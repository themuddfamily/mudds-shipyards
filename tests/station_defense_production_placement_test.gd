extends SceneTree

## This load order is intentional: it covers the clean-load dependency cycle in
## which the picket's RangeOpponent base is resolved before ShipyardWorld.
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
const TORRENT_WEAPON := preload("res://assets/weapons/torrent_combat_pulse.tres")
const AUDITED_ENCOUNTER_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(90.0, 0.0, -10.0)
)
const ACTIVITY_BOARD_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(12.0, 1.0, -26.0)
)
const TORRENT_SOURCE_ID := 81101
const TORRENT_FACTION: StringName = &"shipyard_flight_test"

class MemoryUserDataStore extends RefCounted:
	var payload: Dictionary = {}
	var generation := 0

	func commit(next_payload: Dictionary, expected_generation: int, _commit_id: String) -> Dictionary:
		if expected_generation != generation:
			return {"accepted": false, "reason": &"stale_generation", "generation": generation}
		payload = next_payload.duplicate(true)
		generation += 1
		return {"accepted": true, "reason": &"committed", "generation": generation}

	func load() -> Dictionary:
		return {
			"accepted": true,
			"reason": &"ok",
			"generation": generation,
			"payload": payload.duplicate(true),
		}

class RewardFaultFilesystem extends UserDataFilesystem:
	var reject_rewards := true
	var reject_all := false
	var refused_reward := false
	var fail_published_sync := false
	var reward_published := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if reject_all:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			refused_reward = true
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func rename_path(from_path: String, to_path: String) -> Error:
		var reward := false
		if from_path.ends_with(".tmp"):
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(from_path))
			reward = document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-")
		var result := super.rename_path(from_path, to_path)
		if result == OK and reward:
			reward_published = true
		return result

	func sync_directory(path: String) -> Error:
		if reward_published and fail_published_sync:
			fail_published_sync = false
			reward_published = false
			return ERR_UNAVAILABLE
		return super.sync_directory(path)

