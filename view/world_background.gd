extends Node2D
## Simplified stand-in for drawWorld's one-shot background (index.html:1509-1518) — a flat fill
## over the kernel's world bounds instead of the full light/oxygen-sampled gradient, canopy, and
## sandy floor detail. Just enough to distinguish "in the world" from empty void; the full gradient
## band is Phase 5 polish. Only redraws when world dimensions change (effectively once, on the
## first snapshot after boot). Drawn 3x world-width wide (index.html:1518 does the same,
## `fillRect(-W, 0, W*3, H)`) so the camera never sees void near the horizontal wrap seam — the
## world is toroidal but this rect is a flat plane, so one copy alone would only cover x in
## [0, world_w] and leave the seam's far side blank.

var world_w := 0.0
var world_h := 0.0

func set_world_size(w: float, h: float) -> void:
	if w == world_w and h == world_h:
		return
	world_w = w
	world_h = h
	queue_redraw()

func _draw() -> void:
	if world_w <= 0.0 or world_h <= 0.0:
		return
	draw_rect(Rect2(-world_w, 0.0, world_w * 3.0, world_h), Color(0.02, 0.05, 0.09))
