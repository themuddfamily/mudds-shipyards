extends SceneTree

const AMBIENCE_SCENE := preload("res://scenes/audio/station_machinery_ambience.tscn")

var _failures: Array[String] = []
var _test_root: Node3D

class RejectingStationAmbience extends StationMachineryAmbience:
	func _request_cue_playback(_player: AudioStreamPlayer3D) -> bool:
		return false


class TrackingStationAmbience extends StationMachineryAmbience:
	var enabled_state_apply_count := 0

	func _apply_enabled_state() -> void:
		enabled_state_apply_count += 1
		super()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "StationMachineryAmbienceTestRoot"
	root.add_child(_test_root)

	var ambience := _make_ambience("Primary", 4831)
	_check(ambience != null, "station machinery ambience scene instantiates as its reusable component type")
	if ambience == null:
		_finish()
		return
	await process_frame

	_test_identity_and_evidence(ambience)
	_test_spatial_and_voice_contract(ambience)
	_test_synthesis_and_performance(ambience)
	await _test_live_configuration_audit()
	await _test_built_snapshot_spoof_and_rebuild()
	await _test_disabled_detach_and_reentry()
	await _test_determinism_and_lifecycle(ambience)
	await _test_queued_public_mutators_are_inert()
	await _test_queued_reentry_restore_is_inert()
	await _test_cleanup(ambience)

	_test_root.queue_free()
	await process_frame
	_finish()


func _make_ambience(
		label: String,
		seed: int,
		frequency_hz: float = 52.5,
		component_script: Script = null
	) -> StationMachineryAmbience:
	var ambience := AMBIENCE_SCENE.instantiate() as StationMachineryAmbience
	if ambience == null:
		return null
	if component_script != null:
		ambience.set_script(component_script)
	ambience.name = label
	ambience.emitter_id = StringName("%s-emitter" % label.to_lower())
	ambience.synthesis_seed = seed
	ambience.base_frequency_hz = frequency_hz
	ambience.maximum_distance = 36.0
	ambience.reference_distance = 4.5
	_test_root.add_child(ambience)
	return ambience


func _make_tracking_ambience(label: String, seed: int) -> TrackingStationAmbience:
	var ambience := AMBIENCE_SCENE.instantiate() as StationMachineryAmbience
	if ambience == null:
		return null
	ambience.set_script(TrackingStationAmbience)
	var tracking := ambience as TrackingStationAmbience
	if tracking == null:
		return null
	tracking.name = label
	tracking.emitter_id = StringName("%s-emitter" % label.to_lower())
	tracking.synthesis_seed = seed
	tracking.base_frequency_hz = 52.5
	tracking.maximum_distance = 36.0
	tracking.reference_distance = 4.5
	_test_root.add_child(tracking)
	return tracking


func _test_identity_and_evidence(ambience: StationMachineryAmbience) -> void:
	_check(ambience.get_component_id() == &"station-machinery-ambience", "component exposes a stable integration identity")
	_check(ambience.get_emitter_id() == &"primary-emitter", "instance exposes its configured emitter identity")
	_check(ambience.is_in_group("station_machinery_ambience"), "component participates in ambience-emitter discovery")
	_check(bool(ambience.get_meta("station_ambience", false)), "root metadata identifies station ambience")
	_check(str(ambience.get_meta("evidence_status", "")) == "modern_interpretation", "root explicitly labels the sound design as modern interpretation")
	_check(not bool(ambience.get_meta("historically_supported", true)), "component cannot authenticate its sound as recovered evidence")
	var evidence := ambience.get_evidence_metadata()
	_check(int(evidence.schema_version) == StationMachineryAmbience.SCHEMA_VERSION, "evidence API is schema-versioned")
	_check(str(evidence.design_origin) == "project_original_procedural_audio", "evidence API records original procedural provenance")
	_check("No surviving source" in str(evidence.content_note), "evidence note states the historical-audio limitation")
	var interpretations := evidence.modern_interpretations as PackedStringArray
	interpretations.append("mutation")
	_check("mutation" not in (ambience.get_evidence_metadata().modern_interpretations as PackedStringArray), "evidence arrays are detached from component state")


