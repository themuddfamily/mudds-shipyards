extends SceneTree

const RIG_SCENE := preload("res://scenes/audio/ship_audio_rig.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")
const JOVIAN_DEFINITION := preload("res://assets/ships/jovian_provisional.tres")


## Deterministic backend seams: both represent a named non-Dummy driver whose
## latency query returns zero. The first uses the real engine playback request;
## the second models that named backend rejecting the requested handle.
class ZeroLatencyQueueRig extends ShipAudioRig:
	func _detect_playback_queue_candidate() -> bool:
		return ShipAudioRig._is_playback_queue_candidate("ZeroLatencyTest", 0.0)


class RejectingZeroLatencyQueueRig extends ShipAudioRig:
	func _detect_playback_queue_candidate() -> bool:
		return ShipAudioRig._is_playback_queue_candidate("ZeroLatencyTest", 0.0)

	func _request_player_playback(_player: AudioStreamPlayer3D) -> bool:
		return false


var _failures: Array[String] = []
var _assertions := 0
var _test_root: Node3D
var _cue_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "ShipAudioRigTestRoot"
	root.add_child(_test_root)

	var rigs := await _build_profile_roster()
	if rigs.size() != 3:
		_finish()
		return

	_test_declared_identity(rigs)
	await _test_profile_distinction(rigs)
	await _test_zero_latency_queue_candidate_and_playback_outcomes()
	_test_spatial_voice_and_budget_contract(rigs[ShipAudioRig.PROFILE_STANDARD_FIGHTER])
	_test_state_transitions(rigs[ShipAudioRig.PROFILE_STANDARD_FIGHTER])
	await _test_cue_contract_and_budget(rigs[ShipAudioRig.PROFILE_STANDARD_FIGHTER])
	await _test_fail_red_corruption()
	await _test_detach_reentry_release_and_cleanup()

	for rig_value in rigs.values():
		var rig := rig_value as ShipAudioRig
		if is_instance_valid(rig):
			rig.queue_free()
	await process_frame
	await process_frame
	_test_root.queue_free()
	await process_frame
	_finish()


func _build_profile_roster() -> Dictionary:
	var rigs := {}
	for declared_id in ShipAudioRig.get_declared_profile_ids():
		var rig := _make_rig(StringName(declared_id), "Roster_%s" % declared_id)
		if rig != null:
			rigs[StringName(declared_id)] = rig
	await process_frame
	return rigs


func _make_rig(profile: StringName, label: String) -> ShipAudioRig:
	var rig := RIG_SCENE.instantiate() as ShipAudioRig
	if rig == null:
		_check(false, "%s scene instantiates as ShipAudioRig" % label)
		return null
	rig.name = label
	rig.rig_id = StringName("%s_audio" % label.to_lower())
	rig.profile_id = profile
	rig.maximum_distance = 144.0
	rig.reference_distance = 4.5
	_test_root.add_child(rig)
	return rig


func _test_declared_identity(rigs: Dictionary) -> void:
	var exact_ids := PackedStringArray([
		"standard_fighter",
		"efficient_twin_recon",
		"heavy_quad_freighter",
	])
	_check(ShipAudioRig.get_declared_profile_ids() == exact_ids, "public profile roster exposes the three exact ShipDefinition audio_profile_id values")
	var definition_profile_ids := PackedStringArray([
		str(TORRENT_DEFINITION.get("audio_profile_id")),
		str(ARROW_DEFINITION.get("audio_profile_id")),
		str(JOVIAN_DEFINITION.get("audio_profile_id")),
	])
	_check(definition_profile_ids == exact_ids, "declared rig profiles exactly match the three live ShipDefinition resources")
	for profile in exact_ids:
		_check(ShipAudioRig.is_declared_profile_id(StringName(profile)), "%s is accepted as an exact declared profile" % profile)
	_check(not ShipAudioRig.is_declared_profile_id(&"Standard_Fighter"), "profile validation is case-sensitive")
	_check(not ShipAudioRig.is_declared_profile_id(&"standard-fighter"), "profile validation rejects punctuation aliases")
	_check(not ShipAudioRig.is_declared_profile_id(&"standard_fighter "), "profile validation rejects trailing-space aliases")

	for profile in exact_ids:
		var rig := rigs[StringName(profile)] as ShipAudioRig
		var audit := rig.get_audit_report()
		_check(rig.get_component_id() == &"ship-audio-rig", "%s exposes the stable reusable component ID" % profile)
		_check(rig.get_profile_id() == StringName(profile), "%s consumes and preserves its exact configured profile ID" % profile)
		_check(rig.is_in_group(&"ship_audio_rig") and bool(rig.get_meta(&"ship_audio_rig", false)), "%s participates in explicit ship-audio discovery" % profile)
		_check(str(rig.get_meta(&"profile_id", "")) == profile, "%s root metadata matches its immutable built profile" % profile)
		_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "%s passes the complete initial public audit" % profile)
		var evidence := audit.evidence as Dictionary
		_check(str(evidence.design_origin) == "project_original_procedural_audio" and not bool(evidence.historically_supported), "%s records modern procedural provenance without a historical-audio claim" % profile)
		_check("No surviving source" in str(evidence.content_note), "%s states the historical audio evidence boundary" % profile)

	var invalid := _make_rig(&"unknown_profile", "InvalidProfile")
	if invalid != null:
		var invalid_audit := invalid.get_audit_report()
		_check(not bool(invalid_audit.valid) and _errors_contain(invalid_audit.errors, "profile_id"), "unknown profile fails red without an implicit fallback claim")
		_check(not bool(invalid_audit.synthesis.resources_ready), "unknown profile does not synthesize mislabeled fallback resources")
		invalid.queue_free()

	var invalid_bounds := RIG_SCENE.instantiate() as ShipAudioRig
	if invalid_bounds != null:
		invalid_bounds.name = "InvalidBounds"
		invalid_bounds.rig_id = &"invalid_bounds_audio"
		invalid_bounds.profile_id = ShipAudioRig.PROFILE_STANDARD_FIGHTER
		invalid_bounds.maximum_distance = 8.0
		invalid_bounds.reference_distance = 30.0
		_test_root.add_child(invalid_bounds)
		var bounds_audit := invalid_bounds.get_audit_report()
		_check(not bool(bounds_audit.valid) and _errors_contain(bounds_audit.errors, "greater than reference_distance"), "individually finite distances still fail when the maximum does not exceed the reference distance")
		invalid_bounds.queue_free()


