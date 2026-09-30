extends Control

signal closed
signal intent(command: Dictionary)
signal detail_requested(kind: String, data: Dictionary)
signal skill_requested(data: Dictionary, anchor: Control)
signal notice(message: String)
const CARD = preload("res://scenes/town/main_hero_library_card.tscn")
const TRAINING_ROW = preload("res://scenes/town/main_hero_training_row.tscn")
const CATEGORIES := ["全部英雄", "卡池", "特殊卡池", "活动"]
var tab := 0
var element := 0
var category := 0
var _catalog
var _definitions: Dictionary = {}
var _state: Dictionary = {}
var _keys := ["", "", ""]

func _ready() -> void:
	$Bottom/Back.pressed.connect(close)
	for i in 3: get_node("Bottom/Tab%d" % i).pressed.connect(func(): select_tab(i))
	for i in 5: get_node("Filters/Filter%d" % i).pressed.connect(func(): element = i; $FormationScroll.scroll_vertical = 0; render(_state))
	for i in 4: get_node("CatalogFilters/Category%d" % i).pressed.connect(func(): category = i; $CatalogScroll.scroll_vertical = 0; render(_state))
	for i in range(1,8): get_node("Training/Category%d" % i).pressed.connect(func(): notice.emit("尚未解锁"))
	for i in 15: get_node("Formation/Slot%d" % i).pressed.connect(func(): _slot(i))
	$Filters/Quick.pressed.connect(func(): intent.emit({"type": "hero_quick_deploy", "element": element}))
	$Header/Coins.pressed.connect(func(): detail_requested.emit("coins", {}))
	$Header/Diamonds.pressed.connect(func(): detail_requested.emit("diamond_store", {}))
	$Header/Help.pressed.connect(func(): detail_requested.emit("management_help", {"page": tab}))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions

func open(page: int, state: Dictionary) -> void:
	_state = state
	element = 0
	category = 0
	for path: String in ["FormationScroll", "TrainingScroll", "CatalogScroll"]: get_node(path).scroll_vertical = 0
	show()
	select_tab(page)

func close() -> void:
	hide()
	closed.emit()

func select_tab(page: int) -> void:
	tab = page
	render(_state)

func resize_page(height: float) -> void:
	size.y = height

func render(state: Dictionary) -> void:
	_state = state
	if not visible or state.is_empty(): return
	$Header/Coins/Value.text = MainHUD.compact(state.coins)
	$Header/Diamonds/Value.text = MainHUD.compact(state.diamonds)
	$Header/Help.visible = tab != 2
	for i in 3:
		var resource := "main_ui.nav_2" if i == 0 else "hero_management.tab_%d" % i
		get_node("Bottom/Tab%d" % i).texture_normal = _catalog.load_resource(resource + ("_selected" if tab == i else ""))
	for path: String in ["Formation", "Filters", "FormationScroll"]: get_node(path).visible = tab == 0
	for path: String in ["Training", "TrainingScroll"]: get_node(path).visible = tab == 1
	for path: String in ["CatalogTitle", "CatalogScroll", "CatalogFilters"]: get_node(path).visible = tab == 2
	$Empty.hide()
	if tab == 0: _formation()
	elif tab == 1: _training()
	else: _library()

func _formation() -> void:
	var team: Array = _state.main.team
	var capacity: int = _state.main.deployment_capacity
	$Formation/Count.text = "[center]已上阵英雄[color=%s]%d[/color]/%d[/center]" % ["#ff3650" if team.size() >= capacity else "#36ed38", team.size(), capacity]
	for i in 15:
		var slot = get_node("Formation/Slot%d" % i)
		slot.get_node("Lock").visible = i >= capacity
		slot.get_node("Add").visible = i < capacity and i >= team.size()
		slot.get_node("Pedestal").modulate.a = 0.3 if i >= capacity else 1.0
		slot.get_node("Unlock").text = "英雄营地Lv%d" % (_state.camp.level + 1) if i == capacity else ""
		slot.get_node("Portrait").visible = i < team.size()
		if i < team.size():
			var hero: Dictionary = _state.main.roster.filter(func(h): return h.id == team[i])[0]
			slot.get_node("Portrait").configure(_definitions.heroes[hero.definition].appearance, _catalog, _definitions)
	for i in 5: get_node("Filters/Filter%d/Selected" % i).visible = element == i
	var heroes: Array = _state.main.roster.filter(func(h): return element == 0 or h.combat.element == element)
	heroes.sort_custom(_power_order)
	_render_cards($FormationScroll/Grid, heroes, 0, "formation")
	$Empty.visible = heroes.is_empty()

