extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const AUDITED_ENCOUNTER_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(90.0, 0.0, -10.0)
)
const ACTIVITY_BOARD_TRANSFORM := Transform3D(
	Basis.IDENTITY, Vector3(12.0, 1.0, -26.0)
)

var _assertions := 0
var _failures: Array[String] = []


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
		and authority.get_resolver().get_registered_source_count() == 3,
		"embodied board interaction starts the externally combat-owned encounter and its first authored wave"
	)

	var content_id := content.get_instance_id()
	var board_id: int = board.get_instance_id()
	var content_generation := content.get_generation()
	production_root.remove_child(world)
	await process_frame
	_check(
		not content.is_inside_tree()
		and authority.get_resolver().get_registered_source_count() == 0,
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
		and authority.get_resolver().get_registered_source_count() == 3
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
