class_name FinalApproachStatusBinding
extends RefCounted

## Caller-injected bridge from PlanetaryCruiseProductionBinding receipts to the
## detached final-approach presenter. It owns no cruise, movement, or landing.

const PresenterType := preload("res://scripts/ui/final_approach_status_presenter.gd")

var _source: Object
var _presenter: FinalApproachStatusPresenter
var _reduced_motion := false
var _generation := 0
var _attached := false
var _snapshot: Dictionary = {}


func attach(source: Object, presenter: FinalApproachStatusPresenter = null, reduced_motion: bool = false) -> Dictionary:
	if _attached:
		detach()
	if source == null or not is_instance_valid(source) or not source.has_signal(&"engagement_changed") \
			or not source.has_signal(&"tick_committed") or not source.has_signal(&"final_approach_completed") \
			or not source.has_method(&"get_snapshot"):
		return _reject(&"source_contract_missing")
	_source = source
	_presenter = presenter if presenter != null else PresenterType.new()
	_reduced_motion = reduced_motion
	_generation += 1
	_attached = true
	_source.connect(&"engagement_changed", _on_engagement_changed)
	_source.connect(&"tick_committed", _on_tick_committed)
	_source.connect(&"final_approach_completed", _on_completed)
	_apply_snapshot(_source.call(&"get_snapshot") as Dictionary)
	return {"accepted": true, "reason": &"bound", "generation": _generation, "presentation_only": true}


func detach() -> Dictionary:
	if is_instance_valid(_source):
		if _source.is_connected(&"engagement_changed", _on_engagement_changed):
			_source.disconnect(&"engagement_changed", _on_engagement_changed)
		if _source.is_connected(&"tick_committed", _on_tick_committed):
			_source.disconnect(&"tick_committed", _on_tick_committed)
		if _source.is_connected(&"final_approach_completed", _on_completed):
			_source.disconnect(&"final_approach_completed", _on_completed)
	if _presenter != null:
		_presenter.detach()
	_source = null
	_attached = false
	_generation += 1
	_snapshot = {}
	return {"accepted": true, "reason": &"detached", "generation": _generation, "presentation_only": true}


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached and is_instance_valid(_source),
		"generation": _generation,
		"source": _snapshot.duplicate(true),
		"presentation_only": true,
		"movement_authority": false,
		"landing_authority": false,
	}.duplicate(true)


func _on_engagement_changed(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _on_tick_committed(receipt: Dictionary) -> void:
	if not _attached:
		return
	var combined := _snapshot.duplicate(true)
	_set_receipt_generation(combined, receipt)
	combined["last_result"] = receipt.duplicate(true)
	combined["last_reason"] = receipt.get("reason", &"")
	_apply_snapshot(combined)


func _on_completed(receipt: Dictionary) -> void:
	if not _attached:
		return
	var combined := _snapshot.duplicate(true)
	_set_receipt_generation(combined, receipt)
	combined["last_result"] = receipt.duplicate(true)
	combined["last_reason"] = receipt.get("reason", &"final_approach_handoff_ready")
	_apply_snapshot(combined)


func _apply_snapshot(snapshot: Dictionary) -> void:
	if not _attached:
		return
	var view := _presenter.present(snapshot, _reduced_motion)
	if bool(view.get("accepted", false)):
		_snapshot = snapshot.duplicate(true)
		view["binding_generation"] = _generation


func _set_receipt_generation(snapshot: Dictionary, receipt: Dictionary) -> void:
	var receipt_generation: Variant = receipt.get("generation", receipt.get("controller_generation", null))
	if receipt_generation is int and int(receipt_generation) >= 0:
		snapshot["generation"] = int(receipt_generation)


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation, "presentation_only": true}
