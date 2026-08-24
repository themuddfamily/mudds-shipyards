extends SceneTree

## Focused Zenith proof for one retained, steady component-damage silhouette.
## Damage enters only through HeroShip.apply_damage; this presentation consumes
## the existing starboard-wing ledger and owns no damage, repair, timing, light,
## collision, boarding, aiming, or weapon authority.

const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := ZENITH_SCENE.instantiate() as ZenithInterceptor
	root.add_child(craft)
	await process_frame
	await physics_frame

	var visual := craft.get_zenith_visual_root()
	var cue := visual.get_node_or_null(^"StarboardWingDamageCue") as Node3D \
		if visual != null else null
	var scorch := cue.get_node_or_null(^"DamageScorch") as MeshInstance3D \
		if cue != null else null
	var spar := cue.get_node_or_null(^"ExposedWingSpar") as MeshInstance3D \
		if cue != null else null
	var scorch_material := scorch.material_override as StandardMaterial3D \
		if scorch != null else null
	var spar_material := spar.material_override as StandardMaterial3D \
		if spar != null else null
	var nominal := craft.get_starboard_wing_damage_cue_snapshot()
	_check(
		cue != null
			and nominal.get("component_id", &"") \
				== ShipComponentDamageType.COMPONENT_STARBOARD_WING
			and nominal.get("stage", &"") == &"nominal"
			and not bool(nominal.get("visible", true))
			and bool(nominal.get("presentation_only", false))
			and not bool(nominal.get("damage_authority", true))
			and not bool(nominal.get("repair_authority", true))
			and not bool(nominal.get("processes", true))
			and not bool(nominal.get("flashes", true))
			and cue.process_mode == Node.PROCESS_MODE_DISABLED
			and cue.get_child_count() == 2
			and cue.find_children("*", "CollisionObject3D", true, false).is_empty()
			and cue.find_children("*", "Timer", true, false).is_empty()
			and cue.find_children("*", "AnimationPlayer", true, false).is_empty()
			and cue.find_children("*", "Light3D", true, false).is_empty(),
		"the Zenith boots with one hidden presentation-only cue and no gameplay, timing, flashing, light, or collision authority"
	)
	_check(
		scorch != null and spar != null
			and scorch.mesh is BoxMesh and spar.mesh is BoxMesh
			and not scorch.mesh.resource_local_to_scene
			and not spar.mesh.resource_local_to_scene
			and scorch_material != null and spar_material != null
			and not scorch_material.resource_local_to_scene
			and not spar_material.resource_local_to_scene
			and not scorch_material.emission_enabled
			and spar_material.emission_enabled
			and spar_material.emission.is_equal_approx(ZenithInterceptor.DAMAGE_SPAR_COLOR)
			and is_equal_approx(spar_material.emission_energy_multiplier, 1.45),
		"the dark scorch and steady exposed spar use exactly two immutable presentation recipes"
	)

	var nominal_bounds := nominal.get("local_bounds", AABB()) as AABB
	var chase_camera := craft.get_camera()
	var projected_height_px := nominal_bounds.size.y * 720.0 \
		/ (2.0 * craft.maximum_chase_camera_distance * tan(deg_to_rad(72.0) * 0.5))
	var left_muzzle := craft.get_node(^"LeftMuzzle") as Marker3D
	var right_muzzle := craft.get_node(^"RightMuzzle") as Marker3D
	var boarding_point := craft.get_node(^"BoardingPoint") as Marker3D
	var exit_point := craft.get_node(^"ExitPoint") as Marker3D
	var cockpit_camera := visual.get_node(^"CockpitInterior/CockpitCamera") as Camera3D
	_check(
		_cue_base_is_supported_by_starboard_wing(craft, nominal_bounds)
			and projected_height_px >= 10.0
			and chase_camera.is_position_in_frustum(craft.to_global(nominal_bounds.get_center())),
		"the spar rises by a gameplay-distance-readable silhouette from the production starboard-wing shell inside the chase frustum"
	)
	_check(
		nominal_bounds.position.x > right_muzzle.position.x + 1.0
			and nominal_bounds.position.x > cockpit_camera.position.x + 1.0
			and nominal_bounds.position.x > 0.0
			and boarding_point.position.x < 0.0 and exit_point.position.x < 0.0
			and nominal_bounds.position.z > left_muzzle.position.z
			and nominal_bounds.position.z > right_muzzle.position.z,
		"the outboard aft mount leaves the cockpit/aim corridor, port boarding route, and both forward muzzle paths clear"
	)
	# Exercise the cue in its intended chase context. These are the same public
	# startup and flight-input paths used by production; leaving the berth also
	# prevents the legitimate landed auto-repair loop from immediately restoring
	# a damaged component.
	craft.engine_start_time = 0.04
	craft.set_piloted(true)
	craft.request_engine_start()
	for _frame in 8:
		await physics_frame
	Input.action_press("move_forward")
	for _frame in 10:
		await physics_frame
	Input.action_release("move_forward")
	_check(
		not bool(craft.get_telemetry().get("landed", true))
			and craft.velocity.length() > 0.5,
		"the focused fixture reaches the production in-flight chase state before applying damage"
	)

	var model := craft.get_component_damage()
	var starboard_position := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_STARBOARD_WING
	)
	var hull_before := float(craft.get_telemetry().get("hull", -1.0))
	var damage_amount := craft.maximum_hull * 0.10
	craft.apply_damage(
		damage_amount,
		craft.to_global(starboard_position),
		Vector3.UP
	)
	var damaged := craft.get_starboard_wing_damage_cue_snapshot()
	_check(
		is_equal_approx(
			float(craft.get_telemetry().get("hull", -1.0)), hull_before - damage_amount
		)
			and model.get_component_state(ShipComponentDamageType.COMPONENT_STARBOARD_WING) \
				== ShipComponentDamageType.ComponentState.IMPAIRED
			and damaged.get("stage", &"") == &"impaired"
			and bool(damaged.get("visible", false)),
		"production HeroShip.apply_damage alone impairs the existing starboard-wing ledger and reveals the cue"
	)

	var cue_id := cue.get_instance_id()
	var cue_transform := cue.transform
	var resource_ids := [
		damaged.get("mesh_resource_ids", PackedInt64Array()),
		damaged.get("material_resource_ids", PackedInt64Array()),
	]
	for _frame in 4:
		await process_frame
		await physics_frame
	_check(
		cue.visible and cue.get_instance_id() == cue_id
			and cue.transform.is_equal_approx(cue_transform)
			and craft.get_starboard_wing_damage_cue_snapshot().get("stage", &"") \
				== &"impaired"
			and [
				craft.get_starboard_wing_damage_cue_snapshot().get(
					"mesh_resource_ids", PackedInt64Array()
				),
				craft.get_starboard_wing_damage_cue_snapshot().get(
					"material_resource_ids", PackedInt64Array()
				),
			] == resource_ids,
		"the damaged silhouette remains steady on the same nodes and resources across runtime frames"
	)

	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	await physics_frame
	_check(
		cue.get_instance_id() == cue_id
			and cue.visible
			and craft.get_starboard_wing_damage_cue_snapshot().get("stage", &"") \
				== &"impaired"
			and model.get_signal_connection_list(&"component_state_changed").size() == 1
			and craft.get_signal_connection_list(&"component_damage_changed").size() == 1
			and bool(craft.get_zenith_runtime_identity_report().get("stable", false)),
		"whole-ship detach/re-entry retains one impaired cue and the existing component signal/resource identities"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	var recovered := craft.get_starboard_wing_damage_cue_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and model.get_component_state(ShipComponentDamageType.COMPONENT_STARBOARD_WING) \
				== ShipComponentDamageType.ComponentState.NOMINAL
			and recovered.get("stage", &"") == &"nominal"
			and not bool(recovered.get("visible", true))
			and cue.get_instance_id() == cue_id
			and bool(craft.get_zenith_runtime_identity_report().get("stable", false))
			and bool(craft.get_zenith_audit_report().get("valid", false)),
		"pool reuse restores nominal presentation in place without disturbing Zenith's production audit"
	)

	var second := ZENITH_SCENE.instantiate() as ZenithInterceptor
	root.add_child(second)
	await process_frame
	await physics_frame
	var second_snapshot := second.get_starboard_wing_damage_cue_snapshot()
	_check(
		recovered.get("mesh_resource_ids", PackedInt64Array()) \
				== second_snapshot.get("mesh_resource_ids", PackedInt64Array())
			and recovered.get("material_resource_ids", PackedInt64Array()) \
				== second_snapshot.get("material_resource_ids", PackedInt64Array())
			and int(second_snapshot.get("renderer_nodes_per_copy", -1)) == 2
			and int(second_snapshot.get("geometry_submissions_per_copy", -1)) == 2
			and not bool(second_snapshot.get("visible", true)),
		"multiple Zenith copies share the two immutable recipes while keeping independent nominal visibility"
	)

	craft.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _cue_base_is_supported_by_starboard_wing(craft: ZenithInterceptor, bounds: AABB) -> bool:
	var collision := craft.get_node_or_null(^"StarboardMainWing") as CollisionShape3D
	if collision == null or not collision.shape is ConvexPolygonShape3D:
		return false
	var points := (collision.shape as ConvexPolygonShape3D).points
	var support_points := PackedVector2Array()
	var top_y := -INF
	for point in points:
		top_y = maxf(top_y, point.y + collision.position.y)
		support_points.append(Vector2(
			point.x + collision.position.x,
			point.z + collision.position.z
		))
	if absf(bounds.position.y - top_y) > 0.001:
		return false
	var support_hull := Geometry2D.convex_hull(support_points)
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			if not Geometry2D.is_point_in_polygon(Vector2(x, z), support_hull):
				return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_INTERCEPTOR_DAMAGE_FEEDBACK_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("ZENITH_INTERCEPTOR_DAMAGE_FEEDBACK_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
