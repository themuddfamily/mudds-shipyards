extends SceneTree

class FakeProduction:
	extends RefCounted
	signal state_changed(snapshot: Dictionary)
	signal completion_handback_ready(receipt: Dictionary)
	var snapshot: Dictionary = {
		"generation": 4,
		"configured": true,
		"state_id": &"running",
		"identities": {},
		"planetary_surface": {
			"state": &"bound",
			"host_generation": 4,
			"attachment_generation": 2,
			"relay_survey_presentation": {
				"state": &"completed",
				"cue_mode": &"reward_confirmed",
			},
		},
	}
	var manifest: Dictionary = {
		"issued_generation": 8,
		"activity_id": &"ember_beacon_survey",
		"destination_id": &"mudds_shipyards",
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)
	func get_planetary_relay_survey_return_manifest_snapshot() -> Dictionary:
		return manifest.duplicate(true)

class FakeHost:
	extends RefCounted
	var snapshot: Dictionary = {
		"attached": true,
		"host_id": &"ember_surface_loop",
		"generation": 4,
		"attachment_generation": 2,
		"phase_id": &"on_foot",
		"identities": {"player_instance_id": 41, "ship_instance_id": 42},
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

const BindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var production := FakeProduction.new()
	var host := FakeHost.new()
	production.snapshot.identities = {
		"host_instance_id": host.get_instance_id(),
		"player_instance_id": 41,
		"ship_instance_id": 42,
	}
	var binding = BindingType.new()
	_check(
		bool(binding.attach(production, host, null, true).get("accepted", false)),
		"binding accepts one exact live Host/production identity tuple",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	_sync(production, host, 5, &"surface_outbound", 2)
	_check_no_stage(
		binding,
		"pre-on-foot surface outbound does not claim survey completion",
	)
	_sync(production, host, 6, &"on_foot", 2)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	var missing_attachment := _manifest_receipt(8, 2)
	(missing_attachment.manifest as Dictionary).erase("attachment_generation")
	_check_rejection(
		binding.apply_return_manifest_receipt(missing_attachment),
		&"receipt_attachment_generation_missing",
		"manifest receipt without attachment scope is rejected",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(99, 2)),
		&"foreign_receipt_activity_generation",
		"foreign activity generation cannot borrow the current attachment",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(8, 1)),
		&"stale_receipt_generation",
		"foreign attachment generation cannot enter the return status",
	)
	_check(
		bool(binding.apply_return_manifest_receipt(
			_manifest_receipt(8, 2), true
		).get("accepted", false)),
		"exact activity and attachment receipt is accepted",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	production.snapshot.identities.host_instance_id = host.get_instance_id() + 1
	production.state_changed.emit({})
	_check_cleared(binding, "HOST INSTANCE MISMATCH", "wrong Host ID fails closed")
	production.snapshot.identities.host_instance_id = host.get_instance_id()
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)
	production.snapshot.identities.player_instance_id = 99
	production.state_changed.emit({})
	_check_cleared(binding, "ACTOR IDENTITY MISMATCH", "wrong Player ID fails closed")
	production.snapshot.identities.player_instance_id = 41
	production.state_changed.emit({})
	production.snapshot.identities.ship_instance_id = 100
	production.state_changed.emit({})
	_check_cleared(binding, "ACTOR IDENTITY MISMATCH", "wrong ship ID fails closed")
	production.snapshot.identities.ship_instance_id = 42
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	host.snapshot.generation = 7
	production.state_changed.emit({})
	_check_cleared(
		binding, "HOST PRODUCTION GENERATION MISMATCH",
		"independently advanced Host generation fails closed",
	)
	_sync(production, host, 7, &"on_foot", 2)
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 1
	production.state_changed.emit({})
	_check_cleared(
		binding, "PLANETARY ATTACHMENT GENERATION MISMATCH",
		"production surface attachment must pair with the Host attachment",
	)
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 2
	production.state_changed.emit({})
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	# Reuse carries deliberately stale survey and manifest snapshots. The exact
	# source tuple is current, but no return stage may survive without a fresh,
	# attachment-scoped and newly issued receipt.
	_sync(production, host, 8, &"on_foot", 3)
	_check_no_stage(
		binding,
		"attachment reuse clears retained survey and manifest stage evidence",
	)
	_check(
		(binding.get_snapshot().last_result as Dictionary).is_empty(),
		"attachment reuse clears the retained receipt",
	)
	_check_rejection(
		binding.apply_return_manifest_receipt(_manifest_receipt(8, 3)),
		&"replayed_receipt_activity_generation",
		"reuse rejects a re-scoped copy of the prior activity receipt",
	)
	production.manifest.issued_generation = 9
	_check(
		bool(binding.apply_return_manifest_receipt(
			_manifest_receipt(9, 3), true
		).get("accepted", false)),
		"reuse accepts a newly issued exact receipt for the current attachment",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	_sync(production, host, 9, &"boarding", 3)
	_check_stage(
		binding, &"reboard", 2, "COMPLETE REBOARD",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_sync(production, host, 10, &"reboarded", 3)
	_check_stage(
		binding, &"reboard", 2, "TAKE OFF",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_sync(production, host, 11, &"takeoff", 3)
	_check_stage(
		binding, &"takeoff", 3, "BEGIN ASCENT",
		"REMAIN SEATED WHILE TAKEOFF STATUS RECOVERS",
	)
	_sync(production, host, 12, &"ascent", 3)
	_check_stage(
		binding, &"ascent", 4, "REACH ORBIT",
		"CONTINUE THE STEADY CLIMB IF GUIDANCE IS INTERRUPTED",
	)
	_sync(production, host, 13, &"orbit_return", 3)
	_check_stage(
		binding, &"orbit", 5, "COMPLETE RETURN HANDOFF",
		"HOLD ORBIT WHILE THE MUDDS HANDOFF RECOVERS",
	)
	var before_stale := binding.get_presenter_snapshot()
	_sync(production, host, 12, &"takeoff", 3)
	_check(
		binding.get_presenter_snapshot() == before_stale,
		"coherent but stale source generations cannot overwrite orbit status",
	)

	_sync(production, host, 14, &"completed", 3)
	_check_no_stage(
		binding,
		"unmatched completed phase cannot claim terminal Mudds return",
	)
	var completion := {
		"reason": &"runtime_ownership_returned",
		"host_id": &"ember_surface_loop",
		"generation": 14,
		"retired_attachment_generation": 3,
		"current_attachment_generation": 4,
		"player_instance_id": 41,
		"ship_instance_id": 42,
		"host_attached": false,
		"command_source_restored": true,
		"boarding_reservation_retained": true,
		"player_seated": true,
		"ship_piloted": true,
	}
	host.snapshot.attached = false
	host.snapshot.attachment_generation = 4
	production.snapshot.state_id = &"handoff_pending"
	production.snapshot.completion_handback_pending = true
	var unmatched_handback := completion.duplicate(true)
	unmatched_handback.player_instance_id = 99
	production.snapshot.completion_handback = unmatched_handback
	# The planetary composition retains the exact retired attachment until the
	# caller consumes this handback.
	(production.snapshot.planetary_surface as Dictionary).attachment_generation = 3
	production.state_changed.emit({})
	_check_cleared(
		binding, "PLANETARY ATTACHMENT GENERATION MISMATCH",
		"detached completed phase with an unmatched handback fails closed",
	)
	production.snapshot.completion_handback = completion.duplicate(true)
	production.state_changed.emit({})
	_check_stage(
		binding, &"mudds_return", 6, "RETURN TO MUDDS SHIPYARDS",
		"MUDDS SHIPYARDS REMAINS THE MANIFEST DESTINATION",
	)
	_check(
		not bool(binding.get_presenter_snapshot().attached)
			and bool(binding.get_presenter_snapshot().completion_observed),
		"only the exact stored handback exposes terminal Mudds return",
	)

	binding.detach()
	_check(
		not bool(binding.get_snapshot().attached)
			and binding.get_presenter_snapshot().is_empty(),
		"detach clears all status evidence",
	)
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _manifest_receipt(activity_generation: int, attachment_generation: int) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"activity_id": &"ember_beacon_survey",
			"activity_generation": activity_generation,
			"attachment_generation": attachment_generation,
			"destination_id": &"mudds_shipyards",
		},
	}.duplicate(true)

func _sync(
		production: FakeProduction, host: FakeHost, generation: int,
		phase: StringName, attachment_generation: int
	) -> void:
	host.snapshot.attached = true
	host.snapshot.generation = generation
	host.snapshot.attachment_generation = attachment_generation
	host.snapshot.phase_id = phase
	production.snapshot.generation = generation
	production.snapshot.state_id = &"running"
	production.snapshot.completion_handback_pending = false
	production.snapshot.completion_handback = {}
	var planetary := production.snapshot.planetary_surface as Dictionary
	planetary.host_generation = generation
	planetary.attachment_generation = attachment_generation
	production.state_changed.emit({})

func _check_stage(
		binding: RefCounted, stage: StringName, step: int,
		next_action: String, recovery: String
	) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	var status := view.get("return_status", {}) as Dictionary
	var action := view.get("next_action", {}) as Dictionary
	_check(
		status.get("stage", &"") == stage
			and int(status.get("step", 0)) == step
			and int(status.get("step_count", 0)) == 6
			and status.get("next_action", "") == next_action
			and status.get("recovery", "") == recovery,
		"%s has a stable numbered next-action and recovery meaning" % stage,
	)
	_check(
		view.text.contains("RETURN STEP  //  %d OF 6" % step)
			and view.text.contains("NEXT ACTION  //  " + next_action)
			and view.text.contains("RECOVERY  //  " + recovery)
			and bool(status.get("steady", false))
			and bool(status.get("color_independent", false))
			and bool(view.get("reduced_flash_safe", false))
			and not bool(view.get("flash_requested", true)),
		"%s remains readable without colour, motion, or flashing" % stage,
	)
	_check(
		not bool(action.get("input_authority", true))
			and not bool(action.get("travel_authority", true))
			and not bool(action.get("boarding_authority", true))
			and not bool(action.get("reward_authority", true))
			and not bool(view.get("input_authority", true))
			and not bool(view.get("travel_authority", true))
			and not bool(view.get("boarding_authority", true))
			and not bool(view.get("reward_authority", true)),
		"%s presentation cannot advance the return loop" % stage,
	)

func _check_no_stage(binding: RefCounted, message: String) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	_check(
		(view.get("return_status", {}) as Dictionary).is_empty()
			and not str(view.get("text", "")).contains("RETURN STEP  //"),
		message,
	)

func _check_cleared(binding: RefCounted, reason: String, message: String) -> void:
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	_check(
		view.get("state", &"") == &"rejected"
			and (view.get("return_status", {}) as Dictionary).is_empty()
			and str(view.get("text", "")).contains(reason),
		message,
	)

func _check_rejection(result: Dictionary, reason: StringName, message: String) -> void:
	_check(
		not bool(result.get("accepted", true))
			and StringName(result.get("reason", &"")) == reason,
		message,
	)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
