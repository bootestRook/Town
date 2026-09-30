class_name BuildingUI
extends Control

signal intent(command: Dictionary)
signal closed
signal resource_requested(kind: String)
signal dungeon_requested
signal city_requested
signal hero_requested(id: String)
var building := ""
var _catalog
var _items: Dictionary = {}
var _state: Dictionary = {}
var _selection: Dictionary = {}
var _mode := ""
var _quantity := 0
var _notice_time := 0.0


func _ready() -> void:
	$Stage/EquipmentShop.intent.connect(func(command): intent.emit(command))
	$Stage/EquipmentShop.resource_requested.connect(func(kind): resource_requested.emit(kind))
	$Stage/EquipmentShop.city_requested.connect(func(): city_requested.emit())
	$Stage/EquipmentShop.hero_requested.connect(func(id): hero_requested.emit(id))
	$Stage/EquipmentShop.material_requested.connect(func(id): _select_item(_items["item.%d"%id],"order"))
	$Stage/Life.intent.connect(func(command): intent.emit(command))
	$Stage/Life.material_requested.connect(_open_material_order)
	$Stage/Life.field_requested.connect(close)
	$Stage/Camp.intent.connect(func(command): intent.emit(command))
	$Stage/Camp.resource_requested.connect(func(kind): resource_requested.emit(kind))
	$Stage/Horn.intent.connect(func(command): intent.emit(command))
	$Stage/Horn.resource_requested.connect(func(kind): resource_requested.emit(kind))
	$Stage/Horn.dungeon_requested.connect(func(): close(); dungeon_requested.emit())
	$Stage/Shop.intent.connect(func(command): intent.emit(command))
	$Stage/Shop.select_item.connect(_select_item)
	$Stage/Back.pressed.connect(close)
	$Stage/Report.pressed.connect(_report)
	$Stage/ReportPanel/Close.pressed.connect(func(): $Stage/ReportPanel.hide())
	$Stage/Modal/Cancel.pressed.connect(func(): $Stage/Modal.hide())
	$Stage/Modal/Confirm.pressed.connect(_confirm)
	$Stage/Modal/Minus.pressed.connect(func(): _change_quantity(-1))
	$Stage/Modal/Plus.pressed.connect(func(): _change_quantity(1))
	$Stage/Modal/Ten.pressed.connect(func(): _change_quantity(10))
	$Stage/Modal/Reset.pressed.connect(func(): _quantity = 0; _change_quantity(0))
	get_viewport().size_changed.connect(_resize)
	_resize()


func configure(catalog, items: Array, recipes: Array, buildings: Array) -> void:
	_catalog = catalog
	for row: Dictionary in items:
		_items[row.id] = row
	$Stage/Life.configure(catalog, _items)
	$Stage/Shop.configure(catalog, _items, recipes, buildings)
	$Stage/Revival.configure(catalog)


func open(id: String, state: Dictionary) -> void:
	building = id
	_state = state
	$Stage/Modal.hide()
	$Stage/ReportPanel.hide()
	$Stage/Notice.hide()
	$Stage/Back.show()
	var life: bool = state.services.has(id)
	var camp := id == TownHeroCamp.BUILDING
	var horn := id == TownBattleHorn.BUILDING
	var equipment: bool = $Stage/EquipmentShop.supports(id)
	for node in [$Stage/Topbar, $Stage/MoneyBg, $Stage/Coin, $Stage/Coins]:
		node.visible = not life and not camp and not horn and not equipment
	var revival := id == "building.11"
	$Stage/Life.visible = life
	$Stage/Shop.visible = not life and not revival and not camp and not horn and not equipment
	$Stage/EquipmentShop.visible = equipment
	$Stage/Revival.visible = revival
	$Stage/Camp.visible = camp
	$Stage/Horn.visible = horn
	$Stage/Report.visible = not revival and not camp and not horn and not equipment
	$Stage/ReportLabel.visible = not revival and not camp and not horn and not equipment
	$Stage/Report.position = Vector2(659, 994) if life else Vector2(652, 464)
	$Stage/ReportLabel.position = Vector2(661, 1066) if life else Vector2(653, 544)
	if life:
		$Stage/Life.open(id, state)
	elif camp:
		$Stage/Camp.open(state)
	elif horn:
		$Stage/Horn.open(state)
	elif equipment:
		$Stage/EquipmentShop.open(id, state)
	elif not revival:
		$Stage/Shop.open(id, state)
	show()
	render(state)


func close() -> void:
	$Stage/EquipmentShop.close_trade()
	$Stage/Life.cancel_drag()
	hide()
	building = ""
	closed.emit()


func render(state: Dictionary) -> void:
	_state = state
	if not visible:
		return
	$Stage/Coins.text = str(int(state.coins))
	if $Stage/Life.visible:
		$Stage/Life.render(state)
	elif $Stage/Camp.visible:
		$Stage/Camp.render(state)
	elif $Stage/Horn.visible:
		$Stage/Horn.render(state)
	elif $Stage/EquipmentShop.visible:
		$Stage/EquipmentShop.render(state)
	elif $Stage/Revival.visible:
		$Stage/Revival.render(state)
	else:
		$Stage/Shop.render(state)
	if $Stage/Modal.visible:
		_change_quantity(0)


