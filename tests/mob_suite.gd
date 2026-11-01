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
	check(bend.mob.vx[0] > 1.5, "drones inherit lateral velocity (vx %.2f)" % bend.mob.vx[0])
	var flag_off := RunSim.new()
	flag_off.setup(1, 9)
	check(flag_off.mob == null, "no mob state with the flag off")
