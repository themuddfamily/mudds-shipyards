extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_objective_reward_recovery_contract.gd")
var assertions := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "authored objective/reward/recovery roster validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var activities: Array = snapshot["activities"]
	_check(activities.size() == 5, "the authored roster carries five planetary objectives")
	_check(snapshot["identity"]["world_id"] == &"ember_moon", "handoff identifies Ember Moon")
	_check(snapshot["identity"]["return_target_id"] == &"mudds_shipyards", "every objective returns to Mudds Shipyards")
	_check(snapshot["authorities"]["reward_store_id"] == &"game_flow_reward_store", "handoff names the existing reward store")
	_check(snapshot["authority"]["reward"] == false and snapshot["authority"]["reward_store"] == false, "manifest owns no reward authority or store")
	var seen_rewards := {}
	var seen_incentives := {}
	for activity in activities:
		_check([
			&"activity_director", &"cargo_delivery_activity", &"timed_checkpoint_race",
			&"convoy_escort_activity",
		].has(activity["activity_authority_id"]), "objective ties to an existing activity authority")
		_check(activity["reward_store_id"] == &"game_flow_reward_store", "objective uses the one reward store")
		_check(String(activity["return_incentive_id"]).begins_with("return_"), "objective exposes a return incentive")
		_check(not String(activity["recovery_id"]).is_empty(), "objective exposes a recoverable failure state")
		_check(not seen_rewards.has(activity["reward_id"]), "each objective has a distinct reward key")
		_check(not seen_incentives.has(activity["return_incentive_id"]), "each objective has a distinct return incentive")
		seen_rewards[activity["reward_id"]] = true
		seen_incentives[activity["return_incentive_id"]] = true
	var handoff := contract.validate_handoff(snapshot)
	_check(handoff["accepted"] == true, "detached handoff is accepted")
	_check(handoff["snapshot"]["authority"]["activity"] == false, "handoff snapshot stays data-only")
	var unknown_authority := contract.duplicate(true)
	unknown_authority.activity_authority_ids[0] = "new_planetary_activity_authority"
	_check(_has_error(unknown_authority.get_validation_errors(), "existing activity authority"), "unknown activity authority fails closed")
	var duplicate_store := contract.duplicate(true)
	duplicate_store.activity_reward_store_ids[1] = "second_reward_store"
	_check(_has_error(duplicate_store.get_validation_errors(), "duplicate reward store"), "second reward store fails closed")
	var duplicate_reward := contract.duplicate(true)
	duplicate_reward.reward_ids[1] = duplicate_reward.reward_ids[0]
	_check(_has_error(duplicate_reward.get_validation_errors(), "duplicate"), "duplicate reward key fails closed")
	var bad_incentive := contract.duplicate(true)
	bad_incentive.return_incentive_ids[0] = "bonus_without_return"
	_check(_has_error(bad_incentive.get_validation_errors(), "return_"), "non-return incentive fails closed")
	var bad_recovery := contract.duplicate(true)
	bad_recovery.activity_recovery_ids[0] = "unowned_recovery"
	_check(_has_error(bad_recovery.get_validation_errors(), "existing recovery"), "unknown recovery state fails closed")
	var detached_activities: Array = snapshot["activities"]
	detached_activities[0]["reward_id"] = &"mutated_reward"
	_check(contract.get_snapshot()["activities"][0]["reward_id"] == &"ember_beacon_data", "snapshot activities are detached")
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
		print("PLANETARY_OBJECTIVE_REWARD_RECOVERY_CONTRACT_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_OBJECTIVE_REWARD_RECOVERY_CONTRACT_TEST_FAIL: " + "; ".join(failures))
		quit(1)
