class_name TownView
extends Node2D

signal building_clicked(id: String)
signal hero_trade_requested(id: String, building: String)
signal hero_focus_requested(id: String)

const ACTOR = preload("res://scenes/town/actor.tscn")
const HERO_CLICK_RECT := Rect2(-34, -79, 60, 80)

@onready var camera: TownCamera = $Camera
var _catalog
var _definitions: Dictionary = {}
var _sprites: Dictionary = {}
var _heroes: Dictionary = {}
var _offers: Dictionary = {}
var _trade_textures: Dictionary = {}
var _equipment_buildings: Array = []
var _hero_targets: Dictionary = {}
var _animations: Dictionary = {}
var _animation_textures: Dictionary = {}
var _background_loading := false
var _requested_textures: Dictionary = {}
var _attack_definitions: Dictionary = {}
var _appearances: Dictionary = {}
var _directions: Dictionary = {}
var _variants: Dictionary = {}
var _selectable_heroes: Dictionary = {}
var selected_hero := ""
var _visual_rng = RngSet.new(47115).stream("town.attack_appearance")


func configure(data, catalog) -> void:
	_catalog = catalog
	$RegionWorld.configure(data,catalog,$Objects)
	$CombatEffects.configure(data, catalog)
	$LootWorld.configure(data, catalog)
	for row: Dictionary in data.rows("town_appearances"):
		_appearances[row.id] = row
	for row: Dictionary in data.rows("town_animations"):
		_animations[row.id] = row
	# The headless dummy renderer cannot safely initialize textures concurrently.
	_background_loading = DisplayServer.get_name() != "headless"
	for row: Dictionary in data.rows("town_attacks"):
		_attack_definitions[row.id] = row
	camera.map_clicked.connect(_pick_building)
	for row: Dictionary in data.rows("town_equipment"):
		_trade_textures[row.building] = _catalog.load_resource(row.resource_id)
	for row: Dictionary in data.rows("equipment_shops"):
		_trade_textures[row.id] = _catalog.load_resource(row.arrival_resource)
		_equipment_buildings.append(row.id)
	for row: Dictionary in data.rows("town_backgrounds"):
		var sprite := _sprite(row.resource_id)
		sprite.centered = false
		sprite.position = Vector2(row.x, row.y)
		$Background.add_child(sprite)
	for row: Dictionary in data.rows("town_scenery"):
		var root := Node2D.new()
		root.position = placed_position(row)
		var sprite := _sprite(row.resource_id)
		sprite.position = Vector2(row.offset_x, row.offset_y)
		root.add_child(sprite)
		($Ground if row.layer == "ground" else $Objects).add_child(root)
	for row: Dictionary in data.rows("town_buildings"):
		_definitions[row.id] = row
		var root := Node2D.new()
		root.position = placed_position(row)
		var sprite := Sprite2D.new()
		root.add_child(sprite)
		$Objects.add_child(root)
		_sprites[row.id] = sprite


static func grid_position(x: float, y: float) -> Vector2:
	return Vector2(3610 + (x - y) * 19, 3466 - (x + y + 1) * 9.5)


static func placed_position(definition: Dictionary) -> Vector2:
	# BuildingEditorComponent.setNodePosition shifts from the occupied corner to its art origin.
	return grid_position(definition.grid_x, definition.grid_y) - Vector2(0, (definition.height - 1) * 9.5)


func _exit_tree() -> void:
	# Every threaded request must be collected, including actions never displayed.
	if _background_loading:
		for id: String in _requested_textures:
			if not _animation_textures.has(id):
				ResourceLoader.load_threaded_get(_catalog.path(id))
	_animation_textures.clear()


func render(state: Dictionary) -> void:
	for id: String in _sprites:
		var definition: Dictionary = _definitions[id]
		var built := bool(state[id])
		var sprite: Sprite2D = _sprites[id]
		sprite.texture = _catalog.load_resource(definition.built_resource if built else definition.before_resource)
		sprite.position = Vector2(definition.built_offset_x, definition.built_offset_y) if built else Vector2(definition.before_offset_x, definition.before_offset_y)


