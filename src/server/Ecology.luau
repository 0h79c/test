-- Food ownership and wildlife run on the server. The client never supplies rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local FoodModels = require(ReplicatedStorage.Shared.FoodModels)
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)

local Ecology = {ActiveFoods={}, ActiveNPCs={}, PendingFoods={}}
local world, callbacks, rng, foodFolder, npcFolder, heartbeat
local generation, npcSerial, elapsed = 0, 0, 0
local EAT_RANGE = 8

local function horizontalDistance(a, b)
 local dx, dz = a.X - b.X, a.Z - b.Z
 return math.sqrt(dx * dx + dz * dz)
end

local function playerRoot(player)
 local character = player and player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health <= 0 then return nil end
 if callbacks.CanEat and not callbacks.CanEat(player) then return nil end
 return root
end

-- The vertical allowance covers tall evolved animals; reach on the ground is eight studs.
function Ecology.InEatingRange(from, to)
 return horizontalDistance(from, to) <= EAT_RANGE and math.abs(from.Y - to.Y) <= 18
end

function Ecology.CanEatNPC(playerForm, npcForm, playerSize, npcSize, huntBonus)
 local function positiveFinite(value)
  return type(value) == "number" and value > 0 and value < math.huge
 end
 -- The temporary hunting tonic permits the next 2–4 tiers without changing
 -- the player's permanent evolution or relying on client-supplied prey data.
 if positiveFinite(playerForm) and positiveFinite(npcForm) and type(huntBonus) == "number"
  and huntBonus >= 2 and huntBonus <= 4 and huntBonus % 1 == 0
  and npcForm <= playerForm + huntBonus then return true end
 -- A large mutation can hunt physically smaller wildlife even at the same tier.
 -- If sizes were supplied, malformed or incomplete sizes never permit a hunt.
 if playerSize ~= nil or npcSize ~= nil then
  return positiveFinite(playerSize) and positiveFinite(npcSize) and playerSize > npcSize
 end
 return positiveFinite(playerForm) and positiveFinite(npcForm) and playerForm > npcForm
end

function Ecology.Claim(registry, model)
 local entry = registry[model]
 if not entry or entry.Claimed or not model.Parent then return nil end
 entry.Claimed = true
 registry[model] = nil -- Remove before callbacks, which may yield while granting rewards.
 return entry
end

local function foodSpecs()
 return Config.Foods or {
  {Id="berries", Name="Chùm mọng", Hunger=.5, Coins=2, Weight=23},
  {Id="leaf", Name="Lá non", Hunger=1, Coins=3, Weight=22},
  {Id="apple", Name="Táo chín", Hunger=2, Coins=5, Weight=20},
  {Id="mushroom", Name="Nấm rừng", Hunger=3, Coins=8, Weight=15},
  {Id="fish", Name="Cá bạc", Hunger=5, Coins=12, Weight=9},
  {Id="meat", Name="Thịt tươi", Hunger=7, Coins=18, Weight=7},
  {Id="fruit", Name="Quả nhiệt đới", Hunger=10, Coins=25, Weight=4},
 }
end

local function mutationSpec()
 return Config.MutationFood or {Id="mutation", Name="Quả đột biến", Hunger=3, Coins=35, Mutation=true}
end

