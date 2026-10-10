local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Character = require(script.Parent:WaitForChild("Character"))
local World = require(script.Parent:WaitForChild("World"))

-- Never let Roblox spawn an avatar above an uninitialized world.
Players.CharacterAutoLoads = false
workspace:SetAttribute("EvolutionStatus", "Starting")
local rng = Random.new()
local profiles, stations, lastAction, saving = {}, {}, {}, {}
local session = HttpService:GenerateGUID(false)
local remote = game.ReplicatedStorage:FindFirstChild("EvolutionEvent") or Instance.new("RemoteEvent")
remote.Name = "EvolutionEvent"
remote.Parent = game.ReplicatedStorage
local store

local function defaultProfile()
 return {Coins=0, Checkpoint=0, Form=1, Mutations={["1"]="Normal"}, Collected={}, Loading=true, ReadOnly=true}
end
local function integer(value, minimum, maximum, fallback)
 if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
 return math.clamp(math.floor(value), minimum, maximum)
end
local function sync(player, message)
 local data = profiles[player]
 if not data or not player.Parent then return end
 local stats = player:FindFirstChild("leaderstats")
 if stats then
  stats.Coins.Value = data.Coins
  stats.Checkpoint.Value = data.Checkpoint
 end
 remote:FireClient(player, "State", {
  Coins=data.Coins, Checkpoint=data.Checkpoint, Form=data.Form,
  Unlocked=Config.Unlocked(data.Checkpoint), Mutations=table.clone(data.Mutations),
  Message=message, ReadOnly=data.ReadOnly, Loading=data.Loading,
 })
end
local function alive(player)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health <= 0 then return nil end
 return root, humanoid
end
local function placeCharacter(player)
 local data = profiles[player]
 local root = alive(player)
 if not data or not root then return end
 local destination = World.Checkpoints[data.Checkpoint] or World.Checkpoints[0]
 player.Character:PivotTo(destination)
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 Character.Apply(player, data)
 sync(player)
end
local function save(player, release)
 local data = profiles[player]
 if not store or not data or data.ReadOnly or data.Loading then return end
 while saving[player] do task.wait(0.1) end
 -- A concurrent leave/save may have released the profile while we waited.
 if profiles[player] ~= data or data.ReadOnly or data.Loading then return end
 saving[player] = true
 local payload = {
  Coins=data.Coins, Checkpoint=data.Checkpoint, Form=data.Form,
  Mutations=table.clone(data.Mutations), Lease=release and 0 or os.time()+180,
 }
 if not release then payload.Session = data.SessionToken end
 local ok, result = pcall(function()
  return store:UpdateAsync("player_"..player.UserId, function(old)
   if typeof(old) ~= "table" or old.Session ~= data.SessionToken then return nil end
   return payload
  end)
 end)
 saving[player] = nil
 if not ok then
  warn("Evolution save failed for user", player.UserId, result)
  sync(player, "Chưa lưu được tiến trình; máy chủ sẽ thử lại ở lần autosave tiếp theo.")
 elseif not result then
  data.ReadOnly = true
  sync(player, "Mất khóa dữ liệu: phiên này sẽ không ghi đè tiến trình đã lưu.")
 end
end
local function checkpoint(player, stage)
 local data = profiles[player]
 if not data or data.Loading or stage ~= data.Checkpoint+1 then return end
 local root = alive(player)
 local destination = World.Checkpoints[stage]
 if not root or not destination or (root.Position-destination.Position).Magnitude > 24 then return end
 local previous = Config.Unlocked(data.Checkpoint)
 data.Checkpoint = stage
 data.Coins = math.min(2147483647, data.Coins+Config.CheckpointReward)
 local unlocked = Config.Unlocked(stage)
 local message
 if unlocked > previous then
  data.Form = unlocked
  data.Mutations[tostring(unlocked)] = Config.Roll(rng)
  Character.Apply(player, data)
  message = "Tiến hóa! Đã mở "..Config.Species[unlocked].Name
 end
 if stage == 140 then message = "Hoàn thành hành trình! Bạn đã mở khóa Rồng Trắng." end
 sync(player, message)