func _test_spatial_and_voice_contract(ambience: StationMachineryAmbience) -> void:
	var players := ambience.find_children("*", "AudioStreamPlayer3D", true, false)
	_check(players.size() == 2, "component owns exactly one loop voice and one transient voice")
	var every_player_spatial := true
	for candidate in players:
		var player := candidate as AudioStreamPlayer3D
		every_player_spatial = every_player_spatial \
			and player.bus == &"Ambience" \
			and player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE \
			and is_equal_approx(player.max_distance, 36.0) \
			and is_equal_approx(player.unit_size, 4.5) \
			and is_equal_approx(player.panning_strength, 1.0) \
			and player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED \
			and not player.emission_angle_enabled \
			and player.max_polyphony == 1
	_check(every_player_spatial, "both voices share bounded omnidirectional 3D attenuation on the Ambience bus")
	_check(ambience.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "component has no non-positional audio fallback")
	_check(ambience.find_children("*", "CollisionObject3D", true, false).is_empty(), "audio component cannot alter station collision or routes")
	var spatial := ambience.get_spatial_contract()
	_check(str(spatial.origin) == "component_global_position", "public spatial contract fixes the acoustic origin at the component transform")
	_check(str(spatial.orientation) == "omnidirectional_rotation_independent", "public contract states rotation-independent emission")
	_check(is_equal_approx(float(spatial.maximum_distance), 36.0) and is_equal_approx(float(spatial.reference_distance), 4.5), "public contract exposes exact distance bounds")


func _test_synthesis_and_performance(ambience: StationMachineryAmbience) -> void:
	var synthesis := ambience.get_synthesis_report()
	_check(int(synthesis.sample_rate) == 16000 and int(synthesis.channel_count) == 1, "procedural audio uses bounded 16 kHz mono samples")
	_check(str(synthesis.sample_format) == "signed_pcm_16_bit" and str(synthesis.loop_mode) == "forward", "synthesis report exposes PCM and loop semantics")
	_check(bool(synthesis.resources_ready) and int(synthesis.cue_count) == 2, "loop and both machinery cues are synthesized deterministically")
	var fingerprints := synthesis.fingerprints_sha256 as Dictionary
	_check(
		str(fingerprints.get(&"loop", "")).length() == 64
		and str(fingerprints.get(&"servo", "")).length() == 64
		and str(fingerprints.get(&"latch", "")).length() == 64,
		"each original waveform exposes a complete SHA-256 fingerprint"
	)
	_check(
		fingerprints[&"loop"] != fingerprints[&"servo"]
		and fingerprints[&"servo"] != fingerprints[&"latch"],
		"loop, servo, and latch synthesis are distinct waveforms"
	)
	var performance := ambience.get_performance_report()
	_check(int(performance.audio_player_count) == 2 and int(performance.maximum_simultaneous_voices) == 2, "performance API proves the two-voice ceiling")
	_check(not bool(performance.per_frame_script_processing), "station ambience adds no per-frame script callback")
	_check(bool(performance.within_resident_budget) and int(performance.resident_sample_bytes) <= 131072, "resident procedural samples remain inside the declared 128 KiB budget")
	var audit := ambience.get_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "configured component passes its detached public audit")
	(audit.spatial as Dictionary)["maximum_distance"] = -1.0
	_check(float(ambience.get_audit_report().spatial.maximum_distance) == 36.0, "nested audit dictionaries are detached from component state")


