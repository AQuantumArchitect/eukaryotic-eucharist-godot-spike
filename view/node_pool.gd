class_name NodePool
extends RefCounted
## Generic "diff a live kernel array against tracked Godot nodes" pool, shared by the fields/
## hazards/particles layers (entities get their own EntityPool since body-plan dispatch needs
## more than this generic shape). Same new/update/remove diff every frame: a fresh id spawns a
## node via `make_node`, an existing id gets `on_update` called with its node, an id no longer
## present gets freed. Cheap relative to the population sizes involved (POP_CAP=190,
## graph_kernel.mjs:5724; fields/hazards/particles are smaller and shorter-lived) — a real
## freelist-by-type would only be worth it if profiling actually showed churn cost.

var _layer: Node2D
var _make_node: Callable
var _nodes_by_id: Dictionary = {}

func _init(layer: Node2D, make_node: Callable) -> void:
	_layer = layer
	_make_node = make_node

## `items`: array of Dictionaries, each with an "id" key.
## `position_for(item)` -> Vector2 (world position) or null to cull/despawn this item this frame.
## `on_update(node, item)` is called on every item that stays on-screen, node already positioned.
func update(items: Array, position_for: Callable, on_update: Callable) -> void:
	var seen := {}
	for item in items:
		var id = item.get("id")
		if id == null:
			continue
		var pos = position_for.call(item)
		if pos == null:
			if _nodes_by_id.has(id):
				_nodes_by_id[id].queue_free()
				_nodes_by_id.erase(id)
			continue
		seen[id] = true
		var node = _nodes_by_id.get(id)
		if node == null:
			node = _make_node.call(item)
			_layer.add_child(node)
			_nodes_by_id[id] = node
		node.position = pos
		on_update.call(node, item)
	for id in _nodes_by_id.keys():
		if not seen.has(id):
			_nodes_by_id[id].queue_free()
			_nodes_by_id.erase(id)

func count() -> int:
	return _nodes_by_id.size()
