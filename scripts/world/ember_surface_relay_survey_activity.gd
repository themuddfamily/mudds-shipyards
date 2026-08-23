class_name EmberSurfaceRelaySurveyActivity
extends RefCounted

## Authored Ember relay survey facade over the retained planetary activity
## adapter. It contributes IDs and caller evidence only; the adapter/director
## remain authoritative for progression and reward commitment.

const ACTIVITY_ID: StringName = &"ember_beacon_survey"
const START_LANDMARK_ID: StringName = &"ember_relay_tower"
const FINISH_LANDMARK_ID: StringName = &"ember_return_beacon"
const REWARD_ID: StringName = &"ember_beacon_data"

func begin(adapter: Object, navigation: RefCounted = null) -> Dictionary:
	if adapter == null:
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	var ids: Array[StringName] = [ACTIVITY_ID]
	if navigation != null and adapter.has_method(&"start_surface_activity_sequence"):
		return adapter.call(&"start_surface_activity_sequence", ids, navigation)
	if not adapter.has_method(&"start_activity_sequence"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	return adapter.call(&"start_activity_sequence", ids)

func submit_landmark(adapter: Object, landmark_id: StringName, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_landmark_discovery") \
			or not position.is_finite() or landmark_id.is_empty():
		return {"accepted": false, "reason": &"invalid_relay_survey_evidence"}
	return adapter.call(&"submit_activity_landmark_discovery", landmark_id, position)

func submit_position(adapter: Object, position: Vector3) -> Dictionary:
	if adapter == null or not adapter.has_method(&"submit_activity_position") or not position.is_finite():
		return {"accepted": false, "reason": &"invalid_relay_survey_position"}
	return adapter.call(&"submit_activity_position", position)

func commit_reward(adapter: Object) -> Dictionary:
	if adapter == null or not adapter.has_method(&"commit_activity_reward"):
		return {"accepted": false, "reason": &"activity_adapter_unavailable"}
	return adapter.call(&"commit_activity_reward")

func get_snapshot() -> Dictionary:
	return {"activity_id": ACTIVITY_ID, "start_landmark_id": START_LANDMARK_ID, "finish_landmark_id": FINISH_LANDMARK_ID, "reward_id": REWARD_ID, "authority": {"activity": false, "reward": false, "movement": false, "save": false}}.duplicate(true)
