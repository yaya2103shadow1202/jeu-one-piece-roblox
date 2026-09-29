-- Server-authoritative combat prototype: M1 + Observation dodge + replicated impact FX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local observationRemote = getOrCreate(remotes, "RemoteEvent", "Observation")
local fxRemote = getOrCreate(remotes, "RemoteEvent", "CombatFX")

local ATTACK_COOLDOWN = 0.52
local COMBO_RESET = 1.10
local HITBOX_SIZE = Vector3.new(5.5, 5.5, 6)
local HITBOX_FORWARD = 3.0
local DAMAGE_BY_COMBO = {5, 5, 6, 9}
local WINDUP = 0.46
-- The prompt is visible for 0.25s; the remaining 0.12s lets the input reach the server.
local OBSERVATION_WINDOW = 0.37
local OBSERVATION_CHARGES = 3
local OBSERVATION_RECHARGE = 7
local OBSERVATION_INPUT_COOLDOWN = 0.18
local nextAttackId = 0

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
		charges = OBSERVATION_CHARGES,
		rechargeAt = 0,
		lastObservationInput = 0,
		pending = {},
	}
	stateByPlayer[player] = state
	return state
end

local function resetPlayerCombatState(player, character)
	local state = getState(player)
	state.charges = OBSERVATION_CHARGES
	state.rechargeAt = 0
	state.lastObservationInput = 0
	state.pending = {}
	state.combo = 0
	state.lastAttack = 0
	state.lastComboTime = 0
	if character then
		character:SetAttribute("ObservationCharges", state.charges)
	end
end

local function setupPlayer(player)
	-- The future quest will set this attribute from trusted server code.
	-- Studio access allows the mechanic to be tested before progression exists.
	player:SetAttribute("ObservationUnlocked", RunService:IsStudio())
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

local function makeShockwave(position, combo, blocked)
	local part = Instance.new("Part")
	part.Name = blocked and "DodgeShockwave" or "HitShockwave"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = blocked and Color3.fromRGB(110, 195, 255)
		or (combo == 4 and Color3.fromRGB(255, 220, 130) or Color3.fromRGB(255, 245, 215))
	part.Transparency = blocked and 0.32 or 0.22
	part.Size = Vector3.new(0.65, 0.65, 0.65)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = blocked and Vector3.new(2.6, 2.6, 2.6)
		or (combo == 4 and Vector3.new(3.2, 3.2, 3.2) or Vector3.new(2.0, 2.0, 2.0))
	mesh.Parent = part

	TweenService:Create(mesh, TweenInfo.new(combo == 4 and 0.20 or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = mesh.Scale * (combo == 4 and 2.2 or 1.8),
	}):Play()
	TweenService:Create(part, TweenInfo.new(combo == 4 and 0.20 or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()

	Debris:AddItem(part, 0.24)
end

local function makeImpactStreaks(position, combo, blocked)
	local streakCount = combo == 4 and 7 or 4
	local length = combo == 4 and 3.6 or 2.2
	local color = blocked and Color3.fromRGB(120, 205, 255)
		or (combo == 4 and Color3.fromRGB(255, 220, 130) or Color3.fromRGB(255, 250, 225))

	for index = 1, streakCount do
		local angle = (math.pi * 2 / streakCount) * index
		local direction = Vector3.new(math.cos(angle), math.sin(angle), ((index % 2) - 0.5) * 0.7).Unit

		local streak = Instance.new("Part")
		streak.Name = "CombatImpactStreak"
		streak.Anchored = true
		streak.CanCollide = false
		streak.CanQuery = false
		streak.CanTouch = false
		streak.Material = Enum.Material.Neon
		streak.Color = color
		streak.Transparency = 0.12
		streak.Size = Vector3.new(0.10, 0.10, length)
		streak.CFrame = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -length * 0.25)
		streak.Parent = workspace

		TweenService:Create(streak, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(0.04, 0.04, length * 1.45),
			CFrame = streak.CFrame * CFrame.new(0, 0, -0.8),
		}):Play()
		Debris:AddItem(streak, 0.15)
	end
end

local function showHitEffect(model, targetPart, combo)
	local highlight = Instance.new("Highlight")
	highlight.Name = "M1HitFlash"
	highlight.FillColor = combo == 4 and Color3.fromRGB(255, 215, 125) or Color3.fromRGB(255, 245, 220)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = combo == 4 and 0.20 or 0.38
	highlight.OutlineTransparency = 0.18
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	Debris:AddItem(highlight, combo == 4 and 0.16 or 0.10)

	if targetPart then
		makeShockwave(targetPart.Position, combo, false)
		makeImpactStreaks(targetPart.Position, combo, false)
	end
end

local function showDodgeEffect(model, targetRoot)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ObservationFlash"
	highlight.FillColor = Color3.fromRGB(70, 155, 255)
	highlight.OutlineColor = Color3.fromRGB(210, 240, 255)
	highlight.FillTransparency = 0.36
	highlight.OutlineTransparency = 0.08
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	Debris:AddItem(highlight, 0.14)

	if targetRoot then
		local position = targetRoot.Position + Vector3.new(0, 1.0, 0)
		makeShockwave(position, 1, true)
		makeImpactStreaks(position, 1, true)
	end
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

