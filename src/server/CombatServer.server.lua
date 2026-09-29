local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")

local ATTACK_COOLDOWN = 0.28
local COMBO_RESET = 1.0
local DAMAGE = 7
local HITBOX_SIZE = Vector3.new(6, 6, 7)
local HITBOX_FORWARD = 3.5

local stateByPlayer = {}

local function getState(player)
	local state = stateByPlayer[player]
	if not state then
		state = {
			lastAttack = 0,
			combo = 0,
			lastComboTime = 0,
		}
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
	state.combo = (state.combo % 4) + 1

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD)
	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)
	local hitHumanoids = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		local targetRoot = model and model:FindFirstChild("HumanoidRootPart")

		if targetHumanoid
			and targetRoot
			and targetHumanoid ~= humanoid
			and targetHumanoid.Health > 0
			and not hitHumanoids[targetHumanoid]
		then
			hitHumanoids[targetHumanoid] = true
			targetHumanoid:TakeDamage(DAMAGE)

			local forward = root.CFrame.LookVector
			if state.combo == 4 then
				targetRoot.AssemblyLinearVelocity = Vector3.new(
					forward.X * 42,
					18,
					forward.Z * 42
				)
			else
				targetRoot.AssemblyLinearVelocity += Vector3.new(
					forward.X * 8,
					2,
					forward.Z * 8
				)
			end
		end
	end
end

m1Remote.OnServerEvent:Connect(attack)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)
