extends RefCounted
const Heroes = preload("res://tests/test_town_heroes.gd")

func run(test: TestSupport) -> void:
	var op: TownOperations = Heroes.new().fresh()
	var s: Dictionary = op._state
	var regions: TownRegionLevels = op.regions
	var population: TownMonsterPopulation = regions.population
	var nav: TownNavigation = op._simulation.navigation
	var data := DataRegistry.new()
	data.load_default()
	test.assert_equal(s.monsters.size(),6,"initial unlocked forest has six ordinary monsters")
	test.assert_equal(data.rows("town_region_levels").size(),9,"three density levels per first-world region")
	test.assert_equal(data.rows("town_monsters").size(),15,"nine species plus six mutant definitions")
	var before := op.snapshot()
	for command: Dictionary in [{"area":"bad","level":1},{"area":"field","level":9},{"area":"field2","level":1},{"area":"field","level":3}]:
		test.assert_true(not regions.activate(command).accepted,"invalid or locked density rejected")
	test.assert_equal(op.snapshot(),before,"rejected region changes are atomic")
	var coins: int = s.coins
	var all_heroes: Array = s.heroes
	var hero: Dictionary = s.heroes[0]
	var old: Dictionary = s.monsters[0]
	hero.enemy = old.id
	hero.attack_state = {"target":old.id}
	s.projectiles.append({"source":hero.id,"target":old.id})
	test.assert_true(regions.activate({"area":"field","level":2}).accepted,"source forest level two has no dungeon gate")
	test.assert_equal(s.monsters.size(),8,"level two initial load is four wolves and four bears")
	test.assert_equal(s.coins,coins,"density activation does not consume gold")
	test.assert_true(hero.enemy.is_empty() and hero.attack_state.is_empty() and s.projectiles.is_empty(),"activation clears old attack targets and projectiles")
	var ids: Array = s.monsters.map(func(m):return m.id)
	regions.activate({"area":"field","level":2})
	test.assert_equal(s.monsters.map(func(m):return m.id),ids,"repeated active level is a no-op")
	# Source leader replaces a normal spawn only after five creations and sixty seconds.
	var target: Dictionary = s.monsters[0]
	s.heroes = []
	target.hp = 0
	s.time = 59
	population.respawn(target,s)
	test.assert_true(not target.leader,"leader cannot appear before initial sixty-second cooldown")
	target.hp = 0
	s.time = 60
	population.respawn(target,s)
	test.assert_equal(target.kind,"slnitouren","source minotaur replaces an eligible normal refresh")
	test.assert_equal(s.monsters.size(),8,"leader is a replacement, not an extra population slot")
	var other: Dictionary = s.monsters[4]
	other.hp = 0
	population.respawn(other,s)
	test.assert_true(not other.leader,"only one regional leader can be alive")
	population.defeated(target)
	target.hp = 0
	s.time = 119
	population.respawn(target,s)
	test.assert_true(not target.leader,"leader death starts sixty-second cooldown")
	s.heroes = all_heroes
	s.main.progress.dungeon = 30
	regions.sync_unlocked()
	for area: String in ["field","field2","field3"]:
		test.assert_true(regions.activate({"area":area,"level":3}).accepted,"dungeon progress unlocks third density "+area)
		var monsters: Array = s.monsters.filter(func(m):return m.area == area)
		test.assert_equal(monsters.size(),10,"third density preserves ten spawn slots "+area)
		test.assert_true(monsters.all(func(m):return nav.zone(m.position)==area),"all monsters use the corresponding region grid "+area)
		for monster: Dictionary in monsters:
			test.assert_true(data.rows("town_animations").any(func(a):return a.actor==monster.visual and a.direction=="back" and a.action=="death"),"original monster back death action imported")
		var normal: Dictionary = monsters.filter(func(m):return not m.leader)[0]
		population.cycles[area].created[normal.slot_kind] = 29
		normal.hp = 0
		population.respawn(normal,s)
		test.assert_true(normal.kind.ends_with(".mut"),"thirtieth creation becomes source mutant "+area)
		test.assert_equal(normal.base.max_hp,population.definitions[normal.slot_kind].max_hp*5,"mutant uses source five-times health")
		test.assert_equal(normal.base.attack,population.definitions[normal.slot_kind].attack,"mutant does not invent extra attack scaling")
		var blocker: Dictionary = monsters[1]
		blocker.mode = "hunting"
		blocker.path.clear()
		test.assert_true(nav.occupied_cell(hero,[hero,blocker],blocker.position),"stationary actors reserve combat cells in each area "+area)
	var first: Dictionary = s.monsters.filter(func(m):return m.area=="field2")[0]
	hero.position = nav.nearest(first.position+Vector2(20,20),"field2")
	hero.enemy = s.monsters.filter(func(m):return m.area=="field")[0].id
	hero.path.clear()
	op._simulation.combat.hunt(hero,s,0.05,op)
	var chosen := TownAttackSequence.find_actor(s,hero.enemy)
	test.assert_equal(chosen.area,"field2","hero chooses enemies only inside its current region")
	test.assert_true(hero.path.all(func(p):return nav.zone(p)=="field2"),"combat pursuit stays on its field grid")
	# The source town and field grids overlap at the gate; a pursuit can cross that seam.
	hero.position = Vector2(4121.354,2980.226)
	hero.mode = "hunting"
	hero.assigned_area = "field"
	op._simulation.combat.hunt(hero,s,0.05,op)
	test.assert_equal(hero.mode,"walking","a hunter at the town seam resumes its assigned expedition")
	test.assert_true(not hero.path.is_empty() and nav.zone(hero.path.back())=="field","gate recovery reaches the field instead of waiting for town monsters")
	var selected: Dictionary = s.region_levels.duplicate()
	s.horn.phase = "prepare"
	before = op.snapshot()
	test.assert_true(not regions.activate({"area":"field","level":1}).accepted,"horn gathering blocks density changes")
	test.assert_equal(op.snapshot(),before,"horn rejection preserves the encounter")
	s.horn.phase = "idle"
	s.monsters.clear()
	regions.restore()
	test.assert_equal(s.region_levels,selected,"horn restore preserves selected densities")
	test.assert_equal(s.monsters.size(),30,"horn restore repopulates unlocked areas at selected levels")
	regions.activate({"area":"field","level":1})
	test.assert_equal(s.monsters.filter(func(m):return m.area=="field").size(),6,"switching down removes extra slots and special species")
	test.assert_equal(s.monsters.filter(func(m):return m.area=="field2").size(),10,"switching one area does not alter another")
	print("REGION_LEVELS verified original density, unlocks, mutants, leaders, cross-region combat and horn restore")
