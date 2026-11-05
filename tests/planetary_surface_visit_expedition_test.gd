extends SceneTree
## test-matrix-timeout-seconds: 900
## One profile-driven surface visit, run for each atmospheric world.
##
## Aurora and Rime are the same `PlanetarySurfaceVisitExpedition` configured by
## two `PlanetarySurfaceVisitProfile`s. For each world a fresh composed `Main`
## boards the Halyard, requests the visit, cruises out through the one
## surface-visit lane and lands on the profile's berth. The test then checks
## that everything world-specific came from that world's profile - lane world,
## streaming pair, berth identity, copy, peer refusal - that the atmosphere
## flight effects bind to the resident world's own bootstrap (profile, weather
## scalar, advancing weather clock, interior blend)
## and that the resident composition audits valid. Abandoning the landed visit
## winds the lane down and unloads the world.

const MAIN := preload("res://scenes/main.tscn")
const SUCCESS_MARKER := "PLANETARY_SURFACE_VISIT_EXPEDITION_TEST_OK"
const FAILURE_MARKER := "PLANETARY_SURFACE_VISIT_EXPEDITION_TEST_FAILED"
const RESIDENCY_SUCCESS_MARKER := "RETIRED_WORLD_RESIDENCY_TEST_OK"
const RESIDENCY_FAILURE_MARKER := "RETIRED_WORLD_RESIDENCY_TEST_FAILED"
const BASE_SCRIPT := preload("res://scripts/game/planetary_surface_visit_expedition.gd")
const AURORA_EXPEDITION := preload("res://scripts/game/aurora_expedition.gd")
const RIME_EXPEDITION := preload("res://scripts/game/rime_expedition.gd")

const WORLDS := [
	{
		"label": "Aurora",
		"owner": &"_aurora_expedition",
		"peer": &"_rime_expedition",
		"bootstrap": &"aurora_streaming_bootstrap",
		"world_id": &"aurora_temperate_world",
		"berth_id": &"aurora_exploration_pad",
		"weather_scalar": 0.4,
		"peer_copy": "AURORA EXPEDITION ACTIVE",
	},
	{
		"label": "Rime",
		"owner": &"_rime_expedition",
		"peer": &"_aurora_expedition",
		"bootstrap": &"rime_streaming_bootstrap",
		"world_id": &"rime_glacial_world",
		"berth_id": &"rime_icefall_pad",
		"weather_scalar": 0.66,
		"peer_copy": "RIME EXPEDITION ACTIVE",
	},
]

var _failures: Array[String] = []
var _assertions := 0
var _residency_only := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_residency_only = "--retired-world-residency-only" in OS.get_cmdline_user_args()
	if _residency_only:
		for world: Dictionary in WORLDS:
			await _retired_residency(world)
		await _finish()
		return
	_check_profiles()
	for world: Dictionary in WORLDS:
		await _visit(world)
	await _finish()


