extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var v2 := OS.get_cmdline_user_args().has("--v2")
	var game = load("res://src/view/Boot.tscn").instantiate()
	game.flag_overrides = {"ui_v2": v2, "mob_stream": true}
	root.add_child(game)
	game.set_process(false)
	game.capture = true; game.save.path = "user://ui_activity.json"; game.save.data = game.save.defaults()
	game.start_run(false); game.bot = null; game.paused = false
	var bot := MobBot.new(20261031, 0.15)
	var metrics = load("res://tests/ui_metrics.gd")
	var per_second: Dictionary = {}; var samples: Array = []
	var input_frames := 0; var consequence_frames := 0
	for frame in 2700:
		var old_x: float = game.sim.x
		bot.control(game.sim); game.sim.step(1.0 / 60)
		var second := int(game.sim.t)
		if not per_second.has(second): per_second[second] = {}
		for event in game.sim.events:
			per_second[second][event.t] = int(per_second[second].get(event.t, 0)) + 1
		input_frames += int(absf(game.sim.x - old_x) > 0.001)
		consequence_frames += int(not game.sim.bullets.is_empty() or game.sim.mob.n > 0 or not game.sim.events.is_empty())
		game.runtime = game.sim.t
		game._events(); game.world.sync(game.sim, 1.0 / 60); game._update_hud()
		if game.get("ui_v2_enabled") and game.get("ui_v2") != null: game.ui_v2.tick(game, 1.0 / 60)
		game.toast_timer -= 1.0 / 60
		if game.toast_timer <= 0: game.toast_label.text = ""
		if frame % 30 == 0:
			var sample: Dictionary = metrics.measure(game)
			sample.erase("inventory"); sample["sim_t"] = game.sim.t; samples.append(sample)
		if frame % 300 == 0: await process_frame
	var out := {"seconds": 45, "simulated_frames": 2700, "direct_steering_response_frames": input_frames, "consequence_motion_frames": consequence_frames, "input_response_fps": float(input_frames) / 45, "consequence_motion_fps": float(consequence_frames) / 45, "events_per_second": per_second, "clutter_samples": samples}
	FileAccess.open("res://results/ui_activity_%s.json" % ("after" if v2 else "before"), FileAccess.WRITE).store_string(JSON.stringify(out, "  "))
	print("UI ACTIVITY completed: ", input_frames, " direct input response frames, ", consequence_frames, " consequence frames")
	game.queue_free()
	for frame in 4: await process_frame
	quit()
