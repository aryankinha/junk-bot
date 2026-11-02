extends RefCounted
# Hook experiments: pure sim state. No nodes, save data, clocks or renderer inputs.
var host: WeakRef
var cfg: Dictionary = {}
var tiers: Dictionary = {}
var family_tiers := {"cannon": 1, "rocket": 1, "flame": 1, "blaster": 1}
var family_units := {"cannon": 0.0, "rocket": 0.0, "flame": 0.0, "blaster": 0.0}
var pending := {"cannon": 0.0, "rocket": 0.0, "flame": 0.0, "blaster": 0.0}
var tier_times: Dictionary = {}
var pause_until := 0.0
var kill_streak := 0
var last_kill := -10.0
var converted_damage := 0.0
var converted_units := 0.0
var ledger := {"requested": 0.0, "retained": 0.0, "converted": 0.0, "operations": 0}
var cohort_serial := 0
var chain_totals: Dictionary = {}
var wave_serial := 0
var waves: Dictionary = {}
var wave_results: Array = []
var wave_spawned := 0
var wave_truncated := 0
var next_flow_z := 55.0
var recent_kills: Array = []
var reveal_seen: Dictionary = {}
var mystery_seen := false
var paused_credit := 0.0

func setup(sim) -> void:
	host = weakref(sim)
	cfg = GameData.table("mob").get("hook", {}).duplicate(true)
	tiers = GameData.tables.get("tiers", {})
	if tiers.is_empty(): tiers = JSON.parse_string(FileAccess.get_file_as_string("res://data/tiers.json"))

func enabled(flag: String) -> bool:
	var sim = host.get_ref()
	return sim != null and bool(sim.flags.get(flag, false))

func quality(family: String) -> int:
	return int(family_tiers.get(family, 1))

func progress(family: String) -> float:
	var q := quality(family)
	var limits: Array = tiers.get("thresholds", [30.0, 80.0, 160.0])
	var lo := float(limits[q - 2]) if q > 1 else 0.0
	var hi := float(limits[q - 1]) if q < 4 else float(limits[2]) + float(tiers.get("ascend_units", 160.0))
	return clampf((float(family_units.get(family, 0)) - lo) / maxf(1, hi - lo), 0, 1)

func ascensionbonus(family: String) -> float:
	if not enabled("material_tiers") or quality(family) < 4: return 0.0
	var last: float = tiers.get("thresholds", [30,80,160])[2]
	return minf(float(tiers.get("ascend_bonus_cap", 0.15)), maxf(0, float(family_units.get(family, 0)) - last) * float(tiers.get("ascend_bonus_per_unit", 0.0005)))

func multiplier(family: String) -> float:
	if not enabled("material_tiers"): return 1.0
	return float(tiers.get("damage", [1.0,1.25,1.6,2.1])[quality(family) - 1]) * (1.0 + ascensionbonus(family))

func primary(sim) -> String:
	var best := "blaster"
	var power := -1.0
	for weapon in sim.robot.stats.weapons:
		var id := str(weapon.id)
		var rate := float(weapon.get("rate", 1)) * int(weapon.get("barrels", 1))
		var estimate := float(weapon.get("damage", 0)) * (1.0 if weapon.type == "cone" else rate) * multiplier(id)
		if estimate > power: best = id; power = estimate
	return best

func new_cohort(mob, family: String, nominal_damage: float) -> void:
	cohort_serial += 1
	mob.active_cohort = cohort_serial
	mob.active_material = quality(family)
	mob.active_unit_damage = maxf(0.000001, nominal_damage * multiplier(family))

static func resolve(input: float, panel: Dictionary) -> float:
	var v := float(panel.v)
	match str(panel.t):
		"mult": return input * v
		"add": return input + v
		"power": return input * (1.0 + v / 100)
		"trap": return input * maxf(0, 1.0 - v / 100)
	return input

func preview(sim, gate: Dictionary, panel) -> Dictionary:
	var p: Dictionary = gate.panels[int(panel)] if panel is int else panel
	var family := primary(sim)
	var cid := -1
	var lead := -INF
	var input := 0.0
	var members := 0
	var bit := 1 << int(gate.get("ord", 0))
	if sim.mob != null:
		var mob = sim.mob
		for i in mob.n:
			if mob.life[i] > 0 and mob.pz[i] < float(gate.z) and (mob.gmask[i] & bit) == 0 and mob.pz[i] > lead:
				lead = mob.pz[i]; cid = mob.cohort[i]; family = mob.wid[i]
		if cid >= 0:
			for i in mob.n:
				if mob.cohort[i] == cid:
					input += mob.wgt[i]; members += 1
	if cid < 0:
		var level := int(sim.robot.parts.get(family, 1))
		input = float(GameData.table("mob").volley.get(family, [3,3,3])[clampi(level - 1, 0, 2)])
		members = int(input)
	var requested := resolve(input, p)
	var locked: bool = float(gate.get("min_time", 0)) > sim.t
	if locked: requested = input
	var output := requested
	if enabled("material_tiers") and sim.mob != null:
		var slots := maxi(members, mini(int(ceil(requested)), sim.mob.live_cap() - sim.mob.n + members))
		output = minf(requested, slots * float(tiers.get("max_weight", 5.0)))
	return {"input":input,"output":output,"requested":requested,"converted":maxf(0,requested-output),"family":family,"cohort":cid,"estimated":cid<0,"locked":locked,"cap":sim.mob.live_cap() if sim.mob!=null else 200}

