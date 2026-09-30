extends RefCounted

const Registry = preload("res://src/data/data_registry.gd")
const Feature = preload("res://src/features/town/domain/town_feature.gd")


func run(test: TestSupport) -> void:
	var data = Registry.new()
	test.assert_equal(data.load_default(), "", "town data loads")
	var rows: Array = data.rows("town_buildings")
	var feature = Feature.new(rows)
	var snapshot: Dictionary = feature.snapshot()
	var before_count := 0
	for row: Dictionary in rows:
		if not String(row.before_resource).is_empty():
			before_count += 1
			test.assert_true(row.before_resource != row.built_resource, "construction uses distinct source art")
		else:
			test.assert_true(snapshot[row.id], "buildings without ruins start built")
	test.assert_equal(before_count, 15, "all fifteen repairable buildings retain ruin art")
	test.assert_equal(data.rows("town_backgrounds").size(), 6, "six map panels")
	test.assert_equal(data.rows("town_scenery").size(), 55, "road and scenery source placements")
	test.assert_true(not feature.set_built("missing", true).accepted, "unknown ID cannot mutate state")
	test.assert_true(not feature.set_built("building.5", false).accepted, "cannot invent missing ruin art")
	snapshot["building.1"] = true
	test.assert_true(not feature.snapshot()["building.1"], "snapshot mutation cannot alter domain")
	rows[0]["before_resource"] = ""
	test.assert_true(feature.set_built("building.1", true).accepted, "building may be completed")
	test.assert_true(feature.set_built("building.1", false).accepted, "definition copy protects reversible appearance")
	test.assert_equal(feature.set_built("building.1", false).events.size(), 0, "unchanged intent creates no false fact")
