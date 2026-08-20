class_name CrashCleanupLongSessionAudit
extends RefCounted

## Caller-fed acceptance contract for repeated crash/recovery cycles.
##
## This deliberately does not own a scene tree, pooled presentation nodes,
## clock, damage authority, or respawn authority.  A production owner feeds
## the observations at the lifecycle boundaries.  The contract makes four
## failure-prone seams explicit: staged effects must be bounded, pooled nodes
## must return to their fixed capacity, old generations must be released, and
## recovery must complete within the short arcade window.  Primitive resource
## samples are checked on every cycle so a later clean sample cannot hide a
## long-session leak.

const SCHEMA_VERSION := 1
const MAX_IDENTIFIER_BYTES := 128
const MAX_GENERATION := 9_007_199_254_740_991
const MAX_CYCLES := 100_000
const MAX_STAGED_EFFECTS := 32
const MAX_POOL_CAPACITY := 256
const MAX_RECOVERY_SECONDS := 60.0
const MAX_SAMPLE_VALUE := 9_007_199_254_740_991

const STATE_IDLE: StringName = &"idle"
const STATE_READY: StringName = &"ready"
const STATE_STAGED: StringName = &"staged"
const STATE_CLEANED: StringName = &"cleaned"
const STATE_RECOVERED: StringName = &"recovered"
const STATE_FAILED: StringName = &"failed"
const STATE_CLOSED: StringName = &"closed"

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
	"max_recovery_seconds": 3.0,
}

const _LIMIT_KEYS := [
	"max_cycles",
	"max_live_objects_growth",
	"max_live_resources_growth",
	"max_pending_work_growth",
	"max_orphan_count_growth",
	"max_retained_bytes_growth",
	"max_recovery_seconds",
]

var _state: StringName = STATE_IDLE
var _session_id := ""
var _baseline: Dictionary = {}
var _limits: Dictionary = {}
var _peak_growth: Dictionary = {}
var _cycle_count := 0
var _last_source_generation := 0
var _last_generation := 0
var _pool_capacity := 0
var _last_recovery_seconds := 0.0
var _last_sample: Dictionary = {}
var _reason: StringName = &"not_started"


func begin_session(session_id: String, baseline: Dictionary, limits: Dictionary = {}) -> Dictionary:
	if _state != STATE_IDLE:
		return _result(false, &"already_started")
	if session_id.is_empty() or session_id.to_utf8_buffer().size() > MAX_IDENTIFIER_BYTES:
		return _result(false, &"session_id_invalid")
	var baseline_result := validate_sample(baseline)
	if not bool(baseline_result.get("accepted", false)):
		return _result(false, StringName(baseline_result.get("reason", &"sample_invalid")))
	var resolved := _resolve_limits(limits)
	if resolved.is_empty():
		return _result(false, &"limits_invalid")
	_state = STATE_READY
	_session_id = session_id
	_baseline = baseline.duplicate(true)
	_limits = resolved
	_peak_growth.clear()
	for metric in METRICS:
		_peak_growth[metric] = 0
	_cycle_count = 0
	_last_source_generation = 0
	_last_generation = 0
	_pool_capacity = 0
	_last_recovery_seconds = 0.0
	_last_sample = baseline.duplicate(true)
	_reason = &"started"
	return _result(true, &"started")


## Begins one crash presentation cycle. `staged_effect_ids` are the
## caller-owned effect/node identities that were created for this generation.
## A pool is fixed-capacity: active + free must equal capacity at every stage.
func begin_cycle(
		source_generation: int,
		staged_effect_ids: Array,
		pool: Dictionary
		) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_READY:
		return _fail(&"cycle_not_ready")
	if not _valid_generation(source_generation) or source_generation <= _last_generation:
		return _fail(&"source_generation_invalid")
	if _cycle_count >= int(_limits.get("max_cycles", 0)):
		return _fail(&"cycle_limit_exceeded")
	var effects_result := _validate_effect_ids(staged_effect_ids)
	if not bool(effects_result.get("accepted", false)):
		return _fail(StringName(effects_result.get("reason", &"staged_effects_invalid")))
	var pool_result := _validate_pool(pool, true, 0)
	if not bool(pool_result.get("accepted", false)):
		return _fail(StringName(pool_result.get("reason", &"pool_invalid")))
	_pool_capacity = int(pool.get("capacity", 0))
	_last_source_generation = source_generation
	_state = STATE_STAGED
	_reason = &"staged"
	return _result(true, &"staged")


