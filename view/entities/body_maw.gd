extends "res://view/entities/body_base.gd"
## Ports drawMaw (index.html:1931-1937) — a pac-man-style wedge facing the entity's aim direction.
## The gape pulse (Math.sin(world.t...)) is cosmetic juice, deferred to Phase 5 — drawn at a fixed
## mid-gape here.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var gape := 0.65
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.9
	var stroke_col := _stroke()

	var n := 20
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(n + 1):
		var a := gape + float(i) / n * (TAU - 2.0 * gape)
		pts.append(Vector2(cos(a), sin(a)).rotated(ang) * r)
	draw_colored_polygon(pts, fill_col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), stroke_col, 1.5)
