class_name WorldView extends Node3D
const HookGateScript = preload("res://src/view/hook_gate_view.gd")
var hook_gates
var gate_clarity := false
var hook_underglow: MeshInstance3D
var hook_eyes: MultiMeshInstance3D
var ui_v2_enabled := false
var popup_limit := 10
const UiWorldScript = preload("res://src/ui/ui_world_feedback.gd")
var ui_feedback
var reduce_motion := false
var flash_rate := 3
var default_warning_material: StandardMaterial3D
var gate_panel_count := 2
var road: MeshInstance3D
var stripes: MultiMeshInstance3D
var skids: MultiMeshInstance3D
var scenery: MultiMeshInstance3D
var scenery_sets: Array[MultiMeshInstance3D] = []
var scrap: MultiMeshInstance3D
var gold: MultiMeshInstance3D
var projectiles: MultiMeshInstance3D
var hostile_projectiles: MultiMeshInstance3D
var bomblets: MultiMeshInstance3D
var drones: MultiMeshInstance3D
var mob_gate_nodes: Array = []
var impact_count := 0
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
var crowd_scrappers: MultiMeshInstance3D
var hazard_nodes: Array[MeshInstance3D] = []
var warnings: Array[MeshInstance3D] = []
var gate_root: Node3D
var aim_ring: MeshInstance3D
var salvage_tags: Dictionary = {}
var charge_panels: Array = []
var gate_rail: MeshInstance3D
var sim_t1 := 1.0
var sim_cost: Callable
var evolution_level := 0
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
var floor_color := Color("e8e1d2")

func _ready() -> void:
	circle_warning = CylinderMesh.new()
	circle_warning.top_radius = 0.5
	circle_warning.bottom_radius = 0.5
	circle_warning.height = 1.0
	circle_warning.radial_segments = 32
	road = MeshFactory.instance(MeshFactory.merged([
		MeshFactory.box(Vector3(120, 0.3, 190), Vector3(0, -0.35, -55), floor_color),
		MeshFactory.box(Vector3(60, 0.06, 150), Vector3(0, -0.19, -50), Color("e5dece")),
		MeshFactory.box(Vector3(9.6, 0.1, 150), Vector3(0, -0.12, -50), Color("d5d1c3")),
		MeshFactory.box(Vector3(7.4, 0.12, 150), Vector3(0, -0.1, -50), Color("b7c2bf")),
		MeshFactory.box(Vector3(0.6, 0.125, 150), Vector3(-1.5, -0.099, -50), Color("b5c0bd")),
		MeshFactory.box(Vector3(0.6, 0.125, 150), Vector3(1.5, -0.099, -50), Color("b5c0bd")),
		MeshFactory.box(Vector3(0.16, 0.14, 150), Vector3(-3.6, -0.06, -50), Color("f2efdf")),
		MeshFactory.box(Vector3(0.16, 0.14, 150), Vector3(3.6, -0.06, -50), Color("f2efdf"))], true))
	road.material_override = MeshFactory.road_palette()
	add_child(road)
	# Road litter (rocks, rust shards, bolts) and tyre skids scroll past instead of painted lane dashes.
	stripes = make_multimesh(MeshFactory.merged([
		MeshFactory.sphere(0.16, Vector3(0, 0.03, 0), Color("6e6258"), Vector3(1.3, 0.5, 1.0), 6),
		MeshFactory.rbox(Vector3(0.22, 0.04, 0.12), Vector3(0.28, 0.03, 0.1), MeshFactory.RUST, 0.015, Vector3(0, 0.6, 0)),
		MeshFactory.cylinder(0.04, 0.16, Vector3(-0.25, 0.04, 0.15), MeshFactory.GREY, Vector3(0, 0, PI / 2), -1.0, 5)]), 70)
	skids = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.16, 0.012, 2.6), Vector3.ZERO, Color("3b3844"))], true), 26)
	for k in 6:
		scenery_sets.append(make_multimesh(MeshFactory.prop(k), 14))
		scenery_sets.back().material_override = MeshFactory.scenery_palette()
	scenery = scenery_sets[0]
	scrap_mesh = MeshFactory.merged([MeshFactory.cylinder(0.24, 0.1, Vector3.ZERO, MeshFactory.YELLOW, Vector3(PI / 2, 0, 0), -1.0, 14), MeshFactory.cylinder(0.15, 0.14, Vector3.ZERO, Color('ffe98a'), Vector3(PI / 2, 0, 0), -1.0, 12)])
	scrap = make_multimesh(scrap_mesh, 400)
	gold = make_multimesh(MeshFactory.gold_coin(), 40)
	projectiles = make_multimesh(MeshFactory.merged([MeshFactory.capsule(0.09, 0.5, Vector3.ZERO, MeshFactory.BLUE, Vector3(PI / 2, 0, 0))]), 64)
	hostile_projectiles = make_multimesh(MeshFactory.merged([MeshFactory.capsule(0.13, 0.6, Vector3.ZERO, MeshFactory.RED, Vector3(PI / 2, 0, 0))]), 16)
	bomblets = make_multimesh(MeshFactory.merged([MeshFactory.sphere(0.27, Vector3.ZERO, MeshFactory.ORANGE, Vector3.ONE, 8), MeshFactory.sphere(0.14, Vector3(0, 0.1, 0), MeshFactory.YELLOW, Vector3.ONE, 6)]), 16)
	drones = make_multimesh(MeshFactory.drone(), 256, true)
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
	crowd_scrappers = make_multimesh(MeshFactory.enemy("scrapper"), 24, false, true)
	crowd_scrappers.material_override = MeshFactory.crowd_palette()
	var warning_material := StandardMaterial3D.new()
	default_warning_material = warning_material
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
	_build_mob_gate_pool()

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
	if show:
		var tz := sim.z - float(target.z)
		aim_ring.position = Vector3(target.x, 0.07, tz)
		aim_ring.scale = Vector3.ONE * (1.0 + sin(elapsed * 10.0) * 0.08)
	for kind in salvage_tags:
		salvage_tags[kind].visible = false
	for enemy in sim.enemies:
		var kind := str(enemy.get("salvage", ""))
		var gap: float = float(enemy.z) - sim.z
		if salvage_tags.has(kind) and gap > 1.0 and gap < 42.0 and enemy.hp > 0:
			var tag: Label3D = salvage_tags[kind]
			tag.visible = true
			tag.position = Vector3(enemy.x, 3.0 + sin(elapsed * 4.0) * 0.12, -gap)

