@tool
class_name AbilityGraphEditor
extends Control

const GraphEditScript = preload("res://addons/combat_framework_editor/editor/ability_graph_node_view.gd")
const ControllerScript = preload(
	"res://addons/combat_framework_editor/editor/ability_graph_document_controller.gd"
)
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const ActionRegistryScript = preload("res://src/runtime/ability/ability_action_registry.gd")
const PlaceholderResolverScript = preload(
	"res://addons/combat_framework_editor/editor/ability_editor_placeholder_resolver.gd"
)

@onready var _graph_edit: GraphEdit = $Root/Body/GraphEdit
@onready var _status: Label = $Root/Toolbar/Status
@onready var _candidate_menu: PopupMenu = $CandidateMenu

var _controller: RefCounted
var _resource: RefCounted
var _action_registry: RefCounted
var _wired := false
var _selected_node_id := ""
var _move_before: Dictionary = {}
var _views: Dictionary = {}
var _debug_node_id := ""
var _connection_source_node := ""
var _connection_source_port := -1
var _connection_is_output := true
var _candidate_position := Vector2.ZERO
@onready var _inspector: VBoxContainer = $Root/Body/InspectorPanel
@onready var _node_catalog: VBoxContainer = $Root/Body/CatalogPanel


func _ready() -> void:
	_wire_ui()
	_set_status("No graph selected")


func initialize(undo_redo: Object, framework_registry: RefCounted = null) -> void:
	if _controller == null:
		_controller = ControllerScript.new(undo_redo)
		_controller.document_changed.connect(_on_document_changed)
	_action_registry = ActionRegistryScript.new()
	if framework_registry != null and framework_registry.has_method("register_manifest"):
		_controller.set_node_registry(framework_registry.node_registry)
		_action_registry = framework_registry.action_registry
	_action_registry.register_action("editor.placeholder", PlaceholderResolverScript.new())
	_action_registry.register_action("module.damage.deal", PlaceholderResolverScript.new())
	_action_registry.register_action("module.effect.apply", PlaceholderResolverScript.new())
	_inspector.initialize(_controller)
	_node_catalog.initialize(_controller)


func set_graph_resource(graph_resource: RefCounted) -> void:
	if _controller == null:
		initialize(null)
	_resource = graph_resource
	_controller.set_resource(graph_resource)
	_selected_node_id = ""
	_refresh()


func clear_graph_resource() -> void:
	_resource = null
	if _controller != null:
		_controller.set_resource(null)
	_refresh()


func _wire_ui() -> void:
	if _wired:
		return
	_wired = true
	$Root/Toolbar/CompileButton.pressed.connect(_compile)
	$Root/Toolbar/FrameButton.pressed.connect(_add_frame)
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph_edit.begin_node_move.connect(_on_begin_node_move)
	_graph_edit.end_node_move.connect(_on_end_node_move)
	_graph_edit.node_selected.connect(_on_node_selected)
	_graph_edit.node_deselected.connect(_on_node_deselected)
	_graph_edit.copy_nodes_request.connect(_copy_selected)
	_graph_edit.cut_nodes_request.connect(_cut_selected)
	_graph_edit.paste_nodes_request.connect(_paste_clipboard)
	_graph_edit.duplicate_nodes_request.connect(_duplicate_selected)
	_graph_edit.scroll_offset_changed.connect(_on_scroll_changed)
	_graph_edit.popup_request.connect(_on_graph_popup_request)
	_graph_edit.connection_drag_started.connect(_on_connection_drag_started)
	_graph_edit.connection_drag_ended.connect(_on_connection_drag_ended)
	_candidate_menu.id_pressed.connect(_on_candidate_selected)
	_inspector.status_requested.connect(_set_status)
	_inspector.debug_node_selected.connect(_on_debug_node_selected)
	_node_catalog.node_chosen.connect(_on_catalog_type_selected)


