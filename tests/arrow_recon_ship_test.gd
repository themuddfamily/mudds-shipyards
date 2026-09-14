extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const SHIP_LAYER := PhysicsLayers.SHIP

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "ArrowReconShipTestRoot"
	root.add_child(_test_root)
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	_check(arrow != null, "Arrow scene instantiates as ArrowReconShip")
	if arrow == null:
		_finish()
		return
	_test_root.add_child(arrow)
	await process_frame
	await physics_frame
	await physics_frame

	_test_definition_and_evidence(arrow)
	_test_distinct_presentation(arrow)
	_test_recon_pulse_emitter_assemblies(arrow)
	await _test_entry_heat_attachment(arrow)
	_test_airframe_shadow_batch(arrow)
	_test_visual_performance_batch(arrow)
	_test_engine_collar_mesh_sharing(arrow)
	_test_refractory_nozzle_stock(arrow)
	_test_main_gear_foot_mesh_sharing(arrow)
	_test_pod_separation_collar_mesh_sharing(arrow)
	await _test_supported_boarding_access(arrow)
	_test_escape_pods_and_sensors(arrow)
	_test_wingtip_sensor_housings(arrow)
	_test_formed_raceways(arrow)
	_test_instrument_construction(arrow)
	_test_formed_coaming(arrow)
	_test_cockpit_fairing(arrow)
	_test_shared_seat_cushions(arrow)
	_test_arrow_cabin_opening(arrow)
	_test_fitted_canopy(arrow)
	_test_collision_boarding_and_cameras(arrow)
	await _test_engine_weapon_and_lifecycle(arrow)
	await _test_cleanup(arrow)
	_finish()


func _test_formed_raceways(arrow: ArrowReconShip) -> void:
	var resources: Dictionary = {}
	var covers := 0
	var closed := true
	var fitted := true
	var frames_valid := true
	for route in arrow.get_arrow_visual_root().get_children():
		var cover := route.get_node_or_null("CableRaceway0") as MeshInstance3D
		if cover == null:
			continue
		covers += 1
		resources[cover.mesh] = true
		closed = closed and cover.basis.determinant() > 0.999 and cover.mesh is ArrayMesh and cover.mesh.get_surface_count() == 1 and not route.has_node("CableRaceway1")
		var faces := cover.mesh.get_faces()
		var edges: Dictionary = {}
		for triangle in range(0, faces.size(), 3):
			for edge in 3:
				var a := str(faces[triangle + edge].snapped(Vector3.ONE * 0.00001))
				var b := str(faces[triangle + (edge + 1) % 3].snapped(Vector3.ONE * 0.00001))
				var key := a + ":" + b if a < b else b + ":" + a
				edges[key] = int(edges.get(key, 0)) + 1
		for count in edges.values():
			closed = closed and count == 2
		var joints: Array[Vector3] = []
		for child in route.get_children():
			if child is MeshInstance3D and child.mesh is SphereMesh:
				joints.append(child.position)
		# A ray from the retained elbow must exit one enclosing wall. Separate
		# capped bars leave this anchor exposed and cannot satisfy this check.
		var origin := cover.transform.affine_inverse() * joints[1]
		var hits := 0
		for triangle in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(origin, origin + Vector3(0.039, 0.27, 0.06), faces[triangle], faces[triangle + 1], faces[triangle + 2]) != null:
				hits += 1
		fitted = fitted and hits == 1 and cover.mesh.surface_get_material(0) == arrow.get_variant_materials().graphite
		var arrays := cover.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		frames_valid = frames_valid and normals.size() == vertices.size() and tangents.size() == vertices.size() * 4
		for index in vertices.size():
			var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			frames_valid = frames_valid and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001 and tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001 and absf(tangent.dot(normals[index])) < 0.001
	_check(covers == 5 and resources.size() == 3, "five continuous raceway covers share mirrored stock in three meshes and halve the former casing surfaces")
	_check(closed and fitted, "raceway casings are closed around retained elbow anchors with fitted returns and the existing graphite finish")
	_check(frames_valid, "formed raceways retain finite unit normals and nonsingular tangent frames")


