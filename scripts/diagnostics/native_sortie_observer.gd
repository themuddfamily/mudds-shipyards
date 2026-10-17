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
var _sandbox := false
var _full_sandbox := false
var _hulk_arrival := false
var _hulk_breaker := false
var _hulk_home := false
var _fleet_initial := {}
var _crash_surface := {}
var _fleet_details := {}


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
	_hulk_home = "--native-sortie-observer=hulk-home" in OS.get_cmdline_args()
	_hulk_breaker = "--native-sortie-observer=hulk-breaker" in OS.get_cmdline_args() or _hulk_home
	_hulk_arrival = "--native-sortie-observer=hulk-arrival" in OS.get_cmdline_args() or _hulk_breaker
	_full_sandbox = "--native-sortie-observer=sandbox" in OS.get_cmdline_args()
	_sandbox = "--native-sortie-observer=sandbox-walk" in OS.get_cmdline_args() or "--native-sortie-observer=sandbox" in OS.get_cmdline_args()
	if _sandbox:
		for craft: HeroShip in _game.get_flyable_ships():
			_fleet_initial[str(craft.get_ship_id())] = {
				"pose": craft.global_transform, "tuning": _craft_tuning(craft)}


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _sortie_tuning() -> Dictionary:
	return _craft_tuning(_ship)


func _craft_tuning(craft: HeroShip) -> Dictionary:
	return {"canopy": _game.canopy_motion_time, "boarding": _game.boarding_motion_time,
		"exit": _game.disembarking_motion_time, "cooldown": craft.weapon_cooldown,
		"maximum_speed": craft.maximum_speed, "thrust": craft.thrust_acceleration,
		"brake": craft.brake_acceleration, "drag": craft.passive_drag,
		"response": craft.throttle_response, "yaw": craft.yaw_speed_degrees,
		"assist": craft.flight_assist_strength, "mouse": craft.mouse_sensitivity,
		"boost_speed": craft.boost_speed, "boost_multiplier": craft.boost_multiplier,
		"maximum_hull": craft.maximum_hull, "impact_threshold": craft.impact_damage_threshold,
		"impact_scale": craft.impact_damage_scale, "impact_cooldown": craft.impact_damage_cooldown}


func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_elapsed += delta
	if _elapsed < 1.0 / (20.0 if _full_sandbox else 60.0):
		return
	_elapsed = 0.0
	var targets: Array = []
	for target: Node in get_tree().get_nodes_in_group("shipyard_targets"):
		if target is Node3D and not bool(target.get_meta("destroyed", false)):
			targets.append({"name": str(target.name), "position": _v((target as Node3D).global_position)})
	var source := _ship.get_local_input_source()
	var berth := _game.world.get_berth_node(_ship.get_home_berth_id()) as ShipBerth
	var camera_yaw := _player.get_node("%CameraYaw") as Node3D
	var command := _ship.get_last_ship_command()
	var shot := _game.get_last_player_shot_result()
	var capture: Dictionary = _game.world.get_landing_assist_report(_ship, _ship.get_home_berth_id())
	var contract := _ship.get_landing_contract_report()
	var observation := {
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
		"default_sampler": source != null and _ship.get("_command_source") == source and source.get_input_provider() == null,
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
		"command_interact": command.interact if command != null else false,
		"native_interact": Input.is_action_pressed("interact"),
		"source_enabled": source.is_enabled_owner() if source != null else false,
		"application_focused": source.get("_application_focused") if source != null else false,
		"transition_busy": _game.get("_transition_busy"),
	}
	if _hulk_arrival:
		observation["hulk"] = _hulk_arrival_observation()
	if _hulk_home:
		observation["hulk_home"] = _hulk_home_observation(berth)
	if _sandbox:
		observation["sandbox"] = _sandbox_observation()
	print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(observation))


