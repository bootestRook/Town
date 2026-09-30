class_name MainHeroInfoContent
extends RefCounted

static func build(kind: String, data: Dictionary, state: Dictionary, definitions: Dictionary) -> Dictionary:
	var view := {"title": "", "text": "", "portrait": "", "rows": [], "buttons": []}
	var matches: Array = state.main.roster.filter(func(h): return h.id == data.hero)
	if matches.is_empty(): return view
	var hero: Dictionary = matches[0]
	view.portrait = hero.portrait
	match kind:
		"hero_fragment":
			view.title = hero.name + "灵魂石"
			view.text = "持有 %d/%d\n重复招募该英雄可以获得灵魂石" % [hero.fragments, hero.fragment_cost]
		"hero_bag_item":
			var item: Dictionary = definitions.bag_items[data.item]
			view.title = item.display_name
			view.portrait = item.resource_id
			view.text = "数量 %d" % hero.bag.get(data.item, 0)
		"hero_attributes":
			view.title = hero.name + " · 属性"
			view.text = "%d/%d级 · 战力%s\n生命%s · 攻击%s · 防御%s\n%s · %s" % [hero.level, hero.max_level, MainHUD.compact(hero.power), MainHUD.compact(hero.stats.max_hp), MainHUD.compact(hero.stats.attack), MainHUD.compact(hero.stats.defense), "出战" if hero.deployed else "待命", hero.town_status]
			view.buttons = [["升级 %d金币" % hero.upgrade_cost, {"type": "hero_level", "hero": hero.id}], ["取消出战" if hero.deployed else "出战", {"type": "hero_team", "hero": hero.id}], ["解除锁定" if hero.locked else "锁定英雄", {"type": "hero_lock", "hero": hero.id}]]
			view.rows.append(_row("全部技能", {"type": "view", "kind": "skills", "hero": hero.id}))
			if not hero.initially_owned: view.rows.append(_row("遣散英雄", {"type": "hero_release", "hero": hero.id}))
		"hero_donate":
			view.title = "赠送金币"
			view.text = "英雄金币 %s\n公共金币 %s" % [MainHUD.compact(hero.wallet), MainHUD.compact(state.coins)]
			view.buttons = [["赠送", {"type": "hero_donate", "hero": hero.id}]]
		"hero_rank":
			view.title = "英雄品阶"
			view.text = "Ⅰ阶 · " + ["", "战士", "弓手", "法师"][hero.job]
		"hero_element":
			view.title = "元素阵营"
			view.text = ["", "火", "水", "风", "地"][hero.combat.element] + "系"
		"hero_equipment":
			view.title = "装备设置"
			var slot: int = data.get("slot", 0)
			view.text = ""
			if slot == 8:
				var objects: Array = state.main.collections.filter(func(o): return o.kind == "artifact" and o.hero == hero.id)
				for object: Dictionary in objects: view.rows.append(_row(object.name, {"type": "view", "kind": "collection", "object": object.id, "hero": hero.id}))
				view.rows.append(_row("神器仓库", {"type": "view", "kind": "collection_inventory", "collection_kind": "artifact", "hero": hero.id}))
				return view
			for key: String in hero.equipment:
				if slot != 0 and int(key) != slot: continue
				view.rows.append(_row(hero.equipment[key].display_name, {"type": "view", "kind": "equipment_detail", "hero": hero.id, "slot": int(key), "serial": hero.equipment[key].serial}))
			for item: Dictionary in state.equipment:
				if int(item.job) not in [0, int(hero.job)] or (slot != 0 and int(item.slot) != slot): continue
				view.rows.append(_row("装备 · " + item.display_name, {"type": "hero_equip", "hero": hero.id, "serial": item.serial}))
			if view.rows.is_empty(): view.text = "暂无可用装备"
	return view

static func _row(text: String, command: Dictionary) -> Dictionary:
	return {"text": text, "command": command}
