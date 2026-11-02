class_name MobSim extends RefCounted
# Mob Stream (flag mob_stream): the robot fires a stream of small drones instead of single bullets.
# Struct-of-arrays, no physics bodies. A volley of N drones splits the old per-shot damage N ways, so
# without mob gates the stream deals the same damage per second as before; gates then multiply it.
enum Kind { BOLT, BOMB, TORCH, CHAMPION }
const KIND_NAMES := ["bolt", "bomb", "torch", "champion"]
const KIND_TYPE := ["projectile", "rocket", "cone", "rocket"]  # weapon type the boss sees (plate rule)

var hook_owner
var cohort := PackedInt64Array()
var unit_damage := PackedFloat64Array()
var material := PackedInt32Array()
var active_cohort := 0
var active_unit_damage := 1.0
var active_material := 1
var cfg: Dictionary
var n := 0
var px := PackedFloat64Array()
var py := PackedFloat64Array()
var pz := PackedFloat64Array()
var vx := PackedFloat64Array()
var vz := PackedFloat64Array()
var dmg := PackedFloat64Array()
var wgt := PackedFloat64Array()     # damage relative to the launch damage; drives scale and impact size
var life := PackedFloat64Array()
var chg := PackedFloat64Array()     # gate-charge value carried (conserved across multiplication)
var burn := PackedFloat64Array()    # burn dps applied on hit (torch)
var rad := PackedFloat64Array()     # splash radius (bomb)
var kind := PackedInt32Array()
var pierce := PackedInt32Array()
var lasthit := PackedInt32Array()
var hit_ids: Array = []             # piercing drones cannot hit the same target again
var gmask := PackedInt64Array()     # mob gates that already affected this drone (once per gate)
var wid := PackedStringArray()

var robot_vx := 0.0
var prev_x := 0.0
var flame_timer := 0.0
var flame_fire_clock := 0.0
var torch_burn_s := 2.0
var cap_scale := 1.0
var gates: Array = []               # mob_gate beats in z order
var gate_cursor := 0
var first_multiply_t := -1.0
var track_realised := false         # measurement only: credit landed damage to the gates a drone passed
var impacts: Array = []             # [x, z, weight, kind] for the view; not events, never logged
var stats := {"launched": 0, "launched_damage": 0.0, "hit_damage": 0.0, "peak": 0, "live_sum": 0.0, "ticks": 0, "merges": 0, "cap_ticks": 0, "over_cap": 0, "passes": {}, "gain": 0.0, "trap_loss": 0.0}

func setup(config: Dictionary, start_x: float) -> void:
	cfg = config
	prev_x = start_x

func live_cap() -> int:
	return maxi(8, int(float(cfg.cap) * cap_scale))

func _hash(a: int, b: int) -> float:
	return fposmod(sin(float(a * 31 + b) * 12.9898) * 43758.5453, 1.0) - 0.5

func _grow() -> int:
	var i := n
	n += 1
	if px.size() < n:
		px.append(0.0)
		py.append(1.0)
		pz.append(0.0)
		vx.append(0.0)
		vz.append(0.0)
		dmg.append(0.0)
		wgt.append(0.0)
		life.append(0.0)
		chg.append(0.0)
		burn.append(0.0)
		rad.append(0.0)
		kind.append(0)
		pierce.append(0)
		lasthit.append(0)
		hit_ids.append([])
		gmask.append(0)
		wid.append("")
		cohort.append(0); unit_damage.append(1); material.append(1)
	return i

