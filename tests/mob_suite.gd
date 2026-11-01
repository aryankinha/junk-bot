extends RefCounted
# Mob Stream checks (flag mob_stream). Called from tests/run_all.gd; tests/mob_only.gd runs it alone.
var checks := 0
var failures: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

# Damage a stationary high-hp dummy takes from a build in `seconds` of fire, with the robot standing still.
func dummy_damage(overrides: Dictionary, parts: Dictionary, seconds: float) -> float:
	var sim := RunSim.new()
	sim.flag_overrides = overrides
	sim.setup(1, 91)
	for id in parts:
		sim.robot.add_part(id, sim, int(parts[id]))
	sim.spawn_pack("crate", 1, 5.0)
	var dummy: Dictionary = sim.enemies[0]
	dummy.hp = 1.0e9
	dummy.x = 0.0
	dummy.z = 5.0
	for tick in int(seconds * 60.0):
		sim._combat(1.0 / 60.0)
	return 1.0e9 - float(dummy.hp)

func run() -> void:
	GameData.load_all()
	var mob_cfg: Dictionary = GameData.table("mob")
	check(GameData.flags().mob_stream == false, "mob_stream defaults off")
	check(not RunSim.new().flags.has("mob_stream") or RunSim.new().mob == null, "no MobSim without the flag")
	# MOB-1: damage parity. With no mob gates the stream deals the old damage per second.
	var builds := {
		"blaster only": {},
		"cannon L1": {"cannon": 1}, "cannon L2": {"cannon": 2}, "cannon L3": {"cannon": 3},
		"rocket L1": {"rocket": 1}, "rocket L2": {"rocket": 2}, "rocket L3": {"rocket": 3},
		"flame L1": {"flame": 1}, "flame L2": {"flame": 2}, "flame L3": {"flame": 3},
		"cannon L2 + rocket L2 + flame L1": {"cannon": 2, "rocket": 2, "flame": 1}}
	for label in builds:
		var old_damage := dummy_damage({}, builds[label], 20.0)
		var new_damage := dummy_damage({"mob_stream": true}, builds[label], 20.0)
		var ratio := new_damage / maxf(old_damage, 0.001)
		check(old_damage > 50.0 and ratio > 0.96 and ratio < 1.04, "damage parity %s: old %.0f new %.0f ratio %.3f" % [label, old_damage, new_damage, ratio])
	# Volley size follows the part level (cannon 2/3/4, rocket 1/2/3, flame 3/4/5).
	for spec in [["cannon", 1, 2], ["cannon", 2, 3], ["cannon", 3, 4], ["rocket", 1, 1], ["rocket", 2, 2], ["rocket", 3, 3]]:
		var sim := RunSim.new()
		sim.flag_overrides = {"mob_stream": true}
		sim.setup(1, 5)
		sim.robot.add_part(spec[0], sim, spec[1])
		var weapon: Dictionary = sim.robot.stats.weapons.filter(func(w): return w.id == spec[0])[0]
		sim.mob.launch_volley(sim, weapon, 0.0)
		check(sim.mob.n == spec[2], "%s level %d launches %d drones (got %d)" % [spec[0], spec[1], spec[2], sim.mob.n])
	# Drone kinds follow the weapon part.
	var kinds_sim := RunSim.new()
	kinds_sim.flag_overrides = {"mob_stream": true}
	kinds_sim.setup(1, 6)
	kinds_sim.robot.add_part("rocket", kinds_sim)
	for weapon in kinds_sim.robot.stats.weapons:
		if weapon.type != "cone":
			kinds_sim.mob.launch_volley(kinds_sim, weapon, 0.0)
	check(kinds_sim.mob.kind.slice(0, kinds_sim.mob.n).has(MobSim.Kind.BOLT) and kinds_sim.mob.kind.slice(0, kinds_sim.mob.n).has(MobSim.Kind.BOMB), "blaster fires bolts and rocket fires bombs")
	# Cap: a flood never exceeds the live cap and keeps every point of damage (merged into heavier drones).
	var cap_sim := RunSim.new()
	cap_sim.flag_overrides = {"mob_stream": true}
	cap_sim.setup(1, 7)
	var cap := cap_sim.mob.live_cap()
	check(cap == int(mob_cfg.cap), "drone cap comes from data")
	var added := 0.0
	for i in cap + 150:
		cap_sim.mob.add_drone(MobSim.Kind.BOLT, 0.0, 1.0 + float(i) * 0.01, 0.0, 30.0, 2.0, 0.1, 5.0)
		added += 2.0
	var held := 0.0
	for i in cap_sim.mob.n:
		held += cap_sim.mob.dmg[i]
	check(cap_sim.mob.n == cap, "drones never exceed the cap (%d)" % cap_sim.mob.n)
	check(absf(held - added) < 0.001, "overflow merges into heavier drones without losing damage (%.2f vs %.2f)" % [held, added])
	check(cap_sim.mob.stats.merges == 150, "merge count is tracked")
	cap_sim.density_limit = 0.5
	cap_sim.mob.cap_scale = 0.5
	check(cap_sim.mob.live_cap() == cap / 2, "density governor shrinks the live cap")
	# A long high-rate run stays under the cap.
	var rate_sim := RunSim.new()
	rate_sim.flag_overrides = {"mob_stream": true}
	rate_sim.setup(1, 8)
	rate_sim.robot.add_part("cannon", rate_sim, 3)
	rate_sim.robot.add_part("rocket", rate_sim, 3)
	rate_sim.special_time = 100.0
	var peak := 0
	for tick in 1200:
		rate_sim.step(1.0 / 60.0)
		peak = maxi(peak, rate_sim.mob.n)
	check(peak <= int(mob_cfg.cap) and peak > 20, "a gatling+rocket run keeps the stream under the cap (peak %d)" % peak)
	# Determinism: same seed and inputs give the same event log and the same drone state.
	var logs: Array = []
	for pass_index in 2:
		var det := RunSim.new()
		det.flag_overrides = {"mob_stream": true}
		det.setup(1, 123)
		var text := ""
		for tick in 900:
			det.target_x = sin(float(tick) * 0.02) * 2.5
			det.step(1.0 / 60.0)
			for event in det.events:
				text += JSON.stringify(event)
			det.events.clear()
		text += str(det.mob.n) + ":" + str(det.mob.px.slice(0, det.mob.n)) + str(det.mob.dmg.slice(0, det.mob.n))
		logs.append(text.md5_text())
	check(logs[0] == logs[1], "same seed gives the same mob event log and drone state")
	# The stream bends when the robot steers: drones launched while moving right drift right.
	var bend := RunSim.new()
	bend.flag_overrides = {"mob_stream": true}
	bend.setup(1, 9)
	bend.mob.robot_vx = 5.0
	bend.mob.launch_volley(bend, bend.robot.stats.weapons[0], 0.0)
	var mean_vx := 0.0
	for i in bend.mob.n:
		mean_vx += bend.mob.vx[i] / bend.mob.n
	check(mean_vx > 1.5, "drones inherit lateral velocity (mean vx %.2f)" % mean_vx)
	var flag_off := RunSim.new()
	flag_off.setup(1, 9)
	check(flag_off.mob == null, "no mob state with the flag off")

	_gate_tests()
	_champion_tests()
	_generated_tests()
	_stream_tests()
	_resume_regressions()

