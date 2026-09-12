extends RefCounted

## Fitted Cinder glazing seats on the retained pressure-wall and sill tops. The broad
## raked front has no narrow central bow, and the open underside lets the hood
## and pilot remain in the fixed cockpit while the complete upper lid lifts.
static func install(hinge: Node3D, frame_mesh: Callable, cap_rear: bool = true) -> void:
	var rings := _rings()
	var glass := hinge.get_node("CanopyGlass") as MeshInstance3D
	glass.mesh = _glass(rings, glass.mesh.surface_get_material(0), cap_rear)
	glass.set_meta("closed_volume", false)
	glass.set_meta("upper_pressure_enclosure", true)
	for side in [-1, 1]:
		var prefix := "Port" if side < 0 else "Starboard"
		var lower := PackedVector3Array()
		var shoulder := PackedVector3Array()
		for ring: PackedVector3Array in rings:
			lower.append(ring[0 if side < 0 else 32])
			shoulder.append(ring[5 if side < 0 else 27])
		# The 90 mm sill channel also bridges the small wall/sill corner
		# reveal; its radius overlaps both retained pieces across that joint.
		_member(hinge, frame_mesh, prefix + "CanopyLowerRail", lower, 0.045)
		_member(hinge, frame_mesh, prefix + "CanopyTopRail", shoulder, 0.020)
		# A bent keeper carries the existing striker contact back to the lid.
		# The former isolated hook block had no attachment when opened.
		_member(hinge, frame_mesh, prefix + "CanopyLatchHook", PackedVector3Array([
			Vector3(side * 1.18, 0.105, -0.78),
			Vector3(side * 1.18, -0.04, -0.78),
			Vector3(side * 0.92, -0.04, -0.78),
			Vector3(side * 0.92, -0.12, -0.78),
		]), 0.028)
		var seal := lower.duplicate()
		var laminate := lower.duplicate()
		for index in lower.size():
			seal[index].y -= 0.019
			laminate[index].y += 0.023
		_member(hinge, frame_mesh, prefix + "CanopyLowerPressureSeal", seal, 0.019)
		_member(hinge, frame_mesh, prefix + "CanopyLaminateEdge", laminate, 0.008)
		for end in [0, rings.size() - 1]:
			var bow := PackedVector3Array()
			for step in 17:
				bow.append(rings[end][step if side < 0 else 32 - step])
			_member(hinge, frame_mesh, prefix + ("CanopyNoseFrame" if end == 0 else "CanopyRearUpright"), bow, 0.023,
				Vector3.RIGHT if side < 0 else Vector3.LEFT)
	var front := PackedVector3Array([rings[0][0], rings[0][32]])
	var rear := PackedVector3Array([rings[-1][0], rings[-1][32]])
	_member(hinge, frame_mesh, "CanopyNosePressureSeal", front, 0.045)
	_member(hinge, frame_mesh, "CanopyRearFrame", rear, 0.032)
	for index in rear.size():
		rear[index].y -= 0.019
	_member(hinge, frame_mesh, "CanopyRearPressureSeal", rear, 0.019)


## Existing renderers retain material and lifecycle ownership; only their
## fitted stock changes. All coordinates are local to the common aft hinge.
static func _member(hinge: Node3D, frame_mesh: Callable, member_name: String, path: PackedVector3Array, radius: float, tangent := Vector3.ZERO) -> void:
	var member := hinge.get_node(member_name) as MeshInstance3D
	var finish := member.mesh.surface_get_material(0)
	member.transform = Transform3D.IDENTITY
	member.mesh = frame_mesh.call(path, radius, tangent) as ArrayMesh
	member.mesh.surface_set_material(0, finish)


static func _rings() -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	for station in 17:
		var t := float(station) / 16.0
		var lower_z := lerpf(-3.165, 0.015, t)
		var lower_width := lerpf(1.015, 1.18, clampf(t * 16.0, 0.0, 1.0))
		var lower_y := lerpf(0.095, 0.105, clampf(t * 16.0, 0.0, 1.0))
		var crown_y := lerpf(1.40, 1.34, t)
		var crown_z := lerpf(-2.70, 0.015, t)
		var ring := PackedVector3Array()
		for step in 33:
			var angle := PI * float(step) / 32.0
			var rise := pow(maxf(sin(angle), 0.0), 0.40)
			var across := -cos(angle)
			var width := lerpf(lower_width, 1.14, rise)
			ring.append(Vector3(signf(across) * pow(absf(across), 0.40) * width,
				lerpf(lower_y, crown_y, rise), lerpf(lower_z, crown_z, rise)))
		rings.append(ring)
	return rings


static func _glass(rings: Array[PackedVector3Array], finish: Material, cap_rear: bool = true) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(finish)
	for section in range(rings.size() - 1):
		surface.set_smooth_group(0)
		for side in 32:
			for index: Vector2i in [Vector2i(section, side), Vector2i(section, side + 1), Vector2i(section + 1, side + 1),
				Vector2i(section, side), Vector2i(section + 1, side + 1), Vector2i(section + 1, side)]:
				surface.set_uv(Vector2(float(index.y) / 32.0, float(index.x) / 16.0))
				surface.add_vertex(rings[index.x][index.y])
	# Front and rear glazing end at their actual structural cross-sills. No
	# horizontal glass floor passes through the controls or sweeps over the head.
	for cap in ([0, rings.size() - 1] if cap_rear else [0]):
		surface.set_smooth_group(-1)
		var center := (rings[cap][0] + rings[cap][32]) * 0.5
		for side in 32:
			var vertices: Array = [center, rings[cap][side + 1], rings[cap][side]] if cap == 0 else [center, rings[cap][side], rings[cap][side + 1]]
			for vertex: Vector3 in vertices:
				surface.set_uv(Vector2(vertex.x, vertex.y))
				surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()

