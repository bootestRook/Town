extends RefCounted


func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var initial: Dictionary = op.snapshot()
	test.assert_equal(initial.heroes.map(func(h): return h.name), ["艾比", "特伦斯", "芭芭拉"], "new game owns exactly the three requested starters")
	test.assert_equal(initial.main.roster.size(), 3, "resource catalogue never grants ownership")
	test.assert_true(initial.main.roster.all(func(h): return h.quality == 2 and h.deployed), "all three starters are green and deployed")
	test.assert_equal(initial.main.team, initial.heroes.map(func(h): return h.id), "map team contains the three starters")
	test.assert_equal(initial.main.expedition_team, initial.main.team, "initial expedition party contains only starters")
	var starter: Dictionary = op._state.heroes[0]
	var origin: Vector2 = starter.position
	op.main_command({"type":"hero_team", "hero":starter.id})
	test.assert_equal(starter.mode, "standby_walk", "withdrawing in town starts a route immediately")
	test.assert_true(not starter.path.is_empty() and starter.animation == "move", "standby has a walk action before any wait period")
	op.advance(0.05)
	test.assert_true(starter.position.distance_to(origin) > 0.1, "standby moves on the very first 50 ms simulation step")
	op.main_command({"type":"hero_team", "hero":starter.id})
	var available: Array = op.main_definitions().heroes.values()
	var owned: Array = op._state.main.roster.map(func(h): return h.definition)
	var unowned: Array = available.filter(func(d): return d.id not in owned)
	# Every existing recruit, including the 26 formerly unbaked appearances, follows the real command.
	op._state.inventory["item.10001"] = unowned.size() + 3
	var last_id := ""
	for definition: Dictionary in unowned:
		var count: int = op._state.heroes.size()
		op._state.main.pool = [definition.id]
		op._state.main.recruited.clear()
		var receipt: Dictionary = op.main_command({"type":"recruit"})
		test.assert_true(receipt.accepted and receipt.recruitment.new, "first acquisition succeeds")
		test.assert_equal(op._state.heroes.size(), count + 1, "recruitment creates exactly one map actor")
		var entry: Dictionary = op._state.main.roster.filter(func(h): return h.definition == definition.id)[0]
		var actor: Dictionary = op._state.heroes.filter(func(h): return h.id == entry.live)[0]
		test.assert_equal(actor.base.source_appearance, definition.appearance, "recruit uses its own source appearance")
		test.assert_true(not actor.deployed and actor.mode == "standby_walk" and not actor.path.is_empty(), "new recruit starts walking in town without automatically deploying")
		test.assert_true(op._simulation.navigation.zone(actor.position) == "town", "new recruit enters a legal town arrival position")
		origin = actor.position
		op.advance(0.05)
		test.assert_true(actor.position.distance_to(origin) > 0.1, "new recruit is never gated by catalogue start_delay")
		last_id = actor.id
	test.assert_equal(op._state.heroes.size(), available.size(), "whole existing recruit catalogue can inhabit the map")
	test.assert_equal(op._state.main.team.size(), 3, "recruiting the whole catalogue leaves the player's team unchanged")
	var hero: Dictionary = op._state.heroes.back()
	var entry: Dictionary = op._state.main.roster.filter(func(h): return h.id == hero.id)[0]
	var path: Array = hero.path.duplicate()
	var position: Vector2 = hero.position
	op._state.main.pool = [entry.definition]
	op._state.main.recruited.clear()
	var repeat: Dictionary = op.main_command({"type":"recruit"})
	test.assert_true(repeat.accepted and not repeat.recruitment.new and repeat.recruitment.fragments > 0, "duplicate still awards soul stones")
	test.assert_equal(op._state.heroes.size(), available.size(), "duplicate never clones the actor")
	test.assert_equal(hero.path, path, "duplicate does not restart standby path")
	test.assert_equal(hero.position, position, "duplicate never teleports the actor")
	test.assert_true(op.main_command({"type":"hero_team", "hero":last_id}).accepted, "new recruit can actually deploy")
	test.assert_true(hero.deployed and hero.mode == "idle", "deployment resumes active decisions")
	test.assert_true(not op.main_command({"type":"hero_release", "hero":last_id}).accepted, "deployed hero cannot be dismissed")
	op.main_command({"type":"hero_team", "hero":last_id})
	op.select_hero(last_id)
	test.assert_true(op.main_command({"type":"hero_release", "hero":last_id}).accepted, "withdrawn recruit can be dismissed")
	test.assert_true(not op._state.heroes.any(func(h): return h.id == last_id), "dismissal removes the real actor")
	test.assert_equal(op._state.selected_hero, "", "dismissal releases map focus")
	test.assert_true(not op.main_command({"type":"hero_release", "hero":"hero.1"}).accepted, "initial hero protection remains")
	var before: Dictionary = op.snapshot()
	test.assert_true(not op.main_command({"type":"hero_team", "hero":last_id}).accepted, "unowned actor cannot deploy")
	test.assert_equal(op.snapshot(), before, "invalid deployment is atomic")
	print("TOWN_ACQUISITION 3 starters; all %d recruit identities enter town; immediate standby, duplicate and dismissal verified" % available.size())
