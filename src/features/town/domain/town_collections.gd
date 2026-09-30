class_name TownCollections
extends RefCounted

var pets: Dictionary = {}
var pet_levels: Dictionary = {}
var artifacts: Dictionary = {}
var artifact_levels: Dictionary = {}
var qualities: Dictionary = {}
var uses: Dictionary = {}
var _fragment_owners: Dictionary = {}
var _rng

func configure(data, rng) -> void:
	_rng = rng
	for row: Dictionary in data.rows("main_heroes"): _fragment_owners[int(row.fragment)] = row.id
	for pair: Array in [["main_pets", pets], ["main_pet_levels", pet_levels], ["main_artifacts", artifacts], ["main_artifact_levels", artifact_levels], ["main_artifact_qualities", qualities], ["main_item_uses", uses]]:
		for row: Dictionary in data.rows(pair[0]): pair[1][int(row.source_id)] = row.duplicate(true)

func initialize(main: Dictionary) -> void:
	main["collections"] = []
	main["collection_serial"] = 0

func definitions() -> Dictionary:
	return {"pets": pets.duplicate(true), "artifacts": artifacts.duplicate(true), "uses": uses.duplicate(true)}

func snapshot(state: Dictionary) -> Array:
	var result: Array = []
	for object: Dictionary in state.main.collections:
		var row := object.duplicate(true)
		var definition := definition_for(object)
		row.merge({"name": definition.display_name, "portrait": definition.resource_id, "stats": stats(object), "cost": level_cost(object), "max_level": definition.max_level if object.kind == "pet" else artifact_levels.size(), "star": definition.star if object.kind == "pet" else 0, "description": definition.description if object.kind == "pet" else "成长值 %d" % object.growth})
		result.append(row)
	return result

func definition_for(object: Dictionary) -> Dictionary:
	return pets[object.definition] if object.kind == "pet" else artifacts[object.definition]

func stats(object: Dictionary) -> Dictionary:
	var result := {"max_hp": 0.0, "attack": 0.0, "defense": 0.0}
	if object.kind == "pet":
		var row: Dictionary = pet_levels[object.level]
		var prefix := "gold_" if object.quality == 5 else ""
		result = {"max_hp": row[prefix + "hp"], "attack": row[prefix + "attack"], "defense": row[prefix + "defense"]}
	else:
		var row: Dictionary = artifact_levels[object.level]
		var attributes := TownMainInventory.entries(row.gold_stats if object.quality == 4 else row.stats)
		result = {"max_hp": attributes[1], "attack": attributes[5], "defense": attributes[7]}
	return result

func bonus(state: Dictionary, hero: String) -> Dictionary:
	var result := {"max_hp": 0.0, "attack": 0.0, "defense": 0.0}
	for object: Dictionary in state.main.collections:
		if object.hero != hero: continue
		var values := stats(object)
		for key: String in values: result[key] += values[key]
	return result

func pet_skills(state: Dictionary, hero: String) -> String:
	for object: Dictionary in state.main.collections:
		if object.hero == hero and object.kind == "pet": return pets[object.definition].skills
	return ""

func level_cost(object: Dictionary) -> String:
	var row: Dictionary = pet_levels[object.level] if object.kind == "pet" else artifact_levels[object.level]
	return row.gold_cost if object.quality == (5 if object.kind == "pet" else 4) else row.cost

func refund(object: Dictionary) -> String:
	var row: Dictionary = pet_levels[object.level] if object.kind == "pet" else artifact_levels[object.level]
	return row.gold_refund if object.quality == (5 if object.kind == "pet" else 4) else row.refund

