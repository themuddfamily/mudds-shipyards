extends SceneTree

## Runtime audit for the bounded station-rest music bed: voice ceiling, `Music`
## bus routing, the observed session-state response, deterministic 30/60/120 Hz
## equivalence, pause/disable/reset, and whole-`Main` detach/re-entry.
##
## What this suite cannot do is decide whether the bed sounds good. Every check
## below is structural. Musical acceptance is an outstanding human listening
## pass and is deliberately not claimed anywhere in this file.

const MUSIC_BED_SCENE := preload("res://scenes/audio/station_music_bed.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const SAMPLE_RATES: Array[int] = [30, 60, 120]
const GAIN_TOLERANCE := 0.005
## One 30 Hz step plus slack. The loop clock only advances while a layer is
## audible, so the frame on which a fading layer crosses the audible floor can
## differ by at most one step between rates.
const POSITION_TOLERANCE := 0.04

var _failures: Array[String] = []
var _test_root: Node
var _layer_events: Array[Dictionary] = []


## Stands in for a real audio backend while the matrix runs under Dummy. Without
## this the attach path would never execute and the routing checks would pass
## vacuously because a silent backend accepted everything.
class AcceptingMusicBed extends StationMusicBed:
	func _backend_supports_playback() -> bool:
		return true

	func _request_layer_playback(_player: AudioStreamPlayer) -> bool:
		return true


## The opposite witness: a named backend that rejects playback must fall back to
## the exact silent lifecycle rather than retaining a handle that never started.
class RejectingMusicBed extends StationMusicBed:
	func _backend_supports_playback() -> bool:
		return true

	func _request_layer_playback(_player: AudioStreamPlayer) -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node.new()
	_test_root.name = "StationMusicBedTestRoot"
	root.add_child(_test_root)

	await _test_identity_and_contract()
	await _test_voice_ceiling_and_routing()
	await _test_dummy_backend_seam()
	await _test_rejecting_backend_seam()
	await _test_combat_yield_and_recovery()
	await _test_phase_crossfade()
	await _test_frame_rate_equivalence()
	await _test_pause_disable_and_reset()
	await _test_no_gameplay_authority()
	await _test_detached_and_queued_mutators_are_inert()
	await _test_queued_reentry_restore_is_inert()
	await _test_whole_main_detach_and_reentry()

	_test_root.queue_free()
	await process_frame
	await process_frame
	_finish()


func _make_bed(label: String, script_override: Variant = null) -> StationMusicBed:
	var bed := MUSIC_BED_SCENE.instantiate() as StationMusicBed
	if bed == null:
		return null
	if script_override != null:
		bed.set_script(script_override)
	bed.name = label
	_test_root.add_child(bed)
	return bed


## Adds a bed that this suite drives itself, one fixed delta at a time.
func _make_manual_bed(label: String, script_override: Variant = null) -> StationMusicBed:
	var bed := _make_bed(label, script_override)
	if bed != null:
		bed.set_process(false)
	return bed


func _advance(bed: StationMusicBed, seconds: float, samples_per_second: int) -> void:
	var step := 1.0 / float(samples_per_second)
	var steps := maxi(1, roundi(seconds * float(samples_per_second)))
	for _index in steps:
		bed.call("_process", step)


func _release(bed: StationMusicBed) -> void:
	# Cross a bounded mixer boundary before freeing, so no playback handle is
	# still attached to a stream at teardown.
	if is_instance_valid(bed):
		bed.set_bed_enabled(false)
		bed.release_audio_resources()
		bed.queue_free()


func _gains(bed: StationMusicBed) -> Dictionary:
	return (bed.get_state_snapshot()["layer_gains"] as Dictionary)


func _positions(bed: StationMusicBed) -> Dictionary:
	return (bed.get_state_snapshot()["layer_positions"] as Dictionary)


func _errors_contain(errors: Variant, fragment: String) -> bool:
	for message in errors as PackedStringArray:
		if fragment in str(message):
			return true
	return false


func _test_identity_and_contract() -> void:
	var bed := _make_manual_bed("IdentityBed")
	_check(bed != null, "station music bed scene instantiates as its reusable component type")
	if bed == null:
		return
	await process_frame

	_check(bed.get_component_id() == &"station-music-bed", "bed reports its stable component id")
	var evidence: Dictionary = bed.get_evidence_metadata()
	_check(
		evidence.get("evidence_status") == &"modern_interpretation"
		and evidence.get("design_origin") == &"project_original_offline_music_synthesis"
		and evidence.get("historically_supported") == false,
		"bed is tagged modern interpretation rather than recovered Keth audio"
	)
	_check(
		evidence.get("human_listening_pass") == &"outstanding",
		"bed records that its human listening pass is still outstanding"
	)
	_check(
		"no surviving source" in str(evidence.get("content_note", "")).to_lower(),
		"content note plainly states no source authenticates historical music"
	)

	var contract: Dictionary = bed.get_music_contract()
	_check(contract.get("bus") == &"Music", "bed declares the dedicated Music bus rather than Ambience")
	_check(contract.get("positional") == false, "bed declares itself non-positional")
	_check(contract.get("gameplay_authority") == false, "bed declares that it holds no gameplay authority")
	_check(
		is_equal_approx(float(contract.get("combined_cycle_seconds", 0.0)), 240.0),
		"bed declares the 240-second combined cycle of its 16/12/20-second loops"
	)
	var loop_seconds := contract.get("layer_loop_seconds", {}) as Dictionary
	_check(
		is_equal_approx(float(loop_seconds.get(&"drone", 0.0)), 16.0)
		and is_equal_approx(float(loop_seconds.get(&"harmonics", 0.0)), 12.0)
		and is_equal_approx(float(loop_seconds.get(&"motif", 0.0)), 20.0),
		"bed declares each authored loop length"
	)

	var audit: Dictionary = bed.get_audit_report()
	_check(bool(audit["valid"]), "freshly built bed passes its own audit: %s" % str(audit["errors"]))
	var performance := audit["performance"] as Dictionary
	_check(
		int(performance["maximum_simultaneous_voices"]) == 3
		and int(performance["audio_player_count"]) == 3,
		"bed owns exactly its declared three-voice ceiling"
	)
	_check(
		int(performance["resident_sample_bytes"]) == 2116800
		and bool(performance["within_resident_budget"]),
		"resident loop bank matches the authored byte total and stays inside its budget"
	)
	_check(
		performance.get("runtime_wave_synthesis_allowed") == false,
		"bed never synthesizes waveforms at runtime"
	)
	_release(bed)
	await process_frame


func _test_voice_ceiling_and_routing() -> void:
	var bed := _make_manual_bed("RoutingBed")
	if bed == null:
		return
	await process_frame

	var voices := bed.find_children("*", "AudioStreamPlayer", true, false)
	_check(voices.size() == 3, "bed exposes exactly three non-positional voices")
	var names := PackedStringArray()
	for candidate in voices:
		var player := candidate as AudioStreamPlayer
		names.append(player.name)
		_check(player.bus == &"Music", "voice %s routes through the Music bus" % player.name)
		_check(player.max_polyphony == 1, "voice %s is bounded to a single simultaneous stream" % player.name)
		_check(not player.autoplay, "voice %s stays under component lifecycle control" % player.name)
	names.sort()
	_check(
		names == PackedStringArray(["DroneLayer", "HarmonicsLayer", "MotifLayer"]),
		"the fixed voice roster is exactly the three authored layers"
	)
	_check(
		bed.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(),
		"bed introduces no positional voices"
	)
	_check(
		AudioServer.get_bus_index(&"Music") >= 0,
		"the project bus layout provides the Music bus the bed routes to"
	)

	# The ceiling is enforced, not merely declared: one extra voice fails the audit.
	var intruder := AudioStreamPlayer.new()
	intruder.name = "ExtraVoice"
	bed.add_child(intruder)
	var over_budget: Dictionary = bed.get_audit_report()
	_check(
		not bool(over_budget["valid"])
		and _errors_contain(over_budget["errors"], "exactly three bounded non-positional voices"),
		"an extra voice beyond the declared ceiling fails the audit"
	)
	bed.remove_child(intruder)
	intruder.free()
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "removing the extra voice restores a valid audit")

	# A positional voice would silently turn the bed into diegetic audio.
	var positional := AudioStreamPlayer3D.new()
	positional.name = "PositionalIntruder"
	bed.add_child(positional)
	var positional_audit: Dictionary = bed.get_audit_report()
	_check(
		not bool(positional_audit["valid"])
		and _errors_contain(positional_audit["errors"], "positional voices"),
		"an added positional voice fails the audit"
	)
	bed.remove_child(positional)
	positional.free()

	_release(bed)
	await process_frame


