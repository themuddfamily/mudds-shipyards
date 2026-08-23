extends SceneTree

const ProductionOwner := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)
const AudioBinding := preload(
	"res://scripts/audio/ember_surface_loop_audio_production_binding.gd"
)

var _failures := PackedStringArray()
var _assertions := 0


class FakeEmberRoot:
	extends Node3D
	func get_world_id() -> StringName:
		return &"ember_moon"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := ProductionOwner.new()
	var audio := AudioBinding.new()
	var ember_root := FakeEmberRoot.new()
	ember_root.position = Vector3(120.0, -80.0, 45.0)
	root.add_child(owner)
	root.add_child(audio)
	root.add_child(ember_root)
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
			"%s attaches through the retained production audio path" % craft_id,
		)
		audio.set_reduced_dynamic_range(false)
		owner.state_changed.emit(_landing_snapshot(
			generation, 1, craft_id, 0.25, ember_root
		))
		var low := audio.get_snapshot()
		var low_bed := low.landing_bed as Dictionary
		var low_voice := low.continuous_voice as Dictionary
		owner.state_changed.emit(_landing_snapshot(
			generation, 2, craft_id, 0.75, ember_root
		))
		var high := audio.get_snapshot()
		var high_bed := high.landing_bed as Dictionary
		var high_voice := high.continuous_voice as Dictionary
		var high_altitude := high.altitude_transition as Dictionary
		var current_voice_id := int(high.entry_bed.voice_instance_id)
		var current_stream_id := int(high.entry_bed.stream_instance_id)
		if voice_instance_id == 0:
			voice_instance_id = current_voice_id
		_check(
			bool(low_bed.supported_airless_approach)
			and low_bed.craft_id == craft_id
			and low_bed.reason == &"accepted_clearance_descent_load"
			and is_equal_approx(float(
				low_bed.accepted_clearance_descent_load_unitless
			), 0.25)
			and is_equal_approx(float(low_bed.target_intensity_unitless), 0.22)
			and bool(high_bed.continuous_load_response)
			and is_equal_approx(float(
				high_bed.accepted_clearance_descent_load_unitless
			), 0.75)
			and is_equal_approx(float(high_bed.target_intensity_unitless), 0.66)
			and float(high_bed.intensity_unitless) \
				> float(low_bed.intensity_unitless)
			and low_voice.active_mode == &"airless_landing_thruster_regolith"
			and high_voice.active_mode == &"airless_landing_thruster_regolith"
			and float(high_voice.pitch_scale) > float(low_voice.pitch_scale)
			and float(high_voice.pitch_scale) <= AudioBinding.LANDING_BED_MAX_PITCH
			and is_equal_approx(float(high_voice.combined_intensity_unitless),
				float(high_bed.intensity_unitless))
			and float(high_altitude.intensity_unitless) > 0.0
			and not bool(high_altitude.playback_requested)
			and current_voice_id > 0 and current_voice_id == voice_instance_id
			and current_stream_id != 0
			and int(high_voice.voice_ceiling) == 1
			and int(high.maximum_simultaneous_voices) == 2,
			"%s follows the accepted wash load on one exclusive continuous voice" \
				% craft_id,
		)

		audio.set_perspective(&"interior")
		var interior := audio.get_snapshot().landing_bed as Dictionary
		_check(
			is_equal_approx(float(interior.perspective_gain),
				AudioBinding.LANDING_BED_INTERIOR_GAIN)
			and is_equal_approx(float(interior.target_intensity_unitless), 0.4125)
			and float(interior.intensity_unitless) \
				< float(high_bed.intensity_unitless),
			"%s cockpit perspective attenuates the mechanical/regolith bed" % craft_id,
		)
		audio.set_perspective(&"exterior")
		var exterior := audio.get_snapshot().landing_bed as Dictionary
		audio.set_reduced_dynamic_range(true)
		var reduced := audio.get_snapshot().landing_bed as Dictionary
		_check(
			bool(reduced.reduced_dynamic_range)
			and is_equal_approx(float(reduced.target_intensity_unitless), 0.465)
			and float(reduced.intensity_unitless) \
				< float(exterior.intensity_unitless),
			"%s reduced dynamic range caps the retained landing bed" % craft_id,
		)

		owner.state_changed.emit(_unsupported_snapshot(
			generation, 3, craft_id, ember_root
		))
		var unsupported := audio.get_snapshot()
		var unsupported_bed := unsupported.landing_bed as Dictionary
		_check(
			not bool(unsupported_bed.supported_airless_approach)
			and unsupported_bed.reason == &"landing_support_unavailable"
			and bool(unsupported_bed.exact_zero_outside_supported_airless_approach)
			and is_zero_approx(float(unsupported_bed.target_intensity_unitless))
			and is_zero_approx(float(unsupported_bed.intensity_unitless))
			and not bool(unsupported_bed.playback_requested)
			and (unsupported.continuous_voice as Dictionary).active_mode \
				== &"airless_hull_resonance",
			"%s unsupported approach has exact zero landing-bed contribution" \
				% craft_id,
		)

		var atmospheric_snapshot := _landing_snapshot(
			generation, 4, craft_id, 0.0, ember_root
		)
		_set_atmospheric_entry(atmospheric_snapshot, craft_id)
		owner.state_changed.emit(atmospheric_snapshot)
		var atmospheric := audio.get_snapshot()
		_check(
			not bool((atmospheric.landing_bed as Dictionary).supported_airless_approach)
			and (atmospheric.landing_bed as Dictionary).reason \
				== &"atmospheric_branch_zero"
			and is_zero_approx(float(
				(atmospheric.landing_bed as Dictionary).intensity_unitless
			))
			and (atmospheric.continuous_voice as Dictionary).active_mode \
				== &"atmospheric_entry_wind_heat",
			"%s multiplexes atmospheric entry without overlapping landing audio" \
				% craft_id,
		)

		var outside_phase := _landing_snapshot(
			generation, 5, craft_id, 0.75, ember_root
		)
		outside_phase["phase_id"] = &"descent"
		owner.state_changed.emit(outside_phase)
		var outside := audio.get_snapshot().landing_bed as Dictionary
		_check(
			outside.reason == &"outside_landing_approach"
			and bool(outside.exact_zero_outside_supported_airless_approach)
			and is_zero_approx(float(outside.intensity_unitless)),
			"%s leaves the landing bed at exact zero outside final approach" % craft_id,
		)

		_check(bool(audio.detach().accepted), "%s detaches cleanly" % craft_id)
		var detached := audio.get_snapshot()
		var detached_bed := detached.landing_bed as Dictionary
		owner.state_changed.emit(_landing_snapshot(
			generation, 6, craft_id, 1.0, ember_root
		))
		_check(
			not bool(detached.attached)
			and detached_bed.reason == &"unavailable"
			and is_zero_approx(float(detached_bed.intensity_unitless))
			and int(detached.entry_bed.stream_instance_id) == 0
			and audio.get_snapshot().landing_bed == detached_bed
			and audio.find_children(
				"AirlessAltitudeHullResonance", "AudioStreamPlayer", false, false
			).size() == 1,
			"%s detach fences stale load and retains one reusable player" % craft_id,
		)
		if prior_stream_instance_id != 0:
			_check(
				current_stream_id != prior_stream_instance_id,
				"%s craft switch receives a fresh stream generation" % craft_id,
			)
		else:
			_check(true, "%s establishes the first stream generation" % craft_id)
		prior_stream_instance_id = current_stream_id

	audio.free()
	owner.free()
	ember_root.free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print(
		"HERO_FLEET_LANDING_AUDIO_BED_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _landing_snapshot(
		owner_generation: int, observation_count: int, craft_id: StringName,
		load: float, ember_root: Node3D
	) -> Dictionary:
	var wash := {
		"presentation_load": load,
		"support_clearance_factor": load,
		"descent_factor": 1.0,
		"landing_supported": true,
		"last_reason": &"low_altitude_descent",
	}.duplicate(true)
	var snapshot := _base_snapshot(
		owner_generation, craft_id, ember_root, &"landing_approach"
	)
	_set_airless_entry(snapshot, craft_id, observation_count)
	if craft_id == &"arrow":
		(snapshot.entry_presentation as Dictionary)["landing_wash"] = wash
		(snapshot.last_entry_presentation_result as Dictionary)["landing_wash"] = {
			"accepted": true,
			"reason": &"low_altitude_descent",
		}
	else:
		snapshot["fleet_landing_wash_presentation"] = {
			"attached": true,
			"craft_id": craft_id,
			"wash": wash,
		}
		snapshot["last_fleet_landing_wash_result"] = {
			"accepted": true,
			"reason": &"low_altitude_descent",
		}
	return snapshot


