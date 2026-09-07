extends RefCounted
## A repeatable jump expedition. Jump travel changes scenes explicitly; touchdown
## and embodiment use the same physical ship and player as the station.
const WORLD := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const DESTINATION_ID: StringName = &"aurora_temperate_world"
const SURFACE_ORIGIN := Vector3(20000.0, 0.0, 0.0)
const JUMP_SECONDS := 1.2

var _flow: GameFlow
var state: StringName = &"idle"
var _ship: HeroShip
var _surface: Node3D
var _berth: ShipBerth
var _home: ShipBerth
var _departure := Transform3D.IDENTITY
var _jump_remaining := 0.0
var _surface_token: StringName = &""
var _station_environment: Environment
var _station_visible := true
var _landing_elapsed := 0.0
var _jump_fade_layer: CanvasLayer
var _jump_fade: ColorRect
var _fade_opacity := 0.0

func _init(flow: GameFlow) -> void:
	_flow = flow

func is_active() -> bool:
	return state != &"idle"

func runtime_state() -> Dictionary:
	var reason := _launch_rejection() if not is_active() else ""
	var enabled := reason.is_empty()
	var copy := "READY — AURORA LANDING"
	if is_active():
		enabled = _flow._piloting and not _flow._transition_busy and state not in [&"return_jump", &"return_landing"]
		copy = "RETURN TO MUDDS" if enabled else "BOARD YOUR SHIP TO RETURN"
		if state in [&"return_jump", &"return_landing"]:
			copy = "RETURNING TO MUDDS"
	elif not enabled:
		copy = reason
	return {"status_id": &"ready" if enabled else &"unavailable", "status_text": copy,
		"action_enabled": enabled, "engagement_requested": is_active()}

func _launch_rejection() -> String:
	if not _flow._piloting or not is_instance_valid(_flow.active_ship) or not _flow.player.is_seated():
		return "TAKE A SHIP'S PILOT SEAT"
	if _flow._network_session_mode in [&"client", &"server"]:
		return "SOLO EXPLORATION ONLY"
	if _flow._transition_busy or _flow.active_ship.is_landing_active() or _flow._recovering:
		return "FINISH THE CURRENT MANOEUVRE"
	if _flow.active_ship.is_destroyed():
		return "SHIP UNAVAILABLE"
	if _flow._ember_surface_journey_active or not _flow._pending_ember_surface_request.is_empty():
		return "EMBER EXPEDITION ACTIVE"
	if bool(_flow.planetary_cruise_binding.get_snapshot().get("engagement_requested", false)):
		return "CANCEL EMBER CRUISE FIRST"
	if _flow._planetary_cruise_combat_active() or _flow._selected_activity_is_running():
		return "FINISH THE ACTIVE FLIGHT OBJECTIVE"
	if _flow.phase not in [GameFlow.Phase.START_ENGINES, GameFlow.Phase.FREE_FLIGHT, GameFlow.Phase.SHUT_DOWN]:
		return "FREE FLIGHT REQUIRED"
	var definition := _flow.active_ship.get_ship_definition()
	if definition == null or not ("small_craft" in definition.compatibility_tags or "medium_craft" in definition.compatibility_tags):
		return "SMALL OR MEDIUM CRAFT REQUIRED"
	var home := _flow.world.get_berth_node(_flow.active_ship.get_home_berth_id()) as ShipBerth
	if not is_instance_valid(home) or not home.can_accept(definition, _flow.active_ship):
		return "HOME BERTH UNAVAILABLE"
	return ""

func request() -> bool:
	if is_active():
		if not bool(runtime_state().action_enabled):
			return false
		_begin_return()
		return true
	if not _launch_rejection().is_empty():
		return false
	_ship = _flow.active_ship
	_home = _flow.world.get_berth_node(_ship.get_home_berth_id()) as ShipBerth
	_departure = _ship.global_transform
	_station_visible = _flow.world.visible
	_station_environment = _flow.get_viewport().world_3d.environment
	_flow._release_ship_berth(_ship)
	_ship.request_engine_stop(false)
	_ship.velocity = Vector3.ZERO
	state = &"outbound_jump"
	_jump_remaining = JUMP_SECONDS
	_flow.phase = GameFlow.Phase.FREE_FLIGHT
	_flow.hud.toast("Jump to Aurora", "Preparing atmospheric landing approach", 2.5)
	_flow.hud.set_paused(false)
	return true

