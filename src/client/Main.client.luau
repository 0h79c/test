local Players=game:GetService("Players")
local Config=require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remote=game.ReplicatedStorage:WaitForChild("EvolutionEvent")
local gui=Instance.new("ScreenGui"); gui.Name="EvolutionUI"; gui.ResetOnSpawn=false
gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function label(parent,text,size,position)
 local item=Instance.new("TextLabel"); item.Size=size; item.Position=position
 item.BackgroundColor3=Color3.fromRGB(25,30,45); item.TextColor3=Color3.new(1,1,1)
 item.Text=text; item.TextWrapped=true; item.TextSize=16; item.Font=Enum.Font.Gotham; item.Parent=parent
 return item
end
local function button(parent,text,size,position,callback)
 local item=Instance.new("TextButton"); item.Size=size; item.Position=position
 item.BackgroundColor3=Color3.fromRGB(65,85,150); item.TextColor3=Color3.new(1,1,1)
 item.Text=text; item.TextSize=16; item.TextWrapped=true; item.Parent=parent
 item.Activated:Connect(callback); return item
end
local hud=label(gui,"Đang tải…",UDim2.new(1,-24,0,65),UDim2.fromOffset(12,12))
local message=label(gui,"",UDim2.new(1,-24,0,40),UDim2.new(0,12,1,-50))
local dex=Instance.new("Frame"); dex.Size=UDim2.new(0.9,0,0.65,0); dex.Position=UDim2.fromScale(0.05,0.2)
dex.BackgroundColor3=Color3.fromRGB(20,25,40); dex.Visible=false; dex.Parent=gui
button(gui,"Sách Tiến Hóa",UDim2.fromOffset(170,42),UDim2.fromOffset(12,85),function() dex.Visible=not dex.Visible end)
button(dex,"Đóng",UDim2.new(1,0,0,35),UDim2.new(),function() dex.Visible=false end)
local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,1,-40)
scroll.Position=UDim2.fromOffset(0,40); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.CanvasSize=UDim2.new(); scroll.ScrollBarThickness=6; scroll.Parent=dex
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,5); layout.Parent=scroll
local state; local buttons={}
for i=1,#Config.Species do
 buttons[i]=button(scroll,"???",UDim2.new(1,-10,0,45),UDim2.new(),function()
  if state and i<=state.Unlocked then remote:FireServer("Morph",i) end
 end)
end
local station=Instance.new("Frame"); station.Size=UDim2.new(0.8,0,0,180)
station.Position=UDim2.fromScale(0.1,0.35); station.Visible=false; station.Parent=gui
local prompt=label(station,"",UDim2.new(1,0,0,90),UDim2.new())
button(station,"Đổ lại gen · 500 Coins",UDim2.new(1,0,0,45),UDim2.fromOffset(0,90),function() remote:FireServer("Reroll") end)
button(station,"Đóng",UDim2.new(1,0,0,40),UDim2.fromOffset(0,140),function() station.Visible=false end)
remote.OnClientEvent:Connect(function(action,data)
 if action=="Station" then station.Visible=true; return end
 if action~="State" then return end
 state=data
 local species=Config.Species[data.Form]
 hud.Text=string.format("%s · %s | Coins: %d | Checkpoint: %d/140%s",species.Name,
  Config.Mutation(data.Mutations[tostring(data.Form)]).Label,data.Coins,data.Checkpoint,data.ReadOnly and " · Không lưu" or "")
 prompt.Text="Đổ lại gen Đột Biến cho "..species.Name.."? Giá: 500 Coins"
 for i,b in ipairs(buttons) do
  b.Text=i<=data.Unlocked and string.format("%d. %s · %s%s",i,Config.Species[i].Name,
   Config.Mutation(data.Mutations[tostring(i)]).Label,i==data.Form and " ✓" or "") or string.format("??? · Mở tại checkpoint %d",(i-1)*10)
  b.BackgroundColor3=i<=data.Unlocked and Color3.fromRGB(65,85,150) or Color3.fromRGB(40,40,40)
 end
 if data.Message then message.Text=data.Message end
end)
remote:FireServer("Sync")
