extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test := TestSupport.new()
	preload("res://tests/test_main_systems.gd").new().run(test)
	preload("res://tests/test_main_collections.gd").new().run(test)
	preload("res://tests/test_main_combat.gd").new().run(test)
	for failure: String in test.failures: push_error(failure)
	print("[%s] Main systems: %d assertions" % ["OK" if test.failures.is_empty() else "FAIL", test.assertions])
	quit(0 if test.failures.is_empty() else 1)
