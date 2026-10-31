class_name BotController extends RefCounted
var rng := RandomNumberGenerator.new()
var mode := "perfect"
var delay := 0.25
var noticed := ""
var noticed_at := 0.0
var profile: Array = []
var miss_attack := false
func _init(seed_arg := 1, type := "perfect", reaction := 0.25, build: Array = []) -> void:
	rng.seed = seed_arg * 23 + 7
	mode = type
	delay = reaction
	profile = build
func control(sim: RunSim) -> void:
	if sim.state == "choosing" and not sim.pending_parts.is_empty():
		sim.choose_purchase(str(sim.pending_parts[0]))
	if sim.state == "running":
		var gate := sim.next_gate()
		if not gate.is_empty():
			if not gate.has("bot_side"):
				var side := rng.randi_range(0, gate.options.size() - 1)
				if mode not in ["random", "no_dodge"] and gate.type != "repair_bay":
					var best := -999.0
					for i in gate.options.size():
						var option: Dictionary = gate.options[i]
						var value := 0.0
						if option.kind == "part":
							value = {"cannon": 5, "rocket": 8, "armour": 4, "wheels": 2}.get(option.id, 1)
							if profile.has(option.id):
								value += 20
						if value > best:
							best = value
							side = i
				if gate.type == "repair_bay":
					side = 0
				gate.bot_side = side
			if float(gate.z) - sim.z < 15:
				sim.target_x = -3.4 + 6.8 * (float(gate.bot_side) + 0.5) / gate.options.size()
			elif mode != "no_dodge":
				sim.target_x = sin((sim.z + 4) * 0.06) * 2
	elif sim.state == "boss" and mode != "no_dodge":
		var boss: BossSim = sim.boss
		var key := str(boss.attacks_made)
		if key != noticed:
			noticed = key
			noticed_at = sim.t
			miss_attack = mode == "random" and rng.randf() < float(GameData.table("bot_models").random.miss_telegraph_probability)
		if sim.t - noticed_at >= (0.0 if mode == "perfect" else delay) and not boss.zones.is_empty() and not miss_attack:
			var safe := -3.0
			var best_margin := -100.0
			for candidate in [-3.0, -2.25, -1.5, 0.0, 1.5, 2.25, 3.0]:
				var margin := 100.0
				for zone in boss.zones:
					var distance := absf(candidate - float(zone.x)) - float(zone.radius)
					if zone.shape == "sweep":
						distance = -distance
					margin = minf(margin, distance)
				if margin > best_margin:
					best_margin = margin
					safe = candidate
			sim.target_x = safe
	if mode != "no_dodge":
		for enemy in sim.enemies:
			if (enemy.warning or float(enemy.charge_left) > 0) and (float(enemy.timer) < 0.55 or float(enemy.charge_left) > 0) and (sim.next_gate().is_empty() or float(sim.next_gate().z) - sim.z > 5):
				sim.target_x = -2.8 if float(enemy.aim_x) > 0 else 2.8
	sim.tap_special()
