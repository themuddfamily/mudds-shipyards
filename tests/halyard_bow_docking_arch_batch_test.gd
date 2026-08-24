extends SceneTree

## Focused Phase 10 contract for the Halyard's three immutable hull-shade bow
## arch faces. Docking landmarks, collision, boarding, crew authority and ship
## lifecycle remain outside the presentation-only renderer batch.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var visual := craft.get_halyard_visual_root()
	var batch := visual.get_node_or_null(^"BowDockingArchShadeBatch") as MultiMeshInstance3D \
		if visual != null else null
	_check(batch != null and batch.multimesh != null, "the production Halyard owns one bow-arch shade batch")
	if batch == null or batch.multimesh == null:
		_finish(craft)
		return

	var expected_names := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for segment_index in [0, 2, 4]:
		var angle := PI * float(segment_index) / 4.0
		expected_names.append("BowDockingArchSegment%02d" % segment_index)
		expected_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, angle + PI * 0.5)),
			Vector3(
				HalyardCrewTransport.BOW_RING_RADIUS * cos(angle),
				HalyardCrewTransport.BOW_RING_CENTRE_Y
					+ HalyardCrewTransport.BOW_RING_RADIUS * sin(angle),
				HalyardCrewTransport.BOW_RING_Z
			)
		))
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var transforms_exact := authored.size() == expected_transforms.size()
	for index in mini(authored.size(), expected_transforms.size()):
		transforms_exact = transforms_exact \
			and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
	var segment_length := 2.0 * HalyardCrewTransport.BOW_RING_RADIUS * tan(PI / 8.0)
	_check(
		batch.multimesh.instance_count == HalyardCrewTransport.BOW_DOCKING_ARCH_SHADE_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
			and transforms_exact
			and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
				Vector3(segment_length, 0.34, 0.55)
			)
			and batch.material_override == craft.get_variant_materials().get("hull_shade")
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1,
		"all three shade faces retain their exact transform, extent, material and renderer policy"
	)
	_check(
		visual.get_node_or_null(^"BowDockingArchSegment00") == null
			and visual.get_node_or_null(^"BowDockingArchSegment02") == null
			and visual.get_node_or_null(^"BowDockingArchSegment04") == null
			and visual.get_node_or_null(^"BowDockingArchSegment01") is MeshInstance3D
			and visual.get_node_or_null(^"BowDockingArchSegment03") is MeshInstance3D
			and visual.get_node_or_null(^"BowDockingTargetPlate") is MeshInstance3D
			and visual.find_children("BowDockingArchStrut*", "MeshInstance3D", true, false).size() == 2
			and batch.get_meta("visual_detail_only", false)
			and batch.get_child_count() == 0
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"three visual-only faces collapse to one submission while accent faces and docking landmarks remain"
	)

	var render := craft.get_halyard_render_allocation_report()
	_check(
		int(render.get("descendant_nodes", -1)) == 116
			and int(render.get("mesh_instances", -1)) == 105
			and int(render.get("multimesh_batches", -1)) == 6
			and int(render.get("drawn_copies", -1)) == 163
			and int(render.get("geometry_submissions", -1)) == 111
			and bool(render.get("exact_counts", false)),
		"the exterior keeps 163 drawn copies while submissions fall 113->111"
	)
	var full_counts := _render_counts(craft)
	_check(
		int(full_counts.renderers) == 264
			and int(full_counts.mesh_instances) == 255
			and int(full_counts.multimesh_batches) == 9
			and int(full_counts.authored_copies) == 339
			and int(full_counts.geometry_submissions) == 264,
		"the full craft keeps 339 visual copies while allocations fall 266->264"
	)

	var collision_count := craft.find_children("*", "CollisionShape3D", true, false).size()
	var access_transform := craft.get_interior_access_marker().transform
	var deck_transform := craft.get_interior_deck_marker().transform
	var seat_transforms: Array[Transform3D] = []
	for anchor in craft.get_crew_seat_anchors():
		seat_transforms.append((anchor as Marker3D).transform)
	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false))
			and bool(craft.attach_crew_role_authority(authority).get("accepted", false))
			and bool(authority.claim(
				1, 91, &"arch_test_engineer", &"crew_port_01", Authority.ROLE_ENGINEER, 1
			).get("accepted", false))
			and craft.get_pilot_seat_anchor() != null
			and craft.get_co_pilot_station_anchor() != null
			and craft.get_crew_seat_anchors().size() == 6
			and craft.get_loadmaster_station_anchor() != null,
		"pilot, gunner, passenger, engineer and loadmaster roles remain authoritative"
	)
	_check(
		craft.get_moving_interior_component().get_moving_frame() == craft
			and bool(craft.get_in_flight_cabin_report().get("supported", false))
			and bool(craft.get_ship_perspective_audio_snapshot().get("attached", false))
			and bool(craft.get_loadmaster_audio_snapshot().get("attached", false))
			and bool(craft.get_halyard_audit_report().get("valid", false)),
		"moving interior, audio, collision, boarding and production silhouette contracts remain valid"
	)

	var geometry_before := _geometry_signature(batch)
	var damage := craft.get_component_damage().record_damage(9.0, Vector3.ZERO)
	_check(
		bool(damage.get("accepted", false))
			and craft.get_engineer_repair_state().get("status", &"") == &"idle"
			and _geometry_signature(batch) == geometry_before,
		"component damage and repair state remain ship-owned without mutating arch geometry"
	)
	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(
		bool(reset.get("accepted", false))
			and _geometry_signature(batch) == geometry_before
			and craft.find_children("*", "CollisionShape3D", true, false).size() == collision_count
			and craft.get_interior_access_marker().transform.is_equal_approx(access_transform)
			and craft.get_interior_deck_marker().transform.is_equal_approx(deck_transform)
			and _seat_transforms_match(craft.get_crew_seat_anchors(), seat_transforms),
		"reset-for-reuse preserves arch silhouette, boarding, collision and every crew seat"
	)

	print(
		"HALYARD_BOW_DOCKING_ARCH_BATCH_METRICS: renderers=266->264 submissions=266->264 "
		+ "exterior_submissions=113->111 authored_copies=339->339 visual_review=NOT_RUN"
	)
	_finish(craft)