func physics_tick(delta: float) -> void:
	if not is_active():
		return
	if state in [&"outbound_jump", &"return_jump"]:
		_present_jump_fade(clampf(1.0 - _jump_remaining / JUMP_SECONDS, 0.0, 1.0))
	elif _fade_opacity > 0.0:
		_present_jump_fade(move_toward(_fade_opacity, 0.0, delta * 2.5))
	if not is_instance_valid(_ship) or _ship.is_destroyed() or _flow.active_ship != _ship:
		cancel()
		return
	if state in [&"outbound_jump", &"return_jump"]:
		_ship.velocity = Vector3.ZERO
		_jump_remaining -= delta
		if _jump_remaining <= 0.0:
			if state == &"outbound_jump":
				_arrive()
			else:
				_arrive_home()
	elif state in [&"landing", &"return_landing"]:
		_landing_elapsed += delta
		if not _ship.is_landing_active():
			if bool(_ship.get_telemetry().get("landed", false)) and _ship.get_landing_contract_report().get("phase") == HeroShip.LANDING_PHASE_DOCKED:
				_ship.request_engine_stop(false)
				if state == &"return_landing":
					_finish_return()
				else:
					state = &"landed"
					_flow.hud.toast("Welcome to Aurora", "E: leave the ship. Explore the lookout, then board to return.", 4.0)
			elif _landing_elapsed > 0.25:
				cancel()
		elif _landing_elapsed > 60.0:
			cancel()
	elif state == &"disembarking" and not _flow.player.is_seated() and _flow.player.collision_layer != 0:
		_flow._piloting = false
		_flow.phase = GameFlow.Phase.APPROACH_SHIP
		_flow._transition_busy = false
		_flow.player.set_control_enabled(true)
		_flow.hud.set_mode("on-foot")
		_flow.audio.set_on_foot(true)
		state = &"surface"
	elif state == &"boarding" and _flow.player.is_seated():
		_ship.set_canopy_open(false, 0.4)
		_flow._piloting = true
		_flow._transition_busy = false
		_flow.player.set_camera_active(false)
		_ship.set_piloted(true)
		_flow._reset_lifecycle_command_cursor()
		_flow.phase = GameFlow.Phase.FREE_FLIGHT
		_flow.hud.set_mode("piloting")
		_flow.audio.set_on_foot(false)
		state = &"landed"
	if state == &"surface" and _flow.player.global_position.y < -15.0:
		_flow.player.teleport_to(_ship.get_exit_transform())
		_flow.hud.toast("Surface rescue", "Returned to your ship's access ramp")

func update_presentation() -> void:
	if _flow._piloting:
		_flow._consume_active_ship_command_edges()
		_flow.hud.update_ship_telemetry(_ship.get_telemetry())
	if _flow.phase == GameFlow.Phase.IN_FLIGHT_CABIN:
		_flow._update_on_foot_flow()
		return
	match state:
		&"outbound_jump":
			_flow.hud.set_objective("Jumping to Aurora — preparing atmospheric approach", "AURORA EXPEDITION")
			_flow.hud.set_interaction("JUMP DRIVE ENGAGED")
		&"return_jump", &"return_landing":
			_flow.hud.set_objective("Returning to your registered berth at Mudds", "HOMEWARD BOUND")
			_flow.hud.set_interaction("RETURN APPROACH IN PROGRESS")
		&"landing":
			_flow.hud.set_objective("Landing at Aurora's coastal exploration pad", "AURORA EXPEDITION")
			_flow.hud.set_interaction("AUTOMATIC LANDING — PLEASE WAIT")
		&"surface":
			_flow._update_on_foot_flow()
			if is_instance_valid(_flow.station_interaction_candidate):
				return
			_flow.hud.set_objective("Explore the lookout and standing stones; return to your ship when ready", "AURORA SURFACE")
			_flow.hud.set_interaction("[ E ]  BOARD YOUR SHIP" if _near_ship() else "WALK THE COASTAL LOOKOUT")
		&"landed":
			_flow.hud.set_objective("Explore Aurora, or open Esc → Destination Board to return to Mudds", "AURORA EXPEDITION")
			_flow.hud.set_interaction("[ E ]  EXIT SHIP" if bool(_ship.get_telemetry().get("landed", false)) else "[ L ]  LAND AT AURORA PAD  //  ESC: RETURN TO MUDDS")
		_:
			_flow.hud.set_interaction("MOVING THROUGH SHIP ACCESS")
	_flow._sync_planetary_cruise_hud()

