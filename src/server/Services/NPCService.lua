local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local B = require(script.Parent.Builders)
local NPC = {Actors = {}}
local function fallbackRig()
	local model = Instance.new("Model")
	local root = B.part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 4, 0), Color3.new())
	root.Transparency, root.CanCollide = 1, false
	local torso = B.part(model, "Torso", Vector3.new(2, 2, 1), root.CFrame, Color3.fromRGB(125, 91, 73))
	local function joint(name, target, a, b)
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1, motor.C0, motor.C1, motor.Parent = name, torso, target, a, b, torso
	end
	local motor = Instance.new("Motor6D")
	motor.Name, motor.Part0, motor.Part1, motor.Parent = "RootJoint", root, torso, root
	local head = B.part(model, "Head", Vector3.new(2, 1, 1), root.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(209, 166, 125))
	joint("Neck", head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	for _, side in ipairs({-1, 1}) do
		local label = side == -1 and "Left" or "Right"
		local arm = B.part(model, label .. " Arm", Vector3.new(1, 2, 1), root.CFrame * CFrame.new(side * 1.5, 0, 0), torso.Color)
		local leg = B.part(model, label .. " Leg", Vector3.new(1, 2, 1), root.CFrame * CFrame.new(side * 0.5, -2, 0), Color3.fromRGB(56, 65, 78))
		joint(label .. " Shoulder", arm, CFrame.new(side, 0.5, 0), CFrame.new(-side * 0.5, 0.5, 0))
		joint(label .. " Hip", leg, CFrame.new(side * 0.5, -1, 0), CFrame.new(0, 1, 0))
	end
	for _, part in ipairs(model:GetChildren()) do if part:IsA("BasePart") then part.Anchored = false end end
	Instance.new("Humanoid", model)
	model.PrimaryPart = root
	return model
end
function NPC.init(world, combat, progression)
	NPC.World, NPC.Combat, NPC.Progression = world, combat, progression
	NPC.Folder = Instance.new("Folder")
	NPC.Folder.Name, NPC.Folder.Parent = "Enemies", world.Folder
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
	description:Destroy()
	NPC.Template = ok and model or fallbackRig()
	if not ok then warn("[NPC] R15 creation unavailable; using local R6 fallback", model) end
	for _, marker in ipairs(world.Markers) do NPC.spawn(marker); task.wait() end
	NPC.spawn({Position = world.TrainingPosition, Training = true, Island = "Port"})
	task.spawn(function()
		while NPC.Folder.Parent do
			for model, record in pairs(NPC.Actors) do NPC.tick(model, record) end
			task.wait(0.25)
		end
	end)
end
function NPC.spawn(marker)
	local definition = marker.Training and {Name = "Dummy d'entraînement", Level = 1, HP = 1000, Damage = 4, Style = "Fists", Color = {100, 132, 147}} or Config.Enemies[marker.Enemy]
	local model = NPC.Template:Clone()
	model.Name = definition.Name
	model:SetAttribute("EnemyId", marker.Enemy)
	model:SetAttribute("TrainingDummy", marker.Training == true)
	model:SetAttribute("CombatStyle", definition.Style)
	model:SetAttribute("AttackDamage", definition.Damage)
	model:SetAttribute("Island", marker.Island)
	model.Parent = NPC.Folder
	model:PivotTo(CFrame.new(marker.Position))
	local humanoid, root = model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then model:Destroy(); warn("[NPC] Missing rig parts"); return end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part.Name ~= "HumanoidRootPart" then part.Color = Color3.fromRGB(table.unpack(definition.Color)) end
		end
	end
	humanoid.MaxHealth, humanoid.Health = definition.HP, definition.HP
	humanoid.WalkSpeed = marker.Training and 9 or 13
	humanoid.DisplayName = definition.Name .. (marker.Training and " · F pour esquiver" or " · Niv. " .. definition.Level)
	humanoid.NameDisplayDistance, humanoid.HealthDisplayDistance = definition.Boss and 100 or 55, 55
	pcall(function() root:SetNetworkOwner(nil) end)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	NPC.Combat.attachWeapon(model, definition.Style)
	local record = {Marker = marker, Definition = definition, Humanoid = humanoid, Root = root, NextAttack = 0, NextPath = 0,
		PathBusy = false, Waypoints = nil, Waypoint = 1, Returning = false}
	NPC.Actors[model] = record
	-- Official Roblox default R15 walk, documented in creator-docs/animation/graph-editor.
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://507777826"
		local loaded, track = pcall(function() return animator:LoadAnimation(anim) end)
		anim:Destroy()
		if loaded then
			track.Looped, track.Priority = true, Enum.AnimationPriority.Movement
			record.Running = humanoid.Running:Connect(function(speed)
				if speed > 0.5 then if not track.IsPlaying then track:Play(0.15) end; track:AdjustSpeed(speed / 14)
				elseif track.IsPlaying then track:Stop(0.15) end
			end)
		end
	end
	humanoid.Died:Once(function()
		NPC.Actors[model] = nil
		if record.Running then record.Running:Disconnect() end
		local ledger = NPC.Combat.Ledger[model]
		if ledger and not marker.Training then
			for player, hit in pairs(ledger) do
				local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if player.Parent and playerRoot and workspace:GetServerTimeNow() - hit.At < 35 and hit.Damage >= math.min(10, definition.HP * 0.1)
					and (playerRoot.Position - root.Position).Magnitude < 200 then NPC.Progression.kill(player, marker.Enemy) end
			end
		end
		NPC.Combat.States[model], NPC.Combat.Ledger[model] = nil, nil
		task.delay(3, function() if model.Parent then model:Destroy() end end)
		task.delay(marker.Training and 4 or (definition.Boss and 25 or 12), function()
			if NPC.Folder.Parent then NPC.spawn(marker) end
		end)
	end)
end
function NPC.move(record, model, destination)
	local root, humanoid = record.Root, record.Humanoid
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {model}
	local hit = workspace:Raycast(root.Position, destination - root.Position, params)
	if not hit or (hit.Position - destination).Magnitude < 4 then record.Waypoints = nil; humanoid:MoveTo(destination); return end
	if not record.PathBusy and os.clock() >= record.NextPath then
		record.PathBusy, record.NextPath = true, os.clock() + 1.5
		task.spawn(function()
			local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5})
			local ok = pcall(function() path:ComputeAsync(root.Position, destination) end)
			if ok and path.Status == Enum.PathStatus.Success then record.Waypoints, record.Waypoint = path:GetWaypoints(), 2 end
			record.PathBusy = false
			path:Destroy()
		end)
	end
	local point = record.Waypoints and record.Waypoints[record.Waypoint]
	if point then
		if (root.Position - point.Position).Magnitude < 4 then record.Waypoint += 1 end
		if point.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
		humanoid:MoveTo(point.Position)
	end
