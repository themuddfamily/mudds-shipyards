extends SceneTree

## Deterministic offline authoring step for the dated-2011 Torrent macroform.
##
## This script writes checked-in Wavefront OBJ sources. Production scenes load
## Godot's imported ArrayMesh resources; they never execute this generator.
## Coordinates are a modern ergonomic normalization of source B5's broad form,
## not recovered dimensions or authenticated exact geometry.

const OUTPUT_ROOT := "res://assets/models/torrent"
const LOD_PATHS := {
	0: OUTPUT_ROOT + "/torrent_macroform_lod0.obj",
	1: OUTPUT_ROOT + "/torrent_macroform_lod1.obj",
}
const MANIFEST_PATH := OUTPUT_ROOT + "/torrent_authored_asset_manifest.json"
const GENERATION_COMMAND := "godot --headless --path . --script res://tools/generate_torrent_authored_assets.gd"
const SOURCE_RENDITION_SHA256 := "c1f1ed745ce507729228c62deee7798c9af51d98681f2dda65acba0d5a36948d"
const REQUIRED_OBJECTS := [
	"PointedNose",
	"CentralPressureKeel",
	"RaisedSpine",
	"BlockyAftBody",
	"PortLowerSidePlane",
	"PortUpperSidePlane",
	"StarboardLowerSidePlane",
	"StarboardUpperSidePlane",
	"PortAftCircularHousing",
	"StarboardAftCircularHousing",
	"PortAftRail",
	"StarboardAftRail",
	"AftCrossbar",
]
const SIGNED_AXIS_ORDER := ["+X", "-X", "+Y", "-Y", "+Z", "-Z"]
const UV_ROLE_ORDER := [
	"forward_pressure_hull",
	"aft_pressure_hull",
	"lower_side_planes",
	"upper_side_planes",
	"aft_circular_housings",
	"aft_frame",
]
const UV_ROLE_MEMBERS := [
	["PointedNose", "CentralPressureKeel"],
	["RaisedSpine", "BlockyAftBody"],
	["PortLowerSidePlane", "StarboardLowerSidePlane"],
	["PortUpperSidePlane", "StarboardUpperSidePlane"],
	["PortAftCircularHousing", "StarboardAftCircularHousing"],
	["PortAftRail", "StarboardAftRail", "AftCrossbar"],
]
const UV_LAYOUT_ID := "declared_role_weighted_columns_signed_axis_rows_v2"
const UV_ATLAS_OUTER_GUARD := 0.02
const UV_ATLAS_CELL_GUTTER := 0.004
const UV_ATLAS_COLUMNS := 6
const UV_ATLAS_ROWS := 6
# Only the two stepped-side-plane roles sample the image-derived trim sheet in
# production. Give them most of the horizontal texel budget. The four clean
# roles retain small disjoint islands for deterministic importer tangents and
# inspectable UV evidence, but their materials intentionally sample no maps.
const UV_ATLAS_COLUMN_WEIGHTS := [0.06, 0.06, 0.38, 0.38, 0.06, 0.06]
const ATLAS_SAMPLING_ROLES := ["lower_side_planes", "upper_side_planes"]
const ATLAS_SAMPLING_SEMANTICS := [
	"PortLowerSidePlane", "StarboardLowerSidePlane",
	"PortUpperSidePlane", "StarboardUpperSidePlane",
]
const UV_DOMINANT_AXIS_TIE_EPSILON := 0.0005
# These hashes exclude only `vt` records. They pin the exact pre-UV-pass
# positions, normals, object/material declarations and indexed triangle stream,
# so this mapping revision cannot quietly change the authored geometry.
const EXPECTED_GEOMETRY_ONLY_SHA256 := {
	0: "91a24751b27f9e30949241db18914f3ca9820324d0ecf29f5507fc89c9820050",
	1: "c1da2f93e70fb30d30e2db5da2c1ad75e00988d9339944af49672026548cb856",
}

var _objects: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var verify_checked_in := "--verify-checked-in" in OS.get_cmdline_user_args()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Unable to create Torrent authored asset directory: %s" % error_string(directory_error))
		quit(1)
		return

	var lod_records: Array[Dictionary] = []
	for lod: int in [0, 1]:
		_objects.clear()
		_build_macroform(lod)
		_assign_semantic_uv_atlas()
		var record := _write_obj(lod, LOD_PATHS[lod], not verify_checked_in)
		if record.is_empty():
			quit(1)
			return
		lod_records.append(record)

	var manifest := _build_manifest(lod_records)
	var manifest_text := JSON.stringify(manifest, "\t", false) + "\n"
	if verify_checked_in:
		if _read_text(MANIFEST_PATH) != manifest_text:
			push_error("Checked-in Torrent manifest is not reproducible")
			quit(1)
			return
		print("TORRENT_AUTHORED_ASSET_DETERMINISM_OK: checked-in outputs reproduced without writes")
		quit(0)
		return
	if not _write_text(MANIFEST_PATH, manifest_text):
		quit(1)
		return
	print("TORRENT_AUTHORED_ASSET_GENERATION_OK: 2 deterministic OBJ LODs")
	quit(0)


