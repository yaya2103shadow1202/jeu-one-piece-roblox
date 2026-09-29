-- Combat client: M1, guard and lightweight anime-style presentation.
-- Damage and hit validation stay on the server. This file only handles input and visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local M1_COOLDOWN = 0.30
local COMBO_RESET = 1.10

local ready = true
local blocking = false
local localCombo = 0
local lastLocalAttack = 0
local guardHighlight
local guardShield
local guardTween

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")
local feedbackRemote = remotes:WaitForChild("M1Feedback")
local blockRemote = remotes:WaitForChild("BlockState")
local fxRemote = remotes:WaitForChild("CombatFX")

local swingState = {}
local rigCache = setmetatable({}, {__mode = "k"})

local function findMotor(character, ...)
	for _, name in ipairs({...}) do
		local item = character:FindFirstChild(name, true)
		if item and item:IsA("Motor6D") then
			return item
		end
	end
	return nil
end

local function getRig(character)
	local cached = rigCache[character]
	if cached then
		return cached
	end

	local rig = {
		rightShoulder = findMotor(character, "RightShoulder", "Right Shoulder"),
		leftShoulder = findMotor(character, "LeftShoulder", "Left Shoulder"),
		waist = findMotor(character, "Waist"),
		rootJoint = findMotor(character, "RootJoint"),
		rightHand = character:FindFirstChild("RightHand", true) or character:FindFirstChild("Right Arm", true),
		leftHand = character:FindFirstChild("LeftHand", true) or character:FindFirstChild("Left Arm", true),
	}

	rigCache[character] = rig
	return rig
end

local function getFlatCameraLook(root)
	local camera = workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function smoothAttackAlpha(progress)
	if progress <= 0 then return 0 end
	if progress >= 1 then return 0 end

	local alpha
	if progress < 0.34 then
		alpha = progress / 0.34
	else
		alpha = 1 - ((progress - 0.34) / 0.66)
	end
	return math.sin(math.clamp(alpha, 0, 1) * math.pi * 0.5)
end

local function applyMotorOverlay(motor, overlay)
	if motor then
		motor.Transform = motor.Transform * overlay
	end
end

local function applySwingPose(character, combo, alpha)
	local rig = getRig(character)
	local r = math.rad

	if combo == 1 then
		applyMotorOverlay(rig.rightShoulder, CFrame.Angles(r(-68 * alpha), r(8 * alpha), r(-18 * alpha)))
		applyMotorOverlay(rig.leftShoulder, CFrame.Angles(r(10 * alpha), 0, r(8 * alpha)))
		applyMotorOverlay(rig.waist, CFrame.Angles(0, r(-11 * alpha), 0))
	elseif combo == 2 then
		applyMotorOverlay(rig.leftShoulder, CFrame.Angles(r(-70 * alpha), r(-8 * alpha), r(18 * alpha)))
		applyMotorOverlay(rig.rightShoulder, CFrame.Angles(r(10 * alpha), 0, r(-8 * alpha)))
		applyMotorOverlay(rig.waist, CFrame.Angles(0, r(12 * alpha), 0))
	elseif combo == 3 then
		applyMotorOverlay(rig.rightShoulder, CFrame.Angles(r(-28 * alpha), r(-42 * alpha), r(-74 * alpha)))
		applyMotorOverlay(rig.leftShoulder, CFrame.Angles(r(8 * alpha), 0, r(12 * alpha)))
		applyMotorOverlay(rig.waist, CFrame.Angles(0, r(-20 * alpha), r(-3 * alpha)))
	else
		applyMotorOverlay(rig.rightShoulder, CFrame.Angles(r(-102 * alpha), r(4 * alpha), r(-28 * alpha)))
		applyMotorOverlay(rig.leftShoulder, CFrame.Angles(r(-20 * alpha), 0, r(18 * alpha)))
		applyMotorOverlay(rig.waist, CFrame.Angles(r(12 * alpha), r(-25 * alpha), 0))
		applyMotorOverlay(rig.rootJoint, CFrame.Angles(r(5 * alpha), 0, 0))
	end
end

local function applyBlockPose(character)
	local rig = getRig(character)
	local r = math.rad
	applyMotorOverlay(rig.rightShoulder, CFrame.Angles(r(-38), r(-8), r(-34)))
	applyMotorOverlay(rig.leftShoulder, CFrame.Angles(r(-38), r(8), r(34)))
	applyMotorOverlay(rig.waist, CFrame.Angles(r(-5), 0, 0))
end

RunService.PreSimulation:Connect(function()
	local now = os.clock()

	for character, state in pairs(swingState) do
		if not character.Parent then
			swingState[character] = nil
		else
			local progress = (now - state.started) / state.duration
			if progress >= 1 then
				swingState[character] = nil
			else
				applySwingPose(character, state.combo, smoothAttackAlpha(progress))
			end
		end
	end

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local character = otherPlayer.Character
		if character and character:GetAttribute("Blocking") == true then
			applyBlockPose(character)
		end
	end
end)

local function addHandTrail(character, combo)
	local rig = getRig(character)
	local hand = (combo == 2) and rig.leftHand or rig.rightHand
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local a0 = Instance.new("Attachment")
	a0.Name = "CombatTrailA"
	a0.Position = Vector3.new(0, hand.Size.Y * 0.35, 0)
	a0.Parent = hand

	local a1 = Instance.new("Attachment")
	a1.Name = "CombatTrailB"
	a1.Position = Vector3.new(0, -hand.Size.Y * 0.35, 0)
	a1.Parent = hand

	local trail = Instance.new("Trail")
	trail.Name = "CombatHandTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Lifetime = combo == 4 and 0.14 or 0.09
	trail.MinLength = 0.03
	trail.Color = ColorSequence.new(
		Color3.fromRGB(255, 245, 205),
		Color3.fromRGB(120, 205, 255)
	)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, combo == 4 and 1.35 or 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = hand

	Debris:AddItem(trail, 0.28)
	Debris:AddItem(a0, 0.28)
	Debris:AddItem(a1, 0.28)
