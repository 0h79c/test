-- Mathematically exact CFrame/vector mock validates compound hinge transforms.
-- Roblox rendering and its Humanoid physics still need an actual Studio pass.
return function(modelSource, clientSource, configSource)
 local vm={}
 local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm) end
 vm.__index=function(a,key) if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
 vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vm.__mul=function(a,b)
  if type(a)=="number" then a,b=b,a end
  if type(b)=="number" then return v(a.X*b,a.Y*b,a.Z*b) end
  return v(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
 end
 local fm={}
 local function cf(x,y,z,r)
  if type(x)=="table" then x,y,z=x.X,x.Y,x.Z end
  return setmetatable({Position=v(x,y,z),R=r or {1,0,0,0,1,0,0,0,1}},fm)
 end
 local function rotate(r,p) return v(r[1]*p.X+r[2]*p.Y+r[3]*p.Z,r[4]*p.X+r[5]*p.Y+r[6]*p.Z,r[7]*p.X+r[8]*p.Y+r[9]*p.Z) end
 fm.__mul=function(a,b)
  if b.X then return a.Position+rotate(a.R,b) end
  local r={}
  for row=0,2 do for col=0,2 do
   local sum=0
   for k=0,2 do sum+=a.R[row*3+k+1]*b.R[k*3+col+1] end
   r[row*3+col+1]=sum
  end end
  local p=a.Position+rotate(a.R,b.Position)
  return cf(p.X,p.Y,p.Z,r)
 end
 fm.__index={ToObjectSpace=function(a,b)
  local r=a.R
  local inverse={r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}
  local p=rotate(inverse,a.Position*-1)
  return cf(p.X,p.Y,p.Z,inverse)*b
 end}
 local function angles(x,y,z)
  local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
  return cf(0,0,0,{cy*cz,-cy*sz,sy,sx*sy*cz+cx*sz,-sx*sy*sz+cx*cz,-sx*cy,-cx*sy*cz+sx*sz,cx*sy*sz+sx*cz,cx*cy})
 end
 local env=setmetatable({Vector3={new=v},CFrame={new=cf,Angles=angles},Color3={fromRGB=function(...) return {...} end}},{__index=getfenv()})
 local module=assert(loadstring(modelSource));setfenv(module,env)
 local models=module()
 local config=assert(loadstring(configSource))()
 local function close(a,b,label) assert((a-b).Magnitude<1e-7,label) end
 -- Property assignments are observed immediately, before Rig returns. A
 -- final-state assertion misses the transient anchored joint that can freeze
 -- a live character while its new appearance replicates to the physics owner.
 for _,definition in ipairs(models.Definitions) do
  for _,anchoredRoot in ipairs({false,true}) do
   local controlRoot={Anchored=anchoredRoot,CanCollide=true,Massless=false,CFrame=cf(9,17,4)*angles(0,.65,0)}
   function controlRoot:IsA(kind) return kind=="BasePart" end
   local function part(frame,attrs)
    return {Anchored=true,CanCollide=true,CanTouch=true,CanQuery=true,Massless=false,CFrame=frame,
     IsA=function(_,kind) return kind=="BasePart" end,
     GetAttribute=function(_,key) return attrs[key] end}
   end
   local origin=controlRoot.CFrame*cf(0,-3,0)
   local visualRoot=part(origin,{})
   local decorations={visualRoot}
   for _,description in ipairs(definition.Parts) do
    local r=description.rotation
    local transform=origin*cf(v(table.unpack(description.position))*1.5)*angles(math.rad(r[1]),math.rad(r[2]),math.rad(r[3]))
    table.insert(decorations,part(transform,{
     Motion=description.motion,Phase=description.phase,
     MotionPivot=description.pivot and v(table.unpack(description.pivot)),
    }))
   end
   local descendants=table.clone(decorations)
   table.insert(descendants,controlRoot)
   table.insert(descendants,{IsA=function() return false end})
   local activated=0
   env.Instance={new=function(kind)
    assert(kind=="Motor6D")
    local properties={}
    return setmetatable({}, {__index=properties,__newindex=function(_,key,value)
     if key=="Part0" or key=="Part1" or key=="Parent" then
      assert(properties.C0 and properties.C1,"A motor was connected before its authored offsets were ready")
      for _,visualPart in ipairs(decorations) do
       assert(not visualPart.Anchored,"An anchored decoration was present while joining the live assembly")
       assert(not visualPart.CanCollide and not visualPart.CanTouch and not visualPart.CanQuery and visualPart.Massless,
        "A decoration could affect physics while the live assembly was connected")
      end
     end
     if key=="Parent" then
      assert(properties.Part0==controlRoot and properties.Part1==value,"Rig joined the wrong assembly")
      activated+=1
     end
     properties[key]=value
    end})
   end}
   local rigged=models.Rig({PrimaryPart=visualRoot,GetScale=function() return 1.5 end,GetDescendants=function() return descendants end},controlRoot)
   assert(activated==#decorations and #rigged==#decorations,"Rig skipped decorative parts")
   assert(controlRoot.Anchored==anchoredRoot and controlRoot.CanCollide and not controlRoot.Massless,"Rig altered the player or NPC control root")
   for _,state in ipairs(rigged) do
    local joint=state.Joint
    local a,b=controlRoot.CFrame*joint.C0,joint.Part1.CFrame*joint.C1
    close(a.Position,b.Position,"Rig changed the authored hinge position")
    for index,value in ipairs(a.R) do assert(math.abs(value-b.R[index])<1e-7,"Rig changed the authored hinge orientation") end
   end
  end
 end
 for form,definition in ipairs(models.Definitions) do
  local rate=models.GaitRate(form,30,1)
  assert(math.abs(models.GaitRate(form,60,1)-rate*2)<1e-9,"Cadence must rise with actual speed")
  assert(models.GaitRate(form,100,1)>14,"High speed cadence was capped")
  assert(math.abs(models.GaitRate(form,30,5)-rate/5)<1e-9,"Giant strides ignore actual size")
  local states={}
  for _,p in ipairs(definition.Parts) do
   local attrs={Motion=p.motion~="" and p.motion or nil,Phase=p.phase,MotionPivot=p.pivot and v(table.unpack(p.pivot)),BodyPivot=v(table.unpack(p.body_pivot)),KneePivot=p.knee and v(table.unpack(p.knee)),LegLower=p.leg_lower,LegSide=p.leg_side,LegFront=p.leg_front}
   local part={GetAttribute=function(_,key) return attrs[key] end}
   local state=models.DescribeJoint({Part1=part,Parent=true})
   table.insert(states,state)
  end
  for sample=1,30 do
   local phase=sample*.21
   models.Animate(states,3,phase,1,false,1,form,30)
   for _,state in ipairs(states) do
    for _,number in ipairs(state.Joint.Transform.R) do assert(number==number and math.abs(number)<=1.001,"Invalid gait matrix") end
    if state.Knee and state.Lower then
     local upper
     for _,candidate in ipairs(states) do
      if candidate.Knee and not candidate.Lower and candidate.Front==state.Front and candidate.Side==state.Side then upper=candidate;break end
     end
     assert(upper,"Missing matching upper leg")
     local upperEnd=cf(upper.Pivot)*upper.Joint.Transform*(upper.Knee-upper.Pivot)
     local lowerStart=cf(state.Pivot)*state.Joint.Transform*(state.Knee-state.Pivot)
     close(upperEnd,lowerStart,"Articulated knee separated during running: "..definition.Name)
    end
   end
  end
 end
 -- The client must use real anchored NPC displacement, including idle and
 -- blocked states, and smoothly respond to player acceleration and stops.
 local clock=0
 local tick
 local snapshots={}
 local wrapper=setmetatable({Animate=function(_,time,phase,blend,falling,scale,form,speed)
  snapshots[form]={Time=time,Phase=phase,Blend=blend,Speed=speed}
 end},{__index=models})
 local function signal() return {Connect=function(_,callback) return {Disconnect=function() end} end} end
 local root={Position=v(),AssemblyLinearVelocity=v()}
 local playerRoot={Position=v(),AssemblyLinearVelocity=v(20,0,0)}
 local part={GetAttribute=function(_,name) return name=="Motion" and "Body" or nil end}
 local joint={Name="AnimalJoint",Part1=part,IsA=function(_,kind) return kind=="Motor6D" end}
 local visual={GetDescendants=function() return {joint} end}
 local function makeCharacter(r,form,npc)
  local hum={FloorMaterial="Ground",Health=100,GetState=function() return "Running" end}
  return {Parent=true,PrimaryPart=r,
   GetAttribute=function(_,name) return ({Form=form,VisualScale=1,IsNPC=npc,Moving=true,MoveSpeed=100})[name] end,
   FindFirstChild=function(_,name) return name=="AnimalVisual" and visual or name=="HumanoidRootPart" and r or nil end,
   FindFirstChildOfClass=function(_,name) return name=="Humanoid" and hum or nil end,
   IsA=function(_,name) return name=="Model" end}
 end
 local npc=makeCharacter(root,3,true)
 local character=makeCharacter(playerRoot,7,false)
 local players={PlayerRemoving=signal(),GetPlayers=function() return {{Character=character}} end}
 local runService={PreSimulation={Connect=function(_,callback) tick=callback end}}
 local replicated={Shared={AnimalModels="Models",Config="Config"}}
 local clientEnv=setmetatable({
  Vector3={new=v},os={clock=function() return clock end},Enum={Material={Air="Air"},HumanoidStateType={Freefall="Freefall"}},
  game={ReplicatedStorage=replicated,GetService=function(_,name) return name=="Players" and players or runService end},
  require=function(name) return name=="Models" and wrapper or config end,
  workspace={CurrentCamera={CFrame=cf()},FindFirstChild=function(_,name) return name=="Wildlife" and {GetChildren=function() return {npc} end} end},
 },{__index=getfenv()})
 local client=assert(loadstring(clientSource));setfenv(client,clientEnv);client()
 for _=1,120 do clock+=1/60;root.Position+=v(.1,0,0);tick(1/60) end
 assert(math.abs(snapshots[3].Speed-6)<.001,"NPC cadence used configured speed instead of displacement")
 assert(math.abs(snapshots[7].Speed-20)<.001,"Player speed sampling failed")
 local before=snapshots[7].Phase
 playerRoot.AssemblyLinearVelocity=v(80,0,0)
 clock+=1/60;tick(1/60)
 assert(snapshots[7].Speed>20 and snapshots[7].Speed<80,"Acceleration must be smoothly blended")
 for _=1,120 do clock+=1/60;tick(1/60) end
 assert(snapshots[3].Speed<.001 and snapshots[3].Blend<.001,"Blocked anchored AI kept running")
 assert(snapshots[7].Phase-before>models.GaitRate(7,40,1)*2,"Speed boost did not accelerate animation")
 root.Position=v(200,0,0);clock+=1/60;tick(1/60)
 assert(snapshots[3].Speed<.001,"Teleport produced a burst of running animation")
 print("PASS: safe live rig attachment, all 15 gaits, connected articulated knees, uncapped speed cadence, giant strides, anchored NPC motion and smooth transitions")
end
