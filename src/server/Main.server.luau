-- Evolution Wilds: services are independent of persistence so Studio can play
-- an unpublished world. Every economy, combat and purchase decision is server-side.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("Rules"))
local Character = require(script.Parent:WaitForChild("Character"))
local World = require(script.Parent:WaitForChild("World"))
local Ecology = require(script.Parent:WaitForChild("Ecology"))
local Events = require(script.Parent:WaitForChild("Events"))
local Commerce = require(script.Parent:WaitForChild("Commerce"))
local Buffs = require(script.Parent:WaitForChild("Buffs"))

Players.CharacterAutoLoads = false
workspace:SetAttribute("EvolutionStatus", "Starting")
local profiles, locks, recentContacts, lastAction, lastAttack = {}, {}, {}, {}, {}
local serverToken = HttpService:GenerateGUID(false)
local rng = Random.new()
local remote = ReplicatedStorage:FindFirstChild("EvolutionEvent") or Instance.new("RemoteEvent")
remote.Name = "EvolutionEvent"
remote.Parent = ReplicatedStorage
local store
local flushCredits

local function alive(player)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health <= 0 then return nil end
 return root, humanoid
end
local function applyCharacter(player,data)
 data=data or profiles[player]
 if not data then return false end
 data.BuffModifiers=Buffs.GetModifiers(player)
 return Character.Apply(player,data)
end
local function volume(player)
 local collider = player.Character and player.Character:FindFirstChild("AnimalCollider")
 return collider and collider.Size.X*collider.Size.Y*collider.Size.Z or 0
end
local function positionRecord(position, biome)
 return {X=position.X,Y=position.Y,Z=position.Z,Biome=biome}
end
local function storedVector(value)
 if typeof(value)~="table" then return nil end
 for _, axis in ipairs({"X","Y","Z"}) do
  if typeof(value[axis])~="number" or value[axis]~=value[axis] or math.abs(value[axis])>100000 then return nil end
 end
 return Vector3.new(value.X,value.Y,value.Z)
end
local function metadata(raw)
 local credits, receipts, dispatches = {}, {}, {}
 if typeof(raw)=="table" then
  for key, value in pairs(typeof(raw.DropCredits)=="table" and raw.DropCredits or {}) do
   if typeof(key)=="string" and #key>0 and #key<=200 and value==true then credits[key]=true end
  end
  for key, value in pairs(typeof(raw.ReceiptIds)=="table" and raw.ReceiptIds or {}) do
   if typeof(key)=="string" and #key>0 and #key<=200 and typeof(value)=="number" then receipts[key]=value end
  end
  for key,value in pairs(typeof(raw.DropDispatches)=="table" and raw.DropDispatches or {}) do
   if typeof(key)=="string" and #key<=200 and typeof(value)=="table" and typeof(value.Server)=="string"
    and typeof(value.Lease)=="number" and value.Lease==value.Lease then
    dispatches[key]={Server=value.Server,Lease=value.Lease}
   end
  end
 end
 return credits, receipts, dispatches
end
local function sync(player, message)
 local data=profiles[player]
 if not data or not player.Parent then return end
 local root=alive(player)
 local biome=(root and World.PositionBiome(root.Position)) or data.Biome or "meadow"
 data.Biome=biome
 local stats=player:FindFirstChild("leaderstats")
 if stats then
  stats.Coins.Value=data.Coins
  stats.Evolution.Value=data.Unlocked
 end
 local now=os.time()
 local offer=data.LastDeath and math.max(0,Config.NearRespawnOfferSeconds-(now-data.LastDeath.At)) or 0
 local cooldown=math.max(0,(data.NearReviveReadyAt or 0)-now)
 local availability=Commerce.GetAvailability(player)
 availability.DropAvailable=availability.DropAvailable and store~=nil and not data.ReadOnly and not data.Loading
 remote:FireClient(player,"State",{
  Coins=data.Coins,Fullness=data.Fullness,Form=data.Form,Unlocked=data.Unlocked,
  Mutations=table.clone(data.Mutations),FreeRerolls=data.FreeRerolls,LastMutationBoost=data.LastMutationBoost,
  PassOwned=Commerce.HasPass(player),ReadOnly=data.ReadOnly,Loading=data.Loading,
  Buffs=Buffs.GetState(player),
  Biome=biome,ReviveAvailable=Commerce.HasPass(player) and offer>0 and cooldown==0,
  ReviveCooldown=cooldown,ReviveExpiresIn=offer,Commerce=availability,CommerceConfig=Config.Commerce,Message=message,
 })
