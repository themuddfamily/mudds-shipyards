class_name EmberSurfaceLoopProductionBinding
extends Node

## Caller-driven early/late scheduler for an already composed EmberSurfaceLoopHost.
##
## A future GameFlow owner calls prepare_early_tick after its single actor sample
## and optional common-origin transaction. This node validates and freezes that
## detached evidence. Its priority-2 physics callback starts or advances the Host
## only after production actors have consumed the command visible at tick entry.

signal state_changed(snapshot: Dictionary)
signal completion_handback_ready(receipt: Dictionary)

enum State { IDLE, START_PENDING, RUNNING, HANDOFF_PENDING, FAILED }

const SCHEMA_VERSION := 1
const PHYSICS_PRIORITY := 2
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const ACTOR_SAMPLE_KEYS := [
	"actor_instance_id", "actor_kind", "available", "position",
]
const NO_REBASE_RESULT_KEYS := [
	"accepted", "actor_sample", "coordinate_frame_generation", "reason",
]
const COMMITTED_REBASE_RESULT_KEYS := [
	"accepted", "actor_sample", "coordinate_frame_generation", "reason", "receipt",
]
const HAND_BACK_RECEIPT_KEYS := [
	"boarding_area_instance_id", "boarding_reservation_retained",
	"boarding_reservation_token_instance_id", "command_source_restored",
	"current_attachment_generation", "generation", "host_attached",
	"host_command_source_instance_id", "host_id", "player_instance_id",
	"player_seated", "reason", "restored_command_source_instance_id",
	"retired_attachment_generation", "schema_version", "ship_instance_id",
	"ship_piloted",
]
const INTENT_PHASES := {
	&"disembark": EmberSurfaceLoopHost.Phase.LANDED,
	&"reboard": EmberSurfaceLoopHost.Phase.ON_FOOT,
	&"takeoff": EmberSurfaceLoopHost.Phase.REBOARDED,
}
const COMMON_AUTHORITY_KEYS := [
	"activity", "combat", "gameplay", "landing", "movement", "network",
	"reward", "save", "streaming", "teleport", "ui", "world_generation",
]
const ADJACENT_AUTHORITY_KEYS := [
	"actor_resample", "berth_mutation", "boarding_reservation_mutation",
	"command_source_mutation_outside_host", "cruise", "input",
	"origin_apply", "origin_commit", "origin_request", "presentation",
	"seat_mutation", "streaming_generation", "streaming_load_unload",
]
const PlanetaryCompositionScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const ReturnManifestScript := preload("res://scripts/world/ember_relay_survey_return_manifest.gd")

var _state := State.IDLE
var _generation := 0
var _configured := false
var _mutation_active := false
var _signal_dispatch_active := false
var _configuration_error: StringName = &""

var _host: EmberSurfaceLoopHost
var _composition_root: Node
var _bootstrap: EmberMoonStreamingBootstrap
var _origin_owner: CommonWorldOriginRebaseOwner
var _origin_binding: EmberMoonStreamingProductionBinding
var _frame: PlanetaryCoordinateFrame
var _ship: ArrowReconShip
var _player: PlayerController

var _host_instance_id := 0
var _composition_root_instance_id := 0
var _bootstrap_instance_id := 0
var _origin_owner_instance_id := 0
var _origin_binding_instance_id := 0
var _frame_instance_id := 0
var _ship_instance_id := 0
var _player_instance_id := 0
var _loaded_scene_instance_id := 0
var _location_generation := 0
var _planetary_composition: Node
var _atmosphere_composition: Node
var _last_planetary_altitude_m := 0.0
var _relay_return_manifest: RefCounted

var _last_caller_serial := 0
var _pending_envelope: Dictionary = {}
var _last_prepared_physics_frame := -1
var _last_consumed_caller_serial := 0
var _last_consumed_physics_frame := -1
var _last_intent_serial := 0
var _pending_intent: Dictionary = {}
var _prepared_count := 0
var _late_consume_count := 0
var _intent_consume_count := 0
var _start_count := 0
var _advance_count := 0
var _origin_adoption_count := 0
var _handback_count := 0
var _rejection_count := 0
var _reentrant_rejection_count := 0
var _last_result: Dictionary = {}
var _last_prepared_evidence: Dictionary = {}
var _last_late_result: Dictionary = {}
var _completion_handback: Dictionary = {}
var _completion_handback_delivered := false


func _enter_tree() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	set_process(false)
	set_physics_process(_configured)


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	set_process(false)
	set_physics_process(_configured)


func _exit_tree() -> void:
	# A staged early envelope belongs to exactly one live tree epoch. Never replay
	# it after a whole composition detach/re-entry.
	_pending_envelope.clear()
	_pending_intent.clear()
	if _state == State.START_PENDING:
		_state = State.IDLE
	set_physics_process(false)


