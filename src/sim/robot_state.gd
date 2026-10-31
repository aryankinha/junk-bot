class_name RobotState extends RefCounted
var parts: Dictionary = {}
var slots: Dictionary = {}
var broken: Array = []
var tiers: Dictionary = {}
var tradeoffs: Array = []
var hp := 60.0
var max_hp := 60.0
var scrap := 0
var collected := 0
var overdrive := 0.0
var invuln := 0.0
var shield_timer := 0.0
var shield_charges := 0
var crossed: Array = []
var cooldowns: Dictionary = {}
var stats: Dictionary = {}
var parts_lost := 0

func _init() -> void:
	refresh()

func build_points() -> int:
	var points := 0
	for value in parts.values():
		points += int(value)
	return points

func stage() -> int:
	var thresholds: Dictionary = GameData.constants().stage_thresholds
	return 3 if build_points() >= int(thresholds.monster) else (2 if build_points() >= int(thresholds.battle) else 1)

func combos() -> Array:
	var found: Array = []
	for id in GameData.table("combos"):
		var combo: Dictionary = GameData.table("combos")[id]
		if combo.get("stretch", false):
			continue
		if parts.has(combo.needs[0]) and parts.has(combo.needs[1]):
			found.append(id)
	return found

func refresh(heal_growth := false) -> void:
	var previous := max_hp
	stats = StatCalc.compute(self)
	max_hp = stats.max_hp
	if heal_growth:
		hp += maxf(0, max_hp - previous)
	hp = minf(hp, max_hp)
	shield_charges = mini(shield_charges, int(stats.shield_charges))

func remove_part(id: String) -> void:
	parts.erase(id)
	for slot in slots.keys():
		if slots[slot] == id:
			slots.erase(slot)

func add_part(id: String, sim = null, grant_level := 1) -> Dictionary:
	assert(GameData.table("parts").has(id))
	var definition: Dictionary = GameData.table("parts")[id]
	var old_stage := stage()
	var old_combos := combos()
	var level: int = mini(3, int(parts.get(id, 0)) + grant_level)
	var replaced: Array = []
	for other in definition.get("replaces", []):
		if parts.has(other):
			level = maxi(level, int(parts[other]))
			replaced.append(other)
			remove_part(other)
	var chosen := ""
	for slot in slots:
		if slots[slot] == id:
			chosen = slot
			break
	if chosen.is_empty():
		chosen = _claim_slot(id, [])
	if chosen.is_empty():
		var candidate := ""
		for other in parts:
			if GameData.table("parts")[other].category == definition.category and (candidate.is_empty() or int(parts[other]) < int(parts[candidate])):
				candidate = other
		if candidate.is_empty():
			# Occupied sockets from another category: pop the occupant of the preferred socket.
			candidate = str(slots[definition.slots[0]])
		replaced.append(candidate)
		remove_part(candidate)
		for slot in definition.slots:
			if not slots.has(slot):
				chosen = slot
				break
	var result := "upgraded" if parts.has(id) else "attached"
	parts[id] = level
	slots[chosen] = id
	refresh(true)
	if definition.category == "defence" and id == "shield":
		shield_charges = int(stats.shield_charges)
	if sim != null:
		for other in replaced:
			sim.emit("part_replaced", {"id": other})
		sim.emit("part_" + result, {"id": id, "level": level, "slot": chosen})
		if stage() > old_stage:
			sim.emit("stage_up", {"stage": stage()})
		for combo in combos():
			if not old_combos.has(combo):
				sim.emit("combo_active", {"id": combo})
	return {"result": result, "level": level, "slot": chosen, "replaced": replaced}

func _claim_slot(id: String, visited: Array) -> String:
	# Relocate existing attachments through compatible free sockets before replacing one.
	var definition: Dictionary = GameData.table("parts")[id]
	for slot in definition.slots:
		if not slots.has(slot):
			return slot
	var seen := visited.duplicate()
	seen.append(id)
	for slot in definition.slots:
		var occupant: String = slots[slot]
		if seen.has(occupant):
			continue
		var alternate := _claim_slot(occupant, seen)
		if not alternate.is_empty():
			slots.erase(slot)
			slots[alternate] = occupant
			return slot
	return ""

func break_part(sim, stolen := false) -> Dictionary:
	var candidates: Array = []
	var weapons := 0
	for id in parts:
		if GameData.table("parts")[id].category == "weapon":
			weapons += 1
	for id in parts:
		if weapons <= 1 and GameData.table("parts")[id].category == "weapon":
			continue
		for i in int(parts[id]):
			candidates.append(id)
	if candidates.is_empty():
		return {}
	var id: String = candidates[sim.rng.loot.randi_range(0, candidates.size() - 1)]
	if stolen:
		for other in candidates:
			if int(parts[other]) > int(parts[id]):
				id = other
	var item := {"id": id, "level": int(parts[id])}
	broken.append(item)
	remove_part(id)
	parts_lost += 1
	refresh()
	sim.emit("part_stolen" if stolen else "part_broken", item)
	return item

func take_damage(amount: float, sim, cause := "impact") -> void:
	if invuln > 0 or sim.state in ["won", "lost"]:
		return
	if shield_charges > 0:
		shield_charges -= 1
		invuln = float(GameData.constants().hit_invuln_s)
		sim.emit("shield_block")
		return
	hp = maxf(0, hp - amount * (1.0 - float(stats.armor)))
	invuln = float(GameData.constants().hit_invuln_s)
	sim.emit("player_hit", {"amount": amount, "cause": cause})
	var fraction := hp / max_hp
	for threshold in GameData.constants().part_break_thresholds:
		if fraction < float(threshold) and not crossed.has(threshold):
			crossed.append(threshold)
			break_part(sim)
	if hp <= 0:
		sim.state = "lost"
		sim.death_cause = cause
		sim.emit("death", {"cause": cause})

func repair(sim) -> void:
	var restore := broken.duplicate(true)
	broken.clear()
	for item in restore:
		add_part(item.id, sim, int(item.level))
	hp = minf(max_hp, hp + max_hp * float(GameData.table("economy").repair_bay.repair_heal_pct))
	sim.emit("repaired")

func tick(dt: float) -> void:
	invuln = maxf(0, invuln - dt)
	for id in cooldowns:
		cooldowns[id] = maxf(0, float(cooldowns[id]) - dt)
	if shield_charges < int(stats.shield_charges):
		shield_timer += dt
		if shield_timer >= float(stats.shield_recharge_s):
			shield_timer = 0
			shield_charges += 1
