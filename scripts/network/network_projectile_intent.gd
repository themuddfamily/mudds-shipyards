class_name NetworkProjectileIntent
extends RefCounted

## Transport-safe request to fire one projectile.
##
## The packet deliberately carries no damage, speed, lifetime, faction, or
## target fields.  Those values are selected from the server-owned weapon
## profile after the request has passed NetworkProjectileAuthority.  A client
## can request a shot, but it cannot turn a cosmetic packet into damage.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const VECTOR_COMPONENT_COUNT := 3
const DIRECTION_EPSILON := 0.000001

const _WIRE_KEYS := [
	"schema_version", "peer_id", "source_entity_id", "source_generation",
	"stream_id", "sequence", "client_tick", "weapon_id", "origin",
	"direction", "fire_edge",
]

var _schema_version := 0
var _peer_id := 0
var _source_entity_id: StringName = &""
var _source_generation := 0
var _stream_id := 0
var _sequence := 0
var _client_tick := 0
var _weapon_id: StringName = &""
var _origin := Vector3.ZERO
var _direction := Vector3.ZERO
var _fire_edge := false
var _errors := PackedStringArray()


static func create(
	p_peer_id: int,
	p_source_entity_id: StringName,
	p_source_generation: int,
	p_stream_id: int,
	p_sequence: int,
	p_client_tick: int,
	p_weapon_id: StringName,
	p_origin: Vector3,
	p_direction: Vector3,
	p_fire_edge := true
) :
	return new({
		"schema_version": SCHEMA_VERSION,
		"peer_id": p_peer_id,
		"source_entity_id": p_source_entity_id,
		"source_generation": p_source_generation,
		"stream_id": p_stream_id,
		"sequence": p_sequence,
		"client_tick": p_client_tick,
		"weapon_id": p_weapon_id,
		"origin": _encode_vector(p_origin),
		"direction": _encode_vector(p_direction),
		"fire_edge": p_fire_edge,
	})


static func from_dictionary(data: Dictionary):
	return new(data.duplicate(true))


func _init(data: Dictionary = {}) -> void:
	_schema_version = int(data.get("schema_version", 0))
	_peer_id = int(data.get("peer_id", 0))
	_source_entity_id = StringName(data.get("source_entity_id", &""))
	_source_generation = int(data.get("source_generation", 0))
	_stream_id = int(data.get("stream_id", 0))
	_sequence = int(data.get("sequence", 0))
	_client_tick = int(data.get("client_tick", 0))
	_weapon_id = StringName(data.get("weapon_id", &""))
	_origin = _decode_vector(data.get("origin", []))
	_direction = _decode_vector(data.get("direction", []))
	_fire_edge = data.get("fire_edge", false) if data.get("fire_edge", false) is bool else false
	_errors = _validate(data)


func is_valid() -> bool:
	return _errors.is_empty()


func get_validation_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_peer_id() -> int:
	return _peer_id


func get_source_entity_id() -> StringName:
	return _source_entity_id


func get_source_generation() -> int:
	return _source_generation


func get_stream_id() -> int:
	return _stream_id


func get_sequence() -> int:
	return _sequence


func get_client_tick() -> int:
	return _client_tick


func get_weapon_id() -> StringName:
	return _weapon_id


func get_origin() -> Vector3:
	return _origin


func get_direction() -> Vector3:
	return _direction


func get_normalized_direction() -> Vector3:
	if _direction.length_squared() <= DIRECTION_EPSILON:
		return Vector3.ZERO
	return _direction.normalized()


func to_dictionary() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"peer_id": _peer_id,
		"source_entity_id": _source_entity_id,
		"source_generation": _source_generation,
		"stream_id": _stream_id,
		"sequence": _sequence,
		"client_tick": _client_tick,
		"weapon_id": _weapon_id,
		"origin": _encode_vector(_origin),
		"direction": _encode_vector(_direction),
		"fire_edge": _fire_edge,
	}.duplicate(true)


func detached_copy():
	return from_dictionary(to_dictionary())


func _validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_wire_keys(data):
		errors.append("projectile intent fields must match the wire schema")
	for key in ["schema_version", "peer_id", "source_generation", "stream_id", "sequence", "client_tick"]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	if not data.get("fire_edge") is bool:
		errors.append("fire_edge must remain a boolean on the wire")
	for key in ["source_entity_id", "weapon_id"]:
		var value: Variant = data.get(key)
		if not value is String and not value is StringName:
			errors.append("%s must remain an identifier on the wire" % key)
	if _schema_version != SCHEMA_VERSION:
		errors.append("unsupported projectile intent schema version")
	if _peer_id <= 0:
		errors.append("peer_id must be positive")
	if not _valid_id(_source_entity_id):
		errors.append("source_entity_id must be a stable identifier")
	if not _valid_positive_integer(_source_generation):
		errors.append("source_generation must be positive and safe")
	for key in ["stream_id", "sequence", "client_tick"]:
		if not _valid_nonnegative_integer(int(data.get(key, -1))):
			errors.append("%s must be a non-negative safe integer" % key)
	if not _valid_id(_weapon_id):
		errors.append("weapon_id must be a stable identifier")
	if not _valid_vector(data.get("origin", [])):
		errors.append("origin must contain three finite components")
	if not _valid_vector(data.get("direction", [])):
		errors.append("direction must contain three finite components")
	elif _direction.length_squared() <= DIRECTION_EPSILON:
		errors.append("direction must be finite and non-zero")
	if not _fire_edge:
		errors.append("projectile intent must represent a fire edge")
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


static func _valid_vector(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != VECTOR_COMPONENT_COUNT:
		return false
	for component in value as Array:
		if not component is int and not component is float:
			return false
		if not is_finite(float(component)):
			return false
	return true


static func _encode_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _decode_vector(value: Variant) -> Vector3:
	if not _valid_vector(value):
		return Vector3.ZERO
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
