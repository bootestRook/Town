extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")


func run(test: TestSupport) -> void:
	var op = Heroes.new().fresh(47115, 48)
	var nav: TownNavigation = op._simulation.navigation
	var data := DataRegistry.new()
	data.load_default()
	var buildings: Array = data.rows("town_buildings")
	for building: Dictionary in buildings:
		var occupied := true
		for x in range(building.grid_x, building.grid_x + building.width):
			for y in range(building.grid_y, building.grid_y + building.height):
				occupied = occupied and not nav.cells.town.has(Vector2i(x, y))
		test.assert_true(occupied, "entire authored building footprint blocks town travel")
		test.assert_equal(TownView.placed_position(building).y, TownView.grid_position(building.grid_x, building.grid_y).y - 66.5, "eight-tile art root uses original prefab height offset")
	var corner := nav.point(Vector2i(69, 34), "town")
	var opposite := nav.point(Vector2i(68, 35), "town")
	var path := nav.route(corner, opposite)
	test.assert_true(path.size() > 1 and path[0] != opposite, "hospital corner cannot be crossed diagonally")
	test.assert_true(_safe_route(nav, corner, path, buildings), "hospital corner route stays outside building interior")
	var middle := corner.lerp(nav.point(Vector2i(68, 34), "town"), 0.3)
	path = nav.route(middle, opposite)
	test.assert_equal(path[0], nav.point(nav.cell_at(middle, "town"), "town"), "mid-edge retarget rejoins its own cell before changing direction")
	test.assert_true(_safe_route(nav, middle, path, buildings), "retarget does not cut through a building corner")
	var safe := true
	var routes := 0
	for from: Vector2 in nav.doors.values():
		for to: Vector2 in nav.doors.values():
			path = nav.route(from, to)
			safe = safe and not path.is_empty() and _safe_route(nav, from, path, buildings)
			routes += 1
	test.assert_true(safe, "all 324 building-to-building routes are continuously outside all footprints")
	# Sample real 20 Hz simulation, including city wander, arrival, combat return and summon reroutes.
	var samples := 0
	var violations: Array = []
	for frame in 2400:
		if frame % 127 == 0:
			op.summon(op._state.heroes[0].id, buildings[(frame / 127) as int % buildings.size()].id)
		op.advance(0.05)
		for hero: Dictionary in op._state.heroes:
			samples += 1
			if _inside(hero.position, buildings, nav) and violations.size() < 5:
				violations.append({"id":hero.id,"position":hero.position,"mode":hero.mode})
	test.assert_true(violations.is_empty(), "48 city actors never enter physical building footprints between waypoints")
	print("WORLD_NAVIGATION ", JSON.stringify({"routes":routes,"samples":samples,"violations":violations}))


func _safe_route(nav: TownNavigation, start: Vector2, path: Array, buildings: Array) -> bool:
	var previous := start
	for next: Vector2 in path:
		for step in range(1, maxi(2, ceili(previous.distance_to(next)) + 1)):
			var point := previous.lerp(next, step / float(maxi(1, ceili(previous.distance_to(next)))))
			if not nav.passable(point) or _inside(point, buildings, nav):
				return false
		previous = next
	return true


func _inside(position: Vector2, buildings: Array, nav: TownNavigation) -> bool:
	# Independent continuous diamond coordinates; do not use the navigation edge tolerance.
	var r: Dictionary = nav.regions.town
	var x: float = (position.x - r.origin_x) / r.tile_width + (r.origin_y - position.y) / r.tile_height
	var y: float = (r.origin_y - position.y) / r.tile_height - (position.x - r.origin_x) / r.tile_width
	for b: Dictionary in buildings:
		if x > b.grid_x + 0.0001 and x < b.grid_x + b.width - 0.0001 and y > b.grid_y + 0.0001 and y < b.grid_y + b.height - 0.0001:
			return true
	return false
