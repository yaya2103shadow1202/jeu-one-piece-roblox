-- Prototype movement + combat input controller
-- Third-person combat movement: sprint, ground dash, one air dash and M1 input.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local WALK_SPEED = 16
local SPRINT_SPEED = 25
local DASH_SPEED = 70
local DASH_DURATION = 0.16
local DASH_COOLDOWN = 0.55
local AIR_DASH_SPEED = 62
local M1_COOLDOWN = 0.30

local character
local humanoid
local root
local sprinting = false
local dashReady = true
local airDashAvailable = true
local m1Ready = true

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 7
player.CameraMaxZoomDistance = 26

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")
local feedbackRemote = remotes:WaitForChild("M1Feedback")

local function setupCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = WALK_SPEED
	airDashAvailable = true
	m1Ready = true
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local function horizontalCameraVectors()
	local camera = workspace.CurrentCamera
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit

	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if right.Magnitude < 0.01 then
		right = Vector3.new(1, 0, 0)
	end
	return look, right.Unit
end

local function inputDirection()
	if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
		return humanoid.MoveDirection.Unit
	end

	local look = horizontalCameraVectors()
	return look
end

local function dash()
	if not humanoid or not root or humanoid.Health <= 0 or not dashReady then return end

	local state = humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	if airborne and not airDashAvailable then return end

	dashReady = false
	if airborne then
		airDashAvailable = false
	end

	local direction = inputDirection()
	local speed = airborne and AIR_DASH_SPEED or DASH_SPEED
	local started = os.clock()

	while os.clock() - started < DASH_DURATION and root and root.Parent do
		local y = root.AssemblyLinearVelocity.Y
		if airborne then
			y = math.min(y, 4)
		end
		root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, y, direction.Z * speed)
		RunService.Heartbeat:Wait()
	end

	task.delay(DASH_COOLDOWN, function()
		dashReady = true
	end)
end

local function makeFlash(cframe, size, lifetime)
	local part = Instance.new("Part")
	part.Name = "M1DebugFlash"
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.65
	part.Parent = workspace
	Debris:AddItem(part, lifetime)
end

local function attack()
	if not m1Ready or not humanoid or humanoid.Health <= 0 or not root then return end
	m1Ready = false

	local cameraLook = horizontalCameraVectors()
	local attackCFrame = CFrame.lookAt(root.Position, root.Position + cameraLook)

	-- Local flash: proves the left click was read and shows attack direction.
	makeFlash(attackCFrame * CFrame.new(0, 0, -3.5), Vector3.new(6, 5, 7), 0.10)
	m1Remote:FireServer(cameraLook)

	task.delay(M1_COOLDOWN, function()
		m1Ready = true
	end)
end

-- Server feedback. A short second flash means the server received the M1.
feedbackRemote.OnClientEvent:Connect(function(combo, hitCount)
	if not root or not root.Parent then return end
	local cameraLook = horizontalCameraVectors()
	local attackCFrame = CFrame.lookAt(root.Position, root.Position + cameraLook)
	local size = hitCount > 0 and Vector3.new(3, 3, 3) or Vector3.new(1.5, 1.5, 1.5)
	makeFlash(attackCFrame * CFrame.new(0, 1.5, -2.2), size, 0.08)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		if humanoid then humanoid.WalkSpeed = SPRINT_SPEED end
	elseif input.KeyCode == Enum.KeyCode.Q then
		task.spawn(dash)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		if humanoid then humanoid.WalkSpeed = WALK_SPEED end
	end
end)

RunService.Heartbeat:Connect(function()
	if not humanoid then return end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airDashAvailable = true
	end
	if humanoid.Health > 0 then
		humanoid.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
	end
end)
