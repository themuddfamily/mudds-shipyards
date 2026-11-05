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
	await _await_settled_roster(game)

	var world := game.get_node_or_null("ShipyardWorld") as Node3D
	var audio := game.get_node_or_null("AudioDirector") as AudioDirector
	var authority := game.get_combat_authority() as LiveCombatAuthority
	var resolver := game.get_combat_resolver() as CombatResolver
	var pulse := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	var opponent := game.get_node_or_null("RangeOpponent") as Node3D
	# Expansion binding completion is intentionally asynchronous. This lifecycle
	# suite owns the retained direct Main subtree, so select that exact roster by
	# public ship identity instead of depending on which deferred frame settled.
	var fleet: Array[HeroShip] = _direct_combat_fleet(game.get_flyable_ships())
	_check(
		world != null
		and audio != null
		and authority != null
		and resolver != null
		and pulse != null
		and opponent != null
		and fleet.size() == 6,
		"production re-entry fixture exposes the world, audio, pulse, authority, resolver, opponent, and exact fleet"
	)
	if (
		world == null
		or audio == null
		or authority == null
		or resolver == null
		or pulse == null
		or opponent == null
		or fleet.size() != 6
	):
		await _clean_up(game)
		_finish()
		return

	await _test_pre_guide_freeplay_fire_contract(game, authority, pulse, opponent, fleet)
	await _test_whole_main_reentry(game, world, audio, authority, resolver, pulse, opponent, fleet)
	if not _failures.is_empty():
		await _clean_up(game)
		_finish()
		return
	await _test_destroyed_source_impact_ordering(game, pulse, fleet)
	await _clean_up(game)
	await _test_queued_main_reentry_restore()
	await _test_world_deferred_damage_receipt_currentness()
	_finish()


# The outer coroutine owns pause restoration even when setup or a comparison
# returns early. The original replay/resource fixture remains the inner case.
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
	var prior_pause: bool = paused
	var component_cut: Dictionary = {}
	await _test_whole_main_reentry_paused(game, world, audio, authority, resolver,
		pulse, opponent, fleet, component_cut)
	paused = prior_pause
	if not prior_pause and _failures.is_empty() and bool(component_cut.get("ready", false)):
		await _observe_normal_component_repair(component_cut)


