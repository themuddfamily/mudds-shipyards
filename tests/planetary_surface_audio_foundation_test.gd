extends SceneTree

## Focused isolated audit for the temperate surface-audio asset/catalog/binding
## foundation. This intentionally does not instantiate Main or prove native
## audibility; production/context wiring is outside the foundation.

const ASSET_DIRECTORY := "res://assets/audio/planetary"
const MANIFEST_PATH := ASSET_DIRECTORY + "/temperate_surface_audio_v1_asset_manifest.json"
const CATALOG_PATH := ASSET_DIRECTORY + "/temperate_surface_audio_catalog.tres"
const BINDING_SCENE := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const SAMPLE_RATE := 24_000
const LOOP_FRAMES := 192_000
const LOOP_END_FRAME := LOOP_FRAMES - 1
const EXPECTED_LOOPS := {
	"temperate_exterior_wind_air_v1.wav": {
		"profile_id": &"temperate_exterior",
		"pcm_sha256": "aee627cee390c218c22242785257dafc994012f1a00c5a549a9b660e7ca2710e",
		"raw_sha256": "5c04b1711a696033e8f3a770a94568845265cbdf0294118f5751d99acc063320",
	},
	"temperate_interior_cabin_air_v1.wav": {
		"profile_id": &"temperate_interior",
		"pcm_sha256": "30f72556aa14e36e49921a8011f5a8bfd7136d85d2ebd2115bbdad05e0ff76c3",
		"raw_sha256": "a63fab5afc695f2422394c5720dde6f73e34f8bc04a1a2d3ffcf52eefc13fc28",
	},
}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_assets_and_manifest()
	_test_catalog_contract()
	await _test_binding_contract()
	_finish()


func _test_assets_and_manifest() -> void:
	_check(FileAccess.file_exists(MANIFEST_PATH), "the fixed asset manifest is checked in")
	var manifest := _read_json(MANIFEST_PATH)
	var format := manifest.get("format_contract", {}) as Dictionary
	_check(
		int(manifest.get("schema_version", 0)) == 1
		and str(manifest.get("asset_id", "")) == "mudds.audio.planetary.temperate_surface_loops.v1"
		and str(manifest.get("authorship", "")) == "project_original_fixed_seed_offline_periodic_synthesis"
		and not bool(manifest.get("recorded_or_sampled_source_material", true))
		and not bool(manifest.get("runtime_generation", true)),
		"manifest records two original offline assets without sampled material"
	)
	_check(
		int(format.get("sample_rate_hz", 0)) == SAMPLE_RATE
		and int(format.get("channels", 0)) == 1
		and int(format.get("bit_depth", 0)) == 16
		and str(format.get("loop_mode", "")) == "forward"
		and int(format.get("loop_begin_frame", -1)) == 0
		and int(format.get("loop_end_frame", -1)) == LOOP_END_FRAME,
		"manifest freezes mono PCM16 forward-loop delivery"
	)
	var records := {}
	for value in manifest.get("loops", []) as Array:
		if value is Dictionary:
			records[str((value as Dictionary).get("filename", ""))] = value
	_check(records.size() == EXPECTED_LOOPS.size(), "manifest has exactly two loop records")
	for filename in EXPECTED_LOOPS:
		var expected := EXPECTED_LOOPS[filename] as Dictionary
		var path := ASSET_DIRECTORY.path_join(filename)
		var record := records.get(filename, {}) as Dictionary
		_check(FileAccess.file_exists(path), "authored WAV exists: %s" % filename)
		_check(
			FileAccess.get_sha256(path) == expected.raw_sha256
			and str(record.get("raw_file_sha256", "")) == expected.raw_sha256
			and str(record.get("pcm_payload_sha256", "")) == expected.pcm_sha256,
			"raw and declared identities are frozen: %s" % filename
		)
		var stream := ResourceLoader.load(
			path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE
		) as AudioStreamWAV
		_check(
			stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS
			and not stream.stereo and stream.mix_rate == SAMPLE_RATE
			and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and stream.loop_begin == 0 and stream.loop_end == LOOP_END_FRAME
			and stream.data.size() == LOOP_FRAMES * 2,
			"Godot preserves the complete imported loop contract: %s" % filename
		)
		if stream == null:
			continue


func _test_catalog_contract() -> void:
	var catalog := load(CATALOG_PATH) as PlanetarySurfaceAudioCatalog
	_check(catalog != null and catalog.is_definition_valid(), "the exact two-entry catalog audits green")
	if catalog == null:
		return
	var snapshot := catalog.get_snapshot()
	_check(
		snapshot.profile_ids == [
			PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID,
			PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID,
		]
		and int(snapshot.entry_count) == 2 and snapshot.audio_bus == &"Ambience",
		"catalog exposes only the two policy IDs on Ambience"
	)
	var exterior := catalog.resolve_stream(PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID)
	var interior := catalog.resolve_stream(PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID)
	_check(
		exterior != null and interior != null and exterior != interior
		and catalog.resolve_stream(&"unknown") == null,
		"catalog resolves exact imported identities and rejects unknown IDs"
	)
	if exterior == null:
		return
	var baseline := catalog.get_snapshot()
	var original_data := exterior.data.duplicate()
	var corrupted_data := original_data.duplicate()
	corrupted_data[0] ^= 0x01
	exterior.data = corrupted_data
	_check(
		not catalog.is_definition_valid()
		and catalog.resolve_stream(PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID) == null,
		"mutated live PCM makes immutable catalog resolution fail closed"
	)
	exterior.data = original_data
	_check(catalog.is_definition_valid() and catalog.get_snapshot() == baseline, "restored imported PCM returns the frozen catalog")


