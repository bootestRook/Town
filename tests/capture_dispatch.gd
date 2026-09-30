extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_hud = _app.get_node("Interface/MainHUD")
	var op = _app._operations
	_click(_hud.get_node("Stage/Bottom/Nav2"))
	await _settle()
	_click(_hud.get_node("Stage/HeroRoster/Dispatch"))
	await _settle()
	var page = _hud.get_node("Stage/MapDispatch")
	_check(page.visible and page._cards.size() == 3, "dispatch opens real default three heroes")
	_check(page.get_node("Panel/field2/Locked").visible, "graveyard locked below dungeon gate")
	await _capture("dispatch_default")
	_click(page.get_node("Panel/Allfield2"))
	_check(not page.get_node("Popup").visible and page.assignments.values().all(func(a): return a == "field"), "locked bulk destination cannot alter draft")
	_tap_blank(page)
	_check(not page.visible,"outside click closes panel")
	# Seven acquired heroes are an explicit visual fixture, not a new-game roster.
	_app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115,7)
	op = _app._operations
	op._state.main.progress.dungeon = 18
	op._state.main.team = op._state.main.roster.map(func(h): return h.id)
	op._simulation.sync_deployment(op._state)
	var assignments := {}
	for id: String in op._state.main.team: assignments[id] = "field3"
	_check(op.main_command({"type":"hero_dispatch","assignments":assignments,"confirmed":assignments}).accepted,"unlocked confirmed seven hero fixture")
	_hud.render(op.snapshot())
	_hud._detail("dispatch", {})
	await _settle()
	await _capture("dispatch_seven")
	var id: String = page.assignments.keys()[0]
	_click(page._cards[id].get_node("Card"))
	await _settle()
	_check(page.selected == [id] and page.get_node("Panel/town/Move").visible, "real card input selects and shows target buttons")
	await _capture("dispatch_selected")
	_click(page.get_node("Panel/town/Move"))
	_check(page.assignments[id] == "town" and op.snapshot().main.roster.filter(func(h): return h.id==id)[0].assigned_area == "field3", "moving card only updates draft before close")
	_click(page._cards[id].get_node("Card"))
	_click(page.get_node("Panel/field2/Move"))
	await _settle()
	_check(page.get_node("Popup").visible, "low power prompts confirmation")
	await _capture("dispatch_low_power")
	_click(page.get_node("Popup/Box/Cancel"))
	_check(page.assignments[id] == "town", "cancel keeps weak hero in source area")
	_click(page._cards[id].get_node("Card"))
	_click(page.get_node("Panel/field2/Move"))
	_click(page.get_node("Popup/Box/Accept"))
	_check(page.assignments[id] == "field2", "confirm permits low-power dispatch")
	_tap_blank(page)
	_check(not page.visible and _hud.get_node("Stage/HeroRoster").visible, "close commits and returns to drawer")
	_check(op.snapshot().main.roster.filter(func(h): return h.id==id)[0].assigned_area == "field2", "close committed exact destination")
	_hud._detail("dispatch", {})
	_click(page.get_node("Panel/Help"))
	await _settle()
	await _capture("dispatch_help")
	_tap_blank(page)
	_check(not page.get_node("Popup").visible,"outside click closes help before viewport checks")
	for dimensions in [Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		await _settle()
		await _capture("dispatch_%d_%d" % [dimensions.x,dimensions.y])
		_check(page.get_node("DismissHint").get_global_rect().end.y <= _hud.get_node("Stage").get_global_rect().end.y,"dismiss hint fits viewport")
	root.size = Vector2i(750,1334)
	_app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115,15)
	op = _app._operations
	op._state.main.team = op._state.main.roster.map(func(h): return h.id)
	op._simulation.sync_deployment(op._state)
	_hud.render(op.snapshot())
	_hud._detail("dispatch", {})
	await _settle()
	var scroll = page.get_node("Panel/field/Scroll")
	var camera: Vector2 = _app.get_node("Town/Camera").position
	await _touch_list(scroll)
	_check(scroll.scroll_vertical > 0 and page.selected.is_empty(), "touch drag scrolls crowded region without selecting a hero")
	_check(_app.get_node("Town/Camera").position == camera,"dispatch scrolling never drags world")
	_click(page.get_node("Panel/Alltown"))
	_check(page.assignments.values().all(func(a): return a=="town"), "top button dispatches every active hero")
	await _settle()
	var ids: Array = page.get_node("Panel/town/Scroll/Grid").get_children().slice(0,2).map(func(c): return c.hero_id)
	_click(page._cards[ids[0]].get_node("Card"))
	_click(page._cards[ids[1]].get_node("Card"))
	_check(page.selected.size()==2, "same-area multiple selection")
	_click(page.get_node("Panel/field/Move"))
	_check(page.assignments[ids[0]]=="field" and page.assignments[ids[1]]=="field", "selected group moves together")
	op._state.main.progress.dungeon = 18
	_hud.render(op.snapshot())
	_click(page.get_node("Panel/Allfield3"))
	await _settle()
	await _capture("dispatch_many_low_power")
	_check(page.get_node("Popup/Box/Scroll/Text").size.x <= page.get_node("Popup/Box/Scroll").size.x,"long confirmation respects text inset")
	if _failures.is_empty(): print("[OK] Dispatch native input, draft/confirmation/close and 8 captures")
	else:
		for failure in _failures: push_error(failure)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _touch_list(scroll: Control) -> void:
	Input.emulate_touch_from_mouse = true
	var point: Vector2 = scroll.get_global_rect().get_center()
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

func _tap_blank(page: Control) -> void:
	var point: Vector2 = root.get_final_transform() * page.get_node("DismissHint").get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