func _build_macroform(lod: int) -> void:
	# The low LOD is rebuilt analytically. It retains every semantic landmark and
	# exact silhouette extremum instead of depending on a destructive decimator.
	var nose_stations: Array = [
		Vector3(0.06, 0.08, -4.80),
		Vector3(0.22, 0.20, -4.58),
		Vector3(0.42, 0.34, -4.32),
		Vector3(0.66, 0.46, -4.02),
		Vector3(0.92, 0.56, -3.70),
		Vector3(1.18, 0.62, -3.34),
		Vector3(1.38, 0.67, -2.98),
		Vector3(1.54, 0.70, -2.62),
		Vector3(1.66, 0.72, -2.25),
		Vector3(1.74, 0.73, -1.94),
		Vector3(1.84, 0.72, -1.62),
	] if lod == 0 else [
		Vector3(0.06, 0.08, -4.80),
		Vector3(0.54, 0.40, -4.16),
		Vector3(1.18, 0.62, -3.34),
		Vector3(1.66, 0.72, -2.25),
		Vector3(1.84, 0.72, -1.62),
	]
	_add_loft("PointedNose", 0.92, nose_stations, "torrent_hull_ivory", 10)

	var keel_stations: Array = [
		Vector3(1.78, 0.64, -1.70),
		Vector3(1.82, 0.67, -1.32),
		Vector3(1.86, 0.70, -0.90),
		Vector3(1.88, 0.72, -0.55),
		Vector3(1.90, 0.75, 0.05),
		Vector3(1.92, 0.78, 0.72),
		Vector3(1.92, 0.78, 1.35),
		Vector3(1.92, 0.92, 2.16),
		# This retained ventral extent locks both LODs to the documented modern
		# normalization AABB without introducing gameplay landing gear.
		Vector3(1.92, 1.15, 3.48),
	] if lod == 0 else [
		Vector3(1.78, 0.64, -1.70),
		Vector3(1.88, 0.72, -0.55),
		Vector3(1.92, 0.78, 1.35),
		Vector3(1.92, 1.15, 3.48),
	]
	_add_loft("CentralPressureKeel", 0.76, keel_stations, "torrent_hull_ivory", 10)

	_begin_object("RaisedSpine", "torrent_hull_light")
	if lod == 0:
		_add_rounded_box(Vector3(-1.32, 2.03, -0.25), Vector3(0.46, 0.72, 3.55), 0.08)
		_add_rounded_box(Vector3(1.32, 2.03, -0.25), Vector3(0.46, 0.72, 3.55), 0.08)
		_add_rounded_box(Vector3(0.0, 2.62, 1.78), Vector3(2.74, 1.14, 1.45), 0.12)
		_add_rounded_box(Vector3(0.0, 2.22, -1.72), Vector3(1.62, 0.34, 1.12), 0.07)
		_add_rounded_box(Vector3(0.0, 3.42, 1.92), Vector3(1.18, 0.42, 0.72), 0.08)
		# Shallow centreline ribs break the large roof without inventing a system.
		_add_rounded_box(Vector3(0.0, 3.67, 1.92), Vector3(0.32, 0.08, 0.50), 0.025)
	else:
		_add_box(Vector3(-1.32, 2.03, -0.25), Vector3(0.46, 0.72, 3.55))
		_add_box(Vector3(1.32, 2.03, -0.25), Vector3(0.46, 0.72, 3.55))
		_add_box(Vector3(0.0, 2.62, 1.78), Vector3(2.74, 1.14, 1.45))
		_add_box(Vector3(0.0, 2.22, -1.72), Vector3(1.62, 0.34, 1.12))
		_add_box(Vector3(0.0, 3.42, 1.92), Vector3(1.18, 0.42, 0.72))

	_begin_object("BlockyAftBody", "torrent_hull_ivory")
	if lod == 0:
		_add_rounded_box(Vector3(0.0, 1.20, 2.55), Vector3(3.84, 2.08, 2.08), 0.13)
		_add_rounded_box(Vector3(0.0, 2.36, 2.62), Vector3(3.28, 0.42, 1.65), 0.08)
		_add_rounded_box(Vector3(0.0, 1.20, 3.57), Vector3(3.10, 1.45, 0.06), 0.02)
		# A restrained raised frame gives the dark aft plane readable depth. Its
		# function remains explicitly unknown in the presentation metadata.
		_add_rounded_box(Vector3(-1.43, 1.20, 3.595), Vector3(0.10, 1.26, 0.01), 0.004)
		_add_rounded_box(Vector3(1.43, 1.20, 3.595), Vector3(0.10, 1.26, 0.01), 0.004)
		_add_rounded_box(Vector3(0.0, 1.79, 3.595), Vector3(2.76, 0.08, 0.01), 0.004)
		_add_rounded_box(Vector3(0.0, 0.61, 3.595), Vector3(2.76, 0.08, 0.01), 0.004)
	else:
		_add_box(Vector3(0.0, 1.20, 2.55), Vector3(3.84, 2.08, 2.08))
		_add_box(Vector3(0.0, 2.36, 2.62), Vector3(3.28, 0.42, 1.65))
		_add_box(Vector3(0.0, 1.20, 3.57), Vector3(3.10, 1.45, 0.06))

	_add_beveled_planform("PortLowerSidePlane", PackedVector2Array([
		Vector2(-1.10, -3.35), Vector2(-1.85, -3.15), Vector2(-3.15, -1.40),
		Vector2(-3.60, 0.20), Vector2(-3.52, 2.65), Vector2(-2.75, 3.20), Vector2(-1.65, 2.70),
	]), 0.56, 0.30, "torrent_hull_light", lod)
	_add_side_plane_relief(-1.0, false, lod)
	_add_beveled_planform("PortUpperSidePlane", PackedVector2Array([
		Vector2(-1.25, -2.55), Vector2(-1.85, -2.35), Vector2(-3.42, -0.55),
		Vector2(-3.36, 2.35), Vector2(-2.45, 2.95), Vector2(-1.48, 2.45),
	]), 0.91, 0.24, "torrent_hull_ivory", lod)
	_add_side_plane_relief(-1.0, true, lod)
	_add_beveled_planform("StarboardLowerSidePlane", PackedVector2Array([
		Vector2(1.10, -3.35), Vector2(1.65, 2.70), Vector2(2.75, 3.20),
		Vector2(3.52, 2.65), Vector2(3.60, 0.20), Vector2(3.15, -1.40), Vector2(1.85, -3.15),
	]), 0.56, 0.30, "torrent_hull_light", lod)
	_add_side_plane_relief(1.0, false, lod)
	_add_beveled_planform("StarboardUpperSidePlane", PackedVector2Array([
		Vector2(1.25, -2.55), Vector2(1.48, 2.45), Vector2(2.45, 2.95),
		Vector2(3.36, 2.35), Vector2(3.42, -0.55), Vector2(1.85, -2.35),
	]), 0.91, 0.24, "torrent_hull_ivory", lod)
	_add_side_plane_relief(1.0, true, lod)

	var housing_profile := PackedVector2Array([
		Vector2(-1.675, 0.32), Vector2(-1.62, 0.36), Vector2(-1.54, 0.40),
		Vector2(-1.39, 0.40), Vector2(-1.31, 0.36), Vector2(-0.55, 0.36),
		Vector2(-0.47, 0.39), Vector2(0.47, 0.39), Vector2(0.55, 0.36),
		Vector2(1.31, 0.36), Vector2(1.39, 0.40), Vector2(1.54, 0.40),
		Vector2(1.62, 0.36), Vector2(1.675, 0.32),
	]) if lod == 0 else PackedVector2Array([
		Vector2(-1.675, 0.34), Vector2(-1.55, 0.40),
		Vector2(1.55, 0.40), Vector2(1.675, 0.34),
	])
	_add_profiled_cylinder("PortAftCircularHousing", Vector3(-2.52, 1.02, 1.925), housing_profile, 16 if lod == 0 else 12, "torrent_hull_light")
	_add_profiled_cylinder("StarboardAftCircularHousing", Vector3(2.52, 1.02, 1.925), housing_profile, 16 if lod == 0 else 12, "torrent_hull_light")

	_begin_object("PortAftRail", "torrent_hull_ivory")
	if lod == 0:
		_add_rounded_box(Vector3(-1.55, 2.91, 2.58), Vector3(0.24, 2.48, 0.34), 0.055)
		_add_rounded_box(Vector3(-1.55, 1.72, 2.38), Vector3(0.46, 0.30, 0.72), 0.065)
		_add_rounded_box(Vector3(-1.55, 2.22, 2.39), Vector3(0.16, 1.05, 0.18), 0.04, 0, Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
	else:
		_add_box(Vector3(-1.55, 2.91, 2.58), Vector3(0.24, 2.48, 0.34))
		_add_box(Vector3(-1.55, 1.72, 2.38), Vector3(0.46, 0.30, 0.72))
	_begin_object("StarboardAftRail", "torrent_hull_ivory")
	if lod == 0:
		_add_rounded_box(Vector3(1.55, 2.91, 2.58), Vector3(0.24, 2.48, 0.34), 0.055)
		_add_rounded_box(Vector3(1.55, 1.72, 2.38), Vector3(0.46, 0.30, 0.72), 0.065)
		_add_rounded_box(Vector3(1.55, 2.22, 2.39), Vector3(0.16, 1.05, 0.18), 0.04, 0, Basis(Vector3.RIGHT, deg_to_rad(18.0)))
	else:
		_add_box(Vector3(1.55, 2.91, 2.58), Vector3(0.24, 2.48, 0.34))
		_add_box(Vector3(1.55, 1.72, 2.38), Vector3(0.46, 0.30, 0.72))
	_begin_object("AftCrossbar", "torrent_hull_ivory")
	if lod == 0:
		_add_rounded_box(Vector3(0.0, 4.06, 2.58), Vector3(3.34, 0.18, 0.34), 0.045)
		_add_rounded_box(Vector3(0.0, 3.995, 2.58), Vector3(1.15, 0.05, 0.20), 0.018)
	else:
		_add_box(Vector3(0.0, 4.06, 2.58), Vector3(3.34, 0.18, 0.34))


func _begin_object(object_name: String, material_name: String) -> void:
	_objects.append({
		"name": object_name,
		"material": material_name,
		"positions": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"uv_projection_bounds": [],
		"faces": PackedInt32Array(),
	})


func _add_box(center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var corners := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	_add_quad(corners[0], corners[3], corners[2], corners[1])
	_add_quad(corners[4], corners[5], corners[6], corners[7])
	_add_quad(corners[0], corners[4], corners[7], corners[3])
	_add_quad(corners[1], corners[2], corners[6], corners[5])
	_add_quad(corners[0], corners[1], corners[5], corners[4])
	_add_quad(corners[3], corners[7], corners[6], corners[2])


func _add_rounded_box(
	center: Vector3,
	size: Vector3,
	bevel_radius: float,
	bevel_segments: int = 0,
	basis: Basis = Basis.IDENTITY
) -> void:
	# A deterministic authored chamfered solid. Samples are concentrated at the
	# bevel transitions so triangles describe curved/chamfered edges rather than
	# merely subdividing a flat box face.
	var half := size * 0.5
	var radius := minf(bevel_radius, minf(half.x, minf(half.y, half.z)) * 0.45)
	if radius <= 0.00001:
		_add_box(center, size)
		return
	var inner := half - Vector3.ONE * radius
	var xs := _rounded_axis_samples(half.x, radius, bevel_segments)
	var ys := _rounded_axis_samples(half.y, radius, bevel_segments)
	var zs := _rounded_axis_samples(half.z, radius, bevel_segments)
	for yi in range(ys.size() - 1):
		for zi in range(zs.size() - 1):
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(half.x, ys[yi], zs[zi]),
				Vector3(half.x, ys[yi + 1], zs[zi]),
				Vector3(half.x, ys[yi + 1], zs[zi + 1]),
				Vector3(half.x, ys[yi], zs[zi + 1]),
			])
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(-half.x, ys[yi], zs[zi]),
				Vector3(-half.x, ys[yi], zs[zi + 1]),
				Vector3(-half.x, ys[yi + 1], zs[zi + 1]),
				Vector3(-half.x, ys[yi + 1], zs[zi]),
			])
	for xi in range(xs.size() - 1):
		for zi in range(zs.size() - 1):
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(xs[xi], half.y, zs[zi]),
				Vector3(xs[xi], half.y, zs[zi + 1]),
				Vector3(xs[xi + 1], half.y, zs[zi + 1]),
				Vector3(xs[xi + 1], half.y, zs[zi]),
			])
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(xs[xi], -half.y, zs[zi]),
				Vector3(xs[xi + 1], -half.y, zs[zi]),
				Vector3(xs[xi + 1], -half.y, zs[zi + 1]),
				Vector3(xs[xi], -half.y, zs[zi + 1]),
			])
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(xs[xi], ys[yi], half.z),
				Vector3(xs[xi + 1], ys[yi], half.z),
				Vector3(xs[xi + 1], ys[yi + 1], half.z),
				Vector3(xs[xi], ys[yi + 1], half.z),
			])
			_add_rounded_box_quad(center, inner, radius, basis, [
				Vector3(xs[xi], ys[yi], -half.z),
				Vector3(xs[xi], ys[yi + 1], -half.z),
				Vector3(xs[xi + 1], ys[yi + 1], -half.z),
				Vector3(xs[xi + 1], ys[yi], -half.z),
			])


