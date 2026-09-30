extends SceneTree

const OUTPUT := "res://validation/navigation_motion/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT + "frames")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var op = app._operations
	var town = app.get_node("Town")
	var nav: TownNavigation = op._simulation.navigation
	for i in 3:
		var hero: Dictionary = op._state.heroes[i]
		hero.position = nav.doors[["building.1", "building.6", "building.7"][i]]
		hero.previous_position = hero.position
		op._simulation.movement.travel(hero, nav.field_center, "field")
	var maximum_step := 0.0
	var prior: Vector2 = op._state.heroes[0].position
	var valid := true
	for frame in 150:
		op.advance(1.0 / 30.0)
		var snapshot: Dictionary = op.snapshot()
		town.render_actors(snapshot)
		var actor = town._heroes["hero.1"]
		maximum_step = maxf(maximum_step, actor.position.distance_to(prior))
		prior = actor.position
		valid = valid and nav.passable(snapshot.heroes[0].position)
		town.camera.go_to(actor.position + Vector2(0, -140), 1.2)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png(OUTPUT + "frames/%03d.png" % frame)
		if frame in [0, 60, 149]:
			shot.save_png(OUTPUT + "%03d_walk.png" % frame)
	print("NAVIGATION_MOTION ", JSON.stringify({"frames":150,"valid_cells":valid,"maximum_visual_step":maximum_step,"no_visual_teleport":maximum_step <= 4.7}))
	app.queue_free()
	await process_frame
	quit(0 if valid and maximum_step <= 4.7 else 1)
