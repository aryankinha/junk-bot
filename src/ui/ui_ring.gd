class_name UiRing extends Control
# Circular progress ring drawn around round buttons (special / overdrive).
var value := 0.0
var color := Color("ffd23f")
var glow := false
var pulse := 0.0

func _process(delta: float) -> void:
	if glow:
		pulse += delta
		queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 8.0
	draw_arc(c, radius, 0, TAU, 48, Color("d9dfd5"), 16.0)
	if value > 0.0:
		var width := 12.0 + (sin(pulse * 8.0) * 2.5 if glow else 0.0)
		draw_arc(c, radius, -PI / 2, -PI / 2 + TAU * clampf(value, 0, 1), 48, color, width)
