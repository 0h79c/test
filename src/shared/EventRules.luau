-- Pure event and commerce rules shared by server services and validation.
local EventRules = {}

local function isFiniteNumber(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function EventRules.DropChance(playerCount)
	if not isFiniteNumber(playerCount) then
		return 0
	end
	return math.clamp(0.05 * math.floor(playerCount), 0, 1)
end

function EventRules.RollDrop(playerCount, rng)
	local chance = EventRules.DropChance(playerCount)
	return chance >= 1 or (chance > 0 and rng:NextNumber() < chance)
end

function EventRules.IsValidMarketplaceId(id)
	return isFiniteNumber(id) and id > 0 and id == math.floor(id)
end

function EventRules.ReceiptDecision(productId, expectedProductId, playerPresent, grantOk)
	if EventRules.IsValidMarketplaceId(productId)
		and EventRules.IsValidMarketplaceId(expectedProductId)
		and productId == expectedProductId
		and playerPresent == true
		and grantOk == true
	then
		return "PurchaseGranted"
	end
	return "NotProcessedYet"
end

function EventRules.PassBenefits(owned)
	local hasPass = owned == true
	return {
		FoodMultiplier = if hasPass then 1.5 else 1,
		CoinMultiplier = if hasPass then 1.5 else 1,
		FreeRerollsPerMeal = if hasPass then 2 else 0,
		NearDeathRespawnCooldown = if hasPass then 180 else 0,
	}
end

return EventRules
