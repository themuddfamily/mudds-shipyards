extends Node

## Read-only exported-game telemetry. No input, actor writes, gameplay actions,
## timing overrides, or process shutdown: the external OS-input driver owns those.
var _game: GameFlow
var _player: PlayerController
var _ship: HeroShip
var _opponent: RangeOpponent
var _spawn := Vector3.ZERO
var _parked := Transform3D.IDENTITY
var _tuning := {}
var _elapsed := 0.0


func on_startup_completed(main: Node) -> void:
	if _game != null or not main is GameFlow or get_parent().call("get_main") != main:
		return
	_game = main as GameFlow
	_player = _game.get_node("Player") as PlayerController
	_ship = _game.get_node("TorrentInterceptor") as HeroShip
	_opponent = _game.get_node("RangeOpponent") as RangeOpponent
	_spawn = _player.global_position
	_parked = _ship.global_transform
	_tuning = _sortie_tuning()


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _sortie_tuning() -> Dictionary:
	return {"canopy": _game.canopy_motion_time, "boarding": _game.boarding_motion_time,
		"exit": _game.disembarking_motion_time, "cooldown": _ship.weapon_cooldown,
		"maximum_speed": _ship.maximum_speed, "thrust": _ship.thrust_acceleration,
		"brake": _ship.brake_acceleration, "drag": _ship.passive_drag,
		"response": _ship.throttle_response, "yaw": _ship.yaw_speed_degrees,
		"assist": _ship.flight_assist_strength, "mouse": _ship.mouse_sensitivity}


func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_elapsed += delta
	if _elapsed < 1.0 / 60.0:
		return
	_elapsed = 0.0
	var targets: Array = []
	for target: Node in get_tree().get_nodes_in_group("shipyard_targets"):
		if target is Node3D and not bool(target.get_meta("destroyed", false)):
			targets.append({"name": str(target.name), "position": _v((target as Node3D).global_position)})
	var source := _ship.get_local_input_source()
	var berth := _game.world.get_berth_node(_ship.get_home_berth_id()) as ShipBerth
	var camera_yaw := _player.get_node("CameraYaw") as Node3D
	var command := _ship.get_last_ship_command()
	var shot := _game.get_last_player_shot_result()
	var capture := _game.world.get_landing_assist_report(_ship, _ship.get_home_berth_id())
	var contract := _ship.get_landing_contract_report()
	print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify({
		"frame": Engine.get_physics_frames(), "phase": GameFlow.Phase.keys()[_game.phase],
		"menu_ready": StartupLoader.is_title_menu_ready(_game) and not is_instance_valid(get_parent().call("get_loading_screen")),
		"player_id": _player.get_instance_id(), "ship_id": _ship.get_instance_id(),
		"player": _v(_player.global_position), "spawn": _v(_spawn),
		"walk_offset": _v(_ship.get_boarding_position() - _player.get_interaction_origin()),
		"walk_forward": _v(-camera_yaw.global_basis.z), "walk_right": _v(camera_yaw.global_basis.x),
		"candidate": _game.boarding_candidate == _ship, "seated": _player.is_seated(),
		"control_enabled": _player.is_control_enabled(), "piloted": _ship.is_piloted(),
		"active_ship": _game.get_active_ship() == _ship, "position": _v(_ship.global_position),
		"parked": _v(_parked.origin), "velocity": _v(_ship.velocity),
		"right": _v(_ship.global_basis.x), "up": _v(_ship.global_basis.y), "back": _v(_ship.global_basis.z),
		"camera": _v(_ship.get_camera().global_position), "targets": targets,
		"opponent_active": _opponent.is_active(), "opponent": _v(_opponent.global_position),
		"opponent_health": _opponent.get_health(), "opponent_velocity": _v(_opponent.velocity),
		"destroyed_targets": _game.world.get_destroyed_target_count(), "destroyed": _ship.is_destroyed(),
		"telemetry": {"engine": _ship.get_telemetry().get("engine_state"), "hull": _ship.get_telemetry().get("hull")},
		"default_sampler": source != null and source.get_input_provider() == null,
		"tuning_unchanged": _sortie_tuning() == _tuning, "tuning": _tuning,
		"landed": _ship.get_telemetry().get("landed"), "landing_active": _ship.is_landing_active(),
		"capture": bool(capture.get("assist_capture_accepted", false)),
		"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false)) and contract.get("berth_id", &"") == _ship.get_home_berth_id(),
		"lease": berth.get_occupant() == _ship and berth.get_reservation_owner() == _ship and berth.get_reserved_ship_id() == _ship.get_ship_definition().ship_id,
		"lease_free": berth.get_occupant() == null and berth.get_reservation_owner() == null,
		"parked_exact": _ship.global_transform.is_equal_approx(_parked),
		"exit_error": _player.global_position.distance_to(_ship.get_exit_transform().origin),
		"guided_complete": _game.is_guided_activity_complete(), "upright": _ship.global_basis.y.dot(Vector3.UP),
		"shot_accepted": bool(shot.get("accepted", false)) and bool(shot.get("resolved", false)) and shot.get("source_entity") == _ship,
		"command_fire": command.fire if command != null else false,
	}))
