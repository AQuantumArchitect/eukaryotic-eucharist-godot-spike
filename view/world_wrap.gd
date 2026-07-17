class_name WorldWrap
extends RefCounted
## Ports index.html's wrapX()/dxWrap() (index.html:186-187) verbatim. The kernel's world is
## horizontally toroidal but does NOT export this geometry — it's stateless coordinate math, not
## simulation, so this is the one accepted exception to "the kernel is the only source of truth."

static func wrap_x(x: float, world_w: float) -> float:
	var wrapped := fmod(x, world_w)
	if wrapped < 0.0:
		wrapped += world_w
	return wrapped

## Shortest signed horizontal distance from ax to bx around the wrap seam.
static func dx_wrap(ax: float, bx: float, world_w: float) -> float:
	var dx := bx - ax
	if dx > world_w / 2.0:
		dx -= world_w
	if dx < -world_w / 2.0:
		dx += world_w
	return dx
