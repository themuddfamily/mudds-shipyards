extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

class FakeStore extends RefCounted:
	var payload: Dictionary = {}

	func commit(next_payload: Dictionary, _generation: int, _commit_id: String) -> Dictionary:
		payload = next_payload.duplicate(true)
		return {"accepted": true, "reason": &"committed", "payload": payload}

	func load() -> Dictionary:
		return {"accepted": true, "reason": &"ok", "payload": payload.duplicate(true)}


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding")
	var store := FakeStore.new()
	_check(bool(binding.call("configure_activity_persistence", store, &"nearby_slot")), "real nearby owner accepts caller-owned persistence configuration")
	var save := binding.call("save_activity_session", 2, "nearby_commit_2") as Dictionary
	_check(bool(save.get("accepted", false)), "nearby owner captures all activity state through the persistence binding")
	var load := binding.call("load_activity_session") as Dictionary
	_check(bool(load.get("accepted", false)), "nearby owner loads and validates the persisted session")
	var restored := binding.call("get_restored_activity_session") as Dictionary
	_check(not restored.is_empty(), "validated state is retained as detached caller-owned restore data")
	var mining := restored.get("activities", []) as Array
	var rewards_granted := false
	for activity in mining:
		rewards_granted = rewards_granted or bool((activity as Dictionary).get("reward_granted", true))
	_check(not rewards_granted, "restored activity data never claims a granted reward")
	cluster.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS nearby_sector_activity_persistence_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
