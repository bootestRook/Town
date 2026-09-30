class_name MainCollectionContent
extends RefCounted

static func hero_tab(tab: int, selected: Dictionary, state: Dictionary, definitions: Dictionary) -> Dictionary:
	var view := {"text": "", "rows": []}
	match tab:
		1, 2:
			var object_kind := "pet" if tab == 1 else "artifact"
			var label := "宠物" if tab == 1 else "神器"
			var objects: Array = state.main.collections.filter(func(o): return o.kind == object_kind and o.hero == selected.id)
			view.text = "暂无" + label
			if not objects.is_empty():
				var object: Dictionary = objects[0]
				view.text = "%s  %d级\n生命 +%s  攻击 +%s\n防御 +%s" % [object.name, object.level, MainHUD.compact(object.stats.max_hp), MainHUD.compact(object.stats.attack), MainHUD.compact(object.stats.defense)]
				view.rows.append(_row(label + "详情", {"type": "view", "kind": "collection", "object": object.id, "hero": selected.id}))
			view.rows.append(_row(label + "仓库", {"type": "view", "kind": "collection_inventory", "collection_kind": object_kind, "hero": selected.id}))
			view.rows.append(_row(label + "图鉴", {"type": "view", "kind": "collection_catalog", "collection_kind": object_kind}))
	return view

static func build(kind: String, data: Dictionary, state: Dictionary, definitions: Dictionary) -> Dictionary:
	var view := {"title": "", "text": "", "portrait": "", "rows": [], "buttons": []}
	match kind:
		"collection_inventory":
			view.title = "宠物仓库" if data.collection_kind == "pet" else "神器仓库"
			var objects: Array = state.main.collections.filter(func(o): return o.kind == data.collection_kind)
			view.text = "拥有 %d" % objects.size()
			for object: Dictionary in objects:
				var status := "空闲" if object.hero.is_empty() else "已装备"
				view.rows.append(_row("%s  %d级 · %s" % [object.name, object.level, status], {"type": "view", "kind": "collection", "object": object.id, "hero": data.hero}))
			for key: String in state.inventory:
				var id := int(key.get_slice(".", 1))
				if state.inventory[key] <= 0 or not definitions.uses.has(id): continue
				var item: Dictionary = definitions.uses[id]
				if item.kind == (30 if data.collection_kind == "pet" else 36): view.rows.append(_row("%s ×%d" % [item.display_name, state.inventory[key]], {"type": "view", "kind": "item", "item": id}))
		"collection_catalog":
			view.title = "宠物图鉴" if data.collection_kind == "pet" else "神器图鉴"
			view.text = ""
			var catalog: Dictionary = definitions.pets if data.collection_kind == "pet" else definitions.artifacts
			for entry: Dictionary in catalog.values():
				if data.collection_kind == "pet" and entry.star != 1: continue
				view.rows.append(_row(entry.display_name, {"type": "view", "kind": "collection_info", "collection_kind": data.collection_kind, "definition": int(entry.source_id)}))
		"collection_info":
			var entry: Dictionary = (definitions.pets if data.collection_kind == "pet" else definitions.artifacts)[data.definition]
			view.title = entry.display_name
			view.portrait = entry.resource_id
			view.text = entry.description if data.collection_kind == "pet" else "成长值 %d–%d" % [entry.growth_min, entry.growth_max]
		"collection":
			var objects: Array = state.main.collections.filter(func(o): return o.id == data.object)
			if objects.is_empty(): return view
			var object: Dictionary = objects[0]
			view.title = object.name
			view.portrait = object.portrait
			view.text = "%d/%d级%s\n生命 +%s   攻击 +%s\n防御 +%s\n%s" % [object.level, object.max_level, " · %d星" % object.star if object.kind == "pet" else "", MainHUD.compact(object.stats.max_hp), MainHUD.compact(object.stats.attack), MainHUD.compact(object.stats.defense), MainDetailContent.reward_text(object.cost, definitions.items)]
			view.buttons = [["升级", {"type": "collection_level", "object": object.id}], ["装备" if object.hero.is_empty() else "卸下", {"type": "collection_equip" if object.hero.is_empty() else "collection_unequip", "object": object.id, "hero": data.hero}], ["解除锁定" if object.locked else "锁定", {"type": "collection_lock", "object": object.id}], ["升星" if object.kind == "pet" else "重置等级", {"type": "collection_star" if object.kind == "pet" else "collection_reset", "object": object.id}]]
			view.rows.append(_row("技能说明" if object.kind == "pet" else "神器说明", {"type": "view", "kind": "collection_info", "collection_kind": object.kind, "definition": object.definition}))
			if object.kind == "pet": view.rows.append(_row("重置等级", {"type": "collection_reset", "object": object.id}))
			view.rows.append(_row("分解", {"type": "collection_dismantle", "object": object.id}))
		"item":
			var item: Dictionary = definitions.uses[data.item]
			view.title = item.display_name
			view.portrait = item.resource_id
			view.text = item.description.replace("<br/>", "\n")
			var amount: int = state.inventory.get("item." + str(data.item), 0)
			view.rows.append(_row("拥有 %d" % amount, {}))
			if amount > 0: view.buttons.append(["合成" if item.kind == 39 else "使用", {"type": "item_use", "item": data.item}])
		"gift":
			var offer: Dictionary = state.main.gifts.filter(func(g): return g.id == data.product)[0]
			view.title = offer.display_name
			view.portrait = offer.resource_id
			view.text = MainDetailContent.reward_text(offer.rewards, definitions.items)
			view.rows.append(_row("主城等级 %d–%d" % [offer.minimum, offer.maximum - 1], {}))
			if offer.limit >= 0: view.rows.append(_row("今日剩余 %d/%d次" % [maxi(0, offer.limit - state.main.daily.get("gift." + offer.id, 0)), offer.limit], {}))
			if state.city_level < offer.minimum or state.city_level >= offer.maximum: view.rows.append(_row("主城等级不符合购买条件", {}))
			elif offer.limit >= 0 and state.main.daily.get("gift." + offer.id, 0) >= offer.limit: view.rows.append(_row("今日已售罄", {}))
			else: view.buttons.append(["免费领取" if offer.price == 0 else "模拟购买 ¥%s" % offer.price, {"type": "gift_buy", "product": offer.id}])
	return view

static func _row(text: String, command: Dictionary) -> Dictionary:
	return {"text": text, "command": command}
