local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Progression = {}
local function nearby(player, part)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - part.Position).Magnitude <= 16
end
function Progression.init(data, world, remotes)
	Progression.Data, Progression.World, Progression.Remotes = data, world, remotes
	for id, hub in pairs(world.Hubs) do
		hub.QuestPrompt.Triggered:Connect(function(player)
			local p = data.Profiles[player]
			if not p or not nearby(player, hub.QuestRoot) then return end
			local offers = {}
			for questId, q in pairs(Config.Quests) do if q.Island == id then table.insert(offers, questId) end end
			table.sort(offers, function(a, b) return Config.Quests[a].Level < Config.Quests[b].Level end)
			data.sync(player)
			remotes.Dialogue:FireClient(player, {Kind = "Quest", Title = hub.Definition.QuestNPC.Name, Island = id, Offers = offers})
		end)
		hub.FerryPrompt.Triggered:Connect(function(player)
			if not data.Profiles[player] or not nearby(player, hub.FerryRoot) then return end
			remotes.Dialogue:FireClient(player, {Kind = "Ferry", Title = "Ivo · passeur", Island = id})
		end)
	end
	world.Master.Prompt.Triggered:Connect(function(player)
		if nearby(player, world.Master.Root) then
			remotes.Dialogue:FireClient(player, {Kind = "Master", Title = "Ren · maître d'armes"})
		end
	end)
	world.FruitNPC.Prompt.Triggered:Connect(function(player)
		if nearby(player, world.FruitNPC.Root) then
			remotes.Dialogue:FireClient(player, {Kind = "Fruit", Title = "Ena · chercheuse des fruits"})
		end
	end)
end
function Progression.quest(player, action, questId)
	local data = Progression.Data
	local p, q = data.Profiles[player], type(questId) == "string" and Config.Quests[questId]
	if not p then return end
	if action == "AbandonQuest" then p.Quest = nil; data.sync(player); return end
	if not q then return end
	local hub = Progression.World.Hubs[q.Island]
	if not nearby(player, hub.QuestRoot) then return end
	if action == "AcceptQuest" then
		local ok, reason = Rules.canTakeQuest(p, q, questId)
		if not ok then data.notify(player, reason); return end
		p.Quest = {Id = questId, Progress = 0}
		data.notify(player, "Quête acceptée : " .. q.Name)
	elseif action == "TurnInQuest" then
		if not p.Quest or p.Quest.Id ~= questId or p.Quest.Progress < q.Count then return end
		p.Quest = nil -- consume first: duplicate requests cannot award twice
		local firstCompletion = not p.Completed[questId]
		p.Completed[questId] = true
		if firstCompletion and q.Unlock then
			if Config.Styles[q.Unlock] then p.Owned[q.Unlock] = true else p[q.Unlock] = true end
			local label = Config.Styles[q.Unlock] and Config.Styles[q.Unlock].Name or (q.Unlock == "Armament" and "Haki de l'Armement" or "Haki de l'Observation")
			data.notify(player, label .. " débloqué !")
		end
		data.reward(player, q.XP, q.Coins)
		data.notify(player, "+" .. q.XP .. " XP · +" .. q.Coins .. " pièces")
	end
	data.sync(player)
end
function Progression.kill(player, enemyId)
	local data = Progression.Data
	local p, enemy = data.Profiles[player], Config.Enemies[enemyId]
	if not p or not enemy then return end
	if p.Quest then
		local q = Config.Quests[p.Quest.Id]
		if q and Rules.advanceQuest(p.Quest, q, enemyId) and p.Quest.Progress == q.Count then
			data.notify(player, "Objectif terminé. Retourne voir le PNJ.")
		end
	end
	data.reward(player, enemy.XP, enemy.Coins)
end
function Progression.fruit(player)
	local data = Progression.Data
	local p = data.Profiles[player]
	if not p or not nearby(player, Progression.World.FruitNPC.Root) then return end
	if not p.Completed[Config.Fruit.RequiredQuest] then data.notify(player, "Termine d'abord « Écouter la forêt »."); return end
	if p.Fruit then data.notify(player, "Tu maîtrises déjà les Braises. [T] pour créer une technique."); return end
	p.Fruit = true
	data.sync(player)
	data.notify(player, "Fruit des Braises acquis. [T] : technique · [Z] : utiliser. La mer devient plus dangereuse.")
end
function Progression.travel(player, targetId, sourceId)
	local data, world = Progression.Data, Progression.World
	local p, source, target = data.Profiles[player], world.Hubs[sourceId], world.Hubs[targetId]
	if not p or not source or not target or not nearby(player, source.FerryRoot) then return end
	if p.Level < target.Definition.Level then data.notify(player, "Niveau " .. target.Definition.Level .. " requis pour cette traversée."); return end
	if player:GetAttribute("InCombatUntil") and player:GetAttribute("InCombatUntil") > workspace:GetServerTimeNow() then
		data.notify(player, "Éloigne-toi du combat avant de voyager."); return
	end
	p.LastIsland = targetId
	player.Character:PivotTo(target.Spawn)
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if root then root.AssemblyLinearVelocity = Vector3.zero end
	data.notify(player, "Bienvenue · " .. target.Definition.Name)
	data.sync(player)
end
return Progression
