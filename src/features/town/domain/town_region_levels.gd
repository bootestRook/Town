class_name TownRegionLevels
extends RefCounted

var gates: Dictionary = {}
var requirements: Dictionary = {}
var population: TownMonsterPopulation
var _state: Dictionary

func configure(data, state: Dictionary, value: TownMonsterPopulation) -> void:
	_state = state
	population = value
	state.region_levels = {}
	for row: Dictionary in data.rows("town_region_gates"):
		gates[row.id] = row
		state.region_levels[row.id] = 1
	for row: Dictionary in data.rows("town_dispatch"): requirements[row.id] = row.dungeon
	sync_unlocked()

func unlocked(area: String) -> bool:
	return gates.has(area) and int(_state.get("main", {}).get("progress", {}).get("dungeon", 0)) >= requirements[area]

func sync_unlocked() -> void:
	if _state.get("horn", {}).get("phase", "idle") in ["prepare", "fight"]: return
	for area: String in gates:
		if unlocked(area) and not population.cycles.has(area): population.rebuild(area)

func activate(command: Dictionary) -> Dictionary:
	var area := String(command.get("area", ""))
	var level := int(command.get("level", 0))
	var id := area + "." + str(level)
	if not population.stages.has(id): return TownOperations.reject("区域等级无效")
	if not unlocked(area): return TownOperations.reject("区域尚未解锁")
	if _state.horn.phase in ["prepare", "fight"]: return TownOperations.reject("BOSS战期间不能切换区域等级")
	if not _state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能切换区域等级")
	if int(_state.main.progress.get("dungeon", 0)) < population.stages[id].dungeon: return TownOperations.reject("地下城通关进度不足")
	if _state.region_levels[area] == level: return {"accepted":true, "changed":false}
	_state.region_levels[area] = level
	population.rebuild(area)
	return {"accepted":true, "changed":true}

func restore() -> void:
	population.cycles.clear()
	sync_unlocked()

func snapshot() -> Dictionary:
	var result := {}
	for area: String in gates: result[area] = {"level":_state.region_levels[area], "unlocked":unlocked(area)}
	return result
