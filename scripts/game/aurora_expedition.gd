extends RefCounted
## A repeatable Aurora visit on the production planetary path.
##
## This used to be a 1.2 s jump that instantiated the authored world locally.
## It now goes through exactly the components an Ember expedition uses: the
## journey coordinator admits it, the one `PlanetaryCruiseProductionBinding` is
## pointed at Aurora's bootstrap and engaged, Aurora's own
## `PlanetaryStreamingProductionBinding` observes the craft, the one
## `CommonWorldOriginRebaseOwner` commits the common-world rebases that bring
## the body inside the streaming envelope, the authored approach corridor is
## flown by the real cruise controller, and the touchdown is a real
## `ShipBerth` lease on the streamed world's own landing region.
##
## Outbound movement belongs to the shared cruise controller and HeroShip's
## berth landing assist. The visit only admits, observes and leases the route.
## Interrupted-visit restoration and the return leg still retain their existing
## explicit recovery placements; neither is outbound travel.
const DESTINATION_ID: StringName = &"aurora_temperate_world"
const LANDING_REGION_PATH := ^"LandingRegion"
const LANDING_REGION_RESOURCE_PATH := \
	"res://assets/world/planets/aurora_foundation_landing.tres"
const _LANDING_REGION := preload(LANDING_REGION_RESOURCE_PATH)
const ApproachSourceType := preload(
	"res://scripts/world/aurora_visit_approach_source.gd"
)
## Interrupted-visit restoration alone uses this recovery offset. Ordinary
## outbound travel never stages at the navigation anchor.
const ORBIT_STANDOFF_M := 500.0
## The approach entry volume the corridor is measured against. Taken from the
## Ember Host's own envelope constant so both worlds present the same tolerance.
const APPROACH_ENTRY_POSITION_HALF_EXTENTS_M := Vector3(42.0, 25.0, 75.0)
const APPROACH_MAXIMUM_SPEED_MPS := 12.0
const APPROACH_MAXIMUM_ATTITUDE_DEGREES := 12.0
const APPROACH_HULL_MARGIN_M := 0.05
## Bounded tick budgets. Every wait in this visit is a tick budget, never a
## wall clock, and every exhausted budget cancels rather than stalling.
const ORBIT_STAGE_TICK_BUDGET := 900
const OUTBOUND_TICK_BUDGET := 48_000
const MAX_CRUISE_RESUME_ATTEMPTS := 600
const CORRIDOR_TICK_BUDGET := 12_000
const DEPARTURE_TICK_BUDGET := 900

