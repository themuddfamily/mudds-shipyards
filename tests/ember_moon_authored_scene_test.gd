extends SceneTree

const SCENE_PATH := "res://scenes/world/planets/ember_moon.tscn"
const EXPECTED_ASSERTIONS := 30
const INTEGRATION_AUTHORITY_KEYS := [
	"streaming", "game_flow", "gameplay", "landing_decision", "ship_movement",
	"player_movement", "world_generation", "terrain_generation",
	"collision_generation", "origin_shift", "save", "network", "reward",
	"audio", "camera", "lighting",
]

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := ResourceLoader.load(SCENE_PATH) as PackedScene
	_check(packed != null, "the reserved Ember Moon path loads as a PackedScene")
	var scene := packed.instantiate() as EmberMoonAuthoredScene if packed != null else null
	_check(scene != null, "the scene instantiates as the typed authored runtime component")
	if scene == null:
		_finish()
		return
	root.add_child(scene)
	await process_frame
	await physics_frame
	_test_identity_and_audit(scene)
	_test_geometry_and_markers(scene)
	_test_collision(scene)
	_test_lod_seam(scene)
	await _test_detachment_and_structured_reds(packed, scene)
	scene.queue_free()
	await process_frame
	_finish()


func _test_identity_and_audit(scene: EmberMoonAuthoredScene) -> void:
	var audit := scene.audit()
	_check(audit.valid and (audit.errors as Array).is_empty(), "the exact static authored scene audits green")
	_check(
		scene.get_world_id() == &"ember_moon"
			and scene.get_body_id() == &"ember_body"
			and scene.get_region_id() == &"ember_caldera",
		"runtime identity exactly matches the authored definition join",
	)
	var snapshot := scene.get_snapshot()
	_check(
		snapshot.coordinate_contract.scene_root_reference == &"body_center"
			and snapshot.coordinate_contract.body_radius_m == 120_000.0
			and snapshot.coordinate_contract.body_visual_radius_m == 119_999.0
			and snapshot.coordinate_contract.body_visual_inset_m == 1.0,
		"the physical datum remains 120 km while the noncolliding silhouette is explicitly inset",
	)
	_check(
		(audit.owned_capabilities as Dictionary) == {
			"presentation_geometry": true,
			"static_world_collision": true,
		},
		"audit truthfully owns only presentation geometry and bounded static collision",
	)
	_check(_exact_all_false(audit.integration_authority, INTEGRATION_AUTHORITY_KEYS), "all runtime integration authority remains exactly false")
	_check(not scene.is_processing() and not scene.is_physics_processing(), "the authored scene has no automatic process loop")
	_check(
		audit.performance.node_count == 13
			and audit.performance.mesh_instances == 4
			and audit.performance.static_bodies == 1
			and audit.performance.collision_shapes == 1
			and audit.performance.triangle_count <= 8192,
		"live topology and primitive triangles stay inside the exact bounded budget",
	)
	_check(_forbidden_node_count(scene) == 0, "the scene owns no camera, light, audio, navigation, actor, area, particle, or animation node")


func _test_geometry_and_markers(scene: EmberMoonAuthoredScene) -> void:
	var landing_root := scene.get_node(^"LandingRegion") as Node3D
	var body := scene.get_node(^"BodyVisual") as MeshInstance3D
	var floor := scene.get_node(^"LandingRegion/CalderaFloor") as MeshInstance3D
	var rim := scene.get_node(^"LandingRegion/CalderaRim") as MeshInstance3D
	_check(landing_root.transform == Transform3D(Basis.IDENTITY, Vector3(0.0, 120_000.0, 0.0)), "landing geometry remains under the exact +Y body-local frame")
	_check(
		(body.mesh as SphereMesh).radius == 119_999.0
			and (floor.mesh as CylinderMesh).top_radius == 256.0
			and (rim.mesh as TorusMesh).inner_radius == 240.0
			and (rim.mesh as TorusMesh).outer_radius == 280.0,
		"body silhouette and bounded caldera proxy retain exact authored radii",
	)
	var markers := scene.get_body_local_marker_transforms()
	_check(markers.size() == 4, "exactly four detached landing marker transforms are published")
	_check((markers.caldera_pad as Transform3D).origin == Vector3(0.0, 120_000.0, 0.0), "pad marker composes to the sea-level body-local point")
	_check((markers.caldera_approach as Transform3D).origin == Vector3(0.0, 120_060.0, 300.0), "approach marker composes through the landing-region frame")
	_check((markers.caldera_pad_egress as Transform3D).origin == Vector3(18.0, 120_000.0, 0.0), "egress marker composes through the landing-region frame")
	_check((markers.caldera_staging_gate as Transform3D).origin == Vector3(42.0, 120_000.0, 0.0), "staging marker composes through the landing-region frame")
	markers[&"caldera_pad"] = Transform3D.IDENTITY
	_check((scene.get_body_local_marker_transforms().caldera_pad as Transform3D).origin == Vector3(0.0, 120_000.0, 0.0), "returned marker dictionaries are detached")


