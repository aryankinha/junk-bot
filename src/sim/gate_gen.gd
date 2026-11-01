class_name GateGen extends RefCounted

static func available(level: int, robot, unlocked: Array = []) -> Array:
	var ids: Array = []
	for id in GameData.table("parts"):
		if (int(GameData.table("parts")[id].unlock_level) <= level or unlocked.has(id)) and int(robot.parts.get(id, 0)) < 3:
			ids.append(id)
	return ids

static func pair(level: int, robot, rng: RandomNumberGenerator, gate_index := 0, unlocked: Array = []) -> Array:
	var ids := available(level, robot, unlocked)
	if ids.size() < 2:
		return [{"kind": "repair"}, {"kind": "scrap", "amount": 25}]
	var first := _weighted(ids, rng)
	if gate_index >= 2:
		var has_weapon := false
		for id in robot.parts:
			has_weapon = has_weapon or GameData.table("parts")[id].category == "weapon"
		if not has_weapon:
			var weapons: Array = ids.filter(func(id): return GameData.table("parts")[id].category == "weapon")
			if not weapons.is_empty():
				first = _weighted(weapons, rng)
	var others: Array = ids.filter(func(id): return GameData.table("parts")[id].category != GameData.table("parts")[first].category)
	if others.is_empty():
		return [{"kind": "part", "id": first}, {"kind": "repair"}]
	return [{"kind": "part", "id": first}, {"kind": "part", "id": _weighted(others, rng)}]

# Utility lanes that sit beside part gates: heal, coin frenzy, overdrive charge.
static func utility(rng: RandomNumberGenerator) -> Dictionary:
	return [{"kind": "heal", "pct": 0.35}, {"kind": "frenzy"}, {"kind": "surge"}][rng.randi_range(0, 2)]

# From level 2, some gates grow a third lane so the player trades power for utility.
static func with_extra(options: Array, level: int, index: int, rng: RandomNumberGenerator) -> Array:
	if level >= 2 and index % 2 == 1 and options.size() == 2 and options[0].kind == "part" and options[1].kind == "part":
		options.append(utility(rng))
	return options

static func _weighted(ids: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for id in ids:
		total += int(GameData.table("parts")[id].weight)
	var roll := rng.randi_range(1, total)
	for id in ids:
		roll -= int(GameData.table("parts")[id].weight)
		if roll <= 0:
			return id
	return ids.back()

static func label(option: Dictionary) -> String:
	var id := str(option.get("id", ""))
	match option.kind:
		"part": return GameData.table("parts")[id].name
		"tradeoff": return GameData.table("tradeoffs")[id].name
		"gamble": return "Mystery crate"
		"upgrade_random_owned": return "Merge part"
		"repair": return "Repair · 20"
		"reroll": return "Re-roll · FREE"
		"buy": return "Buy part · 35"
		"scrap": return "+25 Scrap"
		"heal": return "Quick repair"
		"frenzy": return "Coin frenzy"
		"surge": return "Overdrive"
	return "Upgrade"

static func description(option: Dictionary) -> String:
	var id := str(option.get("id", ""))
	if option.kind == "tradeoff":
		return GameData.table("tradeoffs")[id].desc
	if option.kind == "part":
		return {"wheels": "+ SPEED", "tracks": "+ HP · OIL IMMUNE", "cannon": "+ FIREPOWER", "rocket": "BYPASS BOSS PLATE", "flame": "AREA DAMAGE", "armour": "+ HP · RESIST", "shield": "BLOCK A HIT", "magnet": "PULL MORE SCRAP", "storage": "+ SCRAP VALUE"}.get(id, "+ POWER")
	return {"gamble": "75% PART · 25% SCRAP", "upgrade_random_owned": "+1 PART LEVEL", "repair": "HEAL + RESTORE", "reroll": "REPLACE NEXT GATE", "buy": "CHOOSE A NEW PART", "heal": "+35% HP NOW", "frenzy": "12S · COINS x2", "surge": "+50% OVERDRIVE"}.get(option.kind, "+ POWER")
