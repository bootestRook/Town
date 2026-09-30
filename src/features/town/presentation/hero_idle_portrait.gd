extends TextureRect

# A sampled source Spine loop; presentation time never consumes gameplay RNG.
var _appearance := -1
var _definition: Dictionary = {}
var _elapsed := 0.0
var frame := 0
var _catalog
var _clip: ScrollContainer

func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: _clip = ancestor; break
		ancestor = ancestor.get_parent()

func configure(appearance: int, catalog, definitions: Dictionary) -> void:
	if appearance == _appearance: return
	_appearance = appearance
	_definition = definitions.hero_idle[appearance]
	_catalog = catalog
	_elapsed = 0.0
	frame = 0
	texture = null

func _process(delta: float) -> void:
	if _definition.is_empty() or not is_visible_in_tree(): return
	if _clip != null and not get_global_rect().intersects(_clip.get_global_rect()): return
	if texture == null:
		var atlas := AtlasTexture.new()
		atlas.atlas = _catalog.load_resource(_definition.resource_id)
		atlas.region = Rect2(0, 0, 256, 256)
		texture = atlas
	_elapsed = fmod(_elapsed + delta, _definition.duration)
	var next := int(_elapsed / _definition.duration * _definition.frames)
	if next == frame: return
	frame = next
	texture.region = Rect2((frame % int(_definition.columns)) * 256, (frame / int(_definition.columns)) * 256, 256, 256)
