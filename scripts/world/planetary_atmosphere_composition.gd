class_name PlanetaryAtmosphereComposition
extends Node3D

## Explicit standalone owner that installs one configured rig Environment into
## its sibling WorldEnvironment. It owns no clock, camera, streaming, gameplay,
## or production-world binding.

const COMPONENT_ID: StringName = &"planetary-atmosphere-composition"
const SCENE_PATH := "res://scenes/world/components/aurora_temperate_atmosphere_composition.tscn"

@export var world_definition: PlanetaryWorldDefinition
@export var atmosphere_profile: PlanetaryAtmosphereProfile
@export var terrain_profile: PlanetaryTerrainProfile

var _configured := false
var _generation := 0
var _baseline_environment: Environment


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	var target := get_world_environment()
	_baseline_environment = target.environment if target != null else null


func _exit_tree() -> void:
	if _configured:
		var target := get_world_environment()
		if target != null:
			target.environment = _baseline_environment


func _enter_tree() -> void:
	if _configured:
		var target := get_world_environment()
		var rig := get_atmosphere_rig()
		if target != null and rig != null:
			target.environment = rig.get_scene_environment()


func configure() -> Dictionary:
	if _configured:
		return {"accepted": false, "reason": &"already_configured"}
	var target := get_world_environment()
	var rig := get_atmosphere_rig()
	if target == null or rig == null:
		return {"accepted": false, "reason": &"authored_scene_contract_invalid"}
	if world_definition == null or atmosphere_profile == null or terrain_profile == null:
		return {"accepted": false, "reason": &"missing_composition_resource"}
	var result := rig.configure(world_definition, atmosphere_profile, terrain_profile)
	if not bool(result.get("accepted", false)):
		return result.duplicate(true)
	_baseline_environment = target.environment
	target.environment = rig.get_scene_environment()
	_configured = true
	_generation = rig.get_generation()
	return {"accepted": true, "reason": &"configured", "generation": _generation}.duplicate(true)


func present_observation(observation: Dictionary, expected_generation: int) -> Dictionary:
	if not _configured:
		return {"accepted": false, "reason": &"not_configured"}
	return get_atmosphere_rig().present_observation(observation, expected_generation)


func get_world_environment() -> WorldEnvironment:
	return get_node_or_null("WorldEnvironment") as WorldEnvironment


func get_atmosphere_rig() -> PlanetaryAtmosphereWorldRig:
	return get_node_or_null("PlanetaryAtmosphereWorldRig") as PlanetaryAtmosphereWorldRig


func audit() -> Dictionary:
	var target := get_world_environment()
	var rig := get_atmosphere_rig()
	var errors := PackedStringArray()
	if scene_file_path != SCENE_PATH or target == null or rig == null:
		errors.append("authored_scene_contract_invalid")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	if _configured and (
		target == null
		or rig == null
		or target.environment != (
			rig.get_scene_environment() if is_inside_tree() else _baseline_environment
		)
		or _generation != rig.get_generation()
	):
		errors.append("installed_environment_drift")
	return {
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"configured": _configured,
		"generation": _generation,
		"authority": {
			"renderer": true, "gameplay": false, "streaming": false,
			"save": false, "network": false, "physics": false,
			"world_generation": false, "terrain_generation": false,
			"collision_generation": false, "origin_shift": false,
			"weather_clock": false, "audio": false,
		},
	}.duplicate(true)
