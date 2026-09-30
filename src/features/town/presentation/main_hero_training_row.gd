extends Control

signal detail_requested(kind: String, data: Dictionary)
signal skill_requested(data: Dictionary, anchor: Control)
signal promote(id: String)
var _hero: Dictionary = {}
var _order: Array = []

func _ready() -> void:
	$Card.pressed.connect(func(): detail_requested.emit("hero", {"hero": _hero.id, "order": _order}))
	$Upgrade.pressed.connect(func():
		if _hero.fragments < _hero.fragment_cost: detail_requested.emit("hero_fragment", {"hero": _hero.id})
		else: promote.emit(_hero.id))
	for i in 4:
		get_node("Skill%d" % i).pressed.connect(func():
			var parts := String(_hero.skills).split("|")[i+1].split(";")
			skill_requested.emit({"skill": int(parts[0]), "level": int(parts[1]), "name": _hero.name, "talent": _hero.talent}, get_node("Skill%d" % i)))

func configure(hero: Dictionary, catalog, definitions: Dictionary, order: Array) -> void:
	_hero = hero
	_order = order
	$Card.configure(hero, catalog, definitions, "training")
	$Deployed.visible = hero.deployed
	for i in 4:
		var parts := String(hero.skills).split("|")[i+1].split(";")
		get_node("Skill%d/Art" % i).texture = catalog.load_resource(definitions.skill_art[int(parts[0])])
		var locked := int(parts[1]) <= 0
		get_node("Skill%d/Lock" % i).visible = locked
		for path: String in ["Art", "Corner", "Frame"]:
			get_node("Skill%d/" % i + path).modulate = Color(0.43,0.416,0.416) if locked else Color.WHITE
		get_node("Skill%d/Level" % i).modulate.a = 0.5 if locked else 1.0
		get_node("Skill%d/Level" % i).text = parts[1]
	$Portrait.texture = catalog.load_resource(hero.portrait)
	$Cost.text = "[center][color=%s]%d[/color]/%d[/center]" % ["#36ed38" if hero.fragments >= hero.fragment_cost else "#ff3650", hero.fragments, hero.fragment_cost]
	for path: String in ["Portrait", "Cost", "CostArt", "Upgrade"]: get_node(path).visible = hero.can_star
	$Max.visible = not hero.can_star
