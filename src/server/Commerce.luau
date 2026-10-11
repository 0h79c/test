-- Roblox purchases are fulfilled only by ProcessReceipt and a durable profile
-- transaction supplied by Main. Product/Pass ID 0 means intentionally disabled.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.EventRules)
local Commerce = {}
local callbacks = {}
local owned, querying, receiptsInFlight = {}, {}, {}
local started = false
local passPrice, dropPrice

local function ids()
 local settings = Config.Commerce or {}
 return settings.PassId or 0, settings.SupplyDropProductId or 0
end
local function message(player, text)
 if callbacks.Message and player and player.Parent then callbacks.Message(player, text) end
end
local function notifyPass(player, hasPass)
 owned[player] = hasPass == true
 if callbacks.OnPassChanged and player.Parent then callbacks.OnPassChanged(player, owned[player]) end
end
local function lookupPrice(id, infoType)
 if not Rules.IsValidMarketplaceId(id) then return nil end
 local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, infoType) end)
 if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
  return info.PriceInRobux
 end
 return nil
end

function Commerce.HasPass(player)
 return owned[player] == true
end
function Commerce.GetBenefits(player)
 return Rules.PassBenefits(Commerce.HasPass(player))
end
function Commerce.GetAvailability(player)
 local passId, dropId = ids()
 return {
  PassAvailable = Rules.IsValidMarketplaceId(passId),
  DropAvailable = Rules.IsValidMarketplaceId(dropId),
  PassOwned = Commerce.HasPass(player), PassPrice = passPrice, DropPrice = dropPrice,
  DisabledReason = "Chưa cấu hình ID Roblox. Chủ game cần tạo Game Pass / Developer Product.",
 }
end
function Commerce.OnPlayerAdded(player)
 if querying[player] or owned[player] ~= nil then return end
 local passId = ids()
 if not Rules.IsValidMarketplaceId(passId) or player.UserId <= 0 then
  notifyPass(player, false)
  return
 end
 querying[player] = true
 task.spawn(function()
  local ok, result = pcall(function()
   return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
  end)
  querying[player] = nil
  if not player.Parent then return end
  -- A confirmed purchase may arrive while the query yields. Never overwrite it
  -- with a stale false result. A failed query grants no paid entitlement.
  if owned[player] == true then return end
  if ok then notifyPass(player, result == true)
  else
   owned[player] = nil
   if callbacks.OnPassChanged then callbacks.OnPassChanged(player, false) end
   message(player, "Chưa kiểm tra được Game Pass; mở lại cửa hàng để thử lại.")
  end
 end)
end
function Commerce.PromptPass(player)
 local passId = ids()
 if not Rules.IsValidMarketplaceId(passId) then
  message(player, "Gói hỗ trợ đang chờ chủ game cấu hình ID Game Pass.")
  return false
 end
 if Commerce.HasPass(player) then message(player, "Bạn đã sở hữu gói hỗ trợ."); return false end
 Commerce.OnPlayerAdded(player)
 local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, passId) end)
 if not ok then message(player, "Không mở được cửa hàng Roblox. Vui lòng thử lại.") end
 return ok
end
function Commerce.PromptSupplyDrop(player)
 local _, productId = ids()
 if not Rules.IsValidMarketplaceId(productId) then
  message(player, "Thính mua bằng Robux đang chờ cấu hình Developer Product.")
  return false
 end
 -- Unavailable persistence must never lead to charging without a durable award.
 if callbacks.CanPurchaseDrop and not callbacks.CanPurchaseDrop(player) then
  message(player, "Lưu dữ liệu chưa sẵn sàng; mua thính sẽ mở lại khi có thể lưu an toàn.")
  return false
 end
 local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, productId) end)
 if not ok then message(player, "Không mở được cửa hàng Roblox. Vui lòng thử lại.") end
 return ok
end

function Commerce.Start(options)
 if started then return end
 started = true
 callbacks = options or {}
 MarketplaceService.ProcessReceipt = function(receipt)
  local _, productId = ids()
  local player = Players:GetPlayerByUserId(receipt.PlayerId)
  local purchaseId = receipt.PurchaseId
  if Rules.ReceiptDecision(receipt.ProductId, productId, player ~= nil, true) ~= "PurchaseGranted"
   or typeof(purchaseId) ~= "string" or purchaseId == "" or #purchaseId > 200
   or not callbacks.GrantDropCredit or receiptsInFlight[purchaseId] then
   return Enum.ProductPurchaseDecision.NotProcessedYet
  end
  receiptsInFlight[purchaseId] = true
  local ok, granted = pcall(callbacks.GrantDropCredit, player, purchaseId)
  receiptsInFlight[purchaseId] = nil
  if not ok then warn("Supply drop receipt persistence failed", receipt.PlayerId) end
  if Rules.ReceiptDecision(receipt.ProductId, productId, player ~= nil, ok and granted == true) == "PurchaseGranted" then
   -- Main queues persisted credits after granting, including when the player
   -- reconnects. This hook is optional; replayed receipts cannot add credits.
   if callbacks.OnDropCreditGranted then task.defer(callbacks.OnDropCreditGranted, player) end
   return Enum.ProductPurchaseDecision.PurchaseGranted
  end
  return Enum.ProductPurchaseDecision.NotProcessedYet
 end
 MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedId, wasPurchased)
  local passId = ids()
  if wasPurchased and Rules.IsValidMarketplaceId(passId) and purchasedId == passId then
   notifyPass(player, true)
   message(player, "Đã kích hoạt gói hỗ trợ: +50% độ no và Coins, 2 reroll miễn phí mỗi món đột biến, hồi sinh gần mỗi 3 phút.")
  end
 end)
 Players.PlayerRemoving:Connect(function(player) owned[player] = nil; querying[player] = nil end)
 task.spawn(function()
  local passId, dropId = ids()
  passPrice = lookupPrice(passId, Enum.InfoType.GamePass)
  dropPrice = lookupPrice(dropId, Enum.InfoType.Product)
  if callbacks.OnAvailabilityChanged then callbacks.OnAvailabilityChanged() end
 end)
end

return Commerce
