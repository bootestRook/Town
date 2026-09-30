class_name TownEquipmentShop
extends RefCounted

const CAPACITY := 300
var shops: Dictionary = {}
var levels: Dictionary = {}
var recipes: Dictionary = {}
var equipment: Dictionary = {}
var affixes: Dictionary = {}
var _rng

func configure(state: Dictionary, data, rng) -> void:
	_rng = rng
	state.equipment_shop = {"calls":{}, "trading":"", "building":"", "locked":[], "purchased":[]}
	for row: Dictionary in data.rows("equipment_shops"):
		shops[row.id] = row
		state.buildings[row.id] = 1
		levels[row.id] = {}
	for row: Dictionary in data.rows("equipment_shop_levels"): levels[row.building][int(row.level)] = row
	for row: Dictionary in data.rows("equipment_shop_recipes"): recipes[row.id] = row
	for row: Dictionary in data.rows("equipment_shop_equipment"): equipment[row.id] = row
	for row: Dictionary in data.rows("equipment_shop_affixes"):
		if not affixes.has(row.equipment): affixes[row.equipment] = {}
		if not affixes[row.equipment].has(int(row.slot)): affixes[row.equipment][int(row.slot)] = []
		affixes[row.equipment][int(row.slot)].append(row)

func definitions() -> Dictionary:
	return {"shops":shops.duplicate(true), "levels":levels.duplicate(true), "recipes":recipes.duplicate(true), "equipment":equipment.duplicate(true)}

func stock(state: Dictionary, building: String) -> Array:
	return state.equipment.filter(func(e): return e.building == building)

func maximum(state: Dictionary, recipe: Dictionary) -> int:
	var count := mini(10, CAPACITY - stock(state, recipe.building).size())
	if recipe.tier > levels[recipe.building][state.buildings[recipe.building]].tier: return 0
	if not recipe.one_use and recipe.unlock_level > state.buildings[recipe.building]: return 0
	for id: int in TownMainInventory.entries(recipe.cost):
		count = mini(count, TownMainInventory.count(state, id) / TownMainInventory.entries(recipe.cost)[id])
	if recipe.one_use: count = mini(count, TownMainInventory.count(state, recipe.source_id))
	return count

func craft(state: Dictionary, id: String, count: int, owner) -> Dictionary:
	if not recipes.has(id) or count < 1 or count > 10: return TownOperations.reject("打造数量须为1至10")
	var recipe: Dictionary = recipes[id]
	if recipe.tier > levels[recipe.building][state.buildings[recipe.building]].tier or recipe.unlock_level > state.buildings[recipe.building]: return TownOperations.reject("店铺等级不足")
	if count > CAPACITY - stock(state, recipe.building).size(): return TownOperations.reject("货架已满")
	if count > maximum(state, recipe): return TownOperations.reject("材料或一次性图纸不足")
	for item: int in TownMainInventory.entries(recipe.cost): TownMainInventory.add(state, item, -TownMainInventory.entries(recipe.cost)[item] * count)
	if recipe.one_use: TownMainInventory.add(state, recipe.source_id, -count)
	var created: Array = []
	for i in count:
		state.serial += 1
		var item: Dictionary = equipment[recipe.equipment].duplicate(true)
		item.serial = state.serial
		item.affixes = []
		for slot: int in affixes[item.id]:
			var pool: Array = affixes[item.id][slot]
			var weight := 0
			for a: Dictionary in pool: weight += a.weight
			var roll: int = _rng.next_int(weight)
			for a: Dictionary in pool:
				roll -= a.weight
				if roll < 0:
					item.affixes.append({"id":a.source_id, "effect":a.effect, "value":a.minimum + _rng.next_int(a.maximum - a.minimum + 1), "label":a.label, "percent":a.percent})
					break
		state.equipment.append(item)
		created.append(item.serial)
	owner.record("打造", "%s ×%d" % [recipe.display_name, count], 0)
	return {"accepted":true, "quantity":count, "created":created}

