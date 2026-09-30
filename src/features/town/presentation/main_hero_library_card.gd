extends Button

var hero_id := ""

func configure(hero: Dictionary, catalog, definitions: Dictionary, mode: String) -> void:
	hero_id = hero.id
	var library := mode == "catalog"
	$Quality.texture = catalog.load_resource("hero_roster.quality_%d" % hero.quality)
	$Portrait.configure(definitions.heroes[hero.definition].appearance, catalog, definitions)
	$Job.texture = catalog.load_resource("hero_roster.job_%d" % hero.job)
	$Job.position.y = 6 if library else 34
	$Element.texture = catalog.load_resource("hero_roster.element_%d" % hero.combat.element)
	$Name.text = hero.name
	$Name.position.y = 3 if library else 139
	$Name.add_theme_font_size_override("font_size", 18 if hero.name.length() > 5 else 22)
	$Level.visible = not library
	$Rank.visible = not library
	$PowerArt.visible = not library
	$PowerIcon.visible = not library
	$Power.visible = not library
	if not library:
		$Level.text = "Lv.Max" if hero.level >= hero.max_level else "Lv.%d" % hero.level
		$Power.text = str(hero.power)
	$Shade.visible = (not hero.owned if library else hero.deployed and mode == "formation")
	$Check.visible = mode == "formation" and hero.deployed
	var star: Dictionary = definitions.star_display[hero.star]
	for i in 4:
		var icon = get_node("Star%d" % i)
		icon.visible = i < star.count
		icon.position = Vector2((165 - star.count * 33) * 0.5 + i * 33, 146) if library else Vector2(130, 130-i*25)
		icon.texture = catalog.load_resource(star.resource_id)
