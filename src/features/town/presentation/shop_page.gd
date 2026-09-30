class_name ShopPage
extends Control

signal intent(command: Dictionary)
signal select_item(row: Dictionary, mode: String)
const ItemScene = preload("res://scenes/town/item_card.tscn")
const RecipeScene = preload("res://scenes/town/recipe_card.tscn")
const HeroScene = preload("res://scenes/town/hero_row.tscn")
var building := ""
var mode := "orders"
var _catalog
var _items: Dictionary = {}
var _recipes: Array = []
var _buildings: Dictionary = {}
var _state: Dictionary = {}
var _tier := 1
var _revision := -1


func _ready() -> void:
	$Tab1.pressed.connect(func(): _switch("orders" if building == "building.7" else "craft"))
	$Tab2.pressed.connect(func(): _switch("heroes" if building == "building.7" else "stock"))
	$Tab3.pressed.connect(func(): _switch("sell"))
	$Tier.pressed.connect(func():
		_tier = 2 if _tier == 1 and _state.exchange_level >= 2 else 1
		_revision = -1
		render(_state))
	$Upgrade.pressed.connect(func(): intent.emit({"type": "upgrade", "building": building}))


func configure(catalog, items: Dictionary, recipes: Array, buildings: Array) -> void:
	_catalog = catalog
	_items = items
	_recipes = recipes
	for row: Dictionary in buildings:
		_buildings[row.id] = row


func open(id: String, state: Dictionary) -> void:
	building = id
	_state = state
	$Building.texture = _catalog.load_resource(_buildings[id].built_resource)
	_switch("orders" if id == "building.7" else "craft")


func _switch(next: String) -> void:
	mode = next
	_revision = -1
	render(_state)


func render(state: Dictionary) -> void:
	_state = state
	if building.is_empty():
		return
	var exchange := building == "building.7"
	$Title.text = "%s %d级" % [_buildings[building].display_name, state.exchange_level if exchange else 1]
	$Subtitle.text = "英雄与玩家交易的建筑物" if exchange else "打造装备，出售给英雄"
	$ConditionText.text = ("主城 4级  ·  金币 1000" if state.exchange_level == 1 else "已开放二阶材料") if exchange else "已解锁入门配方"
	$Upgrade.visible = exchange and state.exchange_level == 1
	$Tab1/Text.text = "预购" if exchange else "打造"
	$Tab2/Text.text = "英雄" if exchange else "仓库"
	$Tab3.visible = not exchange
	$SectionText.text = {"orders":"材料", "heroes":"英雄", "craft":"配方", "stock":"装备仓库", "sell":"出售"}[mode]
	$Tier.visible = mode == "orders"
	$Tier/Text.text = "一阶 ▾" if _tier == 1 else "二阶 ▾"
	$Scroll.visible = mode in ["orders", "craft", "stock"]
	$Heroes.visible = mode in ["heroes", "sell"]
	if _revision != int(state.revision):
		_revision = int(state.revision)
		_rebuild()
	if $Heroes.visible:
		_render_heroes()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	_clear($Scroll/Grid)
	_clear($Heroes/Rows)
	$Empty.visible = false
	$Scroll/Grid.columns = 4 if mode == "orders" else 2
	if mode == "orders":
		var sorted_items := _items.values()
		sorted_items.sort_custom(func(a, b): return a.sort_order < b.sort_order)
		for row: Dictionary in sorted_items:
			if row.order_limit <= 0 or row.tier != _tier:
				continue
			var card = ItemScene.instantiate()
			$Scroll/Grid.add_child(card)
			card.get_node("Icon").texture = _catalog.load_resource(row.resource_id)
			card.get_node("Quality").texture = _catalog.load_resource("operations.quality_%d" % row.quality)
			card.get_node("Tier").texture = _catalog.load_resource("operations.tier" if _tier == 1 else "operations.tier_2")
			card.get_node("Name").text = row.display_name
			var order := int(_state.orders.get(row.id, 0))
			card.get_node("Count").text = "预购 %d" % order if order > 0 else "持有 %d" % _state.inventory[row.id]
			card.pressed.connect(func(): select_item.emit(row, "order"))
	elif mode in ["craft", "stock"]:
		var rows: Array = _recipes if mode == "craft" else _state.equipment
		for row: Dictionary in rows:
			if row.building != building:
				continue
			var card = RecipeScene.instantiate()
			$Scroll/Grid.add_child(card)
			card.get_node("Icon").texture = _catalog.load_resource(row.resource_id)
			card.get_node("Name").text = row.display_name
			card.get_node("Power").text = "%s +%d" % [_attribute(row.attribute), row.power]
			card.get_node("Cost").text = "%s %d/%d\n%s %d/%d" % [_items[row.material_a].display_name, _state.inventory[row.material_a], row.count_a, _items[row.material_b].display_name, _state.inventory[row.material_b], row.count_b] if mode == "craft" else "售价：%d 金币\n%s" % [row.price, "职业通用" if row.job == 0 else {1:"战士",2:"弓手",3:"法师"}[int(row.job)]]
			card.get_node("Action").text = "打造" if mode == "craft" else "待售"
			if mode == "craft":
				card.pressed.connect(func(): select_item.emit(row, "craft"))
		$Empty.visible = $Scroll/Grid.get_child_count() == 0
	else:
		for hero: Dictionary in _state.heroes:
			var row = HeroScene.instantiate()
			$Heroes/Rows.add_child(row)
			row.get_node("Portrait").texture = _catalog.load_resource("heroes.%s_portrait" % hero.visual)
			row.get_node("Name").text = hero.name
			row.get_node("Summon").pressed.connect(func(): select_buyer(hero.id))


