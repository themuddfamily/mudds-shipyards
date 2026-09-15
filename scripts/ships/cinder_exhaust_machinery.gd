extends RefCounted

## Passive Cinder nozzle construction. All unit machinery meshes are shared
## across mounts and hull sizes; engine state remains owned by the real plume.
##
## Every revolved part here is tessellated by `ShipGeometryBudget` from the
## radius it is actually built at, rather than by the single authored 96 that
## used to be applied from the two-metre bomber bell mouth down to the
## twenty-centimetre thrust plug. Meshes stay shared: the cache key carries the
## budgeted segment count, so two mounts that budget alike still hold one
## resource and two that do not can no longer silently reuse each other's.
static var _meshes: Dictionary = {}

## Authored tessellation, retained as the ceiling the budget reduces from. The
## budget never returns more than this, so these remain the finest the family
## can be built at.
const AUTHORED_TURNED_SEGMENTS := 96

## Stator blade tessellation, down from the authored 16 segments x 9 stations.
##
## The cross-section is a closed airfoil loop about 7-9 cm across, recessed
## inside the nozzle behind the thrust plug and the lip ring. Twelve segments put
## its worst silhouette error at `0.045 * (1 - cos(PI / 12))` = 1.5 mm, which is
## 0.6 px at 1.5 m and 0.11 px at 8 m.
##
## The span drops from nine stations to five for a separate and stronger reason:
## the blade's only spanwise curvature is the `0.12 * t * t` sweep, and a
## parabola split into four equal spans leaves a residual sagitta of
## `0.12 / (8 * 16)` in blade units — 0.8 mm on the largest (bomber) nozzle.
## Everything else along the span is linear in `t` or a single `sin(t * PI)`
## chord bulge, which five stations sample exactly at its peak.
const VANE_SEGMENTS := 12
const VANE_STATIONS := 5


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
		_meshes[key] = _turned(profile, ShipGeometryBudget.revolved_segments(
			mouth, AUTHORED_TURNED_SEGMENTS
		))
	_add(parent, tag, _meshes[key], at, 1.0, material)


static func install(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material) -> void:
	# Unit meshes are authored about a nominal radius of one and scaled to the
	# mount, so each part is budgeted at the world radius it will actually be
	# drawn at: 0.32, 0.84 and 0.91 of the mount radius respectively.
	var hub_segments := ShipGeometryBudget.revolved_segments(
		radius * 0.32, AUTHORED_TURNED_SEGMENTS
	)
	var back_segments := ShipGeometryBudget.revolved_segments(
		radius * 0.84, AUTHORED_TURNED_SEGMENTS
	)
	var annulus_segments := ShipGeometryBudget.revolved_segments(
		radius * 0.91, AUTHORED_TURNED_SEGMENTS
	)
	var hub_key := "hub:%d" % hub_segments
	var back_key := "back:%d" % back_segments
	var annulus_key := "annulus:%d" % annulus_segments
	var vane_key := "vane"
	if not _meshes.has(hub_key):
		_meshes[hub_key] = _turned(PackedVector2Array([
			Vector2(0, -0.53), Vector2(0.29, -0.53), Vector2(0.32, -0.49),
			Vector2(0.32, -0.39), Vector2(0.30, -0.32), Vector2(0.26, -0.25),
			Vector2(0.20, -0.19), Vector2(0.12, -0.15), Vector2(0, -0.14)]), hub_segments)
	if not _meshes.has(back_key):
		_meshes[back_key] = _turned(PackedVector2Array([
			Vector2(0, -0.59), Vector2(0.84, -0.59), Vector2(0.84, -0.53), Vector2(0, -0.53)]), back_segments)
	if not _meshes.has(annulus_key):
		_meshes[annulus_key] = _turned(PackedVector2Array([
			Vector2(0.84, -0.48), Vector2(0.90, -0.48), Vector2(0.91, -0.43),
			Vector2(0.90, -0.28), Vector2(0.88, -0.25), Vector2(0.84, -0.27),
			Vector2(0.83, -0.31), Vector2(0.84, -0.48)]), annulus_segments)
	# The lip ring was the one revolved part this file still built at the
	# authored 96x16 whatever the mount: 3,072 triangles on each of the six
	# resident nozzles. It is budgeted like every other part here, at the world
	# radius it is drawn at and at walk-up range (the expansion-berth deck runs
	# right under the lowest lip), and the cache key carries the answer so all
	# three hull sizes — which solve alike, the sweep scaling with the ring —
	# keep sharing one unit resource.
	var lip_tessellation := StationSurfaceKit.torus_tessellation_for(
		0.99 * radius, 1.07 * radius, TorusGeometryBudget.NEAR_EYE_METRES, 96, 16
	)
	var lip_key := "lip:%dx%d" % [lip_tessellation.x, lip_tessellation.y]
	if not _meshes.has(lip_key):
		var lip := TorusMesh.new()
		lip.inner_radius = 0.99
		lip.outer_radius = 1.07
		lip.rings = lip_tessellation.x
		lip.ring_segments = lip_tessellation.y
		_meshes[lip_key] = lip
	if not _meshes.has(vane_key):
		_meshes[vane_key] = _vane()
	_add(parent, tag + "ChamberBack", _meshes[back_key], at, radius, dark)
	_add(parent, tag + "CombustorAnnulus", _meshes[annulus_key], at, radius, metal)
	_add(parent, tag + "ThrustPlug", _meshes[hub_key], at, radius, metal)
	var lip := _add(parent, tag + "NozzleLip", _meshes[lip_key], at + Vector3(0, 0, 0.15 * radius), radius, metal)
	lip.rotation.x = PI * 0.5
	var blades := MultiMesh.new()
	blades.transform_format = MultiMesh.TRANSFORM_3D
	blades.mesh = _meshes[vane_key]
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


