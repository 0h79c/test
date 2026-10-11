-- Hand-built food silhouettes, so the game does not depend on private assets.
local FoodModels = {}

local function piece(model, name, size, position, color, shape, material, rotation)
 local part = Instance.new("Part")
 part.Name = name
 part.Size = size
 part.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
 part.Color = color
 part.Shape = shape or Enum.PartType.Ball
 part.Material = material or Enum.Material.SmoothPlastic
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = false
 part.CastShadow = true
 part.Parent = model
 return part
end

local function leaf(model, position, scale, angle, color)
 return piece(model, "Leaf", Vector3.new(1.25, .18, 2.5) * scale, position,
  color or Color3.fromRGB(63, 157, 79), Enum.PartType.Ball, nil,
  CFrame.Angles(0, math.rad(angle or 0), math.rad(18)))
end

local function wedge(model, name, size, position, color, rotation)
 local part = Instance.new("WedgePart")
 part.Name = name
 part.Size = size
 part.CFrame = CFrame.new(position) * (rotation or CFrame.identity)
 part.Color = color
 part.Material = Enum.Material.SmoothPlastic
 part.Anchored = true
 part.CanCollide = false
 part.CanTouch = false
 part.CanQuery = false
 part.Parent = model
 return part
end

local function berry(model)
 for i = 1, 7 do
  local angle = i * math.pi * 2 / 6
  local x, z = math.sin(angle) * .72, math.cos(angle) * .72
  if i == 7 then x, z = 0, 0 end
  local pos = Vector3.new(x, i == 7 and 1.58 or .84, z)
  piece(model, "Berry", Vector3.new(1.05, 1.1, 1.05), pos,
   i % 2 == 0 and Color3.fromRGB(154, 45, 135) or Color3.fromRGB(76, 69, 178))
  piece(model, "Bloom", Vector3.new(.16, .1, .16), pos + Vector3.new(0, .54, 0), Color3.fromRGB(235, 176, 206))
 end
 leaf(model, Vector3.new(-.8, .18, 0), .75, -30)
 leaf(model, Vector3.new(.8, .19, .1), .7, 45)
end

local function apple(model)
 for _, x in ipairs({-.48, .48}) do
  piece(model, "Apple", Vector3.new(1.78, 2.3, 2.18), Vector3.new(x, 1.23, 0), Color3.fromRGB(226, 65, 59))
 end
 piece(model, "AppleBlush", Vector3.new(.68, 1.35, .12), Vector3.new(-.8, 1.38, -.99), Color3.fromRGB(251, 135, 95))
 piece(model, "Stem", Vector3.new(.22, .7, .22), Vector3.new(0, 2.57, 0), Color3.fromRGB(99, 65, 37), Enum.PartType.Cylinder,
  Enum.Material.Wood, CFrame.Angles(0, 0, math.pi / 2 - .18))
 leaf(model, Vector3.new(.5, 2.75, 0), .5, 75)
end

local function mushroom(model)
 piece(model, "Stem", Vector3.new(.94, 2.15, .94), Vector3.new(0, 1.06, 0), Color3.fromRGB(239, 223, 179))
 piece(model, "Gills", Vector3.new(2.78, .24, 2.78), Vector3.new(0, 2.05, 0), Color3.fromRGB(197, 171, 126))
 piece(model, "Cap", Vector3.new(3.4, 1.42, 3.4), Vector3.new(0, 2.44, 0), Color3.fromRGB(194, 80, 69))
 for i = 1, 6 do
  local angle = i * math.pi / 3
  piece(model, "CreamSpot", Vector3.new(.45, .18, .45), Vector3.new(math.cos(angle) * 1.08, 2.96, math.sin(angle) * 1.08), Color3.fromRGB(255, 240, 203))
 end
 piece(model, "CreamSpot", Vector3.new(.7, .14, .7), Vector3.new(0, 3.16, 0), Color3.fromRGB(255, 240, 203))
end