func _refresh() -> void:
	if not is_node_ready():
		return
	_graph_edit.clear_connections()
	for child: Node in _graph_edit.get_children():
		if child is GraphNode or child is GraphFrame:
			_graph_edit.remove_child(child)
			child.queue_free()
	_views.clear()
	for frame_data: Dictionary in _resource.frames if _resource != null else []:
		var frame := GraphFrame.new()
		frame.name = String(frame_data.get("frame_id", "frame"))
		frame.title = String(frame_data.get("title", "Frame"))
		frame.position_offset = frame_data.get("position", Vector2.ZERO)
		frame.size = frame_data.get("size", Vector2(360, 220))
		_graph_edit.add_child(frame)
		_graph_edit.move_child(frame, 0)
	if _resource == null:
		_inspector.select_node(null, "")
		return
	_graph_edit.scroll_offset = _resource.editor_scroll_offset
	_graph_edit.zoom = _resource.editor_zoom
	for node: RefCounted in _resource.nodes:
		var descriptor: RefCounted = _controller.descriptor(node.type_id)
		var view := GraphEditScript.new()
		view.configure(node.to_definition(), descriptor)
		view.position_offset = _resource.node_position(node.node_id)
		view.custom_minimum_size = _resource.node_size(node.node_id)
		view.set_comment(_resource.node_comment(node.node_id))
		_graph_edit.add_child(view)
		_views[node.node_id] = view
	for connection: RefCounted in _resource.connections:
		var from_view: AbilityGraphNodeView = _views.get(connection.from_node_id) as AbilityGraphNodeView
		var to_view: AbilityGraphNodeView = _views.get(connection.to_node_id) as AbilityGraphNodeView
		if from_view == null or to_view == null:
			continue
		var from_port := _output_port(from_view, connection.from_pin_id)
		var to_port := _input_port(to_view, connection.to_pin_id)
		if from_port >= 0 and to_port >= 0:
			_graph_edit.connect_node(connection.from_node_id, from_port, connection.to_node_id, to_port)
	_apply_debug_connection_activity()
	if _views.has(_selected_node_id):
		_views[_selected_node_id].selected = true
	_inspector.select_node(_resource, _selected_node_id)


func _apply_debug_connection_activity() -> void:
	if _resource == null:
		return
	var active: Dictionary = _inspector.active_edge()
	for connection: RefCounted in _resource.connections:
		var from_view: AbilityGraphNodeView = _views.get(connection.from_node_id) as AbilityGraphNodeView
		var to_view: AbilityGraphNodeView = _views.get(connection.to_node_id) as AbilityGraphNodeView
		if from_view == null or to_view == null:
			continue
		var from_port := _output_port(from_view, connection.from_pin_id)
		var to_port := _input_port(to_view, connection.to_pin_id)
		if from_port < 0 or to_port < 0:
			continue
		var is_active: bool = (
			String(active.get("from_node_id", "")) == connection.from_node_id
			and String(active.get("output_pin", "")) == connection.from_pin_id
			and String(active.get("to_node_id", "")) == connection.to_node_id
		)
		_graph_edit.set_connection_activity(connection.from_node_id, from_port, connection.to_node_id, to_port, 1.0 if is_active else 0.0)


func _on_catalog_type_selected(type_id: String) -> void:
	if _resource == null:
		return
	var result: String = _controller.add_node(type_id, _graph_edit.scroll_offset + Vector2(240, 160))
	if not result.is_empty():
		_set_status("Add failed: %s" % result)


func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	_connection_source_node = String(from_node)
	_connection_source_port = from_port
	_connection_is_output = is_output


func _on_connection_drag_ended() -> void:
	_connection_source_node = ""
	_connection_source_port = -1


func _on_graph_popup_request(at_position: Vector2) -> void:
	if _resource == null or _controller == null:
		return
	_candidate_position = at_position
	_candidate_menu.clear()
	var candidates := _candidate_descriptors()
	for descriptor: RefCounted in candidates:
		var index := _candidate_menu.item_count
		_candidate_menu.add_item("%s / %s" % [descriptor.category, descriptor.display_name])
		_candidate_menu.set_item_metadata(index, descriptor.type_id)
	if _candidate_menu.item_count == 0:
		return
	var global_position: Vector2 = _graph_edit.get_global_transform_with_canvas() * at_position
	_candidate_menu.popup_on_parent(Rect2i(Vector2i(global_position), Vector2i.ZERO))


