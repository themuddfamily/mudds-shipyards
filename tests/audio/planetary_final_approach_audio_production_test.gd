extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Adapter := preload("res://scripts/audio/planetary_final_approach_audio_production_binding.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
const Hud := preload("res://scripts/ui/hud.gd")

class MockCruise:
	extends Node
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _flow: GameFlow
var _hud: GameHUD
var _service: CaptionPresentationService

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	root.add_child(director)
	_hud = Hud.new()
	root.add_child(_hud)
	await process_frame
	# Component intro and synthetic cruise signals only, not a whole-Main trip.
	_hud.set_reduced_motion(true)
	(_hud.get("_intro_start_button") as Button).pressed.emit()
	var gameplay_hud := _hud.get("_hud") as Control
	for _frame in 8:
		if gameplay_hud.is_visible_in_tree():
			break
		await process_frame
	_check(gameplay_hud.is_visible_in_tree(), "normal Begin Shift action reveals the actual gameplay HUD")
	_flow = Flow.new()
	_flow.hud = _hud
	_hud.set_captions_enabled(true)
	_flow._initialize_caption_presentation()
	_service = _flow.get("_caption_presentation_service") as CaptionPresentationService
	_check(_service != null and bool(_hud.get_caption_presentation_report().get("request_sink_bound", false)), "actual HUD uses the single GameFlow-owned caption service")
	director.semantic_cue_emitted.connect(_flow._on_semantic_audio_cue_emitted)
	director.semantic_cue_emitted.connect(_on_cue)
	var cruise := MockCruise.new()
	var adapter := Adapter.new()
	var router := director.get("_semantic_router") as SemanticAudioCueRouter
	root.add_child(cruise)
	root.add_child(adapter)
	_check(bool(adapter.attach(cruise).get("accepted", false)), "final approach production adapter attaches")
	_check(bool(router.bind_source(adapter, &"planetary").get("accepted", false)), "router binds planetary final approach source")
	cruise.engagement_changed.emit({
		"generation": 1,
		"final_approach": {"target_generation": 1},
		"controller": {"final_approach": {"state_id": &"armed", "reason": &"final_approach_armed"}},
	})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"final_approach", "reason": &"final_approach_activated"}})
	cruise.final_approach_completed.emit({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 9})
	_check(_has(&"planetary_final_approach_armed") and _has(&"planetary_final_approach_alignment_ready") and _has(&"planetary_final_approach_handoff_ready"), "production lifecycle identity combines with the controller phase before routing approach and completion cues")
	cruise.final_approach_completed.emit({"target_generation": 1, "reason": &"final_approach_handoff_ready", "caller_tick": 9})
	_check(_events.size() == 3, "duplicate completion is suppressed")
	_check(_stored_count() == 3 and _visible_text() == "! Final approach armed", "actual HUD displays armed while alignment and handoff remain queued")
	cruise.tick_committed.emit({"accepted": false, "reason": &"location_generation_mismatch", "generation": 20})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed_v2"}})
	_check(_events.size() == 4 and _has(&"planetary_final_approach_armed"), "generic rejection does not poison a later target generation")
	cruise.tick_committed.emit({"accepted": false, "reason": &"final_approach_aborted", "generation": 1, "target_generation": 1})
	_check(_has(&"planetary_final_approach_rejected"), "rejection receipt routes through planetary router")
	_check(int(adapter.get_snapshot().audio.maximum_simultaneous_voices) == 1, "production adapter retains the one-voice reuse ceiling")
	cruise.tick_committed.emit({"accepted": false, "reason": &"final_approach_aborted", "generation": 1, "target_generation": 1})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 0, "state_id": &"armed", "reason": &"final_approach_armed"}})
	_check(_events.size() == 5 and _stored_count() == 5, "duplicate rejection and stale target add neither routed event nor caption")
	_expect_and_expire("Final approach armed")
	_expect_and_expire("Final approach alignment ready")
	_expect_and_expire("Final approach handoff ready")
	_expect_and_expire("Final approach armed")
	_expect_and_expire("Final approach rejected")
	_check(_stored_count() == 0 and _visible_text().is_empty(), "shared expiry retires all final-approach captions from actual HUD")
	_check(bool(router.detach().accepted), "router detaches")
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 2, "state_id": &"armed", "reason": &"final_approach_armed"}})
	_check(_events.size() == 5 and _stored_count() == 0, "detached router receives no final-approach caption")
	_check(bool(adapter.detach().accepted), "adapter detaches")
	_check(bool(adapter.attach(cruise).accepted), "adapter re-enters")
	_check(bool(director.bind_semantic_audio_source(adapter, &"planetary").accepted), "same production adapter rebinds through AudioDirector")
	_hud.set_captions_enabled(false)
	_service.set_presentation_flags(false, false)
	var off_snapshot := {"final_approach": {"target_generation": 3, "state_id": &"armed", "reason": &"final_approach_armed"}}
	cruise.engagement_changed.emit(off_snapshot)
	_check(_events.size() == 6 and _stored_count() == 0, "OFF permits normal routed approach events but submits no caption")
	_hud.set_captions_enabled(true)
	_service.set_presentation_flags(true, false)
	_check(_stored_count() == 0 and _visible_text().is_empty(), "turning ON cannot replay the OFF approach cue")
	cruise.engagement_changed.emit(off_snapshot)
	_check(_events.size() == 6 and _stored_count() == 0, "replayed OFF snapshot remains silent after enabling captions")
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 3, "state_id": &"final_approach", "reason": &"final_approach_activated"}})
	_check(_stored_count() == 1, "fresh current approach resumes normal enabled caption ingress")
	_expect_and_expire("Final approach alignment ready")
	director.detach_semantic_audio_sources()
	adapter.detach()
	director.semantic_cue_emitted.disconnect(_flow._on_semantic_audio_cue_emitted)
	_flow.free()
	_hud.queue_free()
	adapter.queue_free()
	cruise.queue_free()
	director.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("PLANETARY_FINAL_APPROACH_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _stored_count() -> int:
	return int(_service.get_state_snapshot().get("stored_caption_count", -1))

func _visible_text() -> String:
	var presenter := _hud.get("_caption_presenter") as CaptionPresenter
	if not presenter.is_visible_in_tree():
		return ""
	return str((presenter.get("_text_label") as RichTextLabel).text)

func _expect_and_expire(text: String) -> void:
	var active := _service.get_state_snapshot().get("active_caption", {}) as Dictionary
	_check(
		_visible_text() == "! " + text
		and (_hud.get_caption_presentation_snapshot().get("caption", {}) as Dictionary).get("text", "") == "! " + text
		and str(active.get("speaker", "")) == "planetary"
		and int(active.get("priority", -1)) == 90,
		"actual HUD displays %s with existing intensity-promoted severity and shared priority" % text
	)
	_service.advance_physics(float(active.get("remaining_physics_seconds", 0.0)))

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
