extends Control

# Source-pinned 750x1334 composition. Domain controls summon timing; art only presents it.
signal intent(command: Dictionary)
signal resource_requested(kind: String)
signal dungeon_requested
const Format = preload("res://src/features/town/presentation/life_format.gd")
const REWARD = preload("res://scenes/town/horn_reward.tscn")
var _catalog
var _items: Dictionary = {}
var _reward_items: Dictionary = {}
var _dungeons: Dictionary = {}
var _state: Dictionary = {}
var _level := 1
var _count := 1
var _pending: Dictionary = {}
var _reward_key := ""

func configure(catalog, data) -> void:
	_catalog = catalog
	$Boss.configure(catalog, data)
	for row: Dictionary in data.rows("main_items"): _items[int(row.source_id)] = row
	for row: Dictionary in data.rows("main_horn_items"): _reward_items[int(row.source_id)] = row
	for row: Dictionary in data.rows("main_dungeons"): _dungeons[int(row.source_id)] = row.title.trim_suffix("层")

func _ready() -> void:
	$Upgrade.pressed.connect(func():
		if _state.main.progress.get("dungeon",0) < _state.horn.levels[_state.horn.building_level].dungeon: dungeon_requested.emit()
		else: intent.emit({"type":"upgrade", "building":TownBattleHorn.BUILDING}))
	$Summon.pressed.connect(func(): _request(false))
	$Sweep.pressed.connect(func(): _request(true))
	$Left.pressed.connect(func(): _level = maxi(1, _level - 1); render(_state))
	$Right.pressed.connect(func(): _level = mini(30, _level + 1); render(_state))
	$Five.pressed.connect(func(): _count = 1 if _count == 5 else 5; render(_state))
	$Ten.pressed.connect(func(): _count = 1 if _count == 10 else 10; render(_state))
	$Help.pressed.connect(_help)
	$HelpPanel/Dismiss.pressed.connect(func(): $HelpPanel.hide())
	$Confirm/Dismiss.pressed.connect(func(): $Confirm.hide())
	$Confirm/Cancel.pressed.connect(func(): $Confirm.hide())
	$Confirm/Accept.pressed.connect(func(): $Confirm.hide(); intent.emit(_pending))
	$GoldAdd.pressed.connect(func(): resource_requested.emit("coins"))
	$DiamondAdd.pressed.connect(func(): resource_requested.emit("diamonds"))
	$Info.pressed.connect(func():
		$HelpPanel/Title.text = _state.horn.levels[_level].display_name
		$HelpPanel/Text.text = "生命值：%d\n\n攻击：%d\n\n防御：%d" % [_state.horn.levels[_level].max_hp, _state.horn.levels[_level].attack, _state.horn.levels[_level].defense]
		$HelpPanel.show())

func open(state: Dictionary) -> void:
	_level = state.horn.level if state.horn.phase != "idle" else state.horn.building_level
	$HelpPanel.hide()
	$Confirm.hide()
	render(state)

