class_name PlanetarySurfaceRouteTrailPresentation
extends Node3D

## Presentation-only authored route trail. It renders caller-provided points
## and owns no navigation, pathfinding, activity, movement, or route state.

var _configured := false
var _points: Array[Vector3] = []
var _markers: Array[MeshInstance3D] = []
var _profile: StringName = &"high"
var _solar: Dictionary = {}
var _weather: Dictionary = {}

func configure(points: Array) -> Dictionary:
	if _configured or points.is_empty():
		return {"accepted": false, "reason": &"invalid_route_trail_configuration"}
	for point in points:
		if not point is Vector3 or not (point as Vector3).is_finite():
			return {"accepted": false, "reason": &"invalid_route_trail_configuration"}
		_points.append(point)
		var marker := MeshInstance3D.new()
		marker.name = "RouteTrailMarker_%d" % (_points.size() - 1)
		var mesh := SphereMesh.new()
		mesh.radius = 0.45
		mesh.height = 0.9
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(0.2, 0.7, 1.0, 1.0)
		marker.material_override = material
		marker.position = point
		marker.visible = false
		add_child(marker)
		_markers.append(marker)
	_configured = true
	return {"accepted": true, "reason": &"configured"}

func apply_presentation_recipe(solar: Variant, weather: Variant) -> Dictionary:
	if not _configured or not solar is Dictionary or not weather is Dictionary:
		return {"accepted": false, "reason": &"invalid_route_trail_recipe"}
	_solar = (solar as Dictionary).duplicate(true)
	_weather = (weather as Dictionary).duplicate(true)
	var elevation := float(_solar.get("sun_elevation_sine", 0.0))
	var intensity := clampf(0.25 + clampf(-elevation, 0.0, 1.0) * 0.75, 0.15, 1.0)
	var stride := 1 if _profile == &"high" else (2 if _profile == &"medium" else 3)
	for index in _markers.size():
		var visible := index % stride == 0
		_markers[index].visible = visible
		var material := _markers[index].material_override as StandardMaterial3D
		material.emission_energy_multiplier = intensity
	return {"accepted": true, "reason": &"route_trail_recipe_applied", "marker_count": _markers.size()}

func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"medium", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_profile = profile
	if not _solar.is_empty():
		apply_presentation_recipe(_solar, _weather)
	return {"accepted": true, "reason": &"graphics_profile_applied"}

func detach() -> Dictionary:
	for marker in _markers: marker.visible = false
	return {"accepted": true, "reason": &"route_trail_detached"}

func reenter() -> Dictionary:
	if _solar.is_empty(): return {"accepted": false, "reason": &"route_trail_reentry_unavailable"}
	return apply_presentation_recipe(_solar, _weather)

func get_snapshot() -> Dictionary:
	var visible_count := 0
	for marker in _markers: visible_count += 1 if marker.visible else 0
	return {"configured": _configured, "point_count": _points.size(), "points_body_local_m": _points.duplicate(), "visible_marker_count": visible_count, "graphics_profile": _profile, "authority": {"navigation": false, "pathfinding": false, "activity": false, "movement": false}}.duplicate(true)
