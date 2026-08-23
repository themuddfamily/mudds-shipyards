class_name EmberRelaySurveyReturnTravelAdapter
extends RefCounted

## Caller-authorized travel intent consumer for the Ember survey return.
## It validates identity and lifecycle evidence, but never moves an actor,
## selects a berth, grants a reward, or owns GameFlow.

const DESTINATION_ID: StringName = &"mudds_shipyards"
var _state: StringName = &"ready"
var _consumed_activity_generation := -1
var _attachment_generation := -1
var _last_intent: Dictionary = {}

func consume(
		manifest_result: Variant,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _state == &"detached":
		return _reject(&"return_travel_adapter_detached")
	if not manifest_result is Dictionary or actor_instance_id < 1 \
			or craft_instance_id < 1 or expected_attachment_generation < 1:
		return _reject(&"invalid_return_travel_identity")
	var result := manifest_result as Dictionary
	if not bool(result.get("accepted", false)):
		return _reject(&"return_manifest_not_accepted")
	var manifest := result.get("manifest", {}) as Dictionary
	var activity_generation := int(manifest.get("activity_generation", 0))
	if activity_generation < 1 or activity_generation == _consumed_activity_generation:
		return _reject(&"return_travel_already_consumed")
	if StringName(manifest.get("destination_id", &"")) != DESTINATION_ID \
			or int(manifest.get("attachment_generation", 0)) \
			!= expected_attachment_generation:
		return _reject(&"return_manifest_identity_mismatch")
	if bool(manifest.get("movement_authority", true)) \
			or bool(manifest.get("berth_authority", true)) \
			or bool(manifest.get("reward_authority", true)):
		return _reject(&"return_manifest_claims_authority")
	_consumed_activity_generation = activity_generation
	_attachment_generation = expected_attachment_generation
	_last_intent = {
		"activity_id": manifest.get("activity_id", &""),
		"activity_generation": activity_generation,
		"actor_instance_id": actor_instance_id,
		"craft_instance_id": craft_instance_id,
		"attachment_generation": expected_attachment_generation,
		"destination_id": DESTINATION_ID,
		"movement_authority": false,
		"berth_authority": false,
		"reward_authority": false,
	}.duplicate(true)
	return {"accepted": true, "reason": &"return_travel_intent_ready", "intent": _last_intent.duplicate(true)}

func abort(reason: StringName = &"caller_aborted") -> Dictionary:
	if _state == &"detached":
		return _reject(&"return_travel_adapter_detached")
	_state = &"aborted"
	return {"accepted": true, "reason": reason}

func reset() -> Dictionary:
	_state = &"ready"
	_consumed_activity_generation = -1
	_attachment_generation = -1
	_last_intent.clear()
	return {"accepted": true, "reason": &"return_travel_adapter_reset"}

func detach() -> Dictionary:
	_state = &"detached"
	return {"accepted": true, "reason": &"return_travel_adapter_detached"}

func reenter(attachment_generation: int) -> Dictionary:
	if _state != &"detached" or attachment_generation < 1 \
			or attachment_generation <= _attachment_generation:
		return _reject(&"return_travel_reentry_unavailable")
	_attachment_generation = attachment_generation
	_state = &"ready"
	return {"accepted": true, "reason": &"return_travel_adapter_reentered"}

func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"consumed_activity_generation": _consumed_activity_generation,
		"attachment_generation": _attachment_generation,
		"last_intent": _last_intent.duplicate(true),
		"authority": {"movement": false, "berth": false, "reward": false, "game_flow": false},
	}.duplicate(true)

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
