class_name TownAttackSequence
extends RefCounted

var definitions: Dictionary = {}
var effects: Dictionary = {}


func configure(data) -> void:
	for row: Dictionary in data.rows("town_attacks"):
		definitions[row.id] = row
	for row: Dictionary in data.rows("town_effects"):
		effects[row.id] = row


func begin(actor: Dictionary, target: Dictionary) -> void:
	if actor.has("needs") and not TownHeroNeeds.attack(actor): return
	var definition: Dictionary = definitions[actor.visual]
	actor.attack_state = {"target": target.id, "elapsed": 0.0, "released": false}
	actor.attack_serial += 1
	actor.cooldown = maxf(definition.cooldown, definition.duration + definition.recovery)
	actor.animation = "attack"
	actor.animation_time = 0.0
	actor.path.clear()
	TownHeroStats.face(actor, target.position - actor.position)


func advance(actor: Dictionary, state: Dictionary, dt: float, combat, owner) -> bool:
	if actor.attack_state.is_empty():
		return false
	var definition: Dictionary = definitions[actor.visual]
	var attack: Dictionary = actor.attack_state
	attack.elapsed += dt
	if not attack.released and attack.elapsed + 0.00001 >= definition.windup:
		attack.released = true
		var target := find_actor(state, attack.target)
		if alive(target):
			TownHeroStats.face(actor, target.position - actor.position)
			if definition.projectile.is_empty():
				impact(actor, target, state, combat, owner, definition.impact, attack_damage(actor, target, combat))
			else:
				state.projectiles.append({"source": actor.id, "target": target.id, "position": point(actor, "emit"), "speed": definition.fly_speed, "resource": definition.projectile, "impact": definition.impact, "damage": attack_damage(actor, target, combat)})
	if attack.elapsed + 0.00001 >= definition.duration:
		actor.attack_state = {}
		TownHeroStats.animate(actor, "idle")
	return true


func advance_projectiles(state: Dictionary, dt: float, combat, owner) -> void:
	for effect: Dictionary in state.effects:
		effect.elapsed += dt
	state.effects = state.effects.filter(func(e): return e.elapsed < effects[e.resource].seconds)
	var remaining: Array = []
	for projectile: Dictionary in state.projectiles:
		var target := find_actor(state, projectile.target)
		if not alive(target):
			continue
		var destination := point(target, "hit")
		var distance: float = projectile.position.distance_to(destination)
		projectile.angle = (destination - projectile.position).angle()
		if distance <= projectile.speed * dt:
			impact(find_actor(state, projectile.source), target, state, combat, owner, projectile.impact, projectile.damage)
		else:
			projectile.position = projectile.position.move_toward(destination, projectile.speed * dt)
			remaining.append(projectile)
	state.projectiles = remaining


func impact(source: Dictionary, target: Dictionary, state: Dictionary, combat, owner, resource: String, amount: float) -> void:
	var anchor: Dictionary = source if effects[resource].anchor == 1 else target
	state.effects.append({"position": anchor.position if effects[resource].anchor == 1 else point(anchor, "hit"), "resource": resource, "elapsed": 0.0, "flip": anchor.direction.x > 0})
	if target.has("needs"):
		TownHeroNeeds.injured(target)
		target.needs.hp = maxf(0.0, target.needs.hp - amount / target.stats.max_hp * 100.0)
		if target.needs.hp <= 0:
			combat.kill_hero(target, owner)
	else:
		if not target.get("boss", false) and source.has("needs") and target.hp > 0:
			target.contributors.erase(source.id)
			target.contributors.append(source.id)
		target.hp = maxf(0.0, target.hp - amount)
		if target.hp <= 0:
			combat.defeat(target, source, owner)


func point(actor: Dictionary, kind: String) -> Vector2:
	var definition: Dictionary = definitions[actor.visual]
	var offset := Vector2(definition[kind + "_x"], definition[kind + "_y"])
	if actor.direction.x > 0:
		offset.x = -offset.x
	return actor.position + offset


static func attack_damage(source: Dictionary, target: Dictionary, combat) -> float:
	var attack: float = source.stats.attack if source.has("needs") else source.base.attack
	if source.has("needs"): attack *= TownHeroNeeds.attack_multiplier(source)
	var defense: float = target.stats.defense if target.has("needs") else target.base.defense
	return combat.damage(attack, defense)


static func find_actor(state: Dictionary, id: String) -> Dictionary:
	for actor: Dictionary in state.heroes + state.monsters:
		if actor.id == id:
			return actor
	return {}


static func alive(actor: Dictionary) -> bool:
	return not actor.is_empty() and (actor.needs.hp > 0 if actor.has("needs") else actor.hp > 0)
