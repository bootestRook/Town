extends "res://tests/capture_hero_management.gd"

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
	var definitions: Dictionary = op.main_definitions()
	var detail = _hud.get_node("Stage/HeroDetail")
	var tooltip = _hud.get_node("Stage/SkillTooltip")
	var dialog = _hud.get_node("Stage/Dialogs")
	var management = _hud.get_node("Stage/HeroManagement")
	var sophia := _fixture("索非亚", 5)
	var logan := _fixture("洛根", 3)
	var order: Array = [sophia, logan]
	for dimensions in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		_hud._detail("hero", {"hero":sophia, "order":order})
		await _settle()
		_click(detail.get_node("AttributePage/Skill0"))
		await _settle()
		_check(tooltip.visible and not dialog.visible, "skill opens inline without modal")
		_check(tooltip.get_node("Title").text == "流火重斩" and tooltip.get_node("Type").text == "CD:11S", "source skill title and cooldown")
		_check(tooltip.get_node("Text").text.contains("[color=#34CD3F]400%[/color]"), "level two skill highlights 400 percent")
		_bounds(tooltip)
		_check(tooltip.get_global_rect().end.y < detail.get_node("AttributePage/Skill0").get_global_rect().position.y, "tooltip clears its skill row")
		await _capture("hero_skill_active_%d_%d" % [dimensions.x,dimensions.y])
		_click(tooltip.get_node("Title")); _check(tooltip.visible, "inside click keeps description")
		_click(detail.get_node("AttributePage/Skill0")); _check(not tooltip.visible, "repeat click closes description")
		_click(detail.get_node("AttributePage/Skill1")); _check(tooltip.visible, "different skill opens directly")
		_click(detail.get_node("Next"))
		await _settle()
		_check(detail.hero_id == logan and not tooltip.visible, "adjacent hero closes stale description")
		var locked = detail.get_node("AttributePage/Skill3")
		_check(locked.get_node("Lock").visible and not locked.disabled and locked.get_node("Level").text == "0", "locked skill retains level zero, lock icon and input")
		await _capture("hero_skill_locks_%d_%d" % [dimensions.x,dimensions.y])
		_click(locked)
		await _settle()
		_check(tooltip.visible and tooltip.get_node("Icon/Lock").visible and tooltip.get_node("Type").text == "buff", "locked skill opens full description")
		_check(tooltip.get_node("Unlock").text == "（4星解锁）" and not tooltip.get_node("Text").text.contains("#34CD3F"), "unlock condition comes from source talent and no false highlight")
		_bounds(tooltip)
		await _capture("hero_skill_locked_tip_%d_%d" % [dimensions.x,dimensions.y])
		_escape()
		_check(not tooltip.visible and detail.visible, "Escape dismisses only tooltip")
		# Stress real longest source descriptions against the same anchored control.
		var longest: Array = definitions.skill_art.keys()
		longest.sort_custom(func(a,b): return String(definitions.skills[a].description).length() > String(definitions.skills[b].description).length())
		tooltip.toggle({"skill":longest[0],"level":1,"name":"索菲亚","talent":detail._hero.talent}, locked)
		await _settle()
		_bounds(tooltip)
		await _capture("hero_skill_long_%d_%d" % [dimensions.x,dimensions.y])
		_click(detail.get_node("PortraitArea/Portrait"))
		_check(not tooltip.visible, "outside click dismisses without navigating")
	root.size = Vector2i(750,1334)
	await _settle()
	_click(detail.get_node("Status1")); _click(detail.get_node("AttributePage/Skill0"))
	_check(tooltip.visible and not detail.get_node("Tooltip").visible, "skill dismisses status tooltip")
	_escape(); _click(detail.get_node("AttributePage/Skill0")); _click(detail.get_node("Bottom/Tab3"))
	await _settle()
	_check(not tooltip.visible and detail.tab == 3, "switching detail tab clears description")
	_click(detail.get_node("Bottom/Tab0")); _click(detail.get_node("AttributePage/Skill0"))
	var frame: int = detail.get_node("PortraitArea/Portrait").frame
	for i in 15: await process_frame
	_check(frame != detail.get_node("PortraitArea/Portrait").frame, "hero continues idle animation behind tooltip")
	_escape(); _click(detail.get_node("Change")); _click(management.get_node("Bottom/Tab1"))
	await _settle()
	var row = management.get_node("TrainingScroll/Rows").get_child(0)
	_click(row.get_node("Skill0"))
	await _settle()
	_check(tooltip.visible and not dialog.visible, "training shares inline skill preview")
	_bounds(tooltip)
	await _capture("hero_skill_training")
	management.get_node("TrainingScroll").scroll_vertical = 90
	await _settle()
	_check(not tooltip.visible, "scrolling anchor closes description")
	management.get_node("TrainingScroll").scroll_vertical = 0
	await _settle()
	await _touch_scroll(row.get_node("Skill0").get_global_rect().get_center())
	_check(not tooltip.visible and management.get_node("TrainingScroll").scroll_vertical > 0, "dragging skill scrolls without accidental opening")
	_click(management.get_node("Bottom/Tab2"))
	await _settle()
	_click(management.get_node("CatalogScroll/Grid").get_child(0))
	await _settle()
	var context: Dictionary = dialog.view_context()
	_click(dialog.get_node("Panel/Scroll/Rows").get_child(0))
	await _settle()
	_check(tooltip.visible and dialog.view_context() == context, "catalog skill does not push a secondary page")
	_bounds(tooltip)
	_escape()
	_check(dialog.visible and dialog.kind == "catalog_hero", "catalog stays open when tooltip closes")
	_click(dialog.get_node("Panel/Close"))
	if _failures.is_empty(): print("[OK] Inline hero skills, level highlights, locked previews, all entrances, three sizes, native mouse/touch, dismissal and idle animation")
	else:
		for message in _failures: push_error(message)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _fixture(hero_name: String, star: int) -> String:
	var op = _app._operations
	var definitions: Dictionary = op.main_definitions()
	var source: Dictionary = definitions.heroes.values().filter(func(h): return h.display_name == hero_name)[0]
	if not op._state.main.roster.any(func(h): return h.definition == source.id):
		op._state.main.pool = [source.id]
		op._state.main.recruited.clear()
		op._state.inventory["item.10001"] = 1
		_check(op.main_command({"type":"recruit"}).accepted, "recruit screenshot hero using source definition")
	var entry: Dictionary = op._state.main.roster.filter(func(h): return definitions.heroes[h.definition].display_name == hero_name)[0]
	var definition: Dictionary = definitions.heroes[entry.definition]
	var talent: Dictionary = definitions.hero_talents.values().filter(func(t): return t.appearance == definition.appearance and t.star == star)[0]
	entry.talent = talent.source_id
	entry.star = talent.star
	entry.level = 100
	_hud.render(op.snapshot())
	return entry.id

func _bounds(tooltip: Control) -> void:
	var rect := tooltip.get_global_rect()
	var viewport := root.get_visible_rect()
	_check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= viewport.end.x and rect.end.y <= viewport.end.y, "tooltip stays inside logical viewport")
	_check(tooltip.get_node("Text").get_content_height() <= tooltip.get_node("Text").size.y, "entire source description is visible")

func _escape() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