end

-- Map, spawn and prompts are always available, even without an online DataStore.
if Character.Initialize then Character.Initialize() end
World.Build(checkpoint, function(player, id, value, coin)
 local data = profiles[player]
 if not data or data.Loading or data.Collected[id] then return end
 local root = alive(player)
 local position = coin and coin.Position or (World.CoinPositions and World.CoinPositions[id])
 if not root or not position or (root.Position-position).Magnitude > 12 then return end
 local stage = coin and coin:GetAttribute("Stage")
 if stage and math.abs(stage-data.Checkpoint)>1 then return end
 data.Collected[id] = true
 data.Coins = math.min(2147483647, data.Coins+value)
 remote:FireClient(player, "Coin", id)
 sync(player, "+"..value.." Coins")
end, function(player, station)
 if profiles[player] then
  stations[player] = station
  remote:FireClient(player, "Station")
 end
end)
workspace:SetAttribute("EvolutionStatus", "Ready")

-- GetDataStore itself can throw in an unpublished place, not just Get/UpdateAsync.
-- Persistence must not be a prerequisite for constructing the world or morphing.
if not (RunService:IsStudio() and game.GameId == 0) then
 local ok, result = pcall(function() return DataStoreService:GetDataStore("EvolutionObby_v1") end)
 if ok then store = result else warn("Evolution DataStore unavailable; using temporary progress", result) end
end
workspace:SetAttribute("EvolutionPersistence", store and "Available" or "Temporary")

remote.OnServerEvent:Connect(function(player, action, value)
 local data = profiles[player]
 if not data then return end
 if typeof(action) ~= "string" then return end
 if lastAction[player] and os.clock()-lastAction[player]<0.35 then return end
 lastAction[player] = os.clock()
 if action == "Sync" then sync(player); return end
 local root = alive(player)
 if not root then return end
 if data.Loading then sync(player, "Đang tải tiến trình. Bạn có thể xem map trong lúc chờ."); return end
 if action == "Morph" then
  if typeof(value) ~= "number" or value ~= value or value%1 ~= 0 or value<1 or value>Config.Unlocked(data.Checkpoint) then return end
  data.Form = value
  Character.Apply(player, data)
  sync(player, "Đã chuyển sang "..Config.Species[value].Name)
 elseif action == "Reroll" then
  local station = stations[player]
  if not station or not station.Parent or (root.Position-station.Position).Magnitude>16 then
   sync(player, "Hãy đến trạm đột biến màu tím."); return
  end
  if data.Coins<Config.RerollCost then sync(player, "Không đủ 500 Coins."); return end
  data.Coins -= Config.RerollCost
  data.Mutations[tostring(data.Form)] = Config.Roll(rng)
  Character.Apply(player, data)
  remote:FireClient(player, "Mutation", data.Mutations[tostring(data.Form)])
  sync(player, "Đột biến: "..Config.Mutation(data.Mutations[tostring(data.Form)]).Label)
 elseif action == "Checkpoint" then
  placeCharacter(player)
 elseif action == "Lobby" then
  player.Character:PivotTo(World.Checkpoints[0])
  root.AssemblyLinearVelocity = Vector3.zero
  root.AssemblyAngularVelocity = Vector3.zero
  sync(player, "Về sảnh. Nút Về checkpoint giúp bạn tiếp tục hành trình.")
 end
end)

