extends RefCounted

## Passive reusable framed ventilation cassettes. Geometry is shared by size;
## coatings and all gameplay ownership remain with the installing ship.
static var _stocks: Dictionary = {}


static func install(parent: Node3D, tag: String, at: Vector3, width: float, length: float, frame: Material, dark: Material, metal: Material) -> void:
	var size := Vector2(width, length)
	if not _stocks.has(size):
		var back := BoxMesh.new()
		back.size = Vector3(width, 0.035, length)
		_stocks[size] = [back, _service_cassette_frame(size), _service_cassette_vanes(size)]
	for part in 3:
		var node := MeshInstance3D.new()
		node.name = tag + ["Recess", "Frame", "Vanes"][part]
		node.position = at + (Vector3(0, 0.025, 0) if part == 0 else Vector3.ZERO)
		node.mesh = _stocks[size][part]
		node.material_override = [dark, frame, metal][part]
		node.set_meta(&"presentation_only", true)
		parent.add_child(node)


static func _service_cassette_frame(size: Vector2) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	# Outer foot, wall, rolled shoulder, mouth and returning inner wall.
	for section in [Vector3(0.14, -0.025, 0.14), Vector3(0.14, 0.08, 0.14),
			Vector3(0.10, 0.12, 0.10), Vector3(-0.025, 0.12, -0.025),
			Vector3(-0.025, -0.025, -0.025)]:
		var half := (size + Vector2(section.x, section.z)) * 0.5
		var radius := minf(half.x, half.y) * 0.32
		var ring := PackedVector3Array()
		for corner in 4:
			var centre := Vector2(half.x - radius, half.y - radius)
			centre *= Vector2(1 if corner in [0, 3] else -1, 1 if corner < 2 else -1)
			for step in 9:
				var angle := (float(corner) + float(step) / 8.0) * PI * 0.5
				var point := centre + Vector2(cos(angle), sin(angle)) * radius
				ring.append(Vector3(point.x, section.y, point.y))
		rings.append(ring)
	for row in rings.size():
		var next_row := (row + 1) % rings.size()
		for edge in rings[row].size():
			var next := (edge + 1) % rings[row].size()
			var a := rings[row][edge]
			var b := rings[row][next]
			var c := rings[next_row][next]
			var d := rings[next_row][edge]
			var outward := Vector3(a.x, 0, a.z).normalized()
			if row == 2:
				outward = Vector3.UP
			elif row == 3:
				outward = -outward
			elif row == 4:
				outward = Vector3.DOWN
			tool.set_smooth_group(row)
			_service_stock_quad(tool, a, b, c, d, outward)
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	return tool.commit()


static func _service_cassette_vanes(size: Vector2) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var centre_z := (float(blade) / 4.0 - 0.5) * size.y * 0.78
		var rings: Array[PackedVector3Array] = []
		for end in [-1.0, 1.0]:
			var ring := PackedVector3Array()
			for step in 16:
				var angle := float(step) * TAU / 16.0
				var chord := cos(angle) * size.y * 0.070
				ring.append(Vector3(end * size.x * 0.5, 0.078 + sin(angle) * 0.012 + chord * 0.16, centre_z + chord))
			rings.append(ring)
		for edge in 16:
			var next := (edge + 1) % 16
			var a := rings[0][edge]
			var b := rings[1][edge]
			var c := rings[1][next]
			var d := rings[0][next]
			var outward := (a + d) * 0.5 - Vector3(a.x, 0.078, centre_z)
			tool.set_smooth_group(blade)
			_service_stock_quad(tool, a, b, c, d, outward)
		for end in 2:
			tool.set_smooth_group(-1)
			var normal := Vector3.LEFT if end == 0 else Vector3.RIGHT
			var centre := Vector3(rings[end][0].x, 0.078, centre_z)
			for edge in 16:
				_service_stock_triangle(tool, centre, rings[end][edge], rings[end][(edge + 1) % 16], normal,
					Vector2(centre.y, centre.z), Vector2(rings[end][edge].y, rings[end][edge].z),
					Vector2(rings[end][(edge + 1) % 16].y, rings[end][(edge + 1) % 16].z))
	tool.generate_normals()
	tool.generate_tangents()
	tool.index()
	return tool.commit()


static func _service_stock_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var uv_a := Vector2.ZERO
	var uv_b := Vector2(a.distance_to(b), 0)
	var uv_c := Vector2(a.distance_to(b), b.distance_to(c))
	var uv_d := Vector2(0, a.distance_to(d))
	_service_stock_triangle(tool, a, b, c, outward, uv_a, uv_b, uv_c)
	_service_stock_triangle(tool, a, c, d, outward, uv_a, uv_c, uv_d)


static func _service_stock_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var order := [0, 2, 1] if (b - a).cross(c - a).dot(outward) > 0.0 else [0, 1, 2]
	for index in order:
		tool.set_uv([uv_a, uv_b, uv_c][index])
		tool.add_vertex([a, b, c][index])
