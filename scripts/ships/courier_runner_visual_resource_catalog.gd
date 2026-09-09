extends RefCounted

## Process-owned immutable Material identities for CourierRunner presentation.
## This standalone holder avoids coupling catalog lifetime to the opponent's
## scripted inheritance chain; consumers always receive a shallow map copy.

static var _materials: Dictionary = {}
static var _build_count := 0


static func get_catalog() -> Dictionary:
	return _materials.duplicate(false)


static func publish_catalog(materials: Dictionary) -> Dictionary:
	if _materials.is_empty():
		_materials = materials.duplicate(false)
		_build_count += 1
	return get_catalog()


static func get_material(key: Variant) -> StandardMaterial3D:
	return _materials.get(key) as StandardMaterial3D


static func get_entry_count() -> int:
	return _materials.size()


static func get_build_count() -> int:
	return _build_count


## Axial profiles are (z, radius). Rings carry the pressure shell's rolled
## shoulders and the strap's turned lips; their normals follow the actual
## curvature instead of smoothing the vessel into a straight cylinder.
static func make_cargo_shell(material: Material) -> ArrayMesh:
	return _revolve(PackedVector2Array([
		Vector2(-2.3, 0.0), Vector2(-2.3, 0.31),
		Vector2(-2.27, 0.40), Vector2(-2.20, 0.49),
		Vector2(-2.08, 0.565), Vector2(-1.92, 0.61),
		Vector2(-1.74, 0.62), Vector2(1.74, 0.62),
		Vector2(1.92, 0.61), Vector2(2.08, 0.565),
		Vector2(2.20, 0.49), Vector2(2.27, 0.40),
		Vector2(2.3, 0.31), Vector2(2.3, 0.0),
	]), material)


static func make_cargo_strap(material: Material) -> ArrayMesh:
	# Closed rolled strap, with a real aperture around the vessel. The old
	# solid square band obscured the tank and read as a disconnected box.
	return _revolve(PackedVector2Array([
		Vector2(-0.11, 0.637), Vector2(-0.105, 0.657),
		Vector2(-0.085, 0.675), Vector2(0.085, 0.675),
		Vector2(0.105, 0.657), Vector2(0.11, 0.637),
		Vector2(0.09, 0.623), Vector2(-0.09, 0.623),
		Vector2(-0.11, 0.637),
	]), material, true)


static func _revolve(profile: PackedVector2Array, material: Material, closed := false) -> ArrayMesh:
	const SEGMENTS := 64
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for station in profile.size() - 1:
		for segment in SEGMENTS:
			var corners: Array[Vector2i] = []
			if not is_zero_approx(profile[station + 1].y):
				corners.append_array([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)])
			if not is_zero_approx(profile[station].y):
				corners.append_array([Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)])
			for corner: Vector2i in corners:
				var ring := station + corner.x
				var angle := TAU * float(segment + corner.y) / SEGMENTS
				var point := profile[ring]
				var previous := profile[maxi(ring - 1, 0)]
				var following := profile[mini(ring + 1, profile.size() - 1)]
				if closed and (ring == 0 or ring == profile.size() - 1):
					previous = profile[profile.size() - 2]
					following = profile[1]
				var tangent := (following - previous).normalized()
				var normal := Vector3(cos(angle) * tangent.x, sin(angle) * tangent.x, -tangent.y)
				if is_zero_approx(point.y):
					normal = Vector3(0, 0, -1 if ring == 0 else 1)
				surface.set_normal(normal)
				surface.set_uv(Vector2(float(segment + corner.y) / SEGMENTS, point.x))
				surface.add_vertex(Vector3(cos(angle) * point.y, sin(angle) * point.y, point.x))
	surface.generate_tangents()
	return surface.commit()
