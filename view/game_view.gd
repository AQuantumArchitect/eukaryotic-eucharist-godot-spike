extends Node2D
## Minimal playable loop (Phase 1 of the game-view port): boots the kernel via KernelBridge,
## drives the REAL game step (KernelBridge.step_game, not stepEcology) every physics frame with
## input from GameInput, and renders the player as a plain circle under a player-following
## Camera2D. No body-plan dispatch or entity pooling yet — that's Phase 2. Every tunable is read
## from config/sim_params.tres (a SimParams Resource) instead of a literal in this script.

@onready var camera: Camera2D = $MainCamera
@onready var status_label: Label = $HudLayer/StatusLabel
@onready var player_dot: Node2D = $PlayerDot

var params: SimParams = load("res://config/sim_params.tres")
var world_w := 2240.0
var world_h := 7840.0
var booted := false

func _ready() -> void:
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

func _physics_process(delta: float) -> void:
	if not booted:
		return
	var mouse_world := camera.get_global_mouse_position()
	var command := GameInput.build(player_dot.position, mouse_world)
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

	var player_entity: Dictionary = {}
	for e in render.get("entities", []):
		if e.get("kind") == "player":
			player_entity = e
			break
	if player_entity.is_empty():
		status_label.text = "Player not found — dead or not yet spawned."
		return

	player_dot.position = Vector2(float(player_entity.get("x", 0.0)), float(player_entity.get("y", 0.0)))
	player_dot.queue_redraw()
	camera.position = player_dot.position
	camera.position.y += get_viewport_rect().size.y * (params.camera_y_bias - 0.5)

	status_label.text = "t = %.1fs  entities = %d" % [float(snap.get("t", 0.0)), render.get("entities", []).size()]
