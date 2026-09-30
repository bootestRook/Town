extends Control

signal chosen(id: String)
var hero_id := ""

func _ready() -> void:
	$Card.pressed.connect(func(): chosen.emit(hero_id))

func configure(hero: Dictionary, catalog, definitions: Dictionary) -> void:
	hero_id = hero.id
	$Card.configure(hero, catalog, definitions, "dispatch")

func set_selection(selected: bool, blocked: bool, weak: bool) -> void:
	$Selected.visible = selected
	$Warning.visible = weak
	$Card.disabled = blocked
	$Card.modulate = Color(0.45,0.45,0.45,1) if blocked else Color.WHITE
	$Card/Power.add_theme_color_override("font_color", Color("ef4949") if weak else Color.WHITE)