func _test_profile_distinction(rigs: Dictionary) -> void:
	var fingerprints_by_profile := {}
	var base_frequencies := PackedFloat32Array()
	var idle_volumes := PackedFloat32Array()
	for profile in ShipAudioRig.get_declared_profile_ids():
		var rig := rigs[StringName(profile)] as ShipAudioRig
		var profile_report := rig.get_profile_report()
		var synthesis := rig.get_synthesis_report()
		var fingerprints := synthesis.fingerprints_sha256 as Dictionary
		fingerprints_by_profile[StringName(profile)] = fingerprints.duplicate(true)
		base_frequencies.append(float(profile_report.base_frequency_hz))
		idle_volumes.append((rig.get_node("ThrustIdle") as AudioStreamPlayer3D).volume_db)
		_check(fingerprints.size() == 12, "%s owns four loop and eight cue fingerprints" % profile)
		var every_fingerprint_complete := true
		for resource_id in fingerprints:
			every_fingerprint_complete = every_fingerprint_complete and str(fingerprints[resource_id]).length() == 64
		_check(every_fingerprint_complete, "%s exposes complete SHA-256 fingerprints for every resident waveform" % profile)

	_check(base_frequencies[0] != base_frequencies[1] and base_frequencies[1] != base_frequencies[2] and base_frequencies[0] != base_frequencies[2], "all three profiles publish measurably different engine fundamentals")
	_check(idle_volumes[0] != idle_volumes[1] and idle_volumes[1] != idle_volumes[2], "all three profiles publish measurably different idle mix levels")
	_check(fingerprints_by_profile[ShipAudioRig.PROFILE_STANDARD_FIGHTER] != fingerprints_by_profile[ShipAudioRig.PROFILE_EFFICIENT_TWIN_RECON], "standard fighter and efficient twin recon generate distinct complete waveform sets")
	_check(fingerprints_by_profile[ShipAudioRig.PROFILE_STANDARD_FIGHTER] != fingerprints_by_profile[ShipAudioRig.PROFILE_HEAVY_QUAD_FREIGHTER], "standard fighter and heavy quad freighter generate distinct complete waveform sets")
	_check(fingerprints_by_profile[ShipAudioRig.PROFILE_EFFICIENT_TWIN_RECON] != fingerprints_by_profile[ShipAudioRig.PROFILE_HEAVY_QUAD_FREIGHTER], "efficient twin recon and heavy quad freighter generate distinct complete waveform sets")

	var twin := _make_rig(ShipAudioRig.PROFILE_STANDARD_FIGHTER, "DeterministicTwin")
	await process_frame
	if twin != null:
		_check((twin.get_synthesis_report().fingerprints_sha256 as Dictionary) == fingerprints_by_profile[ShipAudioRig.PROFILE_STANDARD_FIGHTER], "equal profile inputs regenerate byte-identical deterministic waveform sets")
		twin.queue_free()
		await process_frame


