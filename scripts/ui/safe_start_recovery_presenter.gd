class_name SafeStartRecoveryPresenter
extends RefCounted

## Presentation-only consumer for caller-owned recovery receipts and detached
## diagnostic snapshots. It does not inspect settings, perform restoration, or
## own crash diagnostics.

const COMPONENT_ID: StringName = &"safe-start-recovery-presenter"
const RecoveryRecordType := preload(
	"res://scripts/recovery/safe_start_recovery_record.gd"
)
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
var _accepted_report: Dictionary = {}
var _source_generation := -1
var _source_revision := -1
var _attached := false
var _mode: StringName = &""


func present_receipt(receipt: Dictionary) -> Dictionary:
	var cursor := _recovery_cursor(receipt)
	if not bool(cursor.get("accepted", false)):
		return _reject(StringName(cursor.get("reason", &"invalid_cursor")))
	var generation := int(cursor.get("generation", -1))
	var revision := int(cursor.get("revision", -1))
	if _attached and generation < _source_generation:
		return _reject(&"stale_generation")
	if _attached and generation == _source_generation:
		if revision < _source_revision:
			return _reject(&"stale_revision")
		if revision == _source_revision:
			if receipt != _accepted_report:
				return _reject(&"revision_conflict")
			if _mode == &"receipt":
				return _snapshot.duplicate(true)
	_source_generation = generation
	_source_revision = revision
	_accepted_report = receipt.duplicate(true)
	_attached = true
	_mode = &"receipt"
	if not _valid_receipt(receipt):
		_snapshot = {
			"component_id": COMPONENT_ID,
			"accepted": false,
			"attached": true,
			"generation": generation,
			"revision": revision,
			"status": &"invalid",
			"title": "Recovery information unavailable",
			"message": "READINESS // [STATUS UNAVAILABLE]\nNEXT ACTION // Keep Safe Settings and review recovery information.",
			"readiness": "[STATUS UNAVAILABLE]",
			"next_action": "Keep Safe Settings and review recovery information.",
			"actions": [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}],
			"color_independent": true,
			"presentation_only": true,
			"settings_authority": false,
			"filesystem_authority": false,
		}
		return _snapshot.duplicate(true)
	var graphics := receipt.get("graphics_recovery_receipt", {}) as Dictionary
	var audio := receipt.get("audio_recovery_receipt", {}) as Dictionary
	var graphics_restore_available := not graphics.is_empty() and not bool(graphics.get("consumed", true))
	var audio_restore_available := not audio.is_empty() and not bool(audio.get("consumed", true))
	var restore_record_available := graphics_restore_available or audio_restore_available
	var policy_snapshot := receipt.get("policy_snapshot", {}) as Dictionary
	var stability_confirmed := (
		str(policy_snapshot.get("state", "")) == RecoveryRecordType.STATE_STABLE
		and _status_reason(receipt, "stable_status") in [&"startup_stable", &"already_stable"]
	)
	var restore_available := restore_record_available and stability_confirmed
	var blocked_reason := _blocked_reason(receipt)
	var actions: Array = [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}]
	var status: StringName = &"safe_mode_confirmed"
	var title := "Safe Settings Active"
	var summary := _fallback_summary(graphics_restore_available, audio_restore_available)
	var readiness := "[READY]"
	var next_action := "Continue with the current settings."
	var explanation := "Safe display and audio status was read from the recovery record."
	if not blocked_reason.is_empty():
		status = &"recovery_blocked"
		title = "Settings Recovery Required"
		readiness = "[ACTION REQUIRED]"
		next_action = "Review Settings Recovery before changing display or audio settings."
		explanation = "Settings data was preserved because recovery authority could not safely continue."
		actions.clear()
	elif restore_record_available and not stability_confirmed:
		status = &"safe_mode_active"
		readiness = "[STABILITY CHECK]"
		next_action = "Keep Safe Settings until startup stability is confirmed."
		explanation = "Fallback settings are active while this startup is checked for stability."
	elif restore_available:
		status = &"restore_ready"
		readiness = "[RESTORE READY]"
		var restored_domains := _restore_domains(graphics_restore_available, audio_restore_available)
		next_action = "Restore previous %s settings, or keep the safe settings." % restored_domains
		explanation = "Startup stability is confirmed and previous settings are available."
		actions.push_front({
			"id": &"restore",
			"label": "Restore Previous %s" % restored_domains.capitalize(),
			"focusable": true,
		})
	elif not graphics.is_empty() or not audio.is_empty():
		status = &"recovery_complete"
		readiness = "[RECOVERY COMPLETE]"
		next_action = "Continue with the current settings. Previous fallback receipts are complete."
		explanation = "No previous graphics or audio settings remain available to restore."
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": true,
		"generation": generation,
		"revision": revision,
		"status": status,
		"title": title,
		"message": "%s\nFALLBACK // %s\nREADINESS // %s\nNEXT ACTION // %s" % [
			explanation, summary, readiness, next_action,
		],
		"fallback_summary": summary,
		"readiness": readiness,
		"next_action": next_action,
		"details": {
			"graphics_restore_available": graphics_restore_available,
			"audio_restore_available": audio_restore_available,
			"graphics_receipt_consumed": not graphics.is_empty() and bool(graphics.get("consumed", false)),
			"audio_receipt_consumed": not audio.is_empty() and bool(audio.get("consumed", false)),
			"stability_confirmed": stability_confirmed,
			"blocked_reason": blocked_reason,
		},
		"actions": actions,
		"color_independent": true,
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_accepted_report.clear()
	_source_generation = -1
	_source_revision = -1
	_attached = false
	_mode = &""
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": false,
		"generation": -1,
		"revision": -1,
		"status": &"detached",
		"actions": [],
		"color_independent": true,
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}
	return _snapshot.duplicate(true)


