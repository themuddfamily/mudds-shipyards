extends SceneTree

class FakeCruise:
	extends RefCounted
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)
	var snapshot: Dictionary = {"generation": 1, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

class FakeNodeCruise:
	extends Node
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)
	var snapshot: Dictionary = {"generation": 8, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

const PresenterType := preload("res://scripts/ui/final_approach_status_presenter.gd")
const BindingType := preload("res://scripts/ui/final_approach_status_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []
var _presentation_events: Array[Dictionary] = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var source := FakeCruise.new()
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	binding.presentation_changed.connect(_on_presentation_changed)
	_check(bool(binding.attach(source, presenter, true).get("accepted", false)), "binding attaches through caller signal contract")
	_check(presenter.get_snapshot().state == &"armed", "initial detached source snapshot reaches presenter")
	_check(binding.get_presenter_snapshot().state == &"armed" and _presentation_events.size() == 1, "binding exposes a detached initial presenter view")
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
	_check(_presentation_events.size() == 6 and not bool(_presentation_events[-1].accepted) and _presentation_events[-1].reason == &"stale_generation", "stale input emits one rejection event without replacing the authoritative view")
	_check(binding.get_presenter_snapshot().state == &"rejected", "one-off stale rejection preserves the last valid binding view")
	binding.detach()
	source.final_approach_completed.emit({"accepted": true, "generation": 5})
	_check(not bool(presenter.get_snapshot().get("attached", true)), "detach disconnects future source signals")
	source.snapshot = {"generation": 5, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	_check(bool(binding.attach(source, presenter).get("accepted", false)) and presenter.get_snapshot().state == &"armed", "re-entry reads a fresh caller snapshot")
	_check(binding.get_presenter_snapshot().get("binding_generation", -1) > 0, "re-entry exposes a fresh binding generation")
	binding.detach()
	var node_source := FakeNodeCruise.new()
	root.add_child(node_source)
	_check(bool(binding.attach(node_source, presenter).get("accepted", false)), "binding accepts a production-shaped Node source")
	var before_source_loss := _presentation_events.size()
	node_source.free()
	var saw_source_loss := false
	for index in range(before_source_loss, _presentation_events.size()):
		if _presentation_events[index].get("reason") == &"source_lost":
			saw_source_loss = true
	_check(saw_source_loss and not bool(binding.get_snapshot().attached), "source tree exit emits synchronous loss and detaches without polling")
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


func _on_presentation_changed(view: Dictionary) -> void:
	_presentation_events.append(view.duplicate(true))
