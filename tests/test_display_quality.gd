extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://src/view/Boot.tscn").instantiate()
	root.add_child(game)
	game.capture = true
	game.save.path = "user://display_quality_test.json"
	game.save.data = game.save.defaults()
	game.start_run(false)
	game.paused = true
	root.size = Vector2i(720,1280)
	game.show_hangar()
	for i in 15: await process_frame
	var preview: SubViewport = game.hangar_model.get_viewport()
	assert(root.msaa_3d == Viewport.MSAA_4X)
	assert(preview.msaa_3d == Viewport.MSAA_4X)
	assert(ProjectSettings.get_setting("display/window/dpi/allow_hidpi"))
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	captured.save_png("res://results/mac_quality_home.png")
	var texture: ImageTexture = await game.capture_build()
	assert(texture.get_size() == Vector2(1200,1200))
	texture.get_image().save_png("res://results/mac_quality_portrait.png")
	var report := {"root_msaa":root.msaa_3d,"preview_msaa":preview.msaa_3d,"captured_image":str(captured.get_size()),"surface_after_os_resize":str(root.get_texture().get_size()),"screen_scale":DisplayServer.screen_get_scale(),"portrait":str(texture.get_size()),"hidpi":true,"checks":"passed"}
	FileAccess.open("res://results/mac_quality_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.queue_free()
	for i in 10: await process_frame
	quit()