func _test_whole_main_reentry_paused(
	game: GameFlow,
	world: Node3D,
	audio: AudioDirector,
	authority: LiveCombatAuthority,
	resolver: CombatResolver,
	pulse: PulseWeaponPresentation,
	opponent: Node3D,
	fleet: Array[HeroShip],
	component_cut: Dictionary
	) -> void:
	var world_owner := world as ShipyardWorld
	var opponent_ship := opponent as RangeOpponent
	var parent := game.get_parent()
	var torrent := _ship_by_id(fleet, &"torrent_provisional")
	var arrow := _ship_by_id(fleet, &"arrow_provisional")
	var jovian := _ship_by_id(fleet, &"jovian_provisional")
	var zenith := _ship_by_id(fleet, &"zenith_b7_observed")
	var halyard := _ship_by_id(fleet, &"halyard_new_design")
	var bulwark := _ship_by_id(fleet, &"bulwark_heavy_gunship")
	_check(
		torrent != null and arrow != null and jovian != null and zenith != null \
		and halyard != null and bulwark != null,
		"whole-tree fixture retains all six exact production ship identities"
	)
	if torrent == null or arrow == null or jovian == null or zenith == null \
			or halyard == null or bulwark == null:
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
		GameFlow.TORRENT_COMBAT_WEAPON_ID,
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
	var damageable_events: Array[StringName] = []
	replay_damageable.damage_applied.connect(
		func(_amount: float, _current: float, _maximum: float, _position: Vector3, _normal: Vector3, _context: Dictionary) -> void:
			damageable_events.append(&"damage")
	)
	replay_damageable.reset.connect(func(_current: float, _maximum: float) -> void: damageable_events.append(&"reset"))
	var replay_parent := replay_target.get_parent()
	var detached_health := replay_damageable.get_health()
	var detached_context := replay_damageable.get_last_hit_context()
	if replay_parent != null:
		replay_parent.remove_child(replay_target)
	var detached_damage := replay_damageable.apply_damage(10.0)
	replay_damageable.reset_health(140.0)
	_check(
		not replay_damageable.is_inside_tree()
			and not bool(detached_damage.get("accepted", true))
			and detached_damage.get("reason", &"") == &"damageable_unavailable"
			and is_equal_approx(replay_damageable.get_health(), detached_health)
			and replay_damageable.get_last_hit_context() == detached_context
			and damageable_events.is_empty(),
		"a detached Main-owned Damageable rejects direct health and reset mutation atomically"
	)
	if replay_parent != null:
		replay_parent.add_child(replay_target)
	await physics_frame
	replay_damageable.reset_health(140.0)
	var live_damage := replay_damageable.apply_damage(10.0)
	_check(
		replay_damageable.is_inside_tree()
			and bool(live_damage.get("accepted", false))
			and is_equal_approx(replay_damageable.get_health(), 130.0),
		"a re-entered Main-owned Damageable accepts fresh reset and direct damage"
	)

	# This is a declared staged source cut, not combat or ordinary access proof.
	# Keep the original six-direct combat roster; census the complete live fleet
	# independently, after the accepted replay target/request setup above.
	var all_craft: Array[HeroShip] = game.get_flyable_ships()
	var roster: Dictionary = game.get_live_combat_source_roster_audit()
	var census_valid: bool = all_craft.size() == 9 and bool(roster.get("valid", false)) \
		and int(roster.get("actual_source_count", 0)) == 13
	_check(census_valid, "component cut uses the settled nine-craft/thirteen-source composition")
	if not census_valid:
		return
	paused = true
	var lod_hauler := _ship_by_id(all_craft, &"cinder_cargo_hauler") as CinderCargoHauler
	var lod_bomber := _ship_by_id(all_craft, &"cinder_long_range_bomber") as CinderLongRangeBomber
	_check(lod_bomber != null, "Bomber LOD cut resolves the exact production craft")
	_check(lod_hauler != null, "Hauler LOD cut resolves the exact production craft")
	if lod_hauler == null or lod_bomber == null:
		return
	_test_craft_lod_epoch(lod_hauler, "healthy settled initial epoch", game, world_owner, authority)
	_test_craft_lod_epoch(lod_bomber, "healthy settled initial epoch", game, world_owner, authority)
	if not _prepare_component_cut(game, world_owner, authority, all_craft, component_cut):
		return

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
	# Torrent's original deferred 6.5 damage and every original queue are now
	# staged. The baseline is measured here, never assumed to be 0.9H.
	for entry: Dictionary in component_cut["entries"]:
		entry["baseline"] = _component_cut_snapshot(entry)
		print("MAIN_COMPONENT_BASELINE: ", entry["ship_id"], " ", entry["baseline"])
	component_cut["ready"] = true

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
		if not _compare_component_cut(game, component_cut, authority, cycle, false):
			return

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
			and authority.get_source_id(halyard) == 0
			and authority.get_source_id(bulwark) == 0
			and authority.get_source_id(opponent) == 0,
			"detach cycle %d clears all seven source registrations and resolver ownership" % (cycle + 1)
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
		await _await_settled_roster(game)
		if not _compare_component_cut(game, component_cut, authority, cycle, true):
			return
		_test_craft_lod_epoch(lod_hauler, "retained Main epoch %d" % (cycle + 1), game, world_owner, authority)
		_test_craft_lod_epoch(lod_bomber, "retained Main epoch %d" % (cycle + 1), game, world_owner, authority)

		var restored_audio := audio.get_synthesis_report()
		var restored_resource_ids := restored_audio.resource_instance_ids as Dictionary
		var unique_resource_ids := {}
		for instance_id in restored_resource_ids.values():
			unique_resource_ids[int(instance_id)] = true
		_check(
			resolver.get_registered_source_count() == 13
			and int(authority.get("_registrations_by_instance").size()) == 13
			and authority.get_source_id(torrent) == 1101
			and authority.get_source_id(arrow) == 1102
			and authority.get_source_id(jovian) == 1103
			and authority.get_source_id(zenith) == 1104
			and authority.get_source_id(halyard) == 1105
			and authority.get_source_id(bulwark) == 1107
			and authority.get_source_id(opponent) == GameFlow.OPPONENT_SOURCE_ID
			and bool(game.get_live_combat_source_roster_audit().get("valid", false)),
			"re-entry cycle %d restores the settled exact thirteen-source production roster" % (cycle + 1)
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
		var submission_sources: Array[Node3D] = [torrent, arrow, jovian, zenith, halyard, bulwark, opponent]
		var submission_weapons: Array[StringName] = [
			GameFlow.TORRENT_COMBAT_WEAPON_ID,
			GameFlow.ARROW_COMBAT_WEAPON_ID,
			GameFlow.JOVIAN_COMBAT_WEAPON_ID,
			GameFlow.ZENITH_COMBAT_WEAPON_ID,
			GameFlow.HALYARD_COMBAT_WEAPON_ID,
			GameFlow.BULWARK_COMBAT_WEAPON_ID,
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
			and int(pulse.get_statistics().presented) == presented_before + 7
			and pulse.get_active_effect_count() == 6,
			"re-entry cycle %d presents all seven live submissions once while Bulwark's adjacent deck impact terminates synchronously" % (cycle + 1)
		)
	var queued_health := replay_damageable.get_health()
	var queued_context := replay_damageable.get_last_hit_context()
	var queued_events := damageable_events.size()
	replay_damageable.queue_free()
	var queued_damage := replay_damageable.apply_damage(10.0)
	replay_damageable.reset_health(180.0)
	_check(
		replay_damageable.is_inside_tree()
			and replay_damageable.is_queued_for_deletion()
			and not bool(queued_damage.get("accepted", true))
			and queued_damage.get("reason", &"") == &"damageable_unavailable"
			and is_equal_approx(replay_damageable.get_health(), queued_health)
			and replay_damageable.get_last_hit_context() == queued_context
			and damageable_events.size() == queued_events,
		"a queued Main-owned Damageable rejects direct health and reset mutation atomically"
	)


# All references come from the settled composition. Snapshot helpers only read
# existing objects; in particular they never ensure a role or component owner.
func _prepare_component_cut(
	game: GameFlow, world: ShipyardWorld, authority: LiveCombatAuthority,
	craft: Array[HeroShip], cut: Dictionary
	) -> bool:
	var entries: Array[Dictionary] = []
	var identities: Dictionary = {}
	cut["player"] = game.player
	cut["entries"] = entries
	if not _component_player_is_unclaimed(game):
		_check(false, "component cut starts on foot without transition or role claim")
		return false
	for ship: HeroShip in craft:
		var model: ShipComponentDamage = ship.get_component_damage()
		var home: ShipBerth = world.get_berth_node(ship.get_home_berth_id())
		var area: ShipBoardingArea = ship.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
		var role: CrewSeatRoleAuthority = null
		if ship.has_method(&"get_crew_role_authority"):
			role = ship.call(&"get_crew_role_authority") as CrewSeatRoleAuthority
		var entry: Dictionary = {"ship": ship, "ship_id": ship.get_ship_id(),
			"model": model, "home": home, "area": area, "role": role,
			"source_id": authority.get_source_id(ship), "player": game.player, "game": game}
		var valid: bool = model != null and model.is_configured() and home != null \
			and area != null and ship.ship_definition != null \
			and ship.get("_pilot_seat_anchor") != null and ship.get_rid().is_valid() \
			and not ship.find_children("*", "CollisionShape3D", true, false).is_empty() \
			and not identities.has(ship.get_ship_id()) \
			and int(entry["source_id"]) > 0 \
			and _connection_count(model, &"component_state_changed", Callable(ship, "_on_component_state_changed")) == 1 \
			and _connection_count(model, &"component_repair_committed", Callable(ship, "_on_component_repair_committed")) == 1
		_check(valid, "component cut resolves unique existing model/home/boarding/source: %s" % ship.get_ship_id())
		if not valid:
			return false
		identities[ship.get_ship_id()] = true
		entries.append(entry)
		if not _capture_null_role_discovery(entry):
			return false
		if not _component_entry_is_quiescent(entry):
			_check(false, "component cut has healthy settled unclaimed own-home craft: %s" % ship.get_ship_id())
			return false
		var hit: Vector3 = Vector3.INF
		for component: Dictionary in model.get_component_states():
			if StringName(component["id"]) == &"port_wing":
				hit = ship.to_global(component["local_position"] as Vector3)
		var hull_before: float = float(ship.get("_hull"))
		_check(hit.is_finite() and is_equal_approx(hull_before, ship.maximum_hull),
			"component cut begins healthy with actual port-wing anchor: %s" % ship.get_ship_id())
		if not hit.is_finite() or not is_equal_approx(hull_before, ship.maximum_hull):
			return false
		ship.apply_damage(ship.maximum_hull * 0.1, hit, Vector3.ZERO)
		var hit_accepted: bool = is_equal_approx(float(ship.get("_hull")), hull_before - ship.maximum_hull * 0.1) \
			and model.get_component_integrity(&"port_wing") < 1.0
		_check(hit_accepted, "located staged .1H hit reaches actual hull and port ledger: %s" % ship.get_ship_id())
		if not hit_accepted:
			return false
	return true


func _component_player_is_unclaimed(game: GameFlow) -> bool:
	if not is_instance_valid(game.player):
		return false
	var solo_authority: CrewSeatRoleAuthority = game.get("_solo_crew_authority") as CrewSeatRoleAuthority
	return (solo_authority == null or (solo_authority.get_snapshot().get("assignments", []) as Array).is_empty()) \
		and game.player.get("_seat_anchor") == null and not bool(game.player.call(&"is_seated")) \
		and not bool(game.player.call(&"is_station_seated")) \
		and not bool(game.get("_piloting")) and not bool(game.get("_station_seated")) \
		and not bool(game.get("_transition_busy")) \
		and not bool(game.get("_ground_transition_active")) \
		and not bool(game.get("_landing_request_active")) \
		and StringName(game.get("_active_activity_id")).is_empty() \
		and game.get("network_session") == null \
		and StringName(game.get("_solo_crew_role")).is_empty() \
		and game.get("_solo_crew_ship") == null and game.get("_solo_crew_seat") == null


func _component_entry_is_quiescent(entry: Dictionary) -> bool:
	var ship: HeroShip = entry["ship"] as HeroShip
	var home: ShipBerth = entry["home"] as ShipBerth
	var area: ShipBoardingArea = entry["area"] as ShipBoardingArea
	var role: CrewSeatRoleAuthority = entry["role"] as CrewSeatRoleAuthority
	var player: Node = entry["player"] as Node
	var game: GameFlow = entry["game"] as GameFlow
	if not is_instance_valid(ship) or not is_instance_valid(home) \
			or not is_instance_valid(area) or not is_instance_valid(player):
		return false
	var at_home: bool = not ship.is_inside_tree() or ship.global_transform.is_equal_approx(home.get_dock_transform())
	return at_home and not player.has_meta(ship.get_solo_crew_occupant_metadata_key()) \
		and StringName(ship.get("_planetary_cruise_state")) == HeroShip.PLANETARY_CRUISE_STATE_INACTIVE \
		and bool(ship.get("_landed")) and not ship.is_destroyed() \
		and not ship.is_landing_active() and not ship.is_piloted() \
		and not ship.is_remote_piloted() and ship.velocity.is_zero_approx() \
		and not area.is_reserved() and area.get_reservation_token() == null \
		and (role == null or (role.get_snapshot().get("assignments", []) as Array).is_empty()) \
		and home.get_occupant() == ship and home.get_reservation_owner() == ship \
		and home.get_reserved_ship_id() == ship.get_ship_id() \
		and not home.get_reservation_token(ship).is_empty() \
		and (game.get("_berth_tokens") as Dictionary).get(ship.get_instance_id(), &"") == home.get_reservation_token(ship) \
		and (game.get("_reserved_berth_ids") as Dictionary).get(ship.get_instance_id(), &"") == ship.get_home_berth_id()


func _component_cut_snapshot(entry: Dictionary) -> Dictionary:
	var ship: HeroShip = entry["ship"] as HeroShip
	if not is_instance_valid(ship):
		return {"ship": 0}
	var model: ShipComponentDamage = ship.get_component_damage()
	var home: ShipBerth = entry["home"] as ShipBerth
	var area: ShipBoardingArea = entry["area"] as ShipBoardingArea
	if not is_instance_valid(model) or not is_instance_valid(home) or not is_instance_valid(area):
		return {"ship": ship.get_instance_id(), "model": _retained_id(model),
			"home": _retained_id(home), "boarding": _retained_id(area)}
	var shapes: Array[Dictionary] = []
	for node: Node in ship.find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		var owner: CollisionObject3D = shape.get_parent() as CollisionObject3D
		shapes.append({"node": shape.get_instance_id(), "resource": _retained_id(shape.shape),
			"transform": shape.transform, "disabled": shape.disabled,
			"owner": _retained_id(owner), "layers": owner.collision_layer if owner != null else 0,
			"mask": owner.collision_mask if owner != null else 0})
	var actual_role: CrewSeatRoleAuthority = null
	if ship.has_method(&"get_crew_role_authority"):
		actual_role = ship.call(&"get_crew_role_authority") as CrewSeatRoleAuthority
	return {"ship": ship.get_instance_id(), "transform": ship.transform,
		"definition": _retained_id(ship.ship_definition),
		"body_rid": ship.get_rid(), "model": _retained_id(model),
		"hull": float(ship.get("_hull")), "ledger": model.get_ledger_snapshot(),
		"revision": model.get_revision(), "generation": model.get_ledger_generation(),
		"states": model.get_component_states(), "elapsed": float(ship.get("_elapsed")),
		"shapes": shapes, "seat": _retained_id(ship.get("_pilot_seat_anchor") as Object),
		"boarding": area.get_instance_id(), "boarding_transform": area.transform,
		"boarding_reserved": area.is_reserved(), "boarding_token": area.get_reservation_token(),
		"role": _retained_id(actual_role),
		"assignments": actual_role.get_snapshot().get("assignments", []) if actual_role != null else [],
		"piloted": ship.is_piloted(), "remote_piloted": ship.is_remote_piloted(),
		"home": home.get_instance_id(), "home_id": ship.get_home_berth_id(),
		"home_occupant": _retained_id(home.get_occupant()),
		"home_owner": _retained_id(home.get_reservation_owner()),
		"home_ship_id": home.get_reserved_ship_id(), "home_token": home.get_reservation_token(ship),
		"component_connections": _component_connection_snapshot(model),
		"null_role_discovery": _null_role_discovery_snapshot(entry)}


# These two discovery spheres belong to the null-role Cinder station owners,
# not physical hull collision. Their existing clear_for_detach() retires them.
# This does not qualify an active role or require discovery to become available.
func _capture_null_role_discovery(entry: Dictionary) -> bool:
	var bindings: Array[Dictionary] = []
	entry["null_role_discovery"] = bindings
	var ship: HeroShip = entry["ship"] as HeroShip
	if not ship is CinderCargoHauler:
		return true
	var hauler: CinderCargoHauler = ship as CinderCargoHauler
	var paths: Array[NodePath] = [
		NodePath("WalkableInterior/LoadmasterCabin/LoadmasterStationInteraction"),
		NodePath("WalkableInterior/LoadmasterCabin/NavigatorStationInteraction"),
	]
	var owners: Array[Area3D] = [hauler.get_loadmaster_interaction(), hauler.get_navigator_interaction()]
	var valid: bool = hauler.get_crew_role_authority() == null
	for index: int in paths.size():
		var owner: Area3D = owners[index]
		var shape: CollisionShape3D = owner.get_node_or_null("InteractionShape") as CollisionShape3D if is_instance_valid(owner) else null
		valid = valid and is_instance_valid(owner) and is_instance_valid(shape) \
			and ship.get_node_or_null(paths[index]) == owner \
			and not bool(owner.call(&"is_available")) \
			and owner.collision_layer == PhysicsLayers.INTERACTABLE_AREA_LAYER and owner.collision_mask == 0
		bindings.append({"path": paths[index], "owner": owner, "shape": shape})
	valid = valid and bindings.size() == 2 and owners[0] != owners[1]
	_check(valid, "null-role Cinder discovery binds exactly the retained Loadmaster/Navigator interaction spheres, both unavailable")
	return valid


func _null_role_discovery_snapshot(entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for binding: Dictionary in entry["null_role_discovery"]:
		var owner: Area3D = binding["owner"] as Area3D
		var shape: CollisionShape3D = binding["shape"] as CollisionShape3D
		result.append({"path": binding["path"], "owner": _retained_id(owner),
			"shape": _retained_id(shape),
			"available": bool(owner.call(&"is_available")) if is_instance_valid(owner) else true})
	return result


func _expected_component_cut_snapshot(entry: Dictionary) -> Dictionary:
	var expected: Dictionary = (entry["baseline"] as Dictionary).duplicate(true)
	var bindings: Array = entry["null_role_discovery"]
	if bindings.is_empty():
		return expected
	var hauler: CinderCargoHauler = entry["ship"] as CinderCargoHauler
	if bindings.size() != 2 or not is_instance_valid(hauler) or hauler.get_crew_role_authority() != null:
		return {}
	var matches: int = 0
	for binding: Dictionary in bindings:
		var owner: Area3D = binding["owner"] as Area3D
		var shape: CollisionShape3D = binding["shape"] as CollisionShape3D
		if not is_instance_valid(owner) or not is_instance_valid(shape) \
				or shape.get_parent() != owner or hauler.get_node_or_null(binding["path"]) != owner \
				or bool(owner.call(&"is_available")):
			return {}
		for row: Dictionary in expected["shapes"]:
			if int(row["node"]) == shape.get_instance_id() and int(row["owner"]) == owner.get_instance_id():
				row["disabled"] = true
				matches += 1
	# Every other raw shape field and the complete authority snapshot are still
	# compared. Raw initial enabled bits remain in the printed baseline unchanged.
	return expected if matches == 2 else {}


func _retained_id(value: Object) -> int:
	return value.get_instance_id() if is_instance_valid(value) else 0


func _component_connection_snapshot(model: ShipComponentDamage) -> Array[String]:
	var result: Array[String] = []
	for signal_info: Dictionary in model.get_signal_list():
		var signal_name: StringName = signal_info["name"]
		for connection: Dictionary in model.get_signal_connection_list(signal_name):
			var callback: Callable = connection["callable"]
			result.append("%s:%d:%s:%d" % [signal_name, callback.get_object_id(),
				callback.get_method(), int(connection["flags"])])
	result.sort()
	return result


func _compare_component_cut(
	game: GameFlow, cut: Dictionary, authority: LiveCombatAuthority, cycle: int, live: bool
	) -> bool:
	var player_valid: bool = paused and game.player == cut["player"] and _component_player_is_unclaimed(game)
	_check(player_valid, "component cycle %d live=%s retains the same unclaimed on-foot Player" % [cycle + 1, live])
	var valid: bool = player_valid
	for entry: Dictionary in cut["entries"]:
		var ship: HeroShip = entry["ship"] as HeroShip
		var actual: Dictionary = _component_cut_snapshot(entry)
		var expected: Dictionary = _expected_component_cut_snapshot(entry)
		var matches: bool = not expected.is_empty() and actual == expected and _component_entry_is_quiescent(entry) \
			and ship.is_inside_tree() == live \
			and authority.get_source_id(ship) == (int(entry["source_id"]) if live else 0)
		print("MAIN_COMPONENT_CYCLE: ", cycle + 1, " live=", live,
			" ship=", entry["ship_id"], " actual=", actual)
		_check(matches, "component cycle %d live=%s retains actual ledger/hull/shape/empty claims/home/source: %s" \
			% [cycle + 1, live, entry["ship_id"]])
		valid = valid and matches
	_check(valid, "component cycle %d live=%s passes all retained-authority comparisons with zero paused repair advancement" % [cycle + 1, live])
	return valid


func _observe_normal_component_repair(cut: Dictionary) -> void:
	# Every craft stayed landed, intact and not landing during the cut. Observe
	# actual completed production ticks; do not advance the ledger from the test.
	for frame: int in 12:
		await physics_frame
		for entry: Dictionary in cut["entries"]:
			if not _component_entry_is_quiescent(entry):
				_check(false, "normal repair keeps every craft eligible on physics observation %d" % frame)
				return
	for entry: Dictionary in cut["entries"]:
		var ship: HeroShip = entry["ship"] as HeroShip
		var model: ShipComponentDamage = ship.get_component_damage()
		var before: Dictionary = entry["baseline"]
		var elapsed: float = float(ship.get("_elapsed")) - float(before["elapsed"])
		var valid: bool = elapsed > 0.0 and model == entry["model"] \
			and model.get_ledger_generation() == int(before["generation"]) \
			and model.get_revision() > int(before["revision"]) \
			and is_equal_approx(float(ship.get("_hull")), float(before["hull"]))
		for component: Dictionary in before["states"]:
			var expected: float = minf(1.0, float(component["integrity"]) + model.repair_rate_per_second * elapsed)
			valid = valid and is_equal_approx(model.get_component_integrity(StringName(component["id"])), expected)
		print("MAIN_COMPONENT_NORMAL_REPAIR: ", entry["ship_id"], " eligible_elapsed=", elapsed,
			" before=", before["states"], " actual=", model.get_component_states(),
			" revision=", model.get_revision(), " generation=", model.get_ledger_generation())
		_check(valid, "normal production repair matches actual eligible elapsed without hull heal or generation reset: %s" % entry["ship_id"])
		if not valid:
			return


func _test_queued_main_reentry_restore() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "queued-reentry fixture instantiates a second production Main")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	await _await_settled_roster(game)
	var resolver := game.get_combat_resolver() as CombatResolver
	var parent := game.get_parent()
	_check(
		resolver != null and resolver.get_registered_source_count() == 13,
		"queued-reentry fixture begins with the settled thirteen-source combat registry"
	)
	if resolver == null or parent == null:
		await _clean_up(game)
		return
	parent.remove_child(game)
	await process_frame
	var detached_apply_count := int(game.get_runtime_settings_persistence_report().get("apply_count", -1))
	_check(
		resolver.get_registered_source_count() == 0
		and not bool(game.get_caption_integration_report().get("hud_request_sink_bound", true)),
		"queued-reentry fixture confirms detach releases combat registration and the caption HUD sink"
	)
	parent.add_child(game)
	game.queue_free()
	game.call("_restore_runtime_bindings_after_reentry")
	_check(
		game.is_queued_for_deletion()
		and resolver.get_registered_source_count() == 0
		and int(game.get_runtime_settings_persistence_report().get("apply_count", -1)) == detached_apply_count
		and not bool(game.get_caption_integration_report().get("hud_request_sink_bound", true)),
		"queued Main rejects reentry restore before combat, global settings, or HUD binding mutation"
	)
	for _frame in 3:
		await process_frame
	_check(not is_instance_valid(game), "queued-reentry fixture frees its rejected Main without a retained subtree")


func _test_world_deferred_damage_receipt_currentness() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "world deferred-receipt fixture instantiates a third production Main")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var target: StaticBody3D = null
	if world != null:
		for candidate in world.find_children("*", "StaticBody3D", true, false):
			target = candidate as StaticBody3D
			if target != null:
				break
	_check(
		world != null and target != null,
		"world deferred-receipt fixture resolves a live ShipyardWorld target"
	)
	if world == null or target == null:
		await _clean_up(game)
		return

	var detached_pending := world.defer_target_damage_presentation(
		92001, target, &"detached_receipt_target", Vector3.ZERO, false
	)
	var world_parent := world.get_parent()
	var topology_before := game.get_minimap_snapshot().topology_nodes as Array
	world_parent.remove_child(world)
	await process_frame
	_check(not topology_before.is_empty() and (game.get_minimap_snapshot().topology_nodes as Array).is_empty(),
		"detached world withdraws cached minimap topology")
	var detached_before := _world_deferred_receipt_snapshot(world, target)
	var detached_deferred := world.defer_target_damage_presentation(
		92004, target, &"detached_rejected_target", Vector3.ZERO, false
	)
	var detached_committed := world.commit_deferred_damage_presentation(92001)
	_check(
		not world.is_inside_tree()
		and detached_pending
		and not detached_deferred
		and not detached_committed
		and _world_deferred_receipt_snapshot(world, target) == detached_before,
		"detached ShipyardWorld rejects stale admission and leaves an existing deferred receipt unconsumed"
	)

	world_parent.add_child(world)
	_check(game.get_minimap_snapshot().topology_nodes == topology_before,
		"reentered world restores the retained minimap topology")
	await process_frame
	await physics_frame
	await process_frame
	var reentry_pending := world.get_pending_target_damage_presentation_count()
	world.discard_deferred_damage_presentations()
	_check(
		world.is_inside_tree()
		and reentry_pending == 1
		and world.get_pending_target_damage_presentation_count() == 0,
		"reentered ShipyardWorld explicitly discards the stale detached receipt before fresh work"
	)
	var live_deferred := world.defer_target_damage_presentation(
		92002, target, &"live_receipt_target", Vector3.ZERO, false
	)
	var live_pending := world.get_pending_target_damage_presentation_count()
	world.discard_deferred_damage_presentations()
	_check(
		world.is_inside_tree()
		and live_deferred
		and live_pending == 1
		and world.get_pending_target_damage_presentation_count() == 0,
		"reentered ShipyardWorld accepts a fresh deferred receipt and retains explicit teardown discard"
	)

	var queued_pending := world.defer_target_damage_presentation(
		92003, target, &"queued_receipt_target", Vector3.ZERO, false
	)
	var queued_before := _world_deferred_receipt_snapshot(world, target)
	world.queue_free()
	var queued_deferred := world.defer_target_damage_presentation(
		92005, target, &"queued_rejected_target", Vector3.ZERO, false
	)
	var queued_committed := world.commit_deferred_damage_presentation(92003)
	_check(
		world.is_inside_tree()
		and world.is_queued_for_deletion()
		and queued_pending
		and not queued_deferred
		and not queued_committed
		and _world_deferred_receipt_snapshot(world, target) == queued_before,
		"queued ShipyardWorld rejects stale receipt admission and commit without pending, target, or effect mutation"
	)
	await _clean_up(game)


