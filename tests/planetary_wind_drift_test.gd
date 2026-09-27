extends SceneTree

## Weather wind response on an atmosphere world.
##
## A piloted craft in ordinary flight below the wind ceiling receives a bounded
## lateral drift along Aurora's authored wind vector (the same vector the cloud
## shell is drawn moving with); landed, landing-assist and above-ceiling states
## are exactly zero; HeroShip carries the drift through one move only and never
## leaves it in `velocity`; and the weather clock that moves the clouds advances
## with the tick and resets with the world.

const FlightEffectsScript := preload(
	"res://scripts/world/planetary_atmosphere_flight_effects.gd"
)
const COMPOSITION_SCENE := preload(
	"res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn"
)
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const BODY_RADIUS_M := 120_000.0
const TICK := 1.0 / 60.0


class StubAtmosphereSource:
	extends Node
	var composition: PlanetaryAtmosphereComposition
	var world: Node3D
	var states: Array = []
	var cleared := 0

	func get_atmosphere_composition() -> PlanetaryAtmosphereComposition:
		return composition

	func get_loaded_instance() -> Node3D:
		return world

	func get_atmosphere_weather_scalar() -> float:
		return AuroraTemperateStreamingBootstrap.OBSERVATION_WEATHER_SCALAR

	func set_surface_atmosphere_state(
			blend: float, wind: float, clock: float
		) -> Dictionary:
		states.append([blend, wind, clock])
		return {"accepted": true}

	func clear_surface_atmosphere_state() -> void:
		cleared += 1


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := GameHUD.new()
	root.add_child(hud)
	var body := Node3D.new()
	root.add_child(body)
	var composition := COMPOSITION_SCENE.instantiate() as PlanetaryAtmosphereComposition
	body.add_child(composition)
	var source := StubAtmosphereSource.new()
	source.composition = composition
	source.world = body
	root.add_child(source)
	var craft := TORRENT_SCENE.instantiate() as HeroShip
	root.add_child(craft)
	await process_frame
	await physics_frame
	craft.set_physics_process(false)
	var profile := composition.atmosphere_profile
	var up := Vector3.UP

	# Ordinary piloted flight 800 m up, slow enough that entry heat is zero.
	_make_flying(craft)
	craft.global_position = Vector3(0.0, BODY_RADIUS_M + 800.0, 0.0)
	craft.velocity = Vector3(0.0, 0.0, -40.0)
	_check(craft.is_atmospheric_wind_drift_eligible(), "ordinary piloted flight is wind-eligible")
	var effects := FlightEffectsScript.new()
	for _i in 120:
		effects.advance(TICK, craft, true, null, hud, [source])
	var wind := effects.get_snapshot().wind as Dictionary
	var drift := wind.get("drift_world_mps", Vector3.ZERO) as Vector3
	var authored_lateral := (
		profile.wind_velocity_mps * source.get_atmosphere_weather_scalar()
	).slide(up)
	_check(
		drift.length() > 0.2 and drift.length() <= FlightEffectsScript.WIND_DRIFT_MAX_MPS,
		"a flown craft below the ceiling drifts, bounded (%.3f m/s)" % drift.length()
	)
	_check(absf(drift.normalized().dot(up)) < 0.01, "the drift is lateral: nothing pushes toward terrain")
	_check(
		drift.normalized().dot(authored_lateral.normalized()) > 0.9,
		"the drift follows the authored wind vector the clouds move with"
	)
	var pending := craft.get_atmospheric_wind_drift_snapshot().get("pending_mps", Vector3.ZERO) as Vector3
	_check(pending.is_equal_approx(drift), "the drift is submitted to the craft for its next flight tick")

	# HeroShip carries it through one move and removes it again.
	var own_velocity := craft.velocity
	var consumed := craft.call(&"_consume_atmospheric_wind_drift") as Vector3
	craft.velocity += consumed
	craft.call(&"_remove_atmospheric_wind_drift", consumed)
	_check(
		consumed.is_equal_approx(drift) and craft.velocity.is_equal_approx(own_velocity),
		"drift rides one move and never accumulates in the craft's own velocity"
	)
	_check(
		(craft.call(&"_consume_atmospheric_wind_drift") as Vector3) == Vector3.ZERO,
		"an unsubmitted tick applies no drift"
	)

	# Landed: exactly zero, both at the source and at the craft.
	craft.set("_landed", true)
	effects.advance(TICK, craft, true, null, hud, [source])
	_check(
		(effects.get_snapshot().wind.drift_world_mps as Vector3) == Vector3.ZERO
			and not craft.is_atmospheric_wind_drift_eligible(),
		"a landed craft receives exactly zero drift"
	)
	craft.submit_atmospheric_wind_drift(Vector3(3.0, 0.0, 0.0))
	_check(
		(craft.call(&"_consume_atmospheric_wind_drift") as Vector3) == Vector3.ZERO,
		"HeroShip itself refuses drift while landed"
	)
	craft.set("_landed", false)

	# Landing assist final approach: exactly zero.
	craft.set("_landing_active", true)
	effects.advance(TICK, craft, true, null, hud, [source])
	_check(
		(effects.get_snapshot().wind.drift_world_mps as Vector3) == Vector3.ZERO,
		"landing assist receives exactly zero drift"
	)
	craft.submit_atmospheric_wind_drift(Vector3(3.0, 0.0, 0.0))
	_check(
		(craft.call(&"_consume_atmospheric_wind_drift") as Vector3) == Vector3.ZERO,
		"HeroShip itself refuses drift during landing assist"
	)
	craft.set("_landing_active", false)

	# Not piloted (berthed / on foot): zero.
	effects.advance(TICK, craft, false, null, hud, [source])
	_check(
		(effects.get_snapshot().wind.drift_world_mps as Vector3) == Vector3.ZERO,
		"an unpiloted craft receives zero drift"
	)

	# Above the wind ceiling (cloud top + band) the target is zero.
	craft.global_position = Vector3(
		0.0,
		BODY_RADIUS_M + profile.cloud_top_altitude_m
			+ FlightEffectsScript.WIND_CEILING_BAND_M + 500.0,
		0.0
	)
	for _i in 600:
		effects.advance(TICK, craft, true, null, hud, [source])
	_check(
		(effects.get_snapshot().wind.drift_world_mps as Vector3).length() < 0.001,
		"no drift above the wind ceiling"
	)

	# The weather clock that moves the cloud shell advances and resets.
	var clocks := source.states.map(func(state: Array) -> float: return float(state[2]))
	_check(
		clocks.size() > 2 and float(clocks[clocks.size() - 1]) > float(clocks[0]),
		"the cloud weather clock advances with each tick"
	)
	effects.advance(TICK, craft, true, null, hud, [])
	_check(
		not effects.is_active() and source.cleared == 1
			and float(effects.get_snapshot().weather_clock_seconds) == 0.0,
		"leaving the atmosphere world resets the wind state and the source clock"
	)

	if _failures.is_empty():
		print("PASS planetary_wind_drift_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL planetary_wind_drift_test (%d/%d failed)" % [_failures.size(), _assertions])
		quit(1)


func _make_flying(craft: HeroShip) -> void:
	craft.set("_piloted", true)
	craft.set("_landed", false)
	craft.set("_landing_active", false)
	craft.set("_docked_latch", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
