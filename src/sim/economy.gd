class_name Economy extends RefCounted
static func reward(scrap: int, level: int, won: bool, streak: int) -> int:
	var config: Dictionary = GameData.table("economy").cogs
	var base := float(scrap) * float(config.per_scrap)
	if won:
		base += float(config.boss_bonus_per_level) * level
	return int(round(base * (1 + minf(float(config.streak_bonus_max), streak * float(config.streak_bonus_per_step)))))

static func upgrade_cost(tier: int) -> int:
	var costs: Array = GameData.table("economy").upgrade_costs
	return int(costs[tier - 1]) if tier >= 1 and tier <= costs.size() else -1
