extends RefCounted

func run(test: TestSupport) -> void:
	var data := DataRegistry.new()
	assert(data.load_default().is_empty())
	var op := TownOperations.new(data, RngSet.new(582))
	var hero: Dictionary = op._state.heroes[0]
	var before: Dictionary = op.snapshot()
	test.assert_true(not op.main_command({"type":"hero_dispatch", "assignments":{hero.id:"missing"}}).accepted, "invalid dispatch map rejected")
	test.assert_equal(op.snapshot(), before, "invalid map cannot mutate state")
	test.assert_true(not op.main_command({"type":"hero_dispatch", "assignments":{"missing":"town"}}).accepted, "invalid dispatch hero rejected")
	var standby_id: String = op._state.heroes[1].id
	op.main_command({"type":"hero_team", "hero":standby_id})
	test.assert_true(not op.main_command({"type":"hero_dispatch", "assignments":{standby_id:"field"}}).accepted, "standby hero cannot silently deploy through dispatch")
	op.main_command({"type":"hero_team", "hero":standby_id})
	hero.position = op._simulation.navigation.field_center
	hero.previous_position = hero.position
	hero.mode = "hunting"
	hero.path.clear()
	hero.needs.hp = 43.0
	var original: Vector2 = hero.position
	var monster: Dictionary = op._state.monsters[0]
	op._simulation.combat.sequence.begin(monster, hero)
	monster.target = hero.id
	op._state.projectiles.append({"source":monster.id, "target":hero.id})
	test.assert_true(op.main_command({"type":"hero_dispatch", "assignments":{hero.id:"town"}}).accepted, "city dispatch accepted")
	test.assert_true(hero.deployed and hero.assigned_area == "town", "city assignment preserves combat team membership")
	test.assert_equal(hero.position, original, "dispatch returns along navigation instead of teleporting")
	test.assert_true(hero.mode == "standby_return" and hero.attack_state.is_empty() and monster.target.is_empty() and op._state.projectiles.is_empty(), "dispatch releases encounter locks and projectiles")
	op.advance(100)
	test.assert_equal(op._simulation.navigation.zone(hero.position), "town", "city assigned hero reaches city")
	test.assert_equal(hero.needs.hp, 43.0, "dispatch grants no free healing")
	test.assert_equal(hero.attack_serial, 0, "city assignment prevents automatic attacks")
	test.assert_true(op.main_command({"type":"hero_dispatch", "assignments":{hero.id:"field"}}).accepted, "field assignment restores adventuring")
	op.advance(0.1)
	test.assert_true(hero.assigned_area != "town" and hero.mode not in ["standby_idle", "standby_walk", "standby_return"], "field hero resumes normal needs-driven simulation")
	op._state.main.battle = {"status":"running"}
	before = op.snapshot()
	test.assert_true(not op.main_command({"type":"hero_dispatch", "assignments":{hero.id:"town"}}).accepted, "active battle protects assignment")
	test.assert_equal(op.snapshot(), before, "rejected battle dispatch is atomic")
	var definitions: Dictionary = op.main_definitions()
	for row: Dictionary in op.snapshot().main.roster:
		test.assert_true(definitions.star_display.has(row.star), "source star display exists for each map hero")
	test.assert_equal(op.snapshot().main.map_capacity, 3, "map actor count follows the initial owned roster")
	_four_regions(test, data)