func _candidate_descriptors() -> Array[RefCounted]:
	if _connection_source_node.is_empty() or _connection_source_port < 0:
		return _controller.node_registry().descriptors()
	var source_view := _views.get(_connection_source_node) as AbilityGraphNodeView
	if source_view == null:
		return _controller.node_registry().descriptors()
	var source_node: RefCounted = _resource.node_by_id(_connection_source_node)
	var source_descriptor: RefCounted = _controller.descriptor(source_node.type_id)
	var source_pin_id := source_view.output_pin_for_port(_connection_source_port) if _connection_is_output else source_view.input_pin_for_port(_connection_source_port)
	if source_pin_id.is_empty() or source_descriptor == null:
		return []
	var source_pin: RefCounted = source_descriptor.output_pin(source_pin_id) if _connection_is_output else source_descriptor.input_pin(source_pin_id)
	return _controller.node_registry().descriptors_for_pin(source_pin, not _connection_is_output)


func _on_candidate_selected(index: int) -> void:
	var type_id := String(_candidate_menu.get_item_metadata(index))
	var new_node_id: String = _controller.add_node(type_id, _candidate_position)
	if new_node_id.is_empty() or _connection_source_node.is_empty():
		return
	_connect_candidate(new_node_id)


func _connect_candidate(new_node_id: String) -> void:
	var source_node: RefCounted = _resource.node_by_id(_connection_source_node)
	var target_node: RefCounted = _resource.node_by_id(new_node_id)
	if source_node == null or target_node == null:
		return
	var source_descriptor: RefCounted = _controller.descriptor(source_node.type_id)
	var target_descriptor: RefCounted = _controller.descriptor(target_node.type_id)
	var source_view := _views.get(_connection_source_node) as AbilityGraphNodeView
	if source_descriptor == null or target_descriptor == null or source_view == null:
		return
	var source_pin_id := source_view.output_pin_for_port(_connection_source_port) if _connection_is_output else source_view.input_pin_for_port(_connection_source_port)
	if source_pin_id.is_empty():
		return
	if _connection_is_output:
		var source_pin: RefCounted = source_descriptor.output_pin(source_pin_id)
		for pin_id: String in target_descriptor.input_pins:
			if target_descriptor.input_pin(pin_id).accepts(source_pin).is_empty():
				_controller.connect_nodes(_connection_source_node, source_pin_id, new_node_id, pin_id)
				return
	else:
		var source_pin: RefCounted = source_descriptor.input_pin(source_pin_id)
		for pin_id: String in target_descriptor.output_pins:
			if source_pin.accepts(target_descriptor.output_pin(pin_id)).is_empty():
				_controller.connect_nodes(new_node_id, pin_id, _connection_source_node, source_pin_id)
				return


func _on_connection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	var source_view: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
	var target_view: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
	if source_view == null or target_view == null:
		return
	var output_pin := source_view.output_pin_for_port(from_port)
	var input_pin := target_view.input_pin_for_port(to_port)
	if output_pin.is_empty() or input_pin.is_empty():
		var swapped_source: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
		var swapped_target: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
		if swapped_source != null and swapped_target != null:
			output_pin = swapped_source.output_pin_for_port(to_port)
			input_pin = swapped_target.input_pin_for_port(from_port)
			if not output_pin.is_empty() and not input_pin.is_empty():
				var swapped_result: String = _controller.connect_nodes(
					String(to_node), output_pin, String(from_node), input_pin
				)
				if not swapped_result.is_empty():
					_set_status("Connect failed: %s" % swapped_result)
				return
		_set_status("Connect failed: ports must be output → input")
		return
	var result: String = _controller.connect_nodes(String(from_node), output_pin, String(to_node), input_pin)
	if not result.is_empty():
		_set_status("Connect failed: %s" % result)


