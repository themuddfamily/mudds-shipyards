extends SceneTree

const Presenter := preload("res://scripts/ui/surface_route_hazard_presenter.gd")
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presenter := Presenter.new()
	var snapshot := presenter.present_snapshot({
		"weather": "Ashfall front",
		"waypoints": [{"id": &"relay", "label": "North Relay", "distance_m": 148.5}],
		"hazard": {"state": &"storm", "exposure": 0.91, "recovery_available": true},
	})
	_check(snapshot.next_landmark == "North Relay" and is_equal_approx(snapshot.distance_m, 148.5), "next surface landmark and distance remain readable")
	_check(snapshot.exposure_marker == &"!! HIGH EXPOSURE !!" and snapshot.weather == "Ashfall front", "hazard and weather use text markers independent of colour")
	_check(snapshot.message.contains("HAZARD // HIGH EXPOSURE") and snapshot.message.contains("NEXT ACTION // LEAVE HAZARD ZONE") and snapshot.color_independent and not snapshot.flash_requested, "high exposure names one steady colour-independent next action")
	_check(snapshot.actions.size() == 3 and snapshot.actions[2].focusable and not snapshot.actions[2].input_authority, "recovery-enabled hazard state exposes a controller-focusable presentation intent only")
	_check(presenter.request_resume().accepted and presenter.request_abort().accepted and presenter.request_recovery().accepted and not presenter.request_recovery().recovery_authority, "route actions return external presentation intents without recovery authority")
	var safe := presenter.present_snapshot({"waypoints": [], "hazard": {"state": &"clear", "exposure": 0.0, "recovery_available": false}})
	_check(safe.next_landmark == "No waypoint queued" and safe.exposure_marker == &"[ SAFE WINDOW ]" and not presenter.request_recovery().accepted, "empty safe route fails closed without recovery authority")
	var detached_copy := presenter.get_snapshot()
	detached_copy["next_landmark"] = "forged"
	_check(presenter.get_snapshot().next_landmark == "No waypoint queued", "route presentation snapshot is detached")

	var fenced := Presenter.new()
	var recovery := fenced.present_snapshot(_authoritative_snapshot(
		91, 501, 701, 3, 8, 12, &"recovery_required", 0.86,
		"Return to the staging relay"
	))
	_check(
		recovery.accepted and recovery.attached
			and recovery.hazard_state == &"recovery_required"
			and is_equal_approx(recovery.exposure, 0.86)
			and recovery.message.contains("HAZARD // RECOVERY REQUIRED")
			and recovery.message.contains("NEXT ACTION // RETURN TO THE STAGING RELAY")
			and recovery.next_action == "RETURN TO THE STAGING RELAY"
			and not recovery.recovery_available
			and not fenced.request_recovery().accepted,
		"authoritative Ember hazard status publishes the recovery destination without offering an already-requested no-op action"
	)
	_check(
		not recovery.hazard_authority and not recovery.recovery_authority
			and not recovery.movement_authority and not recovery.boarding_authority
			and not recovery.reward_authority and not recovery.input_authority,
		"surface recovery presentation owns no gameplay or input authority"
	)
	var stale := fenced.present_snapshot(_authoritative_snapshot(
		91, 501, 701, 3, 8, 11, &"clear", 0.0, "Clear"
	))
	_check(
		stale.hazard_state == &"recovery_required" and stale.revision == 12,
		"an older revision cannot repaint the accepted hazard recovery status"
	)
	var actor_lost := _authoritative_snapshot(
		91, 0, 701, 3, 8, 13, &"clear", 0.0, "Clear"
	)
	var cleared := fenced.present_snapshot(actor_lost)
	_check(
		not cleared.accepted and not cleared.attached
			and cleared.hazard_state == &"unavailable" and cleared.actions.is_empty()
			and cleared.reason == &"source_identity_lost",
		"actor/session loss clears recovery copy and actions instead of retaining a stale warning"
	)
	var late_retired := fenced.present_snapshot(_authoritative_snapshot(
		91, 501, 701, 3, 8, 99, &"recovery_required", 0.99,
		"Return to the staging relay"
	))
	_check(
		late_retired.hazard_state == &"unavailable" and late_retired.actions.is_empty(),
		"a retired attachment cannot replay recovery status after actor loss"
	)
	var reused := fenced.present_snapshot(_authoritative_snapshot(
		91, 502, 702, 4, 9, 1, &"clear", 0.0, "Clear"
	))
	_check(
		reused.accepted and reused.attachment_generation == 4
			and reused.actor_instance_id == 502 and reused.session_instance_id == 702
			and reused.hazard_state == &"clear" and not reused.recovery_available
			and not fenced.request_recovery().accepted,
		"a newer attachment accepts its exact actor/session without inheriting prior recovery state"
	)
	var identity_reuse := fenced.present_snapshot(_authoritative_snapshot(
		91, 999, 702, 4, 9, 2, &"recovery_required", 0.9,
		"Return to the staging relay"
	))
	_check(
		not identity_reuse.accepted and not identity_reuse.attached
			and identity_reuse.reason == &"source_identity_mismatch",
		"same-attachment actor reuse fails closed and clears the presenter"
	)
	var fresh := fenced.present_snapshot(_authoritative_snapshot(
		91, 503, 703, 5, 10, 1, &"warning", 0.46,
		"Electrical discharge zone"
	))
	_check(fresh.accepted and fresh.hazard_state == &"warning" and fresh.message.contains("NEXT ACTION // MOVE CLEAR OF HAZARD"), "a fresh attachment restores warning guidance without replaying recovery copy")
	var detached := fenced.detach()
	var late_after_detach := fenced.present_snapshot(_authoritative_snapshot(
		91, 503, 703, 5, 10, 200, &"recovery_required", 1.0,
		"Return to the staging relay"
	))
	_check(
		not detached.attached and detached.actions.is_empty()
			and late_after_detach.hazard_state == &"unavailable"
			and not fenced.request_resume().accepted,
		"detach clears route actions and fences late snapshots from the retired attachment"
	)
	if _failures.is_empty():
		print("SURFACE_ROUTE_HAZARD_PRESENTER_TEST_OK: 16 assertions")
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _authoritative_snapshot(
		host_instance_id: int, actor_instance_id: int, session_instance_id: int,
		attachment_generation: int, generation: int, revision: int,
		hazard_state: StringName, exposure: float, status_text: String
	) -> Dictionary:
	return {
		"attached": true,
		"host_instance_id": host_instance_id,
		"actor_instance_id": actor_instance_id,
		"session_instance_id": session_instance_id,
		"attachment_generation": attachment_generation,
		"generation": generation,
		"revision": revision,
		"title": "EMBER SURFACE ROUTE",
		"waypoints": [{
			"id": &"ember_staging_relay",
			"label": "Ember Staging Relay",
			"distance_m": 64.0,
		}],
		"hazard": {
			"state": hazard_state,
			"hazard_id": &"ember_relay_arc",
			"title": "RELAY ARC EXPOSURE",
			"status_text": status_text,
			"recovery_id": &"ember_staging_relay",
			"exposure_unitless": exposure,
			"recovery_request": {
				"requested": hazard_state == &"recovery_required",
				"movement_mutation": false,
			},
			"authority": {
				"damage": false, "health": false, "movement": false,
				"recovery": false, "reward": false, "hud": false,
				"lifecycle": false,
			},
		},
		"presentation_only": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
