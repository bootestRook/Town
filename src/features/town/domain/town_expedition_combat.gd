class_name TownExpeditionCombat
extends RefCounted

# Property codes come from the client passive/buff registrations, not content IDs.
const PASSIVE = {1:"hp_up",2:"hurt",3:"defense_up",4:"critical",5:"bonus",6:"hit",7:"dodge",8:"speed_up",9:"restraint",10:"restraint_resist",11:"toughness",12:"monster_damage",13:"hero_damage",14:"penetration",15:"reduction",16:"boss_damage",17:"poison_damage",18:"bleed_damage",19:"burn_damage",20:"dot_damage",21:"invincibility",22:"cooldown_flat",23:"large_target_damage"}
const BUFF = {2:["skill_damage",1],3:["hurt",1],4:["attack_up",-1],5:["defense_up",1],6:["defense_up",-1],7:["speed_up",1],8:["speed_up",-1],9:["hit",1],10:["hit",-1],11:["dodge",1],12:["dodge",-1],13:["critical",1],14:["critical",-1],30:["poison_damage",1],31:["bleed_damage",1],33:["burn_damage",1],39:["attack_up",1],40:["toughness",1],41:["bonus",1],42:["hp_up",1],44:["attack_up",1],45:["healing",1],46:["reduction",1],47:["blood",1],52:["restraint",1],53:["cooldown_up",1],57:["receive_healing",-1]}
var passives: Dictionary = {}
var buffs: Dictionary = {}
var rules: Dictionary = {}
var rng

func configure(data, stream) -> void:
	rng = stream
	for row: Dictionary in data.rows("main_passives"): passives[int(row.source_id)] = row.duplicate(true)
	for row: Dictionary in data.rows("main_buffs"): buffs[int(row.source_id)] = row.duplicate(true)
	for row: Dictionary in data.rows("main_combat_rules"): rules[int(row.source_id)] = row.value

static func value(values: String, level: int) -> float:
	var entries := values.split(";")
	return float(entries[clampi(level - 1, 0, entries.size() - 1)])

func prepare(actor: Dictionary, source: Dictionary, loadout: String) -> void:
	actor["properties"] = {}
	actor["base_hp"] = actor.max_hp
	actor["effects"] = []
	actor["trigger_buffs"] = []
	actor["invincible_remaining"] = 0.0
	actor["invincible_cooldown"] = 0.0
	actor["hit_target"] = ""
	actor["hit_count"] = 0
	actor["element"] = int(source.element)
	actor["role"] = source.get("role", "hero")
	for key: String in ["hit", "dodge", "critical", "bonus", "toughness", "blood", "hurt", "reduction"]: actor.properties[key] = float(source[key])
	actor.frequency = source.frequency
	for token: String in loadout.split("|"):
		var pair := token.split(";")
		if pair.size() != 2 or int(pair[1]) <= 0: continue
		var id := int(pair[0])
		if passives.has(id):
			var definition: Dictionary = passives[id]
			var key: String = PASSIVE[int(definition.kind)]
			actor.properties[key] = actor.properties.get(key, 0.0) + value(definition.multiplier, int(pair[1]))
		elif buffs.has(id): actor.trigger_buffs.append({"id": id, "level": int(pair[1])})
	actor.max_hp *= 1.0 + prop(actor, "hp_up") / 10000.0
	actor.hp = actor.max_hp

static func prop(actor: Dictionary, key: String) -> float:
	var result: float = actor.properties.get(key, 0.0)
	for effect: Dictionary in actor.effects:
		if BUFF.has(effect.kind) and BUFF[effect.kind][0] == key: result += effect.amount * BUFF[effect.kind][1]
	return result

static func base_damage(actor: Dictionary, target: Dictionary) -> float:
	var attack: float = actor.attack * maxf(0.0, 1.0 + prop(actor, "attack_up") / 10000.0)
	var defense: float = target.defense * maxf(0.0, 1.0 + prop(target, "defense_up") / 10000.0) * (1.0 - clampf(prop(actor, "penetration") / 10000.0, 0, 1))
	if attack <= 0: return 0
	return attack * attack / (attack + defense) * 0.8 + 0.4 * (attack - defense / 3.0)

static func restrained(actor: Dictionary, target: Dictionary) -> bool:
	return [actor.element, target.element] in [[1,3],[3,2],[2,1]]

