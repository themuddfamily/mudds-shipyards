class_name NetworkMovementIntent
extends RefCounted

## Transport-safe on-foot movement and boarding intent.
##
## This packet is client input, not movement truth.  The server validates it
## through NetworkMovementAuthority and only then exposes one intent to the
## authoritative Player/boarding components.  Keeping the boarding target in
## the packet makes the request explicit without letting a client claim a seat
## or teleport across a collision boundary.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const AXIS_EPSILON := 0.000001

const _WIRE_KEYS := [
	"schema_version", "peer_id", "entity_id", "entity_generation",
	"stream_id", "sequence", "client_tick", "move_axis", "board_request",
	"boarding_target_id", "disembark_request",
]

var _schema_version := 0
var _peer_id := 0
var _entity_id: StringName = &""
var _entity_generation := 0
var _stream_id := 0
var _sequence := 0
var _client_tick := 0
var _move_axis := Vector2.ZERO
var _board_request := false
var _boarding_target_id: StringName = &""
var _disembark_request := false
var _errors := PackedStringArray()


static func create(
	p_peer_id: int,
	p_entity_id: StringName,
	p_entity_generation: int,
	p_stream_id: int,
	p_sequence: int,
	p_client_tick: int,
	p_move_axis := Vector2.ZERO,
	p_board_request := false,
	p_boarding_target_id: StringName = &"",
	p_disembark_request := false
):
	return NetworkMovementIntent.new({
		"schema_version": SCHEMA_VERSION,
		"peer_id": p_peer_id,
		"entity_id": p_entity_id,
		"entity_generation": p_entity_generation,
		"stream_id": p_stream_id,
		"sequence": p_sequence,
		"client_tick": p_client_tick,
		"move_axis": [p_move_axis.x, p_move_axis.y],
		"board_request": p_board_request,
		"boarding_target_id": p_boarding_target_id,
		"disembark_request": p_disembark_request,
	})


static func from_dictionary(data: Dictionary):
	return NetworkMovementIntent.new(data.duplicate(true))


func _init(data: Dictionary = {}) -> void:
	_schema_version = int(data.get("schema_version", 0))
	_peer_id = int(data.get("peer_id", 0))
	_entity_id = StringName(data.get("entity_id", &""))
	_entity_generation = int(data.get("entity_generation", 0))
	_stream_id = int(data.get("stream_id", 0))
	_sequence = int(data.get("sequence", 0))
	_client_tick = int(data.get("client_tick", 0))
	_move_axis = _decode_axis(data.get("move_axis", []))
	_board_request = data.get("board_request", false) if data.get("board_request", false) is bool else false
	_boarding_target_id = StringName(data.get("boarding_target_id", &""))
	_disembark_request = data.get("disembark_request", false) if data.get("disembark_request", false) is bool else false
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


func get_move_axis() -> Vector2:
	return _move_axis


func has_board_request() -> bool:
	return _board_request


func get_boarding_target_id() -> StringName:
	return _boarding_target_id


func has_disembark_request() -> bool:
	return _disembark_request


func is_neutral_movement() -> bool:
	return _move_axis.length_squared() <= AXIS_EPSILON


func to_dictionary() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"peer_id": _peer_id,
		"entity_id": _entity_id,
		"entity_generation": _entity_generation,
		"stream_id": _stream_id,
		"sequence": _sequence,
		"client_tick": _client_tick,
		"move_axis": [_move_axis.x, _move_axis.y],
		"board_request": _board_request,
		"boarding_target_id": _boarding_target_id,
		"disembark_request": _disembark_request,
	}.duplicate(true)


func detached_copy():
	return NetworkMovementIntent.from_dictionary(to_dictionary())


func _validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_wire_keys(data):
		errors.append("movement intent fields must match the wire schema")
	for key in ["schema_version", "peer_id", "entity_generation", "stream_id", "sequence", "client_tick"]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	for key in ["board_request", "disembark_request"]:
		if not data.get(key) is bool:
			errors.append("%s must remain a boolean on the wire" % key)
	for key in ["entity_id", "boarding_target_id"]:
		var value: Variant = data.get(key)
		if not value is String and not value is StringName:
			errors.append("%s must remain an identifier on the wire" % key)
	if _schema_version != SCHEMA_VERSION:
		errors.append("unsupported movement intent schema version")
	if _peer_id <= 0:
		errors.append("peer_id must be positive")
	if not _valid_id(_entity_id):
		errors.append("entity_id must be a stable identifier")
	if _entity_generation <= 0 or _entity_generation > MAX_SAFE_INTEGER:
		errors.append("entity_generation must be positive and safe")
	if _stream_id < 0 or _stream_id > MAX_SAFE_INTEGER:
		errors.append("stream_id must be a non-negative safe integer")
	if _sequence < 0 or _sequence > MAX_SAFE_INTEGER:
		errors.append("sequence must be a non-negative safe integer")
	if _client_tick < 0 or _client_tick > MAX_SAFE_INTEGER:
		errors.append("client_tick must be a non-negative safe integer")
	if not _valid_axis(data.get("move_axis", [])):
		errors.append("move_axis must contain two finite values in the unit range")
	if _board_request and not _valid_id(_boarding_target_id):
		errors.append("boarding_target_id is required for a board request")
	if not _board_request and _boarding_target_id != &"":
		errors.append("boarding_target_id must be empty without a board request")
	if _board_request and _disembark_request:
		errors.append("board and disembark cannot be requested together")
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


func _valid_axis(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 2:
		return false
	for component in value as Array:
		if not component is int and not component is float:
			return false
		var number := float(component)
		if not is_finite(number) or abs(number) > 1.0 + AXIS_EPSILON:
			return false
	return true


func _decode_axis(value: Variant) -> Vector2:
	if not _valid_axis(value):
		return Vector2.ZERO
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))
