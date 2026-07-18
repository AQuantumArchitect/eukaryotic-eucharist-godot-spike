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
rendering — done; (3) full HUD, read-only — done; (4) build/shop economy — done; (5) visual
polish/parity — done as a LIGHT pass (blob wobble + a simplified depth/oxygen vignette only; see
"Explicitly out of scope" below for what's still deliberately not ported). All five phases are now
built; rendering stays recognizable-but-simplified rather than pixel-parity with index.html.

**`tools/build_web.sh` note:** the JS kernel repo split `graph_kernel.mjs` into a barrel file
(`export * from './simCore.mjs'` etc.) partway through this port — `build_web.sh` now copies every
`.mjs` file in the kernel's `src/` directory, not just the entry point, so this build survives
further splits there without needing an edit here each time.

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
  is the only source of truth." `view/world_background.gd` is a flat-fill stand-in for
  `drawWorld`'s gradient/canopy/floor (full detail is Phase 5 polish), drawn 3x world-width wide so
  the camera never sees void at the wrap seam.
- **`view/entity_pool.gd` + `view/entities/`** — every entity in `getRenderProjection().entities`
  gets a pooled Godot node, diffed against the kernel's own array each frame (new ids spawn, gone
  ids free) and positioned via `WorldWrap`'s nearest-copy unwrap — cheaper than index.html's
  brute-force 3x world redraw (index.html:1507) since Godot holds persistent nodes rather than
  redrawing immediate-mode every frame; ghost-duplication exactly at the seam stays undone (light
  Phase 5 didn't reach it — see "Explicitly out of scope"). `view/entities/body_factory.gd`
  dispatches on `bodyPlan` (`body_blob/spiny/jelly/ciliate/maw/amoeba/colonial/brood.gd`) or
  `controller==='shroomba'` (`body_crab.gd`), one script per plan porting the matching
  `index.html` draw function (`:1887-1944`, `:1705-1731`). `body_blob.gd` — the default plan, used
  by the player and most unclassified NPCs — got the one animation light Phase 5 spent its budget
  on: per-vertex sine wobble + speed-based stretch/shrink, same formula as the original
  (index.html:1898). Every other plan stays a static silhouette; their own wobble/pulse/beat-cycle
  juice, plus internal-organelle "confetti" and appendage rendering, are still cosmetic and still
  deferred. `view/entities/body_colors.gd` ports the hit-flash/duress-tint color math (`bodyFill`/
  `bodyStroke`, index.html:1851-1875) — this was already live before Phase 5, not new.
- **`view/effects/`** (`field_view.gd`, `hazard_view.gd`, `particle_view.gd`) + `view/node_pool.gd`
  — simplified flat-circle ports of `drawFields`/`drawHazards`/`drawParticles`
  (index.html:1563-1671): recognizable footprint/color/fade, not the full per-resource-type
  gradient/glyph detail (Phase 5 polish). `NodePool` is the generic version of the same
  diff-and-pool pattern `EntityPool` uses, shared across all three effect layers.
- **`view/hud/`** (`hud_root.tscn`/`.gd`, `vitals_panel.gd`, `controls_legend.gd`, `toast.gd`,
  `vignette.gd`) — read-only HUD chrome, instanced into `game_view.tscn`. All driven off the exact
  same `hud`/`render` data `step_game()` already returns each frame — no new bridge calls.
  `vitals_panel.gd` is a plain-text port of index.html's `.vital` bars (HP/O2/depth/pressure/every
  `hud.resources[]` entry); `controls_legend.gd` ports `updateControls()`'s key -> action rows
  (index.html:1233), filtered by whether `hud.actions[]` actually has that action; `toast.gd` scans
  `render.events` for one-shot notices, same array `checkDeathEvent()` reads, no pub/sub.
  `vignette.gd` (light Phase 5) is a simplified stand-in for `drawVignette` (index.html:1960): a
  flat full-screen dark tint scaled by depth/oxygen danger, not a true radial gradient centered on
  the player (Godot has no built-in radial-fill primitive without a shader) — still reads as
  "getting dangerous," just not radial.