func _four_regions(test: TestSupport, data) -> void:
	var op := TownOperations.new(data, RngSet.new(582))
	var hero: Dictionary = op._state.heroes[0]
	var nav := op._simulation.navigation
	var initial := op.snapshot()
	test.assert_equal(nav.regions.size(), 4, "four original region grids")
	for area: String in ["field2", "field3"]:
		test.assert_true(not op.main_command({"type":"dispatch_preview","area":area,"heroes":[hero.id]}).accepted, "locked preview rejected")
		test.assert_true(not op.main_command({"type":"hero_dispatch","assignments":{hero.id:area},"confirmed":{hero.id:area}}).accepted, "confirmation cannot bypass dungeon gate")
	test.assert_equal(op.snapshot(), initial, "locked dispatch cannot mutate any game state")
	op._state.main.progress.dungeon = 9
	test.assert_true(op.snapshot().main.dispatch.field2.unlocked and not op.snapshot().main.dispatch.field3.unlocked, "source graveyard gate at ninth cleared dungeon")
	op._state.main.progress.dungeon = 18
	initial = op.snapshot()
	var preview := op.main_command({"type":"dispatch_preview","area":"field3","heroes":op._state.main.team})
	test.assert_true(preview.accepted and preview.weak.size() == 3, "recommended power is a confirmable warning")
	test.assert_equal(op.snapshot(), initial, "preview is read only")
	test.assert_true(not op.main_command({"type":"hero_dispatch","assignments":{hero.id:"field3"}}).accepted, "weak dispatch requires explicit confirmation")
	test.assert_true(not op.main_command({"type":"hero_dispatch","assignments":{hero.id:"town", "bad":"field"}}).accepted, "invalid batch is rejected atomically")
	test.assert_equal(op.snapshot(), initial, "failed batch does not apply an earlier valid row")
	for from: String in nav.regions:
		for to: String in nav.regions:
			if from == to: continue
			var start := nav.center(from)
			var destination := nav.center(to)
			var path := nav.route(start, destination)
			test.assert_true(not path.is_empty(), "reachable route %s -> %s" % [from,to])
			var safe := true
			var previous := start
			for point: Vector2 in path:
				for sample in range(1, 11): safe = safe and nav.passable(previous.lerp(point, sample/10.0))
				previous = point
			test.assert_true(safe, "whole path stays on native walkable grids %s -> %s" % [from,to])
			if from != "town" and to != "town":
				test.assert_true(path.any(func(p): return p in nav.exits[from]) and path.any(func(p): return p in nav.exits[to]), "field transfer uses both original city gates")
	# Speeding up the fixture keeps this behavioral journey bounded; it still takes
	# each actual waypoint and never changes position during the dispatch command.
	hero.base.speed = 300.0
	hero.base.city_speed = 300.0
	hero.skip_shopping = 10000
	hero.stats.max_hp = 10000000.0
	for area: String in ["field2", "field3", "town"]:
		for stat: String in hero.needs: hero.needs[stat] = 100.0
		var start: Vector2 = hero.position
		test.assert_true(op.main_command({"type":"hero_dispatch","assignments":{hero.id:area},"confirmed":{hero.id:area}}).accepted,"confirmed four-area dispatch accepted")
		test.assert_equal(hero.position, start, "dispatch does not teleport")
		var reached := false
		for frame in 1600:
			var old: Vector2 = hero.position
			op.advance(0.05)
			if old.distance_to(hero.position) > 15.01: test.assert_true(false,"movement cannot teleport between regions")
			if nav.zone(hero.position) == area and (area == "town" or hero.mode == "hunting"):
				reached = true
				break
		test.assert_true(reached, "hero actually reaches " + area)
		if area != "town":
			test.assert_true(op._state.monsters.any(func(m): return m.area == area and m.hp > 0), "dispatched field has real monster population")
	# A building summon must return from the new field and resume its assigned area.
	op.main_command({"type":"hero_dispatch","assignments":{hero.id:"field2"},"confirmed":{hero.id:"field2"}})
	for stat: String in hero.needs: hero.needs[stat] = 100.0
	for frame in 1600:
		op.advance(0.05)
		if hero.mode == "hunting": break
	test.assert_true(op.summon(hero.id).accepted,"new-area hero can be summoned to exchange")
	var visited_town := false
	var resumed := false
	for frame in 2400:
		op.advance(0.05)
		visited_town = visited_town or nav.zone(hero.position) == "town"
		if visited_town and hero.mode == "hunting" and nav.zone(hero.position) == "field2":
			resumed = true
			break
	test.assert_true(visited_town and resumed,"building visit returns along real route to assigned graveyard")
	op.main_command({"type":"hero_dispatch","assignments":{hero.id:"field3"},"confirmed":{hero.id:"field3"}})
	op.advance(0.05)
	hero.needs.hp = 29.0
	op.advance(0.05)
	test.assert_equal(hero.target,"building.1","injured hero on any field route detours to hospital")
