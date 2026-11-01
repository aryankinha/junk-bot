extends SceneTree
# Engagement metrics over bot runs.
# Usage: -- --label=baseline --seeds=20 [--level=1] [--flags={"aim_mode":"lane"}]
# Writes results/interactivity_<label>.json and prints a markdown table.
func _initialize() -> void:
	GameData.load_all()
	var label := "baseline"
	var seeds := 20
	var level := 1
	var overrides: Dictionary = {"engagement_metrics": true}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.get_slice("=", 1)
		elif arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--level="):
			level = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--flags="):
			overrides.merge(JSON.parse_string(arg.substr(8)), true)
	var rows: Array = []
	var md := "| Bot | delay ms | runs | win % | first gate s | payoff s (median) | payoff <=2s | gap pre-boss median | p90 | gap<=4s share | full-run gap p90 | evolved |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n"
	for config in [["perfect", 0.0], ["perfect", 0.15], ["perfect", 0.25], ["perfect", 0.4], ["aim", 0.0], ["aim", 0.15], ["aim", 0.25], ["aim", 0.4], ["random", 0.25], ["no_dodge", 0.0]]:
		var mode: String = config[0]
		var delay: float = config[1]
		var gaps: Array = []
		var full_gaps: Array = []
		var payoffs: Array = []
		var gates: Array = []
		var wins := 0
		var fast := 0
		var evolved := 0
		var kinds: Dictionary = {}
		var chosen: Dictionary = {}
		for seed_arg in seeds:
			var sim := RunSim.new()
			sim.flag_overrides = overrides
			sim.setup(level, seed_arg + 1000)
			var bot = AimBot.new(seed_arg + 1000, delay) if mode == "aim" else BotController.new(seed_arg + 1000, mode, delay)
			for tick in 18000:
				bot.control(sim)
				sim.step(1.0 / 60)
				sim.events.clear()
				if sim.state in ["won", "lost"]:
					break
			wins += int(sim.state == "won")
			var r: Dictionary = sim.engage.results(sim.t)
			gaps.append(r.max_gap_pre_boss)
			full_gaps.append(r.max_gap_full_run)
			gates.append(r.time_to_first_gate)
			payoffs.append(r.time_to_first_payoff)
			evolved += int(r.evolution_t >= 0)
			fast += int(r.time_to_first_payoff >= 0 and r.time_to_first_payoff <= 2.0)
			chosen[r.chosen] = int(chosen.get(r.chosen, 0)) + 1
			for k in r.marks_by_kind:
				kinds[k] = int(kinds.get(k, 0)) + int(r.marks_by_kind[k])
		var ok_gap := 0
		for g in gaps:
			ok_gap += int(g <= 4.0)
		var seen_payoffs: Array = payoffs.filter(func(p): return p >= 0)
		var row := {"bot": mode, "delay_ms": delay * 1000, "runs": seeds, "win_rate": float(wins) / seeds,
			"first_gate_median": _q(gates, 0.5), "payoff_median": _q(seen_payoffs, 0.5), "payoff_seen_share": float(seen_payoffs.size()) / seeds,
			"payoff_within_2s": float(fast) / seeds, "gap_pre_boss_median": _q(gaps, 0.5), "gap_pre_boss_p90": _q(gaps, 0.9),
			"gap_le_4s_share": float(ok_gap) / seeds, "gap_full_p90": _q(full_gaps, 0.9), "evolved_share": float(evolved) / seeds, "marks": kinds, "first_gate_choice": chosen}
		rows.append(row)
		md += "| %s | %d | %d | %.0f | %.1f | %.1f | %.0f%% | %.1f | %.1f | %.0f%% | %.1f | %.0f%% |\n" % [mode, delay * 1000, seeds, row.win_rate * 100, row.first_gate_median, row.payoff_median, row.payoff_within_2s * 100, row.gap_pre_boss_median, row.gap_pre_boss_p90, row.gap_le_4s_share * 100, row.gap_full_p90, row.evolved_share * 100]
	FileAccess.open("res://results/interactivity_%s.json" % label, FileAccess.WRITE).store_string(JSON.stringify({"level": level, "flags": overrides, "rows": rows}, "  "))
	print(md)
	quit()

func _q(list: Array, p: float) -> float:
	if list.is_empty():
		return -1.0
	var sorted := list.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(sorted.size() * p))])
