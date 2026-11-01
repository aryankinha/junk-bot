class_name MobBot extends RefCounted
# Plays the Mob Stream: AimBot behaviour (targets, part gates, dodging, reaction delay) plus steering the stream
# into the mob-gate panel with the best value it can see. Everything it reads is late by `delay` seconds, like a player's eyes.
# mode "best": rational, picks the highest value panel; "stay": never steers for gates (a stationary player).
var aim: AimBot
var delay := 0.0
var mode := "best"
var steer_window := 48.0
var rng := RandomNumberGenerator.new()

func _init(seed_arg := 1, reaction := 0.0, build: Array = [], inner_mode := "perfect", gate_mode := "best") -> void:
	aim = AimBot.new(seed_arg, reaction, build, inner_mode)
	rng.seed = seed_arg * 7919 + 13
	delay = reaction
	mode = gate_mode

# Expected damage gain a panel gives the stream, as a fraction of the stream (what a player reads off the gate).
static func panel_value(panel: Dictionary, add_per: float) -> float:
	var v := float(panel.v)
	match str(panel.t):
		"mult": return v - 1.0
		"add": return v / add_per
		"power": return v / 100.0
		"speed": return 0.15
		"trap": return -v / 100.0
	return 0.0

func control(sim: RunSim) -> void:
	aim.control(sim)
	if sim.mob == null or sim.state != "running" or mode == "stay":
		return
	var mob: MobSim = sim.mob
	var gate = null
	for candidate in mob.gates:
		var gap := float(candidate.z) - sim.z
		if gap > 1.5 and gap <= steer_window:
			gate = candidate
			break
	if gate == null:
		return
	if not gate.has("bot_lane"):
		var best := 0
		var best_value := -999.0
		for lane in gate.panels.size():
			# Near-equal panels are a coin flip, like a player who cannot tell them apart.
			var value := panel_value(gate.panels[lane], float(mob.cfg.gates.add_per)) + rng.randf() * 0.02
			if value > best_value:
				best_value = value
				best = lane
		gate.bot_lane = best
	# A part gate close ahead or a telegraphed attack keeps priority over the mob gate.
	var part := sim.next_gate()
	if not part.is_empty() and float(part.z) - sim.z < 15.0 and float(part.z) - sim.z > -1.0:
		return
	for enemy in sim.enemies:
		if (enemy.warning or float(enemy.charge_left) > 0) and (float(enemy.timer) < 0.55 or float(enemy.charge_left) > 0):
			return
	sim.target_x = clampf(mob.panel_center(gate, int(gate.bot_lane), sim.t - delay, sim.flags.tuning), -3.0, 3.0)