func _test_zero_latency_queue_candidate_and_playback_outcomes() -> void:
	_check(ShipAudioRig._is_playback_queue_candidate("ALSA", 0.0), "named non-Dummy backend remains a queue candidate when its latency query returns zero")
	_check(not ShipAudioRig._is_playback_queue_candidate("Dummy", 0.0), "Dummy backend remains fail-closed even with finite latency telemetry")
	_check(not ShipAudioRig._is_playback_queue_candidate("", 0.0), "missing backend identity remains fail-closed")

	var accepting := RIG_SCENE.instantiate() as ShipAudioRig
	if accepting != null:
		accepting.set_script(ZeroLatencyQueueRig)
		accepting.name = "ZeroLatencyQueueAcceptance"
		accepting.rig_id = &"zero_latency_acceptance_audio"
		accepting.profile_id = ShipAudioRig.PROFILE_STANDARD_FIGHTER
		_test_root.add_child(accepting)
		await process_frame
		_check(bool(accepting.get_performance_report().playback_queue_allowed), "zero-latency named-backend seam reaches queue-candidate state")
		accepting.set_engine_running(true, false)
		var idle_player := accepting.get_node("ThrustIdle") as AudioStreamPlayer3D
		_check(idle_player.playing and idle_player.stream != null, "successful play request retains its owned loop playback handle")
		_check(accepting.play_weapon_fire(), "successful play request reports queue acceptance on the zero-latency named-backend seam")
		var accepting_state := accepting.get_state_snapshot()
		_check(
			(accepting_state.queued_voice_ids as PackedStringArray).has("combat_cue_voice")
			and (accepting_state.active_cues_by_voice as Dictionary).get(&"combat_cue_voice", &"") == ShipAudioRig.CUE_FIRE,
			"successful transient request retains exact active-cue ownership"
		)
		var accepting_performance := accepting.get_performance_report()
		_check(not bool(accepting_performance.output_audibility_verified) and str(accepting_performance.output_claim_scope) == "engine_queue_state_not_audibility", "zero-latency queue acceptance remains explicitly narrower than audibility")
		accepting.queue_free()
		await process_frame

	var rejecting := RIG_SCENE.instantiate() as ShipAudioRig
	if rejecting != null:
		rejecting.set_script(RejectingZeroLatencyQueueRig)
		rejecting.name = "ZeroLatencyQueueRejection"
		rejecting.rig_id = &"zero_latency_rejection_audio"
		rejecting.profile_id = ShipAudioRig.PROFILE_STANDARD_FIGHTER
		_test_root.add_child(rejecting)
		await process_frame
		_check(bool(rejecting.get_performance_report().playback_queue_allowed), "rejecting named-backend seam begins as a queue candidate")
		_cue_events.clear()
		rejecting.cue_requested.connect(_on_cue_requested)
		_check(not rejecting.play_weapon_fire(), "backend play rejection reports that no transient was queued")
		var rejected_state := rejecting.get_state_snapshot()
		_check(
			not bool(rejected_state.playback_queue_allowed)
			and (rejected_state.active_cues_by_voice as Dictionary).is_empty()
			and _players_stopped_and_detached(rejecting),
			"backend play rejection degrades atomically to detached silence"
		)
		_check(_cue_events.size() == 1 and not bool(_cue_events[0].playback_queued), "backend play rejection emits the exact false queue outcome")
		rejecting.set_engine_running(true, false)
		_check(
			(rejecting.get_state_snapshot().desired_loop_layers as PackedStringArray) == PackedStringArray(["thrust_idle"])
			and _players_stopped_and_detached(rejecting),
			"degraded backend preserves desired loop state without retry churn or pinned streams"
		)
		_check(bool(rejecting.get_audit_report().valid), "settled play-rejection fallback remains deeply auditable")
		rejecting.queue_free()
		await process_frame


