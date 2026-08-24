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
var _next_landmark_label: Label3D
var _profile_buffers: Dictionary = {}
var _profile_bounds: Dictionary = {}
var _profile_visible_counts: Dictionary = {}
var _submitted_profile: StringName = &""
var _geometry_buffer_build_count := 0
var _geometry_buffer_submission_count := 0
var _presentation_generation := 0
var _next_landmark_cue: Dictionary = {}

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
	_next_landmark_label = Label3D.new()
	_next_landmark_label.name = "NextLandmarkCue"
	_next_landmark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# A target hidden by the surface must not read as an unobstructed route.
	_next_landmark_label.no_depth_test = false
	_next_landmark_label.outline_size = 8
	_next_landmark_label.pixel_size = 0.008
	_next_landmark_label.modulate = Color(0.85, 0.95, 1.0, 1.0)
	_next_landmark_label.outline_modulate = Color(0.02, 0.08, 0.14, 1.0)
	_next_landmark_label.visible = false
	add_child(_next_landmark_label)
	_configured = true
	_presentation_generation = 1
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
	if _next_landmark_label != null:
		_next_landmark_label.visible = false
	_next_landmark_cue = {}
	_presentation_generation += 1
	return {"accepted": true, "reason": &"route_trail_detached"}

func reenter() -> Dictionary:
	if _solar.is_empty(): return {"accepted": false, "reason": &"route_trail_reentry_unavailable"}
	return apply_presentation_recipe(_solar, _weather)


func get_presentation_generation() -> int:
	return _presentation_generation


## Renders one static, high-contrast target label from an already computed
## navigation cue. The caller owns both the location observation and lifecycle
## generation; this presentation never polls an input device or advances travel.
func present_next_landmark_feedback(
		feedback: Variant, expected_generation: int, reduced_motion: bool = false
	) -> Dictionary:
	if not _configured or _next_landmark_label == null:
		return _cue_result(false, &"route_trail_unconfigured")
	if expected_generation != _presentation_generation:
		return _cue_result(false, &"stale_presentation_generation")
	if not feedback is Dictionary:
		return _cue_result(false, &"invalid_navigation_feedback")
	var source := feedback as Dictionary
	if not bool(source.get("accepted", false)):
		_clear_next_landmark_cue()
		return _cue_result(true, &"next_landmark_cue_unavailable")
	var cue := source.get("cue", {}) as Dictionary
	if not _valid_cue(cue):
		return _cue_result(false, &"invalid_navigation_feedback")
	var target := cue.target_body_local_m as Vector3
	var distance := float(cue.distance_m)
	var landmark_id := StringName(cue.landmark_id)
	var label := str(cue.label)
	var distance_band := StringName(cue.distance_band)
	_next_landmark_label.position = target + Vector3.UP * 2.4
	_next_landmark_label.text = "NEXT LANDMARK\n%s\n%s // %d m" % [
		label.to_upper(), str(distance_band).to_upper(), roundi(distance),
	]
	_next_landmark_label.visible = true
	_next_landmark_cue = {
		"visible": true,
		"landmark_id": landmark_id,
		"label": label,
		"target_body_local_m": target,
		"distance_m": distance,
		"distance_band": distance_band,
		"reduced_motion": reduced_motion,
		"static": true,
		"controller_only": true,
		"raw_input": false,
		"authority": {
			"navigation": false, "movement": false, "interaction": false,
		},
	}.duplicate(true)
	return _cue_result(true, &"next_landmark_cue_presented")

func get_snapshot() -> Dictionary:
	var visible_count := 0
	if _marker_batch != null and _marker_batch.visible and _marker_multimesh != null:
		visible_count = _marker_multimesh.visible_instance_count
	return {"configured": _configured, "point_count": _points.size(), "points_body_local_m": _points.duplicate(), "visible_marker_count": visible_count, "graphics_profile": _profile, "shared_mesh": _shared_mesh != null, "shared_material": _shared_material != null, "presentation_generation": _presentation_generation, "next_landmark_cue": _next_landmark_cue.duplicate(true), "performance": {"cached_profile_geometry_count": _geometry_buffer_build_count, "geometry_buffer_submissions": _geometry_buffer_submission_count}, "authority": {"navigation": false, "pathfinding": false, "activity": false, "movement": false, "interaction": false}}.duplicate(true)

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


func _valid_cue(cue: Dictionary) -> bool:
	var target: Variant = cue.get("target_body_local_m")
	var distance: Variant = cue.get("distance_m")
	var label := str(cue.get("label", ""))
	var band := StringName(cue.get("distance_band", &""))
	return bool(cue.get("available", false)) \
		and StringName(cue.get("landmark_id", &"")).length() > 0 \
		and label.length() > 0 and label.length() <= 64 \
		and target is Vector3 and (target as Vector3).is_finite() \
		and (distance is float or distance is int) and is_finite(float(distance)) \
		and float(distance) >= 0.0 \
		and band in [&"arriving", &"nearby", &"approaching", &"distant"] \
		and bool(cue.get("controller_only", false)) \
		and not bool(cue.get("raw_input", true)) \
		and not bool((cue.get("authority", {}) as Dictionary).get("navigation", true)) \
		and not bool((cue.get("authority", {}) as Dictionary).get("movement", true)) \
		and not bool((cue.get("authority", {}) as Dictionary).get("interaction", true))


func _clear_next_landmark_cue() -> void:
	if _next_landmark_label != null:
		_next_landmark_label.visible = false
	_next_landmark_cue = {}


func _cue_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"presentation_generation": _presentation_generation,
		"cue": _next_landmark_cue.duplicate(true),
		"authority": {
			"navigation": false, "movement": false, "interaction": false,
		},
	}.duplicate(true)
