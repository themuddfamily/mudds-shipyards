extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Layers := preload("res://scripts/core/physics_layers.gd")

const REENTRY_CYCLE_COUNT := 3

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for whole-tree lifecycle testing")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null("ShipyardWorld") as Node3D
	var audio := game.get_node_or_null("AudioDirector") as AudioDirector
	var authority := game.get_combat_authority() as LiveCombatAuthority
	var resolver := game.get_combat_resolver() as CombatResolver
	var pulse := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	var opponent := game.get_node_or_null("RangeOpponent") as Node3D
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(
		world != null
		and audio != null
		and authority != null
		and resolver != null
		and pulse != null
		and opponent != null
		and fleet.size() == 4,
		"production re-entry fixture exposes the world, audio, pulse, authority, resolver, opponent, and exact fleet"
	)
	if (
		world == null
		or audio == null
		or authority == null
		or resolver == null
		or pulse == null
		or opponent == null
		or fleet.size() != 4
	):
		await _clean_up(game)
		_finish()
		return

	await _test_safed_fire_contract(game, authority, pulse, opponent, fleet)
	await _test_whole_main_reentry(game, world, audio, authority, resolver, pulse, opponent, fleet)
	await _test_destroyed_source_impact_ordering(game, pulse, fleet)
	await _clean_up(game)
	_finish()


