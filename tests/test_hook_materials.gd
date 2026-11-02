extends SceneTree
# Headless visual-state/geometry contract. Pixel appearance is verified separately in portraits.
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func fingerprint(mesh: ArrayMesh) -> int:
	return hash(mesh.surface_get_arrays(0))
func blue_core(mesh: ArrayMesh) -> int:
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var found := 0
	for color in colors:
		if color.a < 0.1 and color.b > color.r + 0.3 and color.b > color.g + 0.1: found += 1
	return found
func run() -> void:
	GameData.load_all()
	var states: Dictionary = {}
	for family in ["cannon", "rocket", "flame"]:
		var variants: Array = []
		for tier in range(1, 5):
			var mesh := MeshFactory.hook_part(family, 2, tier, 1)
			var signature := fingerprint(mesh)
			check(not variants.has(signature), "each material has distinct geometry: %s %d" % [family, tier]); variants.append(signature)
			check(mesh.get_surface_count() == 1, "quality artifacts merged into one surface")
			check(blue_core(mesh) > 0, "protected blue energy core: %s %d" % [family, tier])
			check(mesh.surface_get_material(0) == MeshFactory.hook_palette(), "shared material across quality tiers")
		states[family] = variants
		var permanent: Array = []
		for stars in range(1, 6):
			var signature := fingerprint(MeshFactory.hook_part(family, 2, 1, stars))
			check(not permanent.has(signature), "permanent tier artifact set differs: %s %d" % [family, stars]); permanent.append(signature)
	check(MeshFactory.hook_drone().get_surface_count() == 1 and blue_core(MeshFactory.hook_drone()) > 0, "one-surface drone has protected core/trail")
	check(MeshFactory.hook_drone_palette().shader.code.contains("INSTANCE_CUSTOM.r") and not MeshFactory.hook_drone_palette().shader.code.contains("INSTANCE_COLOR"), "crowd quality comes from custom tier, never recolors blue core")
	var rig := RobotBuilder.new(); root.add_child(rig); rig.set_process(false)
	var robot := RobotState.new(); robot.add_part("cannon", null, 2)
	rig.sync(robot, false)
	check(rig.attachments.cannon.mesh == MeshFactory.part("cannon", 2), "default-off uses exact legacy cached mesh")
	rig.hook_materials_enabled = true
	for tier in range(1, 5):
		rig.material_levels.cannon = tier; rig.sync(robot, false)
		check(rig.attachments.cannon.mesh == MeshFactory.hook_part("cannon", 2, tier, 1), "same rig changes material geometry on quality change")
		check(is_equal_approx(float(rig.attachments.cannon.get_instance_shader_parameter("tier")), tier), "instance hardware uniform matches run tier")
	rig.material_ascending.cannon = 0.4; rig.sync(robot, false)
	check(is_equal_approx(float(rig.attachments.cannon.get_instance_shader_parameter("ascending")), 0.4), "ascend shimmer updates without mesh rebuild")
	rig.forge("cannon", 4); rig._process(0.1)
	check(rig.forge_time > 0 and float(rig.attachments.cannon.get_instance_shader_parameter("forge")) > 0, "forge begins on existing family")
	rig._process(0.6)
	check(rig.forge_time == 0 and is_zero_approx(float(rig.attachments.cannon.get_instance_shader_parameter("forge"))), "forge settles within0.55s")
	rig.forge("cannon", 4); rig.reduced_motion = true; rig._process(0)
	check(rig.forge_time == 0 and is_zero_approx(float(rig.attachments.cannon.get_instance_shader_parameter("forge"))), "Reduce Motion clears an active forge sweep")
	rig.hook_materials_enabled = false; rig.sync(robot, false)
	check(rig.attachments.cannon.mesh == MeshFactory.part("cannon", 2), "disabling material mode restores exact legacy mesh")
	# Full high-level builds in varied acquisition orders: bounded sideways footprint, no head/part penetration.
	rig.hook_materials_enabled = true
	var widest := 0.0
	for level in range(1,4):
		for order in 12:
			var full := RobotState.new()
			var ids: Array = GameData.table("parts").keys()
			ids = ids.slice(order % ids.size()) + ids.slice(0, order % ids.size())
			for id in ids: full.add_part(id, null, level)
			full.tiers = {"cannon":5,"rocket":5,"flame":5,"armour":5}
			rig.material_levels = {"cannon":4,"rocket":4,"flame":4}; rig.sync(full, false)
			var bounds := rig.visual_bounds(); widest = maxf(widest, bounds.size.x)
			check(bounds.size.x <= 7.4, "compact full build bounded laterally")
			var keys := rig.attachments.keys()
			for i in keys.size():
				var box := rig.attachment_bounds(keys[i])
				check(not box.intersects(AABB(Vector3(-0.9,1.05,-0.9),Vector3(1.8,1.75,1.8))), "hook head clearance: " + keys[i])
				if keys[i] in ["wheels","tracks"]: check(box.position.y >= 0, "movement stays above road")
				for j in range(i+1,keys.size()): check(not box.intersects(rig.attachment_bounds(keys[j])), "hook attachments clear %s/%s" % [keys[i],keys[j]])
	rig.hook_materials_enabled = false; rig.compact_layout = true
	var plain_full := RobotState.new()
	for id in GameData.table("parts"): plain_full.add_part(id, null, 3)
	rig.sync(plain_full, false)
	check(rig.visual_bounds().size.x <= 7.4, "clarity-only compact layout bounds full build")
	for id in rig.attachments:
		check(rig.attachments[id].mesh == MeshFactory.part(id, int(plain_full.parts[id])), "clarity-only layout preserves legacy hardware mesh " + id)
	var report := {"checks":checks,"failures":failures,"material_geometry_hashes":states,"widest_full_build":widest,"forge_seconds":rig.forge_duration,"blue_core_rgb":[MeshFactory.HOOK_BLUE.r,MeshFactory.HOOK_BLUE.g,MeshFactory.HOOK_BLUE.b],"gpu_pixels":"separate rendered portrait verification required"}
	FileAccess.open("res://results/hook_material_visual_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOOK MATERIAL VISUALS: %d checks, %d failures; max width %.3f" % [checks, failures.size(), widest])
	for failure in failures: printerr(failure)
	rig.queue_free(); for frame in 4: await process_frame
	quit(0 if failures.is_empty() else 1)
