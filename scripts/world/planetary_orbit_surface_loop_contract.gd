class_name PlanetaryOrbitSurfaceLoopContract
extends RefCounted

## Caller-owned lifecycle gate for one orbit-to-surface visit and return.
##
## This contract records the observations that a production orbit, landing,
## Player, and station owner must provide. It does not move a ship or Player,
## stream terrain, shift an origin, reserve a berth, save, reward, or mutate
## GameFlow. In particular, a plausible-looking position never skips a phase:
## each transition requires the authority-owned completion fact for that edge.

const SCHEMA_VERSION := 1
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_SPEED_METERS_PER_SECOND := 100_000.0

enum Phase {
	IDLE,
	ORBIT_APPROACH,
	ATMOSPHERIC_ENTRY,
	DESCENT,
	SURFACE_FLIGHT,
	LANDED,
	ON_FOOT,
	REBOARDED,
	TAKEOFF,
	ASCENT,
	ORBIT,
	RETURN_APPROACH,
	COMPLETED,
	FAILED,
}

const PHASE_IDS := [
	&"idle", &"orbit_approach", &"atmospheric_entry", &"descent",
	&"surface_flight", &"landed", &"on_foot", &"reboarded", &"takeoff",
	&"ascent", &"orbit", &"return_approach", &"completed", &"failed",
]

var _world_id: StringName = &""
var _landing_region_id: StringName = &""
var _return_target_id: StringName = &""
var _has_atmosphere := false
var _configuration_errors := PackedStringArray()

var _phase := Phase.IDLE
var _run_generation := 0
var _last_observation: Dictionary = {}
var _last_reason: StringName = &""
var _failure_reason: StringName = &""
var _transition_count := 0


func _init(
		world_id: StringName = &"ember_moon",
		landing_region_id: StringName = &"ember_caldera",
		return_target_id: StringName = &"mudds_shipyards",
		has_atmosphere: bool = false
	) -> void:
	_world_id = world_id
	_landing_region_id = landing_region_id
	_return_target_id = return_target_id
	_has_atmosphere = has_atmosphere
	_configuration_errors = _validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func begin(run_generation: int) -> Dictionary:
	if not is_configuration_valid():
		return _reject(&"invalid_configuration")
	if _phase != Phase.IDLE:
		return _reject(&"already_started")
	if not _valid_generation(run_generation):
		return _reject(&"invalid_generation")
	_run_generation = run_generation
	_last_observation = {}
	_failure_reason = &""
	_transition_count = 0
	return _transition(
		Phase.ORBIT_APPROACH,
		&"visit_started",
		{}
	)


