extends Control

signal opened(id: String)
signal located(id: String)
var _id := ""

func _ready() -> void:
	$Open.pressed.connect(func(): opened.emit(_id))
	$Locate.pressed.connect(func(): located.emit(_id))

func configure(hero: Dictionary, catalog, definitions: Dictionary) -> void:
	_id = hero.id
	$Open/Quality.texture = catalog.load_resource("hero_roster.quality_%d" % hero.quality)
	$Open/Portrait.configure(definitions.heroes[hero.definition].appearance,catalog,definitions)
	$Open/Job.texture = catalog.load_resource("hero_roster.job_%d" % hero.job)
	$Open/Element.texture = catalog.load_resource("hero_roster.element_%d" % hero.combat.element)
	$Open/Name.text = hero.name
	$Open/Level.text = "Lv.Max" if hero.level >= hero.max_level else "Lv.%d" % hero.level
	$Locate/Power.text = MainHUD.compact(hero.power)
	var star: Dictionary = definitions.star_display[hero.star]
	for i in 4:
		get_node("Open/Star%d"%i).visible = i < star.count
		get_node("Open/Star%d"%i).texture = catalog.load_resource(star.resource_id)