local function loadProfile(player)
 local data = profiles[player]
 if not data then return end
 local token = data.SessionToken
 if not store then
  data.Loading = false
  sync(player, "Chế độ chơi thử: map và tiến hóa hoạt động; tiến trình chưa được lưu.")
  return
 end
 local acquired
 local ok, err = pcall(function()
  acquired = store:UpdateAsync("player_"..player.UserId, function(old)
   if typeof(old) == "table" and old.Session and (tonumber(old.Lease) or 0)>os.time() and old.Session ~= token then return nil end
   local nextData = typeof(old) == "table" and table.clone(old) or defaultProfile()
   nextData.Loading=nil; nextData.ReadOnly=nil; nextData.Collected=nil; nextData.SessionToken=nil
   nextData.Session=token; nextData.Lease=os.time()+180
   return nextData
  end)
 end)
 if profiles[player] ~= data or not player.Parent then
  -- Release only the lease acquired by this server if the player left while loading.
  if ok and acquired then
   pcall(function() store:UpdateAsync("player_"..player.UserId, function(old)
    if typeof(old) == "table" and old.Session == token then old.Session=nil; old.Lease=0; return old end
    return nil
   end) end)
  end
  return
 end
 if ok and not acquired then
  player:Kick("Tiến trình đang mở ở máy chủ khác. Vui lòng thử lại sau.")
  return
 end
 if not ok then
  warn("Evolution load unavailable; temporary progress only", player.UserId, err)
  data.Loading = false
  sync(player, "DataStore chưa khả dụng. Bạn vẫn chơi được; phiên này không lưu tiến trình.")
  return
 end
 data.Checkpoint = integer(acquired.Checkpoint,0,140,0)
 data.Coins = integer(acquired.Coins,0,2147483647,0)
 data.Form = integer(acquired.Form,1,Config.Unlocked(data.Checkpoint),1)
 data.Mutations = {}
 for i=1,Config.Unlocked(data.Checkpoint) do
  local name = typeof(acquired.Mutations)=="table" and acquired.Mutations[tostring(i)] or "Normal"
  data.Mutations[tostring(i)] = Config.Mutation(name).Name
 end
 data.Loading=false; data.ReadOnly=false
 placeCharacter(player)
 sync(player, "Đã tải tiến trình. Chào mừng trở lại!")
end

local function addPlayer(player)
 if profiles[player] then return end
 profiles[player] = defaultProfile()
 profiles[player].SessionToken = session..":"..HttpService:GenerateGUID(false)
 local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
 stats.Name="leaderstats"; stats.Parent=player
 for _, name in ipairs({"Coins", "Checkpoint"}) do
  if not stats:FindFirstChild(name) then
   local v=Instance.new("IntValue"); v.Name=name; v.Parent=stats
  end
 end
 local spawning = false
 local function requestSpawn()
  if not profiles[player] or not player.Parent or spawning then return end
  spawning = true
  local ok, err = pcall(function() player:LoadCharacterAsync() end)
  spawning = false
  if not ok then warn("Evolution character spawn failed", player.UserId, err) end
 end
 local function prepare(character)
  local root = character:WaitForChild("HumanoidRootPart",15)
  local humanoid = character:WaitForChild("Humanoid",15)
  if not root or not humanoid or not profiles[player] or player.Character ~= character then return end
  placeCharacter(player)
  humanoid.Died:Connect(function()
   task.delay(Players.RespawnTime, function()
    if player.Character==character then requestSpawn() end
   end)
  end)
  -- Accessories can arrive after CharacterAdded; re-hide them after appearance loads.
 end
 player.CharacterAdded:Connect(function(character) task.spawn(prepare,character) end)
 player.CharacterAppearanceLoaded:Connect(function(character)
  if player.Character==character and profiles[player] then Character.Apply(player,profiles[player]) end
 end)
 if player.Character then task.spawn(prepare, player.Character) else task.spawn(requestSpawn) end
 sync(player)
 task.spawn(loadProfile, player)
end
Players.PlayerAdded:Connect(addPlayer)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(addPlayer,player) end
Players.PlayerRemoving:Connect(function(player)
 save(player,true)
 profiles[player]=nil; stations[player]=nil; lastAction[player]=nil
end)
task.spawn(function()
 while true do
  task.wait(60)
  for player in pairs(profiles) do task.spawn(save,player,false) end
 end
end)
game:BindToClose(function()
 local pending = 0
 for player in pairs(profiles) do
  pending += 1
  task.spawn(function() save(player,true); pending-=1 end)
 end
 while pending>0 do task.wait(0.1) end
end)