func _sandbox_observation() -> Dictionary:
	var fleet: Dictionary = {}
	for craft: HeroShip in _game.get_flyable_ships():
		var key := str(craft.get_ship_id())
		if not _fleet_initial.has(key):
			continue
		var initial: Dictionary = _fleet_initial[key]
		if _full_sandbox and key == "cinder_light_interceptor" and _crash_surface.is_empty():
			# Observe an existing physical crash surface over the craft's own
			# soon-vacated pad. The ray excludes only that hull and the avatar.
			var parked: Vector3 = (initial.pose as Transform3D).origin
			var ray := PhysicsRayQueryParameters3D.create(parked + Vector3.UP * 220.0,
				parked - Vector3.UP * 20.0, craft.collision_mask, [craft.get_rid(), _player.get_rid()])
			var hit := craft.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():
				_crash_surface = {"position": _v(hit.position), "normal": _v(hit.normal),
					"collider": str((hit.collider as Node).get_path())}
		var source := craft.get_local_input_source()
		if not _full_sandbox:
			fleet[key] = {
				"ship_id": craft.get_instance_id(), "piloted": craft.is_piloted(),
				"destroyed": craft.is_destroyed(),
				"parked_exact": craft.global_transform.is_equal_approx(initial.pose),
				"default_sampler": source != null and craft.get("_command_source") == source and source.get_input_provider() == null,
				"tuning_unchanged": _craft_tuning(craft) == initial.tuning,
			}
			continue
		if _fleet_details.has(key) and _game.get_active_ship() != craft:
			# Inactive, exactly parked hulls need no repeated expensive cockpit
			# telemetry/capture calculation. Live safety and identity are still
			# observed; an active sortie always gets a fresh full snapshot.
			fleet[key] = (_fleet_details[key] as Dictionary).duplicate()
			fleet[key].merge({"ship_id": craft.get_instance_id(), "piloted": craft.is_piloted(),
				"active_ship": false, "details_current": false, "destroyed": craft.is_destroyed(),
				"parked_exact": craft.global_transform.is_equal_approx(initial.pose),
				"candidate": _game.boarding_candidate == craft,
				"default_sampler": source != null and craft.get("_command_source") == source and source.get_input_provider() == null,
				"tuning_unchanged": _craft_tuning(craft) == initial.tuning}, true)
			continue
		var berth := _game.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
		var capture: Dictionary = _game.world.get_landing_assist_report(craft, craft.get_home_berth_id())
		var contract := craft.get_landing_contract_report()
		var telemetry := craft.get_telemetry()
		var command := craft.get_last_ship_command()
		fleet[key] = {
			"ship_id": craft.get_instance_id(), "piloted": craft.is_piloted(),
			"destroyed": craft.is_destroyed(), "active_ship": _game.get_active_ship() == craft, "details_current": true,
			"parked_exact": craft.global_transform.is_equal_approx(initial.pose),
			"position": _v(craft.global_position), "parked": _v((initial.pose as Transform3D).origin),
			"velocity": _v(craft.velocity), "right": _v(craft.global_basis.x),
			"up": _v(craft.global_basis.y), "back": _v(craft.global_basis.z),
			"parked_forward": _v(-(initial.pose as Transform3D).basis.z),
			"camera": _v(craft.get_camera().global_position),
			"boarding": _v(craft.get_boarding_position()),
			"walk_offset": _v(craft.get_boarding_position() - _player.get_interaction_origin()),
			"exit": _v(craft.get_exit_transform().origin),
			"candidate": _game.boarding_candidate == craft,
			"landed": telemetry.get("landed"), "telemetry": {
				"engine": telemetry.get("engine_state"), "hull": telemetry.get("hull")},
			"landing_active": craft.is_landing_active(), "upright": craft.global_basis.y.dot(Vector3.UP),
			"capture": bool(capture.get("assist_capture_accepted", false)),
			"capture_position": _v(berth.get_assist_capture_transform().origin),
			"departure_lift": berth.get_departure_lift_height(),
			"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false)) and contract.get("berth_id", &"") == craft.get_home_berth_id(),
			"lease": berth.get_occupant() == craft and berth.get_reservation_owner() == craft and berth.get_reserved_ship_id() == craft.get_ship_definition().ship_id,
			"lease_free": berth.get_occupant() == null and berth.get_reservation_owner() == null,
			"regeneration_pending": (_game.get("_regeneration_pending") as Dictionary).has(craft.get_instance_id()),
			"command_throttle": command.throttle if command != null else 0.0,
			"command_boost": command.boost if command != null else false,
			"default_sampler": source != null and craft.get("_command_source") == source and source.get_input_provider() == null,
			"tuning_unchanged": _craft_tuning(craft) == initial.tuning, "tuning": initial.tuning,
		}
		_fleet_details[key] = fleet[key]
	var doors: Array = []
	var door := _game.world.get_node(^"HabitatSpine/MainAccess") as StationDoor
	doors.append({"position": _v(door.global_position), "open": door.is_open(),
		"candidate": _game.station_interaction_candidate == door})
	var station_candidate := {}
	if _full_sandbox and is_instance_valid(_game.station_interaction_candidate):
		station_candidate = {"position": _v(_game.station_interaction_candidate.global_position),
			"path": str(_game.station_interaction_candidate.get_path())}
	return {"fleet": fleet, "doors": doors, "station_candidate": station_candidate,
		"crash_surface": _crash_surface, "grounded": _player.is_on_floor(),
		"walk_mouse": _player.mouse_sensitivity}


