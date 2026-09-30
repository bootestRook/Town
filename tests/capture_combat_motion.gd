extends SceneTree

var app
var op
var town
const OUTPUT := "res://validation/combat_motion/"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.unfocusable = true
	root.position = Vector2i(-4000, 0)
	root.size = Vector2i(750, 1334)
	DirAccess.make_dir_recursive_absolute(OUTPUT + "frames")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	op = app._operations
	town = app.get_node("Town")
	var sequence = op._simulation.combat.sequence
	var targets: Array = [op._state.monsters[0], op._state.monsters[3], op._state.monsters[1]]
	for monster: Dictionary in op._state.monsters:
		monster.position = Vector2(6000, 4500)
	for i in 3:
		var hero: Dictionary = op._state.heroes[i]
		hero.position = Vector2(4330, 3210 + i * 220)
		hero.mode = "hunting"
		hero.needs.hp = 100
		targets[i].position = hero.position + Vector2(90 if i == 1 else 180, 20)
		targets[i].direction = Vector2.LEFT
		sequence.begin(hero, targets[i])
	town.camera.go_to(Vector2(4410, 3390), 1.35)
	var projectile_seen := false
	var impact_seen := false
	for frame in 96:
		if frame == 45:
			for i in 3:
				targets[i].position = op._state.heroes[i].position + Vector2(90 if i == 1 else 180, -30 if i == 1 else -70)
				sequence.begin(op._state.heroes[i], targets[i])
		for hero: Dictionary in op._state.heroes:
			hero.animation_time += 1.0 / 30.0
			sequence.advance(hero, op._state, 1.0 / 30.0, op._simulation.combat, op)
		sequence.advance_projectiles(op._state, 1.0 / 30.0, op._simulation.combat, op)
		projectile_seen = projectile_seen or not op._state.projectiles.is_empty()
		impact_seen = impact_seen or not op._state.effects.is_empty()
		var shot := await render_frame()
		shot.save_png(OUTPUT + "frames/%03d.png" % frame)
		if frame in [8, 15, 20, 55, 61, 68]:
			shot.save_png(OUTPUT + "%02d_pose.png" % frame)
	check(projectile_seen, "original arrow and orb are visible in the native sequence")
	check(impact_seen, "source hit sprites appear after contact")
	root.size = Vector2i(360, 640)
	(await render_frame()).save_png(OUTPUT + "small.png")
	root.size = Vector2i(750, 1624)
	(await render_frame()).save_png(OUTPUT + "tall.png")
	print("COMBAT_MOTION ", JSON.stringify({"failures":failures,"frames":96,"projectile_seen":projectile_seen,"impact_seen":impact_seen}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func render_frame() -> Image:
	for actor: Dictionary in op._state.heroes + op._state.monsters:
		actor.previous_position = actor.position
	town.render_actors(op.snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
