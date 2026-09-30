extends RefCounted

const ActionExecutorScript = preload("res://src/runtime/action_executor.gd")
const ActionResultScript = preload("res://src/runtime/action_result.gd")
const GraphDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_definition.gd"
)
const NodeDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_node_definition.gd"
)
const ConnectionDefinitionScript = preload(
	"res://src/runtime/ability/ability_graph_connection_definition.gd"
)
const ActionNodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_action_node_configuration.gd"
)
const AbilityNodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_node_configuration.gd"
)
const NodeRegistryScript = preload(
	"res://src/runtime/ability/ability_node_registry.gd"
)
const ActionRegistryScript = preload(
	"res://src/runtime/ability/ability_action_registry.gd"
)
const GraphCompilerScript = preload(
	"res://src/runtime/ability/ability_graph_compiler.gd"
)
const AbilityRunScript = preload(
	"res://src/runtime/ability/ability_run.gd"
)
const AbilityDebugRegistryScript = preload(
	"res://src/runtime/ability/ability_debug_registry.gd"
)
const AbilityDefinitionScript = preload("res://src/runtime/ability/ability_definition.gd")
const AbilityServiceScript = preload("res://src/runtime/ability/ability_service.gd")
const AbilityPlanCatalogScript = preload("res://src/runtime/ability/ability_plan_catalog.gd")
const AttributeDefinitionScript = preload("res://src/runtime/core/core_attribute_definition.gd")
const CoreStateScript = preload("res://src/runtime/core/core_state.gd")
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeResourceScript = preload("res://src/runtime/ability/ability_graph_node_resource.gd")
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const DocumentControllerScript = preload(
	"res://addons/combat_framework_editor/editor/ability_graph_document_controller.gd"
)
const ExecutionContextScript = preload("res://src/runtime/core/core_execution_context.gd")
const TargetRegistryScript = preload("res://src/runtime/core/core_target_resolver_registry.gd")
const TargetActionResolverScript = preload("res://src/runtime/ability/ability_target_action_resolver.gd")
const DamageModuleScript = preload("res://src/runtime/modules/damage/damage_module.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const EventRequestScript = preload("res://src/runtime/core/core_event_request.gd")
const EventHandlerResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")
const EventPipelineScript = preload("res://src/runtime/core/core_event_pipeline.gd")
const NodeDescriptorScript = preload("res://src/runtime/ability/ability_node_descriptor.gd")
const ExtensionManifestScript = preload("res://src/runtime/ability/ability_extension_manifest.gd")
const FrameworkRegistryScript = preload("res://src/runtime/ability/ability_framework_registry.gd")
const SubgraphReferenceScript = preload("res://src/runtime/ability/ability_subgraph_reference.gd")
const SubgraphCatalogScript = preload("res://src/runtime/ability/ability_subgraph_catalog.gd")
const GraphVariableScript = preload(
	"res://src/runtime/ability/ability_graph_variable_definition.gd"
)


class FakeCombatContext extends RefCounted:
	var value: int = 10

	func snapshot_state() -> Dictionary:
		return {"value": value}

	func restore_state(snapshot: Dictionary) -> String:
		value = int(snapshot.value)
		return ""


class AbilityTestIncrementAction extends RefCounted:
	func action_id() -> String:
		return "test.increment"

	func atomicity() -> String:
		return "atomic"

	func validate(_context: RefCounted) -> String:
		return ""

	func execute(context: RefCounted):
		context.value += 5
		return ActionResultScript.success([{"type": "test.incremented", "amount": 5}])


class AbilityTestRejectAction extends RefCounted:
	func action_id() -> String:
		return "test.reject"

	func atomicity() -> String:
		return "atomic"

	func validate(_context: RefCounted) -> String:
		return ""

	func execute(context: RefCounted):
		context.value += 100
		return ActionResultScript.rejected("forced_failure")


class AbilityTestMarkEventAction extends RefCounted:
	func action_id() -> String:
		return "test.mark_event"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		return "" if context != null and context.state != null else "event_context_missing"

	func execute(context: RefCounted):
		var entity: RefCounted = context.state.entity(context.source_entity_id)
		if entity == null:
			return ActionResultScript.rejected("event_source_missing")
		entity.tags.grant("event.seen", "ability")
		return ActionResultScript.success()


class IncrementResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestIncrementAction.new()


class RejectResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestRejectAction.new()


class MarkEventResolver extends RefCounted:
	func build_action() -> RefCounted:
		return AbilityTestMarkEventAction.new()


class BridgeCommitHandler extends RefCounted:
	func handler_id() -> String:
		return "test.bridge_commit"

	func phase() -> String:
		return "commit"

	func priority() -> int:
		return 0

	func scope_rank() -> int:
		return 0

	func owner_sequence() -> int:
		return 0

	func handle(context: RefCounted):
		var fact := DomainEventScript.new(
			"test.committed", {}, "", 0, 1, context.request.source_entity_id, context.request.target_entity_ids
		)
		return EventHandlerResultScript.commit_result([fact])


func _create_action_registry() -> RefCounted:
	var registry := ActionRegistryScript.new()
	registry.register_action("test.increment", IncrementResolver.new())
	registry.register_action("test.reject", RejectResolver.new())
	registry.register_action("test.mark_event", MarkEventResolver.new())
	return registry


func _build_linear_graph(graph_id: String, action_ids: Array[String]) -> RefCounted:
	var graph := GraphDefinitionScript.new(graph_id)
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	var previous_node_id := "entry"
	for index in range(action_ids.size()):
		var node_id := "action_%d" % index
		graph.add_node(
			NodeDefinitionScript.new(
				node_id,
				NodeRegistryScript.EXECUTE_ACTION_TYPE,
				ActionNodeConfigurationScript.new(action_ids[index])
			)
		)
		graph.add_connection(
			ConnectionDefinitionScript.new(previous_node_id, "then", node_id, "in")
		)
		previous_node_id = node_id
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new(previous_node_id, "then", "end", "in"))
	return graph


