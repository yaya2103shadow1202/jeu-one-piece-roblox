local Rules = require("../src/shared/Rules")
local Config = require("../src/shared/Config")
local count = 0
local function check(ok, message) assert(ok, message); count += 1 end
local level, xp = Rules.addXP(1, 0, 80, 30)
check(level == 2 and xp == 0, "exact XP threshold")
local amount = 0
for n = 1, 29 do amount += Rules.xpNeeded(n) end
level, xp = Rules.addXP(1, 0, amount + 99999, 30)
check(level == 30 and xp == 0, "level cap")
for n = 1, 29 do check(Rules.xpNeeded(n + 1) > Rules.xpNeeded(n), "XP progression must increase") end
local broken = {nil, "recipe", {}, {Shape = "Hacked", Power = 1, Size = 1, Reach = 1}, {Shape = "Zone", Power = 0/0, Size = 1, Reach = 1},
	{Shape = "Zone", Power = math.huge, Size = 1, Reach = 1}, {Shape = "Zone", Power = 1.5, Size = 1, Reach = 1}, {Shape = "Zone", Power = 4, Size = 1, Reach = 1}}
check(Rules.validateTechnique(nil) == nil, "reject nil")
for _, bad in pairs(broken) do check(Rules.validateTechnique(bad) == nil, "reject invalid recipe") end
for _, shape in ipairs(Config.Fruit.Shapes) do
	for power = 1, 3 do for size = 1, 3 do for reach = 1, 3 do
		local value = {Shape = shape, Power = power, Size = size, Reach = reach, UntrustedDamage = 100000}
		local clean, stats = Rules.validateTechnique(value), Rules.techniqueStats(value)
		check(clean.UntrustedDamage == nil, "strip untrusted fields")
		check(stats.Cost > 0 and stats.Cost <= 100 and stats.Cooldown > 0, "every recipe must be usable and bounded")
	end end end
end
check(Rules.damage(10, 1, 0, "Off") == 10, "baseline fists damage")
check(Rules.damage(10, 1, 0, "Focus") == 13, "armament focus")
local q = {Id = "PortBandits", Progress = 0}
check(not Rules.advanceQuest(q, Config.Quests.PortBandits, "Ronin") and q.Progress == 0, "wrong enemy ignored")
for _ = 1, 12 do Rules.advanceQuest(q, Config.Quests.PortBandits, "Bandit") end
check(q.Progress == 4, "quest progress capped")
local p = {Level = 1, Completed = {}}
check(Rules.canTakeQuest(p, Config.Quests.PortBandits), "starter quest available")
check(not Rules.canTakeQuest(p, Config.Quests.JungleRaiders), "level requirement")
p.Level = 30
check(not Rules.canTakeQuest(p, Config.Quests.PortBoss), "prerequisite required")
p.Completed.PortBandits = true
check(Rules.canTakeQuest(p, Config.Quests.PortBoss), "boss unlocked after prerequisite")
p.Quest = q
check(not Rules.canTakeQuest(p, Config.Quests.PortBandits), "only one quest")
for id, quest in pairs(Config.Quests) do
	check(Config.Enemies[quest.Target] ~= nil, id .. " must target a real enemy")
	check(not quest.Requires or Config.Quests[quest.Requires] ~= nil, id .. " has valid prerequisite")
	check(quest.Count >= 1 and quest.XP > 0, id .. " has rewards/objective")
end
for _, island in ipairs(Config.Islands) do
	check(Config.Quests[island.Quest].Island == island.Id, "quest belongs to island")
	check(Config.Enemies[island.Enemy] and Config.Enemies[island.Boss], "island enemies configured")
end
print("PASS Rules:", count, "assertions")