## Bounded integration fixture, not a shared cancellation journey: ordinary
## boarding/departure precedes a staged actor position. Ship physics is then
## frozen and the loaded expedition's corridor state is explicitly staged.
## Main, its sole origin owner, streaming bindings and loaders keep ticking.
## No target scene is manually unloaded or freed by this driver. Every API used
## here predates residency wind-down, so the same fixture runs on old runtime.
func _retired_residency(world: Dictionary) -> void:
	var label := str(world.label)
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _shut_down(game)
		return
	await _prepare_bounded_outbound(game, world)
	# The ship must consume released departure input and the cruise's current
	# envelope before the fixture freezes it. has_manual_flight_intent reads its
	# last consumed command; disabling ship physics first can strand the visit
	# behind _ensure_outbound_cruise before source composition ever runs.
	for _i in 30:
		if not craft.has_manual_flight_intent():
			break
		await _residency_frames(1)
	var owner: RefCounted = game.get(world.owner)
	var peer: RefCounted = game.get(world.peer)
	var bootstrap := game.get(world.bootstrap) as PlanetaryStreamingBootstrap
	var binding := _residency_binding(game, world)
	var coordinator := bootstrap.get_node(^"WorldStreamingCoordinator") as WorldStreamingCoordinator
	var peer_profile: RefCounted = peer.get("profile")
	var peer_bootstrap := game.get(peer_profile.get("bootstrap_property")) as PlanetaryStreamingBootstrap
	var peer_binding := game.get(peer_profile.get("binding_property")) as PlanetaryStreamingProductionBinding
	_check(owner.request(), "%s residency fixture admits through the existing visit request" % label)
	for _i in 120:
		await _residency_frames(1)
		if is_instance_valid(bootstrap.get_loaded_instance()) \
				and is_instance_valid(owner.get("_approach_source")):
			break
	var surface := bootstrap.get_loaded_instance()
	var setup_visit := owner.call(&"get_visit_snapshot") as Dictionary
	var setup_cruise := game.planetary_cruise_binding.get_snapshot()
	var setup_controller := setup_cruise.get("controller", {}) as Dictionary
	var setup_attachment := craft.get_planetary_cruise_attachment_report()
	var setup_command := craft.get_last_ship_command()
	print("RETIRED_RESIDENCY_SETUP world=", world.world_id, " state=", owner.get("state"),
		" manual_intent=", craft.has_manual_flight_intent(),
		" command=", setup_command.to_dictionary() if setup_command != null else {},
		" cruise_requested=", game.planetary_cruise_binding.is_engagement_requested(),
		" controller_generation=", setup_controller.get("generation", -1),
		" controller_reason=", (setup_controller.get("last_result", {}) as Dictionary).get("reason", &""),
		" ship_state=", setup_attachment.get("state", &""), " speed=", craft.velocity.length(),
		" compose_reason=", (setup_visit.get("compose", {}) as Dictionary).get("reason", &""),
		" last_leg_reason=", (setup_visit.get("last_leg", {}) as Dictionary).get("reason", &""))
	_check(is_instance_valid(surface) and is_instance_valid(owner.get("_approach_source")),
		"%s staged approach has an actual streamed scene and visit-owned source" % label)
	if not is_instance_valid(surface) or not is_instance_valid(owner.get("_approach_source")):
		await _shut_down(game)
		return
	craft.set_physics_process(false)
	var terrain := surface.get_node_or_null(^"TerrainClipmap")
	_check(terrain != null, "%s streamed scene owns its terrain subtree" % label)
	var surface_ref: WeakRef = weakref(surface)
	var terrain_ref: WeakRef = weakref(terrain)
	var generation := bootstrap.get_location_generation()
	var source := craft.get_command_source()
	var stream_id := source.get_stream_id()
	var pilot := game.player
	var origin_owner := game.common_world_origin_rebase_owner
	owner.set("state", &"corridor")
	print("RETIRED_RESIDENCY_STAGING world=", world.world_id,
		" actor_position=", craft.global_position, " body_center=", bootstrap.global_position,
		" location_generation=", generation,
		" ship_physics=false corridor_state=staged live_Main_ticks=true")
	var pose := craft.global_transform
	var velocity := craft.velocity
	_check(owner.request(), "%s staged corridor uses the ordinary abandon request" % label)
	var immediate_preserved: bool = craft.global_transform == pose and craft.velocity == velocity \
		and game.player == pilot and pilot.is_seated() and craft.is_piloted() \
		and game._piloting and craft.get_command_source() == source \
		and source.get_stream_id() >= stream_id and owner.get("state") == &"idle" \
		and not game._planetary_journey.is_aurora_visit_active() \
		and owner.get("_berth") == null and owner.get("_approach_source") == null \
		and owner.get("_surface") == null \
		and not game.planetary_cruise_binding.is_engagement_requested()
	if not await _settle_residency_cancel(craft, owner, "%s initial cancel" % label):
		await _shut_down(game)
		return
	var held_ticks := int(binding.get_snapshot().get("physics_tick_count", -1))
	await _residency_frames(4)
	var inside_preserved: bool = bootstrap.get_loaded_instance() == surface \
		and bootstrap.get_location_generation() == generation
	var retired_observed_inside: bool = int(binding.get_snapshot().get("physics_tick_count", -1)) > held_ticks

	# Re-admission hands this exact resident generation back to its active lane.
	_check(_request_residency_visit(owner, craft, label), "%s can re-admit its resident world before wind-down finishes" % label)
	var active_ticks := int(binding.get_snapshot().get("physics_tick_count", -1))
	var active_frame := Engine.get_physics_frames()
	await _residency_frames(4)
	var readmit_single_cadence: bool = int(binding.get_snapshot().get("physics_tick_count", -1)) \
		- active_ticks == Engine.get_physics_frames() - active_frame
	var readmit_preserved: bool = bootstrap.get_loaded_instance() == surface \
		and bootstrap.get_location_generation() == generation
	owner.set("state", &"corridor")
	_check(owner.request(), "%s re-admitted approach cancels through the same request" % label)
	if not await _settle_residency_cancel(craft, peer, "%s second cancel" % label):
		await _shut_down(game)
		return
	_check(_request_residency_visit(peer, craft, label), "%s's other world can own the active lane during retirement" % label)
	await _residency_frames(4)
	var other_lane_hold: bool = bootstrap.get_loaded_instance() == surface
	var peer_ticks := int(peer_binding.get_snapshot().get("physics_tick_count", -1))
	var peer_frame := Engine.get_physics_frames()
	var origin_generation := bootstrap.get_coordinate_frame_for_session().get_generation()
	_stage_residency_actor(craft, peer_bootstrap)
	await _residency_frames(12)
	var report := coordinator.audit()
	print("RETIRED_RESIDENCY_UNLOAD world=", world.world_id,
		" generation_before=", generation, " generation_after=", bootstrap.get_location_generation(),
		" coordinator=", report, " binding=", binding.get_snapshot().get("last_tick_result", {}))
	# First assertion sensitive to the missing runtime integration: old runtime
	# reaches the same staged cut but leaves this exact generation resident.
	_check(not is_instance_valid(bootstrap.get_loaded_instance())
		and int(report.get("unload_count", 0)) > 0
		and bootstrap.get_location_generation() > generation,
		"%s retired world actually unloads through its coordinator outside the envelope" % label)
	_check(immediate_preserved and inside_preserved and other_lane_hold and retired_observed_inside,
		"%s cancellation preserves pilot/source/pose and keeps observing inside-envelope residency" % label)
	_check(readmit_single_cadence and readmit_preserved,
		"%s fresh admission replaces retirement ownership with exactly one active cadence" % label)
	_check((report.get("loading_records", []) as Array).is_empty()
		and (report.get("loaded_records", []) as Array).is_empty()
		and int(report.get("owned_instance_count", -1)) == 0,
		"%s coordinator clears loading and owned records" % label)
	await _residency_frames(4)
	_check(surface_ref.get_ref() == null and terrain_ref.get_ref() == null,
		"%s scene and terrain weakrefs expire after coordinator deferred free" % label)
	var peer_snapshot := peer_binding.get_snapshot()
	_check(int(peer_snapshot.get("physics_tick_count", -1)) - peer_ticks
		== Engine.get_physics_frames() - peer_frame
		and is_instance_valid(peer_bootstrap.get_loaded_instance())
		and game._planetary_journey.is_aurora_visit_active()
		and game._planetary_journey.get_visit_world_id() == peer_profile.get("world_id"),
		"%s retirement leaves the other active world's one cadence and resident scene intact" % label)
	var retired_snapshot := binding.get_snapshot()
	_check(bootstrap.get_coordinate_frame_for_session().get_generation() > origin_generation
		and int(retired_snapshot.get("bound_coordinate_frame_generation", -1))
			== bootstrap.get_coordinate_frame_for_session().get_generation()
		and retired_snapshot.get("last_world_streaming_position") == craft.global_position
		and int(retired_snapshot.get("last_actor_instance_id", -1)) == craft.get_instance_id()
		and game.common_world_origin_rebase_owner == origin_owner,
		"%s wind-down consumes the other lane's current translated actor sample under the sole origin owner" % label)
	var stopped_ticks := int(retired_snapshot.get("physics_tick_count", -1))
	var load_requests := int(report.get("load_request_count", -1))
	peer.set("state", &"corridor")
	_check(peer.request(), "%s fixture retires the other active approach normally" % label)
	if not await _settle_residency_cancel(craft, owner, "%s peer cancel" % label):
		await _shut_down(game)
		return
	await _residency_frames(4)
	_stage_residency_actor(craft, bootstrap)
	await _residency_frames(12)
	_check(int(binding.get_snapshot().get("physics_tick_count", -1)) == stopped_ticks
		and int(coordinator.audit().get("load_request_count", -2)) == load_requests
		and not is_instance_valid(bootstrap.get_loaded_instance()),
		"%s completed retirement stops cadence and never cold-loads on re-entering the envelope" % label)
	_check(game.player == pilot and pilot.is_seated() and game.active_ship == craft
		and craft.is_piloted() and game._piloting and craft.get_command_source() == source
		and source.get_stream_id() >= stream_id and not game._transition_busy
		and not game._landing_request_active and not craft.is_landing_active()
		and not game.planetary_cruise_binding.is_engagement_requested()
		and owner.get("state") == &"idle" and owner.get("_berth") == null
		and owner.get("_surface") == null and owner.get("_approach_source") == null,
		"%s wind-down never revives controls, approach, lease or visit authority" % label)
	await _shut_down(game)