func _test_spatial_voice_and_budget_contract(rig: ShipAudioRig) -> void:
	var players := rig.find_children("*", "AudioStreamPlayer3D", true, false)
	_check(players.size() == 6, "rig owns exactly four loop voices and two bounded transient voices")
	var cue_timers := rig.find_children("*", "Timer", true, false)
	var timers_bounded := cue_timers.size() == 2
	for candidate in cue_timers:
		var timer := candidate as Timer
		timers_bounded = timers_bounded and timer.one_shot and not timer.autostart and timer.process_callback == Timer.TIMER_PROCESS_IDLE and timer.is_stopped()
	_check(timers_bounded, "rig owns exactly two stopped one-shot cue-expiry timers")
	_check(rig.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "rig contains no non-positional fallback players")
	_check(rig.find_children("*", "CollisionObject3D", true, false).is_empty(), "ship-local audio cannot alter flight or boarding collision")
	var expected_buses := {
		"ThrustIdle": &"Engines",
		"ThrustLoad": &"Engines",
		"ThrustBoost": &"Engines",
		"DamageAlarm": &"UI",
		"EngineCueVoice": &"Engines",
		"CombatCueVoice": &"Weapons",
	}
	var every_player_bounded := true
	for candidate in players:
		var player := candidate as AudioStreamPlayer3D
		every_player_bounded = every_player_bounded \
			and player.bus == expected_buses[player.name] \
			and player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE \
			and is_finite(player.max_distance) and is_equal_approx(player.max_distance, 144.0) \
			and is_finite(player.unit_size) and is_equal_approx(player.unit_size, 4.5) \
			and player.max_distance > player.unit_size \
			and player.max_polyphony == 1 \
			and player.area_mask == 0 \
			and player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED \
			and not player.autoplay and not player.emission_angle_enabled \
			and player.position.is_equal_approx(Vector3.ZERO)
	_check(every_player_bounded, "all six voices retain exact buses and finite ship-local inverse-distance bounds")

	var spatial := rig.get_spatial_contract()
	_check(str(spatial.origin) == "ship_local_component_position" and str(spatial.orientation) == "omnidirectional_rotation_independent", "public contract fixes one rotation-independent ship-local acoustic origin")
	_check(bool(spatial.configuration_current) and is_equal_approx(float(spatial.maximum_distance), 144.0), "spatial report exposes the immutable live distance configuration")
	var synthesis := rig.get_synthesis_report()
	_check(bool(synthesis.resources_ready) and int(synthesis.loop_template_count) == 4 and int(synthesis.cue_template_count) == 8, "profile retains exactly four loops and eight bounded one-shots")
	_check(int(synthesis.resident_sample_bytes) == 145680 and int(synthesis.expected_resident_sample_bytes) == 145680, "resident raw PCM report exactly matches all declared deterministic durations")
	var seam_report := synthesis.loop_seams_pcm as Dictionary
	var every_loop_seam_bounded := seam_report.size() == 4
	for loop_id in seam_report:
		every_loop_seam_bounded = every_loop_seam_bounded and bool(seam_report[loop_id].available) and bool(seam_report[loop_id].bounded) and int(seam_report[loop_id].seam_delta) <= int(seam_report[loop_id].maximum_adjacent_delta) + 32
	_check(every_loop_seam_bounded, "all four forward loops wrap within an ordinary adjacent-sample step instead of clicking at the seam")
	var performance := rig.get_performance_report()
	_check(int(performance.maximum_simultaneous_voices) == 6 and int(performance.maximum_simultaneous_transients) == 2 and int(performance.cue_expiry_timer_count) == 2, "performance contract proves the strict six-voice/two-transient/two-expiry-timer ceiling")
	_check(bool(performance.within_resident_budget) and int(performance.resident_byte_budget) == 163840 and str(performance.resident_byte_budget_scope) == "component_owned_raw_pcm_data", "all twelve component-owned PCM buffers stay inside the explicitly scoped 160 KiB ceiling")
	_check(AudioServer.get_bus_index(&"Engines") >= 0 and AudioServer.get_bus_index(&"Weapons") >= 0 and AudioServer.get_bus_index(&"UI") >= 0, "every declared ship-audio bus resolves in the active AudioServer layout")
	_check(not bool(performance.per_frame_script_processing) and not bool(performance.per_physics_frame_script_processing), "event-driven rig adds no frame or physics-frame callback")


func _test_state_transitions(rig: ShipAudioRig) -> void:
	var initial_generation := int(rig.get_synthesis_report().generation_count)
	var initial := rig.get_state_snapshot()
	_check(not bool(initial.engine_running) and is_zero_approx(float(initial.throttle)) and (initial.desired_loop_layers as PackedStringArray).is_empty(), "rig begins silent with no implied engine state")
	_check(rig.set_engine_running(true), "engine startup transition changes desired state exactly once")
	_check(not rig.set_engine_running(true), "repeated engine startup request is idempotent")
	var idle := rig.get_state_snapshot()
	_check((idle.desired_loop_layers as PackedStringArray) == PackedStringArray(["thrust_idle"]), "running engine activates only the idle layer before thrust")
	_check(rig.set_thrust_state(0.72, false), "finite throttle input is accepted")
	var loaded := rig.get_state_snapshot()
	_check((loaded.desired_loop_layers as PackedStringArray).has("thrust_load") and not (loaded.desired_loop_layers as PackedStringArray).has("thrust_boost"), "ordinary thrust layers load over idle without boost")
	_check(rig.set_thrust_state(0.82, true), "boost request updates the bounded thrust state")
	_check(rig.set_damage_alarm_active(true), "damage alarm transition activates independently")
	var layered := rig.get_state_snapshot()
	var layered_ids := layered.desired_loop_layers as PackedStringArray
	_check(layered_ids.size() == 4 and layered_ids.has("thrust_idle") and layered_ids.has("thrust_load") and layered_ids.has("thrust_boost") and layered_ids.has("damage_alarm"), "idle, load, boost, and damage alarm can form the complete four-layer state")
	var throttle_before_invalid := float(layered.throttle)
	_check(not rig.set_thrust_state(NAN, false), "non-finite thrust input is rejected")
	_check(is_equal_approx(float(rig.get_state_snapshot().throttle), throttle_before_invalid), "rejected non-finite input cannot corrupt current audio state")

	rig.set_rig_enabled(false)
	_check(not rig.is_rig_enabled() and _players_stopped_and_detached(rig), "disable is immediate and detaches every positional playback handle")
	_check((rig.get_state_snapshot().desired_loop_layers as PackedStringArray).size() == 4, "disable preserves desired ship state for reversible lifecycle restoration")
	_check(bool(rig.get_audit_report().valid), "settled disabled state remains internally auditable")
	rig.set_rig_enabled(true)
	_check(rig.is_rig_enabled() and int(rig.get_synthesis_report().generation_count) == initial_generation, "ordinary re-enable reuses resident templates without regeneration churn")
	var queue_allowed := bool(rig.get_performance_report().playback_queue_allowed)
	_check(not bool(rig.get_performance_report().output_audibility_verified) and str(rig.get_performance_report().output_claim_scope) == "engine_queue_state_not_audibility", "backend report never promotes queue bookkeeping into an audibility claim")
	if not queue_allowed:
		_check(_players_stopped_and_detached(rig), "Dummy or unavailable output keeps all layered playback handles detached")
	else:
		_check((rig.get_state_snapshot().queued_voice_ids as PackedStringArray).size() >= 4, "queue-candidate backend owns all requested continuous layer handles")

	_check(rig.set_engine_running(false), "engine stop transition is accepted")
	var stopped := rig.get_state_snapshot()
	var stopped_layers := stopped.desired_loop_layers as PackedStringArray
	_check(stopped_layers == PackedStringArray(["damage_alarm"]), "engine stop removes idle/load/boost while leaving independent damage alarm state")
	_check(rig.set_damage_alarm_active(false), "damage alarm can be cleared independently")
	_check((rig.get_state_snapshot().desired_loop_layers as PackedStringArray).is_empty(), "cleared stopped state owns no continuous layer")
	var transition_audit := rig.get_audit_report()
	_check(bool(transition_audit.valid), "complete state-transition sequence preserves the deep audit")