end
function NPC.tick(model, record)
	local humanoid, root = record.Humanoid, record.Root
	if not model.Parent or humanoid.Health <= 0 then return end
	if (model:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then humanoid:MoveTo(root.Position); return end
	local home = record.Marker.Position
	local leash = record.Marker.Training and 27 or 105
	if root.Position.Y < -12 then model:PivotTo(CFrame.new(home)); root.AssemblyLinearVelocity = Vector3.zero end
	local target, distance
	if (root.Position - home).Magnitude <= leash then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
			if targetRoot and NPC.Combat.canHit(model, character) and (targetRoot.Position - home).Magnitude < leash then
				local gap = (targetRoot.Position - root.Position).Magnitude
				if gap < (record.Marker.Training and 20 or 64) and (not distance or gap < distance) then target, distance = targetRoot, gap end
			end
		end
	end
	if not target then
		if (root.Position - home).Magnitude > 5 then NPC.move(record, model, home)
		else
			humanoid:MoveTo(root.Position)
			local recent = false
			for _, hit in pairs(NPC.Combat.Ledger[model] or {}) do if workspace:GetServerTimeNow() - hit.At < 10 then recent = true end end
			if not recent then humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 2); NPC.Combat.Ledger[model] = nil end
		end
		return
	end
	local isGun = record.Definition.Style == "Gun"
	local reach = isGun and 70 or (record.Definition.Style == "Sword" and 6.5 or 5)
	if distance > reach or not NPC.Combat.lineClear(root.Position, target.Parent, {model}) then NPC.move(record, model, target.Position); return end
	humanoid:MoveTo(root.Position)
	local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
	if flat.Magnitude < 0.05 then return end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	if os.clock() >= record.NextAttack then
		NPC.Combat.attack(model, (target.Position - root.Position).Unit, false)
		local combo = NPC.Combat.state(model).Combo
		record.NextAttack = os.clock() + (record.Marker.Training and 1.45 or (record.Definition.Boss and (combo == 4 and 1.7 or 0.75) or 1.7))
	end
end
return NPC
