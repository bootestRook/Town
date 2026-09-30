extends Control

signal closed
signal intent(command: Dictionary)
signal notice(message: String)
var _catalog
var _definitions: Dictionary = {}
var _data: Dictionary = {}
var _item: Dictionary = {}
var _rule: Dictionary = {}

func _ready() -> void:
	$Outside.pressed.connect(close)
	$Panel/Buyback.pressed.connect(func():
		$Confirm/Card/Text.text = "花费 %d 钻石回购%s？" % [_rule.buyback, _item.display_name]
		$Confirm.show())
	$Confirm/Card/Cancel.pressed.connect(func(): $Confirm.hide())
	$Confirm/Card/Accept.pressed.connect(func():
		$Confirm.hide()
		intent.emit(_command("hero_equipment_buyback")))
	$Panel/Refine.pressed.connect(func(): intent.emit(_command("hero_equipment_refine")))
	$Panel/Share.pressed.connect(func():
		DisplayServer.clipboard_set("%s\n%s\n%s" % [_item.display_name, $Panel/Attribute.text, _affix_text(false)])
		notice.emit("装备信息已复制"))

func configure(catalog, definitions: Dictionary) -> void:
	_catalog = catalog
	_definitions = definitions

func open(data: Dictionary, state: Dictionary) -> void:
	_data = data.duplicate(true)
	$Confirm.hide()
	show()
	render(state)

func close() -> void:
	if $Confirm.visible: $Confirm.hide(); return
	hide()
	closed.emit()

func resize_page(height: float) -> void:
	size.y = height
	$Panel.position.y = (height - 516) * 0.5 - 48
	$CloseHint.position.y = $Panel.position.y + 560
	$Confirm/Card.position.y = (height - 260) * 0.5

func render(state: Dictionary) -> void:
	if not visible: return
	var heroes: Array = state.main.roster.filter(func(h): return h.id == _data.hero)
	if heroes.is_empty(): hide(); closed.emit(); return
	var equipment: Dictionary = heroes[0].equipment
	var slot := str(int(_data.slot))
	if not equipment.has(slot) or equipment[slot].serial != _data.serial:
		hide(); $Confirm.hide(); closed.emit(); return
	_item = equipment[slot]
	_rule = _definitions.equipment_rules[_item.id]
	$Panel/Title.text = _item.display_name
	$Panel/Item/Frame.texture = _catalog.load_resource("operations.quality_%d" % _item.quality)
	$Panel/Item/Icon.texture = _catalog.load_resource(_item.resource_id)
	$Panel/Item/Rank/Value.text = ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"][mini(5, int(_item.rank))]
	$Panel/Attribute.text = "%s%s" % [{1:"生命",5:"攻击",7:"防御"}[int(_item.attribute)], MainHUD.compact(_item.power)]
	$Panel/Affixes.text = _affix_text(true)

func _affix_text(formatted: bool) -> String:
	var lines: PackedStringArray = []
	for affix: Dictionary in _item.affixes:
		if affix.has("label"):
			var value := "%.2f%%" % (affix.value / 100.0) if affix.percent else str(affix.value)
			lines.append("• [color=#c342d2]%s[/color]" % String(affix.label).replace("%s",value) if formatted else String(affix.label).replace("%s",value))
			continue
		var text: String = _rule.label + _value(affix.value)
		if formatted: text = "[color=#c342d2]" + text + "[/color]"
		lines.append("• " + text + "  (%s--%s)" % [_value(_rule.minimum), _value(_rule.maximum)])
	return "\n".join(lines)

func _value(value: int) -> String:
	return ("%.2f" % (value / 100.0)).trim_suffix("0").trim_suffix("0").trim_suffix(".") + "%" if _rule.percent else str(value)

func _command(kind: String) -> Dictionary:
	return {"type": kind, "hero": _data.hero, "slot": str(int(_data.slot)), "serial": _data.serial}
