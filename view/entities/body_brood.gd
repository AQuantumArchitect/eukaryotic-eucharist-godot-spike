extends "res://view/entities/body_base.gd"
## Ports drawBrood (index.html:1887-1895) — a soft green haze halo, a ring of small "egg" bodies,
## a core, and an inner pulse dot. Orbit rotation/pulse animation is cosmetic juice, deferred to
## Phase 5 — the ring is drawn at a fixed layout here.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var fill_col := _fill()
	var stroke_col := _stroke()

	draw_circle(Vector2.ZERO, r * 1.9, Color(0.373, 0.878, 0.627, 0.10))

	var n := 6
	for i in range(n):
		var a := ang + float(i) / n * TAU
		var bp := Vector2(cos(a), sin(a)) * r * 1.25
		draw_circle(bp, r * 0.16, fill_col)
		draw_arc(bp, r * 0.16, 0.0, TAU, 10, stroke_col, 1.0)

	var core := fill_col
	core.a = 0.96 if _friendly() else 0.92
	draw_circle(Vector2.ZERO, r, core)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, stroke_col, 1.2)
	draw_circle(Vector2.ZERO, r * 0.34, Color(0.373, 0.878, 0.627, 0.6))
