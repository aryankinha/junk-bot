class_name RunSim extends RefCounted
var t := 0.0
var z := 0.0
var x := 0.0
var target_x := 0.0
var level := 1
var seed_value := 1
var robot: RobotState
var rng := RngStreams.new()
var boss: BossSim
var events: Array = []
var state := "running"
var death_cause := ""
var beats: Array = []
var gate_history: Array = []
var enemies: Array = []
var bullets: Array = []
var hostile_bullets: Array = []
var scrap_nodes: Array = []
var hazards: Array = []
var fire_timers: Dictionary = {}
var boss_z := 720.0
var next_beat := 0
var next_scrap_z := 15.0
var losses := 0
var special_time := 0.0
var dash_time := 0.0
var sustained_fire_clock := 0.0
var last_boss_hit := -100.0
var free_rerolls := 1
var revived := false
var unlocked: Array = []
var oil_time := 0.0
var shot_count := 0
var entity_counter := 0
var pending_parts: Array = []
var chain := 0
var scrap_frac := 0.0
var chain_timer := 0.0
var best_chain := 0
var coin_index := 0
var frenzy_time := 0.0
var exposed_time := 0.0
var flags: Dictionary = {}
var flag_overrides: Dictionary = {}
var engage: EngagementLog
var mob: MobSim
var aim_target = null
var payoff_id := ""
var focus_hold := 0.0
var density_limit := 1.0
var last_target_x := 0.0
var payoff_paid := false

static func _deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	for key in over:
		if base.get(key) is Dictionary and over[key] is Dictionary:
			base[key] = _deep_merge(base[key], over[key])
		else:
			base[key] = over[key]
	return base

func setup(level_value := 1, seed_arg := 1, tiers: Dictionary = {}, loss_count := 0, early_unlocks: Array = []) -> void:
	flags = _deep_merge(GameData.flags().duplicate(true), flag_overrides)
	if flags.engagement_metrics:
		engage = EngagementLog.new()
		engage.setup(float(flags.tuning.lane_half_width))
	if flags.mob_stream:
		mob = MobSim.new()
		mob.setup(GameData.table("mob"), 0.0)
	level = level_value
	seed_value = seed_arg
	losses = loss_count
	unlocked = early_unlocks
	rng.seed_all(seed_value)
	robot = RobotState.new()
	robot.tiers = tiers.duplicate()
	robot.refresh()
	free_rerolls = int(GameData.constants().free_rerolls_per_run)
	beats = GameData.table("gates_level1").beats.duplicate(true)
	boss_z = float(GameData.table("gates_level1").boss_z)
	if level > 1:
		_generate_beats()
	if flags.post_gate_payoff and level == 1 and not flags.tuning.level1_first_gate.is_empty():
		# Content fix: Cannon vs Wheels is not a fair first choice (a weapon against no weapon).
		for beat in beats:
			if beat.type == "gate":
				beat.options = flags.tuning.level1_first_gate.map(func(id): return {"kind": "part", "id": id})
				break
	if flags.guarded_salvage:
		_add_salvage_beats()
	if flags.dense_blocks:
		_add_rhythm_beats()
	if flags.mob_stream:
		_add_mob_gates()
	var gate_index := 0
	for beat in beats:
		beat.resolved = false
		if beat.type == "gate":
			# Moving gates: from the third gate on, every other two-panel pair slides sideways.
			if flags.moving_gates and gate_index >= 2 and gate_index % 2 == 0 and beat.options.size() == 2:
				beat.moving = true
			gate_index += 1
		if flags.gate_charge and beat.type == "gate":
			beat.charge = []
			for option in beat.options:
				beat.charge.append(0.0)
		if beat.type == "repair_bay":
			beat.options = [{"kind": "repair"}, {"kind": "reroll"}, {"kind": "buy"}]
		elif beat.type == "final_choice":
			beat.options = [{"kind": "part", "id": "rocket"}, {"kind": "part", "id": "armour"}, {"kind": "part", "id": "cannon"}]
	if mob != null:
		mob.register_gates(beats)
	emit("run_start", {"level": level, "seed": seed_value})

# Mob gates (flag mob_stream): authored for Level 1 in data/mob.json, generated for later levels between the part gates.
func _add_mob_gates() -> void:
	var rules: Dictionary = GameData.table("mob").gates
	if level == 1:
		for row in rules.level1:
			beats.append({"z": float(row.z), "type": "mob_gate", "panels": row.panels.duplicate(true), "moving": bool(row.get("moving", false))})
			if row.has("pack"):
				beats.append({"z": float(row.z) + float(row.pack.dz), "type": "enemy_pack", "enemy": str(row.pack.enemy), "count": int(row.pack.count), "lane": "spread"})
	else:
		var gen: Dictionary = rules.generated
		var part_z: Array = beats.filter(func(b): return b.get("generated", false) and b.has("options")).map(func(b): return float(b.z))
		var finals: Array = beats.filter(func(b): return b.type == "final_choice")
		var row_z: Array = []
		for i in range(1, part_z.size()):
			row_z.append((part_z[i - 1] + part_z[i]) / 2.0)
		if not finals.is_empty():
			row_z.append(float(finals[0].z) + float(gen.final_dz))
		for i in row_z.size():
			var panels: Array = gen.rows[(i + level) % gen.rows.size()].duplicate(true)
			if level >= int(gen.three_panel_from_level) and i % 2 == 1 and panels.size() == 2:
				panels.append(gen.third_panel.duplicate(true))
			for panel in panels:
				if panel.t == "power":
					panel.v = int(panel.v) + int(gen.power_per_level) * (level - 1)
				elif panel.t == "add":
					panel.v = int(panel.v) + int(gen.add_per_level) * (level - 1)
			var moving: bool = i % int(gen.moving_every) == int(gen.moving_every) - 1 and panels.size() == 2
			beats.append({"z": row_z[i], "type": "mob_gate", "panels": panels, "moving": moving})
			beats.append({"z": row_z[i] + float(gen.pack_dz), "type": "enemy_pack", "enemy": ["scrapper", "gunner", "scrapper"][i % 3], "count": int(gen.pack_base) + level / 2 if i % 3 != 1 else 1, "lane": "spread"})
	if flags.mob_enemy_streams:
		_add_enemy_streams()
	beats.sort_custom(func(a, b): return a.z < b.z)