func _test_wingtip_sensor_housings(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var pods := 0
	var attached := true
	var geometry_valid := true
	var fitted := true
	for child in visual.get_children():
		if not child is MeshInstance3D or not child.has_node("ForwardOpticalWindow"):
			continue
		pods += 1
		var pod := child as MeshInstance3D
		var side := signf(pod.position.x)
		var wing := visual.get_node("PortSensorWing" if side < 0.0 else "StarboardSensorWing") as MeshInstance3D
		for point in [Vector2(5.24, 1.65), Vector2(5.38, 2.30), Vector2(5.58, 3.40)]:
			var sample := Vector2(side * point.x, point.y)
			var hull_span := _mesh_vertical_span(pod, sample, true)
			var wing_span := _mesh_vertical_span(wing, sample)
			attached = attached and hull_span.size() >= 2 and wing_span.size() >= 2
			if hull_span.size() >= 2 and wing_span.size() >= 2:
				attached = attached and hull_span[0] < wing_span[-1] and wing_span[0] < hull_span[-1]
		var aperture := pod.get_node("FlushPassiveAperture") as MeshInstance3D
		var optic := pod.get_node("ForwardOpticalWindow") as MeshInstance3D
		var recess := pod.get_node("OpticalRecess") as MeshInstance3D
		var optic_box := optic.transform * optic.mesh.get_aabb()
		fitted = fitted and is_equal_approx(aperture.mesh.get_aabb().position.z, -0.58) and is_equal_approx(aperture.mesh.get_aabb().end.z, 0.75)
		fitted = fitted and optic_box.position.z > pod.mesh.get_aabb().position.z and optic_box.end.z < recess.mesh.get_aabb().end.z
		# The shell really opens in front of the optic, and the dark well has
		# an actual back wall. Bounds alone cannot detect a hidden old cap.
		for stock: MeshInstance3D in [pod, recess, optic]:
			var hits := 0
			var relative := Transform3D.IDENTITY if stock == pod else stock.transform
			var faces := stock.mesh.get_faces()
			for triangle in range(0, faces.size(), 3):
				if Geometry3D.segment_intersects_triangle(Vector3(0.03, 0.02, -2), Vector3(0.03, 0.02, -1.70), relative * faces[triangle], relative * faces[triangle + 1], relative * faces[triangle + 2]) != null:
					hits += 1
			fitted = fitted and hits == (0 if stock == pod else (1 if stock == recess else 2))
		for stock: MeshInstance3D in [pod, aperture, recess, optic]:
			var arrays := stock.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			geometry_valid = geometry_valid and normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
			for index in vertices.size():
				geometry_valid = geometry_valid and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001 and uvs[index].is_finite()
			for index in range(0, tangents.size(), 4):
				var tangent := Vector3(tangents[index], tangents[index + 1], tangents[index + 2])
				geometry_valid = geometry_valid and tangent.is_finite() and absf(tangent.length() - 1.0) < 0.001 and absf(tangent.dot(normals[index / 4])) < 0.001 and absf(absf(tangents[index + 3]) - 1.0) < 0.001
			if indices.is_empty():
				for index in vertices.size(): indices.append(index)
			for triangle in range(0, indices.size(), 3):
				var a := indices[triangle]
				var b := indices[triangle + 1]
				var c := indices[triangle + 2]
				var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
				if stock == recess:
					var centre := (vertices[a] + vertices[b] + vertices[c]) / 3.0
					geometry_valid = geometry_valid and cross.dot(Vector3(0, 0, -1.90) - centre) < 0.0
				geometry_valid = geometry_valid and cross.dot(normals[a] + normals[b] + normals[c]) < 0.0 and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 0.000000001
	_check(pods == 2 and attached, "both formed sensor shoulders overlap the actual wing triangles along their complete junction")
	_check(pods == 2 and fitted, "both passive apertures fit their new equipment lands and both optical windows sit inside open front recesses")
	_check(pods == 2 and geometry_valid, "sensor skins, inset returns and optical wells retain outward winding, nonsingular UVs and finite unit tangent frames")


func _test_shared_seat_cushions(arrow: ArrowReconShip) -> void:
	var cockpit := arrow.get_arrow_visual_root().get_node("CockpitInterior") as Node3D
	var expected := {
		"SeatPan": AABB(Vector3(-0.37, -0.08, -0.41), Vector3(0.74, 0.19, 0.78)),
		"SeatBack": AABB(Vector3(-0.36, -0.06, -0.44), Vector3(0.72, 0.20, 0.87)),
		"Headrest": AABB(Vector3(-0.27, -0.07, -0.14), Vector3(0.54, 0.19, 0.28)),
	}
	for cushion_name in expected:
		var cushion := cockpit.get_node(NodePath(cushion_name)) as MeshInstance3D
		var mesh := cushion.mesh
		_check(mesh.get_aabb().is_equal_approx(expected[cushion_name]),
			"%s foam retains its occupied envelope" % cushion_name)
		_check(mesh.get_surface_count() == 1 and mesh.surface_get_material(0) == cushion.material_override,
			"%s keeps one renderer surface and its existing upholstery material" % cushion_name)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var front := mesh.get_aabb().position.z
		var front_vertices := PackedVector3Array()
		for vertex in vertices:
			if is_equal_approx(vertex.z, front):
				front_vertices.append(vertex)
		var closed_roll := not front_vertices.is_empty()
		for vertex in front_vertices:
			closed_roll = closed_roll and is_zero_approx(vertex.x)
		_check(closed_roll, "%s front foam rolls continuously into a closed tip" % cushion_name)
	_check(arrow.get_pilot_seat_anchor().position.is_equal_approx(Vector3(0.0, 1.56, -0.02)),
		"cushion refit keeps the physical seated feet frame")


func _test_supported_boarding_access(ship: ArrowReconShip) -> void:
	var visual := ship.get_arrow_visual_root()
	var access := visual.get_node("SupportedBoardingAccess")
	var upper := access.get_node("UpperLadderHinge") as Node3D
	var lower := upper.get_node("LowerLadderHinge") as Node3D
	var stock := (upper.get_node("LadderStock") as MeshInstance3D).mesh
	_check(visual.get_node_or_null("BoardingStep") == null and stock == (lower.get_node("LadderStock") as MeshInstance3D).mesh,
		"floating step batch is replaced by two folding flights sharing one immutable ladder stock")
	ship.set_canopy_open(true, 0.0)
	await process_frame
	_check(is_zero_approx(upper.rotation.x) and is_zero_approx(lower.rotation.x), "settled open canopy deploys both ladder sections")
	ship.set_canopy_open(false, 0.0)
	await process_frame
	_check(upper.rotation.x > PI and is_equal_approx(lower.rotation.x, PI), "closed canopy folds the ground ladder onto the wing")
	_check(stock == (upper.get_node("LadderStock") as MeshInstance3D).mesh, "folding retains shared stock without mesh allocation")
	ship.set_canopy_open(true, 0.0)
	await process_frame
	var prior_physics := ship.is_physics_processing()
	ship.set_physics_process(false)
	var geometry := Node3D.new()
	_test_root.add_child(geometry)
	var corridor := AABB(Vector3(-7, -1.4, -9), Vector3(14, 7, 17))
	var geometry_count := 0
	for node in ship.find_children("*", "GeometryInstance3D", true, false):
		if ship.get_entry_heat_target().is_ancestor_of(node):
			continue
		if not (node as GeometryInstance3D).is_visible_in_tree() or (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				geometry_count += _add_access_mesh_probe(geometry, ship, corridor, mesh_node.mesh, mesh_node.global_transform, StringName(str(ship.get_path_to(mesh_node)).replace("/", "__")))
		elif node is MultiMeshInstance3D:
			var batch := node as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.mesh == null: continue
			var count := batch.multimesh.instance_count if batch.multimesh.visible_instance_count < 0 else batch.multimesh.visible_instance_count
			for index in count:
				geometry_count += _add_access_mesh_probe(geometry, ship, corridor, batch.multimesh.mesh,
					batch.global_transform * batch.multimesh.get_instance_transform(index), batch.name)
	_check(geometry_count > 50, "access sweep includes emitted hull, wings, ladder, canopy and cockpit fittings")
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	player.set_physics_process(false)
	player.global_position = ship.get_boarding_position()
	var skeleton := player.get_pilot_visual_root().find_child("*Skeleton*", true, false) as Skeleton3D
	var capsule_query := PhysicsShapeQueryParameters3D.new()
	capsule_query.shape = (player.get_node("PlayerCollision") as CollisionShape3D).shape
	capsule_query.collision_mask = 1 << 25
	capsule_query.margin = 0.005
	var body_query := PhysicsShapeQueryParameters3D.new()
	var body_sphere := SphereShape3D.new()
	body_sphere.radius = 0.20
	body_query.shape = body_sphere
	body_query.collision_mask = 1 << 25
	body_query.margin = 0.003
	await physics_frame
	await physics_frame
	var accepted := player.begin_boarding(ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(),
		2.0, ship, ship.get_exterior_boarding_waypoints())
	var board_sweep := _sample_access_motion(ship, player, skeleton, capsule_query, body_query, PlayerController.EmbodimentState.BOARDING)
	_check(accepted and player.is_seated() and board_sweep.frames >= 120 and board_sweep.hits.is_empty(),
		"boarding clears actual geometry with standing capsule and animated chest/head through seat settling: %s" % board_sweep)
	accepted = player.begin_disembark(ship.get_exit_transform(), 2.0, ship, ship.get_exterior_exit_waypoints())
	var exit_sweep := _sample_access_motion(ship, player, skeleton, capsule_query, body_query, PlayerController.EmbodimentState.DISEMBARKING)
	_check(accepted and not player.is_seated() and exit_sweep.frames >= 120 and exit_sweep.hits.is_empty(),
		"reverse access clears actual geometry with standing capsule and animated chest/head: %s" % exit_sweep)
	for start in [Vector3(-6.4,-1.09,0),Vector3(6.4,-1.09,0),Vector3(0,-1.09,-8.4),Vector3(0,-1.09,8)]:
		player.force_recovery_to_on_foot(ship.global_transform * Transform3D(Basis.IDENTITY, start))
		player.begin_boarding(ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 2.0, ship,
			ship.get_exterior_boarding_waypoints(player.global_position))
		var sweep := _sample_access_motion(ship, player, skeleton, capsule_query, body_query, PlayerController.EmbodimentState.BOARDING)
		_check(sweep.hits.is_empty(), "flank/nose/tail approach skirts actual hull before climbing: %s %s" % [start, sweep])
	geometry.queue_free()
	player.queue_free()
	ship.set_canopy_open(false, 0.0)
	ship.set_physics_process(prior_physics)
	await process_frame
	await physics_frame


func _test_engine_collar_mesh_sharing(arrow: ArrowReconShip) -> void:
	var report := arrow.get_arrow_visual_performance_report()
	var sharing := report.engine_collar_mesh_sharing as Dictionary
	var visual := arrow.get_arrow_visual_root()
	var paths := sharing.node_paths as PackedStringArray
	var port := visual.get_node_or_null(NodePath(paths[0])) as MeshInstance3D \
		if paths.size() == 2 else null
	var starboard := visual.get_node_or_null(NodePath(paths[1])) as MeshInstance3D \
		if paths.size() == 2 else null
	_check(
		bool(sharing.valid)
		and int(sharing.geometry_nodes) == 2
		and int(sharing.geometry_submissions) == 2
		and int(sharing.visible_geometry_copies) == 2
		and int(sharing.primitive_mesh_allocations) == 1
		and int(sharing.resource_allocation_reduction) == 1,
		"engine collars retain their local 2->1 TorusMesh allocation reduction without changing nodes, submissions, or copies"
	)
	_check(
		port != null and starboard != null and port.mesh == starboard.mesh
		and port.transform.is_equal_approx((sharing.authored_transforms as Array)[0])
		and starboard.transform.is_equal_approx((sharing.authored_transforms as Array)[1])
		and port.get_child_count() == 0 and starboard.get_child_count() == 0
		and port.find_children("*", "CollisionObject3D", true, false).is_empty()
		and starboard.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"both ordinary collar paths retain exact transforms, visible renderers, and zero collision or gameplay authority"
	)
	if port != null and starboard != null:
		var shared_mesh := port.mesh
		starboard.mesh = shared_mesh.duplicate(false)
		_check(
			not bool(arrow.get_arrow_visual_performance_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"engine-collar shared-mesh identity drift"
			),
			"structured-red: a private replacement collar mesh fails the production allocation audit"
		)
		starboard.mesh = shared_mesh
		_check(
			bool(arrow.get_arrow_visual_performance_report().valid),
			"restoring the shared immutable collar mesh restores the Arrow audit"
		)


func _test_refractory_nozzle_stock(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var port := visual.get_node("PortRefractoryNozzle") as MeshInstance3D
	var starboard := visual.get_node("StarboardRefractoryNozzle") as MeshInstance3D
	_check(port.mesh == starboard.mesh and port.mesh is ArrayMesh and port.mesh.get_surface_count() == 1,
		"both refractory nozzles share one formed stock without adding renderers or surfaces")
	var arrays := port.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var valid := normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	for i in vertices.size():
		valid = valid and vertices[i].is_finite() and normals[i].is_finite() and is_equal_approx(normals[i].length(), 1.0)
	for i in range(0, vertices.size(), 3):
		valid = valid and absf((uvs[i + 1] - uvs[i]).cross(uvs[i + 2] - uvs[i])) > 1e-10
	_check(valid, "curved petal faces and closed side returns retain complete normals, UVs and tangent frames")
	var faces := port.mesh.get_faces()
	var first_hit := -INF
	for i in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(0, 0, 1.2), Vector3.FORWARD, faces[i], faces[i + 1], faces[i + 2])
		if hit is Vector3:
			first_hit = maxf(first_hit, hit.z)
	_check(is_equal_approx(first_hit, 0.055), "the dark backing sits deeply behind the open nozzle mouth")


func _test_main_gear_foot_mesh_sharing(arrow: ArrowReconShip) -> void:
	var report := arrow.get_arrow_visual_performance_report()
	var sharing := report.main_gear_foot_mesh_sharing as Dictionary
	var visual := arrow.get_arrow_visual_root()
	var paths := sharing.node_paths as PackedStringArray
	var port := visual.get_node_or_null(NodePath(paths[0])) as MeshInstance3D \
		if paths.size() == 2 else null
	var starboard := visual.get_node_or_null(NodePath(paths[1])) as MeshInstance3D \
		if paths.size() == 2 else null
	_check(
		bool(sharing.valid)
		and sharing.legacy == {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
		}
		and int(sharing.geometry_nodes) == 2
		and int(sharing.geometry_submissions) == 2
		and int(sharing.visible_geometry_copies) == 2
		and int(sharing.primitive_mesh_allocations) == 1
		and int(sharing.resource_allocation_reduction) == 1,
		"main-gear shoes share immutable formed stock without adding renderers or submissions"
	)
	_check(
		port != null and starboard != null and port.mesh == starboard.mesh
		and port.mesh is ArrayMesh
		and port.mesh.surface_get_material(0) == arrow.get_variant_materials().titanium
		and port.transform.is_equal_approx((sharing.authored_transforms as Array)[0])
		and starboard.transform.is_equal_approx((sharing.authored_transforms as Array)[1])
		and port.get_child_count() == 0 and starboard.get_child_count() == 0
		and port.find_children("*", "CollisionObject3D", true, false).is_empty()
		and starboard.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"both main shoes preserve shared titanium stock, renderer state, and zero collision authority"
	)
	var supports: Array[MeshInstance3D] = []
	for child in visual.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh:
			var bounds: AABB = (child as MeshInstance3D).mesh.get_aabb()
			if is_equal_approx(child.position.y, ArrowReconShip.LANDING_SOLE_Y) and is_zero_approx(bounds.position.y):
				supports.append(child)
	var all_contact := supports.size() == 3
	var all_clear := supports.size() == 3
	var all_mounted := supports.size() == 3
	var main_support_meshes := {}
	for support in supports:
		var is_nose := support.name == &"NoseGearStrut"
		var sole_vertices := 0
		for vertex in support.mesh.get_faces():
			var placed: Vector3 = support.transform * vertex
			all_contact = all_contact and placed.y >= -1.17001
			if is_equal_approx(placed.y, -1.17):
				sole_vertices += 1

		all_contact = all_contact and sole_vertices >= 8
		if not is_nose:
			main_support_meshes[support.mesh.get_instance_id()] = true
		var mount := support.transform * Vector3(0.0 if is_nose else -0.28, 1.65 if is_nose else 2.03, -0.12)
		var connected := false
		for shell: MeshInstance3D in arrow.get("_airframe_shadow_sources"):
			var inverse := shell.global_transform.affine_inverse() * visual.global_transform
			var from: Vector3 = inverse * (mount - Vector3.UP * 0.65)
			var to: Vector3 = inverse * (mount + Vector3.UP * 0.08)
			var faces := shell.mesh.get_faces()
			for index in range(0, faces.size(), 3):
				if Geometry3D.segment_intersects_triangle(from, to, faces[index], faces[index + 1], faces[index + 2]) != null:
					connected = true
					break
			if connected: break
		all_mounted = all_mounted and connected
	var winding_ok := true
	for child in visual.get_children():
		if not child is MeshInstance3D or not is_equal_approx(child.position.y, ArrowReconShip.LANDING_SOLE_Y):
			continue
		var gear := child as MeshInstance3D
		var arrays := gear.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			winding_ok = winding_ok and (b - a).cross(c - a).dot(normals[indices[i]]) < -0.0000001
		for vertex in vertices:
			if vertex.y < 0.24:
				var placed: Vector3 = gear.transform * vertex
				var radial := Vector2(placed.x, placed.z).length()
				all_clear = all_clear and (radial > 3.34 and radial < 4.45 if gear.name in [&"NoseGearStrut", &"NoseGearFoot"] else radial < 3.15)
	_check(winding_ok, "formed shoes and merged stock retain outward normals and front-face winding")

	_check(all_contact, "all three formed soles provide flat support at the actual dock deck plane, local y=-1.17")
	_check(all_clear, "emitted low shoe geometry clears the raised inner and outer berth rings")
	_check(all_mounted, "all three strut saddles connect through the actual rendered airframe underside")
	_check(main_support_meshes.size() == 1, "both main dark soles and connected supports share one immutable mesh")

	if port != null and starboard != null:
		var shared_mesh := port.mesh
		starboard.mesh = shared_mesh.duplicate(false)
		_check(
			not bool(arrow.get_arrow_visual_performance_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"main-gear-foot shared-mesh identity drift"
			),
			"structured-red: a private replacement main-gear-foot mesh fails the production allocation audit"
		)
		starboard.mesh = shared_mesh
		_check(
			bool(arrow.get_arrow_visual_performance_report().valid),
			"restoring the shared immutable main-gear-foot mesh restores the Arrow audit"
		)


func _test_pod_separation_collar_mesh_sharing(arrow: ArrowReconShip) -> void:
	var report := arrow.get_arrow_visual_performance_report()
	var sharing := report.pod_separation_collar_mesh_sharing as Dictionary
	var visual := arrow.get_arrow_visual_root()
	var paths := sharing.node_paths as PackedStringArray
	var port := visual.get_node_or_null(NodePath(paths[0])) as MeshInstance3D \
		if paths.size() == 2 else null
	var starboard := visual.get_node_or_null(NodePath(paths[1])) as MeshInstance3D \
		if paths.size() == 2 else null
	_check(
		bool(sharing.valid)
		and sharing.legacy == {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
		}
		and int(sharing.geometry_nodes) == 2
		and int(sharing.geometry_submissions) == 2
		and int(sharing.visible_geometry_copies) == 2
		and int(sharing.primitive_mesh_allocations) == 1
		and int(sharing.resource_allocation_reduction) == 1
		and paths == PackedStringArray([
			"PortEscapePod/PodSeparationCollar",
			"StarboardEscapePod/PodSeparationCollar",
		]),
		"escape-pod collars reduce immutable TorusMesh allocations 2->1 while retaining both named pod renderers and submissions"
	)
	_check(
		port != null and starboard != null and port.mesh == starboard.mesh
		and port.mesh is TorusMesh
		and is_equal_approx(
			(port.mesh as TorusMesh).inner_radius,
			ArrowReconShip.POD_SEPARATION_COLLAR_INNER_RADIUS
		)
		and is_equal_approx(
			(port.mesh as TorusMesh).outer_radius,
			ArrowReconShip.POD_SEPARATION_COLLAR_OUTER_RADIUS
		)
		and (port.mesh as TorusMesh).material == arrow.get_variant_materials().graphite
		and port.transform.is_equal_approx(sharing.authored_local_transform)
		and starboard.transform.is_equal_approx(sharing.authored_local_transform)
		and port.get_parent() == arrow.get_escape_pod(&"port")
		and starboard.get_parent() == arrow.get_escape_pod(&"starboard")
		and port.get_child_count() == 0 and starboard.get_child_count() == 0
		and port.find_children("*", "CollisionObject3D", true, false).is_empty()
		and starboard.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"both pod-local collars preserve exact graphite geometry, transforms, parent identity, and zero gameplay authority"
	)
	if port != null and starboard != null:
		var shared_mesh := port.mesh
		starboard.mesh = shared_mesh.duplicate(false)
		_check(
			not bool(arrow.get_arrow_visual_performance_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"pod-separation-collar shared-mesh identity drift"
			),
			"structured-red: a private pod-collar mesh fails the allocation audit"
		)
		starboard.mesh = shared_mesh
		_check(
			bool(arrow.get_arrow_visual_performance_report().valid),
			"restoring the shared pod-collar mesh restores the Arrow audit"
		)


func _test_definition_and_evidence(arrow: ArrowReconShip) -> void:
	var definition := arrow.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Arrow owns a valid ShipDefinition resource")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"arrow_provisional", "definition exposes a stable Arrow candidate ID")
	_check(definition.get_display_name() == "Arrow-class Recon Ship candidate", "definition labels the craft as a candidate")
	_check(definition.get_role() == "Reconnaissance ship", "creator-supported reconnaissance role is preserved")
	_check(definition.get_evidence_status_id() == &"provisional", "definition explicitly rejects authenticated status")
	_check(not definition.is_authenticated() and definition.is_historical_claim(), "Arrow is a sourced but unauthenticated historical claim")
	_check(definition.evidence_references.size() >= 3, "definition cites creator roster, research register, and label footage")
	_check("two escape pods" in definition.evidence_notes, "definition records the supported pod-count fact")
	_check("silhouette" in definition.evidence_notes and "provisional" in definition.evidence_notes, "definition limits all shape claims")
	_check(definition.audio_profile_id == &"efficient_twin_recon", "definition exposes a distinct future audio profile")
	_check(definition.compatibility_tags.has("recon") and definition.compatibility_tags.has("small_craft"), "definition declares recon berth compatibility")

	var definition_audit := definition.get_audit_report()
	_check(bool(definition_audit.valid), "definition audit validates")
	_check(str(definition_audit.evidence_status) == "provisional", "definition audit preserves provisional status")
	var evidence := arrow.get_arrow_evidence_report()
	_check(str(evidence.evidence_scope) == "name_role_pod_count_only", "craft audit narrowly scopes supported evidence")
	_check(not bool(evidence.authenticated_geometry), "craft audit denies authenticated geometry")
	_check((evidence.creator_supported as PackedStringArray).size() == 3, "craft audit lists exactly the three supported fact categories")
	_check((evidence.modern_provisional as PackedStringArray).size() >= 5, "craft audit inventories provisional design categories")
	var audit := arrow.get_arrow_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "fully constructed Arrow passes its public audit")
	_check(int(audit.escape_pod_count) == 2 and int(audit.engine_count) == 2, "audit exposes two pods and twin engines")
	_check(str(audit.weapon_class) == "light_recon_pulse", "audit labels the deliberately lighter weapon class")
	_check(bool(arrow.get_meta("arrow_recon_candidate", false)), "root metadata identifies an Arrow candidate")
	_check(not bool(arrow.get_meta("authenticated_historical_silhouette", true)), "root metadata cannot imply historical silhouette authentication")


func _test_distinct_presentation(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	_check(visual != null and visual.name == "ArrowReconVisual", "variant replaces the Torrent exterior with a dedicated visual root")
	_check(arrow.get_node_or_null("TorrentVisual") == null, "no inherited Torrent visual hierarchy remains")
	_check(str(visual.get_meta("geometry_status", "")) == "provisional", "visual hierarchy carries provisional geometry metadata")
	_check(not bool(visual.get_meta("authenticated_historical_silhouette", true)), "visual hierarchy denies an authenticated silhouette")
	_check(visual.get_node_or_null("ReconFuselage") is MeshInstance3D, "slender recon fuselage is a real procedural mesh")
	_check(visual.get_node_or_null("PortSensorWing") is MeshInstance3D, "port sensor wing is a smooth authored planform mesh")
	_check(visual.get_node_or_null("StarboardSensorWing") is MeshInstance3D, "starboard sensor wing is a smooth authored planform mesh")
	_check(visual.get_node_or_null("DorsalSurveySpine") is MeshInstance3D, "dorsal survey spine is a curved loft")


func _test_recon_pulse_emitter_assemblies(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var report := arrow.get_arrow_visual_performance_report().recon_pulse_emitters as Dictionary
	_check(
		bool(report.valid)
		and Array(report.assembly_roster) == [
			"PortReconPulseEmitter", "StarboardReconPulseEmitter",
		]
		and report.component_roster == [
			"RecessedGraphiteMount", "CompactGraphiteShroud",
			"LightPulseBarrel", "CyanMuzzleLens",
		]
		and int(report.assembly_nodes) == 2
		and int(report.renderer_nodes) == 8
		and int(report.unique_mesh_resource_allocations) == 4,
		"Arrow exposes an exact mirrored two-by-four light recon pulse-emitter roster sharing four meshes"
	)
	var muzzle_names := PackedStringArray(["LeftMuzzle", "RightMuzzle"])
	for index in ArrowReconShip.RECON_PULSE_EMITTER_NAMES.size():
		var emitter := visual.get_node_or_null(
			ArrowReconShip.RECON_PULSE_EMITTER_NAMES[index]
		) as Node3D
		var muzzle := arrow.get_node_or_null(muzzle_names[index]) as Marker3D
		_check(
			emitter != null and muzzle != null
			and emitter.position == ArrowReconShip.RECON_PULSE_EMITTER_POSITIONS[index]
			and emitter.position == muzzle.position
			and emitter.rotation == Vector3.ZERO
			and emitter.scale == Vector3.ONE,
			"%s is exactly aligned to its unchanged gameplay muzzle transform" % ArrowReconShip.RECON_PULSE_EMITTER_NAMES[index]
		)
		if emitter == null:
			continue
		_check(
			emitter.get_meta("presentation_status", &"") == &"modern_provisional"
			and emitter.get_meta("geometry_status", &"") == &"provisional"
			and not bool(emitter.get_meta("authenticated_historical_weapon", true))
			and bool(emitter.get_meta("visual_only", false))
			and not bool(emitter.get_meta("gameplay_authority", true))
			and emitter.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"%s is explicitly modern/provisional visual presentation with no gameplay or collision authority" % emitter.name
		)
		var mount := emitter.get_node_or_null("RecessedGraphiteMount") as MeshInstance3D
		var shroud := emitter.get_node_or_null("CompactGraphiteShroud") as MeshInstance3D
		var barrel := emitter.get_node_or_null("LightPulseBarrel") as MeshInstance3D
		var lens := emitter.get_node_or_null("CyanMuzzleLens") as MeshInstance3D
		_check(
			mount != null and mount.mesh is BoxMesh
			and (mount.mesh as BoxMesh).size == Vector3(0.38, 0.22, 0.62)
			and shroud != null and shroud.mesh is TorusMesh
			and is_equal_approx((shroud.mesh as TorusMesh).outer_radius, 0.155),
			"%s uses a compact recessed mount and shroud envelope" % emitter.name
		)
		_check(
			barrel != null and barrel.mesh != null
			and is_equal_approx(float(report.barrel_radius), 0.09)
			and is_equal_approx(barrel.mesh.get_aabb().size.x, 0.18)
			and is_equal_approx(barrel.mesh.get_aabb().size.y, 0.4)
			and float(report.barrel_radius) < 0.13
			and float(report.barrel_radius) < 0.19,
			"%s freezes a 0.09m barrel, visibly smaller than the Torrent 0.13m and Jovian 0.19m barrels" % emitter.name
		)
		_check(
			lens != null and lens.position == Vector3.ZERO
			and lens.mesh != null
			and is_equal_approx(lens.mesh.get_aabb().size.x, 0.15)
			and lens.mesh.surface_get_material(0) == arrow.get_variant_materials().sensor
			and muzzle != null
			and lens.global_position.is_equal_approx(muzzle.global_position),
			"%s terminates in a compact cyan lens centred on the gameplay muzzle" % emitter.name
		)
	_check(
		visual.get_node_or_null("VentralSensorGimbal") is MeshInstance3D
		and visual.get_node_or_null("VentralSensorLens") is MeshInstance3D
		and visual.get_node("VentralSensorGimbal").get_parent() == visual,
		"the separate ventral optical/spectral sensor remains intact and is not repurposed as a weapon"
	)


func _test_entry_heat_attachment(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var target := arrow.get_entry_heat_target()
	_check(
		target != null
		and target.name == "PlanetaryEntryHeatTarget"
		and target.get_parent() == visual
		and not target.top_level,
		"Arrow exposes exactly one typed entry-heat target as a direct non-top-level child of its final visual root"
	)
	_check(
		target != null
		and target.position == Vector3(0.0, 1.4, -0.15)
		and target.rotation == Vector3.ZERO
		and target.scale == Vector3(1.45, 1.4, 1.08),
		"Arrow entry-heat target freezes the exact authored ship-local fit"
	)
	var attachment := arrow.get_arrow_audit_report().entry_heat_attachment as Dictionary
	_check(
		bool(attachment.valid)
		and (attachment.authored_local_bounds as AABB).is_equal_approx(AABB(
			Vector3(-5.8, -1.4, -7.71), Vector3(11.6, 5.6, 15.12)
		))
		and (attachment.expanded_local_bounds as AABB).is_equal_approx(AABB(
			Vector3(-6.1625, -1.75, -7.98), Vector3(12.325, 6.3, 15.66)
		)),
		"attachment audit freezes the authored and 0.25m-standoff Arrow-local bounds"
	)
	_check(
		int(attachment.target_subtree_nodes) == 4
		and int(attachment.renderer_nodes) == 2
		and int(attachment.surface_count) == 2
		and int(attachment.geometry_submissions) == 2
		and int(attachment.visible_geometry_copies) == 2
		and int(attachment.unique_mesh_resource_allocations) == 2
		and int(attachment.exclusive_material_allocations) == 1
		and not bool(attachment.presentation_configured)
		and float(attachment.intensity_baseline) == 0.0
		and float(attachment.live_intensity) == 0.0,
		"attachment contributes one four-node target subtree with overlay and compression renderers sharing one exclusive material"
	)
	var presentation := target.get_presentation() if target != null else null
	var state := presentation.get_state_snapshot() if presentation != null else {}
	var material := target.get_material() if target != null else null
	_check(
		presentation != null
		and not bool(state.get("configured", true))
		and int(state.get("generation", -1)) == 0
		and int(state.get("revision", -1)) == 0
		and not bool(state.get("has_presented_observation", true))
		and material != null
		and material.resource_local_to_scene
		and float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0,
		"host attachment is passive and starts at the exact zero baseline without configuring or sampling"
	)
	_check(
		target != null
		and target.is_contract_valid()
		and target.find_children("*", "CollisionObject3D", true, false).is_empty()
		and not target.is_processing()
		and not target.is_physics_processing(),
		"entry-heat attachment owns no collision or automatic process authority"
	)

	var second := ARROW_SCENE.instantiate() as ArrowReconShip
	_check(second != null, "a second Arrow instantiates for resource-ownership evidence")
	if second != null:
		second.position = Vector3(100.0, 0.0, 0.0)
		_test_root.add_child(second)
		await process_frame
		await physics_frame
		var second_target := second.get_entry_heat_target()
		var second_material := (
			second_target.get_material() if second_target != null else null
		)
		var first_overlay := target.get_overlay() if target != null else null
		var second_overlay := (
			second_target.get_overlay() if second_target != null else null
		)
		_check(
			second_target != null
			and second_target != target
			and first_overlay != null
			and second_overlay != null
			and first_overlay.mesh == second_overlay.mesh
			and material != null
			and second_material != null
			and material != second_material
			and material.shader == second_material.shader
			and float(second_material.get_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER
			)) == 0.0,
			"two Arrows share the immutable target mesh/shader but own distinct exact-zero live materials"
		)
		_check(
			_count_named(visual, "PlanetaryEntryHeatTarget") == 1
			and _count_named(
				second.get_arrow_visual_root(), "PlanetaryEntryHeatTarget"
			) == 1,
			"each live Arrow owns exactly one entry-heat target generation"
		)
		second.queue_free()
		await process_frame

	(attachment.authored_transform as Dictionary)["position"] = Vector3(INF, INF, INF)
	(attachment.target_contract as Dictionary)["valid"] = false
	_check(
		bool(arrow.get_arrow_audit_report().entry_heat_attachment.valid)
		and arrow.get_arrow_audit_report().entry_heat_attachment.authored_transform.position \
			== Vector3(0.0, 1.4, -0.15),
		"caller mutation cannot alter detached entry-heat attachment evidence"
	)
	if target != null:
		var authored_position := target.position
		target.position += Vector3(0.1, 0.0, 0.0)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"authored transform drift"
			),
			"structured-red: entry-heat attachment transform drift fails Arrow audit"
		)
		target.position = authored_position
		target.top_level = true
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"top-level transform authority"
			),
			"structured-red: top-level target drift fails Arrow audit"
		)
		target.top_level = false
		target.position = authored_position
		target.rotation = Vector3.ZERO
		target.scale = Vector3(1.45, 1.4, 1.08)
		if material != null:
			material.set_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER, 0.25
			)
			_check(
				not bool(arrow.get_arrow_audit_report().valid)
				and _report_has_error(
					arrow.get_arrow_audit_report(),
					"target contract is invalid"
				),
				"structured-red: unconfigured nonzero intensity fails Arrow target audit"
			)
			material.set_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER, 0.0
			)
		var duplicate := preload(
			"res://scenes/effects/planetary_entry_heat_target.tscn"
		).instantiate() as PlanetaryEntryHeatTarget
		visual.add_child(duplicate)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"instance roster drift"
			),
			"structured-red: a duplicate entry-heat target fails the one-instance host roster"
		)
		visual.remove_child(duplicate)
		duplicate.free()
	_check(
		bool(arrow.get_arrow_audit_report().valid),
		"Arrow audit returns green after every entry-heat host mutation is restored"
	)
	var configured := presentation.configure(
		PlanetaryAtmosphereProfile.new(), material
	)
	_check(
		bool(configured.get("accepted", false))
		and bool(arrow.get_arrow_audit_report().valid),
		"a legitimate external adapter configuration keeps the immutable Arrow host audit green"
	)
	var presented := presentation.present_observation(
		14000.0, 250.0, presentation.get_generation()
	)
	_check(
		bool(presented.get("accepted", false))
		and is_equal_approx(float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)), 0.25)
		and bool(arrow.get_arrow_audit_report().valid),
		"bounded externally driven live intensity remains valid without giving Arrow sampling authority"
	)
	var reset := presentation.reset_for_reuse(presentation.get_generation())
	_check(
		bool(reset.get("accepted", false))
		and float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0
		and bool(arrow.get_arrow_audit_report().valid),
		"explicit adapter reset restores zero while the unchanged Arrow host remains valid"
	)
	var loft := (visual.get_node("ReconFuselage") as MeshInstance3D).mesh
	_check(loft is ArrayMesh and (loft as ArrayMesh).get_faces().size() > 700, "recon fuselage has a manufactured plate loft with fitted access skins")

	var arrow_weapon_cooldown := arrow.weapon_cooldown
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_test_root.add_child(torrent)
	await process_frame
	var arrow_collision := arrow.get_node("ArrowHullCollision") as CollisionShape3D
	var torrent_collision := torrent.get_node("HullCollision") as CollisionShape3D
	var arrow_box := arrow_collision.shape as BoxShape3D
	var torrent_box := torrent_collision.shape as BoxShape3D
	_check(arrow_box.size.z > torrent_box.size.z * 1.35, "Arrow collision envelope is substantially longer than Torrent")
	_check(arrow_box.size.x < torrent_box.size.x * 0.7, "Arrow core is substantially narrower than Torrent")
	_check(arrow.maximum_speed > torrent.maximum_speed, "Arrow has a faster recon top-speed profile")
	_check(arrow.thrust_acceleration < torrent.thrust_acceleration, "Arrow trades launch acceleration for efficient speed")
	_check(arrow.yaw_speed_degrees < torrent.yaw_speed_degrees, "long recon craft turns differently from the interceptor")
	_check(arrow.roll_speed_degrees > torrent.roll_speed_degrees, "Arrow has a distinct higher roll response")
	_check(arrow.maximum_hull < torrent.maximum_hull, "Arrow is lighter and more fragile than the interceptor")
	_check(arrow_weapon_cooldown > torrent.weapon_cooldown, "Arrow's light pulse weapons fire more slowly than Torrent cannons")
	torrent.queue_free()
	await process_frame


