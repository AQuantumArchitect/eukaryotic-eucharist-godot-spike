class_name BodyBase
extends Node2D
## Shared state every body-plan script needs: the live entity Dictionary from
## getRenderProjection().entities[] plus the kernel's own sim clock (for the hit-flash/duress
## color math in BodyColors). EntityPool calls update() every frame instead of touching these
## fields directly; subclasses override _draw() and read _r()/_ang()/_fill()/_stroke() etc.

var entity: Dictionary = {}
var sim_t := 0.0

func update(e: Dictionary, t: float) -> void:
	entity = e
	sim_t = t
	queue_redraw()

func _r() -> float:
	return float(entity.get("r", 18.0))

func _ang() -> float:
	return float(entity.get("phase", 0.0))

func _friendly() -> bool:
	return bool(entity.get("friendly", false))

func _fill() -> Color:
	return BodyColors.fill(entity, sim_t)

func _stroke() -> Color:
	return BodyColors.stroke(entity)