func make_multimesh(mesh: Mesh, count: int, colors := false, custom := false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = colors
	node.multimesh.use_custom_data = custom
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
		gate_root.remove_child(child)
		child.queue_free()
	charge_panels.clear()
	if gate.is_empty():
		return
	var options: Array = gate.options
	gate_panel_count = options.size()
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
		if ui_v2_enabled:
			name_label.font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf")
			name_label.font_size = 64 if options.size() == 3 or moving else 80
		gate_root.add_child(name_label)
		var charging: bool = gate.has("charge") and option.kind in ["part", "upgrade_random_owned"]
		if not charging:
			# Chargeable panels already show their level and next part name above the bar.
			gate_root.add_child(label3d(GateGen.description(option), Vector3(dx, 2.08, 0.12), 20 if options.size() == 3 else (24 if moving else 30)))
		if option.kind == "part":
			var icon := MeshFactory.instance(MeshFactory.part(str(option.id), 1))
			icon.position = Vector3(dx, 1.2, 0)
			icon.scale = Vector3.ONE * 0.85
			gate_root.add_child(icon)
			var tag := "" if charging and not tag_is_evolution(option, robot) else _gate_tag(option, robot)
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

func tag_is_evolution(option: Dictionary, robot: RobotState) -> bool:
	return _gate_tag(option, robot) in ["EVOLVES!", "COMBO!"]

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
	if evolution_level > 0 and id in ["rocket", "cannon"]:
		var rocket_after := int(robot.parts.get("rocket", 0)) + (1 if id == "rocket" else 0)
		var cannon_after := int(robot.parts.get("cannon", 0)) + (1 if id == "cannon" else 0)
		if rocket_after >= evolution_level and cannon_after >= 1 and not (int(robot.parts.get("rocket", 0)) >= evolution_level and int(robot.parts.get("cannon", 0)) >= 1):
			return "EVOLVES!"
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

# Mob gates: at most two are on screen. Each is one flat merged frame mesh plus one Label3D per panel (<= 4 draw calls),
# so a mob gate costs about half of a part gate. They are rebuilt only when a different gate is assigned to the slot.
func _build_mob_gate_pool() -> void:
	for slot in 2:
		var root := Node3D.new()
		root.visible = false
		var frame := MeshInstance3D.new()
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(frame)
		var labels: Array = []
		for k in 3:
			var label := label3d("", Vector3.ZERO, 76)
			# The dark sign supplies contrast; an extra outline pass costs one draw per panel.
			label.outline_size = 0
			label.outline_modulate = Color(0.06, 0.07, 0.12)
			label.visible = false
			root.add_child(label)
			labels.append(label)
		var rail_node := MeshInstance3D.new()
		rail_node.mesh = gate_rail.mesh
		rail_node.material_override = gate_rail.material_override
		rail_node.position.y = 0.03
		rail_node.visible = false
		add_child(rail_node)
		add_child(root)
		mob_gate_nodes.append({"root": root, "frame": frame, "labels": labels, "rail": rail_node, "ord": -1})

func _mob_panel_color(type_name: String) -> Color:
	return Color(str(GameData.table("mob").gates.types[type_name].color))

func _mob_panel_text(panel: Dictionary) -> String:
	return str(GameData.table("mob").gates.types[str(panel.t)].text) % int(panel.v)

func _rebuild_mob_gate(slot: Dictionary, gate: Dictionary, tuning: Dictionary) -> void:
	var panels: Array = gate.panels
	var moving: bool = gate.get("moving", false)
	var width := 2.4 if moving else 6.8 / panels.size()
	var pieces: Array = []
	for i in panels.size():
		var dx: float = (float(i) - (panels.size() - 1) / 2.0) * float(tuning.moving_spacing) if moving else -3.4 + width * (i + 0.5)
		var tone := _mob_panel_color(str(panels[i].t))
		pieces.append(MeshFactory.rbox(Vector3(width - 0.1, 0.95, 0.16), Vector3(dx, 3.05, 0), MeshFactory.DARK, 0.06))
		pieces.append(MeshFactory.rbox(Vector3(width - 0.1, 0.12, 0.2), Vector3(dx, 3.58, 0), tone, 0.04))
		pieces.append(MeshFactory.rbox(Vector3(0.12, 3.1, 0.18), Vector3(dx - width / 2 + 0.06, 1.55, 0), tone, 0.05))
		pieces.append(MeshFactory.rbox(Vector3(0.12, 3.1, 0.18), Vector3(dx + width / 2 - 0.06, 1.55, 0), tone, 0.05))
		pieces.append(MeshFactory.rbox(Vector3(width - 0.1, 0.05, 0.5), Vector3(dx, 0.03, 0), tone, 0.02))
		var label: Label3D = slot.labels[i]
		label.text = _mob_panel_text(panels[i])
		label.font_size = 56 if moving or panels.size() == 3 else 76
		if ui_v2_enabled:
			label.font = load("res://assets/fonts/rajdhani_Rajdhani-Bold.ttf")
			label.font_size = 100 if moving or panels.size() == 3 else 144
			if panels[i].t == "speed": label.text = "↑%d%%" % int(panels[i].v)
		label.position = Vector3(dx, 3.02, 0.14)
		label.modulate = Color("ff6b7a") if str(panels[i].t) == "trap" else Color.WHITE
		label.visible = true
	for k in range(panels.size(), 3):
		slot.labels[k].visible = false
	slot.frame.mesh = MeshFactory.merged(pieces, true)
	slot.ord = int(gate.ord)

func _sync_mob_gates(sim: RunSim) -> void:
	var mob: MobSim = sim.mob
	var shown := 0
	var shown_ords: Array = []
	if mob != null and sim.state == "running":
		var reach := float(mob.cfg.gates.visible_m)
		# Draw-call budget: while a part gate is on screen only the nearest mob gate is drawn.
		var limit := 1 if gate_root.visible else 2
		for gate in mob.gates:
			var gz := float(gate.z)
			if gz < sim.z - 3.0:
				continue
			if gz > sim.z + reach or shown >= limit:
				break
			var slot: Dictionary = mob_gate_nodes[int(gate.ord) % 2]
			if int(slot.ord) != int(gate.ord):
				_rebuild_mob_gate(slot, gate, sim.flags.tuning)
			slot.root.visible = true
			slot.root.position = Vector3(mob.gate_offset(gate, sim.t, sim.flags.tuning), 0, sim.z - gz)
			for panel_index in slot.labels.size():
				var number: Label3D = slot.labels[panel_index]
				number.scale = Vector3.ONE
				if ui_v2_enabled and ui_feedback != null and ui_feedback.mob_pulses.has(int(gate.ord)):
					var pulse: Dictionary = ui_feedback.mob_pulses[int(gate.ord)]
					if int(pulse.lane) == panel_index and float(pulse.until) > ui_feedback.clock and not reduce_motion:
						number.scale = Vector3.ONE * (1.0 + (float(pulse.until) - ui_feedback.clock) / 0.35 * 0.12)
			var is_moving: bool = gate.get("moving", false)
			slot.rail.visible = is_moving
			if is_moving:
				slot.rail.position = Vector3(0, 0.03, sim.z - gz)
				slot.rail.scale = Vector3(2.0 * (float(sim.flags.tuning.moving_amplitude) + 1.4 + float(sim.flags.tuning.moving_half)), 1, 1)
			shown_ords.append(int(gate.ord))
			shown += 1
	for slot in mob_gate_nodes:
		if slot.root.visible and not shown_ords.has(int(slot.ord)):
			slot.root.visible = false
			slot.rail.visible = false
			slot.ord = -1

const DRONE_COLORS := [Color("50b9df"), Color("8197cf"), Color("e0a254"), Color("5fd0ff")]

func reset_run_feedback() -> void:
	fx_items.clear()
	impact_count = 0
	if ui_feedback != null: ui_feedback.reset()
	for label in popups:
		label.visible = false
		label.set_meta("life", 0.0)
	for slot in mob_gate_nodes:
		slot.ord = -1
		slot.root.visible = false
		slot.rail.visible = false

# Mob Stream drones: one MultiMesh, tint by kind, scale by how heavy (multiplied or merged) the drone is.
func _sync_drones(sim: RunSim) -> void:
	var mob: MobSim = sim.mob
	if mob == null:
		drones.multimesh.visible_instance_count = 0
		impact_count = 0
		return
	var count := mini(mob.n, 256)
	var kinds: Dictionary = mob.cfg.kinds
	var extra := float(mob.cfg.scale_per_extra_weight)
	var limit := float(mob.cfg.scale_max)
	for i in count:
		var k := mob.kind[i]
		var s := minf(limit * (3.0 if k == MobSim.Kind.CHAMPION else 1.0), float(kinds[MobSim.KIND_NAMES[k]].scale) * (1.0 + extra * (mob.wgt[i] - 1.0)))
		var yaw := -atan2(mob.vx[i], maxf(mob.vz[i], 0.1)) if absf(mob.vx[i]) > 0.3 else 0.0
		var at := Vector3(mob.px[i], mob.py[i] + (0.0 if reduce_motion else sin(elapsed * 14.0 + float(i)) * 0.05), sim.z - mob.pz[i])
		drones.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at))
		var tint: Color = DRONE_COLORS[k]
		if ui_v2_enabled and mob.wgt[i] > 1.01: tint = tint.lerp(Color.WHITE, minf(0.4, (mob.wgt[i] - 1.0) * 0.12))
		drones.multimesh.set_instance_color(i, tint)
	drones.multimesh.visible_instance_count = count
	var shown := 0
	impact_count = mob.impacts.size()
	for impact in mob.impacts:
		if shown < 6:
			burst(Vector3(impact[0], 1.0, sim.z - float(impact[1])), 1 + mini(3, int(float(impact[2]))), DRONE_COLORS[int(impact[3])], 0.6)
			shown += 1
	mob.impacts.clear()

