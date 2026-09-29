local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")
local feedbackRemote = remotes:WaitForChild("M1Feedback")

local ATTACK_COOLDOWN = 0.30
local COMBO_RESET = 1.10
local HITBOX_SIZE = Vector3.new(6, 6, 7)
local HITBOX_FORWARD = 3.4
local DAMAGE_BY_COMBO = {5, 5, 6, 9}

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

local function showHitEffect(model, targetRoot, damage, combo)
	local highlight = Instance.new("Highlight")
	highlight.Name = "M1HitFlash"
	highlight.FillTransparency = combo == 4 and 0.25 or 0.5
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	Debris:AddItem(highlight, 0.10)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "M1DamageNumber"
	billboard.Size = UDim2.fromOffset(90, 42)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = targetRoot
	billboard.Parent = targetRoot

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "-" .. tostring(damage)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard

	Debris:AddItem(billboard, 0.45)
end

local function applyKnockback(attackerRoot, targetRoot, combo)
	local forward = attackerRoot.CFrame.LookVector
	local mass = targetRoot.AssemblyMass

	if combo == 4 then
		targetRoot:ApplyImpulse(Vector3.new(
			forward.X * mass * 42,
			mass * 16,
			forward.Z * mass * 42
		))
	else
		targetRoot:ApplyImpulse(Vector3.new(
			forward.X * mass * 5,
			mass * 1.5,
			forward.Z * mass * 5
		))
	end
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

	local combo = state.combo
	local damage = DAMAGE_BY_COMBO[combo]

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD)
	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)
	local hitHumanoids = {}
	local hitCount = 0

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
			local offset = targetRoot.Position - root.Position
			local inFront = offset.Magnitude < 0.01
				or root.CFrame.LookVector:Dot(offset.Unit) > -0.15

			if inFront then
				hitHumanoids[targetHumanoid] = true
				hitCount += 1
				targetHumanoid:TakeDamage(damage)
				applyKnockback(root, targetRoot, combo)
				showHitEffect(model, targetRoot, damage, combo)
			end
		end
	end

	feedbackRemote:FireClient(player, combo, hitCount)
end

m1Remote.OnServerEvent:Connect(attack)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)
