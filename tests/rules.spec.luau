local Rules = require("../src/shared/Rules")

local function rngAt(roll)
	return {NextInteger = function(_, minimum, maximum)
		assert(minimum == 1 and maximum == 100)
		return roll
	end}
end

local expected = {
	[1] = {Normal = 75, Giant = 8, Tiny = 7, Radioactive = 7, Awakened = 3},
	[3] = {Normal = 25, Giant = 24, Tiny = 21, Radioactive = 21, Awakened = 9},
}
for _, boost in ipairs({1, 3}) do
	local counts = {}
	for roll = 1, 100 do
		local name = Rules.RollMutation(rngAt(roll), boost)
		counts[name] = (counts[name] or 0) + 1
	end
	local sum = 0
	for _, row in ipairs(Rules.MutationWeights(boost)) do
		assert(row.Weight == expected[boost][row.Name], row.Name)
		assert(counts[row.Name] == row.Weight, row.Name)
		sum += row.Weight
	end
	assert(sum == 100)
end

assert(Rules.FullnessGain(0.5, false) == 0.5)
assert(Rules.FullnessGain(10, true) == 15)
assert(Rules.FullnessGain(-10, true) == 0)
assert(Rules.FullnessGain(math.huge, true) == 0)
assert(Rules.CoinsGain(5, true) == 8)
assert(Rules.CoinsGain(5, false) == 5)
assert(Rules.CoinsGain(0 / 0, true) == 0)
local profile = Rules.DefaultProfile()
assert(profile.Unlocked == 1 and profile.Form == 1 and profile.Fullness == 0)
local gain, coins = Rules.AddFood(profile, {Hunger = 10, Coins = 10}, true)
assert(gain == 15 and coins == 15 and profile.Coins == 15)
profile.Fullness = 99.5
gain, coins = Rules.AddFood(profile, {Hunger = 10, Fullness = 1, Coins = 5}, true)
assert(gain == 0.5 and coins == 8 and profile.Fullness == 100)
gain, coins = Rules.AddFood(profile, {Fullness = 20, Coins = 4}, false)
assert(gain == 0 and coins == 4)
profile.Coins = 2147483646
gain, coins = Rules.AddFood(profile, {Hunger = 0, Coins = 10}, true)
assert(coins == 1 and profile.Coins == 2147483647)

local migrated = Rules.Normalize({Checkpoint = 49, Form = 15, Coins = 10.9,
	Mutations = {["1"] = "Awakened", [2] = "Tiny", ["5"] = "invented", ["15"] = "Giant"}})
assert(migrated.Unlocked == 5 and migrated.Form == 5 and migrated.Coins == 10)
assert(migrated.Mutations["1"] == "Awakened" and migrated.Mutations["2"] == "Tiny")
assert(migrated.Mutations["5"] == "Normal" and migrated.Mutations["15"] == nil)
assert(Rules.Normalize({Checkpoint = 140}).Unlocked == 15)
local invalid = Rules.Normalize({Coins = math.huge, Unlocked = 0 / 0, Form = "15", Fullness = -3,
	FreeRerolls = 500, LastMutationBoost = 20})
assert(invalid.Coins == 0 and invalid.Unlocked == 1 and invalid.Form == 1)
assert(invalid.Fullness == 0 and invalid.FreeRerolls == 2 and invalid.LastMutationBoost == 1)
assert(Rules.Normalize({Fullness = 200}).Fullness == 100)
assert(Rules.Normalize({Coins = -10}).Coins == 0)
assert(Rules.Normalize(nil).Mutations["1"] == "Normal")
local raw = {Unlocked = 4, Form = 1, Fullness = 100, Mutations = {["1"] = "Awakened"}}
local evolving = Rules.Normalize(raw)
assert(Rules.CanEvolve(evolving))
assert(Rules.Evolve(evolving))
assert(evolving.Unlocked == 5 and evolving.Form == 5 and evolving.Fullness == 0)
assert(evolving.Mutations["1"] == "Awakened" and evolving.Mutations["5"] == "Normal")
assert(raw.Unlocked == 4 and raw.Mutations["5"] == nil)
assert(not Rules.Evolve(evolving))
local maxed = Rules.Normalize({Unlocked = 15, Form = 1, Fullness = 100})
assert(not Rules.CanEvolve(maxed) and not Rules.Evolve(maxed))
assert(maxed.Fullness == 100 and maxed.Form == 1)

local mutant = Rules.DefaultProfile()
assert(Rules.StartMutation(mutant, rngAt(100), 3, true) == "Awakened")
assert(mutant.FreeRerolls == 2 and mutant.LastMutationBoost == 3)
assert(Rules.Reroll(mutant, rngAt(26)) == "Giant")
assert(mutant.FreeRerolls == 1 and mutant.LastMutationBoost == 3)
assert(Rules.StartMutation(mutant, rngAt(1), 1, true) == "Normal")
assert(mutant.FreeRerolls == 2 and mutant.LastMutationBoost == 1)
assert(Rules.Reroll(mutant, rngAt(76)) == "Giant")
assert(Rules.Reroll(mutant, rngAt(100)) == "Awakened")
assert(mutant.FreeRerolls == 0 and Rules.Reroll(mutant, rngAt(1)) == nil)
Rules.StartMutation(mutant, rngAt(90), 3, false)
assert(mutant.FreeRerolls == 0 and mutant.LastMutationBoost == 3)
assert(Rules.CanEatNPC(3, 2))
assert(not Rules.CanEatNPC(3, 3))
assert(Rules.CanEatNPC(2, 3, 20, 10))
assert(not Rules.CanEatNPC(15, 1, 10, 10))
assert(not Rules.CanEatNPC(15, 1, math.huge, 10))
assert(Rules.AttackStrength(15) > Rules.AttackStrength(1))
assert(Rules.AttackStrength(1) == 22 and Rules.AttackStrength(15) == 78)

print("PASS: hunger progression, pass gains, migration, evolution, all mutation odds, meal rerolls, predation")