func _test_escape_pods_and_sensors(arrow: ArrowReconShip) -> void:
	_check(arrow.get_escape_pod_count() == 2, "Arrow visibly exposes exactly two escape pods")
	var pods := arrow.get_escape_pods()
	_check(pods.size() == 2 and pods[0] != pods[1], "escape pods are distinct scene-tree modules")
	var port := arrow.get_escape_pod(&"port")
	var starboard := arrow.get_escape_pod(&"starboard")
	_check(port != null and starboard != null, "both port and starboard pods resolve by stable side ID")
	_check(arrow.get_escape_pod(&"missing") == null, "unknown pod side has no fallback")
	if port != null and starboard != null:
		_check(port.position.x < -1.0 and starboard.position.x > 1.0, "pods are visibly separated on opposite fuselage sides")
		_check(port.position.distance_to(starboard.position) > 3.0, "pod pressure shells are not a duplicated central decoration")
		for pod in [port, starboard]:
			_check(bool(pod.get_meta("escape_pod", false)), "%s is semantically tagged as escape pod" % pod.name)
			_check(str(pod.get_meta("geometry_status", "")) == "provisional", "%s exposes provisional geometry status" % pod.name)
			_check(bool(pod.get_meta("separable_visual_module", false)), "%s is a visibly separable module" % pod.name)
			_check(not bool(pod.get_meta("release_mechanism_implemented", true)), "%s does not falsely claim a working release system" % pod.name)
			_check(pod.get_node_or_null("PodPressureShell") is MeshInstance3D, "%s owns a smooth pressure shell" % pod.name)
			_check(pod.get_node_or_null("PodSeparationCollar") is MeshInstance3D, "%s has a legible separation collar" % pod.name)
		var port_status_light := port.get_node_or_null("PodStatusLight") as MeshInstance3D
		var starboard_status_light := starboard.get_node_or_null("PodStatusLight") as MeshInstance3D
		_check(
			port_status_light != null and starboard_status_light != null
			and port_status_light.mesh == starboard_status_light.mesh
			and port_status_light.mesh is SphereMesh
			and is_equal_approx((port_status_light.mesh as SphereMesh).radius, ArrowReconShip.ESCAPE_POD_STATUS_LIGHT_RADIUS)
			and (port_status_light.mesh as SphereMesh).material == arrow.get_variant_materials().sensor
			and port_status_light.position.is_equal_approx(Vector3(-0.53, 0.14, -0.72))
			and starboard_status_light.position.is_equal_approx(Vector3(0.53, 0.14, -0.72))
			and port_status_light.visible and starboard_status_light.visible
			and port_status_light.find_children("*", "CollisionObject3D", true, false).is_empty()
			and starboard_status_light.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"escape-pod status lights retain exact local transforms and sensor material while sharing one immutable visual mesh"
		)

	var mast := arrow.get_sensor_mast()
	_check(mast != null and mast.name == "SensorSweep", "Arrow exposes its rotating sensor sweep")
	_check(mast != null and mast.get_parent().name == "ReconSensorMast", "sensor sweep sits on a dedicated dorsal mast")
	var receiver_report := arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary
	_check(
		bool(receiver_report.valid) and int(receiver_report.geometry_nodes) == 1
			and int(receiver_report.geometry_submissions) == 1
			and int(receiver_report.visible_geometry_copies) == 2
			and int(receiver_report.primitive_mesh_allocations) == 1
			and int(receiver_report.multimesh_allocations) == 1,
		"mirrored sensor receivers retain both exact copies in one bounded batch"
	)
	if mast != null:
		var receiver := mast.get_node_or_null("ArrayReceiver") as MultiMeshInstance3D
		if receiver != null and receiver.multimesh != null:
			var authored_bounds := receiver.multimesh.custom_aabb
			receiver.multimesh.custom_aabb = authored_bounds.grow(0.1)
			_check(
				not bool((arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary).valid),
				"structured-red: receiver culling-bounds drift fails the batch audit"
			)
			receiver.multimesh.custom_aabb = authored_bounds
			_check(
				bool((arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary).valid),
				"restoring receiver culling bounds clears the batch audit"
			)
	_check(arrow.get_arrow_visual_root().get_node_or_null("VentralSensorGimbal") is MeshInstance3D, "recon craft has a ventral optical/spectral gimbal")
	_check(
		arrow.get_arrow_visual_root().get_node_or_null("PortLateralArray") != null
		and arrow.get_arrow_visual_root().get_node_or_null("StarboardLateralArray") != null,
		"recon craft exposes paired lateral sensor arrays"
	)



