extends SceneTree

var app
var test := TestSupport.new()
const OUTPUT := "res://validation/loot/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750,1334)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var op = app._operations
	var town = app.get_node("Town")
	var world = town.get_node("LootWorld")
	var hud = app.get_node("Interface/MainHUD")
	# The initial sample comes from actual movement, attacks and the source loot roll.
	for i in 1200:
		op.advance(0.5)
		if not op._state.ground_drops.is_empty(): break
	test.assert_true(not op._state.ground_drops.is_empty(),"native natural kill creates loot")
	if op._state.ground_drops.is_empty(): quit(1); return
	op.advance(0.6)
	refresh()
	var origin: Vector2 = op._state.ground_drops[0].origin
	town.camera.go_to(origin,1.15)
	await capture("natural_kill_750x1334")
	for dimensions: Vector2i in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = dimensions
		hud.close()
		app.select_hero("")
		# Isolated click fixture keeps other drops out of the source hit rectangle.
		op._state.ground_drops.clear()
		op._state.loot_cues.clear()
		op._simulation.combat.loot.spawn({"item.20101":2},origin,false)
		var id: int = op._state.ground_drops[0].id
		var before: int = op._state.inventory["item.20101"]
		town.camera.go_to(origin,0.9)
		refresh()
		await settle()
		var initial: Vector2 = town.get_global_transform_with_canvas() * origin
		click(initial)
		test.assert_equal(op._state.inventory["item.20101"],before,"jump animation cannot be collected early")
		op.advance(0.6)
		refresh()
		await capture("landed_%dx%d" % [dimensions.x,dimensions.y])
		var location: Vector2 = world._drops[id].position
		var point: Vector2 = town.get_global_transform_with_canvas() * location
		mouse(point,true)
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_final_transform() * (point+Vector2(35,0))
		motion.relative = root.get_final_transform().basis_xform(Vector2(35,0))
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		mouse(point+Vector2(35,0),false)
		test.assert_equal(op._state.inventory["item.20101"],before,"drag starting on a drop does not pick it up")
		town.camera.go_to(origin,0.9)
		await settle()
		point = town.get_global_transform_with_canvas() * location
		# A blocking building page must consume the input instead of clicking the map.
		app.open_building("building.7")
		click(point)
		test.assert_equal(op._state.inventory["item.20101"],before,"open building blocks ground pickup")
		app.get_node("Interface/BuildingUI").close()
		town.camera.go_to(origin,0.9)
		await settle()
		point = town.get_global_transform_with_canvas() * location
		click(point)
		test.assert_equal(op._state.inventory["item.20101"],before+2,"actual mouse input grants public inventory")
		click(point)
		test.assert_equal(op._state.inventory["item.20101"],before+2,"double click cannot duplicate reward")
		test.assert_true(not world._drops.has(id),"collected sprite removed in same input response")
		test.assert_true(world.get_node("PickupSound").playing,"source pickup audio plays")
		await capture("pickup_%dx%d" % [dimensions.x,dimensions.y])
		# Revisit an existing building after pickup: inventory is shared with production.
		app.open_building("building.1")
		test.assert_equal(app.operations_snapshot().inventory["item.20101"],before+2,"building uses collected material immediately")
		app.get_node("Interface/BuildingUI").close()
	# Verify material flight and private hero bag, including boss-only item definitions.
	root.size = Vector2i(750,1334)
	var hero: Dictionary = op._state.heroes[0]
	op._simulation.combat.loot.grant_heroes({"item.20101":2,"item.70001":1},[hero],hero.position+Vector2(100,0),1000,50,op)
	op.advance(0.3)
	refresh()
	town.camera.go_to(hero.position,1.2)
	await capture("hero_material_flight")
	hud._detail("hero",{"hero":hero.id,"order":op._state.heroes.map(func(h):return h.id)})
	var detail = hud.get_node("Stage/HeroDetail")
	detail.tab=3
	detail.render(op.snapshot())
	await capture("hero_private_bag")
	# No renderer is responsible for expiry or awarding items.
	op._simulation.combat.loot.spawn({"item.20101":3},origin,false)
	var remaining: int = op._state.ground_drops.size()
	op._state.time += 61
	op._simulation.combat.loot.step()
	refresh()
	test.assert_true(op._state.ground_drops.size()<remaining,"drops expire while a full page covers the map")
	await settle()
	test.assert_equal(world.get_node("Drops").get_child_count(),0,"expired visual nodes cleaned up")
	print("LOOT_NATIVE ",JSON.stringify({"assertions":test.assertions,"failures":test.failures}))
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)

func refresh() -> void:
	var state: Dictionary = app.operations_snapshot()
	app.get_node("Town").render_actors(state)
	app.get_node("Town/HornWorld").render(state)
	app.get_node("Interface/MainHUD").render(state)

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(point: Vector2) -> void:
	mouse(point,true)
	mouse(point,false)

func settle() -> void:
	for frame in 3: await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
