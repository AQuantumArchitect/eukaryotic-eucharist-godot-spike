extends ColorRect
## Simplified stand-in for drawVignette (index.html:1960) — a flat full-screen dark tint scaled by
## depth/oxygen danger, instead of a true radial gradient centered on the player (Godot has no
## built-in radial-fill primitive without a shader). Light-Phase-5 version of this signal: still
## readable as "things are getting dangerous," just not radial. A real radial vignette (shader or
## concentric-circle _draw()) stays a later polish item if ever revisited.

func apply(hud: Dictionary) -> void:
	if hud.is_empty():
		color = Color(0.0, 0.0, 0.0, 0.0)
		return
	var depth: Dictionary = hud.get("depth", {})
	var depth_frac := clamp(float(depth.get("value", 0.0)) / max(1.0, float(depth.get("max", 1.0))), 0.0, 1.0)
	var oxygen: Dictionary = hud.get("oxygen", {})
	var o2_excess := clamp((float(oxygen.get("value", 0.0)) - float(oxygen.get("tolerance", 0.0))) / 0.15, 0.0, 1.0)
	var danger := clamp(depth_frac * 0.5 + o2_excess * 0.6, 0.0, 0.55)
	color = Color(0.0, 0.0, 0.05, danger)
