class_name EmberRelaySurveyReturnManifest
extends RefCounted

## Generation-fenced return handoff for the authored Ember survey. This emits
## a route intent only; callers retain movement, berth, reward, and GameFlow
## authority.

const ACTIVITY_ID: StringName = &"ember_beacon_survey"
const RecoveryContractScript := preload("res://scripts/world/planetary_objective_reward_recovery_contract.gd")
var _recovery_contract: Resource = RecoveryContractScript.new()
var _issued_generation := -1

func issue(activity_snapshot: Variant, attachment_generation: int) -> Dictionary:
	if not activity_snapshot is Dictionary or attachment_generation < 1:
		return {"accepted": false, "reason": &"invalid_return_manifest_input"}
	var snapshot := activity_snapshot as Dictionary
	if StringName(snapshot.get("state", &"")) not in [&"completed", &"awaiting_reward"]:
		return {"accepted": false, "reason": &"survey_not_return_ready"}
	var generation := int(snapshot.get("activity_generation", 0))
	if generation < 1 or generation == _issued_generation:
		return {"accepted": false, "reason": &"return_manifest_already_issued"}
	var contract_activity := _contract_activity()
	if contract_activity.is_empty():
		return {"accepted": false, "reason": &"return_contract_activity_missing"}
	_issued_generation = generation
	return {"accepted": true, "reason": &"return_manifest_ready", "manifest": {"activity_id": ACTIVITY_ID, "activity_generation": generation, "attachment_generation": attachment_generation, "destination_id": contract_activity.return_target_id, "objective_id": contract_activity.objective_id, "reward_id": contract_activity.reward_id, "return_incentive_id": contract_activity.return_incentive_id, "recovery_id": contract_activity.recovery_id, "recovery_authority_id": contract_activity.recovery_authority_id, "movement_authority": false, "berth_authority": false, "reward_authority": false}}.duplicate(true)

func reset() -> Dictionary:
	_issued_generation = -1
	return {"accepted": true, "reason": &"return_manifest_reset"}

func get_snapshot() -> Dictionary:
	return {"issued_generation": _issued_generation, "activity_id": ACTIVITY_ID, "destination_id": _recovery_contract.return_target_id, "authority": {"movement": false, "berth": false, "reward": false, "save": false}}.duplicate(true)


func _contract_activity() -> Dictionary:
	for activity: Dictionary in _recovery_contract.get_snapshot().get("activities", []):
		if StringName(activity.get("activity_id", &"")) == ACTIVITY_ID:
			return activity
	return {}
