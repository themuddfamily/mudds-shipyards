extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var first := Hauler.new()
	var second := Hauler.new()
	root.add_child(first)
	root.add_child(second)
	await process_frame

	var first_hull := _hull(first)
	var second_hull := _hull(second)
	_check(
		first_hull != null and second_hull != null
			and first_hull != second_hull
			and first_hull.mesh == second_hull.mesh
			and first_hull.material_override == second_hull.material_override,
		"two production haulers retain separate hull renderers backed by one immutable recipe"
	)
	var material := first_hull.material_override as StandardMaterial3D \
		if first_hull != null else null
	_check(
		first_hull != null
			and first_hull.mesh is ArrayMesh
			and first_hull.mesh.get_aabb().is_equal_approx(AABB(-Hauler.HULL_SIZE * 0.5, Hauler.HULL_SIZE))
			and _port_aperture_is_open(first_hull, Hauler.HULL_SIZE)
			and bool(first_hull.mesh.get_meta(&"closed_aperture_reveals", false))
			and first_hull.transform.is_equal_approx(Transform3D.IDENTITY)
			and first_hull.visible
			and first_hull.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and first_hull.layers == 1
			and first_hull.get_child_count() == 0
			and first_hull.get_script() == null
			and not first_hull.mesh.resource_local_to_scene
			and material != null
			and material.albedo_color.is_equal_approx(Hauler.HULL_COLOR)
			and is_equal_approx(material.metallic, 0.12)
			and is_equal_approx(material.roughness, 0.72)
			and not material.resource_local_to_scene,
		"sharing preserves the IndustrialHull outer silhouette, opens the bounded port route, and retains its material and renderer policy"
	)
	_check(
		_hull(second).mesh.get_surface_count() == 1
			and _hull(first).mesh.get_aabb().is_equal_approx(_hull(second).mesh.get_aabb()),
		"both visible hull copies retain the exact one-surface geometry"
	)
	var first_pod := _cargo_pod(first)
	var second_pod := _cargo_pod(second)
	var pod_material := first_pod.material_override as StandardMaterial3D \
		if first_pod != null else null
	_check(
		first_pod != null and second_pod != null
			and first_pod != second_pod
			and first_pod.mesh == second_pod.mesh
			and first_pod.material_override == second_pod.material_override
			and first_pod.mesh is ArrayMesh
			and first_pod.mesh.get_aabb().is_equal_approx(AABB(
				-Hauler.CARGO_POD_SIZE * 0.5, Hauler.CARGO_POD_SIZE
			))
			and first_pod.position.is_equal_approx(Hauler.CARGO_POD_POSITION)
			and _port_aperture_is_open(first_pod, Hauler.CARGO_POD_SIZE)
			and bool(first_pod.mesh.get_meta(&"closed_aperture_reveals", false))
			and first_pod.visible
			and first_pod.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and first_pod.layers == 1
			and not first_pod.mesh.resource_local_to_scene
			and pod_material != null
			and pod_material.albedo_color.is_equal_approx(Hauler.CARGO_COLOR)
			and is_equal_approx(pod_material.metallic, 0.12)
			and is_equal_approx(pod_material.roughness, 0.62)
			and not pod_material.resource_local_to_scene,
		"two production haulers retain exact cargo-pod bounds and an aligned port opening backed by one immutable geometry and paint recipe"
	)
	_check(
		_cabin_owns_forward_pod_bulkhead(first, first_pod),
		"the cabin fully covers the forward pod perimeter without a competing coplanar cap"
	)
	_check(
		first.get_cockpit_seat_anchor() != null
			and second.get_cockpit_seat_anchor() != null
			and first.get_boarding_marker() != null
			and second.get_boarding_marker() != null
			and first.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and second.get_cargo_transfer_anchors().size() == Hauler.CARGO_CAPACITY
			and first.get_cargo_hold_root() != null
			and second.get_cargo_hold_root() != null,
		"cockpit, boarding and the cargo-access anchor bridge remain per craft"
	)
	# Clearance belongs to the active view; parked fleet cameras do no boundary work.
	first.set_piloted(true)
	var cockpit_view := first.get_cockpit_quality_report()
	var chase_view := first.get_chase_camera_self_hull_boundary_report()
	_check(
		bool(cockpit_view.get("forward_sight_clear", false))
			and int(cockpit_view.get("opaque_obstruction_count", -1)) == 0
			and int(cockpit_view.get("sight_sample_count", 0)) == 5
			and bool(chase_view.get("valid", false))
			and int(chase_view.get("sample_count", 0)) == 5,
		"production cockpit sight rays and chase-camera near-plane samples remain clear of opaque self-geometry"
	)
	var first_audit := first.get_audit_report()
	var second_audit := second.get_audit_report()
	_check(
		bool(first_audit.get("valid", false))
			and bool(second_audit.get("valid", false))
			and bool(first.get_landing_collision_report().get("valid", false))
			and bool(second.get_landing_collision_report().get("valid", false))
			and not bool(first_audit.get("cargo_transfer_authority", true))
			and not bool(second_audit.get("cargo_transfer_authority", true))
			and not bool(first_audit.get("network_authority", true))
			and not bool(second_audit.get("network_authority", true))
			and first.get_crew_role_authority() == null
			and second.get_crew_role_authority() == null,
		"sharing leaves collision, component lifecycle and gameplay authority unchanged"
	)
	await _check_cabin_finish_reuse(first, second)

	first.queue_free()
	second.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"both craft detach cleanly while immutable presentation resources remain process-owned"
	)

	if _failures.is_empty():
		print("CINDER_CARGO_HULL_RESOURCE_SHARING: hull and cargo-pod immutable recipes are shared across two local renderers")
		print("PASS cinder_cargo_hauler_hull_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_cabin_finish_reuse(first: CinderCargoHauler, second: CinderCargoHauler) -> void:
	var finishes := _cabin_finishes(first)
	var other_finishes := _cabin_finishes(second)
	var shared := finishes.size() == 7 and not finishes.has(null)
	if shared:
		for index in 7:
			shared = shared and finishes[index] == finishes[0 if index < 3 else 3]
		shared = shared and finishes[0] != finishes[3]
	_check(shared, "seven authored cabin pieces retain exactly two immutable finishes")
	var expected_recipes := true
	for index in finishes.size():
		var expected := StandardMaterial3D.new()
		expected.albedo_color = Hauler.HULL_COLOR if index < 3 else Hauler.ACCENT_COLOR
		expected.metallic = 0.42
		expected.roughness = 0.62
		expected.cull_mode = BaseMaterial3D.CULL_DISABLED
		expected.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		expected.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		expected.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		expected_recipes = expected_recipes and _finish_recipe(finishes[index]) == _finish_recipe(expected)
	_check(shared and expected_recipes, "both cabin finishes retain their complete authored material recipes")
	_check(shared and other_finishes.size() == 7 and not other_finishes.has(null)
		and finishes[0] != other_finishes[0] and finishes[3] != other_finishes[3],
		"each hauler owns separate cabin finishes without a cross-craft material cache")
	var recipes: Array[Dictionary] = []
	for finish in finishes + other_finishes:
		recipes.append(_finish_recipe(finish))
	var geometry := [_cabin_geometry(first), _cabin_geometry(second)]
	var first_hull := float(first.get_telemetry().get("hull", 0.0))
	var second_hull := float(second.get_telemetry().get("hull", 0.0))
	first.apply_damage(1.0)
	await process_frame
	var after := _cabin_finishes(first) + _cabin_finishes(second)
	var unchanged := after == finishes + other_finishes
	for index in after.size():
		unchanged = unchanged and _finish_recipe(after[index]) == recipes[index]
	_check(unchanged and float(first.get_telemetry().get("hull", 0.0)) < first_hull
		and is_equal_approx(float(second.get_telemetry().get("hull", 0.0)), second_hull),
		"real damage changes only its craft's health and leaves both immutable cabin recipes intact")
	_check(geometry == [_cabin_geometry(first), _cabin_geometry(second)],
		"finish reuse and real damage preserve cabin mesh buffers and all local placements")


func _cabin_finishes(craft: CinderCargoHauler) -> Array[Material]:
	var cabin := craft.get_cargo_cabin_root()
	var out: Array[Material] = []
	for piece_name in ["CabinCeiling", "CabinStarboardWall"]:
		# Resolve the authored finish even if the existing fitout pass folded it.
		var piece := ShipFitoutBatch.find_authored_piece(cabin, piece_name)
		out.append(piece.get("material_override") as Material)
	for piece_name in ["CabinEndWallBatch", "CrewSeatBaseBatch", "CrewSeatBackBatch", "CrewConsoleBatch", "LoadmasterStatusPanel"]:
		var piece := cabin.get_node_or_null(NodePath(piece_name)) as GeometryInstance3D
		out.append(piece.material_override if piece != null else null)
	return out


func _finish_recipe(finish: Material) -> Dictionary:
	var out: Dictionary = {}
	if finish == null:
		return out
	for property: Dictionary in finish.get_property_list():
		var property_name := String(property.name)
		if int(property.usage) & PROPERTY_USAGE_STORAGE and not property_name.begins_with("resource_"):
			out[property_name] = finish.get(property_name)
	return out


func _cabin_geometry(craft: CinderCargoHauler) -> PackedByteArray:
	var rows: Array = []
	for node in craft.get_cargo_cabin_root().find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var placements: Array[Transform3D] = []
		if node is MultiMeshInstance3D:
			var multi := (node as MultiMeshInstance3D).multimesh
			mesh = multi.mesh
			for index in multi.instance_count:
				placements.append(multi.get_instance_transform(index))
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		var surfaces: Array = []
		if mesh != null:
			for index in mesh.get_surface_count():
				surfaces.append(mesh.surface_get_arrays(index))
		rows.append([node.name, node.transform, surfaces, placements])
	return var_to_bytes(rows)


func _hull(craft: CinderCargoHauler) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"IndustrialHull") as MeshInstance3D \
		if visual != null else null


