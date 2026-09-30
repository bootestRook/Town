extends Control
signal activation_requested(command: Dictionary)
signal closed
const ROW = preload("res://scenes/town/region_row.tscn")
const DROP = preload("res://scenes/town/region_drop.tscn")
var area := ""
var gates := {}
var stages: Array = []
var members: Array = []
var monsters := {}
var items := {}
var _catalog
var _state := {}
var _key := ""
var _dragging := false
var _moved := false
var _drag_start := Vector2.ZERO
var _scroll_start := 0

func _ready() -> void:
	$Dismiss.pressed.connect(close)
	$Stage/Help.pressed.connect(func(): $Stage/Dialog.show_text(gates[area].display_name,_rich(gates[area].help_text)))
	get_viewport().size_changed.connect(_resize)
	_resize()

func configure(data, catalog) -> void:
	_catalog = catalog
	for row: Dictionary in data.rows("town_region_gates"): gates[row.id] = row
	stages = data.rows("town_region_levels")
	members = data.rows("town_region_members").duplicate()
	for row: Dictionary in data.rows("town_monsters"): monsters[row.id] = row
	members.sort_custom(func(a,b): return monsters[a.monster].source_id < monsters[b.monster].source_id)
	for row: Dictionary in data.rows("town_region_items"): items[int(row.source_id)] = row

func open(id: String, state: Dictionary) -> void:
	if not gates.has(id): return
	area = id
	_key = ""
	$Stage/Dialog.hide()
	$Stage/Title.text = gates[area].display_name
	EquipmentItemCard.clear_list($Stage/Drops/Items)
	for token: String in gates[area].drops.split(","):
		var item: Dictionary = items[int(token)]
		var card = DROP.instantiate()
		$Stage/Drops/Items.add_child(card)
		card.get_node("Quality").texture = _catalog.load_resource("operations.quality_%d" % item.quality)
		card.get_node("Icon").texture = _catalog.load_resource(item.resource_id)
		card.get_node("Tier").visible = item.tier > 0
		if item.tier > 0: card.get_node("Tier").texture = _catalog.load_resource("equipment_shop.tier_%d" % item.tier)
		card.pressed.connect(func():
			if not _moved: $Stage/Dialog.show_text(item.display_name,_rich(item.description)))
	$Stage/Drops.scroll_horizontal = 0
	show()
	render(state)

func render(state: Dictionary) -> void:
	if not visible or area.is_empty(): return
	_state = state
	var progress := int(state.main.progress.get("dungeon",0))
	var entry: Dictionary = state.regions[area]
	var key := "%s:%d:%d:%s" % [area,entry.level,progress,str(entry.unlocked)]
	if key == _key: return
	_key = key
	EquipmentItemCard.clear_list($Stage/Rows)
	for stage: Dictionary in stages:
		if stage.area != area: continue
		var row = ROW.instantiate()
		$Stage/Rows.add_child(row)
		row.configure(stage,members,monsters,_catalog,entry.level,progress,entry.unlocked)
		row.activate_requested.connect(func(level): activation_requested.emit({"area":area,"level":level}))

func action_result(result: Dictionary) -> void:
	if result.accepted: close()
	else: $Stage/Dialog.show_text("提示", result.reason)

func close() -> void:
	hide()
	$Stage/Dialog.hide()
	closed.emit()

func _resize() -> void:
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / 750.0, viewport.y / 1334.0)
	$Stage.scale = Vector2.ONE * factor
	$Stage.position = (viewport - Vector2(750,1334) * factor) * 0.5

func _rich(text: String) -> String:
	return text.replace("<color=", "[color=").replace(">", "]").replace("</color]", "[/color]")

func _input(event: InputEvent) -> void:
	if not visible or $Stage/Dialog.visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_moved = false
			_dragging = $Stage/Drops.get_global_rect().has_point(event.position)
			_drag_start = event.position
			_scroll_start = $Stage/Drops.scroll_horizontal
		else: _dragging = false
	elif event is InputEventMouseMotion and _dragging:
		if event.position.distance_to(_drag_start) > 8: _moved = true
		if _moved: $Stage/Drops.scroll_horizontal = _scroll_start + roundi((_drag_start.x - event.position.x) / $Stage.scale.x)
