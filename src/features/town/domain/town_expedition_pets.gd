class_name TownExpeditionPets
extends RefCounted

# Source btPet: one timed buff/attack, fourth normal attack, or active-skill completion.
var definitions: Dictionary = {}
var combat: TownExpeditionCombat

func configure(data, rules: TownExpeditionCombat) -> void:
	combat = rules
	for row: Dictionary in data.rows("main_pet_skills"): definitions[int(row.source_id)] = row.duplicate(true)

func prepare(actor: Dictionary, loadout: String) -> void:
	actor["pet_actions"] = []
	actor["pet_normals"] = 0
	for token: String in loadout.split("|"):
		var pair := token.split(";")
		if pair.size() != 2 or not definitions.has(int(pair[0])): continue
		actor.pet_actions.append({"id":int(pair[0]),"level":int(pair[1]),"remaining":0.0,"delay":-1.0,"record":0.0})

func trigger(actor: Dictionary, normal: bool, damage: float) -> void:
	if actor.pet_actions.is_empty(): return
	if normal:
		actor.pet_normals += 1
		if actor.pet_normals < 4: return
		actor.pet_normals = 0
	if damage <= 0: return
	for action: Dictionary in actor.pet_actions:
		var definition: Dictionary = definitions[action.id]
		if definition.trigger == (2 if normal else 3):
			action.delay = definition.delay / 1000.0
			action.record = damage

func step(actor: Dictionary, allies: Array, enemies: Array, log: Array) -> void:
	for action: Dictionary in actor.pet_actions:
		var definition: Dictionary = definitions[action.id]
		action.remaining -= 0.05
		if action.delay >= 0:
			action.delay -= 0.05
			if action.delay <= 0:
				_emit(actor, allies, enemies, action, definition)
				action.delay = -1.0
				log.push_front("%s · %s" % [actor.name,definition.display_name])
				while log.size() > 8: log.pop_back()
		if int(definition.trigger) in [0,1] and action.remaining <= 0 and action.delay < 0:
			action.remaining = TownExpeditionCombat.value(definition.cooldown,action.level)/1000.0
			action.delay = definition.delay/1000.0

func _emit(actor: Dictionary, allies: Array, enemies: Array, action: Dictionary, definition: Dictionary) -> void:
	var targets: Array = enemies.filter(func(h): return h.hp > 0).slice(0,definition.targets)
	for token: String in String(definition.buffs).split(";"):
		if combat.buffs.has(int(token)): combat.emit_buff(actor,allies,targets,int(token),action.level)
	var multiplier := TownExpeditionCombat.value(definition.multiplier,action.level)/10000.0
	for target: Dictionary in targets:
		if target.invincible_remaining > 0: continue
		var amount: float = action.record * multiplier
		if definition.trigger == 1:
			# Phoenix uses the owner's defense as its attacking property.
			var source := actor.duplicate(true)
			source.attack = actor.defense
			source.properties["attack_up"] = 0.0
			source.effects = source.effects.filter(func(e): return not (TownExpeditionCombat.BUFF.has(e.kind) and TownExpeditionCombat.BUFF[e.kind][0] == "attack_up"))
			var fluctuate: float = combat.rules[1077] + combat.rng.next_int(maxi(1,roundi((combat.rules[1078]-combat.rules[1077])*1000)+1))/1000.0
			amount = maxf(100*fluctuate,TownExpeditionCombat.base_damage(source,target)*fluctuate*(1.0+(TownExpeditionCombat.prop(actor,"hurt")-TownExpeditionCombat.prop(target,"reduction"))/10000.0)*multiplier)
		target.hp = maxf(0,target.hp-ceilf(amount))
