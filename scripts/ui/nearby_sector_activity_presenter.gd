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
		"actions": _persistence_actions(),
		"persistence_feedback": {"status": &"none", "text": "No progress result received."},
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


func save_progress_intent() -> Dictionary:
	return {"accepted": true, "reason": &"save_requested", "action": &"save_progress", "authority": false}


func load_progress_intent() -> Dictionary:
	return {"accepted": true, "reason": &"load_requested", "action": &"load_progress", "authority": false}


## Formats a detached persistence receipt without reading or writing a store.
## The returned actions remain available so callers can retry after a failure.
func present_persistence_result(result: Dictionary) -> Dictionary:
	var view := present(_snapshot)
	var status := StringName(str(result.get("status", result.get("reason", &"unknown"))))
	var feedback := _persistence_feedback(status, bool(result.get("accepted", false)))
	view["persistence_feedback"] = feedback
	return view


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
	if activity_id == &"cinder_debris_beacon_traversal" \
			and StringName(state.get("reason", &"")) == &"out_of_order_beacon":
		state_id = &"wrong_order"
	var cargo_progress: Dictionary = {}
	if activity_id == &"cinder_platform_supply_run":
		cargo_progress = _cargo_progress(state)
	var progress := (
		"  //  %s" % str(cargo_progress.get("summary", ""))
		if not cargo_progress.is_empty()
		else _progress_text(activity_id, state)
	)
	var recovery := _recovery_text(state)
	var reward_pending := bool(state.get("reward_requested", false))
	var status_suffix := ""
	if reward_pending:
		status_suffix += "  REWARD PENDING"
	if not recovery.is_empty():
		status_suffix += "  " + recovery
	return {
		"activity_id": activity_id,
		"title": _title(activity_id),
		"state_id": state_id,
		"text": "%s — %s%s%s" % [_title(activity_id), _state_text(state_id), progress, status_suffix],
		"focusable": true,
		"selected": activity_id == _selected_activity,
		"intents": ["select", "start", "reset"],
		"reward_pending": reward_pending,
		"recovery_text": recovery,
		"objective_text": str(cargo_progress.get("objective_text", "")),
		"cargo_progress": cargo_progress.duplicate(true),
		"activity_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _progress_text(activity_id: StringName, state: Dictionary) -> String:
	if activity_id == &"cinder_debris_beacon_traversal":
		return " (NEXT BEACON %d/%d)" % [int(state.get("next_beacon_index", 0)) + 1, int(state.get("beacon_count", 4))]
	if activity_id == &"cinder_platform_mining_run":
		return " (%.1f/%.1f s)" % [float(state.get("elapsed_seconds", 0.0)), float(state.get("extraction_seconds", 0.0))]
	if activity_id == &"cinder_derelict_structure_scan":
		return " (%.1f/%.1f s)" % [float(state.get("elapsed_seconds", 0.0)), float(state.get("scan_seconds", 0.0))]
	if activity_id == &"cinder_platform_supply_run":
		var next_phase := int(state.get("next_phase_index", 0))
		var phase_count := maxi(int(state.get("phase_count", 0)), 0)
		var remaining := float(state.get("deadline_remaining_seconds", 0.0))
		return " (PHASE %d/%d  %.1fs LEFT)" % [next_phase, phase_count, maxf(remaining, 0.0)]
	return ""


## Converts the cargo authority's ordered phase cursor into concise player copy.
## It does not infer movement, cargo ownership, transfer success, or rewards.
func _cargo_progress(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var numeric_state := int(state.get("state", -1))
	var next_phase_index := maxi(int(state.get("next_phase_index", 0)), 0)
	var phase_count := maxi(int(state.get("phase_count", 0)), 0)
	var contract := state.get("contract", {}) as Dictionary
	var ordered_phases := contract.get("ordered_phases", []) as Array
	if phase_count == 0:
		phase_count = ordered_phases.size()
	var next_phase_id: StringName = &""
	if next_phase_index < ordered_phases.size():
		next_phase_id = StringName(ordered_phases[next_phase_index])

	var stage_id: StringName = &"pickup"
	var objective := "LOAD THE CINDER SUPPLY CRATE"
	match next_phase_id:
		&"clear_gate":
			stage_id = &"transit"
			objective = "CLEAR THE CINDER DEPARTURE GATE"
		&"dock_platform":
			stage_id = &"delivery"
			objective = "DOCK AT THE CINDER PLATFORM"
		&"load_crate":
			pass
		_:
			if phase_count > 0 and next_phase_index >= phase_count:
				stage_id = &"delivery"
				objective = "TRANSFER AT THE PLATFORM CARGO TERMINAL"

	var terminal := numeric_state in [CargoDeliveryActivity.State.COMPLETED,
		CargoDeliveryActivity.State.FAILED, CargoDeliveryActivity.State.EXPIRED]
	if numeric_state == CargoDeliveryActivity.State.COMPLETED:
		stage_id = &"delivered"
		objective = "CARGO TRANSFER CONFIRMED"
	elif numeric_state in [CargoDeliveryActivity.State.FAILED, CargoDeliveryActivity.State.EXPIRED]:
		stage_id = &"failure"
		objective = "DELIVERY FAILED DURING %s" % _cargo_stage_label(
			_stage_for_phase(next_phase_id, next_phase_index, phase_count)
		)

	var step_number := mini(next_phase_index + 1, phase_count) if phase_count > 0 else 0
	var remaining := maxf(float(state.get("deadline_remaining_seconds", 0.0)), 0.0)
	var summary := "%s %d/%d: %s" % [
		_cargo_stage_label(stage_id), step_number, phase_count, objective
	]
	if numeric_state == CargoDeliveryActivity.State.ACTIVE:
		summary += "  //  %.1fs LEFT" % remaining
	return {
		"stage_id": stage_id,
		"stage_label": _cargo_stage_label(stage_id),
		"objective_text": objective,
		"next_phase_id": next_phase_id,
		"next_phase_index": next_phase_index,
		"phase_count": phase_count,
		"step_number": step_number,
		"deadline_remaining_seconds": remaining,
		"terminal": terminal,
		"summary": summary,
		"activity_authority": false,
		"inventory_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func _stage_for_phase(phase_id: StringName, next_index: int, phase_count: int) -> StringName:
	if phase_id == &"clear_gate":
		return &"transit"
	if phase_id == &"dock_platform" or (phase_count > 0 and next_index >= phase_count):
		return &"delivery"
	return &"pickup"


func _cargo_stage_label(stage_id: StringName) -> String:
	return {
		&"pickup": "PICKUP",
		&"transit": "TRANSIT",
		&"delivery": "DELIVERY",
		&"delivered": "DELIVERED",
		&"failure": "FAILED",
	}.get(stage_id, "PICKUP")


func _state_label(state: Dictionary) -> String:
	if state.is_empty():
		return "available"
	var numeric_state := int(state.get("state", -1))
	if numeric_state == 2:
		return "completed"
	if numeric_state == 1:
		return "active"
	if numeric_state == 3:
		return "failed"
	if numeric_state == 4:
		return "expired"
	return "available"


func _state_text(state_id: StringName) -> String:
	return {&"idle": "AVAILABLE", &"active": "ACTIVE", &"started": "ACTIVE", &"traversing": "ACTIVE", &"wrong_order": "WRONG ORDER", &"completed": "COMPLETED", &"complete": "COMPLETED", &"failed": "FAILED", &"expired": "EXPIRED", &"reset": "AVAILABLE"}.get(state_id, str(state_id).to_upper())


func _recovery_text(state: Dictionary) -> String:
	var failure := StringName(state.get("failure_reason", &""))
	if StringName(state.get("reason", &"")) == &"out_of_order_beacon":
		return "RECOVER: FOLLOW BEACON ORDER"
	if not failure.is_empty():
		return "RECOVER: " + str(failure).replace("_", " ").to_upper()
	var reason := StringName(state.get("reason", &""))
	if reason in [&"", &"started", &"progressed", &"completed", &"reward_requested", &"reset"]:
		return ""
	return "RECOVER: " + str(reason).replace("_", " ").to_upper()


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


func _persistence_actions() -> Array[Dictionary]:
	return [
		{"id": &"save_progress", "label": "Save progress", "focusable": true, "authority": false},
		{"id": &"load_progress", "label": "Load progress", "focusable": true, "authority": false},
	]


func _persistence_feedback(status: StringName, accepted: bool) -> Dictionary:
	if accepted and status in [&"saved", &"save_succeeded", &"progress_saved"]:
		return {"status": &"saved", "text": "Progress saved.", "color_independent": true}
	if accepted and status in [&"restored", &"loaded", &"progress_restored"]:
		return {"status": &"restored", "text": "Progress restored.", "color_independent": true}
	if status in [&"invalid", &"invalid_payload", &"corrupt"]:
		return {"status": &"invalid", "text": "Saved progress is invalid; current activity state is unchanged.", "color_independent": true}
	if status == &"newer_schema":
		return {"status": &"newer_schema", "text": "Saved progress belongs to a newer version.", "color_independent": true}
	if status in [&"failed_write", &"save_failed"]:
		return {"status": &"failed_write", "text": "Progress could not be saved.", "color_independent": true}
	if status in [&"load_failed", &"read_failed"]:
		return {"status": &"load_failed", "text": "Progress could not be loaded.", "color_independent": true}
	return {"status": &"unknown", "text": "Progress result unavailable.", "color_independent": true}
