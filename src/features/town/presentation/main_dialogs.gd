extends Control

signal intent(command: Dictionary)
signal closed
signal hero_requested(data: Dictionary)
signal equipment_requested(data: Dictionary)
signal skill_requested(data: Dictionary, anchor: Control)
const ROW = preload("res://scenes/town/main_action_row.tscn")
var kind := ""
var _data: Dictionary = {}
var _state: Dictionary = {}
var _definitions: Dictionary = {}
var _catalog
var _commands: Dictionary = {}
var _confirm: Dictionary = {}
var _list_key := ""
var _history: Array = []


func _ready() -> void:
	$Panel/Close.pressed.connect(close)
	for name: String in ["Action", "Alternate", "Third", "Fourth"]:
		get_node("Panel/" + name).pressed.connect(func(): _action(name))
	$Confirm/Cancel.pressed.connect(func(): $Confirm.hide())
	$Confirm/Accept.pressed.connect(func():
		var command := _confirm.duplicate(true)
		_confirm.clear()
		$Confirm.hide()
		intent.emit(command))


func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions


func open(next: String, data: Dictionary, state: Dictionary) -> void:
	_history.clear()
	_show(next, data, state)


func _show(next: String, data: Dictionary, state: Dictionary) -> void:
	kind = next
	_data = data.duplicate(true)
	_list_key = ""
	$Confirm.hide()
	$Panel/NameInput.text = "" if next == "hero_donate" else state.main.player_name
	$Panel/NameInput.placeholder_text = "输入赠送金币数量" if next == "hero_donate" else "输入名字"
	show()
	render(state)


func close() -> void:
	if $Confirm.visible:
		$Confirm.hide()
		return
	if not _history.is_empty():
		var previous: Dictionary = _history.pop_back()
		_show(previous.kind, previous.data, _state)
		return
	hide()
	closed.emit()


func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	var main: Dictionary = state.main
	_commands.clear()
	for name: String in ["Action", "Alternate", "Third", "Fourth"]: get_node("Panel/" + name).hide()
	$Panel/NameInput.visible = kind in ["profile", "hero_donate"]
	$Panel/Text.position.y = 374 if kind in ["profile", "hero_donate"] else 316
	$Panel/Text.size.y = 136 if kind in ["profile", "hero_donate"] else 205
	if kind == "collection" and not main.collections.any(func(o): return o.id == _data.object): close(); return
	$Panel/Portrait.visible = kind in ["profile", "coins", "energy"]
	var rows: Array = []
	match kind:
		"profile":
			$Panel/Title.text = "个人信息"
			$Panel/Portrait.texture = _catalog.load_resource(main.avatar)
			$Panel/Text.text = "总战力 %s\n主城等级 %d\n拥有英雄 %d" % [MainHUD.compact(main.power), state.city_level, main.roster.size()]
			_button("Action", "修改名字", {"type": "profile_name"})
			_button("Alternate", "声音：" + ("开启" if main.sound else "关闭"), {"type": "profile_sound"})
			for hero: Dictionary in main.roster: rows.append({"text": "头像 · " + hero.name, "command": {"type": "profile_avatar", "hero": hero.definition}})
		"coins", "energy":
			var offer: Dictionary = main.coin_offer if kind == "coins" else main.energy_offer
			$Panel/Title.text = "金币补充" if kind == "coins" else "净化之力"
			$Panel/Portrait.texture = _catalog.load_resource("operations.coin" if kind == "coins" else "main_ui.energy")
			$Panel/Text.text = "当前 %s\n钻石补充 +%s\n今日剩余 %d/%d 次" % [MainHUD.compact(state.coins) if kind == "coins" else "%d/%d" % [main.energy, main.energy_max], MainHUD.compact(offer.amount), maxi(0, offer.limit - main.daily.get(kind, 0)), offer.limit]
			_button("Action", "%d钻石领取" % offer.cost, {"type": "resource_buy", "resource": kind})
			_button("Alternate", "模拟观看并领取" if kind == "coins" else "领取赠送", {"type": "resource_free", "resource": kind})
			rows.append({"text": "免费剩余 %d/%d 次" % [maxi(0, offer.free_limit - main.daily.get("coin_ads", 0)), offer.free_limit] if kind == "coins" else "每日 8点、12点、18点赠送", "command": {}})
		"team":
			$Panel/Title.text = "出战队伍"
			$Panel/Text.text = "已出战 %d/5" % main.expedition_team.size()
			var order: Array = main.roster.map(func(h): return h.id)
			for hero: Dictionary in main.roster:
				rows.append({"text": hero.name + "  战力 " + MainHUD.compact(hero.power), "command": {"type": "view", "kind": "hero", "hero": hero.id, "order": order}, "toggle": {"type": "expedition_team", "hero": hero.id}, "status": "下阵" if hero.id in main.expedition_team else "出战"})
		"stage", "stage_info":
			var level: Dictionary = _definitions.encounters[_data.mode][int(_data.level)]
			$Panel/Title.text = "第%d关" % (int(_data.level) + 1)
			$Panel/Text.text = "%s\n消耗净化之力 %d\n首通奖励：%s" % [level.title, level.cost, _reward_text(level.rewards)]
			if _definitions.battle_gates.has(level.id):
				var gate: Dictionary = _definitions.battle_gates[level.id]
				$Panel/Text.text = "%s\n召唤消耗：%s\n地下城通过 %d/%d关\n召唤准备 %d秒" % [level.title,_reward_text(gate.cost),main.progress.get("dungeon",0),gate.dungeon,gate.preparation]
			for id: String in String(level.enemies).split(";"):
				var enemy: Dictionary = _definitions.enemies[id]
				rows.append({"text": "%s · 生命%s · 攻击%s" % [enemy.display_name, MainHUD.compact(enemy.hp), MainHUD.compact(enemy.attack)], "command": {}})
			for hero: Dictionary in main.roster:
				if hero.id in main.expedition_team: rows.append({"text": hero.name + "  战力 " + MainHUD.compact(hero.power), "command": {}})
			if kind == "stage": _button("Action", "开始战斗", {"type": "battle_start", "mode": _data.mode})
		"orders":
			$Panel/Title.text = "购买记录"
			$Panel/Text.text = "暂无记录" if main.orders.is_empty() else "本地演示订单"
			for order: Dictionary in main.orders: rows.append({"text": "%d  %s  ¥%d" % [order.number, order.product, order.price], "command": {}})
		_:
			var view: Dictionary
			if kind.begins_with("hero_"): view = MainHeroInfoContent.build(kind, _data, state, _definitions)
			elif kind.begins_with("collection") or kind in ["item", "gift"]: view = MainCollectionContent.build(kind, _data, state, _definitions)
			else: view = MainDetailContent.build(kind, _data, state, _definitions)
			$Panel/Title.text = view.title
			$Panel/Text.text = view.text
			$Panel/Portrait.visible = not view.portrait.is_empty()
			if $Panel/Portrait.visible: $Panel/Portrait.texture = _catalog.load_resource(view.portrait)
			rows = view.rows
			for i in view.buttons.size(): _button(["Action", "Alternate", "Third", "Fourth"][i], view.buttons[i][0], view.buttons[i][1])
	var key := str(rows)
	if key != _list_key:
		_list_key = key
		for child in $Panel/Scroll/Rows.get_children():
			$Panel/Scroll/Rows.remove_child(child)
			child.queue_free()
		for row: Dictionary in rows:
			var item = ROW.instantiate()
			$Panel/Scroll/Rows.add_child(item)
			item.get_node("Text").text = row.text
			item.disabled = row.command.is_empty()
			item.pressed.connect(func(): _send(row.command, item))
			if row.has("toggle"):
				item.get_node("Text").size.x = 442
				item.get_node("Toggle").show()
				item.get_node("Toggle/Text").text = row.status
				item.get_node("Toggle").pressed.connect(func(): _send(row.toggle))


