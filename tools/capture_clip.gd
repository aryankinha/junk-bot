extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scenario := "boss"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scenario = arg.get_slice("=", 1)
	var game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://capture_save.json"
	game.save.data = game.save.defaults()
	game.start_run(false)
	game.paused = true
	var controller_mode := "no_dodge" if scenario == "part_loss" else "perfect"
	game.bot = BotController.new(20261031, controller_mode, 0)
	var target_time := -1.0
	if scenario == "part_loss":
		var probe := RunSim.new()
		probe.setup(1, 20261031)
		var controller := BotController.new(20261031, controller_mode, 0)
		for i in 18000:
			controller.control(probe)
			probe.step(1.0 / 60)
			for event in probe.events:
				if event.t == "part_broken":
					target_time = maxf(0, probe.t - 1)
			probe.events.clear()
			if target_time >= 0:
				break
	for i in (0 if scenario == "first" else 18000):
		game.bot.control(game.sim)
		game.sim.step(1.0 / 60)
		game.sim.events.clear()
		if (scenario == "boss" and game.sim.state == "boss") or (scenario == "part_loss" and game.sim.t >= target_time):
			break
	game.world.sync(game.sim, 0)
	game._update_hud()
	game.paused = false
	var end_runtime: float = game.runtime + (20 if scenario == "boss" else (12 if scenario == "first" else 6))
	var guard := 0
	while game.runtime < end_runtime and guard < 10000:
		guard += 1
		await RenderingServer.frame_post_draw
		await process_frame
	game.queue_free()
	for i in 8:
		await process_frame
	quit()
