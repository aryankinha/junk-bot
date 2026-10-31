class_name WorldView extends Node3D
var road: MeshInstance3D
var stripes: MultiMeshInstance3D
var scenery: MultiMeshInstance3D
var scrap: MultiMeshInstance3D
var projectiles: MultiMeshInstance3D
var hostile_projectiles: MultiMeshInstance3D
var shadows: MultiMeshInstance3D
var fx: MultiMeshInstance3D
var fx_items: Array = []
var flame_fx: CPUParticles3D
var player: RobotBuilder
var enemy_nodes: Array[MeshInstance3D] = []
var hazard_nodes: Array[MeshInstance3D] = []
var warnings: Array[MeshInstance3D] = []
var gate_root: Node3D
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
var floor_color := Color("dfbd87")

func _ready() -> void:
	circle_warning = CylinderMesh.new()
	circle_warning.top_radius = 0.5
	circle_warning.bottom_radius = 0.5
	circle_warning.height = 1.0
	circle_warning.radial_segments = 32
	road = MeshFactory.instance(MeshFactory.merged([
		MeshFactory.box(Vector3(120, 0.3, 190), Vector3(0, -0.35, -55), floor_color),
		MeshFactory.box(Vector3(7.4, 0.12, 150), Vector3(0, -0.1, -50), Color("6d777b")),
		MeshFactory.box(Vector3(0.18, 0.15, 150), Vector3(-3.8, 0, -50), MeshFactory.ORANGE),
		MeshFactory.box(Vector3(0.18, 0.15, 150), Vector3(3.8, 0, -50), MeshFactory.ORANGE)]))
	add_child(road)
	stripes = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.08, 0.012, 2.2), Vector3.ZERO, Color("d8d9c6"))]), 80)
	var wreck := MeshFactory.merged([MeshFactory.box(Vector3(1.7, 0.8, 2.8), Vector3(0, 0.5, 0), MeshFactory.STEEL), MeshFactory.box(Vector3(1.45, 0.65, 1.3), Vector3(0, 1.2, -0.15), MeshFactory.ORANGE), MeshFactory.box(Vector3(1.47, 0.38, 0.12), Vector3(0, 1.25, -0.85), MeshFactory.DARK)])
	scenery = make_multimesh(wreck, 64)
	scrap_mesh = MeshFactory.merged([MeshFactory.cylinder(0.15, 0.12, Vector3.ZERO, MeshFactory.YELLOW), MeshFactory.box(Vector3(0.1, 0.22, 0.1), Vector3.ZERO, MeshFactory.LIGHT)])
	scrap = make_multimesh(scrap_mesh, 400)
	projectiles = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.1, 0.1, 0.45), Vector3.ZERO, MeshFactory.YELLOW)]), 64)
	hostile_projectiles = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.16, 0.16, 0.55), Vector3.ZERO, MeshFactory.RED)]), 16)
	shadows = make_multimesh(MeshFactory.merged([MeshFactory.cylinder(0.65, 0.01, Vector3.ZERO, Color("424b50"))]), 26)
	fx = make_multimesh(MeshFactory.merged([MeshFactory.box(Vector3(0.14, 0.14, 0.14), Vector3.ZERO, MeshFactory.ORANGE)]), 96)
	player = RobotBuilder.new()
	add_child(player)
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
		var node := MeshFactory.instance(MeshFactory.chassis(1, true))
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
	boss_core = MeshFactory.instance(MeshFactory.merged([MeshFactory.cylinder(0.7, 0.22, Vector3.ZERO, MeshFactory.RED, Vector3(PI / 2, 0, 0))]))
	boss_core.position = Vector3(0, 3.6, 1.12)
	boss_root.add_child(boss_core)
	boss_plate = MeshFactory.instance(MeshFactory.merged([MeshFactory.box(Vector3(2.5, 1.7, 0.3), Vector3.ZERO, MeshFactory.LIGHT), MeshFactory.box(Vector3(0.4, 1.7, 0.32), Vector3.ZERO, MeshFactory.ORANGE)]))
	boss_plate.position = Vector3(0, 3.4, 1.4)
	boss_root.add_child(boss_plate)
	boss_arm = MeshFactory.instance(MeshFactory.merged([MeshFactory.box(Vector3(0.7, 0.7, 6), Vector3.ZERO, MeshFactory.ORANGE)]))
	boss_arm.position = Vector3(2.8, 2.1, 4)
	boss_root.add_child(boss_arm)
	boss_root.visible = false

