class_name BodyFactory
extends RefCounted
## One script per body plan (index.html's drawBody dispatch, :1876-1885) plus the
## controller==='shroomba' special case (:1734) and a generic fallback. Plain scripts attached to
## a bare Node2D rather than wrapped in near-empty .tscn files — none of these need child nodes,
## just a _draw() override, so a script IS the whole scene here.

const SCRIPTS := {
	"spiny": "res://view/entities/body_spiny.gd",
	"radial": "res://view/entities/body_spiny.gd",
	"jelly": "res://view/entities/body_jelly.gd",
	"ciliate": "res://view/entities/body_ciliate.gd",
	"maw": "res://view/entities/body_maw.gd",
	"amoeba": "res://view/entities/body_amoeba.gd",
	"colonial": "res://view/entities/body_colonial.gd",
	"brood": "res://view/entities/body_brood.gd",
}
const BLOB_SCRIPT := preload("res://view/entities/body_blob.gd")
const CRAB_SCRIPT := preload("res://view/entities/body_crab.gd")
const GENERIC_SCRIPT := preload("res://view/entities/body_generic.gd")

static func node_for(e: Dictionary) -> Node2D:
	var script: GDScript
	if e.get("controller") == "shroomba":
		script = CRAB_SCRIPT
	elif e.get("kind") == "colony_segment" or e.get("kind") == "orbital_spore":
		script = GENERIC_SCRIPT
	else:
		var plan = e.get("bodyPlan")
		script = load(SCRIPTS[plan]) if SCRIPTS.has(plan) else BLOB_SCRIPT
	var node := Node2D.new()
	node.set_script(script)
	return node
