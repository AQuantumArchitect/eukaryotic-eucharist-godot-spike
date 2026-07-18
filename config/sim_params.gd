extends Resource
class_name SimParams
## Every knob this spike exposes, in one Inspector-editable Resource instead of scattered
## literals. Edit config/sim_params.tres directly (no code change, no recompile/re-export needed
## in the editor) or swap in a different .tres to A/B a configuration.

## Seed passed to the kernel's createWorld({ seed }) on boot.
@export var seed_val: int = 1001

## How often (sim/real seconds — the poll itself drives the kernel forward by this much sim time)
## the view pulls a fresh snapshot from the bridge. Lower = smoother visuals, more eval() calls.
@export var poll_interval_s: float = 1.0

## GraphNode grid layout width, purely cosmetic.
@export var grid_columns: int = 8

## Vertical camera-follow bias for the game view: 0.5 = perfectly centered on the player, 0.53
## matches index.html's own `player.y - innerHeight*.53` framing (index.html:440) — a touch more
## world visible below the player than above.
@export var camera_y_bias: float = 0.53

## Every _physics_process frame must call K.step() (that's what advances the sim and applies the
## player's command — skipping it would make input feel broken), but NOT every frame needs to
## pull back the full getRenderProjection()/getHudProjection() JSON payload — that's what actually
## costs time (confirmed via tools/profile.sh: ~100ms/frame in the bridge eval+JSON round trip vs.
## ~5ms for everything Godot does locally with the result). render_fetch_stride=N means "step every
## frame, but only fetch+apply a fresh render/HUD snapshot every Nth frame" — 1 = fetch every frame
## (old behavior), higher = cheaper but the world visually updates less often between fetches.
@export var render_fetch_stride: int = 3
