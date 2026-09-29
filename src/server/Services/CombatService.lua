local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local B = require(script.Parent.Builders)
local Combat = {States = {}, Ledger = setmetatable({}, {__mode = "k"})}
local nextAttackId = 0
local function now() return workspace:GetServerTimeNow() end
local function modelOf(actor) return actor:IsA("Player") and actor.Character or actor end
local function alive(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return hum, root end
	return nil
end
local function directionOf(root, requested, flat)
	if typeof(requested) == "Vector3" and Rules.finite(requested.X) and Rules.finite(requested.Y) and Rules.finite(requested.Z) and requested.Magnitude > 0.05 and requested.Magnitude < 1.5 then
		local d = flat and Vector3.new(requested.X, 0, requested.Z) or requested
		if d.Magnitude > 0.05 then return d.Unit end
	end
	return root.CFrame.LookVector
end
local function humanoidModel(part)
	local model = part
	while model and model ~= workspace do
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then return model end
		model = model.Parent
	end
	return nil
end
function Combat.state(actor)
	if not Combat.States[actor] then
		Combat.States[actor] = {LastAttack = -10, NextAttack = 0, Combo = 0, Pending = {}, Charges = 3, RechargeAt = 0, LastInput = -10,
			Energy = 100, LastEnergyUse = -10, Armament = "Off", Ammo = 6, Reloading = false, ReloadSerial = 0, LastFruit = -10, AirBoost = false}
	end
	return Combat.States[actor]
end
function Combat.lineClear(from, target, ignore)
	local _, root = alive(target)
	if not root then return false end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, ignore or {}
	local hit = workspace:Raycast(from, root.Position - from, params)
	return not hit or hit.Instance:IsDescendantOf(target)
end
function Combat.safe(player)
	local _, root = alive(player.Character)
	if not root then return true end
	for _, hub in pairs(Combat.World.Hubs) do
		if (root.Position - hub.Spawn.Position).Magnitude < 48 then return true end
	end
	return false
end
function Combat.canHit(attacker, target)
	local model = modelOf(attacker)
	if target == model or not alive(target) then return false end
	local sourcePlayer = attacker:IsA("Player") and attacker or nil
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if sourcePlayer then
		if targetPlayer then
			return sourcePlayer:GetAttribute("PvPEnabled") == true and targetPlayer:GetAttribute("PvPEnabled") == true
				and not Combat.safe(sourcePlayer) and not Combat.safe(targetPlayer)
		end
		return target:GetAttribute("EnemyId") ~= nil or target:GetAttribute("TrainingDummy") == true
	end
	return targetPlayer ~= nil and targetPlayer:GetAttribute("ProfileReady") == true and not Combat.safe(targetPlayer)
end
function Combat.hasObservation(player)
	local p = Combat.Data.Profiles[player]
	return p and (p.Observation or player:GetAttribute("ObservationTraining") == true)
end
function Combat.warnTargets(targets, attackId, deadline)
	local warned = {}
	for target in pairs(targets) do
		local player = Players:GetPlayerFromCharacter(target)
		if player and Combat.hasObservation(player) then
			local state = Combat.state(player)
			if state.Charges > 0 then
				state.Pending[attackId] = {Character = target, Deadline = deadline, Dodged = false}
				warned[player] = true
				Combat.Remotes.Observation:FireClient(player, "Warning", attackId, deadline, state.Charges)
			end
		end
	end
	return warned
end
function Combat.clearWarnings(warned, attackId)
	for player in pairs(warned) do
		local state = Combat.States[player]
		if state then state.Pending[attackId] = nil end
		if player.Parent then Combat.Remotes.Observation:FireClient(player, "End", attackId) end
	end
end
function Combat.observation(player, attackId)
	if not Rules.finite(attackId) or attackId % 1 ~= 0 or not Combat.hasObservation(player) then return end
	local state, t = Combat.state(player), now()
	if t - state.LastInput < Config.Observation.InputCooldown then return end
	state.LastInput = t
	local pending = state.Pending[attackId]
	local humanoid = alive(player.Character)
	if not pending or not humanoid or pending.Character ~= player.Character or pending.Dodged or state.Charges <= 0
		or t > pending.Deadline or t < pending.Deadline - Config.Observation.Window - Config.Observation.NetworkMargin then return end
	pending.Dodged = true
	state.Charges -= 1
	if state.Charges == Config.Observation.Charges - 1 then state.RechargeAt = t + Config.Observation.Recharge end
	player:SetAttribute("ObservationCharges", state.Charges)
	Combat.Remotes.Observation:FireClient(player, "Success", attackId, state.Charges)
end
function Combat.applyDamage(attacker, target, amount, direction, combo, attackId, style)
	if not Combat.canHit(attacker, target) then return 0 end
	local humanoid, root = alive(target)
	if target:FindFirstChildOfClass("ForceField") then return 0 end
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local targetState = targetPlayer and Combat.state(targetPlayer)
	local pending = targetState and targetState.Pending[attackId]
	if pending and pending.Character == target and pending.Dodged then
		Combat.Remotes.CombatFX:FireAllClients("Dodge", target, root.Position, direction)
		local side = Vector3.new(-direction.Z, 0, direction.X)
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {target}
		if not workspace:Raycast(root.Position, side * 5, params) then root:ApplyImpulse(side * root.AssemblyMass * 25) end
		local p = Combat.Data.Profiles[targetPlayer]
		if p and p.Observation then p.Mastery.Haki = math.min(1000, p.Mastery.Haki + 2) end
		return 0
	end
	if targetState and targetState.Armament == "Guard" and targetState.Energy >= 8 then
		amount *= 0.7
		targetState.Energy -= 8
		targetState.LastEnergyUse = now()
	end
	if not attacker:IsA("Player") and attacker:GetAttribute("TrainingDummy") then amount = math.min(amount, math.max(0, humanoid.Health - 1)) end
	local before = humanoid.Health
	local expected = math.min(before, math.max(0, amount))
	-- Record before TakeDamage: Humanoid.Died can run immediately.
	if attacker:IsA("Player") and target:GetAttribute("EnemyId") and expected > 0 then
		local ledger = Combat.Ledger[target] or {}
		Combat.Ledger[target] = ledger
		local contribution = ledger[attacker] or {Damage = 0, At = 0}
		contribution.Damage += expected
		contribution.At = now()
		ledger[attacker] = contribution
	end
	humanoid:TakeDamage(amount)
	local actual = math.max(0, before - humanoid.Health)
	if actual <= 0 then return 0 end
	target:SetAttribute("StunnedUntil", now() + (combo == 4 and 0.28 or 0.12))
	if not root.Anchored then
		local force = style == "Gun" and 3 or (combo == 4 and 24 or 3)
		root:ApplyImpulse((direction * force + Vector3.new(0, combo == 4 and 7 or 0, 0)) * root.AssemblyMass)
	end
	if targetPlayer then targetPlayer:SetAttribute("InCombatUntil", now() + 7) end
	if attacker:IsA("Player") then
		attacker:SetAttribute("InCombatUntil", now() + 7)
		local p = Combat.Data.Profiles[attacker]
		if p and not target:GetAttribute("TrainingDummy") then
			p.Mastery[style] = math.min(1000, (p.Mastery[style] or 0) + 1)
			Combat.Data.sync(attacker)
		end
	end
	Combat.Remotes.CombatFX:FireAllClients("Hit", target, root.Position, combo)
	return actual
end
function Combat.meleeTargets(attacker, position, direction, range, width)
	local params = OverlapParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {modelOf(attacker)}
	local targets = {}
	local box = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -range / 2)
	for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(width, 6, range), params)) do
		local model = humanoidModel(part)
		if model and not targets[model] and Combat.canHit(attacker, model) and Combat.lineClear(position, model, {modelOf(attacker)}) then targets[model] = true end
	end
	return targets
