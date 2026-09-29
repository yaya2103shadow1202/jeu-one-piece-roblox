-- Real DataService load/save/reward code, with storage and scheduling mocked.
-- This verifies ownership/error paths, not Roblox DataStore availability or timing.
local count = 0
local function check(ok, message) assert(ok, message); count += 1 end
local function clone(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = clone(v) end
	return out
end
local records, calls, failures, studio, onWait = {}, 0, false, false, nil
local fakeStore = {}
function fakeStore:UpdateAsync(key, callback)
	calls += 1
	if failures then error("simulated storage outage") end
	local result = callback(clone(records[key]))
	if result ~= nil then records[key] = clone(result) end
	return clone(result)
end
local services = {
	Players = {}, ReplicatedStorage = {},
	DataStoreService = {GetDataStore = function() return fakeStore end},
	RunService = {IsStudio = function() return studio end},
	HttpService = {GenerateGUID = function() return "test-guid" end},
}
local game = {JobId = "test-server"}
function game:GetService(name) return services[name] end
local Instance = {new = function() return {} end}
local task = {wait = function() if onWait then onWait() end end}
local warn = function() end
local function newService()
	local result = (function()
-- INSERT_DATA_SERVICE
	end)()
	-- UI replication is outside this test; all load/save logic remains unchanged.
	result.sync = function() end
	result.notify = function() end
	result.init({})
	return result
end
local function newPlayer(id)
	local player = {UserId = id, Parent = true, Attributes = {}}
	function player:SetAttribute(key, value) self.Attributes[key] = value end
	function player:Kick(reason) self.Kicked = reason end
	return player
end

local data, player = newService(), newPlayer(1)
local profile = data.load(player)
check(profile.Level == 1 and profile.XP == 0 and profile.Owned.Fists, "new profile defaults")
check(records.u_1.Session.Id == "test-server" and data.Sessions[player].Writable, "live load acquires ownership")
profile.Coins, profile.XP, profile.Owned.Sword = 180, 22, true
data.save(player, false)
check(records.u_1.Data.Coins == 180 and records.u_1.Data.Owned.Sword, "save persists earned progression")
profile.Coins = 200
check(records.u_1.Data.Coins == 180, "saved snapshot is isolated from later mutations")
data.save(player, true)
check(records.u_1.Session == nil and records.u_1.Data.Coins == 200, "release saves and removes lock")
local before = calls
data.save(player, true)
check(calls == before and not player.Kicked, "duplicate release is harmless")

local rejoined = newPlayer(1)
data = newService()
profile = data.load(rejoined)
check(profile.XP == 22 and profile.Coins == 200 and profile.Owned.Sword, "rejoin restores progression")
records.u_1.Session = {Id = "other-server", ExpiresAt = os.time() + 180}
profile.Coins = 999
data.save(rejoined, false)
check(records.u_1.Data.Coins == 200 and rejoined.Kicked and not data.Sessions[rejoined].Writable, "lost ownership cannot overwrite data")

local blocked, competitor = newService(), newPlayer(1)
check(blocked.load(competitor) == nil and competitor.Kicked, "active foreign session refuses login")
check(blocked.Profiles[competitor] == nil and records.u_1.Session.Id == "other-server", "blocked load leaves saved profile untouched")

failures = true
local offline, offlinePlayer = newService(), newPlayer(1)
local offlineProfile = offline.load(offlinePlayer)
check(offlineProfile and not offline.Sessions[offlinePlayer].Writable, "failed load enters non-writable session")
check(offline.Sessions[offlinePlayer].Mode == "Sauvegarde indisponible", "storage failure is reported")
before = calls
offlineProfile.Coins = 456
offline.save(offlinePlayer, true)
check(calls == before and records.u_1.Data.Coins == 200, "failed load never writes a replacement profile")
failures = false

records.u_1.Session.ExpiresAt = os.time() - 1
local recovered, returning = newService(), newPlayer(1)
check(recovered.load(returning).Coins == 200, "expired lock can be recovered without losing data")
local session = recovered.Sessions[returning]
session.Saving = true
onWait = function() session.Saving = false; session.Writable = false end
before = calls
recovered.save(returning, true)
onWait = nil
check(calls == before, "release waiting on another release rechecks write ownership")

studio = true
local testing, tester = newService(), newPlayer(2)
before = calls
local testProfile = testing.load(tester)
testProfile.Coins = 1000
testing.save(tester, true)
check(calls == before and records.u_2 == nil, "Studio never accesses live storage")
check(testing.Sessions[tester].Mode == "Test Studio · session", "Studio save status is explicit")
local deadHumanoid = {Health = 0, MaxHealth = 100}
tester.Character = {FindFirstChildOfClass = function() return deadHumanoid end}
testing.reward(tester, 200, 0)
check(testProfile.Level > 1 and deadHumanoid.Health == 0, "level-up reward cannot revive a dead character")
print("PASS DataService:", count, "assertions")
