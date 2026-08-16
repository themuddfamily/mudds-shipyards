extends SceneTree

## Adversarial contract for the presentation-only caption queue. No HUD,
## GameFlow, audio, gameplay, activity or reward owner participates.

const EventScript := preload("res://scripts/ui/caption_presentation_event.gd")
const ServiceScript := preload("res://scripts/ui/caption_presentation_service.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_validation_and_detached_snapshots()
	_test_priority_overflow_and_duplicates()
	_test_signal_post_commit_and_reentry()
	_test_physics_timing_at_three_rates()
	_test_enable_disable_reduced_flash_and_reset()
	_finish()


func _test_validation_and_detached_snapshots() -> void:
	var service := ServiceScript.new() as CaptionPresentationService
	var valid := _event(&"radio.arrival-01", 2.0, 40, "Controller", "Docking corridor is clear.", CaptionPresentationEvent.Category.RADIO)
	_check(valid.is_valid(), "typed caption accepts bounded stable identity, category, speaker, text, duration and priority")
	_check(service.enqueue(valid).reason == &"presenting", "first valid event commits as the active caption")
	valid.text = "caller mutation"
	valid.speaker = "mutated"
	var detached := service.get_state_snapshot()
	_check(
		str((detached.active_caption as Dictionary).text) == "Docking corridor is clear."
		and str((detached.active_caption as Dictionary).speaker) == "Controller",
		"enqueue copies validated scalar fields instead of retaining caller mutation authority"
	)
	(detached.active_caption as Dictionary)["text"] = "snapshot mutation"
	(detached.pending_captions as Array).append({"stable_id": &"forged"})
	_check(
		str(service.get_state_snapshot().active_caption.text) == "Docking corridor is clear."
		and int(service.get_state_snapshot().pending_caption_count) == 0,
		"nested state snapshots are deeply detached from the live service"
	)
	var presentation := service.get_presentation_snapshot()
	(presentation.caption as Dictionary)["speaker"] = "forged"
	_check(str(service.get_presentation_snapshot().caption.speaker) == "Controller", "consumer presentation snapshots are also deeply detached")
	var boundary_service := ServiceScript.new() as CaptionPresentationService
	var upper_boundary := _event(
		StringName("i".repeat(CaptionPresentationEvent.MAX_ID_LENGTH)),
		CaptionPresentationEvent.MAX_DURATION_PHYSICS_SECONDS,
		CaptionPresentationEvent.MAX_PRIORITY,
		"s".repeat(CaptionPresentationEvent.MAX_SPEAKER_LENGTH),
		"t".repeat(CaptionPresentationEvent.MAX_TEXT_LENGTH),
		CaptionPresentationEvent.Category.SYSTEM
	)
	var lower_boundary := _event(
		&"minimums",
		CaptionPresentationEvent.MIN_DURATION_PHYSICS_SECONDS,
		CaptionPresentationEvent.MIN_PRIORITY
	)
	_check(
		boundary_service.enqueue(upper_boundary).accepted
		and boundary_service.enqueue(lower_boundary).accepted,
		"exact upper and lower field limits remain accepted"
	)

	var invalid_category := _event(&"bad_category", 1.0, 1)
	invalid_category.category = 999 as CaptionPresentationEvent.Category
	var invalids: Array[CaptionPresentationEvent] = [
		_event(&"Bad ID", 1.0, 1),
		_event(&"", 1.0, 1),
		_event(StringName("a".repeat(CaptionPresentationEvent.MAX_ID_LENGTH + 1)), 1.0, 1),
		invalid_category,
		_event(&"bad_speaker", 1.0, 1, "", "Text"),
		_event(&"long_speaker", 1.0, 1, "s".repeat(CaptionPresentationEvent.MAX_SPEAKER_LENGTH + 1), "Text"),
		_event(&"bad_text", 1.0, 1, "Speaker", " "),
		_event(&"long_text", 1.0, 1, "Speaker", "x".repeat(CaptionPresentationEvent.MAX_TEXT_LENGTH + 1)),
		_event(&"short_duration", CaptionPresentationEvent.MIN_DURATION_PHYSICS_SECONDS - 0.01, 1),
		_event(&"long_duration", CaptionPresentationEvent.MAX_DURATION_PHYSICS_SECONDS + 0.01, 1),
		_event(&"nan_duration", NAN, 1),
		_event(&"negative_priority", 1.0, CaptionPresentationEvent.MIN_PRIORITY - 1),
		_event(&"bad_priority", 1.0, CaptionPresentationEvent.MAX_PRIORITY + 1),
	]
	var rejected_without_mutation := true
	var before := service.get_state_snapshot()
	for event in invalids:
		var result := service.enqueue(event)
		rejected_without_mutation = rejected_without_mutation and not bool(result.accepted) and result.reason == &"invalid_event"
	_check(rejected_without_mutation and service.get_state_snapshot() == before, "all explicit id/text/duration/priority limit violations fail without mutation")
	_check(service.enqueue(null).reason == &"invalid_event", "null event input fails closed")
	var audit_first := service.audit()
	var audit_second := service.audit()
	_check(
		bool(audit_first.valid)
		and audit_first == audit_second
		and int(audit_first.limits.maximum_stored_captions) == 8
		and int(audit_first.limits.maximum_dedupe_ids) == 1024
		and not bool(audit_first.gameplay_authority)
		and not bool(audit_first.audio_authority)
		and not bool(audit_first.reward_authority),
		"audit is deterministic, freezes every public bound and grants no adjacent authority"
	)
	(audit_first.state as Dictionary)["revision"] = -500
	_check(int(service.audit().state.revision) >= 1, "nested audit data is detached from live revision state")


func _test_priority_overflow_and_duplicates() -> void:
	var service := ServiceScript.new() as CaptionPresentationService
	_check(service.enqueue(_event(&"active", 5.0, 0)).accepted, "overflow fixture establishes a non-preemptive active caption")
	var priorities := [10, 10, 20, 30, 40, 50, 60]
	for index in priorities.size():
		_check(
			service.enqueue(_event(StringName("queued_%02d" % index), 1.0, priorities[index])).accepted,
			"bounded queue accepts slot %d" % (index + 2)
		)
	var full := service.get_state_snapshot()
	_check(int(full.stored_caption_count) == 8 and int(full.pending_caption_count) == 7, "capacity is exactly eight stored captions including active")
	_check(
		service.enqueue(_event(&"equal_floor", 1.0, 10)).reason == &"queue_full"
		and service.get_state_snapshot() == full,
		"equal-to-lowest priority cannot churn a full queue"
	)
	var replacement := service.enqueue(_event(&"urgent", 1.0, 70))
	var after := service.get_state_snapshot()
	var pending_ids := _pending_ids(after)
	_check(
		replacement.reason == &"replaced_lower_priority"
		and replacement.replaced_stable_id == &"queued_01"
		and int(after.stored_caption_count) == 8
		and pending_ids == PackedStringArray(["urgent", "queued_06", "queued_05", "queued_04", "queued_03", "queued_02", "queued_00"]),
		"strictly higher overflow replaces the newest lowest-priority pending item and preserves deterministic order"
	)
	_check(StringName(after.active_caption.stable_id) == &"active", "overflow and priority never preempt the active caption")
	var before_duplicates := service.get_state_snapshot()
	_check(
		service.enqueue(_event(&"active", 1.0, 100)).reason == &"duplicate_event_id"
		and service.enqueue(_event(&"queued_01", 1.0, 100)).reason == &"duplicate_event_id"
		and service.get_state_snapshot() == before_duplicates,
		"accepted active and overflow-evicted IDs both reject replay without state change"
	)
	_check(
		int(after.dedupe_id_count) == 9
		and int(after.accepted_event_count) == 9
		and int(after.replaced_event_count) == 1,
		"bounded replay ledger retains all accepted IDs, including the replaced caption"
	)
	var ledger_service := ServiceScript.new() as CaptionPresentationService
	var ledger_filled := true
	for index in CaptionPresentationService.MAX_DEDUPE_ID_COUNT:
		ledger_filled = ledger_filled and bool(
			ledger_service.enqueue(_event(StringName("ledger_%04d" % index), 0.1, 1)).accepted
		)
		ledger_service.advance_physics(0.1)
	var ledger_full_state := ledger_service.get_state_snapshot()
	_check(
		ledger_filled
		and int(ledger_full_state.dedupe_id_count) == CaptionPresentationService.MAX_DEDUPE_ID_COUNT
		and int(ledger_full_state.stored_caption_count) == 0,
		"accepted-ID replay ledger reaches its exact 1,024-entry bound without retaining expired captions"
	)
	_check(
		ledger_service.enqueue(_event(&"ledger_overflow", 0.1, 100)).reason == &"dedupe_ledger_full"
		and ledger_service.enqueue(_event(&"ledger_0000", 0.1, 100)).reason == &"duplicate_event_id"
		and ledger_service.get_state_snapshot() == ledger_full_state,
		"full replay ledger rejects unique growth, preserves duplicate classification and never evicts protection"
	)


func _test_signal_post_commit_and_reentry() -> void:
	var service := ServiceScript.new() as CaptionPresentationService
	var probe := {
		"signal_count": 0,
		"post_commit": false,
		"enqueue_reason": &"",
		"advance_reason": &"",
		"flags_reason": &"",
		"reset_reason": &"",
	}
	service.state_committed.connect(func(reason: StringName, snapshot: Dictionary) -> void:
		probe["signal_count"] = int(probe.signal_count) + 1
		probe["post_commit"] = (
			reason == &"presenting"
			and snapshot == service.get_state_snapshot()
			and int(snapshot.revision) == 1
			and StringName(snapshot.active_caption.stable_id) == &"signal_origin"
		)
		probe["enqueue_reason"] = service.enqueue(_event(&"reentrant_enqueue", 1.0, 99)).reason
		probe["advance_reason"] = service.advance_physics(0.25).reason
		probe["flags_reason"] = service.set_presentation_flags(false, true).reason
		probe["reset_reason"] = service.reset().reason
		(snapshot.active_caption as Dictionary)["text"] = "observer mutation"
	, CONNECT_ONE_SHOT)
	var result := service.enqueue(_event(&"signal_origin", 1.0, 10, "Pilot", "Signal state."))
	_check(bool(result.accepted) and bool(probe.post_commit), "commit signal fires only after the complete active state and revision are observable")
	_check(
		probe.enqueue_reason == &"reentrant_call"
		and probe.advance_reason == &"reentrant_call"
		and probe.flags_reason == &"reentrant_call"
		and probe.reset_reason == &"reentrant_call",
		"every mutation entry point rejects signal reentry"
	)
	_check(
		int(probe.signal_count) == 1
		and int(service.get_state_snapshot().stored_caption_count) == 1
		and str(service.get_state_snapshot().active_caption.text) == "Signal state.",
		"reentrant calls and observer snapshot mutation produce no nested signal or partial state"
	)
	var before_zero := service.get_state_snapshot()
	_check(service.advance_physics(0.0).reason == &"no_delta" and service.get_state_snapshot() == before_zero and int(probe.signal_count) == 1, "zero physics delta freezes state and emits no commit signal")


func _test_physics_timing_at_three_rates() -> void:
	var terminal_snapshots: Array[Dictionary] = []
	for rate in [30, 60, 120]:
		var service := ServiceScript.new() as CaptionPresentationService
		service.enqueue(_event(&"one_second", 1.0, 10))
		service.enqueue(_event(&"half_second", 0.5, 10))
		var delta := 1.0 / float(rate)
		for _step in rate:
			service.advance_physics(delta)
		var boundary := service.get_state_snapshot()
		_check(
			StringName(boundary.active_caption.stable_id) == &"half_second"
			and is_equal_approx(float(boundary.active_caption.remaining_physics_seconds), 0.5)
			and int(boundary.expired_event_count) == 1,
			"%d Hz expires the one-second caption exactly on caller physics time" % rate
		)
		for _step in rate / 2:
			service.advance_physics(delta)
		var terminal := service.get_state_snapshot()
		terminal_snapshots.append(_timing_projection(terminal))
		_check(
			int(terminal.stored_caption_count) == 0
			and int(terminal.expired_event_count) == 2,
			"%d Hz expires the second caption at the same 1.5-second boundary" % rate
		)
	_check(
		terminal_snapshots[0] == terminal_snapshots[1]
		and terminal_snapshots[1] == terminal_snapshots[2],
		"30/60/120 Hz produce identical terminal queue and expiration state"
	)
	var service := ServiceScript.new() as CaptionPresentationService
	service.enqueue(_event(&"large_delta_a", 0.25, 1))
	service.enqueue(_event(&"large_delta_b", 0.25, 1))
	var crossed := service.advance_physics(1.0)
	_check(
		(crossed.expired_stable_ids as PackedStringArray) == PackedStringArray(["large_delta_a", "large_delta_b"])
		and is_equal_approx(float(crossed.unused_delta_seconds), 0.5),
		"one caller physics delta deterministically expires multiple captions and reports unused idle time"
	)
	var invalid_before := service.get_state_snapshot()
	_check(
		service.advance_physics(-0.1).reason == &"invalid_delta"
		and service.advance_physics(NAN).reason == &"invalid_delta"
		and service.get_state_snapshot() == invalid_before,
		"negative and non-finite physics delta reject without time mutation"
	)


func _test_enable_disable_reduced_flash_and_reset() -> void:
	var service := ServiceScript.new() as CaptionPresentationService
	service.enqueue(_event(&"accessibility", 1.0, 10, "System", "Accessibility state."))
	var revision_before := int(service.get_state_snapshot().revision)
	_check(
		service.set_presentation_flags(false, true).reason == &"presentation_flags_changed"
		and not bool(service.get_presentation_snapshot().visible)
		and service.get_presentation_snapshot().transition_policy == &"steady_no_flash"
		and int(service.get_state_snapshot().stored_caption_count) == 1,
		"captions-disabled hides presentation and reduced-flash publishes a steady policy without discarding timing state"
	)
	var unchanged := service.get_state_snapshot()
	_check(
		service.set_presentation_flags(false, true).reason == &"unchanged"
		and service.get_state_snapshot() == unchanged,
		"reapplying identical presentation flags is a signal-free no-op"
	)
	service.advance_physics(0.75)
	_check(
		is_equal_approx(float(service.get_state_snapshot().active_caption.remaining_physics_seconds), 0.25)
		and not bool(service.get_presentation_snapshot().visible),
		"disabled captions continue expiring on caller physics time rather than pausing or replaying"
	)
	service.set_presentation_flags(true, false)
	_check(
		bool(service.get_presentation_snapshot().visible)
		and service.get_presentation_snapshot().transition_policy == &"consumer_standard"
		and is_equal_approx(float(service.get_presentation_snapshot().caption.remaining_physics_seconds), 0.25),
		"reenabling reveals only the live remainder and restores the standard consumer transition hint"
	)
	_check(int(service.get_state_snapshot().revision) > revision_before, "flag and physics commits monotonically advance revision")
	service.set_presentation_flags(false, true)
	var generation_before := int(service.get_state_snapshot().generation)
	var reset := service.reset()
	var reset_state := service.get_state_snapshot()
	_check(
		bool(reset.accepted)
		and int(reset_state.generation) == generation_before + 1
		and int(reset_state.stored_caption_count) == 0
		and int(reset_state.dedupe_id_count) == 0
		and not bool(reset_state.captions_enabled)
		and bool(reset_state.reduced_flash),
		"reset clears content and replay state in a new generation while preserving accessibility flags"
	)
	_check(service.enqueue(_event(&"accessibility", 0.5, 10)).accepted, "a stable ID may be accepted again only after explicit generation reset")
	service.advance_physics(0.5)
	_check(int(service.get_state_snapshot().stored_caption_count) == 0, "post-reset re-entry runs a fresh caption lifetime without stale queue state")


func _event(
		stable_id: StringName,
		duration: float,
		priority: int,
		speaker: String = "Speaker",
		text: String = "Caption text.",
		category: CaptionPresentationEvent.Category = CaptionPresentationEvent.Category.DIALOGUE
	) -> CaptionPresentationEvent:
	return EventScript.new(stable_id, category, speaker, text, duration, priority) as CaptionPresentationEvent


func _pending_ids(snapshot: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for pending in snapshot.pending_captions as Array:
		result.append(str((pending as Dictionary).stable_id))
	return result


func _timing_projection(snapshot: Dictionary) -> Dictionary:
	return {
		"active_caption": snapshot.active_caption,
		"pending_captions": snapshot.pending_captions,
		"stored_caption_count": snapshot.stored_caption_count,
		"expired_event_count": snapshot.expired_event_count,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAPTION_PRESENTATION_SERVICE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("CAPTION_PRESENTATION_SERVICE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