func _test_airframe_shadow_batch(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var batch := visual.get_node_or_null("OpaqueEnvelopeShadowBatch") as MeshInstance3D
	var sources: Array[MeshInstance3D] = arrow._airframe_shadow_sources
	_check(batch != null and sources.size() == 28, "Arrow builds one shadow renderer from exactly 28 constructor-owned rigid airframe sources")
	if batch == null or sources.size() != 28:
		return
	var expected_names := PackedStringArray([
		"ReconFuselage", "GraphiteKeel", "PortSensorWing", "StarboardSensorWing",
		"WingtipSensorPod", "StarboardWingtipSensorPod", "DorsalSurveySpine", "CockpitSillFairing",
		"PortShoulderFairing", "StarboardShoulderFairing", "PortEngineIntakeFairing", "StarboardEngineIntakeFairing",
		"PortSurveyCoolingDuct", "StarboardSurveyCoolingDuct", "PortWingInset", "StarboardWingInset",
		"PortSensorWingSkin0", "PortSensorWingSkin1", "PortSensorWingSkin2",
		"StarboardSensorWingSkin0", "StarboardSensorWingSkin1", "StarboardSensorWingSkin2",
		"PortSurveyRecognitionMark", "StarboardSurveyRecognitionMark",
		"EfficientEngineHousing", "StarboardEfficientEngineHousing", "PortRefractoryNozzle", "StarboardRefractoryNozzle",
	])
	var names := PackedStringArray()
	var merged := batch.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = merged[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = merged[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = merged[Mesh.ARRAY_INDEX]
	var vertex_offset := 0
	var index_offset := 0
	var positions_match := true
	var indices_match := true
	var renderers_match := true
	var normal_error := 0.0
	var bounds := AABB()
	for source in sources:
		var source_name := str(source.name)
		if source_name.begins_with("@"):
			if source.position.is_equal_approx(Vector3(5.55, 1.0, 2.45)):
				source_name = "StarboardWingtipSensorPod"
			elif source.position.is_equal_approx(Vector3(0.92, 0.94, 5.0)):
				source_name = "StarboardEfficientEngineHousing"
		names.append(source_name)
		renderers_match = renderers_match and source.get_parent() == visual and source.visible \
			and source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and source.material_override == null and arrow.get_variant_materials().values().has(source.get_active_material(0))
		var arrays := source.mesh.surface_get_arrays(0)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			for index in source_vertices.size():
				source_indices.append(index)
		var normal_basis := source.basis.inverse().transposed()
		for index in source_vertices.size():
			var expected_vertex := source.transform * source_vertices[index]
			positions_match = positions_match and vertices[vertex_offset + index].is_equal_approx(expected_vertex)
			normal_error = maxf(normal_error, normals[vertex_offset + index].distance_to((normal_basis * source_normals[index]).normalized()))
			bounds = AABB(expected_vertex, Vector3.ZERO) if vertex_offset + index == 0 else bounds.expand(expected_vertex)
		for index in source_indices.size():
			indices_match = indices_match and indices[index_offset + index] == vertex_offset + source_indices[index]
		vertex_offset += source_vertices.size()
		index_offset += source_indices.size()
	names.sort()
	expected_names.sort()
	_check(names == expected_names and renderers_match, "the exact 28 finalized shell sources retain their original colour materials, parents and visibility")
	_check(positions_match and indices_match and vertices.size() == vertex_offset and indices.size() == index_offset and normal_error <= 0.0002, "merged shadow triangles preserve finalized vertices/index order and packed normal directions")
	_check(batch.transform == Transform3D.IDENTITY and batch.mesh.get_aabb().is_equal_approx(bounds) \
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
		and batch.material_override == sources[0].get_active_material(0) and batch.get_child_count() == 0,
		"the single shadow-only batch retains tight source bounds and opaque material semantics without children or physics")
	var original_rotation := visual.rotation
	visual.rotation.z = deg_to_rad(13.0)
	var banking_matches := batch.global_transform.is_equal_approx(visual.global_transform)
	for source in sources:
		banking_matches = banking_matches and source.global_transform.is_equal_approx(visual.global_transform * source.transform)
	visual.rotation = original_rotation
	_check(banking_matches, "the batch and retained colour geometry share the inherited banked visual root")
	print("ARROW_AIRFRAME_SHADOW_PARITY: sources=", sources.size(), " vertices=", vertex_offset, " triangles=", index_offset / 3, " bounds=", bounds, " max_normal_error=", normal_error)



func _test_visual_performance_batch(arrow: ArrowReconShip) -> void:
	var report := arrow.get_arrow_visual_performance_report()
	if not bool(report.valid):
		print("ARROW_VISUAL_CENSUS_ERRORS: ", report.errors)
	var local_evidence_format := (
		"ARROW_WING_ROOT_RIB_BATCH: nodes %d->%d submissions %d->%d "
		+ "primitive_mesh_allocations %d->%d visible_copies %d->%d"
	)
	print(local_evidence_format % [
			int(report.wing_root_rib_batch.legacy.geometry_nodes),
			int(report.wing_root_rib_batch.geometry_nodes),
			int(report.wing_root_rib_batch.legacy.geometry_submissions),
			int(report.wing_root_rib_batch.geometry_submissions),
			int(report.wing_root_rib_batch.legacy.primitive_mesh_allocations),
		int(report.wing_root_rib_batch.primitive_mesh_allocations),
		int(report.wing_root_rib_batch.legacy.visible_geometry_copies),
		int(report.wing_root_rib_batch.visible_geometry_copies),
	])
	var joint_evidence_format := (
		"ARROW_LATERAL_ARRAY_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(joint_evidence_format % [
		int(report.lateral_array_curve_joint_sharing.legacy.geometry_nodes),
		int(report.lateral_array_curve_joint_sharing.geometry_nodes),
		int(report.lateral_array_curve_joint_sharing.legacy.geometry_submissions),
		int(report.lateral_array_curve_joint_sharing.geometry_submissions),
		int(report.lateral_array_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.lateral_array_curve_joint_sharing.primitive_mesh_allocations),
		int(report.lateral_array_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.lateral_array_curve_joint_sharing.visible_geometry_copies),
	])
	var leading_edge_evidence_format := (
		"ARROW_SENSOR_LEADING_EDGE_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(leading_edge_evidence_format % [
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.geometry_nodes),
		int(report.sensor_leading_edge_curve_joint_sharing.geometry_nodes),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.geometry_submissions),
		int(report.sensor_leading_edge_curve_joint_sharing.geometry_submissions),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.sensor_leading_edge_curve_joint_sharing.visible_geometry_copies),
	])
	var dorsal_conduit_evidence_format := (
		"ARROW_DORSAL_DATA_CONDUIT_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(dorsal_conduit_evidence_format % [
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.geometry_nodes),
		int(report.dorsal_data_conduit_curve_joint_sharing.geometry_nodes),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.geometry_submissions),
		int(report.dorsal_data_conduit_curve_joint_sharing.geometry_submissions),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.dorsal_data_conduit_curve_joint_sharing.primitive_mesh_allocations),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.dorsal_data_conduit_curve_joint_sharing.visible_geometry_copies),
	])
	var panel_band_evidence_format := (
		"ARROW_FUSELAGE_PANEL_BAND_MESH_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(panel_band_evidence_format % [
		int(report.fuselage_panel_band_mesh_sharing.legacy.geometry_nodes),
		int(report.fuselage_panel_band_mesh_sharing.geometry_nodes),
		int(report.fuselage_panel_band_mesh_sharing.legacy.geometry_submissions),
		int(report.fuselage_panel_band_mesh_sharing.geometry_submissions),
		int(report.fuselage_panel_band_mesh_sharing.legacy.primitive_mesh_allocations),
		int(report.fuselage_panel_band_mesh_sharing.primitive_mesh_allocations),
		int(report.fuselage_panel_band_mesh_sharing.legacy.visible_geometry_copies),
		int(report.fuselage_panel_band_mesh_sharing.visible_geometry_copies),
	])
	var whole_evidence_format := (
		"ARROW_VISUAL_CENSUS: nodes %d->%d submissions %d->%d "
		+ "unique_mesh_allocations %d->%d visible_copies %d->%d"
	)
	print(whole_evidence_format % [
			int(report.legacy.nodes), int(report.current.nodes),
			int(report.legacy.geometry_submissions),
			int(report.current.geometry_submissions),
			int(report.legacy.unique_mesh_resource_allocations),
			int(report.current.unique_mesh_resource_allocations),
			int(report.legacy.visible_geometry_copies),
			int(report.current.visible_geometry_copies),
	])
	_check(
		bool(report.valid)
		and report.current == report.expected
		and report.expected_without_markings == {
			"nodes": 284,
			"mesh_instance_nodes": 246,
			"multi_mesh_instance_nodes": 2,
			"geometry_submissions": 252,
			"visible_geometry_copies": 249,
			"unique_mesh_resource_allocations": 197,
			"auto_fallback_names": 20,
		},
		"entry-complete Arrow retains 284 nodes, 252 submissions including one shadow-only renderer, 197 meshes with shared folding access and 249 copies"
	)
	_check(
		report.phase9_before_entry_heat == {
			"nodes": 176,
			"mesh_instance_nodes": 157,
			"multi_mesh_instance_nodes": 1,
			"geometry_submissions": 158,
			"visible_geometry_copies": 159,
			"unique_mesh_resource_allocations": 119,
			"auto_fallback_names": 23,
		}
		and report.entry_heat_target_delta == {
			"target_subtree_nodes": 4,
			"renderer_nodes": 2,
			"surface_count": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"unique_mesh_resource_allocations": 2,
			"exclusive_material_allocations": 1,
		}
		and report.recon_pulse_emitter_delta == {
			"assembly_nodes": 2,
			"renderer_nodes": 8,
			"geometry_submissions": 8,
			"visible_geometry_copies": 8,
			"unique_mesh_resource_allocations": 4,
		}
		and report.reductions == {
			"nodes": -12,
			"geometry_submissions": -8,
			"unique_mesh_resource_allocations": 19,
			"auto_fallback_names": 4,
			"visible_geometry_copies": -12,
		}
		and report.phase9_reductions_before_entry_heat == {
			"nodes": 1,
			"geometry_submissions": 1,
			"unique_mesh_resource_allocations": 23,
			"auto_fallback_names": 1,
			"visible_geometry_copies": 0,
		},
		"performance evidence isolates the exact recon-emitter and entry-heat deltas from the frozen Phase-9 visual"
	)
	_check(
		report.wing_root_rib_batch.legacy == {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
			"multimesh_allocations": 0,
		}
		and int(report.wing_root_rib_batch.geometry_nodes) == 1
		and int(report.wing_root_rib_batch.geometry_submissions) == 1
		and int(report.wing_root_rib_batch.visible_geometry_copies) == 2
		and int(report.wing_root_rib_batch.primitive_mesh_allocations) == 1
		and int(report.wing_root_rib_batch.multimesh_allocations) == 1,
		"local rib family records exact 2->1 node/submission/primitive allocation with its two visible copies unchanged"
	)
	_check(
		report.lateral_array_curve_joint_sharing.legacy == {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		}
		and int(report.lateral_array_curve_joint_sharing.geometry_nodes) == 6
		and int(report.lateral_array_curve_joint_sharing.geometry_submissions) == 6
		and int(report.lateral_array_curve_joint_sharing.visible_geometry_copies) == 6
		and int(report.lateral_array_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.lateral_array_curve_joint_sharing.resource_allocation_reduction) == 5
		and report.lateral_array_curve_joint_sharing.node_paths == PackedStringArray([
			"PortLateralArray/CurveJoint",
			"PortLateralArray/@MeshInstance3D@14",
			"PortLateralArray/@MeshInstance3D@15",
			"StarboardLateralArray/CurveJoint",
			"StarboardLateralArray/@MeshInstance3D@16",
			"StarboardLateralArray/@MeshInstance3D@17",
		]),
		"six unchanged lateral-array nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of six"
	)
	_check(
		report.sensor_leading_edge_curve_joint_sharing.legacy == {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		}
		and int(report.sensor_leading_edge_curve_joint_sharing.geometry_nodes) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.geometry_submissions) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.visible_geometry_copies) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.sensor_leading_edge_curve_joint_sharing.resource_allocation_reduction) == 5
		and report.sensor_leading_edge_curve_joint_sharing.node_paths == PackedStringArray([
			"SensorLeadingEdge/CurveJoint",
			"SensorLeadingEdge/@MeshInstance3D@2",
			"SensorLeadingEdge/@MeshInstance3D@3",
			"@Node3D@4/CurveJoint",
			"@Node3D@4/@MeshInstance3D@5",
			"@Node3D@4/@MeshInstance3D@6",
		]),
		"six unchanged sensor-leading-edge nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of six"
	)
	_check(
		report.dorsal_data_conduit_curve_joint_sharing.legacy == {
			"geometry_nodes": 3,
			"geometry_submissions": 3,
			"visible_geometry_copies": 3,
			"primitive_mesh_allocations": 3,
		}
		and int(report.dorsal_data_conduit_curve_joint_sharing.geometry_nodes) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.geometry_submissions) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.visible_geometry_copies) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.dorsal_data_conduit_curve_joint_sharing.resource_allocation_reduction) == 2
		and report.dorsal_data_conduit_curve_joint_sharing.node_paths == PackedStringArray([
			"DorsalDataConduit/CurveJoint",
			"DorsalDataConduit/@MeshInstance3D@8",
			"DorsalDataConduit/@MeshInstance3D@9",
		]),
		"three named dorsal-conduit nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of three"
	)
	_check(
		report.fuselage_panel_band_mesh_sharing.legacy == {
			"geometry_nodes": 5,
			"geometry_submissions": 5,
			"visible_geometry_copies": 5,
			"primitive_mesh_allocations": 5,
		}
		and int(report.fuselage_panel_band_mesh_sharing.geometry_nodes) == 5
		and int(report.fuselage_panel_band_mesh_sharing.geometry_submissions) == 5
		and int(report.fuselage_panel_band_mesh_sharing.visible_geometry_copies) == 5
		and int(report.fuselage_panel_band_mesh_sharing.primitive_mesh_allocations) == 1
		and int(report.fuselage_panel_band_mesh_sharing.resource_allocation_reduction) == 4
		and StringName(report.fuselage_panel_band_mesh_sharing.mesh_kind) == &"BoxMesh"
		and (report.fuselage_panel_band_mesh_sharing.mesh_size as Vector3).is_equal_approx(
			Vector3(0.74, 0.024, 0.07)
		)
		and (report.fuselage_panel_band_mesh_sharing.node_paths as PackedStringArray).size() == 5
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[0]) == "FuselagePanelBand"
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[1]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[2]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[3]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[4]).begins_with("@MeshInstance3D@"),
		"five ordinary dorsal panel seams retain one shallow BoxMesh instead of hollow full-circumference loops"
	)
	_check(
		report.cockpit_console_key_mesh_sharing.legacy == {
			"geometry_nodes": 4,
			"geometry_submissions": 4,
			"visible_geometry_copies": 4,
			"primitive_mesh_allocations": 4,
		}
		and int(report.cockpit_console_key_mesh_sharing.geometry_nodes) == 4
		and int(report.cockpit_console_key_mesh_sharing.geometry_submissions) == 4
		and int(report.cockpit_console_key_mesh_sharing.visible_geometry_copies) == 4
		and int(report.cockpit_console_key_mesh_sharing.primitive_mesh_allocations) == 1
		and int(report.cockpit_console_key_mesh_sharing.resource_allocation_reduction) == 3
		and report.cockpit_console_key_mesh_sharing.node_paths == PackedStringArray([
			"CockpitInterior/PortConsoleKey00",
			"CockpitInterior/PortConsoleKey02",
			"CockpitInterior/StarboardConsoleKey00",
			"CockpitInterior/StarboardConsoleKey02",
		]),
		"four inherited cyan console keys retain their named nodes, transforms, submissions and visible copies while sharing one immutable mesh"
	)
	var visual := arrow.get_arrow_visual_root()
	var batch := visual.get_node_or_null("WingRootRibBatch") as MultiMeshInstance3D
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.instance_count == 2
		and batch.multimesh.visible_instance_count == 2
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and bool(batch.get_meta("visual_detail_only", false))
		and (batch.get_meta("authored_instance_transforms", []) as Array).size() == 2
		and batch.get_groups().is_empty()
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty()
		and visual.get_node_or_null("WingRootRib") == null,
		"the rib batch owns only visual-detail audit metadata and no script, group, child, or collision authority"
	)
	_check(
		visual.get_node_or_null("FuselagePanelBand") is MeshInstance3D,
		"the first dorsal panel-seam evidence node remains independently addressable"
	)

	# Detached report and structured-red mutations cover the whole census,
	# authored transform buffer, visible roster, and shared primitive allocation.
	(report.current as Dictionary)["nodes"] = -1
	(report.wing_root_rib_batch as Dictionary)["geometry_nodes"] = -1
	(report.lateral_array_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.sensor_leading_edge_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.dorsal_data_conduit_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.fuselage_panel_band_mesh_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.entry_heat_target as Dictionary)["target_subtree_nodes"] = -1
	var detached_dorsal_transforms := (
		report.dorsal_data_conduit_curve_joint_sharing.authored_transforms as Array
	)
	detached_dorsal_transforms[0] = Transform3D.IDENTITY
	var detached_panel_transforms := (
		report.fuselage_panel_band_mesh_sharing.authored_transforms as Array
	)
	detached_panel_transforms[0] = Transform3D.IDENTITY
	_check(
		int(arrow.get_arrow_visual_performance_report().current.nodes) == 284 + int(report.surface_marking_costs.nodes)
		and int(
			arrow.get_arrow_visual_performance_report()
				.lateral_array_curve_joint_sharing.primitive_mesh_allocations
		) == 1
		and int(
			arrow.get_arrow_visual_performance_report()
				.entry_heat_target.target_subtree_nodes
		) == 4,
		"caller mutation cannot alter the detached visual or entry-heat performance evidence"
	)
	_check(
		int(
			arrow.get_arrow_visual_performance_report()
				.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations
		) == 1,
		"caller mutation cannot alter detached sensor-leading-edge allocation evidence"
	)
	var fresh_dorsal_report := (
		arrow.get_arrow_visual_performance_report()
			.dorsal_data_conduit_curve_joint_sharing as Dictionary
	)
	_check(
		int(fresh_dorsal_report.primitive_mesh_allocations) == 1
		and not ((fresh_dorsal_report.authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"caller mutation cannot alter detached dorsal-conduit allocation or transform evidence"
	)
	var fresh_panel_report := (
		arrow.get_arrow_visual_performance_report()
			.fuselage_panel_band_mesh_sharing as Dictionary
	)
	_check(
		int(fresh_panel_report.primitive_mesh_allocations) == 1
		and not ((fresh_panel_report.authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"caller mutation cannot alter detached panel-band allocation or transform evidence"
	)
	var torus_budget_report := TorusGeometryBudget.normalise_tree(arrow)
	var budgeted_panel_report := (
		arrow.get_arrow_visual_performance_report()
			.fuselage_panel_band_mesh_sharing as Dictionary
	)
	_check(
		bool(budgeted_panel_report.valid)
		and StringName(budgeted_panel_report.mesh_kind) == &"BoxMesh"
		and int(torus_budget_report.tori) == 10,
		"production torus budget retains the compact emitter shrouds and bounded compression bow while leaving shallow dorsal seams outside torus normalization"
	)
	var injected := Node3D.new()
	injected.name = "ForbiddenVisualAllocation"
	visual.add_child(injected)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"whole visual census drift: nodes"
		),
		"structured-red: an unbudgeted visual node fails the whole Arrow census"
	)
	visual.remove_child(injected)
	injected.free()
	if batch != null and batch.multimesh != null:
		var authored_transforms := (
			batch.get_meta("authored_instance_transforms", []) as Array
		).duplicate()
		var corrupted_transforms := authored_transforms.duplicate()
		var authored_transform := corrupted_transforms[0] as Transform3D
		corrupted_transforms[0] = Transform3D(
			authored_transform.basis,
			authored_transform.origin + Vector3(0.1, 0, 0)
		)
		batch.set_meta("authored_instance_transforms", corrupted_transforms)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib authored transform metadata drift"
			),
			"structured-red: an authored rib transform mutation fails presentation audit"
		)
		batch.set_meta("authored_instance_transforms", authored_transforms)
		var authored_bounds := batch.multimesh.custom_aabb
		batch.multimesh.custom_aabb = authored_bounds.grow(0.1)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib culling bounds drift"
			),
			"structured-red: a rib batch culling-bounds mutation fails presentation audit"
		)
		batch.multimesh.custom_aabb = authored_bounds
		batch.multimesh.visible_instance_count = 1
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib visible-copy roster drift"
			),
			"structured-red: hiding one batched rib fails the visible-copy roster"
		)
		batch.multimesh.visible_instance_count = 2
		var box := batch.multimesh.mesh as BoxMesh
		if box != null:
			var authored_size := box.size
			box.size.x += 0.1
			_check(
				not bool(arrow.get_arrow_audit_report().valid)
				and _report_has_error(
					arrow.get_arrow_visual_performance_report(),
					"wing-root rib primitive allocation drift"
				),
				"structured-red: shared rib primitive mutation fails presentation audit"
			)
			box.size = authored_size
	var lateral_report := (
		arrow.get_arrow_visual_performance_report()
			.lateral_array_curve_joint_sharing as Dictionary
	)
	var joint_paths := lateral_report.node_paths as PackedStringArray
	var first_joint := visual.get_node(NodePath(joint_paths[0])) as MeshInstance3D
	var last_joint := visual.get_node(NodePath(joint_paths[-1])) as MeshInstance3D
	var shared_joint_mesh := first_joint.mesh as SphereMesh
	last_joint.mesh = shared_joint_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private lateral-array joint mesh fails shared-allocation identity"
	)
	last_joint.mesh = shared_joint_mesh
	var authored_radius := shared_joint_mesh.radius
	shared_joint_mesh.radius += 0.01
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint primitive recipe drift"
		),
		"structured-red: shared lateral-array sphere recipe mutation fails presentation audit"
	)
	shared_joint_mesh.radius = authored_radius
	var authored_material := shared_joint_mesh.material
	shared_joint_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint material identity drift"
		),
		"structured-red: lateral-array material mutation fails presentation audit"
	)
	shared_joint_mesh.material = authored_material
	last_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint render-state drift"
		),
		"structured-red: lateral-array shadow mutation fails presentation audit"
	)
	last_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var leading_edge_report := (
		arrow.get_arrow_visual_performance_report()
			.sensor_leading_edge_curve_joint_sharing as Dictionary
	)
	var leading_edge_paths := leading_edge_report.node_paths as PackedStringArray
	var first_leading_edge_joint := (
		visual.get_node(NodePath(leading_edge_paths[0])) as MeshInstance3D
	)
	var last_leading_edge_joint := (
		visual.get_node(NodePath(leading_edge_paths[-1])) as MeshInstance3D
	)
	var shared_leading_edge_mesh := first_leading_edge_joint.mesh as SphereMesh
	last_leading_edge_joint.mesh = shared_leading_edge_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private sensor-leading-edge joint mesh fails shared-allocation identity"
	)
	last_leading_edge_joint.mesh = shared_leading_edge_mesh
	var authored_leading_edge_rings := shared_leading_edge_mesh.rings
	shared_leading_edge_mesh.rings -= 1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint primitive recipe drift"
		),
		"structured-red: shared sensor-leading-edge sphere recipe mutation fails presentation audit"
	)
	shared_leading_edge_mesh.rings = authored_leading_edge_rings
	var authored_leading_edge_material := shared_leading_edge_mesh.material
	shared_leading_edge_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint material identity drift"
		),
		"structured-red: sensor-leading-edge material mutation fails presentation audit"
	)
	shared_leading_edge_mesh.material = authored_leading_edge_material
	last_leading_edge_joint.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint render-state drift"
		),
		"structured-red: sensor-leading-edge renderer-layer mutation fails presentation audit"
	)
	last_leading_edge_joint.layers = 1
	last_leading_edge_joint.set_meta("forbidden_semantic_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint gained semantic authority"
		),
		"structured-red: sensor-leading-edge semantic metadata fails the zero-authority audit"
	)
	last_leading_edge_joint.remove_meta("forbidden_semantic_authority")
	var dorsal_conduit_report := (
		arrow.get_arrow_visual_performance_report()
			.dorsal_data_conduit_curve_joint_sharing as Dictionary
	)
	var dorsal_joint_paths := dorsal_conduit_report.node_paths as PackedStringArray
	var first_dorsal_joint := (
		visual.get_node(NodePath(dorsal_joint_paths[0])) as MeshInstance3D
	)
	var last_dorsal_joint := (
		visual.get_node(NodePath(dorsal_joint_paths[-1])) as MeshInstance3D
	)
	var shared_dorsal_mesh := first_dorsal_joint.mesh as SphereMesh
	last_dorsal_joint.mesh = shared_dorsal_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private dorsal-conduit joint mesh fails shared-allocation identity"
	)
	last_dorsal_joint.mesh = shared_dorsal_mesh
	var authored_dorsal_radial_segments := shared_dorsal_mesh.radial_segments
	shared_dorsal_mesh.radial_segments -= 1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint primitive recipe drift"
		),
		"structured-red: shared dorsal-conduit sphere recipe mutation fails presentation audit"
	)
	shared_dorsal_mesh.radial_segments = authored_dorsal_radial_segments
	var authored_dorsal_material := shared_dorsal_mesh.material
	shared_dorsal_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint material identity drift"
		),
		"structured-red: dorsal-conduit sensor-material mutation fails presentation audit"
	)
	shared_dorsal_mesh.material = authored_dorsal_material
	last_dorsal_joint.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint render-state drift"
		),
		"structured-red: dorsal-conduit renderer-layer mutation fails presentation audit"
	)
	last_dorsal_joint.layers = 1
	last_dorsal_joint.set_meta("forbidden_lifecycle_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint gained semantic authority"
		),
		"structured-red: dorsal-conduit lifecycle metadata fails the zero-authority audit"
	)
	last_dorsal_joint.remove_meta("forbidden_lifecycle_authority")
	var panel_band_paths := (
		budgeted_panel_report.node_paths as PackedStringArray
	)
	var first_panel_band := (
		visual.get_node(NodePath(panel_band_paths[0])) as MeshInstance3D
	)
	var last_panel_band := (
		visual.get_node(NodePath(panel_band_paths[-1])) as MeshInstance3D
	)
	var shared_panel_band_mesh := first_panel_band.mesh as BoxMesh
	last_panel_band.mesh = shared_panel_band_mesh.duplicate() as BoxMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band shared-mesh identity drift"
		),
		"structured-red: one private panel-band mesh fails shared-allocation identity"
	)
	last_panel_band.mesh = shared_panel_band_mesh
	var authored_panel_size := shared_panel_band_mesh.size
	shared_panel_band_mesh.size.x -= 0.1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band primitive recipe drift"
		),
		"structured-red: shared panel-band live recipe mutation fails presentation audit"
	)
	shared_panel_band_mesh.size = authored_panel_size
	var authored_panel_material := shared_panel_band_mesh.material
	shared_panel_band_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band material identity drift"
		),
		"structured-red: panel-band titanium-material mutation fails presentation audit"
	)
	shared_panel_band_mesh.material = authored_panel_material
	last_panel_band.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band render-state drift"
		),
		"structured-red: panel-band renderer-layer mutation fails presentation audit"
	)
	last_panel_band.layers = 1
	last_panel_band.set_meta("forbidden_semantic_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band gained semantic authority"
		),
		"structured-red: panel-band metadata fails the zero-authority audit"
	)
	last_panel_band.remove_meta("forbidden_semantic_authority")
	_check(
		bool(arrow.get_arrow_audit_report().valid),
		"whole/local Arrow visual audits return green after every mutation is restored"
	)