func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	var h: Dictionary = state.horn
	var active: bool = h.phase != "idle" or h.queue > 0
	if active: _level = h.level
	var boss: Dictionary = h.levels[_level]
	var upgrade: Dictionary = h.levels[h.building_level]
	var gated: bool = state.main.progress.get("dungeon",0) < upgrade.dungeon
	$Title.text = "战斗号角 Lv.%d" % h.building_level
	$Coins.text = Format.money(state.coins)
	$Diamonds.text = Format.money(state.diamonds)
	$Tickets.text = str(h.ticket_count)
	$Cost.text = Format.money(upgrade.cost)
	$Gate.text = "升级条件：通关地下城%s" % _dungeons[int(upgrade.dungeon)] if gated else "已达最高等级"
	$Gate.visible = gated or h.building_level == 30
	$Cost.visible = not gated and h.building_level < 30
	$CostIcon.visible = $Cost.visible
	$CostBar.visible = $Cost.visible
	$Upgrade.visible = h.building_level < 30
	$Upgrade/Text.text = "前往" if gated else "升级"
	$Upgrade.disabled = not gated and state.coins < upgrade.cost
	$Upgrade/Art.modulate = Color(0.5,0.5,0.5) if $Upgrade.disabled else Color.WHITE
	$Boss.display(boss.visual)
	$Hp.text = _number(boss.max_hp)
	$Attack.text = _number(boss.attack)
	$Defense.text = _number(boss.defense)
	$Left.visible = not active and _level > 1
	$Right.visible = not active and _level < 30
	$Five/Check.visible = _count == 5
	$Ten/Check.visible = _count == 10
	for node in [$Five,$Ten,$Sweep]: node.visible = not active
	$Sweep.disabled = _level > h.building_level or h.cooldown > 0
	var pay: Dictionary = h.payment_next
	$Free.text = "免费次数：%d/4" % h.free
	$Summon/Text.text = "中止" if active else ("免费召唤" if pay.kind == "free" else ("召唤 ×1" if pay.kind == "ticket" else "%d钻石召唤" % pay.amount))
	$Summon.disabled = not active and (_level > h.building_level or h.cooldown > 0)
	$Summon/Art.modulate = Color(0.5,0.5,0.5) if $Summon.disabled else Color.WHITE
	$State.text = ("集结中 %d/%d  %d秒" % [h.ready.size(), h.participants.size(), ceili(h.remaining)]) if h.phase == "prepare" else ("战斗中 %d秒" % ceili(h.remaining) if h.phase == "fight" else ("战斗号角lv%d解锁" % _level if _level > h.building_level else ("冷却中 %d秒" % ceili(h.cooldown) if h.cooldown > 0 else "")))
	_rewards(boss.rewards)

func _request(sweep: bool) -> void:
	if _state.horn.phase != "idle" or _state.horn.queue > 0:
		_pending = {"type":"horn", "action":"cancel"}
		$Confirm/Title.text = "结束boss战"
		$Confirm/Text.text = "确定要中止boss战吗？"
		$Confirm.show()
		return
	_pending = {"type":"horn", "action":"summon", "level":_level, "sweep":sweep, "count":_count if sweep else 1}
	intent.emit(_pending)

func confirm(reason: String) -> void:
	_pending = _pending.duplicate()
	_pending.confirmed = true
	$Confirm/Title.text = "提示"
	$Confirm/Text.text = reason
	$Confirm.show()

func _rewards(value: String) -> void:
	if _reward_key == value: return
	_reward_key = value
	for child in $Rewards/Items.get_children(): child.free()
	for entry: String in value.split(";"):
		var pair := entry.split(":")
		var id := int(pair[0])
		var card = REWARD.instantiate()
		$Rewards/Items.add_child(card)
		card.get_node("Icon").texture = _catalog.load_resource(_reward_items[id].resource_id)
		card.get_node("Quality").texture = _catalog.load_resource(("battle_horn." if _reward_items[id].quality == 6 else "operations.") + "quality_" + str(int(_reward_items[id].quality)))
		card.get_node("Chance").text = "%s%%" % Format.number(float(pair[1]) / 100.0)
		card.pressed.connect(func():
			$HelpPanel/Title.text = _items[id].display_name
			$HelpPanel/Text.text = "获得概率：%s%%" % Format.number(float(pair[1]) / 100.0)
			$HelpPanel.show())

func _help() -> void:
	$HelpPanel/Title.text = "战斗号角说明"
	$HelpPanel/Text.text = "1.战斗号角可以召唤BOSS出现在野区,英雄们会前往野区集结,准备挑战BOSS。挑战成功后,BOSS会掉落宝箱,开启宝箱可获得大量奖励。\n\n2.BOSS宝箱只能同时存在一个，召唤新的BOSS时会提示替换尚未开启的宝箱。\n\n3.中止挑战、挑战失败和挑战超时,都会返还本次挑战消耗的材料和次数。\n\n4.免费召唤和材料召唤之间有时间间隔，需要等待倒计时结束。材料召唤只有免费召唤不可使用时才可使用。\n\n5.免费召唤次数每日0点（UTC+8）刷新,未使用的次数不会累计到次日。"
	$HelpPanel.show()

func overlay_open() -> bool:
	return $HelpPanel.visible or $Confirm.visible

static func _number(value: float) -> String:
	return str(roundi(value / 1000.0)) + "k" if value >= 10000 else str(roundi(value))
