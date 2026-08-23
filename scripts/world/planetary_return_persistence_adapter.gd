class_name PlanetaryReturnPersistenceAdapter
extends RefCounted

## Detached persistence record for one completed planetary return. The record
## retains terminal evidence, never a live surface attachment, berth lease, or
## reward grant. Replay is a one-shot observation and retirement is explicit.

const SCHEMA_VERSION := 1
const RETURN_TARGET_ID: StringName = &"mudds_shipyards"
const WORLD_ID: StringName = &"ember_moon"
const RECORD_KEYS := [
	"accepted", "schema_version", "marker", "world_id", "return_target_id",
	"run_generation", "attachment_generation", "actor_instance_id",
	"craft_instance_id", "completed_return", "receipt_sha256",
	"surface_attachment", "berth_lease", "reward_replay_allowed",
]
const COMPLETED_RETURN_KEYS := [
	"travel_session", "return_contract", "returned_receipt",
]
const DIRECT_AUTHORITY_KEYS := [
	"reward_replay_allowed", "reward_authority", "reward_grant_authority",
	"movement_authority", "ship_movement_authority", "teleport_authority",
	"reparent_authority", "berth_authority", "reservation_authority",
	"occupancy_authority", "lease_authority", "attachment_authority",
]
const AUTHORITY_MAP_KEYS := [
	"reward", "movement", "ship_movement", "teleport", "reparent", "berth",
	"reservation", "occupancy", "lease", "attachment",
]

var _restored_generation := -1
var _retired_generation := -1


func capture(
		travel_session: Object, return_contract: Object, returned_receipt: Variant
	) -> Dictionary:
	if travel_session == null or return_contract == null \
			or not travel_session.has_method(&"get_presentation_snapshot") \
			or not return_contract.has_method(&"get_snapshot"):
		return _reject(&"return_persistence_runtime_unavailable")
	if not returned_receipt is Dictionary:
		return _reject(&"return_persistence_receipt_invalid")
	var receipt := returned_receipt as Dictionary
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("reason", &"")) != &"returned_to_station":
		return _reject(&"return_persistence_receipt_invalid")
	var contract_variant: Variant = return_contract.call(&"get_snapshot")
	var travel_variant: Variant = travel_session.call(&"get_presentation_snapshot")
	if not contract_variant is Dictionary or not travel_variant is Dictionary:
		return _reject(&"return_persistence_runtime_unavailable")
	var contract := contract_variant as Dictionary
	var travel := travel_variant as Dictionary
	if StringName(contract.get("phase_id", &"")) != &"completed" \
			or StringName(contract.get("return_target_id", &"")) != RETURN_TARGET_ID \
			or StringName(contract.get("world_id", &"")) != WORLD_ID \
			or StringName(travel.get("state_id", &"")) != &"completed":
		return _reject(&"return_persistence_not_completed")
	if _contains_live_authority(travel) or _contains_live_authority(contract) \
			or _contains_live_authority(receipt):
		return _reject(&"return_persistence_reward_authority_present")
	var completed_return := {
		"travel_session": _wire_copy(travel),
		"return_contract": _wire_copy(contract),
		"returned_receipt": _wire_copy(receipt),
	}
	var digest := _digest(completed_return)
	if digest.is_empty():
		return _reject(&"return_persistence_receipt_invalid")
	var evidence_rejection := _completed_evidence_rejection(
		completed_return, {}, 0, 0
	)
	if not evidence_rejection.is_empty():
		return _reject(evidence_rejection)
	var berth := receipt.get("berth_receipt", {}) as Dictionary
	var run_generation := int(berth.get("session_generation", 0))
	var attachment_generation := int(berth.get("attachment_generation", 0))
	return {
		"accepted": true,
		"schema_version": SCHEMA_VERSION,
		"marker": "returned_to_station",
		"world_id": str(contract.get("world_id", "")),
		"return_target_id": String(RETURN_TARGET_ID),
		"run_generation": run_generation,
		"attachment_generation": attachment_generation,
		"actor_instance_id": int(berth.get("actor_instance_id", 0)),
		"craft_instance_id": int(berth.get("craft_instance_id", 0)),
		"completed_return": completed_return,
		"receipt_sha256": digest,
		"surface_attachment": {"active": false, "state": "detached"},
		"berth_lease": {"active": false, "state": "fresh_station"},
		"reward_replay_allowed": false,
	}.duplicate(true)


