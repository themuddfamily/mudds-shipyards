class_name CombatRecoveryPolicy
extends RefCounted

## Bounded post-crash recovery timing for arcade combat.
##
## This policy is deliberately data-only: it does not respawn a ship, change
## GameFlow, repair health, or grant a reward. The owning ship/lifecycle
## adapter starts a generation, advances it from physics, and consumes the
## detached snapshot to drive its own recovery presentation. Keeping the
## timer here makes a short recovery window deterministic at any frame rate
## and prevents an old destroyed craft from making a newer generation
## vulnerable.

signal recovery_started(generation: int)
signal recovery_ready(generation: int)

const STATE_IDLE: StringName = &"idle"
const STATE_RECOVERING: StringName = &"recovering"
const STATE_READY: StringName = &"ready"
const MAX_SECONDS := 60.0

var recovery_seconds := 2.0
var invulnerability_seconds := 0.75
var _state: StringName = STATE_IDLE
var _generation := 0
var _elapsed := 0.0

func _init(recovery_time: float = 2.0, invulnerability_time: float = 0.75) -> void:
	recovery_seconds = recovery_time
	invulnerability_seconds = invulnerability_time

func begin(generation: int) -> Dictionary:
	if generation <= 0 or _state == STATE_RECOVERING:
		return _result(false, &"invalid_generation" if generation <= 0 else &"already_recovering")
	if generation <= _generation:
		return _result(false, &"stale_generation")
	if not _valid_configuration():
		return _result(false, &"invalid_configuration")
	_generation = generation
	_elapsed = 0.0
	_state = STATE_RECOVERING
	recovery_started.emit(_generation)
	return _result(true, &"started")

func tick(delta: float, generation: int) -> Dictionary:
	if generation != _generation:
		return _result(false, &"stale_generation")
	if _state != STATE_RECOVERING:
		return _result(false, &"not_recovering")
	if not is_finite(delta) or delta < 0.0:
		return _result(false, &"invalid_delta")
	_elapsed = minf(recovery_seconds, _elapsed + delta)
	if _elapsed >= recovery_seconds:
		_state = STATE_READY
		recovery_ready.emit(_generation)
	return _result(true, &"ready" if _state == STATE_READY else &"advanced")

func reset() -> void:
	_state = STATE_IDLE
	_elapsed = 0.0

func get_state() -> StringName:
	return _state

func get_generation() -> int:
	return _generation

func get_elapsed() -> float:
	return _elapsed

func is_ready() -> bool:
	return _state == STATE_READY

func is_invulnerable() -> bool:
	return _state == STATE_RECOVERING and _elapsed < invulnerability_seconds

func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"generation": _generation,
		"elapsed": _elapsed,
		"recovery_seconds": recovery_seconds,
		"invulnerability_seconds": invulnerability_seconds,
		"invulnerability_remaining": maxf(0.0, invulnerability_seconds - _elapsed),
	}

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _valid_configuration():
		errors.append("recovery and invulnerability windows must be finite and ordered")
	return errors

func _valid_configuration() -> bool:
	return is_finite(recovery_seconds) and recovery_seconds > 0.0 \
		and recovery_seconds <= MAX_SECONDS \
		and is_finite(invulnerability_seconds) and invulnerability_seconds >= 0.0 \
		and invulnerability_seconds <= recovery_seconds

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"state": _state,
		"elapsed": _elapsed,
	}
