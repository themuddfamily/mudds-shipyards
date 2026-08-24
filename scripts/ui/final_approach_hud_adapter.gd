class_name FinalApproachHudAdapter
extends RefCounted

## Caller-injected bridge from FinalApproachStatusBinding/Presenter output to the
## existing HUD cruise row. It translates presentation vocabulary only; cruise
## engagement, movement, and landing remain caller-owned.

const HudType := preload("res://scripts/ui/hud.gd")
const GUIDANCE_LABEL_NAME := &"FinalApproachGuidance"

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
		_clear_guidance()
		return _reject(&"detached")
	if not is_instance_valid(_binding):
		_clear_guidance()
		return _reject(&"source_lost")
	var binding_snapshot := _binding.call(&"get_snapshot") as Dictionary
	if not bool(binding_snapshot.get("attached", false)):
		_clear_guidance()
		return _reject(&"source_lost")
	if not bool(view.get("accepted", false)) or not bool(view.get("presentation_only", false)):
		return _reject(&"view_not_presentation_only")
	var binding_generation: Variant = view.get("binding_generation", null)
	if not binding_generation is int \
			or int(binding_generation) != int(binding_snapshot.get("generation", -1)):
		return _reject(&"stale_binding_generation")
	var source_generation: Variant = view.get("generation", null)
	if not source_generation is int or int(source_generation) < 0:
		return _reject(&"invalid_generation")
	if _generation < 0 or (_last_view.has("generation") and int(source_generation) < int(_last_view.get("generation", -1))):
		return _reject(&"stale_generation")
	var current_view := _binding.call(&"get_presenter_snapshot") as Dictionary
	if view != current_view:
		return _reject(&"stale_binding_generation")
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
	if not _ensure_guidance_label():
		return _reject(&"hud_guidance_anchor_missing")
	if not _hud.set_planetary_cruise_state(
		mapped.get("status_id", &"unavailable"),
		mapped.get("status_text", "UNAVAILABLE — NAVIGATION OFFLINE"),
		toggle_enabled,
		engagement_requested,
	):
		return _reject(&"hud_rejected_view")
	_guidance_label.text = mapped.get("guidance_text", "") as String
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
		"guidance_text": _guidance_for_state(state),
	}


func _guidance_for_state(state: StringName) -> String:
	match state:
		&"armed":
			return "LAT CENTER  //  VERT HOLD  //  ALIGN ACQUIRE"
		&"approaching":
			return "LAT CENTER  //  VERT DESCEND  //  ALIGN CORRECT"
		&"aligned":
			return "LAT CENTERED  //  VERT DESCEND  //  ALIGN HELD"
		&"handoff":
			return "LAT HOLD  //  VERT SETTLE  //  ALIGN HOLD"
		&"rejected":
			return "RECOVERY  //  LEVEL OUT  //  CLEAR BERTH  //  RE-ARM"
		_:
			return ""


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
	_guidance_label.add_theme_font_size_override("font_size", 10)
	_guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guidance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guidance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guidance_label.focus_mode = Control.FOCUS_NONE
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


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
