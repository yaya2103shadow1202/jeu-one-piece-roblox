-- Server-authoritative combat prototype: M1 + guard.

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
local blockRemote = getOrCreate(remotes, "RemoteEvent", "BlockState")

local ATTACK_COOLDOWN = 0.30
local COMBO_RESET = 1.10
local HITBOX_SIZE = Vector3.new(5.5, 5.5, 6)
local HITBOX_FORWARD = 3.0
local DAMAGE_BY_COMBO = {5, 5, 6, 9}
local BLOCK_FRONT_DOT = 0.20

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
		blocking = false,
		blockStarted = 0,
	}
	stateByPlayer[player] = state
	return state
end

local function resetPlayerCombatState(player, character)
	local state = getState(player)
	state.blocking = false
	state.combo = 0
	state.lastAttack = 0
	state.lastComboTime = 0
	if character then
		character:SetAttribute("Blocking", false)
	end
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		resetPlayerCombatState(player, character)
	end)
	if player.Character then
		resetPlayerCombatState(player, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

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

local function showBlockEffect(model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "BlockFlash"
	highlight.FillColor = Color3.fromRGB(80, 150, 255)
	highlight.OutlineColor = Color3.fromRGB(190, 225, 255)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	Debris:AddItem(highlight, 0.12)
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

local function applyBlockRecoil(direction, targetRoot)
	if not targetRoot or targetRoot.Anchored then
		return
	end
	local mass = targetRoot.AssemblyMass
	targetRoot:ApplyImpulse(Vector3.new(
		direction.X * mass * 1.5,
		0,
		direction.Z * mass * 1.5
	))
end

local function isBlockingFrontally(targetPlayer, targetRoot, attackerRoot)
	if not targetPlayer or not targetRoot then
		return false
	end

	local targetState = getState(targetPlayer)
	if not targetState.blocking then
		return false
	end

	local toAttacker = attackerRoot.Position - targetRoot.Position
	local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if flat.Magnitude < 0.05 then
		return true
	end

	local targetLook = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
	if targetLook.Magnitude < 0.05 then
		return false
	end

	return targetLook.Unit:Dot(flat.Unit) >= BLOCK_FRONT_DOT
end

local function setBlockState(player, requestedState)
	if typeof(requestedState) ~= "boolean" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		requestedState = false
	end

	local state = getState(player)
	state.blocking = requestedState
	if requestedState then
		state.blockStarted = os.clock()
	end

	if character then
		character:SetAttribute("Blocking", requestedState)
	end
end

local function attack(player, requestedDirection)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local state = getState(player)
	if state.blocking then
		return
	end

	local now = os.clock()
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
	local blockedCount = 0

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")

		if targetHumanoid
			and targetHumanoid ~= humanoid
			and targetHumanoid.Health > 0
			and not alreadyHit[targetHumanoid]
		then
			alreadyHit[targetHumanoid] = true

			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local targetPart = targetRoot or model:FindFirstChild("Head")
			local targetPlayer = Players:GetPlayerFromCharacter(model)

			if isBlockingFrontally(targetPlayer, targetRoot, root) then
				blockedCount += 1
				showBlockEffect(model)
				applyBlockRecoil(direction, targetRoot)
			else
				hitCount += 1
				targetHumanoid:TakeDamage(damage)
				applyKnockback(direction, targetRoot, combo)
				showHitEffect(model, targetPart, damage)
			end
		end
	end

	feedbackRemote:FireClient(player, combo, hitCount, blockedCount)
end

m1Remote.OnServerEvent:Connect(attack)
blockRemote.OnServerEvent:Connect(setBlockState)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)

print("[CombatServer] ready")
