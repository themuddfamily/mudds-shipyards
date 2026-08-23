class_name PlanetaryTravelSession
extends RefCounted

const LandingCompositionValidatorScript := preload(
	"res://scripts/world/planetary_landing_composition_validator.gd"
)
const WorldCompositionValidatorScript := preload(
	"res://scripts/world/planetary_world_composition_validator.gd"
)

## Caller-clock, authority-free lifecycle for one planetary visit.
##
## Absolute positions are accepted only as canonical orbital-coordinate records
## validated and decoded by the configured PlanetaryCoordinateFrame. The
## session never accepts world-streaming positions as persistent evidence, so a
## floating-origin rebase cannot change an already committed observation.

signal session_started(snapshot: Dictionary)
signal landing_composition_bound(snapshot: Dictionary)
signal phase_changed(snapshot: Dictionary, previous_state_id: StringName)
signal session_completed(snapshot: Dictionary)
signal session_failed(snapshot: Dictionary)
signal session_aborted(snapshot: Dictionary)
signal session_reset(snapshot: Dictionary)
signal attachment_changed(snapshot: Dictionary)
signal presentation_changed(snapshot: Dictionary)

enum State {
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
	ORBIT_RETURN,
	COMPLETED,
	FAILED,
	ABORTED,
}

const SCHEMA_VERSION := 1
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_CALLER_PHYSICS_DELTA_SECONDS := 0.25
const MAX_SESSION_ELAPSED_SECONDS := 604_800.0
const MAX_SAMPLE_SPEED_METERS_PER_SECOND := 100_000.0

const WORLD_COMPOSITION_REPORT_KEYS := [
	"schema_version",
	"valid",
	"errors",
	"error_codes",
	"world_id",
	"atmosphere_profile_id",
	"terrain_profile_id",
	"radius_datum",
	"anchor_frame",
	"body_radius_meters",
	"surface_radius_bounds_meters",
	"atmosphere_outer_radius_meters",
	"evidence",
	"authority",
]

const LANDING_REPORT_KEYS := [
	"schema_version",
	"valid",
	"errors",
	"error_codes",
	"world_id",
	"body_id",
	"region_id",
	"terrain_profile_id",
	"coordinate_frame_generation",
	"radius_datum",
	"frame_seam",
	"body_radius_meters",
	"region_center_body_local_meters",
	"evidence",
	"authority",
]
const LANDING_AUTHORITY_KEYS := [
	"renderer",
	"gameplay",
	"streaming",
	"save",
	"network",
	"physics",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"origin_shift",
	"weather_clock",
	"audio",
]

const ATMOSPHERIC_SEQUENCE: Array[int] = [
	State.ORBIT_APPROACH,
	State.ATMOSPHERIC_ENTRY,
	State.DESCENT,
	State.SURFACE_FLIGHT,
	State.LANDED,
	State.ON_FOOT,
	State.REBOARDED,
	State.TAKEOFF,
	State.ASCENT,
	State.ORBIT_RETURN,
	State.COMPLETED,
]
const AIRLESS_SEQUENCE: Array[int] = [
	State.ORBIT_APPROACH,
	State.DESCENT,
	State.SURFACE_FLIGHT,
	State.LANDED,
	State.ON_FOOT,
	State.REBOARDED,
	State.TAKEOFF,
	State.ASCENT,
	State.ORBIT_RETURN,
	State.COMPLETED,
]

var _session_id: StringName = &""
var _world_id: StringName = &""
var _body_id: StringName = &""
var _orbital_frame_id: StringName = &""
var _has_atmosphere := false
var _body_radius_meters := 0.0
var _world_snapshot: Dictionary = {}
var _world_composition_report: Dictionary = {}
var _world_landing_region_ids := PackedStringArray()
var _terrain_profile_id: StringName = &""
var _orbital_anchor_body_local_meters := Vector3.ZERO
var _navigation_anchor_radius_meters := 0.0
var _orbital_anchor_radius_meters := 0.0
var _surface_radius_minimum_meters := 0.0
var _surface_radius_maximum_meters := 0.0
var _atmosphere_outer_radius_meters := 0.0
var _coordinate_frame: PlanetaryCoordinateFrame
var _coordinate_frame_instance_id := 0
var _configuration_errors := PackedStringArray()

var _state := State.IDLE
var _generation := 0
var _attachment_generation := 0
var _attached := false
var _started_once := false
var _elapsed_seconds := 0.0
var _phase_elapsed_seconds := 0.0
var _last_duration_seconds := -1.0
var _transition_count := 0
var _terminal_reason: StringName = &""
var _last_sample: Dictionary = {}
var _last_return_intent: Dictionary = {}
var _last_return_activity_generation := -1
var _return_approach_ready := false
var _return_contract_approach_admitted := false
var _landing_composition_report: Dictionary = {}
var _last_coordinate_frame_generation := 0
var _mutation_active := false
var _signal_dispatch_active := false