func damage(actor: Dictionary, target: Dictionary, multiplier: float, normal: bool, percent: float = -1.0) -> float:
	if target.invincible_remaining > 0: return 0
	if normal:
		if target.effects.any(func(e): return e.kind == 56): return 0
		var chance: float = (prop(actor, "hit") + rules[1174]) / maxf(1, prop(target, "dodge") + rules[1174])
		if not roll(chance * 10000.0): return 0
	var fluctuate: float = rules[1077] + rng.next_int(maxi(1, roundi((rules[1078] - rules[1077]) * 1000) + 1)) / 1000.0
	var restraint := 1.0
	if restrained(actor, target): restraint += 0.2 * (1.0 + prop(actor,"restraint")/10000.0) * (1.0 - prop(target,"restraint_resist")/10000.0)
	var role_bonus := prop(actor, "hero_damage" if target.role == "hero" else "monster_damage")
	if target.role == "boss": role_bonus += prop(actor, "boss_damage")
	var dot := false
	for pair: Array in [[15,"poison_damage"],[16,"bleed_damage"],[19,"burn_damage"]]:
		if target.effects.any(func(e): return e.kind == pair[0]): role_bonus += prop(actor,pair[1]); dot = true
	if dot: role_bonus += prop(actor, "dot_damage")
	var large := prop(actor, "large_target_damage") * minf(3.0, target.max_hp / actor.max_hp) / 10000.0 if target.max_hp > actor.max_hp else 0.0
	var final_bonus := 1.0 + (prop(actor,"hurt") - prop(target,"reduction")) / 10000.0
	var amount: float
	if normal: amount = base_damage(actor,target) * restraint * fluctuate * (1.0+role_bonus/10000.0) * (final_bonus+large) * multiplier
	else: amount = base_damage(actor,target) * restraint * fluctuate * (multiplier + role_bonus/10000.0 + prop(actor,"skill_damage")/10000.0 + large) * final_bonus
	amount = maxf(ceilf(amount), ceilf(100.0 * fluctuate))
	if percent >= 0: amount = maxf(100, ceilf(percent))
	if normal and roll(prop(actor,"critical") - prop(target,"toughness")): amount = ceilf(amount * prop(actor,"bonus") / 10000.0)
	var actual := minf(target.hp, amount)
	target.hp = maxf(0, target.hp - amount)
	if normal:
		heal(actor, actor, actual * prop(actor,"blood") / 10000.0)
		if actor.hit_target != target.id: actor.hit_target = target.id; actor.hit_count = 0
		actor.hit_count += 1
		if actor.hit_count >= 5:
			actor.hit_count = 0
			for effect: Dictionary in actor.effects:
				if effect.kind == 58 and target.role != "boss": target.hp = maxf(0,target.hp - ceilf(target.max_hp * effect.amount/10000.0))
	return actual

static func heal(actor: Dictionary, target: Dictionary, amount: float) -> void:
	var adjusted := ceilf(amount * (1.0+prop(actor,"healing")/10000.0) * maxf(0,1.0+prop(target,"receive_healing")/10000.0))
	target.hp = minf(target.max_hp, target.hp + adjusted)

func apply_buff(actor: Dictionary, target: Dictionary, id: int, level: int) -> void:
	if not buffs.has(id) or target.hp <= 0: return
	var definition: Dictionary = buffs[id]
	var elements := {4:[3,4],5:[1,4],6:[2,4],7:[4]}
	if elements.has(int(definition.selector)) and target.element not in elements[int(definition.selector)]: return
	if target.role == "boss" and definition.boss_immune >= 10000: return
	if not roll(value(definition.chance,level)): return
	var amount := value(definition.multiplier,level)
	if definition.kind == 1: heal(actor,target,target.max_hp*amount/10000.0); return
	var previous: Array = target.effects.filter(func(e): return e.id == id)
	if not previous.is_empty(): _remove_effect(target,previous[0])
	target.effects.append({"id":id,"kind":int(definition.kind),"amount":amount,"remaining":value(definition.duration,level)/1000.0,"interval":definition.interval/1000.0,"tick":0.0,"dot":maxf(100,ceilf(base_damage(actor,target)*amount/10000.0))})
	if definition.kind == 42:
		var added := roundf(target.base_hp*amount/10000.0)
		target.max_hp += added
		target.hp += added

func emit_buff(actor: Dictionary, allies: Array, targets: Array, id: int, level: int) -> void:
	var definition: Dictionary = buffs[id]
	var choices: Array = [actor] if definition.target == 2 else (allies if definition.target == 3 else targets).filter(func(h): return h.hp > 0)
	if definition.target == 3:
		var elements := {4:[3,4],5:[1,4],6:[2,4],7:[4]}
		if elements.has(int(definition.selector)): choices = choices.filter(func(h): return h.element in elements[int(definition.selector)])
		match int(definition.selector):
			0:
				while choices.size() > definition.targets: choices.remove_at(rng.next_int(choices.size()))
			1: choices.sort_custom(func(a,b): return a.hp < b.hp)
			2: choices.sort_custom(func(a,b): return a.attack < b.attack)
			3: choices.sort_custom(func(a,b): return a.attack > b.attack)
		choices = choices.slice(0,definition.targets)
	for target: Dictionary in choices: apply_buff(actor,target,id,level)

static func _remove_effect(actor: Dictionary, effect: Dictionary) -> void:
	actor.effects.erase(effect)
	if effect.kind == 42:
		actor.max_hp -= roundf(actor.base_hp*effect.amount/10000.0)
		actor.hp = minf(actor.hp,actor.max_hp)

func tick(actor: Dictionary) -> bool:
	actor.invincible_remaining = maxf(0,actor.invincible_remaining - 0.05)
	actor.invincible_cooldown = maxf(0,actor.invincible_cooldown - 0.05)
	if actor.hp > 0 and actor.hp < actor.max_hp * 0.5 and actor.invincible_cooldown == 0 and prop(actor,"invincibility") > 0:
		actor.invincible_cooldown = 60.0
		actor.invincible_remaining = prop(actor,"invincibility")/1000.0
	for effect: Dictionary in actor.effects.duplicate():
		if effect.remaining > 0:
			effect.remaining -= 0.05
			if effect.remaining <= 0: _remove_effect(actor,effect); continue
		if effect.kind in [15,16,19] and effect.interval > 0:
			effect.tick -= 0.05
			if effect.tick <= 0:
				effect.tick += effect.interval
				if actor.invincible_remaining <= 0: actor.hp = maxf(0,actor.hp - effect.dot)
	return actor.hp > 0 and not actor.effects.any(func(e): return e.kind in [17,18,22])

func roll(chance: float) -> bool:
	return rng.next_int(10000) < clampf(chance,0,10000)
