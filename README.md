# Godot 4.5 hybrid-architecture spike

Proves out one architecture: Godot owns rendering/input and a native `GraphEdit` view of
low-frequency structural data; the existing JS ecology kernel
(`eukaryotic_eucharist_mobile_v1_3_3/src/graph_kernel.mjs`, in the sibling `eukarayotic_eucharist`
repo) keeps doing 100% of the high-volume per-tick math, completely unmodified. Zero kernel logic
is reimplemented in GDScript.

Bridge: Godot's `JavaScriptBridge` singleton (Web export only) — the kernel runs as a genuine ES
module in the same browser JS context Godot's canvas runs in. `head_include.html` (baked into
`export_presets.cfg`'s `html/head_include`) imports it and exposes `window.EE`; `kernel_bridge.gd`
drives it via `JavaScriptBridge.eval()`, always returning a JSON string snapshot back to GDScript.

`graph_view.gd` builds one `GraphNode` per id appearing in the kernel's own `ORGAN_GRAPH_ROLE` /
`ORGAN_GRAPH_EDGES` ("DAG HUD") data, and recolors/labels them each poll from the live
`getHudProjection()` read — owned organelles bright with their count, unowned ones dimmed.

## Build + run

```
./build_web.sh                                    # exports to dist_web/, copies in the real kernel
python3 -m http.server 8788 --directory dist_web   # serve it
```
Open `http://localhost:8788/index.html` in a browser.

## Verified

`t at claude_verify_spike.py` — a Playwright headless-Chromium run confirms `window.__eeWorld.t`
genuinely advances between reads (the kernel is really ticking, not a static snapshot), and a
screenshot shows the `GraphEdit` correctly distinguishing owned vs. unowned organelles with live
counts.

## Explicitly out of scope here

- Native desktop/mobile export (`JavaScriptBridge` is Web-only; native needs a GDExtension-embedded
  JS engine — `godot-quickjs` or `GodotJS` are the two real existing options to evaluate next).
- Any UI/rendering migration beyond this one DAG-HUD proof slice.
- A general-purpose GraphEdit *authoring* tool (this is a read-only live view).
