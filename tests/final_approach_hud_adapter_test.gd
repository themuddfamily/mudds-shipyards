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
	_check(hud.find_child("FinalApproachGuidance", true, false) == null, "armed state waits for a real production measurement")
	var target := {
		"entry_position_half_extents_m": Vector3(20.0, 10.0, 60.0),
		"maximum_attitude_degrees": 12.0,
	}
	source.snapshot = {"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 2, "accepted": true, "controller": {
		"final_approach_aligned": true,
		"observation": {"distance_to_destination_meters": 80.0, "ship_speed_meters_per_second": 9.0},
		"final_approach_measurement": {"position_offset_entry_local_m": Vector3(3.0, 2.0, 4.0), "speed_mps": 9.0, "attitude_degrees": 4.0},
	}})
	var approaching := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(approaching, true, true).get("accepted", false)), "approaching view maps without owning engagement")
	_check(hud.get_planetary_cruise_presentation_report().status_id == &"accelerating", "approaching state uses bounded HUD vocabulary")
	var guidance := hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "LAT LEFT / VERT DOWN / RANGE FWD / ALIGN CORRECT", "positive entry-local offsets and measured attitude produce corrective guidance")
	_check(guidance.focus_mode == Control.FOCUS_NONE and guidance.mouse_filter == Control.MOUSE_FILTER_IGNORE and guidance.get_theme_font_size("font_size") == 14, "raised guidance remains controller and pointer neutral")
	_check(approaching.state == &"approaching", "boolean alignment hint never fabricates aligned state")
	var duplicate := adapter.apply_view(approaching, true, true)
	_check(bool(duplicate.get("accepted", false)) and duplicate.get("reason") == &"duplicate", "same generation and caller state is deduplicated")
	source.tick_committed.emit({"generation": 3, "accepted": true, "controller": {
		"final_approach_measurement": {"position_offset_entry_local_m": Vector3(2.0, 1.0, 3.0), "speed_mps": 5.0, "attitude_degrees": 3.0},
	}})
	var boundary := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(boundary, true, true).get("accepted", false)) and guidance.text == "LAT CENTER / VERT LEVEL / RANGE HOLD / ALIGN HELD", "exact envelope-derived deadband boundaries are steady")
	source.tick_committed.emit({"generation": 4, "accepted": true, "controller": {
		"final_approach_measurement": {"position_offset_entry_local_m": Vector3(-2.01, -1.01, -3.01), "speed_mps": 5.0, "attitude_degrees": 3.01},
	}})
	var reversed := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(reversed, true, true).get("accepted", false)) and guidance.text == "LAT RIGHT / VERT UP / RANGE BACK / ALIGN CORRECT", "negative sign changes and just-outside thresholds reverse corrections explicitly")
	_check(not bool(adapter.apply_view(boundary, true, true).get("accepted", false)) and hud.find_child("FinalApproachGuidance", true, false) == null, "stale source generation clears guidance synchronously")
	_check(bool(adapter.apply_view(reversed, true, true).get("accepted", false)), "current view restores guidance after stale input is fenced")
	var authority := adapter.get_snapshot()
	_check(bool(authority.presentation_only) and not bool(authority.movement_authority) and not bool(authority.landing_authority), "guidance remains presentation-only without movement or landing authority")
	source.tick_committed.emit({"generation": 5, "accepted": false, "reason": &"final_approach_actor_lost"})
	_check(not bool(adapter.apply_view(binding.get_presenter_snapshot(), true, true).get("accepted", false)) and hud.find_child("FinalApproachGuidance", true, false) == null, "real actor-loss rejection clears guidance synchronously")
	source.snapshot = {"generation": 6, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 6, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 1.0, "attitude_degrees": 0.0}}})
	_check(bool(adapter.apply_view(binding.get_presenter_snapshot(), true, true).get("accepted", false)), "fresh actor measurement restores guidance")
	source.tick_committed.emit({"generation": 7, "accepted": false, "reason": &"final_approach_landing_root_lost"})
	_check(not bool(adapter.apply_view(binding.get_presenter_snapshot(), true, true).get("accepted", false)) and hud.find_child("FinalApproachGuidance", true, false) == null, "real berth-loss rejection clears guidance synchronously")
	binding.detach()
	var lost := adapter.apply_view(reversed, true, true)
	_check(not bool(lost.get("accepted", false)) and lost.get("reason") == &"source_lost" and hud.find_child("FinalApproachGuidance", true, false) == null, "actor loss clears guidance and fences future UI updates")
	var replacement_source := FakeCruise.new()
	replacement_source.snapshot = {"generation": 8, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}, "last_result": {"accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 1.0, "attitude_degrees": 0.0}}}}
	var replacement_binding := BindingType.new()
	_check(bool(replacement_binding.attach(replacement_source, PresenterType.new()).get("accepted", false)), "replacement binding attaches")
	_check(bool(adapter.attach(replacement_binding, hud).get("accepted", false)), "adapter reuse starts a fresh binding generation")
	var pre_reuse_view := reversed.duplicate(true)
	_check(adapter.apply_view(pre_reuse_view, true, true).get("reason") == &"stale_binding_generation", "pre-reuse binding generation is rejected")
	var replacement_view := replacement_binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(replacement_view, true, true).get("accepted", false)), "fresh replacement view restores measured guidance")
	var wrong_binding_view := reversed.duplicate(true)
	wrong_binding_view["generation"] = 9
	wrong_binding_view["binding_generation"] = replacement_binding.get_snapshot().generation
	_check(adapter.apply_view(wrong_binding_view, true, true).get("reason") == &"stale_binding_generation" and hud.find_child("FinalApproachGuidance", true, false) == null, "non-current binding view clears replacement guidance synchronously")
	_check(bool(adapter.apply_view(replacement_view, true, true).get("accepted", false)) and hud.find_children("FinalApproachGuidance", "Label", true, false).size() == 1, "current replacement view restores exactly one guidance label")
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
