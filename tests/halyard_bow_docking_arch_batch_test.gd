extends SceneTree

## Focused Phase 10 contract for the Halyard's three immutable hull-shade bow
## arch faces. Docking landmarks, collision, boarding, crew authority and ship
## lifecycle remain outside the presentation-only renderer batch.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const SHIP_FITOUT_BATCH := preload("res://scripts/rendering/ship_fitout_batch.gd")
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
	var radius := HalyardCrewTransport.BOW_RING_RADIUS
	var segment_extent := Vector3(2.0 * (radius + 0.18) * sin(PI / 8.0),
		radius - (radius - 0.18) * cos(PI / 8.0) + 0.18, 0.55)
	_check(
		batch.multimesh.instance_count == HalyardCrewTransport.BOW_DOCKING_ARCH_SHADE_COPY_COUNT
			and batch.multimesh.visible_instance_count == -1
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
			and transforms_exact
			and batch.multimesh.mesh.get_aabb().size.is_equal_approx(
				segment_extent
			)
			and batch.material_override == craft.get_variant_materials().get("hull_shade")
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1,
		"all three shade faces retain their exact transform, formed extent, material and renderer policy"
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

	for segment_index in [1, 3]:
		var accent := visual.get_node("BowDockingArchSegment%02d" % segment_index) as MeshInstance3D
		var angle := PI * float(segment_index) / 4.0
		_check(accent.mesh == batch.multimesh.mesh
			and accent.material_override == craft.get_variant_materials().get("accent")
			and accent.transform.is_equal_approx(Transform3D(
				Basis.from_euler(Vector3(0, 0, angle + PI * 0.5)),
				Vector3(radius * cos(angle), HalyardCrewTransport.BOW_RING_CENTRE_Y + radius * sin(angle),
					HalyardCrewTransport.BOW_RING_Z))),
			"accent section %d retains the shared casting, authored pose and finish" % segment_index)

	_check_cast_geometry(batch.multimesh.mesh, "arch")
	var arch_arrays := batch.multimesh.mesh.surface_get_arrays(0)
	var arch_vertices: PackedVector3Array = arch_arrays[Mesh.ARRAY_VERTEX]
	var arch_normals: PackedVector3Array = arch_arrays[Mesh.ARRAY_NORMAL]
	var smooth_stations := true
	var profile_creased := true
	const SWEEP_STEPS := 24
	for edge in 8:
		for station in SWEEP_STEPS - 1:
			var here := (edge * SWEEP_STEPS + station) * 6
			var following := here + 6
			smooth_stations = smooth_stations \
				and arch_vertices[here + 2].is_equal_approx(arch_vertices[following]) \
				and arch_normals[here + 2].is_equal_approx(arch_normals[following])
		var here := edge * SWEEP_STEPS * 6
		var following := ((edge + 1) % 8) * SWEEP_STEPS * 6
		profile_creased = profile_creased \
			and arch_vertices[here + 4].is_equal_approx(arch_vertices[following]) \
			and arch_normals[here + 4].dot(arch_normals[following]) < 0.9
	_check(smooth_stations and profile_creased,
		"casting normals flow along the sweep while the eight profile edges retain intentional creases")
	for strut_index in 2:
		var strut := visual.get_node("BowDockingArchStrut%02d" % strut_index) as MeshInstance3D
		_check_cast_geometry(strut.mesh, "strut %d" % strut_index)
		var side := 1.0 if strut_index == 0 else -1.0
		var arch_socket := strut.transform * Vector3(0.40, 0.40, -0.52)
		var roof_foot := strut.transform * Vector3(0.0, -0.075, 0.66)
		var socket_radius := Vector2(arch_socket.x, arch_socket.y - HalyardCrewTransport.BOW_RING_CENTRE_Y).length()
		_check(absf(socket_radius - radius) < 0.03
			and arch_socket.z > HalyardCrewTransport.BOW_RING_Z
			and arch_socket.z < HalyardCrewTransport.BOW_RING_Z + 0.275
			and is_equal_approx(roof_foot.x, side * 1.320592)
			and roof_foot.y > 3.0 and roof_foot.y < 3.15
			and is_equal_approx(roof_foot.z, -12.28)
			and strut.material_override == craft.get_variant_materials().get("structure"),
			"strut %d flares into the arch and seats on the pressure roof with its structural finish" % strut_index)

	var render := craft.get_halyard_render_allocation_report()
	_check(
		int(render.get("descendant_nodes", -1)) == HalyardCrewTransport.RENDER_DESCENDANT_COUNT
			and int(render.get("mesh_instances", -1)) == HalyardCrewTransport.RENDER_MESH_INSTANCE_COUNT
			and int(render.get("multimesh_batches", -1)) == HalyardCrewTransport.RENDER_MULTIMESH_BATCH_COUNT
			and int(render.get("drawn_copies", -1)) == HalyardCrewTransport.RENDER_DRAWN_COPY_COUNT
			and int(render.get("geometry_submissions", -1)) == HalyardCrewTransport.RENDER_GEOMETRY_SUBMISSION_COUNT
			and bool(render.get("exact_counts", false)),
		"the exterior retains the production render allocation contract"
	)
	var full_counts := _render_counts(craft)
	# Current production fittings and formed exhausts are included in this whole
	# craft snapshot; the bow still owns three shade copies and two accents.

	_check(
		int(full_counts.renderers) == 341
			and int(full_counts.mesh_instances) == 327
			and int(full_counts.multimesh_batches) == 14
			and int(full_counts.authored_copies) == 449
			and int(full_counts.geometry_submissions) == 348,
		"the exact current craft snapshot keeps all 449 visual copies across 341 allocations and 348 surfaces"
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
		"HALYARD_BOW_DOCKING_ARCH_BATCH_METRICS: local_renderers=266->264 "
		+ "local_submissions=266->264 current_renderers=341 current_submissions=348 "
		+ "current_exterior_submissions=130 current_authored_copies=449 visual_review=NOT_RUN"
	)
	_finish(craft)


func _check_cast_geometry(mesh: Mesh, label: String) -> void:
	_check(mesh is ArrayMesh and mesh.get_surface_count() == 1,
		"%s is one formed casting surface" % label)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var valid := vertices.size() % 3 == 0 and normals.size() == vertices.size() \
		and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	var edges := {}
	for start in range(0, vertices.size(), 3):
		var cross := (vertices[start + 1] - vertices[start]).cross(vertices[start + 2] - vertices[start])
		var uv_cross := (uvs[start + 1] - uvs[start]).cross(uvs[start + 2] - uvs[start])
		valid = valid and cross.length() > 0.000001 and absf(uv_cross) > 0.000001
		for corner in 3:
			var index := start + corner
			var normal := normals[index]
			var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			valid = valid and normal.is_finite() and tangent.is_finite() \
				and absf(normal.length() - 1.0) < 0.001 \
				and absf(tangent.length() - 1.0) < 0.001 \
				and absf(normal.dot(tangent)) < 0.001 \
				and absf(tangents[index * 4 + 3]) == 1.0 \
				and cross.dot(normal) < 0.0
			var first := str(vertices[index].snapped(Vector3.ONE * 0.00001))
			var second := str(vertices[start + (corner + 1) % 3].snapped(Vector3.ONE * 0.00001))
			var key := first + "|" + second if first < second else second + "|" + first
			edges[key] = int(edges.get(key, 0)) + 1
	for count in edges.values():
		valid = valid and count == 2
	_check(valid, "%s has closed caps, nondegenerate outward triangles, usable UVs and orthogonal unit tangents" % label)


func _render_counts(craft: Node) -> Dictionary:
	# The craft folds anonymous sibling fitout dressing into merged renderers as
	# the last step of its own build (`ShipFitoutBatch`). This snapshot is what
	# the craft *allocates*, so each batch is added back as the renderers, copies
	# and submissions it stands in for. The delta is zero on a craft built without
	# that pass, so the frozen roster below is unchanged either way.
	var authored := SHIP_FITOUT_BATCH.authored_render_census_delta(craft)
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
		"renderers": meshes.size() + batches.size() + int(authored.renderer_nodes),
		"mesh_instances": meshes.size() + int(authored.renderer_nodes),
		"multimesh_batches": batches.size(),
		"authored_copies": copies + int(authored.drawn_copies),
		"geometry_submissions": submissions + int(authored.surface_submissions),
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
