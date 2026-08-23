class_name EmberAirlessSunBinding
extends Node3D

## Passive, caller-driven composition for Ember Moon's authored airless sun.
##
## The standalone rig owns one authored DirectionalLight3D target and one
## PlanetarySunPresentation adapter. A production caller must bind the exact
## loaded Ember generation, then submit an already-decoded body-local observer
## after any common-world origin rebase. This component never samples an actor,
## transforms an observation, advances time, or requests streaming/rebasing.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"ember-airless-sun-binding"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

const WORLD_ID: StringName = &"ember_moon"
const BODY_ID: StringName = &"ember_body"
const LOCATION_ID: StringName = &"ember_moon"
const ORBITAL_FRAME_ID: StringName = &"nearby_sector_orbital"
const WORLD_RESOURCE_PATH := "res://assets/world/planets/ember_moon_world.tres"
const RIG_SCENE_PATH := "res://scenes/world/components/ember_airless_sun_rig.tscn"
const DOCUMENTATION_PATH := "res://docs/EMBER_AIRLESS_SUN_BINDING.md"

const BODY_RADIUS_M := 120_000.0
const ORBITAL_CELL_SIZE_M := 1_000_000.0
const ORIGIN_SHIFT_THRESHOLD_M := 10_000.0
const RIG_NODE_NAME: StringName = &"EmberAirlessSunRig"
const LIGHT_NODE_NAME: StringName = &"SunLight"
const PRESENTATION_NODE_NAME: StringName = &"Presentation"

## The sun is statically authored over Ember's +Y landing pole. Godot emits a
## DirectionalLight3D along its local -Z axis, so the matching ray direction is
## body-local -Y. No runtime method may mutate either direction or transform.
const AUTHORED_BODY_TO_SUN_DIRECTION := Vector3.UP
const AUTHORED_EMITTED_LIGHT_DIRECTION := Vector3.DOWN
const AUTHORED_LIGHT_BASIS := Basis(
	Vector3.RIGHT,
	Vector3.FORWARD,
	Vector3.UP,
)
const AUTHORED_LIGHT_TRANSFORM := Transform3D(
	AUTHORED_LIGHT_BASIS,
	Vector3.ZERO,
)
const AUTHORED_BASELINE_ENERGY := 1.5
const AUTHORED_BASELINE_COLOR := Color(1.0, 0.75, 0.5, 1.0)

const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"atmosphere", "camera", "caller_observation_sampling",
	"coordinate_conversion", "direction_or_orientation_mutation",
	"directional_light_runtime_creation", "sun_ephemeris",
	"time_or_day_night_clock", "absolute_energy_or_lux",
	"calibrated_colorimetry", "temperature", "angular_distance", "shadows",
	"occlusion_query", "terrain_horizon", "cloud_or_weather",
	"environment_or_sky", "origin_or_rebase", "streaming_load_unload",
	"streaming_generation", "movement", "physics", "gameplay", "save",
	"network",
]
const CAPABILITY_KEYS := [
	"authored_airless_directional_light_target",
	"immutable_body_to_sun_direction", "immutable_light_orientation",
	"baseline_relative_sun_presentation", "post_rebase_generation_validation",
	"exact_streamed_root_identity_validation", "caller_driven_observations_only",
	"production_caller_wired", "runtime_target_creation",
	"runtime_orientation_mutation", "coordinate_conversion",
	"clock_or_ephemeris", "atmosphere", "shadow_or_occlusion",
]

