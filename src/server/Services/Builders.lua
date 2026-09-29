-- Original low-poly scenery, generated from native Roblox primitives.
local B = {}
local V = Vector3.new
local C = Color3.fromRGB
B.Palette = {Wood = C(112, 78, 52), DarkWood = C(65, 49, 40), Sand = C(219, 201, 151), Rock = C(83, 98, 103), Cream = C(231, 222, 195), Gold = C(227, 177, 75)}
function B.part(parent, name, size, cf, color, material, class)
	local part = Instance.new(class or "Part")
	part.Name, part.Size, part.CFrame = name, size, cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
function B.decor(part)
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	return part
end
function B.disc(parent, name, position, radius, height, color, material)
	local p = B.part(parent, name, V(height, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
function B.ball(parent, name, position, size, color, material)
	local p = B.part(parent, name, size, CFrame.new(position), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end
function B.beam(parent, name, from, to, width, color, material)
	local delta = to - from
	return B.part(parent, name, V(width, width, delta.Magnitude), CFrame.lookAt((from + to) / 2, to), color, material)
end
function B.label(part, title, subtitle, color, distance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromOffset(250, 65)
	gui.StudsOffsetWorldSpace = V(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = distance or 75
	gui.Adornee, gui.Parent = part, part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = title .. (subtitle and ("\n" .. subtitle) or "")
	text.TextColor3 = color or B.Palette.Cream
	text.TextStrokeTransparency = 0.5
	text.Font = Enum.Font.GothamBold
	text.TextSize = 15
	text.Parent = gui
	return text
end
function B.prompt(parent, text, object)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = true
	prompt.HoldDuration = 0.15
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end
function B.tree(parent, position, scale, jungle)
	local top = position + V(scale * 1.8, scale * 15, 0)
	B.beam(parent, "Tronc", position, top, scale * 2.3, B.Palette.Wood, Enum.Material.Wood)
	if jungle then
		B.decor(B.ball(parent, "Canopée", top, V(20, 11, 18) * scale, C(35, 93, 63), Enum.Material.Grass))
		B.decor(B.ball(parent, "Feuillage", top + V(3, 5, -2) * scale, V(14, 9, 13) * scale, C(56, 124, 77), Enum.Material.Grass))
	else
		for i = 1, 6 do
			local angle = i * math.pi / 3
			local endPosition = top + V(math.cos(angle) * 12, -3, math.sin(angle) * 12) * scale
			B.decor(B.beam(parent, "Palme", top + V(0, 2, 0), endPosition, 3.2 * scale, C(48, 125, 76), Enum.Material.Grass))
		end
	end
end
function B.lantern(parent, position)
	B.part(parent, "Mât", V(0.7, 9, 0.7), CFrame.new(position + V(0, 4.5, 0)), B.Palette.DarkWood, Enum.Material.Wood)
	local lamp = B.decor(B.part(parent, "Lanterne", V(1.7, 2.5, 1.7), CFrame.new(position + V(0, 9, 0)), C(255, 208, 113), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = lamp.Color, 18, 0.6
	light.Parent = lamp
end
function B.house(parent, cf, color, width, depth)
	local p = B.Palette
	local w, d = width or 25, depth or 23
	B.part(parent, "Fondation", V(w + 2, 1, d + 2), cf * CFrame.new(0, 0.5, 0), p.Rock, Enum.Material.Slate)
	-- Open doorway: side/back walls and two front panels, never a solid building block.
	B.part(parent, "Mur", V(w, 17, 1), cf * CFrame.new(0, 9, -d / 2), p.Cream, Enum.Material.Plaster)
	for _, x in ipairs({-w / 2, w / 2}) do
		B.part(parent, "Mur", V(1, 17, d), cf * CFrame.new(x, 9, 0), p.Cream, Enum.Material.Plaster)
		B.part(parent, "Poutre", V(1.2, 19, 1.2), cf * CFrame.new(x, 9.5, d / 2), p.Wood, Enum.Material.Wood)
	end
	for _, side in ipairs({-1, 1}) do
		B.part(parent, "Façade", V((w - 7) / 2, 17, 1), cf * CFrame.new(side * (w + 7) / 4, 9, d / 2), p.Cream, Enum.Material.Plaster)
		local window = B.decor(B.part(parent, "Fenêtre", V(5, 5, 0.3), cf * CFrame.new(side * w * 0.32, 11, d / 2 + 0.6), C(82, 151, 166), Enum.Material.Glass))
		window.Transparency = 0.12
		B.part(parent, "Toit", V(w / 2 + 2.5, 1.3, d + 5), cf * CFrame.new(side * w / 4, 20, 0) * CFrame.Angles(0, 0, -side * math.rad(22)), color, Enum.Material.WoodPlanks)
	end
	B.part(parent, "Linteau", V(7, 5, 1), cf * CFrame.new(0, 15, d / 2), p.Wood, Enum.Material.Wood)
	B.part(parent, "Cheminée", V(3, 11, 3), cf * CFrame.new(-w / 3, 23, -d / 4), p.Rock, Enum.Material.Brick)
end
function B.boat(parent, cf, accent, scale)
	local s = scale or 1
	B.part(parent, "Coque", V(15, 3, 33) * s, cf, B.Palette.DarkWood, Enum.Material.WoodPlanks)
	B.part(parent, "Pont", V(13, 1, 29) * s, cf * CFrame.new(0, 2 * s, 0), B.Palette.Wood, Enum.Material.WoodPlanks)
	for _, side in ipairs({-1, 1}) do
		B.part(parent, "Bastingage", V(1, 4, 31) * s, cf * CFrame.new(side * 7 * s, 3 * s, 0), B.Palette.DarkWood, Enum.Material.Wood)
	end
	B.part(parent, "Mât", V(0.8, 35, 0.8) * s, cf * CFrame.new(0, 17 * s, 0), B.Palette.Wood, Enum.Material.Wood)
	B.decor(B.part(parent, "Grand-voile", V(20, 22, 0.35) * s, cf * CFrame.new(0, 22 * s, 0), B.Palette.Cream, Enum.Material.Fabric))
	B.decor(B.part(parent, "Bande de voile", V(20.1, 2.5, 0.45) * s, cf * CFrame.new(0, 26 * s, 0), accent, Enum.Material.Fabric))
end
function B.npc(parent, name, position, coat)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	local cf = CFrame.new(position)
	local torso = B.part(model, "Torso", V(2.2, 2.4, 1.2), cf, coat, Enum.Material.Fabric)
	local head = B.part(model, "Head", V(1.8, 1.8, 1.8), cf * CFrame.new(0, 2.1, 0), C(211, 169, 127))
	head.Shape = Enum.PartType.Ball
	B.part(model, "Hat", V(2.5, 0.6, 2.4), cf * CFrame.new(0, 3.05, 0), B.Palette.DarkWood)
	for _, side in ipairs({-1, 1}) do
		B.part(model, "Arm", V(0.9, 2.3, 1), cf * CFrame.new(side * 1.65, 0, 0), coat, Enum.Material.Fabric)
		B.part(model, "Leg", V(1, 2.2, 1), cf * CFrame.new(side * 0.57, -2.2, 0), C(51, 63, 78))
	end
	model.PrimaryPart = torso
	B.label(head, name, "[E] Parler", B.Palette.Gold)
	return model, torso
end
return B
