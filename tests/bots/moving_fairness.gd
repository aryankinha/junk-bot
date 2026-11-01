extends SceneTree
# Moving-gate fairness: does a bot with reaction delay still end up in the panel it meant to pick?
# Usage: -- --seeds=30 [--level=1]
func _initialize() -> void:
	GameData.load_all()
	var seeds := 30
	var level := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--level="):
			level = arg.get_slice("=", 1).to_int()
	var rows: Array = []
	var md := "| Bot delay ms | moving gates | intended panel taken | share |\n|---|---|---|---|\n"
	for delay in [0.0, 0.15, 0.25, 0.4, 0.6]:
		var total := 0
		var hit := 0
		for seed_arg in seeds:
			var sim := RunSim.new()
			sim.flag_overrides = {"aim_mode": "lane", "gate_charge": true, "moving_gates": true}
			sim.setup(level, seed_arg + 3000)
			var bot := AimBot.new(seed_arg + 3000, delay)
			for tick in 18000:
				bot.control(sim)
				sim.step(1.0 / 60)
				sim.events.clear()
				if sim.state in ["won", "lost", "boss"]:
					break
			for beat in sim.beats:
				if beat.get("moving", false) and beat.resolved:
					total += 1
					for entry in sim.gate_history:
						if entry.z == beat.z:
							hit += int(entry.side == int(beat.get("bot_side", -1)))
		rows.append({"delay_ms": delay * 1000, "moving_gates": total, "intended": hit})
		md += "| %d | %d | %d | %.0f%% |\n" % [delay * 1000, total, hit, float(hit) / maxf(1.0, total) * 100.0]
	FileAccess.open("res://results/interactivity_moving_fairness.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print(md)
	quit()
