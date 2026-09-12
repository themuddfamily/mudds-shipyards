extends RefCounted

## Formed armor below the existing canopy seal. Geometry is shared by recipe;
## the owning craft supplies its finish through material_override.
static var _meshes: Dictionary = {}

static func install(cockpit: Node3D, armor: Material, profile: StringName, half_width: float, foot_heights: Array) -> void:
	var names := ["PortSidewall", "StarboardSidewall", "ForwardPressureWall", "RearPressureWall"]
	for index in names.size():
		var wall := cockpit.get_node(names[index]) as MeshInstance3D
		var key: String = String(profile) + names[index]
		if not _meshes.has(key):
			_meshes[key] = _build(wall.transform * wall.get_aabb(), index, half_width, foot_heights)
		wall.transform = Transform3D.IDENTITY
		wall.mesh = _meshes[key]
		wall.material_override = armor


static func _build(bounds: AABB, wall_index: int, half_width: float, heights: Array) -> ArrayMesh:
	var side_wall := wall_index < 2
	var direction := -1.0 if wall_index in [0, 2] else 1.0
	var rings: Array[PackedVector3Array] = []
	for station in 7:
		var t := float(station) / 6.0
		var top: Vector3
		var inner: Vector3
		var foot: Vector3
		if side_wall:
			top = Vector3(direction * 1.17, bounds.end.y, lerpf(bounds.position.z, bounds.end.z, t))
			inner = Vector3(direction * 0.99, top.y, top.z)
			foot = Vector3(direction * (1.20 + (half_width - 1.20) * sin(PI * t)), heights[0][station], lerpf(-2.34, 1.23, t))
		else:
			top = Vector3(lerpf(-1.17, 1.17, t), bounds.end.y, bounds.position.z if direction < 0 else bounds.end.z)
			inner = Vector3(top.x, top.y, bounds.end.z if direction < 0 else bounds.position.z)
			foot = Vector3(lerpf(-1.20, 1.20, t), heights[wall_index - 1][station], -2.34 - 0.11 * sin(PI * t) if direction < 0 else 1.23 + 0.09 * sin(PI * t))
		# A retained upright seal land turns through a rolled shoulder, broad
		# cheek and tucked toe. This is a curved skin, not a flat trapezoid.
		var ring := PackedVector3Array([inner, top])
		for step in range(1, 9):
			var depth := float(step) / 8.0
			var point := top.lerp(foot, [0.015, 0.12, 0.38, 0.72, 0.98, 1.08, 1.06, 1.0][step - 1])
			point.y = lerpf(top.y, foot.y, depth)
			ring.append(point)
		ring.append(Vector3(inner.x, 1.87, inner.z))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_size := rings[0].size()
	var outward := Vector3(direction, 0, 0) if side_wall else Vector3(0, 0, direction)
	for bay in 6:
		for edge in ring_size:
			surface.set_smooth_group(0 if edge >= 1 and edge < 9 else -1)
			var facing := outward
			if edge == 0: facing = Vector3.UP
			elif edge == 9: facing = Vector3.DOWN
			elif edge == 10: facing = -outward
			var next := (edge + 1) % ring_size
			_triangle(surface, rings[bay][edge], rings[bay+1][edge], rings[bay+1][next], facing)
			_triangle(surface, rings[bay][edge], rings[bay+1][next], rings[bay][next], facing)
	surface.set_smooth_group(-1)
	for end in [0, 6]:
		var facing := Vector3(0, 0, -1 if end == 0 else 1) if side_wall else Vector3(-1 if end == 0 else 1, 0, 0)
		for edge in range(1, ring_size - 1):
			_triangle(surface, rings[end][0], rings[end][edge], rings[end][edge+1], facing)
	surface.generate_normals()
	surface.generate_tangents()
	surface.index()
	return surface.commit()


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.0000000001:
		return
	var points := [a, b, c] if normal.dot(facing) >= 0.0 else [a, c, b]
	for point: Vector3 in points:
		surface.set_uv(Vector2(point.x + point.z, point.y) * 0.3)
		surface.add_vertex(point)
