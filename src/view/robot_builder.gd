class_name RobotBuilder extends Node3D
var mounts: MeshInstance3D
var body: MeshInstance3D
var head_pivot: Node3D
var head: MeshInstance3D
var antenna_pivot: Node3D
var wheels: Array[MeshInstance3D] = []
var sockets: Dictionary = {}
var attachments: Dictionary = {}
var hook_materials_enabled := false
var compact_layout := false
var compact_was_enabled := false
var material_levels: Dictionary = {}
var material_ascending: Dictionary = {}
var material_signature := 0
var hook_was_enabled := false
var forge_family := ""
var forge_time := 0.0
var forge_duration := 0.55
var signature := ""
var stage_value := 0
var growth_tween: Tween
# Driven by the world view; the hangar models keep the idle defaults.
var drive_speed := 0.0
var steer := 0.0
var fire_kick := 0.0
var reduced_motion := false:
	set(value):
		if value and not reduced_motion:
			if growth_tween != null: growth_tween.kill()
			if stage_value > 0: scale = Vector3.ONE * [0.85, 1.12, 1.4][stage_value - 1]
			for node in attachments.values():
				var tween = node.get_meta("attach_tween") if node.has_meta("attach_tween") else null
				if tween != null and tween.is_valid(): tween.kill()
				node.position = Vector3.ZERO; node.scale = Vector3.ONE
			flash_amount = 0
			for node in [body, head] + wheels:
				if node != null: node.set_instance_shader_parameter("flash", 0.0)
		reduced_motion = value
var flash_amount := 0.0
var clock := 0.0
var wheel_spin := 0.0
var head_swing := 0.0
var antenna_swing := 0.0
var last_steer := 0.0
const POSITIONS = {"wheel_fl": Vector3(0, 0.3, 0), "wheel_fr": Vector3(0, 0.3, 0), "wheel_bl": Vector3(0, 0.3, 0), "wheel_br": Vector3(0, 0.3, 0), "wheel_ml": Vector3(0, 0.3, 0), "wheel_mr": Vector3(0, 0.3, 0), "top_c": Vector3(0, 1.3, -1.15), "top_l": Vector3(-1.15, 1.7, -0.6), "top_r": Vector3(1.15, 1.7, -0.6), "side_l": Vector3(-1.35, 1.0, 0), "side_r": Vector3(1.35, 1.0, 0), "back_c": Vector3(0, 1.0, 1.25), "front_c": Vector3(0, 0.8, -1.1), "shoulder_l": Vector3(-1.3, 1.7, 0.3), "shoulder_r": Vector3(1.3, 1.7, 0.3), "head": Vector3(0, 1.65, 1.3)}


func _ready() -> void:
	body = MeshFactory.instance(MeshFactory.chassis_body(1))
	add_child(body)
	mounts = MeshFactory.instance(MeshFactory.chassis_body(1))
	mounts.visible = false
	add_child(mounts)
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.32, -0.1)
	add_child(head_pivot)
	head = MeshFactory.instance(MeshFactory.head(1))
	head_pivot.add_child(head)
	antenna_pivot = Node3D.new()
	antenna_pivot.position = Vector3(0.18, 0.62, 0.0)
	head_pivot.add_child(antenna_pivot)
	antenna_pivot.add_child(MeshFactory.instance(MeshFactory.antenna()))
	for dz in [-0.48, 0.5]:
		for side in [-1, 1]:
			var wheel := MeshFactory.instance(MeshFactory.wheel_mesh())
			wheel.position = Vector3(side * 0.66, 0.33, dz)
			add_child(wheel)
			wheels.append(wheel)
	for id in POSITIONS:
		var socket := Marker3D.new()
		socket.name = id
		socket.position = POSITIONS[id]
		add_child(socket)
		sockets[id] = socket

func flash() -> void:
	flash_amount = 1.0

