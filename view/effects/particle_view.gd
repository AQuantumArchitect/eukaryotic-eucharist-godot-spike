extends Node2D
## Simplified port of drawParticles (index.html:1663-1671) — one flat colored dot per particle
## (dna/spores/enzymes/crystals/ballast) fading with age, instead of per-kind rotated glyph shapes
## (DNA rungs, spore fans, enzyme diamonds, crystal facets). Decorative glyph detail is Phase 5
## polish.

var data: Dictionary = {}

func update(p: Dictionary) -> void:
	data = p
	queue_redraw()

func _draw() -> void:
	var age := float(data.get("age", 0.0))
	var max_age := max(0.0001, float(data.get("maxAge", 1.0)))
	var col := Color(String(data.get("color", "#ffffff")))
	col.a = clamp(1.0 - age / max_age, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 4.0, col)
