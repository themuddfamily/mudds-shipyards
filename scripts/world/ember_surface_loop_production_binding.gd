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
signal service_terminal_repair_feedback(feedback: Dictionary)
signal station_return_handoff_ready(intent: Dictionary)

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
const ReturnTravelAdapterScript := preload("res://scripts/world/ember_relay_survey_return_travel_adapter.gd")
const ReturnBerthAdapterScript := preload("res://scripts/world/planetary_return_berth_adapter.gd")
const ReturnPersistenceAdapterScript := preload("res://scripts/world/planetary_return_persistence_adapter.gd")
const PlanetaryTravelAudioBindingScript := preload("res://scripts/audio/planetary_travel_audio_binding.gd")
const ArrowEntryPresentationBindingScript := preload("res://scripts/ships/arrow_entry_presentation_binding.gd")
const HeroAirlessLandingWashBindingScript := preload(
	"res://scripts/ships/hero_airless_landing_wash_binding.gd"
)
const HeroAtmosphericEntryEnvelopeBindingScript := preload(
	"res://scripts/ships/hero_atmospheric_entry_envelope_binding.gd"
)
const StagingRelayProximityBindingScript := preload(
	"res://scripts/world/ember_staging_relay_proximity_binding.gd"
)
const STAGING_RELAY_ACCESS_PATH := \
	^"LandingRegion/SurfaceLandmarks/RouteMarkers/StagingRelayAccess"
const RETURN_PERSISTENCE_SCHEMA_VERSION := 1
const RETURN_PERSISTENCE_PAYLOAD_KIND: StringName = &"ember_planetary_return"
const RETURN_PERSISTENCE_RECORD_KEYS := [
	"schema_version", "payload_kind", "slot_id", "binding_generation",
	"run_generation", "receipt_sha256", "session",
]
const RELAY_REWARD_INTENT_KEYS := [
	"activity_generation", "activity_id", "attachment_generation",
	"objective_id", "recovery_id", "return_target_id", "reward_authority_id",
	"reward_id", "reward_store_id", "run_generation", "world_id",
]
const RELAY_REWARD_EVIDENCE_KEYS := [
	"activity_generation", "actor_instance_id", "actor_kind", "caller_serial",
	"completion_attachment_generation", "craft_instance_id",
	"host_attachment_generation", "host_generation", "host_instance_id",
	"owner_generation", "physics_frame", "session_instance_id",
]

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
var _ship: HeroShip
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
var _relay_survey_persistence_store: RefCounted
var _relay_survey_persistence_slot: StringName = &""
var _planetary_reward_authority := Callable()
var _active_relay_reward_evidence: Dictionary = {}
var _relay_reward_authority_in_flight := false
var _relay_reward_authority_receipt: Dictionary = {}
var _relay_reward_commit_receipt: Dictionary = {}
var _last_relay_reward_commit_result: Dictionary = {}
var _relay_reward_authority_commit_count := 0
var _relay_reward_persistence_commit_count := 0
var _atmosphere_composition: Node
var _last_planetary_altitude_m := 0.0
var _relay_return_manifest: RefCounted
var _relay_return_travel: RefCounted
var _return_berth_adapter: RefCounted
var _return_persistence_adapter: RefCounted
var _return_persistence_store: RefCounted
var _return_persistence_slot: StringName = &""
var _return_persistence_replayed_generation := -1
var _return_persistence_replayed_digest := ""
var _return_persistence_retired_generation := -1
var _travel_audio_binding: RefCounted
var _entry_presentation_binding: RefCounted
var _last_entry_presentation_result: Dictionary = {}
var _fleet_landing_wash_binding: RefCounted
var _last_fleet_landing_wash_result: Dictionary = {}
var _fleet_entry_envelope_binding: RefCounted
var _last_fleet_entry_envelope_result: Dictionary = {}
var _staging_relay_proximity: Area3D
var _staging_relay_access_marker: Marker3D

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
var _planetary_orbit_return_consumed := false
var _retained_return_host_instance_id := 0
var _retained_return_host_generation := -1
var _retained_return_host_attachment_generation := -1
var _retained_return_session: Object
var _retained_return_session_instance_id := 0
var _retained_return_actor_instance_id := 0
var _retained_return_craft_instance_id := 0
var _station_return_handoff_intent: Dictionary = {}
var _station_return_handoff_delivered := false


func _enter_tree() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	set_process(false)
	set_physics_process(_configured)


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	set_process(false)
	set_physics_process(_configured)


func _exit_tree() -> void:
	_retire_staging_relay_proximity()
	if _travel_audio_binding != null:
		_travel_audio_binding.detach()
		_travel_audio_binding = null
	if _fleet_landing_wash_binding != null:
		_fleet_landing_wash_binding.call(&"detach")
		_fleet_landing_wash_binding = null
	_last_fleet_landing_wash_result = {}
	if _fleet_entry_envelope_binding != null:
		_fleet_entry_envelope_binding.call(&"detach")
		_fleet_entry_envelope_binding = null
	_last_fleet_entry_envelope_result = {}
	# A staged early envelope belongs to exactly one live tree epoch. Never replay
	# it after a whole composition detach/re-entry.
	_pending_envelope.clear()
	_pending_intent.clear()
	_active_relay_reward_evidence.clear()
	_relay_reward_authority_in_flight = false
	_clear_retained_return_context()
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
	_ship = resolved.ship as HeroShip
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
	# The host owns the retained session; audio observes its detached
	# presentation signal without advancing travel or claiming movement authority.
	var retained_session: Variant = _host.get_travel_session_observation_source()
	if retained_session is Object:
		bind_planetary_travel_audio(retained_session as Object)
	_attach_fleet_landing_wash_presentation()
	_attach_fleet_entry_envelope_presentation()
	_attach_entry_presentation()
	process_physics_priority = PHYSICS_PRIORITY
	set_physics_process(is_inside_tree())
	return _finish(true, &"configured")


## Composes presentation cues from the caller-owned travel session. This hook
## observes detached snapshots only and never advances or validates travel.
func bind_planetary_travel_audio(travel_session: Object) -> Dictionary:
	if _travel_audio_binding != null:
		return _reject(&"travel_audio_already_bound")
	var binding := PlanetaryTravelAudioBindingScript.new() as RefCounted
	var result: Dictionary = binding.attach(travel_session)
	if not bool(result.get("accepted", false)):
		return result
	_travel_audio_binding = binding
	return _result(true, &"travel_audio_bound")


func detach_planetary_travel_audio() -> Dictionary:
	if _travel_audio_binding == null:
		return _reject(&"travel_audio_unbound")
	var result: Dictionary = _travel_audio_binding.detach()
	_travel_audio_binding = null
	return result


func get_planetary_travel_audio_snapshot() -> Dictionary:
	return _travel_audio_binding.get_snapshot() if _travel_audio_binding != null else {"attached": false}


## Instantiates the retained planetary surface composition under this real
## Ember production owner. The composition remains caller-observation driven.
func configure_planetary_surface(
		director: ActivityDirector,
		reward_sink: Callable,
		atmosphere_composition: Node = null,
		service_repair_sink: Callable = Callable()
	) -> Dictionary:
	if not _configured or _composition_root == null:
		return _reject(&"production_binding_unavailable")
	if _planetary_composition != null:
		return _reject(&"planetary_composition_already_bound")
	if not reward_sink.is_valid():
		return _reject(&"reward_sink_unavailable")
	var host_snapshot := _host.get_snapshot() if _host != null else {}
	if _state not in [State.IDLE, State.RUNNING] \
			or not bool(host_snapshot.get("attached", false)) \
			or (_state == State.RUNNING \
				and int(host_snapshot.get("generation", -1)) != _generation) \
			or int(host_snapshot.get("attachment_generation", -1)) \
				!= _host.get_attachment_generation():
		return _reject(&"planetary_composition_lifecycle_unavailable")
	_planetary_composition = PlanetaryCompositionScript.new() as Node
	_planetary_composition.name = "EmberPlanetarySurfaceProductionBinding"
	_composition_root.add_child(_planetary_composition)
	_planetary_composition.connect(
		&"authored_hazard_presentation_changed",
		_on_authored_hazard_presentation_changed
	)
	_planetary_composition.connect(
		&"service_terminal_repair_feedback", _on_service_terminal_repair_feedback
	)
	_planetary_reward_authority = reward_sink
	var result: Dictionary = _planetary_composition.call(
		&"configure", _host, director,
		Callable(self, &"_commit_relay_reward_through_authority"),
		_host.get_generation(),
		service_repair_sink
	)
	if bool(result.get("accepted", false)) \
			and _relay_survey_persistence_store != null:
		var persistence_configured := _planetary_composition.call(
			&"configure_relay_survey_persistence",
			_relay_survey_persistence_store, _relay_survey_persistence_slot
		) as Dictionary
		if not bool(persistence_configured.get("accepted", false)):
			_planetary_reward_authority = Callable()
			_planetary_composition.queue_free()
			_planetary_composition = null
			return persistence_configured
	if not bool(result.get("accepted", false)):
		_planetary_reward_authority = Callable()
		_planetary_composition.queue_free()
		_planetary_composition = null
	else:
		var diagnostic_attached := _attach_staging_relay_proximity()
		if not bool(diagnostic_attached.get("accepted", false)):
			_planetary_reward_authority = Callable()
			_planetary_composition.queue_free()
			_planetary_composition = null
			return diagnostic_attached
		_relay_return_manifest = ReturnManifestScript.new()
		_relay_return_travel = ReturnTravelAdapterScript.new()
	_atmosphere_composition = atmosphere_composition
	if bool(result.get("accepted", false)) and atmosphere_composition != null:
		_configure_entry_atmosphere(atmosphere_composition)
	return result


func _on_service_terminal_repair_feedback(feedback: Dictionary) -> void:
	var forwarded := feedback.duplicate(true)
	forwarded["owner_generation"] = _generation
	service_terminal_repair_feedback.emit(forwarded)


