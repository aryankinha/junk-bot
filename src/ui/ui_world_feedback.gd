extends Node3D
# Fixed pools: four local rings, three gate-choice plates, one aim arrow and one weak-point ring.
var rings: MultiMeshInstance3D
var plates: MultiMeshInstance3D
var aim: MeshInstance3D
var weakpoint: MeshInstance3D
var danger_material: ShaderMaterial
var timers := PackedFloat32Array([0, 0, 0, 0])
var positions := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
var last_start := PackedFloat64Array([-10, -10, -10, -10])
var choice_time := 0.0
var choice_z := 0.0
var choice_side := 0
var choice_count := 2
var clock := 0.0
var reduced := false
var flash_limit := 3
var duck := false
var mob_pulses: Dictionary = {}
var optional_starts := 0

func _ready() -> void:
	var mesh := TorusMesh.new(); mesh.inner_radius = 0.75; mesh.outer_radius = 1.0; mesh.rings = 20; mesh.ring_segments = 5; mesh.material = material(Color.WHITE)
	rings = batch(mesh, 4)
	var pad := BoxMesh.new(); pad.size = Vector3.ONE; pad.material = material(Color.WHITE)
	plates = batch(pad, 3)
	aim = MeshInstance3D.new(); aim.mesh = MeshFactory.merged([MeshFactory.box(Vector3(0.08, 0.02, 1.3), Vector3(0, 0, 0), Color.WHITE), MeshFactory.box(Vector3(0.08, 0.02, 0.6), Vector3(-0.18, 0, -0.6), Color.WHITE, Vector3(0, -0.65, 0)), MeshFactory.box(Vector3(0.08, 0.02, 0.6), Vector3(0.18, 0, -0.6), Color.WHITE, Vector3(0, 0.65, 0))], true); aim.material_override = material(Color(Color("50b9df"), 0.3)); add_child(aim)
	weakpoint = MeshInstance3D.new(); weakpoint.mesh = mesh; weakpoint.material_override = material(Color(Color("43b975"), 0.8)); weakpoint.rotation.x = PI / 2; weakpoint.visible = false; add_child(weakpoint)
	var shader := Shader.new(); shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float travel = 0.0;
varying vec2 ground;
void vertex() { ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
 float stripe = step(0.54, fract((ground.x + ground.y - travel) * 1.3));
 ALBEDO = mix(vec3(0.12, 0.14, 0.15), vec3(0.58, 0.12, 0.10), stripe);
}
"""
	danger_material = ShaderMaterial.new(); danger_material.shader = shader

func material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new(); value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; value.vertex_color_use_as_albedo = true; value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; value.albedo_color = color; value.cull_mode = BaseMaterial3D.CULL_DISABLED
	return value

func batch(mesh: Mesh, capacity: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new(); node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D; node.multimesh.use_colors = true; node.multimesh.mesh = mesh; node.multimesh.instance_count = capacity; node.multimesh.visible_instance_count = 0; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(node)
	return node

func reset() -> void:
	timers.fill(0); choice_time = 0; mob_pulses.clear(); optional_starts = 0
	if rings != null: rings.multimesh.visible_instance_count = 0; plates.multimesh.visible_instance_count = 0

func ring(at: Vector3, color: Color, sim_z: float) -> void:
	if reduced or flash_limit <= 0: return
	for i in 4:
		if timers[i] <= 0 and clock - last_start[i] >= 1.0 / flash_limit:
			positions[i] = Vector3(at.x, at.y, sim_z - at.z); colors[i] = color; timers[i] = 0.38; last_start[i] = clock; optional_starts += 1
			return

func confirm(side: int, count: int, z: float) -> void:
	choice_side = side; choice_count = clampi(count, 1, 3); choice_z = z; choice_time = 0.5

func mob_pass(event: Dictionary) -> void:
	mob_pulses[int(event.ord)] = {"until": clock + 0.35, "lane": int(event.lane), "count": int(event.count), "value": int(event.v), "type": str(event.type)}
	# At most the two visible gate slots need pulse history.
	if mob_pulses.size() > 4:
		var oldest = mob_pulses.keys()[0]; mob_pulses.erase(oldest)

func sync(world, sim: RunSim, delta: float) -> void:
	clock += delta
	choice_time = maxf(0, choice_time - delta)
	var n := 0
	for i in 4:
		timers[i] = maxf(0, timers[i] - delta)
		if timers[i] <= 0 or reduced: continue
		var u := timers[i] / 0.38
		var point := Vector3(positions[i].x, positions[i].y, sim.z - positions[i].z)
		var radius := 0.25 + (1 - u) * 0.7
		rings.multimesh.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * radius), point))
		var color := colors[i]; color.a = u * (0.3 if duck else 0.7); rings.multimesh.set_instance_color(n, color); n += 1
	rings.multimesh.visible_instance_count = n
	plates.multimesh.visible_instance_count = choice_count if choice_time > 0 else 0
	for i in plates.multimesh.visible_instance_count:
		var width := 6.8 / choice_count
		plates.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(width * 0.84, 0.035, 1.0)), Vector3(-3.4 + width * (i + 0.5), 0.045, sim.z - choice_z)))
		var color := Color("43b975") if i == choice_side else Color("55605c"); color.a = choice_time * (1.5 if i == choice_side else 0.4); plates.multimesh.set_instance_color(i, color)
	aim.visible = sim.state == "running" and (sim._lane_aim() or sim.aim_target != null)
	aim.position = Vector3(sim.x, 0.04, -3.0)
	aim.rotation.y = 0.0
	if sim.aim_target != null and not sim._lane_aim(): aim.rotation.y = -atan2(float(sim.aim_target.x) - sim.x, maxf(1, float(sim.aim_target.z) - sim.z))
	weakpoint.visible = sim.boss != null and sim.state == "boss" and (sim.boss.arm_hp > 0 or sim.boss.phase >= 2 or sim.exposed_time > 0)
	if weakpoint.visible: weakpoint.position = world.boss_arm.position + world.boss_root.position if sim.boss.arm_hp > 0 else world.boss_core.position + world.boss_root.position
	danger_material.set_shader_parameter("travel", 0.0 if reduced else clock * 0.25)