func configure(host: EmberSurfaceLoopHost, expected_generation: int = 0) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	_mutation_active = true
	if expected_generation != _generation:
		return _finish(false, &"stale_generation")
	if _configured:
		return _finish(false, &"already_configured")
	if _generation >= MAX_SAFE_INTEGER:
		return _finish(false, &"generation_exhausted")
	var resolved := _resolve_host_composition(host)
	if not bool(resolved.get("accepted", false)):
		_configuration_error = resolved.get("reason", &"invalid_host") as StringName
		return _finish(false, _configuration_error)
	_host = host
	_composition_root = resolved.composition_root as Node
	_bootstrap = resolved.bootstrap as EmberMoonStreamingBootstrap
	_origin_owner = resolved.origin_owner as CommonWorldOriginRebaseOwner
	_origin_binding = resolved.origin_binding as EmberMoonStreamingProductionBinding
	_frame = resolved.frame as PlanetaryCoordinateFrame
	_ship = resolved.ship as ArrowReconShip
	_player = resolved.player as PlayerController
	_host_instance_id = _host.get_instance_id()
	_composition_root_instance_id = _composition_root.get_instance_id()
	_bootstrap_instance_id = _bootstrap.get_instance_id()
	_origin_owner_instance_id = _origin_owner.get_instance_id()
	_origin_binding_instance_id = _origin_binding.get_instance_id()
	_frame_instance_id = _frame.get_instance_id()
	_ship_instance_id = _ship.get_instance_id()
	_player_instance_id = _player.get_instance_id()
	_loaded_scene_instance_id = int(resolved.loaded_scene_instance_id)
	_location_generation = int(resolved.location_generation)
	_generation += 1
	_configured = true
	_configuration_error = &""
	_state = State.IDLE
	process_physics_priority = PHYSICS_PRIORITY
	set_physics_process(is_inside_tree())
	return _finish(true, &"configured")


## Instantiates the retained planetary surface composition under this real
## Ember production owner. The composition remains caller-observation driven.
func configure_planetary_surface(
		director: ActivityDirector,
		reward_sink: Callable,
		atmosphere_composition: Node = null
	) -> Dictionary:
	if not _configured or _composition_root == null:
		return _reject(&"production_binding_unavailable")
	if _planetary_composition != null:
		return _reject(&"planetary_composition_already_bound")
	_planetary_composition = PlanetaryCompositionScript.new() as Node
	_planetary_composition.name = "EmberPlanetarySurfaceProductionBinding"
	_composition_root.add_child(_planetary_composition)
	var result: Dictionary = _planetary_composition.call(
		&"configure", _host, director, reward_sink, _host.get_generation()
	)
	if not bool(result.get("accepted", false)):
		_planetary_composition.queue_free()
		_planetary_composition = null
	else:
		_relay_return_manifest = ReturnManifestScript.new()
	_atmosphere_composition = atmosphere_composition
	return result


func get_planetary_surface_snapshot() -> Dictionary:
	return _planetary_composition.call(&"get_snapshot") as Dictionary \
		if _planetary_composition != null else {}


func get_planetary_atmosphere_snapshot() -> Dictionary:
	if _atmosphere_composition == null:
		return {}
	return _atmosphere_composition.call(&"get_presentation_snapshot")


func get_planetary_surface_session_snapshot() -> Dictionary:
	if _planetary_composition == null:
		return {}
	return _planetary_composition.call(&"get_session_snapshot")


func restore_planetary_surface_session_snapshot(snapshot: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"restore_session_snapshot", snapshot)


func consume_planetary_orbit_return(handback: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"consume_orbit_return_handback", handback)


func accept_planetary_origin_rebase(receipt: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"accept_origin_rebase", receipt)


func submit_planetary_weather_exposure(
		hazard_id: StringName,
		position: Variant,
		altitude_m: float,
		caller_time_seconds: float,
		exposure: float,
		delta_seconds: float,
		shelter_scalar: float
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	var result: Dictionary = _planetary_composition.call(
		&"submit_weather_exposure", hazard_id, position, altitude_m,
		caller_time_seconds, exposure, delta_seconds, shelter_scalar
	)
	if bool(result.get("accepted", false)) and is_finite(altitude_m):
		_last_planetary_altitude_m = altitude_m
	_apply_planetary_atmosphere_recipe()
	return result


func submit_planetary_solar_observation(
		surface_up: Variant, direction_to_sun: Variant, caller_time_seconds: float
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	var result: Dictionary = _planetary_composition.call(
		&"submit_solar_observation", surface_up, direction_to_sun, caller_time_seconds
	)
	_apply_planetary_atmosphere_recipe()
	return result


func _apply_planetary_atmosphere_recipe() -> void:
	if _atmosphere_composition == null or _planetary_composition == null:
		return
	var snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var solar := snapshot.get("solar_phase", {}) as Dictionary
	var weather := (snapshot.get("weather_observation", {}) as Dictionary).duplicate(true)
	weather["altitude_m"] = _last_planetary_altitude_m
	if solar.is_empty() or weather.is_empty():
		return
	_atmosphere_composition.call(
		&"apply_retained_presentation_recipe", solar, weather
	)


func enter_planetary_water(position: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"enter_water", position)


func submit_planetary_water_contact(
		position: Variant, depth_m: float, velocity_mps: Variant, delta_seconds: float
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"submit_water_contact", position, depth_m, velocity_mps, delta_seconds
	)


func discover_planetary_settlements(position: Variant, radius_m: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"discover_settlements", position, radius_m)


func enter_planetary_settlement(structure_id: StringName, position: Variant) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"enter_settlement", structure_id, position)


func start_planetary_relay_survey() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"start_relay_survey")


func submit_planetary_relay_survey_position(position: Vector3) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"submit_relay_survey_position", position)


func submit_planetary_relay_survey_landmark(landmark_id: StringName, position: Vector3) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"submit_relay_survey_landmark", landmark_id, position)


func commit_planetary_relay_survey_reward() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"commit_relay_survey_reward")


## Emits a caller-routed return intent after the survey's reward handoff is
## accepted. This binding never moves the actor, grants the reward, or selects
## a berth; the receipt only names the authored Mudds Shipyards destination.
func issue_planetary_relay_survey_return_manifest() -> Dictionary:
	if _planetary_composition == null or _relay_return_manifest == null:
		return _reject(&"planetary_composition_unavailable")
	var snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var adapter_snapshot := snapshot.get("adapter", {}) as Dictionary
	var activity_snapshot := adapter_snapshot.get("activity_reward", {}) as Dictionary
	return _relay_return_manifest.issue(activity_snapshot, _host.get_attachment_generation())


