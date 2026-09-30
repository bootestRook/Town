class_name TownExpeditionLoot
extends RefCounted

var gates: Dictionary = {}
var fairy: Dictionary = {}
var _rng

func configure(data, rng) -> void:
	_rng = rng
	for row: Dictionary in data.rows("main_battle_gates"): gates[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("main_fairy_loot"): fairy[row.id] = row.duplicate(true)

func roll(encounter: String) -> String:
	if not fairy.has(encounter): return "-"
	var definition: Dictionary = fairy[encounter]
	var drops := {}
	for i in _pick(definition.counts):
		var tier := _pick(definition.tiers)
		var item := _pick(String(definition.pools).get_slice("|",tier-1))
		drops[item] = drops.get(item,0)+1
	var parts: Array[String] = []
	for id: int in drops: parts.append("%d:%d" % [id,drops[id]])
	return ";".join(parts)

func _pick(value: String) -> int:
	var total := 0
	for pair: String in value.split(";"): total += int(pair.get_slice(":",0))
	var draw: int = _rng.next_int(total)
	for pair: String in value.split(";"):
		draw -= int(pair.get_slice(":",0))
		if draw < 0: return int(pair.get_slice(":",1))
	return 0
