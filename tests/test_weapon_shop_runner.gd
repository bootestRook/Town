extends SceneTree
func _initialize() -> void:
	var t := TestSupport.new()
	preload("res://tests/test_equipment_shop.gd").new().run(t)
	print("WEAPON_SHOP ",JSON.stringify({"assertions":t.assertions,"failures":t.failures}))
	quit(0 if t.failures.is_empty() else 1)
