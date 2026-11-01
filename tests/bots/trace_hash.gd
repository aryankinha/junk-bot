extends SceneTree
# Fingerprint of full bot runs. With every experiment flag off the fingerprints must equal the
# stored baseline (results/interactivity_trace_baseline.txt).  Usage: -- [--write]
const NEW_EVENTS := ["gate_charge_tick", "payoff", "gate_charged", "salvage_target", "evolution", "evolution_hint", "focus_ramp", "salvage_spawn", "salvage_looted", "wave_spawn", "cluster_burst"]
func _initialize() -> void:
	GameData.load_all()
	var lines: Array = []
	for level in [1, 2, 3]:
		for mode in ["perfect", "random", "no_dodge"]:
			for seed_arg in 4:
				var sim := RunSim.new()
				sim.setup(level, seed_arg + 500)
				var bot := BotController.new(seed_arg + 500, mode, 0.25)
				var trace := ""
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					for event in sim.events:
						if event.t not in NEW_EVENTS:
							trace += JSON.stringify(event)
					sim.events.clear()
					if tick % 20 == 0:
						trace += "%.4f,%.4f,%.3f,%d,%d,%d|" % [sim.z, sim.x, sim.robot.hp, sim.robot.scrap, sim.bullets.size(), sim.enemies.size()]
					if sim.state in ["won", "lost"]:
						break
				lines.append("L%d %s s%d %s %s t=%.2f" % [level, mode, seed_arg, sim.state, trace.md5_text(), sim.t])
	var out := "\n".join(lines) + "\n"
	if OS.get_cmdline_user_args().has("--write"):
		FileAccess.open("res://results/interactivity_trace_baseline.txt", FileAccess.WRITE).store_string(out)
		print("baseline written: ", lines.size())
	else:
		var expected := FileAccess.get_file_as_string("res://results/interactivity_trace_baseline.txt")
		print("TRACE MATCH" if expected == out else "TRACE MISMATCH")
		if expected != out:
			var a := expected.split("\n")
			var b := out.split("\n")
			for i in mini(a.size(), b.size()):
				if a[i] != b[i]:
					print("diff: ", a[i], "  !=  ", b[i])
	quit()
