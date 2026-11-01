class_name MeshFactory extends RefCounted
# Procedural, rounded "toy" models. Every assembly is one vertex-coloured surface that shares the
# toon material below (cel-shaded diffuse, glossy rim light, inverted-hull outline as a next pass).
const STEEL = Color("6c7b99")
const LIGHT = Color("d3dbea")
const ORANGE = Color("ff8a1f")
const YELLOW = Color("ffd23f")
const BLUE = Color("3ab0ff")
const RED = Color("ff4757")
const DARK = Color("2a3042")
const HERO = Color("2f7bff")
const HERO_DARK = Color("1d4fd0")
const FOE = Color("e8344e")
const FOE_DARK = Color("8f1d3a")
const GREEN = Color("43d17a")
const PURPLE = Color("9b6cff")
const RUBBER = Color("1e2230")
const RUST = Color("c2622b")
const RUST_DARK = Color("8a3f1e")
const OLIVE = Color("7d8a3e")
const TEAL = Color("3f9a94")
const GREY = Color("8b97a8")
const DIRT = Color("8b6a47")
static var material: ShaderMaterial
static var ground_material: StandardMaterial3D
static var cache: Dictionary = {}

const TOON_SHADER := """
shader_type spatial;
render_mode cull_back;
varying vec3 vcol;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	vcol = pow(COLOR.rgb, vec3(2.2));
}
void fragment() {
	ALBEDO = mix(vcol, vec3(1.0, 0.95, 0.85), flash);
	EMISSION = vec3(1.0, 0.8, 0.6) * flash * 0.8;
	ROUGHNESS = 0.4;
	SPECULAR = 0.35;
	RIM = 0.22;
	RIM_TINT = 0.4;
}
void light() {
	float nl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float band = smoothstep(0.38, 0.52, nl) * 0.5 + smoothstep(0.62, 0.78, nl) * 0.35;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (0.28 + band);
	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(0.88, 0.94, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * 0.22;
}
"""
const OUTLINE_SHADER := """
shader_type spatial;
render_mode cull_front, unshaded;
uniform float width = 0.035;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = vec3(0.07, 0.08, 0.14);
}
"""

static func palette() -> ShaderMaterial:
	if material == null:
		var toon := Shader.new()
		toon.code = TOON_SHADER
		material = ShaderMaterial.new()
		material.shader = toon
		var outline := Shader.new()
		outline.code = OUTLINE_SHADER
		var pass_material := ShaderMaterial.new()
		pass_material.shader = outline
		material.next_pass = pass_material
	return material

static func flat_material() -> StandardMaterial3D:
	if ground_material == null:
		ground_material = StandardMaterial3D.new()
		ground_material.vertex_color_use_as_albedo = true
		ground_material.vertex_color_is_srgb = true
		ground_material.roughness = 1.0
		ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return ground_material

# Each assembly becomes one vertex-coloured surface and one shared material.
static func merged(pieces: Array, flat := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		var mesh: Mesh = piece.mesh
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var transform: Transform3D = piece.get("transform", Transform3D.IDENTITY)
		var color: Color = piece.get("color", STEEL)
		var normal_basis := transform.basis.inverse().transposed()
		for i in indices.size() if not indices.is_empty() else verts.size():
			var vi: int = indices[i] if not indices.is_empty() else i
			tool.set_color(color)
			tool.set_normal((normal_basis * normals[vi]).normalized())
			tool.add_vertex(transform * verts[vi])
	tool.set_material(flat_material() if flat else palette())
	tool.index()
	return tool.commit()

static func _xform(pos: Vector3, rotation: Vector3, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation).scaled(scale), pos)

# Rounded box: a 3x3x3-segment grid whose outer ring is pushed onto a sphere of radius r.
static func rbox_mesh(size: Vector3, r: float) -> ArrayMesh:
	var h := size / 2.0
	r = minf(r, minf(h.x, minf(h.y, h.z)) - 0.001)
	var xs := [-h.x, -h.x + r, h.x - r, h.x]
	var ys := [-h.y, -h.y + r, h.y - r, h.y]
	var zs := [-h.z, -h.z + r, h.z - r, h.z]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six faces; each is a 4x4 vertex grid on the box surface.
	for face in 6:
		var axis := face / 2
		var sgn := 1.0 if face % 2 == 0 else -1.0
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var grids := [xs, ys, zs]
		var pts: Array = []
		for j in 4:
			for i in 4:
				var p := Vector3.ZERO
				p[axis] = h[axis] * sgn
				p[u_axis] = grids[u_axis][i]
				p[v_axis] = grids[v_axis][j]
				var inner := Vector3(clampf(p.x, -h.x + r, h.x - r), clampf(p.y, -h.y + r, h.y - r), clampf(p.z, -h.z + r, h.z - r))
				var n := (p - inner)
				n = n.normalized() if n.length() > 0.0001 else Vector3.ZERO
				pts.append([inner + n * r, n])
		for j in 3:
			for i in 3:
				var a: Array = pts[j * 4 + i]
				var b: Array = pts[j * 4 + i + 1]
				var c: Array = pts[(j + 1) * 4 + i + 1]
				var d: Array = pts[(j + 1) * 4 + i]
				var quad := [a, b, c, d]
				for order in [[0, 1, 2], [0, 2, 3]]:
					var p0: Vector3 = quad[order[0]][0]
					var p1: Vector3 = quad[order[1]][0]
					var p2: Vector3 = quad[order[2]][0]
					var sum: Vector3 = quad[order[0]][1] + quad[order[1]][1] + quad[order[2]][1]
					# Godot treats clockwise triangles as front-facing.
					if (p1 - p0).cross(p2 - p0).dot(sum) > 0:
						order = [order[0], order[2], order[1]]
					for k in order:
						tool.set_normal(quad[k][1])
						tool.add_vertex(quad[k][0])
	return tool.commit()

