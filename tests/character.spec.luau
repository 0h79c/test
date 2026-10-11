-- Execute the actual morph and model modules. CFrame rotation/physics are not
-- simulated here; these tests cover lifecycle, collision policy and effects.
return function(configSource, modelSource, characterSource)
 local function signal()
  local handlers = {}
  local event = {}
  function event:Connect(callback)
   local connection = {Connected=true, Callback=callback}
   function connection:Disconnect() self.Connected=false end
   table.insert(handlers,connection)
   return connection
  end
  function event:Fire(...)
   for _, connection in ipairs(table.clone(handlers)) do
    if connection.Connected then connection.Callback(...) end
   end
  end
  function event:Count()
   local n=0
   for _,connection in ipairs(handlers) do if connection.Connected then n+=1 end end
   return n
  end
  return event
 end
 local vectorMeta = {}
 local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta) end
 vectorMeta.__index = function(v,k)
  if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 end
 vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vectorMeta.__mul=function(a,b)
  if type(a)=="number" then a,b=b,a end
  if type(b)=="number" then return vector(a.X*b,a.Y*b,a.Z*b) end
  return vector(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
 end
 local frameMeta = {}
 local function frame(x,y,z)
  if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end
  return setmetatable({Position=vector(x,y,z)},frameMeta)
 end
 frameMeta.__mul=function(a,b) return frame(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z) end
 frameMeta.__index={ToObjectSpace=function(a,b)
  return frame(b.Position.X-a.Position.X,b.Position.Y-a.Position.Y,b.Position.Z-a.Position.Z)
 end}
 local colorMeta = {}
 local function color(r,g,b) return setmetatable({R=r or 0,G=g or 0,B=b or 0},colorMeta) end
 colorMeta.__index={Lerp=function(a,b,t) return color(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t) end}
 local methods,instanceMeta={},{}
 local makeInstance
 instanceMeta.__index=function(obj,key)
  if methods[key] then return methods[key] end
  if obj._p[key]~=nil then return obj._p[key] end
  for _,child in ipairs(obj._children) do if child.Name==key then return child end end
 end
 instanceMeta.__newindex=function(obj,key,value)
  if key=="Parent" then
   local old=obj._p.Parent
   if old then
    local index=table.find(old._children,obj)
    if index then table.remove(old._children,index) end
   end
   obj._p.Parent=value
   if value then
    table.insert(value._children,obj)
    local ancestor=value
    while ancestor do
     ancestor.DescendantAdded:Fire(obj)
     for _,descendant in ipairs(obj:GetDescendants()) do ancestor.DescendantAdded:Fire(descendant) end
     ancestor=ancestor.Parent
    end
   end
   obj.AncestryChanged:Fire(obj,value)
  else
   obj._p[key]=value
  end
 end
 makeInstance=function(className)
  local obj=setmetatable({_p={ClassName=className,Name=className},_children={},_attrs={}},instanceMeta)
  obj.DescendantAdded=signal(); obj.AncestryChanged=signal()
  if className=="Part" or className=="WedgePart" then
   obj.Size=vector(2,2,2); obj.CFrame=frame(); obj.Color=color(); obj.Anchored=false
   obj.CanCollide=true; obj.CanTouch=true; obj.CanQuery=true; obj.Transparency=0
   obj.AssemblyLinearVelocity=vector(); obj.AssemblyMass=10
  elseif className=="Humanoid" then
   obj.Health=100; obj.RigType="R15"; obj.FloorMaterial="Grass"; obj.State="Running"
  elseif className=="ParticleEmitter" then obj.Enabled=true end
  return obj
 end
 function methods:IsA(className)
  return self.ClassName==className or (className=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart"))
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
 function methods:FindFirstChild(name,recursive)
  for _,child in ipairs(self._children) do if child.Name==name then return child end end
  if recursive then for _,child in ipairs(self._children) do
   local found=child:FindFirstChild(name,true); if found then return found end
  end end
 end
 function methods:FindFirstChildOfClass(className)
  for _,child in ipairs(self._children) do if child.ClassName==className then return child end end
 end
 function methods:SetAttribute(name,value) self._attrs[name]=value end
 function methods:GetAttribute(name) return self._attrs[name] end
 function methods:Destroy()
  self.Parent=nil
  for _,child in ipairs(self:GetChildren()) do child:Destroy() end
 end
 function methods:ScaleTo(scale)
  local ratio=scale/(self._p.Scale or 1)
  self.Scale=scale
  for _,part in ipairs(self:GetDescendants()) do if part:IsA("BasePart") then
   part.Size=part.Size*ratio
   local p=part.CFrame.Position*ratio
   part.CFrame=frame(p.X,p.Y,p.Z)
  end end
 end
 function methods:GetScale() return self.Scale or 1 end
 function methods:PivotTo(target)
  local current=self.PrimaryPart and self.PrimaryPart.CFrame or frame()
  local delta=target.Position-current.Position
  for _,part in ipairs(self:GetDescendants()) do if part:IsA("BasePart") then
   local p=part.CFrame.Position+delta; part.CFrame=frame(p.X,p.Y,p.Z)
  end end
 end
 function methods:GetExtentsSize()
  local low,high=math.huge,-math.huge
  for _,part in ipairs(self:GetDescendants()) do if part:IsA("BasePart") then
   low=math.min(low,part.CFrame.Position.Y-part.Size.Y/2)
   high=math.max(high,part.CFrame.Position.Y+part.Size.Y/2)
  end end
  return vector(10,high-low,10)
 end
 function methods:GetState() return self.State end

 local storage=makeInstance("Folder")
 local shared=makeInstance("Folder"); shared.Name="Shared"; shared.Parent=storage
 local configRef=makeInstance("ModuleScript"); configRef.Name="Config"; configRef.Parent=shared
 local modelsRef=makeInstance("ModuleScript"); modelsRef.Name="AnimalModels"; modelsRef.Parent=shared
 local heartbeat=signal()
 local groups,collisionPairs={},{}
 local physics={}
 function physics:IsCollisionGroupRegistered(name) return groups[name]~=nil end
 function physics:RegisterCollisionGroup(name) groups[name]=true end
 function physics:CollisionGroupSetCollidable(a,b,value) collisionPairs[a..":"..b]=value end
 local workspace=makeInstance("Folder"); workspace.Gravity=196.2
 local game={ReplicatedStorage=storage}
 function game:GetService(name)
  if name=="ReplicatedStorage" then return storage
  elseif name=="PhysicsService" then return physics
  elseif name=="RunService" then return {Heartbeat=heartbeat} end
  error("Unexpected service "..name)
 end
 local enum={
  HumanoidRigType={R6="R6",R15="R15"},
  HumanoidDisplayDistanceType={None="None"},
  HumanoidStateType={Freefall="Freefall"},
  Material={Air="Air"},
  PartType={},ActuatorRelativeTo={World="World"},
  Font={GothamBold="GothamBold"},HighlightDepthMode={Occluded="Occluded"},
 }
 for _,name in ipairs({"SmoothPlastic","Neon","Metal"}) do enum.Material[name]=name end
 for _,name in ipairs({"Ball","Block"}) do enum.PartType[name]=name end
 local environment=setmetatable({
  game=game,workspace=workspace,Instance={new=makeInstance},Enum=enum,
  Vector3={new=vector,zero=vector()},Vector2={new=function(x,y) return {X=x,Y=y} end},
  CFrame={new=frame,Angles=function() return frame() end,identity=frame()},
  Color3={new=color,fromRGB=function(r,g,b) return color(r/255,g/255,b/255) end,
   fromHSV=function(h,s,v) return color(v,h,s) end},
  ColorSequence={new=function(v) return v end},NumberRange={new=function(...) return {...} end},
  NumberSequence={new=function(v) return v end},NumberSequenceKeypoint={new=function(...) return {...} end},
  PhysicalProperties={new=function(...) return {...} end},
  UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},
 },{__index=getfenv()})
 local function load(source,name)
  local chunk,err=loadstring(source,name); assert(chunk,err)
  setfenv(chunk,environment); return chunk()
 end
 local config=load(configSource,"Config")
 local models=load(modelSource,"AnimalModels")
 environment.require=function(ref)
  if ref==configRef then return config elseif ref==modelsRef then return models end
  error("Unexpected require")
 end
 local characterModule=load(characterSource,"Character")
 local library=characterModule.Initialize()
 assert(#library:GetChildren()==15,"Preview library must contain all species")
 assert(collisionPairs["EvolutionAvatar:Default"]==false,"Invisible avatar collision not isolated")

 local function makePlayer(rig)
  local character=makeInstance("Model"); character.Parent=workspace
  local root=makeInstance("Part"); root.Name="HumanoidRootPart"; root.Size=vector(2,2,1); root.CFrame=frame(0,16,0); root.Parent=character
  local torso=makeInstance("Part"); torso.Name="Torso"; torso.Parent=character
  local leg=makeInstance("Part"); leg.Name="Left Leg"; leg.Size=vector(1,2,1); leg.Parent=character
  local humanoid=makeInstance("Humanoid"); humanoid.RigType=rig; humanoid.Parent=character
  return {Character=character,UserId=42},humanoid,root,torso
 end
 local function countDescendants(character,className)
  local count=0
  for _,obj in ipairs(character:GetDescendants()) do if obj:IsA(className) then count+=1 end end
  return count
 end
 for _,rig in ipairs({"R6","R15"}) do
  local player,humanoid,root,torso=makePlayer(rig)
  local character=player.Character
  for form=1,15 do
   for _,mutation in ipairs({"Normal","Giant","Tiny","Giant","Normal","Awakened","Radioactive","Normal"}) do
    assert(characterModule.Apply(player,{Form=form,Mutations={[tostring(form)]=mutation}}))
    assert(character.Scale==nil,"Morph scaled the avatar rig cumulatively")
    assert(character.AnimalVisual.Scale==config.Mutation(mutation).Scale)
    local collider=character.AnimalCollider
    assert(collider.CanCollide and collider.CanTouch and collider.CollisionGroup=="Default")
    assert(collider.Size.X<=3.8 and collider.Size.Y<=4.1 and collider.Size.Z<=4.4,"Collider is too large for travel")
    assert(math.abs(collider.CFrame.Position.Y-collider.Size.Y/2-(root.CFrame.Position.Y-3))<1e-8,"Collider floor offset wrong")
    assert(torso.Transparency==1 and not torso.CanCollide and torso.CollisionGroup=="EvolutionAvatar","Default avatar still visible or collidable")
    assert(root.CollisionGroup=="Default" and not root.CanCollide,"Humanoid root cannot sense the map floor")
    local colliders=0
    for _,child in ipairs(character:GetChildren()) do if child.Name=="AnimalCollider" then colliders+=1 end end
    assert(colliders==1,"Morph stacked colliders")
    assert(heartbeat:Count()==1,"Morph stacked per-character update connections")
    assert(character.DescendantAdded:Count()==1,"Morph stacked avatar appearance hooks")
    if mutation=="Normal" and form~=14 then assert(countDescendants(character,"ParticleEmitter")==0,"Previous aura leaked after reroll") end
    local variant = character.AnimalVisual:GetAttribute("Mutation")
    assert(variant==mutation,"Morph did not apply requested mutation skin")
    local extra=0
    local neon=0
    for _,part in ipairs(character.AnimalVisual:GetChildren()) do
     if part:IsA("BasePart") then
      if part:GetAttribute("MutationGeometry") then extra+=1 end
      if part.Material=="Neon" then neon+=1 end
      if part.Name~="Root" then
       assert(part.AnimalJoint and part.AnimalJoint.C1,"Animal geometry has no common hinge")
      end
     end
    end
    if mutation=="Normal" then assert(extra==0,"Mutation anatomy leaked after reroll")
    else assert(extra>0,"Mutation did not add visual anatomy") end
    if mutation=="Radioactive" then assert(neon>0,"Biolume crystals are missing") end
    if mutation~="Normal" or form==14 then
     local enabled=0
     for _,obj in ipairs(character:GetDescendants()) do
      if obj:IsA("ParticleEmitter") and obj.Enabled then enabled+=1 end
     end
     assert(enabled>0,"Avatar hiding disabled animal effects")
    end
   end
  end
  local accessory=makeInstance("Accessory"); accessory.Parent=character
  local handle=makeInstance("Part"); handle.Name="Handle"; handle.Parent=accessory
  assert(handle.Transparency==1 and not handle.CanCollide and handle.CollisionGroup=="EvolutionAvatar","Late accessory showed default avatar")
  characterModule.Apply(player,{Form=13,Mutations={['13']="Normal"}})
  humanoid.State="Running"; root.AssemblyLinearVelocity=vector(0,0,0); heartbeat:Fire(.11)
  assert(root.GlideForce.Force.Y==0,"Grounded animal is levitating")
  humanoid.State="Freefall"; root.AssemblyLinearVelocity=vector(0,10,0); heartbeat:Fire(.11)
  assert(root.GlideForce.Force.Y==0,"Glide boosts rising jumps")
  root.AssemblyLinearVelocity=vector(0,-10,0); heartbeat:Fire(.11)
  assert(root.GlideForce.Force.Y>0,"Winged form cannot glide while falling")
  characterModule.Cleanup(character)
  assert(heartbeat:Count()==0 and character.DescendantAdded:Count()==0,"Character cleanup leaked callbacks")
  character:Destroy()
 end
 -- Viewport skins are independent of Character.Apply and can reroll without
 -- stacking geometry or permanently tinting the original authored colors.
 for form=1,15 do
  local preview=models.Create(form)
  local base=preview:GetChildren()[2]
  local original=base.Color
  models.ApplySkin(preview,form,"Awakened")
  local awakenedCount=#preview:GetChildren()
  models.ApplySkin(preview,form,"Awakened")
  assert(#preview:GetChildren()==awakenedCount,"Preview reroll stacked appendages")
  models.ApplySkin(preview,form,"Normal")
  assert(#preview:GetChildren()==#models.Definitions[form].Parts+1,"Normal preview retained mutation parts")
  assert(base.Color==original,"Normal preview did not restore authored palette")
  preview:Destroy()
 end
 print("Character lifecycle passed: 15 species × 8 mutation changes × R6/R15; one collider, hidden avatar, clean effects, falling-only glide")
end
