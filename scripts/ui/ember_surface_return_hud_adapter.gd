class_name EmberSurfaceReturnHudAdapter
extends RefCounted

## Caller-injected bridge from EmberSurfaceReturnStatusBinding to the existing
## HUD surface-route status row. Ordinary route state remains caller-owned.

var _binding: Object
var _hud: GameHUD
var _attached := false
var _generation := 0
var _last_source_generation := -1
var _last_snapshot: Dictionary = {}


func attach(binding: Object, hud: GameHUD) -> Dictionary:
	if _attached:
		detach()
	if binding == null or not is_instance_valid(binding) \
			or not binding.has_signal(&"presentation_changed") \
			or not binding.has_method(&"get_presenter_snapshot"):
		return _reject(&"binding_contract_missing")
	if hud == null or not is_instance_valid(hud) or not hud.has_method(&"update_surface_route_status"):
		return _reject(&"hud_contract_missing")
	_binding = binding
	_hud = hud
	_attached = true
	_generation += 1
	_binding.connect(&"presentation_changed", _on_presentation_changed)
	_apply(binding.call(&"get_presenter_snapshot") as Dictionary)
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_binding) and _binding.is_connected(&"presentation_changed", _on_presentation_changed):
		_binding.disconnect(&"presentation_changed", _on_presentation_changed)
	_binding = null
	_hud = null
	_attached = false
	_generation += 1
	_last_source_generation = -1
	_last_snapshot = {}
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached and is_instance_valid(_binding) and is_instance_valid(_hud),
		"generation": _generation,
		"source_generation": _last_source_generation,
		"surface_route": _last_snapshot.duplicate(true),
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
		"session_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _on_presentation_changed(view: Dictionary) -> void:
	_apply(view)


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
	_hud.call(&"update_surface_route_status", route)
	_last_source_generation = int(source_generation)
	_last_snapshot = route.duplicate(true)


func _to_surface_route_snapshot(view: Dictionary) -> Dictionary:
	var state := StringName(view.get("state", &"rejected"))
	var blocked := state == &"rejected"
	var distance := float(view.get("distance_m", -1.0))
	if not is_finite(distance) or distance < 0.0:
		distance = 0.0
	return {
		"title": "EMBER RETURN",
		"message": str(view.get("text", "EMBER RETURN STATUS")),
		"waypoints": [{
			"id": state,
			"label": "EMBER RETURN // " + str(state).replace("_", " ").to_upper(),
			"distance_m": distance,
		}],
		"weather": str(view.get("text", "EMBER RETURN STATUS")),
		"hazard": {
			"state": &"blocked" if blocked else &"clear",
			"exposure": 1.0 if blocked else 0.0,
			"recovery_available": false,
		},
		"state": state,
		"presentation_only": true,
	}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