end
local function grantProtection(player, seconds)
 local data=profiles[player]
 if not data then return end
 data.ProtectedUntil=os.clock()+seconds
 if player.Character then player.Character:SetAttribute("SpawnProtectedUntil",workspace:GetServerTimeNow()+seconds) end
end
local function teleportCharacter(player, destination)
 local root=alive(player)
 if not root or not destination then return false end
 player.Character:PivotTo(destination)
 root.AssemblyLinearVelocity=Vector3.zero
 root.AssemblyAngularVelocity=Vector3.zero
 return true
end
local function copyProgress(data, old, release)
 local payload=Rules.Normalize(data)
 payload.DropCredits,payload.ReceiptIds,payload.DropDispatches=metadata(old)
 payload.NearReviveReadyAt=data.NearReviveReadyAt or 0
 payload.Position=data.LastPosition
 payload.Lease=release and 0 or os.time()+180
 if not release then payload.Session=data.SessionToken end
 return payload
end
local function acquireLock(userId)
 while locks[userId] do task.wait(0.05) end
 locks[userId]=true
end
local function save(player, release)
 local data=profiles[player]
 if not store or not data or data.ReadOnly or data.Loading then return false end
 acquireLock(player.UserId)
 if profiles[player]~=data or data.ReadOnly or data.Loading then locks[player.UserId]=nil; return false end
 local root=alive(player)
 if root and World.IsSafe(root.Position) then
  data.LastPosition=positionRecord(root.Position,World.PositionBiome(root.Position))
 end
 local ok,result=pcall(function()
  return store:UpdateAsync("player_"..player.UserId,function(old)
   if typeof(old)~="table" or old.Session~=data.SessionToken then return nil end
   return copyProgress(data,old,release)
  end)
 end)
 locks[player.UserId]=nil
 if not ok then
  warn("Evolution save unavailable",player.UserId,result)
  sync(player,"Chưa lưu được tiến trình; máy chủ sẽ thử lại.")
  return false
 end
 if not result then
  data.ReadOnly=true
  sync(player,"Mất khóa dữ liệu: phiên này không ghi đè tiến trình đã lưu.")
  return false
 end
 data.DropCredits,data.ReceiptIds,data.DropDispatches=metadata(result)
 return true
end
local function grantDropCredit(player,purchaseId)
 local data=profiles[player]
 if not store or not data or data.Loading or data.ReadOnly then return false end
 acquireLock(player.UserId)
 local accepted=false
 local ok,result=pcall(function()
  return store:UpdateAsync("player_"..player.UserId,function(old)
   if typeof(old)~="table" or old.Session~=data.SessionToken then accepted=false; return nil end
   local nextData=copyProgress(data,old,false)
   if not nextData.ReceiptIds[purchaseId] then
    nextData.ReceiptIds[purchaseId]=os.time()
    nextData.DropCredits[purchaseId]=true
   end
   accepted=true
   return nextData
  end)
 end)
 locks[player.UserId]=nil
 if ok and accepted and result then
  data.DropCredits,data.ReceiptIds,data.DropDispatches=metadata(result)
  return true
 end
 return false
end
local function acknowledgeDrop(sponsor,purchaseId)
 -- Touch only this purchase's credit, even if the sponsor left or rejoined.
 -- Progress/session fields belonging to another server remain untouched.
 if not store or not sponsor then return false end
 local userId=sponsor.UserId
 acquireLock(userId)
 local acknowledged=false
 local ok,result=pcall(function()
  return store:UpdateAsync("player_"..userId,function(old)
   if typeof(old)~="table" then return nil end
   local credits,receipts,dispatches=metadata(old)
   if not receipts[purchaseId] then return nil end
   credits[purchaseId]=nil
   dispatches[purchaseId]=nil
   old.DropCredits=credits
   old.DropDispatches=dispatches
   acknowledged=true
   return old
  end)
 end)
 locks[userId]=nil
 if ok and acknowledged and result then
  local current=Players:GetPlayerByUserId(userId)
  if current and profiles[current] then
   profiles[current].DropCredits[purchaseId]=nil
   profiles[current].DropDispatches[purchaseId]=nil
  end
  return true
 end
 return false
