extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var before: Dictionary = op.snapshot()
	for amount in ["", "abc", "12.5", "0", "-3", str(before.coins + 1)]:
		test.assert_true(not op.main_command({"type": "hero_donate", "hero": "hero.1", "amount": amount}).accepted, "invalid hero donation rejected: " + amount)
	test.assert_equal(op.snapshot().coins, before.coins, "failed donation keeps public gold")
	test.assert_true(op.main_command({"type": "hero_donate", "hero": "hero.1", "amount": "123"}).accepted, "donation accepted")
	var after: Dictionary = op.snapshot()
	test.assert_equal(after.coins, before.coins - 123, "donation deducts public wallet")
	test.assert_equal(after.main.roster[0].wallet, before.heroes[0].wallet + 123, "donation credits authoritative hero wallet")
	test.assert_equal(after.main.roster[0].needs, after.heroes[0].needs, "hero page has live needs snapshot")
	after.main.roster[0].needs.energy = -10
	test.assert_true(op.snapshot().heroes[0].needs.energy >= 0, "UI snapshot cannot mutate needs")
	var hero: Dictionary = op._state.heroes[0]
	hero.needs.magic = 4
	op._state.main.energy = 2
	TownHeroNeeds.purify(hero, op._state)
	test.assert_equal(hero.needs.magic, 2, "purification capped at available power")
	test.assert_equal(op._state.main.energy, 0, "purification spends one power per magic")
	TownHeroNeeds.purify(hero, op._state)
	test.assert_equal(hero.needs.magic, 2, "empty power cannot clear magic")
	hero.needs.energy = 0
	test.assert_true(not TownHeroNeeds.attack(hero), "zero hunger blocks attack")
	hero.needs.energy = 100
	hero.needs.tired = 0
	test.assert_true(not TownHeroNeeds.attack(hero), "zero fatigue blocks attack")
	hero.needs.tired = 100
	test.assert_true(TownHeroNeeds.attack(hero), "healthy hero can attack")
	test.assert_true(hero.needs.energy < 100, "attack consumes hunger")
	TownHeroNeeds.injured(hero)
	test.assert_true(hero.needs.mood < 100, "injury consumes mood")
	hero.needs.mood = 0
	test.assert_equal(TownHeroNeeds.attack_multiplier(hero), 0.9, "zero mood lowers attack ten percent")
	var definitions: Dictionary = op.main_definitions()
	var skills := {}
	for talent: Dictionary in op._main_systems.management.talents.values():
		for token in String(talent.skills).split("|").slice(1):
			skills[int(token.get_slice(";",0))] = true
	for skill: int in skills:
		test.assert_true(definitions.skill_art.has(skill), "source hero skill artwork indexed by integer id %d" % skill)
