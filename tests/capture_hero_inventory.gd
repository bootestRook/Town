extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_app.set_process(false)
	_hud = _app.get_node("Interface/MainHUD")
	var op = _app._operations
	var detail = _hud.get_node("Stage/HeroDetail")
	var equipment = _hud.get_node("Stage/EquipmentDetail")
	var dialog = _hud.get_node("Stage/Dialogs")
	_click(_hud.get_node("Stage/Bottom/Nav2"))
	await _settle()
	var card = _hud.get_node("Stage/HeroRoster/Scroll/Grid").get_child(0)
	var first_frame: int = card.get_node("Open/Portrait").frame
	await _settle()
	_check(card.get_node("Open/Portrait").frame != first_frame, "roster source idle advances")
	await _capture("hero_inventory_roster_motion")
	_click(card.get_node("Open"))
	await _settle()
	var live: Dictionary = op._state.heroes.filter(func(h): return h.id == detail.hero_id)[0]
	var bag = detail.get_node("BagPage")
	var portrait = detail.get_node("PortraitArea/Portrait")
	var sampled: Array = []
	for i in 8:
		sampled.append(portrait.frame)
		await _capture("hero_idle_%02d" % i)
		await _settle()
	_check(sampled[0] != sampled[-1], "full-screen idle continues independently of domain refresh")
	_click(detail.get_node("Bottom/Tab3"))
	await _settle()
	_check(bag.visible and bag.get_node("Scroll/Grid").get_child_count() == 24, "empty backpack fills four rows of six")
	await _capture("hero_inventory_empty")
	var counts := [71,5,46,6,74,8,17,4]
	var ids: Array = op.main_definitions().bag_items.keys().slice(0,8)
	for i in ids.size(): live.bag[ids[i]] = counts[i]
	_check(op.craft("forge.20101",1).accepted, "armor fixture crafted through domain")
	var item: Dictionary = op._state.equipment.back()
	_check(op.main_command({"type":"hero_equip","hero":live.id,"serial":item.serial}).accepted, "armor fixture equipped through domain")
	_hud.render(op.snapshot())
	for dimensions in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		await _settle()
		_hud.render(op.snapshot())
		await _settle()
		await _capture("hero_inventory_bag_%d_%d" % [dimensions.x,dimensions.y])
		_check(bag.get_node("Scroll/Grid").columns == 6, "six columns at every viewport")
		_check(bag.get_global_rect().end.y <= detail.get_node("Bottom").get_global_rect().position.y + 1, "bag clears tabs")
		_click(detail.get_node("Slot2"))
		await _settle()
		_check(equipment.visible, "occupied equipment opens secondary panel")
		await _capture("hero_inventory_equipment_%d_%d" % [dimensions.x,dimensions.y])
		_click(equipment.get_node("Panel/Title"))
		_check(equipment.visible, "inside panel does not close")
		_tap(Vector2(12,100))
		_check(not equipment.visible and detail.tab == 3, "outside dismisses only equipment")
	root.size = Vector2i(750,1334)
	await _settle()
	_click(bag.get_node("Scroll/Grid").get_child(0))
	await _settle()
	_check(dialog.kind == "hero_bag_item" and dialog.get_node("Panel/Text").text == "数量 71", "bag item detail uses private count")
	_check(not dialog.get_node("Panel/Action").visible, "private loot has no public use action")
	_click(dialog.get_node("Panel/Close"))
	var before: Dictionary = op.snapshot()
	_click(detail.get_node("Slot2"))
	_click(equipment.get_node("Panel/Refine"))
	await _settle()
	_check(op.snapshot() == before, "low quality refine makes no mutation")
	_check("品质" in _hud.get_node("Stage/Notice").text, "refine shows source quality gate")
	_click(equipment.get_node("Panel/Buyback"))
	await _settle()
	await _capture("hero_inventory_buyback_confirm")
	_click(equipment.get_node("Confirm/Card/Cancel"))
	_check(op.snapshot() == before and equipment.visible, "cancel buyback preserves equipment")
	op._state.diamonds = 0
	_hud.render(op.snapshot())
	_click(equipment.get_node("Panel/Buyback"))
	_click(equipment.get_node("Confirm/Card/Accept"))
	await _settle()
	_check(live.equipment.has("2") and equipment.visible, "insufficient diamonds preserves equipment and detail")
	op._state.diamonds = 30
	_hud.render(op.snapshot())
	_click(equipment.get_node("Panel/Buyback"))
	_click(equipment.get_node("Confirm/Card/Accept"))
	await _settle()
	_check(not live.equipment.has("2") and op._state.diamonds == 24 and not equipment.visible, "buyback deducts source price, clears slot, closes detail")
	for id: String in op.main_definitions().bag_items: live.bag[id] = 1
	_hud.render(op.snapshot())
	await _settle()
	_check(bag.get_node("Scroll/Grid").get_child_count() == 36, "overfull bag grows to six rows")
	bag.get_node("Scroll").scroll_vertical = 500
	await _settle()
	await _capture("hero_inventory_scrolled")
	_click(detail.get_node("Next"))
	await _settle()
	_check(detail.hero_id != live.id and bag.get_node("Scroll").scroll_vertical == 0, "hero switch resets private bag scroll")
	_check(bag.get_node("Scroll/Grid").get_child(0).disabled, "other hero does not inherit private items")
	_click(detail.get_node("Bottom/Back"))
	_check(not detail.visible and _hud.get_node("Stage/HeroRoster").visible, "return restores roster")
	if _failures.is_empty(): print("[OK] Hero bag, source equipment input and continuous idle at three viewport sizes")
	else:
		for message in _failures: push_error(message)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _tap(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