func _rounded_axis_samples(half_extent: float, radius: float, bevel_segments: int) -> PackedFloat32Array:
	var inner := half_extent - radius
	var samples := PackedFloat32Array([-half_extent])
	for segment in bevel_segments:
		var t := float(segment + 1) / float(bevel_segments + 1)
		samples.append(lerpf(-half_extent, -inner, t))
	samples.append(-inner)
	samples.append(inner)
	for segment in bevel_segments:
		var t := float(segment + 1) / float(bevel_segments + 1)
		samples.append(lerpf(inner, half_extent, t))
	samples.append(half_extent)
	return samples


func _add_rounded_box_quad(
	center: Vector3,
	inner: Vector3,
	radius: float,
	basis: Basis,
	points: Array
) -> void:
	var rounded: Array[Vector3] = []
	for value: Variant in points:
		var point := value as Vector3
		var nearest := Vector3(
			clampf(point.x, -inner.x, inner.x),
			clampf(point.y, -inner.y, inner.y),
			clampf(point.z, -inner.z, inner.z)
		)
		var offset := point - nearest
		var local_point := nearest + offset.normalized() * radius
		rounded.append(center + basis * local_point)
	_add_quad(rounded[0], rounded[1], rounded[2], rounded[3])


func _add_loft(
	object_name: String,
	center_y: float,
	stations: Array,
	material_name: String,
	ring_point_count: int = 8
) -> void:
	_begin_object(object_name, material_name)
	var rings: Array[Array] = []
	for station_value: Variant in stations:
		var station := station_value as Vector3
		var profile := PackedVector2Array([
			Vector2(-0.58, 1.0), Vector2(0.58, 1.0),
			Vector2(0.88, 0.70), Vector2(1.0, 0.22), Vector2(1.0, -0.56),
			Vector2(0.62, -1.0), Vector2(-0.62, -1.0),
			Vector2(-1.0, -0.56), Vector2(-1.0, 0.22), Vector2(-0.88, 0.70),
		])
		var ring: Array[Vector3] = []
		for point_index in mini(ring_point_count, profile.size()):
			var point := profile[point_index]
			ring.append(Vector3(point.x * station.x, center_y + point.y * station.y, station.z))
		rings.append(ring)
	for ring_index in rings.size() - 1:
		for point_index in ring_point_count:
			var next := (point_index + 1) % ring_point_count
			_add_quad(rings[ring_index][point_index], rings[ring_index + 1][point_index], rings[ring_index + 1][next], rings[ring_index][next])
	var front := rings[0]
	var rear := rings[rings.size() - 1]
	_add_cap(front, true)
	_add_cap(rear, false)


