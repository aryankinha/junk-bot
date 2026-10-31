extends SceneTree
var failures: Array = []
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	GameData.load_all()
	for id in GameData.NAMES:
		check(not GameData.table(id).is_empty(), "table " + id)
	for id in GameData.table("parts"):
		var p: Dictionary = GameData.table("parts")[id]
		check(p.levels.size() == 3, id + " has three levels")
		check(not p.slots.is_empty(), id + " has sockets")
	for combo in GameData.table("combos").values():
		for id in combo.needs:
			check(GameData.table("parts").has(id), "combo references " + id)
	for beat in GameData.table("gates_level1").beats:
		for option in beat.get("options", []):
			if option.kind == "part":
				check(GameData.table("parts").has(option.id), "gate reference")
	var robot := RobotState.new()
	check(robot.stage() == 1 and robot.hp == 60, "tiny chassis")
	robot.add_part("cannon")
	robot.add_part("cannon")
	check(robot.parts.cannon == 2 and robot.slots.size() == 1, "merge does not allocate a duplicate")
	robot.add_part("cannon", null, 3)
	check(robot.parts.cannon == 3, "level cap")
	robot.add_part("wheels")
	check(robot.stage() == 2, "battle at 4")
	robot.add_part("tracks")
	check(not robot.parts.has("wheels") and robot.parts.has("tracks"), "tracks replace wheels")
	robot.add_part("rocket", null, 3)
	robot.add_part("armour", null, 2)
	check(robot.stage() == 3, "monster at 9")
	check(robot.combos().has("burst_volley") and robot.combos().has("ram_charge"), "combos")
	check(robot.stats.oil_immune, "tracks oil immunity")
	check(robot.stats.max_hp > 260, "parts contribute hp")
	# Verify each threshold fires once and invulnerability cannot be bypassed.
	var sim := RunSim.new()
	sim.setup(1, 42)
	for id in ["cannon", "wheels", "magnet", "armour"]:
		sim.robot.add_part(id, sim)
	var hp_before: float = sim.robot.hp
	sim.robot.take_damage(sim.robot.max_hp * 0.3, sim)
	var hp_after: float = sim.robot.hp
	sim.robot.take_damage(20, sim)
	check(sim.robot.hp == hp_after and hp_after < hp_before, "hit invulnerability")
	check(sim.robot.crossed.size() == 1, "75 percent breaks once")
	sim.robot.invuln = 0
	sim.robot.take_damage(999, sim)
	check(sim.robot.parts.has("cannon"), "never break last weapon")
	check(sim.state == "lost", "death")
	check(sim.revive() and not sim.revive(), "one revive")
	# Thousands of generated pairs; verify categories, unlock levels and lv3 exclusions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for level in range(1, 6):
		for i in 1000:
			var pair := GateGen.pair(level, robot if i % 2 == 0 else RobotState.new(), rng, i % 10)
			check(pair.size() == 2, "pair size")
			if pair[0].kind == "part" and pair[1].kind == "part":
				check(GameData.table("parts")[pair[0].id].category != GameData.table("parts")[pair[1].id].category, "pair categories")
				for option in pair:
					check(int(GameData.table("parts")[option.id].unlock_level) <= level, "unlock rule")
					if i % 2 == 0:
						check(int(robot.parts.get(option.id, 0)) < 3, "exclude capped part")
	var a := RunSim.new()
	var b := RunSim.new()
	a.setup(1, 77)
	b.setup(1, 77)
	var log_a: Array = []
	var log_b: Array = []
	for i in 7200:
		a.target_x = sin(i * 0.001) * 2
		b.target_x = a.target_x
		a.step(1.0 / 60)
		b.step(1.0 / 60)
		log_a.append_array(a.events)
		log_b.append_array(b.events)
		a.events.clear()
		b.events.clear()
	check(JSON.stringify(log_a) == JSON.stringify(log_b), "same seed + input -> identical full event log")
	check(a.z == b.z and a.robot.hp == b.robot.hp, "deterministic state")
	var r1 := RngStreams.new()
	var r2 := RngStreams.new()
	r1.seed_all(8)
	r2.seed_all(8)
	for i in 100:
		r1.loot.randf()
	check(r1.boss.randi() == r2.boss.randi(), "loot cannot perturb boss RNG")
	var bs := BossSim.new()
	bs.setup(1, 0)
	bs.roar = 0
	var hp := bs.hp
	bs.apply_hit("projectile", 100, a)
	check(is_equal_approx(hp - bs.hp, 50), "boss plate halves projectile")
	hp = bs.hp
	bs.apply_hit("rocket", 100, a)
	check(is_equal_approx(hp - bs.hp, 100), "rockets ignore plate")
	bs.apply_hit("rocket", bs.max_hp * 0.36, a)
	check(bs.phase == 2 and bs.roar > 0, "phase two roar")
	bs.roar = 0
	bs.apply_hit("rocket", bs.max_hp * 0.36, a)
	check(bs.phase == 3, "phase three")
	bs.roar = 0
	hp = bs.hp
	bs.apply_hit("rocket", 100, a)
	check(is_equal_approx(hp - bs.hp, 150), "exposed core multiplier")
	var assist := BossSim.new()
	assist.setup(1, 4)
	check(is_equal_approx(assist.max_hp, float(GameData.table("boss_scrap_titan").base_hp) * 0.7), "assist caps at 30 percent")
	var collector := RobotState.new()
	for id in ["cannon", "rocket", "magnet", "storage"]:
		collector.add_part(id)
	check(collector.parts.size() == 4, "socket relocation preserves existing attachments")
	check(collector.combos().has("vacuum"), "Vacuum is obtainable with magnet-first pickup order")
	check(collector.combos().has("burst_volley"), "relocation retains weapon combo")
	var arm_sim := RunSim.new()
	arm_sim.setup(1, 17)
	arm_sim.robot.add_part("cannon", arm_sim, 3)
	arm_sim.robot.add_part("wheels", arm_sim, 2)
	var arm_boss := BossSim.new()
	arm_boss.setup(1, 0)
	arm_boss.roar = 0
	arm_boss.stolen = arm_sim.robot.break_part(arm_sim, true)
	arm_boss.arm_hp = 250
	check(not arm_sim.robot.parts.has("wheels"), "grabber steals highest eligible attachment")
	arm_boss.apply_hit("projectile", 250, arm_sim, "arm")
	check(arm_sim.robot.parts.get("wheels", 0) == 2 and arm_sim.robot.broken.is_empty(), "destroying arm restores stolen level")
	for attack_id in GameData.table("boss_scrap_titan").attacks:
		check(float(GameData.table("boss_scrap_titan").attacks[attack_id].telegraph_s) > 0, "boss attacks always telegraph")
	var burn_sim := RunSim.new()
	burn_sim.setup(2, 20)
	burn_sim.robot.add_part("flame")
	burn_sim.spawn_pack("scrapper", 1, 4)
	burn_sim.enemies[0].x = 0
	burn_sim._combat(0.1)
	check(float(burn_sim.enemies[0].burn_left) > 0, "flame applies a burn timer")
	burn_sim.robot.remove_part("flame")
	burn_sim.robot.refresh()
	var burned_hp: float = burn_sim.enemies[0].hp
	burn_sim._combat(0.1)
	check(float(burn_sim.enemies[0].hp) < burned_hp, "burn persists outside the flame cone")
	var blast := RunSim.new()
	blast.setup(1, 21)
	blast.spawn_pack("scrapper", 1, 6)
	blast.spawn_pack("barrel", 1, 6)
	for enemy in blast.enemies:
		enemy.x = 0
	blast.enemies[1].hp = 0
	blast._combat(0.01)
	check(blast.enemies.is_empty(), "destroyed barrel blasts nearby enemies")
	var gunner := RunSim.new()
	gunner.setup(1, 22)
	gunner.spawn_pack("gunner", 1, 10)
	gunner.enemies[0].x = 0
	gunner.enemies[0].timer = 0
	gunner.enemies[0].warning = true
	gunner._combat(0.01)
	check(gunner.hostile_bullets.size() == 1, "gunner telegraph launches a simulated bolt")
	for tick in 60:
		gunner.robot.tick(1.0 / 60)
		gunner._combat(1.0 / 60)
	check(gunner.robot.hp < gunner.robot.max_hp, "hostile bolt collision deals damage")
	var charging := RunSim.new()
	charging.setup(1, 23)
	charging.spawn_pack("elite_bruiser", 1, 12)
	charging.enemies[0].x = 0
	charging.enemies[0].aim_x = 0
	charging.enemies[0].timer = 0
	charging.enemies[0].warning = true
	charging._combat(0.01)
	check(float(charging.enemies[0].charge_left) > 0, "Bruiser begins a physical charge")
	var initial_charge_z: float = charging.enemies[0].z
	for tick in 20:
		charging.robot.tick(1.0 / 60)
		charging._combat(1.0 / 60)
	check(float(charging.enemies[0].z) < initial_charge_z, "charging enemy advances through the lane")
	var charge_events := 0
	for tick in 160:
		charging.robot.tick(1.0 / 60)
		charging._combat(1.0 / 60)
	for event in charging.events:
		if event.t == "player_hit":
			charge_events += 1
	check(charge_events == 2, "Elite performs two separately damaging charges")
	var overdrive_sim := RunSim.new()
	overdrive_sim.setup(1, 24)
	overdrive_sim.state = "boss"
	overdrive_sim.boss = BossSim.new()
	overdrive_sim.boss.setup(1, 0)
	overdrive_sim.last_boss_hit = 0
	for tick in 60:
		overdrive_sim.step(1.0 / 60)
	check(is_equal_approx(overdrive_sim.robot.overdrive, 2), "sustained Overdrive accrues by time, not bullet count")
	# Exercise the actual scene tree and persistent services as part of the main runner.
	var integration = load("res://tests/integration_suite.gd").new()
	var integration_failures: Array = await integration.run(self)
	checks += integration.checks
	failures.append_array(integration_failures)
	print("%d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	var file := FileAccess.open("res://results/headless_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	quit(0 if failures.is_empty() else 1)
