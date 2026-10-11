-- Server-authoritative, contested supply drops. Paid purchases grant durable
-- credits in Main; this module only queues a physical, publicly contestable drop.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.EventRules)
local Events = {}
local world, callbacks, folder
local active, purchased, pending = {}, {}, 0
local rng = Random.new()
local started = false

local function setting(name, default)
 local values = Config.Drop or Config.SupplyDrop or {}
 return values[name] or default
end
local function announce(entry, status)
 entry.Status = status
 if callbacks.Broadcast then
  callbacks.Broadcast("Drop", {Id=entry.Id, Position=entry.Position, LandingAt=entry.LandingAt, Status=status})
 end
end
local function part(parent, name, size, position, color, material, shape)
 local result = Instance.new("Part")
 result.Name = name
 result.Anchored = true
 result.CanCollide = false
 result.CanTouch = false
 result.CanQuery = false
 result.Size = size
 result.CFrame = CFrame.new(position)
 result.Color = color
 result.Material = material or Enum.Material.SmoothPlastic
 result.TopSurface = Enum.SurfaceType.Smooth
 result.BottomSurface = Enum.SurfaceType.Smooth
 if shape then result.Shape = shape end
 result.Parent = parent
 return result
end
local function link(parent, name, a, b, width, color)
 local length = (b-a).Magnitude
 local result = part(parent, name, Vector3.new(width, width, length), (a+b)/2, color)
 result.CFrame = CFrame.lookAt((a+b)/2, b)
 return result
end
local function label(parent, title, subtitle)
 local gui = Instance.new("BillboardGui")
 gui.Name = "SupplyLabel"
 gui.Size = UDim2.fromOffset(280, 68)
 gui.StudsOffset = Vector3.new(0, 9, 0)
 gui.AlwaysOnTop = false
 gui.MaxDistance = 700
 gui.Parent = parent
 local text = Instance.new("TextLabel")
 text.Size = UDim2.fromScale(1, 1)
 text.BackgroundTransparency = .24
 text.BackgroundColor3 = Color3.fromRGB(18, 27, 39)
 text.TextColor3 = Color3.fromRGB(255, 220, 124)
 text.TextSize = 19
 text.Font = Enum.Font.GothamBold
 text.TextWrapped = true
 text.Text = title .. "\n" .. subtitle
 text.Parent = gui
 local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = text
 return text
end
local function beacon(entry)
 local model = Instance.new("Model")
 model.Name = "LandingBeacon_" .. entry.Id
 model.Parent = folder
 local anchor = part(model, "Target", Vector3.new(3,.15,3), entry.Position+Vector3.new(0,.25,0), Color3.fromRGB(255, 197, 76), Enum.Material.Neon)
 for i = 1, 24 do
  local angle = i/24*math.pi*2
  local radius = 22
  local marker = part(model, "TargetRing", Vector3.new(5.9,.18,1.25), entry.Position+Vector3.new(math.cos(angle)*radius,.35,math.sin(angle)*radius), anchor.Color, Enum.Material.Neon)
  marker.CFrame = CFrame.new(marker.Position)*CFrame.Angles(0,-angle-math.pi/2,0)
 end
 local beam = part(model, "SkyBeacon", Vector3.new(320,1.9,1.9), entry.Position+Vector3.new(0,160,0), anchor.Color, Enum.Material.Neon, Enum.PartType.Cylinder)
 beam.CFrame = CFrame.new(beam.Position)*CFrame.Angles(0,0,math.pi/2)
 beam.Transparency = .65
 local light = Instance.new("PointLight"); light.Brightness=2; light.Range=45; light.Color=anchor.Color; light.Parent=anchor
 entry.Label = label(anchor, "THÍNH ĐANG ĐẾN", "Vị trí đã đánh dấu • Cạnh tranh để nhận quà")
 entry.Beacon = model
