extends Node

## Read-only exported-game telemetry. No input, actor writes, gameplay actions,
## timing overrides, or process shutdown: the external OS-input driver owns those.
var _game: GameFlow
const LIFE_ROUTES := {
	"life-tow": {"ship": ^"TorrentInterceptor",
		"activity": ^"OperationalLattice/Activities/CentralTowServiceActivity",
		"movers": ["_gantry_carriage", "_gantry_tool", "_service_arm_shoulder", "_service_arm_elbow", "_service_arm_tool"],
		"drones": true, "bounded": false},
	"life-gantry": {"ship": ^"JovianLightFreighter",
		"activity": ^"OperationalLattice/Activities/FreightApproachGantry",
		"movers": ["_gantry_carriage", "_gantry_tool"], "drones": false, "bounded": true},
	"life-arm": {"ship": ^"ZenithInterceptor",
		"activity": ^"OperationalLattice/Activities/AftOperationsActivity",
		"movers": ["_service_arm_shoulder", "_service_arm_elbow", "_service_arm_tool"],
		"drones": false, "bounded": true},
	"life-patrol": {"ship": ^"TorrentInterceptor",
		"activity": ^"OperationalLattice/Activities/HabitatServicePatrol",
		"movers": [], "drones": true, "bounded": true,
		"door": ^"HabitatSpine/MainAccess"},
}
var _browser_mode := false
var _browser_sequence := 0
var _beacon_entry := false
var _beacon_mode := "beacon-entry"
var _beacon_sequence := 0
var _life_mode := ""
var _life_config: Dictionary = {}
var _habitat_loop := false
var _habitat_restart := false
var _restart_sequence: int = 0
var _ember := false
var _ember_started := false
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
	if _ember:
		if main is GameFlow and get_parent().call("get_main") == main:
			_game = main as GameFlow
			_ember_started = true
		return
	if _game != null or not main is GameFlow or get_parent().call("get_main") != main:
		return
	_game = main as GameFlow
	_player = _game.get_node("Player") as PlayerController
	_spawn = _player.global_position
	_browser_mode = "--native-sortie-observer=browser-unreachable" in OS.get_cmdline_args()
	if _browser_mode:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	_beacon_mode = "beacon-settlement" if "--native-sortie-observer=beacon-settlement" in OS.get_cmdline_args() else "beacon-entry"
	_beacon_entry = "--native-sortie-observer=" + _beacon_mode in OS.get_cmdline_args()
	if _beacon_entry:
		process_mode = Node.PROCESS_MODE_ALWAYS
	_habitat_restart = "--native-sortie-observer=habitat-restart" in OS.get_cmdline_args()
	_habitat_loop = "--native-sortie-observer=habitat-loop" in OS.get_cmdline_args()
	if _habitat_restart:
		# Only this diagnostic node remains readable while the production tree pauses.
		process_mode = Node.PROCESS_MODE_ALWAYS
	if _habitat_loop or _habitat_restart:
		return
	for mode: String in LIFE_ROUTES:
		if "--native-sortie-observer=" + mode in OS.get_cmdline_args():
			_life_mode = mode
			_life_config = LIFE_ROUTES[mode]
	_ship = _game.get_node(_life_config.get("ship", ^"TorrentInterceptor")) as HeroShip
	if not _life_config.is_empty():
		if bool(_life_config.bounded):
			_parked = _ship.global_transform
		_tuning = _sortie_tuning()
		return
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


