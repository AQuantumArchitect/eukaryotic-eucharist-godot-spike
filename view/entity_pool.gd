class_name EntityPool
extends RefCounted
## Diffs getRenderProjection().entities[] against tracked Godot nodes each frame: new ids spawn a
## BodyFactory node, existing ids get position + update() (-> queue_redraw()), ids no longer
## present or now off-screen get freed. Also does the toroidal-wrap "nearest offset" positioning
## (WorldWrap.dx_wrap picks whichever unwrapped copy of an entity's x is nearest the camera) —
## cheaper than index.html's brute-force 3x world redraw (index.html:1507) since Godot holds
## persistent pooled nodes rather than redrawing immediate-mode every frame. Ghost-duplication at
## the wrap seam itself is Phase 5 polish, not implemented here (see README).

var _layer: Node2D
var _nodes_by_id: Dictionary = {}

func _init(layer: Node2D) -> void:
	_layer = layer

func update(entities: Array, sim_t: float, camera_pos: Vector2, viewport_size: Vector2, world_w: float, cull_pad: float) -> void:
	var seen := {}
	var top_left := camera_pos - viewport_size * 0.5
	for e in entities:
		var id = e.get("id")
		if id == null:
			continue
		var r := float(e.get("r", 18.0))
		var raw_x := float(e.get("x", 0.0))
		var unwrapped_x := camera_pos.x + WorldWrap.dx_wrap(camera_pos.x, raw_x, world_w)
		var pos := Vector2(unwrapped_x, float(e.get("y", 0.0)))
		var local := pos - top_left
		var pad := r + cull_pad
		var onscreen := local.x >= -pad and local.x <= viewport_size.x + pad and local.y >= -pad and local.y <= viewport_size.y + pad
		if not onscreen:
			if _nodes_by_id.has(id):
				_nodes_by_id[id].queue_free()
				_nodes_by_id.erase(id)
			continue
		seen[id] = true
		var node = _nodes_by_id.get(id)
		if node == null:
			node = BodyFactory.node_for(e)
			_layer.add_child(node)
			_nodes_by_id[id] = node
		node.position = pos
		node.update(e, sim_t)
	for id in _nodes_by_id.keys():
		if not seen.has(id):
			_nodes_by_id[id].queue_free()
			_nodes_by_id.erase(id)

func count() -> int:
	return _nodes_by_id.size()
