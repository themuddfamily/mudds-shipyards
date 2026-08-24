extends SceneTree

## This load order is intentional: it covers the clean-load dependency cycle in
## which the picket's RangeOpponent base is resolved before ShipyardWorld.
const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
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
const TORRENT_SOURCE_ID := 1101
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

var _assertions := 0
var _failures: Array[String] = []
var _reward_requests: Array[Dictionary] = []


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
	var console_mesh := (
		board_console.mesh as BoxMesh if board_console != null else null
	)
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
		and board_label.get_aabb().size.x <= console_mesh.size.x,
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
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var picket := roster.get_node(^"PerimeterHeavyPicket") as StandoffPicketOpponent
	var alpha_terminal := await _destroy_with_torrent(authority, torrent, alpha)
	var relief := content.advance_physics(0.5, generation)
	await physics_frame
	var beta_terminal := await _destroy_with_torrent(authority, torrent, beta)
	var gamma_terminal := await _destroy_with_torrent(authority, torrent, gamma)
	var reinforcement := content.advance_physics(1.25, generation)
	await physics_frame
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
		and _reward_requests.size() == 1
		and int(_reward_requests[0].activity_generation) == generation
		and int(reward_snapshot.highest_reward_generation) == generation
		and bool(completed_save.get("accepted", false))
		and persisted_history.get("state_id") == &"completed"
		and int(persisted_history.get("reward_handoff_generation", 0)) == generation
		and not bool(persisted_history.get("reward_replayable", true))
		and authority.get_resolver().get_registered_source_count() == 1,
		"real fleet fire must neutralize the heavy picket before completion feeds the shared reward adapter exactly once"
	)
	content.snapshot_changed.emit(content.get_snapshot())
	_check(
		_reward_requests.size() == 1,
		"a repeated completed snapshot cannot duplicate the committed reward handoff"
	)

	var completed_reset: Dictionary = board.abort_and_reset(actor, generation)
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
	call_deferred("_finish")


func _accept_reward_request(request: Dictionary) -> Dictionary:
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
	var actor := Node3D.new()
	reload_root.add_child(actor)
	actor.global_position = board.global_position + Vector3(1.5, 0.0, 0.0)
	var started: bool = board.interact(actor)
	_check(
		started
		and content.get_generation() > int(persisted_history.generation)
		and authority.get_resolver().get_registered_source_count() == before_sources
		and _reward_requests.size() == reward_before,
		"the restored board starts a fresh higher generation without replaying the prior reward or duplicating sources"
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