## All poses below are live common-world coordinates from this one sample.
## Never use the legacy Torrent reference, retained startup poses, or a Host's
## retained actor pose as a substitute for the actual active craft.
func _ember_observation() -> Dictionary:
	var result := {"mode": "ember", "frame": Engine.get_physics_frames(),
		"main_current": false, "world_available": false, "actors_available": false, "menu_ready": false,
		"coordinate_space": "common_world", "main_id": 0,
		"world_origin_transaction_count": -1, "player": {}, "ship": {},
		"ember": {"loaded": false, "loaded_instance_id": 0, "host": {}, "abandon": {}},
		"home": {}, "return": {}}
	var owner := get_parent()
	if not is_instance_valid(_game) or not _game.is_inside_tree() \
			or _game.is_queued_for_deletion() or not is_instance_valid(owner) \
			or not owner.has_method("get_main") or owner.call("get_main") != _game:
		return result
	result.main_current = true
	result.main_id = _game.get_instance_id()
	result.menu_ready = StartupLoader.is_title_menu_ready(_game) and owner.has_method("get_loading_screen") \
		and not is_instance_valid(owner.call("get_loading_screen"))
	result["phase"] = GameFlow.Phase.keys()[_game.phase]
	if not _ember_node_current(_game.world):
		return result
	result.world_available = true
	var origin := _game.common_world_origin_rebase_owner
	if _ember_node_current(origin):
		result.world_origin_transaction_count = int(origin.get_snapshot().get("transaction_count", 0))
	var bootstrap := _game.ember_streaming_bootstrap
	var loaded: Node3D
	if _ember_node_current(bootstrap) and bool(bootstrap.get("_configured")):
		# The bootstrap's loaded-instance and generation getters reconcile the
		# coordinator. Inspect its existing records without advancing streaming.
		var coordinator := bootstrap.get("_coordinator") as WorldStreamingCoordinator
		if _ember_node_current(coordinator):
			var records := coordinator.get("_loaded") as Dictionary
			var generations := coordinator.get("_generation_by_id") as Dictionary
			var record := records.get(EmberMoonStreamingBootstrap.LOCATION_ID, {}) as Dictionary
			var generation := int(generations.get(EmberMoonStreamingBootstrap.LOCATION_ID, -1))
			result.ember["location_generation"] = generation
			var candidate: Variant = record.get("instance")
			if is_instance_valid(candidate) and candidate is Node3D \
					and candidate.get_parent() == coordinator and int(record.get("generation", -1)) == generation:
				loaded = candidate as Node3D
		var frame := bootstrap.get_coordinate_frame_for_session()
		result.ember["coordinate_frame_generation"] = frame.get_generation() if frame != null else -1
	if _ember_node_current(loaded):
		result.ember.loaded = true
		result.ember.loaded_instance_id = loaded.get_instance_id()
	var host := _game.ember_surface_loop_host
	if _ember_node_current(host):
		# This lightweight production snapshot avoids the full Host audit's
		# bootstrap, telemetry and physics calculations on every observer tick.
		var status := host.get_return_status_snapshot()
		result.ember.host = {"instance_id": host.get_instance_id(),
			"attached": status.get("attached", false), "phase_id": str(status.get("phase_id", &"")),
			"generation": status.get("generation", -1),
			"attachment_generation": status.get("attachment_generation", -1),
			"terminal_reason": str(status.get("terminal_reason", &"")),
			"identities": (status.get("identities", {}) as Dictionary).duplicate(true)}
		result.ember.abandon = host.get_abandon_snapshot()
	result["return"] = {
		"approach_active": bool(_game.get("_mudds_return_approach_active")),
		"approach_result": (_game.get("_last_mudds_return_approach_result") as Dictionary).duplicate(true),
		"physical_arrival_required": bool(_game.get("_planetary_return_physical_arrival_required")),
		"physical_arrival_armed": bool(_game.get("_planetary_return_physical_arrival_armed")),
		"physical_arrival_result": (_game.get("_last_planetary_return_physical_arrival_result") as Dictionary).duplicate(true),
		"receipt_consumed": bool(_game.get("_planetary_return_receipt_consumed")),
	}
	var craft := _game.get_active_ship()
	var pilot := _game.player as PlayerController
	if not _ember_node_current(craft) or not _ember_node_current(pilot):
		return result
	result.actors_available = true
	# Exactly one telemetry sample for the current craft. Read the retained
	# landing acceptance directly: the full contract getter cleans stale leases.
	var telemetry := craft.get_telemetry()
	var contract := craft.get("_landing_contract") as Dictionary
	# These existing fields avoid getters that lazily build seats/input owners.
	var source := craft.get("_default_local_command_source") as LocalShipInputSource
	var boarding := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	var seat := craft.get("_pilot_seat_anchor") as Node3D
	var support: Dictionary = {}
	if not pilot.is_seated():
		var ray := PhysicsRayQueryParameters3D.create(pilot.global_position + Vector3.UP * 0.2,
			pilot.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD, [pilot.get_rid(), craft.get_rid()])
		support = pilot.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider := support.get("collider") as Node
	var supported_home := _ember_node_current(collider) and _game.world.is_ancestor_of(collider)
	var supported_ember := _ember_node_current(collider) and _ember_node_current(loaded) and loaded.is_ancestor_of(collider)
	result.player = {"instance_id": pilot.get_instance_id(), "path": str(pilot.get_path()),
		"position": _v(pilot.global_position), "right": _v(pilot.global_basis.x),
		"up": _v(pilot.global_basis.y), "back": _v(pilot.global_basis.z), "velocity": _v(pilot.velocity),
		"seated": pilot.is_seated(), "seated_at_active_craft": is_instance_valid(seat) and pilot.is_seated_at(seat),
		"seat_instance_id": seat.get_instance_id() if is_instance_valid(seat) else 0,
		"boarding_reserved": is_instance_valid(boarding) and bool(boarding.get("_has_reservation"))
			and boarding.get("_reservation_token") == pilot,
		"control_enabled": pilot.is_control_enabled(), "grounded": pilot.is_on_floor(),
		"support_collider_id": collider.get_instance_id() if is_instance_valid(collider) else 0,
		"support_collider": str(collider.get_path()) if _ember_node_current(collider) else "",
		"supported_home": supported_home, "supported_ember": supported_ember}
	result.ship = {"instance_id": craft.get_instance_id(), "definition_id": str(craft.get_ship_id()),
		"path": str(craft.get_path()), "position": _v(craft.global_position),
		"right": _v(craft.global_basis.x), "up": _v(craft.global_basis.y), "back": _v(craft.global_basis.z),
		"velocity": _v(craft.velocity), "piloted": craft.is_piloted(), "destroyed": craft.is_destroyed(),
		"landed": bool(telemetry.get("landed", false)), "engine": str(telemetry.get("engine_state", &"")),
		"landing_active": craft.is_landing_active(), "boarding": _v(craft.get_boarding_position()),
		"exit": _v(craft.get_exit_transform().origin), "candidate": _game.boarding_candidate == craft,
		"default_sampler": is_instance_valid(source) and craft.get("_command_source") == source and source.get_input_provider() == null}
	var home: ShipBerth
	if _game.world.has_method("get_berth_node") and _game.world.has_method("get_landing_assist_report"):
		home = _game.world.call("get_berth_node", craft.get_home_berth_id()) as ShipBerth
	if _ember_node_current(home):
		var capture := _game.world.call("get_landing_assist_report", craft, craft.get_home_berth_id()) as Dictionary
		var occupant := home.get_occupant()
		var reservation_owner := home.get_reservation_owner()
		# The public token/ship-id getters reconcile stale claims. Observing a
		# stale lease must leave its owner, token and weak references untouched.
		var token := StringName(home.get("_reservation_token"))
		var reserved_ship_id := StringName(home.get("_reserved_ship_id"))
		var token_bound := reservation_owner == craft and (occupant == null or occupant == craft) and not token.is_empty() \
			and token == StringName(craft.get("_landing_reservation_token")) \
			and reserved_ship_id == StringName(craft.get("_landing_reserved_ship_id"))
		result.home = {"berth_id": str(home.get_berth_id()), "berth_instance_id": home.get_instance_id(),
			"dock": _v(home.get_dock_transform().origin), "dock_forward": _v(-home.get_dock_transform().basis.z),
			"capture_position": _v(home.get_assist_capture_transform().origin),
			"selected_berth_id": str(capture.get("selected_berth_id", &"")),
			"capture": bool(capture.get("assist_capture_accepted", false)),
			"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false))
				and token_bound and StringName(craft.get("_landing_berth_id")) == home.get_berth_id()
				and int(craft.get("_landing_berth_instance_id")) == home.get_instance_id(),
			"landing_abort_reason": str(craft.get("_landing_last_abort_reason")),
			"lease": occupant == craft and reservation_owner == craft and not token.is_empty() and reserved_ship_id == craft.get_ship_id(),
			"lease_free": occupant == null and reservation_owner == null and token.is_empty() and reserved_ship_id == &"",
			"occupant_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
			"reservation_owner_id": reservation_owner.get_instance_id() if is_instance_valid(reservation_owner) else 0,
			"reservation_token": str(token),
			"reserved_ship_id": str(reserved_ship_id),
			"parked_exact": craft.global_transform.is_equal_approx(home.get_dock_transform()),
			"grounded": pilot.is_on_floor(), "supported": supported_home}
	return result


