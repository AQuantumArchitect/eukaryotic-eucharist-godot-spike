extends Node
## Thin JavaScriptBridge client. Owns zero simulation logic — every call below just asks the
## unmodified graph_kernel.mjs (loaded into `window.EE` by the custom Web export shell, see
## web_shell/head_include.html) to do the real work, and parses back a JSON string snapshot.
## Only meaningful in a Web export; JavaScriptBridge does not exist elsewhere.

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
	var result = JavaScriptBridge.eval(code, true)
	if typeof(result) != TYPE_STRING:
		push_error("KernelBridge: step eval returned non-string — check browser console for a JS exception.")
		return {}
	var json := JSON.new()
	var err := json.parse(result)
	if err != OK:
		push_error("KernelBridge: JSON parse failed: %s" % json.get_error_message())
		return {}
	return json.data
