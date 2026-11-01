class_name EngagementLog extends RefCounted
# Removable measurement of how often the player decides an outcome.
# Fed from RunSim.emit() and two combat hooks; it never writes sim state.
# Player-decided outcomes: a shot landing on a target in the player's lane, a gate charge tick,
# a telegraph avoided by moving, a coin pickup while steering, a gate pass, a special used.
const STEER_WINDOW := 1.0
const STEER_MIN := 0.3
const DODGE_MOVE := 0.8
var marks: Array = []           # [time, kind]
var steer_samples: Array = []   # [time, target_x] over the last STEER_WINDOW seconds
var gate_times: Array = []
var first_gate_t := -1.0
var boss_t := -1.0
var end_t := -1.0
var chosen_id := ""             # option picked at the first gate
var chosen_kind := ""
var payoff_from := -1.0
var payoff_t := -1.0
var telegraph_x := 0.0
var warned: Dictionary = {}     # enemy uid -> x when its telegraph started
var lane_half := 1.2
var evolution_t := -1.0
var bursts := 0

func setup(half_width: float) -> void:
	lane_half = half_width

func mark(t: float, kind: String) -> void:
	marks.append([t, kind])

func on_tick(sim) -> void:
	steer_samples.append([sim.t, sim.target_x])
	while steer_samples.size() > 1 and float(steer_samples[0][0]) < sim.t - STEER_WINDOW:
		steer_samples.pop_front()
	for enemy in sim.enemies:
		var uid: int = enemy.uid
		if enemy.warning and not warned.has(uid):
			warned[uid] = sim.x
		elif not enemy.warning and warned.has(uid) and enemy.id in ["gunner", "bruiser"]:
			# Telegraph resolved: counts if the player left the marked lane by moving.
			var started: float = warned[uid]
			if absf(sim.x - float(enemy.aim_x)) > 1.0 and absf(sim.x - started) >= DODGE_MOVE:
				mark(sim.t, "dodge")
			warned.erase(uid)

func steered() -> bool:
	if steer_samples.is_empty():
		return false
	var low := 1e9
	var high := -1e9
	for sample in steer_samples:
		low = minf(low, float(sample[1]))
		high = maxf(high, float(sample[1]))
	return high - low >= STEER_MIN

func on_event(sim, type: String, data: Dictionary) -> void:
	match type:
		"gate_choice":
			mark(sim.t, "gate")
			gate_times.append(sim.t)
			if first_gate_t < 0:
				first_gate_t = sim.t
				var option: Dictionary = data.option
				chosen_kind = str(option.kind)
				chosen_id = str(option.get("id", option.kind))
				payoff_from = sim.t
		"scrap":
			if data.has("chain") and steered():
				mark(sim.t, "pickup")
			_payoff(sim.t, "scrap")
		"special_used":
			mark(sim.t, "special")
		"boss_intro":
			boss_t = sim.t
		"clean_dodge":
			if absf(sim.x - telegraph_x) >= DODGE_MOVE:
				mark(sim.t, "dodge")
		"telegraph":
			telegraph_x = sim.x
		"shield_block":
			_payoff(sim.t, "shield")
		"player_hit":
			_payoff(sim.t, "armour")
		"cluster_burst":
			bursts += 1
			if evolution_t < 0:
				evolution_t = sim.t
		"gate_charge_tick":
			mark(sim.t, "charge")
		"payoff":
			_payoff(sim.t, str(data.get("source", "")))
			mark(sim.t, "payoff")
		"death", "boss_killed":
			end_t = sim.t

func on_hit(sim, bullet: Dictionary, enemy: Dictionary) -> void:
	if absf(float(enemy.x) - sim.x) <= lane_half:
		mark(sim.t, "shot")
	_payoff(sim.t, "hit:" + str(bullet.get("wid", "")))

# Chosen part shows its effect: weapons by a landed hit, defence by absorbing damage,
# anything else by the sim emitting an explicit "payoff" event.
func _payoff(t: float, source: String) -> void:
	if payoff_from < 0 or payoff_t >= 0 or chosen_id.is_empty():
		return
	var weapon: bool = chosen_kind == "part" and GameData.table("parts").has(chosen_id) and GameData.table("parts")[chosen_id].category == "weapon"
	var ok := false
	if weapon:
		ok = source == "hit:" + chosen_id
	elif chosen_id == "armour":
		ok = source == "armour"
	elif chosen_id == "shield":
		ok = source == "shield"
	elif chosen_id in ["magnet", "storage"]:
		ok = source == "scrap"
	else:
		ok = source == chosen_id
	if ok:
		payoff_t = t

func results(run_end: float) -> Dictionary:
	var sorted: Array = marks.duplicate()
	var horizon := boss_t if boss_t >= 0 else run_end
	return {
		"time_to_first_gate": first_gate_t,
		"time_to_first_payoff": (payoff_t - payoff_from) if payoff_t >= 0 else -1.0,
		"max_gap_pre_boss": _max_gap(sorted, horizon),
		"max_gap_full_run": _max_gap(sorted, run_end),
		"mark_count": sorted.size(),
		"marks_by_kind": _by_kind(sorted),
		"chosen": chosen_id,
		"evolution_t": evolution_t,
		"bursts": bursts}

func _by_kind(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for m in list:
		out[m[1]] = int(out.get(m[1], 0)) + 1
	return out

func _max_gap(list: Array, horizon: float) -> float:
	var previous := 0.0
	var worst := 0.0
	for m in list:
		if float(m[0]) > horizon:
			break
		worst = maxf(worst, float(m[0]) - previous)
		previous = float(m[0])
	return maxf(worst, horizon - previous)
