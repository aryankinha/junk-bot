class_name AimBot extends RefCounted
# Steers to line up with targets, seeing the world `delay` seconds late (reaction time).
# Gate choice and telegraph dodging come from the wrapped BotController so only aiming differs.
var inner: BotController
var delay := 0.0
var history: Array = []
var charge_gates := false

func _init(seed_arg := 1, reaction := 0.0, build: Array = []) -> void:
	inner = BotController.new(seed_arg, "perfect", 0.0, build)
	delay = reaction

func control(sim: RunSim) -> void:
	inner.control(sim)
	var snap: Array = []
	for enemy in sim.enemies:
		snap.append({"id": enemy.id, "x": enemy.x, "z": enemy.z, "salvage": enemy.get("salvage", ""), "hp": enemy.hp})
	history.append([sim.t, snap])
	while history.size() > 2 and float(history[1][0]) <= sim.t - delay:
		history.pop_front()
	if sim.state != "running":
		return
	var gate := sim.next_gate()
	if not gate.is_empty() and float(gate.z) - sim.z < 15:
		return
	for enemy in sim.enemies:
		if (enemy.warning or float(enemy.charge_left) > 0) and (float(enemy.timer) < 0.55 or float(enemy.charge_left) > 0):
			return
	var seen: Array = history[0][1]
	var best = null
	for enemy in seen:
		var gap: float = float(enemy.z) - sim.z
		if gap < 2.0 or gap > 22.0 or float(enemy.hp) <= 0:
			continue
		if best == null or (enemy.salvage == "blast" and best.salvage != "blast") or (enemy.salvage == best.salvage and gap < float(best.z) - sim.z):
			best = enemy
	if best != null:
		sim.target_x = clampf(float(best.x), -3.0, 3.0)
