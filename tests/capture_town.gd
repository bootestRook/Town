extends SceneTree

var _failures: Array[String] = []
var _app
var _town
var _camera


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_town = _app.get_node("Town")
	_camera = _town.camera
	_app.set_building_appearance("building.1", false)
	_check(_app.is_ready_for_use(), "app boot")
	await _capture("01_town")
	# Real input dispatch through Godot's input and UI propagation.
	var start := Vector2(360, 660)
	var old_position: Vector2 = _camera.position
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(140, 80)
	motion.relative = Vector2(140, 80)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	_mouse(motion.position, MOUSE_BUTTON_LEFT, false)
	await _settle()
	_check(_camera.position.distance_to(old_position) > 100, "drag changes camera position")
	_check(not _app.town_snapshot()["building.1"], "drag cannot change building state")
	var point := Vector2(300, 550)
	var anchor: Vector2 = _camera.screen_to_world(point)
	var old_zoom: float = _camera.zoom.x
	_mouse(point, MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(point, MOUSE_BUTTON_WHEEL_UP, false)
	await _settle()
	_check(_camera.zoom.x > old_zoom, "wheel input zooms")
	_check(_camera.screen_to_world(point).distance_to(anchor) < 0.01, "wheel retains cursor anchor")
	# Construction appearance is tested through the domain API, with no demo HUD.
	_camera.go_to(Vector2(4256, 2430), 1.0)
	await _settle()
	await _capture("02_before")
	_app.set_building_appearance("building.1", true)
	await _settle()
	_check(_app.town_snapshot()["building.1"], "domain API changes construction state")
	await _capture("03_after")
	for pair in [[Vector2(4840, 3420), "04_east"], [Vector2(2080, 3490), "05_southwest"], [Vector2(1810, 2000), "06_northwest"]]:
		_camera.go_to(pair[0])
		await _settle()
		await _capture(pair[1])
	_camera.go_to(Vector2(-10000, 10000), 0.001)
	await _settle()
	var half_view: Vector2 = root.get_visible_rect().size / _camera.zoom.x / 2.0
	_check(_camera.position.x >= half_view.x - 0.1, "left bound clamps")
	_check(_camera.position.y <= _camera.WORLD_SIZE.y - half_view.y + 0.1, "bottom bound clamps")
	_check(_camera.zoom.x >= _camera.minimum_zoom(), "zoom minimum fills viewport")
	_camera.zoom_at(100, Vector2(375, 667))
	_check(_camera.zoom.x <= _camera.MAX_ZOOM, "zoom maximum clamps")
	_camera.go_to(Vector2(3650, 2385), 0.65)
	root.size = Vector2i(360, 640)
	await _settle()
	await _capture("07_small_portrait")
	root.size = Vector2i(750, 1624)
	await _settle()
	_check(is_equal_approx(_camera.zoom.x, 0.65), "resize preserves camera magnification")
	await _capture("08_tall_portrait")
	if _failures.is_empty():
		print("[OK] native town input, construction state, bounds and portrait captures")
	else:
		for failure in _failures:
			push_error(failure)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)


func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _settle() -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://validation/town_stage1/" + name + ".png")
	_check(result == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
