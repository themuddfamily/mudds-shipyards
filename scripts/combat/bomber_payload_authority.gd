class_name BomberPayloadAuthority
extends RefCounted

## Caller-owned admission for a bomber payload release.
##
## This component is deliberately narrower than a weapon or combat authority:
## it accepts one server-authorized, generation/sequence-fenced release intent
## and returns a detached release record. The caller remains responsible for
## consuming that record. No scene, physics, damage, presentation, audio, or
## score state is read or mutated here.

const SCHEMA_VERSION := 1
const MAX_ID_LENGTH := 64
const MAX_AMMUNITION := 64
const MAX_COOLDOWN_SECONDS := 60.0
const MAX_RELEASE_RECORDS := 256
const MAX_RELEASE_POSITION_METERS := 100_000.0
const MAX_RELEASE_SPEED_METERS_PER_SECOND := 10_000.0
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

const RELEASE_KEYS := [
	"generation",
	"payload_id",
	"weapon_id",
	"presentation_id",
	"audio_id",
	"release_position",
	"release_velocity",
]

var _authority_peer_id := 1
var _initial_ammunition := 0
var _cooldown_seconds := 0.0
var _configuration_errors := PackedStringArray()

var _active := false
var _generation := 0
var _ammunition_remaining := 0
var _cooldown_remaining := 0.0
var _last_request_sequence_by_actor: Dictionary = {}
var _next_release_sequence := 1
var _release_records: Array[Dictionary] = []
var _detach_reason: StringName = &""


func _init(
		p_authority_peer_id: int = 1,
		p_ammunition: int = 4,
		p_cooldown_seconds: float = 1.0
) -> void:
	_authority_peer_id = p_authority_peer_id
	_initial_ammunition = p_ammunition
	_cooldown_seconds = p_cooldown_seconds
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func begin_generation(generation: int) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if generation <= 0:
		return _result(false, &"invalid_generation")
	if generation <= _generation:
		return _result(false, &"stale_generation")
	if _active:
		return _result(false, &"authority_active")
	return _start_generation(generation, &"generation_started")


## Re-entry is explicit: detach first, then start a strictly newer generation.
func reset_for_reuse(generation: int) -> Dictionary:
	if _active:
		return _result(false, &"reset_requires_detach")
	var result := begin_generation(generation)
	if bool(result.get("accepted", false)):
		result["reason"] = &"reentered"
	return result.duplicate(true)


## Clears every release cursor and record. A later generation gets fresh ammo
## and cannot inherit the detached actor's sequence or cooldown state.
func detach(reason: StringName = &"detached") -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if not _active:
		return _result(false, &"already_detached")
	_active = false
	_ammunition_remaining = 0
	_cooldown_remaining = 0.0
	_last_request_sequence_by_actor.clear()
	_next_release_sequence = 1
	_release_records.clear()
	_detach_reason = reason if _valid_id(reason) else &"detached"
	return _result(true, &"detached", {"generation": _generation, "detach_reason": _detach_reason})


## The owner advances this injected clock; no wall clock or scene tree is used.
func advance(delta_seconds: float) -> Dictionary:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _result(false, &"invalid_delta")
	if not _active:
		return _result(false, &"authority_detached")
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta_seconds)
	return _result(true, &"advanced", {"cooldown_remaining": _cooldown_remaining})