static func rbox(size: Vector3, pos: Vector3, color: Color, r := 0.12, rotation := Vector3.ZERO) -> Dictionary:
	return {"mesh": rbox_mesh(size, r), "color": color, "transform": _xform(pos, rotation)}

# Hard-edged box, kept for road/ground slabs where roundness is wasted.
static func box(size: Vector3, pos: Vector3, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "color": color, "transform": _xform(pos, rotation)}

static func sphere(radius: float, pos: Vector3, color: Color, scale := Vector3.ONE, segments := 12) -> Dictionary:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = segments
	mesh.rings = maxi(3, segments / 2)
	return {"mesh": mesh, "color": color, "transform": _xform(pos, Vector3.ZERO, scale)}

static func capsule(radius: float, height: float, pos: Vector3, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.01)
	mesh.radial_segments = 10
	mesh.rings = 3
	return {"mesh": mesh, "color": color, "transform": _xform(pos, rotation)}

static func cylinder(radius: float, height: float, pos: Vector3, color: Color, rotation := Vector3.ZERO, tip := -1.0, segments := 12) -> Dictionary:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if tip < 0 else tip
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return {"mesh": mesh, "color": color, "transform": _xform(pos, rotation)}

static func instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# A wheel: black tyre, bright hub, tiny bolt cap. Axle along X.
static func wheel(radius: float, width: float, pos: Vector3, hub: Color, side := 1.0) -> Array:
	var rot := Vector3(0, 0, PI / 2)
	return [
		cylinder(radius, width, pos, RUBBER, rot, -1.0, 12),
		cylinder(radius * 0.62, width + 0.04, pos, hub, rot, -1.0, 10),
		cylinder(radius * 0.2, width + 0.08, pos, LIGHT, rot, -1.0, 6)]

# Junk-built hero. Body, head, antenna and wheels are separate meshes so they can animate on their own.
static func _rivets(points: Array, color: Color) -> Array:
	var out: Array = []
	for point in points:
		out.append(sphere(0.045, point, color, Vector3.ONE, 5))
	return out

static func chassis_body(stage: int, enemy := false) -> ArrayMesh:
	var key := "body_%d_%s" % [stage, enemy]
	if cache.has(key):
		return cache[key]
	var body := FOE if enemy else HERO
	var body_dark := FOE_DARK if enemy else HERO_DARK
	var a: Array = [
		rbox(Vector3(1.1, 0.5, 1.45), Vector3(0, 0.62, 0.02), body, 0.2),
		rbox(Vector3(1.18, 0.16, 1.5), Vector3(0, 0.4, 0.02), body_dark, 0.07),
		cylinder(0.07, 1.25, Vector3(0, 0.46, -0.8), GREY, Vector3(0, 0, PI / 2), -1.0, 8),
		rbox(Vector3(0.9, 0.46, 0.8), Vector3(0, 1.04, 0.1), Color("d9d3c0"), 0.2),
		rbox(Vector3(0.92, 0.1, 0.3), Vector3(0, 1.1, 0.1), YELLOW, 0.04),
		rbox(Vector3(0.5, 0.34, 0.04), Vector3(-0.56, 0.66, 0.2), RUST, 0.03),
		rbox(Vector3(0.4, 0.28, 0.04), Vector3(0.56, 0.6, -0.2), OLIVE, 0.03),
		rbox(Vector3(0.45, 0.04, 0.4), Vector3(0.2, 0.89, -0.35), RUST_DARK, 0.02),
		cylinder(0.3, 0.14, Vector3(0, 0.98, 0.78), RUBBER, Vector3(PI / 2, 0, 0), -1.0, 10),
		cylinder(0.14, 0.16, Vector3(0, 0.98, 0.78), RUST, Vector3(PI / 2, 0, 0), -1.0, 8),
		rbox(Vector3(0.16, 0.1, 0.06), Vector3(-0.38, 0.68, 0.76), RED, 0.03),
		rbox(Vector3(0.16, 0.1, 0.06), Vector3(0.38, 0.68, 0.76), RED, 0.03)]
	a.append_array(_rivets([Vector3(-0.5, 0.82, -0.6), Vector3(0.5, 0.82, -0.6), Vector3(-0.5, 0.82, 0.6), Vector3(0.5, 0.82, 0.6), Vector3(0, 0.86, -0.66)], LIGHT))
	for side in [-1, 1]:
		a.append(rbox(Vector3(0.2, 0.42, 0.9), Vector3(side * 0.62, 0.78, 0.05), body_dark, 0.09))
		a.append(cylinder(0.07, 0.65, Vector3(side * 0.3, 1.32, 0.52), RUST_DARK, Vector3.ZERO, -1.0, 8))
		a.append(cylinder(0.1, 0.07, Vector3(side * 0.3, 1.68, 0.52), RUBBER, Vector3.ZERO, -1.0, 8))
	if enemy:
		for side in [-1, 1]:
			a.append(cylinder(0.07, 0.2, Vector3(side * 0.3, 0.55, -0.82), LIGHT, Vector3(-PI / 2, 0, 0), 0.0, 8))
	if stage >= 2:
		for side in [-1, 1]:
			a.append(cylinder(0.34, 0.16, Vector3(side * 0.78, 1.18, 0.05), RUST, Vector3(0, 0, PI / 2), -1.0, 12))
			a.append(cylinder(0.2, 0.2, Vector3(side * 0.8, 1.18, 0.05), YELLOW, Vector3(0, 0, PI / 2), -1.0, 10))
			a.append(cylinder(0.05, 0.3, Vector3(side * 0.95, 1.18, 0.05), GREY, Vector3(0, 0, PI / 2), 0.0, 6))
	if stage == 3:
		a.append(rbox(Vector3(1.3, 0.26, 0.4), Vector3(0, 1.0, -0.72), body_dark, 0.1))
		for i in 5:
			a.append(cylinder(0.05, 0.3, Vector3(-0.5 + i * 0.25, 1.2, -0.72), GREY, Vector3(-0.4, 0, 0), 0.0, 5))
	cache[key] = merged(a)
	return cache[key]

