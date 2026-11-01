extends RefCounted
# Conservative union of painted control rectangles, not an opaque screenshot-pixel count.
static func rect_union(rects: Array) -> float:
	var xs: Array = []
	for r in rects:
		xs.append(r.position.x)
		xs.append(r.end.x)
	xs.sort()
	var area := 0.0
	for i in range(1, xs.size()):
		var width: float = xs[i] - xs[i - 1]
		if width <= 0: continue
		var spans: Array = []
		for r in rects:
			if r.position.x < xs[i] and r.end.x > xs[i - 1]: spans.append([r.position.y, r.end.y])
		spans.sort_custom(func(a, b): return a[0] < b[0])
		var bottom := -INF
		var height := 0.0
		for span in spans:
			height += maxf(0.0, float(span[1]) - maxf(bottom, float(span[0])))
			bottom = maxf(bottom, float(span[1]))
		area += width * height
	return area

static func controls(node: Node, bounds: Rect2, rows: Array, rects: Array) -> void:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.modulate.a > 0.01:
			var text := str(child.text) if child is Label or child is BaseButton else ""
			var painted := child is BaseButton or child is ProgressBar or child is PanelContainer or child is UiIcon or child is UiRing or (child is Label and not text.is_empty())
			var r: Rect2 = child.get_global_rect().intersection(bounds)
			# Scroll clipping is included in the inventory, never counted outside its visible container.
			var ancestor := child.get_parent()
			while ancestor is Control:
				if ancestor.clip_contents: r = r.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			if painted and r.has_area():
				rows.append({"path": str(child.get_path()), "class": child.get_class(), "text": text, "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "font_px": child.get_theme_font_size("font_size") if child is Label or child is BaseButton else 0, "tappable": child is BaseButton, "color": str(child.modulate)})
				if not (child is PanelContainer and child.get_theme_stylebox("panel") is StyleBoxEmpty): rects.append(r)
		controls(child, bounds, rows, rects)

static func measure(game) -> Dictionary:
	var bounds: Rect2 = game.get_viewport().get_visible_rect()
	var rows: Array = []
	var rects: Array = []
	var active_play: bool = game.hud.visible and not game.overlay.visible
	if active_play: controls(game.hud, bounds, rows, rects)
	var hud_area := rect_union(rects)
	var popup_count := 0
	for label in game.world.popups:
		if active_play and label.visible and label.modulate.a > 0.01:
			popup_count += 1
			var center: Vector2 = game.camera.unproject_position(label.global_position)
			var width := float(label.text.length() * label.font_size) * 0.3
			rects.append(Rect2(center - Vector2(width / 2, 22), Vector2(width, 44)).intersection(bounds))
	var hero_count := 0
	if game.get("ui_v2") != null and game.get("ui_v2_enabled"):
		hero_count = int(game.ui_v2.hero_time > 0)
	var full_screen := int(active_play and game.flash.visible and game.flash.color.a > 0.01)
	return {"logical_size": [bounds.size.x, bounds.size.y], "hud_area_pct": 100.0 * hud_area / bounds.get_area(), "hud_popup_area_pct": 100.0 * rect_union(rects) / bounds.get_area(), "popups": popup_count, "hero_events": hero_count, "full_screen_effects": full_screen, "attention_groups": popup_count + hero_count + full_screen + int(not game.toast_label.text.is_empty()) + int(not game.world.fx_items.is_empty()), "inventory": rows}