func _ember_node_current(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion() \
		and _game.is_ancestor_of(node)


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
	if _ember:
		if not _ember_started:
			return
		print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(_ember_observation()))
		return
	if _game == null:
		return
	if _browser_mode:
		_browser_sequence += 1
		print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(_browser_observation()))
		return
	if _beacon_entry:
		_beacon_sequence += 1
		if get_tree().paused:
			var paused_sample := _beacon_entry_observation()
			paused_sample["frame"] = Engine.get_physics_frames()
			paused_sample["player_id"] = _player.get_instance_id()
			paused_sample["ship_id"] = _ship.get_instance_id()
			if _beacon_mode == "beacon-settlement":
				paused_sample["settlement"] = _beacon_settlement_observation()
			print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(paused_sample))
			return
	if _habitat_restart:
		_restart_sequence += 1
		var sample: Dictionary = _habitat_restart_pause_observation() if get_tree().paused else _habitat_restart_observation()
		sample["sequence"] = _restart_sequence
		sample["pid"] = OS.get_process_id()
		print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(sample))
		return
	if not _life_config.is_empty():
		print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(_life_observation()))
		return
	if _habitat_loop:
		print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(_habitat_loop_observation()))
		return
	_elapsed += delta
	if _elapsed < 1.0 / (20.0 if _full_sandbox else 60.0):
		return
	_elapsed = 0.0
	var targets: Array = []
	for target: Node in get_tree().get_nodes_in_group("shipyard_targets"):
		if target is Node3D and not bool(target.get_meta("destroyed", false)):
			targets.append({"name": str(target.name), "position": _v((target as Node3D).global_position)})
	var source := (_ship.get("_default_local_command_source") as LocalShipInputSource) if _beacon_entry else _ship.get_local_input_source()
	var berth := _game.world.get_berth_node(_ship.get_home_berth_id()) as ShipBerth
	var camera_yaw := _player.get_node("%CameraYaw") as Node3D
	var command := _ship.get_last_ship_command()
	var shot := _game.get_last_player_shot_result()
	var capture: Dictionary = {} if _beacon_entry else _game.world.get_landing_assist_report(_ship, _ship.get_home_berth_id())
	var contract := (_ship.get("_landing_contract") as Dictionary).duplicate(true) if _beacon_entry else _ship.get_landing_contract_report()
	if _beacon_entry:
		contract["berth_id"] = _ship.get("_landing_berth_id")
	var reserved_ship_id: StringName = berth.get("_reserved_ship_id") if _beacon_entry else berth.get_reserved_ship_id()
	var telemetry: Dictionary = {"engine_state": _ship.get("_engine_state"), "hull": _ship.get("_hull"), "landed": _ship.get("_landed")} if _beacon_entry else _ship.get_telemetry()
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
		"telemetry": {"engine": telemetry.get("engine_state"), "hull": telemetry.get("hull")},
		"default_sampler": source != null and _ship.get("_command_source") == source and source.get_input_provider() == null,
		"tuning_unchanged": _sortie_tuning() == _tuning, "tuning": _tuning,
		"landed": telemetry.get("landed"), "landing_active": _ship.is_landing_active(),
		"capture": bool(capture.get("assist_capture_accepted", false)),
		"contract": bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false)) and contract.get("berth_id", &"") == _ship.get_home_berth_id(),
		"lease": berth.get_occupant() == _ship and berth.get_reservation_owner() == _ship and reserved_ship_id == _ship.get_ship_definition().ship_id,
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
	if _beacon_entry:
		observation.merge(_beacon_entry_observation())
		if _beacon_mode == "beacon-settlement":
			observation["settlement"] = _beacon_settlement_observation()
	if _hulk_arrival:
		observation["hulk"] = _hulk_arrival_observation()
	if _hulk_home:
		observation["hulk_home"] = _hulk_home_observation(berth)
	if _sandbox:
		observation["sandbox"] = _sandbox_observation()
	print("NATIVE_SORTIE_OBSERVATION: " + JSON.stringify(observation))


