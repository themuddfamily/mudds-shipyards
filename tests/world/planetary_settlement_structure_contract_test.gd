extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
var assertions := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "authored settlement validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var landing_sites: Array = snapshot["landing_sites"]
	var structures: Array = snapshot["structures"]
	var landmarks: Array = snapshot["landmarks"]
	var hazards: Array = snapshot["hazards"]
	var activities: Array = snapshot["activities"]
	_check(snapshot["identity"]["settlement_id"] == &"ember_caldera_settlement", "snapshot preserves settlement identity")
	_check(landing_sites.size() >= 1, "settlement has an authored landing site")
	_check(structures.size() >= 3, "settlement has multiple authored structures")
	_check(landmarks.size() >= 4, "settlement has multiple navigable landmarks")
	_check(hazards.size() >= 2, "settlement has authored hazards")
	_check(activities.size() >= 2, "settlement has activity handoffs")
	_check(snapshot["handoffs"]["reward_ids"].size() >= 1, "settlement exposes reward handoffs")
	_check(snapshot["identity"]["return_target_id"] == &"mudds_shipyards", "settlement returns to shipyard")
	_check(snapshot["evidence"]["procedural_generation"] == false, "settlement rejects procedural generation")
	_check(snapshot["evidence"]["historical_claim"] == false, "settlement does not claim recovered source geometry")
	_check(snapshot["authority"]["activity"] == false and snapshot["authority"]["reward"] == false, "manifest owns no gameplay authority")
	_check(snapshot["authority"]["hazard"] == false and snapshot["authority"]["streaming"] == false, "manifest owns no hazard or streaming authority")
	var kinds := {}
	for structure in structures:
		kinds[structure["kind"]] = true
		_check(not String(structure["route_id"]).is_empty(), "structure declares a surface route")
	_check(kinds.has(&"habitat"), "habitat structure is represented")
	_check(kinds.has(&"operations"), "operations structure is represented")
	_check(kinds.has(&"processing"), "processing structure is represented")
	var landmark_ids := {}
	for landmark in landmarks:
		landmark_ids[landmark["id"]] = true
	for activity in activities:
		_check(landmark_ids.has(activity["start_landmark_id"]), "activity starts at a declared landmark")
		_check(landmark_ids.has(activity["finish_landmark_id"]), "activity finishes at a declared landmark")
		_check(not String(activity["authority_id"]).is_empty(), "activity names an existing authority handoff")
		_check(not String(activity["reward_id"]).is_empty(), "activity names a reward handoff")
		_check(not String(activity["recovery_id"]).is_empty(), "activity names a recovery handoff")
	var duplicate := contract.duplicate(true)
	duplicate.structure_ids = PackedStringArray(["same", "same", "three", "four"])
	_check(_has_error(duplicate.get_validation_errors(), "duplicate"), "duplicate structures fail closed")
	var bad_kind := contract.duplicate(true)
	bad_kind.structure_kind_ids[0] = "generated_biome"
	_check(_has_error(bad_kind.get_validation_errors(), "authored kind"), "unknown structure kind fails closed")
	var unknown_landmark := contract.duplicate(true)
	unknown_landmark.activity_start_landmark_ids[0] = "missing_marker"
	_check(_has_error(unknown_landmark.get_validation_errors(), "unknown activity start landmark"), "orphan activity landmark fails closed")
	var unknown_reward := contract.duplicate(true)
	unknown_reward.activity_reward_ids[0] = "unlisted_reward"
	_check(_has_error(unknown_reward.get_validation_errors(), "unknown activity reward"), "orphan activity reward fails closed")
	var non_finite := contract.duplicate(true)
	non_finite.structure_positions_body_local_m[0] = Vector3(INF, 0.0, 0.0)
	_check(_has_error(non_finite.get_validation_errors(), "must be finite"), "non-finite authored placement fails closed")
	var procedural := contract.duplicate(true)
	procedural.authored_radius_m = 0.0
	_check(_has_error(procedural.get_validation_errors(), "authored_radius"), "unbounded settlement envelope fails closed")
	var detached: Array = snapshot["structures"]
	detached[0]["id"] = &"mutated_structure"
	_check(contract.get_snapshot()["structures"][0]["id"] == &"ember_habitat_spine", "snapshot structures are detached")
	_finish()


func _has_error(errors: PackedStringArray, needle: String) -> bool:
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
		print("PLANETARY_SETTLEMENT_STRUCTURE_CONTRACT_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_SETTLEMENT_STRUCTURE_CONTRACT_TEST_FAIL: " + "; ".join(failures))
		quit(1)