const AUTHORITY := {
	"renderer": true,
	"gameplay": false,
	"streaming": false,
	"save": false,
	"network": false,
	"physics": false,
	"world_generation": false,
	"terrain_generation": false,
	"collision_generation": false,
	"origin_shift": false,
	"weather_clock": false,
	"audio": false,
}
const ADJACENT_AUTHORITY := {
	"atmosphere": false,
	"camera": false,
	"caller_observation_sampling": false,
	"coordinate_conversion": false,
	"direction_or_orientation_mutation": false,
	"directional_light_runtime_creation": false,
	"sun_ephemeris": false,
	"time_or_day_night_clock": false,
	"absolute_energy_or_lux": false,
	"calibrated_colorimetry": false,
	"temperature": false,
	"angular_distance": false,
	"shadows": false,
	"occlusion_query": false,
	"terrain_horizon": false,
	"cloud_or_weather": false,
	"environment_or_sky": false,
	"origin_or_rebase": false,
	"streaming_load_unload": false,
	"streaming_generation": false,
	"movement": false,
	"physics": false,
	"gameplay": false,
	"save": false,
	"network": false,
}
const CAPABILITIES := {
	"authored_airless_directional_light_target": true,
	"immutable_body_to_sun_direction": true,
	"immutable_light_orientation": true,
	"baseline_relative_sun_presentation": true,
	"post_rebase_generation_validation": true,
	"exact_streamed_root_identity_validation": true,
	"caller_driven_observations_only": true,
	"production_caller_wired": false,
	"runtime_target_creation": false,
	"runtime_orientation_mutation": false,
	"coordinate_conversion": false,
	"clock_or_ephemeris": false,
	"atmosphere": false,
	"shadow_or_occlusion": false,
}
const _EMBER_WORLD_DEFINITION := preload(WORLD_RESOURCE_PATH)

var _configured := false
var _binding_generation := 0
var _presentation_generation := 0
var _last_coordinate_frame_generation := 0
var _location_generation := 0
var _bootstrap_ref: WeakRef
var _loaded_root_ref: WeakRef
var _coordinate_frame: PlanetaryCoordinateFrame
var _bootstrap_instance_id := 0
var _loaded_root_instance_id := 0
var _coordinate_frame_instance_id := 0
var _rig_instance_id := 0
var _light_instance_id := 0
var _presentation_instance_id := 0
var _last_body_local_observer_m := Vector3.ZERO
var _last_presentation_result: Dictionary = {}
var _accepted_observation_count := 0
var _mutation_active := false


func _enter_tree() -> void:
	set_process(false)
	set_physics_process(false)


