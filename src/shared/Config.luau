local Config = {}
Config.MetersPerStud = 0.28
Config.DeathRespawnMeters = 200
Config.DeathRespawnStuds = Config.DeathRespawnMeters / Config.MetersPerStud
Config.NearRespawnCooldown = 180
Config.NearRespawnOfferSeconds = 120
Config.AttackRange = 9
Config.AttackCooldown = 1.25
Config.SpawnProtectionSeconds = 8
Config.MutationFoodSpawnChance = 0.012
Config.FoodCount = 220
Config.NPCCount = 24
Config.Commerce = {PassId=0, SupplyDropProductId=0}
Config.Drop = {
 CheckInterval=300, ChancePerPlayer=0.05, WarningSeconds=180,
 CoinsMin=800, CoinsMax=1800, FullnessMin=20, FullnessMax=50,
 DespawnSeconds=600, MaxPending=3,
}
Config.Foods = {
 {Id="berry",Name="Quả mọng",Hunger=0.5,Coins=4,Weight=22},
 {Id="leaf",Name="Lá non",Hunger=1,Coins=6,Weight=20},
 {Id="apple",Name="Táo",Hunger=2,Coins=10,Weight=18},
 {Id="mushroom",Name="Nấm",Hunger=3,Coins=14,Weight=17},
 {Id="fish",Name="Cá",Hunger=5,Coins=22,Weight=11},
 {Id="meat",Name="Thịt",Hunger=7,Coins=30,Weight=8},
 {Id="fruit",Name="Trái cây quý",Hunger=10,Coins=45,Weight=4},
}
-- The remaining 75% is Normal. A supply drop triples each non-Normal
-- probability exactly (8/7/7/3 -> 24/21/21/9), leaving 25% Normal.
Config.RareFoodMutations = {
 {Name="Normal",Weight=75}, {Name="Giant",Weight=8}, {Name="Tiny",Weight=7},
 {Name="Radioactive",Weight=7}, {Name="Awakened",Weight=3},
}
Config.Species = {}
local rows = {
 {"Snail", "Ốc Sên",12,40}, {"Caterpillar","Sâu Bướm",14,45},
 {"Mouse","Chuột",16,50}, {"Frog","Ếch",16,65}, {"Turtle","Rùa",14,50},
 {"Rabbit","Thỏ",18,60}, {"Cat","Mèo",20,60}, {"Hound","Chó Săn",24,60},
 {"Monkey","Khỉ",22,75}, {"Cheetah","Báo Gấm",35,65},
 {"Kangaroo","Chuột Túi",24,90}, {"Gorilla","Tinh Tinh",20,70},
 {"Pegasus","Ngựa Cánh",35,95}, {"Phoenix","Phượng Hoàng",40,100},
 {"WhiteDragon","Rồng Trắng",50,120},
}
for id, row in ipairs(rows) do
 Config.Species[id] = {ModelName=row[1], Name=row[2], WalkSpeed=row[3], JumpPower=row[4]}
end
Config.Mutations = {
 {Name="Normal", Label="Nguyên bản", Weight=50, Scale=1, Speed=1, Jump=1},
 {Name="Giant", Label="Khổng lồ", Weight=20, Scale=1.5, Speed=1.1, Jump=1.05},
 {Name="Tiny", Label="Tí hon", Weight=15, Scale=0.5, Speed=1.05, Jump=1.1},
 {Name="Radioactive", Label="Phát quang", Weight=10, Scale=1, Speed=1.15, Jump=1.15},
 {Name="Awakened", Label="Thức tỉnh", Weight=5, Scale=1, Speed=1.3, Jump=1.3},
}
function Config.Unlocked(legacyCheckpoint)
 -- Only used to migrate saves from the old obby version.
 return math.clamp(1 + math.floor(legacyCheckpoint / 10), 1, #Config.Species)
end
function Config.Roll(rng)
 local roll = rng:NextInteger(1,100)
 for _, mutation in ipairs(Config.Mutations) do
  roll -= mutation.Weight
  if roll <= 0 then return mutation.Name end
 end
 return "Normal"
end
function Config.Mutation(name)
 for _, mutation in ipairs(Config.Mutations) do
  if mutation.Name == name then return mutation end
 end
 return Config.Mutations[1]
end
return Config
