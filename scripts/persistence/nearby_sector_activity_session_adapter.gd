class_name NearbySectorActivitySessionAdapter
extends RefCounted

## Caller-owned persistence codec for nearby-sector activity progress.
## It never reads/writes UserDataStore, starts activities, or grants rewards.

const SCHEMA_VERSION := 1
const SUPPORTED_ACTIVITY_IDS: Array[StringName] = [
	&"cinder_reach_emberline_convoy", &"cinder_reach_checkpoint_route",
	&"cinder_reach_platform_patrol_route",
	&"cinder_platform_supply_run", &"cinder_platform_mining_run",
	&"jovian_fabrication_kit_delivery",
	&"cinder_derelict_structure_scan", &"cinder_debris_beacon_traversal",
	&"cinder_asteroid_field_threading_run",
	&"station_defense",
]

const ASTEROID_SESSION_SLOT := "cinder_asteroid_session"
const ASTEROID_ACTIVITY_ID: StringName = &"cinder_asteroid_field_threading_run"
const ASTEROID_ROUTE := preload("res://assets/activities/cinder_asteroid_field_threading_run.tres")


## Use the existing envelope with only the route owner's canonical save state.
## Reward metadata proves a terminal handoff; it cannot replace route geometry.
static func capture_asteroid_session(route_state: Dictionary, paid: bool) -> Dictionary:
	var record := {"schema_version": SCHEMA_VERSION, "activities": [{
		"activity_id": String(ASTEROID_ACTIVITY_ID),
		"generation": route_state.get("generation", 0),
		"state": route_state.get("state", 0), "progress": route_state.duplicate(true),
		"reward_requested": int(route_state.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED,
		"reward_granted": paid,
	}]}
	if not bool(validate_asteroid_session(record).get("accepted", false)):
		return {}
	# UserDataStore installs parsed JSON numbers. Canonicalise this validated
	# owned session only, so exact comparisons retain every route/payment field.
	return JSON.parse_string(JSON.stringify(record)) as Dictionary


static func validate_asteroid_session(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 2 \
			or not (value.get("schema_version") is int or value.get("schema_version") is float) \
			or float(value.schema_version) != float(SCHEMA_VERSION) \
			or not value.get("activities") is Array or value.activities.size() != 1:
		return {"accepted": false, "reason": &"asteroid_session_invalid"}
	var entry: Variant = value.activities[0]
	if not entry is Dictionary or entry.size() != 6 or entry.get("activity_id") != String(ASTEROID_ACTIVITY_ID) \
			or not entry.get("reward_requested") is bool or not entry.get("reward_granted") is bool:
		return {"accepted": false, "reason": &"asteroid_session_invalid"}
	var route := CheckpointRouteActivity.new(ASTEROID_ROUTE)
	var validated := route.validate_persistence_state(entry.get("progress"))
	if not bool(validated.get("accepted", false)):
		return validated
	var state := entry.progress as Dictionary
	if not state.get("activity_id") is String or not (entry.get("generation") is int or entry.get("generation") is float) \
			or not (entry.get("state") is int or entry.get("state") is float):
		return {"accepted": false, "reason": &"asteroid_session_invalid"}
	if entry.get("generation") != state.generation or entry.get("state") != state.state \
			or entry.reward_requested != (int(state.state) == CheckpointRouteActivity.State.COMPLETED) \
			or (entry.reward_granted and not entry.reward_requested):
		return {"accepted": false, "reason": &"asteroid_session_invalid"}
	return {"accepted": true, "reason": &"asteroid_session_valid"}


var _restored_generations: Dictionary = {}


func capture(binding_snapshot: Dictionary) -> Dictionary:
	var activities: Array[Dictionary] = []
	var host := binding_snapshot.get("host", {}) as Dictionary
	_capture_activity(activities, host.get("activity", {}) as Dictionary, &"cinder_reach_emberline_convoy")
	# A standalone persistence slot supplies at most one typed patrol route, so
	# prefer it over the race record when present instead of emitting two owners.
	var patrol := binding_snapshot.get("patrol", {}) as Dictionary
	if not patrol.is_empty():
		_capture_activity(activities, patrol, &"cinder_reach_checkpoint_route")
	else:
		_capture_activity(activities, binding_snapshot.get("race", {}) as Dictionary, &"cinder_reach_checkpoint_route")
	_capture_activity(activities, binding_snapshot.get("cargo", {}) as Dictionary, &"cinder_platform_supply_run")
	_capture_activity(activities, binding_snapshot.get("mining", {}) as Dictionary, &"cinder_platform_mining_run")
	_capture_activity(activities, binding_snapshot.get("structure_scan", {}) as Dictionary, &"cinder_derelict_structure_scan")
	_capture_activity(activities, binding_snapshot.get("beacon_traversal", {}) as Dictionary, &"cinder_debris_beacon_traversal")
	_capture_activity(activities, binding_snapshot.get("asteroid_field_run", {}) as Dictionary, &"cinder_asteroid_field_threading_run")
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
