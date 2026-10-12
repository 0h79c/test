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
 particles.LightEmission = 0.55
 particles.LightInfluence = 0.15
 particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
 particles.Rate = rate
 particles.Lifetime = NumberRange.new(0.6, 1.25)
 particles.Speed = NumberRange.new(speed * 0.4, speed)
 particles.SpreadAngle = Vector2.new(55, 55)
 particles.Rotation = NumberRange.new(-180,180)
 particles.RotSpeed = NumberRange.new(-30,30)
 particles.Size = NumberSequence.new({
  NumberSequenceKeypoint.new(0, 0.06),
  NumberSequenceKeypoint.new(0.35, 0.17),
  NumberSequenceKeypoint.new(1, 0),
 })
 particles.Transparency = NumberSequence.new({
  NumberSequenceKeypoint.new(0, 0.5),
  NumberSequenceKeypoint.new(0.25, 0.2),
  NumberSequenceKeypoint.new(1, 1),
 })
 particles.Parent = attachment
 return attachment
end

local function auraRing(visual, radius, height, color, layer)
 for n=1,18 do
  local angle = n*math.pi*2/18
  local part = Instance.new("Part")
  part.Name = "MutationAuraRing"
  part.Size = Vector3.new(.035,.035,radius*.37)
  part.CFrame = CFrame.new(math.sin(angle)*radius,height,math.cos(angle)*radius)
   * CFrame.Angles(0,angle+math.pi/2,0)
  part.Color = color
  part.Material = Enum.Material.Neon
  part.Transparency = layer == 1 and .35 or .65
  part.Anchored = true
  part.CanCollide = false
  part.CanTouch = false
  part.CanQuery = false
  part.CastShadow = false
  part:SetAttribute("Motion","AuraRing")
  part:SetAttribute("Phase",layer == 1 and 1 or -1)
  part:SetAttribute("MotionPivot",Vector3.new(0,height,0))
  part.Parent = visual
 end
end