# Bucket head with headlight eyes (origin at the neck).
static func head(stage: int, enemy := false) -> ArrayMesh:
	var key := "head_%d_%s" % [stage, enemy]
	if cache.has(key):
		return cache[key]
	var eye := YELLOW if enemy else BLUE
	var shell := Color("a33a3a") if enemy else GREY
	var a: Array = [
		cylinder(0.3, 0.5, Vector3(0, 0.28, 0), shell, Vector3.ZERO, 0.38, 14),
		cylinder(0.4, 0.07, Vector3(0, 0.55, 0), RUST_DARK if enemy else Color("6f7c8e"), Vector3.ZERO, -1.0, 14),
		rbox(Vector3(0.62, 0.22, 0.14), Vector3(0, 0.32, -0.3), RUBBER, 0.06),
		cylinder(0.11, 0.08, Vector3(-0.15, 0.32, -0.36), eye, Vector3(PI / 2, 0, 0), -1.0, 10),
		cylinder(0.075, 0.08, Vector3(0.16, 0.32, -0.36), eye, Vector3(PI / 2, 0, 0), -1.0, 10),
		rbox(Vector3(0.22, 0.16, 0.04), Vector3(0.2, 0.2, 0.3), RUST, 0.02),
		cylinder(0.03, 0.12, Vector3(0, 0.62, 0), GREY, Vector3.ZERO, -1.0, 6)]
	if enemy:
		for side in [-1, 1]:
			a.append(rbox(Vector3(0.26, 0.07, 0.1), Vector3(side * 0.16, 0.46, -0.34), FOE_DARK, 0.03, Vector3(0, 0, side * 0.45)))
	if stage == 3:
		for side in [-1, 1]:
			a.append(cylinder(0.09, 0.5, Vector3(side * 0.34, 0.6, -0.02), YELLOW, Vector3(0, 0, side * -0.5), 0.0, 8))
	cache[key] = merged(a)
	return cache[key]

static func antenna() -> ArrayMesh:
	if cache.has("antenna"):
		return cache.antenna
	cache.antenna = merged([cylinder(0.025, 0.4, Vector3(0, 0.2, 0), GREY, Vector3.ZERO, -1.0, 6), sphere(0.08, Vector3(0, 0.44, 0), YELLOW, Vector3.ONE, 8), cylinder(0.04, 0.12, Vector3(0, 0.02, 0), DARK, Vector3.ZERO, -1.0, 6)])
	return cache.antenna

# One tyre with lugs and a hubcap; axle on X so rotation.x spins it.
static func wheel_mesh(hub_color := ORANGE) -> ArrayMesh:
	var key := "wheel_%s" % hub_color.to_html()
	if cache.has(key):
		return cache[key]
	var rot := Vector3(0, 0, PI / 2)
	var a: Array = [cylinder(0.33, 0.26, Vector3.ZERO, RUBBER, rot, -1.0, 12), cylinder(0.2, 0.3, Vector3.ZERO, hub_color, rot, -1.0, 10), cylinder(0.07, 0.34, Vector3.ZERO, LIGHT, rot, -1.0, 6)]
	for i in 8:
		var angle := i * TAU / 8
		a.append(box(Vector3(0.3, 0.07, 0.1), Vector3(0, sin(angle) * 0.33, cos(angle) * 0.33), Color("3a3f55"), Vector3(-angle, 0, 0)))
	for i in 4:
		var angle := i * TAU / 4 + 0.4
		a.append(sphere(0.035, Vector3(0.16, sin(angle) * 0.13, cos(angle) * 0.13), LIGHT, Vector3.ONE, 5))
		a.append(sphere(0.035, Vector3(-0.16, sin(angle) * 0.13, cos(angle) * 0.13), LIGHT, Vector3.ONE, 5))
	cache[key] = merged(a)
	return cache[key]