func _world_deferred_receipt_snapshot(
	world: ShipyardWorld,
	target: StaticBody3D
	) -> Dictionary:
	return {
		"pending_count": world.get_pending_target_damage_presentation_count(),
		"child_count": world.get_child_count(),
		"impact_count": world.find_children(
			"ProjectileImpact", "MeshInstance3D", true, false
		).size(),
		"target_collision_layer": target.collision_layer,
		"target_collision_mask": target.collision_mask,
		"target_destroyed": bool(target.get_meta("destroyed", false)),
		"target_authority_committed": bool(
			target.get_meta("destruction_authority_committed", false)
		),
		"target_visual_committed": bool(
			target.get_meta("destruction_visual_committed", false)
		),
	}.duplicate(true)


func _test_pre_guide_freeplay_fire_contract(
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
	var weapon_ids_by_ship_id := {
		&"torrent_provisional": GameFlow.TORRENT_COMBAT_WEAPON_ID,
		&"arrow_provisional": GameFlow.ARROW_COMBAT_WEAPON_ID,
		&"jovian_provisional": GameFlow.JOVIAN_COMBAT_WEAPON_ID,
		&"zenith_b7_observed": GameFlow.ZENITH_COMBAT_WEAPON_ID,
		&"halyard_new_design": GameFlow.HALYARD_COMBAT_WEAPON_ID,
		&"bulwark_heavy_gunship": GameFlow.BULWARK_COMBAT_WEAPON_ID,
	}
	var all_freeplay_fire_truthful := true
	for firing_ship in fleet:
		game.active_ship = firing_ship
		game.phase = GameFlow.Phase.FREE_FLIGHT
		game.set("_guided_activity_complete", false)
		pulse.clear_effects()
		var origin := firing_ship.global_position + Vector3.UP * 0.5
		var direction := Vector3.FORWARD
		blocker.global_position = origin + direction * 2.0
		await physics_frame
		var sequence_before := authority.get_last_submitted_sequence(firing_ship)
		game.call("_on_projectile_fired", origin, direction, firing_ship)
		var result: Dictionary = game.get_last_player_shot_result()
		var request := result.get("request") as ShotRequest
		var shots := pulse.get_active_shot_snapshots()
		var snapshot: Dictionary = shots[0] if shots.size() == 1 else {}
		all_freeplay_fire_truthful = (
			all_freeplay_fire_truthful
			and bool(result.get("accepted", false))
			and bool(result.get("resolved", false))
			and result.get("status", &"") == &"world_blocked"
			and request != null
			and request.weapon_id == weapon_ids_by_ship_id.get(firing_ship.get_ship_id(), &"")
			and authority.get_last_submitted_sequence(firing_ship) == sequence_before + 1
			and shots.size() == 1
			and float(snapshot.get("distance", 0.0)) > 0.2
			and bool(snapshot.get("hit", false))
		)
	_check(
		all_freeplay_fire_truthful
		and is_equal_approx(float(opponent.call("get_health")), opponent_health_before),
		"all six craft resolve pre-guide freeplay fire through their own weapon profile and stop at world geometry"
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


func _direct_combat_fleet(fleet: Array[HeroShip]) -> Array[HeroShip]:
	var direct_ids := {
		&"torrent_provisional": true,
		&"arrow_provisional": true,
		&"jovian_provisional": true,
		&"zenith_b7_observed": true,
		&"halyard_new_design": true,
		&"bulwark_heavy_gunship": true,
	}
	var result: Array[HeroShip] = []
	for candidate in fleet:
		if direct_ids.has(candidate.get_ship_id()):
			result.append(candidate)
	return result


func _await_settled_roster(game: GameFlow) -> Dictionary:
	var audit: Dictionary = {}
	for _attempt in 120:
		audit = game.get_live_combat_source_roster_audit()
		if bool(audit.get("valid", false)) \
				and int(audit.get("expected_player_source_count", 0)) == 9 \
				and int(audit.get("expected_source_count", 0)) == 13 \
				and int(audit.get("actual_source_count", 0)) == 13:
			return audit
		await process_frame
	return audit


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
		if _is_optional_semantic_runtime_adapter(node) or _is_regenerated_presentation(node, search_root):
			continue
		ids.append(node.get_instance_id())
		# aca8cb9e4: a dormant production opponent parks its visual root out of
		# the tree and reattaches the same root on activation. That retained
		# subtree is still this Main's identity whether or not it is attached.
		if node is RangeOpponent and not (node as RangeOpponent).is_presentation_resident():
			var parked := (node as RangeOpponent).get_presentation_root()
			if parked != null:
				ids.append(parked.get_instance_id())
				for parked_node in parked.find_children("*", "", true, false):
					ids.append(parked_node.get_instance_id())
	ids.sort()
	return ids


func _is_regenerated_presentation(node: Node, search_root: Node) -> bool:
	# These exact presentation owners intentionally recreate transient rows and
	# projectile cue adapters on attachment; retain every other gameplay identity.
	var hud := search_root.get_node_or_null("HUD")
	var rows := hud.get("_nearby_activity_rows") as Node if hud != null else null
	if rows != null and rows.is_ancestor_of(node):
		return true
	return node.get_parent() is BomberPayloadAudioBinding \
		and node.get_script() == preload("res://scripts/audio/bomber_payload_projectile_audio_binding.gd")


func _is_optional_semantic_runtime_adapter(node: Node) -> bool:
	# The optional-audio composition recreates two unnamed presentation adapters
	# on each attach. They are not authored Main hierarchy or gameplay identity.
	return node.get_parent() != null \
		and node.get_parent().name == &"OptionalSemanticAudioComposition" \
		and String(node.name).begins_with("@Node@")


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
		if game.is_inside_tree():
			game.queue_free()
		else:
			game.free()
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


func _test_craft_lod_epoch(craft, epoch: String, game: GameFlow, world: ShipyardWorld, authority: LiveCombatAuthority) -> void:
	var before := {"craft": _lod_retained_snapshot(craft), "external": _lod_main_external(craft, game, world, authority)}
	var source_id: int = (craft.get_command_source()).get_instance_id()
	for item: Array in [[20.0, 0], [120.0, 0], [120.001, 1], [110.0, 1], [100.0, 1], [99.999, 0]]:
		craft.update_exterior_lod_distance(float(item[0]))
		var report: Dictionary = craft.get_exterior_lod_report()
		var actual := {"craft": _lod_retained_snapshot(craft), "external": _lod_main_external(craft, game, world, authority)}
		var difference := _lod_first_difference(before, actual)
		if not difference.is_empty():
			print("MAIN_CRAFT_LOD_FIRST_DIFFERENCE: craft=", craft.get_ship_id(), " epoch=", epoch, " distance=", item[0], " ", difference)
		_check(report.valid and report.active_lod == int(item[1]) and difference.is_empty()
			and craft.get_command_source().get_instance_id() == source_id,
			"%s complete exterior switch retains exact owned resources and authority within %s at %s" % [craft.get_ship_id(), epoch, item[0]])


# Snapshot actual owned resources, not duplicate-returning definition getters.
# Prime normal lazy discovery before walking IDs so the first comparison has
# exactly the same ownership universe as all later ones.
func _lod_retained_snapshot(craft) -> Dictionary:
	craft.get_command_source()
	craft.get_weapon_component_emitter_snapshot()
	craft.get_exterior_lod_report()
	var resources: Dictionary = {}
	var nodes: Array[Dictionary] = []
	var shared: Array = craft.get("_exterior_lod_shared")
	for node: Node in [craft] + craft.find_children("*", "", true, false):
		var row := {"id": node.get_instance_id(), "parent": node.get_parent().get_instance_id() if node.get_parent() != null else 0,
			"children": node.get_child_count()}
		if node is Node3D:
			row["transform"] = (node as Node3D).transform
		if node is GeometryInstance3D and shared.has(node as GeometryInstance3D):
			row["shared_visible"] = (node as GeometryInstance3D).visible
		if node is Camera3D:
			row["cull_mask"] = (node as Camera3D).cull_mask
		if node is GeometryInstance3D:
			row["layers"] = (node as GeometryInstance3D).layers
		if node is CollisionObject3D:
			row["rid"] = (node as CollisionObject3D).get_rid()
			row["layer"] = (node as CollisionObject3D).collision_layer
			row["mask"] = (node as CollisionObject3D).collision_mask
		if node is CollisionShape3D:
			row["disabled"] = (node as CollisionShape3D).disabled
		nodes.append(row)
		for property: Dictionary in node.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				_lod_collect_resource_ids(node.get(property.name), resources)
	_lod_collect_resource_ids(craft.ship_definition, resources)
	if craft is CinderCargoHauler:
		_lod_collect_resource_ids(craft.get("_weapon_definition"), resources)
	var source: ShipCommandSource = craft.get_command_source()
	return {"nodes": nodes, "resources": resources, "source": source.get_instance_id(),
		"stream": source.get_stream_id(), "sequence": source.get_next_sequence(),
		"anchors": (craft.get_payload_hardpoints() if craft is CinderLongRangeBomber else craft.get_cargo_transfer_anchors()).map(func(anchor: Marker3D) -> int: return anchor.get_instance_id()),
		"payload": craft.get_payload_authority_snapshot() if craft is CinderLongRangeBomber else {},
		"payload_owner": craft.get("_payload_authority").get_instance_id() if craft is CinderLongRangeBomber else 0,
		"definition": craft.ship_definition.get_instance_id(), "hull": craft.get("_hull"),
		"ledger": craft.get_component_damage().get_ledger_snapshot(),
		"generation": craft.get_component_damage().get_ledger_generation()}


func _lod_collect_resource_ids(value: Variant, ids: Dictionary) -> void:
	if value is Resource and not value is Script:
		var resource := value as Resource
		var id := resource.get_instance_id()
		if ids.has(id):
			return
		ids[id] = resource.get_class()
		if resource is Mesh:
			for surface in (resource as Mesh).get_surface_count():
				_lod_collect_resource_ids((resource as Mesh).surface_get_material(surface), ids)
		for property: Dictionary in resource.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				_lod_collect_resource_ids(resource.get(property.name), ids)
	elif value is Array:
		for item: Variant in value:
			_lod_collect_resource_ids(item, ids)
	elif value is Dictionary:
		for item: Variant in value.values():
			_lod_collect_resource_ids(item, ids)


func _lod_first_difference(expected: Variant, actual: Variant, path: String = "owned") -> String:
	if typeof(expected) != typeof(actual):
		return "%s expected=%s actual=%s" % [path, str(expected), str(actual)]
	if expected is Dictionary:
		if expected.size() != actual.size():
			return "%s.size expected=%s actual=%s" % [path, expected.size(), actual.size()]
		for key: Variant in expected:
			if not actual.has(key):
				return "%s[%s] expected=%s actual=MISSING" % [path, key, str(expected[key])]
			var difference := _lod_first_difference(expected[key], actual[key], "%s[%s]" % [path, key])
			if not difference.is_empty():
				return difference
	elif expected is Array:
		if expected.size() != actual.size():
			return "%s.size expected=%s actual=%s" % [path, expected.size(), actual.size()]
		for index in expected.size():
			var difference := _lod_first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if not difference.is_empty():
				return difference
	elif expected != actual:
		return "%s expected=%s actual=%s" % [path, str(expected), str(actual)]
	return ""


func _lod_main_external(craft, game: GameFlow, world: ShipyardWorld, authority: LiveCombatAuthority) -> Dictionary:
	var home := world.get_berth_node(craft.get_home_berth_id())
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var role = craft.get_crew_role_authority() if craft is CinderCargoHauler else null
	return {"world": world.get_instance_id(), "player": game.player.get_instance_id(),
		"source": authority.get_source_id(craft), "source_count": game.get_combat_resolver().get_registered_source_count(),
		"home": home.get_instance_id(), "home_id": craft.get_home_berth_id(),
		"home_occupant": _retained_id(home.get_occupant()), "home_owner": _retained_id(home.get_reservation_owner()),
		"home_ship_id": home.get_reserved_ship_id(), "home_token": home.get_reservation_token(craft),
		"berth_token": (game.get("_berth_tokens") as Dictionary).get(craft.get_instance_id()),
		"boarding_reserved": area.is_reserved(), "boarding_token": area.get_reservation_token(),
		"role": _retained_id(role), "claims": role.get_snapshot() if role != null else {},
		"pilot": craft.is_piloted(), "remote_pilot": craft.is_remote_piloted()}
