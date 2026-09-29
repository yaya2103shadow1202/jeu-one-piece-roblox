-- Prototype movement + combat input controller
-- Third-person combat movement: sprint, ground dash, one air dash and M1 input.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local WALK_SPEED = 16
local SPRINT_SPEED = 25
local DASH_SPEED = 70
local DASH_DURATION = 0.16
local DASH_COOLDOWN = 0.55
local AIR_DASH_SPEED = 62
local M1_COOLDOWN = 0.28

local character
local humanoid
local root
local sprinting = false
local dashReady = true
local airDashAvailable = true
local m1Ready = true

-- Force third person and keep a useful PvP camera distance.
player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 7
player.CameraMaxZoomDistance = 14

local function setupCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = WALK_SPEED
	airDashAvailable = true
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
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
	return look, right
end

local function inputDirection()
	local look, right = horizontalCameraVectors()
	local direction = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += look end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= look end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += right end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= right end

	if direction.Magnitude > 0 then
		return direction.Unit
	end
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

local function showAttackFlash()
	if not root or not root.Parent then return end

	local part = Instance.new("Part")
	part.Name = "M1DebugFlash"
	part.Size = Vector3.new(5, 5, 6)
	part.CFrame = root.CFrame * CFrame.new(0, 0, -3.5)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.55
	part.Parent = workspace
	Debris:AddItem(part, 0.12)
end

local function attack()
	if not m1Ready or not humanoid or humanoid.Health <= 0 then return end
	m1Ready = false

	-- This flash proves that the client received the left click.
	showAttackFlash()

	local remotes = ReplicatedStorage:FindFirstChild("CombatRemotes")
	local m1Remote = remotes and remotes:FindFirstChild("M1")
	if m1Remote and m1Remote:IsA("RemoteEvent") then
		m1Remote:FireServer()
	else
		warn("M1 RemoteEvent introuvable")
	end

	task.delay(M1_COOLDOWN, function()
		m1Ready = true
	end)
end

-- GetMouse is deliberately used here because this LocalScript is already known to run.
mouse.Button1Down:Connect(attack)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
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