var _flow: GameFlow
var state: StringName = &"idle"
var _ship: HeroShip
var _surface: Node3D
var _berth: ShipBerth
var _home: ShipBerth
var _departure := Transform3D.IDENTITY
var _surface_token: StringName = &""
var _station_environment: Environment
var _station_visible := true
var _landing_elapsed := 0.0
var _approach_source: AuroraVisitApproachSource
var _staging_events := 0
var _orbit_ticks := 0
var _cruise_resume_attempts := 0
var _corridor_ticks := 0
var _departure_ticks := 0
var _retire_ticks := 0
var _committed_rebases_outbound := 0
var _last_admission: Dictionary = {}
var _last_compose_result: Dictionary = {}
var _last_leg_result: Dictionary = {}
var _fade_layer: CanvasLayer
var _fade: ColorRect
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
		# A visit that has arrived is asked to go home; a visit still on its way
		# out is asked to give up, which is the one control a pilot has over an
		# approach in flight. Neither is offered while a transition owns the
		# actors or while the way home is already under way.
		enabled = not _flow._transition_busy \
			and state in [&"landed", &"surface", &"outbound", &"corridor"]
		if state in [&"landed", &"surface"]:
			enabled = enabled and _flow._piloting
			copy = "RETURN TO MUDDS" if enabled else "BOARD YOUR SHIP TO RETURN"
		elif state in [&"outbound", &"corridor"]:
			copy = "ABANDON THE AURORA APPROACH"
		elif state in [&"return_cruise", &"return_landing"]:
			copy = "RETURNING TO MUDDS"
		else:
			copy = "APPROACHING AURORA"
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
	var departed_return := _flow.phase == GameFlow.Phase.SHUT_DOWN and _flow._sortie_departed_berth
	if (_flow.phase != GameFlow.Phase.FREE_FLIGHT and not departed_return) \
			or bool(_flow.active_ship.get_telemetry().get("landed", true)):
		return "DEPART SHIPYARD, THEN FACE AURORA"
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
		if state in [&"outbound", &"corridor"]:
			cancel()
		else:
			_begin_return()
		return true
	if not _launch_rejection().is_empty():
		return false
	var craft := _flow.active_ship
	var home := _flow.world.get_berth_node(craft.get_home_berth_id()) as ShipBerth
	var departure := craft.global_transform
	var station_visible := _flow.world.visible
	var station_environment := _flow.get_viewport().world_3d.environment
	# Admission is the journey coordinator's, exactly as an Ember expedition's
	# is: it points the one cruise binding at Aurora, makes sure the one origin
	# owner holds Aurora's pair, and engages the cruise.
	_last_admission = _flow._planetary_journey.admit_aurora_visit(craft, false)
	if not bool(_last_admission.get("accepted", false)):
		_flow.hud.toast(
			"Aurora expedition unavailable",
			str(_last_admission.get("reason", &"aurora_visit_refused")), 2.4
		)
		return false
	_flow.phase = GameFlow.Phase.FREE_FLIGHT
	_ship = craft
	_home = home
	_departure = departure
	_station_visible = station_visible
	_station_environment = station_environment
	_staging_events = 0
	_cruise_resume_attempts = 0
	_orbit_ticks = 0
	_corridor_ticks = 0
	_departure_ticks = 0
	_committed_rebases_outbound = 0
	state = &"outbound"
	_flow._sortie_departed_berth = true
	var engaged := _flow._planetary_journey.engage_aurora_cruise(_ship, true)
	if not bool(engaged.get("accepted", false)):
		_last_leg_result = engaged.duplicate(true)
		cancel()
		return false
	_flow.hud.toast(
		"Cruise to Aurora", "Streaming the world and arming the landing approach",
		2.5
	)
	_flow.hud.set_paused(false)
	return true


## Detached visit state. Fresh outbound travel records no staging events.
func get_visit_snapshot() -> Dictionary:
	return {
		"state": state,
		"staging_events": _staging_events,
		"committed_rebases_outbound": _committed_rebases_outbound,
		"orbit_ticks": _orbit_ticks,
		"cruise_resume_attempts": _cruise_resume_attempts,
		"corridor_ticks": _corridor_ticks,
		"departure_ticks": _departure_ticks,
		"retire_ticks": _retire_ticks,
		"streamed_world_resident": is_instance_valid(_surface),
		"berth_leased": is_instance_valid(_berth) and not _surface_token.is_empty(),
		"approach_source": _approach_source.get_snapshot() \
			if is_instance_valid(_approach_source) else {},
		"admission": _last_admission.duplicate(true),
		"compose": _last_compose_result.duplicate(true),
		"last_leg": _last_leg_result.duplicate(true),
		"journey": _flow._planetary_journey.get_aurora_visit_snapshot(),
	}.duplicate(true)

func physics_tick(delta: float) -> void:
	if not is_active():
		return
	if _fade_opacity > 0.0:
		_present_transition_fade(move_toward(_fade_opacity, 0.0, delta * 2.5))
	if state == &"retiring":
		_advance_retiring()
		return
	if not is_instance_valid(_ship) or _ship.is_destroyed() or _flow.active_ship != _ship:
		cancel()
		return
	match state:
		&"outbound":
			_advance_outbound()
			return
		&"corridor":
			_advance_corridor()
			return
		&"restoring":
			_advance_restoring()
			return
		&"return_cruise":
			_advance_return_cruise()
			return
	if state in [&"landing", &"return_landing"]:
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
				_note_leg_failure(&"aurora_landing_inactive_without_dock")
				cancel()
		elif _landing_elapsed > 60.0:
			_note_leg_failure(&"aurora_landing_timed_out")
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
	if state == &"surface" and is_instance_valid(_surface) \
			and _flow.player.global_position.distance_to(
				_landing_region_origin()
			) > 20_000.0:
		_flow.player.teleport_to(_ship.get_exit_transform())
		_flow.hud.toast("Surface rescue", "Returned to your ship's access ramp")