func _test_instrument_construction(arrow: ArrowReconShip) -> void:
	var cluster := arrow.get_arrow_visual_root().get_node("CockpitInterior/InstrumentCluster") as Node3D
	var readout := cluster.get_node("FlightDataReadout") as Label3D
	_check(readout == arrow.get("_cockpit_readout") and readout.has_node("LiveFlightInstruments") and not readout.no_depth_test,
		"recessed instruments retain the controller-owned physical live readout")
	var port := cluster.get_node("PortStatusRepeater") as MeshInstance3D
	var starboard := cluster.get_node("StarboardStatusRepeater") as MeshInstance3D
	_check(port.mesh == starboard.mesh and port.mesh.get_surface_count() == 1,
		"both recessed dial sockets share one immutable single-surface mesh")
	var camera := arrow.get("_cockpit_camera") as Camera3D
	var geometry_valid := true
	var clear_dials := true
	for node_name in ["InstrumentHood", "DisplayBezelTop", "DisplayBezelBottom", "PortDisplayBezelSide", "StarboardDisplayBezelSide", "PortStatusRepeater", "StarboardStatusRepeater"]:
		var stock := cluster.get_node(node_name) as MeshInstance3D
		for surface in stock.mesh.get_surface_count():
			var arrays := stock.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			geometry_valid = geometry_valid and normals.size() == vertices.size() and uvs.size() == vertices.size()
			for index in vertices.size():
				geometry_valid = geometry_valid and vertices[index].is_finite() and normals[index].is_finite() and normals[index].length() > 0.99 and uvs[index].is_finite()
			for index in range(0, vertices.size(), 3):
				var a := vertices[index]
				var b := vertices[index + 1]
				var c := vertices[index + 2]
				geometry_valid = geometry_valid and (b - a).cross(c - a).dot(normals[index]) < 0.0
				geometry_valid = geometry_valid and absf((uvs[index + 1] - uvs[index]).cross(uvs[index + 2] - uvs[index])) > 0.00000001
				# Sample the outer dial ticks from the real pilot eye, including
				# the off-axis far rim, against every new opaque mounting face.
				for side in [-1.0, 1.0]:
					for sample in 24:
						var angle := TAU * float(sample) / 24.0
						var target := cluster.to_global(Vector3(side * 0.57 + cos(angle) * 0.116, 0.08 + sin(angle) * 0.116, 0.165))
						clear_dials = clear_dials and Geometry3D.segment_intersects_triangle(stock.to_local(camera.global_position), stock.to_local(target), a, b, c) == null
	_check(geometry_valid, "instrument stock retains outward winding, finite unit normals and nonsingular UVs")
	_check(clear_dials, "both complete dial sweeps clear the new mounting geometry from the authored pilot eye")


