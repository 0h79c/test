-- Cosmetic animation stays on the client. Shared articulated hinges preserve
-- feet, feathers and face details while the gait follows real ground speed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnimalModels = require(game.ReplicatedStorage.Shared.AnimalModels)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cache = {}
local wildlife = {}
local nextWildlifeScan = 0

local function discover(character, visual, clock)
 local previous = cache[character]
 local state = {
  Visual=visual, Joints={}, ScanAt=clock+1,
  WalkClock=previous and previous.WalkClock or 0,
  Speed=previous and previous.Speed or 0, Blend=previous and previous.Blend or 0,
  LastPosition=previous and previous.LastPosition, LastSample=previous and previous.LastSample,
 }
 for _, descendant in ipairs(visual:GetDescendants()) do
  if descendant:IsA("Motor6D") and descendant.Name == "AnimalJoint" and descendant.Part1 then
   table.insert(state.Joints,AnimalModels.DescribeJoint(descendant))
  end
 end
 cache[character] = state
 return state
end

local function animate(character, camera, clock, dt, npc)
 local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
 local humanoid = not npc and character:FindFirstChildOfClass("Humanoid")
 local visual = character:FindFirstChild("AnimalVisual")
 if not root or not visual or (not npc and not humanoid) then return end
 local state = cache[character]
 if (root.Position-camera.CFrame.Position).Magnitude > 300 then
  if state then state.LastPosition=nil; state.LastSample=nil; state.Speed=0; state.Blend=0 end
  return
 end
 if not state or state.Visual ~= visual or #state.Joints == 0 or clock >= state.ScanAt then
  state = discover(character,visual,clock)
 end
 local form = character:GetAttribute("Form") or 1
 local scale = character:GetAttribute("VisualScale") or 1
 local horizontal = root.AssemblyLinearVelocity*Vector3.new(1,0,1)
 local speed = horizontal.Magnitude
 if npc then
  -- Anchored TweenService NPCs report zero AssemblyLinearVelocity. Measure
  -- their replicated position, so blocked/stopped AI never run in place.
  local elapsed = state.LastSample and clock-state.LastSample or 0
  speed = 0
  if state.LastPosition and elapsed > 0 and elapsed < .5 then
   local distance = ((root.Position-state.LastPosition)*Vector3.new(1,0,1)).Magnitude
   local expected = (Config.Species[form] or Config.Species[1]).WalkSpeed
   if distance <= math.max(24,expected*elapsed*3) then speed = distance/elapsed end
  end
 end
 state.LastPosition=root.Position
 state.LastSample=clock
 local grounded = npc or humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Health > 0
 local moving = grounded and speed > .35
 local falling = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall or false
 local alpha = 1-math.exp(-math.min(dt,.1)*12)
 state.Speed += ((moving and speed or 0)-state.Speed)*alpha
 state.Blend += ((moving and 1 or 0)-state.Blend)*alpha
 state.WalkClock += math.min(dt,.1)*AnimalModels.GaitRate(form,state.Speed,scale)
 AnimalModels.Animate(state.Joints,clock,state.WalkClock,state.Blend,falling,scale,form,state.Speed)
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
  if player.Character then animate(player.Character,camera,clock,dt,false) end
 end
 if clock >= nextWildlifeScan then
  nextWildlifeScan = clock+1
  table.clear(wildlife)
  local folder = workspace:FindFirstChild("Wildlife")
  if folder then
   for _, npc in ipairs(folder:GetChildren()) do
    if npc:IsA("Model") and npc:GetAttribute("IsNPC") then table.insert(wildlife,npc) end
   end
  end
 end
 for _, npc in ipairs(wildlife) do
  if npc.Parent then animate(npc,camera,clock,dt,true) end
 end
end)
