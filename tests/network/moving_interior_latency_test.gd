extends SceneTree

## Focused latency/stability coverage for the moving-interior network slice.
## This test is intentionally data-only: no scene, physics body, renderer,
## multiplayer peer, or production authority is instantiated.

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const Validator := preload("res://scripts/network/moving_interior_latency_validator.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_bounded_latency_loss_and_frame_motion()
	_test_rejection_and_local_instability()
	_test_audit_and_detachment()
	if _failures.is_empty():
		print("OK: moving interior latency stability (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_bounded_latency_loss_and_frame_motion() -> void:
	var trace: Array = []
	var sent_count := 100
	for index in 100:
		var tick := 100 + index
		# Two omitted packets model exactly 2% loss. A modest deterministic
		# latency wobble stays below the 20 ms jitter budget.
		if tick == 130 or tick == 160:
			continue
		var local_origin := Vector3(float(index) * 0.04, 1.0, -2.0)
		var snapshot := Relationship.create(
			tick,
			&"pilot_7",
			1,
			&"jovian_frame",
			3,
			Transform3D(Basis.IDENTITY, local_origin),
			Vector3(2.4, 0.0, 0.0)
		).get_snapshot()
		var send_time := float(tick - 100) / 60.0
		var jitter := 0.006 if index % 2 == 0 else -0.006
		trace.append({
			"snapshot": snapshot,
			"arrival_time_seconds": send_time + 0.100 + jitter,
			# The interior translates 18 m per packet. This must not count as
			# occupant instability because the pose is frame-local.
			"frame_world_transform": Transform3D(
				Basis.IDENTITY,
				Vector3(float(index) * 18.0, 0.0, 0.0)
			),
		})
	var report := Validator.new().validate_trace(trace, sent_count, {
		"authority_peer_id": 42,
		"origin_server_tick": 100,
		"max_latency_seconds": 0.100 + 0.006,
		"max_jitter_seconds": 0.020,
		"max_loss_ratio": 0.02,
	})
	var metrics := report.get("metrics", {}) as Dictionary
	_check(
		bool(report.accepted)
		and bool(report.stable)
		and int(metrics.get("delivered_packet_count", 0)) == 98
		and is_equal_approx(float(metrics.get("packet_loss_ratio", 1.0)), 0.02),
		"trace reports delivered packets and loss against the declared sent count"
	)
	_check(
		float(metrics.get("max_frame_motion_meters", 0.0)) > 17.0
		and float(metrics.get("max_local_step_meters", 99.0)) < 0.1
		and int(metrics.get("max_gap_ticks", 0)) >= 2,
		"large moving-frame travel does not become local occupant drift"
	)
	_check(
		int(metrics.get("occupancy_sample_count", 0)) == 98
		and int(metrics.get("occupancy_entity_count", 0)) == 1
		and is_equal_approx(float(metrics.get("occupancy_coverage_ratio", 0.0)), 1.0)
		and float(metrics.get("max_occupancy_gap_seconds", 0.0)) > 0.02,
		"trace exposes deterministic occupant coverage and hold-gap metrics"
	)
	# A caller may also assess the delivered window independently of upstream
	# loss by declaring only the packets represented in that window.
	var bounded_report := Validator.new().validate_trace(trace, 98, {
		"authority_peer_id": 42,
		"origin_server_tick": 100,
		"max_latency_seconds": 0.106,
		"max_loss_ratio": 0.0,
	})
	_check(
		bool(bounded_report.accepted)
		and float((bounded_report.metrics as Dictionary).get("packet_loss_ratio", 1.0)) == 0.0,
		"caller can assess a bounded delivered window independently of upstream loss"
	)


func _test_rejection_and_local_instability() -> void:
	var first := Relationship.create(
		1, &"pilot_7", 1, &"jovian_frame", 1,
		Transform3D.IDENTITY
	).get_snapshot()
	var second := Relationship.create(
		2, &"pilot_7", 1, &"jovian_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(9.0, 0.0, 0.0))
	).get_snapshot()
	var unstable := Validator.new().validate_trace([
		{"snapshot": first, "arrival_time_seconds": 0.100},
		{"snapshot": second, "arrival_time_seconds": 0.117},
	], 2, {
		"origin_server_tick": 1,
		"authority_peer_id": 1,
		"max_local_speed_mps": 1.0,
		"local_correction_meters": 0.01,
	})
	_check(
		not bool(unstable.accepted)
		and unstable.reason == &"unstable"
		and not (unstable.packet_errors as PackedStringArray).is_empty(),
		"excessive frame-local correction fails the stability gate"
	)
	var too_late := Validator.new().validate_trace([
		{"snapshot": first, "arrival_time_seconds": 0.250},
	], 1, {"origin_server_tick": 1})
	_check(
		not bool(too_late.accepted)
		and (too_late.packet_errors as PackedStringArray).size() == 1,
		"packets beyond the latency budget are reported rather than accepted"
	)
	var missing_frame := Validator.new().validate_trace([{
		"snapshot": Relationship.create(
			3, &"pilot_7", 1, &"", 0, Transform3D.IDENTITY
		).get_snapshot(),
		"arrival_time_seconds": 0.100,
	}], 1, {"origin_server_tick": 3})
	_check(
		not bool(missing_frame.accepted)
		and int((missing_frame.metrics as Dictionary).get("occupancy_missing_frame_count", 0)) == 1,
		"missing moving-interior occupancy fails closed with an explicit metric"
	)
	var switched_frame := Validator.new().validate_trace([
		{
			"snapshot": Relationship.create(
				4, &"pilot_7", 1, &"jovian_frame", 1, Transform3D.IDENTITY
			).get_snapshot(),
			"arrival_time_seconds": 0.100,
		},
		{
			"snapshot": Relationship.create(
				5, &"pilot_7", 1, &"lifeboat_frame", 1, Transform3D.IDENTITY
			).get_snapshot(),
			"arrival_time_seconds": 0.117,
		},
	], 2, {"origin_server_tick": 4})
	_check(
		not bool(switched_frame.accepted)
		and int((switched_frame.metrics as Dictionary).get("occupancy_frame_switch_count", 0)) == 1,
		"moving-interior frame switches fail closed instead of silently relatching"
	)


func _test_audit_and_detachment() -> void:
	var validator := Validator.new()
	var audit := validator.audit()
	_check(
		bool(audit.valid)
		and bool(audit.frame_local_stability_gate)
		and bool(audit.latency_loss_jitter_gate)
		and not bool(audit.network_authority)
		and not bool(audit.owns_interpolation),
		"audit exposes bounded observation-only authority and capability seams"
	)
	var snapshot := validator.get_last_report()
	var trace := [{
		"snapshot": Relationship.create(
			10, &"pilot_7", 4, &"jovian_frame", 9, Transform3D.IDENTITY
		).get_snapshot(),
		"arrival_time_seconds": 0.100,
	}]
	var report := validator.validate_trace(trace, 1, {"origin_server_tick": 10})
	report.metrics.max_latency_seconds = 999.0
	_check(
		float(validator.get_last_report().metrics.max_latency_seconds) < 1.0
		and snapshot.is_empty(),
		"trace reports are detached and do not expose mutable retained state"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
