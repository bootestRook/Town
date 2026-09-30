extends Control

signal closed
signal detail_requested(kind: String, data: Dictionary)
signal locate_requested(id: String)
const CARD = preload("res://scenes/town/main_hero_card.tscn")
var _catalog
var _definitions: Dictionary = {}
var _key := ""
var _order: Array = []

func _ready() -> void:
	$Close.pressed.connect(func(): closed.emit())
	$Lineup.pressed.connect(func(): detail_requested.emit("hero_management", {"page":0}))
	$Dispatch.pressed.connect(func(): detail_requested.emit("dispatch", {}))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions

func open(state: Dictionary) -> void:
	show()
	render(state)

func render(state: Dictionary) -> void:
	if not visible: return
	var rows: Array = state.main.roster.filter(func(h): return not h.live.is_empty())
	rows.sort_custom(func(a,b): return a.power > b.power if a.power != b.power else a.job > b.job)
	$Count.text = "英雄：%d/%d" % [rows.size(), state.main.map_capacity]
	var key := str(rows.map(func(h): return [h.id,h.name,h.level,h.star,h.power,h.max_level]))
	if key == _key: return
	_key = key
	_order = rows.map(func(h): return h.id)
	var cards := $Scroll/Grid.get_children()
	for i in rows.size():
		var card = cards[i] if i < cards.size() else CARD.instantiate()
		if i >= cards.size():
			$Scroll/Grid.add_child(card)
			card.opened.connect(func(id): detail_requested.emit("hero", {"hero": id, "order": _order}))
			card.located.connect(func(id): locate_requested.emit(id))
		card.configure(rows[i], _catalog, _definitions)
	for i in range(rows.size(), cards.size()):
		$Scroll/Grid.remove_child(cards[i])
		cards[i].queue_free()
