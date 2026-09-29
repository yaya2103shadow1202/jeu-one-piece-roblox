-- M1 combat input only.
-- Mouse.Button1Down is used because it is simple, supported by Roblox, and already worked in this project.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local M1_COOLDOWN = 0.30
local ready = true

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")
local feedbackRemote = remotes:WaitForChild("M1Feedback")

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

local function showLocalSwing(root, direction)
	local facing = CFrame.lookAt(root.Position, root.Position + direction)
	local part = Instance.new("Part")
	part.Name = "M1SwingPreview"
	part.Size = Vector3.new(5.5, 4.5, 5.5)
	part.CFrame = facing * CFrame.new(0, 0, -3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.78
	part.Parent = workspace
	Debris:AddItem(part, 0.08)
end

local function attack()
	if not ready then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	ready = false
	local direction = getFlatCameraLook(root)
	showLocalSwing(root, direction)
	m1Remote:FireServer(direction)

	task.delay(M1_COOLDOWN, function()
		ready = true
	end)
end

mouse.Button1Down:Connect(attack)

feedbackRemote.OnClientEvent:Connect(function(combo, hitCount)
	print(string.format("[CombatClient] M1 combo=%d hits=%d", combo, hitCount))
end)

print("[CombatClient] ready")
