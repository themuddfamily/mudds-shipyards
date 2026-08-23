class_name PlanetaryLandingReturnContract
extends RefCounted

## Caller-owned acceptance contract for one authored planetary visit.
##
## This is deliberately not a mover, berth, stream, save, reward, or GameFlow
## owner. Production callers submit observations from those existing owners at
## their physics boundary. The contract only makes the complete landing and
## return loop explicit, fences every observation to the same live run, and
## records a floating-origin generation change without moving any node.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ACTIVITY_IDS := 32
const MAX_ROUTE_IDS := 32
const PHASE_SEQUENCE := [
	&"orbit_approach",
	&"surface_flight",
	&"landed",
	&"on_foot",
	&"reboarded",
	&"takeoff",
	&"orbit_return",
	&"completed",
]

enum Phase {
	IDLE,
	ORBIT_APPROACH,
	SURFACE_FLIGHT,
	LANDED,
	ON_FOOT,
	REBOARDED,
	TAKEOFF,
	ORBIT_RETURN,
	COMPLETED,
	FAILED,
}

var _world_id: StringName = &""
var _region_id: StringName = &""
var _return_target_id: StringName = &""
var _route_ids := PackedStringArray()
var _activity_ids := PackedStringArray()
var _configuration_errors := PackedStringArray()

var _phase := Phase.IDLE
var _run_generation := 0
var _attachment_generation := 0
var _coordinate_frame_generation := 0
var _location_generation := 0
var _origin_rebase_count := 0
var _last_origin_receipt := {}
var _completed_activity_id: StringName = &""
var _last_evidence := {}
var _return_approach_admitted := false
var _failure_reason: StringName = &""
var _failed_phase := Phase.IDLE


func _init(
		world_id: StringName = &"ember_moon",
		region_id: StringName = &"ember_caldera",
		return_target_id: StringName = &"mudds_shipyards",
		route_ids: PackedStringArray = PackedStringArray([
			"pad_alpha_egress", "surface_staging_gate", "orbit_return_corridor",
		]),
		activity_ids: PackedStringArray = PackedStringArray(["caldera_relay_scan"])
	) -> void:
	_world_id = world_id
	_region_id = region_id
	_return_target_id = return_target_id
	_route_ids = route_ids.duplicate()
	_activity_ids = activity_ids.duplicate()
	_configuration_errors = _validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func begin(
		run_generation: int,
		attachment_generation: int,
		coordinate_frame_generation: int,
		location_generation: int
	) -> Dictionary:
	if not is_configuration_valid():
		return _reject(&"invalid_configuration")
	if _phase != Phase.IDLE:
		return _reject(&"already_started")
	if not _valid_generation(run_generation) or not _valid_generation(attachment_generation) \
			or not _valid_generation(coordinate_frame_generation) \
			or not _valid_generation(location_generation):
		return _reject(&"invalid_generation")
	_run_generation = run_generation
	_attachment_generation = attachment_generation
	_coordinate_frame_generation = coordinate_frame_generation
	_location_generation = location_generation
	_phase = Phase.ORBIT_APPROACH
	_failure_reason = &""
	_failed_phase = Phase.IDLE
	_completed_activity_id = &""
	_last_evidence = {}
	_return_approach_admitted = false
	_last_origin_receipt = {}
	_origin_rebase_count = 0
	return _accept(&"started")


## A rebase is an external atomic transaction. The receipt is copied as a
## witness; no transform or actor is touched here.
func commit_origin_rebase(
		target_coordinate_frame_generation: int,
		target_location_generation: int,
		receipt: Dictionary
	) -> Dictionary:
	var rejection := _running_rejection()
	if not rejection.is_empty():
		return _reject(rejection)
	if _phase in [Phase.COMPLETED, Phase.FAILED]:
		return _reject(&"terminal_state")
	if not _valid_generation(target_coordinate_frame_generation) \
			or not _valid_generation(target_location_generation):
		return _reject(&"invalid_generation")
	if target_coordinate_frame_generation <= _coordinate_frame_generation \
			or target_location_generation <= _location_generation:
		return _reject(&"origin_generation_not_advanced")
	if not _valid_receipt(receipt):
		return _reject(&"invalid_origin_receipt")
	_coordinate_frame_generation = target_coordinate_frame_generation
	_location_generation = target_location_generation
	_origin_rebase_count += 1
	_last_origin_receipt = receipt.duplicate(true)
	return _accept(&"origin_rebase_committed")


