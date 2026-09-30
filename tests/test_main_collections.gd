extends RefCounted

func fresh():
	var data := DataRegistry.new()
	assert(data.load_default().is_empty())
	return TownOperations.new(data, RngSet.new(9123))

func run(test: TestSupport) -> void:
	var op = fresh()
	var definitions: Dictionary = op.main_definitions()
	test.assert_equal(definitions.pets.size(), 336, "all source pet star stages")
	test.assert_equal(definitions.artifacts.size(), 95, "all source artifact definitions")
	test.assert_true(op.snapshot().main.collections.is_empty(), "no invented starting collection")
	var before: Dictionary = op.snapshot()
	test.assert_true(not op.main_command({"type": "item_use", "item": 200001}).accepted, "empty egg inventory rejected")
	test.assert_equal(op.snapshot(), before, "failed item use is atomic")
	# Source egg weights are deterministic and do not perturb recruitment.
	var other = fresh()
	op._state.inventory["item.200001"] = 3
	other._state.inventory["item.200001"] = 3
	for i in 3:
		test.assert_true(op.main_command({"type": "item_use", "item": 200001}).accepted, "egg creates owned pet")
		other.main_command({"type": "item_use", "item": 200001})
	test.assert_equal(op.snapshot().main.collections, other.snapshot().main.collections, "collection named stream replays")
	var clean = fresh()
	op._state.inventory["item.10001"] = 1
	clean._state.inventory["item.10001"] = 1
	op.main_command({"type": "recruit"})
	clean.main_command({"type": "recruit"})
	test.assert_equal(op.snapshot().main.last_recruit, clean.snapshot().main.last_recruit, "egg draws do not perturb recruitment stream")
	var object: Dictionary = op.snapshot().main.collections[0]
	var hero: Dictionary = op.snapshot().heroes[0]
	test.assert_true(op.main_command({"type": "collection_equip", "object": object.id, "hero": hero.id}).accepted, "pet equips")
	test.assert_equal(op.snapshot().heroes[0].stats.attack, hero.stats.attack + object.stats.attack, "pet bonus reaches live world stats")
	test.assert_equal(op.snapshot().main.roster[0].stats.attack, op.snapshot().heroes[0].stats.attack, "HUD and live hero use same pet bonus")
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "collection_level", "object": object.id}).accepted, "missing mushroom blocks upgrade")
	test.assert_equal(op.snapshot(), before, "partial currency availability does not consume gold")
	op._state.inventory["item.11310"] = 100
	op._state.coins = 100000
	test.assert_true(op.main_command({"type": "collection_level", "object": object.id}).accepted, "source pet upgrade")
	test.assert_equal(op.snapshot().main.collections[0].level, 2, "pet level advances")
	test.assert_true(op.snapshot().heroes[0].stats.attack > before.heroes[0].stats.attack, "upgrade reapplies authoritative bonus")
	test.assert_true(not op.main_command({"type": "collection_dismantle", "object": object.id}).accepted, "equipped pet protected")
	op.main_command({"type": "collection_unequip", "object": object.id})
	test.assert_equal(op.snapshot().heroes[0].stats.attack, hero.stats.attack, "unequip removes bonus exactly")
	op.main_command({"type": "collection_lock", "object": object.id})
	test.assert_true(not op.main_command({"type": "collection_dismantle", "object": object.id}).accepted, "locked pet protected")
	op.main_command({"type": "collection_lock", "object": object.id})
	test.assert_true(op.main_command({"type": "collection_reset", "object": object.id}).accepted, "pet level reset refunds")
	test.assert_equal(op.snapshot().main.collections[0].level, 1, "pet reset level")
	test.assert_true(op.main_command({"type": "collection_dismantle", "object": object.id}).accepted, "idle pet dismantles")
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "collection_dismantle", "object": object.id}).accepted, "dismantle cannot repeat")
	test.assert_equal(op.snapshot(), before, "repeat dismantle grants no reward")
	# Direct fixture contains identical source pets, not a random success assumption.
	op = fresh()
	op._main_systems.collections._create(op._state.main, "pet", 1001)
	op._main_systems.collections._create(op._state.main, "pet", 1001)
	test.assert_true(op.main_command({"type": "collection_star", "object": 1}).accepted, "pet consumes matching idle material")
	test.assert_equal(op.snapshot().main.collections.size(), 1, "pet material consumed")
	test.assert_equal(op.snapshot().main.collections[0].definition, 1002, "pet source successor stage")
	op._state.inventory["item.13016"] = 1
	test.assert_true(op.main_command({"type": "item_use", "item": 13016}).accepted, "source artifact box opens")
	var artifact: Dictionary = op.snapshot().main.collections[-1]
	test.assert_equal(artifact.quality, 4, "S box produces source S growth range")
	op._state.coins = 1000000
	op._state.inventory["item.13001"] = 1000
	test.assert_true(op.main_command({"type": "collection_level", "object": artifact.id}).accepted, "artifact source cost upgrade")
	test.assert_equal(op.snapshot().main.collections[-1].level, 2, "artifact level advances")
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "collection_equip", "object": artifact.id, "hero": "missing"}).accepted, "invalid hero rejected")
	test.assert_equal(op.snapshot(), before, "invalid owner atomic")
	op.main_command({"type": "collection_equip", "object": artifact.id, "hero": "hero.1"})
	op.main_command({"type": "battle_start", "mode": "dungeon"})
	test.assert_true(not op.main_command({"type": "collection_unequip", "object": artifact.id}).accepted, "battle snapshot prevents equipment swapping")
	op.main_command({"type": "battle_close"})
	# Permanent shop category, source product price, daily idempotence and level gate.
	op = fresh()
	test.assert_true(op.main_command({"type": "gift_buy", "product": "gift.4201"}).accepted, "free pet store package")
	test.assert_equal(op.snapshot().inventory["item.11310"], 30, "source package grants mushrooms")
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "gift_buy", "product": "gift.4201"}).accepted, "daily gift cannot repeat")
	test.assert_equal(op.snapshot(), before, "repeat gift leaves state unchanged")
	test.assert_true(not op.main_command({"type": "gift_buy", "product": "gift.4114"}).accepted, "artifact package city level gate")
	test.assert_true(op.main_command({"type": "gift_buy", "product": "gift.4202"}).accepted, "simulated paid package")
	test.assert_equal(op.snapshot().main.orders[0].price, 18.0, "price from original CNY product table")
	test.assert_equal(op.snapshot().inventory["item.11301"], 5, "paid package grants source items")
	op._state.main.day_time = 86399
	op._main_systems.advance(op._state, 2)
	test.assert_true(op.main_command({"type": "gift_buy", "product": "gift.4201"}).accepted, "daily store limit resets at day boundary")
	op._state.inventory["item.10081"] = 1
	var energy: int = op.snapshot().main.energy
	test.assert_true(op.main_command({"type": "item_use", "item": 10081}).accepted, "energy item works")
	test.assert_equal(op.snapshot().main.energy, energy + 500, "source energy amount")