func present_recovery_choice(recommendation: Dictionary) -> Dictionary:
	_mode = &"choice"
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


func request_restore(expected_generation: int = -1, expected_revision: int = -1) -> Dictionary:
	return _intent(&"restore", &"restore_requested", expected_generation, expected_revision)


func request_keep_safe(expected_generation: int = -1, expected_revision: int = -1) -> Dictionary:
	return _intent(&"keep_safe", &"keep_safe_requested", expected_generation, expected_revision)


func _intent(
		action: StringName,
		reason: StringName,
		expected_generation: int = -1,
		expected_revision: int = -1
		) -> Dictionary:
	if expected_generation >= 0 and expected_generation != _source_generation:
		return _reject_intent(action, &"stale_generation")
	if expected_revision >= 0 and expected_revision != _source_revision:
		return _reject_intent(action, &"stale_revision")
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {
				"accepted": true,
				"reason": reason,
				"action": action,
				"generation": _source_generation,
				"revision": _source_revision,
				"presentation_only": true,
				"settings_authority": false,
				"filesystem_authority": false,
			}
	return _reject_intent(action, &"action_unavailable")


func _valid_receipt(receipt: Dictionary) -> bool:
	var schema_value: Variant = receipt.get("schema_version")
	if not schema_value is int or int(schema_value) != 1:
		return false
	var graphics_value: Variant = receipt.get("graphics_recovery_receipt")
	var audio_value: Variant = receipt.get("audio_recovery_receipt")
	if not graphics_value is Dictionary or not audio_value is Dictionary:
		return false
	var generation := _source_generation
	return _valid_fallback_receipt(graphics_value as Dictionary, true, generation) \
		and _valid_fallback_receipt(audio_value as Dictionary, false, generation)


