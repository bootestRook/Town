extends RefCounted


func fresh() -> TownOperations:
	return preload("res://tests/test_town_heroes.gd").new().fresh(8164, 48)


func run(test: TestSupport) -> void:
	var op := fresh()
	var nav := op._simulation.navigation
	test.assert_equal(nav.zone(Vector2(4484, 2345)), "town", "shared diagonal grid corner remains inside walkable town")
	var standby: Array = op._state.heroes.filter(func(h): return not h.deployed)
	var before: Array = standby.map(func(h): return {"position": h.position, "needs": h.needs.duplicate(), "wallet": h.wallet})
	test.assert_equal(standby.size(), 45, "explicit owned-roster fixture has 45 standby actors")
	op.advance(0.05)
	test.assert_true(standby.all(func(h): return h.animation == "move"), "all standby actors walk on the first simulation tick")
	var seen_idle := false
	var seen_move := false
	var bad := false
	var bad_sample := ""
	for second in 180:
		op.advance(1)
		for hero: Dictionary in standby:
			if nav.zone(hero.position) != "town" or hero.mode not in ["standby_idle", "standby_walk"] or hero.target != "standby":
				bad = true
				if bad_sample.is_empty(): bad_sample = "%s %s %s %s %s" % [hero.id, hero.position, nav.zone(hero.position), hero.mode, hero.target]
			seen_idle = seen_idle or hero.animation == "idle"
			seen_move = seen_move or hero.animation == "move"
	test.assert_true(not bad and seen_idle and seen_move, "standby walks and pauses entirely on source city navigation: " + bad_sample)
	for i in standby.size():
		var hero: Dictionary = standby[i]
		test.assert_true(hero.position != before[i].position, "each standby hero actually moves")
		test.assert_equal(hero.needs, before[i].needs, "standby does not lose needs or heal for free")
		test.assert_equal(hero.wallet, before[i].wallet, "standby does not trade or consume")
		test.assert_equal(hero.attack_serial, 0, "standby never attacks")
		test.assert_equal(hero.kills, 0, "standby never earns monster kills")
		test.assert_true(hero.bag.values().all(func(n): return n == 0), "standby collects no loot")
		if not hero.path.is_empty():
			test.assert_true(nav.rest_point_available(hero.path.back(), hero, op._state.heroes), "standby reserves separate rest destinations")
	var chosen: Dictionary = standby[0]
	test.assert_true(not op.summon(chosen.id).accepted, "standby cannot receive trade summons")
	op.select_hero(chosen.id)
	var focused_position: Vector2 = chosen.position
	op.advance(2)
	test.assert_true(chosen.position != focused_position, "focused standby continues roaming in town")
	op.select_hero("")
	var cancelled_position: Vector2 = chosen.position
	op.advance(8)
	test.assert_true(chosen.position != cancelled_position, "standby keeps roaming after focus cancellation")
	test.assert_true(op.main_command({"type":"hero_team", "hero":chosen.id}).accepted, "standby deploys through existing team command")
	op.advance(100)
	test.assert_true(chosen.deployed and chosen.attack_serial > 0, "deployed standby resumes real battle AI")
	_withdraw_field(test)
	_service_and_revival(test)
	_empty_team(test)
	print("STANDBY_PASS 3 deployed / 45 standby; city roaming, focus, withdrawal, service and revival")


func _withdraw_field(test: TestSupport) -> void:
	var op := fresh()
	var hero: Dictionary = op._state.heroes[0]
	var monster: Dictionary = op._state.monsters[0]
	hero.position = op._simulation.navigation.field_center
	hero.previous_position = hero.position
	hero.mode = "hunting"
	hero.needs.hp = 43.0
	hero.needs.energy = 35.0
	op._simulation.combat.sequence.begin(hero, monster)
	op._simulation.combat.sequence.begin(monster, hero)
	monster.target = hero.id
	op._state.projectiles.append({"source":hero.id, "target":monster.id})
	op._state.projectiles.append({"source":monster.id, "target":hero.id})
	var position: Vector2 = hero.position
	var attacks: int = hero.attack_serial
	var energy_before_withdrawal: float = hero.needs.energy
	test.assert_true(op.main_command({"type":"hero_team", "hero":hero.id}).accepted, "field hero can withdraw")
	test.assert_true(not hero.deployed and hero.mode == "standby_return", "withdrawing starts an actual return path")
	test.assert_equal(hero.position, position, "withdrawal never teleports")
	test.assert_true(hero.attack_state.is_empty() and monster.attack_state.is_empty() and op._state.projectiles.is_empty(), "withdrawal releases combat locks and pending projectiles")
	test.assert_equal(hero.needs.hp, 43.0, "withdrawal keeps damage")
	op.advance(100)
	test.assert_equal(op._simulation.navigation.zone(hero.position), "town", "withdrawn field hero reaches town")
	test.assert_equal(hero.attack_serial, attacks, "withdrawn hero cannot restart attacks")
	test.assert_equal(hero.needs.hp, 43.0, "standby return does not grant recovery")
	test.assert_equal(hero.needs.energy, energy_before_withdrawal, "standby return does not drain energy after the started attack cost")
	test.assert_true(op.main_command({"type":"hero_team", "hero":hero.id}).accepted, "withdrawn hero can redeploy")
	op.advance(0.1)
	test.assert_equal(hero.target, "building.1", "redeployment resumes need-driven service decision")


func _service_and_revival(test: TestSupport) -> void:
	var op := fresh()
	var hero: Dictionary = op._state.heroes[0]
	hero.position = op._simulation.navigation.queue_point("building.1", 0)
	hero.mode = "waiting"
	hero.target = "building.1"
	hero.needs.hp = 20.0
	op.produce("building.1", "item.20101")
	op.advance(0.05)
	test.assert_equal(hero.mode, "serving", "service begins before withdrawal")
	var paid: int = hero.wallet
	op.main_command({"type":"hero_team", "hero":hero.id})
	test.assert_equal(hero.mode, "serving", "paid service continues after withdrawal")
	op.advance(20)
	test.assert_equal(hero.wallet, paid, "paid service is not charged twice")
	test.assert_equal(hero.needs.hp, 100.0, "paid service still applies its recovery")
	test.assert_true(hero.mode in ["standby_idle", "standby_walk"], "finished service returns to standby")
	op = fresh()
	hero = op._state.heroes[0]
	op._simulation.combat.kill_hero(hero, op)
	op.main_command({"type":"hero_team", "hero":hero.id})
	op.advance(100)
	test.assert_equal(hero.revivals, 1, "withdrawn dead hero completes resurrection")
	test.assert_true(not hero.deployed and hero.mode in ["standby_idle", "standby_walk"], "revived withdrawn hero stays in town")


func _empty_team(test: TestSupport) -> void:
	var op := fresh()
	for id: String in op._state.main.team.duplicate():
		op.main_command({"type":"hero_team", "hero":id})
	op.advance(120)
	test.assert_equal(op._state.main.team.size(), 0, "all heroes may be on standby")
	test.assert_true(op._state.heroes.all(func(h): return not h.deployed and h.kills == 0), "empty team produces no map combat")
	test.assert_true(op.main_command({"type":"battle_start", "mode":"dungeon"}).accepted, "map standby preserves independent expedition party")