end
local function reserveDispatch(player,purchaseId,release)
 local data=profiles[player]
 if not store or not data or data.ReadOnly or data.Loading then return false end
 acquireLock(player.UserId)
 local reserved=false
 local ok,result=pcall(function()
  return store:UpdateAsync("player_"..player.UserId,function(old)
   reserved=false
   if typeof(old)~="table" or old.Session~=data.SessionToken then return nil end
   local credits,receipts,dispatches=metadata(old)
   if not credits[purchaseId] or not receipts[purchaseId] then return nil end
   local dispatch=dispatches[purchaseId]
   if release then
    if dispatch and dispatch.Server==serverToken then dispatches[purchaseId]=nil end
   else
    -- A pending paid drop belongs to one server until it lands or this lease
    -- expires after a crash. Rejoining cannot announce it on every server.
    if dispatch and dispatch.Server~=serverToken and dispatch.Lease>os.time() then return nil end
    dispatches[purchaseId]={Server=serverToken,Lease=os.time()+360}
    reserved=true
   end
   old.DropDispatches=dispatches
   return old
  end)
 end)
 locks[player.UserId]=nil
 if ok and result then data.DropCredits,data.ReceiptIds,data.DropDispatches=metadata(result) end
 return ok and reserved
end
flushCredits=function(player)
 local data=profiles[player]
 if not data or data.ReadOnly or data.Loading then return end
 for purchaseId in pairs(data.DropCredits) do
  if not data.QueuedCredits[purchaseId] and reserveDispatch(player,purchaseId,false) then
   if Events.RequestPurchasedDrop(player,purchaseId) then data.QueuedCredits[purchaseId]=true
   else reserveDispatch(player,purchaseId,true) end
  end
 end
end

local function canEat(player)
 local data=profiles[player]
 return data~=nil and not data.Loading and alive(player)~=nil
end
local function awardFood(player,spec,source)
 local data=profiles[player]
 if not data or not canEat(player) then return end
 local gain, coins=Rules.AddFood(data,spec,Commerce.HasPass(player))
 local mutated=source and source.MutationFood
 local message=string.format("%s: +%g%% no · +%d Coins",spec.Name or "Thức ăn",gain,coins)
 local buff=spec.Buff and Buffs.Apply(player,spec.Buff)
 if buff then
  local description=spec.Buff=="Speed" and "+50% tốc chạy"
   or spec.Buff=="Hunt" and ("Săn vượt "..tostring(buff.Tiers or 2).." bậc") or "Kích thước ×5"
  message=(spec.Name or "Thuốc")..": "..description.." · "..Config.Buffs.Duration.." giây"
 end
 if mutated then
  local name=Rules.StartMutation(data,rng,source.Boost==3 and 3 or 1,Commerce.HasPass(player))
  applyCharacter(player,data)
  message="Thức ăn đột biến: "..Config.Mutation(name).Label..(data.FreeRerolls>0 and " · 2 reroll miễn phí" or "")
  remote:FireClient(player,"Mutation",name)
 end
 local root=alive(player)
 remote:FireClient(player,"Food",{Gain=gain,Coins=coins,Position=root and root.Position,Name=spec.Name,MutationFood=mutated,
  Buff=buff and spec.Buff,EffectName=buff and spec.Name})
 if buff then
  remote:FireClient(player,"Buff",{Kind=spec.Buff,Name=spec.Name,Duration=Config.Buffs.Duration,Tiers=buff.Tiers})
 end
 if Rules.CanEvolve(data) then message..=" · Đủ no! Nhấn Tiến hóa." end
 sync(player,message)
end
local function buyTeleport(player,sourceId,destinationId)
 local data=profiles[player]
 local root=alive(player)
 local source=World.Teleports[sourceId]
 local destination=World.Teleports[destinationId]
 if not data or data.Loading or not root or not source or not destination or sourceId==destinationId then return false end
 local part=source.Part
 if not part or (root.Position-part.Position).Magnitude>18 then return false end
 local cost=source.Cost or 150
 if data.Coins<cost then sync(player,"Cần "..cost.." Coins để dịch chuyển."); return false end
 data.Coins-=cost
 sync(player,"Dịch chuyển đến "..(destination.Name or destinationId).." · -"..cost.." Coins")
 grantProtection(player,2)
 return true
