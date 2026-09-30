class_name TownHeroDeployment
extends RefCounted

var camp: TownHeroCamp

func capacity(state: Dictionary) -> int:
	return camp.capacity(state)

func unavailable(state: Dictionary, id: String) -> bool:
	if state.get("horn", {}).get("phase", "idle") in ["prepare", "fight"] and id in state.horn.participants: return true
	return not state.main.battle.is_empty() and id in state.main.expedition_team

func command(state: Dictionary, command: Dictionary, roster: Array) -> Dictionary:
	var main: Dictionary = state.main
	var next: Array = main.team.duplicate()
	if command.type == "hero_team":
		var id := String(command.get("hero", ""))
		var found := roster.filter(func(h): return h.id == id)
		if found.is_empty(): return TownOperations.reject("英雄不存在")
		if unavailable(state, id): return TownOperations.reject("英雄正在战斗中")
		if id in next: next.erase(id)
		else:
			if next.size() >= capacity(state): return TownOperations.reject("上阵人数已满")
			next.append(id)
	else:
		var element := int(command.get("element", 0))
		if element < 0 or element > 4: return TownOperations.reject("元素不存在")
		var candidates := roster.filter(func(h): return element == 0 or h.combat.element == element)
		if candidates.is_empty(): return TownOperations.reject("暂无可上阵英雄")
		candidates.sort_custom(func(a,b): return a.power > b.power if a.power != b.power else a.id.naturalnocasecmp_to(b.id) < 0)
		next = main.team.filter(func(id): return unavailable(state, id))
		for hero: Dictionary in candidates:
			if next.size() >= capacity(state): break
			if hero.id not in next: next.append(hero.id)
	main.team = next
	return {"accepted": true}
