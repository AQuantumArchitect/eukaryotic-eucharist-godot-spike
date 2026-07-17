extends "res://view/entities/body_base.gd"
## Ports drawCiliate (index.html:1924-1930) — an oriented ellipse with a fringe of cilia and an
## off-center nucleus shadow. Cilia beat-cycle animation is cosmetic juice, deferred to Phase 5 —
## drawn as static fringe lines here.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var rx := r * 1.28
	var ry := r * 0.76
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.9
	var stroke_col := _stroke()

	var n := 32
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := float(i) / n * TAU
		pts.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(ang))
	draw_colored_polygon(pts, fill_col)
	draw_polyline(pts, stroke_col, 1.5)

	var cn := 24
	for i in range(cn):
		var a := float(i) / cn * TAU
		var edge := Vector2(cos(a) * rx, sin(a) * ry)
		var out := edge + Vector2(cos(a), sin(a)) * 2.5
		draw_line(edge.rotated(ang), out.rotated(ang), stroke_col, 1.0)

	draw_circle(Vector2(-rx * 0.22, 0.0).rotated(ang), ry * 0.32, Color(0.0, 0.0, 0.0, 0.5))
