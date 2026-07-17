# Godot 4.5 port of Eukaryotic Eucharist

Started as a hybrid-architecture spike proving Godot could own rendering/input against the
existing JS ecology kernel; now an active, phased port of the real playable game onto that same
architecture. The kernel (`eukaryotic_eucharist_mobile_v1_3_3/src/graph_kernel.mjs`, in the
sibling `eukarayotic_eucharist` repo) keeps doing 100% of the high-volume per-tick math,
completely unmodified — Godot only ever calls it through `bridge/kernel_bridge.gd`. Zero kernel
logic is reimplemented in GDScript.

`run/main_scene` is `view/game_view.tscn` — the actual playable game view — not the DAG graph view
(`view/graph_view.tscn`, kept as a secondary/debug scene). The port is being built in five
ordered, independently-verified phases (see `tools/test.sh`'s growing assertion list): (0) a real
per-frame command channel into the kernel's actual `step()` — done; (1) minimal playable loop,
player moves and renders under a following camera — done; (2) full entity/field/hazard/particle
rendering; (3) full HUD; (4) build/shop economy; (5) visual polish/parity. Phases 2-5 are not yet
built — right now the player renders as a plain circle and no other entities/fields/HUD exist yet.

## Layout

Four concerns, four folders — separated so each can be looked at, tested, and edited on its own:

```
config/   tunable parameters (edit the .tres, no code change)
bridge/   GDScript <-> JS wiring, owns zero simulation logic
view/     game rendering + input + the GraphEdit debug view, owns zero bridge/wiring logic
tools/    build + regression-test scripts, owns zero engine logic
```

- **`config/sim_params.gd` + `config/sim_params.tres`** — every knob this project exposes
  (`seed_val`, `poll_interval_s`, `grid_columns`, `camera_y_bias`) lives in one Inspector-editable
  `Resource` instead of scattered literals. Retune by editing the `.tres` directly, or point a view
  script at a different `.tres` to A/B a configuration — no recompile, no re-export required to
  see the values in the editor Inspector.
- **`bridge/kernel_bridge.gd`** (autoload) — the only file that calls `JavaScriptBridge.eval()`.
  `boot()` calls `createWorld({ seed })`; `step_and_snapshot()` advances ecology-only (no player
  command) for the DAG debug view; **`step_game(command, dt, sheltered)`** drives the REAL game
  step (`K.step`, movement/combat/economy) and returns `{render: getRenderProjection(), hud:
  getHudProjection(), t}` — this is what `game_view.gd` calls every physics frame. Thin one-eval
  wrappers (`buy_offering`, `remove_organelle`, `trade_at_yuki`, `start_manufacturing`,
  `kill_player`, `get_yuki_offerings`, `get_yuki_trades`) cover the discrete, non-per-frame actions
  (Phase 4 will wire these to an actual shop UI). `bridge/web_shell/head_include.html` is the
  matching source-of-truth copy of the script tag baked into `export_presets.cfg`'s
  `html/head_include`, which imports the kernel as a genuine ES module and exposes it as
  `window.EE`.
- **`view/game_view.gd` + `view/game_view.tscn`** — the real game view (`run/main_scene`). A
  `Camera2D` follows the player (`camera_y_bias`-offset, clamped vertically via
  `limit_top`/`limit_bottom` to mirror index.html's own player-follow clamp; horizontal is
  unclamped since the world wraps). `view/game_input.gd` (`GameInput.build()`) reads raw keycodes
  (WASD/arrows + the same action keys as index.html: F/Q/Shift/R/X/C/Z/V/G/B/H/T/J/M/U) plus the
  mouse for aim/fire and produces the exact command Dictionary shape `K.step()` expects.
  `view/world_wrap.gd` (`WorldWrap`) ports index.html's `wrapX`/`dxWrap` toroidal-world coordinate
  math verbatim — the kernel doesn't export it, so it's the one accepted exception to "the kernel
  is the only source of truth." `view/player_dot.gd` is a Phase-1 placeholder (one flat circle);
  Phase 2 replaces it with real body-plan-dispatched entities.
- **`view/graph_view.gd` + `view/graph_view.tscn`** — the original DAG debug view. Builds one
  `GraphNode` per id appearing in the kernel's own `ORGAN_GRAPH_ROLE` / `ORGAN_GRAPH_EDGES` data,
  recolored/labeled each poll from `getHudProjection()`. Left untouched, no longer the default
  scene, still useful for inspecting organelle-graph state independent of the game view.
- **`tools/`** — `build_web.sh` (export + copy in the real kernel), `test.sh` (one-command
  export/serve/verify/teardown loop), `verify_bridge.py` (the regression check, growing one
  assertion per phase), `deploy_pages.sh` (push `dist_web/` to GitHub Pages).

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

## Play it now (deployed)

**https://aquantumarchitect.github.io/eukaryotic-eucharist-godot-spike/**

Deployed via GitHub Pages, serving the `gh-pages` branch (source lives on `master`; `gh-pages` holds
only the built `dist_web/` output, force-pushed each deploy — same split as the `.gitignore`'d
`dist_web/` locally). Redeploy after any change with:
```
./tools/deploy_pages.sh
```

## Iterate: `./tools/test.sh`

One command — export, serve, headless-verify the bridge is genuinely live, tear down:
```
./tools/test.sh
```
Run this after touching anything under `bridge/`, `view/`, `config/sim_params.tres`,
`export_presets.cfg`, or the game's own `graph_kernel.mjs`. It's the regression check for the
*bridge and game view*, not gameplay balance — kernel logic still gets its own coverage from the
existing `smoke_test.mjs`/`burnin.mjs` headless harness in the game repo, untouched by any of this.
`verify_bridge.py` (Playwright) grows one assertion per port phase, never removing an earlier one:
- `t2 > t1` — sim time genuinely advances between two reads of `window.__eeWorld.t`; a
  frozen/broken bridge shows `t1 == t2`.
- (Phase 0) drives `window.EE.step()` directly with a synthetic `moveX:1` command and asserts the
  player entity's `x` actually changes — proves the real game-step channel (not just
  `stepEcology`) is reachable at all.