func _add_planform(object_name: String, points: PackedVector2Array, center_y: float, thickness: float, material_name: String) -> void:
	_begin_object(object_name, material_name)
	var upper: Array[Vector3] = []
	var lower: Array[Vector3] = []
	for point: Vector2 in points:
		upper.append(Vector3(point.x, center_y + thickness * 0.5, point.y))
		lower.append(Vector3(point.x, center_y - thickness * 0.5, point.y))
	_add_cap(upper, false)
	_add_cap(lower, true)
	for index in points.size():
		var next := (index + 1) % points.size()
		_add_quad(upper[index], lower[index], lower[next], upper[next])


func _add_beveled_planform(
	object_name: String,
	points: PackedVector2Array,
	center_y: float,
	thickness: float,
	material_name: String,
	lod: int
) -> void:
	if lod != 0:
		_add_planform(object_name, points, center_y, thickness, material_name)
		return
	_begin_object(object_name, material_name)
	var centroid := Vector2.ZERO
	for point: Vector2 in points:
		centroid += point
	centroid /= float(points.size())
	var inset_fraction := 0.035
	var outer_upper: Array[Vector3] = []
	var outer_lower: Array[Vector3] = []
	var inner_upper: Array[Vector3] = []
	var inner_lower: Array[Vector3] = []
	for point: Vector2 in points:
		var inset := point.lerp(centroid, inset_fraction)
		outer_upper.append(Vector3(point.x, center_y + thickness * 0.30, point.y))
		outer_lower.append(Vector3(point.x, center_y - thickness * 0.30, point.y))
		inner_upper.append(Vector3(inset.x, center_y + thickness * 0.50, inset.y))
		inner_lower.append(Vector3(inset.x, center_y - thickness * 0.50, inset.y))
	_add_cap(inner_upper, false)
	_add_cap(inner_lower, true)
	for index in points.size():
		var next := (index + 1) % points.size()
		_add_quad(inner_upper[index], inner_upper[next], outer_upper[next], outer_upper[index])
		_add_quad(outer_upper[index], outer_lower[index], outer_lower[next], outer_upper[next])
		_add_quad(inner_lower[index], outer_lower[index], outer_lower[next], inner_lower[next])


