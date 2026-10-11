-- Exercise the real Main.server source with deterministic service boundaries.
-- This validates lifecycle and economy decisions, not Studio rendering/physics.
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")

return function(serverSource)
 local serverCount = 0
 local function createHarness(options)
  options = options or {}
  serverCount += 1
  local serverId = options.serverId or serverCount
  local timeBase = options.timeBase or 10000
  local now, queue, warnings = 0, {}, {}
  local scheduler = {}
  function scheduler.spawn(callback, ...)
   local args = table.pack(...)
   local thread = type(callback) == "thread" and callback or coroutine.create(function()
    callback(table.unpack(args, 1, args.n))
   end)
   table.insert(queue, {At=now, Thread=thread})
   return thread
  end
  function scheduler.delay(seconds, callback, ...)
   local thread = scheduler.spawn(callback, ...)
   queue[#queue].At = now + seconds
   return thread
  end
  scheduler.defer = scheduler.spawn
  function scheduler.wait(seconds) return coroutine.yield(seconds or 0.03) end
  local function advance(seconds)
   local untilTime, iterations = now + (seconds or 0), 0
   while true do
    local index, earliest
    for i, entry in ipairs(queue) do
     if entry.At <= untilTime and (not earliest or entry.At < earliest) then index, earliest = i, entry.At end
    end
    if not index then break end
    local entry = table.remove(queue, index)
    now = entry.At
    local ok, delay = coroutine.resume(entry.Thread)
    assert(ok, "Server runtime error: " .. tostring(delay))
    if coroutine.status(entry.Thread) ~= "dead" then
     table.insert(queue, {At=now + (delay or 0.03), Thread=entry.Thread})
    end
    iterations += 1
    assert(iterations < 5000, "Server did not yield useful work")
   end
   now = untilTime
  end
  local function signal()
   local handlers = {}
   return {
    Connect=function(_, callback)
     table.insert(handlers, callback)
     return {Disconnect=function()
      local index=table.find(handlers,callback); if index then table.remove(handlers,index) end
     end}
    end,
    Fire=function(_, ...)
     for _, callback in ipairs(table.clone(handlers)) do scheduler.spawn(callback, ...) end
    end,
   }
  end
  local vectorMeta = {}
  local function vector(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta) end
  vectorMeta.__index=function(v,key)
   if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
   if key=="Unit" then local length=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z); return vector(v.X/length,v.Y/length,v.Z/length) end
  end
  vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
  vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
  vectorMeta.__mul=function(a,b)
   if type(a)=="number" then a,b=b,a end
   return vector(a.X*b,a.Y*b,a.Z*b)
  end
  vectorMeta.__div=function(a,b) return vector(a.X/b,a.Y/b,a.Z/b) end
  local function cframe(x,y,z)
   return {Position=if type(x)=="table" then x else vector(x,y,z),LookVector=vector(0,0,-1)}
  end
  local instanceMethods, instanceMeta = {}, {}
  local workspaceMock
  instanceMeta.__index=function(object,key)
   if instanceMethods[key] then return instanceMethods[key] end
   if object._properties[key]~=nil then return object._properties[key] end
   for _,child in ipairs(object._children) do if child.Name==key then return child end end
  end
  instanceMeta.__newindex=function(object,key,value)
   if key=="Parent" then
    local old=object._properties.Parent
    if old then local index=table.find(old._children,object);if index then table.remove(old._children,index) end end
    object._properties.Parent=value
    if value then
     table.insert(value._children,object)
     local ancestor=value
     while ancestor do ancestor.DescendantAdded:Fire(object);ancestor=ancestor.Parent end
    end
    if object.AncestryChanged then object.AncestryChanged:Fire(object,value) end
    return
   end
   object._properties[key]=value
  end
  local function instance(className)
   local object=setmetatable({_properties={ClassName=className,Name=className},_children={},_attributes={}},instanceMeta)
   object.AncestryChanged=signal();object.DescendantAdded=signal()
   if className=="RemoteEvent" then object.OnServerEvent=signal();object.Events={}
   elseif className=="Humanoid" then object.Health=100;object.Died=signal()
   elseif className=="Part" or className=="SpawnLocation" then
    object.Touched=signal();object.Size=vector(2,2,2);object.Position=vector();object.AssemblyMass=10
    object.AssemblyLinearVelocity=vector();object.AssemblyAngularVelocity=vector();object.Impulses={}
   end
   return object
  end
  function instanceMethods:SetAttribute(key,value) self._attributes[key]=value end
  function instanceMethods:GetAttribute(key) return self._attributes[key] end
  function instanceMethods:FindFirstChild(name)
   for _,child in ipairs(self._children) do if child.Name==name then return child end end
  end
  function instanceMethods:WaitForChild(name)
   local child=self:FindFirstChild(name);assert(child,"Mock child missing: "..name);return child
  end
  function instanceMethods:FindFirstChildOfClass(className)
   for _,child in ipairs(self._children) do if child:IsA(className) then return child end end
  end
  function instanceMethods:FindFirstAncestorOfClass(className)
   local parent=self.Parent
   while parent do if parent:IsA(className) then return parent end;parent=parent.Parent end
  end
  function instanceMethods:GetChildren() return table.clone(self._children) end
  function instanceMethods:IsA(className)
   return self.ClassName==className or (className=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation"))
  end
  function instanceMethods:FireClient(player,action,data) table.insert(self.Events,{Player=player,Action=action,Data=data}) end
  function instanceMethods:FireAllClients(action,data) table.insert(self.Events,{Action=action,Data=data}) end
  function instanceMethods:PivotTo(cf)
   self.LastPivot=cf
   local root=self:FindFirstChild("HumanoidRootPart")
   if root then root.Position=cf.Position;root.CFrame=cf end
  end
  function instanceMethods:Kick(message) self.Kicked=message end
  function instanceMethods:SetNetworkOwner(owner) self.NetworkOwner=owner end
  function instanceMethods:ApplyImpulse(impulse)
   table.insert(self.Impulses,impulse);self.AssemblyLinearVelocity+=impulse/self.AssemblyMass
  end
  function instanceMethods:ChangeState(state) self.LastState=state end
  function instanceMethods:LoadCharacterAsync()
   self.LoadCount=(self.LoadCount or 0)+1
   if self.Character then self.Character.Parent=nil end
   local character=instance("Model");character.Name=self.Name
   local root=instance("Part");root.Name="HumanoidRootPart";root.CFrame=cframe(root.Position);root.Parent=character
   local humanoid=instance("Humanoid");humanoid.Parent=character
   character.Parent=workspaceMock;self.Character=character;self.CharacterAdded:Fire(character)
   return character
  end
  instanceMethods.LoadCharacter=instanceMethods.LoadCharacterAsync

  local replicated=instance("Folder")
  local shared=instance("Folder");shared.Name="Shared";shared.Parent=replicated
  local scriptParent=instance("Folder")
  local modules={}
  for _,name in ipairs({"Config","Rules","Character","World","Ecology","Events","Commerce","Buffs"}) do
   local module=instance("ModuleScript");module.Name=name
   module.Parent=if name=="Config" or name=="Rules" then shared else scriptParent
   modules[name]=module
  end
  local serverScript=instance("Script");serverScript.Parent=scriptParent
  local players=instance("Players");players.RespawnTime=5
  players.PlayerAdded=signal();players.PlayerRemoving=signal()
  local playerList={}
  function players:GetPlayers() return table.clone(playerList) end
  function players:GetPlayerFromCharacter(character)
   for _,p in ipairs(playerList) do if p.Character==character then return p end end
  end
  function players:GetPlayerByUserId(id)
   for _,p in ipairs(playerList) do if p.UserId==id and p.Parent then return p end end
  end
  local function makePlayer(id)
   local p=instance("Player");p.UserId=id;p.Name="Player"..id;p.DisplayName=p.Name
   p.CharacterAdded=signal();p.CharacterAppearanceLoaded=signal();p.Parent=players
   table.insert(playerList,p);return p
  end
  workspaceMock=instance("Workspace");workspaceMock.Gravity=196.2
  function workspaceMock:GetServerTimeNow() return timeBase+now end
  function workspaceMock:Raycast() return if options.blockAttack then {} else nil end
  local world={StartSpawn=cframe(0,16,0),BuildCount=0,RandomCalls={},Teleports={}}
  function world.Build(callbacks) world.BuildCount+=1;world.Callbacks=callbacks;return instance("Folder") end
  function world.PositionBiome(position) return if position.X>=2000 then "forest" else "meadow" end
  function world.IsSafe(position) return position and math.abs(position.X)<100000 and math.abs(position.Z)<100000 end
  function world.GroundPosition(position)
   return if options.unsafeGround then nil else vector(position.X,10,position.Z)
  end
  function world.NearestSafeSpawn(biome,origin)
   world.NearestCall={Biome=biome,Origin=origin}
   return cframe(origin.X+30,16,origin.Z)
  end
  function world.RandomSpawn(biome,origin,minimum)
   table.insert(world.RandomCalls,{Biome=biome,Origin=origin,Minimum=minimum})
   return cframe(origin.X+minimum+30,16,origin.Z)
  end
  function world.UseTeleport(player,id) world.TeleportRequest={Player=player,Id=id} end
  local applied={}
  local character={Initialize=function() end,Apply=function(p,data)
   assert(p.Character and p.Character:FindFirstChild("HumanoidRootPart"),"Morph attempted before safe character existed")
   table.insert(applied,{Player=p,Form=data.Form,Unlocked=data.Unlocked,
    BuffModifiers=if data.BuffModifiers then table.clone(data.BuffModifiers) else nil})
   p.Character:SetAttribute("Form",data.Form)
   local collider=p.Character:FindFirstChild("AnimalCollider")
   if not collider then collider=instance("Part");collider.Name="AnimalCollider";collider.Parent=p.Character end
   collider.Size=vector(0.5+data.Form*0.25,1,0.5+data.Form*0.25)
  end}
  local commerce={PassPrompts={},DropPrompts={}}
  function commerce.Start(callbacks) commerce.Callbacks=callbacks end
  function commerce.HasPass(p) return options.pass==true or (options.passes and options.passes[p.UserId]==true) or false end
  function commerce.GetAvailability() return {PassAvailable=false,DropAvailable=true} end
  function commerce.OnPlayerAdded() end
  function commerce.PromptPass(p) table.insert(commerce.PassPrompts,p) end
  function commerce.PromptSupplyDrop(p) table.insert(commerce.DropPrompts,p) end
  -- Buff timing/math have their own actual-module tests. This boundary checks that
  -- Main forwards trusted pickups, re-applies the animal, and sends current state.
  local buffs={States={},Applications={}}
  function buffs.Start(callbacks)
   buffs.Callbacks=callbacks
   players.PlayerRemoving:Connect(function(p) buffs.States[p]=nil end)
  end
  function buffs.GetState(p)
   local result={}
   for kind,state in pairs(buffs.States[p] or {}) do
    if state.ExpiresAt>timeBase+now then
     result[kind]=table.clone(state);result[kind].Remaining=state.ExpiresAt-timeBase-now
    end
   end
   return result
  end
  function buffs.GetModifiers(p)
   local state=buffs.GetState(p)
   return {Speed=if state.Speed then state.Speed.Multiplier else 1,
    Scale=if state.Giant then state.Giant.Scale else 1,HuntBonus=if state.Hunt then state.Hunt.Tiers else 0}
  end
  function buffs.Apply(p,kind)
   if kind~="Speed" and kind~="Hunt" and kind~="Giant" then return nil end
   buffs.States[p]=buffs.States[p] or {}
   local state={Kind=kind,Duration=60,Remaining=60,ExpiresAt=timeBase+now+60,
    Multiplier=if kind=="Speed" then 1.5 else nil,Scale=if kind=="Giant" then 5 else nil,
    Tiers=if kind=="Hunt" then 3 else nil}
   buffs.States[p][kind]=state
   table.insert(buffs.Applications,{Player=p,Kind=kind})
   if buffs.Callbacks.OnChanged then buffs.Callbacks.OnChanged(p) end
   scheduler.delay(60,function()
    if buffs.States[p] and buffs.States[p][kind]==state then
     buffs.States[p][kind]=nil
     if buffs.Callbacks.OnChanged then buffs.Callbacks.OnChanged(p) end
    end
   end)
   return table.clone(state)
  end
  function buffs.Clear(p) buffs.States[p]=nil end
  buffs.Remove=buffs.Clear
  local events={Requests={},RequestCounts={}}
  function events.Start(receivedWorld,callbacks) assert(receivedWorld==world);events.Callbacks=callbacks end
  function events.GetActiveDrops() return {} end
  function events.RequestPurchasedDrop(p,id)
   if options.rejectDropQueue then return false end
   table.insert(events.Requests,{Player=p,Id=id});events.RequestCounts[id]=(events.RequestCounts[id] or 0)+1;return true
  end
  local ecology={}
  function ecology.Start(receivedWorld,callbacks) assert(receivedWorld==world);ecology.Callbacks=callbacks end
  function ecology.TryEat(p)
   if ecology.Pending then ecology.Callbacks.OnEat(p,ecology.Pending.Spec,ecology.Pending.Source);ecology.Pending=nil end
  end
  local storedByKey={}
  local initialProfile=options.profile
  local updates,acquisitions=0,0
  local function clone(value)
   if type(value)~="table" then return value end
   local result={};for key,item in pairs(value) do result[key]=clone(item) end;return result
  end
  local store={UpdateAsync=function(_,key,callback)
   updates+=1;local call=updates
   if storedByKey[key]==nil then
    if options.profiles then storedByKey[key]=clone(options.profiles[tonumber(string.sub(key,8))])
    elseif initialProfile then storedByKey[key]=clone(initialProfile);initialProfile=nil end
   end
   if options.loadDelay and call==1 then scheduler.wait(options.loadDelay) end
   if options.updateFailure then error("API Services unavailable") end
   local result=callback(clone(storedByKey[key]))
   if result~=nil then storedByKey[key]=clone(result) end
   if options.returnDelay and call==1 then scheduler.wait(options.returnDelay) end
   return clone(result)
  end}
  local dataStore={GetDataStore=function()
   acquisitions+=1
   if options.acquireFailure then error("You must publish this place to access DataStore") end
   return store
  end}
  local gameMock={ReplicatedStorage=replicated,Players=players,GameId=options.gameId or 0,PlaceId=options.gameId or 0,JobId="test-job"}
  local guidCount=0
  function gameMock:GetService(name)
   if name=="Players" then return players
   elseif name=="DataStoreService" then return dataStore
   elseif name=="HttpService" then return {GenerateGUID=function() guidCount+=1;return "runtime-server-"..serverId.."-guid-"..guidCount end}
   elseif name=="RunService" then return {IsStudio=function() return options.studio~=false end}
   elseif name=="ReplicatedStorage" then return replicated
   elseif name=="Workspace" then return workspaceMock end
   error("Unhandled service: "..name)
  end
  function gameMock:BindToClose(callback) self.OnClose=callback end
  local environment=setmetatable({
   game=gameMock,workspace=workspaceMock,script=serverScript,task=scheduler,
   Instance={new=instance},Vector3={new=vector,zero=vector()},CFrame={new=cframe},
   RaycastParams={new=function() return {} end},
   Enum={RaycastFilterType={Exclude="Exclude"},HumanoidStateType={Freefall="Freefall"}},
   Random={new=function() return {NextInteger=function(_,minimum) return options.roll or minimum end} end},
   warn=function(...) table.insert(warnings,table.pack(...)) end,
   os={time=function() return timeBase+math.floor(now) end,clock=function() return now end},
   require=function(module)
    if module==modules.Config then return Config elseif module==modules.Rules then return Rules
    elseif module==modules.Character then return character elseif module==modules.World then return world
    elseif module==modules.Ecology then return ecology elseif module==modules.Events then return events
    elseif module==modules.Commerce then return commerce elseif module==modules.Buffs then return buffs end
    error("Unexpected module require")
   end,
  },{__index=getfenv()})
  local before=options.existing and makePlayer(101) or nil
  local chunk,compileError=loadstring(serverSource,"Main.server.luau");assert(chunk,compileError)
  setfenv(chunk,environment);scheduler.spawn(chunk);advance(0)
  local h={World=world,Applied=applied,Warnings=warnings,Players=players,Existing=before,Advance=advance,
   Commerce=commerce,Events=events,Ecology=ecology,Buffs=buffs,Vector=vector,Instance=instance,Workspace=workspaceMock}
  function h:AddPlayer(id) local p=makePlayer(id);players.PlayerAdded:Fire(p);advance(0);return p end
  function h:Remote() return replicated:FindFirstChild("EvolutionEvent") end
  function h:LatestState(p)
   for i=#self:Remote().Events,1,-1 do local event=self:Remote().Events[i]
    if event.Player==p and event.Action=="State" then return event.Data end
   end
  end
  function h:LatestApplied(p)
   for index=#applied,1,-1 do if applied[index].Player==p then return applied[index] end end
  end
  function h:EventsNamed(p,action)
   local result={}
   for _,event in ipairs(self:Remote().Events) do
    if event.Player==p and event.Action==action then table.insert(result,event.Data) end
   end
   return result
  end
  function h:Send(p,action,value) advance(0.2);self:Remote().OnServerEvent:Fire(p,action,value);advance(0) end
  function h:Eat(p,spec,source) ecology.Callbacks.OnEat(p,spec,source);advance(0) end
  function h:Roll(value) options.roll=value end
  function h:Acquisitions() return acquisitions end
  function h:Updates() return updates end
  function h:UnixTime() return timeBase+math.floor(now) end
  function h:Stored(id)
   if id then return storedByKey["player_"..id] end
   for _,value in pairs(storedByKey) do return value end
  end
  function h:FailUpdates(value) options.updateFailure=value end
  function h:RejectDrops(value) options.rejectDropQueue=value end
  function h:BlockAttack(value) options.blockAttack=value end
  function h:RemovePlayer(p)
   p.Parent=nil;local index=table.find(playerList,p);if index then table.remove(playerList,index) end
   players.PlayerRemoving:Fire(p);advance(0)
  end
  function h:Close() scheduler.spawn(gameMock.OnClose);advance(0) end
  function h:Kill(p)
   local humanoid=p.Character:FindFirstChildOfClass("Humanoid");humanoid.Health=0;humanoid.Died:Fire();advance(0)
  end
  function h:Respawn(p) self:Kill(p);advance(6) end
  function h:Grant(p,id)
   local result;scheduler.spawn(function() result=commerce.Callbacks.GrantDropCredit(p,id) end);advance(0);return result
  end
  function h:Flush(p) commerce.Callbacks.OnDropCreditGranted(p);advance(0) end
  function h:Delivered(p,id)
   local result;scheduler.spawn(function() result=events.Callbacks.OnPurchasedDropDelivered(p,id) end);advance(0);return result
  end
  function h:Touch(a,b) a.Character.AnimalCollider.Touched:Fire(b.Character.AnimalCollider);advance(0) end
  return h
 end

 local function assertReady(h,p,unlocked,form)
  assert(h.World.BuildCount==1,"Server must build world exactly once")
  assert(h.Workspace:GetAttribute("EvolutionStatus")=="Ready","Server never marked world ready")
  assert(p.Character,"Player never received a character")
  assert(p.Character:GetAttribute("Form")==form,"Player kept the default avatar")
  assert(p.Character.LastPivot,"Player was never placed safely")
  assert(p.leaderstats.Evolution.Value==unlocked,"Unlocked species did not synchronize")
  assert(h:LatestState(p),"Client never received initial state")
 end

 local unpublished=createHarness({acquireFailure=true})
 local player=unpublished:AddPlayer(1)
 assertReady(unpublished,player,1,1)
 assert(unpublished:Acquisitions()==0,"Unpublished Studio must not touch DataStore")
 assert(unpublished:LatestState(player).ReadOnly,"Temporary mode must report unsaved progress")
 assert(not unpublished.Commerce.Callbacks.CanPurchaseDrop(player),"Paid drops must be unavailable without durable storage")
 assert(not unpublished:Grant(player,"cannot-persist"))

 local acquisitionFailure=createHarness({studio=false,gameId=1,acquireFailure=true})
 local fallback=acquisitionFailure:AddPlayer(2)
 assertReady(acquisitionFailure,fallback,1,1)
 assert(acquisitionFailure:Acquisitions()==1 and acquisitionFailure:LatestState(fallback).ReadOnly)
 local denied=createHarness({gameId=1,updateFailure=true})
 local temporary=denied:AddPlayer(3)
 assertReady(denied,temporary,1,1)
 assert(denied:LatestState(temporary).ReadOnly,"Disabled API Services promised persistence")

 local restored=createHarness({gameId=1,existing=true,profile={Coins=950,Checkpoint=20,Form=3,Mutations={["1"]="Normal",["2"]="Giant",["3"]="Tiny"}}})
 assertReady(restored,restored.Existing,3,3)
 assert(restored:LatestState(restored.Existing).Coins==950,"Legacy coins were overwritten")
 assert(restored:LatestState(restored.Existing).Mutations["3"]=="Tiny","Legacy mutation was lost")
 restored:Respawn(restored.Existing)
 assertReady(restored,restored.Existing,3,3)
 assert(restored.Existing.LoadCount>=2,"Death never respawned the player")

 local slow=createHarness({gameId=1,loadDelay=0.5,profile={Coins=600,Unlocked=2,Form=2,Fullness=35,Mutations={}}})
 local loading=slow:AddPlayer(5)
 assert(loading.Character,"A slow DataStore prevented safe character spawning")
 slow:Eat(loading,{Hunger=100,Coins=100})
 slow:Eat(loading,{Name="Thuốc tốc độ",Hunger=0,Coins=0,Buff="Speed"})
 slow:Send(loading,"Morph",2)
 assert(slow:LatestState(loading).Fullness==0 and loading.Character:GetAttribute("Form")==1,"Loading player gained progress")
 assert(#slow.Buffs.Applications==0,"Loading player consumed a temporary buff")
 slow.Advance(0.6)
 assertReady(slow,loading,2,2)
 assert(slow:LatestState(loading).Coins==600 and slow:LatestState(loading).Fullness==35,"Loading state overwrote real profile")

 local departed=createHarness({gameId=1,loadDelay=0.5})
 local leaving=departed:AddPlayer(6);departed:RemovePlayer(leaving);departed.Advance(1)
 assert(departed:Stored(6).Session==nil and departed:Stored(6).Lease==0,"Leaving while loading retained a lease")
 local foreign=createHarness({gameId=1,profile={Coins=123,Unlocked=2,Form=2,Session="other-server",Lease=20000}})
 local rejected=foreign:AddPlayer(7)
 assert(rejected.Kicked,"A foreign session lock was ignored")
 assert(foreign:Stored(7).Session=="other-server" and foreign:Stored(7).Coins==123)

 -- Food fills the meter without silently evolving; selection never lowers progress.
 unpublished:Eat(player,{Name="Quả mọng",Hunger=0.5,Coins=4})
 assert(unpublished:LatestState(player).Fullness==0.5,"Fractional food fullness was rounded away")
 for _=1,10 do unpublished:Eat(player,{Name="Táo",Hunger=10,Coins=10}) end
 assert(unpublished:LatestState(player).Fullness==100 and unpublished:LatestState(player).Unlocked==1,"Food auto-evolved the player")
 for _,value in ipairs({"2",-1,2,1.5,math.huge,0/0}) do unpublished:Send(player,"Morph",value) end
 assert(player.Character:GetAttribute("Form")==1,"Malformed/locked form was accepted")
 unpublished:Send(player,"Evolve")
 assertReady(unpublished,player,2,2)
 assert(unpublished:LatestState(player).Fullness==0 and unpublished:LatestState(player).Mutations["2"]=="Normal")
 local evolutionEffect
 for _,event in ipairs(unpublished:Remote().Events) do
  if event.Player==player and event.Action=="Evolution" then evolutionEffect=event.Data end
 end
 assert(evolutionEffect==2,"Manual evolution did not announce its new form for client effects")
 unpublished:Send(player,"Morph",1);unpublished:Eat(player,{Hunger=100,Coins=0});unpublished:Send(player,"Evolve")
 assertReady(unpublished,player,3,3)
 unpublished:Roll(100);unpublished:Eat(player,{Hunger=1,Coins=0},{MutationFood=true,Boost=1})
 assert(unpublished:LatestState(player).Mutations["3"]=="Awakened" and unpublished:LatestState(player).FreeRerolls==0)
 unpublished:Roll(1);unpublished:Send(player,"Reroll")
 assert(unpublished:LatestState(player).Mutations["3"]=="Awakened","Non-pass player rerolled")
 unpublished:Eat(player,{Hunger=0.5,Coins=4})
 assert(unpublished:LatestState(player).Mutations["3"]=="Awakened","Ordinary food rerolled a mutation")

 local premium=createHarness({pass=true})
 local paid=premium:AddPlayer(20)
 premium:Eat(paid,{Hunger=10,Coins=10})
 assert(premium:LatestState(paid).Fullness==15 and premium:LatestState(paid).Coins==15,"Pass multipliers were not applied")
 premium:Roll(100);premium:Eat(paid,{Hunger=1,Coins=0},{MutationFood=true,Boost=3})
 assert(premium:LatestState(paid).FreeRerolls==2 and premium:LatestState(paid).LastMutationBoost==3)
 premium:Send(paid,"Reroll");assert(premium:LatestState(paid).FreeRerolls==1)
 premium:Eat(paid,{Hunger=1,Coins=0},{MutationFood=true,Boost=1})
 assert(premium:LatestState(paid).FreeRerolls==2 and premium:LatestState(paid).LastMutationBoost==1,"Meal rerolls stacked")
 premium:Send(paid,"Reroll");premium:Send(paid,"Reroll");premium:Send(paid,"Reroll")
 assert(premium:LatestState(paid).FreeRerolls==0,"Free rerolls went negative")

 -- Only trusted food claims grant timed effects. Effects affect the active animal,
 -- survive morph/death, and never become permanent progress in the save record.
 local tonics=createHarness({gameId=1,pass=true,profile={Coins=72,Unlocked=3,Form=3,Fullness=24,
  Mutations={["1"]="Normal",["2"]="Normal",["3"]="Tiny"}}})
 local explorer=tonics:AddPlayer(21)
 assert(tonics.Ecology.Callbacks.HasPass(explorer)==true,"Ecology cannot apply the local pass spawn bonus")
 assert(unpublished.Ecology.Callbacks.HasPass(player)==false,"Ecology granted a pass aura to a free player")
 assert(tonics.Ecology.Callbacks.GetHuntBonus(explorer)==0,"Hunt bonus was active before a pickup")
 local neutral=tonics:LatestApplied(explorer).BuffModifiers
 assert(neutral and neutral.Speed==1 and neutral.Scale==1 and neutral.HuntBonus==0,"Initial animal lacked neutral buff modifiers")
 tonics:Send(explorer,"Buff","Giant")
 assert(#tonics.Buffs.Applications==0,"Client forged a buff without a server food claim")
 for _,kind in ipairs({"Speed","Hunt","Giant"}) do
  tonics:Eat(explorer,{Name="Thuốc "..kind,Hunger=0,Coins=0,Buff=kind})
 end
 assert(#tonics.Buffs.Applications==3,"A trusted tonic failed to grant its effect")
 local tonicState=tonics:LatestState(explorer)
 assert(tonicState.Coins==72 and tonicState.Fullness==24,"Tonic created coins or evolution progress")
 assert(tonicState.Mutations["3"]=="Tiny" and tonicState.FreeRerolls==0,"Tonic rerolled or changed a permanent mutation")
 assert(#tonics:EventsNamed(explorer,"Mutation")==0,"Tonic announced a permanent mutation")
 assert(tonicState.Buffs.Speed.Remaining>59 and tonicState.Buffs.Speed.Remaining<=60.001
  and tonicState.Buffs.Giant.Scale==5 and tonicState.Buffs.Hunt.Tiers==3,"Buff state failed to reach the client")
 local effects=tonics:EventsNamed(explorer,"Buff")
 assert(#effects==3 and effects[1].Kind=="Speed" and effects[2].Tiers==3 and effects[3].Duration==60,"Client did not receive tonic feedback")
 local boosted=tonics:LatestApplied(explorer).BuffModifiers
 assert(boosted.Speed==1.5 and boosted.Scale==5 and boosted.HuntBonus==3,"Tonic modifiers did not reach Character.Apply")
 assert(tonics.Ecology.Callbacks.GetHuntBonus(explorer)==3,"Hunt tiers did not reach the NPC eating check")
 tonics:Send(explorer,"Morph",1)
 local morphed=tonics:LatestApplied(explorer)
 assert(morphed.Form==1 and morphed.BuffModifiers.Scale==5 and morphed.BuffModifiers.Speed==1.5,"Morph discarded active tonics")
 tonics:Roll(100);tonics:Eat(explorer,{Hunger=0,Coins=0},{MutationFood=true,Boost=1})
 assert(tonics:LatestApplied(explorer).BuffModifiers.Scale==5,"Mutation re-application discarded the giant tonic")
 tonics:Send(explorer,"Reroll")
 assert(tonics:LatestApplied(explorer).BuffModifiers.Speed==1.5,"Mutation reroll discarded the speed tonic")
 tonics:Eat(explorer,{Hunger=100,Coins=0});tonics:Send(explorer,"Evolve")
 assert(tonics:LatestApplied(explorer).Form==4 and tonics:LatestApplied(explorer).BuffModifiers.Scale==5,"Evolution discarded active tonic effects")
 tonics:Respawn(explorer)
 assert(tonics:LatestApplied(explorer).BuffModifiers.Speed==1.5,"Respawn discarded the remaining tonic duration")
 assert(tonics:LatestState(explorer).Buffs.Speed.Remaining<60,"Respawn reset the tonic timer")
 tonics.Advance(60)
 local expiredModifiers=tonics:LatestApplied(explorer).BuffModifiers
 assert(expiredModifiers.Speed==1 and expiredModifiers.Scale==1 and expiredModifiers.HuntBonus==0,"Expiry did not restore the animal's normal modifiers")
 assert(next(tonics:LatestState(explorer).Buffs)==nil and tonics.Ecology.Callbacks.GetHuntBonus(explorer)==0,"Expired effects remained in client or ecology state")
 assert(tonics:Stored(21).Buffs==nil and tonics:Stored(21).BuffModifiers==nil,"Autosave persisted temporary tonic effects")
 tonics:Eat(explorer,{Name="Thuốc khổng lồ",Hunger=0,Coins=0,Buff="Giant"})
 tonics:RemovePlayer(explorer)
 local returnedExplorer=tonics:AddPlayer(21)
 assert(tonics:LatestApplied(returnedExplorer).BuffModifiers.Scale==1 and next(tonics:LatestState(returnedExplorer).Buffs)==nil,"Rejoin restored an old temporary tonic")
 tonics.Advance(61)

 local deadTonic=createHarness()
 local deceased=deadTonic:AddPlayer(22);deadTonic:Kill(deceased)
 deadTonic:Eat(deceased,{Name="Thuốc tốc độ",Hunger=0,Coins=0,Buff="Speed"})
 assert(#deadTonic.Buffs.Applications==0,"Dead player consumed a temporary buff")

 local death=createHarness({gameId=1,pass=true,profile={Coins=100,Unlocked=3,Form=3,Fullness=20}})
 local traveller=death:AddPlayer(30)
 local deathPosition=death.Vector(2500,16,50);traveller.Character.HumanoidRootPart.Position=deathPosition
 death:Respawn(traveller)
 local call=death.World.RandomCalls[#death.World.RandomCalls]
 assert(call.Biome=="forest" and call.Origin==deathPosition and call.Minimum==Config.DeathRespawnStuds,"Death omitted same-biome 200 m placement")
 assert((traveller.Character.HumanoidRootPart.Position-deathPosition).Magnitude>=200/0.28)
 assert(death:LatestState(traveller).ReviveAvailable,"Pass user lost near-respawn offer")
 death:Send(traveller,"ReviveNear")
 assert((traveller.Character.HumanoidRootPart.Position-deathPosition).Magnitude<1,"Near revival stayed far from death")
 local readyAt=death:Stored(30).NearReviveReadyAt
 assert(death:LatestState(traveller).ReviveCooldown==180 and readyAt>10180,"Near revival cooldown was not saved")
 death:Respawn(traveller)
 local farPosition=traveller.Character.HumanoidRootPart.Position
 death:Send(traveller,"ReviveNear")
 assert(traveller.Character.HumanoidRootPart.Position==farPosition,"Near revival ignored active cooldown")
 death:RemovePlayer(traveller)
 local rejoined=death:AddPlayer(30)
 assert(death:LatestState(rejoined).ReviveCooldown>0 and death:Stored(30).NearReviveReadyAt==readyAt,"Rejoin reset near-revive cooldown")
 death.Advance(181);death:Respawn(rejoined)
 assert(death:LatestState(rejoined).ReviveAvailable,"Near revival never became available after three minutes")
 death:Send(rejoined,"ReviveNear")
 assert(death:Stored(30).NearReviveReadyAt==death:UnixTime()+180,"A second near revival did not restart cooldown")

 local expiredOffer=createHarness({pass=true})
 local late=expiredOffer:AddPlayer(31);expiredOffer:Respawn(late);expiredOffer.Advance(121)
 local latePosition=late.Character.HumanoidRootPart.Position
 expiredOffer:Send(late,"ReviveNear")
 assert(late.Character.HumanoidRootPart.Position==latePosition and not expiredOffer:LatestState(late).ReviveAvailable,"Expired revival offer remained usable")

 local hazardousDeath=createHarness({pass=true,unsafeGround=true})
 local swimmer=hazardousDeath:AddPlayer(32)
 local hazardPosition=hazardousDeath.Vector(2500,16,0)
 swimmer.Character.HumanoidRootPart.Position=hazardPosition
 hazardousDeath:Respawn(swimmer);hazardousDeath:Send(swimmer,"ReviveNear")
 assert(hazardousDeath.World.NearestCall.Biome=="forest" and hazardousDeath.World.NearestCall.Origin==hazardPosition,"Hazardous near revival did not choose the nearest safe spot in the death biome")
 assert((swimmer.Character.HumanoidRootPart.Position-hazardPosition).Magnitude==30,"Hazardous near revival used an arbitrary distant spawn")

 local deathExit=createHarness({gameId=1,profile={Unlocked=3,Form=3}})
 local quitter=deathExit:AddPlayer(33)
 local exitDeath=deathExit.Vector(2500,16,40)
 quitter.Character.HumanoidRootPart.Position=exitDeath
 deathExit:Kill(quitter)
 assert(quitter.LoadCount==1,"Death-exit case already respawned before leaving")
 deathExit:RemovePlayer(quitter)
 local exitPosition=deathExit:Stored(33).Position
 assert(exitPosition and exitPosition.Biome=="forest","Leaving while dead did not persist the chosen same-biome respawn")
 local returned=deathExit:AddPlayer(33)
 local returnedPosition=returned.Character.HumanoidRootPart.Position
 assert(deathExit.World.PositionBiome(returnedPosition)=="forest" and (returnedPosition-exitDeath).Magnitude>=200/0.28,"Rejoining after death bypassed the same-biome 200 m respawn")
 assert(returnedPosition.X==exitPosition.X and returnedPosition.Z==exitPosition.Z,"Rejoin ignored the saved death respawn destination")

 -- Contact enables a shove beyond the small initial collider's adjacency range.
 local combat=createHarness({gameId=1,profiles={[40]={Unlocked=15,Form=1},[41]={Unlocked=1,Form=1}}})
 local attacker=combat:AddPlayer(40);local victim=combat:AddPlayer(41)
 combat.Advance(9)
 attacker.Character.HumanoidRootPart.Position=combat.Vector(0,16,0)
 victim.Character.HumanoidRootPart.Position=combat.Vector(6,16,0)
 combat:Send(attacker,"Attack")
 local victimRoot=victim.Character.HumanoidRootPart
 assert(#victimRoot.Impulses==0,"Attack hit a distant non-contact player")
 combat:Touch(attacker,victim);combat.Advance(Config.AttackCooldown);combat:Send(attacker,"Attack")
 assert(#victimRoot.Impulses==1,"Contact did not enable attack")
 local smallImpulse=victimRoot.Impulses[1]
 combat:Send(attacker,"Morph",15);combat.Advance(Config.AttackCooldown)
 combat:Touch(attacker,victim);combat:Send(attacker,"Attack")
 assert(#victimRoot.Impulses==2 and victimRoot.Impulses[2].X>smallImpulse.X,"Higher species did not push farther")
 combat:BlockAttack(true);combat.Advance(Config.AttackCooldown);combat:Touch(attacker,victim);combat:Send(attacker,"Attack")
 assert(#victimRoot.Impulses==2,"Shove passed through a blocking wall")
 combat:BlockAttack(false);combat:Respawn(attacker)
 attacker.Character.HumanoidRootPart.Position=combat.Vector(0,16,0)
 combat:Touch(attacker,victim);combat:Send(attacker,"Attack")
 assert(#victimRoot.Impulses==2,"Protected respawn could attack")

 local giantCombat=createHarness()
 local giantAttacker=giantCombat:AddPlayer(43);local nearbyPlayer=giantCombat:AddPlayer(44)
 giantCombat.Advance(9)
 giantAttacker.Character.AnimalCollider.Size=giantCombat.Vector(20,20,20)
 giantAttacker.Character.HumanoidRootPart.Position=giantCombat.Vector(0,16,0)
 nearbyPlayer.Character.HumanoidRootPart.Position=giantCombat.Vector(11,16,0)
 giantCombat:Touch(giantAttacker,nearbyPlayer);giantCombat:Send(giantAttacker,"Attack")
 assert(#nearbyPlayer.Character.HumanoidRootPart.Impulses==1,"A touching giant could not shove beyond the normal root range")
 giantCombat.Advance(Config.AttackCooldown)
 nearbyPlayer.Character.HumanoidRootPart.Position=giantCombat.Vector(40,16,0)
 giantCombat:Send(giantAttacker,"Attack")
 assert(#nearbyPlayer.Character.HumanoidRootPart.Impulses==1,"Giant shove exceeded its server collider reach")

 local transport=createHarness({gameId=1,profile={Coins=300,Unlocked=1,Form=1}})
 local commuter=transport:AddPlayer(42)
 local toll=transport.Instance("Part");toll.Position=transport.Vector(0,16,0)
 assert(transport.World.Callbacks.OnBridge(commuter,toll,150))
 assert(transport:LatestState(commuter).Coins==150,"Bridge did not charge in-game money")
 commuter.Character.HumanoidRootPart.Position=transport.Vector(200,16,0)
 assert(not transport.World.Callbacks.OnBridge(commuter,toll,150),"Distant bridge payment was accepted")
 assert(transport:LatestState(commuter).Coins==150,"Rejected bridge payment changed coins")
 transport.World.Teleports.a={Part=toll,Cost=250};transport.World.Teleports.b={Name="Núi tuyết"}
 commuter.Character.HumanoidRootPart.Position=toll.Position
 assert(not transport.World.Callbacks.OnTeleport(commuter,"a","b"),"Teleport ignored insufficient funds")
 transport:Eat(commuter,{Hunger=0.5,Coins=150})
 assert(transport.World.Callbacks.OnTeleport(commuter,"a","b"))
 assert(transport:LatestState(commuter).Coins==50,"Teleport did not charge its source cost")
 assert(not transport.World.Callbacks.OnTeleport(commuter,"a","a"),"Same-node teleport charged money")

 -- Granting is durable/idempotent; delivery removes only the credit, never its receipt.
 local receipts=createHarness({gameId=1})
 local buyer=receipts:AddPlayer(50)
 assert(receipts.Commerce.Callbacks.CanPurchaseDrop(buyer))
 assert(receipts:Grant(buyer,"receipt-a"));receipts:Flush(buyer)
 assert(receipts:Stored(50).DropCredits["receipt-a"] and receipts.Events.RequestCounts["receipt-a"]==1)
 assert(receipts:Grant(buyer,"receipt-a"));receipts:Flush(buyer)
 assert(receipts.Events.RequestCounts["receipt-a"]==1,"Repeated receipt queued duplicate drops")
 assert(receipts:Delivered(buyer,"receipt-a"))
 assert(receipts:Stored(50).DropCredits["receipt-a"]==nil and receipts:Stored(50).ReceiptIds["receipt-a"])
 assert(receipts:Grant(buyer,"receipt-a"));receipts:Flush(buyer)
 assert(receipts:Stored(50).DropCredits["receipt-a"]==nil and receipts.Events.RequestCounts["receipt-a"]==1,"Delivered receipt was granted twice")
 receipts:FailUpdates(true);assert(not receipts:Grant(buyer,"receipt-b"))
 receipts:FailUpdates(false);assert(receipts:Grant(buyer,"receipt-b"))
 receipts:RejectDrops(true);receipts:Flush(buyer)
 assert(receipts.Events.RequestCounts["receipt-b"]==nil)
 receipts:RejectDrops(false);receipts.Advance(60)
 assert(receipts.Events.RequestCounts["receipt-b"]==1,"Unqueued durable credit was not retried")
 assert(receipts:Stored(50).DropDispatches["receipt-b"],"Queued paid drop was not durably reserved")
 local dispatch=receipts:Stored(50).DropDispatches["receipt-b"]
 assert(dispatch.Lease==receipts:UnixTime()+360,"Dispatch lease must cover the three-minute warning and delivery retries")
 -- Leaving saves ordinary progress while preserving pending delivery ownership.
 receipts:RemovePlayer(buyer)
 assert(receipts:Stored(50).DropDispatches["receipt-b"].Server==dispatch.Server,"Leave discarded an active dispatch lease")
 local recovered=createHarness({gameId=1,profile=receipts:Stored(50),timeBase=receipts:UnixTime()})
 local recoveredBuyer=recovered:AddPlayer(50)
 assert(recovered.Events.RequestCounts["receipt-b"]==nil,"Server hop duplicated an incoming paid drop")
 recovered.Advance(359)
 assert(recovered.Events.RequestCounts["receipt-b"]==nil,"Foreign dispatch lease expired too early")
 recovered.Advance(1)
 assert(recovered.Events.RequestCounts["receipt-b"]==1,"Expired crash lease never recovered its durable paid credit")
 assert(recovered:Stored(50).DropDispatches["receipt-b"].Server~=dispatch.Server,"Recovery did not transfer dispatch ownership")
 recovered:RemovePlayer(recoveredBuyer)
 local changed=recovered:Stored(50);changed.Session="newer-server";changed.Coins=1234
 assert(recovered:Delivered(recoveredBuyer,"receipt-b"))
 assert(recovered:Stored(50).Session=="newer-server" and recovered:Stored(50).Coins==1234,"Late delivery overwrote another session's progress")
 assert(recovered:Stored(50).DropCredits["receipt-b"]==nil)

 local retry=createHarness({gameId=1,profile={Coins=950,Unlocked=3,Form=3,Fullness=20}})
 local playing=retry:AddPlayer(60);retry:Eat(playing,{Hunger=5,Coins=100})
 retry:FailUpdates(true);retry.Advance(60)
 assert(retry:LatestState(playing).ReadOnly==false,"Transient save failure discarded session ownership")
 retry:FailUpdates(false);retry.Advance(60)
 assert(retry:Stored(60).Coins==1050 and retry:Stored(60).Fullness==25,"Autosave never recovered")
 retry:RemovePlayer(playing);assert(retry:Stored(60).Session==nil,"Leave retained saved session ownership")
 unpublished:Close();assert(unpublished:Updates()==0,"Temporary shutdown attempted persistence")
 print("PASS: actual server boot/loading/migration; fractional food/manual evolution/morph guards; pass rerolls and ecology entitlement callbacks; timed tonics across morph/mutation/evolution/death/expiry/rejoin; biome death/near cooldown; contact shoves; durable idempotent drops and cross-server dispatch leases; save retry")
end
