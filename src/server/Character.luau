local Config = require(game.ReplicatedStorage.Shared.Config)
local Character = {}
function Character.Apply(player, data)
 local character = player.Character
 if not character then return end
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 local root = character:FindFirstChild("HumanoidRootPart")
 if not humanoid or not root then return end
 local species = Config.Species[data.Form]
 local mutation = Config.Mutation(data.Mutations[tostring(data.Form)])
 for _, name in ipairs({"AnimalVisual", "GlideForce", "GlideAttachment", "AuraAttachment"}) do
  local old = character:FindFirstChild(name, true)
  if old then old:Destroy() end
 end
 character:ScaleTo(mutation.Scale * (data.Form == 5 and 0.65 or 1))
 humanoid.UseJumpPower = true
 humanoid.WalkSpeed = species.WalkSpeed * mutation.Speed
 humanoid.JumpPower = species.JumpPower * mutation.Jump
 local visual = Instance.new("Model")
 visual.Name = "AnimalVisual"
 visual.Parent = character
 local color = data.Form == 15 and Color3.new(1,1,1) or Color3.fromHSV(data.Form/15,0.65,0.9)
 if mutation.Name == "Radioactive" then color = Color3.fromHSV((player.UserId % 100)/100,1,1) end
 for _, part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") and part ~= root then part.Transparency = 1 end
 end
 local scale = character:GetScale()
 local function body(name, size, offset, shape)
  local p = Instance.new("Part")
  p.Name = name
  p.Shape = shape or Enum.PartType.Ball
  p.Size = size * scale
  p.CFrame = root.CFrame * CFrame.new(offset * scale)
  p.Color = color
  p.Material = mutation.Name == "Radioactive" and Enum.Material.Neon or Enum.Material.SmoothPlastic
  p.CanCollide = false
  p.CanTouch = false
  p.Massless = true
  p.Parent = visual
  local weld = Instance.new("WeldConstraint")
  weld.Part0 = root; weld.Part1 = p; weld.Parent = p
  return p
 end
 body("Body",Vector3.new(2.2,1.6,3),Vector3.new(0,-0.5,0))
 body("Head",Vector3.new(1.6,1.6,1.6),Vector3.new(0,0,-1.7))
 for _, x in ipairs({-0.45,0.45}) do
  local eye = body("Eye",Vector3.new(0.3,0.3,0.3),Vector3.new(x,0.35,-2.4))
  eye.Color = Color3.new(0,0,0)
 end
 if data.Form == 1 or data.Form == 5 then
  local shell = body("Shell",Vector3.new(2.4,2,2.5),Vector3.new(0,0.25,0.3))
  shell.Color = Color3.fromRGB(115,80,45)
 elseif data.Form == 2 then
  for z=1,3 do body("Segment",Vector3.new(1.7,1.5,1.7),Vector3.new(0,-0.5,z)) end
 elseif data.Form >= 13 then
  for _, x in ipairs({-2,2}) do body("Wing",Vector3.new(3,0.3,2),Vector3.new(x,0.5,0),Enum.PartType.Block) end
 else
  for _, x in ipairs({-0.6,0.6}) do body("Ear",Vector3.new(0.5,data.Form == 6 and 1.8 or 0.8,0.5),Vector3.new(x,1,-1.6)) end
 end
 if mutation.Name == "Awakened" or data.Form == 14 then
  local attachment = Instance.new("Attachment")
  attachment.Name="AuraAttachment"; attachment.Position=Vector3.new(0,-2,0); attachment.Parent=root
  local emitter=Instance.new("ParticleEmitter")
  emitter.Color=ColorSequence.new(data.Form == 14 and Color3.fromRGB(255,110,20) or color)
  emitter.Rate=20; emitter.Lifetime=NumberRange.new(0.5,1); emitter.Speed=NumberRange.new(1,3)
  emitter.Parent=attachment
 end
 if data.Form == 13 or mutation.Name == "Awakened" then
  local attachment=Instance.new("Attachment"); attachment.Name="GlideAttachment"; attachment.Parent=root
  local force=Instance.new("VectorForce"); force.Name="GlideForce"; force.Attachment0=attachment
  force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=true
  force.Force=Vector3.new(0,root.AssemblyMass*workspace.Gravity*0.18,0); force.Parent=root
 end
 character:SetAttribute("Form",data.Form)
 character:SetAttribute("Mutation",mutation.Name)
end
return Character
