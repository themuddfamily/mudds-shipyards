class_name PlanetarySurfaceRouteTrailPresentation
extends Node3D

## Presentation-only authored route trail. It renders caller-provided points
## and owns no navigation, pathfinding, activity, movement, or route state.

var _configured := false
var _points: Array[Vector3] = []
var _profile: StringName = &"high"
var _solar: Dictionary = {}
var _weather: Dictionary = {}
static var _shared_mesh: SphereMesh
var _shared_material: StandardMaterial3D
var _marker_multimesh: MultiMesh
var _marker_batch: MultiMeshInstance3D
var _profile_buffers: Dictionary = {}
var _profile_bounds: Dictionary = {}
var _profile_visible_counts: Dictionary = {}
var _submitted_profile: StringName = &""
var _geometry_buffer_build_count := 0
var _geometry_buffer_submission_count := 0

func configure(points: Array) -> Dictionary:
	if _configured or points.is_empty():
		return {"accepted": false, "reason": &"invalid_route_trail_configuration"}
	for point in points:
		if not point is Vector3 or not (point as Vector3).is_finite():
			return {"accepted": false, "reason": &"invalid_route_trail_configuration"}
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.45
		_shared_mesh.height = 0.9
		_shared_mesh.resource_local_to_scene = false
	_shared_material = StandardMaterial3D.new()
	_shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shared_material.emission_enabled = true
	_shared_material.emission = Color(0.2, 0.7, 1.0, 1.0)
	for point in points:
		_points.append(point)
	_marker_multimesh = MultiMesh.new()
	_marker_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_marker_multimesh.mesh = _shared_mesh
	_marker_multimesh.instance_count = _points.size()
	_marker_multimesh.visible_instance_count = 0
	_marker_batch = MultiMeshInstance3D.new()
	_marker_batch.name = "RouteTrailMarkerBatch"
	_marker_batch.multimesh = _marker_multimesh
	_marker_batch.material_override = _shared_material
	_marker_batch.visible = false
	add_child(_marker_batch)
	_configured = true
	return {"accepted": true, "reason": &"configured"}

func apply_presentation_recipe(solar: Variant, weather: Variant) -> Dictionary:
	if not _configured or not solar is Dictionary or not weather is Dictionary:
		return {"accepted": false, "reason": &"invalid_route_trail_recipe"}
	_solar = (solar as Dictionary).duplicate(true)
	_weather = (weather as Dictionary).duplicate(true)
	var elevation := float(_solar.get("sun_elevation_sine", 0.0))
	var intensity := clampf(0.25 + clampf(-elevation, 0.0, 1.0) * 0.75, 0.15, 1.0)
	# Route geometry is immutable after configure(). Solar/weather observations
	# only change readability, so do not rebuild and re-upload the same transforms
	# on every presentation recipe tick.
	if _submitted_profile != _profile:
		_ensure_profile_geometry(_profile)
		_marker_multimesh.buffer = _profile_buffers[_profile]
		_marker_multimesh.custom_aabb = _profile_bounds[_profile]
		_submitted_profile = _profile
		_geometry_buffer_submission_count += 1
	_marker_multimesh.visible_instance_count = int(_profile_visible_counts[_profile])
	_marker_batch.visible = true
	_shared_material.emission_energy_multiplier = intensity
	return {"accepted": true, "reason": &"route_trail_recipe_applied", "marker_count": _points.size()}

func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"medium", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_profile = profile
	if not _solar.is_empty():
		apply_presentation_recipe(_solar, _weather)
	return {"accepted": true, "reason": &"graphics_profile_applied"}

func detach() -> Dictionary:
	if _marker_batch != null:
		_marker_batch.visible = false
	return {"accepted": true, "reason": &"route_trail_detached"}

func reenter() -> Dictionary:
	if _solar.is_empty(): return {"accepted": false, "reason": &"route_trail_reentry_unavailable"}
	return apply_presentation_recipe(_solar, _weather)

func get_snapshot() -> Dictionary:
	var visible_count := 0
	if _marker_batch != null and _marker_batch.visible and _marker_multimesh != null:
		visible_count = _marker_multimesh.visible_instance_count
	return {"configured": _configured, "point_count": _points.size(), "points_body_local_m": _points.duplicate(), "visible_marker_count": visible_count, "graphics_profile": _profile, "shared_mesh": _shared_mesh != null, "shared_material": _shared_material != null, "performance": {"cached_profile_geometry_count": _geometry_buffer_build_count, "geometry_buffer_submissions": _geometry_buffer_submission_count}, "authority": {"navigation": false, "pathfinding": false, "activity": false, "movement": false}}.duplicate(true)

func _stride_for_profile(profile: StringName) -> int:
	return 1 if profile == &"high" else (2 if profile == &"medium" else 3)

func _ensure_profile_geometry(profile: StringName) -> void:
	if _profile_buffers.has(profile):
		return
	var stride := _stride_for_profile(profile)
	_profile_buffers[profile] = _encode_profile_buffer(stride)
	_profile_bounds[profile] = _profile_mesh_bounds(stride)
	_profile_visible_counts[profile] = ceili(float(_points.size()) / float(stride))
	_geometry_buffer_build_count += 1

func _encode_profile_buffer(stride: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	# Keep the buffer at the configured family capacity. Only the compacted prefix
	# is submitted through visible_instance_count for the active profile.
	buffer.resize(_points.size() * 12)
	var visible_index := 0
	for point_index in range(0, _points.size(), stride):
		var offset := visible_index * 12
		buffer[offset + 0] = 1.0
		buffer[offset + 3] = _points[point_index].x
		buffer[offset + 5] = 1.0
		buffer[offset + 7] = _points[point_index].y
		buffer[offset + 10] = 1.0
		buffer[offset + 11] = _points[point_index].z
		visible_index += 1
	return buffer

func _profile_mesh_bounds(stride: int) -> AABB:
	var mesh_bounds := _shared_mesh.get_aabb()
	var bounds := (Transform3D(Basis.IDENTITY, _points[0]) * mesh_bounds).abs()
	for index in range(stride, _points.size(), stride):
		bounds = bounds.merge((Transform3D(Basis.IDENTITY, _points[index]) * mesh_bounds).abs())
	return bounds