func _hulk_arrival_observation() -> Dictionary:
	# Before streaming, this authored station-relative goal only guides OS
	# flight. Once resident, the live berth supplies its exact capture centre.
	var dock_local := Transform3D(Basis(Vector3.UP, PI),
		AbandonedStationHulk.BERTH_LOCAL_POSITION + Vector3.UP * AbandonedStationHulk.BERTH_DOCK_HEIGHT)
	var approach: Vector3 = _game.world.to_global(AbandonedStationHulk.HULK_ANCHOR
		+ dock_local * AbandonedStationHulk.BERTH_ASSIST_CAPTURE_CENTER)
	var result := {"available": false, "approach": _v(approach)}
	var cluster: NearbySectorCluster = _game.world.call("get_nearby_sector_cluster") as NearbySectorCluster
	if not is_instance_valid(cluster):
		return result
	var hulk: AbandonedStationHulk = cluster.get_station_hulk()
	var berth: ShipBerth = _game.get_station_hulk_berth()
	if not is_instance_valid(hulk) or not is_instance_valid(berth) or not berth.is_inside_tree():
		return result
	var capture := _game.call("_get_active_landing_assist_report") as Dictionary
	var contract := _ship.get_landing_contract_report()
	var support := {}
	if not _player.is_seated():
		var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.2,
			_player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD)
		support = _player.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider := support.get("collider") as Node
	var occupant := berth.get_occupant()
	result.merge({"available": true, "hulk_id": hulk.get_instance_id(),
		"berth_id": str(berth.get_berth_id()), "berth_instance_id": berth.get_instance_id(),
		"approach": _v(berth.get_assist_capture_transform().origin),
		"dock": _v(berth.get_dock_transform().origin),
		"dock_forward": _v(-berth.get_dock_transform().basis.z),
		"selected_berth_id": str(capture.get("selected_berth_id", &"")),
		"capture": bool(capture.get("assist_capture_accepted", false)) and bool(capture.get("streamed_destination", false)),
		"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false))
			and bool(contract.get("reservation_token_bound", false)) and contract.get("berth_id", &"") == berth.get_berth_id()
			and int(contract.get("berth_instance_id", 0)) == berth.get_instance_id(),
		"lease": occupant == _ship and berth.get_reservation_owner() == _ship
			and berth.get_reserved_ship_id() == _ship.get_ship_definition().ship_id,
		"lease_free": occupant == null and berth.get_reservation_owner() == null
			and berth.get_reserved_ship_id() == &"",
		"occupant_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
		"parked_exact": _ship.global_transform.is_equal_approx(berth.get_dock_transform()),
		"landing_abort_reason": str(contract.get("last_abort_reason", &"")),
		"grounded": _player.is_on_floor(),
		"shelf_supported": is_instance_valid(collider) and collider == hulk.get_node_or_null(^"Exterior/DockShelf"),
		"support_collider": str(hulk.get_path_to(collider)) if is_instance_valid(collider) and hulk.is_ancestor_of(collider) else "",
	}, true)
	if _hulk_breaker:
		result["interior"] = _hulk_breaker_observation(hulk, collider)
	return result


