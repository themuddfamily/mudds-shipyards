extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Adapter := preload("res://scripts/audio/cinder_loadmaster_audio_production_binding.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
const Hud := preload("res://scripts/ui/hud.gd")

class MockCinderLoadmasterCraft:
	extends Node
	signal loadmaster_manifest_intent_accepted(receipt: Dictionary)
	signal loadmaster_manifest_cleared(generation: int, reason: StringName)

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
	await process_frame
	_hud = Hud.new()
	root.add_child(_hud)
	await process_frame
	_flow = Flow.new()
	_flow.hud = _hud
	_hud.set_captions_enabled(true)
	_flow._initialize_caption_presentation()
	_service = _flow.get("_caption_presentation_service") as CaptionPresentationService
	_check(_service != null and bool(_hud.get_caption_presentation_report().get("request_sink_bound", false)), "actual HUD uses the single GameFlow-owned caption service")
	director.semantic_cue_emitted.connect(_flow._on_semantic_audio_cue_emitted)
	var craft := MockCinderLoadmasterCraft.new()
	root.add_child(craft)
	var adapter := Adapter.new()
	root.add_child(adapter)
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(adapter.attach(craft).get("accepted", false)), "production adapter attaches")
	_check(bool(director.bind_semantic_audio_source(adapter, &"crew").get("accepted", false)), "AudioDirector binds Cinder as crew source")
	var receipt := {"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1,
		"request_sequence": 4, "manifest_id": &"cinder_manifest", "route_id": &"cinder_route", "ready": true}
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_count(&"cinder_loadmaster_seat_occupied") == 1 and _count(&"cinder_loadmaster_manifest_ready") == 1, "accepted receipt routes once through AudioDirector")
	_check(_stored_count() == 2 and _visible_text() == "! Loadmaster seat occupied", "accepted receipt displays occupied and retains ready in the shared queue")
	var foreign := receipt.duplicate(true)
	foreign.seat_id = &"foreign_station"
	craft.loadmaster_manifest_intent_accepted.emit(foreign)
	_check(_stored_count() == 2 and _events.size() == 2, "foreign receipt adds neither normalized cue nor caption")
	_check(bool(adapter.present_rejected({"reason": &"stale_sequence", "request_sequence": 5}).get("accepted", false)), "rejected result is forwarded")
	craft.loadmaster_manifest_cleared.emit(2, &"role_released")
	_check(_count(&"cinder_loadmaster_rejected") == 1 and _count(&"cinder_loadmaster_released") == 1, "rejected and released cues route once")
	craft.loadmaster_manifest_intent_accepted.emit(receipt)
	_check(_count(&"cinder_loadmaster_manifest_ready") == 1, "duplicate accepted receipt remains deduped")
	adapter.present_rejected({"reason": &"stale_sequence", "request_sequence": 5})
	craft.loadmaster_manifest_cleared.emit(2, &"role_released")
	_check(_stored_count() == 4 and _events.size() == 4, "duplicate receipt rejection and release add no caption")
	_expect_and_expire("Loadmaster seat occupied")
	_expect_and_expire("Loadmaster manifest ready")
	_expect_and_expire("Loadmaster request rejected")
	_expect_and_expire("Loadmaster released")
	_check(_stored_count() == 0 and not bool(_hud.get_caption_presentation_snapshot().get("visible", true)), "shared service expiry retires all four captions in the actual HUD")
	director.detach_semantic_audio_sources()
	craft.loadmaster_manifest_cleared.emit(3, &"ship_detached")
	_check(_events.size() == 4, "detached AudioDirector receives no stale cues")
	_check(_stored_count() == 0, "detached emission cannot revive an expired caption")
	_check(bool(director.bind_semantic_audio_source(adapter, &"crew").get("accepted", false)), "same current production adapter can be rebound for route receipt")
	var route_receipt := receipt.duplicate(true)
	route_receipt.request_sequence = 6
	route_receipt.ready = false
	craft.loadmaster_manifest_intent_accepted.emit(route_receipt)
	_check(_stored_count() == 2 and _count(&"cinder_loadmaster_route_ready") == 1, "distinct route receipt retains both occupied and route-ready captions")
	_expect_and_expire("Loadmaster seat occupied")
	_expect_and_expire("Loadmaster route ready")
	_hud.set_captions_enabled(false)
	_service.set_presentation_flags(false, false)
	var off_receipt := receipt.duplicate(true)
	off_receipt.request_sequence = 7
	craft.loadmaster_manifest_intent_accepted.emit(off_receipt)
	_check(_events.size() == 8 and _stored_count() == 0, "OFF allows normal routed events but submits no caption")
	_hud.set_captions_enabled(true)
	_service.set_presentation_flags(true, false)
	_check(_stored_count() == 0 and _visible_text().is_empty(), "turning captions ON cannot replay the OFF receipt")
	craft.loadmaster_manifest_intent_accepted.emit(off_receipt)
	_check(_events.size() == 8 and _stored_count() == 0, "replayed OFF receipt remains silent after enabling captions")
	var fresh_receipt := receipt.duplicate(true)
	fresh_receipt.request_sequence = 8
	craft.loadmaster_manifest_intent_accepted.emit(fresh_receipt)
	_check(_stored_count() == 2, "fresh current receipt resumes normal caption ingress after enabling")
	_expect_and_expire("Loadmaster seat occupied")
	_expect_and_expire("Loadmaster manifest ready")
	director.detach_semantic_audio_sources()
	adapter.detach()
	director.semantic_cue_emitted.disconnect(_flow._on_semantic_audio_cue_emitted)
	_flow.free()
	_hud.queue_free()
	adapter.queue_free()
	craft.queue_free()
	director.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("CINDER_LOADMASTER_AUDIO_ROUTER_INTEGRATION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _stored_count() -> int:
	return int(_service.get_state_snapshot().get("stored_caption_count", -1))

func _visible_text() -> String:
	var presenter := _hud.get("_caption_presenter") as CaptionPresenter
	if not presenter.visible:
		return ""
	return str((presenter.get("_text_label") as RichTextLabel).text)

func _expect_and_expire(text: String) -> void:
	var snapshot := _service.get_state_snapshot()
	var active := snapshot.get("active_caption", {}) as Dictionary
	_check(
		_visible_text() == "! " + text
		and (_hud.get_caption_presentation_snapshot().get("caption", {}) as Dictionary).get("text", "") == "! " + text
		and str(active.get("speaker", "")) == "crew"
		and int(active.get("priority", -1)) == 90,
		"actual HUD displays %s with the existing intensity-promoted severity and shared priority" % text
	)
	_service.advance_physics(float(active.get("remaining_physics_seconds", 0.0)))

func _count(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.cue_id == cue_id:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
