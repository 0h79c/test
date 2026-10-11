-- Cosmetic effects stay on the client; none award food or change server physics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("EvolutionEvent",20)
if not remote then return end
-- Also configure a Rojo-created place, which does not contain the XML presets.
local function preset(className,name,properties,parent)
 parent = parent or Lighting
 local effect = parent:FindFirstChild(name)
 if not effect then effect = Instance.new(className); effect.Name = name; effect.Parent = parent end
 for property,value in pairs(properties) do effect[property] = value end
 return effect
end
Lighting.ClockTime = 14.35
Lighting.Brightness = 2.4
Lighting.ExposureCompensation = -0.12
Lighting.Ambient = Color3.fromRGB(61,87,79)
Lighting.OutdoorAmbient = Color3.fromRGB(135,156,148)
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then atmosphere = preset("Atmosphere","Atmosphere",{}) end
atmosphere.Density = 0.22
atmosphere.Offset = 0.18
atmosphere.Glare = 0.2
atmosphere.Haze = 0.65
atmosphere.Color = Color3.fromRGB(224,240,235)
atmosphere.Decay = Color3.fromRGB(161,191,194)
preset("BloomEffect","WildsBloom",{Enabled=true,Intensity=0.16,Size=22,Threshold=1.4})
local correction = preset("ColorCorrectionEffect","WildsColor",{Enabled=true,Contrast=0.08,Saturation=0.08,Brightness=-0.015,TintColor=Color3.fromRGB(247,255,234)})
preset("SunRaysEffect","WildsSunRays",{Enabled=true,Intensity=0.055,Spread=0.85})
preset("DepthOfFieldEffect","WildsDepth",{Enabled=true,FarIntensity=0.08,NearIntensity=0,FocusDistance=110,InFocusRadius=180})
local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then
 sky = preset("Sky","WildsSky",{CelestialBodiesShown=true,StarCount=800})
 for face,suffix in pairs({Bk="bk",Dn="dn",Ft="ft",Lf="lf",Rt="rt",Up="up"}) do
  sky["Skybox"..face] = "rbxasset://textures/sky/sky512_"..suffix..".tex"
 end
end
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
 preset("Clouds","WildsClouds",{Cover=0.22,Density=0.35,Color=Color3.fromRGB(247,247,242)},terrain)
end
local effects = Instance.new("Folder")
effects.Name = "LocalWildsEffects"
effects.Parent = workspace
local function point(position)
 if typeof(position) == "Vector3" then return position end
 return type(position) == "table" and Vector3.new(table.unpack(position)) or Vector3.zero
end
local function anchor(position)
 local part = Instance.new("Part")
 part.Size = Vector3.new(0.1,0.1,0.1)
 part.Transparency = 1
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = false
 part.Position = position
 part.Parent = effects
 return part
end
local function particles(part,color,count)
 local emitter = Instance.new("ParticleEmitter")
 emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
 emitter.Color = ColorSequence.new(color,Color3.fromRGB(255,250,214))
 emitter.LightEmission = 0.8
 emitter.Lifetime = NumberRange.new(0.45,1.1)
 emitter.Speed = NumberRange.new(3,8)
 emitter.Acceleration = Vector3.new(0,3,0)
 emitter.SpreadAngle = Vector2.new(180,180)
 emitter.Rate = 0
 emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.23),NumberSequenceKeypoint.new(1,0)})
 emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
 emitter.Parent = part
 emitter:Emit(count or 18)
end
local function ring(position,color,startSize,endSize,lifetime)
 local part = Instance.new("Part")
 part.Name = "Pulse"
 part.Shape = Enum.PartType.Cylinder
 part.Size = Vector3.new(0.08,startSize,startSize)
 part.CFrame = CFrame.new(position)*CFrame.Angles(0,0,math.pi/2)
 part.Color = color
 part.Material = Enum.Material.Neon
 part.Transparency = 0.25
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = false
 part.CastShadow = false
 part.Parent = effects
 TweenService:Create(part,TweenInfo.new(lifetime or 0.65,Enum.EasingStyle.Quad),{Size=Vector3.new(0.05,endSize,endSize),Transparency=1}):Play()
 Debris:AddItem(part,(lifetime or 0.65)+0.1)