## Streaming becomes resident during physical braking, then the same carried
## cruise consumes the authored final approach. No actor placement occurs here.
func _advance_outbound() -> void:
	var journey := _flow._planetary_journey
	var visit := journey.get_aurora_visit_snapshot()
	_committed_rebases_outbound = int(visit.get("rebase_commit_count", 0))
	var bootstrap := _flow.aurora_streaming_bootstrap
	var cruise := _flow.planetary_cruise_binding
	if not is_instance_valid(bootstrap) or not is_instance_valid(cruise):
		cancel()
		return
	if not _ensure_outbound_cruise():
		return
	var loaded := bootstrap.get_loaded_instance()
	if is_instance_valid(loaded) and not is_instance_valid(_approach_source):
		_compose_streamed_surface(loaded)
		if not is_active():
			return
	var controller := cruise.get_snapshot().get("controller", {}) as Dictionary
	var approach := controller.get("final_approach", {}) as Dictionary
	if StringName(approach.get("state_id", &"")) == &"final_approach":
		_corridor_ticks = 0
		state = &"corridor"
		return
	_orbit_ticks += 1
	if _orbit_ticks > OUTBOUND_TICK_BUDGET:
		_last_leg_result = {
			"accepted": false,
			"reason": &"aurora_orbit_budget_exhausted",
			"navigation": _navigation_standoff_target(),
			"ship": _ship.global_position if is_instance_valid(_ship) else Vector3.INF,
			"streaming": visit.get("last_streaming_result", {}),
			"origin": visit.get("last_origin_result", {}),
			"binding_rejection": _flow.aurora_streaming_binding.get_snapshot().get(
				"last_external_rebase_rejection", {}
			).get("reason", &""),
			"bootstrap_errors": _flow.aurora_streaming_bootstrap.audit().get("errors", []),
		}
		cancel()


## Manual controls retain priority. A released override may resume this same
## requested visit; repeated failures consume one finite budget until cancelled.
func _ensure_outbound_cruise() -> bool:
	if _ship.has_manual_flight_intent():
		return false
	var cruise := _flow.planetary_cruise_binding
	if not bool(cruise.get_snapshot().get("engagement_requested", false)):
		_cruise_resume_attempts += 1
		if _cruise_resume_attempts > MAX_CRUISE_RESUME_ATTEMPTS:
			_note_leg_failure(&"aurora_cruise_resume_budget_exhausted")
			cancel()
			return false
		var engaged := _flow._planetary_journey.engage_aurora_cruise(_ship, true)
		if not bool(engaged.get("accepted", false)):
			_last_leg_result = engaged.duplicate(true)
			return false
	if is_instance_valid(_approach_source) and _approach_source.is_ready_for_approach():
		var armed := _flow._planetary_journey.arm_aurora_final_approach(
			_approach_source, _landing_region(), _approach_envelope()
		)
		if not bool(armed.get("accepted", false)):
			_last_leg_result = armed.duplicate(true)
			return false
	return true


## Everything from here down is flown by the production cruise controller
## through the authored corridor; this only watches for the handoff the
## coordinator consumes and turns it into the real berth landing request.
func _advance_corridor() -> void:
	_corridor_ticks += 1
	_committed_rebases_outbound = int(
		_flow._planetary_journey.get_aurora_visit_snapshot().get(
			"rebase_commit_count", _committed_rebases_outbound
		)
	)
	if _flow._planetary_journey.aurora_final_approach_handoff_ready():
		_begin_touchdown()
		return
	if not _ensure_outbound_cruise():
		return
	if _corridor_ticks > CORRIDOR_TICK_BUDGET:
		var region := _landing_region()
		_last_leg_result = {
			"accepted": false,
			"reason": &"aurora_corridor_budget_exhausted",
			"ship_region_local": region.to_local(_ship.global_position) \
				if is_instance_valid(region) else Vector3.INF,
			"ship_speed": _ship.velocity.length(),
			"cruise": _flow._planetary_journey.get_aurora_visit_snapshot().get(
				"last_cruise_result", {}
			),
		}
		cancel()


