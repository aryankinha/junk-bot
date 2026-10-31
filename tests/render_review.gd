extends SceneTree
var game
var measurements: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://results/review_%s.png" % name
	root.get_viewport().get_texture().get_image().save_png(path)
	measurements[name] = {"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	print("Captured " + name)
func run() -> void:
	game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://render_review_save.json"
	game.save.data = game.save.defaults()
	game.start_run(false)
	game.paused = true
	var bot := BotController.new(20261031, "perfect", 0)
	var captured_battle := false
	var captured_monster := false
	var captured_gate := false
	for i in 15000:
		bot.control(game.sim)
		game.sim.step(1.0 / 60)
		game.sim.events.clear()
		if not captured_gate and game.sim.z > 85:
			captured_gate = true
			game.world.sync(game.sim, 0.016)
			game._update_hud()
			await shot("first_attach")
		if not captured_battle and game.sim.robot.stage() == 2:
			captured_battle = true
			game.world.sync(game.sim, 0.016)
			game._update_hud()
			await shot("battle")
		if not captured_monster and game.sim.robot.stage() == 3:
			captured_monster = true
			game.world.sync(game.sim, 0.016)
			game._update_hud()
			await shot("monster")
		if game.sim.state == "boss":
			break
	game.camera.position = Vector3(0, 8.5, 11)
	game.camera.look_at(Vector3(0, 1, -8))
	game.world.sync(game.sim, 0.016)
	game._update_hud()
	await shot("boss_plated")
	game.sim.boss.roar = 0
	game.sim.boss.apply_hit("rocket", game.sim.boss.max_hp * 0.36, game.sim)
	game.sim.boss.roar = 0
	game.sim.boss._start_attack(game.sim)
	game.world.sync(game.sim, 0.016)
	game._update_hud()
	await shot("boss_grabber")
	game.sim.boss.apply_hit("rocket", game.sim.boss.max_hp * 0.36, game.sim)
	game.sim.boss.roar = 0
	game.sim.boss._start_attack(game.sim)
	game.world.sync(game.sim, 0.016)
	game._update_hud()
	await shot("boss_enraged")
	game.sim.boss.apply_hit("rocket", game.sim.boss.max_hp, game.sim)
	game.world.sync(game.sim, 0.016)
	await game._finish_run()
	await shot("result")
	game.show_hangar()
	await shot("hangar")
	game.show_hangar("codex")
	await shot("codex")
	game.show_settings()
	await shot("settings")
	game.start_run(false)
	game.paused = true
	game.sim.spawn_pack("scrapper", 20, 12)
	for i in 40:
		game.sim.bullets.append({"x": -3 + (i % 8) * 0.8, "z": game.sim.z + 2 + float(i / 8) * 2, "tx": 0, "tz": 24, "type": "projectile", "damage": 14, "speed": 36, "radius": 0, "ttl": 2})
	game.world.sync(game.sim, 0.016)
	await shot("stress")
	measurements.monster_reached = captured_monster
	var file := FileAccess.open("res://results/render_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "  "))
	game.queue_free()
	await process_frame
	MeshFactory.cache.clear()
	MeshFactory.material = null
	quit()
