extends SceneTree

var app
var ui
var failures: Array[String] = []
const OUTPUT := "res://validation/buildings/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	ui = app.get_node("Interface/BuildingUI")
	await capture("00_map")
	for number in [1, 2, 3, 4]:
		var building := "building.%d" % number
		await open_by_click(building)
		check(ui.visible and ui.building == building, "map click opens " + building)
		var page = ui.get_node("Stage/Life")
		var material: String = app.operations_snapshot().services[building].material
		var before: int = app.operations_snapshot().inventory[material]
		# Invalid drop must not charge stock.
		await drag(page.get_node("Material").get_global_rect().get_center(), Vector2(60, 720))
		check(app.operations_snapshot().inventory[material] == before, "invalid drop keeps material")
		await drag(page.get_node("Material").get_global_rect().get_center(), page.get_node("WorkArea").get_global_rect().get_center())
		check(app.operations_snapshot().inventory[material] == 0, "valid drag commits production " + building)
		await capture("0%d_life" % number)
		await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	await open_by_click("building.7")
	await capture("05_exchange")
	var shop = ui.get_node("Stage/Shop")
	await click(shop.get_node("Scroll/Grid").get_child(0).get_global_rect().get_center())
	await click(ui.get_node("Stage/Modal/Ten").get_global_rect().get_center())
	await capture("06_order")
	await click(ui.get_node("Stage/Modal/Confirm").get_global_rect().get_center())
	check(app.operations_snapshot().orders.get("item.20101", 0) == 10, "order dialog creates remaining quantity")
	await click(shop.get_node("Tab2").get_global_rect().get_center())
	await capture("07_heroes")
	await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	for number in [6, 9, 10]:
		await open_by_click("building.%d" % number)
		await capture("08_shop_%d" % number)
		var index := 2 if number == 6 else 0
		await click(shop.get_node("Scroll/Grid").get_child(index).get_global_rect().get_center())
		await capture("09_forge_%d" % number)
		await click(ui.get_node("Stage/Modal/Confirm").get_global_rect().get_center())
		check(not ui.get_node("Stage/Modal").visible, "crafting succeeds for shop %d" % number)
		await click(shop.get_node("Tab2").get_global_rect().get_center())
		await capture("10_stock_%d" % number)
		await click(ui.get_node("Stage/Back").get_global_rect().get_center())
	for round_index in 12:
		app._operations.advance(15)
		for hero: Dictionary in app.operations_snapshot().heroes:
			if hero.mode == "await_trade":
				var current: Dictionary = app.operations_snapshot().heroes.filter(func(h): return h.id == hero.id)[0]
				if current.mode != "await_trade":
					continue
				ui.close()
				await settle()
				var town = app.get_node("Town")
				var offer: Sprite2D = town._offers[hero.id]
				var point := offer.global_position
				for x in range(-25, 30, 5):
					if offer.is_pixel_opaque(Vector2(x, 0)):
						point = offer.to_global(Vector2(x, 0))
						break
				town.camera.go_to(point, 1.0)
				await settle()
				await click(Vector2(375, 667))
				check(ui.visible and ui.get_node("Stage/Modal").visible, "hero overhead icon opens equipment trade")
				await settle()
				if ui.get_node("Stage/Modal").visible:
					await capture("11_sale_" + hero.id)
					await click(ui.get_node("Stage/Modal/Confirm").get_global_rect().get_center())
	app.open_building("building.7")
	await click(shop.get_node("Tab2").get_global_rect().get_center())
	await capture("11_cycle")
	var report: Array = app.operations_snapshot().report
	check(report.any(func(row): return row.kind == "收购"), "hero sells materials")
	check(report.any(func(row): return row.kind == "使用完成"), "hero finishes service")
	check(report.any(func(row): return row.kind == "出售装备"), "hero buys and equips crafted item")
	check(report.any(func(row): return "幻影项链" in row.text and row.kind == "出售装备"), "jewelry sale completes")
	await click(ui.get_node("Stage/Report").get_global_rect().get_center())
	await capture("12_report")
	await click(ui.get_node("Stage/ReportPanel/Close").get_global_rect().get_center())
	app.open_building("building.1")
	root.size = Vector2i(360, 640)
	await settle()
	await capture("13_small_portrait")
	root.size = Vector2i(750, 1624)
	await settle()
	await capture("14_tall_portrait")
	root.size = Vector2i(750, 1334)
	print("BUILDING_CAPTURE_RESULT ", JSON.stringify({"failures": failures, "report": report}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func open_by_click(id: String) -> void:
	var town = app.get_node("Town")
	var sprite: Sprite2D = town._sprites[id]
	var point := Vector2.ZERO
	for y in range(-40, 81, 10):
		if sprite.is_pixel_opaque(Vector2(0, y)):
			point = sprite.global_position + Vector2(0, y)
			break
	town.camera.go_to(point, 1.0)
	await settle()
	await click(Vector2(375, 667))


func click(point: Vector2) -> void:
	mouse(point, true)
	await process_frame
	mouse(point, false)
	await settle()


func drag(start: Vector2, finish: Vector2) -> void:
	mouse(start, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	mouse(finish, false)
	await settle()


func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)


func settle() -> void:
	for i in 5:
		await process_frame


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")


func check(valid: bool, message: String) -> void:
	if not valid:
		failures.append(message)
	print("[PASS] " if valid else "[FAIL] ", message)