func _test_formed_coaming(arrow: ArrowReconShip) -> void:
	var cockpit := arrow.get_arrow_visual_root().get_node("CockpitInterior")
	var port := cockpit.get_node("PortSidewall") as MeshInstance3D
	var starboard := cockpit.get_node("StarboardSidewall") as MeshInstance3D
	var bounds := AABB(Vector3(-0.09, -0.24, -1.6), Vector3(0.18, 0.48, 3.2))
	_check(port.mesh == starboard.mesh and port.mesh.get_surface_count() == 1,
		"both formed coamings share one surface on the inherited renderers")
	var valid := true
	for stock: MeshInstance3D in [port, starboard]:
		valid = valid and stock.mesh.get_aabb().is_equal_approx(bounds)
		valid = valid and stock.position.is_equal_approx(Vector3(-1.08 if stock == port else 1.08, 2.17, -0.55))
		var arrays := stock.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		valid = valid and indices.size() / 3 == 588 and arrays[Mesh.ARRAY_TANGENT].size() == vertices.size() * 4
		for index in vertices.size():
			valid = valid and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			valid = valid and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) < -0.00000001
			valid = valid and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 0.00000001
		# The former sharp upper fore corner must now be absent; central
		# top and side stock retain the exact original envelope/support.
		var center_span := _mesh_vertical_span(stock, Vector2(stock.position.x, -0.55))
		valid = valid and center_span.size() >= 2 and is_equal_approx(center_span[-1], 2.41)
		for end_z in [-2.05, 0.95]:
			var return_span := _mesh_vertical_span(stock, Vector2(stock.position.x, end_z))
			valid = valid and return_span.size() >= 2 and return_span[-1] < 2.40 and return_span[-1] > 2.34
		var rolled_span := _mesh_vertical_span(stock, Vector2(stock.position.x + 0.07, -0.55))
		valid = valid and rolled_span.size() >= 2 and rolled_span[-1] < 2.39 and rolled_span[-1] > 2.33
	print("ARROW_COAMING_COST: shared_meshes=1 surfaces=1 renderers=2 triangles_per_copy=588 total_triangles=1176 previous_total=24 bounds=", port.mesh.get_aabb())
	_check(valid, "formed coaming keeps exact wall envelope, authored transforms and sound bounded smooth geometry")