func burst(pos: Vector3, count := 8, color := MeshFactory.YELLOW, speed := 1.0) -> void:
	if ui_v2_enabled:
		if reduce_motion: return
		count = mini(count, 4 if ui_feedback != null and ui_feedback.duck else 12)
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
	puff_material.albedo_color = Color(0.7, 0.65, 0.55, 0.25)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_material
	dust_fx = CPUParticles3D.new()
	dust_fx.amount = 6
	dust_fx.lifetime = 0.3
	dust_fx.direction = Vector3(0, 0.4, 1)
	dust_fx.spread = 25
	dust_fx.initial_velocity_min = 2
	dust_fx.initial_velocity_max = 3
	dust_fx.gravity = Vector3.ZERO
	dust_fx.scale_amount_min = 0.5
	dust_fx.scale_amount_max = 0.7
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
	var label := popups[popup_index % popup_limit]
	popup_index = (popup_index + 1) % popup_limit
	if gate_clarity:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var center := camera.unproject_position(to_global(pos))
			var width: float = get_viewport().get_visible_rect().size.x
			var region := clampi(int(center.x / maxf(1, width / 3)), 0, 2)
			for other in popups:
				if other.visible and other != label:
					var other_center := camera.unproject_position(other.global_position)
					if clampi(int(other_center.x / maxf(1, width / 3)), 0, 2) == region: other.visible = false
	label.text = text
	label.font_size = mini(size, 64)
	label.modulate = color
	label.position = pos
	label.visible = true
	label.set_meta("life", 1.0)