func _render_heroes() -> void:
	for i in mini($Heroes/Rows.get_child_count(), _state.heroes.size()):
		var hero: Dictionary = _state.heroes[i]
		var row = $Heroes/Rows.get_child(i)
		row.get_node("Summon").disabled = not hero.deployed
		row.get_node("Summon/Text").text = "未出战" if not hero.deployed else ("交易" if hero.mode == "await_trade" and hero.target == building else "召唤")
		row.get_node("State").text = "金币 %d  ·  %s\n生命 %d  饱食 %d  精力 %d  心情 %d" % [hero.wallet, hero.reason, hero.needs.hp, hero.needs.energy, hero.needs.tired, hero.needs.mood]
		var lines: Array[String] = []
		if mode == "heroes":
			for id: String in hero.bag:
				if hero.bag[id] > 0:
					lines.append("%s ×%d" % [_items[id].display_name, hero.bag[id]])
		else:
			for item: Dictionary in hero.equipment.values():
				lines.append(item.display_name)
			lines.push_front("攻击 %d · 防御 %d · 生命 %d" % [hero.stats.attack, hero.stats.defense, hero.stats.max_hp])
		var groups: Array[String] = []
		for start in range(0, lines.size(), 3):
			groups.append("  ·  ".join(lines.slice(start, start + 3)))
		row.get_node("Bag").text = "\n".join(groups) if not groups.is_empty() else "暂无携带物品"
		var height := maxf(260.0, 142.0 + groups.size() * 30.0)
		row.custom_minimum_size.y = height
		row.get_node("Background").size.y = height
		row.get_node("Bag").size.y = height - 136.0


func select_buyer(id: String) -> void:
	var hero: Dictionary = _state.heroes.filter(func(h): return h.id == id)[0]
	if hero.mode != "await_trade" or hero.target != building:
		intent.emit({"type":"summon", "hero":id, "building":building})
		return
	var offers: Array = _state.equipment.filter(func(eq): return eq.building == building and (eq.job == 0 or eq.job == hero.job))
	select_item.emit({"hero":hero, "offers":offers}, "sale")


static func _attribute(id: int) -> String:
	return {1:"生命",5:"攻击",6:"攻速",7:"防御"}.get(id, "属性")