func reset_planetary_relay_survey_return_manifest() -> Dictionary:
	if _relay_return_manifest == null:
		return _reject(&"planetary_composition_unavailable")
	return _relay_return_manifest.reset()


func get_planetary_relay_survey_return_manifest_snapshot() -> Dictionary:
	if _relay_return_manifest == null:
		return {}
	return _relay_return_manifest.get_snapshot()


func detach_planetary_surface() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"detach")


func reenter_planetary_surface() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"reenter")


## Called once at the future Main/GameFlow priority -100 boundary. The origin
## result must be the exact result already produced for this same actor sample.
func prepare_early_tick(
	caller_serial: int,
	delta: float,
	actor_sample: Variant,
	origin_result: Variant,
	current_coordinate_frame_generation: int,
	current_location_generation: int,
	expected_generation: int
) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	_mutation_active = true
	var basic_rejection := _basic_mutation_rejection(expected_generation)
	if not basic_rejection.is_empty():
		return _finish(false, basic_rejection)
	if _state in [State.HANDOFF_PENDING, State.FAILED]:
		return _finish(false, &"terminal_state")
	if not _pending_envelope.is_empty():
		return _finish(false, &"pending_tick_exists")
	if caller_serial < 1 or caller_serial > MAX_SAFE_INTEGER:
		return _finish(false, &"invalid_caller_serial")
	if _last_caller_serial >= MAX_SAFE_INTEGER:
		return _finish(false, &"caller_serial_exhausted")
	if caller_serial != _last_caller_serial + 1:
		return _finish(
			false,
			&"caller_serial_replayed" if caller_serial <= _last_caller_serial \
				else &"caller_serial_skipped",
		)
	if not is_finite(delta) or delta < 0.0 \
			or delta > EmberSurfaceLoopHost.MAX_CALLER_DELTA_SECONDS:
		return _finish(false, &"invalid_delta")
	var identity_rejection := _identity_rejection()
	if not identity_rejection.is_empty():
		return _fail_guarded(identity_rejection)
	var host_snapshot := _host.get_snapshot()
	if current_coordinate_frame_generation != _frame.get_generation():
		return _finish(false, &"stale_coordinate_frame_generation")
	if current_location_generation != _location_generation \
			or int(host_snapshot.get("location_generation", 0)) != _location_generation:
		return _finish(false, &"stale_location_generation")
	var sample_validation := _validate_actor_sample(actor_sample)
	if not bool(sample_validation.get("accepted", false)):
		_abort_active_relay_survey(&"actor_evidence_lost")
		return _finish(false, sample_validation.get("reason", &"invalid_actor_sample") as StringName)
	var sample := (actor_sample as Dictionary).duplicate(true)
	var origin_validation := _validate_origin_result(
		origin_result, sample, current_coordinate_frame_generation
	)
	if not bool(origin_validation.get("accepted", false)):
		return _finish(false, origin_validation.get("reason", &"invalid_origin_result") as StringName)

	var adopted := false
	var origin_reason := origin_validation.get("origin_reason", &"") as StringName
	if origin_reason == &"rebase_committed":
		var adopted_result := _host.adopt_committed_origin_rebase(
			(origin_result as Dictionary).get("receipt", {}).duplicate(true),
			_host.get_generation(),
			_host.get_attachment_generation(),
			_location_generation,
		)
		if not bool(adopted_result.get("accepted", false)):
			return _fail_guarded(&"host_origin_adoption_rejected")
		adopted = true
		_origin_adoption_count += 1
	elif int(host_snapshot.get("coordinate_frame_generation", 0)) \
			!= current_coordinate_frame_generation:
		return _finish(false, &"host_coordinate_frame_not_adopted")

	_pending_envelope = {
		"caller_serial": caller_serial,
		"physics_frame": int(Engine.get_physics_frames()),
		"delta": delta,
		"actor_sample": sample.duplicate(true),
		"origin_reason": origin_reason,
		"origin_adopted": adopted,
		"coordinate_frame_generation": current_coordinate_frame_generation,
		"location_generation": current_location_generation,
		"host_generation": _host.get_generation(),
		"host_attachment_generation": _host.get_attachment_generation(),
	}.duplicate(true)
	_last_prepared_evidence = _pending_envelope.duplicate(true)
	_last_prepared_physics_frame = int(Engine.get_physics_frames())
	_last_caller_serial = caller_serial
	_prepared_count += 1
	if _state == State.IDLE:
		_state = State.START_PENDING
	return _finish(true, &"early_tick_prepared")


## Queue a disembark intent against the prepared early envelope. The priority-2
## callback alone calls the Host's public mutation.
func queue_disembark_intent(intent_serial: int, expected_generation: int) -> Dictionary:
	return _queue_host_intent(
		intent_serial, &"disembark", EmberSurfaceLoopHost.Phase.LANDED,
		expected_generation,
	)


## Queue a reboard intent against the prepared early envelope.
func queue_reboard_intent(intent_serial: int, expected_generation: int) -> Dictionary:
	return _queue_host_intent(
		intent_serial, &"reboard", EmberSurfaceLoopHost.Phase.ON_FOOT,
		expected_generation,
	)


