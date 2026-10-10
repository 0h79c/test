-- Run against the real Main.server source supplied by tools/test_runtime.py.
-- Roblox services are mocked; this catches startup and character lifecycle
-- regressions without pretending to replace physics tests in Studio.
local Config = require("../src/shared/Config")

return function(serverSource)
 local function createHarness(options)
  options = options or {}
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
  function scheduler.wait(seconds)
   return coroutine.yield(seconds or 0.03)
  end
  local function advance(seconds)
   local untilTime, iterations = now + (seconds or 0), 0
   while true do
    local index, earliest
    for i, entry in ipairs(queue) do
     if entry.At <= untilTime and (not earliest or entry.At < earliest) then
      index, earliest = i, entry.At
     end
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
    assert(iterations < 1000, "Server did not yield useful work")
   end
   now = untilTime
  end
  local function signal()
   local handlers = {}
   return {
    Connect=function(_, callback)
     table.insert(handlers, callback)
     return {Disconnect=function() table.remove(handlers, table.find(handlers, callback)) end}
    end,
    Fire=function(_, ...)
     for _, callback in ipairs(table.clone(handlers)) do scheduler.spawn(callback, ...) end
    end,
   }
  end
  local vectorMeta = {}
  local function vector(x, y, z)
   return setmetatable({X=x or 0, Y=y or 0, Z=z or 0}, vectorMeta)
  end
  vectorMeta.__index=function(v, key)
   if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
  end
  vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
  vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
  vectorMeta.__mul=function(a,b)
   if type(a) == "number" then a,b=b,a end
   return vector(a.X*b,a.Y*b,a.Z*b)
  end
  local instanceMethods, instanceMeta = {}, {}
  local workspaceMock
  instanceMeta.__index=function(object, key)
   if instanceMethods[key] then return instanceMethods[key] end
   if object._properties[key] ~= nil then return object._properties[key] end
   for _, child in ipairs(object._children) do
    if child.Name == key then return child end
   end
  end
  instanceMeta.__newindex=function(object, key, value)
   if key == "Parent" then
    local old = object._properties.Parent
    if old then
     local index=table.find(old._children,object)
     if index then table.remove(old._children,index) end
    end
    if value then table.insert(value._children,object) end
   end
   object._properties[key] = value
  end
  local function instance(className)
   local object = setmetatable({_properties={ClassName=className,Name=className},_children={},_attributes={}}, instanceMeta)
   if className == "RemoteEvent" then
    object.OnServerEvent=signal()
    object.Events={}
   elseif className == "Humanoid" then
    object.Health=100
    object.Died=signal()
   end
   return object
  end
  function instanceMethods:SetAttribute(key,value) self._attributes[key]=value end
  function instanceMethods:GetAttribute(key) return self._attributes[key] end
  function instanceMethods:FindFirstChild(name)
   for _,child in ipairs(self._children) do if child.Name == name then return child end end
  end
  function instanceMethods:WaitForChild(name)
   local child=self:FindFirstChild(name)
   assert(child,"Mock child missing: "..name)
   return child
  end
  function instanceMethods:FindFirstChildOfClass(className)
   for _,child in ipairs(self._children) do if child.ClassName == className then return child end end
  end
  function instanceMethods:GetChildren() return table.clone(self._children) end
  function instanceMethods:IsA(className) return self.ClassName == className end
  function instanceMethods:FireClient(player,action,data)
   table.insert(self.Events,{Player=player,Action=action,Data=data})
  end
  function instanceMethods:PivotTo(cf)
   self.LastPivot=cf
   local root=self:FindFirstChild("HumanoidRootPart")
   if root then root.Position=cf.Position; root.CFrame=cf end
  end
  function instanceMethods:Kick(message) self.Kicked=message end
  function instanceMethods:LoadCharacterAsync()
   self.LoadCount=(self.LoadCount or 0)+1
   local character=instance("Model"); character.Name=self.Name
   local root=instance("Part"); root.Name="HumanoidRootPart"; root.Position=vector(); root.Parent=character
   root.CFrame={Position=root.Position}
   local humanoid=instance("Humanoid"); humanoid.Parent=character
   character.Parent=workspaceMock
   self.Character=character
   self.CharacterAdded:Fire(character)
   return character
  end
  instanceMethods.LoadCharacter=instanceMethods.LoadCharacterAsync

  local replicated=instance("Folder")
  local shared=instance("Folder"); shared.Name="Shared"; shared.Parent=replicated
  local configModule=instance("ModuleScript"); configModule.Name="Config"; configModule.Parent=shared
  local scriptParent=instance("Folder")
  local characterModule=instance("ModuleScript"); characterModule.Name="Character"; characterModule.Parent=scriptParent
  local worldModule=instance("ModuleScript"); worldModule.Name="World"; worldModule.Parent=scriptParent
  local serverScript=instance("Script"); serverScript.Parent=scriptParent
  local players=instance("Players")
  players.RespawnTime=5
  players.PlayerAdded=signal(); players.PlayerRemoving=signal()
  local playerList={}
  function players:GetPlayers() return table.clone(playerList) end
  function players:GetPlayerFromCharacter(character)
   for _,p in ipairs(playerList) do if p.Character == character then return p end end
  end
  local function makePlayer(id)
   local p=instance("Player"); p.UserId=id; p.Name="Player"..id
   p.CharacterAdded=signal(); p.CharacterAppearanceLoaded=signal(); p.Parent=players
   table.insert(playerList,p)
   return p
  end
  workspaceMock=instance("Workspace")
  workspaceMock.Gravity=196.2
  local world={Checkpoints={},CoinPositions={},BuildCount=0}
  for i=0,140 do world.Checkpoints[i]={Position=vector(i*24,15,0)} end
  world.SpawnLocation=instance("SpawnLocation")
  function world.Build(onCheckpoint,onCoin,onStation)
   world.BuildCount+=1
   world.OnCheckpoint=onCheckpoint; world.OnCoin=onCoin; world.OnStation=onStation
   return instance("Folder")
  end
  local applied={}
  local character={Apply=function(p,data)
   assert(p.Character,"Morph attempted before character existed")
   assert(p.Character:FindFirstChild("HumanoidRootPart"),"Morph attempted without root")
   table.insert(applied,{Player=p,Form=data.Form,Checkpoint=data.Checkpoint})
   p.Character:SetAttribute("Form",data.Form)
  end}
  local stored=options.profile
  local updates,acquisitions=0,0
  local store={UpdateAsync=function(_,_,callback)
   updates+=1
   local call=updates
   if options.loadDelay and call == 1 then scheduler.wait(options.loadDelay) end
   if options.updateFailure then error("API Services unavailable") end
   local result=callback(stored)
   if result ~= nil then stored=result end
   if options.returnDelay and call == 1 then scheduler.wait(options.returnDelay) end
   return result
  end}
  local dataStore={GetDataStore=function()
   acquisitions+=1
   if options.acquireFailure then error("You must publish this place to access DataStore") end
   return store
  end}
  local gameMock={ReplicatedStorage=replicated,Players=players,
   GameId=options.gameId or 0,PlaceId=options.gameId or 0,JobId="test-job"}
  local guidCount=0
  function gameMock:GetService(name)
   if name == "Players" then return players
   elseif name == "DataStoreService" then return dataStore
   elseif name == "HttpService" then return {GenerateGUID=function()
    guidCount+=1; return "runtime-test-guid-"..guidCount
   end}
   elseif name == "RunService" then return {IsStudio=function() return options.studio ~= false end}
   elseif name == "ReplicatedStorage" then return replicated
   elseif name == "Workspace" then return workspaceMock end
   error("Unhandled service: "..name)
  end
  function gameMock:BindToClose(callback) self.OnClose=callback end
  local environment=setmetatable({
   game=gameMock,workspace=workspaceMock,script=serverScript,task=scheduler,
   Instance={new=instance},Vector3={new=vector,zero=vector()},
   CFrame={new=function(x,y,z) return {Position=vector(x,y,z)} end},
   Random={new=function() return {NextInteger=function(_,minimum) return minimum end} end},
   warn=function(...) table.insert(warnings,table.pack(...)) end,
   os={time=function() return 10000+math.floor(now) end,clock=function() return now end},
   require=function(module)
    if module == configModule then return Config
    elseif module == characterModule then return character
    elseif module == worldModule then return world end
    error("Unexpected module require")
   end,
  },{__index=getfenv()})
  local before=options.existing and makePlayer(101) or nil
  local chunk,compileError=loadstring(serverSource,"Main.server.luau")
  assert(chunk,compileError)
  setfenv(chunk,environment)
  scheduler.spawn(chunk)
  advance(0)
  local h={World=world,Applied=applied,Warnings=warnings,Players=players,Existing=before,Advance=advance}
  function h:AddPlayer(id)
   local p=makePlayer(id); players.PlayerAdded:Fire(p); advance(0); return p
  end
  function h:Remote() return replicated:FindFirstChild("EvolutionEvent") end
  function h:LatestState(p)
   for i=#self:Remote().Events,1,-1 do
    local event=self:Remote().Events[i]
    if event.Player == p and event.Action == "State" then return event.Data end
   end
  end
  function h:Acquisitions() return acquisitions end
  function h:Updates() return updates end
  function h:Stored() return stored end
  function h:FailUpdates(value) options.updateFailure=value end
  function h:RemovePlayer(p)
   p.Parent=nil
   players.PlayerRemoving:Fire(p)
   advance(0)
  end
  function h:Close()
   scheduler.spawn(gameMock.OnClose)
   advance(0)
  end
  function h:Respawn(p)
   local humanoid=p.Character:FindFirstChildOfClass("Humanoid")
   humanoid.Health=0; humanoid.Died:Fire(); advance(6)
  end
  return h
 end

 local function assertReady(h,p,checkpoint,form)
  assert(h.World.BuildCount == 1,"Server must build world exactly once")
  assert(p.Character,"Player never received a character")
  assert(p.Character:GetAttribute("Form") == form,"Player kept the default avatar")
  assert(p.Character.LastPivot == h.World.Checkpoints[checkpoint],"Player spawned away from a safe checkpoint")
  assert(p.leaderstats.Checkpoint.Value == checkpoint,"Checkpoint state did not synchronize")
  assert(h:LatestState(p),"Client never received initial state")
 end

 local unpublished=createHarness({acquireFailure=true})
 local player=unpublished:AddPlayer(1)
 unpublished.Advance(1)
 assertReady(unpublished,player,0,1)
 assert(unpublished:Acquisitions() == 0,"Unpublished Studio must use a temporary profile without touching DataStore")
 assert(unpublished:LatestState(player).ReadOnly,"Unpublished session must report unsaved progress")

 local acquisitionFailure=createHarness({studio=false,gameId=1,acquireFailure=true})
 local fallback=acquisitionFailure:AddPlayer(2)
 acquisitionFailure.Advance(1)
 assertReady(acquisitionFailure,fallback,0,1)
 assert(acquisitionFailure:Acquisitions() == 1,"DataStore access was never attempted in a published game")
 assert(acquisitionFailure:LatestState(fallback).ReadOnly,"Store acquisition failure must preserve a playable temporary session")

 local denied=createHarness({gameId=1,updateFailure=true})
 local temporary=denied:AddPlayer(3)
 denied.Advance(1)
 assertReady(denied,temporary,0,1)
 assert(denied:LatestState(temporary).ReadOnly,"Disabled API Services must not silently promise persistence")

 local restored=createHarness({gameId=1,existing=true,profile={Coins=950,Checkpoint=20,Form=3,Mutations={['1']="Normal",['2']="Giant",['3']="Tiny"}}})
 restored.Advance(1)
 assertReady(restored,restored.Existing,20,3)
 assert(restored.Existing.leaderstats.Coins.Value == 950,"Stored coins were overwritten at startup")
 restored:Respawn(restored.Existing)
 assertReady(restored,restored.Existing,20,3)
 assert(restored.Existing.LoadCount >= 2,"Death never respawned the player")

 local slow=createHarness({gameId=1,loadDelay=0.5,profile={Coins=600,Checkpoint=10,Form=2,Mutations={['1']="Normal",['2']="Normal"}}})
 local loading=slow:AddPlayer(5)
 assert(loading.Character,"A slow DataStore request prevented safe character spawning")
 local root=loading.Character:FindFirstChild("HumanoidRootPart")
 root.Position=slow.World.Checkpoints[1].Position
 slow.World.OnCheckpoint(loading,1)
 slow:Remote().OnServerEvent:Fire(loading,"Morph",2)
 slow.Advance(0.1)
 assert(loading.leaderstats.Checkpoint.Value == 0,"Checkpoint rewards must wait until the profile claim finishes")
 slow.Advance(0.6)
 assertReady(slow,loading,10,2)
 assert(loading.leaderstats.Coins.Value == 600,"Temporary startup state overwrote the real profile")

 local departed=createHarness({gameId=1,loadDelay=0.5})
 local leaving=departed:AddPlayer(6)
 departed:RemovePlayer(leaving)
 departed.Advance(1)
 assert(departed:Stored().Session == nil,"Leaving during profile loading retained a stale session lease")
 assert(departed:Stored().Lease == 0,"Leaving during profile loading did not release the lease")

 -- Simulate a response that arrives after its original lease has expired.
 -- A subsequent join can now own the same profile in this server.
 local rejoin=createHarness({gameId=1,returnDelay=181})
 local original=rejoin:AddPlayer(9)
 rejoin:RemovePlayer(original)
 rejoin.Advance(180.1)
 local current=rejoin:AddPlayer(9)
 local currentSession=rejoin:Stored().Session
 assertReady(rejoin,current,0,1)
 rejoin.Advance(1)
 assert(rejoin:Stored().Session == currentSession,"Late loading cleanup released a newer join's lease")
 assert(rejoin:Stored().Lease > 10181,"Late loading cleanup invalidated a newer join's lease")

 local foreign=createHarness({gameId=1,profile={Coins=123,Checkpoint=10,Form=2,Mutations={},Session="other-server",Lease=20000}})
 local rejected=foreign:AddPlayer(7)
 foreign.Advance(1)
 assert(rejected.Kicked,"A locked profile was accepted by a second server")
 assert(foreign:Stored().Session == "other-server" and foreign:Stored().Coins == 123,"Another server's saved profile was overwritten")

 local retry=createHarness({gameId=1,profile={Coins=950,Checkpoint=20,Form=3,Mutations={['1']="Normal",['2']="Normal",['3']="Normal"}}})
 local playing=retry:AddPlayer(8)
 retry.Advance(1)
 playing.Character.HumanoidRootPart.Position=retry.World.Checkpoints[21].Position
 retry.World.OnCheckpoint(playing,21)
 retry:FailUpdates(true)
 retry.Advance(60)
 assert(retry:LatestState(playing).ReadOnly == false,"A temporary save error discarded session ownership")
 retry:FailUpdates(false)
 retry.Advance(60)
 assert(retry:Stored().Coins == 1050 and retry:Stored().Checkpoint == 21,"Autosave did not recover after a transient DataStore error")
 retry:RemovePlayer(playing)
 assert(retry:Stored().Session == nil,"PlayerRemoving did not release saved session ownership")

 unpublished:Close()
 assert(unpublished:Updates() == 0,"Temporary sessions attempted to persist during shutdown")

 print("PASS: DataStore boot/failure/retry; existing players; restored profile; death/respawn; delayed loading; leave-during-load; session locks")
end