func _resume_regressions() -> void:
	var sim := gate_sim([{"t": "mult", "v": 3}])
	for i in sim.mob.live_cap():
		sim.mob.add_drone(MobSim.Kind.BOLT, 0.0, 0.0, 0.0, 0.0, 2.0, 0.5, 9.0)
	var before := total_damage(sim)
	sim.mob.launch_champion(sim, true)
	check(sim.mob.n <= sim.mob.live_cap() and sim.mob.kind.slice(0, sim.mob.n).has(MobSim.Kind.CHAMPION), "champion launches inside the global cap")
	check(absf(total_damage(sim) - before - float(sim.mob.cfg.champion.damage) * 1.5) < 0.001, "making room for champion preserves existing damage")
	before = total_damage(sim)
	sim.mob.cap_scale = 0.6
	sim.mob.step(sim, 0.0)
	check(sim.mob.n == sim.mob.live_cap() and absf(total_damage(sim) - before) < 0.001, "governor immediately compacts existing drones without losing damage")
	# A piercing drone overlapping multiple enemies may damage each once, never ping-pong between them.
	var pierce_sim := gate_sim([])
	pierce_sim.spawn_pack("crate", 2, 5.0)
	for enemy in pierce_sim.enemies:
		enemy.x = 0.0
		enemy.z = 5.0
		enemy.hp = 1000.0
	pierce_sim.mob.add_drone(MobSim.Kind.CHAMPION, 0, 5, 0, 0, 10, 0, 5)
	pierce_sim.mob.step(pierce_sim, 0.01)
	pierce_sim.mob.step(pierce_sim, 0.01)
	check(pierce_sim.enemies.all(func(e): return is_equal_approx(float(e.hp), 990.0)), "piercing drone hits each enemy only once")
	var stream := RunSim.new()
	stream.flag_overrides = {"mob_stream": true, "mob_enemy_streams": true, "dense_blocks": true}
	stream.setup(1, 41)
	stream.beats = [{"type": "enemy_stream", "z": 20.0, "x": 1.8, "count": 40}]
	stream.next_beat = 0
	stream._spawn_beats()
	check(stream.events.any(func(e): return e.t == "mob_enemy_stream") and not stream.enemies.is_empty(), "enemy-stream beats actually spawn")
	check(stream.enemies.size() <= int(stream.flags.tuning.dense_enemy_cap), "enemy streams obey the dense enemy cap")
	var stationary := RunSim.new()
	stationary.flag_overrides = {"mob_stream": true}
	stationary.setup(1, 7)
	var stay := MobBot.new(7, 0.0, [], "no_dodge", "stay")
	for tick in 600:
		stay.control(stationary)
		stationary.step(1.0 / 60)
	check(is_zero_approx(stationary.x) and is_zero_approx(stationary.target_x), "stationary bot really stays at x=0")
	var delayed := RunSim.new()
	delayed.flag_overrides = {"mob_stream": true}
	delayed.setup(1, 8)
	var bot := MobBot.new(8, 0.4)
	bot.control(delayed)
	check(is_zero_approx(delayed.target_x), "delayed bot cannot react on the first frame")
	delayed.t = 0.41
	bot.control(delayed)
	check(not is_zero_approx(delayed.target_x), "delayed steering command becomes available after reaction time")
	# A relocated weapon uses its assigned nominal socket, not the central blaster origin.
	var socket_sim := gate_sim([])
	socket_sim.robot.add_part("cannon", socket_sim)
	socket_sim.robot.slots = {"side_r": "cannon"}
	var muzzle := socket_sim.mob.muzzle(socket_sim, "cannon")
	check(muzzle.x > 1.0 and muzzle.y > 0.5, "weapon launches from its assigned socket")
	# Plate, exposed core and clean-dodge exposure all go through the existing BossSim rules.
	for spec in [[MobSim.Kind.BOLT, 1, 0.0, 5.0], [MobSim.Kind.BOMB, 1, 0.0, 10.0], [MobSim.Kind.BOLT, 3, 0.0, 15.0], [MobSim.Kind.BOMB, 3, 1.0, 22.5]]:
		var boss_sim := RunSim.new()
		boss_sim.flag_overrides = {"mob_stream": true}
		boss_sim.setup(1, 55)
		boss_sim.state = "boss"
		boss_sim.boss = BossSim.new()
		boss_sim.boss.setup(1, 0)
		boss_sim.boss.roar = 0.0
		boss_sim.boss.phase = int(spec[1])
		boss_sim.exposed_time = float(spec[2])
		boss_sim.mob.add_drone(int(spec[0]), 0, 14.0, 0, 0, 10, 0, 5)
		var hp := boss_sim.boss.hp
		boss_sim.mob.step(boss_sim, 0.0)
		check(is_equal_approx(hp - boss_sim.boss.hp, float(spec[3])), "drone kind %d phase %d exposure %.0f obeys Titan damage rules" % [spec[0], spec[1], spec[2]])

