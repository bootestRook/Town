@tool
extends VBoxContainer

signal node_chosen(type_id: String)

@onready var _search: LineEdit = $Search
@onready var _catalog_filter: OptionButton = $CatalogFilter
@onready var _favorite_button: Button = $FavoriteButton
@onready var _catalog: ItemList = $Catalog

var _controller: RefCounted
var _favorite_type_ids: Dictionary = {}
var _recent_type_ids: Array[String] = []


func _ready() -> void:
	_catalog_filter.add_item("All")
	_catalog_filter.add_item("Favorites")
	_catalog_filter.add_item("Recent")
	_search.text_changed.connect(func(_text: String) -> void: refresh())
	_catalog_filter.item_selected.connect(func(_index: int) -> void: refresh())
	_favorite_button.pressed.connect(_toggle_catalog_favorite)
	_catalog.item_selected.connect(_on_catalog_item_selected)
	refresh()


func initialize(controller: RefCounted) -> void:
	_controller = controller
	refresh()


func _on_catalog_item_selected(index: int) -> void:
	var type_id := String(_catalog.get_item_metadata(index))
	_recent_type_ids.erase(type_id)
	_recent_type_ids.push_front(type_id)
	while _recent_type_ids.size() > 12:
		_recent_type_ids.pop_back()
	node_chosen.emit(type_id)


func refresh() -> void:
	if not is_node_ready() or _controller == null:
		return
	_catalog.clear()
	var query := _search.text.strip_edges().to_lower()
	var filter := _catalog_filter.get_item_text(_catalog_filter.selected) if _catalog_filter.item_count > 0 else "All"
	for descriptor: RefCounted in _controller.node_registry().descriptors():
		var haystack := "%s %s %s %s" % [
			descriptor.display_name,
			descriptor.type_id,
			descriptor.category,
			" ".join(descriptor.keywords),
		]
		if not query.is_empty() and not haystack.to_lower().contains(query):
			continue
		if filter == "Favorites" and not _favorite_type_ids.has(descriptor.type_id):
			continue
		if filter == "Recent" and not _recent_type_ids.has(descriptor.type_id):
			continue
		var marker := "★ " if _favorite_type_ids.has(descriptor.type_id) else ""
		var index := _catalog.add_item("%s%s / %s" % [marker, descriptor.category, descriptor.display_name])
		_catalog.set_item_metadata(index, descriptor.type_id)


func _toggle_catalog_favorite() -> void:
	var selected := _catalog.get_selected_items()
	if selected.is_empty():
		return
	var type_id := String(_catalog.get_item_metadata(selected[0]))
	if _favorite_type_ids.has(type_id):
		_favorite_type_ids.erase(type_id)
	else:
		_favorite_type_ids[type_id] = true
	refresh()
