class_name WorldView extends Node3D
var road: MeshInstance3D
var stripes: MultiMeshInstance3D
var skids: MultiMeshInstance3D
var scenery: MultiMeshInstance3D
var scenery_sets: Array[MultiMeshInstance3D] = []
var scrap: MultiMeshInstance3D
var gold: MultiMeshInstance3D
var projectiles: MultiMeshInstance3D
var hostile_projectiles: MultiMeshInstance3D
var shadows: MultiMeshInstance3D
var fx: MultiMeshInstance3D
var fx_items: Array = []
var flame_fx: CPUParticles3D
var dust_fx: CPUParticles3D
var shield_bubble: MeshInstance3D
var popups: Array[Label3D] = []
var popup_index := 0
var player: RobotBuilder
var enemy_nodes: Array[MeshInstance3D] = []
var hazard_nodes: Array[MeshInstance3D] = []
var warnings: Array[MeshInstance3D] = []
var gate_root: Node3D
var aim_ring: MeshInstance3D
var aim_beam: MeshInstance3D
var salvage_tags: Dictionary = {}
var charge_panels: Array = []
var gate_rail: MeshInstance3D
var sim_t1 := 1.0
var sim_cost: Callable
var sim_t2 := 2.5
var gate_signature := ""
var boss_root: Node3D
var boss_core: MeshInstance3D
var boss_plate: MeshInstance3D
var boss_arm: MeshInstance3D
var gate_y := 0.0
var elapsed := 0.0
var scrap_mesh: ArrayMesh
var circle_warning: CylinderMesh
var box_warning := BoxMesh.new()
var floor_color := Color("b48e5e")

