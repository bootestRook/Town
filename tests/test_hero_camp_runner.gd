extends SceneTree

func _initialize() -> void:
	var test := TestSupport.new()
	preload("res://tests/test_hero_camp.gd").new().run(test)
	print("HERO_CAMP_RULES ", JSON.stringify({"assertions":test.assertions,"failures":test.failures}))
	quit(0 if test.failures.is_empty() else 1)
