extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	# Existing full-roster UI checks run against an explicit acquisition fixture.
	_app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	_hud = _app.get_node("Interface/MainHUD")
	var camera = _app.get_node("Town/Camera")
	var op = _app._operations
	_click(_hud.get_node("Stage/Bottom/Nav2"))
	await _settle()
	var panel = _hud.get_node("Stage/HeroRoster")
	var grid = panel.get_node("Scroll/Grid")
	var dialog = _hud.get_node("Stage/Dialogs")
	var detail = _hud.get_node("Stage/HeroDetail")
	_check(panel.visible and not _hud.get_node("Stage/Panels").visible, "dedicated half-screen hero route")
	_check(grid.get_child_count() == 48 and panel.get_node("Count").text == "英雄：48/48", "map roster count comes from runtime")
	await _capture("hero_drawer_normal")
	var initial: Vector2 = camera.position
	_drag(Vector2(180,260), Vector2(240,290))
	await _settle()
	_check(camera.position != initial, "upper map accepts real drag")
	initial = camera.position
	var wheel := InputEventMouseButton.new()
	wheel.position = root.get_final_transform() * Vector2(660,900)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	wheel = InputEventMouseButton.new()
	wheel.position = root.get_final_transform() * Vector2(660,900)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = false
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _settle()
	_check(camera.position == initial and not dialog.visible and panel.get_node("Scroll").scroll_vertical > 0, "roster wheel scroll neither moves map nor opens details")
	panel.get_node("Scroll").scroll_vertical = 0
	await _settle()
	await _touch_scroll()
	_check(camera.position == initial and not dialog.visible and panel.get_node("Scroll").scroll_vertical > 0, "touch swipe scrolls roster without opening a card or moving the map")
	panel.get_node("Scroll").scroll_vertical = 0
	await _settle()
	var first = grid.get_child(0)
	_click(first.get_node("Locate"))
	await _settle()
	_check(op.snapshot().selected_hero == first.hero_id and panel.visible and not dialog.visible, "location uses map hero without opening details")
	var hero: Dictionary = op.snapshot().heroes.filter(func(h): return h.id == first.hero_id)[0]
	var screen: Vector2 = (hero.position-camera.position)*camera.zoom.x + camera.get_viewport_rect().size*0.5
	_check(screen.y > 84 and screen.y < panel.position.y, "located hero stays above drawer")
	await _capture("hero_drawer_locate")
	_click(first.get_node("Open"))
	await _settle()
	_check(detail.visible and detail.hero_id == first.hero_id, "card opens correct detail")
	var order: Array = detail._order.duplicate()
	_click(detail.get_node("Previous"))
	_check(detail.hero_id == order[0], "first hero previous stays bounded")
	_click(detail.get_node("Next"))
	_check(detail.hero_id == order[1], "next follows visible combat order")
	_click(detail.get_node("Bottom/Back"))
	await _settle()
	_check(panel.visible and panel.get_node("Scroll").scroll_vertical == 0, "detail close returns to drawer")
	_click(panel.get_node("Lineup"))
	await _settle()
	var management = _hud.get_node("Stage/HeroManagement")
	_check(management.visible and management.tab == 0, "lineup opens source formation page")
	var team_size: int = op.snapshot().main.team.size()
	_click(management.get_node("Formation/Slot0"))
	await _settle()
	_check(op.snapshot().main.team.size() == team_size-1, "lineup withdrawal updates domain")
	_click(management.get_node("Bottom/Back"))
	_click(panel.get_node("Dispatch"))
	await _settle()
	var dispatch = _hud.get_node("Stage/MapDispatch")
	_check(dispatch.visible, "source map dispatch opens")
	var dispatched: String = dispatch.assignments.keys()[0]
	_click(dispatch._cards[dispatched].get_node("Card"))
	_click(dispatch.get_node("Panel/town/Move"))
	dispatch.close()
	await _settle()
	_check(op.snapshot().heroes.filter(func(h): return h.id == dispatched)[0].assigned_area == "town", "city dispatch reaches live simulation")
	_click(panel.get_node("Dispatch"))
	await _settle()
	await _capture("hero_drawer_dispatch")
	_click(dispatch._cards[dispatched].get_node("Card"))
	_click(dispatch.get_node("Panel/field/Move"))
	dispatch.close()
	await _settle()
	_check(op.snapshot().heroes.filter(func(h): return h.id == dispatched)[0].assigned_area == "field", "field dispatch reaches live simulation")
	panel.get_node("Scroll").scroll_vertical = 100000
	await _settle()
	var offset: int = panel.get_node("Scroll").scroll_vertical
	var last = grid.get_child(grid.get_child_count()-1)
	_check(last.get_node("Locate").get_global_rect().end.y <= _hud.get_node("Stage/Bottom").get_global_rect().position.y, "last location control scrolls clear of bottom nav")
	_click(last.get_node("Open"))
	await _settle()
	_click(detail.get_node("Next"))
	_check(detail.hero_id == last.hero_id, "last hero next stays bounded")
	_click(detail.get_node("Bottom/Back"))
	_check(panel.get_node("Scroll").scroll_vertical == offset, "detail return preserves scrolled position")
	await _capture("hero_drawer_last")
	panel.get_node("Scroll").scroll_vertical = 0
	for dimensions in [Vector2i(360,640), Vector2i(750,1624)]:
		root.size = dimensions
		await _settle()
		await _capture("hero_drawer_%d_%d" % [dimensions.x,dimensions.y])
		_check(grid.get_child(2).get_global_rect().end.x <= panel.get_global_rect().end.x, "three card columns fit viewport")
	# A newly acquired recruit joins the map and retains its detail/growth path.
	var owned: Array = op.snapshot().main.roster.map(func(h): return h.definition)
	var candidate: String = op.main_definitions().heroes.keys().filter(func(id): return id not in owned)[0]
	op._state.main.pool = [candidate]
	op._state.main.recruited = []
	op._state.inventory["item.10001"] = 1
	_check(op.main_command({"type":"recruit"}).accepted, "real recruitment creates map fixture")
	var recruited_id: String = op.snapshot().main.roster.filter(func(h): return h.definition == candidate)[0].id
	_hud.render(op.snapshot())
	_click(panel.get_node("Lineup"))
	await _settle()
	_click(management.get_node("Bottom/Tab1"))
	await _settle()
	var reserve_rows = management.get_node("TrainingScroll/Rows")
	var reserve_row = reserve_rows.get_children().filter(func(r): return r._hero.id == recruited_id)[0]
	management.get_node("TrainingScroll").scroll_vertical = int(reserve_row.position.y)
	await _settle()
	_click(reserve_row.get_node("Card"))
	await _settle()
	_check(detail.visible and detail.hero_id == recruited_id, "training opens newly recruited map hero")
	_click(detail.get_node("Attributes/Info"))
	await _settle()
	_click(dialog.get_node("Panel/Action"))
	await _settle()
	_check(op.snapshot().main.roster[-1].level == 2, "reserve retains native upgrade path")
	_click(dialog.get_node("Panel/Close"))
	_click(detail.get_node("Bottom/Back"))
	_check(management.visible and management.tab == 1, "reserve detail returns to training")
	_click(management.get_node("Bottom/Back"))
	_check(panel.get_node("Count").text == "英雄：49/49", "new recruitment adds its actual map entity to the roster")
	_click(panel.get_node("Close"))
	await _settle()
	_check(_hud.route.is_empty() and not panel.visible, "raised arrow returns to map")
	if _failures.is_empty(): print("[OK] Hero drawer native input, map focus, lineup, dispatch and three viewport sizes")
	else:
		for message in _failures: push_error(message)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _drag(start: Vector2, end: Vector2) -> void:
	var transform := root.get_final_transform()
	var down := InputEventMouseButton.new()
	down.position = transform * start
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()

	var motion := InputEventMouseMotion.new()
	motion.position = transform * end
	motion.relative = transform * end - transform * start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	down = InputEventMouseButton.new()
	down.position = transform * end
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = false
	Input.parse_input_event(down)
	Input.flush_buffered_events()

func _touch_scroll() -> void:
	Input.emulate_touch_from_mouse = true
	var point := Vector2(350,870)
	var touch := InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * point
	touch.pressed = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	for i in 8:
		await process_frame
		point.y -= 17
		var drag := InputEventScreenDrag.new()
		drag.position = root.get_final_transform() * point
		drag.relative = Vector2(0,-17)
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
	touch = InputEventScreenTouch.new()
	touch.position = root.get_final_transform() * point
	touch.pressed = false
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	for i in 40: await process_frame
	Input.emulate_touch_from_mouse = false
