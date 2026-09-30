extends "res://tests/capture_buildings.gd"
var op: TownOperations
var page

func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	DirAccess.make_dir_recursive_absolute("res://validation/regions/")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.set_process(false)
	op = app._operations
	page = app.get_node("Interface/RegionUI")
	ui = page
	var town = app.get_node("Town")
	var gate: Dictionary = page.gates.field
	town.camera.go_to(Vector2(gate.gate_x,gate.gate_y-240),0.9)
	await settle()
	town.render_actors(op.snapshot())
	await capture("gate_forest")
	var point := Vector2(gate.gate_x+gate.click_x,gate.gate_y+gate.click_y)
	await click(town.get_global_transform_with_canvas()*point)
	check(page.visible and page.area=="field","source gate hit opens region popup")
	for viewport in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = viewport
		await settle()
		await capture("forest_lv1_%d_%d" % [viewport.x,viewport.y])
		check(page.get_node("Stage/Rows").get_child(2).get_node("Locked").visible,"third forest row locked at initial progress")
	root.size = Vector2i(750,1334)
	await settle()
	var rows = page.get_node("Stage/Rows")
	await click(rows.get_child(1).get_node("Activate").get_global_rect().get_center())
	check(not page.visible and op.snapshot().regions.field.level==2,"native activate commits selected density and dismisses popup")
	check(op._state.monsters.size()==8,"activation spawns actual four wolves and four bears")
	app.open_region("field")
	await settle()
	await capture("forest_lv2")
	await click(page.get_node("Stage/Drops/Items").get_child(0).get_global_rect().get_center())
	check(page.get_node("Stage/Dialog").visible,"drop icon opens item information")
	await capture("drop_info")
	await click(page.get_node("Stage/Dialog/Cancel").get_global_rect().get_center())
	await drag(Vector2(600,260),Vector2(140,260))
	check(page.get_node("Stage/Drops").scroll_horizontal > 0 and not page.get_node("Stage/Dialog").visible,"drop shelf drags without triggering item tap")
	await capture("drops_scrolled")
	await click(page.get_node("Stage/Help").get_global_rect().get_center())
	check(page.get_node("Stage/Dialog").visible,"source help is connected")
	await capture("help")
	await click(page.get_node("Stage/Dialog/Cancel").get_global_rect().get_center())
	await click(Vector2(20,1290))
	check(not page.visible,"blank outside dismisses modal")
	op._state.main.progress.dungeon = 30
	op.regions.sync_unlocked()
	for area: String in ["field","field2","field3"]:
		op.regions.activate({"area":area,"level":3})
		app.open_region(area)
		await settle()
		await capture(area+"_lv3")
		check(page.get_node("Stage/Rows").get_child(2).get_node("Monsters").get_child_count()==5,"third row contains two ordinary, two mutant and one leader previews")
		page.close()
		var nav: TownNavigation = op._simulation.navigation
		town.camera.go_to(nav.center(area),0.65)
		town.render_actors(op.snapshot())
		await settle()
		await capture(area+"_monsters")
	# Render each imported species near its authored field center, using actual population transitions.
	for area: String in ["field","field2","field3"]:
		var target: Dictionary = op._state.monsters.filter(func(m):return m.area==area and not m.leader)[0]
		op._state.time = 120
		op.regions.population.cycles[area].created[target.slot_kind] = 4
		target.hp = 0
		# Release an authored leader point in this isolated capture fixture.
		var numbers = op.regions.population.stage_for(area).leader_points.split(";")
		for other: Dictionary in op._state.monsters:
			if other.area == area and other.spawn_id == area+".spawn."+numbers[0]: other.hp = 0
		op.regions.population.respawn(target,op._state)
		town.render_actors(op.snapshot())
		town.camera.go_to(target.position,1.0)
		await settle()
		await capture(area+"_leader")
		check(target.leader,"actual regional leader can be spawned after source conditions")
	print("REGION_NATIVE checks failures=",failures.size())
	for failure in failures: push_error(failure)
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://validation/regions/"+name+".png")