func _test_dummy_backend_seam() -> void:
	var bed := _make_manual_bed("DummyBed")
	if bed == null:
		return
	await process_frame
	var performance := (bed.get_audit_report() as Dictionary)["performance"] as Dictionary
	var driver_is_dummy := AudioServer.get_driver_name() == "Dummy"
	_check(
		bool(performance["playback_available"]) == not driver_is_dummy,
		"bed reports playback availability from the real backend name rather than assuming success"
	)

	_advance(bed, 4.0, 60)
	var gains := _gains(bed)
	_check(
		float(gains[&"drone"]) > 0.5,
		"the deterministic gain envelope runs on every backend, including Dummy"
	)
	if driver_is_dummy:
		var attached := false
		for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
			if (candidate as AudioStreamPlayer).stream != null:
				attached = true
		_check(not attached, "the Dummy backend never receives a playback handle")
		_check(
			int(bed.get_state_snapshot()["layer_start_count"]) == 0,
			"no layer claims to have started under a backend that cannot play"
		)
		_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the silent Dummy lifecycle is a valid audited state")
	_release(bed)
	await process_frame

	# Now the same timeline with a backend that does accept playback.
	var accepting := _make_manual_bed("AcceptingBed", AcceptingMusicBed)
	if accepting == null:
		return
	await process_frame
	_advance(accepting, 4.0, 60)
	var active: PackedStringArray = accepting.get_state_snapshot()["active_layer_ids"]
	_check(active.size() == 3, "an accepting backend attaches all three rest-state layers")
	var streams_attached := 0
	for candidate in accepting.find_children("*", "AudioStreamPlayer", true, false):
		if (candidate as AudioStreamPlayer).stream != null:
			streams_attached += 1
	_check(streams_attached == 3, "each attached layer holds exactly one authored loop stream")
	_check(
		int(accepting.get_state_snapshot()["layer_start_count"]) == 3,
		"each layer starts exactly once rather than restarting every frame"
	)
	_check(bool((accepting.get_audit_report() as Dictionary)["valid"]), "an actively playing bed passes its audit")
	_release(accepting)
	await process_frame


