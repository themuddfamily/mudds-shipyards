extends SceneTree

## Focused Phase 9 contract for the six immutable Halyard aft-rack readouts.
## Their presentation is batched under the moving interior while repair,
## component damage, crew authority, collision and lifecycle remain ship-owned.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const GEOMETRY_SHA256 := "b4790ca4de29ac91a09d11a06e1ed56ec3225d413443e9bec31f3250435b8118"

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

	var batch := craft.get_node_or_null(
		^"WalkableInterior/AftSystemsBay/AftRackPanelBatch"
	) as MultiMeshInstance3D
	var expected_names := PackedStringArray()
	var expected_transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for panel_index in 3:
			expected_names.append(side_name + "RackPanel%02d" % panel_index)
			expected_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(side * 1.42, 1.68 + float(panel_index) * 0.56, 3.85)
			))
	_check(batch != null and batch.multimesh != null, "the production Halyard owns one aft-rack panel batch")
	if batch == null or batch.multimesh == null:
		_finish(craft)
		return

	var authored_names := batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray
	var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
	var transforms_exact := authored_transforms.size() == expected_transforms.size()
	for index in mini(authored_transforms.size(), expected_transforms.size()):
		transforms_exact = transforms_exact \
			and (authored_transforms[index] as Transform3D).is_equal_approx(expected_transforms[index])
	_check(
		batch.multimesh.instance_count == HalyardCrewTransport.AFT_RACK_PANEL_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and authored_names == expected_names
			and transforms_exact
			and batch.get_meta("visual_detail_only", false)
			and batch.material_override == craft.get_variant_materials().get("display"),
		"all six named readouts retain their authored transforms and display material"
	)
	var raw_panels := craft.find_children("*RackPanel*", "MeshInstance3D", true, false)
	_check(
		raw_panels.is_empty()
			and batch.multimesh.mesh.get_surface_count() == 1
			and batch.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"six one-surface readout submissions collapse to one collision-free renderer"
	)

	var counts := _render_counts(craft)
	_check(
		int(counts.renderers) == 269
			and int(counts.mesh_instances) == 262
			and int(counts.multimesh_batches) == 7
			and int(counts.authored_copies) == 339
			and int(counts.geometry_submissions) == 269,
		"the full production craft retains 339 visual copies while submissions fall 274->269"
	)
	var geometry_hash := _rack_geometry_hash(batch)
	print("HALYARD_AFT_RACK_PANEL_BATCH_ACTUAL: %s geometry_sha256=%s" % [counts, geometry_hash])
	_check(
		geometry_hash == GEOMETRY_SHA256,
		"the canonical rack-panel geometry hash remains %s" % GEOMETRY_SHA256
	)

	var collision_count := craft.find_children("*", "CollisionShape3D", true, false).size()
	var seat_transforms: Array[Transform3D] = []
	for anchor in craft.get_crew_seat_anchors():
		seat_transforms.append((anchor as Marker3D).transform)
	var access_transform := craft.get_interior_access_marker().transform
	var deck_transform := craft.get_interior_deck_marker().transform
	var frame := craft.get_moving_interior_component()
	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false))
			and bool(craft.attach_crew_role_authority(authority).get("accepted", false))
			and bool(authority.claim(
				1, 81, &"rack_test_engineer", &"crew_port_01", Authority.ROLE_ENGINEER, 1
			).get("accepted", false)),
		"the physical engineer seat and server-owned crew authority remain available"
	)
	_check(
		frame != null
			and frame.get_moving_frame() == craft
			and craft.get_in_flight_cabin_report().get("supported", false)
			and craft.get_halyard_audit_report().get("valid", false)
			and craft.get_meta("evidence_status", &"") == HalyardCrewTransport.EVIDENCE_STATUS,
		"moving-interior, cabin, silhouette allocation and evidence contracts remain valid"
	)

	var component := craft.get_component_damage()
	var damage := component.record_damage(12.0, Vector3.ZERO)
	_check(
		bool(damage.get("accepted", false))
			and _rack_geometry_hash(batch) == geometry_hash
			and craft.get_engineer_repair_state().get("status", &"") == &"idle",
		"component damage remains owner-controlled without mutating rack geometry or repair state"
	)
	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(
		bool(reset.get("accepted", false))
			and _rack_geometry_hash(batch) == geometry_hash
			and craft.find_children("*", "CollisionShape3D", true, false).size() == collision_count
			and craft.get_interior_access_marker().transform.is_equal_approx(access_transform)
			and craft.get_interior_deck_marker().transform.is_equal_approx(deck_transform)
			and _seat_transforms_match(craft.get_crew_seat_anchors(), seat_transforms)
			and craft.get_engineer_repair_state().get("status", &"") == &"idle",
		"reset-for-reuse preserves boarding, collision, seats, repair state and batched geometry"
	)

	print(
		"HALYARD_AFT_RACK_PANEL_BATCH_METRICS: renderers=274->269 submissions=274->269 "
		+ "authored_copies=339->339 geometry_sha256=%s->%s visual_review=NOT_RUN"
		% [GEOMETRY_SHA256, geometry_hash]
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
		var batch := raw_batch as MultiMeshInstance3D
		copies += batch.multimesh.instance_count if batch.multimesh != null else 0
		submissions += batch.multimesh.mesh.get_surface_count() \
			if batch.multimesh != null and batch.multimesh.mesh != null else 0
	return {
		"renderers": meshes.size() + batches.size(),
		"mesh_instances": meshes.size(),
		"multimesh_batches": batches.size(),
		"authored_copies": copies,
		"geometry_submissions": submissions,
	}


func _rack_geometry_hash(batch: MultiMeshInstance3D) -> String:
	if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
		return ""
	var names := batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray
	var transforms := batch.get_meta("authored_instance_transforms", []) as Array
	var material := batch.material_override as StandardMaterial3D
	if names.size() != HalyardCrewTransport.AFT_RACK_PANEL_COPY_COUNT \
			or transforms.size() != names.size() or material == null:
		return ""
	var mesh_bounds := batch.multimesh.mesh.get_aabb()
	var canonical := ""
	for index in names.size():
		var transform := transforms[index] as Transform3D
		canonical += "%s|%.6f,%.6f,%.6f|%.6f,%.6f,%.6f|%s|%.6f|%.6f\n" % [
			names[index],
			transform.origin.x, transform.origin.y, transform.origin.z,
			mesh_bounds.size.x, mesh_bounds.size.y, mesh_bounds.size.z,
			material.albedo_color.to_html(), material.metallic, material.roughness,
		]
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(canonical.to_utf8_buffer())
	return hashing.finish().hex_encode()


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
		print("HALYARD_AFT_RACK_PANEL_BATCH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		quit(1)
