-- Runtime adopts the map embedded in the place. Rojo creates the same geometry.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.WorldLayout)
local AnimalModels = require(Shared.AnimalModels)
local World = {Checkpoints = {}, CoinPositions = {}, CoinStages = {}}
local built = false
local moving, windZones = {}, {}

local function vector(values)
 return Vector3.new(values[1], values[2], values[3])
end

local function group(folder, name)
 local existing = folder:FindFirstChild(name)
 if existing then return existing end
 local result = Instance.new("Folder")
 result.Name = name
 result.Parent = folder
 return result
end

local function billboard(part, spec)
 local gui = Instance.new("BillboardGui")
 gui.Name = "Label"
 gui.Size = UDim2.fromOffset(spec.width, spec.height)
 gui.MaxDistance = spec.width >= 300 and 160 or 65
 gui.LightInfluence = 0
 gui.AlwaysOnTop = false
 gui.Parent = part
 local label = Instance.new("TextLabel")
 label.Name = "Text"
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundColor3 = Color3.fromRGB(23, 34, 52)
 label.BackgroundTransparency = 0.18
 label.BorderSizePixel = 0
 label.TextColor3 = part.Color
 label.Font = Enum.Font.GothamBold
 label.TextSize = spec.width >= 300 and 25 or 20
 label.TextWrapped = true
 label.Text = spec.title .. (spec.subtitle ~= "" and "\n" .. spec.subtitle or "")
 label.Parent = gui
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(0, 10)
 corner.Parent = label
end

local function create(folder, record)
 local parent = group(folder, record.group)
 local part = parent:FindFirstChild(record.name)
 if part then return part end
 part = Instance.new(record.class_name or "Part")
 part.Name = record.name
 part.Size = vector(record.size)
 local rotation = record.rotation or {0, 0, 0}
 part.CFrame = CFrame.new(vector(record.position)) * CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
 part.Color = Color3.fromRGB(record.color[1], record.color[2], record.color[3])
 part.Anchored = true
 part.CanCollide = record.collide ~= false
 part.CanTouch = record.kind ~= nil
 part.Transparency = record.transparency or 0
 part.Material = Enum.Material[record.material or "SmoothPlastic"]
 part.TopSurface = Enum.SurfaceType.Smooth
 part.BottomSurface = Enum.SurfaceType.Smooth
 if part:IsA("Part") then part.Shape = Enum.PartType[record.shape or "Block"] end
 if part:IsA("SpawnLocation") then
  part.Neutral = true
  part.Enabled = true
  part.Duration = 0
 end
 part.Parent = parent
 if record.billboard then billboard(part, record.billboard) end
 if record.prompt then
  local prompt = Instance.new("ProximityPrompt")
  prompt.ActionText = record.prompt.action
  prompt.ObjectText = record.prompt.object
  prompt.MaxActivationDistance = record.prompt.distance
  prompt.RequiresLineOfSight = false
  prompt.HoldDuration = 0
  prompt.Parent = part
 end
 return part
end

-- Find the actual avatar, including hits from its welded animal visual parts.
local function playerFromHit(hit)
 local model = hit:FindFirstAncestorOfClass("Model")
 while model do
  local player = Players:GetPlayerFromCharacter(model)
  if player then return player end
  local parent = model.Parent
  model = parent and (parent:IsA("Model") and parent or parent:FindFirstAncestorOfClass("Model"))
 end
 return nil
end

function World.ReturnToCheckpoint(player)
 local stats = player:FindFirstChild("leaderstats")
 local checkpoint = stats and stats:FindFirstChild("Checkpoint")
 local destination = World.Checkpoints[checkpoint and checkpoint.Value or 0]
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if root and destination then
  root.AssemblyLinearVelocity = Vector3.zero
  root.AssemblyAngularVelocity = Vector3.zero
  character:PivotTo(destination)
 end
end

local function contains(part, position, padding)
 local localPosition = part.CFrame:PointToObjectSpace(position)
 local half = part.Size / 2 + (padding or Vector3.zero)
 return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Y) <= half.Y and math.abs(localPosition.Z) <= half.Z
end