static func enemy(id: String) -> ArrayMesh:
	var key := "enemy_" + id
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match id:
		"scrapper":
			# Angry living tyre with a rusty hubcap, nail spikes and a toothy grin.
			var rot := Vector3(0, 0, PI / 2)
			a.append(cylinder(0.62, 0.6, Vector3(0, 0.64, 0), RUBBER, rot, -1.0, 16))
			a.append(cylinder(0.42, 0.66, Vector3(0, 0.64, 0), RUST, rot, -1.0, 12))
			a.append(cylinder(0.2, 0.7, Vector3(0, 0.64, 0), GREY, rot, -1.0, 8))
			a.append(sphere(0.17, Vector3(-0.14, 0.86, -0.56), LIGHT, Vector3(1, 1.1, 0.7), 8))
			a.append(sphere(0.17, Vector3(0.14, 0.86, -0.56), LIGHT, Vector3(1, 1.1, 0.7), 8))
			a.append(sphere(0.07, Vector3(-0.14, 0.85, -0.66), RED, Vector3.ONE, 6))
			a.append(sphere(0.07, Vector3(0.14, 0.85, -0.66), RED, Vector3.ONE, 6))
			for i in 4:
				a.append(box(Vector3(0.1, 0.12, 0.06), Vector3(-0.15 + i * 0.1, 0.55, -0.62), LIGHT))
			for side in [-1, 1]:
				a.append(rbox(Vector3(0.3, 0.07, 0.1), Vector3(side * 0.14, 1.05, -0.52), FOE_DARK, 0.03, Vector3(0, 0, side * 0.5)))
				a.append(cylinder(0.05, 0.4, Vector3(side * 0.3, 1.32, 0.1), GREY, Vector3(0, 0, side * -0.5), 0.0, 6))
		"gunner":
			# Oil-drum turret with a funnel hat and a pipe cannon.
			a.append(cylinder(0.65, 0.22, Vector3(0, 0.11, 0), RUBBER, Vector3.ZERO, -1.0, 14))
			a.append(cylinder(0.5, 0.95, Vector3(0, 0.68, 0), RUST, Vector3.ZERO, -1.0, 14))
			a.append(cylinder(0.53, 0.1, Vector3(0, 0.45, 0), DARK, Vector3.ZERO, -1.0, 14))
			a.append(cylinder(0.53, 0.1, Vector3(0, 0.9, 0), DARK, Vector3.ZERO, -1.0, 14))
			a.append(cylinder(0.42, 0.34, Vector3(0, 1.3, 0), GREY, Vector3.ZERO, 0.08, 12))
			a.append(cylinder(0.13, 0.9, Vector3(0, 0.82, -0.62), GREY, Vector3(PI / 2, 0, 0), -1.0, 8))
			a.append(cylinder(0.19, 0.16, Vector3(0, 0.82, -1.08), DARK, Vector3(PI / 2, 0, 0), -1.0, 8))
			a.append(cylinder(0.14, 0.08, Vector3(0, 0.95, -0.5), RED, Vector3(PI / 2, 0, 0), -1.0, 8))
			a.append(rbox(Vector3(0.4, 0.3, 0.04), Vector3(0.2, 0.55, -0.49), YELLOW, 0.02, Vector3(0, 0.2, 0)))
		"hauler":
			# Rusty scrap truck seen from behind: cab, armoured loot crate, big tyres, exhaust stacks.
			a.append(rbox(Vector3(1.9, 0.5, 3.4), Vector3(0, 0.7, 0), DARK, 0.15))
			a.append(rbox(Vector3(1.5, 1.0, 1.1), Vector3(0, 1.4, -1.25), RUST, 0.25))
			a.append(rbox(Vector3(1.2, 0.35, 0.05), Vector3(0, 1.6, -1.82), Color("9ad7ff"), 0.03))
			a.append(rbox(Vector3(2.1, 1.7, 2.0), Vector3(0, 1.7, 0.7), YELLOW, 0.18))
			for i in 3:
				a.append(rbox(Vector3(2.15, 0.2, 0.3), Vector3(0, 1.1 + i * 0.55, 1.5), DARK, 0.05, Vector3(0, 0, 0.0)))
			a.append(rbox(Vector3(0.9, 0.9, 0.08), Vector3(0, 1.8, 1.72), Color("2a3042"), 0.06))
			a.append(cylinder(0.3, 0.1, Vector3(0, 1.8, 1.78), ORANGE, Vector3(PI / 2, 0, 0), -1.0, 14))
			a.append(cylinder(0.18, 0.12, Vector3(0, 1.8, 1.8), Color("ffe98a"), Vector3(PI / 2, 0, 0), -1.0, 12))
			a.append(rbox(Vector3(2.0, 0.08, 0.08), Vector3(0, 2.4, 0.2), GREY, 0.02))
			for side in [-1, 1]:
				a.append(cylinder(0.09, 1.2, Vector3(side * 0.7, 2.0, -0.55), GREY, Vector3.ZERO, -1.0, 8))
				a.append(cylinder(0.12, 0.08, Vector3(side * 0.7, 2.62, -0.55), RUBBER, Vector3.ZERO, -1.0, 8))
				a.append(rbox(Vector3(0.22, 0.14, 0.06), Vector3(side * 0.78, 0.75, 1.74), RED, 0.03))
				for dz in [-1.2, 0.4, 1.3]:
					a.append(cylinder(0.5, 0.42, Vector3(side * 1.0, 0.5, dz), RUBBER, Vector3(0, 0, PI / 2), -1.0, 12))
					a.append(cylinder(0.28, 0.46, Vector3(side * 1.0, 0.5, dz), RUST, Vector3(0, 0, PI / 2), -1.0, 10))
		_:
			# Bruiser / elite: crushed car body with tyre fists and a bumper grin.
			a.append(rbox(Vector3(1.4, 0.7, 1.3), Vector3(0, 0.8, 0.05), FOE, 0.25))
			a.append(rbox(Vector3(1.5, 0.12, 0.5), Vector3(0, 0.45, -0.75), YELLOW, 0.05))
			a.append(rbox(Vector3(0.9, 0.55, 0.7), Vector3(0, 1.4, -0.05), FOE_DARK, 0.2))
			a.append(rbox(Vector3(0.7, 0.16, 0.1), Vector3(0, 1.42, -0.42), LIGHT, 0.04))
			a.append(sphere(0.09, Vector3(-0.2, 1.45, -0.46), YELLOW, Vector3.ONE, 6))
			a.append(sphere(0.09, Vector3(0.2, 1.45, -0.46), YELLOW, Vector3.ONE, 6))
			a.append(rbox(Vector3(0.5, 0.05, 0.4), Vector3(0.2, 1.1, 0.3), RUST_DARK, 0.02))
			for side in [-1, 1]:
				a.append(cylinder(0.42, 0.34, Vector3(side * 0.98, 0.6, -0.1), RUBBER, Vector3(0, 0, PI / 2), -1.0, 12))
				a.append(cylinder(0.24, 0.38, Vector3(side * 0.98, 0.6, -0.1), RUST, Vector3(0, 0, PI / 2), -1.0, 10))
				a.append(cylinder(0.09, 0.55, Vector3(side * 0.4, 1.9, 0.1), GREY, Vector3(0, 0, side * -0.3), 0.0, 8))
				a.append_array(wheel(0.3, 0.26, Vector3(side * 0.55, 0.3, 0.4), YELLOW, side))
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
					a.append_array(wheel(0.3 + level * 0.07, 0.28, Vector3(side * 0.78, 0.0, dz), ORANGE, side))
		"tracks":
			for side in [-1, 1]:
				a.append(rbox(Vector3(0.42, 0.42, 1.7), Vector3(side * 0.76, 0, 0), RUBBER, 0.19))
				a.append(cylinder(0.2, 0.46, Vector3(side * 0.76, 0, -0.62), STEEL, Vector3(0, 0, PI / 2), -1.0, 10))
				a.append(cylinder(0.2, 0.46, Vector3(side * 0.76, 0, 0.62), STEEL, Vector3(0, 0, PI / 2), -1.0, 10))
				for i in 6:
					a.append(box(Vector3(0.46, 0.1, 0.16), Vector3(side * 0.76, -0.2, -0.68 + i * 0.27), ORANGE))
		"cannon":
			a.append(rbox(Vector3(0.62, 0.28, 0.46), Vector3.ZERO, STEEL, 0.12))
			a.append(sphere(0.18, Vector3(0, 0.18, 0.05), ORANGE, Vector3(1, 0.7, 1), 8))
			for i in (4 if level == 3 else level):
				var dx := (i - (3.0 if level == 3 else level - 1.0) / 2) * 0.17
				a.append(cylinder(0.075, 0.85, Vector3(dx, 0.14, -0.4), LIGHT, Vector3(PI / 2, 0, 0), -1.0, 8))
				a.append(cylinder(0.105, 0.12, Vector3(dx, 0.14, -0.84), DARK, Vector3(PI / 2, 0, 0), -1.0, 8))
		"rocket":
			a.append(rbox(Vector3(0.82, 0.42, 0.64), Vector3.ZERO, STEEL, 0.14))
			for i in (6 if level == 3 else level):
				var dx := (i % 3 - 1) * 0.23 if level == 3 else ((i - (level - 1) / 2.0) * 0.3)
				var dy := float(i / 3) * 0.24 if level == 3 else 0.0
				a.append(cylinder(0.08, 0.46, Vector3(dx, dy, -0.18), ORANGE, Vector3(PI / 2, 0, 0), -1.0, 8))
				a.append(cylinder(0.08, 0.2, Vector3(dx, dy, -0.49), RED, Vector3(PI / 2, 0, 0), 0.0, 8))
		"flame":
			a.append(capsule(0.2, 0.6 + level * 0.1, Vector3.ZERO, ORANGE))
			a.append(cylinder(0.11 + level * 0.02, 0.5, Vector3(0, 0, -0.4), DARK, Vector3(PI / 2, 0, 0), -1.0, 10))
			a.append(cylinder(0.17, 0.09, Vector3(0, 0, -0.7), YELLOW, Vector3(PI / 2, 0, 0), -1.0, 10))
		"armour":
			for side in [-1, 1]:
				a.append(rbox(Vector3(0.55, 0.5 + level * 0.12, 0.2), Vector3(side * 0.38, 0, 0), LIGHT, 0.09, Vector3(0, side * 0.15, side * -0.15)))
				if level >= 2:
					a.append(rbox(Vector3(0.12, 0.5, 0.23), Vector3(side * 0.38, 0, -0.05), ORANGE, 0.04))
				if level == 3:
					a.append(cylinder(0.12, 0.32, Vector3(side * 0.55, 0.4, 0), YELLOW, Vector3.ZERO, 0.0, 8))
		"shield":
			a.append(cylinder(0.22, 0.18, Vector3.ZERO, STEEL, Vector3.ZERO, -1.0, 12))
			a.append(cylinder(0.08, 0.45 + level * 0.1, Vector3(0, 0.22, 0), BLUE, Vector3.ZERO, -1.0, 8))
			a.append(sphere(0.12, Vector3(0, 0.45 + level * 0.1, 0), LIGHT, Vector3.ONE, 8))
		"magnet":
			a.append(rbox(Vector3(0.65, 0.2, 0.26), Vector3.ZERO, LIGHT, 0.09))
			for side in [-1, 1]:
				a.append(rbox(Vector3(0.2, 0.5 + level * 0.1, 0.26), Vector3(side * 0.25, 0.24, 0), RED if side < 0 else BLUE, 0.09))
		"storage":
			a.append(rbox(Vector3(0.72, 0.5 + level * 0.13, 0.46), Vector3.ZERO, ORANGE, 0.14))
			for side in [-1, 1]:
				a.append(rbox(Vector3(0.09, 0.55 + level * 0.13, 0.5), Vector3(side * 0.2, 0, 0), DARK, 0.04))
	cache[key] = merged(a)
	return cache[key]

