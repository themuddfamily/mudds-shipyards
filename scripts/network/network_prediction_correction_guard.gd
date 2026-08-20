class_name NetworkPredictionCorrectionGuard
extends RefCounted

## Server-snapshot boundary for an explicitly local client prediction path.
##
## This contract compares a client-owned prediction with a server-owned
## snapshot and returns a detached correction decision. It never applies a
## transform, velocity, command, damage, landing, seat, or ownership change.
## The server is the only accepted snapshot source; a client can therefore
## present the returned correction but cannot turn prediction into authority.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_prediction_correction_guard_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_POSITION_MAGNITUDE := 10_000_000.0
const MAX_VELOCITY_MAGNITUDE := 1_000_000.0
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2
const DEFAULT_POSITION_CORRECTION_THRESHOLD := 0.25
const DEFAULT_VELOCITY_CORRECTION_THRESHOLD := 1.0
const DEFAULT_MAX_POSITION_CORRECTION := 4.0
const DEFAULT_MAX_VELOCITY_CORRECTION := 32.0
const COMPARISON_EPSILON := 0.000001

const _WIRE_KEYS := [
	"schema_version", "server_peer_id", "entity_id", "entity_generation",
	"owner_peer_id", "server_tick", "event_sequence", "position", "velocity",
]
const _PREDICTION_KEYS := [
	"entity_id", "entity_generation", "position", "velocity",
]

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _position_threshold := DEFAULT_POSITION_CORRECTION_THRESHOLD
var _velocity_threshold := DEFAULT_VELOCITY_CORRECTION_THRESHOLD
var _max_position_correction := DEFAULT_MAX_POSITION_CORRECTION
var _max_velocity_correction := DEFAULT_MAX_VELOCITY_CORRECTION
var _entities: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_max_tick_behind: int = DEFAULT_MAX_TICK_BEHIND,
	p_max_tick_ahead: int = DEFAULT_MAX_TICK_AHEAD,
	p_position_threshold: float = DEFAULT_POSITION_CORRECTION_THRESHOLD,
	p_velocity_threshold: float = DEFAULT_VELOCITY_CORRECTION_THRESHOLD,
	p_max_position_correction: float = DEFAULT_MAX_POSITION_CORRECTION,
	p_max_velocity_correction: float = DEFAULT_MAX_VELOCITY_CORRECTION
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_tick_behind = maxi(0, p_max_tick_behind)
	_max_tick_ahead = maxi(0, p_max_tick_ahead)
	_position_threshold = maxf(0.0, p_position_threshold)
	_velocity_threshold = maxf(0.0, p_velocity_threshold)
	_max_position_correction = maxf(_position_threshold, p_max_position_correction)
	_max_velocity_correction = maxf(_velocity_threshold, p_max_velocity_correction)
	_last_result = _result(false, &"uninitialized")


## Test/adapter helper for a server-owned wire snapshot. The guard still
## validates every field and the source peer when this packet is accepted.
static func create_snapshot(
	server_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int,
	server_tick: int,
	event_sequence: int,
	position: Vector3,
	velocity: Vector3
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"server_peer_id": server_peer_id,
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"owner_peer_id": owner_peer_id,
		"server_tick": server_tick,
		"event_sequence": event_sequence,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
	}.duplicate(true)


## Registration is a server lifecycle operation. Reusing an ID requires the
## previous generation to be retired, so late snapshots cannot relatch it.
func register_entity(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(entity_id) or not _valid_positive_integer(entity_generation):
		return _remember(_result(false, &"invalid_entity_identity"))
	if owner_peer_id < 0:
		return _remember(_result(false, &"invalid_owner_peer_id"))
	if _entities.has(entity_id):
		var current := _entities[entity_id] as Dictionary
		if entity_generation <= int(current.entity_generation):
			return _remember(_result(false, &"duplicate_entity"))
		return _remember(_result(false, &"retire_previous_generation_first"))
	_entities[entity_id] = {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"owner_peer_id": owner_peer_id,
		"last_server_tick": -1,
		"last_event_sequence": -1,
		"accepted_snapshot_count": 0,
		"correction_count": 0,
	}
	return _remember(_result(true, &"entity_registered", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
	}))


