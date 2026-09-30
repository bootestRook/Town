class_name TownHeroManagement
extends RefCounted

var definitions: Dictionary = {}
var talents: Dictionary = {}
var experience_levels: Dictionary = {}
var collections: TownCollections
var equipment_rules: TownEquipmentRules
var equipment_shop: TownEquipmentShop

func roster(state: Dictionary) -> Array:
	var result: Array = []
	for entry: Dictionary in state.main.roster:
		var row := entry.duplicate(true)
		var definition: Dictionary = definitions[row.definition]
		var talent: Dictionary = talents[row.talent]
		var live := _live(state, row.live)
		row["deployed"] = row.id in state.main.team
		row["initially_owned"] = live.base.initially_owned
		row["town_status"] = live.reason
		row["wallet"] = live.wallet
		row["experience"] = live.experience
		row["experience_required"] = experience_levels[mini(100, row.level)]
		row["needs"] = live.needs.duplicate(true)
		row["bag"] = live.bag.duplicate(true)
		row["magic_capacity"] = TownHeroNeeds.MAGIC_CAPACITY
		row["can_star"] = talent.next_id != 0
		row.merge({"job": definition.job, "quality": definition.quality, "portrait": definition.resource_id, "max_level": talent.max_level, "fragments": state.main.fragments.get(row.definition, 0), "fragment_cost": talent.fragment_count, "upgrade_cost": row.level * 200, "skills": talent.skills})
		row["stats"] = live.stats.duplicate(true)
		row["equipment"] = live.equipment.duplicate(true)
		row["power"] = power(row.stats)
		row["combat"] = {}
		row["pet_skills"] = collections.pet_skills(state, row.id)
		for key: String in ["hit", "dodge", "critical", "bonus", "toughness", "blood", "hurt", "reduction", "element", "frequency"]: row.combat[key] = definition[key]
		row.combat.dodge += TownEquipmentRules.total(row.equipment, "dodge_up")
		result.append(row)
	return result

static func power(stats: Dictionary) -> int:
	return roundi(stats.max_hp * 0.01 + stats.attack + stats.defense * 0.5)

func gain_experience(state: Dictionary, id: String, amount: int) -> void:
	if amount <= 0: return
	for entry: Dictionary in state.main.roster:
		if entry.id != id: continue
		var live := _live(state, entry.live)
		var cap := mini(100, int(talents[entry.talent].max_level))
		live.experience += amount
		while entry.level < cap and live.experience >= int(experience_levels[entry.level]):
			live.experience -= int(experience_levels[entry.level])
			_level_up(entry, live)
		if entry.level >= cap: live.experience = mini(live.experience, int(experience_levels[cap]))
		return

func _level_up(entry: Dictionary, live: Dictionary) -> void:
	var definition: Dictionary = definitions[entry.definition]
	entry.level += 1
	live.level = entry.level
	live.base.max_hp += definition.hp_growth
	live.base.attack += definition.attack_growth
	live.base.defense += definition.defense_growth
	TownHeroStats.refresh(live)