func _residency_binding(game: GameFlow, world: Dictionary) -> PlanetaryStreamingProductionBinding:
	var owner: RefCounted = game.get(world.owner)
	var profile: RefCounted = owner.get("profile")
	return game.get(profile.get("binding_property")) as PlanetaryStreamingProductionBinding


## Cancellation requests the body's actual bounded brake. The immediate cut
## was already captured; now give that body real physics until its current
## lifecycle and the next owner's ordinary launch gate both permit admission.
## Observe readiness without repeatedly invoking an admission action.
func _settle_residency_cancel(craft: HeroShip, next_owner: RefCounted, label: String) -> bool:
	var before := craft.get_planetary_cruise_attachment_report()
	craft.set_physics_process(true)
	var ready := false
	for _i in 120:
		await _residency_frames(1)
		var current := craft.get_planetary_cruise_attachment_report()
		var runtime := next_owner.call(&"runtime_state") as Dictionary
		if current.get("state", &"") == HeroShip.PLANETARY_CRUISE_STATE_INACTIVE \
				and not craft.has_manual_flight_intent() and bool(runtime.get("action_enabled", false)):
			ready = true
			break
	craft.set_physics_process(false)
	var after := craft.get_planetary_cruise_attachment_report()
	print("RETIRED_RESIDENCY_CANCEL_SETTLED cut=", label,
		" before_state=", before.get("state", &""),
		" after_state=", after.get("state", &""), " after_reason=", after.get("reason", &""),
		" speed=", craft.velocity.length(), " next_runtime=", next_owner.call(&"runtime_state"))
	_check(ready, "%s consumes cancellation braking before the next owner action" % label)
	return ready