func _test_collision(scene: EmberMoonAuthoredScene) -> void:
	var body := scene.get_node(^"LandingRegion/WalkablePatch") as StaticBody3D
	var collision := scene.get_node(^"LandingRegion/WalkablePatch/CollisionShape3D") as CollisionShape3D
	_check(
		body.position == Vector3(0.0, -0.25, 0.0)
			and body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
			and body.collision_mask == PhysicsLayers.WORLD_BODY_MASK
			and (collision.shape as BoxShape3D).size == Vector3(96.0, 0.5, 96.0),
		"one exact World-layer box places its top at the landing tangent plane",
	)
	var space := scene.get_world_3d().direct_space_state
	var hit_pad := _ray_hit(space, Vector3(0.0, 120_002.0, 0.0))
	var hit_egress := _ray_hit(space, Vector3(18.0, 120_002.0, 0.0))
	var hit_staging := _ray_hit(space, Vector3(42.0, 120_002.0, 0.0))
	var outside := _ray_hit(space, Vector3(49.0, 120_002.0, 0.0))
	_check(not hit_pad.is_empty() and hit_pad.collider == body, "the pad point is collision-supported")
	_check(not hit_egress.is_empty() and hit_egress.collider == body, "the egress point is collision-supported")
	_check(not hit_staging.is_empty() and hit_staging.collider == body, "the staging point is collision-supported")
	_check(outside.is_empty(), "collision fails closed immediately beyond the authored +/-48m patch")


func _test_lod_seam(scene: EmberMoonAuthoredScene) -> void:
	var ring_zero := scene.evaluate_terrain_lod_hint(256.0, false)
	var ring_one := scene.evaluate_terrain_lod_hint(256.001, false)
	_check(ring_zero.accepted and ring_zero.render_ring_index == 0 and ring_one.render_ring_index == 1, "LOD hint keeps the first inclusive near-to-far boundary")
	var collision_edge := scene.evaluate_terrain_lod_hint(1500.0, true)
	var collision_outside := scene.evaluate_terrain_lod_hint(1500.001, true)
	_check(collision_edge.collision_participates and not collision_outside.collision_participates, "terrain collision hint preserves the exact inclusive 1500m boundary")
	var far_edge := scene.evaluate_terrain_lod_hint(18_432.0, false)
	var beyond := scene.evaluate_terrain_lod_hint(18_432.001, false)
	_check(far_edge.render_ring_index == 4 and beyond.accepted and not beyond.render_participates, "outermost ring is inclusive and farther distances do not participate")


func _test_detachment_and_structured_reds(packed: PackedScene, scene: EmberMoonAuthoredScene) -> void:
	var audit := scene.audit()
	(audit.snapshot.marker_transforms_body_local as Dictionary).clear()
	(audit.integration_authority as Dictionary)["streaming"] = true
	_check(
		scene.audit().valid
			and scene.get_body_local_marker_transforms().size() == 4
			and not bool(scene.audit().integration_authority.streaming),
		"nested audit mutation cannot alter later reports or live authored state",
	)
	var drifted := packed.instantiate() as EmberMoonAuthoredScene
	root.add_child(drifted)
	await process_frame
	(drifted.get_node(^"LandingRegion/Markers/PadEgress") as Marker3D).position.x = 19.0
	var drift_report := drifted.audit()
	_check(
		not drift_report.valid
			and (drift_report.error_codes as PackedStringArray).has("marker_transform_mismatch"),
		"marker drift produces a structured red code",
	)
	(drifted.get_node(^"LandingRegion/WalkablePatch") as StaticBody3D).collision_layer = 0
	var collision_report := drifted.audit()
	_check((collision_report.error_codes as PackedStringArray).has("walkable_body_drift"), "collision authority drift produces a structured red code")
	drifted.queue_free()
	await process_frame


func _ray_hit(space: PhysicsDirectSpaceState3D, origin: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + Vector3(0.0, -4.0, 0.0),
		PhysicsLayers.WORLD,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _forbidden_node_count(scene: Node) -> int:
	var count := 0
	for node in scene.find_children("*", "Node", true, false):
		if node is Camera3D or node is WorldEnvironment or node is Light3D \
				or node is Area3D or node is NavigationRegion3D \
				or node is AudioStreamPlayer or node is AudioStreamPlayer3D \
				or node is GPUParticles3D or node is CPUParticles3D \
				or node is AnimationPlayer or node is CharacterBody3D \
				or node is RigidBody3D:
			count += 1
	return count


func _exact_all_false(candidate: Dictionary, keys: Array) -> bool:
	if candidate.size() != keys.size():
		return false
	for key in keys:
		if not candidate.has(key) or not candidate[key] is bool or bool(candidate[key]):
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
	_check(_assertions == EXPECTED_ASSERTIONS - 1, "the focused assertion roster remains exact")
	print("EMBER_MOON_AUTHORED_SCENE_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("EMBER_MOON_AUTHORED_SCENE_TEST_OK")
		quit(0)
		return
	print("EMBER_MOON_AUTHORED_SCENE_TEST_FAILURES: %s" % _failures)
	quit(1)