func _add_side_plane_relief(side: float, upper_tier: bool, lod: int) -> void:
	if lod != 0:
		return
	var top_y := 1.03 if upper_tier else 0.71
	var sign_angle := -1.0 if side < 0.0 else 1.0
	var first_center := Vector3(side * (2.12 if upper_tier else 2.18), top_y + 0.035, -0.55)
	var second_center := Vector3(side * (2.58 if upper_tier else 2.66), top_y + 0.035, 1.46)
	_add_rounded_box(
		first_center,
		Vector3(0.34, 0.07, 1.34 if upper_tier else 1.55),
		0.028,
		0,
		Basis(Vector3.UP, deg_to_rad(sign_angle * 9.0))
	)
	_add_rounded_box(
		second_center,
		Vector3(0.30, 0.07, 1.18 if upper_tier else 1.42),
		0.028,
		0,
		Basis(Vector3.UP, deg_to_rad(sign_angle * -7.0))
	)


func _add_cylinder(object_name: String, center: Vector3, radius: float, length: float, segments: int, material_name: String) -> void:
	_begin_object(object_name, material_name)
	var front_z := center.z - length * 0.5
	var rear_z := center.z + length * 0.5
	var front: Array[Vector3] = []
	var rear: Array[Vector3] = []
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		var radial := Vector2(cos(angle), sin(angle)) * radius
		front.append(Vector3(center.x + radial.x, center.y + radial.y, front_z))
		rear.append(Vector3(center.x + radial.x, center.y + radial.y, rear_z))
	for index in segments:
		var next := (index + 1) % segments
		_add_quad(front[index], rear[index], rear[next], front[next])
	_add_cap(front, true)
	_add_cap(rear, false)


func _add_profiled_cylinder(
	object_name: String,
	center: Vector3,
	profile: PackedVector2Array,
	segments: int,
	material_name: String
) -> void:
	_begin_object(object_name, material_name)
	var rings: Array[Array] = []
	for profile_point: Vector2 in profile:
		var ring: Array[Vector3] = []
		for index in segments:
			var angle := TAU * float(index) / float(segments)
			ring.append(Vector3(
				center.x + cos(angle) * profile_point.y,
				center.y + sin(angle) * profile_point.y,
				center.z + profile_point.x
			))
		rings.append(ring)
	for ring_index in range(rings.size() - 1):
		for point_index in segments:
			var next := (point_index + 1) % segments
			_add_quad(
				rings[ring_index][point_index],
				rings[ring_index + 1][point_index],
				rings[ring_index + 1][next],
				rings[ring_index][next]
			)
	_add_cap(rings[0], true)
	_add_cap(rings[-1], false)


func _add_cap(ring: Array, reverse: bool) -> void:
	var center := Vector3.ZERO
	for point_value: Variant in ring:
		center += point_value as Vector3
	center /= float(ring.size())
	for index in ring.size():
		var next := (index + 1) % ring.size()
		if reverse:
			_add_triangle(center, ring[next], ring[index])
		else:
			_add_triangle(center, ring[index], ring[next])


func _add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(a, b, c)
	_add_triangle(a, c, d)


func _add_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var current := _objects[-1]
	var positions := current.positions as PackedVector3Array
	var normals := current.normals as PackedVector3Array
	var uvs := current.uvs as PackedVector2Array
	var faces := current.faces as PackedInt32Array
	var base := positions.size()
	for point: Vector3 in [a, b, c]:
		positions.append(point)
		normals.append(normal)
		uvs.append(Vector2.ZERO)
		faces.append(base)
		base += 1
	current.positions = positions
	current.normals = normals
	current.uvs = uvs
	current.faces = faces
	_objects[-1] = current


func _assign_semantic_uv_atlas() -> void:
	for object_index in _objects.size():
		var object := _objects[object_index]
		var positions := object.positions as PackedVector3Array
		var normals := object.normals as PackedVector3Array
		var projection_bounds := _projection_bounds(positions, normals)
		var remapped := PackedVector2Array()
		for vertex_index in positions.size():
			remapped.append(_atlas_uv(str(object.name), positions[vertex_index], normals[vertex_index], projection_bounds))
		object.uvs = remapped
		object.uv_projection_bounds = _projection_bounds_records(projection_bounds)
		_objects[object_index] = object


