extends "res://tests/capture_buildings.gd"

func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	DirAccess.make_dir_recursive_absolute("res://validation/battle_horn/")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.set_process(false)
	ui = app.get_node("Interface/BuildingUI")
	var page = ui.get_node("Stage/Horn")
	var op = app._operations
	check(app.town_snapshot()[TownBattleHorn.BUILDING],"horn is built and clickable")
	await open_by_click(TownBattleHorn.BUILDING)
	check(ui.visible and page.visible,"map building opens horn page")
	await capture("level1_gate")
	op._state.buildings[TownBattleHorn.BUILDING] = 2
	op._state.main.progress.dungeon = 21
	op._state.coins = 857000
	op._state.diamonds = 1635
	app.open_building(TownBattleHorn.BUILDING)
	check(page.get_node("Cost").text == "80k", "source level two upgrade price")
	check(page.get_node("Hp").text == "104k", "source giant HP rounds as screenshot")
	await capture("level2")
	await click(page.get_node("Right").get_global_rect().get_center())
	check(page.get_node("Summon").disabled,"higher level previews locked")
	await capture("locked")
	await click(page.get_node("Left").get_global_rect().get_center())
	await click(page.get_node("Help").get_global_rect().get_center())
	check(page.get_node("HelpPanel").visible and not ui.get_node("Stage/Back").visible,"help blocks back clickthrough")
	await capture("help")
	await click(Vector2(375,1200))
	for viewport in [Vector2i(360,640),Vector2i(750,1624)]:
		root.size = viewport
		await settle()
		await capture("small" if viewport.x == 360 else "tall")
	root.size = Vector2i(750,1334)
	await settle()
	await click(page.get_node("Summon").get_global_rect().get_center())
	check(not ui.visible and op.snapshot().horn.phase == "prepare","summon closes page and begins real gathering")
	op.advance(8)
	refresh()
	await capture("gather")
	check(op.snapshot().monsters.is_empty(),"gather has no premature boss")
	op.advance(23)
	refresh()
	await capture("fight")
	check(op.snapshot().monsters[0].get("boss",false),"fight renders actual boss")
	app.open_building(TownBattleHorn.BUILDING)
	await click(page.get_node("Summon").get_global_rect().get_center())
	check(page.get_node("Confirm").visible,"stop requires source confirm")
	await capture("cancel")
	await click(page.get_node("Confirm/Accept").get_global_rect().get_center())
	check(op.snapshot().horn.phase == "idle" and op.snapshot().horn.free == 4,"UI abort refunds daily attempt")
	op.advance(5.1)
	op._state.horn.free = 0
	ui.render(op.snapshot())
	await click(page.get_node("Summon").get_global_rect().get_center())
	check(page.get_node("Confirm").visible,"paid summon opens diamond confirmation")
	await capture("paid")
	await click(page.get_node("Confirm/Cancel").get_global_rect().get_center())
	check(op.snapshot().diamonds == 1635,"cancel confirmation preserves diamonds")
	op._state.horn.free = 4
	op._state.horn.cleared = 2
	ui.render(op.snapshot())
	await click(page.get_node("Five").get_global_rect().get_center())
	check(page.get_node("Five/Check").visible and not page.get_node("Ten/Check").visible,"sweep checkboxes exclusive")
	await click(page.get_node("Ten").get_global_rect().get_center())
	check(page.get_node("Ten/Check").visible and not page.get_node("Five/Check").visible,"ten sweep selection")
	await click(page.get_node("Ten").get_global_rect().get_center())
	await click(page.get_node("Sweep").get_global_rect().get_center())
	check(not ui.visible and op.snapshot().horn.sweep,"sweep runs actual source fast battle")
	op.advance(2)
	refresh()
	check(op.snapshot().horn.result == "won", "sweep victory settles")
	op.advance(5.1)
	op.horn_command({"action":"summon","level":1})
	op.advance(30.1)
	op._state.monsters[0].hp = 0
	op.advance(0.1)
	refresh()
	await capture("chest")
	var coins: int = op.snapshot().coins
	app.get_node("Town/HornWorld").pick(op.horn.encounter.origin)
	check(op.snapshot().horn.chest.is_empty() and op.snapshot().coins == coins + 12800,"map chest click grants source rewards exactly once")
	print("BATTLE_HORN_CAPTURE ", JSON.stringify({"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func refresh() -> void:
	var state: Dictionary = app.operations_snapshot()
	app.get_node("Town").render_actors(state)
	app.get_node("Town/HornWorld").render(state)
	app.get_node("Interface/MainHUD").render(state)

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/battle_horn/"+name+".png")
