extends SceneTree
# Paired-seed pick share for the five Level 1 gate pairs.
# For each seed the same run is played twice, forcing option A then option B at one gate; a rational
# chooser takes the option with the better outcome score. Share near 50 % means neither option dominates.
# The raw paired share is degenerate when gaps are tiny but consistent, so a noise-aware share is also reported:
# a chooser that judges each option from one playthrough picks A with probability Phi(mean gap / sigma), where sigma is the
# larger of the seed-to-seed spread and a 2 % perception floor (a player cannot feel a smaller difference).
# score = 1000 * won + 100 * final HP fraction + 0.25 * scrap collected (scrap buys repairs and parts later)
#         - 2 * seconds the boss fight took (a stronger build kills the Titan sooner).
# Usage: -- --label=baseline --seeds=30 [--flags={...}]
func _initialize() -> void:
	GameData.load_all()
	var label := "baseline"
	var seeds := 30
	var overrides: Dictionary = {}
	var inner_mode := "perfect"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.get_slice("=", 1)
		elif arg.begins_with("--seeds="):
			seeds = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--inner="):
			inner_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--flags="):
			overrides.merge(JSON.parse_string(arg.substr(8)), true)
	var rows: Array = []
	var md := "| Gate z | Option A | Option B | A picked (paired) | A picked (noise-aware) | A win % | B win % | A score | B score | A payoff s | B payoff s |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
	var shares: Array = []
	for gate_z in [80, 180, 290, 400, 520]:
		var scores := [[], []]
		var wins := [0, 0]
		var payoffs := [[], []]
		var names := ["", ""]
		for side in 2:
			for seed_arg in seeds:
				var sim := RunSim.new()
				sim.flag_overrides = overrides.merged({"engagement_metrics": true}, true)
				sim.setup(1, seed_arg + 2000)
				for beat in sim.beats:
					if int(beat.z) == gate_z:
						beat.bot_side = side
						names[side] = GateGen.label(beat.options[side])
				var bot := AimBot.new(seed_arg + 2000, 0.15, [], inner_mode)
				for tick in 18000:
					bot.control(sim)
					sim.step(1.0 / 60)
					sim.events.clear()
					if sim.state in ["won", "lost"]:
						break
				var won := sim.state == "won"
				wins[side] += int(won)
				scores[side].append(1000.0 * float(won) + 100.0 * sim.robot.hp / sim.robot.max_hp + 0.25 * sim.robot.collected - 2.0 * (sim.boss.elapsed if sim.boss != null else 60.0))
				if gate_z == 80:
					var r: Dictionary = sim.engage.results(sim.t)
					if r.time_to_first_payoff >= 0:
						payoffs[side].append(r.time_to_first_payoff)
		var a_better := 0.0
		for i in seeds:
			a_better += 1.0 if scores[0][i] > scores[1][i] else (0.5 if is_equal_approx(scores[0][i], scores[1][i]) else 0.0)
		var share := a_better / seeds
		var noise_share := _phi((_mean(scores[0]) - _mean(scores[1])) / maxf(0.02 * absf(_mean(scores[1])), sqrt(_var(scores[0]) + _var(scores[1]))))
		shares.append(share)
		var mean_a := _mean(scores[0])
		var mean_b := _mean(scores[1])
		rows.append({"gate_z": gate_z, "a": names[0], "b": names[1], "a_share": share, "a_share_noise_aware": noise_share, "score_gap_pct": (_mean(scores[0]) - _mean(scores[1])) / maxf(1.0, _mean(scores[1])) * 100.0, "a_win": float(wins[0]) / seeds, "b_win": float(wins[1]) / seeds, "a_score": mean_a, "b_score": mean_b, "a_payoff": _mean(payoffs[0]), "b_payoff": _mean(payoffs[1]), "a_payoff_seen": payoffs[0].size(), "b_payoff_seen": payoffs[1].size()})
		md += "| %d | %s | %s | %.0f%% | %.0f%% | %.0f | %.0f | %.1f | %.1f | %s | %s |\n" % [gate_z, names[0], names[1], share * 100, noise_share * 100, float(wins[0]) / seeds * 100, float(wins[1]) / seeds * 100, mean_a, mean_b, ("%.1f (%d/%d)" % [_mean(payoffs[0]), payoffs[0].size(), seeds]) if gate_z == 80 else "-", ("%.1f (%d/%d)" % [_mean(payoffs[1]), payoffs[1].size(), seeds]) if gate_z == 80 else "-"]
	FileAccess.open("res://results/interactivity_pairs_%s.json" % label, FileAccess.WRITE).store_string(JSON.stringify({"flags": overrides, "rows": rows}, "  "))
	print(md)
	quit()

func _mean(list: Array) -> float:
	if list.is_empty():
		return -1.0
	var total := 0.0
	for v in list:
		total += float(v)
	return total / list.size()

func _var(list: Array) -> float:
	var m := _mean(list)
	var total := 0.0
	for v in list:
		total += (float(v) - m) * (float(v) - m)
	return total / maxf(1.0, list.size() - 1.0)

# Standard normal CDF (Abramowitz-Stegun 7.1.26).
func _phi(z: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(z) / sqrt(2.0))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z / 2.0)
	return 0.5 * (1.0 + (y if z >= 0 else -y))