## Inspect retained coordinator records and the pure activity snapshot. The
## binding presentation getter reconciles feedback and must not run in telemetry.
## The paused branch deliberately avoids the base ship physics/landing getters.
func _beacon_entry_observation() -> Dictionary:
	var hud := _game.hud as GameHUD
	var focus := get_viewport().gui_get_focus_owner()
	var row := focus.get_parent() if is_instance_valid(focus) else null
	var main_page := hud.get("_pause_main_page") as Control
	var activity_page := hud.get("_activity_selection_page") as Control
	var nearby_page := hud.get("_nearby_activity_page") as Control
	var feedback := hud.get("_nearby_activity_feedback") as Label
	var presenter := hud.get("_nearby_activity_presenter") as RefCounted
	var selected := presenter.call(&"get_snapshot") as Dictionary if is_instance_valid(presenter) else {}
	var first: Vector3 = CinderBeaconTraversalActivity.BEACONS[0]
	var authored: Vector3 = _game._cinder_authored_frame_position(_ship.global_position)
	var beacon := {"available": false, "binding_id": 0, "owner_id": 0,
		"activity_id": str(CinderBeaconTraversalActivity.ACTIVITY_ID),
		"state": -1, "generation": -1, "next_beacon_index": -1,
		"beacon_count": 4, "reward_requested": false,
		"first_world": _v(_game._cinder_authored_frame_to_world(first)),
		"authored_position": _v(authored), "distance_m": authored.distance_to(first),
		"selected_id": str(selected.get("selected_activity", &"")),
		"feedback": feedback.text if is_instance_valid(feedback) else ""}
	var bootstrap := _game.cinder_streaming_bootstrap
	if _ember_node_current(bootstrap) and bool(bootstrap.get("_configured")):
		var coordinator := bootstrap.get("_coordinator") as WorldStreamingCoordinator
		if _ember_node_current(coordinator):
			var records := coordinator.get("_loaded") as Dictionary
			var generations := coordinator.get("_generation_by_id") as Dictionary
			var record := records.get(CinderStreamingBootstrap.LOCATION_ID, {}) as Dictionary
			var cluster: Node = record.get("instance") as Node
			if _ember_node_current(cluster) and cluster.get_parent() == coordinator \
					and int(record.get("generation", -1)) == int(generations.get(CinderStreamingBootstrap.LOCATION_ID, -2)):
				var binding := cluster.get_node_or_null(^"ActivityBinding")
				var activity: RefCounted = binding.get("_beacon_activity") as RefCounted if _ember_node_current(binding) else null
				if is_instance_valid(activity):
					beacon.merge(activity.call(&"get_snapshot") as Dictionary, true)
					beacon.merge({"available": true, "binding_id": binding.get_instance_id(),
						"owner_id": activity.get_instance_id()}, true)
	if _beacon_mode == "beacon-settlement":
		var points: Array = []
		for point: Vector3 in CinderBeaconTraversalActivity.BEACONS:
			points.append(_v(_game._cinder_authored_frame_to_world(point)))
		beacon["beacons_world"] = points
	return {"mode": _beacon_mode, "sequence": _beacon_sequence,
		"pid": OS.get_process_id(), "main_id": _game.get_instance_id(),
		"paused": get_tree().paused, "beacon": beacon,
		"native_keys": {"escape": Input.is_physical_key_pressed(KEY_ESCAPE),
			"tab": Input.is_physical_key_pressed(KEY_TAB), "return": Input.is_physical_key_pressed(KEY_ENTER)},
		"ui": {"main_visible": is_instance_valid(main_page) and main_page.is_visible_in_tree(),
			"activity_visible": is_instance_valid(activity_page) and activity_page.is_visible_in_tree(),
			"nearby_visible": is_instance_valid(nearby_page) and nearby_page.is_visible_in_tree(),
			"focus_path": str(focus.get_path()) if is_instance_valid(focus) else "",
			"focus_name": str(focus.name) if is_instance_valid(focus) else "",
			"focus_text": (focus as Button).text if focus is Button else "",
			"focus_activity": str(row.get_meta(&"activity_id", &"")) if is_instance_valid(row) else "",
			"focus_visible": is_instance_valid(focus) and focus.is_visible_in_tree(),
			"focus_enabled": focus is BaseButton and not (focus as BaseButton).disabled}}


## Pure live snapshots only; the external driver independently reads the real
## primary file. Telemetry neither loads nor commits a store or requests rewards.
func _beacon_settlement_observation() -> Dictionary:
	var store := _game.get("_runtime_settings_user_data_store") as UserDataStore
	var authority := _game.get("_game_flow_reward_authority") as RefCounted
	var payload := store.get_snapshot() if store != null else {}
	var snapshot: Dictionary = authority.call(&"get_snapshot") as Dictionary if is_instance_valid(authority) else {}
	return {"configured": bool(snapshot.get("configured", false)) and store != null,
		"authority_id": authority.get_instance_id() if is_instance_valid(authority) else 0,
		"store_id": store.get_instance_id() if store != null else 0,
		"store": {"path": ProjectSettings.globalize_path(str(store.get("_path"))) if store != null else "",
			"source": str(store.get_loaded_source()) if store != null else "",
			"generation": store.get_generation() if store != null else -1},
		"record": (snapshot.get("record", {}) as Dictionary).duplicate(true),
		"terminal": (payload.get("cinder_beacon_session", {}) as Dictionary).duplicate(true),
		"handoff": (_game.get("_last_cinder_beacon_traversal_reward_result") as Dictionary).duplicate(true)}


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