## The interrupted-visit resume. It streams Aurora back in through the same lane
## a fresh arrival uses rather than standing a private copy of the world, then
## puts the craft on the authored pad through a real lease and the pilot on foot
## beside its ramp. There is no corridor here: a resumed visit is already down.
func _advance_restoring() -> void:
	var bootstrap := _flow.aurora_streaming_bootstrap
	if not is_instance_valid(bootstrap):
		cancel()
		return
	var loaded := bootstrap.get_loaded_instance()
	if is_instance_valid(loaded):
		_complete_restore(loaded)
		return
	var navigation := _navigation_standoff_target()
	if navigation.is_finite():
		if _staging_events == 0:
			_staging_events += 1
		# The lane observes whichever actor GameFlow samples; a resumed pilot is
		# on foot, so the pilot is the observation that carries the visit back.
		_flow.player.teleport_to(Transform3D(
			_flow.player.global_basis, navigation + Vector3.BACK * ORBIT_STANDOFF_M
		))
		_ship.global_position = navigation + Vector3.BACK * ORBIT_STANDOFF_M \
			+ Vector3.RIGHT * 30.0
		_ship.velocity = Vector3.ZERO
	_orbit_ticks += 1
	if _orbit_ticks > ORBIT_STAGE_TICK_BUDGET:
		cancel()


## Holds the craft at its registered home pad's staging pose so the lane's next
## committed rebase brings the common origin back to the yard, which is what
## streams Aurora out behind the departing craft.
func _advance_return_cruise() -> void:
	_departure_ticks += 1
	if is_instance_valid(_home) and _home.is_inside_tree():
		if _departure_ticks == 1:
			_staging_events += 1
		_ship.global_transform = _home.get_assist_staging_transform()
		_ship.velocity = Vector3.ZERO
		if is_instance_valid(_flow.player) and not _flow.player.is_seated():
			_flow.player.teleport_to(_ship.get_exit_transform())
	var bootstrap := _flow.aurora_streaming_bootstrap
	if not is_instance_valid(bootstrap) \
			or not is_instance_valid(bootstrap.get_loaded_instance()):
		_arrive_home()
		return
	if _departure_ticks > DEPARTURE_TICK_BUDGET:
		cancel()



func update_presentation() -> void:
	if _flow._piloting:
		_flow._consume_active_ship_command_edges()
		_flow.hud.update_ship_telemetry(_ship.get_telemetry())
	if _flow.phase == GameFlow.Phase.IN_FLIGHT_CABIN:
		_flow._update_on_foot_flow()
		return
	match state:
		&"outbound":
			_flow.hud.set_objective("Cruising to Aurora — streaming the world and arming the approach", "AURORA EXPEDITION")
			_flow.hud.set_interaction("CRUISE ENGAGED")
		&"corridor":
			_flow.hud.set_objective("Flying Aurora's authored approach corridor", "AURORA EXPEDITION")
			_flow.hud.set_interaction("FINAL APPROACH — PLEASE WAIT")
		&"restoring":
			_flow.hud.set_objective("Returning you to Aurora", "AURORA SURFACE")
			_flow.hud.set_interaction("STREAMING AURORA")
		&"return_cruise", &"return_landing":
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
	if _flow.player.begin_disembark(_ship.get_exit_transform(), 0.6, _ship,
			_ship.get_exterior_exit_waypoints()):
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
	if _flow.player.begin_boarding(_ship.get_boarding_entry_transform(), _ship.get_pilot_seat_anchor(), 0.7, _ship,
			_ship.get_exterior_boarding_waypoints(_flow.player.global_position)):
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

## Composes the visit against the world the production streaming coordinator
## has just made resident. The world itself is never instantiated here: this
## only leases the exploration berth on the streamed scene's own authored
## landing region, stands the visit's approach source, arms the authored
## corridor through the journey coordinator, and hands the viewport Aurora's own
## atmosphere. The berth is parented to the live landing region, so its dock is
## expressed in the streamed world's frame rather than in Main's.
func _compose_streamed_surface(loaded: Node3D) -> void:
	var region := loaded.get_node_or_null(LANDING_REGION_PATH) as Node3D
	if not is_instance_valid(region) or not region.is_inside_tree():
		_last_compose_result = {
			"accepted": false, "reason": &"aurora_landing_region_unavailable",
		}
		return
	_surface = loaded
	_lease_surface_berth(region)
	if _surface_token.is_empty():
		_last_compose_result = {
			"accepted": false, "reason": &"aurora_berth_lease_refused",
		}
		cancel()
		return
	_present_aurora_environment()
	var bootstrap := _flow.aurora_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		_last_compose_result = {
			"accepted": false, "reason": &"aurora_coordinate_frame_unavailable",
		}
		cancel()
		return
	# Retain the same physical transit attachment when streaming becomes resident.
	var engaged := _flow._planetary_journey.engage_aurora_cruise(_ship, true)
	if not bool(engaged.get("accepted", false)):
		_last_compose_result = engaged.duplicate(true)
		cancel()
		return
	_approach_source = ApproachSourceType.new() as AuroraVisitApproachSource
	_approach_source.name = "AuroraVisitApproachSource"
	_flow.add_child(_approach_source)
	var armed_source := _approach_source.arm(
		frame.get_generation(),
		int(bootstrap.get_snapshot().get("location_generation", 0)),
		bootstrap, _flow.common_world_origin_rebase_owner,
	)
	if not bool(armed_source.get("accepted", false)):
		_last_compose_result = armed_source.duplicate(true)
		cancel()
		return
	var armed := _flow._planetary_journey.arm_aurora_final_approach(
		_approach_source, region, _approach_envelope()
	)
	_last_compose_result = armed.duplicate(true)
	if not bool(armed.get("accepted", false)):
		cancel()


