class_name TownHornEncounter
extends RefCounted

var state: Dictionary
var navigation: TownNavigation
var movement: TownHeroMovement
var combat: TownCombat
var origin := Vector2.ZERO
var _goals: Dictionary = {}

func configure(value: Dictionary, _data, sim) -> void:
	state = value
	navigation = sim.navigation
	movement = sim.movement
	combat = sim.combat
	origin = sim.navigation.point(Vector2i(20,25), "field")

func prepare(participants: Array, sweep: bool) -> void:
	state.monsters.clear()
	state.effects.clear()
	state.projectiles.clear()
	_goals.clear()
	var points: Array[Vector2] = []
	for cell: Vector2i in navigation.cells.field:
		var point: Vector2 = navigation.point(cell, "field")
		if point.distance_to(origin) >= 100 and point.distance_to(origin) <= 250: points.append(point)
	points.sort_custom(func(a,b): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for i in participants.size():
		var hero: Dictionary = participants[i]
		hero.attack_state = {}
		hero.enemy = ""
		_goals[hero.id] = points[i % points.size()]
		if not sweep and hero.needs.hp > 0 and hero.mode not in ["serving", "reviving", "dead"]: gather(hero)

func gather(hero: Dictionary) -> void:
	hero.mode = "horn_gather"
	hero.reason = "前往野区集结"
	hero.target = "field"
	hero.path = navigation.route(hero.position, _goals[hero.id])
	TownHeroStats.animate(hero, "move")

func control(hero: Dictionary, owner, dt: float) -> bool:
	if state.horn.phase not in ["prepare", "fight"] or state.horn.sweep or hero.id not in state.horn.participants: return false
	if hero.needs.hp <= 0 or hero.mode in ["serving", "reviving", "dead"]: return false
	if state.horn.phase == "fight" and navigation.zone(hero.position) != "field":
		if hero.mode != "horn_gather": gather(hero)
		movement.step(hero, state.heroes, dt, hero.base.city_speed)
		return true
	if state.horn.phase == "fight":
		if hero.mode != "horn_fight":
			hero.path.clear()
			hero.mode = "horn_fight"
		if not combat.sequence.advance(hero, state, dt, combat, owner): combat.hunt(hero, state, dt, owner)
		return true
	if hero.mode not in ["horn_gather", "horn_ready"]: gather(hero)
	if hero.mode == "horn_gather":
		var speed: float = hero.base.city_speed if navigation.zone(hero.position) == "town" else hero.base.speed
		if movement.step(hero, state.heroes, dt, speed) and hero.position.distance_to(_goals[hero.id]) < 1:
			hero.mode = "horn_ready"
			hero.reason = "等待集结"
			TownHeroStats.animate(hero, "idle")
			if hero.id not in state.horn.ready: state.horn.ready.append(hero.id)
	return true

func spawn(definition: Dictionary) -> void:
	var base: Dictionary = definition.duplicate(true)
	base.respawn_seconds = 0.0
	base.coins = 0
	state.monsters.append({"id":"horn.boss", "kind":definition.id, "boss":true, "name":definition.display_name, "visual":definition.visual, "base":base, "index":1000, "position":origin, "previous_position":origin, "spawn":origin, "spawn_id":"horn", "hp":float(definition.max_hp), "mode":"hunting", "target":"", "path":[], "cooldown":0.0, "timer":0.0, "direction":Vector2.LEFT, "animation":"idle", "animation_time":0.0, "attack_state":{}, "attack_serial":0, "reason":"BOSS战"})

func restore() -> void:
	state.monsters.clear()
	state.projectiles.clear()
	state.effects.clear()
	for hero: Dictionary in state.heroes:
		if hero.id not in state.horn.participants: continue
		hero.attack_state = {}
		hero.enemy = ""
		if hero.mode not in ["dead", "reviving", "serving"]:
			hero.mode = "idle"
			hero.timer = 0.0
			hero.path.clear()
			TownHeroStats.animate(hero, "idle")
	combat.regions.restore()