## This route reads only the live walking/door/bunk owners. In particular it
## never requests fleet telemetry, landing contracts or Habitat dressing audits.
func _habitat_loop_observation() -> Dictionary:
	var owner := get_parent()
	var current: bool = is_instance_valid(_game) and _game.is_inside_tree() and not _game.is_queued_for_deletion() \
		and owner.call("get_main") == _game \
		and _ember_node_current(_player) and _game.player == _player \
		and _ember_node_current(_game.world)
	var result := {"mode": "habitat-loop", "frame": Engine.get_physics_frames(), "actors_current": current}
	if not current:
		return result
	var habitat := _game.world.get_node(^"HabitatSpine") as HabitatSpine
	var door := habitat.get_node(^"MainAccess") as StationDoor
	var bunk := habitat.get_node(^"Structure/PressurizedHabitatCorridor/BunkAlcove01/StationBunkInteraction") as StationBunk
	result.actors_current = _ember_node_current(habitat) and _ember_node_current(door) and _ember_node_current(bunk)
	if not bool(result.actors_current):
		return result
	var yaw := _player.get_node(^"%CameraYaw") as Node3D
	var capsule := _player.get_node(^"PlayerCollision") as CollisionShape3D
	var support: Dictionary = {}
	if not _player.is_seated() and not bool(_game.get("_transition_busy")):
		var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.2,
			_player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD, [_player.get_rid()])
		support = _player.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider := support.get("collider") as Node
	var supported := _ember_node_current(collider) and _game.world.is_ancestor_of(collider)
	var occupant := bunk.get("_occupant") as Node
	var active_seat := _game.get("_active_station_seat") as StationSeat
	result.merge({
		"phase": GameFlow.Phase.keys()[_game.phase],
		"menu_ready": StartupLoader.is_title_menu_ready(_game) and not is_instance_valid(owner.call("get_loading_screen")),
		"main_id": _game.get_instance_id(), "world_id": _game.world.get_instance_id(),
		"player_id": _player.get_instance_id(), "player": _v(_player.global_position),
		"position": _v(_player.global_position), "spawn": _v(_spawn),
		"walk_forward": _v(-yaw.global_basis.z), "walk_right": _v(yaw.global_basis.x),
		"velocity": _v(_player.velocity), "interaction_origin": _v(_player.get_interaction_origin()),
		"control_enabled": _player.is_control_enabled(), "seated": _player.is_seated(),
		"sleeping": _player.is_sleeping(), "station_seated": _player.is_station_seated(),
		"game_station_seated": bool(_game.get("_station_seated")),
		"transition_busy": bool(_game.get("_transition_busy")),
		"native_interact": Input.is_action_pressed("interact"),
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"grounded": _player.is_on_floor(), "supported": supported,
		"support_collider": str(collider.get_path()) if supported else "",
		"capsule_id": capsule.get_instance_id(), "shape_id": capsule.shape.get_instance_id(),
		"capsule_enabled": not capsule.disabled,
		"walk_tuning": {"walk": _player.walk_speed, "sprint": _player.sprint_speed,
			"deceleration": _player.ground_deceleration, "mouse": _player.mouse_sensitivity},
		"physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale,
		"door": {"id": door.get_instance_id(), "position": _v(door.global_position),
			"state": door.get("_state"), "open": door.is_open(),
			"candidate": _game.station_interaction_candidate == door},
		"bunk": {"id": bunk.get_instance_id(), "position": _v(bunk.global_position),
			"wake": _v(bunk.get_exit_transform().origin),
			"candidate": _game.station_interaction_candidate == bunk,
			"occupant_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
			"reserved": bunk.is_reserved_for(_player), "available": bunk.is_available(),
			"transitioning": bool(bunk.get("_transitioning")),
			"active": active_seat == bunk, "active_seat_id": active_seat.get_instance_id() if is_instance_valid(active_seat) else 0,
			"seated_at_bunk": _player.is_seated_at(bunk.get_seat_anchor())},
		"common_occupied": habitat.contains_room(&"observation-common", _player.global_position),
	}, true)
	return result


## The paused branch deliberately avoids physics/support/fleet queries. UI focus
## and held native keys remain observable without advancing any gameplay owner.
func _habitat_restart_pause_observation() -> Dictionary:
	var focus: Control = get_viewport().gui_get_focus_owner()
	var hud: GameHUD = _game.hud if is_instance_valid(_game) else null
	var page: Control = hud.get("_pause_main_page") as Control if is_instance_valid(hud) else null
	var exit_button: Button = page.find_child("ExitButton", true, false) as Button if is_instance_valid(page) else null
	var bunk: StationBunk = _game.get("_active_station_seat") as StationBunk if is_instance_valid(_game) else null
	return {"mode": "habitat-restart", "paused": true,
		"frame": Engine.get_physics_frames(),
		"main_id": _game.get_instance_id() if is_instance_valid(_game) else 0,
		"rest_retained": _ember_node_current(_player) and _player.is_sleeping()
			and _player.is_station_seated() and _ember_node_current(bunk)
			and bunk == _game.world.get_node_or_null(^"HabitatSpine/Structure/PressurizedHabitatCorridor/BunkAlcove01/StationBunkInteraction")
			and bunk.is_reserved_for(_player) and bunk.get("_occupant") == _player
			and _player.is_seated_at(bunk.get_seat_anchor()),
		"native_keys": {"escape": Input.is_physical_key_pressed(KEY_ESCAPE),
			"tab": Input.is_physical_key_pressed(KEY_TAB), "return": Input.is_physical_key_pressed(KEY_ENTER)},
		"ui": {"main_visible": is_instance_valid(page) and page.is_visible_in_tree(),
			"focus_path": str(focus.get_path()) if is_instance_valid(focus) else "",
			"focus_name": str(focus.name) if is_instance_valid(focus) else "",
			"focus_is_exit": is_instance_valid(exit_button) and focus == exit_button,
			"exit_path": str(exit_button.get_path()) if is_instance_valid(exit_button) else "",
			"exit_visible": is_instance_valid(exit_button) and exit_button.is_visible_in_tree(),
			"exit_enabled": is_instance_valid(exit_button) and not exit_button.disabled,
			"exit_text": exit_button.text if is_instance_valid(exit_button) else ""}}


