class_name TownMonsterPopulation
extends RefCounted

var navigation: TownNavigation
var movement: TownHeroMovement
var rng
var spawns: Dictionary = {}
var _patrol_points: Dictionary = {}


var definitions: Dictionary = {}
var stages: Dictionary = {}
var members: Array = []
var cycles: Dictionary = {}
var _serial := 0
var _state: Dictionary

func configure(data, field_rng, state: Dictionary) -> void:
	assert(validation_error(data).is_empty(), validation_error(data))
	rng = field_rng
	_state = state
	members = data.rows("town_region_members")
	for row: Dictionary in data.rows("town_region_levels"): stages[row.id] = row
	for row: Dictionary in data.rows("town_monster_spawns"):
		spawns[row.id] = navigation.point(Vector2i(row.grid_x, row.grid_y), row.area)
	for definition: Dictionary in data.rows("town_monsters"):
		definitions[definition.id] = definition
		for id: String in spawns:
			if id.begins_with(definition.area + "."):
				_patrol_points[definition.id + "/" + id] = _candidates(spawns[id], definition.patrol_range, definition.area)

func validation_error(data) -> String:
	var occupied := {}
	for row: Dictionary in data.rows("town_monster_spawns"):
		var cell := Vector2i(row.grid_x, row.grid_y)
		if not navigation.cells[row.area].has(cell): return "Monster spawn outside walkable field: " + row.id
		var key: String = row.area + str(cell)
		if occupied.has(key): return "Duplicate monster spawn cell: " + row.id
		occupied[key] = true
		for definition: Dictionary in data.rows("town_monsters"):
			if definition.area == row.area and _candidates(navigation.point(cell, row.area), definition.patrol_range, row.area).is_empty(): return "Monster spawn has no patrol route: " + definition.id
	for stage: Dictionary in data.rows("town_region_levels"):
		var total := 0
		for member: Dictionary in data.rows("town_region_members"):
			if member.stage == stage.id and member.role == "normal": total += int(member.count)
		if total > stage.normal_points.split(";", false).size(): return "Monster population exceeds available spawn points"
		for list: String in [stage.normal_points, stage.leader_points]:
			for number: String in list.split(";", false):
				if not data.rows("town_monster_spawns").any(func(s): return s.area == stage.area and s.number == int(number)): return "Unknown region spawn point"
	return ""

func stage_for(area: String) -> Dictionary:
	return stages[area + "." + str(_state.region_levels[area])]

func rebuild(area: String) -> void:
	var removed: Array = _state.monsters.filter(func(m): return m.get("area", "field") == area).map(func(m): return m.id)
	_state.monsters = _state.monsters.filter(func(m): return m.id not in removed)
	_state.projectiles = _state.projectiles.filter(func(p): return p.source not in removed and p.target not in removed)
	for hero: Dictionary in _state.heroes:
		if hero.enemy in removed:
			hero.enemy = ""
			hero.attack_state = {}
			hero.path.clear()
	cycles[area] = {"created":{}, "leader_dead":0.0}
	for member: Dictionary in members:
		if member.stage == stage_for(area).id and member.role == "normal":
			for i in int(member.count): _state.monsters.append(create(definitions[member.monster], i, _state))

func create(definition: Dictionary, index: int, state: Dictionary) -> Dictionary:
	var monster := {"id":"monster.%s.%d" % [definition.id,index], "slot_kind":definition.id, "area":definition.area, "kind":definition.id, "name":definition.display_name, "visual":definition.visual, "base":definition, "index":state.monsters.size()+3, "position":Vector2.ZERO, "previous_position":Vector2.ZERO, "spawn":Vector2.ZERO, "spawn_id":"", "hp":0.0, "mode":"dead", "target":"", "path":[], "cooldown":0.0, "timer":0.0, "direction":Vector2.LEFT, "animation":"idle", "animation_time":0.0, "attack_state":{}, "attack_serial":0, "reason":""}
	respawn(monster, state)
	return monster