func sync(sim: RunSim, dt: float) -> void:
	elapsed += dt
	gate_clarity = bool(sim.flags.get("gate_clarity", false))
	if sim.flags.get("horde_scaling", false) and enemy_nodes.size() < 48:
		while enemy_nodes.size() < 48:
			var enemy_node := MeshFactory.instance(MeshFactory.enemy("scrapper")); enemy_node.visible = false; add_child(enemy_node); enemy_nodes.append(enemy_node)
		crowd_scrappers.multimesh.instance_count = 48
		shadows.multimesh.instance_count = 49
	if gate_clarity and hook_eyes == null:
		var lens := SphereMesh.new(); lens.radius = 0.09; lens.height = 0.18; lens.radial_segments = 6; lens.rings = 3
		var glow := StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow.albedo_color = Color("ff554f"); glow.emission_enabled = true; glow.emission = Color("ed3333"); lens.material = glow
		hook_eyes = make_multimesh(lens, 96)
		var disc := CylinderMesh.new(); disc.top_radius = 1.0; disc.bottom_radius = 1.0; disc.height = 0.01; disc.radial_segments = 20
		var under := StandardMaterial3D.new(); under.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; under.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; under.albedo_color = Color(0.1,0.65,0.95,0.12); disc.material = under
		hook_underglow = MeshInstance3D.new(); hook_underglow.mesh = disc; add_child(hook_underglow)
	if hook_eyes != null:
		hook_eyes.visible = gate_clarity; hook_eyes.multimesh.visible_instance_count = 0
		hook_underglow.visible = gate_clarity; hook_underglow.position = Vector3(sim.x,0.015,0); hook_underglow.scale = Vector3(1.2,1,1.4)
	player.position.x = sim.x
	player.position.y = absf(sin(elapsed * 9.0)) * 0.035 if sim.state in ["running", "boss"] and not reduce_motion else 0.0
	var lean := (sim.x - sim.target_x) * 0.05
	player.rotation.z = lerpf(player.rotation.z, lean if absf(lean) > 0.004 else 0.0, 0.2)
	if "compact_layout" in player: player.set("compact_layout", gate_clarity)
	player.sync(sim.robot)
	player.drive_speed = (float(sim.robot.stats.fwd_mult) * (0.6 if sim.oil_time > 0 else 1.0)) if sim.state == "running" else (0.3 if sim.state == "boss" else 0.0)
	player.steer = clampf(sim.target_x - sim.x, -1.5, 1.5)
	var moving: bool = sim.state in ["running", "boss"]
	dust_fx.position = Vector3(sim.x, 0.25, 0.8)
	dust_fx.emitting = moving and not reduce_motion and not (ui_feedback != null and ui_feedback.duck)
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
			label.scale = Vector3.ONE
			if life <= 0:
				label.visible = false
	flame_fx.position = Vector3(sim.x, 1.0, -0.9)
	flame_fx.emitting = sim.robot.parts.has("flame") and (sim.state == "boss" or not sim.enemies.is_empty()) and not reduce_motion
	# Leave the playable surface clear. Sparse matte salvage keeps the junkyard setting outside it.
	stripes.multimesh.visible_instance_count = 0
	skids.multimesh.visible_instance_count = 0
	road.material_override.set_shader_parameter("travel", sim.z)
	for k in scenery_sets.size():
		var set_mesh := scenery_sets[k].multimesh
		set_mesh.visible_instance_count = 4 if k in [0, 1, 4] else 0
		for j in set_mesh.visible_instance_count:
			var side := -1 if (j + k) % 2 == 0 else 1
			var size := 0.85 if k == 4 else 1.0
			var basis := Basis(Vector3.UP, float(j) * 1.7).scaled(Vector3.ONE * size)
			var offset := 10.0 + float(k) * 1.1 + float(j % 2) * 1.8
			var pos := Vector3(side * offset, 0, 14.0 - fposmod(float(j) * 48.0 + float(k) * 11.0 - sim.z, 192.0))
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
	var shot_count := 0
	var bomblet_count := 0
	for bullet in sim.bullets:
		var at := Vector3(bullet.x, 1.1, sim.z - float(bullet.z))
		if bullet.type == "cluster":
			if bomblet_count < 16:
				bomblets.multimesh.set_instance_transform(bomblet_count, Transform3D(Basis(), at))
				bomblet_count += 1
		elif shot_count < 64:
			projectiles.multimesh.set_instance_transform(shot_count, Transform3D(Basis(), at))
			shot_count += 1
	projectiles.multimesh.visible_instance_count = shot_count
	bomblets.multimesh.visible_instance_count = bomblet_count
	_sync_drones(sim)
	hostile_projectiles.multimesh.visible_instance_count = sim.hostile_bullets.size()
	for i in sim.hostile_bullets.size():
		var bolt: Dictionary = sim.hostile_bullets[i]
		hostile_projectiles.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(bolt.x, 0.9, sim.z - float(bolt.z))))
	shadows.multimesh.visible_instance_count = sim.enemies.size() + 1
	shadows.multimesh.set_instance_transform(0, Transform3D(Basis().scaled(Vector3(1.2, 1, 1.3)), Vector3(sim.x, 0.025, 0)))
	var crowd_count := 0
	for i in enemy_nodes.size():
		var node := enemy_nodes[i]
		node.visible = i < sim.enemies.size()
		if node.visible:
			var enemy: Dictionary = sim.enemies[i]
			var size := (1.0 if gate_clarity else 0.75) if enemy.id == "scrapper" else (1.35 if enemy.id == "hauler" else 1.0)
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
			if gate_clarity and reduce_motion: hop = 0.0; node.rotation.z = 0
			node.position = Vector3(enemy.x, hop, sim.z - float(enemy.z))
			if gate_clarity and enemy.id in ["scrapper", "gunner", "bruiser"]:
				var at_eye := hook_eyes.multimesh.visible_instance_count
				for side in [-1,1]:
					if at_eye < 96:
						hook_eyes.multimesh.set_instance_transform(at_eye, Transform3D(Basis().scaled(Vector3.ONE * size), node.position + Vector3(side*0.16*size,0.9*size,0.65*size)))
						at_eye += 1
				hook_eyes.multimesh.visible_instance_count = at_eye
			var last_hp: float = node.get_meta("hp", float(enemy.hp))
			if float(enemy.hp) < last_hp - 0.01:
				if not ui_v2_enabled or (not reduce_motion and flash_rate > 0 and elapsed - float(node.get_meta("flash_at", -10.0)) >= 1.0 / flash_rate + 0.002):
					node.set_meta("flash", 1.0)
					node.set_meta("flash_at", elapsed)
			node.set_meta("hp", float(enemy.hp))
			var flash_value: float = maxf(0.0, float(node.get_meta("flash", 0.0)) - dt * 6.0)
			if ui_v2_enabled and (reduce_motion or flash_rate == 0): flash_value = 0
			node.set_meta("flash", flash_value)
			node.set_instance_shader_parameter("flash", flash_value)
			if sim.mob != null and enemy.id == "scrapper":
				crowd_scrappers.multimesh.set_instance_transform(crowd_count, node.transform)
				crowd_scrappers.multimesh.set_instance_custom_data(crowd_count, Color(flash_value, 0, 0, 1))
				crowd_count += 1
				node.visible = false
			shadows.multimesh.set_instance_transform(i + 1, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3(enemy.x, 0.025, node.position.z)))
	crowd_scrappers.multimesh.visible_instance_count = crowd_count
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
	evolution_level = int(sim.flags.tuning.evolution_rocket_level) if sim.flags.weapon_evolution else 0
	sim_t1 = float(sim.flags.tuning.charge_t1)
	sim_t2 = float(sim.flags.tuning.charge_t2)
	_update_charge(gate, sim.robot)
	for child in gate_root.get_children():
		if child.has_meta("spin"):
			child.rotation.y = elapsed * 2.0
	gate_root.visible = not gate.is_empty() and sim.state == "running" and float(gate.z) - sim.z <= 62.0
	if not gate.is_empty():
		gate_root.position.z = sim.z - float(gate.z)
		gate_root.position.x = sim.gate_offset(gate, sim.t)
	gate_rail.visible = gate_root.visible and gate.get("moving", false)
	if gate_rail.visible:
		gate_rail.position.z = sim.z - float(gate.z)
		var travel: float = 2.0 * (float(sim.flags.tuning.moving_amplitude) + 1.4 + float(sim.flags.tuning.moving_half))
		gate_rail.scale = Vector3(travel, 1, 1)
	_sync_mob_gates(sim)
	gate_clarity = bool(sim.flags.get("gate_clarity", false))
	if gate_clarity:
		if hook_gates == null: hook_gates = HookGateScript.new(); add_child(hook_gates)
		hook_gates.visible = true; hook_gates.sync(self, sim, dt)
		gate_root.visible = false; gate_rail.visible = false
		for slot in mob_gate_nodes: slot.root.visible = false; slot.rail.visible = false
	elif hook_gates != null: hook_gates.visible = false
	boss_root.visible = sim.boss != null
	if boss_root.visible:
		boss_root.position.y = 0.0 if reduce_motion else sin(elapsed * 2) * 0.06
		boss_root.rotation.z = 0.0 if reduce_motion else sin(elapsed * 1.3) * 0.018
		boss_plate.visible = sim.boss.phase == 1
		boss_arm.visible = sim.boss.arm_hp > 0 or sim.boss.attack == "grabber_arm"
		boss_core.scale = Vector3.ONE if reduce_motion else Vector3.ONE * (1.1 + sin(elapsed * 6) * 0.1)
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
					node.position = Vector3((edge + outer) / 2, 0.04, -10.5 if ui_v2_enabled else -1.5)
					node.scale = Vector3(maxf(0.1, absf(outer - edge)), 0.025, 7)
					warning_index += 1
			else:
				node.position = Vector3(zone.x, 0.045, -10.5 if ui_v2_enabled else -1.2)
				node.mesh = circle_warning if zone.shape == "circle" else box_warning
				node.scale = Vector3(width, 0.025, width if zone.shape == "circle" else 5.5)
				warning_index += 1
	for enemy in sim.enemies:
		if enemy.warning and warning_index < warnings.size():
			var node := warnings[warning_index]
			node.visible = true
			node.mesh = box_warning
			node.position = Vector3(enemy.aim_x, 0.05, -10.5 if ui_v2_enabled else -1.8)
			node.scale = Vector3(1.8, 0.025, 6)
			warning_index += 1
	for i in warning_index:
		if ui_v2_enabled and ui_feedback != null:
			warnings[i].material_override = ui_feedback.danger_material
		else:
			warnings[i].material_override = default_warning_material
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
	if ui_v2_enabled and ui_feedback != null: ui_feedback.sync(self, sim, dt)

func configure_ui_v2(enabled: bool, reduced: bool, limit: int) -> void:
	ui_v2_enabled = enabled; reduce_motion = enabled and reduced; flash_rate = clampi(limit, 0, 3)
	player.reduced_motion = reduce_motion
	road.material_override = MeshFactory.industrial_road_palette() if enabled else MeshFactory.road_palette()
	if enabled and ui_feedback == null:
		ui_feedback = UiWorldScript.new(); add_child(ui_feedback)
	if ui_feedback != null:
		ui_feedback.visible = enabled; ui_feedback.reduced = reduce_motion; ui_feedback.flash_limit = flash_rate
	if reduce_motion:
		fx_items.clear(); player.flash_amount = 0
