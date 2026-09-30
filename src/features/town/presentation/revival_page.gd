extends Control

const HeroScene = preload("res://scenes/town/hero_row.tscn")
var _catalog


func configure(catalog) -> void:
	_catalog = catalog


func render(state: Dictionary) -> void:
	$Capacity.text = "席位 %d    复活时间 %d秒    恢复生命 %d%%" % [state.revival.seats, state.revival.seconds, state.revival.hp]
	if $Scroll/Rows.get_child_count() == 0:
		for hero: Dictionary in state.heroes:
			var row = HeroScene.instantiate()
			$Scroll/Rows.add_child(row)
			row.get_node("Portrait").texture = _catalog.load_resource("heroes.%s_portrait" % hero.visual)
			row.get_node("Name").text = hero.name
			row.get_node("Summon").hide()
	for i in state.heroes.size():
		var hero: Dictionary = state.heroes[i]
		var row = $Scroll/Rows.get_child(i)
		row.get_node("State").text = "复活中 · 剩余 %d秒" % ceili(hero.timer) if hero.mode == "reviving" else (hero.reason if hero.needs.hp <= 0 else "生命 %d%%" % hero.needs.hp)
		row.get_node("Bag").text = "" if hero.needs.hp <= 0 else "无需复活"
