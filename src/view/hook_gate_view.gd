extends Node3D
# Clarity-only presentation. One part gantry and at most two pooled stream rows.
var part := Node3D.new()
var part_key := ""
var road_material: ShaderMaterial
var slots: Array = []
var clock := 0.0
var numbers_at := -1.0
var metrics: Dictionary = {}
func _ready() -> void:
	add_child(part)
	var shader := Shader.new(); shader.code = """
shader_type spatial;
render_mode unshaded;
uniform float travel = 0.0;
varying vec2 ground;
varying vec3 tint;
void vertex() { ground = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; tint = pow(COLOR.rgb,vec3(2.2)); }
void fragment() {
 float inside = 1.0 - smoothstep(3.6,4.7,abs(ground.x));
 float seam = 1.0-smoothstep(0.08,0.2,abs(mod(ground.y-travel+6.0,12.0)-6.0));
 ALBEDO = tint * mix(vec3(0.9,0.8,0.68),vec3(0.48,0.54,0.62),inside) * (1.0-seam*inside*0.06);
}
"""
	road_material = ShaderMaterial.new(); road_material.shader = shader
	for row in 2:
		var node := Node3D.new(); add_child(node)
		slots.append({"root": node, "ord": -1, "labels": [], "previews": [], "rings": [], "key": ""})
func text3(text: String, at: Vector3, size: int) -> Label3D:
	var label := Label3D.new(); label.text = text; label.position = at; label.font_size = size; label.pixel_size = 0.0065
	label.font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf"); label.outline_size = 9; label.outline_modulate = Color("172128"); label.no_depth_test = false
	return label
func clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()
func build_part(gate: Dictionary, sim: RunSim) -> void:
	clear(part)
	if gate.is_empty(): return
	var options: Array = gate.get("options", []); var width := 6.8 / maxi(1, options.size()); var pieces: Array = []
	for i in options.size():
		var x: float = -3.4 + width * (i + 0.5)
		for side in [-1, 1]:
			pieces.append(MeshFactory.box(Vector3(0.24, 3.45, 0.38), Vector3(x + side * (width / 2 - 0.13), 1.65, 0), Color("647079")))
		pieces.append(MeshFactory.box(Vector3(width - 0.1, 1.18, 0.3), Vector3(x, 3.1, 0), Color("26343d")))
		pieces.append(MeshFactory.box(Vector3(width - 0.08, 0.18, 0.4), Vector3(x, 3.78, 0), Color("bbc3bc")))
		pieces.append(MeshFactory.box(Vector3(width - 0.12, 0.1, 0.7), Vector3(x, 0.06, 0), Color("43b975")))
		for side in [-1, 1]: pieces.append(MeshFactory.box(Vector3(0.18, 0.18, 0.35), Vector3(x + side * (width / 2 - 0.35), 3.45, 0.05), Color("dbc28e")))
		var name := GateGen.label(options[i]).to_upper().replace(" ", "\n")
		part.add_child(text3(name, Vector3(x, 3.08, 0.22), 96 if options.size() < 3 else 80))
		if options[i].kind == "part":
			var icon := MeshFactory.instance(MeshFactory.part(str(options[i].id), 1)); icon.position = Vector3(x, 1.45, 0); icon.scale = Vector3.ONE * 0.9; part.add_child(icon)
		else: part.add_child(text3(GateGen.description(options[i]), Vector3(x, 1.5, 0.1), 64))
	var frame := MeshFactory.instance(MeshFactory.merged(pieces, true)); part.add_child(frame)
func build_row(slot: Dictionary, gate: Dictionary) -> void:
	clear(slot.root); slot.labels.clear(); slot.previews.clear(); slot.rings.clear()
	var width: float = 6.8 / gate.panels.size()
	for i in gate.panels.size():
		var x: float = -3.4 + width * (i + 0.5)
		var tint := Color("5cd4ee") if gate.panels[i].t != "trap" else Color("df655b")
		var torus := TorusMesh.new(); torus.inner_radius = width * 0.39; torus.outer_radius = width * 0.44; torus.rings = 24; torus.ring_segments = 5
		var ring := MeshInstance3D.new(); ring.mesh = torus; ring.position = Vector3(x, 1.9, 0); ring.rotation.x = PI / 2
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color = Color(tint, 0.7); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = mat; slot.root.add_child(ring); slot.rings.append(ring)
		var number := text3(panel_text(gate.panels[i]), Vector3(x, 2.13, 0.12), 144); number.modulate = Color("e8fcff") if gate.panels[i].t != "trap" else Color("ffaaa3"); slot.root.add_child(number); slot.labels.append(number)
		var preview := text3("", Vector3(x, 1.24, 0.14), 60); slot.root.add_child(preview); slot.previews.append(preview)
	slot.ord = int(gate.ord)
func panel_text(panel: Dictionary) -> String:
	match str(panel.t):
		"mult": return "×%d" % int(panel.v)
		"add": return "+%d" % int(panel.v)
		"speed": return "↑%d%%" % int(panel.v)
		"trap": return "−%d%%" % int(panel.v)
	return "+%d%%" % int(panel.v)
func sync(world, sim: RunSim, delta: float) -> void:
	clock += delta
	world.road.material_override = road_material; road_material.set_shader_parameter("travel", sim.z)
	var gate: Dictionary = sim.next_gate()
	var key := str(gate.get("z", -1)) + str(gate.get("options", []))
	if key != part_key: part_key = key; build_part(gate, sim)
	part.visible = sim.state == "running" and not gate.is_empty() and float(gate.z) - sim.z < 62
	if part.visible: part.position = Vector3(sim.gate_offset(gate, sim.t), 0, sim.z - float(gate.z))
	for slot in slots: slot.root.visible = false
	if sim.mob == null or sim.state != "running": return
	var count := 0
	var update := clock >= numbers_at
	if update: numbers_at = clock + 0.25
	for row in sim.mob.gates:
		var gap := float(row.z) - sim.z
		if gap < -2 or gap > 62 or count >= 2: continue
		# A robot decision owns the near field; later stream rows stay quiet behind it.
		if part.visible and float(gate.z) - sim.z < 30 and float(row.z) > float(gate.z): continue
		var slot: Dictionary = slots[count]
		var row_key := str(row.ord) + str(row.panels)
		if slot.key != row_key: slot.key = row_key; build_row(slot, row)
		slot.root.visible = true; slot.root.position = Vector3(sim.mob.gate_offset(row, sim.t, sim.flags.tuning), 0, sim.z - float(row.z))
		for i in slot.labels.size():
			var number: Label3D = slot.labels[i]
			number.scale = Vector3.ONE
			if world.ui_feedback != null and world.ui_feedback.mob_pulses.has(int(row.ord)) and not world.reduce_motion:
				var pulse: Dictionary = world.ui_feedback.mob_pulses[int(row.ord)]
				if int(pulse.lane) == i: number.scale *= 1.0 + maxf(0, float(pulse.until) - world.ui_feedback.clock) * 0.25
			if update and sim.flags.get("gate_preview", false) and sim.get("hook") != null:
				var p: Dictionary = sim.get("hook").preview(sim, row, row.panels[i])
				slot.previews[i].text = "POWER\n%.0f → %.0f" % [float(p.get("input", 0)), float(p.get("output", 0))]
		count += 1
	metrics = {"part_rows": int(part.visible), "mob_rows": count}