func _training() -> void:
	$Training/Count.text = "英雄数量%d" % _state.main.roster.size()
	var heroes: Array = _state.main.roster.duplicate()
	heroes.sort_custom(func(a,b):
		var first: bool = a.can_star and a.fragments >= a.fragment_cost
		var second: bool = b.can_star and b.fragments >= b.fragment_cost
		return first if first != second else _power_order(a,b))
	var order := heroes.map(func(h): return h.id)
	var key := str(order)
	if _keys[1] != key:
		_keys[1] = key
		_clear($TrainingScroll/Rows)
		for hero: Dictionary in heroes:
			var row = TRAINING_ROW.instantiate()
			$TrainingScroll/Rows.add_child(row)
			row.detail_requested.connect(func(kind,data): detail_requested.emit(kind,data))
			row.skill_requested.connect(func(data,anchor): skill_requested.emit(data,anchor))
			row.promote.connect(func(id): intent.emit({"type":"hero_star", "hero":id}))
	for i in heroes.size(): $TrainingScroll/Rows.get_child(i).configure(heroes[i], _catalog, _definitions, order)

func _library() -> void:
	$CatalogTitle.text = CATEGORIES[category]
	for i in 4:
		get_node("CatalogFilters/Category%d/Art" % i).texture = _catalog.load_resource("hero_management.category" + ("_selected" if i == category else ""))
		get_node("CatalogFilters/Category%d/Text" % i).modulate = Color(1,0.94,0.06) if i == category else Color.WHITE
	var heroes: Array = []
	var level: Dictionary = _definitions.recruit_levels[_state.main.recruit_level-1]
	for definition: Dictionary in _definitions.heroes.values():
		if category >= 2: continue # No source membership data for these two screenshot categories.
		if category == 1 and (definition.weight <= 0 or level[["green","blue","purple","gold"][definition.quality-2]] <= 0): continue
		var record: Dictionary = _definitions.hero_catalog[definition.id]
		heroes.append({"id":definition.id, "definition":definition.id, "name":definition.display_name, "quality":definition.quality, "job":definition.job, "combat":{"element":definition.element}, "star":record.star, "rank":record.rank, "owned":_state.main.roster.any(func(h): return h.definition == definition.id)})
	heroes.sort_custom(func(a,b):
		if a.owned != b.owned: return a.owned
		if a.quality != b.quality: return a.quality > b.quality
		return a.rank < b.rank)
	_render_cards($CatalogScroll/Grid, heroes, 2, "catalog")
	$Empty.visible = heroes.is_empty()

func _render_cards(grid: GridContainer, heroes: Array, index: int, mode: String) -> void:
	var key := str(heroes.map(func(h): return h.id))
	if _keys[index] != key:
		_keys[index] = key
		_clear(grid)
		for hero: Dictionary in heroes:
			var card = CARD.instantiate()
			grid.add_child(card)
			card.pressed.connect(func():
				if mode == "formation": intent.emit({"type":"hero_team", "hero":card.hero_id})
				else: detail_requested.emit("catalog_hero", {"definition":card.hero_id}))
	for i in heroes.size(): grid.get_child(i).configure(heroes[i], _catalog, _definitions, mode)

func _slot(index: int) -> void:
	if index < _state.main.team.size(): intent.emit({"type":"hero_team", "hero":_state.main.team[index]})
	elif index >= _state.main.deployment_capacity: notice.emit("英雄营地Lv%d解锁" % (_state.camp.level + index - _state.main.deployment_capacity + 1))

static func _power_order(a: Dictionary, b: Dictionary) -> bool:
	return a.power > b.power if a.power != b.power else a.id.naturalnocasecmp_to(b.id) < 0

static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
