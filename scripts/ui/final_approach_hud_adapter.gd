class_name FinalApproachHudAdapter
extends RefCounted

## Caller-injected bridge from FinalApproachStatusBinding/Presenter output to the
## existing HUD cruise row. It translates presentation vocabulary only; cruise
## engagement, movement, and landing remain caller-owned.

const HudType := preload("res://scripts/ui/hud.gd")
const GUIDANCE_LABEL_NAME := &"FinalApproachGuidance"
const AXIS_DEADBAND_FRACTION := 0.10
const LONGITUDINAL_DEADBAND_FRACTION := 0.05
const ATTITUDE_DEADBAND_FRACTION := 0.25
const MIN_AXIS_DEADBAND_M := 0.5
const MIN_LONGITUDINAL_DEADBAND_M := 1.0
const MIN_ATTITUDE_DEADBAND_DEGREES := 1.0
const GUIDANCE_FONT_SIZE := 14

var _binding: Object
var _hud: GameHUD
var _guidance_label: Label
var _attached := false
var _generation := -1
var _last_view: Dictionary = {}
var _last_report: Dictionary = {}


func attach(binding: Object, hud: GameHUD) -> Dictionary:
	if _attached:
		detach()
	if binding == null or not is_instance_valid(binding) \
			or not binding.has_method(&"get_snapshot") \
			or not binding.has_method(&"get_presenter_snapshot"):
		return _reject(&"binding_contract_missing")
	if hud == null or not is_instance_valid(hud) or not hud.has_method(&"set_planetary_cruise_state"):
		return _reject(&"hud_contract_missing")
	_binding = binding
	_hud = hud
	_remove_guidance_from(hud)
	_attached = true
	_generation += 1
	_last_view = {}
	_last_report = {}
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	_clear_guidance()
	_binding = null
	_hud = null
	_attached = false
	_generation += 1
	_last_view = {}
	_last_report = {}
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func apply_view(view: Dictionary, toggle_enabled: bool, engagement_requested: bool) -> Dictionary:
	if not _attached or not is_instance_valid(_hud):
		return _reject_and_clear(&"detached")
	if not is_instance_valid(_binding):
		return _reject_and_clear(&"source_lost")
	var binding_snapshot := _binding.call(&"get_snapshot") as Dictionary
	if not bool(binding_snapshot.get("attached", false)):
		return _reject_and_clear(&"source_lost")
	if not bool(view.get("accepted", false)) or not bool(view.get("presentation_only", false)):
		return _reject_and_clear(&"view_not_presentation_only")
	var binding_generation: Variant = view.get("binding_generation", null)
	if not binding_generation is int \
			or int(binding_generation) != int(binding_snapshot.get("generation", -1)):
		return _reject_and_clear(&"stale_binding_generation")
	var source_generation: Variant = view.get("generation", null)
	if not source_generation is int or int(source_generation) < 0:
		return _reject_and_clear(&"invalid_generation")
	if _generation < 0 or (_last_view.has("generation") and int(source_generation) < int(_last_view.get("generation", -1))):
		return _reject_and_clear(&"stale_generation")
	var current_view := _binding.call(&"get_presenter_snapshot") as Dictionary
	if view != current_view:
		return _reject_and_clear(&"stale_binding_generation")
	var state := StringName(view.get("state", &"unavailable"))
	var mapped := _map_state(state, toggle_enabled, engagement_requested)
	if not bool(mapped.get("accepted", false)):
		_clear_guidance()
		return mapped
	mapped["guidance_text"] = _guidance_for_view(view, state)
	if (
		_last_view.has("generation")
		and int(source_generation) == int(_last_view.get("generation", -1))
		and _last_report == mapped
		and (
			str(mapped.get("guidance_text", "")).is_empty()
			or is_instance_valid(_guidance_label)
		)
	):
		return {"accepted": true, "reason": &"duplicate", "generation": _generation, "source_generation": int(source_generation), "presentation_only": true}
	var guidance_text := mapped.get("guidance_text", "") as String
	if not guidance_text.is_empty() and not _ensure_guidance_label():
		return _reject_and_clear(&"hud_guidance_anchor_missing")
	if not _hud.set_planetary_cruise_state(
		mapped.get("status_id", &"unavailable"),
		mapped.get("status_text", "UNAVAILABLE — NAVIGATION OFFLINE"),
		toggle_enabled,
		engagement_requested,
	):
		return _reject_and_clear(&"hud_rejected_view")
	if guidance_text.is_empty():
		_clear_guidance()
	else:
		_guidance_label.text = guidance_text
		_guidance_label.visible = true
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
		"guidance_text": mapped.get("guidance_text"),
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
	return {
		"accepted": true,
		"status_id": status_id,
		"status_text": status_text,
	}


