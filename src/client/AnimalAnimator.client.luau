-- Cosmetic animation stays on the client. Shared hinges keep feathers, feet,
-- tails and facial details joined, without per-frame server replication.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnimalModels = require(game.ReplicatedStorage.Shared.AnimalModels)
local cache = {}
local wildlife = {}
local nextWildlifeScan = 0

local function discover(character, visual)
 local previous = cache[character]
 local state = {Visual=visual,Joints={},ScanAt=os.clock()+1,WalkClock=previous and previous.WalkClock or 0}
 for _, descendant in ipairs(visual:GetDescendants()) do
  if descendant:IsA("Motor6D") and descendant.Name == "AnimalJoint" and descendant.Part1 then
   table.insert(state.Joints,{
    Joint=descendant,
    Motion=descendant.Part1:GetAttribute("Motion") or "Body",
    Phase=descendant.Part1:GetAttribute("Phase") or 0,
   })
  end
 end
 cache[character] = state
 return state
end

local function animate(character, camera, clock, dt, npc)
 local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
 local humanoid = not npc and character:FindFirstChildOfClass("Humanoid")
 local visual = character:FindFirstChild("AnimalVisual")
 if not root or not visual or (root.Position-camera.CFrame.Position).Magnitude > 220 then return end
 if not npc and not humanoid then return end
 local state = cache[character]
 if not state or state.Visual ~= visual or #state.Joints == 0 or clock >= state.ScanAt then
  state = discover(character,visual)
 end
 local horizontal = root.AssemblyLinearVelocity*Vector3.new(1,0,1)
 local speed = npc and (character:GetAttribute("MoveSpeed") or 9) or horizontal.Magnitude
 local moving = npc and character:GetAttribute("Moving") == true
  or humanoid and horizontal.Magnitude > 1 and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.Health > 0
 local falling = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall or false
 local scale = character:GetAttribute("VisualScale") or 1
 state.WalkClock += dt*math.clamp(speed*.42,3,14)
 AnimalModels.Animate(state.Joints,clock,state.WalkClock,moving,falling,scale,character:GetAttribute("Form") or 1)
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
