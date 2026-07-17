extends "res://view/entities/body_base.gd"
## Ports drawCrab (index.html:1705-1731) — the Horseshroomba scavenger, hand-special-cased by
## e.controller==='shroomba' rather than bodyPlan (index.html:1734). A dark fungal halo, a ring of
## spikes, four carapace lobes, a central dome, a pulsing maw shadow, and a warm shop-marker cap.
## Per-frame spike jitter/march drift and the maw pulse are cosmetic juice, deferred to Phase 5.

func _draw() -> void:
	var r := _r()

	draw_circle(Vector2.ZERO, r, Color(0.165, 0.110, 0.204, 0.4))

	var n_spikes := clampi(int(round(float(entity.get("cellCount", 240)) / 28.0)), 7, 11)
	var spike_col := Color(0.47, 0.36, 0.53, 0.92)
	for i in range(n_spikes):
		var a := float(i) / n_spikes * TAU
		var length := r * 1.1
		var w := r * 0.09
		var base_pt := Vector2(cos(a), sin(a)) * r * 0.52
		var perp := Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * w
		var tip := Vector2(cos(a), sin(a)) * length
		draw_colored_polygon(PackedVector2Array([base_pt + perp, base_pt - perp, tip]), spike_col)

	for i in range(4):
		var a := float(i) / 4.0 * TAU
		var lp := Vector2(cos(a), sin(a)) * r * 0.26
		draw_circle(lp, r * 0.36, Color(0.42, 0.31, 0.51))

	draw_circle(Vector2.ZERO, r * 0.44, Color(0.53, 0.42, 0.61))
	draw_circle(Vector2.ZERO, r * 0.17, Color(0.07, 0.035, 0.094, 0.5))
	draw_circle(Vector2(0.0, -r * 0.34), r * 0.10, Color(0.9, 0.71, 0.47, 0.9))
