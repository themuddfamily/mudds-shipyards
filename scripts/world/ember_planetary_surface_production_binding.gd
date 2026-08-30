class_name EmberPlanetarySurfaceProductionBinding
extends Node

signal service_terminal_repair_feedback(feedback: Dictionary)
signal authored_hazard_presentation_changed(snapshot: Dictionary)

## Retained Ember composition for the caller-owned planetary surface systems.
## The Ember host still owns lifecycle and actors; this node only keeps one
## generation-fenced set of planetary runtimes and forwards observations.

const AdapterScript := preload("res://scripts/world/planetary_surface_activity_reward_adapter.gd")
const ActivityRuntimeScript := preload("res://scripts/world/planetary_activity_reward_runtime.gd")
const NavigationScript := preload("res://scripts/world/planetary_surface_navigation_runtime.gd")
const NavigationContractScript := preload("res://scripts/world/planetary_surface_navigation_contract.gd")
const HazardScript := preload("res://scripts/world/planetary_surface_hazard_runtime.gd")
const HazardContentScript := preload("res://scripts/world/planetary_surface_hazard_content_contract.gd")
const HazardZonePresentationScript := preload("res://scripts/world/ember_surface_hazard_zone_presentation.gd")
const WeatherScript := preload("res://scripts/world/planetary_weather_field.gd")
const WeatherProfile := preload("res://assets/world/planets/aurora_temperate_atmosphere.tres")
const WaterPresentationScript := preload("res://scripts/world/planetary_water_presentation.gd")
const WaterScript := preload("res://scripts/world/planetary_water_contact_runtime.gd")
const WaterContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")
const LandmarkScript := preload("res://scripts/world/planetary_activity_landmark_runtime.gd")
const LandmarkContractScript := preload("res://scripts/world/planetary_activity_landmark_cluster_contract.gd")
const LandmarkBeaconScript := preload("res://scripts/world/planetary_surface_landmark_beacon_presentation.gd")
const LandingApproachScript := preload("res://scripts/world/planetary_landing_approach_presentation.gd")
const OrbitalRingScript := preload("res://scripts/world/planetary_orbital_approach_ring_presentation.gd")
const RouteTrailScript := preload("res://scripts/world/planetary_surface_route_trail_presentation.gd")
const RelaySurveyScript := preload("res://scripts/world/ember_surface_relay_survey_activity.gd")
const ActivityDefinitionScript := preload("res://scripts/activities/activity_definition.gd")
const LocationDefinitionScript := preload("res://scripts/world/definitions/world_location_definition.gd")
const RelaySurveyPresentationScript := preload("res://scripts/world/ember_surface_relay_survey_presentation.gd")
const SurveyInteractionScript := preload("res://scripts/world/ember_survey_bunker_interaction_binding.gd")
const SampleRackInteractionScript := preload(
	"res://scripts/world/ember_sample_rack_interaction_binding.gd"
)
const EmberAuthoredSceneScript := preload("res://scripts/world/ember_moon_authored_scene.gd")
const RelaySurveyPersistenceScript := preload(
	"res://scripts/persistence/ember_relay_survey_persistence_binding.gd"
)
const SettlementScript := preload("res://scripts/world/planetary_settlement_interaction_runtime.gd")
const SettlementContractScript := preload("res://scripts/world/planetary_settlement_structure_contract.gd")
const SettlementPracticalScript := preload("res://scripts/world/planetary_settlement_practical_presentation.gd")
const SurfaceAudioBindingScene := preload("res://scenes/audio/planetary_surface_audio_playback_binding.tscn")
const SurfaceAudioAdapterScript := preload("res://scripts/audio/planetary_surface_audio_environment_adapter.gd")
const SurfaceAudioPolicyScript := preload("res://scripts/world/planetary_surface_audio_policy.gd")
const SurfaceAudioCatalog := preload("res://assets/audio/planetary/temperate_surface_audio_catalog.tres")

const AUTHORED_HAZARD_ID: StringName = &"ember_relay_arc"
const AUTHORED_HAZARD_RECOVERY_LANDMARK_ID: StringName = &"ember_staging_relay"
const AUTHORED_HAZARD_MARKER_ID: StringName = &"surface_staging_gate"
const AUTHORED_HAZARD_RUNTIME_ROUTE_ID: StringName = &"pad_to_surface_staging"
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

enum State { IDLE, BOUND, DETACHED }

var _state := State.IDLE
var _host: Object
var _host_generation := -1
var _attachment_generation := -1
var _composition_generation := 0
var _adapter: RefCounted
var _navigation: RefCounted
var _hazard: RefCounted
var _hazard_content: Resource
var _authored_hazard: Dictionary = {}
var _authored_recovery_landmark: Dictionary = {}
var _hazard_zone_presentation: Node
var _hazard_semantic_status: Dictionary = {}
var _hazard_presentation_revision := 0
var _weather: RefCounted
var _solar_phase: Dictionary = {}
var _weather_observation: Dictionary = {}
var _water_presentation: Node
var _water: RefCounted
var _landmarks: RefCounted
var _landmark_beacons: Dictionary = {}
var _landing_markers: Dictionary = {}
var _orbital_ring: Node
var _route_trail: Node
var _last_surface_navigation_feedback: Dictionary = {}
var _relay_survey: RefCounted
var _relay_survey_presentation: Node
var _relay_survey_persistence: RefCounted
var _restored_relay_survey_completion: Dictionary = {}
var _survey_interaction: Area3D
var _sample_rack_interaction: Area3D
var _settlement: RefCounted
var _settlement_practicals: Dictionary = {}
var _surface_audio_binding: Node
var _surface_audio_adapter: Node
var _surface_audio_policy: RefCounted
var _surface_audio_generation := 0
var _surface_audio_altitude_m := 0.0
var _surface_audio_exposure := 0.0


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_water_presentation = WaterPresentationScript.new() as Node
	_water_presentation.name = "OwnedPlanetaryWaterPresentation"
	add_child(_water_presentation)
	_water_presentation.call(&"configure")
	_surface_audio_binding = SurfaceAudioBindingScene.instantiate()
	_surface_audio_binding.name = "OwnedPlanetarySurfaceAudioBinding"
	add_child(_surface_audio_binding)
	_surface_audio_adapter = SurfaceAudioAdapterScript.new() as Node
	_surface_audio_adapter.name = "OwnedPlanetarySurfaceAudioAdapter"
	add_child(_surface_audio_adapter)
	_surface_audio_binding.call(&"configure", SurfaceAudioCatalog)
	_surface_audio_adapter.call(&"configure", _surface_audio_binding)


