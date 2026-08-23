extends SceneTree

const Binding := preload("res://scripts/persistence/nearby_sector_activity_persistence_binding.gd")
const Adapter := preload("res://scripts/persistence/nearby_sector_activity_session_adapter.gd")

class FakeStore extends RefCounted:
	var payload: Dictionary = {}
	var fail_commit := false

	func commit(next_payload: Dictionary, _generation: int, _commit_id: String) -> Dictionary:
		if fail_commit:
			return {"accepted": false, "reason": &"atomic_replace_failed", "rollback_restored": true}
		payload = next_payload.duplicate(true)
		return {"accepted": true, "reason": &"committed", "payload": payload}

	func load() -> Dictionary:
		return {"accepted": not payload.is_empty(), "reason": &"ok", "payload": payload.duplicate(true)}


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var store := FakeStore.new()
	var binding := Binding.new()
	_check(binding.configure(store, Adapter.new(), &"cinder_slot"), "binding accepts caller-owned store, adapter and slot")
	var saved := binding.save({"mining": {"activity_id": &"cinder_platform_mining_run", "generation": 2, "state": 2}}, 2, "cinder_commit_2")
	_check(bool(saved.get("accepted", false)), "binding commits the adapter payload through the store seam")
	var loaded := binding.load()
	_check(bool(loaded.get("accepted", false)), "binding restores a valid slot payload")
	store.fail_commit = true
	var failed := binding.save({}, 3, "cinder_commit_3")
	_check(not bool(failed.get("accepted", true)) and bool(failed.get("rollback_restored", false)), "failed store publication reports preserved rollback")
	store.payload["slot_id"] = &"other_slot"
	var wrong_slot := binding.load()
	_check(not bool(wrong_slot.get("accepted", true)) and wrong_slot.get("reason", &"") == &"wrong_slot_or_payload", "foreign slot payloads fail closed")
	if _failures.is_empty():
		print("PASS nearby_sector_activity_persistence_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
