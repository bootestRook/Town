class_name MainDetailContent
extends RefCounted

static func build(kind: String, data: Dictionary, state: Dictionary, definitions: Dictionary) -> Dictionary:
	var view := {"title": "", "text": "", "portrait": "", "rows": [], "buttons": []}
	var main: Dictionary = state.main
	match kind:
		"management_help":
			view.title = "上阵" if data.page == 0 else "培养"
			view.text = "选择英雄上阵，点击已上阵英雄下阵。\n快捷上阵选择当前元素中战力最高的英雄。" if data.page == 0 else "消耗对应英雄的灵魂石升星，提升属性和技能等级。"
		"catalog_hero":
			var definition: Dictionary = definitions.heroes[data.definition]
			var record: Dictionary = definitions.hero_catalog[data.definition]
			var talent: Dictionary = definitions.hero_talents[record.show_talent]
			view.title = definition.display_name
			view.portrait = definition.resource_id
			view.text = "图鉴 · Lv.%d\n生命%s · 攻击%s · 防御%s" % [talent.max_level,MainHUD.compact(definition.hp+talent.hp+definition.hp_growth*(talent.max_level-1)),MainHUD.compact(definition.attack+talent.attack+definition.attack_growth*(talent.max_level-1)),MainHUD.compact(definition.defense+talent.defense+definition.defense_growth*(talent.max_level-1))]
			var skills := String(talent.skills).split("|")
			for i in range(1,skills.size()):
				var parts := skills[i].split(";")
				var skill: Dictionary = definitions.skills[int(parts[0])]
				view.rows.append({"text":skill.display_name+" Lv."+parts[1], "command":{"type":"view", "kind":"skill", "skill":int(parts[0]), "level":int(parts[1]), "name":definition.display_name, "talent":record.show_talent}})
		"city":
			var offer: Dictionary = definitions.city[state.city_level]
			view.title = "主城"
			view.portrait = "town.jianzhu_icon_zhucheng"
			view.text = "主城等级 %d\n升级消耗 %s 金币\n地下城通关 %d/%d" % [state.city_level, MainHUD.compact(offer.cost), main.progress.get("dungeon",0), offer.dungeon]
			view.buttons.append(["升级", {"type": "city_upgrade"}])
		"sea":
			var site: Dictionary = definitions.sea.filter(func(s): return s.id == data.site)[0]
			var job: Dictionary = main.salvage.jobs.get(site.id, {})
			view.title = site.display_name
			view.portrait = site.resource_id
			view.text = "消耗打捞体力 %d\n打捞时间 %d分钟" % [site.cost, site.seconds / 60]
			var reward: String = definitions.sea_rewards[state.city_level][["low", "middle", "high"][site.source_id - 1]]
			if job.is_empty(): view.buttons.append(["开始打捞", {"type": "sea_start", "site": site.id}])
			else:
				reward = job.reward
				var seconds := ceili(job.remaining)
				view.text += "\n剩余 %02d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]
				if seconds == 0: view.buttons.append(["领取", {"type": "sea_claim", "site": site.id}])
			view.rows.append({"text": reward_text(reward, definitions.items), "command": {}})
		"sea_records":
			view.title = "打捞记录"
			view.text = "暂无打捞记录" if main.salvage.records.is_empty() else "已完成 %d次" % main.salvage.records.size()
			for record: Dictionary in main.salvage.records: view.rows.append({"text": record.site + " · " + reward_text(record.reward, definitions.items), "command": {}})
		"skills":
			var hero: Dictionary = main.roster.filter(func(h): return h.id == data.hero)[0]
			view.title = hero.name + " · 技能"
			view.portrait = hero.portrait
			view.text = "%d星 · %d级" % [hero.star, hero.level]
			for token in String(hero.skills).split("|").slice(1):
				var parts := token.split(";")
				if parts.size() < 2: continue
				var id := int(parts[0])
				if definitions.skills.has(id):
					var skill: Dictionary = definitions.skills[id]
					view.rows.append({"text": "%s · %s" % [skill.display_name, "%s级" % parts[1] if int(parts[1]) > 0 else "未解锁"], "command": {"type": "view", "kind": "skill", "skill": id, "name": hero.name, "level": int(parts[1]), "talent":hero.talent}})
		"completed":
			view.title = "全部通关"
			view.text = "当前全部关卡已完成"
	return view

static func reward_text(value: String, items: Dictionary) -> String:
	var parts: Array[String] = []
	for pair in value.split(";"):
		var data := pair.split(":")
		if data.size() == 2: parts.append(String(items.get(int(data[0]), "道具")) + "×" + data[1])
	return "、".join(parts)