## Records the effect/pool boundary after destruction cleanup.  No staged
## effect, active pooled node, callback, or old-generation authority may
## survive this boundary.
func record_cleanup(
		source_generation: int,
		sample: Dictionary,
		staged_effect_ids_after: Array,
		pool_after: Dictionary,
		pending_callbacks_after: int,
		stale_callbacks_cancelled: bool,
		old_generation_released: bool
		) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_STAGED:
		return _fail(&"cleanup_not_staged")
	if source_generation != _last_source_generation:
		return _fail(&"cleanup_generation_mismatch")
	var sample_result := _measure_sample(sample)
	if not bool(sample_result.get("accepted", false)):
		return _fail(StringName(sample_result.get("reason", &"sample_invalid")))
	if not staged_effect_ids_after.is_empty():
		return _fail(&"staged_effects_retained")
	var pool_result := _validate_pool(pool_after, false, _pool_capacity)
	if not bool(pool_result.get("accepted", false)):
		return _fail(StringName(pool_result.get("reason", &"pool_cleanup_invalid")))
	if pending_callbacks_after != 0:
		return _fail(&"pending_callbacks_retained")
	if not stale_callbacks_cancelled:
		return _fail(&"stale_callbacks_not_cancelled")
	if not old_generation_released:
		return _fail(&"old_generation_retained")
	_state = STATE_CLEANED
	_reason = &"cleaned"
	return _result(true, &"cleaned")


## Records the caller-owned recovery timer and the restored primitive sample.
## The timer is supplied by physics; this contract never reads wall time.
func record_recovery(
		source_generation: int,
		next_generation: int,
		recovery_seconds: float,
		sample: Dictionary,
		restored: bool
		) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_CLEANED:
		return _fail(&"recovery_not_cleaned")
	if source_generation != _last_source_generation:
		return _fail(&"recovery_source_generation_mismatch")
	if not _valid_generation(next_generation) or next_generation != source_generation + 1:
		return _fail(&"recovery_generation_invalid")
	if not is_finite(recovery_seconds) or recovery_seconds < 0.0:
		return _fail(&"recovery_time_invalid")
	if recovery_seconds > float(_limits.get("max_recovery_seconds", MAX_RECOVERY_SECONDS)):
		return _fail(&"recovery_time_exceeded")
	if not restored:
		return _fail(&"recovery_not_restored")
	var sample_result := _measure_sample(sample)
	if not bool(sample_result.get("accepted", false)):
		return _fail(StringName(sample_result.get("reason", &"sample_invalid")))
	_last_generation = next_generation
	_last_recovery_seconds = recovery_seconds
	_state = STATE_RECOVERED
	_cycle_count += 1
	_reason = &"recovered"
	return _result(true, &"recovered")


## Re-entry proves that the just-retired generation cannot be used again.
## This is intentionally a separate boundary from recovery so a production
## owner cannot claim a clean teardown merely because a replacement spawned.
func record_reentry(
		stale_generation: int,
		current_generation: int,
		stale_request_rejected: bool,
		stale_reason: StringName,
		state_restored: bool
		) -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_RECOVERED:
		return _fail(&"reentry_not_recovered")
	if stale_generation != _last_source_generation:
		return _fail(&"reentry_stale_generation_invalid")
	if current_generation != _last_generation:
		return _fail(&"reentry_current_generation_invalid")
	if not stale_request_rejected:
		return _fail(&"stale_reentry_accepted")
	if stale_reason != &"stale_generation" and stale_reason != &"stale_attachment_generation":
		return _fail(&"stale_reentry_reason_invalid")
	if not state_restored:
		return _fail(&"reentry_state_not_restored")
	_state = STATE_READY
	_reason = &"ready"
	return _result(true, &"ready")


func close_session() -> Dictionary:
	if _state == STATE_FAILED:
		return _result(false, &"audit_failed")
	if _state != STATE_READY:
		return _fail(&"session_not_detached")
	_state = STATE_CLOSED
	_reason = &"closed"
	return _result(true, &"closed")


