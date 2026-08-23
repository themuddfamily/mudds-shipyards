class_name BomberPayloadProjectile
extends RefCounted

## Caller-advanced ballistic state for one admitted bomber payload release.
##
## The component consumes a detached BomberPayloadAuthority record, advances
## only its own finite position/velocity envelope, and returns one resolver-ready
## impact or expiry intent. It does not query a world, raycast, move a ship,
## apply damage, spawn presentation/audio, or award score.

const SCHEMA_VERSION := 1
const MAX_ID_LENGTH := 64
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_RELEASE_POSITION_METERS := 100_000.0
const MAX_RELEASE_SPEED_METERS_PER_SECOND := 10_000.0
const MAX_GRAVITY_METERS_PER_SECOND_SQUARED := 1_000.0
const MAX_LIFETIME_SECONDS := 600.0
const MAX_TRAVEL_DISTANCE_METERS := 1_000_000.0
const MAX_WORLD_POSITION_METERS := 2_000_000.0

const RELEASE_RECORD_KEYS := [
	"schema_version",
	"record_id",
	"release_sequence",
	"generation",
	"actor_id",
	"request_sequence",
	"payload_id",
	"weapon_id",
	"presentation_id",
	"audio_id",
	"release_position",
	"release_velocity",
	"ammunition_remaining",
	"cooldown_remaining",
]

var _authority_peer_id := 1
var _gravity := Vector3.ZERO
var _maximum_lifetime := 0.0
var _maximum_speed := 0.0
var _maximum_travel_distance := 0.0
var _configuration_errors := PackedStringArray()

var _active := false
var _generation := 0
var _state: StringName = &"detached"
var _release_record: Dictionary = {}
var _release_sequence := 0
var _request_sequence := 0
var _start_position := Vector3.ZERO
var _position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _elapsed_lifetime := 0.0
var _remaining_lifetime := 0.0
var _travel_distance := 0.0
var _terminal_sequence := 0
var _terminal_intent: Dictionary = {}
var _terminal_emitted := false


func _init(
		p_authority_peer_id: int = 1,
		p_gravity: Vector3 = Vector3(0.0, -9.81, 0.0),
		p_maximum_lifetime: float = 30.0,
		p_maximum_speed: float = 500.0,
		p_maximum_travel_distance: float = 100_000.0
) -> void:
	_authority_peer_id = p_authority_peer_id
	_gravity = p_gravity
	_maximum_lifetime = p_maximum_lifetime
	_maximum_speed = p_maximum_speed
	_maximum_travel_distance = p_maximum_travel_distance
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


## Re-entry is explicit and requires the old projectile to be detached first.
func reset_for_reuse(generation: int) -> Dictionary:
	if _active:
		return _result(false, &"reset_requires_detach")
	var result := begin_generation(generation)
	if bool(result.get("accepted", false)):
		result["reason"] = &"reentered"
	return result.duplicate(true)


## Detach clears the release and terminal ledgers without inventing a resolver
## event. The caller may then re-enter with a strictly newer generation.
func detach(reason: StringName = &"detached") -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if not _active:
		return _result(false, &"already_detached")
	_active = false
	_state = &"detached"
	_release_record.clear()
	_release_sequence = 0
	_request_sequence = 0
	_start_position = Vector3.ZERO
	_position = Vector3.ZERO
	_velocity = Vector3.ZERO
	_elapsed_lifetime = 0.0
	_remaining_lifetime = 0.0
	_travel_distance = 0.0
	_terminal_intent.clear()
	_terminal_sequence = 0
	_terminal_emitted = false
	return _result(true, &"detached", {"generation": _generation, "detach_reason": _stable_reason(reason)})


