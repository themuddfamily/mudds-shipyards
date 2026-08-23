extends SceneTree

const ProductionOwner := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)
const AudioBinding := preload(
	"res://scripts/audio/ember_surface_loop_audio_production_binding.gd"
)

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := ProductionOwner.new()
	var audio := AudioBinding.new()
	root.add_child(owner)
	root.add_child(audio)
	var craft_ids: Array[StringName] = [
		&"arrow", &"torrent", &"jovian", &"zenith", &"halyard",
	]
	var voice_instance_id := 0
	var prior_stream_instance_id := 0
	for craft_index in craft_ids.size():
		var craft_id := craft_ids[craft_index]
		var generation := craft_index + 1
		_check(
			bool(audio.attach(owner, &"exterior").accepted),
			"%s attaches to the retained production audio path" % craft_id,
		)
		_check(
			bool(audio.set_reduced_dynamic_range(false).accepted),
			"%s accepts the normal dynamic-range profile" % craft_id,
		)
		owner.state_changed.emit(_entry_snapshot(
			generation, 1, craft_id, &"atmospheric", 0.25
		))
		var low := audio.get_snapshot()
		var low_bed := low.entry_bed as Dictionary
		var low_voice := low.continuous_voice as Dictionary
		owner.state_changed.emit(_entry_snapshot(
			generation, 2, craft_id, &"atmospheric", 0.75
		))
		var high := audio.get_snapshot()
		var high_bed := high.entry_bed as Dictionary
		var high_voice := high.continuous_voice as Dictionary
		var current_voice_id := int(high_bed.voice_instance_id)
		var current_stream_id := int(high_bed.stream_instance_id)
		if voice_instance_id == 0:
			voice_instance_id = current_voice_id
		_check(
			low_bed.branch_id == &"atmospheric"
			and low_bed.craft_id == craft_id
			and is_equal_approx(float(low_bed.accepted_entry_intensity_unitless), 0.25)
			and is_equal_approx(float(low_bed.target_intensity_unitless), 0.205)
			and float(low_bed.intensity_unitless) > 0.0
			and bool(low_bed.playback_requested)
			and bool(high_bed.continuous_intensity_response)
			and is_equal_approx(float(high_bed.accepted_entry_intensity_unitless), 0.75)
			and float(high_bed.target_intensity_unitless) \
				> float(low_bed.target_intensity_unitless)
			and float(high_bed.intensity_unitless) \
				> float(low_bed.intensity_unitless)
			and low_voice.active_mode == &"atmospheric_entry_wind_heat"
			and high_voice.active_mode == &"atmospheric_entry_wind_heat"
			and float(high_voice.pitch_scale) > float(low_voice.pitch_scale)
			and float(high_voice.pitch_scale) <= AudioBinding.ENTRY_BED_MAX_PITCH
			and current_voice_id > 0 and current_voice_id == voice_instance_id
			and current_stream_id != 0
			and int(high_voice.voice_ceiling) == 1
			and int(high.maximum_simultaneous_voices) == 2,
			"%s receives a monotonic accepted-intensity bed on the existing voice" \
				% craft_id,
		)

		_check(
			bool(audio.set_perspective(&"interior").accepted),
			"%s accepts cockpit attenuation" % craft_id,
		)
		var interior := audio.get_snapshot().entry_bed as Dictionary
		_check(
			is_equal_approx(float(interior.perspective_gain),
				AudioBinding.ENTRY_BED_INTERIOR_GAIN)
			and float(interior.target_intensity_unitless) \
				< float(high_bed.target_intensity_unitless),
			"%s cockpit perspective attenuates the same retained bed" % craft_id,
		)
		audio.set_perspective(&"exterior")
		var exterior := audio.get_snapshot().entry_bed as Dictionary
		_check(
			bool(audio.set_reduced_dynamic_range(true).accepted),
			"%s accepts reduced dynamic range" % craft_id,
		)
		var reduced := audio.get_snapshot().entry_bed as Dictionary
		_check(
			bool(reduced.reduced_dynamic_range)
			and is_equal_approx(float(reduced.target_intensity_unitless), 0.435)
			and float(reduced.target_intensity_unitless) \
				< float(exterior.target_intensity_unitless)
			and float(reduced.intensity_unitless) \
				<= float(reduced.target_intensity_unitless),
			"%s reduced range deterministically caps the atmospheric bed" % craft_id,
		)
		var phase_exit_snapshot := _entry_snapshot(
			generation, 3, craft_id, &"atmospheric", 0.75
		)
		phase_exit_snapshot["state_id"] = &"landed"
		owner.state_changed.emit(phase_exit_snapshot)
		var phase_exit := audio.get_snapshot()
		_check(
			not bool((phase_exit.entry_bed as Dictionary).entry_phase_active)
			and is_zero_approx(float(
				(phase_exit.entry_bed as Dictionary).intensity_unitless
			))
			and (phase_exit.continuous_voice as Dictionary).active_mode == &"silence",
			"%s leaving the entry phase recovers the bed to silence" % craft_id,
		)

		owner.state_changed.emit(_entry_snapshot(
			generation, 4, craft_id, &"airless", 0.0
		))
		var airless := audio.get_snapshot()
		var airless_bed := airless.entry_bed as Dictionary
		_check(
			airless_bed.branch_id == &"airless"
			and bool(airless_bed.airless_exact_silence)
			and is_zero_approx(float(airless_bed.target_intensity_unitless))
			and is_zero_approx(float(airless_bed.intensity_unitless))
			and not bool(airless_bed.playback_requested)
			and (airless.continuous_voice as Dictionary).active_mode == &"silence"
			and not bool((airless.continuous_voice as Dictionary).playback_requested),
			"%s produces exact atmospheric-bed silence on airless Ember" % craft_id,
		)

		_check(bool(audio.detach().accepted), "%s detaches cleanly" % craft_id)
		var detached := audio.get_snapshot()
		var detached_bed := detached.entry_bed as Dictionary
		owner.state_changed.emit(_entry_snapshot(
			generation, 5, craft_id, &"atmospheric", 1.0
		))
		_check(
			not bool(detached.attached)
			and detached_bed.branch_id == &"unavailable"
			and is_zero_approx(float(detached_bed.intensity_unitless))
			and int(detached_bed.stream_instance_id) == 0
			and audio.get_snapshot().entry_bed == detached_bed
			and audio.find_children(
				"AirlessAltitudeHullResonance", "AudioStreamPlayer", false, false
			).size() == 1,
			"%s detach fences stale samples and retains exactly one reusable voice" \
				% craft_id,
		)
		if prior_stream_instance_id != 0:
			_check(
				current_stream_id != prior_stream_instance_id,
				"%s re-entry rebuilt a fresh stream generation" % craft_id,
			)
		else:
			_check(true, "%s establishes the first stream generation" % craft_id)
		prior_stream_instance_id = current_stream_id

	audio.free()
	owner.free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print(
		"HERO_FLEET_ENTRY_AUDIO_BED_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _entry_snapshot(
		owner_generation: int, observation_count: int, craft_id: StringName,
		branch_id: StringName, intensity: float
	) -> Dictionary:
	var snapshot := {
		"generation": owner_generation,
		"state_id": &"running",
		"last_prepared_evidence": {"delta": 0.35},
	}.duplicate(true)
	if craft_id == &"arrow":
		var retained := {
			"accepted": true,
			"source": {
				"branch_id": branch_id,
				"altitude_m": 10_000.0 if branch_id == &"atmospheric" else 100.0,
				"vertical_speed_mps": -20.0,
				"entry_intensity": intensity,
				"landing_supported": false,
				"craft_id": craft_id,
			},
		}.duplicate(true)
		snapshot["entry_presentation"] = {
			"generation": 1,
			"observation_count": observation_count,
			"last_result": retained.duplicate(true),
		}
		snapshot["last_entry_presentation_result"] = retained
		return snapshot
	snapshot["fleet_entry_envelope_presentation"] = {
		"attached": true,
		"craft_id": craft_id,
		"generation": 1,
		"observation_serial": observation_count,
		"accepted_atmosphere_sample": {
			"accepted": true,
			"entry_effect_intensity": intensity,
			"inputs": {
				"altitude_m": 10_000.0 if branch_id == &"atmospheric" else 100.0,
			},
		},
		"envelope": {"branch_id": branch_id},
	}.duplicate(true)
	return snapshot


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
