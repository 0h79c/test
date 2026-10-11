local Rules = require("../src/shared/EventRules")

assert(Rules.DropChance(0) == 0)
assert(Rules.DropChance(1) == 0.05)
assert(Rules.DropChance(20) == 1)
assert(Rules.DropChance(30) == 1)
assert(Rules.DropChance(-2) == 0)
assert(Rules.DropChance(1.9) == 0.05)
assert(Rules.DropChance(nil) == 0)
assert(Rules.DropChance("20") == 0)
assert(Rules.DropChance(math.huge) == 0)
assert(Rules.DropChance(-math.huge) == 0)
assert(Rules.DropChance(0 / 0) == 0)

local function rngAt(value)
	return {NextNumber = function() return value end}
end
assert(not Rules.RollDrop(0, rngAt(0)))
assert(Rules.RollDrop(1, rngAt(0.049)))
assert(not Rules.RollDrop(1, rngAt(0.05)))
assert(Rules.RollDrop(20, rngAt(0.999)))
assert(Rules.RollDrop(20, rngAt(1)))

assert(Rules.IsValidMarketplaceId(12345))
for _, id in ipairs({0, -1, 1.25, "12345", false, math.huge, -math.huge, 0 / 0}) do
	assert(not Rules.IsValidMarketplaceId(id))
end
assert(not Rules.IsValidMarketplaceId(nil))
assert(Rules.ReceiptDecision(100, 100, true, true) == "PurchaseGranted")
assert(Rules.ReceiptDecision(101, 100, true, true) == "NotProcessedYet")
assert(Rules.ReceiptDecision(0, 0, true, true) == "NotProcessedYet")
assert(Rules.ReceiptDecision(100, 100, false, true) == "NotProcessedYet")
assert(Rules.ReceiptDecision(100, 100, true, false) == "NotProcessedYet")
assert(Rules.ReceiptDecision(100, 100, true, nil) == "NotProcessedYet")
assert(Rules.ReceiptDecision(100, 100, 1, true) == "NotProcessedYet")
assert(Rules.ReceiptDecision("100", "100", true, true) == "NotProcessedYet")
assert(Rules.ReceiptDecision(1.5, 1.5, true, true) == "NotProcessedYet")

local regular = Rules.PassBenefits(false)
assert(regular.FoodMultiplier == 1)
assert(regular.CoinMultiplier == 1)
assert(regular.FreeRerollsPerMeal == 0)
assert(regular.NearDeathRespawnCooldown == 0)
local premium = Rules.PassBenefits(true)
assert(premium.FoodMultiplier == 1.5)
assert(premium.CoinMultiplier == 1.5)
assert(premium.FreeRerollsPerMeal == 2)
assert(premium.NearDeathRespawnCooldown == 180)
assert(Rules.PassBenefits(nil).FoodMultiplier == 1)
regular.FoodMultiplier = 99
assert(Rules.PassBenefits(false).FoodMultiplier == 1)

print("PASS: population drop chances, marketplace receipt validation, pass benefits")
