local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent:WaitForChild("UI"))
local Config = require(ReplicatedStorage:WaitForChild("ArchipelagoShared"):WaitForChild("Config"))
local Rules = require(ReplicatedStorage:WaitForChild("ArchipelagoShared"):WaitForChild("Rules"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local request = remotes:WaitForChild("Request")
local palette = UI.Colors
local profile, modal, page = nil, nil, nil
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ArchipelagoHUD", false, 10
gui.Parent = player:WaitForChild("PlayerGui")
local canvas = UI.frame(gui, "Canvas", 0, 0, 1280, 800)
canvas.BackgroundTransparency, canvas.AnchorPoint, canvas.Position = 1, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
local scale = Instance.new("UIScale", canvas)
local function fit()
	local camera = workspace.CurrentCamera
	if camera then scale.Scale = math.min(camera.ViewportSize.X / 1280, (camera.ViewportSize.Y - 40) / 800) end
end
fit()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
local title = UI.text(canvas, "LES MERS LIBRES", 24, 17, 390, 30, 22, palette.Gold, true)
local region = UI.text(canvas, "Port Brise-Azur", 24, 46, 440, 24, 14, palette.Muted)
local vitals = UI.round(UI.frame(canvas, "Progression", 24, 83, 274, 80), 12)
UI.stroke(vitals)
local levelText = UI.text(vitals, "CHARGEMENT…", 14, 9, 250, 22, 15, palette.Text, true)
local xpText = UI.text(vitals, "", 14, 33, 245, 17, 10, palette.Muted)
local xpBar = UI.bar(vitals, 14, 58, 246, 5, palette.Gold)
local questPanel = UI.round(UI.frame(canvas, "Quest", 923, 83, 332, 180), 12)
UI.stroke(questPanel)
UI.text(questPanel, "JOURNAL DE BORD", 16, 12, 292, 20, 12, palette.Gold, true)
local questTitle = UI.text(questPanel, "Ton aventure commence", 16, 38, 300, 40, 17, palette.Text, true)
local questBody = UI.text(questPanel, "Parle à Alma sur la place du port. Approche-toi et appuie sur [E].", 16, 82, 300, 70, 14, palette.Muted)
local coins = UI.text(canvas, "0 pièces", 950, 276, 300, 28, 18, palette.Gold, true)
coins.TextXAlignment = Enum.TextXAlignment.Right
local hakiPanel = UI.round(UI.frame(canvas, "Haki", 24, 665, 325, 74), 12)
local hakiText = UI.text(hakiPanel, "Observation à débloquer", 14, 8, 298, 22, 13, palette.Text)
local armamentText = UI.text(hakiPanel, "Armement à débloquer", 14, 39, 298, 20, 12, palette.Muted)
local status = UI.text(canvas, "Connexion…", 902, 744, 354, 24, 11, palette.Muted)
status.TextXAlignment = Enum.TextXAlignment.Right
local controls = UI.text(canvas, "Clic : attaque   R : lourde / recharge   Q : dash   F : esquive   H : Haki   Z : fruit", 357, 535, 900, 20, 12, palette.Muted)
local styleButtons = {}
local ammo = UI.text(canvas, "", 465, 637, 400, 23, 13, palette.Gold)
ammo.TextXAlignment = Enum.TextXAlignment.Center
for _, element in ipairs({title, region, vitals, questPanel, coins, hakiPanel, status, controls, ammo}) do
	element.Visible = false
end
local notification = UI.round(UI.frame(canvas, "Notification", 365, 84, 550, 62), 10)
notification.Visible = false
local notificationText = UI.text(notification, "", 18, 6, 514, 50, 16, palette.Text, true)
local notifyToken = 0
local function notify(message)
	notifyToken += 1
	local token = notifyToken
	notificationText.Text, notification.Visible = message, true
	task.delay(4, function() if notifyToken == token then notification.Visible = false end end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(notify)
local function close()
	if modal then modal:Destroy() end
	modal, page = nil, nil
	player:SetAttribute("MenuOpen", false)
end
local function open(title, subtitle, kind)
	close()
	page = kind
	player:SetAttribute("MenuOpen", true)
	modal = UI.round(UI.frame(canvas, "Menu", 265, 172, 750, 482), 14)
	UI.stroke(modal)
	UI.text(modal, title, 24, 18, 645, 32, 23, palette.Gold, true)
	UI.text(modal, subtitle, 24, 56, 690, 44, 14, palette.Muted)
	UI.button(modal, "×", 691, 15, 38, 38, close)
	return modal
end
local function refresh()
	if not profile then return end
	levelText.Text = "NIVEAU " .. profile.Level .. "  ·  " .. Config.Styles[profile.Style].Name
	coins.Text = profile.Coins .. " pièces"
	xpText.Text = profile.Level == Config.MaxLevel and "NIVEAU MAX DU PROTOTYPE" or (profile.XP .. " / " .. profile.NextXP .. " XP")
	xpBar(profile.XP / profile.NextXP)
	status.Text = profile.SaveStatus
	for id, button in pairs(styleButtons) do
		button.BackgroundColor3 = id == profile.Style and Color3.fromRGB(78, 99, 94) or palette.Raised
		button.TextTransparency = profile.Owned[id] and 0 or 0.6
	end
	if profile.Quest then
		local q = Config.Quests[profile.Quest.Id]
		questTitle.Text = q.Name
		questBody.Text = profile.Quest.Progress >= q.Count and "Objectif terminé. Retourne voir le PNJ sur l'île pour recevoir ta récompense."
			or (Config.Enemies[q.Target].Name .. "  " .. profile.Quest.Progress .. "/" .. q.Count .. "\n" .. q.Text)
	else
		questTitle.Text = "Une mer à découvrir"
		questBody.Text = "[E] Parler aux PNJ · [M] Carte\nQuêtes près des places d'arrivée. Le passeur t'attend au bout de chaque jetée."
	end
end
remotes:WaitForChild("State").OnClientEvent:Connect(function(snapshot) profile = snapshot; refresh() end)
local function showQuests(dialogue)
	if not profile then return end
	local panel = open(dialogue.Title, "Termine l'objectif puis reviens réclamer l'XP et la récompense.", "Quest")
	for index, id in ipairs(dialogue.Offers) do
		local q = Config.Quests[id]
		local card = UI.round(UI.frame(panel, id, 24, 115 + (index - 1) * 148, 702, 136, palette.Raised), 10)
		UI.text(card, q.Name, 16, 7, 510, 26, 17, palette.Text, true)
		UI.text(card, "Niv. " .. q.Level .. " · " .. q.XP .. " XP · " .. q.Coins .. " pièces", 16, 36, 500, 20, 12, palette.Gold)
		UI.text(card, q.Text, 16, 61, 506, 62, 13, palette.Muted)
		local active = profile.Quest and profile.Quest.Id == id
		local complete = active and profile.Quest.Progress >= q.Count
		local actionText = complete and "RÉCOMPENSE" or (active and (profile.Quest.Progress .. "/" .. q.Count) or "ACCEPTER")
		UI.button(card, actionText, 531, 43, 154, 46, function()
			if complete then request:FireServer("TurnInQuest", id); close()
			elseif not active then request:FireServer("AcceptQuest", id); close() end
		end, complete and Color3.fromRGB(61, 111, 98) or palette.Panel)
	end
	if profile.Quest then UI.button(panel, "Abandonner la quête en cours", 24, 419, 300, 40, function() request:FireServer("AbandonQuest"); close() end) end
end
local function showFerry(dialogue)
	if not profile then return end
	local panel = open("TRAVERSÉES", "Passage gratuit. Choisis une île adaptée à ton niveau.", "Ferry")
	for i, island in ipairs(Config.Islands) do
		local label = island.Name .. "   ·   niv. " .. island.Level
		if island.Id == dialogue.Island then label ..= "   ·   vous êtes ici" end
		UI.button(panel, label, 24, 112 + (i - 1) * 81, 702, 65, function()
			request:FireServer("Travel", island.Id, dialogue.Island)
			close()
		end, profile.Level >= island.Level and palette.Raised or Color3.fromRGB(38, 41, 48))
	end
end
local function showStyles()
	if not profile then return end
	local panel = open("LA FORCE DE TA VOLONTÉ", "Le fruit est facultatif. Les maîtrises progressent en infligeant des dégâts aux ennemis.", "Styles")
	for i, style in ipairs({"Fists", "Sword", "Gun"}) do
		local text = Config.Styles[style].Name .. " · maîtrise " .. profile.Mastery[style]
		if not profile.Owned[style] then text ..= " · verrouillé" end
		UI.button(panel, text, 24, 113 + (i - 1) * 51, 348, 42, function() request:FireServer("Equip", style); close() end)
	end
	UI.text(panel, "DÉBLOCAGES\nPillards du port → sabre\nBrisecoque → Armement\nÉcumeurs → pistolet\nGardien → Observation", 399, 112, 313, 148, 14, palette.Muted)
	UI.text(panel, "ARMEMENT [H] · Concentration : +30 % dégâts. Garde : −30 % dégâts subis. L'énergie limite la durée.\nOBSERVATION [F] · Trois charges, réaction au signal. Le dojo permet de s'entraîner avant le déblocage.", 24, 283, 696, 96, 14, palette.Text)
	UI.button(panel, "PvP : " .. (player:GetAttribute("PvPEnabled") and "ACTIVÉ" or "DÉSACTIVÉ"), 24, 409, 340, 44, function()
		request:FireServer("PvP", not player:GetAttribute("PvPEnabled")); close()
	end)
	UI.text(panel, "Le PvP exige l'accord des deux joueurs et reste désactivé près des arrivées.", 389, 403, 323, 56, 12, palette.Muted)
end
local function showFruit(dialogue)
	local panel = open(dialogue.Title, "Une voie possible, pas une obligation.", "Fruit")
	UI.text(panel, "LE FRUIT DES BRAISES", 24, 124, 680, 35, 22, palette.Text, true)
	UI.text(panel, "Après « Écouter la forêt », tu peux choisir ce fruit. Tu construis ensuite tes techniques : projectile, zone, rempart ou propulsion, avec puissance, taille et portée réglables.\n\nChaque réglage modifie le coût et l'efficacité. La mer inflige davantage de dégâts aux utilisateurs de fruit.", 24, 173, 680, 166, 17, palette.Muted)
	UI.button(panel, "Choisir le fruit des Braises", 24, 383, 680, 56, function() request:FireServer("ConsumeFruit"); close() end)
end
local function showTechnique()
	if not profile then return end
	local panel = open("ATELIER DES TECHNIQUES", "Choisis une forme et répartis tes réglages. [Z] pour utiliser ta technique.", "Technique")
	if not profile.Fruit then
		UI.text(panel, "Tu n'as pas encore choisi de fruit.\nEna t'attend dans la Futaie des Épaves, après la quête du Gardien.\n\nTu peux poursuivre toute la progression avec les armes et le Haki.", 28, 133, 687, 195, 19, palette.Text)
		return
	end
	local draft = table.clone(profile.Technique)
	local statsText = UI.text(panel, "", 391, 172, 315, 158, 17, palette.Gold)
	local values, buttons = {}, {}
	local function preview()
		local stats = Rules.techniqueStats(draft)
		statsText.Text = "COÛT  " .. stats.Cost .. " énergie\nDÉGÂTS DE BASE  " .. math.floor(stats.Damage) .. "\nRAYON  " .. stats.Radius .. "\nPORTÉE  " .. stats.Range .. "\nRECHARGE  " .. string.format("%.1f s", stats.Cooldown)
		if draft.Shape == "Propulsion" then statsText.Text = "COÛT  " .. stats.Cost .. " énergie\nVITESSE  " .. stats.Speed .. "\nDURÉE  " .. string.format("%.2f s", stats.Duration) .. "\nUne propulsion aérienne avant de retoucher le sol."
		elseif draft.Shape == "Rempart" then statsText.Text = "COÛT  " .. stats.Cost .. " énergie\nLARGEUR  " .. (5 + draft.Size * 4) .. "\nDISTANCE  " .. stats.Range .. "\nDURÉE  " .. string.format("%.1f s", stats.Duration) .. "\nUn rempart actif à la fois." end
		for key, label in pairs(values) do label.Text = tostring(draft[key]) end
		for shape, button in pairs(buttons) do button.BackgroundColor3 = draft.Shape == shape and Color3.fromRGB(107, 89, 61) or palette.Raised end
	end
	for i, shape in ipairs(Config.Fruit.Shapes) do
		buttons[shape] = UI.button(panel, shape, 24 + (i - 1) * 177, 112, 171, 42, function() draft.Shape = shape; preview() end)
	end
	for i, key in ipairs({"Power", "Size", "Reach"}) do
		local name = ({Power = "Puissance", Size = "Taille", Reach = "Portée"})[key]
		local y = 185 + (i - 1) * 56
		UI.text(panel, name, 24, y, 142, 36, 17, palette.Text)
		UI.button(panel, "−", 175, y, 42, 36, function() draft[key] = math.max(1, draft[key] - 1); preview() end)
		values[key] = UI.text(panel, "", 230, y, 40, 36, 20, palette.Gold, true)
		UI.button(panel, "+", 282, y, 42, 36, function() draft[key] = math.min(3, draft[key] + 1); preview() end)
	end
	UI.text(panel, "Une zone plus large dilue la puissance. Plus de portée, de taille ou de puissance coûte davantage d'énergie.", 24, 354, 691, 48, 14, palette.Muted)
	UI.button(panel, "ENREGISTRER LA TECHNIQUE", 24, 414, 702, 44, function() request:FireServer("Technique", draft); close() end)
	preview()
end
local function showMap()
	local panel = open("CARTE DE L'ARCHIPEL", "Voyage avec le passeur de chaque port. Quatre étapes vers les mers suivantes.", "Map")
	local chart = UI.round(UI.frame(panel, "Chart", 24, 109, 702, 292, Color3.fromRGB(28, 66, 83)), 10)
	local selected = UI.text(panel, "Choisis une île pour lire son nom et son niveau conseillé.", 24, 414, 702, 45, 15, palette.Gold)
	for _, island in ipairs(Config.Islands) do
		local x = (island.Position[1] + 1150) / 2400 * 650 + 25
		local y = (island.Position[3] + 1830) / 2250 * 244 + 18
		local button = UI.button(chart, island.Level .. "+", x - 26, y - 21, 66, 45, function()
			selected.Text = island.Name .. " · Niv. " .. island.Level .. "\n" .. island.Subtitle
		end, Color3.fromRGB(table.unpack(island.Color)))
		UI.round(button, 22)
		UI.text(chart, island.Name, x - 71, y + 27, 154, 25, 10, palette.Text, true).TextXAlignment = Enum.TextXAlignment.Center
	end
end
local function showInventory()
	if not profile then return end
	local panel = open("SAC", "Tes équipements et maîtrises actuelles.", "Inventory")
	local owned = {}
	for _, id in ipairs({"Fists", "Sword", "Gun"}) do
		if profile.Owned[id] then table.insert(owned, Config.Styles[id].Name .. " · maîtrise " .. profile.Mastery[id]) end
	end
	UI.text(panel, "ÉQUIPEMENT\n" .. table.concat(owned, "\n"), 28, 118, 330, 180, 18, palette.Text)
	UI.text(panel, "TRÉSOR\n" .. profile.Coins .. " pièces\n\nFRUIT\n" .. (profile.Fruit or "Aucun fruit"), 397, 118, 315, 180, 18, palette.Gold)
	UI.button(panel, "STYLES ET HAKI", 28, 389, 320, 52, showStyles)
	UI.button(panel, "TECHNIQUE DE FRUIT", 390, 389, 322, 52, showTechnique)
end
local function showShop()
	local panel = open("BOUTIQUE", "La boutique du port proposera des objets achetés avec les pièces gagnées en jeu.", "Shop")
	UI.text(panel, "La boutique est en construction.\nAucun achat payant n'est actif.", 28, 155, 694, 120, 23, palette.Text, true).TextXAlignment = Enum.TextXAlignment.Center
	UI.text(panel, "Tes pièces actuelles : " .. (profile and profile.Coins or 0), 28, 294, 694, 45, 18, palette.Gold, true).TextXAlignment = Enum.TextXAlignment.Center
end
local helpVisible = true
local function showSettings()
	local panel = open("RÉGLAGES", "Réglages locaux de l'interface.", "Settings")
	local helpButton
	helpButton = UI.button(panel, "AIDE DES TOUCHES : " .. (helpVisible and "VISIBLE" or "MASQUÉE"), 28, 125, 694, 56, function()
		helpVisible = not helpVisible
		controls.Visible = helpVisible
		helpButton.Text = "AIDE DES TOUCHES : " .. (helpVisible and "VISIBLE" or "MASQUÉE")
	end)
	UI.button(panel, "FERMER TOUS LES MENUS", 28, 205, 694, 56, close)
end

-- Interface principale inspirée du dessin fourni : commandes et jauges en bas au centre.
local dock = UI.round(UI.frame(canvas, "MainDock", 410, 594, 460, 66, Color3.fromRGB(20, 25, 29)), 18)
UI.stroke(dock, Color3.fromRGB(204, 170, 91)).Transparency = 0.2
local dockGradient = Instance.new("UIGradient")
dockGradient.Color = ColorSequence.new(Color3.fromRGB(39, 45, 49), Color3.fromRGB(17, 21, 25))
dockGradient.Rotation, dockGradient.Parent = 90, dock
local dockButtons = {
	{"SAC", "Sac", showInventory}, {"BOUTIQUE", "Boutique", showShop},
	{"CARTE", "Carte", showMap}, {"RÉGLAGES", "Réglages", showSettings},
}
for i, definition in ipairs(dockButtons) do
	local button = UI.button(dock, definition[1], 8 + (i - 1) * 112, 7, 108, 52, definition[3], Color3.fromRGB(31, 37, 42))
	button.Name, button.TextSize, button.TextColor3 = definition[2], 12, Color3.fromRGB(226, 208, 161)
	UI.stroke(button, Color3.fromRGB(204, 170, 91)).Transparency = 0.62
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(64, 57, 42), TextColor3 = Color3.fromRGB(255, 237, 184)}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(31, 37, 42), TextColor3 = Color3.fromRGB(226, 208, 161)}):Play()
	end)
