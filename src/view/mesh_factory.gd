class_name MeshFactory extends RefCounted
const STEEL = Color("4a5568")
const LIGHT = Color("8fa3b8")
const ORANGE = Color("f28c28")
const YELLOW = Color("f2c230")
const BLUE = Color("35b6ff")
const RED = Color("e53935")
const DARK = Color("202b3c")
static var material: StandardMaterial3D
static var cache: Dictionary = {}

static func palette() -> StandardMaterial3D:
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.85
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return material

# Each assembly becomes one vertex-coloured surface and one shared material.
static func merged(pieces: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		var mesh: PrimitiveMesh = piece.mesh
		var arrays := mesh.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var transform: Transform3D = piece.get("transform", Transform3D.IDENTITY)
		var color: Color = piece.get("color", STEEL)
		for i in indices.size() if not indices.is_empty() else verts.size():
			var vi: int = indices[i] if not indices.is_empty() else i
			tool.set_color(color)
			tool.set_normal((transform.basis.inverse().transposed() * normals[vi]).normalized())
			tool.add_vertex(transform * verts[vi])
	tool.set_material(palette())
	tool.index()
	return tool.commit()

static func box(size: Vector3, pos: Vector3, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "color": color, "transform": Transform3D(Basis.from_euler(rotation), pos)}

static func cylinder(radius: float, height: float, pos: Vector3, color: Color, rotation := Vector3.ZERO, tip := -1.0) -> Dictionary:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if tip < 0 else tip
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return {"mesh": mesh, "color": color, "transform": Transform3D(Basis.from_euler(rotation), pos)}

static func instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func chassis(stage: int, enemy := false) -> ArrayMesh:
	var key := "chassis_%d_%s" % [stage, enemy]
	if cache.has(key):
		return cache[key]
	var accent := RED if enemy else ORANGE
	var a: Array = [box(Vector3(1.1, 0.65, 1.3), Vector3(0, 0.7, 0), STEEL), box(Vector3(0.9, 0.15, 1.2), Vector3(0, 1.08, 0), accent), box(Vector3(0.72, 0.5, 0.65), Vector3(0, 1.4, -0.12), LIGHT), box(Vector3(0.62, 0.2, 0.07), Vector3(0, 1.43, -0.48), DARK)]
	for side in [-1, 1]:
		a.append(box(Vector3(0.18, 0.09, 0.08), Vector3(side * 0.18, 1.45, -0.53), RED if enemy else BLUE))
		for dz in [-0.43, 0.43]:
			a.append(cylinder(0.3, 0.22, Vector3(side * 0.6, 0.3, dz), DARK, Vector3(0, 0, PI / 2)))
			a.append(cylinder(0.15, 0.24, Vector3(side * 0.61, 0.3, dz), accent, Vector3(0, 0, PI / 2)))
		a.append(box(Vector3(0.2, 0.6, 0.7), Vector3(side * 0.68, 0.85, 0), accent))
	a.append(box(Vector3(0.12, 0.08, 0.6), Vector3(0, 1.16, -0.5), DARK))
	if stage >= 2:
		for side in [-1, 1]:
			a.append(box(Vector3(0.45, 0.35, 0.75), Vector3(side * 0.75, 1.15, 0), LIGHT))
	if stage == 3:
		a.append(box(Vector3(1.3, 0.28, 0.4), Vector3(0, 1.06, -0.65), accent))
		for side in [-1, 1]:
			a.append(cylinder(0.12, 0.5, Vector3(side * 0.7, 1.5, 0.25), YELLOW, Vector3.ZERO, 0))
	cache[key] = merged(a)
	return cache[key]

static func part(id: String, level: int) -> ArrayMesh:
	var key := "%s_%d" % [id, level]
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match id:
		"wheels":
			for side in [-1, 1]:
				for dz in [-0.45, 0.45]:
					a.append(cylinder(0.28 + level * 0.07, 0.25, Vector3(side * 0.75, 0.0, dz), DARK, Vector3(0, 0, PI / 2)))
					a.append(cylinder(0.15, 0.28, Vector3(side * 0.76, 0.0, dz), ORANGE, Vector3(0, 0, PI / 2)))
		"tracks":
			for side in [-1, 1]:
				a.append(box(Vector3(0.4, 0.4, 1.65), Vector3(side * 0.75, 0, 0), DARK))
				for i in 6:
					a.append(box(Vector3(0.43, 0.14, 0.16), Vector3(side * 0.75, -0.18, -0.68 + i * 0.27), LIGHT))
		"cannon":
			a.append(box(Vector3(0.6, 0.25, 0.4), Vector3.ZERO, STEEL))
			for i in (4 if level == 3 else level):
				var dx := (i - (3.0 if level == 3 else level - 1.0) / 2) * 0.17
				a.append(cylinder(0.09, 0.85, Vector3(dx, 0.14, -0.4), LIGHT, Vector3(PI / 2, 0, 0)))
				a.append(cylinder(0.12, 0.1, Vector3(dx, 0.14, -0.84), DARK, Vector3(PI / 2, 0, 0)))
		"rocket":
			a.append(box(Vector3(0.8, 0.42, 0.62), Vector3.ZERO, STEEL))
			for i in (6 if level == 3 else level):
				var dx := (i % 3 - 1) * 0.23
				var dy := float(i / 3) * 0.24
				a.append(cylinder(0.08, 0.48, Vector3(dx, dy, -0.18), ORANGE, Vector3(PI / 2, 0, 0)))
				a.append(cylinder(0.08, 0.18, Vector3(dx, dy, -0.49), YELLOW, Vector3(PI / 2, 0, 0), 0))
		"flame":
			a.append(cylinder(0.2, 0.6 + level * 0.1, Vector3.ZERO, ORANGE))
			a.append(cylinder(0.12 + level * 0.02, 0.5, Vector3(0, 0, -0.4), DARK, Vector3(PI / 2, 0, 0)))
			a.append(cylinder(0.17, 0.09, Vector3(0, 0, -0.7), YELLOW, Vector3(PI / 2, 0, 0)))
		"armour":
			for side in [-1, 1]:
				a.append(box(Vector3(0.55, 0.5 + level * 0.12, 0.2), Vector3(side * 0.38, 0, 0), LIGHT, Vector3(0, side * 0.15, side * -0.15)))
				if level >= 2:
					a.append(box(Vector3(0.12, 0.5, 0.23), Vector3(side * 0.38, 0, -0.05), ORANGE))
				if level == 3:
					a.append(cylinder(0.12, 0.32, Vector3(side * 0.55, 0.4, 0), YELLOW, Vector3.ZERO, 0))
		"shield":
			a.append(cylinder(0.22, 0.18, Vector3.ZERO, STEEL))
			a.append(cylinder(0.1, 0.45 + level * 0.1, Vector3(0, 0.22, 0), BLUE))
		"magnet":
			a.append(box(Vector3(0.65, 0.18, 0.25), Vector3.ZERO, LIGHT))
			for side in [-1, 1]:
				a.append(box(Vector3(0.18, 0.5 + level * 0.1, 0.25), Vector3(side * 0.25, 0.24, 0), RED if side < 0 else BLUE))
		"storage":
			a.append(box(Vector3(0.7, 0.5 + level * 0.13, 0.45), Vector3.ZERO, ORANGE))
			for side in [-1, 1]:
				a.append(box(Vector3(0.08, 0.55 + level * 0.13, 0.48), Vector3(side * 0.2, 0, 0), DARK))
	cache[key] = merged(a)
	return cache[key]

static func boss_body() -> ArrayMesh:
	if cache.has("boss"):
		return cache.boss
	var a: Array = [box(Vector3(3.4, 3.2, 2), Vector3(0, 3.4, 0), STEEL), box(Vector3(2.0, 1.1, 1.6), Vector3(0, 5.6, -0.15), LIGHT), box(Vector3(1.8, 0.4, 0.15), Vector3(0, 5.65, 0.73), DARK), box(Vector3(2.4, 0.35, 0.18), Vector3(0, 2.4, 1.05), ORANGE)]
	for side in [-1, 1]:
		a.append(box(Vector3(0.55, 0.17, 0.2), Vector3(side * 0.47, 5.7, 0.8), RED))
		a.append(box(Vector3(1.2, 1.8, 1.4), Vector3(side * 1.05, 1.05, 0.1), DARK))
		a.append(box(Vector3(1.4, 0.65, 1.9), Vector3(side * 1.05, 0.35, 0.4), LIGHT))
		a.append(box(Vector3(1.6, 1.1, 1.8), Vector3(side * 2.4, 4.4, 0), ORANGE, Vector3(0, 0, side * 0.12)))
		a.append(box(Vector3(0.85, 2.1, 0.9), Vector3(side * 2.7, 2.9, 0.2), LIGHT))
		a.append(box(Vector3(1.2, 0.8, 1.3), Vector3(side * 2.7, 1.8, 0.55), DARK))
	cache.boss = merged(a)
	return cache.boss

static func hazard(id: String) -> ArrayMesh:
	var key := "hazard_" + id
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match id:
		"barrel":
			a.append(cylinder(0.4, 0.9, Vector3(0, 0.45, 0), ORANGE))
			for y in [0.15, 0.75]:
				a.append(cylinder(0.42, 0.08, Vector3(0, y, 0), DARK))
		"oil": a.append(cylinder(1.4, 0.01, Vector3(0, -0.18, 0), DARK))
		_:
			a.append(cylinder(0.7, 0.15, Vector3.ZERO, LIGHT))
			for i in 8:
				var angle := i * TAU / 8
				a.append(box(Vector3(0.32, 0.18, 0.22), Vector3(sin(angle) * 0.72, 0, cos(angle) * 0.72), YELLOW, Vector3(0, angle, 0)))
	cache[key] = merged(a)
	return cache[key]
