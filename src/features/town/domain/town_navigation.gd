class_name TownNavigation
extends RefCounted

const STEPS := [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
var regions: Dictionary = {}
var grids: Dictionary = {}
var cells: Dictionary = {}
var doors: Dictionary = {}
var waiting_points: Dictionary = {}
var _capacity := 0
var exits: Dictionary = {}
var dispatch: Dictionary = {}
var field_center: Vector2
var town_center: Vector2


func configure(data) -> void:
	_capacity = data.rows("town_heroes").size()
	for row: Dictionary in data.rows("town_dispatch"): dispatch[row.id] = row
	for row: Dictionary in data.rows("town_regions"):
		regions[row.id] = row
		cells[row.id] = {}
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(0, 0, row.count_x, row.count_y)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES if row.id == "town" else AStarGrid2D.DIAGONAL_MODE_ALWAYS
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.update()
		grid.fill_solid_region(grid.region)
		grids[row.id] = grid
	for row: Dictionary in data.rows("town_navigation"):
		var cell := Vector2i(row.x, row.y)
		cells[row.zone][cell] = point(cell, row.zone)
		grids[row.zone].set_point_solid(cell, false)
	for row: Dictionary in data.rows("town_buildings"):
		doors[row.id] = point(Vector2i(row.door_x, row.door_y), "town")
		waiting_points[row.id] = _building_waiting_points(row)
	for row: Dictionary in data.rows("town_exits"):
		if not exits.has(row.area): exits[row.area] = []
		exits[row.area].append(point(Vector2i(row.x, row.y), "town"))
	town_center = nearest(point(Vector2i(regions.town.center_x, regions.town.center_y), "town"), "town")
	field_center = nearest(point(Vector2i(regions.field.center_x, regions.field.center_y), "field"), "field")


func point(cell: Vector2i, area: String) -> Vector2:
	var r: Dictionary = regions[area]
	return Vector2(r.origin_x + (cell.x - cell.y) * r.tile_width * 0.5, r.origin_y - (cell.x + cell.y + 1) * r.tile_height * 0.5)


func cell_at(position: Vector2, area: String) -> Vector2i:
	var r: Dictionary = regions[area]
	var delta := Vector2(position.x - r.origin_x, r.origin_y - position.y)
	var grid := Vector2(delta.x / r.tile_width + delta.y / r.tile_height, delta.y / r.tile_height - delta.x / r.tile_width)
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	if cells[area].has(cell):
		return cell
	# A diagonal can touch a blocked cell's corner exactly. Keep shared grid edges
	# on their walkable side instead of classifying that instant as outside the map.
	var on_x := absf(grid.x - roundf(grid.x)) < 0.00001
	var on_y := absf(grid.y - roundf(grid.y)) < 0.00001
	if on_x and cells[area].has(cell - Vector2i(1, 0)):
		return cell - Vector2i(1, 0)
	if on_y and cells[area].has(cell - Vector2i(0, 1)):
		return cell - Vector2i(0, 1)
	if on_x and on_y and cells[area].has(cell - Vector2i.ONE):
		return cell - Vector2i.ONE
	return cell


func passable(position: Vector2) -> bool:
	return not zone(position).is_empty()


func zone(position: Vector2) -> String:
	for area: String in ["town"] + exits.keys():
		if cells[area].has(cell_at(position, area)):
			return area
	return ""


func nearest(position: Vector2, required_zone: String = "") -> Vector2:
	var best := Vector2.INF
	var distance := INF
	for area: String in cells:
		if not required_zone.is_empty() and area != required_zone:
			continue
		for candidate: Vector2 in cells[area].values():
			var value := candidate.distance_squared_to(position)
			if value < distance:
				distance = value
				best = candidate
	return best


func route(start: Vector2, finish: Vector2) -> Array:
	if not start.is_finite() or not finish.is_finite():
		return []
	var from := zone(start)
	var to := zone(finish)
	if from.is_empty() or to.is_empty():
		return []
	if from == to:
		return _within(start, finish, from)
	return TownRegionRoutes.route(self, start, finish, from, to)


func center(area: String) -> Vector2:
	return nearest(point(Vector2i(regions[area].center_x, regions[area].center_y), area), area)


func _within(start: Vector2, finish: Vector2, area: String) -> Array:
	var from := cell_at(start, area)
	var to := cell_at(finish, area)
	if not cells[area].has(from) or not cells[area].has(to):
		return []
	var ids: Array[Vector2i] = []
	if area == "town":
		ids = grids[area].get_id_path(from, to)
	else:
		# Field movement follows grid steps; only map edges trigger a detour.
		ids = [from]
		var visited := {from: true}
		var current := from
		while current != to and ids.size() <= cells[area].size():
			var next := current + Vector2i(signi(to.x - current.x), signi(to.y - current.y))
			if not cells[area].has(next) or visited.has(next):
				var score := INF
				next = current
				for step: Vector2i in STEPS:
					var neighbor := current + step
					if cells[area].has(neighbor) and not visited.has(neighbor):
						var cost: float = absi(to.x - neighbor.x) + absi(to.y - neighbor.y) + (1.0 if neighbor.x == to.x or neighbor.y == to.y else 1.4)
						if cost < score:
							score = cost
							next = neighbor
				if next == current:
					return []
			current = next
			visited[current] = true
			ids.append(current)
	var result: Array = []
	# A retarget can arrive mid-edge. Rejoin its safe cell before taking the new path.
	if area == "town" and not start.is_equal_approx(point(from, area)):
		result.append(point(from, area))
	for i in range(1, ids.size()):
		result.append(point(ids[i], area))
	if not ids.is_empty():
		result.append(finish)
	return result


func _building_waiting_points(building: Dictionary) -> Array[Vector2]:
	# Source BuildingEditorComponent uses a one-tile perimeter around these buildings.
	var candidates: Array[Vector2] = []
	for x in range(building.grid_x - 1, building.grid_x + building.width + 1):
		for y in range(building.grid_y - 1, building.grid_y + building.height + 1):
			if x >= building.grid_x and x < building.grid_x + building.width and y >= building.grid_y and y < building.grid_y + building.height:
				continue
			var cell := Vector2i(x, y)
			if cells.town.has(cell):
				candidates.append(point(cell, "town"))
	var door: Vector2 = doors[building.id]
	var result: Array[Vector2] = []
	_append_spaced(result, candidates, door)
	# A full perimeter overflows into nearby walkable city tiles instead of reusing a spot.
	if result.size() < _capacity:
		_append_spaced(result, cells.town.values(), door)
	return result


func _append_spaced(result: Array[Vector2], candidates: Array, origin: Vector2) -> void:
	candidates.sort_custom(func(a: Vector2, b: Vector2):
		var a_distance := a.distance_squared_to(origin)
		var b_distance := b.distance_squared_to(origin)
		return a_distance < b_distance if a_distance != b_distance else a.x < b.x)
	for candidate: Vector2 in candidates:
		if result.size() >= _capacity:
			return
		# Keep the source hero's 60 x 80 footprint clear at rest, without city hard collisions.
		if result.all(func(p: Vector2): return absf(p.x - candidate.x) >= 60.0 or absf(p.y - candidate.y) >= 80.0):
			result.append(candidate)


func available_queue_point(building: String, hero: Dictionary, heroes: Array) -> Vector2:
	if not waiting_points.has(building):
		return Vector2.INF
	for candidate: Vector2 in waiting_points[building]:
		if rest_point_available(candidate, hero, heroes):
			return candidate
	return Vector2.INF


func rest_point_available(candidate: Vector2, hero: Dictionary, heroes: Array) -> bool:
	for other: Dictionary in heroes:
		if other.id == hero.id or other.mode in ["serving", "reviving", "dead", "hunting"]:
			continue
		var position: Vector2 = other.position
		if other.mode in ["walking", "standby_walk", "standby_return"]:
			if regions.has(other.target) or other.path.is_empty():
				continue
			position = other.path.back()
		if absf(position.x - candidate.x) < 60.0 and absf(position.y - candidate.y) < 80.0:
			return false
	return true


func queue_point(building: String, index: int) -> Vector2:
	if not waiting_points.has(building) or index < 0 or index >= waiting_points[building].size():
		return Vector2.INF
	return waiting_points[building][index]


func occupied_cell(actor: Dictionary, actors: Array, point_position: Vector2) -> bool:
	var area := zone(point_position)
	var target := cell_at(point_position, area)
	for other: Dictionary in actors:
		if other.id != actor.id and other.mode == "hunting" and other.path.is_empty() and TownAttackSequence.alive(other) and zone(other.position) == area and cell_at(other.position, area) == target:
			return true
	return false


func attack_position(actor: Dictionary, target: Dictionary, actors: Array, reach: float) -> Vector2:
	var area := zone(target.position)
	var center := cell_at(target.position, area)
	var delta := cell_at(actor.position, area) - center
	var horizontal := Vector2i(1 if delta.x >= 0 else -1, 0)
	var vertical := Vector2i(0, 1 if delta.y >= 0 else -1)
	var directions := [horizontal, vertical] if absi(delta.x) >= absi(delta.y) else [vertical, horizontal]
	var radius := ceili(reach / minf(regions[area].tile_width, regions[area].tile_height))
	for side in [1, -1]:
		for ring in range(radius, 0, -1):
			for direction: Vector2i in directions:
				var begin: int = 1 - ring if direction.x != 0 else -ring
				var end: int = ring if direction.x != 0 else ring + 1
				for i in range(begin, end):
					var offset := Vector2i(ring * direction.x * side, i) if direction.x != 0 else Vector2i(i, ring * direction.y * side)
					var cell := center + offset
					if cells[area].has(cell):
						var candidate := point(cell, area)
						if zone(candidate) == area and candidate.distance_to(target.position) <= reach and not occupied_cell(actor, actors, candidate):
							return candidate
	return Vector2.INF