func _test_rejecting_backend_seam() -> void:
	var bed := _make_manual_bed("RejectingBed", RejectingMusicBed)
	if bed == null:
		return
	await process_frame
	_advance(bed, 3.0, 60)
	var attached := false
	for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
		if (candidate as AudioStreamPlayer).stream != null:
			attached = true
	_check(not attached, "a rejected playback request leaves no stream handle attached")
	_check(
		int(bed.get_state_snapshot()["layer_start_count"]) == 0,
		"a rejected playback request never counts as a started layer"
	)
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the rejected-playback fallback is a valid audited state")
	_release(bed)
	await process_frame


func _test_combat_yield_and_recovery() -> void:
	var bed := _make_manual_bed("CombatYieldBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	_layer_events.clear()
	bed.layer_state_changed.connect(_on_layer_state_changed)

	_check(bed.notify_session_state(StationMusicBed.STATE_REST), "the rest state is accepted")
	_advance(bed, 6.0, 60)
	var rest_gains := _gains(bed)
	_check(
		is_equal_approx(float(rest_gains[&"drone"]), 1.0)
		and is_equal_approx(float(rest_gains[&"harmonics"]), 1.0)
		and is_equal_approx(float(rest_gains[&"motif"]), 1.0),
		"the station at rest reaches the full authored three-layer bed"
	)

	_check(bed.notify_session_state(StationMusicBed.STATE_FLIGHT), "the flight state is accepted")
	_advance(bed, 4.0, 60)
	var flight_gains := _gains(bed)
	_check(
		is_equal_approx(float(flight_gains[&"motif"]), 0.0)
		and float(flight_gains[&"drone"]) > 0.5,
		"leaving the station drops the foreground motif and keeps only the sustaining layers"
	)

	_check(bed.notify_session_state(StationMusicBed.STATE_COMBAT), "the combat state is accepted")
	_advance(bed, 1.0, 60)
	var combat_gains := _gains(bed)
	_check(
		is_equal_approx(float(combat_gains[&"drone"]), 0.0)
		and is_equal_approx(float(combat_gains[&"harmonics"]), 0.0)
		and is_equal_approx(float(combat_gains[&"motif"]), 0.0),
		"an encounter silences every music layer inside one second"
	)
	var combat_state: Dictionary = bed.get_state_snapshot()
	_check(
		(combat_state["active_layer_ids"] as PackedStringArray).is_empty(),
		"a silenced bed strands no voice: every layer is stopped and detached"
	)
	for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
		var player := candidate as AudioStreamPlayer
		_check(
			player.stream == null and not player.playing,
			"combat leaves voice %s fully released rather than idling at silence" % player.name
		)

	# The bed must not swell straight back in the moment the last shot lands.
	_check(bed.notify_session_state(StationMusicBed.STATE_REST), "returning to rest is accepted")
	_advance(bed, 2.0, 60)
	var hold_gains := _gains(bed)
	_check(
		is_equal_approx(float(hold_gains[&"drone"]), 0.0),
		"the post-combat hold keeps the bed out while the encounter settles"
	)
	_advance(bed, 8.0, 60)
	var recovered_gains := _gains(bed)
	_check(
		float(recovered_gains[&"drone"]) > 0.5 and float(recovered_gains[&"motif"]) > 0.5,
		"the bed returns after the hold rather than staying dead for the session"
	)
	_check(
		int(bed.get_state_snapshot()["layer_start_count"]) > int(combat_state["layer_start_count"]),
		"recovery restarts the released layers exactly through the normal start path"
	)
	_check(
		not bed.notify_session_state(&"boss_fight"),
		"an unknown session state is rejected instead of silently reinterpreted"
	)
	_check(
		bed.get_session_state() == StationMusicBed.STATE_REST,
		"a rejected state leaves the observed session state untouched"
	)
	_check(not _layer_events.is_empty(), "layer transitions are announced for observers")

	bed.layer_state_changed.disconnect(_on_layer_state_changed)
	_release(bed)
	await process_frame


func _test_phase_crossfade() -> void:
	var bed := _make_manual_bed("PhaseCrossfadeBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	_advance(bed, 6.0, 60)
	_check(bed.notify_music_phase(&"landing"), "landing phase reaches the production music bed")
	var landing := bed.get_state_snapshot() as Dictionary
	_check(
		landing.presentation_state == &"landing"
		and is_equal_approx(float((landing.layer_targets as Dictionary)[&"motif"]), 0.28),
		"landing selects a restrained crossfade profile using the resident authored loops"
	)
	var landing_position := float((landing.layer_positions as Dictionary)[&"drone"])
	_advance(bed, 2.0, 60)
	var settled_landing := bed.get_state_snapshot() as Dictionary
	_check(
		float((settled_landing.layer_gains as Dictionary)[&"motif"]) > 0.2
		and int(settled_landing.active_layer_count) == StationMusicBed.MAXIMUM_SIMULTANEOUS_VOICES,
		"landing crossfade raises the motif without creating another voice"
	)
	_check(
		float((settled_landing.layer_positions as Dictionary)[&"drone"]) > landing_position,
		"landing keeps the resident loop clock continuous"
	)
	_check(bed.notify_music_phase(&"planetary"), "planetary phase is accepted after landing")
	_advance(bed, 1.0, 60)
	var planetary := bed.get_state_snapshot() as Dictionary
	_check(
		float((planetary.layer_gains as Dictionary)[&"motif"])
		< float((settled_landing.layer_gains as Dictionary)[&"motif"]),
		"leaving landing fades the motif back out"
	)
	_check(
		bool(bed.get_audit_report().valid),
		"phase crossfade remains inside the production bed audit"
	)
	_release(bed)
	await process_frame


func _on_layer_state_changed(layer_id: StringName, active: bool) -> void:
	_layer_events.append({"layer": layer_id, "active": active})


func _test_frame_rate_equivalence() -> void:
	var results := {}
	for samples_per_second: int in SAMPLE_RATES:
		var bed := _make_manual_bed("RateBed%d" % samples_per_second, AcceptingMusicBed)
		if bed == null:
			continue
		await process_frame
		# One identical scripted timeline: settle at rest, take a contact, then
		# recover. Only the step size differs between runs.
		bed.notify_session_state(StationMusicBed.STATE_REST)
		_advance(bed, 3.0, samples_per_second)
		bed.notify_session_state(StationMusicBed.STATE_COMBAT)
		_advance(bed, 2.0, samples_per_second)
		bed.notify_session_state(StationMusicBed.STATE_REST)
		_advance(bed, 6.0, samples_per_second)
		var snapshot: Dictionary = bed.get_state_snapshot()
		results[samples_per_second] = {
			"gains": (snapshot["layer_gains"] as Dictionary).duplicate(true),
			"positions": (snapshot["layer_positions"] as Dictionary).duplicate(true),
			"active": snapshot["active_layer_ids"],
			"starts": int(snapshot["layer_start_count"]),
			"stops": int(snapshot["layer_stop_count"]),
			"elapsed": float(snapshot["elapsed_bed_seconds"]),
		}
		_check(
			bool((bed.get_audit_report() as Dictionary)["valid"]),
			"%d Hz equivalent bed timeline ends in a valid audited state" % samples_per_second
		)
		_release(bed)
		await process_frame

	_check(results.size() == SAMPLE_RATES.size(), "30/60/120 Hz equivalent bed timelines all complete")
	if results.size() != SAMPLE_RATES.size():
		return
	var baseline := results[60] as Dictionary
	_check(
		float(baseline["positions"][&"drone"]) > 0.0,
		"the baseline timeline actually advanced the deterministic loop clock"
	)
	for samples_per_second in [30, 120]:
		var candidate := results[samples_per_second] as Dictionary
		var gains_match := true
		var positions_match := true
		for layer_id: StringName in [&"drone", &"harmonics", &"motif"]:
			if absf(
				float((candidate["gains"] as Dictionary)[layer_id])
				- float((baseline["gains"] as Dictionary)[layer_id])
			) > GAIN_TOLERANCE:
				gains_match = false
			if absf(
				float((candidate["positions"] as Dictionary)[layer_id])
				- float((baseline["positions"] as Dictionary)[layer_id])
			) > POSITION_TOLERANCE:
				positions_match = false
		_check(gains_match, "%d Hz equivalent layer gains agree with 60 Hz" % samples_per_second)
		_check(positions_match, "%d Hz equivalent loop positions agree with 60 Hz" % samples_per_second)
		_check(
			(candidate["active"] as PackedStringArray) == (baseline["active"] as PackedStringArray),
			"%d Hz equivalent active-layer set agrees with 60 Hz" % samples_per_second
		)
		_check(
			int(candidate["starts"]) == int(baseline["starts"])
			and int(candidate["stops"]) == int(baseline["stops"]),
			"%d Hz equivalent start/stop accounting agrees with 60 Hz" % samples_per_second
		)
		_check(
			absf(float(candidate["elapsed"]) - float(baseline["elapsed"])) <= 0.001,
			"%d Hz equivalent timeline consumed the same total time" % samples_per_second
		)


func _test_pause_disable_and_reset() -> void:
	var bed := _make_manual_bed("LifecycleBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	_advance(bed, 5.0, 60)
	var before_pause := _positions(bed)

	bed.set_bed_paused(true)
	_check(bed.is_bed_paused(), "the bed reports its paused state")
	for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
		var player := candidate as AudioStreamPlayer
		if player.stream != null:
			_check(player.stream_paused, "paused voice %s holds rather than continuing" % player.name)
	_advance(bed, 3.0, 60)
	var during_pause := _positions(bed)
	_check(
		is_equal_approx(float(during_pause[&"drone"]), float(before_pause[&"drone"])),
		"a paused bed freezes its loop clock instead of running on silently"
	)
	bed.set_bed_paused(false)
	_advance(bed, 1.0, 60)
	_check(
		float(_positions(bed)[&"drone"]) > float(before_pause[&"drone"]),
		"resuming continues the same loop rather than restarting it"
	)
	var resumed_active: PackedStringArray = bed.get_state_snapshot()["active_layer_ids"]
	_check(resumed_active.size() == 3, "resuming does not strand or drop a voice")

	var starts_before_disable := int(bed.get_state_snapshot()["layer_start_count"])
	bed.set_bed_enabled(false)
	_check(not bed.is_bed_enabled(), "the bed reports its disabled state")
	var disabled_state: Dictionary = bed.get_state_snapshot()
	_check(
		(disabled_state["active_layer_ids"] as PackedStringArray).is_empty(),
		"disabling releases every voice"
	)
	for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
		_check(
			(candidate as AudioStreamPlayer).stream == null,
			"disabled voice %s detaches its stream" % (candidate as AudioStreamPlayer).name
		)
	_advance(bed, 3.0, 60)
	_check(
		is_equal_approx(float(_gains(bed)[&"drone"]), 0.0)
		and int(bed.get_state_snapshot()["layer_start_count"]) == starts_before_disable,
		"a disabled bed neither raises gain nor starts a voice"
	)
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the disabled lifecycle is a valid audited state")

	bed.set_bed_enabled(true)
	_advance(bed, 2.0, 60)
	_check(
		float(_positions(bed)[&"drone"]) > 0.0,
		"re-enabling resumes from the retained loop position"
	)

	bed.reset_bed()
	var reset_state: Dictionary = bed.get_state_snapshot()
	_check(
		is_equal_approx(float((reset_state["layer_positions"] as Dictionary)[&"drone"]), 0.0)
		and is_equal_approx(float((reset_state["layer_gains"] as Dictionary)[&"drone"]), 0.0)
		and reset_state["session_state"] == StationMusicBed.STATE_REST
		and is_equal_approx(float(reset_state["elapsed_bed_seconds"]), 0.0),
		"the explicit reset returns the bed to its authored start-of-session condition"
	)
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the reset bed passes its audit")
	_release(bed)
	await process_frame


func _test_no_gameplay_authority() -> void:
	var bed := _make_manual_bed("AuthorityBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	_check(
		bed.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"bed introduces no gameplay collision"
	)
	_check(
		bed.get_meta(&"gameplay_authority", true) == false
		and bed.get_meta(&"historically_supported", true) == false,
		"bed metadata records no gameplay authority and no historical support"
	)
	# The only public mutators are its own presentation state.
	for method_name in [
		"start_shift", "set_phase", "spawn_opponent", "apply_damage", "submit_hitscan"
	]:
		_check(not bed.has_method(method_name), "bed exposes no %s gameplay entry point" % method_name)
	_release(bed)
	await process_frame


func _test_detached_and_queued_mutators_are_inert() -> void:
	var bed := _make_manual_bed("CurrentnessBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	var layer_events: Array[Dictionary] = []
	bed.layer_state_changed.connect(
		func(layer_id: StringName, active: bool) -> void:
			layer_events.append({"layer_id": layer_id, "active": active})
	)
	_check(bed.notify_session_state(StationMusicBed.STATE_COMBAT), "currentness fixture accepts an attached session state")
	var parent := bed.get_parent()
	parent.remove_child(bed)
	await process_frame
	var detached_state := bed.get_state_snapshot()
	var detached_performance := bed.get_performance_report()
	var detached_event_count := layer_events.size()
	_check(
		not bed.notify_session_state(StationMusicBed.STATE_REST),
		"detached bed rejects stale session-state requests"
	)
	bed.set_bed_enabled(false)
	bed.set_bed_paused(true)
	bed.reset_bed()
	_check(
		not bed.is_inside_tree()
		and bed.get_state_snapshot() == detached_state
		and bed.get_performance_report() == detached_performance
		and layer_events.size() == detached_event_count,
		"detached bed public mutators preserve retained state, voices, and signals"
	)
	parent.add_child(bed)
	await process_frame
	_check(
		bed.notify_session_state(StationMusicBed.STATE_REST)
		and bed.is_bed_enabled(),
		"re-added bed accepts a fresh session-state request"
	)
	bed.set_bed_paused(true)
	_check(bed.is_bed_paused(), "re-added bed accepts a fresh pause request")
	bed.set_bed_paused(false)
	bed.set_bed_enabled(false)
	_check(not bed.is_bed_enabled(), "re-added bed accepts a fresh enabled-state request")
	bed.set_bed_enabled(true)
	bed.reset_bed()
	_check(
		bed.get_session_state() == StationMusicBed.STATE_REST,
		"re-added bed accepts a fresh reset request"
	)

	bed.notify_session_state(StationMusicBed.STATE_COMBAT)
	bed.queue_free()
	var queued_state := bed.get_state_snapshot()
	var queued_performance := bed.get_performance_report()
	var queued_event_count := layer_events.size()
	bed.set_bed_enabled(false)
	bed.set_bed_paused(true)
	bed.reset_bed()
	_check(
		bed.is_inside_tree()
		and bed.is_queued_for_deletion()
		and not bed.notify_session_state(StationMusicBed.STATE_REST)
		and bed.get_state_snapshot() == queued_state
		and bed.get_performance_report() == queued_performance
		and layer_events.size() == queued_event_count,
		"queued bed rejects every public mutator without retained-state, voice, or signal drift"
	)
	await process_frame
	_check(not is_instance_valid(bed), "queued currentness fixture frees normally")


func _test_queued_reentry_restore_is_inert() -> void:
	var bed := _make_manual_bed("QueuedReentryBed", AcceptingMusicBed)
	if bed == null:
		return
	await process_frame
	var parent := bed.get_parent()
	parent.remove_child(bed)
	await process_frame
	parent.add_child(bed)
	# `_enter_tree()` has now queued its normal restore. A terminal disposal in
	# the same turn must make that restore inert: no voice may be reattached after
	# the owner has committed to deletion.
	bed.queue_free()
	var before := bed.get_state_snapshot()
	var performance_before := bed.get_performance_report()
	bed.call("_restore_after_enter_tree")
	var after := bed.get_state_snapshot()
	var performance_after := bed.get_performance_report()
	_check(
		bed.is_queued_for_deletion()
		and after == before
		and performance_after == performance_before
		and (after["active_layer_ids"] as PackedStringArray).is_empty(),
		"a queued post-reentry music bed cannot restore playback or mutate retained state"
	)
	await process_frame
	_check(not is_instance_valid(bed), "the queued re-entry music-bed fixture frees normally")


func _test_whole_main_detach_and_reentry() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the music-bed re-entry check")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var bed := game.get_music_bed()
	_check(bed != null, "production Main owns exactly one station music bed")
	if bed == null:
		game.queue_free()
		await process_frame
		return
	_check(
		game.get_node_or_null("StationMusicBed") == bed,
		"the bed is a first-class fixed child of Main rather than a runtime insertion"
	)
	_check(
		root.find_children("*", "StationMusicBed", true, false).size() == 1,
		"only one music bed exists in the running tree"
	)
	_check(
		bed.get_session_state() == StationMusicBed.STATE_REST,
		"the flow reports the pre-launch station as the resting state"
	)
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the production bed passes its audit in Main")

	# Give the deterministic envelope and loop clock somewhere to be.
	bed.set_process(false)
	_advance(bed, 5.0, 60)
	var before_detach: Dictionary = bed.get_state_snapshot()
	var positions_before := (before_detach["layer_positions"] as Dictionary).duplicate(true)
	var starts_before := int(before_detach["layer_start_count"])

	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	var detached_state: Dictionary = bed.get_state_snapshot()
	_check(
		(detached_state["active_layer_ids"] as PackedStringArray).is_empty(),
		"a detached Main leaves no music voice playing"
	)
	for candidate in bed.find_children("*", "AudioStreamPlayer", true, false):
		_check(
			(candidate as AudioStreamPlayer).stream == null,
			"detached voice %s releases its playback handle" % (candidate as AudioStreamPlayer).name
		)
	_check(
		is_equal_approx(
			float((detached_state["layer_positions"] as Dictionary)[&"drone"]),
			float(positions_before[&"drone"])
		),
		"the detach retains the loop position instead of rewinding the bed"
	)

	parent.add_child(game)
	await process_frame
	await process_frame
	var after_reentry: Dictionary = bed.get_state_snapshot()
	_check(
		is_equal_approx(
			float((after_reentry["layer_positions"] as Dictionary)[&"drone"]),
			float(positions_before[&"drone"])
		),
		"re-entry resumes the retained loop position rather than replaying from the beginning"
	)
	_check(
		int(after_reentry["state_change_count"]) == int(before_detach["state_change_count"]),
		"re-entry re-states the observed session state without inventing a transition"
	)
	_check(
		root.find_children("*", "StationMusicBed", true, false).size() == 1,
		"re-entry does not duplicate the music bed"
	)
	var live_voices := bed.find_children("*", "AudioStreamPlayer", true, false)
	_check(live_voices.size() == 3, "re-entry preserves the exact three-voice roster")
	if AudioServer.get_driver_name() == "Dummy":
		_check(
			int(after_reentry["layer_start_count"]) == starts_before,
			"a backend that cannot play starts no voice on re-entry, so nothing double-starts"
		)
	else:
		_check(
			int(after_reentry["layer_start_count"]) <= starts_before + 3,
			"re-entry restarts each layer at most once, so nothing double-starts"
		)
	_check(bool((bed.get_audit_report() as Dictionary)["valid"]), "the re-entered bed passes its audit")

	bed.set_bed_enabled(false)
	bed.release_audio_resources()
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_MUSIC_BED_TEST_OK")
		quit(0)
	else:
		print("STATION_MUSIC_BED_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
