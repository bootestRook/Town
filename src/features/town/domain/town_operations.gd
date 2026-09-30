class_name TownOperations
extends RefCounted
const LifeRules = preload("res://src/features/town/domain/town_life_rules.gd")
const Workshop = preload("res://src/features/town/domain/town_workshop.gd")
var _items: Dictionary = {}
var _services: Dictionary = {}
var _levels: Dictionary = {}
var _state: Dictionary
var _simulation := TownHeroSimulation.new()
var _workshop := Workshop.new()
var _clock := 0.0
var _main_systems := TownMainSystems.new()
var _equipment_rules := TownEquipmentRules.new()
var horn := TownBattleHorn.new()
var regions: TownRegionLevels
var equipment_shop := TownEquipmentShop.new()
func _init(data, rng: RngSet) -> void:
	for row: Dictionary in data.rows("town_items"):
		_items[row.id] = row
	for row: Dictionary in data.rows("town_loot_items"):
		if not _items.has(row.id): _items[row.id] = row
	for row: Dictionary in data.rows("town_services"):
		_services[row.id] = row
		_levels[row.id] = []
	for row: Dictionary in data.rows("town_service_levels"):
		_levels[row.building].append(row)
	for rows: Array in _levels.values():
		rows.sort_custom(func(a, b): return a.level < b.level)
	_state = {"coins": 60000, "diamonds": 1155, "purchased_seats": {}, "life_reports": {}, "city_level": 5, "exchange_level": 1, "inventory": {}, "orders": {}, "heroes": [], "report": [], "revision": 0, "buildings": {}, "equipment": [], "serial": 0}
	for id: String in _items:
		_state.inventory[id] = 0
	for id: String in _services:
		_state.buildings[id] = 5
		_state.purchased_seats[id] = []
		_state.life_reports[id] = {"total": 0, "bills": []}
		_state.inventory[_services[id].material] = 8
	for id: String in ["item.20206", "item.20302", "item.20304", "item.30206", "item.30306"]:
		_state.inventory[id] = 30
	_equipment_rules.configure(data, rng.stream("town.equipment"))
	_workshop.equipment_rules = _equipment_rules
	_main_systems.management.equipment_rules = _equipment_rules
	_workshop.configure(data.rows("town_equipment"))
	equipment_shop.configure(_state, data, rng.stream("town.equipment"))
	_main_systems.management.equipment_shop = equipment_shop
	_state.merge({"counts":{}, "selected_hero":""})
	_simulation.initialize(_state, data, _items, rng.stream("town.loot"), rng.stream("town.wander"), rng.stream("town.field"))
	_main_systems.initialize(_state, data, rng.stream("town.recruit"), rng.stream("town.collections"), rng.stream("town.expedition"))
	regions = _simulation.combat.regions
	_simulation.sync_deployment(_state)
	horn.initialize(_state, data, _simulation, rng.stream("town.horn"))
func snapshot() -> Dictionary:
	var result := _state.duplicate(true)
	result.main = _main_systems.snapshot(_state)
	result["camp"] = _main_systems.camp.snapshot(_state)
	result.merge({"horn":horn.snapshot(), "regions":regions.snapshot()}, true)
	result["frame_remainder"] = _clock
	result["services"] = _services.duplicate(true)
	result["details"] = {}
	for id: String in _services:
		result.details[id] = LifeRules.detail(_levels[id], int(_state.buildings[id]), _state.purchased_seats[id].size())
		result.details[id].merge({"price": service_price(id), "duration": service_duration(id), "recovery": 100 if _state.exchange_level == 1 else 80})
	return result
func main_definitions() -> Dictionary:
	return _main_systems.definitions()
func main_command(command: Dictionary) -> Dictionary:
	var result := _main_systems.command(_state, command)
	if result.accepted and command.get("type", "") in ["hero_team", "hero_quick_deploy", "hero_dispatch", "recruit", "hero_release"]:
		_simulation.sync_deployment(_state)
		equipment_shop.clean_calls(_state)
		if not _state.heroes.any(func(h): return h.id == _state.selected_hero): select_hero("")
	return result
func horn_command(command: Dictionary) -> Dictionary:
	return horn.command(command, self)