func _test_binding_contract() -> void:
	var binding := BINDING_SCENE.instantiate() as PlanetarySurfaceAudioPlaybackBinding
	_check(binding != null, "standalone playback binding scene instantiates")
	if binding == null:
		return
	root.add_child(binding)
	await process_frame
	var exterior := binding.get_node_or_null("ExteriorVoice") as AudioStreamPlayer
	var interior := binding.get_node_or_null("InteriorVoice") as AudioStreamPlayer
	_check(
		exterior != null and interior != null
		and binding.find_children("*", "AudioStreamPlayer", true, false).size() == 2
		and binding.find_children("*", "AudioStreamPlayer2D", true, false).is_empty()
		and binding.find_children("*", "AudioStreamPlayer3D", true, false).is_empty()
		and exterior.bus == &"Ambience" and interior.bus == &"Ambience"
		and exterior.max_polyphony == 1 and interior.max_polyphony == 1,
		"binding owns exactly two direct non-positional one-voice Ambience players"
	)
	var catalog := load(CATALOG_PATH) as PlanetarySurfaceAudioCatalog
	var configuration := binding.configure(catalog)
	_check(bool(configuration.accepted), "binding accepts one valid immutable catalog")
	var attachment := binding.attach(&"temperate_game_scale", 1001, 7, 11, binding.get_attachment_generation())
	_check(bool(attachment.accepted), "binding accepts only caller-supplied opaque attachment identities")
	var reentrant_reasons := PackedStringArray()
	binding.state_committed.connect(func(_reason: StringName, _snapshot: Dictionary) -> void:
		reentrant_reasons.append(String(binding.set_paused(false, binding.get_attachment_generation()).get("reason", &"")))
	)
	# The three stale upstream identities must reject before a policy value can
	# reach a voice. They are opaque caller values; the binding never resolves
	# the root or samples any context itself.
	var attachment_generation := binding.get_attachment_generation()
	_check(
		binding.present_policy_result(_policy_result(&"exterior"), 0.75, attachment_generation, 1002, 7, 11).reason == &"stale_root_instance"
		and binding.present_policy_result(_policy_result(&"exterior"), 0.75, attachment_generation, 1001, 8, 11).reason == &"stale_frame_generation"
		and binding.present_policy_result(_policy_result(&"exterior"), 0.75, attachment_generation, 1001, 7, 12).reason == &"stale_location_generation",
		"stale root, frame, and location identities reject before local playback"
	)
	var exterior_result := binding.present_policy_result(
		_policy_result(&"exterior"), 0.75, attachment_generation, 1001, 7, 11
	)
	var exterior_fade := binding.get_state_snapshot().fade as Dictionary
	_check(
		bool(exterior_result.accepted)
		and is_equal_approx(float(exterior_fade.route_mix_unitless), 0.0)
		and is_equal_approx(float(exterior_fade.intensity_unitless), 0.8)
		and is_equal_approx(float(exterior_fade.exterior_route_weight_unitless), 1.0)
		and is_equal_approx(float(exterior_fade.interior_route_weight_unitless), 0.0),
		"one accepted exterior result reaches its exact equal-power endpoint"
	)
	var midpoint_result := binding.present_policy_result(
		_policy_result(&"cabin"), 0.375, attachment_generation, 1001, 7, 11
	)
	var midpoint_fade := binding.get_state_snapshot().fade as Dictionary
	_check(
		bool(midpoint_result.accepted)
		and is_equal_approx(float(midpoint_fade.route_mix_unitless), 0.5)
		and is_equal_approx(float(midpoint_fade.exterior_route_weight_unitless), sqrt(0.5))
		and is_equal_approx(float(midpoint_fade.interior_route_weight_unitless), sqrt(0.5))
		and is_equal_approx(float(midpoint_fade.equal_power_sum), 1.0),
		"cabin aliases interior through the 0.75-second equal-power midpoint"
	)
	var interior_result := binding.present_policy_result(
		_policy_result(&"interior"), 0.375, attachment_generation, 1001, 7, 11
	)
	var interior_fade := binding.get_state_snapshot().fade as Dictionary
	_check(
		bool(interior_result.accepted)
		and is_equal_approx(float(interior_fade.route_mix_unitless), 1.0)
		and is_equal_approx(float(interior_fade.exterior_route_weight_unitless), 0.0)
		and is_equal_approx(float(interior_fade.interior_route_weight_unitless), 1.0),
		"interior reaches its exact equal-power endpoint after 0.75 seconds"
	)
	_check(reentrant_reasons.has("reentrant_call"), "commit signals reject reentrant state mutation")
	# Removing the attached node is a safety teardown, not a suspended playback
	# state. Re-entry must reject the old generation and never resurrect streams.
	root.remove_child(binding)
	await process_frame
	root.add_child(binding)
	await process_frame
	var reentered := binding.get_state_snapshot()
	_check(
		not bool(reentered.attached)
		and not bool((reentered.voices.exterior as Dictionary).stream_attached)
		and not bool((reentered.voices.interior as Dictionary).stream_attached)
		and binding.attach(&"temperate_game_scale", 1001, 7, 11, attachment_generation).reason == &"stale_attachment_generation",
		"tree re-entry clears both voice handles and rejects the stale attachment generation"
	)
	var fresh_attachment := binding.attach(
		&"temperate_game_scale", 1001, 7, 11, binding.get_attachment_generation()
	)
	_check(bool(fresh_attachment.accepted), "a fresh generation can attach after tree re-entry")
	attachment_generation = binding.get_attachment_generation()
	var exterior_stream := catalog.resolve_stream(PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID)
	var original_data := exterior_stream.data.duplicate()
	var corrupted_data := original_data.duplicate()
	corrupted_data[0] ^= 0x01
	exterior_stream.data = corrupted_data
	var drift_result := binding.present_policy_result(
		_policy_result(&"exterior"), 0.0, attachment_generation, 1001, 7, 11
	)
	var drift_snapshot := binding.get_state_snapshot()
	_check(
		not bool(drift_result.accepted) and drift_result.reason == &"catalog_contract_lost"
		and not bool(drift_snapshot.attached)
		and not bool((drift_snapshot.voices.exterior as Dictionary).stream_attached)
		and not bool((drift_snapshot.voices.interior as Dictionary).stream_attached),
		"catalog PCM drift immediately detaches and clears both local voices"
	)
	exterior_stream.data = original_data
	var detach_attachment := binding.attach(
		&"temperate_game_scale", 1001, 7, 11, binding.get_attachment_generation()
	)
	_check(bool(detach_attachment.accepted), "restored catalog permits a new caller attachment")
	var detach_result := binding.detach(&"root_lost", binding.get_attachment_generation())
	var detached := binding.get_state_snapshot()
	_check(
		bool(detach_result.accepted) and not bool(detached.attached)
		and not bool((detached.voices.exterior as Dictionary).playing)
		and not bool((detached.voices.interior as Dictionary).playing)
		and not bool((detached.voices.exterior as Dictionary).stream_attached)
		and not bool((detached.voices.interior as Dictionary).stream_attached),
		"immediate caller detach stops and clears both voices"
	)
	var snapshot := binding.get_state_snapshot()
	_check(
		bool((binding.get_audit_report() as Dictionary).get("valid", false))
		and not bool((snapshot.authority as Dictionary).get("renderer", true))
		and bool((snapshot.authority as Dictionary).get("audio", false))
		and not bool((snapshot.adjacent_authority as Dictionary).get("audio_bus_level", true)),
		"binding is locally audio-authoritative without context or bus authority"
	)
	var source := FileAccess.get_file_as_string("res://scripts/audio/planetary_surface_audio_playback_binding.gd")
	_check(
		"AudioDirector" not in source and "AudioServer.set_bus" not in source
		and "set_process(false)" in source and "set_physics_process(false)" in source,
		"binding has no AudioDirector reuse, bus mutation, or autonomous process loop"
	)
	binding.queue_free()
	await process_frame


