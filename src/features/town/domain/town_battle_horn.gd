class_name TownBattleHorn
extends RefCounted

const BUILDING := "building.12"
const TICKET := 12001
var levels: Dictionary = {}
var encounter := TownHornEncounter.new()
var loot := TownHornLoot.new()
var world_loot: TownLoot
var _state: Dictionary
var _day := -1

func initialize(state: Dictionary, data, simulation, rng) -> void:
	_state = state
	world_loot = simulation.combat.loot
	for row: Dictionary in data.rows("main_horn_levels"): levels[int(row.level)] = row
	state.buildings[BUILDING] = 1
	state.horn = {"phase":"idle", "level":1, "remaining":0.0, "elapsed":0.0, "free":4, "paid":0, "cooldown":0.0, "participants":[], "ready":[], "payment":{}, "sweep":false, "queue":0, "budget":0, "cleared":0, "chest":{}, "result":"", "rewards":{}, "serial":0}
	loot.configure(data, rng)
	encounter.configure(state, data, simulation)
	simulation.horn = self

func set_day(unix_seconds_utc8: float) -> void:
	var day := floori(unix_seconds_utc8 / 86400.0)
	if day == _day: return
	_day = day
	_state.horn.free = 4
	_state.horn.paid = 0

func active() -> bool:
	return _state.horn.phase in ["prepare", "fight"]

func snapshot() -> Dictionary:
	var result: Dictionary = _state.horn.duplicate(true)
	result.building_level = _state.buildings[BUILDING]
	result.levels = levels.duplicate(true)
	result.ticket_count = TownMainInventory.count(_state, TICKET)
	result.payment_next = payment()
	result.origin = encounter.origin
	result.boss_hp = _state.monsters[0].hp if result.phase == "fight" else 0.0
	return result

func payment() -> Dictionary:
	if _state.horn.free > 0: return {"kind":"free", "amount":1}
	if TownMainInventory.count(_state, TICKET) > 0: return {"kind":"ticket", "amount":1}
	return {"kind":"diamonds", "amount":mini(300, (int(_state.horn.paid) + 1) * 50)}

func quote(count: int) -> Dictionary:
	var free := mini(count, _state.horn.free)
	var tickets := mini(count - free, TownMainInventory.count(_state, TICKET))
	var diamonds := 0
	for i in count - free - tickets: diamonds += mini(300, (int(_state.horn.paid) + i + 1) * 50)
	return {"free":free, "tickets":tickets, "diamonds":diamonds}

func command(command: Dictionary, owner) -> Dictionary:
	match command.get("action", ""):
		"upgrade": return upgrade()
		"summon": return start(int(command.get("level", 0)), bool(command.get("sweep", false)), int(command.get("count", 1)), bool(command.get("confirmed", false)), owner)
		"cancel":
			if not active() and _state.horn.queue == 0: return TownOperations.reject("当前没有BOSS战")
			_state.horn.queue = 0
			if active(): finish("cancelled", owner)
			return {"accepted":true}
		"chest":
			if _state.horn.chest.is_empty(): return TownOperations.reject("没有可开启的BOSS宝箱")
			var rewards: Dictionary = _state.horn.chest.duplicate()
			TownHornLoot.grant(_state, rewards)
			_state.horn.chest.clear()
			return {"accepted":true, "rewards":rewards}
	return TownOperations.reject("无效操作")

func upgrade() -> Dictionary:
	var level := int(_state.buildings[BUILDING])
	if level >= levels.size(): return TownOperations.reject("已达最高等级")
	if _state.main.progress.get("dungeon", 0) < levels[level].dungeon: return TownOperations.reject("地下城通关进度不足")
	if _state.coins < levels[level].cost: return TownOperations.reject("金币不足")
	_state.coins -= int(levels[level].cost)
	_state.buildings[BUILDING] += 1
	return {"accepted":true}

