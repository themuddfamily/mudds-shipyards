class_name PlanetarySaveSessionContract
extends RefCounted

## JSON-safe, caller-owned save/re-entry contract for one planetary visit.
##
## Checkpoints retain an absolute orbital coordinate and, for surface saves, a
## surface-tangent coordinate.  Local streaming positions are deliberately not
## persisted.  An orbital checkpoint can be re-entered after an origin rebase;
## a surface checkpoint must be restored at the exact coordinate-frame
## generation at which its local tangent was captured.  This contract owns no
## filesystem, scene, physics, streaming, gameplay, or clock authority.

const CoordinateFrame := preload("res://scripts/world/planetary_coordinate_frame.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")

const SCHEMA_VERSION := 1
const COORDINATE_SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_LOCAL_COMPONENT_METERS := 1_000_000_000.0
const MAX_PHYSICS_TICK := MAX_SAFE_INTEGER
const MAX_IDENTIFIER_BYTES := 128

const STATE_IDLE: StringName = &"idle"
const STATE_ACTIVE: StringName = &"active"
const STATE_DETACHED: StringName = &"detached"
const STATE_CLOSED: StringName = &"closed"
const PHASE_ORBIT: StringName = &"orbit"
const PHASE_SURFACE: StringName = &"surface"

const _STATES := [STATE_IDLE, STATE_ACTIVE, STATE_DETACHED, STATE_CLOSED]
const _PHASES := [PHASE_ORBIT, PHASE_SURFACE]
const _SNAPSHOT_KEYS := [
	"schema_version", "state", "world_id", "session_id",
	"attachment_generation", "checkpoint_generation", "physics_tick",
	"frame_generation", "checkpoint",
]
const _CHECKPOINT_KEYS := [
	"phase", "orbital_coordinate", "surface_tangent_meters",
	"frame_generation", "physics_tick", "payload",
]
const _COORDINATE_KEYS := [
	"schema_version", "frame_id", "cell_x", "cell_y", "cell_z",
	"offset_meters",
]

var _frame: PlanetaryCoordinateFrame
var _world_id: StringName = &""
var _state: StringName = STATE_IDLE
var _session_id: StringName = &""
var _attachment_generation := 0
var _checkpoint_generation := 0
var _physics_tick := 0
var _frame_generation := 0
var _checkpoint: Dictionary = {}
var _configuration_errors := PackedStringArray()


func _init(world_id: StringName = &"", frame: PlanetaryCoordinateFrame = null) -> void:
	_world_id = world_id
	if not _is_stable_id(str(world_id)):
		_configuration_errors.append("world_id must be a stable lowercase identifier")
	if frame == null or not frame.is_configured():
		_configuration_errors.append("a configured planetary coordinate frame is required")
	else:
		_frame = frame


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


## Starts a new visit at the caller's current attachment and frame generations.
func begin_session(
		session_id: StringName,
		attachment_generation: int,
		expected_frame_generation: int
		) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _state != STATE_IDLE:
		return _result(false, &"session_already_started")
	if not _is_stable_id(str(session_id)):
		return _result(false, &"session_id_invalid")
	if not _valid_generation(attachment_generation):
		return _result(false, &"attachment_generation_invalid")
	var frame_check := _check_current_frame_generation(expected_frame_generation)
	if not bool(frame_check.accepted):
		return frame_check
	_state = STATE_ACTIVE
	_session_id = session_id
	_attachment_generation = attachment_generation
	_frame_generation = expected_frame_generation
	return _result(true, &"started")


func save_orbit_checkpoint(
		expected_attachment_generation: int,
		expected_frame_generation: int,
		physics_tick: int,
		orbital_coordinate: Dictionary,
		payload: Dictionary
		) -> Dictionary:
	return _save_checkpoint(
		PHASE_ORBIT,
		expected_attachment_generation,
		expected_frame_generation,
		physics_tick,
		orbital_coordinate,
		[],
		payload
	)


func save_surface_checkpoint(
		expected_attachment_generation: int,
		expected_frame_generation: int,
		physics_tick: int,
		orbital_coordinate: Dictionary,
		surface_tangent_meters: Vector3,
		payload: Dictionary
		) -> Dictionary:
	var tangent := [
		float(surface_tangent_meters.x),
		float(surface_tangent_meters.y),
		float(surface_tangent_meters.z),
	]
	return _save_checkpoint(
		PHASE_SURFACE,
		expected_attachment_generation,
		expected_frame_generation,
		physics_tick,
		orbital_coordinate,
		tangent,
		payload
	)