end
local function crate(entry)
 local model = Instance.new("Model")
 model.Name = "SupplyCrate_" .. entry.Id
 model:SetAttribute("DropId", entry.Id)
 model.Parent = folder
 local color = Color3.fromRGB(42, 76, 93)
 local trim = Color3.fromRGB(255, 195, 72)
 local body = part(model, "Cargo", Vector3.new(8,6,8), Vector3.zero, color, Enum.Material.Metal)
 model.PrimaryPart = body
 for _, x in ipairs({-4.1,4.1}) do
  part(model, "CargoEdge", Vector3.new(.35,6.5,8.5), Vector3.new(x,0,0), trim, Enum.Material.Metal)
 end
 for _, z in ipairs({-4.1,4.1}) do
  part(model, "CargoEdge", Vector3.new(8.5,6.5,.35), Vector3.new(0,0,z), trim, Enum.Material.Metal)
 end
 for _, x in ipairs({-2.4,2.4}) do
  part(model, "CargoStrap", Vector3.new(.42,6.25,8.25), Vector3.new(x,0,0), Color3.fromRGB(17,28,35), Enum.Material.Metal)
 end
 part(model, "CargoLid", Vector3.new(8.5,.55,8.5), Vector3.new(0,3.1,0), trim, Enum.Material.Metal)
 for _, z in ipairs({-4.3,4.3}) do
  part(model, "CargoSignal", Vector3.new(4.7,.7,.22), Vector3.new(0,.8,z), Color3.fromRGB(135,255,191), Enum.Material.Neon)
 end
 local canopy = Instance.new("Model")
 canopy.Name = "Parachute"; canopy.Parent=model
 local canopyTop = part(canopy, "Canopy", Vector3.new(28,8,28), Vector3.new(0,30,0), Color3.fromRGB(232,81,65), Enum.Material.Fabric, Enum.PartType.Ball)
 canopyTop.Transparency = .08
 for i = 1, 12 do
  local angle = (i-1)/12*math.pi*2
  local point = Vector3.new(math.cos(angle)*11.8,27,math.sin(angle)*11.8)
  local panel = part(canopy, "CanopyPanel", Vector3.new(7.1,.5,11.5), Vector3.new(math.cos(angle)*7,30.5,math.sin(angle)*7), i%2==0 and Color3.fromRGB(249,231,192) or Color3.fromRGB(227,93,58), Enum.Material.Fabric)
  panel.CFrame = CFrame.new(panel.Position)*CFrame.Angles(0,-angle,math.rad(18))
  link(canopy, "SuspensionRope", point, Vector3.new(math.cos(angle)*3.4,3.2,math.sin(angle)*3.4), .12, Color3.fromRGB(238,236,213))
 end
 local light = Instance.new("PointLight"); light.Color=trim; light.Brightness=3; light.Range=35; light.Parent=body
 entry.Crate = model
 entry.Canopy = canopy
 model:PivotTo(CFrame.new(entry.Position+Vector3.new(0,700,0)))
 return body
end
local function cleanup(entry)
 if not active[entry.Id] then return end
 active[entry.Id] = nil
 pending = math.max(0, pending-1)
 if entry.Prompt then entry.Prompt.Enabled = false end
 if entry.Crate then entry.Crate:Destroy() end
 if entry.Beacon then entry.Beacon:Destroy() end
end
local function validPlayer(player, entry)
 if not player or player.Parent ~= Players then return false end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 return root and humanoid and humanoid.Health > 0 and (root.Position-(entry.Position+Vector3.new(0,4,0))).Magnitude <= 16
end
local function claim(player, entry)
 if active[entry.Id] ~= entry or entry.Status ~= "Landed" or not validPlayer(player, entry) then return end
 -- Lock before calling the economy callback; multiple simultaneous prompts
 -- can never award the same crate. A rejected claim can be retried.
 entry.Status = "Claiming"
 entry.Prompt.Enabled = false
 local payload = {
  Coins=rng:NextInteger(setting("CoinsMin",800),setting("CoinsMax",1800)),
  Fullness=rng:NextInteger(setting("FullnessMin",20),setting("FullnessMax",50)),
  MutationBoost=3, DropId=entry.Id,
 }
 local ok, accepted = pcall(callbacks.OnClaim, player, payload)
 if ok and accepted == false then
  entry.Status = "Landed"; entry.Prompt.Enabled = true
  return
 end
 if not ok then warn("Supply drop claim callback failed; suppressing duplicate award", entry.Id) end
 announce(entry, "Claimed")
 cleanup(entry)