func confirm_orbit_approach(
		handoff_confirmed: bool,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.ORBIT_APPROACH, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not handoff_confirmed:
		return _reject(&"orbit_approach_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_orbit_observation")
	return _transition(
		Phase.ATMOSPHERIC_ENTRY if _has_atmosphere else Phase.DESCENT,
		&"orbit_approach_confirmed",
		observation
	)


func confirm_atmospheric_entry(
		entry_complete: bool,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.ATMOSPHERIC_ENTRY, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not entry_complete:
		return _reject(&"atmospheric_entry_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_atmospheric_observation")
	return _transition(Phase.DESCENT, &"atmospheric_entry_confirmed", observation)


func confirm_descent(
		descent_complete: bool,
		landing_region_id: StringName,
		landing_support_ready: bool,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.DESCENT, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not descent_complete or not landing_support_ready \
			or landing_region_id != _landing_region_id:
		return _reject(&"descent_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_descent_observation")
	return _transition(
		Phase.SURFACE_FLIGHT,
		&"descent_confirmed",
		{"landing_region_id": landing_region_id, "observation": observation}
	)


func confirm_landing(
		landing_confirmed: bool,
		landing_region_id: StringName,
		landing_support_confirmed: bool,
		ship_stable: bool,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.SURFACE_FLIGHT, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not landing_confirmed or not landing_support_confirmed or not ship_stable \
			or landing_region_id != _landing_region_id:
		return _reject(&"landing_prerequisites_not_met")
	return _transition(
		Phase.LANDED,
		&"landing_confirmed",
		{"landing_region_id": landing_region_id, "ship_stable": true}
	)


func confirm_on_foot(
		egress_confirmed: bool,
		surface_route_completed: bool,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.LANDED, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not egress_confirmed or not surface_route_completed:
		return _reject(&"on_foot_prerequisites_not_met")
	return _transition(
		Phase.ON_FOOT,
		&"surface_traversal_confirmed",
		{"egress_confirmed": true, "surface_route_completed": true}
	)


func confirm_reboarded(
		player_reboarded: bool,
		ship_still_landed: bool,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.ON_FOOT, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not player_reboarded or not ship_still_landed:
		return _reject(&"reboard_prerequisites_not_met")
	return _transition(
		Phase.REBOARDED,
		&"reboarded",
		{"player_reboarded": true, "ship_still_landed": true}
	)


func confirm_takeoff(
		takeoff_started: bool,
		ship_still_landed: bool,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.REBOARDED, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not takeoff_started or ship_still_landed:
		return _reject(&"takeoff_prerequisites_not_met")
	return _transition(
		Phase.TAKEOFF,
		&"takeoff_confirmed",
		{"takeoff_started": true, "ship_still_landed": false}
	)


func confirm_ascent(
		clear_of_surface: bool,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.TAKEOFF, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not clear_of_surface:
		return _reject(&"ascent_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_ascent_observation")
	return _transition(Phase.ASCENT, &"surface_clearance_confirmed", observation)


func confirm_orbit(
		orbit_achieved: bool,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.ASCENT, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not orbit_achieved:
		return _reject(&"orbit_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_orbit_observation")
	return _transition(Phase.ORBIT, &"orbit_achieved", observation)


func confirm_return_approach(
		return_corridor_confirmed: bool,
		return_target_id: StringName,
		observation: Dictionary,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.ORBIT, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not return_corridor_confirmed or return_target_id != _return_target_id:
		return _reject(&"return_approach_prerequisites_not_met")
	if not _valid_observation(observation):
		return _reject(&"invalid_return_observation")
	return _transition(
		Phase.RETURN_APPROACH,
		&"return_corridor_confirmed",
		{"return_target_id": return_target_id, "observation": observation}
	)


func confirm_return(
		station_handoff_confirmed: bool,
		return_target_id: StringName,
		expected_run_generation: int
	) -> Dictionary:
	var rejection := _precondition(Phase.RETURN_APPROACH, expected_run_generation)
	if not rejection.is_empty():
		return _reject(rejection)
	if not station_handoff_confirmed or return_target_id != _return_target_id:
		return _reject(&"return_prerequisites_not_met")
	return _transition(
		Phase.COMPLETED,
		&"returned_to_station",
		{"return_target_id": return_target_id, "station_handoff_confirmed": true}
	)


func fail(reason: StringName, expected_run_generation: int) -> Dictionary:
	if _phase in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED]:
		return _reject(&"terminal_state") if _phase != Phase.IDLE else _reject(&"not_started")
	if expected_run_generation != _run_generation:
		return _reject(&"stale_generation")
	if not _is_stable_id(reason):
		return _reject(&"failure_reason_required")
	_failure_reason = reason
	return _transition(Phase.FAILED, &"visit_failed", {"reason": reason})


func get_phase() -> int:
	return _phase


func get_phase_id() -> StringName:
	return PHASE_IDS[_phase] if _phase >= 0 and _phase < PHASE_IDS.size() else &"unknown"


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"world_id": _world_id,
		"landing_region_id": _landing_region_id,
		"return_target_id": _return_target_id,
		"has_atmosphere": _has_atmosphere,
		"phase": _phase,
		"phase_id": get_phase_id(),
		"run_generation": _run_generation,
		"transition_count": _transition_count,
		"last_reason": _last_reason,
		"last_observation": _last_observation.duplicate(true),
		"failure_reason": _failure_reason,
		"authority": {
			"movement": false, "streaming": false, "origin_shift": false,
			"landing": false, "terrain": false, "player": false,
			"game_flow": false, "save": false, "network": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	var report := get_snapshot()
	report["valid"] = is_configuration_valid()
	report["errors"] = get_configuration_errors()
	report["terminal"] = _phase in [Phase.COMPLETED, Phase.FAILED]
	return report.duplicate(true)


func _precondition(expected_phase: int, expected_run_generation: int) -> StringName:
	if _phase == Phase.IDLE:
		return &"not_started"
	if _phase in [Phase.COMPLETED, Phase.FAILED]:
		return &"terminal_state"
	if _phase != expected_phase:
		return &"out_of_order"
	if expected_run_generation != _run_generation:
		return &"stale_generation"
	return &""


func _transition(next_phase: int, reason: StringName, observation: Dictionary) -> Dictionary:
	_phase = next_phase
	_last_reason = reason
	_last_observation = observation.duplicate(true)
	_transition_count += 1
	return _accept(reason)


func _valid_observation(observation: Dictionary) -> bool:
	if observation.is_empty() or not observation.has("position"):
		return false
	var position: Variant = observation.get("position")
	if not position is Vector3 or not (position as Vector3).is_finite():
		return false
	var speed := float(observation.get("speed_meters_per_second", 0.0))
	return is_finite(speed) and speed >= 0.0 and speed <= MAX_SPEED_METERS_PER_SECOND


func _validate_configuration() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", _world_id)
	_validate_id(errors, "landing_region_id", _landing_region_id)
	_validate_id(errors, "return_target_id", _return_target_id)
	return errors


func _accept(reason: StringName) -> Dictionary:
	return {"accepted": true, "reason": reason, "snapshot": get_snapshot()}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "snapshot": get_snapshot()}


static func _valid_generation(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_GENERATION


static func _is_stable_id(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty() or text.length() > 64 or text.begins_with("_") \
			or text.ends_with("_") or text.contains("__"):
		return false
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return true


static func _validate_id(
		errors: PackedStringArray,
		field_name: String,
		value: StringName
	) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a stable lowercase snake_case identifier" % field_name)
