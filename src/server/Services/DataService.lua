local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Data = {Profiles = {}, Sessions = {}}
local sessionId = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
local store
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in pairs(value) do result[k] = copy(v) end
	return result
end
local function default()
	return {Level = 1, XP = 0, Coins = 0, Style = "Fists", Owned = {Fists = true}, Completed = {},
		Mastery = {Fists = 0, Sword = 0, Gun = 0, Fruit = 0, Haki = 0},
		Observation = false, Armament = false, Fruit = false, LastIsland = "Port",
		Technique = {Shape = "Projectile", Power = 1, Size = 1, Reach = 1}}
end
local function bounded(value, low, high, fallback)
	if not Rules.finite(value) then return fallback end
	return math.clamp(math.floor(value), low, high)
end
local function sanitize(raw)
	local p = default()
	if type(raw) ~= "table" then return p end
	p.Level = bounded(raw.Level, 1, Config.MaxLevel, 1)
	p.XP = bounded(raw.XP, 0, Rules.xpNeeded(p.Level) - 1, 0)
	p.Coins = bounded(raw.Coins, 0, 100000000, 0)
	for key in pairs(Config.Styles) do p.Owned[key] = key == "Fists" or (type(raw.Owned) == "table" and raw.Owned[key] == true) end
	if Config.Styles[raw.Style] and p.Owned[raw.Style] then p.Style = raw.Style end
	for key in pairs(p.Mastery) do p.Mastery[key] = bounded(type(raw.Mastery) == "table" and raw.Mastery[key], 0, 1000, 0) end
	for key in pairs(Config.Quests) do if type(raw.Completed) == "table" and raw.Completed[key] == true then p.Completed[key] = true end end
	for _, key in ipairs({"Observation", "Armament", "Fruit"}) do p[key] = raw[key] == true end
	for _, island in ipairs(Config.Islands) do if raw.LastIsland == island.Id and p.Level >= island.Level then p.LastIsland = island.Id end end
	p.Technique = Rules.validateTechnique(raw.Technique) or p.Technique
	if type(raw.Quest) == "table" and Config.Quests[raw.Quest.Id] then
		p.Quest = {Id = raw.Quest.Id, Progress = bounded(raw.Quest.Progress, 0, Config.Quests[raw.Quest.Id].Count, 0)}
	end
	return p
end
function Data.init(remotes)
	Data.Remotes = remotes
	-- Studio is deliberately session-only: play tests cannot overwrite live progression.
	if not RunService:IsStudio() then
		local ok, result = pcall(function() return DataStoreService:GetDataStore("ArchipelagoProfiles_v1") end)
		if ok then store = result else warn("[Data] DataStore unavailable", result) end
	end
end
function Data.load(player)
	local raw, acquired, locked
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:UpdateAsync("u_" .. player.UserId, function(old)
					if type(old) == "table" and type(old.Session) == "table" and old.Session.Id ~= sessionId and (old.Session.ExpiresAt or 0) > os.time() then
						locked = true
						return nil
					end
					return {Version = 1, Data = type(old) == "table" and old.Data or default(), Session = {Id = sessionId, ExpiresAt = os.time() + 180}}
				end)
			end)
			if ok and result then raw, acquired = result.Data, true; break end
			if locked then player:Kick("Ta sauvegarde est encore ouverte sur un autre serveur. Réessaie dans un instant."); return nil end
			if attempt < 3 then task.wait(attempt) end
		end
	end
	Data.Profiles[player] = sanitize(raw)
	Data.Sessions[player] = {Writable = acquired == true, Saving = false, LastSuccess = os.clock(), Mode = acquired and "Sauvegardé" or (RunService:IsStudio() and "Test Studio · session" or "Sauvegarde indisponible")}
	if not player.Parent then Data.save(player, true); Data.Profiles[player], Data.Sessions[player] = nil, nil; return nil end
	local stats = Instance.new("Folder")
	stats.Name, stats.Parent = "leaderstats", player
	for _, key in ipairs({"Niveau", "Pièces"}) do
		local value = Instance.new("IntValue")
		value.Name, value.Parent = key, stats
	end
	player:SetAttribute("ProfileReady", true)
	Data.sync(player)
	return Data.Profiles[player]
end
function Data.sync(player)
	local p, session = Data.Profiles[player], Data.Sessions[player]
	if not p or not player.Parent then return end
	player:SetAttribute("Level", p.Level)
	player:SetAttribute("CombatStyle", p.Style)
	player:SetAttribute("ObservationUnlocked", p.Observation)
	player:SetAttribute("ArmamentUnlocked", p.Armament)
	player:SetAttribute("HasFruit", p.Fruit)
	if player:FindFirstChild("leaderstats") then
		player.leaderstats["Niveau"].Value = p.Level
		player.leaderstats["Pièces"].Value = p.Coins
	end
	local snapshot = copy(p)
	snapshot.NextXP, snapshot.SaveStatus = Rules.xpNeeded(p.Level), session.Mode
	Data.Remotes.State:FireClient(player, snapshot)
end
function Data.notify(player, message)
	if player.Parent then Data.Remotes.Notify:FireClient(player, message) end
end
function Data.reward(player, xp, coins)
	local p = Data.Profiles[player]
	if not p then return end
	local oldLevel = p.Level
	p.Level, p.XP = Rules.addXP(p.Level, p.XP, xp, Config.MaxLevel)
	p.Coins += coins
	if p.Level > oldLevel then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.MaxHealth = 100 + (p.Level - 1) * 6
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (p.Level - oldLevel) * 6)
		end
		Data.notify(player, "Niveau " .. p.Level .. " !")
	end
	Data.sync(player)
end
function Data.save(player, release)
	local session, profile = Data.Sessions[player], Data.Profiles[player]
	if not session or not session.Writable or not profile then return end
	if session.Saving then
		if not release then return end
		local deadline = os.clock() + 20
		while session.Saving and os.clock() < deadline do task.wait(0.1) end
		if session.Saving then return end
	end
	-- PlayerRemoving and BindToClose may both request a release.
	if not session.Writable then return end
	session.Saving = true
	local snapshot, conflict = copy(profile), false
	local success = false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:UpdateAsync("u_" .. player.UserId, function(old)
				if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Id ~= sessionId then conflict = true; return nil end
				return {Version = 1, Data = snapshot, Session = not release and {Id = sessionId, ExpiresAt = os.time() + 180} or nil}
			end)
		end)
		if ok and result then success = true; break end
		if conflict then break end
		if attempt < 3 then task.wait(attempt) end
	end
	session.Saving = false
	if conflict then
		session.Writable = false
		if player.Parent then player:Kick("La session de sauvegarde a changé. Reconnecte-toi pour protéger ta progression.") end
	elseif success then
		session.Mode, session.LastSuccess = "Sauvegardé", os.clock()
		if release then session.Writable = false end
	else session.Mode = "Sauvegarde en attente"; warn("[Data] Save failed for", player.UserId) end
	Data.sync(player)
end
function Data.start()
	Players.PlayerRemoving:Connect(function(player)
		Data.save(player, true)
		Data.Profiles[player], Data.Sessions[player] = nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(Data.Profiles) do task.spawn(Data.save, player, false) end
		end
	end)
	game:BindToClose(function()
		local remaining = 0
		for player in pairs(Data.Profiles) do
			remaining += 1
			task.spawn(function() Data.save(player, true); remaining -= 1 end)
		end
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end
return Data
