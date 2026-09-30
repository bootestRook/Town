class_name EquipmentShopPage
extends Control

signal intent(command: Dictionary)
signal resource_requested(kind: String)
signal city_requested
signal hero_requested(id: String)
signal material_requested(id: int)
const CARD = preload("res://scenes/town/equipment_item_card.tscn")
const HERO = preload("res://scenes/town/equipment_hero_row.tscn")
var building := ""
var _buildings := {}
var _catalog
var _definitions: Dictionary
var _heroes: Dictionary
var _items := {}
var _state: Dictionary = {}
var tab := 0
var tier := 1
var list_mode := false
var resolving := false
var selected: Array = []
var _key := ""

func _ready() -> void:
	for i in 4: get_node("Tab%d" % i).pressed.connect(func(): switch_tab(i))
	for i in range(1,6): get_node("TierMenu/Tier%d" % i).pressed.connect(func(): tier = i; $TierMenu.hide(); _key = ""; render(_state))
	$Tier.pressed.connect(func(): $TierMenu.show())
	$TierMenu/Dismiss.pressed.connect(func(): $TierMenu.hide())
	$ListMode.pressed.connect(func(): list_mode = not list_mode; _key = ""; render(_state))
	$Resolve.pressed.connect(_resolve)
	$Upgrade.pressed.connect(func(): _submit({"type":"equipment_shop","action":"upgrade"}))
	$Go.pressed.connect(func(): city_requested.emit())
	$Help.pressed.connect(func(): $Dialog.show_text(_definitions.shops[building].display_name+"说明","打造装备后放入货架，召唤英雄到店进行交易。\n\n配方可重复打造；一次性图纸每次打造消耗一张。\n\n英雄使用自己的金币购买适合职业、属性更高的装备。"))
	$GoldAdd.pressed.connect(func(): resource_requested.emit("coins"))
	$DiamondAdd.pressed.connect(func(): resource_requested.emit("diamonds"))
	$Dialog.intent.connect(func(c): _submit(c))
	$Dialog.material_requested.connect(func(id): material_requested.emit(id))
	$Trade.intent.connect(func(c): _submit(c))
	$Trade.donate_requested.connect(func(): $Dialog.donate(_state))
	$Trade.resource_requested.connect(func(kind): resource_requested.emit(kind))

