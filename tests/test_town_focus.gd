extends RefCounted

const Heroes = preload("res://tests/test_town_heroes.gd")


func run(test: TestSupport) -> void:
	var op = Heroes.new().fresh()
	var control = Heroes.new().fresh()
	var hero: Dictionary = op._state.heroes[0]
	for simulation in [op, control]:
		simulation._simulation.movement.travel(simulation._state.heroes[0], simulation._simulation.navigation.field_center, "field")
	var before_selection := hero.duplicate(true)
	var origin: Vector2 = hero.position
	test.assert_true(op.select_hero(hero.id).accepted, "active hero can be selected")
	test.assert_equal(hero, before_selection, "selection leaves movement, animation and behavior state untouched")
	for i in 20:
		op.advance(0.05)
		control.advance(0.05)
	test.assert_true(hero.position.distance_to(origin) > 0, "selected town hero continues walking")
	test.assert_equal(hero, control._state.heroes[0], "town selection never changes the hero simulation")
	test.assert_true(not op.select_hero("missing").accepted, "invalid selection is rejected")
	test.assert_equal(op.snapshot().selected_hero, hero.id, "invalid selection cannot disturb existing focus")
	test.assert_true(not op.select_hero(op._state.monsters[0].id).accepted, "monsters are not selectable heroes")
	op.select_hero("")
	op.advance(0.15)
	control.advance(0.15)
	test.assert_equal(hero, control._state.heroes[0], "cancel selection leaves the ongoing route unchanged")
	for simulation in [op, control]:
		var field_hero: Dictionary = simulation._state.heroes[0]
		field_hero.position = simulation._simulation.navigation.field_center
		field_hero.previous_position = field_hero.position
		field_hero.mode = "hunting"
		field_hero.path.clear()
	op.select_hero(hero.id)
	for i in 60:
		op.advance(0.05)
		control.advance(0.05)
	test.assert_equal(hero.position, control._state.heroes[0].position, "field inspection does not affect simulation position")
	test.assert_equal(hero.needs, control._state.heroes[0].needs, "field inspection does not affect damage or needs")
	hero.needs.hp = 0
	op.advance(0.1)
	test.assert_equal(op.snapshot().selected_hero, "", "death cancels selection")
	test.assert_true(not op.select_hero(hero.id).accepted, "dead hero cannot be selected")
	hero.needs.hp = 100
	hero.mode = "serving"
	test.assert_true(not op.select_hero(hero.id).accepted, "heroes hidden inside buildings cannot be selected")
	hero.mode = "idle"
	op.select_hero(hero.id)
	hero.mode = "serving"
	hero.timer = 10
	op.advance(0.1)
	test.assert_equal(op.snapshot().selected_hero, "", "entering a building cancels focus")


