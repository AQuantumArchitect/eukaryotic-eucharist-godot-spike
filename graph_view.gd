extends Control
## Native GraphEdit view of the kernel's existing "DAG HUD" data (ORGAN_GRAPH_EDGES /
## ORGAN_GRAPH_ROLE, src/graph_kernel.mjs:2070 / :551) — a live read-only mirror of the
## organelle -> resource/vital flow graph, fed entirely by the unmodified JS kernel via
## KernelBridge. No simulation logic lives here.

@onready var graph: GraphEdit = $GraphEdit
@onready var status_label: Label = $StatusLabel

var node_by_id := {}
var organelle_ids := {}
var poll_timer := 0.0
const POLL_INTERVAL := 1.0 # low-frequency structural view — the kernel ticks on its own cadence regardless

func _ready() -> void:
	if not KernelBridge.is_bridge_available():
		status_label.text = "JavaScriptBridge not available — run the exported Web build in a browser, not the editor."
		return
	if not KernelBridge.boot(1001):
		status_label.text = "Kernel boot failed — check the browser console."
		return
	var snap := KernelBridge.step_and_snapshot(0.0)
	if snap.is_empty():
		status_label.text = "First snapshot came back empty — check the browser console."
		return
	_build_graph(snap)
	status_label.text = "Live."

func _process(delta: float) -> void:
	if not KernelBridge.booted:
		return
	poll_timer += delta
	if poll_timer < POLL_INTERVAL:
		return
	poll_timer = 0.0
	_apply_snapshot(KernelBridge.step_and_snapshot(POLL_INTERVAL))

func _build_graph(snap: Dictionary) -> void:
	var edges: Array = snap.get("edges", [])
	var roles: Dictionary = snap.get("roles", {})
	for id in roles.keys():
		organelle_ids[str(id)] = true
	var ids := {}
	for id in roles.keys():
		ids[str(id)] = true
	for e in edges:
		ids[str(e[0])] = true
		ids[str(e[1])] = true
	var i := 0
	var cols := 8
	for id in ids.keys():
		var gn := GraphNode.new()
		gn.title = id
		gn.name = "n_%d" % i # GraphNode names must be safe identifiers; keep the real id in title/meta
		gn.set_meta("kernel_id", id)
		gn.position_offset = Vector2((i % cols) * 220, (i / cols) * 110)
		var lbl := Label.new()
		lbl.name = "val"
		lbl.text = "—"
		gn.add_child(lbl)
		gn.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
		graph.add_child(gn)
		node_by_id[id] = gn
		i += 1
	for e in edges:
		var a := str(e[0])
		var b := str(e[1])
		if node_by_id.has(a) and node_by_id.has(b):
			graph.connect_node(node_by_id[a].name, 0, node_by_id[b].name, 0)
	_apply_snapshot(snap)

func _apply_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var hud: Dictionary = snap.get("hud", {})
	if hud.is_empty():
		return
	var owned := {}
	for org in hud.get("organelles", []):
		owned[str(org.get("id"))] = org.get("count", 0)
	for res in hud.get("resources", []):
		var id := str(res.get("id"))
		if not node_by_id.has(id):
			continue
		var gn: GraphNode = node_by_id[id]
		var mx: float = float(res.get("max", 0))
		var val: float = float(res.get("value", 0))
		var frac: float = clamp(val / mx, 0.0, 1.0) if mx > 0.0 else 0.0
		(gn.get_node("val") as Label).text = "%.0f / %.0f" % [val, mx]
		gn.self_modulate = Color(1.0, 1.0 - frac * 0.5, 1.0 - frac * 0.7)
	for id in organelle_ids.keys():
		if not node_by_id.has(id):
			continue
		var gn: GraphNode = node_by_id[id]
		if owned.has(id):
			gn.modulate = Color(1, 1, 1, 1)
			(gn.get_node("val") as Label).text = "x%d" % int(owned[id])
		else:
			gn.modulate = Color(1, 1, 1, 0.3)
	status_label.text = "t = %.1fs" % float(snap.get("t", 0.0))