local function refreshCharges(player, state, now)
	if state.charges >= OBSERVATION_CHARGES then
		return
	end
	while state.charges < OBSERVATION_CHARGES and now >= state.rechargeAt do
		state.charges += 1
		state.rechargeAt += OBSERVATION_RECHARGE
	end
	if player.Character then
		player.Character:SetAttribute("ObservationCharges", state.charges)
	end
end

local function observationInput(player, attackId)
	if typeof(attackId) ~= "number" or not player:GetAttribute("ObservationUnlocked") then
		return
	end
	local state = getState(player)
	local now = workspace:GetServerTimeNow()
	if now - state.lastObservationInput < OBSERVATION_INPUT_COOLDOWN then
		return
	end
	state.lastObservationInput = now
	refreshCharges(player, state, now)
	local pending = state.pending[attackId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not pending or pending.character ~= character or not humanoid or humanoid.Health <= 0
		or pending.dodged or state.charges <= 0
		or now < pending.deadline - OBSERVATION_WINDOW or now > pending.deadline then
		return
	end
	pending.dodged = true
	state.charges -= 1
	if state.charges == OBSERVATION_CHARGES - 1 then
		state.rechargeAt = now + OBSERVATION_RECHARGE
	end
	character:SetAttribute("ObservationCharges", state.charges)
	observationRemote:FireClient(player, "Success", attackId, state.charges)
end

observationRemote.OnServerEvent:Connect(observationInput)

task.spawn(function()
	while true do
		task.wait(0.25)
		local now = workspace:GetServerTimeNow()
		for player, state in pairs(stateByPlayer) do
			if player.Parent then refreshCharges(player, state, now) end
		end
	end
end)

local function attack(player, requestedDirection)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local state = getState(player)
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
	fxRemote:FireAllClients("Swing", player.UserId, combo, false)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	local function candidates()
		local facing = CFrame.lookAt(root.Position, root.Position + direction)
		local hitboxCFrame = facing * CFrame.new(0, 0, -HITBOX_FORWARD)
		local found = {}
		for _, part in ipairs(workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)) do
			local model = part:FindFirstAncestorOfClass("Model")
			local target = model and model:FindFirstChildOfClass("Humanoid")
			if target and target ~= humanoid and target.Health > 0 then
				found[target] = model
			end
		end
		return found
	end

	nextAttackId += 1
	local attackId = nextAttackId
	local deadline = workspace:GetServerTimeNow() + WINDUP
	local warned = {}
	for _, model in pairs(candidates()) do
		local targetPlayer = Players:GetPlayerFromCharacter(model)
		if targetPlayer and targetPlayer:GetAttribute("ObservationUnlocked") then
			local targetState = getState(targetPlayer)
			refreshCharges(targetPlayer, targetState, workspace:GetServerTimeNow())
			if targetState.charges > 0 then
				targetState.pending[attackId] = {deadline = deadline, character = model, dodged = false}
				warned[targetPlayer] = true
				observationRemote:FireClient(targetPlayer, "Warning", attackId, deadline, targetState.charges)
			end
		end
	end

	task.wait(WINDUP)
	for targetPlayer in pairs(warned) do
		local targetState = stateByPlayer[targetPlayer]
		if targetState then
			refreshCharges(targetPlayer, targetState, workspace:GetServerTimeNow())
		end
	end
	if player.Character ~= character or humanoid.Health <= 0 or not root.Parent then
		for targetPlayer in pairs(warned) do
			local targetState = stateByPlayer[targetPlayer]
			if targetState then targetState.pending[attackId] = nil end
		end
		return
	end

	local targets = candidates()
	local hitCount = 0
	local dodgedCount = 0
	local damageDone = 0

	for targetHumanoid, model in pairs(targets) do
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local targetPart = targetRoot or model:FindFirstChild("Head")
			local targetPlayer = Players:GetPlayerFromCharacter(model)
			local targetState = targetPlayer and stateByPlayer[targetPlayer]
			local pending = targetState and targetState.pending[attackId]
			if pending and pending.character == model and pending.dodged then
				dodgedCount += 1
				showDodgeEffect(model, targetRoot)
				if targetRoot and not targetRoot.Anchored then
					local side = Vector3.new(-direction.Z, 0, direction.X)
					targetRoot:ApplyImpulse(side * targetRoot.AssemblyMass * 28)
				end
				fxRemote:FireAllClients("Impact", targetPlayer.UserId, combo, true)
			else
				hitCount += 1
				damageDone += damage
				targetHumanoid:TakeDamage(damage)
				applyKnockback(direction, targetRoot, combo)
				showHitEffect(model, targetPart, combo)
				fxRemote:FireAllClients("Impact", targetPlayer and targetPlayer.UserId or 0, combo, false)
			end
	end
	for targetPlayer in pairs(warned) do
		local targetState = stateByPlayer[targetPlayer]
		if targetState then targetState.pending[attackId] = nil end
	end

	feedbackRemote:FireClient(player, combo, hitCount, dodgedCount, damageDone)
end

m1Remote.OnServerEvent:Connect(attack)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)

print("[CombatServer] ready - HUD damage feedback enabled")