# Adds a drone, or folds it into a compatible heavier drone at the cap. Champions share the same cap.
func add_drone(k: int, x: float, z: float, svx: float, svz: float, damage: float, charge: float, life_s: float, weight := 1.0, weapon_id := "", burn_dps := 0.0, splash := 0.0, mask := 0, height := 1.0) -> int:
	enforce_cap()
	if hook_owner != null and hook_owner.enabled("material_tiers"):
		return hook_owner.accept_particle(self,k,x,z,svx,svz,damage,charge,life_s,weight,weapon_id,burn_dps,splash,mask,height)
	if n >= live_cap():
		var last := -1
		for candidate in range(n - 1, -1, -1):
			if kind[candidate] == k and gmask[candidate] == mask and wid[candidate] == weapon_id and (hook_owner == null or not hook_owner.enabled("gate_preview") or cohort[candidate] == active_cohort):
				last = candidate
				break
		# Free a slot rather than turning a bomb/champion into an unrelated bolt.
		if last < 0:
			_compact_one()
		else:
			stats.merges += 1
			dmg[last] += damage
			wgt[last] += weight
			chg[last] += charge
			life[last] = maxf(life[last], life_s)
			return last
	var i := _grow()
	px[i] = x
	py[i] = height
	pz[i] = z
	vx[i] = svx
	vz[i] = svz
	dmg[i] = damage
	wgt[i] = weight
	life[i] = life_s
	chg[i] = charge
	burn[i] = burn_dps
	rad[i] = splash
	kind[i] = k
	pierce[i] = int(cfg.kinds[KIND_NAMES[k]].pierce)
	lasthit[i] = 0
	hit_ids[i] = []
	gmask[i] = mask
	wid[i] = weapon_id
	cohort[i] = active_cohort; unit_damage[i] = active_unit_damage; material[i] = active_material
	return i

func _compact_one() -> void:
	if hook_owner != null and hook_owner.enabled("material_tiers"):
		hook_owner.compact(self); return
	if hook_owner != null and hook_owner.enabled("gate_preview"):
		hook_owner.compact_preview(self); return
	var a := 0
	var b := 1
	var best := INF
	var groups: Dictionary = {}
	for j in range(1, n):
		var previous := j - 1
		var key := "%d:%d:%s" % [kind[previous], gmask[previous], wid[previous]]
		if not groups.has(key):
			groups[key] = previous
		key = "%d:%d:%s" % [kind[j], gmask[j], wid[j]]
		var i := int(groups.get(key, 0))
		var score := absf(pz[i] - pz[j]) + absf(px[i] - px[j])
		if kind[i] != kind[j] or wid[i] != wid[j]:
			score += 10000.0
		if gmask[i] != gmask[j]:
			score += 1000.0
		if kind[i] == Kind.CHAMPION or kind[j] == Kind.CHAMPION:
			score += 100000.0
		if score < best:
			best = score
			a = i
			b = j
	dmg[a] += dmg[b]
	wgt[a] += wgt[b]
	chg[a] += chg[b]
	life[a] = maxf(life[a], life[b])
	burn[a] = maxf(burn[a], burn[b])
	rad[a] = maxf(rad[a], rad[b])
	gmask[a] |= gmask[b]
	for uid in hit_ids[b]:
		if not hit_ids[a].has(uid):
			hit_ids[a].append(uid)
	_swap_remove(b)
	stats.merges += 1

func enforce_cap() -> void:
	while n > live_cap():
		_compact_one()

func _swap_remove(i: int) -> void:
	var last := n - 1
	if i != last:
		px[i] = px[last]
		py[i] = py[last]
		pz[i] = pz[last]
		vx[i] = vx[last]
		vz[i] = vz[last]
		dmg[i] = dmg[last]
		wgt[i] = wgt[last]
		life[i] = life[last]
		chg[i] = chg[last]
		burn[i] = burn[last]
		rad[i] = rad[last]
		kind[i] = kind[last]
		pierce[i] = pierce[last]
		lasthit[i] = lasthit[last]
		hit_ids[i] = hit_ids[last]
		gmask[i] = gmask[last]
		wid[i] = wid[last]
		cohort[i] = cohort[last]; unit_damage[i] = unit_damage[last]; material[i] = material[last]
	n -= 1

