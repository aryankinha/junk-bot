extends SceneTree
# Screenshots for the interactivity report. Non-headless:
#   Godot --path . --script res://tests/shot_interactivity.gd -- --scenario=salvage --flags={...} --out=name
# Scenarios: first_gate (z just before gate 1), charged_gate, salvage, evolution.
var game
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scenario := "first_gate"
	var out := "shot"
	var flags: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--flags="):
			flags = JSON.parse_string(arg.substr(8))
	game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://shot_save.json"
	game.save.data = game.save.defaults()
	game.flag_overrides = flags
	game.start_run(false)
	game.paused = true
	print("flags ", game.sim.flags.aim_mode, " ", game.sim.flags.guarded_salvage, " salvage beats ", game.sim.beats.filter(func(b): return b.type == "salvage").size())
	var bot := AimBot.new(20261031, 0.0)
	var done := false
	for i in 20000:
		bot.control(game.sim)
		game.sim.step(1.0 / 60)
		game.sim.events.clear()
		match scenario:
			"first_gate":
				done = game.sim.z >= 80.0 - 36.0
			"charged_gate":
				var gate: Dictionary = game.sim.next_gate()
				done = not gate.is_empty() and gate.has("charge") and gate.charge.any(func(c): return c >= 1.2) and float(gate.z) - game.sim.z < 14
			"salvage":
				done = game.sim.enemies.any(func(e): return e.get("salvage", "") == "blast" and float(e.z) - game.sim.z < 33 and e.hp > 0)
			"moving":
				var next_gate: Dictionary = game.sim.next_gate()
				done = not next_gate.is_empty() and next_gate.get("moving", false) and float(next_gate.z) - game.sim.z < 26
			"aim":
				done = game.sim.aim_target != null and float(game.sim.aim_target.z) - game.sim.z < 14 and game.sim.z > 100
			"evolution":
				done = game.sim.has_method("evolution_active") and game.sim.evolution_active() and game.sim.bullets.size() > 6
		if done or game.sim.state in ["won", "lost"]:
			break
	game.world.sync(game.sim, 0.016)
	game._update_hud()
	for n in 20:
		await process_frame
		game.world.sync(game.sim, 0.016)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://results/interactivity_%s.png" % out)
	print("captured %s at z=%.1f t=%.1f done=%s" % [scenario, game.sim.z, game.sim.t, done])
	quit()
