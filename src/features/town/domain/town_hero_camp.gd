class_name TownHeroCamp
extends RefCounted

const BUILDING := "building.26"
var levels: Dictionary = {}

func initialize(state: Dictionary, data) -> void:
	for row: Dictionary in data.rows("main_hero_camp"):
		levels[int(row.level)] = row.duplicate(true)
	state.buildings[BUILDING] = 5

func capacity(state: Dictionary) -> int:
	return int(levels[state.buildings[BUILDING]].capacity)

func snapshot(state: Dictionary) -> Dictionary:
	var level: int = state.buildings[BUILDING]
	var result: Dictionary = levels[level].duplicate(true)
	result["deployed"] = state.main.team.size()
	result["max_level"] = not levels.has(level + 1)
	result["affordable"] = not result.max_level and state.coins >= result.cost
	result["preview"] = []
	for next in range(level + 1, mini(level + 3, levels.size() + 1)):
		result.preview.append({"level": next, "before": int(levels[next - 1].capacity), "after": int(levels[next].capacity)})
	return result

func upgrade(state: Dictionary) -> Dictionary:
	var level: int = state.buildings[BUILDING]
	if not levels.has(level + 1):
		return {"accepted": false, "reason": "英雄营地已满级"}
	var cost := int(levels[level].cost)
	if state.coins < cost:
		return {"accepted": false, "reason": "金币不足"}
	state.coins -= cost
	state.buildings[BUILDING] = level + 1
	return {"accepted": true}