func _ready() -> void:
	circle_warning = CylinderMesh.new()
	circle_warning.top_radius = 0.5
	circle_warning.bottom_radius = 0.5
	circle_warning.height = 1.0
	circle_warning.radial_segments = 32
	road = MeshFactory.instance(MeshFactory.merged([
		MeshFactory.box(Vector3(120, 0.3, 190), Vector3(0, -0.35, -55), floor_color),
		MeshFactory.box(Vector3(60, 0.06, 150), Vector3(0, -0.19, -50), Color("9c7a52")),
		MeshFactory.box(Vector3(9.6, 0.1, 150), Vector3(0, -0.12, -50), Color("7d6244")),
		MeshFactory.box(Vector3(7.4, 0.12, 150), Vector3(0, -0.1, -50), Color("58545f")),
		MeshFactory.box(Vector3(0.6, 0.125, 150), Vector3(-1.5, -0.099, -50), Color("4a4651")),
		MeshFactory.box(Vector3(0.6, 0.125, 150), Vector3(1.5, -0.099, -50), Color("4a4651")),
		MeshFactory.box(Vector3(0.3, 0.2, 150), Vector3(-3.85, 0, -50), MeshFactory.RUST),
		MeshFactory.box(Vector3(0.3, 0.2, 150), Vector3(3.85, 0, -50), MeshFactory.RUST),
		MeshFactory.box(Vector3(0.3, 0.22, 150), Vector3(-4.15, -0.02, -50), Color("6b5236")),
		MeshFactory.box(Vector3(0.3, 0.22, 150), Vector3(4.15, -0.02, -50), Color("6b5236"))], true))
	add_child(road)
	# Road litter (rocks, rust shards, bolts) and tyre skids scroll past instead of painted lane dashes.
	stripes = make_multimesh(MeshFactory.merged([
		MeshFactory.sphere(0.16, Vector3(0, 0.03, 0), Color("6e6258"), Vector3(1.3, 0.5, 1.0), 6),
		MeshFactory.rbox(Vector3(0.22, 0.04, 0.12), Vector3(0.28, 0.03, 0.1), MeshFactory.RUST, 0.015, Vector3(0, 0.6, 0)),
		MeshFactory.cylinder(0.04, 0.16, Vector3(-0.25, 0.04, 0.15), MeshFactory.GREY, Vector3(0, 0, PI / 2), -1.0, 5)]), 70)
	skids = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.16, 0.012, 2.6), Vector3.ZERO, Color("3b3844"))], true), 26)
	for k in 6:
		scenery_sets.append(make_multimesh(MeshFactory.prop(k), 14))
	scenery = scenery_sets[0]
	scrap_mesh = MeshFactory.merged([MeshFactory.cylinder(0.24, 0.1, Vector3.ZERO, MeshFactory.YELLOW, Vector3(PI / 2, 0, 0), -1.0, 14), MeshFactory.cylinder(0.15, 0.14, Vector3.ZERO, Color('ffe98a'), Vector3(PI / 2, 0, 0), -1.0, 12)])
	scrap = make_multimesh(scrap_mesh, 400)
	gold = make_multimesh(MeshFactory.gold_coin(), 40)
	projectiles = make_multimesh(MeshFactory.merged([MeshFactory.capsule(0.09, 0.5, Vector3.ZERO, MeshFactory.YELLOW, Vector3(PI / 2, 0, 0))]), 64)
	hostile_projectiles = make_multimesh(MeshFactory.merged([MeshFactory.capsule(0.13, 0.6, Vector3.ZERO, MeshFactory.RED, Vector3(PI / 2, 0, 0))]), 16)
	shadows = make_multimesh(MeshFactory.merged([MeshFactory.cylinder(0.65, 0.01, Vector3.ZERO, Color("3b434d"), Vector3.ZERO, -1.0, 16)], true), 26)
	fx = make_multimesh(MeshFactory.merged([MeshFactory.sphere(0.14, Vector3.ZERO, Color.WHITE, Vector3.ONE, 6)], true), 128, true)
	player = RobotBuilder.new()
	add_child(player)
	_build_player_fx()
	flame_fx = CPUParticles3D.new()
	flame_fx.amount = 12
	flame_fx.lifetime = 0.4
	flame_fx.direction = Vector3(0, 0, -1)
	flame_fx.spread = 18
	flame_fx.initial_velocity_min = 16
	flame_fx.initial_velocity_max = 22
	flame_fx.gravity = Vector3.ZERO
	flame_fx.color = MeshFactory.ORANGE
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.15
	particle_mesh.height = 0.3
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = MeshFactory.ORANGE
	particle_mesh.material = flame_material
	flame_fx.mesh = particle_mesh
	flame_fx.emitting = false
	add_child(flame_fx)
	for i in 24:
		var node := MeshFactory.instance(MeshFactory.enemy("scrapper"))
		add_child(node)
		node.visible = false
		enemy_nodes.append(node)
	var warning_material := StandardMaterial3D.new()
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.albedo_color = Color("e84c41")
	for i in 8:
		var node := MeshFactory.instance(MeshFactory.merged([MeshFactory.cylinder(0.75, 0.2, Vector3.ZERO, MeshFactory.RED)]))
		add_child(node)
		node.visible = false
		hazard_nodes.append(node)
		var warning := MeshFactory.instance(BoxMesh.new())
		warning.material_override = warning_material
		add_child(warning)
		warning.visible = false
		warnings.append(warning)
	gate_root = Node3D.new()
	add_child(gate_root)
	boss_root = Node3D.new()
	boss_root.position = Vector3(0, 0, -18)
	add_child(boss_root)
	boss_root.add_child(MeshFactory.instance(MeshFactory.boss_body()))
	boss_core = MeshFactory.instance(MeshFactory.merged([MeshFactory.cylinder(0.7, 0.22, Vector3.ZERO, MeshFactory.RED, Vector3(PI / 2, 0, 0), -1.0, 16), MeshFactory.sphere(0.42, Vector3(0, 0, 0.08), MeshFactory.YELLOW, Vector3(1, 1, 0.5), 12)]))
	boss_core.position = Vector3(0, 3.6, 1.12)
	boss_root.add_child(boss_core)
	boss_plate = MeshFactory.instance(MeshFactory.merged([MeshFactory.rbox(Vector3(2.5, 1.7, 0.34), Vector3.ZERO, MeshFactory.STEEL, 0.15), MeshFactory.rbox(Vector3(0.4, 1.7, 0.38), Vector3.ZERO, MeshFactory.ORANGE, 0.1)]))
	boss_plate.position = Vector3(0, 3.4, 1.4)
	boss_root.add_child(boss_plate)
	boss_arm = MeshFactory.instance(MeshFactory.merged([MeshFactory.capsule(0.35, 6, Vector3.ZERO, MeshFactory.ORANGE, Vector3(PI / 2, 0, 0)), MeshFactory.sphere(0.6, Vector3(0, 0, -3), MeshFactory.YELLOW, Vector3.ONE, 10)]))
	boss_arm.position = Vector3(2.8, 2.1, 4)
	boss_root.add_child(boss_arm)
	boss_root.visible = false
	_build_aim_feedback()
	var rail_material := StandardMaterial3D.new()
	rail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rail_material.albedo_color = Color(MeshFactory.ORANGE, 0.4)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(1.0, 0.03, 0.9)
	gate_rail = MeshInstance3D.new()
	gate_rail.mesh = rail_mesh
	gate_rail.material_override = rail_material
	gate_rail.position.y = 0.03
	gate_rail.visible = false
	add_child(gate_rail)