## Queue a takeoff intent against the prepared early envelope.
func queue_takeoff_intent(intent_serial: int, expected_generation: int) -> Dictionary:
	return _queue_host_intent(
		intent_serial, &"takeoff", EmberSurfaceLoopHost.Phase.REBOARDED,
		expected_generation,
	)


func _queue_host_intent(
	intent_serial: int,
	intent_id: StringName,
	expected_host_phase: int,
	expected_generation: int
) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	_mutation_active = true
	var basic_rejection := _basic_mutation_rejection(expected_generation)
	if not basic_rejection.is_empty():
		return _finish(false, basic_rejection)
	if _state != State.RUNNING or _pending_envelope.is_empty():
		return _finish(false, &"intent_without_pending_tick")
	if int(_pending_envelope.get("physics_frame", -1)) != int(Engine.get_physics_frames()):
		return _finish(false, &"intent_stale_physics_frame")
	if not _pending_intent.is_empty():
		return _finish(false, &"pending_intent_exists")
	if intent_serial < 1 or intent_serial > MAX_SAFE_INTEGER:
		return _finish(false, &"invalid_intent_serial")
	if _last_intent_serial >= MAX_SAFE_INTEGER:
		return _finish(false, &"intent_serial_exhausted")
	if intent_serial != _last_intent_serial + 1:
		return _finish(
			false,
			&"intent_serial_replayed" if intent_serial <= _last_intent_serial \
				else &"intent_serial_skipped",
		)
	if not INTENT_PHASES.has(intent_id):
		return _finish(false, &"invalid_host_intent")
	if expected_host_phase != int(INTENT_PHASES[intent_id]) \
			or _host.get_phase() != expected_host_phase:
		return _finish(false, &"host_intent_phase_mismatch")
	_pending_intent = {
		"intent_serial": intent_serial,
		"intent_id": intent_id,
		"expected_host_phase": expected_host_phase,
		"caller_serial": int(_pending_envelope.caller_serial),
		"physics_frame": int(_pending_envelope.physics_frame),
		"host_generation": _host.get_generation(),
		"host_attachment_generation": _host.get_attachment_generation(),
	}.duplicate(true)
	_last_intent_serial = intent_serial
	return _finish(true, &"host_intent_queued")


## Completion handback is delivered once at a later early/caller boundary. The
## receipt is detached evidence only; the Host performed the atomic return.
func take_completion_handback(expected_generation: int) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	_mutation_active = true
	var basic_rejection := _basic_mutation_rejection(expected_generation)
	if not basic_rejection.is_empty():
		return _finish(false, basic_rejection)
	if _state != State.HANDOFF_PENDING or _completion_handback.is_empty():
		return _finish(false, &"handback_not_pending")
	if _completion_handback_delivered:
		return _finish(false, &"handback_already_delivered")
	_completion_handback_delivered = true
	var result := _finish(true, &"completion_handback_delivered")
	result["runtime_ownership_return"] = _completion_handback.duplicate(true)
	_last_result = result.duplicate(true)
	return result


func get_generation() -> int:
	return _generation


func get_state() -> int:
	return _state


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": _state,
		"state_id": _state_id(_state),
		"generation": _generation,
		"configured": _configured,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"physics_priority": process_physics_priority,
		"automatic_process": is_processing(),
		"automatic_late_physics_process": is_physics_processing(),
		"identities": {
			"host_instance_id": _host_instance_id,
			"composition_root_instance_id": _composition_root_instance_id,
			"bootstrap_instance_id": _bootstrap_instance_id,
			"origin_owner_instance_id": _origin_owner_instance_id,
			"origin_binding_instance_id": _origin_binding_instance_id,
			"coordinate_frame_instance_id": _frame_instance_id,
			"ship_instance_id": _ship_instance_id,
			"player_instance_id": _player_instance_id,
			"loaded_scene_instance_id": _loaded_scene_instance_id,
			"location_generation": _location_generation,
		}.duplicate(true),
		"last_caller_serial": _last_caller_serial,
		"pending_envelope": _pending_envelope.duplicate(true),
		"last_prepared_physics_frame": _last_prepared_physics_frame,
		"last_consumed_caller_serial": _last_consumed_caller_serial,
		"last_consumed_physics_frame": _last_consumed_physics_frame,
		"last_intent_serial": _last_intent_serial,
		"pending_intent": _pending_intent.duplicate(true),
		"prepared_count": _prepared_count,
		"late_consume_count": _late_consume_count,
		"intent_consume_count": _intent_consume_count,
		"start_count": _start_count,
		"advance_count": _advance_count,
		"origin_adoption_count": _origin_adoption_count,
		"handback_count": _handback_count,
		"rejection_count": _rejection_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"last_prepared_evidence": _last_prepared_evidence.duplicate(true),
		"last_late_result": _last_late_result.duplicate(true),
		"completion_handback_pending": not _completion_handback.is_empty(),
		"completion_handback_delivered": _completion_handback_delivered,
		"completion_handback": _completion_handback.duplicate(true),
		"planetary_surface": get_planetary_surface_snapshot(),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if process_physics_priority != PHYSICS_PRIORITY:
		errors.append("late physics priority drifted from 2")
	if is_processing():
		errors.append("binding must not own an idle process callback")
	if _configured:
		var identity_rejection := _identity_rejection()
		if not identity_rejection.is_empty():
			errors.append("bound identity invalid: %s" % identity_rejection)
	if _pending_envelope.is_empty() != (_state != State.START_PENDING and _state != State.RUNNING):
		# RUNNING legitimately has no envelope between caller and late boundaries.
		if _state == State.START_PENDING or not _pending_envelope.is_empty():
			errors.append("pending envelope/state mismatch")
	if not _pending_intent.is_empty() and _pending_envelope.is_empty():
		errors.append("a Host intent cannot outlive its exact pending envelope")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"scheduler": {
			"early_caller_priority": -100,
			"arrow_priority": 0,
			"player_priority_minimum": 0,
			"player_seated_priority_minimum": 1,
			"late_binding_priority": PHYSICS_PRIORITY,
			"start_is_late_only": true,
			"advance_is_late_only": true,
			"new_command_visible_no_earlier_than_next_hero_tick": true,
			"same_engine_physics_frame_required": true,
		}.duplicate(true),
		"owned_capabilities": {
			"caller_serial_fence": true,
			"detached_pending_envelope": true,
			"host_lifecycle_forwarding": true,
			"typed_host_intent_forwarding": true,
			"immediate_committed_origin_adoption_invocation": true,
			"late_physics_cadence": true,
			"completion_handback_relay": true,
		}.duplicate(true),
		"common_authority": _false_roster(COMMON_AUTHORITY_KEYS),
		"adjacent_authority": _false_roster(ADJACENT_AUTHORITY_KEYS),
	}.duplicate(true)


func _physics_process(_engine_delta: float) -> void:
	if _pending_envelope.is_empty() or _mutation_active or _signal_dispatch_active:
		return
	_mutation_active = true
	var envelope := _pending_envelope.duplicate(true)
	var current_physics_frame := int(Engine.get_physics_frames())
	if int(envelope.get("physics_frame", -1)) != current_physics_frame:
		_pending_envelope.clear()
		_pending_intent.clear()
		_fail_late(&"stale_physics_frame")
		return
	var caller_serial := int(envelope.get("caller_serial", 0))
	if caller_serial != _last_consumed_caller_serial + 1 \
			or caller_serial != _last_caller_serial:
		_pending_envelope.clear()
		_pending_intent.clear()
		_fail_late(&"late_consume_serial_mismatch")
		return
	# The envelope becomes consumed at one point only, after its exact-frame and
	# monotonic fences pass. Every later branch observes this one accounting fact.
	_pending_envelope.clear()
	var intent := _pending_intent.duplicate(true)
	_pending_intent.clear()
	_late_consume_count += 1
	_last_consumed_caller_serial = caller_serial
	_last_consumed_physics_frame = current_physics_frame
	var identity_rejection := _identity_rejection()
	if not identity_rejection.is_empty():
		_fail_late(identity_rejection)
		return
	if int(envelope.get("host_generation", -1)) != _host.get_generation() \
			or int(envelope.get("host_attachment_generation", -1)) \
				!= _host.get_attachment_generation():
		_abort_active_relay_survey(&"host_generation_drift")
		_fail_late(&"host_generation_drift")
		return
	if int(envelope.get("coordinate_frame_generation", 0)) != _frame.get_generation():
		_fail_late(&"coordinate_frame_generation_drift")
		return
	if int(envelope.get("location_generation", 0)) != _location_generation:
		_fail_late(&"location_generation_drift")
		return
	if not intent.is_empty():
		var intent_rejection := _consume_host_intent(intent, envelope)
		if not intent_rejection.is_empty():
			_fail_late(intent_rejection)
			return
	var relay_forward_rejection := _forward_active_relay_position(envelope)
	if not relay_forward_rejection.is_empty():
		_fail_late(relay_forward_rejection)
		return

	var phase := _host.get_phase()
	var operation: Dictionary
	if _state == State.START_PENDING:
		if phase != EmberSurfaceLoopHost.Phase.IDLE:
			_fail_late(&"host_start_phase_drift")
			return
		operation = _host.start(
			_host.get_generation(),
			_host.get_attachment_generation(),
			_frame.get_generation(),
		)
		if not bool(operation.get("accepted", false)):
			_fail_late(operation.get("reason", &"host_start_rejected") as StringName)
			return
		_state = State.RUNNING
		_start_count += 1
		_last_late_result = operation.duplicate(true)
		_finish_late_signal(&"host_started")
		return
	if _state != State.RUNNING:
		_fail_late(&"late_tick_out_of_order")
		return
	if phase == EmberSurfaceLoopHost.Phase.COMPLETED:
		_complete_handback_late()
		return
	operation = _host.advance_physics(
		float(envelope.get("delta", -1.0)),
		_host.get_generation(),
		_host.get_attachment_generation(),
		_frame.get_generation(),
		_location_generation,
	)
	if not bool(operation.get("accepted", false)):
		_fail_late(operation.get("reason", &"host_advance_rejected") as StringName)
		return
	_advance_count += 1
	_last_late_result = operation.duplicate(true)
	if _host.get_phase() == EmberSurfaceLoopHost.Phase.COMPLETED:
		_complete_handback_late()
		return
	_finish_late_signal(&"host_advanced")


func _forward_active_relay_position(envelope: Dictionary) -> StringName:
	if _planetary_composition == null:
		return &""
	var surface_snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var activity: Dictionary = surface_snapshot.get("adapter", {}).get("activity_reward", {}) as Dictionary
	if StringName(activity.get("state", &"")) not in [&"active", &"awaiting_reward"]:
		return &""
	var sample: Dictionary = envelope.get("actor_sample", {}) as Dictionary
	var position: Variant = sample.get("position", Vector3.INF)
	if not position is Vector3 or not (position as Vector3).is_finite():
		return &"invalid_relay_position_sample"
	var forwarded: Dictionary = _planetary_composition.call(
		&"submit_relay_survey_position", position
	)
	return &"relay_position_forward_rejected" if not bool(forwarded.get("accepted", false)) else &""


