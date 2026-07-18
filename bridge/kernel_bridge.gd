extends Node
## Thin JavaScriptBridge client. Owns zero simulation logic — every call below just asks the
## unmodified graph_kernel.mjs (loaded into `window.EE` by the custom Web export shell, see
## bridge/web_shell/head_include.html) to do the real work, and parses back a JSON string snapshot.
## Only meaningful in a Web export; JavaScriptBridge does not exist elsewhere.
##
## step_and_snapshot()'s {edges, roles, t, hud} shape is the deliberate integration seam: any
## other GraphNode view, headless test bot, or future learning-model harness reads/writes state
## through this exact JSON contract and the same window.EE surface — not through GDScript
## internals. Keep this contract stable; extend it by adding keys, not by changing existing ones.

var booted := false

func is_bridge_available() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

func boot(seed_val: int) -> bool:
	if not is_bridge_available():
		push_warning("KernelBridge: JavaScriptBridge only exists in a Web export — run the exported build in a browser, not the editor.")
		return false
	var code := "window.__eeWorld = window.EE.createWorld({ seed: %d }); 'ok';" % seed_val
	var result = JavaScriptBridge.eval(code, true)
	booted = (result == "ok")
	if not booted:
		push_error("KernelBridge: boot failed, window.EE not ready or createWorld threw.")
	return booted

## Runs `code` (a JS expression producing a JSON string) through JavaScriptBridge.eval and parses
## the result. Every other method in this file is a thin wrapper around this — the one place that
## actually talks to window.EE. Returns null on any eval/parse failure (logged via push_error).
func _eval_json(code: String):
	var result = JavaScriptBridge.eval(code, true)
	if typeof(result) != TYPE_STRING:
		push_error("KernelBridge: eval returned non-string — check browser console for a JS exception.")
		return null
	var json := JSON.new()
	var err := json.parse(result)
	if err != OK:
		push_error("KernelBridge: JSON parse failed: %s" % json.get_error_message())
		return null
	return json.data

## Advances the real kernel by sim_seconds (in the kernel's own fixed 1/60 steps) and returns a
## snapshot: static DAG topology (fetched every call — cheap, small) plus the live HUD projection
## the organelle graph nodes will highlight from. Kernel math happens entirely inside this one
## eval — GDScript never touches per-tick ecology state.
func step_and_snapshot(sim_seconds: float) -> Dictionary:
	if not booted:
		return {}
	var code := """
	(function() {
		var w = window.__eeWorld;
		var dt = 1/60;
		var steps = Math.max(1, Math.round(%f / dt));
		for (var i = 0; i < steps; i++) { window.EE.stepEcology(w, dt); }
		var hud = window.EE.getHudProjection(w);
		return JSON.stringify({
			edges: window.EE.ORGAN_GRAPH_EDGES,
			roles: window.EE.ORGAN_GRAPH_ROLE,
			t: w.t,
			hud: hud
		});
	})()
	""" % sim_seconds
	var data = _eval_json(code)
	return data if data is Dictionary else {}

## Advances the REAL game — player movement/combat/economy, not just ecology — by one command.
## `command` must be a Dictionary shaped like index.html's command() (moveX, moveY, feed, repair,
## rasp, dash, acid, sporeshot, harpoon, cloud, mark, engulf, ward, jettison, flame, divide,
## compact, aimX, aimY) — the game view builds this every physics frame and hands it straight to
## K.step() unmodified. Returns {render: getRenderProjection(), hud: getHudProjection(), t}.
## Call once per physics frame; do not throttle by SimParams.poll_interval_s (that field is
## graph_view.gd's own knob, unrelated to this per-frame gameplay channel).
func step_game(command: Dictionary, dt: float, sheltered: bool = false) -> Dictionary:
	if not booted:
		return {}
	var code := """
	(function() {
		var w = window.__eeWorld;
		var cmd = %s;
		window.EE.step(w, cmd, %f, %s);
		return JSON.stringify({
			render: window.EE.getRenderProjection(w),
			hud: window.EE.getHudProjection(w),
			t: w.t
		});
	})()
	""" % [JSON.stringify(command), dt, ("true" if sheltered else "false")]
	var data = _eval_json(code)
	return data if data is Dictionary else {}

## Same real K.step() as step_game — command still applies, sim time still advances by dt — but
## returns just {t} instead of the full render+HUD projection. Exists purely for cost: profiling
## (tools/profile.sh) showed the getRenderProjection/getHudProjection JSON.stringify + GDScript
## JSON.parse round trip is ~20x the cost of everything Godot does locally with the result, so
## game_view.gd calls this on the frames it doesn't need a fresh visual snapshot
## (SimParams.render_fetch_stride), and step_game only on the frames it does. Sim correctness is
## unaffected either way — the kernel step happens every physics frame regardless of which
## wrapper is called.
func step_light(command: Dictionary, dt: float, sheltered: bool = false) -> float:
	if not booted:
		return 0.0
	var code := """
	(function() {
		var w = window.__eeWorld;
		window.EE.step(w, %s, %f, %s);
		return String(w.t);
	})()
	""" % [JSON.stringify(command), dt, ("true" if sheltered else "false")]
	var result = JavaScriptBridge.eval(code, true)
	return float(result) if typeof(result) in [TYPE_STRING, TYPE_FLOAT, TYPE_INT] else 0.0

## Discrete (non-per-frame) action wrappers. Each is a single eval that just relays the kernel's
## own {ok, reason, ...} result straight back — no interpretation, no branching, so this file stays
## zero-sim-logic. All default to acting on the current player (world.playerId), matching every one
## of these kernel exports' own default entityId argument.
func buy_offering(offering_id: String) -> Dictionary:
	var data = _eval_json("JSON.stringify(window.EE.buyOffering(window.__eeWorld, %s))" % JSON.stringify(offering_id))
	return data if data is Dictionary else {"ok": false, "reason": "bridge error"}

func remove_organelle(org_id: String) -> Dictionary:
	var data = _eval_json("JSON.stringify(window.EE.removeOrganelle(window.__eeWorld, %s))" % JSON.stringify(org_id))
	return data if data is Dictionary else {"ok": false, "reason": "bridge error"}

func trade_at_yuki(res: String, dir: String) -> Dictionary:
	var data = _eval_json("JSON.stringify(window.EE.tradeAtYuki(window.__eeWorld, %s, %s))" % [JSON.stringify(res), JSON.stringify(dir)])
	return data if data is Dictionary else {"ok": false, "reason": "bridge error"}

func start_manufacturing(offering_id: String) -> Dictionary:
	var data = _eval_json("JSON.stringify(window.EE.startManufacturing(window.__eeWorld, %s))" % JSON.stringify(offering_id))
	return data if data is Dictionary else {"ok": false, "reason": "bridge error"}

func kill_player() -> Dictionary:
	var data = _eval_json("JSON.stringify(window.EE.killPlayer(window.__eeWorld))")
	return data if data is Dictionary else {"ok": false, "reason": "bridge error"}

func get_yuki_offerings(source: String = "yuki") -> Array:
	var data = _eval_json("JSON.stringify(window.EE.getYukiOfferings(window.__eeWorld, window.__eeWorld.playerId, %s))" % JSON.stringify(source))
	return data if data is Array else []

func get_yuki_trades() -> Array:
	var data = _eval_json("JSON.stringify(window.EE.getYukiTrades(window.__eeWorld))")
	return data if data is Array else []