func _process(delta: float) -> void:
	if body == null:
		return
	_tick_forge(delta)
	if reduced_motion:
		body.position = Vector3.ZERO
		body.rotation.z = -steer * 0.05
		head_pivot.rotation = Vector3.ZERO
		head_pivot.position.y = 1.32
		antenna_pivot.rotation = Vector3.ZERO
		return
	clock += delta
	# Wheels roll with the drive speed; idle models still tick over slowly.
	wheel_spin += delta * (drive_speed * 3.0 + 1.5)
	for wheel in wheels:
		wheel.rotation.x = -wheel_spin
	# Body: engine rumble, squash when firing, roll with steering.
	var rumble := sin(clock * 24.0) * 0.008 * (0.4 + drive_speed * 0.1)
	body.position.y = rumble + sin(clock * 2.0) * 0.012
	body.rotation.z = -steer * 0.12
	fire_kick = lerpf(fire_kick, 0.0, minf(1.0, delta * 12.0))
	body.position.z = fire_kick * 0.1
	# Head lags behind steering like it has weight, bobs on the bumps and looks around when idle.
	var look := sin(clock * 0.9) * 0.35 if drive_speed < 0.5 else 0.0
	head_swing = lerpf(head_swing, -steer * 0.5 + look, minf(1.0, delta * 8.0))
	head_pivot.rotation.y = head_swing
	head_pivot.rotation.z = lerpf(head_pivot.rotation.z, -steer * 0.25, minf(1.0, delta * 6.0))
	head_pivot.position.y = 1.32 + sin(clock * 11.0) * 0.015 * minf(drive_speed, 1.0) + sin(clock * 2.0) * 0.012
	head_pivot.rotation.x = -fire_kick * 0.18
	# Antenna whips behind the head: spring toward steering velocity.
	var steer_speed := (steer - last_steer) / maxf(delta, 0.001)
	last_steer = steer
	antenna_swing = lerpf(antenna_swing, clampf(-steer_speed * 0.08, -0.6, 0.6), minf(1.0, delta * 10.0))
	antenna_pivot.rotation.z = antenna_swing + sin(clock * 9.0) * 0.1 * minf(drive_speed, 1.0) + sin(clock * 2.3) * 0.05
	antenna_pivot.rotation.x = 0.12 * minf(drive_speed, 1.0) + sin(clock * 3.1) * 0.04
	flash_amount = maxf(0.0, flash_amount - delta * 5.0)
	for node in [body, head] + wheels:
		node.set_instance_shader_parameter("flash", flash_amount)

