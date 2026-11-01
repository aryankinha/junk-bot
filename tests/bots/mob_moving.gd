extends SceneTree
# Moving mob gate fairness: how much of the stream a bot with a given reaction delay gets through the panel it chose.
# Usage: -- --seeds=12   Writes results/mob_moving_fairness.json
func _initialize() -> void:
	GameData.load_all()
	var seeds := 12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
	var rows: Array = []
	var md := "| Reaction ms | chosen panel | drones through chosen panel | through other panel | missed (gap) |\n|---|---|---|---|---|\n"
	for delay in [0.0, 0.15, 0.25, 0.4, 0.6]:
		for lane in 2:
			var chosen := 0
			var other := 0
			var missed := 0
			for seed_arg in seeds:
				var sim := RunSim.new()
				sim.flag_overrides = {"mob_stream": true}
				sim.setup(1, seed_arg + 4000)
				# Isolate the gate: no part gate or mob gate within reach before it, so only the stream aim is measured.
				sim.beats = sim.beats.filter(func(b): return b.type == "mob_gate" and b.get("moving", false) or float(b.z) > 500.0)
				sim.mob.register_gates(sim.beats)
				var gate: Dictionary = sim.beats.filter(func(b): return b.type == "mob_gate" and b.get("moving", false))[0]
				gate.bot_lane = lane
				var bot := MobBot.new(seed_arg + 4000, delay)
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.z > float(gate.z) + 5.0:
						break
				chosen += int(gate.state[lane].get("total", 0))
				other += int(gate.state[1 - lane].get("total", 0))
				missed += int(gate.missed)
			var total := float(maxi(1, chosen + other + missed))
			rows.append({"delay_ms": delay * 1000, "lane": lane, "chosen": chosen / total, "other": other / total, "missed": missed / total})
			md += "| %d | %d | %.0f%% | %.0f%% | %.0f%% |\n" % [delay * 1000, lane, chosen / total * 100, other / total * 100, missed / total * 100]
	FileAccess.open("res://results/mob_moving_fairness.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print(md)
	quit()
