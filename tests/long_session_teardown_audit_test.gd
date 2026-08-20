extends SceneTree

const Audit := preload("res://scripts/persistence/long_session_teardown_audit.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_balanced_reentry_cycles()
	_test_growth_breach_is_terminal()
	_test_generation_and_shape_guards()
	_test_cycle_limit_and_detached_audit()
	if not _failures.is_empty():
		printerr("long_session_teardown_audit_test failures: ", "; ".join(_failures))
		quit(1)
	else:
		print("long_session_teardown_audit_test: %d assertions passed" % _assertions)
		quit(0)


func _test_balanced_reentry_cycles() -> void:
	var audit := Audit.new()
	var baseline := _sample(12, 8, 0, 0, 1024)
	_check(
		bool(audit.begin_session("long-session-a", baseline, {
			"max_cycles": 4,
			"max_live_objects_growth": 1,
			"max_live_resources_growth": 1,
			"max_pending_work_growth": 1,
			"max_retained_bytes_growth": 128,
		}).accepted),
		"a bounded audit accepts a primitive baseline and explicit growth limits"
	)
	_check(
		bool(audit.record_attach(1, _sample(13, 9, 1, 0, 1100)).accepted),
		"first attach records a bounded transient resource increase"
	)
	_check(
		bool(audit.record_detach(1, _sample(12, 8, 0, 0, 1024)).accepted),
		"first detach returns to the baseline without retaining growth"
	)
	_check(
		bool(audit.record_attach(2, _sample(13, 9, 1, 0, 1100)).accepted)
			and bool(audit.record_detach(2, _sample(12, 8, 0, 0, 1024)).accepted),
		"a second attach/detach generation remains sequential and bounded"
	)
	var closed := audit.close_session()
	_check(
		bool(closed.accepted) and closed.reason == &"closed"
			and audit.audit().valid,
		"only a balanced detached run becomes valid release evidence"
	)
	var report := audit.audit()
	_check(
		int(report.counters.attach_count) == 2
			and int(report.counters.detach_count) == 2
			and int(report.counters.attachment_generation) == 2,
		"audit reports exact attach/detach and generation counters"
	)
	_check(
		int(report.growth.peak.live_resources) == 1
			and int(report.growth.peak.retained_bytes) == 76,
		"audit preserves the largest observed growth over repeated cycles"
	)
	var detached_report := audit.audit()
	(detached_report.growth.baseline as Dictionary)["live_objects"] = -1
	_check(
		int(audit.audit().growth.baseline.live_objects) == 12,
		"reported evidence is deeply detached from audit state"
	)


func _test_growth_breach_is_terminal() -> void:
	var audit := Audit.new()
	_check(
		bool(audit.begin_session("growth-breach", _sample(20, 4, 0, 0, 400)).accepted),
		"growth breach fixture starts cleanly"
	)
	var breach := audit.record_attach(1, _sample(21, 4, 0, 0, 400))
	_check(
		not bool(breach.accepted)
			and breach.reason == &"live_objects_growth_exceeded"
			and audit.audit().state == Audit.STATE_FAILED,
		"live-object growth above the zero threshold fails closed"
	)
	var recovery_attempt := audit.record_attach(1, _sample(20, 4, 0, 0, 400))
	_check(
		not bool(recovery_attempt.accepted)
			and recovery_attempt.reason == &"audit_failed",
		"a later clean sample cannot erase a terminal growth breach"
	)
	_check(
		not bool(audit.close_session().accepted)
			and audit.audit().reason == &"live_objects_growth_exceeded",
		"failed long-session evidence cannot be closed as valid"
	)


func _test_generation_and_shape_guards() -> void:
	var malformed := Audit.new()
	_check(
		not bool(malformed.begin_session("bad-shape", {
			"live_objects": 1,
			"live_resources": 1,
			"pending_work": 0,
			"orphan_count": 0,
		}).accepted)
			and malformed.audit().state == Audit.STATE_IDLE,
		"samples missing a metric are rejected without starting an audit"
	)
	var invalid_limits := Audit.new()
	_check(
		not bool(invalid_limits.begin_session("bad-limits", _sample(1, 1, 0, 0, 1), {
			"unknown_growth": 1,
		}).accepted)
			and invalid_limits.audit().state == Audit.STATE_IDLE,
		"unknown limit fields fail closed before lifecycle state changes"
	)
	var generations := Audit.new()
	_check(bool(generations.begin_session("generation-guards", _sample(1, 1, 0, 0, 1)).accepted), "generation fixture starts")
	_check(
		not bool(generations.record_attach(2, _sample(1, 1, 0, 0, 1)).accepted)
			and generations.audit().reason == &"attachment_generation_invalid",
		"skipping an attachment generation is rejected"
	)
	var wrong_detach := Audit.new()
	_check(bool(wrong_detach.begin_session("detach-guards", _sample(1, 1, 0, 0, 1)).accepted), "detach fixture starts")
	_check(bool(wrong_detach.record_attach(1, _sample(1, 1, 0, 0, 1)).accepted), "detach fixture attaches")
	_check(
		not bool(wrong_detach.record_detach(2, _sample(1, 1, 0, 0, 1)).accepted)
			and wrong_detach.audit().reason == &"attachment_generation_mismatch",
		"detaching a different generation fails closed"
	)


func _test_cycle_limit_and_detached_audit() -> void:
	var audit := Audit.new()
	_check(
		bool(audit.begin_session("cycle-limit", _sample(3, 3, 0, 0, 3), {"max_cycles": 1}).accepted),
		"cycle-limit fixture starts with one permitted cycle"
	)
	_check(bool(audit.record_attach(1, _sample(3, 3, 0, 0, 3)).accepted), "cycle-limit fixture attaches once")
	_check(bool(audit.record_detach(1, _sample(3, 3, 0, 0, 3)).accepted), "cycle-limit fixture detaches once")
	_check(
		not bool(audit.record_attach(2, _sample(3, 3, 0, 0, 3)).accepted)
			and audit.audit().reason == &"cycle_limit_exceeded",
		"the configured cycle ceiling fails closed before a second attach"
	)
	var open := Audit.new()
	_check(bool(open.begin_session("open-session", _sample(0, 0, 0, 0, 0)).accepted), "open-session fixture starts")
	_check(bool(open.record_attach(1, _sample(0, 0, 0, 0, 0)).accepted), "open-session fixture attaches")
	_check(
		not bool(open.close_session().accepted)
			and open.audit().reason == &"session_still_attached",
		"close fails closed while an attachment remains live"
	)


func _sample(
	live_objects: int,
	live_resources: int,
	pending_work: int,
	orphan_count: int,
	retained_bytes: int
) -> Dictionary:
	return {
		"live_objects": live_objects,
		"live_resources": live_resources,
		"pending_work": pending_work,
		"orphan_count": orphan_count,
		"retained_bytes": retained_bytes,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
