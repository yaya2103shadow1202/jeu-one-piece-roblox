-- One ordered bootstrap. Services share combat/progression instead of duplicating damage code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Services = script.Parent.Services
local Data = require(Services.DataService)
local World = require(Services.WorldService)
local Combat = require(Services.CombatService)
local NPC = require(Services.NPCService)
local Progression = require(Services.ProgressionService)
local Rules = require(ReplicatedStorage.Shared.Rules)

Players.CharacterAutoLoads = false
local function folder(name)
	local old = ReplicatedStorage:FindFirstChild(name)
	if old then return old end
	local instance = Instance.new("Folder")
	instance.Name, instance.Parent = name, ReplicatedStorage
	return instance
end
local combatFolder, gameFolder = folder("CombatRemotes"), folder("GameRemotes")
local remotes = {}
for name, parent in pairs({M1 = combatFolder, M1Feedback = combatFolder, Observation = combatFolder, CombatFX = combatFolder,
	Request = gameFolder, State = gameFolder, Notify = gameFolder, Dialogue = gameFolder}) do
	local remote = parent:FindFirstChild(name) or Instance.new("RemoteEvent")
	remote.Name, remote.Parent = name, parent
	remotes[name] = remote
end
-- Container for licensed/custom clips; missing clips never block gameplay.
folder("CombatAnimations")
Data.init(remotes)
World.build()
Combat.init(Data, World, remotes)
Progression.init(Data, World, remotes)
Data.start()

local function loadCharacter(player)
	if not player.Parent then return end
	local ok, err = pcall(function() player:LoadCharacterAsync() end)
	if not ok then warn("[Game] Character load failed:", err) end
end
local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local profile = Data.Profiles[player]
	if not humanoid or not root or not profile or player.Character ~= character then return end
	humanoid.MaxHealth = 100 + (profile.Level - 1) * 6
	humanoid.Health = humanoid.MaxHealth
	character:PivotTo((World.Hubs[profile.LastIsland] or World.Hubs.Port).Spawn)
	Combat.character(player, character)
	Data.sync(player)
	humanoid.Died:Once(function()
		task.delay(Players.RespawnTime, function()
			if player.Character == character then loadCharacter(player) end
		end)
	end)
end
local loaded = {}
local function setupPlayer(player)
	if loaded[player] then return end
	loaded[player] = true
	local profile = Data.load(player)
	if not profile then return end
	player:SetAttribute("PvPEnabled", false)
	player.CharacterAdded:Connect(function(character) setupCharacter(player, character) end)
	if player.Character then setupCharacter(player, player.Character) else loadCharacter(player) end
end
Players.PlayerAdded:Connect(function(player) task.spawn(setupPlayer, player) end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(setupPlayer, player) end

local lastRequest, lastRescue = {}, {}
Players.PlayerRemoving:Connect(function(player)
	loaded[player], lastRequest[player], lastRescue[player] = nil, nil, nil
end)
remotes.Request.OnServerEvent:Connect(function(player, action, value, extra)
	if type(action) ~= "string" or not Data.Profiles[player] then return end
	local t = os.clock()
	if t - (lastRequest[player] or -1) < 0.1 then return end
	lastRequest[player] = t
	local p = Data.Profiles[player]
	if action == "State" then Data.sync(player)
	elseif action == "AcceptQuest" or action == "TurnInQuest" or action == "AbandonQuest" then Progression.quest(player, action, value)
	elseif action == "Travel" and type(value) == "string" and type(extra) == "string" then Progression.travel(player, value, extra)
	elseif action == "Equip" then Combat.equip(player, value)
	elseif action == "Armament" then Combat.armament(player, value)
	elseif action == "Reload" then Combat.reload(player)
	elseif action == "ConsumeFruit" then Progression.fruit(player)
	elseif action == "Technique" and p.Fruit then
		local technique = Rules.validateTechnique(value)
		if technique then p.Technique = technique; Data.sync(player); Data.notify(player, "Technique enregistrée. [Z] pour l'utiliser.") end
	elseif action == "Cast" then Combat.fruit(player, value)
	elseif action == "PvP" and type(value) == "boolean" then
		if (player:GetAttribute("InCombatUntil") or 0) > workspace:GetServerTimeNow() then Data.notify(player, "Termine le combat avant de changer le PvP."); return end
		player:SetAttribute("PvPEnabled", value)
		Data.notify(player, value and "PvP activé hors des zones sûres." or "PvP désactivé.")
	end
end)

-- Sea rescue for this first archipelago: ferries are the supported sea travel.
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, profile in pairs(Data.Profiles) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and root.Position.Y < -8 and os.clock() - (lastRescue[player] or -5) > 3 then
				lastRescue[player] = os.clock()
				local hub = World.Hubs[profile.LastIsland] or World.Hubs.Port
				character:PivotTo(hub.Spawn)
				root.AssemblyLinearVelocity = Vector3.zero
				humanoid:TakeDamage(humanoid.MaxHealth * (profile.Fruit and 0.4 or 0.15))
				Data.notify(player, profile.Fruit and "La mer affaiblit ton fruit. Le passeur t'a ramené au port." or "Repêché ! Utilise le passeur au bout de la jetée.")
			end
		end
	end
end)
task.spawn(function() NPC.init(World, Combat, Progression) end)
print("[Archipelago] Four islands, progression, quests and combat ready")
