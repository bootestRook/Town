@tool
extends VBoxContainer

signal status_requested(message: String)
signal debug_node_selected(node_id: String)

@onready var _selected_label: Label = $SelectedNode
@onready var _action_id: LineEdit = $ActionId
@onready var _apply_action: Button = $ApplyAction
@onready var _parameters_json: TextEdit = $ParametersJson
@onready var _apply_parameters: Button = $ApplyParameters
@onready var _comment: LineEdit = $Comment
@onready var _apply_comment: Button = $ApplyComment
@onready var _fields: VBoxContainer = $Fields
@onready var _diagnostics: ItemList = $Diagnostics
@onready var _trace: ItemList = $Trace
@onready var _event_trace: ItemList = $EventTrace

var _controller: RefCounted
var _resource: RefCounted
var _selected_node_id := ""
var _debug_node_id := ""
var _debug_snapshot: Dictionary = {}


func _ready() -> void:
	_apply_action.pressed.connect(_apply_selected_action)
	_apply_parameters.pressed.connect(_apply_selected_parameters)
	_apply_comment.pressed.connect(_apply_selected_comment)
	_trace.item_selected.connect(_on_trace_selected)


func initialize(controller: RefCounted) -> void:
	_controller = controller


func select_node(resource: RefCounted, node_id: String) -> void:
	_resource = resource
	_selected_node_id = node_id
	_update_inspector()


func active_edge() -> Dictionary:
	return _debug_snapshot.get("active_edge", {})


func _set_status(message: String) -> void:
	status_requested.emit(message)


func _update_inspector() -> void:
	if _resource == null or _resource.node_by_id(_selected_node_id) == null:
		_selected_label.text = "No node selected"
		_action_id.text = ""
		_comment.text = ""
		_parameters_json.text = "{}"
		_clear_parameter_fields()
		_action_id.editable = false
		_apply_action.disabled = true
		_apply_parameters.disabled = true
		return
	var node: RefCounted = _resource.node_by_id(_selected_node_id)
	_selected_label.text = "%s\n%s" % [_selected_node_id, node.type_id]
	var selected_descriptor: RefCounted = _controller.descriptor(node.type_id)
	var is_action: bool = selected_descriptor != null and selected_descriptor.operation_kind == "action"
	_action_id.editable = is_action
	_apply_action.disabled = not is_action
	_action_id.text = String(node.parameters.get("action_id", ""))
	_comment.text = _resource.node_comment(_selected_node_id)
	_parameters_json.text = JSON.stringify(node.parameters, "  ")
	_apply_parameters.disabled = false
	_rebuild_parameter_fields(selected_descriptor, node.parameters)


