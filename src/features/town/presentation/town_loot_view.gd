class_name TownLootView
extends Node2D

signal pickup_requested(id: int)
const DROP = preload("res://scenes/town/ground_drop.tscn")
const TIP = preload("res://scenes/town/loot_tip.tscn")
const CLICK_RECT := Rect2(-72, -62, 144, 124)
var _items: Dictionary = {}
var _catalog
var _drops: Dictionary = {}
var _cues: Dictionary = {}
var _clickable: Dictionary = {}


func configure(data, catalog) -> void:
	_catalog = catalog
	for row: Dictionary in data.rows("town_loot_items"): _items[row.id] = row
	$PickupSound.stream = catalog.load_resource("loot.pickup")


static func scatter(index: int, radius: float = 70.0) -> Vector2:
	# CptDropItem: a repeating nine-direction jump, inverted Cocos Y axis.
	var angle := deg_to_rad(40.0 * (index % 9 + 1))
	return Vector2(sin(angle), -cos(angle)) * radius


func render(state: Dictionary) -> void:
	var now: float = state.time + state.frame_remainder
	_prune(_drops, state.ground_drops.map(func(d): return d.id))
	_prune(_cues, state.loot_cues.map(func(c): return c.id))
	_clickable.clear()
	for drop: Dictionary in state.ground_drops:
		var age := maxf(0.0, now - float(drop.born))
		if not _drops.has(drop.id):
			var node = _make_item(drop.item)
			node.get_node("Glow").texture = _catalog.load_resource("loot.glow_%d" % clampi(int(_items[drop.item].quality), 1, 5))
			$Drops.add_child(node)
			_drops[drop.id] = node
		var node: Node2D = _drops[drop.id]
		var phase := clampf(age / 0.5, 0.0, 1.0)
		node.position = drop.origin + scatter(drop.id) * phase - Vector2(0, 4.0 * 50.0 * phase * (1.0 - phase))
		node.get_node("Glow").visible = age >= 0.5
		if age >= 0.5 and age < drop.lifetime: _clickable[drop.id] = node.position
	var heroes := {}
	for hero: Dictionary in state.heroes: heroes[hero.id] = hero.position
	for event: Dictionary in state.loot_cues:
		_render_cue(event, now - event.born, heroes)


func pick(point: Vector2) -> bool:
	var selected := -1
	var distance := INF
	for id: int in _clickable:
		var offset: Vector2 = point - _clickable[id]
		if CLICK_RECT.has_point(offset) and offset.length_squared() < distance:
			selected = id
			distance = offset.length_squared()
	if selected < 0: return false
	pickup_requested.emit(selected)
	return true


func _make_item(item: String):
	var node = DROP.instantiate()
	var texture: Texture2D = _catalog.load_resource(_items[item].resource_id)
	node.get_node("Icon").texture = texture
	# Source prefab uses a 100x100 icon and a 0.35 scale.
	node.get_node("Icon").scale = Vector2(35.0 / texture.get_width(), 35.0 / texture.get_height())
	node.get_node("Glow").hide()
	return node


func _render_cue(event: Dictionary, age: float, heroes: Dictionary) -> void:
	if not _cues.has(event.id):
		var node = _make_item(event.item) if event.kind == "hero_item" else TIP.instantiate()
		$Cues.add_child(node)
		_cues[event.id] = node
		if event.kind == "pickup":
			node.get_node("Text").text = "%s ×%d" % [_items[event.item].display_name, event.count]
			$PickupSound.play()
		elif event.kind == "earnings":
			node.get_node("Text").text = "+%d金币\n+%d经验" % [event.coins, event.experience]
			node.get_node("Text").modulate = Color(1, 0.9, 0.45)
	var node: Node2D = _cues[event.id]
	if event.kind == "hero_item":
		var landed: Vector2 = event.origin + scatter(event.id, 50)
		var phase := clampf(age / 0.3, 0.0, 1.0)
		node.position = event.origin + scatter(event.id, 50) * phase - Vector2(0, 240 * phase * (1 - phase))
		if age >= 0.8:
			var destination: Vector2 = heroes.get(event.hero, landed) - Vector2(0, 30)
			var duration := maxf(0.05, minf(0.5, landed.distance_to(destination) / 500.0))
			node.position = landed.lerp(destination, clampf((age - 0.8) / duration, 0, 1))
			node.visible = age < 0.8 + duration
	else:
		var start: float = 0.0 if event.kind == "pickup" else 0.8
		var elapsed := maxf(0.0, age - start)
		node.visible = age >= start and elapsed < (1.0 if event.kind == "pickup" else 0.5)
		var origin: Vector2 = event.origin + scatter(event.scatter) if event.kind == "pickup" else heroes.get(event.hero, event.origin)
		node.position = origin - Vector2(0, 50 + 60 * elapsed)
		node.scale = Vector2.ONE * lerpf(1.5, 1.0, clampf(elapsed / 0.5, 0, 1))
		if event.kind == "earnings":
			node.position = origin - Vector2(0, 75)
			node.scale = Vector2.ONE


func _prune(cache: Dictionary, present: Array) -> void:
	for id: int in cache.keys():
		if id not in present:
			cache[id].queue_free()
			cache.erase(id)
