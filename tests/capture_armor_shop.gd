extends "res://tests/capture_buildings.gd"

var page
var op
var qa = preload("res://tests/test_equipment_shop.gd").new()

func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000,0)
	root.size = Vector2i(750,1334)
	DirAccess.make_dir_recursive_absolute("res://validation/armor_shop/")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.set_process(false)
	op = app._operations
	ui = app.get_node("Interface/BuildingUI")
	page = ui.get_node("Stage/EquipmentShop")
	op._state.buildings["building.9"] = 3
	op._state.city_level = 3
	op._state.coins = 860000
	op._state.diamonds = 1635
	for hero: Dictionary in op._state.heroes:
		for id: String in ["forge.20102","forge.40102"]:
			qa.supply(op,op.equipment_shop.recipes[id]); op.craft(id,1)
			op.main_command({"type":"hero_equip","hero":hero.id,"serial":op._state.equipment.back().serial})
	await open_by_click("building.9")
	check(ui.visible and page.visible,"map armor building opens new page")
	for viewport in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = viewport
		await settle()
		for i in 4:
			await click(page.get_node("Tab%d"%i).get_global_rect().get_center())
			await capture("tab%d_%d_%d" % [i,viewport.x,viewport.y])
			check(page.tab == i,"native tab switches at "+str(viewport))
	root.size = Vector2i(750,1334)
	await settle()
	await click(page.get_node("Tab0").get_global_rect().get_center())
	check(page.get_node("Scroll/Grid").get_child(5).get_node("Name").text == "日冕护腿","source six recipe order")
	await click(page.get_node("Tier").get_global_rect().get_center())
	await capture("tier_menu")
	await click(page.get_node("TierMenu/Tier2").get_global_rect().get_center())
	check(page.tier == 2 and page.get_node("Scroll/Grid").get_child_count() == 0,"locked tier has no unlocked recipes")
	await click(page.get_node("Tier").get_global_rect().get_center())
	await click(page.get_node("TierMenu/Tier1").get_global_rect().get_center())
	qa.supply(op,op.equipment_shop.recipes["forge.20103"],3)
	ui.render(op.snapshot())
	await click(page.get_node("Scroll/Grid").get_child(4).get_global_rect().get_center())
	check(page.get_node("Dialog").visible,"recipe opens craft dialog")
	await capture("craft")
	await click(page.get_node("Dialog/Max").get_global_rect().get_center())
	var maximum: int = op.equipment_shop.maximum(op._state,op.equipment_shop.recipes["forge.20103"])
	check(page.get_node("Dialog/Slider").value == maximum,"max quantity uses actual materials and capacity")
	await capture("craft_max")
	var material = page.get_node("Dialog/Materials").get_child(0)
	var material_id: int = material.get_meta("item")
	await click(material.get_global_rect().get_center())
	check(page.get_node("Dialog/Title").text == "获得途径","material icon opens source item information")
	check(not page.get_node("Dialog/Detail").text.contains("<color") and page.get_node("Dialog/Detail").text.contains("[color="),"source material markup becomes Godot rich text")
	await capture("material")
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	check(ui.get_node("Stage/Modal").visible,"material preorder opens actual order dialog")
	await click(ui.get_node("Stage/Modal/Reset").get_global_rect().get_center())
	await click(ui.get_node("Stage/Modal/Plus").get_global_rect().get_center())
	await capture("material_preorder")
	await click(ui.get_node("Stage/Modal/Confirm").get_global_rect().get_center())
	check(op.snapshot().orders.get("item.%d"%material_id,0) == 1,"material preorder changes real order state")
	await click(page.get_node("Dialog/Cancel").get_global_rect().get_center())
	check(page.get_node("Dialog/Slider").value == maximum,"return from material preserves craft quantity")
	root.size = Vector2i(360,640)
	await settle()
	await capture("craft_max_360_640")
	root.size = Vector2i(750,1334)
	await settle()
	while page.get_node("Dialog/Slider").value > 2:
		await click(page.get_node("Dialog/Minus").get_global_rect().get_center())
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	check(op.snapshot().equipment.size() == 2,"craft quantity creates two real instances")
	await capture("crafted")
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	await click(page.get_node("Tab2").get_global_rect().get_center())
	await capture("stock")
	await click(page.get_node("ListMode").get_global_rect().get_center())
	check(page.list_mode,"list mode toggles")
	await capture("stock_list")
	await click(page.get_node("ListMode").get_global_rect().get_center())
	await click(page.get_node("Scroll/Grid").get_child(0).get_global_rect().get_center())
	await click(page.get_node("Dialog/Lock").get_global_rect().get_center())
	check(op.snapshot().equipment_shop.locked.size() == 1,"shelf item locks")
	await capture("equipment")
	await click(page.get_node("Dialog/Lock").get_global_rect().get_center())
	await click(page.get_node("Dialog/Cancel").get_global_rect().get_center())
	await click(page.get_node("Resolve").get_global_rect().get_center())
	await click(page.get_node("Scroll/Grid").get_child(1).get_global_rect().get_center())
	await click(page.get_node("Resolve").get_global_rect().get_center())
	await capture("resolve")
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	check(op.snapshot().equipment.size() == 1,"resolve removes selected instance")
	qa.supply(op,op.equipment_shop.recipes["forge.40103"]); op.craft("forge.40103",1)
	ui.render(op.snapshot())
	await click(page.get_node("Tab3").get_global_rect().get_center())
	await click(page.get_node("Heroes/Rows").get_child(0).get_node("Card/Open").get_global_rect().get_center())
	check(app.get_node("Interface/MainHUD/Stage/HeroDetail").visible,"hero card opens actual hero detail")
	app.get_node("Interface/MainHUD/Stage/HeroDetail").close()
	await settle()
	check(ui.visible and page.tab == 3,"hero back restores armor tab")
	await click(page.get_node("Heroes/Rows").get_child(0).get_node("Slot1/Open").get_global_rect().get_center())
	check(page.get_node("Dialog").visible and not page.get_node("Dialog/Lock").visible,"equipped pants inspect does not expose shelf lock")
	await capture("equipped_pants")
	await click(page.get_node("Dialog/Cancel").get_global_rect().get_center())
	var hero: Dictionary = op._state.heroes.filter(func(h): return h.job == 1)[0]
	var before: Vector2 = hero.position
	var buyer_row = page.get_node("Heroes/Rows").get_children().filter(func(r): return r._id == hero.id)[0]
	await click(buyer_row.get_node("Summon").get_global_rect().get_center())
	check(hero.position == before and hero.requested == "building.9","summon submits real walking order")
	await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	for i in 300:
		op.advance(1)
		if hero.mode == "await_trade": break
	op.advance(35)
	refresh()
	check(hero.mode == "await_trade","summoned hero stays after arrival")
	var town = app.get_node("Town")
	var bubble: Sprite2D = town._offers[hero.id]
	town.camera.go_to(bubble.global_position,1.0)
	await settle()
	await capture("arrival")
	app.select_hero(hero.id)
	town.camera.end_focus()
	town.camera.go_to(bubble.global_position,1.0)
	await settle()
	await click(Vector2(375,667))
	check(page.get_node("Trade").visible and op.snapshot().equipment_shop.trading == hero.id,"one click bubble opens trade even when hero selected")
	hero.wallet = 0
	ui.render(op.snapshot())
	await capture("trade_poor")
	await click(page.get_node("Trade/Donate").get_global_rect().get_center())
	page.get_node("Dialog/Amount").text = "50000"
	await capture("donate")
	root.size = Vector2i(360,640)
	await settle()
	await capture("donate_360_640")
	root.size = Vector2i(750,1334)
	await settle()
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	check(hero.wallet == 50000,"trade donation transfers real funds")
	for viewport in [Vector2i(750,1334),Vector2i(360,640),Vector2i(750,1624)]:
		root.size = viewport
		await settle()
		await capture("trade_%d_%d" % [viewport.x,viewport.y])
	root.size = Vector2i(750,1334)
	await settle()
	var defense: float = hero.stats.defense
	var chest_serial: int = hero.equipment["2"].serial
	var pants_serial: int = hero.equipment["4"].serial
	var offers = page.get_node("Trade/Offers/Rows")
	check(offers.get_child_count() > 0,"profession-compatible offer displayed")
	if offers.get_child_count() > 0:
		await click(offers.get_child(0).get_node("Buy").get_global_rect().get_center())
		check(hero.equipment["2"].serial != chest_serial,"trade equips actual chest instance")
		await capture("sold")
	await click(page.get_node("Trade/Part1").get_global_rect().get_center())
	check(page.get_node("Trade")._slot == "4","pants tab switches equipment and offers")
	await capture("trade_pants")
	check(offers.get_child_count() == 1,"other slot remains purchasable in same visit")
	if offers.get_child_count() > 0:
		check(offers.get_child(0).get_node("Buy").disabled,"insufficient private wallet blocks second sale")
		await click(page.get_node("Trade/Donate").get_global_rect().get_center())
		page.get_node("Dialog/Amount").text = "50000"
		await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
		check(not offers.get_child(0).get_node("Buy").disabled,"donation enables second armor part")
		await click(offers.get_child(0).get_node("Buy").get_global_rect().get_center())
		check(hero.equipment["4"].serial != pants_serial,"trade equips actual pants instance")
	check(hero.stats.defense > defense,"both purchases increase real defense")
	check(op.snapshot().equipment_shop.purchased == ["2","4"],"both slots recorded separately")
	await capture("sold_both")
	await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	check(not ui.visible and op.snapshot().equipment_shop.trading.is_empty(),"trade back releases buyer and returns map")
	op._state.buildings["building.9"] = 4
	var recipe: Dictionary = op.equipment_shop.recipes.values().filter(func(r): return r.building == "building.9" and r.one_use and r.tier == 2)[0]
	qa.supply(op,recipe)
	app.open_building("building.9")
	page.tier = 2
	page.switch_tab(1)
	await capture("drawing_owned")
	await click(page.get_node("Scroll/Grid").get_child(0).get_global_rect().get_center())
	await click(page.get_node("Dialog/Accept").get_global_rect().get_center())
	check(TownMainInventory.count(op._state,recipe.source_id) == 0,"one-use drawing consumed by UI")
	print("ARMOR_CAPTURE ",JSON.stringify({"failures":failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func refresh() -> void:
	var state: Dictionary = op.snapshot()
	ui.render(state)
	app.get_node("Town").render_actors(state)
	app.get_node("Interface/MainHUD").render(state)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/armor_shop/"+name+".png")

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
