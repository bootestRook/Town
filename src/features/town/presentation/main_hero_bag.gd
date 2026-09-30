extends Control

signal item_requested(id: String)
const CELL = preload("res://scenes/town/main_hero_bag_cell.tscn")
var _key := ""
var _hero_id := ""

func render(hero: Dictionary, catalog, definitions: Dictionary) -> void:
	var rows: Array = []
	for id: String in hero.bag:
		if hero.bag[id] > 0: rows.append(definitions.bag_items[id])
	rows.sort_custom(func(a,b): return a.sort_order < b.sort_order)
	var visible_rows := maxi(4, roundi((size.y - 17) / 110.0))
	var cells := maxi(visible_rows * 6, ceili(rows.size() / 6.0) * 6)
	var key := str([hero.id, hero.bag, cells])
	if key == _key: return
	_key = key
	if _hero_id != hero.id: $Scroll.scroll_vertical = 0
	_hero_id = hero.id
	for child in $Scroll/Grid.get_children():
		$Scroll/Grid.remove_child(child)
		child.queue_free()
	for i in cells:
		var cell = CELL.instantiate()
		$Scroll/Grid.add_child(cell)
		var item: Dictionary = rows[i] if i < rows.size() else {}
		cell.configure(item, hero.bag[item.id] if not item.is_empty() else 0, catalog)
		if not item.is_empty(): cell.pressed.connect(func(): item_requested.emit(item.id))