func _test_whole_main_reentry(
	game: GameFlow,
	world: Node3D,
	audio: AudioDirector,
	authority: LiveCombatAuthority,
	resolver: CombatResolver,
	pulse: PulseWeaponPresentation,
	opponent: Node3D,
	fleet: Array[HeroShip]
	) -> void:
	var world_owner := world as ShipyardWorld
	var opponent_ship := opponent as RangeOpponent
	var parent := game.get_parent()
	var torrent := _ship_by_id(fleet, &"torrent_provisional")
	var arrow := _ship_by_id(fleet, &"arrow_provisional")
	var jovian := _ship_by_id(fleet, &"jovian_provisional")
	var zenith := _ship_by_id(fleet, &"zenith_b7_observed")
	_check(
		torrent != null and arrow != null and jovian != null and zenith != null,
		"whole-tree fixture retains all four exact production ship identities"
	)
	if torrent == null or arrow == null or jovian == null or zenith == null:
		return
	_check(world_owner != null and opponent_ship != null, "re-entry opponent and world targets are correctly typed runtime components")
	if world_owner == null or opponent_ship == null:
		return

	# Capture one accepted, damaging request before any detach. The exact request
	# remains a valid RefCounted payload while the same Main subtree streams out
	# and back in; replay history must outlive the temporary registrations.
	var replay_target := StaticBody3D.new()
	replay_target.name = "ReentryReplayDamageTarget"
	replay_target.collision_layer = Layers.TARGET
	replay_target.collision_mask = 0
	var replay_shape_node := CollisionShape3D.new()
	var replay_shape := BoxShape3D.new()
	replay_shape.size = Vector3.ONE
	replay_shape_node.shape = replay_shape
	replay_target.add_child(replay_shape_node)
	var replay_damageable := Damageable.new()
	replay_damageable.maximum_health = 100.0
	replay_damageable.faction_id = &"reentry_replay_target"
	replay_target.add_child(replay_damageable)
	game.add_child(replay_target)
	var replay_origin := torrent.global_position + Vector3.UP * 0.25
	replay_target.global_position = replay_origin + Vector3.UP * 3.0
	await physics_frame
	var captured_requests: Array[ShotRequest] = []
	authority.authoritative_shot_submitted.connect(
		func(request: ShotRequest, _result: Dictionary) -> void:
			if request.source_entity == torrent and captured_requests.is_empty():
				captured_requests.append(request)
	)
	var initial_replay_result := authority.submit_hitscan(
		torrent,
		GameFlow.COMBAT_WEAPON_ID,
		replay_origin,
		Vector3.UP
	)
	var health_after_initial_shot := replay_damageable.get_health()
	_check(
		bool(initial_replay_result.get("accepted", false))
		and bool(initial_replay_result.get("damaged", false))
		and captured_requests.size() == 1
		and health_after_initial_shot < replay_damageable.maximum_health,
		"re-entry replay fixture captures one accepted damaging authority request"
	)

	var hero_receipt_id := 91001
	var opponent_receipt_id := 91002
	var world_receipt_id := 91003
	torrent.discard_deferred_damage_presentations()
	var hero_pending_before := torrent.get_pending_damage_presentation_count()
	var hero_health_before := float(torrent.get_telemetry().get("hull", 10000.0))
	torrent.apply_damage(
		6.5,
		torrent.global_position + Vector3(0.2, 0.3, 0.0),
		Vector3.ZERO,
		hero_receipt_id,
		true
	)
	_check(
		float(torrent.get_telemetry().get("hull")) < hero_health_before
		and int(torrent.get_pending_damage_presentation_count()) == hero_pending_before + 1,
		"re-entry fixture stores one deferred hero ship damage receipt"
	)
	opponent_ship.activate(opponent.global_transform)
	opponent_ship.discard_deferred_damage_presentations()
	var opponent_health_before := opponent_ship.get_health()
	var opponent_pending_before := opponent_ship.get_pending_damage_presentation_count()
	opponent_ship.apply_damage(
		4.0,
		opponent.global_position + Vector3(0.4, 0.2, -0.8),
		opponent_receipt_id,
		true
	)
	_check(
		opponent_ship.get_health() < opponent_health_before
		and int(opponent_ship.get_pending_damage_presentation_count()) == opponent_pending_before + 1,
		"re-entry fixture stores one deferred opponent damage receipt"
	)
	opponent_ship.deactivate()
	# Locate one live shipyard target for a deferred target-side presentation queue.
	var world_targets := world.find_children("*", "StaticBody3D", true, false)
	var reentry_world_target: StaticBody3D = null
	for candidate in world_targets:
		var target := candidate as StaticBody3D
		if target != null:
			reentry_world_target = target
			break
	var world_replay_hit := (
		reentry_world_target.global_position + Vector3.UP * 0.15
		if reentry_world_target != null
		else Vector3.ZERO
	)
	var world_defer_result := false
	if world_owner != null and reentry_world_target != null:
		world_defer_result = world_owner.defer_target_damage_presentation(
			world_receipt_id,
			reentry_world_target,
			StringName(reentry_world_target.get_meta("target_id", &"reentry_test")),
			world_replay_hit,
			false
		)
	_check(
		reentry_world_target != null and world_defer_result,
		"re-entry fixture stores one deferred world target damage receipt"
	)

	# Sentinels make an accidental replay of `_ready()` observable. In particular,
	# startup would replace Arrow with Torrent as the active craft and would reset
	# the target/HUD setup even though this is the same gameplay instance.
	game.phase = GameFlow.Phase.COMPLETE
	game.destroyed_targets = 7
	game.active_ship = arrow
	game.set("_guided_activity_complete", true)
	var expected_phase := game.phase
	var expected_destroyed_targets := game.destroyed_targets
	var expected_active_ship := game.active_ship
	var expected_world_built := bool(world.get("_built"))
	var fixed_tree_ids := _descendant_instance_ids(game)
	var fixed_audio_player_ids := _instance_ids_by_name(
		audio.find_children("*", "AudioStreamPlayer", true, false)
	)
	var fixed_audio_timer_ids := _instance_ids_by_name(
		audio.find_children("*", "Timer", true, false)
	)
	var initial_audio_generation := int(audio.get_synthesis_report().generation_count)

	for cycle in REENTRY_CYCLE_COUNT:
		var old_audio_resources := _weak_refs_for_resources(
			(audio.get("_stream_bank") as Dictionary).values()
		)
		var prior_resource_ids := (
			audio.get_synthesis_report().resource_instance_ids as Dictionary
		).duplicate(true)

		parent.remove_child(game)
		await process_frame
		var detached_audio := audio.get_synthesis_report()
		var opponent_replay_rejected := true
		var world_replay_rejected := true
		if opponent_ship != null:
			opponent_replay_rejected = not bool(opponent_ship.commit_deferred_damage_presentation(opponent_receipt_id))
		if world_owner != null:
			world_replay_rejected = not bool(world_owner.commit_deferred_damage_presentation(world_receipt_id))
		_check(
			not bool(torrent.commit_deferred_damage_presentation(hero_receipt_id))
			and opponent_replay_rejected
			and world_replay_rejected,
			"detach cycle %d cannot replay deferred hero/opponent/world receipts before rebuild" % (cycle + 1)
		)
		_check(
			game.get_pending_combat_presentation_receipt_count() == 0
			and int(torrent.get_pending_damage_presentation_count()) == 0
			and int(opponent_ship.get_pending_damage_presentation_count()) == 0
			and int(world_owner.get_pending_target_damage_presentation_count()) == 0,
			"detach cycle %d clears each deferred queue in owner components and coordinator metadata" % (cycle + 1)
		)
		_check(
			resolver.get_registered_source_count() == 0
			and authority.get_source_id(torrent) == 0
			and authority.get_source_id(arrow) == 0
			and authority.get_source_id(jovian) == 0
			and authority.get_source_id(zenith) == 0
			and authority.get_source_id(opponent) == 0,
			"detach cycle %d clears all five source registrations and resolver ownership" % (cycle + 1)
		)
		_check(
			not bool(detached_audio.resources_ready)
			and int(detached_audio.resident_stream_count) == 0
			and int(detached_audio.resident_sample_bytes) == 0
			and (detached_audio.resource_instance_ids as Dictionary).is_empty()
			and _audio_players_stopped_and_detached(audio)
			and _audio_timers_stopped(audio),
			"detach cycle %d releases AudioDirector resources and every backend handle" % (cycle + 1)
		)
		_check(
			_instance_ids_by_name(
				audio.find_children("*", "AudioStreamPlayer", true, false)
			) == fixed_audio_player_ids
			and _instance_ids_by_name(
				audio.find_children("*", "Timer", true, false)
			) == fixed_audio_timer_ids
			and bool(audio.get_audit_report().valid),
			"detach cycle %d preserves the exact fixed audio hierarchy and detached audit" % (cycle + 1)
		)
		var old_resources_released := true
		for reference in old_audio_resources:
			old_resources_released = old_resources_released and reference.get_ref() == null
		_check(old_resources_released, "detach cycle %d leaks no resident AudioDirector WAV" % (cycle + 1))

		var expected_torrent_health := float(torrent.get_telemetry().get("hull"))
		var expected_opponent_health := float(opponent_ship.get_health())
		parent.add_child(game)
		await process_frame
		await physics_frame
		await process_frame
		var restored_audio := audio.get_synthesis_report()
		var restored_resource_ids := restored_audio.resource_instance_ids as Dictionary
		var unique_resource_ids := {}
		for instance_id in restored_resource_ids.values():
			unique_resource_ids[int(instance_id)] = true
		_check(
			resolver.get_registered_source_count() == 5
			and int(authority.get("_registrations_by_instance").size()) == 5
			and authority.get_source_id(torrent) == 1101
			and authority.get_source_id(arrow) == 1102
			and authority.get_source_id(jovian) == 1103
			and authority.get_source_id(zenith) == 1104
			and authority.get_source_id(opponent) == GameFlow.OPPONENT_SOURCE_ID,
			"re-entry cycle %d restores the exact five combat authority/resolver sources" % (cycle + 1)
		)
		_check(
			bool(restored_audio.resources_ready)
			and int(restored_audio.resident_stream_count) == AudioDirector.RESIDENT_STREAM_IDS.size()
			and int(restored_audio.resident_sample_bytes) == AudioDirector.EXPECTED_RESIDENT_SAMPLE_BYTES
			and restored_resource_ids.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
			and unique_resource_ids.size() == AudioDirector.RESIDENT_STREAM_IDS.size()
			and restored_resource_ids != prior_resource_ids
			and int(restored_audio.generation_count) == initial_audio_generation + cycle + 1,
			"re-entry cycle %d restores exactly fifteen new resident resources in one generation" % (cycle + 1)
		)
		_check(
			_instance_ids_by_name(
				audio.find_children("*", "AudioStreamPlayer", true, false)
			) == fixed_audio_player_ids
			and _instance_ids_by_name(
				audio.find_children("*", "Timer", true, false)
			) == fixed_audio_timer_ids
			and int(audio.get_performance_report().audio_player_count) == 5
			and int(audio.get_performance_report().sequence_timer_count) == 3
			and bool(audio.get_audit_report().valid),
			"re-entry cycle %d retains exactly five audio players, three timers, and a green audit" % (cycle + 1)
		)
		_check(
			_descendant_instance_ids(game) == fixed_tree_ids
			and bool(world.get("_built")) == expected_world_built
			and game.phase == expected_phase
			and game.destroyed_targets == expected_destroyed_targets
			and game.active_ship == expected_active_ship
			and bool(game.get("_guided_activity_complete")),
			"re-entry cycle %d preserves every Main node identity and gameplay sentinel without replaying startup/world build" % (cycle + 1)
		)
		_check(
			is_equal_approx(float(torrent.get_telemetry().get("hull")), expected_torrent_health)
			and is_equal_approx(float(opponent_ship.get_health()), expected_opponent_health)
			and game.get_pending_combat_presentation_receipt_count() == 0
			and int(torrent.get_pending_damage_presentation_count()) == 0
			and int(opponent_ship.get_pending_damage_presentation_count()) == 0
			and int(world_owner.get_pending_target_damage_presentation_count()) == 0,
			"re-entry cycle %d preserves authority health and shows an empty deferred queue state" % (cycle + 1)
		)
		_check(
			_connection_count(
				authority,
				&"authoritative_shot_submitted",
				Callable(game, "_on_authoritative_shot_submitted")
			) == 1
			and _connection_count(
				pulse,
				&"impact_started",
				Callable(game, "_on_pulse_impact_started")
			) == 1,
			"re-entry cycle %d owns exactly one authority-to-pulse and pulse-to-audio connection" % (cycle + 1)
		)
		var health_before_replay := replay_damageable.get_health()
		var replay_result := resolver.resolve_hitscan(captured_requests[0])
		_check(
			not bool(replay_result.get("accepted", true))
			and replay_result.get("status", &"") in [
				&"duplicate_sequence",
				&"out_of_order_sequence",
			]
			and int(replay_result.get("last_sequence", -1)) >= captured_requests[0].sequence
			and is_equal_approx(replay_damageable.get_health(), health_before_replay),
			"re-entry cycle %d rejects the captured request without applying damage again" % (cycle + 1)
		)

		pulse.clear_effects()
		var presented_before := int(pulse.get_statistics().presented)
		var submission_sources: Array[Node3D] = [torrent, arrow, jovian, zenith, opponent]
		var submission_weapons: Array[StringName] = [
			GameFlow.COMBAT_WEAPON_ID,
			GameFlow.COMBAT_WEAPON_ID,
			GameFlow.COMBAT_WEAPON_ID,
			GameFlow.COMBAT_WEAPON_ID,
			GameFlow.OPPONENT_WEAPON_ID,
		]
		var every_submission_live := true
		for source_index in submission_sources.size():
			var source := submission_sources[source_index]
			var result := authority.submit_hitscan_with_deferred_presentation(
				source,
				submission_weapons[source_index],
				source.global_position + Vector3.UP * 0.25,
				Vector3.UP
			)
			every_submission_live = (
				every_submission_live
				and bool(result.get("accepted", false))
				and bool(result.get("resolved", false))
				and int(result.get("source_id", 0)) == authority.get_source_id(source)
			)
		_check(
			every_submission_live
			and int(pulse.get_statistics().presented) == presented_before + 5
			and pulse.get_active_effect_count() == 5,
			"re-entry cycle %d accepts live submissions from all five sources and presents each exactly once" % (cycle + 1)
		)