func _sprite(id: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _catalog.load_resource(id)
	return sprite


func _pick_building(point: Vector2) -> void:
	if $LootWorld.pick(point): return
	if $HornWorld.pick(point): return
	if $RegionWorld.pick(point): return
	for hero: String in _offers:
		var offer: Sprite2D = _offers[hero]
		if offer.visible and offer.is_pixel_opaque(offer.to_local(point)):
			hero_trade_requested.emit(hero, _hero_targets[hero])
			return
	var selected := ""
	var front_y := -INF
	for id: String in _selectable_heroes:
		var actor: Node2D = _heroes[id]
		if actor.visible and HERO_CLICK_RECT.has_point(actor.to_local(point)) and actor.position.y >= front_y:
			selected = id
			front_y = actor.position.y
	if not selected.is_empty():
		hero_focus_requested.emit("" if selected == selected_hero else selected)
		return
	if not selected_hero.is_empty():
		hero_focus_requested.emit("")
		return
	var candidate := ""
	var bottom := -INF
	for id: String in _sprites:
		var sprite: Sprite2D = _sprites[id]
		if sprite.is_pixel_opaque(sprite.to_local(point)) and sprite.get_parent().position.y > bottom:
			candidate = id
			bottom = sprite.get_parent().position.y
	if not candidate.is_empty():
		building_clicked.emit(candidate)


func render_actors(state: Dictionary) -> void:
	$RegionWorld.render(state)
	$LootWorld.render(state)
	$CombatEffects.render(state.effects, state.projectiles)
	_selectable_heroes.clear()
	var present: Array = (state.heroes + state.monsters).map(func(a): return a.id)
	for id: String in _heroes.keys():
		if id not in present:
			_heroes[id].queue_free()
			_offers[id].queue_free()
			for cache: Dictionary in [_heroes, _offers, _hero_targets, _directions, _variants]: cache.erase(id)
	for hero: Dictionary in state.heroes + state.monsters:
		var human: bool = hero.has("needs")
		if human and TownOperations.can_select_hero(hero):
			_selectable_heroes[hero.id] = true
		if not _heroes.has(hero.id):
			_request_visual(hero.visual)
			var actor = ACTOR.instantiate()
			$Objects.add_child(actor)
			actor.configure(hero, _appearances[hero.visual])
			_heroes[hero.id] = actor
			var offer := Sprite2D.new()
			offer.scale = Vector2.ONE * 0.55
			offer.z_index = 1
			$Objects.add_child(offer)
			_offers[hero.id] = offer
		if not _directions.has(hero.id):
			_directions[hero.id] = "front"
		if absf(hero.direction.y) > 0.00001:
			_directions[hero.id] = "back" if hero.direction.y < 0 else "front"
		var direction: String = _directions[hero.id]
		var action: String = hero.animation
		if action == "attack":
			if not _variants.has(hero.id) or _variants[hero.id].serial != hero.attack_serial:
				var count: int = _attack_definitions[hero.visual].variants
				var variant := roundi(_visual_rng.next_int(1000000) / 999999.0 * (count - 1)) + 1
				_variants[hero.id] = {"serial": hero.attack_serial, "variant": variant}
			if _variants[hero.id].variant > 1:
				action += str(_variants[hero.id].variant)
		var animation: Dictionary = _animations["%s_%s_%s" % [hero.visual, direction, action]]
		if not _animation_textures.has(animation.resource_id):
			_animation_textures[animation.resource_id] = ResourceLoader.load_threaded_get(_catalog.path(animation.resource_id)) if _background_loading else _catalog.load_resource(animation.resource_id)
		_heroes[hero.id].render(hero, animation, _animation_textures[animation.resource_id], state.frame_remainder)
		var offer: Sprite2D = _offers[hero.id]
		offer.visible = human and hero.mode == "await_trade"
		if offer.visible:
			offer.texture = _trade_textures[hero.target]
			offer.scale = Vector2.ONE * (1.0 if hero.target in _equipment_buildings else 0.55)
			offer.position = hero.position + Vector2(0, -194)
			_hero_targets[hero.id] = hero.target
	if state.selected_hero != selected_hero:
		selected_hero = state.selected_hero
		if selected_hero.is_empty():
			camera.end_focus()
		else:
			camera.begin_focus(_heroes[selected_hero].position)
	if not selected_hero.is_empty():
		camera.follow(_heroes[selected_hero].position)


func _request_visual(visual: String) -> void:
	if not _background_loading:
		return
	# Load only owned actors and current monsters, not the entire recruit catalogue.
	for animation: Dictionary in _animations.values():
		if animation.actor == visual and not _requested_textures.has(animation.resource_id):
			_requested_textures[animation.resource_id] = true
			ResourceLoader.load_threaded_request(_catalog.path(animation.resource_id), "Texture2D")
