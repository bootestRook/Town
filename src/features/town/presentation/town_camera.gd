class_name TownCamera
extends Camera2D

signal map_clicked(world_point: Vector2)

const WORLD_SIZE := Vector2(6198, 4854)
const MAX_ZOOM := 1.6
const DRAG_THRESHOLD := 15.0
const HERO_OFFSET := Vector2(0, -45)
const FOCUS_ZOOM_STEP := 0.6
const RESTORE_SECONDS := 0.5
var focused := false
var obscured_bottom := 0.0
var _saved_zoom := 0.65
var _restore_from := 0.65
var _restore_elapsed := RESTORE_SECONDS
var _dragging := false
var _moved := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_clamp_view)
	go_to(Vector2(3650, 2385), 0.65)


func screen_to_world(point: Vector2) -> Vector2:
	return position + (point - get_viewport_rect().size * 0.5) / zoom.x


func go_to(point: Vector2, magnification: float = 0.65) -> void:
	_restore_elapsed = RESTORE_SECONDS
	position = point
	zoom = Vector2.ONE * clampf(magnification, minimum_zoom(), MAX_ZOOM)
	_clamp_view()


func minimum_zoom() -> float:
	var size := get_viewport_rect().size
	return maxf(0.4, maxf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y))


func begin_focus(point: Vector2) -> void:
	if not focused:
		if _restore_elapsed >= RESTORE_SECONDS:
			_saved_zoom = zoom.x
		_restore_elapsed = RESTORE_SECONDS
		zoom = Vector2.ONE * minf(_saved_zoom + FOCUS_ZOOM_STEP, MAX_ZOOM)
		focused = true
	follow(point)


func follow(point: Vector2) -> void:
	if focused:
		# Hero positioning in the source bypasses ordinary map bounds.
		position = point + HERO_OFFSET + Vector2(0, obscured_bottom * 0.5 / zoom.x)
		force_update_scroll()


func end_focus() -> void:
	if not focused:
		return
	focused = false
	_restore_from = zoom.x
	_restore_elapsed = 0.0


func _process(delta: float) -> void:
	if _restore_elapsed < RESTORE_SECONDS:
		_restore_elapsed = minf(_restore_elapsed + delta, RESTORE_SECONDS)
		zoom = Vector2.ONE * lerpf(_restore_from, _saved_zoom, _restore_elapsed / RESTORE_SECONDS)
		_clamp_view()


func zoom_at(factor: float, screen_point: Vector2) -> void:
	if focused:
		return
	_restore_elapsed = RESTORE_SECONDS
	var anchor := screen_to_world(screen_point)
	zoom = Vector2.ONE * clampf(zoom.x * factor, minimum_zoom(), MAX_ZOOM)
	position += anchor - screen_to_world(screen_point)
	_clamp_view()


func _clamp_view() -> void:
	zoom = Vector2.ONE * clampf(zoom.x, minimum_zoom(), MAX_ZOOM)
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	if not focused:
		position = position.clamp(half_view, WORLD_SIZE - half_view)
	force_update_scroll()


func _input(event: InputEvent) -> void:
	# Keep the drag captured until the mouse button is released.
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_drag_to(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		if not _moved:
			map_clicked.emit(screen_to_world(event.position))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_moved = false
			_start = event.position
			_last = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / 1.15, event.position)
		get_viewport().set_input_as_handled()


func _drag_to(point: Vector2) -> void:
	if not _moved and point.distance_to(_start) >= DRAG_THRESHOLD:
		_moved = true
	if _moved and not focused:
		position -= (point - _last) / zoom.x
		_clamp_view()
	_last = point


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false


func set_map_input(active: bool) -> void:
	_dragging = false
	set_process_input(active)
	set_process_unhandled_input(active)