func _lease_surface_berth(region: Node3D) -> void:
	if is_instance_valid(_berth):
		return
	_berth = ShipBerth.new()
	_berth.name = "AuroraExplorationBerth"
	_berth.berth_id = &"aurora_exploration_pad"
	_berth.compatibility_tags = PackedStringArray(["small_craft", "medium_craft"])
	_berth.landing_half_extents = Vector3(14.0, 12.0, 16.0)
	_berth.assist_capture_center = Vector3(0.0, 30.0, 30.0)
	_berth.assist_capture_half_extents = Vector3(45.0, 60.0, 300.0)
	var bounds: AABB = _ship.get_landing_collision_report().get("local_bounds", AABB())
	_berth.dock_transform.origin.y = -bounds.position.y + 0.03
	region.add_child(_berth)
	_surface_token = _berth.try_reserve(_ship, _ship.get_ship_definition())


func _present_aurora_environment() -> void:
	_flow.world.visible = false
	var environment := _flow.aurora_streaming_bootstrap.get_scene_environment() \
		if is_instance_valid(_flow.aurora_streaming_bootstrap) else null
	if environment != null and _flow.is_inside_tree():
		_flow.get_viewport().world_3d.environment = environment


## The authored corridor, read from Aurora's own landing-region resource. These
## are exactly the nine typed keys `PlanetaryCruiseProductionBinding` validates,
## and nothing in them is Ember's.
func _approach_envelope() -> Dictionary:
	var collision := _ship.get_landing_collision_report()
	return {
		"corridor_id": StringName(_LANDING_REGION.approach_corridor_ids[0]),
		"target_pad_id": StringName(
			_LANDING_REGION.approach_corridor_target_pad_ids[0]
		),
		"corridor_transform_region_local_m":
			_LANDING_REGION.approach_corridor_transforms_region_local_m[0],
		"corridor_half_extents_m": _LANDING_REGION.approach_corridor_half_extents_m[0],
		"entry_position_half_extents_m": APPROACH_ENTRY_POSITION_HALF_EXTENTS_M,
		"maximum_speed_mps": APPROACH_MAXIMUM_SPEED_MPS,
		"maximum_attitude_degrees": APPROACH_MAXIMUM_ATTITUDE_DEGREES,
		"hull_margin_m": APPROACH_HULL_MARGIN_M,
		"collision_bounds": collision.get("local_bounds", AABB()) as AABB,
	}.duplicate(true)


## The completed production approach hands over here. The visit takes the real
## berth lease it already holds and asks HeroShip for a real assisted landing;
## nothing manufactures a landed flag.
func _begin_touchdown() -> void:
	if is_instance_valid(_approach_source):
		_approach_source.retire(&"aurora_touchdown")
	if is_instance_valid(_flow.planetary_cruise_binding):
		_flow.planetary_cruise_binding.request_disengage(
			_flow.planetary_cruise_binding.get_generation(), true
		)
	state = &"landing"
	_landing_elapsed = 0.0
	if _surface_token.is_empty() or not is_instance_valid(_berth):
		_last_leg_result = {
			"accepted": false, "reason": &"aurora_berth_unavailable",
		}
		cancel()
		return
	var requested := _ship.request_berth_landing(_berth)
	_last_leg_result = {
		"accepted": requested,
		"reason": &"aurora_berth_landing_requested" if requested
			else &"aurora_berth_landing_refused",
		"ship_region_local": _landing_region().to_local(_ship.global_position)
			if is_instance_valid(_landing_region()) else Vector3.INF,
		"landing_report": _ship.get_landing_contract_report(),
		"berth": _berth.audit() if _berth.has_method(&"audit") else {},
	}
	if not requested:
		cancel()


