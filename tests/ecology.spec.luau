-- Assertions cover contested claims, reach, dead/loading players, prey size,
-- NPC claims and delayed respawn cancellation. Rendering is intentionally mocked.
return function(source, foodSource)
 local function signal()
  local handlers = {}
  local event = {}
  function event:Connect(callback)
   local c = {Connected=true, Callback=callback}
   function c:Disconnect() self.Connected=false end
   table.insert(handlers, c)
   return c
  end
  function event:Fire(...)
   for _, c in ipairs(table.clone(handlers)) do if c.Connected then c.Callback(...) end end
  end
  return event
 end
 local vectorMeta = {}
 local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta) end
 vectorMeta.__index = function(v,k)
  if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
  if k == "Unit" then return v / v.Magnitude end
 end
 vectorMeta.__add = function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
 vectorMeta.__sub = function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
 vectorMeta.__mul = function(a,b)
  if type(a) == "number" then a,b=b,a end
  return vector(a.X*b,a.Y*b,a.Z*b)
 end
 vectorMeta.__div = function(a,b) return vector(a.X/b,a.Y/b,a.Z/b) end
 local frameMeta = {}
 local function frame(x,y,z)
  local pos = type(x) == "table" and x or vector(x,y,z)
  return setmetatable({Position=pos},frameMeta)
 end
 frameMeta.__mul = function(a,b) return frame(a.Position+b.Position) end
 local methods, meta = {}, {}
 local function make(class)
  return setmetatable({_properties={ClassName=class,Name=class},_children={},_attrs={},
   Touched=signal(),Triggered=signal()},meta)
 end
 meta.__index = function(o,k)
  if methods[k] then return methods[k] end
  if k == "Position" then return o._properties.CFrame and o._properties.CFrame.Position or vector() end
  if o._properties[k] ~= nil then return o._properties[k] end
  for _, c in ipairs(o._children) do if c.Name == k then return c end end
 end
 meta.__newindex = function(o,k,v)
  if k == "Parent" then
   local old=o._properties.Parent
   if old then local index=table.find(old._children,o); if index then table.remove(old._children,index) end end
   o._properties.Parent=v
   if v then table.insert(v._children,o) end
  else o._properties[k]=v end
 end
 function methods:IsA(class) return self.ClassName==class end
 function methods:FindFirstChild(name)
  for _, c in ipairs(self._children) do if c.Name==name then return c end end
 end
 function methods:FindFirstChildOfClass(class)
  for _, c in ipairs(self._children) do if c.ClassName==class then return c end end
 end
 function methods:FindFirstAncestorOfClass(class)
  local ancestor=self.Parent
  while ancestor do if ancestor:IsA(class) then return ancestor end; ancestor=ancestor.Parent end
 end
 function methods:Destroy()
  for _, child in ipairs(table.clone(self._children)) do child:Destroy() end
  self.Parent=nil
 end
 function methods:ScaleTo(_) end
 function methods:PivotTo(cf)
  local before=self.PrimaryPart and self.PrimaryPart.Position or vector()
  local shift=cf.Position-before
  local function move(o)
   if o:IsA("Part") and o.CFrame then o.CFrame=frame(o.Position+shift) end
   for _, c in ipairs(o._children) do move(c) end
  end
  move(self)
 end
 function methods:SetAttribute(k,v) self._attrs[k]=v end
 function methods:GetAttribute(k) return self._attrs[k] end
 local workspace=make("Workspace")
 function workspace:Raycast(_,_,_) return self.Blocked and {Instance={CanCollide=true}} or nil end
 local players={List={}}
 function players:GetPlayers() return self.List end
 function players:GetPlayerFromCharacter(character)
  for _, p in ipairs(self.List) do if p.Character==character then return p end end
 end
 local heartbeat=signal()
 local storage={Shared={Config="Config",FoodModels="FoodModels",AnimalModels="AnimalModels"}}
 local config={Foods={{Id="berry",Name="Mọng",Hunger=.5,Coins=4,Weight=1}},
  Species={},FoodCount=2,NPCCount=1,MutationFoodSpawnChance=.012,AISpeedMultiplier=.5,MetersPerStud=.28,
  FoodRespawn={AdditionalPlayerRate=.25,PerAIRate=.1,PassRadiusMeters=50,PassMultiplier=2},
  BuffSpawnChance=.03,BuffFoodLifetime=300,BuffFoods={
   {Id="speed_tonic",Buff="Speed",Duration=60,Hunger=0,Coins=0},
   {Id="hunting_tonic",Buff="Hunt",Duration=60,Hunger=0,Coins=0},
   {Id="giant_tonic",Buff="Giant",Duration=60,Hunger=0,Coins=0},
  }}
 for i=1,15 do config.Species[i]={Name="Species"..i,WalkSpeed=10+i*2} end
 local foods={}
 function foods.Create(spec,parent,_)
  local model=make("Model"); model.Name=spec.Id
  local root=make("Part"); root.Name="Root"; root.CFrame=frame(0,2,0); root.Parent=model
  model.PrimaryPart=root; model.Parent=parent
  return model
 end
 local animals={Definitions={}}
 for i=1,15 do animals.Definitions[i]={Collider={2,2,3}} end
 function animals.Create(_,parent)
  local model=make("Model")
  local root=make("Part"); root.CFrame=frame(); root.Parent=model
  model.PrimaryPart=root; model.Parent=parent
  return model
 end
 function animals.Rig(_,_) return {} end
 local tweenService={}
 function tweenService:Create(root,_,goals)
  local tween={Cancelled=false}
  function tween:Play() if not self.Cancelled then root.CFrame=goals.CFrame end end
  function tween:Cancel() self.Cancelled=true end
  return tween
 end
 local random={}
 function random:NextNumber(minimum,maximum)
  if minimum then return minimum+(maximum-minimum)*.4 end
  return .8
 end
 function random:NextInteger(minimum,_) return minimum end
 local delayed={}
 local environment={
  game={GetService=function(_,name)
   return ({Players=players,ReplicatedStorage=storage,RunService={Heartbeat=heartbeat},TweenService=tweenService})[name]
  end},
  workspace=workspace,
  require=function(module) return ({Config=config,FoodModels=foods,AnimalModels=animals})[module] end,
  Instance={new=make},
  Vector3={new=vector},
  CFrame={new=frame,identity=frame(),Angles=function() return frame() end,lookAt=function(v,_) return frame(v) end},
  Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end},
  Vector2={new=function(...) return {...} end},
  ColorSequence={new=function(...) return {...} end},
  NumberRange={new=function(...) return {...} end},
  NumberSequence={new=function(...) return {...} end},
  NumberSequenceKeypoint={new=function(...) return {...} end},
  UDim2={fromScale=function(...) return {...} end,fromOffset=function(...) return {...} end},
  Enum={KeyCode={E="E",ButtonX="X"},Font={GothamMedium="font"},RaycastFilterType={Exclude="exclude"},EasingStyle={Linear="linear"},
   PartType={Block="block",Ball="ball",Cylinder="cylinder"},
   Material={SmoothPlastic="plastic",Glass="glass",Metal="metal",Wood="wood",Neon="neon"}},
  TweenInfo={new=function(...) return {...} end},
  RaycastParams={new=function() return {} end},Random={new=function(_) return random end},
  task={delay=function(seconds,callback) table.insert(delayed,{Seconds=seconds,Callback=callback}) end},
  typeof=function(value) return getmetatable(value)==meta and "Instance" or type(value) end,
 }
 setmetatable(environment,{__index=getfenv()})
 local chunk=assert(loadstring(source)); setfenv(chunk,environment)
 local ecology=chunk()
 local world={Biomes={{Id="meadow"}}, FoodSpawnPoints={
  {Position=vector(0,0,0),Biome="meadow"},{Position=vector(150,0,0),Biome="meadow"}}}
 function world.RandomPosition(_,_)
  if world.NoSpace then
   world.BlockedAttempts=(world.BlockedAttempts or 0)+1
   return nil
  end
  return vector(600,0,0)
 end
 function world.GroundPosition(v) return not world.BlockedGround and vector(v.X,0,v.Z) or nil end
 function world.BiomeAt(_) return "meadow" end
 local awarded, rewards=0,{}
 local handlers={
  OnEat=function(player,spec,sourceMetadata)
   awarded+=1; table.insert(rewards,{Player=player,Spec=spec,Source=sourceMetadata})
  end,
  GetPlayerForm=function(player) return player.Form end,
  GetPlayerSize=function(player) return player.Size end,
  GetHuntBonus=function(player) return player.HuntBonus or 0 end,
  HasPass=function(player) return player.Pass == true end,
  CanEat=function(player) return not player.Loading end,
 }
 local function player(name,form,size)
  local character=make("Model"); character.Name=name; character.Parent=workspace
  local root=make("Part"); root.Name="HumanoidRootPart"; root.CFrame=frame(); root.Parent=character
  local humanoid=make("Humanoid"); humanoid.Health=100; humanoid.Parent=character
  local p={Name=name,Form=form,Size=size,Character=character}
  table.insert(players.List,p)
  return p
 end
 local a,b=player("A",3,200),player("B",3,200)
 local function count(registry) local n=0; for _ in pairs(registry) do n+=1 end; return n end
 ecology.Start(world,handlers)
 assert(count(ecology.ActiveFoods)==2 and count(ecology.ActiveNPCs)==1,"startup uses food and wildlife budgets")
 local food,entry=next(ecology.ActiveFoods)
 a.Character.HumanoidRootPart.CFrame=frame(entry.Position+vector(9,0,0))
 assert(not ecology.TryEat(a,food),"remote cannot eat from beyond eight studs")
 a.Character.HumanoidRootPart.CFrame=frame(entry.Position)
 workspace.Blocked=true
 assert(not ecology.TryEat(a,food),"food cannot be eaten through a solid wall")
 workspace.Blocked=false
 a.Loading=true
 assert(not ecology.TryEat(a,food),"loading players cannot claim food")
 a.Loading=false; a.Character.Humanoid.Health=0
 assert(not ecology.TryEat(a,food),"dead players cannot claim food")
 a.Character.Humanoid.Health=100
 b.Character.HumanoidRootPart.CFrame=frame(entry.Position)
 assert(ecology.TryEat(a,food),"live nearby player eats")
 assert(not ecology.TryEat(b,food),"contested food grants rewards exactly once")
 assert(awarded==1 and rewards[1].Spec.Hunger==.5 and rewards[1].Spec.Coins==4,"server provides canonical rewards")
 assert(count(ecology.ActiveFoods)==1 and not food.Parent,"consumed food is removed")
 local pending=next(ecology.PendingFoods)
 assert(pending and pending.Remaining>=35 and pending.Remaining<=90 and pending.Position,
  "normal food reserves its next safe location before starting a population-scaled timer")
 local npc,npcEntry=next(ecology.ActiveNPCs)
 a.Character.HumanoidRootPart.CFrame=frame(npcEntry.Root.Position)
 a.Form=npcEntry.Form; a.Size=npcEntry.Size
 assert(not ecology.TryEat(a,npc),"equal-size wildlife is not edible")
 a.Form=npcEntry.Form+1; a.Size=1
 assert(not ecology.TryEat(a,npc),"tiny evolved players cannot swallow larger prey")
 a.Form=npcEntry.Form; a.Size=200
 assert(string.find(npcEntry.Prompt.ObjectText,"nhỏ hơn bạn",1,true),"wildlife prompt describes physical prey size")
 assert(ecology.TryEat(a,npc),"same-tier wildlife is edible when physically smaller")
 assert(not ecology.TryEat(b,npc) and awarded==2,"prey cannot grant duplicate rewards")
 assert(rewards[2].Source.Kind=="NPC" and rewards[2].Spec.Hunger==3,"prey reward is derived from its server form")
 assert(not ecology.CanEatNPC(2,2) and ecology.CanEatNPC(3,2),"forms are only a fallback when both sizes are absent")
 assert(ecology.CanEatNPC(2,2,100,50) and ecology.CanEatNPC(1,3,100,50),"physical volume permits same-tier and higher-tier smaller prey")
 assert(not ecology.CanEatNPC(3,2,50,50) and not ecology.CanEatNPC(3,2,10,50),"equal and larger prey cannot be hunted")
 assert(not ecology.CanEatNPC(3,2,100,nil) and not ecology.CanEatNPC(3,2,math.huge,50)
  and not ecology.CanEatNPC(3,2,0/0,50) and not ecology.CanEatNPC(3,2,0,50),"invalid or partial supplied sizes never permit hunting")
 assert(ecology.CanEatNPC(1,3,1,100,2) and ecology.CanEatNPC(1,5,1,100,4),
  "temporary hunting strength permits exactly the extra server-supplied tiers regardless of volume")
 assert(not ecology.CanEatNPC(1,4,1,100,2) and not ecology.CanEatNPC(1,6,1,100,4)
  and not ecology.CanEatNPC(1,3,1,100,0) and not ecology.CanEatNPC(1,3,1,100,5)
  and not ecology.CanEatNPC(1,3,1,100,2.5),"missing, expired or invalid hunting bonuses grant no extra tiers")
 assert(ecology.InEatingRange(vector(0,15,0),vector(7,0,0)),"tall forms can eat at their feet")
 assert(not ecology.InEatingRange(vector(0,19,0),vector(0,0,0)),"food too far above or below is unreachable")
 local remaining,remainingEntry=next(ecology.ActiveFoods)
 local stolen=ecology.Claim(ecology.ActiveFoods,remaining)
 assert(stolen==remainingEntry and not ecology.Claim(ecology.ActiveFoods,remaining),"NPC/player ownership is a single atomic claim")
 remaining:Destroy()
 local rare=ecology.RollFood({NextNumber=function() return .001 end},"meadow")
 assert(rare.Mutation and rare.Id=="mutation","rare roll produces mutation food")
 for i=1,3 do
  local tonic=ecology.RollFood({NextNumber=function() return .025 end,NextInteger=function() return i end},"meadow")
  assert(tonic==config.BuffFoods[i] and tonic.Duration==60 and not tonic.Mutation,
   "three tonic variants occupy the separate 3 percent bucket without granting mutations")
 end
 assert(ecology.RollFood({NextNumber=function(_,minimum) return minimum and .1 or .043 end},"meadow").Id=="berry",
  "rolls above rare fruit plus tonic thresholds remain ordinary food")
 local boosted=ecology.SpawnMutationFood(vector(700,0,0),true)
 local boostedEntry=ecology.ActiveFoods[boosted]
 a.Character.HumanoidRootPart.CFrame=frame(boostedEntry.Position)
 assert(ecology.TryEat(a,boosted) and rewards[3].Source.Boost==3 and rewards[3].Source.MutationFood,"boosted rare food carries triple weight to the mutation service")
 ecology.Stop()
 for _, job in ipairs(delayed) do job.Callback() end
 assert(count(ecology.ActiveFoods)==0 and count(ecology.ActiveNPCs)==0 and count(ecology.PendingFoods)==0,
  "stopped ecology cannot resurrect delayed food or prey")
 ecology.Start(world,handlers)
 a.Character.HumanoidRootPart.CFrame=frame(1200,3,0)
 b.Character.HumanoidRootPart.CFrame=frame(1300,3,0)
 local competitor,competitorEntry=next(ecology.ActiveNPCs)
 competitorEntry.SearchAt=math.huge
 competitorEntry.WanderAt=math.huge
 competitorEntry.Goal=competitorEntry.Root.Position+vector(100,0,0)
 local speedStart=competitorEntry.Root.Position
 heartbeat:Fire(.25)
 local expectedSpeed=config.Species[competitorEntry.Form].WalkSpeed*.5
 assert(math.abs((competitorEntry.Root.Position-speedStart).Magnitude-expectedSpeed*.25)<.0001
  and competitor:GetAttribute("MoveSpeed")==expectedSpeed and competitor:GetAttribute("NPCWalkSpeed")==expectedSpeed,
  "AI actual movement and animation speed are exactly half of its default animal speed")
 local contested,contestedEntry=next(ecology.ActiveFoods)
 competitorEntry.Root.CFrame=frame(contestedEntry.GroundPosition+vector(20,0,0))
 local before=competitorEntry.Root.Position
 world.BlockedGround=true
 heartbeat:Fire(.3)
 assert((competitorEntry.Root.Position-before).Magnitude==0,"AI never steps into unsafe terrain or water")
 world.BlockedGround=false
 competitorEntry.Root.CFrame=frame(contestedEntry.GroundPosition+vector(1,0,0))
 competitorEntry.SearchAt=0
 heartbeat:Fire(.3)
 assert(count(ecology.ActiveFoods)==1 and awarded==3,"NPC competitors consume food without granting player rewards")
 assert(not ecology.TryEat(a,contested),"a food eaten by wildlife is unavailable to players")
 local preyForm=competitorEntry.Form
 competitorEntry.Hunger=99.5
 local nextFood,nextFoodEntry=next(ecology.ActiveFoods)
 competitorEntry.Root.CFrame=frame(nextFoodEntry.GroundPosition+vector(1,0,0))
 competitorEntry.SearchAt=0
 heartbeat:Fire(.3)
 assert(competitorEntry.Form==preyForm+1,"wildlife evolves when its own hunger reaches 100 percent")
 ecology.Stop()
 ecology.Start(world,handlers)
 local tonicFood,tonicEntry=next(ecology.ActiveFoods)
 tonicEntry.Spec=config.BuffFoods[1]
 local tonicNPC,tonicNPCEntry=next(ecology.ActiveNPCs)
 tonicNPCEntry.Root.CFrame=frame(tonicEntry.GroundPosition+vector(1,0,0))
 tonicNPCEntry.SearchAt=0
 heartbeat:Fire(.3)
 assert(ecology.ActiveFoods[tonicFood] and tonicNPCEntry.Target~=tonicFood,
  "wildlife ignores a nearby player tonic when choosing food")
 tonicNPCEntry.Target=tonicFood; tonicNPCEntry.SearchAt=math.huge
 tonicNPCEntry.Root.CFrame=frame(tonicEntry.GroundPosition+vector(1,0,0))
 local tonicHunger=tonicNPCEntry.Hunger
 heartbeat:Fire(.3)
 assert(ecology.ActiveFoods[tonicFood] and not tonicNPCEntry.Target and tonicNPCEntry.Hunger==tonicHunger,
  "stale wildlife targets cannot consume player tonics or receive their effects")
 ecology.Stop()
 -- Existing timers must react immediately to server joins, deaths, pass owners
 -- entering/leaving the actual reserved spawn radius, and overlapping auras.
 ecology.Start(world,handlers)
 local rateFood,rateEntry=next(ecology.ActiveFoods)
 a.Character.HumanoidRootPart.CFrame=frame(rateEntry.Position)
 assert(ecology.TryEat(a,rateFood),"dynamic spawn fixture consumes a slot")
 local ratePending=next(ecology.PendingFoods)
 local rateNPC,rateNPCEntry=next(ecology.ActiveNPCs)
 rateNPCEntry.SearchAt=math.huge; rateNPCEntry.WanderAt=math.huge; rateNPCEntry.Goal=rateNPCEntry.Root.Position
 local function advance(expected)
  local beforeRemaining=ratePending.Remaining
  heartbeat:Fire(1)
  assert(math.abs(beforeRemaining-ratePending.Remaining-expected)<.0001,"pending food uses current population and local pass radius")
 end
 advance(1.35) -- Two humans and one live NPC.
 local c=player("C",1,10)
 advance(1.6)
 a.Pass=true; a.Character.HumanoidRootPart.CFrame=frame(ratePending.Position+vector(50/.28+.01,0,0))
 advance(1.6)
 a.Character.HumanoidRootPart.CFrame=frame(ratePending.Position+vector(50/.28-.01,0,0))
 advance(3.2)
 b.Pass=true; b.Character.HumanoidRootPart.CFrame=frame(ratePending.Position)
 advance(3.2)
 a.Character.Humanoid.Health=0; b.Character.Humanoid.Health=0
 advance(1.6)
 rateNPC:Destroy()
 advance(1.5)
 table.remove(players.List,table.find(players.List,c)); c.Character:Destroy()
 advance(1.25)
 a.Pass=false; b.Pass=false; a.Character.Humanoid.Health=100; b.Character.Humanoid.Health=100
 assert(ecology.GlobalRespawnRate(1,0)==1 and ecology.GlobalRespawnRate(5,10)==3,
  "spawn speed starts at 100 percent and adds 25 percent per extra player plus 10 percent per living AI")
 ecology.Stop()
 config.NPCCount=0
 ecology.Start(world,handlers)
 local retryFood,retryEntry=next(ecology.ActiveFoods)
 a.Character.HumanoidRootPart.CFrame=frame(retryEntry.Position)
 world.NoSpace=true; world.BlockedGround=true; world.BlockedAttempts=0
 assert(ecology.TryEat(a,retryFood),"retry fixture consumes one food slot")
 assert(world.BlockedAttempts==45,"each blocked respawn search has a bounded candidate budget")
 assert(count(ecology.ActiveFoods)==1,"blocked respawn never forces food onto unsafe fallback terrain")
 heartbeat:Fire(14)
 assert(world.BlockedAttempts==45,"blocked reservations do not retry every frame")
 heartbeat:Fire(1)
 assert(world.BlockedAttempts==90,"a temporarily blocked food slot retries after fifteen seconds")
 world.NoSpace=false; world.BlockedGround=false
 heartbeat:Fire(60)
 assert(count(ecology.ActiveFoods)==2,"food population recovers when a safe spaced location becomes available")
 ecology.Stop()
 -- Player-only tonics expire independently of accelerated spawn timers, so
 -- ignored consumables cannot gradually fill every ordinary food slot.
 local previousNextNumber=random.NextNumber
 random.NextNumber=function(self,minimum,maximum)
  if not minimum then return .025 end
  return previousNextNumber(self,minimum,maximum)
 end
 local beforeExpiryJobs=#delayed
 ecology.Start(world,handlers)
 random.NextNumber=previousNextNumber
 local consumedTonic,consumedTonicEntry=next(ecology.ActiveFoods)
 assert(consumedTonicEntry.Spec.Buff and count(ecology.ActiveFoods)==2,"expiry fixture spawns two player tonics")
 a.Character.HumanoidRootPart.CFrame=frame(consumedTonicEntry.Position)
 assert(ecology.TryEat(a,consumedTonic),"one tonic is claimed before its expiry")
 local beforeExpiryAwards=awarded
 assert(#delayed-beforeExpiryJobs==2,"each tonic schedules exactly one lifetime callback")
 for index=beforeExpiryJobs+1,#delayed do
  assert(delayed[index].Seconds==300,"unclaimed tonic lifetime is five real minutes")
  delayed[index].Callback()
  delayed[index].Callback()
 end
 assert(count(ecology.ActiveFoods)==0 and count(ecology.PendingFoods)==2 and awarded==beforeExpiryAwards,
  "expiry recycles one slot without rewards and neither repeats nor respawns already consumed tonics")
 ecology.Stop()
 for index=beforeExpiryJobs+1,#delayed do delayed[index].Callback() end
 assert(count(ecology.ActiveFoods)==0 and count(ecology.PendingFoods)==0,
  "tonic lifetime callbacks cannot restart stopped ecology")
 local foodChunk=assert(loadstring(foodSource)); setfenv(foodChunk,environment)
 local actualFoodModels=foodChunk()
 local previousColor
 for _, spec in ipairs(config.BuffFoods) do
  local bottle=actualFoodModels.Create(spec,workspace,false)
  assert(bottle:GetAttribute("BuffType")==spec.Buff and bottle:GetAttribute("BuffDuration")==60
   and bottle:GetAttribute("Hunger")==0 and bottle:GetAttribute("RareFood")==false,
   "rendered tonic metadata has its temporary effect and never advertises a mutation or fullness reward")
  assert(bottle.PotionGlass.Material=="glass" and bottle.PotionGlass.Transparency>.2
   and bottle.PotionLiquid.Material=="neon" and bottle.Cork and bottle.GoldCollar,
   "each tonic has a readable translucent bottle, luminous liquid and fitted stopper")
  assert(string.find(bottle.Root.FoodCaption._children[1].Text,"60 giây",1,true),
   "tonic caption displays its one-minute duration")
  assert(not previousColor or bottle.PotionLiquid.Color[1]~=previousColor[1],"tonic kinds use distinct liquid colors")
  previousColor=bottle.PotionLiquid.Color
  local parts,particles=0,0
  local function inspect(instance)
   if instance.ClassName=="Part" or instance.ClassName=="WedgePart" then
    parts+=1
    assert(instance.Anchored and not instance.CanCollide,"tonic decoration cannot block movement")
   elseif instance.ClassName=="ParticleEmitter" then
    particles+=1
    assert(instance.Rate<=3 and instance.Texture,"tonic uses a small explicit-texture particle budget")
   end
   for _, child in ipairs(instance._children) do inspect(child) end
  end
  inspect(bottle)
  assert(parts>=10 and parts<=25 and particles==1,"tonic silhouette is detailed within a modest rendering budget")
  bottle:Destroy()
 end
 print("Ecology: claims, hunting buffs, tonic rarity, half-speed AI, dynamic population/pass spawn rates, bounded reservations and lifecycle passed")
end