func configure(
		host: Object,
		director: ActivityDirector,
		reward_sink: Callable,
		expected_generation: int = 0,
		service_repair_sink: Callable = Callable()
	) -> Dictionary:
	if _state != State.IDLE or host == null or not is_instance_valid(host):
		return _result(false, &"composition_unavailable")
	if not host.has_method(&"get_generation") or not host.has_method(&"get_attachment_generation"):
		return _result(false, &"host_generation_api_incomplete")
	var generation := int(host.call(&"get_generation"))
	if generation != expected_generation and expected_generation != 0:
		return _result(false, &"stale_host_generation")
	_host = host
	_host_generation = generation
	_attachment_generation = int(host.call(&"get_attachment_generation"))
	_hazard_content = HazardContentScript.new()
	if not _hazard_content.call(&"is_definition_valid"):
		return _result(false, &"hazard_content_configuration_rejected")
	var hazard_composition := _compose_authored_hazard_navigation_contract(
		_hazard_content.call(&"get_snapshot") as Dictionary
	)
	if not bool(hazard_composition.get("accepted", false)):
		return _result(false, hazard_composition.get("reason", &"hazard_content_unavailable") as StringName)
	var navigation_contract := hazard_composition.get("contract") as PlanetarySurfaceNavigationContract
	_authored_hazard = (hazard_composition.get("hazard", {}) as Dictionary).duplicate(true)
	_authored_recovery_landmark = (
		hazard_composition.get("recovery_landmark", {}) as Dictionary
	).duplicate(true)
	_navigation = NavigationScript.new()
	var configured: Dictionary = _navigation.call(&"configure", navigation_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"navigation_configuration_rejected")
	_hazard = HazardScript.new()
	configured = _hazard.call(&"configure", navigation_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"hazard_configuration_rejected")
	_weather = WeatherScript.new()
	configured = _weather.call(&"configure", WeatherProfile)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"weather_configuration_rejected")
	configured = _hazard.call(&"bind_weather_field", _weather)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"weather_binding_rejected")
	_hazard_zone_presentation = HazardZonePresentationScript.new() as Node
	_hazard_zone_presentation.name = "OwnedEmberRelayArcHazardZone"
	add_child(_hazard_zone_presentation)
	configured = _hazard_zone_presentation.call(
		&"configure", _authored_hazard, PlanetarySurfaceHazardRuntime.HAZARD_RADIUS_M
	)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"hazard_zone_presentation_rejected")
	configured = _hazard_zone_presentation.call(
		&"configure_recovery_target", hazard_composition.get("recovery_landmark", {})
	)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"hazard_recovery_cue_rejected")
	_set_hazard_semantic_clear(&"hazard_zone_ready")
	_surface_audio_policy = SurfaceAudioPolicyScript.new()
	configured = _surface_audio_policy.call(&"configure", WeatherProfile)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"surface_audio_policy_rejected")
	_water = WaterScript.new()
	configured = _water.call(&"configure", WaterContractScript.new())
	if not bool(configured.get("accepted", false)):
		return _result(false, &"water_configuration_rejected")
	_landmarks = LandmarkScript.new()
	var landmark_contract := LandmarkContractScript.new()
	configured = _landmarks.call(&"configure", landmark_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"landmark_configuration_rejected")
	_configure_landmark_beacons(landmark_contract.get_snapshot())
	_settlement = SettlementScript.new()
	var settlement_contract := SettlementContractScript.new()
	configured = _settlement.call(&"configure", settlement_contract)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"settlement_configuration_rejected")
	_configure_settlement_practicals(settlement_contract.get_snapshot())
	_configure_landing_markers(settlement_contract.get_snapshot())
	_route_trail = RouteTrailScript.new() as Node
	_route_trail.name = "OwnedSurfaceRouteTrail"
	add_child(_route_trail)
	var route_points: Array = []
	for landmark in landmark_contract.get_snapshot().get("landmarks", []) as Array:
		route_points.append((landmark as Dictionary).get("position_body_local_m", Vector3.ZERO))
	_route_trail.call(&"configure", route_points)
	_relay_survey = RelaySurveyScript.new()
	_register_relay_survey_activity(director)
	_relay_survey_presentation = RelaySurveyPresentationScript.new() as Node
	_relay_survey_presentation.name = "OwnedRelaySurveyPresentation"
	add_child(_relay_survey_presentation)
	_bind_relay_survey_pad_guides(host)
	_orbital_ring = OrbitalRingScript.new() as Node
	_orbital_ring.name = "OwnedOrbitalApproachRing"
	add_child(_orbital_ring)
	_orbital_ring.call(&"configure", Vector3(0.0, 140000.0, 0.0))
	_adapter = AdapterScript.new()
	var runtime := ActivityRuntimeScript.new()
	var bound: Dictionary = _adapter.call(&"bind", host, runtime, director, reward_sink)
	if not bool(bound.get("accepted", false)):
		return _result(false, bound.get("reason", &"activity_binding_rejected") as StringName)
	for binding in [
		_adapter.call(&"bind_surface_hazard", _hazard),
		_adapter.call(&"bind_surface_water", _water),
		_adapter.call(&"bind_activity_landmarks", _landmarks),
		_adapter.call(&"bind_settlement", _settlement),
	]:
		if not bool(binding.get("accepted", false)):
			return _result(false, binding.get("reason", &"runtime_binding_rejected") as StringName)
	_survey_interaction = SurveyInteractionScript.new() as Area3D
	_survey_interaction.name = "OwnedSurveyBunkerInteraction"
	add_child(_survey_interaction)
	_survey_interaction.connect(&"survey_completed", _on_survey_interaction_completed)
	_survey_interaction.connect(
		&"service_repair_feedback", _on_service_terminal_repair_feedback
	)
	configured = _survey_interaction.call(
		&"configure", host, EmberAuthoredSceneScript.get_survey_interaction_definition()
	)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"survey_interaction_configuration_rejected")
	if service_repair_sink.is_valid():
		configured = _survey_interaction.call(
			&"configure_service_repair_sink", service_repair_sink
		)
		if not bool(configured.get("accepted", false)):
			return _result(false, &"service_repair_sink_configuration_rejected")
	_sample_rack_interaction = SampleRackInteractionScript.new() as Area3D
	_sample_rack_interaction.name = "OwnedSampleRackInteraction"
	add_child(_sample_rack_interaction)
	configured = _sample_rack_interaction.call(
		&"configure", host,
		EmberAuthoredSceneScript.get_sample_rack_interaction_definition(),
		Callable(self, "_sample_rack_activity_is_current"),
		Callable(self, "_submit_sample_rack_optional_checkpoint")
	)
	if not bool(configured.get("accepted", false)):
		return _result(false, &"sample_rack_configuration_rejected")
	var audio_attach: Dictionary = _surface_audio_adapter.call(
		&"attach", _surface_audio_policy.get_snapshot().get("profile_id", &""),
		maxi(1, absi(host.get_instance_id())), 1, 1,
		_surface_audio_binding.call(&"get_attachment_generation")
	)
	if not bool(audio_attach.get("accepted", false)):
		return _result(false, &"surface_audio_attach_rejected")
	_composition_generation += 1
	_state = State.BOUND
	_apply_relay_survey_presentation()
	_publish_authored_hazard_presentation()
	return _result(true, &"composition_bound")


func start_surface_activity_sequence(activity_ids: Array[StringName]) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	var result := _adapter.call(
		&"start_surface_activity_sequence", activity_ids, _navigation
	) as Dictionary
	_refresh_sample_rack_presentation()
	return result


