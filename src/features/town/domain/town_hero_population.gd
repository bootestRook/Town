class_name TownHeroPopulation
extends RefCounted

var navigation: TownNavigation
var definitions: Dictionary = {}
var _items: Dictionary = {}
var _arrivals: Array = []


func initialize(state: Dictionary, data, items: Dictionary) -> void:
	_items = items
	_arrivals = navigation.cells.town.values()
	_arrivals.sort_custom(func(a: Vector2, b: Vector2):
		var da := a.distance_squared_to(navigation.town_center)
		var db := b.distance_squared_to(navigation.town_center)
		return da < db if da != db else a.x < b.x)
	var rows: Array = data.rows("town_heroes")
	rows.sort_custom(func(a, b): return a.start_delay < b.start_delay)
	for row: Dictionary in rows:
		definitions[row.id] = row
		if row.initially_owned:
			state.heroes.append(_create(row, state))


func sync_owned(state: Dictionary) -> void:
	var owned: Array = state.main.roster.map(func(h): return h.id)
	for hero: Dictionary in state.heroes.duplicate():
		if hero.id not in owned:
			state.heroes.erase(hero)
			state.projectiles = state.projectiles.filter(func(p): return p.source != hero.id and p.target != hero.id)
			for monster: Dictionary in state.monsters:
				if monster.target == hero.id:
					monster.target = ""
					monster.attack_state = {}
	for entry: Dictionary in state.main.roster:
		if not entry.live.is_empty():
			continue
		assert(definitions.has(entry.id), "Recruited hero must have a complete map definition")
		var hero := _create(definitions[entry.id], state)
		state.heroes.append(hero)
		entry.live = hero.id


func _create(definition: Dictionary, state: Dictionary) -> Dictionary:
	var position := Vector2.INF
	for candidate: Vector2 in _arrivals:
		if state.heroes.all(func(h): return absf(h.position.x - candidate.x) >= 60 or absf(h.position.y - candidate.y) >= 80) and navigation.rest_point_available(candidate, {"id":definition.id}, state.heroes):
			position = candidate
			break
	assert(position.is_finite(), "City needs an available arrival point")
	var index := 0
	for hero: Dictionary in state.heroes:
		index = maxi(index, hero.index + 1)
	return TownHeroStats.create(definition, index, position, _items)
