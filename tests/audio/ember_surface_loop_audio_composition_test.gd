extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const ProductionBinding := preload("res://tests/audio/ember_audio_snapshot_fixture.gd")
const Composition := preload("res://scripts/audio/ember_surface_loop_audio_composition.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")

const PHASE_CAPTIONS := {
	&"descent": [&"ember_surface_descent", "Ember descent"],
	&"landed": [&"ember_surface_landed", "Ember landing complete"],
	&"on_foot": [&"ember_surface_on_foot", "On foot on Ember"],
	&"reboarded": [&"ember_surface_reboard", "Ember craft reboarded"],
	&"takeoff": [&"ember_surface_takeoff", "Ember takeoff"],
	&"ascent": [&"ember_surface_ascent", "Ember ascent"],
	&"orbit_return": [&"ember_surface_orbit_return", "Returning to Ember orbit"],
	&"failed": [&"ember_surface_abort", "Ember surface journey aborted"],
}

class RetainedPlanetarySource:
	extends Node
	signal semantic_surface_cue_emitted(cue_id: StringName, intensity: float)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []
var _flow: GameFlow
var _hud: GameHUD
var _service: CaptionPresentationService
var _displayed_ids := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	var owner := ProductionBinding.new()
	var retained := RetainedPlanetarySource.new()
	var composition := Composition.new()
	root.add_child(director)
	root.add_child(owner)
	root.add_child(retained)
	root.add_child(composition)
	await process_frame
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(director.bind_semantic_audio_source(retained, &"planetary").accepted), "existing planetary source binds")
	_check(bool(composition.attach(director, owner, &"interior").accepted), "real Ember production owner composes")
	_check(composition.get_child_count() == 1, "composition owns one retained adapter child")
	_check(director.get_semantic_audio_binding_count() == 2, "composition adds one planetary source")
	owner.publish({"generation": 1, "state_id": &"landed"})
	_check(_has(&"ember_surface_landed_interior"), "composed surface cue reaches AudioDirector")
	var binding_snapshot: Dictionary = composition.get_snapshot().get("binding", {}) as Dictionary
	_check(binding_snapshot.attached and int(binding_snapshot.maximum_simultaneous_voices) == 2, "composition retains one bounded adapter")
	_check(bool(composition.detach().accepted), "composition detaches")
	_check(composition.get_child_count() == 0, "detach frees the adapter child")
	_check(director.get_semantic_audio_binding_count() == 1, "unrelated planetary source survives targeted detach")
	_check(bool(composition.attach(director, owner, &"exterior").accepted), "composition re-enters")
	_check(composition.get_child_count() == 1, "re-entry recreates one adapter child")
	_check(director.get_semantic_audio_binding_count() == 2, "re-entry registers exactly one source")
	owner.publish({"generation": 2, "state_id": &"ascent"})
	_check(_has(&"ember_surface_ascent_exterior"), "re-entry cue reaches director")
	composition.detach()
	director.detach_semantic_audio_sources()
	composition.free()
	owner.free()
	retained.free()
	director.free()
	await _test_visible_ember_captions()
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURFACE_LOOP_AUDIO_COMPOSITION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _test_visible_ember_captions() -> void:
	# Accepted component-owner observations, not a physical planetary journey.
	# The real guarded owner notification, composition and audio adapter remain
	# responsible for semantic admission. Only shared caption time is manual.
	_events.clear()
	var director := Director.new()
	var owner := ProductionBinding.new()
	var composition := Composition.new()
	_hud = HudScene.instantiate() as GameHUD
	root.add_child(director)
	root.add_child(owner)
	root.add_child(composition)
	root.add_child(_hud)
	await process_frame
	_hud.set_reduced_motion(true)
	(_hud.get("_intro_start_button") as Button).pressed.emit()
	var gameplay_hud := _hud.get("_hud") as Control
	for _frame in 8:
		if gameplay_hud.is_visible_in_tree():
			break
		await process_frame
	_check(gameplay_hud.is_visible_in_tree(), "normal Begin Shift reveals the actual gameplay HUD")
	_flow = Flow.new()
	_flow.hud = _hud
	_hud.set_captions_enabled(true)
	_flow._initialize_caption_presentation()
	_service = _flow.get("_caption_presentation_service") as CaptionPresentationService
	var initial := _flow.get_caption_integration_report()
	_check(
		int(initial.service_count) == 1 and int(initial.presenter_count) == 1
		and bool(initial.hud_request_sink_bound),
		"Ember composition uses one real GameFlow caption service and HUD presenter"
	)
	director.semantic_cue_emitted.connect(_on_cue)
	director.semantic_cue_emitted.connect(_flow._on_semantic_audio_cue_emitted)
	_check(bool(composition.attach(director, owner, &"interior").accepted), "visible Ember fixture attaches the production composition")
	var generation := 3
	for perspective: StringName in [&"interior", &"exterior"]:
		_check(bool(composition.set_perspective(perspective).accepted), "%s perspective uses the production adapter" % perspective)
		for phase: StringName in PHASE_CAPTIONS:
			var contract := PHASE_CAPTIONS[phase] as Array
			var cue_id := StringName("%s_%s" % [contract[0], perspective])
			var observation := {"generation": generation, "state_id": phase}
			var before := _events.size()
			owner.publish(observation)
			_check(
				_events.size() == before + 1 and _events.back() == cue_id,
				"guarded owner routes %s once through composition and AudioDirector" % cue_id
			)
			owner.publish(observation)
			_check(_events.size() == before + 1, "unchanged %s observation adds no caption" % cue_id)
			_expect_and_expire(str(contract[1]), cue_id)
		# Revisit an already-seen on-foot phase so reward admission is tested
		# separately, using the same authenticated/persisted receipt fixture as
		# ember_surface_loop_audio_production_test.gd.
		var reward := _relay_reward_completion_snapshot(generation, generation + 10, generation, generation + 20)
		var unverified := reward.duplicate(true)
		(unverified.relay_reward_commit as Dictionary).erase("authority_receipt")
		var before_reward := _events.size()
		owner.publish(unverified)
		var binding := composition.get_child(0)
		_check(
			_events.size() == before_reward
			and binding.get_snapshot().relay_survey_reward_completion.last_result.reason == &"invalid_relay_reward_completion",
			"missing reward authority receipt remains silent for %s" % perspective
		)
		var refused := reward.duplicate(true)
		refused.relay_reward_commit.commit_receipt.persistence.accepted = false
		owner.publish(refused)
		_check(
			_events.size() == before_reward
			and int(_service.get_state_snapshot().stored_caption_count) == 0,
			"refused reward persistence cannot enqueue a %s caption" % perspective
		)
		owner.publish(reward)
		var reward_cue := StringName("ember_relay_survey_reward_confirmed_%s" % perspective)
		_check(
			_events.size() == before_reward + 1 and _events.back() == reward_cue,
			"authenticated persisted reward routes the actual %s semantic cue" % perspective
		)
		owner.publish(reward)
		_check(_events.size() == before_reward + 1, "replayed %s reward receipt adds no caption" % perspective)
		_expect_and_expire("Ember relay survey reward confirmed", reward_cue)
		owner.publish(_relay_reward_completion_snapshot(generation - 1, generation + 10, generation, generation + 20))
		_check(
			_events.size() == before_reward + 1
			and int(_service.get_state_snapshot().stored_caption_count) == 0,
			"stale %s owner generation cannot enqueue a phase or reward caption" % perspective
		)
		generation += 1
	_check(
		_events.size() == 18 and _displayed_ids.size() == 18
		and int(_service.get_state_snapshot().accepted_event_count) == 18
		and int(_service.get_state_snapshot().expired_event_count) == 18
		and int(_flow.get_caption_integration_report().service_instance_id) == int(initial.service_instance_id),
		"all eighteen authored perspective cues display and expire once through the same service"
	)
	_hud.set_captions_enabled(false)
	_service.set_presentation_flags(false, false)
	var events_before := _events.size()
	owner.publish({"generation": generation, "state_id": &"landed"})
	_check(
		_events.size() == events_before + 1 and _events.back() == &"ember_surface_landed_exterior"
		and int(_service.get_state_snapshot().stored_caption_count) == 0,
		"caption OFF preserves a distinct actual phase emission without storing a caption"
	)
	events_before = _events.size()
	var disabled_reward := _relay_reward_completion_snapshot(generation, 30, 6, 40)
	owner.publish(disabled_reward)
	_check(_events.size() == events_before + 2, "caption OFF preserves actual reward and phase source emissions")
	_hud.set_captions_enabled(true)
	_service.set_presentation_flags(true, false)
	owner.publish(disabled_reward)
	_check(
		int(_service.get_state_snapshot().accepted_event_count) == 18
		and int(_service.get_state_snapshot().stored_caption_count) == 0
		and not bool(_hud.get_caption_presentation_report().get("visible", false)),
		"disabled Ember emissions do not enqueue or replay after re-enabling captions"
	)
	composition.detach()
	events_before = _events.size()
	owner.publish({"generation": generation + 1, "state_id": &"landed"})
	_check(
		_events.size() == events_before and director.get_semantic_audio_binding_count() == 0
		and int(_service.get_state_snapshot().stored_caption_count) == 0,
		"detached Ember owner observations cannot reach the director or shared caption service"
	)
	director.semantic_cue_emitted.disconnect(_flow._on_semantic_audio_cue_emitted)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_flow.free()
	_hud.free()
	composition.free()
	owner.free()
	director.free()
	await process_frame