func _button(name: String, text: String, command: Dictionary) -> void:
	_commands[name] = command
	get_node("Panel/" + name).show()
	get_node("Panel/" + name + "/Text").text = text


func _action(name: String) -> void:
	if not _commands.has(name): return
	var command: Dictionary = _commands[name].duplicate(true)
	if command.type == "profile_name": command["value"] = $Panel/NameInput.text
	if command.type == "hero_donate": command["amount"] = $Panel/NameInput.text
	_send(command, get_node("Panel/" + name))


func _send(command: Dictionary, anchor: Control = null) -> void:
	if command.type == "view":
		if command.kind == "skill":
			skill_requested.emit(command, anchor)
			return
		if command.kind == "equipment_detail":
			equipment_requested.emit(command)
			return
		if command.kind == "hero":
			hero_requested.emit(command)
			return
		_history.append({"kind": kind, "data": _data.duplicate(true)})
		_show(command.kind, command, _state)
	elif command.type in ["gift_buy", "hero_release", "collection_dismantle", "collection_reset"]:
		_confirm = command
		$Confirm/Text.text = {"gift_buy": "确认领取此商品？\n付费商品为演示购买，不会真实扣款。", "hero_release": "确认遣散这名英雄？\n装备返还仓库，英雄转为灵魂石。", "collection_dismantle": "确认分解？\n返还升级材料，并获得分解材料。", "collection_reset": "确认重置到一级？\n返还升级材料，保留星级和品质。"}[command.type]
		$Confirm.show()
	else: intent.emit(command)


func action_result(command: Dictionary, result: Dictionary) -> void:
	if result.accepted and command.type in ["battle_start", "gift_buy"]:
		hide()
		closed.emit()


func _reward_text(value: String) -> String:
	return MainDetailContent.reward_text(value, _definitions.items)


func view_context() -> Dictionary:
	return {"kind": kind, "data": _data.duplicate(true), "history": _history.duplicate(true)}


func restore_context(context: Dictionary, state: Dictionary) -> void:
	_history = context.history.duplicate(true)
	_show(context.kind, context.data, state)
