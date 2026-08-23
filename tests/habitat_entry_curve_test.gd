extends SceneTree

## Focused production contract for the curved Habitat pressure-lintel seen on
## the normal starboard-to-Habitat walk. It observes the existing component
## authority rather than recreating a door or route fixture.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const HEADER_PATH := ^"Structure/PlayerClearConnector/EntryFacadeHeader"
const SIGN_PATH := ^"Structure/PlayerClearConnector/Sign_HABITAT_SPINE____FIXED-ERA-INSPIRED"
const PLAYER_RADIUS := 0.38
const PLAYER_HEIGHT := 1.94

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates for the Habitat entrance")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	var habitat := world.get_habitat_spine()
	_check(habitat != null, "production world exposes the retained HabitatSpine")
	if habitat != null:
		_test_curved_header(habitat)
		await _test_doorway_route(world, habitat)

	world.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_curved_header(habitat: HabitatSpine) -> void:
	var header := habitat.get_node_or_null(HEADER_PATH) as StaticBody3D
	var visual := header.get_node_or_null(^"Mesh") as MeshInstance3D if header != null else null
	var collision := header.get_node_or_null(^"Collision") as CollisionShape3D if header != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	_check(
		header != null and visual != null and visual.mesh != null and shape != null,
		"the Habitat entrance retains one rendered, collision-backed facade header"
	)
	if header == null or visual == null or visual.mesh == null or shape == null:
		return
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	_check(
		visual.mesh.resource_name == "habitat_entry_capsule_header_v1"
		and visual.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 72,
		"the visible capsule lintel uses one 72-triangle surface instead of the 108-triangle shallow box"
	)
	_check(
		visual.mesh.get_aabb().position.is_equal_approx(
			-ShipyardWorld.HABITAT_ENTRY_HEADER_SIZE * 0.5
		)
		and visual.mesh.get_aabb().size.is_equal_approx(ShipyardWorld.HABITAT_ENTRY_HEADER_SIZE)
		and shape.size.is_equal_approx(ShipyardWorld.HABITAT_ENTRY_HEADER_SIZE)
		and header.position.is_equal_approx(Vector3(0.0, 4.48, 0.72)),
		"curved render bounds, placement and box collider preserve the exact 4.2 x 0.72 x 0.48 m header envelope"
	)
	var shell_light_reference := habitat.find_child("HeadServiceUnit", true, false) as StaticBody3D
	var reference_visual := (
		shell_light_reference.get_node_or_null(^"Mesh") as MeshInstance3D
		if shell_light_reference != null else null
	)
	_check(
		reference_visual != null
		and visual.material_override == reference_visual.material_override
		and header.get_child_count() == 2
		and header.collision_layer == PhysicsLayers.WORLD
		and header.collision_mask == PhysicsLayers.NONE,
		"the header retains shell-light material, two-child body and World-only collision authority"
	)
	_check(
		str(header.get_meta("geometry_profile", "")) == "extruded_capsule_header"
		and is_equal_approx(float(header.get_meta("end_radius_m", 0.0)), 0.36)
		and int(header.get_meta("curve_segments_per_end", 0)) == 8,
		"the authored pressure lintel publishes its 0.36 m, eight-segment curve recipe"
	)
	var evidence := habitat.get_evidence_metadata()
	_check(
		str(evidence.get("evidence_status", "")) == "fixed_era_inspired_modern_interpretation"
		and not bool(evidence.get("authenticated_original_geometry", true)),
		"the visual treatment preserves Habitat's fixed-era-inspired modern evidence status"
	)
	var audit := habitat.get_audit_report()
	_check(
		bool(audit.get("valid", false)),
		"Habitat's production geometry, route, room and authority audit is green before door interaction: %s"
		% [audit.get("errors", [])]
	)
	var sign := habitat.get_node_or_null(SIGN_PATH) as MeshInstance3D
	var sign_mesh := sign.mesh as TextMesh if sign != null else null
	_check(
		sign != null and sign_mesh != null
		and sign.position.is_equal_approx(Vector3(4.0, 3.85, 0.43))
		and sign.rotation_degrees.is_equal_approx(Vector3(0.0, 180.0, 0.0))
		and sign_mesh.text == "HABITAT SPINE  //  FIXED-ERA-INSPIRED"
		and sign.visible,
		"the approach-facing amber Habitat legend remains in its exact readable transform"
	)


func _test_doorway_route(world: ShipyardWorld, habitat: HabitatSpine) -> void:
	var door := habitat.get_main_access()
	_check(door != null and door.interact(habitat), "the retained production Habitat door accepts opening")
	if door == null:
		return
	for frame_index in 90:
		if door.is_open():
			break
		await physics_frame
	_check(door.is_open() and not door.is_portal_blocked(), "the real pressure door reaches its fully clear state")

	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT
	var route_samples := PackedVector3Array([
		Vector3(0.0, 1.08, -3.0),
		Vector3(0.0, 1.08, -1.0),
		Vector3(0.0, 1.08, 0.35),
		Vector3(0.0, 1.08, 1.5),
	])
	var every_capsule_clear := true
	for local_sample in route_samples:
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.transform = Transform3D(Basis.IDENTITY, habitat.to_global(local_sample))
		params.collision_mask = PhysicsLayers.WORLD
		params.collide_with_bodies = true
		params.collide_with_areas = false
		await physics_frame
		every_capsule_clear = every_capsule_clear and world.get_world_3d().direct_space_state.intersect_shape(params, 24).is_empty()
	_check(every_capsule_clear, "the production player capsule clears the complete connector-to-door threshold")

	var head_start := habitat.to_global(Vector3(0.0, 0.2, 0.35))
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(
		head_start,
		head_start + habitat.global_basis * Vector3.UP * 3.8,
		PhysicsLayers.WORLD
	)
	query.collide_with_areas = false
	var head_hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(head_hit.is_empty(), "the threshold retains its published 3.8 m clear headroom below the curved lintel")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HABITAT_ENTRY_CURVE_TEST_OK")
		quit(0)
	else:
		print("HABITAT_ENTRY_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