# One barrel shot becomes a volley of drones. Level of the weapon part sets the volley size.
func muzzle(sim, weapon_id: String) -> Vector3:
	var slot := "blaster"
	for socket in sim.robot.slots:
		if sim.robot.slots[socket] == weapon_id:
			slot = str(socket)
			break
	var point: Array = cfg.launch.sockets.get(slot, cfg.launch.sockets.blaster)
	var stage_scale := float(cfg.launch.stage_scale[sim.robot.stage() - 1])
	return Vector3(sim.x + float(point[0]) * stage_scale, float(point[1]) * stage_scale, sim.z + float(point[2]) * stage_scale)

func launch_volley(sim, weapon: Dictionary, z_offset: float) -> void:
	var weapon_id := str(weapon.get("id", "blaster"))
	var level := int(sim.robot.parts.get(weapon_id, 1))
	var counts: Array = cfg.volley.get(weapon_id, [1, 1, 1])
	var count := int(counts[clampi(level - 1, 0, counts.size() - 1)])
	var k := KIND_NAMES.find(str(cfg.kind_of_weapon.get(str(weapon.type), "bolt")))
	var spec: Dictionary = cfg.kinds[KIND_NAMES[k]]
	var total := float(weapon.get("damage", 4)) * float(sim.robot.stats.dps_mult)
	if hook_owner != null:
		hook_owner.new_cohort(self, weapon_id, total / count)
		total *= hook_owner.multiplier(weapon_id)
	var per := total / count
	var charge_total: float = sim._bullet_charge(weapon)
	var speed := float(weapon.get("speed", 36))
	var target = _aim_target(sim)
	var launch: Dictionary = cfg.launch
	var origin := muzzle(sim, weapon_id)
	stats.launched_damage += total
	stats.launched += count
	for i in count:
		var s := float(i) - (count - 1) / 2.0
		var svx: float
		var svz: float
		if target != null:
			var dir := Vector2(float(target.x) - origin.x, float(target.z) - origin.z).normalized().rotated(s * float(launch.aim_spread_rad))
			svx = dir.x * speed + robot_vx * float(cfg.lateral_inherit)
			svz = dir.y * speed
		else:
			svx = s * float(launch.straight_spread_mps) + robot_vx * float(cfg.lateral_inherit) + _hash(sim.shot_count, i) * float(launch.jitter_mps)
			svz = speed
		add_drone(k, origin.x + s * float(launch.muzzle_spread_m), origin.z + z_offset + float(i) * 0.04, svx, svz, per, charge_total / count, float(spec.life_s), 1.0, str(weapon.id), 0.0, float(weapon.get("area_radius", 0)), 0, origin.y)

# Aim assist yields to mob gates: a target that sits behind an upcoming gate is not homed on, so the gate panel the player
# lines up decides where the stream goes; the multiplied stream then reaches whatever is beyond if the player is aligned.
func _aim_target(sim):
	var target = sim._pick_target()
	if target == null:
		return null
	for gate in gates:
		var gz := float(gate.z)
		if gz > sim.z + 1.0 and gz < float(target.z):
			return null
		if gz > float(target.z):
			break
	return target

# Overdrive champion: one big drone down the lane. It smashes through a column of enemies (splash on contact), is boosted by
# mob gates and cannot be destroyed by traps. Existing drones compact to leave room under the global cap.
func launch_champion(sim, overcharged: bool) -> void:
	var spec: Dictionary = cfg.champion
	var kind_spec: Dictionary = cfg.kinds.champion
	var damage := float(spec.damage) * float(sim.robot.stats.dps_mult) * (1.5 if overcharged else 1.0)
	if hook_owner != null:
		hook_owner.new_cohort(self,"champion",damage); damage *= hook_owner.multiplier(hook_owner.primary(sim))
	add_drone(Kind.CHAMPION, sim.x, sim.z + 1.4, robot_vx * float(cfg.lateral_inherit), float(spec.speed), damage, 0.0, float(kind_spec.life_s), 1.0, "champion", 0.0, float(spec.splash))
	stats["champions"] = int(stats.get("champions", 0)) + 1
	sim.emit("mob_champion", {"damage": snappedf(damage, 0.1)})

