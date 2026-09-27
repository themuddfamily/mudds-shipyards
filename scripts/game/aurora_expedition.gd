extends "res://scripts/game/planetary_surface_visit_expedition.gd"
## A repeatable Aurora visit on the production planetary path.
##
## Aurora is the temperate coast and the first world the journey coordinator's
## surface-visit lane served. The whole visit - admission, cruise, streamed
## composition, authored corridor, berth lease, surface, return and the
## interrupted-visit resume - is the shared [PlanetarySurfaceVisitExpedition];
## this wrapper only supplies Aurora's profile and keeps the constants GameFlow
## and the save bridge already address.
const DESTINATION_ID: StringName = &"aurora_temperate_world"
const WORLD_ID: StringName = &"aurora_temperate_world"
const LANDING_REGION_RESOURCE_PATH := \
	"res://assets/world/planets/aurora_foundation_landing.tres"
const _LANDING_REGION := preload(LANDING_REGION_RESOURCE_PATH)
const ApproachSourceType := preload(
	"res://scripts/world/aurora_visit_approach_source.gd"
)
const SurveyType := preload("res://scripts/activities/aurora_coastal_survey.gd")


func _init(flow: GameFlow) -> void:
	super(flow, make_profile())


static func make_profile() -> ProfileType:
	var visit := ProfileType.new()
	visit.destination_id = DESTINATION_ID
	visit.world_id = WORLD_ID
	visit.display_name = "Aurora"
	visit.reason_prefix = "aurora"
	visit.bootstrap_property = &"aurora_streaming_bootstrap"
	visit.binding_property = &"aurora_streaming_binding"
	visit.persistence_binding_property = &"_aurora_expedition_persistence_binding"
	visit.peer_expedition_property = &"_rime_expedition"
	visit.peer_active_copy = "RIME EXPEDITION ACTIVE"
	visit.landing_region = _LANDING_REGION
	visit.approach_source_script = ApproachSourceType
	visit.survey_script = SurveyType
	visit.berth_node_name = "AuroraExplorationBerth"
	visit.berth_id = &"aurora_exploration_pad"
	visit.approach_source_node_name = "AuroraVisitApproachSource"
	visit.fade_layer_name = "AuroraVisitTransition"
	visit.cruise_toast_body = "Streaming the world and arming the landing approach"
	visit.welcome_toast_body = "E: leave the ship. Explore the lookout, then board to return."
	visit.outbound_objective = "Cruising to Aurora — streaming the world and arming the approach"
	visit.corridor_objective = "Flying Aurora's authored approach corridor"
	visit.landing_objective = "Landing at Aurora's coastal exploration pad"
	visit.survey_heading = "AURORA COASTAL SURVEY"
	visit.restore_toast_body = "Your ship is on the pad where you left it"
	visit.return_toast_body = "Lift off and clear Aurora's surface; release controls to engage return cruise"
	return visit