func _build_cycle_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.cycle")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	for node_id in ["cycle_a", "cycle_b"]:
		graph.add_node(
			NodeDefinitionScript.new(
				node_id,
				NodeRegistryScript.EXECUTE_ACTION_TYPE,
				ActionNodeConfigurationScript.new("test.increment")
			)
		)
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("cycle_a", "then", "cycle_b", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("cycle_b", "then", "cycle_a", "in"))
	return graph


func _build_delay_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.delay")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"delay",
			NodeRegistryScript.DELAY_TYPE,
			AbilityNodeConfigurationScript.new({"duration_ticks": 2})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "delay", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("delay", "then", "end", "in"))
	return graph


func _build_wait_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.wait")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"wait",
			NodeRegistryScript.WAIT_EVENT_TYPE,
			AbilityNodeConfigurationScript.new({"event_type": "damage.applied", "filter": {"kind": "critical"}})
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "wait", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "resumed", "end", "in"))
	return graph


func _build_wait_timeout_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.wait_timeout")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(NodeDefinitionScript.new("wait", NodeRegistryScript.WAIT_EVENT_TYPE, AbilityNodeConfigurationScript.new({"event_type": "damage.applied", "timeout_ticks": 1})))
	graph.add_node(NodeDefinitionScript.new("resumed_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("timeout_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "wait", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "resumed", "resumed_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("wait", "timeout", "timeout_end", "in"))
	return graph


func _build_repeat_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.repeat")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"repeat",
			NodeRegistryScript.REPEAT_TYPE,
			AbilityNodeConfigurationScript.new({"count": 2})
		)
	)
	graph.add_node(
		NodeDefinitionScript.new(
			"action",
			NodeRegistryScript.EXECUTE_ACTION_TYPE,
			ActionNodeConfigurationScript.new("test.increment")
		)
	)
	graph.add_node(NodeDefinitionScript.new("end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "repeat", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("repeat", "body", "action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("action", "then", "repeat", "continue"))
	graph.add_connection(ConnectionDefinitionScript.new("repeat", "done", "end", "in"))
	return graph


func _build_branch_graph() -> RefCounted:
	var graph := GraphDefinitionScript.new("test.branch")
	graph.add_node(NodeDefinitionScript.new("entry", NodeRegistryScript.ON_CAST_TYPE))
	graph.add_node(
		NodeDefinitionScript.new(
			"branch",
			NodeRegistryScript.BRANCH_TYPE,
			AbilityNodeConfigurationScript.new({"condition": true})
		)
	)
	graph.add_node(NodeDefinitionScript.new("true_action", NodeRegistryScript.EXECUTE_ACTION_TYPE, ActionNodeConfigurationScript.new("test.increment")))
	graph.add_node(NodeDefinitionScript.new("true_end", NodeRegistryScript.END_TYPE))
	graph.add_node(NodeDefinitionScript.new("false_end", NodeRegistryScript.END_TYPE))
	graph.add_connection(ConnectionDefinitionScript.new("entry", "then", "branch", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("branch", "true", "true_action", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("branch", "false", "false_end", "in"))
	graph.add_connection(ConnectionDefinitionScript.new("true_action", "then", "true_end", "in"))
	return graph
