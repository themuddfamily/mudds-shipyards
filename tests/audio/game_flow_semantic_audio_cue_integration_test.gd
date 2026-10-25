extends SceneTree

class MockHud:
	extends CanvasLayer

	var calls: Array[Dictionary] = []

	func present_semantic_audio_cue(
		cue_id: StringName, source_id: StringName, intensity: float, world_position: Vector3
	) -> bool:
		calls.append({
			"cue_id": cue_id,
			"source_id": source_id,
			"intensity": intensity,
			"world_position": world_position,
		})
		return true


const Flow := preload("res://scripts/game/game_flow.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const HeroScene := preload("res://scenes/ships/torrent_interceptor.tscn")
const DirectorType := preload("res://scripts/audio/audio_director.gd")
var _assertions := 0
var _failures := PackedStringArray()
var _engine_events: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := Flow.new()
	var hud := MockHud.new()
	flow.hud = hud
	flow._on_semantic_audio_cue_emitted(
		&"ship", &"engine_critical", 0.9, Vector3(1.0, 2.0, 3.0)
	)
	_check(hud.calls.size() == 1, "GameFlow forwards one semantic audio cue")
	_check(
		hud.calls[0].cue_id == &"engine_critical"
		and hud.calls[0].source_id == &"ship"
		and is_equal_approx(float(hud.calls[0].intensity), 0.9)
		and hud.calls[0].world_position == Vector3(1.0, 2.0, 3.0),
		"GameFlow preserves cue metadata for HUD presentation"
	)
	var source := FileAccess.get_file_as_string("res://scripts/game/game_flow.gd")
	_check(
		source.contains("_connect_signal_once(audio, &\"semantic_cue_emitted\", _on_semantic_audio_cue_emitted)"),
		"runtime signal wiring uses AudioDirector's normalized stream"
	)
	hud.free()
	flow.free()
	await _test_visible_engine_transitions()
	for failure in _failures:
		push_error(failure)
	print("game_flow_semantic_audio_cue_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _test_visible_engine_transitions() -> void:
	# Compose the shipping endpoints without starting Main's world or settings
	# persistence. GameFlow owns the real service; only its physics clock is manual.
	var flow := Flow.new()
	var hud := HudScene.instantiate() as GameHUD
	var hero := HeroScene.instantiate() as HeroShip
	var director := DirectorType.new() as AudioDirector
	root.add_child(hud)
	root.add_child(hero)
	root.add_child(director)
	await process_frame
	await process_frame
	hero.set_physics_process(false)
	hud.set_reduced_motion(true)
	var begin_button := hud.get("_intro_start_button") as Button
	begin_button.pressed.emit()
	var gameplay_hud := hud.get("_hud") as Control
	for _frame in 8:
		if gameplay_hud.is_visible_in_tree():
			break
		await process_frame
	_check(gameplay_hud.is_visible_in_tree(), "normal Begin Shift action reveals the actual gameplay HUD")
	flow.hud = hud
	flow._initialize_caption_presentation()
	hud.set_captions_enabled(true)
	var service := flow.get("_caption_presentation_service") as CaptionPresentationService
	var initial := flow.get_caption_integration_report()
	var rig := hero.get_node("ShipAudioRig") as ShipAudioRig
	_check(
		bool(rig.get_hero_fleet_audio_snapshot().get("attached", false))
		and int(initial.service_count) == 1 and int(initial.presenter_count) == 1
		and bool(initial.hud_request_sink_bound),
		"real HeroShip auto-binding and real HUD share one GameFlow caption service"
	)
	director.semantic_cue_emitted.connect(flow._on_semantic_audio_cue_emitted)
	director.semantic_cue_emitted.connect(_on_engine_cue)
	_check(
		bool(director.bind_semantic_audio_source(rig, &"ship").get("accepted", false)),
		"real AudioDirector binds the actual hero rig through its semantic router"
	)
	var damage := hero.get_component_damage()
	var engine_position := Vector3.INF
	for component: Dictionary in damage.get_component_states():
		if component.get("id", &"") == &"engine_bay":
			engine_position = component.get("local_position", Vector3.INF) as Vector3
	_check(engine_position.is_finite(), "real hero ledger provides the engine damage location")
	if not engine_position.is_finite():
		director.detach_semantic_audio_sources()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		flow.free()
		hud.free()
		hero.free()
		director.free()
		return
	# Located, already-resolved collision damage changes the actual ledger. Its
	# component signal drives the automatic binding; no cue is sent to the HUD.
	_check(
		bool(damage.record_collision_damage(hero.maximum_hull * 0.12, engine_position).get("accepted", false)),
		"resolved engine damage enters the real component ledger"
	)
	_check(_engine_events.count(&"engine_degraded") == 1, "hero damage emits degraded once through the director")
	var accepted_before := int(flow.get_caption_integration_report().caption_accepted_count)
	damage.record_collision_damage(hero.maximum_hull * 0.01, engine_position)
	# Explicitly observe the same real report twice, including a changed integrity
	# within the existing degraded band (state signals need only fire on changes).
	for _repeat in 2:
		hero.component_damage_changed.emit(
			&"engine_bay", damage.get_component_state(&"engine_bay"),
			damage.get_component_integrity(&"engine_bay")
		)
	_check(
		_engine_events.count(&"engine_degraded") == 1
		and int(flow.get_caption_integration_report().caption_accepted_count) == accepted_before,
		"unchanged degradation bands and repeated component facts add no captions"
	)
	damage.record_collision_damage(hero.maximum_hull * 0.10, engine_position)
	damage.tick_repair(10.0, true)
	_check(
		_engine_events.count(&"engine_degraded") == 1
		and _engine_events.count(&"engine_critical") == 1
		and _engine_events.count(&"engine_recovered") == 1,
		"real damage and repair route each of the three engine transitions exactly once"
	)
	var state := service.get_state_snapshot()
	_check(
		int(state.accepted_event_count) == 5 and int(state.pending_caption_count) == 4,
		"three transition captions queue alongside the two existing damage alarm captions"
	)
	# The active caption is non-preemptive; pending alarm and transition captions
	# follow the unchanged service priority/FIFO policy.
	var expected_texts := [
		"△ Engine degraded", "! Engine critical", "! Engine damage alarm",
		"○ Engine recovered", "○ Engine damage alarm cleared",
	]
	var displayed_ids := PackedStringArray()
	for expected_text: String in expected_texts:
		var snapshot := flow.get_caption_presentation_snapshot()
		var caption := snapshot.get("caption", {}) as Dictionary
		var report := hud.get_caption_presentation_report()
		var stable_id := str(caption.get("stable_id", ""))
		_check(
			bool(snapshot.get("visible", false))
			and snapshot == hud.get_caption_presentation_snapshot()
			and str(caption.get("text", "")) == expected_text
			and str(caption.get("speaker", "")) == "ship"
			and bool(report.get("visible", false))
			and str(report.get("rendered_text", "")) == expected_text
			and (hud.get("_caption_presenter") as Control).is_visible_in_tree()
			and not displayed_ids.has(stable_id),
			"shared service displays %s once in the real visible HUD" % expected_text
		)
		displayed_ids.append(stable_id)
		var expired := service.advance_physics(float(caption.get("remaining_physics_seconds", 0.0)))
		_check(
			(expired.get("expired_stable_ids", PackedStringArray()) as PackedStringArray)
				== PackedStringArray([stable_id]),
			"shared service expires %s exactly once" % expected_text
		)
	_check(
		int(service.get_state_snapshot().expired_event_count) == 5
		and not bool(hud.get_caption_presentation_report().get("visible", false)),
		"the engine transition queue drains and the real caption presenter hides"
	)
	hud.set_captions_enabled(false)
	service.set_presentation_flags(false, false)
	var events_before := _engine_events.size()
	accepted_before = int(flow.get_caption_integration_report().caption_accepted_count)
	damage.record_collision_damage(hero.maximum_hull * 0.22, engine_position)
	damage.tick_repair(10.0, true)
	_check(_engine_events.size() > events_before, "disabled captions retain actual engine source emissions")
	hud.set_captions_enabled(true)
	service.set_presentation_flags(true, false)
	_check(
		int(flow.get_caption_integration_report().caption_accepted_count) == accepted_before
		and int(service.get_state_snapshot().stored_caption_count) == 0
		and not bool(hud.get_caption_presentation_report().get("visible", false)),
		"disabled engine emissions do not enqueue or replay after captions are enabled"
	)
	_check(
		bool(director.unbind_semantic_audio_source(rig, &"ship").get("accepted", false)),
		"engine source detaches from the real semantic router"
	)
	events_before = _engine_events.size()
	damage.record_collision_damage(hero.maximum_hull * 0.12, engine_position)
	_check(
		rig.get_engine_degradation() >= 0.25
		and _engine_events.size() == events_before
		and int(flow.get_caption_integration_report().caption_accepted_count) == accepted_before
		and int(flow.get_caption_integration_report().service_instance_id) == int(initial.service_instance_id),
		"detached real source changes silently while the same shared service remains empty"
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	flow.free()
	hud.free()
	hero.free()
	director.free()
	await process_frame


func _on_engine_cue(
		source_id: StringName, cue_id: StringName, _intensity: float, _position: Vector3
	) -> void:
	if source_id == &"ship":
		_engine_events.append(cue_id)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