func _valid_fallback_receipt(record: Dictionary, graphics: bool, generation: int) -> bool:
	if record.is_empty():
		return true
	var consumed_value: Variant = record.get("consumed")
	var source_store_generation: Variant = record.get("source_store_generation")
	var prior_values: Variant = record.get("prior_values")
	if not consumed_value is bool \
			or not source_store_generation is int \
			or int(source_store_generation) < 0 \
			or not prior_values is Dictionary:
		return false
	if graphics:
		var startup_generation: Variant = record.get("startup_generation")
		return startup_generation is int \
			and int(startup_generation) == generation \
			and (prior_values as Dictionary).has("graphics_profile") \
			and (prior_values as Dictionary).has("window_mode")
	return (prior_values as Dictionary).has("master_volume") \
		and (prior_values as Dictionary).has("music_volume")


func _recovery_cursor(receipt: Dictionary) -> Dictionary:
	var policy_value: Variant = receipt.get("policy_snapshot")
	if not policy_value is Dictionary:
		return {"accepted": false, "reason": &"invalid_cursor"}
	var policy := policy_value as Dictionary
	var report_generation_value: Variant = receipt.get("startup_generation")
	var policy_schema_value: Variant = policy.get("schema_version")
	var generation_value: Variant = policy.get("startup_generation")
	var revision_value: Variant = policy.get("record_generation")
	if not report_generation_value is int \
			or not policy_schema_value is int \
			or int(policy_schema_value) != RecoveryRecordType.SCHEMA_VERSION \
			or not generation_value is int \
			or not revision_value is int:
		return {"accepted": false, "reason": &"invalid_cursor"}
	var report_generation := int(report_generation_value)
	var generation := int(generation_value)
	var revision := int(revision_value)
	if report_generation < 0 \
			or report_generation > RecoveryRecordType.MAX_SAFE_JSON_INTEGER \
			or (report_generation > 0 and report_generation != generation) \
			or generation < 0 or generation > RecoveryRecordType.MAX_SAFE_JSON_INTEGER \
			or revision < 0 or revision > RecoveryRecordType.MAX_SAFE_JSON_INTEGER:
		return {"accepted": false, "reason": &"invalid_cursor"}
	return {
		"accepted": true,
		"generation": generation,
		"revision": revision,
	}


func _blocked_reason(receipt: Dictionary) -> StringName:
	var begin_reason := _status_reason(receipt, "begin_status")
	if begin_reason in [
		&"settings_authority_blocked", &"store_recovery_required", &"restore_rejected",
		&"policy_unavailable", &"store_unavailable", &"startup_generation_exhausted",
	]:
		return begin_reason
	var restore_reason := _status_reason(receipt, "restore_status")
	if restore_reason in [&"store_load_unavailable", &"record_schema_newer", &"invalid_record"]:
		return restore_reason
	return &""


func _status_reason(receipt: Dictionary, key: String) -> StringName:
	var status_value: Variant = receipt.get(key, {})
	if not status_value is Dictionary:
		return &""
	return StringName((status_value as Dictionary).get("reason", &""))


func _fallback_summary(graphics: bool, audio: bool) -> String:
	if graphics and audio:
		return "SAFE GRAPHICS + SAFE AUDIO ACTIVE"
	if graphics:
		return "SAFE GRAPHICS ACTIVE // AUDIO UNCHANGED"
	if audio:
		return "GRAPHICS UNCHANGED // SAFE AUDIO ACTIVE"
	return "NO ACTIVE FALLBACK RECEIPTS"


func _restore_domains(graphics: bool, audio: bool) -> String:
	if graphics and audio:
		return "graphics and audio"
	return "graphics" if graphics else "audio"


func _reject(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"generation": _source_generation,
		"revision": _source_revision,
		"snapshot": _snapshot.duplicate(true),
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}.duplicate(true)


func _reject_intent(action: StringName, reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"action": action,
		"generation": _source_generation,
		"revision": _source_revision,
		"presentation_only": true,
		"settings_authority": false,
		"filesystem_authority": false,
	}


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
