extends "res://tests/support/ability_graph_fixture.gd"


func run(test: TestSupport) -> void:
	_test_compiles_and_executes_linear_graph(test)
	_test_compile_time_rejections(test)
	_test_ability_run_rolls_back_as_one_transaction(test)
	_test_typed_target_value_flow_and_delay(test)


func _test_compiles_and_executes_linear_graph(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var graph := _build_linear_graph("test.linear", ["test.increment"])
	var first_compile = compiler.compile(graph, NodeRegistryScript.create_default(), action_registry)
	var second_compile = compiler.compile(graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(first_compile.accepted, "valid ability graph must compile: %s" % first_compile.error_code)
	test.assert_true(second_compile.accepted, "same ability graph must compile repeatedly")
	if not first_compile.accepted or not second_compile.accepted:
		return
	test.assert_equal(
		first_compile.plan.operation_order(),
		second_compile.plan.operation_order(),
		"ability compilation order must be deterministic"
	)
	test.assert_equal(
		first_compile.plan.operation_order(),
		["entry", "action_0", "end"],
		"linear graph must compile to its control order"
	)

	var executor := ActionExecutorScript.new()
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(
		first_compile.plan, action_registry, executor, "run.linear.1"
	)
	var result = executor.execute(run_instance, context)
	test.assert_true(result.accepted, "compiled ability run must execute: %s" % result.error_code)
	test.assert_equal(context.value, 15, "ability action must change combat context")
	test.assert_equal(result.events.size(), 1, "ability run must forward child action events")
	test.assert_equal(run_instance.state, "ended", "successful ability run must end")
	test.assert_equal(
		run_instance.visited_node_ids,
		["entry", "action_0", "end"],
		"ability run must expose visited nodes for debugging"
	)
	test.assert_true(run_instance.execution_snapshot().trace.size() >= 2, "ability run must retain executed edge trace")
	test.assert_equal(run_instance.execution_snapshot().active_edge.to_node_id, "end", "ability snapshot must expose active edge")
	var debug_registry := AbilityDebugRegistryScript.new()
	test.assert_equal(debug_registry.register_run(run_instance, "entity_a"), "", "debug registry must register active runs")
	test.assert_equal(debug_registry.select_run("run.linear.1"), "", "debug registry must select a run explicitly")
	var debug_snapshot = debug_registry.snapshot("run.linear.1", 4)
	test.assert_equal(debug_snapshot.current_node_id, "end", "debug snapshot must expose current node")
	test.assert_equal(debug_snapshot.owner_entity_id, "entity_a", "debug snapshot must expose run owner")
	test.assert_equal(debug_registry.unregister_run("run.linear.1"), "", "debug registry must release finished runs")
	var repeated = executor.execute(run_instance, context)
	test.assert_equal(repeated.error_code, "ability_run_not_ready", "ability run is single-use")


func _test_compile_time_rejections(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var unknown_type_graph := GraphDefinitionScript.new("test.unknown_type")
	unknown_type_graph.add_node(NodeDefinitionScript.new("mystery", "project.unknown_node"))
	var unknown_type = compiler.compile(
		unknown_type_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(unknown_type.error_code, "unknown_node_type", "unknown node type must fail compile")
	test.assert_equal(unknown_type.node_id, "mystery", "compile errors must preserve source node id")
	var terminal_missing_graph := GraphDefinitionScript.new("test.terminal_missing")
	terminal_missing_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	var terminal_missing = compiler.compile(terminal_missing_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(terminal_missing.error_code, "terminal_missing", "ability graph must declare a terminal")

	var bad_pin_graph := _build_linear_graph("test.bad_pin", ["test.increment"])
	bad_pin_graph.connections[0].from_pin_id = "missing_pin"
	var bad_pin = compiler.compile(
		bad_pin_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(bad_pin.error_code, "unknown_output_pin", "unknown pin must fail compile")
	test.assert_equal(bad_pin.pin_id, "missing_pin", "compile errors must preserve source pin id")

	var unknown_action_graph := _build_linear_graph("test.unknown_action", ["project.missing"])
	var unknown_action = compiler.compile(
		unknown_action_graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_equal(unknown_action.error_code, "unknown_action", "unknown action must fail compile")
	test.assert_equal(unknown_action.node_id, "action_0", "unknown action must identify its graph node")

	var cycle_graph := _build_cycle_graph()
	var cycle = compiler.compile(cycle_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(cycle.error_code, "control_cycle", "control cycles must fail compile")
	var typed_graph := GraphDefinitionScript.new("test.pin_type")
	typed_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	typed_graph.add_node(NodeDefinitionScript.new("select", NodeRegistryScript.SELECT_TARGET_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	typed_graph.add_node(NodeDefinitionScript.new("damage", NodeRegistryScript.DEAL_DAMAGE_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	typed_graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	typed_graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "select", "in"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("select", "then", "damage", "in"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("select", "targets", "damage", "amount", "value"))
	typed_graph.add_connection(ConnectionDefinitionScript.new("damage", "then", "end", "in"))
	var typed_result = compiler.compile(typed_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_equal(typed_result.error_code, "pin_value_type_mismatch", "typed value pin mismatch must fail compile")


func _test_ability_run_rolls_back_as_one_transaction(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var graph := _build_linear_graph("test.rollback", ["test.increment", "test.reject"])
	var compiled = GraphCompilerScript.new().compile(
		graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_true(compiled.accepted, "rollback test graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var executor := ActionExecutorScript.new()
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(
		compiled.plan, action_registry, executor, "run.rollback.1"
	)
	var result = executor.execute(run_instance, context)
	test.assert_equal(result.error_code, "ability_action_failed", "failed child action must reject ability run")
	test.assert_equal(context.value, 10, "failed ability run must roll back all earlier child actions")
	test.assert_equal(run_instance.state, "failed", "rejected ability run must retain failed debug state")
	test.assert_equal(
		run_instance.last_error_code,
		"forced_failure",
		"ability run debug state must retain child failure code"
	)


func _test_typed_target_value_flow_and_delay(test: TestSupport) -> void:
	var state := CoreStateScript.new()
	var source = state.create_entity("source")
	var target = state.create_entity("target")
	target.attributes.register_definition(AttributeDefinitionScript.new("health", 100.0, 0.0, 100.0))
	var pipeline := preload("res://src/runtime/core/core_event_pipeline.gd").new()
	var damage := DamageModuleScript.new(state, pipeline)
	damage.register()
	var action_registry := _create_action_registry()
	action_registry.register_action("module.target.select", TargetActionResolverScript.new())
	damage.register_actions(action_registry)
	var targets := TargetRegistryScript.new()
	test.assert_equal(targets.register_builtins(), "", "target registry builtins must register explicitly")
	var graph := GraphDefinitionScript.new("test.typed_target")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"select",
			NodeRegistryScript.SELECT_TARGET_TYPE,
			ActionNodeConfigurationScript.new("module.target.select", {"target_type": "explicit", "entity_ids": ["target"]})
		)
	)
	graph.add_node(
		NodeDefinitionScript.new(
			"damage",
			NodeRegistryScript.DEAL_DAMAGE_TYPE,
			ActionNodeConfigurationScript.new("module.damage.deal", {"amount": 25.0})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "select", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("select", "then", "damage", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("select", "targets", "damage", "targets", "value"))
	graph.add_connection(ConnectionDefinitionScript.new("damage", "then", "end", "in"))
	var compiled = GraphCompilerScript.new().compile(
		graph, NodeRegistryScript.create_default(), action_registry
	)
	test.assert_true(compiled.accepted, "typed target/value graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
	var run_instance := AbilityRunScript.new(compiled.plan, action_registry, ActionExecutorScript.new(), "run.typed")
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "typed target/value graph must execute")
	test.assert_equal(target.attributes.value("health"), 75.0, "target output must feed damage action")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "typed graph must end")

	var delay_graph := _build_delay_graph()
	var delay_plan = GraphCompilerScript.new().compile(delay_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(delay_plan.accepted, "delay graph must compile")
	if delay_plan.accepted:
		var delay_run := AbilityRunScript.new(delay_plan.plan, action_registry, ActionExecutorScript.new(), "run.delay")
		var delay_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [target.entity_id], targets)
		var delay_result = ActionExecutorScript.new().execute(delay_run, delay_context)
		test.assert_true(delay_result.accepted, "delay run should suspend successfully")
		test.assert_equal(delay_run.state, AbilityRunScript.STATE_WAITING, "delay must enter waiting state")
		var scope_id := delay_run.open_cancel_scope("delay_scope")
		test.assert_equal(scope_id, "delay_scope", "ability run must open a named cancel scope")
		test.assert_equal(delay_run.current_scope_id(), "delay_scope", "new scope must become current")
		test.assert_equal(delay_run.cancel_scope(scope_id), "", "ability run must close a cancel scope")
		test.assert_equal(delay_run.current_scope_id(), "run", "scope close must restore parent scope")
		var saved_delay: Dictionary = delay_run.save_state()
		var restored_delay := AbilityRunScript.new(delay_plan.plan, action_registry, ActionExecutorScript.new(), "run.delay.restored")
		test.assert_equal(restored_delay.restore_state(saved_delay), "", "ability run save state must restore against the same plan")
		test.assert_equal(restored_delay.state, AbilityRunScript.STATE_WAITING, "restored ability run must retain wait state")
		delay_context.logical_tick = 2
		var resumed = delay_run.tick(2)
		test.assert_true(resumed.accepted, "delay run must resume at its deadline")
		test.assert_equal(delay_run.state, AbilityRunScript.STATE_ENDED, "resumed delay run must end")

	var wait_graph := _build_wait_graph()
	var wait_plan = GraphCompilerScript.new().compile(wait_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(wait_plan.accepted, "wait graph must compile")
	if wait_plan.accepted:
		var wait_run := AbilityRunScript.new(wait_plan.plan, action_registry, ActionExecutorScript.new(), "run.wait")
		var wait_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
		var wait_result = ActionExecutorScript.new().execute(wait_run, wait_context)
		test.assert_true(wait_result.accepted, "wait run should suspend successfully")
		test.assert_equal(wait_run.state, AbilityRunScript.STATE_WAITING, "wait event must enter waiting state")
		var wrong_event_result = wait_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "normal"}))
		test.assert_equal(wrong_event_result.error_code, "ability_event_filter_not_matched", "wait event filter must reject mismatched payloads")
		var event_result = wait_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "critical"}))
		test.assert_true(event_result.accepted, "matching committed event must resume wait")
		test.assert_equal(wait_run.state, AbilityRunScript.STATE_ENDED, "resumed wait run must end")

	var timeout_graph := _build_wait_timeout_graph()
	var timeout_plan = GraphCompilerScript.new().compile(timeout_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(timeout_plan.accepted, "wait timeout graph must compile")
	if timeout_plan.accepted:
		var timeout_run := AbilityRunScript.new(timeout_plan.plan, action_registry, ActionExecutorScript.new(), "run.wait_timeout")
		var timeout_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [], targets)
		var timeout_result = ActionExecutorScript.new().execute(timeout_run, timeout_context)
		test.assert_true(timeout_result.accepted, "wait timeout run must suspend")
		test.assert_equal(timeout_run.tick(1).accepted, true, "wait timeout must resume on its deadline")
		test.assert_equal(timeout_run.state, AbilityRunScript.STATE_ENDED, "wait timeout must follow timeout route")
