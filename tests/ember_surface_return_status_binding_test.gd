extends SceneTree

class FakeProduction:
	extends RefCounted
	signal state_changed(snapshot: Dictionary)
	signal completion_handback_ready(receipt: Dictionary)
	var snapshot: Dictionary = {
		"generation": 3,
		"configured": true,
		"planetary_surface": {
			"relay_survey_presentation": {
				"state": &"completed",
				"cue_mode": &"reward_confirmed",
			},
		},
	}
	var manifest: Dictionary = {
		"issued_generation": 8,
		"destination_id": &"mudds_shipyards",
	}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)
	func get_planetary_relay_survey_return_manifest_snapshot() -> Dictionary:
		return manifest.duplicate(true)

class FakeHost:
	extends RefCounted
	var snapshot: Dictionary = {
		"attached": true,
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
	var binding = BindingType.new()
	_check(
		bool(binding.attach(production, host, null, true).get("accepted", false)),
		"binding attaches authoritative Ember snapshot sources",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)
	var manifest := binding.apply_return_manifest_receipt({
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"attachment_generation": 2,
			"destination_id": &"mudds_shipyards",
		},
	}, true)
	_check(
		bool(manifest.get("accepted", false))
			and binding.get_presenter_snapshot().state == &"return_manifest",
		"current manifest receipt remains display evidence without gaining authority",
	)
	_check_stage(
		binding, &"survey_complete", 1, "RETURN TO YOUR SHIP",
		"FOLLOW THE STATIC RETURN ROUTE",
	)

	_set_phase(production, host, 5, &"boarding")
	_check_stage(
		binding, &"reboard", 2, "COMPLETE REBOARD",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_set_phase(production, host, 6, &"reboarded")
	_check_stage(
		binding, &"reboard", 2, "TAKE OFF",
		"RE-ENTER THE LANDING PAD BOARDING AREA IF INTERRUPTED",
	)
	_set_phase(production, host, 7, &"takeoff")
	_check_stage(
		binding, &"takeoff", 3, "BEGIN ASCENT",
		"REMAIN SEATED WHILE TAKEOFF STATUS RECOVERS",
	)
	_set_phase(production, host, 8, &"ascent")
	_check_stage(
		binding, &"ascent", 4, "REACH ORBIT",
		"CONTINUE THE STEADY CLIMB IF GUIDANCE IS INTERRUPTED",
	)
	_set_phase(production, host, 9, &"orbit_return")
	_check_stage(
		binding, &"orbit", 5, "COMPLETE RETURN HANDOFF",
		"HOLD ORBIT WHILE THE MUDDS HANDOFF RECOVERS",
	)
	host.snapshot.attached = false
	host.snapshot.attachment_generation = 3
	production.snapshot.state_id = &"handoff_pending"
	production.snapshot.completion_handback_pending = true
	production.snapshot.completion_handback = {
		"reason": &"runtime_ownership_returned",
		"generation": 10,
		"current_attachment_generation": 3,
		"player_instance_id": 41,
		"ship_instance_id": 42,
	}
	_set_phase(production, host, 10, &"completed")
	_check_stage(
		binding, &"mudds_return", 6, "RETURN TO MUDDS SHIPYARDS",
		"MUDDS SHIPYARDS REMAINS THE MANIFEST DESTINATION",
	)
	_check(
		not bool(binding.get_presenter_snapshot().attached)
			and bool(binding.get_presenter_snapshot().completion_observed),
		"authenticated terminal detach remains readable as the Mudds return step",
	)
	var before_stale := binding.get_presenter_snapshot()
	host.snapshot.generation = 9
	host.snapshot.phase_id = &"on_foot"
	production.state_changed.emit({})
	_check(
		binding.get_presenter_snapshot() == before_stale,
		"stale host generation cannot be masked by the production generation",
	)
	host.snapshot.generation = 11
	production.snapshot.generation = 2
	production.state_changed.emit({})
	_check(
		binding.get_presenter_snapshot() == before_stale,
		"stale production generation cannot overwrite the return status",
	)

	production.snapshot.generation = 4
	host.snapshot.attached = true
	host.snapshot.attachment_generation = 4
	host.snapshot.phase_id = &"takeoff"
	production.state_changed.emit({})
	_check_stage(
		binding, &"takeoff", 3, "BEGIN ASCENT",
		"REMAIN SEATED WHILE TAKEOFF STATUS RECOVERS",
	)
	_check(
		(binding.get_snapshot().last_result as Dictionary).is_empty()
			and not binding.get_presenter_snapshot().text.contains("RETURN MANIFEST READY"),
		"attachment reuse clears prior-session receipt semantics",
	)
	var stale_receipt := binding.apply_return_manifest_receipt({
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"attachment_generation": 2,
			"destination_id": &"mudds_shipyards",
		},
	})
	_check(
		not bool(stale_receipt.get("accepted", true))
			and stale_receipt.reason == &"stale_receipt_generation",
		"receipt from the retired attachment is rejected",
	)

	host.snapshot.generation = 12
	host.snapshot.identities.player_instance_id = 0
	production.state_changed.emit({})
	var lost := binding.get_presenter_snapshot()
	_check(
		lost.state == &"rejected" and not bool(lost.attached)
			and lost.text.contains("ACTOR LOST")
			and lost.text.contains("WAIT FOR CURRENT ACTOR AND SESSION STATUS"),
		"actor loss clears the old action and shows a steady recovery status",
	)
	host.snapshot.generation = 13
	host.snapshot.identities.player_instance_id = 43
	host.snapshot.attached = false
	production.state_changed.emit({})
	_check(
		binding.get_presenter_snapshot().text.contains("SESSION DETACHED"),
		"session detach cannot leave the previous return action visible",
	)

	binding.detach()
	_check(
		not bool(binding.get_snapshot().attached)
			and binding.get_presenter_snapshot().is_empty(),
		"explicit detach clears retained presentation state",
	)
	host.snapshot = {
		"attached": true,
		"generation": 14,
		"attachment_generation": 5,
		"phase_id": &"orbit_return",
		"identities": {"player_instance_id": 43, "ship_instance_id": 44},
	}
	production.snapshot.generation = 5
	production.state_changed.emit({})
	_check(
		binding.get_presenter_snapshot().is_empty(),
		"detached binding ignores future source updates",
	)
	_check(
		bool(binding.attach(production, host, null, false).get("accepted", false)),
		"fresh actor/session attachment can re-enter the status binding",
	)
	_check_stage(
		binding, &"orbit", 5, "COMPLETE RETURN HANDOFF",
		"HOLD ORBIT WHILE THE MUDDS HANDOFF RECOVERS",
	)
	binding.detach()

	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _set_phase(
		production: FakeProduction, host: FakeHost, generation: int,
		phase: StringName
	) -> void:
	host.snapshot.generation = generation
	host.snapshot.phase_id = phase
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

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
