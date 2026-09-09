extends RefCounted

## Passive Cinder nozzle construction. All unit machinery meshes are shared
## across mounts and hull sizes; engine state remains owned by the real plume.
static var _meshes: Dictionary = {}


static func bell(parent: Node3D, tag: String, at: Vector3, mouth: float, throat: float, length: float, material: Material) -> void:
	var key := "bell:%s:%s:%s" % [mouth, throat, length]
	if not _meshes.has(key):
		var profile := PackedVector2Array()
		# A formed flare, rounded mouth edge and returning inner liner make a
		# closed metal wall while leaving both axial openings unobstructed.
		var wall := mouth * 0.042
		for step in 13:
			var t := float(step) / 12.0
			profile.append(Vector2(lerpf(throat, mouth - wall, t * t * (3.0 - 2.0 * t)), lerpf(-length * 0.5, length * 0.5 - wall, t)))
		for step in range(1, 13):
			var angle := float(step) * PI / 12.0
			profile.append(Vector2(mouth - wall + sin(angle) * wall, length * 0.5 - wall + (1.0 - cos(angle)) * wall * 0.5))
		for step in range(12, -1, -1):
			var t := float(step) / 12.0
			profile.append(Vector2(lerpf(throat - wall, mouth - wall * 2.0, t * t * (3.0 - 2.0 * t)), lerpf(-length * 0.5, length * 0.5 - wall, t)))
		profile.append(profile[0])
		_meshes[key] = _turned(profile)
	_add(parent, tag, _meshes[key], at, 1.0, material)


static func install(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material) -> void:
	if not _meshes.has("hub"):
		_meshes.hub = _turned(PackedVector2Array([
			Vector2(0, -0.53), Vector2(0.29, -0.53), Vector2(0.32, -0.49),
			Vector2(0.32, -0.39), Vector2(0.30, -0.32), Vector2(0.26, -0.25),
			Vector2(0.20, -0.19), Vector2(0.12, -0.15), Vector2(0, -0.14)]))
		_meshes.back = _turned(PackedVector2Array([
			Vector2(0, -0.59), Vector2(0.84, -0.59), Vector2(0.84, -0.53), Vector2(0, -0.53)]))
		_meshes.annulus = _turned(PackedVector2Array([
			Vector2(0.84, -0.48), Vector2(0.90, -0.48), Vector2(0.91, -0.43),
			Vector2(0.90, -0.28), Vector2(0.88, -0.25), Vector2(0.84, -0.27),
			Vector2(0.83, -0.31), Vector2(0.84, -0.48)]))
		var lip := TorusMesh.new()
		lip.inner_radius = 0.99
		lip.outer_radius = 1.07
		lip.rings = 96
		lip.ring_segments = 16
		_meshes.lip = lip
		_meshes.vane = _vane()
	_add(parent, tag + "ChamberBack", _meshes.back, at, radius, dark)
	_add(parent, tag + "CombustorAnnulus", _meshes.annulus, at, radius, metal)
	_add(parent, tag + "ThrustPlug", _meshes.hub, at, radius, metal)
	var lip := _add(parent, tag + "NozzleLip", _meshes.lip, at + Vector3(0, 0, 0.15 * radius), radius, metal)
	lip.rotation.x = PI * 0.5
	var blades := MultiMesh.new()
	blades.transform_format = MultiMesh.TRANSFORM_3D
	blades.mesh = _meshes.vane
	blades.instance_count = 12
	for index in 12:
		blades.set_instance_transform(index, Transform3D(Basis(Vector3.BACK, float(index) * TAU / 12.0), Vector3.ZERO))
	var batch := MultiMeshInstance3D.new()
	batch.name = tag + "GuideVanes"
	batch.multimesh = blades
	batch.material_override = metal
	batch.position = at
	batch.scale = Vector3.ONE * radius
	batch.set_meta(&"presentation_only", true)
	parent.add_child(batch)


static func _add(parent: Node3D, tag: String, mesh: Mesh, at: Vector3, size: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = tag
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = Vector3.ONE * size
	node.set_meta(&"presentation_only", true)
	parent.add_child(node)
	return node


static func _turned(profile: PackedVector2Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size() - 1:
		var next := row + 1
		var planar_uv := is_zero_approx(profile[row].x) or is_zero_approx(profile[next].x) \
			or is_equal_approx(profile[row].y, profile[next].y)
		var uv_radius := maxf(profile[row].x, profile[next].x)
		for segment in 96:
			# The pole is one vertex, so only the surviving fan triangle is
			# emitted there; a collapsed half-quad has no valid tangent frame.
			var corners: Array[Vector2i] = []
			if not is_zero_approx(profile[row].x):
				corners.append_array([Vector2i(row, segment), Vector2i(next, segment + 1), Vector2i(row, segment + 1)])
			if not is_zero_approx(profile[next].x):
				corners.append_array([Vector2i(row, segment), Vector2i(next, segment), Vector2i(next, segment + 1)])
			for corner in corners:
				var angle := float(corner.y) * TAU / 96.0
				var p := profile[corner.x]
				var before := profile[maxi(corner.x - 1, 0)]
				var after := profile[mini(corner.x + 1, profile.size() - 1)]
				var tangent := (after - before).normalized()
				surface.set_normal(Vector3(cos(angle) * tangent.y, sin(angle) * tangent.y, -tangent.x))
				if planar_uv:
					surface.set_uv(Vector2(cos(angle), sin(angle)) * p.x / (2.0 * uv_radius) + Vector2.ONE * 0.5)
				else:
					surface.set_uv(Vector2(float(corner.y) / 96.0, float(corner.x) / float(profile.size() - 1)))
				surface.add_vertex(Vector3(cos(angle) * p.x, sin(angle) * p.x, p.y))
	surface.generate_tangents()
	surface.index()
	return surface.commit()


## Swept stator airfoil with a rounded edge and real axial chord. Both roots
## bury into the retained hub/ring; the aft edge stays behind the nozzle lip.
static func _vane() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 9:
		var t := float(row) / 8.0
		var ring := PackedVector3Array()
		for segment in 16:
			var angle := float(segment) * TAU / 16.0
			var chord := 0.105 + sin(t * PI) * 0.025
			var axial := cos(angle) * chord
			ring.append(Vector3(0.12 * t * t + sin(angle) * 0.022 + axial * (0.28 + 0.4 * t), lerpf(0.27, 0.89, t), -0.38 + axial))
		rings.append(ring)
	for row in 8:
		for segment in 16:
			for corner in [Vector2i(row, segment), Vector2i(row + 1, segment + 1), Vector2i(row, segment + 1), Vector2i(row, segment), Vector2i(row + 1, segment), Vector2i(row + 1, segment + 1)]:
				surface.set_smooth_group(0)
				surface.set_uv(Vector2(float(corner.y) / 16.0, float(corner.x) / 8.0))
				surface.add_vertex(rings[corner.x][corner.y % 16])
	# Planar root caps use a separate normal/UV seam from the smooth airfoil.
	for row in [0, 8]:
		for segment in range(1, 15):
			var indices := [0, segment, segment + 1] if row == 0 else [0, segment + 1, segment]
			for index in indices:
				var point := rings[row][index]
				surface.set_smooth_group(-1)
				surface.set_uv(Vector2(point.x, point.z) / 0.5 + Vector2.ONE * 0.5)
				surface.add_vertex(point)
	surface.generate_normals()
	surface.generate_tangents()
	surface.index()
	return surface.commit()
