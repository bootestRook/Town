class_name LifePage
extends Control

signal intent(command: Dictionary)
signal material_requested(material: String)
signal field_requested
const SeatScene = preload("res://scenes/town/service_seat.tscn")
const Format = preload("res://src/features/town/presentation/life_format.gd")
var building := ""
var _catalog
var _recipe: Dictionary = {}
var _items: Dictionary = {}
var _state: Dictionary = {}
var _drag_start := Vector2.ZERO
var _held := false
var _dragging := false
var _production := 0.0
var _seat_key := ""


func _ready() -> void:
	$Material.gui_input.connect(_material_input)
	$Upgrade.pressed.connect(func(): intent.emit({"type": "upgrade", "building": building}))
	$Product.pressed.connect(func(): $ProductTip.show())
	$BuySeat.pressed.connect(func(): $SeatPanel.show(); $ProductTip.hide(); $Bubble.hide())
	$PriceInfo.pressed.connect(func(): _bubble(_recipe.price_tip % (Format.number(_state.details[building].bonus * 100) + "%")))
	$TimeInfo.pressed.connect(func(): _bubble(_recipe.time_tip % Format.number(_state.details[building].reduction)))
	$SeatInfo.pressed.connect(func(): _bubble(_recipe.seat_tip % str(_state.details[building].capacity)))
	$SeatPanel/Row2/Buy.pressed.connect(func(): intent.emit({"type":"buy_seat", "building":building, "slot":2}))
	$SeatPanel/Row3/Buy.pressed.connect(func(): intent.emit({"type":"buy_seat", "building":building, "slot":3}))
	$SeatPanel/Row1/Buy.pressed.connect(func(): $SeatPanel.hide(); _bubble("月卡服务尚未接入"))
	$Help.pressed.connect(func(): $HelpPanel.show())
	$AcquireHint.pressed.connect(func(): $AcquirePanel.show())
	$AcquirePanel/Way0.pressed.connect(func(): material_requested.emit(_recipe.material))
	$AcquirePanel/Way1.pressed.connect(func(): field_requested.emit())
	$GoldAdd.pressed.connect(func(): _bubble("金币补充服务尚未接入"))
	$DiamondAdd.pressed.connect(func(): _bubble("钻石商店尚未接入"))
	for panel in [$SeatPanel, $ReportPanel, $HelpPanel, $AcquirePanel]:
		panel.get_node("Dismiss").pressed.connect(func(): panel.hide())


func configure(catalog, items: Dictionary) -> void:
	_catalog = catalog
	_items = items


func open(id: String, state: Dictionary) -> void:
	cancel_drag()
	_production = 0
	$Production.hide()
	building = id
	_recipe = state.services[id]
	$Room.texture = _catalog.load_resource(_recipe.room)
	$Machine.texture = _catalog.load_resource(_recipe.machine)
	$Machine.scale = Vector2.ONE * float(_recipe.machine_scale)
	$Machine.position.y = 984 - 312 * float(_recipe.machine_scale)
	$Product/Icon.texture = _catalog.load_resource(_items[_recipe.product].resource_id)
	$Material.texture = _catalog.load_resource(_items[_recipe.material].resource_id)
	$Ghost.texture = $Material.texture
	for panel in [$SeatPanel, $ReportPanel, $HelpPanel, $AcquirePanel, $Bubble]:
		panel.hide()
	$ProductTip.visible = int(state.inventory[_recipe.product]) > 0
	_seat_key = "reset"
	render(state)


func render(state: Dictionary) -> void:
	if building.is_empty():
		return
	_state = state
	var detail: Dictionary = state.details[building]
	$Coins.text = Format.money(state.coins)
	$Diamonds.text = Format.money(state.diamonds)
	$Name.text = _recipe.display_name
	$Level.text = "Lv%d" % state.buildings[building]
	$Bonus.text = "+%s%%" % Format.number(detail.bonus * 100)
	$Reduction.text = "-%sS" % Format.number(detail.reduction)
	$Capacity.text = str(detail.capacity)
	$UpgradeCost.text = Format.money(detail.cost)
	$Upgrade/Text.text = "已满级" if detail.max_level else "升级"
	$Upgrade.disabled = detail.max_level
	$LevelProgress.value = detail.stage_progress
	$BenefitIcon.texture = _catalog.load_resource("life_ui." + detail.stage_kind)
	$Benefit.text = ("-" if detail.stage_kind == "time_bonus" else "+") + Format.number(detail.stage_value) + ("%" if detail.stage_kind == "price_bonus" else "")
	$Benefit.visible = not detail.max_level
	$BenefitIcon.visible = not detail.max_level
	$UpgradeInfo.text = "已达最高等级" if detail.max_level else "进度条满："
	$Stock.text = str(int(state.inventory[_recipe.product]))
	var available: bool = state.inventory[_recipe.product] > 0
	for node in [$Product, $ProductBackground, $Stock, $PriceBackground, $Price]:
		node.visible = available
	$Empty.visible = not available
	$Product.disabled = not available
	if not available:
		$ProductTip.hide()
	$Price.text = Format.money(detail.price)
	$MaterialCount.text = str(int(state.inventory[_recipe.material]))
	$AcquireHint.visible = state.inventory[_recipe.material] < _recipe.material_cost
	$AcquirePanel/Icon.texture = $Material.texture
	$AcquirePanel/Count.text = $MaterialCount.text
	$AcquirePanel/Name.text = _items[_recipe.material].display_name
	$AcquirePanel/Description.text = _recipe.material_description.replace("<color=", "[color=").replace(">", "]").replace("</color]", "[/color]")
	$ProductTip/Title.text = _items[_recipe.product].display_name
	$ProductTip/Recovery.text = "恢复%s:%d%%" % [_recipe.stat_name, detail.recovery]
	$ProductTip/Price.text = "[center]售价：%s=%s[color=#34cd3f]*%s%%[/color][/center]" % [Format.money(detail.price), Format.money(_items[_recipe.product].sell_price), Format.number(100 + detail.bonus * 100)]
	$ProductTip/Duration.text = "[center]使用时间：%s=%s[color=#34cd3f]-%s[/color]秒[/center]" % [Format.number(detail.duration), Format.number(_recipe.service_seconds), Format.number(detail.reduction)]
	_render_seat_panel(state, detail)
	$HelpPanel/Title.text = _recipe.display_name + "说明"
	$HelpPanel/Description.text = _recipe.help_description
	$HelpPanel/Price.text = Format.number(detail.bonus * 100) + "%"
	$HelpPanel/Time.text = Format.number(detail.reduction) + "S"
	_render_seats(state.heroes.filter(func(h): return h.mode == "serving" and h.target == building))


