class_name EquipmentItemCard
extends Button

func configure(row: Dictionary, catalog, list_mode: bool = false) -> void:
	custom_minimum_size = Vector2(696,174) if list_mode else Vector2(166,214)
	$Background.size = custom_minimum_size
	for node in [$Quality,$Icon,$Tier,$Name,$Count,$Stars]: node.visible = not row.is_empty()
	$Selected.hide()
	$Locked.hide()
	$Detail.visible = list_mode and not row.is_empty()
	if row.is_empty(): disabled = true; return
	$Quality.texture = catalog.load_resource("operations.quality_%d" % row.quality)
	$Icon.texture = catalog.load_resource(row.resource_id)
	$Tier.texture = catalog.load_resource("equipment_shop.tier_%d" % row.get("tier",row.get("rank",1)))
	$Name.text = row.display_name
	$Name.position = Vector2(173,8) if list_mode else Vector2(5,152)
	$Name.size.x = 435 if list_mode else 156
	$Name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if list_mode else HORIZONTAL_ALIGNMENT_CENTER
	$Count.text = str(row.owned) if row.has("owned") else ""
	$Stars.text = "★".repeat(row.get("star",0))
	if list_mode: $Detail.text = "%s：%d\n售价：%s" % [row.attribute_name,row.power,MainHUD.compact(row.price)]

static func affix_text(item: Dictionary) -> String:
	var lines: Array[String] = []
	for a: Dictionary in item.get("affixes",[]):
		var value := ("%.2f%%" % (a.value / 100.0)) if a.get("percent",false) else str(a.value)
		lines.append("•  " + String(a.get("label","属性%s")).replace("%s",value))
	return "\n\n".join(lines)

static func clear_list(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

static func equipment_nodes(parent: Node, item: Dictionary, catalog) -> void:
	for name in ["Quality","Icon","Tier","Stars"]: parent.get_node(name).visible = not item.is_empty()
	if item.is_empty(): return
	parent.get_node("Quality").texture = catalog.load_resource("operations.quality_%d" % item.quality)
	parent.get_node("Icon").texture = catalog.load_resource(item.resource_id)
	parent.get_node("Tier").texture = catalog.load_resource("equipment_shop.tier_%d" % item.rank)
	parent.get_node("Stars").text = "★".repeat(item.star)
