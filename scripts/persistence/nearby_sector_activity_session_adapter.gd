class_name NearbySectorActivitySessionAdapter
extends RefCounted

## Caller-owned persistence codec for nearby-sector activity progress.
## It never reads/writes UserDataStore, starts activities, or grants rewards.

const SCHEMA_VERSION := 1
const SUPPORTED_ACTIVITY_IDS: Array[StringName] = [
	&"cinder_reach_emberline_convoy", &"cinder_reach_checkpoint_route",
	&"cinder_platform_supply_run", &"cinder_platform_mining_run",
	&"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal",
	&"station_defense",
]

var _restored_generations: Dictionary = {}


func capture(binding_snapshot: Dictionary) -> Dictionary:
	var activities: Array[Dictionary] = []
	var host := binding_snapshot.get("host", {}) as Dictionary
	_capture_activity(activities, host.get("activity", {}) as Dictionary, &"cinder_reach_emberline_convoy")
	_capture_activity(activities, binding_snapshot.get("race", {}) as Dictionary, &"cinder_reach_checkpoint_route")
	_capture_activity(activities, binding_snapshot.get("cargo", {}) as Dictionary, &"cinder_platform_supply_run")
	_capture_activity(activities, binding_snapshot.get("mining", {}) as Dictionary, &"cinder_platform_mining_run")
	_capture_activity(activities, binding_snapshot.get("structure_scan", {}) as Dictionary, &"cinder_derelict_structure_scan")
	_capture_activity(activities, binding_snapshot.get("beacon_traversal", {}) as Dictionary, &"cinder_debris_beacon_traversal")
	_capture_activity(activities, binding_snapshot.get("station_defense", {}) as Dictionary, &"station_defense")
	return {"schema_version": SCHEMA_VERSION, "activities": activities}.duplicate(true)


func restore(payload: Variant, current_generations: Dictionary = {}) -> Dictionary:
	if not payload is Dictionary:
		return _rejected(&"malformed_payload")
	var record := payload as Dictionary
	var version := int(record.get("schema_version", -1))
	if version > SCHEMA_VERSION:
		return _rejected(&"newer_schema")
	if version != SCHEMA_VERSION or not record.get("activities", []) is Array:
		return _rejected(&"malformed_payload")
	var restored: Array[Dictionary] = []
	for raw_activity in record.activities as Array:
		if not raw_activity is Dictionary:
			return _rejected(&"malformed_activity")
		var activity := raw_activity as Dictionary
		var activity_id := StringName(activity.get("activity_id", &""))
		var generation := int(activity.get("generation", -1))
		if not SUPPORTED_ACTIVITY_IDS.has(activity_id) or generation < 0:
			return _rejected(&"invalid_activity_identity")
		var current_generation := int(current_generations.get(activity_id, -1))
		if current_generation >= 0 and generation < current_generation:
			return _rejected(&"stale_generation")
		if int(_restored_generations.get(activity_id, -1)) >= generation:
			return _rejected(&"replay_generation")
		_restored_generations[activity_id] = generation
		restored.append(activity.duplicate(true))
	return {"accepted": true, "reason": &"restored", "schema_version": SCHEMA_VERSION, "activities": restored}.duplicate(true)


func clear_replay_fence() -> void:
	_restored_generations.clear()


func _capture_activity(output: Array[Dictionary], source: Dictionary, fallback_id: StringName) -> void:
	if source.is_empty():
		return
	var activity_id := StringName(source.get("activity_id", fallback_id))
	if not SUPPORTED_ACTIVITY_IDS.has(activity_id):
		return
	output.append({
		"activity_id": activity_id,
		"generation": int(source.get("generation", source.get("session_generation", 0))),
		"state": int(source.get("state", 0)),
		"progress": source.duplicate(true),
		"reward_requested": bool(source.get("reward_requested", false)),
		"reward_granted": false,
	})


func _rejected(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "schema_version": SCHEMA_VERSION, "activities": []}