func _abort_active_relay_survey(reason: StringName) -> void:
	if _planetary_composition == null:
		return
	var snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var activity: Dictionary = snapshot.get("adapter", {}).get("activity_reward", {}) as Dictionary
	if StringName(activity.get("state", &"")) in [&"active", &"awaiting_reward"]:
		_planetary_composition.call(&"abort_relay_survey", reason)


func _complete_handback_late() -> void:
	var retired_attachment_generation := _host.get_attachment_generation()
	var returned := _host.return_runtime_ownership(
		_host.get_generation(), _host.get_attachment_generation()
	)
	if not bool(returned.get("accepted", false)):
		_fail_late(returned.get("reason", &"runtime_ownership_return_rejected") as StringName)
		return
	var receipt := returned.get("runtime_ownership_return", {}) as Dictionary
	var receipt_rejection := _handback_receipt_rejection(
		receipt, retired_attachment_generation
	)
	if not receipt_rejection.is_empty():
		_fail_late(receipt_rejection)
		return
	_completion_handback = receipt.duplicate(true)
	_completion_handback_delivered = false
	_state = State.HANDOFF_PENDING
	_handback_count += 1
	_last_late_result = returned.duplicate(true)
	_mutation_active = false
	_signal_dispatch_active = true
	state_changed.emit(get_snapshot())
	completion_handback_ready.emit(_completion_handback.duplicate(true))
	_signal_dispatch_active = false


func _consume_host_intent(intent: Dictionary, envelope: Dictionary) -> StringName:
	if int(intent.get("caller_serial", 0)) != int(envelope.get("caller_serial", -1)) \
			or int(intent.get("physics_frame", -1)) != int(envelope.get("physics_frame", -2)):
		return &"host_intent_tick_mismatch"
	if int(intent.get("host_generation", -1)) != _host.get_generation() \
			or int(intent.get("host_attachment_generation", -1)) \
				!= _host.get_attachment_generation():
		return &"host_intent_generation_drift"
	var intent_id := intent.get("intent_id", &"") as StringName
	var phase := int(intent.get("expected_host_phase", -1))
	if not INTENT_PHASES.has(intent_id) \
			or int(INTENT_PHASES[intent_id]) != phase or _host.get_phase() != phase:
		return &"host_intent_phase_drift"
	var result: Dictionary
	match intent_id:
		&"disembark":
			result = _host.request_disembark(
				_host.get_generation(), _host.get_attachment_generation()
			)
		&"reboard":
			result = _host.request_reboard(
				_host.get_generation(), _host.get_attachment_generation()
			)
		&"takeoff":
			result = _host.request_takeoff(
				_host.get_generation(), _host.get_attachment_generation()
			)
		_:
			return &"invalid_host_intent"
	if not bool(result.get("accepted", false)):
		return result.get("reason", &"host_intent_rejected") as StringName
	_intent_consume_count += 1
	return &""


func _handback_receipt_rejection(
	receipt: Dictionary, retired_attachment_generation: int
) -> StringName:
	if not _exact_keys(receipt, HAND_BACK_RECEIPT_KEYS):
		return &"runtime_ownership_return_schema_mismatch"
	for key in [
		"schema_version", "generation", "retired_attachment_generation",
		"current_attachment_generation", "ship_instance_id", "player_instance_id",
		"boarding_area_instance_id", "boarding_reservation_token_instance_id",
		"host_command_source_instance_id", "restored_command_source_instance_id",
	]:
		if not receipt.get(key) is int:
			return &"runtime_ownership_return_type_mismatch"
	for key in [
		"boarding_reservation_retained", "command_source_restored", "ship_piloted",
		"player_seated", "host_attached",
	]:
		if not receipt.get(key) is bool:
			return &"runtime_ownership_return_type_mismatch"
	if not receipt.get("reason") is StringName or not receipt.get("host_id") is StringName:
		return &"runtime_ownership_return_type_mismatch"
	if int(receipt.schema_version) != EmberSurfaceLoopHost.SCHEMA_VERSION \
			or receipt.reason != &"runtime_ownership_returned" \
			or receipt.host_id != EmberSurfaceLoopHost.HOST_ID:
		return &"runtime_ownership_return_identity_mismatch"
	if int(receipt.generation) != _host.get_generation() \
			or int(receipt.retired_attachment_generation) != retired_attachment_generation \
			or int(receipt.current_attachment_generation) != retired_attachment_generation + 1 \
			or _host.get_attachment_generation() != retired_attachment_generation + 1:
		return &"runtime_ownership_return_generation_mismatch"
	if int(receipt.ship_instance_id) != _ship_instance_id \
			or int(receipt.player_instance_id) != _player_instance_id \
			or int(receipt.boarding_reservation_token_instance_id) != _player_instance_id:
		return &"runtime_ownership_return_actor_mismatch"
	if int(receipt.boarding_area_instance_id) <= 0 \
			or int(receipt.host_command_source_instance_id) <= 0 \
			or int(receipt.restored_command_source_instance_id) <= 0:
		return &"runtime_ownership_return_capability_identity_invalid"
	if not bool(receipt.boarding_reservation_retained) \
			or not bool(receipt.command_source_restored) \
			or not bool(receipt.ship_piloted) or not bool(receipt.player_seated) \
			or bool(receipt.host_attached):
		return &"runtime_ownership_return_state_mismatch"
	if not _detached_value_safe(receipt):
		return &"runtime_ownership_return_not_detached"
	var host_snapshot := _host.get_snapshot()
	var host_return := host_snapshot.get("runtime_ownership_return", {}) as Dictionary
	if bool(host_snapshot.get("attached", true)) \
			or int(host_snapshot.get("generation", -1)) != int(receipt.generation) \
			or int(host_snapshot.get("attachment_generation", -1)) \
				!= int(receipt.current_attachment_generation) \
			or not bool(host_return.get("returned", false)) \
			or host_return.get("last_receipt", {}) != receipt:
		return &"runtime_ownership_return_host_snapshot_mismatch"
	if _ship.get_command_source() == null \
			or _ship.get_command_source().get_instance_id() \
				!= int(receipt.restored_command_source_instance_id) \
			or _ship.get_command_source().get_instance_id() \
				== int(receipt.host_command_source_instance_id) \
			or _ship.is_piloted() != bool(receipt.ship_piloted) \
			or _player.is_seated() != bool(receipt.player_seated):
		return &"runtime_ownership_return_live_actor_mismatch"
	var boarding_area := instance_from_id(int(receipt.boarding_area_instance_id))
	var ship_boarding_area := _ship.get_node_or_null(^"ShipBoardingArea")
	if not boarding_area is ShipBoardingArea \
			or not _node_current(boarding_area) \
			or boarding_area != ship_boarding_area \
			or (boarding_area as ShipBoardingArea).get_reservation_token() != _player:
		return &"runtime_ownership_return_live_reservation_mismatch"
	return &""


