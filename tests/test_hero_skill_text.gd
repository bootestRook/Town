extends RefCounted

func run(test: TestSupport) -> void:
	var text := MainHeroSkillText.description("%s造成<br/>[250%/400%/580%]伤害，持续[2/3/4]秒", "索菲亚", 2)
	test.assert_true(text.begins_with("索菲亚造成\n"), "source hero name and line break retained")
	test.assert_true(text.contains("[color=#34CD3F]400%[/color]") and text.contains("[color=#34CD3F]3[/color]"), "each value group highlights current skill level")
	test.assert_true(text.contains("[color=#989896]250%[/color]/") and text.contains("[color=#989896]580%[/color]"), "other levels remain visible in source gray")
	test.assert_true(not MainHeroSkillText.description("[1/2/3]", "英雄", 0).contains("#34CD3F"), "unlearned skill has no active level highlight")
	test.assert_true(MainHeroSkillText.description("%s", "[color=red]", 1).begins_with("[lb]color"), "hero names cannot inject BBCode")
	var op = preload("res://tests/test_main_systems.gd").new().fresh()
	var definitions: Dictionary = op.main_definitions()
	for talent: Dictionary in definitions.hero_talents.values():
		for token in String(talent.skills).split("|").slice(1):
			var id := int(token.get_slice(";",0))
			if int(token.get_slice(";",1)) > 0: continue
			var star := MainHeroSkillText.unlock_star(id, talent.source_id, definitions.hero_talents)
			test.assert_true(star > talent.star, "locked skill resolves to a later source talent star")
	for id: int in definitions.skill_art:
		var skill: Dictionary = definitions.skills[id]
		var rendered := MainHeroSkillText.description(skill.description, "英雄", 0)
		test.assert_true(not rendered.contains("%s") and not rendered.contains("<br/>") and not rendered.contains("#34CD3F"), "all source skill descriptions support locked preview")