end
Character.Initialize()
Buffs.Start({OnChanged=function(player)
 local data=profiles[player]
 if not data then return end
 if alive(player) then applyCharacter(player,data) end
 sync(player)
end})
World.Build({
 OnBridge=function(player,part,cost)
  local data=profiles[player]; local root=alive(player)
  if not data or data.Loading or not root or (root.Position-part.Position).Magnitude>part.Size.Magnitude/2+25 then return false end
  if data.Coins<cost then sync(player,"Qua cầu cần "..cost.." Coins; bạn có thể nhảy qua đá miễn phí."); return false end
  data.Coins-=cost; sync(player,"Phí cầu: -"..cost.." Coins")
  return true
 end,
 OnTeleport=buyTeleport,
 OnTeleportMenu=function(player,sourceId,destinations)
  remote:FireClient(player,"TeleportMenu",{SourceId=sourceId,Destinations=destinations})
 end,
})
workspace:SetAttribute("EvolutionStatus","Ready")

-- Do not let persistence block open-world construction or the starter animal.
if not (RunService:IsStudio() and game.GameId==0) then
 local ok,result=pcall(function() return DataStoreService:GetDataStore("EvolutionObby_v1") end)
 if ok then store=result else warn("Evolution DataStore unavailable; temporary mode",result) end
end
workspace:SetAttribute("EvolutionPersistence",store and "Available" or "Temporary")
Commerce.Start({
 Message=sync,GrantDropCredit=grantDropCredit,OnDropCreditGranted=flushCredits,
 CanPurchaseDrop=function(player)
  local data=profiles[player]
  return store~=nil and data~=nil and not data.Loading and not data.ReadOnly
 end,
 OnPassChanged=function(player) sync(player) end,
 OnAvailabilityChanged=function() for player in pairs(profiles) do sync(player) end end,
})
Events.Start(World,{
 Broadcast=function(action,payload) remote:FireAllClients(action,payload) end,
 Message=sync,OnPurchasedDropDelivered=acknowledgeDrop,
 OnClaim=function(player,loot)
  if not canEat(player) then return false end
  awardFood(player,{Name="Thính",Hunger=loot.Fullness,Coins=loot.Coins},{MutationFood=true,Boost=3})
  return true
 end,
})
Ecology.Start(World,{
 OnEat=awardFood,CanEat=canEat,
 GetPlayerForm=function(player) local d=profiles[player]; return d and d.Form or 0 end,
 GetPlayerSize=volume,
 HasPass=Commerce.HasPass,
 GetHuntBonus=function(player) return Buffs.GetModifiers(player).HuntBonus end,
})

local function attack(player)
 local data=profiles[player]
 local root=alive(player)
 if not data or data.Loading or not root then return end
 local now=os.clock()
 if now<(data.ProtectedUntil or 0) then sync(player,"Bạn đang được bảo vệ sau khi hồi sinh."); return end
 if lastAttack[player] and now-lastAttack[player]<Config.AttackCooldown then return end
 lastAttack[player]=now
 local target,bestDistance
 for _,other in ipairs(Players:GetPlayers()) do
  if other~=player then
   local otherData=profiles[other]
   local otherRoot,otherHumanoid=alive(other)
   local contact=recentContacts[player] and recentContacts[player][other]
   if otherData and not otherData.Loading and now>=(otherData.ProtectedUntil or 0) and otherRoot then
    local distance=(otherRoot.Position-root.Position).Magnitude
    local ownCollider=player.Character:FindFirstChild("AnimalCollider")
    local otherCollider=other.Character:FindFirstChild("AnimalCollider")
    -- Giant potions enlarge contact distance as well as the visible animal.
    local reach=ownCollider and otherCollider and (ownCollider.Size.Magnitude+otherCollider.Size.Magnitude)/2+0.6 or 4
    local range=math.max(Config.AttackRange,reach)
    if distance<=range and ((contact and now-contact<2) or distance<=reach) then
     local ray=RaycastParams.new()
     ray.FilterType=Enum.RaycastFilterType.Exclude
     ray.FilterDescendantsInstances={player.Character,other.Character}
     local blocked=workspace:Raycast(root.Position,otherRoot.Position-root.Position,ray)
     if not blocked and (not bestDistance or distance<bestDistance) then target={Player=other,Root=otherRoot,Humanoid=otherHumanoid};bestDistance=distance end
    end
   end
  end
 end
 if not target then sync(player,"Hãy chạm hoặc đứng sát người chơi khác để đẩy."); return end
 local direction=target.Root.Position-root.Position
 direction=Vector3.new(direction.X,0,direction.Z)
 if direction.Magnitude<0.01 then direction=root.CFrame.LookVector else direction=direction.Unit end
 target.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
 pcall(function() target.Root:SetNetworkOwner(nil) end)
 target.Root:ApplyImpulse((direction*Rules.AttackStrength(data.Form)+Vector3.new(0,12,0))*target.Root.AssemblyMass)
 task.delay(0.35,function()
  if target.Root.Parent then pcall(function() target.Root:SetNetworkOwner(target.Player) end) end
 end)
 remote:FireClient(player,"Attack",{Position=target.Root.Position,Strength=Rules.AttackStrength(data.Form)})
 remote:FireClient(target.Player,"Pushed",{By=player.DisplayName or player.Name})