func _complete_restore(loaded: Node3D) -> void:
	var region := loaded.get_node_or_null(LANDING_REGION_PATH) as Node3D
	if not is_instance_valid(region) or not region.is_inside_tree():
		cancel()
		return
	_surface = loaded
	_lease_surface_berth(region)
	if _surface_token.is_empty():
		cancel()
		return
	_present_aurora_environment()
	_ship.global_transform = _berth.get_dock_transform()
	_ship.reset_physics_interpolation()
	_ship.velocity = Vector3.ZERO
	if not _ship.request_berth_landing(_berth):
		cancel()
		return
	var shutdown := _ship.request_engine_stop.bind(false)
	if not _ship.landing_completed.is_connected(shutdown):
		_ship.landing_completed.connect(shutdown, CONNECT_ONE_SHOT)
	_ship.set_piloted(false)
	_flow.active_ship = _ship
	_flow._piloting = false
	_flow._transition_busy = false
	_flow.phase = GameFlow.Phase.APPROACH_SHIP
	_flow.player.force_recovery_to_on_foot(_ship.get_exit_transform())
	_flow.player.set_camera_active(true)
	_flow.player.set_control_enabled(true)
	_flow.hud.set_mode("on-foot")
	_flow.audio.set_on_foot(true)
	state = &"surface"
	_flow.hud.set_objective(
		"Back on Aurora - explore, then board your ship to return", "AURORA SURFACE"
	)
	_flow.hud.toast(
		"Aurora visit resumed", "Your ship is on the pad where you left it", 3.0
	)


func _note_leg_failure(reason: StringName) -> void:
	_last_leg_result = {
		"accepted": false,
		"reason": reason,
		"elapsed": _landing_elapsed,
		"landing_report": _ship.get_landing_contract_report() \
			if is_instance_valid(_ship) else {},
		"telemetry": _ship.get_telemetry() if is_instance_valid(_ship) else {},
	}


func _landing_region() -> Node3D:
	if not is_instance_valid(_surface) or not _surface.is_inside_tree():
		return null
	return _surface.get_node_or_null(LANDING_REGION_PATH) as Node3D


func _landing_region_origin() -> Vector3:
	var region := _landing_region()
	return region.global_position if is_instance_valid(region) else Vector3.INF


## The live world position of Aurora's canonical navigation anchor, decoded from
## the cruise binding's own absolute destination in the current frame.
func _navigation_standoff_target() -> Vector3:
	var bootstrap := _flow.aurora_streaming_bootstrap
	var cruise := _flow.planetary_cruise_binding
	if not is_instance_valid(bootstrap) or not is_instance_valid(cruise):
		return Vector3.INF
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return Vector3.INF
	var canonical := cruise.get_snapshot().get(
		"canonical_destination_orbital", {}
	) as Dictionary
	if canonical.is_empty():
		return Vector3.INF
	var decoded := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	)
	if not bool(decoded.get("accepted", false)):
		return Vector3.INF
	return decoded.get("position", Vector3.INF) as Vector3



## Describes an in-progress visit for the interrupted-visit store, or nothing
## when there is nothing worth coming back to. A pilot who has already asked to
## go home is deliberately not brought back.
func capture_interrupted_visit() -> Dictionary:
	if not is_active() or state in [
		&"outbound", &"corridor", &"restoring", &"retiring",
		&"return_cruise", &"return_landing",
	]:
		return {}
	if not is_instance_valid(_ship):
		return {}
	var berth_id := String(_ship.get_home_berth_id())
	if berth_id.strip_edges().is_empty():
		return {}
	return {
		"visit_state": String(state),
		"craft_home_berth_id": berth_id,
		"on_foot": not _flow.player.is_seated(),
	}


