class_name TownHeroFocus
extends Node2D

signal detail_requested

var _opened := false
var obscured_bottom := 0.0
var _elapsed := 0.266667


func _ready() -> void:
	$Detail/HitArea.pressed.connect(func(): detail_requested.emit())


func configure(catalog) -> void:
	$Ring.texture = catalog.load_resource("hero_focus.ring")
	$Detail/Icon.texture = catalog.load_resource("hero_focus.detail")
	$Detail/LabelBackground.texture = catalog.load_resource("hero_focus.label")


func set_selected(active: bool) -> void:
	$Detail/HitArea.disabled = not active
	if active != _opened:
		_opened = active
		_elapsed = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	visible = _opened or _elapsed < 0.266667
	var viewport_size := get_viewport_rect().size
	position = viewport_size * 0.5 - Vector2(0, obscured_bottom * 0.5)
	scale = Vector2.ONE * minf(viewport_size.x / 720.0, viewport_size.y / 1280.0)
	var ring := clampf(_elapsed / 0.2, 0.0, 1.0)
	var detail := clampf((_elapsed - 0.1) / 0.1, 0.0, 1.0)
	if not _opened:
		ring = 1.0 - ring
		detail = 1.0 - detail
	$Ring.scale = Vector2.ONE * lerpf(0.5, 1.0, ring)
	$Ring.rotation_degrees = lerpf(290.0, 0.0, ring)
	$Ring.modulate.a = ring
	$Detail.scale = Vector2.ONE * detail
	$Detail.modulate.a = detail
