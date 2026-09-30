extends RefCounted

func fresh():
	var data := DataRegistry.new()
	assert(data.load_default().is_empty())
	return TownOperations.new(data, RngSet.new(7741))

func run(test: TestSupport) -> void:
	var op = fresh()
	var initial: Dictionary = op.snapshot()
	var cost: int = initial.main.coin_offer.cost
	var amount: int = initial.main.coin_offer.amount
	test.assert_true(op.main_command({"type": "resource_buy", "resource": "coins"}).accepted, "gold purchase succeeds")
	test.assert_equal(op.snapshot().diamonds, initial.diamonds - cost, "source gold offer deducts diamonds")
	test.assert_equal(op.snapshot().coins, initial.coins + amount, "source gold offer credits gold")
	test.assert_true(not op.main_command({"type": "resource_buy", "resource": "missing"}).accepted, "invalid resource rejected")
	for i in 4: op.main_command({"type": "resource_buy", "resource": "coins"})
	var before: Dictionary = op.snapshot()
	test.assert_true(not op.main_command({"type": "resource_buy", "resource": "coins"}).accepted, "daily gold purchase limit")
	test.assert_equal(op.snapshot().diamonds, before.diamonds, "failed purchase is atomic")
	test.assert_true(op.main_command({"type": "resource_free", "resource": "energy"}).accepted, "scheduled power grant")
	test.assert_true(not op.main_command({"type": "resource_free", "resource": "energy"}).accepted, "power grant cannot repeat")
	op._state.diamonds = 0
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "recruit"}).accepted, "insufficient recruit funds")
	test.assert_equal(op.snapshot().main.pool, before.main.pool, "failed recruit leaves pool unchanged")
	op = fresh()
	var control = fresh()
	op._state.inventory["item.10001"] = 3
	control._state.inventory["item.10001"] = 3
	for i in 3:
		test.assert_true(op.main_command({"type": "recruit"}).accepted, "recruit once per candidate")
		control.main_command({"type": "recruit"})
	test.assert_equal(op.snapshot().main.roster, control.snapshot().main.roster, "injected stream replays recruit results")
	test.assert_equal(op.snapshot().main.fragments, control.snapshot().main.fragments, "duplicate conversion deterministic")
	test.assert_equal(op.snapshot().main.recruited.size(), 0, "exhausted pool replaces automatically")
	test.assert_true(not op.main_command({"type": "recruit_refresh", "method": "invalid"}).accepted, "invalid refresh method rejected")
	before = op.snapshot()
	op.main_command({"type": "hero_level", "hero": "hero.1"})
	test.assert_equal(op.snapshot().heroes[0].level, 2, "upgrade changes authoritative live hero")
	test.assert_true(op.snapshot().main.power > before.main.power, "HUD power follows stats")
	test.assert_true(not op.main_command({"type": "hero_level", "hero": "missing"}).accepted, "unknown hero rejected")
	test.assert_true(not op.main_command({"type": "profile_name", "value": " "}).accepted, "empty name rejected")
	op.main_command({"type": "profile_name", "value": "新镇长"})
	test.assert_equal(op.snapshot().main.player_name, "新镇长", "profile name updates")
	op.main_command({"type": "shop_buy", "product": "shop.1", "order": 1})
	test.assert_equal(op.snapshot().main.orders.size(), 1, "simulated order recorded")
	test.assert_true(not op.main_command({"type": "shop_buy", "product": "invalid"}).accepted, "unknown product rejected")
	op = fresh()
	for hero: Dictionary in op._state.heroes:
		hero.stats.attack = 100000.0
	test.assert_true(op.main_command({"type": "battle_start", "mode": "dungeon"}).accepted, "dungeon starts with real team")
	test.assert_equal(op.snapshot().main.battle.enemies[0].max_hp, 4500.0, "enemy hp comes from original dungeon table")
	test.assert_true(not op.main_command({"type": "battle_start", "mode": "dungeon"}).accepted, "cannot overlap battles")
	test.assert_true(not op.main_command({"type": "expedition_team", "hero": "hero.1"}).accepted, "cannot change active team")
	for i in 400: op._main_systems.advance(op._state, 0.5)
	test.assert_equal(op.snapshot().main.battle.status, "won", "strong controlled team resolves from damage")
	before = op.snapshot()
	test.assert_true(op.main_command({"type": "battle_claim"}).accepted, "victory reward claim")
	test.assert_equal(op.snapshot().coins, before.coins + 2000, "source first stage gold reward")
	test.assert_equal(op.snapshot().inventory.get("item.10022"), 1, "source item reward delivered")
	test.assert_true(not op.main_command({"type": "battle_claim"}).accepted, "reward claim idempotent")
	op.main_command({"type": "battle_close"})
	test.assert_equal(op.snapshot().main.progress.dungeon, 1, "dungeon progression retained")
	for id in op.snapshot().main.expedition_team: op.main_command({"type": "expedition_team", "hero": id})
	test.assert_true(not op.main_command({"type": "battle_start", "mode": "dungeon"}).accepted, "empty team blocks combat")
	var snapshot: Dictionary = op.snapshot()
	snapshot.main.player_name = "modified outside"
	test.assert_equal(op.snapshot().main.player_name, "小镇镇长", "snapshot remains detached")
	_more_rules(test)

