-- Server-authoritative combat prototype: M1 + temporary guard + replicated impact FX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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
local fxRemote = getOrCreate(remotes, "RemoteEvent", "CombatFX")

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

local function makeShockwave(position, combo, blocked)
	local part = Instance.new("Part")
	part.Name = blocked and "BlockShockwave" or "HitShockwave"
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

local function showBlockEffect(model, targetRoot)
	local highlight = Instance.new("Highlight")
	highlight.Name = "BlockFlash"
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

	fxRemote:FireAllClients("Swing", player.UserId, combo, false)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local parts = workspace:GetPartBoundsInBox(hitboxCFrame, HITBOX_SIZE, params)
	local alreadyHit = {}
	local hitCount = 0
	local blockedCount = 0
	local damageDone = 0

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
				showBlockEffect(model, targetRoot)
				applyBlockRecoil(direction, targetRoot)
				fxRemote:FireAllClients("Impact", targetPlayer and targetPlayer.UserId or 0, combo, true)
			else
				hitCount += 1
				damageDone += damage
				targetHumanoid:TakeDamage(damage)
				applyKnockback(direction, targetRoot, combo)
				showHitEffect(model, targetPart, combo)
				fxRemote:FireAllClients("Impact", targetPlayer and targetPlayer.UserId or 0, combo, false)
			end
		end
	end

	feedbackRemote:FireClient(player, combo, hitCount, blockedCount, damageDone)
end

m1Remote.OnServerEvent:Connect(attack)
blockRemote.OnServerEvent:Connect(setBlockState)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)

print("[CombatServer] ready - HUD damage feedback enabled")