func _apply_selected_action() -> void:
	if _selected_node_id.is_empty():
		return
	var result: String = _controller.edit_action_id(_selected_node_id, _action_id.text.strip_edges())
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _apply_selected_parameters() -> void:
	if _selected_node_id.is_empty():
		return
	var parsed: Variant = JSON.parse_string(_parameters_json.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Parameters must be a JSON object")
		return
	var result: String = _controller.edit_parameters(_selected_node_id, parsed)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _apply_selected_comment() -> void:
	if _selected_node_id.is_empty():
		return
	var result: String = _controller.edit_comment(_selected_node_id, _comment.text)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func _clear_parameter_fields() -> void:
	for child: Node in _fields.get_children():
		child.queue_free()


func _rebuild_parameter_fields(descriptor: RefCounted, parameters: Dictionary) -> void:
	_clear_parameter_fields()
	if descriptor == null:
		return
	for field: Dictionary in descriptor.parameter_fields():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(field.get("label", field.get("field_id", "Field")))
		label.custom_minimum_size = Vector2(90, 0)
		row.add_child(label)
		var control: Control = _create_field_control(field, parameters.get(field.get("field_id", ""), null))
		if control == null:
			continue
		control.set_meta("ability_field_id", String(field.get("field_id", "")))
		row.add_child(control)
		_fields.add_child(row)


func _create_field_control(field: Dictionary, value: Variant) -> Control:
	match String(field.get("type", "string")):
		"number":
			var spin := SpinBox.new()
			spin.min_value = float(field.get("min", -100000.0))
			spin.max_value = float(field.get("max", 100000.0))
			spin.step = float(field.get("step", 0.1))
			spin.value = float(value) if value != null else 0.0
			spin.value_changed.connect(func(next_value: float) -> void: _apply_field_value(spin, next_value))
			return spin
		"bool":
			var check := CheckButton.new()
			check.button_pressed = bool(value)
			check.toggled.connect(func(next_value: bool) -> void: _apply_field_value(check, next_value))
			return check
		"enum":
			var option := OptionButton.new()
			for enum_value: String in field.get("enum_values", []):
				option.add_item(enum_value)
				if enum_value == String(value):
					option.select(option.item_count - 1)
			option.item_selected.connect(func(index: int) -> void: _apply_field_value(option, option.get_item_text(index)))
			return option
		"definition_ref":
			var definition_line := LineEdit.new()
			var definition_kind := String(field.get("definition_kind", "definition"))
			definition_line.placeholder_text = "<%s definition id>" % definition_kind
			definition_line.tooltip_text = "Stable %s Definition ID" % definition_kind
			definition_line.text = String(value) if value != null else ""
			definition_line.text_submitted.connect(func(next_value: String) -> void: _apply_field_value(definition_line, next_value))
			definition_line.focus_exited.connect(func() -> void: _apply_field_value(definition_line, definition_line.text))
			return definition_line
		_:
			var line := LineEdit.new()
			line.text = String(value) if value != null else ""
			line.text_submitted.connect(func(next_value: String) -> void: _apply_field_value(line, next_value))
			line.focus_exited.connect(func() -> void: _apply_field_value(line, line.text))
			return line


func _apply_field_value(control: Control, value: Variant) -> void:
	if _selected_node_id.is_empty() or _resource == null:
		return
	var field_id := String(control.get_meta("ability_field_id", ""))
	if field_id.is_empty():
		return
	var node: RefCounted = _resource.node_by_id(_selected_node_id)
	var parameters: Dictionary = node.parameters.duplicate(true)
	parameters[field_id] = value
	var result: String = _controller.edit_parameters(_selected_node_id, parameters)
	if not result.is_empty():
		_set_status("Edit failed: %s" % result)


func compile_graph(action_registry: RefCounted) -> void:
	_diagnostics.clear()
	if _resource == null:
		_set_status("No graph selected")
		return
	var result: RefCounted = _controller.compile(action_registry)
	if result.accepted:
		_set_status("Compiled %s (%d operations)" % [_resource.graph_id, result.plan.operation_count()])
		_diagnostics.add_item("OK: execution plan is valid")
		return
	var location: String = result.node_id
	if not result.pin_id.is_empty():
		location += ":%s" % result.pin_id
	_diagnostics.add_item("ERROR %s %s" % [result.error_code, location])
	_set_status("Compile failed: %s" % result.error_code)


func apply_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)
	_trace.clear()
	_event_trace.clear()
	for entry: Dictionary in _debug_snapshot.get("trace", []):
		var data: Dictionary = entry.get("data", {})
		_trace.add_item("%03d  %s → %s" % [int(entry.get("sequence", 0)), String(data.get("from_node_id", "")), String(data.get("to_node_id", ""))])
	for entry: Dictionary in _debug_snapshot.get("event_trace", []):
		_event_trace.add_item("%s  tick:%d  %s" % [String(entry.get("event_type", "")), int(entry.get("logical_tick", 0)), String(entry.get("error_code", ""))])
	_debug_node_id = String(snapshot.get("current_node_id", ""))
	_set_status(
		"Run %s / %s / %s%s" % [
			String(snapshot.get("run_id", "")),
			String(snapshot.get("state", "")),
			_debug_node_id,
			(" / wait:%s" % String(snapshot.get("waiting_reason", ""))) if not String(snapshot.get("waiting_reason", "")).is_empty() else "",
		]
	)
	debug_node_selected.emit(_debug_node_id)
	_select_trace_for_node(_debug_node_id)


func _on_trace_selected(index: int) -> void:
	var entries: Array = _debug_snapshot.get("trace", [])
	if index < 0 or index >= entries.size():
		return
	var data: Dictionary = entries[index].get("data", {})
	_debug_node_id = String(data.get("to_node_id", data.get("from_node_id", "")))
	_debug_snapshot["current_node_id"] = _debug_node_id
	debug_node_selected.emit(_debug_node_id)


func _select_trace_for_node(node_id: String) -> void:
	if node_id.is_empty():
		return
	var entries: Array = _debug_snapshot.get("trace", [])
	for index in range(entries.size() - 1, -1, -1):
		var data: Dictionary = entries[index].get("data", {})
		if String(data.get("to_node_id", "")) == node_id or String(data.get("from_node_id", "")) == node_id:
			_trace.select(index)
			return