# Flame cone becomes a burst of short-lived torch drones. Per-second damage equals the old cone dps.
func flame(sim, weapon: Dictionary, dt: float) -> bool:
	flame_timer -= dt
	var launched := false
	var rate := float(cfg.torch.rate_per_s)
	if flame_timer <= 0:
		flame_timer += 1.0 / rate
		launched = true
		var level := int(sim.robot.parts.get("flame", 1))
		var counts: Array = cfg.volley.flame
		var count := int(counts[clampi(level - 1, 0, counts.size() - 1)])
		var total := float(weapon.damage) / rate * float(sim.robot.stats.dps_mult)
		if hook_owner != null:
			hook_owner.new_cohort(self,"flame",total / count); total *= hook_owner.multiplier("flame")
		var speed := float(cfg.torch.speed)
		var life_s := (float(cfg.torch.boss_reach_m) / speed) if sim.state == "boss" else float(weapon.range) / speed
		torch_burn_s = float(weapon.get("burn_s", 2.0))
		stats.launched_damage += total
		stats.launched += count
		var origin := muzzle(sim, "flame")
		for i in count:
			var s := (float(i) - (count - 1) / 2.0) / maxf(1.0, (count - 1) / 2.0)
			add_drone(Kind.TORCH, origin.x + s * 0.3, origin.z, s * float(cfg.torch.fan_mps) + robot_vx * float(cfg.lateral_inherit), speed, total / count, 0.0, life_s, 1.0, "flame", float(weapon.get("burn_dps", 0)) * float(sim.robot.stats.dps_mult), 0.0, 0, origin.y)
	return launched

func _record_impact(x: float, z: float, weight: float, k: int) -> void:
	impacts.append([x, z, weight, k])
	if impacts.size() > int(cfg.impact_buffer):
		impacts.pop_front()

