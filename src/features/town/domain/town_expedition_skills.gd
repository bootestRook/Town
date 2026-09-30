class_name TownExpeditionSkills
extends RefCounted

var definitions: Dictionary = {}
var combat := TownExpeditionCombat.new()
var pets := TownExpeditionPets.new()

func configure(data, rng) -> void:
	combat.configure(data, rng)
	pets.configure(data, combat)
	for row: Dictionary in data.rows("main_skills"): definitions[int(row.source_id)] = row.duplicate(true)

func descriptions() -> Dictionary:
	var result := definitions.duplicate(true)
	for row: Dictionary in result.values(): row["category"] = "active"
	for id: int in combat.passives:
		result[id] = combat.passives[id].duplicate(true)
		result[id]["cooldown"] = 0
		result[id]["category"] = "passive"
	for id: int in combat.buffs:
		result[id] = combat.buffs[id].duplicate(true)
		result[id]["cooldown"] = 0
		result[id]["category"] = "buff"
	return result

func prepare(actor: Dictionary, source: Dictionary, loadout: String) -> void:
	combat.prepare(actor, source, loadout)
	pets.prepare(actor, "")
	actor["skills"] = create(loadout)
	actor["normal"] = _skill(int(loadout.get_slice("|",0).get_slice(";",0)), 1)

func create(loadout: String) -> Array:
	var result: Array = []
	for token in loadout.split("|").slice(1):
		var parts := token.split(";")
		if parts.size() != 2 or int(parts[1]) <= 0 or not definitions.has(int(parts[0])): continue
		result.append(_skill(int(parts[0]), int(parts[1])))
	return result

func _skill(id: int, level: int) -> Dictionary:
	var definition: Dictionary = definitions[id]
	return {"id":id, "level":level, "name":definition.display_name, "cooldown":float(definition.cooldown), "remaining":0.0, "kind":int(definition.damage_type), "target":int(definition.target), "targets":int(definition.targets), "multiplier":TownExpeditionCombat.value(definition.multiplier,level)/10000.0, "percent_attribute":int(definition.percent_attribute), "percent_target":int(definition.percent_target), "buffs":definition.buffs}

func step(actor: Dictionary, allies: Array, enemies: Array, log: Array) -> bool:
	pets.step(actor, allies, enemies, log)
	var cast := false
	for skill: Dictionary in actor.skills:
		skill.remaining -= 0.05
		if skill.remaining > 0: continue
		skill.remaining += maxf(0.1,(skill.cooldown - combat.prop(actor,"cooldown_flat")/1000.0) * maxf(0.1,1.0-combat.prop(actor,"cooldown_up")/10000.0))
		attack(actor, allies, enemies, skill, false)
		log.push_front("%s · %s" % [actor.name, skill.name])
		while log.size() > 8: log.pop_back()
		cast = true
	return cast

func attack(actor: Dictionary, allies: Array, enemies: Array, skill: Dictionary, normal: bool) -> void:
	var candidates: Array = (allies if skill.kind == 2 else enemies).filter(func(h): return h.hp > 0)
	match int(skill.target):
		1: candidates.sort_custom(func(a,b): return a.hp/a.max_hp < b.hp/b.max_hp)
		2: candidates.sort_custom(func(a,b): return a.attack > b.attack)
		3: candidates.sort_custom(func(a,b): return a.defense < b.defense)
	var effects: Array = []
	for token: String in String(skill.buffs).split(";"):
		if combat.buffs.has(int(token)): effects.append({"id":int(token), "level":skill.level})
	for effect: Dictionary in actor.trigger_buffs:
		if combat.buffs[effect.id].effective == (0 if normal else 1): effects.append(effect)
	for effect: Dictionary in effects:
		if combat.buffs[effect.id].target != 1: combat.emit_buff(actor,allies,[],effect.id,effect.level)
	var recorded_damage := 0.0
	for target: Dictionary in candidates.slice(0,maxi(1,skill.targets)):
		if skill.kind == 2: combat.heal(actor,target,ceilf(actor.max_hp*skill.multiplier))
		else:
			var percent := -1.0
			if skill.kind == 3:
				var owner: Dictionary = actor if skill.percent_target == 1 else target
				percent = float(owner[{101:"max_hp",501:"max_hp",203:"attack",204:"defense"}[skill.percent_attribute]]) * skill.multiplier
			recorded_damage += combat.damage(actor,target,skill.multiplier,normal,percent)
		for effect: Dictionary in effects:
			if combat.buffs[effect.id].target == 1: combat.apply_buff(actor,target,effect.id,effect.level)
	pets.trigger(actor,normal,recorded_damage)