end
local climates = {
 forest={Tint=Color3.fromRGB(230,247,234),Haze=1.15,Density=0.27},
 mountains={Tint=Color3.fromRGB(239,244,252),Haze=0.5,Density=0.2},
 snow={Tint=Color3.fromRGB(227,243,255),Haze=0.8,Density=0.22},
 plains={Tint=Color3.fromRGB(255,248,230),Haze=0.7,Density=0.2},
 meadow={Tint=Color3.fromRGB(247,255,234),Haze=0.65,Density=0.22},
 river={Tint=Color3.fromRGB(232,249,253),Haze=0.8,Density=0.23},
 swamp={Tint=Color3.fromRGB(224,239,218),Haze=1.8,Density=0.3},
 desert={Tint=Color3.fromRGB(255,239,214),Haze=1.2,Density=0.23},
 volcano={Tint=Color3.fromRGB(255,232,220),Haze=1.7,Density=0.28},
}
local lastBiome
local beacons = {}
local function dropEffect(data)
 if not data or not data.Id then return end
 if data.Status == "Claimed" or data.Status == "Expired" then
  if beacons[data.Id] then beacons[data.Id]:Destroy(); beacons[data.Id] = nil end
  return
 end
 if beacons[data.Id] then return end
 local part = anchor(point(data.Position)+Vector3.new(0,0.6,0))
 part.Name = "SupplyLandingLight"
 local low = Instance.new("Attachment")
 low.Parent = part
 local high = Instance.new("Attachment")
 high.Position = Vector3.new(0,105,0)
 high.Parent = part
 local beam = Instance.new("Beam")
 beam.Attachment0 = low
 beam.Attachment1 = high
 beam.Width0 = 6
 beam.Width1 = 16
 beam.FaceCamera = true
 beam.Color = ColorSequence.new(Color3.fromRGB(255,219,136))
 beam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(1,1)})
 beam.LightEmission = 1
 beam.Parent = part
 local emitter = Instance.new("ParticleEmitter")
 emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
 emitter.Color = beam.Color
 emitter.Size = NumberSequence.new(0.4)
 emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)})
 emitter.LightEmission = 1
 emitter.Rate = 5
 emitter.Lifetime = NumberRange.new(2,4)
 emitter.Speed = NumberRange.new(3,6)
 emitter.EmissionDirection = Enum.NormalId.Top
 emitter.SpreadAngle = Vector2.new(20,20)
 emitter.Parent = part
 beacons[data.Id] = part
end
remote.OnClientEvent:Connect(function(action,data)
 if action == "State" and data and data.Biome ~= lastBiome then
  lastBiome = data.Biome
  local climate = climates[data.Biome] or climates.meadow
  if atmosphere then TweenService:Create(atmosphere,TweenInfo.new(4),{Haze=climate.Haze,Density=climate.Density}):Play() end
  if correction then TweenService:Create(correction,TweenInfo.new(4),{TintColor=climate.Tint}):Play() end
 elseif action == "Food" and type(data) == "table" then
  local character = player.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local position = data.Position and point(data.Position) or (root and root.Position)
  if position then
   local part = anchor(position)
   particles(part,Color3.fromRGB(171,245,155),18)
   ring(position,Color3.fromRGB(159,235,154),0.7,5,0.5)
   Debris:AddItem(part,1.6)
  end
 elseif action == "Mutation" or action == "Evolution" then
  local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root then
   local part = anchor(root.Position)
   particles(part,action == "Mutation" and Color3.fromRGB(194,145,255) or Color3.fromRGB(255,212,120),45)
   ring(root.Position-Vector3.new(0,2,0),Color3.fromRGB(237,209,255),1,15,1)
   Debris:AddItem(part,2)
  end
 elseif action == "Drop" then dropEffect(data) end
end)
local dust
player.CharacterAdded:Connect(function() if dust then dust:Destroy(); dust = nil end end)
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
 if os.clock()-lastUpdate < 0.15 then return end
 lastUpdate = os.clock()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid then return end
 if not dust or dust.Parent ~= root then
  if dust then dust:Destroy() end
  dust = Instance.new("Attachment")
  dust.Name = "LocalFootDust"
  dust.Position = Vector3.new(0,-2,0)
  dust.Parent = root
  local emitter = Instance.new("ParticleEmitter")
  emitter.Name = "Dust"
  emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
  emitter.Color = ColorSequence.new(Color3.fromRGB(223,210,180))
  emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.28),NumberSequenceKeypoint.new(1,1.1)})
  emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.82),NumberSequenceKeypoint.new(1,1)})
  emitter.Lifetime = NumberRange.new(0.2,0.6)
  emitter.Speed = NumberRange.new(0.2,0.7)
  emitter.Acceleration = Vector3.new(0,0.8,0)
  emitter.SpreadAngle = Vector2.new(60,60)
  emitter.Rate = 0
  emitter.Parent = dust
 end
 local emitter = dust:FindFirstChild("Dust")
 local moving = root.AssemblyLinearVelocity.Magnitude > 4 and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Health > 0
 if emitter then emitter.Rate = moving and 5 or 0 end
end)