func make_multimesh(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
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

func rebuild_gate(gate: Dictionary) -> void:
	for child in gate_root.get_children():
		child.queue_free()
	if gate.is_empty():
		return
	var options: Array = gate.options
	var width := 6.8 / options.size()
	for i in options.size():
		var option: Dictionary = options[i]
		var dx: float = -3.4 + width * (i + 0.5)
		var tone := Color("43b975") if option.kind == "part" else (Color("9b72c7") if option.kind == "gamble" else MeshFactory.ORANGE)
		var mesh := MeshFactory.instance(MeshFactory.merged([
			MeshFactory.box(Vector3(width - 0.12, 0.16, 0.16), Vector3(dx, 3.2, 0), tone),
			MeshFactory.box(Vector3(width - 0.22, 1.22, 0.16), Vector3(dx, 2.55, 0), MeshFactory.DARK),
			MeshFactory.box(Vector3(0.1, 3.2, 0.15), Vector3(dx - width / 2 + 0.08, 1.6, 0), tone),
			MeshFactory.box(Vector3(0.1, 3.2, 0.15), Vector3(dx + width / 2 - 0.08, 1.6, 0), tone),
			MeshFactory.box(Vector3(width - 0.15, 0.04, 0.6), Vector3(dx, 0.04, 0), tone)]))
		gate_root.add_child(mesh)
		var name_label := label3d(GateGen.label(option).to_upper().replace(" ", "\n") if options.size() == 3 else GateGen.label(option).to_upper(), Vector3(dx, 2.72, 0.12), 45 if options.size() == 3 else 56)
		gate_root.add_child(name_label)
		var desc := label3d(GateGen.description(option), Vector3(dx, 2.08, 0.12), 24 if options.size() == 3 else 30)
		gate_root.add_child(desc)
		if option.kind == "part":
			var icon := MeshFactory.instance(MeshFactory.part(str(option.id), 1))
			icon.position = Vector3(dx, 1.2, 0)
			icon.scale = Vector3.ONE * 0.85
			gate_root.add_child(icon)

func burst(pos: Vector3, count := 8) -> void:
	for i in mini(count, 96 - fx_items.size()):
		fx_items.append({"pos": pos, "vel": Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)), "life": randf_range(0.35, 0.8)})

func sync(sim: RunSim, dt: float) -> void:
	elapsed += dt
	player.position.x = sim.x
	player.rotation.z = lerpf(player.rotation.z, (sim.x - sim.target_x) * 0.08, 0.15)
	player.sync(sim.robot)
	flame_fx.position = Vector3(sim.x, 1.0, -0.9)
	flame_fx.emitting = sim.robot.parts.has("flame") and (sim.state == "boss" or not sim.enemies.is_empty())
	stripes.multimesh.visible_instance_count = 80
	for i in 80:
		var distance := fposmod(float(i / 2) * 4.5 - sim.z, 180.0)
		stripes.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(-1.15 if i % 2 == 0 else 1.15, 0.01, 8 - distance)))
	scenery.multimesh.visible_instance_count = 64
	for i in 64:
		var side := -1 if i % 2 == 0 else 1
		var sz := 0.7 + float(i % 4) * 0.22
		var basis := Basis(Vector3.UP, i * 1.7).scaled(Vector3.ONE * sz)
		var pos := Vector3(side * (6.2 + float(i % 5) * 2.0), 0, 14 - fposmod(float(i / 2) * 6 - sim.z * 0.95, 192))
		scenery.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	var count := 0
	for node in sim.scrap_nodes:
		if node.alive and float(node.z) > sim.z - 4 and float(node.z) < sim.z + 65:
			scrap.multimesh.set_instance_transform(count, Transform3D(Basis(Vector3.UP, elapsed * 2 + count), Vector3(node.x, 0.35 + sin(elapsed * 4 + count) * 0.1, sim.z - float(node.z))))
			count += 1
	scrap.multimesh.visible_instance_count = count
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
			var size := 0.5 if enemy.id == "scrapper" else (1.6 if enemy.id == "elite_bruiser" else 0.9)
			node.scale = Vector3.ONE * size
			if node.get_meta("kind", "") != enemy.id:
				node.set_meta("kind", enemy.id)
				node.mesh = MeshFactory.hazard("barrel") if enemy.id == "barrel" else MeshFactory.chassis(1, true)
			node.position = Vector3(enemy.x, sin(elapsed * 8 + i) * 0.04, sim.z - float(enemy.z))
			node.rotation.y = PI
			shadows.multimesh.set_instance_transform(i + 1, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3(enemy.x, 0.025, node.position.z)))
	for i in hazard_nodes.size():
		hazard_nodes[i].visible = i < sim.hazards.size() and not sim.hazards[i].used
		if hazard_nodes[i].visible:
			var hazard: Dictionary = sim.hazards[i]
			hazard_nodes[i].mesh = MeshFactory.hazard(str(hazard.id))
			hazard_nodes[i].position = Vector3(hazard.x, 0.2, sim.z - float(hazard.z))
			hazard_nodes[i].rotation.y += dt * 8
	var gate := sim.next_gate()
	var sig := JSON.stringify(gate.get("options", [])) + str(gate.get("z", -1))
	if sig != gate_signature:
		gate_signature = sig
		rebuild_gate(gate)
	gate_root.visible = not gate.is_empty() and sim.state == "running"
	if not gate.is_empty():
		gate_root.position.z = sim.z - float(gate.z)
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
