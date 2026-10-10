local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimalModels = require(ReplicatedStorage.Shared:WaitForChild("AnimalModels"))
local gui = Instance.new("ScreenGui")
gui.Name = "EvolutionUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local palette = {BG=Color3.fromRGB(17,24,39), Panel=Color3.fromRGB(28,39,57),
 Accent=Color3.fromRGB(85,230,171), Purple=Color3.fromRGB(176,120,255),
 Text=Color3.fromRGB(245,249,255), Muted=Color3.fromRGB(170,187,209)}
local remote
local state
local function send(action, value)
 if remote then remote:FireServer(action,value) end
end
local function decorate(frame, color)
 frame.BackgroundColor3=color or palette.Panel
 frame.BorderSizePixel=0
 local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,12); corner.Parent=frame
 local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(62,80,104); stroke.Transparency=0.35; stroke.Parent=frame
end
local function frame(parent,size,position,color)
 local f=Instance.new("Frame"); f.Size=size; f.Position=position or UDim2.new(); f.Parent=parent
 decorate(f,color); return f
end
local function text(parent,contents,size,position,fontSize,color)
 local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=size; t.Position=position or UDim2.new()
 t.Font=Enum.Font.GothamMedium; t.TextSize=fontSize or 16; t.TextColor3=color or palette.Text
 t.Text=contents; t.TextWrapped=true; t.Parent=parent; return t
end
local function button(parent,contents,size,position,callback,color)
 local b=Instance.new("TextButton"); b.Size=size; b.Position=position or UDim2.new()
 b.Text=contents; b.TextSize=15; b.TextWrapped=true; b.Font=Enum.Font.GothamBold
 b.TextColor3=palette.Text; b.AutoButtonColor=true; b.Parent=parent; decorate(b,color)
 b.Activated:Connect(callback); return b
end
local hud=frame(gui,UDim2.new(0.62,0,0,88),UDim2.fromOffset(12,12))
local hudLimit=Instance.new("UISizeConstraint"); hudLimit.MaxSize=Vector2.new(520,88); hudLimit.Parent=hud
local title=text(hud,"EVOLUTION OBBY",UDim2.new(1,-20,0,24),UDim2.fromOffset(10,6),18,palette.Accent)
title.TextXAlignment=Enum.TextXAlignment.Left
local formLabel=text(hud,"Đang khởi động…",UDim2.new(1,-20,0,25),UDim2.fromOffset(10,30),15)
formLabel.TextXAlignment=Enum.TextXAlignment.Left
local progress=text(hud,"Checkpoint 0 / 140",UDim2.new(1,-20,0,23),UDim2.fromOffset(10,56),13,palette.Muted)
progress.TextXAlignment=Enum.TextXAlignment.Left
local coins=frame(gui,UDim2.new(0.28,0,0,56),UDim2.new(1,-12,0,12))
coins.AnchorPoint=Vector2.new(1,0)
local coinLabel=text(coins,"0 COINS",UDim2.new(1,-10,1,0),UDim2.fromOffset(5,0),18,Color3.fromRGB(255,220,100))
local notice=text(gui,"",UDim2.new(1,-30,0,48),UDim2.new(0,15,1,-62),15)
notice.BackgroundColor3=palette.BG; notice.BackgroundTransparency=0.15; notice.Visible=false
local noticeVersion=0
local function toast(message)
 noticeVersion+=1
 local version=noticeVersion
 notice.Text=message; notice.Visible=true; notice.TextTransparency=0
 task.delay(6,function()
  if version==noticeVersion then notice.Visible=false end
 end)
