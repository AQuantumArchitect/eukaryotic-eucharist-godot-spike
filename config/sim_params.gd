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