## Puts a pilot back on Aurora after a whole-`Main` re-entry.
##
## The record names only which craft and which phase; everything physical is
## re-established through the same production calls a fresh visit uses. The
## craft is stood on the authored pad and given a real assisted landing through
## a real berth lease, and the pilot is recovered on foot beside its ramp, which
## is the one embodiment that needs no seat transition to be correct. From there
## the ordinary re-board and the ordinary Destination Board return both work.
func restore_interrupted_visit(visit: Dictionary) -> Dictionary:
	if is_active():
		return {"accepted": false, "reason": &"aurora_visit_already_active"}
	if not is_instance_valid(_flow.world) or not is_instance_valid(_flow.player):
		return {"accepted": false, "reason": &"aurora_visit_host_unavailable"}
	var berth_id := StringName(str(visit.get("craft_home_berth_id", "")))
	var craft := _craft_for_home_berth(berth_id)
	if not is_instance_valid(craft) or craft.is_destroyed():
		return {"accepted": false, "reason": &"aurora_visit_craft_unavailable"}
	var home := _flow.world.get_berth_node(berth_id) as ShipBerth
	if not is_instance_valid(home):
		return {"accepted": false, "reason": &"aurora_visit_home_berth_unavailable"}
	var station_visible := _flow.world.visible
	var station_environment := _flow.get_viewport().world_3d.environment
	_flow._release_ship_berth(craft)
	# Streaming a world in takes physics ticks and committed origin transactions,
	# so a resume is admitted here and completed by the visit's own cadence. It
	# is admitted without a cruise: a resumed visit is already on the ground and
	# has no approach left to fly.
	_last_admission = _flow._planetary_journey.admit_aurora_visit(craft, false)
	if not bool(_last_admission.get("accepted", false)):
		_flow._reserve_berth_for_ship(craft, berth_id, false)
		return {
			"accepted": false,
			"reason": &"aurora_visit_restore_refused",
			"admission_reason": _last_admission.get("reason", &"unknown"),
		}
	_ship = craft
	_home = home
	# The resumed craft is the one the pilot flew out in, not whichever craft a
	# fresh `Main` happens to start with. Adopt it before the visit's own
	# cadence starts, because that cadence refuses to run for another craft.
	_flow.active_ship = craft
	_departure = craft.global_transform
	_station_visible = station_visible
	_station_environment = station_environment
	_ship.request_engine_stop(false)
	_ship.velocity = Vector3.ZERO
	_staging_events = 0
	_orbit_ticks = 0
	_corridor_ticks = 0
	_departure_ticks = 0
	_committed_rebases_outbound = 0
	state = &"restoring"
	return {
		"accepted": true,
		"reason": &"aurora_visit_restoring",
		"craft_home_berth_id": String(berth_id),
		"visit_state": String(state),
	}


func _craft_for_home_berth(berth_id: StringName) -> HeroShip:
	if String(berth_id).strip_edges().is_empty():
		return null
	for candidate in _flow.ships:
		var craft := candidate as HeroShip
		if is_instance_valid(craft) and craft.get_home_berth_id() == berth_id:
			return craft
	return null

func _begin_return() -> void:
	_release_surface_lease()
	_ship.call(&"_end_landing_for_lifecycle", &"aurora_return")
	_ship.request_engine_stop(false)
	_ship.velocity = Vector3.ZERO
	state = &"return_cruise"
	_departure_ticks = 0
	_flow.hud.set_paused(false)
	_flow.hud.toast(
		"Returning to Mudds", "Aurora streams out behind you on the way home", 2.0
	)

func _arrive_home() -> void:
	_clear_surface()
	_flow._planetary_journey.retire_aurora_visit()
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
	_clear_transition_fade()
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

## Releases this visit's lease and its own nodes. The streamed world itself is
## never freed here: it belongs to the production streaming coordinator, which
## unloads it once the departing craft leaves its envelope.
func _release_surface_lease() -> void:
	if is_instance_valid(_approach_source):
		_approach_source.retire(&"aurora_visit_ended")
		_approach_source.queue_free()
	_approach_source = null
	if is_instance_valid(_berth):
		if not _surface_token.is_empty():
			_berth.release(_ship, _surface_token)
		if is_instance_valid(_berth.get_parent()):
			_berth.get_parent().remove_child(_berth)
		_berth.queue_free()
	_berth = null
	_surface_token = &""


func _clear_surface() -> void:
	_release_surface_lease()
	if is_instance_valid(_flow.world):
		_flow.world.visible = _station_visible
	if _flow.is_inside_tree():
		_flow.get_viewport().world_3d.environment = _station_environment
	_surface = null

