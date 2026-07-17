extends "res://view/entities/body_base.gd"
## Ports drawSpiny (index.html:1911-1915) — n=10 static spikes around a core circle. Per-frame
## spike-length jitter is cosmetic juice, deferred to Phase 5.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.92
	var stroke_col := _stroke()
	var n := 10
	var inner := r * 0.9
	var outer := r * 1.55
	for i in range(n):
		var a := ang + float(i) / n * TAU
		var p0 := Vector2(cos(a - 0.13), sin(a - 0.13)) * inner
		var p1 := Vector2(cos(a), sin(a)) * outer
		var p2 := Vector2(cos(a + 0.13), sin(a + 0.13)) * inner
		var tri := PackedVector2Array([p0, p1, p2])
		draw_colored_polygon(tri, fill_col)
		draw_polyline(tri + PackedVector2Array([p0]), stroke_col, 1.4)
	draw_circle(Vector2.ZERO, r, fill_col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, stroke_col, 1.4)