func confirm_orbit_approach(
		orbital_handoff_confirmed: bool,
		observation: Dictionary,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.ORBIT_APPROACH, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if not orbital_handoff_confirmed or not _finite_observation(observation):
		return _reject(&"orbit_approach_prerequisites_not_met")
	return _advance(Phase.SURFACE_FLIGHT, &"orbit_approach_confirmed", observation)


func confirm_landing(
		landing_confirmed: bool,
		landing_region_id: StringName,
		landing_identity: Dictionary,
		landing_support_confirmed: bool,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.SURFACE_FLIGHT, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if not landing_confirmed or not landing_support_confirmed \
			or landing_region_id != _region_id:
		return _reject(&"landing_prerequisites_not_met")
	if not _identity_matches(landing_identity):
		return _reject(&"landing_identity_mismatch")
	return _advance(
		Phase.LANDED, &"landing_confirmed",
		{"landing_region_id": landing_region_id, "landing_identity": landing_identity}
	)


func confirm_on_foot(
		egress_anchor_id: StringName,
		activity_id: StringName,
		activity_completed: bool,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.LANDED, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if _route_ids.find(String(egress_anchor_id)) < 0:
		return _reject(&"unknown_egress_anchor")
	if not _activity_ids.has(String(activity_id)) or not activity_completed:
		return _reject(&"surface_activity_prerequisites_not_met")
	_completed_activity_id = activity_id
	return _advance(
		Phase.ON_FOOT, &"on_foot_activity_completed",
		{"egress_anchor_id": egress_anchor_id, "activity_id": activity_id}
	)


func confirm_reboarded(
		player_reboarded: bool,
		ship_still_landed: bool,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.ON_FOOT, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if not player_reboarded or not ship_still_landed:
		return _reject(&"reboard_prerequisites_not_met")
	return _advance(
		Phase.REBOARDED, &"reboarded",
		{"player_reboarded": true, "ship_still_landed": true}
	)


func confirm_takeoff(
		takeoff_started: bool,
		ship_still_landed: bool,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.REBOARDED, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if not takeoff_started or ship_still_landed:
		return _reject(&"takeoff_prerequisites_not_met")
	return _advance(
		Phase.TAKEOFF, &"takeoff_confirmed",
		{"takeoff_started": true, "ship_still_landed": false}
	)


func confirm_orbit_return(
		orbital_handoff_confirmed: bool,
		return_target_id: StringName,
		observation: Dictionary,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.TAKEOFF, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if not orbital_handoff_confirmed or return_target_id != _return_target_id \
			or not _finite_observation(observation):
		return _reject(&"orbit_return_prerequisites_not_met")
	return _advance(
		Phase.COMPLETED, &"returned_to_station",
		{"return_target_id": return_target_id, "observation": observation}
	)


## Admit a caller-owned orbital return approach without completing arrival.
## The caller must still decide when to invoke confirm_orbit_return; this
## contract never moves a craft, leases a station, or mutates GameFlow.
func admit_orbit_return_approach(
		return_target_id: StringName,
		observation: Dictionary,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	var rejection := _observation_rejection(
		Phase.TAKEOFF, run_generation, attachment_generation
	)
	if not rejection.is_empty():
		return _reject(rejection)
	if _return_approach_admitted:
		return _reject(&"orbit_return_approach_already_admitted")
	if return_target_id != _return_target_id or not _finite_observation(observation):
		return _reject(&"orbit_return_approach_prerequisites_not_met")
	_return_approach_admitted = true
	_last_evidence["return_approach_admission"] = {
		"return_target_id": return_target_id,
		"observation": observation.duplicate(true),
	}.duplicate(true)
	var result := _accept(&"orbit_return_approach_admitted")
	result["return_target_id"] = return_target_id
	result["next_caller_state"] = &"confirm_orbit_return"
	return result


func fail(reason: StringName) -> Dictionary:
	if _phase in [Phase.IDLE, Phase.COMPLETED, Phase.FAILED]:
		return _reject(&"terminal_state")
	if String(reason).is_empty():
		return _reject(&"failure_reason_required")
	_failure_reason = reason
	_failed_phase = _phase
	_phase = Phase.FAILED
	return _accept(&"failed")


## Recovers a stranded surface visit to the landed ship without moving either
## actor. Only failures after landing and before takeoff may use this handoff;
## the caller must prove the return anchor and landed-ship state at current
## generations before normal reboard/takeoff/orbit-return progression resumes.
func recover_to_landed_ship(
		player_at_return_anchor: bool,
		ship_still_landed: bool,
		run_generation: int,
		attachment_generation: int
	) -> Dictionary:
	if _phase != Phase.FAILED:
		return _reject(&"recovery_unavailable")
	if _failed_phase not in [Phase.LANDED, Phase.ON_FOOT, Phase.REBOARDED]:
		return _reject(&"recovery_window_closed")
	if run_generation != _run_generation:
		return _reject(&"stale_generation")
	if attachment_generation != _attachment_generation:
		return _reject(&"stale_attachment_generation")
	if not player_at_return_anchor or not ship_still_landed:
		return _reject(&"landed_ship_recovery_prerequisites_not_met")
	_phase = Phase.ON_FOOT
	_failure_reason = &""
	_last_evidence = {
		"recovery": &"return_to_landed_ship",
		"player_at_return_anchor": true,
		"ship_still_landed": true,
	}
	return _accept(&"recovered_to_landed_ship")


func get_phase() -> int:
	return _phase


func get_phase_id() -> StringName:
	match _phase:
		Phase.IDLE: return &"idle"
		Phase.ORBIT_APPROACH: return &"orbit_approach"
		Phase.SURFACE_FLIGHT: return &"surface_flight"
		Phase.LANDED: return &"landed"
		Phase.ON_FOOT: return &"on_foot"
		Phase.REBOARDED: return &"reboarded"
		Phase.TAKEOFF: return &"takeoff"
		Phase.COMPLETED: return &"completed"
		Phase.FAILED: return &"failed"
	return &"unknown"


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"world_id": _world_id,
		"region_id": _region_id,
		"return_target_id": _return_target_id,
		"phase": _phase,
		"phase_id": get_phase_id(),
		"run_generation": _run_generation,
		"attachment_generation": _attachment_generation,
		"coordinate_frame_generation": _coordinate_frame_generation,
		"location_generation": _location_generation,
		"origin_rebase_count": _origin_rebase_count,
		"route_ids": _route_ids.duplicate(),
		"activity_ids": _activity_ids.duplicate(),
		"completed_activity_id": _completed_activity_id,
		"last_origin_receipt": _last_origin_receipt.duplicate(true),
		"last_evidence": _last_evidence.duplicate(true),
		"return_approach_admitted": _return_approach_admitted,
		"failure_reason": _failure_reason,
		"failed_phase": _failed_phase,
		"authority": {
			"movement": false, "landing": false, "streaming": false,
			"origin_shift": false, "activity": false, "reward": false,
			"save": false, "network": false, "game_flow": false,
		},
	}.duplicate(true)


func audit() -> Dictionary:
	var report := get_snapshot()
	report["valid"] = is_configuration_valid()
	report["errors"] = get_configuration_errors()
	report["terminal"] = _phase in [Phase.COMPLETED, Phase.FAILED]
	return report.duplicate(true)


func _advance(next_phase: int, reason: StringName, evidence: Dictionary) -> Dictionary:
	_phase = next_phase
	_last_evidence = evidence.duplicate(true)
	return _accept(reason)


func _observation_rejection(
		expected_phase: int,
		run_generation: int,
		attachment_generation: int
	) -> StringName:
	var rejection := _running_rejection()
	if not rejection.is_empty():
		return rejection
	if _phase != expected_phase:
		return &"out_of_order"
	if run_generation != _run_generation:
		return &"stale_generation"
	if attachment_generation != _attachment_generation:
		return &"stale_attachment_generation"
	return &""


func _running_rejection() -> StringName:
	if _phase == Phase.IDLE:
		return &"not_started"
	if _phase in [Phase.COMPLETED, Phase.FAILED]:
		return &"terminal_state"
	return &""


func _identity_matches(identity: Dictionary) -> bool:
	return identity.get("world_id", &"") == _world_id \
			and identity.get("region_id", &"") == _region_id \
			and identity.get("landing_confirmed", false) == true


func _finite_observation(observation: Dictionary) -> bool:
	if observation.is_empty():
		return false
	var position: Variant = observation.get("position", Vector3.INF)
	if not position is Vector3 or not (position as Vector3).is_finite():
		return false
	var speed := float(observation.get("speed_meters_per_second", 0.0))
	return is_finite(speed) and speed >= 0.0 and speed <= 100_000.0


func _valid_receipt(receipt: Dictionary) -> bool:
	return not receipt.is_empty() and receipt.get("accepted", true) == true \
			and receipt.get("source_generation", 0) is int \
			and receipt.get("target_generation", 0) is int \
			and int(receipt.target_generation) > int(receipt.source_generation)


func _validate_configuration() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", _world_id)
	_validate_id(errors, "region_id", _region_id)
	_validate_id(errors, "return_target_id", _return_target_id)
	if _route_ids.is_empty() or _route_ids.size() > MAX_ROUTE_IDS:
		errors.append("route_ids must contain 1 to %d entries" % MAX_ROUTE_IDS)
	for route_id in _route_ids:
		_validate_id(errors, "route_id", StringName(route_id))
	if _activity_ids.is_empty() or _activity_ids.size() > MAX_ACTIVITY_IDS:
		errors.append("activity_ids must contain 1 to %d entries" % MAX_ACTIVITY_IDS)
	for activity_id in _activity_ids:
		_validate_id(errors, "activity_id", StringName(activity_id))
	return errors


static func _valid_generation(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


static func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > 64 or text.begins_with("_") \
			or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be a stable lowercase snake_case identifier" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be a stable lowercase snake_case identifier" % field_name)
			return


func _accept(reason: StringName) -> Dictionary:
	return {"accepted": true, "reason": reason, "snapshot": get_snapshot()}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "snapshot": get_snapshot()}
