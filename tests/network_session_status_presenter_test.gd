extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var connecting := presenter.present_snapshot({"state": &"connecting", "role": &"host"})
	_check(connecting.title == "Connecting" and connecting.actions[0].id == &"cancel" and connecting.actions[0].focusable, "connecting state exposes a focusable cancel action")
	_check(connecting.message.contains("NEXT ACTION // WAIT FOR HOST ADMISSION OR CANCEL CONNECTION") and connecting.color_independent, "connecting next action is readable without colour")
	var connected := presenter.present_snapshot({"state": &"connected", "role": &"client", "detail": "Joined Cinder Run."})
	_check(connected.message.begins_with("Joined Cinder Run.") and connected.actions[0].id == &"disconnect", "connected state exposes readable detail and disconnect")
	_check(presenter.request_disconnect().accepted and not presenter.request_retry().accepted, "connected intents remain bounded to disconnect")
	var failed := presenter.present_snapshot({"state": &"failed", "detail": "Admission was refused.", "retryable": true})
	_check(failed.title == "Connection Failed" and failed.actions.size() == 2 and failed.actions[0].id == &"retry", "failed state exposes retry and cancel actions")
	_check(presenter.request_retry().accepted and presenter.request_cancel().accepted, "failure actions return external intents")
	var invalid := presenter.present_snapshot({"state": &"mystery"})
	_check(invalid.state == &"failed" and invalid.actions[0].focusable and not presenter.request_retry().accepted, "unknown state fails closed without retry authority")

	var fenced := Presenter.new()
	var reconnecting := fenced.present_snapshot(_snapshot(
		&"cinder_session", 7, 10, &"reconnecting", 1, 4, 12.5
	))
	_check(
		reconnecting.state == &"reconnecting"
			and reconnecting.message.contains("NEXT ACTION // WAIT 12.5 S FOR RECONNECT ATTEMPT 4 OR CANCEL RECONNECT"),
		"reconnect snapshot names the timed next action in text"
	)
	var stale_sequence := fenced.present_snapshot(_snapshot(
		&"cinder_session", 7, 9, &"connected", 2
	))
	_check(
		stale_sequence.state == &"reconnecting" and stale_sequence.source_sequence == 10,
		"older authoritative event sequence cannot repaint the session status"
	)
	var wrong_session := fenced.present_snapshot(_snapshot(
		&"ember_session", 8, 50, &"connected", 3
	))
	_check(
		wrong_session.state == &"reconnecting" and wrong_session.session_id == &"cinder_session",
		"different session identity cannot replace an attached session"
	)
	var migrating := fenced.present_snapshot(_snapshot(
		&"cinder_session", 7, 11, &"migrating", 2
	))
	_check(
		migrating.state == &"migrating"
			and migrating.next_action == "WAIT FOR NEW HOST OR CANCEL MIGRATION",
		"host migration names the safe player choice without colour"
	)
	var disconnected := fenced.present_snapshot({
		"session_id": &"cinder_session",
		"generation": 7,
		"sequence": 12,
		"state": &"disconnected",
		"retryable": true,
	})
	_check(
		disconnected.state == &"disconnected" and disconnected.next_action == "RETRY CONNECTION",
		"disconnect clears retained authority while keeping a readable recovery action"
	)
	var late_after_disconnect := fenced.present_snapshot(_snapshot(
		&"cinder_session", 7, 99, &"migrating", 4
	))
	_check(
		late_after_disconnect.state == &"disconnected" and late_after_disconnect.source_sequence == 12,
		"retired generation cannot repaint after disconnect even with a larger late sequence"
	)
	var reused := fenced.present_snapshot(_owned_snapshot(
		&"cinder_session", 8, 1, 7, 9
	))
	_check(
		reused.state == &"connected"
			and reused.next_action == "WAIT FOR HOST CRAFT ASSIGNMENT OR DISCONNECT"
			and reused.source_generation == 8,
		"new session generation reuses the presenter with authoritative assignment guidance"
	)
	var detached := fenced.detach()
	var after_detach := fenced.present_snapshot(_snapshot(
		&"ember_session", 1, 1, &"connected", 1
	))
	_check(
		not detached.attached and after_detach.session_id == &"ember_session"
			and after_detach.ownership_rows.is_empty(),
		"detach clears the cursor and cached authoritative rows before reuse"
	)
	if _failures.is_empty():
		print("NETWORK_SESSION_STATUS_PRESENTER_TEST_OK: 15 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _snapshot(
	session_id: StringName,
	generation: int,
	sequence: int,
	state: StringName,
	revision: int,
	attempt: int = 0,
	seconds_remaining: float = 0.0
) -> Dictionary:
	return {
		"session_id": session_id,
		"generation": generation,
		"state": state,
		"role": &"client",
		"attempt": attempt,
		"seconds_remaining": seconds_remaining,
		"authoritative_snapshot": {
			"authority_peer_id": 1,
			"event_sequence": sequence,
			"revision": revision,
			"sections": {&"ownership": [], &"boarding": [], &"respawn": []},
		},
	}


func _owned_snapshot(
	session_id: StringName,
	generation: int,
	sequence: int,
	local_peer_id: int,
	owner_peer_id: int
) -> Dictionary:
	var snapshot := _snapshot(session_id, generation, sequence, &"connected", 1)
	snapshot["local_role"] = &"pilot"
	snapshot["local_peer_id"] = local_peer_id
	snapshot["controlled_craft_id"] = &"jovian_a"
	snapshot["controlled_craft"] = "Jovian A"
	snapshot.authoritative_snapshot.sections.ownership = [{
		"ship_id": &"jovian_a",
		"ship_generation": 1,
		"owner_peer_id": owner_peer_id,
		"ownership_generation": 1,
	}]
	return snapshot
