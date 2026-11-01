class_name BossSim extends RefCounted
var hp := 1500.0
var max_hp := 1500.0
var phase := 1
var elapsed := 0.0
var timer := 2.0
var roar := 1.5
var attack := ""
var zones: Array = []
var attacks_made := 0
var arm_hp := 0.0
var arm_timer := 0.0
var stolen: Dictionary = {}
var repeat_left := 0
var attack_hit := false
var sweep_active := false
var sweep_origin := 0.0
var sweep_direction := 1.0
var burn_left := 0.0
var burn_dps := 0.0
var config: Dictionary
var telegraph_duration := 1.0

func setup(level: int, losses: int) -> void:
	config = GameData.table("boss_scrap_titan")
	var assist: Dictionary = config.assist
	var cut := minf(float(assist.max_cut), maxf(0, losses - int(assist.after_losses) + 1) * float(assist.per_loss_hp_cut))
	max_hp = float(config.base_hp) * (1 + float(config.hp_scale_per_level) * (level - 1)) * (1 - cut)
	hp = max_hp

func apply_hit(weapon_type: String, damage: float, sim, region := "core") -> void:
	if roar > 0 or hp <= 0:
		return
	if region == "arm" and arm_hp > 0:
		arm_hp -= damage
		if arm_hp <= 0:
			if not stolen.is_empty():
				sim.robot.broken.erase(stolen)
				sim.robot.add_part(stolen.id, sim, int(stolen.level))
				stolen = {}
				sim.emit("arm_recovered")
		return
	if phase == 1 and not config.plate.ignored_by.has(weapon_type):
		damage *= 1.0 - float(config.plate.reduction)
	if phase == 3:
		damage *= float(config.core_multiplier_phase3)
	hp = maxf(0, hp - damage)
	var new_phase := 3 if hp / max_hp <= 0.33 else (2 if hp / max_hp <= 0.66 else 1)
	if new_phase != phase:
		phase = new_phase
		roar = 1.5
		zones.clear()
		attack = ""
		sim.emit("boss_phase", {"phase": phase})
	if hp <= 0:
		sim.state = "won"
		sim.emit("boss_killed")

func _start_attack(sim) -> void:
	var definition: Dictionary = config.phases[phase - 1]
	var choices: Array = definition.attacks.duplicate()
	if sim.level == 1 and hp / max_hp > 0.6:
		choices = config.phases[0].attacks
	if sim.level >= 3 and phase == 1:
		choices.append("double_slam")
	if sim.level >= 5 and phase == 1:
		choices.append("laser_sweep")
	attack = str(choices[sim.rng.boss.randi_range(0, choices.size() - 1)])
	var spec: Dictionary = config.attacks[attack]
	telegraph_duration = float(spec.telegraph_s) * (1.2 if sim.level == 1 else 1.0)
	timer = telegraph_duration
	attacks_made += 1
	attack_hit = false
	sweep_active = false
	repeat_left = 0
	zones.clear()
	var center: float = sim.x
	match attack:
		"ground_slam", "double_slam":
			zones.append({"shape": "circle", "x": center, "radius": float(spec.radius), "damage": float(spec.damage)})
			repeat_left = 1 if attack == "double_slam" else 0
		"rocket_barrage":
			repeat_left = int(spec.rockets) - 1
			var safe: int = sim.rng.boss.randi_range(0, 2)
			for lane in 3:
				if lane != safe:
					zones.append({"shape": "lane", "x": (lane - 1) * 2.25, "radius": float(spec.lane_width) / 2, "damage": float(spec.damage)})
		"laser_sweep":
			var safe: float = sim.rng.boss.randf_range(-1.5, 1.5)
			sweep_origin = safe
			sweep_direction = -1.0 if safe > 0 else 1.0
			zones.append({"shape": "sweep", "x": safe, "radius": float(spec.safe_gap) / 2, "damage": float(spec.damage)})
		"grabber_arm":
			zones.append({"shape": "arm", "x": center, "radius": 0.9, "damage": 0.0})
		"call_scrappers":
			zones.append({"shape": "spawn", "x": 0.0, "radius": 0.0, "damage": 0.0})
	sim.emit("telegraph", {"attack": attack})

func _resolve(sim) -> void:
	if attack == "laser_sweep" and not sweep_active:
		sweep_active = true
		timer = float(config.attacks.laser_sweep.duration_s)
		return
	var hit := false
	for zone in zones:
		var inside: bool = absf(sim.x - float(zone.x)) < float(zone.radius)
		if zone.shape == "sweep":
			inside = not inside
		if zone.shape == "spawn":
			sim.spawn_pack("scrapper", int(config.attacks.call_scrappers.spawn), sim.z + 13)
		elif inside:
			hit = true
			if zone.shape == "arm":
				stolen = sim.robot.break_part(sim, true)
				arm_hp = float(config.attacks.grabber_arm.arm_hp)
				arm_timer = float(config.attacks.grabber_arm.recover_window_s)
			else:
				var before: float = sim.robot.hp
				sim.robot.take_damage(float(zone.damage) * (1 + float(config.get("damage_scale_per_level", 0)) * (sim.level - 1)), sim, attack)
				if sim.robot.hp < before and attack in ["ground_slam", "double_slam"]:
					var force: float = float(config.attacks.ground_slam.knockback) * (1.0 - float(sim.robot.stats.knockback_resist))
					sim.drag(force if sim.x >= 0 else -force)
	attack_hit = attack_hit or hit
	sim.emit("boss_attack", {"attack": attack})
	if repeat_left > 0:
		repeat_left -= 1
		timer = float(config.attacks.double_slam.repeat_gap_s) if attack == "double_slam" else float(config.attacks.rocket_barrage.duration_s) / int(config.attacks.rocket_barrage.rockets)
		return
	_finish_attack(sim)

func _finish_attack(sim) -> void:
	if not attack_hit and attack != "call_scrappers":
		sim.robot.overdrive = minf(100, sim.robot.overdrive + float(config.overdrive.per_clean_dodge))
		sim.emit("clean_dodge")
		sim.exposed_time = 3.0
		sim.emit("boss_exposed")
	sweep_active = false
	zones.clear()
	attack = ""
	var gap: Array = config.phases[phase - 1].gap_s
	timer = sim.rng.boss.randf_range(float(gap[0]), float(gap[1]))

func tick(dt: float, sim) -> void:
	elapsed += dt
	if burn_left > 0:
		burn_left -= dt
		apply_hit("cone", burn_dps * dt, sim)
		if hp <= 0:
			return
	if arm_hp > 0:
		arm_timer -= dt
		if arm_timer <= 0:
			arm_hp = 0
			stolen = {}
	if roar > 0:
		roar -= dt
		return
	timer -= dt
	if sweep_active and not zones.is_empty():
		var duration: float = float(config.attacks.laser_sweep.duration_s)
		zones[0].x = clampf(sweep_origin + sweep_direction * (1.0 - timer / duration) * 2.0, -2.3, 2.3)
		if absf(sim.x - float(zones[0].x)) > float(zones[0].radius):
			attack_hit = true
			sim.robot.take_damage(float(config.attacks.laser_sweep.damage) * (1 + float(config.get("damage_scale_per_level", 0)) * (sim.level - 1)), sim, "laser_sweep")
		if timer <= 0:
			_finish_attack(sim)
		return
	if timer <= 0:
		if attack.is_empty():
			_start_attack(sim)
		else:
			_resolve(sim)
