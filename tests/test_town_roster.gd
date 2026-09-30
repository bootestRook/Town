extends RefCounted


func run(test: TestSupport) -> void:
	var data := DataRegistry.new()
	data.load_default()
	# Explicit full-roster pressure fixture; production starts with only three.
	var op = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	var nav: TownNavigation = op._simulation.navigation
	var heroes: Array = op._state.heroes
	var counts := {}
	for hero: Dictionary in op.snapshot().main.roster:
		var key := "%d.%d" % [hero.quality, hero.job]
		counts[key] = counts.get(key, 0) + 1
	test.assert_equal(heroes.size(), 48, "45 new map heroes plus original three")
	for quality in [2, 3, 4, 5]:
		for job in [1, 2, 3]:
			test.assert_equal(counts["%d.%d" % [quality, job]], {2:2, 3:4, 4:5, 5:5}[quality], "requested rarity and profession quota")
	test.assert_equal(op._state.main.team.size(), 3, "only original three heroes initially deploy")
	test.assert_equal(heroes.filter(func(h): return h.deployed).size(), 3, "town deployment follows the roster")
	var animations := {}
	for row: Dictionary in data.rows("town_animations"):
		animations[row.id] = row
	for hero: Dictionary in heroes:
		test.assert_true(nav.passable(hero.position), "hero spawns on source walkable grid")
		for direction in ["front", "back"]:
			for action in ["idle", "move", "attack", "death"]:
				test.assert_true(animations.has("%s_%s_%s" % [hero.visual, direction, action]), "each hero has a complete front/back action set")
		for other: Dictionary in heroes:
			if hero.index > other.index:
				test.assert_true(_separated(hero.position, other.position), "spawn footprints do not overlap")
	for building: String in nav.doors:
		for index in heroes.size():
			var point := nav.queue_point(building, index)
			test.assert_true(point.is_finite() and not nav.route(nav.town_center, point).is_empty(), "all 48 building waiting positions are reachable")
	# Real simultaneous hospital routes exercise reservations and overflowing the source perimeter.
	op._state.monsters.clear()
	for hero: Dictionary in heroes:
		# Deliberate 48-active stress fixture, beyond the ordinary five-person team.
		hero.deployed = true
		hero.needs.hp = 20
		op._simulation.decisions.go(hero, "building.1")
		for other: Dictionary in heroes:
			if other.index < hero.index:
				test.assert_true(_separated(hero.path.back(), other.path.back()), "travelling heroes reserve different arrival positions")
	op.advance(45)
	test.assert_true(heroes.all(func(h): return h.mode == "waiting" and h.target == "building.1"), "all 48 heroes reach hospital without an unreachable loop")
	var positions: Array = heroes.map(func(h): return h.position)
	op.advance(5)
	test.assert_equal(heroes.map(func(h): return h.position), positions, "crowded waiting remains stable")
	op.produce("building.1", "item.20101")
	op.advance(0.1)
	test.assert_equal(heroes.filter(func(h): return h.mode == "serving").size(), 1, "crowd obeys one-seat hospital capacity")
	for hero: Dictionary in heroes:
		test.assert_equal(hero.position, positions[hero.index], "admitting one hero does not collapse the queue")
	var last: Dictionary = heroes.back()
	op._simulation.decisions.go(last, "building.7")
	test.assert_true(last.target == "building.7" and not last.path.is_empty(), "last new hero can leave the hospital queue for a different building")
	print("ROSTER_48 ", JSON.stringify({"quotas": counts, "waiting": heroes.filter(func(h): return h.mode == "waiting").size()}))
	_crowd_loop(test)


func _crowd_loop(test: TestSupport) -> void:
	var op = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	for hero: Dictionary in op._state.heroes: op._simulation.standby.change(hero, true, op._state)
	var late_rewards := 0
	var invalid := false
	for second in range(0, 600, 5):
		for material: String in ["item.20101", "item.20102", "item.20103", "item.20104", "item.20206", "item.20302", "item.20304"]:
			if not op._state.orders.has(material): op.set_order(material, 200)
		for building: String in op.services():
			var material: String = op.services()[building].material
			if op._state.inventory[material] > 0: op.produce(building, material)
		op.advance(5)
		if second == 450: late_rewards = op._state.counts.get("战利品", 0)
		for hero: Dictionary in op._state.heroes:
			invalid = invalid or not op._simulation.navigation.passable(hero.position) or hero.reason == "道路暂不可达" or hero.wallet < 0
	test.assert_true(not invalid, "48 heroes preserve reachable paths and nonnegative wallets over ten minutes")
	test.assert_true(op._state.heroes.all(func(h): return h.attack_serial > 0), "each of the 48 heroes performs actual attacks")
	test.assert_true(op._state.counts.get("战利品", 0) > late_rewards, "crowd continues combat through the last 150 seconds")
	for kind: String in ["战利品", "冒险归来", "收购", "生产", "消费", "使用完成"]:
		test.assert_true(op._state.counts.get(kind, 0) > 0, "48 hero loop includes " + kind)
	print("CROWD_SOAK ", JSON.stringify({"seconds":600,"counts":op._state.counts,"attacks":op._state.heroes.map(func(h): return h.attack_serial),"late_rewards":late_rewards}))


func _separated(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) >= 60.0 or absf(a.y - b.y) >= 80.0
