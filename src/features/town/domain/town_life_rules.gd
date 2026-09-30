class_name TownLifeRules
extends RefCounted


static func detail(levels: Array, current: int, purchased: int) -> Dictionary:
	var result: Dictionary = levels[current - 1].duplicate(true)
	var start := 0
	var end := levels.size()
	var unlock := -1
	for row: Dictionary in levels:
		if row.seats >= 2 and unlock == -1:
			unlock = row.level
		if row.stage_end:
			if row.level <= current:
				start = row.level
			elif end == levels.size():
				end = row.level
	var next: Dictionary = levels[end - 1]
	var previous: Dictionary = levels[maxi(0, end - 2)]
	var kind := "price_bonus"
	var value := snappedf((next.bonus - previous.bonus) * 100, 0.01)
	if next.reduction > previous.reduction:
		kind = "time_bonus"
		value = next.reduction - previous.reduction
	elif next.seats > previous.seats:
		kind = "seats"
		value = next.seats - previous.seats
	result.merge({"stage_kind": kind, "stage_value": value, "stage_progress": 1.0 if start == end else float(current - start) / (end - start), "max_level": current == levels.size(), "capacity": int(result.seats) + purchased, "seat_unlock": unlock})
	return result


static func buy_seat(state: Dictionary, services: Dictionary, building: String, slot: int) -> Dictionary:
	if not services.has(building) or slot not in [2, 3]:
		return {"accepted": false, "reason": "席位不存在"}
	if slot in state.purchased_seats[building]:
		return {"accepted": false, "reason": "已购买此席位"}
	var cost := int(services[building]["seat_cost_%d" % slot])
	if state.diamonds < cost:
		return {"accepted": false, "reason": "钻石不足"}
	state.diamonds -= cost
	state.purchased_seats[building].append(slot)
	return {"accepted": true}


static func set_report_time(state: Dictionary, unix_seconds: float) -> void:
	# App injects local civil time; the domain never queries an operating-system clock.
	var day := floori(unix_seconds / 86400.0)
	if day != state.get("report_day", -1):
		state["report_day"] = day
		for id: String in state.life_reports:
			state.life_reports[id] = {"total": 0, "bills": []}
	state["report_second"] = int(unix_seconds) % 86400

static func begin_service(state: Dictionary, hero: Dictionary, building: String, recipe: Dictionary, capacity: int, price: int, duration: float, product_name: String) -> bool:
	var occupants := 0
	for other: Dictionary in state.heroes:
		if other.mode == "serving" and other.target == building:
			occupants += 1
		if other.id != hero.id and other.mode == "waiting" and other.target == building and other.queued_at < hero.queued_at and state.inventory[recipe.product] > 0 and other.wallet >= price:
			hero.reason = "等待前方英雄"
			return false
	if occupants >= capacity:
		hero.reason = "等待空位"
		return false
	if state.inventory[recipe.product] <= 0:
		hero.reason = "等待成品"
		return false
	if hero.wallet < price:
		hero.reason = "金币不足，等待材料售出"
		return false
	state.inventory[recipe.product] -= 1
	state.coins += price
	hero.wallet -= price
	hero.timer = duration
	hero.service_total = hero.timer
	hero.recovery = float(recipe.recovery_ratio) * (100.0 if state.exchange_level == 1 else 80.0)
	hero.reason = "使用中"
	state.life_reports[building].total += price
	state.life_reports[building].bills.push_front({"second": state.get("report_second", 0), "hero": hero.name, "product": product_name, "coins": price})
	return true

