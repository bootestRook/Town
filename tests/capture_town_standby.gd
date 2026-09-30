extends SceneTree

const OUTPUT := "res://validation/standby/"
var app
var test := TestSupport.new()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	# Explicit owned-roster pressure fixture, separate from the three-person new game.
	app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	var op = app._operations
	var town = app.get_node("Town")
	var hud = app.get_node("Interface/MainHUD")
	var hero: Dictionary = op._state.heroes[3]
	op.advance(20)
	_refresh()
	town.camera.go_to(hero.position, 1.4)
	var actor = town._heroes[hero.id]
	_assert_marker(actor, false)
	await capture("standby_map")
	app.select_hero(hero.id)
	var position: Vector2 = hero.position
	op.advance(2)
	_refresh()
	test.assert_true(hero.position != position, "native selected standby continues roaming")
	await capture("standby_focus")
	app.select_hero("")
	hud.navigate("heroes", false)
	await capture("roster_standby")
	hud._detail("hero", {"hero":hero.id})
	await capture("detail_standby")
	var button = hud.get_node("Stage/Dialogs/Panel/Third")
	_click(button.get_global_rect().get_center())
	_refresh()
	test.assert_true(hero.deployed, "actual detail button deploys the map hero")
	_assert_marker(actor, true)
	await capture("detail_deployed")
	_click(button.get_global_rect().get_center())
	_refresh()
	test.assert_true(not hero.deployed, "same detail button withdraws the map hero")
	_assert_marker(actor, false)
	hud.close()
	app.open_building("building.7")
	var shop = app.get_node("Interface/BuildingUI/Stage/Shop")
	shop._switch("heroes")
	_refresh()
	var row = shop.get_node("Heroes/Rows").get_child(3)
	test.assert_true(row.get_node("Summon").disabled, "standby shop summon is disabled")
	await process_frame
	shop.get_node("Heroes").scroll_vertical = roundi(row.position.y)
	await capture("exchange_standby")
	app.get_node("Interface/BuildingUI").hide()
	hud.navigate("heroes", false)
	hud._detail("hero", {"hero":hero.id})
	for size: Vector2i in [Vector2i(360,640), Vector2i(750,1624)]:
		root.size = size
		await capture("detail_%dx%d" % [size.x,size.y])
	root.size = Vector2i(750,1334)
	hud.close()
	var active: Dictionary = op._state.heroes[0]
	active.position = op._simulation.navigation.field_center
	active.previous_position = active.position
	active.mode = "hunting"
	op.main_command({"type":"hero_team", "hero":active.id})
	_refresh()
	town.camera.go_to(active.position,1.4)
	await capture("returning_standby")
	test.assert_equal(active.mode,"standby_return","field withdrawal keeps returning state")
	op.advance(100)
	_refresh()
	test.assert_equal(op._simulation.navigation.zone(active.position),"town","native withdrawn hero returns to town")
	town.camera.go_to(active.position,1.4)
	await capture("returned_standby")
	print("STANDBY_NATIVE ", JSON.stringify({"assertions":test.assertions,"failures":test.failures,"heroes":op._state.heroes.size(),"active":op._state.main.team.size()}))
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)


func _refresh() -> void:
	var state: Dictionary = app._operations.snapshot()
	app.get_node("Town").render_actors(state)
	app.get_node("Interface/MainHUD").render(state)
	app.get_node("Interface/BuildingUI").render(state)


func _assert_marker(actor, deployed: bool) -> void:
	test.assert_equal(actor.get_node("Health").visible,deployed,"health visibility follows deployment")
	test.assert_equal(actor.get_node("Level").visible,deployed,"level badge follows deployment")
	test.assert_equal(actor.get_node("Name").get_theme_color("font_color"),Color8(49,255,131) if deployed else Color8(144,216,242),"name follows source color")


func _click(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func capture(name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
