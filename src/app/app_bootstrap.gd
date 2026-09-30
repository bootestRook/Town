class_name AppBootstrap
extends Node

const DataRegistryScript = preload("res://src/data/data_registry.gd")
const ResourceCatalogScript = preload("res://src/resources/resource_catalog.gd")
const TownFeatureScript = preload("res://src/features/town/domain/town_feature.gd")
const OperationsScript = preload("res://src/features/town/domain/town_operations.gd")
const ACTIVE_BUILDINGS := ["building.1", "building.2", "building.3", "building.4", "building.6", "building.7", "building.9", "building.10", "building.11", TownHeroCamp.BUILDING, TownBattleHorn.BUILDING]

var boot_error := ""
var _feature: TownFeature
var _operations: TownOperations
var _ui_clock := 0.0
var _resource_return := ""


func _ready() -> void:
	var data = DataRegistryScript.new()
	boot_error = data.load_default()
	if not boot_error.is_empty():
		push_error(boot_error)
		return
	var resources = ResourceCatalogScript.new()
	boot_error = resources.load_default()
	if not boot_error.is_empty():
		push_error(boot_error)
		return
	Engine.max_fps = int(data.setting("app.target_fps", 60))
	_feature = TownFeatureScript.new(data.rows("town_buildings"))
	_operations = OperationsScript.new(data, RngSet.new(47115))
	_update_report_time()
	for id: String in ACTIVE_BUILDINGS:
		_feature.set_built(id, true)
	$Town.configure(data, resources)
	$Town/LootWorld.pickup_requested.connect(func(id):
		var result := _operations.pickup_drop(id)
		if not result.accepted: $Interface/MainHUD.action_result({"type": "pickup"}, result)
		$Town/LootWorld.render(_operations.snapshot()))
	$Town/HornWorld.open_requested.connect(func(): open_building(TownBattleHorn.BUILDING))
	$Town/HornWorld.chest_requested.connect(func():
		var result := _operations.horn_command({"action":"chest"})
		if result.accepted: result.message = "BOSS宝箱奖励已领取"
		$Interface/MainHUD.action_result({"type":"horn_chest"}, result))
	$Interface/RegionUI.configure(data,resources)
	$Town/RegionWorld.open_requested.connect(open_region)
	$Interface/RegionUI.closed.connect(func(): $Town.camera.set_map_input(true))
	$Interface/RegionUI.activation_requested.connect(_activate_region)
	$Town.render(_feature.snapshot())
	$Town.building_clicked.connect(open_building)
	$Town.hero_focus_requested.connect(select_hero)
	$Town.hero_trade_requested.connect(func(hero, building): open_building(building); $Interface/BuildingUI.select_buyer(hero))
	$Interface/BuildingUI.configure(resources, _operations.items(), _operations.recipes(), data.rows("town_buildings"))
	$Interface/BuildingUI/Stage/Horn.configure(resources, data)
	$Interface/BuildingUI/Stage/EquipmentShop.configure(resources,data,_operations.equipment_shop.definitions(),_operations.main_definitions())
	$Interface/BuildingUI.city_requested.connect(func():
		$Interface/BuildingUI.hide()
		$Interface/MainHUD.open_city()
		_resource_return = $Interface/BuildingUI.building)
	$Interface/BuildingUI.hero_requested.connect(func(id):
		$Interface/BuildingUI.hide()
		$Interface/MainHUD._detail("hero",{"hero":id,"order":_operations.snapshot().main.roster.map(func(h): return h.id)})
		_resource_return = $Interface/BuildingUI.building)
	$Interface/BuildingUI.dungeon_requested.connect(func(): $Interface/MainHUD.navigate("dungeon", false))
	$Interface/BuildingUI.intent.connect(_on_intent)
	$Interface/BuildingUI.closed.connect(func(): $Town.camera.set_map_input(true))
	$Interface/BuildingUI.resource_requested.connect(_open_building_resource)
	$Interface/HeroFocus.configure(resources)
	$Interface/HeroFocus.detail_requested.connect(_open_selected_hero)
	$Interface/MainHUD.configure(resources, _operations.main_definitions())
	$Interface/MainHUD.intent.connect(_on_main_intent)
	$Interface/MainHUD.hero_locate_requested.connect(func(id):
		var result := select_hero(id)
		if not result.accepted: $Interface/MainHUD.action_result({"type": "hero_locate"}, result))
	$Interface/MainHUD.map_occlusion_changed.connect(func(height):
		$Town.camera.obscured_bottom = height
		$Interface/HeroFocus.obscured_bottom = height)
	$Interface/MainHUD.overlay_changed.connect(func(opened):
		$Town.camera.set_map_input(not opened and not $Interface/BuildingUI.visible and not $Interface/RegionUI.visible)
		if opened: select_hero("")
		elif not _resource_return.is_empty():
			var id := _resource_return
			_resource_return = ""
			open_building(id))
	$Interface/MainHUD.render(_operations.snapshot())