func _test_cockpit_fairing(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var fairing := visual.get_node("CockpitSillFairing") as MeshInstance3D
	var bounds := fairing.transform * fairing.mesh.get_aabb()
	_check(fairing.mesh.get_surface_count() == 1
		and fairing.mesh.surface_get_material(0) == arrow.get_variant_materials().ceramic
		and bounds.end.y <= 2.19 and bounds.end.z <= 1.20 + 0.00001,
		"formed cockpit sill retains one ceramic skin within the previous cockpit crown and aft clearance")
	var nose := visual.get_node("ReconFuselage") as MeshInstance3D
	var forward_cap_seated := true
	for vertex: Vector3 in fairing.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := fairing.transform * vertex
		if absf(point.z - bounds.position.z) > 0.00001:
			continue
		var nose_span := _mesh_vertical_span(nose, Vector2(point.x, point.z), true)
		forward_cap_seated = forward_cap_seated and nose_span.size() >= 2
		if nose_span.size() >= 2:
			forward_cap_seated = forward_cap_seated and point.y > nose_span[0] and point.y < nose_span[-1]
	_check(forward_cap_seated, "the entire forward fairing cap is buried within the retained nose shell")
	# At each join the closed fairing must actually overlap its supporting
	# shell. A shallow loft above the roof passes bounds/winding but floats.
	var joins_seated := true
	for sample: Array in [
		["ReconFuselage", Vector2(0.0, -2.90)],
		["PortShoulderFairing", Vector2(-1.10, -1.80)],
		["StarboardShoulderFairing", Vector2(1.10, -1.80)],
	]:
		var shell := visual.get_node(sample[0]) as MeshInstance3D
		var sill_span := _mesh_vertical_span(fairing, sample[1])
		var shell_span := _mesh_vertical_span(shell, sample[1])
		joins_seated = joins_seated and sill_span.size() >= 2 and shell_span.size() >= 2
		if sill_span.size() >= 2 and shell_span.size() >= 2:
			joins_seated = joins_seated and sill_span[0] < shell_span[-1] and shell_span[0] < sill_span[-1]
	_check(joins_seated, "cockpit fairing side returns and forward transition seat into both shoulders and the nose")


func _test_arrow_cabin_opening(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var fairing := visual.get_node("CockpitSillFairing") as MeshInstance3D
	var floor := visual.get_node("CockpitInterior/CockpitFloor") as MeshInstance3D
	var floor_bounds := visual.global_transform.affine_inverse() * floor.global_transform * floor.mesh.get_aabb()
	var cabin_clear := true
	var floor_sealed := true
	# Use intersections with the final production triangles across the whole
	# usable cabin, including the seat pan, lower back and pedal well.
	for x_step in 19:
		for z_step in 27:
			var sample := Vector2(lerpf(-0.96, 0.96, float(x_step) / 18.0), lerpf(-1.94, 0.81, float(z_step) / 26.0))
			var span := _mesh_vertical_span(fairing, sample)
			cabin_clear = cabin_clear and span.size() >= 2 and span[-1] <= 1.931
			floor_sealed = floor_sealed and span.size() >= 2 and span[-1] >= floor_bounds.position.y and span[-1] <= floor_bounds.end.y
	_check(cabin_clear, "the entire Arrow cabin footprint clears actual fairing triangles above the recessed floor")
	_check(floor_sealed, "the closed cabin-well bottom overlaps the retained floor without a daylight gap")
	var faces := fairing.mesh.get_faces()
	var walls_closed := true
	for sample in 17:
		var z := lerpf(-1.93, 0.80, float(sample) / 16.0)
		for side in [-1.0, 1.0]:
			var from := fairing.transform.affine_inverse() * Vector3(0, 1.94, z)
			var to := fairing.transform.affine_inverse() * Vector3(side * 1.02, 1.94, z)
			var found := false
			for triangle in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, faces[triangle], faces[triangle + 1], faces[triangle + 2])
				if hit != null:
					found = found or absf(absf((hit as Vector3).x) - 0.99) < 0.00001
			walls_closed = walls_closed and found
	for z in [-1.97, 0.84]:
		for x_step in 17:
			var x := lerpf(-0.96, 0.96, float(x_step) / 16.0)
			var from := fairing.transform.affine_inverse() * Vector3(x, 1.94, -0.55)
			var to := fairing.transform.affine_inverse() * Vector3(x, 1.94, z + (-0.02 if z < 0 else 0.02))
			var found := false
			for triangle in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, faces[triangle], faces[triangle + 1], faces[triangle + 2])
				if hit != null:
					found = found or absf((hit as Vector3).z - z) < 0.00001
			walls_closed = walls_closed and found
	_check(walls_closed, "all four fairing inner returns close the cabin pocket below the retained pressure walls")
	var cabin := visual.get_node("CockpitInterior")
	var canopy := visual.get_node("CanopyHinge")
	var outside_faces := PackedVector3Array()
	for node: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if cabin.is_ancestor_of(node) or canopy.is_ancestor_of(node) or not node.visible or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var transform := visual.global_transform.affine_inverse() * node.global_transform
		var bounds := transform * node.mesh.get_aabb()
		if not bounds.intersects(AABB(Vector3(-0.55, 1.995, -0.48), Vector3(1.1, 1.16, 1.20))):
			continue
		for vertex: Vector3 in node.mesh.get_faces():
			outside_faces.append(transform * vertex)
	var seat_space_clear := true
	for x_step in 13:
		for z_step in 15:
			var x := lerpf(-0.55, 0.55, float(x_step) / 12.0)
			var z := lerpf(-0.48, 0.72, float(z_step) / 14.0)
			for triangle in range(0, outside_faces.size(), 3):
				seat_space_clear = seat_space_clear and Geometry3D.segment_intersects_triangle(Vector3(x, 3.15, z), Vector3(x, 1.995, z), outside_faces[triangle], outside_faces[triangle + 1], outside_faces[triangle + 2]) == null
	_check(seat_space_clear, "every exterior opaque fitting clears the complete seat, lapbelt and lower-back volume")
	var spine := visual.get_node("DorsalSurveySpine") as MeshInstance3D
	var cap_faces := spine.mesh.get_faces()
	var cap_closed := true
	for x_step in 9:
		for y_step in 9:
			var from := spine.transform.affine_inverse() * Vector3(lerpf(-0.4, 0.4, float(x_step) / 8.0), lerpf(1.95, 2.30, float(y_step) / 8.0), 0.80)
			var to := from + Vector3.BACK * 0.08
			var found := false
			for triangle in range(0, cap_faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, cap_faces[triangle], cap_faces[triangle + 1], cap_faces[triangle + 2])
				if hit != null:
					found = found or absf((spine.transform * (hit as Vector3)).z - 0.84) < 0.00001
			cap_closed = cap_closed and found
	_check(cap_closed, "the retained aft survey spine has a closed front cap behind the complete seat")
	var geometry_valid := true
	var cavity_winding := true
	var cavity_faces := [0, 0, 0, 0, 0]
	for stock: MeshInstance3D in [fairing, spine]:
		var arrays := stock.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		geometry_valid = geometry_valid and normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
		for index in vertices.size():
			geometry_valid = geometry_valid and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001 and uvs[index].is_finite()
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if stock == fairing:
				# Independent geometry directions: material normals could agree
				# with an accidentally reversed inner wall, so never trust them.
				var points := [stock.transform * vertices[a], stock.transform * vertices[b], stock.transform * vertices[c]]
				var pocket_planes: Array[Plane] = [Plane(Vector3.RIGHT, 0.99), Plane(Vector3.LEFT, 0.99), Plane(Vector3.FORWARD, 1.97), Plane(Vector3.BACK, 0.84), Plane(Vector3.DOWN, -1.93)]
				for plane_index in pocket_planes.size():
					var plane := pocket_planes[plane_index]
					if absf(plane.distance_to(points[0])) < 0.00001 and absf(plane.distance_to(points[1])) < 0.00001 and absf(plane.distance_to(points[2])) < 0.00001:
						# Godot's clockwise cross points into the material, opposite
						# the desired inner normal (-plane.normal, or +Y at floor).
						cavity_winding = cavity_winding and cross.dot(plane.normal) > 0.0
						cavity_faces[plane_index] += 1
			geometry_valid = geometry_valid and cross.dot(normals[a]) < 0.0 and cross.dot(normals[b]) < 0.0 and cross.dot(normals[c]) < 0.0
			geometry_valid = geometry_valid and absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) > 0.000000001
	_check(cavity_winding and not cavity_faces.has(0), "geometric winding points all four inner walls toward the cabin and the entire bottom upward")
	_check(geometry_valid, "both cabin shells keep finite unit normals, complete tangents, outward winding and nonsingular UVs on every triangle")


func _mesh_vertical_span(stock: MeshInstance3D, sample: Vector2, include_fittings := false) -> Array[float]:
	var heights: Array[float] = []
	var faces := stock.mesh.get_faces()
	if include_fittings:
		# Fitted inserts close the removed service-bay and sensor-roof skins.
		for name in ["SurveyServiceCovers", "SurveyServiceGasket", "FlushPassiveAperture"]:
			var child := stock.get_node_or_null(name) as MeshInstance3D
			if child == null:
				continue
			for vertex: Vector3 in child.mesh.get_faces():
				faces.append(child.transform * vertex)
	var start := stock.transform.affine_inverse() * Vector3(sample.x, 4.0, sample.y)
	var finish := stock.transform.affine_inverse() * Vector3(sample.x, 0.0, sample.y)
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			heights.append((stock.transform * (hit as Vector3)).y)
	heights.sort()
	return heights


func _test_fitted_canopy(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var hinge := visual.get_node("CanopyHinge") as Node3D
	var glass := hinge.get_node("AccessCanopyCarrier/CanopyGlass") as MeshInstance3D
	var sill := visual.get_node("CockpitSillFairing") as MeshInstance3D
	var faces := glass.mesh.get_faces()
	var relative := hinge.transform * glass.transform
	var edges := {}
	for triangle in range(0, faces.size(), 3):
		for corner in 3:
			var a := relative * faces[triangle + corner]
			var b := relative * faces[triangle + (corner + 1) % 3]
			var ka := str(a.snapped(Vector3.ONE * 0.0001))
			var kb := str(b.snapped(Vector3.ONE * 0.0001))
			if ka == kb:
				continue
			var key := ka + ":" + kb if ka < kb else kb + ":" + ka
			if not edges.has(key):
				edges[key] = {"count": 0, "a": a, "b": b}
			edges[key].count += 1
	var boundary_count := 0
	var max_gap := 0.0
	var supported := true
	for edge: Dictionary in edges.values():
		if edge.count != 1:
			continue
		boundary_count += 1
		for t in [0.0, 0.5, 1.0]:
			var point: Vector3 = edge.a.lerp(edge.b, t)
			# The cut rear edge can be coplanar with the vertical ray. Sample
			# 10 microns into the adjoining retained crown at that boundary.
			var sample := Vector2(point.x, point.z + (0.00001 if absf(point.z - 0.84) < 0.00001 else 0.0))
			var span := _mesh_vertical_span(sill, sample)
			if span.is_empty():
				supported = false
			else:
				max_gap = maxf(max_gap, absf(point.y - span[-1]))
	_check(boundary_count > 40 and supported and max_gap < 0.022,
		"every emitted open-bottom canopy perimeter edge seats on actual fairing stock within the 22 mm frame half-width (gap %.6f)" % max_gap)
	var open_bottom := true
	for x in [-0.5, 0.0, 0.5]:
		for z in [-1.3, -0.6, 0.2]:
			var heights: Array[float] = []
			for triangle in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x, 1.9, z), Vector3(x, 4.0, z),
					relative * faces[triangle], relative * faces[triangle + 1], relative * faces[triangle + 2])
				if hit != null:
					var height := (hit as Vector3).y
					if heights.is_empty() or absf(height - heights[0]) > 0.0001:
						heights.append(height)
			open_bottom = open_bottom and heights.size() == 1 and heights[0] > 3.05
	_check(open_bottom, "canopy emits only the upper roof across the occupied cabin, with no lower bubble or floor")
	var hardware_clear := true
	var minimum_hardware_clearance := INF
	for name in ["PortSideConsole", "StarboardSideConsole", "InstrumentHood"]:
		var stock := visual.get_node("CockpitInterior").find_child(name, true, false) as MeshInstance3D
		var stock_relative := visual.global_transform.affine_inverse() * stock.global_transform
		for vertex in stock.mesh.get_faces():
			var point := stock_relative * vertex
			if point.y < 2.4:
				continue
			var roof := -INF
			for triangle in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(point.x, 4.0, point.z), Vector3(point.x, 1.9, point.z),
					relative * faces[triangle], relative * faces[triangle + 1], relative * faces[triangle + 2])
				if hit != null:
					roof = maxf(roof, (hit as Vector3).y)
			minimum_hardware_clearance = minf(minimum_hardware_clearance, roof - point.y)
			hardware_clear = hardware_clear and roof - point.y > 0.02
	_check(hardware_clear, "actual retained console and instrument-hood upper vertices stay inside the glazing (minimum clearance %.4f)" % minimum_hardware_clearance)
	var frame := glass.get_node_or_null("CanopyPressureFrame") as MeshInstance3D
	_check(frame != null and frame.layers == glass.layers and frame.transform == Transform3D.IDENTITY
		and not (hinge.get_node("CanopyRearFrame") as Node3D).visible
		and not (hinge.get_node("CanopyRearPressureSeal") as Node3D).visible
		and not (hinge.get_node("PortCanopyLatchHook") as Node3D).visible
		and not (hinge.get_node("StarboardCanopyLatchHook") as Node3D).visible,
		"fitted perimeter and arches share the retained glass/hinge and replace the floating inherited rear stock")


