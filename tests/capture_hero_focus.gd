extends SceneTree

const OUTPUT := "res://.impeccable/review/hero_focus/"
const MOTION := "res://validation/hero_focus_motion/"
var failures: Array[String] = []
var app
var town
var camera
var focus


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(MOTION + "frames")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	town = app.get_node("Town")
	camera = town.camera
	focus = app.get_node("Interface/HeroFocus")
	camera.set_process(false)
	focus.set_process(false)
	var op = app._operations
	var nav: TownNavigation = op._simulation.navigation
	var hud = app.get_node("Interface/MainHUD")
	var page = hud.get_node("Stage/HeroDetail")
	var town_follow_error := 0.0
	var town_travel := 0.0
	for id: String in ["hero.1", "hero.2", "hero.3"]:
		var walking_hero: Dictionary = op._state.heroes.filter(func(h): return h.id == id)[0]
		op._simulation.movement.travel(walking_hero, nav.field_center, "field")
		town.render_actors(op.snapshot())
		camera.go_to(town._heroes[id].position, 1.0)
		await process_frame
		click(town._heroes[id].get_global_transform_with_canvas() * Vector2(0, -40))
		check(op.snapshot().selected_hero == id, "native click selects " + id)
		var town_origin: Vector2 = camera.position
		for frame in 30:
			op.advance(1.0 / 30.0)
			town.render_actors(op.snapshot())
			focus._process(1.0 / 30.0)
			town_follow_error = maxf(town_follow_error, camera.position.distance_to(town._heroes[id].position + TownCamera.HERO_OFFSET))
			await process_frame
		var traveled: float = camera.position.distance_to(town_origin)
		town_travel += traveled
		check(traveled > 1, "selected town hero and camera continue moving " + id)
		focus._process(0.3)
		await capture("town_" + id.replace(".", "_") + ".png")
		click(focus.get_node("Detail").get_global_transform_with_canvas().origin)
		check(page.visible and page.hero_id == id and page.tab == 0, "native details opens corresponding hero " + id)
		check(page.get_node("Name").text == walking_hero.name, "native details displays corresponding name " + id)
		check(not camera.is_processing_unhandled_input() and op.snapshot().selected_hero.is_empty(), "details isolates map input")
		await capture("detail_" + id.replace(".", "_") + ".png")
		if id == "hero.1":
			for size: Vector2i in [Vector2i(360, 640), Vector2i(750, 1624)]:
				root.size = size
				await process_frame
				await process_frame
				check(page.get_node("Bottom/Back").get_global_rect().end.y <= hud.get_viewport_rect().size.y, "detail return fits viewport")
				await capture("detail_%dx%d.png" % [size.x, size.y])
			root.size = Vector2i(750, 1334)
			await process_frame
			await process_frame
		click(page.get_node("Bottom/Back").get_global_rect().get_center())
		check(not page.visible and hud.route.is_empty() and camera.is_processing_unhandled_input(), "native details returns to map")
		camera._process(0.5)
		focus._process(0.3)
	check(town_follow_error < 0.01, "town camera follows every interpolated walking frame")
	var hero: Dictionary = op._state.heroes[0]
	for i in 2400:
		op.advance(0.05)
		if nav.zone(hero.position) == "field" and hero.mode == "walking" and hero.path.size() > 3:
			break
	town.render_actors(op.snapshot())
	camera.go_to(hero.position, 1.0)
	await process_frame
	click(town._heroes[hero.id].get_global_transform_with_canvas() * Vector2(0, -40))
	check(op.snapshot().selected_hero == hero.id, "native click selects walking field hero")
	var origin: Vector2 = camera.position
	var max_error := 0.0
	for frame in 180:
		op.advance(1.0 / 30.0)
		town.render_actors(op.snapshot())
		focus._process(1.0 / 30.0)
		max_error = maxf(max_error, camera.position.distance_to(town._heroes[hero.id].position + Vector2(0, -45)))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(MOTION + "frames/%03d.png" % frame)
		if frame in [30, 90, 179]:
			await capture("field_%03d.png" % frame)
	check(max_error < 0.01, "every rendered frame follows the interpolated hero position")
	check(camera.position.distance_to(origin) > 30, "camera visibly travels with hero")
	click(focus.get_node("Detail").get_global_transform_with_canvas().origin)
	check(page.visible and page.hero_id == hero.id, "field hero details uses corresponding hero")
	var field_before_details: Vector2 = hero.position
	op.advance(1.0)
	check(hero.position.distance_to(field_before_details) > 0 or hero.animation == "attack", "hero continues walking or fighting behind details")
	hud.render(op.snapshot())
	await capture("field_detail.png")
	click(page.get_node("Bottom/Back").get_global_rect().get_center())
	check(not page.visible and camera.is_processing_unhandled_input(), "field detail returns to map")
	town.render_actors(op.snapshot())
	app.select_hero(hero.id)
	focus._process(0.3)
	for size: Vector2i in [Vector2i(360, 640), Vector2i(750, 1624), Vector2i(825, 1462)]:
		root.size = size
		await process_frame
		await process_frame
		town.render_actors(op.snapshot())
		focus._process(0.3)
		await capture("selected_%dx%d.png" % [size.x, size.y])
	root.size = Vector2i(750, 1334)
	await process_frame
	await process_frame
	click(Vector2(80, 180))
	check(op.snapshot().selected_hero.is_empty(), "native blank click cancels")
	for frame in 18:
		camera._process(1.0 / 30.0)
		focus._process(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(MOTION + "frames/%03d.png" % (frame + 180))
	check(is_equal_approx(camera.zoom.x, 1.0), "native zoom restored")
	await capture("cancelled.png")
	hud.render(op.snapshot())
	hud.navigate("heroes", false)
	app.select_hero("hero.2")
	focus._process(0.3)
	await process_frame
	click(focus.get_node("Detail").get_global_transform_with_canvas().origin)
	check(page.visible and page.hero_id == "hero.2" and hud.route == "heroes", "drawer map focus opens corresponding hero")
	await capture("drawer_detail.png")
	click(page.get_node("Bottom/Back").get_global_rect().get_center())
	check(not page.visible and hud.get_node("Stage/HeroRoster").visible and camera.is_processing_unhandled_input(), "detail returns to existing hero drawer")
	hud.close()
	print("HERO_FOCUS_NATIVE ", JSON.stringify({"frames":198,"town_follow_error":town_follow_error,"town_travel_distance":town_travel,"follow_error":max_error,"travel_distance":camera.position.distance_to(origin),"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + filename) == OK, "capture " + filename)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
