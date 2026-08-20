class_name LongSessionTeardownAudit
extends RefCounted

## A deterministic, caller-fed audit for repeated scene attach/detach cycles.
##
## This contract deliberately observes primitive counters rather than reaching
## into a scene tree, renderer, allocator, or clock.  The owning session feeds
## a baseline and one sample at each attach/detach boundary.  Every sample is
## compared with the baseline; a growth breach is terminal and fail-closed so
## a later clean sample cannot hide an earlier long-session leak.

const SCHEMA_VERSION := 1

const STATE_IDLE := "idle"
const STATE_DETACHED := "detached"
const STATE_ATTACHED := "attached"
const STATE_CLOSED := "closed"
const STATE_FAILED := "failed"

const MAX_IDENTIFIER_BYTES := 128
const MAX_COUNTER := 9_007_199_254_740_991
const MAX_SAMPLE_VALUE := 9_007_199_254_740_991
const MAX_CYCLES_LIMIT := 1_000_000
const MAX_GROWTH_LIMIT := 9_007_199_254_740_991

const METRICS := [
	"live_objects",
	"live_resources",
	"pending_work",
	"orphan_count",
	"retained_bytes",
]

const DEFAULT_LIMITS := {
	"max_cycles": 1000,
	"max_live_objects_growth": 0,
	"max_live_resources_growth": 0,
	"max_pending_work_growth": 0,
	"max_orphan_count_growth": 0,
	"max_retained_bytes_growth": 0,
}

const _LIMIT_KEYS := [
	"max_cycles",
	"max_live_objects_growth",
	"max_live_resources_growth",
	"max_pending_work_growth",
	"max_orphan_count_growth",
	"max_retained_bytes_growth",
]

var _state := STATE_IDLE
var _session_id := ""
var _attachment_generation := 0
var _attach_count := 0
var _detach_count := 0
var _baseline: Dictionary = {}
var _last_sample: Dictionary = {}
var _peak_growth: Dictionary = {}
var _limits: Dictionary = {}
var _reason: StringName = &"not_started"


## Starts a detached audit with a caller-owned baseline.  The baseline is the
## only reference point; this object owns no gameplay or resource authority.
func begin_session(session_id: String, baseline: Dictionary, limits: Dictionary = {}) -> Dictionary:
	if _state != STATE_IDLE:
		return _result(false, &"already_started")
	if not _valid_identifier(session_id):
		return _result(false, &"session_id_invalid")
	var baseline_check := validate_sample(baseline)
	if not bool(baseline_check.accepted):
		return _result(false, StringName(baseline_check.reason))
	var resolved_limits := _resolve_limits(limits)
	if resolved_limits.is_empty():
		return _result(false, &"limits_invalid")
	_state = STATE_DETACHED
	_session_id = session_id
	_attachment_generation = 0
	_attach_count = 0
	_detach_count = 0
	_baseline = baseline.duplicate(true)
	_last_sample = baseline.duplicate(true)
	_peak_growth = {}
	for metric in METRICS:
		_peak_growth[metric] = 0
	_limits = resolved_limits
	_reason = &"started"
	return _result(true, &"started")


## Records one successful attach. Generations must be exactly sequential.
func record_attach(attachment_generation: int, sample: Dictionary) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_DETACHED:
		return _fail(&"attach_not_detached")
	if attachment_generation <= 0 or attachment_generation != _attachment_generation + 1:
		return _fail(&"attachment_generation_invalid")
	if _attach_count >= int(_limits.get("max_cycles", 0)):
		return _fail(&"cycle_limit_exceeded")
	var sample_result := _validate_and_measure(sample)
	if not bool(sample_result.accepted):
		return _fail(StringName(sample_result.reason))
	_attachment_generation = attachment_generation
	_attach_count += 1
	_last_sample = sample.duplicate(true)
	_state = STATE_ATTACHED
	_reason = &"attached"
	return _result(true, &"attached")


## Records one successful detach. The generation must match the active attach.
func record_detach(attachment_generation: int, sample: Dictionary) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_ATTACHED:
		return _fail(&"detach_not_attached")
	if attachment_generation != _attachment_generation:
		return _fail(&"attachment_generation_mismatch")
	var sample_result := _validate_and_measure(sample)
	if not bool(sample_result.accepted):
		return _fail(StringName(sample_result.reason))
	_detach_count += 1
	_last_sample = sample.duplicate(true)
	_state = STATE_DETACHED
	_reason = &"detached"
	return _result(true, &"detached")