func _test_collision_boarding_and_cameras(arrow: ArrowReconShip) -> void:
	_check(arrow.collision_layer == SHIP_LAYER, "Arrow uses canonical Ship physics layer")
	_check(arrow.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Arrow collides with world, players, and ships")
	var collisions: Array[Node] = []
	for child in arrow.get_children():
		if child is CollisionShape3D:
			collisions.append(child)
	_check(collisions.size() == 5, "Arrow retains both hull shapes and adds three bounded sole contacts")
	_check(arrow.get_node_or_null("ArrowHullCollision") is CollisionShape3D, "slender fuselage has a named collision shape")
	_check(arrow.get_node_or_null("ArrowWingCollision") is CollisionShape3D, "sensor-wing planform has a named collision shape")

	var boarding_area := arrow.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(boarding_area != null and boarding_area.get_ship() == arrow, "physical boarding area resolves the Arrow owner generically")
	_check(boarding_area != null and boarding_area.is_available(), "parked Arrow begins physically boardable")
	_check("ARROW RECON SHIP" in boarding_area.get_prompt(), "boarding prompt names the recon craft")
	_check(arrow.get_boarding_position().distance_to(boarding_area.global_position - Vector3.UP * 0.5) < 0.1, "boarding marker and interaction area align")
	var entry := arrow.get_boarding_entry_transform()
	var seat := arrow.get_pilot_seat_anchor()
	_check(entry.origin.is_finite() and seat != null and seat.global_position.is_finite(), "inherited physical entry and seat remain valid")
	_check(entry.origin.distance_to(seat.global_position) < 3.0, "boarding entry remains a short physical transition to the seat")
	_check(arrow.get_exit_transform().origin.distance_to(arrow.global_position) > 5.8, "exit marker clears the full sensor-wing collision")

	var chase := arrow.get_camera()
	_check(chase != null and chase.name == "ShipCamera", "Arrow inherits a physical chase camera")
	arrow.set_piloted(true)
	_check(chase.current, "piloting activates Arrow chase view")
	arrow.set_cockpit_view(true)
	var cockpit_camera := arrow.get_camera()
	_check(cockpit_camera != null and cockpit_camera.name == "CockpitCamera" and cockpit_camera.current, "Arrow switches to inherited physical cockpit camera")
	_check(cockpit_camera.get_parent().name == "CockpitInterior", "cockpit camera remains inside the modelled cabin")
	arrow.set_cockpit_view(false)
	arrow.set_piloted(false)

	var canopy := arrow.get_arrow_visual_root().get_node_or_null("CanopyHinge") as Node3D
	_check(canopy != null, "functional inherited canopy pivot remains intact")
	var glazing := canopy.get_node_or_null("AccessCanopyCarrier/CanopyGlass") as MeshInstance3D
	var glazing_material := glazing.get_active_material(0) as StandardMaterial3D if glazing != null else null
	_check(glazing_material == arrow.get_variant_materials().glass \
		and glazing_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
		and glazing_material.albedo_color.a < 0.5 and is_zero_approx(glazing_material.metallic) \
		and glazing_material.cull_mode == BaseMaterial3D.CULL_BACK,
		"the recon canopy exposes its physical cockpit through dielectric glazing")
	_check(glazing != null and glazing.layers == 1 << 18 \
		and not cockpit_camera.get_cull_mask_value(19),
		"exterior glazing retains the existing unobstructed pilot-camera layer policy")
	var port_hinge_mount := arrow.get_arrow_visual_root().get_node_or_null("PortCanopyHingeMount") as MeshInstance3D
	var starboard_hinge_mount := arrow.get_arrow_visual_root().get_node_or_null("StarboardCanopyHingeMount") as MeshInstance3D
	_check(
		port_hinge_mount != null and starboard_hinge_mount != null
		and port_hinge_mount.position.x < 0.0 and starboard_hinge_mount.position.x > 0.0,
		"Arrow preserves both explicitly named canopy hinge mounts"
	)
	_check(
		canopy.get_node_or_null("PortCanopyTopRail") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyTopRail") is MeshInstance3D
		and canopy.get_node_or_null("PortCanopyNoseFrame") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyNoseFrame") is MeshInstance3D,
		"Arrow preserves and restyles both named canopy sides"
	)
	arrow.set_canopy_open(true, 0.0)
	await process_frame
	_check(arrow.is_canopy_open() and canopy.rotation.x > 0.8, "Arrow canopy opens through the common physical lifecycle")
	arrow.set_canopy_open(false, 0.0)
	await process_frame
	_check(not arrow.is_canopy_open() and absf(canopy.rotation.x) < 0.01, "Arrow canopy reseals without rebuilding its pivot")


func _test_engine_weapon_and_lifecycle(arrow: ArrowReconShip) -> void:
	var airframe_batch := arrow.get_arrow_visual_root().get_node("OpaqueEnvelopeShadowBatch") as MeshInstance3D
	var airframe_mesh := airframe_batch.mesh
	var airframe_sources := arrow._airframe_shadow_sources.duplicate()
	var marking_costs := ShipSurfaceDetail.get_surface_marking_costs(arrow.get_arrow_visual_root())
	var excluded_casts := {}
	for candidate in arrow.get_arrow_visual_root().find_children("*", "GeometryInstance3D", true, false):
		if ShipSurfaceDetail.is_surface_marking_patch(candidate):
			continue
		if candidate != airframe_batch and not (candidate is MeshInstance3D and airframe_sources.has(candidate)):
			excluded_casts[candidate] = (candidate as GeometryInstance3D).cast_shadow
	var rib_batch := arrow.get_arrow_visual_root().get_node_or_null(
		"WingRootRibBatch"
	) as MultiMeshInstance3D
	var rib_batch_identity := rib_batch.get_instance_id() if rib_batch != null else 0
	var entry_target := arrow.get_entry_heat_target()
	var entry_overlay := entry_target.get_overlay() if entry_target != null else null
	var entry_material := entry_target.get_material() if entry_target != null else null
	var entry_mesh := entry_overlay.mesh if entry_overlay != null else null
	var entry_shader := entry_material.shader if entry_material != null else null
	var entry_target_identity := (
		entry_target.get_instance_id() if entry_target != null else 0
	)
	_test_root.remove_child(arrow)
	await process_frame
	_check(
		arrow.get_entry_heat_target() == entry_target
		and entry_target != null
		and entry_target.get_parent() == arrow.get_arrow_visual_root()
		and entry_target.get_material() == entry_material,
		"whole-Arrow detach retains the same passive target, visual-root parent, and exclusive material"
	)
	_test_root.add_child(arrow)
	await process_frame
	await physics_frame
	_check(
		arrow.get_entry_heat_target() == entry_target
		and entry_target != null
		and entry_target.get_instance_id() == entry_target_identity
		and bool(arrow.get_arrow_audit_report().valid),
		"whole-Arrow re-entry restores no target and preserves the sole attachment identity"
	)
	var fired_events: Array[Dictionary] = []
	arrow.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		fired_events.append({"origin": origin, "direction": direction})
	)
	arrow.engine_start_time = 0.03
	arrow.weapon_cooldown = 0.05
	arrow.set_piloted(true)
	arrow.request_engine_start()
	for index in 8:
		await physics_frame
	var telemetry := arrow.get_telemetry()
	_check(str(telemetry.engine_state) == "ONLINE", "Arrow completes the inherited engine-start lifecycle")
	_check((arrow.get("_cockpit_readout") as Label3D).text.contains("ONLINE"), "recessed flight display follows real engine startup")
	_check(str(telemetry.ship_id) == "arrow_provisional" and str(telemetry.role) == "Reconnaissance ship", "telemetry carries Arrow identity and role")
	var plumes: Array[MeshInstance3D] = []
	var port_plume := arrow.get_arrow_visual_root().get_node_or_null("PortEnginePlume") as MeshInstance3D
	var starboard_plume := arrow.get_arrow_visual_root().get_node_or_null("StarboardEnginePlume") as MeshInstance3D
	if port_plume != null:
		plumes.append(port_plume)
	if starboard_plume != null:
		plumes.append(starboard_plume)
	_check(plumes.size() == 2, "Arrow has exactly two efficient engine plumes")
	_check(
		plumes.size() == 2
		and (plumes[0] as MeshInstance3D).visible
		and (plumes[1] as MeshInstance3D).visible,
		"both twin-engine plumes activate online"
	)

	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired_events.size() == 1, "Arrow emits one light pulse from real flight input")
	if not fired_events.is_empty():
		var first_origin: Vector3 = fired_events[0].origin
		_check(first_origin.distance_to(arrow.to_global(Vector3(-1.05, 0.72, -5.7))) < 0.1, "first pulse originates from repositioned port muzzle")
		_check((fired_events[0].direction as Vector3).dot(-arrow.global_basis.z) > 0.9, "light pulse fires along the visible nose axis")
	for index in 5:
		await physics_frame
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired_events.size() == 2, "second pulse alternates after cooldown")
	if fired_events.size() >= 2:
		var second_origin: Vector3 = fired_events[1].origin
		_check(second_origin.distance_to(arrow.to_global(Vector3(1.05, 0.72, -5.7))) < 0.1, "second pulse originates from repositioned starboard muzzle")

	arrow.set_piloted(false)
	arrow.request_engine_stop()
	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	for index in 15:
		await physics_frame
	_check(not airframe_batch.is_visible_in_tree() and not (airframe_sources[0] as MeshInstance3D).is_visible_in_tree(), "destruction hides both the airframe shadow batch and its retained colour sources")
	_check(arrow.is_destroyed(), "Arrow participates in inherited damage/destruction lifecycle")
	_check(arrow.collision_layer == 0 and arrow.collision_mask == 0, "destroyed Arrow disables physical collision")
	_check(
		entry_target != null
		and arrow.get_entry_heat_target() == entry_target
		and not arrow.get_arrow_visual_root().visible,
		"destroyed-hull hiding applies to the attached target through the stable visual root"
	)
	var reset_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(24.0)), Vector3(12, 3, -18))
	arrow.reset_for_reuse(reset_transform)
	await physics_frame
	await physics_frame
	_check(not arrow.is_destroyed() and arrow.is_boardable(), "Arrow resets as the same reusable physical ship")
	_check(arrow.global_transform.origin.is_equal_approx(reset_transform.origin), "Arrow reuse restores the requested berth position")
	_check(arrow.collision_layer == SHIP_LAYER and arrow.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Arrow reuse restores canonical collision")
	_check(arrow.get_arrow_visual_root().visible, "Arrow variant visual is restored after reuse")
	_check(arrow.get_escape_pod_count() == 2, "both visible escape pods survive the reuse lifecycle")
	_check(
		rib_batch_identity != 0
		and arrow.get_arrow_visual_root().get_node_or_null("WingRootRibBatch") == rib_batch
		and rib_batch.get_instance_id() == rib_batch_identity,
		"damage/reset lifecycle preserves the same rib batch and never duplicates it"
	)
	_check(
		entry_target_identity != 0
		and arrow.get_entry_heat_target() == entry_target
		and entry_target.get_instance_id() == entry_target_identity
		and entry_target.get_overlay().mesh == entry_mesh
		and entry_target.get_material() == entry_material
		and entry_target.get_material().shader == entry_shader
		and float(entry_target.get_material().get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0
		and _count_named(
			arrow.get_arrow_visual_root(), "PlanetaryEntryHeatTarget"
		) == 1,
		"damage/reset preserves one exact target, shared resources, exclusive material, and zero baseline"
	)

	_check(ShipSurfaceDetail.get_surface_marking_costs(arrow.get_arrow_visual_root()) == marking_costs,
		"detach/re-entry restores the same marking allocation without retaining retired patches")
	var excluded_unchanged := true
	for candidate: GeometryInstance3D in excluded_casts:
		excluded_unchanged = excluded_unchanged and candidate.cast_shadow == int(excluded_casts[candidate])
	_check(airframe_batch == arrow.get_arrow_visual_root().get_node("OpaqueEnvelopeShadowBatch") \
		and airframe_batch.mesh == airframe_mesh and airframe_batch.is_visible_in_tree() \
		and arrow._airframe_shadow_sources == airframe_sources and excluded_unchanged \
		and _count_named(arrow.get_arrow_visual_root(), "OpaqueEnvelopeShadowBatch") == 1,
		"detach/re-entry and damage/reset retain one batch and its sources while every excluded renderer keeps its shadow behavior")
	_test_airframe_shadow_batch(arrow)


func _test_cleanup(arrow: ArrowReconShip) -> void:
	var arrow_reference: WeakRef = weakref(arrow)
	var entry_target_reference: WeakRef = weakref(arrow.get_entry_heat_target())
	var pod_reference: WeakRef = weakref(arrow.get_escape_pod(&"port"))
	var boarding_reference: WeakRef = weakref(arrow.get_node_or_null("ShipBoardingArea"))
	arrow.queue_free()
	arrow = null
	await process_frame
	await physics_frame
	await process_frame
	_check(arrow_reference.get_ref() == null, "Arrow root cleans up without retention")
	_check(entry_target_reference.get_ref() == null, "entry-heat target cleans up with the Arrow visual root")
	_check(pod_reference.get_ref() == null, "escape pod hierarchy cleans up with Arrow")
	_check(boarding_reference.get_ref() == null, "boarding component cleans up with Arrow")
	_test_root.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _count_named(search_root: Node, node_name: String) -> int:
	var count := 1 if search_root.name == node_name else 0
	for child in search_root.get_children():
		count += _count_named(child, node_name)
	return count


func _report_has_error(report: Dictionary, fragment: String) -> bool:
	for error in report.get("errors", PackedStringArray()):
		if fragment in str(error):
			return true
	return false


func _collect_meshes_named(search_root: Node, node_name: String, output: Array[MeshInstance3D]) -> void:
	if search_root is MeshInstance3D and search_root.name == node_name:
		output.append(search_root as MeshInstance3D)
	for child in search_root.get_children():
		_collect_meshes_named(child, node_name, output)


func _finish() -> void:
	Input.action_release("fire")
	if _failures.is_empty():
		print("ARROW_RECON_SHIP_TEST_OK")
		quit(0)
	else:
		print("ARROW_RECON_SHIP_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _add_access_mesh_probe(parent: Node3D, ship: ArrowReconShip, corridor: AABB,
		mesh: Mesh, world_transform: Transform3D, source_name: StringName) -> int:
	if not corridor.intersects(ship.global_transform.affine_inverse() * world_transform * mesh.get_aabb()):
		return 0
	var body := StaticBody3D.new()
	body.name = source_name
	body.collision_layer = 1 << 25
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = world_transform
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	return 1


func _sample_access_motion(ship: ArrowReconShip, player: PlayerController,
		skeleton: Skeleton3D, capsule_query: PhysicsShapeQueryParameters3D,
		body_query: PhysicsShapeQueryParameters3D, state: int) -> Dictionary:
	var hits := {}
	var frames := 0
	var capsule_frames := 0
	while int(player.get("_embodiment_state")) == state and frames < 125:
		player.call("_update_embodiment", 2.0 / 120.0)
		player.get_motion_animation_player().advance(2.0 / 120.0)
		skeleton.force_update_all_bone_transforms()
		frames += 1
		# Standing clearance ends at the chair approach; the authored seated
		# chest/head probes continue for every frame, including final settling.
		if ship.to_local(player.global_position).x <= -1.20:
			capsule_frames += 1
			capsule_query.transform = Transform3D(ship.global_basis,
				player.global_position + ship.global_basis.y * 0.97)
			for hit in player.get_world_3d().direct_space_state.intersect_shape(capsule_query, 32):
				hits[str(hit.collider.name) + "/capsule"] = str(ship.to_local(player.global_position))
		for bone_name in ["chest", "head"]:
			var bone := skeleton.find_bone(bone_name)
			body_query.transform = Transform3D(Basis.IDENTITY,
				(skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin)
			for hit in player.get_world_3d().direct_space_state.intersect_shape(body_query, 32):
				hits[str(hit.collider.name) + "/" + bone_name] = str(ship.to_local(player.global_position))
	return {"frames": frames, "capsule_frames": capsule_frames, "hits": hits}