var _assertions := 0
var _failures: Array[String] = []
var _reward_requests: Array[Dictionary] = []
var _rejected_reward_requests: Array[Dictionary] = []
var _reject_rewards := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var production_root := Node3D.new()
	production_root.name = "StationDefenseProductionRoot"
	root.add_child(production_root)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	production_root.add_child(authority)
	var director := ActivityDirector.new()
	director.name = "ActivityDirector"
	production_root.add_child(director)
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	production_root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var content := world.get_station_defense_content()
	var board: Variant = world.get_station_defense_activity_board()
	_check(
		PICKET_SCENE.can_instantiate()
		and content != null and board != null
		and world.find_children("*", "StationDefenseEncounterContent", true, false).size() == 1
		and content.scene_file_path == "res://scenes/activities/station_defense_encounter.tscn"
		and content.global_transform.is_equal_approx(AUDITED_ENCOUNTER_TRANSFORM)
		and board.global_transform.is_equal_approx(ACTIVITY_BOARD_TRANSFORM),
		"production ShipyardWorld places one checked-in encounter and one board at their fixed audited anchors"
	)
	if content == null or board == null:
		production_root.queue_free()
		for _frame in 10:
			await process_frame
		call_deferred("_finish")
		return
	var board_snapshot: Dictionary = board.get_snapshot()
	_check(
		content.is_content_ready()
		and content.get_combat_authority() == authority
		and content.get_host().get_combat_authority() == authority
		and int(board_snapshot.combat_authority_instance_id) == authority.get_instance_id()
		and int(board_snapshot.activity_director_instance_id) == director.get_instance_id()
		and not bool(board_snapshot.combat_authority)
		and not bool(board_snapshot.activity_authority)
		and not bool(board_snapshot.health_authority)
		and not bool(board_snapshot.reward_authority)
		and int(board_snapshot.process_loops) == 0,
		"board reuses the exact external combat owner and ActivityDirector seam without acquiring authority"
	)
	var console_body := board.get_node_or_null(^"CollisionBackedConsole") as StaticBody3D
	var console_collision := (
		console_body.get_node_or_null(^"Collision") as CollisionShape3D
		if console_body != null else null
	)
	var console_shape := console_collision.shape as BoxShape3D if console_collision != null else null
	var board_console := (
		console_body.get_node_or_null(^"ActivityBoardConsole") as MeshInstance3D
		if console_body != null else null
	)
	var console_mesh := board_console.mesh as Mesh if board_console != null else null
	var board_label := board.get_node_or_null(^"ActivityLabel") as Label3D
	var central_berth := world.get_node(^"CentralBerth") as ShipBerth
	var console_minimum_x := (
		console_collision.global_position.x - console_shape.size.x * 0.5
		if console_shape != null else -INF
	)
	_check(
		console_body != null
		and console_body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
		and console_collision != null and not console_collision.disabled
		and console_shape != null
		and console_minimum_x > (
			central_berth.get_dock_transform().origin.x
			+ central_berth.get_landing_half_extents().x
		)
		and bool(world.get_station_route_registry_report().get("valid", false)),
		"collision-backed console sits outside the central landing envelope and preserves the station route registry"
	)
	_check(
		board_label != null
		and "STATION" in board_label.text
		and "DEFENSE" in board_label.text
		and console_mesh != null
		and board_label.get_aabb().size.x <= console_mesh.get_aabb().size.x,
		"physical defense board keeps its station-defense identity inside the actual display face"
	)
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	torrent.name = "TorrentInterceptor"
	torrent.ship_definition = TORRENT_DEFINITION
	production_root.add_child(torrent)
	await process_frame
	var torrent_profile := {
		TORRENT_WEAPON.weapon_id: {
			"range": TORRENT_WEAPON.range_meters,
			"damage": TORRENT_WEAPON.damage_per_hit,
			"origin_tolerance": 24.0,
		},
	}
	var torrent_registered := authority.register_source(
			torrent, TORRENT_SOURCE_ID, TORRENT_FACTION, torrent_profile
		)
	var reward_configured := world.configure_station_defense_reward_handoff(
			Callable(self, "_accept_reward_request")
		)
	var session_store := MemoryUserDataStore.new()
	var persistence_configured := world.configure_station_defense_session_persistence(
		session_store, &"station_defense_slot"
	)
	_check(
		torrent.get_ship_id() == &"torrent_provisional"
		and torrent_registered
		and bool(reward_configured.get("accepted", false))
		and persistence_configured,
		"real production Torrent source and shared nearby reward handoff join the existing live authority"
	)

	var actor := Node3D.new()
	actor.name = "StationDefenseBoardActor"
	production_root.add_child(actor)
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var generation := content.get_generation()
	var stale_gate: Dictionary = board.get_interaction_snapshot(actor, generation + 1)
	actor.global_position = Vector3.ZERO
	var range_gate: Dictionary = board.get_interaction_snapshot(actor, generation)
	var before_rejections := content.get_snapshot()
	_check(
		stale_gate.reason == &"stale_generation"
		and range_gate.reason == &"out_of_range"
		and not board.interact(actor)
		and content.get_snapshot() == before_rejections,
		"stale generation and out-of-range board requests reject before encounter mutation"
	)
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var started: bool = board.interact(actor)
	var started_snapshot := content.get_snapshot()
	_check(
		started
		and bool(board.get_last_result().get("accepted", false))
		and started_snapshot.host.activity.state_id == &"active"
		and int(started_snapshot.host.active_entity_count) == 1
		and authority.get_resolver().get_registered_source_count() == 4,
		"embodied board interaction starts the externally combat-owned encounter and its first authored wave"
	)
	generation = content.get_generation()
	var active_save := world.save_station_defense_session(
		session_store.generation, "station-defense-active-history"
	)
	var active_saved_history := (
		((session_store.payload.get("session", {}) as Dictionary).get("history", {}))
		as Dictionary
	)
	_check(
		bool(active_save.get("accepted", false))
		and active_saved_history.get("state_id") == &"idle"
		and int(active_saved_history.get("generation", -1)) == 0
		and not active_saved_history.has("active_hostile_handles")
		and not active_saved_history.has("health")
		and not active_saved_history.has("leases"),
		"saving during combat records only the prior safe idle history and no live encounter state"
	)
	var roster := content.get_node(^"OpponentRoster") as Node3D as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var picket := roster.get_node(^"PerimeterHeavyPicket") as StandoffPicketOpponent
	var alpha_terminal := await _destroy_with_torrent(authority, torrent, alpha)
	var relief := content.advance_physics(2.5, generation)
	await physics_frame
	var beta_terminal := await _destroy_with_torrent(authority, torrent, beta)
	var gamma_terminal := await _destroy_with_torrent(authority, torrent, gamma)
	var reinforcement := content.advance_physics(8.0, generation)
	await physics_frame
	# The reward authority rejects this completion, as it does while the save
	# store cannot commit. The earned report must stay owed, not vanish.
	_reject_rewards = true
	var picket_terminal := await _destroy_with_torrent(authority, torrent, picket, 8)
	await process_frame
	var reward_snapshot: Dictionary = board.get_reward_handoff_snapshot()
	var completed_save := world.save_station_defense_session(
		session_store.generation, "station-defense-completed-history"
	)
	var persisted_history := (
		((session_store.payload.get("session", {}) as Dictionary).get("history", {}))
		as Dictionary
	).duplicate(true)
	_check(
		bool(alpha_terminal.get("destroyed", false))
		and bool(relief.get("accepted", false))
		and bool(beta_terminal.get("destroyed", false))
		and bool(gamma_terminal.get("destroyed", false))
		and bool(reinforcement.get("accepted", false))
		and bool(picket_terminal.get("destroyed", false))
		and content.get_snapshot().host.activity.state_id == &"completed"
		and not _rejected_reward_requests.is_empty()
		and int(_rejected_reward_requests[0].activity_generation) == generation
		and _reward_requests.is_empty()
		and int(reward_snapshot.highest_reward_generation) == 0
		and bool(completed_save.get("accepted", false))
		and persisted_history.get("state_id") == &"completed"
		and int(persisted_history.get("reward_handoff_generation", -1)) == 0
		and not bool(persisted_history.get("reward_replayable", true))
		and authority.get_resolver().get_registered_source_count() == 1,
		"real fleet fire must neutralize the heavy picket before completion feeds the shared reward adapter, which rejects it"
	)
	# The store recovers while the finished run sits on the board.
	_reject_rewards = false
	for _frame in 4:
		await physics_frame
		await process_frame
	var completed_snapshot := content.get_snapshot()
	var completed_reset: Dictionary = board.abort_and_reset(actor, generation)
	_check(
		_reward_requests.size() == 1
		and int(_reward_requests[0].activity_generation) == generation
		and int(board.get_reward_handoff_snapshot().highest_reward_generation) == generation,
		"resetting the completed board first pays the owed report exactly once"
	)
	content.snapshot_changed.emit(completed_snapshot)
	_check(
		_reward_requests.size() == 1,
		"a repeated completed snapshot cannot duplicate the committed reward handoff"
	)

	var failure_start_generation := int(
		(completed_reset.get("reset", {}) as Dictionary).get("activity", {}).get("generation", 0)
	)
	var restarted := content.start(failure_start_generation)
	var asset := content.get_protected_asset()
	var damageable := asset.get_damageable_component()
	var asset_terminal := await _destroy_with_torrent(authority, torrent, asset, 10)
	var failed_snapshot := content.get_snapshot()
	_check(
		bool(completed_reset.get("accepted", false))
		and bool(restarted.get("accepted", false))
		and bool(asset_terminal.get("destroyed", false))
		and failed_snapshot.host.activity.state_id == &"failed"
		and failed_snapshot.host.activity.failure_reason == &"protected_asset_destroyed"
		and damageable.is_destroyed()
		and asset.collision_layer == PhysicsLayers.NONE
		and _reward_requests.size() == 1
		and authority.get_resolver().get_registered_source_count() == 1,
		"resolver-owned asset damage drives physical failure without producing a completion reward"
	)
	var failed_generation := content.get_generation()
	var failure_reset: Dictionary = board.abort_and_reset(actor, failed_generation)
	var recovered_generation := int(
		(failure_reset.get("reset", {}) as Dictionary).get("activity", {}).get("generation", 0)
	)
	var recovery_started := content.start(recovered_generation)
	_check(
		bool(failure_reset.get("accepted", false))
		and bool(recovery_started.get("accepted", false))
		and not damageable.is_destroyed()
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and asset.collision_layer == PhysicsLayers.TARGET
		and authority.get_resolver().get_registered_source_count() == 4
		and _reward_requests.size() == 1,
		"failure recovery renews the same asset/content generation and restores exactly three hostile sources"
	)
	var active_reset: Dictionary = board.abort_and_reset(actor, content.get_generation())
	var post_abort_generation := int(
		(active_reset.get("reset", {}) as Dictionary).get("activity", {}).get("generation", 0)
	)
	var post_abort_start := content.start(post_abort_generation)
	_check(
		bool(active_reset.get("accepted", false))
		and bool((active_reset.get("aborted", {}) as Dictionary).get("accepted", false))
		and bool(post_abort_start.get("accepted", false))
		and authority.get_resolver().get_registered_source_count() == 4
		and _reward_requests.size() == 1,
		"active abort/reset retires then restores bounded sources without duplicating reward state"
	)

	var content_id := content.get_instance_id()
	var board_id: int = board.get_instance_id()
	var content_generation := content.get_generation()
	production_root.remove_child(world)
	await process_frame
	_check(
		not content.is_inside_tree()
		and authority.get_resolver().get_registered_source_count() == 1,
		"whole-world detach retires encounter sources without freeing the one content instance"
	)
	production_root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame
	_check(
		world.get_station_defense_content().get_instance_id() == content_id
		and world.get_station_defense_activity_board().get_instance_id() == board_id
		and content.get_generation() == content_generation
		and content.get_combat_authority() == authority
		and authority.get_resolver().get_registered_source_count() == 4
		and bool(content.get_snapshot().host.activity.attached),
		"world re-entry preserves one encounter/board, generation and external authority while restoring live sources"
	)

	var fleet_expansion := world.get_fleet_expansion_production_binding()
	if fleet_expansion != null:
		for craft_id: StringName in [
			&"cinder_cargo_hauler",
			&"cinder_long_range_bomber",
			&"cinder_light_interceptor",
		]:
			fleet_expansion.detach_craft(craft_id)
	production_root.queue_free()
	for _frame in 10:
		await process_frame
	await _verify_terminal_history_reload(session_store, persisted_history)
	await _verify_main_unpaid_recovery()
	call_deferred("_finish")


