extends Control

signal closed
signal intent(command: Dictionary)
const CARD := preload("res://scenes/town/main_dispatch_card.tscn")
const HELP := "1.领主可以将英雄们放入不同的野区击杀怪物,获取材料资源。\n\n2.野区共有三个,分别为兽人密林、亡灵墓地、魔族战场,被三种不同的异族怪物占据,击杀怪物后,掉落的材料也不同,领主可以根据目前缺失的材料来调整英雄们去往的野区。\n\n3.三个野区的异族怪物战力不同,请注意英雄们的战力是否与其对等,避免因战力不对等而出现英雄无法击杀怪物的情况。"
var assignments: Dictionary = {}
var selected: Array = []
var _confirmed: Dictionary = {}
var _pending: Dictionary = {}
var _cards: Dictionary = {}
var _catalog
var _definitions: Dictionary = {}
var _state: Dictionary = {}

func _ready() -> void:
	$Shade.pressed.connect(close)
	$Panel/Help.pressed.connect(_help)
	$Popup/Dismiss.pressed.connect(_cancel)
	$Popup/Box/Cancel.pressed.connect(_cancel)
	$Popup/Box/Accept.pressed.connect(_accept)
	for area: String in ["town", "field", "field2", "field3"]:
		get_node("Panel/All"+area).pressed.connect(func(): request_move(area, true))
		get_node("Panel/"+area+"/Move").pressed.connect(func(): request_move(area, false))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions

func resize_page(height: float) -> void:
	size.y = height
	for path: String in ["Shade", "Shade/Tint", "Popup", "Popup/Dismiss", "Popup/Dismiss/Tint"]: get_node(path).size.y = height
	var factor := minf(1.0, (height - 105) / 1145.0)
	$Panel.scale = Vector2.ONE * factor
	$Panel.position = Vector2((720-720*factor)*0.5, (height-1145*factor)*0.5-20)
	$DismissHint.position.y = $Panel.position.y+1145*factor+4
	$Popup/Box.position.y = (height-$Popup/Box.size.y)*0.5

func open(state: Dictionary) -> void:
	_state = state
	assignments.clear()
	_confirmed.clear()
	selected.clear()
	_pending.clear()
	$Popup.hide()
	for hero: Dictionary in state.main.roster:
		if hero.deployed: assignments[hero.id] = hero.assigned_area
	show()
	_rebuild()

func render(state: Dictionary) -> void:
	_state = state
	if visible: _selection()

func close() -> void:
	if not visible: return
	if $Popup.visible:
		_cancel()
		return
	intent.emit({"type":"hero_dispatch", "assignments":assignments.duplicate(), "confirmed":_confirmed.duplicate()})

func request_move(area: String, all: bool) -> void:
	var ids: Array = assignments.keys().filter(func(id): return assignments[id] != area) if all else selected.duplicate()
	if ids.is_empty(): return
	intent.emit({"type":"dispatch_preview", "area":area, "heroes":ids})

func action_result(command: Dictionary, result: Dictionary) -> void:
	if not visible or not result.accepted: return
	if command.type == "hero_dispatch":
		hide()
		closed.emit()
	elif command.type == "dispatch_preview":
		for id: String in result.eligible: assignments[id] = result.area
		selected.clear()
		_pending = result
		_rebuild()
		if not result.weak.is_empty():
			$Popup/Box/Title.text = "提示"
			$Popup/Box/Scroll/Text.text = "%s的战力低于当前地图的推荐战力%s,确定要放入到该地图吗？更换更强的装备或升级英雄的星级可以提升英雄的战力" % ["、".join(result.names), int(result.power)]
			_popup(false)

func _rebuild() -> void:
	for card in _cards.values():
		card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	var heroes: Array = _state.main.roster.filter(func(h): return assignments.has(h.id))
	heroes.sort_custom(func(a,b): return a.power > b.power)
	for hero: Dictionary in heroes:
		var card := CARD.instantiate()
		get_node("Panel/"+assignments[hero.id]+"/Scroll/Grid").add_child(card)
		card.configure(hero, _catalog, _definitions)
		card.chosen.connect(_choose)
		_cards[hero.id] = card
	_selection()

func _choose(id: String) -> void:
	if not selected.is_empty() and assignments[id] != assignments[selected[0]]: return
	if id in selected: selected.erase(id)
	else: selected.append(id)
	_selection()

func _selection() -> void:
	var origin: String = "" if selected.is_empty() else assignments[selected[0]]
	for area: String in _state.main.dispatch:
		var info: Dictionary = _state.main.dispatch[area]
		var region := get_node("Panel/"+area)
		region.get_node("Locked").visible = not info.unlocked
		region.get_node("Locked/Text").text = "通过地下城%d后解锁" % info.dungeon
		region.get_node("Move").visible = info.unlocked and origin != "" and origin != area
		if region.has_node("Power"): region.get_node("Power").text = str(int(info.power))
	for hero: Dictionary in _state.main.roster:
		if not _cards.has(hero.id): continue
		var area: String = assignments[hero.id]
		_cards[hero.id].set_selection(hero.id in selected, not origin.is_empty() and area != origin, hero.power < _state.main.dispatch[area].power)

func _popup(help: bool) -> void:
	$Popup/Box.size.y = 720 if help else 480
	$Popup/Box/Frame.size.y = $Popup/Box.size.y
	$Popup/Box/Scroll.size.y = 525 if help else 244
	$Popup/Box/Scroll.scroll_vertical = 0
	$Popup/Box/Accept.visible = not help
	$Popup/Box/Cancel.visible = not help
	resize_page(size.y)
	$Popup.show()

func _help() -> void:
	_pending.clear()
	$Popup/Box/Title.text = "地图派遣说明"
	$Popup/Box/Scroll/Text.text = HELP
	_popup(true)

func _cancel() -> void:
	_pending.clear()
	$Popup.hide()

func _accept() -> void:
	for id: String in _pending.get("weak", []):
		assignments[id] = _pending.area
		_confirmed[id] = _pending.area
	_cancel()
	_rebuild()