func _request_residency_visit(owner: RefCounted, craft: HeroShip, label: String) -> bool:
	var runtime := owner.call(&"runtime_state") as Dictionary
	var accepted := bool(owner.call(&"request"))
	var visit := owner.call(&"get_visit_snapshot") as Dictionary
	var attachment := craft.get_planetary_cruise_attachment_report()
	print("RETIRED_RESIDENCY_ADMISSION fixture=", label, " accepted=", accepted,
		" runtime_before=", runtime,
		" admission_reason=", (visit.get("admission", {}) as Dictionary).get("reason", &""),
		" last_leg_reason=", (visit.get("last_leg", {}) as Dictionary).get("reason", &""),
		" ship_state=", attachment.get("state", &""),
		" ship_reason=", attachment.get("reason", &""), " speed=", craft.velocity.length())
	return accepted


func _stage_residency_actor(craft: HeroShip, bootstrap: PlanetaryStreamingBootstrap) -> void:
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var decoded := frame.orbital_to_world_streaming_position(encoded.get("coordinate"), frame.get_generation())
	craft.global_transform = Transform3D(Basis.IDENTITY,
		(decoded.get("position", Vector3.INF) as Vector3) + Vector3.BACK * 70_000.0)
	craft.velocity = Vector3.ZERO
	craft.reset_physics_interpolation()


func _residency_frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame


