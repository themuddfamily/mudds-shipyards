class_name SafeStartRecoveryRecord
extends RefCounted

## Strict JSON-safe durable state for the explicit safe-start policy.

const SCHEMA_VERSION := 1
const SAFE_MODE_FAILURE_THRESHOLD := 3
const MAX_CONSECUTIVE_FAILURES := 8
const MAX_SAFE_JSON_INTEGER := 9_007_199_254_740_991

const STATE_IDLE := "idle"
const STATE_STARTING := "starting"
const STATE_STABLE := "stable"
const STATE_CLEAN_SHUTDOWN := "clean_shutdown"

const _KEYS := [
	"schema_version",
	"record_generation",
	"state",
	"startup_generation",
	"consecutive_failure_count",
	"safe_settings_recommended",
]
const _STATES := [
	STATE_IDLE,
	STATE_STARTING,
	STATE_STABLE,
	STATE_CLEAN_SHUTDOWN,
]

var record_generation: int
var state: String
var startup_generation: int
var consecutive_failure_count: int
var safe_settings_recommended: bool


func _init(
	p_record_generation: int = 0,
	p_state: String = STATE_IDLE,
	p_startup_generation: int = 0,
	p_consecutive_failure_count: int = 0,
	p_safe_settings_recommended: bool = false
	) -> void:
	record_generation = p_record_generation
	state = p_state
	startup_generation = p_startup_generation
	consecutive_failure_count = p_consecutive_failure_count
	safe_settings_recommended = p_safe_settings_recommended


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"record_generation": record_generation,
		"state": state,
		"startup_generation": startup_generation,
		"consecutive_failure_count": consecutive_failure_count,
		"safe_settings_recommended": safe_settings_recommended,
	}


func duplicate_record() -> SafeStartRecoveryRecord:
	return SafeStartRecoveryRecord.new(
		record_generation,
		state,
		startup_generation,
		consecutive_failure_count,
		safe_settings_recommended
	)


func audit() -> Dictionary:
	var decoded := decode(to_dictionary())
	return {
		"valid": bool(decoded.accepted),
		"reason": decoded.reason,
		"snapshot": to_dictionary().duplicate(true),
		"safe_mode_failure_threshold": SAFE_MODE_FAILURE_THRESHOLD,
		"maximum_consecutive_failures": MAX_CONSECUTIVE_FAILURES,
	}


static func decode(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _rejection(&"record_not_dictionary")
	var raw := candidate as Dictionary
	var raw_schema: Variant = raw.get("schema_version")
	if not _is_safe_integer(raw_schema):
		return _rejection(&"schema_invalid")
	var schema := int(raw_schema)
	if schema > SCHEMA_VERSION:
		return _rejection(&"newer_schema")
	if schema != SCHEMA_VERSION:
		return _rejection(&"unsupported_schema")
	if not _has_exact_string_keys(raw, _KEYS):
		return _rejection(&"record_fields_invalid")
	if not _is_safe_integer(raw.record_generation):
		return _rejection(&"record_generation_invalid")
	if not _is_safe_integer(raw.startup_generation):
		return _rejection(&"startup_generation_invalid")
	if not _is_safe_integer(raw.consecutive_failure_count):
		return _rejection(&"failure_count_invalid")
	if not raw.state is String or not _STATES.has(raw.state):
		return _rejection(&"state_invalid")
	if not raw.safe_settings_recommended is bool:
		return _rejection(&"recommendation_flag_invalid")

	var generation := int(raw.record_generation)
	var startup := int(raw.startup_generation)
	var failures := int(raw.consecutive_failure_count)
	var state_id := str(raw.state)
	var recommended := bool(raw.safe_settings_recommended)
	if generation < 0:
		return _rejection(&"record_generation_invalid")
	if startup < 0:
		return _rejection(&"startup_generation_invalid")
	if failures < 0 or failures > MAX_CONSECUTIVE_FAILURES:
		return _rejection(&"failure_count_invalid")
	if state_id == STATE_IDLE:
		if generation != 0 or startup != 0 or failures != 0 or recommended:
			return _rejection(&"idle_state_invalid")
	elif generation == 0 or startup == 0:
		return _rejection(&"active_identity_invalid")
	if state_id == STATE_STABLE and (failures != 0 or recommended):
		return _rejection(&"stable_state_invalid")
	if recommended != (failures >= SAFE_MODE_FAILURE_THRESHOLD):
		return _rejection(&"recommendation_state_invalid")

	return {
		"accepted": true,
		"reason": &"valid",
		"record": SafeStartRecoveryRecord.new(
			generation,
			state_id,
			startup,
			failures,
			recommended
		),
	}


static func _rejection(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	for key: String in expected:
		if not candidate.has(key):
			return false
	return true


static func _is_safe_integer(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) \
		and number == floor(number) and absf(number) <= MAX_SAFE_JSON_INTEGER
