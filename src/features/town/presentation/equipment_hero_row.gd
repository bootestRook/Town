extends Control

signal summoned(id: String)
signal inspected(id: String)
signal equipped(item: Dictionary)
var _id := ""
var _items: Array = []

func _ready() -> void:
	$Summon.pressed.connect(func(): summoned.emit(_id))
	$Card.opened.connect(func(id): inspected.emit(id))
	$Card.located.connect(func(id): inspected.emit(id))
	for i in 2: get_node("Slot%d/Open" % i).pressed.connect(func():
		if i < _items.size() and not _items[i].is_empty(): equipped.emit(_items[i]))

func configure(hero: Dictionary, live: Dictionary, catalog, definitions: Dictionary, shop: Dictionary, shops: Dictionary, level: int) -> void:
	_id = live.id
	$Card.configure(hero,catalog,definitions)
	$Job.text = {1:"战士",2:"弓手",3:"法师"}[int(hero.job)]
	var slots: PackedStringArray = shop.slots.split(";")
	_items.clear()
	for i in 2:
		var node = get_node("Slot%d" % i)
		node.visible = i < slots.size()
		if not node.visible: continue
		node.position.x = 286 if slots.size() == 1 else 236 + i*106
		var item: Dictionary = hero.equipment.get(slots[i],{})
		_items.append(item)
		EquipmentItemCard.equipment_nodes(node,item,catalog)
		node.get_node("Empty").visible = item.is_empty()
		node.get_node("Rating").visible = not item.is_empty()
		if not item.is_empty(): node.get_node("Rating").texture = catalog.load_resource("equipment_shop.rating_%d" % TownEquipmentShop.rating(item,level,shops))
	$Summon.disabled = not live.deployed or live.assigned_area == "town"
	$Summon/Text.text = "未出战" if not live.deployed else ("已派驻" if live.assigned_area == "town" else ("已到达" if live.target == shop.id and live.mode == "await_trade" else ("召唤中" if live.requested == shop.id else "召唤")))
