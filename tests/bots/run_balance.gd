extends SceneTree
func _initialize() -> void:
	var count := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			count = arg.get_slice("=", 1).to_int()
	var records: Array = []
	var report := "# Bot balance\n\nSame fixed-step simulation as gameplay. Results are simulated, not human/device validation.\n\n| Level | Bot | Runs | Wins | Median boss s | Parts lost | Monster share |\n|---|---|---|---|---|---|---|\n"
	for level in [1, 3, 5]:
		for mode in ["perfect", "random", "no_dodge"]:
			var wins := 0
			var times: Array[float] = []
			var lost := 0
			var monsters := 0
			var causes: Dictionary = {}
			for seed_arg in count:
				var sim := RunSim.new()
				sim.setup(level, seed_arg + 100)
				var bot := BotController.new(seed_arg + 100, mode, 0.25)
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				wins += int(sim.state == "won")
				if sim.boss != null and sim.state == "won":
					times.append(sim.boss.elapsed)
				lost += sim.robot.parts_lost
				monsters += int(sim.robot.stage() == 3)
				var cause := sim.death_cause if sim.state == "lost" else sim.state
				causes[cause] = int(causes.get(cause, 0)) + 1
				bot = null
			times.sort()
			var median := times[times.size() / 2] if not times.is_empty() else -1.0
			var row := {"level": level, "bot": mode, "runs": count, "wins": wins, "win_rate": float(wins) / count, "boss_median_s": median, "parts_lost_mean": float(lost) / count, "monster_share": float(monsters) / count, "outcomes": causes}
			records.append(row)
			report += "| %d | %s | %d | %.1f%% | %.1f | %.2f | %.1f%% |\n" % [level, mode, count, float(wins) / count * 100, median, float(lost) / count, float(monsters) / count * 100]
			print(JSON.stringify(row))
	var file := FileAccess.open("res://results/bot_balance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	var md := FileAccess.open("res://reports/bot_balance.md", FileAccess.WRITE)
	md.store_string(report)
	quit()