## Consumes exactly one detached release record for this lifecycle generation.
## The record is copied; no mutable caller-owned dictionary is retained.
func consume_release_record(source_peer_id: int, release_record: Dictionary) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if not _active:
		return _result(false, &"authority_detached")
	if not _has_exact_keys(release_record, RELEASE_RECORD_KEYS):
		return _result(false, &"invalid_release_record")
	if int(release_record.get("schema_version", -1)) != SCHEMA_VERSION:
		return _result(false, &"unsupported_release_schema")
	var generation: Variant = release_record.get("generation", null)
	if not generation is int or int(generation) != _generation:
		return _result(false, &"stale_generation")
	var release_sequence: Variant = release_record.get("release_sequence", null)
	var request_sequence: Variant = release_record.get("request_sequence", null)
	if not release_sequence is int or not _valid_sequence(int(release_sequence)) \
			or not request_sequence is int or not _valid_sequence(int(request_sequence)):
		return _result(false, &"invalid_release_sequence")
	if not _valid_id(release_record.get("record_id", &"")) \
			or not _valid_id(release_record.get("actor_id", &"")):
		return _result(false, &"invalid_release_identity")
	if not _valid_id(release_record.get("payload_id", &"")) \
			or not _valid_id(release_record.get("weapon_id", &"")) \
			or not _valid_id(release_record.get("presentation_id", &"")) \
			or not _valid_id(release_record.get("audio_id", &"")):
		return _result(false, &"invalid_release_identity")
	var release_position: Variant = release_record.get("release_position", null)
	var release_velocity: Variant = release_record.get("release_velocity", null)
	if not _valid_vector(release_position, MAX_RELEASE_POSITION_METERS) \
			or not _valid_vector(release_velocity, MAX_RELEASE_SPEED_METERS_PER_SECOND):
		return _result(false, &"invalid_release_vector")
	if _state != &"empty":
		if int(release_sequence) == _release_sequence:
			return _result(false, &"duplicate_release")
		return _result(false, &"projectile_active" if _state == &"flying" else &"projectile_terminal")

	_release_record = release_record.duplicate(true)
	_release_sequence = int(release_sequence)
	_request_sequence = int(request_sequence)
	_start_position = release_position as Vector3
	_position = _start_position
	_velocity = _clamp_speed(release_velocity as Vector3)
	_elapsed_lifetime = 0.0
	_remaining_lifetime = _maximum_lifetime
	_travel_distance = 0.0
	_state = &"flying"
	return _result(true, &"release_consumed", {"projectile": get_snapshot()})


## Advances only the caller's physics delta. A hitch larger than the remaining
## lifetime is clamped to the terminal boundary, so expiry is emitted once.
func advance(delta_seconds: float) -> Dictionary:
	if not is_finite(delta_seconds) or delta_seconds < 0.0:
		return _result(false, &"invalid_delta")
	if not _active:
		return _result(false, &"authority_detached")
	if _state != &"flying":
		return _result(false, &"terminal_already_emitted")
	var step := minf(delta_seconds, _remaining_lifetime)
	var next_velocity := _clamp_speed(_velocity + _gravity * step)
	var displacement := (_velocity + next_velocity) * 0.5 * step
	var remaining_distance := maxf(0.0, _maximum_travel_distance - _travel_distance)
	if displacement.length() > remaining_distance:
		if displacement.length() > 0.000001:
			displacement = displacement.normalized() * remaining_distance
	_position += displacement
	if not _position.is_finite() or _position.length() > MAX_WORLD_POSITION_METERS:
		return _finish_expiry(&"position_bound")
	_travel_distance += displacement.length()
	_velocity = next_velocity
	_elapsed_lifetime += step
	_remaining_lifetime = maxf(0.0, _remaining_lifetime - step)
	if _travel_distance >= _maximum_travel_distance - 0.000001:
		return _finish_expiry(&"travel_distance")
	if _remaining_lifetime <= 0.000001:
		return _finish_expiry(&"lifetime")
	return _result(true, &"advanced", {"projectile": get_snapshot()})


## Collision evidence is supplied by the caller; this object never raycasts or
## resolves a target. The returned intent is consumed later by CombatResolver.
func submit_impact(
		source_peer_id: int,
		impact_position: Vector3,
		impact_normal: Vector3,
		target_id: StringName = &"",
		target_generation: int = 0
) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if not _active:
		return _result(false, &"authority_detached")
	if _state != &"flying":
		return _result(false, &"terminal_already_emitted")
	if not _valid_vector(impact_position, MAX_WORLD_POSITION_METERS):
		return _result(false, &"invalid_impact_position")
	if not impact_normal.is_finite() or impact_normal.length_squared() <= 0.000001:
		return _result(false, &"invalid_impact_normal")
	if not target_id.is_empty() and not _valid_id(target_id):
		return _result(false, &"invalid_target_identity")
	if not target_id.is_empty() and not _valid_positive_integer(target_generation):
		return _result(false, &"invalid_target_generation")
	if target_id.is_empty() and target_generation != 0:
		return _result(false, &"invalid_target_generation")
	return _finish_terminal(&"impact", impact_position, impact_normal.normalized(), target_id, target_generation)