local function fish(model)
 piece(model, "FishBody", Vector3.new(3.75, 1.15, 1.42), Vector3.new(-.25, .77, 0), Color3.fromRGB(80, 159, 184))
 piece(model, "SilverBelly", Vector3.new(2.95, .62, 1.47), Vector3.new(-.45, .5, 0), Color3.fromRGB(186, 219, 220))
 wedge(model, "TailFin", Vector3.new(1.2, .32, 1.65), Vector3.new(2, .7, 0), Color3.fromRGB(39, 119, 148), CFrame.Angles(0, 0, math.pi))
 wedge(model, "DorsalFin", Vector3.new(1.25, .95, .14), Vector3.new(.12, 1.42, 0), Color3.fromRGB(36, 108, 137))
 for _, z in ipairs({-.68, .68}) do
  piece(model, "FishEye", Vector3.new(.35, .35, .09), Vector3.new(-1.45, .86, z), Color3.fromRGB(237, 245, 229))
  piece(model, "Pupil", Vector3.new(.19, .19, .1), Vector3.new(-1.46, .87, z * 1.04), Color3.fromRGB(25, 46, 56))
 end
end

local function meat(model)
 piece(model, "SteakFat", Vector3.new(3.4, .8, 2.5), Vector3.new(0, .55, 0), Color3.fromRGB(246, 210, 187))
 piece(model, "Steak", Vector3.new(2.85, .92, 2.03), Vector3.new(-.16, .68, 0), Color3.fromRGB(185, 73, 72))
 piece(model, "Bone", Vector3.new(2.7, .32, .44), Vector3.new(1.24, .81, 0), Color3.fromRGB(250, 237, 208))
 for _, z in ipairs({-.24, .24}) do
  piece(model, "BoneEnd", Vector3.new(.66, .58, .58), Vector3.new(2.55, .81, z), Color3.fromRGB(250, 237, 208))
 end
 for i = 1, 3 do
  piece(model, "Marbling", Vector3.new(.1, .045, 1.2), Vector3.new(-1.1 + i * .55, 1.13, 0), Color3.fromRGB(235, 164, 144), Enum.PartType.Block,
   nil, CFrame.Angles(0, -.45, 0))
 end
end

local function tropicalFruit(model)
 piece(model, "GoldenFruit", Vector3.new(2.1, 3.05, 2.1), Vector3.new(0, 1.62, 0), Color3.fromRGB(245, 183, 53))
 for row = 1, 3 do
  for i = 1, 6 do
   local a = i * math.pi / 3 + row * .27
   piece(model, "FruitDiamond", Vector3.new(.45, .5, .15), Vector3.new(math.sin(a), .65 + row * .65, math.cos(a)),
    Color3.fromRGB(183, 118, 39), Enum.PartType.Ball, nil, CFrame.Angles(0, a, -.45))
  end
 end
 for i = 1, 5 do
  local a = i * math.pi * 2 / 5
  leaf(model, Vector3.new(math.sin(a) * .45, 3.38, math.cos(a) * .45), .78, math.deg(a), Color3.fromRGB(75, 151, 77))
 end
end

local function mutationFruit(model, boosted)
 local aqua = boosted and Color3.fromRGB(255, 179, 61) or Color3.fromRGB(91, 240, 204)
 local pink = boosted and Color3.fromRGB(245, 72, 164) or Color3.fromRGB(178, 101, 245)
 piece(model, "LuminousFruit", Vector3.new(2.45, 2.8, 2.45), Vector3.new(0, 1.58, 0), aqua, nil, Enum.Material.Neon)
 for i = 1, 6 do
  local a = i * math.pi / 3
  wedge(model, "CrystalPetal", Vector3.new(.65, 1.75, .72), Vector3.new(math.sin(a) * 1.25, .8, math.cos(a) * 1.25), pink,
   CFrame.Angles(0, a, -.3))
  piece(model, "FloatingSeed", Vector3.new(.28, .28, .28), Vector3.new(math.sin(a) * 2, 2.6 + (i % 2) * .4, math.cos(a) * 2), aqua, nil, Enum.Material.Neon)
 end
 local stem = piece(model, "CrystalStem", Vector3.new(.33, 1.2, .33), Vector3.new(0, 3.34, 0), pink, Enum.PartType.Block, Enum.Material.Neon,
  CFrame.Angles(.18, .2, .3))
 local light = Instance.new("PointLight")
 light.Color = aqua
 light.Brightness = 1.6
 light.Range = 17
 light.Shadows = false
 light.Parent = stem
 local attachment = Instance.new("Attachment")
 attachment.Parent = stem
 local particles = Instance.new("ParticleEmitter")
 particles.Color = ColorSequence.new(aqua, pink)
 particles.Rate = 4
 particles.Lifetime = NumberRange.new(1.3, 2)
 particles.Speed = NumberRange.new(.4, 1.2)
 particles.SpreadAngle = Vector2.new(180, 180)
 particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .2), NumberSequenceKeypoint.new(1, 0)})
 particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .2), NumberSequenceKeypoint.new(1, 1)})
 particles.LightEmission = 1
 particles.Parent = attachment
 -- A restrained vertical beacon makes genuinely rare food discoverable.
 local beacon = piece(model, "RareBeacon", Vector3.new(.26, 22, .26), Vector3.new(0, 12, 0), aqua, Enum.PartType.Block, Enum.Material.Neon)
 beacon.Transparency = .7
 beacon.CastShadow = false
