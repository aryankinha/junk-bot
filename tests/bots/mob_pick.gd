extends SceneTree
# Pair-audit for mob-gate rows: for each row, play the same seeds with the stream forced through panel A, then B, and
# compare the damage landed by drones that passed that gate (MobSim.track_realised credits each hit to the gates the drone
# went through), over the rest of the run up to the boss. A rational chooser takes the better panel; a share near 50 % means neither panel dominates.
# The noise-aware share uses Phi(mean gap / sigma) with sigma = max(seed spread, 2 % of the mean score), like pair_pick.gd.
# Panel positions are swapped on odd seeds so that the lane a panel sits in (hazards, enemy spread) averages out and the panel
# type is what is compared; lane geometry is a real, separate part of the choice and is not measured here.
# Usage: -- --seeds=16 [--level=1] [--flags={...}] [--label=mob_pick]
func _initialize() -> void:
	GameData.load_all()
	var seeds := 16
	var level := 1
	var label := "mob_pick"
	var overrides: Dictionary = {"mob_stream": true}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--level="):
			level = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--label="):
			label = arg.get_slice("=", 1)
		elif arg.begins_with("--flags="):
			overrides.merge(JSON.parse_string(arg.substr(8)), true)
	var probe := RunSim.new()
	probe.flag_overrides = overrides
	probe.setup(level, 1)
	var rows: Array = []
	var md := "| Gate z | Panels | Pair | A picked (paired) | A picked (noise-aware) | mean score A | mean score B | gap % |\n|---|---|---|---|---|---|---|---|\n"
	var shares: Array = []
	for gate_index in probe.mob.gates.size():
		var panels: Array = probe.mob.gates[gate_index].panels
		var gate_z: float = float(probe.mob.gates[gate_index].z)
		var names := panels.map(func(p): return "%s%s" % [str(p.t), str(p.v)])
		for a in panels.size():
			for b in range(a + 1, panels.size()):
				var scores := [[], []]
				for side in 2:
					for seed_arg in seeds:
						var sim := RunSim.new()
						sim.flag_overrides = overrides
						sim.setup(level, seed_arg + 5000)
						sim.mob.track_realised = true
						var gate: Dictionary = sim.mob.gates[gate_index]
						var swap := seed_arg % 2 == 1
						if swap:
							var tmp = gate.panels[a]
							gate.panels[a] = gate.panels[b]
							gate.panels[b] = tmp
							tmp = gate.state[a]
							gate.state[a] = gate.state[b]
							gate.state[b] = tmp
						# Option A is the panel type that started in slot a; after a swap it sits in slot b.
						var slot_a := b if swap else a
						var slot_b := a if swap else b
						gate.bot_lane = slot_a if side == 0 else slot_b
						var bot := MobBot.new(seed_arg + 5000, 0.15)
						for tick in 18000:
							bot.control(sim)
							sim.step(1.0 / 60)
							sim.events.clear()
							# The last row pays off at the boss: do not stop at boss entry before its volley lands.
							if sim.z >= gate_z + 90.0 or sim.state in ["won", "lost"] or (sim.state == "boss" and sim.boss.elapsed >= 6.0):
								break
						scores[side].append(float(gate.get("realised", 0.0)))
				var a_better := 0.0
				var gaps: Array = []
				var mean_a := 0.0
				var mean_b := 0.0
				var zero_pairs := 0
				for i in seeds:
					zero_pairs += int(is_zero_approx(scores[0][i]) and is_zero_approx(scores[1][i]))
					a_better += 1.0 if scores[0][i] > scores[1][i] else (0.5 if is_equal_approx(scores[0][i], scores[1][i]) else 0.0)
					gaps.append(float(scores[0][i]) - float(scores[1][i]))
					mean_a += float(scores[0][i]) / seeds
					mean_b += float(scores[1][i]) / seeds
				var gap_mean := 0.0
				for g in gaps:
					gap_mean += g / seeds
				var variance := 0.0
				for g in gaps:
					variance += (g - gap_mean) * (g - gap_mean) / seeds
				var sigma := maxf(sqrt(variance), 0.02 * maxf(absf(mean_a), absf(mean_b)))
				var noise_share := _phi(gap_mean / maxf(sigma, 0.0001))
				var paired := a_better / seeds
				var pair_name := "%s vs %s" % [names[a], names[b]]
				shares.append(noise_share)
				rows.append({"z": gate_z, "pair": pair_name, "paired": paired, "noise_aware": noise_share, "mean_a": mean_a, "mean_b": mean_b, "seeds": seeds, "zero_damage_pairs": zero_pairs})
				md += "| %d | %s | %s | %.0f%% | %.0f%% | %.0f | %.0f | %.0f |\n" % [gate_z, " / ".join(names), pair_name, paired * 100, noise_share * 100, mean_a, mean_b, (mean_a - mean_b) / maxf(1.0, maxf(mean_a, mean_b)) * 100]
	FileAccess.open("res://results/%s.json" % label, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print(md)
	quit()

func _phi(x: float) -> float:
	# Logistic approximation of the normal CDF (max error 0.01).
	return 1.0 / (1.0 + exp(-1.702 * x))
