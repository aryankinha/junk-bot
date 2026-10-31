class_name StatCalc extends RefCounted

static func compute(robot) -> Dictionary:
	var c := GameData.constants()
	var chassis: Dictionary = c.chassis[["tiny", "battle", "monster"][robot.stage() - 1]]
	var out := {"max_hp": float(chassis.hp), "steer_mult": float(chassis.steer), "fwd_mult": 1.0, "armor": 0.0, "magnet_radius": float(c.base_magnet_radius), "scrap_mult": 1.0, "oil_immune": false, "shield_charges": 0, "shield_recharge_s": 8.0, "dps_mult": 1.0, "knockback_resist": 0.0, "weapons": []}
	out.weapons.append(c.chassis.tiny.blaster.merged({"type": "projectile", "speed": 36.0, "id": "blaster", "barrels": 1}))
	for id in robot.parts:
		var item: Dictionary = GameData.table("parts")[id].levels[int(robot.parts[id]) - 1]
		var gain: float = 1.0 + (int(robot.tiers.get(id, 1)) - 1) * float(GameData.table("economy").upgrade_stat_gain_per_tier)
		var s: Dictionary = item.get("stats", {})
		out.max_hp += float(s.get("hp_flat", 0)) * gain
		out.fwd_mult += float(s.get("fwd_speed_pct", 0)) / 100.0 * gain
		out.steer_mult += float(s.get("steer_pct", 0)) / 100.0 * gain
		out.armor += float(s.get("armor_pct", 0)) / 100.0 * gain
		out.knockback_resist = maxf(out.knockback_resist, float(s.get("knockback_resist", 0)))
		out.oil_immune = out.oil_immune or s.get("oil_immune", false)
		out.magnet_radius *= float(s.get("magnet_mult", 1))
		out.scrap_mult *= float(s.get("scrap_mult", 1))
		out.shield_charges += int(s.get("shield_charges", 0))
		if s.has("shield_recharge_s"):
			out.shield_recharge_s = float(s.shield_recharge_s)
		if item.has("weapon"):
			var w: Dictionary = item.weapon.duplicate(true)
			w.id = id
			w.damage = float(w.get("damage", w.get("dps", 0))) * gain
			out.weapons.append(w)
	for combo in robot.combos():
		var passive: Dictionary = GameData.table("combos")[combo].get("passive", {})
		out.magnet_radius *= float(passive.get("magnet_mult", 1))
		out.scrap_mult *= float(passive.get("scrap_mult", 1))
	for id in robot.tradeoffs:
		var s: Dictionary = GameData.table("tradeoffs")[id].effects
		out.max_hp *= float(s.get("max_hp_mult", 1))
		out.dps_mult *= float(s.get("dps_mult", 1))
		out.steer_mult += float(s.get("steer_pct", 0)) / 100.0
	out.armor = clampf(out.armor, 0, 0.75)
	return out