## Both wrappers are the shared class; their profiles are complete, distinct
## and keep each world's public constants.
func _check_profiles() -> void:
	var aurora_profile: RefCounted = AURORA_EXPEDITION.make_profile()
	var rime_profile: RefCounted = RIME_EXPEDITION.make_profile()
	var aurora_script := load("res://scripts/game/aurora_expedition.gd") as Script
	var rime_script := load("res://scripts/game/rime_expedition.gd") as Script
	_check(aurora_script.get_base_script() == BASE_SCRIPT
			and rime_script.get_base_script() == BASE_SCRIPT,
		"Aurora and Rime visits are one shared surface-visit expedition")
	_check(aurora_profile.validate().is_empty() and rime_profile.validate().is_empty(),
		"both world profiles are complete")
	_check(AURORA_EXPEDITION.DESTINATION_ID == &"aurora_temperate_world"
			and RIME_EXPEDITION.DESTINATION_ID == &"rime_glacial_world"
			and aurora_profile.world_id == AuroraTemperateStreamingBootstrap.WORLD_ID
			and rime_profile.world_id == RimeGlacialStreamingBootstrap.WORLD_ID,
		"each profile admits its own world id and keeps its board destination id")
	_check(aurora_profile.reason("visit_refused") == &"aurora_visit_refused"
			and rime_profile.reason("visit_refused") == &"rime_visit_refused"
			and aurora_profile.landing_region != rime_profile.landing_region
			and aurora_profile.survey_script != rime_profile.survey_script,
		"reasons, landing regions and activities stay per world")


func _visit(world: Dictionary) -> void:
	var label := str(world.label)
	var game := await _boot()
	var craft := await _board_halyard(game)
	if craft == null:
		await _shut_down(game)
		return
	var owner: RefCounted = game.get(world.owner)
	var peer: RefCounted = game.get(world.peer)
	var profile: RefCounted = owner.get("profile")
	_check(owner.get_script().get_base_script() == BASE_SCRIPT
			and profile.world_id == world.world_id
			and profile.bootstrap_property == world.bootstrap
			and owner.get_profile_snapshot().get("berth_id") == world.berth_id,
		"%s's GameFlow visit runs the shared expedition with its own profile" % label)

	await _prepare_bounded_outbound(game, world)
	_check(bool(owner.request()), "%s's visit is admitted" % label)
	_check(str(owner.runtime_state().get("status_text", ""))
			== "ABANDON THE %s APPROACH" % label.to_upper(),
		"%s's in-flight copy comes from its profile" % label)
	var peer_state := peer.runtime_state() as Dictionary
	_check(not bool(peer_state.get("action_enabled", true))
			and str(peer_state.get("status_text", "")) == str(world.peer_copy),
		"the other world refuses with '%s' while %s holds the lane" % [world.peer_copy, label])
	_check(game._planetary_journey.get_visit_world_id() == world.world_id,
		"the shared lane is admitted for %s's world id" % label)

	await _wait_state(owner, &"landed", 6000)
	_check(owner.state == &"landed", "%s's visit lands" % label)
	if owner.state != &"landed":
		await _shut_down(game)
		return
	var bootstrap := game.get(world.bootstrap) as PlanetaryStreamingBootstrap
	var surface := owner.get("_surface") as Node3D
	var berth := owner.get("_berth") as ShipBerth
	_check(is_instance_valid(surface) and surface == bootstrap.get_loaded_instance()
			and is_instance_valid(berth) and berth.berth_id == world.berth_id
			and berth.get_occupant() == craft
			and berth.get_parent() == surface.get_node_or_null(^"LandingRegion"),
		"%s's craft holds the profile's berth on the streamed world's landing region" % label)

	# Atmosphere parity: the flight effects bind to the resident world's own
	# bootstrap and drive its weather clock and interior blend.
	for _i in 30:
		await physics_frame
	var effects := game.get_planetary_atmosphere_flight_effects_snapshot() as Dictionary
	var composition := bootstrap.call(&"get_atmosphere_composition") as PlanetaryAtmosphereComposition
	var audio := bootstrap.get_snapshot().get("surface_audio", {}) as Dictionary
	_check(bool(effects.get("active", false)) and composition != null
			and effects.get("profile_id") == composition.atmosphere_profile.profile_id
			and is_equal_approx(float(effects.get("weather_scalar", 0.0)), float(world.weather_scalar)),
		"%s's flight effects bind its own atmosphere profile and weather scalar" % label)
	_check(float(audio.get("weather_clock_seconds", 0.0)) > 0.0
			and float(audio.get("interior_blend", -1.0)) >= 0.0,
		"%s's bootstrap receives the advancing weather clock and interior blend" % label)
	_check(composition != null and bool(composition.audit().get("valid", false)),
		"%s's resident composition audits valid against its own world" % label)

	owner.cancel()
	for _i in 1500:
		await physics_frame
		if owner.state == &"idle":
			break
	for _i in 4:
		await physics_frame
	_check(owner.state == &"idle" and not game._planetary_journey.is_aurora_visit_active()
			and not is_instance_valid(bootstrap.get_loaded_instance())
			and not bool(game.get_planetary_atmosphere_flight_effects_snapshot().get("active", true)),
		"abandoning %s winds the lane down, unloads the world and resets the flight effects" % label)
	await _shut_down(game)


