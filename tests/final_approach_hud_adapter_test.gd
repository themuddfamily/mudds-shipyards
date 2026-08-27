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
const CAPTURE_DIR := "user://screenshots/final_approach_states"
var _assertions := 0
var _failures: PackedStringArray = []
var _captured_pixels: Array[PackedByteArray] = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var source := FakeCruise.new()
	var presenter := PresenterType.new()
	var binding := BindingType.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	# Capture the production pause-row context rather than an invisible HUD tree.
	hud.set_paused(true)
	await process_frame
	_check(bool(binding.attach(source, presenter).get("accepted", false)), "binding attaches authoritative cruise source")
	var adapter := AdapterType.new()
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter attaches binding to real HUD")
	var armed_view := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(armed_view, true, true).get("accepted", false)), "engaged armed view maps into HUD row")
	_check(hud.get_planetary_cruise_presentation_report().status_text == "QUEUED", "armed request keeps the production engaged control shape")
	var guidance := hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "[ ] APPROACH ARMED — REQUEST ACCEPTED", "armed state reports request acceptance without claiming a lease")
	await _capture_if_requested("01_approach_armed")
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
	guidance = hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "[>] FINAL APPROACH ACTIVE — FOLLOW GUIDANCE\nLAT LEFT / VERT DOWN / RANGE FWD / ALIGN CORRECT", "active final approach adds explicit state shape and corrective guidance")
	await _capture_if_requested("02_active_correction")
	_check(guidance.focus_mode == Control.FOCUS_NONE and guidance.mouse_filter == Control.MOUSE_FILTER_IGNORE and guidance.get_theme_font_size("font_size") == 14, "raised guidance remains controller and pointer neutral")
	_check(approaching.state == &"approaching", "boolean alignment hint never fabricates aligned state")
	var duplicate := adapter.apply_view(approaching, true, true)
	_check(bool(duplicate.get("accepted", false)) and duplicate.get("reason") == &"duplicate", "same generation and caller state is deduplicated")
	source.tick_committed.emit({"generation": 3, "accepted": true, "controller": {
		"final_approach_measurement": {"position_offset_entry_local_m": Vector3(2.0, 1.0, 3.0), "speed_mps": 5.0, "attitude_degrees": 3.0},
	}})
	var boundary := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(boundary, true, true).get("accepted", false)) and guidance.text == "[>] FINAL APPROACH ACTIVE — FOLLOW GUIDANCE\nLAT CENTER / VERT LEVEL / RANGE HOLD / ALIGN HELD", "exact envelope-derived deadband boundaries are centered and held")
	_check(boundary.state == &"approaching", "centered held measurements stay truthful because the presenter never emits an aligned state")
	await _capture_if_requested("03_centered_held")
	source.tick_committed.emit({"generation": 4, "accepted": true, "controller": {
		"final_approach_measurement": {"position_offset_entry_local_m": Vector3(-2.01, -1.01, -3.01), "speed_mps": 5.0, "attitude_degrees": 3.01},
	}})
	var reversed := binding.get_presenter_snapshot()
	_check(bool(adapter.apply_view(reversed, true, true).get("accepted", false)) and guidance.text == "[>] FINAL APPROACH ACTIVE — FOLLOW GUIDANCE\nLAT RIGHT / VERT UP / RANGE BACK / ALIGN CORRECT", "negative sign changes and just-outside thresholds reverse corrections explicitly")
	_check(not bool(adapter.apply_view(boundary, true, true).get("accepted", false)) and hud.find_child("FinalApproachGuidance", true, false) == null, "stale source generation clears guidance synchronously")
	_check(bool(adapter.apply_view(reversed, true, true).get("accepted", false)), "current view restores guidance after stale input is fenced")
	var authority := adapter.get_snapshot()
	_check(bool(authority.presentation_only) and not bool(authority.movement_authority) and not bool(authority.landing_authority), "guidance remains presentation-only without movement or landing authority")
	source.snapshot = {"generation": 5, "engagement_requested": false, "last_reason": &"final_approach_actor_lost", "last_result": {"generation": 5, "accepted": false, "reason": &"final_approach_actor_lost"}, "controller": {"final_approach": {"state_id": &"none"}}}
	source.engagement_changed.emit(source.snapshot)
	_check(bool(adapter.apply_view(binding.get_presenter_snapshot(), false, false).get("accepted", false)), "rejected state maps with its caller-owned disabled cruise controls")
	guidance = hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "[!] APPROACH REJECTED — CHECK STATUS", "rejected state has an explicit warning shape and text cue")
	await _capture_if_requested("04_approach_rejected")
	source.snapshot = {"generation": 6, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 6, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 1.0, "attitude_degrees": 0.0}}})
	_check(bool(adapter.apply_view(binding.get_presenter_snapshot(), true, true).get("accepted", false)), "fresh actor measurement restores guidance")
	source.snapshot = {"generation": 7, "engagement_requested": false, "last_reason": &"final_approach_handoff_ready", "last_result": {"generation": 7, "accepted": true, "reason": &"final_approach_handoff_ready", "controller_release": {"accepted": true}}, "controller": {"final_approach": {"state_id": &"none"}}}
	source.engagement_changed.emit(source.snapshot)
	source.final_approach_completed.emit(source.snapshot.last_result)
	_check(bool(adapter.apply_view(binding.get_presenter_snapshot(), false, false).get("accepted", false)), "released final-envelope handoff maps into the existing cruise row")
	guidance = hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "[#] FINAL ENVELOPE ACCEPTED — HANDOFF", "handoff reports final-envelope acceptance without claiming docking")
	await _capture_if_requested("05_final_envelope_handoff")
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


func _capture_if_requested(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var image := root.get_texture().get_image()
	var row := root.find_child("PlanetaryCruiseRow", true, false) as Control
	var guidance := root.find_child("FinalApproachGuidance", true, false) as Label
	_check(
		row != null and guidance != null and guidance.visible
			and row.get_global_rect().grow(0.01).encloses(guidance.get_global_rect())
			and guidance.get_visible_line_count() == guidance.get_line_count(),
		"HUD feedback for %s is fully enclosed by the production cruise row" % name,
	)
	_check(image.get_size() == Vector2i(1280, 720), "HUD feedback for %s captures at 1280x720" % name)
	var pixels := image.get_data()
	for previous_pixels in _captured_pixels:
		_check(
			pixels != previous_pixels,
			"HUD feedback for %s produces non-identical visible output" % name,
		)
	_captured_pixels.append(pixels)
	_check(
		image.save_png(CAPTURE_DIR.path_join("%s.png" % name)) == OK,
		"Forward+ HUD state capture saves for %s" % name,
	)
