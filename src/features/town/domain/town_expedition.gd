class_name TownExpedition
extends RefCounted

var levels: Array = []
var encounters: Dictionary = {}
var enemies: Dictionary = {}
var skills := TownExpeditionSkills.new()
var loot := TownExpeditionLoot.new()
var _clock := 0.0


func configure(data, rng) -> void:
	skills.configure(data, rng)
	loot.configure(data, rng)
	levels = data.rows("main_dungeons").duplicate(true)
	levels.sort_custom(func(a,b): return a.source_id < b.source_id)
	for row: Dictionary in data.rows("main_enemies"): enemies[row.id] = row.duplicate(true)
	for row: Dictionary in data.rows("main_encounters"):
		if not encounters.has(row.mode): encounters[row.mode] = []
		encounters[row.mode].append(row.duplicate(true))
	for rows: Array in encounters.values(): rows.sort_custom(func(a,b): return a.stage < b.stage)


func start(state: Dictionary, roster: Array, mode: String) -> Dictionary:
	var main: Dictionary = state.main
	if state.get("horn", {}).get("phase", "idle") in ["prepare", "fight"]: return TownOperations.reject("请先结束当前BOSS战")
	if not main.battle.is_empty():
		return TownOperations.reject("请先结束当前战斗")
	var stage := int(main.progress.get(mode, 0))
	if not encounters.has(mode) or stage >= encounters[mode].size():
		return TownOperations.reject("已完成全部关卡")
	var level: Dictionary = encounters[mode][stage]
	var gate: Dictionary = loot.gates.get(level.id,{})
	if not gate.is_empty() and main.progress.get("dungeon",0) < gate.dungeon: return TownOperations.reject("地下城通关进度不足")
	if mode == "dungeon" and state.city_level < levels[stage].city_level:
		return TownOperations.reject("主城等级不足")
	var allies: Array = []
	for hero: Dictionary in roster:
		if hero.id in main.expedition_team:
			allies.append({"id": hero.id, "name": hero.name, "portrait": hero.portrait, "hp": hero.stats.max_hp, "max_hp": hero.stats.max_hp, "attack": hero.stats.attack, "defense": hero.stats.defense, "frequency": 1.0, "cooldown": 0.0})
			skills.prepare(allies[-1], hero.combat, hero.skills)
			skills.pets.prepare(allies[-1], hero.pet_skills)
	if allies.is_empty():
		return TownOperations.reject("请先选择出战英雄")
	var cost := int(level.cost)
	if main.energy < cost:
		return TownOperations.reject("净化之力不足")
	if not gate.is_empty() and not TownMainInventory.spend(state,gate.cost): return TownOperations.reject("召唤材料不足")
	main.energy -= cost
	var foes: Array = []
	for id: String in String(level.enemies).split(";"):
		var enemy: Dictionary = enemies[id]
		foes.append({"id": id + "." + str(foes.size()), "name": enemy.display_name, "portrait": enemy.resource_id, "hp": enemy.hp, "max_hp": enemy.hp, "attack": enemy.attack, "defense": enemy.defense, "frequency": enemy.frequency, "cooldown": 0.5})
		skills.prepare(foes[-1], enemy, enemy.skills)
	main.battle = {"mode": mode, "stage": stage, "title": level.title, "allies": allies, "enemies": foes, "elapsed": 0.0, "timeout": level.seconds, "round": 0, "status": "fighting", "log": [], "reward": level.rewards, "claimed": false}
	main.battle["encounter"] = level.id
	main.battle["preparation"] = float(gate.get("preparation",0))
	_clock = 0.0
	return {"accepted": true}


func advance(state: Dictionary, seconds: float) -> void:
	var battle: Dictionary = state.main.battle
	if battle.is_empty() or battle.status != "fighting":
		return
	_clock += seconds * (2.0 if state.main.battle_speed == 2 else 1.0)
	while _clock >= 0.05 and battle.status == "fighting":
		_clock -= 0.05
		if battle.preparation > 0:
			battle.preparation = maxf(0,battle.preparation-0.05)
			continue
		battle.elapsed += 0.05
		battle.round += 1
		for side: Array in [[battle.allies, battle.enemies], [battle.enemies, battle.allies]]:
			for attacker: Dictionary in side[0]:
				attacker.cooldown -= 0.05
				if not skills.combat.tick(attacker):
					continue
				if skills.step(attacker, side[0], side[1], battle.log): continue
				if attacker.cooldown > 0: continue
				attacker.cooldown += 1.0 / maxf(0.1, attacker.frequency * (1.0 + skills.combat.prop(attacker,"speed_up")/10000.0))
				var targets: Array = side[1].filter(func(h): return h.hp > 0)
				if targets.is_empty():
					break
				skills.attack(attacker, side[0], side[1], attacker.normal, true)
				battle.log.push_front("%s · %s" % [attacker.name, "治疗" if attacker.normal.kind == 2 else "普攻"])
				if battle.log.size() > 8:
					battle.log.pop_back()
		if battle.enemies.all(func(h): return h.hp <= 0):
			battle.status = "won"
		elif battle.allies.all(func(h): return h.hp <= 0) or battle.elapsed >= battle.timeout:
			battle.status = "lost"


func claim(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.main.battle
	if battle.is_empty() or battle.status != "won" or battle.claimed:
		return TownOperations.reject("没有可领取的战斗奖励")
	battle.claimed = true
	battle.reward += ";" + loot.roll(battle.encounter)
	grant(state, battle.reward)
	state.main.progress[battle.mode] = battle.stage + 1
	return {"accepted": true, "message": "奖励已领取"}


static func grant(state: Dictionary, rewards: String) -> void:
	for pair: String in rewards.split(";"):
		var values := pair.split(":")
		if values.size() != 2:
			continue
		var item := "item." + values[0]
		var amount := int(values[1])
		if values[0] == "101":
			state.coins += amount
		elif values[0] == "102":
			state.diamonds += amount
		else:
			state.inventory[item] = state.inventory.get(item, 0) + amount
