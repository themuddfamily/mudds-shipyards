class_name FinalApproachHudComposition
extends RefCounted

## Caller-injected composition of the final-approach binding and HUD adapter.
## Ordinary cruise presentation, engagement, movement, and landing remain
## outside this component.

const BindingType := preload("res://scripts/ui/final_approach_status_binding.gd")
const AdapterType := preload("res://scripts/ui/final_approach_hud_adapter.gd")

var _binding: FinalApproachStatusBinding
var _adapter: FinalApproachHudAdapter
var _source: Object
var _hud: GameHUD
var _toggle_enabled := false
var _engagement_requested := false
var _generation := 0
var _attached := false
var _last_result: Dictionary = {}


func attach(
		source: Object,
		hud: GameHUD,
		toggle_enabled: bool,
		engagement_requested: bool,
		reduced_motion: bool = false
	) -> Dictionary:
	if _attached:
		detach()
	_binding = BindingType.new()
	_adapter = AdapterType.new()
	var adapter_result := _adapter.attach(_binding, hud)
	if not bool(adapter_result.get("accepted", false)):
		_binding = null
		_adapter = null
		return _reject(StringName(adapter_result.get("reason", &"adapter_attach_failed")))
	_binding.presentation_changed.connect(_on_presentation_changed)
	var binding_result := _binding.attach(source, null, reduced_motion)
	if not bool(binding_result.get("accepted", false)):
		_binding.presentation_changed.disconnect(_on_presentation_changed)
		_adapter.detach()
		_binding = null
		_adapter = null
		return _reject(StringName(binding_result.get("reason", &"binding_attach_failed")))
	_source = source
	_hud = hud
	_toggle_enabled = toggle_enabled
	_engagement_requested = engagement_requested
	_generation += 1
	_attached = true
	# Binding emits its initial view during attach, before this composition marks
	# itself attached; apply the detached current view once after the transaction.
	_apply_current_view()
	return {
		"accepted": true,
		"reason": &"bound",
		"generation": _generation,
		"presentation_only": true,
	}


func detach() -> Dictionary:
	if _binding != null and _binding.presentation_changed.is_connected(_on_presentation_changed):
		_binding.presentation_changed.disconnect(_on_presentation_changed)
	if _binding != null:
		_binding.detach()
	if _adapter != null:
		_adapter.detach()
	_binding = null
	_adapter = null
	_source = null
	_hud = null
	_attached = false
	_generation += 1
	_last_result = {}
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func set_cruise_controls(toggle_enabled: bool, engagement_requested: bool) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	_toggle_enabled = toggle_enabled
	_engagement_requested = engagement_requested
	return _apply_current_view()


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached and is_instance_valid(_source) and is_instance_valid(_hud),
		"generation": _generation,
		"toggle_enabled": _toggle_enabled,
		"engagement_requested": _engagement_requested,
		"binding": _binding.get_snapshot() if _binding != null else {},
		"adapter": _adapter.get_snapshot() if _adapter != null else {},
		"last_result": _last_result.duplicate(true),
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
	}.duplicate(true)


func _on_presentation_changed(view: Dictionary) -> void:
	if _attached:
		_last_result = _adapter.apply_view(view, _toggle_enabled, _engagement_requested)


func _apply_current_view() -> Dictionary:
	if not _attached or _binding == null or _adapter == null:
		return _reject(&"detached")
	_last_result = _adapter.apply_view(
		_binding.get_presenter_snapshot(),
		_toggle_enabled,
		_engagement_requested,
	)
	return _last_result.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