# Flag mob_enemy_streams: columns of scrappers down one lane between the mob gates.
func _add_enemy_streams() -> void:
	var rules: Dictionary = GameData.table("mob").enemy_streams
	if level == 1:
		for row in rules.level1:
			beats.append({"z": float(row.z), "type": "enemy_stream", "x": float(row.x), "count": int(row.count)})
	else:
		var rows: Array = beats.filter(func(b): return b.type == "mob_gate")
		for i in rows.size():
			beats.append({"z": float(rows[i].z) + float(rules.generated_after_row_m), "type": "enemy_stream", "x": 1.8 if i % 2 == 0 else -1.8, "count": int(rules.generated_count_base) + level / 2})

func _spawn_stream(beat: Dictionary) -> void:
	var count := _scaled(int(beat.count), float(beat.z))
	for i in count:
		_place("scrapper", float(beat.x), float(beat.z) + float(i) * float(GameData.table("mob").enemy_streams.spacing_m))
	emit("mob_enemy_stream", {"count": count})

func _generate_beats() -> void:
	beats.clear()
	var gen: Dictionary = GameData.table("level_generator")
	var distance := 80.0
	for i in mini(10, 5 + level):
		beats.append({"z": distance, "type": "gate", "options": GateGen.with_extra(GateGen.pair(level, robot, rng.gates, i, unlocked), level, i, rng.gates), "generated": true})
		beats.append({"z": distance + 40, "type": "enemy_pack", "enemy": ["scrapper", "gunner", "bruiser"][i % 3], "count": 4 if i % 3 == 0 else 1})
		distance += rng.gates.randf_range(float(gen.gate_spacing[0]), float(gen.gate_spacing[1]))
	boss_z = distance + 80
	beats.append({"z": boss_z * 0.5, "type": "miniboss", "enemy": "hauler"})
	beats.append({"z": boss_z * 0.7, "type": "repair_bay"})
	beats.append({"z": boss_z - 45, "type": "final_choice"})
	beats.sort_custom(func(a, b): return a.z < b.z)

# Guarded salvage: two lane-specific targets. One lane holds an explosive barrel between two gunners,
# the other a loot crate behind a gunner. Where the player steers decides what gets destroyed.
func _add_salvage_beats() -> void:
	if level == 1:
		beats.append({"z": 215.0, "type": "salvage"})
	else:
		var gates: Array = beats.filter(func(b): return b.has("options") and b.get("generated", false))
		for i in gates.size():
			if i % 2 == 1:
				beats.append({"z": float(gates[i].z) + 70.0, "type": "salvage"})
	beats.sort_custom(func(a, b): return a.z < b.z)

# Rhythm blocks (E4): authored for Level 1, generated for later levels. A short survival wave fills the
# run-in to the boss, coin arcs ask for steering, and enemy counts ramp up with progress.
func _add_rhythm_beats() -> void:
	var blocks: Dictionary = GameData.table("blocks")
	if level == 1:
		for block in blocks.level1:
			beats.append({"z": float(block.z), "type": str(block.type), "block": str(block.block)})
	else:
		var rules: Dictionary = blocks.generated
		var gate_zs: Array = beats.filter(func(b): return b.get("generated", false) and b.has("options")).map(func(b): return float(b.z))
		for i in gate_zs.size():
			beats.append({"z": gate_zs[i] - float(rules.coin_arc_before_gate_m), "type": "coin_arc", "block": "collect"})
			if not flags.guarded_salvage or i % 2 == 0:
				beats.append({"z": gate_zs[i] + float(rules.wave_after_gate_m), "type": "wave", "block": "survival"})
		beats.append({"z": boss_z - float(rules.pre_boss_wave_m), "type": "wave", "block": "survival"})
	beats.sort_custom(func(a, b): return a.z < b.z)

# Enemy count for a pack or wave at beat distance: ramps up to +density_ramp by the boss, scaled by the perf governor.
func _scaled(base: int, at_z: float) -> int:
	if not flags.dense_blocks:
		return base
	var ramp := 1.0 + float(flags.tuning.density_ramp) * clampf(at_z / maxf(boss_z, 1.0), 0.0, 1.0)
	return maxi(1, int(round(base * ramp * density_limit)))

func _spawn_wave(bz: float) -> void:
	var count := _scaled(int(flags.tuning.wave_scrappers), bz)
	spawn_pack("scrapper", count, bz)
	spawn_pack("scrapper", _scaled(int(flags.tuning.wave_second), bz), bz + 10.0)
	if level >= 2:
		spawn_pack("gunner", 1, bz + 6.0)
	emit("wave_spawn", {"count": count})

func _spawn_coin_arc(bz: float) -> void:
	var amplitude := float(flags.tuning.arc_amplitude)
	for i in int(flags.tuning.arc_coins):
		if scrap_nodes.size() < 400:
			coin_index += 1
			scrap_nodes.append({"x": amplitude * sin(float(i) * 0.95), "z": bz + float(i) * 2.4, "alive": true, "gold": i % 6 == 5})

func _spawn_salvage(bz: float) -> void:
	var blast_side := -1.0 if rng.spawns.randf() < 0.5 else 1.0
	var bx := blast_side * 2.0
	var lx := -blast_side * 2.0
	_place("barrel", bx, bz, "blast")
	_place("gunner", bx - 1.0, bz + 0.5)
	_place("gunner", bx + 1.0, bz + 0.5)
	_place("crate", lx, bz + 3.0, "loot")
	_place("gunner", lx, bz)
	emit("salvage_spawn", {"blast_x": bx, "loot_x": lx})