func start(level: int, sweep: bool, count: int, confirmed: bool, owner) -> Dictionary:
	var h: Dictionary = _state.horn
	if active(): return TownOperations.reject("请先结束当前BOSS战")
	if not _state.main.battle.is_empty(): return TownOperations.reject("请先结束当前战斗")
	if h.cooldown > 0: return TownOperations.reject("冷却中,请%d秒后重试" % ceili(h.cooldown))
	if not levels.has(level) or level > _state.buildings[BUILDING]: return TownOperations.reject("战斗号角等级不足")
	if count not in [1,5,10] or (not sweep and count != 1): return TownOperations.reject("召唤次数无效")
	if sweep and level > h.cleared: return TownOperations.reject("您尚未击败过该BOSS，击败该BOSS后开启该BOSS的扫荡功能！")
	var participants: Array = _state.heroes.filter(func(a): return a.deployed and a.assigned_area != "town")
	if participants.is_empty(): return TownOperations.reject("请先选择出战英雄")
	if not sweep and participants.all(func(a): return a.needs.hp <= 0): return TownOperations.reject("没有可战斗的英雄")
	var pay := payment()
	var bill := quote(count)
	if _state.diamonds < bill.diamonds: return TownOperations.reject("钻石不足")
	if not confirmed and (bill.diamonds > 0 or not h.chest.is_empty()):
		var prompt := "是否消耗%d钻石召唤BOSS？" % bill.diamonds if count == 1 else "本次%d次扫荡消耗免费次数%d次、召唤券%d张、钻石%d。确定继续吗？" % [count,bill.free,bill.tickets,bill.diamonds]
		return {"accepted":false, "confirm":true, "reason":("当前存在尚未开启的BOSS宝箱，新的宝箱掉落后将替换旧宝箱。\n" if not h.chest.is_empty() else "") + (prompt if bill.diamonds > 0 else "确定要召唤BOSS吗？")}
	h.payment = pay.duplicate()
	h.payment.day = _day
	if pay.kind == "free": h.free -= 1
	elif pay.kind == "ticket": TownMainInventory.add(_state, TICKET, -pay.amount)
	else:
		_state.diamonds -= pay.amount
		h.paid += 1
	h.merge({"phase":"prepare", "level":level, "remaining":1.5 if sweep else float(levels[level].prepare_seconds), "elapsed":0.0, "participants":participants.map(func(a): return a.id), "ready":[], "sweep":sweep, "queue":count - 1, "result":"", "rewards":{}, "serial":h.serial + 1}, true)
	h.budget = bill.diamonds - (pay.amount if pay.kind == "diamonds" else 0)
	owner.select_hero("")
	encounter.prepare(participants, sweep)
	owner.record("召唤BOSS", levels[level].display_name, 0)
	return {"accepted":true, "started":true}

func step(dt: float, owner) -> void:
	var h: Dictionary = _state.horn
	h.cooldown = maxf(0.0, h.cooldown - dt)
	if not active():
		if h.queue > 0 and h.cooldown <= 0:
			var count := int(h.queue)
			var budget := int(h.budget)
			var cost: int = payment().amount if payment().kind == "diamonds" else 0
			var result := start(h.level, true, 1, cost <= budget, owner)
			if result.accepted:
				h.queue = count - 1
				h.budget = budget - cost
			else:
				h.queue = 0
				h.result = result.reason
				owner.record("扫荡结束", result.reason, 0)
		return
	h.remaining = maxf(0.0, h.remaining - dt)
	h.elapsed += dt
	if h.phase == "prepare":
		if not h.sweep and h.ready.size() == h.participants.size(): h.remaining = minf(h.remaining, 3.0)
		if h.remaining <= 0:
			h.phase = "fight"
			h.remaining = 30.0 if h.sweep else float(levels[h.level].fight_seconds)
			h.elapsed = 0.0
			encounter.spawn(levels[h.level])
	elif _state.monsters[0].hp <= 0 or (h.sweep and h.elapsed >= 0.3): finish("won", owner)
	elif h.remaining <= 0: finish("timeout", owner)
	elif not h.sweep and _state.heroes.filter(func(a): return a.id in h.participants).all(func(a): return a.needs.hp <= 0): finish("lost", owner)

func finish(result: String, owner) -> void:
	var h: Dictionary = _state.horn
	if not active(): return
	var definition: Dictionary = levels[h.level]
	if result == "won":
		h.cleared = maxi(h.cleared, h.level)
		h.rewards = loot.roll_drops(definition.drop_ground)
		if h.sweep: TownHornLoot.grant(_state, h.rewards)
		else: world_loot.spawn(_item_keys(h.rewards), encounter.origin, true)
		h.chest = loot.roll_chest(definition.chest)
		if h.sweep:
			TownHornLoot.grant(_state, h.chest)
			h.chest.clear()
		var heroes: Array = _state.heroes.filter(func(hero): return hero.id in h.participants)
		world_loot.grant_heroes(_item_keys(loot.roll_drops(definition.drop_hero)), heroes, encounter.origin, int(definition.coins), int(definition.experience), owner)
	else:
		var pay: Dictionary = h.payment
		if pay.kind == "free" and pay.day == _day: h.free = mini(4, h.free + 1)
		elif pay.kind == "ticket": TownMainInventory.add(_state, TICKET, pay.amount)
		elif pay.kind == "diamonds":
			_state.diamonds += pay.amount
			if pay.day == _day: h.paid = maxi(0, h.paid - 1)
		h.queue = 0
	h.phase = "idle"
	h.cooldown = 5.0
	h.payment = {}
	h.result = result
	encounter.restore()
	owner.record("BOSS战结束", {"won":"挑战成功", "lost":"挑战失败，消耗已返还", "timeout":"挑战超时，消耗已返还", "cancelled":"挑战中止，消耗已返还"}[result], 0)

static func _item_keys(rewards: Dictionary) -> Dictionary:
	var result := {}
	for id: int in rewards: result["item." + str(id)] = rewards[id]
	return result
