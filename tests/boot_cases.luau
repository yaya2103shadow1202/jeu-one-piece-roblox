-- Execute the actual server bootstrap against success and failure fixtures.
-- Does not emulate Roblox rendering, replication or avatar APIs.
local count = 0
local function check(ok, message) assert(ok, message); count += 1 end
local function scenario(failure)
	local signal = {Connect = function() end}
	local attrs, scheduled, warned = {}, {}, {}
	local mt = {}
	function mt.__index(self, key)
		if key == "FindFirstChild" or key == "WaitForChild" then return function(s, n) return s.Children[n] end end
		if key == "GetFullName" then return function(s) return s.Name end end
		if key == "SetAttribute" then return function(_, k, v) attrs[k] = v end end
		return self.Children[key]
	end
	function mt.__newindex(self, key, value)
		rawset(self, key, value)
		if key == "Parent" then value.Children[self.Name] = self end
	end
	local function instance(name) return setmetatable({Name = name, Children = {}, OnServerEvent = signal}, mt) end
	local storage, scripts = instance("ReplicatedStorage"), instance("ServerScriptService")
	storage.Children.Shared = instance("Shared") -- stale folder must not be used
	storage.Children.ArchipelagoShared = instance("ArchipelagoShared")
	storage.ArchipelagoShared.Children.Config, storage.ArchipelagoShared.Children.Rules = {}, {}
	scripts.Children.Services = instance("Services")
	for _, name in ipairs({"Builders", "DataService", "WorldService", "CombatService", "NPCService", "ProgressionService"}) do scripts.Services.Children[name] = {} end
	local models, spawned = {}, 0
	local stranded = {LoadCharacterAsync = function() spawned += 1 end}
	local players = {CharacterAutoLoads = false, PlayerAdded = signal, PlayerRemoving = signal,
		GetPlayers = function() return failure and {stranded} or {} end}
	local fakeData = {Profiles = {}, init = function() end, start = function() end}
	models[scripts.Services.DataService] = fakeData
	models[scripts.Services.WorldService] = {load = function() if failure == "map" then error("map failure") end end}
	models[scripts.Services.CombatService] = {init = function() end}
	models[scripts.Services.NPCService] = {init = function() end}
	models[scripts.Services.ProgressionService] = {init = function() end}
	models[storage.ArchipelagoShared.Rules] = {}
	if failure == "missing" then scripts.Services.Children.WorldService = nil end
	if failure == "config" then storage.ArchipelagoShared.Children.Config = nil end
	local game = {GetService = function(_, name) return name == "Players" and players or storage end}
	local script = {Parent = scripts}
	local Instance = {new = function(class) return instance(class) end}
	local task = {spawn = function(fn, ...) table.insert(scheduled, {fn, ...}) end}
	local require = function(module)
		if failure == "module" then error("module failure") end
		assert(models[module], "unexpected module")
		return models[module]
	end
	local warn = function(message) table.insert(warned, message) end
	local print = function() end
	(function()
-- INSERT_BOOTSTRAP
	end)()
	if failure then
		check(attrs.GameBootStage == "Error" and attrs.GameBootError, "bootstrap error is replicated")
		check(players.CharacterAutoLoads == true, "failed startup restores character spawning")
		check(#warned == 1, "full startup error reaches Output")
		check(#scheduled == 1, "stranded player gets one fallback spawn")
		scheduled[1][1]()
		check(spawned == 1, "fallback calls character loading")
	else
		check(attrs.GameBootStage == "Ready" and not attrs.GameBootError, "successful startup reaches Ready")
		check(players.CharacterAutoLoads == false, "successful startup owns respawn lifecycle")
		check(storage.Children.GameRemotes and storage.GameRemotes.Children.Request, "game remotes are created")
	end
end
scenario(nil)
scenario("map")
scenario("module")
scenario("missing")
scenario("config")
print("PASS bootstrap:", count, "assertions")
