extends SceneTree

## Interior/exterior ambience cross-fades on an atmosphere world.
##
## Boarding, disembarking, opening the canopy and walking into a craft's cabin
## ease a continuous interior blend instead of switching; the Aurora binding
## and live voices follow that blend monotonically (exterior quieter and
## low-passed inside, cabin bed louder); the blend resets on unload and a
## fresh arrival starts in place rather than mid-fade.

const FlightEffectsScript := preload(
	"res://scripts/world/planetary_atmosphere_flight_effects.gd"
)
const BINDING := preload("res://scripts/audio/aurora_surface_audio_binding.gd")
const WORLD_SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")
const COMPOSITION_SCENE := preload(
	"res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn"
)
const BODY_RADIUS_M := 120_000.0
const TICK := 1.0 / 60.0


class StubPlayer:
	extends Node3D
	var seated := false

	func is_seated() -> bool:
		return seated


class StubInteriorFrame:
	extends Node


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
	_test_binding_blend_is_continuous()
	await _test_live_voices_cross_fade()
	await _test_flight_effects_eases_transitions()
	if _failures.is_empty():
		print("PASS planetary_interior_exterior_audio_transition_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL planetary_interior_exterior_audio_transition_test (%d/%d failed)" % [
			_failures.size(), _assertions,
		])
		quit(1)


func _snapshot(generation: int, blend: float) -> Dictionary:
	return {
		"generation": generation,
		"weather_intensity_unitless": 0.6,
		"water_exposure_unitless": 0.6,
		"day_night_unitless": 0.5,
		"settlement_activity_unitless": 0.0,
		"wind_strength_unitless": 0.9,
		"ship_perspective": &"exterior",
		"interior_blend_unitless": blend,
	}


func _test_binding_blend_is_continuous() -> void:
	var binding := BINDING.new()
	binding.attach()
	var winds: Array[float] = []
	var cutoffs: Array[float] = []
	var generation := 0
	for step in 11:
		var blend := float(step) / 10.0
		var result := binding.present_snapshot(_snapshot(generation, blend)) as Dictionary
		generation += 1
		_check(bool(result.get("accepted", false)), "blend %.1f is accepted" % blend)
		var mix := binding.get_snapshot().get("mix", {}) as Dictionary
		winds.append(float(mix.get("wind", -1.0)))
		cutoffs.append(float(mix.get("low_pass_hz", -1.0)))
	var monotonic := true
	var largest_step := 0.0
	for index in range(1, winds.size()):
		monotonic = monotonic and winds[index] <= winds[index - 1] \
			and cutoffs[index] <= cutoffs[index - 1]
		largest_step = maxf(largest_step, winds[index - 1] - winds[index])
	_check(monotonic, "exterior wind gain and cutoff fall monotonically as the blend rises")
	_check(largest_step < 0.1, "no single 10% blend step jumps the exterior gain")
	_check(
		cutoffs[0] > 10_000.0 and cutoffs[10] <= BINDING.SEALED_CABIN_LOW_PASS_HZ + 0.01,
		"open air is bright; a sealed cabin low-passes the exterior below %.0f Hz"
			% BINDING.SEALED_CABIN_LOW_PASS_HZ
	)
	_check(
		is_equal_approx(float(binding.get_snapshot().get("interior_blend", -1.0)), 1.0),
		"the binding publishes the applied interior blend"
	)
	_check(
		binding.present_snapshot(_snapshot(generation, 1.4)).get("reason", &"")
			== &"invalid_interior_blend",
		"an out-of-range blend is refused"
	)
	binding.detach()
	_check(
		float(binding.get_snapshot().get("interior_blend", -1.0)) == 0.0,
		"unload resets the interior blend"
	)


func _test_live_voices_cross_fade() -> void:
	var world := WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	var exterior := world.get_node(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	var interior := world.get_node(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	world.present_surface_audio_snapshot(_snapshot(1, 0.0))
	var outside_exterior := exterior.volume_db
	_check(exterior.playing and not interior.playing, "outside plays only the exterior bed")
	world.present_surface_audio_snapshot(_snapshot(2, 0.5))
	var mid_exterior := exterior.volume_db
	var mid_interior := interior.volume_db
	_check(
		exterior.playing and interior.playing and mid_exterior < outside_exterior,
		"half way through boarding both beds play, the exterior already quieter"
	)
	world.present_surface_audio_snapshot(_snapshot(3, 1.0))
	_check(
		interior.volume_db > mid_interior and exterior.volume_db < mid_exterior
			and interior.volume_db > exterior.volume_db,
		"sealed in, the cabin bed leads a muffled exterior"
	)
	world.queue_free()
	await process_frame


func _test_flight_effects_eases_transitions() -> void:
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
	var player := StubPlayer.new()
	root.add_child(player)
	player.global_position = Vector3(0.0, BODY_RADIUS_M + 2.0, 0.0)
	await process_frame
	var effects := FlightEffectsScript.new()

	effects.advance(TICK, null, false, player, hud, [source])
	_check(
		float(effects.get_snapshot().audio.smoothed_interior_blend_unitless) == 0.0,
		"arriving on foot starts fully outside, not mid-fade"
	)
	player.seated = true
	effects.advance(TICK, null, false, player, hud, [source])
	var first := float(effects.get_snapshot().audio.smoothed_interior_blend_unitless)
	_check(first > 0.0 and first < 0.05, "boarding begins a gradual cross-fade (%.4f)" % first)
	for _i in roundi(FlightEffectsScript.INTERIOR_CROSSFADE_SECONDS / TICK) + 2:
		effects.advance(TICK, null, false, player, hud, [source])
	_check(
		is_equal_approx(float(effects.get_snapshot().audio.smoothed_interior_blend_unitless), 1.0),
		"the boarding fade completes to a sealed cabin in about a second"
	)
	var last_state := source.states[source.states.size() - 1] as Array
	_check(is_equal_approx(float(last_state[0]), 1.0), "the source receives the eased blend")

	player.seated = false
	player.set_meta(FlightEffectsScript.MOVING_INTERIOR_OWNER_META, weakref(_frame()))
	for _i in 180:
		effects.advance(TICK, null, false, player, hud, [source])
	_check(
		is_equal_approx(
			float(effects.get_snapshot().audio.interior_blend_unitless),
			FlightEffectsScript.INTERIOR_BLEND_WALKABLE_CABIN
		),
		"standing in a walkable cabin settles on the cabin blend"
	)
	player.remove_meta(FlightEffectsScript.MOVING_INTERIOR_OWNER_META)
	effects.advance(TICK, null, false, player, hud, [source])
	var leaving := float(effects.get_snapshot().audio.interior_blend_unitless)
	_check(
		leaving < FlightEffectsScript.INTERIOR_BLEND_WALKABLE_CABIN and leaving > 0.7,
		"stepping outside fades rather than cuts"
	)

	body.queue_free()
	await process_frame
	effects.advance(TICK, null, false, player, hud, [source])
	_check(
		not effects.is_active() and source.cleared == 1
			and float(effects.get_snapshot().audio.interior_blend_unitless) == -1.0,
		"unloading the atmosphere world resets the blend and clears the source"
	)


var _held_frame: StubInteriorFrame


func _frame() -> StubInteriorFrame:
	if _held_frame == null:
		_held_frame = StubInteriorFrame.new()
		root.add_child(_held_frame)
	return _held_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