func _init(
		session_id: StringName = &"planetary_travel",
		world: PlanetaryWorldDefinition = null,
		coordinate_frame: PlanetaryCoordinateFrame = null,
		world_composition_report: Dictionary = {}
	) -> void:
	_session_id = session_id
	if not _is_stable_id(_session_id):
		_configuration_errors.append("session_id must be a stable lowercase identifier")
	if world == null:
		_configuration_errors.append("a planetary world definition is required")
	elif not world.is_definition_valid():
		_configuration_errors.append("the planetary world definition is invalid")
	else:
		_world_id = world.world_id
		_has_atmosphere = world.has_atmosphere
		_body_radius_meters = world.get_body_radius_meters()
		_world_snapshot = world.audit().duplicate(true)
		_world_landing_region_ids = world.get_landing_region_ids()
		_terrain_profile_id = world.terrain_definition_id
		_orbital_anchor_body_local_meters = world.get_orbital_anchor().origin
		_navigation_anchor_radius_meters = world.get_navigation_anchor().origin.length()
		_orbital_anchor_radius_meters = _orbital_anchor_body_local_meters.length()
	if coordinate_frame == null:
		_configuration_errors.append("a configured planetary coordinate frame is required")
	elif not coordinate_frame.is_configured() \
			or not bool(coordinate_frame.audit().get("valid", false)):
		_configuration_errors.append("the planetary coordinate frame is invalid or unconfigured")
	else:
		_coordinate_frame = coordinate_frame
		_coordinate_frame_instance_id = coordinate_frame.get_instance_id()
		var frame_snapshot := coordinate_frame.get_snapshot()
		_body_id = frame_snapshot.get("body_id", &"") as StringName
		_orbital_frame_id = frame_snapshot.get("orbital_frame_id", &"") as StringName
		_last_coordinate_frame_generation = int(frame_snapshot.get("generation", 0))
		if world != null and world.is_definition_valid() \
				and float(frame_snapshot.get("body_radius_meters", 0.0)) \
				!= _body_radius_meters:
			_configuration_errors.append("world and coordinate-frame body radii must match exactly")
		if world != null and world.is_definition_valid():
			var anchor_result := coordinate_frame.body_local_to_orbital_position(
				_orbital_anchor_body_local_meters,
				_last_coordinate_frame_generation
			)
			if not bool(anchor_result.get("accepted", false)):
				_configuration_errors.append("the world orbital anchor is outside the coordinate frame")
	if world != null and world.is_definition_valid() and coordinate_frame != null \
			and coordinate_frame.is_configured():
		var composition_validation := _validate_world_composition_report(
			world_composition_report
		)
		if not bool(composition_validation.get("accepted", false)):
			_configuration_errors.append(
				"invalid planetary world composition report: %s" \
				% String(composition_validation.get("reason", &"invalid_composition"))
			)
		else:
			_world_composition_report = (
				composition_validation.get("report", {}) as Dictionary
			).duplicate(true)
			var bounds := _world_composition_report.surface_radius_bounds_meters as Dictionary
			_surface_radius_minimum_meters = float(bounds.minimum)
			_surface_radius_maximum_meters = float(bounds.maximum)
			_atmosphere_outer_radius_meters = float(
				_world_composition_report.atmosphere_outer_radius_meters
			)


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func attach(
		world_id: StringName,
		coordinate_frame: PlanetaryCoordinateFrame,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if expected_attachment_generation != _attachment_generation:
		return _finish(false, &"stale_attachment_generation")
	if _attached:
		return _finish(false, &"already_attached")
	if not is_configuration_valid():
		return _finish(false, &"invalid_configuration")
	if world_id != _world_id or coordinate_frame == null \
			or coordinate_frame.get_instance_id() != _coordinate_frame_instance_id:
		return _finish(false, &"world_binding_mismatch")
	var frame_rejection := _coordinate_frame_rejection(
		expected_coordinate_frame_generation
	)
	if not frame_rejection.is_empty():
		return _finish(false, frame_rejection)
	if _attachment_generation >= MAX_SAFE_GENERATION:
		return _finish(false, &"attachment_generation_exhausted")
	_attachment_generation += 1
	_attached = true
	_last_coordinate_frame_generation = expected_coordinate_frame_generation
	var result := _finish(true, &"attached")
	_emit_snapshot_signal(attachment_changed)
	_emit_snapshot_signal(presentation_changed)
	return result


func detach(
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _attachment_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	_attached = false
	var result := _finish(true, &"detached")
	_emit_snapshot_signal(attachment_changed)
	_emit_snapshot_signal(presentation_changed)
	return result


func start(
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _attachment_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not is_configuration_valid():
		return _finish(false, &"invalid_configuration")
	if _state != State.IDLE:
		return _finish(false, &"reset_required")
	if _generation >= MAX_SAFE_GENERATION:
		return _finish(false, &"generation_exhausted")
	_generation += 1
	_state = State.ORBIT_APPROACH
	_started_once = true
	_elapsed_seconds = 0.0
	_phase_elapsed_seconds = 0.0
	_transition_count = 0
	_terminal_reason = &""
	_last_sample = {}
	var result := _finish(true, &"started")
	_emit_snapshot_signal(session_started)
	_emit_snapshot_signal(presentation_changed)
	return result


## Admit a caller-authorized return request without advancing movement state.
## The caller must still drive the existing reboard/takeoff/orbit samples.
func admit_return_travel_intent(
		intent: Variant,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _attachment_rejection(expected_generation, expected_attachment_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not intent is Dictionary or actor_instance_id < 1 or craft_instance_id < 1:
		return _finish(false, &"invalid_return_travel_intent")
	var request := intent as Dictionary
	var activity_generation := int(request.get("activity_generation", 0))
	if activity_generation < 1 or activity_generation == _last_return_activity_generation:
		return _finish(false, &"return_travel_intent_already_admitted")
	if StringName(request.get("destination_id", &"")) != &"mudds_shipyards":
		return _finish(false, &"return_travel_destination_mismatch")
	if _state not in [State.ON_FOOT, State.REBOARDED]:
		return _finish(false, &"return_travel_out_of_order")
	_last_return_activity_generation = activity_generation
	_last_return_intent = request.duplicate(true)
	_last_return_intent["actor_instance_id"] = actor_instance_id
	_last_return_intent["craft_instance_id"] = craft_instance_id
	_last_sample["return_travel_intent"] = _last_return_intent.duplicate(true)
	var result := _finish(true, &"return_travel_intent_admitted")
	_emit_snapshot_signal(presentation_changed)
	return result


func submit_authorized_return_reboard(
		actor_instance_id: int,
		craft_instance_id: int,
		player_reboarded: bool,
		ship_still_landed: bool,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	return submit_reboard_sample(
		player_reboarded, ship_still_landed,
		expected_generation, expected_attachment_generation
	)


func submit_authorized_return_takeoff(
		actor_instance_id: int,
		craft_instance_id: int,
		takeoff_started: bool,
		ship_still_landed: bool,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	return submit_takeoff_sample(
		takeoff_started, ship_still_landed,
		expected_generation, expected_attachment_generation
	)


func submit_authorized_return_ascent(
		actor_instance_id: int,
		craft_instance_id: int,
		surface_clear_confirmed: bool,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	return submit_ascent_sample(
		surface_clear_confirmed, orbital_coordinate, speed_meters_per_second,
		expected_coordinate_frame_generation, expected_generation,
		expected_attachment_generation
	)


func submit_authorized_return_orbit(
		actor_instance_id: int,
		craft_instance_id: int,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	return submit_orbit_return_sample(
		orbital_coordinate, speed_meters_per_second,
		expected_coordinate_frame_generation, expected_generation,
		expected_attachment_generation
	)


## Validates the completed orbital sample against the existing landing-return
## contract and emits approach readiness only. The contract is not advanced;
## arrival, landing lease, movement, and GameFlow remain caller-owned.
func prepare_return_approach(
		landing_return_contract: Object,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	var rejection := _attachment_rejection(expected_generation, expected_attachment_generation)
	if not rejection.is_empty():
		return _result(false, rejection)
	if _state != State.ORBIT_RETURN:
		return _result(false, &"return_approach_requires_orbit_ready")
	if _return_approach_ready:
		return _result(false, &"return_approach_already_prepared")
	if landing_return_contract == null or not landing_return_contract.has_method(&"get_snapshot"):
		return _result(false, &"landing_return_contract_unavailable")
	var contract_snapshot := landing_return_contract.call(&"get_snapshot") as Dictionary
	if StringName(contract_snapshot.get("return_target_id", &"")) != &"mudds_shipyards":
		return _result(false, &"return_approach_destination_mismatch")
	var contract_audit := landing_return_contract.call(&"audit") as Dictionary \
		if landing_return_contract.has_method(&"audit") else contract_snapshot
	if bool(contract_audit.get("terminal", false)):
		return _result(false, &"landing_return_contract_terminal")
	_return_approach_ready = true
	_last_sample["return_approach_ready"] = {
		"destination_id": &"mudds_shipyards",
		"actor_instance_id": actor_instance_id,
		"craft_instance_id": craft_instance_id,
		"contract_snapshot": contract_snapshot.duplicate(true),
	}.duplicate(true)
	var result := _finish(true, &"return_approach_ready")
	_emit_snapshot_signal(presentation_changed)
	return result


func admit_return_contract_approach(
		landing_return_contract: Object,
		actor_instance_id: int,
		craft_instance_id: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var identity_rejection := _return_identity_rejection(actor_instance_id, craft_instance_id)
	if not identity_rejection.is_empty():
		return _result(false, identity_rejection)
	var rejection := _attachment_rejection(expected_generation, expected_attachment_generation)
	if not rejection.is_empty():
		return _result(false, rejection)
	if not _return_approach_ready:
		return _result(false, &"return_approach_not_prepared")
	if _return_contract_approach_admitted:
		return _result(false, &"return_contract_approach_already_admitted")
	if landing_return_contract == null \
			or not landing_return_contract.has_method(&"admit_orbit_return_approach"):
		return _result(false, &"landing_return_contract_unavailable")
	var position := _last_sample.get("body_local_position_meters", Vector3.INF) as Vector3
	var contract_result: Dictionary = landing_return_contract.call(
		&"admit_orbit_return_approach", &"mudds_shipyards",
		{"position": position, "activity_generation": _last_return_activity_generation},
		expected_generation, expected_attachment_generation
	)
	if not bool(contract_result.get("accepted", false)):
		return contract_result
	_return_contract_approach_admitted = true
	var result := contract_result.duplicate(true)
	result["actor_instance_id"] = actor_instance_id
	result["craft_instance_id"] = craft_instance_id
	result["session_generation"] = expected_generation
	return result


func advance_physics(
		delta: float,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not is_finite(delta) or delta < 0.0 \
			or delta > MAX_CALLER_PHYSICS_DELTA_SECONDS:
		return _finish(false, &"invalid_delta")
	if is_zero_approx(delta):
		return _finish(true, &"no_delta")
	var candidate_elapsed := _elapsed_seconds + delta
	var candidate_phase_elapsed := _phase_elapsed_seconds + delta
	if not is_finite(candidate_elapsed) \
			or candidate_elapsed > MAX_SESSION_ELAPSED_SECONDS \
			or not is_finite(candidate_phase_elapsed):
		return _finish(false, &"time_limit_exceeded")
	_elapsed_seconds = candidate_elapsed
	_phase_elapsed_seconds = candidate_phase_elapsed
	var result := _finish(true, &"advanced")
	_emit_snapshot_signal(presentation_changed)
	return result


## The exact landing-composition report contract is intentionally validated at
## one boundary. A report must be bound before DESCENT can enter SURFACE_FLIGHT.
func bind_landing_composition_report(
		report: Dictionary,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _attachment_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if _state not in [State.IDLE, State.ORBIT_APPROACH, State.ATMOSPHERIC_ENTRY, State.DESCENT]:
		return _finish(false, &"landing_composition_too_late")
	var validation := _validate_landing_composition_report(report)
	if not bool(validation.get("accepted", false)):
		return _finish(false, validation.get("reason", &"invalid_landing_composition"))
	_landing_composition_report = (
		validation.get("report", {}) as Dictionary
	).duplicate(true)
	var result := _finish(true, &"landing_composition_bound")
	_emit_snapshot_signal(landing_composition_bound)
	_emit_snapshot_signal(presentation_changed)
	return result


func submit_orbit_approach_sample(
		orbital_handoff_confirmed: bool,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.ORBIT_APPROACH,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if not orbital_handoff_confirmed:
		return _finish(false, &"orbit_approach_prerequisites_not_met")
	observation["orbital_handoff_confirmed"] = true
	return _transition(
		State.ATMOSPHERIC_ENTRY if _has_atmosphere else State.DESCENT,
		&"orbit_approach",
		observation
	)


func submit_atmospheric_entry_sample(
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.ATMOSPHERIC_ENTRY,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if not _has_atmosphere:
		return _finish(false, &"atmosphere_not_configured")
	if float(observation.radial_distance_meters) \
			> _atmosphere_outer_radius_meters:
		return _finish(false, &"atmospheric_entry_prerequisites_not_met")
	return _transition(State.DESCENT, &"atmospheric_entry", observation)


func submit_descent_sample(
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.DESCENT,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if _landing_composition_report.is_empty():
		return _finish(false, &"landing_composition_required")
	if float(observation.radial_distance_meters) \
			> _navigation_anchor_radius_meters:
		return _finish(false, &"descent_prerequisites_not_met")
	return _transition(State.SURFACE_FLIGHT, &"descent", observation)


## This call records a caller-owned landed fact only after a separately
## validated composition report is bound. It intentionally has no invented
## landing distance, altitude, slope, or speed threshold.
func submit_landing_sample(
		landing_confirmed: bool,
		landing_identity: Dictionary,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _begin_sample(
		State.SURFACE_FLIGHT,
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not landing_confirmed:
		return _finish(false, &"landing_not_confirmed")
	if not _landing_identity_matches(landing_identity):
		return _finish(false, &"landing_composition_identity_mismatch")
	return _transition(
		State.LANDED,
		&"landing",
		{
			"landing_confirmed": true,
			"landing_identity": landing_identity.duplicate(true),
		}
	)


func submit_disembark_sample(
		player_on_foot: bool,
		ship_still_landed: bool,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _begin_sample(
		State.LANDED,
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not player_on_foot or not ship_still_landed:
		return _finish(false, &"disembark_prerequisites_not_met")
	return _transition(
		State.ON_FOOT,
		&"disembark",
		{"player_on_foot": true, "ship_still_landed": true}
	)


func submit_reboard_sample(
		player_reboarded: bool,
		ship_still_landed: bool,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _begin_sample(
		State.ON_FOOT,
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not player_reboarded or not ship_still_landed:
		return _finish(false, &"reboard_prerequisites_not_met")
	return _transition(
		State.REBOARDED,
		&"reboard",
		{"player_reboarded": true, "ship_still_landed": true}
	)


func submit_takeoff_sample(
		takeoff_started: bool,
		ship_still_landed: bool,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _begin_sample(
		State.REBOARDED,
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not takeoff_started or ship_still_landed:
		return _finish(false, &"takeoff_prerequisites_not_met")
	return _transition(
		State.TAKEOFF,
		&"takeoff",
		{"takeoff_started": true, "ship_still_landed": false}
	)


func submit_ascent_sample(
		surface_clear_confirmed: bool,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.TAKEOFF,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if not surface_clear_confirmed:
		return _finish(false, &"ascent_prerequisites_not_met")
	observation["surface_clear_confirmed"] = true
	return _transition(State.ASCENT, &"ascent", observation)


func submit_orbit_return_sample(
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.ASCENT,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if float(observation.radial_distance_meters) \
			< _orbital_anchor_radius_meters:
		return _finish(false, &"orbit_return_prerequisites_not_met")
	return _transition(State.ORBIT_RETURN, &"orbit_return", observation)


func submit_completion_sample(
		orbital_handoff_confirmed: bool,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var observation := _begin_absolute_sample(
		State.ORBIT_RETURN,
		orbital_coordinate,
		speed_meters_per_second,
		expected_coordinate_frame_generation,
		expected_generation,
		expected_attachment_generation
	)
	if not bool(observation.get("accepted", false)):
		return _finish(false, observation.get("reason", &"invalid_sample"))
	if not orbital_handoff_confirmed:
		return _finish(false, &"completion_prerequisites_not_met")
	observation["orbital_handoff_confirmed"] = true
	return _transition(State.COMPLETED, &"completion", observation)


func abort(
		reason: StringName,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	return _request_terminal(
		State.ABORTED,
		reason,
		expected_generation,
		expected_attachment_generation
	)


func fail(
		reason: StringName,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	return _request_terminal(
		State.FAILED,
		reason,
		expected_generation,
		expected_attachment_generation
	)


func reset(
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _attachment_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not _started_once:
		return _finish(false, &"not_started")
	if _state == State.IDLE:
		return _finish(false, &"already_idle")
	if _generation >= MAX_SAFE_GENERATION:
		return _finish(false, &"generation_exhausted")
	_generation += 1
	_state = State.IDLE
	_elapsed_seconds = 0.0
	_phase_elapsed_seconds = 0.0
	_transition_count = 0
	_terminal_reason = &""
	_last_sample = {}
	_last_return_intent = {}
	_last_return_activity_generation = -1
	_return_approach_ready = false
	_return_contract_approach_admitted = false
	_landing_composition_report = {}
	var result := _finish(true, &"reset")
	_emit_snapshot_signal(session_reset)
	_emit_snapshot_signal(presentation_changed)
	return result


func get_generation() -> int:
	return _generation


func get_attachment_generation() -> int:
	return _attachment_generation


func get_state() -> int:
	return _state


func get_presentation_snapshot() -> Dictionary:
	var sequence := ATMOSPHERIC_SEQUENCE if _has_atmosphere else AIRLESS_SEQUENCE
	var progress_index := sequence.find(_state)
	var presentation := {
		"visible": _state != State.IDLE,
		"title": "PLANETARY TRANSIT",
		"state_label": _state_label(_state),
		"objective": _objective_text(_state),
		"progress_current": progress_index + 1 if progress_index >= 0 else 0,
		"progress_total": sequence.size(),
		"terminal": _state in [State.COMPLETED, State.FAILED, State.ABORTED],
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": _session_id,
		"world_id": _world_id,
		"body_id": _body_id,
		"orbital_frame_id": _orbital_frame_id,
		"has_atmosphere": _has_atmosphere,
		"branch_id": &"atmospheric" if _has_atmosphere else &"airless",
		"state": _state,
		"state_id": _state_id(_state),
		"next_state_id": _next_state_id(),
		"generation": _generation,
		"attachment_generation": _attachment_generation,
		"coordinate_frame_generation": _last_coordinate_frame_generation,
		"attached": _attached,
		"running": _is_running(),
		"transition_count": _transition_count,
		"elapsed_seconds": _elapsed_seconds,
		"phase_elapsed_seconds": _phase_elapsed_seconds,
		"last_duration_seconds": _last_duration_seconds,
		"terminal_reason": _terminal_reason,
		"last_sample": _last_sample.duplicate(true),
		"last_return_intent": _last_return_intent.duplicate(true),
		"last_return_activity_generation": _last_return_activity_generation,
		"return_approach_ready": _return_approach_ready,
		"return_contract_approach_admitted": _return_contract_approach_admitted,
		"landing_composition": _landing_composition_report.duplicate(true),
		"landing_composition_bound": not _landing_composition_report.is_empty(),
		"presentation": presentation,
		"uses_caller_physics_delta": true,
		"uses_absolute_orbital_coordinates": true,
		"gameplay_authority": false,
		"ship_movement_authority": false,
		"landing_authority": false,
		"terrain_authority": false,
		"reward_authority": false,
		"streaming_authority": false,
		"save_authority": false,
		"render_authority": false,
		"authority": _zero_authority_report(),
	}.duplicate(true)


func audit() -> Dictionary:
	var report := get_presentation_snapshot()
	report["valid"] = is_configuration_valid()
	report["errors"] = get_configuration_errors()
	report["world_definition"] = _world_snapshot.duplicate(true)
	report["world_composition"] = _world_composition_report.duplicate(true)
	report["thresholds"] = {
		"max_caller_physics_delta_seconds": MAX_CALLER_PHYSICS_DELTA_SECONDS,
		"max_session_elapsed_seconds": MAX_SESSION_ELAPSED_SECONDS,
		"maximum_sample_speed_meters_per_second": MAX_SAMPLE_SPEED_METERS_PER_SECOND,
		"surface_radius_minimum_meters": _surface_radius_minimum_meters,
		"surface_radius_maximum_meters": _surface_radius_maximum_meters,
		"atmosphere_outer_radius_meters": _atmosphere_outer_radius_meters,
		"navigation_anchor_radius_meters": _navigation_anchor_radius_meters,
		"orbital_anchor_radius_meters": _orbital_anchor_radius_meters,
		"lifecycle_boundaries_source": &"validated_composition_and_authored_anchors",
		"landing_numeric_thresholds_defined": false,
	}
	return report.duplicate(true)


func _begin_sample(
		expected_state: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> StringName:
	if _is_reentrant():
		return &"reentrant_call"
	_mutation_active = true
	var rejection := _running_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return rejection
	if _state != expected_state:
		return &"out_of_order"
	return &""


func _begin_absolute_sample(
		expected_state: int,
		orbital_coordinate: Dictionary,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	var rejection := _begin_sample(
		expected_state,
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return {"accepted": false, "reason": rejection}
	if not is_finite(speed_meters_per_second) \
			or speed_meters_per_second < 0.0:
		return {"accepted": false, "reason": &"invalid_sample_speed"}
	if speed_meters_per_second > MAX_SAMPLE_SPEED_METERS_PER_SECOND:
		return {"accepted": false, "reason": &"sample_speed_out_of_bounds"}
	var frame_rejection := _coordinate_frame_rejection(
		expected_coordinate_frame_generation
	)
	if not frame_rejection.is_empty():
		return {"accepted": false, "reason": frame_rejection}
	var validation := _coordinate_frame.validate_orbital_coordinate(
		orbital_coordinate
	)
	if not bool(validation.get("accepted", false)):
		return {
			"accepted": false,
			"reason": &"invalid_orbital_coordinate",
			"coordinate_reason": validation.get("reason", &"invalid_coordinate"),
		}
	var canonical := (
		validation.get("coordinate", {}) as Dictionary
	).duplicate(true)
	var body_result := _coordinate_frame.orbital_to_body_local_position(
		canonical,
		expected_coordinate_frame_generation
	)
	if not bool(body_result.get("accepted", false)):
		return {
			"accepted": false,
			"reason": &"absolute_position_out_of_bounds",
			"coordinate_reason": body_result.get("reason", &"conversion_failed"),
		}
	var body_local := body_result.get("position", Vector3.INF) as Vector3
	var altitude := body_local.length() - _body_radius_meters
	var radial_distance := body_local.length()
	var distance_to_anchor := body_local.distance_to(
		_orbital_anchor_body_local_meters
	)
	if not body_local.is_finite() or not is_finite(altitude) \
			or not is_finite(distance_to_anchor):
		return {"accepted": false, "reason": &"absolute_position_out_of_bounds"}
	_last_coordinate_frame_generation = expected_coordinate_frame_generation
	return {
		"accepted": true,
		"reason": &"valid_absolute_sample",
		"orbital_coordinate": canonical,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"body_local_position_meters": body_local,
		"radial_distance_meters": radial_distance,
		"altitude_meters": altitude,
		"distance_to_orbital_anchor_meters": distance_to_anchor,
		"speed_meters_per_second": speed_meters_per_second,
	}


func _validate_world_composition_report(report: Dictionary) -> Dictionary:
	if not _has_exact_string_keys(report, WORLD_COMPOSITION_REPORT_KEYS):
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	if not report.schema_version is int \
			or int(report.schema_version) != WorldCompositionValidatorScript.SCHEMA_VERSION \
			or not report.valid is bool or not bool(report.valid) \
			or not report.errors is Array or not (report.errors as Array).is_empty() \
			or not report.error_codes is PackedStringArray \
			or not (report.error_codes as PackedStringArray).is_empty():
		return {"accepted": false, "reason": &"invalid_world_composition"}
	if not report.world_id is StringName \
			or not report.atmosphere_profile_id is StringName \
			or not report.terrain_profile_id is StringName:
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	if report.world_id != _world_id \
			or report.terrain_profile_id != _terrain_profile_id:
		return {"accepted": false, "reason": &"world_composition_identity_mismatch"}
	var world_body := _world_snapshot.get("body", {}) as Dictionary
	var expected_atmosphere_id := world_body.get(
		"atmosphere_definition_id", &""
	) as StringName
	if report.atmosphere_profile_id != expected_atmosphere_id:
		return {"accepted": false, "reason": &"world_composition_identity_mismatch"}
	if not report.radius_datum is StringName \
			or report.radius_datum != WorldCompositionValidatorScript.RADIUS_DATUM \
			or not report.anchor_frame is StringName \
			or report.anchor_frame != WorldCompositionValidatorScript.ANCHOR_FRAME:
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	if not _is_finite_number(report.body_radius_meters) \
			or float(report.body_radius_meters) != _body_radius_meters:
		return {"accepted": false, "reason": &"world_composition_radius_mismatch"}
	if not report.surface_radius_bounds_meters is Dictionary:
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	var bounds := report.surface_radius_bounds_meters as Dictionary
	if not _has_exact_string_keys(bounds, ["minimum", "maximum"]) \
			or not _is_finite_number(bounds.minimum) \
			or not _is_finite_number(bounds.maximum):
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	var minimum_radius := float(bounds.minimum)
	var maximum_radius := float(bounds.maximum)
	if minimum_radius <= 0.0 or minimum_radius > maximum_radius:
		return {"accepted": false, "reason": &"invalid_world_composition_surface_bounds"}
	var world_anchors := _world_snapshot.get("anchors", {}) as Dictionary
	var surface_record := world_anchors.get("surface", {}) as Dictionary
	var surface_transform := surface_record.get(
		"transform", Transform3D.IDENTITY
	) as Transform3D
	var surface_radius := surface_transform.origin.length()
	if surface_radius < minimum_radius or surface_radius > maximum_radius:
		return {"accepted": false, "reason": &"world_composition_surface_mismatch"}
	if not _is_finite_number(report.atmosphere_outer_radius_meters):
		return {"accepted": false, "reason": &"invalid_world_composition_schema"}
	var atmosphere_outer_radius := float(report.atmosphere_outer_radius_meters)
	if _has_atmosphere:
		if atmosphere_outer_radius < maximum_radius \
				or atmosphere_outer_radius > _orbital_anchor_radius_meters:
			return {"accepted": false, "reason": &"world_composition_atmosphere_mismatch"}
	elif not is_zero_approx(atmosphere_outer_radius):
		return {"accepted": false, "reason": &"world_composition_atmosphere_mismatch"}
	if not report.evidence is Dictionary \
			or not _has_exact_string_keys(
			report.evidence as Dictionary, ["world", "atmosphere", "terrain"]
		) or not report.authority is Dictionary \
			or not _is_exact_zero_authority(report.authority as Dictionary):
		return {"accepted": false, "reason": &"world_composition_authority_mismatch"}
	return {
		"accepted": true,
		"reason": &"valid_world_composition",
		"report": report.duplicate(true),
	}


func _validate_landing_composition_report(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {"accepted": false, "reason": &"missing_landing_composition"}
	if not _has_exact_string_keys(report, LANDING_REPORT_KEYS):
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	if not report.schema_version is int \
			or int(report.schema_version) != LandingCompositionValidatorScript.SCHEMA_VERSION \
			or not report.valid is bool or not bool(report.valid):
		return {"accepted": false, "reason": &"invalid_landing_composition"}
	if not report.errors is Array or not (report.errors as Array).is_empty() \
			or not report.error_codes is PackedStringArray \
			or not (report.error_codes as PackedStringArray).is_empty():
		return {"accepted": false, "reason": &"invalid_landing_composition"}
	if not report.world_id is StringName or not report.body_id is StringName \
			or not report.region_id is StringName \
			or not report.terrain_profile_id is StringName:
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	if report.world_id != _world_id or report.body_id != _body_id:
		return {"accepted": false, "reason": &"landing_composition_identity_mismatch"}
	var region_id := report.region_id as StringName
	if not _is_stable_id(region_id) or not _world_landing_region_ids.has(str(region_id)):
		return {"accepted": false, "reason": &"landing_region_not_referenced"}
	if report.terrain_profile_id != _terrain_profile_id:
		return {"accepted": false, "reason": &"landing_terrain_identity_mismatch"}
	if not report.coordinate_frame_generation is int:
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	var frame_generation := int(report.coordinate_frame_generation)
	if frame_generation < 1 \
			or frame_generation > _coordinate_frame.get_generation():
		return {"accepted": false, "reason": &"landing_composition_frame_generation_mismatch"}
	if not report.radius_datum is StringName \
			or report.radius_datum != LandingCompositionValidatorScript.RADIUS_DATUM \
			or not report.frame_seam is StringName \
			or report.frame_seam != LandingCompositionValidatorScript.FRAME_SEAM:
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	if not _is_finite_number(report.body_radius_meters) \
			or float(report.body_radius_meters) != _body_radius_meters:
		return {"accepted": false, "reason": &"landing_composition_radius_mismatch"}
	if not report.region_center_body_local_meters is Vector3 \
			or not (report.region_center_body_local_meters as Vector3).is_finite() \
			or (report.region_center_body_local_meters as Vector3).is_zero_approx():
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	if not report.evidence is Dictionary \
			or not _has_exact_string_keys(
			report.evidence as Dictionary, ["world", "terrain", "landing_region"]
		) or not report.authority is Dictionary:
		return {"accepted": false, "reason": &"invalid_landing_composition_schema"}
	if not _is_exact_zero_authority(report.authority as Dictionary):
		return {"accepted": false, "reason": &"landing_composition_claims_authority"}
	var region_radius := (
		report.region_center_body_local_meters as Vector3
	).length()
	if region_radius < _surface_radius_minimum_meters \
			or region_radius > _surface_radius_maximum_meters:
		return {"accepted": false, "reason": &"landing_composition_surface_mismatch"}
	return {"accepted": true, "reason": &"valid_landing_composition", "report": report.duplicate(true)}


func _landing_identity_matches(identity: Dictionary) -> bool:
	if _landing_composition_report.is_empty():
		return false
	var expected_keys := [
		"world_id",
		"body_id",
		"region_id",
		"terrain_profile_id",
	]
	if identity.size() != expected_keys.size():
		return false
	for key: Variant in identity:
		if not key is String or not expected_keys.has(key):
			return false
	for key in expected_keys:
		if not identity[key] is StringName:
			return false
	return identity.world_id == _landing_composition_report.world_id \
		and identity.body_id == _landing_composition_report.body_id \
		and identity.region_id == _landing_composition_report.region_id \
		and identity.terrain_profile_id \
		== _landing_composition_report.terrain_profile_id


func _transition(
		next_state: int,
		sample_id: StringName,
		fields: Dictionary
	) -> Dictionary:
	var previous_state_id := _state_id(_state)
	_state = next_state
	_transition_count += 1
	_phase_elapsed_seconds = 0.0
	_last_sample = fields.duplicate(true)
	_last_sample.erase("accepted")
	_last_sample.erase("reason")
	_last_sample["sample_id"] = sample_id
	if next_state == State.COMPLETED:
		_last_duration_seconds = _elapsed_seconds
	var result := _finish(
		true,
		&"completed" if next_state == State.COMPLETED else &"phase_advanced"
	)
	_emit_phase_signal(previous_state_id)
	if next_state == State.COMPLETED:
		_emit_snapshot_signal(session_completed)
	_emit_snapshot_signal(presentation_changed)
	return result


func _request_terminal(
		terminal_state: int,
		reason: StringName,
		expected_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not _is_stable_id(reason):
		return _finish(false, &"invalid_terminal_reason")
	_state = terminal_state
	_terminal_reason = reason
	_last_duration_seconds = _elapsed_seconds
	var result := _finish(
		true,
		&"aborted" if terminal_state == State.ABORTED else &"failed"
	)
	_emit_snapshot_signal(
		session_aborted if terminal_state == State.ABORTED else session_failed
	)
	_emit_snapshot_signal(presentation_changed)
	return result


func _attachment_rejection(
		expected_generation: int,
		expected_attachment_generation: int
	) -> StringName:
	if expected_generation != _generation:
		return &"stale_generation"
	if not _attached:
		return &"not_attached"
	if expected_attachment_generation != _attachment_generation:
		return &"stale_attachment_generation"
	return &""


func _running_rejection(
		expected_generation: int,
		expected_attachment_generation: int
	) -> StringName:
	var rejection := _attachment_rejection(
		expected_generation,
		expected_attachment_generation
	)
	if not rejection.is_empty():
		return rejection
	if not _is_running():
		return &"not_running"
	return &""


func _coordinate_frame_rejection(expected_generation: int) -> StringName:
	if _coordinate_frame == null \
			or _coordinate_frame.get_instance_id() != _coordinate_frame_instance_id:
		return &"coordinate_frame_detached"
	if expected_generation != _coordinate_frame.get_generation():
		return &"stale_coordinate_frame_generation"
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if frame_snapshot.get("body_id", &"") != _body_id \
			or frame_snapshot.get("orbital_frame_id", &"") != _orbital_frame_id \
			or float(frame_snapshot.get("body_radius_meters", 0.0)) \
			!= _body_radius_meters:
		return &"coordinate_frame_binding_mismatch"
	return &""


func _is_running() -> bool:
	return _state >= State.ORBIT_APPROACH and _state <= State.ORBIT_RETURN


func _return_identity_rejection(actor_instance_id: int, craft_instance_id: int) -> StringName:
	if _last_return_intent.is_empty():
		return &"return_travel_intent_required"
	if actor_instance_id < 1 or craft_instance_id < 1:
		return &"invalid_return_travel_identity"
	if int(_last_return_intent.get("actor_instance_id", 0)) != actor_instance_id \
			or int(_last_return_intent.get("craft_instance_id", 0)) != craft_instance_id:
		return &"return_travel_identity_mismatch"
	return &""


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_presentation_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


func _emit_snapshot_signal(target_signal: Signal) -> void:
	var previous_dispatch := _signal_dispatch_active
	_signal_dispatch_active = true
	target_signal.emit(get_presentation_snapshot())
	_signal_dispatch_active = previous_dispatch


func _emit_phase_signal(previous_state_id: StringName) -> void:
	var previous_dispatch := _signal_dispatch_active
	_signal_dispatch_active = true
	phase_changed.emit(get_presentation_snapshot(), previous_state_id)
	_signal_dispatch_active = previous_dispatch


func _next_state_id() -> StringName:
	match _state:
		State.IDLE:
			return &"orbit_approach"
		State.ORBIT_APPROACH:
			return &"atmospheric_entry" if _has_atmosphere else &"descent"
		State.ATMOSPHERIC_ENTRY:
			return &"descent"
		State.DESCENT:
			return &"surface_flight"
		State.SURFACE_FLIGHT:
			return &"landed"
		State.LANDED:
			return &"on_foot"
		State.ON_FOOT:
			return &"reboarded"
		State.REBOARDED:
			return &"takeoff"
		State.TAKEOFF:
			return &"ascent"
		State.ASCENT:
			return &"orbit_return"
		State.ORBIT_RETURN:
			return &"completed"
		_:
			return &""


static func _state_id(state: int) -> StringName:
	match state:
		State.IDLE: return &"idle"
		State.ORBIT_APPROACH: return &"orbit_approach"
		State.ATMOSPHERIC_ENTRY: return &"atmospheric_entry"
		State.DESCENT: return &"descent"
		State.SURFACE_FLIGHT: return &"surface_flight"
		State.LANDED: return &"landed"
		State.ON_FOOT: return &"on_foot"
		State.REBOARDED: return &"reboarded"
		State.TAKEOFF: return &"takeoff"
		State.ASCENT: return &"ascent"
		State.ORBIT_RETURN: return &"orbit_return"
		State.COMPLETED: return &"completed"
		State.FAILED: return &"failed"
		State.ABORTED: return &"aborted"
		_: return &"invalid"


static func _state_label(state: int) -> String:
	return String(_state_id(state)).replace("_", " ").capitalize()


static func _objective_text(state: int) -> String:
	match state:
		State.ORBIT_APPROACH: return "Approach the orbital handoff"
		State.ATMOSPHERIC_ENTRY: return "Complete atmospheric entry"
		State.DESCENT: return "Bind a validated landing region and descend"
		State.SURFACE_FLIGHT: return "Land through the validated region contract"
		State.LANDED: return "Disembark from the landed ship"
		State.ON_FOOT: return "Explore, then return to the ship"
		State.REBOARDED: return "Begin takeoff"
		State.TAKEOFF: return "Clear the surface"
		State.ASCENT: return "Ascend to orbital altitude"
		State.ORBIT_RETURN: return "Return to the orbital handoff"
		State.COMPLETED: return "Planetary transit complete"
		State.FAILED: return "Planetary transit failed"
		State.ABORTED: return "Planetary transit aborted"
		_: return ""


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	return true


static func _is_exact_zero_authority(candidate: Dictionary) -> bool:
	if not _has_exact_string_keys(candidate, LANDING_AUTHORITY_KEYS):
		return false
	for key in LANDING_AUTHORITY_KEYS:
		if not candidate[key] is bool or bool(candidate[key]):
			return false
	return true


static func _zero_authority_report() -> Dictionary:
	var report := {}
	for key in LANDING_AUTHORITY_KEYS:
		report[key] = false
	return report


static func _is_stable_id(value: StringName) -> bool:
	var id_text := String(value)
	if id_text.is_empty() or id_text.length() > 64 \
			or id_text.begins_with("_") or id_text.ends_with("_") \
			or id_text.contains("__"):
		return false
	var first := id_text.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in id_text.length():
		var code := id_text.unicode_at(index)
		if not (code >= 97 and code <= 122) \
				and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true