static func _turned(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size() - 1:
		var next := row + 1
		var planar_uv := is_zero_approx(profile[row].x) or is_zero_approx(profile[next].x) \
			or is_equal_approx(profile[row].y, profile[next].y)
		var uv_radius := maxf(profile[row].x, profile[next].x)
		for segment in segments:
			# The pole is one vertex, so only the surviving fan triangle is
			# emitted there; a collapsed half-quad has no valid tangent frame.
			var corners: Array[Vector2i] = []
			if not is_zero_approx(profile[row].x):
				corners.append_array([Vector2i(row, segment), Vector2i(next, segment + 1), Vector2i(row, segment + 1)])
			if not is_zero_approx(profile[next].x):
				corners.append_array([Vector2i(row, segment), Vector2i(next, segment), Vector2i(next, segment + 1)])
			for corner in corners:
				var angle := float(corner.y) * TAU / float(segments)
				var p := profile[corner.x]
				var before := profile[maxi(corner.x - 1, 0)]
				var after := profile[mini(corner.x + 1, profile.size() - 1)]
				var tangent := (after - before).normalized()
				surface.set_normal(Vector3(cos(angle) * tangent.y, sin(angle) * tangent.y, -tangent.x))
				if planar_uv:
					surface.set_uv(Vector2(cos(angle), sin(angle)) * p.x / (2.0 * uv_radius) + Vector2.ONE * 0.5)
				else:
					surface.set_uv(Vector2(float(corner.y) / float(segments), float(corner.x) / float(profile.size() - 1)))
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
	for row in VANE_STATIONS:
		var t := float(row) / float(VANE_STATIONS - 1)
		var ring := PackedVector3Array()
		for segment in VANE_SEGMENTS:
			var angle := float(segment) * TAU / float(VANE_SEGMENTS)
			var chord := 0.105 + sin(t * PI) * 0.025
			var axial := cos(angle) * chord
			ring.append(Vector3(0.12 * t * t + sin(angle) * 0.022 + axial * (0.28 + 0.4 * t), lerpf(0.27, 0.89, t), -0.38 + axial))
		rings.append(ring)
	for row in VANE_STATIONS - 1:
		for segment in VANE_SEGMENTS:
			for corner in [Vector2i(row, segment), Vector2i(row + 1, segment + 1), Vector2i(row, segment + 1), Vector2i(row, segment), Vector2i(row + 1, segment), Vector2i(row + 1, segment + 1)]:
				surface.set_smooth_group(0)
				surface.set_uv(Vector2(float(corner.y) / float(VANE_SEGMENTS), float(corner.x) / float(VANE_STATIONS - 1)))
				surface.add_vertex(rings[corner.x][corner.y % VANE_SEGMENTS])
	# Planar root caps use a separate normal/UV seam from the smooth airfoil.
	for row in [0, VANE_STATIONS - 1]:
		for segment in range(1, VANE_SEGMENTS - 1):
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
