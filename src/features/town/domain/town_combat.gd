class_name TownCombat
extends RefCounted

var navigation: TownNavigation
var movement: TownHeroMovement
var loot := TownLoot.new()
var sequence := TownAttackSequence.new()
var population := TownMonsterPopulation.new()
var regions := TownRegionLevels.new()


func configure(data, state: Dictionary, rng, field_rng) -> void:
	loot.initialize(state, data, rng)
	sequence.configure(data)
	state.monsters = []
	state.effects = []
	state.projectiles = []
	population.navigation = navigation
	population.movement = movement
	population.configure(data, field_rng, state)
	regions.configure(data, state, population)


func hunt(hero: Dictionary, state: Dictionary, dt: float, owner) -> void:
	if navigation.zone(hero.position) == "town":
		hero.enemy = ""
		movement.travel(hero, navigation.center(hero.assigned_area), hero.assigned_area)
		return
	var candidates: Array = state.monsters.filter(func(m): return m.hp > 0 and navigation.zone(m.position) == navigation.zone(hero.position))
	if candidates.is_empty():
		hero.reason = "等待野外刷新"
		TownHeroStats.animate(hero, "idle")
		return
	candidates.sort_custom(func(a, b): return hero.position.distance_squared_to(a.position) < hero.position.distance_squared_to(b.position))
	var target: Dictionary = candidates[0]
	for candidate: Dictionary in candidates:
		if candidate.id == hero.enemy:
			target = candidate
			break
	if hero.enemy != target.id: hero.path.clear()
	hero.enemy = target.id
	hero.reason = "讨伐" + target.name
	_engage(hero, target, state, dt, 1.0 + TownEquipmentRules.total(hero.equipment, "speed_up") / 10000.0)


func _engage(actor: Dictionary, target: Dictionary, state: Dictionary, dt: float, speed_multiplier: float = 1.0) -> void:
	var actors: Array = state.heroes + state.monsters
	var reach: float = actor.base.attack_range
	var area := navigation.zone(actor.position)
	var current_cell := navigation.cell_at(actor.position, area)
	var on_center: bool = actor.position.distance_to(navigation.point(current_cell, area)) < 0.01
	if on_center and actor.position.distance_to(target.position) <= reach and not navigation.occupied_cell(actor, actors, actor.position):
		actor.path.clear()
		TownHeroStats.face(actor, target.position - actor.position)
		if actor.cooldown <= 0:
			sequence.begin(actor, target)
		else:
			TownHeroStats.animate(actor, "idle")
		return
	if actor.path.is_empty():
		var goal := navigation.attack_position(actor, target, actors, reach)
		if goal == Vector2.INF:
			TownHeroStats.animate(actor, "idle")
			return
		actor.path = navigation.route(actor.position, goal)
	# Check attack range after each completed native field step.
	movement.step(actor, actors, dt, float(actor.base.speed) * speed_multiplier, true)



static func damage(attack: float, defense: float) -> float:
	return maxf(1.0, attack * 100.0 / (100.0 + maxf(0.0, defense)))


func defeat(monster: Dictionary, hero: Dictionary, owner) -> void:
	if monster.mode == "dead":
		return
	monster.mode = "dead"
	monster.hp = 0.0
	monster.timer = float(monster.base.respawn_seconds)
	monster.path.clear()
	monster.attack_state = {}
	monster.animation = "death"
	monster.animation_time = 0.0
	if monster.get("boss", false): return
	population.defeated(monster)
	hero.needs.magic += 1
	hero.trip_kills += 1
	hero.kills += 1
	hero.enemy = ""
	loot.defeat(monster, hero, owner)
	TownHeroStats.record(hero, "击败" + monster.name)


func step(state: Dictionary, dt: float, owner) -> void:
	regions.sync_unlocked()
	sequence.advance_projectiles(state, dt, self, owner)
	for monster: Dictionary in state.monsters:
		monster.animation_time += dt
		monster.cooldown = maxf(0.0, monster.cooldown - dt)
		if monster.mode == "dead":
			if monster.get("boss", false): continue
			monster.timer -= dt
			if monster.timer <= 0:
				population.respawn(monster, state)
			continue
		if sequence.advance(monster, state, dt, self, owner):
			continue
		var targets: Array = state.heroes.filter(func(h): return h.deployed and h.assigned_area != "town" and h.needs.hp > 0 and navigation.zone(h.position) == navigation.zone(monster.position) and h.position.distance_to(monster.position) <= monster.base.patrol_range)
		targets.sort_custom(func(a, b): return monster.position.distance_squared_to(a.position) < monster.position.distance_squared_to(b.position))
		if targets.is_empty():
			if monster.get("boss", false): TownHeroStats.animate(monster, "idle")
			else: population.patrol(monster, state, dt)
			continue
		var hero: Dictionary = targets[0]
		if monster.mode != "hunting" or monster.target != hero.id:
			monster.path.clear()
		monster.target = hero.id
		monster.mode = "hunting"
		_engage(monster, hero, state, dt)


static func kill_hero(hero: Dictionary, owner) -> void:
	if hero.mode in ["dead", "reviving"]:
		return
	hero.mode = "dead"
	hero.needs.hp = 0.0
	hero.target = "building.11"
	hero.path.clear()
	hero.attack_state = {}
	hero.timer = 1.8
	hero.deaths += 1
	hero.animation = "death"
	hero.animation_time = 0.0
	hero.reason = "阵亡"
	owner.record("阵亡", hero.name + "阵亡，前往复活祭坛", 0)
	TownHeroStats.record(hero, "阵亡")
