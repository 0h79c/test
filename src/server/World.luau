-- Embedded scenery and Rojo both adopt one canonical, seeded open landscape.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.WorldLayout)
local Config = require(Shared.WorldConfig)
local World = {Config = Config, Biomes = {}, BiomeById = {}, MapNodes = {}, Teleports = {}, FoodSpawnPoints = {}, SafeSpawns = {}}
local folder, built = nil, false
local callbacks = {}
local rng = Random.new()
local bridgePass, promptCooldown, entrySide = {}, {}, {}
local obstacleCells, hazards = {}, {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local bridge = Config.Bridge

local function vector(v)
 return Vector3.new(v[1], v[2], v[3])
end

for _, raw in ipairs(Config.Biomes) do
 local biome = table.clone(raw)
 biome.Center = vector(raw.Center)
 table.insert(World.Biomes, biome)
 table.insert(World.MapNodes, biome)
 World.BiomeById[biome.Id] = biome
 World.SafeSpawns[biome.Id] = {}
end
for _, raw in ipairs(Config.SafeSpawns) do
 table.insert(World.SafeSpawns[raw.Biome], vector(raw.Position))
end
for _, raw in ipairs(Config.FoodSpawnPoints) do
 table.insert(World.FoodSpawnPoints, {Position = vector(raw.Position), Biome = raw.Biome})
end
World.StartSpawn = CFrame.new(0, 19, 0)

local function group(parent, name)
 local found = parent:FindFirstChild(name)
 if found then return found end
 local child = Instance.new("Folder")
 child.Name, child.Parent = name, parent
 return child
end

local function billboard(part, spec)
 local gui = Instance.new("BillboardGui")
 gui.Name = "Label"
 gui.Size = UDim2.fromOffset(spec.width, spec.height)
 gui.MaxDistance = spec.width >= 300 and 210 or 90
 gui.LightInfluence = 0
 gui.AlwaysOnTop = false
 gui.Parent = part
 local label = Instance.new("TextLabel")
 label.Name = "Text"
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundColor3 = Color3.fromRGB(22, 37, 35)
 label.BackgroundTransparency = 0.24
 label.BorderSizePixel = 0
 label.TextColor3 = part.Color
 label.Font = Enum.Font.GothamBold
 label.TextSize = spec.width >= 300 and 24 or 20
 label.TextWrapped = true
 label.Text = spec.title .. (spec.subtitle ~= "" and "\n" .. spec.subtitle or "")
 label.Parent = gui
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(0, 12)
 corner.Parent = label
end

local function create(parent, record)
 local target = group(parent, record.group)
 local part = target:FindFirstChild(record.name)
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
 part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 if part:IsA("Part") then part.Shape = Enum.PartType[record.shape or "Block"] end
 if part:IsA("SpawnLocation") then
  part.Neutral, part.Enabled, part.Duration = true, true, 0
 end
 part.Parent = target
 if record.billboard then billboard(part, record.billboard) end
 if record.prompt then
  local prompt = Instance.new("ProximityPrompt")
  prompt.ActionText, prompt.ObjectText = record.prompt.action, record.prompt.object
  prompt.MaxActivationDistance = record.prompt.distance
  prompt.RequiresLineOfSight = false
  prompt.HoldDuration = 0.2
  prompt.Parent = part
 end
 return part
end

function World.PositionBiome(position)
 for _, biome in ipairs(World.Biomes) do
  if position.X >= biome.MinX and position.X <= biome.MaxX and position.Z >= biome.MinZ and position.Z <= biome.MaxZ then
   return biome.Id
  end
 end
 return nil
end
World.BiomeAt = World.PositionBiome

local function footprint(part)
 local half = part.Size / 2
 local right, up, look = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector
 local extentX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
 local extentZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
 return {X = part.Position.X, Z = part.Position.Z, ExtentX = extentX + 4, ExtentZ = extentZ + 4}
end

local function cellKey(x, z)
 return math.floor(x / 128) .. ":" .. math.floor(z / 128)
end

local function indexObstacle(part)
 local box = footprint(part)
 for x = math.floor((box.X - box.ExtentX) / 128), math.floor((box.X + box.ExtentX) / 128) do
  for z = math.floor((box.Z - box.ExtentZ) / 128), math.floor((box.Z + box.ExtentZ) / 128) do
   local key = x .. ":" .. z
   obstacleCells[key] = obstacleCells[key] or {}
   table.insert(obstacleCells[key], box)
  end
 end
end

function World.IsSafe(position)
 if not World.PositionBiome(position) then return false end
 -- Stable exclusions also work before Build, so dependent services can prepare.
 for _, region in ipairs(Config.ProtectedRegions) do
  if position.X > region.MinX - 8 and position.X < region.MaxX + 8 and position.Z > region.MinZ - 8 and position.Z < region.MaxZ + 8 then return false end
 end
 if math.abs(position.X - bridge.X) < bridge.HalfLength + 5 and math.abs(position.Z - bridge.Z) < bridge.HalfWidth + 5 then return false end
 for _, box in ipairs(obstacleCells[cellKey(position.X, position.Z)] or {}) do
  if math.abs(position.X - box.X) < box.ExtentX and math.abs(position.Z - box.Z) < box.ExtentZ then return false end
 end
 return true
end
World.IsSafePosition = World.IsSafe

function World.GroundPosition(first, z)
 local position = typeof(first) == "Vector3" and first or Vector3.new(first, Config.GroundY, z)
 if not World.IsSafe(position) then return nil end
 if built then
  local result = workspace:Raycast(Vector3.new(position.X, 400, position.Z), Vector3.new(0, -450, 0), groundParams)
  if result then return result.Position + Vector3.new(0, 0.1, 0) end
  return nil
 end
 return Vector3.new(position.X, Config.GroundY + 0.1, position.Z)
end

function World.RandomPosition(biomeId, random)
 random = random or rng
 local pool = biomeId and World.SafeSpawns[biomeId]
 if pool then
  return pool[random:NextInteger(1, #pool)]
 end
 local point = World.FoodSpawnPoints[random:NextInteger(1, #World.FoodSpawnPoints)]
 return point.Position
end

function World.GetDropPosition(random)
 random = random or rng
 local point = World.FoodSpawnPoints[random:NextInteger(1, #World.FoodSpawnPoints)]
 return point.Position
end

function World.RandomSpawn(biomeId, avoidPosition, minDistanceStuds)
 local pool = World.SafeSpawns[biomeId] or World.SafeSpawns.meadow
 local minimum = minDistanceStuds or Config.RespawnDistanceStuds
 local candidates, farthest, farthestDistance = {}, nil, -1
 -- Examine the whole biome. A few random retries cannot guarantee the distance.
 for _, point in ipairs(pool) do
  local delta = avoidPosition and point - avoidPosition or Vector3.zero
  local distance = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
  if not avoidPosition or distance >= minimum then table.insert(candidates, point) end
  if distance > farthestDistance then farthest, farthestDistance = point, distance end
 end
 local selected = #candidates > 0 and candidates[rng:NextInteger(1, #candidates)] or farthest
 assert(selected, "Biome has no safe respawn position")
 return CFrame.new(selected + Vector3.new(0, 6, 0))
end
World.DeathSpawn = World.RandomSpawn

function World.NearestSafeSpawn(biomeId, origin)
 local biome = World.BiomeById[biomeId] or World.BiomeById.meadow
 origin = typeof(origin) == "Vector3" and origin or biome.Center
 local best, bestDistance = nil, math.huge
 local function consider(position)
  if World.PositionBiome(position) ~= biome.Id then return false end
  local delta = position - origin
  local distance = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
  if distance >= bestDistance then return false end
  local ground = World.GroundPosition(position)
  if not ground then return false end
  best, bestDistance = ground, distance
  return true
 end
 -- A safe death location can be restored exactly. Unsafe water, lava or scenery
 -- use a nearby shore or clearing, never the ordinary distant death spawn.
 consider(origin)
 if not best or bestDistance > 0 then
  for _, point in ipairs(World.SafeSpawns[biome.Id]) do consider(point) end
  -- Refine the guaranteed pool candidate with eight-stud radial steps. Checking
  -- only shorter radii keeps this bounded even when the origin is outside bounds.
  local maximum = math.min(bestDistance, 256)
  for radius = 8, maximum, 8 do
   local found = false
   for step = 0, 15 do
    local angle = step * math.pi / 8
    if consider(origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)) then found = true end
   end
   if found then break end
  end
 end
 assert(best, "Biome has no nearby safe respawn position")
 return CFrame.new(best + Vector3.new(0, 6, 0))
end

local function liveCharacter(player)
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health <= 0 then return nil end
 return character, root, humanoid
end

local function move(player, destination)
 local character, root = liveCharacter(player)
 if not character then return end
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 character:PivotTo(destination)
end

local function validPrompt(player, part)
 local _, root = liveCharacter(player)
 if not root or (root.Position - part.Position).Magnitude > 20 then return false end
 local now = os.clock()
 if promptCooldown[player] and now - promptCooldown[player] < 1 then return false end
 promptCooldown[player] = now
 return true
end

function World.TeleportDestination(sourceId, targetId)
 local ids = Config.Teleports
 if targetId and World.Teleports[targetId] and sourceId ~= targetId then return World.Teleports[targetId] end
 for index, entry in ipairs(ids) do
  if entry.Id == sourceId then return World.Teleports[ids[index % #ids + 1].Id] end
 end
 return nil
end

local function useTeleport(player, sourceId, targetId)
 local source = World.Teleports[sourceId]
 local destination = World.TeleportDestination(sourceId, targetId)
 if not source or not destination or not validPrompt(player, source.Part) then return false end
 if callbacks.OnTeleport and callbacks.OnTeleport(player, sourceId, destination.Id) == true then
  move(player, CFrame.new(destination.Position + Vector3.new(0, 7, 0)))
  return true
 end
 return false
end
function World.UseTeleport(player, targetId)
 local _, root = liveCharacter(player)
 if not root or not World.Teleports[targetId] then return false end
 for sourceId, entry in pairs(World.Teleports) do
  if sourceId ~= targetId and (root.Position - entry.Position).Magnitude <= 20 then
   return useTeleport(player, sourceId, targetId)
  end
 end
 return false
end
World.RequestTeleport = World.UseTeleport

local function useBridge(player, part)
 if not validPrompt(player, part) then return end
 if callbacks.OnBridge and callbacks.OnBridge(player, part, Config.BridgeCost) == true then
  bridgePass[player] = os.clock() + 20
  local side = part:GetAttribute("BridgeSide") or -1
  entrySide[player] = side
  -- The paid crossing carries each buyer safely across; entitlement is per player.
  move(player, CFrame.new(bridge.X - side * 108, Config.GroundY + 7, bridge.Z))
 end
end

function World.Build(receivedCallbacks)
 callbacks = receivedCallbacks or {}
 if built then return folder end
 folder = workspace:FindFirstChild("EvolutionObby")
 if not folder then
  folder = Instance.new("Folder")
  folder.Name, folder.Parent = "EvolutionObby", workspace
 end
 for _, record in ipairs(Layout) do
  local part = create(folder, record)
  part:SetAttribute("Biome", record.biome or World.PositionBiome(part.Position))
  if record.group == "Details" and part.CanCollide then indexObstacle(part) end
  if record.kind == "water" or record.kind == "lava" or record.kind == "swamp" then
   table.insert(hazards, {Part = part, Kind = record.kind})
  elseif record.kind == "spawn" then
   World.StartSpawn = CFrame.new(part.Position + Vector3.new(0, 6, 0))
  elseif record.kind == "teleport" then
   local name = record.id
   for _, definition in ipairs(Config.Teleports) do if definition.Id == record.id then name = definition.Name end end
   World.Teleports[record.id] = {Id = record.id, Name = name, Part = part, Position = part.Position, Biome = record.biome, Cost = record.cost}
   local prompt = part:FindFirstChildOfClass("ProximityPrompt")
   if prompt then prompt.Triggered:Connect(function(player)
    if callbacks.OnTeleportMenu then
     local _, root = liveCharacter(player)
     if not root or (root.Position - part.Position).Magnitude > 20 then return end
     local destinations = {}
     for _, destination in ipairs(Config.Teleports) do
      if destination.Id ~= record.id then
       table.insert(destinations, {Id = destination.Id, Name = destination.Name, Biome = destination.Biome, Cost = destination.Cost})
      end
     end
     callbacks.OnTeleportMenu(player, record.id, destinations)
    else
     useTeleport(player, record.id)
    end
   end) end
  elseif record.kind == "bridge_toll" then
   part:SetAttribute("BridgeSide", record.side)
   local prompt = part:FindFirstChildOfClass("ProximityPrompt")
   if prompt then prompt.Triggered:Connect(function(player) useBridge(player, part) end) end
  end
 end
 groundParams.FilterDescendantsInstances = {folder:FindFirstChild("GroundTerrain")}
 built = true
 workspace:SetAttribute("EvolutionWorldSeed", Config.Seed)
 workspace:SetAttribute("EvolutionWorldReady", true)
 local accumulator = 0
 RunService.Heartbeat:Connect(function(dt)
  accumulator += dt
  if accumulator < 0.12 then return end
  accumulator = 0
  for _, player in ipairs(Players:GetPlayers()) do
   local character, root, humanoid = liveCharacter(player)
   if character then
    local position = root.Position
    local biome = World.PositionBiome(position)
    if biome then character:SetAttribute("Biome", biome) end
    if position.Y < -25 then humanoid.Health = 0 end
    for _, hazard in ipairs(hazards) do
     local part = hazard.Part
     local p = part.CFrame:PointToObjectSpace(position)
     local half = part.Size / 2
     if math.abs(p.X) < half.X and math.abs(p.Z) < half.Z then
      if hazard.Kind == "water" and position.Y < part.Position.Y + half.Y + 1.2 then
       humanoid.Health = 0
      elseif hazard.Kind == "lava" and math.abs(p.Y) < half.Y + 3 then
       local form = character:GetAttribute("Form")
       if form ~= 14 and form ~= 15 then humanoid.Health = 0 end
      elseif hazard.Kind == "swamp" and position.Y < part.Position.Y + 4 then
       -- Marsh water slows traversal without turning every puddle into a death trap.
       local velocity = root.AssemblyLinearVelocity
       root.AssemblyLinearVelocity = Vector3.new(velocity.X * .65, velocity.Y, velocity.Z * .65)
      end
     end
    end
    local dx, dz = position.X - bridge.X, position.Z - bridge.Z
    if math.abs(dz) < bridge.HalfWidth + 3 and math.abs(dx) < bridge.HalfLength and position.Y < 24 then
     if not bridgePass[player] or bridgePass[player] < os.clock() then
      local side = entrySide[player] or (dx < 0 and -1 or 1)
      move(player, CFrame.new(bridge.X + side * 110, Config.GroundY + 7, bridge.Z))
     end
    elseif math.abs(dx) >= bridge.HalfLength and math.abs(dz) < 45 then
     entrySide[player] = dx < 0 and -1 or 1
    end
   end
  end
 end)
 Players.PlayerRemoving:Connect(function(player)
  bridgePass[player], promptCooldown[player], entrySide[player] = nil, nil, nil
 end)
 return folder
end

return World
