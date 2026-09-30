extends Control

var animations: Dictionary = {}
var _catalog
var _visual := ""
var _elapsed := 0.0
var _frames := 1

func configure(catalog, data) -> void:
	_catalog = catalog
	for row: Dictionary in data.rows("town_animations"):
		if row.direction == "front" and row.action == "idle": animations[row.actor] = row

func display(visual: String) -> void:
	if visual == _visual: return
	_visual = visual
	var row: Dictionary = animations[visual]
	$Sprite.texture = _catalog.load_resource(row.resource_id)
	$Sprite.hframes = int(row.columns)
	$Sprite.vframes = int(row.rows)
	$Sprite.scale = Vector2.ONE * minf(735.0 / row.frame_width, 670.0 / row.frame_height)
	_frames = int(row.frames)
	_elapsed = 0.0
	$Sprite.frame = 0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _visual.is_empty(): return
	_elapsed += delta
	$Sprite.frame = int(_elapsed * 30.0) % _frames