func run_scene(test: TestSupport, app) -> void:
	app.set_process(false)
	var town = app.get_node("Town")
	var camera = town.camera
	camera.set_process(false)
	var op = app._operations
	var hero: Dictionary = op._state.heroes[0]
	town.render_actors(op.snapshot())
	camera.go_to(hero.position, 0.65)
	await app.get_tree().process_frame
	var click: Vector2 = town._heroes[hero.id].get_global_transform_with_canvas() * Vector2(0, -40)
	_click(click)
	test.assert_equal(op.snapshot().selected_hero, hero.id, "real mouse hit selects hero before scenery")
	test.assert_true(is_equal_approx(camera.zoom.x, 1.25), "selection adds source 0.6 zoom")
	test.assert_true(camera.position.is_equal_approx(town._heroes[hero.id].position + Vector2(0, -45)), "camera uses original 45px offset")
	var zoom: float = camera.zoom.x
	app.select_hero("hero.2")
	test.assert_equal(camera.zoom.x, zoom, "switching heroes does not accumulate zoom")
	app.select_hero(hero.id)
	_mouse(Vector2(80, 180), MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(200, 250)
	motion.relative = Vector2(120, 70)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	_mouse(motion.position, MOUSE_BUTTON_LEFT, false)
	test.assert_equal(op.snapshot().selected_hero, hero.id, "dragging the inspection mask is not a blank click")
	_mouse(Vector2(80, 180), MOUSE_BUTTON_WHEEL_UP, true)
	test.assert_equal(camera.zoom.x, zoom, "inspection preserves the source zoom while selected")
	await app.get_tree().process_frame
	var focus = app.get_node("Interface/HeroFocus")
	focus._process(0.3)
	var detail: Vector2 = focus.get_node("Detail").get_global_transform_with_canvas().origin
	_click(detail)
	var hud = app.get_node("Interface/MainHUD")
	var page = hud.get_node("Stage/HeroDetail")
	test.assert_true(page.visible and page.hero_id == hero.id and page.tab == 0, "map details opens selected hero attributes")
	test.assert_equal(page.get_node("Name").text, hero.name, "detail page displays the selected hero")
	test.assert_equal(op.snapshot().selected_hero, "", "full hero page closes map focus")
	test.assert_true(not camera.is_processing_unhandled_input(), "hero details disables map input")
	test.assert_true(not app.get_node("Interface/BuildingUI").visible, "details does not click through to buildings")
	_click(page.get_node("Bottom/Back").get_global_rect().get_center())
	test.assert_true(not page.visible and hud.route.is_empty() and camera.is_processing_unhandled_input(), "detail back restores map input")
	app.select_hero("hero.2")
	focus._process(0.3)
	_click(detail)
	test.assert_true(page.visible and page.hero_id == "hero.2", "switching map focus opens the corresponding hero")
	page.close()
	app.select_hero(hero.id)
	_click(Vector2(80, 180))
	test.assert_equal(op.snapshot().selected_hero, "", "blank click cancels through actual input propagation")
	test.assert_true(not app.get_node("Interface/BuildingUI").visible, "cancel does not click through to buildings")
	camera.set_process(false)
	camera._process(0.25)
	test.assert_true(is_equal_approx(camera.zoom.x, 0.95), "zoom restoration has the source half-second duration")
	camera._process(0.25)
	test.assert_true(is_equal_approx(camera.zoom.x, 0.65), "cancel restores preselection zoom")
	app.select_hero(hero.id)
	app.select_hero("")
	camera._process(0.1)
	app.select_hero(hero.id)
	app.select_hero("")
	camera._process(0.5)
	test.assert_true(is_equal_approx(camera.zoom.x, 0.65), "rapid reopen preserves original zoom without drift")
	camera.go_to(hero.position, 1.4)
	app.select_hero(hero.id)
	test.assert_true(is_equal_approx(camera.zoom.x, 1.6), "selected zoom caps at source maximum")
	_click(town._heroes[hero.id].get_global_transform_with_canvas() * Vector2(0, -40))
	test.assert_equal(op.snapshot().selected_hero, "", "clicking selected hero again closes inspection")
	camera._process(0.5)
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = town._heroes[hero.id].get_global_transform_with_canvas() * Vector2(0, -40)
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
	test.assert_equal(op.snapshot().selected_hero, hero.id, "native touch selects through Godot mouse emulation")
	focus._process(0.3)
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = focus.get_node("Detail").get_global_transform_with_canvas().origin
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
	test.assert_true(page.visible and page.hero_id == hero.id, "native touch opens corresponding hero details")
	page.close()
	focus.detail_requested.emit()
	test.assert_true(not page.visible, "late detail request without selection cannot reopen the page")
	app.select_hero(hero.id)
	app.open_building("building.1")
	test.assert_equal(op.snapshot().selected_hero, "", "opening a building clears map hero focus")
	test.assert_true(not camera.is_processing_unhandled_input(), "building modal disables map selection input")


func _click(point: Vector2) -> void:
	_mouse(point, MOUSE_BUTTON_LEFT, true)
	_mouse(point, MOUSE_BUTTON_LEFT, false)


func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