end
local menu=frame(gui,UDim2.new(0,165,0,152),UDim2.fromOffset(12,110))
button(menu,"Sách Tiến Hóa",UDim2.new(1,-12,0,44),UDim2.fromOffset(6,6),function() end,palette.Panel)
local dexToggle=menu:FindFirstChildOfClass("TextButton")
button(menu,"Về checkpoint",UDim2.new(1,-12,0,40),UDim2.fromOffset(6,55),function() send("Checkpoint") end)
button(menu,"Về sảnh",UDim2.new(1,-12,0,40),UDim2.fromOffset(6,102),function() send("Lobby") end)
local dex=frame(gui,UDim2.fromScale(0.91,0.72),UDim2.fromScale(0.5,0.52),palette.BG)
dex.AnchorPoint=Vector2.new(0.5,0.5); dex.Visible=false
local dexLimit=Instance.new("UISizeConstraint"); dexLimit.MaxSize=Vector2.new(920,700); dexLimit.Parent=dex
text(dex,"SÁCH TIẾN HÓA",UDim2.new(1,-80,0,38),UDim2.fromOffset(16,8),22,palette.Accent)
text(dex,"Đổi dạng đã mở miễn phí · Mỗi 10 checkpoint mở một loài",UDim2.new(1,-24,0,30),UDim2.fromOffset(12,48),13,palette.Muted)
button(dex,"×",UDim2.fromOffset(40,36),UDim2.new(1,-48,0,10),function() dex.Visible=false end)
dexToggle.Activated:Connect(function() dex.Visible=not dex.Visible end)
local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-24,1,-96); scroll.Position=UDim2.fromOffset(12,86)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=5
scroll.CanvasSize=UDim2.new(); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=dex
local grid=Instance.new("UIGridLayout")
grid.CellSize=UDim2.new(0.32,-4,0,182); grid.CellPadding=UDim2.new(0.015,0,0,10); grid.SortOrder=Enum.SortOrder.LayoutOrder; grid.Parent=scroll
local cards={}
local viewportCache={}
local function preview(parent,id,locked)
 local view=parent:FindFirstChild("Preview")
 if not view then
  view=Instance.new("ViewportFrame"); view.Name="Preview"; view.Size=UDim2.new(1,-12,0,97)
  view.Position=UDim2.fromOffset(6,5); view.BackgroundTransparency=1; view.Parent=parent
  view.Ambient=Color3.fromRGB(190,190,190); view.LightColor=Color3.new(1,1,1)
  view.LightDirection=Vector3.new(-1,-1,-1)
 end
 if viewportCache[view]==tostring(id)..tostring(locked) then return view end
 viewportCache[view]=tostring(id)..tostring(locked)
 view:ClearAllChildren()
 -- A replicated Model can arrive before its parts. Build complete previews
 -- from the same canonical geometry instead of caching a partial clone.
 local model=AnimalModels.Build(id)
 model.Parent=view; model:PivotTo(CFrame.new())
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored=true
   if locked and part.Transparency<1 then part.Color=Color3.fromRGB(5,9,16); part.Material=Enum.Material.SmoothPlastic end
  end
 end
 local center,size=model:GetBoundingBox()
 local camera=Instance.new("Camera"); camera.FieldOfView=40
 local distance=math.max(size.X,size.Y,size.Z)*1.8+2
 camera.CFrame=CFrame.lookAt(center.Position+Vector3.new(distance*0.7,distance*0.4,-distance),center.Position)
 camera.Parent=view; view.CurrentCamera=camera
 return view
end
for id,species in ipairs(Config.Species) do
 local card=frame(scroll,UDim2.new()); card.LayoutOrder=id
 local name=text(card,"???",UDim2.new(1,-8,0,22),UDim2.fromOffset(4,102),15)
 local detail=text(card,"Checkpoint "..((id-1)*10),UDim2.new(1,-8,0,24),UDim2.fromOffset(4,126),11,palette.Muted)
 local select=button(card,"Đang khóa",UDim2.new(1,-12,0,28),UDim2.fromOffset(6,151),function()
  if state and id<=state.Unlocked then send("Morph",id) end
 end)
 cards[id]={Frame=card,Name=name,Detail=detail,Button=select}
