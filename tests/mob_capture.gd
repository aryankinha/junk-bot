extends SceneTree
# Reproducible rendered evidence. First multiplication is a natural run; later scenes use declared fixtures.
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://mob_evidence_save.json"
	game.save.data = game.save.defaults()
	game.flag_overrides = {"mob_stream": true}
	game.start_run(false)
	game.paused = true
	var sim: RunSim = game.sim
	var bot := MobBot.new(20261031)
	var found := false
	for tick in 1800:
		bot.control(sim)
		sim.step(1.0 / 60)
		found = sim.events.any(func(e): return e.t == "mob_gate_pass" and e.type == "mult" and float(e.gain) > 0)
		game._events()
		sim.events.clear()
		if found:
			break
	assert(found, "natural first multiplication must be captured")
	await shot("first_multiply")
	var first_t := sim.mob.first_multiply_t
	# A loaded build at a real authored x3 row; enemies removed to expose the complete multiplied stream.
	game.start_run(false)
	game.paused = true
	sim = game.sim
	sim.robot.add_part("cannon", sim, 3)
	sim.robot.add_part("rocket", sim, 3)
	sim.events.clear()
	game.save.data.tutorial_done = true
	sim.beats = sim.beats.filter(func(b): return b.type == "mob_gate" and is_equal_approx(float(b.z), 150.0))
	sim.next_beat = sim.beats.size()
	sim.mob.register_gates(sim.beats)
	sim.z = 132.0
	sim.x = -1.7
	sim.target_x = -1.7
	sim.special_time = 5.0
	sim.mob.prev_x = sim.x
	for tick in 45:
		sim.t += 1.0 / 60
		sim._combat(1.0 / 60)
	game._events()
	sim.events.clear()
	await shot("x3_stream")
	sim.robot.overdrive = 100.0
	sim.tap_special()
	for tick in 12:
		sim.t += 1.0 / 60
		sim.mob.step(sim, 1.0 / 60)
	game._events()
	sim.events.clear()
	await shot("champion_launch")
	# Keep the multiplied volley from the x3 fixture and move the boss plane ahead of it.
	sim.state = "boss"
	sim.boss = BossSim.new()
	sim.boss.setup(1, 0)
	sim.boss.roar = 0.0
	sim.boss.max_hp = 10000.0
	sim.boss.hp = 10000.0
	sim.z = 145.0
	var hp_before := sim.boss.hp
	for tick in 120:
		sim.t += 1.0 / 60
		sim.mob.step(sim, 1.0 / 60)
		if sim.boss.hp < hp_before:
			break
	assert(sim.boss.hp < hp_before, "multiplied volley must hit the boss")
	game._events()
	sim.events.clear()
	await shot("boss_multiplied_hit")
	FileAccess.open("res://results/mob_resume_capture.json", FileAccess.WRITE).store_string(JSON.stringify({"first_multiply_t": first_t, "boss_fixture_damage": hp_before - sim.boss.hp, "fixtures": ["x3_stream: cannon L3, rocket L3, enemies removed", "champion_launch: full Overdrive supplied", "boss_multiplied_hit: same multiplied volley, boss HP 10000, roar skipped"]}, "  "))
	quit()

func shot(label: String) -> void:
	game.world.player.sync(game.sim.robot, false)
	game.world.sync(game.sim, 0.0)
	game._update_hud()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://results/mob_resume_%s.png" % label
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("captured ", label, " t=", game.sim.t, " drones=", game.sim.mob.n)
