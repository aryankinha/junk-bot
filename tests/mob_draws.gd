extends SceneTree
# Draw-call peak finder: plays a bot run in the real view and prints the worst frames with what was on screen.
# Non-headless: Godot --path . --script res://tests/mob_draws.gd -- --flags={...}
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var flags: Dictionary = {}
	var steps := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--flags="):
			flags = JSON.parse_string(arg.substr(8))
		elif arg == "--fast":
			steps = 6 # draw-state diagnosis only; never use accelerated frame times as a perf result
	var game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://shot_save.json"
	game.save.data = game.save.defaults()
	game.flag_overrides = flags
	game.start_run(false)
	game.paused = true
	var bot = MobBot.new(20261031, 0.15)
	var rows: Array = []
	for i in 6000:
		for k in steps:
			bot.control(game.sim)
			game.sim.step(1.0 / 60)
		game.runtime = game.sim.t
		game._events()
		game.sim.events.clear()
		game.world.sync(game.sim, float(steps) / 60)
		if game.sim.mob != null:
			var expected: int = game.sim.enemies.filter(func(e): return e.id == "scrapper").size()
			assert(game.world.crowd_scrappers.multimesh.visible_instance_count == expected)
		game._update_hud()
		await process_frame
		if steps > 1 and i == 216:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://results/mob_resume_crowd_batch.png")
		var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var w = game.world
		var pops := 0
		for l in w.popups:
			pops += int(l.visible)
		var gates_visible := 0
		for slot in w.mob_gate_nodes:
			gates_visible += int(slot.root.visible)
		rows.append([draws, i, snappedf(game.sim.z, 1), game.sim.enemies.size(), game.sim.mob.n if game.sim.mob != null else 0, pops, gates_visible, int(w.gate_root.visible), w.fx_items.size()])
		if game.sim.state in ["won", "lost"]:
			break
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("draws,frame,z,enemies,drones,popups,mobgates,partgate,fx")
	for r in rows.slice(0, 12):
		print(r)
	var total := 0
	for r in rows:
		total += r[0]
	print("mean ", total / rows.size(), " frames ", rows.size())
	quit()
