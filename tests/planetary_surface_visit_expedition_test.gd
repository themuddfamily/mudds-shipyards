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


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check_profiles()
	for world: Dictionary in WORLDS:
		await _visit(world)
	await _finish()


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
	print("%s: %d assertions" % [SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions])
	quit(0 if _failures.is_empty() else 1)