end
local energyTrack = UI.round(UI.frame(canvas, "EnergyTrack", 430, 666, 420, 27, Color3.fromRGB(24, 36, 42)), 8)
local energyFill = UI.round(UI.frame(energyTrack, "Fill", 0, 0, 420, 27, Color3.fromRGB(42, 174, 200)), 8)
energyTrack.ClipsDescendants = true
local energyGradient = Instance.new("UIGradient")
energyGradient.Color = ColorSequence.new(Color3.fromRGB(91, 218, 226), Color3.fromRGB(27, 139, 181))
energyGradient.Parent = energyFill
local energyText = UI.text(energyTrack, "100% ÉNERGIE", 0, 0, 420, 27, 13, Color3.fromRGB(238, 247, 246), true)
energyText.TextXAlignment = Enum.TextXAlignment.Center
local healthTrack = UI.round(UI.frame(canvas, "HealthTrack", 430, 696, 420, 27, Color3.fromRGB(27, 39, 32)), 8)
local healthFill = UI.round(UI.frame(healthTrack, "Fill", 0, 0, 420, 27, Color3.fromRGB(56, 175, 91)), 8)
healthTrack.ClipsDescendants = true
local healthGradient = Instance.new("UIGradient")
healthGradient.Color = ColorSequence.new(Color3.fromRGB(102, 207, 118), Color3.fromRGB(42, 142, 78))
healthGradient.Parent = healthFill
local hpText = UI.text(healthTrack, "100% VIE", 0, 0, 420, 27, 13, Color3.fromRGB(244, 248, 239), true)
hpText.TextXAlignment = Enum.TextXAlignment.Center
local quickbar = UI.round(UI.frame(canvas, "PlayerInventory", 430, 727, 420, 61, Color3.fromRGB(17, 22, 26)), 12)
UI.stroke(quickbar, Color3.fromRGB(247, 221, 75))
styleButtons.Fists = UI.button(quickbar, "1  POINGS", 8, 7, 128, 48, function() request:FireServer("Equip", "Fists") end)
UI.button(quickbar, "2  FRUIT", 146, 7, 128, 48, showTechnique, Color3.fromRGB(107, 89, 61))
styleButtons.Sword = UI.button(quickbar, "3  SABRE", 284, 7, 128, 48, function() request:FireServer("Equip", "Sword") end)
remotes:WaitForChild("Dialogue").OnClientEvent:Connect(function(dialogue)
	if dialogue.Kind == "Quest" then showQuests(dialogue)
	elseif dialogue.Kind == "Ferry" then showFerry(dialogue)
	elseif dialogue.Kind == "Master" then showStyles()
	elseif dialogue.Kind == "Fruit" then showFruit(dialogue) end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.M then if page == "Map" then close() else showMap() end
	elseif input.KeyCode == Enum.KeyCode.B then if page == "Styles" then close() else showStyles() end
	elseif input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.Two then if page == "Technique" then close() else showTechnique() end
	elseif input.KeyCode == Enum.KeyCode.One then request:FireServer("Equip", "Fists")
	elseif input.KeyCode == Enum.KeyCode.Three then request:FireServer("Equip", "Sword") end
end)
local damagePanel = UI.round(UI.frame(canvas, "Damage", 1050, 430, 205, 88), 12)
damagePanel.Visible = false
UI.text(damagePanel, "DÉGÂTS", 14, 8, 180, 18, 11, palette.Gold, true)
local damageLabel = UI.text(damagePanel, "", 14, 27, 180, 45, 29, palette.Text, true)
local damage, hits, lastHit, token = 0, 0, -10, 0
ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("M1Feedback").OnClientEvent:Connect(function(combo, hitCount, _, amount)
	if amount <= 0 then return end
	if os.clock() - lastHit > 1.4 or combo == 1 then damage, hits = 0, 0 end
	damage, hits, lastHit = damage + amount, hits + hitCount, os.clock()
	damageLabel.Text = math.floor(damage + 0.5) .. "  ·  " .. hits .. " coups"
	damagePanel.Visible = false
	token += 1
	local current = token
	task.delay(1.5, function() if token == current then damagePanel.Visible = false end end)
end)
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then return end
	elapsed = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		healthFill.Size = UDim2.new(ratio, 0, 1, 0)
		hpText.Text = math.floor(ratio * 100 + 0.5) .. "% VIE"
	end
	local energy = player:GetAttribute("Energy") or 100
	local energyRatio = math.clamp(energy / 100, 0, 1)
	energyFill.Size = UDim2.new(energyRatio, 0, 1, 0)
	energyText.Text = math.floor(energyRatio * 100 + 0.5) .. "% ÉNERGIE"
	local unlocked = player:GetAttribute("ObservationUnlocked") or player:GetAttribute("ObservationTraining")
	local charge = player:GetAttribute("ObservationCharges") or 3
	local recharge = math.max(0, (player:GetAttribute("ObservationRechargeAt") or 0) - workspace:GetServerTimeNow())
	hakiText.Text = unlocked and ("OBSERVATION  " .. charge .. "/3" .. (charge < 3 and ("  ·  " .. math.ceil(recharge) .. " s") or "") .. (player:GetAttribute("ObservationTraining") and " · dojo" or "")) or "Observation à débloquer"
	local mode = player:GetAttribute("ArmamentMode") or "Off"
	armamentText.Text = player:GetAttribute("ArmamentUnlocked") and ("ARMEMENT [H]  ·  " .. ({Off = "désactivé", Focus = "concentration", Guard = "garde"})[mode]) or "Armement à débloquer"
	ammo.Text = player:GetAttribute("CombatStyle") == "Gun" and (player:GetAttribute("Reloading") and "RECHARGEMENT…" or ("MUNITIONS  " .. (player:GetAttribute("Ammo") or 0) .. "/6  ·  [R] recharger")) or ""
	if root then
		local closest, distance
		for _, island in ipairs(Config.Islands) do
			local gap = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(table.unpack(island.Position))).Magnitude
			if not distance or gap < distance then closest, distance = island, gap end
		end
		region.Text = distance < closest.Radius + 80 and closest.Name or "Au large · " .. closest.Name
	end
end)
player.CharacterAdded:Connect(close)
task.spawn(function()
	while not profile do request:FireServer("State"); task.wait(2) end
end)
