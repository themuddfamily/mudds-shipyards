class_name NearbySectorActivityPresenter
extends RefCounted

## Detached presentation model for NearbySectorActivityBinding.
##
## This presenter consumes a copied activity snapshot and emits text plus
## controller-safe intents. It owns no activity lifecycle, reward, HUD, or
## input authority; a caller must route any returned intent explicitly.

const SCHEMA_VERSION := 1
const ACTIVITY_IDS: Array[StringName] = [
	&"cinder_reach_emberline_convoy",
	&"cinder_reach_checkpoint_route",
	&"cinder_platform_mining_run",
	&"cinder_derelict_structure_scan",
	&"cinder_debris_beacon_traversal",
	&"cinder_platform_supply_run",
	&"station_defense",
]

var _snapshot: Dictionary = {}
var _selected_activity: StringName = &""


func present(snapshot: Dictionary) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var cards: Array[Dictionary] = []
	for activity_id in ACTIVITY_IDS:
		var state := _activity_state(activity_id)
		cards.append(_card(activity_id, state))
	return {
		"schema_version": SCHEMA_VERSION,
		"selected_activity": _selected_activity,
		"cards": cards,
		"focusable": true,
		"color_independent": true,
		"activity_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func select(activity_id: StringName) -> Dictionary:
	if not ACTIVITY_IDS.has(activity_id):
		return {"accepted": false, "reason": &"unknown_activity", "activity_id": activity_id}
	_selected_activity = activity_id
	return _intent_result(&"selected", activity_id)


func start_intent(activity_id: StringName = _selected_activity) -> Dictionary:
	return _intent_result(&"start_requested", activity_id)


func reset_intent(activity_id: StringName = _selected_activity) -> Dictionary:
	return _intent_result(&"reset_requested", activity_id)


func get_snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "selected_activity": _selected_activity, "snapshot": _snapshot.duplicate(true)}


func _activity_state(activity_id: StringName) -> Dictionary:
	var source := _snapshot.get("host", {}) as Dictionary
	if activity_id == &"cinder_reach_emberline_convoy":
		return source.get("activity", {}) as Dictionary
	if activity_id == &"cinder_reach_checkpoint_route":
		return _snapshot.get("race", {}) as Dictionary
	if activity_id == &"cinder_platform_mining_run":
		return _snapshot.get("mining", {}) as Dictionary
	if activity_id == &"cinder_derelict_structure_scan":
		return _snapshot.get("structure_scan", {}) as Dictionary
	if activity_id == &"cinder_debris_beacon_traversal":
		return _snapshot.get("beacon_traversal", {}) as Dictionary
	if activity_id == &"cinder_platform_supply_run":
		return _snapshot.get("cargo", {}) as Dictionary
	return {"state_id": "available"}


func _card(activity_id: StringName, state: Dictionary) -> Dictionary:
	var state_id := StringName(state.get("state_id", _state_label(state)))
	var progress := _progress_text(activity_id, state)
	return {
		"activity_id": activity_id,
		"title": _title(activity_id),
		"state_id": state_id,
		"text": "%s — %s%s" % [_title(activity_id), _state_text(state_id), progress],
		"focusable": true,
		"selected": activity_id == _selected_activity,
		"intents": ["select", "start", "reset"],
		"reward_pending": bool(state.get("reward_requested", false)),
	}.duplicate(true)


func _progress_text(activity_id: StringName, state: Dictionary) -> String:
	if activity_id == &"cinder_debris_beacon_traversal":
		return " (%d/%d beacons)" % [int(state.get("next_beacon_index", 0)), int(state.get("beacon_count", 4))]
	if activity_id == &"cinder_platform_mining_run":
		return " (%.1f/%.1f s)" % [float(state.get("elapsed_seconds", 0.0)), float(state.get("extraction_seconds", 0.0))]
	if activity_id == &"cinder_derelict_structure_scan":
		return " (%.1f/%.1f s)" % [float(state.get("elapsed_seconds", 0.0)), float(state.get("scan_seconds", 0.0))]
	return ""


func _state_label(state: Dictionary) -> String:
	if state.is_empty():
		return "available"
	var numeric_state := int(state.get("state", -1))
	if numeric_state == 2:
		return "completed"
	if numeric_state == 1:
		return "active"
	return "available"


func _state_text(state_id: StringName) -> String:
	return {&"idle": "AVAILABLE", &"active": "ACTIVE", &"started": "ACTIVE", &"completed": "COMPLETED", &"complete": "COMPLETED", &"reset": "AVAILABLE"}.get(state_id, str(state_id).to_upper())


func _title(activity_id: StringName) -> String:
	return {
		&"cinder_reach_emberline_convoy": "EMBERLINE CONVOY",
		&"cinder_reach_checkpoint_route": "BEACON RACE",
		&"cinder_platform_mining_run": "PLATFORM EXTRACTION",
		&"cinder_derelict_structure_scan": "DERELICT SCAN",
		&"cinder_debris_beacon_traversal": "DEBRIS BEACON RUN",
		&"cinder_platform_supply_run": "PLATFORM SUPPLY RUN",
		&"station_defense": "STATION DEFENSE",
	}.get(activity_id, "ACTIVITY")


func _intent_result(reason: StringName, activity_id: StringName) -> Dictionary:
	return {"accepted": ACTIVITY_IDS.has(activity_id), "reason": reason, "activity_id": activity_id, "authority": false}