# Lane-aiming feedback: a ring under the locked target, a soft beam to it, and tags on salvage targets.
func _build_aim_feedback() -> void:
	var aim_material := StandardMaterial3D.new()
	aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_material.albedo_color = Color(MeshFactory.ORANGE, 0.9)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.62
	ring_mesh.outer_radius = 0.86
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6
	aim_ring = MeshInstance3D.new()
	aim_ring.mesh = ring_mesh
	aim_ring.material_override = aim_material
	aim_ring.visible = false
	add_child(aim_ring)
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.07, 0.07, 1.0)
	var beam_material := aim_material.duplicate()
	beam_material.albedo_color = Color(MeshFactory.ORANGE, 0.35)
	aim_beam = MeshInstance3D.new()
	aim_beam.mesh = beam_mesh
	aim_beam.material_override = beam_material
	aim_beam.visible = false
	add_child(aim_beam)
	for kind in ["blast", "loot"]:
		var tag := label3d("BLAST" if kind == "blast" else "LOOT", Vector3.ZERO, 110)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = MeshFactory.ORANGE if kind == "blast" else MeshFactory.YELLOW
		tag.outline_size = 14
		tag.outline_modulate = Color(0.07, 0.08, 0.14)
		tag.visible = false
		add_child(tag)
		salvage_tags[kind] = tag

func _sync_aim(sim: RunSim) -> void:
	var target = sim.aim_target
	var show: bool = target != null and sim.state == "running"
	aim_ring.visible = show
	aim_beam.visible = show
	if show:
		var tz := sim.z - float(target.z)
		aim_ring.position = Vector3(target.x, 0.07, tz)
		aim_ring.scale = Vector3.ONE * (1.0 + sin(elapsed * 10.0) * 0.08)
		var from := Vector3(sim.x, 1.0, -0.9)
		var to := Vector3(target.x, 1.0, tz)
		aim_beam.position = (from + to) / 2.0
		aim_beam.rotation = Vector3(0, atan2(to.x - from.x, to.z - from.z), 0)
		aim_beam.scale = Vector3(1, 1, maxf(0.1, from.distance_to(to)))
	for kind in salvage_tags:
		salvage_tags[kind].visible = false
	for enemy in sim.enemies:
		var kind := str(enemy.get("salvage", ""))
		var gap: float = float(enemy.z) - sim.z
		if salvage_tags.has(kind) and gap > 1.0 and gap < 42.0 and enemy.hp > 0:
			var tag: Label3D = salvage_tags[kind]
			tag.visible = true
			tag.position = Vector3(enemy.x, 3.0 + sin(elapsed * 4.0) * 0.12, -gap)