func _test_determinism_and_lifecycle(ambience: StationMachineryAmbience) -> void:
	var original_synthesis := ambience.get_synthesis_report()
	var original_fingerprints := (original_synthesis.fingerprints_sha256 as Dictionary).duplicate(true)
	var original_generation_count := int(original_synthesis.generation_count)
	var twin := _make_ambience("Twin", ambience.synthesis_seed)
	var variant := _make_ambience("Variant", ambience.synthesis_seed + 1)
	await process_frame
	_check(
		(twin.get_synthesis_report().fingerprints_sha256 as Dictionary) == original_fingerprints,
		"equal synthesis settings produce byte-identical loop and cue fingerprints"
	)
	_check(
		str((variant.get_synthesis_report().fingerprints_sha256 as Dictionary).get(&"loop")) != str(original_fingerprints.get(&"loop")),
		"a different seed produces a deliberate deterministic emitter variation"
	)
	var pre_cue_volume := float(ambience.get_spatial_contract().current_cue_volume_db)
	_check(
		not ambience.play_cue(&"servo", 0.0)
		and not ambience.play_cue(&"servo", NAN)
		and not ambience.play_cue(&"servo", -1.0),
		"invalid cue intensity remains rejected and deterministic"
	)
	_check(
		is_equal_approx(float(ambience.get_spatial_contract().current_cue_volume_db), pre_cue_volume),
		"invalid cue intensity leaves last supported cue volume unchanged"
	)
	if AudioServer.get_driver_name() != "Dummy":
		_check(ambience.play_cue(&"servo", 12.0), "real audio clamps cue intensity and still accepts extremely loud inputs")

	ambience.set_ambience_enabled(false)
	ambience.set_ambience_enabled(false)
	_check(not ambience.is_ambience_enabled(), "disable is explicit and idempotent")
	_check(_players_are_stopped_and_detached(ambience), "disable stops both voices and detaches playback streams")
	_check(not ambience.play_cue(&"servo"), "disabled component refuses transient playback")
	ambience.set_ambience_enabled(true)
	ambience.set_ambience_enabled(true)
	_check(ambience.is_ambience_enabled(), "re-enable is explicit and idempotent")
	_check(int(ambience.get_synthesis_report().generation_count) == original_generation_count, "ordinary disable/re-enable retains templates without resynthesis churn")
	if AudioServer.get_driver_name() == "Dummy":
		_check(_players_are_stopped_and_detached(ambience), "Dummy driver never receives a playback handle")
		_check(not ambience.play_cue(&"latch"), "Dummy driver rejects cue playback safely")
	else:
		_check((ambience.get_node("MachineryLoop") as AudioStreamPlayer3D).playing, "real audio driver starts the positional machinery loop")
		_check(ambience.play_cue(&"latch"), "real audio driver accepts a supported transient cue")
		var rejecting_probe := _make_ambience("RejectingProbe", ambience.synthesis_seed, ambience.base_frequency_hz)
		_check(rejecting_probe != null, "rejection probe ambience instantiates for playback-seams checks")
		rejecting_probe.set_script(RejectingStationAmbience)
		await process_frame
		var rejection_probe_volume_before := float(rejecting_probe.get_spatial_contract().current_cue_volume_db)
		var rejection_probe_generation := int(rejecting_probe.get_synthesis_report().generation_count)
		_check(not rejecting_probe.play_cue(&"servo"), "simulated real-driver rejection reports playback failure")
		_check(_players_are_stopped_and_detached(rejecting_probe), "simulated playback rejection leaves a detached deterministic cue player")
		_check(is_equal_approx(float(rejecting_probe.get_spatial_contract().current_cue_volume_db), rejection_probe_volume_before), "simulated cue rejection leaves last cue volume state unchanged")
		_check(int(rejecting_probe.get_synthesis_report().generation_count) == rejection_probe_generation, "simulated cue rejection does not trigger synthesis churn")
		rejecting_probe.queue_free()
	_check(not ambience.play_cue(&"unsupported"), "unknown cue IDs have no implicit sound fallback")

	var original_parent := ambience.get_parent()
	var generation_before_detach := int(ambience.get_synthesis_report().generation_count)
	original_parent.remove_child(ambience)
	_check(ambience.get_parent() == null, "component can be detached at child level without freeing it")
	_check(ambience.is_ambience_enabled(), "child-level exit preserves the enabled desired state")
	var detached := ambience.get_synthesis_report()
	_check(not bool(detached.resources_ready) and int(detached.resident_sample_bytes) == 0, "child-level exit releases deterministic templates without changing desired state")
	_check(_players_are_stopped_and_detached(ambience), "child-level exit stops and detaches both playback voices")
	original_parent.add_child(ambience)
	await process_frame
	await process_frame
	var reentered := ambience.get_synthesis_report()
	_check(ambience.get_parent() == original_parent and ambience.is_ambience_enabled(), "same-parent re-entry restores the retained enabled state")
	_check(bool(reentered.resources_ready) and int(reentered.resident_sample_bytes) > 0, "same-parent re-entry regenerates released deterministic templates")
	_check((reentered.fingerprints_sha256 as Dictionary) == original_fingerprints, "same-parent re-entry regenerates byte-identical waveforms")
	_check(int(reentered.generation_count) == generation_before_detach + 1, "same-parent re-entry performs exactly one bounded regeneration")
	if AudioServer.get_driver_name() == "Dummy":
		_check(_players_are_stopped_and_detached(ambience), "same-parent re-entry keeps Dummy-driver playback detached")
	else:
		var restored_loop := ambience.get_node("MachineryLoop") as AudioStreamPlayer3D
		_check(restored_loop.stream != null and restored_loop.playing, "same-parent re-entry restores real-driver loop resources and playback")

	ambience.release_audio_resources()
	ambience.release_audio_resources()
	var released := ambience.get_synthesis_report()
	_check(not bool(released.resources_ready) and int(released.resident_sample_bytes) == 0, "explicit deep release is idempotent and drops cached samples")
	_check(_players_are_stopped_and_detached(ambience), "deep release clears every player reference")
	var generation_before_explicit_regeneration := int(released.generation_count)
	ambience.set_ambience_enabled(true)
	var regenerated := ambience.get_synthesis_report()
	_check((regenerated.fingerprints_sha256 as Dictionary) == original_fingerprints, "re-enable regenerates byte-identical procedural audio after deep cleanup")
	_check(int(regenerated.generation_count) == generation_before_explicit_regeneration + 1, "deep cleanup causes exactly one bounded regeneration")

	twin.queue_free()
	variant.queue_free()
	await process_frame
	await process_frame


