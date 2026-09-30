local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.ArchipelagoShared.Config)
local B = require(script.Parent.Builders)
local V, C = Vector3.new, Color3.fromRGB
local World = {Hubs = {}, Markers = {}}

local function environment()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.CanCollide, baseplate.CanQuery, baseplate.Transparency = false, false, 1
	end
	Lighting.ClockTime, Lighting.Brightness = 14.7, 2.3
	Lighting.Ambient, Lighting.OutdoorAmbient = C(97, 111, 132), C(136, 150, 168)
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.6, 0.4
	local atmosphere = Lighting:FindFirstChild("ArchipelagoAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name, atmosphere.Density, atmosphere.Offset = "ArchipelagoAtmosphere", 0.24, 0.15
	atmosphere.Color, atmosphere.Decay = C(181, 213, 232), C(102, 132, 161)
	atmosphere.Glare, atmosphere.Haze, atmosphere.Parent = 0.2, 1.2, Lighting
end

local function child(parent, name)
	local result = parent:FindFirstChild(name)
	assert(result, "Carte incomplète : " .. parent.Name .. "." .. name)
	return result
end

function World.bind(folder)
	-- Bind gameplay to the same geometry visible in Studio, without deleting it.
	World.Folder, World.Hubs, World.Markers = folder, {}, {}
	for _, island in ipairs(Config.Islands) do
		local root = child(folder, island.Id)
		local origin = V(table.unpack(island.Position))
		local questNPC = child(root, island.QuestNPC.Name)
		local questRoot = child(questNPC, "Torso")
		local ferryRoot = child(child(root, "Ivo · passeur"), "Torso")
		World.Hubs[island.Id] = {Definition = island, Folder = root,
			Spawn = CFrame.new(origin + V(table.unpack(island.Spawn))), SpawnLocation = child(root, island.Id .. "Spawn"),
			QuestNPC = questNPC, QuestRoot = questRoot, QuestPrompt = child(questRoot, "ProximityPrompt"),
			FerryRoot = ferryRoot, FerryPrompt = child(ferryRoot, "ProximityPrompt")}
		for n = 1, 5 do
			local angle = n * math.pi * 2 / 5
			local center = origin + V(table.unpack(island.EnemyCenter))
			table.insert(World.Markers, {Enemy = island.Enemy, Island = island.Id, Position = center + V(math.cos(angle) * 28, 1, math.sin(angle) * 28)})
		end
		table.insert(World.Markers, {Enemy = island.Boss, Island = island.Id, Position = origin + V(table.unpack(island.BossPosition)) + V(0, 1, 0)})
	end
	local port = World.Hubs.Port.Definition
	World.TrainingPosition = V(table.unpack(port.Position)) + V(-88, port.Top + 4, -66)
	local master = child(child(World.Hubs.Port.Folder, "Ren · maître d'armes"), "Torso")
	World.Master = {Root = master, Prompt = child(master, "ProximityPrompt")}
	local fruit = child(child(World.Hubs.Jungle.Folder, "Ena · chercheuse des fruits"), "Torso")
	World.FruitNPC = {Root = fruit, Prompt = child(fruit, "ProximityPrompt")}
	workspace:SetAttribute("ArchipelagoReady", true)
	return World
end

function World.build(force)
	local previous = workspace:FindFirstChild("Archipelago")
	local version = previous and previous:FindFirstChild("WorldVersion")
	environment()
	if not force and version and version.Value == Config.Version then
		local ok, result = pcall(World.bind, previous)
		if ok then return result end
		warn("[Archipelago] Rebuilding incomplete map:", result)
	end
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "Archipelago", workspace
	World.Folder, World.Hubs, World.Markers = folder, {}, {}
	-- BasePart dimensions are limited to 2048: tile the 6000-stud sea.
	for x = -1, 1 do
		for z = -1, 1 do
			local ocean = B.part(folder, "Mer", V(2000, 3, 2000), CFrame.new(x * 2000, -2, z * 2000 - 700), C(29, 111, 153), Enum.Material.Glass)
			ocean.CanCollide, ocean.CanTouch, ocean.CanQuery = false, false, false
			ocean.Transparency, ocean.Reflectance = 0.18, 0.15
		end
	end
	-- Light surface streaks give the sea scale without thousands of particles.
	for i = 1, 90 do
		local rng = Random.new(700 + i)
		local x, z = rng:NextNumber(-2100, 2100), rng:NextNumber(-2600, 850)
		local stripe = B.decor(B.part(folder, "Écume", V(rng:NextNumber(8, 24), 0.05, 0.5), CFrame.new(x, 0.1, z), C(162, 217, 225)))
		stripe.Transparency = 0.8
	end

	for index, island in ipairs(Config.Islands) do
		local root = Instance.new("Folder")
		root.Name, root.Parent = island.Id, folder
		local origin = V(table.unpack(island.Position))
		local top, radius = island.Top, island.Radius
		local accent, grass = C(table.unpack(island.Accent)), C(table.unpack(island.Color))
		local function pos(x, y, z) return origin + V(x, y, z) end
		B.disc(root, "Socle de falaise", pos(0, -6, 0), radius, 22, B.Palette.Rock, Enum.Material.Rock)
		B.disc(root, "Plage", pos(0, top - 4, 0), radius - 4, 5, B.Palette.Sand, Enum.Material.Sand)
		B.disc(root, "Plateau", pos(0, top - 2, 0), radius - 22, 4, grass, Enum.Material.Grass)
		local rng = Random.new(9301 + index)
		for n = 1, 14 do
			local angle = n * math.pi * 2 / 14
			local r = radius - rng:NextNumber(18, 36)
			local x, z = math.cos(angle) * r, math.sin(angle) * r
			B.disc(root, "Anse", pos(x, top - 5, z), rng:NextNumber(23, 38), 5, B.Palette.Sand, Enum.Material.Sand)
			if z < 100 then
				B.ball(root, "Roche côtière", pos(x * 0.98, top + 3, z * 0.98), V(22, rng:NextNumber(15, 40), 20), B.Palette.Rock, Enum.Material.Slate)
			end
		end
		-- The wide spine connects arrival, quest giver and boss without jump gates.
		B.part(root, "Grand chemin", V(17, 0.22, 340), CFrame.new(pos(0, top + 0.1, 12)), B.Palette.Sand, Enum.Material.Pebble)
		B.part(root, "Chemin du camp", V(125, 0.23, 12), CFrame.new(pos(57, top + 0.12, -38)), B.Palette.Sand, Enum.Material.Pebble)
		B.disc(root, "Place d'arrivée", pos(0, top + 0.14, 95), 40, 0.28, B.Palette.Sand, Enum.Material.Cobblestone)
		B.disc(root, "Arène", origin + V(table.unpack(island.BossPosition)) - V(0, 2.85, 0), 35, 0.3, C(143, 137, 117), Enum.Material.Cobblestone)
		-- Camp perimeter and supplies frame the enemy clearing without blocking spawn pads.
		local camp = origin + V(table.unpack(island.EnemyCenter)) - V(0, 3, 0)
		for n = 1, 3 do
			local angle = n * math.pi * 2 / 3
			local crate = camp + V(math.cos(angle) * 49, 2.5, math.sin(angle) * 49)
			B.part(root, "Caisse de provisions", V(5, 5, 5), CFrame.new(crate), B.Palette.Wood, Enum.Material.WoodPlanks)
			B.part(root, "Renfort de caisse", V(5.2, 0.5, 5.2), CFrame.new(crate + V(0, 1.5, 0)), B.Palette.DarkWood, Enum.Material.Wood)
		end
		for n = 1, 28 do
			local angle = n * math.pi * 2 / 28
			local x, z = math.cos(angle) * (radius - 60), math.sin(angle) * (radius - 60)
			if math.abs(x) > 35 and z < 50 then
				B.decor(B.ball(root, "Buisson côtier", pos(x, top + 1.4, z), V(6, 4, 5), grass:Lerp(C(26, 71, 57), 0.3), Enum.Material.Grass))
			end
		end
		local dockPosition = origin + V(table.unpack(island.Dock))
		local dockLength = island.Dock[3] - 160 + 32
		local dockCenter = (island.Dock[3] + 160) / 2
		B.part(root, "Jetée", V(18, 1.5, dockLength), CFrame.new(pos(0, 6, dockCenter)), B.Palette.Wood, Enum.Material.WoodPlanks)
		-- Steps between the elevated island and the low pier.
		for step = 0, math.ceil((top - 6) / 0.6) do
			local y = math.min(top + 0.1, 6 + step * 0.6)
			B.part(root, "Marche", V(19, 1, 3), CFrame.new(pos(0, y, radius + 16 - step * 2.5)), B.Palette.Wood, Enum.Material.WoodPlanks)
		end
		for z = 205, island.Dock[3] + 10, 22 do
			for _, side in ipairs({-1, 1}) do
				B.part(root, "Pilotis", V(1.6, 15, 1.6), CFrame.new(pos(side * 8, 1, z)), B.Palette.DarkWood, Enum.Material.Wood)
			end
		end
		B.lantern(root, dockPosition + V(-8, 0, -16))
		B.lantern(root, dockPosition + V(8, 0, -16))
		B.boat(root, CFrame.new(dockPosition + V(24, -5, 0)), accent, 1)
		local ferry, ferryRoot = B.npc(root, "Ivo · passeur", dockPosition + V(0, 3, 0), accent)
		local ferryPrompt = B.prompt(ferryRoot, "Choisir une destination", island.Name)
		local questPosition = origin + V(table.unpack(island.QuestNPC.Position))
		local questNPC, questRoot = B.npc(root, island.QuestNPC.Name, questPosition, accent)
		local questPrompt = B.prompt(questRoot, "Parler", island.QuestNPC.Name)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = island.Id .. "Spawn"
		spawn.Size, spawn.CFrame = V(8, 1, 8), CFrame.new(origin + V(table.unpack(island.Spawn)) - V(0, 4, 0))
		spawn.Anchored, spawn.Neutral, spawn.Enabled = true, true, island.Id == "Port"
		spawn.Transparency, spawn.CanCollide, spawn.Duration = 1, false, 2
		spawn.Parent = root
		local sign = B.part(root, "Panneau", V(14, 6, 1), CFrame.new(pos(22, top + 5, 126)), B.Palette.DarkWood, Enum.Material.Wood)
		B.label(sign, island.Name, "Niveau conseillé : " .. island.Level, B.Palette.Gold, 110)
		for n = 1, 38 do
			local x, z = rng:NextNumber(-radius + 45, radius - 45), rng:NextNumber(-radius + 45, radius - 45)
			local reserved = math.abs(x) < 35 or (x > 35 and x < 145 and z > -110 and z < 50)
				or (math.abs(x) < 70 and z > 50)
				or (island.Id == "Port" and (z > 35 or (x > -150 and x < -40 and z > -105)))
			if x * x + z * z < (radius - 45) ^ 2 and not reserved then
				if island.Id == "Storm" then
					local p = B.part(root, "Aiguille rocheuse", V(10, rng:NextNumber(20, 55), 10), CFrame.new(pos(x, top + 8, z)) * CFrame.Angles(0.1, rng:NextNumber(0, 3), 0.18), B.Palette.Rock, Enum.Material.Slate)
					B.decor(B.ball(root, "Cristal", p.Position + V(0, p.Size.Y / 2, 0), V(3, 5, 3), accent, Enum.Material.Neon))
				elseif island.Id ~= "Fort" then B.tree(root, pos(x, top, z), rng:NextNumber(0.8, 1.4), island.Id == "Jungle") end
			end
		end
		if island.Id == "Port" then
			B.ball(root, "Colline du guet", pos(-125, top + 2, -125), V(105, 49, 80), grass, Enum.Material.Grass)
			B.ball(root, "Crête du guet", pos(-104, top + 12, -163), V(62, 60, 52), grass, Enum.Material.Grass)
			for n = 1, 10 do
				local angle = n * 0.7
				local x, z = -100 + math.cos(angle) * 59, -116 + math.sin(angle) * 49
				if (x + 88) ^ 2 + (z + 66) ^ 2 > 40 ^ 2 then B.tree(root, pos(x, top, z), 1, false) end
			end
			for _, x in ipairs({-42, 42}) do
				B.part(root, "Comptoir du marché", V(13, 4, 5), CFrame.new(pos(x, top + 2, 120)), B.Palette.Wood, Enum.Material.WoodPlanks)
				B.part(root, "Auvent du marché", V(16, 0.5, 10), CFrame.new(pos(x, top + 10, 120)), accent, Enum.Material.Fabric)
				for _, side in ipairs({-1, 1}) do B.part(root, "Montant", V(0.6, 10, 0.6), CFrame.new(pos(x + side * 7, top + 5, 120)), B.Palette.Wood, Enum.Material.Wood) end
				for n = 1, 4 do B.decor(B.ball(root, "Marchandise", pos(x - 5 + n * 2, top + 4.5, 120), V(1.5, 1.4, 1.5), n % 2 == 0 and C(210, 85, 65) or B.Palette.Gold)) end
			end
			B.part(root, "Route du dojo", V(86, 0.23, 10), CFrame.new(pos(-43, top + 0.12, -66)), B.Palette.Sand, Enum.Material.Pebble)
			for n, x in ipairs({-110, -72, 65, 105}) do
				B.house(root, CFrame.new(pos(x, top, 80 + (n % 2) * 40)), n % 2 == 0 and accent or C(187, 105, 65), 26, 25)
			end
			B.house(root, CFrame.new(pos(-108, top, -4)), C(75, 96, 124), 42, 35)
			B.disc(root, "Dojo extérieur", pos(-88, top + 0.2, -66), 28, 0.4, C(173, 144, 96), Enum.Material.WoodPlanks)
			World.TrainingPosition = pos(-88, top + 4, -66)
			local _, masterRoot = B.npc(root, "Ren · maître d'armes", pos(-83, top + 3, 27), C(68, 94, 114))
			World.Master = {Root = masterRoot, Prompt = B.prompt(masterRoot, "Étudier les styles", "Maître Ren")}
			for n = 1, 6 do
				B.lantern(root, pos(n % 2 == 0 and -17 or 17, top, 20 + n * 20))
			end
			-- Lighthouse silhouette west of the village.
			B.disc(root, "Phare", pos(-162, top + 23, 57), 12, 46, B.Palette.Cream, Enum.Material.Brick)
			B.disc(root, "Balcon du phare", pos(-162, top + 45, 57), 16, 3, accent, Enum.Material.Metal)
			B.disc(root, "Lumière du phare", pos(-162, top + 50, 57), 7, 7, B.Palette.Gold, Enum.Material.Neon)
		elseif island.Id == "Jungle" then
			B.tree(root, pos(-62, top, -122), 4.5, true)
			for n = 1, 5 do
				B.part(root, "Colonne ancienne", V(5, 18 + n % 3 * 5, 5), CFrame.new(pos(-50 - n * 17, top + 8, 25)), C(127, 141, 116), Enum.Material.Cobblestone)
			end
			B.boat(root, CFrame.new(pos(-120, top + 1, 93)) * CFrame.Angles(0, 0.4, 0.25), accent, 1.2)
			local _, sageRoot = B.npc(root, "Ena · chercheuse des fruits", pos(-45, top + 3, 74), C(141, 103, 157))
			World.FruitNPC = {Root = sageRoot, Prompt = B.prompt(sageRoot, "Le fruit des Braises", "Chercheuse Ena")}
			B.part(root, "Cascade", V(14, 60, 2), CFrame.new(pos(-162, top + 20, -85)), C(94, 187, 207), Enum.Material.Glass).Transparency = 0.35
		elseif island.Id == "Fort" then
			for _, x in ipairs({-150, 150}) do
				B.part(root, "Rempart", V(9, 28, 260), CFrame.new(pos(x, top + 14, -38)), C(148, 148, 137), Enum.Material.Brick)
				for _, z in ipairs({-166, 88}) do
					B.disc(root, "Tour", pos(x, top + 22, z), 18, 44, C(142, 144, 134), Enum.Material.Brick)
					B.disc(root, "Couronne de tour", pos(x, top + 45, z), 22, 4, accent, Enum.Material.Metal)
				end
			end
			for _, x in ipairs({-89, 89}) do
				B.part(root, "Porte latérale", V(122, 24, 7), CFrame.new(pos(x, top + 12, 60)), C(143, 141, 130), Enum.Material.Brick)
			end
			B.part(root, "Arche d'entrée", V(65, 8, 9), CFrame.new(pos(0, top + 28, 60)), accent, Enum.Material.Brick)
			B.house(root, CFrame.new(pos(-77, top, -37)), accent, 44, 40)
		else
			for _, x in ipairs({-50, 50}) do
				B.part(root, "Pilier du sanctuaire", V(5, 38, 5), CFrame.new(pos(x, top + 19, -104)), C(106, 82, 101), Enum.Material.Slate)
			end
			B.part(root, "Portique", V(116, 6, 10), CFrame.new(pos(0, top + 39, -104)), accent, Enum.Material.Wood)
			B.disc(root, "Cercle de volonté", pos(0, top + 0.25, -155), 36, 0.5, C(139, 126, 153), Enum.Material.Slate)
			B.house(root, CFrame.new(pos(-86, top, 82)), C(83, 86, 134), 36, 32)
		end
		task.wait()
	end
	local stamp = Instance.new("StringValue")
	stamp.Name, stamp.Value, stamp.Parent = "WorldVersion", Config.Version, folder
	return World.bind(folder)
end
return World