func _habitat_restart_observation() -> Dictionary:
	var result: Dictionary = _habitat_loop_observation()
	result["mode"] = "habitat-restart"
	result["paused"] = false
	if not bool(result.get("actors_current", false)):
		return result
	var store: UserDataStore = _game.get("_runtime_settings_user_data_store") as UserDataStore
	var camera: Camera3D = _player.get_camera()
	var tractor: TowTractor = _game.get_tow_tractor()
	var station: TowTractorDriverStation = tractor.get_driver_station() if _ember_node_current(tractor) else null
	var crew: Node = _game.get("_solo_crew_seat") as Node
	var cabin: Node = _game.get("_cabin_ship") as Node
	result.merge({
		"camera_current": _ember_node_current(camera) and camera.current and _player.get_viewport().get_camera_3d() == camera,
		"piloting": bool(_game.get("_piloting")) or (is_instance_valid(_game.active_ship) and _game.active_ship.is_piloted()), "driving": _game.is_driving_tow_tractor(),
		"crew_claim": is_instance_valid(crew) or is_instance_valid(_game.get("_solo_crew_ship")),
		"cabin_claim": is_instance_valid(cabin) or is_instance_valid(_player.get("_cabin_frame")),
		"recovery_pending": bool(_game.get("_solo_safe_recovery_pending")),
		"save": {"path": ProjectSettings.globalize_path(str(store.get("_path"))) if store != null else "",
			"generation": store.get_generation() if store != null else -1,
			"source": str(store.get_loaded_source()) if store != null else "",
			"context": (_game.get("_solo_safe_recovery_context") as Dictionary).duplicate(true),
			"context_generation": int(_game.get("_solo_safe_recovery_observed_store_generation")),
			"retry_seconds": float(_game.get("_solo_safe_recovery_retry_remaining_seconds"))},
		"tractor": {"current": _ember_node_current(tractor) and _game.is_ancestor_of(tractor)
			and _ember_node_current(station) and station.get_vehicle() == tractor,
			"id": tractor.get_instance_id() if _ember_node_current(tractor) else 0,
			"station_id": station.get_instance_id() if _ember_node_current(station) else 0,
			"station_path": str(station.get_path()) if _ember_node_current(station) else "",
			"position": _v(station.global_position) if _ember_node_current(station) else [],
			"approach": _v(tractor.get_boarding_position()) if _ember_node_current(tractor) else [],
			"candidate": _ember_node_current(station) and _game.station_interaction_candidate == station,
			"available": _ember_node_current(station) and station.is_available(),
			"driven": bool(tractor.get("_driven")) if _ember_node_current(tractor) else false,
			"seated_at_driver": _ember_node_current(tractor) and _player.is_seated_at(tractor.get_driver_seat_anchor())},
	}, true)
	return result


## Narrow live station service/walking/helm reads. No Habitat or fleet audit,
## service simulation mutator, synthetic input or actor placement is involved.
## Serialization only: retain the controller's completed epoch rather than
## assuming this observer runs after Player in the current physics frame.
func _life_completed_motion() -> Dictionary:
	var motion: Dictionary = _player.get_step_up_assist_audit().get("completed_motion", {})
	if motion.is_empty():
		return motion
	motion["start"] = _v(motion.start)
	motion["end"] = _v(motion.end)
	var event: Dictionary = motion.step_up
	if not event.is_empty():
		for key: String in ["start", "landing", "intended", "up", "tick_start", "tick_end"]:
			event[key] = _v(event[key])
		var frame: Transform3D = event.collision_transform
		event["collision_transform"] = [_v(frame.origin), _v(frame.basis.x), _v(frame.basis.y), _v(frame.basis.z)]
		event.bounds["movement_up"] = _v(event.bounds.movement_up)
	return motion


