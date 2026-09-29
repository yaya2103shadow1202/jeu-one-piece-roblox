-- All progression/world definitions are owned by the server. No external model scripts.
local Config = {}
Config.Version = "Archipel 0.2.1"
Config.MaxLevel = 30
Config.SeaLevel = 0
Config.Observation = {Window = 0.25, NetworkMargin = 0.12, Charges = 3, Recharge = 7, InputCooldown = 0.18}
Config.Styles = {
	Fists = {Name = "Poings", Cooldown = 0.52, Windup = 0.40, Damage = {5, 5, 6, 9}, Range = 6, Width = 5.5},
	Sword = {Name = "Sabre", Cooldown = 0.64, Windup = 0.44, Damage = {7, 7, 8, 12}, Range = 8, Width = 6},
	Gun = {Name = "Pistolet", Cooldown = 1.25, Windup = 0.42, Damage = {16}, Range = 120, Width = 2},
}
Config.Islands = {
	{Id = "Port", Name = "Port Brise-Azur", Subtitle = "Le premier départ", Position = {0, 0, 0}, Radius = 235,
		Level = 1, Top = 10, Color = {86, 151, 96}, Accent = {50, 139, 171}, Dock = {0, 7, 275}, Spawn = {0, 14, 95},
		QuestNPC = {Name = "Alma · capitaine du port", Position = {-20, 13, 75}},
		Enemy = "Bandit", EnemyCenter = {100, 13, -60}, Boss = "Brisecoque", BossPosition = {0, 13, -150}, Quest = "PortBandits"},
	{Id = "Jungle", Name = "Futaie des Épaves", Subtitle = "Sous les racines, les secrets", Position = {-830, 0, -620}, Radius = 240,
		Level = 5, Top = 12, Color = {42, 108, 73}, Accent = {212, 150, 72}, Dock = {0, 7, 280}, Spawn = {0, 16, 115},
		QuestNPC = {Name = "Silo · éclaireur", Position = {-22, 15, 112}},
		Enemy = "Raider", EnemyCenter = {85, 15, -30}, Boss = "Gardien", BossPosition = {0, 15, -145}, Quest = "JungleRaiders"},
	{Id = "Fort", Name = "Citadelle Écarlate", Subtitle = "La volonté face aux canons", Position = {880, 0, -670}, Radius = 230,
		Level = 12, Top = 14, Color = {126, 135, 110}, Accent = {167, 62, 61}, Dock = {0, 7, 270}, Spawn = {0, 18, 110},
		QuestNPC = {Name = "Nara · résistante", Position = {-22, 17, 108}},
		Enemy = "Guard", EnemyCenter = {80, 17, -40}, Boss = "Commandant", BossPosition = {0, 17, -135}, Quest = "FortGuards"},
	{Id = "Storm", Name = "Crête du Tonnerre", Subtitle = "La mer n'arrête pas les rêves", Position = {60, 0, -1570}, Radius = 250,
		Level = 20, Top = 18, Color = {85, 105, 122}, Accent = {145, 140, 221}, Dock = {0, 7, 290}, Spawn = {0, 22, 130},
		QuestNPC = {Name = "Kael · veilleur", Position = {-22, 21, 125}},
		Enemy = "Ronin", EnemyCenter = {90, 21, -40}, Boss = "Tempete", BossPosition = {0, 21, -155}, Quest = "StormRonin"},
}
Config.Enemies = {
	Bandit = {Name = "Pillard du port", Level = 1, HP = 48, Damage = 5, XP = 18, Coins = 12, Style = "Fists", Color = {123, 80, 61}},
	Brisecoque = {Name = "Brisecoque", Level = 4, HP = 190, Damage = 9, XP = 95, Coins = 75, Style = "Fists", Boss = true, Color = {141, 61, 49}},
	Raider = {Name = "Écumeur des épaves", Level = 6, HP = 100, Damage = 10, XP = 48, Coins = 24, Style = "Sword", Color = {81, 103, 66}},
	Gardien = {Name = "Gardien des racines", Level = 10, HP = 420, Damage = 17, XP = 230, Coins = 150, Style = "Sword", Boss = true, Color = {56, 93, 69}},
	Guard = {Name = "Fusilier écarlate", Level = 13, HP = 155, Damage = 14, XP = 95, Coins = 40, Style = "Gun", Color = {121, 61, 62}},
	Commandant = {Name = "Commandant Varek", Level = 18, HP = 700, Damage = 24, XP = 460, Coins = 250, Style = "Sword", Boss = true, Color = {57, 68, 94}},
	Ronin = {Name = "Lame de l'orage", Level = 21, HP = 240, Damage = 23, XP = 160, Coins = 60, Style = "Sword", Color = {70, 79, 108}},
	Tempete = {Name = "L'Amiral de la tempête", Level = 28, HP = 1100, Damage = 32, XP = 900, Coins = 500, Style = "Sword", Boss = true, Color = {85, 65, 128}},
}
Config.Quests = {
	PortBandits = {Name = "Rendre le port aux habitants", Text = "Les pillards bloquent la colline au nord-est. Repousse-les puis reviens me voir.", Island = "Port", Target = "Bandit", Count = 4, Level = 1, XP = 110, Coins = 80, Unlock = "Sword", Next = "PortBoss"},
	PortBoss = {Name = "Le poing de Brisecoque", Text = "Leur chef t'attend dans l'arène au nord. Montre-lui ce que vaut ta volonté.", Island = "Port", Target = "Brisecoque", Count = 1, Level = 3, XP = 250, Coins = 160, Requires = "PortBandits", Unlock = "Armament"},
	JungleRaiders = {Name = "La route des naufragés", Text = "Les écumeurs occupent les ruines à l'est. Ouvre une route pour les survivants.", Island = "Jungle", Target = "Raider", Count = 5, Level = 5, XP = 280, Coins = 160, Unlock = "Gun", Next = "JungleBoss"},
	JungleBoss = {Name = "Écouter la forêt", Text = "Affronte le gardien au pied du grand arbre. Anticipe ses coups au lieu de tout encaisser.", Island = "Jungle", Target = "Gardien", Count = 1, Level = 8, XP = 560, Coins = 250, Requires = "JungleRaiders", Unlock = "Observation"},
	FortGuards = {Name = "Briser le blocus", Text = "Les fusiliers tiennent la cour est. Profite des murs pour te protéger des tirs.", Island = "Fort", Target = "Guard", Count = 5, Level = 12, XP = 650, Coins = 300, Next = "FortBoss"},
	FortBoss = {Name = "Le prix de la liberté", Text = "Varek garde la cour intérieure, au nord. Son sabre frappe loin : garde une sortie.", Island = "Fort", Target = "Commandant", Count = 1, Level = 16, XP = 1050, Coins = 450, Requires = "FortGuards"},
	StormRonin = {Name = "Sous le ciel fendu", Text = "Les ronins gardent l'ascension. Traverse leurs rangs avant de défier l'amiral.", Island = "Storm", Target = "Ronin", Count = 6, Level = 20, XP = 1200, Coins = 500, Next = "StormBoss"},
	StormBoss = {Name = "Une volonté plus forte que l'orage", Text = "L'amiral t'attend au sanctuaire nord. Ton choix de style importe moins que ta maîtrise.", Island = "Storm", Target = "Tempete", Count = 1, Level = 25, XP = 2000, Coins = 900, Requires = "StormRonin"},
}
Config.Fruit = {Name = "Fruit des Braises", RequiredQuest = "JungleBoss", Shapes = {"Projectile", "Zone", "Rempart", "Propulsion"}, MaxEnergy = 100}
return Config
