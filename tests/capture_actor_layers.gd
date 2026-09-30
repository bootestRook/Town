extends SceneTree

var failures: Array[String] = []
var app
const OUTPUT := "res://validation/actor_visuals/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var town = app.get_node("Town")
	var snapshot: Dictionary = app.operations_snapshot()
	var origin := Vector2(3830, 2870)
	for i in 3:
		var hero: Dictionary = snapshot.heroes[i]
		hero.position = origin + [Vector2.ZERO, Vector2(22, 54), Vector2(130, 100)][i]
		hero.previous_position = hero.position
		hero.mode = "idle"
		hero.animation = "idle"
		hero.animation_time = 0.0
		hero.direction = Vector2.RIGHT
		hero.needs.hp = 100.0
	town.render_actors(snapshot)
	town.camera.go_to(origin + Vector2(40, -30), 1.55)
	var with_bar := await capture("01_crowded_actors")
	var back_bar: TextureProgressBar = town._heroes["hero.1"].get_node("Health")
	var front_body: Sprite2D = town._heroes["hero.2"].get_node("Body")
	check(back_bar.size.is_equal_approx(Vector2(58, 9)), "source health track is 58 by 9")
	check(back_bar.texture_progress.get_size() == Vector2(54, 5), "source fill is 54 by 5")
	var overlap: Array[Vector2i] = []
	for x in range(4, 54):
		for y in range(2, 7):
			var world: Vector2 = back_bar.get_global_transform() * Vector2(x, y)
			if front_body.is_pixel_opaque(front_body.to_local(world)):
				overlap.append(Vector2i(back_bar.get_global_transform_with_canvas() * Vector2(x, y)))
	back_bar.visible = false
	var without_bar := await capture("02_occlusion_probe")
	var occluded := 0
	for point: Vector2i in overlap:
		if with_bar.get_pixelv(point).is_equal_approx(without_bar.get_pixelv(point)):
			occluded += 1
	check(overlap.size() > 20 and occluded > overlap.size() * 0.8, "front character covers rear bar at overlapping opaque pixels")
	town.render_actors(snapshot)
	root.size = Vector2i(360, 640)
	await capture("03_crowded_small")
	root.size = Vector2i(750, 1624)
	await capture("04_crowded_tall")
	root.size = Vector2i(750, 1334)
	for i in 3:
		snapshot.heroes[i].position = origin + Vector2((i - 1) * 160, 40)
		snapshot.heroes[i].previous_position = snapshot.heroes[i].position
		snapshot.heroes[i].animation = "attack"
		snapshot.heroes[i].animation_time = 0.25
		snapshot.heroes[i].needs.hp = [100, 50, 25][i]
	town.camera.go_to(origin + Vector2(0, -20), 1.15)
	town.render_actors(snapshot)
	await capture("05_attack_and_health_colors")
	for i in 3:
		var bar: TextureProgressBar = town._heroes["hero.%d" % (i + 1)].get_node("Health")
		check(bar.tint_progress == [Color8(68, 227, 109), Color8(255, 153, 0), Color8(204, 0, 51)][i], "source health color thresholds")
	for hero: Dictionary in snapshot.heroes:
		hero.animation = "death"
		hero.mode = "dead"
		hero.animation_time = 0.35
		hero.needs.hp = 0
	town.render_actors(snapshot)
	await capture("06_death_fade")
	check(not back_bar.visible, "death hides health bar like source")
	for hero: Dictionary in snapshot.heroes:
		hero.animation_time = 1.1
	town.render_actors(snapshot)
	check(town._heroes["hero.1"].modulate.a == 0, "source death fades within one second")
	for hero: Dictionary in snapshot.heroes:
		hero.mode = "walking"
		hero.animation = "move"
		hero.animation_time = 0.2
	town.render_actors(snapshot)
	await capture("07_gray_souls")
	check(town._heroes["hero.1"].body.material != null and town._heroes["hero.1"].modulate.a == 1, "source soul is opaque grayscale")
	var hero: Dictionary = snapshot.heroes[0]
	hero.previous_position = origin
	hero.position = origin + Vector2(7, 0)
	snapshot.frame_remainder = 0.025
	town.render_actors(snapshot)
	check(town._heroes[hero.id].position.is_equal_approx(origin + Vector2(3.5, 0)), "render interpolates half a simulation step without moving domain position")
	check(hero.position == origin + Vector2(7, 0), "presentation never writes back interpolation")
	var actor = town._heroes[hero.id]
	check(actor.get_node("Health").position.is_equal_approx(Vector2(-27.439, 4.647)), "health anchor stays at source root offset")
	check(is_equal_approx(actor.get_node("Name").position.y, -131.096), "hero name uses source anchor independent of pose alpha bounds")
	print("ACTOR_VISUAL_RESULT ", JSON.stringify({"failures":failures, "overlap_pixels":overlap.size(), "occluded_pixels":occluded}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func capture(name: String) -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png(OUTPUT + name + ".png")
	return result


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
