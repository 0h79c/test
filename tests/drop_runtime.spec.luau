-- Actual Events module under a clock/instance harness: authoritative queue,
-- server warning, physical landing, competition, claim distance, and expiration.
return function(configSource, rulesSource, eventSource)
 local clock, sequence=0,0
 local timers, spawned, broadcasts, rewards, delivered={},{},{},{},{}
 local function signal()
  local event={}
  function event:Connect(fn) self.Callback=fn; return {Disconnect=function() end} end
  function event:Fire(...) if self.Callback then self.Callback(...) end end
  return event
 end
 local vectorMeta={}
 local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,_vector=true},vectorMeta) end
 vectorMeta.__index=function(v,key) if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
 vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vectorMeta.__div=function(a,b) return vector(a.X/b,a.Y/b,a.Z/b) end
 local frameMeta={}
 local function frame(a,b,c)
  if type(a)=="table" then return setmetatable({Position=a},frameMeta) end
  return setmetatable({Position=vector(a,b,c)},frameMeta)
 end
 frameMeta.__mul=function(a,b) return frame(a.Position+b.Position) end
 local methods,instanceMeta={},{}
 instanceMeta.__index=function(obj,key)
  if methods[key] then return methods[key] end
  if key=="Position" then return obj._props.CFrame.Position end
  return obj._props[key]
 end
 instanceMeta.__newindex=function(obj,key,value)
  if key=="Parent" then
   local old=obj._props.Parent
   if old then local index=table.find(old._children,obj); if index then table.remove(old._children,index) end end
   obj._props.Parent=value
   if value then table.insert(value._children,obj) end
  else obj._props[key]=value end
 end
 local function instance(className)
  local obj=setmetatable({_props={ClassName=className,Name=className,CFrame=frame()},_children={}},instanceMeta)
  if className=="ProximityPrompt" then obj.Triggered=signal(); obj.Enabled=true end
  return obj
 end
 function methods:FindFirstChild(name)
  for _,child in ipairs(self._children) do if child.Name==name then return child end end
 end
 function methods:FindFirstChildOfClass(name)
  for _,child in ipairs(self._children) do if child.ClassName==name then return child end end
 end
 function methods:GetChildren() return table.clone(self._children) end
 function methods:GetDescendants()
  local found={}
  for _,child in ipairs(self._children) do
   table.insert(found,child)
   for _,descendant in ipairs(child:GetDescendants()) do table.insert(found,descendant) end
  end
  return found
 end
 function methods:SetAttribute(name,value) self._props[name]=value end
 function methods:PivotTo(target)
  local base=self.PrimaryPart and self.PrimaryPart.Position or vector()
  local shift=target.Position-base
  for _,item in ipairs(self:GetDescendants()) do if item.ClassName=="Part" then item.CFrame=frame(item.Position+shift) end end
 end
 function methods:Destroy()
  self.Parent=nil
  for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 end
 local workspace=instance("Folder")
 function workspace:GetServerTimeNow() return clock end
 local players={Members={}}
 function players:GetPlayers() return self.Members end
 local random={NextInteger=function(_,lo) return lo end,NextNumber=function() return .01 end}
 local refs={Config={},EventRules={}}
 local replicated={Shared={Config=refs.Config,EventRules=refs.EventRules}}
 local http={GenerateGUID=function() sequence+=1; return "drop"..sequence end}
 local run={Heartbeat={Wait=function() clock+=.5 end}}
 local game={}
 function game:GetService(name)
  if name=="Players" then return players elseif name=="HttpService" then return http
  elseif name=="ReplicatedStorage" then return replicated elseif name=="RunService" then return run end
  error("Unexpected service "..name)
 end
 local enum={Material={},PartType={Cylinder="Cylinder",Ball="Ball"},SurfaceType={Smooth="Smooth"},Font={GothamBold="GothamBold"}}
 for _,name in ipairs({"SmoothPlastic","Metal","Neon","Fabric"}) do enum.Material[name]=name end
 local environment=setmetatable({game=game,workspace=workspace,Enum=enum,Instance={new=instance},
  Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end},Vector3={new=vector,zero=vector()},
  CFrame={new=frame,Angles=function() return frame() end,lookAt=function(a) return frame(a) end},
  UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},
  UDim={new=function(...) return {...} end},Random={new=function() return random end},
  typeof=function(value) if type(value)=="table" and value._vector then return "Vector3" end; return type(value) end,
  task={delay=function(seconds,callback) table.insert(timers,{At=clock+seconds,Callback=callback}) end,
   spawn=function(callback,...) table.insert(spawned,{callback,...}) end,wait=function(seconds) clock+=seconds end},
  warn=function() end,
 },{__index=getfenv()})
 local function load(source,name)
  local chunk,err=loadstring(source,name); assert(chunk,err); setfenv(chunk,environment); return chunk()
 end
 local config=load(configSource,"Config"); local rules=load(rulesSource,"EventRules")
 environment.require=function(ref)
  if ref==refs.Config then return config elseif ref==refs.EventRules then return rules end
  error("Unexpected require")
 end
 local events=load(eventSource,"Events")
 local function makePlayer(id,position)
  local character=instance("Model")
  local root=instance("Part"); root.Name="HumanoidRootPart"; root.CFrame=frame(position); root.Parent=character
  local humanoid=instance("Humanoid"); humanoid.Health=100; humanoid.Parent=character
  local player={UserId=id,Parent=players,Character=character}
  table.insert(players.Members,player); return player,root,humanoid
 end
 local first,firstRoot=makePlayer(1,vector(0,16,0))
 local second,secondRoot=makePlayer(2,vector(0,16,0))
 local valid=true
 local world={GetDropPosition=function() return vector(0,12,0) end,IsSafePosition=function() return valid end}
 events.Start(world,{
  Broadcast=function(action,payload) assert(action=="Drop"); table.insert(broadcasts,payload) end,
  OnClaim=function(player,reward) table.insert(rewards,{Player=player,Reward=reward}); return true end,
  OnPurchasedDropDelivered=function(player,id) table.insert(delivered,{player,id}); return true end,
 })
 assert(#spawned==1,"Expected exactly one random-event scheduler")
 valid=false
 assert(not events.RequestPurchasedDrop(first,"unsafe"),"Unsafe map location accepted")
 valid=true
 assert(events.RequestPurchasedDrop(first,"receipt1"))
 assert(events.RequestPurchasedDrop(first,"receipt1"))
 assert(#events.GetActiveDrops()==1,"Paid receipt replay queued duplicate drop")
 assert(#broadcasts==1 and broadcasts[1].Status=="Incoming" and broadcasts[1].LandingAt==180)
 assert(events.RequestPurchasedDrop(first,"receipt2")); assert(events.RequestPurchasedDrop(first,"receipt3"))
 assert(not events.RequestPurchasedDrop(first,"receipt4"),"Active drop cap ignored")
 assert(#events.GetActiveDrops()==3)
 local function runTimers(untilTime)
  while true do
   local nextIndex,nextTime
   for index,timer in ipairs(timers) do
    if timer.At<=untilTime and (not nextTime or timer.At<nextTime) then nextIndex=index; nextTime=timer.At end
   end
   if not nextIndex then break end
   local timer=table.remove(timers,nextIndex); clock=math.max(clock,timer.At); timer.Callback()
  end
  clock=math.max(clock,untilTime)
 end
 runTimers(179)
 -- The harness advances Heartbeat through the 20-second visual descent, so
 -- each crate lands at the exact pre-announced timestamp 180, never early.
 assert(clock==180)
 assert(#events.GetActiveDrops()==3)
 for _,entry in ipairs(events.GetActiveDrops()) do assert(entry.Status=="Landed" and entry.LandingAt==180) end
 local drops=workspace:FindFirstChild("SupplyDrops")
 local cargo=drops:FindFirstChild("SupplyCrate_drop1"):FindFirstChild("Cargo")
 local prompt=cargo:FindFirstChildOfClass("ProximityPrompt")
 assert(prompt and prompt.Enabled and math.abs(cargo.Position.Y-15.5)<.001)
 firstRoot.CFrame=frame(vector(100,16,0))
 prompt.Triggered:Fire(first)
 assert(#rewards==0 and #events.GetActiveDrops()==3,"Far-away claim accepted")
 second.Character:FindFirstChildOfClass("Humanoid").Health=0
 prompt.Triggered:Fire(second)
 assert(#rewards==0,"Dead avatar claimed supply drop")
 second.Character:FindFirstChildOfClass("Humanoid").Health=100
 prompt.Triggered:Fire(second)
 firstRoot.CFrame=frame(vector(0,16,0)); prompt.Triggered:Fire(first)
 assert(#rewards==1 and rewards[1].Player==second,"Multiple players received the same crate")
 assert(rewards[1].Reward.Coins==800 and rewards[1].Reward.Fullness==20 and rewards[1].Reward.MutationBoost==3)
 assert(#events.GetActiveDrops()==2)
 for index=2,#spawned do local job=spawned[index]; job[1](table.unpack(job,2)) end
 assert(#delivered==3 and delivered[1][2]=="receipt1","Paid delivery acknowledgement missing")
 runTimers(780)
 assert(#events.GetActiveDrops()==0,"Expired crates held active slots")
 assert(events.RequestPurchasedDrop(first,"receipt4"),"Expired drop cap never released")
 print("PASS: actual Events module: paid idempotence, 180-second warning, parachute landing, single competing claimant, range/death rejection, expiry")
end
