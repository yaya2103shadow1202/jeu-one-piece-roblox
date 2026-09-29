local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local m1Remote = remotes:WaitForChild("M1")

local LOCAL_COOLDOWN = 0.28
local ready = true

local function attack()
	if not ready then return end
	ready = false
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
