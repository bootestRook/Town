class_name TownMainInventory
extends RefCounted

static func entries(value: String) -> Dictionary:
	var result := {}
	for token: String in value.split(";"):
		var pair := token.split(":")
		if pair.size() == 2:
			var id := int(pair[0])
			result[id] = result.get(id, 0) + int(pair[1])
	return result

static func count(state: Dictionary, id: int) -> int:
	if id == 101: return state.coins
	if id == 102: return state.diamonds
	return state.inventory.get("item." + str(id), 0)

static func spend(state: Dictionary, value: String) -> bool:
	var costs := entries(value)
	for id: int in costs:
		if costs[id] < 0 or count(state, id) < costs[id]: return false
	for id: int in costs: add(state, id, -costs[id])
	return true

static func add(state: Dictionary, id: int, amount: int) -> void:
	if id == 101: state.coins += amount
	elif id == 102: state.diamonds += amount
	else:
		var key := "item." + str(id)
		state.inventory[key] = state.inventory.get(key, 0) + amount

static func grant(state: Dictionary, value: String) -> void:
	var rewards := entries(value)
	for id: int in rewards: add(state, id, rewards[id])
