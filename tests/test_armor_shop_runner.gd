extends SceneTree
func _initialize() -> void:
	var t := TestSupport.new()
	preload("res://tests/test_armor_shop.gd").new().run(t)
	print("ARMOR_SHOP ",JSON.stringify({"assertions":t.assertions,"failures":t.failures}))
	quit(0 if t.failures.is_empty() else 1)
