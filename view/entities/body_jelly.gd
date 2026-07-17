extends "res://view/entities/body_base.gd"
## Ports drawJelly (index.html:1916-1923) — a domed bell with a scalloped underside and trailing
## tentacles. Tentacle sway (Math.sin(world.t...)) is cosmetic juice, deferred to Phase 5 — these
## are drawn straight/static here.

func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return pts

func _draw() -> void:
	var r := _r()
	var ang := _ang() + PI / 2.0
	var fill_col := _fill()
	fill_col.a = 0.9 if not _friendly() else 0.9
	var stroke_col := _stroke()

	var pts := PackedVector2Array()
	var dome_steps := 16
	for i in range(dome_steps + 1):
		var a := PI - float(i) / dome_steps * PI
		pts.append(Vector2(cos(a), sin(a)) * r)
	pts.append_array(_quad_bezier(Vector2(r, 0.0), Vector2(r * 0.55, r * 0.5), Vector2(0.0, r * 0.32), 8))
	pts.append_array(_quad_bezier(Vector2(0.0, r * 0.32), Vector2(-r * 0.55, r * 0.5), Vector2(-r, 0.0), 8))
	var rotated := PackedVector2Array()
	for p in pts:
		rotated.append(p.rotated(ang))
	draw_colored_polygon(rotated, fill_col)
	draw_polyline(rotated + PackedVector2Array([rotated[0]]), stroke_col, 1.5)

	for i in range(-2, 3):
		var bx := float(i) * r * 0.34
		var p_top := Vector2(bx, r * 0.15).rotated(ang)
		var p_end := Vector2(bx, r * 1.95).rotated(ang)
		draw_line(p_top, p_end, stroke_col, 1.5)