func command(state: Dictionary, command: Dictionary, owner) -> Dictionary:
	var building := String(command.get("building", ""))
	if not shops.has(building): return TownOperations.reject("装备店不存在")
	match command.get("action", ""):
		"craft":
			if recipes.get(command.get("recipe", ""), {}).get("building", "") != building: return TownOperations.reject("配方不属于该店铺")
			return craft(state, command.get("recipe", ""), int(command.get("count", 0)), owner)
		"upgrade":
			var level: int = state.buildings[building]
			if level >= levels[building].size(): return TownOperations.reject("已达最高等级")
			var rule: Dictionary = levels[building][level]
			if state.city_level < rule.city: return TownOperations.reject("主城等级不足")
			if state.coins < rule.cost: return TownOperations.reject("金币不足")
			state.coins -= rule.cost
			state.buildings[building] += 1
			owner.record("升级", "%s升至%d级" % [shops[building].display_name,state.buildings[building]], -rule.cost)
		"resolve":
			var ids: Array = command.get("serials", [])
			var unique := {}
			for id in ids: unique[id] = true
			if ids.is_empty() or ids.size() != unique.size(): return TownOperations.reject("请选择有效装备")
			var selected: Array = stock(state, building).filter(func(e): return e.serial in ids)
			if selected.size() != ids.size() or selected.any(func(e): return e.serial in state.equipment_shop.locked): return TownOperations.reject("装备不存在或已锁定")
			var rewards := {}
			for item: Dictionary in selected:
				for id: int in TownMainInventory.entries(equipment[item.id].resolve): rewards[id] = rewards.get(id,0) + TownMainInventory.entries(equipment[item.id].resolve)[id]
			for id: int in rewards: TownMainInventory.add(state,id,rewards[id])
			for item: Dictionary in selected: state.equipment.erase(item)
			owner.record("分解", "分解%d件装备" % selected.size(), 0)
			return {"accepted":true, "rewards":rewards}
		"lock":
			var serial := int(command.get("serial",-1))
			if not stock(state, building).any(func(e): return e.serial == serial): return TownOperations.reject("装备不存在")
			if serial in state.equipment_shop.locked: state.equipment_shop.locked.erase(serial)
			else: state.equipment_shop.locked.append(serial)
		"open_trade":
			var id := String(command.get("hero", ""))
			var found: Array = state.heroes.filter(func(h): return h.id == id and h.mode == "await_trade" and h.target == building)
			if found.is_empty(): return TownOperations.reject("英雄尚未到店")
			if not state.equipment_shop.trading.is_empty() and state.equipment_shop.trading != id: return TownOperations.reject("请先结束当前交易")
			if state.equipment_shop.trading != id: state.equipment_shop.purchased = []
			state.equipment_shop.trading = id
			state.equipment_shop.building = building
		"close_trade":
			if state.equipment_shop.building != building: return TownOperations.reject("交易目标不符")
			for hero: Dictionary in state.heroes:
				if hero.id != state.equipment_shop.trading: continue
				state.equipment_shop.calls.erase(hero.id)
				hero.requested = ""
				if hero.mode == "await_trade": hero.mode = "shopping_done"; hero.skip_shopping = 45.0
			state.equipment_shop.trading = ""
			state.equipment_shop.purchased = []
			state.equipment_shop.building = ""
		"donate":
			if state.equipment_shop.building != building: return TownOperations.reject("交易目标不符")
			if not str(command.get("amount","")).is_valid_int(): return TownOperations.reject("请输入正整数金币数量")
			var amount := int(command.get("amount",0))
			var found: Array = state.heroes.filter(func(h): return h.id == state.equipment_shop.trading)
			if found.is_empty() or amount <= 0 or amount > state.coins: return TownOperations.reject("赠送金币数量无效")
			state.coins -= amount
			found[0].wallet += amount
			owner.record("赠送金币", found[0].name, -amount)
		_: return TownOperations.reject("无效操作")
	return {"accepted":true}

func clean_calls(state: Dictionary) -> void:
	var available: Array = state.heroes.filter(func(h): return h.deployed and h.assigned_area != "town").map(func(h): return h.id)
	for id: String in state.equipment_shop.calls.keys():
		if id not in available: state.equipment_shop.calls.erase(id)
	if state.equipment_shop.trading not in available:
		state.equipment_shop.trading = ""
		state.equipment_shop.purchased = []
		state.equipment_shop.building = ""

static func rating(item: Dictionary, level: int, definitions: Dictionary) -> int:
	for recipe: Dictionary in definitions.recipes.values():
		if recipe.building != item.building or recipe.one_use or recipe.unlock_level != level: continue
		if recipe.slot == item.slot and recipe.job == item.job and definitions.equipment[recipe.equipment].power > item.power: return 1
	return 3
