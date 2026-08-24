extends SceneTree

## Focused allocation regression for the production-sized courier roster's
## immutable ForwardCowl mesh. Presentation nodes and service behavior stay local.

const AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")
const AGENT_COUNT := 7
const COWL_PATH := ^"PresentationRoot/ServiceCarriage/ForwardCowl"
const CARRIAGE_PATH := ^"PresentationRoot/ServiceCarriage"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var agents: Array[StationServiceAgent] = []
	for index in AGENT_COUNT:
		var agent := AGENT_SCENE.instantiate() as StationServiceAgent
		agent.agent_id = StringName("cowl-sharing-probe-%d" % index)
		var configured := agent.configure_service_route(
			StringName("cowl-sharing-route-%d" % index),
			PackedStringArray(["probe:start", "probe:end"]),
			PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 4.0)])
		)
		_check(configured, "probe %d accepts its bounded service route" % index)
		root.add_child(agent)
		agents.append(agent)
	await process_frame

	var cowl_mesh_ids := {}
	var copies_preserve_recipe := true
	for agent in agents:
		var cowl := agent.get_node_or_null(COWL_PATH) as MeshInstance3D
		var material_ids := agent.get_material_catalog_audit().identity_by_key as Dictionary
		copies_preserve_recipe = copies_preserve_recipe \
			and cowl != null and cowl.mesh != null \
			and cowl.position.is_equal_approx(Vector3(0.0, 0.02, -0.72)) \
			and cowl.basis.is_equal_approx(Basis.IDENTITY) \
			and cowl.mesh.get_aabb().size.is_equal_approx(Vector3(0.5, 0.26, 0.34)) \
			and cowl.mesh.get_surface_count() == 1 \
			and cowl.mesh.surface_get_material(0) == null \
			and cowl.material_override != null \
			and cowl.material_override.get_instance_id() == int(material_ids.get("hull_edge", 0))
		if cowl != null and cowl.mesh != null:
			cowl_mesh_ids[cowl.mesh.get_instance_id()] = true
	_check(
		copies_preserve_recipe and cowl_mesh_ids.size() == 1,
		"seven stable ForwardCowl copies retain one immutable mesh instead of seven"
	)

	var first := agents[0]
	var cowl := first.get_node(COWL_PATH) as MeshInstance3D
	var carriage := first.get_node(CARRIAGE_PATH) as Node3D
	var shared_mesh := cowl.mesh
	first.set_agent_time(0.0)
	var start_position := carriage.position
	var advanced := first.set_agent_time(0.75)
	var authority := first.get_authority_contract()
	var performance := first.get_performance_audit()
	_check(
		advanced and not carriage.position.is_equal_approx(start_position)
			and cowl.mesh == shared_mesh
			and cowl.position.is_equal_approx(Vector3(0.0, 0.02, -0.72))
			and bool(first.get_audit_report().valid),
		"shared cowl stock preserves deterministic movement and the complete courier audit"
	)
	_check(
		int(authority.collision_nodes) == 0 and int(authority.area_nodes) == 0
			and not bool(authority.owns_navigation_authority)
			and not bool(authority.owns_interaction_authority)
			and int((performance.counts as Dictionary).mesh_instances) == 7,
		"sharing adds no collision, navigation, interaction, lifecycle, or renderer copies"
	)

	first.set_agent_enabled(false)
	var disabled_preserves_identity := not first.is_processing() and not cowl.is_visible_in_tree()
	first.set_agent_enabled(true)
	_check(
		disabled_preserves_identity and first.is_processing() and cowl.is_visible_in_tree()
			and cowl.mesh == shared_mesh and bool(first.get_audit_report().valid),
		"disable and re-enable preserve cowl identity and reversible agent lifecycle"
	)

	for agent in agents:
		agent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_SERVICE_AGENT_FORWARD_COWL_SHARING_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