func _place(id: String, at_x: float, at_z: float, tag := "") -> void:
	var before := enemies.size()
	spawn_pack(id, 1, at_z)
	if enemies.size() == before:
		return
	var enemy: Dictionary = enemies.back()
	enemy.x = at_x
	enemy.z = at_z
	if id == "barrel":
		enemy.timer = 99.0
	if not tag.is_empty():
		enemy.salvage = tag

func emit(type: String, data: Dictionary = {}) -> void:
	events.append({"t": type, "time": snappedf(t, 0.0001)}.merged(data))
	if engage != null:
		engage.on_event(self, type, data)

func drag(dx: float) -> void:
	var width := float(GameData.constants().road_half_width)
	target_x = clampf(target_x + dx, -width + 0.3, width - 0.3)

func next_gate() -> Dictionary:
	for beat in beats:
		if not beat.resolved and beat.has("options"):
			return beat
	return {}

func reroll() -> bool:
	if free_rerolls <= 0:
		return false
	var gate := next_gate()
	if gate.is_empty():
		return false
	var had_extra: bool = gate.options.size() > 2
	gate.options = GateGen.pair(level, robot, rng.gates, gate_history.size(), unlocked)
	if had_extra:
		gate.options.append(GateGen.utility(rng.gates))
	free_rerolls -= 1
	emit("reroll")
	return true

func apply_option(option: Dictionary, bonus := 0) -> void:
	match str(option.kind):
		"part": robot.add_part(str(option.id), self, 1 + bonus)
		"upgrade_random_owned":
			var ids: Array = robot.parts.keys().filter(func(id): return int(robot.parts[id]) < 3)
			robot.add_part(str(ids[rng.loot.randi_range(0, ids.size() - 1)]) if not ids.is_empty() else "cannon", self, 1 + bonus)
		"tradeoff":
			robot.tradeoffs.append(option.id)
			robot.refresh(true)
			emit("tradeoff", {"id": option.id})
		"gamble":
			var roll := rng.loot.randf()
			if roll < 0.75:
				var ids := GateGen.available(level, robot, unlocked)
				if not ids.is_empty():
					robot.add_part(ids[rng.loot.randi_range(0, ids.size() - 1)], self, 2 if roll >= 0.6 else 1)
			else:
				collect_scrap(int(GameData.table("tradeoffs").crate.outcomes[2].scrap))
		"repair":
			var cost := int(GameData.table("economy").repair_bay.repair_cost)
			if robot.scrap >= cost:
				robot.scrap -= cost
				robot.repair(self)
			else:
				emit("station_unavailable", {"placement": "repair"})
		"reroll":
			# The repair bay itself is already resolved at this point.
			reroll()
		"buy":
			var cost := int(GameData.table("economy").repair_bay.buy_part_cost)
			if robot.scrap >= cost:
				robot.scrap -= cost
				pending_parts = GateGen.available(level, robot, unlocked)
				while pending_parts.size() > 3:
					pending_parts.remove_at(rng.gates.randi_range(0, pending_parts.size() - 1))
				if pending_parts.is_empty():
					robot.scrap += cost
					emit("station_unavailable", {"placement": "buy"})
				else:
					state = "choosing"
					emit("buy_offer")
			else:
				emit("station_unavailable", {"placement": "repair"})
		"scrap": collect_scrap(int(option.get("amount", 25)))
		"heal":
			robot.hp = minf(robot.max_hp, robot.hp + robot.max_hp * float(option.get("pct", 0.35)))
			emit("healed")
		"frenzy":
			frenzy_time = 12.0
			emit("frenzy")
		"surge":
			robot.overdrive = minf(100.0, robot.overdrive + 50.0)
			emit("surge")

func choose_purchase(id: String) -> bool:
	if state != "choosing" or not pending_parts.has(id):
		return false
	robot.add_part(id, self)
	pending_parts.clear()
	state = "running"
	return true

func collect_scrap(amount: int, chain_mult := 1.0, extra: Dictionary = {}) -> void:
	var raw := amount * float(robot.stats.scrap_mult) * chain_mult * (2.0 if frenzy_time > 0 else 1.0)
	var value := maxi(1, int(round(raw)))
	if chain_mult > 1.0:
		# Carry the fraction so a +1.5% chain bonus still pays out over a run.
		raw += scrap_frac
		value = maxi(1, int(floor(raw)))
		scrap_frac = raw - floor(raw)
	robot.scrap += value
	robot.collected += value
	emit("scrap", {"amount": value}.merged(extra))

# Picking up coins back to back builds a chain that raises their value (max +60%).
func pickup_coin(node: Dictionary) -> void:
	node.alive = false
	chain += 1
	best_chain = maxi(best_chain, chain)
	chain_timer = 1.4
	var gold: bool = node.get("gold", false)
	if node.get("bonus", false) and not payoff_paid:
		payoff_paid = true
		emit("payoff", {"source": payoff_id})
	collect_scrap(5 if gold else 1, 1.0 + minf(chain, 40) * 0.015, {"chain": chain, "gold": gold})

# Coin layouts rotate between waves, zigzags and lane lines, and lure toward a gate lane near gates.
func _coin_x(zc: float) -> float:
	for beat in beats:
		if beat.has("options") and not beat.resolved and float(beat.z) - zc < 30 and float(beat.z) - zc > 0:
			var count: int = beat.options.size()
			var lane := (int(beat.z) / 7) % count
			return -3.4 + 6.8 * (lane + 0.5) / count
	var seg := int(zc / 70.0) % 4
	match seg:
		0: return sin(zc * 0.06) * 2.0
		1: return absf(fposmod(zc, 18.0) - 9.0) / 9.0 * 4.4 - 2.2
		2: return float(int(zc / 70.0) % 3 - 1) * 2.2
		_: return sin(zc * 0.11) * 2.8

