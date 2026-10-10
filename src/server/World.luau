local World = {}
World.Checkpoints = {}
function World.Build(onCheckpoint, onCoin, onStation)
 local folder=Instance.new("Folder"); folder.Name="EvolutionObby"; folder.Parent=workspace
 local function part(name,size,position,color)
  local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Position=position
  p.Anchored=true; p.Color=color; p.Parent=folder; return p
 end
 local function player(hit)
  local model=hit:FindFirstAncestorOfClass("Model")
  return model and game.Players:GetPlayerFromCharacter(model)
 end
 local spawn=Instance.new("SpawnLocation"); spawn.Size=Vector3.new(24,1,24)
 spawn.Position=Vector3.new(0,10,0); spawn.Anchored=true; spawn.Neutral=true; spawn.Parent=folder
 World.Checkpoints[0]=spawn.CFrame + Vector3.new(0,5,0)
 for stage=0,140 do
  local x=stage*24
  if stage > 0 then
   local platform=part("Checkpoint"..stage,Vector3.new(14,1,14),Vector3.new(x,10,0),Color3.fromRGB(70,190,130))
   World.Checkpoints[stage]=platform.CFrame + Vector3.new(0,5,0)
   platform.Touched:Connect(function(hit) local p=player(hit); if p then onCheckpoint(p,stage) end end)
  end
  if stage < 140 then
   for step=1,2 do
    part("Jump",Vector3.new(7,1,8),Vector3.new(x+step*8,10,step==1 and 2 or -2),Color3.fromRGB(90,130,210))
   end
   local coin=part("Coin",Vector3.new(1,1,1),Vector3.new(x+8,13,2),Color3.fromRGB(255,215,40))
   coin.Shape=Enum.PartType.Ball; coin.Material=Enum.Material.Neon; coin.CanCollide=false
   coin.Touched:Connect(function(hit) local p=player(hit); if p then onCoin(p,stage+1,25) end end)
   if stage >= 30 and stage % 3 == 0 then
    local lava=part("Lava",Vector3.new(2,0.25,8),Vector3.new(x+16,10.65,-2),Color3.fromRGB(255,70,15))
    lava.Material=Enum.Material.Neon
    lava.Touched:Connect(function(hit)
     local p=player(hit); local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
     if h and p.Character:GetAttribute("Form") ~= 14 then h.Health=0 end
    end)
   end
  end
  if stage % 10 == 0 then
   local station=part("MutationPad",Vector3.new(5,1,5),Vector3.new(x,11,5),Color3.fromRGB(165,70,230))
   local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Đột biến · 500 Coins"
   prompt.ObjectText="Trạm đột biến"; prompt.RequiresLineOfSight=false; prompt.MaxActivationDistance=12; prompt.Parent=station
   prompt.Triggered:Connect(function(p) onStation(p,station) end)
  end
 end
 local void=part("Void",Vector3.new(3500,1,200),Vector3.new(1680,-20,0),Color3.fromRGB(255,40,30))
 void.Transparency=1
 void.Touched:Connect(function(hit)
  local p=player(hit); local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h then h.Health=0 end
 end)
 return folder
end
return World
