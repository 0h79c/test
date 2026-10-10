local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local AnimalModels = require(game.ReplicatedStorage.Shared.AnimalModels)

local Character = {}
local active = {}
local initialized = false

local function disconnect(character)
 local state = active[character]
 if not state then return end
 for _, connection in ipairs(state.Connections) do connection:Disconnect() end
 active[character] = nil
end

function Character.Initialize()
 if not initialized then
  if not PhysicsService:IsCollisionGroupRegistered("EvolutionAvatar") then
   PhysicsService:RegisterCollisionGroup("EvolutionAvatar")
  end
  PhysicsService:CollisionGroupSetCollidable("EvolutionAvatar", "Default", false)
  PhysicsService:CollisionGroupSetCollidable("EvolutionAvatar", "EvolutionAvatar", false)
  initialized = true
 end
 return AnimalModels.EnsureLibrary()
end

local function belongsToAnimal(instance, character)
 local ancestor = instance.Parent
 while ancestor and ancestor ~= character do
  if ancestor:GetAttribute("EvolutionVisual") then return true end
  ancestor = ancestor.Parent
 end
 return false
end

local function hideAvatar(instance, character)
 if instance.Name == "AnimalCollider" or belongsToAnimal(instance, character) then return end
 if instance:IsA("BasePart") then
  instance.Transparency = 1
  instance.CanCollide = false
  instance.CanTouch = false
  instance.CanQuery = false
  -- Humanoid floor sensing uses its root's collision group. The root remains
  -- query-compatible with the map even though it never physically collides.
  instance.CollisionGroup = instance.Name == "HumanoidRootPart" and "Default" or "EvolutionAvatar"
  instance.Massless = instance.Name ~= "HumanoidRootPart"
 elseif instance:IsA("Decal") or instance:IsA("Texture") then
  instance.Transparency = 1
 elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") then
  instance.Enabled = false
 end
end

local function emitter(parent, name, color, rate, speed)
 local attachment = Instance.new("Attachment")
 attachment.Name = name
 attachment.Parent = parent
 local particles = Instance.new("ParticleEmitter")
 particles.Name = name .. "Particles"
 particles.Color = ColorSequence.new(color)
 particles.LightEmission = 0.7
 particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
 particles.Rate = rate
 particles.Lifetime = NumberRange.new(0.35, 0.75)
 particles.Speed = NumberRange.new(speed * 0.4, speed)
 particles.SpreadAngle = Vector2.new(25, 25)
 particles.Size = NumberSequence.new({
  NumberSequenceKeypoint.new(0, 0.25),
  NumberSequenceKeypoint.new(0.35, 0.4),
  NumberSequenceKeypoint.new(1, 0),
 })
 particles.Transparency = NumberSequence.new({
  NumberSequenceKeypoint.new(0, 0.15),
  NumberSequenceKeypoint.new(1, 1),
 })
 particles.Parent = attachment
 return attachment
end

