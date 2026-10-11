-- Geometry uses real descriptors. Service mocks cover authority and spawn logic;
-- the Roblox physics and rendering engines are still required for visual QA.
return function(source, layoutSource, configSource)
 local function signal()
  local event={Handlers={}}
  function event:Connect(callback) table.insert(self.Handlers,callback) end
  function event:Fire(...) for _,callback in ipairs(self.Handlers) do callback(...) end end
  return event
 end
 local vm={}
 local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm) end
 vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vm.__div=function(a,b) return v(a.X/b,a.Y/b,a.Z/b) end
 vm.__mul=function(a,b) if type(a)=='number' then a,b=b,a end;return v(a.X*b,a.Y*b,a.Z*b) end
 vm.__index=function(a,key)
  if key=='Magnitude' then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
  if key=='Unit' then return a/a.Magnitude end
 end
 local identity={1,0,0,0,1,0,0,0,1}
 local cm={}
 local function cf(x,y,z,m)
  return setmetatable({Position=type(x)=='table' and x or v(x,y,z),Matrix=m or identity},cm)
 end
 cm.__mul=function(a,b)
  local ap,am,bm=a.Position,a.Matrix,b.Matrix
  local bp=b.Position
  local pos=ap+v(am[1]*bp.X+am[2]*bp.Y+am[3]*bp.Z,am[4]*bp.X+am[5]*bp.Y+am[6]*bp.Z,am[7]*bp.X+am[8]*bp.Y+am[9]*bp.Z)
  local m={}
  for r=0,2 do for c=0,2 do m[r*3+c+1]=am[r*3+1]*bm[c+1]+am[r*3+2]*bm[c+4]+am[r*3+3]*bm[c+7] end end
  return cf(pos,nil,nil,m)
 end
 cm.__index=function(a,key)
  local m=a.Matrix
  if key=='RightVector' then return v(m[1],m[4],m[7]) end
  if key=='UpVector' then return v(m[2],m[5],m[8]) end
  if key=='LookVector' then return v(-m[3],-m[6],-m[9]) end
  if key=='PointToObjectSpace' then return function(_,p)
   local d=p-a.Position
   return v(m[1]*d.X+m[4]*d.Y+m[7]*d.Z,m[2]*d.X+m[5]*d.Y+m[8]*d.Z,m[3]*d.X+m[6]*d.Y+m[9]*d.Z)
  end end
 end
 local function angles(rx,ry,rz)
  local cx,cy,cz,sx,sy,sz=math.cos(rx),math.cos(ry),math.cos(rz),math.sin(rx),math.sin(ry),math.sin(rz)
  return cf(v(),nil,nil,{cy*cz,-cy*sz,sy,sx*sy*cz+cx*sz,-sx*sy*sz+cx*cz,-sx*cy,-cx*sy*cz+sx*sz,cx*sy*sz+sx*cz,cx*cy})
 end
 local methods,im={},{}
 local function instance(class)
  return setmetatable({Props={ClassName=class,Name=class},Children={},Attributes={},Triggered=signal()},im)
 end
 im.__index=function(o,key)
  if methods[key] then return methods[key] end
  if key=='Position' then return o.Props.CFrame and o.Props.CFrame.Position or v() end
  return o.Props[key]
 end
 im.__newindex=function(o,key,value)
  if key=='Parent' then
   if o.Props.Parent then local index=table.find(o.Props.Parent.Children,o);if index then table.remove(o.Props.Parent.Children,index) end end
   o.Props.Parent=value
   if value then table.insert(value.Children,o) end
  else o.Props[key]=value end
 end
 function methods:IsA(class) return self.ClassName==class end
 function methods:FindFirstChild(label) for _,child in ipairs(self.Children) do if child.Name==label then return child end end end
 function methods:FindFirstChildOfClass(class) for _,child in ipairs(self.Children) do if child.ClassName==class then return child end end end
 function methods:SetAttribute(key,value) self.Attributes[key]=value end
 function methods:GetAttribute(key) return self.Attributes[key] end
 function methods:PivotTo(frame) local root=self:FindFirstChild('HumanoidRootPart');if root then root.CFrame=frame end end
 local workspace=instance('Workspace')
 local rayMiss=false
 function workspace:Raycast(origin,direction,params)
  assert(direction.X==0 and direction.Z==0 and direction.Y<0,'Ground query must cast vertically down')
  assert(params.FilterType=='RaycastFilterType.Include','Ground query lost its include filter')
  local terrain=params.FilterDescendantsInstances[1]
  assert(terrain and terrain.Name=='GroundTerrain','Ground query can hit decorations or characters')
  if rayMiss then return nil end
  local top=-math.huge
  for _,part in ipairs(terrain.Children) do
   local half=part.Size/2
   local right,up,look=part.CFrame.RightVector,part.CFrame.UpVector,part.CFrame.LookVector
   local x=math.abs(right.X)*half.X+math.abs(up.X)*half.Y+math.abs(look.X)*half.Z
   local y=math.abs(right.Y)*half.X+math.abs(up.Y)*half.Y+math.abs(look.Y)*half.Z
   local z=math.abs(right.Z)*half.X+math.abs(up.Z)*half.Y+math.abs(look.Z)*half.Z
   if math.abs(origin.X-part.Position.X)<=x and math.abs(origin.Z-part.Position.Z)<=z then
    local candidate=part.Position.Y+y
    if candidate<=origin.Y and candidate>=origin.Y+direction.Y then top=math.max(top,candidate) end
   end
  end
  if top>-math.huge then return {Position=v(origin.X,top,origin.Z)} end
  return nil
 end
 local players={List={},PlayerRemoving=signal()}
 function players:GetPlayers() return self.List end
 local heartbeat=signal()
 local layout=assert(loadstring(layoutSource))()
 local config=assert(loadstring(configSource))()
 local storage={Shared={WorldLayout='Layout',WorldConfig='Config'}}
 local enum=setmetatable({}, {__index=function(_,key) return setmetatable({}, {__index=function(_,item) return key..'.'..item end}) end})
 local random=Random or {}
 function random.new()
  local serial=0
  return {NextInteger=function(_,low,high) serial+=1;return low+(serial*37)%(high-low+1) end}
 end
 local now=0
 local env=setmetatable({game={GetService=function(_,name)
  if name=='Players' then return players end
  if name=='RunService' then return {Heartbeat=heartbeat} end
  if name=='ReplicatedStorage' then return storage end
 end},workspace=workspace,Vector3={new=v,zero=v()},CFrame={new=cf,Angles=angles},Random=random,
  RaycastParams={new=function() return {} end},Enum=enum,Instance={new=instance},
  Color3={fromRGB=function(...) return {...} end},UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},UDim={new=function(...) return {...} end},
  os={clock=function() return now end},typeof=function(a) return getmetatable(a)==vm and 'Vector3' or type(a) end,
  require=function(key) if key=='Layout' then return layout elseif key=='Config' then return config end end}, {__index=getfenv()})
 local chunk=assert(loadstring(source));setfenv(chunk,env)
 local world=chunk()
 local bridgePaid,teleportPaid,menus,teleportTransactions=0,0,{},{}
 local allowBridge,allowTeleport=true,true
 world.Build({OnBridge=function(_,_,cost) if allowBridge then bridgePaid+=cost;return true end;return false end,
  OnTeleport=function(player,sourceId,targetId)
   table.insert(teleportTransactions,{player,sourceId,targetId})
   if allowTeleport then teleportPaid+=250;return true end;return false
  end,
  OnTeleportMenu=function(_,sourceId,destinations) table.insert(menus,{sourceId,destinations}) end})
 assert(workspace:GetAttribute('EvolutionWorldReady')==true)
 assert(workspace:GetAttribute('EvolutionWorldSeed')==config.Seed)
 assert(#world.Biomes==9 and #world.FoodSpawnPoints>300)
 assert(config.MetersPerStud==.28 and math.abs(config.RespawnDistanceStuds*.28-200)<1e-9)
 assert(#workspace:FindFirstChild('EvolutionObby'):FindFirstChild('GroundTerrain').Children>90)
 local builtFolder=world.Build({OnBridge=function(_,_,cost) if allowBridge then bridgePaid+=cost;return true end;return false end,
  OnTeleport=function(player,sourceId,targetId)
   table.insert(teleportTransactions,{player,sourceId,targetId})
   if allowTeleport then teleportPaid+=250;return true end;return false
  end,
  OnTeleportMenu=function(_,sourceId,destinations) table.insert(menus,{sourceId,destinations}) end})
 assert(builtFolder==workspace:FindFirstChild('EvolutionObby') and #heartbeat.Handlers==1,'Build duplicated world listeners')
 local checks=0
 for _,biome in ipairs(world.Biomes) do
  for _,position in ipairs(world.SafeSpawns[biome.Id]) do
   assert(world.PositionBiome(position)==biome.Id and world.IsSafe(position),'Canonical safe spawn blocked or in another biome')
   assert(world.GroundPosition(position)~=nil,'Canonical safe spawn has no physical floor')
  end
  for xi=0,16 do for zi=0,10 do
   local origin=v(biome.MinX+xi*(biome.MaxX-biome.MinX)/16,18,biome.MinZ+zi*(biome.MaxZ-biome.MinZ)/10)
   local position=world.RandomSpawn(biome.Id,origin,config.RespawnDistanceStuds).Position
   local delta=position-origin
   assert(math.sqrt(delta.X*delta.X+delta.Z*delta.Z)>=config.RespawnDistanceStuds,'Death spawn too close in '..biome.Id)
   assert(world.PositionBiome(position)==biome.Id,'Death spawn changed biome')
   assert(world.IsSafe(position),'Death spawn blocked')
   checks+=1
  end end
 end
 for _,point in ipairs(world.FoodSpawnPoints) do
  assert(world.IsSafe(point.Position),'Food slot blocked')
  assert(world.PositionBiome(point.Position)==point.Biome,'Food slot biome mismatch')
  assert(world.GroundPosition(point.Position)~=nil,'Food slot has no physical floor')
 end
 for _=1,100 do
  local position=world.GetDropPosition()
  assert(world.IsSafe(position) and world.GroundPosition(position),'Airdrop can land in danger')
 end
 assert(world.GroundPosition(v(1440,20,0))==nil,'River is unsafe ground')
 assert(world.GroundPosition(v(0,20,0))~=nil)
 assert(world.GroundPosition(0,0)~=nil,'Numeric ground lookup failed')
 assert(not world.IsSafe(v(99999,12,0)),'Out-of-map position accepted')
 rayMiss=true;assert(world.GroundPosition(v(0,20,0))==nil,'Missing ground raycast invented a floor');rayMiss=false
 local exact=world.NearestSafeSpawn('meadow',v(0,20,0)).Position
 assert(exact.X==0 and exact.Z==0 and exact.Y>18,'Safe near-revive did not preserve death location')
 for _,case in ipairs({{'river',v(1440,9,0)},{'volcano',v(1730,91,900)},{'swamp',v(-1640,12,970)}}) do
  local biomeId,origin=case[1],case[2]
  local nearestPool=math.huge
  for _,point in ipairs(world.SafeSpawns[biomeId]) do
   local delta=point-origin
   nearestPool=math.min(nearestPool,math.sqrt(delta.X*delta.X+delta.Z*delta.Z))
  end
  local position=world.NearestSafeSpawn(biomeId,origin).Position
  local delta=position-origin
  local distance=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
  assert(world.PositionBiome(position)==biomeId and world.IsSafe(position),'Near-revive changed biome or landed in danger')
  assert(distance<=nearestPool+1e-6 and distance<200,'Near-revive used an arbitrary distant death spawn')
 end
 local character=instance('Model')
 local root=instance('Part');root.Name='HumanoidRootPart';root.Parent=character
 local hum=instance('Humanoid');hum.Health=100;hum.Parent=character
 local player={Character=character}
 players.List={player}
 local source=world.Teleports.meadow
 root.CFrame=cf(source.Position+v(0,6,0))
 source.Part:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(#menus==1 and menus[1][1]=='meadow' and #menus[1][2]==2)
 assert(world.UseTeleport(player,'snow') and teleportPaid==250)
 assert(#teleportTransactions==1 and teleportTransactions[1][1]==player and teleportTransactions[1][2]=='meadow' and teleportTransactions[1][3]=='snow','Teleport charged wrong route')
 assert(math.abs((root.Position-world.Teleports.snow.Position).Magnitude-7)<.001)
 assert(root.AssemblyLinearVelocity.Magnitude==0 and root.AssemblyAngularVelocity.Magnitude==0,'Teleport preserved falling velocity')
 assert(not world.UseTeleport(player,'volcano'),'Teleport cooldown bypass')
 assert(not world.UseTeleport(player,'missing') and not world.UseTeleport(player,'snow'),'Invalid or same portal accepted')
 now=2;allowTeleport=false
 assert(not world.UseTeleport(player,'volcano') and teleportPaid==250,'Rejected purchase moved or charged')
 root.CFrame=cf(v(0,20,0));now=4
 assert(not world.UseTeleport(player,'volcano'),'Teleport away from portal allowed')
 source.Part:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(#menus==1,'Portal menu opened away from portal')
 root.CFrame=cf(source.Position+v(0,6,0));hum.Health=0;now=4.5
 assert(not world.UseTeleport(player,'volcano'),'Dead player teleported')
 source.Part:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(#menus==1,'Dead player opened portal menu')
 hum.Health=100
 local travel=workspace:FindFirstChild('EvolutionObby'):FindFirstChild('Travel')
 local toll=travel:FindFirstChild('BridgeToll-1')
 root.CFrame=cf(toll.Position+v(0,4,0));now=5
 toll:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(bridgePaid==150 and root.Position.X>config.Bridge.X,'Paid crossing failed')
 root.CFrame=cf(v(config.Bridge.X,20,config.Bridge.Z));heartbeat:Fire(.2)
 assert(root.Position.X==config.Bridge.X,'Active bridge entitlement rejected buyer')
 local strangerCharacter=instance('Model')
 local strangerRoot=instance('Part');strangerRoot.Name='HumanoidRootPart';strangerRoot.Parent=strangerCharacter
 local strangerHum=instance('Humanoid');strangerHum.Health=100;strangerHum.Parent=strangerCharacter
 strangerRoot.CFrame=cf(v(config.Bridge.X,20,config.Bridge.Z))
 local stranger={Character=strangerCharacter};players.List={player,stranger}
 heartbeat:Fire(.2)
 assert(math.abs(strangerRoot.Position.X-config.Bridge.X)>config.Bridge.HalfLength,'Bridge entitlement leaked to another player')
 players.List={player}
 root.CFrame=cf(v(config.Bridge.X,20,config.Bridge.Z));now=27
 heartbeat:Fire(.2)
 assert(math.abs(root.Position.X-config.Bridge.X)>config.Bridge.HalfLength,'Expired bridge access allowed')
 allowBridge=false;root.CFrame=cf(toll.Position+v(0,4,0));now=30
 toll:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(bridgePaid==150 and root.Position.X<config.Bridge.X,'Rejected crossing charged or crossed')
 root.CFrame=cf(v(0,20,0));allowBridge=true;now=32
 toll:FindFirstChildOfClass('ProximityPrompt').Triggered:Fire(player)
 assert(bridgePaid==150,'Distant bridge prompt charged player')
 root.CFrame=cf(v(1440,9,0));heartbeat:Fire(.2)
 assert(hum.Health==0,'Falling into river did not defeat player')
 hum.Health=100;root.CFrame=cf(v(1440,18,155));heartbeat:Fire(.2)
 assert(hum.Health==100,'Safe stepping-stone height treated as river drowning')
 local hazards=workspace:FindFirstChild('EvolutionObby'):FindFirstChild('Hazards')
 local lava=hazards:FindFirstChild('CraterLava')
 character:SetAttribute('Form',1);root.CFrame=cf(lava.Position);heartbeat:Fire(.2)
 assert(hum.Health==0,'Lava did not defeat vulnerable form')
 for _,form in ipairs({14,15}) do
  hum.Health=100;character:SetAttribute('Form',form);root.CFrame=cf(lava.Position);heartbeat:Fire(.2)
  assert(hum.Health==100,'Lava-resistant form died in lava')
 end
 local marsh=hazards:FindFirstChild('MarshPool0')
 hum.Health=100;root.CFrame=cf(marsh.Position+v(0,1,0));root.AssemblyLinearVelocity=v(10,-3,20);heartbeat:Fire(.2)
 assert(hum.Health==100,'Swamp caused unintended death')
 assert(root.AssemblyLinearVelocity.X==6.5 and root.AssemblyLinearVelocity.Y==-3 and root.AssemblyLinearVelocity.Z==13,'Swamp slow changed vertical velocity or wrong factor')
 root.CFrame=cf(v(0,-26,0));heartbeat:Fire(.2)
 assert(hum.Health==0,'Below-map fall did not defeat player')
 print('World runtime: '..checks..' same-biome 200m spawns, nearest safe revives, canonical floor clearance, portal rejection, per-player bridge authority and water/lava/swamp hazards passed')
end
