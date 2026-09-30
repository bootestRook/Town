extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")

class InvalidData extends DataRegistry:
	var mutation := ""
	func rows(table_name: String) -> Array:
		var result := super.rows(table_name).duplicate(true)
		if table_name == "town_monster_spawns":
			if mutation == "outside": result[0].grid_x = 999
			if mutation == "duplicate":
				result[0].grid_x = result[1].grid_x
				result[0].grid_y = result[1].grid_y
		if table_name == "town_region_members" and mutation == "capacity": result[0].count = 100
		if table_name == "town_monsters":
			if mutation == "radius": result[0].patrol_range = 1.0
		return result


func run(test: TestSupport) -> void:
	var op = Heroes.new().fresh(47115, 48)
	var state: Dictionary = op._state
	var combat: TownCombat = op._simulation.combat
	var nav: TownNavigation = op._simulation.navigation
	var monsters: Array = state.monsters
	var invalid := InvalidData.new()
	invalid.load_default()
	test.assert_equal(combat.population.validation_error(invalid), "", "source spawn data is valid")
	for mutation: String in ["outside", "duplicate", "capacity", "radius"]:
		invalid.mutation = mutation
		test.assert_true(not combat.population.validation_error(invalid).is_empty(), "invalid spawn configuration rejected: " + mutation)
	var counts := {}
	var used := {}
	for monster: Dictionary in monsters:
		counts[monster.name] = counts.get(monster.name, 0) + 1
		used[monster.spawn_id] = true
	test.assert_equal(counts, {"疾风狼":3,"棕熊":3}, "source stage one has three wolves and three bears")
	test.assert_equal(used.size(), 6, "initial six monsters use distinct authored points")
	test.assert_equal(combat.population.stage_for("field").normal_points.split(";").size(), 7, "source field one stage one provides seven candidate points")
	var small = Heroes.new().fresh()
	test.assert_equal(small._state.monsters.map(func(m):return m.spawn_id), monsters.map(func(m):return m.spawn_id), "owned roster size never scales field population or consumes field RNG")
	var other = Heroes.new().fresh(845)
	test.assert_true(other._state.monsters.map(func(m):return m.spawn_id) != monsters.map(func(m):return m.spawn_id), "different field seeds choose different spawn assignments")
	var hero: Dictionary = state.heroes[0]
	state.heroes = []
	var moved := {}
	var rested := {}
	var safe := true
	for frame in 2400:
		combat.step(state, 0.05, op)
		for monster: Dictionary in monsters:
			safe = safe and nav.zone(monster.position) == "field" and monster.position.distance_to(monster.spawn) <= 300.01
			if monster.position.distance_to(monster.spawn) > 5:
				moved[monster.id] = true
			if monster.animation == "idle" and monster.timer > 0:
				rested[monster.id] = true
	test.assert_true(safe, "two-minute idle patrol remains inside source radius and field")
	test.assert_equal(moved.size(), 6, "every monster patrols instead of standing in a grid")
	test.assert_equal(rested.size(), 6, "every monster pauses between patrol routes")
	var target: Dictionary = monsters[0]
	# Keep the credited killer present for the owned-hero experience system,
	# but out of combat while validating independent monster respawn timers.
	state.heroes = [hero]
	hero.deployed = false
	var spawn_history := {target.spawn_id:true}
	for cycle in 16:
		combat.defeat(target, hero, op)
		combat.step(state, 9.9, op)
		test.assert_equal(target.hp, 0.0, "dead monster never respawns before source ten-second timer")
		combat.step(state, 0.11, op)
		test.assert_true(target.hp == target.base.max_hp and target.mode == "patrol", "respawn restores health and patrol state")
		spawn_history[target.spawn_id] = true
		used.clear()
		for monster: Dictionary in monsters:
			used[monster.spawn_id] = true
		test.assert_equal(used.size(), 6, "repeated respawn never doubles up a reserved spawn")
	test.assert_true(spawn_history.size() > 1, "respawn reselects authored points rather than returning to one fixed position")
	test.assert_equal(monsters.size(), 6, "deaths and respawns preserve source population cap")
	# A nearby deployed hero interrupts patrol; withdrawal releases combat and resumes patrol.
	hero.position = target.position
	hero.previous_position = hero.position
	hero.needs.hp = 100.0
	hero.deployed = true
	state.heroes = [hero]
	combat.step(state, 0.05, op)
	test.assert_equal(target.mode, "hunting", "nearby deployed hero interrupts patrol")
	test.assert_equal(target.target, hero.id, "monster pursues the detected hero")
	op._simulation.standby.change(hero, false, state)
	combat.step(state, 0.05, op)
	test.assert_equal(target.mode, "patrol", "withdrawing target resumes monster patrol")
	print("FIELD_POPULATION ", JSON.stringify({"count":monsters.size(),"patrolled":moved.size(),"rested":rested.size(),"respawn_points":spawn_history.keys(),"patrol_safe":safe}))