func _attach_staging_relay_proximity(
		loaded_scene_override: Node3D = null
	) -> Dictionary:
	if is_instance_valid(_staging_relay_proximity):
		return {
			"accepted": false,
			"reason": &"staging_relay_proximity_already_attached",
		}
	var loaded_scene := loaded_scene_override
	if loaded_scene == null and is_instance_valid(_bootstrap):
		loaded_scene = _bootstrap.get_loaded_instance()
	if loaded_scene == null or not is_instance_valid(loaded_scene) \
			or loaded_scene.get_instance_id() != _loaded_scene_instance_id \
			or _host == null or not is_instance_valid(_host) \
			or _player == null or not is_instance_valid(_player) \
			or _composition_root == null \
			or not is_instance_valid(_composition_root):
		return {
			"accepted": false,
			"reason": &"staging_relay_proximity_source_unavailable",
		}
	var access_marker := loaded_scene.get_node_or_null(
		STAGING_RELAY_ACCESS_PATH
	) as Marker3D
	if access_marker == null:
		return {
			"accepted": false,
			"reason": &"staging_relay_access_marker_unavailable",
		}
	var diagnostic := StagingRelayProximityBindingScript.new() as Area3D
	diagnostic.name = "OwnedStagingRelayProximityDiagnostic"
	_composition_root.add_child(diagnostic)
	diagnostic.global_transform = access_marker.global_transform
	var configured := diagnostic.call(
		&"configure", _host, _player, _host.get_generation(), _generation,
		_loaded_scene_instance_id
	) as Dictionary
	if not bool(configured.get("accepted", false)):
		diagnostic.queue_free()
		return configured
	_staging_relay_proximity = diagnostic
	_staging_relay_access_marker = access_marker
	return {
		"accepted": true,
		"reason": &"staging_relay_proximity_attached",
		"diagnostic": diagnostic.call(&"get_snapshot"),
	}.duplicate(true)


func _retire_staging_relay_proximity() -> void:
	if is_instance_valid(_staging_relay_proximity):
		_staging_relay_proximity.queue_free()
	_staging_relay_proximity = null
	_staging_relay_access_marker = null


func _on_authored_hazard_presentation_changed(_snapshot: Dictionary) -> void:
	if _mutation_active or _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	state_changed.emit(get_snapshot())
	_signal_dispatch_active = false


func get_planetary_surface_snapshot() -> Dictionary:
	return _planetary_composition.call(&"get_snapshot") as Dictionary \
		if _planetary_composition != null else {}


func get_authored_hazard_presentation_snapshot() -> Dictionary:
	if _planetary_composition == null:
		return {}
	return _planetary_composition.call(
		&"get_authored_hazard_presentation_snapshot"
	) as Dictionary


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
	if _state != State.HANDOFF_PENDING or _completion_handback.is_empty():
		return _reject(&"planetary_orbit_return_not_pending")
	if _planetary_orbit_return_consumed:
		return _reject(&"planetary_orbit_return_already_consumed")
	if not handback is Dictionary or handback != _completion_handback:
		return _reject(&"planetary_orbit_return_handback_mismatch")
	var receipt := handback as Dictionary
	var receipt_rejection := _handback_receipt_rejection(
		receipt, int(receipt.retired_attachment_generation)
	)
	if not receipt_rejection.is_empty():
		return _reject(receipt_rejection)
	var staging_snapshot: Dictionary = {}
	var staging_detached := false
	if is_instance_valid(_staging_relay_proximity):
		staging_snapshot = _staging_relay_proximity.call(&"get_snapshot") \
			as Dictionary
		if bool(staging_snapshot.get("attached", false)):
			var diagnostic_detached := _staging_relay_proximity.call(&"detach") \
				as Dictionary
			if not bool(diagnostic_detached.get("accepted", false)):
				return diagnostic_detached
			staging_detached = true
	var result: Dictionary = _planetary_composition.call(
		&"consume_orbit_return_handback", receipt
	)
	if not bool(result.get("accepted", false)) and staging_detached:
		var diagnostic_rollback := _staging_relay_proximity.call(
			&"rollback_detach",
			int(staging_snapshot.get("host_generation", -1)),
			int(staging_snapshot.get("attachment_generation", -1)),
			int(staging_snapshot.get("production_generation", -1))
		) as Dictionary
		if not bool(diagnostic_rollback.get("accepted", false)):
			var rollback_failure := _reject(
				&"staging_relay_handback_rollback_failed"
			)
			rollback_failure["composition_result"] = result.duplicate(true)
			rollback_failure["diagnostic_rollback"] = (
				diagnostic_rollback.duplicate(true)
			)
			return rollback_failure
	if bool(result.get("accepted", false)):
		if _relay_return_travel != null:
			_relay_return_travel.call(&"detach")
		_planetary_orbit_return_consumed = true
	return result


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


func stage_interrupted_relay_survey_resume(
		route_identity: Variant, retirement_request: Variant
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"stage_interrupted_relay_survey_resume",
		route_identity,
		retirement_request
	)


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
	if not _relay_reward_commit_receipt.is_empty():
		return _reject(&"relay_reward_already_committed")
	# Production commits only from the already validated priority-2 actor
	# envelope. A public/manual call has no authority to manufacture that witness.
	return _reject(&"relay_reward_requires_late_actor_evidence")


func configure_relay_survey_persistence(
		store: RefCounted, slot_id: StringName = &"ember_relay_survey_completion"
	) -> Dictionary:
	if store == null or str(slot_id).strip_edges().is_empty() \
			or _relay_survey_persistence_store != null:
		return _reject(&"survey_persistence_configuration_invalid")
	_relay_survey_persistence_store = store
	_relay_survey_persistence_slot = slot_id
	if _planetary_composition != null:
		return _planetary_composition.call(
			&"configure_relay_survey_persistence", store, slot_id
		)
	return {
		"accepted": true,
		"reason": &"survey_persistence_configured",
		"slot_id": slot_id,
		"owns_save_authority": false,
	}.duplicate(true)


func restore_relay_survey_persistence() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(&"restore_relay_survey_persistence")


func save_interrupted_relay_survey_journey(
		session_contract: Object,
		route_snapshot: Variant,
		commit_id: String
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"save_interrupted_relay_survey_journey",
		session_contract,
		route_snapshot,
		commit_id
	) as Dictionary


func capture_interrupted_relay_survey_optional_progress() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"capture_interrupted_relay_survey_optional_progress"
	) as Dictionary


func load_interrupted_relay_survey_journey() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"load_interrupted_relay_survey_journey"
	) as Dictionary


func retire_interrupted_relay_survey_journey(
		expected_store_generation: int,
		expected_receipt_sha256: String,
		commit_id: String
	) -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	return _planetary_composition.call(
		&"retire_interrupted_relay_survey_journey",
		expected_store_generation,
		expected_receipt_sha256,
		commit_id
	) as Dictionary


## Emits a caller-routed return intent after the survey's fenced external reward
## commit is accepted and persisted. This binding never moves the actor, owns
## the reward authority/store, or selects a berth; the receipt only names the
## authored Mudds Shipyards destination.
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
	var manifest_reset: Dictionary = _relay_return_manifest.reset()
	if _relay_return_travel != null:
		_relay_return_travel.call(&"reset")
	_clear_retained_return_context()
	return manifest_reset


func get_planetary_relay_survey_return_manifest_snapshot() -> Dictionary:
	if _relay_return_manifest == null:
		return {}
	return _relay_return_manifest.get_snapshot()


func consume_planetary_relay_survey_return(
		manifest_result: Variant, actor_instance_id: int, craft_instance_id: int
	) -> Dictionary:
	if _relay_return_travel == null or _host == null:
		return _reject(&"planetary_composition_unavailable")
	return _relay_return_travel.call(
		&"consume", manifest_result, actor_instance_id, craft_instance_id,
		_host.get_attachment_generation()
	)


## Feeds the accepted caller intent into the retained host travel session by
## default. An explicit session remains available to compatibility callers,
## but production no longer requires GameFlow to reach into the Host's private
## session. The session still advances only from normal reboard, takeoff,
## ascent, and orbit-return evidence.
func admit_planetary_relay_survey_return(
		manifest_result: Variant,
		actor_instance_id: int,
		craft_instance_id: int,
		travel_session: Object = null
	) -> Dictionary:
	if _relay_return_travel == null or _host == null:
		return _reject(&"return_travel_session_unavailable")
	var retained := travel_session == null
	if retained and not _host.has_method(&"admit_return_travel_intent"):
		return _reject(&"return_travel_session_unavailable")
	if not retained and not travel_session.has_method(&"admit_return_travel_intent"):
		return _reject(&"return_travel_session_unavailable")
	var consumed: Dictionary = _relay_return_travel.call(
		&"consume", manifest_result, actor_instance_id, craft_instance_id,
		_host.get_attachment_generation()
	)
	if not bool(consumed.get("accepted", false)):
		return consumed
	var intent := consumed.get("intent", {}) as Dictionary
	var admitted: Dictionary
	if retained:
		admitted = _host.call(
			&"admit_return_travel_intent", intent, actor_instance_id,
			craft_instance_id, _host.get_generation(),
			_host.get_attachment_generation()
		)
	else:
		admitted = travel_session.call(
			&"admit_return_travel_intent", intent, actor_instance_id,
			craft_instance_id, _host.get_generation(),
			_host.get_attachment_generation()
		)
	if not bool(admitted.get("accepted", false)):
		_relay_return_travel.call(&"reset")
		return admitted
	if retained:
		_capture_retained_return_context(
			actor_instance_id, craft_instance_id,
			_host.get_travel_session_observation_source()
		)
	return {"accepted": true, "reason": &"return_travel_intent_admitted", "intent": intent}.duplicate(true)


func submit_planetary_return_reboard(
		travel_session: Object, actor_instance_id: int, craft_instance_id: int,
		player_reboarded: bool, ship_still_landed: bool
	) -> Dictionary:
	return _submit_authorized_return_sample(
		travel_session, &"submit_authorized_return_reboard", actor_instance_id,
		craft_instance_id, [player_reboarded, ship_still_landed]
	)


func submit_planetary_return_takeoff(
		travel_session: Object, actor_instance_id: int, craft_instance_id: int,
		takeoff_started: bool, ship_still_landed: bool
	) -> Dictionary:
	return _submit_authorized_return_sample(
		travel_session, &"submit_authorized_return_takeoff", actor_instance_id,
		craft_instance_id, [takeoff_started, ship_still_landed]
	)