func sync(robot: RobotState, animate := true) -> void:
	animate = animate and not reduced_motion
	var key := JSON.stringify(robot.parts) + str(robot.stage()) + JSON.stringify(robot.slots) + JSON.stringify(robot.tiers)
	var material_key := material_levels.hash() if hook_materials_enabled else 0
	if hook_materials_enabled:
		for id in attachments:
			var amount := clampf(float(material_ascending.get(id, 0)), 0, 1)
			if bool(attachments[id].get_meta("hook_materials", false)) and float(attachments[id].get_meta("ascending", -1)) != amount:
				attachments[id].set_instance_shader_parameter("ascending", amount)
				attachments[id].set_meta("ascending", amount)
	if key == signature and hook_was_enabled == hook_materials_enabled and material_signature == material_key and compact_was_enabled == compact_layout:
		return
	signature = key
	hook_was_enabled = hook_materials_enabled; material_signature = material_key; compact_was_enabled = compact_layout
	var changed_stage := stage_value != robot.stage()
	stage_value = robot.stage()
	body.mesh = MeshFactory.chassis_body(stage_value)
	head.mesh = MeshFactory.head(stage_value)
	var size: float = [0.85, 1.12, 1.4][stage_value - 1]
	if growth_tween != null:
		growth_tween.kill()
	if changed_stage and animate and is_inside_tree():
		scale = Vector3.ONE * size * 0.7
		growth_tween = create_tween()
		growth_tween.tween_property(self, "scale", Vector3.ONE * size, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = Vector3.ONE * size
	for id in attachments.keys():
		if not robot.parts.has(id):
			attachments[id].queue_free()
			attachments.erase(id)
	for slot in robot.slots:
		var id: String = robot.slots[slot]
		var level: int = int(robot.parts[id])
		var tier := int(robot.tiers.get(id, 1))
		if attachments.has(id) and int(attachments[id].get_meta("level")) == level and int(attachments[id].get_meta("tier", 1)) == tier and bool(attachments[id].get_meta("hook_materials", false)) == hook_materials_enabled:
			if attachments[id].get_parent() != sockets[slot]:
				attachments[id].reparent(sockets[slot], false)
			if hook_materials_enabled:
				var quality := clampi(int(material_levels.get(id, 1)), 1, 4)
				attachments[id].mesh = MeshFactory.hook_part(id, level, quality, tier)
				attachments[id].set_instance_shader_parameter("tier", float(quality))
				attachments[id].set_instance_shader_parameter("ascending", float(material_ascending.get(id, 0)))
			continue
		if attachments.has(id):
			attachments[id].queue_free()
		var quality := clampi(int(material_levels.get(id, 1)), 1, 4)
		var node := MeshFactory.instance(MeshFactory.hook_part(id, level, quality, tier) if hook_materials_enabled else MeshFactory.part(id, level))
		node.set_meta("hook_materials", hook_materials_enabled)
		if hook_materials_enabled:
			node.set_instance_shader_parameter("tier", float(quality))
			node.set_instance_shader_parameter("forge", 0.0)
			node.set_instance_shader_parameter("ascending", float(material_ascending.get(id, 0)))
		node.set_meta("level", level)
		node.set_meta("tier", tier)
		sockets[slot].add_child(node)
		if tier >= 3 and not hook_materials_enabled:
			var trim := MeshFactory.instance(MeshFactory.merged([MeshFactory.box(Vector3(0.1, 0.15, 0.5), Vector3(-0.18, 0.28, 0), MeshFactory.YELLOW if tier < 5 else MeshFactory.BLUE), MeshFactory.box(Vector3(0.1, 0.15, 0.5), Vector3(0.18, 0.28, 0), MeshFactory.YELLOW if tier < 5 else MeshFactory.BLUE)]))
			node.add_child(trim)
		attachments[id] = node
		if animate:
			node.position.y = 1.5
			node.scale = Vector3.ONE * 0.2
			var tween := node.create_tween().set_parallel(true)
			node.set_meta("attach_tween", tween)
			tween.tween_property(node, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(node, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for wheel in wheels:
		wheel.visible = not robot.parts.has("wheels") and not robot.parts.has("tracks")
	_layout_attachments(robot)

func attachment_bounds(id: String) -> AABB:
	var node: MeshInstance3D = attachments[id]
	var bounds := node.mesh.get_aabb()
	for child in node.get_children():
		if child is MeshInstance3D:
			bounds = bounds.merge(child.transform * child.mesh.get_aabb())
	return AABB(bounds.position + node.get_parent().position, bounds.size)

func _layout_attachments(robot: RobotState) -> void:
	# Keep the animated head/antenna envelope and attachment envelopes disjoint.
	# Body mount contact is intentional; these are visual clearances, not combat hitboxes.
	var occupied: Array[AABB] = [AABB(Vector3(-0.9, 1.05, -0.9), Vector3(1.8, 1.75, 1.8))]
	var ids: Array = attachments.keys()
	ids.sort_custom(func(a, b):
		var a_move: bool = GameData.table("parts")[a].category == "movement"
		var b_move: bool = GameData.table("parts")[b].category == "movement"
		return a_move if a_move != b_move else str(a) < str(b))
	for id in ids:
		var node: MeshInstance3D = attachments[id]
		var socket: Node3D = node.get_parent()
		socket.position = POSITIONS[str(socket.name)]
		var direction := Vector3(0, 0, -1)
		var slot := str(socket.name)
		if slot.begins_with("wheel"):
			socket.position.y = -node.mesh.get_aabb().position.y + 0.035
			direction = Vector3.BACK
		elif slot == "back_c": direction = Vector3.BACK
		elif slot == "head": direction = Vector3.UP
		elif slot.ends_with("_l"): direction = Vector3.LEFT
		elif slot.ends_with("_r"): direction = Vector3.RIGHT
		if (hook_materials_enabled or compact_layout) and _compact_socket(id, occupied):
			occupied.append(attachment_bounds(id).grow(0.035))
			continue
		for attempt in 80:
			var bounds := attachment_bounds(id).grow(0.035)
			var overlap := false
			for other in occupied:
				if bounds.intersects(other):
					overlap = true
					break
			if not overlap:
				break
			socket.position += direction * 0.1
		occupied.append(attachment_bounds(id).grow(0.035))
	var supports: Array = []
	for id in ids:
		if GameData.table("parts")[id].category == "movement": continue
		var target: Vector3 = attachments[id].get_parent().position
		var anchor := Vector3(clampf(target.x, -0.5, 0.5), clampf(target.y, 0.6, 1.1), clampf(target.z, -0.45, 0.45))
		var offset := target - anchor
		if offset.length() > 0.05:
			var rotation := Basis(Quaternion(Vector3.UP, offset.normalized())).get_euler()
			supports.append(MeshFactory.cylinder(0.06, offset.length(), (anchor + target) / 2, MeshFactory.STEEL, rotation, -1.0, 6))
			supports.append(MeshFactory.box(Vector3(0.3, 0.15, 0.15), target, MeshFactory.STEEL))
	mounts.visible = not supports.is_empty()
	if mounts.visible: mounts.mesh = MeshFactory.merged(supports)

func visual_bounds() -> AABB:
	var bounds := body.mesh.get_aabb()
	bounds = bounds.merge(head_pivot.transform * head.mesh.get_aabb())
	for wheel in wheels:
		if wheel.visible: bounds = bounds.merge(wheel.transform * wheel.mesh.get_aabb())
	for id in attachments: bounds = bounds.merge(attachment_bounds(id))
	return AABB(bounds.position * scale, bounds.size * scale)

# A forge moment travels once along the current family; no brightness oscillation or camera effect.
func forge(family: String, _quality: int) -> void:
	if not forge_family.is_empty() and attachments.has(forge_family) and bool(attachments[forge_family].get_meta("hook_materials", false)):
		attachments[forge_family].set_instance_shader_parameter("forge", 0.0)
	forge_family = family
	forge_time = forge_duration if hook_materials_enabled and not reduced_motion else 0.0

func _tick_forge(delta: float) -> void:
	if forge_time <= 0: return
	forge_time = 0.0 if reduced_motion or not hook_materials_enabled else maxf(0.0, forge_time - delta)
	if attachments.has(forge_family) and bool(attachments[forge_family].get_meta("hook_materials", false)):
		attachments[forge_family].set_instance_shader_parameter("forge", clampf(1.0 - forge_time / forge_duration, 0.001, 0.999) if forge_time > 0 else 0.0)

# Preserve the named socket and all clearance envelopes, but search forward/up as well as sideways.
# This runs only on a build change; no frame-time packing or physics/hitbox changes.
func _compact_socket(id: String, occupied: Array[AABB]) -> bool:
	var socket: Node3D = attachments[id].get_parent()
	var origin := socket.position
	var movement: bool = GameData.table("parts")[id].category == "movement"
	var best := INF
	var chosen := origin
	var sign_x := -1.0 if origin.x < 0 else 1.0
	for dy in ([0.0] if movement else [0.0, 0.35, 0.7, 1.05, 1.4, 1.75, 2.1, -0.35, -0.7]):
		for dz in [0.0, -0.35, 0.35, -0.7, 0.7, -1.05, 1.05, -1.4, 1.4, -1.75, 1.75, -2.1, 2.1, -2.45, 2.45]:
			for dx in ([0.0] if movement else [0.0, 0.25, 0.5]):
				var offset := Vector3(float(dx) * sign_x, float(dy), float(dz))
				var score := offset.x * offset.x * 2.5 + offset.y * offset.y * 1.3 + offset.z * offset.z
				if score >= best: continue
				socket.position = origin + offset
				var bounds := attachment_bounds(id).grow(0.035)
				if bounds.position.x < -2.6 or bounds.end.x > 2.6 or bounds.position.y < 0 or bounds.end.y > 4.8: continue
				var overlap := false
				for other in occupied:
					if bounds.intersects(other): overlap = true; break
				if not overlap: best = score; chosen = socket.position
	socket.position = chosen if best < INF else origin
	return best < INF