func _test_queued_reentry_restore_is_inert() -> void:
	var ambience := _make_tracking_ambience("QueuedReentry", 69841)
	if ambience == null:
		return
	await process_frame
	var parent := ambience.get_parent()
	parent.remove_child(ambience)
	await process_frame
	parent.add_child(ambience)
	# Re-entry queued the normal restore. Once the retained owner has committed
	# to deletion, that deferred callback must not apply playback state again.
	var apply_count_before := ambience.enabled_state_apply_count
	ambience.queue_free()
	ambience.call("_restore_after_enter_tree")
	_check(
		ambience.is_queued_for_deletion()
		and ambience.enabled_state_apply_count == apply_count_before
		and _players_are_stopped_and_detached(ambience),
		"a queued post-reentry machinery emitter cannot restore playback state"
	)
	await process_frame
	_check(not is_instance_valid(ambience), "the queued re-entry machinery fixture frees normally")


func _test_queued_public_mutators_are_inert() -> void:
	var pre_tree := AMBIENCE_SCENE.instantiate() as StationMachineryAmbience
	if pre_tree != null:
		pre_tree.set_ambience_enabled(false)
		_check(
			not pre_tree.is_ambience_enabled(),
			"uninitialized pre-tree ambience retains authored enablement configuration"
		)
		pre_tree.queue_free()

	var ambience := _make_ambience(
		"QueuedPublicMutators", 73429, 52.5, RejectingStationAmbience
	)
	if ambience == null:
		return
	await process_frame
	# Make the cue path reach its player preparation in headless runs. The
	# rejecting hook leaves a bad queued guard observable through cue volume.
	ambience._audio_available = true
	var loop := ambience.get_node("MachineryLoop") as AudioStreamPlayer3D
	var cue := ambience.get_node("CueVoice") as AudioStreamPlayer3D
	var enabled_before := ambience.is_ambience_enabled()
	var synthesis_before := ambience.get_synthesis_report()
	var spatial_before := ambience.get_spatial_contract()
	var players_before := {
		"loop_stream": loop.stream,
		"loop_playing": loop.playing,
		"loop_volume_db": loop.volume_db,
		"cue_stream": cue.stream,
		"cue_playing": cue.playing,
		"cue_volume_db": cue.volume_db,
	}
	ambience.queue_free()
	var cue_accepted := ambience.play_cue(&"servo", 1.25)
	ambience.set_ambience_enabled(not enabled_before)
	var players_after := {
		"loop_stream": loop.stream,
		"loop_playing": loop.playing,
		"loop_volume_db": loop.volume_db,
		"cue_stream": cue.stream,
		"cue_playing": cue.playing,
		"cue_volume_db": cue.volume_db,
	}
	_check(
		ambience.is_queued_for_deletion()
		and not cue_accepted
		and ambience.is_ambience_enabled() == enabled_before
		and ambience.get_synthesis_report() == synthesis_before
		and ambience.get_spatial_contract() == spatial_before
		and players_after == players_before,
		"queued public ambience toggles and cues leave desired state, resources, and voices unchanged"
	)
	await process_frame
	_check(not is_instance_valid(ambience), "the queued public-mutator machinery fixture frees normally")

	var reentered := _make_ambience("QueuedPublicReentry", 81643)
	if reentered == null:
		return
	await process_frame
	var parent := reentered.get_parent()
	parent.remove_child(reentered)
	await process_frame
	var detached_enabled := reentered.is_ambience_enabled()
	var detached_synthesis := reentered.get_synthesis_report()
	var detached_spatial := reentered.get_spatial_contract()
	reentered.set_ambience_enabled(false)
	_check(
		not reentered.is_inside_tree()
			and reentered.is_ambience_enabled() == detached_enabled
			and reentered.get_synthesis_report() == detached_synthesis
			and reentered.get_spatial_contract() == detached_spatial,
		"initialized detached ambience enablement preserves retained desired state, resources, and voice contract"
	)
	parent.add_child(reentered)
	await process_frame
	await process_frame
	_check(
		reentered.is_ambience_enabled()
			and bool(reentered.get_synthesis_report().resources_ready),
		"a fresh re-entry restores the retained enabled ambience lifecycle after detached rejection"
	)
	reentered.queue_free()
	await process_frame