func command(state: Dictionary, command: Dictionary) -> Dictionary:
	if not state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能调整宠物和神器")
	if command.type == "item_use": return _use(state, int(command.get("item", 0)))
	var matches: Array = state.main.collections.filter(func(o): return o.id == int(command.get("object", 0)))
	if matches.is_empty(): return TownOperations.reject("物品不存在")
	var object: Dictionary = matches[0]
	var definition := definition_for(object)
	match command.type:
		"collection_equip":
			var heroes: Array = state.main.roster.filter(func(h): return h.id == command.get("hero", ""))
			if heroes.is_empty(): return TownOperations.reject("英雄不存在")
			if not object.hero.is_empty() and object.hero != heroes[0].id: return TownOperations.reject("请先从原英雄卸下")
			for old: Dictionary in state.main.collections:
				if old.hero == heroes[0].id and old.kind == object.kind: old.hero = ""
			object.hero = heroes[0].id
		"collection_unequip": object.hero = ""
		"collection_lock": object.locked = not object.locked
		"collection_level":
			var cap: int = definition.max_level if object.kind == "pet" else artifact_levels.size()
			if object.level >= cap: return TownOperations.reject("已达等级上限")
			if object.kind == "pet" and state.city_level < pet_levels[object.level].city_level: return TownOperations.reject("主城等级不足")
			if not TownMainInventory.spend(state, level_cost(object)): return TownOperations.reject("升级材料不足")
			object.level += 1
		"collection_star":
			if object.kind != "pet" or definition.next_id == 0: return TownOperations.reject("已达星级上限")
			var candidates: Array = state.main.collections.filter(func(o): return o.kind == "pet" and o.id != object.id and o.definition == definition.consume and o.hero.is_empty() and not o.locked)
			if candidates.size() < definition.count: return TownOperations.reject("缺少同星级的空闲宠物")
			candidates.sort_custom(func(a,b): return a.level < b.level)
			for material: Dictionary in candidates.slice(0, definition.count):
				TownMainInventory.grant(state, refund(material))
				state.main.collections.erase(material)
			object.definition = int(definition.next_id)
		"collection_reset":
			if object.level <= 1: return TownOperations.reject("已经是一级")
			TownMainInventory.grant(state, refund(object))
			object.level = 1
		"collection_dismantle":
			if object.locked or not object.hero.is_empty(): return TownOperations.reject("请先卸下并解除锁定")
			TownMainInventory.grant(state, refund(object))
			TownMainInventory.grant(state, definition.dismantle if object.kind == "pet" else qualities[object.quality].dismantle)
			state.main.collections.erase(object)
		_:
			return TownOperations.reject("无效物品操作")
	_sync(state)
	return {"accepted": true}

func _use(state: Dictionary, id: int) -> Dictionary:
	if not uses.has(id) or TownMainInventory.count(state, id) <= 0: return TownOperations.reject("没有可使用的道具")
	var item: Dictionary = uses[id]
	var definition := 0
	var amount := 1
	match int(item.kind):
		30:
			definition = _weighted(item.value, ":", 1, 0)
			if not pets.has(definition): return TownOperations.reject("宠物配置不存在")
		36:
			definition = _weighted(item.value, ",", 0, 2)
			if not artifacts.has(definition): return TownOperations.reject("神器配置不存在")
		39:
			amount = int(item.amount)
			if amount <= 0 or TownMainInventory.count(state, id) < amount: return TownOperations.reject("碎片数量不足")
		6:
			definition = _weighted(item.value, ":", 1, 0)
			if not _fragment_owners.has(definition): return TownOperations.reject("英雄灵魂石配置不存在")
	TownMainInventory.add(state, id, -amount)
	match int(item.kind):
		30: _create(state.main, "pet", definition)
		36: _create(state.main, "artifact", definition)
		22: state.main.energy += int(item.amount)
		39:
			var values := String(item.value).split(",")
			TownMainInventory.add(state, int(values[0]), int(values[1]))
		6:
			var hero: String = _fragment_owners[definition]
			state.main.fragments[hero] = state.main.fragments.get(hero, 0) + int(item.amount)
	return {"accepted": true, "message": "已使用" + item.display_name}

func _create(main: Dictionary, kind: String, id: int) -> void:
	var definition: Dictionary = pets[id] if kind == "pet" else artifacts[id]
	var quality := int(definition.quality) if kind == "pet" else 1
	var growth := 0
	if kind == "artifact":
		growth = definition.growth_min + _rng.next_int(definition.growth_max - definition.growth_min + 1)
		for row: Dictionary in qualities.values():
			if growth >= row.growth_min and growth <= row.growth_max: quality = int(row.source_id)
	main.collection_serial += 1
	main.collections.append({"id": main.collection_serial, "definition": id, "kind": kind, "level": 1, "quality": quality, "growth": growth, "hero": "", "locked": false})

func _weighted(value: String, separator: String, id_index: int, weight_index: int) -> int:
	var choices: Array = []
	var total := 0
	for token: String in value.split(";"):
		var parts := token.split(separator)
		var weight := int(parts[weight_index])
		choices.append([int(parts[id_index]), weight])
		total += weight
	var draw: int = _rng.next_int(total)
	for choice: Array in choices:
		draw -= choice[1]
		if draw < 0: return choice[0]
	return 0

func _sync(state: Dictionary) -> void:
	for hero: Dictionary in state.heroes:
		hero.collection_bonus = bonus(state, hero.id)
		TownHeroStats.refresh(hero)
		hero.needs.hp = minf(hero.needs.hp, hero.stats.max_hp)