function Ecology.RollFood(random, biome)
 local rarity = random:NextNumber()
 local mutationChance = Config.MutationFoodSpawnChance or .012
 if rarity < mutationChance then return mutationSpec() end
 local buffs = Config.BuffFoods or {}
 if rarity < mutationChance + (Config.BuffSpawnChance or .03) and #buffs > 0 then
  return buffs[random:NextInteger(1, #buffs)]
 end
 local eligible, total = {}, 0
 for _, spec in ipairs(foodSpecs()) do
  if not spec.Biomes or table.find(spec.Biomes, biome) then
   local weight = spec.Weight or 1
   if weight > 0 then
    total += weight
    table.insert(eligible, spec)
   end
  end
 end
 if #eligible == 0 then return foodSpecs()[1] end
 local roll = random:NextNumber(0, total)
 for _, spec in ipairs(eligible) do
  roll -= spec.Weight or 1
  if roll <= 0 then return spec end
 end
 return eligible[#eligible]
end

local function isMutation(spec)
 return spec.Mutation == true or spec.Id == "mutation"
end

local function reserved(position, excluded)
 for _, entry in pairs(Ecology.ActiveFoods) do
  if horizontalDistance(position, entry.Position) < (Config.FoodMinimumSpacing or 70) then return true end
 end
 for entry in pairs(Ecology.PendingFoods) do
  if entry ~= excluded and entry.Position
   and horizontalDistance(position, entry.Position) < (Config.FoodMinimumSpacing or 70) then return true end
 end
 return false
end

local function spawnPosition(biome, excluded)
 for _ = 1, 45 do
  local position = world.RandomPosition(biome, rng)
  if position and not reserved(position, excluded) then return position end
 end
 return nil
end

local spawnFood
local function reserveFoodDestination(entry)
 local position = spawnPosition(entry.Biome, entry)
 if not position and entry.PreviousGround then position = world.GroundPosition(entry.PreviousGround) end
 if position and not reserved(position, entry) then
  entry.Position = position
  return true
 end
 entry.Position = nil
 entry.RetryIn = 15
 return false
end

local function queueFood(biome, remaining, previousGround)
 local pending = {Biome=biome, Remaining=remaining, PreviousGround=previousGround, RetryIn=0}
 reserveFoodDestination(pending)
 Ecology.PendingFoods[pending] = true
 return pending
end

local function respawnFood(entry)
 local waitTime = isMutation(entry.Spec) and rng:NextNumber(120, 300) or rng:NextNumber(35, 90)
 queueFood(entry.Biome, waitTime, entry.GroundPosition)
end

function Ecology.GlobalRespawnRate(playerCount, npcCount)
 local settings = Config.FoodRespawn or {}
 return 1 + math.max(0, playerCount - 1) * (settings.AdditionalPlayerRate or .25)
  + math.max(0, npcCount) * (settings.PerAIRate or .1)
end

local function stepFoodRespawns(delta)
 local online = Players:GetPlayers()
 local livingNPCs = 0
 for _, entry in pairs(Ecology.ActiveNPCs) do
  if entry.Model.Parent and not entry.Claimed then livingNPCs += 1 end
 end
 local settings = Config.FoodRespawn or {}
 local globalRate = Ecology.GlobalRespawnRate(#online, livingNPCs)
 local passPositions = {}
 if callbacks.HasPass then
  for _, player in ipairs(online) do
   local root = playerRoot(player)
   if root and callbacks.HasPass(player) then table.insert(passPositions, root.Position) end
  end
 end
 local radius = (settings.PassRadiusMeters or 50) / (Config.MetersPerStud or .28)
 for entry in pairs(Ecology.PendingFoods) do
  if not entry.Position then
   entry.RetryIn -= delta
   if entry.RetryIn <= 0 then reserveFoodDestination(entry) end
  end
  if entry.Position then
   local multiplier = 1
   for _, position in ipairs(passPositions) do
    if (position - entry.Position).Magnitude <= radius then
     multiplier = settings.PassMultiplier or 2
     break -- Overlapping pass owners do not stack the local bonus.
    end
   end
   entry.Remaining -= delta * globalRate * multiplier
   if entry.Remaining <= 0 then
    local ground = world.GroundPosition(entry.Position)
    if ground and not reserved(ground, entry) then
     Ecology.PendingFoods[entry] = nil
     spawnFood(ground, entry.Biome, Ecology.RollFood(rng, entry.Biome))
    else
     entry.Position = nil
     entry.RetryIn = 15
    end
   end
  end
 end
end

local function unobstructed(player, position)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 local parameters = RaycastParams.new()
 parameters.FilterType = Enum.RaycastFilterType.Exclude
 parameters.FilterDescendantsInstances = {player.Character, foodFolder, npcFolder}
 local hit = workspace:Raycast(root.Position, position - root.Position, parameters)
 return not hit or not hit.Instance.CanCollide
end

local function consumeFood(player, model)
 local root = playerRoot(player)
 local entry = Ecology.ActiveFoods[model]
 if not root or not entry or not Ecology.InEatingRange(root.Position, entry.Position)
  or not unobstructed(player, entry.Position) then return false end
 entry = Ecology.Claim(Ecology.ActiveFoods, model)
 if not entry then return false end
 model:Destroy()
 respawnFood(entry)
 callbacks.OnEat(player, entry.Spec, {Kind="Food", MutationFood=isMutation(entry.Spec), Boost=entry.Boost,
  Buff=entry.Spec.Buff})
 return true
end

local function touchingPlayer(hit)
 local character = hit and hit:FindFirstAncestorOfClass("Model")
 if not character then return nil end
 local player = Players:GetPlayerFromCharacter(character)
 if player then return player end
 -- AnimalVisual is itself a Model beneath the player's Character.
 return character.Parent and character.Parent:IsA("Model") and Players:GetPlayerFromCharacter(character.Parent) or nil
end

local function prompt(root, label, action)
 local interaction = Instance.new("ProximityPrompt")
 interaction.Name = "EatPrompt"
 interaction.ActionText = action or "Ăn"
 interaction.ObjectText = label
 interaction.KeyboardKeyCode = Enum.KeyCode.E
 interaction.GamepadKeyCode = Enum.KeyCode.ButtonX
 interaction.MaxActivationDistance = EAT_RANGE
 interaction.RequiresLineOfSight = true
 interaction.HoldDuration = 0
 interaction.Parent = root
 return interaction
end

spawnFood = function(position, biome, spec, boosted)
 local model = FoodModels.Create(spec, foodFolder, boosted)
 model:PivotTo(CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
 model:SetAttribute("Biome", biome)
 local entry = {Model=model, Spec=spec, Position=model.PrimaryPart.Position, GroundPosition=position,
  Biome=biome, Boost=boosted and 3 or 1, Claimed=false}
 Ecology.ActiveFoods[model] = entry
 prompt(model.PrimaryPart, spec.Name or "Thức ăn", spec.Buff and "Uống" or "Ăn")
 -- Prompt events, like touch events, go through the same authoritative claim.
 model.PrimaryPart.EatPrompt.Triggered:Connect(function(player) consumeFood(player, model) end)
 model.PrimaryPart.Touched:Connect(function(hit)
  local player = touchingPlayer(hit)
  if player then consumeFood(player, model) end
 end)
 if spec.Buff then
  -- Unclaimed tonics must not gradually occupy every shared food slot.
  local currentGeneration = generation
  task.delay(Config.BuffFoodLifetime or 300, function()
   if generation ~= currentGeneration then return end
   local expired = Ecology.Claim(Ecology.ActiveFoods, model)
   if not expired then return end
   model:Destroy()
   respawnFood(expired)
  end)
 end
 return model
end

function Ecology.SpawnMutationFood(position, boosted)
 if not world or not foodFolder then return nil end
 local ground = world.GroundPosition(position)
 if not ground then return nil end
 return spawnFood(ground, world.BiomeAt(ground), mutationSpec(), boosted == true)
end

local spawnNPC
local function npcVisual(entry)
 local previous = entry.Model:FindFirstChild("AnimalVisual")
 if previous then previous:Destroy() end
 local visual = AnimalModels.Create(entry.Form, entry.Model)
 visual.Name = "AnimalVisual"
 visual:ScaleTo(.9 + entry.Form * .055)
 visual:PivotTo(entry.Root.CFrame)
 if AnimalModels.Rig then AnimalModels.Rig(visual, entry.Root) end
 entry.Model:SetAttribute("Form", entry.Form)
 entry.Model:SetAttribute("NPCSpecies", entry.Form)
 entry.Model:SetAttribute("VisualScale", .9 + entry.Form * .055)
 local definition = AnimalModels.Definitions[entry.Form]
 local collider = definition and definition.Collider or {2, 2, 3}
 entry.Size = collider[1] * collider[2] * collider[3] * (.9 + entry.Form * .055) ^ 3
 local spec = Config.Species[entry.Form]
 entry.Caption.Text = string.format("%s · Bậc %d", spec and spec.Name or "Sinh vật", entry.Form)
 entry.Prompt.ObjectText = string.format("%s · ăn được khi nhỏ hơn bạn", spec and spec.Name or "Sinh vật")
end

local function canHunt(player, entry)
 return Ecology.CanEatNPC(callbacks.GetPlayerForm(player), entry.Form,
  callbacks.GetPlayerSize and callbacks.GetPlayerSize(player), entry.Size,
  callbacks.GetHuntBonus and callbacks.GetHuntBonus(player) or 0)
end

local function consumeNPC(player, model)
 local root = playerRoot(player)
 local entry = Ecology.ActiveNPCs[model]
 if not root or not entry or not Ecology.InEatingRange(root.Position, entry.Root.Position)
  or not canHunt(player, entry) or not unobstructed(player, entry.Root.Position) then return false end
 entry = Ecology.Claim(Ecology.ActiveNPCs, model)
 if not entry then return false end
 local form, biome = entry.Form, entry.Biome
 if entry.MoveTween then entry.MoveTween:Cancel() end
 model:Destroy()
 local currentGeneration = generation
 task.delay(rng:NextNumber(45, 80), function()
  if generation ~= currentGeneration then return end
  local position = world.RandomPosition(biome, rng)
  if position then spawnNPC(position, biome, rng:NextInteger(1, 8)) end
 end)
 callbacks.OnEat(player, {Id="prey", Name=Config.Species[form].Name, Hunger=math.min(10, 2 + form), Coins=4 * form},
  {Kind="NPC", MutationFood=false, Boost=1, Form=form})
 return true
end

spawnNPC = function(position, biome, form)
 npcSerial += 1
 local model = Instance.new("Model")
 model.Name = "Wildlife" .. npcSerial
 model:SetAttribute("IsNPC", true)
 model:SetAttribute("Biome", biome)
 local root = Instance.new("Part")
 root.Name = "HumanoidRootPart"
 root.Size = Vector3.new(4, 4, 4)
 root.CFrame = CFrame.new(position)
 root.Transparency = 1
 root.Anchored = true
 root.CanCollide = false
 root.CanTouch = true
 root.CanQuery = false
 root.Parent = model
 model.PrimaryPart = root
 local board = Instance.new("BillboardGui")
 board.Name = "WildlifeCaption"
 board.Size = UDim2.fromOffset(160, 30)
 board.StudsOffset = Vector3.new(0, 5.5, 0)
 board.MaxDistance = 65
 board.Parent = root
 local label = Instance.new("TextLabel")
 label.BackgroundTransparency = 1
 label.Size = UDim2.fromScale(1, 1)
 label.Font = Enum.Font.GothamMedium
 label.TextSize = 12
 label.TextColor3 = Color3.fromRGB(255, 230, 177)
 label.TextStrokeTransparency = .25
 label.Parent = board
 model.Parent = npcFolder
 local eatPrompt = prompt(root, "Sinh vật nhỏ", "Săn / Ăn")
 local entry = {Model=model, Root=root, Form=form, Biome=biome, Hunger=0, Claimed=false,
  Target=nil, SearchAt=0, WanderAt=0, Goal=position, Caption=label, Prompt=eatPrompt,
  Raycast=RaycastParams.new()}
 entry.Raycast.FilterType = Enum.RaycastFilterType.Exclude
 entry.Raycast.FilterDescendantsInstances = {model, foodFolder, npcFolder}
 Ecology.ActiveNPCs[model] = entry
 npcVisual(entry)
 eatPrompt.Triggered:Connect(function(player) consumeNPC(player, model) end)
 root.Touched:Connect(function(hit)
  local player = touchingPlayer(hit)
  if player then consumeNPC(player, model) end
 end)
 return model
end

local function closestFood(entry)
 local nearest, distance = nil, 320
 for model, food in pairs(Ecology.ActiveFoods) do
  if food.Biome == entry.Biome and not food.Spec.Buff then
   local separation = horizontalDistance(entry.Root.Position, food.Position)
   if separation < distance then distance, nearest = separation, model end
  end
 end
 return nearest
end

local function threatPosition(entry)
 for _, player in ipairs(Players:GetPlayers()) do
  local root = playerRoot(player)
  if root and canHunt(player, entry)
   and horizontalDistance(root.Position, entry.Root.Position) < 26 then return root.Position end
 end
 return nil
end

local function stepNPC(entry, delta, now)
 if not entry.Model.Parent then Ecology.ActiveNPCs[entry.Model] = nil; return end
 local position = entry.Root.Position
 if now >= entry.SearchAt then
  entry.SearchAt = now + .9 + rng:NextNumber(0, .3)
  entry.Target = closestFood(entry)
  local threat = threatPosition(entry)
  if threat then
   local away = Vector3.new(position.X - threat.X, 0, position.Z - threat.Z)
   if away.Magnitude > .1 then
    local safe = world.GroundPosition(position + away.Unit * 45)
    if safe and world.BiomeAt(safe) == entry.Biome then
     entry.Goal, entry.Target, entry.WanderAt = safe, nil, now + 3
     entry.Model:SetAttribute("Activity", "Né thú lớn")
    end
   end
  end
 end
 local food = entry.Target and Ecology.ActiveFoods[entry.Target]
 -- Tonics are player effects. Wildlife neither seeks nor consumes them, so
 -- scarce potions remain available and AI always keeps its configured speed.
 if food and food.Spec.Buff then
  entry.Target = nil
  food = nil
 end
 if food then
  entry.Goal = food.GroundPosition
  entry.Model:SetAttribute("Activity", "Tranh thức ăn")
  if horizontalDistance(position, food.Position) < 3.5 and math.abs(position.Y - food.GroundPosition.Y) < 4 then
   local eaten = Ecology.Claim(Ecology.ActiveFoods, entry.Target)
   if eaten then
    eaten.Model:Destroy()
    respawnFood(eaten)
    entry.Hunger += eaten.Spec.Hunger or .5
    if entry.Hunger >= 100 and entry.Form < 8 then
     entry.Hunger -= 100
     entry.Form += 1
     npcVisual(entry)
    end
   end
   entry.Target = nil
  end
 elseif now >= entry.WanderAt or horizontalDistance(position, entry.Goal) < 5 then
  entry.Goal = world.RandomPosition(entry.Biome, rng) or position
  entry.WanderAt = now + rng:NextNumber(12, 24)
  entry.Model:SetAttribute("Activity", "Tìm thức ăn")
 end
 local offset = Vector3.new(entry.Goal.X - position.X, 0, entry.Goal.Z - position.Z)
 if offset.Magnitude < .3 then entry.Model:SetAttribute("Moving", false); return end
 local direction = offset.Unit
 local species = Config.Species[entry.Form]
 local speed = species.WalkSpeed * (Config.AISpeedMultiplier or .5)
 local distance = math.min(offset.Magnitude, speed * delta)
 local eye = position + Vector3.new(0, 2, 0)
 local obstacle = workspace:Raycast(eye, direction * (distance + 3), entry.Raycast)
 if obstacle and obstacle.Instance.CanCollide then
  direction = Vector3.new(-direction.Z, 0, direction.X)
 end
 local ground = world.GroundPosition(position + direction * distance)
 -- Never snap across water, lava, steep cliffs, or a different habitat.
 if not ground or world.BiomeAt(ground) ~= entry.Biome or math.abs(ground.Y - position.Y) > 3 then
  entry.Target = nil
  entry.WanderAt = 0
  entry.Model:SetAttribute("Moving", false)
  return
 end
 entry.Model:SetAttribute("Moving", true)
 entry.Model:SetAttribute("NPCWalkSpeed", speed)
 entry.Model:SetAttribute("MoveSpeed", speed)
 local destination = CFrame.lookAt(ground, ground + direction)
 if AnimalModels.Rig and TweenService then
  -- Only the anchored root moves; Motor6Ds carry the detailed anatomy with it.
  -- Smooth motion needs no per-frame model PivotTo or untrusted client positions.
  if entry.MoveTween then entry.MoveTween:Cancel() end
  entry.MoveTween = TweenService:Create(entry.Root, TweenInfo.new(delta, Enum.EasingStyle.Linear), {CFrame=destination})
  entry.MoveTween:Play()
 else
  entry.Model:PivotTo(destination)
 end
end

function Ecology.TryEat(player, target)
 local root = playerRoot(player)
 if not root then return false end
 if typeof(target) == "Instance" then
  local model = target
  while model and model ~= workspace do
   if Ecology.ActiveFoods[model] then return consumeFood(player, model) end
   if Ecology.ActiveNPCs[model] then return consumeNPC(player, model) end
   model = model.Parent
  end
  return false
 end
 local selected, best, kind = nil, EAT_RANGE + .01, nil
 for model, entry in pairs(Ecology.ActiveFoods) do
  local distance = horizontalDistance(root.Position, entry.Position)
  if distance < best and Ecology.InEatingRange(root.Position, entry.Position) then selected, best, kind = model, distance, "Food" end
 end
 for model, entry in pairs(Ecology.ActiveNPCs) do
  local distance = horizontalDistance(root.Position, entry.Root.Position)
  if distance < best and Ecology.InEatingRange(root.Position, entry.Root.Position) and canHunt(player, entry) then
   selected, best, kind = model, distance, "NPC"
  end
 end
 if not selected then return false end
 if kind == "Food" then return consumeFood(player, selected) end
 return consumeNPC(player, selected)
end

Ecology.AttackNearest = Ecology.TryEat

function Ecology.Stop()
 generation += 1
 if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
 for _, entry in pairs(Ecology.ActiveNPCs) do if entry.MoveTween then entry.MoveTween:Cancel() end end
 if foodFolder then foodFolder:Destroy() end
 if npcFolder then npcFolder:Destroy() end
 Ecology.ActiveFoods, Ecology.ActiveNPCs, Ecology.PendingFoods = {}, {}, {}
 foodFolder, npcFolder = nil, nil
end

function Ecology.Start(worldModule, handlers)
 Ecology.Stop()
 world, callbacks = worldModule, handlers
 assert(type(callbacks.OnEat) == "function" and type(callbacks.GetPlayerForm) == "function", "Ecology requires food and form callbacks")
 -- Layout can be seeded, while edible spawns stay unpredictable across servers.
 rng = Config.EcologySeed and Random.new(Config.EcologySeed) or Random.new()
 elapsed = 0
 foodFolder = Instance.new("Folder")
 foodFolder.Name = "Foods"
 foodFolder.Parent = workspace
 npcFolder = Instance.new("Folder")
 npcFolder.Name = "Wildlife"
 npcFolder.Parent = workspace
 local candidates = table.clone(world.FoodSpawnPoints or {})
 for i = #candidates, 2, -1 do
  local j = rng:NextInteger(1, i)
  candidates[i], candidates[j] = candidates[j], candidates[i]
 end
 local count = 0
 for _, candidate in ipairs(candidates) do
  if count >= (Config.FoodCount or 220) then break end
  if not reserved(candidate.Position) then
   spawnFood(candidate.Position, candidate.Biome, Ecology.RollFood(rng, candidate.Biome))
   count += 1
  end
 end
 local biomes = world.Biomes or Config.Biomes
 -- Retain every configured slot even when the initial map has temporarily
 -- unavailable candidates. The bounded reservation worker fills them later.
 for i = count + 1, (Config.FoodCount or 220) do
  queueFood(biomes[1 + (i - 1) % #biomes].Id, 0)
 end
 for i = 1, (Config.NPCCount or 24) do
  local biome = biomes[1 + (i - 1) % #biomes].Id
  local position = world.RandomPosition(biome, rng)
  if position then spawnNPC(position, biome, 1 + (i - 1) % 8) end
 end
 heartbeat = RunService.Heartbeat:Connect(function(delta)
  stepFoodRespawns(delta)
  elapsed += delta
  if elapsed < .25 then return end
  local step = math.min(elapsed, .5)
  elapsed = 0
  local now = os.clock()
  for _, entry in pairs(Ecology.ActiveNPCs) do stepNPC(entry, step, now) end
 end)
 return Ecology
end

return Ecology
