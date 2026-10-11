-- Run the real timed-buff service with a controlled clock and server signals.
return function(source)
 local function signal()
  local handlers={}
  local event={}
  function event:Connect(callback)
   local connection={Connected=true,Callback=callback}
   function connection:Disconnect() self.Connected=false end
   table.insert(handlers,connection)
   return connection
  end
  function event:Fire(...)
   for _,connection in ipairs(table.clone(handlers)) do
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
 local now=0
 local heartbeat=signal()
 local players={PlayerRemoving=signal()}
 local configRef={}
 local config={Buffs={Duration=60,SpeedMultiplier=1.5,HuntMin=2,HuntMax=4,GiantScale=5}}
 local game={ReplicatedStorage={Shared={Config=configRef}}}
 function game:GetService(name)
  if name=="Players" then return players end
  if name=="RunService" then return {Heartbeat=heartbeat} end
  error("Unexpected service "..name)
 end
 local rolls=0
 local environment=setmetatable({
  game=game,
  workspace={GetServerTimeNow=function() return now+10000 end},
  os={clock=function() return now end},
  require=function(ref) assert(ref==configRef); return config end,
  Random={new=function() return {NextInteger=function(_,minimum,maximum)
   assert(minimum==2 and maximum==4)
   rolls+=1
   return 2+(rolls-1)%3
  end} end},
 },{__index=getfenv()})
 local chunk,err=loadstring(source,"Buffs"); assert(chunk,err); setfenv(chunk,environment)
 local buffs=chunk()
 local player={Parent=players,Name="One",Character={Alive=true}}
 local other={Parent=players,Name="Two",Character={Alive=true}}
 local changes={}
 local function onChanged(target)
  changes[target]=(changes[target] or 0)+1
  -- Reading state during notification must not re-enter the expiry callback.
  buffs.GetState(target)
  buffs.GetModifiers(target)
 end
 buffs.Start({OnChanged=onChanged})
 assert(heartbeat:Count()==1 and players.PlayerRemoving:Count()==1)
 assert(buffs.Apply(player,"UntrustedBuff")==nil and next(buffs.GetState(player))==nil)
 assert(buffs.Apply({Parent=nil},"Speed")==nil,"A departed player received a potion")
 local speed=buffs.Apply(player,"Speed")
 local hunt=buffs.Apply(player,"Hunt")
 local giant=buffs.Apply(player,"Giant")
 assert(speed.Remaining==60 and speed.ExpiresAt==10060 and speed.Multiplier==1.5)
 assert(hunt.Tiers==2 and giant.Scale==5)
 assert(changes[player]==3)
 local modifiers=buffs.GetModifiers(player)
 assert(modifiers.Speed==1.5 and modifiers.Scale==5 and modifiers.HuntBonus==2,"Distinct buffs cannot coexist")
 local sent=buffs.GetState(player); sent.Giant.Scale=999
 assert(buffs.GetModifiers(player).Scale==5,"Client snapshot aliases authoritative state")
 now=30
 buffs.Apply(player,"Speed")
 assert(buffs.GetState(player).Speed.ExpiresAt==10090 and buffs.GetState(player).Speed.Remaining==60)
 assert(buffs.GetModifiers(player).Speed==1.5,"Refreshing a potion stacks its multiplier")
 assert(changes[player]==4)
 player.Character.Alive=false
 assert(buffs.GetModifiers(player).Scale==5,"Dying cleared the remaining potion duration")
 now=60
 assert(not buffs.GetState(player).Giant and not buffs.GetState(player).Hunt,"Expired buffs remained claimable between ticks")
 heartbeat:Fire(.11)
 assert(changes[player]==5,"Same-tick expirations should cause one character rebuild")
 assert(buffs.GetModifiers(player).Speed==1.5 and buffs.GetModifiers(player).Scale==1 and buffs.GetModifiers(player).HuntBonus==0)
 heartbeat:Fire(2)
 assert(changes[player]==5,"Expired potion repeatedly notified the character")
 player.Character={Alive=true}
 assert(buffs.GetState(player).Speed.Remaining==30,"Respawn reset the potion timer")
 now=90
 heartbeat:Fire(.11)
 assert(changes[player]==6 and next(buffs.GetState(player))==nil)
 assert(buffs.GetModifiers(player).Speed==1)
 buffs.Apply(player,"Hunt")
 assert(buffs.GetState(player).Hunt.Tiers==3)
 buffs.Apply(player,"Hunt")
 assert(buffs.GetState(player).Hunt.Tiers==4 and buffs.GetState(player).Hunt.Remaining==60)
 buffs.Apply(other,"Giant")
 local beforeLeave=changes[player]
 players.PlayerRemoving:Fire(player); player.Parent=nil
 assert(next(buffs.GetState(player))==nil,"Leaving leaked an active potion")
 assert(buffs.GetModifiers(other).Scale==5,"Leaving removed another player's potion")
 buffs.Start({OnChanged=onChanged})
 assert(heartbeat:Count()==1 and players.PlayerRemoving:Count()==1,"Starting twice leaked service subscriptions")
 now=150
 heartbeat:Fire(.11)
 assert(changes[player]==beforeLeave and changes[other]==2,"Removal or independent expiry fired incorrect notifications")
 assert(next(buffs.GetState(other))==nil)
 print("Buff service passed: authoritative 60s expiry, independent stacking, refresh, 2–4 hunt tiers, death/respawn persistence, snapshot isolation and player cleanup")
end
