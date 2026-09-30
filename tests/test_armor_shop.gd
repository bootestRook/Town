extends "res://tests/test_equipment_shop.gd"

func armor_command(op, action: String, args: Dictionary = {}) -> Dictionary:
	args.merge({"building":"building.9","action":action},true)
	return op.equipment_shop_command(args)

func run(t: TestSupport) -> void:
	var op = fresh()
	var state: Dictionary = op._state
	var shop: TownEquipmentShop = op.equipment_shop
	var recipes: Array = shop.recipes.values().filter(func(r): return r.building == "building.9")
	t.assert_equal(shop.shops["building.9"].slots,"2;4","armor has both source slots")
	t.assert_equal(shop.levels["building.9"].size(),15,"all armor levels")
	t.assert_equal(recipes.filter(func(r): return not r.one_use).size(),30,"30 permanent armor recipes")
	t.assert_equal(recipes.filter(func(r): return r.one_use).size(),36,"36 once drawings")
	t.assert_equal(shop.equipment.values().filter(func(e): return e.building == "building.9").size(),86,"86 source armors")
	state.coins = 20000
	t.assert_true(armor_command(op,"upgrade").accepted,"armor upgrade uses own level")
	t.assert_equal(state.coins,0,"armor source price")
	t.assert_equal(state.buildings["building.6"],1,"weapon unaffected")
	t.assert_equal(state.buildings["building.9"],2,"armor level increment")
	var before: Dictionary = state.duplicate(true)
	t.assert_true(not armor_command(op,"upgrade").accepted,"poor player cannot upgrade")
	t.assert_equal(state,before,"failed upgrade atomic")
	state.buildings["building.9"] = 3
	state.city_level = 3
	state.coins = 900000
	t.assert_true(not armor_command(op,"upgrade").accepted,"source city4 gate at armor3")
	t.assert_true(not op.craft("forge.20104",1).accepted,"next tier locked")
	state.buildings["building.9"] = 15
	state.city_level = 30
	t.assert_true(not armor_command(op,"upgrade").accepted,"max level cannot charge")
	for recipe: Dictionary in recipes:
		supply(op,recipe)
		var inventory: Dictionary = state.inventory.duplicate(true)
		t.assert_true(armor_command(op,"craft",{"recipe":recipe.id,"count":1}).accepted,"all armor crafts: "+recipe.id)
		var item: Dictionary = state.equipment.back()
		t.assert_equal(item.id,recipe.equipment,"actual source result")
		if not item.display_name.contains("测试"):
			t.assert_equal(item.attribute,7,"defense attribute")
			t.assert_equal(item.attribute_name,"防御","armor uses defense copy")
		t.assert_true(int(item.slot) in [2,4] and item.job == 0,"all jobs armor; both slots")
		t.assert_equal(item.power,shop.equipment[recipe.equipment].power,"actual source defense")
		for id: int in TownMainInventory.entries(recipe.cost):
			t.assert_equal(inventory.get("item.%d" % id,0)-state.inventory.get("item.%d" % id,0),TownMainInventory.entries(recipe.cost)[id],"source material cost")
		if recipe.one_use: t.assert_equal(TownMainInventory.count(state,recipe.source_id),0,"one drawing consumed")
		t.assert_true(not item.affixes.is_empty(),"source affixes generated")
	var serial: int = state.equipment[0].serial
	t.assert_true(not command(op,"lock",{"serial":serial}).accepted,"weapon cannot lock armor")
	t.assert_true(not command(op,"resolve",{"serials":[serial]}).accepted,"weapon cannot resolve armor")
	t.assert_true(not command(op,"craft",{"recipe":"forge.20101","count":1}).accepted,"recipe cannot cross stores")
	armor_command(op,"lock",{"serial":serial})
	t.assert_true(not armor_command(op,"resolve",{"serials":[serial]}).accepted,"locked armor protected")
	armor_command(op,"lock",{"serial":serial})
	var coins: int = state.coins
	var value: int = TownMainInventory.entries(state.equipment[0].resolve)[101]
	t.assert_true(armor_command(op,"resolve",{"serials":[serial]}).accepted,"armor resolved")
	t.assert_equal(state.coins,coins+value,"exact armor resolve reward")
	while shop.stock(state,"building.9").size() < 300:
		supply(op,shop.recipes["forge.20101"])
		op.craft("forge.20101",1)
	before = state.duplicate(true)
	t.assert_true(not op.craft("forge.20101",1).accepted,"armor shelf stops at300")
	t.assert_equal(state,before,"full armor shelf cannot spend")
	supply(op,shop.recipes["forge.11101"])
	t.assert_true(op.craft("forge.11101",1).accepted,"weapon stock independent of full armor")
	_trade_armor(t)

