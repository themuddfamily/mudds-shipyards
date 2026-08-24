extends SceneTree

## Focused regression for the Halyard's steady engine-bay damage silhouette.
## Human rendered review is deliberately NOT_RUN here; this executable check
## proves the production component seam, physical support, chase projection, and
## the existing Halyard lifecycle/crew/boarding/weapon contracts it must not own.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")

const VANE_PATH := NodePath("HalyardTransportVisual/EngineDamageIsolationVane")
const TAIL_CAP_PATH := NodePath("HalyardTransportVisual/TailYokeCap")
const PROJECTED_VIEWPORT_HEIGHT := 720.0
const PROJECTED_CAMERA_DISTANCE := 24.0
const PROJECTED_VERTICAL_FOV_DEGREES := 70.0

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var vane := craft.get_node_or_null(VANE_PATH) as MeshInstance3D
	var tail_cap := craft.get_node_or_null(TAIL_CAP_PATH) as MeshInstance3D
	var damage_model := craft.get_component_damage()
	var nominal_transform := vane.transform if vane != null else Transform3D.IDENTITY
	var presentation_material := vane.material_override as StandardMaterial3D \
		if vane != null else null
	_check(
		vane != null
			and tail_cap != null
			and vane.get_meta(&"damage_component_id", &"") \
				== ComponentDamage.COMPONENT_ENGINE_BAY
			and vane.get_meta(&"damage_state", &"") == &"nominal"
			and bool(vane.get_meta(&"presentation_only", false))
			and not bool(vane.get_meta(&"damage_authority", true))
			and not bool(vane.get_meta(&"repair_authority", true))
			and not bool(vane.get_meta(&"seat_authority", true))
			and not bool(vane.get_meta(&"animated", true))
			and not bool(vane.get_meta(&"uses_timer", true)),
		"the production Halyard starts with one authority-free steady engine-bay vane"
	)
	_check(
		presentation_material != null
			and not presentation_material.emission_enabled
			and vane.get_script() == null
			and vane.get_child_count() == 0
			and vane.find_children("*", "Light3D", true, false).is_empty()
			and vane.find_children("*", "Timer", true, false).is_empty()
			and vane.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the vane adds no light, emission, script, timer, process, or collision owner"
	)
	_check(
		_pose_is_supported(vane, tail_cap, false),
		"the nominal plate lies flat on the authored tail-yoke cap rather than floating"
	)

	var authority := Authority.new(1)
	var registered := authority.register_halyard_roster()
	var attached := craft.attach_crew_role_authority(authority)
	var role_snapshot := authority.get_snapshot().duplicate(true)
	var moving_frame := craft.get_moving_interior_component()
	var moving_frame_id := moving_frame.get_instance_id()
	var seat_paths := _seat_paths(craft)
	var route_ids := _route_contract_ids(craft)
	var collision_ids := _collision_ids(craft)
	var weapon_report := craft.get_halyard_weapon_visual_report()
	var muzzle_positions := weapon_report.get("authored_muzzle_positions", []) as Array
	var repair_state := craft.get_engineer_repair_state().duplicate(true)
	_check(
		bool(registered.get("accepted", false))
			and bool(attached.get("accepted", false))
			and (role_snapshot.get("seats", []) as Array).size() == 8
			and _roster_has_all_roles(role_snapshot)
			and seat_paths.size() == 6
			and moving_frame.get_moving_frame() == craft
			and bool(weapon_report.get("exact_roster", false))
			and route_ids.size() == 3,
		"all crew roles, six cabin seats, moving interior, weapons, boarding, and ramp are live before damage"
	)

	var engine_position := _component_local_position(
		craft, ComponentDamage.COMPONENT_ENGINE_BAY
	)
	# A normal chase occurs away from the berth. Keep the existing landed-only
	# passive repair path from legitimately restoring the component during the
	# steady-frame observation below.
	craft.set("_landed", false)
	craft.apply_damage(
		craft.maximum_hull * 0.10,
		craft.to_global(engine_position),
		craft.global_basis.z
	)
	var damaged_transform := vane.transform
	var damaged_bounds := (damaged_transform * vane.get_aabb()).abs()
	var projected_height := damaged_bounds.size.y * PROJECTED_VIEWPORT_HEIGHT \
		/ (
			2.0 * PROJECTED_CAMERA_DISTANCE
			* tan(deg_to_rad(PROJECTED_VERTICAL_FOV_DEGREES) * 0.5)
		)
	_check(
		damage_model.get_component_state(ComponentDamage.COMPONENT_ENGINE_BAY) \
			== ComponentDamage.ComponentState.IMPAIRED
			and vane.get_meta(&"damage_state", &"") == &"impaired"
			and not damaged_transform.is_equal_approx(nominal_transform)
			and damaged_transform.origin.is_equal_approx(
				HalyardCrewTransport.ENGINE_DAMAGE_VANE_DAMAGED_POSITION
			)
			and damaged_transform.basis.is_equal_approx(Basis.IDENTITY)
			and presentation_material.albedo_color.is_equal_approx(
				HalyardCrewTransport.ENGINE_DAMAGE_VANE_AMBER
			),
		"production HeroShip damage drives the inherited engine ledger into one upright amber cue"
	)
	_check(
		_pose_is_supported(vane, tail_cap, true)
			and damaged_bounds.end.y > 3.15
			and projected_height >= 15.0,
		"the upright face stays hinged to the yoke and projects at least 15 pixels in a conservative chase view"
	)

	for _frame in 12:
		await process_frame
	_check(
		vane.transform.is_equal_approx(damaged_transform)
			and presentation_material.albedo_color.is_equal_approx(
				HalyardCrewTransport.ENGINE_DAMAGE_VANE_AMBER
			),
		"the impaired silhouette remains steady across frames without flashing or process animation"
	)
	_check(
		authority.get_snapshot() == role_snapshot
			and craft.get_crew_role_authority() == authority
			and craft.get_moving_interior_component().get_instance_id() == moving_frame_id
			and _seat_paths(craft) == seat_paths
			and _route_contract_ids(craft) == route_ids
			and _collision_ids(craft) == collision_ids
			and craft.get_halyard_weapon_visual_report().get("authored_muzzle_positions", []) \
				== muzzle_positions
			and craft.get_engineer_repair_state() == repair_state,
		"damage presentation leaves crew authority, interior, seats, boarding, collision, weapons, and repair untouched"
	)

	var vane_id := vane.get_instance_id()
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		vane.get_instance_id() == vane_id
			and vane.get_meta(&"damage_state", &"") == &"impaired"
			and vane.transform.is_equal_approx(damaged_transform)
			and craft.get_moving_interior_component().get_instance_id() == moving_frame_id
			and _seat_paths(craft) == seat_paths
			and _route_contract_ids(craft) == route_ids,
		"detach and re-entry retain the same impaired vane and every Halyard route/interior identity"
	)

	var reset := craft.reset_for_reuse(craft.global_transform)
	_check(
		bool(reset.get("accepted", false))
			and vane.get_instance_id() == vane_id
			and damage_model.get_component_state(ComponentDamage.COMPONENT_ENGINE_BAY) \
				== ComponentDamage.ComponentState.NOMINAL
			and vane.get_meta(&"damage_state", &"") == &"nominal"
			and vane.transform.is_equal_approx(nominal_transform)
			and authority.get_snapshot() == role_snapshot
			and craft.get_crew_role_authority() == authority
			and _seat_paths(craft) == seat_paths
			and _route_contract_ids(craft) == route_ids
			and _collision_ids(craft) == collision_ids
			and bool(craft.get_halyard_audit_report().get("valid", false)),
		"pooled reuse restores the stowed vane while preserving all Halyard production contracts"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in ship.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _pose_is_supported(
		vane: MeshInstance3D,
		tail_cap: MeshInstance3D,
		damaged: bool
	) -> bool:
	if vane == null or tail_cap == null:
		return false
	var vane_bounds := (vane.transform * vane.get_aabb()).abs()
	var cap_bounds := (tail_cap.transform * tail_cap.get_aabb()).abs()
	var hinge := HalyardCrewTransport.ENGINE_DAMAGE_VANE_HINGE
	var contact_y := vane_bounds.position.y if damaged else vane_bounds.position.y
	return absf(contact_y - cap_bounds.end.y) <= 0.002 \
		and hinge.x >= cap_bounds.position.x and hinge.x <= cap_bounds.end.x \
		and hinge.z >= cap_bounds.position.z and hinge.z <= cap_bounds.end.z \
		and vane_bounds.position.x >= cap_bounds.position.x \
		and vane_bounds.end.x <= cap_bounds.end.x


func _seat_paths(craft: HalyardCrewTransport) -> PackedStringArray:
	var paths := PackedStringArray()
	for anchor in craft.get_crew_seat_anchors():
		paths.append(str(craft.get_path_to(anchor)))
	return paths


func _route_contract_ids(craft: HalyardCrewTransport) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for path in [
		NodePath("BoardingPoint"),
		NodePath("ShipBoardingArea/HalyardApproachRange"),
		NodePath("PortAirstairCollision"),
	]:
		var node := craft.get_node_or_null(path)
		if node != null:
			ids.append(node.get_instance_id())
	return ids


func _collision_ids(craft: HalyardCrewTransport) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for node in craft.find_children("*", "CollisionShape3D", true, false):
		ids.append(node.get_instance_id())
	ids.sort()
	return ids


func _roster_has_all_roles(snapshot: Dictionary) -> bool:
	var roles := {}
	for seat_variant in snapshot.get("seats", []) as Array:
		roles[StringName((seat_variant as Dictionary).get("role", &""))] = true
	return roles.has(Authority.ROLE_PILOT) \
		and roles.has(Authority.ROLE_GUNNER) \
		and roles.has(Authority.ROLE_ENGINEER) \
		and roles.has(Authority.ROLE_PASSENGER)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_ENGINE_DAMAGE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: %s" % failure)
	quit(1)
