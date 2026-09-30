extends Control

signal intent(command: Dictionary)
signal resource_requested(kind: String)
const Format = preload("res://src/features/town/presentation/life_format.gd")

func _ready() -> void:
	$Upgrade.pressed.connect(func(): intent.emit({"type": "upgrade", "building": TownHeroCamp.BUILDING}))
	$Help.pressed.connect(func(): $HelpPanel.show())
	$HelpPanel/Dismiss.pressed.connect(func(): $HelpPanel.hide())
	$GoldAdd.pressed.connect(func(): resource_requested.emit("coins"))
	$DiamondAdd.pressed.connect(func(): resource_requested.emit("diamonds"))
	$HelpPanel/Text.text = "1.英雄营地是容纳英雄们在小镇中同时进行活动的地方,随着营地的升级,小镇可同时容纳英雄的位置越多,营地升至满级时可容纳15名英雄同时活动。\n\n2.当营地没有多余位置的时候,除了指定可活动的英雄外,其余英雄只能处于待机状态。"

func open(state: Dictionary) -> void:
	$HelpPanel.hide()
	render(state)

func render(state: Dictionary) -> void:
	if not visible: return
	var camp: Dictionary = state.camp
	$Title.text = "英雄营地 Lv.%d" % camp.level
	$Coins.text = Format.money(state.coins)
	$Diamonds.text = Format.money(state.diamonds)
	$Capacity.text = "[center][color=#34cd3f]%d[/color][color=#c3d2d4]/%d[/color][/center]" % [camp.deployed, camp.capacity]
	$Cost.text = Format.money(camp.cost)
	$Cost.add_theme_color_override("font_color", Color("c3d2d4") if camp.affordable else Color("d23d22"))
	for node in [$Cost, $CostIcon, $Upgrade]: node.visible = not camp.max_level
	$Upgrade.disabled = not camp.affordable
	$Upgrade/Art.modulate = Color.WHITE if camp.affordable else Color(0.5,0.5,0.5)
	$Max.visible = camp.max_level
	$Preview.visible = not camp.preview.is_empty()
	for i in 2:
		var row = get_node("Preview/Row%d" % i)
		row.visible = i < camp.preview.size()
		if row.visible:
			row.get_node("Level").text = str(camp.preview[i].level)
			row.get_node("Before").text = str(camp.preview[i].before)
			row.get_node("After").text = str(camp.preview[i].after)

func overlay_open() -> bool:
	return $HelpPanel.visible