func _render_counts(craft: Node) -> Dictionary:
	var meshes := craft.find_children("*", "MeshInstance3D", true, false)
	var batches := craft.find_children("*", "MultiMeshInstance3D", true, false)
	var copies := meshes.size()
	var submissions := 0
	for raw_mesh in meshes:
		var mesh := (raw_mesh as MeshInstance3D).mesh
		submissions += mesh.get_surface_count() if mesh != null else 0
	for raw_batch in batches:
		var multi := (raw_batch as MultiMeshInstance3D).multimesh
		if multi != null:
			copies += multi.instance_count
			submissions += multi.mesh.get_surface_count() if multi.mesh != null else 0
	return {
		"renderers": meshes.size() + batches.size(),
		"mesh_instances": meshes.size(),
		"multimesh_batches": batches.size(),
		"authored_copies": copies,
		"geometry_submissions": submissions,
	}


func _geometry_signature(batch: MultiMeshInstance3D) -> String:
	if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
		return ""
	return "%s|%s|%s|%s" % [
		batch.get_meta("authored_visual_names", PackedStringArray()),
		batch.get_meta("authored_instance_transforms", []),
		batch.multimesh.mesh.get_aabb(),
		batch.multimesh.buffer,
	]


func _seat_transforms_match(anchors: Array[Marker3D], expected: Array[Transform3D]) -> bool:
	if anchors.size() != expected.size():
		return false
	for index in anchors.size():
		if not anchors[index].transform.is_equal_approx(expected[index]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish(craft: Node) -> void:
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_BOW_DOCKING_ARCH_BATCH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		quit(1)