# Sim with one mob gate at z=20 and a single drone aimed straight at it.
func gate_sim(panels: Array, moving := false) -> RunSim:
	var sim := RunSim.new()
	sim.flag_overrides = {"mob_stream": true}
	sim.setup(1, 33)
	sim.beats = [{"z": 20.0, "type": "mob_gate", "panels": panels, "moving": moving, "resolved": false}]
	sim.next_beat = 1
	sim.mob.register_gates(sim.beats)
	sim.robot.stats.weapons = []
	return sim

func total_damage(sim: RunSim) -> float:
	var sum := 0.0
	for i in sim.mob.n:
		sum += sim.mob.dmg[i]
	return sum

func send(sim: RunSim, at_x: float, count := 1, damage := 4.0) -> void:
	for i in count:
		sim.mob.add_drone(MobSim.Kind.BOLT, at_x, 18.0 + float(i) * 0.001, 0.0, 36.0, damage, 0.0, 5.0)

func _gate_tests() -> void:
	# MOB-2: multiply, add, power, speed, trap.
	var mult := gate_sim([{"t": "mult", "v": 3}, {"t": "mult", "v": 2}])
	send(mult, -1.7)
	mult.step(0.1)
	check(mult.mob.n == 3 and absf(total_damage(mult) - 12.0) < 0.001, "x3 gate makes 3 drones with 3x damage (n %d, dmg %.2f)" % [mult.mob.n, total_damage(mult)])
	mult.step(0.1)
	check(mult.mob.n == 3, "a drone is affected once per gate (n %d)" % mult.mob.n)
	var right := gate_sim([{"t": "mult", "v": 3}, {"t": "mult", "v": 2}])
	send(right, 1.7)
	right.step(0.1)
	check(right.mob.n == 2 and absf(total_damage(right) - 8.0) < 0.001, "panel is chosen by the drone's x (right panel x2)")
	var outside := gate_sim([{"t": "mult", "v": 3}, {"t": "mult", "v": 2}])
	send(outside, 3.8)
	outside.step(0.1)
	check(outside.mob.n == 1, "a drone beside the gate is not multiplied")
	# Two gates in a row each multiply once.
	var two := gate_sim([{"t": "mult", "v": 2}])
	two.beats.append({"z": 21.5, "type": "mob_gate", "panels": [{"t": "mult", "v": 2}], "moving": false, "resolved": false})
	two.mob.register_gates(two.beats)
	send(two, 0.0)
	for i in 6:
		two.step(0.05)
	check(two.mob.n == 4 and absf(total_damage(two) - 16.0) < 0.001, "two gates multiply a drone twice and no more (n %d)" % two.mob.n)
	var added := gate_sim([{"t": "add", "v": 6}])
	send(added, 0.0, 10)
	added.step(0.1)
	check(added.mob.n == 10 + 12 and absf(total_damage(added) - 4.0 * 22.0) < 0.001, "+6 gate adds 6 drones per 5 that pass (n %d)" % added.mob.n)
	var power := gate_sim([{"t": "power", "v": 100}])
	send(power, 0.0, 3)
	power.step(0.1)
	check(power.mob.n == 3 and absf(total_damage(power) - 24.0) < 0.001, "+100% power doubles drone damage")
	var speed := gate_sim([{"t": "speed", "v": 40}])
	send(speed, 0.0)
	speed.step(0.1)
	check(absf(speed.mob.vz[0] - 36.0 * 1.4) < 0.01, "speed gate scales drone velocity")
	var trap := gate_sim([{"t": "trap", "v": 50}])
	send(trap, 0.0, 10)
	trap.step(0.1)
	check(trap.mob.n == 5 and absf(total_damage(trap) - 20.0) < 0.001, "trap /2 destroys every second drone (n %d)" % trap.mob.n)
	# Cap: a multiplication at the cap merges into heavier drones and keeps the damage.
	var capped := gate_sim([{"t": "mult", "v": 3}])
	var cap := capped.mob.live_cap()
	for i in cap - 1:
		capped.mob.add_drone(MobSim.Kind.BOLT, 2.5, 0.0 + float(i) * 0.0, 0.0, 0.0, 1.0, 0.0, 9.0)
	send(capped, 0.0, 1, 5.0)
	var before := total_damage(capped)
	capped.step(0.1)
	check(capped.mob.n <= cap, "gate multiplication never exceeds the cap (n %d, cap %d)" % [capped.mob.n, cap])
	check(absf(total_damage(capped) - (before + 10.0)) < 0.001, "merged multiplication keeps total damage (%.2f vs %.2f)" % [total_damage(capped), before + 10.0])
	check(capped.mob.stats.merges >= 1, "cap merge is counted")
	# Pass events are throttled and report counts.
	var events := gate_sim([{"t": "mult", "v": 2}])
	for i in 8:
		send(events, 0.0, 1)
		events.mob.px[events.mob.n - 1] = 0.0
		events.mob.pz[events.mob.n - 1] = 19.99
		events.step(0.02)
	var passes := events.events.filter(func(e): return e.t == "mob_gate_pass")
	check(passes.size() == 1 and int(passes[0].count) >= 1, "mob_gate_pass is throttled (%d events)" % passes.size())
	check(events.mob.first_multiply_t >= 0.0, "first multiplication time is recorded")
	# Moving gates: panel follows the slide, and a drone between panels gets nothing.
	var moving := gate_sim([{"t": "mult", "v": 3}, {"t": "mult", "v": 2}], true)
	moving.t = 1.0
	var left_center := moving.mob.panel_center(moving.beats[0], 0, 1.0, moving.flags.tuning)
	var right_center := moving.mob.panel_center(moving.beats[0], 1, 1.0, moving.flags.tuning)
	check(moving.mob.panel_lane(moving.beats[0], left_center, 1.0, moving.flags.tuning) == 0 and moving.mob.panel_lane(moving.beats[0], right_center, 1.0, moving.flags.tuning) == 1, "moving mob panels are found by their slid centre")
	check(moving.mob.panel_lane(moving.beats[0], (left_center + right_center) / 2.0, 1.0, moving.flags.tuning) == -1, "the gap between moving panels gives nothing")
	# Level 1 authoring: at least six gates in the first 45 s of road, in z order, both families present.
	var level1 := RunSim.new()
	level1.flag_overrides = {"mob_stream": true}
	level1.setup(1, 5)
	var mob_beats := level1.beats.filter(func(b): return b.type == "mob_gate")
	var early := mob_beats.filter(func(b): return float(b.z) <= 9.0 * 45.0)
	check(early.size() >= 6, "level 1 has at least six mob gates in the first 45 s (%d)" % early.size())
	check(level1.beats.any(func(b): return b.type == "gate"), "part gates stay beside mob gates")
	var part_gate_z := level1.beats.filter(func(b): return b.type == "gate").map(func(b): return float(b.z))
	var near := 999.0
	for beat in mob_beats:
		for gz in part_gate_z:
			near = minf(near, absf(float(beat.z) - gz))
	check(near >= 20.0, "mob gates keep 20 m from part gates (%.0f)" % near)
	var plain := RunSim.new()
	plain.setup(1, 5)
	check(not plain.beats.any(func(b): return b.type == "mob_gate"), "no mob gates with the flag off")

