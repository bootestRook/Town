class_name MainHUD
extends Control

signal intent(command: Dictionary)
signal overlay_changed(opened: bool)
signal hero_locate_requested(id: String)
signal map_occlusion_changed(height: float)
const ROUTES := ["gameplay", "dungeon", "heroes", "recruit", "shop"]
var route := ""
var _catalog
var _state: Dictionary = {}
var _notice_time := 0.0
var _selected_textures: Array = []
var _normal_textures: Array = []
var _hero_return_view: Dictionary = {}
var _shop_return_nodes: Array[String] = []

func _ready() -> void:
	MainHUDSignals.bind(self)
	get_viewport().size_changed.connect(_resize)
	_resize()

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	for i in range(5):
		_selected_textures.append(catalog.load_resource("main_ui.nav_%d_selected" % i))
		_normal_textures.append(catalog.load_resource("main_ui.nav_%d" % i))
	for page: String in ["Panels", "HeroRoster", "Dialogs", "HeroDetail", "EquipmentDetail", "HeroManagement", "SkillTooltip", "Recruitment", "RecruitOverlay", "DiamondShop", "MapDispatch"]:
		get_node("Stage/"+page).configure(catalog, definitions)

func render(state: Dictionary) -> void:
	_state = state
	var main: Dictionary = state.main
	$Stage/Top/Coins/Value.text = compact(state.coins)
	$Stage/Top/Diamonds/Value.text = compact(state.diamonds)
	$Stage/Top/Energy/Value.text = "%d/%d" % [main.energy, main.energy_max]
	$Stage/Top/Combat.text = compact(main.power)
	$Stage/Top/Profile/Name.text = main.player_name
	$Stage/Top/Profile/Portrait.texture = _catalog.load_resource(main.avatar)
	$Stage/Top/Energy/RedDot.visible = main.energy_claimable
	$Stage/Bottom/Nav3/RedDot.visible = main.recruitment.tickets > 0 if main.recruitment.offer.item != 102 else state.diamonds >= main.recruitment.offer.amount
	for page: String in ["Panels", "HeroRoster", "Dialogs", "HeroDetail", "EquipmentDetail", "HeroManagement", "Recruitment", "RecruitOverlay", "DiamondShop", "MapDispatch"]:
		get_node("Stage/"+page).render(state)


func navigate(next: String, toggle: bool = true) -> void:
	if next not in ROUTES or _state.is_empty(): return
	if next == "shop":
		_open_diamond_store()
		return
	$Stage/DiamondShop.hide()
	_shop_return_nodes.clear()
	$Stage/SkillTooltip.hide()
	$Stage/Notice.hide()
	_notice_time = 0.0
	$Stage/Dialogs.hide()
	$Stage/HeroDetail.hide()
	$Stage/EquipmentDetail.hide()
	$Stage/HeroManagement.hide()
	$Stage/Recruitment.hide()
	$Stage/RecruitOverlay.hide()
	$Stage/Recruitment.busy = false
	_hero_return_view.clear()
	if next == route and toggle:
		close()
		return
	route = next
	$Stage/Panels.hide()
	$Stage/HeroRoster.hide()
	if next == "heroes": $Stage/HeroRoster.open(_state)
	elif next == "recruit": $Stage/Recruitment.open(_state)
	else: $Stage/Panels.open(next, _state)
	_sync_selection()
	_sync_overlay()


func close() -> void:
	if $Stage/MapDispatch.visible:
		$Stage/MapDispatch.close()
		if $Stage/MapDispatch.visible: return
	route = ""
	$Stage/DiamondShop.hide()
	_shop_return_nodes.clear()
	$Stage/SkillTooltip.hide()
	$Stage/Panels.hide()
	$Stage/HeroRoster.hide()
	$Stage/Dialogs.hide()
	$Stage/HeroDetail.hide()
	$Stage/EquipmentDetail.hide()
	$Stage/HeroManagement.hide()
	$Stage/Recruitment.hide()
	$Stage/RecruitOverlay.hide()
	$Stage/Recruitment.busy = false
	_hero_return_view.clear()
	_sync_selection()
	_sync_overlay()


func open_city() -> void:
	_open_top("city")


func open_resource(kind: String) -> void:
	if kind == "coins": _open_top("coins")
	elif kind == "diamonds": _detail("diamond_store", {})


func action_result(command: Dictionary, result: Dictionary) -> void:
	if not result.accepted:
		_notice(result.reason)
	elif result.has("message"):
		_notice(result.message)
	elif command.type == "hero_star": _notice("升星成功")
	$Stage/Panels.action_result(command, result)
	$Stage/Dialogs.action_result(command, result)
	$Stage/DiamondShop.action_result(command, result)
	$Stage/MapDispatch.action_result(command, result)
	if route == "recruit":
		$Stage/RecruitOverlay.action_result(command, result, _state)
		$Stage/Recruitment.busy = $Stage/RecruitOverlay.kind in ["animation", "success"]
		_sync_overlay()


func _open_top(kind: String) -> void:
	close()
	_detail(kind, {})


