extends "res://scripts/game/planetary_surface_visit_expedition.gd"
## A repeatable Rime visit on the production planetary path.
##
## Rime, the cold glacial world, is reached exactly as Aurora is: the shared
## [PlanetarySurfaceVisitExpedition] admits it into the journey coordinator's
## one surface-visit lane with Rime's world id, streams it through Rime's own
## pair, flies its authored corridor and leases its icefall pad. On the surface
## the optional ice-core survey runs its cold-exposure hazard from the visit's
## physics tick (the survey declares `physics_tick` and `detach`). This wrapper
## only supplies Rime's profile and keeps the constants GameFlow addresses.
const DESTINATION_ID: StringName = &"rime_glacial_world"
const WORLD_ID: StringName = &"rime_glacial_world"
const LANDING_REGION_RESOURCE_PATH := \
	"res://assets/world/planets/rime_icefall_landing.tres"
const _LANDING_REGION := preload(LANDING_REGION_RESOURCE_PATH)
const ApproachSourceType := preload(
	"res://scripts/world/rime_visit_approach_source.gd"
)
const SurveyType := preload("res://scripts/activities/rime_ice_core_survey.gd")


func _init(flow: GameFlow) -> void:
	super(flow, make_profile())


static func make_profile() -> ProfileType:
	var visit := ProfileType.new()
	visit.destination_id = DESTINATION_ID
	visit.world_id = WORLD_ID
	visit.display_name = "Rime"
	visit.reason_prefix = "rime"
	visit.bootstrap_property = &"rime_streaming_bootstrap"
	visit.binding_property = &"rime_streaming_binding"
	visit.persistence_binding_property = &"_rime_expedition_persistence_binding"
	visit.peer_expedition_property = &"_aurora_expedition"
	visit.peer_active_copy = "AURORA EXPEDITION ACTIVE"
	visit.landing_region = _LANDING_REGION
	visit.approach_source_script = ApproachSourceType
	visit.survey_script = SurveyType
	visit.berth_node_name = "RimeExplorationBerth"
	visit.berth_id = &"rime_icefall_pad"
	visit.approach_source_node_name = "RimeVisitApproachSource"
	visit.fade_layer_name = "RimeVisitTransition"
	visit.cruise_toast_body = "Streaming the glacial world and arming the landing approach"
	visit.welcome_toast_body = "E: leave the ship. Follow the orange beacons, then board to return."
	visit.outbound_objective = "Cruising to Rime — streaming the glacial world and arming the approach"
	visit.corridor_objective = "Flying Rime's authored approach corridor through the ice haze"
	visit.landing_objective = "Landing at Rime's icefall survey pad"
	visit.survey_heading = "RIME ICE-CORE SURVEY"
	visit.restore_toast_body = "Your ship is on the icefall pad where you left it"
	visit.return_toast_body = "Lift off and clear Rime's ice shelf; release controls to engage return cruise"
	return visit