end

local tonicStyles = {
 Speed={Color=Color3.fromRGB(64, 205, 255), Light=Color3.fromRGB(183, 249, 255), Label="Tăng tốc · 60 giây"},
 Hunt={Color=Color3.fromRGB(247, 86, 66), Light=Color3.fromRGB(255, 216, 117), Label="Săn vượt 2–4 bậc · 60 giây"},
 Giant={Color=Color3.fromRGB(170, 103, 255), Light=Color3.fromRGB(237, 190, 255), Label="Kích thước ×5 · 60 giây"},
}

local function tonic(model, buff)
 local style = tonicStyles[buff] or tonicStyles.Speed
 local glass = piece(model, "PotionGlass", Vector3.new(2.35, 2.55, 2.35), Vector3.new(0, 1.3, 0),
  style.Light, Enum.PartType.Ball, Enum.Material.Glass)
 glass.Transparency = .55
 local liquid = piece(model, "PotionLiquid", Vector3.new(2.07, 1.7, 2.07), Vector3.new(0, 1.07, 0),
  style.Color, Enum.PartType.Ball, Enum.Material.Neon)
 liquid.Transparency = .13
 local neck = piece(model, "BottleNeck", Vector3.new(.88, 1.25, .88), Vector3.new(0, 2.59, 0),
  style.Light, Enum.PartType.Cylinder, Enum.Material.Glass, CFrame.Angles(0, 0, math.pi / 2))
 -- Cylinders are aligned along their X axis in Roblox.
 neck.Size = Vector3.new(1.25, .88, .88)
 neck.Transparency = .38
 piece(model, "GoldCollar", Vector3.new(.24, 1.09, 1.09), Vector3.new(0, 2.98, 0),
  Color3.fromRGB(238, 190, 91), Enum.PartType.Cylinder, Enum.Material.Metal, CFrame.Angles(0, 0, math.pi / 2))
 piece(model, "Cork", Vector3.new(.43, .69, .69), Vector3.new(0, 3.22, 0),
  Color3.fromRGB(144, 96, 60), Enum.PartType.Cylinder, Enum.Material.Wood, CFrame.Angles(0, 0, math.pi / 2))
 piece(model, "PotionSeal", Vector3.new(1.15, 1.12, .15), Vector3.new(0, 1.35, -1.04),
  Color3.fromRGB(36, 40, 58), Enum.PartType.Ball)
 if buff == "Speed" then
  wedge(model, "LightningUpper", Vector3.new(.47, .72, .12), Vector3.new(-.07, 1.54, -1.18),
   style.Light, CFrame.Angles(0, 0, -.38))
  wedge(model, "LightningLower", Vector3.new(.47, .72, .12), Vector3.new(.07, 1.17, -1.18),
   style.Light, CFrame.Angles(0, 0, math.pi - .38))
 elseif buff == "Hunt" then
  for _, x in ipairs({-.3, 0, .3}) do
   wedge(model, "HunterFang", Vector3.new(.18, .8, .13), Vector3.new(x, 1.34, -1.18),
    style.Light, CFrame.Angles(0, 0, .19))
  end
 else
  piece(model, "GiantEmblem", Vector3.new(.6, .6, .16), Vector3.new(0, 1.35, -1.18),
   style.Light, Enum.PartType.Block, Enum.Material.Neon, CFrame.Angles(0, 0, math.pi / 4))
  for _, x in ipairs({-.46, .46}) do
   wedge(model, "ExpansionArrow", Vector3.new(.26, .44, .15), Vector3.new(x, 1.35, -1.18),
    style.Light, CFrame.Angles(0, 0, x < 0 and -math.pi / 2 or math.pi / 2))
  end
 end
 for i = 1, 3 do
  piece(model, "PotionBubble", Vector3.new(.15, .15, .15), Vector3.new(-.48 + i * .23, .86 + i * .26, -.54),
   style.Light, Enum.PartType.Ball, Enum.Material.Neon)
 end
 local sparkle = Instance.new("Attachment")
 sparkle.Position = Vector3.new(0, 1.1, 0)
 sparkle.Parent = liquid
 local particles = Instance.new("ParticleEmitter")
 particles.Name = "TonicSparkles"
 particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
 particles.Color = ColorSequence.new(style.Color, style.Light)
 particles.Rate = 2
 particles.Lifetime = NumberRange.new(.8, 1.4)
 particles.Speed = NumberRange.new(.3, .8)
 particles.SpreadAngle = Vector2.new(30, 30)
 particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, .17), NumberSequenceKeypoint.new(1, 0)})
 particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .2), NumberSequenceKeypoint.new(1, 1)})
 particles.LightEmission = .8
 particles.Parent = sparkle
 local light = Instance.new("PointLight")
 light.Color = style.Color
 light.Brightness = .6
 light.Range = 9
 light.Shadows = false
 light.Parent = liquid
