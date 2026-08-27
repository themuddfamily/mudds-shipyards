class_name EmberSurfaceReturnHudAdapter
extends RefCounted

## Caller-injected bridge from EmberSurfaceReturnStatusBinding to the existing
## HUD surface-route status row. Ordinary route state remains caller-owned.

var _binding: Object
var _hud: GameHUD
var _hazard_source: Object
var _attached := false
var _generation := 0
var _last_source_generation := -1
var _last_snapshot: Dictionary = {}
var _last_minimap_marker: Dictionary = {}
var _last_hazard_snapshot: Dictionary = {}
var _hazard_active := false


func attach(binding: Object, hud: GameHUD, hazard_source: Object = null) -> Dictionary:
	if _attached:
		detach()
	if binding == null or not is_instance_valid(binding) \
			or not binding.has_signal(&"presentation_changed") \
			or not binding.has_method(&"get_presenter_snapshot"):
		return _reject(&"binding_contract_missing")
	if hud == null or not is_instance_valid(hud) \
			or not hud.has_method(&"update_surface_route_status") \
			or not hud.has_method(&"detach_surface_route_status") \
			or not hud.has_method(&"update_offscreen_route_marker") \
			or not hud.has_method(&"clear_offscreen_route_marker") \
			or not hud.has_method(&"get_minimap_report"):
		return _reject(&"hud_contract_missing")
	if hazard_source != null and (
			not is_instance_valid(hazard_source)
			or not hazard_source.has_signal(&"state_changed")
			or not hazard_source.has_method(&"get_authored_hazard_presentation_snapshot")
		):
		return _reject(&"hazard_source_contract_missing")
	_binding = binding
	_hud = hud
	_hazard_source = hazard_source
	_attached = true
	_generation += 1
	_binding.connect(&"presentation_changed", _on_presentation_changed)
	if is_instance_valid(_hazard_source):
		_hazard_source.connect(&"state_changed", _on_hazard_source_changed)
	_apply(binding.call(&"get_presenter_snapshot") as Dictionary)
	_refresh_authored_hazard()
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_binding) and _binding.is_connected(&"presentation_changed", _on_presentation_changed):
		_binding.disconnect(&"presentation_changed", _on_presentation_changed)
	if is_instance_valid(_hazard_source) \
			and _hazard_source.is_connected(&"state_changed", _on_hazard_source_changed):
		_hazard_source.disconnect(&"state_changed", _on_hazard_source_changed)
	if not _last_hazard_snapshot.is_empty() and is_instance_valid(_hud):
		_hud.call(&"detach_surface_route_status")
	_binding = null
	_hazard_source = null
	if is_instance_valid(_hud):
		_hud.call(&"clear_offscreen_route_marker")
	_hud = null
	_attached = false
	_generation += 1
	_last_source_generation = -1
	_last_snapshot = {}
	_last_minimap_marker = {}
	_last_hazard_snapshot = {}
	_hazard_active = false
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached and is_instance_valid(_binding) and is_instance_valid(_hud),
		"generation": _generation,
		"source_generation": _last_source_generation,
		"surface_route": _last_snapshot.duplicate(true),
		"minimap_marker": _last_minimap_marker.duplicate(true),
		"authored_hazard": _last_hazard_snapshot.duplicate(true),
		"hazard_active": _hazard_active,
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
		"session_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _on_presentation_changed(view: Dictionary) -> void:
	_apply(view)
	_refresh_authored_hazard()


func _on_hazard_source_changed(_snapshot: Dictionary) -> void:
	_refresh_authored_hazard()


func _refresh_authored_hazard() -> void:
	if not _attached or not is_instance_valid(_hud) \
			or not is_instance_valid(_hazard_source):
		return
	var snapshot := _hazard_source.call(
		&"get_authored_hazard_presentation_snapshot"
	) as Dictionary
	if snapshot.is_empty():
		return
	var previous_hazard := _last_hazard_snapshot.duplicate(true)
	_last_hazard_snapshot = snapshot.duplicate(true)
	var attached := bool(snapshot.get("attached", false))
	var hazard := snapshot.get("hazard", {}) as Dictionary
	var hazard_visible := bool(hazard.get("visible", false)) \
		and StringName(hazard.get("state", &"clear")) \
			in [&"warning", &"recovery_required"]
	if not attached:
		if _hazard_active or bool(previous_hazard.get("attached", false)):
			_hud.call(&"detach_surface_route_status")
			_hazard_active = false
			if StringName(snapshot.get("reason", &"")) == &"surface_lifecycle_inactive" \
					and not _last_snapshot.is_empty():
				_restore_cached_route()
		return
	if not hazard_visible:
		if _hazard_active:
			# Admit the newer clear revision before restoring the ordinary route;
			# re-entering the same zone in this attachment must remain possible.
			_hud.call(&"update_surface_route_status", snapshot)
			_hazard_active = false
			if not _last_snapshot.is_empty():
				_restore_cached_route()
		return
	_hud.call(&"update_surface_route_status", snapshot)
	_hazard_active = true


