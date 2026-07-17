extends Node2D
## Simplified port of drawHazards (index.html:1631-1661) — one flat colored circle per hazard
## (fire/blast, projectiles, seekers, auras) fading with age, instead of per-kind gradient/flicker
## detail. Recognizable danger blob; decorative detail is Phase 5 polish.

var data: Dictionary = {}

func update(h: Dictionary) -> void:
	data = h
	queue_redraw()

func _draw() -> void:
	var age := float(data.get("age", 0.0))
	var max_age := max(0.0001, float(data.get("maxAge", 1.0)))
	var life := clamp(1.0 - age / max_age, 0.0, 1.0)
	var r := float(data.get("radius", 12.0))
	var col := Color(String(data.get("color", "#e8e22c")))
	col.a = 0.6 * life
	draw_circle(Vector2.ZERO, r, col)
