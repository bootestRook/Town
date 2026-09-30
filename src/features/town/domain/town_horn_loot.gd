class_name TownHornLoot
extends RefCounted

var rng
var chests: Dictionary = {}

func configure(data, stream) -> void:
	rng = stream
	for row: Dictionary in data.rows("main_horn_chests"): chests[row.id] = row.rewards

func roll_drops(value: String) -> Dictionary:
	var result := {}
	for entry: String in value.split(";"):
		var fields := entry.split("|")
		if fields.size() != 4 or rng.next_int(10000) >= int(fields[1]): continue
		var quantity: int = int(fields[2]) + rng.next_int(int(fields[3]) - int(fields[2]) + 1)
		var id := int(fields[0])
		result[id] = result.get(id, 0) + quantity
	return result

func roll_chest(value: String) -> Dictionary:
	var choices := value.split(";")
	var key := "horn_chest." + choices[rng.next_int(choices.size())]
	var result := {}
	for entry: String in String(chests[key]).split(";"):
		var fields := entry.split(":")
		if fields.size() != 3: continue
		var id := int(fields[0])
		result[id] = result.get(id, 0) + int(fields[1]) + rng.next_int(int(fields[2]) - int(fields[1]) + 1)
	return result

static func grant(state: Dictionary, rewards: Dictionary) -> void:
	for id: int in rewards: TownMainInventory.add(state, id, int(rewards[id]))