# Advance every drone, resolve hits on enemies, crates, barrels and the boss, and charge part gates.
func step(sim, dt: float) -> void:
	enforce_cap()
	robot_vx = (sim.x - prev_x) / maxf(dt, 0.0001)
	prev_x = sim.x
	var targets: Array = []
	var tx := PackedFloat64Array()
	var tz := PackedFloat64Array()
	for enemy in sim.enemies:
		if float(enemy.hp) > 0:
			targets.append(enemy)
			tx.append(float(enemy.x))
			tz.append(float(enemy.z))
	var gate: Dictionary = sim.next_gate() if sim.flags.gate_charge else {}
	var gate_z := float(gate.z) if gate.has("charge") else -1.0
	while gate_cursor < gates.size() and float(gates[gate_cursor].z) < sim.z - 1.0:
		gate_cursor += 1
	var active: Array = []
	var gi := gate_cursor
	while gi < gates.size() and float(gates[gi].z) <= sim.z + 90.0:
		active.append(gates[gi])
		gi += 1
	var gate_tuning: Dictionary = sim.flags.tuning
	var boss_plane: float = sim.z + 14.0
	var in_boss: bool = sim.state == "boss"
	var kinds: Dictionary = cfg.kinds
	var i := n - 1
	while i >= 0:
		var prev_z := pz[i]
		px[i] += vx[i] * dt
		pz[i] += vz[i] * dt
		life[i] -= dt
		var k := kind[i]
		var dead := life[i] <= 0.0
		if not dead and gate_z >= 0.0 and k != Kind.TORCH and prev_z < gate_z and pz[i] >= gate_z:
			sim._charge_gate({"x": px[i], "z": pz[i], "charge": chg[i]}, prev_z)
		if not dead:
			for g in active:
				var gz := float(g.z)
				var bit := 1 << int(g.ord)
				if prev_z < gz and pz[i] >= gz and (gmask[i] & bit) == 0:
					gmask[i] |= bit
					var lane := panel_lane(g, px[i], sim.t, gate_tuning)
					g.crossed += 1
					if lane < 0:
						g.missed += 1
					else:
						g.state[lane].total = int(g.state[lane].get("total", 0)) + 1
					if lane >= 0 and _apply_panel(sim, i, g, lane):
						dead = true
						break
		if not dead:
			var r := float(kinds[KIND_NAMES[k]].hit_radius)
			for j in targets.size():
				if absf(tz[j] - pz[i]) >= r or absf(tx[j] - px[i]) >= r:
					continue
				var enemy: Dictionary = targets[j]
				var uid := int(enemy.uid)
				if hit_ids[i].has(uid) or float(enemy.hp) <= 0:
					continue
				if Vector2(tx[j] - px[i], tz[j] - pz[i]).length() >= r:
					continue
				_hit_enemy(sim, i, enemy, targets)
				lasthit[i] = uid
				hit_ids[i].append(uid)
				if pierce[i] <= 0:
					dead = true
					break
				pierce[i] -= 1
		if not dead and in_boss and pz[i] >= boss_plane:
			var boss_damage := dmg[i] * (1.5 if sim.exposed_time > 0 else 1.0)
			var before_hp: float = sim.boss.hp + sim.boss.arm_hp
			sim.boss.apply_hit(KIND_TYPE[k], boss_damage, sim, "arm" if sim.boss.arm_hp > 0 else "core")
			if k == Kind.TORCH:
				sim.boss.burn_left = torch_burn_s
				sim.boss.burn_dps = burn[i]
			var landed := maxf(0.0, before_hp - float(sim.boss.hp) - float(sim.boss.arm_hp))
			stats.hit_damage += landed
			if track_realised:
				_attribute(i, landed)
			_record_impact(px[i], boss_plane, wgt[i], k)
			if landed > 0:
				sim.last_boss_hit = sim.t
			dead = true
		if dead:
			_swap_remove(i)
		i -= 1
	_flush_passes(sim)
	stats.peak = maxi(int(stats.peak), n)
	stats.live_sum += n
	stats.ticks += 1
	if n >= live_cap():
		stats.cap_ticks += 1

func _attribute(i: int, damage: float) -> void:
	for g in gates:
		if (gmask[i] & (1 << int(g.ord))) != 0:
			g["realised"] = float(g.get("realised", 0.0)) + damage

func _hit_enemy(sim, i: int, enemy: Dictionary, targets: Array) -> void:
	var damage := dmg[i]
	var landed := minf(damage, maxf(0.0, float(enemy.hp)))
	if track_realised:
		_attribute(i, landed)
	enemy.hp -= damage
	stats.hit_damage += landed
	_record_impact(px[i], pz[i], wgt[i], kind[i])
	if sim.engage != null:
		sim.engage.on_hit(sim, {"wid": wid[i], "damage": damage}, enemy)
	if kind[i] == Kind.TORCH:
		enemy.burn_left = torch_burn_s
		enemy.burn_dps = burn[i]
	if kind[i] == Kind.BOMB or kind[i] == Kind.CHAMPION:
		if kind[i] == Kind.BOMB and sim.flags.weapon_evolution and sim.evolution_active():
			sim._split_rocket({"damage": damage}, enemy)
		if rad[i] > 0:
			for other in targets:
				if other != enemy and Vector2(float(other.x) - float(enemy.x), float(other.z) - float(enemy.z)).length() < rad[i]:
					landed = minf(damage, maxf(0.0, float(other.hp)))
					stats.hit_damage += landed
					if track_realised:
						_attribute(i, landed)
					other.hp -= damage

func is_alive(i: int) -> bool:
	return i >= 0 and i < n

