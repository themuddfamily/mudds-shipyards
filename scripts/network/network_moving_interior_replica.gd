class_name NetworkMovingInteriorReplica
extends RefCounted

## Presentation-only moving-interior sampler. Authority and ordering remain in
## NetworkMovingInteriorRelationshipStream; this class owns no scene or physics state.

const RelationshipStream := preload("res://scripts/network/moving_interior_relationship_stream.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

const MAX_ENTITIES := 128

var _authority_peer_id := 1
var _interpolation_delay_seconds := 0.0
var _max_extrapolation_seconds := 0.25
var _teleport_threshold := 8.0
var _stream
var _samples: Dictionary = {}
var _frozen: Dictionary = {}
var _teleport_count := 0


func _init(
	p_authority_peer_id: int = 1,
	p_max_hold_ticks: int = 15,
	p_interpolation_delay_seconds: float = 0.0,
	p_max_extrapolation_seconds: float = 0.25,
	p_teleport_threshold: float = 8.0
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_interpolation_delay_seconds = maxf(0.0, p_interpolation_delay_seconds)
	_max_extrapolation_seconds = clampf(p_max_extrapolation_seconds, 0.0, 2.0)
	_teleport_threshold = maxf(0.0, p_teleport_threshold)
	_stream = RelationshipStream.new(_authority_peer_id, p_max_hold_ticks)


func accept_snapshot(
	source_peer_id: int,
	snapshot: Dictionary,
	migration_generation: int,
	arrival_time_seconds: float
) -> Dictionary:
	if not is_finite(arrival_time_seconds) or arrival_time_seconds < 0.0:
		return _result(false, &"invalid_arrival_time")
	var gate: Dictionary = _stream.accept_snapshot(source_peer_id, snapshot, migration_generation)
	if not bool(gate.get("accepted", false)):
		return gate
	var relationship := Relationship.from_dictionary(snapshot)
	var entity_id := relationship.get_entity_id()
	if gate.get("status") == &"gap_hold":
		_frozen[entity_id] = true
		return _result(true, &"gap_hold", {"entity_id": entity_id, "frozen": true})
	if not _samples.has(entity_id) and _samples.size() >= MAX_ENTITIES:
		return _result(false, &"entity_capacity")
	var current: Dictionary = _samples.get(entity_id, {}) as Dictionary
	var record := {
		"relationship": relationship,
		"arrival_time_seconds": arrival_time_seconds,
		"transform": relationship.get_frame_local_transform(),
		"linear_velocity": relationship.get_linear_velocity(),
		"server_tick": relationship.get_server_tick(),
	}
	var teleported := false
	if not current.is_empty():
		var prior_transform: Transform3D = current.get("transform", Transform3D.IDENTITY)
		teleported = prior_transform.origin.distance_to(relationship.get_frame_local_transform().origin) > _teleport_threshold
		if teleported:
			_teleport_count += 1
		else:
			record["previous"] = current.duplicate(true)
	_samples[entity_id] = record
	_frozen.erase(entity_id)
	return _result(true, &"teleported" if teleported else &"accepted", {
		"entity_id": entity_id, "frozen": false, "teleported": teleported,
	})


func sample(entity_id: StringName, now_seconds: float) -> Dictionary:
	if not is_finite(now_seconds) or now_seconds < 0.0:
		return _result(false, &"invalid_sample_time")
	if not _samples.has(entity_id):
		return _result(false, &"entity_not_tracked")
	var current: Dictionary = _samples[entity_id] as Dictionary
	var transform: Transform3D = current.get("transform", Transform3D.IDENTITY)
	if bool(_frozen.get(entity_id, false)):
		return _result(true, &"frozen", {"entity_id": entity_id, "transform": transform, "frozen": true})
	var render_time := now_seconds - _interpolation_delay_seconds
	var previous: Dictionary = current.get("previous", {}) as Dictionary
	if not previous.is_empty():
		var previous_time := float(previous.get("arrival_time_seconds", 0.0))
		var current_time := float(current.get("arrival_time_seconds", previous_time))
		if current_time > previous_time and render_time < current_time:
			var alpha := clampf((render_time - previous_time) / (current_time - previous_time), 0.0, 1.0)
			var previous_transform: Transform3D = previous.get("transform", Transform3D.IDENTITY)
			transform = previous_transform.interpolate_with(transform, alpha)
	if render_time > float(current.get("arrival_time_seconds", 0.0)):
		var extra := minf(render_time - float(current.get("arrival_time_seconds", 0.0)), _max_extrapolation_seconds)
		var velocity: Vector3 = current.get("linear_velocity", Vector3.ZERO)
		transform.origin += velocity * extra
		return _result(true, &"extrapolated", {"entity_id": entity_id, "transform": transform, "frozen": false})
	return _result(true, &"interpolated", {"entity_id": entity_id, "transform": transform, "frozen": false})


func detach_entity(entity_id: StringName) -> Dictionary:
	_samples.erase(entity_id)
	_frozen.erase(entity_id)
	return _result(true, &"detached", {"entity_id": entity_id})


func reset_migration(source_peer_id: int, migration_generation: int) -> Dictionary:
	var result: Dictionary = _stream.reset_migration(source_peer_id, migration_generation)
	if bool(result.get("accepted", false)):
		_samples.clear()
		_frozen.clear()
	return result


func get_snapshot() -> Dictionary:
	return {
		"tracked_entities": _samples.size(),
		"frozen_entities": _frozen.size(),
		"teleport_count": _teleport_count,
		"migration_generation": int(_stream.get_snapshot().get("migration_generation", 1)),
	}.duplicate(true)


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