end
function Combat.gunTargets(attacker, origin, direction, range)
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {modelOf(attacker)}
	local hit = workspace:Raycast(origin, direction * range, params)
	local model = hit and humanoidModel(hit.Instance)
	return model and Combat.canHit(attacker, model) and {[model] = true} or {}, hit and hit.Position or origin + direction * range
end
function Combat.reload(player)
	local p, state = Combat.Data.Profiles[player], Combat.state(player)
	if not p or p.Style ~= "Gun" or state.Reloading or state.Ammo >= 6 or not alive(player.Character) then return end
	state.Reloading = true
	state.ReloadSerial += 1
	local serial, character = state.ReloadSerial, player.Character
	player:SetAttribute("Reloading", true)
	task.delay(1.8, function()
		if player.Parent and player.Character == character and serial == state.ReloadSerial then
			state.Ammo, state.Reloading = 6, false
			player:SetAttribute("Ammo", 6)
			player:SetAttribute("Reloading", false)
		end
	end)
end
function Combat.attack(attacker, requested, heavy)
	local character = modelOf(attacker)
	local humanoid, root = alive(character)
	if not humanoid or humanoid.Sit or (character:GetAttribute("StunnedUntil") or 0) > now() then return end
	local isPlayer = attacker:IsA("Player")
	local profile = isPlayer and Combat.Data.Profiles[attacker]
	if isPlayer and not profile then return end
	local style = profile and profile.Style or character:GetAttribute("CombatStyle") or "Fists"
	local def, state, t = Config.Styles[style], Combat.state(attacker), now()
	heavy = heavy == true and style ~= "Gun"
	local cooldown = heavy and 1.1 or def.Cooldown
	if t < state.NextAttack or state.Reloading then return end
	if style == "Gun" and isPlayer and state.Ammo <= 0 then Combat.reload(attacker); return end
	if heavy and state.Energy < 16 then return end
	if t - state.LastAttack > 1.1 then state.Combo = 0 end
	state.Combo = style == "Gun" and 1 or ((state.Combo % 4) + 1)
	local combo = heavy and 4 or state.Combo
	state.LastAttack, state.NextAttack = t, t + cooldown
	local windup = heavy and 0.6 or def.Windup
	if heavy then state.Energy -= 16; state.LastEnergyUse = t end
	if style == "Gun" and isPlayer then state.Ammo -= 1; attacker:SetAttribute("Ammo", state.Ammo) end
	local direction = directionOf(root, requested, style ~= "Gun")
	local damage = def.Damage[combo] * (heavy and 1.4 or 1)
	if profile then damage = Rules.damage(damage, profile.Level, profile.Mastery[style], state.Armament)
	else damage = (character:GetAttribute("AttackDamage") or damage) * (combo == 4 and 1.4 or 1) end
	if state.Armament == "Focus" then state.Energy = math.max(0, state.Energy - 6); state.LastEnergyUse = t end
	nextAttackId += 1
	local attackId = nextAttackId
	local function targets()
		if style == "Gun" then return Combat.gunTargets(attacker, root.Position + Vector3.new(0, 1, 0), direction, def.Range) end
		return Combat.meleeTargets(attacker, root.Position, direction, def.Range, def.Width)
	end
	local initialTargets, endpoint = targets()
	local warned = Combat.warnTargets(initialTargets, attackId, t + windup)
	Combat.Remotes.CombatFX:FireAllClients("Swing", character, combo, {Style = style, Windup = windup, EndPoint = endpoint})
	task.delay(windup, function()
		if not attacker.Parent or modelOf(attacker) ~= character or not alive(character) or not character.Parent then Combat.clearWarnings(warned, attackId); return end
		local found, endPosition = targets()
		local hits, damageDone = 0, 0
		for target in pairs(found) do
			local amount = Combat.applyDamage(attacker, target, damage, direction, combo, attackId, style)
			if amount > 0 then hits += 1; damageDone += amount end
		end
		if style == "Gun" then Combat.Remotes.CombatFX:FireAllClients("Shot", character, root.Position + Vector3.new(0, 1, 0), endPosition) end
		Combat.clearWarnings(warned, attackId)
		if isPlayer and attacker.Parent then Combat.Remotes.M1Feedback:FireClient(attacker, combo, hits, 0, damageDone) end
	end)