func _life_observation() -> Dictionary:
	var ship_path: NodePath = _life_config.ship
	var activity_path: NodePath = _life_config.activity
	var owner := get_parent()
	var current: bool = is_instance_valid(_game) and _game.is_inside_tree() and not _game.is_queued_for_deletion() \
		and owner.call("get_main") == _game and _ember_node_current(_player) \
		and _game.player == _player and _ember_node_current(_game.world) \
		and _ember_node_current(_ship) and _game.get_node_or_null(ship_path) == _ship
	var result := {"mode": _life_mode, "frame": Engine.get_physics_frames(), "actors_current": current}
	if not current:
		return result
	var activity := _game.world.get_node_or_null(activity_path) as StationOperationsActivity
	result.actors_current = _ember_node_current(activity)
	if not bool(result.actors_current):
		return result
	var yaw := _player.get_node(^"%CameraYaw") as Node3D
	var capsule := _player.get_node(^"PlayerCollision") as CollisionShape3D
	var shape := capsule.shape as CapsuleShape3D
	if shape == null:
		result.actors_current = false
		return result
	var support: Dictionary = {}
	if not _player.is_seated() and not bool(_game.get("_transition_busy")):
		var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.2,
			_player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD, [_player.get_rid()])
		support = _player.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider := support.get("collider") as Node
	var supported := _ember_node_current(collider) and _game.world.is_ancestor_of(collider)
	var source := _ship.get("_default_local_command_source") as LocalShipInputSource
	var pilot_seat := _ship.get("_pilot_seat_anchor") as Node3D
	var movers: Array = []
	# Actual transform owners, not clock-derived expected poses or summary data.
	var live_movers: Array = []
	for property_name: String in _life_config.movers:
		live_movers.append(activity.get(property_name))
	if bool(_life_config.drones):
		live_movers.append_array(activity.get("_drone_roots") as Array)
	for candidate: Variant in live_movers:
		var mover := candidate as Node3D
		if not _ember_node_current(mover) or not activity.is_ancestor_of(mover):
			result.actors_current = false
			return result
		var drawn: Array = []
		for mesh: MeshInstance3D in mover.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh != null and mesh.is_visible_in_tree():
				drawn.append(mesh.get_instance_id())
		var pose := mover.global_transform
		movers.append({"id": mover.get_instance_id(), "path": str(activity.get_path_to(mover)),
			"visible": mover.is_visible_in_tree(), "drawn_mesh_ids": drawn,
			"pose": [_v(pose.origin), _v(pose.basis.x), _v(pose.basis.y), _v(pose.basis.z)]})
	var station_candidate: Dictionary = {}
	if is_instance_valid(_game.station_interaction_candidate):
		station_candidate = {"position": _v(_game.station_interaction_candidate.global_position),
			"path": str(_game.station_interaction_candidate.get_path())}
	var default_controls := not _player.is_remote_driven()
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"sprint_boost", &"interact"]:
		var authored: Dictionary = ProjectSettings.get_setting("input/" + str(action), {})
		var expected: Array = []
		for event: InputEvent in authored.get("events", []):
			expected.append(event.as_text())
		var actual: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			actual.append(event.as_text())
		default_controls = default_controls and expected == actual \
			and is_equal_approx(InputMap.action_get_deadzone(action), float(authored.get("deadzone", -1.0)))
	result.merge({"phase": GameFlow.Phase.keys()[_game.phase],
		"menu_ready": StartupLoader.is_title_menu_ready(_game) and not is_instance_valid(owner.call("get_loading_screen")),
		"main_id": _game.get_instance_id(), "world_id": _game.world.get_instance_id(),
		"player_id": _player.get_instance_id(), "ship_id": _ship.get_instance_id(),
		"completed_motion": _life_completed_motion(),
		"player": _v(_player.global_position), "position": _v(_player.global_position), "spawn": _v(_spawn),
		"walk_forward": _v(-yaw.global_basis.z), "walk_right": _v(yaw.global_basis.x),
		"velocity": _v(_player.velocity), "walk_offset": _v(_ship.get_boarding_position() - _player.get_interaction_origin()),
		"candidate": _game.boarding_candidate == _ship, "station_candidate": station_candidate,
		"control_enabled": _player.is_control_enabled(), "seated": _player.is_seated(),
		"sleeping": _player.is_sleeping(), "station_seated": _player.is_station_seated(),
		"game_station_seated": bool(_game.get("_station_seated")), "transition_busy": bool(_game.get("_transition_busy")),
		"native_interact": Input.is_action_pressed("interact"), "mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"grounded": _player.is_on_floor(), "supported": supported, "support_collider": str(collider.get_path()) if supported else "",
		"capsule_id": capsule.get_instance_id(), "shape_id": capsule.shape.get_instance_id(),
		"capsule_enabled": not capsule.disabled, "capsule_geometry": [shape.radius, shape.height],
		"walk_tuning": {"walk": _player.walk_speed, "sprint": _player.sprint_speed,
			"acceleration": _player.ground_acceleration, "deceleration": _player.ground_deceleration,
			"air_acceleration": _player.air_acceleration, "jump": _player.jump_velocity,
			"gravity": _player.gravity_multiplier, "terminal": _player.terminal_velocity,
			"facing": _player.facing_speed, "mouse": _player.mouse_sensitivity, "invert_y": _player.invert_mouse_y},
		"default_controls": default_controls, "physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale,
		"default_sampler": is_instance_valid(source) and _ship.get("_command_source") == source and source.get_input_provider() == null,
		"tuning_unchanged": _sortie_tuning() == _tuning, "ship_tuning": _tuning,
		"piloted": _ship.is_piloted(), "remote_piloted": _ship.is_remote_piloted(),
		"active_ship": _game.get_active_ship() == _ship, "seated_at_pilot": _ember_node_current(pilot_seat) and _player.is_seated_at(pilot_seat),
		"service": {"id": activity.get_instance_id(), "clock": activity.get_activity_time(),
			"enabled": activity.is_activity_enabled(), "advancing": activity.is_activity_advancing(),
			"processing": activity.is_processing(), "visible": activity.is_visible_in_tree(), "movers": movers}}, true)
	if bool(_life_config.bounded):
		var berth := _game.world.get_berth_node(_ship.get_home_berth_id()) as ShipBerth
		result.merge({"ship_name": str(_ship.name), "ship_definition_id": str(_ship.get_ship_definition().ship_id),
			"boarding": _v(_ship.get_boarding_position()),
			"engine": str(_ship.get("_engine_state")),
			"parked_exact": _ship.global_transform.is_equal_approx(_parked),
			"home_berth_id": str(_ship.get_home_berth_id()),
			"home_berth_instance_id": berth.get_instance_id() if _ember_node_current(berth) else 0,
			"home_lease": _ember_node_current(berth) and berth.get_occupant() == _ship
				and berth.get_reservation_owner() == _ship
				and StringName(berth.get("_reserved_ship_id")) == _ship.get_ship_definition().ship_id})
		result.service.merge({"profile": str(activity.get_activity_profile_id()),
			"path": str(activity_path), "origin": _v(activity.global_position)})
	if _life_config.has("door"):
		var door_path: NodePath = _life_config.door
		var door := _game.world.get_node_or_null(door_path) as StationDoor
		if not _ember_node_current(door):
			result.actors_current = false
			return result
		result["door"] = {"id": door.get_instance_id(), "path": str(door_path),
			"position": _v(door.global_position), "state": door.get_state(),
			"open": door.is_open(), "blocked": door.is_portal_blocked(),
			"locked": door.locked, "candidate": _game.station_interaction_candidate == door}
		result.service["seed"] = activity.variation_seed
	return result


