extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var twin = preload("res://tests/test_main_systems.gd").new().fresh()
	var hero: Dictionary = op._state.heroes.filter(func(h): return h.job == 1)[0]
	hero.bag["item.20101"] = 71
	var view: Dictionary = op.snapshot().main.roster.filter(func(h): return h.id == hero.id)[0]
	test.assert_equal(view.bag["item.20101"], 71, "hero bag uses private loot")
	view.bag["item.20101"] = 99
	test.assert_equal(hero.bag["item.20101"], 71, "bag snapshot cannot mutate owner")
	op._state.inventory["item.20101"] += 10
	test.assert_equal(hero.bag["item.20101"], 71, "public inventory does not alter hero bag")
	for owner in [op,twin]:
		for id: String in ["forge.11101","forge.20101","forge.40101"]:
			var recipe: Dictionary = owner.equipment_shop.recipes[id]
			preload("res://tests/test_equipment_shop.gd").new().supply(owner,recipe)
			test.assert_true(owner.craft(recipe.id,1).accepted,"equipment uses source recipe path")
	test.assert_equal(op._state.equipment[0].affixes,twin._state.equipment[0].affixes,"weapon RNG is deterministic")
	for recipe: Dictionary in op.recipes():
		for owner in [op, twin]:
			owner._state.inventory[recipe.material_a] += int(recipe.count_a)
			owner._state.inventory[recipe.material_b] += int(recipe.count_b)
		test.assert_true(op.craft(recipe.id, 1).accepted, "current source equipment can be crafted")
		twin.craft(recipe.id, 1)
		var item: Dictionary = op._state.equipment.back()
		var rule: Dictionary = op.main_definitions().equipment_rules[item.id]
		test.assert_true(item.affixes[0].value >= rule.minimum and item.affixes[0].value <= rule.maximum, "source affix interval preserved")
		test.assert_equal(item.affixes, twin._state.equipment.back().affixes, "equipment RNG is deterministic")
		test.assert_true(item.quality < rule.refine_quality, "current source recipes do not unlock refinement")
	var sword: Dictionary = op._state.equipment[0]
	test.assert_true(op.main_command({"type":"hero_equip","hero":hero.id,"serial":sword.serial}).accepted, "equip affixed sword")
	test.assert_true(hero.stats.attack > hero.base.attack + sword.power, "affix changes actual attack")
	var command := {"type":"hero_equipment_buyback","hero":hero.id,"slot":"1","serial":sword.serial}
	op._state.diamonds = 0
	var before: Dictionary = op.snapshot()
	test.assert_true(not op.main_command(command).accepted, "insufficient buyback funds rejected")
	test.assert_equal(op.snapshot(), before, "failed buyback leaves all state unchanged")
	op._state.diamonds = 30
	command.type = "hero_equipment_refine"
	before = op.snapshot()
	test.assert_true(not op.main_command(command).accepted, "source quality gate blocks refine")
	test.assert_equal(op.snapshot(), before, "refine rejection does not spend or roll")
	command.type = "hero_equipment_buyback"
	command.serial = -1
	test.assert_true(not op.main_command(command).accepted, "stale equipment instance rejected")
	command.serial = sword.serial
	op._state.main.battle = {"status":"running"}
	test.assert_true(not op.main_command(command).accepted, "combat blocks equipment mutation")
	op._state.main.battle = {}
	test.assert_true(op.main_command(command).accepted, "diamond buyback accepted")
	test.assert_equal(op.snapshot().diamonds, 24, "source recovery cost is six diamonds")
	test.assert_true(not hero.equipment.has("1"), "buyback clears hero slot")
	test.assert_equal(hero.stats.attack, float(hero.base.attack), "buyback removes base and affix effects")
	test.assert_equal(op._state.equipment.filter(func(e): return e.serial == sword.serial).size(), 1, "exact instance returns once")
	before = op.snapshot()
	test.assert_true(not op.main_command(command).accepted, "duplicate buyback rejected")
	test.assert_equal(op.snapshot(), before, "duplicate does not charge or duplicate item")
	command.hero = "missing"
	test.assert_true(not op.main_command(command).accepted, "invalid hero rejected")
	var armor: Dictionary = op._state.equipment.filter(func(e): return int(e.slot) == 2)[0]
	op.main_command({"type":"hero_equip","hero":hero.id,"serial":armor.serial})
	hero.needs.energy = 100
	TownHeroNeeds.consume_energy(hero, 10)
	test.assert_true(hero.needs.energy > 90 and hero.needs.energy < 100, "hunger capacity affix scales normalized consumption")
	var necklace: Dictionary = op._state.equipment.filter(func(e): return int(e.slot) == 6)[0]
	op.main_command({"type":"hero_equip","hero":hero.id,"serial":necklace.serial})
	var roster: Dictionary = op.snapshot().main.roster.filter(func(h): return h.id == hero.id)[0]
	var hero_definition: Dictionary = op.main_definitions().heroes[roster.definition]
	test.assert_equal(roster.combat.dodge, hero_definition.dodge + necklace.affixes[0].value, "necklace contributes actual expedition dodge")
	for definition: Dictionary in op.main_definitions().hero_idle.values():
		test.assert_true(definition.frames > 1 and definition.duration > 0, "source hero idle is a full loop")
