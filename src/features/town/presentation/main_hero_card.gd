extends Control

signal opened(id: String)
signal located(id: String)
var hero_id := ""

func _ready() -> void:
	$Open.pressed.connect(func(): opened.emit(hero_id))
	$Locate.pressed.connect(func(): located.emit(hero_id))

func configure(hero: Dictionary, catalog, definitions: Dictionary) -> void:
	hero_id = hero.id
	$Open/Quality.texture = catalog.load_resource("hero_roster.quality_%d" % hero.quality)
	$Open/Portrait.configure(definitions.heroes[hero.definition].appearance, catalog, definitions)
	$Open/Job.texture = catalog.load_resource("hero_roster.job_%d" % hero.job)
	$Open/Element.texture = catalog.load_resource("hero_roster.element_%d" % hero.combat.element)
	$Open/Name.text = hero.name
	$Open/Name.add_theme_font_size_override("font_size", 20 if hero.name.length() > 5 else 23)
	$Open/Level.text = "Lv.Max" if hero.level >= hero.max_level else "Lv.%d" % hero.level
	$Locate/Power.text = MainHUD.compact(hero.power)
	var star: Dictionary = definitions.star_display[hero.star]
	for i in 4:
		var icon := get_node("Open/Stars/Star%d" % i)
		icon.visible = i < star.count
		icon.position.x = (176 - star.count * 40) * 0.5 + i * 40
		icon.texture = catalog.load_resource(star.resource_id)
