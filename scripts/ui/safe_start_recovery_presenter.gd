class_name SafeStartRecoveryPresenter
extends RefCounted

## Presentation-only consumer for caller-owned recovery receipts and detached
## diagnostic snapshots. It does not inspect settings, perform restoration, or
## own crash diagnostics.

const COMPONENT_ID: StringName = &"safe-start-recovery-presenter"
const SessionDiagnosticRecordType := preload(
	"res://scripts/diagnostics/session_diagnostic_record.gd"
)
const RUNTIME_MODE_LABELS := {
	SessionDiagnosticRecordType.RuntimeMode.STATION: &"STATION",
	SessionDiagnosticRecordType.RuntimeMode.FLIGHT: &"FLIGHT",
	SessionDiagnosticRecordType.RuntimeMode.SURFACE: &"SURFACE",
}
const DIAGNOSTIC_SNAPSHOT_KEYS := [
	"schema_version",
	"capacity",
	"next_sequence",
	"dropped_event_count",
	"events",
]

var _snapshot: Dictionary = {}


func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _valid_receipt(receipt):
		_snapshot = {
			"component_id": COMPONENT_ID,
			"status": &"invalid",
			"title": "Recovery information unavailable",
			"message": "Keep Safe Settings is the only available option.",
			"actions": [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}],
			"presentation_only": true,
		}
		return _snapshot.duplicate(true)
	var graphics := receipt.get("graphics_recovery_receipt", {}) as Dictionary
	var audio := receipt.get("audio_recovery_receipt", {}) as Dictionary
	var restore_available := not graphics.is_empty() or not audio.is_empty()
	var actions: Array = [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}]
	if restore_available:
		actions.push_front({"id": &"restore", "label": "Restore Previous Settings", "focusable": true})
	_snapshot = {
		"component_id": COMPONENT_ID,
		"status": &"safe_mode_active" if restore_available else &"safe_mode_confirmed",
		"title": "Safe Settings Active",
		"message": "The previous session did not start cleanly. Safe display/audio settings are active.",
		"details": {
			"graphics_restore_available": not graphics.is_empty(),
			"audio_restore_available": not audio.is_empty(),
			"stability_confirmed": bool(receipt.get("stability_confirmed", false)),
		},
		"actions": actions,
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func present_recovery_choice(recommendation: Dictionary) -> Dictionary:
	if not bool(recommendation.get("available", false)) or not bool(recommendation.get("requires_caller_choice", false)):
		_snapshot = {"component_id": COMPONENT_ID, "status": &"hidden", "actions": [], "presentation_only": true}
		return _snapshot.duplicate(true)
	var severity := StringName(str(recommendation.get("severity", &"review_prior_session")))
	_snapshot = {
		"component_id": COMPONENT_ID,
		"status": &"choice_required",
		"title": "Previous session recovery",
		"message": "The last session did not close cleanly. Choose how to start this session.",
		"summary": "Recovery record available  //  %s" % str(severity).replace("_", " ").to_upper(),
		"actions": [
			{"id": &"normal_start", "label": "Normal Start", "focusable": true},
			{"id": &"safe_graphics_windowed", "label": "Safe Graphics (Session Only)", "focusable": true},
			{"id": &"discard", "label": "Discard Recovery Record", "focusable": true},
		],
		"presentation_only": true,
	}.duplicate(true)
	return _snapshot.duplicate(true)


## Reduces the existing diagnostic ring to fixed labels and bounded primitives
## for an interrupted-session card. No event text, fields, paths, or sink data
## are copied into the presentation result.
func present_diagnostic_support_summary(
		diagnostic_snapshot: Dictionary,
		interrupted_session_id: int
		) -> Dictionary:
	var hidden := {
		"available": false,
		"session_id": 0,
		"retained_event_count": 0,
		"last_runtime_mode": &"NOT_RETAINED",
		"presentation_only": true,
	}
	if not _valid_diagnostic_snapshot(diagnostic_snapshot) \
			or interrupted_session_id <= 0 \
			or interrupted_session_id > SessionDiagnosticRecordType.MAX_SESSION_ID:
		return hidden.duplicate(true)
	var retained_event_count := 0
	var last_runtime_mode: StringName = &"NOT_RETAINED"
	for event_variant: Variant in diagnostic_snapshot.get("events", []) as Array:
		if event_variant is not Dictionary:
			return hidden.duplicate(true)
		var event := event_variant as Dictionary
		var session_value: Variant = event.get("session_id")
		if session_value is not int:
			return hidden.duplicate(true)
		if session_value as int != interrupted_session_id:
			continue
		retained_event_count += 1
		if event.get("event_code") != "control_source_changed":
			continue
		var fields_value: Variant = event.get("fields")
		if fields_value is not Dictionary:
			continue
		var fields := fields_value as Dictionary
		# Production runtime-mode observations contain exactly this one fixed
		# primitive. Other CONTROL_SOURCE_CHANGED uses cannot impersonate it.
		if fields.size() != 1 or not fields.has("input_device_code"):
			continue
		var mode_value: Variant = fields.get("input_device_code")
		if mode_value is int and RUNTIME_MODE_LABELS.has(mode_value):
			last_runtime_mode = RUNTIME_MODE_LABELS[mode_value]
	if retained_event_count == 0:
		return hidden.duplicate(true)
	return {
		"available": true,
		"session_id": interrupted_session_id,
		"retained_event_count": retained_event_count,
		"last_runtime_mode": last_runtime_mode,
		"presentation_only": true,
	}.duplicate(true)


func request_choice(choice: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == choice:
			return {"accepted": true, "reason": &"recovery_choice_requested", "choice": choice, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "choice": choice, "presentation_only": true}


func request_restore() -> Dictionary:
	return _intent(&"restore", &"restore_requested")


func request_keep_safe() -> Dictionary:
	return _intent(&"keep_safe", &"keep_safe_requested")


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {"accepted": true, "reason": reason, "action": action, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "action": action, "presentation_only": true}


func _valid_receipt(receipt: Dictionary) -> bool:
	return receipt.has("graphics_recovery_receipt") and receipt.has("audio_recovery_receipt")


func _valid_diagnostic_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.size() != DIAGNOSTIC_SNAPSHOT_KEYS.size():
		return false
	for key: Variant in snapshot.keys():
		if key is not String or key not in DIAGNOSTIC_SNAPSHOT_KEYS:
			return false
	var schema_value: Variant = snapshot.get("schema_version")
	var capacity_value: Variant = snapshot.get("capacity")
	var next_sequence_value: Variant = snapshot.get("next_sequence")
	var dropped_value: Variant = snapshot.get("dropped_event_count")
	var events_value: Variant = snapshot.get("events")
	if (
		schema_value is not int
		or capacity_value is not int
		or next_sequence_value is not int
		or dropped_value is not int
		or events_value is not Array
	):
		return false
	var events := events_value as Array
	return (
		schema_value as int == SessionDiagnosticRecordType.SCHEMA_VERSION
		and capacity_value as int == SessionDiagnosticRecordType.MAX_EVENTS
		and next_sequence_value as int > 0
		and next_sequence_value as int <= SessionDiagnosticRecordType.MAX_FIELD_INTEGER
		and dropped_value as int >= 0
		and dropped_value as int <= SessionDiagnosticRecordType.MAX_COUNT
		and events.size() <= SessionDiagnosticRecordType.MAX_EVENTS
	)
