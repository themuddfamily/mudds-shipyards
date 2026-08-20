class_name NetworkMovingInteriorRelationship
extends RefCounted

## Transport-safe relationship between an entity and a moving interior frame.
##
## The authoritative simulation publishes frame-local pose and generation
## handles. A replica may resolve that pose against its current frame transform,
## but this value never becomes an authority setter. Keeping the relationship in
## the frame's coordinates means interpolation and packet loss do not turn a
## ship's motion into an occupant teleport.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const TRANSFORM_COMPONENT_COUNT := 12
const VECTOR_COMPONENT_COUNT := 3

const _KEYS := [
	"schema_version", "server_tick", "entity_id", "entity_generation",
	"parent_frame_id", "parent_frame_generation", "frame_local_transform",
	"linear_velocity", "angular_velocity", "event_sequence",
]

var _snapshot: Dictionary = {}
var _errors := PackedStringArray()


func _init(data: Dictionary = {}) -> void:
	_snapshot = _canonical_snapshot(data)
	_errors = _validate(_snapshot, data)


static func create(
	p_server_tick: int,
	p_entity_id: StringName,
	p_entity_generation: int,
	p_parent_frame_id: StringName,
	p_parent_frame_generation: int,
	p_frame_local_transform: Transform3D,
	p_linear_velocity := Vector3.ZERO,
	p_angular_velocity := Vector3.ZERO,
	p_event_sequence: int = 0
	) -> NetworkMovingInteriorRelationship:
	return NetworkMovingInteriorRelationship.new({
		"schema_version": SCHEMA_VERSION,
		"server_tick": p_server_tick,
		"entity_id": p_entity_id,
		"entity_generation": p_entity_generation,
		"parent_frame_id": p_parent_frame_id,
		"parent_frame_generation": p_parent_frame_generation,
		"frame_local_transform": _encode_transform(p_frame_local_transform),
		"linear_velocity": _encode_vector(p_linear_velocity),
		"angular_velocity": _encode_vector(p_angular_velocity),
		"event_sequence": p_event_sequence,
	})


static func from_dictionary(data: Dictionary) -> NetworkMovingInteriorRelationship:
	return NetworkMovingInteriorRelationship.new(data.duplicate(true))


func is_valid() -> bool:
	return _errors.is_empty()


func get_validation_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_server_tick() -> int:
	return int(_snapshot.get("server_tick", 0))


func get_entity_id() -> StringName:
	return StringName(_snapshot.get("entity_id", &""))


func get_entity_generation() -> int:
	return int(_snapshot.get("entity_generation", 0))


func get_parent_frame_id() -> StringName:
	return StringName(_snapshot.get("parent_frame_id", &""))


func get_parent_frame_generation() -> int:
	return int(_snapshot.get("parent_frame_generation", 0))


func get_event_sequence() -> int:
	return int(_snapshot.get("event_sequence", 0))


func get_frame_local_transform() -> Transform3D:
	return _decode_transform(_snapshot.get("frame_local_transform", []))


func get_linear_velocity() -> Vector3:
	return _decode_vector(_snapshot.get("linear_velocity", []))


func get_angular_velocity() -> Vector3:
	return _decode_vector(_snapshot.get("angular_velocity", []))


## Resolves presentation-only world placement from a caller-owned frame pose.
## No node is looked up and no simulation state is mutated here.
func resolve_world_transform(frame_world_transform: Transform3D) -> Transform3D:
	return frame_world_transform * get_frame_local_transform()


func audit() -> Dictionary:
	return {
		"valid": is_valid(),
		"errors": get_validation_errors(),
		"snapshot": get_snapshot(),
		"frame_local_authority": true,
		"replica_transform_setter": false,
		"owns_movement": false,
		"owns_boarding": false,
		"owns_seat_reservation": false,
		"owns_damage_or_landing": false,
	}.duplicate(true)


static func _canonical_snapshot(data: Dictionary) -> Dictionary:
	return {
		"schema_version": int(data.get("schema_version", 0)),
		"server_tick": int(data.get("server_tick", 0)),
		"entity_id": StringName(data.get("entity_id", &"")),
		"entity_generation": int(data.get("entity_generation", 0)),
		"parent_frame_id": StringName(data.get("parent_frame_id", &"")),
		"parent_frame_generation": int(data.get("parent_frame_generation", 0)),
		"frame_local_transform": _copy_array(data.get("frame_local_transform", [])),
		"linear_velocity": _copy_array(data.get("linear_velocity", [])),
		"angular_velocity": _copy_array(data.get("angular_velocity", [])),
		"event_sequence": int(data.get("event_sequence", 0)),
	}


