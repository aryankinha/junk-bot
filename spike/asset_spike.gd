extends Node3D
var runtime := 0.0
var saved := false
func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("dfbd87")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.9
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 33
	camera.position = Vector3(9, 22, 20)
	add_child(camera)
	camera.look_at(Vector3(0, 0, -9))
	var index := 0
	for id in GameData.table("parts"):
		for level in range(1, 4):
			var model := RobotBuilder.new()
			model.position = Vector3((level - 2) * 3.2, 0, -index * 2.7)
			add_child(model)
			var robot := RobotState.new()
			robot.add_part(id, null, level)
			model.sync(robot, false)
			var label := Label3D.new()
			label.text = "%s · %d" % [str(id).to_upper(), level]
			label.font_size = 56
			label.pixel_size = 0.009
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = model.position + Vector3(0, 2.1, 0)
			add_child(label)
		index += 1
func _process(dt: float) -> void:
	runtime += dt
	if runtime > 2 and not saved:
		saved = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://results/asset_spike.png")
	if runtime > 3:
		get_tree().quit()
