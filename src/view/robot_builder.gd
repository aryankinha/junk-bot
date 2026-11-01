class_name RobotBuilder extends Node3D
var body: MeshInstance3D
var head_pivot: Node3D
var head: MeshInstance3D
var antenna_pivot: Node3D
var wheels: Array[MeshInstance3D] = []
var sockets: Dictionary = {}
var attachments: Dictionary = {}
var signature := ""
var stage_value := 0
# Driven by the world view; the hangar models keep the idle defaults.
var drive_speed := 0.0
var steer := 0.0
var fire_kick := 0.0
var flash_amount := 0.0
var clock := 0.0
var wheel_spin := 0.0
var head_swing := 0.0
var antenna_swing := 0.0
var last_steer := 0.0
const POSITIONS = {"wheel_fl": Vector3(0, 0.3, 0), "wheel_fr": Vector3(0, 0.3, 0), "wheel_bl": Vector3(0, 0.3, 0), "wheel_br": Vector3(0, 0.3, 0), "wheel_ml": Vector3(0, 0.3, 0), "wheel_mr": Vector3(0, 0.3, 0), "top_c": Vector3(0, 1.18, -0.3), "top_l": Vector3(-0.55, 1.2, -0.2), "top_r": Vector3(0.55, 1.2, -0.2), "side_l": Vector3(-0.85, 0.9, -0.2), "side_r": Vector3(0.85, 0.9, -0.2), "back_c": Vector3(0, 1.0, 0.6), "front_c": Vector3(0, 0.75, -0.8), "shoulder_l": Vector3(-0.8, 1.1, 0), "shoulder_r": Vector3(0.8, 1.1, 0), "head": Vector3(0, 1.85, 0)}

func _ready() -> void:
	body = MeshFactory.instance(MeshFactory.chassis_body(1))
	add_child(body)
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
	var key := JSON.stringify(robot.parts) + str(robot.stage()) + JSON.stringify(robot.slots) + JSON.stringify(robot.tiers)
	if key == signature:
		return
	signature = key
	var changed_stage := stage_value != robot.stage()
	stage_value = robot.stage()
	body.mesh = MeshFactory.chassis_body(stage_value)
	head.mesh = MeshFactory.head(stage_value)
	var size: float = [0.85, 1.12, 1.4][stage_value - 1]
	if changed_stage and animate and is_inside_tree():
		scale = Vector3.ONE * size * 0.7
		create_tween().tween_property(self, "scale", Vector3.ONE * size, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = Vector3.ONE * size
	for id in attachments.keys():
		if not robot.parts.has(id):
			attachments[id].queue_free()
			attachments.erase(id)
	for slot in robot.slots:
		var id: String = robot.slots[slot]
		var level: int = int(robot.parts[id])
		if attachments.has(id) and int(attachments[id].get_meta("level")) == level:
			if attachments[id].get_parent() != sockets[slot]:
				attachments[id].reparent(sockets[slot], false)
			continue
		if attachments.has(id):
			attachments[id].queue_free()
		var node := MeshFactory.instance(MeshFactory.part(id, level))
		node.set_meta("level", level)
		sockets[slot].add_child(node)
		var tier := int(robot.tiers.get(id, 1))
		if tier >= 3:
			var trim := MeshFactory.instance(MeshFactory.merged([MeshFactory.box(Vector3(0.1, 0.15, 0.5), Vector3(-0.18, 0.28, 0), MeshFactory.YELLOW if tier < 5 else MeshFactory.BLUE), MeshFactory.box(Vector3(0.1, 0.15, 0.5), Vector3(0.18, 0.28, 0), MeshFactory.YELLOW if tier < 5 else MeshFactory.BLUE)]))
			node.add_child(trim)
		attachments[id] = node
		if animate:
			node.position.y = 1.5
			node.scale = Vector3.ONE * 0.2
			var tween := create_tween().set_parallel(true)
			tween.tween_property(node, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(node, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
