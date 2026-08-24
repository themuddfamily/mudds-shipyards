extends SceneTree

## Focused production-Arrow proof for one steady component-damage silhouette.
## Damage enters only through HeroShip.apply_damage; the retained starboard
## engine collar observes the existing engine-bay ledger without adding a
## health, repair, collision, light, timing, or processing seam.

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	root.add_child(arrow)
	await process_frame
	await physics_frame

	var visual := arrow.get_arrow_visual_root()
	var sharing := arrow.get_arrow_visual_performance_report().get(
		"engine_collar_mesh_sharing", {}
	) as Dictionary
	var paths := sharing.get("node_paths", PackedStringArray()) as PackedStringArray
	var port := visual.get_node_or_null(NodePath(paths[0])) as MeshInstance3D \
			if paths.size() == 2 else null
	var starboard := visual.get_node_or_null(NodePath(paths[1])) as MeshInstance3D \
			if paths.size() == 2 else null
	var nominal := arrow.get_engine_damage_collar_snapshot()
	var nominal_port_transform := port.transform if port != null else Transform3D()
	var nominal_starboard_transform := (
		starboard.transform if starboard != null else Transform3D()
	)
	var collar_mesh := starboard.mesh as TorusMesh if starboard != null else null
	var nominal_starboard_bounds := (
		(nominal_starboard_transform * collar_mesh.get_aabb()).abs()
		if collar_mesh != null else AABB()
	)
	_check(
		port != null and starboard != null
			and nominal.get("component_id", &"") \
				== ShipComponentDamageType.COMPONENT_ENGINE_BAY
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("active", true))
			and starboard.material_override == null
			and bool(arrow.get_arrow_audit_report().get("valid", false)),
		"the production Arrow boots with its retained engine collars nominal"
	)
	_check(
		int(nominal.get("renderer_nodes_added", -1)) == 0
			and int(nominal.get("geometry_submissions_added", -1)) == 0
			and int(nominal.get("collision_shapes_added", -1)) == 0
			and int(nominal.get("lights_added", -1)) == 0
			and int(nominal.get("timers_added", -1)) == 0
			and int(nominal.get("processes_added", -1)) == 0
			and not bool(nominal.get("flashes", true))
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true))
			and starboard.get_script() == null
			and starboard.get_child_count() == 0,
		"the cue reuses one renderer and adds no collision, light, timer, process, flash, or authority"
	)

	var engine_position := _component_local_position(
		arrow, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	var hull_before := float(arrow.get_telemetry().get("hull", -1.0))
	# Leave enough impaired-ledger headroom that the production berth repair
	# cannot legitimately restore nominal state during the steady-state sample.
	var damage_amount := arrow.maximum_hull * 0.16
	arrow.apply_damage(
		damage_amount,
		arrow.to_global(engine_position),
		Vector3.UP
	)
	var damaged := arrow.get_engine_damage_collar_snapshot()
	var damage_material := starboard.material_override as StandardMaterial3D
	_check(
		is_equal_approx(
			float(arrow.get_telemetry().get("hull", -1.0)),
			hull_before - damage_amount
		)
			and arrow.get_component_damage().get_component_state(
				ShipComponentDamageType.COMPONENT_ENGINE_BAY
			) == ShipComponentDamageType.ComponentState.IMPAIRED
			and damaged.get("stage", &"") == &"impaired"
			and bool(damaged.get("active", false))
			and damage_material != null
			and damage_material.albedo_color.is_equal_approx(
				ArrowReconShip.ENGINE_DAMAGE_COLLAR_COLOR
			)
			and damage_material.emission.is_equal_approx(
				ArrowReconShip.ENGINE_DAMAGE_COLLAR_COLOR
			),
		"production HeroShip.apply_damage alone reveals the steady orange engine-bay cue"
	)

	var damaged_bounds := damaged.get("local_bounds", AABB()) as AABB
	var silhouette_extension := damaged_bounds.end.x - nominal_starboard_bounds.end.x
	# At the maximum normal chase distance and a conservative 720-line viewport,
	# the outboard warp must still clear the original silhouette by several pixels.
	var projected_extension_px := silhouette_extension * 720.0 \
		/ (2.0 * 24.0 * tan(deg_to_rad(72.0) * 0.5))
	arrow.set_piloted(true)
	await physics_frame
	var chase_camera := arrow.get_camera()
	_check(
		port.transform.is_equal_approx(nominal_port_transform)
			and not starboard.transform.is_equal_approx(nominal_starboard_transform)
			and silhouette_extension >= 0.40
			and projected_extension_px >= 8.0
			and chase_camera.is_position_in_frustum(
				arrow.to_global(damaged_bounds.get_center())
			),
		"the asymmetric rear collar clears the original silhouette and remains visible at maximum chase distance"
	)
	_check(
		_damaged_collar_is_supported(visual, starboard)
			and damaged_bounds.position.x > 0.10
			and damaged_bounds.position.z > 6.20
			and not damaged_bounds.has_point(
				arrow.to_local(arrow.get_boarding_position())
			)
			and not damaged_bounds.has_point(
				arrow.get_node(^"LeftMuzzle").position
			)
			and not damaged_bounds.has_point(
				arrow.get_node(^"RightMuzzle").position
			),
		"the warped collar stays on its engine housing and clear of cockpit, aim, weapon, and port-boarding lanes"
	)
	_check(
		bool(arrow.get_arrow_audit_report().get("valid", false))
			and damage_material != null
			and not damage_material.resource_local_to_scene
			and damage_material.next_pass == null,
		"the damaged Arrow remains production-valid with one immutable material and no extra render pass"
	)

	var cue_id := starboard.get_instance_id()
	var damaged_transform := starboard.transform
	var material_id := damage_material.get_instance_id()
	for _frame in 8:
		await process_frame
		await physics_frame
	_check(
		starboard.get_instance_id() == cue_id
			and starboard.transform.is_equal_approx(damaged_transform)
			and starboard.material_override.get_instance_id() == material_id
			and arrow.get_engine_damage_collar_snapshot().get("stage", &"") \
				== &"impaired",
		"the cue is retained and perfectly steady while the Arrow's existing animated systems advance"
	)

	root.remove_child(arrow)
	await process_frame
	root.add_child(arrow)
	await process_frame
	_check(
		starboard.get_instance_id() == cue_id
			and starboard.transform.is_equal_approx(damaged_transform)
			and starboard.material_override.get_instance_id() == material_id
			and arrow.get_engine_damage_collar_snapshot().get("stage", &"") \
				== &"impaired",
		"whole-craft detach and re-entry preserve the exact impaired cue identity and state"
	)

	var reset := arrow.reset_for_reuse(arrow.global_transform)
	var recovered := arrow.get_engine_damage_collar_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("active", true))
			and starboard.get_instance_id() == cue_id
			and starboard.transform.is_equal_approx(nominal_starboard_transform)
			and port.transform.is_equal_approx(nominal_port_transform)
			and starboard.material_override == null
			and is_equal_approx(
				float(arrow.get_telemetry().get("hull", -1.0)), arrow.maximum_hull
			),
		"pooled HeroShip reuse restores the same collars to their nominal silhouette"
	)

	var second := ARROW_SCENE.instantiate() as ArrowReconShip
	root.add_child(second)
	await process_frame
	var second_snapshot := second.get_engine_damage_collar_snapshot()
	_check(
		int(second_snapshot.get("material_resource_id", 0)) == material_id
			and not bool(second_snapshot.get("active", true)),
		"a second pooled Arrow shares the single immutable cue material while retaining independent state"
	)

	arrow.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _damaged_collar_is_supported(
	visual: Node3D,
	collar: MeshInstance3D
	) -> bool:
	if visual == null or collar == null or collar.mesh == null:
		return false
	var housing: MeshInstance3D
	for candidate in visual.find_children("*", "MeshInstance3D", false, false):
		var renderer := candidate as MeshInstance3D
		if renderer.position.is_equal_approx(Vector3(0.92, 0.94, 5.0)):
			housing = renderer
			break
	if housing == null or housing.mesh == null:
		return false
	var housing_bounds := (housing.transform * housing.mesh.get_aabb()).abs()
	var collar_bounds := (collar.transform * collar.mesh.get_aabb()).abs()
	return housing_bounds.grow(0.02).intersection(collar_bounds).has_volume() \
		and is_equal_approx(collar.position.y, housing.position.y) \
		and absf(collar.position.x - housing.position.x) <= 0.20


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ARROW_COMPONENT_DAMAGE_CUE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("ARROW_COMPONENT_DAMAGE_CUE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