func _test_safed_fire_contract(
	game: GameFlow,
	authority: LiveCombatAuthority,
	pulse: PulseWeaponPresentation,
	opponent: Node3D,
	fleet: Array[HeroShip]
	) -> void:
	var blocker := _make_world_blocker(Vector3.ZERO, Vector3(1.0, 3.0, 1.0))
	game.add_child(blocker)
	await physics_frame
	var opponent_health_before := float(opponent.call("get_health"))
	var all_safed_truthful := true
	for firing_ship in fleet:
		game.active_ship = firing_ship
		game.phase = GameFlow.Phase.INTRO
		game.set("_guided_activity_complete", false)
		pulse.clear_effects()
		var origin := firing_ship.global_position + Vector3.UP * 0.5
		var direction := Vector3.FORWARD
		blocker.global_position = origin + direction * 2.0
		await physics_frame
		var sequence_before := authority.get_last_submitted_sequence(firing_ship)
		game.call("_on_projectile_fired", origin, direction, firing_ship)
		var result: Dictionary = game.get_last_player_shot_result()
		var shots := pulse.get_active_shot_snapshots()
		var snapshot: Dictionary = shots[0] if shots.size() == 1 else {}
		var expected_status: StringName = (
			&"weapons_safed"
			if firing_ship == game.get_guided_ship()
			else &"guided_range_reserved"
		)
		all_safed_truthful = (
			all_safed_truthful
			and not bool(result.get("accepted", true))
			and not bool(result.get("resolved", true))
			and not bool(result.get("hit", true))
			and not bool(result.get("damaged", true))
			and result.get("status", &"") == expected_status
			and authority.get_last_submitted_sequence(firing_ship) == sequence_before
			and shots.size() == 1
			and is_equal_approx(float(snapshot.get("distance", 0.0)), GameFlow.SAFED_PULSE_DISTANCE)
			and float(snapshot.get("distance", INF)) < origin.distance_to(blocker.global_position)
			and not bool(snapshot.get("hit", true))
		)
	_check(
		all_safed_truthful
		and is_equal_approx(float(opponent.call("get_health")), opponent_health_before),
		"all four craft report safed fire as unresolved and show only an exact 0.2 m muzzle pulse before world geometry"
	)
	game.active_ship = game.get_guided_ship()
	blocker.queue_free()
	await physics_frame