func _test_live_configuration_audit() -> void:
	var probe := _make_ambience("MutationProbe", 93217)
	await process_frame
	var original_synthesis := probe.get_synthesis_report()
	var original_spatial := probe.get_spatial_contract()
	var original_fingerprints := (original_synthesis.fingerprints_sha256 as Dictionary).duplicate(true)
	var original_seed := probe.synthesis_seed
	var original_frequency := probe.base_frequency_hz

	probe.synthesis_seed = original_seed + 19
	var seed_audit := probe.get_audit_report()
	var seed_report := seed_audit.synthesis as Dictionary
	_check(not bool(seed_audit.valid), "audit fails red when the live seed no longer describes built resources")
	_check(not bool(seed_report.configuration_matches_resources), "synthesis report explicitly marks a stale seed/resource configuration")
	_check(int(seed_report.seed) == original_seed and int(seed_report.requested_seed) == probe.synthesis_seed, "synthesis report distinguishes the built seed from the newly requested seed")
	_check((seed_report.fingerprints_sha256 as Dictionary) == original_fingerprints, "read-only seed audit neither relabels nor silently rebuilds existing waveforms")
	probe.synthesis_seed = original_seed
	_check(bool(probe.get_audit_report().valid), "restoring the built seed clears the stale-configuration audit error")

	probe.base_frequency_hz = original_frequency + 4.0
	var frequency_audit := probe.get_audit_report()
	var frequency_report := frequency_audit.synthesis as Dictionary
	_check(not bool(frequency_audit.valid), "audit fails red when the live base frequency no longer describes built resources")
	_check(not bool(frequency_report.configuration_matches_resources), "synthesis report explicitly marks a stale frequency/resource configuration")
	_check(is_equal_approx(float(frequency_report.base_frequency_hz), original_frequency) and is_equal_approx(float(frequency_report.requested_base_frequency_hz), probe.base_frequency_hz), "synthesis report distinguishes built and requested base frequencies")
	probe.base_frequency_hz = original_frequency
	_check(bool(probe.get_audit_report().valid), "restoring the built frequency clears the stale-configuration audit error")

	var original_maximum_distance := probe.maximum_distance
	var original_reference_distance := probe.reference_distance
	probe.maximum_distance = original_maximum_distance - 5.0
	var maximum_audit := probe.get_audit_report()
	var maximum_report := maximum_audit.spatial as Dictionary
	var requested_maximum := maximum_report.requested_configuration as Dictionary
	_check(not bool(maximum_audit.valid) and _errors_contain(maximum_audit.errors, "maximum distance changed"), "maximum-distance export drift independently fails the audit")
	_check(not bool(maximum_report.configuration_matches_players), "maximum-distance drift marks the spatial report stale")
	_check(is_equal_approx(float(maximum_report.maximum_distance), float(original_spatial.maximum_distance)) and is_equal_approx(float(requested_maximum.maximum_distance), probe.maximum_distance), "maximum-distance report separates built and requested values")
	probe.maximum_distance = original_maximum_distance
	_check(bool(probe.get_audit_report().valid), "restoring maximum distance clears its audit error")

	probe.reference_distance = original_reference_distance + 1.0
	var reference_audit := probe.get_audit_report()
	var reference_report := reference_audit.spatial as Dictionary
	var requested_reference := reference_report.requested_configuration as Dictionary
	_check(not bool(reference_audit.valid) and _errors_contain(reference_audit.errors, "reference distance changed"), "reference-distance export drift independently fails the audit")
	_check(not bool(reference_report.configuration_matches_players), "reference-distance drift marks the spatial report stale")
	_check(is_equal_approx(float(reference_report.reference_distance), float(original_spatial.reference_distance)) and is_equal_approx(float(requested_reference.reference_distance), probe.reference_distance), "reference-distance report separates built and requested values")
	probe.reference_distance = original_reference_distance
	_check(bool(probe.get_audit_report().valid), "restoring reference distance clears its audit error")

	var loop_player := probe.get_node("MachineryLoop") as AudioStreamPlayer3D
	var cue_player := probe.get_node("CueVoice") as AudioStreamPlayer3D
	loop_player.max_distance += 3.0
	var player_maximum_audit := probe.get_audit_report()
	_check(not bool(player_maximum_audit.valid) and not bool(player_maximum_audit.spatial.configuration_matches_players), "direct player maximum-distance drift fails both audit and spatial report")
	loop_player.max_distance = float(original_spatial.maximum_distance)
	_check(bool(probe.get_audit_report().valid), "restoring player maximum distance clears its audit error")

	cue_player.unit_size += 0.75
	var player_reference_audit := probe.get_audit_report()
	_check(not bool(player_reference_audit.valid) and not bool(player_reference_audit.spatial.configuration_matches_players), "direct player reference-distance drift fails both audit and spatial report")
	cue_player.unit_size = float(original_spatial.reference_distance)
	_check(bool(probe.get_audit_report().valid), "restoring player reference distance clears its audit error")

	loop_player.bus = &"Master"
	var player_bus_audit := probe.get_audit_report()
	_check(not bool(player_bus_audit.valid) and not bool(player_bus_audit.spatial.configuration_matches_players), "direct player bus drift cannot leave an honestly matching spatial report")
	loop_player.bus = &"Ambience"
	_check(bool(probe.get_audit_report().valid), "restoring player bus clears its audit error")

	cue_player.area_mask = 1
	var player_area_audit := probe.get_audit_report()
	_check(not bool(player_area_audit.valid) and not bool(player_area_audit.spatial.configuration_matches_players), "direct player area-mask drift cannot leave an honestly matching spatial report")
	cue_player.area_mask = 0
	_check(bool(probe.get_audit_report().valid), "restoring direct player configuration clears stale-player audit errors")

	loop_player.volume_db -= 9.0
	var loop_volume_audit := probe.get_audit_report()
	_check(not bool(loop_volume_audit.valid) and not bool(loop_volume_audit.spatial.configuration_matches_players), "direct loop-volume drift fails both audit and spatial report")
	loop_player.volume_db = float(original_spatial.loop_volume_db)
	_check(bool(probe.get_audit_report().valid), "restoring loop-player volume clears its audit error")

	cue_player.volume_db += 6.0
	var cue_volume_audit := probe.get_audit_report()
	_check(not bool(cue_volume_audit.valid) and not bool(cue_volume_audit.spatial.configuration_matches_players), "direct cue-volume drift fails both audit and spatial report")
	cue_player.volume_db = float(original_spatial.cue_volume_db)
	_check(bool(probe.get_audit_report().valid), "restoring cue-player volume clears its audit error")

	loop_player.position = Vector3(0.5, 0.0, 0.0)
	var origin_audit := probe.get_audit_report()
	_check(not bool(origin_audit.valid) and not bool(origin_audit.spatial.configuration_matches_players), "direct voice-origin drift cannot contradict the published component acoustic origin")
	loop_player.position = Vector3.ZERO
	_check(bool(probe.get_audit_report().valid), "restoring the voice to the component origin clears its audit error")

	loop_player.pitch_scale = 2.75
	var pitch_audit := probe.get_audit_report()
	_check(not bool(pitch_audit.valid) and not bool(pitch_audit.spatial.configuration_matches_players), "direct pitch drift cannot relabel deterministic PCM playback")
	loop_player.pitch_scale = 1.0
	_check(bool(probe.get_audit_report().valid), "restoring authored pitch clears its audit error")

	loop_player.attenuation_filter_cutoff_hz = 500.0
	var filter_audit := probe.get_audit_report()
	_check(not bool(filter_audit.valid) and not bool(filter_audit.spatial.configuration_matches_players), "direct attenuation-filter drift cannot silently erase the machinery bed")
	loop_player.attenuation_filter_cutoff_hz = 5000.0
	_check(bool(probe.get_audit_report().valid), "restoring the authored attenuation filter clears its audit error")
	var loop_stream := (probe.get_node("MachineryLoop") as AudioStreamPlayer3D).stream as AudioStreamWAV
	if loop_stream == null:
		# Dummy audio intentionally keeps the voice detached; the deterministic
		# owned template remains available through the internal audit path.
		loop_stream = probe.get("_loop_stream") as AudioStreamWAV
	var original_loop_end := loop_stream.loop_end
	loop_stream.loop_end = 1
	_check(not bool(probe.get_audit_report().valid), "audit rejects an owned loop template with truncated sample bounds")
	loop_stream.loop_end = original_loop_end
	_check(bool(probe.get_audit_report().valid), "restoring complete loop bounds restores deterministic audio audit")

	var foreign_stream := AudioStreamWAV.new()
	foreign_stream.format = AudioStreamWAV.FORMAT_16_BITS
	foreign_stream.mix_rate = 16000
	foreign_stream.data = PackedByteArray([0, 0, 0, 0])
	loop_player.stream = foreign_stream
	var foreign_loop_audit := probe.get_audit_report()
	_check(not bool(foreign_loop_audit.valid) and not bool(foreign_loop_audit.spatial.configuration_matches_players), "foreign loop playback cannot masquerade as the fingerprinted procedural bed")
	probe.set_ambience_enabled(false)
	probe.set_ambience_enabled(true)
	_check(bool(probe.get_audit_report().valid), "normal lifecycle restoration replaces a foreign loop on every audio driver")

	cue_player.stream = foreign_stream
	var foreign_cue_audit := probe.get_audit_report()
	_check(not bool(foreign_cue_audit.valid) and not bool(foreign_cue_audit.spatial.configuration_matches_players), "foreign cue playback cannot masquerade as an owned transient template")
	cue_player.stream = null
	_check(bool(probe.get_audit_report().valid), "detaching the foreign cue restores its lifecycle audit")

	probe.maximum_distance = original_maximum_distance - 7.0
	var snapshot_before_reentry := probe.get_spatial_contract()
	var probe_parent := probe.get_parent()
	probe_parent.remove_child(probe)
	probe_parent.add_child(probe)
	await process_frame
	await process_frame
	var snapshot_after_reentry := probe.get_spatial_contract()
	_check(not bool(probe.get_audit_report().valid) and not bool(snapshot_after_reentry.configuration_matches_players), "child detach/re-entry cannot rebase an invalid requested spatial export")
	_check(is_equal_approx(float(snapshot_after_reentry.maximum_distance), float(snapshot_before_reentry.maximum_distance)), "child detach/re-entry retains the immutable built spatial distance")
	probe.maximum_distance = original_maximum_distance
	_check(bool(probe.get_audit_report().valid), "restoring the built spatial export recovers after re-entry")

	probe.queue_free()
	await process_frame
	await process_frame