func action_result(command: Dictionary, result: Dictionary) -> void:
	$Stage/EquipmentShop.action_result(command,result)
	if result.get("confirm", false):
		$Stage/Horn.confirm(result.reason)
		return
	if not result.accepted:
		$Stage/Notice.text = result.reason
		$Stage/Notice.show()
		_notice_time = 3.0
		return
	if command.type == "produce":
		$Stage/Life.play_production()
	elif command.type in ["order", "craft", "sale"]:
		$Stage/Modal.hide()
	elif command.type == "summon":
		$Stage/Notice.text = "已召唤，英雄完成当前服务后前来"
		$Stage/Notice.show()
		_notice_time = 2.5


func _select_item(row: Dictionary, mode: String) -> void:
	_selection = row
	_mode = mode
	$Stage/Modal/Reset.visible = mode != "sale"
	$Stage/Modal/Ten.visible = mode != "sale"
	$Stage/Modal/Minus/Text.text = "‹" if mode == "sale" else "−"
	$Stage/Modal/Plus/Text.text = "›" if mode == "sale" else "+"
	if mode == "sale":
		if row.offers.is_empty():
			action_result({}, {"accepted":false, "reason":"暂无适合此职业的待售装备"})
			return
		_quantity = 0
		$Stage/Modal.show()
		_change_quantity(0)
		return
	_quantity = int(_state.orders.get(row.id, 0)) if mode == "order" else 1
	$Stage/Modal/Title.text = ("预购 · " if mode == "order" else "打造 · ") + row.display_name
	$Stage/Modal/Icon.texture = _catalog.load_resource(row.resource_id)
	$Stage/Modal.show()
	_change_quantity(0)


func _open_material_order(material: String) -> void:
	open("building.7", _state)
	_select_item(_items[material], "order")


func _change_quantity(delta: int) -> void:
	if _selection.is_empty():
		return
	if _mode == "sale":
		_quantity = clampi(_quantity + delta, 0, _selection.offers.size() - 1)
		var offer: Dictionary = _selection.offers[_quantity]
		$Stage/Modal/Title.text = "出售 · " + offer.display_name
		$Stage/Modal/Icon.texture = _catalog.load_resource(offer.resource_id)
		$Stage/Modal/Detail.text = "%s持有 %d 金币\n售价 %d 金币" % [_selection.hero.name, _selection.hero.wallet, offer.price]
		$Stage/Modal/Count.text = "%d / %d" % [_quantity + 1, _selection.offers.size()]
		$Stage/Modal/Confirm/Text.text = "出售"
		return
	var limit := int(_selection.order_limit) if _mode == "order" else 10
	_quantity = clampi(_quantity + delta, 0, limit)
	$Stage/Modal/Count.text = str(_quantity)
	if _mode == "order":
		$Stage/Modal/Detail.text = "持有 %d  ·  单价 %d 金币\n预购总价 %d 金币" % [_state.inventory[_selection.id], _selection.buy_price, _selection.buy_price * _quantity]
		$Stage/Modal/Confirm/Text.text = "取消预购" if _quantity == 0 else "确定预购"
	else:
		var r := _selection
		$Stage/Modal/Detail.text = "%s %d/%d\n%s %d/%d" % [_items[r.material_a].display_name, _state.inventory[r.material_a], r.count_a * _quantity, _items[r.material_b].display_name, _state.inventory[r.material_b], r.count_b * _quantity]
		$Stage/Modal/Confirm/Text.text = "打造"


func _confirm() -> void:
	if _mode == "sale":
		intent.emit({"type":"sale", "hero":_selection.hero.id, "serial":_selection.offers[_quantity].serial})
	else:
		intent.emit({"type":_mode, "item":_selection.id, "quantity":_quantity})


func select_buyer(hero: String) -> void:
	if $Stage/EquipmentShop.supports(building): $Stage/EquipmentShop.select_buyer(hero)
	else: $Stage/Shop.select_buyer(hero)


func _report() -> void:
	if $Stage/Life.visible:
		$Stage/Life.show_report()
		return
	var lines: Array[String] = []
	for row: Dictionary in _state.report:
		var money := "  %+d金币" % row.coins if row.coins != 0 else ""
		lines.append("%s%s\n" % [row.text, money])
	$Stage/ReportPanel/Scroll/Text.text = "\n".join(lines) if not lines.is_empty() else "暂无经营记录"
	$Stage/ReportPanel.show()


func _resize() -> void:
	var viewport := get_viewport_rect().size
	var factor := minf(viewport.x / 750.0, viewport.y / 1334.0)
	$Stage.scale = Vector2.ONE * factor
	$Stage.position = (viewport - Vector2(750, 1334) * factor) * 0.5


func _process(delta: float) -> void:
	if visible and $Stage/EquipmentShop.visible:
		$Stage/Back.visible = not $Stage/EquipmentShop.overlay_open()
	if visible and $Stage/Horn.visible:
		$Stage/Back.visible = not $Stage/Horn.overlay_open()
	if visible and $Stage/Camp.visible:
		$Stage/Back.visible = not $Stage/Camp.overlay_open()
	if visible and $Stage/Life.visible:
		var has_overlay: bool = $Stage/Life.overlay_open()
		$Stage/Back.visible = not has_overlay
		$Stage/Report.visible = not has_overlay
		$Stage/ReportLabel.visible = not has_overlay
	if _notice_time > 0:
		_notice_time -= delta
		if _notice_time <= 0:
			$Stage/Notice.hide()