- (Phase 1) dispatches a REAL keyboard `d` hold at the Godot canvas (`page.keyboard.down`) and
  asserts the player's `vx` ends up clearly positive — proves input genuinely reaches
  `GameInput` -> `KernelBridge.step_game()` -> `K.step()` through the running `game_view.tscn`
  scene, not a JS side-channel. (Movement ramps up over `MOTOR_RAMP_TIME`, so this checks final
  velocity rather than a short before/after position delta, which can land on a momentum
  transient.)

Caught a real, transient issue on first use (pre-port): the shared kernel was mid-edit by the
other collaborator (a twilight-grazer maturation refactor) when the export copied it, producing
one broken build that self-resolved on the next run — exactly the kind of break this check exists
to catch, not something to "fix" here.

### For an external test/product bot

`./tools/test.sh --json` (or `python3 tools/verify_bridge.py <url> --json` against an
already-served build) prints every human-readable line to stderr and exactly one JSON object to
stdout — `{ok, t1, t2, ee_present, world_present, edges_len, player_x1, player_x2, player_moved,
player_x3, player_x4, player_vx, input_moved_player, console_errors, screenshot}` — so a bot can
pipe stdout straight into a parser instead of scraping text. `--boot-wait`/`--settle-wait` override
the default 20s/5s timing if a bot's environment is slower or needs a tighter loop.

Override `PORT`, `PYTHON_BIN`, or `SPIKE_CHROME_PATH` as env vars if the defaults (port 8788, the
`torch118` venv's Python, a specific cached Chromium build) don't match your machine.

## Explicitly out of scope here

- Native desktop/mobile export (`JavaScriptBridge` is Web-only; native needs a GDExtension-embedded
  JS engine — `godot-quickjs` or `GodotJS` are the two real existing options to evaluate next).
- Audio (index.html itself has none).
- True multi-touch / on-screen joystick+button parity — keyboard+mouse only through the planned
  Phase 4; touch is an optional future phase, not part of the current port plan.
- Pixel-perfect visual parity with index.html's canvas rendering — the goal is recognizable and
  playable, not a faithful clone of every gradient/bezier curve.
- A general-purpose GraphEdit *authoring* tool for `graph_view.tscn` (it's a read-only live view).
- A generic multi-project test framework. `tools/verify_bridge.py --json` is this project's own
  bot-facing contract; it deliberately isn't an attempt to unify testing across every parallel
  project — that's a bigger, separate decision, not a byproduct of this port.
