extends SceneTree

const OUTPUT := "res://validation/building_waiting/"
var app


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	var test := TestSupport.new()
	preload("res://tests/test_town_waiting.gd").new().run(test)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var op = app._operations
	var town = app.get_node("Town")
	op._state.monsters.clear()
	for hero: Dictionary in op._state.heroes:
		hero.needs.hp = 20
		op._simulation.decisions.go(hero, "building.1")
	op.advance(45)
	town.camera.go_to(op._simulation.navigation.doors["building.1"] + Vector2(-80, 0), 1.0)
	await capture("01_three_waiting")
	var positions: Array = op._state.heroes.map(func(h): return {"name": h.name, "position": str(h.position), "mode": h.mode})
	op.produce("building.1", "item.20101")
	op.advance(0.1)
	await capture("02_first_hero_inside")
	print("BUILDING_WAITING ", JSON.stringify({"assertions": test.assertions, "failures": test.failures, "heroes": positions}))
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)


func capture(name: String) -> void:
	var state: Dictionary = app.operations_snapshot()
	app.get_node("Town").render_actors(state)
	app.get_node("Interface/MainHUD").render(state)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
