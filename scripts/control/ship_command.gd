class_name ShipCommand
extends RefCounted

## Read-only-public, transport-safe snapshot of one ship-control simulation tick.
##
## Producers sanitize at this boundary so flight code never has to defend
## against NaN/INF input or out-of-range analogue values. Public properties have
## getters only; underscore backing fields are private by GDScript convention.
## Queue/transport boundaries must clone through the serialization API because
## GDScript does not provide enforceable per-instance private storage.

const SCHEMA_VERSION := 3
const MAX_SAFE_SERIALIZED_INTEGER := 9007199254740991

var _sequence := 0
var _timestamp_usec := 0
var _stream_id := 0
var _throttle := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _look_yaw_delta := 0.0
var _look_pitch_delta := 0.0
var _camera_distance_delta := 0.0
var _boost := false
var _brake := false
var _hover := false
var _fire := false
var _barrel_roll := false
var _engine_start := false
var _engine_stop := false
var _landing := false
var _interact := false
var _camera_toggle := false
var _deserialization_error := ""

var sequence: int:
	get:
		return _sequence
var timestamp_usec: int:
	get:
		return _timestamp_usec
var stream_id: int:
	get:
		return _stream_id
var throttle: float:
	get:
		return _throttle
var yaw: float:
	get:
		return _yaw
var pitch: float:
	get:
		return _pitch
var roll: float:
	get:
		return _roll
var look_yaw_delta: float:
	get:
		return _look_yaw_delta
var look_pitch_delta: float:
	get:
		return _look_pitch_delta
var camera_distance_delta: float:
	get:
		return _camera_distance_delta
var boost: bool:
	get:
		return _boost
var brake: bool:
	get:
		return _brake
var hover: bool:
	get:
		return _hover
var fire: bool:
	get:
		return _fire
var barrel_roll: bool:
	get:
		return _barrel_roll
var engine_start: bool:
	get:
		return _engine_start
var engine_stop: bool:
	get:
		return _engine_stop
var landing: bool:
	get:
		return _landing
var interact: bool:
	get:
		return _interact
var camera_toggle: bool:
	get:
		return _camera_toggle


func _init(
	p_sequence: int = 0,
	p_timestamp_usec: int = 0,
	p_stream_id: int = 0,
	p_throttle: float = 0.0,
	p_yaw: float = 0.0,
	p_pitch: float = 0.0,
	p_roll: float = 0.0,
	p_look_yaw_delta: float = 0.0,
	p_look_pitch_delta: float = 0.0,
	p_boost: bool = false,
	p_brake: bool = false,
	p_hover: bool = false,
	p_fire: bool = false,
	p_barrel_roll: bool = false,
	p_engine_start: bool = false,
	p_engine_stop: bool = false,
	p_landing: bool = false,
	p_interact: bool = false,
	p_camera_toggle: bool = false,
	p_camera_distance_delta: float = 0.0
	) -> void:
	_sequence = clampi(p_sequence, 0, MAX_SAFE_SERIALIZED_INTEGER)
	_timestamp_usec = clampi(p_timestamp_usec, 0, MAX_SAFE_SERIALIZED_INTEGER)
	_stream_id = clampi(p_stream_id, 0, MAX_SAFE_SERIALIZED_INTEGER)
	_throttle = _sanitize_axis(p_throttle)
	_yaw = _sanitize_axis(p_yaw)
	_pitch = _sanitize_axis(p_pitch)
	_roll = _sanitize_axis(p_roll)
	_look_yaw_delta = _sanitize_axis(p_look_yaw_delta)
	_look_pitch_delta = _sanitize_axis(p_look_pitch_delta)
	_camera_distance_delta = _sanitize_axis(p_camera_distance_delta)
	_boost = p_boost
	_brake = p_brake
	_hover = p_hover
	_fire = p_fire
	_barrel_roll = p_barrel_roll
	_engine_start = p_engine_start
	_engine_stop = p_engine_stop
	_landing = p_landing
	_interact = p_interact
	_camera_toggle = p_camera_toggle


## Creates a command with stream metadata but no held or edge-trigger actions.
static func neutral(p_sequence: int = 0, p_timestamp_usec: int = 0, p_stream_id: int = 0) -> ShipCommand:
	return ShipCommand.new(p_sequence, p_timestamp_usec, p_stream_id)


## Reconstructs an independent sanitized snapshot from primitive wire values.
## Unknown or wrongly typed fields become neutral instead of being coerced into
## surprising actions (for example, the string "false" never becomes true).
static func from_dictionary(data: Dictionary) -> ShipCommand:
	var sequence_value := _read_non_negative_int(data, &"sequence")
	var timestamp_value := _read_non_negative_int(data, &"timestamp_usec")
	var stream_value := _read_non_negative_int(data, &"stream_id")
	var schema_error := _get_schema_error(data)
	if not schema_error.is_empty():
		var rejected := ShipCommand.neutral(sequence_value, timestamp_value, stream_value)
		rejected._deserialization_error = schema_error
		return rejected
	return ShipCommand.new(
		sequence_value,
		timestamp_value,
		stream_value,
		_read_float(data, &"throttle"),
		_read_float(data, &"yaw"),
		_read_float(data, &"pitch"),
		_read_float(data, &"roll"),
		_read_float(data, &"look_yaw_delta"),
		_read_float(data, &"look_pitch_delta"),
		_read_bool(data, &"boost"),
		_read_bool(data, &"brake"),
		_read_bool(data, &"hover"),
		_read_bool(data, &"fire"),
		_read_bool(data, &"barrel_roll"),
		_read_bool(data, &"engine_start"),
		_read_bool(data, &"engine_stop"),
		_read_bool(data, &"landing"),
		_read_bool(data, &"interact"),
		_read_bool(data, &"camera_toggle"),
		_read_float(data, &"camera_distance_delta")
	)