func detach_session(
		expected_attachment_generation: int,
		expected_frame_generation: int
		) -> Dictionary:
	if _state != STATE_ACTIVE:
		return _result(false, &"session_not_active")
	var identity := _check_identity(
		expected_attachment_generation, expected_frame_generation
	)
	if not bool(identity.accepted):
		return identity
	_state = STATE_DETACHED
	return _result(true, &"detached")


## Installs a detached snapshot into a fresh contract. Orbit saves survive a
## frame generation change because they carry an absolute coordinate. Surface
## saves fail closed until the caller has decoded/re-saved them at the current
## frame generation.
func restore_detached_snapshot(
		candidate: Dictionary,
		expected_attachment_generation: int,
		expected_frame_generation: int
		) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _state != STATE_IDLE:
		return _result(false, &"session_already_started")
	var decoded := decode_snapshot(candidate)
	if not bool(decoded.accepted):
		return _result(false, StringName(decoded.reason))
	var snapshot := decoded.snapshot as Dictionary
	if snapshot.get("state") != str(STATE_DETACHED):
		return _result(false, &"snapshot_not_detached")
	if snapshot.get("world_id") != str(_world_id):
		return _result(false, &"world_id_mismatch")
	var frame_check := _check_current_frame_generation(expected_frame_generation)
	if not bool(frame_check.accepted):
		return frame_check
	var saved_attachment := int(snapshot.get("attachment_generation", 0))
	if not _valid_generation(expected_attachment_generation) \
		or expected_attachment_generation != saved_attachment + 1:
		return _result(false, &"stale_attachment_generation")
	var checkpoint := snapshot.get("checkpoint", {}) as Dictionary
	if not checkpoint.is_empty() \
		and checkpoint.get("phase") == str(PHASE_SURFACE) \
		and int(checkpoint.get("frame_generation", 0)) != expected_frame_generation:
		return _result(false, &"surface_checkpoint_generation_mismatch")
	_install(snapshot)
	_state = STATE_ACTIVE
	_attachment_generation = expected_attachment_generation
	_frame_generation = expected_frame_generation
	return _result(true, &"reentered", {
		"origin_generation_changed": int(snapshot.get("frame_generation", 0))
			!= expected_frame_generation,
	})


func close_session(
		expected_attachment_generation: int,
		expected_frame_generation: int
		) -> Dictionary:
	if _state != STATE_ACTIVE:
		return _result(false, &"session_not_active")
	var identity := _check_identity(
		expected_attachment_generation, expected_frame_generation
	)
	if not bool(identity.accepted):
		return identity
	_state = STATE_CLOSED
	return _result(true, &"closed")


func get_snapshot() -> Dictionary:
	return _snapshot().duplicate(true)


func audit() -> Dictionary:
	var decoded := decode_snapshot(_snapshot())
	return {
		"valid": bool(decoded.accepted) and is_configuration_valid(),
		"reason": decoded.reason if bool(decoded.accepted) else decoded.reason,
		"snapshot": get_snapshot(),
		"uses_absolute_orbital_coordinates": true,
		"surface_checkpoint_requires_exact_frame_generation": true,
		"authority": {
			"filesystem": false,
			"scene": false,
			"physics": false,
			"streaming": false,
			"gameplay": false,
			"clock": false,
			"origin_shift": false,
		},
	}.duplicate(true)


