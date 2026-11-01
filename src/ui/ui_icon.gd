class_name UiIcon extends Control
# Small vector icons drawn in code (no texture files): coin, heart, bolt, star, skull, pause, dice, flame, gear, lock, wrench.
const OUTLINE = Color("34433f")
var kind := "coin"
var tint := Color.WHITE
var value := 1.0

static func make(icon_kind: String, size := 56.0, color := Color.WHITE) -> UiIcon:
	var icon := UiIcon.new()
	icon.kind = icon_kind
	icon.tint = color
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	match kind:
		"coin":
			draw_circle(c, s * 0.48, OUTLINE)
			draw_circle(c, s * 0.4, Color("ffb21a"))
			draw_circle(c + Vector2(0, -s * 0.03), s * 0.33, Color("ffd84a"))
			draw_arc(c, s * 0.22, 0, TAU, 20, Color("e08a00"), s * 0.07)
		"heart":
			var pts := PackedVector2Array([c + Vector2(0, s * 0.42), c + Vector2(-s * 0.46, -s * 0.05), c + Vector2(-s * 0.4, -s * 0.28), c + Vector2(-s * 0.2, -s * 0.4), c + Vector2(0, -s * 0.22), c + Vector2(s * 0.2, -s * 0.4), c + Vector2(s * 0.4, -s * 0.28), c + Vector2(s * 0.46, -s * 0.05)])
			draw_colored_polygon(_grow(pts, c, 1.18), OUTLINE)
			draw_colored_polygon(pts, tint if tint != Color.WHITE else Color("ff4d6a"))
			draw_circle(c + Vector2(-s * 0.2, -s * 0.2), s * 0.07, Color(1, 1, 1, 0.8))
		"bolt":
			var pts := PackedVector2Array([c + Vector2(s * 0.08, -s * 0.48), c + Vector2(-s * 0.3, s * 0.06), c + Vector2(-s * 0.02, s * 0.06), c + Vector2(-s * 0.1, s * 0.48), c + Vector2(s * 0.32, -s * 0.1), c + Vector2(s * 0.04, -s * 0.1)])
			draw_colored_polygon(_grow(pts, c, 1.2), OUTLINE)
			draw_colored_polygon(pts, tint if tint != Color.WHITE else Color("ffe14a"))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var radius := s * (0.48 if i % 2 == 0 else 0.22)
				var angle := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(_grow(pts, c, 1.16), OUTLINE)
			draw_colored_polygon(pts, tint if tint != Color.WHITE else Color("ffd23f"))
		"skull":
			draw_circle(c + Vector2(0, -s * 0.05), s * 0.46, OUTLINE)
			draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.2, s * 0.48, s * 0.28), OUTLINE)
			draw_circle(c + Vector2(0, -s * 0.05), s * 0.38, Color("f2f2f7"))
			draw_rect(Rect2(c.x - s * 0.17, c.y + s * 0.2, s * 0.34, s * 0.2), Color("f2f2f7"))
			draw_circle(c + Vector2(-s * 0.15, -s * 0.05), s * 0.1, OUTLINE)
			draw_circle(c + Vector2(s * 0.15, -s * 0.05), s * 0.1, OUTLINE)
		"pause":
			for dx in [-0.17, 0.17]:
				draw_rect(Rect2(c.x + s * dx - s * 0.12, c.y - s * 0.3, s * 0.24, s * 0.6), OUTLINE)
				draw_rect(Rect2(c.x + s * dx - s * 0.08, c.y - s * 0.26, s * 0.16, s * 0.52), Color.WHITE)
		"dice":
			draw_rect(Rect2(c - Vector2(s, s) * 0.4, Vector2(s, s) * 0.8), OUTLINE)
			draw_rect(Rect2(c - Vector2(s, s) * 0.34, Vector2(s, s) * 0.68), Color.WHITE)
			for d in [Vector2(-0.17, -0.17), Vector2(0.17, 0.17), Vector2(0, 0), Vector2(0.17, -0.17), Vector2(-0.17, 0.17)]:
				draw_circle(c + d * s, s * 0.07, OUTLINE)
		"flame":
			var pts := PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.34, s * 0.2), c + Vector2(0, s * 0.46), c + Vector2(-s * 0.34, s * 0.2), c + Vector2(-s * 0.28, -s * 0.12), c + Vector2(-s * 0.1, -s * 0.1)])
			draw_colored_polygon(_grow(pts, c, 1.15), OUTLINE)
			draw_colored_polygon(pts, Color("ff7a1a"))
			draw_circle(c + Vector2(0, s * 0.22), s * 0.16, Color("ffd23f"))
		"gear":
			for i in 8:
				var angle := i * TAU / 8
				draw_circle(c + Vector2(cos(angle), sin(angle)) * s * 0.36, s * 0.13, OUTLINE)
			draw_circle(c, s * 0.38, OUTLINE)
			draw_circle(c, s * 0.3, Color("c8d0e0"))
			draw_circle(c, s * 0.12, OUTLINE)
		"lock":
			draw_arc(c + Vector2(0, -s * 0.12), s * 0.22, PI, TAU, 14, OUTLINE, s * 0.14)
			draw_rect(Rect2(c.x - s * 0.34, c.y - s * 0.08, s * 0.68, s * 0.5), OUTLINE)
			draw_rect(Rect2(c.x - s * 0.28, c.y - s * 0.02, s * 0.56, s * 0.38), Color("ffb21a"))
		"wrench":
			draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(s * 0.2, -s * 0.2), OUTLINE, s * 0.26)
			draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(s * 0.2, -s * 0.2), Color("c8d0e0"), s * 0.14)
			draw_circle(c + Vector2(s * 0.25, -s * 0.25), s * 0.22, OUTLINE)
			draw_circle(c + Vector2(s * 0.25, -s * 0.25), s * 0.14, Color("c8d0e0"))
		"dot":
			draw_circle(c, s * 0.4, OUTLINE)
			draw_circle(c, s * 0.3, tint)

func _grow(pts: PackedVector2Array, center: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + (p - center) * factor)
	return out
