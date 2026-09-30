extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")


func run(test: TestSupport) -> void:
	var op = Heroes.new().fresh()
	var nav: TownNavigation = op._simulation.navigation
	for building: String in nav.doors:
		var points: Array[Vector2] = []
		for hero: Dictionary in op._state.heroes:
			var point := nav.queue_point(building, hero.index)
			test.assert_true(point.is_finite() and nav.zone(point) == "town", "waiting point is a source walkable city tile: " + building)
			test.assert_true(not nav.route(nav.town_center, point).is_empty(), "all three waiting points are reachable: " + building)
			for other: Vector2 in points:
				test.assert_true(absf(point.x - other.x) >= 60 or absf(point.y - other.y) >= 80, "waiting heroes have distinct non-overlapping footprints: " + building)
			points.append(point)
	test.assert_true(nav.route(nav.town_center, nav.queue_point("missing", 0)).is_empty(), "invalid building waiting target is rejected")
	test.assert_true(nav.route(nav.town_center, nav.queue_point("building.1", -1)).is_empty(), "negative waiting slot is rejected")
	test.assert_true(nav.route(nav.town_center, nav.queue_point("building.1", 10000)).is_empty(), "out-of-range waiting slot is rejected rather than wrapped")
	# Genuine routes followed by an extended stock shortage reproduce the screenshot.
	op._state.monsters.clear()
	for hero: Dictionary in op._state.heroes:
		hero.needs.hp = 20
		op._simulation.decisions.go(hero, "building.1")
	op.advance(35)
	test.assert_true(op._state.heroes.all(func(h): return h.mode == "waiting" and h.target == "building.1"), "all three heroes wait at hospital when stock is empty")
	var positions: Array = op._state.heroes.map(func(h): return h.position)
	for hero: Dictionary in op._state.heroes:
		test.assert_equal(hero.position, nav.queue_point("building.1", hero.index), "actual arrivals occupy their separate waiting points")
	op.advance(10)
	test.assert_equal(op._state.heroes.map(func(h): return h.position), positions, "continued waiting does not drift or collapse back to the door")
	var order: Array = op._state.heroes.duplicate()
	order.sort_custom(func(a, b): return a.queued_at < b.queued_at if a.queued_at != b.queued_at else a.index < b.index)
	op.produce("building.1", "item.20101")
	op.advance(0.1)
	test.assert_equal(order[0].mode, "serving", "first arrival enters service first")
	test.assert_equal(op._state.heroes.filter(func(h): return h.mode == "serving").size(), 1, "service capacity is preserved")
	for hero: Dictionary in order.slice(1):
		test.assert_equal(hero.position, positions[hero.index], "remaining heroes retain their waiting positions during service")
	op.advance(40)
	test.assert_true(op._state.heroes.all(func(h): return h.needs.hp == 100), "each waiting hero eventually receives treatment")
	test.assert_equal(op._state.counts.get("使用完成", 0), 3, "three heroes complete service without starvation or duplicate admission")
	var returning: Dictionary = op._state.heroes[0]
	returning.needs.hp = 20
	op._simulation.decisions.go(returning, "building.1")
	test.assert_equal(returning.path.back(), nav.queue_point("building.1", returning.index), "released waiting point can be reused on the next visit")
