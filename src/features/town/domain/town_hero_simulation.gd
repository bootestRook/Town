class_name TownHeroSimulation
extends RefCounted

const THRESHOLDS := {"hp": 70.0, "energy": 50.0, "tired": 40.0, "mood": 40.0}
var navigation := TownNavigation.new()
var movement := TownHeroMovement.new()
var combat := TownCombat.new()
var decisions := TownHeroDecisions.new()
var standby := TownHeroStandby.new()
var population := TownHeroPopulation.new()
var horn: TownBattleHorn


func initialize(state: Dictionary, data, items: Dictionary, rng, wander_rng, field_rng) -> void:
	navigation.configure(data)
	movement.navigation = navigation
	combat.navigation = navigation
	combat.movement = movement
	decisions.navigation = navigation
	decisions.movement = movement
	decisions.heroes = state.heroes
	decisions.standby = standby
	standby.navigation = navigation
	standby.movement = movement
	standby.rng = wander_rng
	population.navigation = navigation
	population.initialize(state, data, items)
	state.time = 0.0
	combat.configure(data, state, rng, field_rng)
	state.revival = {"seats": 3, "seconds": 15.0, "hp": 10.0}


func sync_deployment(state: Dictionary) -> void:
	population.sync_owned(state)
	for hero: Dictionary in state.heroes:
		var entry: Dictionary = state.main.roster.filter(func(h): return h.id == hero.id)[0]
		standby.change(hero, hero.id in state.main.team, state, entry.assigned_area)


func step(state: Dictionary, owner, dt: float) -> void:
	state.time += dt
	combat.loot.step()
	horn.step(dt, owner)
	for actor: Dictionary in state.heroes + state.monsters:
		actor.previous_position = actor.position
	for hero: Dictionary in state.heroes:
		hero.animation_time += dt
		if navigation.zone(hero.position) == "town": TownHeroNeeds.purify(hero, state)
		if (not hero.deployed or hero.assigned_area == "town") and hero.needs.hp > 0 and hero.mode not in ["serving", "reviving", "dead"]:
			standby.step(hero, state.heroes, dt)
			continue
		hero.cooldown = maxf(0.0, hero.cooldown - dt)
		hero.skip_shopping = maxf(0.0, hero.skip_shopping - dt)
		if hero.needs.hp > 0 and navigation.zone(hero.position) not in ["", "town"]:
			TownHeroNeeds.consume_energy(hero, dt * 0.32)
			for stat: String in ["tired", "mood"]:
				hero.needs[stat] = maxf(0.0, hero.needs[stat] - dt * {"tired": 0.26, "mood": 0.2}[stat])
		if hero.mode not in ["serving", "reviving", "dead"] and hero.needs.hp <= 0 and hero.target != "building.11":
			combat.kill_hero(hero, owner)
		if horn.encounter.control(hero, owner, dt): continue
		if hero.needs.hp > 0 and combat.sequence.advance(hero, state, dt, combat, owner):
			continue
		if hero.mode not in ["serving", "reviving", "dead"] and (hero.requested != "" or hero.summoned) and not decisions.is_order_route(hero):
			decisions.choose(hero, owner, state)
		if hero.mode == "walking" and navigation.regions.has(hero.target) and hero.needs.hp < 30:
			decisions.choose(hero, owner, state)
		if hero.mode == "walking" and hero.target in navigation.regions and hero.target != "town" and navigation.zone(hero.position) == hero.target:
			if state.monsters.any(func(m): return m.hp > 0 and hero.position.distance_to(m.position) < 220):
				_arrive(hero, owner, state)
		match hero.mode:
			"walking":
				var speed: float = (hero.base.city_speed if navigation.zone(hero.position) == "town" else hero.base.speed) * (1.0 + TownEquipmentRules.total(hero.equipment, "speed_up") / 10000.0)
				if movement.step(hero, state.heroes + state.monsters, dt, speed):
					_arrive(hero, owner, state)
			"hunting":
				if decisions.must_return(hero, owner):
					owner.record("冒险归来", "%s · 本次击败%d只怪物" % [hero.name, hero.trip_kills], 0)
					hero.returning = true
					decisions.choose(hero, owner, state)
				else:
					combat.hunt(hero, state, dt, owner)
			"stationed":
				if decisions.must_return(hero, owner): decisions.choose(hero, owner, state)
			"idle":
				hero.timer -= dt
				if hero.timer <= 0:
					decisions.choose(hero, owner, state)
			"waiting": _wait(hero, owner, state, dt)
			"serving":
				hero.timer -= dt
				if hero.timer <= 0:
					owner.finish_service(hero)
					decisions.choose(hero, owner, state)
			"await_trade":
				hero.wait_time += dt
				if state.equipment_shop.calls.get(hero.id, "") == hero.target or state.equipment_shop.trading == hero.id: continue
				if not owner.has_equipment_offer(hero) or hero.wait_time > 25:
					hero.skip_shopping = 45.0
					decisions.choose(hero, owner, state)
			"shopping_done": decisions.choose(hero, owner, state)
			"dead":
				hero.timer -= dt
				if hero.timer <= 0:
					decisions.go(hero, "building.11")
			"reviving":
				hero.timer -= dt
				if hero.timer <= 0:
					hero.needs.hp = state.revival.hp
					hero.revivals += 1
					owner.record("复活", hero.name + "复活", 0)
					TownHeroStats.record(hero, "复活")
					decisions.choose(hero, owner, state)
	combat.step(state, dt, owner)


func _arrive(hero: Dictionary, owner, state: Dictionary) -> void:
	hero.path.clear()
	TownHeroStats.animate(hero, "idle")
	TownHeroStats.record(hero, "到达" + hero.target)
	if navigation.regions.has(hero.target):
		hero.mode = "hunting" if navigation.dispatch[hero.target].combat_enabled else "stationed"
		hero.reason = navigation.dispatch[hero.target].display_name
		hero.enemy = ""
		hero.trip_kills = 0
		hero.returning = false
	elif hero.target == "building.7":
		hero.summoned = false
		owner.settle_trade(hero)
		decisions.choose(hero, owner, state)
	elif hero.target == "building.11" or owner.services().has(hero.target):
		hero.mode = "waiting"
		hero.queued_at = state.time
		hero.wait_time = 0.0
		hero.reason = "等待空位"
	else:
		hero.requested = ""
		if owner.has_equipment_offer(hero) or state.equipment_shop.calls.get(hero.id, "") == hero.target:
			hero.mode = "await_trade"
			hero.wait_time = 0.0
			hero.reason = "到店等待装备交易"
		else:
			hero.skip_shopping = 10.0
			decisions.choose(hero, owner, state)


func _wait(hero: Dictionary, owner, state: Dictionary, dt: float) -> void:
	hero.wait_time += dt
	if hero.target == "building.11":
		var occupied: int = state.heroes.filter(func(h): return h.mode == "reviving").size()
		if occupied < int(state.revival.seats):
			hero.mode = "reviving"
			hero.timer = state.revival.seconds
			hero.reason = "复活中"
		return
	if owner.begin_service(hero, hero.target):
		hero.mode = "serving"
		return
	if hero.wait_time >= 2.0:
		hero.wait_time = 0.0
		if owner.can_trade(hero):
			decisions.go(hero, "building.7")
		else:
			decisions.choose(hero, owner, state, hero.target)
