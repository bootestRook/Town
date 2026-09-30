extends SceneTree

const OUTPUT := "res://validation/world_navigation/"
var app
var test := TestSupport.new()


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
	var town = app.get_node("Town")
	var op = app._operations
	var nav: TownNavigation = op._simulation.navigation
	app.set_building_appearance("building.1", true)
	town.camera.go_to(Vector2(3960, 2490), 0.65)
	await capture("town_overview")
	for size: Vector2i in [Vector2i(360, 640), Vector2i(750, 1624)]:
		root.size = size
		await capture("town_%dx%d" % [size.x, size.y])
	root.size = Vector2i(750, 1334)
	var snapshot: Dictionary = op.snapshot()
	for hero: Dictionary in snapshot.heroes:
		hero.mode = "serving"
	for monster: Dictionary in snapshot.monsters:
		monster.mode = "dead"
		monster.animation_time = 2.0
	var hero: Dictionary = snapshot.heroes[0]
	hero.mode = "idle"
	hero.animation = "idle"
	hero.direction = Vector2.RIGHT
	town.camera.go_to(Vector2(4256, 2370), 1.5)
	for side: String in ["back", "front"]:
		hero.position = nav.point(Vector2i(77, 43) if side == "back" else Vector2i(68, 34), "town")
		hero.previous_position = hero.position
		town.render_actors(snapshot)
		var actor = town._heroes[hero.id]
		var building: Sprite2D = town._sprites["building.1"]
		var with_hero: Image = await capture("hospital_" + side)
		var overlap: Array[Vector2i] = []
		for x in range(-30, 31, 2):
			for y in range(-85, -4, 2):
				var world: Vector2 = actor.position + Vector2(x, y)
				if actor.body.is_pixel_opaque(actor.body.to_local(world)) and building.is_pixel_opaque(building.to_local(world)):
					overlap.append(Vector2i(actor.get_global_transform_with_canvas() * Vector2(x, y)))
		actor.visible = false
		var without_hero: Image = await capture("hospital_" + side + "_probe")
		var covered := 0
		for p: Vector2i in overlap:
			if with_hero.get_pixelv(p).is_equal_approx(without_hero.get_pixelv(p)):
				covered += 1
		test.assert_true(overlap.size() > 20, "building and hero have enough opaque overlap for layer probe")
		test.assert_true(covered > overlap.size() * 0.9 if side == "back" else covered < overlap.size() * 0.1, "building covers rear hero and front hero covers building")
		print("BUILDING_LAYERS ", JSON.stringify({"side":side,"overlap":overlap.size(),"covered":covered}))
	hero.position = nav.point(Vector2i(68, 42), "town")
	hero.previous_position = hero.position
	hero.path = nav.route(hero.position, nav.point(Vector2i(77, 34), "town"))
	for frame in 240:
		hero.previous_position = hero.position
		op._simulation.movement.step(hero, [], 1.0 / 30.0, hero.base.city_speed)
		hero.animation_time += 1.0 / 30.0
		snapshot.frame_remainder = 0.05
		town.render_actors(snapshot)
		if frame % 40 == 0 or frame == 239:
			await capture("hospital_walk_%03d" % frame)
	test.assert_true(hero.path.is_empty(), "native walking route completes around hospital")
	app.set_building_appearance("building.1", false)
	await capture("hospital_before_building")
	app.set_building_appearance("building.1", true)
	# Native field snapshot includes exactly the original six, with no heroes disturbing patrol.
	town.render_actors(op.snapshot())
	town.camera.go_to(Vector2(4510, 3370), 0.67)
	await capture("field_initial")
	for frame in 400:
		op._state.time += 0.05
		op._simulation.combat.step(op._state, 0.05, op)
	town.render_actors(op.snapshot())
	await capture("field_patrol")
	print("WORLD_NATIVE ", JSON.stringify({"assertions":test.assertions,"failures":test.failures}))
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)


func capture(name: String) -> Image:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png(OUTPUT + name + ".png")
	return shot
