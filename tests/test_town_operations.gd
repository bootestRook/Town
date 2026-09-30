extends RefCounted

const Registry = preload("res://src/data/data_registry.gd")
const Operations = preload("res://src/features/town/domain/town_operations.gd")


func fresh():
	return preload("res://tests/test_town_heroes.gd").new().fresh()


func run(test: TestSupport) -> void:
	_production(test)
	_trade(test)
	_service(test)
	_equipment(test)
	_competing_buyers(test)
	_cycle(test)
	_life_source_rules(test)


func _life_source_rules(test: TestSupport) -> void:
	var operations = fresh()
	for row in [["building.1",30,1432,0.0],["building.2",30,2700,0.0],["building.3",28,4056,0.8],["building.4",29,2218,0.9]]:
		operations._state.buildings[row[0]] = row[1]
		var detail: Dictionary = operations.snapshot().details[row[0]]
		test.assert_equal(detail.price, row[2], "source screenshot selling price " + row[0])
		test.assert_equal(detail.stage_progress, row[3], "source configured stage interval " + row[0])
	test.assert_equal(operations.snapshot().details["building.1"].stage_kind, "seats", "Lv30 next milestone is seat at Lv40")
	var before: Dictionary = operations.snapshot()
	test.assert_true(not operations.buy_seat("building.1", 2).accepted, "insufficient diamonds do not buy hospital seat")
	test.assert_equal(operations.snapshot().diamonds, before.diamonds, "failed purchase is atomic")
	test.assert_true(not operations.buy_seat("building.3", 1).accepted, "monthly-card slot cannot be purchased as diamonds")
	test.assert_true(operations.buy_seat("building.3", 2).accepted, "hotel source diamond cost succeeds")
	test.assert_equal(operations.snapshot().diamonds, 355, "hotel seat costs 800 diamonds")
	test.assert_equal(operations.snapshot().details["building.3"].capacity, 2, "purchased seat increases actual capacity")
	test.assert_true(not operations.buy_seat("building.3", 2).accepted, "same seat cannot be charged twice")
	operations.set_report_time(86400 + 3600)
	operations.produce("building.1", "item.20101")
	var hero: Dictionary = operations._state.heroes[0]
	test.assert_true(operations.begin_service(hero, "building.1"), "service creates building sale bill")
	test.assert_equal(operations.snapshot().life_reports["building.1"].total, 1432, "bill records paid money")
	test.assert_equal(operations.snapshot().life_reports["building.2"].total, 0, "reports are scoped to building")
	operations.set_report_time(86400 * 2)
	test.assert_equal(operations.snapshot().life_reports["building.1"].total, 0, "local midnight clears daily sales")


func _production(test: TestSupport) -> void:
	var operations = fresh()
	var before: Dictionary = operations.snapshot()
	test.assert_equal(before.details["building.1"].price, 968, "Lv5 bandage price uses numeric level order")
	test.assert_equal(before.details["building.1"].duration, 12.0, "hospital uses twelve-second treatment")
	test.assert_true(not operations.produce("building.1", "item.20102").accepted, "wrong material rejected atomically")
	for id: String in before.services:
		var recipe: Dictionary = before.services[id]
		var result: Dictionary = operations.produce(id, recipe.material)
		test.assert_true(result.accepted, "each life building accepts its material")
		test.assert_equal(operations.snapshot().inventory[recipe.material], 0, "batch uses all available material")
		test.assert_equal(operations.snapshot().inventory[recipe.product], 8, "products are committed before animation")
		test.assert_true(not operations.produce(id, recipe.material).accepted, "repeated drag cannot duplicate stock")
	test.assert_equal(operations.snapshot().coins, before.coins, "production has no invented coin fee")
	var copy: Dictionary = operations.snapshot()
	copy.inventory["item.20101"] = 9999
	copy.heroes[0].wallet = 0
	test.assert_true(operations.snapshot().heroes[0].wallet > 0, "deep snapshot cannot modify hero wallet")
	test.assert_equal(operations.snapshot().inventory["item.20101"], 0, "deep snapshot cannot modify material")


func _trade(test: TestSupport) -> void:
	var operations = fresh()
	var hero: Dictionary = operations._state.heroes[0]
	hero.bag["item.20101"] = 10
	operations._state.coins = 820
	var wallet: int = hero.wallet
	test.assert_true(not operations.set_order("item.20101", -1).accepted, "negative order rejected")
	test.assert_true(not operations.set_order("item.20101", 201).accepted, "order cap enforced")
	test.assert_true(not operations.set_order("item.30206", 1).accepted, "tier-two order requires exchange upgrade")
	operations.set_order("item.20101", 8)
	test.assert_equal(operations.snapshot().coins, 820, "preorder does not immediately spend")
	operations.settle_trade(hero)
	test.assert_equal(operations.snapshot().coins, 100, "trade buys only affordable quantity")
	test.assert_equal(hero.wallet, wallet + 720, "trade pays the hero")
	test.assert_equal(hero.bag["item.20101"], 7, "trade deducts real hero bag")
	test.assert_equal(operations.snapshot().orders["item.20101"], 5, "partially filled order remains")
	test.assert_equal(operations.snapshot().inventory["item.20101"], 11, "trade replenishes player materials")
	operations.set_order("item.20101", 0)
	test.assert_true(not operations.snapshot().orders.has("item.20101"), "zero cancels order without refund fabrication")
	operations._state.coins = 5000
	operations.upgrade("building.7")
	test.assert_true(operations.set_order("item.30206", 10).accepted, "upgrade unlocks jewelry material supply")


