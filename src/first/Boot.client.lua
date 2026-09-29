-- ReplicatedFirst runs even if character spawning or shared modules are blocked.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
while not player do Players:GetPropertyChangedSignal("LocalPlayer"):Wait(); player = Players.LocalPlayer end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.IgnoreGuiInset = "ArchipelagoBoot", false, 1000, true
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 72)
panel.Size, panel.BackgroundColor3, panel.BorderSizePixel = UDim2.new(0.9, 0, 0, 128), Color3.fromRGB(16, 29, 42), 0
panel.Parent = gui
local limit = Instance.new("UISizeConstraint", panel)
limit.MaxSize = Vector2.new(640, 128)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local title = Instance.new("TextLabel")
title.Size, title.Position = UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 12)
title.BackgroundTransparency, title.TextColor3, title.TextSize = 1, Color3.fromRGB(227, 177, 75), 20
title.Font, title.Text, title.Parent = Enum.Font.GothamBold, "LES MERS LIBRES · chargement", panel
local body = Instance.new("TextLabel")
body.Size, body.Position = UDim2.new(1, -28, 0, 72), UDim2.fromOffset(14, 45)
body.BackgroundTransparency, body.TextColor3, body.TextSize = 1, Color3.fromRGB(236, 232, 216), 15
body.Font, body.TextWrapped, body.Parent = Enum.Font.Gotham, true, panel
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
local started = os.clock()
while gui.Parent do
	local phase = ReplicatedStorage:GetAttribute("GameBootStage")
	local failure = ReplicatedStorage:GetAttribute("GameBootError") or player:GetAttribute("StartupError")
	local character = player.Character
	local playerGui = player:FindFirstChild("PlayerGui")
	if not failure and phase == "Ready" and player:GetAttribute("ProfileReady")
		and character and character:FindFirstChild("HumanoidRootPart") and playerGui and playerGui:FindFirstChild("ArchipelagoHUD") then
		gui:Destroy()
		break
	end
	if failure then
		title.Text = "DÉMARRAGE BLOQUÉ"
		body.Text = tostring(failure):sub(1, 220) .. "\nOuvre Sortie / Output pour voir l'erreur complète."
		panel.BackgroundColor3 = Color3.fromRGB(75, 29, 34)
	elseif os.clock() - started > 30 then
		title.Text = "LE CHARGEMENT N'ABOUTIT PAS"
		body.Text = "Arrête Play, synchronise Rojo hors du test puis relance Play.\nSi le problème persiste, ouvre Sortie / Output. Étape : " .. tostring(phase or "serveur non démarré")
	else
		body.Text = ({Services = "Préparation du jeu…", Map = "Préparation de l'archipel…", Gameplay = "Chargement de la progression…",
			Enemies = "Arrivée des habitants et des ennemis…", Ready = "Préparation de ton personnage…"})[phase] or "Connexion au serveur…"
	end
	task.wait(0.25)
end