func _test_destroyed_source_impact_ordering(
	game: GameFlow,
	pulse: PulseWeaponPresentation,
	fleet: Array[HeroShip]
	) -> void:
	var source_ship := _ship_by_id(fleet, &"arrow_provisional")
	_check(source_ship != null, "destroyed-source delayed-impact fixture finds the Arrow craft")
	if source_ship == null:
		return
	var combat_audio := game.get_combat_audio_presentation()
	_check(combat_audio != null, "destroyed-source fixture finds the authored world-space combat bank")
	if combat_audio == null:
		return

	pulse.clear_effects()
	pulse.set_auto_advance_enabled(false)
	var impact_events: Array[int] = []
	pulse.impact_started.connect(
		func(_shot_id: int, _style: StringName, _source_id: int, _position: Vector3) -> void:
			impact_events.append(1)
	)
	var origin := source_ship.global_position + Vector3.UP
	_check(
		pulse.present_shot(origin, origin + Vector3.FORWARD * 20.0, &"cyan", source_ship, true),
		"hit presentation is in flight before its source is destroyed"
	)
	var source_health_before := float(source_ship.get_telemetry().get("hull", 1000.0))
	source_ship.apply_damage(
		float(source_ship.get_telemetry().get("maximum_hull", 100.0)) + 1.0,
		source_ship.global_position,
		Vector3.BACK
	)
	var source_health_after := float(source_ship.get_telemetry().get("hull", 0.0))
	var destruction_state := combat_audio.get_state_snapshot()
	var destruction_counts := destruction_state.get("cue_counts", {}) as Dictionary
	var destruction_count := int(destruction_counts.get(CombatAudioPresentation.CUE_EXPLOSION, 0))
	var impact_count := int(destruction_counts.get(CombatAudioPresentation.CUE_IMPACT_MEDIUM, 0))
	_check(
		source_ship.is_destroyed()
		and source_health_after < source_health_before
		and is_equal_approx(source_health_after, 0.0)
		and destruction_count > 0
		and destruction_state.get("last_world_position") == source_ship.global_position,
		"lethal damage starts exactly one authored explosion at the immutable ship position"
	)
	pulse.advance_simulation(0.30)
	var after_impact := combat_audio.get_state_snapshot()
	var after_counts := after_impact.get("cue_counts", {}) as Dictionary
	_check(
		impact_events.size() == 1
		and int(after_counts.get(CombatAudioPresentation.CUE_EXPLOSION, 0)) == destruction_count
		and int(after_counts.get(CombatAudioPresentation.CUE_IMPACT_MEDIUM, 0)) == impact_count + 1,
		"a delayed endpoint impact overlaps rather than replacing the independent explosion pool"
	)