func _clone(i: int) -> int:
	var j := _grow()
	px[j] = px[i]
	py[j] = py[i]
	pz[j] = pz[i]
	vx[j] = vx[i]
	vz[j] = vz[i]
	dmg[j] = dmg[i]
	wgt[j] = wgt[i]
	life[j] = life[i]
	chg[j] = chg[i]
	burn[j] = burn[i]
	rad[j] = rad[i]
	kind[j] = kind[i]
	pierce[j] = pierce[i]
	lasthit[j] = lasthit[i]
	hit_ids[j] = hit_ids[i].duplicate()
	gmask[j] = gmask[i]
	wid[j] = wid[i]
	cohort[j] = cohort[i]; unit_damage[j] = unit_damage[i]; material[j] = material[i]
	return j

# Register the authored mob gates (beats of type mob_gate). Each gate and panel keeps its own pass counters.
func register_gates(beats: Array) -> void:
	gates.clear()
	gate_cursor = 0
	var ordinal := 0
	for beat in beats:
		if str(beat.type) == "mob_gate":
			beat["ord"] = ordinal
			ordinal += 1
			beat["crossed"] = 0
			beat["missed"] = 0
			beat["state"] = []
			for panel in beat.panels:
				beat.state.append({"acc": 0.0, "count": 0, "gain": 0.0, "next": 0.0, "sx": 0.0})
			gates.append(beat)
	assert(ordinal < 62, "gate mask holds 62 mob gates")

# Slide of a moving mob gate: same pure function of time as the part gates, so it is telegraphed and deterministic.
func gate_offset(gate: Dictionary, at_t: float, tuning: Dictionary) -> float:
	if not gate.get("moving", false):
		return 0.0
	return float(tuning.moving_amplitude) * sin(TAU * at_t / float(tuning.moving_period) + float(gate.z) * 0.37)

func panel_center(gate: Dictionary, lane: int, at_t: float, tuning: Dictionary) -> float:
	var count: int = gate.panels.size()
	if gate.get("moving", false):
		return (float(lane) - (count - 1) / 2.0) * float(tuning.moving_spacing) + gate_offset(gate, at_t, tuning)
	var half := float(GameData.constants().road_half_width)
	return -half + 2.0 * half / count * (lane + 0.5)

# Panel a drone at x passes through, or -1 when it flies through a gap beside the panels.
func panel_lane(gate: Dictionary, at_x: float, at_t: float, tuning: Dictionary) -> int:
	var count: int = gate.panels.size()
	if gate.get("moving", false):
		var best := -1
		var best_distance := float(tuning.moving_half)
		for lane in count:
			var distance := absf(at_x - panel_center(gate, lane, at_t, tuning))
			if distance < best_distance:
				best_distance = distance
				best = lane
		return best
	var half := float(GameData.constants().road_half_width)
	if absf(at_x) >= half:
		return -1
	return clampi(int(floor((at_x + half) / (2.0 * half) * count)), 0, count - 1)

# Gate that creates `extra` more full-damage drones from drone i. Room under the cap decides how many become real
# drones; the rest of the damage is folded into the group as heavier drones, so no damage is lost to the cap.
func _multiply(i: int, extra: int, jitter_seed: int) -> void:
	if hook_owner != null and hook_owner.enabled("material_tiers"):
		hook_owner.multiply_single(self,i,extra,jitter_seed); return
	var room := maxi(0, live_cap() - n)
	var made := mini(extra, room)
	var group := 1 + made
	if made < extra:
		stats.merges += 1
	var factor := float(1 + extra) / group
	dmg[i] *= factor
	wgt[i] *= factor
	chg[i] /= group
	for c in made:
		var j := _clone(i)
		var side := 1.0 if c % 2 == 0 else -1.0
		px[j] += side * (1 + c / 2) * minf(float(cfg.gates.copy_spread_m), float(cfg.gates.copy_span_m) / maxf(1.0, float(extra)))
		vx[j] += _hash(jitter_seed, c) * float(cfg.gates.copy_jitter_mps)

