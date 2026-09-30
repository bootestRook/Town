extends "res://tests/support/ability_graph_fixture.gd"


func run(test: TestSupport) -> void:
	_test_resource_roundtrip_and_editor_commands(test)
	_test_ability_grant_cost_and_cooldown(test)


func _test_resource_roundtrip_and_editor_commands(test: TestSupport) -> void:
	var sample: Resource = ResourceLoader.load(
		"res://authoring/combat/ability_graphs/example_on_cast.tres",
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	test.assert_true(sample is GraphResourceScript, "sample authoring graph must load as AbilityGraphResource")
	if sample is GraphResourceScript:
		test.assert_equal(sample.graph_id, "example.on_cast", "sample graph must preserve stable graph id")
	test.assert_equal(sample.nodes.size(), 3, "sample graph must contain the minimal ability path")
	var plan_catalog := AbilityPlanCatalogScript.new()
	test.assert_equal(plan_catalog.load_default(), "", "generated ability plan catalog must load")
	test.assert_equal(plan_catalog.graph_ids(), ["example.on_cast"], "plan catalog must expose deterministic graph ids")
	test.assert_true(plan_catalog.has_plan("example.on_cast"), "generated plan catalog must satisfy subgraph lookup contract")
	test.assert_equal(
		plan_catalog.plan("example.on_cast").operation_order(),
		["entry", "action", "end"],
		"generated plan must preserve compiled operation order"
	)
	var graph := GraphResourceScript.new()
	graph.graph_id = "test.resource_roundtrip"
	var entry := NodeResourceScript.new()
	entry.node_id = "entry"
	entry.type_id = NodeRegistryScript.ON_CAST_TYPE
	var action := NodeResourceScript.new()
	action.node_id = "action"
	action.type_id = NodeRegistryScript.EXECUTE_ACTION_TYPE
	action.parameters = {"action_id": "test.increment"}
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
	var path := "user://ability_graph_resource_roundtrip.tres"
	var save_error: Error = ResourceSaver.save(graph, path)
	test.assert_equal(save_error, OK, "AbilityGraphResource must save as text Resource")
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	test.assert_true(loaded is GraphResourceScript, "saved graph must load as AbilityGraphResource")
	if loaded is GraphResourceScript:
		test.assert_equal(
			loaded.document_snapshot(),
			graph.document_snapshot(),
			"AbilityGraphResource save/load must preserve semantic graph and layout"
		)

	var undo_redo := UndoRedo.new()
	var controller := DocumentControllerScript.new(undo_redo)
	controller.set_resource(graph)
	test.assert_equal(
		controller.add_node(NodeRegistryScript.END_TYPE, Vector2(700, 80)),
		"",
		"editor controller must add nodes through a command"
	)
	test.assert_true(graph.nodes.size() == 4, "editor command must update Resource model")
	undo_redo.undo()
	test.assert_true(graph.nodes.size() == 3, "editor command must undo Resource mutation")
	undo_redo.redo()
	test.assert_true(graph.nodes.size() == 4, "editor command must redo Resource mutation")
	test.assert_equal(controller.edit_parameters("action", {"action_id": "test.increment", "amount": 5}), "", "editor parameter command must update typed payload")
	test.assert_equal(graph.node_by_id("action").parameters.amount, 5, "editor parameter command must preserve numeric values")
	test.assert_equal(controller.batch_edit_parameters(["action"], {"amount": 9}), "", "editor batch refactor must use one command")
	test.assert_equal(graph.node_by_id("action").parameters.amount, 9, "editor batch refactor must update selected nodes")
	undo_redo.undo()
	test.assert_equal(graph.node_by_id("action").parameters.amount, 5, "editor batch refactor must undo atomically")
	undo_redo.redo()
	test.assert_equal(controller.edit_comment("action", "Apply the configured hit amount"), "", "editor comment command must update document metadata")
	test.assert_equal(graph.node_comment("action"), "Apply the configured hit amount", "graph resource must preserve node comments")
	var frame_id: String = controller.add_frame("Damage Sequence", Vector2(20, 20))
	test.assert_true(graph.frames.size() == 1, "editor frame command must add a serialized frame")
	test.assert_equal(controller.edit_frame(frame_id, {"title": "Damage Flow"}), "", "editor frame command must edit frame metadata")
	test.assert_equal(graph.frames[0].title, "Damage Flow", "frame title edit must preserve metadata")
	test.assert_equal(controller.remove_frame(frame_id), "", "editor frame command must remove by stable frame id")
	var copy := controller.copy_payload(["action"])
	var pasted := controller.paste_payload(copy, Vector2(40, 40))
	test.assert_equal(pasted.size(), 1, "editor clipboard must paste one remapped node")
	test.assert_true(graph.node_by_id(pasted[0]) != null, "pasted node must receive a stable new id")
	controller.set_resource(null)
	undo_redo.clear_history()
	controller = null
	undo_redo.free()
	undo_redo = null
	loaded = null
	sample = null
	graph = null


func _test_ability_grant_cost_and_cooldown(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var compiled = compiler.compile(
		_build_linear_graph("test.service", ["test.increment"]),
		NodeRegistryScript.create_default(),
		action_registry
	)
	test.assert_true(compiled.accepted, "ability service fixture must compile")
	if not compiled.accepted:
		return
	var state := CoreStateScript.new()
	var entity = state.create_entity("caster")
	entity.attributes.register_definition(AttributeDefinitionScript.new("mana", 10.0, 0.0, 10.0))
	var executor := ActionExecutorScript.new()
	var service := AbilityServiceScript.new(state, action_registry, executor)
	var definition := AbilityDefinitionScript.new("ability.test", "test.service", 2, {"mana": 3.0})
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "ability definition must bind to compiled plan")
	var grant_handle: String = service.grant("caster", "ability.test", "loadout")
	test.assert_not_empty(grant_handle, "ability grant must return a stable handle")
	var context := FakeCombatContext.new()
	var first = service.activate("caster", grant_handle, context)
	test.assert_true(first.accepted, "granted ability must activate")
	test.assert_equal(entity.attributes.value("mana"), 7.0, "ability activation must commit declared cost")
	var blocked = service.activate("caster", grant_handle, context)
	test.assert_equal(blocked.error_code, "ability_on_cooldown", "ability must reject before cooldown expiry")
	state.advance_tick()
	var still_blocked = service.activate("caster", grant_handle, context)
	test.assert_equal(still_blocked.error_code, "ability_on_cooldown", "cooldown uses explicit logical ticks")
	state.advance_tick()
	var second = service.activate("caster", grant_handle, context)
	test.assert_true(second.accepted, "ability must activate after cooldown tick")
	test.assert_equal(entity.attributes.value("mana"), 4.0, "second activation must pay the next cost")
	test.assert_equal(service.revoke("caster", grant_handle), "", "ability grant must revoke by stable handle")
	var wait_compiled = compiler.compile(_build_delay_graph(), NodeRegistryScript.create_default(), action_registry)
	var wait_definition := AbilityDefinitionScript.new("ability.wait", "test.delay")
	test.assert_equal(service.register_definition(wait_definition, wait_compiled.plan), "", "waiting ability must register")
	var wait_handle: String = service.grant("caster", "ability.wait", "loadout")
	var wait_context := ExecutionContextScript.new(state, null, "caster", [])
	var wait_activation = service.activate("caster", wait_handle, wait_context)
	test.assert_true(wait_activation.accepted, "waiting ability must activate")
	var service_snapshot: Dictionary = service.snapshot()
	var waiting_run_ids := service.active_run_ids()
	test.assert_equal(waiting_run_ids.size(), 1, "waiting ability must be included in service snapshot")
	test.assert_equal(service.restore(service_snapshot, {waiting_run_ids[0]: wait_context}), "", "service snapshot must restore active runs")
	test.assert_equal(service.active_run_ids(), waiting_run_ids, "service restore must preserve active run IDs")
	test.assert_equal(service.run(waiting_run_ids[0]).state, AbilityRunScript.STATE_WAITING, "service restore must preserve wait state")
	service.cancel_run(waiting_run_ids[0])
	service.revoke("caster", wait_handle)
