-- Bundled with the unchanged ProgressionService by tools/check.py (no Roblox engine required).
local count = 0
local function check(ok, message) assert(ok, message); count += 1 end
local fakeHumanoid = {Health = 100}
local root = {Position = Vector3.new(0, 0, 0)}
local character = {}
function character:FindFirstChild() return root end
function character:FindFirstChildOfClass() return fakeHumanoid end
function character:PivotTo(cf) root.Position = cf.Position end
local player = {Character = character, Parent = true}
function player:GetAttribute() return 0 end
local p = {Level = 1, XP = 0, Coins = 0, Owned = {Fists = true}, Completed = {}, Quest = nil, Fruit = false}
local rewards, syncs = 0, 0
local data = {Profiles = {[player] = p}}
function data.sync() syncs += 1 end
function data.notify() end
function data.reward(_, xp, coins) rewards += 1; p.XP += xp; p.Coins += coins end
local npcRoot = {Position = Vector3.new(0, 0, 0)}
Progression.Data = data
Progression.World = {Hubs = {Port = {QuestRoot = npcRoot, FerryRoot = npcRoot}, Storm = {Definition = {Level = 20, Name = "Storm"}, Spawn = {Position = Vector3.new(500, 0, 0)}}}, FruitNPC = {Root = npcRoot}}
Progression.quest(player, "TurnInQuest", "PortBandits")
check(rewards == 0, "cannot claim a quest never accepted")
Progression.quest(player, "AcceptQuest", "PortBandits")
check(p.Quest and p.Quest.Progress == 0, "accept real quest near NPC")
Progression.quest(player, "TurnInQuest", "PortBandits")
check(rewards == 0, "cannot claim unfinished objective")
p.Quest.Progress = 4
root.Position = Vector3.new(100, 0, 0)
Progression.quest(player, "TurnInQuest", "PortBandits")
check(rewards == 0, "remote turn-in rejected outside NPC range")
root.Position = Vector3.new(0, 0, 0)
Progression.quest(player, "TurnInQuest", "PortBandits")
check(rewards == 1 and p.Coins == 80 and p.Owned.Sword and p.Completed.PortBandits and p.Quest == nil, "quest rewards and sword unlock")
for _ = 1, 10 do Progression.quest(player, "TurnInQuest", "PortBandits") end
check(rewards == 1 and p.Coins == 80, "replayed turn-in never duplicates rewards")
Progression.travel(player, "Storm", "Port")
check(root.Position.X == 0, "level-gated ferry cannot teleport")
Progression.fruit(player)
check(not p.Fruit, "fruit requires boss quest")
p.Completed.JungleBoss = true
Progression.fruit(player)
check(p.Fruit, "fruit is opt-in after quest")
Progression.quest(player, "AcceptQuest", "PortBandits")
Progression.kill(player, "Ronin")
check(p.Quest.Progress == 0, "wrong kills never progress objective")
Progression.kill(player, "Bandit")
check(p.Quest.Progress == 1, "correct kills progress objective")
Progression.quest(player, "AbandonQuest")
check(p.Quest == nil, "abandon releases quest slot")
print("PASS ProgressionService:", count, "assertions")
