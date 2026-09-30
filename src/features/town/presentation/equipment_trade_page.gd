extends Control

signal intent(command: Dictionary)
signal donate_requested
signal resource_requested(kind: String)
const OFFER = preload("res://scenes/town/equipment_offer.tscn")
var _catalog
var _definitions: Dictionary
var _shops: Dictionary
var _building := ""
var _slot := ""
var _state: Dictionary
var _hero := ""
var _key := ""

func _ready() -> void:
	$Donate.pressed.connect(func(): donate_requested.emit())
	$GoldAdd.pressed.connect(func(): resource_requested.emit("coins"))
	$DiamondAdd.pressed.connect(func(): resource_requested.emit("diamonds"))
	for i in 2: get_node("Part%d" % i).pressed.connect(func():
		_slot = _shops.shops[_building].slots.split(";")[i]; _key = ""; render(_state))

func configure(catalog, definitions: Dictionary, shops: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions
	_shops = shops

func open(hero: String, building: String, state: Dictionary) -> void:
	_hero = hero
	_building = building
	var slots: PackedStringArray = _shops.shops[building].slots.split(";")
	_slot = slots[0]
	if slots.size() > 1 and not state.equipment.any(func(e): return e.building == building and str(int(e.slot)) == _slot) and state.equipment.any(func(e): return e.building == building and str(int(e.slot)) == slots[1]): _slot = slots[1]
	_key = ""
	$Offers.scroll_vertical = 0
	show()
	render(state)

func render(state: Dictionary) -> void:
	_state = state
	var found: Array = state.main.roster.filter(func(h): return h.live == _hero)
	if found.is_empty(): return
	var hero: Dictionary = found[0]
	var item: Dictionary = hero.equipment.get(_slot,{})
	var slots: PackedStringArray = _shops.shops[_building].slots.split(";")
	for i in 2:
		get_node("Part%d" % i).visible = slots.size() > 1
		if slots.size() > 1: get_node("Part%d/Art" % i).texture = _catalog.load_resource("equipment_shop.part_%s_%s" % [slots[i],"on" if slots[i] == _slot else "off"])
	$Portrait.configure(_definitions.heroes[hero.definition].appearance,_catalog,_definitions)
	$Backdrop/Background.texture = _catalog.load_resource("hero_detail.background_%d" % hero.quality)
	$HeroName.text = hero.name
	$Job.texture = _catalog.load_resource("equipment_shop.job_%d" % hero.job)
	$HeroPower.text = str(hero.power)
	$Wallet.text = MainHUD.compact(hero.wallet)
	$GoldValue.text = MainHUD.compact(state.coins)
	$DiamondValue.text = MainHUD.compact(state.diamonds)
	EquipmentItemCard.equipment_nodes(self,item,_catalog)
	$EquipmentName.text = item.get("display_name","暂无装备")
	$EquipmentPower.text = "%s%d" % [item.attribute_name,item.power] if not item.is_empty() else ""
	$Affixes.text = "[color=#c049d3]%s[/color]" % EquipmentItemCard.affix_text(item)
	var purchased: bool = _slot in state.equipment_shop.purchased
	var key := str([_slot,state.equipment,state.equipment_shop.locked,state.equipment_shop.purchased,item,hero.wallet])
	if key == _key: return
	_key = key
	EquipmentItemCard.clear_list($Offers/Rows)
	for offer: Dictionary in state.equipment:
		if offer.building != _building or str(int(offer.slot)) != _slot or int(offer.job) not in [0,int(hero.job)] or offer.serial in state.equipment_shop.locked: continue
		var row = OFFER.instantiate()
		$Offers/Rows.add_child(row)
		EquipmentItemCard.equipment_nodes(row,offer,_catalog)
		row.get_node("Name").text = offer.display_name
		row.get_node("Power").text = "%s：[color=#00f009]%d[/color]" % [offer.attribute_name,offer.power]
		row.get_node("Up").visible = offer.power > item.get("power",0)
		row.get_node("Price").text = MainHUD.compact(offer.price)
		row.get_node("Buy").disabled = purchased or hero.wallet < offer.price or offer.power <= item.get("power",0)
		row.get_node("Buy").modulate = Color(0.5,0.5,0.5,1) if row.get_node("Buy").disabled else Color.WHITE
		row.get_node("Buy/Text").text = "已交易" if purchased else "交易"
		row.get_node("Buy").pressed.connect(func(): intent.emit({"type":"sale","hero":_hero,"serial":offer.serial}))