static func boss_body() -> ArrayMesh:
	if cache.has("boss"):
		return cache.boss
	# Scrap Titan: a heap of crushed car shells, tyre shoulders and an oil-drum head.
	var a: Array = [
		rbox(Vector3(3.4, 3.0, 2.1), Vector3(0, 3.3, 0), RUST_DARK, 0.6),
		rbox(Vector3(3.5, 0.5, 2.2), Vector3(0, 2.0, 0), DARK, 0.2),
		rbox(Vector3(1.5, 1.4, 0.2), Vector3(-0.9, 3.5, 1.05), TEAL, 0.08, Vector3(0, 0, 0.1)),
		rbox(Vector3(1.1, 1.0, 0.2), Vector3(1.0, 3.9, 1.05), OLIVE, 0.08, Vector3(0, 0, -0.15)),
		rbox(Vector3(1.4, 0.8, 0.2), Vector3(0.6, 2.9, 1.05), Color("d9d3c0"), 0.08),
		cylinder(1.0, 1.4, Vector3(0, 5.5, -0.1), GREY, Vector3.ZERO, 0.85, 18),
		cylinder(1.12, 0.18, Vector3(0, 6.2, -0.1), RUST_DARK, Vector3.ZERO, -1.0, 18),
		rbox(Vector3(1.9, 0.5, 0.35), Vector3(0, 5.55, 0.82), RUBBER, 0.14),
		rbox(Vector3(2.4, 0.4, 0.2), Vector3(0, 2.4, 1.08), YELLOW, 0.1),
		cylinder(0.12, 1.6, Vector3(1.1, 6.9, -0.1), GREY, Vector3(0, 0, -0.3), -1.0, 8),
		cylinder(0.12, 1.2, Vector3(-1.2, 6.8, -0.1), GREY, Vector3(0, 0, 0.5), -1.0, 8)]
	for side in [-1, 1]:
		a.append(sphere(0.2, Vector3(side * 0.5, 5.58, 0.95), RED, Vector3.ONE, 8))
		a.append(rbox(Vector3(1.0, 0.2, 0.2), Vector3(side * 0.5, 5.95, 0.95), FOE_DARK, 0.06, Vector3(0, 0, side * 0.35)))
		a.append(rbox(Vector3(1.2, 1.8, 1.4), Vector3(side * 1.05, 1.05, 0.1), DARK, 0.4))
		a.append(rbox(Vector3(1.4, 0.65, 1.9), Vector3(side * 1.05, 0.35, 0.4), STEEL, 0.28))
		a.append(cylinder(1.05, 0.9, Vector3(side * 2.4, 4.4, 0), RUBBER, Vector3(0, 0, PI / 2), -1.0, 18))
		a.append(cylinder(0.65, 1.0, Vector3(side * 2.4, 4.4, 0), RUST, Vector3(0, 0, PI / 2), -1.0, 12))
		a.append(cylinder(0.25, 1.05, Vector3(side * 2.4, 4.4, 0), GREY, Vector3(0, 0, PI / 2), -1.0, 8))
		a.append(capsule(0.45, 2.2, Vector3(side * 2.7, 2.9, 0.2), GREY))
		a.append(cylinder(0.75, 0.9, Vector3(side * 2.7, 1.7, 0.45), RUBBER, Vector3(0, 0, PI / 2), -1.0, 14))
		a.append(cylinder(0.14, 0.9, Vector3(side * 0.7, 6.6, -0.1), YELLOW, Vector3(0, 0, side * -0.35), 0.0, 8))
	cache.boss = merged(a)
	return cache.boss

