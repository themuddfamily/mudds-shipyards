extends SceneTree

class FakeCruise:
	extends RefCounted
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)
	var snapshot: Dictionary = {"generation": 1, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

const PresenterType := preload("res://scripts/ui/final_approach_status_presenter.gd")
const BindingType := preload("res://scripts/ui/final_approach_status_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var source := FakeCruise.new()
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	_check(bool(binding.attach(source, presenter, true).get("accepted", false)), "binding attaches through caller signal contract")
	_check(presenter.get_snapshot().state == &"armed", "initial detached source snapshot reaches presenter")
	source.snapshot = {"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach"}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"accepted": true, "reason": &"final_approach_envelope_submitted", "generation": 2, "controller": {"distance_to_destination_meters": 30.0, "ship_speed_meters_per_second": 5.0, "alignment_dot": 0.9}})
	_check(presenter.get_snapshot().state == &"approaching" and str(presenter.get_snapshot().text).contains("TRANSITION  //  STATIC"), "tick receipt refreshes reduced-motion presentation")
	source.final_approach_completed.emit({"accepted": true, "reason": &"final_approach_handoff_ready", "generation": 3})
	_check(presenter.get_snapshot().state == &"handoff", "completion receipt reaches handoff state")
	source.tick_committed.emit({"accepted": false, "reason": &"final_approach_generation_mismatch", "generation": 4})
	_check(presenter.get_snapshot().state == &"rejected", "rejection receipt is presented explicitly")
	source.engagement_changed.emit({"generation": 2, "controller": {"final_approach": {"state_id": &"armed"}}})
	_check(presenter.get_snapshot().state == &"rejected", "stale engagement snapshot cannot overwrite newer receipt")
	binding.detach()
	source.final_approach_completed.emit({"accepted": true, "generation": 5})
	_check(not bool(presenter.get_snapshot().get("attached", true)), "detach disconnects future source signals")
	source.snapshot = {"generation": 5, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	_check(bool(binding.attach(source, presenter).get("accepted", false)) and presenter.get_snapshot().state == &"armed", "re-entry reads a fresh caller snapshot")
	binding.detach()
	source = null
	presenter = null
	binding = null
	await process_frame
	if _failures.is_empty():
		print("FINAL_APPROACH_STATUS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
