extends "res://view/entities/body_base.gd"
## Ports drawBlob (index.html:1896-1903) — the default body plan (player included). Per-frame
## vertex wobble/speed-stretch is cosmetic juice, deferred to Phase 5; this is the static
## silhouette underneath it.

func _draw() -> void:
	var r := _r()
	var n := 28
	var pts := PackedVector2Array()
	for i in range(n):
		var a := float(i) / n * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.90
	draw_colored_polygon(pts, fill_col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), _stroke(), 2.5 if entity.get("kind") == "player" else 1.5)