func _trade_armor(t: TestSupport) -> void:
	var op = fresh()
	var s: Dictionary = op._state
	var hero: Dictionary = s.heroes[0]
	var start: Vector2 = hero.position
	t.assert_true(not armor_command(op,"open_trade",{"hero":hero.id}).accepted,"no trade before arrival")
	op.summon(hero.id,"building.6")
	op.summon(hero.id,"building.9")
	t.assert_equal(s.equipment_shop.calls[hero.id],"building.9","new call replaces old target")
	t.assert_equal(hero.position,start,"no teleport")
	for second in 300:
		op.advance(1)
		if hero.mode == "await_trade": break
	t.assert_equal(hero.target,"building.9","actual armor arrival")
	op.advance(40)
	t.assert_equal(hero.mode,"await_trade","summoned buyer waits with empty stock")
	t.assert_true(not command(op,"open_trade",{"hero":hero.id}).accepted,"wrong store cannot begin trade")
	t.assert_true(armor_command(op,"open_trade",{"hero":hero.id}).accepted,"arrived armor trade")
	s.buildings["building.9"] = 3
	hero.wallet = 1000000
	var funds: int = s.coins + hero.wallet
	for id: String in ["forge.20101","forge.20102","forge.40101","forge.40102"]:
		supply(op,op.equipment_shop.recipes[id]); op.craft(id,1)
	var defense: float = hero.stats.defense
	var attack: float = hero.stats.attack
	for slot: int in [2,4]:
		var offers: Array = s.equipment.filter(func(e): return e.slot == slot)
		t.assert_true(op.sell_equipment(hero.id,offers[0].serial).accepted,"each armor part can buy once")
		t.assert_equal(hero.equipment[str(slot)].serial,offers[0].serial,"correct equipped instance")
		t.assert_true(not op.sell_equipment(hero.id,offers[1].serial).accepted,"same part cannot buy twice in visit")
		t.assert_equal(TownEquipmentShop.rating(hero.equipment[str(slot)],3,op.equipment_shop.definitions()),1,"inferior to level3 recipe receives unhappy face")
	t.assert_true(hero.stats.defense > defense,"both items refresh real defense")
	t.assert_equal(hero.stats.attack,attack,"defense items do not overwrite attack")
	t.assert_equal(s.coins+hero.wallet,funds,"transactions conserve all coins")
	t.assert_equal(s.equipment_shop.purchased,["2","4"],"each slot tracked separately")
	t.assert_equal(hero.mode,"await_trade","after sales stay until explicit close")
	armor_command(op,"close_trade")
	t.assert_equal(hero.mode,"shopping_done","back releases buyer")
	op.summon(hero.id,"building.9")
	for second in 300:
		op.advance(1)
		if hero.mode == "await_trade": break
	armor_command(op,"open_trade",{"hero":hero.id})
	t.assert_equal(s.equipment_shop.purchased,[],"new visit resets both slot flags")
	var next: Dictionary = s.equipment.filter(func(e): return e.slot == 2)[0]
	t.assert_true(op.sell_equipment(hero.id,next.serial).accepted,"new visit can upgrade same part")
	t.assert_equal(hero.retired.size(),1,"replaced equipment retires exactly once")