func get_terminal_intent() -> Dictionary:
	return _terminal_intent.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"authority_peer_id": _authority_peer_id,
		"active": _active,
		"generation": _generation,
		"state": _state,
		"release_record": _release_record.duplicate(true),
		"release_sequence": _release_sequence,
		"request_sequence": _request_sequence,
		"position": _position,
		"velocity": _velocity,
		"elapsed_lifetime": _elapsed_lifetime,
		"remaining_lifetime": _remaining_lifetime,
		"travel_distance": _travel_distance,
		"terminal_intent": get_terminal_intent(),
		"configuration_errors": get_configuration_errors(),
		"authority": {
			"server_admission": true,
			"projectile_motion": true,
			"ship_movement": false,
			"raycast": false,
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
	_state = &"empty"
	_release_record.clear()
	_release_sequence = 0
	_request_sequence = 0
	_start_position = Vector3.ZERO
	_position = Vector3.ZERO
	_velocity = Vector3.ZERO
	_elapsed_lifetime = 0.0
	_remaining_lifetime = 0.0
	_travel_distance = 0.0
	_terminal_intent.clear()
	_terminal_sequence = 0
	_terminal_emitted = false
	return _result(true, reason, {"generation": generation})


func _finish_expiry(expiry_reason: StringName) -> Dictionary:
	return _finish_terminal(&"expiry", _position, Vector3.ZERO, &"", 0, expiry_reason)


func _finish_terminal(
		kind: StringName,
		terminal_position: Vector3,
		terminal_normal: Vector3,
		target_id: StringName,
		target_generation: int,
		expiry_reason: StringName = &""
) -> Dictionary:
	_state = &"terminal"
	_terminal_sequence += 1
	_terminal_intent = {
		"schema_version": SCHEMA_VERSION,
		"terminal_sequence": _terminal_sequence,
		"generation": _generation,
		"release_sequence": _release_sequence,
		"request_sequence": _request_sequence,
		"record_id": _release_record.get("record_id", &""),
		"kind": kind,
		"position": terminal_position,
		"velocity": _velocity,
		"normal": terminal_normal,
		"target_id": target_id,
		"target_generation": target_generation,
		"expiry_reason": expiry_reason,
		"resolver_ready": true,
	}
	if _terminal_emitted:
		return _result(false, &"terminal_already_emitted")
	_terminal_emitted = true
	return _result(true, &"terminal_intent", {"terminal_intent": _terminal_intent})


func _validate_configuration() -> void:
	_configuration_errors.clear()
	if _authority_peer_id <= 0:
		_configuration_errors.append("authority_peer_id must be positive")
	if not _gravity.is_finite() or _gravity.length() > MAX_GRAVITY_METERS_PER_SECOND_SQUARED:
		_configuration_errors.append("gravity is outside the finite envelope")
	if not is_finite(_maximum_lifetime) or _maximum_lifetime <= 0.0 \
			or _maximum_lifetime > MAX_LIFETIME_SECONDS:
		_configuration_errors.append("lifetime is outside the finite envelope")
	if not is_finite(_maximum_speed) or _maximum_speed <= 0.0 \
			or _maximum_speed > MAX_RELEASE_SPEED_METERS_PER_SECOND:
		_configuration_errors.append("speed is outside the finite envelope")
	if not is_finite(_maximum_travel_distance) or _maximum_travel_distance <= 0.0 \
			or _maximum_travel_distance > MAX_TRAVEL_DISTANCE_METERS:
		_configuration_errors.append("travel distance is outside the finite envelope")


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


func _clamp_speed(value: Vector3) -> Vector3:
	if not value.is_finite():
		return Vector3.ZERO
	if value.length() <= _maximum_speed:
		return value
	return value.normalized() * _maximum_speed


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


func _valid_sequence(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _stable_reason(value: StringName) -> StringName:
	return value if _valid_id(value) else &"detached"


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key in extra:
		result[key] = extra[key]
	return result.duplicate(true)
