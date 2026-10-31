extends SceneTree
func _initialize() -> void:
	var rows: Array = []
	var report := "# Gate pair audit\n\nBoth fixed choices tested through the complete sim with a perfect-dodge bot. Category checks do not establish equivalent value.\n\n| Gate z | Side | Runs | Win rate |\n|---|---|---|---|\n"
	for gate_z in [80, 180, 290, 400, 520]:
		for side in 2:
			var wins := 0
			for seed_arg in 12:
				var sim := RunSim.new()
				sim.setup(1, seed_arg + 200)
				var bot := BotController.new(seed_arg + 200, "perfect", 0)
				for beat in sim.beats:
					if int(beat.z) == gate_z:
						beat.bot_side = side
				for i in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				wins += int(sim.state == "won")
			rows.append({"gate_z": gate_z, "side": side, "runs": 12, "wins": wins})
			report += "| %d | %d | 12 | %.1f%% |\n" % [gate_z, side, wins / 12.0 * 100]
	var profiles := {"speed_gunner": ["wheels", "cannon"], "rocket_tank": ["rocket", "armour", "tracks"], "collector": ["magnet", "storage", "flame"]}
	report += "\n## Build profiles\n\n| Profile | Level | Runs | Win rate |\n|---|---|---|---|\n"
	for profile in profiles:
		for level in [1, 2, 3]:
			var wins := 0
			for seed_arg in 10:
				var sim := RunSim.new()
				sim.setup(level, seed_arg + 300)
				var bot := BotController.new(seed_arg + 300, "perfect", 0, profiles[profile])
				for i in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				wins += int(sim.state == "won")
			report += "| %s | %d | 10 | %.1f%% |\n" % [profile, level, wins * 10.0]
	var file := FileAccess.open("res://results/pair_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  "))
	var md := FileAccess.open("res://reports/pair_audit.md", FileAccess.WRITE)
	md.store_string(report)
	print(report)
	quit()