-- CFrame animation cannot rely solely on Touched: a moving anchored wall also
-- checks its occupied volume so standing avatars are hit consistently.
local function startEnvironmentMotion()
 local started = os.clock()
 RunService.Heartbeat:Connect(function(deltaTime)
  local elapsed = os.clock() - started
  for _, entry in ipairs(moving) do
   local motion = entry.Motion
   local duration = motion.distance / motion.speed
   local cycle = duration + motion.pause
   local phase = elapsed % cycle
   -- Pause at the starting line, then sweep forward at a constant studs/second.
   local distance = phase < motion.pause and 0 or math.min(motion.distance, (phase - motion.pause) * motion.speed)
   local offset = motion.axis == "X" and Vector3.new(distance, 0, 0) or Vector3.new(0, 0, distance)
   entry.Part.CFrame = entry.Origin + offset
  end
  for _, player in ipairs(Players:GetPlayers()) do
   local character = player.Character
   local root = character and character:FindFirstChild("HumanoidRootPart")
   local humanoid = character and character:FindFirstChildOfClass("Humanoid")
   if root and humanoid and humanoid.Health > 0 then
    local form = character:GetAttribute("Form")
    for _, entry in ipairs(moving) do
     if form ~= entry.ImmuneForm and contains(entry.Part, root.Position, Vector3.new(1, 2, 1)) then humanoid.Health = 0 end
    end
    for _, entry in ipairs(windZones) do
     if form ~= entry.ImmuneForm and contains(entry.Part, root.Position) then
      local velocity = root.AssemblyLinearVelocity
      root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y,
       math.min(entry.Config.max_speed, velocity.Z + entry.Config.acceleration * math.min(deltaTime, 0.1)))
     end
    end
   end
  end
 end)
end

function World.Build(onCheckpoint, onCoin, onStation)
 local folder = workspace:FindFirstChild("EvolutionObby")
 if not folder then
  folder = Instance.new("Folder")
  folder.Name = "EvolutionObby"
  folder.Parent = workspace
 end
 if built then return folder end
 built = true
 for _, record in ipairs(Layout) do
  local part = create(folder, record)
  if record.motion then
   table.insert(moving, {Part = part, Origin = part.CFrame, Motion = record.motion, ImmuneForm = record.immune_form or 14})
  end
  if record.kind == "spawn" then
   local position = part.Position + Vector3.new(0, 5, 0)
   World.Checkpoints[0] = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
  elseif record.kind == "checkpoint" then
   local stage = record.stage
   local position = part.Position + Vector3.new(0, 5, 0)
   World.Checkpoints[stage] = CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
   part.Touched:Connect(function(hit)
    local player = playerFromHit(hit)
    if player then onCheckpoint(player, stage) end
   end)
  elseif record.kind == "coin" then
   local id = record.id
   World.CoinPositions[id] = part.Position
   World.CoinStages[id] = record.stage or id
   part:SetAttribute("CoinId", id)
   part:SetAttribute("Stage", record.stage or id)
   part.Touched:Connect(function(hit)
    local player = playerFromHit(hit)
    if player then onCoin(player, id, record.value, part) end
   end)
  elseif record.kind == "station" then
   local prompt = part:FindFirstChildOfClass("ProximityPrompt")
   if prompt then prompt.Triggered:Connect(function(player) onStation(player, part) end) end
  elseif record.kind == "return" then
   local prompt = part:FindFirstChildOfClass("ProximityPrompt")
   if prompt then prompt.Triggered:Connect(World.ReturnToCheckpoint) end
  elseif record.kind == "wind" then
   table.insert(windZones, {Part = part, Config = record.wind, ImmuneForm = record.immune_form})
  elseif record.kind == "hazard" or record.kind == "void" then
   part.Touched:Connect(function(hit)
    local player = playerFromHit(hit)
    local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local immune = record.kind == "hazard" and player and player.Character:GetAttribute("Form") == (record.immune_form or 14)
    if humanoid and not immune then humanoid.Health = 0 end
   end)
  end
 end
 -- Rojo users receive the same lobby exhibits as the prebuilt place.
 local exhibits = group(folder, "Exhibits")
 if not exhibits:FindFirstChild("AnimalGallery") then
  local gallery = group(exhibits, "AnimalGallery")
  for form, definition in ipairs(AnimalModels.Definitions) do
   local model = AnimalModels.Create(form, gallery)
   model.Name = string.format("%02d_%s", form, definition.Name)
   model:ScaleTo(0.72)
   local index = form - 1
   model:PivotTo(CFrame.new(-44 + (index % 5) * 12, 11.3, -28 - math.floor(index / 5) * 16))
  end
 end
 startEnvironmentMotion()
 workspace:SetAttribute("EvolutionWorldReady", true)
 return folder
end

return World
