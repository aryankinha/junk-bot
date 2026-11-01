extends SceneTree
# Same fixed-step fixture for before/after captures. Does not alter a player's save.
var game
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	var label := "before" if baseline else "after"
	var v2 := OS.get_cmdline_user_args().has("--v2")
	if v2: label = "ui_v2"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.substr(8); assert(label.is_valid_filename())
	game = load("res://src/view/Boot.tscn").instantiate()
	game.capture = true
	root.add_child(game)
	game.capture = true
	game.save.path = "user://visual_focus_test.json"
	game.save.data = game.save.defaults()
	game.save.data.tutorial_done = true
	var evidence: Dictionary = {}
	for mob_mode in [false, true]:
		game.flag_overrides = {"mob_stream": mob_mode, "ui_v2": v2}
		game.start_run(false)
		game.paused = true
		game.bot = null
		var sim: RunSim = game.sim
		var bot = MobBot.new(20261031, 0.15) if mob_mode else AimBot.new(20261031, 0.15)
		for tick in 5000:
			bot.control(sim)
			sim.step(1.0 / 60)
			game.runtime = sim.t
			game._events()
			game.world.sync(sim, 1.0 / 60)
			game.toast_timer -= 1.0 / 60
			if game.toast_timer <= 0:
				game.toast_label.text = ""
			if sim.z >= 195.0:
				break
		game._update_hud()
		# Compare normal lighting, independently of the transient damage flash at this fixture tick.
		game.flash.color.a = 0.0
		game.camera.position = Vector3(0, 7.8, 9.5)
		game.camera.look_at(Vector3(0, 0.7, -7.5))
		game.camera.fov = 62.0
		game.camera.h_offset = 0
		game.camera.v_offset = 0
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var mode := "mob" if mob_mode else "normal"
		root.get_texture().get_image().save_png("res://results/focus_%s_%s.png" % [label, mode])
		var scenery_count := 0
		for batch in game.world.scenery_sets:
			scenery_count += batch.multimesh.visible_instance_count
		evidence[mode] = {"state": [sim.t, sim.z, sim.x, sim.robot.hp, sim.robot.scrap, sim.robot.parts], "scenery_instances": scenery_count, "litter": game.world.stripes.multimesh.visible_instance_count, "skids": game.world.skids.multimesh.visible_instance_count}
		if not baseline:
			assert(scenery_count == 12)
			assert(game.world.stripes.multimesh.visible_instance_count == 0 and game.world.skids.multimesh.visible_instance_count == 0)
	# Isolate reward feedback from actual damage or enemy attacks.
	game.start_run(false)
	game.paused = true
	game.sim.events.clear()
	game.sim.robot.add_part("cannon", game.sim)
	game.sim.emit("scrap", {"amount": 1, "chain": 5, "gold": false})
	game.sim.emit("scrap", {"amount": 5, "chain": 10, "gold": true})
	game.sim.emit("stage_up", {"stage": 2})
	game.sim.emit("gate_level_up", {"bonus": 1})
	game.sim.emit("mob_gate_pass", {"ord": 0, "lane": 0, "type": "mult", "v": 2, "gain": 4.0, "count": 3, "x": 0.0, "z": 20.0})
	game._events()
	if not baseline:
		var initial: Transform3D = game.camera.transform
		game.sim.beats.clear()
		game.sim.enemies.clear()
		game.sim.hazards.clear()
		game.sim.boss_z = 100000.0
		game.sim.next_scrap_z = 100000.0
		game.perf.enabled = false
		game.paused = false
		for frame in 120:
			var before_t: float = game.sim.t
			game.sim.collect_scrap(1)
			game.sim.target_x = 2.0 if frame % 40 < 20 else -2.0
			if frame % 40 == 0:
				game.sim.robot.add_part("cannon", game.sim)
			game._process(1.0 / 60)
			assert(is_equal_approx(game.sim.t - before_t, 1.0 / 60), "reward feedback cannot pause simulation")
			assert(game.camera.transform.is_equal_approx(initial), "routine rewards cannot move the camera")
			assert(game.camera.fov == 62.0 and is_zero_approx(game.camera.h_offset) and is_zero_approx(game.camera.v_offset))
		game.paused = true
		assert(not game.world.popups.any(func(p): return p.visible and (p.text.begins_with("GOLD") or p.text.contains("CANNON"))))
		evidence["reward_frames_checked"] = 120
		evidence["camera_fov"] = game.camera.fov
	FileAccess.open("res://results/focus_%s.json" % label, FileAccess.WRITE).store_string(JSON.stringify(evidence, "  "))
	print("VISUAL FOCUS ", label, ": ", evidence)
	game.queue_free()
	for frame in 5:
		await process_frame
	quit()
