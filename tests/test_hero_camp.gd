extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_town_heroes.gd").new().fresh(84713, 48)
	var before: Dictionary = op.snapshot()
	test.assert_equal(before.buildings[TownHeroCamp.BUILDING], 5, "existing demo camp level becomes actual building state")
	test.assert_true(not before.main.has("camp_level"), "obsolete independent camp level removed")
	test.assert_equal(before.camp.cost, 150000, "source level five upgrade costs 150000 coins")
	test.assert_equal(before.camp.preview, [{"level":6,"before":7,"after":8},{"level":7,"before":8,"after":9}], "preview shows next two source levels")
	op._state.coins = 149999
	test.assert_true(not op.upgrade(TownHeroCamp.BUILDING).accepted, "insufficient coins reject upgrade")
	test.assert_equal(op.snapshot().buildings[TownHeroCamp.BUILDING], 5, "failed upgrade preserves actual level")
	test.assert_equal(op.snapshot().coins, 149999, "failed upgrade does not spend coins")
	op._state.city_level = 1
	op._state.main.progress.clear()
	op._state.coins = 150000
	var diamonds: int = op.snapshot().diamonds
	var inventory: Dictionary = op.snapshot().inventory
	test.assert_true(op.main_command({"type":"hero_quick_deploy", "element":0}).accepted, "fill original capacity")
	test.assert_equal(op.snapshot().main.team.size(), 7, "level five caps actual deployment at seven")
	var candidate: String = op.snapshot().main.roster.filter(func(h): return not h.deployed)[0].id
	test.assert_true(not op.main_command({"type":"hero_team", "hero":candidate}).accepted, "eighth hero rejected before upgrade")
	test.assert_true(op.upgrade(TownHeroCamp.BUILDING).accepted, "exact coins suffice without city dungeon material or unlock conditions")
	var upgraded: Dictionary = op.snapshot()
	test.assert_equal(upgraded.buildings[TownHeroCamp.BUILDING], 6, "upgrade writes real building level")
	test.assert_equal(upgraded.coins, 0, "source coin price deducted exactly once")
	test.assert_equal(upgraded.diamonds, diamonds, "upgrade never charges diamonds")
	test.assert_equal(upgraded.inventory, inventory, "upgrade never consumes original unlock materials")
	test.assert_equal(upgraded.main.deployment_capacity, 8, "deployment capacity updates immediately")
	test.assert_equal(upgraded.main.team.size(), 7, "upgrade does not change player's formation")
	test.assert_true(op.main_command({"type":"hero_team", "hero":candidate}).accepted, "eighth hero can actually deploy after upgrade")
	test.assert_equal(op.snapshot().heroes.filter(func(h): return h.deployed).size(), 8, "eighth map actor is active")
	test.assert_equal(op.snapshot().main.expedition_team, before.main.expedition_team, "five-person independent challenge is preserved")
	test.assert_true(not op.upgrade(TownHeroCamp.BUILDING).accepted, "rapid repeat cannot spend nonexistent coins")
	op._state.coins = 20000000
	for level in range(6,13):
		var current: Dictionary = op.snapshot()
		test.assert_true(op.upgrade(TownHeroCamp.BUILDING).accepted, "every remaining source upgrade succeeds with coins")
		var after: Dictionary = op.snapshot()
		test.assert_equal(after.coins, current.coins - int(current.camp.cost), "each level spends its own configured coin cost")
		test.assert_equal(after.main.deployment_capacity, level + 3, "actual deployment uses upgraded capacity through level thirteen")
	var full: Dictionary = op.snapshot()
	test.assert_true(full.camp.max_level and full.camp.preview.is_empty(), "maximum has no nonexistent preview")
	test.assert_equal(full.camp.capacity, 15, "source level thirteen capacity is fifteen")
	test.assert_true(not op.upgrade(TownHeroCamp.BUILDING).accepted, "max level rejects repeated upgrade")
	test.assert_equal(op.snapshot().coins, full.coins, "max level never charges coins")
	test.assert_true(op.main_command({"type":"hero_quick_deploy", "element":0}).accepted, "quick deployment fills upgraded maximum")
	test.assert_equal(op.snapshot().heroes.filter(func(h): return h.deployed).size(), 15, "all fifteen are authoritative active actors")
	full.camp.capacity = 99
	test.assert_equal(op.snapshot().camp.capacity, 15, "snapshot edits never mutate definitions")