func _hulk_breaker_observation(hulk: AbandonedStationHulk, support_collider: Node) -> Dictionary:
	var route: Array = []
	for point: Vector3 in hulk.get_interior_route_points():
		route.append(_v(point))
	var breaker: Area3D = hulk.get_breaker()
	var capsule: CollisionShape3D = _player.get_node(^"PlayerCollision") as CollisionShape3D
	var activity: Dictionary = _game.get_hulk_power_restoration_snapshot()
	var reward_report: Dictionary = _game.get_activity_reward_report()
	var authority: Dictionary = reward_report.get("authority", {}) as Dictionary
	var record: Dictionary = authority.get("record", {}) as Dictionary
	var counts: Dictionary = record.get("reward_counts", {}) as Dictionary
	var last_breaker_result: Dictionary = _game.get("_last_hulk_power_result") as Dictionary
	var lights: Array = []
	var restored_interiors: int = 0
	var emergency_interiors: int = 0
	var dock_lights: int = 0
	for light: OmniLight3D in hulk.get_light_nodes():
		lights.append({"name": str(light.name), "color": light.light_color.to_html(false),
			"energy": light.light_energy, "range": light.omni_range, "attenuation": light.omni_attenuation})
		if light.name == &"DockShelfPractical":
			if light.light_color.is_equal_approx(AbandonedStationHulk.DOCK_CYAN) and light.light_energy < 1.0:
				dock_lights += 1
		elif light.light_color.is_equal_approx(AbandonedStationHulk.RESTORED_BUS_COLOR) \
				and is_equal_approx(light.light_energy, AbandonedStationHulk.RESTORED_PRACTICAL_ENERGY) \
				and is_equal_approx(light.omni_range, AbandonedStationHulk.RESTORED_PRACTICAL_RANGE) \
				and is_equal_approx(light.omni_attenuation, AbandonedStationHulk.RESTORED_PRACTICAL_ATTENUATION):
			restored_interiors += 1
		elif not light.light_color.is_equal_approx(AbandonedStationHulk.RESTORED_BUS_COLOR) \
				and light.light_energy <= 1.0 and is_equal_approx(light.omni_range, AbandonedStationHulk.PRACTICAL_RANGE) \
				and is_equal_approx(light.omni_attenuation, AbandonedStationHulk.EMERGENCY_PRACTICAL_ATTENUATION):
			emergency_interiors += 1
	return {"route": route, "space_ids": AbandonedStationHulk.SPACE_IDS,
		"support_owned": is_instance_valid(support_collider) and hulk.is_ancestor_of(support_collider),
		"capsule_id": capsule.get_instance_id(), "shape_id": capsule.shape.get_instance_id(),
		"capsule_enabled": not capsule.disabled, "player_velocity": _v(_player.velocity),
		"walk_tuning": {"walk": _player.walk_speed, "sprint": _player.sprint_speed,
			"deceleration": _player.ground_deceleration, "mouse": _player.mouse_sensitivity},
		"physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale,
		"breaker_id": breaker.get_instance_id(), "breaker_position": _v(breaker.global_position),
		"breaker_candidate": _game.station_interaction_candidate == breaker,
		"breaker_engaged": bool(breaker.call("is_engaged")),
		"last_breaker_result": last_breaker_result,
		"activity": activity, "reward_count": int(counts.get("hulk_auxiliary_power_cell", 0)),
		"reward_receipt": record.get("last_receipt", {}),
		"power_restored": hulk.is_auxiliary_power_restored(), "lights": lights,
		"bus_lights_restored": restored_interiors == 7 and dock_lights == 1 and lights.size() == 8,
		"emergency_lights": emergency_interiors == 7 and dock_lights == 1 and lights.size() == 8}