end

local function makeAirSlash(character, combo)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	else
		direction = direction.Unit
	end

	local facing = CFrame.lookAt(root.Position, root.Position + direction)
	local part = Instance.new("Part")
	part.Name = "CombatAirSlash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = combo == 4 and Color3.fromRGB(255, 235, 165) or Color3.fromRGB(185, 225, 255)
	part.Transparency = 0.35
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.CFrame = facing * CFrame.new(0, 1.1, combo == 4 and -4.2 or -3.2)
	part.Parent = workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = combo == 4 and Vector3.new(4.5, 0.28, 3.6) or Vector3.new(3.0, 0.20, 2.5)
	mesh.Parent = part

	local meshTween = TweenService:Create(mesh, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = mesh.Scale * 1.55,
	})
	local fadeTween = TweenService:Create(part, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	})
	meshTween:Play()
	fadeTween:Play()
	Debris:AddItem(part, 0.18)
end

local function playSwingVisual(character, combo)
	if not character then
		return
	end

	swingState[character] = {
		combo = combo,
		started = os.clock(),
		duration = combo == 4 and 0.34 or 0.26,
	}
	addHandTrail(character, combo)
	makeAirSlash(character, combo)
end

local function cameraImpact(strength, duration)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	task.spawn(function()
		local started = os.clock()
		local original = humanoid.CameraOffset
		while os.clock() - started < duration and humanoid.Parent do
			local remaining = 1 - ((os.clock() - started) / duration)
			humanoid.CameraOffset = original + Vector3.new(
				(math.random() - 0.5) * strength * remaining,
				(math.random() - 0.5) * strength * remaining,
				0
			)
			RunService.RenderStepped:Wait()
		end
		if humanoid.Parent then
			humanoid.CameraOffset = original
		end
	end)
end

local function destroyGuardVisual()
	if guardTween then
		guardTween:Cancel()
		guardTween = nil
	end
	if guardHighlight then
		guardHighlight:Destroy()
		guardHighlight = nil
	end
	if guardShield then
		guardShield:Destroy()
		guardShield = nil
	end
end

local function setLocalGuardVisual(enabled)
	destroyGuardVisual()
	if not enabled then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalGuardHighlight"
	highlight.FillColor = Color3.fromRGB(55, 125, 220)
	highlight.OutlineColor = Color3.fromRGB(190, 230, 255)
	highlight.FillTransparency = 0.88
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	guardHighlight = highlight

	local shield = Instance.new("Part")
	shield.Name = "LocalGuardShield"
	shield.Shape = Enum.PartType.Cylinder
	shield.Material = Enum.Material.Neon
	shield.Color = Color3.fromRGB(110, 195, 255)
	shield.Transparency = 0.78
	shield.Size = Vector3.new(0.12, 4.0, 4.0)
	shield.CanCollide = false
	shield.CanQuery = false
	shield.CanTouch = false
	shield.Massless = true
	shield.CFrame = root.CFrame * CFrame.new(0, 0.8, -2.0)
	shield.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shield
	weld.Parent = shield

	guardShield = shield
	guardTween = TweenService:Create(shield, TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.9,
		Size = Vector3.new(0.12, 4.35, 4.35),
	})
	guardTween:Play()
end

local function setBlocking(enabled)
	if blocking == enabled then
		return
	end

	blocking = enabled
	setLocalGuardVisual(enabled)
	blockRemote:FireServer(enabled)
end

local function predictCombo()
	local now = os.clock()
	if now - lastLocalAttack > COMBO_RESET then
		localCombo = 0
	end
	lastLocalAttack = now
	localCombo = (localCombo % 4) + 1
	return localCombo
end

local function attack()
	if not ready or blocking then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	ready = false
	local combo = predictCombo()
	local direction = getFlatCameraLook(root)
	playSwingVisual(character, combo)
	m1Remote:FireServer(direction)

	task.delay(M1_COOLDOWN, function()
		ready = true
	end)
end

mouse.Button1Down:Connect(attack)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		setBlocking(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		setBlocking(false)
	end
end)

player.CharacterAdded:Connect(function()
	blocking = false
	ready = true
	localCombo = 0
	lastLocalAttack = 0
	destroyGuardVisual()
	blockRemote:FireServer(false)
end)

local function findPlayerByUserId(userId)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer.UserId == userId then
			return otherPlayer
		end
	end
	return nil
end

fxRemote.OnClientEvent:Connect(function(action, userId, combo, extra)
	if action == "Swing" then
		if userId == player.UserId then
			return
		end
		local attacker = findPlayerByUserId(userId)
		if attacker and attacker.Character then
			playSwingVisual(attacker.Character, combo)
		end
	elseif action == "Impact" then
		local blocked = extra == true
		if userId == player.UserId then
			cameraImpact(blocked and 0.22 or (combo == 4 and 0.34 or 0.18), blocked and 0.07 or 0.09)
		end
	end
end)

feedbackRemote.OnClientEvent:Connect(function(combo, hitCount, blockedCount)
	localCombo = combo or localCombo
	if (hitCount or 0) > 0 then
		cameraImpact(combo == 4 and 0.42 or 0.24, combo == 4 and 0.11 or 0.075)
	elseif (blockedCount or 0) > 0 then
		cameraImpact(0.16, 0.06)
	end
end)

print("[CombatClient] ready - stylized combat FX enabled")
