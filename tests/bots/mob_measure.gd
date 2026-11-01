extends SceneTree
# Mob Stream bot runs: win rate, time to first multiplication, engagement gap, drone counts, boss time.
# Usage: -- --label=mob --seeds=20 [--level=1] [--flags={...}]  (mob_stream is added unless --flags sets it)
# Writes results/mob_<label>.json and prints a markdown table.
func _initialize() -> void:
	GameData.load_all()
	var label := "mob"
	var seeds := 20
	var level := 1
	var overrides: Dictionary = {"engagement_metrics": true, "mob_stream": true}
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
	var md := "| Bot | delay ms | runs | win % | first multiply s (median) | gap pre-boss median | p90 | gap<=4s | boss time s | drones avg | peak | cap ticks % | gate gain x |\\n|---|---|---|---|---|---|---|---|---|---|---|---|---|\\n".replace("\\n", "\n")
	for config in [["mob", 0.0], ["mob", 0.15], ["mob", 0.25], ["mob", 0.4], ["stay", 0.0], ["aim", 0.15], ["random", 0.25], ["no_dodge", 0.0]]:
		var mode: String = config[0]
		var delay: float = config[1]
		var firsts: Array = []
		var gaps: Array = []
		var boss_times: Array = []
		var avgs: Array = []
		var peaks: Array = []
		var cap_share: Array = []
		var gains: Array = []
		var wins := 0
		var fast := 0
		for seed_arg in seeds:
			var sim := RunSim.new()
			sim.flag_overrides = overrides
			sim.setup(level, seed_arg + 3000)
			var bot
			match mode:
				"mob": bot = MobBot.new(seed_arg + 3000, delay) if overrides.mob_stream else AimBot.new(seed_arg + 3000, delay)
				"stay": bot = MobBot.new(seed_arg + 3000, delay, [], "no_dodge", "stay")
				"aim": bot = AimBot.new(seed_arg + 3000, delay)
				_: bot = BotController.new(seed_arg + 3000, mode, delay)
			for tick in 18000:
				bot.control(sim)
				sim.step(1.0 / 60)
				sim.events.clear()
				if sim.state in ["won", "lost"]:
					break
			wins += int(sim.state == "won")
			var r: Dictionary = sim.engage.results(sim.t)
			gaps.append(r.max_gap_pre_boss)
			fast += int(r.max_gap_pre_boss <= 4.0)
			if sim.boss != null:
				boss_times.append(sim.boss.elapsed)
			if sim.mob != null:
				if sim.mob.first_multiply_t >= 0.0:
					firsts.append(sim.mob.first_multiply_t)
				var st: Dictionary = sim.mob.stats
				avgs.append(float(st.live_sum) / maxf(1.0, float(st.ticks)))
				peaks.append(float(st.peak))
				cap_share.append(float(st.cap_ticks) / maxf(1.0, float(st.ticks)))
				gains.append(float(st.gain))
		var row := {"bot": mode, "delay_ms": delay * 1000, "runs": seeds, "win_rate": float(wins) / seeds, "first_multiply_median": _q(firsts, 0.5), "gap_median": _q(gaps, 0.5), "gap_p90": _q(gaps, 0.9), "gap_le_4s": float(fast) / seeds, "boss_time_median": _q(boss_times, 0.5), "drones_avg": _mean(avgs), "drones_peak": _q(peaks, 1.0), "cap_tick_share": _mean(cap_share), "gate_gain_damage": _mean(gains)}
		rows.append(row)
		md += "| %s | %d | %d | %.0f | %.1f | %.1f | %.1f | %.0f%% | %.1f | %.0f | %.0f | %.1f | %.0f |\n" % [mode, delay * 1000, seeds, row.win_rate * 100, row.first_multiply_median, row.gap_median, row.gap_p90, row.gap_le_4s * 100, row.boss_time_median, row.drones_avg, row.drones_peak, row.cap_tick_share * 100, row.gate_gain_damage]
	FileAccess.open("res://results/%s.json" % label, FileAccess.WRITE).store_string(JSON.stringify({"level": level, "flags": overrides, "rows": rows}, "  "))
	print(md)
	quit()

func _q(list: Array, p: float) -> float:
	if list.is_empty():
		return -1.0
	var sorted := list.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(sorted.size() * p))])

func _mean(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var sum := 0.0
	for v in list:
		sum += float(v)
	return sum / list.size()
