class_name NetworkLandingIntent
extends RefCounted

## Transport-safe request for one landing or respawn transition.
##
## The packet is only a request. It carries no transform, velocity, lease,
## spawn generation, berth occupancy, or respawn position. Those values remain
## server-owned and are returned only after the request has been accepted.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const ACTION_LANDING: StringName = &"landing"
const ACTION_RESPAWN: StringName = &"respawn"
const ACTIONS := [ACTION_LANDING, ACTION_RESPAWN]

const _WIRE_KEYS := [
	"schema_version", "peer_id", "entity_id", "entity_generation",
	"stream_id", "sequence", "client_tick", "action", "region_id",
	"target_id",
]

var _schema_version := 0
var _peer_id := 0
var _entity_id: StringName = &""
var _entity_generation := 0
var _stream_id := 0
var _sequence := 0
var _client_tick := 0
var _action: StringName = &""
var _region_id: StringName = &""
var _target_id: StringName = &""
var _errors := PackedStringArray()


static func create(
	p_peer_id: int,
	p_entity_id: StringName,
	p_entity_generation: int,
	p_stream_id: int,
	p_sequence: int,
	p_client_tick: int,
	p_action: StringName,
	p_region_id: StringName,
	p_target_id: StringName
):
	return new({
		"schema_version": SCHEMA_VERSION,
		"peer_id": p_peer_id,
		"entity_id": p_entity_id,
		"entity_generation": p_entity_generation,
		"stream_id": p_stream_id,
		"sequence": p_sequence,
		"client_tick": p_client_tick,
		"action": p_action,
		"region_id": p_region_id,
		"target_id": p_target_id,
	})


static func from_dictionary(data: Dictionary):
	return new(data.duplicate(true))


func _init(data: Dictionary = {}) -> void:
	_schema_version = int(data.get("schema_version", 0))
	_peer_id = int(data.get("peer_id", 0))
	_entity_id = StringName(data.get("entity_id", &""))
	_entity_generation = int(data.get("entity_generation", 0))
	_stream_id = int(data.get("stream_id", 0))
	_sequence = int(data.get("sequence", 0))
	_client_tick = int(data.get("client_tick", 0))
	_action = StringName(data.get("action", &""))
	_region_id = StringName(data.get("region_id", &""))
	_target_id = StringName(data.get("target_id", &""))
	_errors = _validate(data)


func is_valid() -> bool:
	return _errors.is_empty()


func get_validation_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_peer_id() -> int:
	return _peer_id


func get_entity_id() -> StringName:
	return _entity_id


func get_entity_generation() -> int:
	return _entity_generation


func get_stream_id() -> int:
	return _stream_id


func get_sequence() -> int:
	return _sequence


func get_client_tick() -> int:
	return _client_tick


func get_action() -> StringName:
	return _action


func get_region_id() -> StringName:
	return _region_id


func get_target_id() -> StringName:
	return _target_id


func to_dictionary() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"peer_id": _peer_id,
		"entity_id": _entity_id,
		"entity_generation": _entity_generation,
		"stream_id": _stream_id,
		"sequence": _sequence,
		"client_tick": _client_tick,
		"action": _action,
		"region_id": _region_id,
		"target_id": _target_id,
	}.duplicate(true)


func detached_copy():
	return from_dictionary(to_dictionary())


func _validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_wire_keys(data):
		errors.append("landing intent fields must match the wire schema")
	for key in ["schema_version", "peer_id", "entity_generation", "stream_id", "sequence", "client_tick"]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	for key in ["action", "entity_id", "region_id", "target_id"]:
		var value: Variant = data.get(key)
		if not value is String and not value is StringName:
			errors.append("%s must remain an identifier on the wire" % key)
	if _schema_version != SCHEMA_VERSION:
		errors.append("unsupported landing intent schema version")
	if _peer_id <= 0:
		errors.append("peer_id must be positive")
	if not _valid_id(_entity_id):
		errors.append("entity_id must be a stable identifier")
	if not _valid_positive_integer(_entity_generation):
		errors.append("entity_generation must be positive and safe")
	for key in ["stream_id", "sequence", "client_tick"]:
		if not _valid_nonnegative_integer(int(data.get(key, -1))):
			errors.append("%s must be a non-negative safe integer" % key)
	if not ACTIONS.has(_action):
		errors.append("action must be landing or respawn")
	if not _valid_id(_region_id):
		errors.append("region_id must be a stable identifier")
	if not _valid_id(_target_id):
		errors.append("target_id must be a stable identifier")
	return errors


func _has_exact_wire_keys(data: Dictionary) -> bool:
	if data.size() != _WIRE_KEYS.size():
		return false
	for key in _WIRE_KEYS:
		if not data.has(key):
			return false
	return true


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER
