extends SceneTree

const ActivityScript := preload("res://scripts/world/ember_surface_relay_survey_activity.gd")

class FakeAdapter:
	var sequence: Array = []
	var discoveries: Array = []
	var positions: Array = []
	func start_surface_activity_sequence(ids: Array) -> Dictionary:
		sequence = ids.duplicate()
		return {"accepted": true, "reason": &"sequence_started"}
	func submit_activity_landmark_discovery(id: StringName, position: Vector3) -> Dictionary:
		discoveries.append({"id": id, "position": position})
		return {"accepted": true, "reason": &"landmark_discovered"}
	func submit_activity_position(position: Vector3) -> Dictionary:
		positions.append(position)
		return {"accepted": true, "reason": &"position_accepted"}
	func commit_activity_reward() -> Dictionary:
		return {"accepted": true, "reason": &"reward_committed"}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var adapter := FakeAdapter.new()
	var activity := ActivityScript.new()
	var started := activity.begin(adapter)
	var discovered := activity.submit_landmark(adapter, activity.START_LANDMARK_ID, Vector3(180.0, 120009.0, -44.0))
	var positioned := activity.submit_position(adapter, Vector3(200.0, 120010.0, -45.0))
	var committed := activity.commit_reward(adapter)
	var snapshot := activity.get_snapshot()
	if not started.accepted or adapter.sequence != [activity.ACTIVITY_ID] or not discovered.accepted \
			or not positioned.accepted or not committed.accepted or snapshot.authority.reward:
		push_error("relay survey activity facade failed")
		quit(1)
		return
	print("EMBER_SURFACE_RELAY_SURVEY_ACTIVITY_TEST_OK: adapter-owned activity/reward handoff")
	quit(0)
