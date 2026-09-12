extends SceneTree

## Focused renderer contract for the base defender's two immutable gun-housing
## shells. Weapon, collision, damage and reuse authority remain outside the
## presentation-only batch.

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	root.add_child(opponent)
	await process_frame

	var visual := opponent.get_node_or_null(^"RangeInterceptorVisual") as Node3D
	var batch := visual.get_node_or_null(^"GunHousingBatch") as MultiMeshInstance3D \
		if visual != null else null
	var multi := batch.multimesh if batch != null else null
	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array \
		if batch != null else []
	var names := batch.get_meta(&"authored_visual_names", PackedStringArray()) as PackedStringArray \
		if batch != null else PackedStringArray()
	var expected_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var expected_transforms: Array[Transform3D] = [
		Transform3D(expected_basis, Vector3(-2.65, -0.08, -4.35)),
		Transform3D(expected_basis, Vector3(2.65, -0.08, -4.35)),
	]
	var expected_bounds := AABB()
	if multi != null and multi.mesh != null:
		for index in expected_transforms.size():
			var instance_bounds := (expected_transforms[index] * multi.mesh.get_aabb()).abs()
			expected_bounds = instance_bounds if index == 0 else expected_bounds.merge(instance_bounds)
	var material := multi.mesh.surface_get_material(0) as StandardMaterial3D \
		if multi != null and multi.mesh != null else null
	_check(
		multi != null
			and multi.transform_format == MultiMesh.TRANSFORM_3D
			and multi.instance_count == 2
			and multi.visible_instance_count == -1
			and multi.mesh.get_surface_count() == 1,
		"the two gun-housing shells use one bounded 3D MultiMesh submission"
	)
	_check(
		transforms == expected_transforms
			and multi.custom_aabb.is_equal_approx(expected_bounds)
			and names == PackedStringArray(["PortGunHousing", "StarboardGunHousing"]),
		"the batch preserves both exact transforms, culling bounds and semantic identities"
	)
	_check(
		batch.layers == 1
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and material != null
			and material.albedo_color.is_equal_approx(RangeOpponent.FRAME_DARK)
			and is_equal_approx(material.metallic, 0.65)
			and is_equal_approx(material.roughness, 0.43)
			and bool(batch.get_meta(&"presentation_only", false))
			and batch.get_child_count() == 0,
		"material, render layers, shadow policy and authority-free ownership remain exact"
	)

	# The one surface contains a real open lip, a recessed bore, and a wider
	# mounting shoulder, with outward winding and complete tangent-space data.
	var arrays := multi.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var geometry_valid := vertices.size() == 1344 and normals.size() == vertices.size() \
		and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	var bore_vertices := 0
	var shoulder_vertices := 0
	for index in vertices.size():
		var vertex := vertices[index]
		var radius := Vector2(vertex.x, vertex.z).length()
		if vertex.y < -0.25 and is_equal_approx(radius, 0.37):
			bore_vertices += 1
		if is_equal_approx(radius, 0.44):
			shoulder_vertices += 1
		geometry_valid = geometry_valid and vertex.is_finite() and normals[index].is_normalized()
		var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
		geometry_valid = geometry_valid and tangent.is_finite() and tangent.is_normalized() \
			and absf(tangent.dot(normals[index])) < 0.001 \
			and is_equal_approx(absf(tangents[index * 4 + 3]), 1.0)
	for index in range(0, vertices.size(), 3):
		var clockwise := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
		geometry_valid = geometry_valid and clockwise.dot(normals[index]) > 0.00001
		var uv_edge_a := uvs[index + 1] - uvs[index]
		var uv_edge_b := uvs[index + 2] - uvs[index]
		geometry_valid = geometry_valid and absf(uv_edge_a.cross(uv_edge_b)) > 0.000001

	_check(geometry_valid and bore_vertices > 0 and shoulder_vertices > 0,
		"machined shell retains one modest surface with open lens bore, shoulder, outward winding, UVs and tangents")

	# Read the actual inward-facing mesh rings, including the front chamfer.
	# The full charge sphere must clear every axial section of the aperture,
	# including between vertices and halfway around each faceted bore panel.
	var bore_rings: Dictionary = {}
	for index in vertices.size():
		var vertex := vertices[index]
		var radial := Vector3(vertex.x, 0.0, vertex.z).normalized()
		if normals[index].dot(radial) < -0.01:
			var radius := Vector2(vertex.x, vertex.z).length()
			bore_rings[vertex.y] = minf(radius, float(bore_rings.get(vertex.y, INF)))
	var bore_stations := bore_rings.keys()
	bore_stations.sort()
	_check(bore_stations.size() == 3,
		"the open bore has a continuous inner wall and a chamfered front edge")
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_process(false)
	opponent.set_physics_process(false)
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(0, 0, -100)
	opponent.set_target(target)
	var fired_origins: Array[Vector3] = []
	opponent.projectile_fired.connect(func(origin: Vector3, _direction: Vector3): fired_origins.append(origin))
	for pattern: StringName in [RangeOpponent.FIRE_PATTERN_SINGLE_SHOT,
		RangeOpponent.FIRE_PATTERN_SHORT_BURST, RangeOpponent.FIRE_PATTERN_SPACED_SUPPRESSION]:
		opponent.configure_firing_pattern(pattern)
		opponent.set("_cooldown_remaining", 0.0)
		opponent.call("_update_weapon", target.position, Vector3.FORWARD, 100.0, 0.0)
		var charge_clear := true
		var first_radius := 0.0
		var peak_radius := 0.0
		for step in 17:
			if step > 0:
				var delta := opponent.telegraph_time / 16.0 - (0.00001 if step == 16 else 0.0)
				opponent.call("_update_weapon", target.position, Vector3.FORWARD, 100.0, delta)
			# Sample the upper sine envelope at every real charging timestep.
			opponent.set("_elapsed", PI / 68.0)
			opponent.call("_update_presentation", 0.0)
			var lenses: Array = opponent.get("_warning_lenses")
			for side in lenses.size():
				var lens := lenses[side] as MeshInstance3D
				var radius := (lens.mesh as SphereMesh).radius * lens.scale.x
				var local_centre := expected_transforms[side].affine_inverse() * lens.position
				charge_clear = charge_clear and lens.visible and local_centre.y - radius < float(bore_stations[0])
				charge_clear = charge_clear and local_centre.y + radius < float(bore_stations[-1])
				for ring_index in bore_stations.size() - 1:
					for sample in 33:
						var fraction := float(sample) / 32.0
						var axial := lerpf(float(bore_stations[ring_index]), float(bore_stations[ring_index + 1]), fraction)
						var wall_radius := lerpf(float(bore_rings[bore_stations[ring_index]]), float(bore_rings[bore_stations[ring_index + 1]]), fraction) * cos(PI / 28.0)
						var sphere_section := sqrt(maxf(0.0, radius * radius - pow(axial - local_centre.y, 2)))
						charge_clear = charge_clear and sphere_section < wall_radius
				if step == 0:
					first_radius = maxf(first_radius, radius)
				if step == 16:
					peak_radius = maxf(peak_radius, radius)
		_check(charge_clear and peak_radius > first_radius * 1.5,
			"%s charge grows visibly through its full cycle without intersecting the bore" % pattern)
		var before_fire := fired_origins.size()
		opponent.call("_update_weapon", target.position, Vector3.FORWARD, 100.0, 0.001)
		_check(fired_origins.size() == before_fire + 1
			and fired_origins[-1] in [Vector3(-2.65, -0.08, -5.03), Vector3(2.65, -0.08, -5.03)],
			"%s still dispatches from an unchanged authoritative muzzle after charging" % pattern)
	target.queue_free()
	opponent.deactivate()

	var back_wall_vertices := 0
	for index in vertices.size():
		if is_equal_approx(vertices[index].y, -0.25) and normals[index].dot(Vector3.DOWN) > 0.9999:
			back_wall_vertices += 1
	var fixed_lenses := visual.get_node(^"ChargeLensBatch") as MultiMeshInstance3D
	var lens_seated := back_wall_vertices == 84
	for side in 2:
		var fixed_bounds: AABB = (expected_transforms[side].affine_inverse()
			* (fixed_lenses.get_meta(&"authored_instance_transforms") as Array)[side] * fixed_lenses.multimesh.mesh.get_aabb()).abs()
		lens_seated = lens_seated and fixed_bounds.position.y > -0.66 and fixed_bounds.end.y < -0.25
	_check(lens_seated,
		"a complete back wall closes the cavity behind both unchanged recessed fixed lenses")

	var ordinary_housings := 0
	for child in visual.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and (
			mesh_instance.position.is_equal_approx(Vector3(-2.65, -0.08, -4.35))
				or mesh_instance.position.is_equal_approx(Vector3(2.65, -0.08, -4.35))
		):
			ordinary_housings += 1
	_check(ordinary_housings == 0, "the retired ordinary housing renderers do not remain alongside the batch")

	var colliders := opponent.find_children("*", "CollisionShape3D", false, false)
	_check(
		colliders.size() == 7
			and opponent.get_node_or_null(^"PortMuzzle") is Marker3D
			and opponent.get_node_or_null(^"StarboardMuzzle") is Marker3D,
		"all seven hull colliders and both authoritative weapon muzzles remain independent"
	)

	var activated := opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	var maximum_health := opponent.get_maximum_health()
	opponent.apply_damage(maximum_health * 0.7, opponent.global_position)
	var smoke := opponent.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var damaged_and_reused := opponent.is_active() and smoke != null and smoke.emitting
	opponent.deactivate()
	activated = opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(-3.0, 1.0, 6.0)))
	_check(
		damaged_and_reused
			and bool(activated.get("accepted", false))
			and opponent.is_active()
			and is_equal_approx(opponent.get_health(), maximum_health)
			and smoke != null
			and not smoke.emitting
			and batch.visible,
		"staged damage and deactivate/reactivate reuse remain intact around the visual batch"
	)

	opponent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RANGE_OPPONENT_GUN_HOUSING_MULTIMESH_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
