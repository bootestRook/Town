extends "res://tests/support/ability_graph_fixture.gd"


func run(test: TestSupport) -> void:
	_test_bounded_repeat(test)
	_test_graph_variables(test)
	_test_multi_entry_event_trigger(test)
	_test_pipeline_event_bridge(test)
	_test_extension_manifest_registry(test)


func _test_bounded_repeat(test: TestSupport) -> void:
	var action_registry := _create_action_registry()
	var graph := _build_repeat_graph()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(compiled.accepted, "bounded repeat graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var context := FakeCombatContext.new()
	var run_instance := AbilityRunScript.new(compiled.plan, action_registry, ActionExecutorScript.new(), "run.repeat")
	var result = ActionExecutorScript.new().execute(run_instance, context)
	test.assert_true(result.accepted, "bounded repeat run must execute")
	test.assert_equal(context.value, 20, "bounded repeat must execute exactly its declared count")
	test.assert_equal(run_instance.state, AbilityRunScript.STATE_ENDED, "bounded repeat must reach done route")
	var branch_graph := _build_branch_graph()
	var branch_plan = GraphCompilerScript.new().compile(branch_graph, NodeRegistryScript.create_default(), action_registry)
	test.assert_true(branch_plan.accepted, "branch graph must compile")
	if branch_plan.accepted:
		var branch_context := FakeCombatContext.new()
		var branch_run := AbilityRunScript.new(branch_plan.plan, action_registry, ActionExecutorScript.new(), "run.branch")
		var branch_result = ActionExecutorScript.new().execute(branch_run, branch_context)
		test.assert_true(branch_result.accepted, "branch run must execute selected route")
		test.assert_equal(branch_context.value, 15, "branch condition must select the true route")


func _test_graph_variables(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.variables")
	graph.add_variable(GraphVariableScript.new("power", "float", 2.5, "save"))
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "graph variables must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	test.assert_equal(compiled.plan.variables().power.default_value, 2.5, "plan must preserve variable defaults")
	var run_instance := AbilityRunScript.new(compiled.plan, registry, ActionExecutorScript.new(), "run.variables")
	var result = ActionExecutorScript.new().execute(run_instance, FakeCombatContext.new())
	test.assert_true(result.accepted, "variable graph must execute")
	test.assert_equal(run_instance.execution_snapshot().values.power, 2.5, "run must initialize variable defaults")
	var mutation_graph := GraphDefinitionScript.new("test.variable_mutation")
	mutation_graph.add_variable(GraphVariableScript.new("power", "float", 2.5, "transient"))
	mutation_graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	mutation_graph.add_node(NodeDefinitionScript.new("write", NodeRegistryScript.WRITE_VARIABLE_TYPE, AbilityNodeConfigurationScript.new({"variable_id": "power", "value": 7.0})))
	mutation_graph.add_node(NodeDefinitionScript.new("read", NodeRegistryScript.READ_VARIABLE_TYPE, AbilityNodeConfigurationScript.new({"variable_id": "power"})))
	mutation_graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "write", "in"))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("write", "then", "read", "in"))
	mutation_graph.add_connection(ConnectionDefinitionScript.new("read", "then", "end", "in"))
	var mutation = GraphCompilerScript.new().compile(mutation_graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(mutation.accepted, "variable read/write graph must compile: %s" % mutation.error_code)
	if mutation.accepted:
		var mutation_run := AbilityRunScript.new(mutation.plan, registry, ActionExecutorScript.new(), "run.variable_mutation")
		var mutation_result = ActionExecutorScript.new().execute(mutation_run, FakeCombatContext.new())
		test.assert_true(mutation_result.accepted, "variable read/write graph must execute")
		test.assert_equal(mutation_run.execution_snapshot().values.power, 7.0, "variable write must update run-local state")


func _test_multi_entry_event_trigger(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.multi_entry")
	graph.add_node(NodeDefinitionScript.new("cast", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit", NodeRegistryScript.ON_HIT_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit_action", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	graph.add_node(NodeDefinitionScript.new("cast_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("hit_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("cast", "then", "cast_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("hit", "then", "hit_action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("hit_action", "then", "hit_end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "multiple event entries must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	test.assert_equal(compiled.plan.entry_node_ids("hit.resolved"), ["hit"], "hit entry must be indexed by the hit-resolution event type")
	var state := CoreStateScript.new()
	state.create_entity("source")
	var service := AbilityServiceScript.new(state, registry, ActionExecutorScript.new())
	var definition := AbilityDefinitionScript.new("ability.multi", "test.multi_entry")
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "multi-entry ability must register")
	var grant_handle: String = service.grant("source", "ability.multi", "fixture")
	var context := FakeCombatContext.new()
	var event := DomainEventScript.new("hit.resolved", {}, "hit.event", 0, 1, "source", [])
	var results := service.trigger_event(event, context)
	test.assert_equal(results.size(), 1, "event trigger must create one entry run")
	if not results.is_empty():
		test.assert_true(results[0].accepted, "event entry run must execute")
	test.assert_equal(context.value, 15, "event entry must route into its action")
	test.assert_equal(service.active_run_ids(), [], "finished event run must not leak active state")
	test.assert_equal(service.revoke("source", grant_handle), "", "event ability grant must revoke")


func _test_pipeline_event_bridge(test: TestSupport) -> void:
	var graph := GraphDefinitionScript.new("test.pipeline_bridge")
	graph.add_node(NodeDefinitionScript.new("hit", NodeRegistryScript.ON_HIT_TYPE, AbilityNodeConfigurationScript.new({"event_type": "test.committed"})))
	graph.add_node(NodeDefinitionScript.new("mark", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.mark_event")))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("hit", "then", "mark", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("mark", "then", "end", "in"))
	var registry := _create_action_registry()
	var compiled = GraphCompilerScript.new().compile(graph, NodeRegistryScript.create_default(), registry)
	test.assert_true(compiled.accepted, "pipeline bridge graph must compile: %s" % compiled.error_code)
	if not compiled.accepted:
		return
	var state := CoreStateScript.new()
	var source = state.create_entity("source")
	var pipeline := EventPipelineScript.new()
	pipeline.register("event.request", BridgeCommitHandler.new())
	var service := AbilityServiceScript.new(state, registry, ActionExecutorScript.new(), null, pipeline)
	var definition := AbilityDefinitionScript.new("ability.bridge", "test.pipeline_bridge")
	test.assert_equal(service.register_definition(definition, compiled.plan), "", "pipeline bridge ability must register")
	service.grant("source", "ability.bridge", "fixture")
	var dispatch_result = pipeline.dispatch(EventRequestScript.new("event.request", {}, "source", []), 3)
	test.assert_true(dispatch_result.accepted, "pipeline observer must preserve event dispatch")
	test.assert_true(source.tags.has_tag("event.seen"), "committed pipeline event must trigger matching ability entry")
	test.assert_equal(service.detach_pipeline(), "", "ability service must detach its event observer")


func _test_extension_manifest_registry(test: TestSupport) -> void:
	var framework := FrameworkRegistryScript.new()
	var descriptor := NodeDescriptorScript.new("project.test.logic.sequence", "sequence", ["in"], ["then"], false, false, "Project", "Project Sequence")
	var manifest := ExtensionManifestScript.new("project.test", 1, [descriptor], {"project.test.mark": MarkEventResolver.new()})
	test.assert_equal(framework.register_manifest(manifest), "", "project extension manifest must register explicitly")
	test.assert_equal(framework.manifest_ids(), ["project.test"], "framework registry must expose deterministic manifest IDs")
	test.assert_true(framework.node_registry.has_descriptor("project.test.logic.sequence"), "extension node must enter shared catalog")
	test.assert_true(framework.action_registry.has_action("project.test.mark"), "extension action must enter shared registry")