- **`view/hud/shop_panel.gd`/`.tscn` + `shop_logic.gd`** — the build/shop modal, toggled by `E`
  when `hud.nearYuki`/`hud.nearCrab` (`game_view.gd`'s `_unhandled_input`), `Escape` to close.
  `ShopLogic` ports `organState()`/`buildRoutes()`/`primaryBuild()`/`buildCategoryOf()`
  (index.html:329-334, :1373-1399) as pure functions over `KernelBridge.get_yuki_offerings()`'s
  fields — UI decision logic, not simulation, so porting it doesn't compromise "the kernel is the
  only source of truth." `shop_panel.gd` keeps index.html's shared-filter-state design
  (`BUILD_CATEGORIES`/`buildFilter`, index.html:300-357) as its own `build_filter`/
  `build_category` state — this port has only one build surface so far (no separate DAG-chip row),
  but the state is structured the same way so a second surface could share it later without a
  rewrite. Each card's action routes through `doBuy()`'s own prefix rule (index.html:1334-1336): a
  `"print_"` route id calls `KernelBridge.start_manufacturing()`, everything else calls
  `KernelBridge.buy_offering()`. While the panel is open, `game_view.gd` passes `sheltered=true` to
  `step_game()` — mirroring index.html's own `sheltered` flag (index.html:435): world time and
  passive regen (`yukiRestore`) keep running, only player-command application pauses.
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
- (Phase 2) asserts `getRenderProjection().entities.length > 1` (NPCs exist, not just the player)
  and that a debug counter `game_view.gd` pushes to `window.__eeGodotEntityCount` via
  `JavaScriptBridge.eval` is nonzero and never exceeds the kernel's own entity count — proves
  `EntityPool` is genuinely instantiating/tracking on-screen nodes. Not an exact-equality check:
  `EntityPool` deliberately culls off-screen entities (mirroring index.html's own `onScreen`
  culling, index.html:1505), so the pooled count is normally well below the kernel's true count.
- (Phase 3) asserts `window.__eeGodotHudHp` (another debug push, this one of the exact `hud.hp`
  Dictionary `game_view.gd` hands to `vitals_panel.gd` every frame) is within a small tolerance of
  a fresh `window.EE.getHudProjection(w).hp` read — proves the read-only HUD genuinely reflects
  live kernel state rather than stale or fabricated numbers. The tolerance (not exact equality)
  covers the one-tick drift between the two reads, since HP can regen/drain between them.
- (Phase 4) drives `window.EE.buyOffering()` directly on the first currently-affordable bare-graft
  offering and asserts it returns `ok:true` with the organelle's owned count actually incremented —
  `KernelBridge.buy_offering()` is a thin 1:1 relay over this exact call, so this proves the
  discrete-action channel works, the same scope Phase 0 proved for the per-frame command channel.
  Doesn't drive `shop_panel.gd`'s own UI click (that needs the player standing near Yuki, not
  guaranteed at this fixed seed/tick) — `ShopLogic`'s filter/routing logic is a pure port exercised
  by reading, not a live click here; an honest scope limit, not a gap papered over.

Caught a real, transient issue on first use (pre-port): the shared kernel was mid-edit by the
other collaborator (a twilight-grazer maturation refactor) when the export copied it, producing
one broken build that self-resolved on the next run — exactly the kind of break this check exists
to catch, not something to "fix" here.

### For an external test/product bot

`./tools/test.sh --json` (or `python3 tools/verify_bridge.py <url> --json` against an
already-served build) prints every human-readable line to stderr and exactly one JSON object to
stdout — `{ok, t1, t2, ee_present, world_present, edges_len, player_x1, player_x2, player_moved,
player_x3, player_x4, player_vx, input_moved_player, kernel_entities_len, godot_entity_count,
entities_pooled_sane, godot_hud_hp, kernel_hud_hp, hud_reflects_kernel, buy_result, build_worked,
console_errors, screenshot}` — so a bot can pipe stdout straight into a parser instead of scraping
text. `--boot-wait`/`--settle-wait` override the default 20s/5s timing if a bot's environment is
slower or needs a tighter loop.

Override `PORT`, `PYTHON_BIN`, or `SPIKE_CHROME_PATH` as env vars if the defaults (port 8788, the
`torch118` venv's Python, a specific cached Chromium build) don't match your machine.

## Explicitly out of scope here

- Native desktop/mobile export (`JavaScriptBridge` is Web-only; native needs a GDExtension-embedded
  JS engine — `godot-quickjs` or `GodotJS` are the two real existing options to evaluate next).
- Audio (index.html itself has none).
- True multi-touch / on-screen joystick+button parity — keyboard+mouse only.
- Pixel-perfect visual parity with index.html's canvas rendering — the goal is recognizable and
  playable, not a faithful clone of every gradient/bezier curve. Phase 5 landed as a LIGHT pass
  (blob wobble + a flat-tint vignette) and stopped there; still not done, on purpose: every other
  body plan's own wobble/pulse/beat-cycle animation, internal-organelle "confetti" and external
  appendage rendering (~60 organelle-specific draw branches, decorative not gameplay), the full
  per-resource-type field/hazard/particle gradient and glyph detail, a true radial vignette, and
  ghost-entity duplication exactly at the world's wrap seam. None of this is gameplay-relevant —
  revisit only if it's ever actually worth the time against other priorities.
- A general-purpose GraphEdit *authoring* tool for `graph_view.tscn` (it's a read-only live view).
- A generic multi-project test framework. `tools/verify_bridge.py --json` is this project's own
  bot-facing contract; it deliberately isn't an attempt to unify testing across every parallel
  project — that's a bigger, separate decision, not a byproduct of this port.