func _render_seat_panel(state: Dictionary, detail: Dictionary) -> void:
	$SeatPanel/Title.text = _recipe.seat_title
	$SeatPanel/Row0/Label.text = "等级%d" % detail.seat_unlock
	$SeatPanel/Row0/State.text = "已达成" if state.buildings[building] >= detail.seat_unlock else "未达成"
	$SeatPanel/Row0/State.add_theme_color_override("font_color", Color("34cd3f") if state.buildings[building] >= detail.seat_unlock else Color("df3a14"))
	$SeatPanel/Row1/State.hide()
	for slot in [2,3]:
		var row = $SeatPanel.get_node("Row%d" % slot)
		var purchased: bool = slot in state.purchased_seats[building]
		row.get_node("State").visible = purchased
		row.get_node("Buy").visible = not purchased
		row.get_node("Price").text = str(int(_recipe["seat_cost_%d" % slot]))


func _render_seats(occupants: Array) -> void:
	var key := str(occupants.map(func(h): return h.id))
	if key != _seat_key:
		_seat_key = key
		for child in $Seats.get_children():
			$Seats.remove_child(child)
			child.queue_free()
		for hero: Dictionary in occupants:
			var seat = SeatScene.instantiate()
			$Seats.add_child(seat)
			var texture: Texture2D = _catalog.load_resource("heroes.%s_portrait" % hero.visual)
			var portrait := AtlasTexture.new()
			portrait.atlas = texture
			portrait.region = texture.get_image().get_used_rect()
			seat.get_node("Crop/Hero").texture = portrait
	for i in occupants.size():
		var seat = $Seats.get_child(i)
		seat.get_node("Time").text = "%dS" % ceili(occupants[i].timer)
		seat.get_node("Progress").value = occupants[i].timer / occupants[i].service_total


func overlay_open() -> bool:
	return $SeatPanel.visible or $ReportPanel.visible or $HelpPanel.visible or $AcquirePanel.visible


func show_report() -> void:
	var report: Dictionary = _state.life_reports[building]
	$ReportPanel/Total.text = Format.money(report.total)
	var lines: Array[String] = []
	for bill: Dictionary in report.bills:
		var second := int(bill.second)
		lines.append("[%02d:%02d:%02d] 向[color=#34cd3f]%s[/color]出售了[color=#34cd3f]%s[/color]，获得金币[color=#34cd3f]%s[/color]" % [second / 3600, second / 60 % 60, second % 60, bill.hero, bill.product, Format.money(bill.coins)])
	$ReportPanel/Scroll/Text.text = "\n\n".join(lines)
	$ReportPanel.show()


func _bubble(text: String) -> void:
	$Bubble/Text.text = text
	$Bubble.show()
	$ProductTip.hide()


func play_production() -> void:
	_production = 2.0
	$Production.show()
	$ProductTip.show()


func cancel_drag() -> void:
	_held = false
	_dragging = false
	$Ghost.hide()


func _material_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _state.inventory[_recipe.material] < _recipe.material_cost:
			$AcquireHint.show()
			return
		_held = true
		_drag_start = $Material.get_global_transform_with_canvas() * event.position


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not $Product.get_global_rect().has_point(event.position) and not $ProductTip.get_global_rect().has_point(event.position):
			$ProductTip.hide()
		$Bubble.hide()
	if not _held:
		return
	if event is InputEventMouseMotion:
		if event.position.distance_to(_drag_start) > 8.0:
			_dragging = true
			$Ghost.show()
			$Ghost.position = get_global_transform_with_canvas().affine_inverse() * event.position - $Ghost.size / 2
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var local: Vector2 = $WorkArea.get_global_transform_with_canvas().affine_inverse() * event.position
		var valid: bool = _dragging and Rect2(Vector2.ZERO, $WorkArea.size).has_point(local)
		cancel_drag()
		if valid:
			intent.emit({"type": "produce", "building": building, "material": _recipe.material})
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _production > 0:
		_production = maxf(0.0, _production - delta)
		$Machine.frame = mini(7, int((2.0 - _production) * 4))
		$Production.value = (2.0 - _production) / 2.0
		if _production == 0:
			$Production.hide()
	else:
		$Machine.frame = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		cancel_drag()
