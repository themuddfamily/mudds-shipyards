extends SceneTree

## Real-Main regression for the combat epoch that surrounds one reusable fleet
## craft. A destroyed physical source must not retain live firing authority while
## it waits for berth regeneration, and a request observed in that retired epoch
## must remain stale after whole-Main re-entry and same-instance recovery.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PhysicsLayers := preload("res://scripts/core/physics_layers.gd")

const WEAPON_ID := GameFlow.ARROW_COMBAT_WEAPON_ID
const OPEN_ARENA := Vector3(48000.0, 32000.0, -41000.0)

var _assertions := 0
var _failures := PackedStringArray()
var _arrow_requests: Array[ShotRequest] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the combat recovery lifecycle")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var authority := game.get_combat_authority() as LiveCombatAuthority
	var resolver := game.get_combat_resolver() as CombatResolver
	var arrow := game.get_node_or_null("ArrowReconShip") as HeroShip
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(
		authority != null and resolver != null and arrow != null and torrent != null and world != null,
		"fixture exposes the production authority, resolver, fleet lifecycle, and berth world"
	)
	if authority == null or resolver == null or arrow == null or torrent == null or world == null:
		await _clean_up(game)
		_finish()
		return
	var torrent_damageable := torrent.get_node_or_null(
		"AuthoritativeDamageable"
	) as LifecycleDamageableAdapter
	_check(
		torrent_damageable != null,
		"Torrent exposes the retained lifecycle damage adapter used by combat"
	)
	if torrent_damageable == null:
		await _clean_up(game)
		_finish()
		return

	authority.authoritative_shot_submitted.connect(_on_shot_submitted)
	arrow.global_transform = Transform3D(Basis.IDENTITY, OPEN_ARENA)
	var retired_target := _make_target(
		game,
		&"RetiredCombatTarget",
		OPEN_ARENA + Vector3(0.0, 0.0, -16.0),
		48.0
	)
	var recovery_target := _make_target(
		game,
		&"RecoveryCombatTarget",
		OPEN_ARENA + Vector3(16.0, 0.0, 0.0),
		100.0
	)
	await physics_frame

	var first_result := _shoot(authority, arrow, retired_target.body)
	var terminal_result := _shoot(authority, arrow, retired_target.body)
	_check(
		bool(first_result.get("accepted", false))
		and bool(first_result.get("damaged", false))
		and is_equal_approx(retired_target.damageable.get_health(), 0.0)
		and bool(terminal_result.get("destroyed", false)),
		"accepted production fire damages and destroys one authoritative target"
	)
	var retired_target_result := _shoot(authority, arrow, retired_target.body)
	_check(
		bool(retired_target_result.get("accepted", false))
		and bool(retired_target_result.get("hit", false))
		and not bool(retired_target_result.get("damaged", true))
		and retired_target_result.get("status", &"") == &"already_destroyed"
		and is_equal_approx(retired_target.damageable.get_health(), 0.0),
		"a destroyed target stays retired even when its collision remains observable"
	)

	var arrow_instance_id := arrow.get_instance_id()
	var arrow_source_id := authority.get_source_id(arrow)
	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	var pending := game.get("_regeneration_pending") as Dictionary
	_check(
		arrow.is_destroyed()
		and arrow_source_id == 1102
		and pending.has(arrow_instance_id),
		"Arrow destruction synchronously enters one same-instance berth-regeneration lifecycle"
	)

	var recovery_health_before: float = recovery_target.damageable.get_health()
	var request_index := _arrow_requests.size()
	var destroyed_source_result := _shoot(authority, arrow, recovery_target.body)
	var destroyed_epoch_request: ShotRequest = (
		_arrow_requests[request_index]
		if request_index < _arrow_requests.size()
		else null
	)
	_check(
		not bool(destroyed_source_result.get("accepted", true))
		and destroyed_source_result.get("status", &"") == &"source_destroyed"
		and destroyed_epoch_request != null
		and is_equal_approx(recovery_target.damageable.get_health(), recovery_health_before),
		"a destroyed fleet source cannot submit live damage while regeneration is pending"
	)

	var parent := game.get_parent()
	var detached_torrent_hull := float(torrent.get_telemetry().get("hull", -1.0))
	var detached_proxy_context := torrent_damageable.get_last_hit_context()
	parent.remove_child(game)
	await process_frame
	var detached_proxy_damage := torrent_damageable.apply_damage(
		1.0, Vector3.INF, Vector3.ZERO, {}
	)
	_check(
		resolver.get_registered_source_count() == 0
		and authority.get_source_id(arrow) == 0,
		"whole-Main detach retires every live source registration"
	)
	_check(
		not bool(detached_proxy_damage.get("accepted", true))
		and detached_proxy_damage.get("reason", &"") == &"lifecycle_unavailable"
		and is_equal_approx(float(torrent.get_telemetry().get("hull", -2.0)), detached_torrent_hull)
		and torrent_damageable.get_last_hit_context() == detached_proxy_context,
		"a retained proxy cannot damage or publish hit state for a detached fleet hull"
	)
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		resolver.get_registered_source_count() == 6
		and authority.get_source_id(arrow) == arrow_source_id
		and _connection_count(
			arrow,
			&"destroyed",
			Callable(game, "_on_ship_destroyed").bind(arrow)
		) == 1,
		"re-entry restores six registrations and exactly one destruction signal binding"
	)
	var reentry_torrent_hull := float(torrent.get_telemetry().get("hull", -1.0))
	var reentry_proxy_damage := torrent_damageable.apply_damage(
		1.0, Vector3.INF, Vector3.ZERO, {}
	)
	_check(
		bool(reentry_proxy_damage.get("accepted", false))
		and is_equal_approx(float(reentry_proxy_damage.get("applied_damage", 0.0)), 1.0)
		and is_equal_approx(
			float(torrent.get_telemetry().get("hull", -1.0)), reentry_torrent_hull - 1.0
		),
		"the same retained proxy accepts live damage again after whole-Main re-entry"
	)

	var replay_result := (
		resolver.resolve_hitscan(destroyed_epoch_request)
		if destroyed_epoch_request != null
		else {}
	)
	_check(
		not bool(replay_result.get("accepted", true))
		and replay_result.get("status", &"") in [
			&"duplicate_sequence",
			&"out_of_order_sequence",
		]
		and is_equal_approx(recovery_target.damageable.get_health(), recovery_health_before),
		"the destroyed-source request remains stale after whole-Main re-entry"
	)
	var destroyed_after_reentry := _shoot(authority, arrow, recovery_target.body)
	_check(
		not bool(destroyed_after_reentry.get("accepted", true))
		and destroyed_after_reentry.get("status", &"") == &"source_destroyed"
		and is_equal_approx(recovery_target.damageable.get_health(), recovery_health_before),
		"re-entry does not reactivate a still-destroyed source"
	)

	pending = game.get("_regeneration_pending") as Dictionary
	var entry := (pending.get(arrow_instance_id, {}) as Dictionary).duplicate()
	entry["ready_at_msec"] = Time.get_ticks_msec() - 1
	pending[arrow_instance_id] = entry
	game.set("_regeneration_pending", pending)
	game.call("_update_pending_regeneration", 0.0)
	_check(
		not arrow.is_destroyed()
		and not (game.get("_regeneration_pending") as Dictionary).has(arrow_instance_id)
		and arrow.get_instance_id() == arrow_instance_id
		and arrow.global_transform.is_equal_approx(
			world.get_berth_transform(arrow.get_home_berth_id())
		),
		"berth regeneration restores the exact physical Arrow and retires its deadline"
	)

	arrow.global_transform = Transform3D(Basis.IDENTITY, OPEN_ARENA)
	await physics_frame
	var recovered_result := _shoot(authority, arrow, recovery_target.body)
	_check(
		bool(recovered_result.get("accepted", false))
		and bool(recovered_result.get("damaged", false))
		and recovered_result.get("target_entity") == recovery_target.body
		and recovery_target.damageable.get_health() < recovery_health_before,
		"same-instance recovery opens a fresh live submission after the retired epoch"
	)

	await _clean_up(game)
	_finish()