func _guidance_for_view(view: Dictionary, state: StringName) -> String:
	if state not in [&"approaching", &"aligned"] \
			or not bool(view.get("approach_measurement_valid", false)):
		return ""
	var offset_variant: Variant = view.get("position_offset_entry_local_m", null)
	var extents_variant: Variant = view.get("entry_position_half_extents_m", null)
	var attitude_variant: Variant = view.get("attitude_degrees", null)
	var maximum_attitude_variant: Variant = view.get(
		"maximum_attitude_degrees", null
	)
	if not offset_variant is Vector3 or not extents_variant is Vector3 \
			or not (attitude_variant is int or attitude_variant is float) \
			or not (maximum_attitude_variant is int or maximum_attitude_variant is float):
		return ""
	var offset := offset_variant as Vector3
	var extents := extents_variant as Vector3
	var attitude := float(attitude_variant)
	var maximum_attitude := float(maximum_attitude_variant)
	if not offset.is_finite() or not extents.is_finite() \
			or extents.x <= 0.0 or extents.y <= 0.0 or extents.z <= 0.0 \
			or not is_finite(attitude) or attitude < 0.0 \
			or not is_finite(maximum_attitude) or maximum_attitude <= 0.0:
		return ""
	var lateral_deadband := maxf(
		MIN_AXIS_DEADBAND_M, extents.x * AXIS_DEADBAND_FRACTION
	)
	var vertical_deadband := maxf(
		MIN_AXIS_DEADBAND_M, extents.y * AXIS_DEADBAND_FRACTION
	)
	var longitudinal_deadband := maxf(
		MIN_LONGITUDINAL_DEADBAND_M,
		extents.z * LONGITUDINAL_DEADBAND_FRACTION,
	)
	var attitude_deadband := maxf(
		MIN_ATTITUDE_DEADBAND_DEGREES,
		maximum_attitude * ATTITUDE_DEADBAND_FRACTION,
	)
	# Offsets describe the actor in the target's entry-local frame, so each
	# instruction names the correction back toward the zero-centred envelope.
	return "LAT %s / VERT %s / RANGE %s / ALIGN %s" % [
		_axis_correction(offset.x, lateral_deadband, "LEFT", "RIGHT", "CENTER"),
		_axis_correction(offset.y, vertical_deadband, "DOWN", "UP", "LEVEL"),
		_axis_correction(offset.z, longitudinal_deadband, "FWD", "BACK", "HOLD"),
		"HELD" if attitude <= attitude_deadband else "CORRECT",
	]


func _axis_correction(
		value: float,
		deadband: float,
		positive_correction: String,
		negative_correction: String,
		centered: String,
	) -> String:
	if value > deadband:
		return positive_correction
	if value < -deadband:
		return negative_correction
	return centered


func _ensure_guidance_label() -> bool:
	if is_instance_valid(_guidance_label):
		return true
	var row := _hud.find_child("PlanetaryCruiseRow", true, false) as VBoxContainer
	if row == null:
		return false
	var existing := row.find_child(str(GUIDANCE_LABEL_NAME), false, false) as Label
	if existing != null:
		_guidance_label = existing
	else:
		_guidance_label = Label.new()
		_guidance_label.name = GUIDANCE_LABEL_NAME
		row.add_child(_guidance_label)
	_guidance_label.add_theme_font_size_override("font_size", GUIDANCE_FONT_SIZE)
	_guidance_label.custom_minimum_size = Vector2(0.0, 18.0)
	_guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guidance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guidance_label.focus_mode = Control.FOCUS_NONE
	_guidance_label.tooltip_text = (
		"Entry-local lateral / vertical / range / attitude correction"
	)
	_guidance_label.visible = false
	return true


func _clear_guidance() -> void:
	if not is_instance_valid(_guidance_label):
		_guidance_label = null
		return
	_guidance_label.visible = false
	_guidance_label.text = ""
	var parent := _guidance_label.get_parent()
	if parent != null:
		parent.remove_child(_guidance_label)
	_guidance_label.queue_free()
	_guidance_label = null


func _remove_guidance_from(hud: GameHUD) -> void:
	var stale := hud.find_child(str(GUIDANCE_LABEL_NAME), true, false) as Label
	if stale == null:
		return
	stale.visible = false
	stale.text = ""
	var parent := stale.get_parent()
	if parent != null:
		parent.remove_child(stale)
	stale.queue_free()


func _reject_and_clear(reason: StringName) -> Dictionary:
	_clear_guidance()
	return _reject(reason)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
