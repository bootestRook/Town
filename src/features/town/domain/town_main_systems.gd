class_name TownMainSystems
extends RefCounted

var recruitment := TownRecruitment.new()
var management := TownHeroManagement.new()
var expedition := TownExpedition.new()
var salvage := TownSalvage.new()
var collections := TownCollections.new()
var gift_shop := TownMainShop.new()
var _purchase: Array = []
var diamond_shop := TownDiamondShop.new()
var _modes: Array = []
var _city: Dictionary = {}
var _items: Dictionary = {}
var _star_display: Dictionary = {}
var _skill_art: Dictionary = {}
var _hero_idle: Dictionary = {}
var _bag_items: Dictionary = {}
var _hero_catalog: Dictionary = {}
var deployment := TownHeroDeployment.new()
var dispatch := TownMapDispatch.new()
var camp := TownHeroCamp.new()

func initialize(state: Dictionary, data, rng, collection_rng, battle_rng) -> void:
	recruitment.configure(data, rng)
	collections.configure(data, collection_rng)
	gift_shop.configure(data)
	management.collections = collections
	management.definitions = recruitment.definitions
	for row: Dictionary in data.rows("town_hero_levels"): management.experience_levels[int(row.level)] = int(row.experience)
	camp.initialize(state, data)
	dispatch.configure(data)
	deployment.camp = camp
	for row: Dictionary in data.rows("main_hero_catalog"): _hero_catalog[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("main_star_display"): _star_display[row.stage] = row.duplicate(true)
	for row: Dictionary in data.rows("main_skill_art"): _skill_art[int(row.source_id)] = row.resource_id
	for row: Dictionary in data.rows("main_hero_idle"): _hero_idle[int(row.appearance)] = row.duplicate(true)
	for row: Dictionary in data.rows("town_items"): _bag_items[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("town_loot_items"):
		if not _bag_items.has(row.id): _bag_items[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("main_talents"): management.talents[row.source_id] = row.duplicate(true)
	expedition.configure(data, battle_rng)
	salvage.configure(data)
	_purchase = data.rows("main_purchase").duplicate(true)
	_modes = data.rows("main_modes").duplicate(true)
	_modes.sort_custom(func(a,b): return a.order < b.order)
	for row: Dictionary in data.rows("main_city"): _city[int(row.source_id)] = row.duplicate(true)
	for row: Dictionary in data.rows("main_items"): _items[int(row.source_id)] = row.display_name
	diamond_shop.configure(data)
	state["main"] = {"player_name": "小镇镇长", "avatar": "main_ui.avatar", "energy": 1100, "day_time": 8.0 * 3600, "daily": {}, "claimed_energy": [], "roster": [], "team": [], "fragments": {}, "pool": [], "recruited": [], "refresh_remaining": 0.0, "recruit_level": 1, "recruit_exp": 0, "last_recruit": "", "progress": {}, "battle": {}, "battle_speed": 1, "sound": true, "orders": [], "order_serial": 0, "diamond_purchases": {}}
	for hero: Dictionary in state.heroes:
		var matches := recruitment.definitions.values().filter(func(d): return d.appearance == hero.base.source_appearance)
		assert(not matches.is_empty(), "Initial hero must have source recruit identity")
		state.main.roster.append({"id": hero.id, "definition": matches[0].id, "talent": matches[0].source_id, "name": hero.name, "level": hero.level, "star": matches[0].star, "locked": false, "live": hero.id, "assigned_area": "field"})
		if state.main.team.size() < 3:
			state.main.team.append(hero.id)
	recruitment.initialize(state)
	state.main["expedition_team"] = state.main.team.duplicate()
	salvage.initialize(state.main)
	collections.initialize(state.main)
	state.main["day"] = 0

func definitions() -> Dictionary:
	var result := {"heroes": recruitment.definitions.duplicate(true), "levels": expedition.levels.duplicate(true), "encounters": expedition.encounters.duplicate(true), "enemies": expedition.enemies.duplicate(true), "skills": expedition.skills.descriptions(), "modes": _modes.duplicate(true), "shop": diamond_shop.products.values().duplicate(true), "sea": salvage.sites.duplicate(true), "sea_rewards": salvage.rewards.duplicate(true), "city": _city.duplicate(true), "items": _items.duplicate(), "recruit_levels": recruitment.levels.duplicate(true)}
	result["recruit_rules"] = recruitment.rules.duplicate(true)
	result.merge(collections.definitions())
	result["star_display"] = _star_display.duplicate(true)
	result["skill_art"] = _skill_art.duplicate()
	result["hero_idle"] = _hero_idle.duplicate(true)
	result["bag_items"] = _bag_items.duplicate(true)
	result["equipment_rules"] = management.equipment_rules.definitions.duplicate(true)
	result["battle_gates"] = expedition.loot.gates.duplicate(true)
	result["hero_catalog"] = _hero_catalog.duplicate(true)
	result["hero_talents"] = management.talents.duplicate(true)
	return result

func snapshot(state: Dictionary) -> Dictionary:
	var main: Dictionary = state.main.duplicate(true)
	main.roster = management.roster(state)
	main["dispatch"] = dispatch.snapshot(state)
	main["map_capacity"] = state.heroes.size()
	main["deployment_capacity"] = deployment.capacity(state)
	main.collections = collections.snapshot(state)
	main["gifts"] = gift_shop.visible_gifts(state).duplicate(true)
	main["power"] = 0
	for hero: Dictionary in main.roster: main.power += hero.power
	main["energy_max"] = purchase(state, "energy").capacity
	main["coin_offer"] = purchase(state, "coins").duplicate(true)
	main["energy_offer"] = purchase(state, "energy").duplicate(true)
	main["recruitment"] = recruitment.snapshot(state)
	main["recruit_required"] = recruitment.levels[mini(main.recruit_level - 1, recruitment.levels.size() - 1)].experience
	main["energy_claimable"] = _energy_slot(state) >= 0
	return main

func advance(state: Dictionary, seconds: float) -> void:
	var main: Dictionary = state.main
	recruitment.advance(state, seconds)
	main.day_time += seconds
	if main.day_time >= 86400:
		main.day += int(main.day_time / 86400)
		main.day_time = fmod(main.day_time, 86400)
		main.daily.clear()
		main.claimed_energy.clear()
	expedition.advance(state, seconds)
	salvage.advance(state, seconds)

func purchase(state: Dictionary, kind: String) -> Dictionary:
	var options := _purchase.filter(func(d): return d.kind == kind and d.city_level == state.city_level)
	var step: int = mini(state.main.daily.get(kind, 0), options.size() - 1)
	return options[step]

func command(state: Dictionary, command: Dictionary) -> Dictionary:
	var main: Dictionary = state.main
	var kind := String(command.get("type", ""))
	if kind == "dispatch_preview": return dispatch.preview(state, command, management.roster(state))
	if kind == "hero_dispatch": return dispatch.commit(state, command, management.roster(state))
	if kind in ["hero_team", "hero_quick_deploy"]: return deployment.command(state, command, management.roster(state))
	if kind == "expedition_team":
		if not main.battle.is_empty(): return TownOperations.reject("战斗期间不能调整队伍")
		var id := String(command.get("hero", ""))
		if not main.roster.any(func(h): return h.id == id): return TownOperations.reject("英雄不存在")
		if id in main.expedition_team: main.expedition_team.erase(id)
		elif main.expedition_team.size() < 5: main.expedition_team.append(id)
		else: return TownOperations.reject("队伍最多出战五名英雄")
		return {"accepted": true}
	if kind == "recruit" or kind.begins_with("recruit_"): return recruitment.command(state, command)
	if kind.begins_with("hero_"): return management.command(state, command)
	if kind.begins_with("sea_"): return salvage.command(state, command)
	if kind.begins_with("collection_") or kind == "item_use": return collections.command(state, command)
	if kind == "gift_buy": return gift_shop.buy(state, String(command.get("product", "")))
	match kind:
		"city_upgrade":
			if state.city_level >= _city.size(): return TownOperations.reject("主城已满级")
			var offer: Dictionary = _city[state.city_level]
			if main.progress.get("dungeon", 0) < offer.dungeon: return TownOperations.reject("地下城通关进度不足")
			if state.coins < offer.cost: return TownOperations.reject("金币不足")
			state.coins -= int(offer.cost)
			state.city_level += 1
		"resource_buy":
			var resource := String(command.get("resource", ""))
			if resource not in ["coins", "energy"]: return TownOperations.reject("资源不存在")
			var offer := purchase(state, resource)
			if main.daily.get(resource, 0) >= offer.limit: return TownOperations.reject("今日购买次数已用完")
			if state.diamonds < offer.cost: return TownOperations.reject("钻石不足")
			state.diamonds -= int(offer.cost)
			if resource == "coins": state.coins += int(offer.amount)
			else: main.energy += int(offer.amount)
			main.daily[resource] = main.daily.get(resource, 0) + 1
		"resource_free":
			var resource := String(command.get("resource", ""))
			if resource == "coins":
				var offer := purchase(state, "coins")
				if main.daily.get("coin_ads", 0) >= offer.free_limit: return TownOperations.reject("今日领取次数已用完")
				main.daily["coin_ads"] = main.daily.get("coin_ads", 0) + 1
				state.coins += int(offer.free_amount)
			elif resource == "energy":
				var slot := _energy_slot(state)
				if slot < 0: return TownOperations.reject("当前没有可领取的净化之力")
				main.claimed_energy.append(slot)
				main.energy += int(purchase(state, "energy").free_amount)
			else: return TownOperations.reject("资源不存在")
		"battle_start":
			var mode := String(command.get("mode", "dungeon"))
			if mode != "dungeon" and not _modes.any(func(m): return m.id == mode): return TownOperations.reject("玩法不存在")
			return expedition.start(state, management.roster(state), mode)
		"battle_claim": return expedition.claim(state)
		"battle_close":
			if not main.battle.is_empty() and main.battle.status == "won" and not main.battle.claimed: return TownOperations.reject("请先领取奖励")
			main.battle = {}
		"battle_speed": main.battle_speed = 2 if main.battle_speed == 1 else 1
		"shop_buy": return diamond_shop.buy(state, command)
		"profile_name":
			var value := String(command.get("value", "")).strip_edges()
			if value.is_empty() or value.length() > 12 or "\n" in value: return TownOperations.reject("名称需要 1 至 12 个字符")
			main.player_name = value
		"profile_avatar":
			var id := String(command.get("hero", ""))
			if not main.roster.any(func(h): return h.definition == id): return TownOperations.reject("请先获得该英雄")
			main.avatar = recruitment.definitions[id].resource_id
		"profile_sound": main.sound = not main.sound
		_:
			return TownOperations.reject("无效操作")
	return {"accepted": true}

func _energy_slot(state: Dictionary) -> int:
	for hour: int in [8, 12, 18]:
		if state.main.day_time >= hour * 3600 and hour not in state.main.claimed_energy: return hour
	return -1