func _atlas_uv(
	component_name: String,
	point: Vector3,
	normal: Vector3,
	projection_bounds: Array[Rect2]
) -> Vector2:
	# One guarded atlas island is reserved for every declared visual role and
	# signed dominant face direction. Related/mirrored semantics deliberately
	# share their role; unrelated roles cannot overlap. LOD0 and LOD1 share the
	# layout while retaining their own local projection bounds.
	var role_index := _uv_role_index(component_name)
	assert(role_index >= 0, "Unknown Torrent semantic component role")
	var signed_axis_index := _signed_dominant_axis_index(normal)
	var projected := _dominant_axis_projection(point, signed_axis_index)
	var bounds := projection_bounds[signed_axis_index]
	var local := Vector2(
		(projected.x - bounds.position.x) / bounds.size.x,
		(projected.y - bounds.position.y) / bounds.size.y
	)
	var island := _atlas_island_rect(role_index, signed_axis_index)
	return island.position + local.clamp(Vector2.ZERO, Vector2.ONE) * island.size


func _uv_role_index(component_name: String) -> int:
	for role_index in UV_ROLE_MEMBERS.size():
		if component_name in UV_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _projection_bounds(positions: PackedVector3Array, normals: PackedVector3Array) -> Array[Rect2]:
	var minimums: Array[Vector2] = []
	var maximums: Array[Vector2] = []
	var used := PackedByteArray()
	used.resize(SIGNED_AXIS_ORDER.size())
	for axis_index in SIGNED_AXIS_ORDER.size():
		minimums.append(Vector2(INF, INF))
		maximums.append(Vector2(-INF, -INF))
	for vertex_index in positions.size():
		var axis_index := _signed_dominant_axis_index(normals[vertex_index])
		var projected := _dominant_axis_projection(positions[vertex_index], axis_index)
		minimums[axis_index] = minimums[axis_index].min(projected)
		maximums[axis_index] = maximums[axis_index].max(projected)
		used[axis_index] = 1
	var bounds: Array[Rect2] = []
	for axis_index in SIGNED_AXIS_ORDER.size():
		assert(used[axis_index] != 0, "Every semantic component must exercise all signed axes")
		var size := maximums[axis_index] - minimums[axis_index]
		assert(size.x > 0.000001 and size.y > 0.000001, "UV projection bounds must be two-dimensional")
		bounds.append(Rect2(minimums[axis_index], size))
	return bounds