func _test_built_snapshot_spoof_and_rebuild() -> void:
	const ORIGINAL_SEED := 4831
	const ORIGINAL_FREQUENCY := 44.0
	const MUTANT_SEED := 987654
	const MUTANT_FREQUENCY := 80.0
	var probe := _make_ambience("SnapshotProbe", ORIGINAL_SEED, ORIGINAL_FREQUENCY)
	await process_frame
	var original_report := probe.get_synthesis_report()
	var original_fingerprints := (original_report.fingerprints_sha256 as Dictionary).duplicate(true)
	var original_generation := int(original_report.generation_count)

	probe.synthesis_seed = MUTANT_SEED
	probe.base_frequency_hz = MUTANT_FREQUENCY
	probe.release_audio_resources()
	probe.set_ambience_enabled(true)
	var mutant_report := probe.get_synthesis_report()
	var mutant_fingerprints := (mutant_report.fingerprints_sha256 as Dictionary).duplicate(true)
	_check(mutant_fingerprints != original_fingerprints, "explicit rebuild uses the newly requested synthesis configuration")
	_check(int(mutant_report.seed) == MUTANT_SEED and is_equal_approx(float(mutant_report.base_frequency_hz), MUTANT_FREQUENCY), "rebuilt synthesis report records the configuration that produced its mutant waveforms")
	_check(bool(probe.get_audit_report().valid), "explicit mutant rebuild produces an internally honest component")

	probe.synthesis_seed = ORIGINAL_SEED
	probe.base_frequency_hz = ORIGINAL_FREQUENCY
	var stale_audit := probe.get_audit_report()
	var stale_report := stale_audit.synthesis as Dictionary
	_check(not bool(stale_audit.valid) and not bool(stale_report.configuration_matches_resources), "restoring exports alone cannot spoof the mutant resources as original")
	_check(int(stale_report.seed) == MUTANT_SEED and is_equal_approx(float(stale_report.base_frequency_hz), MUTANT_FREQUENCY), "stale synthesis report continues to identify its actual mutant build")
	_check(int(stale_report.requested_seed) == ORIGINAL_SEED and is_equal_approx(float(stale_report.requested_base_frequency_hz), ORIGINAL_FREQUENCY), "stale synthesis report separately exposes the restored original request")
	_check((stale_report.fingerprints_sha256 as Dictionary) == mutant_fingerprints and int(stale_report.generation_count) == original_generation + 1, "read-only reporting preserves mutant fingerprints and generation count")

	probe.release_audio_resources()
	probe.set_ambience_enabled(true)
	var restored_report := probe.get_synthesis_report()
	_check((restored_report.fingerprints_sha256 as Dictionary) == original_fingerprints, "explicit rebuild restores the original deterministic waveforms")
	_check(int(restored_report.generation_count) == original_generation + 2 and bool(probe.get_audit_report().valid), "original rebuild advances once and restores a valid audit")

	probe.queue_free()
	await process_frame
	await process_frame


