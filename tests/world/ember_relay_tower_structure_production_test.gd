extends SceneTree

const EmberScene := preload("res://scenes/world/planets/ember_moon.tscn")
const RELAY_PATH := ^"LandingRegion/SurfaceLandmarks/StagingRelay"
const HEAD_VISUAL_PATH := ^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadVisual"
const HEAD_COLLISION_PATH := ^"LandingRegion/SurfaceLandmarks/StagingRelay/HeadCollision"
const RELAY_ACCESS_ID: StringName = &"ember_staging_relay_access"

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := EmberScene.instantiate() as EmberMoonAuthoredScene
	root.add_child(first)
	await process_frame
	var first_snapshot := _structure_snapshot(first)
	_check(
		bool((first.audit() as Dictionary).valid)
			and first_snapshot.visual_shape == &"bevelled_prism"
			and first_snapshot.visual_size_m == Vector3(0.9, 0.45, 0.9)
			and int(first_snapshot.visual_triangles) == 8
			and first_snapshot.visual_position_m == Vector3(0.0, 3.25, 0.0)
			and first_snapshot.relay_position_m == Vector3(42.0, 0.0, 7.0),
		"the streamed relay head is a bounded bevelled prism at its authored anchor"
	)
	_check(
		first_snapshot.collision_shape == &"box"
			and first_snapshot.collision_size_m == Vector3(0.9, 0.45, 0.9)
			and first_snapshot.collision_position_m == Vector3(0.0, 3.25, 0.0)
			and not bool(first_snapshot.collision_disabled)
			and int(first_snapshot.collision_layer) == 1
			and int(first_snapshot.collision_mask) == 0,
		"the bevel remains inside the unchanged solid relay collision envelope"
	)
	var landing_markers := first.get_body_local_marker_transforms()
	var surface_markers := first.get_surface_landmark_marker_transforms()
	_check(
		(landing_markers.caldera_staging_gate as Transform3D).origin \
			== Vector3(42.0, 120000.0, 0.0)
			and (surface_markers[RELAY_ACCESS_ID] as Transform3D).origin \
				== Vector3(42.0, 120000.0, 4.4)
			and first_snapshot.landmark_id == &"ember_staging_relay",
		"landing, route, checkpoint, and relay identities remain at exact anchors"
	)
	_check(
		first_snapshot.content_class == &"NEW"
			and first_snapshot.status == &"modern_interpretation"
			and bool(first_snapshot.solid_visual_collision)
			and not first.is_processing() and not first.is_physics_processing(),
		"the static relay remains bounded modern-interpretation surface content"
	)

	root.remove_child(first)
	_check(
		not first.is_inside_tree()
			and _structure_snapshot(first) == first_snapshot,
		"streaming detach does not mutate relay geometry, collision, or anchors"
	)
	root.add_child(first)
	await process_frame
	_check(
		bool((first.audit() as Dictionary).valid)
			and _structure_snapshot(first) == first_snapshot,
		"same instance re-entry restores the identical passive relay structure"
	)
	var first_triangles := int((first.audit() as Dictionary).performance.triangle_count)
	first.queue_free()
	await process_frame

	var fresh := EmberScene.instantiate() as EmberMoonAuthoredScene
	root.add_child(fresh)
	await process_frame
	var fresh_snapshot := _structure_snapshot(fresh)
	var fresh_audit := fresh.audit() as Dictionary
	_check(
		bool(fresh_audit.valid)
			and fresh_snapshot == first_snapshot
			and int(fresh_audit.performance.node_count) == 81
			and int(fresh_audit.performance.mesh_instances) == 22
			and int(fresh_audit.performance.collision_shapes) == 26
			and int(fresh_audit.performance.triangle_count) == first_triangles
			and int(fresh_audit.performance.triangle_count) <= 60_000,
		"fresh streaming generation resets the relay and bounded terrain within the retained scene budget"
	)

	for failure in _failures:
		push_error(failure)
	print("EMBER_RELAY_TOWER_STRUCTURE_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _structure_snapshot(scene: EmberMoonAuthoredScene) -> Dictionary:
	var relay := scene.get_node(RELAY_PATH) as StaticBody3D
	var head := scene.get_node(HEAD_VISUAL_PATH) as MeshInstance3D
	var prism := head.mesh as PrismMesh
	var collision := scene.get_node(HEAD_COLLISION_PATH) as CollisionShape3D
	var box := collision.shape as BoxShape3D
	return {
		"visual_shape": &"bevelled_prism" if prism != null else &"invalid",
		"visual_size_m": prism.size if prism != null else Vector3.ZERO,
		"visual_triangles": int(prism.get_faces().size() / 3) if prism != null else 0,
		"visual_position_m": head.position,
		"collision_shape": &"box" if box != null else &"invalid",
		"collision_size_m": box.size if box != null else Vector3.ZERO,
		"collision_position_m": collision.position,
		"collision_disabled": collision.disabled,
		"relay_position_m": relay.position,
		"collision_layer": relay.collision_layer,
		"collision_mask": relay.collision_mask,
		"landmark_id": relay.get_meta("landmark_id", &""),
		"content_class": relay.get_meta("content_class", &""),
		"status": relay.get_meta("status", &""),
		"solid_visual_collision": relay.get_meta("solid_visual_collision", false),
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