func spawn_pack(id: String, count: int, at_z: float) -> void:
	var def: Dictionary = GameData.table("enemies")[id]
	var enemy_cap := int(flags.tuning.dense_enemy_cap) if flags.dense_blocks else 24
	for i in mini(count, enemy_cap - enemies.size()):
		entity_counter += 1
		enemies.append({"uid": entity_counter, "id": id, "x": rng.spawns.randf_range(-2.7, 2.7), "z": at_z + float(i / 3) * 1.7, "hp": float(def.hp) * (0.8 if level == 1 else 1.0), "max_hp": float(def.hp), "timer": 1.5 + float(i) * 0.3, "warning": false, "aim_x": x, "windup": 0.0, "charge_left": 0.0, "charges_remaining": 0, "burn_left": 0.0, "burn_dps": 0.0})

func _spawn_beats() -> void:
	while next_beat < beats.size() and float(beats[next_beat].z) <= z + 45:
		var beat: Dictionary = beats[next_beat]
		match str(beat.type):
			"enemy_pack": spawn_pack(str(beat.enemy), _scaled(int(beat.count), float(beat.z)), float(beat.z))
			"enemy_stream": _spawn_stream(beat)
			"wave": _spawn_wave(float(beat.z))
			"coin_arc": _spawn_coin_arc(float(beat.z))
			"miniboss": spawn_pack("hauler", 1, float(beat.z))
			"salvage": _spawn_salvage(float(beat.z))
			"hazard":
				if beat.kind == "barrel":
					spawn_pack("barrel", 1, float(beat.z))
					enemies.back().x = 1.8
				else:
					hazards.append({"id": beat.kind, "z": float(beat.z), "x": -1.8 if beat.kind in ["saw", "oil"] else 1.8, "used": false})
		next_beat += 1
	while next_scrap_z < z + 55 and next_scrap_z < boss_z:
		if scrap_nodes.size() < 400:
			if int(next_scrap_z / 2.8) % 20 < 14:
				coin_index += 1
				scrap_nodes.append({"x": _coin_x(next_scrap_z), "z": next_scrap_z, "alive": true, "gold": coin_index % 14 == 0})
		next_scrap_z += 2.8

func _resolve_gates() -> void:
	for beat in beats:
		if beat.resolved or z < float(beat.z):
			continue
		beat.resolved = true
		if beat.has("options"):
			var opts: Array = beat.options
			var lane := _panel_lane(beat, x)
			var bonus := charge_bonus(beat, lane)
			apply_option(opts[lane], bonus)
			if bonus > 0:
				emit("gate_charged", {"lane": lane, "bonus": bonus})
			if flags.post_gate_payoff and beat.type == "gate" and gate_history.is_empty():
				_spawn_payoff(opts[lane], float(beat.z))
			if beat.type == "final_choice":
				# A rare final reward gives a visible merge and makes stage 3 reachable.
				if opts[lane].kind == "part":
					robot.add_part(str(opts[lane].id), self, int(GameData.table("gates_level1").get("final_choice_grant_levels", 2)) - 1)
				for merge in int(GameData.table("gates_level1").get("final_choice_bonus_merges", 0)):
					var eligible: Array = robot.parts.keys().filter(func(id): return int(robot.parts[id]) < 3)
					if not eligible.is_empty():
						eligible.sort_custom(func(a, b): return int(robot.parts[a]) < int(robot.parts[b]))
						robot.add_part(str(eligible[0]), self)
			gate_history.append({"z": beat.z, "side": lane, "option": opts[lane]})
			emit("gate_choice", gate_history.back())

# Gate charge (E2): shots that cross a gate panel charge it; thresholds raise the part level it grants.
func chargeable(option: Dictionary) -> bool:
	return option.kind in ["part", "upgrade_random_owned"]

# Weaker parts level up on less charge, stronger ones need more, so aiming at either panel is a real trade.
func charge_cost(option: Dictionary) -> float:
	return float(flags.tuning.charge_cost.get(str(option.get("id", "")), 1.0))

func charge_bonus(beat: Dictionary, lane: int) -> int:
	if not beat.has("charge") or not chargeable(beat.options[lane]):
		return 0
	var amount: float = beat.charge[lane]
	var cost := charge_cost(beat.options[lane])
	return int(amount >= float(flags.tuning.charge_t1) * cost) + int(amount >= float(flags.tuning.charge_t2) * cost)

func _panel_lane(gate: Dictionary, at_x: float) -> int:
	var count: int = gate.options.size()
	if gate.get("moving", false):
		# Moving panels: the nearest panel centre wins, so crossing between panels never loses the pick.
		var best := 0
		for lane in count:
			if absf(at_x - panel_center(gate, lane, t)) < absf(at_x - panel_center(gate, best, t)):
				best = lane
		return best
	var half := float(GameData.constants().road_half_width)
	return clampi(int(floor((at_x + half) / (2 * half) * count)), 0, count - 1)

# Sideways slide of a moving gate pair; a pure function of time so it is deterministic and telegraphed.
func gate_offset(gate: Dictionary, at_t: float) -> float:
	if not gate.get("moving", false):
		return 0.0
	return float(flags.tuning.moving_amplitude) * sin(TAU * at_t / float(flags.tuning.moving_period) + float(gate.z) * 0.37)

func panel_center(gate: Dictionary, lane: int, at_t: float) -> float:
	var count: int = gate.options.size()
	if gate.get("moving", false):
		return (float(lane) - (count - 1) / 2.0) * float(flags.tuning.moving_spacing) + gate_offset(gate, at_t)
	var half := float(GameData.constants().road_half_width)
	return -half + 2.0 * half / count * (lane + 0.5)