func _projection_bounds_records(bounds: Array[Rect2]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for axis_index in SIGNED_AXIS_ORDER.size():
		var bound := bounds[axis_index]
		records.append({
			"signed_axis": SIGNED_AXIS_ORDER[axis_index],
			"projected_min": [_rounded(bound.position.x), _rounded(bound.position.y)],
			"projected_max": [_rounded(bound.end.x), _rounded(bound.end.y)],
		})
	return records


func _signed_dominant_axis_index(normal: Vector3) -> int:
	# Stable X > Y > Z tie-breaking makes diagonal chamfers deterministic.
	# Godot's tangent import can perturb diagonal authored normals by a few
	# ten-thousandths. A narrow documented tie band keeps those faces in the same
	# deterministic island while retaining X > Y > Z priority.
	var absolute := normal.abs()
	var maximum := maxf(absolute.x, maxf(absolute.y, absolute.z))
	if absolute.x >= maximum - UV_DOMINANT_AXIS_TIE_EPSILON:
		return 0 if normal.x >= 0.0 else 1
	if absolute.y >= maximum - UV_DOMINANT_AXIS_TIE_EPSILON:
		return 2 if normal.y >= 0.0 else 3
	return 4 if normal.z >= 0.0 else 5


func _dominant_axis_projection(point: Vector3, signed_axis_index: int) -> Vector2:
	var x := (point.x + 3.60) / 7.20
	var y := (point.y + 0.39) / 4.54
	var z := (point.z + 4.80) / 8.40
	match signed_axis_index:
		0: # +X: looking inward from starboard.
			return Vector2(z, y)
		1: # -X: mirror U so port and starboard tangent frames remain coherent.
			return Vector2(1.0 - z, y)
		2: # +Y: dorsal projection follows the planform.
			return Vector2(x, z)
		3: # -Y: mirror V for the ventral face.
			return Vector2(x, 1.0 - z)
		4: # +Z: looking inward from aft.
			return Vector2(1.0 - x, y)
		_: # -Z: looking inward from forward.
			return Vector2(x, y)


func _atlas_island_rect(role_index: int, signed_axis_index: int) -> Rect2:
	var guarded_size := 1.0 - UV_ATLAS_OUTER_GUARD * 2.0
	var normalized_column_start := 0.0
	for previous_role_index in role_index:
		normalized_column_start += float(UV_ATLAS_COLUMN_WEIGHTS[previous_role_index])
	var cell_size := Vector2(
		guarded_size * float(UV_ATLAS_COLUMN_WEIGHTS[role_index]),
		guarded_size / float(UV_ATLAS_ROWS)
	)
	var cell_origin := Vector2(
		UV_ATLAS_OUTER_GUARD + guarded_size * normalized_column_start,
		UV_ATLAS_OUTER_GUARD + float(signed_axis_index) * cell_size.y
	)
	return Rect2(
		cell_origin + Vector2.ONE * UV_ATLAS_CELL_GUTTER,
		cell_size - Vector2.ONE * UV_ATLAS_CELL_GUTTER * 2.0
	)


func _write_obj(lod: int, path: String, write_outputs: bool) -> Dictionary:
	var lines := PackedStringArray([
		"# Torrent dated-2011 source-aligned partial macroform LOD%d" % lod,
		"# Deterministic project-authored geometry; exact geometry/authenticity false",
		"# +Y up, -Z forward, metres; no collision authority",
	])
	var vertex_offset := 1
	var total_vertices := 0
	var total_triangles := 0
	var object_records: Array[Dictionary] = []
	var total_bounds := AABB()
	var has_bounds := false
	for object: Dictionary in _objects:
		var positions := object.positions as PackedVector3Array
		var normals := object.normals as PackedVector3Array
		var uvs := object.uvs as PackedVector2Array
		var faces := object.faces as PackedInt32Array
		lines.append("")
		lines.append("o %s" % object.name)
		lines.append("usemtl %s" % object.material)
		var object_bounds := AABB()
		var object_has_bounds := false
		for point: Vector3 in positions:
			lines.append("v %s %s %s" % [_float_text(point.x), _float_text(point.y), _float_text(point.z)])
			if not object_has_bounds:
				object_bounds = AABB(point, Vector3.ZERO)
				object_has_bounds = true
			else:
				object_bounds = object_bounds.expand(point)
			if not has_bounds:
				total_bounds = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				total_bounds = total_bounds.expand(point)
		for uv: Vector2 in uvs:
			lines.append("vt %s %s" % [_float_text(uv.x), _float_text(1.0 - uv.y)])
		for normal: Vector3 in normals:
			lines.append("vn %s %s %s" % [_float_text(normal.x), _float_text(normal.y), _float_text(normal.z)])
		for face_index in range(0, faces.size(), 3):
			var indices := [
				vertex_offset + faces[face_index],
				vertex_offset + faces[face_index + 1],
				vertex_offset + faces[face_index + 2],
			]
			lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [
				indices[0], indices[0], indices[0],
				indices[1], indices[1], indices[1],
				indices[2], indices[2], indices[2],
			])
		object_records.append({
			"name": str(object.name),
			"uv_role": UV_ROLE_ORDER[_uv_role_index(str(object.name))],
			"vertex_count": positions.size(),
			"triangle_count": faces.size() / 3,
			"aabb": _aabb_record(object_bounds),
			"uv_projection_bounds": (object.uv_projection_bounds as Array).duplicate(true),
		})
		vertex_offset += positions.size()
		total_vertices += positions.size()
		total_triangles += faces.size() / 3
	var text := "\n".join(lines) + "\n"
	var geometry_sha256 := _sha256_text(_without_uv_records(text))
	if geometry_sha256 != str(EXPECTED_GEOMETRY_ONLY_SHA256[lod]):
		push_error("LOD%d geometry changed during the UV-only atlas pass" % lod)
		return {}
	if write_outputs:
		if not _write_text(path, text):
			return {}
	elif _read_text(path) != text:
		push_error("Checked-in LOD%d aggregate OBJ is not reproducible" % lod)
		return {}
	var component_records: Array[Dictionary] = []
	for object: Dictionary in _objects:
		var component_path := (
			OUTPUT_ROOT + "/torrent_macroform_lod%d_%s.obj"
			% [lod, str(object.name).to_snake_case()]
		)
		var component_text := _component_obj_text(lod, object)
		if write_outputs:
			if not _write_text(component_path, component_text):
				return {}
		elif _read_text(component_path) != component_text:
			push_error("Checked-in LOD%d %s component OBJ is not reproducible" % [lod, str(object.name)])
			return {}
		component_records.append({
			"name": str(object.name),
			"path": component_path,
			"sha256": _sha256_text(component_text),
			"bytes": component_text.to_utf8_buffer().size(),
		})
	return {
		"lod": lod,
		"path": path,
		"sha256": _sha256_text(text),
		"geometry_only_sha256": geometry_sha256,
		"bytes": text.to_utf8_buffer().size(),
		"vertex_count": total_vertices,
		"triangle_count": total_triangles,
		"object_count": _objects.size(),
		"objects": object_records,
		"component_artifacts": component_records,
		"aabb": _aabb_record(total_bounds),
	}


func _component_obj_text(lod: int, object: Dictionary) -> String:
	var positions := object.positions as PackedVector3Array
	var normals := object.normals as PackedVector3Array
	var uvs := object.uvs as PackedVector2Array
	var faces := object.faces as PackedInt32Array
	var lines := PackedStringArray([
		"# Torrent authored macroform LOD%d semantic component" % lod,
		"# Imported production resource; exact geometry/authenticity false",
		"o %s" % object.name,
		"usemtl %s" % object.material,
	])
	for point: Vector3 in positions:
		lines.append("v %s %s %s" % [_float_text(point.x), _float_text(point.y), _float_text(point.z)])
	for uv: Vector2 in uvs:
		lines.append("vt %s %s" % [_float_text(uv.x), _float_text(1.0 - uv.y)])
	for normal: Vector3 in normals:
		lines.append("vn %s %s %s" % [_float_text(normal.x), _float_text(normal.y), _float_text(normal.z)])
	for face_index in range(0, faces.size(), 3):
		var a := faces[face_index] + 1
		var b := faces[face_index + 1] + 1
		var c := faces[face_index + 2] + 1
		lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [a, a, a, b, b, b, c, c, c])
	return "\n".join(lines) + "\n"