## Returns only primitive Variant/RPC values with a stable schema marker. The
## integer range is also exactly representable by JSON's double precision.
func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"sequence": _sequence,
		"timestamp_usec": _timestamp_usec,
		"stream_id": _stream_id,
		"throttle": _throttle,
		"yaw": _yaw,
		"pitch": _pitch,
		"roll": _roll,
		"look_yaw_delta": _look_yaw_delta,
		"look_pitch_delta": _look_pitch_delta,
		"camera_distance_delta": _camera_distance_delta,
		"boost": _boost,
		"brake": _brake,
		"hover": _hover,
		"fire": _fire,
		"barrel_roll": _barrel_roll,
		"engine_start": _engine_start,
		"engine_stop": _engine_stop,
		"landing": _landing,
		"interact": _interact,
		"camera_toggle": _camera_toggle,
	}


func is_neutral() -> bool:
	return is_zero_approx(_throttle) \
		and is_zero_approx(_yaw) \
		and is_zero_approx(_pitch) \
		and is_zero_approx(_roll) \
		and is_zero_approx(_look_yaw_delta) \
		and is_zero_approx(_look_pitch_delta) \
		and is_zero_approx(_camera_distance_delta) \
		and not _boost \
		and not _brake \
		and not _hover \
		and not _fire \
		and not _barrel_roll \
		and not _engine_start \
		and not _engine_stop \
		and not _landing \
		and not _interact \
		and not _camera_toggle


## Lifecycle consumers run independently from the ship's physics consumer. Only
## these ordered one-shot fields need the source's lossless delivery side-channel;
## held axes, fire, camera, and presentation state are consumed by HeroShip from
## the direct per-tick return value.
func has_lifecycle_edge() -> bool:
	return _engine_start or _engine_stop or _landing or _interact


## GDScript's underscore storage is private only by convention. Every queue and
## listener boundary therefore receives a serialized clone, never this instance.
func detached_copy() -> ShipCommand:
	return ShipCommand.from_dictionary(to_dictionary())


## Commands are ordered lexicographically by epoch then sequence. Gaps are legal;
## rollback or reuse is not. A negative cursor represents an empty history.
func is_strictly_newer_than(previous_stream_id: int, previous_sequence: int) -> bool:
	return (
		_stream_id > previous_stream_id
		or (_stream_id == previous_stream_id and _sequence > previous_sequence)
	)


## Useful at trust boundaries even though all built-in constructors sanitize.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _deserialization_error.is_empty():
		errors.append(_deserialization_error)
	if _sequence < 0 or _sequence > MAX_SAFE_SERIALIZED_INTEGER:
		errors.append("sequence must be inside the lossless serialized integer range")
	if _timestamp_usec < 0 or _timestamp_usec > MAX_SAFE_SERIALIZED_INTEGER:
		errors.append("timestamp_usec must be inside the lossless serialized integer range")
	if _stream_id < 0 or _stream_id > MAX_SAFE_SERIALIZED_INTEGER:
		errors.append("stream_id must be inside the lossless serialized integer range")
	for axis_name: StringName in [
		&"throttle",
		&"yaw",
		&"pitch",
		&"roll",
		&"look_yaw_delta",
		&"look_pitch_delta",
		&"camera_distance_delta",
	]:
		var value := float(get(axis_name))
		if not is_finite(value) or value < -1.0 or value > 1.0:
			errors.append("%s must be finite and between -1 and 1" % axis_name)
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


static func _sanitize_axis(value: float) -> float:
	return clampf(value, -1.0, 1.0) if is_finite(value) else 0.0


static func _read_float(data: Dictionary, key: StringName) -> float:
	var value: Variant = data.get(key, 0.0)
	if value is float or value is int:
		return float(value)
	return 0.0


static func _read_non_negative_int(data: Dictionary, key: StringName) -> int:
	var value: Variant = data.get(key, 0)
	if value is int:
		return clampi(int(value), 0, MAX_SAFE_SERIALIZED_INTEGER)
	# JSON.parse_string() represents every number as a float. Accept only exact,
	# finite integer values inside the lossless JSON range; never round input.
	if value is float:
		var number := float(value)
		if (
			is_finite(number)
			and number >= 0.0
			and number <= float(MAX_SAFE_SERIALIZED_INTEGER)
			and floor(number) == number
		):
			return int(number)
	return 0


static func _read_bool(data: Dictionary, key: StringName) -> bool:
	var value: Variant = data.get(key, false)
	return bool(value) if value is bool else false


static func _get_schema_error(data: Dictionary) -> String:
	if not data.has(&"schema_version"):
		return "schema_version is required"
	var schema_value: Variant = data.get(&"schema_version")
	var parsed_schema := _read_non_negative_int(data, &"schema_version")
	if not (schema_value is int or schema_value is float):
		return "schema_version must be an integer"
	if parsed_schema != SCHEMA_VERSION:
		return "unsupported schema_version %s" % str(schema_value)
	for required_key: StringName in [&"sequence", &"timestamp_usec", &"stream_id"]:
		if not data.has(required_key):
			return "%s is required" % required_key
	return ""
