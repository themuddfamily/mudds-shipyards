extends SceneTree

const Adapter := preload("res://scripts/persistence/nearby_sector_activity_session_adapter.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var adapter := Adapter.new()
	var payload := adapter.capture({
		"host": {"activity": {"activity_id": &"cinder_reach_emberline_convoy", "generation": 3, "state": 1}},
		"mining": {"activity_id": &"cinder_platform_mining_run", "generation": 2, "state": 2, "reward_requested": true},
	})
	_check(payload.get("schema_version", 0) == 1 and (payload.get("activities", []) as Array).size() == 2, "capture records supported activity IDs and generations")
	var restored := adapter.restore(payload)
	_check(bool(restored.get("accepted", false)) and (restored.get("activities", []) as Array).size() == 2, "valid payload restores detached progress")
	_check(not bool(((restored.get("activities", []) as Array)[1] as Dictionary).get("reward_granted", true)), "restored progress never claims a granted reward")
	var replay := adapter.restore(payload)
	_check(not bool(replay.get("accepted", true)) and replay.get("reason", &"") == &"replay_generation", "replaying a generation is fenced")
	var stale := adapter.restore({"schema_version": 1, "activities": [{"activity_id": &"cinder_platform_mining_run", "generation": 1}]}, {&"cinder_platform_mining_run": 2})
	_check(not bool(stale.get("accepted", true)) and stale.get("reason", &"") == &"stale_generation", "older progress cannot overwrite a newer generation")
	var newer := adapter.restore({"schema_version": 2, "activities": []})
	_check(not bool(newer.get("accepted", true)) and newer.get("reason", &"") == &"newer_schema", "newer schemas fail closed")
	if _failures.is_empty():
		print("PASS nearby_sector_activity_session_adapter_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
