local Config = {}
Config.CheckpointsPerEvolution = 10
Config.CheckpointReward = 100
Config.RerollCost = 500
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
function Config.Unlocked(checkpoint)
 return math.clamp(1 + math.floor(checkpoint / Config.CheckpointsPerEvolution), 1, #Config.Species)
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
