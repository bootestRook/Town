class_name TownRecruitment
extends RefCounted

var definitions: Dictionary = {}
var levels: Array = []
var prices: Dictionary = {}
var rules: Dictionary = {}
var pool_entries: Array = []
var _rng
var _actor_ids: Dictionary = {}

func configure(data, rng) -> void:
	_rng = rng
	for row: Dictionary in data.rows("main_heroes"): definitions[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("town_heroes"): _actor_ids[row.source_appearance] = row.id
	assert(definitions.values().all(func(d): return _actor_ids.has(d.appearance)), "Every recruit requires a mapped actor")
	levels = data.rows("main_recruit").duplicate(true)
	levels.sort_custom(func(a, b): return a.source_id < b.source_id)
	for row: Dictionary in data.rows("main_recruit_prices"): prices[int(row.source_id)] = row.duplicate(true)
	for row: Dictionary in data.rows("main_recruit_rules"): rules[row.id] = row.value
	pool_entries = data.rows("main_recruit_pool").duplicate(true)

func initialize(state: Dictionary) -> void:
	state.main["recruit_total"] = 0
	state.main["recruit_refreshes"] = 0
	state.main["recruit_ad_remaining"] = 0.0
	state.main["recruit_wish"] = false
	_new_batch(state)

func advance(state: Dictionary, seconds: float) -> void:
	var main: Dictionary = state.main
	main.recruit_ad_remaining = maxf(0, main.recruit_ad_remaining - seconds)
	main.refresh_remaining -= seconds
	if main.refresh_remaining <= 0:
		main.recruit_refreshes = 0
		_new_batch(state)

func command(state: Dictionary, command: Dictionary) -> Dictionary:
	match command.type:
		"recruit": return recruit(state)
		"recruit_refresh": return refresh(state, String(command.get("method", "")))
		"recruit_finish":
			if state.main.recruited.is_empty(): return TownOperations.reject("请先招募一名英雄")
			if command.get("remember", false): state.main.daily["recruit_finish_silent"] = 1
			_new_batch(state)
		"recruit_tickets":
			var quantity := int(command.get("quantity", 0))
			if quantity < 1 or quantity > 9999: return TownOperations.reject("购买数量无效")
			var amount := quantity * int(rules.ticket_price)
			if state.diamonds < amount: return TownOperations.reject("钻石不足")
			state.diamonds -= amount
			TownMainInventory.add(state, int(rules.ticket), quantity)
		"recruit_wish":
			if not wish_unlocked(state): return TownOperations.reject("获得后解锁")
			state.main.recruit_wish = not state.main.recruit_wish
		_: return TownOperations.reject("无效招募操作")
	return {"accepted": true}

func wish_unlocked(state: Dictionary) -> bool:
	return state.main.roster.any(func(h): return int(definitions[h.definition].source_id) == int(rules.wish_talent))

func refresh(state: Dictionary, method: String) -> Dictionary:
	var main: Dictionary = state.main
	if method not in ["ad", "diamond"]: return TownOperations.reject("刷新方式无效")
	if main.recruit_refreshes >= rules.refresh_limit: return TownOperations.reject("本次招募船刷新次数已用完")
	if method == "ad":
		if main.daily.get("recruit_ads", 0) >= rules.ad_limit: return TownOperations.reject("今日免费刷新次数已用完")
		if main.recruit_ad_remaining > 0: return TownOperations.reject("免费刷新尚未恢复")
		main.daily["recruit_ads"] = main.daily.get("recruit_ads", 0) + 1
		main.recruit_ad_remaining = rules.ad_cooldown
	else:
		if state.diamonds < rules.refresh_price: return TownOperations.reject("钻石不足")
		state.diamonds -= int(rules.refresh_price)
	main.recruit_refreshes += 1
	_new_batch(state)
	return {"accepted": true}

func _new_batch(state: Dictionary) -> void:
	var main: Dictionary = state.main
	var level: Dictionary = levels[main.recruit_level - 1]
	var selected: Array = []
	for slot in 3:
		var candidates: Array = pool_entries.filter(func(r): return r.hero not in selected and _pool_weight(state, r) > 0)
		var weights: Array = []
		for entry: Dictionary in candidates:
			var total := 0.0
			for other: Dictionary in candidates:
				if other.quality == entry.quality and other.pool == entry.pool: total += _pool_weight(state, other)
			var color_key: String = ["green", "blue", "purple", "gold"][int(entry.quality) - 2]
			var weight: float = float(level[color_key]) * float(level["pool_%d_%d" % [entry.quality, entry.pool]]) * _pool_weight(state, entry) / total
			if main.recruit_wish and int(definitions[entry.hero].source_id) == int(rules.wish_talent): weight *= rules.wish_multiplier
			weights.append(weight)
		assert(not candidates.is_empty() and weights.any(func(w): return w > 0), "Recruitment pool must have positive candidates")
		selected.append(candidates[_weighted(weights)].hero)
	main.pool = selected
	main.recruited.clear()
	main.refresh_remaining = rules.duration

func _pool_weight(state: Dictionary, entry: Dictionary) -> float:
	if state.main.recruit_wish and int(definitions[entry.hero].source_id) == int(rules.wish_talent): return maxf(entry.weight, rules.wish_weight)
	return float(entry.weight)

func offer(state: Dictionary) -> Dictionary:
	var step: int = state.main.recruited.size()
	if step == 0: return {"item": int(rules.ticket), "amount": 1, "original": 1}
	var quality := 2
	var count := 0
	for id: String in state.main.pool:
		if id in state.main.recruited: continue
		if definitions[id].quality > quality: quality = int(definitions[id].quality); count = 0
		if definitions[id].quality == quality: count += 1
	if count == 0: return {"item": 102, "amount": 0, "original": 0}
	var original := int(prices[quality]["third" if step == 2 else "second" if count > 1 else "first"])
	var discount: bool = state.main.recruit_total > 3 and state.main.daily.get("recruit_discount_%d" % step, 0) == 0
	return {"item": 102, "amount": int(floor(original * rules.discount)) if discount else original, "original": original}

func chances(state: Dictionary) -> Dictionary:
	var result := {}
	var total := 0.0
	var level: Dictionary = levels[state.main.recruit_level - 1]
	for id: String in state.main.pool:
		var weight := 0.0 if id in state.main.recruited else float(level["draw_%d" % definitions[id].quality])
		result[id] = weight
		total += weight
	for id: String in result: result[id] = result[id] / total if total > 0 else 0.0
	return result

func snapshot(state: Dictionary) -> Dictionary:
	return {"offer": offer(state), "chances": chances(state), "tickets": TownMainInventory.count(state, int(rules.ticket)), "ad_left": maxi(0, int(rules.ad_limit) - int(state.main.daily.get("recruit_ads", 0))), "refresh_left": maxi(0, int(rules.refresh_limit) - state.main.recruit_refreshes), "wish_unlocked": wish_unlocked(state), "finish_silent": state.main.daily.get("recruit_finish_silent", 0) == 1}

func recruit(state: Dictionary) -> Dictionary:
	var main: Dictionary = state.main
	var choices: Array = main.pool.filter(func(id): return id not in main.recruited)
	if choices.is_empty(): return TownOperations.reject("本轮英雄已全部招募")
	var payment := offer(state)
	if TownMainInventory.count(state, payment.item) < payment.amount:
		return TownOperations.reject("英雄招募卷轴不足" if payment.item == int(rules.ticket) else "钻石不足")
	var probability := chances(state)
	var id: String = choices[_weighted(choices.map(func(key): return probability[key]))]
	var definition: Dictionary = definitions[id]
	var old_pool: Array = choices.duplicate()
	TownMainInventory.add(state, payment.item, -payment.amount)
	if payment.amount < payment.original: main.daily["recruit_discount_%d" % main.recruited.size()] = 1
	main.recruited.append(id)
	main.recruit_total += 1
	var existing: Array = main.roster.filter(func(h): return h.definition == id)
	var receipt := {"hero": id, "pool": old_pool, "new": existing.is_empty(), "fragments": 0, "before": int(main.fragments.get(id, 0)), "talent": definition.source_id, "star": definition.star}
	if existing.is_empty():
		main.roster.append({"id": _actor_ids[definition.appearance], "definition": id, "talent": definition.source_id, "name": definition.display_name, "level": 1, "star": definition.star, "locked": false, "live": "", "assigned_area": "field"})
	else:
		receipt.talent = existing[0].talent
		receipt.star = existing[0].star
		receipt.fragments = int(definition.fragment_count)
		main.fragments[id] = receipt.before + receipt.fragments
	main.recruit_exp += int(rules.experience)
	while main.recruit_level < levels.size() and main.recruit_exp >= levels[main.recruit_level - 1].experience:
		main.recruit_exp -= int(levels[main.recruit_level - 1].experience)
		main.recruit_level += 1
	main.last_recruit = id
	if main.recruited.size() == main.pool.size(): _new_batch(state)
	return {"accepted": true, "recruitment": receipt}

func _weighted(weights: Array) -> int:
	var total := 0.0
	for weight in weights: total += float(weight)
	assert(total > 0, "Recruitment weights must be positive")
	var value: float = float(_rng.next_int(1000000)) / 1000000.0 * total
	for i in weights.size():
		value -= float(weights[i])
		if value < 0: return i
	return weights.size() - 1
