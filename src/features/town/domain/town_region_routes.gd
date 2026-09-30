class_name TownRegionRoutes
extends RefCounted

# The source map joins each field to the city. Fields never connect directly.
static func route(nav: TownNavigation, start: Vector2, finish: Vector2, from: String, to: String) -> Array:
	var starts: Array = [start] if from == "town" else nav.exits[from]
	var finishes: Array = [finish] if to == "town" else nav.exits[to]
	var best: Array = []
	var shortest := INF
	for entry: Vector2 in starts:
		var first: Array = [] if from == "town" else nav._within(start, entry, from)
		if from != "town" and first.is_empty(): continue
		for exit_point: Vector2 in finishes:
			var middle := nav._within(entry, exit_point, "town")
			var last: Array = [] if to == "town" else nav._within(exit_point, finish, to)
			if middle.is_empty() or (to != "town" and last.is_empty()): continue
			var candidate := first + middle + last
			var distance := 0.0
			var previous := start
			for waypoint: Vector2 in candidate:
				distance += previous.distance_to(waypoint)
				previous = waypoint
			if distance < shortest:
				shortest = distance
				best = candidate
	return best
