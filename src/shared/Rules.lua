-- Pure Luau: shared by authoritative services, HUD previews and CLI tests.
local Rules = {}
function Rules.finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Rules.xpNeeded(level)
	return math.floor(80 + (level - 1) * 32 + (level - 1) ^ 1.45 * 6)
end
function Rules.addXP(level, xp, amount, maxLevel)
	xp += math.max(0, math.floor(amount))
	while level < maxLevel and xp >= Rules.xpNeeded(level) do
		xp -= Rules.xpNeeded(level)
		level += 1
	end
	if level >= maxLevel then xp = 0 end
	return level, xp
end
function Rules.canTakeQuest(profile, quest, questId)
	if profile.Quest then return false, "Termine ou abandonne ta quête actuelle." end
	if profile.Level < quest.Level then return false, "Niveau " .. quest.Level .. " requis." end
	if quest.Requires and not profile.Completed[quest.Requires] then return false, "Termine d'abord la quête précédente." end
	return true
end
function Rules.advanceQuest(quest, definition, enemyId)
	if definition.Target ~= enemyId or quest.Progress >= definition.Count then return false end
	quest.Progress = math.min(definition.Count, quest.Progress + 1)
	return true
end
function Rules.validateTechnique(value)
	if type(value) ~= "table" then return nil end
	if value.Shape ~= "Projectile" and value.Shape ~= "Zone" and value.Shape ~= "Rempart" and value.Shape ~= "Propulsion" then return nil end
	local clean = {Shape = value.Shape}
	for _, key in ipairs({"Power", "Size", "Reach"}) do
		local n = value[key]
		if not Rules.finite(n) or n % 1 ~= 0 or n < 1 or n > 3 then return nil end
		clean[key] = n
	end
	return clean
end
function Rules.techniqueStats(value)
	local t = Rules.validateTechnique(value)
	if not t then return nil end
	return {
		Cost = 10 + t.Power * 6 + t.Size * 4 + t.Reach * 3,
		Damage = (8 + t.Power * 8) / (1 + (t.Size - 1) * 0.2),
		Radius = 2 + t.Size * 3,
		Range = t.Shape == "Zone" and (12 + t.Reach * 10) or (t.Shape == "Rempart" and (6 + t.Reach * 3) or (25 + t.Reach * 25)),
		Cooldown = 2.4 + t.Power * 0.5 + t.Size * 0.3,
		Speed = 30 + t.Power * 12 + t.Reach * 4,
		Duration = t.Shape == "Propulsion" and (0.1 + t.Size * 0.06 + t.Reach * 0.025) or (1 + t.Power * 0.8),
	}
end
function Rules.damage(base, level, mastery, armament)
	local scale = 1 + (level - 1) * 0.045 + math.min(mastery, 1000) * 0.0005
	return math.floor(base * scale * (armament == "Focus" and 1.30 or 1) + 0.5)
end
return Rules
