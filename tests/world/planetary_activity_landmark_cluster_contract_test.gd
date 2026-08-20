extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")
var assertions := 0
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "authored cluster validates")
	var snapshot: Dictionary = contract.get_snapshot()
	var landmarks: Array = snapshot["landmarks"]
	var activities: Array = snapshot["activities"]
	_check(landmarks.size() >= 6, "cluster carries a substantial authored landmark roster")
	_check(activities.size() >= 5, "cluster carries beacon patrol cargo race and convoy activities")
	_check(snapshot["identity"]["return_target_id"] == &"mudds_shipyards", "cluster returns to the shipyard")
	_check(snapshot["evidence"]["procedural_generation"] == false, "cluster explicitly rejects procedural generation")
	_check(snapshot["authority"]["activity"] == false and snapshot["authority"]["reward"] == false, "manifest owns no gameplay authority")
	var types := {}
	for activity in activities:
		types[activity["type"]] = true
		_check(landmarks.any(func(item: Dictionary) -> bool: return item["id"] == activity["start_landmark_id"]), "activity start is a declared landmark")
		_check(landmarks.any(func(item: Dictionary) -> bool: return item["id"] == activity["finish_landmark_id"]), "activity finish is a declared landmark")
		_check(not String(activity["return_incentive_id"]).is_empty(), "activity exposes a return incentive")
	_check(types.has(&"beacon"), "beacon activity is represented")
	_check(types.has(&"patrol"), "patrol activity is represented")
	_check(types.has(&"cargo"), "cargo activity is represented")
	_check(types.has(&"race"), "race activity is represented")
	_check(types.has(&"convoy"), "convoy activity is represented")
	var duplicate := contract.duplicate(true)
	duplicate.activity_ids = PackedStringArray(["same", "same", "cargo", "race", "convoy"])
	_check(_has_error(duplicate.get_validation_errors(), "duplicate"), "duplicate activity IDs fail closed")
	var unknown_landmark := contract.duplicate(true)
	unknown_landmark.activity_start_landmark_ids[0] = "missing_marker"
	_check(_has_error(unknown_landmark.get_validation_errors(), "unknown landmark"), "unknown activity landmark fails closed")
	var procedural := contract.duplicate(true)
	procedural.maximum_travel_time_s = 0.0
	_check(_has_error(procedural.get_validation_errors(), "travel_time"), "unbounded travel envelope fails closed")
	var detached: Array = snapshot["activities"]
	detached[0]["id"] = &"mutated"
	_check(contract.get_snapshot()["activities"][0]["id"] == &"ember_beacon_survey", "snapshot activities are detached")
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
		print("PLANETARY_ACTIVITY_LANDMARK_CLUSTER_CONTRACT_TEST_OK: %d assertions" % assertions)
		quit(0)
	else:
		printerr("PLANETARY_ACTIVITY_LANDMARK_CLUSTER_CONTRACT_TEST_FAIL: " + "; ".join(failures))
		quit(1)
