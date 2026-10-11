-- Evolution Wilds: responsive exploration HUD, 3D field guide and live drop map.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local WorldConfig = require(shared:WaitForChild("WorldConfig"))
local AnimalModels = require(shared:WaitForChild("AnimalModels"))
local gui = Instance.new("ScreenGui")
gui.Name = "EvolutionUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")
local P = {BG=Color3.fromRGB(12,23,23), Panel=Color3.fromRGB(20,38,36),
 Raised=Color3.fromRGB(31,51,46), Accent=Color3.fromRGB(152,232,171),
 Gold=Color3.fromRGB(249,211,118), Purple=Color3.fromRGB(193,161,255),
 Text=Color3.fromRGB(247,248,234), Muted=Color3.fromRGB(164,188,175)}
local remote, state
local reviveReadyAt, reviveExpiresAt = 0, 0
local dropRecords, dropMarkers, mapViews = {}, {}, {}
local modalPanels, cards = {}, {}
local function send(action, value)
 if remote then remote:FireServer(action, value) end
end
local function decorate(frame, color, radius)
 frame.BackgroundColor3 = color or P.Panel
 frame.BackgroundTransparency = 0.08
 frame.BorderSizePixel = 0
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(0, radius or 12)
 corner.Parent = frame
 local stroke = Instance.new("UIStroke")
 stroke.Color = P.Accent
 stroke.Transparency = 0.8
 stroke.Thickness = 1
 stroke.Parent = frame
end
local function frame(parent, size, position, color)
 local result = Instance.new("Frame")
 result.Size = size
 result.Position = position or UDim2.new()
 result.Parent = parent
 decorate(result, color)
 return result
end
local function label(parent, contents, size, position, fontSize, color)
 local result = Instance.new("TextLabel")
 result.BackgroundTransparency = 1
 result.Size = size
 result.Position = position or UDim2.new()
 result.Font = Enum.Font.GothamMedium
 result.TextSize = fontSize or 14
 result.TextColor3 = color or P.Text
 result.Text = contents
 result.TextWrapped = true
 result.Parent = parent
 return result
end
local function left(result)
 result.TextXAlignment = Enum.TextXAlignment.Left
 return result
end
local function button(parent, contents, size, position, callback, color)
 local result = Instance.new("TextButton")
 result.Size = size
 result.Position = position or UDim2.new()
 result.Font = Enum.Font.GothamBold
 result.TextSize = 13
 result.TextWrapped = true
 result.TextColor3 = P.Text
 result.Text = contents
 result.AutoButtonColor = true
 result.Parent = parent
 decorate(result, color or P.Raised, 9)
 result.Activated:Connect(callback)
 return result
end
local function formatNumber(value)
 local integer = tostring(math.floor(value or 0))
 return integer:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
end
local function asVector(value)
 if typeof(value) == "Vector3" then return value end
 if type(value) == "table" then
  return Vector3.new(value.X or value[1] or 0, value.Y or value[2] or 0, value.Z or value[3] or 0)
 end
 return Vector3.zero
end
local notice = frame(gui, UDim2.new(0.8,0,0,48), UDim2.fromScale(0.5,0.18), P.BG)
notice.AnchorPoint = Vector2.new(0.5,0)
notice.Visible = false
local noticeLimit = Instance.new("UISizeConstraint")
noticeLimit.MaxSize = Vector2.new(560,64)
noticeLimit.Parent = notice
local noticeText = label(notice, "", UDim2.new(1,-24,1,-8), UDim2.fromOffset(12,4), 14)
local noticeVersion = 0
local function toast(message)
 if type(message) ~= "string" then return end
 noticeVersion += 1
 local version = noticeVersion
 noticeText.Text = message
 notice.Visible = true
 task.delay(6,function() if version == noticeVersion then notice.Visible = false end end)
