class_name NearbyActivityRewardAdapter
extends RefCounted

## Typed, caller-owned reward handoff for nearby activities. This adapter keeps
## no wallet, save, GameFlow, combat, or activity authority; the callback/store
## remains responsible for the actual grant.

var _callback: Callable
var _activity_id: StringName = &""
var _reward_id: StringName = &""
var _state: StringName = &"unconfigured"
var _consumed_generation := -1
var _attachment_generation := -1
var _last_request: Dictionary = {}

func configure(callback: Callable, activity_id: StringName, reward_id: StringName) -> Dictionary:
	if not callback.is_valid() or activity_id.is_empty() or reward_id.is_empty():
		return _reject(&"invalid_reward_callback_configuration")
	if _state != &"unconfigured":
		return _reject(&"reward_adapter_already_configured")
	_callback = callback
	_activity_id = activity_id
	_reward_id = reward_id
	_state = &"ready"
	return _result(true, &"reward_adapter_configured")

func consume(activity_snapshot: Variant, expected_generation: int) -> Dictionary:
	if _state == &"detached":
		return _reject(&"reward_adapter_detached")
	if _state != &"ready" or not activity_snapshot is Dictionary:
		return _reject(&"reward_adapter_unavailable")
	var snapshot := activity_snapshot as Dictionary
	var generation := int(snapshot.get("generation", 0))
	if generation < 1 or generation == _consumed_generation:
		return _reject(&"reward_already_consumed")
	if expected_generation < 1 or generation != expected_generation:
		return _reject(&"stale_activity_generation")
	if StringName(snapshot.get("activity_id", &"")) != _activity_id \
			or StringName(snapshot.get("state_id", &"")) != &"concluded" \
			or StringName(snapshot.get("outcome", &"")) != &"cleared":
		return _reject(&"activity_not_reward_complete")
	var request := {
		"activity_id": _activity_id,
		"activity_generation": generation,
		"reward_id": _reward_id,
		"reward_authority": false,
		"granted": false,
	}.duplicate(true)
	var callback_result: Variant = _callback.call(request.duplicate(true))
	if not callback_result is Dictionary or not bool((callback_result as Dictionary).get("accepted", false)):
		return _reject(&"reward_callback_rejected")
	_consumed_generation = generation
	_last_request = request
	return {"accepted": true, "reason": &"reward_request_committed", "reward_request": request, "callback": callback_result}.duplicate(true)

func reset() -> Dictionary:
	_state = &"ready" if _callback.is_valid() else &"unconfigured"
	_consumed_generation = -1
	_last_request.clear()
	return _result(true, &"reward_adapter_reset")

func detach() -> Dictionary:
	_state = &"detached"
	return _result(true, &"reward_adapter_detached")

func reenter(attachment_generation: int) -> Dictionary:
	if _state != &"detached" or attachment_generation < 1:
		return _reject(&"reward_adapter_reentry_unavailable")
	_attachment_generation = attachment_generation
	_state = &"ready"
	return _result(true, &"reward_adapter_reentered")

func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"activity_id": _activity_id,
		"reward_id": _reward_id,
		"consumed_generation": _consumed_generation,
		"attachment_generation": _attachment_generation,
		"last_request": _last_request.duplicate(true),
		"authority": {"wallet": false, "save": false, "game_flow": false, "reward": false},
	}.duplicate(true)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}

func _reject(reason: StringName) -> Dictionary:
	return _result(false, reason)
