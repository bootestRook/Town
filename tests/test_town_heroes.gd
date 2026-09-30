extends RefCounted

const Registry = preload("res://src/data/data_registry.gd")
const Operations = preload("res://src/features/town/domain/town_operations.gd")

# Small scenarios isolate service, attack timing and money rules from crowd competition.
class ScenarioData extends DataRegistry:
	var hero_limit := 3
	func rows(table_name: String) -> Array:
		var result := super.rows(table_name)
		if table_name == "town_heroes":
			result = result.duplicate(true)
			result.sort_custom(func(a, b): return a.start_delay < b.start_delay)
			for i in result.size(): result[i].initially_owned = i < hero_limit
		return result


func fresh(seed_value: int = 47115, hero_limit: int = 3):
	var data := ScenarioData.new()
	data.hero_limit = hero_limit
	data.load_default()
	return Operations.new(data, RngSet.new(seed_value))


func run(test: TestSupport) -> void:
	_identity_navigation(test)
	_interruptions(test)
	_combat(test)
	_revival(test)
	_shortages(test)
	_soak(test)


func _identity_navigation(test: TestSupport) -> void:
	var op = fresh()
	var heroes: Array = op.snapshot().heroes
	test.assert_equal(heroes.map(func(h): return h.name), ["艾比", "特伦斯", "芭芭拉"], "requested named roster")
	test.assert_equal(heroes.map(func(h): return h.job), [3, 1, 2], "one mage warrior archer using source professions")
	test.assert_true(heroes.all(func(h): return h.level == 1), "demo starts all named heroes at level one")
	test.assert_true(heroes.all(func(h): return h.bag.values().all(func(n): return n == 0)), "no free expedition materials at birth")
	var nav: TownNavigation = op._simulation.navigation
	var goals: Array = nav.doors.values() + [nav.field_center]
	for goal: Vector2 in goals:
		var path := nav.route(nav.town_center, goal)
		test.assert_true(not path.is_empty(), "all eighteen building doors and first field reachable")
		test.assert_true(path.all(func(p): return nav.passable(p)), "route stays on source walkable cells")
	test.assert_true(not nav.passable(Vector2(4256, 2468.5)), "hospital footprint blocks walking")
	test.assert_true(nav.route(nav.town_center, Vector2(-100, -100)).is_empty(), "invalid destination has no path")
	var a: Dictionary = heroes[0]
	var b: Dictionary = heroes[1]
	a.position = nav.town_center
	b.position = nav.town_center + Vector2(10, 0)
	a.path = [b.position]
	var before: Vector2 = a.position
	op._simulation.movement.step(a, [a, b], 0.05, 155)
	test.assert_true(a.position != before, "source city movement allows heroes to pass each other")


func _interruptions(test: TestSupport) -> void:
	var op = fresh()
	var hero: Dictionary = op._state.heroes[0]
	op.advance(1)
	test.assert_equal(hero.mode, "walking", "hero starts travelling")
	test.assert_true(op.summon(hero.id, "building.6").accepted, "summon while walking accepted")
	op.advance(0.1)
	test.assert_equal(hero.target, "building.6", "walking task reroutes without completing old route")
	op.produce("building.1", "item.20101")
	hero.mode = "waiting"
	hero.requested = ""
	hero.summoned = false
	hero.target = "building.1"
	hero.needs.hp = 30
	op.advance(0.05)
	var paid: int = hero.wallet
	op.summon(hero.id, "building.7")
	op.advance(1)
	test.assert_equal(hero.mode, "serving", "summon cannot interrupt paid treatment")
	test.assert_equal(hero.wallet, paid, "pending summon never charges twice")
	op.advance(11.1)
	test.assert_equal(hero.target, "building.7", "pending summon runs after treatment")
	test.assert_equal(hero.needs.hp, 100.0, "service completes before summon")


func _combat(test: TestSupport) -> void:
	var op = fresh()
	var hero: Dictionary = op._state.heroes[0]
	var monster: Dictionary = op._state.monsters[0]
	var wallet: int = hero.wallet
	op._simulation.combat.defeat(monster, hero, op)
	var bag: Dictionary = hero.bag.duplicate()
	test.assert_equal(hero.wallet, wallet + 1000, "source monster reward paid once")
	op._simulation.combat.defeat(monster, hero, op)
	test.assert_equal(hero.wallet, wallet + 1000, "duplicate death cannot duplicate reward")
	test.assert_equal(hero.bag, bag, "duplicate death cannot duplicate drops")
	test.assert_true(hero.bag.keys().filter(func(k): return hero.bag[k] > 0).all(func(k): return k in ["item.20101", "item.20102", "item.20103", "item.20104", "item.20206", "item.20302", "item.20304"]), "first field only drops configured materials")
	test.assert_true(TownCombat.damage(200, 200) < TownCombat.damage(200, 80), "defense reduces real damage")
	var second = fresh()
	second._simulation.combat.defeat(second._state.monsters[0], second._state.heroes[0], second)
	test.assert_equal(second._state.heroes[0].bag, bag, "injected named RNG reproduces drops")
	var real = fresh()
	real.advance(60)
	test.assert_true(real._state.heroes.any(func(h): return h.kills > 0), "unattended navigation reaches actual combat kills")
	test.assert_true(real._state.heroes.any(func(h): return h.needs.hp < 100), "monsters inflict actual health loss")