func _make_world_blocker(world_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SafedFireWorldBlocker"
	body.position = world_position
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _ship_by_id(fleet: Array[HeroShip], ship_id: StringName) -> HeroShip:
	for candidate in fleet:
		if candidate.get_ship_id() == ship_id:
			return candidate
	return null


func _connection_count(source: Object, signal_name: StringName, callback: Callable) -> int:
	var count := 0
	for connection: Dictionary in source.get_signal_connection_list(signal_name):
		if connection.get("callable", Callable()) == callback:
			count += 1
	return count


func _descendant_instance_ids(search_root: Node) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for node in search_root.find_children("*", "", true, false):
		# Skeleton3D creates this deprecated compatibility helper as an internal
		# child on every NOTIFICATION_ENTER_TREE. Godot deliberately queues the
		# previous helper for deletion and allocates a replacement, so it is engine
		# lifecycle state rather than authored Main hierarchy identity.
		if _is_pilot_compat_physical_bone_simulator(node):
			continue
		ids.append(node.get_instance_id())
	ids.sort()
	return ids


func _is_pilot_compat_physical_bone_simulator(node: Node) -> bool:
	if not node is PhysicalBoneSimulator3D:
		return false
	var skeleton := node.get_parent() as Skeleton3D
	if skeleton == null or skeleton.name != &"PilotSkeleton":
		return false
	var runtime_name := String(node.name)
	const GENERATED_PREFIX := "@PhysicalBoneSimulator3D@"
	if not runtime_name.begins_with(GENERATED_PREFIX):
		return false
	if not runtime_name.trim_prefix(GENERATED_PREFIX).is_valid_int():
		return false
	# Godot adds the compatibility simulator with INTERNAL_MODE_BACK. Avoid a
	# class-only exception: an authored/non-internal simulator remains identity
	# significant and will still fail the whole-tree invariant.
	if not skeleton.get_children(true).has(node) or skeleton.get_children(false).has(node):
		return false
	var rig := skeleton.get_parent()
	var art := rig.get_parent() if rig != null else null
	var import_root := art.get_parent() if art != null else null
	var presentation := import_root.get_parent() if import_root != null else null
	return (
		rig != null
		and rig.name == &"PilotRig"
		and art != null
		and art.name == &"PilotArt"
		and import_root != null
		and import_root.name == &"PilotMotionImport"
		and presentation is PilotSkinnedPresentation
	)


func _instance_ids_by_name(nodes: Array[Node]) -> Dictionary:
	var result := {}
	for node in nodes:
		result[StringName(node.name)] = node.get_instance_id()
	return result


func _weak_refs_for_resources(resources: Array) -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for resource in resources:
		references.append(weakref(resource))
	return references


func _audio_players_stopped_and_detached(audio: AudioDirector) -> bool:
	var players := audio.find_children("*", "AudioStreamPlayer", true, false)
	if players.size() != 1 + AudioDirector.EFFECT_VOICE_COUNT:
		return false
	for candidate in players:
		var player := candidate as AudioStreamPlayer
		if player.playing or player.stream != null:
			return false
	return true


func _audio_timers_stopped(audio: AudioDirector) -> bool:
	var timers := audio.find_children("*", "Timer", true, false)
	if timers.size() != AudioDirector.SEQUENCE_TIMER_COUNT:
		return false
	for candidate in timers:
		if not (candidate as Timer).is_stopped():
			return false
	return true


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
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
		print("MAIN_REENTRY_QUALITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("MAIN_REENTRY_QUALITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
