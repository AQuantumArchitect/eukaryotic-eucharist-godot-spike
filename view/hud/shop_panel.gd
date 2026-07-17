extends Control
## Build/shop modal (Phase 4). Ports index.html's shared-filter-state design (BUILD_CATEGORIES/
## buildFilter, index.html:300-357): one build_filter/build_category state object drives the one
## card list this port has so far (no separate DAG-chip row yet — graph_view.tscn is still a
## separate, untouched debug scene) — structured the same way so a second surface could share this
## state later without a rewrite, per the original's own "ONE filter state... drive BOTH build
## surfaces" comment. Every card's single action is ShopLogic.primary_build()'s pick, routed
## through doBuy()'s own prefix rule (index.html:1334-1336).

const BUILD_CATEGORIES := [
	{"key": "feeding", "label": "Feeding & Intake"},
	{"key": "metabolism", "label": "Metabolism & Fuel"},
	{"key": "structure", "label": "Structure, Storage & Defense"},
	{"key": "oxygen", "label": "Oxygen & Buoyancy"},
	{"key": "movement", "label": "Movement"},
	{"key": "weapons", "label": "Weapons"},
	{"key": "swarm", "label": "Swarm & Colony"},
	{"key": "eucharist", "label": "Mitochondrial Eucharist"},
	{"key": "archive", "label": "Tier 3 — DNA Information"},
]

signal closed

@onready var title_label: Label = $Panel/VBox/Title
@onready var filter_row: HBoxContainer = $Panel/VBox/FilterRow
@onready var card_list: VBoxContainer = $Panel/VBox/Scroll/CardList
@onready var close_button: Button = $Panel/VBox/CloseButton
@onready var status_label: Label = $Panel/VBox/StatusLabel

var build_filter := {"affordable_only": false, "owned_only": false, "new_only": false}
var build_category := ""
var current_hud: Dictionary = {}
var current_source := "yuki"

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): close())
	_build_filter_row()

func _build_filter_row() -> void:
	for child in filter_row.get_children():
		child.queue_free()
	var affordable := CheckButton.new()
	affordable.text = "Affordable"
	affordable.toggled.connect(func(v): build_filter.affordable_only = v; refresh())
	filter_row.add_child(affordable)
	var owned := CheckButton.new()
	owned.text = "Owned"
	owned.toggled.connect(func(v): build_filter.owned_only = v; refresh())
	filter_row.add_child(owned)
	var new_only := CheckButton.new()
	new_only.text = "New"
	new_only.toggled.connect(func(v): build_filter.new_only = v; refresh())
	filter_row.add_child(new_only)
	var all_cat := Button.new()
	all_cat.text = "All"
	all_cat.pressed.connect(func(): build_category = ""; refresh())
	filter_row.add_child(all_cat)
	for cat in BUILD_CATEGORIES:
		var b := Button.new()
		b.text = cat.get("label")
		var key := String(cat.get("key"))
		b.pressed.connect(func(): build_category = key; refresh())
		filter_row.add_child(b)

func open_shop(source: String) -> void:
	current_source = source
	title_label.text = "The Horseshroomba" if source == "crab" else "Yuki"
	visible = true
	refresh()

func close() -> void:
	visible = false
	closed.emit()

func apply_hud(hud: Dictionary) -> void:
	current_hud = hud
	if visible:
		refresh()

func _owned_count(organelle_id: String) -> int:
	for o in current_hud.get("organelles", []):
		if o.get("id") == organelle_id:
			return int(o.get("count", 0))
	return 0

func refresh() -> void:
	for child in card_list.get_children():
		child.queue_free()
	var has_ribosome := false
	for o in current_hud.get("organelles", []):
		if o.get("id") == "organ_manufacturing":
			has_ribosome = true
			break
	var offerings: Array = KernelBridge.get_yuki_offerings(current_source)
	var shown := 0
	for o in offerings:
		var owned_count := _owned_count(String(o.get("organelle", "")))
		if build_category != "" and ShopLogic.category_of(o) != build_category:
			continue
		if build_filter.owned_only and owned_count <= 0:
			continue
		if build_filter.new_only and owned_count > 0:
			continue
		var state := ShopLogic.org_state(o)
		if build_filter.affordable_only and state != "ready":
			continue
		var route = ShopLogic.primary_build(o, has_ribosome, owned_count)
		card_list.add_child(_make_card(o, state, owned_count, route))
		shown += 1
	status_label.text = "%d offerings" % shown

func _make_card(o: Dictionary, state: String, owned_count: int, route) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	var name_text := String(o.get("name", o.get("id", "?")))
	label.text = "%s  [%s]  x%d" % [name_text, state, owned_count]
	label.custom_minimum_size = Vector2(420, 0)
	row.add_child(label)
	var btn := Button.new()
	if route != null:
		btn.text = String(route.get("label", "Build"))
		btn.disabled = false
		var action_id := String(route.get("id", ""))
		btn.pressed.connect(func(): _do_build(action_id))
	else:
		btn.text = "—"
		btn.disabled = true
	row.add_child(btn)
	return row

func _do_build(action_id: String) -> void:
	var result: Dictionary
	if action_id.begins_with("print_"):
		result = KernelBridge.start_manufacturing(action_id.substr(6))
	else:
		result = KernelBridge.buy_offering(action_id)
	status_label.text = String(result.get("reason", "Done.")) if not result.get("ok", false) else "Done."
	refresh()
