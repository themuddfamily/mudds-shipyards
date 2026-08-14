extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := PackedStringArray()
var _assertions := 0


class FakeInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_pressed(action: StringName, value: bool) -> void:
		pressed[action] = value
		strengths[action] = 1.0 if value else 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates as GameFlow")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var fleet: Array[HeroShip] = game.get_flyable_ships()
	var pulse := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	var pulse_instances := _find_pulse_presentations(game)
	var grouped_pools := get_nodes_in_group(&"pulse_weapon_presentation")
	_check(fleet.size() == 3, "quality integration owns the exact three-craft production fleet")
	_check(
		pulse != null
		and pulse.get_parent() == game
		and pulse_instances.size() == 1
		and pulse_instances[0] == pulse
		and grouped_pools.size() == 1
		and grouped_pools[0] == pulse,
		"production owns exactly one global PulseWeaponPresentation pool"
	)
	_check(
		pulse != null and bool(pulse.get_audit_report().get("valid", false)),
		"the global bounded pulse pool passes its public audit"
	)
	_check(
		game.find_children("PulseTracer", "", true, false).is_empty(),
		"production scene contains no legacy PulseTracer node"
	)

	var expected_profiles := {
		&"torrent_provisional": &"standard_fighter",
		&"arrow_provisional": &"efficient_twin_recon",
		&"jovian_provisional": &"heavy_quad_freighter",
	}
	var observed_profiles := {}
	var fleet_by_id := {}
	var fleet_rigs: Array[ShipAudioRig] = []
	for ship in fleet:
		var ship_id := ship.get_ship_id()
		var rig := ship.get_ship_audio_rig()
		var definition := ship.get_ship_definition()
		fleet_by_id[ship_id] = ship
		_check(
			rig != null
			and rig.get_parent() == ship
			and ship.get_node_or_null("ShipAudioRig") == rig,
			"%s owns its direct ship-local ShipAudioRig" % ship.name
		)
		if rig == null:
			continue
		fleet_rigs.append(rig)
		observed_profiles[ship_id] = rig.get_profile_id()
		_check(
			definition != null
			and rig.get_profile_id() == definition.audio_profile_id
			and rig.get_profile_id() == expected_profiles.get(ship_id, &""),
			"%s consumes its exact ShipDefinition audio profile" % ship.name
		)
		_check(
			bool(rig.get_audit_report().get("valid", false)),
			"%s ship-local audio passes its public deep audit" % ship.name
		)

	var discovered_rigs := _find_ship_audio_rigs(game)
	var grouped_rigs := get_nodes_in_group(&"ship_audio_rig")
	_check(
		discovered_rigs.size() == 3
		and grouped_rigs.size() == 3
		and fleet_rigs.size() == 3
		and _same_instances(discovered_rigs, fleet_rigs)
		and _same_instances(grouped_rigs, fleet_rigs),
		"production exposes exactly the three per-ship ShipAudioRig instances"
	)
	_check(
		observed_profiles == expected_profiles and fleet_by_id.size() == expected_profiles.size(),
		"fleet IDs map one-to-one onto the three required audio profiles"
	)

	var torrent := fleet_by_id.get(&"torrent_provisional") as HeroShip
	var torrent_rig := torrent.get_ship_audio_rig() if torrent != null else null
	var combat_audio := game.get_combat_audio_presentation()
	_check(
		torrent != null and torrent_rig != null and combat_audio != null,
		"Torrent operational and authored-combat audio fixtures are available"
	)
	if torrent == null or torrent_rig == null or combat_audio == null:
		await _clean_up(game)
		_finish()
		return

	var cue_events: Array[Dictionary] = []
	torrent_rig.cue_requested.connect(
		func(cue_id: StringName, intensity: float, playback_queued: bool) -> void:
			cue_events.append({
				"cue_id": cue_id,
				"intensity": intensity,
				"playback_queued": playback_queued,
			})
	)
	var startup_state_before := torrent_rig.get_state_snapshot()
	var startup_event_count_before := cue_events.size()
	torrent.engine_start_time = 0.01
	torrent.request_engine_start()
	await physics_frame
	await physics_frame
	var startup_state := torrent_rig.get_state_snapshot()
	var startup_event: Dictionary = cue_events.back() if not cue_events.is_empty() else {}
	_check(torrent_rig.is_engine_running(), "engine ONLINE state activates the same ship-local rig")
	_check(
		int(startup_state.get("cue_request_count", -1))
			== int(startup_state_before.get("cue_request_count", 0)) + 1
		and startup_state.get("last_cue_id", &"") == ShipAudioRig.CUE_STARTUP,
		"engine startup requests exactly one local startup cue"
	)
	_check(
		cue_events.size() == startup_event_count_before + 1
		and startup_event.get("cue_id", &"") == ShipAudioRig.CUE_STARTUP
		and bool(startup_event.get("playback_queued", true))
			== bool(startup_state.get("playback_queue_allowed", false)),
		"startup cue reports its real-backend or Dummy queue outcome without losing the request"
	)

	var source := torrent.get_command_source() as LocalShipInputSource
	_check(source != null, "Torrent exposes its production local command adapter")
	if source == null:
		await _clean_up(game)
		_finish()
		return
	var provider := FakeInputProvider.new()
	torrent.set_piloted(true)
	source.set_input_provider(provider)
	provider.set_pressed(source.throttle_forward_action, true)
	provider.set_pressed(source.boost_action, true)
	await physics_frame
	await physics_frame
	await physics_frame
	var boost_state := torrent_rig.get_state_snapshot()
	var desired_layers := boost_state.get("desired_loop_layers", PackedStringArray()) as PackedStringArray
	_check(
		bool(torrent.get_last_ship_command().boost)
		and float(boost_state.get("throttle", 0.0)) > 0.0
		and bool(boost_state.get("boost_requested", false))
		and bool(boost_state.get("boost_active", false))
		and desired_layers.has("thrust_boost"),
		"injected production commands drive the boost layer independently of raw Input"
	)
	if not bool(boost_state.get("playback_queue_allowed", false)):
		_check(
			(boost_state.get("queued_voice_ids", PackedStringArray()) as PackedStringArray).is_empty(),
			"Dummy or unavailable audio keeps boost desired while claiming no queued voices"
		)
	else:
		_check(
			(boost_state.get("queued_voice_ids", PackedStringArray()) as PackedStringArray).has("boost_voice"),
			"queue-capable audio routes the requested boost layer through its fixed voice"
		)

	var fire_state_before := combat_audio.get_state_snapshot()
	provider.set_pressed(source.fire_action, true)
	await physics_frame
	await physics_frame
	provider.set_pressed(source.fire_action, false)
	var fire_state := combat_audio.get_state_snapshot()
	var fire_counts_before := fire_state_before.get("cue_counts", {}) as Dictionary
	var fire_counts := fire_state.get("cue_counts", {}) as Dictionary
	_check(
		int(fire_counts.get(CombatAudioPresentation.CUE_DRY_FIRE, 0))
			== int(fire_counts_before.get(CombatAudioPresentation.CUE_DRY_FIRE, 0)) + 1
		and int(fire_counts.get(CombatAudioPresentation.CUE_PLAYER_FIRE, 0))
			== int(fire_counts_before.get(CombatAudioPresentation.CUE_PLAYER_FIRE, 0))
		and fire_state.get("last_cue_id", &"") == CombatAudioPresentation.CUE_DRY_FIRE,
		"one locally safed weapon action requests one restrained dry cue and no accepted fire cue"
	)
	_check(
		fire_state.get("last_world_position") is Vector3
		and (fire_state.get("last_world_position") as Vector3).is_finite()
		and int(fire_state.get("last_source_instance_id", 0)) == torrent.get_instance_id(),
		"safed cue remains observable at its finite muzzle origin under Dummy audio"
	)

	var combat := game.get_node_or_null("CombatAuthority") as LiveCombatAuthority
	_check(combat != null and pulse != null, "production combat and pulse presentation endpoints are available")
	if combat != null and pulse != null:
		torrent.set_piloted(false)
		torrent.global_transform = Transform3D(Basis.IDENTITY, Vector3(180.0, 54.0, -230.0))
		pulse.clear_effects()
		var presented_events: Array[Dictionary] = []
		pulse.shot_presented.connect(
			func(shot_id: int, style_id: StringName, source_instance_id: int, hit: bool) -> void:
				presented_events.append({
					"shot_id": shot_id,
					"style_id": style_id,
					"source_instance_id": source_instance_id,
					"hit": hit,
				})
		)
		var statistics_before := pulse.get_statistics()
		var authored_fire_before := combat_audio.get_state_snapshot()
		var shot_origin := torrent.global_position + Vector3(0.0, 0.8, -5.5)
		var result := combat.submit_hitscan(
			torrent,
			&"combat_pulse_cannon",
			shot_origin,
			Vector3.FORWARD
		)
		var statistics_after := pulse.get_statistics()
		var authored_fire_after := combat_audio.get_state_snapshot()
		var authored_counts_before := authored_fire_before.get("cue_counts", {}) as Dictionary
		var authored_counts_after := authored_fire_after.get("cue_counts", {}) as Dictionary
		var presented_event: Dictionary = presented_events[0] if presented_events.size() == 1 else {}
		_check(
			bool(result.get("accepted", false)) and bool(result.get("resolved", false)),
			"public combat authority accepts and resolves the production shot"
		)
		_check(
			int(statistics_after.get("presented", -1))
				== int(statistics_before.get("presented", 0)) + 1
			and int(statistics_after.get("active", -1)) == 1,
			"accepted authoritative combat shot enters the one global pool"
		)
		_check(
			int(authored_counts_after.get(CombatAudioPresentation.CUE_PLAYER_FIRE, 0))
				== int(authored_counts_before.get(CombatAudioPresentation.CUE_PLAYER_FIRE, 0)) + 1
			and authored_fire_after.get("last_world_position") == shot_origin,
			"accepted authoritative combat shot requests one authored positional fire cue"
		)
		_check(
			presented_events.size() == 1
			and int(presented_event.get("shot_id", 0)) > 0
			and presented_event.get("style_id", &"") == &"cyan"
			and int(presented_event.get("source_instance_id", 0)) == torrent.get_instance_id()
			and bool(presented_event.get("hit", false)) == bool(result.get("hit", false)),
			"pool signal preserves the accepted shot's public style, source, and hit semantics"
		)
		_check(
			game.find_children("PulseTracer", "", true, false).is_empty(),
			"live accepted shot allocates no legacy PulseTracer node"
		)
		_check(
			bool(pulse.get_audit_report().get("valid", false)),
			"global pulse pool remains valid after live combat presentation"
		)

	await _clean_up(game)
	_finish()


func _find_pulse_presentations(search_root: Node) -> Array[PulseWeaponPresentation]:
	var result: Array[PulseWeaponPresentation] = []
	for candidate in search_root.find_children("*", "", true, false):
		if candidate is PulseWeaponPresentation:
			result.append(candidate as PulseWeaponPresentation)
	return result


func _find_ship_audio_rigs(search_root: Node) -> Array[ShipAudioRig]:
	var result: Array[ShipAudioRig] = []
	for candidate in search_root.find_children("*", "", true, false):
		if candidate is ShipAudioRig:
			result.append(candidate as ShipAudioRig)
	return result


func _same_instances(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for instance in first:
		if not second.has(instance):
			return false
	return true


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		await _release_combat_audio(game)
		game.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _release_combat_audio(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	var maximum_active_stream_seconds := 0.0
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing and player.stream != null:
			maximum_active_stream_seconds = maxf(
				maximum_active_stream_seconds,
				player.stream.get_length()
			)
	if maximum_active_stream_seconds > 0.0:
		await create_timer(maximum_active_stream_seconds + 0.05).timeout
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		player.stop()
		player.stream_paused = false
		player.stream = null
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_QUALITY_INTEGRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("HERO_QUALITY_INTEGRATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
