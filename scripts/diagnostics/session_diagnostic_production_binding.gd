class_name SessionDiagnosticProductionBinding
extends RefCounted

## Caller-injected production seam for the privacy-safe diagnostic record.
##
## The binding owns no store, lifecycle, clock, or OS authority. It fences the
## record's attach/detach and persistence calls around a caller-supplied store
## generation reader so failed commits remain retryable and re-entry cannot
## replay a different session.

const Record := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const Event := preload("res://scripts/diagnostics/session_diagnostic_event.gd")

var _record: SessionDiagnosticRecord
var _session_id := 0
var _expected_generation := -1
var _generation_reader := Callable()
var _attached := false
var _last_status: Dictionary = {}


func configure(
		record: SessionDiagnosticRecord,
		session_id: int,
		expected_generation: int,
		generation_reader: Callable
		) -> Dictionary:
	if record == null or session_id <= 0 or expected_generation < 0 or not generation_reader.is_valid():
		return _status(false, &"invalid_configuration")
	_record = record
	_session_id = session_id
	_expected_generation = expected_generation
	_generation_reader = generation_reader
	_attached = false
	_last_status = _status(true, &"configured")
	return _last_status.duplicate(true)


func attach() -> Dictionary:
	if _record == null:
		return _status(false, &"binding_unavailable")
	if not _generation_matches():
		return _status(false, &"stale_store_generation")
	_last_status = _record.attach_session(_session_id).duplicate(true)
	_attached = bool(_last_status.get("accepted", false))
	return _last_status.duplicate(true)


func detach() -> Dictionary:
	if _record == null or not _attached:
		return _status(false, &"not_attached")
	_last_status = _record.detach_session(_session_id).duplicate(true)
	if bool(_last_status.get("accepted", false)):
		_attached = false
	return _last_status.duplicate(true)


func record_event(event: SessionDiagnosticEvent) -> Dictionary:
	if not _attached or event == null:
		return _status(false, &"not_attached")
	if event.session_id != _session_id:
		return _status(false, &"wrong_session")
	_last_status = _record.record(event).duplicate(true)
	return _last_status.duplicate(true)


func persist(commit_id: String) -> Dictionary:
	if not _attached:
		return _status(false, &"not_attached")
	if not _generation_matches():
		_last_status = _status(false, &"stale_store_generation")
		return _last_status.duplicate(true)
	_last_status = _record.persist(commit_id).duplicate(true)
	if bool(_last_status.get("accepted", false)):
		_expected_generation = int(_last_status.get("generation", _expected_generation))
	return _last_status.duplicate(true)


func get_snapshot() -> Dictionary:
	return _record.get_snapshot().duplicate(true) if _record != null else {}


func get_report() -> Dictionary:
	return {
		"schema_version": 1,
		"configured": _record != null,
		"attached": _attached,
		"session_id": _session_id,
		"expected_generation": _expected_generation,
		"last_status": _last_status.duplicate(true),
		"record_snapshot": get_snapshot(),
	}.duplicate(true)


func _generation_matches() -> bool:
	var observed: Variant = _generation_reader.call()
	return observed is int and int(observed) == _expected_generation


func _status(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}
