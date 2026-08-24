extends SceneTree

## Focused Phase 10 contract for the Halyard's four immutable airstair treads.
## The renderer batch owns presentation only; the separate ramp collider, route
## markers, seats and ship systems remain authoritative.

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
	var batch := visual.get_node_or_null(^"AirstairTreadBatch") as MultiMeshInstance3D \
		if visual != null else null
	_check(batch != null and batch.multimesh != null, "the production Halyard owns one airstair-tread batch")
	if batch == null or batch.multimesh == null:
		_finish(craft)
		return

	var expected_names := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for tread_index in HalyardCrewTransport.AIRSTAIR_TREAD_COPY_COUNT:
		expected_names.append("AirstairTread%02d" % tread_index)
		expected_transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(
				-2.86 - float(tread_index) * 0.42,
				0.24 - float(tread_index) * 0.44,
				HalyardCrewTransport.AIRSTAIR_Z
			)
		))
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var transforms_exact := authored.size() == expected_transforms.size()
	for index in mini(authored.size(), expected_transforms.size()):
		transforms_exact = transforms_exact \
			and (authored[index] as Transform3D).is_equal_approx(expected_transforms[index])
	_check(
		batch.multimesh.instance_count == HalyardCrewTransport.AIRSTAIR_TREAD_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
			and transforms_exact
			and batch.multimesh.mesh.get_aabb().size.is_equal_approx(HalyardCrewTransport.AIRSTAIR_TREAD_SIZE)
			and batch.material_override == craft.get_variant_materials().get("deck")
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1,
		"all four treads retain their exact transforms, extent, deck material and renderer policy"
	)
	_check(
		visual.find_children("AirstairTread*", "MeshInstance3D", true, false).is_empty()
			and batch.get_meta("visual_detail_only", false)
			and batch.get_child_count() == 0
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"four childless one-surface tread renderers collapse to one visual-only submission"
	)

	var render := craft.get_halyard_render_allocation_report()
	_check(
		int(render.get("mesh_instances", -1)) == 108
			and int(render.get("multimesh_batches", -1)) == 5
			and int(render.get("drawn_copies", -1)) == 163
			and int(render.get("geometry_submissions", -1)) == 113
			and bool(render.get("exact_counts", false)),
		"the exterior keeps 163 drawn copies while geometry submissions fall 116->113"
	)
	var full_counts := _render_counts(craft)
	_check(
		int(full_counts.renderers) == 266
			and int(full_counts.mesh_instances) == 258
			and int(full_counts.multimesh_batches) == 8
			and int(full_counts.authored_copies) == 339
			and int(full_counts.geometry_submissions) == 266,
		"the full craft keeps 339 visual copies while renderer allocations fall 269->266"
	)

	var collision_count := craft.find_children("*", "CollisionShape3D", true, false).size()
	var ramp := craft.get_node_or_null(^"PortAirstairCollision") as CollisionShape3D
	var access_transform := craft.get_interior_access_marker().transform
	var deck_transform := craft.get_interior_deck_marker().transform
	var seat_transforms: Array[Transform3D] = []
	for anchor in craft.get_crew_seat_anchors():
		seat_transforms.append((anchor as Marker3D).transform)
	_check(
		ramp != null
			and craft.get_interior_access_marker() != null
			and craft.get_interior_deck_marker() != null
			and craft.get_pilot_seat_anchor() != null
			and craft.get_co_pilot_station_anchor() != null
			and craft.get_crew_seat_anchors().size() == 6
			and craft.get_loadmaster_station_anchor() != null,
		"boarding collision and pilot, gunner, passenger, engineer and loadmaster seat anchors remain intact"
	)

	var authority := Authority.new(1)
	var roster := authority.register_halyard_roster()
	var attached := craft.attach_crew_role_authority(authority)
	var gunner := authority.claim(1, 71, &"tread_gunner", &"co_pilot_station", Authority.ROLE_GUNNER, 1)
	var passenger := authority.claim(1, 72, &"tread_passenger", &"crew_port_00", Authority.ROLE_PASSENGER, 1)
	var engineer := authority.claim(1, 73, &"tread_engineer", &"crew_port_01", Authority.ROLE_ENGINEER, 1)
	_check(
		bool(roster.get("accepted", false))
			and bool(attached.get("accepted", false))
			and bool(gunner.get("accepted", false))
			and bool(passenger.get("accepted", false))
			and bool(engineer.get("accepted", false)),
		"gunner, passenger and engineer claims remain server-authoritative"
	)
	_check(
		craft.get_moving_interior_component().get_moving_frame() == craft
			and bool(craft.get_in_flight_cabin_report().get("supported", false))
			and bool(craft.get_ship_perspective_audio_snapshot().get("attached", false))
			and bool(craft.get_loadmaster_audio_snapshot().get("attached", false))
			and bool(craft.get_halyard_audit_report().get("valid", false)),
		"moving interior, audio bindings and the production silhouette audit remain valid"
	)

	var geometry_before := _geometry_signature(batch)
	var damage := craft.get_component_damage().record_damage(9.0, Vector3.ZERO)
	_check(
		bool(damage.get("accepted", false))
			and craft.get_engineer_repair_state().get("status", &"") == &"idle"
			and _geometry_signature(batch) == geometry_before,
		"component damage and repair state remain ship-owned without mutating tread geometry"
	)
	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(
		bool(reset.get("accepted", false))
			and _geometry_signature(batch) == geometry_before
			and craft.find_children("*", "CollisionShape3D", true, false).size() == collision_count
			and craft.get_interior_access_marker().transform.is_equal_approx(access_transform)
			and craft.get_interior_deck_marker().transform.is_equal_approx(deck_transform)
			and _seat_transforms_match(craft.get_crew_seat_anchors(), seat_transforms),
		"reset-for-reuse preserves tread silhouette, boarding collision, routes and every crew seat"
	)

	print(
		"HALYARD_AIRSTAIR_TREAD_BATCH_METRICS: renderers=269->266 submissions=269->266 "
		+ "exterior_submissions=116->113 authored_copies=339->339 visual_review=NOT_RUN"
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
		print("HALYARD_AIRSTAIR_TREAD_BATCH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		quit(1)
