extends SceneTree

## Focused allocation regression for the production-sized courier roster's
## immutable StatusLens mesh. Each renderer keeps its clock-driven material.

const AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")
const AGENT_COUNT := 7
const LENS_PATH := ^"PresentationRoot/ServiceCarriage/StatusLens"
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
		agent.agent_id = StringName("status-lens-sharing-probe-%d" % index)
		var configured := agent.configure_service_route(
			StringName("status-lens-sharing-route-%d" % index),
			PackedStringArray(["probe:start", "probe:end"]),
			PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 4.0)])
		)
		_check(configured, "probe %d accepts its bounded service route" % index)
		root.add_child(agent)
		agents.append(agent)
	await process_frame

	var lens_mesh_ids := {}
	var tail_fin_mesh_ids := {}
	var copies_preserve_recipe := true
	for agent in agents:
		var lens := agent.get_node_or_null(LENS_PATH) as MeshInstance3D
		var tail_fin := agent.get_node_or_null(TAIL_FIN_PATH) as MeshInstance3D
		copies_preserve_recipe = copies_preserve_recipe \
			and lens != null and lens.mesh != null \
			and lens.position.is_equal_approx(Vector3(0.0, 0.2, -0.5)) \
			and lens.basis.is_equal_approx(Basis.IDENTITY) \
			and lens.mesh.get_aabb().size.is_equal_approx(Vector3(0.22, 0.1, 0.06)) \
			and lens.mesh.get_surface_count() == 1 \
			and lens.mesh.surface_get_material(0) == null \
			and lens.material_override != null
		if lens != null and lens.mesh != null:
			lens_mesh_ids[lens.mesh.get_instance_id()] = true
		if tail_fin != null and tail_fin.mesh != null:
			tail_fin_mesh_ids[tail_fin.mesh.get_instance_id()] = true
	_check(
		copies_preserve_recipe and lens_mesh_ids.size() == 1,
		"seven stable StatusLens copies retain one immutable mesh instead of seven"
	)
	_check(
		tail_fin_mesh_ids.size() == 1,
		"status-lens sharing preserves the existing single tail-fin mesh allocation"
	)

	var first := agents[0]
	var lens := first.get_node(LENS_PATH) as MeshInstance3D
	var carriage := first.get_node(CARRIAGE_PATH) as Node3D
	var shared_mesh := lens.mesh
	first.set_agent_time(0.0)
	var start_transform := carriage.transform
	var start_material := lens.material_override
	var material_changed := false
	for step in 17:
		first.set_agent_time(float(step) * 0.1)
		if lens.material_override != start_material:
			material_changed = true
			break
	var authority := first.get_authority_contract()
	var performance := first.get_performance_audit()
	_check(
		material_changed and not carriage.transform.is_equal_approx(start_transform)
			and lens.mesh == shared_mesh
			and bool(first.get_audit_report().valid),
		"shared lens stock preserves independent blinking, route movement, and the courier audit"
	)
	_check(
		int(authority.collision_nodes) == 0 and int(authority.area_nodes) == 0
			and not bool(authority.owns_navigation_authority)
			and not bool(authority.owns_interaction_authority)
			and int((performance.counts as Dictionary).mesh_instances) == 7,
		"sharing adds no collision, navigation, interaction, lifecycle, or renderer copies"
	)

	first.set_agent_enabled(false)
	var disabled_preserves_identity := not first.is_processing() and not lens.is_visible_in_tree()
	first.set_agent_enabled(true)
	_check(
		disabled_preserves_identity and first.is_processing() and lens.is_visible_in_tree()
			and lens.mesh == shared_mesh and bool(first.get_audit_report().valid),
		"disable and re-enable preserve lens identity and reversible agent lifecycle"
	)

	for agent in agents:
		agent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_SERVICE_AGENT_STATUS_LENS_SHARING_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
