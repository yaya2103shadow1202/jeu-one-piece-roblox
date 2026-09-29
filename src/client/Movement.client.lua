-- Movement and camera only. Combat input is intentionally kept in a separate LocalScript.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local WALK_SPEED = 16
local SPRINT_SPEED = 25
local DASH_SPEED = 70
local AIR_DASH_SPEED = 62
local DASH_DURATION = 0.16
local DASH_COOLDOWN = 0.55

local character
local humanoid
local root
local sprinting = false
local dashReady = true
local airDashAvailable = true
local generation = 0

player.CameraMode = Enum.CameraMode.Classic
player.CameraMinZoomDistance = 7
player.CameraMaxZoomDistance = 26

local function setupCharacter(newCharacter)
	generation += 1
	sprinting = false
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = WALK_SPEED
	dashReady = true
	airDashAvailable = true
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

local function horizontalCameraLook()
	local camera = workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function getDashDirection()
	if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
		return humanoid.MoveDirection.Unit
	end
	return horizontalCameraLook()
end

local function dash()
	if not humanoid or not root or humanoid.Health <= 0 or not dashReady or humanoid.Sit
		or player:GetAttribute("MenuOpen") or (character:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then
		return
	end

	local state = humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	if airborne and not airDashAvailable then
		return
	end

	dashReady = false
	if airborne then
		airDashAvailable = false
	end

	local direction = getDashDirection()
	local speed = airborne and AIR_DASH_SPEED or DASH_SPEED
	local startedAt = os.clock()
	local dashRoot, dashHumanoid, dashCharacter, token = root, humanoid, character, generation

	while os.clock() - startedAt < DASH_DURATION and dashRoot.Parent and dashHumanoid.Health > 0 and generation == token do
		if (dashCharacter:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then break end
		local verticalVelocity = dashRoot.AssemblyLinearVelocity.Y
		if airborne then
			verticalVelocity = math.min(verticalVelocity, 4)
		end

		dashRoot.AssemblyLinearVelocity = Vector3.new(
			direction.X * speed,
			verticalVelocity,
			direction.Z * speed
		)
		RunService.Heartbeat:Wait()
	end

	task.delay(DASH_COOLDOWN, function()
		if generation == token then dashReady = true end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or player:GetAttribute("MenuOpen") then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		if humanoid then
			humanoid.WalkSpeed = SPRINT_SPEED
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		task.spawn(dash)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
		if humanoid then
			humanoid.WalkSpeed = WALK_SPEED
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not humanoid then
		return
	end

	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airDashAvailable = true
	end

	if humanoid.Health > 0 then
		local stunned = (character:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow()
		humanoid.WalkSpeed = stunned and 0 or (sprinting and SPRINT_SPEED or WALK_SPEED)
	end
end)

UserInputService.WindowFocusReleased:Connect(function() sprinting = false end)

print("[MovementClient] ready")