func respawn(monster: Dictionary, state: Dictionary) -> bool:
	var area: String = monster.area
	var stage := stage_for(area)
	var cycle: Dictionary = cycles[area]
	var slot: String = monster.slot_kind
	var count := int(cycle.created.get(slot, 0)) + 1
	var kind := slot
	var leader := false
	if count >= stage.mutant_count and rng.next_int(10000) < stage.mutant_chance:
		kind += ".mut"
	elif count >= stage.leader_count and state.time >= cycle.leader_dead + stage.leader_seconds and not state.monsters.any(func(m): return m.get("area", "") == area and m.get("leader", false) and m.hp > 0):
		if rng.next_int(10000) < stage.leader_chance:
			for member: Dictionary in members:
				if member.stage == stage.id and member.role == "leader": kind = member.monster; leader = true
	var available: Array[String] = []
	for number: String in String(stage.leader_points if leader else stage.normal_points).split(";", false):
		var id := area + ".spawn." + number
		var reserved: bool = state.monsters.any(func(m): return m.hp > 0 and m.spawn_id == id)
		var occupied: bool = (state.heroes + state.monsters).any(func(a): return a.id != monster.id and TownAttackSequence.alive(a) and a.position.distance_to(spawns[id]) < 45)
		if not reserved and not occupied: available.append(id)
	if available.is_empty(): return false
	cycle.created[slot] = 0 if kind != slot else count
	_serial += 1
	monster.id = "monster.%s.%d" % [area,_serial]
	monster.kind = kind
	monster.base = definitions[kind]
	monster.name = monster.base.display_name
	monster.visual = monster.base.visual
	monster["leader"] = leader
	monster.spawn_id = available[rng.next_int(available.size())]
	monster.spawn = spawns[monster.spawn_id]
	monster.position = monster.spawn
	monster.previous_position = monster.spawn
	monster.hp = float(monster.base.max_hp)
	monster["contributors"] = []
	monster.mode = "patrol"
	monster.reason = "野外巡逻"
	monster.target = ""
	monster.path.clear()
	monster.attack_state = {}
	monster.cooldown = 0.0
	monster.timer = 0.0
	TownHeroStats.animate(monster, "idle")
	return true

func defeated(monster: Dictionary) -> void:
	if monster.get("leader", false): cycles[monster.area].leader_dead = _state.time
	monster.timer = stage_for(monster.area).normal_seconds


func patrol(monster: Dictionary, state: Dictionary, dt: float) -> void:
	if monster.mode != "patrol":
		monster.mode = "patrol"
		monster.path.clear()
		monster.timer = 0.0
	monster.target = ""
	monster.reason = "野外巡逻"
	if not monster.path.is_empty():
		if movement.step(monster, state.heroes + state.monsters, dt, monster.base.speed, true):
			_rest(monster)
		return
	monster.timer -= dt
	if monster.timer > 0:
		return
	var points: Array = _patrol_points[monster.kind + "/" + monster.spawn_id]
	var begin: int = rng.next_int(maxi(1, points.size()))
	for offset in points.size():
		var goal: Vector2 = points[(begin + offset) % points.size()]
		if monster.position.distance_to(goal) < 1 or navigation.occupied_cell(monster, state.heroes + state.monsters, goal):
			continue
		var path: Array = navigation.route(monster.position, goal)
		if path.is_empty():
			continue
		# A map-edge detour may leave the patrol circle even when its endpoint is valid.
		if path.any(func(p): return navigation.zone(p) != monster.area):
			continue
		if monster.position.distance_to(monster.spawn) <= monster.base.patrol_range and path.any(func(p): return p.distance_to(monster.spawn) > monster.base.patrol_range):
			continue
		monster.path = path
		TownHeroStats.animate(monster, "move")
		return
	_rest(monster)


func _rest(monster: Dictionary) -> void:
	monster.timer = 2.5 + rng.next_int(2501) / 1000.0
	monster.reason = "巡逻停留"
	TownHeroStats.animate(monster, "idle")


func _candidates(origin: Vector2, radius: float, area: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var cell := navigation.cell_at(origin, area)
	var width := floori(radius / navigation.regions[area].tile_width)
	var height := floori(radius / navigation.regions[area].tile_height)
	for x in range(-width, width + 1):
		for y in range(-height, height + 1):
			if absi(x) != width and absi(y) != height:
				continue
			var target := cell + Vector2i(x, y)
			if target == cell:
				continue
			var point := navigation.point(target, area)
			if navigation.cells[area].has(target) and navigation.zone(point) == area and point.distance_to(origin) <= radius:
				result.append(point)
	return result