end
local hud = frame(gui, UDim2.fromOffset(344,154), UDim2.fromOffset(22,18))
left(label(hud, "EVOLUTION  /  WILDS", UDim2.new(1,-32,0,23), UDim2.fromOffset(16,10), 15, P.Accent))
local formLabel = left(label(hud, "Khám phá vùng hoang dã", UDim2.new(1,-32,0,25), UDim2.fromOffset(16,35), 17))
local biomeLabel = left(label(hud, "Đang kết nối…", UDim2.new(1,-32,0,19), UDim2.fromOffset(16,62), 12, P.Muted))
local hungerBack = frame(hud, UDim2.new(1,-32,0,15), UDim2.fromOffset(16,91), P.BG)
hungerBack.ClipsDescendants = true
local hungerFill = frame(hungerBack, UDim2.fromScale(0,1), UDim2.new(), P.Accent)
hungerFill.BackgroundTransparency = 0
local hungerGradient = Instance.new("UIGradient")
hungerGradient.Color = ColorSequence.new(Color3.fromRGB(74,150,112), P.Accent)
hungerGradient.Parent = hungerFill
local hungerLabel = left(label(hud, "ĐỘ NO  0%", UDim2.fromOffset(175,23), UDim2.fromOffset(16,111), 12, P.Accent))
local coinLabel = label(hud, "0  COINS", UDim2.fromOffset(138,23), UDim2.fromOffset(190,111), 13, P.Gold)
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
local evolveButton = button(gui, "TIẾN HÓA  [G]", UDim2.fromOffset(344,40), UDim2.fromOffset(22,179), function() send("Evolve") end, Color3.fromRGB(64,113,72))
evolveButton.Visible = false
local compass = frame(gui, UDim2.fromOffset(214,30), UDim2.new(0.5,-107,0,18))
local compassLabel = label(compass, "BẮC   ·   000°", UDim2.fromScale(1,1), UDim2.new(), 11, P.Muted)
local miniPanel = frame(gui, UDim2.fromOffset(220,237), UDim2.new(1,-22,0,18))
miniPanel.AnchorPoint = Vector2.new(1,0)
left(label(miniPanel, "VÙNG HOANG DÃ", UDim2.new(1,-30,0,28), UDim2.fromOffset(14,4), 11, P.Muted))
local miniMap = frame(miniPanel, UDim2.fromOffset(192,168), UDim2.fromOffset(14,34), P.BG)
local coordLabel = label(miniPanel, "", UDim2.new(1,-20,0,22), UDim2.fromOffset(10,207), 10, P.Muted)
local modalShade = Instance.new("TextButton")
modalShade.Name = "ModalShade"
modalShade.BackgroundColor3 = Color3.new(0,0,0)
modalShade.BackgroundTransparency = 0.38
modalShade.BorderSizePixel = 0
modalShade.Text = ""
modalShade.Size = UDim2.fromScale(1,1)
modalShade.Visible = false
modalShade.ZIndex = 3
modalShade.Parent = gui
local function closeModal()
 for _, panel in pairs(modalPanels) do panel.Visible = false end
 modalShade.Visible = false
end
local function showModal(key)
 local panel = modalPanels[key]
 local wasOpen = panel and panel.Visible
 closeModal()
 if panel and not wasOpen then panel.Visible = true; modalShade.Visible = true end
end
modalShade.Activated:Connect(closeModal)
local function modal(key, title, subtitle, width, height)
 local panel = frame(gui, UDim2.new(0.9,0,0.78,0), UDim2.fromScale(0.5,0.52), P.BG)
 panel.AnchorPoint = Vector2.new(0.5,0.5)
 panel.Visible = false
 panel.ZIndex = 4
 local limit = Instance.new("UISizeConstraint")
 limit.MaxSize = Vector2.new(width,height)
 limit.Parent = panel
 left(label(panel,title,UDim2.new(1,-82,0,33),UDim2.fromOffset(20,12),20,P.Accent))
 left(label(panel,subtitle,UDim2.new(1,-36,0,42),UDim2.fromOffset(20,49),12,P.Muted))
 button(panel,"×",UDim2.fromOffset(36,32),UDim2.new(1,-48,0,12),closeModal)
 modalPanels[key] = panel
 return panel
