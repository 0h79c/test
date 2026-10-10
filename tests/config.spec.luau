local Config = require("../src/shared/Config")
assert(#Config.Species == 15)
assert(Config.Unlocked(0) == 1)
assert(Config.Unlocked(9) == 1)
assert(Config.Unlocked(10) == 2)
assert(Config.Unlocked(140) == 15)
assert(Config.Species[4].JumpPower == 65)
assert(Config.Species[10].WalkSpeed == 35)
assert(Config.Species[15].JumpPower == 120)
local counts = {}
for roll = 1, 100 do
 local rng = {NextInteger=function(_,minimum,maximum)
  assert(minimum == 1 and maximum == 100)
  return roll
 end}
 local name = Config.Roll(rng)
 counts[name] = (counts[name] or 0) + 1
end
for _,mutation in ipairs(Config.Mutations) do
 assert(counts[mutation.Name] == mutation.Weight, mutation.Name)
 assert(Config.Mutation(mutation.Name) == mutation)
end
assert(Config.Mutation("invalid").Name == "Normal")
print("PASS: species, evolution thresholds, all 100 RNG outcomes, mutation lookup")