## Validates and admits exactly one release intent. The input dictionary is
## copied only into a detached record; no caller-owned object is retained.
func submit_release_intent(source_peer_id: int, actor_id: StringName, payload: Dictionary, request_sequence: int) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if not _active:
		return _result(false, &"authority_detached")
	if not _valid_id(actor_id) or not _valid_sequence(request_sequence):
		return _result(false, &"invalid_request")
	if not _has_exact_keys(payload, RELEASE_KEYS):
		return _result(false, &"invalid_payload")
	var generation: Variant = payload.get("generation", null)
	if not generation is int or int(generation) != _generation:
		return _result(false, &"stale_generation")
	var previous_sequence := int(_last_request_sequence_by_actor.get(actor_id, 0))
	if request_sequence <= previous_sequence:
		return _result(false, &"stale_request_sequence")
	if _cooldown_remaining > 0.0:
		return _result(false, &"cooldown")
	if _ammunition_remaining <= 0:
		return _result(false, &"ammunition_exhausted")

	var payload_id := _canonical_id(payload.get("payload_id", &""))
	var weapon_id := _canonical_id(payload.get("weapon_id", &""))
	var presentation_id := _canonical_id(payload.get("presentation_id", &""))
	var audio_id := _canonical_id(payload.get("audio_id", &""))
	if not _valid_id(payload_id) or not _valid_id(weapon_id) \
			or not _valid_id(presentation_id) or not _valid_id(audio_id):
		return _result(false, &"invalid_release_identity")
	var release_position: Variant = payload.get("release_position", null)
	var release_velocity: Variant = payload.get("release_velocity", null)
	if not _valid_vector(release_position, MAX_RELEASE_POSITION_METERS) \
			or not _valid_vector(release_velocity, MAX_RELEASE_SPEED_METERS_PER_SECOND):
		return _result(false, &"invalid_release_vector")

	# Commit all state only after every field has passed validation.
	_last_request_sequence_by_actor[actor_id] = request_sequence
	var release_sequence := _next_release_sequence
	_next_release_sequence += 1
	_ammunition_remaining -= 1
	_cooldown_remaining = _cooldown_seconds
	var record := {
		"schema_version": SCHEMA_VERSION,
		"record_id": "bomber_payload_release_%06d" % release_sequence,
		"release_sequence": release_sequence,
		"generation": _generation,
		"actor_id": actor_id,
		"request_sequence": request_sequence,
		"payload_id": payload_id,
		"weapon_id": weapon_id,
		"presentation_id": presentation_id,
		"audio_id": audio_id,
		"release_position": release_position,
		"release_velocity": release_velocity,
		"ammunition_remaining": _ammunition_remaining,
		"cooldown_remaining": _cooldown_remaining,
	}
	_release_records.append(record.duplicate(true))
	if _release_records.size() > MAX_RELEASE_RECORDS:
		_release_records.pop_front()
	return _result(true, &"payload_release_accepted", {
		"record": record,
		"ammunition_remaining": _ammunition_remaining,
		"cooldown_remaining": _cooldown_remaining,
	})


func get_release_records() -> Array:
	return _release_records.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"authority_peer_id": _authority_peer_id,
		"active": _active,
		"generation": _generation,
		"ammunition_remaining": _ammunition_remaining,
		"cooldown_seconds": _cooldown_seconds,
		"cooldown_remaining": _cooldown_remaining,
		"detach_reason": _detach_reason,
		"release_records": get_release_records(),
		"configuration_errors": get_configuration_errors(),
		"authority": {
			"server_admission": true,
			"raycast": false,
			"movement": false,
			"damage": false,
			"visual_spawn": false,
			"audio_playback": false,
			"score": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	return {"valid": is_configuration_valid(), "contract": get_snapshot()}.duplicate(true)


func _start_generation(generation: int, reason: StringName) -> Dictionary:
	_active = true
	_generation = generation
	_ammunition_remaining = _initial_ammunition
	_cooldown_remaining = 0.0
	_last_request_sequence_by_actor.clear()
	_next_release_sequence = 1
	_release_records.clear()
	_detach_reason = &""
	return _result(true, reason, {"generation": generation, "ammunition_remaining": _ammunition_remaining})


func _validate_configuration() -> void:
	_configuration_errors.clear()
	if _authority_peer_id <= 0:
		_configuration_errors.append("authority_peer_id must be positive")
	if _initial_ammunition < 0 or _initial_ammunition > MAX_AMMUNITION:
		_configuration_errors.append("ammunition is outside the bounded envelope")
	if not is_finite(_cooldown_seconds) or _cooldown_seconds < 0.0 \
			or _cooldown_seconds > MAX_COOLDOWN_SECONDS:
		_configuration_errors.append("cooldown is outside the bounded envelope")


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


func _valid_vector(value: Variant, maximum_length: float) -> bool:
	if not value is Vector3:
		return false
	var vector := value as Vector3
	return vector.is_finite() and vector.length() <= maximum_length


func _valid_sequence(sequence: int) -> bool:
	return sequence > 0 and sequence <= MAX_SAFE_INTEGER


func _valid_id(value: Variant) -> bool:
	var canonical := _canonical_id(value)
	var text := str(canonical)
	return not canonical.is_empty() and text.length() <= MAX_ID_LENGTH \
			and text.is_valid_identifier()


func _canonical_id(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		return StringName(value)
	return &""


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key in extra:
		result[key] = extra[key]
	return result.duplicate(true)
