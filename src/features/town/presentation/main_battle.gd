extends Control

signal intent(command: Dictionary)
var _catalog

func _ready() -> void:
	$Footer/Back.pressed.connect(func(): intent.emit({"type": "battle_close"}))
	$Footer/Speed.pressed.connect(func(): intent.emit({"type": "battle_speed"}))
	$Footer/Claim.pressed.connect(func(): intent.emit({"type": "battle_claim"}))

func configure(catalog) -> void:
	_catalog = catalog

func render(battle: Dictionary, speed: int) -> void:
	$Title.text = battle.title
	$Time.text = "%02d:%02d" % [int(battle.elapsed) / 60, int(battle.elapsed) % 60]
	$Result.text = {"fighting": "战斗中", "won": "胜利", "lost": "失败"}[battle.status]
	if battle.preparation > 0:
		$Time.text = "召唤准备 %d秒" % ceili(battle.preparation)
		$Result.text = "召唤中"
	$Footer/Back/Text.text = "撤退" if battle.status == "fighting" else "返回"
	$Footer/Speed/Text.text = "二倍速" if speed == 2 else "一倍速"
	$Footer/Claim.visible = battle.status == "won" and not battle.claimed
	$Log.text = "\n".join(battle.log.slice(0, 5))
	for group: String in ["Allies", "Enemies"]:
		var rows: Array = battle.allies if group == "Allies" else battle.enemies
		if rows.size() > 5:
			var living := rows.filter(func(h): return h.hp > 0)
			rows = living if not living.is_empty() else rows.slice(-5)
		for i in range(5):
			var unit := get_node("%s/Unit%d" % [group, i])
			unit.visible = i < rows.size()
			if i >= rows.size(): continue
			var row: Dictionary = rows[i]
			unit.get_node("Portrait").texture = _catalog.load_resource(row.portrait)
			unit.get_node("Name").text = row.name
			unit.get_node("HP").max_value = row.max_hp
			unit.get_node("HP").value = row.hp
			unit.get_node("Value").text = "%d/%d" % [ceili(row.hp), ceili(row.max_hp)]
			unit.modulate = Color.WHITE if row.hp > 0 else Color(0.4,0.4,0.4,1)
