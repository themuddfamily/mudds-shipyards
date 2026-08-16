extends SceneTree

## Focused contract for the world-owned ModernFleetRegistry pod.
##
## The four roof columns remain four independently colliding bodies; only their
## identical child render meshes are drawn through one sibling MultiMesh batch.
## This suite freezes that local delta and the registry paths the optimization
## must never absorb.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD
const COLUMN_SIZE := Vector3(0.34, 5.4, 0.34)
const COLUMN_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-48.6, 2.95, 23.4)),
	Transform3D(Basis.IDENTITY, Vector3(-48.6, 2.95, 30.4)),
	Transform3D(Basis.IDENTITY, Vector3(-37.4, 2.95, 23.4)),
	Transform3D(Basis.IDENTITY, Vector3(-37.4, 2.95, 30.4)),
]
const PRESERVED_SIGN_PATHS: Array[NodePath] = [
	^"Sign_FLEET_REGISTRY__--__MODERN_INTERFACE",
	^"Sign_SAY_SHIP_NAME",
	^"Sign_TORRENT__JOVIAN__TITAN__VORTEX",
	^"Sign_KATANA__PARADOX__PREDATOR__DYNAMIC",
	^"Sign_UTOPIA__ARROW",
	^"Sign_ACTIVE_BERTH__--__CENTRE_SPINE",
	^"Sign_REGISTERED_BERTHS",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the modern registry audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var registry := game.get_node_or_null(^"ShipyardWorld/ModernFleetRegistry") as Node3D
	_check(world != null and registry != null, "production ModernFleetRegistry resolves under ShipyardWorld")
	if world != null and registry != null:
		_test_local_render_contract(world, registry)
		_test_column_batch(world, registry)
		_test_preserved_registry_paths(world, registry)
		_test_mutation_guards(world, registry)

	game.queue_free()
	await process_frame
	_finish()


func _test_local_render_contract(world: ShipyardWorld, registry: Node3D) -> void:
	var report := world.get_modern_fleet_registry_render_contract()
	_check(bool(report.get("valid", false)), "production modern-registry render contract is green: %s" % [report.get("errors", [])])
	_check(
		int(report.get("descendant_nodes", -1)) == 62
		and int(report.get("mesh_instances", -1)) == 35
		and int(report.get("multimesh_batches", -1)) == 1,
		"local renderer nodes freeze at 65 -> 62, MeshInstances 39 -> 35, batches 0 -> 1"
	)
	_check(
		int(report.get("drawn_copies", -1)) == 39
		and int(report.get("geometry_submissions", -1)) == 36
		and bool(report.get("exact_counts", false)),
		"all 39 local copies remain drawn while structural submissions fall 39 -> 36"
	)
	_check(
		int(report.get("physics_bodies", -1)) == 12
		and int(report.get("collision_shapes", -1)) == 12
		and int(report.get("lights", -1)) == 2
		and int(report.get("areas", -1)) == 0,
		"batching leaves the pod's 12 bodies, 12 shapes, two lights and zero areas unchanged"
	)
	_check(
		bool(report.get("registry_parent_is_world", false))
		and bool(report.get("registry_transform_identity", false))
		and bool(report.get("process_free", false)),
		"the registry remains a process-free identity child of ShipyardWorld"
	)


func _test_column_batch(world: ShipyardWorld, registry: Node3D) -> void:
	var batch := registry.get_node_or_null(^"RegistryPodColumnVisuals") as MultiMeshInstance3D
	_check(batch != null and batch.multimesh != null, "four column visuals resolve as one registry-local MultiMesh batch")
	if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
		return
	var multi := batch.multimesh
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == COLUMN_TRANSFORMS.size()
	for index in mini(authored.size(), COLUMN_TRANSFORMS.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(
			COLUMN_TRANSFORMS[index]
		)
	_check(
		multi.instance_count == 4
		and multi.visible_instance_count == -1
		and multi.transform_format == MultiMesh.TRANSFORM_3D
		and authored_exact,
		"one batch retains all four old column transforms in x-major/z-minor ordering"
	)
	if not RenderingServer.get_video_adapter_name().is_empty():
		var renderer_exact := true
		for index in COLUMN_TRANSFORMS.size():
			renderer_exact = renderer_exact and multi.get_instance_transform(index).is_equal_approx(
				COLUMN_TRANSFORMS[index]
			)
		_check(renderer_exact, "renderer transforms retain all four authored column copies exactly")

	var steel_reference := registry.get_node_or_null(^"RegistryTerminalRiser") as MeshInstance3D
	_check(
		multi.mesh.get_aabb().size.is_equal_approx(COLUMN_SIZE)
		and multi.mesh.get_surface_count() == 1
		and steel_reference != null
		and batch.material_override == steel_reference.material_override
		and bool(world.get_modern_fleet_registry_render_contract().get("mesh_identity_matches_cache", false))
		and bool(world.get_modern_fleet_registry_render_contract().get("material_identity_matches_shared_palette", false)),
		"the batch retains the cached chamfered mesh and shared steel-blue material identities"
	)
	_check(
		batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1
		and batch.material_overlay == null
		and batch.get_child_count() == 0
		and bool(batch.get_meta("visual_detail_only", false)),
		"the childless visual batch preserves parent-space transforms, shadows, layers and overlay"
	)
	_check(
		multi.buffer.size() == COLUMN_TRANSFORMS.size() * 12
		and multi.custom_aabb.is_equal_approx(_transformed_bounds(multi.mesh.get_aabb(), COLUMN_TRANSFORMS)),
		"renderer payload carries 12 floats per copy and the exact four-column culling union"
	)

	var matched_bodies: Array[StaticBody3D] = []
	for expected in COLUMN_TRANSFORMS:
		var matches: Array[StaticBody3D] = []
		for child in registry.get_children():
			if child is StaticBody3D and (child as StaticBody3D).transform.is_equal_approx(expected):
				matches.append(child as StaticBody3D)
		_check(matches.size() == 1, "one physical column remains at %s" % expected.origin)
		if matches.size() == 1:
			matched_bodies.append(matches[0])
	var collisions_exact := matched_bodies.size() == COLUMN_TRANSFORMS.size()
	for body in matched_bodies:
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		collisions_exact = (
			collisions_exact
			and body.collision_layer == WORLD_LAYER
			and body.collision_mask == 0
			and body.get_child_count() == 1
			and body.find_children("*", "MeshInstance3D", true, false).is_empty()
			and shape != null
			and shape.size.is_equal_approx(COLUMN_SIZE)
		)
	_check(
		collisions_exact
		and not matched_bodies.is_empty()
		and matched_bodies[0].name == &"RegistryPodColumn",
		"all four column bodies/colliders and the stable RegistryPodColumn path remain independent"
	)


func _test_preserved_registry_paths(world: ShipyardWorld, registry: Node3D) -> void:
	_check(
		registry.get_node_or_null(^"RegistryPodDeck") is StaticBody3D
		and registry.get_node_or_null(^"RegistryPodThreshold") is StaticBody3D
		and registry.get_node_or_null(^"FleetRegistryTerminal") is StaticBody3D
		and registry.get_node_or_null(^"RegistryScreen") is MeshInstance3D
		and registry.get_node_or_null(^"BerthIndicatorBase") is StaticBody3D,
		"deck, threshold, terminal, screen and berth-indicator authority paths are unchanged"
	)
	var tile_roster_exact := true
	for tile_index in ShipyardWorld.SHIP_BERTH_FEEDBACK_BERTH_IDS.size():
		tile_roster_exact = tile_roster_exact and registry.get_node_or_null(
			NodePath("RegistryBerthTile%02d" % (tile_index + 1))
		) is MeshInstance3D
	_check(
		tile_roster_exact
		and ShipyardWorld.SHIP_BERTH_FEEDBACK_BERTH_IDS.size() == 5,
		"all five independently named readiness tiles remain outside the batch"
	)
	var signs_exact := true
	for path in PRESERVED_SIGN_PATHS:
		var sign_node := registry.get_node_or_null(path) as MeshInstance3D
		signs_exact = signs_exact and sign_node != null and sign_node.mesh is TextMesh
	_check(signs_exact, "all seven registry labels/evidence-facing legends retain their stable paths")
	_check(
		registry.get_node_or_null(^"RegistryDispatchBoard") is MeshInstance3D
		and registry.get_node_or_null(^"RegistryTaskLampHousing") is MeshInstance3D
		and registry.get_node_or_null(^"RegistryToolRack") is MeshInstance3D
		and registry.get_node_or_null(^"RegistryPartsTray") is MeshInstance3D
		and registry.get_node_or_null(^"RegistryStowedManifest") is MeshInstance3D
		and bool(world.get_modern_fleet_registry_render_contract().get("preserved_paths_match", false)),
		"dispatch, task, tool, parts and manifest state-readable paths remain independent"
	)


func _test_mutation_guards(world: ShipyardWorld, registry: Node3D) -> void:
	var batch := registry.get_node_or_null(^"RegistryPodColumnVisuals") as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var published := world.get_modern_fleet_registry_render_contract().get(
		"authored_column_transforms", []
	) as Array
	published[0] = Transform3D.IDENTITY
	var detached := world.get_modern_fleet_registry_render_contract().get(
		"authored_column_transforms", []
	) as Array
	_check(
		detached.size() == 4
		and not (detached[0] as Transform3D).is_equal_approx(Transform3D.IDENTITY),
		"the published column roster is deep-detached from callers"
	)

	var original_buffer := multi.buffer.duplicate()
	var moved_buffer := original_buffer.duplicate()
	moved_buffer[3] += 0.1
	multi.buffer = moved_buffer
	var moved := world.get_modern_fleet_registry_render_contract()
	_check(
		not bool(moved.get("valid", true))
		and not bool(moved.get("renderer_buffer_matches_authored", true)),
		"moving a renderer-buffer copy turns the production contract red"
	)
	multi.buffer = original_buffer

	var original_bounds := multi.custom_aabb
	multi.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.001)
	var culled := world.get_modern_fleet_registry_render_contract()
	_check(
		not bool(culled.get("valid", true))
		and not bool(culled.get("bounds_match_authored", true)),
		"shrinking the explicit culling union turns the production contract red"
	)
	multi.custom_aabb = original_bounds

	var original_material := batch.material_override
	var alternate := (registry.get_node(^"RegistryScreen") as MeshInstance3D).material_override
	batch.material_override = alternate
	var rematerialed := world.get_modern_fleet_registry_render_contract()
	_check(
		not bool(rematerialed.get("valid", true))
		and not bool(rematerialed.get("material_identity_matches_shared_palette", true)),
		"breaking shared material identity turns the production contract red"
	)
	batch.material_override = original_material

	var bodies := registry.find_children("*", "StaticBody3D", true, false)
	var first_column: StaticBody3D = null
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		if body.transform.is_equal_approx(COLUMN_TRANSFORMS[0]):
			first_column = body
			break
	_check(first_column != null, "the first retained column body resolves for collision mutation")
	if first_column == null:
		return
	var collision := first_column.get_node(^"Collision") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	var original_size := shape.size
	shape.size = original_size + Vector3(0.1, 0.0, 0.0)
	var reshaped := world.get_modern_fleet_registry_render_contract()
	_check(
		not bool(reshaped.get("valid", true))
		and not bool(reshaped.get("column_collision_matches", true)),
		"changing one retained column collider turns the production contract red"
	)
	shape.size = original_size
	_check(
		bool(world.get_modern_fleet_registry_render_contract().get("valid", false)),
		"restoring buffer, bounds, material and collider returns the contract to green"
	)


func _transformed_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for transform_value in transforms:
		var piece := (transform_value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("MODERN_FLEET_REGISTRY_TEST_OK")
		quit(0)
	else:
		push_error("MODERN_FLEET_REGISTRY_TEST_FAILED: %s" % _failures)
		quit(1)
