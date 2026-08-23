extends SceneTree

class FakeCruise:
	extends RefCounted
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)
	var snapshot: Dictionary = {"generation": 1, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

const CompositionType := preload("res://scripts/ui/final_approach_hud_composition.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var source := FakeCruise.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	var composition := CompositionType.new()
	_check(
		bool(composition.attach(source, hud, true, false, true).get("accepted", false)),
		"composition attaches source and real HUD with caller controls",
	)
	_check(
		hud.get_planetary_cruise_presentation_report().status_text == "READY — EMBER MOON",
		"initial armed presentation reaches existing HUD cruise row",
	)
	composition.set_cruise_controls(true, true)
	source.snapshot = {"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach"}}}
	source.engagement_changed.emit(source.snapshot)
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"accelerating",
		"binding presentation signal updates HUD without polling",
	)
	source.final_approach_completed.emit({"accepted": true, "reason": &"final_approach_handoff_ready", "generation": 3})
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"braking_to_speed",
		"completion receipt maps to handoff row while preserving engagement",
	)
	source.engagement_changed.emit({"generation": 2, "controller": {"final_approach": {"state_id": &"armed"}}})
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"braking_to_speed",
		"stale source generation cannot overwrite composed HUD",
	)
	var before_detach: String = str(hud.get_planetary_cruise_presentation_report().status_text)
	_check(bool(composition.detach().get("accepted", false)), "composition detaches both owned presentation layers")
	source.final_approach_completed.emit({"accepted": true, "generation": 4})
	_check(
		hud.get_planetary_cruise_presentation_report().status_text == before_detach
			and not bool(composition.get_snapshot().attached),
		"detached composition ignores future source receipts",
	)
	source.snapshot = {"generation": 5, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	_check(
		bool(composition.attach(source, hud, true, false).get("accepted", false)),
		"re-entry attaches a fresh binding and adapter pair",
	)
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"ready"
			and int(composition.get_snapshot().get("generation", 0)) > 0,
		"re-entry presents the fresh caller snapshot",
	)
	composition.detach()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FINAL_APPROACH_HUD_COMPOSITION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