func _more_rules(test: TestSupport) -> void:
	var op = fresh()
	var definitions: Dictionary = op.main_definitions()
	var valid_references := true
	for encounters: Array in definitions.encounters.values():
		for encounter: Dictionary in encounters:
			for enemy: String in String(encounter.enemies).split(";"):
				valid_references = valid_references and definitions.enemies.has(enemy)
	test.assert_true(valid_references, "all imported encounter enemy references resolve")
	test.assert_equal(definitions.modes[0].id, "modes.6", "gameplay order matches source rather than id")
	test.assert_equal(definitions.recruit_levels[9].source_id, 10, "recruit thresholds sort numerically")
	var skills: TownExpeditionSkills = op._main_systems.expedition.skills
	var actor := {"id":"actor", "name": "技能测试", "attack": 100, "max_hp": 1000, "hp": 500, "defense": 0}
	var target := {"id":"target", "attack":100, "hp": 1000, "max_hp": 1000, "defense": 0}
	var source: Dictionary = definitions.heroes.values()[0]
	skills.prepare(actor,source,"1000;1|1003;1|1051;1")
	skills.prepare(target,source,"1000;1")
	actor.hp = 500
	skills.combat.rules[1077] = 1.0
	skills.combat.rules[1078] = 1.0
	var log: Array = []
	test.assert_equal(actor.skills.size(), 2, "source damage and healing active skills configured")
	for skill: Dictionary in actor.skills: skill.remaining = 0
	skills.step(actor, [actor], [target], log)
	test.assert_equal(target.hp, 712.0, "source base formula 120 times active 240 percent")
	test.assert_equal(actor.hp, 650.0, "healing uses source 15 percent caster hp coefficient")
	skills.step(actor, [actor], [target], log)
	test.assert_equal(target.hp, 712.0, "skill cooldown prevents immediate repeat")
	test.assert_equal(definitions.encounters["modes.2"][0].cost, 100, "fairyland uses separate source rules")
	test.assert_true(definitions.encounters["modes.4"][0].enemies != definitions.encounters.dungeon[0].enemies, "cloud enemies are distinct")
	var hero: Dictionary = op._state.main.roster[0]
	var before: Dictionary = op.snapshot()
	op._state.main.fragments[hero.definition] = 1000
	test.assert_true(op.main_command({"type": "hero_star", "hero": hero.id}).accepted, "source talent successor can be reached")
	test.assert_true(op.snapshot().main.roster[0].max_level > before.main.roster[0].max_level, "star raises source level cap")
	test.assert_true(op.snapshot().heroes[0].stats.attack > before.heroes[0].stats.attack, "star affects live hero stats")
	op = fresh()
	before = op.snapshot()
	test.assert_true(op.main_command({"type": "sea_start", "site": "sea.1"}).accepted, "salvage starts")
	test.assert_equal(op.snapshot().main.salvage.power, 80, "salvage uses dedicated power")
	test.assert_equal(op.snapshot().main.energy, before.main.energy, "salvage does not spend purification energy")
	test.assert_true(not op.main_command({"type": "sea_start", "site": "sea.1"}).accepted, "cannot overwrite active salvage")
	op._main_systems.advance(op._state, 3599)
	test.assert_true(not op.main_command({"type": "sea_claim", "site": "sea.1"}).accepted, "cannot claim early")
	op._main_systems.advance(op._state, 1)
	test.assert_true(op.main_command({"type": "sea_claim", "site": "sea.1"}).accepted, "source duration completes salvage")
	test.assert_true(op.snapshot().inventory.get("item.13001", 0) > 0, "source salvage rewards reach inventory")
	test.assert_true(not op.main_command({"type": "sea_claim", "site": "sea.1"}).accepted, "salvage reward is idempotent")
	test.assert_equal(op.snapshot().main.salvage.records.size(), 1, "salvage receipt retained")
	before = op.snapshot()
	test.assert_true(not op.main_command({"type": "city_upgrade"}).accepted, "city upgrade checks dungeon prerequisite")
	test.assert_equal(op.snapshot().coins, before.coins, "failed upgrade spends nothing")
	op._state.main.progress.dungeon = 48
	op._state.coins = 120000
	test.assert_true(op.main_command({"type": "city_upgrade"}).accepted, "source city conditions unlock upgrade")
	test.assert_equal(op.snapshot().city_level, 6, "city upgrade changes authoritative state")
	test.assert_equal(op.snapshot().coins, 0, "city upgrade spends exact source cost")
	op = fresh()
	op.main_command({"type": "battle_start", "mode": "dungeon"})
	for ally: Dictionary in op._state.main.battle.allies:
		ally.hp = 1
		ally.cooldown = 100
		for skill: Dictionary in ally.skills: skill.remaining = 100
	op._main_systems.advance(op._state, 1)
	test.assert_equal(op.snapshot().main.battle.status, "lost", "weak team can lose")
	test.assert_true(not op.main_command({"type": "battle_claim"}).accepted, "loss cannot receive win rewards")
	test.assert_true(op.main_command({"type": "battle_close"}).accepted, "loss returns to stage selection")
	op._state.main.progress.dungeon = 12
	op._state.inventory["item.12001"] = 1
	for mode: String in definitions.encounters:
		test.assert_true(op.main_command({"type": "battle_start", "mode": mode}).accepted, "every battle mode starts with its own table")
		op.main_command({"type": "battle_close"})
