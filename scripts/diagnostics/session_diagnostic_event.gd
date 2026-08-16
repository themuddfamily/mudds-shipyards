class_name SessionDiagnosticEvent
extends RefCounted

## Caller-authored, privacy-bounded input for SessionDiagnosticRecord.
##
## Codes and severities are enums instead of caller text. `fields` is validated
## by the record and may contain only its fixed numeric/boolean vocabulary.

enum Code {
	SESSION_STARTED,
	SESSION_REENTERED,
	SESSION_ENDED,
	PHYSICS_STALL,
	CRASH_DETECTED,
	RECOVERY_STARTED,
	RECOVERY_COMPLETED,
	PERSISTENCE_FAILURE,
	CONTROL_SOURCE_CHANGED,
}

enum Severity {
	INFO,
	WARNING,
	ERROR,
}

var code: Code
var severity: Severity
var session_id: int
var physics_tick: int
var session_elapsed_physics_seconds: float
var fields: Dictionary


func _init(
	p_code: Code,
	p_severity: Severity,
	p_session_id: int,
	p_physics_tick: int,
	p_session_elapsed_physics_seconds: float,
	p_fields: Dictionary = {}
	) -> void:
	code = p_code
	severity = p_severity
	session_id = p_session_id
	physics_tick = p_physics_tick
	session_elapsed_physics_seconds = p_session_elapsed_physics_seconds
	fields = p_fields.duplicate(true)
