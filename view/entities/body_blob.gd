extends "res://view/entities/body_base.gd"
## Ports drawBlob (index.html:1896-1903) — the default body plan (player included, since its
## bodyPlan is null). Phase 5 (light pass): per-vertex sine wobble + speed-based
## stretch/shrink, same formula as the original — this is the single most-visible body plan
## (every player and most unclassified NPCs use it), so it's the one animation worth the cost in
## a light pass. Membrane-layer rings and every other body plan's own animation stay static.

func _draw() -> void:
	var r := _r()
	var ang := _ang()
	var hp_frac := clamp(float(entity.get("hp", 1.0)) / max(0.0001, float(entity.get("maxHp", 1.0))), 0.0, 1.0)
	var vx := float(entity.get("vx", 0.0))
	var vy := float(entity.get("vy", 0.0))
	var speed: float = clamp(sqrt(vx * vx + vy * vy) / 260.0, 0.0, 1.0)
	var stretch: float = 1.0 + speed * 0.22
	var shrink: float = 1.0 - speed * 0.12
	var phase := float(entity.get("phase", 0.0))

	var n := 28
	var pts := PackedVector2Array()
	for i in range(n):
		var a := float(i) / n * TAU
		var wob: float = sin(a * 3.0 + sim_t * 5.0 + phase) * r * (1.0 - hp_frac) * 0.09
		var local := Vector2((r + wob) * stretch, (r + wob) * shrink)
		var pt := Vector2(cos(a) * local.x, sin(a) * local.y)
		pts.append(pt.rotated(ang))
	var fill_col := _fill()
	fill_col.a = 0.96 if _friendly() else 0.90
	draw_colored_polygon(pts, fill_col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), _stroke(), 2.5 if entity.get("kind") == "player" else 1.5)
