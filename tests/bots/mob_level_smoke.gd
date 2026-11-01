extends SceneTree
# End-to-end generated-level coverage; small sample, not a human balance claim.
func _initialize() -> void:
	GameData.load_all()
	var rows: Array = []
	for level in [2, 3, 4, 5]:
		var wins := 0
		var timeouts := 0
		var cap_violations := 0
		var peak := 0
		for seed_arg in 8:
			var sim := RunSim.new()
			sim.flag_overrides = {"mob_stream": true, "mob_enemy_streams": true, "dense_blocks": true}
			sim.setup(level, seed_arg + 8000)
			var bot := MobBot.new(seed_arg + 8000, 0.25)
			for tick in 18000:
				bot.control(sim)
				sim.step(1.0 / 60)
				peak = maxi(peak, sim.mob.n)
				cap_violations += int(sim.mob.n > sim.mob.live_cap() or sim.enemies.size() > int(sim.flags.tuning.dense_enemy_cap))
				sim.events.clear()
				if sim.state in ["won", "lost"]:
					break
			wins += int(sim.state == "won")
			timeouts += int(sim.state not in ["won", "lost"])
		var row := {"level": level, "runs": 8, "wins": wins, "timeouts": timeouts, "cap_violations": cap_violations, "drones_peak": peak}
		rows.append(row)
		print(row)
	FileAccess.open("res://results/mob_resume_levels.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit(0 if rows.all(func(r): return r.cap_violations == 0 and r.timeouts == 0) else 1)
