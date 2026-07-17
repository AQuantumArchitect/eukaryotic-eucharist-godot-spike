extends "res://view/entities/body_base.gd"
## Ports drawColonial (index.html:1938-1945) — five lobes around a bright core. Orbiting spot
## decorations and per-frame lobe drift are cosmetic juice, deferred to Phase 5.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var fill_col := _fill()
	var lobe_col := fill_col
	lobe_col.a = 0.9 if not _friendly() else 0.9
	var stroke_col := _stroke()
	var lobes := 5
	for i in range(lobes):
		var a := ang + float(i) / lobes * TAU
		var lp := Vector2(cos(a), sin(a)) * r * 0.44
		draw_circle(lp, r * 0.56, lobe_col)
		draw_arc(lp, r * 0.56, 0.0, TAU, 16, stroke_col, 1.5)
	var core := fill_col
	core.a = 0.96
	draw_circle(Vector2.ZERO, r * 0.62, core)
	draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 20, stroke_col, 1.5)