func pickup_drop(id: int) -> Dictionary: return _simulation.combat.loot.pickup(id, self)
func gain_hero_experience(id: String, amount: int) -> void: _main_systems.management.gain_experience(_state, id, amount)
func equipment_shop_command(command: Dictionary) -> Dictionary: return equipment_shop.command(_state, command, self)
func items() -> Array:
	return _items.values().duplicate(true)
func recipes() -> Array:
	return _workshop.recipes()
func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	_clock += seconds
	_main_systems.advance(_state, seconds)
	while _clock >= 0.05:
		_clock -= 0.05
		_simulation.step(_state, self, 0.05)
		for hero: Dictionary in _state.heroes:
			if hero.id == _state.selected_hero and not can_select_hero(hero):
				select_hero("")
static func can_select_hero(hero: Dictionary) -> bool:
	return hero.needs.hp > 0 and hero.mode not in ["serving", "reviving", "dead"]
func select_hero(id: String) -> Dictionary:
	if not id.is_empty() and not _state.heroes.any(func(hero): return hero.id == id and can_select_hero(hero)):
		return reject("英雄当前不可选中")
	_state.selected_hero = id
	return {"accepted": true}
func produce(building: String, material: String) -> Dictionary:
	if not _services.has(building) or material != _services[building].material:
		return reject("材料与配方不符")
	var recipe: Dictionary = _services[building]
	var count := int(_state.inventory[material]) / int(recipe.material_cost)
	if count < 1:
		return reject("原材料不足，可到交易所预购")
	_state.inventory[material] -= count * int(recipe.material_cost)
	_state.inventory[recipe.product] += count
	record("生产", "%s · %s ×%d" % [recipe.display_name, _items[recipe.product].display_name, count], 0)
	return {"accepted": true, "quantity": count}
func set_order(item: String, quantity: int) -> Dictionary:
	if not _items.has(item) or _items[item].order_limit <= 0 or _items[item].tier > _state.exchange_level:
		return reject("交易所等级不足或物品不可预购")
	if quantity < 0 or quantity > int(_items[item].order_limit):
		return reject("预购数量超出上限")
	if quantity == 0:
		_state.orders.erase(item)
	else:
		_state.orders[item] = quantity
	record("预购", "%s ×%d" % [_items[item].display_name, quantity], 0)
	return {"accepted": true}
func summon(hero_id: String, building: String = "building.7") -> Dictionary:
	for hero: Dictionary in _state.heroes:
		if hero.id == hero_id:
			if horn.active() and hero.id in _state.horn.participants: return reject("英雄正在BOSS战中")
			if not _state.main.battle.is_empty(): return reject("英雄正在战斗中")
			if not hero.deployed:
				return reject("该佣兵未出战")
			if hero.assigned_area == "town": return reject("该佣兵已派驻城镇")
			if hero.mode == "await_trade" and hero.target == building: return {"accepted":true}
			if not equipment_shop.shops.has(building): _state.equipment_shop.calls.erase(hero.id)
			else: _state.equipment_shop.calls[hero.id] = building
			if building == "building.7":
				hero.summoned = true
			elif building in ["building.6", "building.9", "building.10"]:
				hero.requested = building
			else:
				return reject("不能召唤到该建筑")
			select_hero("")
			return {"accepted": true}
	return reject("英雄不存在")
func upgrade(building: String) -> Dictionary:
	if equipment_shop.shops.has(building): return equipment_shop_command({"action":"upgrade","building":building})
	if building == TownBattleHorn.BUILDING: return horn.upgrade()
	if building == TownHeroCamp.BUILDING:
		var result := _main_systems.camp.upgrade(_state)
		if result.accepted: record("升级", "英雄营地升至 %d 级" % _state.buildings[building], -int(_main_systems.camp.levels[_state.buildings[building] - 1].cost))
		return result
	if building == "building.7":
		if _state.exchange_level >= 2:
			return reject("已开放当前全部材料")
		if _state.city_level < 4 or _state.coins < 1000:
			return reject("需要主城 4 级及 1000 金币")
		_state.coins -= 1000
		_state.exchange_level = 2
		record("交易所升级", "解锁二阶材料", -1000)
		return {"accepted": true}
	if not _services.has(building):
		return reject("建筑不支持此操作")
	var info := level_info(building)
	if _state.buildings[building] >= _levels[building].size():
		return reject("已达当前开放等级")
	if _state.city_level < int(info.city_level) or _state.coins < int(info.cost):
		return reject("金币或主城等级不足")
	_state.coins -= int(info.cost)
	_state.buildings[building] += 1
	record("升级", "%s升至 %d 级" % [_services[building].display_name, _state.buildings[building]], -int(info.cost))
	return {"accepted": true}
