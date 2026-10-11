-- Runtime client smoke tests. GUI drawing, streaming and physics need Studio.
return function(configSource,worldSource,uiSource,effectsSource)
 local function signal()
  local handlers = {}
  return {Connect=function(_,fn) table.insert(handlers,fn); return {Disconnect=function() end} end,
   Fire=function(_,...) for _,fn in ipairs(handlers) do fn(...) end end}
 end
 local vectorMeta={}
 local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,Kind="Vector3"},vectorMeta) end
 vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vectorMeta.__mul=function(a,b) return vector(a.X*b,a.Y*b,a.Z*b) end
 vectorMeta.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
 local frameMeta={}
 local function cframe(x,y,z) return setmetatable({Position=type(x)=="table" and x or vector(x,y,z),LookVector=vector(0,0,-1)},frameMeta) end
 frameMeta.__mul=function(a,b) return cframe(a.Position+b.Position) end
 local function enums()
  return setmetatable({},{__index=function(t,k) local value=enums();rawset(t,k,value);return value end})
 end
 local instances,methods,meta = {},{},{}
 meta.__index=function(obj,key)
  if methods[key] then return methods[key] end
  if obj._p[key]~=nil then return obj._p[key] end
  for _,child in ipairs(obj._children) do if child.Name==key then return child end end
 end
 meta.__newindex=function(obj,key,value)
  if key=="Parent" then
   if obj._p.Parent then
    local old=obj._p.Parent._children
    local index=table.find(old,obj)
    if index then table.remove(old,index) end
   end
   obj._p.Parent=value
   if value then table.insert(value._children,obj) end
  else obj._p[key]=value end
 end
 local function instance(class)
  local obj=setmetatable({_p={Name=class,ClassName=class},_children={},_attrs={}},meta)
  obj.Activated=signal(); obj.CharacterAdded=signal(); obj.OnClientEvent=signal()
  if class=="Part" then obj.Transparency=0;obj.Position=vector();obj.Size=vector(1,1,1) end
  table.insert(instances,obj)
  return obj
 end
 function methods:GetChildren() return table.clone(self._children) end
 function methods:GetDescendants()
  local result={}
  for _,child in ipairs(self._children) do
   table.insert(result,child)
   for _,descendant in ipairs(child:GetDescendants()) do table.insert(result,descendant) end
  end
  return result
 end
 function methods:FindFirstChild(name)
  for _,child in ipairs(self._children) do if child.Name==name then return child end end
 end
 function methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing fixture "..name) end
 function methods:FindFirstChildOfClass(class)
  for _,child in ipairs(self._children) do if child.ClassName==class then return child end end
 end
 function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
 function methods:Destroy() self.Parent=nil;self.Destroyed=true;self:ClearAllChildren() end
 function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
 function methods:PivotTo(target) self.Pivot=target end
 function methods:GetBoundingBox() return cframe(),vector(6,4,7) end
 function methods:ScaleTo(value) self.Scale=value end
 function methods:GetAttribute(name) return self._attrs[name] end
 function methods:Emit(count) self.Emitted=count end
 local sent={}
 function methods:FireServer(action,value) table.insert(sent,{Action=action,Value=value}) end
 local function folder(name,parent,class)
  local obj=instance(class or "Folder");obj.Name=name;obj.Parent=parent;return obj
 end
 local storage=folder("ReplicatedStorage")
 local shared=folder("Shared",storage)
 local refs={}
 for _,name in ipairs({"Config","WorldConfig","AnimalModels"}) do refs[name]=folder(name,shared,"ModuleScript") end
 local event=folder("EvolutionEvent",storage,"RemoteEvent")
 local player=folder("LocalPlayer",nil,"Player")
 local playerGui=folder("PlayerGui",player)
 local workspace=folder("Workspace")
 workspace.CurrentCamera=folder("Camera",workspace,"Camera")
 workspace.CurrentCamera.ViewportSize=vector(1280,800)
 workspace.CurrentCamera.CFrame=cframe()
 local clock=1000
 function workspace:GetServerTimeNow() return clock end
 local lighting=folder("Lighting")
 folder("Terrain",workspace,"Terrain")
 local runService={RenderStepped=signal(),Heartbeat=signal()}
 local input={InputBegan=signal(),TouchEnabled=false}
 function input:GetFocusedTextBox() return nil end
 local config=assert(loadstring(configSource))()
 local world=assert(loadstring(worldSource))()
 local models={}
 function models.Build(form) return folder("PreviewSpecies"..form,nil,"Model") end
 function models.ApplySkin(_,form,_) assert(type(form)=="number","Preview calls skin API with form id") end
 local enum=enums()
 local env=setmetatable({game={GetService=function(_,name)
   return assert(({Players={LocalPlayer=player},ReplicatedStorage=storage,Lighting=lighting,
    RunService=runService,UserInputService=input,
    TweenService={Create=function(_,target,_,props) return {Play=function() for k,v in pairs(props) do target[k]=v end end} end},
    Debris={AddItem=function() end}})[name],name)
  end},workspace=workspace,Instance={new=instance},Enum=enum,
  Color3={fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end,new=function(r,g,b) return {R=r,G=g,B=b} end},
  Vector3={new=vector,zero=vector()},Vector2={new=vector},
  CFrame={new=cframe,Angles=function() return cframe() end,identity=cframe(),lookAt=function(pos) return cframe(pos) end},
  UDim={new=function(s,o) return {Scale=s,Offset=o} end},
  UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end,
   fromScale=function(x,y) return {X={Scale=x},Y={Scale=y}} end,fromOffset=function(x,y) return {X={Offset=x},Y={Offset=y}} end},
  ColorSequence={new=function(a,b) return {a,b} end},NumberSequence={new=function(a) return a end},
  NumberSequenceKeypoint={new=function(a,b) return {a,b} end},NumberRange={new=function(a,b) return {a,b} end},
  TweenInfo={new=function() return {} end},typeof=function(v) return type(v)=="table" and v.Kind or type(v) end,
  require=function(ref) return ({[refs.Config]=config,[refs.WorldConfig]=world,[refs.AnimalModels]=models})[ref] end,
  task={delay=function() end,spawn=function(fn) fn() end,wait=function() end},
 },{__index=getfenv(0)})
 local function execute(source) local fn=assert(loadstring(source));setfenv(fn,env);fn() end
 execute(uiSource)
 execute(effectsSource)
 assert(playerGui:FindFirstChild("EvolutionUI"),"HUD starts without Character/data")
 assert(sent[1].Action=="Sync","Client requests initial state")
 local function textContaining(text,class)
  for _,obj in ipairs(instances) do
   if not obj.Destroyed and type(obj.Text)=="string" and obj.Text:find(text,1,true) and (not class or obj.ClassName==class) then return obj end
  end
 end
 local function state(overrides)
  local result={Coins=1200,Fullness=65.5,Form=3,Unlocked=3,Mutations={["3"]="Tiny"},FreeRerolls=0,PassOwned=false,ReadOnly=true,Loading=false,
   Biome="forest",CommerceConfig={PassId=0,SupplyDropProductId=0},ReviveCooldown=0,ReviveExpiresIn=0}
  for k,v in pairs(overrides or {}) do result[k]=v end
  event.OnClientEvent:Fire("State",result)
  return result
 end
 state()
 assert(textContaining("ĐỘ NO  65.5%"),"Fractional food hunger is visible")
 assert(textContaining("1.200  COINS"),"Coins are formatted")
 assert(textContaining("Chuột  /  Tí hon"),"Current form uses stored mutation")
 local evolve=textContaining("TIẾN HÓA  [G]","TextButton")
 assert(evolve and not evolve.Visible,"Cannot evolve below 100%")
 state({Fullness=100})
 assert(evolve.Visible,"Full hunger exposes evolution action")
 evolve.Activated:Fire()
 assert(sent[#sent].Action=="Evolve")
 state({Fullness=100,Unlocked=15})
 assert(not evolve.Visible,"Final form stops evolution button")
 local pass=textContaining("Chưa cấu hình Game Pass","TextButton")
 local calls=#sent
 pass.Activated:Fire()
 assert(#sent==calls,"ID 0 never opens a paid purchase")
 state({FreeRerolls=2,PassOwned=true,ReviveExpiresIn=120,ReviveAvailable=true})
 local reroll=textContaining("REROLL MIỄN PHÍ  ·  2","TextButton")
 assert(reroll and reroll.Visible)
 reroll.Activated:Fire()
 assert(sent[#sent].Action=="Reroll")
 input.InputBegan:Fire({KeyCode=enum.KeyCode.F},false)
 assert(sent[#sent].Action=="Attack","F requests server-validated attack")
 calls=#sent
 input.InputBegan:Fire({KeyCode=enum.KeyCode.F},true)
 assert(#sent==calls,"Processed input is ignored")
 event.OnClientEvent:Fire("Drop",{Id="late-join",Position=vector(800,12,700),LandingAt=clock+180,Status="Incoming"})
 local marker=workspace:FindFirstChild("DropBeacon_late-join")
 assert(marker,"Incoming drop position survives streamed-out geometry")
 runService.RenderStepped:Fire()
 assert(textContaining("✦ THÍNH  3:00"),"Announcement countdown uses server clock")
 clock+=181
 event.OnClientEvent:Fire("Drop",{Id="late-join",Position=vector(800,12,700),LandingAt=clock-1,Status="Landed"})
 runService.RenderStepped:Fire()
 assert(textContaining("✦ THÍNH ĐÃ HẠ"))
 event.OnClientEvent:Fire("Drop",{Id="late-join",Status="Claimed"})
 assert(marker.Destroyed,"Claim removes map/world markers")
 event.OnClientEvent:Fire("TeleportMenu",{SourceId="meadow",Destinations={{Id="snow",Name="TEST SNOW",Cost=250}}})
 local tele=textContaining("TEST SNOW","TextButton")
 assert(tele)
 tele.Activated:Fire()
 assert(sent[#sent].Action=="Teleport" and sent[#sent].Value=="snow","Teleport menu uses server destination id")
 event.OnClientEvent:Fire("Food",{Gain=0.5,Coins=4,Position=vector(2,12,5)})
 event.OnClientEvent:Fire("Mutation","Awakened")
 assert(lighting:FindFirstChild("WildsBloom"),"Rojo gets lighting presets too")
 print("PASS: client HUD lifecycle, exact hunger, form skins, disabled commerce, input actions, live drop markers, teleport menu and cosmetic event smoke tests")
end
