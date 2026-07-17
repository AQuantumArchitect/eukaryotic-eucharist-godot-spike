extends Node2D
## Simplified port of drawFields (index.html:1563-1628) — one flat colored circle per resource
## field instead of per-resType gradient/particle detail (biomass backing halo, lipid slick
## droplets, ATP sparkle dots, toxin ripple rings). Recognizable footprint + color + rough density
## via alpha; the decorative detail is Phase 5 polish.

const COLORS := {
	"biomass": "#5fd96b", "lipids": "#f0a63c", "energy": "#49b6ff",
	"toxins": "#e8e22c", "ballast": "#8a7a6b",
}

var data: Dictionary = {}

func update(f: Dictionary) -> void:
	data = f
	queue_redraw()

func _draw() -> void:
	var res_type := String(data.get("resType", ""))
	var stock: Dictionary = data.get("stock", {})
	var amt := float(stock.get(res_type, 0.0))
	if amt <= 0.05:
		return
	var r := float(data.get("radius", 20.0))
	var col := Color(COLORS.get(res_type, "#e8e22c"))
	col.a = clamp(amt / 70.0, 0.15, 0.5)
	draw_circle(Vector2.ZERO, r, col)
