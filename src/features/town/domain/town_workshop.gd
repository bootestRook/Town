class_name TownWorkshop
extends RefCounted

var _recipes: Dictionary = {}
var equipment_rules: TownEquipmentRules


func configure(rows: Array) -> void:
	for row: Dictionary in rows:
		_recipes[row.id] = row.duplicate(true)


func recipes() -> Array:
	return _recipes.values().duplicate(true)


func craft(state: Dictionary, recipe: String, count: int, owner) -> Dictionary:
	if not _recipes.has(recipe) or count < 1 or count > 10:
		return owner.reject("打造数量须为 1 至 10")
	if state.equipment.size() + count > 150:
		return owner.reject("装备仓库已满")
	var row: Dictionary = _recipes[recipe]
	if state.inventory[row.material_a] < row.count_a * count or state.inventory[row.material_b] < row.count_b * count:
		return owner.reject("材料不足，可到交易所预购")
	state.inventory[row.material_a] -= row.count_a * count
	state.inventory[row.material_b] -= row.count_b * count
	for i in count:
		state.serial += 1
		var item := equipment_rules.create(row, state.serial)
		state.equipment.append(item)
	owner.record("打造", "%s ×%d" % [row.display_name, count], 0)
	return {"accepted": true, "quantity": count}


func _suitable(item: Dictionary, hero: Dictionary) -> bool:
	return (item.job == 0 or item.job == hero.job) and item.power > hero.equipment.get(str(int(item.slot)), {}).get("power", 0) and hero.wallet >= item.price


func find_target(state: Dictionary, hero: Dictionary) -> String:
	for item: Dictionary in state.equipment:
		if item.serial not in state.equipment_shop.locked and _suitable(item, hero):
			return item.building
	return ""


func has_offer(state: Dictionary, hero: Dictionary) -> bool:
	return state.equipment.any(func(item): return item.serial not in state.equipment_shop.locked and item.building == hero.target and _suitable(item, hero))


func buy(state: Dictionary, hero: Dictionary, serial: int, owner) -> Dictionary:
	for i in range(state.equipment.size() - 1, -1, -1):
		var item: Dictionary = state.equipment[i]
		if int(item.serial) != serial:
			continue
		if hero.mode != "await_trade" or item.building != hero.target:
			return owner.reject("英雄尚未到店")
		if item.serial in state.equipment_shop.locked: return owner.reject("装备已锁定")
		if state.equipment_shop.trading == hero.id and str(int(item.slot)) in state.equipment_shop.purchased: return owner.reject("本次已交易，请重新召唤")
		if not _suitable(item, hero):
			return owner.reject("职业不符、金币不足或装备没有提升")
		hero.wallet -= int(item.price)
		state.coins += int(item.price)
		var slot := str(int(item.slot))
		if hero.equipment.has(slot):
			hero.retired.append(hero.equipment[slot])
		hero.equipment[slot] = item
		state.equipment.remove_at(i)
		TownHeroStats.refresh(hero)
		owner.record("出售装备", "%s · 装备%s" % [hero.name, item.display_name], int(item.price))
		if state.equipment_shop.trading != hero.id: hero.mode = "shopping_done"
		else: state.equipment_shop.purchased.append(slot)
		state.equipment_shop.calls.erase(hero.id)
		return {"accepted": true}
	return owner.reject("装备已售出或不存在")
