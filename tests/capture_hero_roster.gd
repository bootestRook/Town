extends SceneTree

const OUTPUT := "res://validation/hero_roster/"
const ACTOR = preload("res://scenes/town/actor.tscn")
var app


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
	# Preserve the explicit 48-appearance gallery fixture, separate from new-game ownership.
	app._operations = preload("res://tests/test_town_heroes.gd").new().fresh(47115, 48)
	var op = app._operations
	var town = app.get_node("Town")
	var nav: TownNavigation = op._simulation.navigation
	town.camera.go_to(nav.town_center, 0.85)
	town.render_actors(op.snapshot())
	await capture("town_start")
	var total_start := Time.get_ticks_usec()
	op.advance(60)
	var simulation_ms := (Time.get_ticks_usec() - total_start) / 1000.0
	town.camera.go_to(nav.field_center, 0.85)
	var times: Array[float] = []
	for frame in 240:
		var start := Time.get_ticks_usec()
		app._process(1.0 / 60.0)
		times.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
	await capture("field_64_seconds")
	for size: Vector2i in [Vector2i(360, 640), Vector2i(750, 1624)]:
		root.size = size
		await capture("field_%dx%d" % [size.x, size.y])
	root.size = Vector2i(750, 1334)
	app.get_node("Interface/MainHUD").navigate("heroes", false)
	await capture("roster_page")
	var roster: Array = op.snapshot().main.roster
	var definitions := {}
	for hero: Dictionary in roster:
		definitions[hero.id] = hero
	var data := DataRegistry.new()
	data.load_default()
	var appearances := {}
	var animations := {}
	for row: Dictionary in data.rows("town_appearances"):
		appearances[row.id] = row
	for row: Dictionary in data.rows("town_animations"):
		animations[row.id] = row
	var catalog := ResourceCatalog.new()
	catalog.load_default()
	var heroes: Array = op.snapshot().heroes
	heroes.sort_custom(func(a, b):
		var left: int = definitions[a.id].quality * 1000000 + a.job * 100000 + a.base.source_appearance
		var right: int = definitions[b.id].quality * 1000000 + b.job * 100000 + b.base.source_appearance
		return left < right)
	app.get_node("Interface").hide()
	town.hide()
	town.camera.enabled = false
	RenderingServer.set_default_clear_color(Color("315653"))
	for page in 6:
		var gallery := Node2D.new()
		root.add_child(gallery)
		for slot in 8:
			var hero: Dictionary = heroes[page * 8 + slot]
			var origin := Vector2((slot % 2) * 375, (slot / 2) * 315)
			var portrait := Sprite2D.new()
			portrait.texture = catalog.load_resource(definitions[hero.id].portrait)
			portrait.scale = Vector2.ONE * 90.0 / portrait.texture.get_width()
			portrait.position = origin + Vector2(65, 150)
			gallery.add_child(portrait)
			for direction in ["front", "back"]:
				var actor = ACTOR.instantiate()
				gallery.add_child(actor)
				actor.configure(hero, appearances[hero.visual])
				hero.position = origin + Vector2(175 if direction == "front" else 290, 225)
				hero.previous_position = hero.position
				hero.animation = "idle"
				hero.mode = "idle"
				hero.needs.hp = 100
				hero.animation_time = 0
				hero.direction = Vector2.LEFT
				var animation: Dictionary = animations["%s_%s_idle" % [hero.visual, direction]]
				actor.render(hero, animation, catalog.load_resource(animation.resource_id), 0)
				actor.get_node("Name").visible = direction == "front"
		await capture("gallery_%02d" % (page + 1))
		gallery.queue_free()
		await process_frame
	times.sort()
	print("ROSTER_NATIVE ", JSON.stringify({"heroes": heroes.size(), "simulation_60s_ms": simulation_ms, "process_p50_ms": times[times.size() / 2], "process_p95_ms": times[int(times.size() * 0.95)], "max_process_ms": times.back(), "counts": op._state.counts, "modes": op._state.heroes.map(func(h): return {"name":h.name,"mode":h.mode,"kills":h.kills,"reason":h.reason})}))
	app.queue_free()
	await process_frame
	quit()


func capture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