static func decode_snapshot(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _rejection(&"snapshot_not_dictionary")
	var snapshot := candidate as Dictionary
	if not _has_exact_keys(snapshot, _SNAPSHOT_KEYS):
		return _rejection(&"snapshot_fields_invalid")
	if not _valid_schema(snapshot.get("schema_version")):
		return _rejection(&"schema_invalid")
	var state_value: Variant = snapshot.get("state")
	if not state_value is String or not _STATES.has(StringName(state_value)):
		return _rejection(&"state_invalid")
	if not _valid_identifier_value(snapshot.get("world_id"), false):
		return _rejection(&"world_id_invalid")
	if not _valid_identifier_value(snapshot.get("session_id"), false):
		return _rejection(&"session_id_invalid")
	if not _valid_bounded_integer(snapshot.get("attachment_generation"), 0, MAX_SAFE_INTEGER):
		return _rejection(&"attachment_generation_invalid")
	if not _valid_bounded_integer(snapshot.get("checkpoint_generation"), 0, MAX_SAFE_INTEGER):
		return _rejection(&"checkpoint_generation_invalid")
	if not _valid_bounded_integer(snapshot.get("physics_tick"), 0, MAX_PHYSICS_TICK):
		return _rejection(&"physics_tick_invalid")
	if not _valid_bounded_integer(snapshot.get("frame_generation"), 0, MAX_SAFE_INTEGER):
		return _rejection(&"frame_generation_invalid")
	var state := StringName(state_value)
	var checkpoint: Variant = snapshot.get("checkpoint")
	if not checkpoint is Dictionary:
		return _rejection(&"checkpoint_invalid")
	var checkpoint_dict := checkpoint as Dictionary
	if state == STATE_IDLE:
		if snapshot.get("world_id") != "" or snapshot.get("session_id") != "" \
			or int(snapshot.get("attachment_generation")) != 0 \
			or int(snapshot.get("checkpoint_generation")) != 0 \
			or int(snapshot.get("physics_tick")) != 0 \
			or int(snapshot.get("frame_generation")) != 0 \
			or not checkpoint_dict.is_empty():
			return _rejection(&"idle_state_invalid")
	else:
		if not _valid_identifier_value(snapshot.get("world_id"), true) \
			or not _valid_identifier_value(snapshot.get("session_id"), true) \
			or int(snapshot.get("attachment_generation")) <= 0 \
			or int(snapshot.get("frame_generation")) <= 0:
			return _rejection(&"active_identity_invalid")
	if checkpoint_dict.is_empty():
		if int(snapshot.get("checkpoint_generation")) != 0 \
			or int(snapshot.get("physics_tick")) != 0:
			return _rejection(&"checkpoint_progress_invalid")
	else:
		var checkpoint_validation := _decode_checkpoint(checkpoint_dict)
		if not bool(checkpoint_validation.accepted):
			return _rejection(StringName(checkpoint_validation.reason))
		if int(snapshot.get("checkpoint_generation")) <= 0 \
			or int(snapshot.get("checkpoint_generation")) \
			!= int(snapshot.get("checkpoint_generation")):
			return _rejection(&"checkpoint_generation_invalid")
		if int(snapshot.get("physics_tick")) \
			!= int(checkpoint_dict.get("physics_tick", -1)):
			return _rejection(&"checkpoint_tick_mismatch")
	if state == STATE_IDLE and not checkpoint_dict.is_empty():
		return _rejection(&"idle_checkpoint_invalid")
	return {"accepted": true, "reason": &"valid", "snapshot": snapshot.duplicate(true)}


func _save_checkpoint(
		phase: StringName,
		expected_attachment_generation: int,
		expected_frame_generation: int,
		physics_tick: int,
		orbital_coordinate: Dictionary,
		surface_tangent_meters: Array,
		payload: Dictionary
		) -> Dictionary:
	if _state != STATE_ACTIVE:
		return _result(false, &"session_not_active")
	var identity := _check_identity(
		expected_attachment_generation, expected_frame_generation
	)
	if not bool(identity.accepted):
		return identity
	if not _valid_bounded_integer(physics_tick, 0, MAX_PHYSICS_TICK):
		return _result(false, &"physics_tick_invalid")
	if physics_tick < _physics_tick:
		return _result(false, &"physics_tick_regressed")
	var payload_validation := Store.validate_payload(payload)
	if not bool(payload_validation.valid):
		return _result(false, &"payload_invalid")
	var coordinate := _validate_and_encode_coordinate(orbital_coordinate)
	if not bool(coordinate.accepted):
		return coordinate
	if phase == PHASE_SURFACE:
		var tangent_validation := _validate_surface_tangent(surface_tangent_meters)
		if not bool(tangent_validation.accepted):
			return tangent_validation
		var decoded_tangent := _decode_surface_tangent(surface_tangent_meters)
		var body_local := _frame.surface_tangent_to_body_local(
			decoded_tangent, expected_frame_generation
		)
		if not bool(body_local.accepted):
			return _result(false, &"surface_coordinate_invalid")
		var expected_orbit := _frame.body_local_to_orbital_position(
			body_local.position, expected_frame_generation
		)
		if not bool(expected_orbit.accepted) \
			or _encode_orbital_coordinate(expected_orbit.coordinate) \
				!= coordinate.coordinate:
			return _result(false, &"surface_orbital_mismatch")
	var checkpoint_generation := _checkpoint_generation + 1
	if checkpoint_generation > MAX_SAFE_INTEGER:
		return _result(false, &"checkpoint_generation_exhausted")
	_checkpoint_generation = checkpoint_generation
	_physics_tick = physics_tick
	_checkpoint = {
		"phase": str(phase),
		"orbital_coordinate": (coordinate.coordinate as Dictionary).duplicate(true),
		"surface_tangent_meters": surface_tangent_meters.duplicate(true),
		"frame_generation": expected_frame_generation,
		"physics_tick": physics_tick,
		"payload": payload.duplicate(true),
	}
	return _result(true, &"checkpointed")


func _check_identity(expected_attachment_generation: int, expected_frame_generation: int) -> Dictionary:
	if expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	return _check_current_frame_generation(expected_frame_generation)


func _check_current_frame_generation(expected_frame_generation: int) -> Dictionary:
	if not _valid_generation(expected_frame_generation):
		return _result(false, &"frame_generation_invalid")
	if _frame == null or expected_frame_generation != _frame.get_generation():
		return _result(false, &"stale_frame_generation")
	return _result(true, &"generation_valid")


func _install(snapshot: Dictionary) -> void:
	_state = StringName(snapshot.get("state"))
	_session_id = StringName(snapshot.get("session_id"))
	_attachment_generation = int(snapshot.get("attachment_generation"))
	_checkpoint_generation = int(snapshot.get("checkpoint_generation"))
	_physics_tick = int(snapshot.get("physics_tick"))
	_frame_generation = int(snapshot.get("frame_generation"))
	_checkpoint = (snapshot.get("checkpoint", {}) as Dictionary).duplicate(true)


func _snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": str(_state),
		"world_id": str(_world_id) if _state != STATE_IDLE else "",
		"session_id": str(_session_id) if _state != STATE_IDLE else "",
		"attachment_generation": _attachment_generation,
		"checkpoint_generation": _checkpoint_generation,
		"physics_tick": _physics_tick,
		"frame_generation": _frame_generation,
		"checkpoint": _checkpoint.duplicate(true),
	}