func command(state: Dictionary, command: Dictionary) -> Dictionary:
	var found: Array = state.main.roster.filter(func(h): return h.id == command.get("hero", ""))
	if found.is_empty(): return TownOperations.reject("英雄不存在")
	var hero: Dictionary = found[0]
	var definition: Dictionary = definitions[hero.definition]
	var talent: Dictionary = talents[hero.talent]
	var live := _live(state, hero.live)
	match command.type:
		"hero_donate":
			var value := str(command.get("amount", ""))
			if not value.is_valid_int(): return TownOperations.reject("请输入正整数金币数量")
			var amount := value.to_int()
			if amount <= 0: return TownOperations.reject("请输入正整数金币数量")
			if amount > state.coins: return TownOperations.reject("公共金币不足")
			state.coins -= amount
			live.wallet += amount
		"hero_level":
			var cap: int = talent.max_level
			var cost: int = hero.level * 200
			if hero.level >= cap: return TownOperations.reject("请先升星提高等级上限")
			if state.coins < cost: return TownOperations.reject("金币不足")
			state.coins -= cost
			_level_up(hero, live)
		"hero_star":
			var cost: int = talent.fragment_count
			if talent.next_id == 0 or not talents.has(talent.next_id): return TownOperations.reject("英雄已满星")
			if state.main.fragments.get(hero.definition, 0) < cost: return TownOperations.reject("灵魂石不足")
			state.main.fragments[hero.definition] -= cost
			var next: Dictionary = talents[talent.next_id]
			hero.talent = next.source_id
			hero.star = next.star
			live.base.max_hp += next.hp - talent.hp
			live.base.attack += next.attack - talent.attack
			live.base.defense += next.defense - talent.defense
			TownHeroStats.refresh(live)
		"hero_lock": hero.locked = not hero.locked
		"hero_equip":
			if not state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能更换装备")
			var equipment: Array = state.equipment.filter(func(e): return e.serial == int(command.get("serial", -1)))
			if equipment.is_empty() or int(equipment[0].job) not in [0, int(definition.job)]: return TownOperations.reject("装备不存在或职业不符")
			var item: Dictionary = equipment[0]
			var target: Dictionary = live.equipment
			var slot := str(int(item.slot))
			state.equipment.erase(item)
			if target.has(slot): state.equipment.append(target[slot])
			target[slot] = item
			TownHeroStats.refresh(live)
		"hero_equipment_buyback":
			if not state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能更换装备")
			var target: Dictionary = live.equipment
			var slot := String(command.get("slot", ""))
			if not target.has(slot) or target[slot].serial != int(command.get("serial", -1)): return TownOperations.reject("装备已变更，请重新打开详情")
			var cost: int = equipment_rules.definitions[target[slot].id].buyback
			var limit := TownEquipmentShop.CAPACITY if equipment_shop.shops.has(target[slot].building) else 150
			if state.equipment.filter(func(e): return e.building == target[slot].building).size() >= limit: return TownOperations.reject("装备仓库已满")
			if state.diamonds < cost: return TownOperations.reject("钻石不足")
			state.diamonds -= cost
			state.equipment.append(target[slot])
			target.erase(slot)
			TownHeroStats.refresh(live)
			return {"accepted": true, "message": "装备已回购至仓库"}
		"hero_equipment_refine":
			var target: Dictionary = live.equipment
			var slot := String(command.get("slot", ""))
			if not target.has(slot) or target[slot].serial != int(command.get("serial", -1)): return TownOperations.reject("装备已变更，请重新打开详情")
			# All obtainable recipes are below the source gate; c9_lang 40014003.
			return TownOperations.reject("仅限金色、红色品质的装备可以洗练")
		"hero_release":
			if live.base.initially_owned: return TownOperations.reject("请保留初始佣兵")
			if hero.locked: return TownOperations.reject("请先解除英雄锁定")
			if not state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能遣散英雄")
			if hero.id in state.main.team: return TownOperations.reject("请先撤下英雄")
			if live.mode in ["serving", "reviving", "dead"]: return TownOperations.reject("请等待英雄完成当前服务或复活")
			for item: Dictionary in live.equipment.values(): state.equipment.append(item)
			state.main.team.erase(hero.id)
			state.main.expedition_team.erase(hero.id)
			for object: Dictionary in state.main.collections:
				if object.hero == hero.id: object.hero = ""
			state.main.roster.erase(hero)
			state.main.fragments[hero.definition] = state.main.fragments.get(hero.definition, 0) + definition.fragment_count
		_:
			return TownOperations.reject("无效英雄操作")
	return {"accepted": true}

func _live(state: Dictionary, id: String) -> Dictionary:
	for hero: Dictionary in state.heroes:
		if hero.id == id: return hero
	assert(false, "Every owned hero must have a map actor")
	return {}
