extends SceneTree

## Focused contract checks for the authored station-defense/cargo/patrol roster.
## This intentionally does not launch Main, render, or run the wider matrix.

const ContractScript := preload("res://scripts/world/shipyard_activity_cluster_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_manifest()
	_test_handoffs_and_return_incentives()
	_test_snapshot_detachment()
	_test_invalid_rosters_fail_closed()
	_finish()


func _test_default_manifest() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "default authored shipyard cluster is valid")
	var report := contract.get_audit_report()
	var snapshot: Dictionary = report.get("snapshot", {})
	var evidence: Dictionary = snapshot.get("evidence", {})
	_check(int(report.get("schema_version", -1)) == 1, "schema version is explicit")
	_check(snapshot.get("identity", {}).get("station_id") == &"mudds_shipyards", "station identity is stable")
	_check(snapshot.get("identity", {}).get("return_target_id") == &"mudds_shipyards", "return target stays at the shipyard")
	_check(snapshot.get("activities", []).size() == 3, "cluster has exactly three authored activity handoffs")
	_check(evidence.get("procedural_generation", true) == false, "cluster explicitly forbids procedural generation")
	_check(evidence.get("historical_claim", true) == false, "modern content makes no historical mission claim")
	_check(snapshot.get("authority", {}).get("activity", true) == false, "manifest owns no activity authority")
	_check(snapshot.get("authority", {}).get("cargo", true) == false, "manifest owns no cargo authority")
	_check(snapshot.get("authority", {}).get("combat", true) == false, "manifest owns no combat authority")


func _test_handoffs_and_return_incentives() -> void:
	var contract := ContractScript.new()
	var defense := contract.get_activity_by_id(&"shipyard_perimeter_defense")
	var cargo := contract.get_activity_by_id(&"cinder_kit_cargo_run")
	var patrol := contract.get_activity_by_id(&"cinder_relay_patrol")
	_check(defense.get("type") == &"station_defense", "defense handoff has station_defense type")
	_check(defense.get("authority_id") == &"station_defense_encounter_host", "defense handoff names the existing encounter host")
	_check(defense.get("combat_authority_id") == &"live_combat_authority", "defense hands combat to the shared authority")
	_check(cargo.get("type") == &"cargo" and cargo.get("cargo_authority_id") == &"cargo_transfer_authority", "cargo handoff names typed transfer authority")
	_check(patrol.get("type") == &"patrol" and patrol.get("authority_id") == &"patrol_activity", "patrol handoff names patrol activity authority")
	for activity in [defense, cargo, patrol]:
		_check(activity.get("finish_landmark_id") == &"shipyard_return_berth", "every activity returns to the shipyard berth")
		_check(activity.get("return_authority_id") == &"shipyard_return_authority", "every activity names a return authority")
		_check(String(activity.get("return_incentive_id", "")).begins_with("return_"), "every activity carries a return incentive ID")
		_check(String(activity.get("recovery_id", "")).is_empty() == false, "every activity carries a recovery handoff")
	_check(contract.get_activity_by_id(&"missing_activity").is_empty(), "unknown activity IDs do not fabricate a handoff")
	_check(contract.get_activity(-1).is_empty() and contract.get_activity(99).is_empty(), "out-of-range activity indexes fail closed")


func _test_snapshot_detachment() -> void:
	var contract := ContractScript.new()
	var snapshot := contract.get_snapshot()
	(snapshot.get("identity", {}) as Dictionary)["cluster_id"] = &"forged_cluster"
	(snapshot.get("activities", []) as Array).clear()
	var fresh := contract.get_snapshot()
	_check(fresh.get("identity", {}).get("cluster_id") == &"shipyard_activity_cluster", "snapshot identity is detached")
	_check(fresh.get("activities", []).size() == 3, "snapshot activity array is detached")
	var activity := contract.get_activity(0)
	activity["authority_id"] = &"forged_authority"
	_check(contract.get_activity(0).get("authority_id") == &"station_defense_encounter_host", "activity handoff snapshot is detached")


func _test_invalid_rosters_fail_closed() -> void:
	var duplicate := ContractScript.new()
	duplicate.activity_ids[1] = duplicate.activity_ids[0]
	_check(not duplicate.is_definition_valid() and _has_error(duplicate, "activity_ids must not contain duplicate IDs"), "duplicate activity IDs are rejected")
	var missing_type := ContractScript.new()
	missing_type.activity_type_ids[2] = "survey"
	_check(not missing_type.is_definition_valid() and _has_error(missing_type, "activity cluster must include a patrol activity"), "missing required activity types are rejected")
	var broken_parallel := ContractScript.new()
	broken_parallel.return_incentive_ids.remove_at(0)
	_check(not broken_parallel.is_definition_valid() and _has_error(broken_parallel, "activity return incentives must be parallel to IDs"), "parallel handoff drift is rejected")
	var unknown_landmark := ContractScript.new()
	unknown_landmark.activity_start_landmark_ids[0] = "unknown_anchor"
	_check(not unknown_landmark.is_definition_valid() and _has_error(unknown_landmark, "activity 0 references unknown landmark"), "unknown activity anchors are rejected")
	var unbounded := ContractScript.new()
	unbounded.maximum_cluster_radius_m = 0.0
	_check(not unbounded.is_definition_valid() and _has_error(unbounded, "maximum_cluster_radius_m is outside the bounded activity envelope"), "unbounded cluster scale is rejected")


func _has_error(contract: Resource, expected: String) -> bool:
	return (contract.get_validation_errors() as PackedStringArray).has(expected)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIPYARD_ACTIVITY_CLUSTER_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	push_error("%d/%d assertions failed" % [_failures.size(), _assertions])
	quit(1)
