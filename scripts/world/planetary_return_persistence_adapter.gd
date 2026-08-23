class_name PlanetaryReturnPersistenceAdapter
extends RefCounted

## Caller-owned persistence boundary for a completed planetary return.  A
## completed visit is safe to serialize as a station marker, but its surface
## attachment and berth lease are deliberately not serializable authority.

const SCHEMA_VERSION := 1
const RETURN_TARGET_ID: StringName = &"mudds_shipyards"

var _restored_generation := -1

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
	var berth := receipt.get("berth_receipt", {}) as Dictionary
	if not bool(berth.get("accepted", false)) \
			or StringName(berth.get("reason", &"")) != &"return_berth_occupied":
		return _reject(&"return_persistence_berth_receipt_invalid")
	var contract := return_contract.call(&"get_snapshot") as Dictionary
	var travel := travel_session.call(&"get_presentation_snapshot") as Dictionary
	if StringName(contract.get("phase_id", &"")) != &"completed" \
			or StringName(contract.get("return_target_id", &"")) != RETURN_TARGET_ID \
			or StringName(travel.get("state_id", &"")) != &"completed":
		return _reject(&"return_persistence_not_completed")
	var run_generation := int(berth.get("session_generation", 0))
	var attachment_generation := int(berth.get("attachment_generation", 0))
	if run_generation < 1 or attachment_generation < 1 \
			or int(contract.get("run_generation", run_generation)) != run_generation \
			or int(travel.get("generation", run_generation)) != run_generation:
		return _reject(&"return_persistence_generation_mismatch")
	return {
		"schema_version": SCHEMA_VERSION,
		"marker": &"returned_to_station",
		"world_id": StringName(contract.get("world_id", &"")),
		"return_target_id": RETURN_TARGET_ID,
		"run_generation": run_generation,
		"attachment_generation": attachment_generation,
		"actor_instance_id": int(berth.get("actor_instance_id", 0)),
		"craft_instance_id": int(berth.get("craft_instance_id", 0)),
		"surface_attachment": {"active": false, "state": &"detached"},
		"berth_lease": {"active": false, "state": &"fresh_station"},
		"reward_replay_allowed": false,
	}.duplicate(true)

func restore(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return _reject(&"return_persistence_snapshot_invalid")
	var saved := snapshot as Dictionary
	if int(saved.get("schema_version", 0)) != SCHEMA_VERSION \
			or StringName(saved.get("marker", &"")) != &"returned_to_station" \
			or StringName(saved.get("return_target_id", &"")) != RETURN_TARGET_ID:
		return _reject(&"return_persistence_snapshot_invalid")
	var run_generation := int(saved.get("run_generation", 0))
	var attachment_generation := int(saved.get("attachment_generation", 0))
	if run_generation < 1 or attachment_generation < 1 \
			or run_generation <= _restored_generation:
		return _reject(&"return_persistence_stale_generation")
	var surface := saved.get("surface_attachment", {}) as Dictionary
	var berth := saved.get("berth_lease", {}) as Dictionary
	if bool(surface.get("active", true)) or bool(berth.get("active", true)) \
			or StringName(surface.get("state", &"")) != &"detached" \
			or StringName(berth.get("state", &"")) != &"fresh_station" \
			or bool(saved.get("reward_replay_allowed", true)):
		return _reject(&"return_persistence_authority_present")
	if int(saved.get("actor_instance_id", 0)) < 1 \
			or int(saved.get("craft_instance_id", 0)) < 1:
		return _reject(&"return_persistence_identity_invalid")
	_restored_generation = run_generation
	return {
		"accepted": true,
		"reason": &"returned_to_station_restored",
		"marker": &"returned_to_station",
		"run_generation": run_generation,
		"attachment_generation": attachment_generation,
		"surface_attachment": {"active": false, "state": &"detached"},
		"berth_lease": {"active": false, "state": &"fresh_station"},
		"reward_replay_allowed": false,
	}.duplicate(true)

func get_snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "restored_generation": _restored_generation, "save_authority": false}

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