func _build_manifest(lods: Array[Dictionary]) -> Dictionary:
	return {
		"schema_version": 2,
		"asset_id": "torrent_dated_2011_authored_macroform",
		"asset_revision": "v2",
		"generator_path": "res://tools/generate_torrent_authored_assets.gd",
		"generation_command": GENERATION_COMMAND,
		"toolchain": "Godot 4.7.1 deterministic GDScript OBJ writer",
		"coordinate_contract": {"units": "metres", "up": "+Y", "forward": "-Z", "root_transform": "identity"},
		"lod_strategy": {"count": 2, "manual_switch_distance_m": 60.0, "automatic_import_lods": false, "lod1_method": "analytic_rebuild"},
		"geometry_refinement": {
			"revision": "bounded_authored_relief_v2",
			"lod0_triangle_target": [3000, 6000],
			"lod1_maximum_fraction_of_lod0": 0.25,
			"features": [
				"restrained chamfers on primary pressure-body, aft-body and rail solids",
				"shallow non-functional structural relief on the stepped side planes",
				"stepped collars on source-observed aft circular housings",
				"faceted longitudinal transitions on the nose and central keel",
			],
			"exact_aabb_locked": true,
			"new_historical_claims": false,
		},
		"required_objects": REQUIRED_OBJECTS.duplicate(),
		"lods": lods,
		"provenance": {
			"identity_lock": "dated_2011",
			"historical_revision": "2011",
			"source_references": ["B5"],
			"source_upload_date": "2011-06-29",
			"source_rendition_sha256": SOURCE_RENDITION_SHA256,
			"geometry_status": "source_aligned_partial",
			"reconstruction_status": "partial",
			"authenticated_geometry": false,
			"exact_geometry": false,
			"authenticated_exact_geometry": false,
			"authenticated_historical_silhouette": false,
			"2009_continuity": "unproved",
			"absolute_scale_status": "modern_ergonomic_normalization",
			"copied_source_geometry": false,
			"bilateral_symmetry": "modern_reconstruction_assumption",
			"aft_housing_historical_function": "unknown",
			"aft_crossbar_evidence_status": "inferred_reconstruction",
			"aft_crossbar_historically_supported": false,
		},
		"texture_contract": {
			"origin": "modern_project_original",
			"mapping": "intentional_non_seamless_weighted_role_signed_axis_trim_v2",
			"uv_set": 0,
			"triplanar": false,
			"repeat": false,
			"source_kind": "image_derived_proxy_trim_atlas",
			"final_hand_authored_pbr": false,
			"production_usage": "selected_stepped_side_planes_only",
			"atlas_sampling_roles": ATLAS_SAMPLING_ROLES.duplicate(),
			"atlas_sampling_semantics": ATLAS_SAMPLING_SEMANTICS.duplicate(),
			"uv_layout": _atlas_layout_manifest(),
			"source_albedo": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-v1.png",
			"runtime_albedo": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png",
			"runtime_normal": "res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png",
			"runtime_roughness": "res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png",
			"runtime_orm": "res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png",
			"runtime_emissive": "res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png",
		},
		"content_note": "B5 bounds only the broad dated-2011 macroform. Exact topology, dimensions, UV layout, normals, finish, symmetry, and 2009 continuity are not authenticated.",
	}


func _atlas_layout_manifest() -> Dictionary:
	var islands: Array[Dictionary] = []
	for role_index in UV_ROLE_ORDER.size():
		for signed_axis_index in SIGNED_AXIS_ORDER.size():
			var island := _atlas_island_rect(role_index, signed_axis_index)
			islands.append({
				"role": UV_ROLE_ORDER[role_index],
				"members": (UV_ROLE_MEMBERS[role_index] as Array).duplicate(),
				"signed_axis": SIGNED_AXIS_ORDER[signed_axis_index],
				"column": role_index,
				"row": signed_axis_index,
				"uv_min": [_rounded(island.position.x), _rounded(island.position.y)],
				"uv_max": [_rounded(island.end.x), _rounded(island.end.y)],
			})
	return {
		"layout_id": UV_LAYOUT_ID,
		"semantic_order": REQUIRED_OBJECTS.duplicate(),
		"role_order": UV_ROLE_ORDER.duplicate(),
		"role_members": UV_ROLE_MEMBERS.duplicate(true),
		"signed_axis_order": SIGNED_AXIS_ORDER.duplicate(),
		"columns": UV_ATLAS_COLUMNS,
		"rows": UV_ATLAS_ROWS,
		"column_weights": UV_ATLAS_COLUMN_WEIGHTS.duplicate(),
		"outer_guard": UV_ATLAS_OUTER_GUARD,
		"cell_gutter": UV_ATLAS_CELL_GUTTER,
		"island_count": islands.size(),
		"cross_role_overlap": false,
		"intentional_within_role_reuse": true,
		"cross_semantic_overlap": "within_declared_role_only",
		"cross_signed_axis_overlap": false,
		"lods_share_layout": true,
		"dominant_axis_tie_break": "X_then_Y_then_Z",
		"dominant_axis_tie_epsilon": UV_DOMINANT_AXIS_TIE_EPSILON,
		"obj_v_encoding": "one_minus_internal_v",
		"projection_normalization": "per_lod_semantic_signed_axis_local_bounds",
		"islands": islands,
	}


func _aabb_record(bounds: AABB) -> Dictionary:
	return {
		"position": [_rounded(bounds.position.x), _rounded(bounds.position.y), _rounded(bounds.position.z)],
		"size": [_rounded(bounds.size.x), _rounded(bounds.size.y), _rounded(bounds.size.z)],
	}


func _rounded(value: float) -> float:
	# Five decimal places are more precise than the authored tolerance while
	# avoiding binary subtraction residue such as 8.400001 in the manifest.
	return snappedf(value, 0.00001)


func _float_text(value: float) -> String:
	var normalized := 0.0 if absf(value) < 0.0000005 else value
	return "%.6f" % normalized


func _without_uv_records(obj_text: String) -> String:
	var retained := PackedStringArray()
	for line: String in obj_text.split("\n", true):
		if not line.begins_with("vt "):
			retained.append(line)
	return "\n".join(retained)


func _sha256_text(content: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(content.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _write_text(path: String, content: String) -> bool:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(content)
	file.close()
	return true


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	return file.get_as_text() if file != null else ""
