class_name EmberSurfaceReturnStatusBinding
extends RefCounted

## Caller-injected bridge from Ember Host/ProductionBinding snapshots to the
## detached return presenter. It owns no travel, landing, or return authority.

const PresenterType := preload("res://scripts/ui/ember_surface_return_status_presenter.gd")

signal presentation_changed(view: Dictionary)

var _production: Object
var _host: Object
var _presenter: Object
var _attached := false
var _generation := 0
var _last_result: Dictionary = {}
var _view: Dictionary = {}
var _reduced_motion := false


func attach(production: Object, host: Object, presenter: Object = null, reduced_motion: bool = false) -> Dictionary:
	if _attached:
		detach()
	if production == null or not is_instance_valid(production) \
			or not production.has_signal(&"state_changed") \
			or not production.has_signal(&"completion_handback_ready") \
			or not production.has_method(&"get_snapshot") \
			or not production.has_method(&"get_planetary_relay_survey_return_manifest_snapshot"):
		return _reject(&"production_contract_missing")
	if host == null or not is_instance_valid(host) or not host.has_method(&"get_snapshot"):
		return _reject(&"host_contract_missing")
	_production = production
	_host = host
	_presenter = presenter if presenter != null else PresenterType.new()
	_attached = true
	_generation += 1
	_reduced_motion = reduced_motion
	_production.connect(&"state_changed", _on_state_changed)
	_production.connect(&"completion_handback_ready", _on_completion)
	_publish(reduced_motion)
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_production):
		if _production.is_connected(&"state_changed", _on_state_changed):
			_production.disconnect(&"state_changed", _on_state_changed)
		if _production.is_connected(&"completion_handback_ready", _on_completion):
			_production.disconnect(&"completion_handback_ready", _on_completion)
	if _presenter != null:
		_presenter.call(&"detach")
	_production = null
	_host = null
	_attached = false
	_generation += 1
	_last_result = {}
	_view = {}
	_reduced_motion = false
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func apply_return_manifest_receipt(receipt: Dictionary, reduced_motion: bool = false) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	_last_result = receipt.duplicate(true)
	return _publish(reduced_motion)


func get_snapshot() -> Dictionary:
	return {"attached": _attached, "generation": _generation, "view": _view.duplicate(true), "last_result": _last_result.duplicate(true), "presentation_only": true, "movement_authority": false, "landing_authority": false, "reward_authority": false}.duplicate(true)


func get_presenter_snapshot() -> Dictionary:
	return _view.duplicate(true)


func _on_state_changed(_snapshot: Dictionary) -> void:
	_publish(_reduced_motion)


func _on_completion(receipt: Dictionary) -> void:
	_last_result = receipt.duplicate(true)
	_publish(_reduced_motion)


func _publish(reduced_motion: bool) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	var production_snapshot := _production.call(&"get_snapshot") as Dictionary
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	var source_generation := maxi(_generation, int(production_snapshot.get("generation", 0)))
	source_generation = maxi(source_generation, int(host_snapshot.get("generation", 0)))
	source_generation = maxi(source_generation, int(host_snapshot.get("attachment_generation", 0)))
	var aggregate := {
		"generation": source_generation,
		"binding": production_snapshot,
		"host": host_snapshot,
		"return_manifest": _production.call(&"get_planetary_relay_survey_return_manifest_snapshot") as Dictionary,
		"last_result": _last_result.duplicate(true),
	}
	var next: Dictionary = _presenter.call(&"present", aggregate, reduced_motion)
	if bool(next.get("accepted", false)):
		if next == _view:
			return {"accepted": true, "reason": &"duplicate", "generation": _generation, "presentation_only": true}
		_view = next.duplicate(true)
		presentation_changed.emit(_view.duplicate(true))
	return next


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
