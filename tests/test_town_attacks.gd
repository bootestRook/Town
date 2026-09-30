extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")


func run(test: TestSupport) -> void:
	for index in 3:
		_timeline(test, index)
	_interruptions(test)
	_monsters(test)


func _timeline(test: TestSupport, index: int) -> void:
	var op = Heroes.new().fresh()
	var state: Dictionary = op._state
	var hero: Dictionary = state.heroes[index]
	var monster: Dictionary = state.monsters[0]
	var combat = op._simulation.combat
	var sequence = combat.sequence
	var definition: Dictionary = sequence.definitions[hero.visual]
	hero.position = monster.position - Vector2(300, 0)
	var hp: float = monster.hp
	sequence.begin(hero, monster)
	test.assert_equal(monster.hp, hp, "starting attack never immediately damages target")
	sequence.advance(hero, state, definition.windup - 0.01, combat, op)
	test.assert_equal(monster.hp, hp, "no damage during source windup")
	test.assert_true(state.projectiles.is_empty(), "no projectile before source release frame")
	sequence.advance(hero, state, 0.01, combat, op)
	if definition.fly_speed > 0:
		test.assert_equal(monster.hp, hp, "ranged release is not an instant hit")
		test.assert_equal(state.projectiles.size(), 1, "one original projectile launched")
		test.assert_equal(state.projectiles[0].resource, definition.projectile, "source projectile resource")
		sequence.advance_projectiles(state, 0.01, combat, op)
		test.assert_equal(monster.hp, hp, "projectile must actually reach its target")
		sequence.advance_projectiles(state, 0.4, combat, op)
	test.assert_true(monster.hp < hp, "source melee frame or projectile arrival applies damage")
	test.assert_equal(state.effects.back().resource, definition.impact, "source impact effect follows hit")
	var hit_hp: float = monster.hp
	sequence.advance(hero, state, 0.1, combat, op)
	sequence.advance_projectiles(state, 0.1, combat, op)
	test.assert_equal(monster.hp, hit_hp, "one attack cannot hit twice")
	test.assert_equal(hero.animation, "attack", "follow-through remains an attack")
	sequence.advance(hero, state, definition.duration, combat, op)
	test.assert_true(hero.attack_state.is_empty(), "source action completes")
	test.assert_equal(hero.animation, "idle", "completion returns to idle")


func _interruptions(test: TestSupport) -> void:
	var op = Heroes.new().fresh()
	var state: Dictionary = op._state
	var hero: Dictionary = state.heroes[0]
	var monster: Dictionary = state.monsters[0]
	var sequence = op._simulation.combat.sequence
	hero.position = monster.position - Vector2(160, 0)
	hero.mode = "hunting"
	sequence.begin(hero, monster)
	var position: Vector2 = hero.position
	op.summon(hero.id, "building.1")
	op.advance(0.2)
	test.assert_equal(hero.position, position, "ordinary retreat or summon cannot cut attack windup")
	test.assert_equal(hero.animation, "attack", "attack remains selected during windup")
	TownCombat.kill_hero(hero, op)
	test.assert_true(hero.attack_state.is_empty(), "death cancels unlaunched attack")
	test.assert_true(state.projectiles.is_empty(), "dead caster cannot launch later")
	var archer: Dictionary = state.heroes[2]
	sequence.begin(archer, monster)
	sequence.advance(archer, state, 0.6, op._simulation.combat, op)
	var before: int = archer.wallet
	op._simulation.combat.defeat(monster, hero, op)
	sequence.advance_projectiles(state, 1.0, op._simulation.combat, op)
	test.assert_true(state.projectiles.is_empty(), "dead target removes pending projectile")
	test.assert_equal(archer.wallet, before, "dead target cannot yield a second reward")


func _monsters(test: TestSupport) -> void:
	var op = Heroes.new().fresh()
	var sequence = op._simulation.combat.sequence
	test.assert_equal(sequence.definitions.wolf.windup, 0.277, "source wolf impact at 277ms")
	test.assert_equal(sequence.definitions.bear.windup, 0.333, "source bear impact at 333ms")
	for visual: String in ["wolf", "bear"]:
		var monster: Dictionary = op._state.monsters.filter(func(m):return m.visual == visual)[0]
		var hero: Dictionary = op._state.heroes[0]
		var hp: float = hero.needs.hp
		sequence.begin(monster, hero)
		sequence.advance(monster, op._state, 0.2, op._simulation.combat, op)
		test.assert_equal(hero.needs.hp, hp, "monster windup cannot deal early damage")
		sequence.advance(monster, op._state, 0.14, op._simulation.combat, op)
		test.assert_true(hero.needs.hp < hp, "monster damage lands at configured windup")
