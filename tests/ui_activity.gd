extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var v2 := OS.get_cmdline_user_args().has("--v2")
	var game = load("res://src/view/Boot.tscn").instantiate()
	game.flag_overrides = {"ui_v2": v2, "mob_stream": true}
	game.capture = true
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
		bot.control(game.sim)
		# Proxy for the bot's steering gesture; uses unchanged sim.drag/target logic.
		if v2 and absf(game.sim.target_x - old_x) > 0.01: game.ui_v2.steering(game)
		game.sim.step(1.0 / 60)
		var second := int(game.sim.t)
		if not per_second.has(second): per_second[second] = {}
		for event in game.sim.events:
			per_second[second][event.t] = int(per_second[second].get(event.t, 0)) + 1
		input_frames += int(absf(game.sim.x - old_x) > 0.001)
		consequence_frames += int(not game.sim.bullets.is_empty() or game.sim.mob.n > 0 or not game.sim.events.is_empty())
		var expected: Dictionary = {}
		var counts: Dictionary = game.ui_v2.feedback_counts.duplicate() if v2 else {}
		if v2:
			for e in game.sim.events:
				if e.t in ["scrap", "weapon_fire", "enemy_death", "part_attached", "gate_choice", "mob_gate_pass", "player_hit", "special_used"]:
					expected[e.t] = int(expected.get(e.t, 0)) + 1
		game.runtime = game.sim.t
		game._events(); game.world.sync(game.sim, 1.0 / 60); game._tick_run_hud(1.0 / 60)
		if v2:
			for action in expected: assert(int(game.ui_v2.feedback_counts.get(action, 0)) - int(counts.get(action, 0)) >= expected[action], "same-frame bot response " + action)
		if game.get("ui_v2_enabled") and game.get("ui_v2") != null: game.ui_v2.tick(game, 1.0 / 60)
		if frame % 30 == 0:
			# Let Control containers settle before measuring their painted rectangles.
			for settle_frame in 4: await process_frame
			var sample: Dictionary = metrics.measure(game)
			sample.erase("inventory"); sample["sim_t"] = game.sim.t; samples.append(sample)
		if frame % 300 == 0: await process_frame
	var out := {"seconds": 45, "simulated_frames": 2700, "direct_steering_response_frames": input_frames, "consequence_motion_frames": consequence_frames, "input_response_fps": float(input_frames) / 45, "consequence_motion_fps": float(consequence_frames) / 45, "events_per_second": per_second, "clutter_samples": samples}
	if v2:
		out["feedback_counts"] = game.ui_v2.feedback_counts
		out["steering_proxy"] = "bot target differs from current x; not human touch timing"
		for action in ["scrap", "weapon_fire", "enemy_death", "part_attached", "gate_choice", "mob_gate_pass", "steer"]:
			assert(int(game.ui_v2.feedback_counts.get(action, 0)) > 0, "bot action receives same-frame feedback: " + action)
		for sample in samples:
			assert(sample.hud_popup_area_pct <= 22 and sample.popups <= 3 and sample.hero_events <= 1 and sample.full_screen_effects <= 1, "bot clutter budget")
	FileAccess.open("res://results/ui_activity_%s.json" % ("after" if v2 else "before"), FileAccess.WRITE).store_string(JSON.stringify(out, "  "))
	print("UI ACTIVITY completed: ", input_frames, " direct input response frames, ", consequence_frames, " consequence frames")
	game.queue_free()
	for frame in 4: await process_frame
	quit()
