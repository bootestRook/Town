class_name TownMapDispatch
extends RefCounted

var areas: Dictionary = {}

func configure(data) -> void:
	for row: Dictionary in data.rows("town_dispatch"): areas[row.id] = row

func snapshot(state: Dictionary) -> Dictionary:
	var result := areas.duplicate(true)
	for area: Dictionary in result.values():
		area["unlocked"] = int(state.main.progress.get("dungeon", 0)) >= area.dungeon
	return result

func preview(state: Dictionary, command: Dictionary, roster: Array) -> Dictionary:
	var area := String(command.get("area", ""))
	var ids = command.get("heroes", [])
	if ids is not Array or ids.is_empty(): return TownOperations.reject("请选择英雄")
	if not areas.has(area): return TownOperations.reject("地图不存在")
	if not snapshot(state)[area].unlocked: return TownOperations.reject("地图未解锁")
	if not state.main.battle.is_empty(): return TownOperations.reject("战斗期间不能调整派遣")
	var eligible: Array = []
	var weak: Array = []
	var names: Array[String] = []
	for id in ids:
		var found := roster.filter(func(h): return h.id == id)
		if found.is_empty(): return TownOperations.reject("英雄不存在")
		if id not in state.main.team: return TownOperations.reject("请先将英雄加入出战队伍")
		if state.get("horn", {}).get("phase", "idle") in ["prepare", "fight"] and id in state.horn.participants: return TownOperations.reject("英雄正在BOSS战中")
		if id in eligible or id in weak: return TownOperations.reject("英雄重复")
		if found[0].power < areas[area].power:
			weak.append(id)
			names.append(found[0].name)
		else: eligible.append(id)
	return {"accepted":true, "area":area, "eligible":eligible, "weak":weak, "names":names, "power":areas[area].power}

func commit(state: Dictionary, command: Dictionary, roster: Array) -> Dictionary:
	var assignments = command.get("assignments", {})
	var confirmed = command.get("confirmed", {})
	if assignments is not Dictionary or confirmed is not Dictionary: return TownOperations.reject("派遣数据无效")
	# Validate the entire change set before writing any instance state.
	for id in assignments:
		var old := roster.filter(func(h): return h.id == id)
		if old.is_empty(): return TownOperations.reject("英雄不存在")
		if id not in state.main.team: return TownOperations.reject("请先将英雄加入出战队伍")
		if assignments[id] == old[0].assigned_area: continue
		var result := preview(state, {"area":assignments[id], "heroes":[id]}, roster)
		if not result.accepted: return result
		if not result.weak.is_empty() and confirmed.get(id, "") != assignments[id]: return TownOperations.reject("请确认低战力派遣")
	for entry: Dictionary in state.main.roster:
		if assignments.has(entry.id): entry.assigned_area = assignments[entry.id]
	return {"accepted":true}