end
function Combat.attachWeapon(character, style)
	local previous = character:FindFirstChild("EquippedWeapon")
	if previous then previous:Destroy() end
	if style == "Fists" then return end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then return end
	local weapon = Instance.new("Model")
	weapon.Name, weapon.Parent = "EquippedWeapon", character
	local grip = hand.CFrame * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	local function piece(name, size, offset, color, material)
		local p = B.part(weapon, name, size, grip * offset, color, material)
		p.Anchored, p.Massless, p.CanCollide, p.CanQuery, p.CanTouch = false, true, false, false, false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = hand, p, p
		return p
	end
	if style == "Sword" then
		piece("Poignée", Vector3.new(0.35, 1.2, 0.35), CFrame.new(), Color3.fromRGB(72, 46, 43), Enum.Material.Wood)
		piece("Garde", Vector3.new(1.4, 0.18, 0.6), CFrame.new(0, 0.7, 0), B.Palette.Gold, Enum.Material.Metal)
		piece("Lame", Vector3.new(0.38, 4.2, 0.12), CFrame.new(0, 2.8, 0), Color3.fromRGB(220, 232, 235), Enum.Material.Metal)
	else
		piece("Crosse", Vector3.new(0.6, 1.1, 0.65), CFrame.new(), B.Palette.Wood, Enum.Material.Wood)
		piece("Canon", Vector3.new(0.45, 0.5, 2.6), CFrame.new(0, 0.65, -0.7), Color3.fromRGB(67, 76, 86), Enum.Material.Metal)
		piece("Platine", Vector3.new(0.68, 0.4, 0.7), CFrame.new(0, 0.6, 0.4), B.Palette.Gold, Enum.Material.Metal)
	end