func _test_disabled_detach_and_reentry() -> void:
	var probe := _make_ambience("DisabledReentryProbe", 62843)
	await process_frame
	var original_report := probe.get_synthesis_report()
	var original_fingerprints := (original_report.fingerprints_sha256 as Dictionary).duplicate(true)
	var original_generation := int(original_report.generation_count)
	var original_parent := probe.get_parent()
	probe.set_ambience_enabled(false)
	original_parent.remove_child(probe)
	_check(not probe.is_ambience_enabled(), "child-level exit preserves an explicitly disabled desired state")
	_check(not bool(probe.get_synthesis_report().resources_ready) and _players_are_stopped_and_detached(probe), "disabled child exit releases resources and playback without changing intent")
	_check(bool(probe.get_audit_report().valid), "enabled-resource requirements do not falsely reject a settled detached component")
	probe.set_ambience_enabled(true)
	probe.set_ambience_enabled(false)
	_check(not probe.is_ambience_enabled(), "desired state remains controllable while the component is detached")
	original_parent.add_child(probe)
	await process_frame
	await process_frame
	_check(not probe.is_ambience_enabled() and _players_are_stopped_and_detached(probe), "same-parent re-entry restores explicit disable without playback")
	_check(not probe.play_cue(&"servo"), "re-entered disabled component still refuses transient playback")
	probe.set_ambience_enabled(true)
	var enabled_report := probe.get_synthesis_report()
	_check((enabled_report.fingerprints_sha256 as Dictionary) == original_fingerprints, "eventual enable after disabled re-entry regenerates byte-identical templates")
	_check(int(enabled_report.generation_count) == original_generation + 1, "disabled re-entry causes exactly one eventual deterministic regeneration")
	_check(bool(probe.get_audit_report().valid), "eventual enable after disabled re-entry restores a valid component")

	probe.queue_free()
	await process_frame
	await process_frame


func _test_cleanup(ambience: StationMachineryAmbience) -> void:
	var component_reference: WeakRef = weakref(ambience)
	var loop_reference: WeakRef = weakref(ambience.get_node("MachineryLoop"))
	var cue_reference: WeakRef = weakref(ambience.get_node("CueVoice"))
	ambience.queue_free()
	ambience = null
	await process_frame
	await process_frame
	_check(component_reference.get_ref() == null, "component root cleans up without a retained instance")
	_check(loop_reference.get_ref() == null and cue_reference.get_ref() == null, "both positional audio voices clean up with the component")


func _players_are_stopped_and_detached(ambience: StationMachineryAmbience) -> bool:
	for candidate in ambience.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing or player.stream != null:
			return false
	return true


func _errors_contain(errors: Variant, fragment: String) -> bool:
	for error_message in errors as PackedStringArray:
		if fragment in str(error_message):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_MACHINERY_AMBIENCE_TEST_OK")
		quit(0)
	else:
		print("STATION_MACHINERY_AMBIENCE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