end
local dex = modal("Dex", "SÁCH TIẾN HÓA", "Ăn đủ 100% độ no → tiến hóa. Loài đã mở có thể chọn lại miễn phí.", 880,670)
local dexScroll = Instance.new("ScrollingFrame")
dexScroll.BackgroundTransparency = 1
dexScroll.BorderSizePixel = 0
dexScroll.Size = UDim2.new(1,-32,1,-108)
dexScroll.Position = UDim2.fromOffset(16,96)
dexScroll.ScrollBarThickness = 4
dexScroll.ScrollBarImageColor3 = P.Accent
dexScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
dexScroll.CanvasSize = UDim2.new()
dexScroll.Parent = dex
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.32,-3,0,193)
grid.CellPadding = UDim2.new(0.015,0,0,10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = dexScroll
local previewCache = {}
local function preview(parent, id, locked, mutationName)
 local cacheKey = tostring(id)..tostring(locked)..tostring(mutationName)
 local view = parent:FindFirstChild("Preview")
 if not view then
  view = Instance.new("ViewportFrame")
  view.Name = "Preview"
  view.Size = UDim2.new(1,-12,0,111)
  view.Position = UDim2.fromOffset(6,4)
  view.BackgroundTransparency = 1
  view.Ambient = Color3.fromRGB(167,187,181)
  view.LightColor = Color3.fromRGB(255,239,212)
  view.LightDirection = Vector3.new(-1,-1,-0.5)
  view.Parent = parent
 end
 if previewCache[view] == cacheKey then return end
 previewCache[view] = cacheKey
 view:ClearAllChildren()
 local model = AnimalModels.Build(id)
 model.Parent = view
 if not locked and AnimalModels.ApplySkin then AnimalModels.ApplySkin(model, id, mutationName)
  local mutation = Config.Mutation(mutationName)
  if mutation.Scale then model:ScaleTo(mutation.Scale) end end
 model:PivotTo(CFrame.identity)
 for _, part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored = true
   if locked and part.Transparency < 1 then
    part.Color = Color3.fromRGB(12,21,20)
    part.Material = Enum.Material.SmoothPlastic
   end
  end
 end
 local center, size = model:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 34
 local distance = math.max(size.X,size.Y,size.Z)*1.95+2
 camera.CFrame = CFrame.lookAt(center.Position+Vector3.new(distance*0.67,distance*0.32,-distance),center.Position)
 camera.Parent = view
 view.CurrentCamera = camera
end
for id, species in ipairs(Config.Species) do
 local card = frame(dexScroll, UDim2.new())
 card.LayoutOrder = id
 local nameLabel = label(card, "???", UDim2.new(1,-10,0,22), UDim2.fromOffset(5,112), 14)
 local detail = label(card, "", UDim2.new(1,-10,0,24), UDim2.fromOffset(5,136), 10, P.Muted)
 local selectButton = button(card,"Đang khóa",UDim2.new(1,-16,0,27),UDim2.fromOffset(8,160),function()
  if state and id <= (state.Unlocked or 1) then send("Morph",id) end
 end)
 cards[id] = {Frame=card, Name=nameLabel, Detail=detail, Button=selectButton}
end
local fullMap = modal("Map", "BẢN ĐỒ THÁM HIỂM", "9 vùng sinh thái · ◆ Cổng dịch chuyển có phí · ✦ Vị trí thính · Nằm rải rác, cạnh tranh thức ăn", 840,650)
local bigMap = frame(fullMap, UDim2.new(1,-40,1,-160), UDim2.fromOffset(20,98), P.Panel)
local mapDescription = label(fullMap,"1 stud ≈ 0,28 m · Chết: hồi sinh cùng vùng, cách ít nhất 200 m.",UDim2.new(1,-40,0,42),UDim2.new(0,20,1,-53),12,P.Muted)
local biomeColors = {meadow=Color3.fromRGB(77,124,71), plains=Color3.fromRGB(148,160,94),
 forest=Color3.fromRGB(38,94,71), mountains=Color3.fromRGB(120,126,137),
 swamp=Color3.fromRGB(77,102,85), volcano=Color3.fromRGB(130,70,55),
 river=Color3.fromRGB(61,122,136), desert=Color3.fromRGB(169,139,87),
 snow=Color3.fromRGB(145,170,178)}
local biomeList = WorldConfig.Biomes or {}
local worldSize = asVector(WorldConfig.MapSize or {4320,0,2520})
if worldSize.X <= 0 then worldSize = Vector3.new(4320,0,2520) end
local function mapPosition(position)
 local x = math.clamp(position.X/worldSize.X+0.5,0.01,0.99)
 local z = math.clamp(position.Z/worldSize.Z+0.5,0.01,0.99)
 return UDim2.fromScale(x,z)
end
local function fillMap(map, small)
 map.ClipsDescendants = true
 local playerDot = label(map,"▲",UDim2.fromOffset(small and 16 or 23,small and 16 or 23),UDim2.fromScale(0.5,0.5),small and 14 or 21,P.Text)
 playerDot.AnchorPoint = Vector2.new(0.5,0.5)
 playerDot.ZIndex = 3
 for index, biome in ipairs(biomeList) do
  local center = asVector(biome.Center or biome.center or {((index-1)%3-1)*1440,0,(math.floor((index-1)/3)-1)*840})
  local biomeSize = asVector(biome.Size or biome.size or {1440,0,840})
  if biomeSize.X == 0 then biomeSize = Vector3.new(1440,0,840) end
  local cell = frame(map,UDim2.fromScale(biomeSize.X/worldSize.X,biomeSize.Z/worldSize.Z),mapPosition(center),biome.Color and Color3.fromRGB(table.unpack(biome.Color)) or biomeColors[biome.Id] or Color3.fromRGB(92+index*5,118,92))
  cell.AnchorPoint = Vector2.new(0.5,0.5)
  cell.BackgroundTransparency = small and 0.2 or 0.12
  local cellCorner = cell:FindFirstChildOfClass("UICorner")
  if cellCorner then cellCorner.CornerRadius = UDim.new(0,4) end
  label(cell,biome.Name or biome.Label or biome.Id or tostring(index),UDim2.new(1,-5,1,-5),UDim2.fromOffset(2,2),small and 8 or 15,P.Text)
 end
 local teleports = WorldConfig.Teleports or WorldConfig.Teleporters or {}
 for _, destination in ipairs(teleports) do
  local marker = label(map,"◆",UDim2.fromOffset(17,17),mapPosition(asVector(destination.Position or destination.Center)),small and 10 or 17,P.Gold)
  marker.AnchorPoint = Vector2.new(0.5,0.5)
  marker.ZIndex = 2
 end
 table.insert(mapViews,{Frame=map,Player=playerDot,Drops={},Small=small})
end
fillMap(miniMap,true)
fillMap(bigMap,false)
button(miniPanel,"M",UDim2.fromOffset(28,25),UDim2.new(1,-37,0,4),function() showModal("Map") end)
local shop = modal("Shop", "CỬA HÀNG THÁM HIỂM", "Quyền lợi được máy chủ xác nhận qua Roblox. Giá hiển thị trong hộp mua chính thức.", 640,590)
local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Size = UDim2.new(1,-32,1,-108)
shopScroll.Position = UDim2.fromOffset(16,96)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 4
shopScroll.CanvasSize = UDim2.fromOffset(0,370)
shopScroll.Parent = shop
local passCard = frame(shopScroll,UDim2.new(1,-5,0,202),UDim2.fromOffset(0,0))
left(label(passCard,"EXPLORER PASS",UDim2.new(1,-28,0,27),UDim2.fromOffset(14,12),17,P.Gold))
left(label(passCard,"+50% độ no từ thức ăn  ·  +50% Coins nhặt được\n2 lượt reroll miễn phí / lần ăn thức ăn đột biến\nHồi sinh gần chỗ chết · hồi chiêu 3 phút",UDim2.new(1,-28,0,83),UDim2.fromOffset(14,48),13))
local passButton = button(passCard,"Chưa cấu hình Game Pass",UDim2.new(1,-28,0,39),UDim2.fromOffset(14,146),function()
 if state and state.CommerceConfig and (state.CommerceConfig.PassId or 0) > 0 then send("BuyPass")
 else toast("Chủ game cần tạo Game Pass và nhập PassId trong Config.Commerce.") end
end,Color3.fromRGB(104,88,45))
local dropCard = frame(shopScroll,UDim2.new(1,-5,0,146),UDim2.fromOffset(0,216))
left(label(dropCard,"GỌI THÍNH",UDim2.new(1,-28,0,27),UDim2.fromOffset(14,10),17,P.Purple))
left(label(dropCard,"Báo vị trí trước 3 phút · Coins + 20–50% độ no\n1 thức ăn đột biến với xác suất quý hiếm ×3",UDim2.new(1,-28,0,45),UDim2.fromOffset(14,42),12,P.Muted))
local buyDropButton = button(dropCard,"Chưa cấu hình Developer Product",UDim2.new(1,-28,0,37),UDim2.fromOffset(14,98),function()
 if state and state.CommerceConfig and (state.CommerceConfig.SupplyDropProductId or 0) > 0 then send("BuyDrop")
 else toast("Chủ game cần tạo Developer Product và nhập SupplyDropProductId trong Config.Commerce.") end
end,Color3.fromRGB(79,58,109))
local teleMenu = modal("Teleport","CỔNG DỊCH CHUYỂN","Đến gần cổng để chọn điểm đến. Máy chủ kiểm tra khoảng cách và Coins trước khi dịch chuyển.",560,470)
local teleList = Instance.new("ScrollingFrame")
teleList.BackgroundTransparency = 1
teleList.BorderSizePixel = 0
teleList.Size = UDim2.new(1,-32,1,-110)
teleList.Position = UDim2.fromOffset(16,96)
teleList.ScrollBarThickness = 4
teleList.AutomaticCanvasSize = Enum.AutomaticSize.Y
teleList.CanvasSize = UDim2.new()
teleList.Parent = teleMenu
local teleLayout = Instance.new("UIListLayout")
teleLayout.Padding = UDim.new(0,10)
teleLayout.Parent = teleList
local function populateTeleports(destinations)
 for _, child in ipairs(teleList:GetChildren()) do
  if child:IsA("TextButton") then child:Destroy() end
 end
 for _, destination in ipairs(destinations or {}) do
  local id = destination.Id
  local cost = destination.Cost or WorldConfig.TeleportCost or 100
  button(teleList,(destination.Name or destination.Label or tostring(id)).."  ·  "..formatNumber(cost).." Coins",UDim2.new(1,-6,0,52),UDim2.new(),function() send("Teleport",id); closeModal() end)
 end
end
populateTeleports(WorldConfig.Teleports or WorldConfig.Teleporters)
local controls = frame(gui,UDim2.fromOffset(544,60),UDim2.new(0.5,0,1,-17),P.BG)
controls.AnchorPoint = Vector2.new(0.5,1)
button(controls,"ĂN  [E]",UDim2.fromOffset(88,44),UDim2.fromOffset(8,8),function() send("Eat") end,Color3.fromRGB(55,104,72))
local attackButton = button(controls,"ĐẨY  [F]",UDim2.fromOffset(88,44),UDim2.fromOffset(102,8),function() send("Attack") end,Color3.fromRGB(113,67,52))
button(controls,"SÁCH  [B]",UDim2.fromOffset(96,44),UDim2.fromOffset(196,8),function() showModal("Dex") end)
button(controls,"MAP  [M]",UDim2.fromOffset(90,44),UDim2.fromOffset(298,8),function() showModal("Map") end)
button(controls,"SHOP",UDim2.fromOffset(90,44),UDim2.fromOffset(394,8),function() showModal("Shop") end)
button(controls,"◆",UDim2.fromOffset(42,44),UDim2.fromOffset(490,8),function() showModal("Teleport") end)
local rerollButton = button(gui,"REROLL MIỄN PHÍ  ·  0",UDim2.fromOffset(250,38),UDim2.new(0,22,1,-135),function()
 if state and (state.FreeRerolls or 0) > 0 then send("Reroll") end
end,Color3.fromRGB(79,58,109))
rerollButton.Visible = false
local reviveButton = button(gui,"HỒI SINH GẦN CHỖ CHẾT",UDim2.fromOffset(250,38),UDim2.new(0,22,1,-89),function() send("ReviveNear") end,Color3.fromRGB(75,95,105))
reviveButton.Visible = false
local instruction = label(gui,"WASD: di chuyển  ·  Space: nhảy  ·  E: ăn / tương tác  ·  F: đẩy khi sát người chơi",UDim2.new(0.9,0,0,22),UDim2.new(0.5,0,1,-81),11,P.Muted)
instruction.AnchorPoint = Vector2.new(0.5,1)
local loading = label(hud,"",UDim2.new(1,-32,0,15),UDim2.fromOffset(16,136),9,P.Muted)
local function update(data)
 state = data
 local form = math.clamp(data.Form or 1,1,#Config.Species)
 local species = Config.Species[form]
 local mutations = data.Mutations or {}
 local mutation = Config.Mutation(mutations[tostring(form)] or mutations[form])
 formLabel.Text = species.Name.."  /  "..mutation.Label
 local biomeName = data.Biome or "Đồng cỏ"
 for _, biome in ipairs(biomeList) do if biome.Id == data.Biome then biomeName = biome.Name or biome.Label or biome.Id end end
 biomeLabel.Text = tostring(biomeName).."   ·   "..tostring(data.Unlocked or 1).." / "..#Config.Species.." loài"
 local fullness = math.clamp(data.Fullness or 0,0,100)
 hungerLabel.Text = string.format("ĐỘ NO  %.1f%%",fullness)
 TweenService:Create(hungerFill,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{Size=UDim2.fromScale(fullness/100,1)}):Play()
 coinLabel.Text = formatNumber(data.Coins).."  COINS"
 evolveButton.Visible = fullness >= 100 and (data.Unlocked or 1) < #Config.Species
 loading.Text = data.Loading and "Đang tải tiến trình…" or (data.ReadOnly and "Chơi thử · tiến trình không lưu" or (data.PassOwned and "Explorer Pass đang hoạt động" or "Ăn thức ăn rải rác để tiến hóa"))
 rerollButton.Visible = (data.FreeRerolls or 0) > 0
 rerollButton.Text = "REROLL MIỄN PHÍ  ·  "..tostring(data.FreeRerolls or 0)
 reviveReadyAt = workspace:GetServerTimeNow()+(data.ReviveCooldown or 0)
 reviveExpiresAt = workspace:GetServerTimeNow()+(data.ReviveExpiresIn or 0)
 reviveButton.Visible = data.PassOwned == true and (data.ReviveAvailable == true or (data.ReviveCooldown or 0) > 0)
 local cooldown = data.ReviveCooldown or 0
 reviveButton.Text = cooldown > 0 and ("HỒI SINH GẦN  ·  "..math.ceil(cooldown).."s") or "HỒI SINH GẦN CHỖ CHẾT"
 local commerce = data.CommerceConfig or Config.Commerce or {}
 passButton.Text = data.PassOwned and "Đã sở hữu ✓" or ((commerce.PassId or 0) > 0 and "Mua Explorer Pass" or "Chưa cấu hình Game Pass")
 passButton.AutoButtonColor = not data.PassOwned and (commerce.PassId or 0) > 0
 buyDropButton.Text = (commerce.SupplyDropProductId or 0) > 0 and "Mua / gọi thính" or "Chưa cấu hình Developer Product"
 buyDropButton.AutoButtonColor = (commerce.SupplyDropProductId or 0) > 0
 for id, card in ipairs(cards) do
  local unlocked = id <= (data.Unlocked or 1)
  local mutationName = mutations[tostring(id)] or mutations[id]
  card.Name.Text = unlocked and Config.Species[id].Name or "???"
  card.Detail.Text = unlocked and string.format("Tốc độ %g  ·  Nhảy %g",Config.Species[id].WalkSpeed,Config.Species[id].JumpPower) or ("Bậc tiến hóa "..id)
  card.Button.Text = unlocked and (id == form and "Đang sử dụng ✓" or Config.Mutation(mutationName).Label.."  /  Chọn") or "Chưa mở khóa"
  card.Button.BackgroundColor3 = id == form and Color3.fromRGB(49,94,66) or P.Raised
  preview(card.Frame,id,not unlocked,mutationName)
 end
 if data.Message then toast(data.Message) end
end
local function dropEvent(data)
 if type(data) ~= "table" or not data.Id then return end
 if data.Status == "Claimed" or data.Status == "Expired" then
  dropRecords[data.Id] = nil
  if dropMarkers[data.Id] then dropMarkers[data.Id]:Destroy(); dropMarkers[data.Id] = nil end
  for _, map in ipairs(mapViews) do
   if map.Drops[data.Id] then map.Drops[data.Id]:Destroy(); map.Drops[data.Id] = nil end
  end
  return
 end
 local isNew = not dropRecords[data.Id]
 dropRecords[data.Id] = data
 local position = asVector(data.Position)
 if not dropMarkers[data.Id] then
  local anchor = Instance.new("Part")
  anchor.Name = "DropBeacon_"..tostring(data.Id)
  anchor.Size = Vector3.new(1,1,1)
  anchor.Transparency = 1
  anchor.Anchored = true
  anchor.CanCollide = false
  anchor.CanQuery = false
  anchor.CanTouch = false
  anchor.Position = position+Vector3.new(0,20,0)
  anchor.Parent = workspace
  local billboard = Instance.new("BillboardGui")
  billboard.Name = "DropBeacon"
  billboard.Size = UDim2.fromOffset(170,52)
  billboard.AlwaysOnTop = true
  billboard.MaxDistance = 100000
  billboard.Parent = anchor
  local title = label(billboard,"✦ THÍNH",UDim2.fromScale(1,1),UDim2.new(),14,P.Gold)
  title.Name = "Countdown"
  title.TextStrokeTransparency = 0.4
  dropMarkers[data.Id] = anchor
 end
 for _, map in ipairs(mapViews) do
  if not map.Drops[data.Id] then
   local marker = label(map.Frame,"✦",UDim2.fromOffset(21,21),mapPosition(position),map.Small and 15 or 22,P.Gold)
   marker.ZIndex = 4
   marker.AnchorPoint = Vector2.new(0.5,0.5)
   map.Drops[data.Id] = marker
  end
 end
 if isNew then toast("Thính đã được đánh dấu trên bản đồ. Đến trước khi hạ xuống để tranh phần!") end
end
remote = ReplicatedStorage:WaitForChild("EvolutionEvent",20)
if not remote then
 biomeLabel.Text = "Máy chủ chưa khởi động"
 toast("Không kết nối được game. Mở View → Output trong Studio để xem lỗi.")
 return
end
remote.OnClientEvent:Connect(function(action,data)
 if action == "State" then update(data)
 elseif action == "Drop" then dropEvent(data)
 elseif action == "TeleportMenu" then
  if type(data) == "table" and data.Destinations then populateTeleports(data.Destinations) end
  showModal("Teleport")
 elseif action == "Message" then toast(type(data) == "table" and data.Message or data)
 elseif action == "Mutation" then
  local mutationName = type(data) == "table" and (data.Name or data.Mutation) or data
  toast("Bộ gen mới: "..Config.Mutation(mutationName).Label)
 elseif action == "Food" then
  local gain = type(data) == "table" and data.Gain or 0
  if gain and gain > 0 then toast(string.format("+%.1f%% độ no%s",gain,(data.Coins or 0) > 0 and ("  ·  +"..formatNumber(data.Coins).." Coins") or "")) end
 elseif action == "Attack" then
  attackButton.Text = "ĐẨY!"
  task.delay(0.8,function() attackButton.Text = "ĐẨY  [F]" end)
 end
end)
UserInputService.InputBegan:Connect(function(input,processed)
 if processed or UserInputService:GetFocusedTextBox() then return end
 local key = input.KeyCode
 if key == Enum.KeyCode.B then showModal("Dex")
 elseif key == Enum.KeyCode.M then showModal("Map")
 elseif key == Enum.KeyCode.G then send("Evolve")
 elseif key == Enum.KeyCode.F then send("Attack")
 elseif key == Enum.KeyCode.E then send("Eat")
 elseif key == Enum.KeyCode.O then showModal("Shop")
 elseif key == Enum.KeyCode.Escape then closeModal() end
end)
local function alignCamera(character)
 task.spawn(function()
  local humanoid = character:WaitForChild("Humanoid",15)
  local root = character:WaitForChild("HumanoidRootPart",15)
  if not humanoid or not root then return end
  for _ = 1,100 do
   if player.Character ~= character then return end
   if character:GetAttribute("MorphReady") then break end
   task.wait(0.05)
  end
  if player.Character ~= character then return end
  local camera = workspace.CurrentCamera
  if camera then
   camera.CameraSubject = humanoid
   camera.CameraType = Enum.CameraType.Custom
  end
 end)
end
player.CharacterAdded:Connect(alignCamera)
if player.Character then alignCamera(player.Character) end
local scaledWidgets = {hud,evolveButton,miniPanel,controls,rerollButton,reviveButton}
local widgetScales = {}
for _, widget in ipairs(scaledWidgets) do
 local scale = Instance.new("UIScale")
 scale.Parent = widget
 widgetScales[widget] = scale
end
local lastTick = 0
RunService.RenderStepped:Connect(function()
 local camera = workspace.CurrentCamera
 if not camera then return end
 local width = camera.ViewportSize.X
 local scale = math.clamp(width/1100,0.56,1)
 for _, widgetScale in pairs(widgetScales) do widgetScale.Scale = scale end
 compass.Visible = width > 800
 instruction.Visible = width > 650 and not UserInputService.TouchEnabled
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if root then
  for _, map in ipairs(mapViews) do map.Player.Position = mapPosition(root.Position) end
  coordLabel.Text = string.format("%.0f m  /  %.0f m",root.Position.X*0.28,root.Position.Z*0.28)
  local look = camera.CFrame.LookVector
  local heading = (math.deg(math.atan2(look.X,-look.Z))+360)%360
  local directions = {"BẮC","ĐÔNG BẮC","ĐÔNG","ĐÔNG NAM","NAM","TÂY NAM","TÂY","TÂY BẮC"}
  compassLabel.Text = directions[math.floor((heading+22.5)/45)%8+1]..string.format("   ·   %03d°",math.floor(heading))
 end
 local now = workspace:GetServerTimeNow()
 if now-lastTick < 0.25 then return end
 lastTick = now
 if state and state.PassOwned then
  local cooldown = math.max(0,math.ceil(reviveReadyAt-now))
  reviveButton.Visible = reviveExpiresAt > now or cooldown > 0
  reviveButton.Text = cooldown > 0 and ("HỒI SINH GẦN  ·  "..cooldown.."s") or "HỒI SINH GẦN CHỖ CHẾT"
 end
 for id, drop in pairs(dropRecords) do
  local marker = dropMarkers[id]
  local countdown = marker and marker:FindFirstChild("DropBeacon") and marker.DropBeacon:FindFirstChild("Countdown")
  if countdown then
   local remaining = math.max(0,math.ceil((drop.LandingAt or now)-now))
   countdown.Text = drop.Status == "Landed" and "✦ THÍNH ĐÃ HẠ" or string.format("✦ THÍNH  %d:%02d",math.floor(remaining/60),remaining%60)
  end
 end
end)
send("Sync")
task.delay(3,function() if not state then send("Sync") end end)