function Character.Apply(player, data)
 local character = player.Character
 if not character then return false end
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 local root = character:FindFirstChild("HumanoidRootPart")
 if not humanoid or not root then return false end
 if not initialized then Character.Initialize() end
 data = data or {}
 local form = math.clamp(math.floor(tonumber(data.Form) or 1), 1, #Config.Species)
 local mutations = typeof(data.Mutations) == "table" and data.Mutations or {}
 local species = Config.Species[form]
 local mutation = Config.Mutation(mutations[tostring(form)])
 local definition = AnimalModels.Definitions[form]

 disconnect(character)
 for _, name in ipairs({"AnimalVisual", "AnimalCollider", "GlideForce", "GlideAttachment", "AuraAttachment"}) do
  local old = character:FindFirstChild(name, true)
  if old then old:Destroy() end
 end

 -- Preserve the Roblox control rig for both R6 and R15. Only the single
 -- collider touches the world; decorative geometry never blocks jumps.
 humanoid.UseJumpPower = true
 humanoid.WalkSpeed = species.WalkSpeed * mutation.Speed
 humanoid.JumpPower = species.JumpPower * mutation.Jump
 humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
 humanoid.AutoRotate = true
 local groundHeight
 if humanoid.RigType == Enum.HumanoidRigType.R6 then
  humanoid.HipHeight = 0
  local leg = character:FindFirstChild("Left Leg")
  groundHeight = root.Size.Y / 2 + (leg and leg.Size.Y or 2)
 else
  humanoid.HipHeight = 2
  groundHeight = root.Size.Y / 2 + humanoid.HipHeight
 end
 for _, instance in ipairs(character:GetDescendants()) do hideAvatar(instance, character) end

 local scale = mutation.Scale
 if form == 5 then scale *= 0.72 end
 scale = math.clamp(scale, 0.3, 1.5)
 local collision = definition.Collider
 local colliderSize = Vector3.new(
  math.clamp(collision[1] * scale, 0.95, 3.8),
  math.clamp(collision[2] * scale, 0.7, 4.1),
  math.clamp(collision[3] * scale, 1.4, 4.4)
 )
 humanoid.CameraOffset = Vector3.new(0, -groundHeight + colliderSize.Y / 2 - 0.5, 0)
 local collider = Instance.new("Part")
 collider.Name = "AnimalCollider"
 collider.Size = colliderSize
 collider.Transparency = 1
 collider.CanCollide = true
 collider.CanTouch = true
 collider.CanQuery = true
 collider.CollisionGroup = "Default"
 collider.Massless = true
 collider.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.35, 0, 1, 1)
 collider.CFrame = root.CFrame * CFrame.new(0, -groundHeight + colliderSize.Y / 2, 0)
 collider.Parent = character
 local colliderWeld = Instance.new("WeldConstraint")
 colliderWeld.Part0 = root
 colliderWeld.Part1 = collider
 colliderWeld.Parent = collider

 local visual = AnimalModels.Create(form)
 visual.Name = "AnimalVisual"
 visual:SetAttribute("EvolutionVisual", true)
 visual:ScaleTo(scale)
 visual:PivotTo(root.CFrame * CFrame.new(0, -groundHeight, 0))
 visual.Parent = character
 local glow = Color3.fromHSV((player.UserId % 360) / 360, 0.8, 1)
 for _, part in ipairs(visual:GetDescendants()) do
  if part:IsA("BasePart") then
   if mutation.Name == "Radioactive" and part.Name ~= "Root"
    and part.Name ~= "Pupil" and part.Name ~= "Eye" and part.Name ~= "Nose" then
    if part.Color.R + part.Color.G + part.Color.B > 1.4 then
     part.Color = part.Color:Lerp(glow, 0.7)
     part.Material = Enum.Material.Neon
    end
   end
   local weld = Instance.new("Motor6D")
   weld.Name = "AnimalJoint"
   weld.Part0 = root
   weld.Part1 = part
   weld.C0 = root.CFrame:ToObjectSpace(part.CFrame)
   weld.Parent = part
   part.Anchored = false
   part.CanCollide = false
   part.CanTouch = false
   part.CanQuery = false
   part.Massless = true
  end
 end

 local nameplate = Instance.new("BillboardGui")
 nameplate.Name = "SpeciesNameplate"
 nameplate.Size = UDim2.fromOffset(240, 44)
 nameplate.StudsOffset = Vector3.new(0, math.max(1.8, visual:GetExtentsSize().Y - groundHeight + 0.9), 0)
 nameplate.MaxDistance = 55
 nameplate.AlwaysOnTop = false
 nameplate.Adornee = root
 nameplate.Parent = visual
 local label = Instance.new("TextLabel")
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundTransparency = 1
 label.Text = species.Name .. " · " .. mutation.Label
 label.TextColor3 = mutation.Name == "Awakened" and Color3.fromRGB(255, 224, 134) or Color3.fromRGB(255, 255, 255)
 label.TextStrokeTransparency = 0.35
 label.TextStrokeColor3 = Color3.fromRGB(26, 40, 53)
 label.Font = Enum.Font.GothamBold
 label.TextSize = 14
 label.Parent = nameplate

 if form == 14 then
  local tail = visual:FindFirstChild("TailEmber") or visual.PrimaryPart
  emitter(tail, "PhoenixFlame", Color3.fromRGB(255, 174, 45), 17, 1.8)
  local light = Instance.new("PointLight")
  light.Color = Color3.fromRGB(255, 154, 46)
  light.Brightness = 1.1
  light.Range = 9
  light.Parent = tail
 end
 if mutation.Name == "Awakened" then
  emitter(visual.PrimaryPart, "AwakenedAura", Color3.fromRGB(253, 214, 94), 24, 2)
  local highlight = Instance.new("Highlight")
  highlight.Name = "AwakenedOutline"
  highlight.Adornee = visual
  highlight.FillTransparency = 0.9
  highlight.OutlineColor = Color3.fromRGB(255, 216, 94)
  highlight.OutlineTransparency = 0.2
  highlight.DepthMode = Enum.HighlightDepthMode.Occluded
  highlight.Parent = visual
 elseif mutation.Name == "Radioactive" then
  emitter(visual.PrimaryPart, "RadioactiveAura", glow, 10, 1.1)
 end

 local glideForce
 if form >= 13 or mutation.Name == "Awakened" then
  local attachment = Instance.new("Attachment")
  attachment.Name = "GlideAttachment"
  attachment.Parent = root
  glideForce = Instance.new("VectorForce")
  glideForce.Name = "GlideForce"
  glideForce.Attachment0 = attachment
  glideForce.RelativeTo = Enum.ActuatorRelativeTo.World
  glideForce.ApplyAtCenterOfMass = true
  glideForce.Force = Vector3.zero
  glideForce.Parent = root
 end

 local state = {Connections={}}
 active[character] = state
 table.insert(state.Connections, character.DescendantAdded:Connect(function(instance)
  hideAvatar(instance, character)
 end))
 local glideClock = 0
 table.insert(state.Connections, RunService.Heartbeat:Connect(function(dt)
  if character.Parent == nil or humanoid.Health <= 0 then
   if glideForce then glideForce.Force = Vector3.zero end
   return
  end
  glideClock += dt
  if glideClock < 0.1 then return end
  glideClock = 0
  local falling = humanoid:GetState() == Enum.HumanoidStateType.Freefall and root.AssemblyLinearVelocity.Y < -2
  if glideForce then
   glideForce.Force = falling and Vector3.new(0, root.AssemblyMass * workspace.Gravity * 0.28, 0) or Vector3.zero
  end
 end))
 table.insert(state.Connections, character.AncestryChanged:Connect(function(_, parent)
  if not parent then disconnect(character) end
 end))
 character:SetAttribute("Form", form)
 character:SetAttribute("Mutation", mutation.Name)
 character:SetAttribute("MorphReady", true)
 character:SetAttribute("VisualScale", scale)
 return true
end

function Character.Cleanup(character)
 disconnect(character)
end

return Character
