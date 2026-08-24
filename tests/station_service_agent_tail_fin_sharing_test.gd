extends SceneTree

## Focused allocation regression for the production courier roster's immutable
## TailFin mesh. Render nodes, routes, materials, and lifecycle remain local.

const AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")
const AGENT_COUNT := 7
const TAIL_FIN_PATH := ^"PresentationRoot/ServiceCarriage/TailFin"
const CARRIAGE_PATH := ^"PresentationRoot/ServiceCarriage"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var agents: Array[StationServiceAgent] = []
	for index in AGENT_COUNT:
		var agent := AGENT_SCENE.instantiate() as StationServiceAgent
		agent.agent_id = StringName("tail-fin-sharing-probe-%d" % index)
		var configured := agent.configure_service_route(
			StringName("tail-fin-sharing-route-%d" % index),
			PackedStringArray(["probe:start", "probe:end"]),
			PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 4.0)])
		)
		_check(configured, "probe %d accepts its bounded service route" % index)
		root.add_child(agent)
		agents.append(agent)
	await process_frame

	var tail_fin_mesh_ids := {}
	var copies_preserve_recipe := true
	for agent in agents:
		var tail_fin := agent.get_node_or_null(TAIL_FIN_PATH) as MeshInstance3D
		var material_ids := agent.get_material_catalog_audit().identity_by_key as Dictionary
		copies_preserve_recipe = copies_preserve_recipe \
			and tail_fin != null and tail_fin.mesh != null \
			and tail_fin.position.is_equal_approx(Vector3(0.0, 0.28, 0.5)) \
			and tail_fin.basis.is_equal_approx(Basis.IDENTITY) \
			and tail_fin.mesh.get_aabb().size.is_equal_approx(Vector3(0.08, 0.42, 0.36)) \
			and tail_fin.mesh.get_surface_count() == 1 \
			and tail_fin.mesh.surface_get_material(0) == null \
			and tail_fin.material_override != null \
			and tail_fin.material_override.get_instance_id() == int(material_ids.get("hull_edge", 0))
		if tail_fin != null and tail_fin.mesh != null:
			tail_fin_mesh_ids[tail_fin.mesh.get_instance_id()] = true
	_check(
		copies_preserve_recipe and tail_fin_mesh_ids.size() == 1,
		"seven stable TailFin copies retain one immutable mesh instead of seven"
	)

	var first := agents[0]
	var tail_fin := first.get_node(TAIL_FIN_PATH) as MeshInstance3D
	var carriage := first.get_node(CARRIAGE_PATH) as Node3D
	var shared_mesh := tail_fin.mesh
	first.set_agent_time(0.0)
	var start_transform := carriage.transform
	var advanced := first.set_agent_time(0.75)
	var authority := first.get_authority_contract()
	var performance := first.get_performance_audit()
	_check(
		advanced and not carriage.transform.is_equal_approx(start_transform)
			and tail_fin.mesh == shared_mesh
			and tail_fin.position.is_equal_approx(Vector3(0.0, 0.28, 0.5))
			and bool(first.get_audit_report().valid),
		"shared tail-fin stock preserves deterministic route movement and the complete courier audit"
	)
	_check(
		int(authority.collision_nodes) == 0 and int(authority.area_nodes) == 0
			and not bool(authority.owns_navigation_authority)
			and not bool(authority.owns_interaction_authority)
			and int((performance.counts as Dictionary).mesh_instances) == 7,
		"sharing preserves seven renderers and adds no collision, navigation, or interaction authority"
	)

	first.set_agent_enabled(false)
	var disabled_preserves_identity := not first.is_processing() and not tail_fin.is_visible_in_tree()
	first.set_agent_enabled(true)
	_check(
		disabled_preserves_identity and first.is_processing() and tail_fin.is_visible_in_tree()
			and tail_fin.mesh == shared_mesh and bool(first.get_audit_report().valid),
		"disable and re-enable preserve tail-fin identity and reversible agent lifecycle"
	)

	for agent in agents:
		agent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_SERVICE_AGENT_TAIL_FIN_SHARING_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
