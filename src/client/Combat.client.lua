-- Combat client: M1 input, temporary guard, external animation hooks and HUD feedback.
-- Gameplay-critical validation stays on the server.

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

local animationCache = setmetatable({}, {__mode = "k"})

local function getAnimator(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function playExternalAnimation(character, animationName)
	local folder = ReplicatedStorage:FindFirstChild("CombatAnimations")
	local animation = folder and folder:FindFirstChild(animationName)
	if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
		return false
	end

	local animator = getAnimator(character)
	if not animator then
		return false
	end

	local characterCache = animationCache[character]
	if not characterCache then
		characterCache = {}
		animationCache[character] = characterCache
	end

	local key = animationName .. "|" .. animation.AnimationId
	local track = characterCache[key]
	if not track then
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		characterCache[key] = track
	end

	track:Stop(0.03)
	track:Play(0.05, 1, 1)
	return true
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

local function findHand(character, combo)
	if combo == 2 then
		return character:FindFirstChild("LeftHand", true) or character:FindFirstChild("Left Arm", true)
	end
	return character:FindFirstChild("RightHand", true) or character:FindFirstChild("Right Arm", true)
end

local function addHandTrail(character, combo)
	local hand = findHand(character, combo)
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, hand.Size.Y * 0.35, 0)
	a0.Parent = hand

	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -hand.Size.Y * 0.35, 0)
	a1.Parent = hand

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Lifetime = combo == 4 and 0.14 or 0.09
	trail.MinLength = 0.03
	trail.Color = ColorSequence.new(
		Color3.fromRGB(255, 238, 190),
		Color3.fromRGB(130, 205, 255)
	)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, combo == 4 and 1.2 or 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = hand

	Debris:AddItem(trail, 0.25)
	Debris:AddItem(a0, 0.25)
	Debris:AddItem(a1, 0.25)
end

local function makeAirSlash(character, combo)
	local root = character and character:FindFirstChild("HumanoidRootPart")
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
	part.Color = combo == 4 and Color3.fromRGB(255, 225, 150) or Color3.fromRGB(190, 225, 255)
	part.Transparency = 0.45
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.CFrame = facing * CFrame.new(0, 1.0, combo == 4 and -4.0 or -3.0)
	part.Parent = workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = combo == 4 and Vector3.new(4.0, 0.24, 3.2) or Vector3.new(2.7, 0.18, 2.2)
	mesh.Parent = part

	TweenService:Create(mesh, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = mesh.Scale * 1.45,
	}):Play()
	TweenService:Create(part, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()

	Debris:AddItem(part, 0.17)
end

local function playSwingVisual(character, combo)
	if not character then
		return
	end

	-- Body motion now comes from imported Animation objects, not procedural Motor6D posing.
	playExternalAnimation(character, "M1_" .. tostring(combo))
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

local function createDamageHUD()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("CombatHUD")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "DamagePanel"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(0.975, 0, 0.58, 0)
	frame.Size = UDim2.fromOffset(170, 82)
	frame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(220, 180, 95)
	stroke.Transparency = 0.2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 7)
	title.Size = UDim2.new(1, -20, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.Text = "DÉGÂTS"
	title.TextColor3 = Color3.fromRGB(224, 191, 112)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "Damage"
	damageLabel.BackgroundTransparency = 1
	damageLabel.Position = UDim2.fromOffset(10, 24)
	damageLabel.Size = UDim2.new(1, -20, 0, 36)
	damageLabel.Font = Enum.Font.GothamBlack
	damageLabel.Text = "0"
	damageLabel.TextColor3 = Color3.fromRGB(255, 248, 225)
	damageLabel.TextSize = 32
	damageLabel.TextXAlignment = Enum.TextXAlignment.Left
	damageLabel.Parent = frame

	local comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "Combo"
	comboLabel.BackgroundTransparency = 1
	comboLabel.Position = UDim2.fromOffset(10, 60)
	comboLabel.Size = UDim2.new(1, -20, 0, 16)
	comboLabel.Font = Enum.Font.GothamMedium
	comboLabel.Text = "1 COUP"
	comboLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	comboLabel.TextSize = 12
	comboLabel.TextXAlignment = Enum.TextXAlignment.Left
	comboLabel.Parent = frame

	return frame, damageLabel, comboLabel
end

local damageFrame, damageLabel, comboLabel = createDamageHUD()
local hudDamage = 0
local hudHits = 0
local lastHudHit = 0
local hudToken = 0

local function showDamageHUD(combo, hitCount, damageDone)
	if damageDone <= 0 or hitCount <= 0 then
		return
	end

	local now = os.clock()
	if now - lastHudHit > COMBO_RESET + 0.25 or (combo == 1 and hudHits > 0) then
		hudDamage = 0
		hudHits = 0
	end
	lastHudHit = now
	hudDamage += damageDone
	hudHits += hitCount
	hudToken += 1
	local token = hudToken

	damageLabel.Text = tostring(hudDamage)
	comboLabel.Text = hudHits == 1 and "1 COUP" or (tostring(hudHits) .. " COUPS")
	damageFrame.Visible = true
	damageFrame.BackgroundTransparency = 0.18
	damageLabel.TextTransparency = 0
	comboLabel.TextTransparency = 0

	local originalSize = damageFrame.Size
	damageFrame.Size = UDim2.fromOffset(160, 76)
	TweenService:Create(damageFrame, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = originalSize,
	}):Play()

	task.delay(1.35, function()
		if token ~= hudToken or not damageFrame.Parent then
			return
		end

		local fade = TweenService:Create(damageFrame, TweenInfo.new(0.25), {
			BackgroundTransparency = 1,
		})
		TweenService:Create(damageLabel, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		TweenService:Create(comboLabel, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		fade:Play()
		fade.Completed:Wait()
		if token == hudToken then
			damageFrame.Visible = false
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
	highlight.FillTransparency = 0.90
	highlight.OutlineTransparency = 0.30
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	guardHighlight = highlight

	local shield = Instance.new("Part")
	shield.Name = "LocalGuardShield"
	shield.Shape = Enum.PartType.Cylinder
	shield.Material = Enum.Material.Neon
	shield.Color = Color3.fromRGB(110, 195, 255)
	shield.Transparency = 0.82
	shield.Size = Vector3.new(0.10, 3.8, 3.8)
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
		Transparency = 0.91,
		Size = Vector3.new(0.10, 4.05, 4.05),
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

	-- Temporary guard input. This will be replaced by the Observation Haki QTE system.
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
	hudDamage = 0
	hudHits = 0
	damageFrame.Visible = false
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
			cameraImpact(blocked and 0.20 or (combo == 4 and 0.32 or 0.16), blocked and 0.07 or 0.09)
		end
	end
end)

feedbackRemote.OnClientEvent:Connect(function(combo, hitCount, blockedCount, damageDone)
	localCombo = combo or localCombo
	if (hitCount or 0) > 0 then
		showDamageHUD(combo or 1, hitCount or 0, damageDone or 0)
		cameraImpact(combo == 4 and 0.38 or 0.20, combo == 4 and 0.10 or 0.07)
	elseif (blockedCount or 0) > 0 then
		cameraImpact(0.14, 0.06)
	end
end)

print("[CombatClient] ready - external animation hooks + HUD damage counter")