## Select-only return observations survive retirement of the streamed HULK.
## Read existing owners directly: no scene loads, policy ticks, reconciliation,
## activity mutations, actor placement, or synthetic gameplay input.
func _hulk_home_observation(home_berth: ShipBerth) -> Dictionary:
	var capsule: CollisionShape3D = _player.get_node(^"PlayerCollision") as CollisionShape3D
	var activity: Dictionary = _game.get_hulk_power_restoration_snapshot()
	var reward_report: Dictionary = _game.get_activity_reward_report()
	var authority: Dictionary = reward_report.get("authority", {}) as Dictionary
	var record: Dictionary = authority.get("record", {}) as Dictionary
	var counts: Dictionary = record.get("reward_counts", {}) as Dictionary
	var bootstrap: CinderStreamingBootstrap = _game.get_node(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	var binding: CinderStreamingProductionBinding = _game.get_node(^"CinderStreamingProductionBinding") as CinderStreamingProductionBinding
	var coordinator: WorldStreamingCoordinator = bootstrap.get_node(^"WorldStreamingCoordinator") as WorldStreamingCoordinator
	var generations: Dictionary = coordinator.get("_generation_by_id") as Dictionary
	var loaded: Dictionary = coordinator.get("_loaded") as Dictionary
	var loading: Dictionary = coordinator.get("_loading") as Dictionary
	var loaded_record: Dictionary = loaded.get(CinderStreamingBootstrap.LOCATION_ID, {}) as Dictionary
	var cluster: Node3D = loaded_record.get("instance") as Node3D
	var presentation: Dictionary = binding.get("_last_presentation_result") as Dictionary
	var capture: Dictionary = _game.call("_get_active_landing_assist_report") as Dictionary
	var contract: Dictionary = _ship.get_landing_contract_report()
	var support: Dictionary = {}
	if not _player.is_seated():
		var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.2,
			_player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD)
		support = _player.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider: Node = support.get("collider") as Node
	var station_candidate: Node3D = _game.station_interaction_candidate
	var home_occupant: Node = home_berth.get_occupant()
	var anchor: Vector3 = bootstrap.to_global(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	return {
		"activity": activity, "reward_count": int(counts.get("hulk_auxiliary_power_cell", 0)),
		"reward_receipt": record.get("last_receipt", {}),
		"capsule_id": capsule.get_instance_id(), "shape_id": capsule.shape.get_instance_id(),
		"capsule_enabled": not capsule.disabled, "player_velocity": _v(_player.velocity),
		"walk_tuning": {"walk": _player.walk_speed, "sprint": _player.sprint_speed,
			"deceleration": _player.ground_deceleration, "mouse": _player.mouse_sensitivity},
		"physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale,
		"boarding": _v(_ship.get_boarding_position()),
		"station_candidate": str(station_candidate.get_path()) if is_instance_valid(station_candidate) else "",
		"streaming": {
			"loaded": is_instance_valid(cluster) and cluster.is_inside_tree() and not cluster.is_queued_for_deletion(),
			"loaded_instance_id": cluster.get_instance_id() if is_instance_valid(cluster) else 0,
			"loaded_generation": int(loaded_record.get("generation", -1)),
			"generation": int(generations.get(CinderStreamingBootstrap.LOCATION_ID, -1)),
			"loading": loading.has(CinderStreamingBootstrap.LOCATION_ID),
			"load_request_count": int(coordinator.get("_load_request_count")),
			"load_failure_count": int(coordinator.get("_load_failure_count")),
			"unload_count": int(coordinator.get("_unload_count")),
			"presentation": presentation.duplicate(true),
			"distance_m": _ship.global_position.distance_to(anchor),
			"unload_radius_m": CinderStreamingBootstrap.UNLOAD_RADIUS_METERS,
		},
		"home": {
			"berth_id": str(home_berth.get_berth_id()), "berth_instance_id": home_berth.get_instance_id(),
			"approach": _v(_game.world.to_global(Vector3(0, 2, -18))),
			"dock": _v(home_berth.get_dock_transform().origin),
			"dock_forward": _v(-home_berth.get_dock_transform().basis.z),
			"selected_berth_id": str(capture.get("selected_berth_id", &"")),
			"capture": bool(capture.get("assist_capture_accepted", false)),
			"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false))
				and bool(contract.get("reservation_token_bound", false)) and contract.get("berth_id", &"") == home_berth.get_berth_id()
				and int(contract.get("berth_instance_id", 0)) == home_berth.get_instance_id(),
			"landing_abort_reason": str(contract.get("last_abort_reason", &"")),
			"lease": home_occupant == _ship and home_berth.get_reservation_owner() == _ship
				and home_berth.get_reserved_ship_id() == _ship.get_ship_definition().ship_id,
			"occupant_id": home_occupant.get_instance_id() if is_instance_valid(home_occupant) else 0,
			"parked_exact": _ship.global_transform.is_equal_approx(home_berth.get_dock_transform()),
			"grounded": _player.is_on_floor(),
			"supported": is_instance_valid(collider) and _game.world.is_ancestor_of(collider),
			"support_collider": str(_game.world.get_path_to(collider)) if is_instance_valid(collider) and _game.world.is_ancestor_of(collider) else "",
		},
	}
