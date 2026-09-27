extends SceneTree

## Focused contract for the ShipyardWorld structural edge treatment: the lattice
## decks, catwalk landing, Dock Operations control pod and launch-arm stock are
## re-cut at the station's 38.2 mm tool chamfer with their exact authored AABB,
## their colliders untouched, and their materials carrying the triplanar station
## family plus the packed ORM occlusion/metal set.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Named pieces that keep their own node through dressing consolidation, with
## their authored (collider) sizes.
const NAMED_PIECES := {
	^"ExposedDockLattice/CentralJunction": Vector3(25.0, 1.2, 0.0),
	^"ExposedDockLattice/StarboardBerthNode": Vector3(12.0, 1.2, 17.0),
	^"UpperOperations/ObservationLanding": Vector3(4.6, 0.55, 4.4),
	^"UpperOperations/OperationsPodFloor": Vector3(12.0, 0.4, 8.0),
	^"UpperOperations/OperationsPodBack": Vector3(12.0, 5.5, 0.5),
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tool_mesh_recipe()
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame

	var report := world.get_structural_edge_treatment_report()
	var pieces := report.get("pieces", []) as Array
	_check(
		bool(report.get("valid", false)) and (report.get("errors", PackedStringArray()) as PackedStringArray).is_empty(),
		"the structural edge pass reports no AABB drift, missing root or budget error: %s" % str(report.get("errors"))
	)
	_check(
		pieces.size() >= 20,
		"the pass re-cuts the lattice, catwalk, control-room and launch stock (%d pieces)" % pieces.size()
	)
	var delta := int(report.get("resident_triangle_delta", 1))
	_check(
		delta == pieces.size() * (
			StationStructuralEdgeTreatment.TOOL_CHAMFER_TRIANGLES
			- StationStructuralEdgeTreatment.ROLLED_BOX_TRIANGLES
		) and delta <= StationStructuralEdgeTreatment.MAX_RESIDENT_TRIANGLE_DELTA,
		"the resident triangle delta is inside the +6,000 allowance (%d)" % delta
	)

	var roots_seen := {}
	var cache := world.get("_structural_edge_cache") as Dictionary
	var every_piece_exact := true
	var every_piece_mapped := true
	for piece_variant in pieces:
		var piece := piece_variant as Dictionary
		var size := piece.get("size", Vector3.ZERO) as Vector3
		var path := piece.get("path", NodePath()) as NodePath
		roots_seen[String(path).get_slice("/", 0)] = true
		var mesh := StationStructuralEdgeTreatment.tool_chamfer_mesh_cached(size, cache)
		every_piece_exact = every_piece_exact \
			and mesh.get_aabb().is_equal_approx(AABB(-size * 0.5, size)) \
			and mesh.get_faces().size() / 3 == StationStructuralEdgeTreatment.TOOL_CHAMFER_TRIANGLES \
			and is_equal_approx(float(piece.get("chamfer_m", 0.0)), ShipChamferedStock.largest_resolvable_chamfer()) \
			and float(piece.get("previous_bevel_m", 0.0)) > float(piece.get("chamfer_m", 1.0))
		every_piece_mapped = every_piece_mapped \
			and bool(piece.get("triplanar_bound", false)) \
			and bool(piece.get("orm_bound", false))
	_check(every_piece_exact, "every treated piece keeps its exact authored AABB on the 44-triangle 38.2 mm recipe")
	_check(every_piece_mapped, "every treated piece carries the triplanar station family and the packed ORM set")
	_check(
		roots_seen.has("ExposedDockLattice") and roots_seen.has("UpperOperations") and roots_seen.has("OpenLaunchSpine"),
		"treated pieces span the lattice, the catwalk/control pod and the launch arm: %s" % str(roots_seen.keys())
	)

	for node_path: NodePath in NAMED_PIECES:
		_test_named_piece(world, node_path, NAMED_PIECES[node_path] as Vector3)

	var materials := world.get("_materials") as Dictionary
	var steel := materials.get("steel_blue") as StandardMaterial3D
	var deck := materials.get("deck") as StandardMaterial3D
	_check(
		steel != null and steel.ao_enabled
		and StationSurfaceKit.texture_path(steel.ao_texture) == StationSurfaceKit.PANEL_ORM_PATH
		and steel.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and StationSurfaceKit.texture_path(steel.metallic_texture) == StationSurfaceKit.PANEL_ORM_PATH
		and steel.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		and StationSurfaceKit.texture_path(steel.roughness_texture) == StationSurfaceKit.PANEL_ROUGHNESS_PATH,
		"metal trim binds packed occlusion (R) and metal mask (B) while keeping the registered roughness map"
	)
	_check(
		deck != null and deck.ao_enabled and deck.metallic_texture == null
		and is_equal_approx(deck.ao_light_affect, 0.35),
		"walked deck binds packed occlusion only; its scalar metalness is not masked"
	)

	world.queue_free()
	await process_frame
	_finish()


func _test_tool_mesh_recipe() -> void:
	var cache := {}
	var size := Vector3(4.6, 0.55, 4.4)
	var first := StationStructuralEdgeTreatment.tool_chamfer_mesh_cached(size, cache)
	var second := StationStructuralEdgeTreatment.tool_chamfer_mesh_cached(size, cache)
	_check(
		first == second and first.resource_name == StationStructuralEdgeTreatment.MESH_RESOURCE_NAME
		and first.get_aabb().is_equal_approx(AABB(-size * 0.5, size))
		and first.get_surface_count() == 1,
		"the tool-chamfer mesh is cached per size, one surface, exact AABB"
	)
	_check(
		is_equal_approx(StationStructuralEdgeTreatment.chamfer_for_size(size), ShipChamferedStock.largest_resolvable_chamfer())
		and StationStructuralEdgeTreatment.minimum_treated_section() < 0.2,
		"structural stock is cut at the 38.2 mm tool width"
	)


func _test_named_piece(world: ShipyardWorld, node_path: NodePath, authored_size: Vector3) -> void:
	var body := world.get_node_or_null(node_path) as StaticBody3D
	var visual := body.get_node_or_null(^"Mesh") as MeshInstance3D if body != null else null
	var collision := body.get_node_or_null(^"Collision") as CollisionShape3D if body != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	if body == null or visual == null or shape == null:
		_check(false, "%s resolves with its Mesh and box Collision" % node_path)
		return
	var size := shape.size
	if authored_size.z > 0.0:
		_check(size.is_equal_approx(authored_size), "%s collider keeps its authored size %s" % [node_path, authored_size])
	var material := visual.material_override as StandardMaterial3D
	_check(
		visual.mesh != null
		and visual.mesh.resource_name == StationStructuralEdgeTreatment.MESH_RESOURCE_NAME
		and visual.mesh.get_aabb().is_equal_approx(AABB(-size * 0.5, size))
		and visual.position.is_zero_approx()
		and collision.position.is_zero_approx()
		and material != null and material.uv1_world_triplanar and material.ao_enabled,
		"%s draws the tool-chamfered mesh over its unchanged collider with the mapped ORM material" % node_path
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_STRUCTURAL_EDGE_TREATMENT_TEST_OK")
		quit(0)
	else:
		push_error("%d structural edge treatment assertion(s) failed" % _failures.size())
		quit(1)
