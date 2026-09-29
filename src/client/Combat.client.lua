local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")

local LOCAL_COOLDOWN = 0.28
local ready = true

local function showAttackFlash()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local part = Instance.new("Part")
	part.Name = "M1DebugFlash"
	part.Size = Vector3.new(4.5, 4.5, 5)
	part.CFrame = root.CFrame * CFrame.new(0, 0, -3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.72
	part.Parent = workspace
	Debris:AddItem(part, 0.08)
end

local function attack()
	if not ready then return end
	ready = false

	showAttackFlash()
	m1Remote:FireServer()

	task.delay(LOCAL_COOLDOWN, function()
		ready = true
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	end
end)