func _champion_tests() -> void:
	var spec: Dictionary = GameData.table("mob").champion
	# Overdrive launches a champion; below 100 it does nothing extra.
	var sim := RunSim.new()
	sim.flag_overrides = {"mob_stream": true}
	sim.setup(1, 61)
	sim.robot.overdrive = 60.0
	check(not sim.tap_special() and sim.mob.n == 0, "no champion below full Overdrive")
	sim.robot.overdrive = 100.0
	check(sim.tap_special(), "full Overdrive can be spent")
	check(sim.mob.n == 1 and sim.mob.kind[0] == MobSim.Kind.CHAMPION and sim.robot.overdrive == 0.0, "Overdrive launches one champion and empties the bar")
	check(sim.events.any(func(e): return e.t == "mob_champion"), "champion launch is an event")
	# Champion gets through a gate: boosted by x3, ignores a trap, never splits.
	var boosted := gate_sim([{"t": "mult", "v": 3}])
	boosted.mob.launch_champion(boosted, true)
	boosted.mob.pz[0] = 19.5
	var base := boosted.mob.dmg[0]
	boosted.step(0.1)
	check(boosted.mob.n == 1 and absf(boosted.mob.dmg[0] - base * 3.0) < 0.01, "champion is boosted x3 by a mob gate and does not split")
	var trapped := gate_sim([{"t": "trap", "v": 50}])
	trapped.mob.launch_champion(trapped, true)
	trapped.mob.pz[0] = 19.5
	trapped.step(0.1)
	check(trapped.mob.n == 1 and trapped.mob.dmg[0] > 0.9 * float(spec.damage), "a trap gate cannot destroy the champion")
	# Smash: the champion pierces a column and splashes neighbours.
	var smash := RunSim.new()
	smash.flag_overrides = {"mob_stream": true}
	smash.setup(1, 62)
	smash.robot.stats.weapons = []
	for i in 4:
		smash.spawn_pack("crate", 1, 8.0 + float(i) * 3.0)
		smash.enemies.back().hp = 100.0
		smash.enemies.back().x = 0.0
	smash.enemies.append({"uid": 99, "id": "crate", "x": 1.5, "z": 8.0, "hp": 100.0, "max_hp": 100.0, "timer": 99.0, "warning": false, "aim_x": 0.0, "windup": 0.0, "charge_left": 0.0, "charges_remaining": 0, "burn_left": 0.0, "burn_dps": 0.0})
	smash.mob.launch_champion(smash, true)
	for tick in 120:
		smash.step(1.0 / 60.0)
		for e in smash.enemies:
			e.timer = 99.0
	var hurt := smash.enemies.filter(func(e): return float(e.hp) < 100.0).size() + (4 - smash.enemies.filter(func(e): return int(e.uid) != 99).size())
	check(hurt >= 4, "champion smashes through a column and splashes the neighbour (%d hurt)" % hurt)
	# Champion + combo special in the same tap.
	var combo := RunSim.new()
	combo.flag_overrides = {"mob_stream": true}
	combo.setup(1, 63)
	combo.robot.add_part("cannon", combo, 1)
	combo.robot.add_part("rocket", combo, 1)
	combo.robot.overdrive = 100.0
	check(combo.tap_special() and combo.events.any(func(e): return e.t == "special_used" and e.id == "burst_volley") and combo.events.any(func(e): return e.t == "mob_champion"), "a combo special and a champion launch together at full Overdrive")
	var combo_only := RunSim.new()
	combo_only.flag_overrides = {"mob_stream": true}
	combo_only.setup(1, 63)
	combo_only.robot.add_part("cannon", combo_only, 1)
	combo_only.robot.add_part("rocket", combo_only, 1)
	combo_only.robot.overdrive = 30.0
	check(combo_only.tap_special() and not combo_only.events.any(func(e): return e.t == "mob_champion"), "a combo special alone launches no champion")
	# Boss: the champion hits the Titan through the plate (it counts as a rocket-type hit).
	var boss := RunSim.new()
	boss.flag_overrides = {"mob_stream": true}
	boss.setup(1, 64)
	boss.robot.stats.weapons = []
	boss.state = "boss"
	boss.boss = BossSim.new()
	boss.boss.setup(1, 0)
	boss.boss.roar = 0.0
	boss.boss.phase = 1
	boss.mob.launch_champion(boss, false)
	var hp_before: float = boss.boss.hp
	for tick in 120:
		boss.mob.step(boss, 1.0 / 60.0)
	check(hp_before - boss.boss.hp > float(spec.damage) * 0.9, "champion damages the Titan through the phase 1 plate (%.0f)" % (hp_before - boss.boss.hp))
	# Mob gate passes fill Overdrive while running.
	var fill := gate_sim([{"t": "mult", "v": 3}])
	fill.robot.overdrive = 0.0
	send(fill, 0.0, 20, 40.0)
	fill.step(0.1)
	fill.step(0.5)
	check(fill.robot.overdrive > 0.0, "gate gain fills Overdrive (%.1f)" % fill.robot.overdrive)