func _add_charge(gate: Dictionary, lane: int, amount: float) -> void:
	var before := charge_bonus(gate, lane)
	gate.charge[lane] += amount
	var after := charge_bonus(gate, lane)
	emit("gate_charge_tick", {"lane": lane, "charge": snappedf(gate.charge[lane], 0.01)})
	if after > before:
		emit("gate_level_up", {"lane": lane, "bonus": after})

func _charge_gate(bullet: Dictionary, prev_z: float) -> bool:
	var gate := next_gate()
	if gate.is_empty() or not gate.has("charge"):
		return false
	var gz := float(gate.z)
	if prev_z >= gz or float(bullet.z) < gz or gz - z > float(flags.tuning.charge_range):
		return false
	var lane := _panel_lane(gate, float(bullet.x))
	if gate.get("moving", false) and absf(float(bullet.x) - panel_center(gate, lane, t)) > float(flags.tuning.moving_half):
		return false
	if not chargeable(gate.options[lane]):
		return false
	_add_charge(gate, lane, float(bullet.get("charge", 0.0)))
	return true

func _charge_cone(weapon: Dictionary, dt: float) -> void:
	var gate := next_gate()
	if gate.is_empty() or not gate.has("charge"):
		return
	var gap := float(gate.z) - z
	if gap <= 0 or gap > float(weapon.range) or gap > float(flags.tuning.charge_range):
		return
	var lane := _panel_lane(gate, x)
	if chargeable(gate.options[lane]):
		_add_charge(gate, lane, _bullet_charge(weapon) * dt)

# Right after the first gate, a small formation lets the chosen part show its effect within 1-2 s.
func _spawn_payoff(option: Dictionary, gate_z: float) -> void:
	var id := str(option.get("id", ""))
	var at_z := gate_z + float(flags.tuning.payoff_distance)
	payoff_id = id
	var category: String = str(GameData.table("parts")[id].category) if option.kind == "part" else "collection"
	match category:
		"weapon":
			# Tight cluster of scrappers: cannon shreds it, rockets and flame splash through it.
			for i in 4:
				_place("scrapper", clampf(x + [-0.9, 0.9, -0.45, 0.45][i], -3.0, 3.0), at_z + float(i / 2) * 0.9, "payoff")
		"movement":
			# Bonus route: a swerving golden coin line that rewards the sharper steering.
			var side := -1.0 if x > 0 else 1.0
			for i in 14:
				scrap_nodes.append({"x": clampf(side * 2.3 * sin(float(i) * 0.55) + x * 0.3, -3.0, 3.0), "z": at_z - 6.0 + float(i) * 1.5, "alive": true, "gold": i % 4 == 0, "bonus": true})
		"defence":
			_place("gunner", clampf(x - 1.8, -3.0, 3.0), at_z, "payoff")
			_place("gunner", clampf(x + 1.8, -3.0, 3.0), at_z, "payoff")
			for e in enemies:
				if e.get("salvage", "") == "payoff":
					e.timer = 0.2
		_:
			# Collectors: a wide scatter of coins that the bigger magnet or storage clearly pays off.
			for i in 16:
				scrap_nodes.append({"x": -2.8 + float(i % 8) * 0.8, "z": at_z - 4.0 + float(i / 8) * 3.0, "alive": true, "gold": i % 5 == 0, "bonus": true})

# Focus fire (A/B hypothesis): holding a lane without steering ramps fire rate; any steering resets it.
func focus_multiplier() -> float:
	if not flags.focus_fire:
		return 1.0
	var ramp := clampf((focus_hold - float(flags.tuning.focus_hold_s)) / float(flags.tuning.focus_ramp_s), 0.0, 1.0)
	return 1.0 + float(flags.tuning.focus_max_bonus) * ramp

# Weapon evolution (E5): Cluster Rockets. Needs the cannon + rocket combo (Burst Volley) and the rocket at level 2+.
# A rocket that hits an enemy then splits into bomblets that seek nearby enemies or fan out ahead.
func evolution_active() -> bool:
	return flags.weapon_evolution and int(robot.parts.get("rocket", 0)) >= int(flags.tuning.evolution_rocket_level) and robot.combos().has("burst_volley")

func _split_rocket(bullet: Dictionary, hit: Dictionary) -> void:
	var children := 0
	for b in bullets:
		if b.type == "cluster":
			children += 1
	var cap := int(flags.tuning.evolution_child_cap)
	var targets: Array = enemies.filter(func(e): return e != hit and e.hp > 0 and Vector2(float(e.x) - float(hit.x), float(e.z) - float(hit.z)).length() < float(flags.tuning.evolution_reach))
	targets.sort_custom(func(a, b): return Vector2(float(a.x) - float(hit.x), float(a.z) - float(hit.z)).length() < Vector2(float(b.x) - float(hit.x), float(b.z) - float(hit.z)).length())
	var spawned := 0
	for i in int(flags.tuning.evolution_children):
		if children + spawned >= cap or bullets.size() + hostile_bullets.size() >= 64:
			break
		var tx: float = float(hit.x) + (i - 1) * 2.2
		var tz: float = float(hit.z) + 6.0
		if i < targets.size():
			tx = float(targets[i].x)
			tz = float(targets[i].z)
		bullets.append({"x": hit.x, "z": hit.z, "tx": tx, "tz": tz, "type": "cluster", "wid": "cluster", "charge": 0.0, "damage": float(bullet.damage) * float(flags.tuning.evolution_damage_pct), "speed": 26.0, "radius": float(flags.tuning.evolution_radius), "ttl": 0.6})
		spawned += 1
	if spawned > 0:
		emit("cluster_burst", {"x": hit.x, "z": hit.z, "children": spawned})

