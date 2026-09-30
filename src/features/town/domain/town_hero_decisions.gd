class_name TownHeroDecisions
extends RefCounted

var navigation: TownNavigation
var movement: TownHeroMovement
var heroes: Array = []
var standby: TownHeroStandby


static func is_order_route(hero: Dictionary) -> bool:
	if hero.needs.hp <= 0:
		return true
	return hero.mode == "walking" and ((hero.requested != "" and hero.target == hero.requested) or (hero.summoned and hero.target == "building.7"))


static func must_return(hero: Dictionary, owner) -> bool:
	return hero.needs.hp < 30 or hero.needs.energy <= 10 or hero.needs.tired <= 10 or hero.needs.mood <= 10 or (hero.trip_kills >= 3 and (owner.has_trade(hero) or hero.needs.hp < 70))


func choose(hero: Dictionary, owner, _state: Dictionary, excluded: String = "") -> void:
	if hero.needs.hp <= 0:
		go(hero, "building.11")
		return
	if not hero.deployed or hero.assigned_area == "town":
		standby.start(hero, heroes)
		return
	if hero.requested != "":
		go(hero, hero.requested)
		return
	if hero.summoned:
		go(hero, "building.7")
		return
	var needs: Array = []
	var services: Dictionary = owner.services()
	for building: String in services:
		var stat: String = services[building].stat
		if hero.needs[stat] < TownHeroSimulation.THRESHOLDS[stat]:
			needs.append({"building": building, "urgency": hero.needs[stat] / TownHeroSimulation.THRESHOLDS[stat]})
	needs.sort_custom(func(a, b): return a.urgency < b.urgency)
	for need: Dictionary in needs:
		var building: String = need.building
		if building == excluded:
			continue
		if owner.service_available(hero, building):
			go(hero, building)
			return
	if owner.can_trade(hero):
		go(hero, "building.7")
		return
	if not needs.is_empty():
		var target: String = needs[0].building
		if hero.mode != "waiting" or hero.target != target:
			go(hero, target)
		return
	if hero.skip_shopping <= 0:
		var shop: String = owner.equipment_target(hero)
		if not shop.is_empty():
			go(hero, shop)
			return
	go(hero, hero.assigned_area)


func go(hero: Dictionary, target: String) -> void:
	var destination: Vector2
	if navigation.regions.has(target):
		destination = navigation.nearest(navigation.center(target) + Vector2((hero.index % 8 - 3) * 70, (hero.index / 8) * 55 - 120), target)
	else:
		if hero.target == target and hero.mode in ["walking", "waiting", "await_trade"]:
			return
		destination = navigation.available_queue_point(target, hero, heroes)
	hero.reason = "前往" + navigation.dispatch[target].display_name if navigation.regions.has(target) else "前往" + {"building.1":"医院", "building.2":"餐馆", "building.3":"旅馆", "building.4":"酒馆", "building.6":"武器店", "building.7":"交易所", "building.9":"防具店", "building.10":"饰品店", "building.11":"复活祭坛"}[target]
	TownHeroStats.record(hero, hero.reason)
	movement.travel(hero, destination, target)
