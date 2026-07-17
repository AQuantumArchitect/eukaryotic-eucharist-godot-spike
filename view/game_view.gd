extends Node2D
## Phase 2: full entity/field/hazard/particle rendering, layered on Phase 0/1's real game-step
## channel. The Phase-1 PlayerDot placeholder is gone — the player is now just another pooled
## entity (its bodyPlan is null, so BodyFactory falls through to the same blob default
## index.html's own drawBody dispatch uses, index.html:1876-1885). Every tunable is read from
## config/sim_params.tres (a SimParams Resource) instead of a literal in this script.

@onready var camera: Camera2D = $MainCamera
@onready var status_label: Label = $HudLayer/StatusLabel
@onready var world_background: Node2D = $WorldBackground
@onready var field_layer: Node2D = $FieldLayer
@onready var hazard_layer: Node2D = $HazardLayer
@onready var particle_layer: Node2D = $ParticleLayer
@onready var entity_layer: Node2D = $EntityLayer

const FIELD_SCRIPT := preload("res://view/effects/field_view.gd")
const HAZARD_SCRIPT := preload("res://view/effects/hazard_view.gd")
const PARTICLE_SCRIPT := preload("res://view/effects/particle_view.gd")
const CULL_PAD := 80.0

var params: SimParams = load("res://config/sim_params.tres")
var world_w := 2240.0
var world_h := 7840.0
var booted := false
var player_pos := Vector2.ZERO

var entity_pool: EntityPool
var field_pool: NodePool
var hazard_pool: NodePool
var particle_pool: NodePool

func _ready() -> void:
	entity_pool = EntityPool.new(entity_layer)
	field_pool = NodePool.new(field_layer, func(_item): return _make_node(FIELD_SCRIPT))
	hazard_pool = NodePool.new(hazard_layer, func(_item): return _make_node(HAZARD_SCRIPT))
	particle_pool = NodePool.new(particle_layer, func(_item): return _make_node(PARTICLE_SCRIPT))

	if not KernelBridge.is_bridge_available():
		status_label.text = "JavaScriptBridge not available — run the exported Web build in a browser, not the editor."
		return
	if not KernelBridge.boot(params.seed_val):
		status_label.text = "Kernel boot failed — check the browser console."
		return
	camera.limit_top = 0
	camera.limit_left = -2000000000
	camera.limit_right = 2000000000
	booted = true
	status_label.text = "Live."

func _make_node(script: GDScript) -> Node2D:
	var node := Node2D.new()
	node.set_script(script)
	return node

func _physics_process(delta: float) -> void:
	if not booted:
		return
	var mouse_world := camera.get_global_mouse_position()
	var command := GameInput.build(player_pos, mouse_world)
	var snap := KernelBridge.step_game(command, delta, false)
	if snap.is_empty():
		return
	_apply_snapshot(snap)

func _apply_snapshot(snap: Dictionary) -> void:
	var render: Dictionary = snap.get("render", {})
	if render.is_empty():
		return
	var w: Dictionary = render.get("world", {})
	if w.has("w"):
		world_w = float(w["w"])
	if w.has("h"):
		world_h = float(w["h"])
	camera.limit_bottom = int(world_h)
	world_background.set_world_size(world_w, world_h)

	var entities: Array = render.get("entities", [])
	var sim_t := float(render.get("t", 0.0))

	var player_entity: Dictionary = {}
	for e in entities:
		if e.get("kind") == "player":
			player_entity = e
			break
	if player_entity.is_empty():
		status_label.text = "Player not found — dead or not yet spawned."
	else:
		player_pos = Vector2(float(player_entity.get("x", 0.0)), float(player_entity.get("y", 0.0)))
		camera.position = player_pos
		camera.position.y += get_viewport_rect().size.y * (params.camera_y_bias - 0.5)

	var viewport_size := get_viewport_rect().size
	entity_pool.update(entities, sim_t, camera.position, viewport_size, world_w, CULL_PAD)
	if KernelBridge.is_bridge_available():
		# Debug hook for tools/verify_bridge.py's Phase 2 check: exposes the pooled (on-screen)
		# node count on `window` so Playwright can confirm EntityPool is genuinely
		# instantiating/tracking nodes, not silently stuck at zero. One-way push (Godot -> JS);
		# nothing reads this back into the game.
		JavaScriptBridge.eval("window.__eeGodotEntityCount = %d;" % entity_pool.count(), true)

	var cam_pos := camera.position
	var w_w := world_w
	var unwrap_and_cull := func(item: Dictionary):
		var raw_x := float(item.get("x", 0.0))
		var x := cam_pos.x + WorldWrap.dx_wrap(cam_pos.x, raw_x, w_w)
		var y := float(item.get("y", 0.0))
		var top_left := cam_pos - viewport_size * 0.5
		var local := Vector2(x, y) - top_left
		if local.x < -CULL_PAD or local.x > viewport_size.x + CULL_PAD or local.y < -CULL_PAD or local.y > viewport_size.y + CULL_PAD:
			return null
		return Vector2(x, y)

	field_pool.update(render.get("fields", []), unwrap_and_cull, func(node, item): node.update(item))
	hazard_pool.update(render.get("hazards", []), unwrap_and_cull, func(node, item): node.update(item))
	particle_pool.update(render.get("particles", []), unwrap_and_cull, func(node, item): node.update(item))

	status_label.text = "t = %.1fs  entities = %d" % [sim_t, entities.size()]
