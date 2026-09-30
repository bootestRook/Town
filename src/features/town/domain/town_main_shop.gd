class_name TownMainShop
extends RefCounted

var gifts: Array = []

func configure(data) -> void:
	gifts = data.rows("main_shop_gifts").duplicate(true)
	gifts.sort_custom(func(a,b): return a.order < b.order)

func visible_gifts(state: Dictionary) -> Array:
	return gifts.filter(func(g): return g.end_day == 0 or (state.main.day >= g.start_day and state.main.day < g.end_day))

func buy(state: Dictionary, id: String) -> Dictionary:
	var matches: Array = visible_gifts(state).filter(func(g): return g.id == id)
	if matches.is_empty(): return TownOperations.reject("商品不存在或已经下架")
	var gift: Dictionary = matches[0]
	if state.city_level < gift.minimum or state.city_level >= gift.maximum: return TownOperations.reject("主城等级不符合购买条件")
	var key := "gift." + id
	if gift.limit >= 0 and state.main.daily.get(key, 0) >= gift.limit: return TownOperations.reject("今日购买次数已用完")
	state.main.daily[key] = state.main.daily.get(key, 0) + 1
	TownMainInventory.grant(state, gift.rewards)
	state.main.order_serial += 1
	state.main.orders.push_front({"number": state.main.order_serial, "product": gift.display_name, "price": gift.price})
	return {"accepted": true, "message": "物品已领取"}
