extends SceneTree

const ProductionBinding := preload("res://tests/audio/ember_audio_snapshot_fixture.gd")
const AudioBinding := preload("res://scripts/audio/ember_surface_loop_audio_production_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []

class FakeEmberRoot:
	extends Node3D
	func get_world_id() -> StringName: return &"ember_moon"

class LegacyOwner:
	extends Node
	signal state_changed(snapshot: Dictionary)
	var observation := {"generation": 0, "state_id": &"idle"}
	func get_snapshot() -> Dictionary:
		return observation.duplicate(true)
	func publish(snapshot: Dictionary) -> void:
		observation = snapshot.duplicate(true)
		state_changed.emit(get_snapshot())

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := ProductionBinding.new()
	var audio := AudioBinding.new()
	root.add_child(owner)
	root.add_child(audio)
	audio.semantic_surface_cue_emitted.connect(_on_cue)
	_check(bool(audio.attach(owner, &"interior").accepted), "real Ember production owner attaches")
	owner.publish({"generation": 1, "state_id": &"running"})
	_check(_has(&"ember_surface_descent_interior"), "production running state maps to descent cue")
	owner.publish({"generation": 1, "state_id": &"descent"})
	owner.publish({"generation": 1, "state_id": &"landed"})
	owner.publish({"generation": 1, "state_id": &"on_foot"})
	_check(_has(&"ember_surface_descent_interior") and _has(&"ember_surface_landed_interior") and _has(&"ember_surface_on_foot_interior"), "descent/landing/on-foot cues emit")
	_check(audio.present_snapshot({"generation": 0, "state_id": &"takeoff"}).reason == &"stale_generation", "stale generation is rejected")
	_check(bool(audio.set_perspective(&"exterior").accepted), "exterior perspective is accepted")
	owner.publish({"generation": 2, "state_id": &"reboarded"})
	owner.publish({"generation": 2, "state_id": &"takeoff"})
	owner.publish({"generation": 2, "state_id": &"ascent"})
	owner.publish({"generation": 2, "state_id": &"orbit_return"})
	_check(_has(&"ember_surface_reboard_exterior") and _has(&"ember_surface_orbit_return_exterior"), "reboard/takeoff/ascent/orbit-return cues emit")
	owner.publish({"generation": 2, "state_id": &"failed", "terminal_reason": &"caller_aborted"})
	_check(_has(&"ember_surface_abort_exterior"), "abort cue emits")
	owner.publish({"generation": 2, "state_id": &"takeoff"})
	_check(_events.size() == 8, "duplicate phase is suppressed")
	_check(int(audio.get_snapshot().maximum_simultaneous_voices) == 2, "two-voice ceiling is retained")
	var ember_root := FakeEmberRoot.new()
	ember_root.position = Vector3(400.0, -250.0, 90.0)
	root.add_child(ember_root)
	var orbital := _altitude_snapshot(3, ember_root, 20_000.0, 12.0, &"descent")
	var low_descent := _altitude_snapshot(3, ember_root, 5_000.0, 12.0, &"descent")
	var surface := _altitude_snapshot(3, ember_root, 0.0, 12.0, &"descent")
	_check(bool(audio.present_snapshot(orbital).accepted), "exact orbital ceiling is presented")
	var orbital_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		orbital_mix.surface_proximity_unitless == 0.0
			and orbital_mix.target_intensity_unitless == 0.0,
		"the airless hull loop is exactly silent at the 20 km ceiling"
	)
	_check(bool(audio.present_snapshot(low_descent).accepted), "same-phase low descent updates continuously")
	var low_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		float(low_mix.surface_proximity_unitless) > 0.0
			and float(low_mix.target_intensity_unitless) > 0.0
			and bool(low_mix.playback_requested)
			and int(low_mix.voice_instance_id) > 0
			and int(low_mix.stream_instance_id) != 0,
		"descent proximity raises a live bounded hull-resonance loop"
	)
	_check(bool(audio.present_snapshot(surface).accepted), "surface-proximate descent is presented")
	var surface_mix := audio.get_snapshot().altitude_transition as Dictionary
	_check(
		float(surface_mix.target_intensity_unitless) > float(low_mix.target_intensity_unitless),
		"hull resonance increases monotonically toward Ember's surface datum"
	)
	_check(
		not bool(surface_mix.has_atmosphere)
			and surface_mix.fog_factor_unitless == 0.0
			and surface_mix.cloud_factor_unitless == 0.0
			and surface_mix.wind_gain_unitless == 0.0,
		"Ember's checked-in airless contract keeps fog, clouds, and wind at exact zero"
	)
	_check(
		bool(audio.present_snapshot({"generation": 3, "phase_id": &"descent"}).accepted)
			and audio.get_snapshot().altitude_transition.intensity_unitless == 0.0
			and not bool(audio.get_snapshot().altitude_transition.playback_requested),
		"loss of actor/root evidence silences the continuous hull loop instead of retaining a ghost voice"
	)
	var on_foot := _altitude_snapshot(3, ember_root, 0.0, 0.0, &"on_foot", &"player")
	_check(bool(audio.present_snapshot(on_foot).accepted), "on-foot surface observation is presented")
	_check(
		audio.get_snapshot().altitude_transition.target_intensity_unitless == 0.0,
		"leaving the ship removes the presentation-only hull resonance"
	)
	var reward_completion := _relay_reward_completion_snapshot(4, 12, 3, 7)
	var unauthenticated := reward_completion.duplicate(true)
	(unauthenticated.relay_reward_commit as Dictionary).erase("authority_receipt")
	var reward_count := _events.count(&"ember_relay_survey_reward_confirmed_exterior")
	_check(bool(audio.present_snapshot(unauthenticated).accepted)
		and _events.count(&"ember_relay_survey_reward_confirmed_exterior") == reward_count
		and audio.get_snapshot().relay_survey_reward_completion.last_result.reason
			== &"invalid_relay_reward_completion",
		"unverified relay reward receipts remain silent")
	_check(bool(audio.present_snapshot(reward_completion).accepted)
		and _has(&"ember_relay_survey_reward_confirmed_exterior"),
		"authenticated persisted relay reward emits a distinct exterior cue")
	reward_count = _events.count(&"ember_relay_survey_reward_confirmed_exterior")
	_check(bool(audio.present_snapshot(reward_completion).accepted)
		and _events.count(&"ember_relay_survey_reward_confirmed_exterior") == reward_count,
		"replayed relay reward receipt is silent")
	_check(audio.present_snapshot(_relay_reward_completion_snapshot(3, 12, 3, 7)).reason
		== &"stale_generation",
		"stale relay reward completion is rejected before cue output")
	_check(bool(audio.set_reduced_dynamic_range(true).accepted), "reduced range is accepted")
	_check(bool(audio.set_perspective(&"interior").accepted), "interior perspective is restored")
	_check(bool(audio.present_snapshot(_relay_reward_completion_snapshot(5, 13, 4, 8)).accepted)
		and _has(&"ember_relay_survey_reward_confirmed_interior"),
		"fresh authenticated reward follows interior routing")
	var reward_snapshot := audio.get_snapshot().relay_survey_reward_completion as Dictionary
	_check(float(reward_snapshot.last_result.intensity) == 0.75
		and int(reward_snapshot.emitted_cue_count) == 2,
		"reduced-range reward cue is accessible and remains replay-safe")
	_check(bool(audio.detach().accepted), "surface audio detaches")
	_check(
		audio.get_snapshot().altitude_transition.intensity_unitless == 0.0
			and not bool(audio.get_snapshot().altitude_transition.playback_requested),
		"detach silences the altitude loop without retaining lifecycle state"
	)
	_check(bool(audio.attach(owner, &"exterior").accepted), "surface audio re-enters")
	audio.detach()
	audio.free()
	owner.free()
	ember_root.free()
	_test_observation_routes()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("EMBER_SURFACE_LOOP_AUDIO_PRODUCTION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _test_observation_routes() -> void:
	var focused := ProductionBinding.new()
	var legacy := LegacyOwner.new()
	var focused_audio := AudioBinding.new()
	var legacy_audio := AudioBinding.new()
	var ember_root := FakeEmberRoot.new()
	for node in [focused, legacy, focused_audio, legacy_audio, ember_root]:
		root.add_child(node)
	var focused_cues: Array = []
	var legacy_cues: Array = []
	focused_audio.semantic_surface_cue_emitted.connect(
		func(cue: StringName, intensity: float): focused_cues.append([cue, intensity]))
	legacy_audio.semantic_surface_cue_emitted.connect(
		func(cue: StringName, intensity: float): legacy_cues.append([cue, intensity]))
	focused_audio.attach(focused)
	legacy_audio.attach(legacy)
	_check(focused.state_changed.get_connections().is_empty()
		and focused.state_invalidated.get_connections().size() == 1
		and legacy.state_changed.get_connections().size() == 1,
		"audio selects lightweight invalidation or legacy payload according to owner capability")
	var observations: Array[Dictionary] = [
		_altitude_snapshot(1, ember_root, 20_000.0, 12.0, &"descent"),
		_altitude_snapshot(1, ember_root, 5_000.0, 12.0, &"descent"),
		_altitude_snapshot(1, ember_root, 0.0, 12.0, &"descent"),
		_altitude_snapshot(1, ember_root, 0.0, 0.0, &"on_foot", &"player"),
		_relay_reward_completion_snapshot(2, 12, 3, 7),
		_relay_reward_completion_snapshot(2, 12, 3, 7),
		{"generation": 3, "state_id": &"failed", "terminal_reason": &"caller_aborted"},
	]
	for observation in observations:
		focused.publish(observation)
		legacy.publish(observation)
		_check(_comparable_audio(focused_audio) == _comparable_audio(legacy_audio)
			and focused_cues == legacy_cues,
			"focused and legacy notifications preserve complete audio state and cue ordering")
	for audio in [focused_audio, legacy_audio]:
		audio.set_perspective(&"interior")
		audio.set_reduced_dynamic_range(true)
	focused.publish(_relay_reward_completion_snapshot(4, 13, 4, 8))
	legacy.publish(_relay_reward_completion_snapshot(4, 13, 4, 8))
	_check(_comparable_audio(focused_audio) == _comparable_audio(legacy_audio)
		and focused_cues == legacy_cues,
		"focused notifications preserve perspective, accessibility and reward replay rules")
	_check(focused.full_snapshot_reads == 0
		and focused.audio_snapshot_reads == observations.size() + 2,
		"attach and every invalidation read fresh audio evidence without full diagnostics")
	var before := focused_audio.get_snapshot()
	focused.state_changed.emit({"generation": 99, "state_id": &"takeoff"})
	_check(focused_audio.get_snapshot() == before,
		"focused owner does not also subscribe to legacy diagnostic payloads")
	for audio in [focused_audio, legacy_audio]:
		audio.detach()
	_check(focused.state_invalidated.get_connections().is_empty()
		and legacy.state_changed.get_connections().is_empty(),
		"detach disconnects both supported notification routes")
	focused_audio.attach(legacy)
	legacy_audio.attach(focused)
	focused.publish({"generation": 5, "state_id": &"on_foot"})
	legacy.publish({"generation": 5, "state_id": &"on_foot"})
	_check(_comparable_audio(focused_audio) == _comparable_audio(legacy_audio),
		"reattaching across owner capabilities preserves lifecycle and presentation")
	for audio in [focused_audio, legacy_audio]:
		audio.detach()
	for node in [focused_audio, legacy_audio, focused, legacy, ember_root]:
		node.free()

func _comparable_audio(audio: Node) -> Dictionary:
	var snapshot: Dictionary = audio.get_snapshot()
	# Each adapter owns its own voice and stream. Check their real handles before
	# removing only those identities from the otherwise exact state comparison.
	for field in ["entry_bed", "altitude_transition"]:
		var layer: Dictionary = snapshot[field]
		_check(int(layer.voice_instance_id) > 0 and int(layer.stream_instance_id) != 0,
			"both observation routes retain a live voice and stream")
		layer.erase("voice_instance_id")
		layer.erase("stream_instance_id")
	return snapshot

func _on_cue(cue_id: StringName, intensity: float) -> void:
	_events.append(cue_id)

func _has(cue_id: StringName) -> bool:
	return _events.has(cue_id)

func _altitude_snapshot(
		generation: int,
		ember_root: Node3D,
		altitude_m: float,
		speed_mps: float,
		phase_id: StringName,
		actor_kind: StringName = &"ship"
	) -> Dictionary:
	return {
		"generation": generation,
		"phase_id": phase_id,
		"identities": {"loaded_scene_instance_id": ember_root.get_instance_id()},
		"last_prepared_evidence": {
			"delta": 0.25,
			"actor_sample": {
				"actor_kind": actor_kind,
				"position": ember_root.global_position + Vector3(0.0, 120_000.0 + altitude_m, 0.0),
			},
			"caller_kinematics": {"velocity_mps": Vector3(0.0, -speed_mps, 0.0)},
		},
	}.duplicate(true)

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

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