func _accept_reward_request(request: Dictionary) -> Dictionary:
	if _reject_rewards:
		_rejected_reward_requests.append(request.duplicate(true))
		return {"accepted": false, "reason": &"reward_store_commit_rejected"}
	_reward_requests.append(request.duplicate(true))
	return {"accepted": true, "grant_count": _reward_requests.size()}


func _destroy_with_torrent(
		authority: LiveCombatAuthority,
		torrent: HeroShip,
		target: Node3D,
		maximum_shots: int = 4
	) -> Dictionary:
	var result: Dictionary = {}
	for _shot in maximum_shots:
		torrent.global_position = target.global_position + Vector3(0.0, 0.0, 20.0)
		await physics_frame
		var origin := torrent.global_position
		var direction := (target.global_position - origin).normalized()
		result = authority.submit_hitscan(
			torrent, TORRENT_WEAPON.weapon_id, origin, direction
		)
		await process_frame
		if bool(result.get("destroyed", false)):
			break
	return result.duplicate(true)


func _verify_terminal_history_reload(
		store: MemoryUserDataStore,
		persisted_history: Dictionary
	) -> void:
	# Exercise the legacy codec explicitly: terminal history alone cannot imply entitlement.
	store.payload.session.schema_version = 1
	store.payload.session.erase("completion")
	var reload_root := Node3D.new()
	reload_root.name = "StationDefenseReloadRoot"
	root.add_child(reload_root)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	reload_root.add_child(authority)
	var director := ActivityDirector.new()
	director.name = "ActivityDirector"
	reload_root.add_child(director)
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	reload_root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame
	var board: Variant = world.get_station_defense_activity_board()
	var content := world.get_station_defense_content()
	var before_sources := authority.get_resolver().get_registered_source_count()
	var reward_before := _reward_requests.size()
	var configured := (
		world.configure_station_defense_session_persistence(
			store, &"station_defense_slot"
		)
		and bool(world.configure_station_defense_reward_handoff(
			Callable(self, "_accept_reward_request")
		).get("accepted", false))
	)
	var loaded := world.load_station_defense_session()
	var content_snapshot := content.get_snapshot()
	var asset := content.get_protected_asset()
	var damageable := asset.get_damageable_component()
	_check(
		configured
		and bool(loaded.get("accepted", false))
		and content_snapshot.host.activity.state_id == &"idle"
		and int(content_snapshot.host.activity.generation) \
			== int(persisted_history.generation) + 1
		and int(asset.get_asset_handle().generation) \
			== int(persisted_history.generation) + 1
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and not damageable.is_destroyed()
		and authority.get_resolver().get_registered_source_count() == before_sources
		and int(content_snapshot.host.active_entity_count) == 0
		and _reward_requests.size() == reward_before
		and not bool(board.get_session_persistence_snapshot().reward_replayable),
		"reload restores terminal history as pristine idle without enemies, damage, new sources, leases, or reward replay"
	)
	content.snapshot_changed.emit({"host": {"activity": persisted_history.duplicate(true)}})
	_check(
		_reward_requests.size() == reward_before
		and int(board.get_reward_handoff_snapshot().replay_generation_floor) \
			== int(persisted_history.generation),
		"the loaded terminal generation is permanently fenced from reward replay"
	)
	# A common-origin rebase translates the whole ShipyardWorld root; the
	# encounter still sits at its audited site within the yard.
	world.global_position += Vector3(2048.0, 0.0, -512.0)
	var actor := Node3D.new()
	reload_root.add_child(actor)
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var started: bool = board.interact(actor)
	_check(
		started
		and content.get_generation() > int(persisted_history.generation)
		and authority.get_resolver().get_registered_source_count() == before_sources
		and _reward_requests.size() == reward_before,
		"the restored board starts a fresh higher generation after an origin rebase without replaying the prior reward or duplicating sources (%s)"
			% str(board.get_last_result().get("reason", &""))
	)
	var rebased_tick := content.advance_physics(0.0, content.get_generation())
	_check(
		StringName(content.get_snapshot().host.activity.state_id) == &"active"
		and rebased_tick.get("reason") != &"audited_world_pose_changed",
		"a rebased yard keeps the live defense run instead of aborting it (%s)"
			% str(rebased_tick.get("reason", &""))
	)
	board.abort_and_reset(actor, content.get_generation())
	var fleet_expansion := world.get_fleet_expansion_production_binding()
	if fleet_expansion != null:
		for craft_id: StringName in [
			&"cinder_cargo_hauler",
			&"cinder_long_range_bomber",
			&"cinder_light_interceptor",
		]:
			fleet_expansion.detach_craft(craft_id)
	reload_root.queue_free()
	for _frame in 10:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DEFENSE_PRODUCTION_PLACEMENT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("STATION_DEFENSE_PRODUCTION_PLACEMENT_TEST_FAILED: ", "; ".join(_failures))
	quit(1)


