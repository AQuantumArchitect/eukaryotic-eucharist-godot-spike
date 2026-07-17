extends "res://view/entities/body_base.gd"
## Fallback body for anything without a matching bodyPlan/controller — colony_segment and
## orbital_spore sub-drawables (graph_kernel.mjs:7744-7784) mostly land here, since index.html
## draws those as plain filled circles too (its drawEntity dispatch only special-cases the crab;
## everything else without a recognized bodyPlan falls through drawBody's `else drawBlob` branch —
## this generic circle is a deliberately simpler stand-in for that default rather than reusing
## body_blob.gd's full polygon, since these sub-drawables are typically small and numerous).

func _draw() -> void:
	var col := _fill()
	col.a = 0.96 if _friendly() else 0.9
	var r := _r()
	draw_circle(Vector2.ZERO, r, col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, _stroke(), 1.2)