func _cargo_pod(craft: CinderCargoHauler) -> MeshInstance3D:
	var visual := craft.get_variant_visual_root()
	return visual.get_node_or_null(^"CargoPod") as MeshInstance3D \
		if visual != null else null


func _port_aperture_is_open(renderer: MeshInstance3D, expected_size: Vector3) -> bool:
	if renderer == null or renderer.mesh == null or renderer.mesh.get_surface_count() != 1:
		return false
	var arrays := renderer.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if vertices.is_empty() or indices.size() < 66 or indices.size() % 3 != 0:
		return false
	var left_x := -expected_size.x * 0.5
	for triangle_offset in range(0, indices.size(), 3):
		var a := vertices[indices[triangle_offset]] + renderer.position
		var b := vertices[indices[triangle_offset + 1]] + renderer.position
		var c := vertices[indices[triangle_offset + 2]] + renderer.position
		if is_equal_approx(a.x, left_x) \
				and is_equal_approx(b.x, left_x) \
				and is_equal_approx(c.x, left_x):
			var centre := (a + b + c) / 3.0
			if centre.y > Hauler.PORT_APERTURE_Y_MIN \
					and centre.y < Hauler.PORT_APERTURE_Y_MAX \
					and centre.z > Hauler.PORT_APERTURE_Z_MIN \
					and centre.z < Hauler.PORT_APERTURE_Z_MAX:
				return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _cabin_owns_forward_pod_bulkhead(craft: CinderCargoHauler, pod: MeshInstance3D) -> bool:
	var wall := craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin/CabinEndWallBatch") as MultiMeshInstance3D
	if pod == null or wall == null or wall.multimesh == null:
		return false
	var stock := wall.multimesh.mesh as BoxMesh
	var transforms: Array = wall.get_meta(&"authored_instance_transforms", [])
	if stock == null or transforms.size() != 2:
		return false
	var forward_wall: Transform3D = transforms[0]
	var wall_bounds := forward_wall * stock.get_aabb()
	var cap_z := Hauler.CARGO_POD_POSITION.z - Hauler.CARGO_POD_SIZE.z * 0.5
	if not is_equal_approx(wall_bounds.position.z, cap_z):
		return false
	var vertices := pod.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var faces := pod.mesh.get_faces()
	var perimeter_points := 0
	for point in vertices:
		var craft_point := pod.transform * point
		if is_equal_approx(craft_point.z, cap_z):
			perimeter_points += 1
			if craft_point.x < wall_bounds.position.x or craft_point.x > wall_bounds.end.x \
					or craft_point.y < wall_bounds.position.y or craft_point.y > wall_bounds.end.y:
				return false
	for triangle in range(0, faces.size(), 3):
		if is_equal_approx((pod.transform * faces[triangle]).z, cap_z) \
				and is_equal_approx((pod.transform * faces[triangle + 1]).z, cap_z) \
				and is_equal_approx((pod.transform * faces[triangle + 2]).z, cap_z):
			return false
	return perimeter_points >= 12