func _revival(test: TestSupport) -> void:
	var op = fresh()
	var hero: Dictionary = op._state.heroes[0]
	op.summon(hero.id, "building.6")
	TownCombat.kill_hero(hero, op)
	var wallet: int = hero.wallet
	op.advance(1)
	test.assert_equal(hero.mode, "dead", "death pose completes before travelling soul")
	op.advance(50)
	test.assert_equal(hero.revivals, 1, "dead hero reaches altar and revives exactly once")
	test.assert_true(hero.needs.hp > 0, "revival restores source ten percent life")
	test.assert_equal(hero.wallet, wallet, "revival does not invent rewards")
	test.assert_true(hero.mode not in ["dead", "reviving"], "hero resumes pending task after revival")


func _shortages(test: TestSupport) -> void:
	var op = fresh()
	var hero: Dictionary = op._state.heroes[0]
	hero.position = op._simulation.navigation.queue_point("building.1", 0)
	hero.mode = "waiting"
	hero.target = "building.1"
	hero.needs.hp = 20.0
	hero.wallet = 0
	op.produce("building.1", "item.20101")
	op.advance(5)
	test.assert_equal(hero.needs.hp, 20.0, "no money means no free recovery")
	test.assert_equal(hero.wallet, 0, "poor hero never spends below zero")
	hero.bag["item.20101"] = 20
	op.set_order("item.20101", 20)
	op.advance(60)
	test.assert_true(op._state.counts.get("收购", 0) > 0, "poor hero sells bag before returning to service")
	test.assert_true(op._state.counts.get("消费", 0) > 0, "proceeds allow actual service purchase")
	var before: int = op._state.coins
	op.set_order("item.20101", 0)
	test.assert_equal(op._state.coins, before, "cancel order never spends money")


func _soak(test: TestSupport) -> void:
	var op = fresh()
	for id: String in op.services():
		op.produce(id, op.services()[id].material)
	for recipe: Dictionary in op.recipes():
		op.craft(recipe.id, 1)
	for recipe: Dictionary in op.equipment_shop.recipes.values():
		if not recipe.one_use and recipe.unlock_level == 1: op.craft(recipe.id,1)
	var invalid := false
	var late_kills := 0
	for second in range(0, 1200, 5):
		# Test player uses the same public commands as the real UI, no state gifts.
		for material: String in ["item.20101", "item.20102", "item.20103", "item.20104", "item.20206", "item.20302", "item.20304"]:
			if not op._state.orders.has(material):
				op.set_order(material, 200)
		for building: String in op.services():
			var material: String = op.services()[building].material
			if op._state.inventory[material] > 0:
				op.produce(building, material)
		for hero: Dictionary in op._state.heroes:
			if hero.mode == "await_trade":
				for item: Dictionary in op._state.equipment.duplicate():
					if item.building == hero.target:
						op.sell_equipment(hero.id, item.serial)
		op.advance(5)
		if second == 900:
			late_kills = int(op._state.counts.get("战利品", 0))
		for hero: Dictionary in op._state.heroes:
			invalid = invalid or hero.wallet < 0 or not op._simulation.navigation.passable(hero.position) or hero.needs.hp < 0 or hero.needs.hp > 100
		invalid = invalid or op._state.coins < 0 or op._state.inventory.values().any(func(n): return n < 0)
	test.assert_true(not invalid, "twenty minutes preserve navigation wallet health stock invariants")
	test.assert_true(op._state.heroes.all(func(h): return h.kills > 0), "each named hero participates in wilderness")
	test.assert_true(op._state.counts.get("战利品", 0) > late_kills, "last five minutes still produce combat rewards")
	if op._state.counts.get("战利品", 0) <= late_kills:
		print("BLOCKED_ACTORS ", JSON.stringify((op._state.heroes + op._state.monsters).map(func(a):return {"id":a.id,"position":a.position,"mode":a.mode,"path":a.path.slice(0,3),"zone":op._simulation.navigation.zone(a.position)})))
	for kind: String in ["战利品", "冒险归来", "收购", "生产", "消费", "使用完成", "出售装备"]:
		test.assert_true(op._state.counts.get(kind, 0) > 0, "twenty minute loop contains " + kind)
	print("HERO_SOAK ", JSON.stringify({"seconds":1200,"counts":op._state.counts,"heroes":op._state.heroes.map(func(h):return {"name":h.name,"kills":h.kills,"deaths":h.deaths,"revivals":h.revivals,"mode":h.mode,"reason":h.reason,"position":h.position})}))