func _make_target(
	game: Node,
	target_name: StringName,
	world_position: Vector3,
	maximum_health: float
	) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = target_name
	body.collision_layer = PhysicsLayers.TARGET
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	shape_node.shape = shape
	body.add_child(shape_node)
	var damageable := Damageable.new()
	damageable.name = "Damageable"
	damageable.maximum_health = maximum_health
	damageable.faction_id = &"lifecycle_test_target"
	body.add_child(damageable)
	game.add_child(body)
	body.global_position = world_position
	return {
		"body": body,
		"damageable": damageable,
	}


func _shoot(
	authority: LiveCombatAuthority,
	source: Node3D,
	target: Node3D
	) -> Dictionary:
	var origin := source.global_position
	return authority.submit_hitscan(
		source,
		WEAPON_ID,
		origin,
		(target.global_position - origin).normalized()
	)


func _on_shot_submitted(request: ShotRequest, _result: Dictionary) -> void:
	if is_instance_valid(request.source_entity) \
		and request.source_entity.name == &"ArrowReconShip":
		_arrow_requests.append(request)


func _connection_count(source: Object, signal_name: StringName, callback: Callable) -> int:
	var count := 0
	for connection: Dictionary in source.get_signal_connection_list(signal_name):
		if connection.get("callable") == callback:
			count += 1
	return count


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
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
		print("COMBAT_DESTRUCTION_RECOVERY_LIFECYCLE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"COMBAT_DESTRUCTION_RECOVERY_LIFECYCLE_TEST_FAILED: %s"
			% "; ".join(_failures)
		)
		quit(1)
