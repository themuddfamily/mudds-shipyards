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
	var armed_view := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(armed_view, true, false).get("accepted", false)), "armed view maps into HUD row")
	_check(hud.get_planetary_cruise_presentation_report().status_text == "READY — EMBER MOON", "armed state is readable in existing cruise row")
	var armed_guidance := hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(armed_guidance != null and armed_guidance.text == "LAT CENTER  //  VERT HOLD  //  ALIGN ACQUIRE", "armed approach gives steady colour-independent lateral, vertical, and alignment guidance")
	_check(armed_guidance.focus_mode == Control.FOCUS_NONE and armed_guidance.mouse_filter == Control.MOUSE_FILTER_IGNORE, "guidance preserves controller focus and pointer behavior")
	source.snapshot = {"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach"}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 2, "accepted": true, "controller": {"final_approach_aligned": false}})
	var approaching := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(approaching, true, true).get("accepted", false)), "approaching view maps without owning engagement")
	_check(hud.get_planetary_cruise_presentation_report().status_id == &"accelerating", "approaching state uses bounded HUD vocabulary")
	_check(armed_guidance.text == "LAT CENTER  //  VERT DESCEND  //  ALIGN CORRECT", "active approach gives readable manual correction guidance without flashing")
	var duplicate := adapter.apply_view(approaching, true, true)
	_check(bool(duplicate.get("accepted", false)) and duplicate.get("reason") == &"duplicate", "same generation and caller state is deduplicated")
	_check(not bool(adapter.apply_view(armed_view, true, false).get("accepted", false)) and armed_guidance.text.contains("VERT DESCEND"), "stale source generation cannot overwrite guidance")
	var authority := adapter.get_snapshot()
	_check(bool(authority.presentation_only) and not bool(authority.movement_authority) and not bool(authority.landing_authority), "guidance remains presentation-only without movement or landing authority")
	binding.detach()
	var lost := adapter.apply_view(approaching, true, true)
	_check(not bool(lost.get("accepted", false)) and lost.get("reason") == &"source_lost" and hud.find_child("FinalApproachGuidance", true, false) == null, "actor loss clears guidance and fences future UI updates")
	var replacement_source := FakeCruise.new()
	var replacement_binding := BindingType.new()
	_check(bool(replacement_binding.attach(replacement_source, PresenterType.new()).get("accepted", false)), "replacement binding attaches")
	_check(bool(adapter.attach(replacement_binding, hud).get("accepted", false)), "adapter reuse starts a fresh binding generation")
	var pre_reuse_view := approaching.duplicate(true)
	_check(adapter.apply_view(pre_reuse_view, true, true).get("reason") == &"stale_binding_generation", "pre-reuse binding generation is rejected")
	_check(bool(adapter.apply_view(replacement_binding.get_presenter_snapshot(), true, false).get("accepted", false)), "fresh replacement view restores guidance")
	_check(hud.find_children("FinalApproachGuidance", "Label", true, false).size() == 1, "reuse keeps exactly one guidance label")
	_check(bool(adapter.detach().get("accepted", false)) and not bool(adapter.get_snapshot().attached) and hud.find_child("FinalApproachGuidance", true, false) == null, "detach clears guidance and fences future UI updates")
	replacement_binding.detach()
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
