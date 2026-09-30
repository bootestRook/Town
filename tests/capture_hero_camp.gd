extends "res://tests/capture_buildings.gd"

func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	DirAccess.make_dir_recursive_absolute("res://validation/hero_camp/")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.set_process(false)
	ui = app.get_node("Interface/BuildingUI")
	var page = ui.get_node("Stage/Camp")
	var hud = app.get_node("Interface/MainHUD")
	check(app.town_snapshot()[TownHeroCamp.BUILDING], "camp exists as built map building")
	await open_by_click(TownHeroCamp.BUILDING)
	check(ui.visible and page.visible, "source camp map sprite opens real camp page")
	check(not ui.get_node("Stage/Report").visible, "camp does not inherit unrelated shop report")
	check(page.get_node("Upgrade").disabled, "insufficient coins disable upgrade")
	var level: int = app.operations_snapshot().camp.level
	await click(page.get_node("Upgrade").get_global_rect().get_center())
	check(app.operations_snapshot().camp.level == level, "disabled click cannot upgrade")
	await capture("insufficient")
	await click(page.get_node("Help").get_global_rect().get_center())
	check(page.get_node("HelpPanel").visible and not ui.get_node("Stage/Back").visible, "source help opens without return click-through")
	await capture("help")
	await click(Vector2(375,1150))
	check(not page.get_node("HelpPanel").visible, "help blank closes")
	await click(page.get_node("GoldAdd").get_global_rect().get_center())
	check(not ui.visible and hud.get_node("Stage/Dialogs").visible, "coin plus opens existing resource service")
	await click(hud.get_node("Stage/Dialogs/Panel/Close").get_global_rect().get_center())
	check(ui.visible and page.visible and app._resource_return.is_empty(), "resource popup returns to camp")
	await click(page.get_node("DiamondAdd").get_global_rect().get_center())
	check(not ui.visible and hud.get_node("Stage/DiamondShop").visible, "diamond plus opens existing shop")
	await click(hud.get_node("Stage/DiamondShop/Back").get_global_rect().get_center())
	check(ui.visible and page.visible, "diamond shop returns to camp")
	# Recruit real map actors for a populated acceptance fixture; the new game still owns three.
	var op = app._operations
	var owned: Array = op._state.main.roster.map(func(h): return h.definition)
	var candidates: Array = op.main_definitions().heroes.values().filter(func(d): return d.id not in owned)
	op._state.inventory["item.10001"] = 5
	for definition: Dictionary in candidates.slice(0,5):
		op._state.main.pool = [definition.id]
		op._state.main.recruited.clear()
		check(op.main_command({"type":"recruit"}).accepted, "fixture recruits an actual owned hero")
	app._operations.main_command({"type":"hero_quick_deploy", "element":0})
	app._operations._state.coins = 150000
	app._operations._state.main.progress.clear()
	ui.render(app.operations_snapshot())
	await capture("level5")
	await click(page.get_node("Upgrade").get_global_rect().get_center())
	var state: Dictionary = app.operations_snapshot()
	check(state.camp.level == 6 and state.coins == 0, "upgrade click spends exactly 150000 for level six without unlock conditions")
	check(state.main.deployment_capacity == 8, "capacity is actually eight after UI upgrade")
	check(page.get_node("Title").text == "英雄营地 Lv.6" and "7[/color][color=#c3d2d4]/8" in page.get_node("Capacity").text, "page refreshes actual title and seven of eight occupancy")
	await capture("level6")
	await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	check(not ui.visible, "back returns to map")
	await capture("map")
	hud.render(app.operations_snapshot())
	hud._detail("hero_management", {"page":0})
	await settle()
	var formation = hud.get_node("Stage/HeroManagement")
	check(not formation.get_node("Formation/Slot7/Lock").visible and formation.get_node("Formation/Slot8/Lock").visible, "management slot eight unlocks and ninth stays locked")
	await click(formation.get_node("Filters/Quick").get_global_rect().get_center())
	check(op.snapshot().main.team.size() == 8, "real quick deploy button fills all eight camp positions")
	check(op.snapshot().heroes.filter(func(h): return h.deployed).size() == 8, "all eight deployed positions own real active map actors")
	await capture("formation8")
	hud.close()
	app.open_building(TownHeroCamp.BUILDING)
	for size in [Vector2i(360,640),Vector2i(750,1624)]:
		root.size = size
		await settle()
		await capture("small" if size.x == 360 else "tall")
	root.size = Vector2i(750,1334)
	app._operations._state.coins = 20000000
	while app.operations_snapshot().camp.level < 12:
		app._operations.upgrade(TownHeroCamp.BUILDING)
	ui.render(app.operations_snapshot())
	check(page.get_node("Preview/Row0").visible and not page.get_node("Preview/Row1").visible, "penultimate level has exactly one valid preview")
	await capture("level12")
	await click(page.get_node("Upgrade").get_global_rect().get_center())
	check(app.operations_snapshot().camp.level == 13 and page.get_node("Max").visible, "max level reached through real upgrade button")
	check(not page.get_node("Upgrade").visible and not page.get_node("Preview").visible, "maximum hides nonexistent upgrade and preview")
	await capture("max")
	print("HERO_CAMP_CAPTURE ", JSON.stringify({"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/hero_camp/"+name+".png")