func make_multimesh(mesh: Mesh, count: int, colors := false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = colors
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.multimesh.visible_instance_count = 0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func label3d(text: String, pos: Vector3, size := 64) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.0065
	label.outline_size = 7
	label.modulate = Color.WHITE
	label.no_depth_test = false
	return label

func rebuild_gate(gate: Dictionary, robot: RobotState = null) -> void:
	for child in gate_root.get_children():
		child.queue_free()
	charge_panels.clear()
	if gate.is_empty():
		return
	var options: Array = gate.options
	var moving: bool = gate.get("moving", false)
	var width := (2.4 if moving else 6.8 / options.size())
	for i in options.size():
		var option: Dictionary = options[i]
		var dx: float = (float(i) - (options.size() - 1) / 2.0) * 2.8 if moving else -3.4 + width * (i + 0.5)
		var tone := Color("43b975") if option.kind == "part" else (Color("9b72c7") if option.kind in ["gamble", "surge"] else (MeshFactory.YELLOW if option.kind == "frenzy" else (Color("ff6b81") if option.kind == "heal" else MeshFactory.ORANGE)))
		var mesh := MeshFactory.instance(MeshFactory.merged([
			MeshFactory.rbox(Vector3(width - 0.12, 0.16, 0.16), Vector3(dx, 3.2, 0), tone),
			MeshFactory.rbox(Vector3(width - 0.22, 1.22, 0.16), Vector3(dx, 2.55, 0), MeshFactory.DARK),
			MeshFactory.rbox(Vector3(0.1, 3.2, 0.15), Vector3(dx - width / 2 + 0.08, 1.6, 0), tone),
			MeshFactory.rbox(Vector3(0.1, 3.2, 0.15), Vector3(dx + width / 2 - 0.08, 1.6, 0), tone),
			MeshFactory.rbox(Vector3(width - 0.15, 0.04, 0.6), Vector3(dx, 0.04, 0), tone)]))
		gate_root.add_child(mesh)
		var name_label := label3d(GateGen.label(option).to_upper().replace(" ", "\n") if options.size() == 3 else GateGen.label(option).to_upper(), Vector3(dx, 2.72, 0.12), 34 if options.size() == 3 else (42 if moving else 56))
		gate_root.add_child(name_label)
		var desc := label3d(GateGen.description(option), Vector3(dx, 2.08, 0.12), 20 if options.size() == 3 else (24 if moving else 30))
		gate_root.add_child(desc)
		if option.kind == "part":
			var icon := MeshFactory.instance(MeshFactory.part(str(option.id), 1))
			icon.position = Vector3(dx, 1.2, 0)
			icon.scale = Vector3.ONE * 0.85
			gate_root.add_child(icon)
			var tag := _gate_tag(option, robot)
			if not tag.is_empty():
				gate_root.add_child(label3d(tag, Vector3(dx, 3.62, 0.12), 40))
				gate_root.get_child(gate_root.get_child_count() - 1).modulate = MeshFactory.YELLOW
		if gate.has("charge") and option.kind in ["part", "upgrade_random_owned"]:
			charge_panels.append(_charge_panel(i, dx, width, option))
		if option.kind in ["heal", "frenzy", "surge"]:
			var icon := MeshFactory.instance(MeshFactory.icon(str(option.kind)))
			icon.position = Vector3(dx, 1.2, 0)
			icon.scale = Vector3.ONE * 1.1
			icon.set_meta("spin", true)
			gate_root.add_child(icon)

# Charge bar and next-level preview over a chargeable panel (gate_charge flag).
func _charge_panel(lane: int, dx: float, width: float, option: Dictionary) -> Dictionary:
	var bar_material := StandardMaterial3D.new()
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.albedo_color = MeshFactory.DARK
	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(width - 0.5, 0.5, 0.1)
	back.mesh = back_mesh
	back.material_override = bar_material
	back.position = Vector3(dx, 4.0, 0.0)
	gate_root.add_child(back)
	var fill_material := StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.albedo_color = MeshFactory.ORANGE
	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(width - 0.62, 0.34, 0.12)
	fill.mesh = fill_mesh
	fill.material_override = fill_material
	fill.position = Vector3(dx, 4.0, 0.04)
	gate_root.add_child(fill)
	var tick_x := (float(sim_t1) / float(sim_t2) - 0.5) * (width - 0.62)
	var tick := MeshInstance3D.new()
	var tick_mesh := BoxMesh.new()
	tick_mesh.size = Vector3(0.1, 0.56, 0.14)
	tick.mesh = tick_mesh
	tick.material_override = bar_material
	tick.position = Vector3(dx + tick_x, 4.0, 0.05)
	gate_root.add_child(tick)
	var level_label := label3d("", Vector3(dx, 4.95, 0.12), 54)
	level_label.modulate = MeshFactory.YELLOW
	gate_root.add_child(level_label)
	return {"lane": lane, "fill": fill, "label": level_label, "width": width - 0.62, "x": dx, "option": option, "material": fill_material}

func _update_charge(gate: Dictionary, robot: RobotState) -> void:
	if not gate.has("charge"):
		return
	for panel in charge_panels:
		var amount: float = gate.charge[panel.lane]
		var cost: float = sim_cost.call(panel.option)
		var fraction := clampf(amount / (float(sim_t2) * cost), 0.0, 1.0)
		var fill: MeshInstance3D = panel.fill
		fill.scale.x = maxf(0.001, fraction)
		fill.position.x = panel.x - panel.width * (1.0 - fraction) / 2.0
		panel.material.albedo_color = MeshFactory.ORANGE.lerp(MeshFactory.YELLOW, fraction)
		var bonus := int(amount >= float(sim_t1) * cost) + int(amount >= float(sim_t2) * cost)
		var option: Dictionary = panel.option
		var text := ""
		if option.kind == "part":
			var id := str(option.id)
			var granted := mini(3, int(robot.parts.get(id, 0)) + 1 + bonus)
			text = "LV %d%s\n%s" % [granted, " MAX" if granted == 3 else "", str(GameData.table("parts")[id].levels[granted - 1].name).to_upper()]
		else:
			text = "+%d LEVEL%s" % [1 + bonus, "S" if bonus > 0 else ""]
		panel.label.text = text

# Hint above a gate: does picking it finish a combo or upgrade a part?
func _gate_tag(option: Dictionary, robot: RobotState) -> String:
	if robot == null:
		return ""
	var id := str(option.id)
	if robot.parts.has(id):
		return "LV %d > %d" % [int(robot.parts[id]), mini(3, int(robot.parts[id]) + 1)]
	for combo_id in GameData.table("combos"):
		var def: Dictionary = GameData.table("combos")[combo_id]
		if def.get("stretch", false):
			continue
		if def.needs.has(id):
			var other: String = def.needs[1] if def.needs[0] == id else def.needs[0]
			if robot.parts.has(other):
				return "COMBO!"
	return ""

func burst(pos: Vector3, count := 8, color := MeshFactory.YELLOW, speed := 1.0) -> void:
	for i in mini(count, 128 - fx_items.size()):
		fx_items.append({"pos": pos, "vel": Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)) * speed, "life": randf_range(0.35, 0.8), "color": color})