func _validate_and_encode_coordinate(candidate: Dictionary) -> Dictionary:
	var decoded := _decode_orbital_coordinate(candidate)
	if not bool(decoded.accepted):
		return _result(false, StringName(decoded.reason))
	var validation := _frame.validate_orbital_coordinate(decoded.coordinate)
	if not bool(validation.accepted):
		return _result(false, &"orbital_coordinate_invalid")
	return _result(true, &"coordinate_valid", {
		"coordinate": _encode_orbital_coordinate(validation.coordinate),
	})


static func _decode_checkpoint(candidate: Dictionary) -> Dictionary:
	if not _has_exact_keys(candidate, _CHECKPOINT_KEYS):
		return _rejection(&"checkpoint_fields_invalid")
	if not candidate.phase is String or not _PHASES.has(StringName(candidate.phase)):
		return _rejection(&"checkpoint_phase_invalid")
	var coordinate := _decode_orbital_coordinate(candidate.get("orbital_coordinate"))
	if not bool(coordinate.accepted):
		return _rejection(&"checkpoint_coordinate_invalid")
	if not _valid_bounded_integer(candidate.get("frame_generation"), 1, MAX_SAFE_INTEGER):
		return _rejection(&"checkpoint_frame_generation_invalid")
	if not _valid_bounded_integer(candidate.get("physics_tick"), 0, MAX_PHYSICS_TICK):
		return _rejection(&"checkpoint_tick_invalid")
	var payload_validation := Store.validate_payload(candidate.get("payload"))
	if not bool(payload_validation.valid):
		return _rejection(&"checkpoint_payload_invalid")
	var tangent: Variant = candidate.get("surface_tangent_meters")
	if not tangent is Array:
		return _rejection(&"surface_tangent_invalid")
	if StringName(candidate.phase) == PHASE_ORBIT:
		if not (tangent as Array).is_empty():
			return _rejection(&"orbit_surface_coordinate_invalid")
	else:
		if not _valid_surface_array(tangent as Array):
			return _rejection(&"surface_tangent_invalid")
	return {"accepted": true, "reason": &"valid"}


