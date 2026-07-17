class_name BodyColors
extends RefCounted
## Ports bodyFill()/bodyStroke() from index.html (:1851-1875): the hit-flash pulse, the slow
## O2/toxin "duress" tint, and the player/friendly stroke rule. The toxin tint is simplified to a
## flat toxins-yellow blend rather than porting dagToxinTint's own gradient — "recognizable, not
## pixel-perfect" per this port's own scoping (see README).

static func fill(e: Dictionary, sim_t: float) -> Color:
	if e.get("kind") == "player" and float(e.get("combatHit", 0.0)) > 0.0:
		return Color("#ff2e2e")
	var base := Color(String(e.get("color", "#8ceaa0")))
	var hit := float(e.get("hit", 0.0))
	if hit > 0.0:
		var freq := 6.0 + hit * 18.0
		var p := 0.5 + 0.5 * sin(sim_t * freq)
		return base.lerp(Color.WHITE, clamp(0.25 + 0.55 * p * hit, 0.0, 1.0))
	var o2_excess := clamp((float(e.get("oxygen", 0.0)) - float(e.get("oxygenTolerance", 0.0))) / 0.15, 0.0, 1.0)
	var toxin_cap := float(e.get("toxinCap", 0.0))
	var tox_frac := 0.0
	if toxin_cap > 0.0:
		tox_frac = clamp((float(e.get("toxins", 0.0)) - toxin_cap * 0.68) / (toxin_cap * 0.32), 0.0, 1.0)
	if o2_excess > 0.02 or tox_frac > 0.02:
		var p2 := 0.5 + 0.5 * sin(sim_t * 2.4)
		if tox_frac >= o2_excess:
			return base.lerp(Color("#e8e22c"), clamp(0.18 + 0.34 * tox_frac * p2, 0.0, 1.0))
		return base.lerp(Color("#a878ff"), clamp(0.18 + 0.34 * o2_excess * p2, 0.0, 1.0))
	return base

static func stroke(e: Dictionary) -> Color:
	if e.get("kind") == "player":
		return Color("#eaffff")
	if e.get("friendly", false):
		return Color("#7fffe0")
	return Color(0.0, 0.0, 0.0, 0.45)