end

function FoodModels.Create(spec, parent, boosted)
 local model = Instance.new("Model")
 model.Name = spec.Id or "Food"
 local root = piece(model, "Root", Vector3.new(5, 5, 5), Vector3.new(0, 2, 0), Color3.new(1, 1, 1), Enum.PartType.Block)
 root.Transparency = 1
 root.CanTouch = true
 root.CanQuery = true
 root.CastShadow = false
 model.PrimaryPart = root
 local id = string.lower(spec.Id or "berries")
 local isMutation = spec.Mutation == true or id == "mutation"
 local buffStyle = spec.Buff and tonicStyles[spec.Buff]
 if spec.Buff then tonic(model, spec.Buff)
 elseif isMutation then mutationFruit(model, boosted)
 elseif id == "leaf" then
  for i = 1, 3 do leaf(model, Vector3.new((i - 2) * .35, .25 + i * .1, 0), 1, (i - 2) * 55) end
 elseif id == "apple" then apple(model)
 elseif id == "mushroom" then mushroom(model)
 elseif id == "fish" then fish(model)
 elseif id == "meat" then meat(model)
 elseif id == "fruit" then tropicalFruit(model)
 else berry(model) end
 model:SetAttribute("IsFood", true)
 model:SetAttribute("FoodId", spec.Id or "berries")
 model:SetAttribute("Hunger", spec.Hunger or .5)
 model:SetAttribute("RareFood", isMutation)
 model:SetAttribute("BuffType", spec.Buff)
 model:SetAttribute("BuffDuration", spec.Buff and (spec.Duration or 60) or nil)
 model:SetAttribute("MutationMultiplier", boosted and 3 or 1)
 local caption = Instance.new("BillboardGui")
 caption.Name = "FoodCaption"
 caption.Size = UDim2.fromOffset(spec.Buff and 235 or 170, 46)
 caption.StudsOffset = Vector3.new(0, 3.8, 0)
 caption.AlwaysOnTop = false
 caption.MaxDistance = isMutation and 150 or (spec.Buff and 100 or 75)
 caption.Parent = root
 local label = Instance.new("TextLabel")
 label.BackgroundTransparency = 1
 label.Size = UDim2.fromScale(1, 1)
 label.Font = Enum.Font.GothamMedium
 label.TextSize = 13
 label.TextColor3 = buffStyle and buffStyle.Light or (isMutation and Color3.fromRGB(159, 255, 231) or Color3.fromRGB(255, 245, 211))
 label.TextStrokeTransparency = .3
 label.Text = (spec.Name or "Thức ăn") .. (buffStyle and ("\n" .. buffStyle.Label)
  or (boosted and " · ×3 đột biến" or string.format(" · +%g%%", spec.Hunger or .5)))
 label.Parent = caption
 model.Parent = parent
 return model
end

return FoodModels