# Applies one panel to drone i. Returns true when the drone is destroyed (trap).
func _apply_panel(sim, i: int, gate: Dictionary, lane: int) -> bool:
	if hook_owner != null and hook_owner.enabled("gate_preview"):
		return hook_owner.apply_gate(sim,self,i,gate,lane)
	var panel: Dictionary = gate.panels[lane]
	var state: Dictionary = gate.state[lane]
	var value := float(panel.v)
	var before := dmg[i]
	var removed := false
	state.count += 1
	state.sx += px[i]
	if kind[i] == Kind.CHAMPION:
		_boost_champion(i, panel, state, before)
		return false
	match str(panel.t):
		"mult":
			_multiply(i, int(value) - 1, sim.shot_count + i)
			state.gain += before * (value - 1.0)
		"add":
			state.acc += 1.0
			if state.acc >= float(cfg.gates.add_per):
				state.acc -= float(cfg.gates.add_per)
				_multiply(i, int(value), sim.shot_count + i)
				state.gain += before * value
		"power":
			dmg[i] *= 1.0 + value / 100.0
			wgt[i] *= 1.0 + value / 100.0
			state.gain += before * value / 100.0
		"speed":
			vx[i] *= 1.0 + value / 100.0
			vz[i] *= 1.0 + value / 100.0
		"trap":
			state.acc += value / 100.0
			if state.acc >= 1.0:
				state.acc -= 1.0
				state.gain -= before
				stats.trap_loss += before
				removed = true
	if hook_owner != null and hook_owner.enabled("material_tiers") and not removed: hook_owner.bound_particle(self,i)
	return removed

# A champion is boosted by good gates and only dented by traps; it never splits or dies at a gate.
func _boost_champion(i: int, panel: Dictionary, state: Dictionary, before: float) -> void:
	var value := float(panel.v)
	var spec: Dictionary = cfg.champion
	match str(panel.t):
		"mult":
			dmg[i] *= value
			wgt[i] *= value
		"add":
			dmg[i] *= 1.0 + value * float(spec.gate_add_scale)
			wgt[i] *= 1.0 + value * float(spec.gate_add_scale)
		"power":
			dmg[i] *= 1.0 + value / 100.0
			wgt[i] *= 1.0 + value / 100.0
		"speed":
			vz[i] *= 1.0 + value / 100.0
		"trap":
			dmg[i] *= 1.0 - value * float(spec.gate_trap_scale)
	state.gain += dmg[i] - before

# Emits at most one mob_gate_pass per panel per pop_interval so the log and the pop-ups stay readable.
func _flush_passes(sim) -> void:
	for gate in gates:
		var gz := float(gate.z)
		if gz < sim.z - 12.0:
			continue
		if gz > sim.z + 80.0:
			break
		for lane in gate.panels.size():
			var state: Dictionary = gate.state[lane]
			if state.count > 0 and sim.t >= float(state.next):
				var panel: Dictionary = gate.panels[lane]
				var typ := str(panel.t)
				stats.passes[typ] = int(stats.passes.get(typ, 0)) + int(state.count)
				stats.gain += float(state.gain)
				if sim.state == "running" and float(state.gain) > 0.0:
					sim.robot.overdrive = minf(100.0, sim.robot.overdrive + float(state.gain) * float(cfg.champion.overdrive_per_gain))
				if first_multiply_t < 0.0 and float(state.gain) > 0.0 and typ in ["mult", "add"]:
					first_multiply_t = sim.t
				sim.emit("mob_gate_pass", {"ord": gate.ord, "lane": lane, "type": typ, "v": panel.v, "count": state.count, "gain": snappedf(state.gain, 0.01), "x": snappedf(float(state.sx) / state.count, 0.01), "z": gz})
				state.count = 0
				state.gain = 0.0
				state.sx = 0.0
				state.next = sim.t + float(cfg.gates.pop_interval_s)
