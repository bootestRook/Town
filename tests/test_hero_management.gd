extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_town_heroes.gd").new().fresh(7741, 48)
	var initial: Dictionary = op.snapshot()
	test.assert_equal(initial.main.deployment_capacity, 7, "camp level five reads seven activity positions from source")
	test.assert_equal(initial.main.team.size(), 3, "opening management never grants heroes or fills positions")
	for level: int in op._main_systems.camp.levels:
		op._state.buildings[TownHeroCamp.BUILDING] = level
		test.assert_equal(op.snapshot().main.deployment_capacity, int(op._main_systems.camp.levels[level].capacity), "every camp level reads actual building capacity")
	op._state.buildings[TownHeroCamp.BUILDING] = 5
	var expedition: Array = initial.main.expedition_team.duplicate()
	test.assert_true(op.main_command({"type":"hero_quick_deploy", "element":1}).accepted, "quick deployment is a real domain command")
	var snap: Dictionary = op.snapshot()
	test.assert_equal(snap.main.team.size(), 7, "quick deployment respects source camp capacity")
	test.assert_true(snap.main.roster.filter(func(h): return h.deployed).all(func(h): return h.combat.element == 1), "element filtering changes actual deployment")
	test.assert_equal(snap.main.expedition_team, expedition, "map deployment does not mutate five person expedition")
	test.assert_equal(snap.heroes.filter(func(h): return h.deployed).size(), 7, "domain command synchronizes map actors")
	var remaining: Array = snap.main.roster.filter(func(h): return not h.deployed and h.live != "")
	var before: Array = snap.main.team.duplicate()
	test.assert_true(not op.main_command({"type":"hero_team", "hero":remaining[0].id}).accepted, "full deployment rejects extra hero")
	test.assert_equal(op.snapshot().main.team, before, "rejected deployment is atomic")
	test.assert_true(not op.main_command({"type":"hero_quick_deploy", "element":99}).accepted, "invalid element cannot clear team")
	test.assert_equal(op.snapshot().main.team, before, "invalid quick request preserves all positions")
	var id: String = before[0]
	test.assert_true(op.main_command({"type":"hero_team", "hero":id}).accepted, "upper pedestal and card can withdraw")
	test.assert_true(op.main_command({"type":"hero_team", "hero":id}).accepted, "withdrawn hero can immediately redeploy without advancing time")
	test.assert_true(id in op.snapshot().main.team and op.snapshot().main.team.size() == before.size(), "immediate redeploy restores membership and capacity")
	test.assert_true(op.snapshot().heroes.filter(func(h): return h.id == id)[0].deployed, "immediate redeploy restores actual map actor state")
	test.assert_true(op.main_command({"type":"hero_team", "hero":id}).accepted, "same hero can immediately withdraw again")
	test.assert_true(op.main_command({"type":"hero_quick_deploy", "element":1}).accepted, "quick deployment immediately considers withdrawn heroes")
	test.assert_equal(op.snapshot().main.team, before, "quick deployment restores strongest team without a cooldown exclusion")
	test.assert_equal(op._state.time, initial.time, "repeated deployment does not require or consume simulation time")
	var team: Array = op.snapshot().main.team.duplicate()
	test.assert_true(op.main_command({"type":"expedition_team", "hero":expedition[0]}).accepted, "expedition remains editable independently")
	test.assert_equal(op.snapshot().main.team, team, "expedition toggles never change map membership")
	op._state.main.battle = {"status":"running"}
	op._state.main.expedition_team = [id]
	test.assert_true(not op.main_command({"type":"hero_team", "hero":id}).accepted, "active expedition member cannot be withdrawn")
	test.assert_true(op.main_command({"type":"hero_quick_deploy", "element":2}).accepted, "quick deploy retains unavailable members")
	test.assert_true(id in op._state.main.team, "unavailable hero retained even outside selected element")
	test.assert_true(op._state.main.team.size() <= 7, "retained members consume camp capacity")
	op._state.main.battle.clear()
	var defs: Dictionary = op.main_definitions()
	test.assert_equal(defs.hero_catalog.size(), defs.heroes.size(), "every imported hero has source catalog preview stage")
	for record: Dictionary in defs.hero_catalog.values():
		test.assert_true(defs.hero_talents.has(record.show_talent), "catalog stage resolves to source talent")
		test.assert_equal(defs.hero_talents[record.show_talent].star, record.star, "catalog stars come from show_id rather than owned rank")
	var hero: Dictionary = op.snapshot().main.roster[0]
	var view := MainDetailContent.build("catalog_hero", {"definition":hero.definition}, op.snapshot(), defs)
	test.assert_equal(view.buttons.size(), 0, "catalog preview has no growth mutations")
	test.assert_equal(op.snapshot().main.roster[0].star, hero.star, "max rank catalog preview never upgrades owned hero")
	test.assert_true(not op.main_command({"type":"hero_star", "hero":hero.id}).accepted, "insufficient fragment promotion rejects")
	op._state.main.fragments[hero.definition] = hero.fragment_cost
	test.assert_true(op.main_command({"type":"hero_star", "hero":hero.id}).accepted, "training promotion consumes actual soul stones")
	var upgraded: Dictionary = op.snapshot().main.roster[0]
	test.assert_equal(upgraded.fragments, 0, "promotion consumes exact fragment cost")
	test.assert_true(upgraded.star > hero.star and upgraded.stats.attack > hero.stats.attack, "promotion changes live talent and stats")
	test.assert_true(not op.main_command({"type":"hero_star", "hero":hero.id}).accepted, "repeat promotion cannot spend missing fragments")
	var owned: Array = op._state.main.roster.map(func(h): return h.definition)
	var reserve: String = defs.heroes.keys().filter(func(key): return key not in owned)[0]
	op._state.main.pool = [reserve]
	op._state.main.recruited.clear()
	op._state.inventory["item.10001"] = 1
	test.assert_true(op.main_command({"type":"recruit"}).accepted, "new recruit fixture uses actual acquisition command")
	var prior: Dictionary = op.snapshot()
	var recruited: Dictionary = prior.main.roster.filter(func(h): return h.definition == reserve)[0]
	test.assert_true(not recruited.live.is_empty(), "every new recruit has a real map actor")
	op._state.main.team.clear()
	test.assert_true(op.main_command({"type":"hero_team", "hero":recruited.id}).accepted, "newly recruited hero can deploy on the map")