func _validate_surface_tangent(tangent: Array) -> Dictionary:
	if not _valid_surface_array(tangent):
		return _result(false, &"surface_tangent_invalid")
	return _result(true, &"surface_tangent_valid")


static func _valid_surface_array(candidate: Array) -> bool:
	if candidate.size() != 3:
		return false
	for value in candidate:
		if not (value is float or value is int) or not is_finite(float(value)) \
			or abs(float(value)) > MAX_LOCAL_COMPONENT_METERS:
			return false
	return true


static func _decode_surface_tangent(candidate: Array) -> Vector3:
	return Vector3(float(candidate[0]), float(candidate[1]), float(candidate[2]))


static func _decode_orbital_coordinate(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _rejection(&"orbital_coordinate_not_dictionary")
	var coordinate := candidate as Dictionary
	if not _has_exact_keys(coordinate, _COORDINATE_KEYS):
		return _rejection(&"orbital_coordinate_fields_invalid")
	if not _valid_schema(coordinate.get("schema_version")):
		return _rejection(&"orbital_coordinate_schema_invalid")
	if not coordinate.frame_id is String and not coordinate.frame_id is StringName:
		return _rejection(&"orbital_coordinate_frame_invalid")
	if not _valid_bounded_integer(coordinate.get("cell_x"), -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER) \
		or not _valid_bounded_integer(coordinate.get("cell_y"), -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER) \
		or not _valid_bounded_integer(coordinate.get("cell_z"), -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER):
		return _rejection(&"orbital_coordinate_cell_invalid")
	var offset: Variant = coordinate.get("offset_meters")
	var vector: Vector3
	if offset is Vector3:
		vector = offset
	elif offset is Array and _valid_surface_array(offset as Array):
		vector = _decode_surface_tangent(offset as Array)
	else:
		return _rejection(&"orbital_coordinate_offset_invalid")
	return {
		"accepted": true,
		"reason": &"valid",
		"coordinate": {
			"schema_version": int(coordinate.schema_version),
			"frame_id": StringName(coordinate.frame_id),
			"cell_x": int(coordinate.cell_x),
			"cell_y": int(coordinate.cell_y),
			"cell_z": int(coordinate.cell_z),
			"offset_meters": vector,
		},
	}


static func _encode_orbital_coordinate(coordinate: Dictionary) -> Dictionary:
	var offset := coordinate.get("offset_meters", Vector3.ZERO) as Vector3
	return {
		"schema_version": COORDINATE_SCHEMA_VERSION,
		"frame_id": str(coordinate.get("frame_id", "")),
		"cell_x": int(coordinate.get("cell_x", 0)),
		"cell_y": int(coordinate.get("cell_y", 0)),
		"cell_z": int(coordinate.get("cell_z", 0)),
		"offset_meters": [float(offset.x), float(offset.y), float(offset.z)],
	}


static func _valid_schema(value: Variant) -> bool:
	return _valid_bounded_integer(value, SCHEMA_VERSION, SCHEMA_VERSION)


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.to_utf8_buffer().size() > MAX_IDENTIFIER_BYTES:
		return false
	for character in value:
		if not ((character >= "a" and character <= "z") \
			or (character >= "0" and character <= "9") or character == "_"):
			return false
	return true


static func _valid_identifier_value(value: Variant, required: bool) -> bool:
	return value is String and _valid_identifier(str(value), required)


static func _valid_identifier(value: String, required: bool) -> bool:
	if value.is_empty():
		return not required
	if value.to_utf8_buffer().size() > MAX_IDENTIFIER_BYTES:
		return false
	for character in value:
		if not ((character >= "a" and character <= "z") \
			or (character >= "0" and character <= "9") or character == "_"):
			return false
	return true


static func _valid_generation(value: Variant) -> bool:
	return _valid_bounded_integer(value, 1, MAX_SAFE_INTEGER)


static func _valid_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int:
		return false
	return int(value) >= minimum and int(value) <= maximum


static func _has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _result(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"snapshot": get_snapshot(),
	}
	result.merge(details, true)
	return result


static func _rejection(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
