extends CanvasLayer
## Read-only HUD chrome (Phase 3): vitals, keybind legend, toast — all driven by the same
## `hud`/`render` data step_game() already returns, no new bridge calls. No build/shop UI yet
## (Phase 4 adds that as its own panel, wired to KernelBridge's discrete action wrappers).

@onready var vitals = $Vitals
@onready var controls = $Controls
@onready var toast = $Toast
@onready var vignette = $Vignette

func apply(hud: Dictionary, render: Dictionary, delta: float) -> void:
	vitals.apply(hud)
	controls.apply(hud)
	toast.apply(render.get("events", []), delta)
	vignette.apply(hud)
