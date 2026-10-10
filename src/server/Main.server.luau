local Players=game:GetService("Players")
local DataStoreService=game:GetService("DataStoreService")
local HttpService=game:GetService("HttpService")
local Config=require(game.ReplicatedStorage.Shared.Config)
local Character=require(script.Parent.Character)
local World=require(script.Parent.World)
local store=DataStoreService:GetDataStore("EvolutionObby_v1")
local rng=Random.new()
local profiles, stations, lastAction, saving = {}, {}, {}, {}
local session=HttpService:GenerateGUID(false)
local remote=Instance.new("RemoteEvent"); remote.Name="EvolutionEvent"; remote.Parent=game.ReplicatedStorage
local function sync(p,message)
 local d=profiles[p]; if not d then return end
 p.leaderstats.Coins.Value=d.Coins; p.leaderstats.Checkpoint.Value=d.Checkpoint
 remote:FireClient(p,"State",{Coins=d.Coins,Checkpoint=d.Checkpoint,Form=d.Form,
  Unlocked=Config.Unlocked(d.Checkpoint),Mutations=d.Mutations,Message=message,ReadOnly=d.ReadOnly})
end
local function save(p,release)
 local d=profiles[p]; if not d or d.ReadOnly then return end
 while saving[p] do task.wait(0.1) end
 saving[p]=true
 local payload={Coins=d.Coins,Checkpoint=d.Checkpoint,Form=d.Form,Mutations=table.clone(d.Mutations)}
 local ok,result=pcall(function()
  return store:UpdateAsync("player_"..p.UserId,function(old)
   if not old or old.Session ~= session then return nil end
   if release then payload.Session=nil else payload.Session=session end
   payload.Lease=release and 0 or os.time()+180
   return payload
  end)
 end)
 saving[p]=nil
 if not ok then
  warn("Save failed for user",p.UserId,result)
  if p.Parent then sync(p,"Lưu dữ liệu đang lỗi. Máy chủ sẽ thử lại ở lần autosave tiếp theo.") end
 elseif not result then
  d.ReadOnly=true
  if p.Parent then sync(p,"Mất khóa dữ liệu: tiến trình phiên này không được lưu.") end
 end
end
local function checkpoint(p,stage)
 local d=profiles[p]
 if not d or stage ~= d.Checkpoint+1 then return end
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position-World.Checkpoints[stage].Position).Magnitude > 18 then return end
 local previous=Config.Unlocked(d.Checkpoint)
 d.Checkpoint=stage; d.Coins+=Config.CheckpointReward
 local unlocked=Config.Unlocked(stage)
 if unlocked>previous then
  d.Form=unlocked; d.Mutations[tostring(unlocked)]=Config.Roll(rng); Character.Apply(p,d)
 end
 sync(p,stage==140 and "Bạn đã mở khóa Rồng Trắng!" or nil)
end
World.Build(checkpoint,function(p,id,value)
 local d=profiles[p]; if not d or d.Collected[id] or math.abs(id-d.Checkpoint)>1 then return end
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 local coinPosition=Vector3.new((id-1)*24+8,13,2)
 if not root or (root.Position-coinPosition).Magnitude>10 then return end
 d.Collected[id]=true; d.Coins+=value; sync(p)
end,function(p,station)
 if profiles[p] then stations[p]=station; remote:FireClient(p,"Station") end
end)
remote.OnServerEvent:Connect(function(p,action,value)
 local d=profiles[p]; if not d then return end
 if lastAction[p] and os.clock()-lastAction[p]<0.5 then return end
 lastAction[p]=os.clock()
 if action=="Sync" then sync(p); return end
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return end
 if action=="Morph" then
  if typeof(value)~="number" or value~=value or value%1~=0 or value<1 or value>Config.Unlocked(d.Checkpoint) then return end
  d.Form=value; Character.Apply(p,d); sync(p)
 elseif action=="Reroll" then
  local root=p.Character:FindFirstChild("HumanoidRootPart")
  local station=stations[p]
  if not root or not station or (root.Position-station.Position).Magnitude>14 then sync(p,"Hãy đến trạm đột biến."); return end
  if d.Coins<Config.RerollCost then sync(p,"Không đủ 500 Coins."); return end
  d.Coins-=Config.RerollCost; d.Mutations[tostring(d.Form)]=Config.Roll(rng)
  Character.Apply(p,d); sync(p,"Đột biến: "..Config.Mutation(d.Mutations[tostring(d.Form)]).Label)
 end
end)
Players.PlayerAdded:Connect(function(p)
 local stats=Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=p
 for _,name in ipairs({"Coins","Checkpoint"}) do local v=Instance.new("IntValue"); v.Name=name; v.Parent=stats end
 local d
 local ok=pcall(function()
  d=store:UpdateAsync("player_"..p.UserId,function(old)
   if old and old.Session and (old.Lease or 0)>os.time() and old.Session~=session then return nil end
   old=old or {Coins=0,Checkpoint=0,Form=1,Mutations={['1']="Normal"}}
   old.Session=session; old.Lease=os.time()+180; return old
  end)
 end)
 if ok and not d then p:Kick("Tiến trình đang mở ở máy chủ khác. Vui lòng thử lại sau."); return end
 if not ok then
  d={Coins=0,Checkpoint=0,Form=1,Mutations={['1']="Normal"},ReadOnly=true}
  warn("DataStore unavailable; temporary progress only",p.UserId)
 end
 d.Checkpoint=math.clamp(math.floor(tonumber(d.Checkpoint) or 0),0,140)
 d.Coins=math.max(0,math.floor(tonumber(d.Coins) or 0))
 d.Form=math.clamp(math.floor(tonumber(d.Form) or 1),1,Config.Unlocked(d.Checkpoint))
 d.Mutations=typeof(d.Mutations)=="table" and d.Mutations or {}
 for i=1,Config.Unlocked(d.Checkpoint) do d.Mutations[tostring(i)]=Config.Mutation(d.Mutations[tostring(i)]).Name end
 d.Collected={}; profiles[p]=d
 local function spawn(character)
  character:WaitForChild("HumanoidRootPart"); character:WaitForChild("Humanoid")
  if profiles[p]~=d then return end
  Character.Apply(p,d); character:PivotTo(World.Checkpoints[d.Checkpoint]); sync(p)
 end
 p.CharacterAdded:Connect(spawn)
 if p.Character then task.spawn(spawn,p.Character) end
 sync(p,d.ReadOnly and "Phiên tạm: tiến trình không được lưu (DataStore chưa khả dụng)." or nil)
end)
Players.PlayerRemoving:Connect(function(p)
 save(p,true); profiles[p]=nil; stations[p]=nil; lastAction[p]=nil
end)
task.spawn(function()
 while true do task.wait(60); for p in pairs(profiles) do task.spawn(save,p,false) end end
end)
game:BindToClose(function()
 local pending=0
 for p in pairs(profiles) do pending+=1; task.spawn(function() save(p,true); pending-=1 end) end
 while pending>0 do task.wait(0.1) end
end)