func retire_entity(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	_entities.erase(entity_id)
	return _remember(_result(true, &"entity_retired"))


## Validates one server snapshot against the current client tick and one
## detached prediction. The prediction is never stored as authoritative state.
func accept_snapshot(
	source_peer_id: int,
	client_peer_id: int,
	client_tick: int,
	predicted_state: Dictionary,
	wire_snapshot: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if client_peer_id <= 0 or not _valid_nonnegative_integer(client_tick):
		return _remember(_result(false, &"invalid_client_tick"))
	if not _has_exact_keys(wire_snapshot, _WIRE_KEYS):
		return _remember(_result(false, &"invalid_snapshot_schema"))
	var packet := _decode_snapshot(wire_snapshot)
	if not bool(packet.valid):
		return _remember(_result(false, &"invalid_snapshot", {
			"errors": packet.errors,
		}))
	if int(packet.server_peer_id) != _authority_peer_id:
		return _remember(_result(false, &"snapshot_not_from_authority"))
	var entity_id := StringName(packet.entity_id)
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(packet.entity_generation) != int(entity.entity_generation):
		return _remember(_result(false, &"stale_entity_generation"))
	if int(packet.owner_peer_id) != int(entity.owner_peer_id):
		return _remember(_result(false, &"owner_mismatch"))
	var predicted_errors := _validate_prediction(predicted_state, entity_id, int(packet.entity_generation))
	if not predicted_errors.is_empty():
		return _remember(_result(false, &"invalid_prediction", {"errors": predicted_errors}))
	var server_tick := int(packet.server_tick)
	var last_tick := int(entity.last_server_tick)
	if server_tick < client_tick - _max_tick_behind:
		return _remember(_result(false, &"snapshot_tick_too_old"))
	if server_tick > client_tick + _max_tick_ahead:
		return _remember(_result(false, &"snapshot_tick_too_far_ahead"))
	if server_tick <= last_tick:
		return _remember(_result(false, &"stale_snapshot_tick"))
	if int(packet.event_sequence) <= int(entity.last_event_sequence):
		return _remember(_result(false, &"stale_event_sequence"))

	var authoritative_position: Vector3 = packet.get("position", Vector3.ZERO)
	var authoritative_velocity: Vector3 = packet.get("velocity", Vector3.ZERO)
	# `_validate_prediction` has already rejected malformed arrays; decode the
	# accepted detached values here rather than casting their wire arrays.
	var prediction_decode_errors := PackedStringArray()
	var predicted_position := _decode_vector(
		predicted_state.get("position", []), "prediction position",
		prediction_decode_errors, MAX_POSITION_MAGNITUDE
	)
	var predicted_velocity := _decode_vector(
		predicted_state.get("velocity", []), "prediction velocity",
		prediction_decode_errors, MAX_VELOCITY_MAGNITUDE
	)
	var position_delta := authoritative_position - predicted_position
	var velocity_delta := authoritative_velocity - predicted_velocity
	var position_error := position_delta.length()
	var velocity_error := velocity_delta.length()
	if position_error > _max_position_correction + COMPARISON_EPSILON:
		return _remember(_result(false, &"position_correction_exceeds_hard_limit", {
			"position_error_meters": position_error,
			"max_position_correction": _max_position_correction,
		}))
	if velocity_error > _max_velocity_correction + COMPARISON_EPSILON:
		return _remember(_result(false, &"velocity_correction_exceeds_hard_limit", {
			"velocity_error_mps": velocity_error,
			"max_velocity_correction": _max_velocity_correction,
		}))
	entity.last_server_tick = server_tick
	entity.last_event_sequence = int(packet.event_sequence)
	entity.accepted_snapshot_count = int(entity.accepted_snapshot_count) + 1
	var correction_required := position_error > _position_threshold + COMPARISON_EPSILON \
		or velocity_error > _velocity_threshold + COMPARISON_EPSILON
	if correction_required:
		entity.correction_count = int(entity.correction_count) + 1
	var status: StringName = &"correction_required" if correction_required else &"within_threshold"
	return _remember(_result(true, status, {
		"entity_id": entity_id,
		"server_tick": server_tick,
		"event_sequence": int(packet.event_sequence),
		"position_error_meters": position_error,
		"velocity_error_mps": velocity_error,
		"position_delta": _encode_vector(position_delta),
		"velocity_delta": _encode_vector(velocity_delta),
		"authoritative_state": {
			"position": _encode_vector(authoritative_position),
			"velocity": _encode_vector(authoritative_velocity),
		},
		"client_can_mutate_state": false,
	}))


func get_entity_snapshot(entity_id: StringName) -> Dictionary:
	return (_entities.get(entity_id, {}) as Dictionary).duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_snapshot_validation": true,
		"server_owns_correction_source": true,
		"client_prediction_is_presentation_only": true,
		"client_can_mutate_state": false,
		"registered_entity_count": _entities.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _decode_snapshot(data: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	for key in ["schema_version", "server_peer_id", "entity_generation", "owner_peer_id", "server_tick", "event_sequence"]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	for key in ["entity_id"]:
		var value: Variant = data.get(key)
		if not value is String and not value is StringName:
			errors.append("%s must remain an identifier on the wire" % key)
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("unsupported prediction snapshot schema version")
	if int(data.get("server_peer_id", 0)) <= 0:
		errors.append("server_peer_id must be positive")
	if not _valid_id(StringName(data.get("entity_id", &""))):
		errors.append("entity_id must be a stable identifier")
	if not _valid_positive_integer(int(data.get("entity_generation", 0))):
		errors.append("entity_generation must be positive and safe")
	if int(data.get("owner_peer_id", -1)) < 0:
		errors.append("owner_peer_id must be non-negative")
	if not _valid_nonnegative_integer(int(data.get("server_tick", -1))):
		errors.append("server_tick must be non-negative and safe")
	if not _valid_nonnegative_integer(int(data.get("event_sequence", -1))):
		errors.append("event_sequence must be non-negative and safe")
	var position := _decode_vector(data.get("position", []), "position", errors, MAX_POSITION_MAGNITUDE)
	var velocity := _decode_vector(data.get("velocity", []), "velocity", errors, MAX_VELOCITY_MAGNITUDE)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"server_peer_id": int(data.get("server_peer_id", 0)),
		"entity_id": StringName(data.get("entity_id", &"")),
		"entity_generation": int(data.get("entity_generation", 0)),
		"owner_peer_id": int(data.get("owner_peer_id", -1)),
		"server_tick": int(data.get("server_tick", -1)),
		"event_sequence": int(data.get("event_sequence", -1)),
		"position": position,
		"velocity": velocity,
	}


func _validate_prediction(data: Dictionary, expected_entity_id: StringName, expected_generation: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_keys(data, _PREDICTION_KEYS):
		errors.append("prediction fields must match the local state schema")
	var entity_value: Variant = data.get("entity_id", &"")
	if not entity_value is String and not entity_value is StringName:
		errors.append("prediction entity_id must remain an identifier")
	elif StringName(entity_value) != expected_entity_id:
		errors.append("prediction entity_id does not match snapshot")
	if not data.get("entity_generation", 0) is int or int(data.get("entity_generation", 0)) != expected_generation:
		errors.append("prediction generation does not match snapshot")
	_decode_vector(data.get("position", []), "prediction position", errors, MAX_POSITION_MAGNITUDE)
	_decode_vector(data.get("velocity", []), "prediction velocity", errors, MAX_VELOCITY_MAGNITUDE)
	return errors


func _decode_vector(value: Variant, label: String, errors: PackedStringArray, magnitude_limit: float) -> Vector3:
	if not value is Array or (value as Array).size() != 3:
		errors.append("%s must be a three-component array" % label)
		return Vector3.ZERO
	var values := value as Array
	var components := PackedFloat32Array()
	for component in values:
		if not component is float and not component is int:
			errors.append("%s components must be numeric" % label)
			return Vector3.ZERO
		var number := float(component)
		if not is_finite(number):
			errors.append("%s components must be finite" % label)
			return Vector3.ZERO
		components.append(number)
	var result := Vector3(components[0], components[1], components[2])
	if result.length() > magnitude_limit:
		errors.append("%s exceeds the safe magnitude" % label)
		return Vector3.ZERO
	return result


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
			return false
	return true


func _valid_id(entity_id: StringName) -> bool:
	var text := str(entity_id)
	return not text.is_empty() and text.length() <= MAX_ID_LENGTH and text.is_valid_ascii_identifier()


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _encode_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _remember(value: Dictionary) -> Dictionary:
	_last_result = value.duplicate(true)
	return _last_result.duplicate(true)


func _result(accepted: bool, status: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"status": status,
		"schema_version": SCHEMA_VERSION,
	}
	for key in details:
		result[key] = details[key]
	return result.duplicate(true)