func _unsupported_snapshot(
		owner_generation: int, observation_count: int, craft_id: StringName,
		ember_root: Node3D
	) -> Dictionary:
	var snapshot := _landing_snapshot(
		owner_generation, observation_count, craft_id, 0.0, ember_root
	)
	var wash := _wash_from_snapshot(snapshot, craft_id)
	wash["landing_supported"] = false
	wash["last_reason"] = &"landing_support_unavailable"
	return snapshot


func _set_atmospheric_entry(snapshot: Dictionary, craft_id: StringName) -> void:
	var wash := _wash_from_snapshot(snapshot, craft_id)
	wash["presentation_load"] = 0.0
	wash["landing_supported"] = true
	wash["last_reason"] = &"atmospheric_branch_zero"
	if craft_id == &"arrow":
		var source := (snapshot.last_entry_presentation_result as Dictionary).source \
			as Dictionary
		source["branch_id"] = &"atmospheric"
		source["entry_intensity"] = 1.0
	else:
		var entry := snapshot.fleet_entry_envelope_presentation as Dictionary
		(entry.envelope as Dictionary)["branch_id"] = &"atmospheric"
		(entry.accepted_atmosphere_sample as Dictionary)[
			"entry_effect_intensity"
		] = 1.0


func _wash_from_snapshot(snapshot: Dictionary, craft_id: StringName) -> Dictionary:
	return (snapshot.entry_presentation as Dictionary).landing_wash as Dictionary \
		if craft_id == &"arrow" else (
			snapshot.fleet_landing_wash_presentation as Dictionary
		).wash as Dictionary


