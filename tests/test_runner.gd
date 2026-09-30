extends SceneTree

const TestSupportScript = preload("res://tests/test_support.gd")
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeResourceScript = preload("res://src/runtime/ability/ability_graph_node_resource.gd")
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const NodeRegistryScript = preload("res://src/runtime/ability/ability_node_registry.gd")
const Suites := [
	preload("res://tests/test_region_levels.gd"),
	preload("res://tests/test_armor_shop.gd"),
	preload("res://tests/test_equipment_shop.gd"),
	preload("res://tests/test_town_loot.gd"),
	preload("res://tests/test_recruitment.gd"),
	preload("res://tests/test_diamond_shop.gd"),
	preload("res://tests/test_main_systems.gd"),
	preload("res://tests/test_hero_management.gd"),
	preload("res://tests/test_hero_camp.gd"),
	preload("res://tests/test_battle_horn.gd"),
	preload("res://tests/test_main_collections.gd"),
	preload("res://tests/test_main_combat.gd"),
	preload("res://tests/test_rng.gd"),
	preload("res://tests/test_data_and_assets.gd"),
	preload("res://tests/test_action_and_feature.gd"),
	preload("res://tests/test_ability_graph_execution.gd"),
	preload("res://tests/test_ability_graph_control.gd"),
	preload("res://tests/test_ability_graph_subgraphs.gd"),
	preload("res://tests/test_ability_graph_resources.gd"),
	preload("res://tests/test_core_framework.gd"),
	preload("res://tests/test_save.gd"),
	preload("res://tests/test_town.gd"),
	preload("res://tests/test_town_operations.gd"),
	preload("res://tests/test_town_heroes.gd"),
	preload("res://tests/test_town_attacks.gd"),
	preload("res://tests/test_town_navigation.gd"),
	preload("res://tests/test_town_world_rules.gd"),
	preload("res://tests/test_town_monster_population.gd"),
	preload("res://tests/test_town_waiting.gd"),
	preload("res://tests/test_town_roster.gd"),
	preload("res://tests/test_town_standby.gd"),
	preload("res://tests/test_town_acquisition.gd"),
	preload("res://tests/test_town_dispatch.gd"),
	preload("res://tests/test_town_focus.gd"),
	preload("res://tests/test_hero_information.gd"),
	preload("res://tests/test_hero_skill_text.gd"),
	preload("res://tests/test_hero_inventory.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test = TestSupportScript.new()
	for suite_script in Suites:
		suite_script.new().run(test)
	await _run_scene_smoke(test)
	if test.failures.is_empty():
		print("[OK] Godot tests: %d assertions" % test.assertions)
		quit(0)
		return
	for failure: String in test.failures:
		push_error("TEST FAILURE: %s" % failure)
	print("[FAIL] Godot tests: %d failure(s), %d assertions" % [test.failures.size(), test.assertions])
	quit(1)


func _run_scene_smoke(test: TestSupport) -> void:
	root.size = Vector2i(750, 1334)
	var packed: PackedScene = load("res://scenes/main.tscn")
	test.assert_true(packed != null, "main scene must load")
	if packed == null:
		return
	var app = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	test.assert_true(app.is_ready_for_use(), "composition root must boot")
	app.set_building_appearance("building.1", false)
	var before: Dictionary = app.town_snapshot()
	test.assert_equal(before.size(), 18, "town places all source buildings")
	app.set_building_appearance("building.1", true)
	await process_frame
	var after: Dictionary = app.town_snapshot()
	test.assert_true(not before["building.1"] and after["building.1"], "domain command updates building appearance state")
	await preload("res://tests/test_town_focus.gd").new().run_scene(test, app)
	app.queue_free()
	await process_frame
	await _run_editor_graph_smoke(test)


func _run_editor_graph_smoke(test: TestSupport) -> void:
	var graph := GraphResourceScript.new()
	graph.graph_id = "smoke.editor_graph"
	var entry := NodeResourceScript.new()
	entry.node_id = "entry"
	entry.type_id = NodeRegistryScript.ON_CAST_TYPE
	var action := NodeResourceScript.new()
	action.node_id = "action"
	action.type_id = NodeRegistryScript.EXECUTE_ACTION_TYPE
	action.parameters = {"action_id": "editor.placeholder"}
	var end := NodeResourceScript.new()
	end.node_id = "end"
	end.type_id = NodeRegistryScript.END_TYPE
	graph.add_node_resource(entry, Vector2(40, 80))
	graph.add_node_resource(action, Vector2(280, 80))
	graph.add_node_resource(end, Vector2(520, 80))
	var first_connection := ConnectionResourceScript.new()
	first_connection.from_node_id = "entry"
	first_connection.from_pin_id = "then"
	first_connection.to_node_id = "action"
	first_connection.to_pin_id = "in"
	graph.add_connection_resource(first_connection)
	var second_connection := ConnectionResourceScript.new()
	second_connection.from_node_id = "action"
	second_connection.from_pin_id = "then"
	second_connection.to_node_id = "end"
	second_connection.to_pin_id = "in"
	graph.add_connection_resource(second_connection)
	var editor_scene: PackedScene = ResourceLoader.load(
		"res://addons/combat_framework_editor/editor/ability_graph_editor.tscn",
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	var editor: Control = editor_scene.instantiate()
	root.add_child(editor)
	editor.initialize(null)
	editor.set_graph_resource(graph)
	await process_frame
	var graph_edit: GraphEdit = editor.get_node("Root/Body/GraphEdit")
	var dynamic_node_count := 0
	for child: Node in graph_edit.get_children():
		if child is GraphNode:
			dynamic_node_count += 1
	test.assert_equal(dynamic_node_count, 3, "editor canvas must project Resource nodes into GraphNode views")
	var candidates: Array = editor.call("_candidate_descriptors")
	test.assert_true(candidates.size() > 0, "editor must expose a non-empty node candidate menu")
	test.assert_true(editor.get_node("CandidateMenu") is PopupMenu, "editor must mount the context candidate menu")
	editor.call("_compile")
	var diagnostics: ItemList = editor.get_node("Root/Body/InspectorPanel/Diagnostics")
	test.assert_true(diagnostics.item_count > 0, "editor compile command must surface diagnostics")
	editor.call("apply_debug_snapshot", {"run_id": "smoke", "state": "running", "current_node_id": "action", "trace": [{"sequence": 1, "kind": "edge", "data": {"from_node_id": "entry", "to_node_id": "action", "output_pin": "then"}}], "event_trace": [{"event_type": "damage.applied", "logical_tick": 2, "error_code": ""}]})
	var trace_list: ItemList = editor.get_node("Root/Body/InspectorPanel/Trace")
	test.assert_equal(trace_list.item_count, 1, "editor must render the ability execution trace")
	var event_trace_list: ItemList = editor.get_node("Root/Body/InspectorPanel/EventTrace")
	test.assert_equal(event_trace_list.item_count, 1, "editor must render the core event trace")
	trace_list.item_selected.emit(0)
	test.assert_equal(editor.get("_debug_node_id"), "action", "trace selection must jump back to its graph node")
	editor.free()
	editor_scene = null
