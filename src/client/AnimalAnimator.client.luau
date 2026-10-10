-- Cosmetic animation runs independently on each client. Motor6D.Transform
-- does not replicate per frame, so walking does not flood the server network.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local cache = {}

local function discover(character, visual)
 local previous = cache[character]
 local state = {Visual=visual, Joints={}, ScanAt=os.clock()+1, WalkClock=previous and previous.WalkClock or 0}
 for _, descendant in ipairs(visual:GetDescendants()) do
  if descendant:IsA("Motor6D") and descendant.Name == "AnimalJoint" and descendant.Part1 then
   local motion = descendant.Part1:GetAttribute("Motion")
   if motion then
    table.insert(state.Joints, {
     Joint=descendant,
     Motion=motion,
     Phase=descendant.Part1:GetAttribute("Phase") or 0,
    })
   end
  end
 end
 cache[character] = state
 return state
end

Players.PlayerRemoving:Connect(function(player)
 if player.Character then cache[player.Character] = nil end
end)

RunService.PreSimulation:Connect(function(dt)
 local camera = workspace.CurrentCamera
 if not camera then return end
 local clock = os.clock()
 for character in pairs(cache) do
  if not character.Parent then cache[character] = nil end
 end
 for _, player in ipairs(Players:GetPlayers()) do
  local character = player.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  local visual = character and character:FindFirstChild("AnimalVisual")
  if not root or not humanoid or not visual or (root.Position - camera.CFrame.Position).Magnitude > 160 then continue end
  local state = cache[character]
  if not state or state.Visual ~= visual then state = discover(character, visual) end
  -- Parts can replicate after their parent Model. Rediscover until joints exist.
  if #state.Joints == 0 or clock >= state.ScanAt then state = discover(character, visual) end
  local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
  local moving = horizontal.Magnitude > 1 and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Health > 0
  local falling = humanoid:GetState() == Enum.HumanoidStateType.Freefall
  local scale = character:GetAttribute("VisualScale") or 1
  state.WalkClock += dt * math.clamp(horizontal.Magnitude * 0.42, 5, 14)
  local gait = state.WalkClock
  for _, joint in ipairs(state.Joints) do
   if not joint.Joint.Parent then continue end
   local transform = CFrame.identity
   if joint.Motion == "Leg" and moving then
    local wave = math.sin(gait + joint.Phase * math.pi / 2)
    transform = CFrame.new(0, math.max(0, wave) * 0.085 * scale, wave * 0.17 * scale)
   elseif joint.Motion == "Wing" then
    local wave = math.sin(clock * (falling and 5 or 2.3))
    transform = CFrame.new(0, wave * 0.09 * scale, 0) * CFrame.Angles(0, 0, wave * 0.055 * joint.Phase)
   elseif joint.Motion == "Tail" then
    transform = CFrame.new(math.sin(clock * 2.8 + joint.Phase * 0.25) * 0.055 * scale, 0, 0)
   elseif joint.Motion == "Segment" and moving then
    transform = CFrame.new(0, math.sin(clock * 5 + joint.Phase * 0.7) * 0.045 * scale, 0)
   end
   joint.Joint.Transform = transform
  end
 end
end)