static func hazard(id: String) -> ArrayMesh:
	var key := "hazard_" + id
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match id:
		"barrel":
			# Explosive drum: red with a hazard band and a skull-ish warning plate.
			a.append(cylinder(0.42, 0.9, Vector3(0, 0.45, 0), RED, Vector3.ZERO, -1.0, 14))
			for y in [0.12, 0.78]:
				a.append(cylinder(0.45, 0.1, Vector3(0, y, 0), DARK, Vector3.ZERO, -1.0, 14))
			a.append(cylinder(0.44, 0.16, Vector3(0, 0.45, 0), YELLOW, Vector3.ZERO, -1.0, 14))
			a.append(rbox(Vector3(0.22, 0.22, 0.05), Vector3(0, 0.45, -0.44), DARK, 0.03))
			a.append(cylinder(0.12, 0.08, Vector3(0, 0.93, 0), GREY, Vector3.ZERO, -1.0, 8))
		"oil":
			a.append(cylinder(1.4, 0.01, Vector3(0, -0.18, 0), Color("1a1830"), Vector3.ZERO, -1.0, 24))
			a.append(cylinder(0.9, 0.012, Vector3(0.3, -0.17, -0.2), Color("3a2f6a"), Vector3.ZERO, -1.0, 16))
			a.append(cylinder(0.5, 0.014, Vector3(-0.6, -0.16, 0.3), Color("2a2150"), Vector3.ZERO, -1.0, 12))
		_:
			# Rusty circular saw: tooth ring, hub and a red warning dot.
			a.append(cylinder(0.7, 0.12, Vector3.ZERO, GREY, Vector3.ZERO, -1.0, 18))
			a.append(cylinder(0.3, 0.16, Vector3.ZERO, RUST, Vector3.ZERO, -1.0, 10))
			a.append(cylinder(0.1, 0.2, Vector3.ZERO, RED, Vector3.ZERO, -1.0, 8))
			for i in 10:
				var angle := i * TAU / 10
				a.append(box(Vector3(0.22, 0.11, 0.3), Vector3(sin(angle) * 0.76, 0, cos(angle) * 0.76), Color("d9dde6"), Vector3(0, angle, 0)))
	cache[key] = merged(a)
	return cache[key]

