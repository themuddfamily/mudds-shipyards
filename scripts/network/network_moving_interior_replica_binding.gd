class_name NetworkMovingInteriorReplicaBinding
extends RefCounted

## Applies sampled frame-local poses to caller-owned presentation nodes only.
## No physics body, seat ledger, movement authority, or scene lookup is owned here.

const MAX_ENTITIES := 128

var _teleport_threshold := 8.0
var _bindings: Dictionary = {}
var _last_local_transforms: Dictionary = {}
var _frozen_entities: Dictionary = {}
var _teleport_count := 0


func _init(p_teleport_threshold: float = 8.0) -> void:
	_teleport_threshold = maxf(0.0, p_teleport_threshold)


func bind(
	entity_id: StringName,
	entity_generation: int,
	avatar_node: Node3D,
	frame_node: Node3D,
	frame_generation: int
) -> Dictionary:
	if entity_id.is_empty() or entity_generation <= 0 or frame_generation < 0:
		return _result(false, &"invalid_binding_identity")
	if not is_instance_valid(avatar_node) or not is_instance_valid(frame_node):
		return _result(false, &"invalid_binding_node")
	if avatar_node is PhysicsBody3D or frame_node is PhysicsBody3D:
		return _result(false, &"physics_body_rejected")
	if not _bindings.has(entity_id) and _bindings.size() >= MAX_ENTITIES:
		return _result(false, &"entity_capacity")
	_bindings[entity_id] = {
		"entity_generation": entity_generation,
		"frame_generation": frame_generation,
		"avatar_node": avatar_node,
		"frame_node": frame_node,
	}
	_frozen_entities.erase(entity_id)
	return _result(true, &"bound", {"entity_id": entity_id})


func apply_sample(
	entity_id: StringName,
	sample: Dictionary,
	entity_generation: int,
	frame_generation: int
) -> Dictionary:
	if not _bindings.has(entity_id):
		return _result(false, &"entity_not_bound")
	var binding: Dictionary = _bindings[entity_id] as Dictionary
	if int(binding.get("entity_generation", 0)) != entity_generation:
		return _result(false, &"stale_entity_generation")
	if int(binding.get("frame_generation", -1)) != frame_generation:
		return _result(false, &"stale_frame_generation")
	var avatar_variant: Variant = binding.get("avatar_node")
	var frame_variant: Variant = binding.get("frame_node")
	if not is_instance_valid(avatar_variant) or not is_instance_valid(frame_variant):
		_frozen_entities[entity_id] = true
		return _result(true, &"frame_unavailable", {"entity_id": entity_id, "frozen": true})
	var avatar := avatar_variant as Node3D
	var frame := frame_variant as Node3D
	var local_transform_variant: Variant = sample.get("transform", Transform3D.IDENTITY)
	if not local_transform_variant is Transform3D or not _finite_transform(local_transform_variant as Transform3D):
		return _result(false, &"invalid_sample_transform")
	var local_transform := local_transform_variant as Transform3D
	var prior: Transform3D = _last_local_transforms.get(entity_id, Transform3D.IDENTITY)
	var teleported := bool(sample.get("status", &"") == &"teleported")
	if _last_local_transforms.has(entity_id) and prior.origin.distance_to(local_transform.origin) > _teleport_threshold:
		teleported = true
	if teleported:
		_teleport_count += 1
	avatar.global_transform = frame.global_transform * local_transform
	_last_local_transforms[entity_id] = local_transform
	_frozen_entities.erase(entity_id)
	return _result(true, &"teleported" if teleported else StringName(sample.get("status", &"applied")), {
		"entity_id": entity_id,
		"frozen": false,
		"global_transform": avatar.global_transform,
	})


func detach(entity_id: StringName) -> Dictionary:
	_bindings.erase(entity_id)
	_last_local_transforms.erase(entity_id)
	_frozen_entities.erase(entity_id)
	return _result(true, &"detached", {"entity_id": entity_id})


func get_snapshot() -> Dictionary:
	return {
		"bound_entities": _bindings.size(),
		"frozen_entities": _frozen_entities.size(),
		"teleport_count": _teleport_count,
		"owns_physics_authority": false,
		"owns_seat_authority": false,
		"owns_movement_authority": false,
	}.duplicate(true)


func _finite_transform(transform: Transform3D) -> bool:
	for value in [
		transform.origin.x, transform.origin.y, transform.origin.z,
		transform.basis.x.x, transform.basis.x.y, transform.basis.x.z,
		transform.basis.y.x, transform.basis.y.y, transform.basis.y.z,
		transform.basis.z.x, transform.basis.z.y, transform.basis.z.z,
	]:
		if not is_finite(float(value)):
			return false
	return true


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
