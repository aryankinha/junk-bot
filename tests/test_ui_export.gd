extends SceneTree
# Copy beside an extracted APK's project.binary; excluded from shipped APKs.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var expected := OS.get_cmdline_user_args().has("--v2")
	var game = load("res://src/view/Boot.tscn").instantiate()
	game.save.path = "user://ui_export_smoke.json"
	root.add_child(game)
	for frame in 4: await process_frame
	assert(not bool(GameData.flags().ui_v2), "packaged flag still defaults off")
	assert(game.ui_v2_enabled == expected, "review feature selects the intended HUD")
	if expected: assert(game.save.path == "user://ui_review_b.json", "preview uses an isolated save")
	print("UI APK SMOKE: ", "v2" if expected else "default", " booted; ui_v2=", game.ui_v2_enabled, "; save=", game.save.path)
	game.queue_free()
	for frame in 4: await process_frame
	quit()
