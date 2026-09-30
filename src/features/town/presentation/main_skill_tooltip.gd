extends Control

var _catalog
var _definitions: Dictionary = {}
var _anchor: Control
var _anchor_rect := Rect2()


func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions


func toggle(data: Dictionary, anchor: Control) -> void:
	if visible and _anchor == anchor:
		hide()
		return
	_anchor = anchor
	_anchor_rect = anchor.get_global_rect()
	var skill: Dictionary = _definitions.skills[data.skill]
	$Icon/Art.texture = _catalog.load_resource(_definitions.skill_art[data.skill])
	$Icon/Level.text = str(data.level)
	$Icon/Lock.visible = data.level <= 0
	for path: String in ["Art", "Corner", "Frame"]:
		get_node("Icon/" + path).modulate = Color(0.43,0.416,0.416) if data.level <= 0 else Color.WHITE
	$Icon/Level.modulate.a = 0.5 if data.level <= 0 else 1.0
	$Title.text = skill.display_name
	$Type.text = "CD:%sS" % str(skill.cooldown).trim_suffix(".0") if skill.category == "active" else ("buff" if skill.category == "buff" else "被动")
	$Text.text = MainHeroSkillText.description(skill.description, data.name, data.level)
	var star := MainHeroSkillText.unlock_star(data.skill, data.talent, _definitions.hero_talents) if data.level <= 0 else 0
	$Unlock.text = "（%d星解锁）" % star if star > 0 else ""
	$Unlock.visible = star > 0
	$Text.position.y = 90 if star > 0 else 54
	show()
	_place()
	call_deferred("_place")


func _place() -> void:
	if not visible: return
	var anchor_position: Vector2 = get_parent().get_global_transform().affine_inverse() * _anchor_rect.position
	var height := maxf(132, $Text.position.y + $Text.get_content_height() + 20)
	size.y = height
	$Text.size.y = height - $Text.position.y - 16
	position = Vector2(30, anchor_position.y - height - 12)
	if position.y < 64:
		position.y = anchor_position.y + _anchor_rect.size.y / get_parent().scale.y + 12
	position.y = clampf(position.y, 64, get_parent().size.y - 110 - height)


func _process(_delta: float) -> void:
	if not visible: return
	if not is_instance_valid(_anchor) or not _anchor.is_visible_in_tree() or _anchor.get_global_rect() != _anchor_rect:
		hide()


func _input(event: InputEvent) -> void:
	if not visible: return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if not get_global_rect().has_point(event.position) and not _anchor_rect.has_point(event.position): hide()
