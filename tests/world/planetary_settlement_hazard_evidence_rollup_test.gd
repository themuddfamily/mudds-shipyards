extends SceneTree

const RollupScript := preload("res://scripts/world/planetary_settlement_hazard_evidence_rollup.gd")
const SettlementScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const HazardScript := preload("res://scripts/world/planetary_surface_hazard_content_contract.gd")
var assertions := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rollup := RollupScript.new()
	_check(rollup.is_definition_valid(), "authored settlement/hazard sources roll up cleanly")
	var snapshot: Dictionary = rollup.get_snapshot()
	_check(snapshot["identity"]["world_id"] == &"ember_moon", "rollup preserves world identity")
	_check(snapshot["identity"]["landing_region_id"] == &"ember_caldera", "rollup preserves landing region")
	_check(snapshot["identity"]["return_target_id"] == &"mudds_shipyards", "rollup preserves station return")
	_check(snapshot["counts"]["settlement_landmarks"] >= 4, "rollup counts authored settlement landmarks")
	_check(snapshot["counts"]["settlement_structures"] >= 3, "rollup counts authored settlement structures")
	_check(snapshot["counts"]["settlement_hazards"] >= 2, "rollup counts settlement hazards")
	_check(snapshot["counts"]["surface_hazards"] >= 2, "rollup counts surface hazards")
	_check(snapshot["handoffs"]["activity_authority_id"] == &"activity_director", "activity handoff uses existing authority")
	_check(snapshot["handoffs"]["reward_authority_id"] == &"game_flow_reward_authority", "reward handoff uses existing authority")
	_check(snapshot["handoffs"]["recovery_authority_id"] == &"planetary_landing_return_contract", "recovery handoff uses existing authority")
	_check(snapshot["evidence"]["historical_claim"] == false, "rollup makes no historical claim")
	_check(snapshot["evidence"]["procedural_generation"] == false, "rollup rejects procedural generation")
	_check(snapshot["authority"]["settlement"] == false and snapshot["authority"]["hazard"] == false, "rollup owns no content authority")
	_check(snapshot["authority"]["activity"] == false and snapshot["authority"]["reward"] == false, "rollup owns no gameplay authority")
	var source_result := rollup.validate_sources(
		SettlementScript.new().get_snapshot(), HazardScript.new().get_snapshot()
	)
	_check(source_result["accepted"] == true, "detached source snapshots are accepted")
	var bad_world := SettlementScript.new().get_snapshot()
	bad_world["identity"]["world_id"] = &"other_moon"
	var rejected_world := rollup.validate_sources(bad_world, HazardScript.new().get_snapshot())
	_check(rejected_world["accepted"] == false, "world identity drift fails closed")
	_check(_has_error(rejected_world["errors"], "world ID"), "world identity failure is explained")
	var bad_evidence := HazardScript.new().get_snapshot()
	bad_evidence["evidence"]["procedural_generation"] = true
	var rejected_evidence := rollup.validate_sources(SettlementScript.new().get_snapshot(), bad_evidence)
	_check(rejected_evidence["accepted"] == false, "procedural evidence fails closed")
	var bad_reward := SettlementScript.new().get_snapshot()
	bad_reward["handoffs"]["reward_ids"] = PackedStringArray(["ember_relay_data"])
	var rejected_reward := rollup.validate_sources(bad_reward, HazardScript.new().get_snapshot())
	_check(rejected_reward["accepted"] == false, "duplicate cross-source reward fails closed")
	_check(_has_error(rejected_reward["errors"], "duplicate reward"), "duplicate reward failure is explained")
	var detached_counts: Dictionary = snapshot["counts"]
	detached_counts["surface_hazards"] = 0
	_check(rollup.get_snapshot()["counts"]["surface_hazards"] >= 2, "rollup snapshot is detached")
	_finish()


func _has_error(errors: Variant, needle: String) -> bool:
	for error in errors:
		if String(error).to_lower().contains(needle.to_lower()):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PLANETARY_SETTLEMENT_HAZARD_EVIDENCE_ROLLUP_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_SETTLEMENT_HAZARD_EVIDENCE_ROLLUP_TEST_FAIL: " + "; ".join(failures))
		quit(1)