func _build_player_fx() -> void:
	var puff := SphereMesh.new()
	puff.radius = 0.18
	puff.height = 0.36
	puff.radial_segments = 6
	puff.rings = 3
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_color = Color(0.62, 0.5, 0.36, 0.6)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_material
	dust_fx = CPUParticles3D.new()
	dust_fx.amount = 14
	dust_fx.lifetime = 0.55
	dust_fx.direction = Vector3(0, 0.4, 1)
	dust_fx.spread = 25
	dust_fx.initial_velocity_min = 5
	dust_fx.initial_velocity_max = 8
	dust_fx.gravity = Vector3.ZERO
	dust_fx.scale_amount_min = 0.5
	dust_fx.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	dust_fx.scale_amount_curve = fade
	dust_fx.mesh = puff
	add_child(dust_fx)
	var bubble := SphereMesh.new()
	bubble.radius = 1.35
	bubble.height = 2.7
	bubble.radial_segments = 16
	bubble.rings = 8
	var bubble_material := StandardMaterial3D.new()
	bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_material.albedo_color = Color(0.3, 0.8, 1.0, 0.28)
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble.material = bubble_material
	shield_bubble = MeshInstance3D.new()
	shield_bubble.mesh = bubble
	shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_bubble.visible = false
	add_child(shield_bubble)
	for i in 10:
		var label := label3d("", Vector3.ZERO, 72)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.visible = false
		label.outline_size = 14
		label.outline_modulate = Color(0.07, 0.08, 0.14)
		label.set_meta("life", 0.0)
		add_child(label)
		popups.append(label)

# Floating world-space text (scrap pickups, damage, kill streaks).
func popup(text: String, pos: Vector3, color := Color.WHITE, size := 72) -> void:
	var label := popups[popup_index]
	popup_index = (popup_index + 1) % popups.size()
	label.text = text
	label.font_size = size
	label.modulate = color
	label.position = pos
	label.visible = true
	label.set_meta("life", 1.0)

