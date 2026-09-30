class_name TownHeroStandby
extends RefCounted

# Source CityMapDataMgr / Constant: city building area, minimum trip distance,
# 40% chance of a three-second stop. Occupied destinations are excluded locally.
const MIN_TRIP := 29
const STOP_SECONDS := 3.0
var navigation: TownNavigation
var movement: TownHeroMovement
var rng


func change(hero: Dictionary, deployed: bool, state: Dictionary, assigned_area: String = "field") -> void:
	if hero.deployed == deployed and hero.assigned_area == assigned_area:
		return
	hero.deployed = deployed
	hero.assigned_area = assigned_area
	hero.summoned = false
	hero.requested = ""
	hero.enemy = ""
	hero.attack_state = {}
	state.projectiles = state.projectiles.filter(func(p): return p.source != hero.id and p.target != hero.id)
	for monster: Dictionary in state.monsters:
		if monster.target == hero.id:
			monster.target = ""
			monster.attack_state = {}
	# Paid services and death/revival finish normally; withdrawing never heals or refunds.
	if hero.mode in ["serving", "reviving", "dead"] or hero.needs.hp <= 0:
		return
	hero.path.clear()
	hero.target = ""
	TownHeroStats.animate(hero, "idle")
	if deployed and assigned_area != "town":
		hero.mode = "idle"
		hero.timer = 0.0
		hero.reason = "准备出城"
	else:
		start(hero, state.heroes)


func start(hero: Dictionary, heroes: Array) -> void:
	hero.path.clear()
	hero.target = "standby"
	hero.enemy = ""
	hero.mode = "standby_idle"
	hero.timer = 0.0
	hero.reason = "城内待命"
	TownHeroStats.animate(hero, "idle")
	_travel(hero, heroes, navigation.zone(hero.position) != "town")


func step(hero: Dictionary, heroes: Array, dt: float) -> void:
	if hero.mode not in ["standby_idle", "standby_walk", "standby_return"]:
		start(hero, heroes)
	if hero.mode in ["standby_walk", "standby_return"]:
		var speed: float = (hero.base.city_speed if navigation.zone(hero.position) == "town" else hero.base.speed) * (1.0 + TownEquipmentRules.total(hero.equipment, "speed_up") / 10000.0)
		if movement.step(hero, heroes, dt, speed):
			hero.mode = "standby_idle"
			hero.reason = "城内待命"
			hero.timer = STOP_SECONDS if rng.next_int(100) < 40 else 0.0
		return
	hero.timer -= dt
	if hero.timer <= 0:
		_travel(hero, heroes, navigation.zone(hero.position) != "town")


func _travel(hero: Dictionary, heroes: Array, returning: bool) -> void:
	var start_cell := navigation.cell_at(hero.position, "town")
	var first_column: int = 26 + rng.next_int(65)
	# Bounded column search replaces source recursion when all destinations are busy.
	for offset in 65:
		var x: int = 26 + (first_column - 26 + offset) % 65
		var candidates: Array[Vector2] = []
		for y in range(20, 91):
			var cell := Vector2i(x, y)
			if not navigation.cells.town.has(cell) or absi(x - start_cell.x) + absi(y - start_cell.y) <= MIN_TRIP:
				continue
			var destination := navigation.point(cell, "town")
			if navigation.rest_point_available(destination, hero, heroes):
				candidates.append(destination)
		if candidates.is_empty():
			continue
		var destination: Vector2 = candidates[rng.next_int(candidates.size())]
		if movement.travel(hero, destination, "standby"):
			hero.mode = "standby_return" if returning else "standby_walk"
			hero.reason = "返城待命" if returning else "城内闲逛"
			return
	hero.mode = "standby_idle"
	hero.reason = "等待返城道路" if returning else "城内待命"
	hero.timer = STOP_SECONDS