func cancel() -> void:
	if not is_active():
		return
	if state in [&"outbound", &"corridor", &"landing"]:
		# Revoking travel leaves the same live pilot in direct control at the
		# current pose. Recovery/return placements are not cancellation movement.
		_clear_transition_fade()
		if is_instance_valid(_ship):
			_ship.call(&"_end_landing_for_lifecycle", &"aurora_cancelled")
		_flow._planetary_journey.retire_aurora_visit()
		_clear_surface()
		state = &"idle"
		_flow._sync_planetary_cruise_hud()
		_ship = null
		_home = null
		return
	_clear_transition_fade()
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
	var recovery := (
		_flow.world.get_player_spawn() as Transform3D
		if is_instance_valid(_flow.world) and _flow.world.is_inside_tree()
		else _departure
	)
	if is_instance_valid(_ship) and not _ship.is_destroyed():
		_ship.set_piloted(false)
		_ship.request_engine_stop(false)
		_ship.velocity = Vector3.ZERO
		_ship.global_transform = _departure
		# Park the craft on its home pad's live pose. The touchdown that
		# re-establishes occupancy is deliberately deferred to the end of the
		# wind-down: the common origin is still out at Aurora at this instant,
		# and a landing assist started here would be running across the very
		# rebase that brings the yard back under the craft.
		if is_instance_valid(_home) and _home.is_inside_tree():
			_ship.global_transform = _home.get_dock_transform()
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
	# The actors are home, but the common origin is still out at Aurora and
	# Aurora is still resident. Keep the lane running for a bounded wind-down so
	# the production streaming coordinator commits the rebase back to the yard
	# and unloads Aurora itself, rather than this visit deleting a world it does
	# not own and leaving the origin twelve thousand kilometres from the station.
	state = &"retiring"
	_retire_ticks = 0


## The bounded wind-down. It moves nothing: the actors are already home, and the
## lane's own streaming observation is what retires Aurora.
func _advance_retiring() -> void:
	_retire_ticks += 1
	# Hold the craft and the pilot on the yard's live poses so the lane's own
	# observation is what asks for the rebase home.
	if is_instance_valid(_ship) and is_instance_valid(_home) and _home.is_inside_tree():
		_ship.global_transform = _home.get_dock_transform()
		_ship.velocity = Vector3.ZERO
		if is_instance_valid(_flow.player) and not _flow.player.is_seated():
			_flow.player.teleport_to(_ship.get_exit_transform())
	var bootstrap := _flow.aurora_streaming_bootstrap
	var resident := is_instance_valid(bootstrap) \
		and is_instance_valid(bootstrap.get_loaded_instance())
	if resident and _retire_ticks <= DEPARTURE_TICK_BUDGET:
		return
	_flow._planetary_journey.retire_aurora_visit()
	# The yard is back under the craft, so the ordinary home touchdown can run.
	# One normal physical landing re-establishes occupancy; no landed flag is
	# manufactured anywhere in this path.
	if is_instance_valid(_ship) and not _ship.is_destroyed() \
			and is_instance_valid(_home) and _home.is_inside_tree() \
			and _home.can_accept(_ship.get_ship_definition(), _ship):
		_ship.global_transform = _home.get_dock_transform()
		_ship.reset_physics_interpolation()
		if _flow._reserve_berth_for_ship(_ship, _home.berth_id, false):
			if _ship.request_berth_landing(_home):
				var shutdown := _ship.request_engine_stop.bind(false)
				if not _ship.landing_completed.is_connected(shutdown):
					_ship.landing_completed.connect(shutdown, CONNECT_ONE_SHOT)
			if is_instance_valid(_flow.player) and not _flow.player.is_seated():
				_flow.player.force_recovery_to_on_foot(_ship.get_exit_transform())
				_flow.player.set_camera_active(true)
				_flow.player.set_control_enabled(true)
	state = &"idle"
	_ship = null
	_home = null
	_flow._sync_planetary_cruise_hud()


func _present_transition_fade(opacity: float) -> void:
	_fade_opacity = opacity
	if not is_instance_valid(_fade_layer):
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "AuroraVisitTransition"
		_fade_layer.layer = 7
		_fade = ColorRect.new()
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_layer.add_child(_fade)
		_flow.add_child(_fade_layer)
	_fade.color = Color(0.005, 0.018, 0.028, opacity)


func _clear_transition_fade() -> void:
	_fade_opacity = 0.0
	if is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade = null
