class_name NetworkBoardingIntent
extends RefCounted

## Transport-safe request for one authoritative boarding or disembark action.
##
## The packet carries identity and lifecycle generations only. It deliberately
## carries no transform, occupancy count, role grant, or ship ownership state;
## those values remain server-owned and are returned by the authority after the
## request is accepted.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64

const ACTION_BOARD: StringName = &"board"
const ACTION_DISEMBARK: StringName = &"disembark"
const ACTIONS := [ACTION_BOARD, ACTION_DISEMBARK]

const ROLE_PILOT: StringName = &"pilot"
const ROLE_GUNNER: StringName = &"gunner"
const ROLE_PASSENGER: StringName = &"passenger"
const ROLE_ENGINEER: StringName = &"engineer"
const ROLES := [ROLE_PILOT, ROLE_GUNNER, ROLE_PASSENGER, ROLE_ENGINEER]

const _WIRE_KEYS := [
	"schema_version", "peer_id", "avatar_id", "ship_id", "ship_generation",
	"frame_id", "frame_generation", "seat_id", "seat_generation", "role",
	"sequence", "client_tick", "action",
]

var _schema_version := 0
var _peer_id := 0
var _avatar_id: StringName = &""
var _ship_id: StringName = &""
var _ship_generation := 0
var _frame_id: StringName = &""
var _frame_generation := 0
var _seat_id: StringName = &""
var _seat_generation := 0
var _role: StringName = &""
var _sequence := 0
var _client_tick := 0
var _action: StringName = &""
var _errors := PackedStringArray()


static func create(
	p_peer_id: int,
	p_avatar_id: StringName,
	p_ship_id: StringName,
	p_ship_generation: int,
	p_frame_id: StringName,
	p_frame_generation: int,
	p_seat_id: StringName,
	p_seat_generation: int,
	p_role: StringName,
	p_sequence: int,
	p_client_tick: int,
	p_action: StringName
):
	return new({
		"schema_version": SCHEMA_VERSION,
		"peer_id": p_peer_id,
		"avatar_id": p_avatar_id,
		"ship_id": p_ship_id,
		"ship_generation": p_ship_generation,
		"frame_id": p_frame_id,
		"frame_generation": p_frame_generation,
		"seat_id": p_seat_id,
		"seat_generation": p_seat_generation,
		"role": p_role,
		"sequence": p_sequence,
		"client_tick": p_client_tick,
		"action": p_action,
	})


static func from_dictionary(data: Dictionary):
	return new(data.duplicate(true))


func _init(data: Dictionary = {}) -> void:
	_schema_version = int(data.get("schema_version", 0))
	_peer_id = int(data.get("peer_id", 0))
	_avatar_id = StringName(data.get("avatar_id", &""))
	_ship_id = StringName(data.get("ship_id", &""))
	_ship_generation = int(data.get("ship_generation", 0))
	_frame_id = StringName(data.get("frame_id", &""))
	_frame_generation = int(data.get("frame_generation", 0))
	_seat_id = StringName(data.get("seat_id", &""))
	_seat_generation = int(data.get("seat_generation", 0))
	_role = StringName(data.get("role", &""))
	_sequence = int(data.get("sequence", 0))
	_client_tick = int(data.get("client_tick", 0))
	_action = StringName(data.get("action", &""))
	_errors = _validate(data)


func is_valid() -> bool:
	return _errors.is_empty()


func get_validation_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_peer_id() -> int:
	return _peer_id


func get_avatar_id() -> StringName:
	return _avatar_id


func get_ship_id() -> StringName:
	return _ship_id


func get_ship_generation() -> int:
	return _ship_generation


func get_frame_id() -> StringName:
	return _frame_id


func get_frame_generation() -> int:
	return _frame_generation


func get_seat_id() -> StringName:
	return _seat_id


func get_seat_generation() -> int:
	return _seat_generation


func get_role() -> StringName:
	return _role


func get_sequence() -> int:
	return _sequence


func get_client_tick() -> int:
	return _client_tick


func get_action() -> StringName:
	return _action


func to_dictionary() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"peer_id": _peer_id,
		"avatar_id": _avatar_id,
		"ship_id": _ship_id,
		"ship_generation": _ship_generation,
		"frame_id": _frame_id,
		"frame_generation": _frame_generation,
		"seat_id": _seat_id,
		"seat_generation": _seat_generation,
		"role": _role,
		"sequence": _sequence,
		"client_tick": _client_tick,
		"action": _action,
	}.duplicate(true)


func detached_copy():
	return from_dictionary(to_dictionary())


func _validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_wire_keys(data):
		errors.append("boarding intent fields must match the wire schema")
	for key in [
		"schema_version", "peer_id", "ship_generation", "frame_generation",
		"seat_generation", "sequence", "client_tick",
	]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	for key in ["avatar_id", "ship_id", "frame_id", "seat_id", "role", "action"]:
		var value: Variant = data.get(key)
		if not value is String and not value is StringName:
			errors.append("%s must remain an identifier on the wire" % key)
	if _schema_version != SCHEMA_VERSION:
		errors.append("unsupported boarding intent schema version")
	if _peer_id <= 0:
		errors.append("peer_id must be positive")
	if not _valid_id(_avatar_id):
		errors.append("avatar_id must be a stable identifier")
	if not _valid_id(_ship_id):
		errors.append("ship_id must be a stable identifier")
	if not _valid_positive_integer(_ship_generation):
		errors.append("ship_generation must be positive and safe")
	if not _valid_id(_frame_id):
		errors.append("frame_id must be a stable identifier")
	if not _valid_positive_integer(_frame_generation):
		errors.append("frame_generation must be positive and safe")
	if not _valid_id(_seat_id):
		errors.append("seat_id must be a stable identifier")
	if not _valid_positive_integer(_seat_generation):
		errors.append("seat_generation must be positive and safe")
	if not ROLES.has(_role):
		errors.append("role must be a supported crew role")
	if not ACTIONS.has(_action):
		errors.append("action must be board or disembark")
	for key in ["sequence", "client_tick"]:
		if not _valid_nonnegative_integer(int(data.get(key, -1))):
			errors.append("%s must be a non-negative safe integer" % key)
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