func credit(family: String, units: float, damage: float, reason: String) -> void:
	if not enabled("material_tiers") or units <= 0: return
	if not family_units.has(family): family = primary(host.get_ref())
	converted_damage += maxf(0, damage); converted_units += units
	pending[family] = float(pending.get(family, 0)) + units
	_apply_credit(host.get_ref(), family, reason)

func _apply_credit(sim, family: String, reason: String) -> void:
	if sim.t < pause_until: return
	var amount := float(pending.get(family, 0))
	if amount <= 0: return
	pending[family] = 0.0
	family_units[family] = float(family_units.get(family, 0)) + amount
	var thresholds: Array = tiers.get("thresholds", [30.0,80.0,160.0])
	var target := 1
	for limit in thresholds: target += int(float(family_units[family]) >= float(limit))
	while quality(family) < target:
		family_tiers[family] = quality(family) + 1
		var q := quality(family)
		if not tier_times.has(family): tier_times[family] = {}
		tier_times[family][str(q)] = sim.t
		sim.emit("tier_up", {"family":family,"tier":q,"reason":reason,"duration":0.55})

func account(requested: float, retained: float, converted: float) -> void:
	ledger.requested += requested; ledger.retained += retained; ledger.converted += converted; ledger.operations += 1
	assert(absf(requested - retained - converted) < maxf(0.0001, absf(requested) * 0.000001), "Hook direct payload accounted exactly once")

func apply_gate(sim, mob, i: int, gate: Dictionary, lane: int) -> bool:
	if float(gate.get("min_time", 0)) > sim.t: return false
	var cid: int = mob.cohort[i]
	if not gate.has("hook_done"): gate.hook_done = {}
	if gate.hook_done.has(cid): return false
	gate.hook_done[cid] = true
	var indices: Array[int] = []
	var input := 0.0
	var payload := 0.0
	var charge := 0.0
	var family: String = mob.wid[i]
	var unit: float = mob.unit_damage[i]
	var bit := 1 << int(gate.ord)
	for j in mob.n:
		if mob.cohort[j] == cid:
			indices.append(j); input += mob.wgt[j]; payload += mob.dmg[j]; charge += mob.chg[j]; mob.gmask[j] |= bit
	unit = payload / maxf(0.000001,input)
	var panel: Dictionary = gate.panels[lane]
	var requested := resolve(input, panel)
	var desired := maxi(indices.size(), mini(int(ceil(requested)), mob.live_cap() - mob.n + indices.size()))
	var source: int = indices[0]
	while indices.size() < desired:
		var j: int = mob._clone(source)
		mob.px[j] += float((indices.size() % 5) - 2) * 0.12
		indices.append(j)
	var retained := requested
	if enabled("material_tiers"): retained = minf(requested, indices.size() * float(tiers.get("max_weight", 5.0)))
	var weight := retained / maxf(1, indices.size())
	for j in indices:
		mob.wgt[j] = weight; mob.dmg[j] = unit * weight; mob.chg[j] = charge / indices.size()
		if retained <= 0: mob.life[j] = 0
		if panel.t == "speed": mob.vx[j] *= 1.0 + float(panel.v) / 100; mob.vz[j] *= 1.0 + float(panel.v) / 100
	var residual := maxf(0, requested - retained)
	if residual > 0: credit(family, residual, residual * unit, "overflow")
	account(requested * unit, retained * unit, residual * unit)
	var gain := (retained - input) * unit
	mob.stats.gain += gain
	mob.stats.passes[str(panel.t)] = int(mob.stats.passes.get(str(panel.t),0)) + 1
	if panel.t == "trap": mob.stats.trap_loss += maxf(0, (input - retained) * unit)
	if mob.first_multiply_t < 0 and retained > input: mob.first_multiply_t = sim.t
	var step := int(gate.get("chain_step", 1))
	sim.emit("hook_gate_pass", {"input":input,"output":retained,"requested":requested,"converted":residual,"family":family,"ord":gate.ord,"lane":lane,"type":panel.t,"v":panel.v,"chain_step":step,"chain_id":int(gate.get("chain_id",-1)),"x":mob.px[i],"z":gate.z})
	# Existing engagement and Overdrive mechanisms receive the same event family, without legacy receipts.
	sim.robot.overdrive = minf(100, sim.robot.overdrive + maxf(0, gain) * float(mob.cfg.champion.overdrive_per_gain))
	if sim.engage != null: sim.engage.on_event(sim,"mob_gate_pass",{"count":indices.size(),"gain":gain,"type":panel.t})
	if step == int(gate.get("chain_length", 1)) and step > 1:
		sim.emit("hook_chain", {"total":retained,"input":input,"family":family,"chain_id":int(gate.chain_id),"cohort":cid})
	return retained <= 0

