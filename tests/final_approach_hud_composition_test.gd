extends SceneTree

class FakeCruise:
	extends Node
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
	root.add_child(source)
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
	var target := {"entry_position_half_extents_m": Vector3(20.0, 10.0, 60.0), "maximum_attitude_degrees": 12.0}
	source.snapshot = {"generation": 2, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	var measured_tick := {"generation": 2, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3(3.0, -2.0, 8.0), "speed_mps": 6.0, "attitude_degrees": 4.0}}}
	source.tick_committed.emit(measured_tick)
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"accelerating",
		"binding presentation signal updates HUD without polling",
	)
	var guidance := hud.find_child("FinalApproachGuidance", true, false) as Label
	_check(guidance != null and guidance.text == "LAT LEFT / VERT UP / RANGE FWD / ALIGN CORRECT", "production-shaped measurement reaches composed directional guidance")
	hud.set_paused(true)
	hud.set_safe_area_insets(Rect2(Vector2(24.0, 16.0), Vector2(24.0, 16.0)))
	var layout_clean := true
	for viewport: Vector2 in [Vector2(1280.0, 720.0), Vector2(3440.0, 1440.0)]:
		hud.set_ui_scale(0.75)
		var effective := hud.layout_for_viewport(viewport)
		await process_frame
		await process_frame
		var report := hud.get_planetary_cruise_presentation_report()
		var page := report.get("pause_main_rect", Rect2()) as Rect2
		var row := report.get("row_rect", Rect2()) as Rect2
		var guidance_rect := guidance.get_global_rect()
		var safe_rect := Rect2(Vector2(24.0, 16.0), viewport - Vector2(48.0, 32.0))
		layout_clean = layout_clean \
			and is_equal_approx(effective, 0.75) \
			and safe_rect.encloses(page) \
			and page.grow(0.01).encloses(row) \
			and row.grow(0.01).encloses(guidance_rect) \
			and guidance_rect.size.y >= 10.0
	_check(layout_clean and guidance.get_theme_font_size("font_size") == 14, "guidance remains readable and enclosed at 75% UI scale across supported layouts")
	source.engagement_changed.emit({"generation": 1, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}})
	_check(hud.find_child("FinalApproachGuidance", true, false) == null, "stale composed source event clears guidance instead of retaining text")
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit(measured_tick)
	_check(hud.find_child("FinalApproachGuidance", true, false) != null, "current authoritative measurement restores guidance after stale input")
	source.tick_committed.emit({"generation": 3, "accepted": false, "reason": &"final_approach_actor_lost"})
	_check(hud.find_child("FinalApproachGuidance", true, false) == null, "composed actor loss clears guidance synchronously")
	source.snapshot = {"generation": 4, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 4, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 2.0, "attitude_degrees": 0.0}}})
	_check(hud.find_child("FinalApproachGuidance", true, false) != null, "fresh actor and berth restore composed guidance")
	source.tick_committed.emit({"generation": 5, "accepted": false, "reason": &"final_approach_landing_root_lost"})
	_check(hud.find_child("FinalApproachGuidance", true, false) == null, "composed berth loss clears guidance synchronously")
	source.snapshot = {"generation": 6, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 6, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 1.0, "attitude_degrees": 0.0}}})
	source.final_approach_completed.emit({"accepted": true, "reason": &"final_approach_handoff_ready", "generation": 7})
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"braking_to_speed",
		"completion receipt maps to handoff row while preserving engagement",
	)
	_check(hud.find_child("FinalApproachGuidance", true, false) == null, "handoff clears manual guidance after craft authority is released")
	source.engagement_changed.emit({"generation": 6, "controller": {"final_approach": {"state_id": &"armed"}}})
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"braking_to_speed",
		"stale source generation cannot overwrite composed HUD",
	)
	var before_detach: String = str(hud.get_planetary_cruise_presentation_report().status_text)
	_check(bool(composition.detach().get("accepted", false)), "composition detaches both owned presentation layers")
	source.final_approach_completed.emit({"accepted": true, "generation": 8})
	_check(
		hud.get_planetary_cruise_presentation_report().status_text == before_detach
			and not bool(composition.get_snapshot().attached),
		"detached composition ignores future source receipts",
	)
	source.snapshot = {"generation": 9, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"armed"}}}
	_check(
		bool(composition.attach(source, hud, true, false).get("accepted", false)),
		"re-entry attaches a fresh binding and adapter pair",
	)
	_check(
		hud.get_planetary_cruise_presentation_report().status_id == &"ready"
			and int(composition.get_snapshot().get("generation", 0)) > 0,
		"re-entry presents the fresh caller snapshot",
	)
	composition.set_cruise_controls(true, true)
	source.snapshot = {"generation": 10, "engagement_requested": true, "controller": {"final_approach": {"state_id": &"final_approach", "target": target}}}
	source.engagement_changed.emit(source.snapshot)
	source.tick_committed.emit({"generation": 10, "accepted": true, "controller": {"final_approach_measurement": {"position_offset_entry_local_m": Vector3.ZERO, "speed_mps": 1.0, "attitude_degrees": 0.0}}})
	_check(hud.find_child("FinalApproachGuidance", true, false) != null, "re-entered Node source restores measured guidance")
	source.free()
	_check(hud.find_child("FinalApproachGuidance", true, false) == null and not bool(composition.get_snapshot().attached), "production Node source tree exit synchronously clears composed guidance")
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
