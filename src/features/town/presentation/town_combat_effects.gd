extends Node2D

var _definitions: Dictionary = {}
var _textures: Dictionary = {}
var _effects: Array = []
var _projectiles: Array = []


func configure(data, catalog) -> void:
	for row: Dictionary in data.rows("town_effects"):
		_definitions[row.id] = row
		_textures[row.id] = catalog.load_resource(row.resource_id)


func render(effects: Array, projectiles: Array) -> void:
	_effects = effects
	_projectiles = projectiles
	queue_redraw()


func _draw() -> void:
	for effect: Dictionary in _effects:
		var definition: Dictionary = _definitions[effect.resource]
		var frame := mini(int(effect.elapsed / definition.seconds * definition.frames), definition.frames - 1)
		_draw_frame(effect.resource, effect.position, frame, 0.0, effect.flip)
	for projectile: Dictionary in _projectiles:
		var definition: Dictionary = _definitions[projectile.resource]
		_draw_frame(projectile.resource, projectile.position, 0, projectile.get("angle", 0.0) + deg_to_rad(definition.rotation), false)
	draw_set_transform(Vector2.ZERO)


func _draw_frame(id: String, point: Vector2, frame: int, angle: float, flip: bool) -> void:
	var definition: Dictionary = _definitions[id]
	var texture: Texture2D = _textures[id]
	var size := Vector2(texture.get_width() / float(definition.columns), texture.get_height() / float(definition.rows))
	draw_set_transform(point, angle, Vector2(-1 if flip else 1, 1) * definition.scale)
	draw_texture_rect_region(texture, Rect2(-size * 0.5, size), Rect2(Vector2((frame % int(definition.columns)) * size.x, (frame / int(definition.columns)) * size.y), size))