func _test_cue_contract_and_budget(rig: ShipAudioRig) -> void:
	var exact_cues := PackedStringArray([
		"engine_startup",
		"engine_stop",
		"weapon_fire",
		"impact",
		"hull_hit",
		"destruction",
		"landing",
		"docking",
	])
	_check(rig.get_supported_cues() == exact_cues, "public cue roster covers every required ship event with exact stable IDs")
	var contract := rig.get_cue_contract()
	var routes := contract.routes as Dictionary
	_check(routes.size() == 8 and int(contract.maximum_simultaneous_transients) == 2, "eight cues share exactly two replacement channels")
	var engine_cues := PackedStringArray(["engine_startup", "engine_stop", "landing", "docking"])
	var combat_cues := PackedStringArray(["weapon_fire", "impact", "hull_hit", "destruction"])
	var routing_exact := true
	for cue_id in engine_cues:
		routing_exact = routing_exact and str(routes[StringName(cue_id)].bus) == "Engines" and str(routes[StringName(cue_id)].voice_id) == "engine_cue_voice"
	for cue_id in combat_cues:
		routing_exact = routing_exact and str(routes[StringName(cue_id)].bus) == "Weapons" and str(routes[StringName(cue_id)].voice_id) == "combat_cue_voice"
	_check(routing_exact, "startup/stop/landing/docking route to Engines while fire/impact/hull/destruction route to Weapons")

	var before_state := rig.get_state_snapshot()
	var before_generation := int(rig.get_synthesis_report().generation_count)
	var expected_playback := bool(rig.get_performance_report().playback_queue_allowed)
	_cue_events.clear()
	if not rig.cue_requested.is_connected(_on_cue_requested):
		rig.cue_requested.connect(_on_cue_requested)
	var playback_results_match_driver := true
	for cue_id in exact_cues:
		playback_results_match_driver = playback_results_match_driver and rig.play_cue(StringName(cue_id), 0.85) == expected_playback
	_check(playback_results_match_driver, "all supported cue requests follow the queue-candidate-versus-Dummy contract")
	_check(_cue_events.size() == 8, "every accepted cue synchronously reports its exact queue outcome")
	var signal_outcomes_match := true
	for event in _cue_events:
		signal_outcomes_match = signal_outcomes_match and bool(event.playback_queued) == expected_playback
	_check(signal_outcomes_match, "cue signal distinguishes a queued real-driver request from Dummy-safe rejection")
	if expected_playback:
		await process_frame
		var active_cues := rig.get_state_snapshot().active_cues_by_voice as Dictionary
		_check(
			active_cues.size() == 2
			and active_cues.get(&"engine_cue_voice", &"") == ShipAudioRig.CUE_DOCKING
			and active_cues.get(&"combat_cue_voice", &"") == ShipAudioRig.CUE_DESTRUCTION,
			"queue-candidate backend owns docking and destruction as the exact final cues on their replacement channels"
		)
		var longest_cleanup_timeout := 0.0
		for cue_id in routes:
			longest_cleanup_timeout = maxf(longest_cleanup_timeout, float(routes[cue_id].cleanup_timeout_seconds))
		await create_timer(longest_cleanup_timeout + 0.20).timeout
		await process_frame
		_check((rig.get_state_snapshot().active_cues_by_voice as Dictionary).is_empty(), "bounded completion detaches docking and destruction even if mixer completion is unavailable")
	var after_state := rig.get_state_snapshot()
	_check(int(after_state.cue_request_count) == int(before_state.cue_request_count) + 8 and str(after_state.last_cue_id) == "docking", "state report counts accepted cue requests and records the exact latest ID")
	var count_before_rejection := int(after_state.cue_request_count)
	_check(not rig.play_cue(&"unsupported") and not rig.play_cue(ShipAudioRig.CUE_FIRE, NAN) and not rig.play_cue(ShipAudioRig.CUE_FIRE, 0.0), "unknown, non-finite, and zero-intensity cues are rejected")
	_check(int(rig.get_state_snapshot().cue_request_count) == count_before_rejection, "rejected cues do not mutate request state")
	_check(rig.find_children("*", "AudioStreamPlayer3D", true, false).size() == 6, "cue churn cannot allocate an unbounded voice")
	_check(int(rig.get_synthesis_report().generation_count) == before_generation and int(rig.get_synthesis_report().resident_sample_bytes) == 145680, "cue churn reuses the fixed resident templates without allocation growth")
	_check(bool(rig.get_audit_report().valid), "all cue routes leave the component auditable")

	rig.set_engine_running(true, false)
	rig.set_thrust_state(0.7, true)
	rig.set_damage_alarm_active(true)
	rig.play_destruction(1.0)
	var destroyed := rig.get_state_snapshot()
	_check(not bool(destroyed.engine_running) and not bool(destroyed.boost_active) and not bool(destroyed.damage_alarm_active), "destruction cue atomically silences engine, boost, and damage-alarm loops")


