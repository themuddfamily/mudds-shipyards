extends RefCounted

## Shared formed skin beneath the two fixed Cinder cockpit rigs. The flat
## crown still meets the cockpit floor; rolled sides and eased fore/aft runs
## join that crown to the lower pressure body without a trapezoidal plinth.
static func build(origin: Vector3, crown: float, width: float, material: Material) -> ArrayMesh:
	var stations := [-3.7, -2.25, 1.15, 3.1]
	var tops := [crown * 0.45, 1.89, 1.89, crown]
	var widths := [0.6, width, width, width * 0.95]
	var top_widths := [0.48, 2.18, 2.18, width * 0.85]
	var rings: Array[PackedVector3Array] = []
	const RUN_STEPS := 6
	for bay in 3:
		for sample_index in RUN_STEPS:
			var t := float(sample_index) / RUN_STEPS
			var eased := smoothstep(0.0, 1.0, t)
			rings.append(_section(
				lerpf(stations[bay], stations[bay + 1], t),
				lerpf(tops[bay], tops[bay + 1], eased),
				lerpf(widths[bay], widths[bay + 1], eased),
				lerpf(top_widths[bay], top_widths[bay + 1], eased), crown
			))
	rings.append(_section(stations[-1], tops[-1], widths[-1], top_widths[-1], crown))
	var perimeter_uvs: Array[PackedFloat32Array] = []
	for ring in rings:
		var distances := PackedFloat32Array([0.0])
		for edge in ring.size():
			distances.append(distances[-1] + ring[edge].distance_to(ring[(edge + 1) % ring.size()]))
		perimeter_uvs.append(distances)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	surface.set_smooth_group(0)
	var ring_size := rings[0].size()
	for bay in range(rings.size() - 1):
		for edge in ring_size:
			var next := (edge + 1) % ring_size
			for corner in [Vector2i(edge, bay), Vector2i(next, bay), Vector2i(next, bay + 1), Vector2i(edge, bay), Vector2i(next, bay + 1), Vector2i(edge, bay + 1)]:
				var point := rings[corner.y][corner.x]
				var u_index: int = ring_size if edge == ring_size - 1 and corner.x == 0 else corner.x
				surface.set_uv(Vector2(perimeter_uvs[corner.y][u_index], point.z) * 0.3)
				surface.add_vertex(point - origin)
	# End plates keep flat normals; they do not pull the rolled skin's shading
	# toward a cap normal at the nose or stern.
	surface.set_smooth_group(-1)
	for cap in [0, rings.size() - 1]:
		var center := Vector3.ZERO
		for point in rings[cap]:
			center += point / float(ring_size)
		for edge in ring_size:
			var next := (edge + 1) % ring_size
			var triangle := [center, rings[cap][next], rings[cap][edge]] if cap == 0 else [center, rings[cap][edge], rings[cap][next]]
			for point in triangle:
				surface.set_uv(Vector2(point.x, point.y) * 0.3)
				surface.add_vertex(point - origin)
	surface.generate_normals()
	surface.generate_tangents()
	surface.index()
	return surface.commit()


static func _section(z: float, top: float, width: float, top_width: float, crown: float) -> PackedVector3Array:
	var bottom := minf(crown - 0.24, top - 0.12)
	var half := width * 0.5
	var bevel := minf(0.065, (top - bottom) * 0.22)
	var upper := top_width * 0.5 - bevel
	var side := PackedVector3Array([Vector3(upper, top, z)])
	# A quarter ellipse is tangent to the flat crown and to the outer flank.
	# Its lower rolled return joins the flat bottom without a knife edge.
	for sample_index in range(1, 9):
		var angle := PI * 0.5 * float(sample_index) / 8.0
		side.append(Vector3(
			upper + (half - upper) * sin(angle),
			bottom + bevel + (top - bottom - bevel) * cos(angle), z
		))
	for sample_index in range(1, 4):
		var angle := PI * 0.5 * float(sample_index) / 3.0
		side.append(Vector3(half - bevel + bevel * cos(angle), bottom + bevel - bevel * sin(angle), z))
	var ring := PackedVector3Array([Vector3(-upper, top, z)])
	ring.append_array(side)
	for index in range(side.size() - 1, 0, -1):
		ring.append(Vector3(-side[index].x, side[index].y, z))
	return ring