end
local function reviveNear(player)
 local data=profiles[player]
 if not data or data.Loading or not Commerce.HasPass(player) then sync(player,"Cần gói hỗ trợ để hồi sinh gần nơi chết."); return end
 local death=data.LastDeath
 local now=os.time()
 if not death or now-death.At>Config.NearRespawnOfferSeconds then sync(player,"Không còn điểm hồi sinh gần đang chờ."); return end
 if now<(data.NearReviveReadyAt or 0) then sync(player,"Hồi sinh gần đang hồi chiêu 3 phút."); return end
 local ground=World.GroundPosition(death.Position)
 local destination=ground and CFrame.new(ground+Vector3.new(0,6,0)) or World.NearestSafeSpawn(death.Biome,death.Position)
 if not teleportCharacter(player,destination) then return end
 data.NearReviveReadyAt=now+Config.NearRespawnCooldown
 data.LastDeath=nil
 grantProtection(player,Config.SpawnProtectionSeconds)
 sync(player,"Đã hồi sinh gần nơi chết. Hồi chiêu: 3 phút.")
 task.spawn(save,player,false)
end
remote.OnServerEvent:Connect(function(player,action,value)
 local data=profiles[player]
 if not data or typeof(action)~="string" then return end
 local now=os.clock()
 if lastAction[player] and now-lastAction[player]<0.16 then return end
 lastAction[player]=now
 if action=="Sync" then
  sync(player)
  for _,drop in ipairs(Events.GetActiveDrops()) do remote:FireClient(player,"Drop",drop) end
  return
 end
 if action=="BuyPass" then Commerce.PromptPass(player); return end
 if action=="BuyDrop" then Commerce.PromptSupplyDrop(player); return end
 if data.Loading then sync(player,"Đang tải tiến trình, vui lòng chờ một chút."); return end
 if not alive(player) then return end
 if action=="Evolve" then
  if Rules.Evolve(data) then
   applyCharacter(player,data)
   remote:FireClient(player,"Evolution",data.Form)
   sync(player,"Tiến hóa thành "..Config.Species[data.Form].Name.."!")
  else sync(player,data.Unlocked==#Config.Species and "Bạn đã mở loài cuối cùng." or "Cần ăn đủ 100% độ no để tiến hóa.") end
 elseif action=="Morph" then
  if typeof(value)~="number" or value~=value or value%1~=0 or value<1 or value>data.Unlocked then return end
  data.Form=value;applyCharacter(player,data);sync(player,"Đã đổi sang "..Config.Species[value].Name)
 elseif action=="Eat" then Ecology.TryEat(player)
 elseif action=="Attack" then attack(player)
 elseif action=="Reroll" then
  if not Commerce.HasPass(player) then sync(player,"Reroll miễn phí thuộc gói hỗ trợ."); return end
  local name=Rules.Reroll(data,rng)
  if name then applyCharacter(player,data);remote:FireClient(player,"Mutation",name);sync(player,"Đột biến: "..Config.Mutation(name).Label)
  else sync(player,"Ăn thức ăn đột biến để nhận 2 reroll miễn phí.") end
 elseif action=="Teleport" and typeof(value)=="string" then World.UseTeleport(player,value)
 elseif action=="ReviveNear" then reviveNear(player)
 end
end)

local function loadProfile(player)
 local data=profiles[player]
 if not data then return end
 if not store then data.Loading=false;sync(player,"Chơi thử không lưu. Ăn đủ no để tiến hóa!");return end
 acquireLock(player.UserId)
 local acquired
 local ok,err=pcall(function()
  acquired=store:UpdateAsync("player_"..player.UserId,function(old)
   if typeof(old)=="table" and old.Session and (tonumber(old.Lease) or 0)>os.time() and old.Session~=data.SessionToken then return nil end
   local nextData=Rules.Normalize(old)
   nextData.DropCredits,nextData.ReceiptIds,nextData.DropDispatches=metadata(old)
   nextData.Position=typeof(old)=="table" and old.Position or nil
   nextData.NearReviveReadyAt=typeof(old)=="table" and tonumber(old.NearReviveReadyAt) or 0
   nextData.Session=data.SessionToken;nextData.Lease=os.time()+180
   return nextData
  end)
 end)
 locks[player.UserId]=nil
 if profiles[player]~=data or not player.Parent then
  if ok and acquired then
   acquireLock(player.UserId)
   pcall(function() store:UpdateAsync("player_"..player.UserId,function(old)
    if typeof(old)=="table" and old.Session==data.SessionToken then old.Session=nil;old.Lease=0;return old end
    return nil
   end) end)
   locks[player.UserId]=nil
  end
  return
 end
 if ok and not acquired then player:Kick("Tiến trình đang mở ở máy chủ khác. Vui lòng thử lại sau.");return end
 if not ok then
  warn("Evolution load unavailable; temporary session",player.UserId,err)
  data.Loading=false;sync(player,"Chưa tải được DataStore; phiên này chơi thử và không ghi đè dữ liệu cũ.");return
 end
 local normalized=Rules.Normalize(acquired)
 for key,value in pairs(normalized) do data[key]=value end
 data.DropCredits,data.ReceiptIds,data.DropDispatches=metadata(acquired)
 data.NearReviveReadyAt=math.max(0,tonumber(acquired.NearReviveReadyAt) or 0)
 data.Loading=false;data.ReadOnly=false
 local saved=storedVector(acquired.Position)
 if saved and World.IsSafe(saved) then
  local ground=World.GroundPosition(saved)
  data.NextSpawn=ground and CFrame.new(ground+Vector3.new(0,6,0)) or World.StartSpawn
 else data.NextSpawn=World.StartSpawn end
 if teleportCharacter(player,data.NextSpawn) then applyCharacter(player,data);grantProtection(player,Config.SpawnProtectionSeconds) end
 sync(player,"Đã tải tiến trình. Chào mừng đến thế giới mở!")
 task.defer(flushCredits,player)
end
local function playerFromHit(hit)
 local model=hit:FindFirstAncestorOfClass("Model")
 while model do
  local player=Players:GetPlayerFromCharacter(model)
  if player then return player end
  local parent=model.Parent
  model=parent and (parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model"))
 end
end
local function addPlayer(player)
 if profiles[player] then return end
 local data=Rules.DefaultProfile()
 data.Loading=true;data.ReadOnly=true;data.Biome="meadow";data.NextSpawn=World.StartSpawn
 data.DropCredits={};data.ReceiptIds={};data.DropDispatches={};data.QueuedCredits={};data.NearReviveReadyAt=0
 data.SessionToken=serverToken..":"..HttpService:GenerateGUID(false)
 profiles[player]=data
 local stats=player:FindFirstChild("leaderstats") or Instance.new("Folder")
 stats.Name="leaderstats";stats.Parent=player
 for _,name in ipairs({"Coins","Evolution"}) do
  if not stats:FindFirstChild(name) then local v=Instance.new("IntValue");v.Name=name;v.Parent=stats end
 end
 local spawning=false
 local function spawn()
  if spawning or not player.Parent or not profiles[player] then return end
  spawning=true
  local ok,err=pcall(function()
   -- A same-biome respawn can be beyond the client's streamed region. Request
   -- that ground before creating the new, freely controlled character. Never
   -- anchor a live character or disable its controls while waiting for terrain.
   if workspace.StreamingEnabled then
    local destination=data.NextSpawn or World.StartSpawn
    pcall(function() player:RequestStreamAroundAsync(destination.Position,3) end)
    if profiles[player]~=data or not player.Parent then return end
    -- The initial profile may finish loading during the streaming request.
    local latest=data.NextSpawn or World.StartSpawn
    if (latest.Position-destination.Position).Magnitude>1 then
     pcall(function() player:RequestStreamAroundAsync(latest.Position,3) end)
    end
   end
   if profiles[player]~=data or not player.Parent then return end
   player:LoadCharacterAsync()
  end)
  spawning=false
  if not ok then warn("Evolution spawn failed",player.UserId,err) end
 end
 local function prepare(character)
  local root=character:WaitForChild("HumanoidRootPart",15)
  local humanoid=character:WaitForChild("Humanoid",15)
  if not root or not humanoid or profiles[player]~=data or player.Character~=character then return end
  teleportCharacter(player,data.NextSpawn or World.StartSpawn)
  applyCharacter(player,data)
  grantProtection(player,Config.SpawnProtectionSeconds)
  sync(player)
  local contactConnections={}
  local function attach(part)
   if part.Name~="AnimalCollider" or not part:IsA("BasePart") then return end
   table.insert(contactConnections,part.Touched:Connect(function(hit)
    local other=playerFromHit(hit)
    if other and other~=player then
     recentContacts[player]=recentContacts[player] or {}
     recentContacts[player][other]=os.clock()
    end
   end))
  end
  local collider=character:FindFirstChild("AnimalCollider");if collider then attach(collider) end
  local watcher=character.DescendantAdded:Connect(attach)
  character.AncestryChanged:Connect(function(_,parent)
   if not parent then watcher:Disconnect();for _,c in ipairs(contactConnections) do c:Disconnect() end end
  end)
  humanoid.Died:Connect(function()
   local deathPosition=root.Position
   local biome=World.PositionBiome(deathPosition) or data.Biome or "meadow"
   data.LastDeath={Position=deathPosition,Biome=biome,At=os.time()}
   data.Biome=biome
   data.NextSpawn=World.RandomSpawn(biome,deathPosition,Config.DeathRespawnStuds)
   -- Leaving while dead must resume at the new same-biome spawn as well.
   data.LastPosition=positionRecord(data.NextSpawn.Position,biome)
   sync(player,"Bạn sẽ hồi sinh ở nơi khác cùng biome, cách ít nhất 200 m.")
   task.delay(Players.RespawnTime,function() if player.Character==character then spawn() end end)
  end)
 end
 player.CharacterAdded:Connect(function(character) task.spawn(prepare,character) end)
 player.CharacterAppearanceLoaded:Connect(function(character)
  if player.Character==character and profiles[player]==data then applyCharacter(player,data) end
 end)
 if player.Character then task.spawn(prepare,player.Character) else task.spawn(spawn) end
 sync(player)
 Commerce.OnPlayerAdded(player)
 task.spawn(loadProfile,player)
 task.defer(function() for _,drop in ipairs(Events.GetActiveDrops()) do if player.Parent then remote:FireClient(player,"Drop",drop) end end end)
end
Players.PlayerAdded:Connect(addPlayer)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(addPlayer,player) end
Players.PlayerRemoving:Connect(function(player)
 save(player,true)
 profiles[player]=nil;recentContacts[player]=nil;lastAction[player]=nil;lastAttack[player]=nil
 for _,contacts in pairs(recentContacts) do contacts[player]=nil end
end)
task.spawn(function()
 while true do
  task.wait(60)
  for player in pairs(profiles) do task.spawn(save,player,false);task.spawn(flushCredits,player) end
 end
end)
task.spawn(function()
 while true do
  task.wait(3)
  for player in pairs(profiles) do sync(player) end
 end
end)
game:BindToClose(function()
 local pending=0
 for player in pairs(profiles) do pending+=1;task.spawn(function() save(player,true);pending-=1 end) end
 while pending>0 do task.wait(0.1) end
end)