func _policy_result(context: StringName) -> Dictionary:
	var interior := context != &"exterior"
	var selected_id: StringName = (
		PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID if interior
		else PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID
	)
	return {
		"accepted": true,
		"reason": &"evaluated",
		"configured": true,
		"profile_id": &"temperate_game_scale",
		"evaluation": {
			"evaluation_schema_version": 1,
			"profile_id": &"temperate_game_scale",
			"policy_version": &"planetary_surface_audio_v1",
			"equation_version": &"density_max_airflow_hints_v1",
			"inputs": {"listener_context": context},
			"altitude": {},
			"routing": {
				"available_profile_ids": {
					"exterior": PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID,
					"interior": PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID,
				},
				"selected_route": &"interior" if interior else &"exterior",
				"selected_audio_profile_id": selected_id,
				"listener_context": context,
				"profile_id_resolved": false,
				"playback_requested": false,
				"cabin_aliases_interior": context == &"cabin",
			},
			"gain": {
				"authored_exterior_gain_db": -6.0,
				"authored_interior_attenuation_db": -18.0,
				"recommended_gain_db": -24.0 if interior else -6.0,
			},
			"mix": {
				"exterior_route_unitless": 0.0 if interior else 1.0,
				"interior_route_unitless": 1.0 if interior else 0.0,
				"instantaneous_endpoints_only": true,
			},
			"intensity": {"recommended_intensity_unitless": 0.8},
			"atmosphere_sample": {},
		},
	}


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("planetary_surface_audio_foundation_test: PASS (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("planetary_surface_audio_foundation_test: FAIL (%d/%d)" % [_failures.size(), _assertions])
	quit(1)
