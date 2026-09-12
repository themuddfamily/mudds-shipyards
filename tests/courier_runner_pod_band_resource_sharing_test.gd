extends SceneTree

const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var first := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	var second := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	host.add_child(first)
	host.add_child(second)
	await process_frame

	var bow := first.get_node(^"ContractCourierVisual/BluntNose") as MeshInstance3D
	var bow_bounds := bow.transform * bow.mesh.get_aabb()
	_check(bow_bounds.position.is_equal_approx(Vector3(-1.1,-0.85,-4.7))
		and bow_bounds.end.is_equal_approx(Vector3(1.1,0.85,-2.0)),
		"formed courier bow retains its nose station, beam and pressure-body join envelope")
	var stations := {}
	var bow_faces := bow.mesh.get_faces()
	for point in bow_faces:
		var z := snappedf(point.z, 0.0001)
		var extent: Vector2 = stations.get(z, Vector2.ZERO)
		stations[z] = extent.max(Vector2(absf(point.x), absf(point.y)))
	var ordered := stations.keys()
	ordered.sort()
	var tip: Vector2 = stations[ordered[0]]
	var shoulder: Vector2 = stations[ordered[ordered.size()/2]]
	_check(ordered.size() >= 12 and tip.x < 0.15 and tip.y < 0.15
		and shoulder.x > 0.65 and shoulder.y > 0.48,
		"the actual bow rounds in plan and profile into a small nose face instead of a freight slab")
	_check(bow_faces.size()/3 <= 1800 and bow.mesh.get_surface_count() == 1,
		"rounded forebody stays bounded to one existing renderer and fewer than 1800 triangles")

	var canopy := first.get_node(^"ContractCourierVisual/Canopy") as MeshInstance3D
	_check(canopy.mesh is ArrayMesh and _upperworks_surface_is_valid(canopy.mesh),
		"fitted courier cab has nondegenerate glazing with usable UVs and tangent frames")
	var fitted := first.get_node(^"ContractCourierVisual/FittedArmourAndServices") as MeshInstance3D
	_check(fitted.mesh.get_surface_count() == 3,
		"courier pressure frames and formed roof covers retain three opaque material batches")
	var collar := first._courier_upper_mesh([
		Vector4(-1.0,0.8,0.5,1.0), Vector4(1.0,0.8,0.5,1.0),
	],0.5,null)
	_check(_upperworks_surface_is_valid(collar, true),
		"closed upperworks fittings face out of their pressure volume with valid texture frames")

	_check_cab_shell_construction(first, fitted)
	_check_roof_construction(first, fitted)

	var engines: Array[MeshInstance3D] = []
	var collars: Array[MeshInstance3D] = []
	for child in first.get_node(^"ContractCourierVisual").get_children():
		if child is MeshInstance3D and child.mesh == first.get_node(^"ContractCourierVisual/EnginePod").mesh:
			engines.append(child)
		elif child is MeshInstance3D and child.mesh == first.get_node(^"ContractCourierVisual/EngineCore").mesh:
			collars.append(child)
	_check(engines.size() == 2 and collars.size() == 2
		and engines[0].mesh == engines[1].mesh and collars[0].mesh == collars[1].mesh,
		"bilateral recessed nacelles and passive retention collars share stock in existing renderer slots")
	for engine in engines + collars:
		_check(_upperworks_surface_is_valid(engine.mesh),
			"engine shell and collar have valid winding, UVs and tangent frames")
		var finish := engine.mesh.surface_get_material(0) as StandardMaterial3D
		_check(not finish.emission_enabled and finish.vertex_color_use_as_albedo,
			"no permanent engine cap emission; passive liner uses vertex finish tint")
		var vertices: PackedVector3Array = engine.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var clear_throat := true
		for vertex in vertices:
			if vertex.z > 0.41 and Vector2(vertex.x, vertex.y).length() < 0.279:
				clear_throat = false
		_check(clear_throat, "no shell or retention collar crosses the recessed throat axis")

	var fittings_clear := true
	for node_name in ["HullBody", "FittedArmourAndServices"]:
		var structure := first.get_node("ContractCourierVisual/" + node_name) as MeshInstance3D
		var faces := structure.mesh.get_faces()
		for side in [-1.0, 1.0]:
			for offset in [Vector2.ZERO, Vector2(0.2,0), Vector2(-0.2,0), Vector2(0,0.2), Vector2(0,-0.2)]:
				var start := Vector3(side*1.15+offset.x,0.05+offset.y,4.95)
				var finish := Vector3(start.x,start.y,4.32)
				for index in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(start,finish,
						structure.transform*faces[index],structure.transform*faces[index+1],
						structure.transform*faces[index+2]) != null:
						fittings_clear = false
	_check(fittings_clear, "actual hull and fitted support triangles leave both recessed throat interiors clear")

	var first_bands := _pod_bands(first)
	var second_bands := _pod_bands(second)
	_check(
		first_bands.size() == 2 and second_bands.size() == 2,
		"both production couriers retain port and starboard cargo bands"
	)
	var first_mesh := first_bands[0].mesh as ArrayMesh if first_bands.size() == 2 else null
	var second_mesh := second_bands[0].mesh as ArrayMesh if second_bands.size() == 2 else null
	_check(
		first_mesh != null
			and second_mesh != null
			and first_bands[1].mesh == first_mesh
			and second_bands[1].mesh == second_mesh,
		"each courier shares one immutable pod-band mesh across both renderer nodes"
	)
	_check(
		first_mesh != second_mesh
			and first_mesh.get_aabb().size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE)
			and second_mesh.get_aabb().size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE)
			and first_mesh.get_surface_count() == 1
			and second_mesh.get_surface_count() == 1,
		"the shared family stays instance-owned and retains the outer envelope with a formed circular strap"
	)
	_check(_formed_strap_is_valid(first_mesh),
		"rolled strap has a clear vessel aperture, outward normals and no degenerate faces")
	var pods: Array[MeshInstance3D] = []
	for child in first.get_node(^"ContractCourierVisual").get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh and child.mesh.get_aabb().size.is_equal_approx(Vector3(1.24, 1.24, 4.6)):
			pods.append(child)
	_check(pods.size() == 2 and pods[0].mesh == pods[1].mesh
		and pods[0].mesh is ArrayMesh
		and pods[0].mesh.get_aabb().size.is_equal_approx(Vector3(1.24, 1.24, 4.6)),
		"formed pressure vessels share a mesh and preserve their collision envelope")
	var rust_id := int((first.get_visual_resource_audit().identity_by_key as Dictionary).get(&"courier_rust", 0))
	_check(
		first_mesh != null
			and second_mesh != null
			and first_mesh.surface_get_material(0) != null
			and first_mesh.surface_get_material(0).get_instance_id() == rust_id
			and second_mesh.surface_get_material(0) == first_mesh.surface_get_material(0),
		"both shared meshes retain the process-wide rust material binding"
	)
	_check(
		_positions_are_exact(first_bands)
			and _positions_are_exact(second_bands)
			and first.get_node_or_null(^"PortPodCollision") is CollisionShape3D
			and first.get_node_or_null(^"StarboardPodCollision") is CollisionShape3D,
		"sharing preserves bilateral placement and independent cargo-pod collision"
	)
	var first_components := first.get_component_damage_snapshot()
	var second_components := second.get_component_damage_snapshot()
	_check(
		bool(first_components.get("configuration_current", false))
			and bool(second_components.get("configuration_current", false)),
		"the visual-only sharing leaves both production component-damage models configured"
	)
	_check(
		first.get_node_or_null(^"ContractCourierVisual/TailTurretLens") is MeshInstance3D,
		"the visual-only sharing leaves the tail-turret telegraph intact"
	)
	_check(
		first.get_component_id() == CourierRunnerOpponent.COMPONENT_ID
			and second.get_component_id() == CourierRunnerOpponent.COMPONENT_ID
			and first.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and second.get_weapon_id() == CourierRunnerOpponent.COURIER_WEAPON_ID
			and not first.is_combat_source_registered()
			and not second.is_combat_source_registered(),
		"the visual-only sharing leaves combat/component identity and authority unchanged"
	)

	var unique_meshes := {
		first_mesh.get_instance_id() if first_mesh != null else 0: true,
		second_mesh.get_instance_id() if second_mesh != null else -1: true,
	}
	_check(
		unique_meshes.size() == 2,
		"two couriers reduce four legacy pod-band mesh allocations to two without batching renderers"
	)

	host.queue_free()
	await process_frame
	_check(
		not is_instance_valid(first) and not is_instance_valid(second),
		"couriers still leave the reuse lifecycle cleanly"
	)

	if _failures.is_empty():
		print("COURIER_RUNNER_POD_BAND_SHARING: mesh_resources 4->2 renderer_nodes 4->4 geometry_submissions 4->4")
		print("PASS courier_runner_pod_band_resource_sharing_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _pod_bands(courier: CourierRunnerOpponent) -> Array[MeshInstance3D]:
	var bands: Array[MeshInstance3D] = []
	var visual := courier.get_node_or_null(^"ContractCourierVisual")
	if visual == null:
		return bands
	for child in visual.get_children():
		if child is not MeshInstance3D:
			continue
		var candidate := child as MeshInstance3D
		var strap := candidate.mesh as ArrayMesh
		if strap != null and strap.get_aabb().size.is_equal_approx(CourierRunnerOpponent.POD_BAND_SIZE):
			bands.append(candidate)
	return bands


func _formed_strap_is_valid(mesh: ArrayMesh) -> bool:
	if mesh == null:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for vertex in vertices:
		var radial := Vector2(vertex.x, vertex.y).length()
		if radial < 0.622 or radial > 0.676:
			return false
	for index in range(0, vertices.size(), 3):
		var cross_product := (vertices[index + 1] - vertices[index]).cross(
			vertices[index + 2] - vertices[index])
		var average_normal := normals[index] + normals[index + 1] + normals[index + 2]
		if cross_product.length_squared() < 0.0000000001 or cross_product.dot(average_normal) >= 0.0:
			return false
	return true


func _positions_are_exact(bands: Array[MeshInstance3D]) -> bool:
	if bands.size() != 2:
		return false
	var positions := [bands[0].position, bands[1].position]
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	return (
		positions[0].is_equal_approx(Vector3(-2.5, -0.34, -0.8))
		and positions[1].is_equal_approx(Vector3(2.5, -0.34, -0.8))
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _upperworks_surface_is_valid(mesh: ArrayMesh, check_outward := false) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	if vertices.is_empty() or uvs.size() != vertices.size() or tangents.size() != vertices.size()*4:
		return false
	var centre := mesh.get_aabb().get_center()
	for index in range(0,vertices.size(),3):
		var face := (vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index])
		var uv_area := (uvs[index+1]-uvs[index]).cross(uvs[index+2]-uvs[index])
		if face.length_squared() < 0.0000000001 or face.dot(normals[index]) >= 0.0 or absf(uv_area) < 0.00000001:
			return false
		if check_outward and normals[index].dot(vertices[index]-centre) <= 0.0:
			return false
	for index in vertices.size():
		var tangent := Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
		if not tangent.is_finite() or absf(tangent.length()-1.0) > 0.01 or absf(tangent.dot(normals[index])) > 0.01:
			return false
	return true


func _check_cab_shell_construction(courier: CourierRunnerOpponent, fitted: MeshInstance3D) -> void:
	var installed := {}
	for point: Vector3 in fitted.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		installed[point.snapped(Vector3.ONE*0.00001)] = true
	for weather_roof in [false,true]:
		var shell := courier._courier_cab_shell_mesh(weather_roof,null)
		_check(_upperworks_surface_is_valid(shell),
			"formed cab shell has outward winding, nondegenerate triangles and valid UV/tangent frames")
		var actual := true
		var vertices: PackedVector3Array = shell.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var crown_levels := {}
		for point in vertices:
			actual = actual and installed.has(point.snapped(Vector3.ONE*0.00001))
			if absf(point.z-(-2.35 if weather_roof else -2.70)) < 0.0001:
				crown_levels[snappedf(point.y,0.0001)] = true
		_check(actual and crown_levels.size() >= 9 and vertices.size()/3 < 700,
			"actual opaque batch carries a bounded curved cab crown and shoulders, rather than a four-corner housing")
		if weather_roof:
			var aft := _roof_vertical_hits(shell.get_faces(),0.0,-1.4901)
			var service := courier._courier_roof_mesh(-1.51,-0.045,0.024,null)
			var deck := _roof_vertical_hits(service.get_faces(),0.0,-1.4901)
			_check(not aft.is_empty() and not deck.is_empty() and absf(aft[-1]-deck[-1]) < 0.01,
				"aft cab crown joins the actual service cover within one centimetre")
		else:
			var bow := courier.get_node(^"ContractCourierVisual/BluntNose") as MeshInstance3D
			var bow_faces := bow.mesh.get_faces()
			for index in bow_faces.size():
				bow_faces[index] = bow.transform*bow_faces[index]
			var seated := true
			for z in [-3.70,-3.50,-3.20]:
				var base := _roof_vertical_hits(bow_faces,0.0,z)
				var collar := _roof_vertical_hits(shell.get_faces(),0.0,z)
				seated = seated and not base.is_empty() and collar.size() >= 2
				if not base.is_empty() and collar.size() >= 2:
					seated = seated and collar[0] < base[-1] and collar[-1] > base[-1]
			_check(seated,"drawn collar intersects the actual formed bow instead of floating above it")


func _check_roof_construction(courier: CourierRunnerOpponent, fitted: MeshInstance3D) -> void:
	var hull := courier.get_node(^"ContractCourierVisual/HullBody") as MeshInstance3D
	var seal := courier.get_node(^"ContractCourierVisual/SpineTrunk") as MeshInstance3D
	_check(seal.mesh is ArrayMesh and _upperworks_surface_is_valid(seal.mesh),
		"continuous recessed seal has valid skin, edge-return and end-cap geometry/UV/tangents")
	var fitted_vertices: PackedVector3Array = fitted.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var actual_vertices := {}
	for vertex in fitted_vertices:
		actual_vertices[vertex.snapped(Vector3.ONE*0.00001)] = true
	var hull_faces := hull.mesh.get_faces()
	for index in hull_faces.size():
		hull_faces[index] = hull.transform*hull_faces[index]
	for bay in 3:
		var start := -1.51+bay*1.51
		var cover := courier._courier_roof_mesh(start,start+1.465,0.024,null)
		_check(_upperworks_surface_is_valid(cover),
			"formed cover %d has valid curved skin, returned edges, end caps and texture frames" % bay)
		var installed := true
		var cover_vertices: PackedVector3Array = cover.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in cover_vertices:
			installed = installed and actual_vertices.has(vertex.snapped(Vector3.ONE*0.00001))
		_check(installed, "checked cover %d is installed in the actual production material batch" % bay)
		var seated := true
		for z in [start+0.001,start+0.73,start+1.464]:
			var width := lerpf(1.1,1.03,clampf(z-2.1,0.0,1.0))
			for fraction in [0.0,-0.64,0.64,-0.97259,0.97259]:
				var x: float = fraction*width
				var hull_hits := _roof_vertical_hits(hull_faces,x,z)
				var skin_hits := _roof_vertical_hits(cover.get_faces(),x,z)
				if hull_hits.is_empty() or skin_hits.size() < 2:
					seated = false
					continue
				var clearance: float = skin_hits[-1]-hull_hits[-1]
				seated = seated and clearance > 0.032 and clearance < 0.117
				if absf(fraction) > 0.97:
					var return_depth: float = skin_hits[0]-hull_hits[-1]
					seated = seated and return_depth >= -0.0021 and return_depth <= 0.0001
		_check(seated, "actual cover %d clears hull triangles and its thin returns seat within 2 mm at both shoulders and aft taper" % bay)
		_check(cover.get_aabb().position.z >= -1.51 and cover.get_aabb().end.z <= 2.976,
			"service cover remains behind the cab pressure frame and before the aft machinery")
	for z in [-0.025,1.49]:
		var seal_hits := _roof_vertical_hits(seal.mesh.get_faces(),0.0,z)
		var fitted_hits := _roof_vertical_hits(fitted.mesh.get_faces(),0.0,z)
		_check(not seal_hits.is_empty() and (fitted_hits.is_empty() or fitted_hits[-1] < seal_hits[-1]),
			"the actual transverse cover gap exposes the continuous recessed seal")


func _roof_vertical_hits(faces: PackedVector3Array, x: float, z: float) -> Array[float]:
	var heights: Array[float] = []
	for index in range(0,faces.size(),3):
		var hit = Geometry3D.segment_intersects_triangle(Vector3(x,2.0,z),Vector3(x,0.2,z),
			faces[index],faces[index+1],faces[index+2])
		if hit != null:
			heights.append(hit.y)
	heights.sort()
	return heights
