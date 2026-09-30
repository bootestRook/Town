extends RefCounted

func run(test: TestSupport) -> void:
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var state: Dictionary = op._state
	var shop = op._main_systems.diamond_shop
	var before: Dictionary = state.duplicate(true)
	for command: Dictionary in [{"type":"shop_buy","product":"missing","order":1},{"type":"shop_buy","product":"shop.1"},{"type":"shop_buy","product":"shop.1","order":-1},{"type":"shop_buy","product":"shop.1","order":2}]:
		test.assert_true(not op.main_command(command).accepted,"invalid product/order rejected")
		test.assert_equal(state,before,"rejected recharge is atomic")
	for product: Dictionary in shop.products.values():
		var balance: int = state.diamonds
		var command := {"type":"shop_buy","product":product.id,"order":state.main.order_serial+1}
		var result: Dictionary = op.main_command(command)
		test.assert_true(result.accepted,"all six source tiers can be purchased")
		test.assert_equal(state.diamonds,balance+int(product.diamonds)*2,"first purchase doubles each tier independently")
		test.assert_equal(result.recharge.total,int(product.diamonds)*2,"receipt matches granted amount")
		test.assert_equal(result.recharge.price,product.price,"receipt uses exact source CNY price")
		test.assert_true(result.recharge.simulation,"receipt records local simulation")
		before=state.duplicate(true)
		test.assert_true(not op.main_command(command).accepted,"same order cannot be applied twice")
		test.assert_equal(state,before,"duplicate request changes neither history nor balance")
		command.order=state.main.order_serial+1
		result=op.main_command(command)
		test.assert_equal(state.diamonds,before.diamonds+int(product.diamonds),"repeat purchase only grants base amount")
		test.assert_equal(result.recharge.bonus,0,"repeat receipt contains no bonus")
		test.assert_equal(state.main.diamond_purchases[product.id],2,"purchase counts are per tier")
		result.recharge.total=0
		test.assert_equal(state.main.orders[0].total,int(product.diamonds),"presentation receipt cannot mutate stored order")
	var counts: Dictionary = state.main.diamond_purchases.duplicate()
	op._main_systems.advance(state,86400)
	test.assert_equal(state.main.diamond_purchases,counts,"daily rollover does not reset first purchase")
	test.assert_equal(state.main.orders.size(),12,"twelve purchases record twelve local orders")
