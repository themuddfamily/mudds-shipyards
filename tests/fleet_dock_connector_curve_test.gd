extends SceneTree

## Focused geometry, renderer and route contract for the world-owned gateway
## between the Aft upper deck and Fleet Dock Comb. Berth and Comb authority stay
## with their existing owners; this test observes only the connector presentation
## and the exact retained walk-support seam.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const CONNECTOR_PATH := ^"ExposedDockLattice/FleetDockCombConnector"
const DECK_PATH := ^"ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates for the Fleet Dock gateway")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	_test_curved_geometry(world)
	await _test_retained_route(world)

	world.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_curved_geometry(world: ShipyardWorld) -> void:
	var connector := world.get_node_or_null(CONNECTOR_PATH) as Node3D
	var deck := world.get_node_or_null(DECK_PATH) as StaticBody3D
	var visual := deck.get_node_or_null(^"Mesh") as MeshInstance3D if deck != null else null
	var collision := deck.get_node_or_null(^"Collision") as CollisionShape3D if deck != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	_check(
		connector != null and deck != null and visual != null and visual.mesh != null and shape != null,
		"the Fleet Dock gateway retains one visible collision-backed connector deck"
	)
	if connector == null or deck == null or visual == null or visual.mesh == null or shape == null:
		return
	var arrays := visual.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	_check(
		visual.mesh.resource_name == "fleet_dock_connector_rounded_gateway_v1"
		and visual.mesh.get_surface_count() == 1
		and vertices.size() / 3 == 64,
		"the rounded gateway uses one 64-triangle surface instead of the 108-triangle shallow box"
	)
	_check(
		visual.mesh.get_aabb().position.is_equal_approx(
			-ShipyardWorld.FLEET_DOCK_CONNECTOR_DECK_SIZE * 0.5
		)
		and visual.mesh.get_aabb().size.is_equal_approx(
			ShipyardWorld.FLEET_DOCK_CONNECTOR_DECK_SIZE
		)
		and shape.size.is_equal_approx(ShipyardWorld.FLEET_DOCK_CONNECTOR_DECK_SIZE)
		and deck.position.is_equal_approx(Vector3(6.0, 3.88, 68.3)),
		"rounded render bounds, placement and box collider preserve the exact 12.5 x 0.64 x 3.6 m route envelope"
	)
	var established_deck := world.get_node_or_null(
		^"ExposedDockLattice/AftModuleConnector/Mesh"
	) as MeshInstance3D
	var connector_bodies := connector.find_children("*", "StaticBody3D", true, false)
	var connector_meshes := connector.find_children("*", "MeshInstance3D", true, false)
	var connector_shapes := connector.find_children("*", "CollisionShape3D", true, false)
	var connector_submissions := 0
	for candidate in connector_meshes:
		var mesh_instance := candidate as MeshInstance3D
		connector_submissions += mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0
	_check(
		established_deck != null
		and visual.material_override == established_deck.material_override
		and deck.get_child_count() == 2
		and connector.find_children("*", "", true, false).size() == 9
		and connector_bodies.size() == 3
		and connector_meshes.size() == 3
		and connector_shapes.size() == 3
		and connector_submissions == 3,
		"the gateway keeps deck-light material and the 9-node, 3-body/shape/renderer, 3-submission census"
	)
	_check(
		deck.collision_layer == PhysicsLayers.WORLD
		and deck.collision_mask == PhysicsLayers.NONE
		and connector.find_children("*", "ShipBerth", true, false).is_empty()
		and connector.find_children("*", "Area3D", true, false).is_empty(),
		"the gateway retains World-only collision with no berth or interaction authority"
	)
	_check(
		str(connector.get_meta("evidence_status", "")) == "modern_interpretation"
		and str(deck.get_meta("evidence_status", "")) == "modern_interpretation"
		and not bool(deck.get_meta("historical_form_identified", true))
		and str(deck.get_meta("geometry_profile", "")) == "horizontal_rounded_gateway"
		and is_equal_approx(float(deck.get_meta("corner_radius_m", 0.0)), 0.72)
		and int(deck.get_meta("curve_segments_per_corner", 0)) == 4,
		"the 0.72 m curve preserves the connector's honest modern-interpretation evidence status"
	)


func _test_retained_route(world: ShipyardWorld) -> void:
	var route_samples := PackedVector3Array([
		Vector3(-0.15, 4.2, 68.3),
		Vector3(0.1, 4.2, 68.3),
		Vector3(3.0, 4.2, 68.3),
		Vector3(6.0, 4.2, 68.3),
		Vector3(9.0, 4.2, 68.3),
		Vector3(11.8, 4.2, 68.3),
		Vector3(12.1, 4.2, 68.3),
	])
	var every_sample_supported := true
	var worst_height_error := 0.0
	for sample in route_samples:
		var hit := await _ray(world, sample + Vector3.UP * 2.5, sample + Vector3.DOWN * 2.5)
		every_sample_supported = every_sample_supported and not hit.is_empty()
		if not hit.is_empty():
			worst_height_error = maxf(
				worst_height_error,
				absf((hit.position as Vector3).y - 4.2)
			)
	_check(
		every_sample_supported and worst_height_error <= 0.02,
		"the exact Aft-deck-to-Comb centreline remains continuously supported at y = 4.2"
	)
	_check(
		bool(world.get_fleet_dock_comb_integration_audit_report().get("valid", false)),
		"the production Comb placement, assignments and connector audit remain green"
	)


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_DOCK_CONNECTOR_CURVE_TEST_OK")
		quit(0)
	else:
		print("FLEET_DOCK_CONNECTOR_CURVE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
