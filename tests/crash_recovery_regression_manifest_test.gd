extends SceneTree

const Manifest := preload("res://scripts/recovery/crash_recovery_regression_manifest.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := Manifest.new()
	var trace := _valid_trace()
	var accepted := manifest.validate_trace(trace)
	_check(bool(accepted.get("accepted", false)), "complete crash recovery trace is accepted")
	_check(
		accepted.get("validated_steps", []).size() == 4
			and int(accepted.get("failure_generation", 0)) == 7
			and int(accepted.get("respawn_generation", 0)) == 8,
		"accepted trace reports the failure and respawn generations"
	)
	var contract := manifest.get_manifest()
	_check(
		contract.get("required_steps", []).size() == 4
			and bool(contract.get("ordered_steps", false))
			and int(contract.get("schema_version", 0)) == 1,
		"manifest freezes four ordered recovery steps"
	)
	_check(
		manifest.audit().get("authority", {}).get("respawn", true) == false
			and manifest.audit().get("authority", {}).get("persistence", true) == false,
		"manifest remains evidence-only and owns no recovery authority"
	)

	var missing_cleanup := trace.duplicate(true)
	missing_cleanup.remove_at(1)
	_check(
		not bool(manifest.validate_trace(missing_cleanup).get("accepted", true)),
		"missing cleanup evidence fails closed"
	)
	var stale_respawn := trace.duplicate(true)
	(stale_respawn[2] as Dictionary)["generation"] = 10
	_check(
		not bool(manifest.validate_trace(stale_respawn).get("accepted", true)),
		"respawn from a non-successor generation fails closed"
	)
	var leaked_cleanup := trace.duplicate(true)
	(leaked_cleanup[1] as Dictionary)["transient_nodes_after"] = 1
	_check(
		not bool(manifest.validate_trace(leaked_cleanup).get("accepted", true)),
		"transient cleanup leakage fails closed"
	)
	var unsafe_reentry := trace.duplicate(true)
	(unsafe_reentry[3] as Dictionary)["stale_request_rejected"] = false
	_check(
		not bool(manifest.validate_trace(unsafe_reentry).get("accepted", true)),
		"stale generation re-entry acceptance fails closed"
	)
	var duplicate_step := trace.duplicate(true)
	duplicate_step.append((trace[0] as Dictionary).duplicate(true))
	_check(
		not bool(manifest.validate_trace(duplicate_step).get("accepted", true)),
		"duplicate component failure evidence fails closed"
	)
	_check(
		manifest.validate_trace(trace).get("errors", []).is_empty(),
		"validation does not mutate the accepted detached trace"
	)
	_finish()


func _valid_trace() -> Array:
	return [
		{
			"step": Manifest.STEP_COMPONENT_FAILURE,
			"authority_owner": "ComponentDamageModel",
			"authoritative": true,
			"generation": 7,
			"component_id": "port_engine",
			"damage_sequence": 41,
			"health_before": 12.0,
			"health_after": 0.0,
			"state": "failed",
		},
		{
			"step": Manifest.STEP_CLEANUP,
			"authority_owner": "RecoveryLifecycle",
			"authoritative": true,
			"source_generation": 7,
			"pending_receipts_after": 0,
			"transient_nodes_after": 0,
			"stale_callbacks_cancelled": true,
			"old_authority_released": true,
		},
		{
			"step": Manifest.STEP_RESPAWN,
			"authority_owner": "HeroShip",
			"authoritative": true,
			"source_generation": 7,
			"generation": 8,
			"restored": true,
			"health_restored": true,
			"spawn_transform_restored": true,
			"active": true,
		},
		{
			"step": Manifest.STEP_GENERATION_SAFE_REENTRY,
			"authority_owner": "SaveReentryLifecycle",
			"authoritative": true,
			"source_generation": 8,
			"generation": 9,
			"stale_request_rejected": true,
			"stale_reason": "stale_attachment_generation",
			"duplicate_reentry_rejected": true,
			"state_restored": true,
			"accepted": true,
			"current_generation": 9,
		},
	]


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("CRASH_RECOVERY_REGRESSION_MANIFEST_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("CRASH_RECOVERY_REGRESSION_MANIFEST_TEST_FAIL: " + failure)
	quit(1)
