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
	charging.spawn_pack("bruiser", 1, 12)
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
	var hauler := RunSim.new()
	hauler.setup(1, 24)
	hauler.spawn_pack("hauler", 1, 30)
	hauler.enemies[0].timer = 0
	var start_z: float = hauler.enemies[0].z
	for tick in 300:
		hauler.t += 1.0 / 60
		hauler._combat(1.0 / 60)
	var barrels := 0
	for enemy in hauler.enemies:
		if enemy.id == "barrel":
			barrels += 1
	var hauler_events: Array = hauler.events.filter(func(e): return e.t == "hauler_spawn")
	check(float(hauler.enemies[0].z) > start_z and barrels >= 1 and hauler_events.size() == 1, "Scrap Hauler drives off and drops barrels")
	hauler.enemies[0].hp = 0
	hauler._combat(0.01)
	var burst_coins: int = hauler.scrap_nodes.size()
	check(burst_coins >= 10 and hauler.events.any(func(e): return e.t == "hauler_destroyed"), "Destroyed hauler bursts into coins")
	check(hauler.robot.parts.has("wheels"), "Destroyed hauler drops a rare part")
	var missed := RunSim.new()
	missed.setup(1, 27)
	missed.spawn_pack("hauler", 1, 10)
	missed.z = 40
	missed._combat(0.01)
	check(missed.events.any(func(e): return e.t == "hauler_missed"), "Passing the hauler counts as a miss")
	var chain := RunSim.new()
	chain.setup(1, 25)
	var first_coin := {"x": 0.0, "z": 1.0, "alive": true}
	chain.pickup_coin(first_coin)
	var scrap_one: int = chain.robot.scrap
	for i in 29:
		chain.pickup_coin({"x": 0.0, "z": 1.0, "alive": true})
	check(chain.chain == 30 and chain.robot.scrap - scrap_one > 29, "coin chain raises coin value")
	chain.robot.take_damage(5, chain)
	check(chain.chain == 0, "damage breaks the coin chain")
	var utility := RunSim.new()
	utility.setup(2, 26)
	utility.robot.hp = 10
	utility.apply_option({"kind": "heal", "pct": 0.35})
	check(utility.robot.hp > 10, "heal gate repairs")
	utility.apply_option({"kind": "frenzy"})
	check(utility.frenzy_time > 0, "frenzy gate starts")
	var three := 0
	for seed_value in 40:
		var probe := RunSim.new()
		probe.setup(3, seed_value)
		for beat in probe.beats:
			if beat.has("options") and beat.options.size() == 3:
				three += 1
	check(three > 0, "generated levels include three-lane gates")
	var overdrive_sim := RunSim.new()
	overdrive_sim.setup(1, 24)
	overdrive_sim.state = "boss"
	overdrive_sim.boss = BossSim.new()
	overdrive_sim.boss.setup(1, 0)
	overdrive_sim.last_boss_hit = 0
	for tick in 60:
		overdrive_sim.step(1.0 / 60)
	check(is_equal_approx(overdrive_sim.robot.overdrive, 2), "sustained Overdrive accrues by time, not bullet count")
	# E1: steering is aiming. Lane mode only shoots what sits in the robot's lane.
	var legacy := RunSim.new()
	legacy.setup(1, 31)
	legacy.spawn_pack("scrapper", 1, 12)
	legacy.enemies[0].x = 3.0
	check(legacy._pick_target() != null, "legacy nearest mode targets an enemy 3 m off to the side")
	var lane := RunSim.new()
	lane.flag_overrides = {"aim_mode": "lane"}
	lane.setup(1, 31)
	lane.robot.add_part("cannon", lane, 1)
	lane.spawn_pack("gunner", 1, 12)
	lane.enemies[0].x = 3.0
	lane.enemies[0].timer = 99.0
	check(lane._pick_target() == null, "lane mode ignores an enemy outside the aim cone")
	lane._fire({"id": "blaster", "type": "projectile", "damage": 4, "speed": 36})
	check(lane.bullets.size() == 1 and is_equal_approx(float(lane.bullets[0].tx), lane.x), "lane mode fires straight ahead when nothing is in the cone")
	var start_hp: float = lane.enemies[0].hp
	for tick in 120:
		lane._combat(1.0 / 60)
	check(is_equal_approx(float(lane.enemies[0].hp), start_hp), "enemy outside the cone is not hit while the player holds the lane")
	lane.x = 3.0
	lane.target_x = 3.0
	check(lane._pick_target() != null, "moving into the lane acquires the target")
	for tick in 120:
		lane._combat(1.0 / 60)
	check(lane.enemies.is_empty() or float(lane.enemies[0].hp) < start_hp, "enemy is hit once the player steers into its lane")
	# Guarded salvage: shooting the barrel clears its guards; the crate pays out when shot.
	var salvage := RunSim.new()
	salvage.flag_overrides = {"guarded_salvage": true}
	salvage.setup(1, 32)
	check(salvage.beats.any(func(b): return b.type == "salvage"), "guarded_salvage adds a salvage beat")
	salvage._spawn_salvage(40.0)
	var kinds: Dictionary = {}
	for enemy in salvage.enemies:
		kinds[enemy.id] = int(kinds.get(enemy.id, 0)) + 1
	check(kinds.get("barrel", 0) == 1 and kinds.get("gunner", 0) == 3 and kinds.get("crate", 0) == 1, "salvage block holds barrel + guards and crate + guard")
	var barrel: Dictionary = salvage.enemies.filter(func(e): return e.id == "barrel")[0]
	var guards_near := salvage.enemies.filter(func(e): return e.id == "gunner" and absf(float(e.x) - float(barrel.x)) < 1.5).size()
	check(guards_near == 2, "two gunners flank the barrel")
	barrel.hp = 0
	salvage._combat(0.01)
	salvage._combat(0.01)
	check(salvage.enemies.filter(func(e): return e.id == "gunner").size() == 1 and salvage.enemies.any(func(e): return e.id == "crate"), "barrel blast kills its two guards and spares the crate lane")
	var crate: Dictionary = salvage.enemies.filter(func(e): return e.id == "crate")[0]
	crate.hp = 0
	salvage._combat(0.01)
	check(salvage.events.any(func(e): return e.t == "salvage_looted") and salvage.scrap_nodes.size() >= 10, "looted crate bursts into coins")
	var plain := RunSim.new()
	plain.setup(1, 32)
	check(not plain.beats.any(func(b): return b.type == "salvage"), "no salvage beat with the flag off")
	# Caps hold with lane aiming and salvage on, for every aiming delay.
	for delay in [0.0, 0.15, 0.25, 0.4]:
		var capped := RunSim.new()
		capped.flag_overrides = {"aim_mode": "lane", "guarded_salvage": true, "gate_charge": true, "post_gate_payoff": true, "moving_gates": true, "dense_blocks": true, "weapon_evolution": true}
		capped.setup(3, 90)
		var aimer := AimBot.new(90, delay)
		var cap_ok := true
		for tick in 12000:
			aimer.control(capped)
			capped.step(1.0 / 60)
			capped.events.clear()
			cap_ok = cap_ok and capped.bullets.size() + capped.hostile_bullets.size() <= 64 and capped.enemies.size() <= 24 and capped.hostile_bullets.size() <= 16
			if capped.state in ["won", "lost"]:
				break
		check(cap_ok, "projectile and enemy caps hold with lane aiming (delay %.2f)" % delay)
	# E2: shots that cross a gate panel charge it; thresholds raise the granted part level.
	var charged := RunSim.new()
	charged.flag_overrides = {"gate_charge": true, "post_gate_payoff": true}
	charged.setup(1, 41)
	var first_gate: Dictionary = charged.next_gate()
	check(first_gate.has("charge") and first_gate.charge.size() == 2, "gate_charge gives each panel a charge counter")
	charged.z = 60.0
	var cannon_cost: float = charged.charge_cost({"kind": "part", "id": "cannon"})
	var t1 := float(charged.flags.tuning.charge_t1) * cannon_cost
	var t2 := float(charged.flags.tuning.charge_t2) * cannon_cost
	check(charged._charge_gate({"x": -1.7, "z": 80.2, "charge": 0.4}, 79.5), "bullet crossing a chargeable panel is absorbed")
	check(is_equal_approx(float(first_gate.charge[0]), 0.4) and float(first_gate.charge[1]) == 0.0, "charge goes to the panel the bullet crossed")
	check(not charged._charge_gate({"x": 1.7, "z": 79.0, "charge": 1.0}, 78.5), "bullet short of the gate does not charge it")
	charged.z = 30.0
	check(not charged._charge_gate({"x": 1.7, "z": 80.2, "charge": 1.0}, 79.5), "gate beyond charge range cannot be charged")
	charged.z = 60.0
	check(charged.charge_bonus(first_gate, 0) == 0, "below the first threshold grants no bonus level")
	charged._charge_gate({"x": -1.7, "z": 80.2, "charge": t1}, 79.5)
	check(charged.charge_bonus(first_gate, 0) == 1, "first threshold adds a level")
	charged._charge_gate({"x": -1.7, "z": 80.2, "charge": t2}, 79.5)
	check(charged.charge_bonus(first_gate, 0) == 2, "second threshold adds another level")
	var window := float(charged.flags.tuning.charge_range) / (float(GameData.constants().forward_speed))
	check(window >= 3.0 and window <= 4.0, "charge window is 3-4 s at base speed (%.2f s)" % window)
	check(window < 2.0 * t2 and t1 < window, "approach cannot max both panels but can reach level 2")
	# For every pair of parts that can share a gate, the charge window cannot max both panels.
	var pair_ok := true
	var ids: Array = GameData.table("parts").keys()
	for first_id in ids:
		for second_id in ids:
			if first_id != second_id and GameData.table("parts")[first_id].category != GameData.table("parts")[second_id].category:
				var both: float = (charged.charge_cost({"id": first_id}) + charged.charge_cost({"id": second_id})) * float(charged.flags.tuning.charge_t2)
				pair_ok = pair_ok and both > window
	check(pair_ok, "no part pair can have both panels maxed in one approach")
	charged.x = -1.7
	charged.target_x = -1.7
	charged.z = 80.1
	charged._resolve_gates()
	check(int(charged.robot.parts.get("cannon", 0)) == 3, "fully charged panel grants level 3 and respects the cap")
	check(charged.enemies.filter(func(e): return e.id == "scrapper").size() == 4, "cannon choice spawns a scrapper cluster to shred")
	check(charged.events.any(func(e): return e.t == "gate_charged" and e.bonus == 2), "gate_charged event reports the bonus")
	var wheels_sim := RunSim.new()
	wheels_sim.flag_overrides = {"post_gate_payoff": true}
	wheels_sim.flag_overrides = {"post_gate_payoff": true, "tuning": {"level1_first_gate": []}}
	wheels_sim.setup(1, 42)
	wheels_sim.x = 1.7
	wheels_sim.z = 80.1
	wheels_sim._resolve_gates()
	var bonus_coins := wheels_sim.scrap_nodes.filter(func(n): return n.get("bonus", false))
	check(wheels_sim.robot.parts.has("wheels") and bonus_coins.size() >= 10, "wheels choice spawns a bonus coin route")
	wheels_sim.pickup_coin(bonus_coins[0])
	check(wheels_sim.events.any(func(e): return e.t == "payoff" and e.source == "wheels"), "first bonus coin reports the wheels payoff")
	var uncharged := RunSim.new()
	uncharged.setup(1, 41)
	check(not uncharged.next_gate().has("charge"), "no charge counters with the flag off")
	var flame := RunSim.new()
	flame.flag_overrides = {"gate_charge": true}
	flame.setup(1, 43)
	flame.robot.add_part("flame", flame)
	flame.z = 76.0
	flame.x = -1.7
	var flame_gate: Dictionary = flame.next_gate()
	flame._charge_cone(flame.robot.stats.weapons[flame.robot.stats.weapons.size() - 1], 0.5)
	check(float(flame_gate.charge[0]) > 0.0, "flame sweep charges the panel in front of it")
	# E3: moving gates slide on a telegraphed path; focus fire ramps only while the lane is held.
	var sliding := RunSim.new()
	sliding.flag_overrides = {"moving_gates": true}
	sliding.setup(1, 51)
	var moving_z: Array = []
	for beat in sliding.beats:
		if beat.get("moving", false):
			moving_z.append(int(beat.z))
	check(moving_z == [290, 520], "level 1 moves the third and fifth gate pairs (got %s)" % str(moving_z))
	var moving_gate: Dictionary = sliding.beats.filter(func(b): return int(b.z) == 290)[0]
	var peak := 0.0
	var peak_speed := 0.0
	var last_offset := sliding.gate_offset(moving_gate, 0.0)
	for step_index in range(1, 1000):
		var offset := sliding.gate_offset(moving_gate, step_index * 0.01)
		peak = maxf(peak, absf(offset))
		peak_speed = maxf(peak_speed, absf(offset - last_offset) / 0.01)
		last_offset = offset
	check(peak <= float(sliding.flags.tuning.moving_amplitude) + 0.001 and peak > 0.5, "gate slide stays within its amplitude")
	check(peak_speed < 1.5, "gates slide slowly enough to read (%.2f m/s)" % peak_speed)
	check(is_equal_approx(sliding.gate_offset(moving_gate, 1.7), sliding.gate_offset(moving_gate, 1.7)), "gate slide is a pure function of time")
	var left_center: float = sliding.panel_center(moving_gate, 0, 2.0)
	var right_center: float = sliding.panel_center(moving_gate, 1, 2.0)
	check(is_equal_approx(right_center - left_center, float(sliding.flags.tuning.moving_spacing)), "moving panels keep their spacing")
	sliding.t = 2.0
	check(sliding._panel_lane(moving_gate, left_center) == 0 and sliding._panel_lane(moving_gate, right_center) == 1, "panel pick follows the moving panel centre")
	check(not sliding.beats.filter(func(b): return int(b.z) == 400)[0].get("moving", false), "other gates stay static")
	var still := RunSim.new()
	still.setup(1, 51)
	check(not still.beats.any(func(b): return b.get("moving", false)), "no moving gates with the flag off")
	var focus := RunSim.new()
	focus.flag_overrides = {"focus_fire": true}
	focus.setup(1, 52)
	check(is_equal_approx(focus.focus_multiplier(), 1.0), "focus fire starts at normal rate")
	for tick in 60:
		focus.step(1.0 / 60)
	check(focus.focus_multiplier() > 1.0, "holding the lane ramps the fire rate")
	for tick in 90:
		focus.step(1.0 / 60)
	check(is_equal_approx(focus.focus_multiplier(), 1.0 + float(focus.flags.tuning.focus_max_bonus)), "focus fire caps at +30 percent")
	focus.target_x = 1.5
	focus.step(1.0 / 60)
	check(is_equal_approx(focus.focus_multiplier(), 1.0), "any steering resets focus fire")
	var no_focus := RunSim.new()
	no_focus.setup(1, 52)
	for tick in 120:
		no_focus.step(1.0 / 60)
	check(is_equal_approx(no_focus.focus_multiplier(), 1.0), "focus fire is inert with the flag off")
	# E4: rhythm blocks and density ramp.
	var blocks := RunSim.new()
	blocks.flag_overrides = {"dense_blocks": true}
	blocks.setup(1, 61)
	var block_types: Dictionary = {}
	for beat in blocks.beats:
		if beat.type in ["wave", "coin_arc"]:
			block_types[beat.type] = int(block_types.get(beat.type, 0)) + 1
	check(block_types.get("wave", 0) == 3 and block_types.get("coin_arc", 0) == 3, "level 1 authors three survival waves and three coin arcs")
	check(blocks.beats.any(func(b): return b.type == "wave" and int(b.z) == 695), "a survival wave fills the run-in to the boss")
	var plain_blocks := RunSim.new()
	plain_blocks.setup(1, 61)
	check(not plain_blocks.beats.any(func(b): return b.type in ["wave", "coin_arc"]), "no rhythm blocks with the flag off")
	check(blocks._scaled(4, 100.0) < blocks._scaled(4, 700.0), "enemy counts ramp up toward the boss")
	var full_density: int = blocks._scaled(4, 700.0)
	blocks.density_limit = 0.6
	check(blocks._scaled(4, 700.0) < full_density, "the perf governor lowers density")
	blocks.density_limit = 1.0
	blocks._spawn_wave(100.0)
	check(blocks.enemies.size() >= 5, "a survival wave spawns a first and a second group")
	blocks._spawn_coin_arc(50.0)
	var arc_x: Array = blocks.scrap_nodes.map(func(n): return float(n.x))
	check(arc_x.size() == 12 and arc_x.max() - arc_x.min() > 3.5, "a coin arc needs steering")
	var generated := RunSim.new()
	generated.flag_overrides = {"dense_blocks": true}
	generated.setup(3, 62)
	check(generated.beats.any(func(b): return b.type == "wave" and is_equal_approx(float(b.z), generated.boss_z - 25.0)), "generated levels get a pre-boss wave")
	# E5: Cluster Rockets need the burst-volley combo and rocket level 2.
	var evo := RunSim.new()
	evo.flag_overrides = {"weapon_evolution": true}
	evo.setup(1, 71)
	evo.robot.add_part("rocket", evo, 1)
	evo.robot.add_part("cannon", evo, 1)
	check(not evo.evolution_active(), "rocket level 1 does not evolve")
	evo.robot.add_part("rocket", evo, 1)
	check(evo.evolution_active(), "rocket level 2 with a cannon evolves")
	var evo_missing := RunSim.new()
	evo_missing.flag_overrides = {"weapon_evolution": true}
	evo_missing.setup(1, 71)
	evo_missing.robot.add_part("rocket", evo_missing, 2)
	check(not evo_missing.evolution_active(), "rocket level 2 without a cannon does not evolve")
	var evo_off := RunSim.new()
	evo_off.setup(1, 71)
	evo_off.robot.add_part("rocket", evo_off, 2)
	evo_off.robot.add_part("cannon", evo_off, 1)
	check(not evo_off.evolution_active(), "evolution is inert with the flag off")
	for i in 4:
		evo.spawn_pack("scrapper", 1, 12.0 + i)
		evo.enemies.back().x = -1.0 + i * 0.7
		evo.enemies.back().hp = 500.0
		evo.enemies.back().timer = 99.0
	evo.bullets.append({"x": -1.0, "z": 11.4, "tx": -1.0, "tz": 12.0, "type": "rocket", "wid": "rocket", "damage": 40.0, "speed": 26.0, "radius": 2.0, "ttl": 2.0, "charge": 0.0})
	evo._combat(0.05)
	var kids: Array = evo.bullets.filter(func(b): return b.type == "cluster")
	check(kids.size() == 3 and evo.events.any(func(e): return e.t == "cluster_burst"), "a rocket hit splits into three bomblets")
	evo.events.clear()
	evo.robot.stats.weapons = []
	evo.bullets = evo.bullets.filter(func(b): return b.type == "cluster")
	var max_kids := 0
	for tick in 120:
		evo._combat(1.0 / 60)
		max_kids = maxi(max_kids, evo.bullets.filter(func(b): return b.type == "cluster").size())
	check(max_kids <= int(evo.flags.tuning.evolution_child_cap), "bomblets stay under the cap")
	check(not evo.events.any(func(e): return e.t == "cluster_burst"), "bomblets do not split again")
	var evo_plain := RunSim.new()
	evo_plain.setup(1, 71)
	evo_plain.robot.add_part("rocket", evo_plain, 2)
	evo_plain.robot.add_part("cannon", evo_plain, 1)
	evo_plain.spawn_pack("scrapper", 1, 12.0)
	evo_plain.enemies[0].hp = 500.0
	evo_plain.enemies[0].timer = 99.0
	evo_plain.bullets.append({"x": 0.0, "z": 11.8, "tx": 0.0, "tz": 12.0, "type": "rocket", "wid": "rocket", "damage": 40.0, "speed": 26.0, "radius": 2.0, "ttl": 2.0, "charge": 0.0})
	evo_plain._combat(0.05)
	check(evo_plain.bullets.filter(func(b): return b.type == "cluster").is_empty(), "no bomblets with the flag off")
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