func submit_planetary_return_ascent(
		travel_session: Object, actor_instance_id: int, craft_instance_id: int,
		surface_clear_confirmed: bool, orbital_coordinate: Dictionary,
		speed_meters_per_second: float, expected_coordinate_frame_generation: int
	) -> Dictionary:
	return _submit_authorized_return_sample(
		travel_session, &"submit_authorized_return_ascent", actor_instance_id,
		craft_instance_id, [surface_clear_confirmed, orbital_coordinate,
		 speed_meters_per_second, expected_coordinate_frame_generation]
	)


func submit_planetary_return_orbit(
		travel_session: Object, actor_instance_id: int, craft_instance_id: int,
		orbital_coordinate: Dictionary, speed_meters_per_second: float,
		expected_coordinate_frame_generation: int
	) -> Dictionary:
	return _submit_authorized_return_sample(
		travel_session, &"submit_authorized_return_orbit", actor_instance_id,
		craft_instance_id, [orbital_coordinate, speed_meters_per_second,
		 expected_coordinate_frame_generation]
	)


func prepare_planetary_return_approach(
		travel_session: Object, landing_return_contract: Object,
		actor_instance_id: int, craft_instance_id: int
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_travel_session_unavailable")
	if travel_session == null:
		if not _host.has_method(&"prepare_return_approach"):
			return _reject(&"return_travel_session_unavailable")
		return _host.call(
			&"prepare_return_approach", landing_return_contract,
			actor_instance_id, craft_instance_id, _host.get_generation(),
			_host.get_attachment_generation()
		)
	if not travel_session.has_method(&"prepare_return_approach"):
		return _reject(&"return_travel_session_unavailable")
	return travel_session.call(
		&"prepare_return_approach", landing_return_contract,
		actor_instance_id, craft_instance_id, _host.get_generation(),
		_host.get_attachment_generation()
	)


func admit_planetary_return_contract_approach(
		travel_session: Object, landing_return_contract: Object,
		actor_instance_id: int, craft_instance_id: int
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_travel_session_unavailable")
	if travel_session == null:
		if not _host.has_method(&"admit_return_contract_approach"):
			return _reject(&"return_travel_session_unavailable")
		return _host.call(
			&"admit_return_contract_approach", landing_return_contract,
			actor_instance_id, craft_instance_id, _host.get_generation(),
			_host.get_attachment_generation()
		)
	if not travel_session.has_method(&"admit_return_contract_approach"):
		return _reject(&"return_travel_session_unavailable")
	return travel_session.call(
		&"admit_return_contract_approach", landing_return_contract,
		actor_instance_id, craft_instance_id, _host.get_generation(),
		_host.get_attachment_generation()
	)


func confirm_planetary_return_arrival_ready(
		travel_session: Object, landing_return_contract: Object,
		actor_instance_id: int, craft_instance_id: int,
		observation: Dictionary
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_travel_session_unavailable")
	if travel_session == null:
		if not _host.has_method(&"confirm_return_arrival_ready"):
			return _reject(&"return_travel_session_unavailable")
		return _host.call(
			&"confirm_return_arrival_ready", landing_return_contract,
			actor_instance_id, craft_instance_id, observation,
			_host.get_generation(), _host.get_attachment_generation()
		)
	if not travel_session.has_method(&"confirm_return_arrival_ready"):
		return _reject(&"return_travel_session_unavailable")
	return travel_session.call(
		&"confirm_return_arrival_ready", landing_return_contract,
		actor_instance_id, craft_instance_id, observation,
		_host.get_generation(), _host.get_attachment_generation()
	)


func request_planetary_return_berth(
		arrival_receipt: Variant, berth: ShipBerth, ship: Node,
		definition: ShipDefinition, actor_instance_id: int, craft_instance_id: int
	) -> Dictionary:
	if _return_berth_adapter == null:
		_return_berth_adapter = ReturnBerthAdapterScript.new()
	return _return_berth_adapter.call(
		&"request", arrival_receipt, berth, ship, definition,
		actor_instance_id, craft_instance_id, _generation,
		_host.get_attachment_generation() if _host != null else 1
	)


func confirm_planetary_return_berth_occupied(landing_evidence: Variant) -> Dictionary:
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(&"confirm_occupied", landing_evidence)


func complete_planetary_return_contract(
		occupied_receipt: Variant, landing_return_contract: Object,
		observation: Dictionary
	) -> Dictionary:
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(
		&"complete_return_contract", occupied_receipt,
		landing_return_contract, observation
	)


func reset_planetary_return_berth() -> Dictionary:
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(&"reset")


func _current_planetary_return_surface_attachment_generation() -> int:
	var surface_snapshot := get_planetary_surface_snapshot()
	var surface_attachment := int(surface_snapshot.get("attachment_generation", 0))
	if surface_attachment > 0:
		return surface_attachment
	return _host.get_attachment_generation() if _host != null else 0


## Adopts GameFlow's existing home-berth lease after HeroShip has accepted the
## ordinary landing assist. The adapter receives only detached identities and
## cannot reserve, move, occupy, release, or reward the craft.
func adopt_physical_planetary_return_arrival(
		shell_handoff: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int,
		berth: ShipBerth,
		ship: Node,
		definition: ShipDefinition,
		existing_token: StringName,
		actor_instance_id: int,
		craft_instance_id: int
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_surface_host_unavailable")
	if _return_berth_adapter == null:
		_return_berth_adapter = ReturnBerthAdapterScript.new()
	return _return_berth_adapter.call(
		&"adopt_physical_arrival",
		shell_handoff,
		current_shell_generation,
		current_coordinate_frame_generation,
		_generation,
		_current_planetary_return_surface_attachment_generation(),
		berth,
		ship,
		definition,
		existing_token,
		actor_instance_id,
		craft_instance_id,
	)


func confirm_physical_planetary_return_arrival(
		landing_evidence: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_surface_host_unavailable")
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(
		&"confirm_physical_arrival",
		landing_evidence,
		current_shell_generation,
		current_coordinate_frame_generation,
		_generation,
		_current_planetary_return_surface_attachment_generation(),
	)


func complete_physical_planetary_return_arrival(
		occupied_receipt: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int
	) -> Dictionary:
	if _host == null:
		return _reject(&"return_surface_host_unavailable")
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(
		&"complete_physical_arrival",
		occupied_receipt,
		current_shell_generation,
		current_coordinate_frame_generation,
		_generation,
		_current_planetary_return_surface_attachment_generation(),
	)


func abort_physical_planetary_return_arrival(
		reason: StringName
	) -> Dictionary:
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(&"abort_physical_arrival", reason)


## Caller-owned UserDataStore bridge for the terminal Ember return. The exact
## completed evidence is committed in one namespaced transaction, while the
## restorable state remains detached and carries no berth or reward authority.
func configure_planetary_return_persistence(
		store: RefCounted, slot_id: StringName = &"ember_planetary_return"
	) -> Dictionary:
	if store == null or str(slot_id).strip_edges().is_empty() \
			or not store.has_method(&"load") or not store.has_method(&"commit") \
			or not store.has_method(&"get_snapshot") \
			or not store.has_method(&"get_generation"):
		return _reject(&"return_persistence_configuration_invalid")
	if _return_persistence_configured():
		return _reject(&"return_persistence_already_configured")
	_return_persistence_store = store
	_return_persistence_slot = slot_id
	_return_persistence_adapter = ReturnPersistenceAdapterScript.new()
	_return_persistence_replayed_generation = -1
	_return_persistence_replayed_digest = ""
	_return_persistence_retired_generation = -1
	return {
		"accepted": true,
		"reason": &"return_persistence_configured",
		"slot_id": slot_id,
		"owns_save_authority": false,
	}


func save_planetary_return_persistence(
		travel_session: Object, return_contract: Object, returned_receipt: Variant,
		expected_store_generation: int, commit_id: String
	) -> Dictionary:
	if not _return_persistence_configured():
		return _reject(&"return_persistence_unavailable")
	if expected_store_generation < 0 or commit_id.strip_edges().is_empty():
		return _reject(&"return_persistence_save_request_invalid")
	var captured: Dictionary = _return_persistence_adapter.call(
		&"capture", travel_session, return_contract, returned_receipt
	)
	if not bool(captured.get("accepted", false)):
		return captured
	if int(_return_persistence_store.call(&"get_generation")) != expected_store_generation:
		return _reject(&"return_persistence_stale_store_generation")
	var payload: Dictionary = _return_persistence_store.call(&"get_snapshot")
	var slot_key := String(_return_persistence_slot)
	if payload.has(slot_key):
		var existing_variant: Variant = payload.get(slot_key)
		if not existing_variant is Dictionary:
			return _reject(&"return_persistence_payload_corrupt")
		var existing := existing_variant as Dictionary
		if int(existing.get("schema_version", 0)) > RETURN_PERSISTENCE_SCHEMA_VERSION:
			return _reject(&"return_persistence_newer_schema")
		if not _return_persistence_record_valid(existing):
			return _reject(&"return_persistence_payload_corrupt")
		if StringName(existing.get("slot_id", &"")) != _return_persistence_slot:
			return _reject(&"return_persistence_wrong_slot")
		if int(existing.get("run_generation", 0)) \
				>= int(captured.get("run_generation", 0)):
			return _reject(&"return_persistence_stale_generation")
	var record := {
		"schema_version": RETURN_PERSISTENCE_SCHEMA_VERSION,
		"payload_kind": String(RETURN_PERSISTENCE_PAYLOAD_KIND),
		"slot_id": String(_return_persistence_slot),
		"binding_generation": _generation,
		"run_generation": int(captured.get("run_generation", 0)),
		"receipt_sha256": str(captured.get("receipt_sha256", "")),
		"session": captured.duplicate(true),
	}
	payload[slot_key] = record
	var result: Dictionary = _return_persistence_store.call(
		&"commit", payload, expected_store_generation, commit_id
	)
	result["binding_reason"] = &"saved" if bool(result.get("accepted", false)) else &"store_rejected"
	return result


func restore_planetary_return_persistence() -> Dictionary:
	if not _return_persistence_configured():
		return _reject(&"return_persistence_unavailable")
	var loaded: Dictionary = _return_persistence_store.call(&"load")
	if not bool(loaded.get("accepted", false)):
		return loaded
	var payload := loaded.get("payload", {}) as Dictionary
	var slot_key := String(_return_persistence_slot)
	if not payload.has(slot_key):
		for candidate_variant in payload.values():
			if candidate_variant is Dictionary \
					and StringName((candidate_variant as Dictionary).get("payload_kind", &"")) \
						== RETURN_PERSISTENCE_PAYLOAD_KIND:
				return _reject(&"return_persistence_wrong_slot")
		return _reject(
			&"return_persistence_retired"
			if _return_persistence_retired_generation >= 1
			else &"return_persistence_not_found"
		)
	var record_variant: Variant = payload.get(slot_key)
	if not record_variant is Dictionary:
		return _reject(&"return_persistence_payload_corrupt")
	var record := record_variant as Dictionary
	if int(record.get("schema_version", 0)) > RETURN_PERSISTENCE_SCHEMA_VERSION:
		return _reject(&"return_persistence_newer_schema")
	if not _return_persistence_record_valid(record):
		return _reject(&"return_persistence_payload_corrupt")
	if StringName(record.get("slot_id", &"")) != _return_persistence_slot:
		return _reject(&"return_persistence_wrong_slot")
	if _planetary_composition != null:
		var surface := _planetary_composition.call(&"get_snapshot") as Dictionary
		if bool(surface.get("attached", false)):
			return _reject(&"return_persistence_surface_attachment_active")
	if bool((record.get("session", {}) as Dictionary).get("reward_replay_allowed", true)):
		return _reject(&"return_persistence_reward_authority_present")
	var session := record.get("session", {}) as Dictionary
	if int(record.get("run_generation", 0)) != int(session.get("run_generation", -1)) \
			or str(record.get("receipt_sha256", "")) \
				!= str(session.get("receipt_sha256", "")):
		return _reject(&"return_persistence_payload_corrupt")
	var restored: Dictionary = _return_persistence_adapter.call(
		&"restore", session
	)
	if not bool(restored.get("accepted", false)):
		return restored
	_return_persistence_replayed_generation = int(restored.run_generation)
	_return_persistence_replayed_digest = str(restored.receipt_sha256)
	return {
		"accepted": true,
		"reason": &"return_persistence_loaded",
		"detached": true,
		"fresh_station": true,
		"requires_retirement": true,
		"store_generation": int(loaded.get("generation", -1)),
		"session": restored,
	}.duplicate(true)


## Removes the exact replayed slot through the same atomic UserDataStore
## transaction. A failed write leaves the published receipt available to a
## fresh binding after process re-entry; this binding may retry retirement.
func retire_planetary_return_persistence(
		expected_store_generation: int, commit_id: String
	) -> Dictionary:
	if not _return_persistence_configured():
		return _reject(&"return_persistence_unavailable")
	if _return_persistence_replayed_generation < 1 \
			or _return_persistence_replayed_digest.is_empty():
		return _reject(&"return_persistence_replay_required")
	if expected_store_generation < 0 or commit_id.strip_edges().is_empty():
		return _reject(&"return_persistence_retire_request_invalid")
	if int(_return_persistence_store.call(&"get_generation")) != expected_store_generation:
		return _reject(&"return_persistence_stale_store_generation")
	var payload: Dictionary = _return_persistence_store.call(&"get_snapshot")
	var slot_key := String(_return_persistence_slot)
	var record_variant: Variant = payload.get(slot_key)
	if not record_variant is Dictionary:
		return _reject(&"return_persistence_payload_corrupt")
	var record := record_variant as Dictionary
	if not _return_persistence_record_valid(record) \
			or int(record.get("run_generation", -1)) \
				!= _return_persistence_replayed_generation \
			or str(record.get("receipt_sha256", "")) \
				!= _return_persistence_replayed_digest:
		return _reject(&"return_persistence_retire_receipt_mismatch")
	payload.erase(slot_key)
	var result: Dictionary = _return_persistence_store.call(
		&"commit", payload, expected_store_generation, commit_id
	)
	result["binding_reason"] = (
		&"retired" if bool(result.get("accepted", false)) else &"store_rejected"
	)
	if not bool(result.get("accepted", false)):
		return result
	var retired: Dictionary = _return_persistence_adapter.call(
		&"retire", _return_persistence_replayed_generation
	)
	if not bool(retired.get("accepted", false)):
		return _reject(&"return_persistence_adapter_retire_rejected")
	_return_persistence_retired_generation = _return_persistence_replayed_generation
	result["run_generation"] = _return_persistence_retired_generation
	return result


func get_planetary_return_persistence_snapshot() -> Dictionary:
	return {
		"configured": _return_persistence_configured(),
		"slot_id": _return_persistence_slot,
		"detached": true,
		"fresh_station": true,
		"replayed_generation": _return_persistence_replayed_generation,
		"retired_generation": _return_persistence_retired_generation,
		"retirement_pending": _return_persistence_replayed_generation >= 1 \
				and _return_persistence_retired_generation \
					!= _return_persistence_replayed_generation,
		"adapter": _return_persistence_adapter.call(&"get_snapshot") if _return_persistence_adapter != null else {},
		"owns_save_authority": false,
		"owns_movement_authority": false,
		"owns_berth_authority": false,
		"owns_reward_authority": false,
	}.duplicate(true)


func _return_persistence_configured() -> bool:
	return is_instance_valid(_return_persistence_store) \
			and _return_persistence_adapter != null \
			and not _return_persistence_slot.is_empty()


func _return_persistence_record_valid(record: Dictionary) -> bool:
	if record.size() != RETURN_PERSISTENCE_RECORD_KEYS.size():
		return false
	for key in RETURN_PERSISTENCE_RECORD_KEYS:
		if not record.has(key):
			return false
	return _return_persistence_integral_number(record.get("schema_version")) \
			and int(record.get("schema_version", 0)) == RETURN_PERSISTENCE_SCHEMA_VERSION \
			and record.get("payload_kind") is String \
			and record.get("slot_id") is String \
			and StringName(record.get("payload_kind", &"")) \
				== RETURN_PERSISTENCE_PAYLOAD_KIND \
			and _return_persistence_integral_number(record.get("binding_generation")) \
			and int(record.get("binding_generation", -1)) >= 0 \
			and _return_persistence_integral_number(record.get("run_generation")) \
			and int(record.get("run_generation", 0)) >= 1 \
			and record.get("receipt_sha256") is String \
			and str(record.get("receipt_sha256", "")).length() == 64 \
			and record.get("session") is Dictionary


func _return_persistence_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value)


func retire_planetary_return(next_session_generation: int) -> Dictionary:
	if _return_berth_adapter == null:
		return _reject(&"return_berth_adapter_unavailable")
	return _return_berth_adapter.call(&"retire", next_session_generation)


func _submit_authorized_return_sample(
		travel_session: Object, method: StringName, actor_instance_id: int,
		craft_instance_id: int, sample_args: Array
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	if _host == null:
		return _reject(&"return_travel_session_unavailable")
	if travel_session == null:
		if actor_instance_id != _retained_return_actor_instance_id \
				or craft_instance_id != _retained_return_craft_instance_id:
			return _reject(&"return_travel_bound_actor_mismatch")
		var context_rejection := _retained_return_context_rejection()
		if not context_rejection.is_empty():
			return _abort_retained_return_drift(context_rejection)
		if not _host.has_method(&"submit_return_travel_evidence"):
			return _abort_retained_return_drift(&"return_host_drift")
		var evidence_result := _return_evidence_from_sample(method, sample_args)
		if not bool(evidence_result.get("accepted", false)):
			return evidence_result
		var committed: Dictionary = _host.call(
			&"submit_return_travel_evidence",
			evidence_result.kind as StringName,
			actor_instance_id, craft_instance_id,
			evidence_result.evidence as Dictionary,
			_host.get_generation(), _host.get_attachment_generation()
		)
		if not bool(committed.get("accepted", false)) \
				or method != &"submit_authorized_return_orbit":
			return committed
		var published := _publish_retained_station_return_handoff()
		if not bool(published.get("accepted", false)):
			return published
		committed["station_return_handoff_intent"] = (
			published.get("intent", {}) as Dictionary
		).duplicate(true)
		committed["station_return_handoff_published"] = true
		return committed
	if not travel_session.has_method(method):
		return _reject(&"return_travel_session_unavailable")
	var args: Array = [actor_instance_id, craft_instance_id]
	args.append_array(sample_args)
	args.append(_host.get_generation())
	args.append(_host.get_attachment_generation())
	return travel_session.callv(method, args)


func _return_evidence_from_sample(method: StringName, args: Array) -> Dictionary:
	match method:
		&"submit_authorized_return_reboard":
			if args.size() == 2:
				return {"accepted": true, "kind": &"reboard", "evidence": {
					"player_reboarded": args[0], "ship_still_landed": args[1],
				}}.duplicate(true)
		&"submit_authorized_return_takeoff":
			if args.size() == 2:
				return {"accepted": true, "kind": &"takeoff", "evidence": {
					"takeoff_started": args[0], "ship_still_landed": args[1],
				}}.duplicate(true)
		&"submit_authorized_return_ascent":
			if args.size() == 4:
				return {"accepted": true, "kind": &"ascent", "evidence": {
					"surface_clear_confirmed": args[0],
					"orbital_coordinate": args[1],
					"speed_meters_per_second": args[2],
					"coordinate_frame_generation": args[3],
				}}.duplicate(true)
		&"submit_authorized_return_orbit":
			if args.size() == 3:
				return {"accepted": true, "kind": &"orbit", "evidence": {
					"orbital_coordinate": args[0],
					"speed_meters_per_second": args[1],
					"coordinate_frame_generation": args[2],
				}}.duplicate(true)
	return _reject(&"invalid_return_travel_evidence")


## Delivers the already published detached station-route intent once. The
## receipt is not an arrival, movement, origin, landing, boarding, or reward
## capability; the next production owner must consume it explicitly.
func take_planetary_station_return_handoff_intent(
		expected_generation: int
	) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _reject(&"reentrant_call")
	if expected_generation != _generation:
		return _reject(&"stale_generation")
	if _station_return_handoff_intent.is_empty():
		return _reject(&"station_return_handoff_not_ready")
	if _station_return_handoff_delivered:
		return _reject(&"station_return_handoff_already_delivered")
	var context_rejection := _retained_return_context_rejection()
	if not context_rejection.is_empty():
		return _abort_retained_return_drift(context_rejection)
	_station_return_handoff_delivered = true
	return {
		"accepted": true,
		"reason": &"station_return_handoff_delivered",
		"intent": _station_return_handoff_intent.duplicate(true),
	}.duplicate(true)


func _capture_retained_return_context(
		actor_instance_id: int, craft_instance_id: int, session: Object
	) -> void:
	_retained_return_host_instance_id = _host.get_instance_id()
	_retained_return_host_generation = _host.get_generation()
	_retained_return_host_attachment_generation = _host.get_attachment_generation()
	_retained_return_session = session
	_retained_return_session_instance_id = (
		session.get_instance_id() if is_instance_valid(session) else 0
	)
	_retained_return_actor_instance_id = actor_instance_id
	_retained_return_craft_instance_id = craft_instance_id
	_station_return_handoff_intent = {}
	_station_return_handoff_delivered = false


func _clear_retained_return_context() -> void:
	_retained_return_host_instance_id = 0
	_retained_return_host_generation = -1
	_retained_return_host_attachment_generation = -1
	_retained_return_session = null
	_retained_return_session_instance_id = 0
	_retained_return_actor_instance_id = 0
	_retained_return_craft_instance_id = 0
	_station_return_handoff_intent = {}
	_station_return_handoff_delivered = false


func _retained_return_context_rejection() -> StringName:
	if _retained_return_host_instance_id == 0 \
			or _retained_return_session_instance_id == 0:
		return &"return_travel_intent_required"
	if not is_instance_valid(_host) \
			or _host.get_instance_id() != _retained_return_host_instance_id:
		return &"return_host_drift"
	if _host.get_generation() != _retained_return_host_generation \
			or _host.get_attachment_generation() \
				!= _retained_return_host_attachment_generation:
		return &"return_host_drift"
	var host_snapshot := _host.get_snapshot() as Dictionary
	var identities := host_snapshot.get("identities", {}) as Dictionary
	if int(identities.get("player_instance_id", 0)) \
			!= _retained_return_actor_instance_id \
			or int(identities.get("ship_instance_id", 0)) \
				!= _retained_return_craft_instance_id:
		return &"return_actor_drift"
	var session := _host.get_travel_session_observation_source() \
		if _host.has_method(&"get_travel_session_observation_source") else null
	if not is_instance_valid(session) \
			or session.get_instance_id() != _retained_return_session_instance_id:
		return &"return_host_drift"
	return &""


func _abort_retained_return_drift(reason: StringName) -> Dictionary:
	var session_abort: Dictionary = {}
	if is_instance_valid(_retained_return_session) \
			and _retained_return_session.has_method(&"abort"):
		var snapshot := _retained_return_session.call(
			&"get_presentation_snapshot"
		) as Dictionary
		if bool(snapshot.get("running", false)):
			session_abort = _retained_return_session.call(
				&"abort", reason,
				int(snapshot.get("generation", -1)),
				int(snapshot.get("attachment_generation", -1))
			) as Dictionary
	if _relay_return_travel != null:
		_relay_return_travel.call(&"abort", reason)
	_station_return_handoff_intent = {}
	_station_return_handoff_delivered = false
	var result := _reject(reason)
	result["return_session_abort"] = session_abort.duplicate(true)
	return result


func _publish_retained_station_return_handoff() -> Dictionary:
	var context_rejection := _retained_return_context_rejection()
	if not context_rejection.is_empty():
		return _abort_retained_return_drift(context_rejection)
	if not _station_return_handoff_intent.is_empty():
		return _reject(&"station_return_handoff_already_published")
	if not _host.has_method(&"publish_station_return_handoff_intent"):
		return _abort_retained_return_drift(&"return_host_drift")
	var published := _host.call(
		&"publish_station_return_handoff_intent",
		_retained_return_actor_instance_id,
		_retained_return_craft_instance_id,
		_host.get_generation(), _host.get_attachment_generation(),
		int((_retained_return_session.call(&"get_presentation_snapshot") as Dictionary).get(
			"coordinate_frame_generation", -1
		))
	) as Dictionary
	if not bool(published.get("accepted", false)):
		return published
	_station_return_handoff_intent = (
		published.get("intent", {}) as Dictionary
	).duplicate(true)
	_station_return_handoff_delivered = false
	_signal_dispatch_active = true
	station_return_handoff_ready.emit(_station_return_handoff_intent.duplicate(true))
	_signal_dispatch_active = false
	return {
		"accepted": true,
		"reason": &"station_return_handoff_published",
		"intent": _station_return_handoff_intent.duplicate(true),
	}.duplicate(true)


func abort_planetary_relay_survey_return(reason: StringName = &"caller_aborted") -> Dictionary:
	if _relay_return_travel == null:
		return _reject(&"planetary_composition_unavailable")
	return _relay_return_travel.call(&"abort", reason)


func get_planetary_relay_survey_return_snapshot() -> Dictionary:
	if _relay_return_travel == null:
		return {}
	return _relay_return_travel.get_snapshot()


func detach_planetary_surface() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	var result: Dictionary = _planetary_composition.call(&"detach")
	if bool(result.get("accepted", false)) \
			and is_instance_valid(_staging_relay_proximity):
		var diagnostic_detached := _staging_relay_proximity.call(&"detach") \
			as Dictionary
		if not bool(diagnostic_detached.get("accepted", false)):
			return diagnostic_detached
	if bool(result.get("accepted", false)) and _relay_return_travel != null:
		_relay_return_travel.call(&"detach")
	if bool(result.get("accepted", false)) and _terminal_station_return_completed():
		_retire_completed_journey_for_repeat()
	return result


func _terminal_station_return_completed() -> bool:
	if _return_berth_adapter == null:
		return false
	var snapshot := _return_berth_adapter.call(&"get_snapshot") as Dictionary
	return bool(snapshot.get("physical_arrival_completed", false)) \
		and bool(snapshot.get("contract_completed", false))


## The station lifecycle has consumed the terminal receipt, so the old
## scheduler/location identities must not block the next streamed Ember visit.
## This releases only Ember-owned compositions and evidence; the occupied Mudds
## berth and all GameFlow/ship authority remain untouched.
func _retire_completed_journey_for_repeat() -> void:
	_retire_staging_relay_proximity()
	if is_instance_valid(_planetary_composition):
		_planetary_composition.queue_free()
	_planetary_composition = null
	_relay_return_manifest = null
	_relay_return_travel = null
	_return_berth_adapter = null
	_clear_retained_return_context()
	_station_return_handoff_intent.clear()
	_station_return_handoff_delivered = false
	_active_relay_reward_evidence.clear()
	_relay_reward_authority_in_flight = false
	_relay_reward_authority_receipt.clear()
	_relay_reward_commit_receipt.clear()
	_last_relay_reward_commit_result.clear()
	_planetary_reward_authority = Callable()
	_atmosphere_composition = null
	if _travel_audio_binding != null:
		_travel_audio_binding.detach()
		_travel_audio_binding = null
	if _fleet_landing_wash_binding != null:
		_fleet_landing_wash_binding.call(&"detach")
		_fleet_landing_wash_binding = null
	if _fleet_entry_envelope_binding != null:
		_fleet_entry_envelope_binding.call(&"detach")
		_fleet_entry_envelope_binding = null
	if _entry_presentation_binding != null:
		_entry_presentation_binding.call(&"detach")
	_entry_presentation_binding = null
	_last_entry_presentation_result.clear()
	_last_fleet_landing_wash_result.clear()
	_last_fleet_entry_envelope_result.clear()
	_pending_envelope.clear()
	_pending_intent.clear()
	_last_prepared_evidence.clear()
	_last_late_result.clear()
	_completion_handback.clear()
	_completion_handback_delivered = false
	_planetary_orbit_return_consumed = false
	_last_caller_serial = 0
	_last_prepared_physics_frame = -1
	_last_consumed_caller_serial = 0
	_last_consumed_physics_frame = -1
	_last_intent_serial = 0
	_prepared_count = 0
	_late_consume_count = 0
	_intent_consume_count = 0
	_start_count = 0
	_advance_count = 0
	_origin_adoption_count = 0
	_handback_count = 0
	_state = State.IDLE
	_configured = false
	_configuration_error = &""
	_generation += 1
	set_physics_process(false)


func reenter_planetary_surface() -> Dictionary:
	if _planetary_composition == null:
		return _reject(&"planetary_composition_unavailable")
	var result: Dictionary = _planetary_composition.call(&"reenter")
	if not bool(result.get("accepted", false)):
		return result
	var diagnostic_reentered := false
	if is_instance_valid(_staging_relay_proximity):
		var relay_result := _staging_relay_proximity.call(
			&"reenter", _host.get_attachment_generation()
		) as Dictionary
		if not bool(relay_result.get("accepted", false)):
			var composition_rollback := _planetary_composition.call(&"detach") \
				as Dictionary
			if not bool(composition_rollback.get("accepted", false)):
				return _reject(&"planetary_surface_reentry_rollback_failed")
			return relay_result
		diagnostic_reentered = true
	if bool(result.get("accepted", false)) and _relay_return_travel != null:
		var travel_result: Dictionary = _relay_return_travel.call(
			&"reenter", _host.get_attachment_generation()
		)
		if not bool(travel_result.get("accepted", false)):
			var composition_rollback := _planetary_composition.call(&"detach") \
				as Dictionary
			var diagnostic_rollback := {"accepted": true}
			if diagnostic_reentered:
				diagnostic_rollback = _staging_relay_proximity.call(&"detach") \
					as Dictionary
			if not bool(composition_rollback.get("accepted", false)) \
					or not bool(diagnostic_rollback.get("accepted", false)):
				return _reject(&"planetary_surface_reentry_rollback_failed")
			return travel_result
	return result


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

	# Authored surface geometry is body-local. Freeze its position in the same
	# generation as the admitted world sample; actors move between early and late.
	# The live bootstrap transform also accounts for a translated composition root.
	var body_local_position := _bootstrap.to_local(sample.position as Vector3)
	if not body_local_position.is_finite():
		return _finish(false, &"invalid_body_local_position")
	_pending_envelope = {
		"position_body_local_m": body_local_position,
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


## Explicit caller-sample facade for production owners that already hold the
## live actor/craft observation. It delegates to the existing early envelope;
## the binding's priority-2 callback remains the only advancement owner.
func advance_from_caller_sample(
		caller_serial: int, delta: float, actor_kind: StringName,
		actor_instance_id: int, craft_instance_id: int, position: Vector3,
		velocity_mps: Vector3, landed: bool, reboarded: bool, takeoff: bool,
		origin_result: Variant, coordinate_frame_generation: int,
		location_generation: int, expected_generation: int,
		orbit_return_ready: bool = false, occupied_receipt: Variant = {},
		landing_return_contract: Object = null, return_observation: Dictionary = {},
		return_travel_session: Object = null
	) -> Dictionary:
	if actor_kind not in [&"ship", &"player"] \
			or actor_instance_id < 1 or craft_instance_id < 1 \
			or not position.is_finite() or not velocity_mps.is_finite():
		return _reject(&"caller_sample_identity_invalid")
	if actor_kind == &"ship" and actor_instance_id != _ship_instance_id:
		return _reject(&"caller_sample_actor_mismatch")
	if craft_instance_id != _ship_instance_id:
		return _reject(&"caller_sample_craft_mismatch")
	if not is_finite(delta) or delta < 0.0 \
			or delta > EmberSurfaceLoopHost.MAX_CALLER_DELTA_SECONDS:
		return _reject(&"invalid_delta")
	var sample := {
		"actor_kind": actor_kind,
		"actor_instance_id": actor_instance_id,
		"available": true,
		"position": position,
	}
	var prepared := prepare_early_tick(
		caller_serial, delta, sample, origin_result,
		coordinate_frame_generation, location_generation, expected_generation
	)
	if not bool(prepared.get("accepted", false)):
		return prepared
	_pending_envelope["caller_kinematics"] = {
		"craft_instance_id": craft_instance_id,
		"velocity_mps": velocity_mps,
		"landed": landed,
		"reboarded": reboarded,
		"takeoff": takeoff,
	}.duplicate(true)
	_last_prepared_evidence = _pending_envelope.duplicate(true)
	var transition := {"accepted": true, "reason": &"no_transition"}
	var host_phase := get_host_phase()
	if host_phase in [
		EmberSurfaceLoopHost.Phase.ORBIT_APPROACH,
		EmberSurfaceLoopHost.Phase.DESCENT,
		EmberSurfaceLoopHost.Phase.SURFACE_APPROACH,
		EmberSurfaceLoopHost.Phase.LANDING_APPROACH,
	]:
		# The retained planetary compositions author local +Y as surface-up.
		# This is a display observation only; no velocity is written back.
		_present_entry_observation(
			velocity_mps.length(),
			velocity_mps.y,
			host_phase == EmberSurfaceLoopHost.Phase.LANDING_APPROACH,
		)
	if reboarded:
		if host_phase != EmberSurfaceLoopHost.Phase.ON_FOOT:
			return _reject(&"caller_reboard_phase_mismatch")
		transition = queue_reboard_intent(_last_intent_serial + 1, expected_generation)
	elif takeoff:
		if host_phase != EmberSurfaceLoopHost.Phase.REBOARDED:
			return _reject(&"caller_takeoff_phase_mismatch")
		transition = queue_takeoff_intent(_last_intent_serial + 1, expected_generation)
	if not bool(transition.get("accepted", false)):
		return transition
	if orbit_return_ready:
		if get_host_phase() not in [EmberSurfaceLoopHost.Phase.ORBIT_RETURN, EmberSurfaceLoopHost.Phase.COMPLETED]:
			return _reject(&"caller_return_phase_mismatch")
		if _return_berth_adapter == null or landing_return_contract == null:
			return _reject(&"caller_return_contract_unavailable")
		var completed := complete_planetary_return_contract(
			occupied_receipt, landing_return_contract, return_observation
		)
		if not bool(completed.get("accepted", false)):
			return completed
		if return_travel_session != null and _return_persistence_configured():
			var saved := save_planetary_return_persistence(
				return_travel_session, landing_return_contract, completed,
				_return_persistence_store.get_generation(),
				"ember-return-%d" % _generation
			)
			if not bool(saved.get("accepted", false)):
				return {"accepted": false, "reason": &"return_persistence_commit_rejected", "store": saved}
		transition = completed
	return {"accepted": true, "reason": &"caller_sample_advanced", "transition": transition, "envelope": _pending_envelope.duplicate(true)}


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


func get_host_phase() -> int:
	return _host.get_phase() if _host != null else -1


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
		"planetary_orbit_return_consumed": _planetary_orbit_return_consumed,
		"station_return_handoff_pending": (
			not _station_return_handoff_intent.is_empty()
			and not _station_return_handoff_delivered
		),
		"station_return_handoff_delivered": _station_return_handoff_delivered,
		"station_return_handoff_intent": (
			_station_return_handoff_intent.duplicate(true)
		),
		"retained_return_context": {
			"host_instance_id": _retained_return_host_instance_id,
			"host_generation": _retained_return_host_generation,
			"host_attachment_generation": (
				_retained_return_host_attachment_generation
			),
			"session_instance_id": _retained_return_session_instance_id,
			"actor_instance_id": _retained_return_actor_instance_id,
			"craft_instance_id": _retained_return_craft_instance_id,
		}.duplicate(true),
		"relay_reward_commit": {
			"authority_commit_count": _relay_reward_authority_commit_count,
			"persistence_commit_count": _relay_reward_persistence_commit_count,
			"authority_in_flight": _relay_reward_authority_in_flight,
			"authority_receipt": _relay_reward_authority_receipt.duplicate(true),
			"commit_receipt": _relay_reward_commit_receipt.duplicate(true),
			"last_result": _last_relay_reward_commit_result.duplicate(true),
			"automatic_late_commit": true,
			"owns_reward_authority": false,
			"owns_reward_store": false,
		}.duplicate(true),
		"planetary_surface": get_planetary_surface_snapshot(),
		"entry_presentation": _entry_presentation_binding.get_snapshot() \
			if _entry_presentation_binding != null else {"attached": false},
		"last_entry_presentation_result": _last_entry_presentation_result.duplicate(true),
		"fleet_landing_wash_presentation": (
			_fleet_landing_wash_binding.call(&"get_snapshot")
			if _fleet_landing_wash_binding != null else {
				"attached": false,
				"delegated_to_arrow_entry": _ship is ArrowReconShip,
			}
		),
		"last_fleet_landing_wash_result": (
			_last_fleet_landing_wash_result.duplicate(true)
		),
		"fleet_entry_envelope_presentation": (
			_fleet_entry_envelope_binding.call(&"get_snapshot")
			if _fleet_entry_envelope_binding != null else {
				"attached": false,
				"delegated_to_arrow_entry": _ship is ArrowReconShip,
			}
		),
		"last_fleet_entry_envelope_result": (
			_last_fleet_entry_envelope_result.duplicate(true)
		),
	}.duplicate(true)


## Attaches one shared non-Arrow wash to the accepted HeroShip visual root.
## Arrow keeps its existing entry-owned presenter, so no craft receives two.
func _attach_fleet_landing_wash_presentation() -> Dictionary:
	if _ship is ArrowReconShip:
		return {
			"accepted": true,
			"reason": &"delegated_to_arrow_entry",
		}
	if _fleet_landing_wash_binding != null:
		return {"accepted": true, "reason": &"landing_wash_retained"}
	if _ship == null or _composition_root == null:
		return {"accepted": false, "reason": &"landing_wash_unavailable"}
	var hud := _composition_root.get_node_or_null(^"HUD") as GameHUD
	if hud == null:
		return {"accepted": false, "reason": &"entry_hud_unavailable"}
	var binding := HeroAirlessLandingWashBindingScript.new() as RefCounted
	var result := binding.call(&"attach", _ship, hud) as Dictionary
	if bool(result.get("accepted", false)):
		_fleet_landing_wash_binding = binding
	return result


## Attaches one shared non-Arrow atmospheric envelope to the accepted HeroShip
## silhouette. Arrow keeps its existing entry-owned presenter, so no craft
## receives two compression envelopes.
func _attach_fleet_entry_envelope_presentation() -> Dictionary:
	if _ship is ArrowReconShip:
		return {
			"accepted": true,
			"reason": &"delegated_to_arrow_entry",
		}
	if _fleet_entry_envelope_binding != null:
		return {"accepted": true, "reason": &"entry_envelope_retained"}
	if _ship == null or _composition_root == null:
		return {"accepted": false, "reason": &"entry_envelope_unavailable"}
	var hud := _composition_root.get_node_or_null(^"HUD") as GameHUD
	if hud == null:
		return {"accepted": false, "reason": &"entry_hud_unavailable"}
	var binding := HeroAtmosphericEntryEnvelopeBindingScript.new() as RefCounted
	var result := binding.call(&"attach", _ship, hud) as Dictionary
	if bool(result.get("accepted", false)):
		_fleet_entry_envelope_binding = binding
	return result


func _configure_fleet_entry_envelope_atmosphere(
		atmosphere_composition: Node
	) -> Dictionary:
	var attached := _attach_fleet_entry_envelope_presentation()
	if not bool(attached.get("accepted", false)):
		return attached
	var profile: PlanetaryAtmosphereProfile = atmosphere_composition.get(
		"atmosphere_profile"
	) as PlanetaryAtmosphereProfile
	if profile == null:
		return {
			"accepted": false,
			"reason": &"entry_atmosphere_profile_unavailable",
		}
	return _fleet_entry_envelope_binding.call(
		&"configure_atmosphere", profile
	) as Dictionary


## Resolves the retained gameplay HUD beside this production owner. Failure is
## presentation-local: travel, physics, landing, and damage continue unchanged.
func _attach_entry_presentation() -> Dictionary:
	if _entry_presentation_binding != null:
		return {"accepted": true, "reason": &"entry_presentation_retained"}
	if not _ship is ArrowReconShip or _composition_root == null:
		return {"accepted": false, "reason": &"entry_presentation_unavailable"}
	var hud := _composition_root.get_node_or_null(^"HUD") as GameHUD
	if hud == null:
		return {"accepted": false, "reason": &"entry_hud_unavailable"}
	var binding := ArrowEntryPresentationBindingScript.new() as RefCounted
	var result: Dictionary = binding.call(&"attach", _ship as ArrowReconShip, hud)
	if bool(result.get("accepted", false)):
		_entry_presentation_binding = binding
	return result


func _configure_entry_atmosphere(atmosphere_composition: Node) -> Dictionary:
	var attached := _attach_entry_presentation()
	if not bool(attached.get("accepted", false)):
		return attached
	var profile: PlanetaryAtmosphereProfile = atmosphere_composition.get(
		"atmosphere_profile"
	) as PlanetaryAtmosphereProfile
	if profile == null:
		return {"accepted": false, "reason": &"entry_atmosphere_profile_unavailable"}
	return _entry_presentation_binding.call(&"configure_atmosphere", profile)


func _present_entry_observation(
		speed_mps: float, vertical_speed_mps: float, landing_supported: bool
	) -> void:
	var fleet_envelope_attached := _attach_fleet_entry_envelope_presentation()
	if bool(fleet_envelope_attached.get("accepted", false)) \
			and _fleet_entry_envelope_binding != null:
		if _atmosphere_composition != null:
			var envelope_snapshot := _fleet_entry_envelope_binding.call(
				&"get_snapshot"
			) as Dictionary
			if StringName(envelope_snapshot.get("profile_id", &"")) == &"":
				var configured := _configure_fleet_entry_envelope_atmosphere(
					_atmosphere_composition
				)
				if not bool(configured.get("accepted", false)):
					_last_fleet_entry_envelope_result = configured.duplicate(true)
				else:
					_last_fleet_entry_envelope_result = \
						_fleet_entry_envelope_binding.call(
							&"present_observation", _last_planetary_altitude_m,
							speed_mps, true
						) as Dictionary
			else:
				_last_fleet_entry_envelope_result = \
					_fleet_entry_envelope_binding.call(
						&"present_observation", _last_planetary_altitude_m,
						speed_mps, true
					) as Dictionary
		else:
			_last_fleet_entry_envelope_result = \
				_fleet_entry_envelope_binding.call(
					&"present_observation", _last_planetary_altitude_m,
					speed_mps, false
				) as Dictionary
	else:
		_last_fleet_entry_envelope_result = \
			fleet_envelope_attached.duplicate(true)
	var wash_attached := _attach_fleet_landing_wash_presentation()
	if bool(wash_attached.get("accepted", false)) \
			and _fleet_landing_wash_binding != null:
		_last_fleet_landing_wash_result = _fleet_landing_wash_binding.call(
			&"present_observation", _last_planetary_altitude_m,
			vertical_speed_mps, _atmosphere_composition == null,
			landing_supported
		) as Dictionary
	else:
		_last_fleet_landing_wash_result = wash_attached.duplicate(true)
	var attached := _attach_entry_presentation()
	if not bool(attached.get("accepted", false)):
		_last_entry_presentation_result = attached.duplicate(true)
		return
	if _atmosphere_composition != null:
		var snapshot: Dictionary = _entry_presentation_binding.call(&"get_snapshot")
		if snapshot.get("branch_id", &"airless") != &"atmospheric":
			var configured := _configure_entry_atmosphere(_atmosphere_composition)
			if not bool(configured.get("accepted", false)):
				_last_entry_presentation_result = configured.duplicate(true)
				return
	_last_entry_presentation_result = _entry_presentation_binding.call(
		&"present_observation", _last_planetary_altitude_m, speed_mps,
		vertical_speed_mps, landing_supported
	) as Dictionary


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
			"fenced_external_relay_reward_commit": true,
		}.duplicate(true),
		"common_authority": _false_roster(COMMON_AUTHORITY_KEYS),
		"adjacent_authority": _false_roster(ADJACENT_AUTHORITY_KEYS),
	}.duplicate(true)


func _physics_process(_engine_delta: float) -> void:
	if is_instance_valid(_staging_relay_proximity):
		if is_instance_valid(_staging_relay_access_marker):
			_staging_relay_proximity.global_transform = \
				_staging_relay_access_marker.global_transform
			_staging_relay_proximity.call(&"refresh_authoritative_state")
		elif bool(
			(_staging_relay_proximity.call(&"get_snapshot") as Dictionary).get(
				"attached", false
			)
		):
			_staging_relay_proximity.call(&"detach")
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
	_forward_authored_hazard_observation(envelope)

	var phase := _host.get_phase()
	var operation: Dictionary
	if _state == State.START_PENDING:
		if phase != EmberSurfaceLoopHost.Phase.IDLE:
			_fail_late(&"host_start_phase_drift")
			return
		if _planetary_composition != null:
			var adoption_ready := _planetary_composition.call(
				&"preflight_started_host_generation",
				int(envelope.get("host_generation", -1)),
				int(envelope.get("host_attachment_generation", -1)),
			) as Dictionary
			if not bool(adoption_ready.get("accepted", false)):
				_rollback_planetary_surface_start_configuration()
				_reject_late_start(
					adoption_ready.get(
						"reason", &"planetary_surface_host_start_preflight_rejected"
					) as StringName
				)
				return
		operation = _host.start(
			_host.get_generation(),
			_host.get_attachment_generation(),
			_frame.get_generation(),
		)
		if not bool(operation.get("accepted", false)):
			_fail_late(operation.get("reason", &"host_start_rejected") as StringName)
			return
		if _planetary_composition != null:
			var adopted := _planetary_composition.call(
				&"adopt_started_host_generation",
				int(envelope.get("host_generation", -1)),
				int(envelope.get("host_attachment_generation", -1)),
			) as Dictionary
			if not bool(adopted.get("accepted", false)):
				var adoption_reason := adopted.get(
					"reason", &"planetary_surface_host_start_adoption_rejected"
				) as StringName
				var rolled_back := _host.rollback_uncommitted_start(
					_host.get_generation(), _host.get_attachment_generation(),
					adoption_reason
				)
				_rollback_planetary_surface_start_configuration()
				if bool(rolled_back.get("accepted", false)):
					_generation = _host.get_generation()
					_reject_late_start(adoption_reason, rolled_back)
				else:
					# An unexpected reentrant mutation may invalidate the narrow
					# rollback window. Detach terminalizes the Host rather than
					# leaving an unobserved running travel session behind.
					_host.detach(
						_host.get_generation(), _host.get_attachment_generation()
					)
					_fail_late(&"planetary_surface_host_start_rollback_rejected")
				return
		_generation = _host.get_generation()
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
	# The real Host commits retained return evidence internally. Publish its
	# generation-fenced route intent at the first ORBIT_RETURN boundary, leaving
	# one caller tick for GameFlow to take it before the next late tick atomically
	# retires Host ownership.
	if _host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_RETURN \
			and _retained_return_session_instance_id != 0 \
			and _station_return_handoff_intent.is_empty():
		var published := _publish_retained_station_return_handoff()
		if not bool(published.get("accepted", false)):
			_fail_late(
				published.get(
					"reason", &"station_return_handoff_publication_rejected"
				) as StringName
			)
			return
	if _host.get_phase() == EmberSurfaceLoopHost.Phase.COMPLETED:
		_complete_handback_late()
		return
	_finish_late_signal(&"host_advanced")


func _forward_active_relay_position(envelope: Dictionary) -> StringName:
	if _planetary_composition == null:
		return &""
	var surface_snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var activity: Dictionary = surface_snapshot.get("adapter", {}).get("activity_reward", {}) as Dictionary
	if StringName(activity.get("activity_id", &"")) != &"ember_beacon_survey":
		return &""
	var activity_state := StringName(activity.get("state", &""))
	if activity_state not in [&"active", &"awaiting_reward"]:
		return &""
	if activity_state == &"awaiting_reward":
		return _commit_pending_relay_reward(envelope, activity)
	var position: Variant = envelope.get("position_body_local_m", Vector3.INF)
	if not position is Vector3 or not (position as Vector3).is_finite():
		return &"invalid_relay_position_sample"
	var forwarded: Dictionary = _planetary_composition.call(
		&"submit_relay_survey_position", position
	)
	if not bool(forwarded.get("accepted", false)):
		# A valid observation between checkpoints keeps the route active.
		if StringName(forwarded.get("reason", &"")) == &"outside_checkpoint":
			return &""
		return &"relay_position_forward_rejected"
	var updated: Dictionary = _planetary_composition.call(&"get_snapshot")
	var updated_activity := (
		updated.get("adapter", {}).get("activity_reward", {}) as Dictionary
	)
	if StringName(updated_activity.get("state", &"")) == &"awaiting_reward":
		return _commit_pending_relay_reward(envelope, updated_activity)
	return &""


## Reuses the exact already-admitted player observation for the authored Relay
## Arc. The hazard runtime may emit damage/recovery requests, but this scheduler
## neither consumes those requests nor changes Host movement/lifecycle state.
func _forward_authored_hazard_observation(envelope: Dictionary) -> void:
	if _planetary_composition == null \
			or _host.get_phase() != EmberSurfaceLoopHost.Phase.ON_FOOT:
		return
	var sample := envelope.get("actor_sample", {}) as Dictionary
	if StringName(sample.get("actor_kind", &"")) != &"player" \
			or int(sample.get("actor_instance_id", 0)) != _player_instance_id:
		return
	_planetary_composition.call(
		&"submit_authored_hazard_observation",
		{
			"actor_instance_id": int(sample.get("actor_instance_id", 0)),
			"delta_seconds": float(envelope.get("delta", 0.0)),
			"exposure_unitless": 1.0,
			"position_body_local_m": envelope.get("position_body_local_m", Vector3.INF),
			"surface_phase_id": &"on_foot",
		}.duplicate(true),
		_host.get_generation(), _host.get_attachment_generation()
	)


func _commit_pending_relay_reward(
		envelope: Dictionary, activity: Dictionary
	) -> StringName:
	if not _relay_reward_commit_receipt.is_empty():
		return &"relay_reward_replayed"
	if _relay_survey_persistence_store == null \
			or _relay_survey_persistence_slot.is_empty():
		return &"relay_reward_persistence_unavailable"
	var evidence := _build_relay_reward_evidence(envelope, activity)
	var evidence_rejection := _relay_reward_evidence_rejection(evidence, activity)
	if not evidence_rejection.is_empty():
		return evidence_rejection
	_active_relay_reward_evidence = evidence.duplicate(true)
	var committed := _planetary_composition.call(
		&"commit_relay_survey_reward"
	) as Dictionary
	_active_relay_reward_evidence.clear()
	_last_relay_reward_commit_result = committed.duplicate(true)
	if not bool(committed.get("accepted", false)):
		return committed.get("reason", &"relay_reward_commit_rejected") as StringName
	if _relay_reward_authority_receipt.is_empty():
		return &"relay_reward_authority_receipt_missing"
	var persistence := committed.get("persistence", {}) as Dictionary
	if not bool(persistence.get("accepted", false)):
		return &"relay_reward_persistence_commit_rejected"
	_relay_reward_persistence_commit_count += 1
	_relay_reward_commit_receipt = {
		"commit_id": _relay_reward_authority_receipt.get("commit_id", ""),
		"owner_generation": _generation,
		"host_generation": _host.get_generation(),
		"host_attachment_generation": _host.get_attachment_generation(),
		"activity_generation": int(activity.get("activity_generation", -1)),
		"actor_instance_id": int(evidence.get("actor_instance_id", 0)),
		"session_instance_id": int(evidence.get("session_instance_id", 0)),
		"authority": _relay_reward_authority_receipt.duplicate(true),
		"persistence": persistence.duplicate(true),
	}.duplicate(true)
	_last_relay_reward_commit_result["production_commit"] = (
		_relay_reward_commit_receipt.duplicate(true)
	)
	return &""


func _build_relay_reward_evidence(
		envelope: Dictionary, activity: Dictionary
	) -> Dictionary:
	var sample := envelope.get("actor_sample", {}) as Dictionary
	var pending := activity.get("pending_reward", {}) as Dictionary
	var session: Object = _host.get_travel_session_observation_source() \
		if _host != null else null
	return {
		"owner_generation": _generation,
		"host_instance_id": _host_instance_id,
		"host_generation": int(envelope.get("host_generation", -1)),
		"host_attachment_generation": int(
			envelope.get("host_attachment_generation", -1)
		),
		"session_instance_id": session.get_instance_id() \
			if is_instance_valid(session) else 0,
		"actor_kind": sample.get("actor_kind", &""),
		"actor_instance_id": int(sample.get("actor_instance_id", 0)),
		"craft_instance_id": _ship_instance_id,
		"caller_serial": int(envelope.get("caller_serial", 0)),
		"physics_frame": int(envelope.get("physics_frame", -1)),
		"activity_generation": int(activity.get("activity_generation", -1)),
		"completion_attachment_generation": int(
			pending.get("attachment_generation", -1)
		),
	}.duplicate(true)


func _relay_reward_evidence_rejection(
		evidence: Variant, activity: Dictionary
	) -> StringName:
	if not _configured or _state != State.RUNNING \
			or _planetary_composition == null \
			or not _planetary_reward_authority.is_valid():
		return &"relay_reward_production_unavailable"
	if not evidence is Dictionary \
			or not _exact_keys(evidence as Dictionary, RELAY_REWARD_EVIDENCE_KEYS):
		return &"relay_reward_evidence_schema_mismatch"
	var witness := evidence as Dictionary
	for key in [
		"activity_generation", "actor_instance_id", "caller_serial",
		"completion_attachment_generation", "craft_instance_id",
		"host_attachment_generation", "host_generation", "host_instance_id",
		"owner_generation", "physics_frame", "session_instance_id",
	]:
		if not witness.get(key) is int:
			return &"relay_reward_evidence_type_mismatch"
	if not witness.get("actor_kind") is StringName:
		return &"relay_reward_evidence_type_mismatch"
	if int(witness.owner_generation) != _generation \
			or int(witness.host_instance_id) != _host_instance_id \
			or int(witness.host_generation) != _host.get_generation() \
			or int(witness.host_attachment_generation) \
				!= _host.get_attachment_generation() \
			or int(witness.caller_serial) != _last_consumed_caller_serial \
			or int(witness.physics_frame) != _last_consumed_physics_frame \
			or int(witness.physics_frame) != int(Engine.get_physics_frames()):
		return &"stale_relay_reward_evidence"
	var host_snapshot := _host.get_snapshot() as Dictionary
	var identities := host_snapshot.get("identities", {}) as Dictionary
	var session: Object = _host.get_travel_session_observation_source()
	if not bool(host_snapshot.get("attached", false)) \
			or StringName(host_snapshot.get("phase_id", &"")) != &"on_foot" \
			or StringName(witness.actor_kind) != &"player" \
			or int(witness.actor_instance_id) != _player_instance_id \
			or int(witness.actor_instance_id) \
				!= int(identities.get("player_instance_id", 0)) \
			or int(witness.craft_instance_id) != _ship_instance_id \
			or int(witness.craft_instance_id) \
				!= int(identities.get("ship_instance_id", 0)) \
			or not is_instance_valid(session) \
			or int(witness.session_instance_id) != session.get_instance_id():
		return &"forged_relay_reward_actor_session_evidence"
	var pending := activity.get("pending_reward", {}) as Dictionary
	if StringName(activity.get("state", &"")) != &"awaiting_reward" \
			or StringName(activity.get("completed_activity_id", &"")) \
				!= &"ember_beacon_survey" \
			or int(witness.activity_generation) \
				!= int(activity.get("activity_generation", -1)) \
			or int(witness.completion_attachment_generation) \
				!= int(pending.get("attachment_generation", -1)) \
			or int(witness.completion_attachment_generation) < 1 \
			or int(witness.completion_attachment_generation) \
				> int(witness.host_attachment_generation):
		return &"stale_relay_reward_completion_evidence"
	return &""


func _commit_relay_reward_through_authority(intent: Variant) -> Dictionary:
	if _relay_reward_authority_in_flight:
		return {"accepted": false, "reason": &"relay_reward_commit_reentrant"}
	if not _relay_reward_authority_receipt.is_empty():
		return {"accepted": false, "reason": &"relay_reward_already_committed"}
	if not intent is Dictionary \
			or not _exact_keys(intent as Dictionary, RELAY_REWARD_INTENT_KEYS):
		return {"accepted": false, "reason": &"relay_reward_intent_schema_mismatch"}
	if _active_relay_reward_evidence.is_empty():
		return {"accepted": false, "reason": &"relay_reward_evidence_unavailable"}
	var surface_snapshot: Dictionary = _planetary_composition.call(&"get_snapshot")
	var activity := (
		surface_snapshot.get("adapter", {}).get("activity_reward", {}) as Dictionary
	)
	var pending := activity.get("pending_reward", {}) as Dictionary
	if pending != intent:
		return {"accepted": false, "reason": &"relay_reward_intent_mismatch"}
	var evidence_rejection := _relay_reward_evidence_rejection(
		_active_relay_reward_evidence, activity
	)
	if not evidence_rejection.is_empty():
		return {"accepted": false, "reason": evidence_rejection}
	var request := (intent as Dictionary).duplicate(true)
	var commit_id := "ember-relay-survey:%d:%d" % [
		int(request.get("run_generation", -1)),
		int(request.get("activity_generation", -1)),
	]
	request["production_commit_id"] = commit_id
	request["production_evidence"] = _active_relay_reward_evidence.duplicate(true)
	_relay_reward_authority_in_flight = true
	var authority_result: Variant = _planetary_reward_authority.call(
		request.duplicate(true)
	) if _planetary_reward_authority.is_valid() else null
	_relay_reward_authority_in_flight = false
	if not authority_result is Dictionary \
			or not bool((authority_result as Dictionary).get("accepted", false)):
		return {
			"accepted": false,
			"reason": (authority_result as Dictionary).get(
				"reason", &"relay_reward_authority_rejected"
			) as StringName if authority_result is Dictionary \
				else &"relay_reward_authority_rejected",
		}.duplicate(true)
	if not _detached_value_safe(authority_result):
		return {"accepted": false, "reason": &"relay_reward_authority_result_unsafe"}
	_relay_reward_authority_commit_count += 1
	_relay_reward_authority_receipt = {
		"accepted": true,
		"reason": &"relay_reward_authority_committed",
		"commit_id": commit_id,
		"evidence": _active_relay_reward_evidence.duplicate(true),
		"authority_result": (authority_result as Dictionary).duplicate(true),
	}.duplicate(true)
	return _relay_reward_authority_receipt.duplicate(true)


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
			or not ship is HeroShip or not player is PlayerController:
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


func _reject_late_start(reason: StringName, rollback: Dictionary = {}) -> void:
	_state = State.IDLE
	_last_late_result = {
		"accepted": false,
		"reason": reason,
		"rolled_back": true,
		"rollback": rollback.duplicate(true),
	}.duplicate(true)
	_finish_late_signal(reason)


func _rollback_planetary_surface_start_configuration() -> void:
	_retire_staging_relay_proximity()
	if is_instance_valid(_planetary_composition):
		var snapshot := _planetary_composition.call(&"get_snapshot") as Dictionary
		if int(snapshot.get("state", -1)) \
				== EmberPlanetarySurfaceProductionBinding.State.BOUND:
			_planetary_composition.call(&"detach")
		_planetary_composition.queue_free()
	_planetary_composition = null
	if _relay_return_travel != null:
		_relay_return_travel.call(&"detach")
	_relay_return_manifest = null
	_relay_return_travel = null
	_planetary_reward_authority = Callable()
	_atmosphere_composition = null


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
