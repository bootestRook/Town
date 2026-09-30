extends Control

signal closed
signal detail_requested(kind: String, data: Dictionary)
signal skill_requested(data: Dictionary, anchor: Control)
signal intent(command: Dictionary)
const ROW = preload("res://scenes/town/main_action_row.tscn")
const NEEDS := ["magic", "energy", "tired", "mood"]
const TITLES := ["魔气缠身", "饥饿", "疲劳", "心情"]
const DESCRIPTIONS := ["净化之力会自动消耗,以驱散英雄感染的魔气", "英雄攻击或者释放技能会消耗饥饿值,为0时无法狩猎,前往餐馆吃饭可以恢复", "英雄会持续不断的降低疲劳,为0时无法狩猎,前往旅馆睡觉可以恢复", "英雄被攻击时会降低心情值,为0时攻击将下降10%,前往酒吧消费可以恢复"]
const COLORS := [Color.WHITE, Color.WHITE, Color(0.165,0.8,0.275), Color(0.125,0.588,0.812), Color(0.878,0.373,0.878), Color(0.992,0.447,0.231)]
var hero_id := ""
var tab := 0
var _order: Array = []
var _state: Dictionary = {}
var _definitions: Dictionary = {}
var _hero: Dictionary = {}
var _catalog
var _tooltip := -1
var _rows_key := ""


func _ready() -> void:
	$Bottom/Back.pressed.connect(close)
	$Change.pressed.connect(func(): _detail("hero_management", {"page": 0}))
	$Header/Coins.pressed.connect(func(): _detail("coins"))
	$Header/Diamonds.pressed.connect(func(): _detail("diamond_store"))
	$Wallet.pressed.connect(func(): _detail("hero_donate"))
	$Rank.pressed.connect(func(): _detail("hero_rank"))
	$Element.pressed.connect(func(): _detail("hero_element"))
	$Attributes/Info.pressed.connect(func(): _detail("hero_attributes"))
	$EquipmentSettings.pressed.connect(func(): _detail("hero_equipment"))
	$Previous.pressed.connect(func(): _adjacent(-1))
	$Next.pressed.connect(func(): _adjacent(1))
	$AttributePage/Promotion/Upgrade.pressed.connect(func(): _hide_tip(); intent.emit({"type": "hero_star", "hero": hero_id}))
	for slot: int in [1,2,4,7,6,8]:
		get_node("Slot%d" % slot).pressed.connect(func():
			if _hero.equipment.has(str(slot)): _detail("equipment_detail", {"slot": slot, "serial": _hero.equipment[str(slot)].serial})
			else: _detail("hero_equipment", {"slot": slot}))
	$BagPage.item_requested.connect(func(id): _detail("hero_bag_item", {"item": id}))
	for i in 4:
		get_node("Status%d" % i).pressed.connect(func(): _tooltip = -1 if _tooltip == i else i; _render_tip())
		get_node("Bottom/Tab%d" % i).pressed.connect(func(): tab = i; _rows_key = ""; _hide_tip(); render(_state))
		get_node("AttributePage/Skill%d" % i).pressed.connect(func(): _skill(i))
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: _hide_tip())


func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions


func open(data: Dictionary, state: Dictionary) -> void:
	hero_id = data.hero
	_order = data.order.duplicate()
	tab = 0
	_rows_key = ""
	_hide_tip()
	show()
	render(state)


func close() -> void:
	_hide_tip()
	hide()
	closed.emit()


func resize_page(height: float) -> void:
	size.y = height
	$AttributePage.size.y = height - 833
	$AttributePage/Promotion.position.y = height - 1100
	$CollectionPage.size.y = height - 833
	$BagPage.size.y = height - 822
	$ContentBackground.size.y = height - 719


func render(state: Dictionary) -> void:
	_state = state
	if not visible: return
	var found: Array = state.main.roster.filter(func(h): return h.id == hero_id)
	if found.is_empty(): close(); return
	_hero = found[0]
	_order = _order.filter(func(id): return state.main.roster.any(func(h): return h.id == id))
	var definition: Dictionary = _definitions.heroes[_hero.definition]
	$Name.text = _hero.name
	$Level.text = "Lv.%d" % _hero.level
	$Name.modulate = COLORS[_hero.quality]
	$Level.modulate = COLORS[_hero.quality]
	$PortraitArea/Background.texture = _catalog.load_resource("hero_detail.background_%d" % _hero.quality)
	$PortraitArea/Portrait.configure(definition.appearance, _catalog, _definitions)
	$Element/Art.texture = _catalog.load_resource("hero_roster.element_%d" % definition.element)
	$Header/Coins/Value.text = MainHUD.compact(state.coins)
	$Header/Diamonds/Value.text = MainHUD.compact(state.diamonds)
	$Wallet/Value.text = MainHUD.compact(_hero.wallet)
	$Power/Value.text = str(_hero.power)
	$Previous.visible = _order.find(hero_id) > 0
	$Next.visible = _order.find(hero_id) < _order.size() - 1
	for key: String in ["hp", "attack", "defense"]:
		get_node("Attributes/"+key+"/Value").text = MainHUD.compact(_hero.stats["max_hp" if key == "hp" else key])
	for i in 4:
		var label = get_node("Status%d/Value" % i)
		label.text = "—" if _hero.needs.is_empty() else str(int(_hero.needs[NEEDS[i]])) + ("%" if i > 0 else "")
		label.modulate = Color(1,0.15,0.2) if not _hero.needs.is_empty() and _hero.needs[NEEDS[i]] <= 0 else Color(0.15,1,0.08)
		get_node("Bottom/Tab%d" % i).texture_normal = _catalog.load_resource("hero_detail.tab_%d%s" % [i, "_selected" if tab == i else ""])
	_render_equipment()
	$AttributePage.visible = tab == 0
	$CollectionPage.visible = tab in [1,2]
	$BagPage.visible = tab == 3
	if tab == 0: _render_attributes()
	elif tab == 3: $BagPage.render(_hero, _catalog, _definitions)
	else: _render_collection()
	_render_tip()


