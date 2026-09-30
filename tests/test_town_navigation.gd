extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")


func run(test: TestSupport) -> void:
	var op = Heroes.new().fresh()
	var nav: TownNavigation = op._simulation.navigation
	test.assert_equal(nav.point(Vector2i(74, 34), "town"), Vector2(4370, 2430.5), "source hospital door uses its authored tile, not building center")
	test.assert_equal(nav.doors["building.1"], Vector2(4370, 2430.5), "hospital entrance matches source prefab")
	test.assert_equal(nav.regions.town.tile_width, 38, "native city diamond width")
	test.assert_equal(nav.regions.field.tile_width, 84, "native wilderness diamond width")
	var roundtrip := true
	for area: String in nav.cells:
		for cell: Vector2i in nav.cells[area]:
			roundtrip = roundtrip and nav.cell_at(nav.point(cell, area), area) == cell
	test.assert_true(roundtrip, "all native grid centers round trip without resampling")
	var blocked := true
	for x in range(69, 77):
		for y in range(35, 43):
			blocked = blocked and not nav.cells.town.has(Vector2i(x, y))
	test.assert_true(blocked, "entire hospital footprint is occupied from source lower corner")
	for door: Vector2 in nav.doors.values():
		var outward := nav.route(door, nav.field_center)
		var inward := nav.route(nav.field_center, door)
		test.assert_true(not outward.is_empty() and not inward.is_empty(), "each building can enter wilderness and return through source exits")
		test.assert_true(outward.any(func(p): return p in nav.exits.field) and inward.any(func(p): return p in nav.exits.field), "cross region routes use source entrances")
	_facing_and_distance(test, op)
	_combat_cells(test, op)


func _facing_and_distance(test: TestSupport, op) -> void:
	var hero: Dictionary = op._state.heroes[0]
	hero.direction = Vector2(1, -1)
	TownHeroStats.face(hero, Vector2.LEFT)
	test.assert_equal(hero.direction, Vector2(-1, -1), "horizontal turns preserve back-facing pose")
	TownHeroStats.face(hero, Vector2.DOWN)
	test.assert_equal(hero.direction, Vector2(-1, 1), "vertical turns preserve horizontal facing")
	var nav: TownNavigation = op._simulation.navigation
	hero.position = nav.town_center
	var origin: Vector2 = hero.position
	hero.path = [origin + Vector2(2, 0), origin + Vector2(4, 0), origin + Vector2(9, 0)]
	op._simulation.movement.step(hero, [], 0.05, 140)
	test.assert_true(hero.position.is_equal_approx(origin + Vector2(7, 0)), "short waypoints do not waste remaining frame distance")
	test.assert_equal(hero.animation, "move", "moving along short segments keeps locomotion")
	var clock: float = 0.3
	hero.animation_time = clock
	op._simulation.movement.step(hero, [], 0.005, 140)
	test.assert_equal(hero.animation_time, clock, "continuing movement does not restart the walk cycle")
	hero.position = origin
	hero.path = [origin + Vector2(2, 0), origin + Vector2(9, 0)]
	op._simulation.movement.step(hero, [], 0.05, 140, true)
	test.assert_equal(hero.position, origin + Vector2(2, 0), "field combat checks attack range at each completed step")
	test.assert_equal(hero.path.size(), 1, "field movement retains later cells for subsequent attack range checks")


func _combat_cells(test: TestSupport, op) -> void:
	var nav: TownNavigation = op._simulation.navigation
	var hero: Dictionary = op._state.heroes[0]
	var other: Dictionary = op._state.heroes[1]
	var monster: Dictionary = op._state.monsters[0]
	hero.position = nav.field_center
	hero.mode = "hunting"
	hero.path = []
	other.position = nav.point(nav.cell_at(hero.position, "field") + Vector2i(1, 0), "field")
	other.mode = "hunting"
	other.path = []
	test.assert_true(nav.occupied_cell(hero, [hero, other], other.position), "stationary combat actor owns its native field cell")
	other.path = [hero.position]
	test.assert_true(not nav.occupied_cell(hero, [hero, other], other.position), "moving actors do not create a hard circular collision")
	other.path = []
	other.needs.hp = 0
	test.assert_true(not nav.occupied_cell(hero, [hero, other], other.position), "dead actor releases its combat cell")
	monster.position = other.position
	hero.cooldown = 1
	var before: Vector2 = hero.position
	op._simulation.combat._engage(hero, monster, {"heroes": [hero], "monsters": [monster]}, 0.05)
	test.assert_equal(hero.position, before, "ranged actor in reach waits at its standing tile instead of invented kiting")
	test.assert_equal(hero.animation, "idle", "cooldown at a valid tile is idle, not walking in place")
	test.assert_equal(op._state.heroes.map(func(h): return h.base.attack_range), [300.0, 100.0, 300.0], "actual normal skill ranges override generic profession ranges")