# Scenery: roadside junk. Rust, olive and teal panels, tyres and pipes.
static func prop(index: int) -> ArrayMesh:
	var key := "prop_%d" % index
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match index:
		0: # wrecked car: no hood, one wheel gone, tilted bumper
			a.append(rbox(Vector3(1.7, 0.6, 2.8), Vector3(0, 0.55, 0), TEAL if index == 0 else RUST, 0.22))
			a.append(rbox(Vector3(1.4, 0.55, 1.3), Vector3(0, 1.05, 0.25), Color("d9d3c0"), 0.2))
			a.append(rbox(Vector3(1.2, 0.3, 0.05), Vector3(0, 1.1, -0.42), RUBBER, 0.03))
			a.append(rbox(Vector3(1.5, 0.06, 1.0), Vector3(0, 0.95, -0.9), RUST, 0.02, Vector3(-0.5, 0, 0)))
			a.append(rbox(Vector3(1.6, 0.14, 0.2), Vector3(0, 0.3, -1.45), GREY, 0.05, Vector3(0, 0, 0.18)))
			for dz in [0.9, -0.9]:
				a.append(cylinder(0.34, 0.24, Vector3(-0.85, 0.34, dz), RUBBER, Vector3(0, 0, PI / 2), -1.0, 10))
			a.append(cylinder(0.34, 0.24, Vector3(0.85, 0.34, 0.9), RUBBER, Vector3(0, 0, PI / 2), -1.0, 10))
			a.append(cylinder(0.34, 0.24, Vector3(1.3, 0.12, -1.1), RUBBER, Vector3.ZERO, -1.0, 10))
		1: # tyre stack with a rusty drum on top
			for i in 3:
				a.append(cylinder(0.62 - i * 0.04, 0.3, Vector3(i * 0.06, 0.15 + i * 0.3, 0), RUBBER, Vector3.ZERO, -1.0, 12))
				a.append(cylinder(0.3, 0.32, Vector3(i * 0.06, 0.15 + i * 0.3, 0), DIRT, Vector3.ZERO, -1.0, 8))
			a.append(cylinder(0.3, 0.5, Vector3(0.1, 1.15, 0), RUST, Vector3(0.3, 0, 0.2), -1.0, 10))
		2: # crushed scrap cube: mismatched panels
			a.append(rbox(Vector3(1.4, 1.2, 1.3), Vector3(0, 0.6, 0), RUST_DARK, 0.16))
			a.append(rbox(Vector3(1.45, 0.4, 1.0), Vector3(0, 0.9, 0.1), TEAL, 0.08, Vector3(0, 0.3, 0)))
			a.append(rbox(Vector3(0.6, 0.9, 1.35), Vector3(-0.5, 0.5, 0), Color("d9d3c0"), 0.08, Vector3(0, 0.1, 0.1)))
			a.append(rbox(Vector3(1.0, 0.9, 0.9), Vector3(0.15, 1.65, 0.1), OLIVE, 0.12, Vector3(0, 0.5, 0.15)))
			a.append(cylinder(0.05, 1.0, Vector3(0.6, 1.9, 0.4), GREY, Vector3(0.4, 0, 0.6), -1.0, 6))
		3: # leaking barrels
			a.append(cylinder(0.45, 1.0, Vector3(-0.4, 0.5, 0), OLIVE, Vector3.ZERO, -1.0, 10))
			a.append(cylinder(0.45, 1.0, Vector3(0.45, 0.5, 0.2), RUST, Vector3.ZERO, -1.0, 10))
			a.append(cylinder(0.47, 0.1, Vector3(-0.4, 0.75, 0), DARK, Vector3.ZERO, -1.0, 10))
			a.append(cylinder(0.47, 0.1, Vector3(0.45, 0.75, 0.2), DARK, Vector3.ZERO, -1.0, 10))
			a.append(cylinder(0.45, 0.9, Vector3(0.1, 0.45, -0.9), RED, Vector3(0, 0, PI / 2), -1.0, 10))
			a.append(cylinder(0.8, 0.02, Vector3(0.2, 0.01, -1.1), Color("2a2150"), Vector3.ZERO, -1.0, 12))
		4: # big junk heap: mound with sticking-out parts
			a.append(sphere(1.7, Vector3(0, 0.2, 0), DIRT, Vector3(1.5, 0.75, 1.3), 12))
			a.append(sphere(1.0, Vector3(0.7, 0.9, 0.2), Color("6f5a40"), Vector3(1.2, 0.8, 1), 10))
			a.append(cylinder(0.55, 0.3, Vector3(-0.9, 1.1, 0.4), RUBBER, Vector3(1.1, 0, 0.5), -1.0, 10))
			a.append(rbox(Vector3(1.3, 0.1, 0.9), Vector3(0.3, 1.6, -0.3), TEAL, 0.03, Vector3(0.3, 0.6, 0.4)))
			a.append(rbox(Vector3(0.9, 0.1, 1.3), Vector3(-0.7, 1.7, -0.1), RUST, 0.03, Vector3(0.2, 0.3, -0.5)))
			a.append(cylinder(0.08, 1.8, Vector3(1.2, 1.7, 0.3), GREY, Vector3(0.2, 0, -0.5), -1.0, 6))
			a.append(rbox(Vector3(0.8, 0.9, 0.7), Vector3(-0.2, 1.3, 0.8), Color("d9d3c0"), 0.1, Vector3(0.2, 0.4, 0.1)))
		_: # fridge stack
			a.append(rbox(Vector3(0.9, 1.7, 0.9), Vector3(0, 0.85, 0), Color("d9d3c0"), 0.12))
			a.append(rbox(Vector3(0.8, 0.05, 0.05), Vector3(0, 1.1, -0.46), GREY, 0.02))
			a.append(rbox(Vector3(0.95, 0.9, 0.9), Vector3(0.15, 2.1, 0.05), TEAL, 0.12, Vector3(0, 0.3, 0.12)))
			a.append(rbox(Vector3(0.4, 0.6, 0.06), Vector3(0.2, 2.1, -0.4), RUST, 0.03, Vector3(0, 0.3, 0.12)))
	cache[key] = merged(a)
	return cache[key]

