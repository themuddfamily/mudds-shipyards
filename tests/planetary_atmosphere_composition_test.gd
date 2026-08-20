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
	var retry_composition := COMPOSITION_SCENE.instantiate() as PlanetaryAtmosphereComposition
	root.add_child(retry_composition)
	await process_frame
	var preserved_baseline := Environment.new()
	retry_composition.get_world_environment().environment = preserved_baseline
	var repaired_world := WORLD.duplicate(true) as PlanetaryWorldDefinition
	repaired_world.atmosphere_definition_id = &"mismatched_atmosphere"
	retry_composition.world_definition = repaired_world
	var rejected := retry_composition.configure()
	var rejected_audit := retry_composition.audit()
	var baseline_preserved := retry_composition.get_world_environment().environment == preserved_baseline
	repaired_world.atmosphere_definition_id = ATMOSPHERE.profile_id
	var repaired := retry_composition.configure()
	_check(
		not bool(rejected.accepted) and rejected.reason == &"invalid_atmospheric_composition"
		and baseline_preserved
		and not bool(rejected_audit.configured)
		and repaired.accepted
		and retry_composition.get_world_environment().environment
		== retry_composition.get_atmosphere_rig().get_scene_environment(),
		"rejected pre-install composition preserves baseline and repaired input retries into one install"
	)
	var retry_rig_environment := retry_composition.get_world_environment().environment
	root.remove_child(retry_composition)
	await process_frame
	_check(
		not retry_composition.is_inside_tree()
		and retry_composition.get_world_environment().environment == preserved_baseline
		and bool(retry_composition.audit().valid),
		"detach restores a baseline assigned after ready and before accepted installation"
	)
	root.add_child(retry_composition)
	await process_frame
	_check(
		retry_composition.get_world_environment().environment == retry_rig_environment
		and bool(retry_composition.audit().valid),
		"re-entry reapplies the rig Environment after late-baseline restoration"
	)
	retry_composition.queue_free()
	await process_frame
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
		not composition.is_inside_tree()
		and composition.get_world_environment().environment == null
		and bool(composition.audit().valid),
		"whole composition detach restores its WorldEnvironment baseline without audit drift"
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
		return
	print("PLANETARY_ATMOSPHERE_COMPOSITION_TEST_FAILED: %s" % ", ".join(_failures))
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)
