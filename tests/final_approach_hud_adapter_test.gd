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
const AdapterType := preload("res://scripts/ui/final_approach_hud_adapter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var source := FakeCruise.new()
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	_check(bool(binding.attach(source, presenter).get("accepted", false)), "binding attaches authoritative cruise source")
	var adapter := AdapterType.new()
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter attaches binding to real HUD")
	_check(bool(adapter.apply_view(presenter.get_snapshot(), true, false).get("accepted", false)), "armed view maps into HUD row")
	_check(hud.get_planetary_cruise_presentation_report().status_text == "READY — EMBER MOON", "armed state is readable in existing cruise row")
	var approaching := presenter.present({"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach"}}, "last_result": {"accepted": true}})
	_check(bool(adapter.apply_view(approaching, true, true).get("accepted", false)), "approaching view maps without owning engagement")
	_check(hud.get_planetary_cruise_presentation_report().status_id == &"accelerating", "approaching state uses bounded HUD vocabulary")
	var duplicate := adapter.apply_view(approaching, true, true)
	_check(bool(duplicate.get("accepted", false)) and duplicate.get("reason") == &"duplicate", "same generation and caller state is deduplicated")
	var stale := presenter.present({"generation": 1, "engagement_requested": false, "controller": {"final_approach": {"state_id": &"armed"}}})
	_check(not bool(adapter.apply_view(stale, true, false).get("accepted", false)), "stale generation cannot overwrite HUD")
	_check(bool(adapter.detach().get("accepted", false)) and not bool(adapter.get_snapshot().attached), "detach fences future UI updates")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FINAL_APPROACH_HUD_ADAPTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
