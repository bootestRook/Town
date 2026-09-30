extends Button

func configure(item: Dictionary, quantity: int, catalog) -> void:
	var occupied := not item.is_empty()
	$Empty.visible = not occupied
	for child: String in ["Frame", "Icon", "Rank", "Quantity"]: get_node(child).visible = occupied
	disabled = not occupied
	if not occupied: return
	$Frame.texture = catalog.load_resource("operations.quality_%d" % item.quality)
	$Icon.texture = catalog.load_resource(item.resource_id)
	$Rank/Tier.text = ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"][mini(5, int(item.tier))]
	$Quantity.text = MainHUD.compact(quantity)
	tooltip_text = item.display_name
