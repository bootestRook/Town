extends SceneTree

var app
var failures: Array[String] = []
const OUTPUT := "res://validation/heroes/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var town = app.get_node("Town")
	var op = app._operations
	town.camera.go_to(op._simulation.navigation.town_center + Vector2(0, -100), 1.15)
	await capture("01_named_heroes")
	for hero: Dictionary in op._state.heroes:
		var actor = town._heroes[hero.id]
		check(actor.get_node("Name").text == hero.name, "hero world name is bound")
		check(actor.get_node("Level/Value").text == "1", "hero world level is bound")
		check(actor.get_node("Health").value == hero.needs.hp, "hero world health is bound")
		check(actor.get_node("Body").flip_h == (hero.direction.x > 0), "source sprite faces left before mirroring")
	for id: String in op.services():
		op.produce(id, op.services()[id].material)
	op.set_order("item.20101", 100)
	op.advance(12)
	town.camera.go_to(op._simulation.navigation.field_center, 0.9)
	await capture("02_wilderness")
	for i in 400:
		op.advance(0.05)
		if not op._state.effects.is_empty():
			break
	await capture("03_combat")
	check(not op._state.effects.is_empty(), "native capture observes real attack event")
	for monster: Dictionary in op._state.monsters:
		var actor = town._heroes[monster.id]
		check(actor.get_node("Name").text == monster.name, "monster world name is bound")
		check(not actor.get_node("Level").visible, "monster has no level badge")
		check(absf(actor.get_node("Health").value - monster.hp / monster.base.max_hp * 100) < 0.01, "monster bar reflects damage")
	root.size = Vector2i(360, 640)
	await capture("08_world_small")
	root.size = Vector2i(750, 1624)
	await capture("09_world_tall")
	root.size = Vector2i(750, 1334)
	op.advance(70)
	app.open_building("building.7")
	var shop = app.get_node("Interface/BuildingUI/Stage/Shop")
	shop._switch("heroes")
	await capture("04_hero_status")
	check(shop.get_node("Heroes/Rows").get_child(0).get_node("Name").text == "艾比", "named roster appears in existing exchange page")
	app.get_node("Interface/BuildingUI").close()
	var hero: Dictionary = op._state.heroes[0]
	TownCombat.kill_hero(hero, op)
	for i in 1000:
		op.advance(0.05)
		if hero.mode == "reviving":
			break
	check(hero.mode == "reviving", "hero actually reaches altar")
	var sprite: Sprite2D = town._sprites["building.11"]
	var point := sprite.global_position
	for y in range(-50, 60, 5):
		if sprite.is_pixel_opaque(Vector2(0, y)):
			point += Vector2(0, y)
			break
	town.camera.go_to(point, 1.0)
	await sync()
	await click(Vector2(375, 667))
	check(app.get_node("Interface/BuildingUI").building == "building.11", "native map click opens revival altar")
	await capture("05_revival")
	root.size = Vector2i(360, 640)
	await capture("06_small_portrait")
	root.size = Vector2i(750, 1624)
	await capture("07_tall_portrait")
	print("HERO_CAPTURE ", JSON.stringify({"failures":failures,"counts":op._state.counts}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func sync() -> void:
	var state: Dictionary = app.operations_snapshot()
	app.get_node("Town").render_actors(state)
	app.get_node("Interface/BuildingUI").render(state)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func capture(name: String) -> void:
	await sync()
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")


func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await sync()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
