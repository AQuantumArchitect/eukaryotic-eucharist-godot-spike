extends Label
## Read-only vitals readout: HP, oxygen, depth, pressure, and every RESOURCES bar (hud.resources[],
## graph_kernel.mjs:7659) — the same getHudProjection() data index.html's DOM `.vital` bars render,
## as plain text lines. Native ProgressBar/GridContainer controls are worth the extra scene
## complexity in Phase 4's shop panel; a read-only readout doesn't need them.

func apply(hud: Dictionary) -> void:
	if hud.is_empty():
		text = "—"
		return
	var lines := PackedStringArray()
	var hp: Dictionary = hud.get("hp", {})
	lines.append("HP: %.0f / %.0f" % [float(hp.get("value", 0.0)), float(hp.get("max", 1.0))])
	var oxygen: Dictionary = hud.get("oxygen", {})
	lines.append("O2: %.1f / %.1f" % [float(oxygen.get("value", 0.0)), float(oxygen.get("max", 1.0))])
	var depth: Dictionary = hud.get("depth", {})
	lines.append("Depth: %.0f (%s)" % [float(depth.get("value", 0.0)), String(depth.get("zone", ""))])
	var pressure: Dictionary = hud.get("pressure", {})
	lines.append("Pressure: %.2f" % float(pressure.get("value", 0.0)))
	for res in hud.get("resources", []):
		lines.append("%s: %.0f / %.0f" % [String(res.get("label", res.get("id", ""))), float(res.get("value", 0.0)), float(res.get("max", 0.0))])
	text = "\n".join(lines)
