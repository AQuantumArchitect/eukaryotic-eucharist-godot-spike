# Godot 4.5 hybrid-architecture spike

Proves out one architecture: Godot owns rendering/input and a native `GraphEdit` view of
low-frequency structural data; the existing JS ecology kernel
(`eukaryotic_eucharist_mobile_v1_3_3/src/graph_kernel.mjs`, in the sibling `eukarayotic_eucharist`
repo) keeps doing 100% of the high-volume per-tick math, completely unmodified. Zero kernel logic
is reimplemented in GDScript.

## Layout

Four concerns, four folders — separated so each can be looked at, tested, and edited on its own:

```
config/   tunable parameters (edit the .tres, no code change)
bridge/   GDScript <-> JS wiring, owns zero simulation logic
view/     the GraphEdit visualization, owns zero bridge/wiring logic
tools/    build + regression-test scripts, owns zero engine logic
```

- **`config/sim_params.gd` + `config/sim_params.tres`** — every knob this spike exposes
  (`seed_val`, `poll_interval_s`, `grid_columns`) lives in one Inspector-editable `Resource`
  instead of scattered literals. Retune by editing the `.tres` directly, or point
  `graph_view.gd`/`kernel_bridge.gd` at a different `.tres` to A/B a configuration — no recompile,
  no re-export required to see the values in the editor Inspector.
- **`bridge/kernel_bridge.gd`** (autoload) — the only file that calls `JavaScriptBridge.eval()`.
  Boots the kernel with `createWorld({ seed })` and returns a JSON snapshot each poll.
  `bridge/web_shell/head_include.html` is the matching source-of-truth copy of the script tag
  baked into `export_presets.cfg`'s `html/head_include`, which imports the kernel as a genuine ES
  module into the page and exposes it as `window.EE`.
- **`view/graph_view.gd` + `view/graph_view.tscn`** — builds one `GraphNode` per id appearing in
  the kernel's own `ORGAN_GRAPH_ROLE` / `ORGAN_GRAPH_EDGES` ("DAG HUD") data, and recolors/labels
  them each poll from the live `getHudProjection()` read — owned organelles bright with their
  count, unowned ones dimmed. It only ever reads the bridge's JSON contract; it never calls
  `JavaScriptBridge` directly.
- **`tools/`** — `build_web.sh` (export + copy in the real kernel), `test.sh` (one-command
  export/serve/verify/teardown loop), `verify_bridge.py` (the actual regression check).

## The hook point: one stable JSON contract

`KernelBridge.step_and_snapshot()` always returns the same shape:
```
{ edges: [[from, to], ...], roles: { id: role }, t: <sim seconds>, hud: { organelles, resources } }
```
This is the deliberate integration seam, not an implementation detail. Anything that needs to
observe or drive this world — a second `GraphNode` view over a different subsystem, an external
learning-model harness (e.g. something modeling membrane transport), a headless test/product bot —
reads or writes through this same JSON contract and the same `window.EE` surface, instead of
reaching into GDScript or kernel internals. Extend it by adding keys, not by changing existing
ones, so nothing hooked into it silently breaks.

## Build + run

```
./tools/build_web.sh                              # exports to dist_web/, copies in the real kernel
python3 -m http.server 8788 --directory dist_web   # serve it
```
Open `http://localhost:8788/index.html` in a browser.

## Iterate: `./tools/test.sh`

One command — export, serve, headless-verify the bridge is genuinely live, tear down:
```
./tools/test.sh
```
Run this after touching `bridge/kernel_bridge.gd`, `view/graph_view.gd`,
`config/sim_params.tres`, `export_presets.cfg`, or the game's own `graph_kernel.mjs`. It's the
regression check for the *bridge* specifically — kernel logic still gets its own coverage from
the existing `smoke_test.mjs`/`burnin.mjs` headless harness in the game repo, untouched by any of
this. `verify_bridge.py` (Playwright) asks `window.__eeWorld.t` whether sim time genuinely
advances between two reads apart — a frozen/broken bridge shows `t1 == t2`; a real one doesn't.
Caught a real, transient issue on first use: the shared kernel was mid-edit by the other
collaborator (a twilight-grazer maturation refactor) when the export copied it, producing one
broken build that self-resolved on the next run — exactly the kind of break this check exists to
catch, not something to "fix" here.

### For an external test/product bot

`./tools/test.sh --json` (or `python3 tools/verify_bridge.py <url> --json` against an
already-served build) prints every human-readable line to stderr and exactly one JSON object to
stdout — `{ok, t1, t2, ee_present, world_present, edges_len, console_errors, screenshot}` — so a
bot can pipe stdout straight into a parser instead of scraping text. `--boot-wait`/`--settle-wait`
override the default 20s/5s timing if a bot's environment is slower or needs a tighter loop.

Override `PORT`, `PYTHON_BIN`, or `SPIKE_CHROME_PATH` as env vars if the defaults (port 8788, the
`torch118` venv's Python, a specific cached Chromium build) don't match your machine.

## Explicitly out of scope here

- Native desktop/mobile export (`JavaScriptBridge` is Web-only; native needs a GDExtension-embedded
  JS engine — `godot-quickjs` or `GodotJS` are the two real existing options to evaluate next).
- Any UI/rendering migration beyond this one DAG-HUD proof slice.
- A general-purpose GraphEdit *authoring* tool (this is a read-only live view).
- A generic multi-project test framework. `tools/verify_bridge.py --json` is this project's own
  bot-facing contract; it deliberately isn't an attempt to unify testing across every parallel
  project — that's a bigger, separate decision, not a byproduct of this reorg.
