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

func setup(level_value := 1, seed_arg := 1, tiers: Dictionary = {}, loss_count := 0, early_unlocks: Array = []) -> void:
	flags = GameData.flags().merged(flag_overrides, true)
	if flags.engagement_metrics:
		engage = EngagementLog.new()
		engage.setup(float(flags.tuning.lane_half_width))
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
	for beat in beats:
		beat.resolved = false
		if beat.type == "repair_bay":
			beat.options = [{"kind": "repair"}, {"kind": "reroll"}, {"kind": "buy"}]
		elif beat.type == "final_choice":
			beat.options = [{"kind": "part", "id": "rocket"}, {"kind": "part", "id": "armour"}, {"kind": "part", "id": "cannon"}]
	emit("run_start", {"level": level, "seed": seed_value})

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

func apply_option(option: Dictionary) -> void:
	match str(option.kind):
		"part": robot.add_part(str(option.id), self)
		"upgrade_random_owned":
			var ids: Array = robot.parts.keys().filter(func(id): return int(robot.parts[id]) < 3)
			robot.add_part(str(ids[rng.loot.randi_range(0, ids.size() - 1)]) if not ids.is_empty() else "cannon", self)
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
	for i in mini(count, 24 - enemies.size()):
		entity_counter += 1
		enemies.append({"uid": entity_counter, "id": id, "x": rng.spawns.randf_range(-2.7, 2.7), "z": at_z + float(i / 3) * 1.7, "hp": float(def.hp) * (0.8 if level == 1 else 1.0), "max_hp": float(def.hp), "timer": 1.5 + float(i) * 0.3, "warning": false, "aim_x": x, "windup": 0.0, "charge_left": 0.0, "charges_remaining": 0, "burn_left": 0.0, "burn_dps": 0.0})

func _spawn_beats() -> void:
	while next_beat < beats.size() and float(beats[next_beat].z) <= z + 45:
		var beat: Dictionary = beats[next_beat]
		match str(beat.type):
			"enemy_pack": spawn_pack(str(beat.enemy), int(beat.count), float(beat.z))
			"miniboss": spawn_pack("hauler", 1, float(beat.z))
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
			var lane := clampi(int(floor((x + float(GameData.constants().road_half_width)) / (2 * float(GameData.constants().road_half_width)) * opts.size())), 0, opts.size() - 1)
			apply_option(opts[lane])
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

func _fire(weapon: Dictionary, offset := 0.0) -> void:
	if bullets.size() + hostile_bullets.size() >= 64:
		return
	var target = null
	var distance := float(GameData.constants().auto_fire_range)
	var cone := deg_to_rad(float(GameData.constants().auto_fire_cone_deg))
	for enemy in enemies:
		var dz: float = float(enemy.z) - z
		var dx: float = float(enemy.x) - x
		if enemy.hp > 0 and dz > 0 and dz < distance and absf(atan2(dx, dz)) <= cone:
			distance = dz
			target = enemy
	if target == null and state != "boss":
		return
	shot_count += 1
	var tx: float = float(target.x) if target != null else 0.0
	var tz: float = float(target.z) if target != null else z + 16
	bullets.append({"x": x, "z": z + 0.8 + offset, "tx": tx, "tz": tz, "type": weapon.type, "damage": float(weapon.get("damage", 4)) * float(robot.stats.dps_mult), "wid": weapon.id, "speed": float(weapon.get("speed", 36)), "radius": float(weapon.get("area_radius", 0)), "ttl": 2.0})
	if shot_count % 3 == 0:
		emit("weapon_fire", {"id": weapon.id})

func _combat(dt: float) -> void:
	for enemy in enemies:
		if float(enemy.burn_left) > 0:
			enemy.hp -= float(enemy.burn_dps) * dt
			enemy.burn_left -= dt
	for weapon in robot.stats.weapons:
		var id: String = weapon.id
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
			fire_timers[id] = float(fire_timers.get(id, 0)) - dt
			if firing and float(fire_timers[id]) <= 0:
				fire_timers[id] = 0.16
				emit("weapon_fire", {"id": id})
			continue
		fire_timers[id] = float(fire_timers.get(id, 0)) - dt
		if float(fire_timers[id]) <= 0:
			fire_timers[id] = 1.0 / (float(weapon.rate) * (2.0 if special_time > 0 else 1.0))
			for barrel in int(weapon.get("barrels", 1)):
				_fire(weapon, barrel * 0.15)
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		var direction := Vector2(float(bullet.tx) - float(bullet.x), float(bullet.tz) - float(bullet.z)).normalized()
		bullet.x += direction.x * float(bullet.speed) * dt
		bullet.z += direction.y * float(bullet.speed) * dt
		bullet.ttl -= dt
		var impacted := false
		for enemy in enemies:
			if enemy.hp <= 0:
				continue
			if Vector2(float(enemy.x) - float(bullet.x), float(enemy.z) - float(bullet.z)).length() < 0.85:
				enemy.hp -= float(bullet.damage)
				if engage != null:
					engage.on_hit(self, bullet, enemy)
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
			enemies.clear()
			hazards.clear()
			emit("boss_intro")
	_combat(dt)
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