# Floating icons for utility gate lanes.
static func icon(kind: String) -> ArrayMesh:
	var key := "icon_" + kind
	if cache.has(key):
		return cache[key]
	var a: Array = []
	match kind:
		"heal":
			a.append(rbox(Vector3(0.9, 0.3, 0.3), Vector3.ZERO, GREEN, 0.12))
			a.append(rbox(Vector3(0.3, 0.9, 0.3), Vector3.ZERO, GREEN, 0.12))
		"frenzy":
			for i in 3:
				a.append(cylinder(0.4, 0.14, Vector3(0, -0.3 + i * 0.2, 0), YELLOW if i != 1 else ORANGE, Vector3.ZERO, -1.0, 14))
			a.append(sphere(0.16, Vector3(0, 0.45, 0), LIGHT, Vector3.ONE, 8))
		"surge":
			a.append(sphere(0.42, Vector3.ZERO, PURPLE, Vector3.ONE, 12))
			a.append(rbox(Vector3(0.22, 0.8, 0.2), Vector3(0, 0, 0.36), YELLOW, 0.07, Vector3(0, 0, 0.5)))
		_:
			a.append(sphere(0.4, Vector3.ZERO, YELLOW, Vector3.ONE, 10))
	cache[key] = merged(a)
	return cache[key]

static func gold_coin() -> ArrayMesh:
	if cache.has("gold_coin"):
		return cache.gold_coin
	cache.gold_coin = merged([cylinder(0.34, 0.14, Vector3.ZERO, ORANGE, Vector3(PI / 2, 0, 0), -1.0, 16), cylinder(0.24, 0.18, Vector3.ZERO, Color("fff2a8"), Vector3(PI / 2, 0, 0), -1.0, 14)])
	return cache.gold_coin
