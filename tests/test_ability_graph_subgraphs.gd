extends "res://tests/support/ability_graph_fixture.gd"


func run(test: TestSupport) -> void:
	_test_synchronous_subgraph(test)
	_test_owned_async_subgraph(test)


func _test_synchronous_subgraph(test: TestSupport) -> void:
	var registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var child = compiler.compile(_build_linear_graph("test.child", ["test.increment"]), NodeRegistryScript.create_default(), registry)
	test.assert_true(child.accepted, "subgraph child must compile")
	if not child.accepted:
		return
	var catalog := SubgraphCatalogScript.new()
	test.assert_equal(catalog.register("test.child", child.plan), "", "subgraph catalog must register a plan")
	var parent := GraphDefinitionScript.new("test.parent")
	parent.add_subgraph_ref(SubgraphReferenceScript.new("test.child"))
	parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.child"})))
	parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
	parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
	var compiled = compiler.compile(parent, NodeRegistryScript.create_default(), registry, catalog)
	test.assert_true(compiled.accepted, "declared subgraph call must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent", null, catalog)
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "synchronous subgraph must execute")
	test.assert_equal(context.value, 15, "subgraph child must execute through parent context")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "synchronous subgraph must return to parent")


func _test_owned_async_subgraph(test: TestSupport) -> void:
	var registry := _create_action_registry()
	var compiler := GraphCompilerScript.new()
	var child = compiler.compile(_build_delay_graph(), NodeRegistryScript.create_default(), registry)
	test.assert_true(child.accepted, "async subgraph child must compile")
	if not child.accepted:
		return
	var catalog := SubgraphCatalogScript.new()
	test.assert_equal(catalog.register("test.delay", child.plan), "", "async subgraph must register")
	var parent := GraphDefinitionScript.new("test.parent_async")
	parent.add_subgraph_ref(SubgraphReferenceScript.new("test.delay"))
	parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.delay"})))
	parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
	parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
	var compiled = compiler.compile(parent, NodeRegistryScript.create_default(), registry, catalog)
	test.assert_true(compiled.accepted, "owned async subgraph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := ExecutionContextScript.new()
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async", null, catalog)
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "owned async subgraph activation must return a wait token")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_WAITING, "parent must own child wait state")
	var snapshot := run_instance.save_state()
	var restored := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async.restore", null, catalog)
	test.assert_equal(restored.restore_state(snapshot), "", "owned child wait must restore from parent snapshot")
	test.assert_equal(restored.tick(1).error_code, "ability_wait_not_ready", "child delay must retain its deadline")
	var resumed = restored.tick(2)
	test.assert_true(resumed.accepted, "parent must resume after owned child completes")
	test.assert_equal(restored.state, AbilityRunScript.STATE_ENDED, "owned child completion must advance parent")
	var cancellable := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.parent_async.cancel", null, catalog)
	ActionExecutorScript.new().execute(cancellable, ExecutionContextScript.new())
	test.assert_equal(cancellable.cancel_scope("run"), "", "parent scope cancellation must be accepted")
	test.assert_equal(cancellable.state, AbilityRunScript.STATE_CANCELLED, "parent scope cancellation must cancel owned child")
	var event_child = compiler.compile(_build_wait_graph(), NodeRegistryScript.create_default(), registry)
	test.assert_true(event_child.accepted, "event-wait subgraph must compile")
	if event_child.accepted:
		var event_catalog := SubgraphCatalogScript.new()
		test.assert_equal(event_catalog.register("test.wait", event_child.plan), "", "event-wait subgraph must register")
		var event_parent := GraphDefinitionScript.new("test.parent_event")
		event_parent.add_subgraph_ref(SubgraphReferenceScript.new("test.wait"))
		event_parent.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
		event_parent.add_node(NodeDefinitionScript.new("call", NodeRegistryScript.SUBGRAPH_CALL_TYPE, AbilityNodeConfigurationScript.new({"graph_id": "test.wait"})))
		event_parent.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
		event_parent.add_connection(ConnectionDefinitionScript.new("entry", "then", "call", "in"))
		event_parent.add_connection(ConnectionDefinitionScript.new("call", "then", "end", "in"))
		var event_compiled = compiler.compile(event_parent, NodeRegistryScript.create_default(), registry, event_catalog)
		test.assert_true(event_compiled.accepted, "event-wait parent must compile")
		if event_compiled.accepted:
			var event_run := AbilityRunScript.new(event_compiled.plan, registry, ActionExecutorScript.new(), "run.parent_event", null, event_catalog)
			ActionExecutorScript.new().execute(event_run, ExecutionContextScript.new())
			test.assert_equal(event_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "normal"})).error_code, "ability_event_filter_not_matched", "owned child must preserve event filters")
			test.assert_true(event_run.resume_event(DomainEventScript.new("damage.applied", {"kind": "critical"})).accepted, "owned child must resume from matching committed event")
			test.assert_equal(event_run.state, AbilityRunScript.STATE_ENDED, "owned event child completion must advance parent")