## Main prepares this composition while the retained Host is IDLE, before
## cruise hands off final approach. The late scheduler checks this fence before
## starting the Host so a detached or stale composition cannot strand a live
## travel session while the later adoption rejects.
func preflight_started_host_generation(
		expected_previous_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _state != State.BOUND or _host == null or not is_instance_valid(_host):
		return _result(false, &"host_start_adoption_unavailable")
	if expected_previous_generation >= MAX_SAFE_GENERATION:
		return _result(false, &"host_start_adoption_generation_exhausted")
	var current_generation := int(_host.call(&"get_generation"))
	var current_attachment := int(_host.call(&"get_attachment_generation"))
	if _host_generation != expected_previous_generation \
			or current_generation != expected_previous_generation \
			or current_attachment != expected_attachment_generation:
		return _result(false, &"host_start_adoption_generation_mismatch")
	return _result(true, &"host_start_adoption_ready")


## Host.start() advances the run generation exactly once; the scheduler
## forwards that committed fact before admitting surface activity or
## observation. This is the commit half of the preflight above.
func adopt_started_host_generation(
		expected_previous_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if _state != State.BOUND or _host == null or not is_instance_valid(_host):
		return _result(false, &"host_start_adoption_unavailable")
	var current_generation := int(_host.call(&"get_generation"))
	var current_attachment := int(_host.call(&"get_attachment_generation"))
	if _host_generation != expected_previous_generation \
			or current_generation != expected_previous_generation + 1 \
			or current_attachment != expected_attachment_generation:
		return _result(false, &"host_start_adoption_generation_mismatch")
	_host_generation = current_generation
	return _result(true, &"host_start_generation_adopted")


func start_relay_survey() -> Dictionary:
	if not _live(): return _result(false, &"composition_detached")
	var result: Dictionary = _relay_survey.begin(_adapter, _navigation)
	if bool(result.get("accepted", false)):
		_restored_relay_survey_completion.clear()
		var runtime := (
			_adapter.get_snapshot().get("activity_reward", {}) as Dictionary
		)
		var next_generation := int(runtime.get("activity_generation", -1))
		var service := _survey_interaction.call(&"get_snapshot") as Dictionary
		var terminal := service.get("service_terminal", {}) as Dictionary
		if int(terminal.get("terminal_generation", -1)) > 0:
			_survey_interaction.call(&"reset_service_terminal", next_generation)
		var rack_activation := _sample_rack_interaction.call(
			&"activate_for_activity_generation", next_generation
		) as Dictionary
		if not bool(rack_activation.get("accepted", false)):
			return _result(false, &"sample_rack_activation_rejected")
	_apply_relay_survey_presentation()
	return result


func _on_service_terminal_repair_feedback(feedback: Dictionary) -> void:
	var forwarded := feedback.duplicate(true)
	forwarded["composition_generation"] = _composition_generation
	service_terminal_repair_feedback.emit(forwarded)

func submit_relay_survey_landmark(landmark_id: StringName, position: Vector3) -> Dictionary:
	if not _live(): return _result(false, &"composition_detached")
	var result: Dictionary = _relay_survey.submit_landmark(
		_adapter, landmark_id, position
	)
	_refresh_sample_rack_presentation()
	return result

func submit_relay_survey_position(position: Vector3) -> Dictionary:
	if not _live(): return _result(false, &"composition_detached")
	var result: Dictionary = _relay_survey.submit_position(_adapter, position)
	_apply_relay_survey_presentation()
	_refresh_sample_rack_presentation()
	return result

func commit_relay_survey_reward() -> Dictionary:
	if not _live(): return _result(false, &"composition_detached")
	var result: Dictionary = _relay_survey.commit_reward(_adapter)
	_apply_relay_survey_presentation()
	_refresh_sample_rack_presentation()
	if bool(result.get("accepted", false)) and _relay_survey_persistence != null:
		var next_store_generation := int(
			_relay_survey_persistence.call(&"get_store_generation")
		) + 1
		result["persistence"] = _relay_survey_persistence.call(
			&"save", get_snapshot(),
			"ember-relay-survey-%010d" % next_store_generation
		)
	return result


func configure_relay_survey_persistence(
		store: RefCounted, slot_id: StringName = &"ember_relay_survey_completion"
	) -> Dictionary:
	if _relay_survey_persistence != null:
		return _result(false, &"survey_persistence_already_configured")
	var persistence := RelaySurveyPersistenceScript.new() as RefCounted
	var configured := persistence.call(&"configure", store, slot_id) as Dictionary
	if not bool(configured.get("accepted", false)):
		return configured
	_relay_survey_persistence = persistence
	return configured


func restore_relay_survey_persistence() -> Dictionary:
	if not _live() or _relay_survey_persistence == null:
		return _result(false, &"survey_persistence_unavailable")
	if not _restored_relay_survey_completion.is_empty():
		return _result(false, &"survey_persistence_already_restored")
	var loaded := _relay_survey_persistence.call(&"load") as Dictionary
	if not bool(loaded.get("accepted", false)):
		return loaded
	var runtime := _adapter.get_snapshot().get("activity_reward", {}) as Dictionary
	if StringName(runtime.get("state", &"")) != &"ready":
		return _result(false, &"survey_persistence_live_activity_present")
	var completion := (
		loaded.get("completion", {}) as Dictionary
	).duplicate(true)
	var optional := completion.get("optional_checkpoint", {}) as Dictionary
	if bool(optional.get("completed", false)):
		var bunker_restored := _survey_interaction.call(
			&"restore_terminal_completion_presentation", optional
		) as Dictionary
		if not bool(bunker_restored.get("accepted", false)):
			return _result(false, &"survey_bunker_presentation_restore_rejected")
	_restored_relay_survey_completion = completion
	_apply_relay_survey_presentation()
	return {
		"accepted": true,
		"reason": &"survey_completion_restored",
		"store_generation": int(loaded.get("store_generation", -1)),
		"reward_replay_allowed": false,
		"completion": _restored_relay_survey_completion.duplicate(true),
	}.duplicate(true)


## Forwards a caller-built detached save contract through the already-bound
## Ember persistence slot. This composition does not create the checkpoint,
## detach an actor, or acquire route/reward authority.
func save_interrupted_relay_survey_journey(
		session_contract: Object,
		route_snapshot: Variant,
		commit_id: String
	) -> Dictionary:
	if not _live() or _relay_survey_persistence == null:
		return _result(false, &"survey_persistence_unavailable")
	return _relay_survey_persistence.call(
		&"save_interrupted_journey", session_contract, route_snapshot, commit_id
	) as Dictionary


func load_interrupted_relay_survey_journey() -> Dictionary:
	if not _live() or _relay_survey_persistence == null:
		return _result(false, &"survey_persistence_unavailable")
	return _relay_survey_persistence.call(&"load_interrupted_journey") as Dictionary


func retire_interrupted_relay_survey_journey(
		expected_store_generation: int,
		expected_receipt_sha256: String,
		commit_id: String
	) -> Dictionary:
	if not _live() or _relay_survey_persistence == null:
		return _result(false, &"survey_persistence_unavailable")
	return _relay_survey_persistence.call(
		&"retire_interrupted_journey",
		expected_store_generation,
		expected_receipt_sha256,
		commit_id
	) as Dictionary

func abort_relay_survey(reason: StringName = &"caller_evidence_lost") -> Dictionary:
	if not _live(): return _result(false, &"composition_detached")
	var result := _adapter.call(&"abort_activity", reason) as Dictionary
	_refresh_sample_rack_presentation()
	return result


func discover_settlements(position: Variant, radius_m: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"discover_settlements", position, radius_m)


func enter_settlement(structure_id: StringName, position: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _adapter.call(&"submit_settlement_entry", structure_id, position, _attachment_generation)


func submit_hazard_exposure(hazard_id: StringName, position: Variant, exposure: float, delta_seconds: float) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	var result := _adapter.call(
		&"submit_surface_hazard_exposure",
		hazard_id, position, exposure, delta_seconds
	) as Dictionary
	_refresh_sample_rack_presentation()
	return result


## Consumes one exact caller-owned on-foot observation for the authored Relay
## Arc zone. Returned damage/recovery requests and semantic HUD copy are
## detached; this binding never applies them or advances another lifecycle.
func submit_authored_hazard_observation(
		observation: Variant,
		expected_host_generation: int,
		expected_attachment_generation: int
	) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	if expected_host_generation != _host_generation:
		return _result(false, &"stale_host_generation")
	if expected_attachment_generation != _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	var validation := _validate_authored_hazard_observation(observation)
	if not bool(validation.get("accepted", false)):
		return _result(false, validation.get("reason", &"invalid_hazard_observation") as StringName)
	var evidence := observation as Dictionary
	var actor_position := evidence.get("position_body_local_m") as Vector3
	# The same generation-fenced on-foot observation already admitted for the
	# authored hazard supplies the presentation-only route cue. No input is
	# sampled and neither the hazard nor the cue can advance the route.
	_present_surface_navigation_feedback(
		actor_position, expected_host_generation, expected_attachment_generation
	)
	var center := _authored_hazard.get("position_body_local_m", Vector3.INF) as Vector3
	var inside := actor_position.distance_to(center) \
		<= PlanetarySurfaceHazardRuntime.HAZARD_RADIUS_M
	if not inside:
		_clear_authored_hazard_runtime_exposure()
		_set_hazard_semantic_clear(&"hazard_zone_exited")
		_publish_authored_hazard_presentation()
		return _hazard_observation_result(
			true, &"hazard_zone_clear", {}, actor_position
		)
	var sampled: Dictionary = _hazard.call(
		&"submit_exposure", AUTHORED_HAZARD_ID, actor_position,
		float(evidence.exposure_unitless), float(evidence.delta_seconds)
	)
	if not bool(sampled.get("accepted", false)):
		return _result(
			false, sampled.get("reason", &"hazard_observation_rejected") as StringName
		)
	_set_hazard_semantic_from_sample(sampled)
	_publish_authored_hazard_presentation()
	return _hazard_observation_result(
		true,
		&"hazard_recovery_requested" if bool(
			(sampled.get("recovery_request", {}) as Dictionary).get("requested", false)
		) else &"hazard_zone_exposed",
		sampled, actor_position
	)


## Exposes the active route's next landmark from a caller-owned on-foot sample.
## This is deliberately separate from route evidence: presenting a cue cannot
## commit a waypoint, invoke an interaction, or claim input authority.
func submit_surface_navigation_feedback(
		position: Variant,
		expected_host_generation: int,
		expected_attachment_generation: int,
		reduced_motion: bool = false
	) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	if expected_host_generation != _host_generation:
		return _result(false, &"stale_host_generation")
	if expected_attachment_generation != _attachment_generation \
			or int(_host.call(&"get_attachment_generation")) != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	if StringName(host_snapshot.get("phase_id", &"")) != &"on_foot":
		return _result(false, &"surface_navigation_lifecycle_mismatch")
	if not position is Vector3 or not (position as Vector3).is_finite():
		return _result(false, &"invalid_surface_navigation_position")
	return _present_surface_navigation_feedback(
		position as Vector3, expected_host_generation,
		expected_attachment_generation, reduced_motion
	)


func get_authored_hazard_status() -> Dictionary:
	return _hazard_semantic_status.duplicate(true)


## Public presentation envelope built from the exact live Host identities and
## the already-produced semantic hazard status. It is detached data only.
func get_authored_hazard_presentation_snapshot() -> Dictionary:
	return _authored_hazard_presentation_snapshot()


func set_surface_audio_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if _surface_audio_binding == null:
		return {"accepted": false, "reason": &"surface_audio_unavailable"}
	return _surface_audio_binding.call(&"set_reduced_dynamic_range", enabled)


func submit_weather_exposure(
		hazard_id: StringName,
		position: Variant,
		altitude_m: float,
		caller_time_seconds: float,
		exposure: float,
		delta_seconds: float,
		shelter_scalar: float
	) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	var result: Dictionary = _hazard.call(
		&"submit_weather_exposure", hazard_id, position, altitude_m,
		caller_time_seconds, exposure, delta_seconds, shelter_scalar
	)
	if bool(result.get("accepted", false)):
		_weather_observation = result.get("weather", {}).duplicate(true)
		_surface_audio_altitude_m = altitude_m
		_surface_audio_exposure = clampf(exposure, 0.0, 1.0)
		_surface_audio_generation += 1
		_present_surface_audio()
		_apply_water_presentation()
		_apply_landmark_beacons()
		_apply_landing_markers()
		if not _solar_phase.is_empty():
			_route_trail.call(&"apply_presentation_recipe", _solar_phase, _weather_observation)
	return result


func submit_solar_observation(
		surface_up: Variant, direction_to_sun: Variant, caller_time_seconds: float
	) -> Dictionary:
	if not _live() or not surface_up is Vector3 or not direction_to_sun is Vector3:
		return _result(false, &"invalid_solar_observation")
	var up := surface_up as Vector3
	var sun := direction_to_sun as Vector3
	if not up.is_finite() or not sun.is_finite() or up.length_squared() <= 0.0 \
			or sun.length_squared() <= 0.0 or not is_finite(caller_time_seconds) \
			or caller_time_seconds < 0.0:
		return _result(false, &"invalid_solar_observation")
	var elevation := clampf(up.normalized().dot(sun.normalized()), -1.0, 1.0)
	var state: StringName = &"night"
	var twilight := 0.0
	if elevation > 0.0:
		state = &"daylight"
	elif elevation > -0.104528:
		state = &"twilight"
		twilight = clampf(1.0 + elevation / 0.104528, 0.0, 1.0)
	_solar_phase = {
		"state": state, "sun_elevation_sine": elevation,
		"twilight_factor_unitless": twilight,
		"caller_time_seconds": caller_time_seconds,
	}.duplicate(true)
	_apply_settlement_practicals()
	_apply_landmark_beacons()
	_apply_landing_markers()
	_orbital_ring.call(&"apply_solar_phase", _solar_phase)
	_route_trail.call(&"apply_presentation_recipe", _solar_phase, _weather_observation)
	_surface_audio_generation += 1
	_present_surface_audio()
	_apply_water_presentation()
	return _result(true, &"solar_observation_accepted")


func apply_graphics_profile(profile: StringName) -> Dictionary:
	if not _live() or profile not in [&"low", &"medium", &"high"]:
		return _result(false, &"invalid_graphics_profile")
	_water_presentation.call(&"apply_graphics_profile", profile)
	for practical: Node in _settlement_practicals.values():
		practical.call(&"apply_graphics_profile", profile)
	return _result(true, &"graphics_profile_applied")


func _present_surface_audio() -> void:
	if _surface_audio_adapter == null or _surface_audio_policy == null \
			or _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	var shelter := float(_weather_observation.get("shelter_scalar", 0.0))
	var context: StringName = &"cabin" if shelter >= 0.75 else &"exterior"
	var policy_result: Dictionary = _surface_audio_policy.call(&"evaluate", {
		"altitude_m": _surface_audio_altitude_m,
		"listener_context": context,
		"grounded": false,
		"speed_mps": 0.0,
		"ambient_wind_scalar_unitless": 1.0,
	})
	var environment := {
		"generation": _surface_audio_generation,
		"solar": _solar_phase.duplicate(true),
		"weather": _weather_observation.duplicate(true),
		"cabin_exposed": context == &"cabin",
	}.duplicate(true)
	_surface_audio_adapter.call(
		&"present_environment", environment, policy_result, 0.0,
		_surface_audio_binding.call(&"get_attachment_generation"),
		maxi(1, absi(_host.get_instance_id())), 1, 1
	)


func _apply_water_presentation() -> void:
	if _water_presentation == null or _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	var solar_recipe := {
		"sun_energy_unitless": clampf(float(_solar_phase.get("sun_elevation_sine", 0.0)), 0.0, 1.0),
	}
	_water_presentation.call(
		&"apply_presentation_recipe", solar_recipe, _weather_observation
	)


func submit_water_contact(position: Variant, depth_m: float, velocity_mps: Variant, delta_seconds: float) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _water.call(
		&"sample_contact", depth_m, velocity_mps, delta_seconds, _attachment_generation
	)


func enter_water(position: Variant) -> Dictionary:
	if not _live():
		return _result(false, &"composition_detached")
	return _water.call(&"enter_water", position, _attachment_generation)


func detach() -> Dictionary:
	if _state != State.BOUND or not _host_current():
		return _result(false, &"composition_not_bound")
	var activity: StringName = _adapter.get_snapshot().get("state", &"idle") as StringName
	if activity in [&"active", &"ready"]:
		var detached: Dictionary = _adapter.call(&"detach")
		if not bool(detached.get("accepted", false)) and activity == &"active":
			return detached
	var settlement_snapshot := _settlement.call(&"get_snapshot") as Dictionary
	if settlement_snapshot.get("state", &"idle") == &"inside":
		_settlement.call(&"detach")
	for practical: Node in _settlement_practicals.values():
		practical.call(&"detach")
	for marker: Node in _landing_markers.values():
		marker.call(&"detach")
	_relay_survey_presentation.call(&"detach")
	_orbital_ring.call(&"detach")
	_route_trail.call(&"detach")
	_last_surface_navigation_feedback = {}
	for beacon: Node in _landmark_beacons.values():
		beacon.call(&"detach")
	if _hazard_zone_presentation != null:
		_hazard_zone_presentation.call(&"detach")
	if _survey_interaction != null:
		_survey_interaction.call(&"detach")
	if _sample_rack_interaction != null:
		_sample_rack_interaction.call(&"detach")
	_clear_authored_hazard_runtime_exposure()
	_set_hazard_semantic_clear(&"composition_detached")
	var water_snapshot := _water.call(&"get_snapshot") as Dictionary
	if water_snapshot.get("state", &"idle") == &"in_water":
		_water.call(&"detach")
	if _surface_audio_adapter != null:
		_surface_audio_adapter.call(
			&"detach", &"caller_detached",
			_surface_audio_binding.call(&"get_attachment_generation")
		)
	_state = State.DETACHED
	_publish_authored_hazard_presentation()
	return _result(true, &"composition_detached")


func reenter() -> Dictionary:
	if _state != State.DETACHED or not _host_current():
		return _result(false, &"composition_reentry_unavailable")
	var next_attachment := int(_host.call(&"get_attachment_generation"))
	if next_attachment <= _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	_attachment_generation = next_attachment
	if _adapter.get_snapshot().get("state", &"ready") == &"detached":
		var activity_reentry: Dictionary = _adapter.call(&"reenter")
		if not bool(activity_reentry.get("accepted", false)):
			return activity_reentry
	var settlement_snapshot := _settlement.call(&"get_snapshot") as Dictionary
	if settlement_snapshot.get("state", &"idle") == &"detached":
		_settlement.call(&"reenter", next_attachment)
	_apply_settlement_practicals()
	_apply_landmark_beacons()
	_apply_landing_markers()
	_orbital_ring.call(&"reenter")
	_route_trail.call(&"reenter")
	if _hazard_zone_presentation != null:
		_hazard_zone_presentation.call(&"reenter")
	if _survey_interaction != null:
		var survey_reentry: Dictionary = _survey_interaction.call(&"reenter", next_attachment)
		if not bool(survey_reentry.get("accepted", false)):
			return _result(false, &"survey_interaction_reentry_rejected")
	if _sample_rack_interaction != null:
		var rack_reentry: Dictionary = _sample_rack_interaction.call(
			&"reenter", next_attachment
		)
		if not bool(rack_reentry.get("accepted", false)):
			return _result(false, &"sample_rack_reentry_rejected")
	_set_hazard_semantic_clear(&"composition_reentered")
	_apply_relay_survey_presentation()
	var water_snapshot := _water.call(&"get_snapshot") as Dictionary
	if water_snapshot.get("state", &"idle") == &"detached":
		_water.call(&"reenter", next_attachment)
	var audio_attach: Dictionary = _surface_audio_adapter.call(
		&"attach", _surface_audio_policy.get_snapshot().get("profile_id", &""),
		maxi(1, absi(_host.get_instance_id())), 1, 1,
		_surface_audio_binding.call(&"get_attachment_generation")
	)
	if not bool(audio_attach.get("accepted", false)):
		return _result(false, &"surface_audio_reentry_rejected")
	_state = State.BOUND
	_publish_authored_hazard_presentation()
	return _result(true, &"composition_reentered")


func consume_orbit_return_handback(handback: Variant) -> Dictionary:
	if _state != State.BOUND or not handback is Dictionary:
		return _result(false, &"orbit_return_unavailable")
	var receipt := handback as Dictionary
	if StringName(receipt.get("reason", &"")) != &"runtime_ownership_returned" \
			or StringName(receipt.get("host_id", &"")) != &"ember_surface_loop" \
			or bool(receipt.get("host_attached", true)):
		return _result(false, &"invalid_orbit_return_handback")
	var detached := detach()
	if not bool(detached.get("accepted", false)):
		return detached
	return _result(true, &"planetary_orbit_return_consumed")


func accept_origin_rebase(receipt: Variant) -> Dictionary:
	if _state != State.BOUND or _adapter == null:
		return _result(false, &"origin_rebase_unavailable")
	return _adapter.call(&"accept_origin_rebase", receipt)


func get_snapshot() -> Dictionary:
	return {
		"state": [&"idle", &"bound", &"detached"][_state],
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"composition_generation": _composition_generation,
		"adapter": _adapter.get_snapshot() if _adapter != null else {},
		"navigation": _navigation.get_snapshot() if _navigation != null else {},
		"hazard": _hazard.get_snapshot() if _hazard != null else {},
		"hazard_content": _hazard_content.call(&"get_snapshot") if _hazard_content != null else {},
		"authored_hazard_status": _hazard_semantic_status.duplicate(true),
		"hazard_zone_presentation": _hazard_zone_presentation.call(&"get_snapshot") \
			if _hazard_zone_presentation != null else {},
		"weather": _weather.call(&"audit") if _weather != null else {},
		"solar_phase": _solar_phase.duplicate(true),
		"weather_observation": _weather_observation.duplicate(true),
		"water_presentation": _water_presentation.call(&"get_snapshot") if _water_presentation != null else {},
		"water": _water.get_snapshot() if _water != null else {},
		"landmarks": _landmarks.get_snapshot() if _landmarks != null else {},
		"settlement": _settlement.get_snapshot() if _settlement != null else {},
		"settlement_practicals": _settlement_practical_snapshot(),
		"landmark_beacons": _landmark_beacon_snapshot(),
		"landing_markers": _landing_marker_snapshot(),
		"orbital_ring": _orbital_ring.call(&"get_snapshot") if _orbital_ring != null else {},
		"route_trail": _route_trail.call(&"get_snapshot") if _route_trail != null else {},
		"surface_navigation_feedback": _last_surface_navigation_feedback.duplicate(true),
		"relay_survey": _relay_survey.get_snapshot(_adapter) if _relay_survey != null else {},
		"relay_survey_presentation": _relay_survey_presentation.call(&"get_snapshot") if _relay_survey_presentation != null else {},
		"relay_survey_persistence": {
			"configured": _relay_survey_persistence != null,
			"restored": not _restored_relay_survey_completion.is_empty(),
			"reward_replay_allowed": false,
			"completion": _restored_relay_survey_completion.duplicate(true),
			"authority": {"save": false, "reward": false, "activity": false},
		},
		"survey_interaction": _survey_interaction.call(&"get_snapshot") if _survey_interaction != null else {},
		"sample_rack_interaction": _sample_rack_interaction.call(&"get_snapshot") \
			if _sample_rack_interaction != null else {},
		"surface_audio": _surface_audio_adapter.call(&"get_snapshot") if _surface_audio_adapter != null else {},
	}.duplicate(true)


func _register_relay_survey_activity(director: ActivityDirector) -> void:
	if director.get_definition(_relay_survey.ACTIVITY_ID) != null:
		return
	var location := LocationDefinitionScript.new()
	location.location_id = &"ember_relay_survey_location"
	location.display_name = "Ember Relay Survey"
	location.sector_id = &"ember_moon_surface"
	location.anchor_source_id = _relay_survey.START_LANDMARK_ID
	location.anchor_position = Vector3(180.0, 120009.0, -44.0)
	location.content_note = "Authored Ember relay survey anchor."
	var definition := ActivityDefinitionScript.new()
	definition.activity_id = _relay_survey.ACTIVITY_ID
	definition.display_name = "Relay Survey"
	definition.content_note = "Survey the authored Ember relay route."
	definition.location = location
	definition.checkpoint_positions = PackedVector3Array([
		Vector3(180.0, 120009.0, -44.0), Vector3(540.0, 120030.0, -210.0)
	])
	director.register_definition(definition)


func _compose_authored_hazard_navigation_contract(
		content_snapshot: Dictionary
	) -> Dictionary:
	var selected := {}
	var recovery_landmark := {}
	for hazard_value in content_snapshot.get("hazards", []) as Array:
		var hazard := hazard_value as Dictionary
		if StringName(hazard.get("id", &"")) == AUTHORED_HAZARD_ID:
			selected = hazard.duplicate(true)
			break
	if selected.is_empty():
		return {"accepted": false, "reason": &"authored_hazard_missing"}
	for landmark_value in content_snapshot.get("landmarks", []) as Array:
		var landmark := landmark_value as Dictionary
		if StringName(landmark.get("id", &"")) == AUTHORED_HAZARD_RECOVERY_LANDMARK_ID:
			recovery_landmark = landmark.duplicate(true)
			break
	if recovery_landmark.is_empty():
		return {"accepted": false, "reason": &"authored_hazard_recovery_landmark_missing"}
	var contract := NavigationContractScript.new() as PlanetarySurfaceNavigationContract
	contract.hazard_ids.append(String(selected.id))
	contract.hazard_display_names.append(String(selected.display_name))
	contract.hazard_kind_ids.append(String(selected.kind))
	contract.hazard_marker_ids.append(String(AUTHORED_HAZARD_MARKER_ID))
	contract.hazard_route_ids.append(String(AUTHORED_HAZARD_RUNTIME_ROUTE_ID))
	contract.hazard_recovery_ids.append(String(selected.recovery_id))
	contract.hazard_positions_body_local_m.append(
		selected.position_body_local_m as Vector3
	)
	if not contract.is_definition_valid():
		return {"accepted": false, "reason": &"authored_hazard_runtime_contract_rejected"}
	selected["runtime_marker_id"] = AUTHORED_HAZARD_MARKER_ID
	selected["runtime_route_id"] = AUTHORED_HAZARD_RUNTIME_ROUTE_ID
	return {
		"accepted": true, "reason": &"authored_hazard_composed",
		"contract": contract, "hazard": selected,
		"recovery_landmark": recovery_landmark,
	}


func _validate_authored_hazard_observation(observation: Variant) -> Dictionary:
	if not observation is Dictionary:
		return {"accepted": false, "reason": &"invalid_hazard_observation"}
	var evidence := observation as Dictionary
	var expected_keys := [
		"actor_instance_id", "delta_seconds", "exposure_unitless",
		"position_body_local_m", "surface_phase_id",
	]
	if evidence.size() != expected_keys.size():
		return {"accepted": false, "reason": &"hazard_observation_schema_mismatch"}
	for key in expected_keys:
		if not evidence.has(key):
			return {"accepted": false, "reason": &"hazard_observation_schema_mismatch"}
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary
	var identities := host_snapshot.get("identities", {}) as Dictionary
	if not evidence.actor_instance_id is int \
			or int(evidence.actor_instance_id) == 0 \
			or int(evidence.actor_instance_id) \
				!= int(identities.get("player_instance_id", 0)):
		return {"accepted": false, "reason": &"hazard_actor_identity_mismatch"}
	if not evidence.surface_phase_id is StringName \
			or StringName(evidence.surface_phase_id) != &"on_foot" \
			or StringName(host_snapshot.get("phase_id", &"")) != &"on_foot":
		return {"accepted": false, "reason": &"hazard_lifecycle_mismatch"}
	if not evidence.position_body_local_m is Vector3 \
			or not (evidence.position_body_local_m as Vector3).is_finite():
		return {"accepted": false, "reason": &"invalid_hazard_position"}
	if not (evidence.exposure_unitless is float or evidence.exposure_unitless is int) \
			or not is_finite(float(evidence.exposure_unitless)) \
			or float(evidence.exposure_unitless) < 0.0 \
			or float(evidence.exposure_unitless) > 1.0:
		return {"accepted": false, "reason": &"invalid_hazard_exposure"}
	if not (evidence.delta_seconds is float or evidence.delta_seconds is int) \
			or not is_finite(float(evidence.delta_seconds)) \
			or float(evidence.delta_seconds) < 0.0 \
			or float(evidence.delta_seconds) > PlanetarySurfaceHazardRuntime.MAX_DELTA_SECONDS:
		return {"accepted": false, "reason": &"invalid_hazard_delta"}
	return {"accepted": true, "reason": &"hazard_observation_valid"}


func _set_hazard_semantic_from_sample(sampled: Dictionary) -> void:
	var recovery := sampled.get("recovery_request", {}) as Dictionary
	var recovery_required := bool(recovery.get("requested", false))
	_hazard_semantic_status = {
		"visible": true,
		"state": &"recovery_required" if recovery_required else &"warning",
		"hazard_id": AUTHORED_HAZARD_ID,
		"title": "RELAY ARC EXPOSURE",
		"status_text": "Return to the staging relay" if recovery_required \
			else "Electrical discharge zone",
		"recovery_id": recovery.get("recovery_id", &""),
		"exposure_unitless": float(sampled.get("exposure_unitless", 0.0)),
		"damage_request": (sampled.get("damage_request", {}) as Dictionary).duplicate(true),
		"recovery_request": recovery.duplicate(true),
		"authority": _hazard_zero_authority(),
	}.duplicate(true)
	_hazard_zone_presentation.call(&"apply_status", _hazard_semantic_status)
	_present_hazard_audio_status()


func _set_hazard_semantic_clear(reason: StringName) -> void:
	_hazard_semantic_status = {
		"visible": false,
		"state": &"clear",
		"hazard_id": AUTHORED_HAZARD_ID,
		"title": "RELAY ARC PERIMETER",
		"status_text": "Clear",
		"recovery_id": _authored_hazard.get("recovery_id", &""),
		"exposure_unitless": 0.0,
		"reason": reason,
		"damage_request": {"requested": false, "health_mutation": false},
		"recovery_request": {"requested": false, "movement_mutation": false},
		"authority": _hazard_zero_authority(),
	}.duplicate(true)
	if _hazard_zone_presentation != null \
			and bool((_hazard_zone_presentation.call(&"get_snapshot") as Dictionary).get("attached", false)):
		_hazard_zone_presentation.call(&"apply_status", _hazard_semantic_status)
	if reason == &"hazard_zone_exited":
		_present_hazard_audio_status()


func _present_hazard_audio_status() -> void:
	if _surface_audio_binding == null or _composition_generation < 1 or _host == null:
		return
	_surface_audio_binding.call(
		&"present_semantic_hazard_snapshot", _hazard_semantic_status,
		_composition_generation,
		_surface_audio_binding.call(&"get_attachment_generation"),
		maxi(1, absi(_host.get_instance_id())), 1, 1
	)


func _clear_authored_hazard_runtime_exposure() -> void:
	if _hazard == null:
		return
	var snapshot := _hazard.call(&"get_snapshot") as Dictionary
	var exposure := (snapshot.get("exposure", {}) as Dictionary).duplicate(true)
	if exposure.has(AUTHORED_HAZARD_ID):
		exposure[AUTHORED_HAZARD_ID] = 0.0
		snapshot["exposure"] = exposure
		_hazard.call(&"restore_snapshot", snapshot)


func _hazard_observation_result(
		accepted: bool, reason: StringName, sample: Dictionary,
		position_body_local_m: Vector3
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"position_body_local_m": position_body_local_m,
		"sample": sample.duplicate(true),
		"status": _hazard_semantic_status.duplicate(true),
		"presentation": _hazard_zone_presentation.call(&"get_snapshot"),
		"hud_presentation": _authored_hazard_presentation_snapshot(),
		"surface_navigation_feedback": _last_surface_navigation_feedback.duplicate(true),
	}.duplicate(true)


func _publish_authored_hazard_presentation() -> void:
	if _hazard_presentation_revision < MAX_SAFE_GENERATION:
		_hazard_presentation_revision += 1
	var snapshot := _authored_hazard_presentation_snapshot()
	authored_hazard_presentation_changed.emit(snapshot.duplicate(true))


func _authored_hazard_presentation_snapshot() -> Dictionary:
	var host_snapshot := _host.call(&"get_snapshot") as Dictionary \
		if _host != null and is_instance_valid(_host) else {}
	var identities := host_snapshot.get("identities", {}) as Dictionary
	var actor_instance_id := int(identities.get("player_instance_id", 0))
	var session_instance_id := 0
	if _host != null and is_instance_valid(_host) \
			and _host.has_method(&"get_travel_session_observation_source"):
		var session: Object = _host.call(&"get_travel_session_observation_source")
		if session != null and is_instance_valid(session):
			session_instance_id = session.get_instance_id()
	var host_instance_id := _host.get_instance_id() \
		if _host != null and is_instance_valid(_host) else 0
	var host_generation := int(host_snapshot.get("generation", _host_generation))
	var attachment_generation := int(
		host_snapshot.get("attachment_generation", _attachment_generation)
	)
	var phase_id := StringName(host_snapshot.get("phase_id", &""))
	var attached := _state == State.BOUND \
		and bool(host_snapshot.get("attached", false)) \
		and phase_id == &"on_foot" \
		and host_instance_id != 0 and actor_instance_id != 0 \
		and session_instance_id != 0 and host_generation > 0 \
		and attachment_generation > 0
	var waypoint := _authored_recovery_landmark.duplicate(true)
	var feedback := _last_surface_navigation_feedback.get("navigation", {}) as Dictionary
	var cue := feedback.get("cue", {}) as Dictionary
	if bool(cue.get("available", false)):
		waypoint = {
			"id": cue.get("landmark_id", &""),
			"label": cue.get("label", "Staging Relay"),
			"distance_m": cue.get("distance_m", 0.0),
		}.duplicate(true)
	else:
		waypoint = {
			"id": waypoint.get("id", AUTHORED_HAZARD_RECOVERY_LANDMARK_ID),
			"label": waypoint.get("display_name", "Staging Relay"),
			"distance_m": 0.0,
		}.duplicate(true)
	var reason: StringName = &"current"
	if _state == State.DETACHED or not bool(host_snapshot.get("attached", false)):
		reason = &"source_detached"
	elif actor_instance_id == 0 or session_instance_id == 0:
		reason = &"source_identity_lost"
	elif phase_id != &"on_foot":
		reason = &"surface_lifecycle_inactive"
	return {
		"attached": attached,
		"reason": reason,
		"host_instance_id": host_instance_id,
		"actor_instance_id": actor_instance_id,
		"session_instance_id": session_instance_id,
		"attachment_generation": attachment_generation,
		"generation": host_generation,
		"revision": maxi(1, _hazard_presentation_revision),
		"title": "EMBER SURFACE HAZARD",
		"message": str(_hazard_semantic_status.get("title", "RELAY ARC STATUS")),
		"waypoints": [waypoint],
		"weather": "Ember Relay Arc",
		"hazard": _hazard_semantic_status.duplicate(true),
		"presentation_only": true,
		"hazard_authority": false,
		"recovery_authority": false,
		"movement_authority": false,
		"input_authority": false,
	}.duplicate(true)


func _present_surface_navigation_feedback(
		position_body_local_m: Vector3,
		expected_host_generation: int,
		expected_attachment_generation: int,
		reduced_motion: bool = false
	) -> Dictionary:
	if _navigation == null or _route_trail == null:
		return _result(false, &"surface_navigation_feedback_unavailable")
	if expected_host_generation != _host_generation:
		return _result(false, &"stale_host_generation")
	if expected_attachment_generation != _attachment_generation:
		return _result(false, &"stale_attachment_generation")
	var feedback := _navigation.call(
		&"get_next_landmark_feedback", position_body_local_m
	) as Dictionary
	var presented := _route_trail.call(
		&"present_next_landmark_feedback", feedback,
		_route_trail.call(&"get_presentation_generation"), reduced_motion
	) as Dictionary
	_last_surface_navigation_feedback = {
		"accepted": bool(presented.get("accepted", false)),
		"reason": presented.get("reason", &"surface_navigation_feedback_rejected"),
		"navigation": feedback.duplicate(true),
		"presentation": presented.duplicate(true),
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"authority": {
			"navigation": false, "movement": false, "interaction": false,
			"input": false,
		},
	}.duplicate(true)
	return _last_surface_navigation_feedback.duplicate(true)


func _hazard_zero_authority() -> Dictionary:
	return {
		"damage": false, "health": false, "movement": false,
		"recovery": false, "reward": false, "hud": false,
		"lifecycle": false,
	}.duplicate(true)


func _apply_relay_survey_presentation() -> void:
	if _relay_survey_presentation == null or _adapter == null:
		return
	var activity_snapshot: Dictionary = _adapter.get_snapshot().get("activity_reward", {}) as Dictionary
	var survey_snapshot := _relay_survey.get_snapshot(_adapter) as Dictionary
	var checkpoint_snapshot := survey_snapshot.get("optional_checkpoint", {}) as Dictionary
	var mandatory_route := survey_snapshot.get("mandatory_route", {}) as Dictionary
	var committed_reward := activity_snapshot.get("committed_reward", {}) as Dictionary
	if not _restored_relay_survey_completion.is_empty() \
			and StringName(activity_snapshot.get("state", &"")) == &"ready":
		activity_snapshot = {
			"state": &"completed",
			"activity_id": &"ember_beacon_survey",
			"activity_generation": int(
				_restored_relay_survey_completion.get("activity_generation", -1)
			),
		}
		var restored_optional := _restored_relay_survey_completion.get(
			"optional_checkpoint", {}
		) as Dictionary
		checkpoint_snapshot = {
			"checkpoint_id": &"ember_bunker_gantry_log",
			"status": &"completed",
			"completed": true,
			"progress_text": "OPTIONAL BUNKER LOG  1 / 1",
			"status_text": "Bunker / gantry log recorded",
		} if bool(restored_optional.get("completed", false)) else {}
		mandatory_route = (
			_restored_relay_survey_completion.get("mandatory_route", {}) as Dictionary
		).duplicate(true)
		committed_reward = (
			_restored_relay_survey_completion.get("committed_reward", {}) as Dictionary
		).duplicate(true)
	_relay_survey_presentation.call(
		&"apply_activity_snapshot", activity_snapshot, checkpoint_snapshot,
		mandatory_route, committed_reward
	)


func _bind_relay_survey_pad_guides(host: Object) -> void:
	if _relay_survey_presentation == null or host == null \
			or not host.has_method(&"get_snapshot"):
		return
	var host_snapshot := host.call(&"get_snapshot") as Dictionary
	var loaded_scene_instance_id := int(
		host_snapshot.get("loaded_scene_instance_id", 0)
	)
	if loaded_scene_instance_id <= 0:
		return
	var loaded_scene := instance_from_id(loaded_scene_instance_id) as Node
	if loaded_scene == null or not is_instance_valid(loaded_scene) \
			or loaded_scene.get_script() != EmberAuthoredSceneScript:
		return
	var pad_guides := loaded_scene.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/PadGuideVisuals"
	) as MultiMeshInstance3D
	if pad_guides != null:
		_relay_survey_presentation.call(
			&"bind_landing_pad_guides", pad_guides, loaded_scene_instance_id
		)


func _on_survey_interaction_completed(receipt: Dictionary) -> void:
	if _relay_survey == null or _adapter == null:
		return
	var result := _relay_survey.call(
		&"submit_optional_checkpoint", _adapter, receipt
	) as Dictionary
	if bool(result.get("accepted", false)):
		var checkpoint := result.get("checkpoint", {}) as Dictionary
		_survey_interaction.call(
			&"activate_service_terminal",
			int(checkpoint.get("activity_generation", -1))
		)
	_apply_relay_survey_presentation()


func _sample_rack_activity_is_current(expected_activity_generation: int) -> bool:
	if _relay_survey == null or _adapter == null:
		return false
	var adapter_snapshot := _adapter.call(&"get_snapshot") as Dictionary
	var runtime := adapter_snapshot.get("activity_reward", {}) as Dictionary
	return StringName(adapter_snapshot.get("state", &"")) == &"active" \
		and StringName(runtime.get("state", &"")) == &"active" \
		and StringName(runtime.get("activity_id", &"")) == _relay_survey.ACTIVITY_ID \
		and int(runtime.get("activity_generation", -1)) \
			== expected_activity_generation


func _submit_sample_rack_optional_checkpoint(receipt: Dictionary) -> Dictionary:
	if _relay_survey == null or _adapter == null:
		return {"accepted": false, "reason": &"relay_survey_unavailable"}
	return _relay_survey.call(&"submit_optional_checkpoint", _adapter, receipt)


func _refresh_sample_rack_presentation() -> void:
	if _sample_rack_interaction != null:
		_sample_rack_interaction.call(&"get_snapshot")


func get_session_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"host_generation": _host_generation,
		"attachment_generation": _attachment_generation,
		"composition_generation": _composition_generation,
		"surface": _adapter.call(&"get_session_snapshot") if _adapter != null else {},
		"survey_interaction": _survey_interaction.call(&"get_persistence_snapshot") if _survey_interaction != null else {},
		"relay_survey_optional_checkpoint": _relay_survey.call(
			&"get_persistence_snapshot", _adapter
		) if _relay_survey != null else {},
		"authority": {"save": false, "movement": false, "reward": false, "doors": false},
	}.duplicate(true)


func restore_session_snapshot(snapshot: Variant) -> Dictionary:
	if _state != State.BOUND or not snapshot is Dictionary:
		return _result(false, &"invalid_planetary_session_snapshot")
	var saved := snapshot as Dictionary
	if int(saved.get("schema_version", -1)) != 1:
		return _result(false, &"unsupported_planetary_session_schema")
	if int(saved.get("host_generation", -1)) != _host_generation:
		return _result(false, &"stale_planetary_host_generation")
	if int(saved.get("attachment_generation", -1)) >= _attachment_generation:
		return _result(false, &"stale_planetary_attachment_generation")
	var surface := saved.get("surface", {}) as Dictionary
	if surface.is_empty():
		return _result(false, &"invalid_planetary_session_snapshot")
	var survey_saved := saved.get("survey_interaction", {}) as Dictionary
	var checkpoint_saved := saved.get("relay_survey_optional_checkpoint", {}) as Dictionary
	if _survey_interaction != null and not survey_saved.is_empty():
		var survey_validation: Dictionary = _survey_interaction.call(
			&"validate_persistence_snapshot", survey_saved
		)
		if not bool(survey_validation.get("accepted", false)):
			return _result(false, &"survey_interaction_restore_rejected")
	if _relay_survey != null and not checkpoint_saved.is_empty():
		var checkpoint_validation: Dictionary = _relay_survey.call(
			&"validate_persistence_snapshot", checkpoint_saved, _adapter
		)
		if not bool(checkpoint_validation.get("accepted", false)):
			return _result(false, &"relay_survey_checkpoint_restore_rejected")
	if not _surface_session_is_pristine(surface):
		var restored: Dictionary = _adapter.call(
			&"restore_session_snapshot", surface, _navigation, _hazard, _landmarks, _settlement
		)
		if not bool(restored.get("accepted", false)):
			return _result(false, restored.get("reason", &"planetary_session_restore_rejected") as StringName)
	if _survey_interaction != null and not survey_saved.is_empty():
		var survey_restored: Dictionary = _survey_interaction.call(
			&"restore_persistence_snapshot", survey_saved
		)
		if not bool(survey_restored.get("accepted", false)):
			return _result(false, &"survey_interaction_restore_rejected")
	if _relay_survey != null and not checkpoint_saved.is_empty():
		var checkpoint_restored: Dictionary = _relay_survey.call(
			&"restore_persistence_snapshot", checkpoint_saved, _adapter
		)
		if not bool(checkpoint_restored.get("accepted", false)):
			return _result(false, &"relay_survey_checkpoint_restore_rejected")
	_apply_relay_survey_presentation()
	return _result(true, &"planetary_session_restored")


func _surface_session_is_pristine(surface: Dictionary) -> bool:
	var route := surface.get("surface_route", {}) as Dictionary
	if StringName(surface.get("state", &"")) != &"ready" \
			or (not route.is_empty() and StringName(route.get("state", &"")) != &"idle") \
			or StringName((surface.get("surface_water", {}) as Dictionary).get("state", &"")) != &"idle" \
			or not (surface.get("settlement_entries", {}) as Dictionary).is_empty():
		return false
	var exposure := (surface.get("surface_hazard", {}) as Dictionary).get("exposure", {}) as Dictionary
	for value in exposure.values():
		if not is_zero_approx(float(value)):
			return false
	var landmarks := surface.get("activity_landmarks", {}) as Dictionary
	var settlement := surface.get("settlement", {}) as Dictionary
	return int(landmarks.get("sequence_index", -1)) == -1 \
		and StringName(settlement.get("state", &"")) == &"idle"


func _configure_settlement_practicals(contract_snapshot: Dictionary) -> void:
	_settlement_practicals.clear()
	for item in contract_snapshot.get("structures", []) as Array:
		var structure := item as Dictionary
		var structure_id := StringName(structure.get("id", &""))
		if structure_id.is_empty() or _settlement_practicals.size() >= 4:
			continue
		var practical := SettlementPracticalScript.new() as Node3D
		practical.name = "SettlementPractical_%s" % structure_id
		practical.position = structure.get("position_body_local_m", Vector3.ZERO)
		add_child(practical)
		var result: Dictionary = practical.call(&"configure", structure_id)
		if bool(result.get("accepted", false)):
			_settlement_practicals[structure_id] = practical


func _apply_settlement_practicals() -> void:
	if _solar_phase.is_empty():
		return
	for practical: Node in _settlement_practicals.values():
		practical.call(&"apply_solar_phase", _solar_phase)


func _settlement_practical_snapshot() -> Dictionary:
	var snapshot := {}
	for structure_id: StringName in _settlement_practicals:
		var practical: Node = _settlement_practicals[structure_id]
		snapshot[structure_id] = practical.call(&"get_snapshot")
	return snapshot


func _configure_landmark_beacons(contract_snapshot: Dictionary) -> void:
	_landmark_beacons.clear()
	for item in contract_snapshot.get("landmarks", []) as Array:
		var landmark := item as Dictionary
		var landmark_id := StringName(landmark.get("id", &""))
		var anchor: Variant = landmark.get("position_body_local_m", Vector3.INF)
		if landmark_id.is_empty() or not anchor is Vector3 or not (anchor as Vector3).is_finite():
			continue
		var beacon := LandmarkBeaconScript.new() as Node
		beacon.name = "LandmarkBeacon_%s" % landmark_id
		add_child(beacon)
		var result: Dictionary = beacon.call(&"configure", landmark_id, anchor)
		if bool(result.get("accepted", false)):
			_landmark_beacons[landmark_id] = beacon


func _apply_landmark_beacons() -> void:
	if _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	for beacon: Node in _landmark_beacons.values():
		beacon.call(&"apply_presentation_recipe", _solar_phase, _weather_observation)


func _landmark_beacon_snapshot() -> Dictionary:
	var snapshot := {}
	for landmark_id: StringName in _landmark_beacons:
		snapshot[landmark_id] = (_landmark_beacons[landmark_id] as Node).call(&"get_snapshot")
	return snapshot


func _configure_landing_markers(contract_snapshot: Dictionary) -> void:
	_landing_markers.clear()
	for item in contract_snapshot.get("landing_sites", []) as Array:
		var site := item as Dictionary
		var landing_id := StringName(site.get("id", &""))
		var anchor: Variant = site.get("position_body_local_m", Vector3.INF)
		if landing_id.is_empty() or not anchor is Vector3 or not (anchor as Vector3).is_finite():
			continue
		var marker := LandingApproachScript.new() as Node
		marker.name = "LandingApproach_%s" % landing_id
		add_child(marker)
		var result: Dictionary = marker.call(&"configure", landing_id, anchor)
		if bool(result.get("accepted", false)):
			_landing_markers[landing_id] = marker


func _apply_landing_markers() -> void:
	if _solar_phase.is_empty() or _weather_observation.is_empty():
		return
	for marker: Node in _landing_markers.values():
		marker.call(&"apply_presentation_recipe", _solar_phase, _weather_observation)


func _landing_marker_snapshot() -> Dictionary:
	var snapshot := {}
	for landing_id: StringName in _landing_markers:
		snapshot[landing_id] = (_landing_markers[landing_id] as Node).call(&"get_snapshot")
	return snapshot


func _live() -> bool:
	return _state == State.BOUND and _host_current()


func _host_current() -> bool:
	return _host != null and is_instance_valid(_host) \
		and int(_host.call(&"get_generation")) == _host_generation


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "runtime": get_snapshot()}.duplicate(true)
