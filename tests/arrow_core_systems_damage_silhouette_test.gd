extends SceneTree

## Focused production proof for the Arrow's failed core-systems silhouette.
## The existing component ledger alone must cant the retained sensor sweep,
## hold it steady, and restore its exact nominal pose during pooled reuse.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	root.add_child(arrow)
	await process_frame
	await physics_frame

	var sweep := arrow.get_sensor_mast()
	var visual := arrow.get_arrow_visual_root()
	var nominal := arrow.get_core_systems_damage_silhouette_snapshot()
	var sweep_id := sweep.get_instance_id() if sweep != null else 0
	_check(
		sweep != null and sweep.get_parent().name == &"ReconSensorMast"
			and nominal.get("component_id", &"") \
				== ShipComponentDamageType.COMPONENT_CORE_SYSTEMS
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("active", true))
			and bool(arrow.get_arrow_audit_report().get("valid", false)),
		"the production Arrow starts with its retained recon head under the normal survey presentation"
	)
	_check(
		int(nominal.get("renderer_nodes_added", -1)) == 0
			and int(nominal.get("geometry_submissions_added", -1)) == 0
			and int(nominal.get("collision_shapes_added", -1)) == 0
			and int(nominal.get("lights_added", -1)) == 0
			and int(nominal.get("timers_added", -1)) == 0
			and int(nominal.get("processes_added", -1)) == 0
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true)),
		"the cue changes only an existing visual node and adds no authority or runtime infrastructure"
	)

	var core_position := _component_local_position(
		arrow, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS
	)
	# The existing component ledger applies the same localized hit twice; this is
	# deliberately below hull destruction while crossing its established failed
	# threshold for the core-systems component.
	for _hit in 2:
		arrow.apply_damage(arrow.maximum_hull * 0.16, arrow.to_global(core_position), Vector3.UP)
	var failed := arrow.get_core_systems_damage_silhouette_snapshot()
	var failed_rotation := failed.get("failed_rotation", Vector3.ZERO) as Vector3
	_check(
		arrow.get_component_damage().get_component_state(
			ShipComponentDamageType.COMPONENT_CORE_SYSTEMS
		) == ShipComponentDamageType.ComponentState.FAILED
			and failed.get("stage", &"") == &"failed"
			and bool(failed.get("active", false))
			and sweep.rotation.is_equal_approx(failed_rotation)
			and not sweep.rotation.is_equal_approx(Vector3.ZERO),
		"the existing failed core-systems state alone locks the recon head into its distinct silhouette pose"
	)
	_check(
		visual.get_node_or_null(^"ReconSensorMast/SensorSweep/ArrayCrossbar") != null
			and sweep.rotation.x != 0.0 and sweep.rotation.y != 0.0 and sweep.rotation.z != 0.0
			and bool(arrow.get_arrow_visual_performance_report().get("valid", false)),
		"the retained crossbar and aperture rotate together as a localized non-colour silhouette break"
	)

	var failed_transform := sweep.transform
	for _frame in 8:
		await process_frame
		await physics_frame
	_check(
		sweep.get_instance_id() == sweep_id and sweep.transform.is_equal_approx(failed_transform),
		"the failed pose remains perfectly steady while the existing Arrow presentation advances"
	)

	var reset := arrow.reset_for_reuse(arrow.global_transform)
	var recovered := arrow.get_core_systems_damage_silhouette_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("active", true))
			and sweep.get_instance_id() == sweep_id
			and sweep.rotation.is_equal_approx(Vector3.ZERO)
			and bool(arrow.get_arrow_audit_report().get("valid", false)),
		"pooled reuse restores the same recon head to its exact nominal pose"
	)

	arrow.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ARROW_CORE_SYSTEMS_DAMAGE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("ARROW_CORE_SYSTEMS_DAMAGE_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