func author(sim) -> void:
	if sim.mob == null: return
	if not (enabled("gate_preview") or enabled("gate_clarity")): return
	var part_z: Array = []
	for b in sim.beats:
		if b.has("options") or b.type in ["gate","repair_bay","final_choice"]: part_z.append(float(b.z))
	part_z.sort()
	if not enabled("gate_preview"):
		for b in sim.beats:
			if b.type != "mob_gate": continue
			var best := float(b.z)
			for pz in part_z:
				if absf(best - pz) < 25: best = pz - 25 if best < pz else pz + 25
			b.z = best
		sim.beats.sort_custom(func(a,b):return a.z<b.z)
		return
	sim.beats = sim.beats.filter(func(b):return b.type != "mob_gate")
	var previous := -25.0
	var serial := 0
	var maximum := mini(4, 2 + sim.level)
	for edge in part_z + [sim.boss_z + 25]:
		var lo := maxf(30, previous + 25)
		var hi := minf(float(edge) - 25, sim.boss_z - 25)
		var count := mini(maximum, int(floor((hi - lo) / 16.0)) + 1)
		if count > 0:
			var start := (lo + hi - 16 * (count - 1)) / 2
			for step in count:
				var z := start + step * 16
				var panels := [{"t":"mult","v":2},{"t":"add","v":10}]
				if serial % 3 == 1 and step == count - 1: panels = [{"t":"mult","v":3},{"t":"add","v":12}]
				sim.beats.append({"type":"mob_gate","z":z,"panels":panels,"moving":false,"chain_id":serial,"chain_step":step+1,"chain_length":count,"hook":true})
			serial += 1
		previous = float(edge)
	sim.beats.sort_custom(func(a,b):return a.z<b.z)

func on_event(sim, event: String, data: Dictionary) -> void:
	if event == "player_hit":
		kill_streak = 0; pause_until = sim.t + float(tiers.get("damage_pause_s", 1.2))
	elif event == "enemy_death" and enabled("material_tiers"):
		kill_streak = kill_streak + 1 if sim.t - last_kill <= 4 else 1; last_kill = sim.t
		var family := primary(sim)
		var bonus := float(tiers.get("kill_bonus", 1.0)) * (1 + minf(1, kill_streak / 10.0))
		pending[family] = float(pending.get(family,0)) + bonus
		_apply_credit(sim,family,"kill_chain")

func tick(sim, _dt: float) -> void:
	if enabled("material_tiers"):
		for family in pending: _apply_credit(sim, family, "overflow")

# Cap compaction fuses same-family volleys; STREAM POWER names that compacted cohort,
# not the number of render entities. Direct damage and charge remain additive.
func compact_preview(mob) -> void:
	var groups: Dictionary = {}; var a := -1; var b := -1
	for j in mob.n:
		var key := "%d:%s:%d" % [mob.kind[j],mob.wid[j],mob.gmask[j]]
		if groups.has(key):a=int(groups[key]);b=j;break
		groups[key]=j
	if b<0:
		var saved=mob.hook_owner;mob.hook_owner=null;mob._compact_one();mob.hook_owner=saved;return
	var old: int=mob.cohort[b];var merged: int=mob.cohort[a]
	for j in mob.n:
		if mob.cohort[j]==old:mob.cohort[j]=merged
	mob.dmg[a]+=mob.dmg[b];mob.wgt[a]+=mob.wgt[b];mob.chg[a]+=mob.chg[b]
	mob.unit_damage[a]=mob.dmg[a]/maxf(0.000001,mob.wgt[a])
	mob.life[a]=maxf(mob.life[a],mob.life[b]);mob.burn[a]=maxf(mob.burn[a],mob.burn[b]);mob.rad[a]=maxf(mob.rad[a],mob.rad[b])
	for uid in mob.hit_ids[b]:
		if not mob.hit_ids[a].has(uid):mob.hit_ids[a].append(uid)
	mob._swap_remove(b);mob.stats.merges+=1
