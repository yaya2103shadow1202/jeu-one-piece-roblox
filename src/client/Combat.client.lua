-- Combat input: M1 + guard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local M1_COOLDOWN = 0.30
local ready = true
local blocking = false
local guardHighlight

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")
local feedbackRemote = remotes:WaitForChild("M1Feedback")
local blockRemote = remotes:WaitForChild("BlockState")

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

local function setLocalGuardVisual(enabled)
	if guardHighlight then
		guardHighlight:Destroy()
		guardHighlight = nil
	end

	if not enabled then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalGuardHighlight"
	highlight.FillColor = Color3.fromRGB(80, 150, 255)
	highlight.OutlineColor = Color3.fromRGB(170, 215, 255)
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	guardHighlight = highlight
end

local function setBlocking(enabled)
	if blocking == enabled then
		return
	end

	blocking = enabled
	setLocalGuardVisual(enabled)
	blockRemote:FireServer(enabled)
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
	local direction = getFlatCameraLook(root)
	showLocalSwing(root, direction)
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
	setLocalGuardVisual(false)
	blockRemote:FireServer(false)
end)

feedbackRemote.OnClientEvent:Connect(function(combo, hitCount, blockedCount)
	print(string.format(
		"[CombatClient] M1 combo=%d hits=%d blocked=%d",
		combo,
		hitCount or 0,
		blockedCount or 0
	))
end)

print("[CombatClient] ready")
