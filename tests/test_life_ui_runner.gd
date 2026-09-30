extends SceneTree


func _initialize() -> void:
	var test := TestSupport.new()
	preload("res://tests/test_town_operations.gd").new().run(test)
	for failure: String in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("LIFE_RULES_RESULT ", JSON.stringify({"failures": test.failures, "assertions": test.assertions}))
	quit(0 if test.failures.is_empty() else 1)
