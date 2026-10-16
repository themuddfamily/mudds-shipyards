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
	var engineer := presenter.present_snapshot({"state": &"connected", "role": &"client", "local_role": &"engineer"})
	_check(engineer.local_role == &"engineer" and engineer.ownership_text == "ENGINEER" and engineer.next_action.contains("REPAIR AT BERTH"), "confirmed engineer role retains explicit ownership and usable controls guidance")
	var gunner := presenter.present_snapshot({"state": &"connected", "role": &"client", "local_role": &"gunner"})
	_check(gunner.local_role == &"gunner" and gunner.ownership_text == "GUNNER" and gunner.next_action == "CONTINUE AS GUNNER OR DISCONNECT", "confirmed gunner is named correctly rather than being told to wait for assignment")
	_check(presenter.request_disconnect().accepted and not presenter.request_retry().accepted and not presenter.request_cancel().accepted, "gunner presentation keeps the existing connected-session intent boundary")
	var unknown_role := presenter.present_snapshot({"state": &"connected", "local_role": &"unknown_crew_role"})
	_check(unknown_role.local_role == &"observer" and unknown_role.ownership_text == "OBSERVER" and unknown_role.next_action == "WAIT FOR HOST ASSIGNMENT OR DISCONNECT", "an unknown role still falls back to observer after a confirmed gunner")
	var failed := presenter.present_snapshot({"state": &"failed", "detail": "Admission was refused.", "retryable": true})
	_check(failed.title == "Connection Failed" and failed.actions.size() == 2 and failed.actions[0].id == &"retry", "failed state exposes retry and cancel actions")
	_check(presenter.request_retry().accepted and presenter.request_cancel().accepted, "failure actions return external intents")
	var host_lost := presenter.present_snapshot({
		"state": &"disconnected", "role": &"client",
		"detail": "Session closed: server_disconnected", "retryable": true,
	})
	_check(host_lost.message.begins_with("Connection to the session host was lost.") and host_lost.message.contains("NEXT ACTION // RETRY CONNECTION"), "host loss names the lost connection and available recovery action")
	_check(presenter.request_retry().accepted and not presenter.request_disconnect().accepted, "host loss preserves caller-owned retry intent without an active disconnect")
	var unreachable := presenter.present_snapshot({
		"state": &"disconnected", "role": &"client",
		"detail": "Session closed: connection_failed", "retryable": true,
	})
	_check(unreachable.message.begins_with("Could not reach the session host.") and unreachable.message.contains("Check the address"), "failed initial connection gives readable host troubleshooting")
	var reconnect_started := presenter.present_snapshot({
		"state": &"connecting", "role": &"client", "detail": "Contacting the session host.",
	})
	_check(reconnect_started.message.begins_with("Contacting the session host.") and not reconnect_started.message.contains("was lost") and reconnect_started.actions[0].id == &"cancel", "retry replaces terminal host-loss copy with current connecting guidance")
	var full_source := {
		"state": &"disconnected", "role": &"client",
		"detail": "Session closed: session_full", "retryable": true,
	}
	var full := presenter.present_snapshot(full_source)
	_check(full.message.begins_with("The session is full. Wait for a player to leave before retrying.") and full.state == &"disconnected", "full admission explains capacity rather than displaying the transport token")
	_check(presenter.request_retry().accepted and not presenter.request_disconnect().accepted, "capacity guidance preserves the caller-owned retry intent without an active session")
	full_source["retryable"] = false
	var full_without_retry := presenter.present_snapshot(full_source)
	_check(full_without_retry.actions.is_empty() and not presenter.request_retry().accepted, "capacity guidance cannot enable retry when the caller forbids it")
	var after_capacity_retry := presenter.present_snapshot({
		"state": &"connecting", "role": &"client", "detail": "Contacting the session host.",
	})
	_check(after_capacity_retry.message.begins_with("Contacting the session host.") and not after_capacity_retry.message.contains("session is full") and after_capacity_retry.actions[0].id == &"cancel", "a fresh connection replaces stale capacity guidance with current connecting status")
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
		print("NETWORK_SESSION_STATUS_PRESENTER_TEST_OK: 27 assertions")
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