func restore(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return _reject(&"return_persistence_snapshot_invalid")
	var saved := snapshot as Dictionary
	var schema := int(saved.get("schema_version", 0))
	if schema > SCHEMA_VERSION:
		return _reject(&"return_persistence_newer_schema")
	if not _has_exact_keys(saved, RECORD_KEYS) \
			or not _is_integral_number(saved.get("schema_version")) \
			or schema != SCHEMA_VERSION \
			or not saved.get("accepted") is bool \
			or not bool(saved.get("accepted", false)) \
			or not saved.get("marker") is String \
			or not saved.get("world_id") is String \
			or not saved.get("return_target_id") is String \
			or StringName(saved.get("marker", &"")) != &"returned_to_station" \
			or StringName(saved.get("world_id", &"")) != WORLD_ID \
			or StringName(saved.get("return_target_id", &"")) != RETURN_TARGET_ID:
		return _reject(&"return_persistence_snapshot_invalid")
	for numeric_key in [
		"run_generation", "attachment_generation", "actor_instance_id",
		"craft_instance_id",
	]:
		if not _is_integral_number(saved.get(numeric_key)):
			return _reject(&"return_persistence_snapshot_invalid")
	var run_generation := int(saved.get("run_generation", 0))
	var attachment_generation := int(saved.get("attachment_generation", 0))
	if run_generation < 1 or attachment_generation < 1 \
			or run_generation <= _restored_generation \
			or run_generation <= _retired_generation:
		return _reject(&"return_persistence_stale_generation")
	if not saved.get("surface_attachment") is Dictionary \
			or not saved.get("berth_lease") is Dictionary \
			or not saved.get("completed_return") is Dictionary:
		return _reject(&"return_persistence_snapshot_invalid")
	var surface := saved.get("surface_attachment", {}) as Dictionary
	var berth := saved.get("berth_lease", {}) as Dictionary
	if not surface.get("active") is bool \
			or not surface.get("state") is String \
			or bool(surface.get("active", true)) \
			or StringName(surface.get("state", &"")) != &"detached":
		return _reject(&"return_persistence_surface_attachment_active")
	if not berth.get("active") is bool \
			or not berth.get("state") is String \
			or bool(berth.get("active", true)) \
			or StringName(berth.get("state", &"")) != &"fresh_station":
		return _reject(&"return_persistence_berth_authority_present")
	if not saved.get("reward_replay_allowed") is bool \
			or bool(saved.get("reward_replay_allowed", true)) \
			or _contains_live_authority(saved):
		return _reject(&"return_persistence_reward_authority_present")
	if int(saved.get("actor_instance_id", 0)) < 1 \
			or int(saved.get("craft_instance_id", 0)) < 1:
		return _reject(&"return_persistence_identity_invalid")
	var completed_return := saved.get("completed_return", {}) as Dictionary
	if not _has_exact_keys(completed_return, COMPLETED_RETURN_KEYS) \
			or str(saved.get("receipt_sha256", "")) != _digest(completed_return):
		return _reject(&"return_persistence_receipt_corrupt")
	var evidence_rejection := _completed_evidence_rejection(
		completed_return, saved, run_generation, attachment_generation
	)
	if not evidence_rejection.is_empty():
		return _reject(evidence_rejection)
	_restored_generation = run_generation
	return {
		"accepted": true,
		"reason": &"returned_to_station_restored",
		"marker": &"returned_to_station",
		"run_generation": run_generation,
		"attachment_generation": attachment_generation,
		"actor_instance_id": int(saved.actor_instance_id),
		"craft_instance_id": int(saved.craft_instance_id),
		"receipt_sha256": str(saved.receipt_sha256),
		"surface_attachment": {"active": false, "state": &"detached"},
		"berth_lease": {"active": false, "state": &"fresh_station"},
		"reward_replay_allowed": false,
	}.duplicate(true)


func retire(run_generation: int) -> Dictionary:
	if run_generation < 1 or run_generation != _restored_generation \
			or run_generation <= _retired_generation:
		return _reject(&"return_persistence_retire_generation_mismatch")
	_retired_generation = run_generation
	return {
		"accepted": true,
		"reason": &"return_persistence_retired",
		"run_generation": run_generation,
	}


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"restored_generation": _restored_generation,
		"retired_generation": _retired_generation,
		"save_authority": false,
		"movement_authority": false,
		"berth_authority": false,
		"reward_authority": false,
	}


