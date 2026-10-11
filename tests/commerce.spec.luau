-- Exercise the real commerce adapter with fake Marketplace/Players services.
-- No live purchases, DataStore calls, Roblox tokens, or platform API are used.
return function(configSource, rulesSource, commerceSource)
 local function signal()
  local event={Handlers={}}
  function event:Connect(callback) table.insert(self.Handlers,callback); return {Disconnect=function() end} end
  function event:Fire(...) for _,callback in ipairs(self.Handlers) do callback(...) end end
  return event
 end
 local marketplace={PromptGamePassPurchaseFinished=signal(),Owned=false,Calls={}}
 function marketplace:GetProductInfo(id,infoType)
  table.insert(self.Calls,{"Info",id,infoType})
  return {PriceInRobux=if infoType=="Pass" then 99 else 49}
 end
 function marketplace:UserOwnsGamePassAsync(userId,id)
  table.insert(self.Calls,{"Owns",userId,id}); return self.Owned
 end
 function marketplace:PromptGamePassPurchase(player,id) table.insert(self.Calls,{"PromptPass",player.UserId,id}) end
 function marketplace:PromptProductPurchase(player,id) table.insert(self.Calls,{"PromptProduct",player.UserId,id}) end
 local players={PlayerRemoving=signal(),Members={}}
 function players:GetPlayerByUserId(id) return self.Members[id] end
 local refs={Config={},EventRules={}}
 local shared={Config=refs.Config,EventRules=refs.EventRules}
 local replicated={Shared=shared}
 local game={}
 function game:GetService(name)
  if name=="Players" then return players elseif name=="MarketplaceService" then return marketplace
  elseif name=="ReplicatedStorage" then return replicated end
  error("Unexpected service "..name)
 end
 local deferQueue={}
 local environment=setmetatable({
  game=game,Enum={ProductPurchaseDecision={PurchaseGranted="Granted",NotProcessedYet="Pending"},InfoType={GamePass="Pass",Product="Product"}},
  task={spawn=function(fn,...) fn(...) end,defer=function(fn,...) table.insert(deferQueue,{fn,...}) end},
  warn=function() end,
 },{__index=getfenv()})
 local function load(source,name)
  local chunk,err=loadstring(source,name); assert(chunk,err); setfenv(chunk,environment); return chunk()
 end
 local config=load(configSource,"Config")
 local rules=load(rulesSource,"EventRules")
 environment.require=function(ref)
  if ref==refs.Config then return config elseif ref==refs.EventRules then return rules end
  error("Unexpected require")
 end
 config.Commerce={PassId=0,SupplyDropProductId=0}
 local commerce=load(commerceSource,"Commerce")
 local player={UserId=42,Parent=players}; players.Members[42]=player
 local receiptIds,credits,messages,passNotifications={},{},{},{}
 local canBuy=true
 local grantsPaused=false
 commerce.Start({
  Message=function(_,text) table.insert(messages,text) end,
  OnPassChanged=function(_,owns) table.insert(passNotifications,owns) end,
  CanPurchaseDrop=function() return canBuy end,
  GrantDropCredit=function(p,id)
   if id=="error" then error("Simulated DataStore outage") end
   if id=="concurrent" then
    assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId=id})=="Pending", "Concurrent receipt re-entered the durable grant callback")
   end
   if grantsPaused then return false end
   if not receiptIds[id] then receiptIds[id]=true; credits[p.UserId]=(credits[p.UserId] or 0)+1 end
   return true
  end,
 })
 commerce.OnPlayerAdded(player)
 assert(#marketplace.Calls==0,"ID=0 must never call Roblox APIs")
 assert(not commerce.HasPass(player))
 assert(not commerce.PromptPass(player) and not commerce.PromptSupplyDrop(player))
 assert(#marketplace.Calls==0,"Disabled purchase button called Marketplace")
 local available=commerce.GetAvailability(player)
 assert(not available.PassAvailable and not available.DropAvailable and #available.DisabledReason>0)
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=0,PurchaseId="disabled"})=="Pending")
 assert(not credits[42],"ID=0 receipt granted currency")

 config.Commerce={PassId=123,SupplyDropProductId=456}
 assert(commerce.PromptPass(player)); assert(commerce.PromptSupplyDrop(player))
 assert(marketplace.ProcessReceipt({PlayerId=99,ProductId=456,PurchaseId="offline"})=="Pending")
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=999,PurchaseId="wrong-product"})=="Pending")
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId=""})=="Pending")
 assert(not credits[42],"Unrelated or malformed receipts were granted")
 grantsPaused=true
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="retry"})=="Pending")
 assert(not credits[42],"Unavailable persistence granted a paid credit")
 grantsPaused=false
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="retry"})=="Granted")
 assert(credits[42]==1)
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="retry"})=="Granted")
 assert(credits[42]==1,"Receipt replay added a duplicate paid credit")
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="second"})=="Granted")
 assert(credits[42]==2)
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="error"})=="Pending")
 assert(credits[42]==2,"Throwing grant callback acknowledged a paid purchase")
 assert(marketplace.ProcessReceipt({PlayerId=42,ProductId=456,PurchaseId="concurrent"})=="Granted")
 assert(credits[42]==3)

 marketplace.PromptGamePassPurchaseFinished:Fire(player,999,true)
 assert(not commerce.HasPass(player),"Unrelated pass unlocked entitlements")
 marketplace.PromptGamePassPurchaseFinished:Fire(player,123,false)
 assert(not commerce.HasPass(player),"Cancelled pass unlocked entitlements")
 marketplace.PromptGamePassPurchaseFinished:Fire(player,123,true)
 assert(commerce.HasPass(player))
 local benefits=commerce.GetBenefits(player)
 assert(benefits.FoodMultiplier==1.5 and benefits.CoinMultiplier==1.5 and benefits.FreeRerollsPerMeal==2 and benefits.NearDeathRespawnCooldown==180)
 assert(not commerce.PromptPass(player),"Owned pass should not re-prompt purchase")
 canBuy=false
 local count=#marketplace.Calls
 assert(not commerce.PromptSupplyDrop(player))
 assert(#marketplace.Calls==count,"Paused persistence still prompted a paid purchase")
 players.PlayerRemoving:Fire(player)
 assert(not commerce.HasPass(player),"Left player leaked cached entitlement")

 -- Entitlement query succeeds for a player who joins with a configured pass.
 local returning={UserId=43,Parent=players}; marketplace.Owned=true; players.Members[43]=returning
 commerce.OnPlayerAdded(returning)
 assert(commerce.HasPass(returning))
 local solo={UserId=-1,Parent=players}; count=#marketplace.Calls
 commerce.OnPlayerAdded(solo)
 assert(not commerce.HasPass(solo) and #marketplace.Calls==count,"Studio test user called paid entitlement APIs")
 print("PASS: actual Commerce adapter: disabled IDs, safe prompts, durable receipt replay, missing player, pass entitlements")
end
