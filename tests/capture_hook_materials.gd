extends SceneTree
# Render-only fixtures: fixed level2/pose/camera/light for honest material and permanent-detail comparison.
# Coordinate graphics runs with the main agent. No sim, save, random reward or gameplay state is changed.
var portrait: MeshInstance3D
var title: Label
var subtitle: Label
var rows: Array = []
var output := "res://results/hook_materials"
const NAMES := ["SCRAP", "FIXED", "IRON", "METAL"]
func _initialize() -> void: call_deferred("run")
func capture(file_name: String, family: String, quality: int, stars: int, forge := 0.0) -> void:
	portrait.mesh = MeshFactory.hook_part(family, 2, quality, stars)
	portrait.set_instance_shader_parameter("tier", float(quality))
	portrait.set_instance_shader_parameter("forge", forge)
	portrait.set_instance_shader_parameter("ascending", 0.0)
	title.text = family.to_upper() + " / " + NAMES[quality - 1]
	subtitle.text = "LEVEL 2   ·   HANGAR TIER %d" % stars
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + file_name + ".png")
	rows.append({"file":file_name + ".png","family":family,"part_level":2,"run_material":quality,"hangar_tier":stars,"forge_progress":forge,"mesh_hash":hash(portrait.mesh.surface_get_arrays(0)),"surfaces":portrait.mesh.get_surface_count(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"fixture":true})
func run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(640,640); root.content_scale_size = Vector2i(640,640)
	root.msaa_3d = Viewport.MSAA_4X
	var scene := Node3D.new(); root.add_child(scene)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("273940")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("d5e1e5"); env.environment.ambient_light_energy = 0.8
	scene.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-38,-25,0); sun.light_color = Color("fff3df"); sun.light_energy = 1.0; scene.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-22,140,0); fill.light_color = Color("b5d7e5"); fill.light_energy = 0.6; scene.add_child(fill)
	portrait = MeshInstance3D.new(); scene.add_child(portrait)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 1.65
	camera.position = Vector3(1.2,1.05,-1.7); scene.add_child(camera); camera.look_at(Vector3(0,0.12,-0.2)); camera.current = true
	var layer := CanvasLayer.new(); root.add_child(layer)
	title = Label.new(); title.add_theme_font_override("font",load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf")); title.add_theme_font_size_override("font_size",42); title.position = Vector2(28,22); title.size = Vector2(584,60); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(title)
	subtitle = Label.new(); subtitle.add_theme_font_override("font",load("res://assets/fonts/barlow_Barlow-SemiBold.ttf")); subtitle.add_theme_font_size_override("font_size",26); subtitle.position = Vector2(24,574); subtitle.size = Vector2(592,40); subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; layer.add_child(subtitle)
	for family in ["cannon","rocket","flame"]:
		for quality in range(1,5): await capture("%s_%s" % [family,NAMES[quality - 1].to_lower()],family,quality,1)
		for stars in range(1,6): await capture("%s_permanent_%d" % [family,stars],family,1,stars)
	for quality in range(2,5): await capture("forge_" + NAMES[quality - 1].to_lower(),"cannon",quality,1,0.5)
	# The same shell/core geometry is drawn at each quality; only shader state and the8% scale change.
	portrait.mesh = MeshFactory.hook_drone()
	for quality in range(1,5):
		# A regular MeshInstance uses its own quality uniform; the production MultiMesh uses custom data.
		portrait.material_override = MeshFactory.hook_palette(); portrait.set_instance_shader_parameter("tier",float(quality)); portrait.set_instance_shader_parameter("forge",0.0)
		portrait.scale = Vector3.ONE * (1.0 + 0.08 * (quality - 1)); title.text = "DRONE / " + NAMES[quality - 1]; subtitle.text = "BLUE CORE AND TRAIL AT EVERY TIER"
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/drone_" + NAMES[quality - 1].to_lower() + ".png")
	FileAccess.open(output + "/inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"weapon_captures":rows,"extra_drone_captures":4,"camera":"fixed orthographic1.65; pos(1.2,1.05,-1.7), target(0,.12,-.2)","lighting":"same warm key/cool fill for every portrait","level_shape":"same level2 throughout; run quality differs from permanent Hangar tier"},"  "))
	print("HOOK MATERIAL PORTRAITS: ",rows.size()," weapon/forge +4 drone captures completed")
	scene.queue_free(); layer.queue_free(); for frame in 4: await process_frame
	quit()
