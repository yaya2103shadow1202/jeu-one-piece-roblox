-- Inputs and cosmetic feedback. Hits, timing, ammo and energy remain server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local request = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("Request")
local m1 = remotes:WaitForChild("M1")
local observation = remotes:WaitForChild("Observation")
local fx = remotes:WaitForChild("CombatFX")
local warnings, lastAttack, shake = {}, -10, 0
local tracks = setmetatable({}, {__mode = "k"})
local effects = Instance.new("Folder")
effects.Name, effects.Parent = "LocalCombatFX", workspace
local function part(size, cf, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, Enum.Material.Neon
	p.Parent = effects
	return p
end
local function pulse(position, color, radius)
	local p = part(Vector3.one, CFrame.new(position), color)
	p.Shape, p.Transparency = Enum.PartType.Ball, 0.45
	TweenService:Create(p, TweenInfo.new(0.24), {Size = Vector3.one * radius, Transparency = 1}):Play()
	Debris:AddItem(p, 0.25)
end
local function line(from, to, color, width, life)
	if (to - from).Magnitude < 0.05 then return end
	local p = part(Vector3.new(width, width, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color)
	TweenService:Create(p, TweenInfo.new(life), {Transparency = 1}):Play()
	Debris:AddItem(p, life + 0.02)
end
local function playClip(character, name)
	local owner = Players:GetPlayerFromCharacter(character)
	if owner and owner ~= player then return end
	local folder = ReplicatedStorage:FindFirstChild("CombatAnimations")
	local clip = folder and folder:FindFirstChild(name)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not clip or not clip:IsA("Animation") or clip.AnimationId == "" or not animator then return end
	local cache = tracks[character] or {}
	tracks[character] = cache
	local key = name .. clip.AnimationId
	if not cache[key] then
		local ok, track = pcall(function() return animator:LoadAnimation(clip) end)
		if not ok then return end
		track.Priority = Enum.AnimationPriority.Action
		cache[key] = track
	end
	cache[key]:Play(0.06)
end
local function aim()
	local camera = workspace.CurrentCamera
	if not camera then return Vector3.new(0, 0, -1) end
	local mouse = player:GetMouse()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and not UserInputService.TouchEnabled then
		local delta = mouse.Hit.Position - (root.Position + Vector3.new(0, 1, 0))
		if delta.Magnitude > 0.05 then return delta.Unit end
	end
	return camera.CFrame.LookVector
end
local function attack(heavy)
	if player:GetAttribute("MenuOpen") then return end
	local style = player:GetAttribute("CombatStyle") or "Fists"
	local definition = Config.Styles[style]
	if os.clock() - lastAttack < (heavy and 1.1 or definition.Cooldown) then return end
	lastAttack = os.clock()
	m1:FireServer(aim(), heavy == true)
end
local function nextWarning()
	local t, choice, nearest = workspace:GetServerTimeNow(), nil, math.huge
	for id, warning in pairs(warnings) do
		local deadline = warning.Deadline - Config.Observation.NetworkMargin
		if t > warning.Deadline + 0.2 then warnings[id] = nil
		elseif not warning.Sent and t >= deadline - Config.Observation.Window and t <= deadline and deadline < nearest then choice, nearest = id, deadline end
	end
	return choice, nearest
end
local function dodge()
	local id = nextWarning()
	if not id then return end
	warnings[id].Sent = true
	observation:FireServer(id)
end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ObservationHUD", false, 30
gui.Parent = player:WaitForChild("PlayerGui")
local prompt = Instance.new("TextButton")
prompt.AnchorPoint, prompt.Position, prompt.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.64), UDim2.fromOffset(240, 64)
prompt.BackgroundColor3, prompt.TextColor3 = Color3.fromRGB(13, 29, 43), Color3.fromRGB(188, 238, 247)
prompt.Font, prompt.TextSize, prompt.Text = Enum.Font.GothamBlack, 22, "[ F ]  ESQUIVE"
prompt.Visible, prompt.Parent = false, gui
Instance.new("UICorner", prompt).CornerRadius = UDim.new(0, 12)
local border = Instance.new("UIStroke", prompt)
border.Color, border.Thickness = Color3.fromRGB(107, 206, 224), 2
local timer = Instance.new("Frame")
timer.BorderSizePixel, timer.BackgroundColor3 = 0, border.Color
timer.Position, timer.Size, timer.Parent = UDim2.new(0, 8, 1, -6), UDim2.new(1, -16, 0, 3), prompt
prompt.Activated:Connect(dodge)
local successUntil = 0
observation.OnClientEvent:Connect(function(action, id, value)
	if action == "Warning" then warnings[id] = {Deadline = value, Sent = false}
	elseif action == "End" then warnings[id] = nil
	elseif action == "Success" then warnings[id] = nil; successUntil = os.clock() + 0.35 end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonB then dodge(); return end
	if player:GetAttribute("MenuOpen") then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then attack(false)
	elseif input.KeyCode == Enum.KeyCode.R then
		if player:GetAttribute("CombatStyle") == "Gun" then request:FireServer("Reload") else attack(true) end
	elseif input.KeyCode == Enum.KeyCode.Z then request:FireServer("Cast", aim())
	elseif input.KeyCode == Enum.KeyCode.One then request:FireServer("Equip", "Fists")
	elseif input.KeyCode == Enum.KeyCode.Two then request:FireServer("Equip", "Sword")
	elseif input.KeyCode == Enum.KeyCode.Three then request:FireServer("Equip", "Gun")
	elseif input.KeyCode == Enum.KeyCode.H then
		local mode = player:GetAttribute("ArmamentMode") or "Off"
		request:FireServer("Armament", mode == "Off" and "Focus" or (mode == "Focus" and "Guard" or "Off"))
	end
end)
if UserInputService.TouchEnabled then
	local function touch(label, x, callback)
		local button = Instance.new("TextButton")
		button.Size, button.Position = UDim2.fromOffset(72, 56), UDim2.new(1, x, 0.72, 0)
		button.Text, button.TextSize, button.Font = label, 16, Enum.Font.GothamBold
		button.TextColor3, button.BackgroundColor3 = Color3.fromRGB(245, 223, 164), Color3.fromRGB(25, 39, 51)
		button.Parent = gui
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
		button.Activated:Connect(callback)
	end
	touch("ATTAQUE", -90, function() attack(false) end)
	touch("LOURDE", -170, function() if player:GetAttribute("CombatStyle") == "Gun" then request:FireServer("Reload") else attack(true) end end)
	touch("FRUIT", -250, function() request:FireServer("Cast", aim()) end)
end
fx.OnClientEvent:Connect(function(action, character, a, extra)
	if typeof(character) ~= "Instance" then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if action == "Swing" and root then
		local combo, info = a, extra
		playClip(character, info.Style == "Fists" and ("M1_" .. combo) or (info.Style .. "_" .. combo))
		if info.Style == "Gun" and info.EndPoint then
			line(root.Position + Vector3.new(0, 1, 0), info.EndPoint, Color3.fromRGB(223, 111, 83), 0.08, info.Windup)
		else
			task.delay(math.max(0, info.Windup - 0.10), function()
				if not root.Parent then return end
				local cf = root.CFrame * CFrame.new(0, 0.7, -3)
				local color = info.Style == "Sword" and Color3.fromRGB(225, 227, 245) or Color3.fromRGB(245, 206, 132)
				for i = 0, 7 do
					local angle, nextAngle = -1.3 + i * 0.32, -1.3 + (i + 1) * 0.32
					local radius = info.Style == "Sword" and 4 or 2.5
					line(cf:PointToWorldSpace(Vector3.new(math.sin(angle) * radius, math.cos(angle), 0)), cf:PointToWorldSpace(Vector3.new(math.sin(nextAngle) * radius, math.cos(nextAngle), 0)), color, 0.14, 0.14)
				end
			end)
		end
	elseif action == "Hit" then
		pulse(a, Color3.fromRGB(247, 212, 154), extra == 4 and 5 or 3)
		if character == player.Character then shake = 0.14 end
	elseif action == "Dodge" then pulse(a, Color3.fromRGB(103, 209, 238), 5); playClip(character, "ObservationDodgeRight")
	elseif action == "Shot" then line(a, extra, Color3.fromRGB(255, 227, 139), 0.14, 0.12)
	elseif action == "Propulsion" then pulse(a, Color3.fromRGB(240, 125, 57), 7)
	elseif action == "FruitCast" then
		if extra.Shape == "Zone" then
			local ring = part(Vector3.new(0.15, extra.Radius * 2, extra.Radius * 2), CFrame.new(a - Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(225, 115, 49))
			ring.Shape, ring.Transparency = Enum.PartType.Cylinder, 0.68
			Debris:AddItem(ring, extra.Duration)
		else
			local orb = part(Vector3.one * math.min(extra.Radius, 4), CFrame.new(extra.Origin), Color3.fromRGB(252, 164, 69))
			orb.Shape = Enum.PartType.Ball
			TweenService:Create(orb, TweenInfo.new(extra.Duration, Enum.EasingStyle.Linear), {Position = a}):Play()
			Debris:AddItem(orb, extra.Duration)
		end
	elseif action == "FruitImpact" then pulse(a, Color3.fromRGB(255, 144, 59), extra * 2) end
end)
RunService.RenderStepped:Connect(function(dt)
	local id, deadline = nextWarning()
	prompt.Visible = id ~= nil or os.clock() < successUntil
	prompt.Text = id and "[ F ]  ESQUIVE" or "ESQUIVÉ !"
	local remaining = id and math.clamp((deadline - workspace:GetServerTimeNow()) / Config.Observation.Window, 0, 1) or 1
	timer.Size = UDim2.fromOffset(math.max(0, prompt.AbsoluteSize.X - 16) * remaining, 3)
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0) end
	end
end)
player.CharacterAdded:Connect(function()
	warnings, lastAttack, shake = {}, -10, 0
	table.clear(tracks)
end)
