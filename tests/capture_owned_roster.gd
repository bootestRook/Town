extends "res://tests/capture_main_ui.gd"

func _run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	_app = load("res://scenes/main.tscn").instantiate()
	root.add_child(_app)
	await _settle()
	_app.set_process(false)
	_hud = _app.get_node("Interface/MainHUD")
	var op = _app._operations
	var town = _app.get_node("Town")
	_check(op.snapshot().heroes.size() == 3, "native new game creates only three heroes")
	_check(town._requested_textures.size() == 50, "startup requests only three owned actors and two monster types")
	for dimensions in [Vector2i(750,1334), Vector2i(360,640), Vector2i(750,1624)]:
		root.size = dimensions
		_hud.navigate("heroes", false)
		await _settle()
		var page = _hud.get_node("Stage/HeroRoster")
		_check(page.get_node("Scroll/Grid").get_child_count() == 3 and page.get_node("Count").text == "英雄：3/3", "native roster shows actual three owned heroes")
		await _capture("initial_%dx%d" % [dimensions.x, dimensions.y])
		_hud.close()
	root.size = Vector2i(750,1334)
	# All candidates use formerly unavailable map appearances; purchase and draw use real inputs.
	var definitions: Dictionary = op.main_definitions().heroes
	op._state.main.pool = definitions.values().filter(func(d): return int(d.appearance) in [12004,22007,32006]).map(func(d): return d.id)
	_check(op._state.main.pool.size() == 3, "three unowned recruit candidates resolve to source definitions")
	op._state.main.recruited.clear()
	_hud.navigate("recruit", false)
	_hud.render(op.snapshot())
	await _settle()
	var page = _hud.get_node("Stage/Recruitment")
	var overlay = _hud.get_node("Stage/RecruitOverlay")
	_click(page.get_node("Body/Recruit"))
	await _settle()
	_check(overlay.kind == "purchase", "no scroll opens existing purchase flow")
	_click(overlay.get_node("Panel/Purchase/Buy"))
	await _settle()
	_check(op.snapshot().inventory["item.10001"] == 1 and not overlay.visible, "purchase grants one scroll and closes")
	_click(page.get_node("Body/Recruit"))
	await _settle()
	_check(op.snapshot().heroes.size() == 4 and op.snapshot().main.team.size() == 3, "real input recruits an actor without auto deployment")
	_outside()
	await _settle()
	await _capture("recruit_success")
	_outside()
	await _settle()
	_click(page.get_node("Back"))
	await _settle()
	var hero: Dictionary = op._state.heroes.back()
	var origin: Vector2 = hero.position
	op.advance(0.1)
	town.render_actors(op.snapshot())
	town.camera.go_to(hero.position + Vector2(0,-90), 1.25)
	var actor = town._heroes[hero.id]
	_check(actor.position.distance_to(origin) > 0.1 and hero.animation == "move", "new recruit visibly walks on its first simulation steps")
	_check(not actor.get_node("Health").visible and not actor.get_node("Level").visible, "new standby hero has no deployed health or level UI")
	_check(actor.get_node("Name").get_theme_color("font_color") == Color8(144,216,242), "standby retains source blue name")
	await _capture("recruited_walking_010")
	op.advance(0.5)
	town.render_actors(op.snapshot())
	await _capture("recruited_walking_060")
	op.main_command({"type":"hero_team","hero":hero.id})
	town.render_actors(op.snapshot())
	_check(actor.get_node("Health").visible and actor.get_node("Level").visible, "recruited actor deploys with active markers")
	await _capture("recruited_deployed")
	op.main_command({"type":"hero_team","hero":hero.id})
	_check(op.main_command({"type":"hero_release","hero":hero.id}).accepted, "dismiss recruited standby")
	town.render_actors(op.snapshot())
	_check(not town._heroes.has(hero.id), "dismissal removes visible map actor")
	await _settle()
	if _failures.is_empty(): print("[OK] OWNED_ROSTER_NATIVE: three starters, three viewport sizes, purchase/recruit, immediate walking, markers, deployment, removal")
	else:
		for failure in _failures: push_error(failure)
	_app.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _outside() -> void:
	var point := root.get_final_transform() * Vector2(root.get_visible_rect().size.x * 0.5, 55)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _capture(name: String) -> void:
	await _settle()
	_check(root.get_texture().get_image().save_png("res://validation/owned_roster/" + name + ".png") == OK, "capture " + name)
