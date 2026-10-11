-- Server-authoritative progression rules with no Roblox service dependencies.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Rules = {}
local MAX_COINS = 2147483647
local SPECIES_COUNT = #Config.Species
local mutationNames = {"Normal", "Giant", "Tiny", "Radioactive", "Awakened"}
local validMutation = {}
for _, name in ipairs(mutationNames) do validMutation[name] = true end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function bounded(value, minimum, maximum, fallback, integer)
	if not finite(value) then return fallback end
	if integer then value = math.floor(value) end
	return math.clamp(value, minimum, maximum)
end

local function positive(value)
	return if finite(value) then math.max(0, value) else 0
end

function Rules.DefaultProfile()
	return {
		Coins = 0, Fullness = 0, Unlocked = 1, Form = 1,
		Mutations = {["1"] = "Normal"}, FreeRerolls = 0, LastMutationBoost = 1,
	}
end

function Rules.Normalize(raw)
	if type(raw) ~= "table" then return Rules.DefaultProfile() end
	local unlocked
	if raw.Unlocked == nil then
		local checkpoint = bounded(raw.Checkpoint, 0, 140, 0, true)
		unlocked = math.clamp(1 + math.floor(checkpoint / 10), 1, SPECIES_COUNT)
	else
		unlocked = bounded(raw.Unlocked, 1, SPECIES_COUNT, 1, true)
	end
	local mutations = {}
	for form = 1, unlocked do
		local name
		if type(raw.Mutations) == "table" then
			name = raw.Mutations[tostring(form)] or raw.Mutations[form]
		end
		mutations[tostring(form)] = if type(name) == "string" and validMutation[name] then name else "Normal"
	end
	return {
		Coins = bounded(raw.Coins, 0, MAX_COINS, 0, true),
		Fullness = bounded(raw.Fullness, 0, 100, 0, false),
		Unlocked = unlocked,
		Form = bounded(raw.Form, 1, unlocked, 1, true),
		Mutations = mutations,
		FreeRerolls = bounded(raw.FreeRerolls, 0, 2, 0, true),
		LastMutationBoost = if raw.LastMutationBoost == 3 then 3 else 1,
	}
end

function Rules.FullnessGain(base, hasPass)
	return positive(base) * (if hasPass == true then 1.5 else 1)
end

function Rules.CoinsGain(base, hasPass)
	return math.min(MAX_COINS, math.floor(positive(base) * (if hasPass == true then 1.5 else 1) + 0.5))
end

function Rules.AddFood(profile, spec, hasPass)
	local oldFullness = bounded(profile.Fullness, 0, 100, 0, false)
	local oldCoins = bounded(profile.Coins, 0, MAX_COINS, 0, true)
	local food = if type(spec) == "table" then spec else {}
	local base = if food.Hunger ~= nil then food.Hunger else food.Fullness
	profile.Fullness = math.min(100, oldFullness + Rules.FullnessGain(base, hasPass))
	profile.Coins = math.min(MAX_COINS, oldCoins + Rules.CoinsGain(food.Coins, hasPass))
	return profile.Fullness - oldFullness, profile.Coins - oldCoins
end

function Rules.CanEvolve(profile)
	return type(profile) == "table"
		and finite(profile.Unlocked) and profile.Unlocked >= 1 and profile.Unlocked < SPECIES_COUNT
		and finite(profile.Fullness) and profile.Fullness >= 100
end

function Rules.Evolve(profile)
	if not Rules.CanEvolve(profile) then return false end
	profile.Unlocked = math.floor(profile.Unlocked) + 1
	profile.Form = profile.Unlocked
	profile.Fullness = 0
	profile.Mutations[tostring(profile.Unlocked)] = "Normal"
	-- Free rolls belong to the last rare meal and must not transfer to a new species.
	profile.FreeRerolls = 0
	profile.LastMutationBoost = 1
	return true
end

function Rules.MutationWeights(boost)
	local factor = if boost == 3 then 3 else 1
	local baseWeights = {Normal = 75, Giant = 8, Tiny = 7, Radioactive = 7, Awakened = 3}
	for _, row in ipairs(Config.RareFoodMutations or {}) do
		if validMutation[row.Name] and finite(row.Weight) and row.Weight >= 0 then
			baseWeights[row.Name] = row.Weight
		end
	end
	local nonNormal = 0
	for index = 2, #mutationNames do nonNormal += baseWeights[mutationNames[index]] * factor end
	assert(nonNormal <= 100, "Rare-food mutation weights must fit within 100 percent")
	local result = {{Name = "Normal", Weight = 100 - nonNormal}}
	for index = 2, #mutationNames do
		local name = mutationNames[index]
		table.insert(result, {Name = name, Weight = baseWeights[name] * factor})
	end
	return result
end

function Rules.RollMutation(rng, boost)
	local roll = rng:NextInteger(1, 100)
	for _, row in ipairs(Rules.MutationWeights(boost)) do
		roll -= row.Weight
		if roll <= 0 then return row.Name end
	end
	return "Normal"
end

function Rules.StartMutation(profile, rng, boost, hasPass)
	local factor = if boost == 3 then 3 else 1
	local name = Rules.RollMutation(rng, factor)
	profile.Mutations[tostring(profile.Form)] = name
	profile.FreeRerolls = if hasPass == true then 2 else 0
	profile.LastMutationBoost = factor
	return name
end

function Rules.Reroll(profile, rng)
	if not finite(profile.FreeRerolls) or profile.FreeRerolls < 1 then return nil end
	profile.FreeRerolls -= 1
	local name = Rules.RollMutation(rng, profile.LastMutationBoost)
	profile.Mutations[tostring(profile.Form)] = name
	return name
end

function Rules.CanEatNPC(form, preyForm, predatorVolume, preyVolume)
	if predatorVolume ~= nil or preyVolume ~= nil then
		return finite(predatorVolume) and finite(preyVolume)
			and predatorVolume > 0 and preyVolume > 0 and predatorVolume > preyVolume
	end
	return finite(form) and finite(preyForm) and form > preyForm
end

function Rules.AttackStrength(form)
	return 18 + bounded(form, 1, SPECIES_COUNT, 1, true) * 4
end

return Rules