func _test_fail_red_corruption() -> void:
	var probe := _make_rig(ShipAudioRig.PROFILE_STANDARD_FIGHTER, "CorruptionProbe")
	await process_frame
	if probe == null:
		return
	_check(bool(probe.get_audit_report().valid), "corruption probe starts from a valid audited build")

	probe.remove_from_group(&"ship_audio_rig")
	_check(not bool(probe.get_audit_report().valid), "audit rejects removal from the live ship-audio discovery group")
	probe.add_to_group(&"ship_audio_rig", false)
	probe.set_meta(&"historically_supported", true)
	_check(not bool(probe.get_audit_report().valid), "live metadata cannot contradict the non-historical evidence report")
	probe.set_meta(&"historically_supported", false)
	probe.set_meta(&"design_origin", &"recovered_recording")
	_check(not bool(probe.get_audit_report().valid), "live provenance metadata cannot contradict project-original synthesis")
	probe.set_meta(&"design_origin", ShipAudioRig.DESIGN_ORIGIN)
	_check(bool(probe.get_audit_report().valid), "restoring discovery and provenance metadata restores validity")

	var original_profile := probe.profile_id
	probe.profile_id = &"standard_fighter_mutated"
	var profile_audit := probe.get_audit_report()
	_check(not bool(profile_audit.valid) and _errors_contain(profile_audit.errors, "profile_id"), "audit fails red when requested profile diverges from immutable built profile")
	probe.profile_id = original_profile
	_check(bool(probe.get_audit_report().valid), "restoring exact profile ID clears configuration drift")

	var original_distance := probe.maximum_distance
	probe.maximum_distance += 9.0
	var distance_audit := probe.get_audit_report()
	_check(not bool(distance_audit.valid) and not bool(distance_audit.spatial.configuration_current), "audit fails red without rebasing mutated spatial exports")
	probe.maximum_distance = original_distance
	_check(bool(probe.get_audit_report().valid), "restoring immutable spatial export clears its audit error")

	var idle_player := probe.get_node("ThrustIdle") as AudioStreamPlayer3D
	idle_player.bus = &"Master"
	_check(not bool(probe.get_audit_report().valid), "audit rejects direct voice-bus corruption")
	idle_player.bus = &"Engines"
	idle_player.max_polyphony = 3
	_check(not bool(probe.get_audit_report().valid), "audit rejects direct voice-budget corruption")
	idle_player.max_polyphony = 1
	_check(bool(probe.get_audit_report().valid), "restoring player configuration restores validity")
	var engine_expiry := probe.get_node("EngineCueExpiry") as Timer
	engine_expiry.one_shot = false
	_check(not bool(probe.get_audit_report().valid), "audit rejects direct cue-expiry timer corruption")
	engine_expiry.one_shot = true
	_check(bool(probe.get_audit_report().valid), "restoring bounded timer configuration restores validity")

	var rogue := AudioStreamPlayer3D.new()
	rogue.name = "RogueVoice"
	probe.add_child(rogue)
	_check(not bool(probe.get_audit_report().valid), "audit rejects an unindexed seventh positional voice")
	probe.remove_child(rogue)
	rogue.queue_free()
	_check(bool(probe.get_audit_report().valid), "removing rogue voice restores exact hierarchy")

	probe.remove_child(idle_player)
	var replacement := AudioStreamPlayer3D.new()
	replacement.name = "ThrustIdle"
	probe.add_child(replacement)
	var replacement_audit := probe.get_audit_report()
	_check(not bool(replacement_audit.valid) and _errors_contain(replacement_audit.errors, "identity"), "same-name player replacement cannot spoof immutable voice identity")
	probe.remove_child(replacement)
	replacement.queue_free()
	probe.add_child(idle_player)
	_check(bool(probe.get_audit_report().valid), "re-adding the exact cached player restores immutable hierarchy")

	var foreign := AudioStreamWAV.new()
	foreign.format = AudioStreamWAV.FORMAT_16_BITS
	foreign.mix_rate = 12000
	foreign.data = PackedByteArray([0, 0, 0, 0])
	idle_player.stream = foreign
	_check(not bool(probe.get_audit_report().valid), "foreign playback resource cannot masquerade as an owned loop")
	idle_player.stream = null
	_check(bool(probe.get_audit_report().valid), "detaching foreign playback resource restores lifecycle audit")

	var loop_streams := probe.get("_loop_streams") as Dictionary
	var idle_stream := loop_streams[ShipAudioRig.LOOP_IDLE] as AudioStreamWAV
	var original_data := idle_stream.data.duplicate()
	var corrupt_data := original_data.duplicate()
	corrupt_data[0] = corrupt_data[0] ^ 0x5a
	idle_stream.data = corrupt_data
	var fingerprint_audit := probe.get_audit_report()
	_check(not bool(fingerprint_audit.valid) and _errors_contain(fingerprint_audit.errors, "fingerprint"), "audit detects resident PCM byte corruption through SHA-256")
	idle_stream.data = original_data
	_check(bool(probe.get_audit_report().valid), "restoring byte-identical PCM clears fingerprint error")

	var impostor_stream := AudioStreamWAV.new()
	impostor_stream.format = idle_stream.format
	impostor_stream.mix_rate = idle_stream.mix_rate
	impostor_stream.stereo = idle_stream.stereo
	impostor_stream.data = idle_stream.data.duplicate()
	impostor_stream.loop_mode = idle_stream.loop_mode
	impostor_stream.loop_begin = idle_stream.loop_begin
	impostor_stream.loop_end = idle_stream.loop_end
	loop_streams[ShipAudioRig.LOOP_IDLE] = impostor_stream
	var identity_audit := probe.get_audit_report()
	_check(not bool(identity_audit.valid) and _errors_contain(identity_audit.errors, "resource identity"), "byte-identical replacement resource still fails immutable resource identity")
	loop_streams[ShipAudioRig.LOOP_IDLE] = idle_stream
	_check(bool(probe.get_audit_report().valid), "restoring exact resident resource identity clears audit")

	var cue_streams := probe.get("_cue_streams") as Dictionary
	var docking_stream := cue_streams[ShipAudioRig.CUE_DOCKING] as AudioStreamWAV
	cue_streams.erase(ShipAudioRig.CUE_DOCKING)
	_check(not bool(probe.get_audit_report().valid), "audit rejects a missing declared cue template")
	cue_streams[ShipAudioRig.CUE_DOCKING] = docking_stream
	_check(bool(probe.get_audit_report().valid), "restoring exact cue roster restores validity")

	var original_bytes := int(probe.get("_resident_sample_bytes"))
	probe.set("_resident_sample_bytes", original_bytes + 1)
	_check(not bool(probe.get_audit_report().valid), "audit rejects falsified resident-byte accounting")
	probe.set("_resident_sample_bytes", original_bytes)
	_check(bool(probe.get_audit_report().valid), "restoring exact byte accounting returns the complete audit to green")

	probe.queue_free()
	await process_frame
	await process_frame