func level_info(building: String) -> Dictionary:
	return _levels[building][_state.buildings[building] - 1]
func service_price(building: String) -> int:
	return floori(snappedf(float(_items[_services[building].product].sell_price) * (1.0 + float(level_info(building).bonus)), 0.000001))
func service_capacity(building: String) -> int:
	return int(level_info(building).seats) + _state.purchased_seats[building].size()
func buy_seat(building: String, slot: int) -> Dictionary:
	var result := LifeRules.buy_seat(_state, _services, building, slot)
	if result.accepted:
		record("购买席位", "%s人数上限增加1" % _services[building].display_name, 0)
	return result
func set_report_time(unix_seconds: float) -> void:
	LifeRules.set_report_time(_state, unix_seconds)
func service_duration(building: String) -> float:
	return maxf(1.0, float(_services[building].service_seconds) - float(level_info(building).reduction))
func services() -> Dictionary:
	return _services.duplicate(true)
func has_trade(hero: Dictionary) -> bool:
	for id: String in _state.orders:
		if _state.orders[id] > 0 and hero.bag.get(id, 0) > 0:
			return true
	return false
func can_trade(hero: Dictionary) -> bool:
	for id: String in _state.orders:
		if hero.bag.get(id, 0) > 0 and _state.coins >= _items[id].buy_price:
			return true
	return false
func item_name(id: String) -> String:
	return _items[id].display_name
func service_available(hero: Dictionary, building: String) -> bool:
	return _state.inventory[_services[building].product] > 0 and hero.wallet >= service_price(building)
func settle_trade(hero: Dictionary) -> void:
	for id: String in _state.orders.keys():
		var price := int(_items[id].buy_price)
		var amount := mini(int(_state.orders[id]), int(hero.bag.get(id, 0)))
		amount = mini(amount, int(_state.coins) / price)
		if amount <= 0:
			continue
		var total := amount * price
		_state.coins -= total
		hero.wallet += total
		hero.bag[id] -= amount
		_state.inventory[id] += amount
		_state.orders[id] -= amount
		if _state.orders[id] == 0:
			_state.orders.erase(id)
		record("收购", "%s · %s ×%d" % [hero.name, _items[id].display_name, amount], -total)
func begin_service(hero: Dictionary, building: String) -> bool:
	var recipe: Dictionary = _services[building]
	var price := service_price(building)
	var accepted := LifeRules.begin_service(_state, hero, building, recipe, service_capacity(building), price, service_duration(building), _items[recipe.product].display_name)
	if accepted:
		record("消费", "%s · %s" % [hero.name, _items[recipe.product].display_name], price)
	return accepted
func finish_service(hero: Dictionary) -> void:
	var stat: String = _services[hero.target].stat
	hero.needs[stat] = minf(100.0, hero.needs[stat] + hero.recovery)
	record("使用完成", "%s · %s" % [hero.name, _services[hero.target].display_name], 0)
func craft(recipe: String, quantity: int) -> Dictionary:
	if equipment_shop.recipes.has(recipe): return equipment_shop.craft(_state, recipe, quantity, self)
	return _workshop.craft(_state, recipe, quantity, self)
func equipment_target(hero: Dictionary) -> String:
	return _workshop.find_target(_state, hero)
func has_equipment_offer(hero: Dictionary) -> bool:
	return _workshop.has_offer(_state, hero)
func sell_equipment(hero_id: String, serial: int) -> Dictionary:
	for hero: Dictionary in _state.heroes:
		if hero.id == hero_id:
			return _workshop.buy(_state, hero, serial, self)
	return reject("英雄不存在")
func record(kind: String, text: String, coins: int) -> void:
	_state.revision += 1
	_state.counts[kind] = _state.counts.get(kind, 0) + 1
	_state.report.push_front({"kind": kind, "text": text, "coins": coins})
	if _state.report.size() > 80:
		_state.report.pop_back()
static func reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
