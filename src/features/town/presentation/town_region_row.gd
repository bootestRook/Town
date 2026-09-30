extends Control
signal activate_requested(level: int)
const MONSTER = preload("res://scenes/town/region_monster.tscn")

func configure(stage: Dictionary, members: Array, definitions: Dictionary, catalog, current: int, progress: int, area_open: bool) -> void:
	var unlocked: bool = area_open and progress >= stage.dungeon
	var active: bool = unlocked and stage.level == current
	$Active.visible = active
	$Activated.visible = active
	$Status.visible = active
	$Status.text = "Lv.%d 激活中..." % stage.level
	$Shade.visible = not unlocked
	$Locked.visible = not unlocked
	$Locked.text = "通过地下城%d-%d后解锁" % [int((stage.dungeon - 1) / 30) + 1, (int(stage.dungeon) - 1) % 30 + 1] if area_open else "区域尚未解锁"
	$Activate.visible = unlocked and not active
	$Activate/Level.text = "Lv.%d" % stage.level
	$Activate.pressed.connect(func(): activate_requested.emit(int(stage.level)))
	var entries: Array = []
	for member: Dictionary in members:
		if member.stage == stage.id and member.role == "normal": entries.append({"monster":member.monster,"count":member.count,"elite":false})
	if stage.mutant_chance > 0:
		for member: Dictionary in members:
			if member.stage == stage.id and member.role == "normal": entries.append({"monster":member.monster,"count":1,"elite":true})
	if stage.leader_chance > 0:
		for member: Dictionary in members:
			if member.stage == stage.id and member.role == "leader": entries.append({"monster":member.monster,"count":member.count,"elite":true})
	var gap := 0.0 if entries.size() >= 5 else 40.0
	var width := entries.size() * 105 + (entries.size() - 1) * gap
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var card = MONSTER.instantiate()
		$Monsters.add_child(card)
		card.position.x = (554 - width) * 0.5 + i * (105 + gap)
		card.get_node("Portrait").texture = catalog.load_resource("region.monster_%d" % definitions[entry.monster].source_id)
		card.get_node("Elite").visible = entry.elite
		card.get_node("Count").text = "x%d" % entry.count