end
local function landing(entry)
 if active[entry.Id] ~= entry then return end
 if not entry.Crate then crate(entry) end
 entry.Crate:PivotTo(CFrame.new(entry.Position+Vector3.new(0,3.5,0)))
 if entry.Canopy then entry.Canopy:Destroy(); entry.Canopy=nil end
 if entry.Label then entry.Label.Text = "THÍNH ĐÃ HẠ CÁNH\nCoins + 20–50% độ no + món đột biến ×3" end
 local prompt = Instance.new("ProximityPrompt")
 prompt.ActionText="Mở thính"; prompt.ObjectText="Coins • Thức ăn • Đột biến"
 prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=true; prompt.HoldDuration=1.25
 prompt.Parent=entry.Crate.PrimaryPart; entry.Prompt=prompt
 prompt.Triggered:Connect(function(player) claim(player, entry) end)
 announce(entry,"Landed")
 if entry.PurchaseId and callbacks.OnPurchasedDropDelivered then
  -- Physical delivery and a DataStore write cannot be one atomic operation.
  -- Main retains the paid credit until its acknowledgement is durably saved.
  -- Retry a transient failure even if another player already won the crate.
  task.spawn(function()
   for attempt = 1, 12 do
    local ok, acknowledged = pcall(callbacks.OnPurchasedDropDelivered, entry.Sponsor, entry.PurchaseId)
    if ok and acknowledged == true then return end
    if not ok then warn("Supply drop delivery acknowledgement failed", entry.PurchaseId) end
    task.wait(15)
   end
  end)
 end
 task.delay(setting("DespawnSeconds",600),function()
  if active[entry.Id] ~= entry or entry.Status ~= "Landed" then return end
  announce(entry,"Expired"); cleanup(entry)
 end)
end
local function descend(entry)
 if active[entry.Id] ~= entry then return end
 crate(entry)
 local began=workspace:GetServerTimeNow()
 local duration=math.max(.01,entry.LandingAt-began)
 while active[entry.Id] == entry and workspace:GetServerTimeNow() < entry.LandingAt do
  local progress=math.clamp((workspace:GetServerTimeNow()-began)/duration,0,1)
  local height=3.5+(1-progress)*696.5
  local sway=math.sin(progress*math.pi*4)*(1-progress)*12
  entry.Crate:PivotTo(CFrame.new(entry.Position+Vector3.new(sway,height,0))*CFrame.Angles(0,progress*.4,0))
  RunService.Heartbeat:Wait()
 end
 landing(entry)
end
local function safePosition()
 local position
 if world.GetDropPosition then position=world.GetDropPosition(rng)
 elseif world.RandomPosition then position=world.RandomPosition(rng) end
 if typeof(position) ~= "Vector3" then return nil end
 if world.IsSafePosition and not world.IsSafePosition(position) then return nil end
 return position
end
local function queue(player, purchaseId)
 if not started or pending >= setting("MaxPending",3) or not callbacks.OnClaim then return false end
 if purchaseId and purchased[purchaseId] then return true end
 local position=safePosition()
 if not position then return false end
 local warning=setting("WarningSeconds",180)
 local entry={Id=HttpService:GenerateGUID(false),Position=position,LandingAt=workspace:GetServerTimeNow()+warning,Status="Incoming",Sponsor=player,PurchaseId=purchaseId}
 active[entry.Id]=entry; pending+=1
 if purchaseId then purchased[purchaseId]=entry.Id end
 beacon(entry)
 announce(entry,"Incoming")
 if player and callbacks.Message then callbacks.Message(player,"Thính của bạn đã được đánh dấu. Hạ cánh sau 3 phút; mọi người đều có thể tranh giành!") end
 task.delay(math.max(0,warning-20),function() descend(entry) end)
 return true
end

function Events.RequestPurchasedDrop(player, purchaseId)
 if not player or player.Parent ~= Players then return false end
 if purchaseId ~= nil and (typeof(purchaseId) ~= "string" or purchaseId == "") then return false end
 -- Idempotence is scoped to this server. Main persists paid credits and consumes
 -- one only after queue accepts; never use a client-supplied purchase ID here.
 if purchaseId and purchased[purchaseId] then return true end
 return queue(player,purchaseId)
end
function Events.GetActiveDrops()
 local result={}
 for _,entry in pairs(active) do
  if entry.Status ~= "Claiming" then table.insert(result,{Id=entry.Id,Position=entry.Position,LandingAt=entry.LandingAt,Status=entry.Status}) end
 end
 return result
end
function Events.Start(World, options)
 if started then return end
 world=World; callbacks=options or {}; started=true
 folder=workspace:FindFirstChild("SupplyDrops") or Instance.new("Folder")
 folder.Name="SupplyDrops"; folder.Parent=workspace
 task.spawn(function()
  while started do
   task.wait(setting("CheckInterval",300))
   local count=#Players:GetPlayers()
   if count > 0 and Rules.RollDrop(count,rng) then queue(nil,nil) end
  end
 end)
end
return Events