func _detail(kind: String, data: Dictionary) -> void:
	$Stage/SkillTooltip.hide()
	if kind == "diamond_store":
		_open_diamond_store()
	elif kind == "dispatch":
		_notice_time = 0.0
		$Stage/Notice.hide()
		$Stage/MapDispatch.open(_state)
	elif kind == "hero_management":
		if $Stage/HeroDetail.visible and not _state.main.battle.is_empty() and $Stage/HeroDetail.hero_id in _state.main.expedition_team:
			_notice("英雄正在战斗中")
			return
		$Stage/HeroDetail.hide()
		$Stage/Dialogs.hide()
		_hero_return_view.clear()
		$Stage/HeroManagement.open(int(data.get("page", 0)), _state)
	elif kind == "hero":
		if not $Stage/HeroDetail.visible:
			_hero_return_view = {"kind":"management"} if $Stage/HeroManagement.visible else ($Stage/Dialogs.view_context() if $Stage/Dialogs.visible else {})
		$Stage/HeroManagement.hide()
		$Stage/Dialogs.hide()
		$Stage/HeroDetail.open(data, _state)
	elif kind == "equipment_detail": $Stage/EquipmentDetail.open(data, _state)
	else: $Stage/Dialogs.open(kind, data, _state)
	_sync_overlay()


func _close_hero() -> void:
	$Stage/Dialogs.hide()
	if not _hero_return_view.is_empty():
		if _hero_return_view.kind == "management":
			$Stage/HeroManagement.show()
			$Stage/HeroManagement.render(_state)
		else: $Stage/Dialogs.restore_context(_hero_return_view, _state)
	_hero_return_view.clear()
	_sync_overlay()


func _sync_selection() -> void:
	if _normal_textures.is_empty(): return
	for i in range(5):
		get_node("Stage/Bottom/Nav%d" % i).texture_normal = _selected_textures[i] if route == ROUTES[i] else _normal_textures[i]


func _sync_overlay() -> void:
	$Stage/Bottom.visible = route != "recruit" and not $Stage/DiamondShop.visible
	map_occlusion_changed.emit(708.0 * $Stage.scale.x if route in ["heroes", "recruit"] else 0.0)
	overlay_changed.emit(route not in ["", "heroes", "recruit"] or $Stage/Dialogs.visible or $Stage/HeroDetail.visible or $Stage/HeroManagement.visible or $Stage/RecruitOverlay.visible or $Stage/DiamondShop.visible or $Stage/MapDispatch.visible)


func _resize() -> void:
	var viewport := get_viewport_rect().size
	var factor := viewport.x / 720.0
	$Stage.scale = Vector2.ONE * factor
	$Stage.size = Vector2(720, viewport.y / factor)
	$Stage/Panels.size.y = $Stage.size.y - 194
	$Stage/HeroRoster.position.y = $Stage.size.y - 708
	$Stage/Recruitment.position.y = $Stage.size.y - 708
	$Stage/RecruitOverlay.resize_page($Stage.size.y)
	$Stage/Dialogs.size.y = $Stage.size.y
	$Stage/HeroDetail.resize_page($Stage.size.y)
	$Stage/EquipmentDetail.resize_page($Stage.size.y)
	$Stage/HeroManagement.resize_page($Stage.size.y)
	$Stage/DiamondShop.resize_page($Stage.size.y)
	$Stage/MapDispatch.resize_page($Stage.size.y)
	$Stage/Dialogs.get_node("Panel").position.y = maxf(78, ($Stage.size.y - 970) * 0.5)
	$Stage/Notice.position.y = $Stage.size.y - 239
	_sync_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if $Stage/SkillTooltip.visible: $Stage/SkillTooltip.hide()
		elif $Stage/MapDispatch.visible: $Stage/MapDispatch.close()
		elif $Stage/EquipmentDetail.visible: $Stage/EquipmentDetail.close()
		elif $Stage/Dialogs.visible: $Stage/Dialogs.close()
		elif $Stage/DiamondShop.visible: $Stage/DiamondShop.close()
		elif $Stage/HeroDetail.visible: $Stage/HeroDetail.close()
		elif $Stage/HeroManagement.visible: $Stage/HeroManagement.close()
		elif $Stage/RecruitOverlay.visible: $Stage/RecruitOverlay.close()
		elif not route.is_empty(): close()
		else: return
		get_viewport().set_input_as_handled()


func _notice(message: String) -> void:
	$Stage/Notice.text = message
	$Stage/Notice.show()
	_notice_time = 2.5


func _open_diamond_store() -> void:
	if $Stage/DiamondShop.visible: return
	$Stage/SkillTooltip.hide()
	$Stage/Notice.hide()
	_notice_time = 0.0
	_shop_return_nodes.clear()
	for name: String in ["Panels","HeroRoster","Dialogs","HeroDetail","HeroManagement","EquipmentDetail","Recruitment","RecruitOverlay"]:
		var page := get_node("Stage/"+name)
		if page.visible:
			_shop_return_nodes.append(name)
			page.hide()
	$Stage/DiamondShop.open(_state)
	_sync_overlay()


func _close_diamond_store() -> void:
	$Stage/Dialogs.hide()
	for name: String in _shop_return_nodes: get_node("Stage/"+name).show()
	_shop_return_nodes.clear()
	render(_state)
	_sync_overlay()


func _process(delta: float) -> void:
	if _notice_time > 0:
		_notice_time -= delta
		$Stage/Notice.visible = _notice_time > 0
	$Stage/Notice.position.y = 92 if $Stage/Dialogs.visible or $Stage/RecruitOverlay.visible or $Stage/MapDispatch.visible else $Stage.size.y - 239
	$Stage/Panels/Footer/FooterText.visible = not $Stage/Notice.visible


static func compact(value: float) -> String:
	if value < 10000: return str(int(value))
	var divisor := 1000000.0 if value >= 1000000 else 1000.0
	var number := "%.1f" % (floorf(value / divisor * 10.0) / 10.0)
	return number.trim_suffix(".0") + ("m" if divisor == 1000000 else "k")
