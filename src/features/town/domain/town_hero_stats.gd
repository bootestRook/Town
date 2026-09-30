class_name TownHeroStats
extends RefCounted


static func refresh(hero: Dictionary) -> void:
	hero.stats = {"max_hp": float(hero.base.max_hp), "attack": float(hero.base.attack), "defense": float(hero.base.defense)}
	for key: String in hero.collection_bonus: hero.stats[key] += hero.collection_bonus[key]
	for item: Dictionary in hero.equipment.values():
		match int(item.attribute):
			1: hero.stats.max_hp += float(item.power)
			5: hero.stats.attack += float(item.power)
			7: hero.stats.defense += float(item.power)
	TownEquipmentRules.apply_stats(hero.stats, hero.equipment)


static func create(row: Dictionary, index: int, position: Vector2, items: Dictionary) -> Dictionary:
	var bag := {}
	for id: String in items:
		if items[id].order_limit > 0:
			bag[id] = 0
	var hero := {"id": row.id, "name": row.display_name, "visual": row.visual, "job": int(row.job), "index": index, "wallet": int(row.wallet), "base": row.duplicate(true), "needs": {"hp": float(row.hp), "energy": 100.0, "tired": 100.0, "mood": 100.0}, "bag": bag, "mode": "idle", "position": position, "path": [], "timer": float(row.start_delay), "service_total": 12.0, "target": "", "summoned": false, "requested": "", "reason": "准备出城", "recovery": 0.0, "equipment": {}, "retired": [], "cooldown": 0.0, "enemy": "", "direction": Vector2.RIGHT, "animation": "idle", "animation_time": 0.0, "queued_at": 0.0, "wait_time": 0.0, "trip_kills": 0, "kills": 0, "deaths": 0, "revivals": 0, "skip_shopping": 0.0, "returning": false, "history": []}
	hero.level = int(row.level)
	hero["experience"] = 0
	hero.needs["magic"] = 0
	hero.deployed = true
	hero.assigned_area = "field"
	hero.collection_bonus = {}
	hero.attack_state = {}
	hero.attack_serial = 0
	hero.previous_position = position
	refresh(hero)
	return hero


static func animate(actor: Dictionary, action: String) -> void:
	if actor.animation != action:
		actor.animation = action
		actor.animation_time = 0.0


static func face(actor: Dictionary, delta: Vector2) -> void:
	# Source lookAtVec2 keeps the previous axis when movement is horizontal/vertical.
	if absf(delta.x) > 0.00001:
		actor.direction.x = signf(delta.x)
	if absf(delta.y) > 0.00001:
		actor.direction.y = signf(delta.y)


static func record(hero: Dictionary, text: String) -> void:
	hero.history.push_front(text)
	if hero.history.size() > 24:
		hero.history.pop_back()
