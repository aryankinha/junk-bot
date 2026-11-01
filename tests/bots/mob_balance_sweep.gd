extends SceneTree
# Isolate the Mob-only Titan HP retune; never writes production tuning.
func _initialize() -> void:
	GameData.load_all()
	var rows: Array = []
	for hp in [1.3, 1.6, 2.0, 2.5]:
		GameData.table("mob").boss_hp_mult = hp
		for mode in ["stay", "best"]:
			var wins := 0
			var boss_times: Array = []
			for seed_arg in 12:
				var sim := RunSim.new()
				sim.flag_overrides = {"mob_stream": true, "aim_mode": "lane", "guarded_salvage": true, "gate_charge": true, "post_gate_payoff": true, "moving_gates": true, "focus_fire": true, "dense_blocks": true, "weapon_evolution": true}
				sim.setup(1, seed_arg + 3000)
				var bot := MobBot.new(seed_arg + 3000, 0.4 if mode == "best" else 0.0, [], "perfect", mode)
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				wins += int(sim.state == "won")
				if sim.state == "won":
					boss_times.append(sim.boss.elapsed)
			boss_times.sort()
			var row := {"hp_mult": hp, "mode": mode, "runs": 12, "wins": wins, "winning_boss_median_s": boss_times[boss_times.size() / 2] if not boss_times.is_empty() else -1.0}
			rows.append(row)
			print(row)
	FileAccess.open("res://results/mob_resume_hp_sweep.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
