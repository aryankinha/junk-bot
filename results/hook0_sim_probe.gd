extends SceneTree
func _initialize() -> void:
	GameData.load_all()
	var rows: Array = []
	for mode in ["off", "mob", "bundle"]:
		var sim := RunSim.new()
		sim.flag_overrides = {"engagement_metrics": true, "mob_stream": mode != "off"}
		if mode == "bundle": sim.flag_overrides.merge({"aim_mode":"lane","guarded_salvage":true,"gate_charge":true,"post_gate_payoff":true,"moving_gates":true,"focus_fire":true,"dense_blocks":true,"weapon_evolution":true,"mob_enemy_streams":true})
		sim.setup(1, 20261031)
		var bot := MobBot.new(20261031, 0.15)
		var first := -1.0
		var peak_enemies := 0
		var peak_gate_rows := 0
		for frame in 18000:
			bot.control(sim); sim.step(1.0 / 60)
			peak_enemies = maxi(peak_enemies, sim.enemies.size())
			var part := sim.next_gate()
			var part_visible := not part.is_empty() and float(part.z) - sim.z < 62
			var visible := int(part_visible)
			if sim.mob != null:
				var mob_rows := 0
				for row in sim.mob.gates:
					if float(row.z) >= sim.z - 3 and float(row.z) <= sim.z + 62: mob_rows += 1
				visible += mini(mob_rows, 1 if part_visible else 2)
			peak_gate_rows = maxi(peak_gate_rows, visible)
			for e in sim.events:
				if e.t == "gate_choice" and first < 0: first = sim.t
			sim.events.clear()
			if sim.state in ["won", "lost"]: break
		rows.append({"mode":mode,"seed":20261031,"bot":"MobBot delay150ms","state":sim.state,"sim_end_t":sim.t,"first_part_choice_t":first,"first_multiply_t":sim.mob.first_multiply_t if sim.mob != null else -1,"peak_enemy_array_count":peak_enemies,"peak_gate_rows_under_pool_distance_rules":peak_gate_rows,"engagement":sim.engage.results(sim.t),"mob_stats":sim.mob.stats if sim.mob != null else {}})
	FileAccess.open("res://results/hook0_sim_probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print(JSON.stringify(rows))
	quit()
