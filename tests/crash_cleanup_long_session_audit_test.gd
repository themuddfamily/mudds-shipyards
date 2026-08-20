extends SceneTree

const Audit := preload("res://scripts/recovery/crash_cleanup_long_session_audit.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_repeated_clean_cycles()
	_test_staged_and_pool_guards()
	_test_cleanup_generation_and_timing_guards()
	_test_growth_is_terminal()
	if _failures.is_empty():
		print("CRASH_CLEANUP_LONG_SESSION_AUDIT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("CRASH_CLEANUP_LONG_SESSION_AUDIT_TEST_FAIL: " + failure)
	quit(1)


func _test_repeated_clean_cycles() -> void:
	var audit := Audit.new()
	var baseline := _sample(20, 11, 0, 0, 2048)
	_check(
		bool(audit.begin_session("crash-cleanup-soak", baseline, {
			"max_cycles": 2,
			"max_recovery_seconds": 1.5,
		}).get("accepted", false)),
		"bounded crash cleanup audit accepts its baseline"
	)
	_check(
		bool(audit.begin_cycle(1, ["impact", "smoke", "debris"], _pool(6, 2)).get("accepted", false)),
		"first generation stages named effects against a fixed pool"
	)
	_check(
		bool(audit.record_cleanup(1, baseline, [], _pool(6, 0), 0, true, true).get("accepted", false)),
		"first generation cleanup releases effects, pooled nodes, callbacks, and authority"
	)
	_check(
		bool(audit.record_recovery(1, 2, 0.75, baseline, true).get("accepted", false)),
		"first generation recovers within the caller-provided arcade timing window"
	)
	_check(
		bool(audit.record_reentry(1, 2, true, &"stale_generation", true).get("accepted", false)),
		"re-entry rejects the retired generation and restores the current state"
	)
	_check(
		bool(audit.begin_cycle(3, ["impact", "smoke"], _pool(6, 1)).get("accepted", false)),
		"second generation remains monotonic after re-entry"
	)
	_check(
		bool(audit.record_cleanup(3, baseline, [], _pool(6, 0), 0, true, true).get("accepted", false))
			and bool(audit.record_recovery(3, 4, 1.5, baseline, true).get("accepted", false))
			and bool(audit.record_reentry(3, 4, true, &"stale_attachment_generation", true).get("accepted", false)),
		"second generation closes the same cleanup and generation-safe handoff"
	)
	var closed := audit.close_session()
	_check(
		bool(closed.get("accepted", false)) and bool(audit.audit().get("valid", false)),
		"only a fully detached repeated run becomes valid evidence"
	)
	var report := audit.audit()
	_check(
		int(report.get("cycles", 0)) == 2
			and int(report.get("last_source_generation", 0)) == 3
			and int(report.get("last_generation", 0)) == 4
			and is_equal_approx(float(report.get("last_recovery_seconds", -1.0)), 1.5),
		"report preserves cycle, generation, and recovery timing evidence"
	)
	_check(
		int(report.get("growth", {}).get("peak", {}).get("retained_bytes", -1)) == 0
			and int(report.get("pool_capacity", 0)) == 6,
		"repeated cleanup proves zero retained growth with a stable pool capacity"
	)
	var detached := audit.audit()
	(detached.get("growth", {}).get("baseline", {}) as Dictionary)["live_objects"] = -1
	_check(
		int(audit.audit().get("growth", {}).get("baseline", {}).get("live_objects", -1)) == 20,
		"audit reports are deeply detached from lifecycle state"
	)


func _test_staged_and_pool_guards() -> void:
	var no_effects := Audit.new()
	_check(bool(no_effects.begin_session("no-effects", _sample(0, 0, 0, 0, 0)).get("accepted", false)), "empty-effect fixture starts")
	_check(
		not bool(no_effects.begin_cycle(1, [], _pool(4, 1)).get("accepted", true))
			and no_effects.audit().get("reason", &"") == &"staged_effects_count_invalid",
		"a crash cycle cannot hide an unreported staged effect set"
	)
	var duplicate_effects := Audit.new()
	duplicate_effects.begin_session("duplicate-effects", _sample(0, 0, 0, 0, 0))
	_check(
		not bool(duplicate_effects.begin_cycle(1, ["impact", "impact"], _pool(4, 1)).get("accepted", true))
			and duplicate_effects.audit().get("reason", &"") == &"staged_effect_id_invalid",
		"duplicate staged effect identities fail closed"
	)
	var pool_accounting := Audit.new()
	pool_accounting.begin_session("bad-pool", _sample(0, 0, 0, 0, 0))
	_check(
		not bool(pool_accounting.begin_cycle(1, ["impact"], {"capacity": 4, "active": 2, "free": 1}).get("accepted", true))
			and pool_accounting.audit().get("reason", &"") == &"pool_accounting_invalid",
		"a pool whose active and free nodes do not cover capacity fails closed"
	)
	var no_active := Audit.new()
	no_active.begin_session("no-active", _sample(0, 0, 0, 0, 0))
	_check(
		not bool(no_active.begin_cycle(1, ["impact"], _pool(4, 0)).get("accepted", true))
			and no_active.audit().get("reason", &"") == &"pool_has_no_active_nodes",
		"a staged crash must account for at least one active pooled node"
	)


func _test_cleanup_generation_and_timing_guards() -> void:
	var leaked_effect := _started_audit("leaked-effect")
	leaked_effect.begin_cycle(1, ["impact"], _pool(4, 1))
	_check(
		not bool(leaked_effect.record_cleanup(1, _sample(0, 0, 0, 0, 0), ["impact"], _pool(4, 0), 0, true, true).get("accepted", true))
			and leaked_effect.audit().get("reason", &"") == &"staged_effects_retained",
		"cleanup rejects a staged effect that survives the destruction boundary"
	)
	var retained_pool := _started_audit("retained-pool")
	retained_pool.begin_cycle(1, ["impact"], _pool(4, 1))
	_check(
		not bool(retained_pool.record_cleanup(1, _sample(0, 0, 0, 0, 0), [], _pool(4, 1), 0, true, true).get("accepted", true))
			and retained_pool.audit().get("reason", &"") == &"pool_nodes_retained",
		"cleanup rejects an active pooled node retained after destruction"
	)
	var stale_generation := _started_audit("stale-generation")
	stale_generation.begin_cycle(4, ["impact"], _pool(4, 1))
	_check(
		not bool(stale_generation.record_cleanup(3, _sample(0, 0, 0, 0, 0), [], _pool(4, 0), 0, true, true).get("accepted", true))
			and stale_generation.audit().get("reason", &"") == &"cleanup_generation_mismatch",
		"cleanup cannot release a generation other than the destroyed craft"
	)
	var too_slow := _started_audit("too-slow")
	too_slow.begin_cycle(1, ["impact"], _pool(4, 1))
	too_slow.record_cleanup(1, _sample(0, 0, 0, 0, 0), [], _pool(4, 0), 0, true, true)
	_check(
		not bool(too_slow.record_recovery(1, 2, 3.01, _sample(0, 0, 0, 0, 0), true).get("accepted", true))
			and too_slow.audit().get("reason", &"") == &"recovery_time_exceeded",
		"recovery exceeding the configured short window fails closed"
	)
	var stale_reentry := _started_audit("stale-reentry")
	stale_reentry.begin_cycle(1, ["impact"], _pool(4, 1))
	stale_reentry.record_cleanup(1, _sample(0, 0, 0, 0, 0), [], _pool(4, 0), 0, true, true)
	stale_reentry.record_recovery(1, 2, 0.5, _sample(0, 0, 0, 0, 0), true)
	_check(
		not bool(stale_reentry.record_reentry(1, 2, false, &"stale_generation", true).get("accepted", true))
			and stale_reentry.audit().get("reason", &"") == &"stale_reentry_accepted",
		"re-entry fails closed when a stale-generation request is accepted"
	)


func _test_growth_is_terminal() -> void:
	var growth := _started_audit("growth")
	growth.begin_cycle(1, ["impact"], _pool(4, 1))
	_check(
		not bool(growth.record_cleanup(1, _sample(0, 1, 0, 0, 0), [], _pool(4, 0), 0, true, true).get("accepted", true))
			and growth.audit().get("reason", &"") == &"live_resources_growth_exceeded",
		"a resource leak during cleanup fails the complete audit"
	)
	_check(
		not bool(growth.begin_cycle(2, ["impact"], _pool(4, 1)).get("accepted", true))
			and growth.audit().get("reason", &"") == &"live_resources_growth_exceeded",
		"later cycles cannot erase a terminal long-session growth breach"
	)


func _started_audit(id: String) -> RefCounted:
	var audit := Audit.new()
	audit.begin_session(id, _sample(0, 0, 0, 0, 0))
	return audit


func _pool(capacity: int, active: int) -> Dictionary:
	return {"capacity": capacity, "active": active, "free": capacity - active}


func _sample(live_objects: int, live_resources: int, pending_work: int, orphan_count: int, retained_bytes: int) -> Dictionary:
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