# --- harness (the Rime visit loop's, parameterised by world) ------------------


func _boot() -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.01
	game.boarding_motion_time = 0.01
	game.start_shift()
	await process_frame
	await physics_frame
	return game


func _shut_down(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"hover")
	Input.action_release(&"interact")
	game.queue_free()
	for _i in range(6):
		await process_frame
		await physics_frame


func _board_halyard(game: GameFlow) -> HeroShip:
	var craft := game.get_node_or_null("HalyardCrewTransport") as HeroShip
	if craft == null:
		_check(false, "the production Main composes the Halyard crew transport")
		return null
	game.player.teleport_to(Transform3D(craft.global_basis,
		craft.get_boarding_position() + craft.global_basis.y * 0.01))
	for _i in range(6):
		await physics_frame
		await process_frame
	Input.action_press(&"interact")
	await physics_frame
	await process_frame
	Input.action_release(&"interact")
	for _i in range(300):
		await physics_frame
		if game._piloting:
			break
	_check(game._piloting and game.player.is_seated() and game.active_ship == craft,
		"an ordinary boarding takes the Halyard's pilot seat")
	return craft if game._piloting else null


## Real departure, then one bounded placement 70 km short of the world's
## navigation anchor; the expedition itself then makes zero placements.
func _prepare_bounded_outbound(game: GameFlow, world: Dictionary) -> void:
	var craft := game.active_ship as HeroShip
	if bool(craft.get_telemetry().get("landed", true)):
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		for _i in 180:
			await physics_frame
		Input.action_release(&"hover")
		Input.action_release(&"move_forward")
		for _i in 4:
			await physics_frame
			await process_frame
	var activity := game.cinder_race_session.get_presentation_snapshot()
	if bool(activity.get("running", false)):
		game.cinder_race_session.fail(&"arrival_fixture_activity_ended",
			game.cinder_race_session.get_session_generation())
	var bootstrap := game.get(world.bootstrap) as PlanetaryStreamingBootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(
		bootstrap.get_navigation_destination().get("body_local_position_meters"), frame.get_generation())
	var anchor := frame.orbital_to_world_streaming_position(
		encoded.get("coordinate"), frame.get_generation()).get("position", Vector3.INF) as Vector3
	craft.global_transform = Transform3D(Basis.IDENTITY, anchor + Vector3.BACK * 70_000.0)
	craft.velocity = Vector3.ZERO
	craft.reset_physics_interpolation()
	for _i in 2:
		await physics_frame
		await process_frame


func _wait_state(owner: RefCounted, target: StringName, frames: int) -> void:
	for _i in frames:
		await physics_frame
		if owner.state == target:
			break
	if owner.state != target:
		print("WAIT ENDED: ", owner.state, " wanted ", target, " snapshot=", owner.get_visit_snapshot())


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _finish() -> void:
	paused = false
	await process_frame
	var success := RESIDENCY_SUCCESS_MARKER if _residency_only else SUCCESS_MARKER
	var failure := RESIDENCY_FAILURE_MARKER if _residency_only else FAILURE_MARKER
	print("%s: %d assertions" % [success if _failures.is_empty() else failure, _assertions])
	quit(0 if _failures.is_empty() else 1)
