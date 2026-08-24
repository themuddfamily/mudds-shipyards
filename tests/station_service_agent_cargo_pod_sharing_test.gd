extends SceneTree

## Focused allocation regression for the production-sized courier roster's
## immutable CargoPod mesh. Renderer nodes and service behavior remain local.

const AGENT_SCENE := preload("res://scenes/world/components/station_service_agent.tscn")
const AGENT_COUNT := 7
const CARGO_POD_PATH := ^"PresentationRoot/ServiceCarriage/CargoPod"
const CARRIAGE_PATH := ^"PresentationRoot/ServiceCarriage"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var agents: Array[StationServiceAgent] = []
	for index in AGENT_COUNT:
		var agent := AGENT_SCENE.instantiate() as StationServiceAgent
		agent.agent_id = StringName("cargo-sharing-probe-%d" % index)
		var configured := agent.configure_service_route(
			StringName("cargo-sharing-route-%d" % index),
			PackedStringArray(["probe:start", "probe:end"]),
			PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, 4.0)])
		)
		_check(configured, "probe %d accepts its bounded service route" % index)
		root.add_child(agent)
		agents.append(agent)
	await process_frame

	var cargo_mesh_ids := {}
	var copies_preserve_recipe := true
	for agent in agents:
		var cargo_pod := agent.get_node_or_null(CARGO_POD_PATH) as MeshInstance3D
		var material_ids := agent.get_material_catalog_audit().identity_by_key as Dictionary
		copies_preserve_recipe = copies_preserve_recipe \
			and cargo_pod != null and cargo_pod.mesh != null \
			and cargo_pod.position.is_equal_approx(Vector3(0.0, -0.3, 0.12)) \
			and cargo_pod.basis.is_equal_approx(Basis.IDENTITY) \
			and cargo_pod.mesh.get_aabb().size.is_equal_approx(Vector3(0.54, 0.3, 0.62)) \
			and cargo_pod.mesh.get_surface_count() == 1 \
			and cargo_pod.mesh.surface_get_material(0) == null \
			and cargo_pod.material_override != null \
			and cargo_pod.material_override.get_instance_id() == int(material_ids.get("orange", 0)) \
			and cargo_pod.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			and cargo_pod.transparency == 0.0
		if cargo_pod != null and cargo_pod.mesh != null:
			cargo_mesh_ids[cargo_pod.mesh.get_instance_id()] = true
	_check(
		copies_preserve_recipe and cargo_mesh_ids.size() == 1,
		"seven stable CargoPod copies retain one immutable mesh instead of seven"
	)

	var first := agents[0]
	var cargo_pod := first.get_node(CARGO_POD_PATH) as MeshInstance3D
	var carriage := first.get_node(CARRIAGE_PATH) as Node3D
	var shared_mesh := cargo_pod.mesh
	first.set_agent_time(0.0)
	var start_transform := carriage.transform
	var advanced := first.set_agent_time(0.75)
	var authority := first.get_authority_contract()
	var performance := first.get_performance_audit()
	_check(
		advanced and not carriage.transform.is_equal_approx(start_transform)
			and cargo_pod.mesh == shared_mesh
			and cargo_pod.position.is_equal_approx(Vector3(0.0, -0.3, 0.12))
			and bool(first.get_audit_report().valid),
		"shared cargo-pod stock preserves deterministic route movement and the complete courier audit"
	)
	_check(
		int(authority.collision_nodes) == 0 and int(authority.area_nodes) == 0
			and not bool(authority.owns_navigation_authority)
			and not bool(authority.owns_interaction_authority)
			and int((performance.counts as Dictionary).mesh_instances) == 7,
		"sharing preserves seven renderers and adds no collision, navigation, or interaction authority"
	)

	first.set_agent_enabled(false)
	var disabled_preserves_identity := not first.is_processing() and not cargo_pod.is_visible_in_tree()
	first.set_agent_enabled(true)
	_check(
		disabled_preserves_identity and first.is_processing() and cargo_pod.is_visible_in_tree()
			and cargo_pod.mesh == shared_mesh and bool(first.get_audit_report().valid),
		"disable and re-enable preserve cargo-pod identity and reversible agent lifecycle"
	)

	for agent in agents:
		agent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("STATION_SERVICE_AGENT_CARGO_POD_SHARING_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
