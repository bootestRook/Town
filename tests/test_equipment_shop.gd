extends RefCounted

func fresh(): return preload("res://tests/test_town_heroes.gd").new().fresh(98211)
func command(op, action: String, data: Dictionary = {}) -> Dictionary:
	data.action = action
	data.building = "building.6"
	return op.equipment_shop_command(data)
func supply(op, recipe: Dictionary, count: int = 1) -> void:
	for id: int in TownMainInventory.entries(recipe.cost): TownMainInventory.add(op._state,id,TownMainInventory.entries(recipe.cost)[id]*count)
	if recipe.one_use: TownMainInventory.add(op._state,recipe.source_id,count)

func run(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	t.assert_equal(op.equipment_shop.levels["building.6"].size(),15,"all source shop levels")
	t.assert_equal(op.equipment_shop.recipes.values().filter(func(r): return r.building == "building.6" and not r.one_use).size(),45,"45 permanent recipes")
	t.assert_equal(op.equipment_shop.recipes.values().filter(func(r): return r.building == "building.6" and r.one_use).size(),54,"54 one-use drawings")
	t.assert_equal(op.equipment_shop.equipment.values().filter(func(e): return e.building == "building.6").size(),129,"all source weapons")
	s.city_level = 1
	t.assert_true(not command(op,"upgrade").accepted,"city gate blocks upgrade")
	s.city_level = 15
	s.coins = 19999
	t.assert_true(not command(op,"upgrade").accepted,"insufficient coins atomic")
	s.coins = 20000
	t.assert_true(command(op,"upgrade").accepted,"source 20000 price")
	t.assert_equal(s.coins,0,"price deducted once")
	t.assert_equal(s.buildings["building.6"],2,"actual level advanced")
	t.assert_true(not op.craft("forge.11103",1).accepted,"locked recipe rejected")
	var before := s.duplicate(true)
	t.assert_true(not op.craft("invalid",1).accepted,"unknown recipe rejected")
	t.assert_true(not op.craft("forge.11101",11).accepted,"max ten per craft")
	t.assert_equal(s.inventory,before.inventory,"invalid craft never spends")
	s.buildings["building.6"] = 15
	for r: Dictionary in op.equipment_shop.recipes.values():
		if r.building != "building.6": continue
		supply(op,r)
		var inventory: Dictionary = s.inventory.duplicate(true)
		var count: int = s.equipment.size()
		t.assert_true(op.craft(r.id,1).accepted,"recipe creates weapon: "+r.id)
		if s.equipment.size() == count: continue
		var item: Dictionary = s.equipment.back()
		t.assert_equal(item.id,r.equipment,"source result binding")
		t.assert_equal(item.power,op.equipment_shop.equipment[r.equipment].power,"source base attribute")
		for id: int in TownMainInventory.entries(r.cost):
			t.assert_equal(inventory.get("item.%d"%id,0)-s.inventory.get("item.%d"%id,0),TownMainInventory.entries(r.cost)[id],"source material consumed")
		if r.one_use: t.assert_equal(TownMainInventory.count(s,r.source_id),0,"drawing consumed once")
		t.assert_true(not item.affixes.is_empty(),"source affix slots rolled")
		for a: Dictionary in item.affixes: t.assert_true(a.value >= 0 and not a.label.is_empty(),"actual affix value and label")
	t.assert_true(not command(op,"upgrade").accepted,"max shop level stops")
	var serial: int = s.equipment[0].serial
	command(op,"lock",{"serial":serial})
	t.assert_true(not command(op,"resolve",{"serials":[serial]}).accepted,"locked item protected")
	command(op,"lock",{"serial":serial})
	t.assert_true(not command(op,"resolve",{"serials":[serial,serial]}).accepted,"duplicate resolve rejected")
	var coins: int = s.coins
	var expected: int = TownMainInventory.entries(s.equipment[0].resolve)[101]
	t.assert_true(command(op,"resolve",{"serials":[serial]}).accepted,"resolve actual item")
	t.assert_equal(s.coins,coins+expected,"exact source disassembly return")
	t.assert_true(not command(op,"resolve",{"serials":[serial]}).accepted,"no repeated grant")
	while s.equipment.size() < 300:
		supply(op,op.equipment_shop.recipes["forge.11101"])
		op.craft("forge.11101",1)
	before = s.duplicate(true)
	t.assert_true(not op.craft("forge.11101",1).accepted,"capacity exactly 300")
	t.assert_equal(s.inventory,before.inventory,"full shelf cannot consume materials")
	_trade(t)

func _trade(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var hero: Dictionary = s.heroes[0]
	var start: Vector2 = hero.position
	t.assert_true(not command(op,"open_trade",{"hero":hero.id}).accepted,"cannot trade before arrival")
	t.assert_true(op.summon(hero.id,"building.6").accepted,"explicit summon accepts empty shelf")
	t.assert_equal(hero.position,start,"summon never teleports")
	for second in 300:
		op.advance(1)
		if hero.mode == "await_trade": break
	t.assert_equal(hero.mode,"await_trade","real navigation reaches shop")
	t.assert_true(hero.position != start,"real movement happened")
	op.advance(40)
	t.assert_equal(hero.mode,"await_trade","explicit call survives empty stock and old timeout")
	t.assert_true(command(op,"open_trade",{"hero":hero.id}).accepted,"arrived icon opens trade")
	op.summon(hero.id,"building.6")
	t.assert_equal(hero.requested,"","repeat summon has no latent order")
	s.buildings["building.6"] = 3
	var recipes: Array = op.equipment_shop.recipes.values().filter(func(r): return r.tier == 1 and r.job == hero.job and not r.one_use)
	for r: Dictionary in recipes: supply(op,r); op.craft(r.id,1)
	hero.wallet = 0
	var offer: Dictionary = s.equipment.back()
	t.assert_true(not op.sell_equipment(hero.id,offer.serial).accepted,"poor hero cannot buy")
	s.coins = 100000
	t.assert_true(not command(op,"donate",{"amount":"1abc"}).accepted,"malformed amount rejected")
	t.assert_true(not command(op,"donate",{"amount":-1}).accepted,"negative donation rejected")
	t.assert_true(command(op,"donate",{"amount":50000}).accepted,"transfer player coins to buyer")
	t.assert_equal(s.coins+hero.wallet,100000,"donation conserves funds")
	var power: float = hero.stats.attack
	t.assert_true(op.sell_equipment(hero.id,offer.serial).accepted,"sale equips actual instance")
	t.assert_equal(hero.equipment["1"].serial,offer.serial,"correct instance equipped")
	t.assert_equal(s.coins+hero.wallet,100000,"sale conserves funds")
	t.assert_true(hero.stats.attack > power,"actual combat stats refreshed")
	t.assert_equal(hero.mode,"await_trade","result visible until close")
	t.assert_true(not op.sell_equipment(hero.id,s.equipment[0].serial).accepted,"one weapon per visit")
	t.assert_true(not op.sell_equipment(hero.id,offer.serial).accepted,"no duplicate sale")
	command(op,"close_trade")
	t.assert_equal(hero.mode,"shopping_done","closing releases buyer")
	t.assert_true(not s.equipment_shop.calls.has(hero.id),"call removed after visit")
	op.advance(0.2)
	t.assert_true(hero.mode != "await_trade","buyer resumes town behavior")
