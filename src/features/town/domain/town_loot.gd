class_name TownLoot
extends RefCounted

var items: Dictionary = {}
var rules: Dictionary = {}
var _drops: Array = []
var _state: Dictionary
var _rng


func initialize(state: Dictionary, data, rng) -> void:
	_state = state
	_rng = rng
	_drops = data.rows("town_drops").duplicate(true)
	rules = data.rows("town_loot_rules")[0].duplicate(true)
	for row: Dictionary in data.rows("town_loot_items"): items[row.id] = row.duplicate(true)
	state["ground_drops"] = []
	state["loot_cues"] = []
	state["missed_loot"] = {}
	state["loot_serial"] = 0
	assert(validation_error().is_empty(), validation_error())


func validation_error() -> String:
	for row: Dictionary in _drops:
		if not items.has(row.item): return "Unknown loot item: " + row.item
		if row.minimum < 1 or row.maximum < row.minimum: return "Invalid loot quantity: " + row.id
		if row.chance < 0 or row.chance > 10000: return "Invalid loot chance: " + row.id
	return ""


func roll(monster: String, recipient: String) -> Dictionary:
	var result := {}
	for row: Dictionary in _drops:
		if row.monster != monster or row.recipient != recipient: continue
		if _rng.next_int(10000) >= int(row.chance): continue
		var amount: int = row.minimum
		if row.maximum > row.minimum: amount += _rng.next_int(int(row.maximum - row.minimum + 1))
		result[row.item] = result.get(row.item, 0) + amount
	return result


func defeat(monster: Dictionary, killer: Dictionary, owner) -> void:
	var participants: Array = []
	for id: String in monster.contributors:
		for hero: Dictionary in _state.heroes:
			if hero.id == id: participants.append(hero)
	# Direct rule callers also supply the actual killing hero.
	if not killer.is_empty() and not participants.any(func(h): return h.id == killer.id): participants.append(killer)
	grant_heroes(roll(monster.kind, "hero"), participants, monster.position, int(monster.base.coins), int(monster.base.experience), owner)
	spawn(roll(monster.kind, "ground"), monster.position, false)
	owner.record("战利品", "%s被击败 · %d名佣兵获得战利品" % [monster.name, participants.size()], 0)


func grant_heroes(rewards: Dictionary, heroes: Array, origin: Vector2, coins: int, experience: int, owner) -> void:
	if heroes.is_empty(): return
	var allocations: Array = []
	for hero: Dictionary in heroes: allocations.append({})
	for item: String in rewards:
		assert(items.has(item), "Unknown hero loot item")
		var count := int(rewards[item])
		var equal := count / heroes.size()
		for allocation: Dictionary in allocations: allocation[item] = equal
		for i in count % heroes.size():
			var recipient: int = _rng.next_int(heroes.size())
			allocations[recipient][item] += 1
	for i in heroes.size():
		var hero: Dictionary = heroes[i]
		var gold := coins / heroes.size()
		var exp := experience / heroes.size()
		hero.wallet += gold
		owner.gain_hero_experience(hero.id, exp)
		if gold > 0 or exp > 0: cue("earnings", origin, {"hero": hero.id, "coins": gold, "experience": exp})
		for item: String in allocations[i]:
			var amount := mini(int(allocations[i][item]), maxi(0, int(items[item].max_count) - int(hero.bag.get(item, 0))))
			if amount <= 0: continue
			hero.bag[item] = hero.bag.get(item, 0) + amount
			cue("hero_item", origin, {"hero": hero.id, "item": item, "count": amount})


func spawn(rewards: Dictionary, origin: Vector2, boss: bool) -> void:
	for item: String in rewards:
		assert(items.has(item), "Unknown ground loot item")
		if int(rewards[item]) <= 0: continue
		_state.loot_serial += 1
		_state.ground_drops.append({"id": _state.loot_serial, "item": item, "count": int(rewards[item]), "origin": origin, "born": _state.time, "lifetime": rules.boss_seconds if boss else rules.normal_seconds})


func pickup(id: int, owner) -> Dictionary:
	for drop: Dictionary in _state.ground_drops:
		if drop.id != id: continue
		var age: float = _state.time - drop.born
		if age < 0.5: return TownOperations.reject("物品尚未落地")
		if age >= drop.lifetime: return TownOperations.reject("掉落物已消失")
		var definition: Dictionary = items[drop.item]
		var current := TownMainInventory.count(_state, int(definition.source_id))
		if current + int(drop.count) > int(definition.max_count): return TownOperations.reject("该物品持有数量已达上限")
		TownMainInventory.add(_state, int(definition.source_id), int(drop.count))
		_state.ground_drops.erase(drop)
		cue("pickup", drop.origin, {"item": drop.item, "count": drop.count, "scatter": drop.id})
		owner.record("拾取", "%s ×%d" % [definition.display_name, drop.count], 0)
		return {"accepted": true, "item": drop.item, "count": drop.count}
	return TownOperations.reject("掉落物已拾取或消失")


func step() -> void:
	var remaining: Array = []
	for drop: Dictionary in _state.ground_drops:
		if _state.time - drop.born >= drop.lifetime:
			_state.missed_loot[drop.item] = _state.missed_loot.get(drop.item, 0) + drop.count
		else: remaining.append(drop)
	_state.ground_drops = remaining
	_state.loot_cues = _state.loot_cues.filter(func(c): return _state.time - c.born < 2.5)


func cue(kind: String, origin: Vector2, values: Dictionary) -> void:
	_state.loot_serial += 1
	var event := {"id": _state.loot_serial, "kind": kind, "origin": origin, "born": _state.time}
	event.merge(values)
	_state.loot_cues.append(event)