func _on_disconnection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int
) -> void:
	var source_view: AbilityGraphNodeView = _views.get(String(from_node)) as AbilityGraphNodeView
	var target_view: AbilityGraphNodeView = _views.get(String(to_node)) as AbilityGraphNodeView
	if source_view == null or target_view == null:
		return
	var output_pin := source_view.output_pin_for_port(from_port)
	var input_pin := target_view.input_pin_for_port(to_port)
	var source_id := String(from_node)
	var target_id := String(to_node)
	if output_pin.is_empty() or input_pin.is_empty():
		output_pin = target_view.output_pin_for_port(to_port)
		input_pin = source_view.input_pin_for_port(from_port)
		source_id = String(to_node)
		target_id = String(from_node)
	var result: String = _controller.disconnect_nodes(source_id, output_pin, target_id, input_pin)
	if not result.is_empty():
		_set_status("Disconnect failed: %s" % result)


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	var ids: Array[String] = []
	for node_name: StringName in node_names:
		ids.append(String(node_name))
	_controller.delete_nodes(ids)
	_selected_node_id = ""


func _on_begin_node_move() -> void:
	_move_before.clear()
	if _resource == null:
		return
	for node: RefCounted in _resource.nodes:
		_move_before[node.node_id] = _resource.node_position(node.node_id)


func _on_end_node_move() -> void:
	if _resource == null or _move_before.is_empty():
		return
	var positions: Dictionary = {}
	for node_id: String in _views:
		positions[node_id] = _views[node_id].position_offset
	if positions != _move_before:
		_controller.commit_node_positions(positions)
	_move_before.clear()


func _on_node_selected(node: Node) -> void:
	if node is AbilityGraphNodeView:
		_selected_node_id = node.source_node_id
		_inspector.select_node(_resource, _selected_node_id)


func _on_node_deselected(_node: Node) -> void:
	if not _views.has(_selected_node_id):
		_selected_node_id = ""
		_inspector.select_node(_resource, _selected_node_id)


func _add_frame() -> void:
	if _resource == null:
		return
	var frame_id: String = _controller.add_frame("Ability Frame", _graph_edit.scroll_offset + Vector2(120, 100))
	_set_status("Added %s" % frame_id)


func _copy_selected() -> void:
	if _resource == null:
		return
	var selected: Array[String] = _selected_node_ids()
	DisplayServer.clipboard_set(JSON.stringify(_controller.copy_payload(selected)))
	_set_status("Copied %d node(s)" % selected.size())


func _cut_selected() -> void:
	_copy_selected()
	var selected := _selected_node_ids()
	_controller.delete_nodes(selected)
	_selected_node_id = ""


func _paste_clipboard() -> void:
	var parsed: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Clipboard does not contain an Ability Graph payload")
		return
	var pasted: Array[String] = _controller.paste_payload(parsed, Vector2(40, 40))
	if pasted.is_empty():
		_set_status("Nothing pasted")
		return
	_selected_node_id = pasted[0]
	_set_status("Pasted %d node(s)" % pasted.size())


func _duplicate_selected() -> void:
	var payload: Dictionary = _controller.copy_payload(_selected_node_ids())
	var pasted: Array[String] = _controller.paste_payload(payload, Vector2(40, 40))
	if not pasted.is_empty():
		_selected_node_id = pasted[0]


func _selected_node_ids() -> Array[String]:
	var ids: Array[String] = []
	for node_id: String in _views:
		if _views[node_id].selected:
			ids.append(node_id)
	return ids


func _on_scroll_changed(offset: Vector2) -> void:
	if _resource != null:
		_resource.editor_scroll_offset = offset


func _on_document_changed() -> void:
	_refresh()


func _set_status(message: String) -> void:
	if is_node_ready():
		_status.text = message


func _input_port(view: AbilityGraphNodeView, pin_id: String) -> int:
	for port_index in range(view.get_input_port_count()):
		if view.input_pin_for_port(port_index) == pin_id:
			return port_index
	return -1


func _output_port(view: AbilityGraphNodeView, pin_id: String) -> int:
	for port_index in range(view.get_output_port_count()):
		if view.output_pin_for_port(port_index) == pin_id:
			return port_index
	return -1


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		get_viewport().set_input_as_handled()
		_compile()


func _compile() -> void:
	_inspector.compile_graph(_action_registry)


func apply_debug_snapshot(snapshot: Dictionary) -> void:
	_inspector.apply_debug_snapshot(snapshot)


func _on_debug_node_selected(node_id: String) -> void:
	_debug_node_id = node_id
	for view_id: String in _views:
		_views[view_id].modulate = Color.WHITE if view_id != node_id else Color(1.0, 0.82, 0.35, 1.0)
	_apply_debug_connection_activity()