func is_ready_for_use() -> bool:
	return boot_error.is_empty() and _feature != null


func town_snapshot() -> Dictionary:
	return _feature.snapshot() if _feature != null else {}


func set_building_appearance(id: String, built: bool) -> void:
	var result := _feature.set_built(id, built)
	if result.accepted:
		$Town.render(_feature.snapshot())


func operations_snapshot() -> Dictionary:
	return _operations.snapshot()


func open_region(area: String) -> void:
	select_hero("")
	$Interface/MainHUD.close()
	$Town.camera.set_map_input(false)
	$Interface/RegionUI.open(area,_operations.snapshot())

func _activate_region(command: Dictionary) -> void:
	var result := _operations.regions.activate(command)
	$Interface/RegionUI.action_result(result)
	if result.accepted:
		var nav := _operations._simulation.navigation
		var region: Dictionary = nav.regions[command.area]
		$Town.camera.go_to(nav.nearest(nav.point(Vector2i(region.center_x,region.center_y),command.area),command.area),0.9)

func open_building(id: String) -> void:
	if id == "building.5":
		$Interface/BuildingUI.hide()
		$Interface/MainHUD.open_city()
		return
	if id not in ACTIVE_BUILDINGS or not _feature.snapshot()[id]:
		return
	select_hero("")
	$Interface/MainHUD.close()
	$Town.camera.set_map_input(false)
	$Interface/BuildingUI.open(id, _operations.snapshot())


func select_hero(id: String) -> Dictionary:
	var result := _operations.select_hero(id)
	if result.accepted:
		var state := _operations.snapshot()
		$Town.render_actors(state)
		$Interface/HeroFocus.set_selected(not state.selected_hero.is_empty())
	return result


func _open_selected_hero() -> void:
	var state := _operations.snapshot()
	if state.selected_hero.is_empty():
		return
	$Interface/MainHUD.render(state)
	$Interface/MainHUD._detail("hero", {"hero": state.selected_hero, "order": state.main.roster.map(func(h): return h.id)})


func _open_building_resource(kind: String) -> void:
	var id: String = $Interface/BuildingUI.building
	$Interface/BuildingUI.hide()
	$Interface/MainHUD.open_resource(kind)
	_resource_return = id


func _on_main_intent(command: Dictionary) -> void:
	var result := _operations.main_command(command)
	$Interface/MainHUD.action_result(command, result)
	$Interface/MainHUD.render(_operations.snapshot())
	if result.accepted and command.type == "profile_sound":
		AudioServer.set_bus_mute(0, not _operations.snapshot().main.sound)


func _on_intent(command: Dictionary) -> void:
	var result := {"accepted": false, "reason": "无效操作"}
	match command.type:
		"produce": result = _operations.produce(command.building, command.material)
		"order": result = _operations.set_order(command.item, int(command.quantity))
		"craft": result = _operations.craft(command.item, int(command.quantity))
		"sale": result = _operations.sell_equipment(command.hero, int(command.serial))
		"upgrade": result = _operations.upgrade(command.building)
		"buy_seat": result = _operations.buy_seat(command.building, int(command.slot))
		"summon": result = _operations.summon(command.hero, command.building)
		"horn": result = _operations.horn_command(command)
		"equipment_shop": result = _operations.equipment_shop_command(command)
	$Interface/BuildingUI.action_result(command, result)
	$Interface/BuildingUI.render(_operations.snapshot())
	if result.get("started", false):
		$Interface/BuildingUI.close()
		$Town.camera.go_to(_operations.horn.encounter.origin, 0.9)


func _process(delta: float) -> void:
	if _operations == null:
		return
	_operations.advance(delta)
	var state := _operations.snapshot()
	$Town.render_actors(state)
	$Town/HornWorld.render(state)
	$Interface/HeroFocus.set_selected(not state.selected_hero.is_empty())
	_ui_clock += delta
	if _ui_clock >= 0.1:
		_ui_clock = 0.0
		_update_report_time()
		$Interface/RegionUI.render(state)
		$Interface/BuildingUI.render(state)
		$Interface/MainHUD.render(state)


func _update_report_time() -> void:
	_operations.set_report_time(Time.get_unix_time_from_system() + int(Time.get_time_zone_from_system().bias) * 60)
	_operations.horn.set_day(Time.get_unix_time_from_system() + 8 * 3600)
