class_name RobotBuilder extends Node3D
var body: MeshInstance3D
var sockets: Dictionary = {}
var attachments: Dictionary = {}
var signature := ""
var stage_value := 0
const POSITIONS = {"wheel_fl": Vector3(0, 0.3, 0), "wheel_fr": Vector3(0, 0.3, 0), "wheel_bl": Vector3(0, 0.3, 0), "wheel_br": Vector3(0, 0.3, 0), "wheel_ml": Vector3(0, 0.3, 0), "wheel_mr": Vector3(0, 0.3, 0), "top_c": Vector3(0, 1.18, -0.3), "top_l": Vector3(-0.55, 1.2, -0.2), "top_r": Vector3(0.55, 1.2, -0.2), "side_l": Vector3(-0.85, 0.9, -0.2), "side_r": Vector3(0.85, 0.9, -0.2), "back_c": Vector3(0, 1.0, 0.6), "front_c": Vector3(0, 0.75, -0.8), "shoulder_l": Vector3(-0.8, 1.1, 0), "shoulder_r": Vector3(0.8, 1.1, 0), "head": Vector3(0, 1.85, 0)}

func _ready() -> void:
	body = MeshFactory.instance(MeshFactory.chassis(1))
	add_child(body)
	for id in POSITIONS:
		var socket := Marker3D.new()
		socket.name = id
		socket.position = POSITIONS[id]
		add_child(socket)
		sockets[id] = socket

func sync(robot: RobotState, animate := true) -> void:
	var key := JSON.stringify(robot.parts) + str(robot.stage()) + JSON.stringify(robot.slots) + JSON.stringify(robot.tiers)
	if key == signature:
		return
	signature = key
	var changed_stage := stage_value != robot.stage()
	stage_value = robot.stage()
	body.mesh = MeshFactory.chassis(stage_value)
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