func _main_game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(UserDataStore.new(path, filesystem), path + ".legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	game.call("_ensure_station_defense_encounter_bindings")
	return game


func _complete_main_defense(game: GameFlow) -> int:
	var content := game.world.get_station_defense_content() as StationDefenseEncounterContent
	var board := game.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	game.player.global_position = board.global_position
	_check(board.interact(game.player), "ordinary physical board starts the real Main defense")
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	torrent.ship_definition = TORRENT_DEFINITION
	game.add_child(torrent)
	await process_frame
	game.combat_authority.register_source(torrent, TORRENT_SOURCE_ID, TORRENT_FACTION, {
		TORRENT_WEAPON.weapon_id: {"range": TORRENT_WEAPON.range_meters, "damage": TORRENT_WEAPON.damage_per_hit, "origin_tolerance": 24.0}})
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var generation := content.get_generation()
	await _destroy_with_torrent(game.combat_authority, torrent, roster.get_node(^"PerimeterRaiderAlpha"))
	content.advance_physics(2.5, generation)
	await physics_frame
	await _destroy_with_torrent(game.combat_authority, torrent, roster.get_node(^"PerimeterRaiderBeta"))
	await _destroy_with_torrent(game.combat_authority, torrent, roster.get_node(^"PerimeterRaiderGamma"))
	content.advance_physics(8.0, generation)
	await physics_frame
	await _destroy_with_torrent(game.combat_authority, torrent, roster.get_node(^"PerimeterHeavyPicket"), 8)
	_check(content.get_snapshot().host.activity.state_id == &"completed", "live Main resolver destruction genuinely completes the authored defense")
	return generation


func _dispose_main(game: GameFlow) -> void:
	game.queue_free()
	await process_frame
	await process_frame


func _main_receipts(game: GameFlow) -> int:
	return int(game.get_activity_reward_report().authority.record.total_receipts)


func _verify_main_unpaid_recovery() -> void:
	var path := "user://station_defense_unpaid_%d.json" % Time.get_ticks_usec()
	var fault := RewardFaultFilesystem.new()
	var first := await _main_game(path, fault)
	first.call("_on_settings_save_requested")
	_check(first.cargo_delivery_activity.start(first.cargo_delivery_activity.get_generation()).accepted
		and first.save_jovian_cargo_session().accepted, "the real cargo owner stores its unrelated production namespace")
	fault.reject_rewards = false
	var unrelated: Dictionary = first.call("_commit_game_flow_activity_reward", {
		"activity_id": &"shipyard_heavy_breach", "activity_generation": 1,
		"reward_id": &"return_heavy_breach_credit", "reward_authority": false, "granted": false})
	_check(unrelated.accepted and _main_receipts(first) == 1, "the existing shared authority stores an unrelated genuine reward receipt")
	fault.reject_rewards = true
	var cargo_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.jovian_cargo_session
	var settings_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings
	var generation := await _complete_main_defense(first)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var terminal: Dictionary = document.payload.get("station_defense_session", {})
	_check(fault.refused_reward and _main_receipts(first) == 1 and not terminal.is_empty(),
		"real rejected Main reward leaves a genuine durable unpaid defense handoff")
	print("STATION_DEFENSE_UNPAID_RAW: ", JSON.stringify(terminal))
	var ambiguous := terminal.duplicate(true)
	ambiguous.session.history.generation = 1.5
	_check(not StationDefenseSessionAdapter.new().restore(ambiguous.session).accepted,
		"the earned-terminal codec refuses ambiguous nonintegral history generation")
	ambiguous = terminal.duplicate(true)
	ambiguous.session.completion.reward_granted = true
	_check(not StationDefenseSessionAdapter.new().restore(ambiguous.session).accepted,
		"a contradictory paid flag without the exact history acknowledgement cannot settle or repay completion")
	print("STATION_DEFENSE_REWARD_FAILURE_RAW: ", JSON.stringify(first.world.get_station_defense_activity_board().get_reward_handoff_snapshot().last_result))
	# Keep the genuine runtime-produced unpaid inner terminal, changing only its
	# outer envelope. The existing public reward consumer must refuse that future
	# contract even when disk writes work and a delayed completion calls it.
	var first_store: UserDataStore = first.get("_runtime_settings_user_data_store")
	var original_payload := first_store.get_snapshot()
	var future_outer := original_payload.duplicate(true)
	future_outer.station_defense_session.schema_version = 2
	_check(first_store.commit(future_outer, first_store.get_generation(), "unit-future-defense-envelope").accepted,
		"the actual store stages a genuine unpaid terminal behind a future outer envelope")
	var future_bytes := FileAccess.get_file_as_bytes(path)
	fault.reject_rewards = false
	var refused_outer: Dictionary = first.call("_commit_game_flow_activity_reward", {
		"activity_id": &"shipyard_perimeter_defense", "activity_generation": generation,
		"reward_id": &"return_defense_report_to_shipyard", "reward_authority": false, "granted": false})
	_check(not refused_outer.accepted and refused_outer.reason == &"reward_terminal_handoff_invalid"
		and FileAccess.get_file_as_bytes(path) == future_bytes and _main_receipts(first) == 1,
		"the public reward authority refuses a future outer envelope without changing disk bytes or receipts")
	_check(first_store.commit(original_payload, first_store.get_generation(), "unit-restore-defense-envelope").accepted,
		"the existing store restores the genuine supported unpaid handoff for ordinary cold recovery")
	fault.reject_rewards = true
	await _dispose_main(first)
	var second_fault := RewardFaultFilesystem.new()
	var second := await _main_game(path, second_fault)
	var board := second.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	second.player.global_position = board.global_position
	var handoff := board.get_reward_handoff_snapshot()
	_check(handoff.get("reward_pending", false) and int(handoff.get("pending_generation", -1)) == generation
		and "PENDING" in board.get_presentation_snapshot().text and _main_receipts(second) == 1,
		"fresh Main visibly retains the exact genuine unpaid terminal without combat replay")
	var sources := second.combat_authority.get_resolver().get_registered_source_count()
	var blocked := board.abort_and_reset(second.player, second.world.get_station_defense_content().get_generation())
	board.interact(second.player)
	_check(not blocked.accepted and board.get_reward_handoff_snapshot().get("reward_pending", false)
		and _main_receipts(second) == 1 and second.combat_authority.get_resolver().get_registered_source_count() == sources,
		"ordinary Reset and Deploy retain unpaid completion when storage refuses")
	second_fault.reject_rewards = false
	second_fault.fail_published_sync = true
	var paid_attempt := board.interact(second.player)
	var published: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload
	var authority_failure: Dictionary = second.get_activity_reward_report().authority.last_result
	_check(not paid_attempt and board.get_reward_handoff_snapshot().reward_pending
		and published.station_defense_session.session.completion.reward_granted
		and int(published.game_flow_reward_store.total_receipts) == 2
		and authority_failure.get("store_result", {}).get("reason") == &"published_directory_sync_failed",
		"real postpublication directory sync refusal leaves one atomic paid receipt and acknowledgement on disk")
	print("STATION_DEFENSE_PUBLISHED_FAILURE_RAW: ", JSON.stringify(authority_failure.get("store_result", {}).get("reason")))
	_check(board.interact(second.player) and _main_receipts(second) == 2 and not board.get_reward_handoff_snapshot().get("reward_pending", true),
		"ordinary board interaction pays the restored generation exactly once after write recovery")
	_check(JSON.parse_string(FileAccess.get_file_as_string(path)).payload.runtime_settings == settings_before
		and JSON.parse_string(FileAccess.get_file_as_string(path)).payload.jovian_cargo_session == cargo_before
		and published.game_flow_reward_store.reward_counts.return_heavy_breach_credit == 1,
		"defense retry and receipt transactions preserve actual settings, cargo and unrelated reward counts")
	await _dispose_main(second)
	var third := await _main_game(path, UserDataFilesystem.new())
	var third_board := third.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	_check(_main_receipts(third) == 2 and not third_board.get_reward_handoff_snapshot().get("reward_pending", true),
		"another cold Main retains paid acknowledgement without another reward")
	var paid_generation := await _complete_main_defense(third)
	_check(paid_generation > generation and _main_receipts(third) == 3 and not third_board.get_reward_handoff_snapshot().reward_pending,
		"the ordinary board completes and pays a distinct next generation once")
	var stale: Dictionary = third.call("_commit_game_flow_activity_reward", {
		"activity_id": &"shipyard_perimeter_defense", "activity_generation": generation,
		"reward_id": &"return_defense_report_to_shipyard", "reward_authority": false, "granted": false})
	_check(not stale.accepted and stale.reason == &"reward_generation_mismatch" and _main_receipts(third) == 3,
		"the existing reward authority fences the earlier paid completion against the new saved generation")
	var duplicate: Dictionary = third.call("_commit_game_flow_activity_reward", {
		"activity_id": &"shipyard_perimeter_defense", "activity_generation": paid_generation,
		"reward_id": &"return_defense_report_to_shipyard", "reward_authority": false, "granted": false})
	_check(not duplicate.accepted and _main_receipts(third) == 3,
		"the newly paid generation cannot duplicate its receipt")
	_check(third_board.abort_and_reset(third.player, paid_generation).accepted,
		"ordinary paid Reset checkpoints a safe new idle boundary")
	await _dispose_main(third)
	var all_fault := RewardFaultFilesystem.new()
	var fourth := await _main_game(path, all_fault)
	var fourth_board := fourth.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	_check(not fourth_board.get_reward_handoff_snapshot().reward_pending and _main_receipts(fourth) == 3,
		"fresh Main after paid Reset starts with no owed terminal and the original three receipts")
	all_fault.reject_all = true
	var unsaved_generation := await _complete_main_defense(fourth)
	_check(fourth_board.get_reward_handoff_snapshot().reward_pending and _main_receipts(fourth) == 3,
		"all-write refusal retains genuine live completion and grants no unsaved entitlement")
	await _dispose_main(fourth)
	var fifth := await _main_game(path, UserDataFilesystem.new())
	var fifth_board := fifth.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	_check(not fifth_board.get_reward_handoff_snapshot().reward_pending and _main_receipts(fifth) == 3
		and fifth.world.get_station_defense_content().get_generation() < unsaved_generation,
		"without a durable terminal another cold Main recovers only the prior safe boundary and creates no owed reward")
	var store: UserDataStore = fifth.get("_runtime_settings_user_data_store")
	var unsupported := store.get_snapshot()
	unsupported.station_defense_session.session.schema_version = 3
	_check(store.commit(unsupported, store.get_generation(), "unit-unsupported-defense-session").accepted,
		"the same real store retains a future station codec fixture")
	var future_record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).payload.station_defense_session
	await _dispose_main(fifth)
	var sixth := await _main_game(path, UserDataFilesystem.new())
	var sixth_board := sixth.world.get_station_defense_activity_board() as StationDefenseActivityBoard
	sixth.player.global_position = sixth_board.global_position
	_check(not sixth_board.interact(sixth.player)
		and not sixth_board.abort_and_reset(sixth.player, sixth.world.get_station_defense_content().get_generation()).accepted
		and JSON.parse_string(FileAccess.get_file_as_string(path)).payload.station_defense_session == future_record
		and _main_receipts(sixth) == 3,
		"unsupported newer station data is retained and ordinary Deploy/Reset refuse it without granting reward")
	await _dispose_main(sixth)