end
function Combat.equip(player, style)
	local profile = Combat.Data.Profiles[player]
	if type(style) ~= "string" or not profile or not Config.Styles[style] or not profile.Owned[style] then return end
	local state = Combat.state(player)
	if now() < state.NextAttack or state.Reloading then return end
	profile.Style = style
	state.Combo = 0
	if player.Character then Combat.attachWeapon(player.Character, style) end
	Combat.Data.sync(player)
end
function Combat.armament(player, mode)
	local profile = Combat.Data.Profiles[player]
	if not profile or not profile.Armament or (mode ~= "Off" and mode ~= "Focus" and mode ~= "Guard") then return end
	local state = Combat.state(player)
	if mode ~= "Off" and state.Energy < 15 then return end
	state.Armament = mode
	player:SetAttribute("ArmamentMode", mode)
	local character = player.Character
	if not character then return end
	local previous = character:FindFirstChild("ArmamentVisual")
	if previous then previous:Destroy() end
	if mode ~= "Off" then
		local light = Instance.new("Highlight")
		light.Name = "ArmamentVisual"
		light.FillColor, light.OutlineColor = Color3.fromRGB(15, 11, 28), Color3.fromRGB(166, 117, 221)
		light.FillTransparency, light.OutlineTransparency = mode == "Guard" and 0.65 or 0.9, 0.3
		light.DepthMode = Enum.HighlightDepthMode.Occluded
		light.Adornee = mode == "Focus" and (character:FindFirstChild("EquippedWeapon") or character:FindFirstChild("RightHand") or character) or character
		light.Parent = character
	end
