-- Server-authoritative M1 combat prototype.
-- The client only requests an attack direction; damage, combo state and hit detection stay on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local function getOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remotes = getOrCreate(ReplicatedStorage, "Folder", "CombatRemotes")
local m1Remote = getOrCreate(remotes, "RemoteEvent", "M1")
local feedbackRemote = getOrCreate(remotes, "RemoteEvent", "M1Feedback")

local ATTACK_COOLDOWN = 0.30
local COMBO_RESET = 1.10
local HITBOX_SIZE = Vector3.new(5.5, 5.5, 6)
local HITBOX_FORWARD = 3.0
local DAMAGE_BY_COMBO = {5, 5, 6, 9}

local stateByPlayer = {}

local function getState(player)
	local state = stateByPlayer[player]
	if state then
		return state
	end

	state = {
		lastAttack = 0,
		lastComboTime = 0,
		combo = 0,
	}
	stateByPlayer[player] = state
	return state
end

local function sanitizeDirection(root, requestedDirection)
	if typeof(requestedDirection) == "Vector3" then
		local flat = Vector3.new(requestedDirection.X, 0, requestedDirection.Z)
		if flat.Magnitude >= 0.05 and flat.Magnitude <= 1.5 then
			return flat.Unit
		end
	end

	local fallback = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if fallback.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return fallback.Unit
end

local function showHitEffect(model, targetPart, damage)
	local highlight = Instance.new("Highlight")
	highlight.Name = "M1HitFlash"
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	Debris:AddItem(highlight, 0.10)

	if not targetPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "M1DamageNumber"
	billboard.Size = UDim2.fromOffset(80, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = targetPart
	billboard.Parent = targetPart

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

local function applyKnockback(direction, targetRoot, combo)
	if not targetRoot or targetRoot.Anchored then
		return
	end

	local mass = targetRoot.AssemblyMass
	if combo == 4 then
		targetRoot:ApplyImpulse(Vector3.new(
			direction.X * mass * 38,
			mass * 14,
			direction.Z * mass * 38
		))
	else
		targetRoot:ApplyImpulse(Vector3.new(
			direction.X * mass * 4,
			mass,
			direction.Z * mass * 4
		))
	end
end

local function attack(player, requestedDirection)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local state = getState(player)
	if now - state.lastAttack < ATTACK_COOLDOWN then
		return
	end

	if now - state.lastComboTime > COMBO_RESET then
		state.combo = 0
	end

	state.lastAttack = now
	state.lastComboTime = now
	state.combo = (state.combo % 4) + 1

	local combo = state.combo
	local damage = DAMAGE_BY_COMBO[combo]
	local direction = sanitizeDirection(root, requestedDirection)
	local facing = CFrame.lookAt(root.Position, root.Position + direction)
	local hitboxCFrame = facing * CFrame.new(0, 0, -HITBOX_FORWARD)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)
	local alreadyHit = {}
	local hitCount = 0

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")

		if targetHumanoid
			and targetHumanoid ~= humanoid
			and targetHumanoid.Health > 0
			and not alreadyHit[targetHumanoid]
		then
			alreadyHit[targetHumanoid] = true
			hitCount += 1

			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local targetPart = targetRoot or model:FindFirstChild("Head")

			targetHumanoid:TakeDamage(damage)
			applyKnockback(direction, targetRoot, combo)
			showHitEffect(model, targetPart, damage)
		end
	end

	feedbackRemote:FireClient(player, combo, hitCount)
end

m1Remote.OnServerEvent:Connect(attack)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)

print("[CombatServer] ready")