func tap_special() -> bool:
	var combos := robot.combos()
	var chosen := ""
	for id in combos:
		if float(robot.cooldowns.get(id, 0)) <= 0:
			chosen = id
			break
	var overcharged := robot.overdrive >= 100
	if chosen.is_empty() and not overcharged:
		return false
	if overcharged:
		robot.overdrive = 0
		if mob != null:
			# Mob Stream: a full Overdrive also launches one champion drone, whether or not a combo special fires.
			mob.launch_champion(self, true)
	if not chosen.is_empty():
		var def: Dictionary = GameData.table("combos")[chosen]
		robot.cooldowns[chosen] = float(def.cooldown_s)
		match chosen:
			"burst_volley":
				special_time = float(def.special.duration_s)
				for i in int(def.special.homing_rockets):
					_fire({"id": "special", "type": "rocket", "damage": 40 * (1.5 if overcharged else 1.0), "speed": 30, "area_radius": 2.8}, i * 0.12)
			"ram_charge":
				robot.invuln = float(def.special.duration_s)
				dash_time = float(def.special.duration_s)
				for enemy in enemies:
					if Vector2(float(enemy.x) - x, float(enemy.z) - z).length() < float(def.special.knockback):
						enemy.hp -= float(def.special.damage) * (1.5 if overcharged else 1.0)
						enemy.z += float(def.special.knockback)
			"vacuum":
				for node in scrap_nodes:
					if node.alive:
						node.alive = false
						collect_scrap(1)
	else:
		special_time = float(GameData.table("boss_scrap_titan").overdrive.no_combo_effect.duration_s)
	emit("special_used", {"id": chosen if not chosen.is_empty() else "overdrive"})
	return true

# Mob Stream always fires along the lane, whatever aim_mode says.
func _lane_aim() -> bool:
	return flags.aim_mode == "lane" or flags.mob_stream

# Auto-fire target. "nearest" is the legacy rule: closest enemy inside a wide cone.
# "lane" keeps shots to the lane the robot stands in: closest enemy inside a narrow aim-assist cone.
func _pick_target():
	var target = null
	var distance := float(GameData.constants().auto_fire_range)
	var lane: bool = _lane_aim()
	var cone := deg_to_rad(float(flags.tuning.aim_cone_deg) if lane else float(GameData.constants().auto_fire_cone_deg))
	for enemy in enemies:
		var dz: float = float(enemy.z) - z
		var dx: float = float(enemy.x) - x
		if enemy.hp > 0 and dz > 0 and dz < distance and absf(atan2(dx, dz)) <= cone:
			distance = dz
			target = enemy
	return target

# Seconds of full firepower one bullet is worth, so every build charges a gate at about 1.0 per second of focus.
func _bullet_charge(weapon: Dictionary) -> float:
	if not flags.gate_charge:
		return 0.0
	var nominal := 0.0
	for w in robot.stats.weapons:
		if w.type == "cone":
			nominal += float(w.damage)
		else:
			nominal += float(w.damage) * float(w.rate) * float(w.get("barrels", 1))
	return float(weapon.get("damage", 4)) / maxf(nominal, 1.0)

func _fire(weapon: Dictionary, offset := 0.0) -> void:
	if mob != null:
		# Mob Stream: the shot becomes a volley of drones (damage split across the volley).
		shot_count += 1
		mob.launch_volley(self, weapon, offset)
		if shot_count % 3 == 0:
			emit("weapon_fire", {"id": weapon.id})
		return
	if bullets.size() + hostile_bullets.size() >= 64:
		return
	var target = _pick_target()
	var straight: bool = (flags.aim_mode == "lane" or flags.gate_charge) and state != "boss"
	if target == null and state != "boss" and not straight:
		return
	shot_count += 1
	# Straight shots only travel as far as the auto-fire range (or the gate charge range when charging).
	var ttl := 2.0
	if target == null and straight:
		var reach := float(flags.tuning.charge_range) if flags.gate_charge else float(GameData.constants().auto_fire_range)
		ttl = reach / float(weapon.get("speed", 36)) + 0.05
	var tx: float = float(target.x) if target != null else (x if straight else 0.0)
	var tz: float = float(target.z) if target != null else (z + 70.0 if straight else z + 16)
	bullets.append({"x": x, "z": z + 0.8 + offset, "tx": tx, "tz": tz, "type": weapon.type, "damage": float(weapon.get("damage", 4)) * float(robot.stats.dps_mult), "wid": weapon.id, "charge": _bullet_charge(weapon), "speed": float(weapon.get("speed", 36)), "radius": float(weapon.get("area_radius", 0)), "ttl": ttl})
	if shot_count % 3 == 0:
		emit("weapon_fire", {"id": weapon.id})

