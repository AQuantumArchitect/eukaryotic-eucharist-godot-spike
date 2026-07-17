extends Label
## Ports updateControls()'s key -> action rows (index.html:1233) as a static legend list, filtered
## by whether the corresponding hud.actions[] entry (getAvailableActions, graph_kernel.mjs:7089)
## is actually present on this body — an organ-less cell doesn't see a keybind it can't use yet.

func apply(hud: Dictionary) -> void:
	if hud.is_empty():
		text = ""
		return
	var actions: Array = hud.get("actions", [])
	var has := {}
	for a in actions:
		has[a.get("id")] = true
	var rows := [
		["WASD", "Swim", true],
		["F / RMB", "Feed", true],
		["Q", "Lipid repair", has.has("repair")],
		["LMB", "Fire weapons", true],
		["R / X", "Toxic Launcher", has.has("acid")],
		["J", "Flamethrower", has.has("flame")],
		["C", "Sporo-toxic gun", has.has("sporeshot")],
		["Z", "Harpoon spine", has.has("harpoon")],
		["G", "Mark for the swarm", has.has("mark")],
		["B", "Engulf", has.has("engulf")],
		["H", "Crystal ward", has.has("ward")],
		["V", "Toxin cloud", has.has("cloud")],
		["Shift", "Dash", has.has("dash")],
		["T", "Jettison", has.has("jettison")],
		["U", "Compact waste", has.has("compact")],
		["M", "Divide", has.has("divide")],
		["E", "Yuki graft chamber", bool(hud.get("nearYuki", false))],
	]
	var lines := PackedStringArray()
	for r in rows:
		if r[2]:
			lines.append("%s — %s" % [r[0], r[1]])
	text = "\n".join(lines)