func _test_detach_reentry_release_and_cleanup() -> void:
	var rig := _make_rig(ShipAudioRig.PROFILE_HEAVY_QUAD_FREIGHTER, "LifecycleProbe")
	await process_frame
	if rig == null:
		return
	rig.set_engine_running(true, false)
	rig.set_thrust_state(0.78, true)
	rig.set_damage_alarm_active(true)
	var original_synthesis := rig.get_synthesis_report()
	var original_fingerprints := (original_synthesis.fingerprints_sha256 as Dictionary).duplicate(true)
	var original_generation := int(original_synthesis.generation_count)
	var parent := rig.get_parent()
	parent.remove_child(rig)
	var detached := rig.get_synthesis_report()
	_check(not bool(detached.resources_ready) and int(detached.resident_sample_bytes) == 0, "child-level detach releases every resident PCM template")
	_check(_players_stopped_and_detached(rig), "child-level detach stops and clears all six playback handles")
	_check((rig.get_state_snapshot().desired_loop_layers as PackedStringArray).size() == 4, "detach retains engine/thrust/boost/alarm desired state")
	_check(bool(rig.get_audit_report().valid), "settled detached component remains internally auditable")
	parent.add_child(rig)
	await process_frame
	await process_frame
	var reentered := rig.get_synthesis_report()
	_check(bool(reentered.resources_ready) and (reentered.fingerprints_sha256 as Dictionary) == original_fingerprints, "re-entry regenerates byte-identical profile resources")
	_check(int(reentered.generation_count) == original_generation + 1, "re-entry performs exactly one bounded synthesis generation")
	_check((rig.get_state_snapshot().desired_loop_layers as PackedStringArray).size() == 4 and bool(rig.get_audit_report().valid), "re-entry restores retained desired state and complete audit")
	if not bool(rig.get_performance_report().playback_queue_allowed):
		_check(_players_stopped_and_detached(rig), "re-entry remains playback-handle-free on Dummy or unavailable output")
	else:
		_check((rig.get_state_snapshot().queued_voice_ids as PackedStringArray).size() == 4, "queue-candidate re-entry restores exactly four requested loop handles")

	rig.set_rig_enabled(false)
	var disabled_generation := int(rig.get_synthesis_report().generation_count)
	parent.remove_child(rig)
	parent.add_child(rig)
	await process_frame
	await process_frame
	var disabled_reentry := rig.get_synthesis_report()
	_check(not rig.is_rig_enabled() and not bool(disabled_reentry.resources_ready) and _players_stopped_and_detached(rig), "disabled detach/re-entry preserves silence and owns no resident samples")
	_check(int(disabled_reentry.generation_count) == disabled_generation and bool(rig.get_audit_report().valid), "disabled re-entry performs no hidden synthesis and remains valid")
	rig.set_rig_enabled(true)
	_check(int(rig.get_synthesis_report().generation_count) == disabled_generation + 1 and bool(rig.get_audit_report().valid), "eventual enable performs one deterministic rebuild and restores validity")

	var generation_before_release := int(rig.get_synthesis_report().generation_count)
	var immutable_distance := rig.maximum_distance
	rig.release_audio_resources()
	rig.release_audio_resources()
	var released := rig.get_synthesis_report()
	_check(not rig.is_rig_enabled() and not bool(released.resources_ready) and int(released.resident_sample_bytes) == 0, "deep release is idempotent and clears all resident data")
	_check(_players_stopped_and_detached(rig) and bool(rig.get_audit_report().valid), "deep-released in-tree component is a valid settled lifecycle state")
	rig.profile_id = ShipAudioRig.PROFILE_STANDARD_FIGHTER
	rig.maximum_distance = immutable_distance + 12.0
	rig.set_rig_enabled(true)
	var rebuilt := rig.get_synthesis_report()
	_check(str(rebuilt.built_profile_id) == "heavy_quad_freighter" and (rebuilt.fingerprints_sha256 as Dictionary) == original_fingerprints, "deep release cannot silently rebase a later profile mutation")
	_check(not bool(rig.get_audit_report().valid), "re-enable keeps post-release profile/spatial mutations visibly fail-red")
	rig.profile_id = ShipAudioRig.PROFILE_HEAVY_QUAD_FREIGHTER
	rig.maximum_distance = immutable_distance
	_check(int(rebuilt.generation_count) == generation_before_release + 1 and bool(rig.get_audit_report().valid), "restoring immutable configuration confirms exactly one eventual regeneration")

	var detached_audit := rig.get_audit_report()
	(detached_audit.synthesis as Dictionary)["resident_sample_bytes"] = -1
	(detached_audit.profile as Dictionary)["active_profile_id"] = &"mutation"
	var fresh_audit := rig.get_audit_report()
	_check(int(fresh_audit.synthesis.resident_sample_bytes) == 145680 and str(fresh_audit.profile.active_profile_id) == "heavy_quad_freighter", "deep audit dictionaries are detached from component state")

	var root_reference: WeakRef = weakref(rig)
	var player_reference: WeakRef = weakref(rig.get_node("ThrustIdle"))
	var timer_reference: WeakRef = weakref(rig.get_node("EngineCueExpiry"))
	rig.queue_free()
	rig = null
	await process_frame
	await process_frame
	_check(root_reference.get_ref() == null, "rig root tears down without a retained instance")
	_check(player_reference.get_ref() == null, "all owned positional voices tear down with the rig")
	_check(timer_reference.get_ref() == null, "both bounded cue-expiry timers tear down with the rig")


func _players_stopped_and_detached(rig: ShipAudioRig) -> bool:
	for candidate in rig.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing or player.stream != null or player.stream_paused:
			return false
	return true


func _on_cue_requested(cue_id: StringName, intensity: float, playback_queued: bool) -> void:
	_cue_events.append({
		"cue_id": cue_id,
		"intensity": intensity,
		"playback_queued": playback_queued,
	})


func _errors_contain(errors: Variant, fragment: String) -> bool:
	for message in errors as PackedStringArray:
		if fragment in str(message):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_AUDIO_RIG_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SHIP_AUDIO_RIG_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
