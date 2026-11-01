class_name AimBot extends RefCounted
# Steers to line up with targets, seeing the world `delay` seconds late (reaction time).
# Gate choice and telegraph dodging come from the wrapped BotController so only aiming differs.
var inner: BotController
var delay := 0.0
var history: Array = []
var charge_gates := true

func _init(seed_arg := 1, reaction := 0.0, build: Array = [], inner_mode := "perfect") -> void:
	inner = BotController.new(seed_arg, inner_mode, reaction, build)
	delay = reaction

func control(sim: RunSim) -> void:
	inner.control(sim)
	if delay > 0.0:
		var snap: Array = []
		for enemy in sim.enemies:
			snap.append({"id": enemy.id, "x": enemy.x, "z": enemy.z, "salvage": enemy.get("salvage", ""), "hp": enemy.hp})
		history.append([sim.t, snap])
		while history.size() > 2 and float(history[1][0]) <= sim.t - delay:
			history.pop_front()
	if sim.state != "running":
		return
	var gate := sim.next_gate()
	if not gate.is_empty() and gate.get("moving", false) and gate.has("bot_side") and float(gate.z) - sim.z < 30.0:
		# Track the sliding panel as it was seen `delay` seconds ago.
		sim.target_x = sim.panel_center(gate, int(gate.bot_side), sim.t - delay)
		return
	if charge_gates and not gate.is_empty() and gate.has("charge") and gate.has("bot_side") and float(gate.z) - sim.z < float(sim.flags.tuning.charge_range):
		# Commit to the chosen panel early and keep shooting it.
		sim.target_x = -3.4 + 6.8 * (float(gate.bot_side) + 0.5) / gate.options.size()
		return
	if not gate.is_empty() and float(gate.z) - sim.z < 15:
		return
	for enemy in sim.enemies:
		if (enemy.warning or float(enemy.charge_left) > 0) and (float(enemy.timer) < 0.55 or float(enemy.charge_left) > 0):
			return
	var seen: Array = history[0][1] if delay > 0.0 else sim.enemies
	var best = null
	for enemy in seen:
		var gap: float = float(enemy.z) - sim.z
		if gap < 2.0 or gap > 22.0 or float(enemy.hp) <= 0:
			continue
		if best == null or (enemy.get("salvage", "") == "blast" and best.get("salvage", "") != "blast") or (enemy.get("salvage", "") == best.get("salvage", "") and gap < float(best.z) - sim.z):
			best = enemy
	if best != null:
		sim.target_x = clampf(float(best.x), -3.0, 3.0)