func _completed_evidence_rejection(
		completed: Dictionary, saved: Dictionary,
		run_generation: int, attachment_generation: int
	) -> StringName:
	if not completed.get("travel_session") is Dictionary \
			or not completed.get("return_contract") is Dictionary \
			or not completed.get("returned_receipt") is Dictionary:
		return &"return_persistence_receipt_corrupt"
	var travel := completed.get("travel_session", {}) as Dictionary
	var contract := completed.get("return_contract", {}) as Dictionary
	var receipt := completed.get("returned_receipt", {}) as Dictionary
	if not receipt.get("berth_receipt") is Dictionary \
			or not receipt.get("contract_receipt") is Dictionary:
		return &"return_persistence_receipt_corrupt"
	var berth := receipt.get("berth_receipt", {}) as Dictionary
	var contract_receipt := receipt.get("contract_receipt", {}) as Dictionary
	var expected_run_generation := run_generation
	var expected_attachment_generation := attachment_generation
	var expected_actor_instance_id := int(saved.get("actor_instance_id", 0))
	var expected_craft_instance_id := int(saved.get("craft_instance_id", 0))
	if saved.is_empty():
		expected_run_generation = int(berth.get("session_generation", 0))
		expected_attachment_generation = int(berth.get("attachment_generation", 0))
		expected_actor_instance_id = int(berth.get("actor_instance_id", 0))
		expected_craft_instance_id = int(berth.get("craft_instance_id", 0))
	if not _positive_integral(travel.get("generation")) \
			or not _positive_integral(travel.get("attachment_generation")) \
			or not _positive_integral(contract.get("run_generation")) \
			or not _positive_integral(contract.get("attachment_generation")) \
			or not _positive_integral(berth.get("session_generation")) \
			or not _positive_integral(berth.get("attachment_generation")) \
			or not _positive_integral(berth.get("actor_instance_id")) \
			or not _positive_integral(berth.get("craft_instance_id")) \
			or not _positive_integral(contract_receipt.get("session_generation")) \
			or not _positive_integral(contract_receipt.get("attachment_generation")) \
			or not _positive_integral(contract_receipt.get("actor_instance_id")) \
			or not _positive_integral(contract_receipt.get("craft_instance_id")):
		return &"return_persistence_receipt_corrupt"
	if StringName(travel.get("state_id", &"")) != &"completed" \
			or StringName(travel.get("world_id", &"")) != WORLD_ID \
			or int(travel.get("generation", 0)) != expected_run_generation \
			or int(travel.get("attachment_generation", 0)) != expected_attachment_generation \
			or StringName(contract.get("phase_id", &"")) != &"completed" \
			or StringName(contract.get("return_target_id", &"")) != RETURN_TARGET_ID \
			or StringName(contract.get("world_id", &"")) != WORLD_ID \
			or int(contract.get("run_generation", 0)) != expected_run_generation \
			or int(contract.get("attachment_generation", 0)) != expected_attachment_generation \
			or (not saved.is_empty() \
				and str(contract.get("world_id", "")) != str(saved.get("world_id", ""))):
		return &"return_persistence_receipt_corrupt"
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("reason", &"")) != &"returned_to_station" \
			or not bool(berth.get("accepted", false)) \
			or StringName(berth.get("reason", &"")) != &"return_berth_occupied" \
			or int(berth.get("session_generation", 0)) != expected_run_generation \
			or int(berth.get("attachment_generation", 0)) != expected_attachment_generation \
			or int(berth.get("actor_instance_id", 0)) != expected_actor_instance_id \
			or int(berth.get("craft_instance_id", 0)) != expected_craft_instance_id \
			or not bool(contract_receipt.get("accepted", false)) \
			or StringName(contract_receipt.get("return_target_id", &"")) != RETURN_TARGET_ID \
			or int(contract_receipt.get("session_generation", 0)) != expected_run_generation \
			or int(contract_receipt.get("attachment_generation", 0)) != expected_attachment_generation \
			or int(contract_receipt.get("actor_instance_id", 0)) != expected_actor_instance_id \
			or int(contract_receipt.get("craft_instance_id", 0)) != expected_craft_instance_id:
		return &"return_persistence_receipt_corrupt"
	return &""


func _contains_live_authority(value: Variant, inside_authority: bool = false) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child: Variant = (value as Dictionary)[key_variant]
			if key in DIRECT_AUTHORITY_KEYS and child is bool and bool(child):
				return true
			if inside_authority and key in AUTHORITY_MAP_KEYS \
					and child is bool and bool(child):
				return true
			if _contains_live_authority(child, inside_authority or key == "authority"):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_live_authority(child, inside_authority):
				return true
	return false


func _wire_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var copied := {}
			var keys := (value as Dictionary).keys()
			keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
			for key in keys:
				copied[str(key)] = _wire_copy((value as Dictionary)[key])
			return copied
		TYPE_ARRAY:
			var copied_array := []
			for child in value as Array:
				copied_array.append(_wire_copy(child))
			return copied_array
		TYPE_PACKED_STRING_ARRAY:
			var copied_strings := []
			for child in value as PackedStringArray:
				copied_strings.append(str(child))
			return copied_strings
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var copied_packed := []
			for child in value:
				copied_packed.append(_wire_copy(child))
			return copied_packed
		TYPE_STRING_NAME:
			return str(value)
		TYPE_INT:
			# UserDataStore's JSON parser exposes all wire numbers as floats. Digest
			# the same representation before and after a real process reload.
			return float(value)
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR4:
			return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_QUATERNION:
			return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_RECT2:
			return {"position": _wire_copy(value.position), "size": _wire_copy(value.size)}
		TYPE_AABB:
			return {"position": _wire_copy(value.position), "size": _wire_copy(value.size)}
		TYPE_BASIS:
			return {"x": _wire_copy(value.x), "y": _wire_copy(value.y), "z": _wire_copy(value.z)}
		TYPE_TRANSFORM3D:
			return {"basis": _wire_copy(value.basis), "origin": _wire_copy(value.origin)}
	return value


func _digest(value: Variant) -> String:
	var canonical: Variant = _wire_copy(value)
	if not canonical is Dictionary:
		return ""
	return JSON.stringify(canonical).sha256_text()


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)


func _positive_integral(value: Variant) -> bool:
	return _is_integral_number(value) and int(value) > 0


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