func _expect_and_expire(text: String, cue_id: StringName) -> void:
	var snapshot := _service.get_presentation_snapshot()
	var caption := snapshot.get("caption", {}) as Dictionary
	var stable_id := str(caption.get("stable_id", ""))
	var presenter := _hud.get("_caption_presenter") as Control
	var report := _hud.get_caption_presentation_report()
	_check(
		int(_service.get_state_snapshot().stored_caption_count) == 1
		and bool(snapshot.get("visible", false)) and presenter.is_visible_in_tree()
		and snapshot == _hud.get_caption_presentation_snapshot()
		and str(caption.get("text", "")) == "! " + text
		and str(report.get("rendered_text", "")) == "! " + text
		and str(caption.get("speaker", "")) == "planetary"
		and int(caption.get("priority", -1)) == 90
		and not _displayed_ids.has(stable_id),
		"real HUD displays %s once with unchanged intensity-promoted severity" % cue_id
	)
	_displayed_ids.append(stable_id)
	var expired := _service.advance_physics(float(caption.get("remaining_physics_seconds", 0.0)))
	_check(
		(expired.get("expired_stable_ids", PackedStringArray()) as PackedStringArray) == PackedStringArray([stable_id])
		and int(_service.get_state_snapshot().stored_caption_count) == 0
		and not bool(_hud.get_caption_presentation_report().get("visible", false)),
		"same shared service expires %s exactly once without queue overflow" % cue_id
	)

func _relay_reward_completion_snapshot(
		owner_generation: int, host_generation: int,
		attachment_generation: int, activity_generation: int
	) -> Dictionary:
	return {
		"generation": owner_generation,
		"state_id": &"on_foot",
		"relay_reward_commit": {
			"authority_commit_count": 1,
			"persistence_commit_count": 1,
			"authority_receipt": {"commit_id": "test-%d" % activity_generation},
			"commit_receipt": {
				"owner_generation": owner_generation,
				"host_generation": host_generation,
				"host_attachment_generation": attachment_generation,
				"activity_generation": activity_generation,
				"authority": {"commit_id": "test-%d" % activity_generation},
				"persistence": {"accepted": true},
			},
		},
	}.duplicate(true)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