func _apply(view: Dictionary) -> void:
	if not _attached or not is_instance_valid(_hud):
		return
	if not bool(view.get("accepted", false)) or not bool(view.get("presentation_only", false)):
		return
	var source_generation: Variant = view.get("generation", null)
	if not source_generation is int or int(source_generation) < 0:
		return
	if _last_source_generation >= 0 and int(source_generation) < _last_source_generation:
		return
	var route := _to_surface_route_snapshot(view)
	if int(source_generation) == _last_source_generation and route == _last_snapshot:
		return
	_last_source_generation = int(source_generation)
	_last_snapshot = route.duplicate(true)
	# An authored warning owns the public row until its cursor advances to a real
	# clear/lifecycle transition. Cache newer route state without letting an
	# unchanged hazard revision be overwritten and then rejected as a duplicate.
	if _hazard_active:
		return
	_restore_cached_route()


func _restore_cached_route() -> void:
	if not is_instance_valid(_hud) or _last_snapshot.is_empty():
		return
	_hud.call(&"update_surface_route_status", _last_snapshot)
	_apply_minimap_guidance(_last_snapshot)


func _to_surface_route_snapshot(view: Dictionary) -> Dictionary:
	var state := StringName(view.get("state", &"rejected"))
	var semantics := view.get("status_semantics", {}) as Dictionary
	var blocked := StringName(semantics.get("kind", &"")) == &"blocked"
	var distance := float(view.get("distance_m", -1.0))
	if not is_finite(distance) or distance < 0.0:
		distance = 0.0
	var guidance := view.get("route_guidance", {}) as Dictionary
	var waypoint_id := state
	var waypoint_label := "EMBER RETURN // " + str(state).replace("_", " ").to_upper()
	if bool(guidance.get("available", false)):
		waypoint_id = guidance.get("target_id", state) as StringName
		waypoint_label = str(guidance.get("target_label", waypoint_label))
		distance = float(guidance.get("distance_m", distance))
	var next_action := view.get("next_action", {}) as Dictionary
	if not next_action.is_empty():
		# SurfaceRouteHazardPresenter renders its first waypoint as the retained
		# controller-readable NEXT row. Keep this cue in that existing focus path
		# rather than creating a second, non-authoritative action control.
		waypoint_label = str(next_action.get("label", "NEXT")) + " // " + waypoint_label
	return {
		"title": str(view.get("visible_title", "EMBER [???] STATUS UNAVAILABLE")),
		"message": str(view.get("text", "EMBER RETURN STATUS")),
		"waypoints": [{
			"id": waypoint_id,
			"label": waypoint_label,
			"distance_m": distance,
		}],
		"weather": str(view.get("text", "EMBER RETURN STATUS")),
		"hazard": {
			"state": &"blocked" if blocked else &"clear",
			"exposure": 1.0 if blocked else 0.0,
			"recovery_available": false,
		},
		"state": state,
		"route_guidance": guidance.duplicate(true),
		"next_action": next_action.duplicate(true),
		"reduced_motion": bool(view.get("reduced_motion", false)),
		"reduced_flash_safe": bool(view.get("reduced_flash_safe", false)),
		"navigation_authority": false,
		"presentation_only": true,
	}


func _apply_minimap_guidance(route: Dictionary) -> void:
	var guidance := route.get("route_guidance", {}) as Dictionary
	if not bool(guidance.get("available", false)):
		_hud.call(&"clear_offscreen_route_marker")
		_last_minimap_marker = {}
		return
	var target: Variant = guidance.get("target_position")
	var direction: Variant = guidance.get("offscreen_direction")
	var distance := float(guidance.get("distance_m", -1.0))
	if target is not Vector3 or direction is not Vector2 \
			or not (target as Vector3).is_finite() \
			or not (direction as Vector2).is_finite() \
			or (direction as Vector2).is_zero_approx() \
			or not is_finite(distance) or distance < 0.0:
		_hud.call(&"clear_offscreen_route_marker")
		_last_minimap_marker = {}
		return
	var report := _hud.call(&"get_minimap_report") as Dictionary
	var has_map := bool(report.get("has_snapshot", false))
	var map_center: Variant = report.get("map_center")
	var map_range := float(report.get("range_meters", 0.0))
	var target_map := Vector2((target as Vector3).x, (target as Vector3).z)
	if has_map and map_center is Vector2 and map_range > 0.0 \
			and target_map.distance_to(map_center as Vector2) <= map_range:
		_hud.call(&"clear_offscreen_route_marker")
		_last_minimap_marker = {
			"accepted": true,
			"reason": &"target_inside_minimap",
			"target_id": guidance.get("target_id", &""),
			"presentation_only": true,
		}.duplicate(true)
		return
	_last_minimap_marker = _hud.call(
		&"update_offscreen_route_marker",
		direction as Vector2,
		distance,
		guidance.get("route_kind", &"surface_route") as StringName,
		bool(route.get("reduced_motion", false)),
	) as Dictionary


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