func request_exit() -> void:
	if state != &"landed" or _flow._transition_busy:
		return
	if not bool(_ship.get_telemetry().get("landed", false)):
		if str(_ship.get_telemetry().get("engine_state", "")).to_upper() == "OFFLINE":
			_flow._leave_seat_into_cabin()
		return
	_ship.request_engine_stop(false)
	var departing := _ship
	_flow._transition_busy = true
	state = &"opening_exit"
	departing.set_canopy_open(true, 0.4)
	await departing.canopy_motion_finished
	if state != &"opening_exit" or not is_instance_valid(departing) or _ship != departing:
		return
	_ship.set_piloted(false)
	_flow.player.set_camera_active(true)
	if _flow.player.begin_disembark(_ship.get_exit_transform(), 0.6, _ship):
		_flow._transition_busy = true
		state = &"disembarking"
	else:
		_ship.set_piloted(true)
		_flow.player.set_camera_active(false)
		_flow._transition_busy = false
		state = &"landed"

func interact() -> bool:
	if _flow._station_seated or _flow._transition_busy:
		return false
	_flow._refresh_interaction_targets()
	if is_instance_valid(_flow.station_interaction_candidate):
		return false
	if _flow.phase == GameFlow.Phase.IN_FLIGHT_CABIN:
		return false
	if state == &"surface" and _near_ship():
		var area := _ship.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
		if area != null and area.try_reserve(_flow.player):
			_flow._boarding_area = area
			_begin_boarding()
	return true

func _begin_boarding() -> void:
	var boarding_ship := _ship
	_flow._transition_busy = true
	state = &"opening_boarding"
	boarding_ship.set_canopy_open(true, 0.4)
	await boarding_ship.canopy_motion_finished
	if state != &"opening_boarding" or not is_instance_valid(boarding_ship) or _ship != boarding_ship:
		return
	if _flow.player.begin_boarding(_ship.get_boarding_entry_transform(), _ship.get_pilot_seat_anchor(), 0.7, _ship):
		state = &"boarding"
	else:
		_flow._transition_busy = false
		state = &"surface"


func request_landing() -> void:
	if state != &"landed" or _ship.is_landing_active():
		return
	if _ship.request_berth_landing(_berth):
		state = &"landing"
		_landing_elapsed = 0.0
	else:
		_flow.hud.toast("Aurora landing", "Approach the pad slowly from above, then press L")

func _near_ship() -> bool:
	var area := _ship.get_node_or_null("ShipBoardingArea")
	return area != null and area in _flow.player.get_nearby_interactables()

func _arrive() -> void:
	_surface = WORLD.instantiate() as Node3D
	_surface.position = SURFACE_ORIGIN - Vector3.UP * 120000.0
	_flow.add_child(_surface)
	_berth = ShipBerth.new()
	_berth.name = "AuroraExplorationBerth"
	_berth.berth_id = &"aurora_exploration_pad"
	_berth.compatibility_tags = PackedStringArray(["small_craft", "medium_craft"])
	_berth.landing_half_extents = Vector3(14.0, 12.0, 16.0)
	_berth.assist_capture_center = Vector3(0.0, 30.0, 30.0)
	_berth.assist_capture_half_extents = Vector3(45.0, 60.0, 300.0)
	var bounds: AABB = _ship.get_landing_collision_report().get("local_bounds", AABB())
	_berth.dock_transform.origin.y = -bounds.position.y + 0.03
	_surface.get_node("LandingRegion").add_child(_berth)
	_surface_token = _berth.try_reserve(_ship, _ship.get_ship_definition())
	_ship.global_transform = _berth.get_assist_staging_transform()
	_ship.reset_physics_interpolation()
	_ship.velocity = Vector3.ZERO
	_flow.world.visible = false
	var atmosphere := _surface.get_node("AuroraAtmosphereComposition")
	atmosphere.configure()
	atmosphere.present_observation({"body_local_observer_m": Vector3(0, 120040, 30), "view_direction_body_local": Vector3.FORWARD, "fog_path_distance_m": 12000.0, "speed_mps": 0.0, "weather_scalar": 0.4, "cloud_scalar": 0.5, "caller_time_seconds": 0.0}, 1)
	_flow.get_viewport().world_3d.environment = atmosphere.get_world_environment().environment
	state = &"landing"
	_landing_elapsed = 0.0
	if _surface_token.is_empty() or not _ship.request_berth_landing(_berth):
		cancel()

func _begin_return() -> void:
	if is_instance_valid(_berth):
		_berth.release(_ship, _surface_token)
	_ship.call(&"_end_landing_for_lifecycle", &"aurora_return")
	_ship.request_engine_stop(false)
	_ship.velocity = Vector3.ZERO
	state = &"return_jump"
	_jump_remaining = JUMP_SECONDS
	_flow.hud.set_paused(false)
	_flow.hud.toast("Returning to Mudds", "Jump drive preparing your home approach", 2.0)