end
function Combat.fruit(player, requested)
	local p, state = Combat.Data.Profiles[player], Combat.state(player)
	local character = player.Character
	local humanoid, root = alive(character)
	if not p or not p.Fruit or not humanoid or humanoid.Sit or (character:GetAttribute("StunnedUntil") or 0) > now() then return end
	local recipe, t = p.Technique, now()
	local stats = Rules.techniqueStats(recipe)
	if not stats or t - state.LastFruit < stats.Cooldown or state.Energy < stats.Cost then return end
	local direction = directionOf(root, requested, recipe.Shape ~= "Projectile")
	if recipe.Shape == "Propulsion" and humanoid.FloorMaterial == Enum.Material.Air and state.AirBoost then return end
	state.LastFruit, state.LastEnergyUse = t, t
	state.Energy -= stats.Cost
	if recipe.Shape == "Propulsion" then
		state.AirBoost = true
		local attachment = Instance.new("Attachment", root)
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0, velocity.RelativeTo = attachment, Enum.ActuatorRelativeTo.World
		velocity.VectorVelocity = direction * stats.Speed + Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 4), 0)
		velocity.MaxForce, velocity.Parent = root.AssemblyMass * 6000, root
		Debris:AddItem(velocity, stats.Duration)
		Debris:AddItem(attachment, stats.Duration)
		Combat.Remotes.CombatFX:FireAllClients("Propulsion", character, root.Position, direction)
		return
	end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {character}
	local origin = root.Position + Vector3.new(0, 1, 0)
	local hit = workspace:Raycast(origin, direction * stats.Range, params)
	local destination = hit and hit.Position or origin + direction * stats.Range
	if recipe.Shape == "Rempart" then
		local wallPosition = hit and hit.Position - direction * 2 or destination
		local check = OverlapParams.new()
		check.FilterType, check.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {character}
		local cf, size = CFrame.lookAt(wallPosition + Vector3.new(0, 1, 0), wallPosition + Vector3.new(0, 1, 0) + direction), Vector3.new(5 + recipe.Size * 4, 7, 1)
		for _, part in ipairs(workspace:GetPartBoundsInBox(cf, size, check)) do
			if part.CanCollide then
				state.Energy += stats.Cost
				Combat.Data.notify(player, "Pas assez d'espace pour le rempart.")
				return
			end
		end
		if state.Wall then state.Wall:Destroy() end
		local wall = B.part(workspace, "Rempart de Braises", size, cf, Color3.fromRGB(242, 130, 62), Enum.Material.Neon)
		wall.Transparency = 0.45
		state.Wall = wall
		Debris:AddItem(wall, stats.Duration)
		return
	end
	if recipe.Shape == "Zone" then
		local offset = direction * stats.Range
		local forwardHit = workspace:Raycast(origin, offset, params)
		local point = forwardHit and forwardHit.Position - direction or origin + offset
		local ground = workspace:Raycast(point + Vector3.new(0, 15, 0), Vector3.new(0, -50, 0), params)
		destination = ground and ground.Position + Vector3.new(0, 2, 0) or point
	end
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {character}
	local function targets()
		local result = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(destination, stats.Radius, overlap)) do
			local model = humanoidModel(part)
			if model and Combat.canHit(player, model) and Combat.lineClear(destination, model, {character}) then result[model] = true end
		end
		return result
	end
	nextAttackId += 1
	local attackId = nextAttackId
	local windup = recipe.Shape == "Zone" and 0.7 or 0.5
	local warned = Combat.warnTargets(targets(), attackId, t + windup)
	Combat.Remotes.CombatFX:FireAllClients("FruitCast", character, destination, {Origin = origin, Radius = stats.Radius, Duration = windup, Shape = recipe.Shape})
	task.delay(windup, function()
		if not player.Parent or player.Character ~= character or not alive(character) then Combat.clearWarnings(warned, attackId); return end
		local damageDone, hits = 0, 0
		local damage = Rules.damage(stats.Damage, p.Level, p.Mastery.Fruit, state.Armament)
		for target in pairs(targets()) do
			local amount = Combat.applyDamage(player, target, damage, direction, 1, attackId, "Fruit")
			if amount > 0 then damageDone += amount; hits += 1 end
		end
		Combat.Remotes.CombatFX:FireAllClients("FruitImpact", character, destination, stats.Radius)
		Combat.clearWarnings(warned, attackId)
		if player.Parent then Combat.Remotes.M1Feedback:FireClient(player, 1, hits, 0, damageDone) end
	end)
end
function Combat.character(player, character)
	Combat.States[player] = nil
	local state = Combat.state(player)
	player:SetAttribute("ObservationCharges", state.Charges)
	player:SetAttribute("Energy", 100)
	player:SetAttribute("Ammo", 6)
	player:SetAttribute("Reloading", false)
	player:SetAttribute("ArmamentMode", "Off")
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local profile = Combat.Data.Profiles[player]
	if profile then Combat.attachWeapon(character, profile.Style) end
end
function Combat.init(data, world, remotes)
	Combat.Data, Combat.World, Combat.Remotes = data, world, remotes
	remotes.M1.OnServerEvent:Connect(Combat.attack)
	remotes.Observation.OnServerEvent:Connect(Combat.observation)
	Players.PlayerRemoving:Connect(function(player) Combat.States[player] = nil end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.2 then return end
		local elapsed, t = accumulated, now()
		accumulated = 0
		for player in pairs(data.Profiles) do
			if not player.Parent then continue end
			local state = Combat.state(player)
			local hum, root = alive(player.Character)
			if hum then
				if hum.FloorMaterial ~= Enum.Material.Air then state.AirBoost = false end
				player:SetAttribute("ObservationTraining", (root.Position - world.TrainingPosition).Magnitude < 38)
				if state.Armament ~= "Off" then
					state.Energy = math.max(0, state.Energy - 5 * elapsed)
					if state.Energy <= 0 then Combat.armament(player, "Off") end
				elseif t - state.LastEnergyUse > 1.5 then state.Energy = math.min(100, state.Energy + 12 * elapsed) end
				while state.Charges < Config.Observation.Charges and t >= state.RechargeAt do
					state.Charges += 1
					local mastery = data.Profiles[player].Mastery.Haki
					state.RechargeAt += Config.Observation.Recharge - math.min(2, mastery / 500)
				end
			end
			player:SetAttribute("ObservationCharges", state.Charges)
			player:SetAttribute("ObservationRechargeAt", state.Charges < 3 and state.RechargeAt or 0)
			player:SetAttribute("Energy", math.floor(state.Energy))
		end
	end)
end
return Combat
