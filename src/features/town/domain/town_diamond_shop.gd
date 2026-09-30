class_name TownDiamondShop
extends RefCounted

var products: Dictionary = {}


func configure(data) -> void:
	for row: Dictionary in data.rows("main_shop"):
		products[row.id] = row.duplicate(true)


func buy(state: Dictionary, command: Dictionary) -> Dictionary:
	var id := String(command.get("product", ""))
	if not products.has(id): return TownOperations.reject("商品不存在")
	var main: Dictionary = state.main
	# A receipt number is consumed exactly once, before presentation begins.
	if command.get("order", 0) != main.order_serial + 1:
		return TownOperations.reject("订单已处理，请重新选择商品")
	var product: Dictionary = products[id]
	var count: int = main.diamond_purchases.get(id, 0)
	var bonus: int = int(product.first_bonus) if count == 0 else 0
	var total := int(product.diamonds) + bonus
	var receipt := {"number": main.order_serial + 1, "product_id": id,
		"product": product.display_name, "price": product.price,
		"diamonds": int(product.diamonds), "bonus": bonus, "total": total,
		"first": count == 0, "balance_before": state.diamonds,
		"balance_after": state.diamonds + total, "simulation": true}
	main.order_serial += 1
	main.diamond_purchases[id] = count + 1
	state.diamonds += total
	main.orders.push_front(receipt.duplicate(true))
	return {"accepted": true, "recharge": receipt}