local function decorateAura(visual, definition, mutation, palette)
 if mutation.Name == "Normal" then return end
 local root = visual.PrimaryPart
 local rate = mutation.Name == "Awakened" and 16 or mutation.Name == "Radioactive" and 12 or 6
 local attachment = emitter(root,"MutationAura",palette.Aura,rate,1.05)
 attachment.Position = Vector3.new(0,definition.Collider[2]*.48,0)
 if mutation.Name == "Awakened" or mutation.Name == "Radioactive" then
  local radius = math.max(.85,definition.Collider[1]*.6)
  auraRing(visual,radius,.09,palette.Aura,1)
  if mutation.Name == "Awakened" then auraRing(visual,radius*1.17,.13,Color3.fromRGB(164,228,235),2) end
  local light = Instance.new("PointLight")
  light.Name = "MutationLight"
  light.Color = palette.Aura
  light.Brightness = mutation.Name == "Awakened" and .6 or .4
  light.Range = 7
  light.Shadows = false
  light.Parent = root
 end
 local highlight = Instance.new("Highlight")
 highlight.Name = "MutationOutline"
 highlight.Adornee = visual
 highlight.FillColor = palette.Aura
 highlight.FillTransparency = 1
 highlight.OutlineColor = palette.Aura
 highlight.OutlineTransparency = mutation.Name == "Awakened" and .38 or .72
 highlight.DepthMode = Enum.HighlightDepthMode.Occluded
 highlight.Parent = visual
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
 local buffModifiers = typeof(data.BuffModifiers) == "table" and data.BuffModifiers or {}
 local function multiplier(value, maximum)
  local number = tonumber(value)
  if not number or number ~= number then return 1 end
  return math.clamp(number, 1, maximum)
 end
 local buffSpeed = multiplier(buffModifiers.Speed, Config.Buffs.SpeedMultiplier)
 local buffScale = multiplier(buffModifiers.Scale, Config.Buffs.GiantScale)

 -- Preserve the Roblox control rig for both R6 and R15. Only the single
 -- collider touches the world; decorative geometry never blocks jumps.
 -- Appearance loading must not resize the hidden rig after its floor probe
 -- and animal feet have been aligned.
 humanoid.AutomaticScalingEnabled = false
 root.RootPriority = 127
 root.Massless = false
 humanoid.UseJumpPower = true
 humanoid.WalkSpeed = species.WalkSpeed * mutation.Speed * buffSpeed
 humanoid.JumpPower = species.JumpPower * mutation.Jump
 humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
 humanoid.AutoRotate = true
 local r6 = humanoid.RigType == Enum.HumanoidRigType.R6
 local leg = r6 and character:FindFirstChild("Left Leg") or nil
 local legHeight = r6 and (leg and leg.Size.Y or 2) or 0
 local baseGroundHeight = root.Size.Y / 2 + (r6 and legHeight or 2)
 for _, instance in ipairs(character:GetDescendants()) do hideAvatar(instance, character) end

 local mutationScale = math.clamp(mutation.Scale, 0.3, 1.5)
 local scale = mutationScale * buffScale
 local collision = definition.Collider
 local colliderSize = Vector3.new(
  math.clamp(collision[1] * mutationScale, 0.95, 3.8),
  math.clamp(collision[2] * mutationScale, 0.7, 4.1),
  math.clamp(collision[3] * mutationScale, 1.4, 4.4)
 ) * buffScale
 -- A giant's floor probe must sit above its new feet. Preserve the floor
 -- position while moving the intact control rig up or down, including a
 -- respawn with an active potion. This does not add velocity on morphing.
 local groundHeight = math.max(baseGroundHeight, colliderSize.Y / 2)
 local clearance = math.min(0.2, 0.08 * math.max(1, scale))
 local previousState = active[character]
 humanoid.HipHeight = groundHeight - root.Size.Y / 2 - legHeight
 humanoid.CameraOffset = Vector3.new(0,-groundHeight+math.max(.7,colliderSize.Y*.6),0)
 character:SetAttribute("BuffSpeed", buffSpeed > 1)
 -- AppearanceLoaded and speed-only potion changes are frequent refreshes.
 -- Keep the live assembly and its ownership intact when geometry is unchanged.
 if previousState and previousState.Form == form and previousState.Mutation == mutation.Name
  and previousState.BuffScale == buffScale and previousState.GroundHeight == groundHeight
  and previousState.Visual == character:FindFirstChild("AnimalVisual")
  and previousState.Collider == character:FindFirstChild("AnimalCollider") then
  return true
 end
 local ownerKnown, previousOwner = false, nil
 if previousState then
  ownerKnown, previousOwner = pcall(function() return root:GetNetworkOwner() end)
 end
 disconnect(character)
 for _, name in ipairs({"AnimalVisual", "AnimalCollider", "GlideForce", "GlideAttachment", "AuraAttachment"}) do
  local old = character:FindFirstChild(name, true)
  if old then old:Destroy() end
 end
 local previousGroundHeight = character:GetAttribute("AnimalGroundHeight") or baseGroundHeight
 if math.abs(groundHeight - previousGroundHeight) > 0.001 then
  local velocity = root.AssemblyLinearVelocity
  root.CFrame = root.CFrame + Vector3.new(0, groundHeight - previousGroundHeight, 0)
  root.AssemblyLinearVelocity = velocity
 end
 local collider = Instance.new("Part")
 collider.Name = "AnimalCollider"
 collider.Shape = Enum.PartType.Ball
 collider.Size = colliderSize
 collider.Anchored = false
 collider.Transparency = 1
 collider.CanCollide = true
 collider.CanTouch = true
 collider.CanQuery = true
 collider.CollisionGroup = "Default"
 collider.Massless = true
 -- A rounded, low-friction contact shape clears the controller's standing
 -- plane slightly, so landing and floor seams cannot pin a flat leading edge.
 collider.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 100)
 collider.CFrame = root.CFrame * CFrame.new(0, -groundHeight + colliderSize.Y / 2 + clearance, 0)
 collider.Parent = character
 local colliderWeld = Instance.new("WeldConstraint")
 colliderWeld.Part0 = root
 colliderWeld.Part1 = collider
 colliderWeld.Parent = collider

 local visual = AnimalModels.Create(form)
 visual.Name = "AnimalVisual"
 visual:SetAttribute("EvolutionVisual", true)
 local palette = AnimalModels.ApplySkin(visual,form,mutation.Name)
 decorateAura(visual,definition,mutation,palette)
 visual:ScaleTo(scale)
 visual:PivotTo(root.CFrame * CFrame.new(0, -groundHeight, 0))
 AnimalModels.Rig(visual,root)
 visual.Parent = character
 -- Assign only after the complete unanchored rig is connected. A morph during
 -- a PvP push preserves the temporary server ownership, including nil.
 pcall(function()
  if ownerKnown then root:SetNetworkOwner(previousOwner) else root:SetNetworkOwner(player) end
 end)

 local nameplate = Instance.new("BillboardGui")
 nameplate.Name = "SpeciesNameplate"
 nameplate.Size = UDim2.fromOffset(240, 44)
 nameplate.StudsOffset = Vector3.new(0, math.max(1.8, visual:GetExtentsSize().Y - groundHeight + 0.9), 0)
 nameplate.MaxDistance = 85
 nameplate.AlwaysOnTop = false
 nameplate.Adornee = root
 nameplate.Parent = visual
 local label = Instance.new("TextLabel")
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundTransparency = 1
 label.Text = species.Name .. " · " .. mutation.Label
 label.TextColor3 = palette.Aura or Color3.fromRGB(255,255,255)
 label.TextStrokeTransparency = 0.35
 label.TextStrokeColor3 = Color3.fromRGB(26, 40, 53)
 label.Font = Enum.Font.GothamBold
 label.TextSize = 14
 label.Parent = nameplate

 if form == 14 then
  local tail = visual:FindFirstChild("TailEmber") or visual.PrimaryPart
  emitter(tail, "PhoenixFlame", Color3.fromRGB(255, 174, 45), 10, 1.1)
  local light = Instance.new("PointLight")
  light.Color = Color3.fromRGB(255, 154, 46)
  light.Brightness = .6
  light.Range = 7
  light.Parent = tail
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

 local state = {Connections={}, Form=form, Mutation=mutation.Name, BuffScale=buffScale,
  GroundHeight=groundHeight, Visual=visual, Collider=collider}
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
 character:SetAttribute("AnimalGroundHeight", groundHeight)
 character:SetAttribute("AnimalFloorClearance", clearance)
 character:SetAttribute("BuffGiant", buffScale > 1)
 character:SetAttribute("BuffSpeed", buffSpeed > 1)
 return true
end

function Character.Cleanup(character)
 disconnect(character)
end

return Character