func audit() -> Dictionary:
	return {
		"valid": _state == STATE_CLOSED,
		"schema_version": SCHEMA_VERSION,
		"state": _state,
		"session_id": _session_id,
		"reason": _reason,
		"cycles": _cycle_count,
		"last_source_generation": _last_source_generation,
		"last_generation": _last_generation,
		"last_recovery_seconds": _last_recovery_seconds,
		"pool_capacity": _pool_capacity,
		"growth": {
			"baseline": _baseline.duplicate(true),
			"last_sample": _last_sample.duplicate(true),
			"peak": _peak_growth.duplicate(true),
			"limits": _limits.duplicate(true),
		},
		"authority": {
			"scene_tree": false,
			"pool": false,
			"clock": false,
			"damage": false,
			"respawn": false,
		}.duplicate(true),
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return audit()


static func validate_sample(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"sample_not_dictionary"}
	var sample := candidate as Dictionary
	if sample.size() != METRICS.size():
		return {"accepted": false, "reason": &"sample_fields_invalid"}
	for metric in METRICS:
		if not sample.has(metric) or not _valid_integer(sample.get(metric), 0, MAX_SAMPLE_VALUE):
			return {"accepted": false, "reason": StringName("%s_invalid" % metric)}
	return {"accepted": true, "reason": &"valid"}


func _measure_sample(sample: Dictionary) -> Dictionary:
	var result := validate_sample(sample)
	if not bool(result.get("accepted", false)):
		return result
	var next_peak := _peak_growth.duplicate(true)
	for metric in METRICS:
		var growth := int(sample.get(metric)) - int(_baseline.get(metric, 0))
		var peak := maxi(int(next_peak.get(metric, 0)), growth)
		var limit_key := "max_%s_growth" % metric
		if growth > int(_limits.get(limit_key, 0)):
			return {"accepted": false, "reason": StringName("%s_growth_exceeded" % metric)}
		next_peak[metric] = peak
	_peak_growth = next_peak
	_last_sample = sample.duplicate(true)
	return {"accepted": true, "reason": &"within_limits"}


func _resolve_limits(candidate: Dictionary) -> Dictionary:
	var resolved := DEFAULT_LIMITS.duplicate(true)
	for key in candidate.keys():
		if not _LIMIT_KEYS.has(key):
			return {}
		if key == "max_recovery_seconds":
			var seconds: Variant = candidate.get(key)
			if seconds is bool or not (seconds is float or seconds is int):
				return {}
			if not is_finite(float(seconds)) or float(seconds) < 0.0 or float(seconds) > MAX_RECOVERY_SECONDS:
				return {}
			resolved[key] = float(seconds)
			continue
		if not _valid_integer(candidate.get(key), 0, MAX_SAMPLE_VALUE):
			return {}
		if key == "max_cycles" and int(candidate.get(key)) > MAX_CYCLES:
			return {}
		resolved[key] = int(candidate.get(key))
	return resolved


func _validate_effect_ids(effect_ids: Array) -> Dictionary:
	if effect_ids.is_empty() or effect_ids.size() > MAX_STAGED_EFFECTS:
		return {"accepted": false, "reason": &"staged_effects_count_invalid"}
	var seen := {}
	for raw_id in effect_ids:
		var id := str(raw_id)
		if id.is_empty() or id.to_utf8_buffer().size() > MAX_IDENTIFIER_BYTES or seen.has(id):
			return {"accepted": false, "reason": &"staged_effect_id_invalid"}
		seen[id] = true
	return {"accepted": true, "reason": &"valid"}


func _validate_pool(pool: Dictionary, require_active: bool, expected_capacity: int) -> Dictionary:
	for key in ["capacity", "active", "free"]:
		if not pool.has(key) or not _valid_integer(pool.get(key), 0, MAX_POOL_CAPACITY):
			return {"accepted": false, "reason": StringName("pool_%s_invalid" % key)}
	var capacity := int(pool.get("capacity"))
	var active := int(pool.get("active"))
	var free := int(pool.get("free"))
	if capacity <= 0 or active > capacity or free > capacity or active + free != capacity:
		return {"accepted": false, "reason": &"pool_accounting_invalid"}
	if expected_capacity > 0 and capacity != expected_capacity:
		return {"accepted": false, "reason": &"pool_capacity_changed"}
	if require_active and active <= 0:
		return {"accepted": false, "reason": &"pool_has_no_active_nodes"}
	if (not require_active and active != 0) or (not require_active and free != capacity):
		return {"accepted": false, "reason": &"pool_nodes_retained"}
	return {"accepted": true, "reason": &"valid"}


func _valid_generation(value: int) -> bool:
	return value > 0 and value <= MAX_GENERATION


static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is bool or not (value is int):
		return false
	return int(value) >= minimum and int(value) <= maximum


func _fail(reason: StringName) -> Dictionary:
	_state = STATE_FAILED
	_reason = reason
	return _result(false, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"state": _state,
		"cycles": _cycle_count,
		"source_generation": _last_source_generation,
		"generation": _last_generation,
	}.duplicate(true)