## Passive browser telemetry. No transport polling, lifecycle reconciliation,
## focus/input changes or physics queries while the production tree is paused.
func _browser_observation() -> Dictionary:
	var owner := get_parent()
	var result := {"mode": "browser-unreachable", "sequence": _browser_sequence,
		"pid": OS.get_process_id(), "frame": Engine.get_physics_frames(),
		"ticks_msec": Time.get_ticks_msec(), "main_id": 0, "player_id": 0,
		"menu_ready": false, "paused": get_tree().paused}
	if not is_instance_valid(_game) or not _game.is_inside_tree() \
			or _game.is_queued_for_deletion() or owner.call("get_main") != _game \
			or not _ember_node_current(_player):
		return result
	var hud := _game.hud as GameHUD
	if not _ember_node_current(hud):
		return result
	var focus := get_viewport().gui_get_focus_owner()
	var main_page := hud.get("_pause_main_page") as Control
	var browser := hud.get("_server_browser_page") as Control
	var intro := hud.get("_intro") as Control
	var feedback := hud.get("_server_browser_feedback") as Label
	var fields: Dictionary = {}
	for entry: Array in [["address", "_server_browser_address"], ["port", "_server_browser_port"],
			["player_name", "_server_browser_player_name"]]:
		var field := hud.get(entry[1]) as LineEdit
		fields[entry[0]] = field.text if is_instance_valid(field) else ""
	var controls: Dictionary = {}
	for node_name: String in ["IntroBeginShiftButton", "IntroServerBrowserButton", "ServerBrowserButton",
			"ResumeButton", "ExitButton", "ServerBrowserAddress", "ServerBrowserPort",
			"ServerBrowserPlayerName", "ServerBrowserRefreshButton", "ServerBrowserHostButton",
			"ServerBrowserManualJoinButton", "ServerBrowserDisconnectButton", "ServerBrowserBackButton"]:
		var control := hud.find_child(node_name, true, false) as Control
		if not is_instance_valid(control):
			continue
		var rect := control.get_global_rect()
		controls[node_name] = {"path": str(control.get_path()), "visible": control.is_visible_in_tree(),
			"enabled": not control.disabled if control is BaseButton else control.focus_mode != Control.FOCUS_NONE,
			"focused": focus == control, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"text": str(control.get("text")) if control is Button or control is LineEdit else ""}
	var adapter := _game.network_session
	var network := {"adapter_id": 0, "adapter_path": "", "configured": false,
		"is_server": false, "offline": _game.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,
		"native_peer_id": 0, "native_status": 0,
		"pending_peer_id": 0, "deadline_msec": 0, "offer": {}, "end_reason": {},
		"mode": str(_game.get("_network_session_mode")),
		"retry_mode": str(_game.get("_network_session_retry_mode")),
		"address": str(_game.get("_network_session_address")),
		"port": int(_game.get("_network_session_port")), "player_name": fields.player_name,
		"hud_snapshot": (hud.get("_network_status_presenter") as RefCounted).call("get_snapshot")}
	if _ember_node_current(adapter):
		var peer := adapter.get("_peer") as ENetMultiplayerPeer
		var pending := adapter.get("_pending_join_peer") as ENetMultiplayerPeer
		network.merge({"adapter_id": adapter.get_instance_id(), "adapter_path": str(adapter.get_path()),
			"configured": bool(adapter.get("_configured")), "is_server": bool(adapter.get("_is_server")),
			"native_peer_id": peer.get_instance_id() if is_instance_valid(peer) else 0,
			"native_status": peer.get_connection_status() if is_instance_valid(peer) else 0,
			"pending_peer_id": pending.get_instance_id() if is_instance_valid(pending) else 0,
			"deadline_msec": int(adapter.get("_pending_join_deadline_milliseconds")),
			"offer": (adapter.get("_server_offer") as Dictionary).duplicate(true),
			"end_reason": (adapter.get("_session_end_reason") as Dictionary).duplicate(true)}, true)
	var keys := {"escape": Input.is_physical_key_pressed(KEY_ESCAPE),
		"tab": Input.is_physical_key_pressed(KEY_TAB), "return": Input.is_physical_key_pressed(KEY_ENTER),
		"control": Input.is_physical_key_pressed(KEY_CTRL), "period": Input.is_physical_key_pressed(KEY_PERIOD)}
	for character: String in "0123456789abcdefghijklmnopqrstuvwxyz":
		keys[character] = Input.is_physical_key_pressed(OS.find_keycode_from_string(character.to_upper()))
	var support: Dictionary = {}
	if not get_tree().paused:
		var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.2,
			_player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD, [_player.get_rid()])
		support = _player.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider := support.get("collider") as Node
	result.merge({"main_id": _game.get_instance_id(), "player_id": _player.get_instance_id(),
		"menu_ready": StartupLoader.is_title_menu_ready(_game) and not is_instance_valid(owner.call("get_loading_screen")),
		"phase": GameFlow.Phase.keys()[_game.phase], "player": _v(_player.global_position),
		"velocity": _v(_player.velocity), "grounded": _player.is_on_floor(),
		"supported": _ember_node_current(collider) and _game.world.is_ancestor_of(collider),
		"control_enabled": _player.is_control_enabled(), "mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"gameplay_seconds": float(_game.get("_session_diagnostics_elapsed_physics_seconds")),
		"native_keys": keys, "network": network,
		"ui": {"main_visible": is_instance_valid(main_page) and main_page.is_visible_in_tree(),
			"browser_visible": is_instance_valid(browser) and browser.is_visible_in_tree(),
			"intro_visible": is_instance_valid(intro) and intro.is_visible_in_tree(),
			"started": bool(hud.get("_started")), "fields": fields,
			"feedback": feedback.text if is_instance_valid(feedback) else "",
			"controls": controls, "focus_path": str(focus.get_path()) if is_instance_valid(focus) else "",
			"focus_name": str(focus.name) if is_instance_valid(focus) else "",
			"selection_text": (focus as LineEdit).get_selected_text() if focus is LineEdit else "",
			"focus_text": str(focus.get("text")) if focus is Button or focus is LineEdit else "",
			"focus_visible": is_instance_valid(focus) and focus.is_visible_in_tree(),
			"focus_enabled": is_instance_valid(focus) and focus.focus_mode != Control.FOCUS_NONE
				and (not focus is BaseButton or not focus.disabled)}}, true)
	return result
