class_name FinalApproachHudAdapter
extends RefCounted

## Caller-injected bridge from FinalApproachStatusBinding/Presenter output to the
## existing HUD cruise row. It translates presentation vocabulary only; cruise
## engagement, movement, and landing remain caller-owned.

const HudType := preload("res://scripts/ui/hud.gd")

var _binding: Object
var _hud: GameHUD
var _attached := false
var _generation := -1
var _last_view: Dictionary = {}
var _last_report: Dictionary = {}


func attach(binding: Object, hud: GameHUD) -> Dictionary:
	if _attached:
		detach()
	if binding == null or not is_instance_valid(binding) or not binding.has_method(&"get_snapshot"):
		return _reject(&"binding_contract_missing")
	if hud == null or not is_instance_valid(hud) or not hud.has_method(&"set_planetary_cruise_state"):
		return _reject(&"hud_contract_missing")
	_binding = binding
	_hud = hud
	_attached = true
	_generation += 1
	_last_view = {}
	_last_report = {}
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	_binding = null
	_hud = null
	_attached = false
	_generation += 1
	_last_view = {}
	_last_report = {}
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func apply_view(view: Dictionary, toggle_enabled: bool, engagement_requested: bool) -> Dictionary:
	if not _attached or not is_instance_valid(_hud):
		return _reject(&"detached")
	if not bool(view.get("accepted", false)) or not bool(view.get("presentation_only", false)):
		return _reject(&"view_not_presentation_only")
	var source_generation: Variant = view.get("generation", null)
	if not source_generation is int or int(source_generation) < 0:
		return _reject(&"invalid_generation")
	if _generation < 0 or (_last_view.has("generation") and int(source_generation) < int(_last_view.get("generation", -1))):
		return _reject(&"stale_generation")
	var state := StringName(view.get("state", &"unavailable"))
	var mapped := _map_state(state, toggle_enabled, engagement_requested)
	if not bool(mapped.get("accepted", false)):
		return mapped
	if (
		_last_view.has("generation")
		and int(source_generation) == int(_last_view.get("generation", -1))
		and _last_report == mapped
	):
		return {"accepted": true, "reason": &"duplicate", "generation": _generation, "source_generation": int(source_generation), "presentation_only": true}
	if not _hud.set_planetary_cruise_state(
		mapped.get("status_id", &"unavailable"),
		mapped.get("status_text", "UNAVAILABLE — NAVIGATION OFFLINE"),
		toggle_enabled,
		engagement_requested,
	):
		return _reject(&"hud_rejected_view")
	_last_view = view.duplicate(true)
	_last_report = mapped.duplicate(true)
	return {
		"accepted": true,
		"reason": &"applied",
		"generation": _generation,
		"source_generation": int(source_generation),
		"source_state": state,
		"status_id": mapped.get("status_id"),
		"status_text": mapped.get("status_text"),
		"presentation_only": true,
	}


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached and is_instance_valid(_binding) and is_instance_valid(_hud),
		"generation": _generation,
		"source_view": _last_view.duplicate(true),
		"mapped": _last_report.duplicate(true),
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
	}.duplicate(true)


func _map_state(state: StringName, toggle_enabled: bool, engagement_requested: bool) -> Dictionary:
	var status_id: StringName
	var status_text: String
	match state:
		&"armed":
			status_id = &"ready"
			status_text = "READY — EMBER MOON"
		&"approaching":
			status_id = &"accelerating"
			status_text = "ACCELERATING"
		&"aligned":
			status_id = &"cruising"
			status_text = "CRUISING"
		&"handoff":
			status_id = &"braking_to_speed" if engagement_requested else &"braking"
			status_text = "BRAKING TO SPEED" if engagement_requested else "BRAKING"
		&"rejected":
			status_id = &"unavailable"
			status_text = "UNAVAILABLE — NAVIGATION OFFLINE"
		_:
			return _reject(&"unknown_state")
	var exact_semantics := (
		(status_id == &"ready" and toggle_enabled and not engagement_requested)
		or (status_id == &"accelerating" and toggle_enabled == engagement_requested)
		or (status_id == &"cruising" and toggle_enabled == engagement_requested)
		or (status_id == &"braking_to_speed" and toggle_enabled == engagement_requested)
		or (status_id == &"braking" and not toggle_enabled and not engagement_requested)
		or (status_id == &"unavailable" and not toggle_enabled and not engagement_requested)
	)
	if not exact_semantics:
		return _reject(&"caller_toggle_state_incompatible")
	return {"accepted": true, "status_id": status_id, "status_text": status_text}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
