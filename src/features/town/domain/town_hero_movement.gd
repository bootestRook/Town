class_name TownHeroMovement
extends RefCounted

var navigation: TownNavigation


func travel(hero: Dictionary, destination: Vector2, target: String) -> bool:
	var path := navigation.route(hero.position, destination)
	if path.is_empty():
		hero.reason = "道路暂不可达"
		hero.mode = "idle"
		hero.timer = 2.0
		TownHeroStats.animate(hero, "idle")
		return false
	hero.mode = "walking"
	hero.target = target
	hero.path = path
	hero.wait_time = 0.0
	TownHeroStats.animate(hero, "move")
	return true


func step(actor: Dictionary, _actors: Array, dt: float, speed: float, stop_at_waypoint: bool = false) -> bool:
	var remaining := speed * dt
	while not actor.path.is_empty():
		var next: Vector2 = actor.path[0]
		if not navigation.passable(next):
			actor.path.clear()
			actor.reason = "道路发生变化"
			TownHeroStats.animate(actor, "idle")
			return false
		var direction: Vector2 = next - actor.position
		var distance := direction.length()
		if distance < 0.0001:
			actor.path.pop_front()
			continue
		TownHeroStats.face(actor, direction)
		TownHeroStats.animate(actor, "move")
		if distance > remaining:
			actor.position += direction / distance * remaining
			return false
		actor.position = next
		actor.path.pop_front()
		remaining -= distance
		if remaining <= 0 or stop_at_waypoint:
			break
	if actor.path.is_empty():
		TownHeroStats.animate(actor, "idle")
	return actor.path.is_empty()
