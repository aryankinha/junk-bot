extends SceneTree
# Does focus_fire make "never move" the dominant strategy? Compares a stationary bot with an aiming bot,
# flag off vs on, on Level 1 (lane aiming and gate charge enabled for both).
# Usage: -- --seeds=40
func _initialize() -> void:
	GameData.load_all()
	var seeds := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
	var md := "| Bot | focus_fire | runs | win % | median boss s | mean kills | mean scrap collected |\n|---|---|---|---|---|---|---|\n"
	var rows: Array = []
	for bot_name in ["stationary", "aim", "aim_slow"]:
		for focus in [false, true]:
			var wins := 0
			var boss_times: Array = []
			var kills := 0
			var scrap := 0
			for seed_arg in seeds:
				var sim := RunSim.new()
				sim.flag_overrides = {"aim_mode": "lane", "gate_charge": true, "focus_fire": focus}
				sim.setup(1, seed_arg + 4000)
				var bot
				match bot_name:
					"stationary": bot = BotController.new(seed_arg + 4000, "no_dodge", 0.0)
					"aim": bot = AimBot.new(seed_arg + 4000, 0.15)
					_: bot = AimBot.new(seed_arg + 4000, 0.4)
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					for event in sim.events:
						kills += int(event.t == "enemy_death")
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				wins += int(sim.state == "won")
				if sim.boss != null and sim.state == "won":
					boss_times.append(sim.boss.elapsed)
				scrap += sim.robot.collected
			boss_times.sort()
			var median: float = boss_times[boss_times.size() / 2] if not boss_times.is_empty() else -1.0
			rows.append({"bot": bot_name, "focus_fire": focus, "win_rate": float(wins) / seeds, "boss_median_s": median, "kills": float(kills) / seeds, "scrap": float(scrap) / seeds})
			md += "| %s | %s | %d | %.0f | %.1f | %.1f | %.0f |\n" % [bot_name, "on" if focus else "off", seeds, float(wins) / seeds * 100, median, float(kills) / seeds, float(scrap) / seeds]
	FileAccess.open("res://results/interactivity_focus_check.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print(md)
	quit()
