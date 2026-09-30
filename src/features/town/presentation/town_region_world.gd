extends Node2D
signal open_requested(area: String)
const GATE = preload("res://scenes/town/region_gate.tscn")
var gates := {}
var levels := {}
var sprites := {}
var _catalog

func configure(data, catalog, objects: Node2D) -> void:
	_catalog = catalog
	for row: Dictionary in data.rows("town_region_levels"): levels[row.id] = row
	for row: Dictionary in data.rows("town_region_gates"):
		gates[row.id] = row
		var gate = GATE.instantiate()
		objects.add_child(gate)
		gate.position = Vector2(row.gate_x, row.gate_y)
		sprites[row.id] = gate.get_node("Art")
		sprites[row.id].position = Vector2(row.click_x,row.click_y)

func render(state: Dictionary) -> void:
	for area: String in gates:
		sprites[area].texture = _catalog.load_resource(levels[area+"."+str(state.regions[area].level)].gate_resource)

func pick(point: Vector2) -> bool:
	for area: String in gates:
		var gate: Dictionary = gates[area]
		var center := Vector2(gate.gate_x+gate.click_x,gate.gate_y+gate.click_y)
		if Rect2(center-Vector2(65,80),Vector2(130,160)).has_point(point):
			open_requested.emit(area)
			return true
	return false
