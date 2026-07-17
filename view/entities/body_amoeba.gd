extends "res://view/entities/body_base.gd"
## Ports drawAmoeba (index.html:1905-1910) — a lobed static polygon with a dark nucleus shadow.
## Per-frame lobe undulation (Math.sin(world.t...)) is cosmetic juice, deferred to Phase 5.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.9
	var stroke_col := _stroke()

	var n := 34
	var pts := PackedVector2Array()
	for i in range(n):
		var a := float(i) / n * TAU
		var lobe := sin(a * 3.0) * 0.20
		var rr := r * (1.0 + lobe)
		pts.append(Vector2(cos(a), sin(a)).rotated(ang) * rr)
	draw_colored_polygon(pts, fill_col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), stroke_col, 1.5)
	draw_circle(Vector2.ZERO, r * 0.32, Color(0.0, 0.0, 0.0, 0.4))