## Closes only after a balanced, detached run. A close is the terminal proof
## that every attach received its matching detach.
func close_session() -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_DETACHED:
		return _fail(&"session_still_attached")
	if _attach_count != _detach_count:
		return _fail(&"attach_detach_unbalanced")
	_state = STATE_CLOSED
	_reason = &"closed"
	return _result(true, &"closed")


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": _state,
		"session_id": _session_id,
		"attachment_generation": _attachment_generation,
		"attach_count": _attach_count,
		"detach_count": _detach_count,
		"baseline": _baseline.duplicate(true),
		"last_sample": _last_sample.duplicate(true),
		"peak_growth": _peak_growth.duplicate(true),
		"limits": _limits.duplicate(true),
		"reason": _reason,
	}.duplicate(true)


## Returns a detached report suitable for a release/evidence record. `valid`
## is true only after close; open, failed, and malformed runs fail closed.
func audit() -> Dictionary:
	var balanced := _attach_count == _detach_count
	return {
		"valid": _state == STATE_CLOSED and balanced,
		"reason": _reason,
		"state": _state,
		"session_id": _session_id,
		"counters": {
			"attach_count": _attach_count,
			"detach_count": _detach_count,
			"balanced": balanced,
			"attachment_generation": _attachment_generation,
		},
		"growth": {
			"baseline": _baseline.duplicate(true),
			"last_sample": _last_sample.duplicate(true),
			"peak": _peak_growth.duplicate(true),
			"limits": _limits.duplicate(true),
		},
		"authority": {
			"scene_tree": false,
			"resource_allocator": false,
			"renderer": false,
			"clock": false,
			"filesystem": false,
		},
	}.duplicate(true)


## Validates a complete primitive sample before it can affect an audit.
static func validate_sample(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"sample_not_dictionary"}
	var sample := candidate as Dictionary
	if not _has_exact_keys(sample, METRICS):
		return {"accepted": false, "reason": &"sample_fields_invalid"}
	for metric in METRICS:
		if not _valid_bounded_integer(sample.get(metric), 0, MAX_SAMPLE_VALUE):
			return {"accepted": false, "reason": StringName("%s_invalid" % metric)}
	return {"accepted": true, "reason": &"valid"}


func _validate_and_measure(sample: Dictionary) -> Dictionary:
	var sample_result := validate_sample(sample)
	if not bool(sample_result.accepted):
		return sample_result
	var next_peak := _peak_growth.duplicate(true)
	for metric in METRICS:
		var growth := int(sample.get(metric)) - int(_baseline.get(metric, 0))
		var peak := maxi(int(next_peak.get(metric, 0)), growth)
		var limit_key := _growth_limit_key(metric)
		if growth > int(_limits.get(limit_key, 0)):
			return {
				"accepted": false,
				"reason": StringName("%s_growth_exceeded" % metric),
			}
		next_peak[metric] = peak
	_peak_growth = next_peak
	return {"accepted": true, "reason": &"within_limits"}


func _resolve_limits(candidate: Dictionary) -> Dictionary:
	var resolved := DEFAULT_LIMITS.duplicate(true)
	for key in candidate.keys():
		if not _LIMIT_KEYS.has(key):
			return {}
		if not _valid_bounded_integer(candidate.get(key), 0, MAX_GROWTH_LIMIT):
			return {}
		if key == "max_cycles" and int(candidate.get(key)) > MAX_CYCLES_LIMIT:
			return {}
		resolved[key] = int(candidate.get(key))
	return resolved


func _growth_limit_key(metric: String) -> String:
	return {
		"live_objects": "max_live_objects_growth",
		"live_resources": "max_live_resources_growth",
		"pending_work": "max_pending_work_growth",
		"orphan_count": "max_orphan_count_growth",
		"retained_bytes": "max_retained_bytes_growth",
	}.get(metric, "")


func _fail(reason: StringName) -> Dictionary:
	_state = STATE_FAILED
	_reason = reason
	return _result(false, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"state": _state,
		"attach_count": _attach_count,
		"detach_count": _detach_count,
		"attachment_generation": _attachment_generation,
	}.duplicate(true)


static func _valid_identifier(value: String) -> bool:
	return not value.is_empty() and value.to_utf8_buffer().size() <= MAX_IDENTIFIER_BYTES


static func _valid_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is bool or not (value is int):
		return false
	return int(value) >= minimum and int(value) <= maximum


static func _has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true
