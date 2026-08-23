class_name CinderCargoRewardHandoff
extends RefCounted

## Routes an authoritative Cinder cargo completion into the existing nearby
## reward adapter. The adapter and its caller remain the only reward/grant seam.

const ACTIVITY_ID: StringName = &"cinder_kit_cargo_run"
const REWARD_ID: StringName = &"return_fabrication_kits_to_shipyard"

signal completion_committed(activity_snapshot: Dictionary, reward_result: Dictionary)

var _activity: CargoDeliveryActivity
var _adapter: RefCounted
var _last_result: Dictionary = {}
var _completion_generation := 0
var _automatic_result_pending := false
var _attached := false


func attach(activity: CargoDeliveryActivity, adapter: RefCounted) -> Dictionary:
	if _attached:
		return _result(false, &"cargo_reward_handoff_already_attached")
	if activity == null or adapter == null \
			or not adapter.has_method(&"consume") or not adapter.has_method(&"get_snapshot"):
		return _result(false, &"cargo_reward_handoff_invalid")
	_activity = activity
	_adapter = adapter
	_activity.completed.connect(_on_cargo_completed)
	_attached = true
	var current := _activity.get_snapshot()
	if int(current.get("state", -1)) == CargoDeliveryActivity.State.COMPLETED:
		var routed := _route_completion(current, int(current.get("generation", 0)))
		_automatic_result_pending = bool(routed.get("accepted", false))
	return _result(true, &"cargo_reward_handoff_attached")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"cargo_reward_handoff_not_attached")
	if _activity != null and _activity.completed.is_connected(_on_cargo_completed):
		_activity.completed.disconnect(_on_cargo_completed)
	_activity = null
	_adapter = null
	_automatic_result_pending = false
	_attached = false
	return _result(true, &"cargo_reward_handoff_detached")


## Explicit retry/read-through seam. Replays after a committed request are
## rejected by NearbyActivityRewardAdapter without calling the grant callback.
func request(expected_generation: int) -> Dictionary:
	if not _attached or _activity == null or _adapter == null:
		return _retain(_result(false, &"cargo_reward_handoff_unavailable"))
	var cargo := _activity.get_snapshot()
	var generation := int(cargo.get("generation", 0))
	if expected_generation < 1 or generation != expected_generation:
		var stale := _result(false, &"stale_activity_generation")
		return stale if _automatic_result_pending else _retain(stale)
	if _automatic_result_pending and generation == _completion_generation:
		_automatic_result_pending = false
		return _last_result.duplicate(true)
	return _route_completion(cargo, expected_generation)


func _route_completion(cargo: Dictionary, expected_generation: int) -> Dictionary:
	var generation := int(cargo.get("generation", 0))
	var completed := int(cargo.get("state", -1)) == CargoDeliveryActivity.State.COMPLETED
	var normalized := {
		"activity_id": ACTIVITY_ID,
		"state_id": &"completed" if completed else &"",
		"outcome": &"cleared" if completed else &"",
		"generation": generation,
	}.duplicate(true)
	var result := _adapter.call("consume", normalized, expected_generation) as Dictionary
	if bool(result.get("accepted", false)):
		_completion_generation = generation
	var retained := _retain(result)
	if bool(retained.get("accepted", false)):
		completion_committed.emit(cargo.duplicate(true), retained.duplicate(true))
	return retained


## Clears only handoff presentation after the activity authority has reset.
## The adapter's consumed-generation fence intentionally survives.
func reset(expected_generation: int) -> Dictionary:
	if not _attached or _activity == null:
		return _result(false, &"cargo_reward_handoff_unavailable")
	var cargo := _activity.get_snapshot()
	if int(cargo.get("generation", 0)) != expected_generation:
		return _result(false, &"stale_activity_generation")
	if int(cargo.get("state", -1)) != CargoDeliveryActivity.State.IDLE:
		return _result(false, &"cargo_activity_not_reset")
	_last_result.clear()
	_completion_generation = 0
	_automatic_result_pending = false
	return _result(true, &"cargo_reward_handoff_reset")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"activity_id": ACTIVITY_ID,
		"reward_id": REWARD_ID,
		"completion_generation": _completion_generation,
		"automatic_result_pending": _automatic_result_pending,
		"last_result": _last_result.duplicate(true),
		"reward_authority": false,
		"inventory_authority": false,
		"grant_authority": false,
	}.duplicate(true)


func _on_cargo_completed(snapshot: Dictionary, _receipt: Dictionary) -> void:
	var result := _route_completion(snapshot, int(snapshot.get("generation", 0)))
	_automatic_result_pending = bool(result.get("accepted", false))


func _retain(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