func _service(test: TestSupport) -> void:
	var operations = fresh()
	operations.produce("building.1", "item.20101")
	for hero: Dictionary in operations._state.heroes:
		hero.mode = "waiting"
		hero.target = "building.1"
		hero.needs = {"hp":20.0,"energy":100.0,"mood":100.0,"tired":100.0,"magic":0}
	var wallet: int = operations._state.heroes[0].wallet
	operations.advance(0.05)
	var snapshot: Dictionary = operations.snapshot()
	test.assert_equal(snapshot.heroes.filter(func(h):return h.mode == "serving").size(), 1, "one bed accepts only one hero")
	test.assert_equal(snapshot.inventory["item.20151"], 7, "service start consumes one product")
	test.assert_equal(snapshot.heroes[0].wallet, wallet - 968, "service payment occurs once")
	operations.advance(11.8)
	test.assert_equal(operations.snapshot().heroes[0].needs.hp, 20.0, "healing waits for service time")
	operations.advance(0.25)
	test.assert_equal(operations.snapshot().heroes[0].needs.hp, 100.0, "treatment restores and clamps health")
	test.assert_equal(operations.snapshot().heroes[1].mode, "serving", "seat passes to next waiting hero")
	var empty = fresh()
	var hero: Dictionary = empty._state.heroes[0]
	test.assert_true(not empty.begin_service(hero, "building.1"), "out of stock cannot charge hero")
	empty.produce("building.1", "item.20101")
	hero.wallet = 0
	test.assert_true(not empty.begin_service(hero, "building.1"), "poor hero cannot consume free product")
	test.assert_equal(empty.snapshot().inventory["item.20151"], 8, "failed service leaves stock intact")


func _equipment(test: TestSupport) -> void:
	for recipe: Dictionary in fresh().recipes():
		var operations = fresh()
		var stock_before: Dictionary = operations.snapshot().inventory
		test.assert_true(not operations.craft(recipe.id, -1).accepted, "invalid crafting amount rejected")
		test.assert_true(operations.craft(recipe.id, 1).accepted, "armor and accessory source recipes craft")
		var state: Dictionary = operations._state
		test.assert_equal(state.inventory[recipe.material_a], stock_before[recipe.material_a] - recipe.count_a, "forge consumes first ingredient")
		test.assert_equal(state.inventory[recipe.material_b], stock_before[recipe.material_b] - recipe.count_b, "forge consumes second ingredient")
		var hero: Dictionary = state.heroes[0]
		hero.job = recipe.job if recipe.job != 0 else 3
		hero.target = recipe.building
		hero.mode = "await_trade"
		var total: int = state.coins + hero.wallet
		var serial: int = state.equipment[0].serial
		test.assert_true(operations.sell_equipment(hero.id, serial).accepted, "player confirms equipment sale")
		test.assert_equal(state.equipment.size(), 0, "sold instance leaves store")
		test.assert_equal(hero.equipment.size(), 1, "sold instance belongs to hero")
		test.assert_equal(state.coins + hero.wallet, total, "equipment sale conserves money")
		test.assert_true(hero.stats.max_hp > hero.base.max_hp or hero.stats.attack > hero.base.attack or hero.stats.defense > hero.base.defense, "equipped item affects actual combat attributes")
		operations.craft(recipe.id, 1)
		hero.mode = "await_trade"
		test.assert_true(not operations.sell_equipment(hero.id, state.equipment[0].serial).accepted, "equal equipment sale rejected")
		test.assert_equal(state.equipment.size(), 1, "hero does not buy equal replacement repeatedly")


func _cycle(test: TestSupport) -> void:
	var operations = fresh()
	operations._state.heroes[0].bag["item.20101"] = 2
	for id: String in operations.services():
		operations.produce(id, operations.services()[id].material)
	operations.set_order("item.20101", 20)
	operations.craft("forge.13101", 1)
	operations.craft("forge.60201", 1)
	var observed_wait := false
	for i in 90:
		operations.advance(2)
		var waiting: Dictionary = operations.snapshot()
		for hero: Dictionary in waiting.heroes:
			if hero.mode == "await_trade":
				observed_wait = true
				for item: Dictionary in waiting.equipment:
					if item.building == hero.target:
						operations.sell_equipment(hero.id, int(item.serial))
	test.assert_true(observed_wait, "hero waits for explicit equipment trade")
	var state: Dictionary = operations.snapshot()
	for kind: String in ["收购", "使用完成", "出售装备", "冒险归来"]:
		test.assert_true(state.counts.get(kind, 0) > 0, "closed-page simulation completes " + kind)
	test.assert_true(state.coins >= 0, "town wallet cannot become negative")
	for hero: Dictionary in state.heroes:
		test.assert_true(hero.wallet >= 0, "hero wallet cannot become negative")
	for count in state.inventory.values():
		test.assert_true(count >= 0, "no negative stock during full cycle")


func _competing_buyers(test: TestSupport) -> void:
	var operations = fresh()
	operations.craft("forge.20101", 1)
	for hero: Dictionary in operations._state.heroes:
		hero.mode = "await_trade"
		hero.target = "building.9"
	var serial: int = operations._state.equipment[0].serial
	test.assert_true(operations.sell_equipment("hero.1", serial).accepted, "first buyer receives unique equipment")
	var coins: int = operations.snapshot().coins
	test.assert_true(not operations.sell_equipment("hero.2", serial).accepted, "second buyer cannot purchase sold instance")
	test.assert_equal(operations.snapshot().coins, coins, "duplicate sale cannot credit money")
	operations.advance(0.1)
	test.assert_true(operations.snapshot().heroes[1].mode != "await_trade", "other buyers replan when inventory sells out")