## Binds once to the exact live Ember streaming identities. The world must be
## the canonical checked-in airless resource; the bootstrap must own both the
## supplied frame and loaded root at the supplied current generations.
func configure(
		world: PlanetaryWorldDefinition,
		bootstrap: EmberMoonStreamingBootstrap,
		coordinate_frame: PlanetaryCoordinateFrame,
		loaded_root: EmberMoonAuthoredScene,
		expected_coordinate_frame_generation: Variant,
		expected_location_generation: Variant,
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if _configured:
		return _result(false, &"already_configured")
	var generation_result := _decode_generations(
		expected_coordinate_frame_generation,
		expected_location_generation,
	)
	if not bool(generation_result.get("accepted", false)):
		return _result(
			false,
			generation_result.get("reason", &"invalid_generation") as StringName,
		)
	var frame_generation := int(
		generation_result.get("coordinate_frame_generation", 0)
	)
	var location_generation := int(
		generation_result.get("location_generation", 0)
	)
	var preflight := _configuration_preflight(
		world,
		bootstrap,
		coordinate_frame,
		loaded_root,
		frame_generation,
		location_generation,
	)
	if not bool(preflight.get("accepted", false)):
		return _result(
			false,
			preflight.get("reason", &"configuration_rejected") as StringName,
		)

	var light := get_directional_light()
	var presentation := get_presentation()
	_mutation_active = true
	_configured = true
	_binding_generation = 1
	_last_coordinate_frame_generation = frame_generation
	_location_generation = location_generation
	_bootstrap_ref = weakref(bootstrap)
	_loaded_root_ref = weakref(loaded_root)
	_coordinate_frame = coordinate_frame
	_bootstrap_instance_id = bootstrap.get_instance_id()
	_loaded_root_instance_id = loaded_root.get_instance_id()
	_coordinate_frame_instance_id = coordinate_frame.get_instance_id()
	_rig_instance_id = get_instance_id()
	_light_instance_id = light.get_instance_id()
	_presentation_instance_id = presentation.get_instance_id()
	var presentation_result := presentation.configure(
		world,
		null,
		light,
		AUTHORED_BASELINE_ENERGY,
		AUTHORED_BASELINE_COLOR,
	)
	if not bool(presentation_result.get("accepted", false)):
		_clear_binding_state()
		_mutation_active = false
		return _result(false, &"sun_presentation_configuration_failed", {
			"presentation_reason": presentation_result.get("reason", &"unknown"),
		})
	_presentation_generation = presentation.get_generation()
	var postflight_reason := _live_composition_reason(
		frame_generation,
		location_generation,
	)
	_mutation_active = false
	if not postflight_reason.is_empty():
		return _result(false, &"configuration_identity_changed", {
			"identity_reason": postflight_reason,
		})
	return _result(true, &"configured")


## Presents one caller-owned, already body-local observation after any rebase.
## The three generations are independent: coordinate-frame, streamed location,
## and this immutable binding/target lifetime.
func present_post_rebase_observation(
		body_local_observer_m: Variant,
		expected_coordinate_frame_generation: Variant,
		expected_location_generation: Variant,
		expected_binding_generation: Variant,
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_exact_safe_positive_integer(expected_binding_generation) \
			or int(expected_binding_generation) != _binding_generation:
		return _result(false, &"stale_binding_generation")
	var generation_result := _decode_generations(
		expected_coordinate_frame_generation,
		expected_location_generation,
	)
	if not bool(generation_result.get("accepted", false)):
		return _result(
			false,
			generation_result.get("reason", &"invalid_generation") as StringName,
		)
	var frame_generation := int(
		generation_result.get("coordinate_frame_generation", 0)
	)
	var location_generation := int(
		generation_result.get("location_generation", 0)
	)
	if body_local_observer_m is not Vector3 \
			or not (body_local_observer_m as Vector3).is_finite():
		return _result(false, &"invalid_body_local_observer")
	var identity_reason := _live_composition_reason(
		frame_generation,
		location_generation,
	)
	if not identity_reason.is_empty():
		return _result(false, identity_reason)

	var observer := body_local_observer_m as Vector3
	var presentation := get_presentation()
	_mutation_active = true
	var presented := presentation.present_observation({
		"body_local_observer_m": observer,
		"normalized_body_to_sun": AUTHORED_BODY_TO_SUN_DIRECTION,
	}, _presentation_generation)
	if not bool(presented.get("accepted", false)):
		_mutation_active = false
		return _result(false, &"sun_presentation_rejected", {
			"presentation_reason": presented.get("reason", &"unknown"),
			"policy_reason": presented.get("policy_reason", &""),
		})
	var postflight_reason := _live_composition_reason(
		frame_generation,
		location_generation,
	)
	if not postflight_reason.is_empty():
		_mutation_active = false
		return _result(false, &"composition_changed_during_presentation", {
			"identity_reason": postflight_reason,
		})
	_last_coordinate_frame_generation = frame_generation
	_last_body_local_observer_m = observer
	_last_presentation_result = presented.duplicate(true)
	_accepted_observation_count += 1
	get_directional_light().visible = true
	_mutation_active = false
	return _result(true, presented.get("reason", &"observation_presented") as StringName, {
		"evaluation": (
			presented.get("evaluation", {}) as Dictionary
		).duplicate(true),
		"renderer_values": (
			presented.get("renderer_values", {}) as Dictionary
		).duplicate(true),
	})


func get_generation() -> int:
	return _binding_generation


func get_directional_light() -> DirectionalLight3D:
	return get_node_or_null(NodePath(String(LIGHT_NODE_NAME))) as DirectionalLight3D


func get_presentation() -> PlanetarySunPresentation:
	return get_node_or_null(
		NodePath(String(PRESENTATION_NODE_NAME))
	) as PlanetarySunPresentation


func get_snapshot() -> Dictionary:
	var presentation := get_presentation()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"configured": _configured,
		"binding_generation": _binding_generation,
		"presentation_generation": _presentation_generation,
		"coordinate_frame_generation": _last_coordinate_frame_generation,
		"location_generation": _location_generation,
		"identity": {
			"world_id": WORLD_ID,
			"body_id": BODY_ID,
			"location_id": LOCATION_ID,
			"orbital_frame_id": ORBITAL_FRAME_ID,
			"bootstrap_instance_id": _bootstrap_instance_id,
			"loaded_root_instance_id": _loaded_root_instance_id,
			"coordinate_frame_instance_id": _coordinate_frame_instance_id,
			"rig_instance_id": _rig_instance_id,
			"light_instance_id": _light_instance_id,
			"presentation_instance_id": _presentation_instance_id,
		},
		"authored": {
			"body_to_sun_direction": AUTHORED_BODY_TO_SUN_DIRECTION,
			"emitted_light_direction": AUTHORED_EMITTED_LIGHT_DIRECTION,
			"light_transform": AUTHORED_LIGHT_TRANSFORM,
			"baseline_energy": AUTHORED_BASELINE_ENERGY,
			"baseline_color": AUTHORED_BASELINE_COLOR,
		},
		"last_body_local_observer_m": _last_body_local_observer_m,
		"last_presentation_result": _last_presentation_result.duplicate(true),
		"accepted_observation_count": _accepted_observation_count,
		"presentation": (
			presentation.get_state_snapshot()
			if presentation != null else {}
		),
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": _capabilities(),
		"evidence": _evidence(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var rig_reason := _rig_contract_reason(not _configured)
	if not rig_reason.is_empty():
		errors.append(String(rig_reason))
	if not _configured:
		errors.append("binding_not_configured")
	else:
		var identity_reason := _live_composition_reason(
			_coordinate_frame.get_generation() if _coordinate_frame != null else 0,
			_location_generation,
		)
		if not identity_reason.is_empty():
			errors.append(String(identity_reason))
		var presentation := get_presentation()
		if presentation == null or not bool(presentation.audit().get("valid", false)):
			errors.append("sun_presentation_audit_invalid")
		else:
			var policy := presentation.get_policy_snapshot()
			if policy.get("world_id", &"") != WORLD_ID \
					or bool(policy.get("has_atmosphere", true)) \
					or policy.get("atmosphere_profile_id", &"") != &"":
				errors.append("airless_policy_identity_drift")
	if is_processing() or is_physics_processing() \
			or has_method("_process") or has_method("_physics_process"):
		errors.append("binding_gained_process_authority")
	if not _authority_contract_is_valid():
		errors.append("authority_contract_drift")
	if not _capability_contract_is_valid():
		errors.append("capability_contract_drift")
	if not _evidence_contract_is_valid():
		errors.append("evidence_contract_drift")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"owned_renderer_properties": PackedStringArray([
			"DirectionalLight3D.light_color",
			"DirectionalLight3D.light_energy",
		]),
		"production_caller_wired": _is_production_composed(),
		"automatic_process": false,
		"runtime_target_creation": false,
		"runtime_transform_or_orientation_writes": false,
		"authority": AUTHORITY.duplicate(true),
		"adjacent_authority": ADJACENT_AUTHORITY.duplicate(true),
		"capabilities": _capabilities(),
		"evidence": _evidence(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _configuration_preflight(
		world: PlanetaryWorldDefinition,
		bootstrap: EmberMoonStreamingBootstrap,
		coordinate_frame: PlanetaryCoordinateFrame,
		loaded_root: EmberMoonAuthoredScene,
		frame_generation: int,
		location_generation: int,
	) -> Dictionary:
	if world == null or world != _EMBER_WORLD_DEFINITION:
		return _result(false, &"unexpected_world_definition")
	var world_audit := world.get_audit_report()
	var body := world_audit.get("body", {}) as Dictionary
	if not bool(world_audit.get("valid", false)) \
			or world_audit.get("world_id", &"") != WORLD_ID \
			or world.resource_path != WORLD_RESOURCE_PATH \
			or float(body.get("radius_metres", NAN)) != BODY_RADIUS_M \
			or bool(body.get("has_atmosphere", true)) \
			or body.get("atmosphere_definition_id", &"invalid") != &"":
		return _result(false, &"invalid_airless_ember_world")
	if not is_instance_valid(bootstrap) or bootstrap.is_queued_for_deletion() \
			or not bootstrap.is_inside_tree():
		return _result(false, &"bootstrap_unavailable")
	if not is_instance_valid(loaded_root) or loaded_root.is_queued_for_deletion() \
			or not loaded_root.is_inside_tree():
		return _result(false, &"loaded_root_unavailable")
	if coordinate_frame == null or not is_instance_valid(coordinate_frame):
		return _result(false, &"coordinate_frame_unavailable")
	if not _has_valid_composition_parent(bootstrap, loaded_root):
		return _result(false, &"rig_bootstrap_composition_mismatch")
	var rig_reason := _rig_contract_reason(true)
	if not rig_reason.is_empty():
		return _result(false, rig_reason)
	var bootstrap_snapshot := bootstrap.get_snapshot()
	if not bool(bootstrap.audit().get("valid", false)) \
			or bootstrap_snapshot.get("world_id", &"") != WORLD_ID \
			or bootstrap_snapshot.get("body_id", &"") != BODY_ID \
			or bootstrap_snapshot.get("location_id", &"") != LOCATION_ID \
			or bootstrap_snapshot.get("location_resource_path", "") \
			!= EmberMoonStreamingBootstrap.LOCATION_RESOURCE_PATH \
			or bootstrap_snapshot.get("scene_resource_path", "") \
			!= EmberMoonStreamingBootstrap.SCENE_RESOURCE_PATH \
			or int(bootstrap_snapshot.get("location_generation", -1)) \
			!= location_generation \
			or int(bootstrap_snapshot.get("loaded_instance_id", 0)) \
			!= loaded_root.get_instance_id():
		return _result(false, &"bootstrap_identity_mismatch")
	if bootstrap.get_coordinate_frame_for_session() != coordinate_frame:
		return _result(false, &"coordinate_frame_identity_mismatch")
	if bootstrap.get_loaded_instance() != loaded_root:
		return _result(false, &"loaded_root_identity_mismatch")
	var frame_reason := _frame_contract_reason(coordinate_frame, frame_generation)
	if not frame_reason.is_empty():
		return _result(false, frame_reason)
	var root_reason := _loaded_root_contract_reason(
		loaded_root,
		bootstrap,
		location_generation,
	)
	if not root_reason.is_empty():
		return _result(false, root_reason)
	if not bool(loaded_root.audit().get("valid", false)):
		return _result(false, &"loaded_root_audit_invalid")
	return _result(true, &"configuration_preflight_passed")


func _live_composition_reason(
		frame_generation: int,
		location_generation: int,
	) -> StringName:
	if not _configured:
		return &"not_configured"
	if is_queued_for_deletion() or not is_inside_tree() \
			or get_instance_id() != _rig_instance_id:
		return &"rig_unavailable"
	var bootstrap := _resolve_bootstrap()
	if bootstrap == null or bootstrap.get_instance_id() != _bootstrap_instance_id:
		return &"bootstrap_identity_drift"
	var loaded_root := _resolve_loaded_root()
	if loaded_root == null \
			or loaded_root.get_instance_id() != _loaded_root_instance_id:
		return &"loaded_root_unavailable"
	if not _has_valid_composition_parent(bootstrap, loaded_root):
		return &"rig_bootstrap_composition_drift"
	if _coordinate_frame == null \
			or _coordinate_frame.get_instance_id() != _coordinate_frame_instance_id \
			or bootstrap.get_coordinate_frame_for_session() != _coordinate_frame:
		return &"coordinate_frame_identity_drift"
	if bootstrap.get_loaded_instance() != loaded_root:
		return &"loaded_root_identity_drift"
	if location_generation != _location_generation:
		return &"stale_location_generation"
	var frame_reason := _frame_contract_reason(
		_coordinate_frame,
		frame_generation,
	)
	if not frame_reason.is_empty():
		return frame_reason
	var root_reason := _loaded_root_contract_reason(
		loaded_root,
		bootstrap,
		location_generation,
	)
	if not root_reason.is_empty():
		return root_reason
	var rig_reason := _rig_contract_reason(false)
	if not rig_reason.is_empty():
		return rig_reason
	var light := get_directional_light()
	var presentation := get_presentation()
	if light == null or light.get_instance_id() != _light_instance_id:
		return &"directional_light_identity_drift"
	if presentation == null \
			or presentation.get_instance_id() != _presentation_instance_id \
			or presentation.get_generation() != _presentation_generation:
		return &"sun_presentation_identity_drift"
	return &""


func _frame_contract_reason(
		frame: PlanetaryCoordinateFrame,
		expected_generation: int,
	) -> StringName:
	if frame == null or not is_instance_valid(frame):
		return &"coordinate_frame_unavailable"
	if frame.get_generation() != expected_generation:
		return &"stale_coordinate_frame_generation"
	var audit_report := frame.audit()
	var snapshot := frame.get_snapshot()
	if not bool(audit_report.get("valid", false)):
		return &"coordinate_frame_audit_invalid"
	if not (snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return &"coordinate_frame_rebase_pending"
	var registry := NearbySectorOrbitalRegistry.new()
	if not bool(snapshot.get("configured", false)) \
			or snapshot.get("body_id", &"") != BODY_ID \
			or snapshot.get("orbital_frame_id", &"") != ORBITAL_FRAME_ID \
			or float(snapshot.get("meters_per_world_unit", NAN)) != 1.0 \
			or float(snapshot.get("body_radius_meters", NAN)) != BODY_RADIUS_M \
			or float(snapshot.get("orbital_cell_size_meters", NAN)) \
			!= ORBITAL_CELL_SIZE_M \
			or float(snapshot.get("origin_shift_threshold_meters", NAN)) \
			!= ORIGIN_SHIFT_THRESHOLD_M \
			or snapshot.get("body_center_orbital_coordinate", {}) \
			!= registry.get_coordinate(NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID) \
			or snapshot.get("surface_reference_direction", Vector3.ZERO) \
			!= Vector3.UP \
			or snapshot.get("surface_north_direction", Vector3.ZERO) \
			!= Vector3.FORWARD:
		return &"coordinate_frame_contract_mismatch"
	return &""


func _loaded_root_contract_reason(
		loaded_root: EmberMoonAuthoredScene,
		bootstrap: EmberMoonStreamingBootstrap,
		location_generation: int,
	) -> StringName:
	if not is_instance_valid(loaded_root) or loaded_root.is_queued_for_deletion() \
			or not loaded_root.is_inside_tree():
		return &"loaded_root_unavailable"
	if loaded_root.get_world_id() != WORLD_ID \
			or loaded_root.get_body_id() != BODY_ID \
			or loaded_root.get_meta(&"world_location_id", &"") != LOCATION_ID:
		return &"loaded_root_identity_mismatch"
	if int(loaded_root.get_meta(&"world_location_generation", -1)) \
			!= location_generation:
		return &"stale_location_generation"
	if loaded_root.transform != Transform3D.IDENTITY:
		return &"loaded_root_local_transform_drift"
	if loaded_root.global_transform.basis != Basis.IDENTITY \
			or bootstrap.global_transform.basis != Basis.IDENTITY \
			or not loaded_root.global_position.is_equal_approx(
				bootstrap.global_position
			):
		return &"loaded_root_frame_alignment_mismatch"
	if not bool(bootstrap.audit().get("valid", false)):
		return &"bootstrap_audit_invalid"
	return &""


func _rig_contract_reason(require_authored_baseline: bool) -> StringName:
	if name != RIG_NODE_NAME or scene_file_path != RIG_SCENE_PATH:
		return &"rig_scene_identity_mismatch"
	if get_child_count() != 2:
		return &"rig_child_roster_mismatch"
	var light := get_directional_light()
	var presentation := get_presentation()
	if light == null or presentation == null \
			or light.get_parent() != self or presentation.get_parent() != self:
		return &"rig_child_identity_mismatch"
	if find_children("*", "DirectionalLight3D", true, false).size() != 1 \
			or find_children("*", "Light3D", true, false).size() != 1:
		return &"directional_light_roster_mismatch"
	if find_children("*", "WorldEnvironment", true, false).size() != 0 \
			or find_children("*", "Camera3D", true, false).size() != 0 \
			or find_children("*", "AudioStreamPlayer", true, false).size() != 0 \
			or find_children("*", "AudioStreamPlayer3D", true, false).size() != 0:
		return &"forbidden_authority_node_present"
	if global_transform.basis != Basis.IDENTITY \
			or light.transform != AUTHORED_LIGHT_TRANSFORM \
			or -light.global_transform.basis.z \
			!= AUTHORED_EMITTED_LIGHT_DIRECTION:
		return &"authored_light_orientation_drift"
	if require_authored_baseline and (
		light.light_energy != AUTHORED_BASELINE_ENERGY
		or light.light_color != AUTHORED_BASELINE_COLOR
	):
		return &"authored_light_baseline_drift"
	if presentation.get_child_count() != 0 \
			or presentation.is_processing() \
			or presentation.is_physics_processing():
		return &"sun_presentation_topology_drift"
	if not presentation.get_signal_connection_list(
		&"presentation_committed"
	).is_empty():
		return &"sun_presentation_signal_observer_present"
	return &""


func _has_valid_composition_parent(
		bootstrap: EmberMoonStreamingBootstrap,
		loaded_root: EmberMoonAuthoredScene,
	) -> bool:
	if get_parent() == null:
		return false
	# Standalone verification composes the passive rig beside the bootstrap.
	if get_parent() == bootstrap.get_parent():
		return true
	# Production composition places the rig beside the exact streamed root under
	# the bootstrap's private coordinator, preserving one body-centred frame and
	# one light owner without modifying the authored terrain scene.
	return loaded_root != null \
		and get_parent() == loaded_root.get_parent() \
		and get_parent() == bootstrap.get_node_or_null(^"WorldStreamingCoordinator")


func _resolve_bootstrap() -> EmberMoonStreamingBootstrap:
	if _bootstrap_ref == null:
		return null
	var candidate: Variant = _bootstrap_ref.get_ref()
	if not is_instance_valid(candidate) or candidate is not EmberMoonStreamingBootstrap:
		return null
	var bootstrap := candidate as EmberMoonStreamingBootstrap
	if bootstrap.is_queued_for_deletion() or not bootstrap.is_inside_tree():
		return null
	return bootstrap


func _resolve_loaded_root() -> EmberMoonAuthoredScene:
	if _loaded_root_ref == null:
		return null
	var candidate: Variant = _loaded_root_ref.get_ref()
	if not is_instance_valid(candidate) or candidate is not EmberMoonAuthoredScene:
		return null
	var loaded_root := candidate as EmberMoonAuthoredScene
	if loaded_root.is_queued_for_deletion() or not loaded_root.is_inside_tree():
		return null
	return loaded_root


func _decode_generations(
		coordinate_frame_generation: Variant,
		location_generation: Variant,
	) -> Dictionary:
	if not _is_exact_safe_positive_integer(coordinate_frame_generation):
		return _result(false, &"invalid_coordinate_frame_generation")
	if not _is_exact_safe_positive_integer(location_generation):
		return _result(false, &"invalid_location_generation")
	return _result(true, &"valid_generations", {
		"coordinate_frame_generation": int(coordinate_frame_generation),
		"location_generation": int(location_generation),
	})


func _clear_binding_state() -> void:
	_configured = false
	_binding_generation = 0
	_presentation_generation = 0
	_last_coordinate_frame_generation = 0
	_location_generation = 0
	_bootstrap_ref = null
	_loaded_root_ref = null
	_coordinate_frame = null
	_bootstrap_instance_id = 0
	_loaded_root_instance_id = 0
	_coordinate_frame_instance_id = 0
	_rig_instance_id = 0
	_light_instance_id = 0
	_presentation_instance_id = 0
	_last_body_local_observer_m = Vector3.ZERO
	_last_presentation_result.clear()
	_accepted_observation_count = 0


func _authority_contract_is_valid() -> bool:
	if AUTHORITY.size() != COMMON_AUTHORITY_KEYS.size():
		return false
	for key: String in COMMON_AUTHORITY_KEYS:
		if not AUTHORITY.has(key) or AUTHORITY[key] is not bool \
				or bool(AUTHORITY[key]) != (key == "renderer"):
			return false
	if ADJACENT_AUTHORITY.size() != ADJACENT_AUTHORITY_KEYS.size():
		return false
	for key: String in ADJACENT_AUTHORITY_KEYS:
		if not ADJACENT_AUTHORITY.has(key) \
				or ADJACENT_AUTHORITY[key] is not bool \
				or bool(ADJACENT_AUTHORITY[key]):
			return false
	return true


func _capability_contract_is_valid() -> bool:
	if CAPABILITIES.size() != CAPABILITY_KEYS.size():
		return false
	for index: int in CAPABILITY_KEYS.size():
		var key := CAPABILITY_KEYS[index] as String
		if not CAPABILITIES.has(key) or CAPABILITIES[key] is not bool:
			return false
		var expected := index < 7
		if bool(CAPABILITIES[key]) != expected:
			return false
	return true


func _capabilities() -> Dictionary:
	var capabilities := CAPABILITIES.duplicate(true)
	capabilities["production_caller_wired"] = _is_production_composed()
	return capabilities


func _is_production_composed() -> bool:
	if not _configured:
		return false
	var bootstrap := _resolve_bootstrap()
	var loaded_root := _resolve_loaded_root()
	return bootstrap != null and loaded_root != null \
		and get_parent() == loaded_root.get_parent() \
		and get_parent() == bootstrap.get_node_or_null(^"WorldStreamingCoordinator")


func _evidence_contract_is_valid() -> bool:
	var evidence := _evidence()
	return evidence.size() == 5 \
		and evidence.get("content_class") == &"NEW" \
		and evidence.get("status") == &"modern_interpretation" \
		and evidence.get("source_bounded") is bool \
		and not bool(evidence.get("source_bounded", true)) \
		and evidence.get("confidence") == &"none" \
		and evidence.get("references") == PackedStringArray([DOCUMENTATION_PATH])


func _evidence() -> Dictionary:
	return {
		"content_class": &"NEW",
		"status": &"modern_interpretation",
		"source_bounded": false,
		"confidence": &"none",
		"references": PackedStringArray([DOCUMENTATION_PATH]),
	}.duplicate(true)


func _result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {},
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"binding_generation": _binding_generation,
		"presentation_generation": _presentation_generation,
		"coordinate_frame_generation": _last_coordinate_frame_generation,
		"location_generation": _location_generation,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


static func _is_exact_safe_positive_integer(value: Variant) -> bool:
	return value is int and int(value) >= 1 and int(value) <= MAX_SAFE_INTEGER
