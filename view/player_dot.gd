extends Node2D
## Phase 1 placeholder for the player body — a single flat circle. Replaced by the full
## body-plan-dispatched entity pool in Phase 2; deliberately not built out further here.

var radius := 22.0
var body_color := Color("#86d2ff")

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, body_color)