func configure(catalog, data, definitions: Dictionary, heroes: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions
	_heroes = heroes
	for item: Dictionary in data.rows("equipment_shop_items"): _items[int(item.source_id)] = item
	for row: Dictionary in data.rows("town_buildings"): _buildings[row.id] = row
	var tradable := {}
	for item: Dictionary in data.rows("town_items"):
		if item.order_limit > 0: tradable[int(item.id.trim_prefix("item."))] = item
	$Dialog.configure(catalog,_definitions,_items,tradable)
	$Trade.configure(catalog,heroes,_definitions)

func supports(id: String) -> bool: return _definitions.shops.has(id)

func _submit(command: Dictionary) -> void:
	command.building = building
	intent.emit(command)

func open(id: String, state: Dictionary) -> void:
	if building != id: tab = 0; tier = 1; list_mode = false; resolving = false; selected.clear()
	building = id
	$Building.texture = _catalog.load_resource(_buildings[id].built_resource)
	$Description.text = _definitions.shops[id].description
	_state = state
	$Dialog.hide()
	$TierMenu.hide()
	$Trade.visible = not state.equipment_shop.trading.is_empty() and state.equipment_shop.building == building
	if $Trade.visible: $Trade.open(state.equipment_shop.trading,building,state)
	_key = ""
	render(state)

func switch_tab(index: int) -> void:
	tab = index
	resolving = false
	selected.clear()
	_key = ""
	$Scroll.scroll_vertical = 0
	$Heroes.scroll_vertical = 0
	render(_state)

func select_buyer(id: String) -> void:
	_submit({"type":"equipment_shop","action":"open_trade","hero":id})
	if _state.equipment_shop.trading == id: $Trade.open(id,building,_state)

func render(state: Dictionary) -> void:
	_state = state
	var level: int = state.buildings[building]
	var rule: Dictionary = _definitions.levels[building][level]
	$Title.text = "%s Lv.%d" % [_definitions.shops[building].display_name,level]
	var gate: bool = state.city_level < rule.city
	$Condition.text = "已达最高等级" if level == 15 else ("升级条件：[color=#e5430a]主城 Lv%d[/color]" % rule.city if gate else "[img=36]res://assets/runtime/operations/coin.png[/img]  %s" % MainHUD.compact(rule.cost))
	$Go.visible = gate and level < 15
	$Upgrade.visible = not gate and level < 15
	$Upgrade.disabled = state.coins < rule.cost
	$GoldValue.text = MainHUD.compact(state.coins)
	$DiamondValue.text = MainHUD.compact(state.diamonds)
	$SectionText.text = ["可打造配方","一次性图纸","待售装备","英雄当前装备"][tab]
	$Tier.visible = tab < 2
	$Tier/Text.text = ["一阶 ▾","二阶 ▾","三阶 ▾","四阶 ▾","五阶 ▾"][tier-1]
	for node in [$ListMode,$CapacityPanel,$Capacity,$Resolve]: node.visible = tab == 2
	$ListMode/Check.visible = list_mode
	$Resolve/Text.text = "确定" if resolving else "分解"
	$Capacity.text = "库存 %d/300" % state.equipment.filter(func(e): return e.building == building).size()
	$Heroes.visible = tab == 3
	$Scroll.visible = tab != 3
	$Scroll.position.y = 662 if tab == 2 else 588
	$Scroll.size.y = 555 if tab == 2 else 629
	for i in 4: get_node("Tab%d/Art" % i).texture = _catalog.load_resource("equipment_shop.tab%d_%s" % [i,"on" if i == tab else "off"])
	var key := str([tab,tier,list_mode,resolving,selected,level,state.revision,state.equipment_shop.locked,state.equipment,state.main.roster.map(func(h): return [h.id,h.equipment,h.level,h.star])])
	if key != _key:
		_key = key
		_rebuild()
	if tab == 3:
		for row in $Heroes/Rows.get_children():
			var live: Array = state.heroes.filter(func(h): return h.id == row._id)
			var roster: Array = state.main.roster.filter(func(h): return h.live == row._id)
			if not live.is_empty() and not roster.is_empty(): row.configure(roster[0],live[0],_catalog,_heroes,_definitions.shops[building],_definitions,level)
	if $Dialog.visible: $Dialog.render(state)
	if $Trade.visible: $Trade.render(state)

func _rebuild() -> void:
	EquipmentItemCard.clear_list($Scroll/Grid)
	EquipmentItemCard.clear_list($Heroes/Rows)
	$Scroll/Grid.columns = 1 if tab == 2 and list_mode else 4
	if tab == 3:
		for hero: Dictionary in _state.main.roster:
			var row = HERO.instantiate()
			$Heroes/Rows.add_child(row)
			var live: Dictionary = _state.heroes.filter(func(h): return h.id == hero.live)[0]
			row.configure(hero,live,_catalog,_heroes,_definitions.shops[building],_definitions,_state.buildings[building])
			row.equipped.connect(func(item): $Dialog.inspect(item,_state,false))
			row.summoned.connect(func(id):
				if live.mode == "await_trade" and live.target == building: select_buyer(id)
				else: _submit({"type":"summon","hero":id,"building":building}))
			row.inspected.connect(func(id): hero_requested.emit(id))
		return
	var rows: Array = []
	if tab < 2:
		for r: Dictionary in _definitions.recipes.values():
			if r.building != building or r.tier != tier or r.one_use != (tab == 1): continue
			if tab == 0 and r.unlock_level > _state.buildings[building]: continue
			if tab == 1 and TownMainInventory.count(_state,r.source_id) == 0: continue
			var copy := r.duplicate(true)
			if tab == 1: copy.owned = TownMainInventory.count(_state,r.source_id)
			rows.append(copy)
		rows.sort_custom(func(a,b): return (a.quality*10000000+a.slot*1000000+a.job*100000+a.source_id) < (b.quality*10000000+b.slot*1000000+b.job*100000+b.source_id))
	else: rows = _state.equipment.filter(func(e): return e.building == building)
	var minimum := 0 if tab == 0 else (3 if list_mode and tab == 2 else 12)
	for i in maxi(minimum,rows.size()):
		var card = CARD.instantiate()
		$Scroll/Grid.add_child(card)
		card.configure(rows[i] if i < rows.size() else {},_catalog,list_mode and tab == 2)
		if i >= rows.size(): continue
		var item: Dictionary = rows[i]
		if tab < 2: card.pressed.connect(func(): $Dialog.craft(item,_state))
		else:
			card.get_node("Locked").visible = item.serial in _state.equipment_shop.locked
			card.get_node("Selected").visible = item.serial in selected
			card.pressed.connect(func():
				if resolving:
					if item.serial in _state.equipment_shop.locked: return
					if item.serial in selected: selected.erase(item.serial)
					else: selected.append(item.serial)
					_key = ""; render(_state)
				else: $Dialog.inspect(item,_state))

func _resolve() -> void:
	if not resolving: resolving = true; _key = ""; render(_state)
	elif selected.is_empty(): resolving = false; _key = ""; render(_state)
	else: $Dialog.resolve(selected,_state)

func action_result(command: Dictionary, result: Dictionary) -> void:
	if not result.accepted: return
	if command.type == "equipment_shop":
		$Dialog.action_result(command,result)
		if command.action == "resolve": selected.clear(); resolving = false
		if command.action == "open_trade": $Trade.show()
		_key = ""

func close_trade() -> void:
	if $Trade.visible:
		_submit({"type":"equipment_shop","action":"close_trade"})
		$Trade.hide()

func overlay_open() -> bool:
	return $Dialog.visible or $TierMenu.visible