end
local station=frame(gui,UDim2.fromScale(0.85,0.6),UDim2.fromScale(0.5,0.5),palette.BG)
station.AnchorPoint=Vector2.new(0.5,0.5); station.Visible=false
local stationLimit=Instance.new("UISizeConstraint"); stationLimit.MaxSize=Vector2.new(540,490); stationLimit.Parent=station
text(station,"TRẠM ĐỘT BIẾN",UDim2.new(1,-64,0,40),UDim2.fromOffset(12,8),22,palette.Purple)
button(station,"×",UDim2.fromOffset(36,34),UDim2.new(1,-46,0,10),function() station.Visible=false end)
local stationView=frame(station,UDim2.new(1,-32,0.34,0),UDim2.fromOffset(16,60))
local stationName=text(station,"",UDim2.new(1,-24,0,40),UDim2.new(0,12,0.48,10),17)
local odds=text(station,"Nguyên bản 50% · Khổng lồ 20% · Tí hon 15%\nPhát quang 10% · Thức tỉnh 5%",UDim2.new(1,-24,0,58),UDim2.new(0,12,0.6,0),12,palette.Muted)
local rolling=false
local reroll=button(station,"Đổ lại gen · 500 Coins",UDim2.new(1,-32,0,46),UDim2.new(0,16,1,-86),function()
 if rolling then return end
 if state and state.Coins>=Config.RerollCost and not state.Loading then
  rolling=true; send("Reroll")
  task.delay(2,function() rolling=false end)
 else toast("Bạn cần 500 Coins. Nhặt xu và vượt checkpoint để kiếm thêm.") end
end,Color3.fromRGB(108,68,164))
text(station,"Đột biến chỉ thay đổi loài đang trang bị",UDim2.new(1,-24,0,26),UDim2.new(0,12,1,-34),12,palette.Muted)
local function update(data)
 state=data
 local species=Config.Species[data.Form]
 local mutation=Config.Mutation(data.Mutations[tostring(data.Form)])
 formLabel.Text=species.Name.." · "..mutation.Label
 local mode=data.Loading and " · Đang tải" or (data.ReadOnly and " · Chơi thử, không lưu" or "")
 progress.Text="Checkpoint "..data.Checkpoint.." / 140 · "..data.Unlocked.."/15 loài"..mode
 coinLabel.Text=tostring(data.Coins).." COINS"
 stationName.Text=species.Name.." · "..mutation.Label
 reroll.Text=(data.Coins>=Config.RerollCost and "Đổ lại gen · 500 Coins" or "Cần 500 Coins · Hiện có "..data.Coins)
 for id,card in ipairs(cards) do
  local unlocked=id<=data.Unlocked
  card.Name.Text=unlocked and Config.Species[id].Name or "???"
  card.Detail.Text=unlocked and string.format("Speed %g · Jump %g",Config.Species[id].WalkSpeed,Config.Species[id].JumpPower) or ("Mở tại checkpoint "..((id-1)*10))
  card.Button.Text=unlocked and (id==data.Form and "Đang sử dụng ✓" or Config.Mutation(data.Mutations[tostring(id)]).Label.." · Chọn") or "Chưa mở khóa"
  card.Button.BackgroundColor3=unlocked and (id==data.Form and Color3.fromRGB(37,121,95) or palette.Panel) or Color3.fromRGB(35,41,53)
  preview(card.Frame,id,not unlocked)
 end
 local view=preview(stationView,data.Form,false)
 view.Size=UDim2.new(1,0,1,0); view.Position=UDim2.new()
 if data.Message then toast(data.Message) end
end
remote=ReplicatedStorage:WaitForChild("EvolutionEvent",15)
if not remote then
 formLabel.Text="Máy chủ chưa khởi động"
 toast("Không kết nối được game. Mở View → Output trong Studio để xem lỗi khởi động.")
 return
end
remote.OnClientEvent:Connect(function(action,data)
 if action=="State" then update(data)
 elseif action=="Station" then station.Visible=true; dex.Visible=false
 elseif action=="Coin" then
  local world=workspace:FindFirstChild("EvolutionObby")
  if world then for _,part in ipairs(world:GetDescendants()) do
   if part:IsA("BasePart") and part:GetAttribute("CoinId")==data then
    part.LocalTransparencyModifier=1
    local light=part:FindFirstChildOfClass("PointLight"); if light then light.Enabled=false end
   end
  end end
 elseif action=="Mutation" then
  rolling=false
  toast("Đột biến mới: "..Config.Mutation(data).Label)
  local flash=Instance.new("Frame"); flash.Size=UDim2.fromScale(1,1); flash.BackgroundColor3=palette.Purple
  flash.BackgroundTransparency=0.65; flash.BorderSizePixel=0; flash.ZIndex=30; flash.Parent=gui
  local tween=TweenService:Create(flash,TweenInfo.new(0.65),{BackgroundTransparency=1})
  tween:Play(); tween.Completed:Connect(function() flash:Destroy() end)
 end
end)
local function alignCamera(character)
 task.spawn(function()
  local root=character:WaitForChild("HumanoidRootPart",15)
  local humanoid=character:WaitForChild("Humanoid",15)
  if not root or not humanoid then return end
  for _=1,100 do
   if player.Character~=character then return end
   if character:GetAttribute("MorphReady") then break end
   task.wait(0.05)
  end
  if not character:GetAttribute("MorphReady") or player.Character~=character then return end
  RunService.RenderStepped:Wait()
  local camera=workspace.CurrentCamera
  if not camera then return end
  camera.CameraSubject=humanoid
  camera.CameraType=Enum.CameraType.Custom
  local target=root.Position+Vector3.new(0,-1,0)
  camera.CFrame=CFrame.lookAt(target-root.CFrame.LookVector*14+Vector3.new(0,6,0),target)
 end)
end
player.CharacterAdded:Connect(alignCamera)
if player.Character then alignCamera(player.Character) end
send("Sync")
task.delay(3,function() if not state then send("Sync") end end)
RunService.RenderStepped:Connect(function(dt)
 if not station.Visible or not rolling then return end
 local view=stationView:FindFirstChild("Preview")
 local model=view and view:FindFirstChildOfClass("Model")
 if model then model:PivotTo(model:GetPivot()*CFrame.Angles(0,dt*7,0)) end
end)