func _arrive_home() -> void:
	_clear_surface()
	if not is_instance_valid(_home) or not _flow._reserve_berth_for_ship(_ship, _home.berth_id, false):
		cancel()
		return
	_ship.global_transform = _home.get_assist_staging_transform()
	_ship.reset_physics_interpolation()
	_ship.velocity = Vector3.ZERO
	state = &"return_landing"
	_landing_elapsed = 0.0
	if not _ship.request_berth_landing(_home):
		cancel()

func _finish_return() -> void:
	_clear_jump_fade()
	state = &"idle"
	_flow.phase = GameFlow.Phase.SHUT_DOWN
	_flow._sortie_departed_berth = false
	_flow._landing_request_active = false
	_flow._active_landing_berth_id = &""
	_flow.hud.set_objective("Home at Mudds — E to exit, or choose another destination", "EXPEDITION COMPLETE")
	_flow.hud.toast("Aurora expedition complete", "Your ship is safely docked at Mudds", 3.0)
	_ship = null
	_home = null
	_flow._sync_planetary_cruise_hud()

func _clear_surface() -> void:
	if is_instance_valid(_flow.world):
		_flow.world.visible = _station_visible
	if is_instance_valid(_surface):
		_surface.get_parent().remove_child(_surface)
		_surface.queue_free()
	if _flow.is_inside_tree():
		_flow.get_viewport().world_3d.environment = _station_environment
	_surface = null
	_berth = null
	_surface_token = &""

func cancel() -> void:
	if not is_active():
		return
	_clear_jump_fade()
	if is_instance_valid(_ship):
		_ship.call(&"_end_landing_for_lifecycle", &"aurora_cancelled")
	if _flow._recovering:
		# Destruction recovery already owns the actor and its generation.
		_clear_surface()
		state = &"idle"
		_ship = null
		_home = null
		return
	_flow._invalidate_transition_generation()
	if _flow._station_seated or is_instance_valid(_flow._active_station_seat):
		_flow._recover_from_station_seat()
	_flow._release_cabin_occupancy()
	if is_instance_valid(_flow._boarding_area):
		_flow._boarding_area.release_reservation(_flow.player)
	_flow._boarding_area = null
	_flow._clear_boarding_confirmation_reservation()
	_clear_surface()
	state = &"idle"
	_flow._transition_busy = false
	_flow._piloting = false
	_flow._landing_request_active = false
	_flow._active_landing_berth_id = &""
	var recovery := _flow.world.get_player_spawn() as Transform3D
	if is_instance_valid(_ship) and not _ship.is_destroyed():
		_ship.set_piloted(false)
		_ship.request_engine_stop(false)
		_ship.velocity = Vector3.ZERO
		_ship.global_transform = _departure
		# Recover the craft to its home pad if available. One normal physical
		# touchdown re-establishes occupancy; no landed flag is manufactured.
		if is_instance_valid(_home) and _home.can_accept(_ship.get_ship_definition(), _ship):
			_ship.global_transform = _home.get_dock_transform()
			if _flow._reserve_berth_for_ship(_ship, _home.berth_id, false):
				if _ship.request_berth_landing(_home):
					var shutdown := _ship.request_engine_stop.bind(false)
					if not _ship.landing_completed.is_connected(shutdown):
						_ship.landing_completed.connect(shutdown, CONNECT_ONE_SHOT)
				recovery = _ship.get_exit_transform()
		_ship.reset_physics_interpolation()
	_flow.player.force_recovery_to_on_foot(recovery)
	_flow.player.set_camera_active(true)
	_flow.player.set_control_enabled(true)
	_flow.audio.set_on_foot(true)
	_flow.phase = GameFlow.Phase.APPROACH_SHIP
	_flow._reboard_blocked_ship = null
	_flow.hud.set_mode("on-foot")
	_flow.hud.set_objective("Board your ship to try another expedition", "BACK AT MUDDS")
	_flow.hud.toast("Expedition interrupted", "Returned safely to Mudds; the route can be retried", 3.0)
	_ship = null
	_home = null


func _present_jump_fade(opacity: float) -> void:
	_fade_opacity = opacity
	if not is_instance_valid(_jump_fade_layer):
		_jump_fade_layer = CanvasLayer.new()
		_jump_fade_layer.name = "AuroraJumpTransition"
		_jump_fade_layer.layer = 7
		_jump_fade = ColorRect.new()
		_jump_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_jump_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_jump_fade_layer.add_child(_jump_fade)
		_flow.add_child(_jump_fade_layer)
	_jump_fade.color = Color(0.005, 0.018, 0.028, opacity)


func _clear_jump_fade() -> void:
	_fade_opacity = 0.0
	if is_instance_valid(_jump_fade_layer):
		_jump_fade_layer.queue_free()
	_jump_fade_layer = null
	_jump_fade = null