func _combat(dt: float) -> void:
	for enemy in enemies:
		if float(enemy.burn_left) > 0:
			enemy.hp -= float(enemy.burn_dps) * dt
			enemy.burn_left -= dt
	for weapon in robot.stats.weapons:
		var id: String = weapon.id
		if weapon.type == "cone" and mob != null:
			var launched := mob.flame(self, weapon, dt)
			if flags.gate_charge:
				_charge_cone(weapon, dt)
			if launched and (state == "boss" or enemies.any(func(e): return e.hp > 0 and float(e.z) > z and float(e.z) - z < float(weapon.range))):
				emit("weapon_fire", {"id": id})
			continue
		if weapon.type == "cone":
			var firing := false
			for enemy in enemies:
				if absf(float(enemy.x) - x) < 2.4 and float(enemy.z) - z < float(weapon.range) and float(enemy.z) > z:
					enemy.hp -= float(weapon.damage) * dt * float(robot.stats.dps_mult)
					firing = true
					enemy.burn_left = float(weapon.burn_s)
					enemy.burn_dps = float(weapon.burn_dps) * float(robot.stats.dps_mult)
			if state == "boss" and boss.roar <= 0:
				boss.apply_hit("cone", float(weapon.damage) * dt * float(robot.stats.dps_mult), self)
				firing = true
				boss.burn_left = float(weapon.burn_s)
				boss.burn_dps = float(weapon.burn_dps) * float(robot.stats.dps_mult)
			if flags.gate_charge:
				_charge_cone(weapon, dt)
			fire_timers[id] = float(fire_timers.get(id, 0)) - dt
			if firing and float(fire_timers[id]) <= 0:
				fire_timers[id] = 0.16
				emit("weapon_fire", {"id": id})
			continue
		fire_timers[id] = float(fire_timers.get(id, 0)) - dt
		if float(fire_timers[id]) <= 0:
			fire_timers[id] = 1.0 / (float(weapon.rate) * (2.0 if special_time > 0 else 1.0) * focus_multiplier())
			for barrel in int(weapon.get("barrels", 1)):
				_fire(weapon, barrel * 0.15)
	if mob != null:
		mob.cap_scale = density_limit
		mob.step(self, dt)
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var direction := Vector2(float(bullet.tx) - float(bullet.x), float(bullet.tz) - float(bullet.z)).normalized()
		var prev_z: float = bullet.z
		bullet.x += direction.x * float(bullet.speed) * dt
		bullet.z += direction.y * float(bullet.speed) * dt
		bullet.ttl -= dt
		var impacted: bool = flags.gate_charge and _charge_gate(bullet, prev_z)
		for enemy in enemies:
			if impacted or enemy.hp <= 0:
				continue
			if Vector2(float(enemy.x) - float(bullet.x), float(enemy.z) - float(bullet.z)).length() < 0.85:
				enemy.hp -= float(bullet.damage)
				if engage != null:
					engage.on_hit(self, bullet, enemy)
				if bullet.type == "rocket" and flags.weapon_evolution and evolution_active():
					_split_rocket(bullet, enemy)
				if float(bullet.radius) > 0:
					for other in enemies:
						if other != enemy and Vector2(float(other.x) - float(enemy.x), float(other.z) - float(enemy.z)).length() < float(bullet.radius):
							other.hp -= float(bullet.damage)
				impacted = true
				break
		if not impacted and state == "boss" and float(bullet.z) >= z + 14:
			boss.apply_hit(str(bullet.type), float(bullet.damage) * (1.5 if exposed_time > 0 else 1.0), self, "arm" if boss.arm_hp > 0 else "core")
			if boss.roar <= 0:
				last_boss_hit = t
			impacted = true
		if impacted or float(bullet.ttl) <= 0:
			bullets.remove_at(i)
	for i in range(hostile_bullets.size() - 1, -1, -1):
		var bolt: Dictionary = hostile_bullets[i]
		bolt.x += float(bolt.vx) * dt
		bolt.z += float(bolt.vz) * dt
		bolt.ttl -= dt
		if Vector2(float(bolt.x) - x, float(bolt.z) - z).length() < 0.8:
			robot.take_damage(float(bolt.damage), self, "gunner")
			bolt.ttl = 0
		if float(bolt.ttl) <= 0:
			hostile_bullets.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var def: Dictionary = GameData.table("enemies")[enemy.id]
		if float(enemy.hp) <= 0:
			if enemy.id == "barrel":
				for other in enemies:
					if other != enemy and Vector2(float(other.x) - float(enemy.x), float(other.z) - float(enemy.z)).length() < float(def.blast_radius):
						other.hp -= float(def.blast_damage_enemy)
				if Vector2(x - float(enemy.x), z - float(enemy.z)).length() < float(def.blast_radius):
					robot.take_damage(float(def.blast_damage_player), self, "barrel")
			collect_scrap(int(def.get("scrap", 2)))
			emit("enemy_death", {"x": enemy.x, "z": enemy.z, "id": enemy.id})
			if enemy.id == "crate":
				for k in int(def.get("coin_burst", 10)):
					scrap_nodes.append({"x": clampf(float(enemy.x) + sin(k * 2.4) * 1.4, -3.0, 3.0), "z": float(enemy.z) + 0.8 + float(k) * 0.5, "alive": true, "gold": k % 5 == 0})
				emit("salvage_looted", {"x": enemy.x, "z": enemy.z})
			if enemy.id == "hauler":
				# Jackpot: the crate bursts into a spray of coins and drops a rare part.
				var reward: Dictionary = GameData.table("gates_level1").miniboss_rare_reward
				robot.add_part(str(reward.id), self, int(reward.level))
				for k in int(def.get("coin_burst", 18)):
					scrap_nodes.append({"x": clampf(float(enemy.x) + sin(k * 2.4) * 2.0, -3.0, 3.0), "z": float(enemy.z) + 1.0 + float(k) * 0.55, "alive": true, "gold": k % 6 == 0})
				emit("hauler_destroyed", {"x": enemy.x, "z": enemy.z})
			enemies.remove_at(i)
			continue
		var gap: float = float(enemy.z) - z
		if enemy.id == "crate":
			if gap < -5:
				enemies.remove_at(i)
			continue
		if enemy.id == "hauler":
			_hauler(enemy, def, dt)
			if gap < -5:
				emit("hauler_missed")
				enemies.remove_at(i)
			continue
		if gap < 22 and gap > -3:
			enemy.timer -= dt
			if enemy.id == "barrel":
				if absf(gap) < 1.1 and absf(float(enemy.x) - x) < 1.0:
					robot.take_damage(float(def.blast_damage_player), self, "barrel")
					enemy.hp = 0
			elif enemy.id == "scrapper":
				enemy.z -= float(def.speed) * dt
				enemy.x = move_toward(float(enemy.x), x, dt * 1.2)
				if absf(gap) < 1.2 and absf(float(enemy.x) - x) < 0.8:
					robot.take_damage(float(def.contact_damage), self, "scrapper")
			elif float(enemy.charge_left) > 0:
				enemy.charge_left -= dt
				enemy.z -= float(def.get("charge_speed", 14)) * dt
				if absf(float(enemy.z) - z) < 1.1 and absf(float(enemy.x) - x) < 0.9:
					robot.take_damage(float(def.get("charge_damage", 20)), self, str(enemy.id))
				if float(enemy.charge_left) <= 0:
					if int(enemy.charges_remaining) > 0:
						enemy.warning = true
						enemy.aim_x = x
						enemy.timer = 0.5
			elif float(enemy.timer) <= 0:
				if not enemy.warning:
					enemy.warning = true
					enemy.aim_x = x
					enemy.timer = float(def.get("telegraph_s", def.get("windup_s", 1.0)))
					emit("enemy_warning", {"id": enemy.id})
				else:
					if enemy.id == "gunner":
						if hostile_bullets.size() < 16 and bullets.size() + hostile_bullets.size() < 64:
							var direction := Vector2(float(enemy.aim_x) - float(enemy.x), z - float(enemy.z)).normalized()
							hostile_bullets.append({"x": enemy.x, "z": enemy.z, "vx": direction.x * float(def.bolt_speed), "vz": direction.y * float(def.bolt_speed), "damage": float(def.bolt_damage), "ttl": 3.0})
					else:
						enemy.x = float(enemy.aim_x)
						enemy.charge_left = maxf(1.0, (float(enemy.z) - z + 2) / float(def.get("charge_speed", 14)))
						if int(enemy.charges_remaining) <= 0:
							enemy.charges_remaining = 2 if def.get("double_charge", false) else 1
						enemy.charges_remaining -= 1
					enemy.warning = false
					enemy.timer = float(def.get("fire_interval_s", def.get("charge_cooldown_s", 3.0)))
		if gap < -5:
			enemies.remove_at(i)

