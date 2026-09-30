class_name MainHeroSkillText
extends RefCounted


static func description(source: String, hero_name: String, level: int) -> String:
	var groups := RegEx.new()
	groups.compile("\\[([^\\]]+)\\]")
	var result := ""
	var offset := 0
	for group: RegExMatch in groups.search_all(source):
		result += source.substr(offset, group.get_start() - offset)
		var values := group.get_string(1).split("/")
		for i in values.size():
			if i > 0: result += "/"
			result += "[color=%s]%s[/color]" % ["#34CD3F" if i + 1 == level else "#989896", values[i]]
		offset = group.get_end()
	result += source.substr(offset)
	return result.replace("<br/>", "\n").replace("%s", hero_name.replace("[", "[lb]"))


static func unlock_star(skill: int, talent_id: float, talents: Dictionary) -> int:
	while talent_id > 0:
		var talent: Dictionary = talents[talent_id]
		for token in String(talent.skills).split("|"):
			if int(token.get_slice(";", 0)) == skill and int(token.get_slice(";", 1)) > 0:
				return int(talent.star)
		talent_id = talent.next_id
	return 0