func _resolve_host_composition(host: EmberSurfaceLoopHost) -> Dictionary:
	if not _node_current(host):
		return {"accepted": false, "reason": &"host_unavailable"}
	var snapshot := host.get_snapshot()
	if not bool(snapshot.get("attached", false)) \
			or int(snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE:
		return {"accepted": false, "reason": &"host_not_idle_attached"}
	var identities := snapshot.get("identities", {}) as Dictionary
	var composition_root := host.get_parent()
	var bootstrap := instance_from_id(int(identities.get("bootstrap_instance_id", 0)))
	var owner := instance_from_id(int(identities.get("origin_owner_instance_id", 0)))
	var binding := instance_from_id(int(identities.get("origin_binding_instance_id", 0)))
	var ship := instance_from_id(int(identities.get("ship_instance_id", 0)))
	var player := instance_from_id(int(identities.get("player_instance_id", 0)))
	if not _node_current(composition_root) \
			or composition_root.get_instance_id() != int(identities.get("composition_root_instance_id", 0)):
		return {"accepted": false, "reason": &"composition_root_mismatch"}
	if not bootstrap is EmberMoonStreamingBootstrap \
			or not owner is CommonWorldOriginRebaseOwner \
			or not binding is EmberMoonStreamingProductionBinding \
			or not ship is ArrowReconShip or not player is PlayerController:
		return {"accepted": false, "reason": &"host_identity_schema_mismatch"}
	for dependency: Node in [host, bootstrap, owner, binding, ship, player]:
		if not _node_current(dependency) or dependency.get_parent() != composition_root:
			return {"accepted": false, "reason": &"host_topology_mismatch"}
	var frame := (bootstrap as EmberMoonStreamingBootstrap).get_coordinate_frame_for_session()
	if not frame is PlanetaryCoordinateFrame:
		return {"accepted": false, "reason": &"coordinate_frame_unavailable"}
	var host_audit := host.audit()
	if not bool(host_audit.get("valid", false)):
		return {"accepted": false, "reason": &"host_audit_invalid"}
	return {
		"accepted": true,
		"reason": &"host_composition_resolved",
		"composition_root": composition_root,
		"bootstrap": bootstrap,
		"origin_owner": owner,
		"origin_binding": binding,
		"frame": frame,
		"ship": ship,
		"player": player,
		"loaded_scene_instance_id": int(identities.get("loaded_scene_instance_id", 0)),
		"location_generation": int(snapshot.get("location_generation", 0)),
	}


func _validate_actor_sample(value: Variant) -> Dictionary:
	if not value is Dictionary or not _exact_keys(value as Dictionary, ACTOR_SAMPLE_KEYS):
		return {"accepted": false, "reason": &"actor_sample_schema_mismatch"}
	var sample := value as Dictionary
	if not sample.available is bool or not bool(sample.available) \
			or not sample.position is Vector3 or not (sample.position as Vector3).is_finite() \
			or not sample.actor_kind is StringName or not sample.actor_instance_id is int:
		return {"accepted": false, "reason": &"actor_sample_invalid"}
	var actor: Node3D
	if sample.actor_kind == &"ship" and int(sample.actor_instance_id) == _ship_instance_id:
		actor = _ship
	elif sample.actor_kind == &"player" and int(sample.actor_instance_id) == _player_instance_id:
		actor = _player
	else:
		return {"accepted": false, "reason": &"actor_identity_mismatch"}
	if not _node_current(actor) or not actor.global_position.is_equal_approx(sample.position as Vector3):
		return {"accepted": false, "reason": &"actor_observation_mismatch"}
	return {"accepted": true, "reason": &"actor_sample_valid"}


func _validate_origin_result(
	value: Variant, sample: Dictionary, current_frame_generation: int
) -> Dictionary:
	if not value is Dictionary:
		return {"accepted": false, "reason": &"origin_result_schema_mismatch"}
	var result := value as Dictionary
	if not result.get("accepted", false) is bool or not bool(result.get("accepted", false)):
		return {"accepted": false, "reason": &"origin_result_rejected"}
	var reason := result.get("reason", &"") as StringName
	var expected_keys := COMMITTED_REBASE_RESULT_KEYS \
		if reason == &"rebase_committed" else NO_REBASE_RESULT_KEYS
	if not _exact_keys(result, expected_keys):
		return {"accepted": false, "reason": &"origin_result_schema_mismatch"}
	if reason not in [&"no_rebase_required", &"rebase_committed"]:
		return {"accepted": false, "reason": &"origin_result_reason_invalid"}
	if result.get("actor_sample", {}) != sample \
			or not result.get("coordinate_frame_generation", 0) is int \
			or int(result.coordinate_frame_generation) != current_frame_generation:
		return {"accepted": false, "reason": &"origin_result_observation_mismatch"}
	var binding_snapshot := _origin_binding.get_snapshot()
	var owner_audit := _origin_owner.audit()
	if not bool(owner_audit.get("valid", false)) \
			or int(binding_snapshot.get("last_actor_instance_id", 0)) \
				!= int(sample.actor_instance_id) \
			or binding_snapshot.get("last_actor_kind", &"") != sample.actor_kind \
			or binding_snapshot.get("last_world_streaming_position", Vector3.INF) \
				!= sample.position \
			or int(binding_snapshot.get("bound_coordinate_frame_generation", 0)) \
				!= current_frame_generation:
		return {"accepted": false, "reason": &"origin_result_not_current"}
	if reason == &"rebase_committed":
		var receipt := result.get("receipt", {}) as Dictionary
		var owner_snapshot := _origin_owner.get_snapshot()
		if receipt.is_empty() or owner_snapshot.get("last_receipt", {}) != receipt \
				or int(owner_snapshot.get("last_target_generation", 0)) != current_frame_generation:
			return {"accepted": false, "reason": &"origin_receipt_mismatch"}
	return {"accepted": true, "reason": &"origin_result_valid", "origin_reason": reason}


func _identity_rejection() -> StringName:
	if process_physics_priority != PHYSICS_PRIORITY:
		return &"physics_priority_drift"
	if not _node_current(self) or not _node_current(_host) \
			or not _node_current(_composition_root) or not _node_current(_bootstrap) \
			or not _node_current(_origin_owner) or not _node_current(_origin_binding) \
			or not _node_current(_ship) or not _node_current(_player):
		return &"dependency_unavailable"
	if _host.get_instance_id() != _host_instance_id \
			or _composition_root.get_instance_id() != _composition_root_instance_id \
			or _bootstrap.get_instance_id() != _bootstrap_instance_id \
			or _origin_owner.get_instance_id() != _origin_owner_instance_id \
			or _origin_binding.get_instance_id() != _origin_binding_instance_id \
			or _ship.get_instance_id() != _ship_instance_id \
			or _player.get_instance_id() != _player_instance_id:
		return &"dependency_identity_mismatch"
	if get_parent() != _composition_root or _host.get_parent() != _composition_root \
			or _bootstrap.get_parent() != _composition_root \
			or _origin_owner.get_parent() != _composition_root \
			or _origin_binding.get_parent() != _composition_root \
			or _ship.get_parent() != _composition_root or _player.get_parent() != _composition_root:
		return &"dependency_topology_mismatch"
	if not is_instance_valid(_frame) or _frame.get_instance_id() != _frame_instance_id \
			or _bootstrap.get_coordinate_frame_for_session() != _frame:
		return &"coordinate_frame_identity_mismatch"
	var host_snapshot := _host.get_snapshot()
	var identities := host_snapshot.get("identities", {}) as Dictionary
	if int(identities.get("loaded_scene_instance_id", 0)) != _loaded_scene_instance_id \
			or int(host_snapshot.get("location_generation", 0)) != _location_generation:
		return &"loaded_location_identity_mismatch"
	return &""


func _basic_mutation_rejection(expected_generation: int) -> StringName:
	if expected_generation != _generation:
		return &"stale_generation"
	if not _configured:
		return &"not_configured"
	if not is_inside_tree() or is_queued_for_deletion():
		return &"binding_unavailable"
	return &""


func _fail_guarded(reason: StringName) -> Dictionary:
	_state = State.FAILED
	_pending_envelope.clear()
	_pending_intent.clear()
	return _finish(false, reason)


func _fail_late(reason: StringName) -> void:
	_state = State.FAILED
	_last_late_result = {"accepted": false, "reason": reason}.duplicate(true)
	_finish_late_signal(reason)


func _finish_late_signal(_reason: StringName) -> void:
	_mutation_active = false
	_signal_dispatch_active = true
	state_changed.emit(get_snapshot())
	_signal_dispatch_active = false


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	if not accepted:
		_rejection_count += 1
	_last_result = _result(accepted, reason)
	return _last_result.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	_rejection_count += 1
	if reason == &"reentrant_call":
		_reentrant_rejection_count += 1
	return _result(false, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


static func _node_current(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node \
		and (value as Node).is_inside_tree() and not (value as Node).is_queued_for_deletion()


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value:
		if not key is String or not expected.has(key):
			return false
	return true


static func _false_roster(keys: Array) -> Dictionary:
	var result := {}
	for key in keys:
		result[key] = false
	return result.duplicate(true)


static func _detached_value_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL:
			return false
		TYPE_ARRAY:
			for item: Variant in value as Array:
				if not _detached_value_safe(item):
					return false
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if not _detached_value_safe(key) \
						or not _detached_value_safe((value as Dictionary)[key]):
					return false
	return true


static func _state_id(value: int) -> StringName:
	match value:
		State.IDLE: return &"idle"
		State.START_PENDING: return &"start_pending"
		State.RUNNING: return &"running"
		State.HANDOFF_PENDING: return &"handoff_pending"
		State.FAILED: return &"failed"
		_: return &"unknown"