func sync(sim: RunSim, dt: float) -> void:
	elapsed += dt
	player.position.x = sim.x
	player.position.y = absf(sin(elapsed * 9.0)) * 0.035 if sim.state in ["running", "boss"] else 0.0
	var lean := (sim.x - sim.target_x) * 0.05
	player.rotation.z = lerpf(player.rotation.z, lean if absf(lean) > 0.004 else 0.0, 0.2)
	player.sync(sim.robot)
	player.drive_speed = (float(sim.robot.stats.fwd_mult) * (0.6 if sim.oil_time > 0 else 1.0)) if sim.state == "running" else (0.3 if sim.state == "boss" else 0.0)
	player.steer = clampf(sim.target_x - sim.x, -1.5, 1.5)
	var moving: bool = sim.state in ["running", "boss"]
	dust_fx.position = Vector3(sim.x, 0.25, 0.8)
	dust_fx.emitting = moving
	shield_bubble.visible = sim.robot.shield_charges > 0
	shield_bubble.position = Vector3(sim.x, 1.1, 0)
	shield_bubble.scale = Vector3.ONE * (1.0 + sin(elapsed * 5) * 0.03) * (0.85 + float(player.stage_value) * 0.15)
	for label in popups:
		if label.visible:
			var life: float = label.get_meta("life") - dt * 1.3
			label.set_meta("life", life)
			label.position.y += dt * 2.2
			label.position.z += dt * (9 if sim.state == "running" else 0)
			label.modulate.a = clampf(life * 2.5, 0, 1)
			label.scale = Vector3.ONE * (1.0 + maxf(0, life - 0.8) * 3.0)
			if life <= 0:
				label.visible = false
	flame_fx.position = Vector3(sim.x, 1.0, -0.9)
	flame_fx.emitting = sim.robot.parts.has("flame") and (sim.state == "boss" or not sim.enemies.is_empty())
	stripes.multimesh.visible_instance_count = 70
	for i in 70:
		var h := fposmod(sin(float(i) * 78.233) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(i) * 12.9898) * 23421.631, 1.0)
		var litter_z := fposmod(float(i) * 2.9 + h * 2.0 - sim.z, 200.0)
		stripes.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, h2 * TAU), Vector3(h * 7.0 - 3.5, 0.0, 12 - litter_z)))
	skids.multimesh.visible_instance_count = 26
	for i in 26:
		var h := fposmod(sin(float(i) * 37.719) * 91753.113, 1.0)
		var skid_z := fposmod(float(i) * 7.9 + h * 4.0 - sim.z, 200.0)
		skids.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, (h - 0.5) * 0.1), Vector3((h - 0.5) * 6.2, 0.0, 12 - skid_z)))
	for k in scenery_sets.size():
		var set_mesh := scenery_sets[k].multimesh
		set_mesh.visible_instance_count = 14
		for j in 14:
			var i := j * 6 + k
			var side := -1 if (j + k) % 2 == 0 else 1
			var heap := k == 4
			var sz := (1.6 + float(i % 3) * 0.4) if heap else (0.9 + float(i % 3) * 0.25)
			if k == 5:
				sz *= 0.7
			var basis := Basis(Vector3.UP, i * 1.7).scaled(Vector3.ONE * sz)
			var lane_offset := (11.0 + float(i % 4) * 3.0) if heap else (6.2 + float(i % 5) * 1.8)
			var pos := Vector3(side * lane_offset, 0, 14 - fposmod(float(j) * 13.7 + float(k) * 5.3 - sim.z * 0.95, 190))
			set_mesh.set_instance_transform(j, Transform3D(basis, pos))
	_sync_aim(sim)
	var count := 0
	var gold_count := 0
	for node in sim.scrap_nodes:
		if node.alive and float(node.z) > sim.z - 4 and float(node.z) < sim.z + 65:
			var coin_pos := Vector3(node.x, 0.35 + sin(elapsed * 4 + count) * 0.1, sim.z - float(node.z))
			if node.get("gold", false):
				if gold_count < 40:
					gold.multimesh.set_instance_transform(gold_count, Transform3D(Basis(Vector3.UP, elapsed * 3 + count).scaled(Vector3.ONE * 1.35), coin_pos + Vector3(0, 0.25, 0)))
					gold_count += 1
			elif count < 400:
				scrap.multimesh.set_instance_transform(count, Transform3D(Basis(Vector3.UP, elapsed * 2 + count), coin_pos))
				count += 1
	scrap.multimesh.visible_instance_count = count
	gold.multimesh.visible_instance_count = gold_count
	projectiles.multimesh.visible_instance_count = sim.bullets.size()
	for i in sim.bullets.size():
		var bullet: Dictionary = sim.bullets[i]
		projectiles.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(bullet.x, 1.1, sim.z - float(bullet.z))))
	hostile_projectiles.multimesh.visible_instance_count = sim.hostile_bullets.size()
	for i in sim.hostile_bullets.size():
		var bolt: Dictionary = sim.hostile_bullets[i]
		hostile_projectiles.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(bolt.x, 0.9, sim.z - float(bolt.z))))
	shadows.multimesh.visible_instance_count = sim.enemies.size() + 1
	shadows.multimesh.set_instance_transform(0, Transform3D(Basis().scaled(Vector3(1.2, 1, 1.3)), Vector3(sim.x, 0.025, 0)))
	for i in enemy_nodes.size():
		var node := enemy_nodes[i]
		node.visible = i < sim.enemies.size()
		if node.visible:
			var enemy: Dictionary = sim.enemies[i]
			var size := 0.75 if enemy.id == "scrapper" else (1.35 if enemy.id == "hauler" else 1.0)
			node.scale = Vector3.ONE * size
			if node.get_meta("kind", "") != enemy.id:
				node.set_meta("kind", enemy.id)
				node.mesh = MeshFactory.hazard("barrel") if enemy.id == "barrel" else MeshFactory.enemy(str(enemy.id))
			var phase := elapsed * 8 + i * 1.7
			var hop := 0.0
			node.rotation = Vector3(0, PI, 0)
			match str(enemy.id):
				"scrapper":
					# Rolling lurch: hops, squashes on landing, leans toward the player.
					hop = absf(sin(phase)) * 0.22
					node.scale = Vector3(1.0 + (1.0 - absf(sin(phase))) * 0.08, 1.0 - (1.0 - absf(sin(phase))) * 0.1, 1.0) * size
					node.rotation.z = sin(phase * 0.5) * 0.12
					node.rotation.x = -0.12
				"gunner":
					# Turret tracks the player and kicks back when it fires.
					node.rotation.y = PI + clampf((float(enemy.x) - sim.x) * -0.08, -0.5, 0.5)
					node.scale = Vector3.ONE * size * (1.0 + (0.06 if enemy.warning else 0.0) * sin(elapsed * 30))
				"barrel":
					node.rotation.y += elapsed * 0.5
				"crate":
					hop = absf(sin(elapsed * 3.0 + float(enemy.uid))) * 0.08
					node.scale = Vector3.ONE * size * (1.0 + sin(elapsed * 5.0) * 0.015)
				"hauler":
					# Drives away from the camera, bouncing on its suspension and swaying with its lane.
					node.rotation = Vector3(sin(elapsed * 14.0) * 0.012, 0.0, sin(elapsed * 9.0) * 0.02 + (float(enemy.x) - sim.x) * 0.0)
					node.rotation.y = cos(elapsed * 1.3 + float(enemy.uid)) * 0.1
					hop = absf(sin(elapsed * 16.0)) * 0.05
				_:
					# Heavy stomp with a windup lean when it is about to charge.
					hop = absf(sin(phase * 0.5)) * 0.1
					node.rotation.z = sin(phase * 0.5) * 0.06
					node.rotation.x = -0.18 if enemy.warning else 0.0
			node.position = Vector3(enemy.x, hop, sim.z - float(enemy.z))
			var last_hp: float = node.get_meta("hp", float(enemy.hp))
			if float(enemy.hp) < last_hp - 0.01:
				node.set_meta("flash", 1.0)
			node.set_meta("hp", float(enemy.hp))
			var flash_value: float = maxf(0.0, float(node.get_meta("flash", 0.0)) - dt * 6.0)
			node.set_meta("flash", flash_value)
			node.set_instance_shader_parameter("flash", flash_value)
			shadows.multimesh.set_instance_transform(i + 1, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3(enemy.x, 0.025, node.position.z)))
	for i in hazard_nodes.size():
		hazard_nodes[i].visible = i < sim.hazards.size() and not sim.hazards[i].used
		if hazard_nodes[i].visible:
			var hazard: Dictionary = sim.hazards[i]
			if hazard_nodes[i].get_meta("kind", "") != str(hazard.id):
				hazard_nodes[i].set_meta("kind", str(hazard.id))
				hazard_nodes[i].mesh = MeshFactory.hazard(str(hazard.id))
			hazard_nodes[i].position = Vector3(hazard.x, 0.2, sim.z - float(hazard.z))
			hazard_nodes[i].rotation.y += dt * 8
	var gate := sim.next_gate()
	var sig := JSON.stringify(gate.get("options", [])) + str(gate.get("z", -1)) + JSON.stringify(sim.robot.parts)
	if sig != gate_signature:
		gate_signature = sig
		rebuild_gate(gate, sim.robot)
	sim_cost = sim.charge_cost
	sim_t1 = float(sim.flags.tuning.charge_t1)
	sim_t2 = float(sim.flags.tuning.charge_t2)
	_update_charge(gate, sim.robot)
	for child in gate_root.get_children():
		if child.has_meta("spin"):
			child.rotation.y = elapsed * 2.0
	gate_root.visible = not gate.is_empty() and sim.state == "running"
	if not gate.is_empty():
		gate_root.position.z = sim.z - float(gate.z)
		gate_root.position.x = sim.gate_offset(gate, sim.t)
	gate_rail.visible = gate_root.visible and gate.get("moving", false)
	if gate_rail.visible:
		gate_rail.position.z = sim.z - float(gate.z)
		var travel: float = 2.0 * (float(sim.flags.tuning.moving_amplitude) + 1.4 + float(sim.flags.tuning.moving_half))
		gate_rail.scale = Vector3(travel, 1, 1)
	boss_root.visible = sim.boss != null
	if boss_root.visible:
		boss_root.position.y = sin(elapsed * 2) * 0.06
		boss_root.rotation.z = sin(elapsed * 1.3) * 0.018
		boss_plate.visible = sim.boss.phase == 1
		boss_arm.visible = sim.boss.arm_hp > 0 or sim.boss.attack == "grabber_arm"
		boss_core.scale = Vector3.ONE * (1.1 + sin(elapsed * 6) * 0.1)
		if sim.state == "won":
			boss_root.scale = boss_root.scale.lerp(Vector3.ONE * 0.01, dt * 2)
		else:
			boss_root.scale = Vector3.ONE
	var warning_index := 0
	if sim.boss != null:
		for zone in sim.boss.zones:
			if warning_index >= warnings.size() or zone.shape == "spawn":
				continue
			var node := warnings[warning_index]
			node.visible = true
			var width: float = float(zone.radius) * 2
			if zone.shape == "sweep":
				# Show danger on both sides of the safe opening.
				for side in [-1, 1]:
					if warning_index >= warnings.size():
						break
					var edge: float = float(zone.x) + side * float(zone.radius)
					var outer: float = side * 3.5
					node = warnings[warning_index]
					node.visible = true
					node.mesh = box_warning
					node.position = Vector3((edge + outer) / 2, 0.04, -1.5)
					node.scale = Vector3(maxf(0.1, absf(outer - edge)), 0.025, 7)
					warning_index += 1
			else:
				node.position = Vector3(zone.x, 0.045, -1.2)
				node.mesh = circle_warning if zone.shape == "circle" else box_warning
				node.scale = Vector3(width, 0.025, width if zone.shape == "circle" else 5.5)
				warning_index += 1
	for enemy in sim.enemies:
		if enemy.warning and warning_index < warnings.size():
			var node := warnings[warning_index]
			node.visible = true
			node.mesh = box_warning
			node.position = Vector3(enemy.aim_x, 0.05, -1.8)
			node.scale = Vector3(1.8, 0.025, 6)
			warning_index += 1
	for i in warning_index:
		warnings[i].material_override.albedo_color = Color("e53935").lerp(Color("ff9070"), (sin(elapsed * 14) + 1) * 0.25)
	for i in range(warning_index, warnings.size()):
		warnings[i].visible = false
	for i in range(fx_items.size() - 1, -1, -1):
		var item: Dictionary = fx_items[i]
		item.life -= dt
		item.pos += item.vel * dt
		item.pos.z += dt * (9 if sim.state == "running" else 0)
		item.vel.y -= dt * 9
		if item.life <= 0:
			fx_items.remove_at(i)
	fx.multimesh.visible_instance_count = fx_items.size()
	for i in fx_items.size():
		fx.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3.ONE * elapsed * 6).scaled(Vector3.ONE * minf(1, fx_items[i].life * 3)), fx_items[i].pos))
		fx.multimesh.set_instance_color(i, fx_items[i].color)
