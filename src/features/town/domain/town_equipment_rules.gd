class_name TownEquipmentRules
extends RefCounted

var definitions: Dictionary = {}
var _rng

func configure(data, rng) -> void:
	_rng = rng
	for row: Dictionary in data.rows("main_equipment_rules"): definitions[row.id] = row.duplicate(true)

func create(recipe: Dictionary, serial: int) -> Dictionary:
	var item := recipe.duplicate(true)
	var rule: Dictionary = definitions[item.id]
	item["serial"] = serial
	item["star"] = rule.star
	item["rank"] = rule.rank
	item["affixes"] = [{"id": rule.affix_id, "effect": rule.effect, "value": rule.minimum + _rng.next_int(rule.maximum - rule.minimum + 1)}]
	return item

static func total(equipment: Dictionary, effect: String) -> float:
	var value := 0.0
	for item: Dictionary in equipment.values():
		for affix: Dictionary in item.affixes:
			if affix.effect == effect: value += float(affix.value)
	return value

static func apply_stats(stats: Dictionary, equipment: Dictionary) -> void:
	stats.attack *= 1.0 + total(equipment, "att_up") / 10000.0