static func _validate(snapshot: Dictionary, source: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _has_exact_keys(source):
		errors.append("snapshot fields must match the relationship wire schema")
	for integer_key in [&"schema_version", &"server_tick", &"entity_generation", &"parent_frame_generation", &"event_sequence"]:
		if not source.get(integer_key) is int:
			errors.append("%s must remain an integer on the wire" % integer_key)
	for id_key in [&"entity_id", &"parent_frame_id"]:
		var raw_id: Variant = source.get(id_key)
		if not raw_id is String and not raw_id is StringName:
			errors.append("%s must remain a string identifier on the wire" % id_key)
	if int(snapshot.schema_version) != SCHEMA_VERSION:
		errors.append("unsupported relationship schema version")
	if not _valid_integer(snapshot.server_tick, false):
		errors.append("server_tick must be a non-negative safe integer")
	if not _valid_id(snapshot.entity_id):
		errors.append("entity_id must be a stable identifier")
	if not _valid_integer(snapshot.entity_generation, false) or int(snapshot.entity_generation) == 0:
		errors.append("entity_generation must be a positive safe integer")
	if snapshot.parent_frame_id != &"":
		if not _valid_id(snapshot.parent_frame_id):
			errors.append("parent_frame_id must be a stable identifier when present")
		if not _valid_integer(snapshot.parent_frame_generation, false) or int(snapshot.parent_frame_generation) == 0:
			errors.append("parent_frame_generation must be positive when a frame is present")
	elif int(snapshot.parent_frame_generation) != 0:
		errors.append("root relationships must use parent_frame_generation zero")
	if not _valid_transform_array(snapshot.frame_local_transform):
		errors.append("frame_local_transform must contain twelve finite components")
	if not _valid_vector_array(snapshot.linear_velocity):
		errors.append("linear_velocity must contain three finite components")
	if not _valid_vector_array(snapshot.angular_velocity):
		errors.append("angular_velocity must contain three finite components")
	if not _valid_integer(snapshot.event_sequence, false):
		errors.append("event_sequence must be a non-negative safe integer")
	return errors


static func _has_exact_keys(data: Dictionary) -> bool:
	if data.size() != _KEYS.size():
		return false
	for key in _KEYS:
		if not data.has(key):
			return false
	return true


static func _valid_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var ascii_alphanumeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (ascii_alphanumeric or codepoint == 95 or codepoint == 45):
			return false
	return true


static func _valid_integer(value: Variant, positive: bool) -> bool:
	if not value is int:
		return false
	var number := int(value)
	return (number > 0 if positive else number >= 0) and number <= MAX_SAFE_INTEGER


static func _valid_transform_array(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != TRANSFORM_COMPONENT_COUNT:
		return false
	for component in value as Array:
		if not component is int and not component is float:
			return false
		if not is_finite(float(component)):
			return false
	return true


static func _valid_vector_array(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != VECTOR_COMPONENT_COUNT:
		return false
	for component in value as Array:
		if not component is int and not component is float:
			return false
		if not is_finite(float(component)):
			return false
	return true


static func _copy_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return []


static func _encode_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _decode_vector(value: Variant) -> Vector3:
	if not _valid_vector_array(value):
		return Vector3.ZERO
	var vector := value as Array
	return Vector3(float(vector[0]), float(vector[1]), float(vector[2]))


static func _encode_transform(value: Transform3D) -> Array:
	return [
		value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z,
	]


static func _decode_transform(value: Variant) -> Transform3D:
	if not _valid_transform_array(value):
		return Transform3D.IDENTITY
	var transform := value as Array
	return Transform3D(
		Basis(
			Vector3(float(transform[0]), float(transform[1]), float(transform[2])),
			Vector3(float(transform[3]), float(transform[4]), float(transform[5])),
			Vector3(float(transform[6]), float(transform[7]), float(transform[8]))
		),
		Vector3(float(transform[9]), float(transform[10]), float(transform[11]))
	)
