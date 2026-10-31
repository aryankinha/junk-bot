extends Node3D
@export var part_id := "cannon"
@export_range(1, 3) var level := 1
func _ready() -> void:
	add_child(MeshFactory.instance(MeshFactory.part(part_id, level)))