func _set_airless_entry(
		snapshot: Dictionary, craft_id: StringName, observation_count: int
	) -> void:
	if craft_id == &"arrow":
		var retained := {
			"accepted": true,
			"source": {
				"branch_id": &"airless",
				"altitude_m": 45.0,
				"vertical_speed_mps": -32.0,
				"entry_intensity": 0.0,
				"landing_supported": true,
				"craft_id": craft_id,
			},
		}.duplicate(true)
		snapshot["entry_presentation"] = {
			"generation": 1,
			"observation_count": observation_count,
			"last_result": retained.duplicate(true),
		}
		snapshot["last_entry_presentation_result"] = retained
		return
	snapshot["fleet_entry_envelope_presentation"] = {
		"attached": true,
		"craft_id": craft_id,
		"generation": 1,
		"observation_serial": observation_count,
		"accepted_atmosphere_sample": {
			"accepted": true,
			"entry_effect_intensity": 0.0,
			"inputs": {"altitude_m": 45.0},
		},
		"envelope": {"branch_id": &"airless"},
	}.duplicate(true)


func _base_snapshot(
		owner_generation: int, craft_id: StringName, ember_root: Node3D,
		phase_id: StringName
	) -> Dictionary:
	return {
		"generation": owner_generation,
		"phase_id": phase_id,
		"identities": {"loaded_scene_instance_id": ember_root.get_instance_id()},
		"last_prepared_evidence": {
			"delta": 0.35,
			"actor_sample": {
				"actor_kind": &"ship",
				"position": ember_root.global_position \
					+ Vector3(0.0, 120_045.0, 0.0),
			},
			"caller_kinematics": {
				"velocity_mps": Vector3(0.0, -32.0, 0.0),
				"craft_id": craft_id,
			},
		},
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
