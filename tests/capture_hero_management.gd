extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_app.set_process(false)
	# Explicitly populated fixture exercises long lists; production starts with three.
	_app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	_hud = _app.get_node("Interface/MainHUD")
	var op = _app._operations
	_hud.render(op.snapshot())
	var page = _hud.get_node("Stage/HeroManagement")
	var detail = _hud.get_node("Stage/HeroDetail")
	var dialog = _hud.get_node("Stage/Dialogs")
	_click(_hud.get_node("Stage/Bottom/Nav2"))
	await _settle()
	_click(_hud.get_node("Stage/HeroRoster/Scroll/Grid").get_child(0).get_node("Open"))
	await _settle()
	_click(detail.get_node("Change"))
	await _settle()
	_check(page.visible and page.tab == 0 and not detail.visible and not dialog.visible, "change hero navigates to full formation page")
	_check(page.get_node("Filters/Filter0/Text").text == "ALL", "all element filter keeps source label")
	for dimensions in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		await _settle()
		for tab in 3:
			_click(page.get_node("Bottom/Tab%d" % tab))
			await _settle()
			await _capture("hero_management_%d_%d_%d" % [tab,dimensions.x,dimensions.y])
			_check(page.tab == tab, "bottom tabs work at all three sizes")
			var scroll = page.get_node(["FormationScroll", "TrainingScroll", "CatalogScroll"][tab])
			_check(scroll.get_global_rect().end.y <= page.get_node("Bottom").get_global_rect().position.y, "scroll content clears bottom navigation")
	root.size = Vector2i(750,1334)
	await _settle()
	var touch_team: Array = op.snapshot().main.team.duplicate()
	for tab in 3:
		_click(page.get_node("Bottom/Tab%d" % tab))
		await _settle()
		var scroll = page.get_node(["FormationScroll", "TrainingScroll", "CatalogScroll"][tab])
		var target = scroll.get_node("Rows").get_child(0).get_node("Skill0") if tab == 1 else scroll.get_node("Grid").get_child(0)
		await _touch_scroll(target.get_global_rect().get_center())
		_check(scroll.scroll_vertical > 0 and not dialog.visible and not detail.visible, "touch drag on cards or skill scrolls without opening details")
		_check(op.snapshot().main.team == touch_team, "touch drag never toggles deployment")
		scroll.scroll_vertical = 0
		await _settle()
	var total: int = page.get_node("CatalogScroll/Grid").get_child_count()
	_click(page.get_node("CatalogFilters/Category1"))
	await _settle()
	_check(page.get_node("CatalogScroll/Grid").get_child_count() < total, "normal pool uses actual recruit level quality weights")
	for category in [2,3]:
		_click(page.get_node("CatalogFilters/Category%d" % category))
		await _settle()
		_check(page.get_node("Empty").visible and page.get_node("CatalogScroll/Grid").get_child_count() == 0, "missing category membership displays empty state")
	_click(page.get_node("CatalogFilters/Category0"))
	await _settle()
	var before: Array = op.snapshot().main.roster.duplicate(true)
	_click(page.get_node("CatalogScroll/Grid").get_child(0))
	await _settle()
	_check(dialog.kind == "catalog_hero", "catalog opens readonly source preview")
	_click(dialog.get_node("Panel/Scroll/Rows").get_child(0))
	await _settle()
	_check(dialog.kind == "catalog_hero" and _hud.get_node("Stage/SkillTooltip").visible, "catalog skill uses tooltip without changing page")
	_click(dialog.get_node("Panel/Close"))
	_check(op.snapshot().main.roster == before, "catalog interaction cannot mutate owned heroes")
	_click(page.get_node("Bottom/Tab1"))
	await _settle()
	var row = page.get_node("TrainingScroll/Rows").get_child(0)
	var hero: Dictionary = row._hero.duplicate(true)
	_click(row.get_node("Upgrade"))
	await _settle()
	_check(dialog.kind == "hero_fragment", "missing fragments opens acquisition detail")
	_click(dialog.get_node("Panel/Close"))
	op._state.main.fragments[hero.definition] = hero.fragment_cost
	_hud.render(op.snapshot())
	_click(page.get_node("TrainingScroll/Rows").get_child(0).get_node("Upgrade"))
	await _settle()
	_check(op.snapshot().main.roster.filter(func(h): return h.id == hero.id)[0].star > hero.star, "training row promotion updates actual hero")
	page.get_node("TrainingScroll").scroll_vertical = 150
	await _settle()
	_click(page.get_node("TrainingScroll/Rows").get_child(1).get_node("Card"))
	await _settle()
	_check(detail.visible and not page.visible, "training card opens animated hero detail")
	var saved_team: Array = op._state.main.expedition_team.duplicate()
	op._state.main.expedition_team = [detail.hero_id]
	op._state.main.battle = {"status":"running"}
	_hud._state = op.snapshot()
	_click(detail.get_node("Change"))
	_check(detail.visible and not page.visible, "source change entry blocks current expedition hero")
	op._state.main.expedition_team = saved_team
	op._state.main.battle.clear()
	_hud._state = op.snapshot()
	var frame: int = detail.get_node("PortraitArea/Portrait").frame
	for i in 15: await process_frame
	_check(detail.get_node("PortraitArea/Portrait").frame != frame, "detail retains source idle animation")
	_click(detail.get_node("Bottom/Back"))
	await _settle()
	_check(page.visible and page.tab == 1 and page.get_node("TrainingScroll").scroll_vertical == 150, "detail back preserves training tab and scroll")
	_click(page.get_node("Bottom/Tab0"))
	_click(page.get_node("Filters/Filter1"))
	_click(page.get_node("Filters/Quick"))
	await _settle()
	_check(op.snapshot().main.team.size() == 7, "quick button fills seven camp positions")
	_check(op.snapshot().main.roster.filter(func(h): return h.deployed).all(func(h): return h.combat.element == 1), "quick button respects selected element")
	_hud._notice_time = 0.0
	_hud.get_node("Stage/Notice").hide()
	await _capture("hero_management_deployed")
	var portrait = page.get_node("Formation/Slot0/Portrait")
	frame = portrait.frame
	for i in 15: await process_frame
	_check(portrait.frame != frame, "formation pedestal hero animates")
	var first: String = op.snapshot().main.team[0]
	_click(page.get_node("Formation/Slot0"))
	await _settle()
	_check(first not in op.snapshot().main.team, "upper hero click withdraws actual deployment")
	var cards = page.get_node("FormationScroll/Grid")
	var withdrawn_card = cards.get_children().filter(func(card): return card.hero_id == first)[0]
	_click(withdrawn_card)
	await _settle()
	_check(first in op.snapshot().main.team and withdrawn_card.get_node("Check").visible, "withdrawn card immediately redeploys and shows selected state")
	_check(not _hud.get_node("Stage/Notice").visible, "immediate redeployment shows no cooldown notice")
	_click(withdrawn_card)
	_click(page.get_node("Filters/Quick"))
	await _settle()
	_check(first in op.snapshot().main.team and op.snapshot().main.team.size() == 7, "quick deploy immediately refills with withdrawn hero")
	_check(not _hud.get_node("Stage/Notice").visible, "quick deployment has no cooldown notice")
	await _capture("hero_management_immediate_redeploy")
	_click(page.get_node("Bottom/Back"))
	await _settle()
	_check(not page.visible and _hud.get_node("Stage/HeroRoster").visible, "management closes to original hero drawer")
	_hud.navigate("recruit", false)
	_click(_hud.get_node("Stage/Recruitment/Body/Illustration"))
	await _settle()
	_check(page.visible and page.tab == 2, "recruit illustration shares new catalog page")
	if _failures.is_empty(): print("[OK] Hero management native navigation, three sizes, formation, training, catalog and idle motion")
	else:
		for message in _failures: push_error(message)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _touch_scroll(point: Vector2) -> void:
	Input.emulate_touch_from_mouse = true
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
