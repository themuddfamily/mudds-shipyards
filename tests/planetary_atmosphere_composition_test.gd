extends SceneTree

const COMPOSITION_SCENE := preload("res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn")
const WORLD := preload("res://assets/world/planets/aurora_temperate_world.tres")
const ATMOSPHERE := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
const TERRAIN := preload("res://assets/world/planets/aurora_temperate_terrain.tres")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition := COMPOSITION_SCENE.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(composition)
	await process_frame
	var validator := PlanetaryWorldCompositionValidator.new()
	var validation := validator.validate_composition(WORLD, ATMOSPHERE, TERRAIN)
	_check(
		WORLD.is_definition_valid() and ATMOSPHERE.is_definition_valid()
		and TERRAIN.is_profile_valid() and bool(validation.valid),
		"new Aurora resource triple is individually and jointly valid"
	)
	_check(
		composition.get_world_environment().environment == null
		and not composition.is_processing() and not composition.is_physics_processing(),
		"unconfigured standalone composition has no installed environment or cadence"
	)
	var configured := composition.configure()
	_check(
		configured.accepted and configured.generation == 1
		and composition.get_world_environment().environment
		== composition.get_atmosphere_rig().get_scene_environment()
		and bool(composition.audit().valid),
		"successful configuration installs only the rig-owned Environment"
	)
	var observation := {
		"body_local_observer_m": Vector3.UP * 123000.0,
		"view_direction_body_local": Vector3.FORWARD,
		"fog_path_distance_m": 12000.0,
		"speed_mps": 200.0,
		"weather_scalar": 1.0,
		"cloud_scalar": 1.0,
		"caller_time_seconds": 0.0,
	}
	_check(
		composition.present_observation(observation, 1).accepted
		and composition.configure().reason == &"already_configured",
		"caller-owned body-local observation reaches the configured rig once"
	)
	var original := composition.get_world_environment().environment
	root.remove_child(composition)
	await process_frame
	_check(
		composition.get_world_environment().environment == null,
		"whole composition detach restores its WorldEnvironment baseline"
	)
	root.add_child(composition)
	await process_frame
	_check(
		composition.get_world_environment().environment == original
		and bool(composition.audit().valid),
		"whole composition re-entry reapplies the retained rig Environment"
	)
	composition.queue_free()
	await process_frame
	print("PLANETARY_ATMOSPHERE_COMPOSITION_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_ATMOSPHERE_COMPOSITION_TEST_OK")
		quit(0)
	print("PLANETARY_ATMOSPHERE_COMPOSITION_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)