func _generated_tests() -> void:
	for level in [2, 3, 4, 5]:
		var sim := RunSim.new()
		sim.flag_overrides = {"mob_stream": true}
		sim.setup(level, 700 + level)
		var rows := sim.beats.filter(func(b): return b.type == "mob_gate")
		var part := sim.beats.filter(func(b): return b.get("generated", false) and b.has("options"))
		check(rows.size() == part.size(), "level %d: one mob row between each part gate pair plus one after the final choice (%d rows, %d part gates)" % [level, rows.size(), part.size()])
		var spacing := 999.0
		for row in rows:
			for gate in part:
				spacing = minf(spacing, absf(float(row.z) - float(gate.z)))
		check(spacing >= 35.0, "level %d: mob rows keep 35 m from part gates (%.0f)" % [level, spacing])
		check(rows.any(func(b): return b.get("moving", false)) and rows.all(func(b): return b.panels.size() >= 2), "level %d: some rows slide, all have at least two panels" % level)
		var same := RunSim.new()
		same.flag_overrides = {"mob_stream": true}
		same.setup(level, 700 + level)
		check(JSON.stringify(same.beats) == JSON.stringify(sim.beats), "level %d: generated mob rows are deterministic" % level)
		var off := RunSim.new()
		off.setup(level, 700 + level)
		check(not off.beats.any(func(b): return b.type == "mob_gate"), "level %d: no mob rows with the flag off" % level)
	var power2 := RunSim.new()
	power2.flag_overrides = {"mob_stream": true}
	power2.setup(2, 5)
	var power5 := RunSim.new()
	power5.flag_overrides = {"mob_stream": true}
	power5.setup(5, 5)
	var best := func(sim: RunSim) -> int:
		var top := 0
		for b in sim.beats.filter(func(x): return x.type == "mob_gate"):
			for panel in b.panels:
				if panel.t == "power":
					top = maxi(top, int(panel.v))
		return top
	check(best.call(power5) > best.call(power2) or best.call(power2) == 0, "power values scale with level")

func _stream_tests() -> void:
	var sim := RunSim.new()
	sim.flag_overrides = {"mob_stream": true, "mob_enemy_streams": true}
	sim.setup(1, 81)
	var streams := sim.beats.filter(func(b): return b.type == "enemy_stream")
	check(streams.size() == GameData.table("mob").enemy_streams.level1.size(), "level 1 enemy streams come from data")
	var peak := 0
	for tick in 4000:
		sim.step(1.0 / 60.0)
		peak = maxi(peak, sim.enemies.size())
		sim.events.clear()
	check(peak > 0 and peak <= 24, "enemy streams respect the enemy cap (%d)" % peak)
	var plain := RunSim.new()
	plain.flag_overrides = {"mob_stream": true}
	plain.setup(1, 81)
	check(not plain.beats.any(func(b): return b.type == "enemy_stream"), "no enemy streams without their flag")
	var generated := RunSim.new()
	generated.flag_overrides = {"mob_stream": true, "mob_enemy_streams": true}
	generated.setup(3, 81)
	check(generated.beats.filter(func(b): return b.type == "enemy_stream").size() == generated.beats.filter(func(b): return b.type == "mob_gate").size(), "generated levels get one stream per mob row")
