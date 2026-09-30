extends Control

signal closed
signal intent(command: Dictionary)
signal detail_requested(kind: String, data: Dictionary)
const CARD = preload("res://scenes/town/main_card.tscn")
const MODE = preload("res://scenes/town/main_mode_card.tscn")
var route := ""
var mode := "dungeon"
var _catalog
var _definitions: Dictionary
var _state: Dictionary = {}
var _key := ""


func _ready() -> void:
	$Close.pressed.connect(func():
		if route == "gameplay" and mode != "dungeon": mode = "dungeon"; _key = ""; render(_state)
		else: closed.emit())
	$Footer/Primary.pressed.connect(_primary)
	$Footer/Secondary.pressed.connect(_secondary)
	$Battle.intent.connect(func(command): intent.emit(command))



func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions
	$Battle.configure(catalog)


func open(next: String, state: Dictionary) -> void:
	route = next
	mode = "dungeon"
	_key = ""
	$Scroll.scroll_vertical = 0
	show()
	render(state)


func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	var main: Dictionary = state.main
	$Battle.visible = not main.battle.is_empty() and route in ["dungeon", "gameplay"]
	if $Battle.visible:
		mode = main.battle.mode
		$Battle.render(main.battle, main.battle_speed)
	$Title.text = {"gameplay": "玩法", "dungeon": "地下城"}[route]
	$Scroll.offset_top = 136
	$Banner.visible = route == "dungeon"
	if $Banner.visible: $Banner.texture = _catalog.load_resource("main_ui." + "dungeon_bg")
	$Summary.text = ""
	$Footer/FooterText.text = ""
	$Footer/Primary.visible = route != "gameplay" or mode != "dungeon"
	$Footer/Secondary.visible = route != "gameplay" or mode != "dungeon"
	match route:
		"dungeon", "gameplay":
			var progress: int = main.progress.get(mode, 0)
			$Summary.text = _mode_name() if mode != "dungeon" else "地下城  ·  已通过%d关" % progress
			$Footer/FooterText.text = "出战 %d/5" % main.expedition_team.size()
			$Footer/Primary/Text.text = "挑战"
			$Footer/Secondary/Text.text = "队伍"
			if route == "gameplay" and mode == "dungeon": $Summary.text = ""; $Footer/FooterText.text = ""
			if mode == "modes.5":
				$Summary.text = "海底遗迹  ·  打捞体力 %d/100" % main.salvage.power
				$Footer/Primary/Text.text = "打捞记录"
				$Footer/FooterText.text = "正在打捞 %d/3" % main.salvage.jobs.size()
	var sea_states: Array = main.salvage.jobs.values().map(func(job): return job.remaining <= 0)
	var key := route + mode + str(main.roster) + str(main.progress) + str(state.diamonds) + str(main.salvage.jobs.keys()) + str(sea_states) + str(main.daily) + str(main.day)
	if key != _key:
		_key = key
		_rebuild()


func _rebuild() -> void:
	for child in $Scroll/Grid.get_children():
		$Scroll/Grid.remove_child(child)
		child.queue_free()
	$Scroll/Grid.columns = 1 if route == "gameplay" and mode == "dungeon" else 3
	match route:
		"gameplay":
			if mode == "dungeon":
				for definition: Dictionary in _definitions.modes:
					var card = MODE.instantiate()
					$Scroll/Grid.add_child(card)
					card.get_node("Art").texture = _catalog.load_resource(definition.resource_id)
					card.get_node("Title").text = definition.display_name
					card.get_node("Detail").text = "已通关 %d" % _state.main.progress.get(definition.id, 0)
					card.pressed.connect(func(): mode = definition.id; _key = ""; render(_state))
			elif mode == "modes.5":
				for site: Dictionary in _definitions.sea:
					var job: Dictionary = _state.main.salvage.jobs.get(site.id, {})
					var status: String = "%d体力" % site.cost if job.is_empty() else "可领取" if job.remaining <= 0 else "打捞中"
					_add_card(site.display_name, status, site.resource_id, func(): detail_requested.emit("sea", {"site": site.id}))
			else: _level_cards()
		"dungeon": _level_cards()



func _level_cards() -> void:
	var progress: int = _state.main.progress.get(mode, 0)
	var start := maxi(0, progress - 2)
	var levels: Array = _definitions.encounters[mode]
	for i in range(start, mini(start + 12, levels.size())):
		var level: Dictionary = levels[i]
		var status := "已通过" if i < progress else "挑战" if i == progress else "未解锁"
		var portrait: String = _definitions.enemies[String(level.enemies).split(";")[0]].resource_id
		_add_card("第%d关" % (i + 1), status, portrait, func():
			if i == progress: detail_requested.emit("stage", {"mode": mode, "level": i})
			else: detail_requested.emit("stage_info", {"mode": mode, "level": i}))


func _add_card(title: String, detail: String, portrait: String, callback: Callable, backing: String = "") -> void:
	var card = CARD.instantiate()
	$Scroll/Grid.add_child(card)
	card.get_node("Title").text = title
	card.get_node("Detail").text = detail
	card.get_node("Portrait").texture = _catalog.load_resource(portrait)
	if not backing.is_empty(): card.get_node("Art").texture = _catalog.load_resource(backing)
	card.pressed.connect(callback)


func _primary() -> void:
	match route:
		"gameplay", "dungeon":
			if mode == "modes.5": detail_requested.emit("sea_records", {})
			elif _state.main.progress.get(mode, 0) >= _definitions.encounters[mode].size(): detail_requested.emit("completed", {})
			else: detail_requested.emit("stage", {"mode": mode, "level": _state.main.progress.get(mode, 0)})


func _secondary() -> void:
	match route:
		"gameplay", "dungeon": detail_requested.emit("team", {})


func _mode_name() -> String:
	for row: Dictionary in _definitions.modes:
		if row.id == mode: return row.display_name
	return "玩法"


func action_result(command: Dictionary, result: Dictionary) -> void:
	if result.accepted and command.type == "battle_start":
		mode = command.get("mode", "dungeon")
