class_name RuntimeInputRemappingPresenter
extends RefCounted

## Player-facing state adapter for RuntimeInputRemappingController.
##
## The presenter owns no InputMap or persistence state. A submitted binding is
## committed immediately when conflict-free; conflicting captures remain in a
## detached pending record until the player explicitly replaces or cancels.

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Controller := preload("res://scripts/settings/runtime_input_remapping_controller.gd")

signal state_changed(snapshot: Dictionary)

var _controller: RuntimeInputRemappingController
var _status: StringName = &"idle"
var _pending_conflict: Dictionary = {}
var _last_result: Dictionary = {}


func _init(controller: RuntimeInputRemappingController) -> void:
	_controller = controller
	if _controller != null:
		_controller.profile_changed.connect(_on_controller_profile_changed)


func is_valid() -> bool:
	return _controller != null and _controller.is_valid()


func get_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	if is_valid():
		var profile := _controller.get_profile()
		var actions: Array[StringName] = []
		for action: StringName in profile.bindings:
			actions.append(action)
		actions.sort()
		for action: StringName in actions:
			rows.append({
				"action": action,
				"bindings": profile.get_bindings(action),
				"options": profile.get_action_options(action),
			})
	return {
		"valid": is_valid(),
		"status": _status,
		"controller_family": _controller.get_controller_family() if is_valid() else &"unknown",
		"revision": _controller.get_revision() if is_valid() else 0,
		"rows": rows,
		"pending_conflict": _pending_conflict.duplicate(true),
		"last_result": _last_result.duplicate(true),
	}


func submit_binding(action: StringName, candidate: Variant) -> Dictionary:
	if not is_valid():
		return _record({"accepted": false, "reason": &"invalid_contract"}, &"error")
	var preview := _controller.preview_binding(action, candidate)
	if preview.reason == &"conflict":
		_pending_conflict = {
			"action": action,
			"candidate": Profile.normalize_binding(candidate),
			"conflicts": preview.get("conflicts", []).duplicate(true),
			"revision": int(preview.revision),
		}
		return _record(preview, &"conflict")
	if not bool(preview.get("accepted", false)):
		return _record(preview, &"error")
	return _record(
		_controller.commit_binding(action, candidate, int(preview.revision)),
		&"committed"
	)


func replace_pending_conflict() -> Dictionary:
	if _pending_conflict.is_empty() or not is_valid():
		return _record({"accepted": false, "reason": &"no_pending_conflict"}, &"error")
	var pending := _pending_conflict.duplicate(true)
	var result := _controller.commit_binding(
		StringName(pending.action),
		pending.candidate,
		int(pending.revision),
		Controller.CONFLICT_REPLACE
	)
	if bool(result.get("accepted", false)):
		_pending_conflict.clear()
	return _record(result, &"committed" if bool(result.get("accepted", false)) else &"error")


func cancel_pending_conflict() -> Dictionary:
	_pending_conflict.clear()
	return _record({"accepted": true, "reason": &"cancelled", "revision": _controller.get_revision() if is_valid() else 0}, &"idle")


func commit_options(action: StringName, deadzone: Variant, curve: StringName, hold_mode: StringName) -> Dictionary:
	if not is_valid():
		return _record({"accepted": false, "reason": &"invalid_contract"}, &"error")
	var result := _controller.commit_options(action, deadzone, curve, hold_mode, _controller.get_revision())
	return _record(result, &"committed" if bool(result.get("accepted", false)) else &"error")


func reset() -> Dictionary:
	if not is_valid():
		return _record({"accepted": false, "reason": &"invalid_contract"}, &"error")
	_pending_conflict.clear()
	var result := _controller.reset(_controller.get_revision())
	return _record(result, &"committed" if bool(result.get("accepted", false)) else &"error")


func _record(result: Dictionary, status: StringName) -> Dictionary:
	_status = status
	_last_result = result.duplicate(true)
	var snapshot := get_snapshot()
	state_changed.emit(snapshot)
	return snapshot


func _on_controller_profile_changed(_result: Dictionary) -> void:
	if _status == &"idle":
		state_changed.emit(get_snapshot())