# The Scrap Hauler drives away down the road with a loot crate and drops barrels behind it.
# Shooting those barrels near the truck hurts it, so the chase rewards aim over reflexes.
func _hauler(enemy: Dictionary, def: Dictionary, dt: float) -> void:
	if not enemy.get("seen", false) and float(enemy.z) - z < 40:
		enemy.seen = true
		emit("hauler_spawn")
	if not enemy.get("seen", false):
		return
	enemy.z += float(def.speed) * dt
	enemy.x = sin(t * 1.3 + float(enemy.uid)) * 2.2
	enemy.timer -= dt
	if float(enemy.timer) <= 0 and float(enemy.z) - z > 4 and enemies.size() < 20:
		enemy.timer = float(def.drop_interval_s)
		spawn_pack("barrel", 1, float(enemy.z) - 3.0)
		enemies.back().x = enemy.x
		enemies.back().timer = 99.0

func step(dt: float) -> void:
	# Subdivision also makes externally supplied long steps safe.
	var remaining := dt
	while remaining > 0.000001:
		var sub := minf(remaining, 1.0 / float(GameData.constants().sim_hz))
		_tick(sub)
		remaining -= sub

func _tick(dt: float) -> void:
	if state in ["won", "lost", "choosing"]:
		return
	t += dt
	robot.tick(dt)
	special_time = maxf(0, special_time - dt)
	dash_time = maxf(0, dash_time - dt)
	oil_time = maxf(0, oil_time - dt)
	frenzy_time = maxf(0, frenzy_time - dt)
	exposed_time = maxf(0, exposed_time - dt)
	if chain_timer > 0:
		chain_timer -= dt
		if chain_timer <= 0:
			chain = 0
	if flags.focus_fire:
		focus_hold = focus_hold + dt if absf(target_x - last_target_x) < 0.002 else 0.0
		last_target_x = target_x
	x = lerpf(x, target_x, 1 - exp(-float(GameData.constants().lateral_follow_rate) * float(robot.stats.steer_mult) * dt))
	if state == "running":
		var speed: float = float(GameData.constants().forward_speed) * float(robot.stats.fwd_mult) * (0.6 if oil_time > 0 else 1.0)
		if dash_time > 0:
			speed *= float(GameData.table("combos").ram_charge.special.speed_mult)
		z += speed * dt
		_spawn_beats()
		_resolve_gates()
		for node in scrap_nodes:
			if node.alive and Vector2(float(node.x) - x, float(node.z) - z).length() < float(robot.stats.magnet_radius) * (1.6 if frenzy_time > 0 else 1.0):
				pickup_coin(node)
		for hazard in hazards:
			if hazard.id == "saw":
				hazard.x = sin(t * 2.0) * 2.8
			if not hazard.used and absf(float(hazard.z) - z) < 1.1 and absf(float(hazard.x) - x) < 1.2:
				hazard.used = true
				if hazard.id == "oil":
					if not robot.stats.oil_immune:
						oil_time = 1.5
				else:
					robot.take_damage(float(GameData.table("enemies")[hazard.id].get("damage", 25)), self, str(hazard.id))
		if z >= boss_z:
			state = "boss"
			boss = BossSim.new()
			boss.setup(level, losses)
			if mob != null:
				boss.max_hp *= float(GameData.table("mob").boss_hp_mult)
				boss.hp = boss.max_hp
			enemies.clear()
			hazards.clear()
			emit("boss_intro")
	_combat(dt)
	if _lane_aim():
		aim_target = _pick_target()
	if engage != null:
		engage.on_tick(self)
	if state == "boss":
		var overdrive: Dictionary = GameData.table("boss_scrap_titan").overdrive
		if t - last_boss_hit <= float(overdrive.sustained_window_s) + 0.000001:
			sustained_fire_clock += dt
			while sustained_fire_clock >= 0.5 - 0.000001:
				sustained_fire_clock -= 0.5
				robot.overdrive = minf(float(overdrive.max), robot.overdrive + float(overdrive.per_sustained_fire_half_second))
		else:
			sustained_fire_clock = 0
		boss.tick(dt, self)

func revive() -> bool:
	if revived or state != "lost":
		return false
	revived = true
	robot.hp = robot.max_hp * float(GameData.constants().revive_hp_pct)
	robot.invuln = 2.0
	state = "boss" if boss != null else "running"
	emit("revive")
	return true
