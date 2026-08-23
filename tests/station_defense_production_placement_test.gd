extends SceneTree

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
		content != null and board != null
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
	_check(
		torrent.get_ship_id() == &"torrent_provisional"
		and torrent_registered
		and bool(reward_configured.get("accepted", false)),
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
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var alpha_terminal := await _destroy_with_torrent(authority, torrent, alpha)
	var relief := content.advance_physics(0.5, generation)
	await physics_frame
	var beta_terminal := await _destroy_with_torrent(authority, torrent, beta)
	var gamma_terminal := await _destroy_with_torrent(authority, torrent, gamma)
	await process_frame
	var reward_snapshot: Dictionary = board.get_reward_handoff_snapshot()
	_check(
		bool(alpha_terminal.get("destroyed", false))
		and bool(relief.get("accepted", false))
		and bool(beta_terminal.get("destroyed", false))
		and bool(gamma_terminal.get("destroyed", false))
		and content.get_snapshot().host.activity.state_id == &"completed"
		and _reward_requests.size() == 1
		and int(_reward_requests[0].activity_generation) == generation
		and int(reward_snapshot.highest_reward_generation) == generation
		and authority.get_resolver().get_registered_source_count() == 1,
		"real fleet fire resolves every wave and completion feeds the shared reward adapter exactly once"
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
