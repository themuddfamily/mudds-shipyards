class_name NetworkMovementIntent
extends RefCounted

## Transport-safe on-foot movement and boarding intent.
##
## This packet is client input, not movement truth.  The server validates it
## through NetworkMovementAuthority and only then exposes one intent to the
## authoritative Player/boarding components.  Keeping the boarding target in
## the packet makes the request explicit without letting a client claim a seat
## or teleport across a collision boundary.
##
## Schema 2 is the whole of what a server-owned remote body needs to be driven
## by its owner: the move axes, the look yaw and pitch the axes are relative
## to, the run / crouch / jump flags and a monotonic interaction request id.
## Every field is bounded on the wire (unit axes, wrapped yaw, clamped pitch,
## safe integers) so the server never has to trust a value before it reads it.
## A schema 1 packet is still admitted with these fields at their neutral
## defaults, so the remote ship command source and the three-process authority
## harness keep the wire they already speak; there is one intent contract, one
## authority ledger and one RPC path for both.

const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const AXIS_EPSILON := 0.000001
const MAX_LOOK_PITCH := PI * 0.5

const _WIRE_KEYS_V1 := [
	"schema_version", "peer_id", "entity_id", "entity_generation",
	"stream_id", "sequence", "client_tick", "move_axis", "board_request",
	"boarding_target_id", "disembark_request",
]
const _WIRE_KEYS_V2 := [
	"schema_version", "peer_id", "entity_id", "entity_generation",
	"stream_id", "sequence", "client_tick", "move_axis", "board_request",
	"boarding_target_id", "disembark_request", "look_yaw", "look_pitch",
	"run", "crouch", "jump", "interaction_request_id",
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
var _look_yaw := 0.0
var _look_pitch := 0.0
var _run := false
var _crouch := false
var _jump := false
var _interaction_request_id := 0
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
	p_disembark_request := false,
	p_look_yaw := 0.0,
	p_look_pitch := 0.0,
	p_run := false,
	p_crouch := false,
	p_jump := false,
	p_interaction_request_id := 0
):
	return new({
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
		"look_yaw": wrapf(p_look_yaw, -PI, PI),
		"look_pitch": clampf(p_look_pitch, -MAX_LOOK_PITCH, MAX_LOOK_PITCH),
		"run": p_run,
		"crouch": p_crouch,
		"jump": p_jump,
		"interaction_request_id": p_interaction_request_id,
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
	_move_axis = _decode_axis(data.get("move_axis", []))
	_board_request = data.get("board_request", false) if data.get("board_request", false) is bool else false
	_boarding_target_id = StringName(data.get("boarding_target_id", &""))
	_disembark_request = data.get("disembark_request", false) if data.get("disembark_request", false) is bool else false
	_look_yaw = _decode_angle(data.get("look_yaw", 0.0))
	_look_pitch = _decode_angle(data.get("look_pitch", 0.0))
	_run = data.get("run", false) if data.get("run", false) is bool else false
	_crouch = data.get("crouch", false) if data.get("crouch", false) is bool else false
	_jump = data.get("jump", false) if data.get("jump", false) is bool else false
	_interaction_request_id = int(data.get("interaction_request_id", 0)) \
		if data.get("interaction_request_id", 0) is int else -1
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


func get_look_yaw() -> float:
	return _look_yaw


func get_look_pitch() -> float:
	return _look_pitch


func is_running() -> bool:
	return _run


func is_crouching() -> bool:
	return _crouch


func has_jump_request() -> bool:
	return _jump


## Monotonic per stream. The server acts on a request id exactly once, the
## first time it sees a value above the last one it handled, so a held key or a
## re-sent packet cannot sit a body down twice.
func get_interaction_request_id() -> int:
	return _interaction_request_id


func is_neutral_movement() -> bool:
	return _move_axis.length_squared() <= AXIS_EPSILON


func to_dictionary() -> Dictionary:
	var wire := {
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
	}
	if _schema_version != LEGACY_SCHEMA_VERSION:
		wire["look_yaw"] = _look_yaw
		wire["look_pitch"] = _look_pitch
		wire["run"] = _run
		wire["crouch"] = _crouch
		wire["jump"] = _jump
		wire["interaction_request_id"] = _interaction_request_id
	return wire.duplicate(true)


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
	if _schema_version != SCHEMA_VERSION and _schema_version != LEGACY_SCHEMA_VERSION:
		errors.append("unsupported movement intent schema version")
	if _schema_version == SCHEMA_VERSION:
		for key in ["run", "crouch", "jump"]:
			if not data.get(key) is bool:
				errors.append("%s must remain a boolean on the wire" % key)
		for key in ["look_yaw", "look_pitch"]:
			var angle: Variant = data.get(key)
			if not (angle is float or angle is int) or not is_finite(float(angle)):
				errors.append("%s must remain a finite angle on the wire" % key)
		if not data.get("interaction_request_id") is int:
			errors.append("interaction_request_id must remain an integer on the wire")
		if abs(_look_yaw) > PI + AXIS_EPSILON:
			errors.append("look_yaw must be wrapped to [-PI, PI]")
		if abs(_look_pitch) > MAX_LOOK_PITCH + AXIS_EPSILON:
			errors.append("look_pitch must stay within a half turn")
		if _interaction_request_id < 0 or _interaction_request_id > MAX_SAFE_INTEGER:
			errors.append("interaction_request_id must be a non-negative safe integer")
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
	var keys: Array = _WIRE_KEYS_V1 if _schema_version == LEGACY_SCHEMA_VERSION else _WIRE_KEYS_V2
	if data.size() != keys.size():
		return false
	for key in keys:
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


func _decode_angle(value: Variant) -> float:
	if not (value is float or value is int):
		return 0.0
	var angle := float(value)
	return angle if is_finite(angle) else 0.0
