extends "res://tests/capture_buildings.gd"


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute("res://validation/life_ui/")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.set_process(false)
	ui = app.get_node("Interface/BuildingUI")
	var page = ui.get_node("Stage/Life")
	for number in [1,2,3,4]:
		var id := "building.%d" % number
		await open_by_click(id)
		check(ui.visible and ui.building == id, "map opens life page " + id)
		var recipe: Dictionary = app.operations_snapshot().services[id]
		app._operations._state.inventory[recipe.product] = 0
		ui.render(app.operations_snapshot())
		check(page.get_node("Empty").visible and not page.get_node("Product").visible, "sold out hides product " + id)
		await click(page.get_node("Product").get_global_rect().get_center())
		check(not page.get_node("ProductTip").visible, "sold out cannot open stale product tooltip")
		var count: int = app.operations_snapshot().inventory[recipe.material]
		await drag(page.get_node("Material").get_global_rect().get_center(), Vector2(60,720))
		check(app.operations_snapshot().inventory[recipe.material] == count, "outside drop preserves stock " + id)
		await drag(page.get_node("Material").get_global_rect().get_center(), page.get_node("WorkArea").get_global_rect().get_center())
		check(app.operations_snapshot().inventory[recipe.material] == 0, "drag produces " + id)
		check(page.get_node("ProductTip").visible, "production shows source tooltip " + id)
		check(not page.get_node("Empty").visible, "production restores stocked shelf")
		check(page.get_node("AcquireHint").visible, "missing material shows acquire hint")
		await drag(page.get_node("Material").get_global_rect().get_center(), page.get_node("WorkArea").get_global_rect().get_center())
		check(not page._held and not page.get_node("Ghost").visible, "missing material never starts drag")
		await click(Vector2(60, 720))
		check(not page.get_node("ProductTip").visible, "outside click closes tooltip")
		await click(page.get_node("Product").get_global_rect().get_center())
		check(page.get_node("ProductTip").visible, "product click restores tooltip")
		var before: int = app.operations_snapshot().buildings[id]
		await click(page.get_node("Upgrade").get_global_rect().get_center())
		check(app.operations_snapshot().buildings[id] == before + 1, "upgrade changes domain level " + id)
		await click(page.get_node("BuySeat").get_global_rect().get_center())
		check(page.get_node("SeatPanel").visible, "plus opens seat panel " + id)
		await click(Vector2(375,1100))
		check(not page.get_node("SeatPanel").visible, "blank area closes seat panel")
		await click(page.get_node("Help").get_global_rect().get_center())
		check(page.get_node("HelpPanel").visible and page.get_node("HelpPanel/Title").text == recipe.display_name + "说明", "source building help opens")
		check(page.get_node("HelpPanel/Description").text == recipe.help_description, "source building purpose shown")
		if number == 1:
			await capture("help")
		await click(Vector2(375,1100))
		await click(page.get_node("AcquireHint").get_global_rect().get_center())
		check(page.get_node("AcquirePanel").visible, "acquisition panel opens")
		if number == 1:
			await capture("acquire")
		await click(page.get_node("AcquirePanel/Way0").get_global_rect().get_center())
		check(ui.building == "building.7" and ui.get_node("Stage/Modal").visible and ui._selection.id == recipe.material, "exchange route selects requested material")
		await click(ui.get_node("Stage/Modal/Ten").get_global_rect().get_center())
		await click(ui.get_node("Stage/Modal/Confirm").get_global_rect().get_center())
		check(app.operations_snapshot().orders[recipe.material] == 10, "acquisition route submits actual preorder")
		await click(ui.get_node("Stage/Back").get_global_rect().get_center())
		check(not ui.visible, "return restores map")
	# Reference save values are only fixtures; production starts from the existing demo state.
	var fixtures := [[30,191000,268,106],[30,193000,203,25],[28,189000,152,55],[29,191000,84,1]]
	for number in [1,2,3,4]:
		var id := "building.%d" % number
		var fixture: Array = fixtures[number-1]
		var state: Dictionary = app._operations._state
		var recipe: Dictionary = app.operations_snapshot().services[id]
		state.buildings[id] = fixture[0]
		state.coins = fixture[1]
		state.inventory[recipe.product] = fixture[2]
		state.inventory[recipe.material] = fixture[3]
		for hero: Dictionary in state.heroes:
			hero.mode = "hunting"
		if number <= 2:
			var hero: Dictionary = state.heroes[number - 1]
			hero.mode = "serving"
			hero.target = id
			hero.timer = 6.0 if number == 1 else 10.0
			hero.service_total = 10.0
		app.open_building(id)
		await settle()
		await capture("reference_%d" % number)
	app.open_building("building.3")
	await click(page.get_node("BuySeat").get_global_rect().get_center())
	await capture("seat_before")
	await click(page.get_node("SeatPanel/Row2/Buy").get_global_rect().get_center())
	check(app.operations_snapshot().diamonds == 355, "UI seat purchase spends source 800 diamonds")
	check(app.operations_snapshot().details["building.3"].capacity == 2, "UI purchase creates usable second seat")
	await capture("seat_after")
	await click(Vector2(375,1100))
	var hero: Dictionary = app._operations._state.heroes[0]
	hero.target = "building.3"
	hero.mode = "waiting"
	app._operations.begin_service(hero, "building.3")
	ui.render(app.operations_snapshot())
	await click(ui.get_node("Stage/Report").get_global_rect().get_center())
	check(page.get_node("ReportPanel").visible, "report opens")
	check("毛毯" in page.get_node("ReportPanel/Scroll/Text").text, "report displays actual sale")
	await capture("report")
	await click(Vector2(375,1200))
	var recipe: Dictionary = app.operations_snapshot().services["building.3"]
	app._operations._state.inventory[recipe.product] = 0
	app._operations._state.inventory[recipe.material] = 0
	ui.render(app.operations_snapshot())
	check(page.get_node("Empty").visible and not page.get_node("ProductTip").visible, "last product sale removes stale tip")
	await capture("empty")
	await click(page.get_node("AcquireHint").get_global_rect().get_center())
	await click(page.get_node("AcquirePanel/Way1").get_global_rect().get_center())
	check(not ui.visible, "monster drop route returns to active map")
	app.open_building("building.4")
	root.size = Vector2i(360,640)
	await settle()
	await capture("small")
	root.size = Vector2i(750,1624)
	await settle()
	await capture("tall")
	print("LIFE_UI_RESULT ", JSON.stringify({"failures": failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/life_ui/" + name + ".png")
