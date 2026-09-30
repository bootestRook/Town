extends Control

signal intent(command: Dictionary)
signal material_requested(id: int)
const MATERIAL = preload("res://scenes/town/horn_reward.tscn")
var _catalog
var _definitions: Dictionary
var _items: Dictionary
var _state: Dictionary
var _mode := ""
var _item: Dictionary = {}
var _serials: Array = []
var _tradable: Dictionary = {}
var _material := 0
var _craft_count := 1

func _ready() -> void:
	$Cancel.pressed.connect(func():
		if _mode == "material": craft(_item,_state); $Slider.value = _craft_count
		else: hide())
	$Accept.pressed.connect(_accept)
	$Minus.pressed.connect(func(): $Slider.value -= 1)
	$Plus.pressed.connect(func(): $Slider.value += 1)
	$Max.pressed.connect(func(): $Slider.value = $Slider.max_value)
	$Slider.value_changed.connect(func(_value): render(_state))
	$Lock.pressed.connect(func(): intent.emit({"type":"equipment_shop","action":"lock","serial":_item.serial}))

func configure(catalog, definitions: Dictionary, items: Dictionary, tradable: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions
	_items = items
	_tradable = tradable

func _open(mode: String, title: String) -> void:
	_mode = mode
	$Title.text = title
	$Name.text = ""
	$Detail.text = ""
	$Count.text = ""
	EquipmentItemCard.clear_list($Materials)
	for node in [$Slider,$Minus,$Plus,$Max,$Count]: node.visible = mode == "craft"
	for node in [$Quality,$Icon,$Tier]: node.visible = mode in ["craft","inspect","result","material"]
	$Lock.visible = mode == "inspect"
	$Amount.visible = mode == "donate"
	$Accept/Text.text = {"craft":"打造","resolve":"分解","donate":"赠送"}.get(mode,"确定")
	$Accept.disabled = false
	$Cancel/Text.text = "返回" if mode == "material" else "取消"
	show()

func craft(recipe: Dictionary, state: Dictionary) -> void:
	_item = recipe
	_state = state
	_open("craft","打造装备")
	var equipment: Dictionary = _definitions.equipment[recipe.equipment]
	$Quality.texture = _catalog.load_resource("operations.quality_%d" % equipment.quality)
	$Icon.texture = _catalog.load_resource(equipment.resource_id)
	$Tier.texture = _catalog.load_resource("equipment_shop.tier_%d" % recipe.tier)
	$Name.text = equipment.display_name
	for id: int in TownMainInventory.entries(recipe.cost):
		var card = MATERIAL.instantiate()
		$Materials.add_child(card)
		card.get_node("Icon").texture = _catalog.load_resource(_items[id].resource_id)
		card.get_node("Quality").texture = _catalog.load_resource("operations.quality_%d" % _items[id].quality)
		card.tooltip_text = _items[id].display_name
		card.set_meta("item",id)
		card.pressed.connect(func(): _show_material(id))
	$Slider.value = 1
	render(state)

func _show_material(id: int) -> void:
	_craft_count = int($Slider.value)
	_material = id
	_open("material","获得途径")
	$Quality.texture = _catalog.load_resource("operations.quality_%d" % _items[id].quality)
	$Icon.texture = _catalog.load_resource(_items[id].resource_id)
	$Tier.hide()
	$Name.text = _items[id].display_name
	var description: String = _items[id].description.replace("<color=", "[color=").replace(">", "]").replace("</color]", "[/color]")
	$Detail.text = "%s\n\n持有：%d" % [description,TownMainInventory.count(_state,id)]
	$Detail.size.y = 280
	$Accept/Text.text = "预购" if _tradable.has(id) else "确定"

func inspect(item: Dictionary, state: Dictionary, editable: bool = true) -> void:
	_item = item
	_state = state
	_open("inspect","装备详情")
	$Lock.visible = editable
	$Quality.texture = _catalog.load_resource("operations.quality_%d" % item.quality)
	$Icon.texture = _catalog.load_resource(item.resource_id)
	$Tier.texture = _catalog.load_resource("equipment_shop.tier_%d" % item.rank)
	$Name.text = item.display_name
	$Detail.text = "%s：%d\n售价：%s\n[color=#d058e0]%s[/color]" % [item.attribute_name,item.power,MainHUD.compact(item.price),EquipmentItemCard.affix_text(item)]
	$Detail.size.y = 262
	render(state)

func resolve(serials: Array, state: Dictionary) -> void:
	_state = state
	_serials = serials.duplicate()
	_open("resolve","分解装备")
	var coins := 0
	for item: Dictionary in state.equipment:
		if item.serial in serials: coins += TownMainInventory.entries(item.resolve).get(101,0)
	$Detail.text = "分解 %d 件装备\n\n可获得金币：%s" % [serials.size(),MainHUD.compact(coins)]

func donate(state: Dictionary) -> void:
	_state = state
	_open("donate","赠送金币")
	$Detail.text = "持有金币：%s" % MainHUD.compact(state.coins)
	$Amount.text = ""
	$Amount.grab_focus()

func show_text(title: String, body: String) -> void:
	_open("text",title)
	$Detail.text = body
	$Detail.size.y = 340

func render(state: Dictionary) -> void:
	_state = state
	if _mode == "inspect":
		$Lock/Text.text = "解锁" if _item.serial in state.equipment_shop.locked else "锁定"
		return
	if _mode != "craft": return
	var maximum := mini(10,300 - state.equipment.filter(func(e): return e.building == _item.building).size())
	var costs := TownMainInventory.entries(_item.cost)
	for id: int in costs: maximum = mini(maximum,TownMainInventory.count(state,id) / costs[id])
	if _item.one_use: maximum = mini(maximum,TownMainInventory.count(state,_item.source_id))
	var level: int = state.buildings[_item.building]
	if _item.unlock_level > level or _item.tier > _definitions.levels[_item.building][level].tier: maximum = 0
	$Slider.max_value = maxi(1,maximum)
	var count := int($Slider.value)
	$Count.text = "%d / %d" % [count,maximum]
	$Accept.disabled = maximum < count
	$Max.disabled = maximum < 1
	$Slider.editable = maximum > 1
	$Slider.modulate = Color.WHITE if maximum > 1 else Color(0.45,0.6,0.6,1)
	$Detail.size.y = 119
	$Detail.text = "%s：%d\n所需材料" % [_definitions.equipment[_item.equipment].attribute_name,_definitions.equipment[_item.equipment].power]
	if _item.one_use: $Detail.text += "   图纸：%d/%d" % [TownMainInventory.count(state,_item.source_id),count]
	for card in $Materials.get_children():
		var id: int = card.get_meta("item")
		card.get_node("Chance").text = "%d/%d" % [TownMainInventory.count(state,id),costs[id]*count]

func _accept() -> void:
	match _mode:
		"craft": intent.emit({"type":"equipment_shop","action":"craft","recipe":_item.id,"count":int($Slider.value)})
		"resolve": intent.emit({"type":"equipment_shop","action":"resolve","serials":_serials})
		"donate": intent.emit({"type":"equipment_shop","action":"donate","amount":$Amount.text})
		"material":
			if _tradable.has(_material): material_requested.emit(_material)
			else: craft(_item,_state)
		_: hide()

func action_result(command: Dictionary, result: Dictionary) -> void:
	if command.action == "craft":
		_open("result","打造成功")
		$Name.text = "%s ×%d" % [_item.display_name,result.quantity]
	elif command.action in ["donate","resolve"]: hide()
