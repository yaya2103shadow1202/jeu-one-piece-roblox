local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("CombatRemotes") or Instance.new("Folder")
remotes.Name = "CombatRemotes"
remotes.Parent = ReplicatedStorage

local m1Remote = remotes:FindFirstChild("M1") or Instance.new("RemoteEvent")
m1Remote.Name = "M1"
m1Remote.Parent = remotes

local ATTACK_COOLDOWN = 0.28
local COMBO_RESET = 1.0
local DAMAGE = 7
local HITBOX_SIZE = Vector3.new(5, 5, 6)
local HITBOX_FORWARD = 3.5

local stateByPlayer = {}

local function getState(player)
	local state = stateByPlayer[player]
	if not state then
		state = { lastAttack = 0, combo = 0, lastComboTime = 0 }
		stateByPlayer[player] = state
	end
	return state
end

local function attack(player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end

	local now = os.clock()
	local state = getState(player)
	if now - state.lastAttack < ATTACK_COOLDOWN then return end

	if now - state.lastComboTime > COMBO_RESET then
		state.combo = 0
	end

	state.lastAttack = now
	state.lastComboTime = now
	state.combo = state.combo % 4 + 1

	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)
	local hitHumanoids = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model and model:FindFirstChild("HumanoidRootPart")

		if targetHumanoid and targetRoot and targetHumanoid.Health > 0 and not hitHumanoids[targetHumanoid] then
			hitHumanoids[targetHumanoid] = true
			targetHumanoid:TakeDamage(DAMAGE)

			if state.combo == 4 then
				local forward = root.CFrame.LookVector
				targetRoot.AssemblyLinearVelocity = Vector3.new(forward.X * 38, 16, forward.Z * 38)
			else
				local forward = root.CFrame.LookVector
				targetRoot.AssemblyLinearVelocity += Vector3.new(forward.X * 7, 1.5, forward.Z * 7)
			end
		end
	end
end

m1Remote.OnServerEvent:Connect(attack)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)