func _render_equipment() -> void:
	for slot: int in [1,2,4,7,6,8]:
		var empty: int = {1: _hero.job, 2:4, 4:5, 7:6, 6:7, 8:8}[slot]
		var resource := "hero_detail.empty_%d" % empty
		var equipped: bool = _hero.equipment.has(str(slot))
		get_node("Slot%d/Frame" % slot).visible = equipped
		if equipped:
			var item: Dictionary = _hero.equipment[str(slot)]
			resource = item.resource_id
			get_node("Slot%d/Frame" % slot).texture = _catalog.load_resource("operations.quality_%d" % item.quality)
		get_node("Slot%d/Art" % slot).position = Vector2(7,7) if equipped else Vector2.ZERO
		get_node("Slot%d/Art" % slot).size = Vector2(84,84) if equipped else Vector2(98,98)
		if slot == 8:
			var artifacts: Array = _state.main.collections.filter(func(o): return o.kind == "artifact" and o.hero == hero_id)
			if not artifacts.is_empty(): resource = artifacts[0].portrait
		get_node("Slot%d/Art" % slot).texture = _catalog.load_resource(resource)


func _render_attributes() -> void:
	var skills := String(_hero.skills).split("|")
	for i in 4:
		var parts := skills[i+1].split(";")
		get_node("AttributePage/Skill%d/Art" % i).texture = _catalog.load_resource(_definitions.skill_art[int(parts[0])])
		get_node("AttributePage/Skill%d/Level" % i).text = parts[1]
		var locked := int(parts[1]) <= 0
		get_node("AttributePage/Skill%d/Lock" % i).visible = locked
		for path: String in ["Art", "Corner", "Frame"]:
			get_node("AttributePage/Skill%d/" % i + path).modulate = Color(0.43,0.416,0.416) if locked else Color.WHITE
		get_node("AttributePage/Skill%d/Level" % i).modulate.a = 0.5 if locked else 1.0
	var display: Dictionary = _definitions.star_display[_hero.star]
	for i in 4:
		var node = get_node("AttributePage/Promotion/Star%d" % i)
		node.visible = i < display.count
		node.position.x = 360 - display.count * 26 + i * 52
		node.texture = _catalog.load_resource(display.resource_id)
	$AttributePage/Promotion/Upgrade.visible = _hero.can_star
	$AttributePage/Promotion/Max.visible = not _hero.can_star
	$AttributePage/Promotion/Upgrade/Cost/Portrait.texture = _catalog.load_resource(_hero.portrait)
	$AttributePage/Promotion/Upgrade/Cost/Value.text = "[center][color=%s]%d[/color]/%d[/center]" % ["#36ed38" if _hero.fragments >= _hero.fragment_cost else "#ff3650", _hero.fragments, _hero.fragment_cost]


func _render_collection() -> void:
	var view := MainCollectionContent.hero_tab(tab, _hero, _state, _definitions)
	$CollectionPage/Text.text = view.text
	var key := str(view.rows)
	if key == _rows_key: return
	_rows_key = key
	for child in $CollectionPage/Scroll/Rows.get_children():
		$CollectionPage/Scroll/Rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in view.rows:
		var item = ROW.instantiate()
		$CollectionPage/Scroll/Rows.add_child(item)
		item.get_node("Text").text = row.text
		item.disabled = row.command.is_empty()
		item.pressed.connect(func():
			_hide_tip()
			if row.command.type == "view": _detail(row.command.kind, row.command)
			else: intent.emit(row.command))


func _render_tip() -> void:
	$Tooltip.visible = _tooltip >= 0
	if _tooltip < 0: return
	$Tooltip.position.x = 257 + _tooltip * 75 - 109.5
	$Tooltip/Title.text = TITLES[_tooltip]
	$Tooltip/Body.size.y = 151 if _tooltip == 0 else 174
	$Tooltip.size.y = $Tooltip/Body.size.y
	$Tooltip/Text.text = DESCRIPTIONS[_tooltip] if not _hero.needs.is_empty() else "英雄进入地图后开始记录此状态。"
	if _hero.needs.is_empty(): $Tooltip/Value.text = "[center]—[/center]"; return
	var current := int(_hero.needs[NEEDS[_tooltip]])
	$Tooltip/Value.text = "[center][color=%s]%d[/color]/%d[/center]" % ["#ff3650" if current <= 0 else "#36ed38", current, _hero.magic_capacity if _tooltip == 0 else 100]


func _hide_tip() -> void:
	_tooltip = -1
	$Tooltip.hide()


func _detail(kind: String, data: Dictionary = {}) -> void:
	_hide_tip()
	var values := data.duplicate(true)
	values["hero"] = hero_id
	detail_requested.emit(kind, values)


func _adjacent(direction: int) -> void:
	var index := _order.find(hero_id) + direction
	if index < 0 or index >= _order.size(): return
	hero_id = _order[index]
	_rows_key = ""
	_hide_tip()
	render(_state)


func _skill(index: int) -> void:
	var parts := String(_hero.skills).split("|")[index+1].split(";")
	_hide_tip()
	skill_requested.emit({"skill": int(parts[0]), "level": int(parts[1]), "name": _hero.name, "talent": _hero.talent}, get_node("AttributePage/Skill%d" % index))
