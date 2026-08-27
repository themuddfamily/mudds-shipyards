class_name GameFlow
extends Node3D

const LiveCombatAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const LifecycleDamageableAdapterType := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const CombatResolverType := preload("res://scripts/combat/combat_resolver.gd")
const RepairAuthorityType := preload("res://scripts/combat/repair_authority.gd")
const BomberPayloadProjectileType := preload("res://scripts/combat/bomber_payload_projectile.gd")
const BomberPayloadCombatAdapterType := preload("res://scripts/combat/bomber_payload_combat_adapter.gd")
const CinderLongRangeBomberType := preload("res://scripts/ships/cinder_long_range_bomber.gd")
const CinderCargoHaulerType := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const CinderLoadmasterHudBindingType := preload("res://scripts/ui/cinder_loadmaster_hud_binding.gd")
const CinderNavigatorPingHudCompositionType := preload(
	"res://scripts/ui/cinder_navigator_ping_hud_composition.gd"
)
const FinalApproachHudCompositionType := preload("res://scripts/ui/final_approach_hud_composition.gd")
const WeaponDefinitionResolverProfileType := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const MainStartupStagerType := preload("res://scripts/game/main_startup_stager.gd")
const CaptionPresentationEventType := preload("res://scripts/ui/caption_presentation_event.gd")
const CaptionPresentationServiceType := preload("res://scripts/ui/caption_presentation_service.gd")
const RuntimeSettingsStoreAdapterType := preload(
	"res://scripts/settings/runtime_settings_store_adapter.gd"
)
const RuntimeSettingsRepairBindingType := preload(
	"res://scripts/persistence/runtime_settings_repair_binding.gd"
)
const UserDataStoreType := preload("res://scripts/persistence/user_data_store.gd")
const CinderRaceSessionPersistenceType := preload(
	"res://scripts/persistence/cinder_race_session_persistence.gd"
)
const CinderPatrolSessionPersistenceType := preload(
	"res://scripts/persistence/cinder_patrol_session_persistence.gd"
)
const SafeStartProductionRecoveryType := preload(
	"res://scripts/recovery/safe_start_production_recovery.gd"
)
const NetworkSessionAdapterType := preload(
	"res://scripts/network/network_enet_session_adapter.gd"
)
const NetworkHalyardCrewCommandBridgeType := preload(
	"res://scripts/network/network_halyard_crew_command_bridge.gd"
)
const NetworkShipAuthorityCompositionType := preload(
	"res://scripts/network/network_ship_authority_composition.gd"
)
const NETWORK_MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MovingInteriorRelationshipType := preload(
	"res://scripts/network/moving_interior_relationship.gd"
)
const NearbySectorActivityAudioBindingType := preload(
	"res://scripts/audio/nearby_sector_activity_audio_binding.gd"
)
const NearbySectorActivityMusicAdapterType := preload(
	"res://scripts/audio/nearby_sector_activity_music_adapter.gd"
)
const HalyardCrewSemanticAudioBindingType := preload(
	"res://scripts/audio/halyard_crew_semantic_audio_binding.gd"
)
const OptionalSemanticAudioCompositionType := preload(
	"res://scripts/audio/optional_semantic_audio_composition.gd"
)
const EmberSurfaceLoopAudioCompositionType := preload(
	"res://scripts/audio/ember_surface_loop_audio_composition.gd"
)
const EmberSurfaceReturnStatusBindingType := preload(
	"res://scripts/ui/ember_surface_return_status_binding.gd"
)
const EmberSurfaceReturnHudAdapterType := preload(
	"res://scripts/ui/ember_surface_return_hud_adapter.gd"
)
const CrashRecoveryCoordinatorType := preload("res://scripts/diagnostics/crash_recovery_coordinator.gd")
const SessionDiagnosticRecordType := preload("res://scripts/diagnostics/session_diagnostic_record.gd")
const SessionDiagnosticFileSinkType := preload("res://scripts/diagnostics/session_diagnostic_file_sink.gd")
const SessionDiagnosticLifecycleBridgeType := preload("res://scripts/diagnostics/session_diagnostic_lifecycle_bridge.gd")

## First production nearby activity. It is a modern interpretation and remains
## a progress-only route: the director and this integration own no rewards,
## combat, ship, landing, or berth state.
const DEFAULT_FREE_FLIGHT_ACTIVITY_ID: StringName = &"cinder_reach_checkpoint_route"
const ACTIVITY_KIND_TIMED_RACE: StringName = &"timed_race"
const ACTIVITY_KIND_PATROL: StringName = &"patrol"
const ACTIVITY_KIND_CARGO_DELIVERY: StringName = &"cargo_delivery"
const ACTIVITY_KIND_CONVOY_ESCORT: StringName = &"convoy_escort"
const CINDER_CONVOY_ACTIVITY_ID: StringName = &"cinder_reach_emberline_convoy"
## The tender stays on its authored route. This audited point is the centre of
## the collision-clear player rendezvous lane 20 metres above route point zero.
const CINDER_CONVOY_ACTIVATION_CENTER := Vector3(84.0, -48.0, -724.0)
const CINDER_CONVOY_ACTIVATION_RADIUS := 4.0
const CINDER_CONVOY_ESCORT_LANE_OFFSET := Vector3(0.0, 20.0, 0.0)
const CARGO_DELIVERY_ACTIVITY_ID: StringName = &"jovian_fabrication_kit_delivery"
const CARGO_DELIVERY_DISPLAY_NAME := "Jovian fabrication kit delivery"
const CARGO_DELIVERY_EVIDENCE_STATUS: StringName = &"modern_interpretation"
const CARGO_DELIVERY_ITEM_ID: StringName = &"fabrication_kits"
const CARGO_DELIVERY_ITEM_DISPLAY_NAME := "Fabrication kits"
const CARGO_DELIVERY_QUANTITY := 2
const CARGO_DELIVERY_SOURCE_INITIAL_QUANTITY := 6
const CARGO_DELIVERY_SOURCE_MANIFEST_ID: StringName = &"jovian_provisional_manifest"
const CARGO_DELIVERY_DESTINATION_MANIFEST_ID: StringName = &"jovian_freight_berth_manifest"
const CARGO_DELIVERY_SOURCE_CAPACITY := 6
const CARGO_DELIVERY_DESTINATION_CAPACITY := 64
const CARGO_DELIVERY_DEADLINE_SECONDS := 180.0
const CARGO_DELIVERY_PHASES: Array[StringName] = [
	&"departed_shipyard",
	&"returned_to_shipyard",
]
const CINDER_RACE_LAPS := 1
const CINDER_RACE_COUNTDOWN_SECONDS := 2.0
const CINDER_RACE_TIMEOUT_SECONDS := 120.0
const CINDER_RACE_SESSION_PERSISTENCE_SLOT: StringName = &"cinder_timed_race_session"
const CINDER_RACE_SESSION_COMMIT_PREFIX := "cinder-race-session-"
const CINDER_PATROL_DWELL_SECONDS := 2.0
const CINDER_PATROL_SESSION_PERSISTENCE_SLOT: StringName = &"cinder_patrol_session"
const CINDER_PATROL_SESSION_COMMIT_PREFIX := "cinder-patrol-session-"
## Arcade recovery budget between authoritative hull loss and the first safe
## berth-regeneration attempt. The attempt still has to pass reset preflight,
## acquire the exact home-berth lease, and commit the retained ship lifecycle.
const DESTROYED_SHIP_REGENERATION_DELAY_MSEC := 2_000
const CAPTION_CATEGORY_BY_ID := {
	&"dialogue": CaptionPresentationEvent.Category.DIALOGUE,
	&"radio": CaptionPresentationEvent.Category.RADIO,
	&"system": CaptionPresentationEvent.Category.SYSTEM,
	&"ambient": CaptionPresentationEvent.Category.AMBIENT,
}
const RUNTIME_SETTINGS_COMMIT_PREFIX := "runtime-settings-"
const RUNTIME_SETTINGS_COMMIT_DIGITS := 10
const RUNTIME_SETTINGS_REPAIR_COMMIT_PREFIX := "runtime-settings-repair-"
## Five seconds of successful physics callbacks is long enough to cross the
## staged Main construction and first embodied simulation ticks without making
## wall-clock, idle-frame, or scene-tree attachment time authoritative.
const SAFE_START_STABILITY_PHYSICS_SECONDS := (
	SafeStartProductionRecoveryType.STABILITY_PHYSICS_SECONDS
)
const SAFE_START_RECOMMENDATION_PRESERVED_KEYS := (
	SafeStartProductionRecoveryType.RECOMMENDATION_PRESERVED_KEYS
)
const PLANETARY_CRUISE_MAX_CALLER_TICK := 9_007_199_254_740_991
const PLANETARY_CRUISE_MAX_HUD_TOGGLE_SERIAL := 9_007_199_254_740_991
const MUDDS_RETURN_TARGET_ID: StringName = &"mudds_shipyards"
const MUDDS_RETURN_CORRIDOR_HALF_LENGTH_METERS := 750_000.0
const MUDDS_RETURN_CORRIDOR_MINIMUM_HALF_WIDTH_METERS := 100.0
const MUDDS_RETURN_BRAKE_SHELL_MINIMUM_METERS := 25_000.0
const MUDDS_RETURN_BRAKE_SHELL_MAXIMUM_METERS := 65_000.0
const MUDDS_RETURN_MAXIMUM_SPEED_MPS := 12.0
const MUDDS_RETURN_MAXIMUM_ATTITUDE_DEGREES := 12.0
const MUDDS_RETURN_HULL_MARGIN_METERS := 0.05
const MUDDS_RETURN_FLEET_IDS: Array[StringName] = [
	&"torrent_provisional",
	&"arrow_provisional",
	&"jovian_provisional",
	&"zenith_b7_observed",
	&"halyard_new_design",
]
const EMBER_STATION_RETURN_HANDOFF_KEYS := [
	"schema_version",
	"intent_id",
	"destination_id",
	"activity_id",
	"activity_generation",
	"actor_instance_id",
	"craft_instance_id",
	"session_generation",
	"attachment_generation",
	"coordinate_frame_generation",
	"orbital_coordinate",
	"evidence_sequence",
	"arrival_confirmed",
	"authority",
]
const EMBER_STATION_RETURN_AUTHORITY_KEYS := [
	"movement", "teleport", "origin", "landing", "boarding", "berth",
	"reward", "arrival",
]
const EMBER_STATION_RETURN_EVIDENCE_SEQUENCE := [
	"reboard", "takeoff", "ascent", "orbit",
]
const EMBER_SERVICE_TERMINAL_ID: StringName = &"ember_bunker_service_terminal"
const EMBER_SERVICE_RESOURCE_ID: StringName = &"ember_service_charge"
const EMBER_SERVICE_ACTOR_RANGE_METERS := 2.5
const EMBER_SERVICE_CRAFT_RANGE_METERS := 48.0
const EMBER_SERVICE_REPAIR_AMOUNT := 0.20
const DEBUG_AIM_DISTANCE_METERS := 10_000.0
const MINIMAP_STATION_RANGE_METERS := 180.0
const MINIMAP_FLIGHT_RANGE_METERS := 900.0

## Production Main can be destroyed and rebuilt by the shift-restart loader
## without ending the OS process. Keep the atomic composition root here so that
## path still owns one settings/store/adapter identity and one startup load.
## Injected test stores never enter this process state.
static var _production_runtime_settings_state: Dictionary = {}

enum Phase {
	INTRO,
	APPROACH_SHIP,
	BOARDING,
	## Stable phase ID for a seated pilot awaiting physical departure. Propulsion
	## is demand-driven; there is no separate player engine-start step.
	START_ENGINES,
	LAUNCH,
	TARGET_PRACTICE,
	INTERCEPTOR_ENGAGEMENT,
	RETURN_TO_YARD,
	## Stable phase ID for a landed return awaiting automatic idle shutdown/exit.
	SHUT_DOWN,
	DISEMBARKING,
	COMPLETE,
	FAILED,
	FREE_FLIGHT,
	RECOVERING,
	## The craft has idled offline away from a berth; its pilot left the seat and is on
	## foot inside the same craft while it drifts. Appended so every existing
	## ordinal is unchanged. `modern_interpretation`.
	IN_FLIGHT_CABIN,
}

const ENEMY_SPAWN := Vector3(24.0, 12.0, -148.0)
const ENEMY_WEAPON_RANGE := 420.0
const ENEMY_HIT_DAMAGE := 11.0
const RANGE_TARGET_HIT_DAMAGE := 50.0
const PLAYER_SOURCE_IDS := {
	&"torrent_provisional": 1101,
	&"arrow_provisional": 1102,
	&"jovian_provisional": 1103,
	&"zenith_b7_observed": 1104,
	&"halyard_new_design": 1105,
	&"cinder-long-range-bomber": 1106,
}
const FLIGHT_PATH_MINIMUM_SPEED := 1.5
const FLIGHT_PATH_PROJECTION_DISTANCE := 100.0
const FLIGHT_PATH_NEAR_SIDE_EPSILON := 0.001
const FLIGHT_PATH_SAFE_HORIZONTAL_VIEWPORT_RATIO := 0.27
const FLIGHT_PATH_SAFE_HORIZONTAL_ASPECT_LIMIT := 0.52
const FLIGHT_PATH_SAFE_VERTICAL_VIEWPORT_RATIO := 0.18
const BOARDING_FALLBACK_REACH := 7.0
const STATION_SEAT_MAX_REACH := 3.25
const OPPONENT_SOURCE_ID := 2101
const RANGE_OPPONENT_NETWORK_ID: StringName = &"range_defence_interceptor"
const STATION_DEFENSE_WEAPON_ID: StringName = &"perimeter_defense_pulse"
const STATION_DEFENSE_NETWORK_PREFIX := "station_defense_"
const STATION_DEFENSE_SOURCE_IDS := {
	&"perimeter_raider_alpha": 2121,
	&"perimeter_raider_beta": 2122,
	&"perimeter_raider_gamma": 2123,
}
const PLAYER_FACTION: StringName = &"shipyard_flight_test"
const OPPONENT_FACTION: StringName = &"range_defence"
const RANGE_WEAPON_ID: StringName = &"range_pulse_cannon"
const TORRENT_COMBAT_WEAPON_ID: StringName = &"torrent_compact_pulse_cannon"
const ARROW_COMBAT_WEAPON_ID: StringName = &"arrow_precision_recon_emitter"
const ZENITH_COMBAT_WEAPON_ID: StringName = &"zenith_interceptor_repeater"
const JOVIAN_COMBAT_WEAPON_ID: StringName = &"jovian_heavy_defensive_cannon"
const HALYARD_COMBAT_WEAPON_ID: StringName = &"halyard_long_range_defensive_lance"
## Compatibility name for the guided Torrent activity. Other ships must use
## their explicit per-hull weapon IDs above.
const COMBAT_WEAPON_ID: StringName = TORRENT_COMBAT_WEAPON_ID
const OPPONENT_WEAPON_ID: StringName = &"defence_pulse_cannon"
const TORRENT_SHIP_ID: StringName = &"torrent_provisional"
const TORRENT_COMBAT_ORIGIN_TOLERANCE_METERS := 24.0
const TORRENT_COMBAT_PRESENTATION_ID: StringName = &"cyan"
const TORRENT_COMBAT_FIRE_AUDIO_ID: StringName = &"player_pulse_fire"
const TORRENT_COMBAT_IMPACT_AUDIO_ID: StringName = &"hull_impact_medium"
const TORRENT_COMBAT_DRY_FIRE_AUDIO_ID: StringName = &"dry_fire_click"
const TORRENT_COMBAT_WEAPON_DEFINITION := preload(
	"res://assets/weapons/torrent_combat_pulse.tres"
)
const ARROW_SHIP_ID: StringName = &"arrow_provisional"
const ARROW_COMBAT_ORIGIN_TOLERANCE_METERS := 24.0
const ARROW_COMBAT_PRESENTATION_ID: StringName = TORRENT_COMBAT_PRESENTATION_ID
const ARROW_COMBAT_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_FIRE_AUDIO_ID
const ARROW_COMBAT_IMPACT_AUDIO_ID: StringName = TORRENT_COMBAT_IMPACT_AUDIO_ID
const ARROW_COMBAT_DRY_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_DRY_FIRE_AUDIO_ID
const ARROW_COMBAT_WEAPON_DEFINITION := preload(
	"res://assets/weapons/arrow_combat_pulse.tres"
)
const ZENITH_SHIP_ID: StringName = &"zenith_b7_observed"
const ZENITH_COMBAT_ORIGIN_TOLERANCE_METERS := 24.0
const ZENITH_COMBAT_PRESENTATION_ID: StringName = TORRENT_COMBAT_PRESENTATION_ID
const ZENITH_COMBAT_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_FIRE_AUDIO_ID
const ZENITH_COMBAT_IMPACT_AUDIO_ID: StringName = TORRENT_COMBAT_IMPACT_AUDIO_ID
const ZENITH_COMBAT_DRY_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_DRY_FIRE_AUDIO_ID
const ZENITH_COMBAT_WEAPON_DEFINITION := preload(
	"res://assets/weapons/zenith_combat_pulse.tres"
)
const JOVIAN_SHIP_ID: StringName = &"jovian_provisional"
const JOVIAN_COMBAT_ORIGIN_TOLERANCE_METERS := 32.0
const JOVIAN_COMBAT_PRESENTATION_ID: StringName = TORRENT_COMBAT_PRESENTATION_ID
const JOVIAN_COMBAT_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_FIRE_AUDIO_ID
const JOVIAN_COMBAT_IMPACT_AUDIO_ID: StringName = TORRENT_COMBAT_IMPACT_AUDIO_ID
const JOVIAN_COMBAT_DRY_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_DRY_FIRE_AUDIO_ID
const JOVIAN_COMBAT_WEAPON_DEFINITION := preload(
	"res://assets/weapons/jovian_combat_pulse.tres"
)
const HALYARD_SHIP_ID: StringName = &"halyard_new_design"
const HALYARD_COMBAT_ORIGIN_TOLERANCE_METERS := 30.0
const HALYARD_COMBAT_PRESENTATION_ID: StringName = TORRENT_COMBAT_PRESENTATION_ID
const HALYARD_COMBAT_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_FIRE_AUDIO_ID
const HALYARD_COMBAT_IMPACT_AUDIO_ID: StringName = TORRENT_COMBAT_IMPACT_AUDIO_ID
const HALYARD_COMBAT_DRY_FIRE_AUDIO_ID: StringName = TORRENT_COMBAT_DRY_FIRE_AUDIO_ID
const HALYARD_COMBAT_WEAPON_DEFINITION := preload(
	"res://assets/weapons/halyard_combat_pulse.tres"
)
const CINDER_BOMBER_SHIP_ID: StringName = &"cinder-long-range-bomber"
const CINDER_BOMBER_WEAPON_ID: StringName = &"bomber_payload_release"
const PLAYER_PULSE_NETWORK_MAX_PENDING := 32
const CINDER_BOMBER_PAYLOAD_PROFILE := {
	"range": 900.0,
	"damage": 80.0,
	"origin_tolerance": 30.0,
}
const CINDER_BOMBER_NETWORK_PROJECTILE_PROFILES := {
	CINDER_BOMBER_WEAPON_ID: {
		"speed": 500.0,
		"damage": 80.0,
		"lifetime": 30.0,
	},
}
const PLAYER_WEAPON_PROFILES := {
	RANGE_WEAPON_ID: {
		"range": 360.0,
		"damage": RANGE_TARGET_HIT_DAMAGE,
		"origin_tolerance": 24.0,
	},
}
const OPPONENT_WEAPON_PROFILES := {
	OPPONENT_WEAPON_ID: {
		"range": ENEMY_WEAPON_RANGE,
		"damage": ENEMY_HIT_DAMAGE,
		"origin_tolerance": 18.0,
	},
}
const RUNTIME_SETTING_KEYS: Array[StringName] = [
	&"ship_mouse_sensitivity",
	&"on_foot_mouse_sensitivity",
	&"invert_ship_y",
	&"invert_on_foot_y",
	&"camera_fov",
	&"on_foot_first_person",
	&"master_volume",
	&"ambience_volume",
	&"engine_volume",
	&"weapons_volume",
	&"ui_volume",
	&"music_volume",
	&"graphics_profile",
	&"window_mode",
	&"display_resolution",
	&"vsync_mode",
	&"control_preset",
	&"ui_scale",
	&"colorblind_palette",
	&"reduced_motion",
	&"captions_enabled",
	&"reduced_dynamic_range",
	&"reduced_flash",
	&"payload_visual_intensity",
	&"show_tutorials",
	&"multiplayer_display_name",
	&"network_default_port",
	&"input_binding_profile",
]

@export_range(0.0, 3.0, 0.05) var canopy_motion_time := 0.65
@export_range(0.0, 4.0, 0.05) var boarding_motion_time := 1.1
@export_range(0.0, 4.0, 0.05) var disembarking_motion_time := 0.9

# Resolved by `_resolve_scene_bindings()` rather than `@onready`, because under a
# staged startup these children are deliberately not in the tree yet when
# `_ready()` runs. The resolver is called at exactly the moment the authored
# subtree is complete on both paths, so every reader still sees the same nodes it
# always did.
var world: Node3D
var player: CharacterBody3D
var activity_board_console: Area3D
## Legacy primary alias retained for the guided vertical-slice tests. Runtime
## gameplay uses `active_ship` and the physical `ships` registry below.
var ship: HeroShip
var opponent: CharacterBody3D
var combat_authority: LiveCombatAuthorityType
var pulse_presentation: PulseWeaponPresentation
var combat_audio: CombatAudioPresentation
var hud: CanvasLayer
var audio: Node
## Exact caller-owned ShipAudioRigs currently registered as the semantic `ship`
## source set. The physical fleet registry remains authoritative for membership.
var _fleet_ship_semantic_audio_sources: Dictionary = {}
var music_bed: StationMusicBed
var nearby_activity_audio_binding: Node
var nearby_activity_music_adapter: Node
var halyard_crew_semantic_audio_binding: Node
var _halyard_crew_semantic_bound := false
var _last_halyard_crew_event_sequence := -2
var optional_semantic_audio_composition: Node
var _bomber_payload_ship: CinderLongRangeBomber
var _bomber_payload_generation := 0
var _bomber_payload_request_sequence := 0
var _bomber_payload_projectiles: Array[BomberPayloadProjectile] = []
var _bomber_payload_adapter: BomberPayloadCombatAdapter
var _last_bomber_payload_result: Dictionary = {}
var _bomber_payload_server_tick := 0
var _bomber_payload_network_source_generation := 0
var _bomber_payload_canonical_publish_pending := false
var _last_bomber_payload_network_result: Dictionary = {}
var _last_bomber_payload_canonical_result: Dictionary = {}
var _bomber_payload_replica_migration_generation := 0
var _bomber_payload_replica_generations: Dictionary = {}
var _bomber_payload_hud_terminal_receipt: Dictionary = {}
## The Torrent pulse remains an already-resolved hitscan presentation. These
## records only mirror its bounded visual lifecycle into the server projectile
## seam; they never query collision or commit damage.
var _player_pulse_network_sequence := 0
var _player_pulse_network_server_tick := 0
var _player_pulse_network_pending: Array[Dictionary] = []
var _player_pulse_network_active_shots: Dictionary = {}
var _player_pulse_network_context: Dictionary = {}
var _player_pulse_canonical_publish_pending := false
var _last_player_pulse_network_result: Dictionary = {}
var _last_player_pulse_canonical_result: Dictionary = {}
var _player_pulse_replica_migration_generation := 0
var _player_pulse_replica_generations: Dictionary = {}
var _opponent_pulse_network_generation := 0
var _opponent_pulse_network_sequence := 0
var _opponent_pulse_network_context: Dictionary = {}
var _opponent_pulse_replica_generations: Dictionary = {}
var nearby_activity_persistence_store: RefCounted
var nearby_activity_persistence_slot: StringName = &"nearby_activity"
var _nearby_activity_persistence_commit_serial := 0
var activity_director: ActivityDirector
var cinder_race_session: CinderTimedRaceSession
var patrol_activity: PatrolActivity
var cinder_convoy_host: CinderConvoyEscortHost
var cinder_streaming_bootstrap: CinderStreamingBootstrap
var cinder_streaming_binding: CinderStreamingProductionBinding
var cinder_streaming_coordinator: WorldStreamingCoordinator
var ember_streaming_bootstrap: EmberMoonStreamingBootstrap
var ember_streaming_binding: EmberMoonStreamingProductionBinding
var ember_surface_loop_production_binding: EmberSurfaceLoopProductionBinding
var ember_surface_loop_host: EmberSurfaceLoopHost
var ember_surface_berth: EmberSurfaceBerth
## Retained presentation identities for the one production Ember Host. They
## detach targeted registrations at the Main tree boundary and are reused on
## re-entry; neither component owns Host, movement, session, reward, or playback.
var _ember_surface_loop_audio_composition: Node
var _ember_surface_return_status_binding: RefCounted
var _ember_surface_return_hud_adapter: RefCounted
var common_world_origin_rebase_owner: CommonWorldOriginRebaseOwner
var planetary_cruise_binding: PlanetaryCruiseProductionBinding
var _final_approach_hud_composition: FinalApproachHudComposition
var _cinder_loadmaster_hud_binding: CinderLoadmasterHudBinding
var _cinder_loadmaster_hud_craft: CinderCargoHauler
var _cinder_navigator_ping_hud_composition: RefCounted
var _cinder_navigator_presentation_ship_generation := 0
var cargo_transfer_authority: CargoTransferAuthority
var cargo_delivery_activity: CargoDeliveryActivity
## Opt-in multiplayer transport. Normal solo startup never creates this node;
## explicit host/join calls retain the ENet/lifecycle seam beneath GameFlow.
var network_session: NetworkSessionAdapterType
var _network_halyard_command_bridge
var _network_ship_authority_composition: NetworkShipAuthorityComposition
var _network_composition_ship: HeroShip
var _network_ship_generation := 0
var _network_ship_event_sequence := 0
var _network_session_mode: StringName = &""
var _network_session_address := "127.0.0.1"
var _network_session_port := NetworkSessionAdapterType.DEFAULT_PORT
var _network_session_max_clients := NetworkSessionAdapterType.DEFAULT_MAX_CLIENTS
var _network_hud_snapshot_generation := 0
var _network_damage_entities: Dictionary = {}
var _network_damage_server_tick := 0
var _network_landing_entities: Dictionary = {}
var _network_landing_handoffs: Dictionary = {}
var _last_network_landing_handoff_result: Dictionary = {}
var _network_landing_request_sequence := 0
var _network_landing_server_tick := 0
var _network_boarding_entities: Dictionary = {}
var _network_boarding_server_tick := 0
## One presentation-only caption authority for this Main lifetime. It is a
## RefCounted service rather than a scene node and survives whole-Main detach.
var _caption_presentation_service: CaptionPresentationService
var _caption_event_serial := 0
var _caption_request_count := 0
var _caption_accepted_count := 0
var _caption_rejected_count := 0
var _reduced_dynamic_range := false

var phase := Phase.INTRO
var destroyed_targets := 0
var total_targets := 0
var _near_ship := false
var _piloting := false
## True only while the same visible pilot is seated in the deck tow tractor.
## Deliberately separate from `_piloting`: the tractor is a ground vehicle and
## must never reach the flight, berth, landing, combat or regeneration paths that
## `_piloting` gates. `tests/fleet_lifecycle_safety_test.gd` freezes that roster.
var _driving := false
## Fixed station furniture uses the Player's camera and seated animation but
## acquires no driving, piloting, berth, or network authority.
var _station_seated := false
var _active_station_seat: StationSeat
var _station_seat_recovery_transform := Transform3D.IDENTITY
## Which of the tow tractor's two independent safety guards last recalled the
## driver. Diagnostic only; nothing gameplay-facing reads it.
var _last_tractor_recovery_reason: StringName = &""
var _last_engine_state := "OFFLINE"
var _launch_registered := false
var _return_registered := false
var _first_sortie_tutorial_generation := 0
var _first_sortie_tutorial_revision := 0
var _first_sortie_tutorial_completed_steps: Dictionary = {}
var _first_sortie_tutorial_dismissed_generation := -1
var _first_sortie_tutorial_active_step: StringName = &""
var _transition_busy := false
## Every awaited boarding/disembarking coroutine captures this generation. A
## destructive recovery advances it before restoring the player, so stale
## continuations can never reacquire cameras, seats, phases, or berth state.
var _transition_generation := 0
## A ground transition has no persistent ship or berth ownership to restore
## after a whole-Main detach. Its awaiting continuation must therefore be
## cancelled at that lifecycle boundary rather than resuming into drive
## authority after the retained nodes re-enter.
var _ground_transition_active := false
## Captured while the station is live. Child nodes leave the tree before Main,
## so a detach transaction must never query the world's global spawn transform.
var _ground_transition_recovery_transform := Transform3D.IDENTITY
var _opponent_spawned := false
var runtime_settings: RuntimeSettings
## Process-lifetime persistence composition for the one production settings
## owner. These RefCounted identities survive whole-Main detach/re-entry and are
## never recreated after the one startup load.
var _runtime_settings_user_data_store: UserDataStore
var _runtime_settings_store_adapter: RuntimeSettingsStoreAdapter
var _runtime_settings_legacy_path := RuntimeSettings.DEFAULT_CONFIG_PATH
var _runtime_settings_load_attempted := false
var _runtime_settings_load_status: Dictionary = {}
var _runtime_settings_repair_binding: RefCounted
var _runtime_settings_last_save_status: Dictionary = {}
var _runtime_settings_load_attempt_count := 0
var _runtime_settings_save_attempt_count := 0
var _runtime_settings_save_success_count := 0
var _runtime_settings_transaction_count := 0
var _runtime_settings_commit_serial := 0
var _runtime_settings_last_commit_id := ""
var _runtime_settings_unsaved_changes := false
var _runtime_settings_transaction_active := false
## Prevent a settings hydration/re-entry apply from becoming a fresh player
## preference write through the PlayerController signal.
var _applying_on_foot_camera_preference := false
var _runtime_settings_reentrant_rejection_count := 0
var _runtime_settings_repair_request_active := false
## A verified repair resolves the retained startup receipt for the rest of this
## process. The receipt remains useful diagnostics, but must not reopen a stale
## recovery notice after the repaired store advances to its next generation.
var _runtime_settings_repair_resolved := false
var _session_diagnostics_bridge: SessionDiagnosticLifecycleBridge
var _session_diagnostics_record: SessionDiagnosticRecord
var _session_diagnostics_last_status: Dictionary = {}
var _session_diagnostics_filesystem: UserDataFilesystem
var _session_diagnostics_session_id := 0
var _session_diagnostics_physics_tick := 0
var _session_diagnostics_elapsed_physics_seconds := 0.0
var _session_diagnostics_runtime_mode := 0
var _session_diagnostics_persist_pending := false
var _session_diagnostics_clean_observation_recorded := false
var _session_recovery_command_status: Dictionary = {}
var _session_recovery_hud_status: Dictionary = {}
var _session_recovery_support_export_token := 0
var _session_recovery_support_export_generation := 0
const SESSION_DIAGNOSTIC_SUPPORT_EXPORT_ROOT := "user://diagnostics/exports"
var _safe_start_recovery_published_generation := -1
var _safe_start_recovery_published_revision := -1
var _safe_start_recovery_published_material: Dictionary = {}
var _safe_start_recovery_dismissed_generation := -1
var _safe_start_recovery_hud_status: Dictionary = {}
var _runtime_settings_apply_count := 0
var _runtime_settings_first_apply_followed_load := false
var _pending_display_confirmation: Dictionary = {}
var _display_confirmation_generation := 0
var _runtime_settings_persistence_injected := false
## Retained safe-start composition over the exact same process-lifetime store.
var _safe_start_production_recovery: SafeStartProductionRecovery
## Authored chase-boom lag per ship, captured before reduced motion ever damps
## it, so turning the preset back off restores the exact authored feel.
var _authored_chase_camera_lag: Dictionary = {}
var ships: Array[HeroShip] = []
var _production_registry_refresh_queued := false
## The station's one drivable ground vehicle, resolved from the world subtree
## rather than a global group so a second world instance in a test cannot be
## mistaken for this one. It is never appended to `ships`.
var tow_tractor: TowTractor
var active_ship: HeroShip
var boarding_candidate: HeroShip
var station_interaction_candidate: Node3D
var _boarding_area: ShipBoardingArea
var _reboard_blocked_ship: HeroShip
var _guided_activity_complete := false
## Destroying the guided defender authorizes the return leg, but is not itself
## completion. This latch survives landing and shutdown, then is consumed only
## after the same pilot finishes the generation-guarded physical disembark.
var _guided_return_ready_for_completion := false
## A planetary return receipt is terminal only after GameFlow verifies the live
## station berth.  This latch prevents a detached/replayed receipt from
## re-entering the ordinary yard shutdown path.
var _planetary_return_receipt_consumed := false
var _planetary_return_persistence_binding: Object
const PLANETARY_RETURN_PERSISTENCE_SLOT: StringName = &"ember_planetary_return"
var _ember_relay_survey_persistence_binding: Object
const EMBER_RELAY_SURVEY_PERSISTENCE_SLOT: StringName = \
	&"ember_relay_survey_completion"
const CINDER_RACE_BEST_PERSISTENCE_SLOT: StringName = &"cinder_race_best_result"
const CINDER_SCAN_DISCOVERY_PERSISTENCE_SLOT: StringName = &"cinder_scan_discovery"
const CINDER_CARGO_DELIVERY_PERSISTENCE_SLOT: StringName = &"cinder_cargo_delivery"
const CINDER_MINING_CAPACITY_PERSISTENCE_SLOT: StringName = &"cinder_mining_capacity"
const CINDER_CONVOY_ARRIVAL_PERSISTENCE_SLOT: StringName = &"cinder_convoy_safe_arrival"
const PLANETARY_RETURN_RETIRE_COMMIT_PREFIX := "planetary-return-retire-"
const PLANETARY_RETURN_RETIRE_MAX_STORE_GENERATION := 2_147_483_647
var _planetary_return_startup_restore_receipt: Dictionary = {}
var _planetary_return_startup_retirement_result: Dictionary = {}
var _planetary_return_startup_retirement_store_generation := -1
var _planetary_return_startup_retirement_commit_id := ""
var _planetary_return_startup_retirement_pending := false
var _planetary_return_startup_retired := false
var _sandbox_sortie := false
## A parked craft begins with `landed == true`. Free-flight return handling must
## not interpret that initial state as a completed sortie before the first
## thrust tick. This latch becomes true once the craft physically clears its
## home transform and remains true until the next boarding lifecycle.
var _sortie_departed_berth := false
var _landing_request_active := false
## The berth whose strict physical contract currently owns landing assist. The
## identifier is cleared on completion, rejection, abort, or destructive recall
## so no stale reservation can leak into a later sortie.
var _active_landing_berth_id: StringName = &""
var _recovering := false
var _regeneration_pending: Dictionary = {}
## Synchronous berth signals may call back into the coordinator. One ship may
## own only one preflight/reserve/commit attempt at a time.
var _regeneration_attempts_active: Dictionary = {}
## Held only across the accepted ship commit. Reset signals may synchronously
## reach ordinary landing/departure cleanup, but they cannot release the exact
## lease that makes the regenerated physical hull safe to reveal.
var _regeneration_lease_guarded_instance_ids: Dictionary = {}
var _berth_tokens: Dictionary = {}
var _reserved_berth_ids: Dictionary = {}
var _last_player_shot_result: Dictionary = {}
var _last_opponent_shot_result: Dictionary = {}
## Receipt-keyed audio metadata captured at authoritative damage time. Gameplay
## state is already final; this only lets the authored positional cue start at
## the same endpoint/ship pose as the delayed impact or destruction art.
var _pending_combat_audio_receipts: Dictionary = {}
var _initialized := false
## The craft whose cabin the player is currently walking under way, or null.
## Occupancy itself stays owned by that craft's `MovingInteriorFrame`; this is
## only the coordinator's record of which craft the current phase belongs to.
var _cabin_ship: HeroShip
var _last_lifecycle_command_ship_instance_id := 0
var _last_lifecycle_command_stream_id := -1
var _last_lifecycle_command_sequence := -1
## Startup that a boot loader drives. Off by default and never latched by a
## detach, so a directly instantiated Main - every test, and every re-entry -
## builds synchronously in `_ready()` exactly as before.
var _startup_stager: MainStartupStagerType
## The adapter generation expected by timing and position submissions from the
## current physical sortie. GameFlow copies it from the session and never
## invents one.
var _active_activity_id: StringName = &""
var _active_activity_generation := 0
## Activity kind is selected independently from the shared director route ID.
## Selection locks on the first accepted start because both typed adapters keep
## private generation history over that one route and cannot safely alternate.
var _selected_activity_kind: StringName = ACTIVITY_KIND_TIMED_RACE
var _activity_selection_locked := false
var _cinder_race_session_persistence: CinderRaceSessionPersistence
var _cinder_race_session_restore_attempted := false
var _cinder_race_session_restore_status: Dictionary = {}
var _cinder_race_session_save_status: Dictionary = {}
var _cinder_race_session_saved_fingerprint := ""
var _cinder_patrol_session_persistence: CinderPatrolSessionPersistence
var _cinder_patrol_session_restore_attempted := false
var _cinder_patrol_session_restore_status: Dictionary = {}
var _cinder_patrol_session_save_status: Dictionary = {}
var _cinder_patrol_session_saved_fingerprint := ""
## Diagnostic only: exactly one increment accompanies each production physics
## position sample, proving no second adapter or retired director sampler is live.
var _cinder_position_sample_count := 0
## Counts the one actor world-position read performed for each production
## physics tick. Cinder, Ember, and convoy consume the same detached sample.
var _cinder_actor_sample_count := 0
var _convoy_stream_instance_id := 0
var _convoy_stream_generation := -1
var _convoy_active_ship_instance_id := 0
var _convoy_terminal_reason: StringName = &""
var _convoy_last_player_position := Vector3.ZERO
var _convoy_has_player_sample := false
var _cargo_delivery_physics_step_count := 0
var _cargo_delivery_source_ship: HeroShip
var _cargo_delivery_destination: JovianFreightBerth
var _cargo_delivery_source_handle: Dictionary = {}
var _cargo_delivery_destination_handle: Dictionary = {}
## One process-lifetime physics serial for the already captured shared actor
## observation. The cruise binding rejects duplicate/replayed serials rather
## than minting more than one envelope for a HeroShip physics tick.
var _planetary_cruise_caller_tick := 0
## Last request serial accepted from the one retained HUD. Replayed signals and
## duplicate connections cannot toggle production state twice, and the value
## survives whole-Main detach/re-entry with the HUD's matching serial.
var _last_hud_planetary_cruise_toggle_serial := 0
var _planetary_cruise_hud_toggle_active := false
var _ember_surface_caller_serial := 0
var _pending_ember_surface_request: Dictionary = {}
var _pending_ember_surface_host: Object
var _pending_ember_surface_director: ActivityDirector
var _pending_ember_surface_reward_sink := Callable()
var _pending_ember_surface_serial := 0
var _last_ember_surface_forward_result: Dictionary = {}
var _ember_surface_forward_count := 0
var _ember_surface_journey_active := false
var _ember_service_repair_authority: RepairAuthority
var _ember_service_repair_context: Dictionary = {}
var _ember_final_approach_handoff_ready := false
var _ember_final_approach_completion_receipt: Dictionary = {}
## The surface scheduler owns the one atomic command-source handback. These
## latches only prevent GameFlow from consuming or replaying it twice before the
## caller-driven cruise binding reaches the existing station return lifecycle.
var _mudds_return_handback_consumption_attempted := false
var _mudds_return_handback_receipt: Dictionary = {}
## The retained surface binding publishes this while its Host/session attachment
## is still live. GameFlow takes and authenticates it on the next caller tick,
## before the Host's atomic ownership return can retire that attachment.
var _mudds_station_return_intent_consumption_attempted := false
var _mudds_station_return_intent_receipt: Dictionary = {}
var _last_mudds_station_return_intent_result: Dictionary = {}
var _mudds_return_approach_active := false
var _mudds_return_approach_completion_attempted := false
var _mudds_return_approach_completion_receipt: Dictionary = {}
var _last_mudds_return_approach_result: Dictionary = {}
## A completed Ember brake-shell handoff must finish through the exact physical
## home-berth landing it armed. These latches prevent the ordinary yard fallback
## from accepting a stale landing after abort, destruction, detach, or replay.
var _planetary_return_physical_arrival_required := false
var _planetary_return_physical_arrival_armed := false
var _last_planetary_return_physical_arrival_result: Dictionary = {}
## Station topology is captured in ShipyardWorld-local coordinates. A common
## floating-origin rebase can then translate the live world root without leaving
## the presentation snapshot pinned to its pre-rebase global coordinates.
var _minimap_topology_nodes_local: Array[Dictionary] = []
var _minimap_topology_edges: Array[Dictionary] = []


func _enter_tree() -> void:
	# A whole Main subtree can be streamed out and re-added without being freed.
	# Source `tree_exiting` hooks intentionally clear combat authority state, but
	# Godot does not call `_ready()` again. Restore only runtime bindings after all
	# descendants have re-entered; gameplay startup and world construction remain
	# one-time operations.
	if _initialized:
		call_deferred("_restore_runtime_bindings_after_reentry")


func _exit_tree() -> void:
	_detach_first_sortie_tutorial_presentation(&"game_flow_detached")
	if _planetary_return_physical_arrival_armed:
		_abort_planetary_return_physical_arrival(&"return_main_detached")
		_landing_request_active = false
		_active_landing_berth_id = &""
	if _mudds_return_approach_active \
			and not _mudds_return_approach_completion_attempted:
		_mudds_return_approach_active = false
		_ember_surface_journey_active = false
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_main_detached",
		}.duplicate(true)
	if not _pending_ember_surface_request.is_empty():
		cancel_ember_surface_journey()
	if not _pending_display_confirmation.is_empty() and runtime_settings != null:
		_revert_display_settings(int(_pending_display_confirmation.generation), &"detach")
	if _runtime_settings_repair_binding != null:
		_runtime_settings_repair_binding.set_attached(false)
	if is_instance_valid(hud) and hud.has_method(&"clear_runtime_settings_repair_report"):
		hud.clear_runtime_settings_repair_report()
	_clear_bomber_payload_loop(&"game_flow_exit")
	_clear_bomber_payload_replica_presentation()
	if is_queued_for_deletion():
		_detach_fleet_expansion_for_shutdown()
	_cancel_station_seat_for_detach()
	if is_instance_valid(network_session):
		network_session.shutdown(&"game_flow_exit")
		network_session = null
	_detach_network_ship_authority_composition(&"game_flow_exit")
	_detach_network_halyard_command_bridge()
	_cancel_ground_transition_for_detach()
	# A retained Main keeps this exact RefCounted session, while a shift reload may
	# free it after the same lifecycle boundary. Capture the caller-physics clock
	# before disconnecting either case; ordinary detach is not treated as orderly
	# process shutdown and does not touch either recovery marker.
	save_cinder_race_session()
	save_cinder_patrol_session()
	_detach_cinder_race_session()
	_detach_cinder_loadmaster_hud_binding()
	_detach_final_approach_hud_composition()
	_detach_caption_presentation()
	_detach_nearby_activity_audio()
	_detach_ember_surface_presentations()
	_detach_optional_semantic_audio()
	_detach_halyard_crew_semantic_audio()
	_detach_fleet_ship_semantic_audio()
	# Travelling pulse slots are presentation-only and are cleared by their own
	# exit transaction. Their target-side records are likewise invalidated by the
	# relevant lifecycle components.
	for fleet_ship in ships:
		if is_instance_valid(fleet_ship) and fleet_ship.has_method(&"discard_deferred_damage_presentations"):
			fleet_ship.call(&"discard_deferred_damage_presentations")
	if is_instance_valid(opponent) and opponent.has_method(&"discard_deferred_damage_presentations"):
		opponent.call(&"discard_deferred_damage_presentations")
	if is_instance_valid(world) and world.has_method(&"discard_deferred_damage_presentations"):
		world.call(&"discard_deferred_damage_presentations")

	# Do not carry coordinator metadata across a streamed whole-Main detach: no
	# transient effect is resurrected on re-entry.
	_pending_combat_audio_receipts.clear()

	# Leaving the tree is leaving gameplay. Whatever owned the cursor, the player
	# gets it back: a detached Main has no camera to steer, and the reload behind
	# `_restart_shift()` goes through here on its way to the loading screen.
	release_mouse_capture()


## The expansion binding retains RefCounted audio compositions whose payload
## presenters are deliberately unparented Nodes. A streamed Main keeps those
## compositions for re-entry, but final Main deletion must close their explicit
## lifecycle before the owning dictionaries disappear.
func _detach_fleet_expansion_for_shutdown() -> void:
	if not is_instance_valid(world) \
			or not world.has_method(&"get_fleet_expansion_production_binding"):
		return
	var expansion_binding := (
		world.call(&"get_fleet_expansion_production_binding") as Node
	)
	if not is_instance_valid(expansion_binding) \
			or not expansion_binding.has_method(&"detach_craft"):
		return
	# These are the binding's fixed authored composition IDs, not GameFlow's
	# public ship IDs. Calling detach on an already released craft fails closed.
	for craft_id: StringName in [
		&"cinder_cargo_hauler",
		&"cinder_long_range_bomber",
		&"cinder_light_interceptor",
	]:
		expansion_binding.call(&"detach_craft", craft_id)


## Returns the cursor to the desktop. Safe to call from any state, and a no-op
## under `--headless`, where `Input.mouse_mode` has nothing to address.
func release_mouse_capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Explicit multiplayer entry point. Solo startup remains offline because this
## method is never called by `_ready()` or the boot loader.
func host_network_session(
	port: int = NetworkSessionAdapterType.DEFAULT_PORT,
	max_clients: int = NetworkSessionAdapterType.DEFAULT_MAX_CLIENTS
) -> Dictionary:
	var session := _ensure_network_session()
	if session == null:
		return {"accepted": false, "status": &"game_flow_not_in_tree"}
	_network_session_mode = &"server"
	_set_station_defense_network_presentation_only(false)
	_network_session_port = port
	_network_session_max_clients = max_clients
	var result := session.host(port, max_clients)
	_publish_network_session_result(result, &"server")
	return result


func join_network_session(
	address: String = "127.0.0.1",
	port: int = NetworkSessionAdapterType.DEFAULT_PORT
) -> Dictionary:
	var session := _ensure_network_session()
	if session == null:
		return {"accepted": false, "status": &"game_flow_not_in_tree"}
	_network_session_mode = &"client"
	_set_station_defense_network_presentation_only(true)
	_network_session_address = address
	_network_session_port = port
	var result := session.join(address, port)
	_publish_network_session_result(result, &"client")
	return result


func shutdown_network_session(reason: StringName = &"requested") -> Dictionary:
	if not is_instance_valid(network_session):
		return {"accepted": false, "status": &"not_started"}
	var result := network_session.shutdown(reason)
	_publish_network_session_snapshot(&"disconnected", _network_session_mode, "Session closed: %s" % reason, true)
	return result


func get_network_session() -> NetworkSessionAdapterType:
	return network_session


func _ensure_network_session() -> NetworkSessionAdapterType:
	if not is_inside_tree():
		return null
	if is_instance_valid(network_session):
		return network_session
	network_session = NetworkSessionAdapterType.new()
	network_session.name = "NetworkSession"
	add_child(network_session)
	_connect_signal_once(network_session, &"session_started", _on_network_session_started)
	_connect_signal_once(network_session, &"session_stopped", _on_network_session_stopped)
	_connect_signal_once(network_session, &"peer_admitted", _on_network_peer_admitted)
	_connect_signal_once(network_session, &"peer_disconnected", _on_network_peer_disconnected)
	_connect_signal_once(network_session, &"transport_rejected", _on_network_transport_rejected)
	_connect_signal_once(network_session, &"crew_role_result", _on_network_crew_role_result)
	_connect_signal_once(network_session, &"crew_command_result", _on_network_crew_command_result)
	_connect_signal_once(network_session, &"projectile_replica_packet", _on_projectile_replica_packet)
	_connect_signal_once(network_session, &"migration_result", _on_network_migration_result)
	_connect_signal_once(network_session, &"server_browser_result", _on_server_browser_result)
	_attach_network_halyard_command_bridge()
	_attach_network_ship_authority_composition()
	return network_session


func _attach_network_ship_authority_composition() -> Dictionary:
	if not is_instance_valid(network_session) or not is_instance_valid(active_ship):
		return {"accepted": false, "status": &"network_or_ship_unavailable"}
	if _network_ship_authority_composition == null:
		_network_ship_authority_composition = NetworkShipAuthorityCompositionType.new()
		_network_ship_authority_composition.name = "NetworkShipAuthorityComposition"
		add_child(_network_ship_authority_composition)
		_connect_signal_once(
			_network_ship_authority_composition,
			&"cinder_navigator_ping_result_forwarded",
			_on_cinder_navigator_ping_result_forwarded
		)
		_connect_signal_once(
			_network_ship_authority_composition,
			&"cinder_navigator_ping_tombstones_forwarded",
			_on_cinder_navigator_ping_tombstones_forwarded
		)
	if _network_composition_ship == active_ship:
		_sync_cinder_navigator_presentations()
		return {"accepted": true, "status": &"already_attached", "ship_generation": _network_ship_generation}
	# A replacement must retire the old generation while its Cinder assignment is
	# still the presentation authority. NetworkShipAuthorityComposition.attach()
	# also defensively detaches, but waiting until that call would advance the
	# GameFlow generation first and make the old tombstone look stale.
	if _network_composition_ship != null:
		_detach_network_ship_authority_composition(&"replacement")
	if _network_ship_generation >= NETWORK_MAX_SAFE_GENERATION:
		return {"accepted": false, "status": &"generation_exhausted", "ship_generation": _network_ship_generation}
	_network_ship_generation += 1
	var result := _network_ship_authority_composition.attach(
		 network_session, active_ship, _network_ship_generation
	)
	if bool(result.get("accepted", false)):
		_network_composition_ship = active_ship
		_network_ship_event_sequence = 0
		_sync_cinder_navigator_presentations()
	else:
		_unbind_cinder_navigator_presentations()
	return result


func _detach_network_ship_authority_composition(reason: StringName = &"detached") -> Dictionary:
	_network_ship_event_sequence = 0
	for shot_id_variant: Variant in _player_pulse_network_active_shots.keys():
		_terminalize_player_pulse_network_shot(int(shot_id_variant), &"abort")
	if _network_ship_authority_composition == null:
		_network_composition_ship = null
		_unbind_cinder_navigator_presentations()
		return {"accepted": true, "status": &"already_detached"}
	# Detach emits its final real tombstone synchronously while the old Cinder
	# assignment and generation are still the presentation authorities.
	var result: Dictionary = _network_ship_authority_composition.detach(reason)
	_network_composition_ship = null
	_unbind_cinder_navigator_presentations()
	return result


func _attach_network_halyard_command_bridge() -> Dictionary:
	if not is_instance_valid(network_session) or not is_instance_valid(active_ship):
		return {"accepted": false, "status": &"network_or_ship_unavailable"}
	if not active_ship.has_method(&"submit_crew_intent") \
		or not active_ship.has_method(&"get_crew_role_authority"):
		return {"accepted": false, "status": &"halyard_unavailable"}
	if _network_halyard_command_bridge == null:
		_network_halyard_command_bridge = NetworkHalyardCrewCommandBridgeType.new(1)
	var result: Dictionary = _network_halyard_command_bridge.attach(network_session, active_ship)
	if bool(result.get("accepted", false)):
		_connect_signal_once(
			active_ship, &"loadmaster_manifest_intent_accepted",
			Callable(self, "_on_halyard_loadmaster_manifest_accepted")
		)
	return result


func _detach_network_halyard_command_bridge() -> Dictionary:
	if is_instance_valid(active_ship) and active_ship.has_signal(&"loadmaster_manifest_intent_accepted"):
		var callback := Callable(self, "_on_halyard_loadmaster_manifest_accepted")
		if active_ship.is_connected(&"loadmaster_manifest_intent_accepted", callback):
			active_ship.disconnect(&"loadmaster_manifest_intent_accepted", callback)
	if _network_halyard_command_bridge == null:
		return {"accepted": true, "status": &"already_detached"}
	var result: Dictionary = _network_halyard_command_bridge.detach()
	_network_halyard_command_bridge = null
	return result


func _on_halyard_loadmaster_manifest_accepted(receipt: Dictionary) -> void:
	if _network_session_mode != &"server" or not is_instance_valid(network_session):
		return
	if not bool(receipt.get("ready", false)) or int(receipt.get("manifest_generation", 0)) <= 0:
		return
	var manifest := {
		"manifest_generation": int(receipt.get("manifest_generation", 0)),
		"terminal_generation": 1,
		"state": &"route_ready",
		"source_id": &"halyard_loadmaster_manifest",
		"destination_id": &"halyard_freight_berth",
		"berth_id": &"crew_port_00",
		"quantity": 1,
		"role": &"loadmaster",
		"seat_id": receipt.get("seat_id", &"crew_port_00"),
		"occupant_peer_id": int(receipt.get("occupant_peer_id", 0)),
		"occupant_avatar_id": receipt.get("avatar_id", &""),
		"manifest_id": receipt.get("manifest_id", &""),
		"route_id": receipt.get("route_id", &""),
		"ready": true,
		"inventory_mutation_authority": false,
		"reward_authority": false,
		"helm_authority": false,
	}
	if network_session.has_method(&"publish_cargo_manifest_snapshot"):
		network_session.publish_cargo_manifest_snapshot(manifest)


func _ready() -> void:
	if _initialized:
		_restore_runtime_bindings_after_reentry()
		return
	if _startup_stager != null and _startup_stager.is_prepared():
		# A boot loader holds the authored children and will call
		# `run_staged_startup()` once they are all back in the tree.
		return
	_resolve_scene_bindings()
	_start_up()


## Binds the authored Main children. Idempotent, and the single place the
## coordinator learns what its subtree contains.
func _resolve_scene_bindings() -> void:
	world = get_node_or_null(^"ShipyardWorld") as Node3D
	player = get_node_or_null(^"Player") as CharacterBody3D
	activity_board_console = (
		world.call(&"get_activity_board_console") as Area3D
		if is_instance_valid(world) and world.has_method(&"get_activity_board_console")
		else null
	)
	ship = get_node_or_null(^"TorrentInterceptor") as HeroShip
	opponent = get_node_or_null(^"RangeOpponent") as CharacterBody3D
	combat_authority = get_node_or_null(^"CombatAuthority") as LiveCombatAuthorityType
	pulse_presentation = get_node_or_null(^"PulseWeaponPresentation") as PulseWeaponPresentation
	combat_audio = get_node_or_null(^"CombatAudioPresentation") as CombatAudioPresentation
	hud = get_node_or_null(^"HUD") as CanvasLayer
	audio = get_node_or_null(^"AudioDirector")
	music_bed = get_node_or_null(^"StationMusicBed") as StationMusicBed
	activity_director = get_node_or_null(^"ActivityDirector") as ActivityDirector
	cinder_convoy_host = get_node_or_null(^"CinderConvoyEscortHost") as CinderConvoyEscortHost
	cinder_streaming_bootstrap = (
		get_node_or_null(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	)
	cinder_streaming_binding = (
		get_node_or_null(^"CinderStreamingProductionBinding")
		as CinderStreamingProductionBinding
	)
	cinder_streaming_coordinator = (
		cinder_streaming_bootstrap.get_node_or_null(^"WorldStreamingCoordinator")
		as WorldStreamingCoordinator
		if is_instance_valid(cinder_streaming_bootstrap)
		else null
	)
	ember_streaming_bootstrap = (
		get_node_or_null(^"EmberMoonStreamingBootstrap")
		as EmberMoonStreamingBootstrap
	)
	ember_streaming_binding = (
		get_node_or_null(^"EmberMoonStreamingProductionBinding")
		as EmberMoonStreamingProductionBinding
	)
	ember_surface_loop_production_binding = (
		get_node_or_null(^"EmberSurfaceLoopProductionBinding")
		as EmberSurfaceLoopProductionBinding
	)
	ember_surface_loop_host = (
		get_node_or_null(^"EmberSurfaceLoopHost") as EmberSurfaceLoopHost
	)
	ember_surface_berth = (
		get_node_or_null(^"EmberSurfaceBerth") as EmberSurfaceBerth
	)
	common_world_origin_rebase_owner = (
		get_node_or_null(^"CommonWorldOriginRebaseOwner")
		as CommonWorldOriginRebaseOwner
	)
	planetary_cruise_binding = (
		get_node_or_null(^"PlanetaryCruiseProductionBinding")
		as PlanetaryCruiseProductionBinding
	)
	if (
		not _initialized
		and is_instance_valid(cinder_streaming_binding)
		and not bool(cinder_streaming_binding.get_snapshot().get("activated", false))
	):
		cinder_streaming_binding.configure_caller_sample_mode()


## Composes one deterministic modern delivery over the production Jovian and
## its published freight berth. The two real nodes own identity/lifecycle only;
## every quantity and transfer remains inside CargoTransferAuthority.
func _initialize_cargo_delivery_composition() -> void:
	if cargo_transfer_authority == null:
		cargo_transfer_authority = CargoTransferAuthority.new()
		cargo_transfer_authority.name = "CargoTransferAuthority"
		add_child(cargo_transfer_authority)
	if cargo_delivery_activity != null:
		_restore_cargo_delivery_bindings()
		return
	_cargo_delivery_source_ship = _find_flyable_ship_by_id(&"jovian_provisional")
	_cargo_delivery_destination = (
		world.call(&"get_jovian_freight_berth") as JovianFreightBerth
		if is_instance_valid(world) and world.has_method(&"get_jovian_freight_berth")
		else null
	)
	if (
		not is_instance_valid(_cargo_delivery_source_ship)
		or not is_instance_valid(_cargo_delivery_destination)
		or _cargo_delivery_destination.get_berth_id() != &"jovian_freight_berth"
	):
		return
	var item := CargoItemDefinition.new()
	item.item_id = CARGO_DELIVERY_ITEM_ID
	item.display_name = CARGO_DELIVERY_ITEM_DISPLAY_NAME
	item.unit_capacity = 1
	var item_registration := cargo_transfer_authority.register_item(item)
	if not bool(item_registration.get("accepted", false)):
		return
	var source_registration := cargo_transfer_authority.register_entity(
		_cargo_delivery_source_ship,
		_cargo_delivery_source_ship.get_ship_id(),
		CARGO_DELIVERY_SOURCE_MANIFEST_ID,
		CARGO_DELIVERY_SOURCE_CAPACITY,
		{CARGO_DELIVERY_ITEM_ID: CARGO_DELIVERY_SOURCE_INITIAL_QUANTITY}
	)
	if not bool(source_registration.get("accepted", false)):
		return
	var destination_registration := cargo_transfer_authority.register_entity(
		_cargo_delivery_destination,
		_cargo_delivery_destination.get_berth_id(),
		CARGO_DELIVERY_DESTINATION_MANIFEST_ID,
		CARGO_DELIVERY_DESTINATION_CAPACITY
	)
	if not bool(destination_registration.get("accepted", false)):
		cargo_transfer_authority.retire_entity(
			source_registration.get("handle", {}) as Dictionary
		)
		return
	_cargo_delivery_source_handle = (
		source_registration.get("handle", {}) as Dictionary
	).duplicate(true)
	_cargo_delivery_destination_handle = (
		destination_registration.get("handle", {}) as Dictionary
	).duplicate(true)
	var contract := CargoDeliveryContract.new(
		CARGO_DELIVERY_ACTIVITY_ID,
		_cargo_delivery_source_handle,
		_cargo_delivery_destination_handle,
		CARGO_DELIVERY_ITEM_ID,
		CARGO_DELIVERY_QUANTITY,
		CARGO_DELIVERY_PHASES,
		CARGO_DELIVERY_DEADLINE_SECONDS
	)
	cargo_delivery_activity = CargoDeliveryActivity.new(
		cargo_transfer_authority,
		contract
	)
	cargo_delivery_activity.started.connect(_on_cargo_delivery_snapshot_changed)
	cargo_delivery_activity.phase_advanced.connect(
		_on_cargo_delivery_snapshot_changed
	)
	cargo_delivery_activity.failed.connect(_on_cargo_delivery_snapshot_changed)
	cargo_delivery_activity.expired.connect(_on_cargo_delivery_snapshot_changed)
	cargo_delivery_activity.activity_reset.connect(
		_on_cargo_delivery_snapshot_changed
	)
	cargo_delivery_activity.completed.connect(_on_cargo_delivery_completed)


func _restore_cargo_delivery_bindings() -> bool:
	if (
		cargo_transfer_authority == null
		or cargo_delivery_activity == null
		or not cargo_transfer_authority.is_inside_tree()
	):
		return false
	# The authority owns the complete two-record transaction. In particular, its
	# first post-state signal cannot strand one attached manifest by synchronously
	# removing the second physical owner before a later scalar reattach.
	var restored := cargo_transfer_authority.reattach_entity_pair(
		_cargo_delivery_source_ship,
		_cargo_delivery_source_handle,
		_cargo_delivery_destination,
		_cargo_delivery_destination_handle
	)
	return bool(restored.get("accepted", false))


func _find_flyable_ship_by_id(ship_id: StringName) -> HeroShip:
	for fleet_ship: HeroShip in ships:
		if is_instance_valid(fleet_ship) and fleet_ship.get_ship_id() == ship_id:
			return fleet_ship
	return null


## Owns one lifetime-stable adapter of each supported presentation kind, while
## attaching only the selected one to the single shared director route. The
## selected adapter is detached rather than discarded when Main leaves the tree,
## so re-entry preserves its clock, progress, results, and identity.
func _initialize_cinder_race_session() -> void:
	if cinder_race_session == null:
		cinder_race_session = CinderTimedRaceSession.new(
			CINDER_RACE_LAPS,
			CINDER_RACE_COUNTDOWN_SECONDS,
			CINDER_RACE_TIMEOUT_SECONDS
		)
		cinder_race_session.presentation_changed.connect(
			_on_cinder_session_presentation_changed
		)
		cinder_race_session.session_completed.connect(_on_cinder_session_completed)
	if patrol_activity == null:
		var route := activity_director.get_definition(DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
		patrol_activity = PatrolActivity.new(route, CINDER_PATROL_DWELL_SECONDS)
		patrol_activity.presentation_changed.connect(
			_on_patrol_presentation_changed
		)
		patrol_activity.patrol_completed.connect(_on_patrol_completed)
	_initialize_cinder_race_session_persistence()
	_initialize_cinder_patrol_session_persistence()
	_restore_cinder_race_session()


func _initialize_cinder_race_session_persistence() -> void:
	if _cinder_race_session_persistence == null \
			and _runtime_settings_user_data_store != null:
		_cinder_race_session_persistence = CinderRaceSessionPersistenceType.new()
		var configured := _cinder_race_session_persistence.configure(
			_runtime_settings_user_data_store,
			CINDER_RACE_SESSION_PERSISTENCE_SLOT
		)
		if not bool(configured.get("accepted", false)):
			_cinder_race_session_save_status = configured.duplicate(true)
			_cinder_race_session_persistence = null
			return
	if _cinder_race_session_restore_attempted \
			or _cinder_race_session_persistence == null \
			or cinder_race_session == null \
			or not is_instance_valid(activity_director):
		return
	_cinder_race_session_restore_attempted = true
	var loaded := _cinder_race_session_persistence.load(
		cinder_race_session, activity_director
	)
	_cinder_race_session_restore_status = loaded.duplicate(true)
	if not bool(loaded.get("accepted", false)):
		return
	var restored := cinder_race_session.restore_persistence_state(
		activity_director,
		loaded.get("session_state", {}),
		cinder_race_session.get_session_generation()
	)
	_cinder_race_session_restore_status = restored.duplicate(true)
	_cinder_race_session_restore_status["store_generation"] = int(
		loaded.get("store_generation", -1)
	)
	if not bool(restored.get("accepted", false)):
		return
	var snapshot := cinder_race_session.get_presentation_snapshot()
	_active_activity_id = DEFAULT_FREE_FLIGHT_ACTIVITY_ID
	_active_activity_generation = int(snapshot.get("session_generation", 0))
	_activity_selection_locked = true
	_cinder_race_session_saved_fingerprint = _cinder_race_save_fingerprint(snapshot)


## Explicit save surface used by orderly shutdown and meaningful session
## boundaries. It merges into GameFlow's one loaded UserDataStore and never
## advances the race, route, or a save-owned clock.
func save_cinder_race_session() -> Dictionary:
	if _cinder_race_session_persistence == null \
			or cinder_race_session == null \
			or not is_instance_valid(activity_director):
		return {"accepted": false, "reason": &"race_session_persistence_unavailable"}
	var snapshot := cinder_race_session.get_presentation_snapshot()
	if int(snapshot.get("session_generation", 0)) < 1:
		return {"accepted": true, "reason": &"race_session_not_started"}
	var next_generation := _runtime_settings_user_data_store.get_generation() + 1
	if next_generation <= 0 or next_generation > UserDataStoreType.MAX_GENERATION:
		return {"accepted": false, "reason": &"race_session_commit_id_exhausted"}
	var commit_id := "%s%010d" % [
		CINDER_RACE_SESSION_COMMIT_PREFIX,
		next_generation,
	]
	_cinder_race_session_save_status = _cinder_race_session_persistence.save(
		cinder_race_session, activity_director, commit_id
	).duplicate(true)
	if bool(_cinder_race_session_save_status.get("accepted", false)):
		_cinder_race_session_saved_fingerprint = _cinder_race_save_fingerprint(
			snapshot
		)
		_runtime_settings_commit_serial = maxi(
			_runtime_settings_commit_serial,
			_runtime_settings_user_data_store.get_generation()
		)
		_sync_production_runtime_settings_state()
	return _cinder_race_session_save_status.duplicate(true)


func get_cinder_race_session_persistence_report() -> Dictionary:
	return {
		"schema_version": 1,
		"configured": _cinder_race_session_persistence != null,
		"store_instance_id": (
			_runtime_settings_user_data_store.get_instance_id()
			if _runtime_settings_user_data_store != null else 0
		),
		"shares_runtime_settings_store": true,
		"restore_attempted": _cinder_race_session_restore_attempted,
		"restore_status": _cinder_race_session_restore_status.duplicate(true),
		"last_save_status": _cinder_race_session_save_status.duplicate(true),
		"owns_clock": false,
		"owns_route": false,
		"owns_results": false,
	}.duplicate(true)


func _initialize_cinder_patrol_session_persistence() -> void:
	if _cinder_patrol_session_persistence == null \
			and _runtime_settings_user_data_store != null:
		_cinder_patrol_session_persistence = CinderPatrolSessionPersistenceType.new()
		var configured := _cinder_patrol_session_persistence.configure(
			_runtime_settings_user_data_store,
			CINDER_PATROL_SESSION_PERSISTENCE_SLOT
		)
		if not bool(configured.get("accepted", false)):
			_cinder_patrol_session_save_status = configured.duplicate(true)
			_cinder_patrol_session_persistence = null
			return
	if _cinder_patrol_session_restore_attempted \
			or _cinder_patrol_session_persistence == null \
			or patrol_activity == null or not is_instance_valid(activity_director):
		return
	_cinder_patrol_session_restore_attempted = true
	# The two typed activities intentionally share one route. A successfully
	# restored race already owns it, so a second saved owner is never adopted.
	if bool(_cinder_race_session_restore_status.get("accepted", false)):
		_cinder_patrol_session_restore_status = {
			"accepted": false,
			"reason": &"shared_route_already_restored",
		}.duplicate(true)
		return
	var loaded := _cinder_patrol_session_persistence.load(
		patrol_activity, activity_director
	)
	_cinder_patrol_session_restore_status = loaded.duplicate(true)
	if not bool(loaded.get("accepted", false)):
		return
	var restored := patrol_activity.restore_persistence_state(
		activity_director,
		loaded.get("patrol_state", {}),
		patrol_activity.get_generation()
	)
	_cinder_patrol_session_restore_status = restored.duplicate(true)
	_cinder_patrol_session_restore_status["store_generation"] = int(
		loaded.get("store_generation", -1)
	)
	if not bool(restored.get("accepted", false)):
		return
	var snapshot := patrol_activity.get_presentation_snapshot()
	_selected_activity_kind = ACTIVITY_KIND_PATROL
	_active_activity_id = DEFAULT_FREE_FLIGHT_ACTIVITY_ID
	_active_activity_generation = int(snapshot.get("generation", 0))
	_activity_selection_locked = true
	_cinder_patrol_session_saved_fingerprint = _cinder_patrol_save_fingerprint(snapshot)


func save_cinder_patrol_session() -> Dictionary:
	if _cinder_patrol_session_persistence == null \
			or patrol_activity == null or not is_instance_valid(activity_director):
		return {"accepted": false, "reason": &"patrol_session_persistence_unavailable"}
	var snapshot := patrol_activity.get_presentation_snapshot()
	if int(snapshot.get("generation", 0)) < 1:
		return {"accepted": true, "reason": &"patrol_session_not_started"}
	var next_generation := _runtime_settings_user_data_store.get_generation() + 1
	if next_generation <= 0 or next_generation > UserDataStoreType.MAX_GENERATION:
		return {"accepted": false, "reason": &"patrol_session_commit_id_exhausted"}
	var commit_id := "%s%010d" % [
		CINDER_PATROL_SESSION_COMMIT_PREFIX,
		next_generation,
	]
	_cinder_patrol_session_save_status = _cinder_patrol_session_persistence.save(
		patrol_activity, activity_director, commit_id
	).duplicate(true)
	if bool(_cinder_patrol_session_save_status.get("accepted", false)):
		_cinder_patrol_session_saved_fingerprint = _cinder_patrol_save_fingerprint(
			snapshot
		)
		_runtime_settings_commit_serial = maxi(
			_runtime_settings_commit_serial,
			_runtime_settings_user_data_store.get_generation()
		)
		_sync_production_runtime_settings_state()
	return _cinder_patrol_session_save_status.duplicate(true)


func get_cinder_patrol_session_persistence_report() -> Dictionary:
	return {
		"schema_version": 1,
		"configured": _cinder_patrol_session_persistence != null,
		"store_instance_id": (
			_runtime_settings_user_data_store.get_instance_id()
			if _runtime_settings_user_data_store != null else 0
		),
		"shares_runtime_settings_store": true,
		"restore_attempted": _cinder_patrol_session_restore_attempted,
		"restore_status": _cinder_patrol_session_restore_status.duplicate(true),
		"last_save_status": _cinder_patrol_session_save_status.duplicate(true),
		"owns_clock": false,
		"owns_route": false,
		"owns_actor": false,
	}.duplicate(true)


func _initialize_cinder_convoy_host() -> void:
	if not is_instance_valid(cinder_convoy_host):
		push_error("Main scene is missing its identity Cinder convoy host")
		return
	# The host owns state for the Main lifetime, but its visual is meaningful only
	# while the matching collision/location generation is resident.
	cinder_convoy_host.visible = false


func _restore_cinder_race_session(sync_hud: bool = true) -> void:
	if cinder_race_session == null or patrol_activity == null:
		_initialize_cinder_race_session()
		return
	# Defensive exclusivity: cargo owns no director route, and re-entry may restore
	# at most the one selected Cinder adapter.
	var race_snapshot := cinder_race_session.get_presentation_snapshot()
	var patrol_snapshot := patrol_activity.get_presentation_snapshot()
	if (
		_selected_activity_kind != ACTIVITY_KIND_TIMED_RACE
		and bool(race_snapshot.get("attached", false))
	):
		cinder_race_session.detach(cinder_race_session.get_session_generation())
	if (
		_selected_activity_kind != ACTIVITY_KIND_PATROL
		and bool(patrol_snapshot.get("attached", false))
	):
		patrol_activity.detach(patrol_activity.get_generation())
	if _selected_activity_kind == ACTIVITY_KIND_TIMED_RACE:
		if not bool(cinder_race_session.get_presentation_snapshot().get("attached", false)):
			cinder_race_session.attach(
				activity_director,
				cinder_race_session.get_session_generation()
			)
	elif _selected_activity_kind == ACTIVITY_KIND_PATROL:
		if not bool(patrol_activity.get_presentation_snapshot().get("attached", false)):
			patrol_activity.attach(
				activity_director,
				patrol_activity.get_generation()
			)
	elif _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_restore_cargo_delivery_bindings()
	if sync_hud:
		_sync_activity_hud()


func _detach_cinder_race_session() -> void:
	if cinder_race_session == null or patrol_activity == null:
		return
	if bool(cinder_race_session.get_presentation_snapshot().get("attached", false)):
		cinder_race_session.detach(cinder_race_session.get_session_generation())
	if bool(patrol_activity.get_presentation_snapshot().get("attached", false)):
		patrol_activity.detach(patrol_activity.get_generation())


## Creates exactly one service for this Main lifetime and binds the authored HUD
## as a request-only producer plus snapshot-only consumer.
func _initialize_caption_presentation() -> void:
	if _caption_presentation_service == null:
		_caption_presentation_service = CaptionPresentationServiceType.new()
	_restore_caption_presentation()


func _restore_caption_presentation() -> void:
	if _caption_presentation_service == null:
		_initialize_caption_presentation()
		return
	if not _caption_presentation_service.state_committed.is_connected(
		_on_caption_service_state_committed
	):
		_caption_presentation_service.state_committed.connect(
			_on_caption_service_state_committed
		)
	if is_instance_valid(hud) and hud.has_method(&"bind_caption_event_submitter"):
		hud.call(
			&"bind_caption_event_submitter",
			Callable(self, &"_submit_caption_request")
		)
	_sync_caption_presentation()


func _detach_caption_presentation() -> void:
	if is_instance_valid(hud) and hud.has_method(&"unbind_caption_event_submitter"):
		hud.call(
			&"unbind_caption_event_submitter",
			Callable(self, &"_submit_caption_request")
		)
	if (
		_caption_presentation_service != null
		and _caption_presentation_service.state_committed.is_connected(
			_on_caption_service_state_committed
		)
	):
		_caption_presentation_service.state_committed.disconnect(
			_on_caption_service_state_committed
		)


func _on_caption_service_state_committed(
		_reason: StringName,
		_state_snapshot: Dictionary
	) -> void:
	_sync_caption_presentation()


func _sync_caption_presentation() -> void:
	if (
		_caption_presentation_service == null
		or not is_instance_valid(hud)
		or not hud.has_method(&"apply_caption_presentation_snapshot")
	):
		return
	hud.call(
		&"apply_caption_presentation_snapshot",
		_caption_presentation_service.get_presentation_snapshot()
	)


## Sole request ingress from the HUD cue map. The HUD supplies scalar display
## intent; GameFlow creates the typed event and the service validates/copies it.
func _submit_caption_request(request: Dictionary) -> bool:
	_caption_request_count += 1
	if _caption_presentation_service == null:
		_caption_rejected_count += 1
		return false
	var category_id := StringName(request.get("category_id", &""))
	if not CAPTION_CATEGORY_BY_ID.has(category_id):
		_caption_rejected_count += 1
		return false
	_caption_event_serial += 1
	var event := CaptionPresentationEventType.new(
		StringName("caption:%08d" % _caption_event_serial),
		int(CAPTION_CATEGORY_BY_ID[category_id]) as CaptionPresentationEvent.Category,
		str(request.get("speaker", "")),
		str(request.get("text", "")),
		float(request.get("duration_physics_seconds", -1.0)),
		int(request.get("priority", -1))
	) as CaptionPresentationEvent
	var result := _caption_presentation_service.enqueue(event)
	if bool(result.get("accepted", false)):
		_caption_accepted_count += 1
		return true
	_caption_rejected_count += 1
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# The window manager's close request is explicit process-exit intent. It
		# may synchronously publish CLEAN_SHUTDOWN before SceneTree accepts the
		# quit; detach, free, and streaming notifications remain non-authoritative.
		mark_orderly_shutdown()
		return
	if what != NOTIFICATION_PREDELETE:
		return
	_detach_caption_presentation()
	_caption_presentation_service = null
	if cargo_delivery_activity != null:
		if cargo_delivery_activity.started.is_connected(
			_on_cargo_delivery_snapshot_changed
		):
			cargo_delivery_activity.started.disconnect(
				_on_cargo_delivery_snapshot_changed
			)
		if cargo_delivery_activity.phase_advanced.is_connected(
			_on_cargo_delivery_snapshot_changed
		):
			cargo_delivery_activity.phase_advanced.disconnect(
				_on_cargo_delivery_snapshot_changed
			)
		if cargo_delivery_activity.failed.is_connected(
			_on_cargo_delivery_snapshot_changed
		):
			cargo_delivery_activity.failed.disconnect(
				_on_cargo_delivery_snapshot_changed
			)
		if cargo_delivery_activity.expired.is_connected(
			_on_cargo_delivery_snapshot_changed
		):
			cargo_delivery_activity.expired.disconnect(
				_on_cargo_delivery_snapshot_changed
			)
		if cargo_delivery_activity.activity_reset.is_connected(
			_on_cargo_delivery_snapshot_changed
		):
			cargo_delivery_activity.activity_reset.disconnect(
				_on_cargo_delivery_snapshot_changed
			)
		if cargo_delivery_activity.completed.is_connected(
			_on_cargo_delivery_completed
		):
			cargo_delivery_activity.completed.disconnect(
				_on_cargo_delivery_completed
			)
		cargo_delivery_activity = null
	if cinder_race_session != null:
		if cinder_race_session.presentation_changed.is_connected(
			_on_cinder_session_presentation_changed
		):
			cinder_race_session.presentation_changed.disconnect(
				_on_cinder_session_presentation_changed
			)
		if cinder_race_session.session_completed.is_connected(_on_cinder_session_completed):
			cinder_race_session.session_completed.disconnect(_on_cinder_session_completed)
		var snapshot := cinder_race_session.get_presentation_snapshot()
		if not bool(snapshot.get("closed", false)):
			cinder_race_session.close(cinder_race_session.get_session_generation())
		cinder_race_session = null
	if patrol_activity != null:
		if patrol_activity.presentation_changed.is_connected(
			_on_patrol_presentation_changed
		):
			patrol_activity.presentation_changed.disconnect(
				_on_patrol_presentation_changed
			)
		if patrol_activity.patrol_completed.is_connected(_on_patrol_completed):
			patrol_activity.patrol_completed.disconnect(_on_patrol_completed)
		var patrol_snapshot := patrol_activity.get_presentation_snapshot()
		if not bool(patrol_snapshot.get("closed", false)):
			patrol_activity.close(patrol_activity.get_generation())
		patrol_activity = null


## Detaches the authored children so a boot loader can add them back one frame
## at a time instead of paying for all of them in a single main-loop iteration.
##
## Must be called while Main itself is outside the tree, which is where a loader
## has it: `PackedScene.instantiate()` does not enter the tree, so no `_ready()`
## has run and nothing is torn down here. Returns false - changing nothing - if
## the caller is too late, so the synchronous path stays the safe default.
func prepare_staged_startup() -> bool:
	return _get_startup_stager().prepare(_initialized)


## Longest a run of cheap children may hold the main loop before it yields. Six
## of the authored children cost a couple of milliseconds each, and a yield
## draws a whole frame, so they are batched; the heavy ones exceed the budget on
## their own and yield immediately after.
const STAGED_STARTUP_FRAME_BUDGET_USEC := (
	MainStartupStagerType.STAGED_STARTUP_FRAME_BUDGET_USEC
)


## Re-adds the authored children a frame at a time, letting any of them that owns
## a staged builder run it, and then performs the ordinary gameplay startup.
##
## `on_stage` is called as `on_stage.call(label: String, ratio: float)` where
## `ratio` is the fraction of real stages that have finished.
func run_staged_startup(on_stage: Callable = Callable()) -> void:
	if _startup_stager == null:
		return
	await _startup_stager.run(_initialized, on_stage)


func _get_startup_stager() -> MainStartupStagerType:
	if _startup_stager == null:
		_startup_stager = MainStartupStagerType.new(
			self,
			Callable(self, &"_resolve_scene_bindings"),
			Callable(self, &"_start_up")
		)
	return _startup_stager


## The one-time gameplay startup. Identical on both construction paths; the only
## difference is when the authored subtree became complete.
func _start_up() -> void:
	_initialize_runtime_settings()
	bind_planetary_return_persistence(ember_surface_loop_production_binding)
	bind_ember_relay_survey_persistence(ember_surface_loop_production_binding)
	_restore_and_retire_planetary_return_persistence()
	_initialize_session_diagnostics()
	_apply_command_line_recovery_args(OS.get_cmdline_args())
	_publish_recovery_choice_to_hud()
	_publish_safe_start_recovery_status_to_hud()
	player.teleport_to(world.get_player_spawn())
	player.set_control_enabled(false)
	player.set_camera_active(false)
	_register_flyable_ships()
	_resolve_ground_vehicle()
	active_ship = ship
	_initialize_minimap_topology()
	_initialize_cargo_delivery_composition()
	_initialize_cinder_race_session()
	_initialize_cinder_convoy_host()
	_initialize_caption_presentation()
	_initialize_live_combat()
	_sync_fleet_ship_semantic_audio()
	_initialize_nearby_activity_audio()
	_initialize_halyard_crew_semantic_audio()
	_initialize_optional_semantic_audio()
	# The atomic load above is complete before the first global, player, ship or
	# HUD settings consumer sees a snapshot. In particular, the complete binding
	# profile reaches InputMap and all retained local ship banks before gameplay
	# signals can sample it.
	_apply_all_runtime_settings()
	_connect_runtime_signals()
	_sync_cinder_loadmaster_hud_binding()
	_ensure_final_approach_hud_composition()
	opponent.set_target(active_ship)
	opponent.deactivate()
	total_targets = world.get_target_count()
	hud.set_target_count(0, total_targets)
	hud.set_mode("on-foot")
	hud.set_interaction("", false)
	hud.set_enemy_status("", 0.0, 1.0, false)
	_update_music_bed_state()
	_sync_halyard_crew_semantic_audio()
	_sync_optional_semantic_audio()
	_apply_torus_geometry_budget()
	_sync_activity_hud()
	_sync_planetary_cruise_hud()
	_publish_runtime_settings_repair_to_hud()
	_initialized = true
	_record_session_startup_completed()


func _initialize_session_diagnostics() -> void:
	if _session_diagnostics_bridge != null or _runtime_settings_user_data_store == null:
		return
	var coordinator := CrashRecoveryCoordinatorType.new(_runtime_settings_user_data_store)
	var record := SessionDiagnosticRecordType.new(_runtime_settings_user_data_store)
	var sink := SessionDiagnosticFileSinkType.new(
		"user://diagnostics", _session_diagnostics_filesystem
	)
	var restored := coordinator.restore()
	if not bool(restored.accepted):
		_session_diagnostics_last_status = {"accepted": false, "reason": &"restore_failed", "status": restored}
		return
	var record_restored := record.restore_from_store()
	if not bool(record_restored.accepted) and record_restored.reason != &"no_record":
		_session_diagnostics_last_status = {
			"accepted": false,
			"reason": &"record_restore_failed",
			"status": record_restored,
		}
		return
	var coordinator_snapshot := coordinator.get_snapshot()
	_session_diagnostics_session_id = int(
		coordinator_snapshot.get("startup_generation", 0)
	) + 1
	_session_diagnostics_bridge = SessionDiagnosticLifecycleBridgeType.new(coordinator, record, sink)
	var start_commit_id := "main-session-start-%d" % (_runtime_settings_user_data_store.get_generation() + 1)
	_session_diagnostics_last_status = _session_diagnostics_bridge.begin_session(
		_session_diagnostics_session_id,
		start_commit_id,
		_session_diagnostics_physics_tick,
		_session_diagnostics_elapsed_physics_seconds,
	)
	if bool(_session_diagnostics_last_status.get("accepted", false)):
		_session_diagnostics_record = record


func get_session_diagnostics_snapshot() -> Dictionary:
	return {
		"available": _session_diagnostics_bridge != null,
		"last_status": _session_diagnostics_last_status.duplicate(true),
		"bridge": _session_diagnostics_bridge.get_snapshot() if _session_diagnostics_bridge != null else {},
		"session_id": _session_diagnostics_session_id,
		"physics_tick": _session_diagnostics_physics_tick,
		"elapsed_physics_seconds": _session_diagnostics_elapsed_physics_seconds,
		"runtime_mode": _session_diagnostics_runtime_mode,
		"recovery_command": _session_recovery_command_status.duplicate(true),
		"recovery_hud": _session_recovery_hud_status.duplicate(true),
	}.duplicate(true)


## Test/platform seam: production defaults to the user filesystem, while an
## injected adapter keeps the marker store and diagnostic sink in one namespace.
func set_session_diagnostics_filesystem(filesystem: UserDataFilesystem) -> void:
	if _session_diagnostics_bridge == null:
		_session_diagnostics_filesystem = filesystem


func mark_orderly_session_shutdown() -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	if StringName(_session_diagnostics_bridge.get_snapshot().get("state", &"")) == &"clean":
		return {"accepted": true, "reason": &"already_clean"}.duplicate(true)
	var observation := (
		{"accepted": true, "reason": &"clean_observation_already_recorded"}
		if _session_diagnostics_clean_observation_recorded
		else _record_session_diagnostic_observation(
			SessionDiagnosticRecordType.LifecycleObservation.CLEAN_SHUTDOWN
		)
	) as Dictionary
	if bool((observation.get("record_status", {}) as Dictionary).get(
		"accepted", false
	)):
		_session_diagnostics_clean_observation_recorded = true
	if _session_diagnostics_clean_observation_recorded \
			and _session_diagnostics_persist_pending:
		var pending_retry := _persist_session_diagnostics_ring()
		observation["accepted"] = bool(pending_retry.get("accepted", false))
		observation["retry_status"] = pending_retry.duplicate(true)
	var clean_commit_id := "main-session-clean-%d" % (_runtime_settings_user_data_store.get_generation() + 1)
	var marker := _session_diagnostics_bridge.mark_orderly_shutdown(
		_session_diagnostics_physics_tick,
		_session_diagnostics_elapsed_physics_seconds,
		clean_commit_id,
	)
	if not bool(observation.get("accepted", false)) \
			and bool((observation.get("record_status", {}) as Dictionary).get(
				"accepted", false
			)):
		var retry := _persist_session_diagnostics_ring()
		observation["retry_status"] = retry.duplicate(true)
		observation["accepted"] = bool(retry.get("accepted", false))
		observation["reason"] = (
			&"observation_persisted"
			if bool(retry.get("accepted", false))
			else &"observation_persist_failed"
		)
	_session_diagnostics_last_status = {
		"accepted": bool(observation.get("accepted", false))
			and bool(marker.get("accepted", false)),
		"reason": (
			&"orderly_shutdown"
			if bool(observation.get("accepted", false))
				and bool(marker.get("accepted", false))
			else &"orderly_shutdown_failed"
		),
		"observation_status": observation.duplicate(true),
		"marker_status": marker.duplicate(true),
	}.duplicate(true)
	return _session_diagnostics_last_status.duplicate(true)


func get_recovery_available_snapshot() -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {}
	return _session_diagnostics_bridge.get_recovery_available_snapshot()


## Recovery-card-only exposure of the existing detached diagnostic ring. A
## clean startup never exposes it, and callers receive no sink, path, store, or
## diagnostic mutation authority.
func get_session_recovery_diagnostic_snapshot() -> Dictionary:
	if _session_diagnostics_bridge == null \
			or get_recovery_available_snapshot().is_empty():
		return {}
	var bridge_snapshot := _session_diagnostics_bridge.get_snapshot()
	var record_value: Variant = bridge_snapshot.get("record")
	if record_value is not Dictionary:
		return {}
	return (record_value as Dictionary).duplicate(true)


func get_session_start_recommendation() -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {"available": false, "requires_caller_choice": false}
	var safe_patch := {}
	if _safe_start_production_recovery != null:
		safe_patch = _safe_start_production_recovery.get_recovery_recommendation_patch()
	return _session_diagnostics_bridge.get_recovery_recommendation(safe_patch)


func _publish_recovery_choice_to_hud() -> void:
	if not is_instance_valid(hud):
		return
	var recovery_snapshot := get_recovery_available_snapshot()
	if recovery_snapshot.is_empty():
		if hud.has_method(&"clear_session_recovery_notice"):
			hud.call(&"clear_session_recovery_notice")
		elif hud.has_method(&"apply_recovery_choice_snapshot"):
			hud.call(
				&"apply_recovery_choice_snapshot",
				{"available": false, "requires_caller_choice": false}
			)
		return
	var recommendation := get_session_start_recommendation()
	if hud.has_method(&"present_session_recovery_notice"):
		var presentation := hud.call(
			&"present_session_recovery_notice",
			recovery_snapshot.duplicate(true),
			recommendation.duplicate(true),
			get_session_recovery_diagnostic_snapshot()
		) as Dictionary
		if not bool(presentation.get("accepted", false)):
			_session_recovery_hud_status = {
				"accepted": false,
				"reason": presentation.get("reason", &"hud_rejected_recovery_notice"),
				"source": &"presentation",
			}.duplicate(true)
		return
	# Compatibility for retained HUD test doubles predating the fenced surface.
	if hud.has_method(&"apply_recovery_choice_snapshot"):
		hud.call(&"apply_recovery_choice_snapshot", recommendation.duplicate(true))


func _connect_session_recovery_hud_signals() -> void:
	_connect_signal_once(
		hud,
		&"session_recovery_safe_requested",
		_on_hud_session_recovery_safe_requested
	)
	_connect_signal_once(
		hud,
		&"session_recovery_continue_requested",
		_on_hud_session_recovery_continue_requested
	)
	_connect_signal_once(
		hud,
		&"session_recovery_discard_requested",
		_on_hud_session_recovery_discard_requested
	)
	_connect_signal_once(
		hud,
		&"session_recovery_support_export_requested",
		_on_hud_session_recovery_support_export_requested
	)


func _restore_session_recovery_hud_after_reentry() -> void:
	_connect_session_recovery_hud_signals()
	_publish_recovery_choice_to_hud()
	# The retained keyed card already owns its serial and controls. Refresh its
	# cursor without promoting it over a newer ordinary source. A newly replaced
	# HUD may activate on the bounded retry inside the publisher.
	_publish_safe_start_recovery_status_to_hud(false, true)


## Publishes only detached SafeStartProductionRecovery output. Report revision
## is an action fence, but any RuntimeSettings batch may advance it; only a
## material status/readiness change is allowed to promote this ordinary card.
func _publish_safe_start_recovery_status_to_hud(
		activate_runtime_card: bool = true,
		force: bool = false
		) -> Dictionary:
	if _safe_start_production_recovery == null:
		return _record_safe_start_recovery_hud_status(
			false, &"policy_unavailable", &"publish", -1, -1, {}
		)
	var report := _safe_start_production_recovery.get_report() as Dictionary
	var cursor := _safe_start_recovery_report_cursor(report)
	if not bool(cursor.get("accepted", false)):
		return _record_safe_start_recovery_hud_status(
			false,
			StringName(cursor.get("reason", &"invalid_recovery_cursor")),
			&"publish",
			int(cursor.get("generation", -1)),
			int(cursor.get("revision", -1)),
			{}
		)
	var generation := int(cursor.generation)
	var revision := int(cursor.revision)
	if generation == _safe_start_recovery_dismissed_generation:
		_safe_start_recovery_published_generation = generation
		_safe_start_recovery_published_revision = revision
		if is_instance_valid(hud) and hud.has_method(&"clear_safe_start_recovery_status"):
			hud.call(&"clear_safe_start_recovery_status")
		return _record_safe_start_recovery_hud_status(
			true, &"dismissed_generation_suppressed", &"publish",
			generation, revision, {}
		)
	if (
		not force
		and generation == _safe_start_recovery_published_generation
		and revision == _safe_start_recovery_published_revision
	):
		return _record_safe_start_recovery_hud_status(
			true, &"recovery_report_unchanged", &"publish",
			generation, revision, {}
		)
	if not is_instance_valid(hud) or not hud.has_method(&"apply_safe_start_recovery_report"):
		return _record_safe_start_recovery_hud_status(
			false, &"hud_unavailable", &"publish", generation, revision, {}
		)
	var material := _safe_start_recovery_material_projection(report)
	var material_changed := (
		generation != _safe_start_recovery_published_generation
		or material != _safe_start_recovery_published_material
	)
	var presentation := hud.call(
		&"apply_safe_start_recovery_report",
		report.duplicate(true),
		activate_runtime_card and material_changed
	) as Dictionary
	# Retained re-entry updates in place. Only a genuinely replaced HUD lacks the
	# keyed source; retrying once activates the same authoritative report there.
	if (
		not bool(presentation.get("accepted", false))
		and not activate_runtime_card
		and presentation.get("reason") == &"safe_start_recovery_card_unavailable"
	):
		presentation = hud.call(
			&"apply_safe_start_recovery_report", report.duplicate(true), true
		) as Dictionary
	if not bool(presentation.get("accepted", false)):
		return _record_safe_start_recovery_hud_status(
			false,
			StringName(presentation.get("reason", &"hud_rejected_recovery_report")),
			&"publish",
			generation,
			revision,
			{"presentation": presentation}
		)
	_safe_start_recovery_published_generation = generation
	_safe_start_recovery_published_revision = revision
	_safe_start_recovery_published_material = material.duplicate(true)
	return _record_safe_start_recovery_hud_status(
		true,
		StringName(presentation.get("reason", &"safe_start_recovery_presented")),
		&"publish",
		generation,
		revision,
		{"presentation": presentation}
	)


func _safe_start_recovery_report_cursor(report: Dictionary) -> Dictionary:
	var generation_value: Variant = report.get("startup_generation")
	var revision_value: Variant = report.get("report_revision")
	if generation_value is not int or revision_value is not int:
		return {"accepted": false, "reason": &"invalid_recovery_cursor"}
	var generation := generation_value as int
	var revision := revision_value as int
	if generation < 0 or revision < 0:
		return {
			"accepted": false,
			"reason": &"invalid_recovery_cursor",
			"generation": generation,
			"revision": revision,
		}
	return {
		"accepted": true,
		"reason": &"recovery_cursor_valid",
		"generation": generation,
		"revision": revision,
	}


func _safe_start_recovery_material_projection(report: Dictionary) -> Dictionary:
	var policy := report.get("policy_snapshot", {}) as Dictionary
	return {
		"begin_reason": (report.get("begin_status", {}) as Dictionary).get("reason", &""),
		"restore_reason": (report.get("restore_status", {}) as Dictionary).get("reason", &""),
		"stable_reason": (report.get("stable_status", {}) as Dictionary).get("reason", &""),
		"policy_state": policy.get("state", &""),
		"graphics_recovery_receipt": (
			report.get("graphics_recovery_receipt", {}) as Dictionary
		).duplicate(true),
		"audio_recovery_receipt": (
			report.get("audio_recovery_receipt", {}) as Dictionary
		).duplicate(true),
		"restore_readiness_snapshot": (
			report.get("restore_readiness_snapshot", {}) as Dictionary
		).duplicate(true),
	}.duplicate(true)


func _on_hud_session_recovery_safe_requested(token: int, generation: int) -> void:
	_handle_hud_session_recovery_choice(&"safe_graphics_windowed", token, generation)


func _on_hud_session_recovery_continue_requested(token: int, generation: int) -> void:
	_handle_hud_session_recovery_choice(&"normal_start", token, generation)


func _on_hud_session_recovery_discard_requested(token: int, generation: int) -> void:
	_handle_hud_session_recovery_choice(&"discard", token, generation)


func _on_hud_session_recovery_support_export_requested(token: int, generation: int) -> void:
	var status := export_session_recovery_support_summary(token, generation)
	if is_instance_valid(hud) and hud.has_method(&"present_session_recovery_support_export_result"):
		hud.call(
			&"present_session_recovery_support_export_result",
			token,
			generation,
			bool(status.get("accepted", false))
		)


## Explicit player-requested local support export. It is deliberately separate
## from recovery choices: it neither retires the receipt nor changes settings,
## gameplay, networking, or diagnostic payloads.
func export_session_recovery_support_summary(token: int, generation: int) -> Dictionary:
	var recovery_snapshot := get_recovery_available_snapshot()
	if recovery_snapshot.is_empty():
		return _record_session_recovery_hud_result(
			false, &"no_recovery_available", &"support_export", token, generation, {}
		)
	if (
		token != int(recovery_snapshot.get("session_id", 0))
		or generation != int(recovery_snapshot.get("startup_generation", 0))
	):
		return _record_session_recovery_hud_result(
			false, &"stale_recovery_fence", &"support_export", token, generation, {}
		)
	if _session_diagnostics_bridge == null:
		return _record_session_recovery_hud_result(
			false, &"diagnostics_unavailable", &"support_export", token, generation, {}
		)
	if (
		token == _session_recovery_support_export_token
		and generation == _session_recovery_support_export_generation
	):
		return _record_session_recovery_hud_result(
			false, &"support_export_replayed", &"support_export", token, generation, {}
		)
	_session_recovery_support_export_token = token
	_session_recovery_support_export_generation = generation
	var result := _session_diagnostics_bridge.export_support_bundle_next_generation(
		SESSION_DIAGNOSTIC_SUPPORT_EXPORT_ROOT
	)
	return _record_session_recovery_hud_result(
		bool(result.get("accepted", false)),
		StringName(str(result.get("reason", &"support_export_failed"))),
		&"support_export",
		token,
		generation,
		result
	)


func _handle_hud_session_recovery_choice(
	choice: StringName,
	token: int,
	generation: int
) -> Dictionary:
	var recovery_snapshot := get_recovery_available_snapshot()
	if recovery_snapshot.is_empty():
		return _record_session_recovery_hud_result(
			false, &"no_recovery_available", choice, token, generation, {}
		)
	if (
		token != int(recovery_snapshot.get("session_id", 0))
		or generation != int(recovery_snapshot.get("startup_generation", 0))
	):
		return _record_session_recovery_hud_result(
			false, &"stale_recovery_fence", choice, token, generation, {}
		)
	var result: Dictionary
	match choice:
		&"safe_graphics_windowed":
			# The bridge invokes only SafeStartProductionRecovery's existing
			# generation-fenced two-setting callback. GameFlow does not inspect,
			# widen, persist, or recreate that patch here.
			result = choose_session_start_recovery(choice)
		&"normal_start":
			result = acknowledge_recovery()
		&"discard":
			result = discard_recovery()
		_:
			result = {"accepted": false, "reason": &"invalid_recovery_choice"}
	var status := _record_session_recovery_hud_result(
		bool(result.get("accepted", false)),
		StringName(str(result.get("reason", &"recovery_choice_failed"))),
		choice,
		token,
		generation,
		result
	)
	# Re-observe bridge truth after the request. Success removes the notice only
	# when the bridge actually retired its receipt; failure leaves the latched
	# decision visible and cannot manufacture a fresh choice generation.
	if get_recovery_available_snapshot().is_empty():
		# A Button is locked while its pressed signal is on the stack. Defer the
		# presentation cleanup past that emission boundary; no choice or bridge
		# mutation is deferred with it.
		if is_instance_valid(hud) and hud.has_method(&"clear_session_recovery_notice"):
			hud.call_deferred(&"clear_session_recovery_notice")
		elif is_instance_valid(hud) and hud.has_method(&"apply_recovery_choice_snapshot"):
			hud.call_deferred(
				&"apply_recovery_choice_snapshot",
				{"available": false, "requires_caller_choice": false}
			)
	return status


func _record_session_recovery_hud_result(
	accepted: bool,
	reason: StringName,
	choice: StringName,
	token: int,
	generation: int,
	result: Dictionary
) -> Dictionary:
	_session_recovery_hud_status = {
		"accepted": accepted,
		"reason": reason,
		"choice": choice,
		"recovery_token": token,
		"recovery_generation": generation,
		"result": result.duplicate(true),
		"automatic_choice": false,
	}.duplicate(true)
	return _session_recovery_hud_status.duplicate(true)


func acknowledge_recovery() -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	return _session_diagnostics_bridge.acknowledge_recovery()


func discard_recovery() -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	return _session_diagnostics_bridge.discard_recovery()


func choose_session_start_recovery(choice: StringName) -> Dictionary:
	if _session_diagnostics_bridge == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	var apply_safe := Callable()
	if _safe_start_production_recovery != null:
		apply_safe = Callable(_safe_start_production_recovery, &"apply_current_session_safe_graphics")
	return _session_diagnostics_bridge.choose_recovery(choice, apply_safe)


func apply_command_line_recovery_args(args: PackedStringArray) -> Dictionary:
	return _apply_command_line_recovery_args(args)


func _apply_command_line_recovery_args(args: PackedStringArray) -> Dictionary:
	var safe_requested := args.has("--safe-mode")
	var discard_requested := args.has("--discard-recovery")
	if not safe_requested and not discard_requested:
		_session_recovery_command_status = {"accepted": true, "reason": &"not_requested", "source": &"command_line"}
		return _session_recovery_command_status.duplicate(true)
	if safe_requested and discard_requested:
		_session_recovery_command_status = {"accepted": false, "reason": &"conflicting_recovery_flags", "source": &"command_line"}
		return _session_recovery_command_status.duplicate(true)
	if _session_diagnostics_bridge == null or get_recovery_available_snapshot().is_empty():
		_session_recovery_command_status = {"accepted": false, "reason": &"no_recovery_available", "source": &"command_line"}
		return _session_recovery_command_status.duplicate(true)
	var choice: StringName = &"safe_graphics_windowed" if safe_requested else &"discard"
	var result := choose_session_start_recovery(choice)
	_session_recovery_command_status = {
		"accepted": bool(result.get("accepted", false)),
		"reason": result.get("reason", &"command_recovery_failed"),
		"source": &"command_line",
		"choice": choice,
		"result": result.duplicate(true),
	}.duplicate(true)
	return _session_recovery_command_status.duplicate(true)


func _record_session_startup_completed() -> Dictionary:
	var startup := _record_session_diagnostic_observation(
		SessionDiagnosticRecordType.LifecycleObservation.STARTUP_COMPLETED
	)
	if bool(startup.get("accepted", false)):
		_observe_session_diagnostic_runtime_mode()
	return startup


func _record_session_diagnostic_observation(
	observation: int,
	runtime_mode: int = SessionDiagnosticRecordType.RuntimeMode.STATION
	) -> Dictionary:
	if _session_diagnostics_record == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	var recorded := _session_diagnostics_record.record_lifecycle_observation(
		observation,
		_session_diagnostics_session_id,
		_session_diagnostics_physics_tick,
		_session_diagnostics_elapsed_physics_seconds,
		runtime_mode,
	)
	if not bool(recorded.get("accepted", false)):
		return {
			"accepted": false,
			"reason": &"observation_rejected",
			"record_status": recorded.duplicate(true),
		}.duplicate(true)
	_session_diagnostics_persist_pending = true
	var persisted := _persist_session_diagnostics_ring()
	var result := {
		"accepted": bool(persisted.get("accepted", false)),
		"reason": (
			&"observation_persisted"
			if bool(persisted.get("accepted", false))
			else &"observation_persist_failed"
		),
		"record_status": recorded.duplicate(true),
		"persist_status": persisted.duplicate(true),
	}.duplicate(true)
	_session_diagnostics_last_status = result.duplicate(true)
	return result


func _persist_session_diagnostics_ring() -> Dictionary:
	if _session_diagnostics_record == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	var persisted := _session_diagnostics_record.persist(
		"main-session-observation-%d"
		% (_runtime_settings_user_data_store.get_generation() + 1)
	)
	if bool(persisted.get("accepted", false)):
		_session_diagnostics_persist_pending = false
	return persisted.duplicate(true)


func _observe_session_diagnostic_runtime_mode() -> Dictionary:
	if _session_diagnostics_record == null:
		return {"accepted": false, "reason": &"diagnostics_unavailable"}
	var mode := SessionDiagnosticRecordType.RuntimeMode.STATION
	if _piloting:
		mode = SessionDiagnosticRecordType.RuntimeMode.FLIGHT
	# The retained journey latch is set only after the production surface
	# composition admits the handoff and is cleared when ownership returns.
	if _ember_surface_journey_active:
		mode = SessionDiagnosticRecordType.RuntimeMode.SURFACE
	if mode == _session_diagnostics_runtime_mode:
		return {"accepted": true, "reason": &"mode_unchanged", "runtime_mode": mode}
	var observed := _record_session_diagnostic_observation(
		SessionDiagnosticRecordType.LifecycleObservation.MODE_HANDOFF,
		mode,
	)
	if bool((observed.get("record_status", {}) as Dictionary).get("accepted", false)):
		_session_diagnostics_runtime_mode = mode
	return observed


func _advance_session_diagnostics_physics(delta: float) -> void:
	if _session_diagnostics_record == null \
			or delta < 0.0 or is_nan(delta) or is_inf(delta):
		return
	_session_diagnostics_physics_tick = mini(
		_session_diagnostics_physics_tick + 1,
		SessionDiagnosticRecordType.MAX_PHYSICS_TICK,
	)
	_session_diagnostics_elapsed_physics_seconds = minf(
		_session_diagnostics_elapsed_physics_seconds + delta,
		SessionDiagnosticRecordType.MAX_SESSION_PHYSICS_SECONDS,
	)
	if _session_diagnostics_persist_pending:
		_persist_session_diagnostics_ring()
	_observe_session_diagnostic_runtime_mode()


## Brings every ring and collar in the scene under one geometry budget.
##
## Nine builders across the station modules and the ship visuals author
## `TorusMesh` rings, and each had independently fixed its own tessellation and
## applied it to everything from a 148-metre moonlet ring to a 10-centimetre pipe
## collar. The whole-scene census put that at 213,664 triangles, 15.2% of the
## scene. `TorusGeometryBudget` solves tessellation from each ring's measured
## world-space radii instead, so a beacon signal ring the player reads as a
## circle keeps its smoothness while a mast collar drops.
##
## This runs here rather than inside a module because the tori are spread across
## `ShipyardWorld` *and* the four ship scenes, which are siblings of it. Godot
## readies children before parents, so by the time `Main` is ready the world and
## every ship have finished building and their global transforms — which the
## budget reads to get world-space size — are final.
##
## It changes `rings` and `ring_segments` only, and never upward, so it cannot
## move, resize, recolour or re-material anything, and cannot make the scene more
## expensive than the builders already made it.
func _apply_torus_geometry_budget() -> void:
	TorusGeometryBudget.normalise_tree(self)


func _process(delta: float) -> void:
	# Under a staged startup the coordinator is in the tree while its subtree is
	# still being assembled. Nothing here has anything to act on until the
	# gameplay startup tail has run.
	if not _initialized:
		return
	_update_display_confirmation(delta)
	_update_debug_overlay()
	_update_pending_regeneration(delta)
	_update_music_bed_state()
	_sync_halyard_crew_semantic_audio()
	if phase == Phase.INTRO:
		return
	if _piloting:
		_consume_active_ship_command_edges()
		_update_pilot_flow()
	elif _driving:
		# A seated driver is not on foot. Running the on-foot flow here would draw
		# station prompts the seated player cannot reach and, worse, would let the
		# walking fall-recall below teleport the avatar out of a live seat.
		_update_drive_flow()
	elif _station_seated:
		_update_station_seat_flow()
	else:
		_update_on_foot_flow()
		# The below-deck recall is a station-floor backstop expressed in world
		# space. A crew member aboard a craft under way is legitimately anywhere,
		# including well below the yard; their backstop is cabin containment.
		if (
			player.global_position.y < -24.0
			and not _transition_busy
			and phase != Phase.IN_FLIGHT_CABIN
			and not player.is_cabin_containment_active()
		):
			player.teleport_to(world.get_player_spawn())
			hud.toast("Regeneration safety recall", "Returned to the central junction", 2.0)


func _update_debug_overlay() -> void:
	if (
		not is_instance_valid(hud)
		or not hud.has_method(&"is_debug_overlay_visible")
		or not bool(hud.call(&"is_debug_overlay_visible"))
	):
		return
	hud.call(&"update_debug_overlay", get_debug_overlay_snapshot())


## Detached, side-effect-free diagnostics for screenshots and focused tests.
## Scene coordinates are current floating-origin metres; the separate absolute
## cell/offset record remains stable when that origin is rebased.
func get_debug_overlay_snapshot() -> Dictionary:
	var actor: Node3D = _get_debug_actor()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		camera = _get_debug_camera(actor)
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	)
	var actor_position: Vector3 = (
		actor.global_position if is_instance_valid(actor) else Vector3.ZERO
	)
	var actor_velocity: Vector3 = (
		(actor as CharacterBody3D).velocity if actor is CharacterBody3D else Vector3.ZERO
	)
	var camera_position: Vector3 = (
		camera.global_position if is_instance_valid(camera) else actor_position
	)
	var camera_forward: Vector3 = (
		-camera.global_basis.orthonormalized().z.normalized()
		if is_instance_valid(camera)
		else Vector3.FORWARD
	)
	var yaw_degrees := rad_to_deg(atan2(camera_forward.x, -camera_forward.z))
	var pitch_degrees := rad_to_deg(asin(clampf(camera_forward.y, -1.0, 1.0)))
	var snapshot := {
		"schema_version": 1,
		"mode": _get_debug_mode(),
		"phase": _get_debug_phase_name(),
		"actor_name": _get_debug_actor_name(actor),
		"actor_path": str(get_path_to(actor)) if is_instance_valid(actor) else "UNAVAILABLE",
		"actor_position": actor_position,
		"actor_velocity": actor_velocity,
		"camera_path": str(get_path_to(camera)) if is_instance_valid(camera) else "UNAVAILABLE",
		"camera_position": camera_position,
		"camera_forward": camera_forward,
		"camera_fov": camera.fov if is_instance_valid(camera) else 0.0,
		"facing": _debug_cardinal(camera_forward),
		"yaw_degrees": yaw_degrees,
		"pitch_degrees": pitch_degrees,
		"fps": Engine.get_frames_per_second(),
		"frame": Engine.get_process_frames(),
		"viewport_size": Vector2i(roundi(viewport_size.x), roundi(viewport_size.y)),
	}
	snapshot.merge(_get_debug_aim_snapshot(camera, actor), true)
	_add_debug_absolute_coordinate(snapshot, actor_position, "absolute_coordinate")
	if bool(snapshot.get("aim_hit", false)):
		_add_debug_absolute_coordinate(
			snapshot,
			snapshot.get("aim_position", Vector3.ZERO) as Vector3,
			"aim_absolute_coordinate"
		)
	return snapshot.duplicate(true)


func _get_debug_actor() -> Node3D:
	if _driving and is_instance_valid(tow_tractor) and tow_tractor.is_inside_tree():
		return tow_tractor
	if (
		is_instance_valid(active_ship)
		and active_ship.is_inside_tree()
		and (_piloting or active_ship.is_piloted())
		and not active_ship.is_destroyed()
	):
		return active_ship
	return player if is_instance_valid(player) and player.is_inside_tree() else null


func _get_debug_camera(actor: Node3D) -> Camera3D:
	if actor is HeroShip:
		return (actor as HeroShip).get_camera()
	if actor is TowTractor:
		return (actor as TowTractor).get_camera()
	if is_instance_valid(player):
		return player.get_camera()
	return null


func _get_debug_actor_name(actor: Node3D) -> String:
	if actor is HeroShip:
		return (actor as HeroShip).get_display_name()
	if actor is TowTractor:
		return "YARD TOW TRACTOR"
	if actor == player:
		return "PLAYER"
	return str(actor.name) if is_instance_valid(actor) else "UNAVAILABLE"


func _get_debug_mode() -> String:
	if _piloting:
		return "PILOTING"
	if _driving:
		return "DRIVING"
	if phase == Phase.IN_FLIGHT_CABIN:
		return "ABOARD"
	return "ON FOOT"


func _get_debug_phase_name() -> String:
	var phase_names := Phase.keys()
	return str(phase_names[phase]) if phase >= 0 and phase < phase_names.size() else "UNKNOWN"


func _get_debug_aim_snapshot(camera: Camera3D, actor: Node3D) -> Dictionary:
	if not is_instance_valid(camera) or camera.get_world_3d() == null:
		return {"aim_hit": false, "aim_endpoint": Vector3.ZERO}
	var viewport_rect := camera.get_viewport().get_visible_rect()
	var centre := viewport_rect.position + viewport_rect.size * 0.5
	var origin := camera.project_ray_origin(centre)
	var direction := camera.project_ray_normal(centre).normalized()
	var endpoint := origin + direction * DEBUG_AIM_DISTANCE_METERS
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"aim_hit": false, "aim_endpoint": endpoint}
	var collider := hit.get("collider") as Object
	var collider_path := str(collider)
	if collider is Node:
		collider_path = str((collider as Node).get_path())
	var hit_position := hit.get("position", endpoint) as Vector3
	return {
		"aim_hit": true,
		"aim_position": hit_position,
		"aim_distance": origin.distance_to(hit_position),
		"aim_collider": collider_path,
		"aim_endpoint": endpoint,
	}


func _add_debug_absolute_coordinate(
		snapshot: Dictionary,
		world_position: Vector3,
		field: String
	) -> void:
	if not is_instance_valid(ember_streaming_bootstrap):
		return
	var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null or not frame.is_configured():
		return
	var generation := frame.get_generation()
	var decoded := frame.decode_world_streaming_position(world_position, generation)
	if not bool(decoded.get("accepted", false)):
		return
	var coordinate := decoded.get("coordinate", {}) as Dictionary
	var absolute := coordinate.get("orbital_coordinate", {}) as Dictionary
	if absolute.is_empty():
		return
	snapshot["coordinate_frame_generation"] = generation
	snapshot[field] = absolute.duplicate(true)


func _debug_cardinal(forward: Vector3) -> String:
	var horizontal := Vector2(forward.x, -forward.z)
	if horizontal.length_squared() < 0.000001:
		return "VERTICAL"
	var heading := fposmod(rad_to_deg(atan2(horizontal.x, horizontal.y)), 360.0)
	var names := ["NORTH (-Z)", "NORTHEAST", "EAST (+X)", "SOUTHEAST", \
		"SOUTH (+Z)", "SOUTHWEST", "WEST (-X)", "NORTHWEST"]
	return names[posmod(roundi(heading / 45.0), names.size())]


func _update_minimap(actor_sample: Dictionary) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"update_minimap"):
		return
	hud.call(&"update_minimap", get_minimap_snapshot(actor_sample))


## Detached presentation snapshot over the one actor observation already taken
## for this physics tick. The map detects nothing and grants no targeting or
## navigation authority; it only formats world-owned topology and live nodes.
func get_minimap_snapshot(actor_sample: Dictionary = {}) -> Dictionary:
	var actor := _get_debug_actor()
	var center_position := Vector3.ZERO
	var has_actor_position := false
	var sampled_position: Variant = actor_sample.get("position", null)
	if (
		bool(actor_sample.get("available", false))
		and sampled_position is Vector3
		and (sampled_position as Vector3).is_finite()
	):
		center_position = sampled_position as Vector3
		has_actor_position = true
	elif is_instance_valid(actor) and actor.global_position.is_finite():
		center_position = actor.global_position
		has_actor_position = true

	var forward := _minimap_actor_forward(actor)
	var heading_radians := 0.0
	if forward.is_finite() and Vector2(forward.x, forward.z).length_squared() > 0.000001:
		heading_radians = atan2(forward.x, -forward.z)
	var snapshot := {
		"schema_version": 1,
		"range_meters": (
			MINIMAP_FLIGHT_RANGE_METERS if _piloting else MINIMAP_STATION_RANGE_METERS
		),
		"center_position": center_position,
		"heading_radians": heading_radians,
		"topology_nodes": _get_minimap_topology_nodes_world(),
		"topology_edges": _minimap_topology_edges.duplicate(true),
		"contacts": _get_minimap_contacts(),
		"objective_markers": _get_minimap_objective_markers(
			int(actor_sample.get("coordinate_frame_generation", 0))
		),
		"mode": _get_debug_mode(),
	}
	# The cyan marker represents the embodied pilot. While seated, its map
	# position is therefore the active craft rather than the hidden Player root.
	if has_actor_position:
		snapshot["player_position"] = center_position
	if (
		is_instance_valid(active_ship)
		and active_ship.is_inside_tree()
		and not active_ship.is_destroyed()
		and active_ship.global_position.is_finite()
	):
		snapshot["active_ship"] = {
			"id": active_ship.get_ship_id(),
			"position": active_ship.global_position,
		}
	return snapshot.duplicate(true)


func _minimap_actor_forward(actor: Node3D) -> Vector3:
	if not is_instance_valid(actor):
		return Vector3.FORWARD
	if actor == player and player.has_method(&"get_pilot_visual_forward_direction"):
		var visual_forward := player.call(&"get_pilot_visual_forward_direction") as Vector3
		if visual_forward.is_finite() and visual_forward.length_squared() > 0.000001:
			return visual_forward.normalized()
	if actor == player and player.has_method(&"get_interaction_direction"):
		var interaction_forward := player.call(&"get_interaction_direction") as Vector3
		if interaction_forward.is_finite() and interaction_forward.length_squared() > 0.000001:
			return interaction_forward.normalized()
	return -actor.global_basis.orthonormalized().z.normalized()


func _initialize_minimap_topology() -> void:
	_minimap_topology_nodes_local.clear()
	_minimap_topology_edges.clear()
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	var world_inverse := world.global_transform.affine_inverse()
	var node_ids: Dictionary = {}
	var graph := world.call(&"get_station_navigation_graph_report") as Dictionary
	if bool(graph.get("valid", false)):
		var graph_nodes := graph.get("nodes", {}) as Dictionary
		var graph_node_ids := graph_nodes.keys()
		graph_node_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
			return str(left) < str(right)
		)
		for raw_node_id in graph_node_ids:
			var node_id := StringName(raw_node_id)
			var record := graph_nodes[raw_node_id] as Dictionary
			var transform_value: Variant = record.get("transform", null)
			if not (transform_value is Transform3D):
				continue
			var position := (transform_value as Transform3D).origin
			if not position.is_finite():
				continue
			_append_minimap_topology_node(
				node_ids,
				node_id,
				world_inverse * position,
				&"connection",
			)
		var graph_edges := graph.get("edges", {}) as Dictionary
		var graph_edge_ids := graph_edges.keys()
		graph_edge_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
			return str(left) < str(right)
		)
		for raw_edge_id in graph_edge_ids:
			var edge := graph_edges[raw_edge_id] as Dictionary
			var endpoints_value: Variant = edge.get("node_ids", null)
			var endpoints := PackedStringArray()
			if endpoints_value is PackedStringArray:
				endpoints = (endpoints_value as PackedStringArray).duplicate()
			elif endpoints_value is Array:
				for endpoint in endpoints_value as Array:
					endpoints.append(str(endpoint))
			if endpoints.size() == 2:
				_minimap_topology_edges.append({
					"from": StringName(endpoints[0]),
					"to": StringName(endpoints[1]),
				})

	# The declared graph contains connection claims only. Retain every module's
	# published internal route marker as a map landmark without inventing edges
	# between them; physical route authority remains outside the minimap.
	for candidate in world.find_children("*", "", true, false):
		if (
			not candidate.is_in_group(&"station_modules")
			or not candidate.has_method(&"get_module_id")
			or not candidate.has_method(&"get_route_transforms")
		):
			continue
		var module_id := StringName(candidate.call(&"get_module_id"))
		var route_transforms := candidate.call(&"get_route_transforms") as Dictionary
		var route_ids := route_transforms.keys()
		route_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
			return str(left) < str(right)
		)
		for raw_route_id in route_ids:
			var transform_value: Variant = route_transforms[raw_route_id]
			if not (transform_value is Transform3D):
				continue
			var position := (transform_value as Transform3D).origin
			if not position.is_finite():
				continue
			_append_minimap_topology_node(
				node_ids,
				StringName("route:%s:%s" % [module_id, str(raw_route_id)]),
				world_inverse * position,
				&"route",
			)

	var berth_ids: Variant = world.call(&"get_berth_ids")
	if berth_ids is Array:
		for raw_berth_id in berth_ids as Array:
			var berth_id := StringName(raw_berth_id)
			var berth_transform := world.call(&"get_berth_transform", berth_id) as Transform3D
			if not berth_transform.origin.is_finite():
				continue
			_append_minimap_topology_node(
				node_ids,
				StringName("berth:%s" % berth_id),
				world_inverse * berth_transform.origin,
				&"berth",
			)


func _append_minimap_topology_node(
		node_ids: Dictionary,
		node_id: StringName,
		local_position: Vector3,
		kind: StringName,
	) -> void:
	if node_id.is_empty() or node_ids.has(node_id) or not local_position.is_finite():
		return
	node_ids[node_id] = true
	_minimap_topology_nodes_local.append({
		"id": node_id,
		"local_position": local_position,
		"kind": kind,
	})


func _get_minimap_topology_nodes_world() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(world):
		return result
	for local_record in _minimap_topology_nodes_local:
		var local_position := local_record.get("local_position", Vector3.ZERO) as Vector3
		result.append({
			"id": local_record.get("id", &"") as StringName,
			"position": world.global_transform * local_position,
			"kind": local_record.get("kind", &"route") as StringName,
		})
	return result


func _get_minimap_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for fleet_ship in ships:
		if (
			not is_instance_valid(fleet_ship)
			or not fleet_ship.is_inside_tree()
			or fleet_ship == active_ship
			or fleet_ship.is_destroyed()
			or not fleet_ship.global_position.is_finite()
		):
			continue
		contacts.append({
			"id": fleet_ship.get_ship_id(),
			"position": fleet_ship.global_position,
			"kind": &"ship",
			"hostile": false,
		})
	for candidate in get_children():
		if (
			candidate is not Node3D
			or candidate == active_ship
			or not candidate.has_method(&"is_active")
			or not bool(candidate.call(&"is_active"))
		):
			continue
		var contact := candidate as Node3D
		if not contact.global_position.is_finite():
			continue
		contacts.append({
			"id": StringName(contact.name),
			"position": contact.global_position,
			"kind": &"ship",
			"hostile": true,
		})
	return contacts


## Detached activity destinations only. These markers are authored by the
## world/streaming owners; the minimap never starts, advances, or rewards an
## activity. A coordinate-frame generation prevents stale streamed transforms
## from surviving a rebase or unload.
func _get_minimap_objective_markers(coordinate_frame_generation: int = 0) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if is_instance_valid(world):
		var board: Area3D = world.get_station_defense_activity_board()
		if is_instance_valid(board) and board.is_inside_tree() and board.global_position.is_finite():
			markers.append({
				"id": &"station_defense_activity_board",
				"position": board.global_position,
				"generation": maxi(coordinate_frame_generation, 0),
				"active": true,
			})
		var cluster: NearbySectorCluster = world.get_nearby_sector_cluster()
		if is_instance_valid(cluster):
			var terminal: CargoTransferTerminal = cluster.get_cinder_cargo_destination_terminal()
			if is_instance_valid(terminal) and terminal.is_inside_tree() and terminal.global_position.is_finite():
				markers.append({
					"id": &"cinder_cargo_terminal",
					"position": terminal.global_position,
					"generation": maxi(coordinate_frame_generation, 0),
					"active": true,
				})
	return markers


## Binds the single retained Ember host only after the asynchronous authored
## scene exists. The active Torrent and Main Player remain the sole actors;
## this composition owns no movement or landing authority.
func _ensure_ember_surface_loop_host_bound(streaming_ready: bool) -> Dictionary:
	if not streaming_ready:
		return {"accepted": false, "reason": &"streaming_not_ready"}
	if not is_instance_valid(ember_surface_loop_host) \
			or not is_instance_valid(ember_surface_berth) \
			or not is_instance_valid(ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"composition_missing"}
	if bool(ember_surface_loop_host.get_snapshot().get("attached", false)):
		return {"accepted": true, "reason": &"already_bound"}
	if bool(ember_surface_loop_production_binding.get_snapshot().get("configured", false)):
		return {"accepted": true, "reason": &"already_configured"}
	var loaded_scene := ember_streaming_bootstrap.get_loaded_instance() \
			if is_instance_valid(ember_streaming_bootstrap) else null
	var player_controller := player as PlayerController
	if not is_instance_valid(loaded_scene) or not is_instance_valid(active_ship) \
			or not is_instance_valid(player_controller):
		return {"accepted": false, "reason": &"loaded_actor_unavailable"}
	var location_generation := int(
		ember_streaming_bootstrap.get_snapshot().get("location_generation", 0)
	)
	if location_generation < 1:
		return {"accepted": false, "reason": &"location_generation_unavailable"}
	var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null or not frame.is_configured():
		return {"accepted": false, "reason": &"coordinate_frame_unavailable"}
	var landing_region := loaded_scene.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(landing_region):
		return {"accepted": false, "reason": &"loaded_landing_region_unavailable"}
	ember_surface_berth.global_transform = landing_region.global_transform
	var bound := ember_surface_loop_host.bind_dependencies(
		ember_streaming_bootstrap, ember_surface_berth, active_ship,
		player_controller, 1.62, location_generation,
		ember_surface_loop_host.get_generation(),
		ember_surface_loop_host.get_attachment_generation(), self,
		common_world_origin_rebase_owner
	)
	if not bool(bound.get("accepted", false)):
		return bound
	var configured := ember_surface_loop_production_binding.configure(
		ember_surface_loop_host, ember_surface_loop_production_binding.get_generation()
	)
	if not bool(configured.get("accepted", false)):
		return configured
	return {"accepted": true, "reason": &"bound_after_stream_load"}


func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if is_instance_valid(network_session) and _network_session_mode == &"server":
		var composition_attachment := _attach_network_ship_authority_composition()
		if bool(composition_attachment.get("accepted", false)) \
				and _network_ship_authority_composition != null:
			_network_ship_event_sequence += 1
			_network_ship_authority_composition.submit_server_physics_tick(
				_network_ship_event_sequence, _network_ship_event_sequence
			)
	_advance_safe_start_recovery_physics(delta)
	_advance_session_diagnostics_physics(delta)
	if _caption_presentation_service != null:
		_caption_presentation_service.advance_physics(delta)
	var actor_sample := _capture_cinder_actor_sample()
	var coordinate_frame_generation := 0
	# A live cruise requires the same accepted Ember streaming observation that
	# supplied its frame/sample. A frame commit alone is insufficient: the
	# binding reconciles its generation before reporting the resulting streaming
	# transition, which can still reject (for example, a load failure).
	var ember_streaming_accepted := false
	var ember_origin_result: Dictionary = {}
	# A required rebase may enter Ember's load envelope. In that exact case, an
	# asynchronous `load_requested` acknowledgement is not yet a physical world
	# root for HeroShip's collision proof; do not queue cruise until it exists.
	var ember_streaming_residency_required := false
	# Cruise may decode its canonical destination only after an origin rebase
	# required by this exact actor observation has committed. A rejected owner
	# transaction leaves the source frame live, but that frame is not a valid
	# substitute for the required post-rebase handoff.
	var required_origin_rebase_uncommitted := false
	if is_instance_valid(ember_streaming_binding):
		var ember_tick := ember_streaming_binding.physics_tick_from_caller_sample(
			delta, actor_sample
		)
		ember_streaming_accepted = bool(ember_tick.get("accepted", false))
		coordinate_frame_generation = int(
			ember_tick.get("coordinate_frame_generation", 0)
		)
		if ember_tick.has("coordinate_frame_generation"):
			var preview := ember_streaming_binding.preview_origin_rebase(
				int(ember_tick.get("coordinate_frame_generation", 0))
			)
			if bool(preview.get("accepted", false)):
				var preview_requires_rebase := bool(preview.get("rebase_required", false))
				required_origin_rebase_uncommitted = preview_requires_rebase
				if is_instance_valid(common_world_origin_rebase_owner):
					var rebase := common_world_origin_rebase_owner.consume_rebase_preview(
						preview, actor_sample
					)
					if bool(rebase.get("accepted", false)):
						ember_origin_result = rebase.duplicate(true)
					if bool(rebase.get("accepted", false)) and rebase.has("actor_sample"):
						actor_sample = (rebase.get("actor_sample", {}) as Dictionary).duplicate(true)
						coordinate_frame_generation = int(
							rebase.get(
								"coordinate_frame_generation",
								coordinate_frame_generation,
							)
							)
						if preview_requires_rebase:
							required_origin_rebase_uncommitted = false
							var receipt := rebase.get("receipt", {}) as Dictionary
							var streaming := receipt.get("ember_streaming", {}) as Dictionary
							ember_streaming_accepted = bool(streaming.get("accepted", false))
							ember_streaming_residency_required = (
								ember_streaming_accepted
								and streaming.get("action", &"") == &"load"
							)
	if ember_origin_result.is_empty() and ember_streaming_accepted \
			and not required_origin_rebase_uncommitted \
			and coordinate_frame_generation > 0:
		ember_origin_result = {
			"accepted": true,
			"actor_sample": actor_sample.duplicate(true),
			"coordinate_frame_generation": coordinate_frame_generation,
			"reason": &"no_rebase_required",
		}.duplicate(true)
	var ember_host_bind_result := _ensure_ember_surface_loop_host_bound(
		ember_streaming_accepted and not required_origin_rebase_uncommitted
	)
	if bool(ember_host_bind_result.get("accepted", false)):
		_ensure_ember_surface_presentations()
	if bool(ember_host_bind_result.get("accepted", false)) \
			and not _pending_ember_surface_request.is_empty():
		_last_ember_surface_forward_result = _forward_pending_ember_surface_journey()
		if bool(_last_ember_surface_forward_result.get("accepted", false)):
			_ember_surface_forward_count += 1
	if not required_origin_rebase_uncommitted:
		_consume_mudds_station_return_handoff_intent(
			coordinate_frame_generation
		)
		_advance_mudds_return_approach_handoff(coordinate_frame_generation)
	if is_instance_valid(planetary_cruise_binding):
		var cruise_gate_reason := _planetary_cruise_gate_reason(false)
		var return_approach_cadence := (
			_mudds_return_approach_active
			and not _mudds_return_approach_completion_attempted
		)
		if required_origin_rebase_uncommitted:
			cruise_gate_reason = &"origin_rebase_required"
		elif not return_approach_cadence and not ember_streaming_accepted:
			cruise_gate_reason = &"ember_streaming_unavailable"
		elif (
			not return_approach_cadence
			and
			ember_streaming_residency_required
			and (
				not is_instance_valid(ember_streaming_bootstrap)
				or not is_instance_valid(ember_streaming_bootstrap.get_loaded_instance())
			)
		):
			cruise_gate_reason = &"ember_streaming_pending"
		if _planetary_cruise_caller_tick >= PLANETARY_CRUISE_MAX_CALLER_TICK:
			planetary_cruise_binding.request_caller_tick_exhausted(
				planetary_cruise_binding.get_generation()
			)
		else:
			_planetary_cruise_caller_tick += 1
			var location_generation := int(
				ember_surface_loop_host.get_snapshot().get("location_generation", 0)
			) if is_instance_valid(ember_surface_loop_host) else 0
			var cruise_tick := planetary_cruise_binding.physics_tick_from_caller_sample(
				_planetary_cruise_caller_tick,
				actor_sample,
				active_ship,
				coordinate_frame_generation,
				_planetary_cruise_combat_active(),
				cruise_gate_reason,
				location_generation,
			)
			if cruise_tick.get("reason") == &"final_approach_handoff_ready":
				_consume_ember_final_approach_completion(cruise_tick)
			elif cruise_tick.get("reason") == &"return_approach_handoff_ready":
				_consume_mudds_return_approach_completion(cruise_tick)
			elif return_approach_cadence \
					and not bool(cruise_tick.get("accepted", false)):
				_mudds_return_approach_active = false
				_ember_surface_journey_active = false
				_last_mudds_return_approach_result = cruise_tick.duplicate(true)
	# The completing cruise tick releases its Hero attachment before this one
	# retained late Host envelope is prepared. Keeping both operations in the same
	# GameFlow callback prevents a new origin transaction from reaching an IDLE
	# Host between completion and start; the priority-2 surface binding still
	# performs the one actual Host.start() after Hero's current physics tick.
	_advance_ember_surface_loop_cadence(
		delta, actor_sample, ember_origin_result, coordinate_frame_generation
	)
	_sync_planetary_cruise_hud()
	var cinder_streaming_tick: Dictionary = {
		"accepted": false,
		"reason": &"binding_unavailable",
	}
	if is_instance_valid(cinder_streaming_binding):
		cinder_streaming_tick = cinder_streaming_binding.physics_tick_from_caller_sample(
			delta, actor_sample
		)
	_sync_cinder_convoy_stream_presence()
	# A live convoy owns one exact streamed Cinder generation, but that retained
	# residency cannot substitute for the required current caller-sampled update.
	# If the sole binding is unavailable or rejects its tick, retire before the
	# host can advance from this physics sample.
	if _convoy_is_running() and not bool(cinder_streaming_tick.get("accepted", false)):
		_fail_active_activity(&"cinder_streaming_unavailable")
	if _convoy_is_running() and not _convoy_lifecycle_accepts_sample(actor_sample):
		_fail_active_activity(_convoy_lifecycle_failure_reason(actor_sample))
	_update_minimap(actor_sample)
	_advance_bomber_payload_loop(delta)
	if not _piloting:
		return
	if not is_instance_valid(active_ship):
		return
	if (
		not bool(actor_sample.get("available", false))
		and actor_sample.get("reason", &"") == &"nonfinite_active_ship_position"
		and _selected_activity_kind == ACTIVITY_KIND_PATROL
		and patrol_activity != null
		and bool(patrol_activity.get_presentation_snapshot().get("running", false))
	):
		_advance_patrol(delta, active_ship, Vector3.INF)
		return
	if (
		not bool(actor_sample.get("available", false))
		or actor_sample.get("actor_kind", &"") != &"ship"
		or int(actor_sample.get("actor_instance_id", 0)) != active_ship.get_instance_id()
	):
		return
	var sampled_ship_position := actor_sample.get("position", Vector3.INF) as Vector3
	_advance_selected_activity(delta, sampled_ship_position)
	var telemetry: Dictionary = active_ship.get_telemetry()
	_decorate_flight_path_telemetry(telemetry)
	hud.update_ship_telemetry(telemetry)
	var engine_state := str(telemetry.get("engine_state", "OFFLINE")).to_upper()
	if engine_state == "OFFLINE":
		return
	# The ship-local positional rig consumes the already sampled ShipCommand and
	# smoothed throttle. The coordinator performs no raw Input read or global hum.


func _advance_bomber_payload_loop(delta: float) -> void:
	_retry_player_pulse_network_publications()
	if _network_session_mode == &"client":
		# A multiplayer client may present server snapshots, but never advances a
		# payload, queries collision, or reaches CombatResolver locally.
		if _bomber_payload_ship != null:
			_clear_bomber_payload_loop(&"client_projectile_authority_released")
		return
	var bomber := active_ship as CinderLongRangeBomber if active_ship is CinderLongRangeBomber else null
	var should_run := is_instance_valid(bomber) and _piloting and bomber.is_piloted()
	if should_run:
		if not _ensure_bomber_payload_session(bomber):
			if is_instance_valid(hud) and hud.has_method(&"clear_bomber_payload_status"):
				hud.call(&"clear_bomber_payload_status")
			return
		_bomber_payload_server_tick += 1
		for projectile_variant: Variant in _bomber_payload_projectiles.duplicate():
			var projectile := projectile_variant as BomberPayloadProjectile
			if projectile == null:
				continue
			var previous_position: Vector3 = projectile.get_snapshot().get("position", Vector3.INF)
			var advanced := projectile.advance(maxf(delta, 0.0))
			if bool(advanced.get("accepted", false)) and not (advanced.get("terminal_intent", {}) as Dictionary).is_empty():
				_consume_bomber_payload_terminal(projectile)
				continue
			if bool(advanced.get("accepted", false)):
				_try_submit_bomber_payload_collision(projectile, previous_position)
				if _bomber_payload_projectiles.has(projectile):
					_publish_bomber_payload_network(projectile, false)
		_publish_bomber_payload_canonical_snapshot()
		_publish_bomber_payload_snapshot(bomber)
		return
	var had_payload_session := _bomber_payload_ship != null
	if had_payload_session:
		_clear_bomber_payload_loop(&"pilot_or_ship_lost")
	if had_payload_session and is_instance_valid(hud) and hud.has_method(&"clear_bomber_payload_status"):
		hud.call(&"clear_bomber_payload_status")
	_publish_bomber_payload_canonical_snapshot()


func _ensure_bomber_payload_session(bomber: CinderLongRangeBomber) -> bool:
	if not is_instance_valid(bomber):
		return false
	_apply_bomber_payload_presentation_profile(bomber)
	var authority_snapshot := bomber.get_payload_authority_snapshot()
	if _bomber_payload_ship == bomber and not bool(authority_snapshot.get("active", false)):
		_clear_bomber_payload_loop(&"ship_payload_reset")
	if _bomber_payload_ship != null and _bomber_payload_ship != bomber:
		_clear_bomber_payload_loop(&"active_ship_replaced")
	if _bomber_payload_ship == bomber:
		return _bomber_payload_adapter != null \
			and bool(_ensure_bomber_payload_network_source().get("accepted", false))
	_bomber_payload_generation += 1
	_bomber_payload_request_sequence = 0
	_bomber_payload_hud_terminal_receipt.clear()
	var started := bomber.begin_payload_generation(_bomber_payload_generation)
	if not bool(started.get("accepted", false)):
		return false
	_bomber_payload_adapter = BomberPayloadCombatAdapterType.new()
	var adapter_started := _bomber_payload_adapter.begin_generation(_bomber_payload_generation)
	if not bool(adapter_started.get("accepted", false)):
		bomber.detach_payload_authority(&"adapter_start_failed")
		_bomber_payload_adapter = null
		return false
	_bomber_payload_ship = bomber
	var network_source := _ensure_bomber_payload_network_source()
	if not bool(network_source.get("accepted", false)):
		_bomber_payload_adapter.detach(&"network_source_registration_failed")
		bomber.detach_payload_authority(&"network_source_registration_failed")
		_bomber_payload_adapter = null
		_bomber_payload_ship = null
		return false
	_present_bomber_payload_audio(&"begin_payload_audio_generation", {
		"generation": _bomber_payload_generation,
	})
	return true


func _consume_bomber_payload_release() -> Dictionary:
	if _network_session_mode == &"client":
		_last_bomber_payload_result = {
			"accepted": false,
			"reason": &"client_projectile_authority_forbidden",
		}
		return _last_bomber_payload_result.duplicate(true)
	if _bomber_payload_ship == null or _bomber_payload_adapter == null:
		_last_bomber_payload_result = {"accepted": false, "reason": &"payload_session_unavailable"}
		return _last_bomber_payload_result.duplicate(true)
	var hardpoints := _bomber_payload_ship.get_payload_hardpoints()
	if hardpoints.is_empty():
		return {"accepted": false, "reason": &"hardpoint_unavailable"}
	var request_sequence := _bomber_payload_request_sequence + 1
	var hardpoint_index := _bomber_payload_request_sequence % hardpoints.size()
	var release_velocity := _bomber_payload_ship.velocity + (-_bomber_payload_ship.global_basis.z * 220.0)
	var result := _bomber_payload_ship.request_payload_release(
		1, &"player_pilot", _bomber_payload_generation, request_sequence,
		hardpoint_index, release_velocity,
	)
	if not bool(result.get("accepted", false)):
		_last_bomber_payload_result = result.duplicate(true)
		return result
	_bomber_payload_request_sequence = request_sequence
	var record := result.get("record", {}) as Dictionary
	var projectile := BomberPayloadProjectileType.new(
		1, Vector3(0.0, -9.81, 0.0), 30.0, 500.0, 100_000.0,
	) as BomberPayloadProjectile
	var projectile_started := projectile.begin_generation(_bomber_payload_generation)
	var consumed := projectile.consume_release_record(1, record)
	if not bool(projectile_started.get("accepted", false)) or not bool(consumed.get("accepted", false)):
		_last_bomber_payload_result = {"accepted": false, "reason": &"projectile_admission_failed"}
		return _last_bomber_payload_result.duplicate(true)
	_bomber_payload_projectiles.append(projectile)
	_bomber_payload_hud_terminal_receipt.clear()
	_bomber_payload_server_tick += 1
	_publish_bomber_payload_network(projectile, false)
	_publish_bomber_payload_canonical_snapshot()
	_publish_bomber_payload_snapshot(_bomber_payload_ship)
	_present_bomber_payload_audio(&"present_payload_release", record)
	_present_bomber_payload_audio(&"present_projectile_launch", record)
	_last_bomber_payload_result = result.duplicate(true)
	return result.duplicate(true)


func _consume_bomber_payload_terminal(projectile: BomberPayloadProjectile) -> void:
	if _network_session_mode == &"client" \
			or projectile == null or _bomber_payload_ship == null or _bomber_payload_adapter == null:
		return
	var terminal := projectile.get_terminal_intent()
	if terminal.is_empty():
		return
	var release_record := projectile.get_snapshot().get("release_record", {}) as Dictionary
	terminal["payload_id"] = release_record.get("payload_id", &"")
	var combat_result := _bomber_payload_adapter.consume_terminal_intent(
		1, projectile, _bomber_payload_ship,
		int(PLAYER_SOURCE_IDS.get(CINDER_BOMBER_SHIP_ID, 0)), combat_authority,
	)
	_publish_bomber_payload_network(projectile, true)
	_bomber_payload_ship.present_payload_terminal_record(terminal)
	_present_bomber_payload_audio(&"present_projectile_terminal", terminal)
	_last_bomber_payload_result = combat_result.duplicate(true)
	var terminal_receipt := projectile.get_snapshot()
	if int(terminal_receipt.get("release_sequence", 0)) \
			>= int(_bomber_payload_hud_terminal_receipt.get("release_sequence", 0)):
		_bomber_payload_hud_terminal_receipt = terminal_receipt.duplicate(true)
	_bomber_payload_projectiles.erase(projectile)
	projectile.detach(&"terminal_forwarded")


func _try_submit_bomber_payload_collision(
	projectile: BomberPayloadProjectile,
	previous_position: Vector3,
) -> void:
	if _network_session_mode == &"client" \
			or _bomber_payload_ship == null or not is_inside_tree() or get_world_3d() == null:
		return
	var current_position: Vector3 = projectile.get_snapshot().get("position", Vector3.INF)
	if not previous_position.is_finite() or not current_position.is_finite() \
			or previous_position.distance_squared_to(current_position) <= 0.000001:
		return
	var query := PhysicsRayQueryParameters3D.create(
		previous_position, current_position, PhysicsLayers.HITSCAN_QUERY_MASK,
		[_bomber_payload_ship.get_rid()],
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var impact_position: Variant = hit.get("position", current_position)
	var impact_normal: Variant = hit.get("normal", Vector3.UP)
	if not impact_position is Vector3 or not impact_normal is Vector3:
		return
	var result := projectile.submit_impact(1, impact_position, impact_normal)
	if bool(result.get("accepted", false)):
		_consume_bomber_payload_terminal(projectile)


func _publish_bomber_payload_snapshot(bomber: CinderLongRangeBomber) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"apply_bomber_payload_snapshot"):
		return
	var authority := bomber.get_payload_authority_snapshot()
	var projectiles: Array[Dictionary] = []
	for projectile in _bomber_payload_projectiles:
		if projectile != null:
			projectiles.append(projectile.get_snapshot())
	if not _bomber_payload_hud_terminal_receipt.is_empty():
		projectiles.append(_bomber_payload_hud_terminal_receipt.duplicate(true))
	var snapshot := {
		"generation": int(authority.get("generation", _bomber_payload_generation)),
		"active": bool(authority.get("active", false)) and _piloting and bomber.is_piloted(),
		"ammo": int(authority.get("ammunition_remaining", 0)),
		"cooldown_remaining": float(authority.get("cooldown_remaining", 0.0)),
		"release_allowed": _bomber_payload_projectiles.size() < 4,
		"action_label": "RELEASE PAYLOAD",
		"action_glyph": "",
		"projectiles": projectiles,
		"adapter": _bomber_payload_adapter.get_snapshot(),
	}
	hud.call(&"apply_bomber_payload_snapshot", snapshot)


func _present_bomber_payload_audio(method: StringName, payload: Dictionary) -> void:
	if not is_instance_valid(world) or not world.has_method(&"get_fleet_expansion_production_binding"):
		return
	var binding := world.call(&"get_fleet_expansion_production_binding") as Node
	if is_instance_valid(binding) and binding.has_method(method):
		binding.call(method, &"cinder_long_range_bomber", payload)


func _publish_bomber_payload_network(
	projectile: BomberPayloadProjectile,
	terminal: bool,
	recipients: Array = [],
) -> Dictionary:
	if (
		projectile == null
		or not is_instance_valid(network_session)
		or not network_session.is_server()
		or _network_session_mode != &"server"
		or _bomber_payload_ship == null
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var snapshot := projectile.get_snapshot()
	var release_record := snapshot.get("release_record", {}) as Dictionary
	var projectile_id := StringName(release_record.get("record_id", &""))
	var generation := int(snapshot.get("generation", 0))
	var authority := _bomber_payload_ship.get_payload_authority_snapshot()
	if (
		projectile_id.is_empty()
		or not bool(snapshot.get("active", false))
		or generation <= 0
		or generation != _bomber_payload_generation
		or int(release_record.get("generation", 0)) != generation
		or not bool(authority.get("active", false))
		or int(authority.get("generation", 0)) != generation
	):
		return {"accepted": false, "status": &"stale_bomber_projectile_generation"}
	var terminal_intent := snapshot.get("terminal_intent", {}) as Dictionary
	if not _bomber_payload_network_records_match(
		projectile_id, generation, release_record, terminal_intent, terminal
	):
		return {"accepted": false, "status": &"invalid_bomber_projectile_record"}
	var velocity: Vector3 = snapshot.get("velocity", Vector3.FORWARD)
	var direction := velocity.normalized() if velocity.is_finite() and velocity.length_squared() > 0.000001 else Vector3.FORWARD
	var state := StringName(snapshot.get("state", &"flying"))
	if terminal and state == &"flying":
		state = &"terminal"
	var packet := {
		"projectile_id": projectile_id,
		"projectile_generation": generation,
		"source_entity_id": CINDER_BOMBER_SHIP_ID,
		"source_generation": generation,
		"owner_peer_id": 1,
		"position": snapshot.get("position", Vector3.ZERO),
		"direction": direction,
		"last_update_tick": _bomber_payload_server_tick,
		"state": state,
		"release_record": release_record.duplicate(true),
		"terminal_intent": (
			terminal_intent.duplicate(true)
			if terminal else {}
		),
	}
	var published: Dictionary = network_session.publish_projectile_snapshot(
		packet, recipients, terminal, _bomber_payload_server_tick, true, true
	)
	_last_bomber_payload_network_result = published.duplicate(true)
	if bool(published.get("accepted", false)):
		_bomber_payload_canonical_publish_pending = true
	return published


func _ensure_bomber_payload_network_source() -> Dictionary:
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or _network_session_mode != &"server"
	):
		return {"accepted": true, "status": &"solo_projectile_source"}
	if _bomber_payload_ship == null or _bomber_payload_generation <= 0:
		return {"accepted": false, "status": &"bomber_payload_source_unavailable"}
	var registered: Dictionary = network_session.get_projectile_source_snapshot(
		CINDER_BOMBER_SHIP_ID
	)
	if not registered.is_empty():
		var registered_generation := int(registered.get("source_generation", 0))
		if (
			registered_generation == _bomber_payload_generation
			and int(registered.get("owner_peer_id", 0)) == 1
		):
			_bomber_payload_network_source_generation = registered_generation
			return {"accepted": true, "status": &"bomber_projectile_source_current"}
		var retired: Dictionary = network_session.retire_projectile_source(
			CINDER_BOMBER_SHIP_ID, registered_generation
		)
		if not bool(retired.get("accepted", false)):
			return retired
	var result: Dictionary = network_session.register_projectile_source(
		1,
		CINDER_BOMBER_SHIP_ID,
		_bomber_payload_generation,
		&"player",
		CINDER_BOMBER_NETWORK_PROJECTILE_PROFILES,
	)
	if bool(result.get("accepted", false)):
		_bomber_payload_network_source_generation = _bomber_payload_generation
	return result


func _retire_bomber_payload_network_source() -> Dictionary:
	var generation := _bomber_payload_network_source_generation
	_bomber_payload_network_source_generation = 0
	if generation <= 0:
		return {"accepted": true, "status": &"bomber_projectile_source_not_registered"}
	if not is_instance_valid(network_session) or not network_session.is_server():
		return {"accepted": true, "status": &"network_projectile_source_already_stopped"}
	return network_session.retire_projectile_source(
		CINDER_BOMBER_SHIP_ID, generation
	)


func _publish_bomber_payload_canonical_snapshot(force: bool = false) -> Dictionary:
	if not force and not _bomber_payload_canonical_publish_pending:
		return {"accepted": true, "status": &"projectile_canonical_snapshot_current"}
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or _network_session_mode != &"server"
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var published: Dictionary = network_session.publish_projectile_canonical_snapshot(
		_bomber_payload_server_tick
	)
	_last_bomber_payload_canonical_result = published.duplicate(true)
	if bool(published.get("accepted", false)):
		_bomber_payload_canonical_publish_pending = false
	return published


func _republish_bomber_payloads_for_peer(peer_id: int) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server():
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var published := 0
	for projectile in _bomber_payload_projectiles:
		if projectile == null:
			continue
		var result := _publish_bomber_payload_network(projectile, false, [peer_id])
		if not bool(result.get("accepted", false)):
			return result
		published += 1
	var canonical := _publish_bomber_payload_canonical_snapshot(true)
	if not bool(canonical.get("accepted", false)):
		return canonical
	return {
		"accepted": true,
		"status": &"game_flow_projectile_resync_published",
		"peer_id": peer_id,
		"projectile_count": published,
		"canonical_revision": int(canonical.get("revision", 0)),
	}.duplicate(true)


func _prepare_player_pulse_network_context(
	request: ShotRequestType,
	endpoint: Vector3,
	style_id: StringName,
	result: Dictionary,
) -> void:
	_player_pulse_network_context.clear()
	if (
		_network_session_mode != &"server"
		or not is_instance_valid(network_session)
		or not network_session.is_server()
		or not is_instance_valid(request.source_entity)
		or request.source_entity != active_ship
		or not request.source_entity is HeroShip
		or (request.source_entity as HeroShip).get_ship_id() != TORRENT_SHIP_ID
		or _network_ship_generation <= 0
	):
		return
	_player_pulse_network_sequence += 1
	var projectile_id := StringName(
		"torrent_pulse_g%06d_s%06d"
		% [_network_ship_generation, _player_pulse_network_sequence]
	)
	_player_pulse_network_context = {
		"projectile_id": projectile_id,
		"projectile_generation": _network_ship_generation,
		"source_entity_id": TORRENT_SHIP_ID,
		"source_generation": _network_ship_generation,
		"owner_peer_id": 1,
		"position": request.origin,
		"direction": request.get_normalized_direction(),
		# The existing adapter uses `flying` as its sole live wire state and
		# promotes the first admitted generation to canonical `spawned`.
		"state": &"flying",
		"pulse_record": {
			"projectile_id": projectile_id,
			"projectile_generation": _network_ship_generation,
			"source_entity_id": TORRENT_SHIP_ID,
			"source_generation": _network_ship_generation,
			"weapon_id": request.weapon_id,
			"origin": request.origin,
			"endpoint": endpoint,
			"style_id": style_id,
			"hit": bool(result.get("hit", false)),
		},
		"terminal_intent": {},
		"presentation_source_instance_id": request.source_entity.get_instance_id(),
	}


func _prepare_opponent_pulse_network_context(
	request: ShotRequestType,
	endpoint: Vector3,
	style_id: StringName,
	result: Dictionary,
) -> void:
	_opponent_pulse_network_context.clear()
	var identity := _get_opponent_pulse_network_identity(request)
	if (
		_network_session_mode != &"server"
		or not is_instance_valid(network_session)
		or not network_session.is_server()
		or identity.is_empty()
	):
		return
	_opponent_pulse_network_sequence += 1
	var generation := int(identity.get("source_generation", 0))
	var source_entity_id := StringName(identity.get("source_entity_id", &""))
	var projectile_id := StringName(
		"%s_pulse_g%06d_s%06d"
		% [String(source_entity_id), generation, _opponent_pulse_network_sequence]
	)
	_opponent_pulse_network_context = {
		"projectile_id": projectile_id,
		"projectile_generation": generation,
		"source_entity_id": source_entity_id,
		"source_generation": generation,
		"owner_peer_id": 1,
		"position": request.origin,
		"direction": request.get_normalized_direction(),
		"state": &"flying",
		"opponent_pulse_record": {
			"projectile_id": projectile_id,
			"projectile_generation": generation,
			"source_entity_id": source_entity_id,
			"source_generation": generation,
			"source_id": int(identity.get("source_id", 0)),
			"weapon_id": request.weapon_id,
			"hostile_id": identity.get("hostile_id", &""),
			"handle_generation": int(identity.get("handle_generation", 0)),
			"activity_generation": int(identity.get("activity_generation", 0)),
			"origin": request.origin,
			"endpoint": endpoint,
			"style_id": style_id,
			"hit": bool(result.get("hit", false)),
		},
		"terminal_intent": {},
		"presentation_source_instance_id": request.source_entity.get_instance_id(),
	}


func _get_opponent_pulse_network_identity(request: ShotRequestType) -> Dictionary:
	if (
		is_instance_valid(opponent)
		and request.source_entity == opponent
		and request.source_id == OPPONENT_SOURCE_ID
		and request.weapon_id == OPPONENT_WEAPON_ID
		and _opponent_pulse_network_generation > 0
	):
		return {
			"source_entity_id": RANGE_OPPONENT_NETWORK_ID,
			"source_generation": _opponent_pulse_network_generation,
			"source_id": OPPONENT_SOURCE_ID,
		}.duplicate(true)
	if (
		not request.source_entity is RangeOpponent
		or request.weapon_id != STATION_DEFENSE_WEAPON_ID
	):
		return {}
	var content := _get_station_defense_content()
	var source := request.source_entity as RangeOpponent
	if not is_instance_valid(content) or not content.is_ancestor_of(source):
		return {}
	var hostile_id := StringName(source.get_meta("hostile_id", &""))
	var handle_generation := int(source.get_meta("handle_generation", 0))
	var activity_generation := int(content.get_generation())
	if (
		hostile_id.is_empty()
		or handle_generation <= 0
		or activity_generation <= 0
		or request.source_id <= 0
	):
		return {}
	return {
		"source_entity_id": StringName(STATION_DEFENSE_NETWORK_PREFIX + String(hostile_id)),
		"source_generation": activity_generation,
		"source_id": request.source_id,
		"hostile_id": hostile_id,
		"handle_generation": handle_generation,
		"activity_generation": activity_generation,
	}.duplicate(true)


func _get_station_defense_content() -> StationDefenseEncounterContent:
	if not is_instance_valid(world) or not world.has_method(&"get_station_defense_content"):
		return null
	return world.call(&"get_station_defense_content") as StationDefenseEncounterContent


func _on_pulse_shot_presented(
	shot_id: int,
	_style_id: StringName,
	source_instance_id: int,
	_hit: bool,
) -> void:
	var context := (
		_player_pulse_network_context
		if not _player_pulse_network_context.is_empty()
		else _opponent_pulse_network_context
	)
	if context.is_empty() or shot_id <= 0:
		return
	if source_instance_id != int(context.get("presentation_source_instance_id", 0)):
		_player_pulse_network_context.clear()
		_opponent_pulse_network_context.clear()
		return
	var record := context.duplicate(true)
	record.erase("presentation_source_instance_id")
	_player_pulse_network_server_tick += 1
	record["last_update_tick"] = _player_pulse_network_server_tick
	_player_pulse_network_active_shots[shot_id] = record.duplicate(true)
	_queue_player_pulse_network_publication(record, false)


func _on_pulse_impact_started(
	shot_id: int,
	style_id: StringName,
	source_instance_id: int,
	position: Vector3
	) -> void:
	# The pulse owns travel timing; its endpoint event is the first frame on which
	# the positional impact cue is allowed to start. A separate fixed pool lets a
	# close impact overlap the already travelling fire transient.
	var impact_weight := 0.45 if style_id == &"amber" else 0.9
	combat_audio.play_impact(position, impact_weight, maxi(source_instance_id, 0))
	_terminalize_player_pulse_network_shot(shot_id, &"impact", position)


func _on_pulse_shot_finished(shot_id: int) -> void:
	_terminalize_player_pulse_network_shot(shot_id, &"expiry")


func _on_pulse_shot_recycled(retired_shot_id: int, _replacement_shot_id: int) -> void:
	_terminalize_player_pulse_network_shot(retired_shot_id, &"abort")


func _on_pulse_effects_cleared() -> void:
	if _network_session_mode == &"server":
		for shot_id_variant: Variant in _player_pulse_network_active_shots.keys():
			_terminalize_player_pulse_network_shot(int(shot_id_variant), &"abort")
	elif _network_session_mode == &"client":
		_player_pulse_replica_generations.clear()
		_opponent_pulse_replica_generations.clear()


func _terminalize_player_pulse_network_shot(
	shot_id: int,
	kind: StringName,
	position: Vector3 = Vector3.INF,
) -> void:
	var active := _player_pulse_network_active_shots.get(shot_id, {}) as Dictionary
	if active.is_empty():
		return
	_player_pulse_network_active_shots.erase(shot_id)
	var terminal := active.duplicate(true)
	var pulse_record_key := (
		"pulse_record" if terminal.has("pulse_record") else "opponent_pulse_record"
	)
	var pulse_record := terminal.get(pulse_record_key, {}) as Dictionary
	var endpoint := pulse_record.get("endpoint", terminal.get("position", Vector3.ZERO)) as Vector3
	terminal["position"] = position if position.is_finite() else endpoint
	terminal["state"] = &"expired" if kind == &"expiry" else (&"aborted" if kind == &"abort" else &"resolved")
	terminal["terminal_intent"] = (
		{}
		if kind == &"abort"
		else {
			"kind": kind,
			"projectile_id": terminal.get("projectile_id", &""),
			"projectile_generation": int(terminal.get("projectile_generation", 0)),
			"source_generation": int(terminal.get("source_generation", 0)),
		}
	)
	pulse_record["terminal_kind"] = kind
	terminal[pulse_record_key] = pulse_record
	_player_pulse_network_server_tick += 1
	terminal["last_update_tick"] = _player_pulse_network_server_tick
	_queue_player_pulse_network_publication(terminal, true)


func _queue_player_pulse_network_publication(record: Dictionary, terminal: bool) -> void:
	_player_pulse_network_pending.append({
		"record": record.duplicate(true),
		"terminal": terminal,
	})
	while _player_pulse_network_pending.size() > PLAYER_PULSE_NETWORK_MAX_PENDING:
		_player_pulse_network_pending.pop_front()
	_retry_player_pulse_network_publications()


func _retry_player_pulse_network_publications() -> Dictionary:
	if (
		_network_session_mode != &"server"
		or not is_instance_valid(network_session)
		or not network_session.is_server()
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	while not _player_pulse_network_pending.is_empty():
		var pending := _player_pulse_network_pending[0]
		var record := pending.get("record", {}) as Dictionary
		var published: Dictionary = network_session.publish_projectile_snapshot(
			record,
			[],
			bool(pending.get("terminal", false)),
			int(record.get("last_update_tick", 0)),
		)
		_last_player_pulse_network_result = published.duplicate(true)
		if not bool(published.get("accepted", false)):
			return published
		_player_pulse_network_pending.pop_front()
		_player_pulse_canonical_publish_pending = true
	if not _player_pulse_canonical_publish_pending:
		return {"accepted": true, "status": &"player_pulse_network_current"}
	var canonical := network_session.publish_projectile_canonical_snapshot(
		_player_pulse_network_server_tick
	)
	_last_player_pulse_canonical_result = canonical.duplicate(true)
	if bool(canonical.get("accepted", false)):
		_player_pulse_canonical_publish_pending = false
	return canonical


func _republish_player_pulses_for_peer(peer_id: int) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server():
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var published_count := 0
	for shot_variant: Variant in _player_pulse_network_active_shots.values():
		var record := shot_variant as Dictionary
		var published: Dictionary = network_session.publish_projectile_snapshot(
			record, [peer_id], false, int(record.get("last_update_tick", 0)), false
		)
		_last_player_pulse_network_result = published.duplicate(true)
		if not bool(published.get("accepted", false)):
			return published
		published_count += 1
		_player_pulse_canonical_publish_pending = true
	var canonical := _retry_player_pulse_network_publications()
	if not bool(canonical.get("accepted", false)):
		return canonical
	return {
		"accepted": true,
		"status": &"player_pulse_resync_published",
		"peer_id": peer_id,
		"projectile_count": published_count,
	}.duplicate(true)


func _on_player_pulse_replica_packet(packet: Dictionary, result: Dictionary) -> Dictionary:
	var projectile := packet.get("projectile", {}) as Dictionary
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var generation := int(projectile.get("projectile_generation", 0))
	var migration_generation := int(packet.get("migration_generation", 0))
	var status := StringName(result.get("status", &""))
	var lifecycle := network_session.get_projectile_replica_lifecycle_snapshot()
	var admitted := lifecycle.get("generations", {}) as Dictionary
	var terminals := lifecycle.get("terminal_generations", {}) as Dictionary
	if (
		projectile_id.is_empty()
		or generation <= 0
		or migration_generation <= 0
		or int(lifecycle.get("migration_generation", 0)) != migration_generation
		or int(admitted.get(projectile_id, 0)) != generation
		or status not in [&"projectile_presented", &"projectile_terminal_applied"]
		or (
			status == &"projectile_terminal_applied"
			and int(terminals.get(projectile_id, 0)) != generation
		)
	):
		return {"accepted": false, "status": &"projectile_lifecycle_receipt_mismatch"}
	var pulse_record := projectile.get("pulse_record", {}) as Dictionary
	var origin_variant: Variant = pulse_record.get("origin")
	var endpoint_variant: Variant = pulse_record.get("endpoint")
	if (
		StringName(projectile.get("source_entity_id", &"")) != TORRENT_SHIP_ID
		or int(projectile.get("source_generation", 0)) != generation
		or StringName(pulse_record.get("projectile_id", &"")) != projectile_id
		or int(pulse_record.get("projectile_generation", 0)) != generation
		or int(pulse_record.get("source_generation", 0)) != generation
		or StringName(pulse_record.get("source_entity_id", &"")) != TORRENT_SHIP_ID
		or StringName(pulse_record.get("weapon_id", &"")) not in [RANGE_WEAPON_ID, TORRENT_COMBAT_WEAPON_ID]
		or not origin_variant is Vector3
		or not (origin_variant as Vector3).is_finite()
		or not endpoint_variant is Vector3
		or not (endpoint_variant as Vector3).is_finite()
	):
		return {"accepted": false, "status": &"invalid_player_pulse_record"}
	if migration_generation != _player_pulse_replica_migration_generation:
		_clear_player_pulse_replica_presentation(migration_generation)
	if status == &"projectile_terminal_applied":
		_player_pulse_replica_generations.erase(projectile_id)
		return {"accepted": true, "status": &"player_pulse_terminal_presented"}
	if int(_player_pulse_replica_generations.get(projectile_id, 0)) == generation:
		return {"accepted": true, "status": &"player_pulse_already_presented"}
	var presented := _present_pulse_shot(
		origin_variant as Vector3,
		endpoint_variant as Vector3,
		StringName(pulse_record.get("style_id", &"cyan")),
		null,
		bool(pulse_record.get("hit", false)),
	)
	if not presented:
		return {"accepted": false, "status": &"player_pulse_presentation_rejected"}
	_player_pulse_replica_generations[projectile_id] = generation
	return {"accepted": true, "status": &"player_pulse_presented"}


func _on_opponent_pulse_replica_packet(packet: Dictionary, result: Dictionary) -> Dictionary:
	var projectile := packet.get("projectile", {}) as Dictionary
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var generation := int(projectile.get("projectile_generation", 0))
	var migration_generation := int(packet.get("migration_generation", 0))
	var status := StringName(result.get("status", &""))
	var lifecycle := network_session.get_projectile_replica_lifecycle_snapshot()
	var admitted := lifecycle.get("generations", {}) as Dictionary
	var terminals := lifecycle.get("terminal_generations", {}) as Dictionary
	if (
		projectile_id.is_empty()
		or generation <= 0
		or migration_generation <= 0
		or int(lifecycle.get("migration_generation", 0)) != migration_generation
		or int(admitted.get(projectile_id, 0)) != generation
		or status not in [&"projectile_presented", &"projectile_terminal_applied"]
		or (
			status == &"projectile_terminal_applied"
			and int(terminals.get(projectile_id, 0)) != generation
		)
	):
		return {"accepted": false, "status": &"projectile_lifecycle_receipt_mismatch"}
	var pulse_record := projectile.get("opponent_pulse_record", {}) as Dictionary
	var origin_variant: Variant = pulse_record.get("origin")
	var endpoint_variant: Variant = pulse_record.get("endpoint")
	if (
		int(projectile.get("source_generation", 0)) != generation
		or StringName(pulse_record.get("projectile_id", &"")) != projectile_id
		or int(pulse_record.get("projectile_generation", 0)) != generation
		or int(pulse_record.get("source_generation", 0)) != generation
		or StringName(pulse_record.get("source_entity_id", &""))
			!= StringName(projectile.get("source_entity_id", &""))
		or not _opponent_pulse_record_identity_is_valid(projectile, pulse_record, generation)
		or StringName(pulse_record.get("style_id", &"")) != &"amber"
		or not origin_variant is Vector3
		or not (origin_variant as Vector3).is_finite()
		or not endpoint_variant is Vector3
		or not (endpoint_variant as Vector3).is_finite()
	):
		return {"accepted": false, "status": &"invalid_opponent_pulse_record"}
	if migration_generation != _player_pulse_replica_migration_generation:
		_clear_player_pulse_replica_presentation(migration_generation)
	if status == &"projectile_terminal_applied":
		_opponent_pulse_replica_generations.erase(projectile_id)
		return {"accepted": true, "status": &"opponent_pulse_terminal_presented"}
	if int(_opponent_pulse_replica_generations.get(projectile_id, 0)) == generation:
		return {"accepted": true, "status": &"opponent_pulse_already_presented"}
	var presented := _present_pulse_shot(
		origin_variant as Vector3,
		endpoint_variant as Vector3,
		&"amber",
		null,
		bool(pulse_record.get("hit", false)),
	)
	if not presented:
		return {"accepted": false, "status": &"opponent_pulse_presentation_rejected"}
	_opponent_pulse_replica_generations[projectile_id] = generation
	return {"accepted": true, "status": &"opponent_pulse_presented"}


func _opponent_pulse_record_identity_is_valid(
	projectile: Dictionary,
	pulse_record: Dictionary,
	generation: int,
) -> bool:
	var source_entity_id := StringName(projectile.get("source_entity_id", &""))
	var source_id := int(pulse_record.get("source_id", 0))
	var weapon_id := StringName(pulse_record.get("weapon_id", &""))
	if source_entity_id == RANGE_OPPONENT_NETWORK_ID:
		return source_id == OPPONENT_SOURCE_ID and weapon_id == OPPONENT_WEAPON_ID
	var hostile_id := StringName(pulse_record.get("hostile_id", &""))
	return (
		not hostile_id.is_empty()
		and source_entity_id
			== StringName(STATION_DEFENSE_NETWORK_PREFIX + String(hostile_id))
		and weapon_id == STATION_DEFENSE_WEAPON_ID
		and source_id == int(STATION_DEFENSE_SOURCE_IDS.get(hostile_id, 0))
		and int(pulse_record.get("handle_generation", 0)) > 0
		and int(pulse_record.get("activity_generation", 0)) == generation
	)


func _clear_player_pulse_replica_presentation(migration_generation: int = 0) -> void:
	_player_pulse_replica_generations.clear()
	_opponent_pulse_replica_generations.clear()
	_player_pulse_replica_migration_generation = maxi(0, migration_generation)
	if is_instance_valid(pulse_presentation):
		pulse_presentation.clear_effects()


func _on_projectile_replica_packet(packet: Dictionary, result: Dictionary) -> Dictionary:
	if _network_session_mode != &"client" or not bool(result.get("accepted", false)) \
			or not is_instance_valid(network_session) or network_session.is_server():
		return {"accepted": false, "status": &"client_replica_authority_required"}
	var projectile := packet.get("projectile", {}) as Dictionary
	if StringName(projectile.get("source_entity_id", &"")) == TORRENT_SHIP_ID:
		return _on_player_pulse_replica_packet(packet, result)
	if projectile.has("opponent_pulse_record"):
		return _on_opponent_pulse_replica_packet(packet, result)
	if StringName(projectile.get("source_entity_id", &"")) != CINDER_BOMBER_SHIP_ID:
		return {"accepted": false, "status": &"unrelated_projectile"}
	var migration_generation := int(packet.get("migration_generation", 0))
	if migration_generation <= 0:
		return {"accepted": false, "status": &"invalid_migration_generation"}
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var generation := int(projectile.get("projectile_generation", 0))
	if projectile_id.is_empty() or generation <= 0 \
			or int(projectile.get("owner_peer_id", 0)) != 1:
		return {"accepted": false, "status": &"invalid_projectile_identity"}
	var status := StringName(result.get("status", &""))
	if status not in [&"projectile_presented", &"projectile_terminal_applied"]:
		return {"accepted": false, "status": &"projectile_not_presentable"}
	var lifecycle := network_session.get_projectile_replica_lifecycle_snapshot()
	var admitted_generations := lifecycle.get("generations", {}) as Dictionary
	var terminal_generations := lifecycle.get("terminal_generations", {}) as Dictionary
	if (
		int(lifecycle.get("migration_generation", 0)) != migration_generation
		or int(admitted_generations.get(projectile_id, 0)) != generation
		or (
			status == &"projectile_terminal_applied"
			and int(terminal_generations.get(projectile_id, 0)) != generation
		)
	):
		return {"accepted": false, "status": &"projectile_lifecycle_receipt_mismatch"}
	var release_record := projectile.get("release_record", {}) as Dictionary
	var terminal_intent := projectile.get("terminal_intent", {}) as Dictionary
	if (
		int(projectile.get("source_generation", 0)) != generation
		or not _bomber_payload_network_records_match(
			projectile_id, generation, release_record, terminal_intent,
			status == &"projectile_terminal_applied"
		)
	):
		return {"accepted": false, "status": &"invalid_bomber_projectile_record"}
	# Migration cleanup occurs only after both the transport lifecycle receipt and
	# the nested bomber records agree, so malformed future packets are atomic at
	# the production presentation boundary.
	if migration_generation != _bomber_payload_replica_migration_generation:
		_clear_bomber_payload_replica_presentation(migration_generation)
	var bomber := _find_flyable_ship_by_id(CINDER_BOMBER_SHIP_ID) as CinderLongRangeBomber
	if not is_instance_valid(bomber):
		return {"accepted": false, "status": &"bomber_replica_unavailable"}
	if status == &"projectile_terminal_applied":
		if terminal_intent.is_empty():
			_clear_bomber_payload_replica_presentation(migration_generation, false)
			_publish_bomber_payload_replica_hud_snapshot(projectile)
			return {"accepted": true, "status": &"bomber_projectile_abort_presented"}
		var terminal_result := bomber.present_payload_terminal_record(terminal_intent)
		if not bool(terminal_result.get("accepted", false)):
			return {"accepted": false, "status": &"bomber_terminal_presentation_rejected"}
		_publish_bomber_payload_replica_hud_snapshot(projectile)
		_bomber_payload_replica_generations[projectile_id] = generation
		return {"accepted": true, "status": &"bomber_projectile_terminal_presented"}
	var prior_generation := int(_bomber_payload_replica_generations.get(projectile_id, 0))
	if prior_generation == generation:
		_publish_bomber_payload_replica_hud_snapshot(projectile)
		return {"accepted": true, "status": &"bomber_projectile_already_presented"}
	if prior_generation > 0:
		_clear_bomber_payload_replica_presentation(migration_generation)
	var presentation = bomber.get_payload_presentation()
	if not is_instance_valid(presentation):
		return {"accepted": false, "status": &"bomber_replica_unavailable"}
	var presented: Dictionary = presentation.consume_release_record(release_record)
	if bool(presented.get("accepted", false)):
		_publish_bomber_payload_replica_hud_snapshot(projectile)
		_bomber_payload_replica_generations[projectile_id] = generation
		return {"accepted": true, "status": &"bomber_projectile_presented"}
	return {"accepted": false, "status": &"bomber_release_presentation_rejected"}


func _bomber_payload_network_records_match(
	projectile_id: StringName,
	generation: int,
	release_record: Dictionary,
	terminal_intent: Dictionary,
	terminal: bool,
) -> bool:
	if (
		projectile_id.is_empty()
		or generation <= 0
		or StringName(release_record.get("record_id", &"")) != projectile_id
		or not release_record.get("generation") is int
		or int(release_record.get("generation", 0)) != generation
		or not release_record.get("release_sequence") is int
		or int(release_record.get("release_sequence", 0)) <= 0
		or projectile_id != StringName(
			"bomber_payload_release_%06d" % int(release_record.get("release_sequence", 0))
		)
		or not release_record.get("request_sequence") is int
		or int(release_record.get("request_sequence", 0)) <= 0
	):
		return false
	if not terminal:
		return terminal_intent.is_empty()
	# An empty terminal record is the explicit authority-detach tombstone. A real
	# impact/expiry must echo every release fence before it can reach presentation.
	if terminal_intent.is_empty():
		return true
	return (
		StringName(terminal_intent.get("record_id", &"")) == projectile_id
		and terminal_intent.get("generation") is int
		and int(terminal_intent.get("generation", 0)) == generation
		and terminal_intent.get("release_sequence") is int
		and int(terminal_intent.get("release_sequence", 0))
			== int(release_record.get("release_sequence", 0))
		and terminal_intent.get("request_sequence") is int
		and int(terminal_intent.get("request_sequence", 0))
			== int(release_record.get("request_sequence", 0))
	)


func _clear_bomber_payload_replica_presentation(
		migration_generation: int = 0,
		clear_hud_status: bool = true,
) -> void:
	var bomber := _find_flyable_ship_by_id(CINDER_BOMBER_SHIP_ID) as CinderLongRangeBomber
	if is_instance_valid(bomber):
		var presentation = bomber.get_payload_presentation()
		if is_instance_valid(presentation):
			presentation.detach()
			presentation.reset_for_reuse()
	_bomber_payload_replica_generations.clear()
	_bomber_payload_replica_migration_generation = maxi(0, migration_generation)
	if clear_hud_status and is_instance_valid(hud) \
			and hud.has_method(&"clear_bomber_payload_status"):
		hud.call(&"clear_bomber_payload_status")


func _publish_bomber_payload_replica_hud_snapshot(projectile: Dictionary) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"apply_bomber_payload_snapshot"):
		return
	var raw_generation: Variant = projectile.get("projectile_generation", null)
	if not raw_generation is int:
		return
	var generation := int(raw_generation)
	var release_record := projectile.get("release_record", {}) as Dictionary
	var raw_ammunition: Variant = release_record.get("ammunition_remaining", null)
	var raw_cooldown: Variant = release_record.get("cooldown_remaining", null)
	if generation <= 0 or int(release_record.get("generation", 0)) != generation \
			or not raw_ammunition is int or not raw_cooldown is float:
		return
	var snapshot := {
		"generation": generation,
		"active": true,
		"ammo": int(raw_ammunition),
		"cooldown_remaining": float(raw_cooldown),
		"release_allowed": false,
		"release_denied_reason": &"server_authority",
		"projectiles": [projectile.duplicate(true)],
		"adapter": {},
	}
	hud.call(&"apply_bomber_payload_snapshot", snapshot)


func _clear_bomber_payload_loop(reason: StringName) -> void:
	for projectile in _bomber_payload_projectiles:
		if projectile != null:
			var release_record := projectile.get_snapshot().get("release_record", {}) as Dictionary
			if is_instance_valid(network_session) and network_session.is_server():
				_bomber_payload_server_tick += 1
				_publish_bomber_payload_network(projectile, true)
			if not release_record.is_empty():
				_present_bomber_payload_audio(&"present_payload_abort", release_record)
				_present_bomber_payload_audio(&"present_projectile_abort", release_record)
			projectile.detach(reason)
	_bomber_payload_projectiles.clear()
	_bomber_payload_hud_terminal_receipt.clear()
	_publish_bomber_payload_canonical_snapshot()
	_retire_bomber_payload_network_source()
	if _bomber_payload_adapter != null:
		if bool(_bomber_payload_adapter.get_snapshot().get("active", false)):
			_bomber_payload_adapter.detach(reason)
	if _bomber_payload_ship != null:
		if bool(_bomber_payload_ship.get_payload_authority_snapshot().get("active", false)):
			_bomber_payload_ship.detach_payload_authority(reason)
		_present_bomber_payload_audio(&"end_payload_audio_generation", {})
	_bomber_payload_adapter = null
	_bomber_payload_ship = null
	_bomber_payload_request_sequence = 0
	_last_bomber_payload_result = {"accepted": true, "reason": reason, "cleared": true}
	if is_instance_valid(hud) and hud.has_method(&"clear_bomber_payload_status"):
		hud.call(&"clear_bomber_payload_status")


func get_bomber_payload_loop_snapshot() -> Dictionary:
	var projectiles: Array[Dictionary] = []
	for projectile in _bomber_payload_projectiles:
		if projectile != null:
			projectiles.append(projectile.get_snapshot())
	return {
		"active": _bomber_payload_ship != null and _bomber_payload_adapter != null,
		"generation": _bomber_payload_generation,
		"request_sequence": _bomber_payload_request_sequence,
		"ship_id": _bomber_payload_ship.get_ship_id() if _bomber_payload_ship != null else &"",
		"projectiles": projectiles,
		"adapter": _bomber_payload_adapter.get_snapshot() if _bomber_payload_adapter != null else {},
		"last_result": _last_bomber_payload_result.duplicate(true),
		"canonical_publish_pending": _bomber_payload_canonical_publish_pending,
		"last_network_result": _last_bomber_payload_network_result.duplicate(true),
		"last_canonical_result": _last_bomber_payload_canonical_result.duplicate(true),
	}.duplicate(true)


func _capture_cinder_actor_sample() -> Dictionary:
	# The retained surface Host temporarily owns embodiment without rewriting
	# GameFlow's sortie-level `_piloting` latch. Once it begins disembarkation the
	# Player is the common-origin observation, including during the two public
	# boarding transitions; selecting the ship from `_piloting` here would freeze
	# the on-foot route at its first frame.
	var ember_surface_phase := (
		ember_surface_loop_production_binding.get_host_phase()
		if _ember_surface_journey_active
			and is_instance_valid(ember_surface_loop_production_binding)
		else -1
	)
	if ember_surface_phase in [
		EmberSurfaceLoopHost.Phase.DISEMBARKING,
		EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND,
		EmberSurfaceLoopHost.Phase.ON_FOOT,
		EmberSurfaceLoopHost.Phase.BOARDING,
	] and is_instance_valid(player) and player.is_inside_tree():
		var surface_player_position := player.global_position
		_cinder_actor_sample_count += 1
		if surface_player_position.is_finite():
			return {
				"available": true,
				"position": surface_player_position,
				"actor_kind": &"player",
				"actor_instance_id": player.get_instance_id(),
			}
		return {"available": false, "reason": &"nonfinite_player_position"}
	if (
		is_instance_valid(active_ship)
		and active_ship.is_inside_tree()
		and (_piloting or active_ship.is_piloted())
		and not active_ship.is_destroyed()
	):
		var ship_position := active_ship.global_position
		_cinder_actor_sample_count += 1
		if ship_position.is_finite():
			return {
				"available": true,
				"position": ship_position,
				"actor_kind": &"ship",
				"actor_instance_id": active_ship.get_instance_id(),
			}
		return {"available": false, "reason": &"nonfinite_active_ship_position"}
	if is_instance_valid(player) and player.is_inside_tree():
		var player_position := player.global_position
		_cinder_actor_sample_count += 1
		if player_position.is_finite():
			return {
				"available": true,
				"position": player_position,
				"actor_kind": &"player",
				"actor_instance_id": player.get_instance_id(),
			}
		return {"available": false, "reason": &"nonfinite_player_position"}
	return {"available": false, "reason": &"no_tracked_production_actor"}


## Forwards the one already-adjusted common-origin observation to the retained
## surface scheduler. GameFlow selects the embodied actor and phase-specific
## intents, while the binding remains the sole same-frame Host advancement
## owner and the actors remain the sole physical movers.
func _advance_ember_surface_loop_cadence(
	delta: float,
	actor_sample: Dictionary,
	origin_result: Dictionary,
	coordinate_frame_generation: int,
) -> Dictionary:
	if not _ember_surface_journey_active \
			or not _ember_final_approach_handoff_ready \
			or not is_instance_valid(ember_surface_loop_production_binding) \
			or not is_instance_valid(active_ship) \
			or not is_instance_valid(player):
		return {"accepted": false, "reason": &"ember_surface_cadence_unavailable"}
	var binding_snapshot := ember_surface_loop_production_binding.get_snapshot()
	if StringName(binding_snapshot.get("state_id", &"")) \
			not in [&"idle", &"start_pending", &"running"]:
		return {"accepted": false, "reason": &"ember_surface_cadence_inactive"}
	if origin_result.is_empty() or not bool(origin_result.get("accepted", false)) \
			or not bool(actor_sample.get("available", false)) \
			or coordinate_frame_generation < 1:
		return {"accepted": false, "reason": &"ember_surface_observation_unavailable"}
	var actor_kind := StringName(actor_sample.get("actor_kind", &""))
	var actor_instance_id := int(actor_sample.get("actor_instance_id", 0))
	var actor_position_value: Variant = actor_sample.get("position", Vector3.INF)
	if actor_kind not in [&"ship", &"player"] \
			or not actor_position_value is Vector3 \
			or not (actor_position_value as Vector3).is_finite() \
			or (actor_kind == &"ship" and actor_instance_id != active_ship.get_instance_id()) \
			or (actor_kind == &"player" and actor_instance_id != player.get_instance_id()):
		return {"accepted": false, "reason": &"ember_surface_actor_sample_mismatch"}
	var location_generation := int(
		(binding_snapshot.get("identities", {}) as Dictionary).get(
			"location_generation", 0
		)
	)
	if location_generation < 1 \
			or _ember_surface_caller_serial >= EmberSurfaceLoopHost.MAX_SAFE_INTEGER:
		return {"accepted": false, "reason": &"ember_surface_generation_unavailable"}
	_ember_surface_caller_serial += 1
	var telemetry := active_ship.get_telemetry()
	var host_phase := ember_surface_loop_production_binding.get_host_phase()
	var advanced := ember_surface_loop_production_binding.advance_from_caller_sample(
		_ember_surface_caller_serial,
		delta,
		actor_kind,
		actor_instance_id,
		active_ship.get_instance_id(),
		actor_position_value as Vector3,
		active_ship.velocity,
		bool(telemetry.get("landed", false)),
		false,
		false,
		origin_result,
		coordinate_frame_generation,
		location_generation,
		ember_surface_loop_production_binding.get_generation(),
	)
	if not bool(advanced.get("accepted", false)):
		return advanced
	var intent_result: Dictionary = {}
	if host_phase == EmberSurfaceLoopHost.Phase.LANDED \
			and str(telemetry.get("engine_state", "ONLINE")) == "OFFLINE":
		intent_result = _queue_ember_surface_intent(&"disembark")
	elif host_phase == EmberSurfaceLoopHost.Phase.REBOARDED:
		intent_result = _queue_ember_surface_intent(&"takeoff")
	if not intent_result.is_empty():
		advanced["intent"] = intent_result.duplicate(true)
	return advanced.duplicate(true)


## Queues one lifecycle intent against the exact early envelope prepared in the
## current physics frame. Re-entry drops that envelope in the production
## binding, so no GameFlow latch can replay an intent into a later tree epoch.
func _queue_ember_surface_intent(intent_id: StringName) -> Dictionary:
	if not is_instance_valid(ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"ember_surface_binding_unavailable"}
	var snapshot := ember_surface_loop_production_binding.get_snapshot()
	if StringName(snapshot.get("state_id", &"")) != &"running":
		return {"accepted": false, "reason": &"ember_surface_intent_out_of_order"}
	var pending := snapshot.get("pending_envelope", {}) as Dictionary
	if pending.is_empty() \
			or int(pending.get("physics_frame", -1)) != int(Engine.get_physics_frames()) \
			or not (snapshot.get("pending_intent", {}) as Dictionary).is_empty():
		return {"accepted": false, "reason": &"ember_surface_intent_without_current_tick"}
	var intent_serial := int(snapshot.get("last_intent_serial", 0)) + 1
	match intent_id:
		&"disembark":
			return ember_surface_loop_production_binding.queue_disembark_intent(
				intent_serial, ember_surface_loop_production_binding.get_generation()
			)
		&"reboard":
			return ember_surface_loop_production_binding.queue_reboard_intent(
				intent_serial, ember_surface_loop_production_binding.get_generation()
			)
		&"takeoff":
			return ember_surface_loop_production_binding.queue_takeoff_intent(
				intent_serial, ember_surface_loop_production_binding.get_generation()
			)
	return {"accepted": false, "reason": &"ember_surface_intent_invalid"}


## PlayerController already owns normal on-foot Input sampling. This handler
## only turns its public interaction signal into the binding's typed reboard
## intent after the Host has proven the complete return walk and the exact live
## boarding area is physically nearby.
func _consume_ember_surface_reboard_interaction() -> bool:
	if not _ember_surface_journey_active \
			or not is_instance_valid(ember_surface_loop_host) \
			or not is_instance_valid(ember_surface_loop_production_binding) \
			or ember_surface_loop_production_binding.get_host_phase() \
				!= EmberSurfaceLoopHost.Phase.ON_FOOT:
		return false
	var host_snapshot := ember_surface_loop_host.get_snapshot()
	# The authored bunker survey uses the existing generic nearby-interaction
	# seam. Let that exact Ember-owned point pass through before this handler
	# reserves all other ON_FOOT presses for the return-to-ship lifecycle.
	var nearby_surface_interaction := _find_station_interaction_candidate()
	if is_instance_valid(nearby_surface_interaction) and bool(
		nearby_surface_interaction.get_meta("ember_surface_survey_interaction", false)
	):
		return false
	if not bool(
		(host_snapshot.get("surface_route", {}) as Dictionary).get(
			"return_complete", false
		)
	):
		return true
	var boarding_area := active_ship.get_node_or_null(^"ShipBoardingArea") \
		as ShipBoardingArea if is_instance_valid(active_ship) else null
	if not is_instance_valid(boarding_area) or not is_instance_valid(player):
		return true
	var boarding_area_nearby := false
	for nearby in player.get_nearby_interactables():
		if nearby == boarding_area:
			boarding_area_nearby = true
			break
	if boarding_area_nearby:
		_queue_ember_surface_intent(&"reboard")
	return true


## Returns the first production-owned reason that prevents an Ember cruise
## request. This observes already-authoritative lifecycle state only; it does
## not decide combat, landing, activity, or ship ownership.
func _planetary_cruise_gate_reason(include_combat: bool = true) -> StringName:
	if not is_inside_tree() or is_queued_for_deletion():
		return &"main_unavailable"
	if (
		not is_instance_valid(active_ship)
		or active_ship.is_queued_for_deletion()
		or not active_ship.is_inside_tree()
	):
		return &"active_ship_unavailable"
	if active_ship.is_destroyed():
		return &"ship_destroyed"
	if not _piloting or not active_ship.is_piloted():
		return &"pilot_unseated"
	if _landing_request_active or active_ship.is_landing_active():
		return &"landing_active"
	var combat_active := _planetary_cruise_combat_active()
	if include_combat and combat_active:
		return &"combat_active"
	if _recovering or phase == Phase.RECOVERING:
		return &"ship_recovery"
	# An already engaged controller must observe the authoritative combat flag so
	# the existing policy produces the fail-closed hint. Public engage uses the
	# stricter branch above and can never start during combat.
	if combat_active:
		return &""
	if phase != Phase.FREE_FLIGHT or not _sortie_departed_berth:
		return &"free_flight_unavailable"
	if _selected_activity_is_running():
		return &"activity_running"
	if not is_instance_valid(ember_streaming_bootstrap):
		return &"coordinate_frame_unavailable"
	var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return &"coordinate_frame_unavailable"
	if not (frame.get_snapshot().get("pending_rebase", {}) as Dictionary).is_empty():
		return &"origin_rebase_pending"
	return &""


func _planetary_cruise_combat_active() -> bool:
	return (
		phase == Phase.INTERCEPTOR_ENGAGEMENT
		or (is_instance_valid(opponent) and opponent.is_active())
	)


func _convoy_lifecycle_accepts_sample(sample: Dictionary) -> bool:
	return (
		_selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT
		and _piloting
		and phase == Phase.FREE_FLIGHT
		and _sortie_departed_berth
		and not _landing_request_active
		and is_instance_valid(active_ship)
		and active_ship.is_piloted()
		and not active_ship.is_destroyed()
		and bool(sample.get("available", false))
		and sample.get("actor_kind", &"") == &"ship"
		and int(sample.get("actor_instance_id", 0))
		== _convoy_active_ship_instance_id
	)


func _convoy_lifecycle_failure_reason(sample: Dictionary) -> StringName:
	if not is_instance_valid(active_ship) or active_ship.is_destroyed():
		return &"ship_destroyed"
	if _landing_request_active:
		return &"landing_requested"
	if _recovering or phase == Phase.RECOVERING:
		return &"ship_recovery"
	if (
		int(sample.get("actor_instance_id", 0)) != _convoy_active_ship_instance_id
		and sample.get("actor_kind", &"") == &"ship"
	):
		return &"active_ship_replaced"
	if not _piloting or not active_ship.is_piloted():
		return &"pilot_unseated"
	if not _sortie_departed_berth:
		return &"returned_to_shipyard"
	return &"flight_authority_lost"


func _restore_runtime_bindings_after_reentry() -> void:
	if not _initialized or is_queued_for_deletion() or not is_inside_tree():
		return
	if _runtime_settings_repair_binding != null:
		_runtime_settings_repair_binding.set_attached(true)
	# The world subtree is not rebuilt by a detach, so this re-binds the same
	# single vehicle rather than producing a second one. Re-resolving is what keeps
	# the binding honest if the instance was released while detached.
	_resolve_ground_vehicle()
	_restore_cargo_delivery_bindings()
	_restore_cinder_race_session()
	_sync_cinder_convoy_stream_presence()
	_restore_caption_presentation()
	_connect_runtime_signals()
	_sync_fleet_ship_semantic_audio()
	# Station-defense content owns three private hostile source identities. Its
	# retained subtree can only re-register them after all of its descendants have
	# re-entered, so its deferred restore is already queued behind this parent
	# callback. Audit the shared authority in the following deferred turn; doing it
	# here observes the valid transient player-only roster and reports 7/10.
	call_deferred(&"_restore_live_combat_after_reentry")
	_initialize_nearby_activity_audio()
	_initialize_halyard_crew_semantic_audio()
	_initialize_optional_semantic_audio()
	# Part of the settings snapshot is process-wide rather than node-local: the
	# `AudioServer` bus levels and the window mode belong to whatever is on screen,
	# so while this subtree is detached another scene legitimately owns them.
	# Reapplying the already-validated snapshot reclaims that global state. The
	# node-local presentation presets (HUD scale, palette, reduced motion,
	# captions, per-ship boom lag) survive the detach on their own; reapplying them
	# is idempotent, and `tests/accessibility_reentry_integration_test.gd` records
	# which half of this call each of its assertions actually witnesses.
	_apply_all_runtime_settings()
	# The bed retained its own envelope and loop positions across the detach; this
	# only re-states the observed session state so a re-entered tree cannot resume
	# under a stale one.
	_update_music_bed_state()
	_restore_cabin_occupancy_after_reentry()
	_sync_cinder_loadmaster_hud_binding()
	_ensure_final_approach_hud_composition()
	_ensure_ember_surface_presentations()
	_sync_activity_hud()
	_sync_planetary_cruise_hud()
	_publish_runtime_settings_repair_to_hud()
	_restore_session_recovery_hud_after_reentry()
	_republish_first_sortie_tutorial_presentation()


func _restore_live_combat_after_reentry() -> void:
	if not _initialized or is_queued_for_deletion() or not is_inside_tree():
		return
	_initialize_live_combat()


func _connect_runtime_signals() -> void:
	_bind_activity_board_console()
	_connect_signal_once(
		combat_authority,
		&"authoritative_shot_submitted",
		_on_authoritative_shot_submitted
	)
	_connect_signal_once(pulse_presentation, &"impact_started", _on_pulse_impact_started)
	_connect_signal_once(pulse_presentation, &"shot_presented", _on_pulse_shot_presented)
	_connect_signal_once(pulse_presentation, &"shot_finished", _on_pulse_shot_finished)
	_connect_signal_once(pulse_presentation, &"shot_recycled", _on_pulse_shot_recycled)
	_connect_signal_once(pulse_presentation, &"effects_cleared", _on_pulse_effects_cleared)
	_connect_signal_once(
		pulse_presentation,
		&"impact_receipt_ready",
		_on_pulse_impact_receipt_ready
	)
	_connect_signal_once(
		pulse_presentation,
		&"impact_receipt_aborted",
		_on_pulse_impact_receipt_aborted
	)
	_connect_signal_once(hud, &"start_requested", start_shift)
	_connect_signal_once(hud, &"restart_requested", _restart_shift)
	_connect_signal_once(
		hud,
		&"activity_selection_requested",
		_on_hud_activity_selection_requested
	)
	_connect_signal_once(
		hud,
		&"nearby_activity_intent_requested",
		_on_hud_nearby_activity_intent_requested
	)
	_connect_signal_once(
		hud,
		&"planetary_cruise_toggle_requested",
		_on_hud_planetary_cruise_toggle_requested
	)
	_connect_signal_once(hud, &"setting_change_requested", _on_setting_change_requested)
	_connect_signal_once(hud, &"settings_save_requested", _on_settings_save_requested)
	_connect_signal_once(hud, &"settings_reset_requested", _on_settings_reset_requested)
	_connect_session_recovery_hud_signals()
	_connect_runtime_settings_repair_hud()
	_connect_signal_once(hud, &"display_settings_keep_requested", _on_display_settings_keep_requested)
	_connect_signal_once(hud, &"display_settings_revert_requested", _on_display_settings_revert_requested)
	_connect_signal_once(
		hud,
		&"presentation_intent_requested",
		_on_hud_presentation_intent_requested
	)
	_connect_signal_once(
		hud,
		&"orderly_shutdown_requested",
		_on_orderly_shutdown_requested
	)
	_connect_signal_once(player, &"interact_requested", _on_interact_requested)
	_connect_signal_once(
		player, &"camera_view_mode_changed", _on_player_camera_view_mode_changed
	)
	_connect_signal_once(opponent, &"projectile_fired", _on_opponent_projectile_fired)
	_connect_signal_once(opponent, &"health_changed", _on_opponent_health_changed)
	_connect_signal_once(opponent, &"destroyed", _on_opponent_destroyed)
	var station_defense_content := _get_station_defense_content()
	_connect_signal_once(
		station_defense_content,
		&"snapshot_changed",
		_on_station_defense_network_snapshot_changed
	)
	_connect_signal_once(world, &"target_destroyed", _on_target_destroyed)
	_connect_signal_once(audio, &"cue_started", _on_audio_cue_started)
	_connect_signal_once(audio, &"semantic_cue_emitted", _on_semantic_audio_cue_emitted)
	_connect_signal_once(combat_audio, &"cue_started", _on_combat_audio_cue_started)
	_connect_signal_once(
		cinder_convoy_host,
		&"presentation_changed",
		_on_cinder_convoy_presentation_changed
	)
	_connect_signal_once(
		cinder_convoy_host,
		&"convoy_safely_arrived",
		_on_cinder_convoy_safely_arrived
	)
	_connect_signal_once(
		cinder_convoy_host,
		&"convoy_failed",
		_on_cinder_convoy_failed
	)
	_connect_signal_once(
		cinder_streaming_coordinator,
		&"location_loaded",
		_on_cinder_location_loaded
	)
	_connect_signal_once(
		cinder_streaming_coordinator,
		&"location_load_failed",
		_on_cinder_location_load_failed
	)
	_connect_signal_once(
		cinder_streaming_coordinator,
		&"location_unloaded",
		_on_cinder_location_unloaded
	)
	if runtime_settings != null:
		_connect_signal_once(runtime_settings, &"setting_changed", _on_runtime_setting_changed)
	for fleet_ship in ships:
		_connect_flyable_ship_signals(fleet_ship)
	if is_instance_valid(tow_tractor):
		_connect_signal_once(tow_tractor, &"board_requested", _on_tractor_board_requested)
		_connect_signal_once(tow_tractor, &"exit_requested", _on_tractor_exit_requested)
		_connect_signal_once(
			tow_tractor,
			&"deck_recovery_required",
			_on_tractor_deck_recovery_required
		)


func _publish_network_session_snapshot(
	state: StringName, role: StringName, detail: String, retryable := false
) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"update_network_session_status"):
		return
	_network_hud_snapshot_generation += 1
	var presentation := _network_local_role_presentation()
	presentation["generation"] = _network_hud_snapshot_generation
	presentation["state"] = state
	presentation["role"] = role
	presentation["detail"] = detail
	presentation["retryable"] = retryable
	hud.call(
		&"update_network_session_status",
		presentation
	)


func _network_local_role_presentation() -> Dictionary:
	var local_role: StringName = &"pilot" if _piloting else &"observer"
	var craft_name := ""
	var craft_id: StringName = &""
	var local_peer_id := 1
	var authoritative_snapshot: Dictionary = {}
	if is_instance_valid(network_session):
		if network_session.multiplayer != null:
			local_peer_id = maxi(1, network_session.multiplayer.get_unique_id())
		if network_session.has_method(&"get_authoritative_snapshot"):
			authoritative_snapshot = network_session.get_authoritative_snapshot() as Dictionary
	if is_instance_valid(active_ship):
		craft_name = active_ship.get_display_name()
		craft_id = active_ship.get_ship_id()
		if not _piloting and is_instance_valid(network_session) and network_session.has_method(&"get_crew_role_snapshot"):
			var role_snapshot := network_session.get_crew_role_snapshot() as Dictionary
			var roles := role_snapshot.get("roles", {}) as Dictionary
			for record_variant in roles.values():
				if not record_variant is Dictionary:
					continue
				var record := record_variant as Dictionary
				if int(record.get("peer_id", 0)) == local_peer_id:
					var admitted_role := StringName(str(record.get("role", &"observer")))
					local_role = admitted_role if admitted_role in [&"pilot", &"passenger"] else &"observer"
					break
	return {
		"local_role": local_role,
		"local_peer_id": local_peer_id,
		"controlled_craft": craft_name,
		"controlled_craft_id": craft_id,
		"authoritative_snapshot": authoritative_snapshot.duplicate(true),
		"authoritative_landing": _network_authoritative_landing_presentation(craft_id),
	}


## Projects the server's already-committed landing entity/handoff into the HUD
## snapshot. This does not publish transport state or mutate either authority;
## it only makes retry latches visible to the local server presentation.
func _network_authoritative_landing_presentation(craft_id: StringName) -> Dictionary:
	if craft_id.is_empty() or _network_session_mode != &"server" \
			or not is_instance_valid(network_session) or not network_session.is_server():
		return {}
	var entity: Dictionary = {}
	if network_session.has_method(&"get_landing_entity"):
		entity = network_session.get_landing_entity(craft_id) as Dictionary
	var handoff := _network_landing_handoffs.get(craft_id, {}) as Dictionary
	if entity.is_empty() and handoff.is_empty():
		return {}
	var state := StringName(handoff.get("state", entity.get("state", &"flying")))
	var retryable := state in [&"abort_pending_publication", &"release_pending_publication"]
	var last_handoff := _last_network_landing_handoff_result.get("handoff", {}) as Dictionary
	if not handoff.is_empty() \
			and StringName(last_handoff.get("entity_id", &"")) == craft_id \
			and int(last_handoff.get("entity_generation", 0)) \
				== int(handoff.get("entity_generation", -1)) \
			and StringName(last_handoff.get("network_lease_id", &"")) \
				== StringName(handoff.get("network_lease_id", &"missing")) \
			and bool(_last_network_landing_handoff_result.get("retryable", false)):
		retryable = true
		if state == &"landed":
			state = &"retry_publication_pending"
	if state == &"release_pending_publication":
		state = &"retry_publication_pending"
	var target_id := StringName(handoff.get("target_id", entity.get("target_id", &"")))
	return {
		"authority_peer_id": 1,
		"revision": maxi(1, _network_landing_server_tick),
		"landing": {
			"entity_id": craft_id,
			"entity_generation": maxi(1, int(handoff.get(
				"entity_generation", entity.get("entity_generation", 1)
			))),
			"state": state,
			"target_id": target_id,
			"occupied": state in [&"landed", &"retry_publication_pending"],
			"retryable": retryable,
			"presentation_only": true,
		},
		"presentation_only": true,
	}


func _publish_network_session_result(result: Dictionary, role: StringName) -> void:
	if bool(result.get("accepted", false)):
		var state: StringName = &"connected" if role == &"server" else &"connecting"
		_publish_network_session_snapshot(
			state,
			role,
			"Session host is listening." if role == &"server" else "Contacting the session host.",
			false
		)
		return
	_publish_network_session_snapshot(
		&"failed", role, "Network session failed: %s" % result.get("status", &"unknown"), true
	)


func _on_network_session_started(mode: StringName) -> void:
	_set_station_defense_network_presentation_only(mode == &"client")
	if mode == &"server" and _bomber_payload_ship != null:
		_ensure_bomber_payload_network_source()
	_publish_network_session_snapshot(
		&"connected" if mode == &"server" else &"connecting",
		mode,
		"Session host is listening." if mode == &"server" else "Contacting the session host.",
		false
	)


func _on_network_session_stopped(reason: StringName) -> void:
	_bomber_payload_canonical_publish_pending = false
	_bomber_payload_network_source_generation = 0
	_player_pulse_canonical_publish_pending = false
	_player_pulse_network_pending.clear()
	_player_pulse_network_active_shots.clear()
	_set_station_defense_network_presentation_only(false)
	if _network_session_mode == &"client":
		_clear_bomber_payload_replica_presentation()
		_clear_player_pulse_replica_presentation()
	_detach_network_ship_authority_composition(reason)
	_detach_network_halyard_command_bridge()
	_detach_halyard_crew_semantic_audio()
	_publish_network_session_snapshot(
		&"disconnected", _network_session_mode, "Session closed: %s" % reason, true
	)


func _set_station_defense_network_presentation_only(enabled: bool) -> Dictionary:
	var content := _get_station_defense_content()
	if not is_instance_valid(content):
		return {"accepted": false, "status": &"station_defense_content_unavailable"}
	return content.set_network_presentation_only(enabled)


func _on_network_peer_admitted(peer_id: int, _receipt: Dictionary) -> void:
	if _network_session_mode == &"server":
		_republish_bomber_payloads_for_peer(peer_id)
		_republish_player_pulses_for_peer(peer_id)
		return
	if _network_session_mode == &"client":
		_publish_network_session_snapshot(
			&"connected", &"client", "Session host accepted peer %d." % peer_id, false
		)


func _on_network_migration_result(result: Dictionary) -> void:
	if _network_session_mode != &"client" or not bool(result.get("accepted", false)) \
			or not is_instance_valid(network_session):
		return
	var generation := int(
		network_session.get_migration_snapshot().get("migration_generation", 0)
	)
	if generation > 0 and generation != _bomber_payload_replica_migration_generation:
		_clear_bomber_payload_replica_presentation(generation)
	if generation > 0 and generation != _player_pulse_replica_migration_generation:
		_clear_player_pulse_replica_presentation(generation)


func _on_network_peer_disconnected(peer_id: int, _receipt: Dictionary) -> void:
	if _network_ship_authority_composition != null:
		_network_ship_authority_composition.release_peer(peer_id)


func _on_network_transport_rejected(status: StringName) -> void:
	_publish_network_session_snapshot(
		&"failed", _network_session_mode, "Network transport rejected: %s" % status, true
	)


func _on_network_crew_role_result(result: Dictionary) -> void:
	_attach_network_halyard_command_bridge()
	if _network_session_mode != &"server" or not bool(result.get("accepted", false)):
		return
	var role_record: Dictionary = result.get("role", {}) as Dictionary
	if role_record.is_empty() or not is_instance_valid(active_ship):
		return
	if not active_ship.has_method(&"admit_network_crew_role"):
		return
	active_ship.call(
		&"admit_network_crew_role",
		int(role_record.get("peer_id", 0)),
		int(role_record.get("peer_generation", 0)),
		StringName(role_record.get("avatar_id", &"")),
		StringName(role_record.get("seat_id", &"")),
		StringName(role_record.get("role", &"")),
		int(role_record.get("seat_generation", 0)),
		int(role_record.get("request_sequence", 0))
	)


func _on_network_crew_command_result(result: Dictionary) -> void:
	if is_instance_valid(optional_semantic_audio_composition) \
			and is_instance_valid(active_ship) \
			and active_ship is CinderCargoHaulerType \
			and not bool(result.get("accepted", false)):
		optional_semantic_audio_composition.present_cinder_rejected(result)
	if _network_session_mode != &"server" or not bool(result.get("accepted", false)):
		return
	if not _attach_network_halyard_command_bridge().get("accepted", false):
		return
	if is_instance_valid(active_ship):
		_network_halyard_command_bridge.dispatch(1, result, active_ship)


func _on_hud_presentation_intent_requested(kind: StringName, payload: Dictionary) -> void:
	if kind == &"recovery":
		var choice := StringName(str(payload.get("choice", &"")))
		var result := choose_session_start_recovery(choice)
		if bool(result.get("accepted", false)):
			_publish_recovery_choice_to_hud()
		elif is_instance_valid(hud) and hud.has_method(&"apply_recovery_choice_snapshot"):
			hud.call(&"apply_recovery_choice_snapshot", get_session_start_recommendation())
		return
	if kind == &"safe_start_recovery":
		_handle_safe_start_recovery_intent(payload)
		return
	if kind == &"bomber":
		if StringName(str(payload.get("intent", payload.get("action", &"")))) == &"release_payload":
			_consume_bomber_payload_release()
		return
	if kind == &"tutorial":
		_handle_first_sortie_tutorial_intent(payload)
		return
	if kind == &"server_browser":
		_handle_server_browser_intent(payload)
		return
	if kind != &"network":
		return
	match StringName(str(payload.get("action", &""))):
		&"retry":
			if _network_session_mode == &"server":
				host_network_session(_network_session_port, _network_session_max_clients)
			elif _network_session_mode == &"client":
				join_network_session(_network_session_address, _network_session_port)
		&"cancel", &"disconnect":
			shutdown_network_session(&"ui_%s" % payload.get("action", &"cancel"))


## Applies the live, validated tutorial policy at the production caller boundary
## before a retained HUD presenter formats any prompt. The HUD remains a
## presentation owner; GameFlow retains tutorial progression and persistence.
func apply_first_sortie_tutorial_snapshot(snapshot: Dictionary) -> bool:
	if not is_instance_valid(hud) or not hud.has_method(&"apply_first_sortie_tutorial_snapshot"):
		return false
	var caller_snapshot := snapshot.duplicate(true)
	caller_snapshot["show_tutorials"] = true if runtime_settings == null else runtime_settings.show_tutorials
	return bool(hud.call(&"apply_first_sortie_tutorial_snapshot", caller_snapshot))


func publish_first_sortie_tutorial_phase(step_id: StringName, generation: int = -1) -> bool:
	if step_id not in [
		&"walk_interact", &"board", &"take_seat", &"launch", &"fire", &"return_land", &"exit"
	]:
		return false
	if generation >= 0 and generation != _first_sortie_tutorial_generation:
		return false
	if _first_sortie_tutorial_dismissed_generation == _first_sortie_tutorial_generation:
		return false
	_first_sortie_tutorial_revision += 1
	_first_sortie_tutorial_active_step = step_id
	var snapshot := {
		"step_id": step_id,
		"generation": _first_sortie_tutorial_generation,
		"revision": _first_sortie_tutorial_revision,
		"actor_attached": true,
		"session_active": true,
		"show_tutorials": true if runtime_settings == null else runtime_settings.show_tutorials,
	}
	return apply_first_sortie_tutorial_snapshot(snapshot)


func _detach_first_sortie_tutorial_presentation(reason: StringName) -> void:
	if is_instance_valid(hud) and hud.has_method(&"clear_first_sortie_tutorial"):
		hud.call(&"clear_first_sortie_tutorial", reason)


func _advance_first_sortie_tutorial_source(reason: StringName) -> void:
	_detach_first_sortie_tutorial_presentation(reason)
	_first_sortie_tutorial_generation += 1
	_first_sortie_tutorial_revision = 0
	_first_sortie_tutorial_active_step = &""
	_first_sortie_tutorial_dismissed_generation = -1


func _republish_first_sortie_tutorial_presentation() -> bool:
	if _first_sortie_tutorial_active_step.is_empty() \
			or _first_sortie_tutorial_dismissed_generation == _first_sortie_tutorial_generation:
		return false
	return apply_first_sortie_tutorial_snapshot({
		"step_id": _first_sortie_tutorial_active_step,
		"generation": _first_sortie_tutorial_generation,
		"revision": _first_sortie_tutorial_revision,
		"actor_attached": true,
		"session_active": true,
	})


func _handle_first_sortie_tutorial_intent(payload: Dictionary) -> void:
	var completion := payload.get("completion_intent", {}) as Dictionary
	var generation_value: Variant = completion.get("generation")
	var revision_value: Variant = completion.get("revision")
	if not generation_value is int or not revision_value is int:
		return
	var generation := int(generation_value)
	if generation != _first_sortie_tutorial_generation:
		return
	var revision := int(revision_value)
	if revision != _first_sortie_tutorial_revision:
		return
	var step_id := StringName(str(completion.get("step_id", &"")))
	if step_id == &"" or step_id != _first_sortie_tutorial_active_step:
		return
	var action := StringName(str(payload.get("action", &"")))
	if action == &"repeat":
		return
	if action not in [&"next", &"dismiss"]:
		return
	_first_sortie_tutorial_completed_steps[step_id] = generation
	if action == &"dismiss":
		_first_sortie_tutorial_dismissed_generation = generation


func _on_server_browser_result(result: Dictionary) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"apply_server_browser_result"):
		return
	var presentation := result.duplicate(true)
	if bool(result.get("accepted", false)) and is_instance_valid(network_session):
		presentation["rows"] = network_session.query_server_directory()
	hud.call(&"apply_server_browser_result", presentation)


func _publish_server_browser_feedback(result: Dictionary) -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"apply_server_browser_feedback"):
		return
	var feedback := result.duplicate(true)
	if not feedback.has("message"):
		var status := StringName(str(feedback.get("status", &"unknown")))
		feedback["message"] = "Session request accepted." if bool(feedback.get("accepted", false)) else "Session request failed: %s" % status
	hud.call(&"apply_server_browser_feedback", feedback)


func _handle_server_browser_intent(payload: Dictionary) -> void:
	var action := StringName(str(payload.get("action", &"")))
	var session = network_session if is_instance_valid(network_session) else _ensure_network_session()
	if session == null:
		return
	match action:
		&"refresh":
			var refresh_result := {"accepted": true, "status": &"snapshot_refreshed"}
			var refresh_request := payload.get("request", {}) as Dictionary
			var request_generation: Variant = refresh_request.get(
				"request_generation", payload.get("request_generation", null)
			)
			if request_generation is int and int(request_generation) > 0:
				refresh_result["request_generation"] = int(request_generation)
			_on_server_browser_result(refresh_result)
		&"join":
			var session_id := StringName(str(payload.get("session_id", &"")))
			var intent := session.create_join_intent(session_id)
			if not bool(intent.get("accepted", false)):
				_publish_network_session_snapshot(
					&"failed", &"client", "Unable to join advertised session: %s" % intent.get("status", &"unknown"), false
				)
				return
			_network_session_mode = &"client"
			var started := session.consume_join_intent(
				intent.get("intent", {}) as Dictionary,
				_network_session_address,
				_network_session_port
			)
			_publish_network_session_result(started, &"client")
		&"host_session":
			var host_port := int(payload.get("port", runtime_settings.network_default_port if runtime_settings != null else NetworkSessionAdapterType.DEFAULT_PORT))
			var host_capacity := int(payload.get("max_clients", runtime_settings.multiplayer_max_players if runtime_settings != null else NetworkSessionAdapterType.DEFAULT_MAX_CLIENTS))
			var hosted := host_network_session(host_port, host_capacity)
			_publish_server_browser_feedback(hosted)
		&"manual_join":
			var direct_connect_intent := {
				"address": payload.get("address", ""),
				"port": payload.get("port", runtime_settings.network_default_port if runtime_settings != null else NetworkSessionAdapterType.DEFAULT_PORT),
				"protocol_version": payload.get("protocol_version", NetworkSessionAdapterType.NETWORK_PROTOCOL_VERSION),
				"package_generation": payload.get("package_generation", NetworkSessionAdapterType.NETWORK_BUILD_VERSION),
			}
			_network_session_mode = &"client"
			_set_station_defense_network_presentation_only(true)
			var joined := session.consume_direct_connect_intent(direct_connect_intent)
			if bool(joined.get("accepted", false)):
				_network_session_address = str(joined.get("address", ""))
				_network_session_port = int(joined.get("port", 0))
			_publish_network_session_result(joined, &"client")
			_publish_server_browser_feedback(joined)


func _connect_flyable_ship_signals(candidate: HeroShip) -> void:
	if not is_instance_valid(candidate):
		return
	_connect_signal_once(
		candidate,
		&"engine_state_changed",
		Callable(self, "_on_engine_state_changed").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"projectile_fired",
		Callable(self, "_on_projectile_fired").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"landing_completed",
		Callable(self, "_on_landing_completed").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"landing_aborted",
		Callable(self, "_on_landing_aborted").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"hull_changed",
		Callable(self, "_on_ship_hull_changed").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"camera_view_changed",
		Callable(self, "_on_camera_view_changed").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"damage_stage_changed",
		Callable(self, "_on_ship_damage_stage_changed").bind(candidate)
	)
	_connect_signal_once(
		candidate,
		&"destroyed",
		Callable(self, "_on_ship_destroyed").bind(candidate)
	)
	if candidate.has_signal(&"engineer_repair_state_changed") \
			and (candidate.has_method(&"get_engineer_repair_network_snapshot") \
			or candidate.has_method(&"get_crew_role_gameplay_snapshot")):
		_connect_signal_once(
			candidate,
			&"engineer_repair_state_changed",
			Callable(self, "_on_engineer_repair_state_changed").bind(candidate)
		)


func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if not is_instance_valid(source) or not source.has_signal(signal_name):
		return
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _decorate_flight_path_telemetry(telemetry: Dictionary) -> void:
	telemetry["flight_path_screen_position"] = Vector2.ZERO
	telemetry["flight_path_visible"] = false
	telemetry["flight_path_clamped"] = false
	telemetry["flight_path_rearward"] = false
	telemetry["flight_path_alignment"] = 0.0

	if bool(telemetry.get("landed", false)) or bool(telemetry.get("destroyed", false)):
		return
	var velocity_value: Variant = telemetry.get("velocity_world")
	var forward_value: Variant = telemetry.get("flight_forward_world")
	if velocity_value is not Vector3 or forward_value is not Vector3:
		return
	var velocity := velocity_value as Vector3
	var flight_forward := forward_value as Vector3
	if not velocity.is_finite() or not flight_forward.is_finite():
		return
	var speed := velocity.length()
	if speed < FLIGHT_PATH_MINIMUM_SPEED or flight_forward.length_squared() <= 0.000001:
		return
	if not is_instance_valid(active_ship):
		return
	var camera: Camera3D = active_ship.get_camera()
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	var viewport_rect := camera.get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return

	var travel_direction := velocity / speed
	var physical_forward := flight_forward.normalized()
	telemetry["flight_path_alignment"] = clampf(travel_direction.dot(physical_forward), -1.0, 1.0)
	var camera_basis := camera.global_basis.orthonormalized()
	var camera_forward := -camera_basis.z.normalized()
	var camera_local_direction := camera_basis.inverse() * travel_direction
	var view_alignment := travel_direction.dot(camera_forward)
	var center := viewport_rect.position + viewport_rect.size * 0.5
	var safe_radii := Vector2(
		minf(
			viewport_rect.size.x * FLIGHT_PATH_SAFE_HORIZONTAL_VIEWPORT_RATIO,
			viewport_rect.size.y * FLIGHT_PATH_SAFE_HORIZONTAL_ASPECT_LIMIT
		),
		viewport_rect.size.y * FLIGHT_PATH_SAFE_VERTICAL_VIEWPORT_RATIO
	)
	var marker_position := center
	var clamped := false
	var rearward := view_alignment < 0.0

	if rearward:
		marker_position = center + Vector2(
			clampf(camera_local_direction.x, -1.0, 1.0) * safe_radii.x * 0.75,
			safe_radii.y
		)
		clamped = true
	elif view_alignment <= FLIGHT_PATH_NEAR_SIDE_EPSILON:
		var screen_direction := Vector2(camera_local_direction.x, -camera_local_direction.y)
		marker_position = center + _flight_path_ellipse_boundary_offset(screen_direction, safe_radii)
		clamped = true
	else:
		var projected := camera.unproject_position(
			camera.global_position + travel_direction * FLIGHT_PATH_PROJECTION_DISTANCE
		)
		if not projected.is_finite():
			return
		var offset := projected - center
		var ellipse_distance := sqrt(
			pow(offset.x / safe_radii.x, 2.0) + pow(offset.y / safe_radii.y, 2.0)
		)
		if ellipse_distance > 1.0:
			offset /= ellipse_distance
			clamped = true
		marker_position = center + offset

	if not marker_position.is_finite():
		return
	telemetry["flight_path_screen_position"] = marker_position
	telemetry["flight_path_visible"] = true
	telemetry["flight_path_clamped"] = clamped
	telemetry["flight_path_rearward"] = rearward


func _flight_path_ellipse_boundary_offset(direction: Vector2, radii: Vector2) -> Vector2:
	if direction.length_squared() <= 0.000001:
		return Vector2(0.0, -radii.y)
	var denominator := sqrt(
		pow(direction.x / radii.x, 2.0) + pow(direction.y / radii.y, 2.0)
	)
	return direction / denominator if denominator > 0.000001 else Vector2.ZERO


func start_shift() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if phase != Phase.INTRO:
		return
	phase = Phase.APPROACH_SHIP
	player.set_camera_active(true)
	player.set_control_enabled(true)
	hud.set_mode("on-foot")
	hud.set_objective(
		"Board the Torrent interceptor for the guided test — other berthed craft are available for free sorties"
	)
	publish_first_sortie_tutorial_phase(&"walk_interact", _first_sortie_tutorial_generation)
	hud.toast("Shipyard access granted", "Guided Torrent test and free-flight fleet access are available")
	audio.set_on_foot(true)
	audio.play_ui_confirm()


## Recomputes the on-foot interaction targets from live world state.
##
## This is the only writer of `station_interaction_candidate`, `boarding_candidate`
## and `_near_ship`, and it is called from two places: the idle on-foot update that
## draws the prompt, and `_on_interact_requested()` immediately before it acts.
##
## The second call site is load-bearing rather than defensive. `interact_requested`
## is emitted from `PlayerController._physics_process()`, and Godot runs every
## physics iteration of a frame ahead of that frame's idle pass, so a handler that
## reads a cached selection can be served a snapshot taken before the state that
## selection depends on last changed. `_try_exit_ship()` is exactly that case: it
## sets `_reboard_blocked_ship` and re-enables control in one synchronous tail, and
## the cached pair it leaves behind still names the craft the pilot just left,
## because the idle refresh is skipped for the whole time the pilot is seated.
## Deciding from a selection computed inside the handler removes the snapshot, so
## the suppression, the boarding-area reservation and the station facing test are
## all evaluated against the world as it is at the instant of the press.
func _refresh_interaction_targets() -> void:
	# ShipyardWorld finishes its procedural Aft Operations children after Main's
	# first binding pass.  Resolve this one optional adapter when on-foot
	# discovery begins so a late-built console still receives exactly one signal
	# connection; subsequent refreshes retain that same instance.
	if (
		not is_instance_valid(activity_board_console)
		or not activity_board_console.is_connected(
			&"open_requested", _on_activity_board_console_open_requested
		)
	):
		_bind_activity_board_console()
	if is_instance_valid(_reboard_blocked_ship):
		if player.get_interaction_origin().distance_to(
			_reboard_blocked_ship.get_boarding_position()
		) > BOARDING_FALLBACK_REACH:
			_reboard_blocked_ship = null
	station_interaction_candidate = _find_station_interaction_candidate()
	boarding_candidate = _find_boarding_candidate()
	_near_ship = is_instance_valid(boarding_candidate)


func _update_on_foot_flow() -> void:
	_refresh_interaction_targets()
	if phase in [Phase.BOARDING, Phase.DISEMBARKING, Phase.FAILED, Phase.RECOVERING]:
		hud.set_interaction("", false)
		return
	if phase == Phase.IN_FLIGHT_CABIN:
		if _near_ship and boarding_candidate == _cabin_ship:
			hud.set_interaction("[ E ]  TAKE THE PILOT SEAT")
		else:
			hud.set_interaction("WALK FORWARD TO THE COCKPIT", true)
	elif is_instance_valid(station_interaction_candidate):
		hud.set_interaction(str(station_interaction_candidate.call("get_interaction_prompt")))
	elif _near_ship:
		if _first_sortie_tutorial_active_step == &"walk_interact":
			publish_first_sortie_tutorial_phase(
				&"board", _first_sortie_tutorial_generation
			)
		hud.set_interaction("[ E ]  BOARD %s" % boarding_candidate.get_display_name().to_upper())
	else:
		hud.set_interaction("", false)
	if player.velocity.length() > 2.0 and player.is_on_floor():
		audio.play_footstep(clampf(player.velocity.length() / 9.2, 0.0, 1.0))


## Resolves the station's drivable ground vehicle.
##
## Scoped to this coordinator's own world subtree rather than a scene-tree group,
## because several suites hold two `Main` instances at once and a global group
## lookup would hand one session the other session's tractor.
func _resolve_ground_vehicle() -> void:
	tow_tractor = null
	if not is_instance_valid(world):
		return
	for candidate in world.find_children("*", "TowTractor", true, false):
		tow_tractor = candidate as TowTractor
		break


func _update_drive_flow() -> void:
	if _transition_busy:
		# The seat handoff owns the HUD and the vehicle's driven flag while it runs.
		hud.set_interaction("", false)
		return
	if not is_instance_valid(tow_tractor):
		# The vehicle cannot vanish under a seated driver in production, but if it
		# ever did, leaving the avatar bound to a dead seat anchor is the one
		# outcome that strands them. Recall through the same path a lost craft uses.
		_recover_from_lost_tractor(&"vehicle_unavailable")
		return
	if tow_tractor.can_release_driver():
		hud.set_interaction("[ E ]  HOP OUT")
	else:
		hud.set_interaction("[ E ]  HOP OUT  //  COME TO A STOP")


func _on_tractor_board_requested(actor: Node) -> void:
	if actor != player:
		return
	_board_tow_tractor()


func _on_tractor_exit_requested() -> void:
	_exit_tow_tractor()


func _on_tractor_deck_recovery_required(reason: StringName) -> void:
	_recover_from_lost_tractor(reason)


## Boarding generation guard for the ground vehicle.
##
## Mirrors `_is_transition_current()` without its craft-specific terms, so a
## destructive recovery that advances the generation cannot be overtaken by a
## boarding or dismount coroutine resuming afterwards.
func _is_ground_transition_current(generation: int) -> bool:
	return (
		generation == _transition_generation
		and _transition_busy
		and _ground_transition_active
		and is_instance_valid(tow_tractor)
	)


func _board_tow_tractor() -> void:
	if _transition_busy or _piloting or _driving or not is_instance_valid(tow_tractor):
		return
	if not tow_tractor.is_boardable():
		return
	# The two on-foot phases. A tractor is a deck toy, not a way to sidestep an
	# active flight objective or an in-flight transition.
	if phase not in [Phase.APPROACH_SHIP, Phase.COMPLETE]:
		return
	_transition_busy = true
	_ground_transition_active = true
	_ground_transition_recovery_transform = world.get_player_spawn()
	var generation := _begin_transition_generation()
	player.set_control_enabled(false)
	hud.set_interaction("", false)
	hud.set_objective("Climb into the yard tow tractor", "TOW TRACTOR")
	if not player.begin_boarding(
		tow_tractor.get_boarding_entry_transform(),
		tow_tractor.get_driver_seat_anchor(),
		boarding_motion_time
	):
		_transition_busy = false
		_ground_transition_active = false
		player.set_control_enabled(true)
		_restore_on_foot_objective()
		return
	await player.boarding_completed
	if not _is_ground_transition_current(generation):
		return
	_driving = true
	player.set_camera_active(false)
	tow_tractor.set_driven(true)
	# Driving is neither piloting nor walking. Leaving it as "on-foot" left the
	# readout naming the regeneration deck and the controls card offering JUMP,
	# SPRINT and BOARD -- none of which the seated driver has.
	hud.set_mode("driving", "YARD TOW TRACTOR")
	hud.set_objective(
		"Drive the tow tractor anywhere on the deck — press E to hop out",
		"TOW TRACTOR"
	)
	hud.toast(
		"Tow tractor running",
		"W / S drive  •  A / D steer  •  SPACE brake  •  E to hop out",
		3.2
	)
	audio.play_ui_confirm()
	_transition_busy = false
	_ground_transition_active = false


func _exit_tow_tractor() -> void:
	if _transition_busy or not _driving or not is_instance_valid(tow_tractor):
		return
	if not tow_tractor.can_release_driver():
		hud.toast(
			"Still moving",
			"Bring the tractor to a stop on the deck before hopping out",
			2.0
		)
		return
	_transition_busy = true
	_ground_transition_active = true
	_ground_transition_recovery_transform = world.get_player_spawn()
	var generation := _begin_transition_generation()
	tow_tractor.set_driven(false)
	player.set_camera_active(true)
	# The exit transform is validated against real deck by the vehicle itself; the
	# on-foot spawn is the fallback it uses when no candidate footfall is backed by
	# floor, so a dismount can never place the player over a void.
	if not player.begin_disembark(
		tow_tractor.get_exit_transform(world.get_player_spawn()),
		disembarking_motion_time
	):
		tow_tractor.set_driven(true)
		player.set_camera_active(false)
		_transition_busy = false
		_ground_transition_active = false
		return
	await player.disembarking_completed
	if not _is_ground_transition_current(generation):
		return
	_driving = false
	player.set_control_enabled(true)
	hud.set_mode("on-foot")
	hud.set_interaction("", false)
	_restore_on_foot_objective()
	audio.set_on_foot(true)
	audio.play_ui_confirm()
	_transition_busy = false
	_ground_transition_active = false


## A retained whole-Main subtree may re-enter, but a partially completed
## tractor embodiment has no durable handback contract. Cancel it at the
## lifecycle boundary so its deferred completion cannot acquire the tractor's
## camera or drive input after re-entry.
func _cancel_ground_transition_for_detach() -> void:
	if not _ground_transition_active:
		return
	_invalidate_transition_generation()
	_ground_transition_active = false
	_transition_busy = false
	_driving = false
	if is_instance_valid(tow_tractor):
		tow_tractor.set_driven(false)
	if is_instance_valid(player):
		player.force_recovery_to_on_foot(_ground_transition_recovery_transform)
		player.set_camera_active(true)
		player.set_control_enabled(true)


## The tow tractor's half of the crash-recovery contract.
##
## The vehicle raises this at most once per departure, from its own pose, so it
## fires whatever the reason — a drive off an edge, a launch off a ramp, or
## geometry that changed underneath it. The pilot recall is the *same*
## `_recall_pilot_to_deck()` a destroyed craft performs; only the vehicle-side
## reset differs, because a tractor owns no berth to regenerate into.
func _recover_from_lost_tractor(reason: StringName) -> void:
	if _recovering:
		return
	var had_driver := _driving
	_recovering = true
	_invalidate_transition_generation()
	_ground_transition_active = false
	_transition_busy = true
	if had_driver:
		hud.set_enemy_status("", 0.0, 1.0, false)
		_recall_pilot_to_deck()
		hud.toast(
			"Tow tractor recovered",
			"You are back on the regeneration deck — the tractor returned to its parking spot",
			3.0
		)
		_restore_on_foot_objective()
	if is_instance_valid(tow_tractor):
		tow_tractor.recover_to_home_transform()
	# Recorded rather than surfaced: the reason names which of the two independent
	# guards fired, which is what a diagnostic read wants and a toast does not.
	_last_tractor_recovery_reason = reason
	_transition_busy = false
	_recovering = false


## Restores the on-foot objective and phase after any seat is released.
func _restore_on_foot_objective() -> void:
	if _guided_activity_complete:
		phase = Phase.COMPLETE
		hud.set_objective(
			"Explore the deck or walk to another physical spacecraft",
			"FLIGHT TEST COMPLETE"
		)
	else:
		phase = Phase.APPROACH_SHIP
		hud.set_objective(
			"Board the Torrent interceptor to begin the pending guided flight test",
			"GUIDED TEST PENDING"
		)


func _update_pilot_flow() -> void:
	if not is_instance_valid(active_ship):
		return
	var telemetry: Dictionary = active_ship.get_telemetry()
	var engine_state := str(telemetry.get("engine_state", "OFFLINE")).to_upper()
	var landed := bool(telemetry.get("landed", false))
	var berth_transform := _get_active_berth_transform()
	var distance_from_pad: float = active_ship.global_position.distance_to(berth_transform.origin)
	if not landed:
		_mark_sortie_departed()

	if phase == Phase.START_ENGINES:
		hud.set_interaction("[ W/S / LEFT STICK ]  APPLY THRUST")
		if not landed:
			if _sandbox_sortie or _guided_activity_complete or active_ship != ship:
				phase = Phase.FREE_FLIGHT
				hud.set_objective("Free flight — explore, fight, or return to a compatible registered berth", "SANDBOX SORTIE")
				hud.toast("Sortie underway", "Automatic propulsion is responding to flight demand")
				_start_default_free_flight_activity()
			else:
				phase = Phase.LAUNCH
				hud.set_objective("Launch through the illuminated bay aperture")
				hud.toast("Departure confirmed", "Flight surfaces and inertial dampers responding")
	elif phase == Phase.LAUNCH:
		if not _launch_registered and (active_ship.global_position.z < -66.0 or distance_from_pad > 70.0):
			_launch_registered = true
			if destroyed_targets >= total_targets:
				_begin_interceptor_engagement()
			else:
				phase = Phase.TARGET_PRACTICE
				publish_first_sortie_tutorial_phase(
					&"fire", _first_sortie_tutorial_generation
				)
				hud.set_objective("Destroy the %d marked range drones outside the yard" % total_targets)
				hud.toast("Launch clear", "Weapons range is now live")
	elif phase == Phase.RETURN_TO_YARD or phase == Phase.FREE_FLIGHT:
		var landing_report := _get_active_landing_assist_report()
		var landing_berth := StringName(landing_report.get("selected_berth_id", &""))
		if _landing_request_active:
			hud.set_interaction(_active_landing_assist_status())
		elif phase == Phase.FREE_FLIGHT and not _sortie_departed_berth and landed:
			if engine_state == "OFFLINE":
				hud.set_interaction("[ E ]  EXIT SPACECRAFT")
			else:
				hud.set_interaction("Clear the berth before requesting a return approach")
		elif _sortie_departed_berth and bool(landing_report.get("assist_capture_accepted", false)):
			hud.set_interaction("[ L / D-PAD LEFT ]  ENGAGE LANDING ASSIST")
		elif (
			not landed
			and engine_state == "OFFLINE"
			and active_ship.supports_in_flight_cabin_access()
		):
			# Only craft that publish a walkable cabin ever advertise this, so the
			# prompt never offers a pilot a step into open space.
			hud.set_interaction("[ E ]  LEAVE THE PILOT SEAT")
		elif (
			_sortie_departed_berth
			and not landing_berth.is_empty()
			and _landing_report_has_error(landing_report, "assist_capture_speed_exceeds_limit")
		):
			hud.set_interaction(
				"SLOW TO %.0f M/S FOR LANDING ASSIST"
				% float(landing_report.get("effective_maximum_speed", 0.0))
			)
		elif (
			_sortie_departed_berth
			and not landing_berth.is_empty()
			and _landing_report_has_error(landing_report, "assist_capture_attitude_exceeds_limit")
		):
			hud.set_interaction(
				"LEVEL / ROLL TO WITHIN %.0f° FOR LANDING ASSIST"
				% float(landing_report.get("maximum_up_angle_degrees", 75.0))
			)
		else:
			hud.set_interaction("", false)
		if (
			_sortie_departed_berth
			and landed
			and _landing_request_active
			and not _active_landing_berth_id.is_empty()
			and not landing_berth.is_empty()
			and not _return_registered
		):
			# The polling fallback must use the same strict contract/occupancy gate as
			# the landing signal. A lifecycle reset can make a craft parked+landed
			# after clearing its acceptance report; treating that visual state as a
			# completed return would allow a false guided completion.
			_on_landing_completed(active_ship)
	elif phase == Phase.SHUT_DOWN:
		if engine_state != "OFFLINE":
			hud.set_interaction("HOLD FLIGHT CONTROLS NEUTRAL  //  AUTO SHUTDOWN")
		elif landed:
			hud.set_interaction("[ E ]  EXIT SPACECRAFT")
	elif phase == Phase.INTERCEPTOR_ENGAGEMENT:
		hud.set_interaction("", false)


func _consume_active_ship_command_edges() -> void:
	if not _piloting or not is_instance_valid(active_ship):
		return
	var source := active_ship.get_command_source()
	if _drain_pending_game_flow_commands(source):
		return
	# Compatibility for custom command sources that have not adopted lossless
	# GameFlow delivery yet. The sequence cursor still prevents repeat polling.
	_consume_active_ship_command(active_ship.get_last_ship_command())


## Returns true when the source implements lossless delivery, including when its
## current FIFO is empty. Capture and validation occur synchronously so a focus,
## pause, pilot, source, or tree boundary cannot let a stale caller drain a newer
## generation. Every queued edge is dispatched in its original command order.
func _drain_pending_game_flow_commands(source: ShipCommandSource) -> bool:
	if (
		not is_instance_valid(source)
		or not source.has_method(&"drain_pending_commands")
		or not source.has_method(&"get_delivery_generation")
	):
		return false
	var delivery_generation := int(source.call(&"get_delivery_generation"))
	var pending_commands := source.call(
		&"drain_pending_commands",
		delivery_generation
	) as Array
	for pending_command_value: Variant in pending_commands:
		var pending_command := pending_command_value as ShipCommand
		_consume_active_ship_command(pending_command)
	return true


## Retained private compatibility seam for deterministic tools written before
## schema v4 named the queue after its then-lifecycle-only contents.
func _drain_pending_lifecycle_commands(source: ShipCommandSource) -> bool:
	return _drain_pending_game_flow_commands(source)


func _consume_active_ship_command(command: ShipCommand) -> void:
	if command == null or not command.is_valid():
		return
	# Source invalidation advances its epoch before any later sample exists. Reject
	# a directly captured pre-boundary snapshot against that live epoch, in addition
	# to the ship-wide replay cursor below. Exhaustion is terminal and fails closed.
	var source := active_ship.get_command_source()
	if is_instance_valid(source):
		if source.is_stream_exhausted():
			return
		# The active producer epoch is an exact authority fence. A future-numbered
		# packet has not been established by this source any more than an older one;
		# accepting it would poison the replay high-water mark and escape the next
		# source boundary's revocation epoch.
		if command.stream_id != source.get_stream_id():
			return
	var ship_instance_id := active_ship.get_instance_id()
	if ship_instance_id == _last_lifecycle_command_ship_instance_id:
		# Stream IDs are epochs, not interchangeable source labels. Once a newer
		# epoch has been observed, no delayed command from an older epoch may move
		# the cursor backwards and reacquire lifecycle authority.
		if command.stream_id < _last_lifecycle_command_stream_id:
			return
		if (
			command.stream_id == _last_lifecycle_command_stream_id
			and command.sequence <= _last_lifecycle_command_sequence
		):
			return
	# Claim the snapshot before dispatch. `_process()` may run several times
	# between physics ticks, and an awaited landing/exit transition must never
	# replay the same edge when it resumes.
	_last_lifecycle_command_ship_instance_id = ship_instance_id
	_last_lifecycle_command_stream_id = command.stream_id
	_last_lifecycle_command_sequence = command.sequence
	if phase == Phase.INTRO or get_tree().paused or _transition_busy:
		return
	if command.fire_pressed and active_ship is CinderLongRangeBomberType:
		_consume_cinder_bomber_fire_pressed()
	if command.landing and phase in [
		Phase.RETURN_TO_YARD,
		Phase.FREE_FLIGHT,
	]:
		_try_request_landing()
	elif command.interact and phase in [
		Phase.START_ENGINES,
		Phase.RETURN_TO_YARD,
		Phase.FREE_FLIGHT,
		Phase.SHUT_DOWN,
	]:
		_try_exit_ship()


## Converges the active Cinder onto GameFlow's existing solo/server payload
## generation before admitting the ordered fire edge. Multiplayer clients fail
## before convergence, so input can neither start local authority nor create a
## projectile outside the retained server-replica path.
func _consume_cinder_bomber_fire_pressed() -> Dictionary:
	if not _piloting or not is_instance_valid(active_ship) \
			or not active_ship is CinderLongRangeBomberType:
		_last_bomber_payload_result = {
			"accepted": false,
			"reason": &"active_cinder_pilot_unavailable",
		}
		return _last_bomber_payload_result.duplicate(true)
	if _network_session_mode == &"client":
		return _consume_bomber_payload_release()
	var bomber := active_ship as CinderLongRangeBomber
	if not bomber.is_piloted() or not _ensure_bomber_payload_session(bomber):
		_last_bomber_payload_result = {
			"accepted": false,
			"reason": &"payload_session_unavailable",
		}
		return _last_bomber_payload_result.duplicate(true)
	return _consume_bomber_payload_release()


## Compatibility seam for deterministic tests and replay tooling that dispatch
## an InputEventAction directly. Real physical keys/buttons are sampled only by
## LocalShipInputSource; this method queues synthetic edges into that same
## authority stream and never mutates ship lifecycle state itself.
func _unhandled_input(event: InputEvent) -> void:
	if (
		not _piloting
		or _transition_busy
		or event is not InputEventAction
		or not (event as InputEventAction).pressed
		or not is_instance_valid(active_ship)
	):
		return
	var source := active_ship.get_command_source()
	if source != null and source.has_method(&"queue_action_edge"):
		source.call(
			&"queue_action_edge",
			StringName((event as InputEventAction).action)
		)
		# Deterministic tools historically observe the result before yielding a
		# frame. Sample immediately, apply ship-local camera effects, then drain the
		# GameFlow FIFO so an older pending edge is always dispatched before this
		# newly sampled one. A later idle drain is empty rather than a replay.
		var command := source.next_command() as ShipCommand
		active_ship.consume_sampled_camera_edges(command)
		if not _drain_pending_game_flow_commands(source):
			_consume_active_ship_command(command)


func _bind_activity_board_console() -> void:
	if not is_instance_valid(world) or not world.has_method(&"get_activity_board_console"):
		activity_board_console = null
		return
	activity_board_console = world.call(&"get_activity_board_console") as Area3D
	_connect_signal_once(
		activity_board_console,
		&"open_requested",
		_on_activity_board_console_open_requested
	)


## The physical console is a presentation/input adapter only.  It cannot
## select, start, reward, or otherwise mutate an activity; it opens the same
## existing Activity Board page whose buttons already forward selection intent
## to this coordinator.
func _on_activity_board_console_open_requested(actor: Node) -> void:
	if (
		actor != player
		or _piloting
		or _transition_busy
		or _station_seated
		or not is_instance_valid(player)
		or not player.is_control_enabled()
		or player.is_seated()
		or phase not in [Phase.APPROACH_SHIP, Phase.COMPLETE]
		or not is_instance_valid(hud)
		or not hud.has_method(&"open_activity_board")
	):
		return
	hud.call(&"open_activity_board")


func _on_interact_requested() -> void:
	if _consume_ember_surface_reboard_interaction():
		return
	if _piloting or _transition_busy:
		return
	if _station_seated:
		_stand_from_station_seat()
		return
	# Physics-emitted signal, idle-refreshed selection: recompute before deciding.
	# See `_refresh_interaction_targets()`.
	_refresh_interaction_targets()
	if is_instance_valid(station_interaction_candidate):
		if station_interaction_candidate is StationSeat:
			_sit_in_station_seat(station_interaction_candidate as StationSeat)
			return
		var accepted := bool(station_interaction_candidate.call("interact", player))
		if accepted:
			audio.play_ui_confirm()
		return
	if phase not in [Phase.APPROACH_SHIP, Phase.COMPLETE, Phase.IN_FLIGHT_CABIN] or not _near_ship:
		return
	# One press retakes the seat. The craft whose cabin this is has held the
	# player's own boarding reservation throughout, so nothing else can be
	# selected here and there is no walk-away-and-back-again cost.
	if phase == Phase.IN_FLIGHT_CABIN and boarding_candidate != _cabin_ship:
		return
	_board_ship(boarding_candidate)


func _update_station_seat_flow() -> void:
	if not is_instance_valid(_active_station_seat):
		_recover_from_station_seat()
		return
	if _transition_busy:
		hud.set_interaction("", false)
		return
	hud.set_interaction(_active_station_seat.get_seated_prompt())


func _sit_in_station_seat(seat: StationSeat) -> void:
	if (
		_transition_busy
		or _station_seated
		or not is_instance_valid(seat)
		or phase not in [Phase.APPROACH_SHIP, Phase.COMPLETE]
		or player.get_interaction_origin().distance_to(seat.get_entry_transform().origin) \
			> STATION_SEAT_MAX_REACH
		or not seat.try_reserve(player)
	):
		return
	_transition_busy = true
	_active_station_seat = seat
	_station_seat_recovery_transform = seat.get_exit_transform()
	var generation := _begin_transition_generation()
	player.set_control_enabled(false)
	hud.set_interaction("", false)
	if not player.begin_boarding(
		seat.get_entry_transform(), seat.get_seat_anchor(), minf(boarding_motion_time, 0.75)
	):
		seat.cancel_reservation(player)
		_active_station_seat = null
		_transition_busy = false
		player.set_control_enabled(true)
		return
	await player.boarding_completed
	if generation != _transition_generation:
		return
	if (
		not _transition_busy
		or _active_station_seat != seat
		or not is_instance_valid(seat)
		or not seat.is_reserved_for(player)
		or not player.is_seated()
	):
		_recover_from_station_seat()
		return
	seat.finish_transition(player)
	_station_seated = true
	player.set_station_seated_context(true)
	player.set_control_enabled(true)
	_transition_busy = false
	audio.play_ui_confirm()


func _stand_from_station_seat() -> void:
	var seat := _active_station_seat
	if (
		_transition_busy
		or not _station_seated
		or not is_instance_valid(seat)
		or not seat.begin_release(player)
	):
		return
	_transition_busy = true
	var generation := _begin_transition_generation()
	player.set_control_enabled(false)
	player.set_station_seated_context(false)
	hud.set_interaction("", false)
	if not player.begin_disembark(seat.get_exit_transform(), minf(disembarking_motion_time, 0.65)):
		seat.finish_transition(player)
		player.set_station_seated_context(true)
		player.set_control_enabled(true)
		_transition_busy = false
		return
	await player.disembarking_completed
	if generation != _transition_generation:
		return
	if _active_station_seat != seat:
		_recover_from_station_seat()
		return
	if is_instance_valid(seat):
		seat.release(player)
	_active_station_seat = null
	_station_seated = false
	_transition_busy = false
	player.set_control_enabled(true)
	hud.set_interaction("", false)
	audio.play_ui_confirm()


func _cancel_station_seat_for_detach() -> void:
	if not _station_seated and not is_instance_valid(_active_station_seat):
		return
	_invalidate_transition_generation()
	if is_instance_valid(_active_station_seat) and is_instance_valid(player):
		_active_station_seat.cancel_reservation(player)
	_active_station_seat = null
	_station_seated = false
	_transition_busy = false
	if is_instance_valid(player):
		player.force_recovery_to_on_foot(_station_seat_recovery_transform)
		player.set_control_enabled(true)


func _recover_from_station_seat() -> void:
	_invalidate_transition_generation()
	if is_instance_valid(_active_station_seat) and is_instance_valid(player):
		_active_station_seat.cancel_reservation(player)
	_active_station_seat = null
	_station_seated = false
	_transition_busy = false
	if is_instance_valid(player):
		player.force_recovery_to_on_foot(_station_seat_recovery_transform)
		player.set_control_enabled(true)
	if is_instance_valid(hud):
		hud.set_interaction("", false)


func _begin_transition_generation() -> int:
	_transition_generation += 1
	return _transition_generation


func _invalidate_transition_generation() -> void:
	_transition_generation += 1


func _is_transition_current(
		generation: int,
		transition_ship: HeroShip,
		expected_phase: Phase
	) -> bool:
	return (
		generation == _transition_generation
		and _transition_busy
		and phase == expected_phase
		and active_ship == transition_ship
		and is_instance_valid(transition_ship)
		and not transition_ship.is_destroyed()
	)


func _board_ship(candidate: HeroShip = null) -> void:
	if _transition_busy or not is_instance_valid(candidate) or not candidate.is_boardable():
		return
	var candidate_area := candidate.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	if candidate_area != null and not candidate_area.try_reserve(player):
		return
	# Retaking the seat of the craft whose cabin the player is already walking is
	# an interior movement, not an approach across an apron: there is no hull to
	# climb, no canopy to cycle, and the craft may still be drifting.
	var from_cabin := phase == Phase.IN_FLIGHT_CABIN and candidate == _cabin_ship
	if from_cabin:
		_release_cabin_occupancy()
	# Every route generation is bound to the physical sortie that started it.
	# Switching hulls is a terminal actor replacement even for the adapters that
	# do not own a convoy entity; otherwise their clock/progress survives and the
	# newly boarded craft silently resumes another ship's activity.
	if _selected_activity_is_running() and candidate != active_ship:
		_fail_active_activity(&"active_ship_replaced")
	if candidate != active_ship:
		if hud.has_method("clear_hero_component_ship"):
			hud.clear_hero_component_ship()
		_clear_bomber_payload_loop(&"active_ship_replaced")
		_detach_cinder_loadmaster_hud_binding()
		if is_instance_valid(network_session):
			_detach_network_halyard_command_bridge()
	active_ship = candidate
	if is_instance_valid(network_session):
		_attach_network_halyard_command_bridge()
		_attach_network_ship_authority_composition()
	_sync_optional_semantic_audio()
	_sync_cinder_loadmaster_hud_binding()
	_advance_first_sortie_tutorial_source(&"boarding_actor_changed")
	_reset_lifecycle_command_cursor()
	_boarding_area = candidate_area
	# The Torrent alias is the one explicitly guided vertical slice. Any other
	# physical craft remains available before completion, but launches into a
	# free sortie without consuming or mutating the pending guided activity.
	_sandbox_sortie = _guided_activity_complete or candidate != ship
	_launch_registered = false
	_return_registered = false
	_sortie_departed_berth = false
	_landing_request_active = false
	_active_landing_berth_id = &""
	_reset_terminal_activity_for_next_sortie()
	opponent.set_target(active_ship)
	if hud.has_method("set_ship_identity"):
		hud.set_ship_identity(active_ship.get_display_name(), active_ship.get_role())
	var entry := _get_ship_entry_descriptor(active_ship)
	var entry_noun := str(entry.get("noun", "canopy"))
	var open_verb := str(entry.get("open_verb", "open"))
	_transition_busy = true
	var transition_generation := _begin_transition_generation()
	phase = Phase.BOARDING
	player.set_control_enabled(false)
	hud.set_interaction("", false)
	if from_cabin:
		hud.set_objective("Take the pilot seat and resume %s" % active_ship.get_display_name())
	else:
		hud.set_objective("%s the %s and take the physical pilot seat" % [open_verb.capitalize(), entry_noun])
		hud.toast("%s releasing" % entry_noun.capitalize(), "Physical entry route and cockpit are clear")
		audio.play_canopy(true)
		active_ship.set_canopy_open(true, canopy_motion_time)
		await active_ship.canopy_motion_finished
		if not _is_transition_current(transition_generation, candidate, Phase.BOARDING):
			return
	if not player.begin_boarding(
		(
			active_ship.get_in_flight_cabin_report().get(
				"stand_transform", active_ship.get_boarding_entry_transform()
			) as Transform3D
			if from_cabin
			else active_ship.get_boarding_entry_transform()
		),
		active_ship.get_pilot_seat_anchor(),
		boarding_motion_time,
		active_ship if from_cabin else null
	):
		_transition_busy = false
		if from_cabin:
			# The craft is still idled offline under way; put the player back in its
			# cabin rather than stranding a failed boarding in a berth phase.
			phase = Phase.IN_FLIGHT_CABIN
			_cabin_ship = candidate
			_bind_cabin_occupancy(candidate)
			player.set_control_enabled(true)
			publish_first_sortie_tutorial_phase(
				&"take_seat", _first_sortie_tutorial_generation
			)
			return
		if _boarding_area != null:
			_boarding_area.release_reservation(player)
		phase = Phase.COMPLETE if _guided_activity_complete else Phase.APPROACH_SHIP
		player.set_control_enabled(true)
		if not _guided_activity_complete:
			publish_first_sortie_tutorial_phase(
				&"walk_interact", _first_sortie_tutorial_generation
			)
		return
	await player.boarding_completed
	if not _is_transition_current(transition_generation, candidate, Phase.BOARDING):
		return
	if not from_cabin:
		audio.play_canopy(false)
		active_ship.set_canopy_open(false, canopy_motion_time)
		await active_ship.canopy_motion_finished
		if not _is_transition_current(transition_generation, candidate, Phase.BOARDING):
			return
	_piloting = true
	_observe_session_diagnostic_runtime_mode()
	if is_instance_valid(network_session) and network_session.is_server():
		network_session.register_remote_ship_pilot(1, active_ship.get_ship_id(), 1)
	_publish_network_boarding_state(active_ship, true)
	_publish_network_moving_interior_state(active_ship, true)
	player.set_camera_active(false)
	active_ship.set_piloted(true)
	active_ship.get_camera().current = true
	phase = Phase.START_ENGINES
	publish_first_sortie_tutorial_phase(&"launch", _first_sortie_tutorial_generation)
	hud.set_mode("piloting")
	if hud.has_method("bind_hero_component_ship"):
		hud.bind_hero_component_ship(active_ship)
	hud.set_objective("Apply thrust to launch %s from its physical pilot seat" % active_ship.get_display_name())
	hud.set_interaction("[ W/S / LEFT STICK ]  APPLY THRUST")
	if from_cabin:
		hud.toast("Back in the seat", "Apply a flight control to resume the sortie", 2.4)
	else:
		hud.toast("Pilot secured", "%s secured — cockpit link established" % entry_noun.capitalize())
	audio.set_on_foot(false)
	audio.play_ui_confirm()
	_transition_busy = false


func _reset_lifecycle_command_cursor() -> void:
	_last_lifecycle_command_ship_instance_id = 0
	_last_lifecycle_command_stream_id = -1
	_last_lifecycle_command_sequence = -1


func _try_exit_ship() -> void:
	if _transition_busy or not _piloting or not is_instance_valid(active_ship):
		return
	if phase not in [
		Phase.START_ENGINES,
		Phase.RETURN_TO_YARD,
		Phase.FREE_FLIGHT,
		Phase.SHUT_DOWN,
	]:
		hud.toast("Exit locked", "Complete the active flight objective before leaving the seat")
		return
	var telemetry: Dictionary = active_ship.get_telemetry()
	var entry := _get_ship_entry_descriptor(active_ship)
	var entry_noun := str(entry.get("noun", "canopy"))
	var open_verb := str(entry.get("open_verb", "open"))
	if str(telemetry.get("engine_state", "ONLINE")).to_upper() != "OFFLINE":
		hud.toast("Exit waiting", "Release flight controls; propulsion shuts down automatically")
		return
	if not bool(telemetry.get("landed", false)):
		# Idled offline away from a berth. Whether the seat may be left at all is the
		# craft's own contract, because only a craft with a bounded walkable cabin
		# has somewhere for its pilot to stand.
		_leave_seat_into_cabin()
		return
	if not _ensure_landed_berth_occupancy(active_ship):
		hud.toast("Exit locked", "The physical berth must be secured before leaving the seat")
		return
	_transition_busy = true
	var transition_ship := active_ship
	var transition_generation := _begin_transition_generation()
	phase = Phase.DISEMBARKING
	hud.set_interaction("", false)
	hud.set_objective("%s the %s and climb back onto the regeneration deck" % [open_verb.capitalize(), entry_noun])
	audio.play_canopy(true)
	active_ship.set_canopy_open(true, canopy_motion_time)
	await active_ship.canopy_motion_finished
	if not _is_transition_current(transition_generation, transition_ship, Phase.DISEMBARKING):
		return
	_clear_bomber_payload_loop(&"pilot_disembarked")
	active_ship.set_piloted(false)
	active_ship.get_camera().current = false
	player.set_camera_active(true)
	if not player.begin_disembark(active_ship.get_exit_transform(), disembarking_motion_time):
		_transition_busy = false
		phase = Phase.SHUT_DOWN
		return
	await player.disembarking_completed
	if not _is_transition_current(transition_generation, transition_ship, Phase.DISEMBARKING):
		return
	audio.play_canopy(false)
	active_ship.set_canopy_open(false, canopy_motion_time)
	await active_ship.canopy_motion_finished
	if not _is_transition_current(transition_generation, transition_ship, Phase.DISEMBARKING):
		return
	_piloting = false
	_observe_session_diagnostic_runtime_mode()
	_landing_request_active = false
	player.set_control_enabled(true)
	_reboard_blocked_ship = active_ship
	if _boarding_area != null:
		_boarding_area.release_reservation(player)
	_boarding_area = null
	hud.set_mode("on-foot")
	if hud.has_method("clear_hero_component_ship"):
		hud.clear_hero_component_ship()
	hud.set_interaction("", false)
	if (
		transition_ship == ship
		and not _sandbox_sortie
		and not _guided_activity_complete
		and _guided_return_ready_for_completion
		and _return_registered
	):
		_guided_activity_complete = true
		_guided_return_ready_for_completion = false
	if _guided_activity_complete:
		phase = Phase.COMPLETE
		hud.set_objective("Explore the deck or walk to another physical spacecraft", "FLIGHT TEST COMPLETE")
		hud.toast("Welcome back to Mudds Shipyards", "The freeform shipyard remains active")
	else:
		phase = Phase.APPROACH_SHIP
		_sandbox_sortie = false
		opponent.set_target(ship)
		hud.set_objective(
			"Board the Torrent interceptor to begin the pending guided flight test",
			"GUIDED TEST PENDING"
		)
		hud.toast("Safe exit complete", "The pending Torrent guided test remains ready")
	_advance_first_sortie_tutorial_source(&"pilot_disembarked")
	if not _guided_activity_complete:
		publish_first_sortie_tutorial_phase(
			&"walk_interact", _first_sortie_tutorial_generation
		)
	audio.set_on_foot(true)
	audio.play_ui_confirm()
	_transition_busy = false


## Leaves the pilot seat of a shut-down craft that is not at a berth, putting the
## player on foot inside that same craft.
##
## `modern_interpretation`. Nothing here is a claim about any historical craft.
##
## The pilot cannot be stranded, and that is arranged three ways rather than one:
##
##  1. The offer only exists at all for a craft whose own
##     `get_in_flight_cabin_report()` publishes a bounded, physically walkable
##     cabin. Every fighter in the fleet declines, so "leave the seat in space"
##     never resolves to "stand in space".
##  2. The arrival pose is a real ship-local marker inside that cabin, and the
##     player is confined to the published envelope by
##     `PlayerController.set_cabin_containment()`. That envelope encloses the
##     craft's own walkable deck colliders and nothing beyond the hull, so the
##     only way out of a flying craft is back through the pilot seat.
##  3. Containment is enforced against the live craft transform, so it holds even
##     if occupancy is somehow lost: a body left behind by a moving hull is
##     hard-recalled to the standing pose rather than left in the dark.
##
## `_recover_from_destroyed_ship()` remains the outer safety net for the case
## the cabin itself is destroyed, and now runs for this phase too.
func _publish_network_boarding_state(ship_to_publish: HeroShip, occupied: bool) -> Dictionary:
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or not is_instance_valid(ship_to_publish)
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var ship_id := ship_to_publish.get_ship_id()
	var seat_id := StringName("%s_pilot" % String(ship_id))
	var frame_id := StringName("frame_%s" % String(ship_id))
	if not _network_boarding_entities.has(ship_id):
		var registered_ship := network_session.register_boarding_ship(ship_id, 1, frame_id, 1)
		if not bool(registered_ship.get("accepted", false)) and registered_ship.get("status") != &"duplicate_ship":
			return registered_ship
		var registered_seat := network_session.register_boarding_seat(seat_id, ship_id, 1, &"pilot")
		if not bool(registered_seat.get("accepted", false)) and registered_seat.get("status") != &"duplicate_seat":
			return registered_seat
		_network_boarding_entities[ship_id] = true
	_network_boarding_server_tick += 1
	return network_session.publish_boarding_snapshot(
		ship_id, 1, seat_id, 1, 1, occupied, [], _network_boarding_server_tick
	)


func _publish_network_moving_interior_state(ship_to_publish: HeroShip, occupied: bool) -> Dictionary:
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or not is_instance_valid(ship_to_publish)
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var entity_id := StringName("pilot_%s" % String(ship_to_publish.get_ship_id()))
	var frame_id := StringName("frame_%s" % String(ship_to_publish.get_ship_id()))
	if not occupied:
		return network_session.publish_moving_interior_release(entity_id, 1)
	var relationship := MovingInteriorRelationshipType.create(
		_network_boarding_server_tick,
		entity_id,
		1,
		frame_id,
		1,
		Transform3D.IDENTITY,
		Vector3.ZERO,
		Vector3.ZERO,
		_network_boarding_server_tick
	)
	return network_session.publish_moving_interior_snapshot(
		relationship.get_snapshot(), [], _network_boarding_server_tick
	)


func _leave_seat_into_cabin() -> void:
	var cabin := active_ship.get_in_flight_cabin_report()
	var frame := cabin.get("frame") as MovingInteriorFrame
	if not bool(cabin.get("supported", false)) or not is_instance_valid(frame):
		hud.toast(
			"Exit locked",
			"%s has no pressurised cabin — land before leaving the seat"
				% active_ship.get_display_name()
		)
		return
	var stand_transform := cabin.get("stand_transform", Transform3D.IDENTITY) as Transform3D
	var cabin_bounds := cabin.get("local_bounds", AABB()) as AABB
	if not stand_transform.origin.is_finite() or cabin_bounds.size.is_zero_approx():
		hud.toast("Exit locked", "The cabin standing route is unavailable")
		return

	_transition_busy = true
	var transition_ship := active_ship
	var restore_phase := phase
	var transition_generation := _begin_transition_generation()
	phase = Phase.IN_FLIGHT_CABIN
	hud.set_interaction("", false)
	hud.set_objective(
		"Cabin access — walk %s, then return to the pilot seat" % transition_ship.get_display_name(),
		"UNDER WAY"
	)
	# Leaving the seat removes the sole production actor authority for every
	# selected flight activity. Convoy already failed here, but race, patrol, and
	# cargo previously remained active (and their clocks froze) until the same or
	# another craft was boarded, creating an unbounded stale generation.
	if _selected_activity_is_running():
		_fail_active_activity(&"pilot_unseated")
	transition_ship.set_piloted(false)
	if is_instance_valid(network_session) and network_session.is_server():
		network_session.reset_remote_ship_pilot(transition_ship.get_ship_id(), &"pilot_released")
	_publish_network_boarding_state(transition_ship, false)
	_publish_network_moving_interior_state(transition_ship, false)
	if transition_ship.get_camera() != null:
		transition_ship.get_camera().current = false
	player.set_camera_active(true)
	# The exit pose belongs to the craft, not to the world. A drifting hull would
	# otherwise leave the avatar interpolating towards a point it has left.
	if not player.begin_disembark(stand_transform, disembarking_motion_time, transition_ship):
		transition_ship.set_piloted(true)
		if transition_ship.get_camera() != null:
			transition_ship.get_camera().current = true
		player.set_camera_active(false)
		_transition_busy = false
		phase = restore_phase
		return
	await player.disembarking_completed
	if not _is_transition_current(transition_generation, transition_ship, Phase.IN_FLIGHT_CABIN):
		return
	_piloting = false
	_landing_request_active = false
	_cabin_ship = transition_ship
	_bind_cabin_occupancy(transition_ship)
	# Deliberately no `_reboard_blocked_ship`. That suppression exists so a pilot
	# who climbs down onto an apron does not instantly climb back in on the same
	# held key, and it clears by walking away from the craft — which is the wrong
	# shape entirely for a pilot who is standing *inside* it and whose whole
	# purpose here is to sit back down. The seat also stays reserved to this
	# player for the whole walk, so nothing else can claim it meanwhile and
	# re-boarding costs exactly one key press.
	player.set_control_enabled(true)
	# On foot, but not on the station: name the craft the pilot is standing in.
	hud.set_mode("cabin", transition_ship.get_display_name())
	hud.toast(
		"Out of the seat",
		"%s is idled offline and drifting — the cabin is yours" % transition_ship.get_display_name(),
		2.6
	)
	audio.set_on_foot(true)
	audio.play_ui_confirm()
	_transition_busy = false


## Single writer of the cabin occupancy + containment pair. Occupancy is the
## frame's to own, so this asks it rather than tracking a parallel record.
##
## The craft's report is re-read here rather than passed in. Every caller reaches
## this across at least one `await`, and the report's poses are world-space on a
## craft that is still moving: a value captured before the transition names a
## place the hull has already left, which would silently offset the recall pose
## by however far it travelled.
func _bind_cabin_occupancy(cabin_ship: HeroShip) -> void:
	if not is_instance_valid(cabin_ship):
		return
	var cabin := cabin_ship.get_in_flight_cabin_report()
	var frame := cabin.get("frame") as MovingInteriorFrame
	var cabin_bounds := cabin.get("local_bounds", AABB()) as AABB
	var stand_transform := cabin.get("stand_transform", Transform3D.IDENTITY) as Transform3D
	if not is_instance_valid(frame):
		return
	# The cockpit deck legitimately reaches past the pressurised occupancy volume,
	# so this registration is explicit rather than bounds-filtered. Containment,
	# not the occupancy volume, is what keeps the occupant inside the hull.
	frame.register_occupant(player, {
		"require_inside_bounds": false,
		"registration_source": &"in_flight_cabin",
	})
	player.set_cabin_containment(cabin_ship, cabin_bounds, stand_transform)


## Reverses `_bind_cabin_occupancy()`. `inherit_velocity` is false for every
## reason this is called: the player is either taking the seat of the same craft
## or being recovered to the deck, and in neither case should the hull's motion
## be imparted to the avatar.
func _release_cabin_occupancy() -> void:
	player.clear_cabin_containment()
	if is_instance_valid(_cabin_ship):
		var frame := _cabin_ship.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
		if is_instance_valid(frame) and frame.is_occupant_registered(player):
			frame.unregister_occupant(player, false, &"in_flight_cabin_ended")
	_cabin_ship = null


## Re-establishes cabin occupancy after a whole-Main detach. `MovingInteriorFrame`
## deliberately drops its occupants when it leaves the tree, and Godot does not
## call `_ready()` again on re-entry, so an explicit registration made before the
## detach has to be restated here rather than assumed to have survived.
func _restore_cabin_occupancy_after_reentry() -> void:
	if phase != Phase.IN_FLIGHT_CABIN or not is_instance_valid(_cabin_ship):
		return
	_bind_cabin_occupancy(_cabin_ship)


## Inspectable state for the in-flight cabin feature.
func get_in_flight_cabin_status() -> Dictionary:
	var frame: MovingInteriorFrame = null
	if is_instance_valid(_cabin_ship):
		frame = _cabin_ship.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	return {
		"active": phase == Phase.IN_FLIGHT_CABIN,
		"ship": _cabin_ship,
		"carried": is_instance_valid(frame) and frame.is_occupant_registered(player),
		"containment": player.get_cabin_containment_report(),
	}


func _on_engine_state_changed(state: Variant, source_ship: HeroShip = null) -> void:
	if source_ship != null and source_ship != active_ship:
		return
	var state_text := str(state).to_upper()
	hud.set_engine_state(state_text)
	if state_text == _last_engine_state:
		return
	_last_engine_state = state_text
	if state_text == "STARTING":
		pass


func _on_projectile_fired(origin: Vector3, direction: Vector3, source_ship: HeroShip = null) -> void:
	var firing_ship := source_ship if is_instance_valid(source_ship) else active_ship
	if not is_instance_valid(firing_ship) or firing_ship != active_ship:
		return
	if _network_session_mode == &"client":
		# A client receives the server's already-resolved pulse presentation below;
		# it never reaches CombatResolver or damage authority from local weapon input.
		_last_player_shot_result = {
			"accepted": false,
			"resolved": false,
			"reason": &"client_projectile_authority_forbidden",
		}
		return
	# Fleet weapons are free-play equipment: the pending guided Torrent activity
	# does not safe another hull or suppress valid fire before its completion.
	# Torrent keeps the fixed range profile during the two tutorial range phases;
	# every other shot uses the firing hull's authored combat profile.
	var weapon_id := (
		RANGE_WEAPON_ID
		if firing_ship == ship and phase in [Phase.LAUNCH, Phase.TARGET_PRACTICE]
		else _get_player_combat_weapon_id(firing_ship)
	)
	var result: Dictionary = combat_authority.submit_hitscan_with_deferred_presentation(
		firing_ship, weapon_id, origin, direction
	)
	_last_player_shot_result = result.duplicate(true)


func _on_authoritative_shot_submitted(request: ShotRequestType, result: Dictionary) -> void:
	if not bool(result.get("accepted", false)) or not bool(result.get("resolved", false)):
		return
	var direction := request.get_normalized_direction()
	if direction.length_squared() <= 0.000001:
		return
	var source_instance_id := (
		request.source_entity.get_instance_id()
		if is_instance_valid(request.source_entity)
		else maxi(request.source_id, 0)
	)
	var opponent_pulse_identity := _get_opponent_pulse_network_identity(request)
	var network_opponent_pulse := (
		_network_session_mode == &"server"
		and is_instance_valid(network_session)
		and network_session.is_server()
		and not opponent_pulse_identity.is_empty()
	)
	if bool(result.get("damaged", false)) and request.presentation_receipt_id < 0 \
			and not network_opponent_pulse:
		# submit_hitscan() is the explicit authority/component-presentation API used
		# by deterministic probes and non-travelling integrations. The target has
		# already reacted synchronously; do not append a late fire/pulse/impact cue.
		return
	var opponent_fire := request.source_entity == opponent or network_opponent_pulse
	if opponent_fire:
		combat_audio.play_defender_fire(request.origin, source_instance_id)
	else:
		combat_audio.play_player_fire(request.origin, source_instance_id)
	var endpoint := request.origin + direction * request.range
	if bool(result.get("hit", false)):
		var resolved_position: Variant = result.get("position", endpoint)
		if resolved_position is Vector3 and (resolved_position as Vector3).is_finite():
			endpoint = resolved_position as Vector3
	var style_id: StringName = &"amber" if opponent_fire else &"cyan"
	var receipt_id := request.presentation_receipt_id
	if bool(result.get("damaged", false)) and receipt_id >= 0:
		var target_entity: Variant = result.get("target_entity")
		var terminal := bool(result.get("destroyed", false))
		var terminal_position := endpoint
		var target_instance_id := 0
		if is_instance_valid(target_entity):
			target_instance_id = (target_entity as Object).get_instance_id()
			if terminal and target_entity is Node3D:
				terminal_position = (target_entity as Node3D).global_position
		_pending_combat_audio_receipts[receipt_id] = {
			"target": weakref(target_entity) if is_instance_valid(target_entity) else null,
			"target_instance_id": target_instance_id,
			"endpoint": endpoint,
			"terminal_position": terminal_position,
			"terminal": terminal,
			"style_id": style_id,
			"source_instance_id": source_instance_id,
		}
	_prepare_player_pulse_network_context(request, endpoint, style_id, result)
	_prepare_opponent_pulse_network_context(request, endpoint, style_id, result)
	var presented := _present_pulse_shot(
		request.origin,
		endpoint,
		style_id,
		request.source_entity if is_instance_valid(request.source_entity) else null,
		bool(result.get("hit", false)),
		receipt_id
	)
	_player_pulse_network_context.clear()
	_opponent_pulse_network_context.clear()
	if bool(result.get("damaged", false)) and receipt_id >= 0 and not presented:
		var impact_weight := 0.45 if style_id == &"amber" else 0.9
		combat_audio.play_impact(endpoint, impact_weight, maxi(source_instance_id, 0))
		_commit_damage_presentation_receipt(receipt_id, result.get("target_entity"), endpoint)


func _on_pulse_impact_receipt_ready(receipt_id: int, position: Vector3) -> void:
	_commit_damage_presentation_receipt(receipt_id, null, position)


func _on_pulse_impact_receipt_aborted(receipt_id: int) -> void:
	# Damage/health authority is already final. If a bounded visual slot is
	# recycled or torn down before arrival, release its queued presentation now
	# so a destroyed hull or impact can never remain visually pending forever.
	if (
		is_instance_valid(pulse_presentation)
		and pulse_presentation.is_lifecycle_transaction_active()
	):
		# Clear/reset/exit publishes only after the pool mutation is atomic. Finalise
		# one message-turn later so a whole-Main exit can finish removing children;
		# ordinary in-tree reset still commits on the following idle turn.
		call_deferred("_finalize_aborted_combat_receipt", receipt_id)
		return
	_finalize_aborted_combat_receipt(receipt_id)


func _finalize_aborted_combat_receipt(receipt_id: int) -> void:
	var record := _pending_combat_audio_receipts.get(receipt_id, {}) as Dictionary
	if record.is_empty():
		return
	if is_queued_for_deletion() or not is_inside_tree() \
			or not _receipt_target_is_inside_tree(record):
		# Whole-Main teardown can remove the target before the pulse child publishes
		# its abort. That transaction intentionally discards transient presentation;
		# never spawn nodes or start audio into a tree that is dismantling.
		_pending_combat_audio_receipts.erase(receipt_id)
		return
	if not record.is_empty():
		var endpoint := record.get("endpoint", Vector3.INF) as Vector3
		if endpoint.is_finite():
			var style_id := StringName(record.get("style_id", &"cyan"))
			var impact_weight := 0.45 if style_id == &"amber" else 0.9
			combat_audio.play_impact(
				endpoint,
				impact_weight,
				maxi(int(record.get("source_instance_id", 0)), 0)
			)
	_commit_damage_presentation_receipt(receipt_id)


func _receipt_target_is_inside_tree(record: Dictionary) -> bool:
	var target_ref := record.get("target") as WeakRef
	if target_ref == null:
		return false
	var target := target_ref.get_ref() as Node
	return is_instance_valid(target) and target.is_inside_tree()


func _commit_damage_presentation_receipt(
		receipt_id: int,
		target_hint: Variant = null,
		arrival_position: Vector3 = Vector3.INF
	) -> bool:
	if receipt_id < 0:
		return false
	var record := _pending_combat_audio_receipts.get(receipt_id, {}) as Dictionary
	# A ready/abort callback is the terminal coordinator event for this receipt.
	# The target may legitimately have discarded an older record after a later
	# lethal commit, deactivation, reuse, or streamed teardown. Retire our metadata
	# before the one best-effort commit so those no-op callbacks cannot leak state.
	_pending_combat_audio_receipts.erase(receipt_id)
	var target: Variant = target_hint
	if not is_instance_valid(target):
		var target_ref := record.get("target") as WeakRef
		if target_ref != null:
			target = target_ref.get_ref()
	var committed := false
	if is_instance_valid(target) and target.has_method("commit_deferred_damage_presentation"):
		committed = bool(target.call("commit_deferred_damage_presentation", receipt_id))
	for fleet_ship in ships:
		if not committed and (
			is_instance_valid(fleet_ship)
			and fleet_ship.has_method("commit_deferred_damage_presentation")
			and bool(fleet_ship.call("commit_deferred_damage_presentation", receipt_id))
		):
			committed = true
			target = fleet_ship
			break
	if (
		not committed
		and
		is_instance_valid(opponent)
		and opponent.has_method("commit_deferred_damage_presentation")
		and bool(opponent.call("commit_deferred_damage_presentation", receipt_id))
	):
		committed = true
		target = opponent
	if not committed:
		committed = (
		bool(world.call("commit_deferred_damage_presentation", receipt_id))
		if is_instance_valid(world) and world.has_method("commit_deferred_damage_presentation")
		else false
		)
	if not committed:
		return false
	if bool(record.get("terminal", false)):
		var effect_position := record.get("terminal_position", arrival_position) as Vector3
		if not effect_position.is_finite():
			effect_position = arrival_position
		if effect_position.is_finite():
			combat_audio.play_explosion(
				effect_position,
				maxi(int(record.get("target_instance_id", 0)), 0)
			)
	return true


func get_pending_combat_presentation_receipt_count() -> int:
	return _pending_combat_audio_receipts.size()


## Range drones are valid free-play targets for every fleet ship. Their one-shot
## destruction authorization must therefore be retained even when the Torrent
## guide is not active; otherwise an early sandbox kill would leave the later
## guided target quota permanently unreachable. Only an active Torrent target
## practice phase consumes a completed quota into the interceptor transition.
func _on_target_destroyed(_target_id: StringName, _position: Vector3) -> void:
	if _guided_activity_complete:
		return
	# ShipyardWorld commits its one-shot destruction ledger before emitting this
	# signal. Re-sync from that authority instead of assuming this listener has
	# observed every earlier free-play kill exactly once.
	destroyed_targets = mini(total_targets, world.get_destroyed_target_count())
	hud.set_target_count(destroyed_targets, total_targets)
	if destroyed_targets >= total_targets and active_ship == ship and phase == Phase.TARGET_PRACTICE:
		_begin_interceptor_engagement()
	elif destroyed_targets >= total_targets and active_ship == ship and phase == Phase.LAUNCH:
		hud.toast("Range contacts cleared", "Clear the launch aperture to receive your return vector")
	elif destroyed_targets >= total_targets:
		hud.toast(
			"Range contacts cleared",
			"Progress retained — the pending Torrent flight test can continue when ready"
		)
	else:
		hud.toast("Target destroyed", "%d range contacts remain" % (total_targets - destroyed_targets))


func _publish_network_landing_state(ship_to_publish: HeroShip, state: StringName) -> Dictionary:
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or _network_session_mode != &"server"
		or not is_instance_valid(ship_to_publish)
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var entity_id := ship_to_publish.get_ship_id()
	var entity_generation := int(_network_landing_entities.get(entity_id, 0))
	if entity_generation <= 0:
		entity_generation = 1
		var registered := network_session.register_landing_entity(1, entity_id, entity_generation)
		if not bool(registered.get("accepted", false)) and registered.get("status") != &"duplicate_entity":
			return registered
		_network_landing_entities[entity_id] = entity_generation
	_network_landing_server_tick += 1
	return network_session.publish_landing_snapshot(
		entity_id, entity_generation, ship_to_publish.global_position, state, [],
		_network_landing_server_tick
	)


## Mirrors the already-owned physical berth token into the server landing
## lifecycle. ShipBerth remains the sole occupancy authority; this handoff
## neither chooses a berth nor accepts a client transform/token.
func _begin_network_landing_handoff(
	ship_to_land: HeroShip,
	berth: ShipBerth,
) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server() \
			or _network_session_mode != &"server":
		return {"accepted": true, "status": &"network_landing_not_required"}
	if not is_instance_valid(ship_to_land) or not is_instance_valid(berth):
		return {"accepted": false, "status": &"physical_landing_owner_unavailable"}
	var instance_id := ship_to_land.get_instance_id()
	var entity_id := ship_to_land.get_ship_id()
	var target_id := berth.get_berth_id()
	var physical_token := StringName(_berth_tokens.get(instance_id, &""))
	if entity_id.is_empty() or target_id.is_empty() or physical_token.is_empty() \
			or StringName(_reserved_berth_ids.get(instance_id, &"")) != target_id \
			or not berth.has_valid_lease(ship_to_land, physical_token, entity_id):
		return {"accepted": false, "status": &"physical_berth_lease_mismatch"}
	if _network_landing_handoffs.has(entity_id):
		return {"accepted": false, "status": &"landing_handoff_active"}
	var entity_generation := int(_network_landing_entities.get(entity_id, 0))
	if entity_generation <= 0:
		entity_generation = 1
		var registered := network_session.register_landing_entity(
			1, entity_id, entity_generation
		)
		if not bool(registered.get("accepted", false)):
			return registered
		_network_landing_entities[entity_id] = entity_generation
	var target_registered := network_session.register_landing_target(
		target_id, MUDDS_RETURN_TARGET_ID, 1
	)
	if not bool(target_registered.get("accepted", false)) \
			and target_registered.get("status") != &"duplicate_target":
		return target_registered
	_network_landing_request_sequence += 1
	_network_landing_server_tick += 1
	var reserved := network_session.reserve_server_landing(
		entity_id, entity_generation, MUDDS_RETURN_TARGET_ID, target_id, 0,
		_network_landing_request_sequence, _network_landing_server_tick
	)
	if not bool(reserved.get("accepted", false)):
		return reserved
	var handoff := {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"target_id": target_id,
		"network_lease_id": StringName(reserved.get("lease_id", &"")),
		"physical_token": physical_token,
		"state": &"landing_pending",
	}
	_network_landing_handoffs[entity_id] = handoff
	var published := _publish_network_landing_state(ship_to_land, &"landing_pending")
	if not bool(published.get("accepted", false)):
		network_session.abort_server_landing(
			entity_id, entity_generation, StringName(handoff.network_lease_id)
		)
		_network_landing_handoffs.erase(entity_id)
		return published
	return {
		"accepted": true,
		"status": &"network_landing_reserved",
		"handoff": handoff.duplicate(true),
		"publication": published.duplicate(true),
	}


func _commit_network_landing_handoff(
	ship_to_land: HeroShip,
	berth: ShipBerth,
) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server() \
			or _network_session_mode != &"server":
		return {"accepted": true, "status": &"network_landing_not_required"}
	if not is_instance_valid(ship_to_land) or not is_instance_valid(berth):
		return {"accepted": false, "status": &"physical_landing_owner_unavailable"}
	var entity_id := ship_to_land.get_ship_id()
	var handoff := _network_landing_handoffs.get(entity_id, {}) as Dictionary
	if handoff.is_empty() or handoff.get("state") not in [&"landing_pending", &"landed"]:
		return {"accepted": false, "status": &"landing_handoff_not_pending"}
	var instance_id := ship_to_land.get_instance_id()
	var physical_token := StringName(handoff.get("physical_token", &""))
	if StringName(handoff.get("target_id", &"")) != berth.get_berth_id() \
			or StringName(_berth_tokens.get(instance_id, &"")) != physical_token \
			or berth.get_occupant() != ship_to_land \
			or not berth.has_valid_lease(ship_to_land, physical_token, entity_id):
		return {"accepted": false, "status": &"physical_berth_occupancy_mismatch"}
	var mutation_committed: bool = handoff.get("state") == &"landed"
	if not mutation_committed:
		var committed := network_session.commit_server_landing(
			entity_id,
			int(handoff.get("entity_generation", 0)),
			StringName(handoff.get("network_lease_id", &"")),
		)
		if not bool(committed.get("accepted", false)):
			return committed
		handoff["state"] = &"landed"
		_network_landing_handoffs[entity_id] = handoff
		mutation_committed = true
	var published := _publish_network_landing_state(ship_to_land, &"landed")
	return {
		"accepted": bool(published.get("accepted", false)),
		"status": (
			&"network_landing_committed"
			if bool(published.get("accepted", false))
			else &"network_landing_commit_publication_failed"
		),
		"mutation_committed": mutation_committed,
		"retryable": not bool(published.get("accepted", false)),
		"handoff": handoff.duplicate(true),
		"publication": published.duplicate(true),
	}


func _abort_network_landing_handoff(ship_to_abort: HeroShip) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server() \
			or _network_session_mode != &"server":
		return {"accepted": true, "status": &"network_landing_not_required"}
	if not is_instance_valid(ship_to_abort):
		return {"accepted": false, "status": &"physical_landing_owner_unavailable"}
	var entity_id := ship_to_abort.get_ship_id()
	var handoff := _network_landing_handoffs.get(entity_id, {}) as Dictionary
	if handoff.is_empty():
		var entity := network_session.get_landing_entity(entity_id) as Dictionary
		if entity.is_empty() or entity.get("state") == &"flying":
			return {"accepted": true, "status": &"network_landing_not_tracked"}
		return {"accepted": false, "status": &"landing_handoff_not_pending"}
	if handoff.get("state") not in [&"landing_pending", &"abort_pending_publication"]:
		return {"accepted": false, "status": &"landing_handoff_not_pending"}
	var mutation_committed: bool = handoff.get("state") == &"abort_pending_publication"
	if not mutation_committed:
		var aborted := network_session.abort_server_landing(
			entity_id,
			int(handoff.get("entity_generation", 0)),
			StringName(handoff.get("network_lease_id", &"")),
		)
		if not bool(aborted.get("accepted", false)):
			aborted["mutation_committed"] = false
			aborted["retryable"] = true
			return aborted
		handoff["state"] = &"abort_pending_publication"
		_network_landing_handoffs[entity_id] = handoff
		mutation_committed = true
	var published := _publish_network_landing_state(ship_to_abort, &"flying")
	if bool(published.get("accepted", false)):
		_network_landing_handoffs.erase(entity_id)
	return {
		"accepted": bool(published.get("accepted", false)),
		"status": (
			&"network_landing_aborted"
			if bool(published.get("accepted", false))
			else &"network_landing_abort_publication_failed"
		),
		"mutation_committed": mutation_committed,
		"retryable": not bool(published.get("accepted", false)),
		"handoff": handoff.duplicate(true),
		"publication": published.duplicate(true),
	}


func _release_network_landing_handoff(
	ship_to_release: HeroShip,
	berth: ShipBerth,
) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server() \
			or _network_session_mode != &"server":
		return {"accepted": true, "status": &"network_landing_not_required"}
	if not is_instance_valid(ship_to_release) or not is_instance_valid(berth):
		return {"accepted": false, "status": &"physical_landing_owner_unavailable"}
	var entity_id := ship_to_release.get_ship_id()
	var handoff := _network_landing_handoffs.get(entity_id, {}) as Dictionary
	if handoff.is_empty():
		var entity := network_session.get_landing_entity(entity_id) as Dictionary
		if entity.is_empty() or entity.get("state") == &"flying":
			return {"accepted": true, "status": &"network_landing_not_tracked"}
		return {"accepted": false, "status": &"landed_handoff_unavailable"}
	if handoff.get("state") not in [
		&"landed", &"release_pending_publication"
	]:
		return {"accepted": false, "status": &"landed_handoff_unavailable"}
	var physical_token := StringName(handoff.get("physical_token", &""))
	if berth.get_occupant() != ship_to_release \
			or berth.get_berth_id() != StringName(handoff.get("target_id", &"")) \
			or not berth.has_valid_lease(
				ship_to_release, physical_token, entity_id
			):
		return {"accepted": false, "status": &"physical_berth_occupancy_mismatch"}
	var next_generation := int(handoff.get("released_entity_generation", 0))
	if handoff.get("state") == &"landed":
		var released := network_session.release_server_landing(
			entity_id,
			int(handoff.get("entity_generation", 0)),
			StringName(handoff.get("network_lease_id", &"")),
		)
		if not bool(released.get("accepted", false)):
			return released
		next_generation = int(released.get("entity_generation", 0))
		_network_landing_entities[entity_id] = next_generation
		handoff["state"] = &"release_pending_publication"
		handoff["released_entity_generation"] = next_generation
		_network_landing_handoffs[entity_id] = handoff
	var published := _publish_network_landing_state(ship_to_release, &"flying")
	if bool(published.get("accepted", false)):
		_network_landing_handoffs.erase(entity_id)
	return {
		"accepted": bool(published.get("accepted", false)),
		"status": (
			&"network_landing_released"
			if bool(published.get("accepted", false))
			else &"network_landing_release_publication_failed"
		),
		"entity_generation": next_generation,
		"mutation_committed": true,
		"retryable": not bool(published.get("accepted", false)),
		"publication": published.duplicate(true),
	}


## Ensures completion paths that did not originate in `_try_request_landing`
## still enter the same server-owned reserve -> commit -> publish lifecycle.
## A committed mutation with a failed publication remains in the handoff ledger
## so retrying this method only republishes; it never commits occupancy twice.
func _ensure_network_landing_handoff_committed(
	ship_to_land: HeroShip,
	berth: ShipBerth,
) -> Dictionary:
	if not is_instance_valid(network_session) or not network_session.is_server() \
			or _network_session_mode != &"server":
		return {"accepted": true, "status": &"network_landing_not_required"}
	if not is_instance_valid(ship_to_land) or not is_instance_valid(berth):
		return {
			"accepted": false,
			"status": &"physical_landing_owner_unavailable",
			"retryable": true,
		}
	var entity_id := ship_to_land.get_ship_id()
	if not _network_landing_handoffs.has(entity_id):
		var begun := _begin_network_landing_handoff(ship_to_land, berth)
		if not bool(begun.get("accepted", false)):
			begun["retryable"] = true
			return begun
	var committed := _commit_network_landing_handoff(ship_to_land, berth)
	if not bool(committed.get("accepted", false)):
		committed["retryable"] = true
	return committed


func _on_landing_completed(source_ship: HeroShip = null) -> void:
	if _network_session_mode == &"client":
		return
	if source_ship != null and source_ship != active_ship:
		return
	if phase not in [Phase.RETURN_TO_YARD, Phase.FREE_FLIGHT] or not _sortie_departed_berth:
		return
	var landing_report := active_ship.get_landing_contract_report()
	if (
		not _landing_request_active
		or _active_landing_berth_id.is_empty()
		or not bool(landing_report.get("contract_accepted", false))
		or not bool(landing_report.get("strict_dock_acceptance", false))
		or landing_report.get("berth_id", &"") != _active_landing_berth_id
	):
		return
	if _planetary_return_physical_arrival_required:
		var physical_berth := (
			world.call(&"get_berth_node", _active_landing_berth_id) as ShipBerth
			if is_instance_valid(world) and world.has_method(&"get_berth_node")
			else null
		)
		var network_landing := _ensure_network_landing_handoff_committed(
			active_ship, physical_berth
		)
		_last_network_landing_handoff_result = network_landing.duplicate(true)
		if not bool(network_landing.get("accepted", false)):
			if is_instance_valid(hud):
				hud.set_interaction("", false)
				hud.set_objective(
					"Docking network handoff interrupted — berth retained; retry completion"
				)
				hud.toast(
					"Docking coordination retry pending",
					"Physical occupancy is retained until the authoritative landing publishes",
					3.5,
				)
			return
		var physical_arrival := _complete_planetary_return_physical_arrival(
			physical_berth, landing_report
		)
		if not bool(physical_arrival.get("accepted", false)):
			_landing_request_active = false
			_active_landing_berth_id = &""
			if is_instance_valid(hud):
				hud.set_interaction("", false)
				hud.set_objective(
					"The Ember return identity changed; re-align and retry the home berth"
				)
				hud.toast(
					"Return receipt rejected",
					"No station completion or reward was granted",
					3.5,
				)
		return
	var completed_berth_id := _active_landing_berth_id
	_landing_request_active = false
	_active_landing_berth_id = &""
	if not _ensure_landed_berth_occupancy(active_ship):
		_release_ship_berth(active_ship)
		hud.set_interaction("", false)
		hud.set_objective("Docking claim interrupted — keep the pad clear and retry the approach")
		hud.toast("Docking coordination fault", "The berth lease could not be secured; do not exit", 3.5)
		return
	var occupied_berth := (
		world.call(&"get_berth_node", completed_berth_id) as ShipBerth
		if is_instance_valid(world) and world.has_method(&"get_berth_node")
		else null
	)
	var network_landing := _commit_network_landing_handoff(active_ship, occupied_berth)
	if not bool(network_landing.get("accepted", false)):
		hud.set_interaction("", false)
		hud.set_objective("Docking network handoff interrupted — keep the pad clear")
		hud.toast("Docking coordination fault", "The authoritative landing was not published; do not exit", 3.5)
		return
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_complete_cargo_delivery_on_return()
	else:
		_fail_active_activity(&"returned_to_shipyard")
	_return_registered = true
	phase = Phase.SHUT_DOWN
	publish_first_sortie_tutorial_phase(&"exit", _first_sortie_tutorial_generation)
	hud.set_objective("Hold controls neutral, then exit %s" % active_ship.get_display_name())
	hud.toast("Landing complete", "Docking clamps engaged — propulsion will idle offline")


## Supplies the retained nearby race with Main's already-loaded atomic store.
## The binding restores only a displayable best result and reward receipt; it
## cannot restore a live/completed activity generation.
func bind_cinder_race_best_persistence(binding: Object) -> Dictionary:
	if binding == null \
			or not binding.has_method(&"configure_cinder_race_best_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"race_best_persistence_unavailable"}
	return binding.call(
		&"configure_cinder_race_best_persistence",
		_runtime_settings_user_data_store,
		CINDER_RACE_BEST_PERSISTENCE_SLOT
	) as Dictionary


## Supplies the retained scan receiver with Main's already-loaded atomic store.
## Only its terminal receipt is restored; scan and reward authority stay idle.
func bind_cinder_scan_discovery_persistence(binding: Object) -> Dictionary:
	if binding == null \
			or not binding.has_method(&"configure_cinder_scan_discovery_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"scan_discovery_persistence_unavailable"}
	return binding.call(
		&"configure_cinder_scan_discovery_persistence",
		_runtime_settings_user_data_store,
		CINDER_SCAN_DISCOVERY_PERSISTENCE_SLOT
	) as Dictionary


## Supplies the retained Cinder cargo presentation with Main's atomic store.
## Only authenticated terminal receipts return; manifests stay session-owned.
func bind_cinder_cargo_delivery_persistence(binding: Object) -> Dictionary:
	if binding == null \
			or not binding.has_method(&"configure_cinder_cargo_delivery_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"cargo_delivery_persistence_unavailable"}
	return binding.call(
		&"configure_cinder_cargo_delivery_persistence",
		_runtime_settings_user_data_store,
		CINDER_CARGO_DELIVERY_PERSISTENCE_SLOT
	) as Dictionary


## Supplies the retained mining presentation with Main's atomic store. Only a
## terminal capacity receipt returns; ore and extraction authority stay live-only.
func bind_cinder_mining_capacity_persistence(binding: Object) -> Dictionary:
	if binding == null \
			or not binding.has_method(&"configure_cinder_mining_capacity_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"mining_capacity_persistence_unavailable"}
	return binding.call(
		&"configure_cinder_mining_capacity_persistence",
		_runtime_settings_user_data_store,
		CINDER_MINING_CAPACITY_PERSISTENCE_SLOT
	) as Dictionary


## Supplies the retained Cinder convoy presentation with Main's already-loaded
## atomic store. Only a generation-authenticated safe-arrival/reward receipt is
## restored; the host stays idle and receives no movement, samples, or combat.
func bind_cinder_convoy_arrival_persistence(binding: Object) -> Dictionary:
	if binding == null \
			or not binding.has_method(&"configure_cinder_convoy_arrival_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"convoy_arrival_persistence_unavailable"}
	return binding.call(
		&"configure_cinder_convoy_arrival_persistence",
		_runtime_settings_user_data_store,
		CINDER_CONVOY_ARRIVAL_PERSISTENCE_SLOT
	) as Dictionary


## Binds the terminal Ember relay-survey receipt bridge to this Main's
## already-loaded UserDataStore. No filesystem or reward authority is created.
func bind_ember_relay_survey_persistence(binding: Object) -> Dictionary:
	if binding == null or not binding.has_method(&"configure_relay_survey_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"survey_persistence_unavailable"}
	var result := binding.call(
		&"configure_relay_survey_persistence",
		_runtime_settings_user_data_store, EMBER_RELAY_SURVEY_PERSISTENCE_SLOT
	) as Dictionary
	if bool(result.get("accepted", false)):
		_ember_relay_survey_persistence_binding = binding
	return result


func restore_ember_relay_survey_persistence() -> Dictionary:
	if _ember_relay_survey_persistence_binding == null \
			or not _ember_relay_survey_persistence_binding.has_method(
				&"restore_relay_survey_persistence"
			):
		return {"accepted": false, "reason": &"survey_persistence_unavailable"}
	return _ember_relay_survey_persistence_binding.call(
		&"restore_relay_survey_persistence"
	) as Dictionary


## Consumes one trusted physical service-terminal request. GameFlow supplies
## player/craft/landing/ownership evidence; RepairAuthority retains the only
## repair token and commits through the ship-local component adapter.
func _commit_ember_service_terminal_repair(request: Variant) -> Dictionary:
	if not request is Dictionary:
		return {"accepted": false, "reason": &"invalid_service_terminal_request"}
	var evidence := request as Dictionary
	var required_keys := [
		"terminal_id", "terminal_generation", "request_sequence",
		"host_generation", "attachment_generation", "actor_instance_id",
		"terminal_world_position",
	]
	if evidence.size() != required_keys.size():
		return {"accepted": false, "reason": &"invalid_service_terminal_request"}
	for key in required_keys:
		if not evidence.has(key):
			return {"accepted": false, "reason": &"invalid_service_terminal_request"}
	var terminal_position: Variant = evidence.get("terminal_world_position")
	if evidence.get("terminal_generation") is not int \
			or evidence.get("request_sequence") is not int \
			or evidence.get("host_generation") is not int \
			or evidence.get("attachment_generation") is not int \
			or evidence.get("actor_instance_id") is not int:
		return {"accepted": false, "reason": &"invalid_service_terminal_request"}
	var terminal_generation := int(evidence.get("terminal_generation", -1))
	var host_generation := int(evidence.get("host_generation", -1))
	var attachment_generation := int(evidence.get("attachment_generation", -1))
	var request_sequence := int(evidence.get("request_sequence", -1))
	if StringName(evidence.get("terminal_id", &"")) != EMBER_SERVICE_TERMINAL_ID \
			or terminal_position is not Vector3 \
			or not (terminal_position as Vector3).is_finite() \
			or terminal_generation < 1 or host_generation < 1 \
			or attachment_generation < 1 or request_sequence < 1:
		return {"accepted": false, "reason": &"invalid_service_terminal_request"}
	if not is_instance_valid(player) \
			or int(evidence.get("actor_instance_id", 0)) != player.get_instance_id() \
			or not player.has_method(&"is_seated") \
			or bool(player.call(&"is_seated")) or _piloting:
		return {"accepted": false, "reason": &"service_player_not_on_foot"}
	var actor_distance := player.global_position.distance_to(terminal_position as Vector3)
	if not is_finite(actor_distance) or actor_distance > EMBER_SERVICE_ACTOR_RANGE_METERS:
		return {"accepted": false, "reason": &"service_actor_out_of_range"}
	if not is_instance_valid(active_ship) or not ships.has(active_ship):
		return {"accepted": false, "reason": &"service_owned_craft_unavailable"}
	var telemetry := active_ship.get_telemetry()
	if not bool(telemetry.get("landed", false)) \
			or bool(telemetry.get("landing_active", false)) \
			or bool(telemetry.get("destroyed", false)):
		return {"accepted": false, "reason": &"service_craft_not_landed"}
	var craft_distance := active_ship.global_position.distance_to(
		terminal_position as Vector3
	)
	if not is_finite(craft_distance) or craft_distance > EMBER_SERVICE_CRAFT_RANGE_METERS:
		return {"accepted": false, "reason": &"service_target_out_of_range"}
	var model := active_ship.get_component_damage()
	if model == null or not model.is_configured():
		return {"accepted": false, "reason": &"component_damage_unavailable"}
	var selected_component := &""
	var selected_integrity := 1.0
	for component_value in model.get_component_report().get("components", []) as Array:
		var component := component_value as Dictionary
		var integrity := float(component.get("integrity", 1.0))
		if integrity < selected_integrity:
			selected_component = StringName(component.get("id", &""))
			selected_integrity = integrity
	if selected_component.is_empty() or selected_integrity >= 1.0:
		return {"accepted": false, "reason": &"no_damaged_component"}
	var service_context := {
		"host_generation": host_generation,
		"terminal_generation": terminal_generation,
		"actor_instance_id": player.get_instance_id(),
		"target_instance_id": active_ship.get_instance_id(),
		"component_generation": model.get_ledger_generation(),
	}
	if _ember_service_repair_authority == null:
		var actor_id := StringName("ember_player_%d" % player.get_instance_id())
		var target_id := StringName("ember_craft_%d" % active_ship.get_instance_id())
		_ember_service_repair_authority = RepairAuthorityType.new(
			actor_id, target_id, EMBER_SERVICE_RESOURCE_ID,
			EMBER_SERVICE_CRAFT_RANGE_METERS, 0.0,
			EMBER_SERVICE_REPAIR_AMOUNT, 1,
			EMBER_SERVICE_TERMINAL_ID, terminal_generation,
			EMBER_SERVICE_ACTOR_RANGE_METERS
		) as RepairAuthority
		if _ember_service_repair_authority == null \
				or not _ember_service_repair_authority.is_configuration_valid() \
				or not bool(_ember_service_repair_authority.begin_generation(
					model.get_ledger_generation()
				).get("accepted", false)):
			_ember_service_repair_authority = null
			return {"accepted": false, "reason": &"service_repair_authority_unavailable"}
		_ember_service_repair_context = service_context.duplicate(true)
	elif service_context != _ember_service_repair_context:
		var previous_host := int(_ember_service_repair_context.get("host_generation", -1))
		var previous_terminal := int(
			_ember_service_repair_context.get("terminal_generation", -1)
		)
		if host_generation < previous_host \
				or (host_generation == previous_host \
				and terminal_generation <= previous_terminal):
			return {"accepted": false, "reason": &"stale_service_terminal_context"}
		if _ember_service_repair_authority.has_active_repair():
			_ember_service_repair_authority.interrupt(&"service_terminal_changed")
		_ember_service_repair_authority = null
		_ember_service_repair_context.clear()
		return _commit_ember_service_terminal_repair(evidence)
	var actor_id := StringName("ember_player_%d" % player.get_instance_id())
	var target_id := StringName("ember_craft_%d" % active_ship.get_instance_id())
	var requested := _ember_service_repair_authority.request_repair({
		"actor_id": actor_id,
		"target_id": target_id,
		"component_id": selected_component,
		"generation": model.get_ledger_generation(),
		"distance_meters": craft_distance,
		"actor_distance_meters": actor_distance,
		"resource_id": EMBER_SERVICE_RESOURCE_ID,
		"interrupted": false,
		"admission_kind": RepairAuthorityType.ADMISSION_SERVICE_TERMINAL,
		"terminal_id": EMBER_SERVICE_TERMINAL_ID,
		"terminal_generation": terminal_generation,
		"request_sequence": request_sequence,
		"player_on_foot": true,
		"craft_landed": true,
		"craft_owned": true,
		"repair": EMBER_SERVICE_REPAIR_AMOUNT,
	})
	if not bool(requested.get("accepted", false)):
		return requested
	var committed := _ember_service_repair_authority.commit_component_repair(
		model, int(requested.get("token", -1))
	)
	if not bool(committed.get("accepted", false)):
		return committed
	var result := committed.duplicate(true)
	result["reason"] = &"ember_service_component_repaired"
	result["component_id"] = selected_component
	result["integrity_before"] = selected_integrity
	result["integrity_after"] = model.get_component_integrity(selected_component)
	result["actor_distance_meters"] = actor_distance
	result["craft_distance_meters"] = craft_distance
	result["authority_path"] = &"repair_authority_component_adapter"
	if is_instance_valid(hud):
		hud.toast(
			"Bunker service complete",
			"%s restored to %d%%" % [
				str(selected_component).replace("_", " ").capitalize(),
				roundi(float(result.integrity_after) * 100.0),
			],
			3.0
		)
	return result


## Binds the caller-owned Ember persistence bridge to this Main's already-loaded
## UserDataStore. No filesystem or save authority is created here.
func bind_planetary_return_persistence(binding: Object) -> Dictionary:
	if binding == null or not binding.has_method(&"configure_planetary_return_persistence") \
			or _runtime_settings_user_data_store == null:
		return {"accepted": false, "reason": &"planetary_return_persistence_unavailable"}
	var result: Dictionary = binding.call(
		&"configure_planetary_return_persistence",
		_runtime_settings_user_data_store, PLANETARY_RETURN_PERSISTENCE_SLOT
	)
	if bool(result.get("accepted", false)):
		_planetary_return_persistence_binding = binding
	return result


func restore_planetary_return_persistence() -> Dictionary:
	if _planetary_return_persistence_binding == null \
			or not _planetary_return_persistence_binding.has_method(&"restore_planetary_return_persistence"):
		return {"accepted": false, "reason": &"planetary_return_persistence_unavailable"}
	return _planetary_return_persistence_binding.call(&"restore_planetary_return_persistence")


## Startup observes one detached terminal record only long enough to retire its
## persistence slot. The saved gameplay receipt is never dispatched back into
## movement, berth, reward, or GameFlow completion authority.
func _restore_and_retire_planetary_return_persistence() -> Dictionary:
	if _planetary_return_startup_retired:
		return {
			"accepted": false,
			"reason": &"planetary_return_startup_already_retired",
		}
	if _planetary_return_startup_retirement_pending:
		return retry_planetary_return_persistence_retirement()
	var restored := restore_planetary_return_persistence()
	_planetary_return_startup_restore_receipt = restored.duplicate(true)
	if not _planetary_return_startup_restore_is_authentic(restored):
		if bool(restored.get("accepted", false)):
			return {
				"accepted": false,
				"reason": &"planetary_return_startup_restore_invalid",
			}.duplicate(true)
		return restored
	var store_generation := int(restored.get("store_generation", -1))
	_planetary_return_startup_retirement_store_generation = store_generation
	_planetary_return_startup_retirement_commit_id = (
		PLANETARY_RETURN_RETIRE_COMMIT_PREFIX + "%010d" % store_generation
	)
	_planetary_return_startup_retirement_pending = true
	return retry_planetary_return_persistence_retirement()


## A failed atomic write retains the exact restored generation and deterministic
## commit ID. Retrying cannot re-run restore or replay any gameplay evidence.
func retry_planetary_return_persistence_retirement() -> Dictionary:
	if _planetary_return_startup_retired:
		return {
			"accepted": false,
			"reason": &"planetary_return_startup_already_retired",
		}
	if not _planetary_return_startup_retirement_pending:
		return {
			"accepted": false,
			"reason": &"planetary_return_retirement_not_pending",
		}
	if _planetary_return_persistence_binding == null \
			or not _planetary_return_persistence_binding.has_method(
				&"retire_planetary_return_persistence"
			):
		_planetary_return_startup_retirement_result = {
			"accepted": false,
			"reason": &"planetary_return_persistence_unavailable",
		}.duplicate(true)
		return _planetary_return_startup_retirement_result.duplicate(true)
	var retired := _planetary_return_persistence_binding.call(
		&"retire_planetary_return_persistence",
		_planetary_return_startup_retirement_store_generation,
		_planetary_return_startup_retirement_commit_id,
	) as Dictionary
	_planetary_return_startup_retirement_result = retired.duplicate(true)
	if bool(retired.get("accepted", false)):
		_planetary_return_startup_retirement_pending = false
		_planetary_return_startup_retired = true
	return retired


func _planetary_return_startup_restore_is_authentic(
		restored: Dictionary
	) -> bool:
	if not bool(restored.get("accepted", false)) \
			or StringName(restored.get("reason", &"")) \
				!= &"return_persistence_loaded" \
			or not bool(restored.get("detached", false)) \
			or not bool(restored.get("fresh_station", false)) \
			or not bool(restored.get("requires_retirement", false)) \
			or not restored.get("store_generation") is int:
		return false
	var store_generation := int(restored.get("store_generation", -1))
	if store_generation < 0 \
			or store_generation > PLANETARY_RETURN_RETIRE_MAX_STORE_GENERATION \
			or not restored.get("session") is Dictionary:
		return false
	var session := restored.get("session", {}) as Dictionary
	if not bool(session.get("accepted", false)) \
			or StringName(session.get("reason", &"")) \
				!= &"returned_to_station_restored" \
			or StringName(session.get("marker", &"")) != &"returned_to_station" \
			or int(session.get("run_generation", 0)) < 1 \
			or int(session.get("attachment_generation", 0)) < 1 \
			or int(session.get("actor_instance_id", 0)) < 1 \
			or int(session.get("craft_instance_id", 0)) < 1 \
			or str(session.get("receipt_sha256", "")).length() != 64 \
			or bool(session.get("reward_replay_allowed", true)):
		return false
	if not session.get("surface_attachment") is Dictionary \
			or not session.get("berth_lease") is Dictionary:
		return false
	var surface := session.get("surface_attachment", {}) as Dictionary
	var berth := session.get("berth_lease", {}) as Dictionary
	if bool(surface.get("active", true)) \
			or StringName(surface.get("state", &"")) != &"detached" \
			or bool(berth.get("active", true)) \
			or StringName(berth.get("state", &"")) != &"fresh_station":
		return false
	for authority_key in [
		"reward_authority", "reward_grant_authority", "movement_authority",
		"ship_movement_authority", "teleport_authority", "reparent_authority",
		"berth_authority", "reservation_authority", "occupancy_authority",
		"lease_authority", "attachment_authority", "release_authority",
		"game_flow_authority",
	]:
		if bool(session.get(authority_key, false)):
			return false
	return true


## Caller-facing Ember surface admission. The host and activity/reward callback
## remain caller-owned; this seam only binds the retained production composition
## and queues the existing disembark intent. It never moves a craft or starts a
## second travel/landing authority.
func begin_ember_surface_journey(
		host: Object, director: ActivityDirector, reward_sink: Callable,
		caller_serial: int
	) -> Dictionary:
	if host == null or director == null or not reward_sink.is_valid() or caller_serial < 1:
		return {"accepted": false, "reason": &"ember_surface_request_invalid"}
	if not is_instance_valid(active_ship) or not active_ship.is_piloted() \
			or phase in [Phase.INTERCEPTOR_ENGAGEMENT, Phase.FAILED, Phase.SHUT_DOWN]:
		return {"accepted": false, "reason": &"ember_surface_actor_unavailable"}
	var cruise_gate_reason := _planetary_cruise_gate_reason(false)
	if not cruise_gate_reason.is_empty():
		return {"accepted": false, "reason": cruise_gate_reason}
	if not is_instance_valid(planetary_cruise_binding):
		return {"accepted": false, "reason": &"ember_cruise_binding_unavailable"}
	var cruise_snapshot := planetary_cruise_binding.get_snapshot()
	if not bool(cruise_snapshot.get("activated", false)):
		return {"accepted": false, "reason": &"ember_cruise_binding_not_ready"}
	if not bool(cruise_snapshot.get("engagement_requested", false)):
		var engaged := planetary_cruise_binding.request_engage(
			active_ship,
			int(cruise_snapshot.get("current_coordinate_frame_generation", 0)),
			&"",
			planetary_cruise_binding.get_generation()
		)
		if not bool(engaged.get("accepted", false)):
			return engaged
	if not is_instance_valid(ember_streaming_binding):
		return {"accepted": false, "reason": &"ember_streaming_binding_unavailable"}
	var streaming := ember_streaming_binding.get_snapshot()
	var host_snapshot: Dictionary = host.get_snapshot()
	var host_ready := bool(host_snapshot.get("attached", false)) \
			and int(host_snapshot.get("phase", -1)) == EmberSurfaceLoopHost.Phase.IDLE
	if not host_ready \
			or not bool(streaming.get("activated", false)) \
			or int(streaming.get("bound_coordinate_frame_generation", 0)) \
			!= int(streaming.get("current_coordinate_frame_generation", -1)):
		_pending_ember_surface_host = host
		_pending_ember_surface_director = director
		_pending_ember_surface_reward_sink = reward_sink
		_pending_ember_surface_serial = caller_serial
		_pending_ember_surface_request = {
			"host_instance_id": host.get_instance_id(),
			"caller_serial": caller_serial,
			"streaming_generation": int(streaming.get("current_coordinate_frame_generation", -1)),
		}.duplicate(true)
		return {"accepted": true, "reason": &"ember_surface_journey_pending_stream", "pending": _pending_ember_surface_request.duplicate(true)}
	if not is_instance_valid(ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"ember_surface_binding_unavailable"}
	var binding := ember_surface_loop_production_binding
	var binding_snapshot := binding.get_snapshot()
	if not bool(binding_snapshot.get("configured", false)):
		var configured: Dictionary = binding.configure(host, binding.get_generation())
		if not bool(configured.get("accepted", false)):
			return configured
	if binding.get_planetary_surface_snapshot().is_empty():
		var composed: Dictionary = binding.configure_planetary_surface(
			director, reward_sink, null,
			Callable(self, &"_commit_ember_service_terminal_repair")
		)
		if not bool(composed.get("accepted", false)):
			return composed
	var survey_restore: Dictionary = {}
	if binding == _ember_relay_survey_persistence_binding:
		survey_restore = restore_ember_relay_survey_persistence()
	var final_approach := _arm_ember_final_approach(host)
	if not bool(final_approach.get("accepted", false)):
		return final_approach
	# Admission starts the retained surface journey. Disembark is a later,
	# phase-specific caller intent after the Host has actually reached LANDED;
	# queuing it while the binding is still IDLE necessarily rejects because no
	# same-frame caller envelope exists yet.
	_ember_surface_journey_active = true
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	_mudds_return_handback_consumption_attempted = false
	_mudds_return_handback_receipt.clear()
	_mudds_station_return_intent_consumption_attempted = false
	_mudds_station_return_intent_receipt.clear()
	_last_mudds_station_return_intent_result.clear()
	_mudds_return_approach_active = false
	_mudds_return_approach_completion_attempted = false
	_mudds_return_approach_completion_receipt.clear()
	_last_mudds_return_approach_result.clear()
	_planetary_return_receipt_consumed = false
	_planetary_return_physical_arrival_required = false
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result.clear()
	# A prior completed attempt retains evidence until a new journey is admitted.
	# Resetting here cannot release GameFlow's berth because the physical adapter
	# explicitly adopts, rather than owns, that lease.
	if ember_surface_loop_production_binding.has_method(
		&"reset_planetary_return_berth"
	):
		ember_surface_loop_production_binding.reset_planetary_return_berth()
	return {
		"accepted": true,
		"reason": &"ember_surface_journey_admitted",
		"binding_generation": binding.get_generation(),
		"caller_serial": caller_serial,
		"relay_survey_persistence": survey_restore.duplicate(true),
	}


func _arm_ember_final_approach(host: Object) -> Dictionary:
	if host != ember_surface_loop_host \
			or not is_instance_valid(ember_surface_loop_host):
		return {"accepted": false, "reason": &"ember_surface_host_identity_mismatch"}
	if not is_instance_valid(planetary_cruise_binding) \
			or not is_instance_valid(ember_streaming_bootstrap):
		return {"accepted": false, "reason": &"ember_final_approach_unavailable"}
	var host_snapshot := ember_surface_loop_host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE:
		return {"accepted": false, "reason": &"ember_surface_host_not_ready"}
	var approach := host_snapshot.get("approach_entry", {}) as Dictionary
	var envelope := approach.get("envelope", {}) as Dictionary
	if envelope.is_empty():
		return {"accepted": false, "reason": &"ember_approach_envelope_unavailable"}
	var loaded_scene := ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded_scene):
		return {"accepted": false, "reason": &"ember_loaded_scene_unavailable"}
	var landing_root := loaded_scene.get_node_or_null(^"LandingRegion") as Node3D
	if not is_instance_valid(landing_root):
		return {"accepted": false, "reason": &"ember_landing_root_unavailable"}
	var cruise_snapshot := planetary_cruise_binding.get_snapshot()
	var existing := cruise_snapshot.get("final_approach", {}) as Dictionary
	if int(existing.get("target_generation", 0)) > 0:
		return {"accepted": true, "reason": &"final_approach_already_armed"}
	return planetary_cruise_binding.request_final_approach(
		ember_surface_loop_host,
		landing_root,
		envelope,
		int(host_snapshot.get("coordinate_frame_generation", 0)),
		int(host_snapshot.get("location_generation", 0)),
		int(host_snapshot.get("generation", -1)),
		int(host_snapshot.get("attachment_generation", 0)),
		planetary_cruise_binding.get_generation(),
	)


func _ember_final_approach_completion_is_current(receipt: Dictionary) -> bool:
	if not is_instance_valid(ember_surface_loop_host) \
			or not is_instance_valid(active_ship) \
			or not is_instance_valid(planetary_cruise_binding):
		return false
	var host_snapshot := ember_surface_loop_host.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) != EmberSurfaceLoopHost.Phase.IDLE \
			or int(receipt.get("host_instance_id", 0)) \
				!= ember_surface_loop_host.get_instance_id() \
			or int(receipt.get("host_generation", -2)) \
				!= int(host_snapshot.get("generation", -1)) \
			or int(receipt.get("host_attachment_generation", 0)) \
				!= int(host_snapshot.get("attachment_generation", -1)) \
			or int(receipt.get("coordinate_frame_generation", 0)) \
				!= int(host_snapshot.get("coordinate_frame_generation", -1)) \
			or int(receipt.get("location_generation", 0)) \
				!= int(host_snapshot.get("location_generation", -1)) \
			or int(receipt.get("ship_instance_id", 0)) != active_ship.get_instance_id():
		return false
	var release := receipt.get("controller_release", {}) as Dictionary
	var ship_report := active_ship.get_planetary_cruise_attachment_report()
	return bool(release.get("accepted", false)) \
		and int(receipt.get("released_ship_attachment_generation", 0)) \
			== int(ship_report.get("ship_attachment_generation", -1)) \
		and int(ship_report.get("controller_instance_id", -1)) == 0


func _consume_ember_final_approach_completion(receipt: Dictionary) -> Dictionary:
	if not is_instance_valid(planetary_cruise_binding):
		return {"accepted": false, "reason": &"ember_cruise_binding_unavailable"}
	var target_generation := int(receipt.get("target_generation", 0))
	if _ember_final_approach_completion_is_current(receipt):
		var consumed := planetary_cruise_binding.consume_final_approach_completion(
			target_generation, planetary_cruise_binding.get_generation()
		)
		if bool(consumed.get("accepted", false)):
			_ember_final_approach_completion_receipt = consumed.duplicate(true)
			_ember_final_approach_handoff_ready = true
		return consumed
	var discarded := planetary_cruise_binding.discard_final_approach_completion(
		target_generation, planetary_cruise_binding.get_generation(),
		&"final_approach_completion_stale",
	)
	_ember_surface_journey_active = false
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	return discarded


## Takes the authority-free station-route intent while the retained Host and
## travel session are still attached. The binding owns publication/delivery
## fencing; GameFlow only authenticates the detached route identity against its
## live actor, Host and sole common-origin frame. A rejected intent never arms
## cruise, landing, or berth state.
func _consume_mudds_station_return_handoff_intent(
		coordinate_frame_generation: int
	) -> Dictionary:
	if _mudds_station_return_intent_consumption_attempted:
		return {
			"accepted": false,
			"reason": &"station_return_handoff_already_observed",
		}.duplicate(true)
	if not is_instance_valid(ember_surface_loop_production_binding) \
			or not ember_surface_loop_production_binding.has_method(
				&"take_planetary_station_return_handoff_intent"
			):
		return {
			"accepted": false,
			"reason": &"station_return_handoff_binding_unavailable",
		}.duplicate(true)
	var binding_snapshot := ember_surface_loop_production_binding.get_snapshot()
	if not bool(binding_snapshot.get("station_return_handoff_pending", false)):
		return {
			"accepted": false,
			"reason": &"station_return_handoff_not_pending",
		}.duplicate(true)
	_mudds_station_return_intent_consumption_attempted = true
	var taken := ember_surface_loop_production_binding.call(
		&"take_planetary_station_return_handoff_intent",
		ember_surface_loop_production_binding.get_generation(),
	) as Dictionary
	if not bool(taken.get("accepted", false)):
		_last_mudds_station_return_intent_result = taken.duplicate(true)
		return taken
	var intent := taken.get("intent", {}) as Dictionary
	var rejection := _mudds_station_return_handoff_rejection(
		intent, binding_snapshot, coordinate_frame_generation
	)
	if not rejection.is_empty():
		var aborted: Dictionary = {}
		if ember_surface_loop_production_binding.has_method(
			&"abort_planetary_relay_survey_return"
		):
			aborted = ember_surface_loop_production_binding.call(
				&"abort_planetary_relay_survey_return", rejection
			) as Dictionary
		_last_mudds_station_return_intent_result = {
			"accepted": false,
			"reason": rejection,
			"return_intent_abort": aborted.duplicate(true),
		}.duplicate(true)
		return _last_mudds_station_return_intent_result.duplicate(true)
	_mudds_station_return_intent_receipt = intent.duplicate(true)
	_last_mudds_station_return_intent_result = {
		"accepted": true,
		"reason": &"station_return_handoff_consumed",
		"intent": intent.duplicate(true),
	}.duplicate(true)
	return _last_mudds_station_return_intent_result.duplicate(true)


func _mudds_station_return_handoff_rejection(
		intent: Dictionary,
		binding_snapshot: Dictionary,
		coordinate_frame_generation: int
	) -> StringName:
	if intent.size() != EMBER_STATION_RETURN_HANDOFF_KEYS.size():
		return &"station_return_handoff_schema_invalid"
	for key in EMBER_STATION_RETURN_HANDOFF_KEYS:
		if not intent.has(key):
			return &"station_return_handoff_schema_invalid"
	if int(intent.get("schema_version", 0)) != 1 \
			or StringName(intent.get("intent_id", &"")) \
				!= &"ember_station_return_handoff" \
			or StringName(intent.get("destination_id", &"")) \
				!= MUDDS_RETURN_TARGET_ID \
			or StringName(intent.get("activity_id", &"")) \
				!= &"ember_beacon_survey" \
			or int(intent.get("activity_generation", 0)) < 1 \
			or bool(intent.get("arrival_confirmed", true)) \
			or not intent.get("evidence_sequence") is PackedStringArray \
			or intent.get("evidence_sequence") \
				!= PackedStringArray(EMBER_STATION_RETURN_EVIDENCE_SEQUENCE):
		return &"station_return_handoff_contract_invalid"
	if not is_instance_valid(active_ship) or not is_instance_valid(player) \
			or int(intent.get("actor_instance_id", 0)) \
				!= player.get_instance_id() \
			or int(intent.get("craft_instance_id", 0)) \
				!= active_ship.get_instance_id():
		return &"station_return_handoff_actor_drift"
	if not is_instance_valid(ember_surface_loop_host):
		return &"station_return_handoff_host_drift"
	var host_snapshot := ember_surface_loop_host.get_snapshot()
	var host_identities := host_snapshot.get("identities", {}) as Dictionary
	if not bool(host_snapshot.get("attached", false)) \
			or int(host_snapshot.get("phase", -1)) \
				!= EmberSurfaceLoopHost.Phase.ORBIT_RETURN \
			or int(intent.get("session_generation", 0)) \
				!= ember_surface_loop_host.get_generation() \
			or int(intent.get("attachment_generation", 0)) \
				!= ember_surface_loop_host.get_attachment_generation() \
			or int(host_identities.get("player_instance_id", 0)) \
				!= player.get_instance_id() \
			or int(host_identities.get("ship_instance_id", 0)) \
				!= active_ship.get_instance_id():
		return &"station_return_handoff_host_drift"
	var retained := binding_snapshot.get("retained_return_context", {}) as Dictionary
	if int(retained.get("host_instance_id", 0)) \
			!= ember_surface_loop_host.get_instance_id() \
			or int(retained.get("host_generation", -1)) \
				!= int(intent.get("session_generation", 0)) \
			or int(retained.get("host_attachment_generation", -1)) \
				!= int(intent.get("attachment_generation", 0)) \
			or int(retained.get("session_instance_id", 0)) == 0 \
			or int(retained.get("actor_instance_id", 0)) \
				!= player.get_instance_id() \
			or int(retained.get("craft_instance_id", 0)) \
				!= active_ship.get_instance_id() \
			or binding_snapshot.get("station_return_handoff_intent", {}) != intent:
		return &"station_return_handoff_session_drift"
	if coordinate_frame_generation < 1 \
			or int(intent.get("coordinate_frame_generation", 0)) \
				!= coordinate_frame_generation \
			or int(host_snapshot.get("coordinate_frame_generation", 0)) \
				!= coordinate_frame_generation:
		return &"station_return_handoff_frame_drift"
	if not is_instance_valid(ember_streaming_bootstrap):
		return &"station_return_handoff_frame_unavailable"
	var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
	if not is_instance_valid(frame) or frame.get_generation() \
			!= coordinate_frame_generation:
		return &"station_return_handoff_frame_drift"
	var orbital_validation := frame.validate_orbital_coordinate(
		intent.get("orbital_coordinate", {})
	)
	if not bool(orbital_validation.get("accepted", false)) \
			or orbital_validation.get("coordinate", {}) \
				!= intent.get("orbital_coordinate", {}):
		return &"station_return_handoff_coordinate_invalid"
	var authority := intent.get("authority", {}) as Dictionary
	if authority.size() != EMBER_STATION_RETURN_AUTHORITY_KEYS.size():
		return &"station_return_handoff_claims_authority"
	for key in EMBER_STATION_RETURN_AUTHORITY_KEYS:
		if not authority.has(key) or bool(authority.get(key, true)):
			return &"station_return_handoff_claims_authority"
	return &""


## Observes the surface scheduler's already-validated atomic ownership return.
## It is called from the same GameFlow physics cadence as the outbound cruise,
## after the Host has completed reboard, takeoff, ascent and orbit return. The
## handback is attempted once; a stale or malformed receipt cannot re-arm a
## later binding generation.
func _advance_mudds_return_approach_handoff(
		coordinate_frame_generation: int
	) -> Dictionary:
	if _mudds_return_handback_consumption_attempted \
			or _mudds_return_approach_active \
			or _mudds_return_approach_completion_attempted:
		return {"accepted": false, "reason": &"return_approach_handoff_already_observed"}
	if not is_instance_valid(ember_surface_loop_production_binding) \
			or not is_instance_valid(planetary_cruise_binding):
		return {"accepted": false, "reason": &"return_approach_binding_unavailable"}
	var surface_snapshot := ember_surface_loop_production_binding.get_snapshot()
	if StringName(surface_snapshot.get("state_id", &"")) != &"handoff_pending":
		return {"accepted": false, "reason": &"return_approach_handoff_not_pending"}
	_mudds_return_handback_consumption_attempted = true
	var handback := ember_surface_loop_production_binding.take_completion_handback(
		ember_surface_loop_production_binding.get_generation()
	)
	if not bool(handback.get("accepted", false)):
		_last_mudds_return_approach_result = handback.duplicate(true)
		return handback
	var ownership := handback.get("runtime_ownership_return", {}) as Dictionary
	var handback_reason := _mudds_return_handback_rejection(ownership)
	if not handback_reason.is_empty():
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": handback_reason,
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	_mudds_return_handback_receipt = ownership.duplicate(true)
	_ember_surface_journey_active = false
	if _mudds_station_return_intent_receipt.is_empty():
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_station_intent_required",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	if int(_mudds_station_return_intent_receipt.get(
			"coordinate_frame_generation", 0
		)) != coordinate_frame_generation:
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_station_intent_stale",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var target_result := _build_mudds_return_approach_target()
	if not bool(target_result.get("accepted", false)):
		_last_mudds_return_approach_result = target_result.duplicate(true)
		return target_result
	if coordinate_frame_generation < 1:
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_coordinate_frame_unavailable",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var cruise_snapshot := planetary_cruise_binding.get_snapshot()
	if bool(cruise_snapshot.get("engagement_requested", false)):
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_cruise_already_engaged",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var engaged := planetary_cruise_binding.request_engage(
		active_ship, coordinate_frame_generation,
		_planetary_cruise_gate_reason(false),
		planetary_cruise_binding.get_generation(),
	)
	if not bool(engaged.get("accepted", false)):
		_last_mudds_return_approach_result = engaged.duplicate(true)
		return engaged
	var armed := planetary_cruise_binding.request_return_approach(
		target_result.get("target", {}) as Dictionary,
		coordinate_frame_generation,
		planetary_cruise_binding.get_generation(),
	)
	if not bool(armed.get("accepted", false)):
		planetary_cruise_binding.request_disengage(
			planetary_cruise_binding.get_generation(), true
		)
		_last_mudds_return_approach_result = armed.duplicate(true)
		return armed
	_mudds_return_approach_active = true
	_last_mudds_return_approach_result = armed.duplicate(true)
	return armed


func _mudds_return_handback_rejection(receipt: Dictionary) -> StringName:
	if not is_instance_valid(active_ship) or not is_instance_valid(player):
		return &"return_approach_actor_unavailable"
	if receipt.get("reason", &"") != &"runtime_ownership_returned" \
			or int(receipt.get("ship_instance_id", 0)) != active_ship.get_instance_id() \
			or int(receipt.get("player_instance_id", 0)) != player.get_instance_id():
		return &"return_approach_handback_identity_mismatch"
	if not bool(receipt.get("command_source_restored", false)) \
			or not bool(receipt.get("boarding_reservation_retained", false)) \
			or not bool(receipt.get("ship_piloted", false)) \
			or not bool(receipt.get("player_seated", false)) \
			or bool(receipt.get("host_attached", true)) \
			or not active_ship.is_piloted() \
			or not bool(player.call(&"is_seated")):
		return &"return_approach_handback_state_mismatch"
	var retired_generation := int(receipt.get("retired_attachment_generation", 0))
	if retired_generation < 1 \
			or int(receipt.get("current_attachment_generation", 0)) \
				!= retired_generation + 1:
		return &"return_approach_handback_generation_mismatch"
	if not _mudds_station_return_intent_receipt.is_empty() \
			and (int(receipt.get("generation", 0)) \
			!= int(_mudds_station_return_intent_receipt.get(
				"session_generation", -1
			)) \
			or retired_generation \
				!= int(_mudds_station_return_intent_receipt.get(
					"attachment_generation", -1
				))):
		return &"return_approach_station_intent_generation_mismatch"
	return &""


## Builds detached route evidence from the existing owners only: ShipyardWorld
## publishes the current station datum, and each registered production HeroShip
## publishes its exact live landing collision bounds. GameFlow does not cache a
## second station transform or synthesize substitute hull geometry.
func _build_mudds_return_approach_target() -> Dictionary:
	if not is_instance_valid(world) or not world.has_method(&"get_ship_spawn"):
		return {"accepted": false, "reason": &"return_approach_home_target_unavailable"}
	var home_transform := world.call(&"get_ship_spawn") as Transform3D
	if not home_transform.origin.is_finite() \
			or not home_transform.basis.x.is_finite() \
			or not home_transform.basis.y.is_finite() \
			or not home_transform.basis.z.is_finite() \
			or is_zero_approx(home_transform.basis.determinant()):
		return {"accepted": false, "reason": &"return_approach_home_target_invalid"}
	var fleet_bounds: Dictionary = {}
	var maximum_x := 0.0
	var maximum_y := 0.0
	for fleet_ship in ships:
		if not is_instance_valid(fleet_ship):
			return {"accepted": false, "reason": &"return_approach_fleet_hull_unavailable"}
		var ship_id := fleet_ship.get_ship_id()
		# Additional expansion craft have their own berth owner and are outside
		# the production binding's frozen five-ID return contract.
		if not MUDDS_RETURN_FLEET_IDS.has(ship_id):
			continue
		if fleet_bounds.has(ship_id):
			return {"accepted": false, "reason": &"return_approach_fleet_roster_mismatch"}
		var collision_report := fleet_ship.get_landing_collision_report()
		var bounds := collision_report.get("local_bounds", AABB()) as AABB
		if not bool(collision_report.get("valid", false)) \
				or not bounds.position.is_finite() or not bounds.size.is_finite() \
				or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
			return {"accepted": false, "reason": &"return_approach_fleet_hull_invalid"}
		fleet_bounds[ship_id] = bounds
		maximum_x = maxf(maximum_x, maxf(absf(bounds.position.x), absf(bounds.end.x)))
		maximum_y = maxf(maximum_y, maxf(absf(bounds.position.y), absf(bounds.end.y)))
	for expected_id in MUDDS_RETURN_FLEET_IDS:
		if not fleet_bounds.has(expected_id):
			return {"accepted": false, "reason": &"return_approach_fleet_roster_mismatch"}
	var corridor_half_extents := Vector3(
		maxf(
			MUDDS_RETURN_CORRIDOR_MINIMUM_HALF_WIDTH_METERS,
			maximum_x + MUDDS_RETURN_HULL_MARGIN_METERS,
		),
		maxf(
			MUDDS_RETURN_CORRIDOR_MINIMUM_HALF_WIDTH_METERS,
			maximum_y + MUDDS_RETURN_HULL_MARGIN_METERS,
		),
		MUDDS_RETURN_CORRIDOR_HALF_LENGTH_METERS,
	)
	return {
		"accepted": true,
		"reason": &"return_approach_target_ready",
		"target": {
			"home_target_id": MUDDS_RETURN_TARGET_ID,
			"home_target_world_transform": home_transform,
			"corridor_half_extents_m": corridor_half_extents,
			"brake_shell_min_distance_m": MUDDS_RETURN_BRAKE_SHELL_MINIMUM_METERS,
			"brake_shell_max_distance_m": MUDDS_RETURN_BRAKE_SHELL_MAXIMUM_METERS,
			"maximum_speed_mps": MUDDS_RETURN_MAXIMUM_SPEED_MPS,
			"maximum_attitude_degrees": MUDDS_RETURN_MAXIMUM_ATTITUDE_DEGREES,
			"hull_margin_m": MUDDS_RETURN_HULL_MARGIN_METERS,
			"fleet_collision_bounds": fleet_bounds.duplicate(true),
		}.duplicate(true),
	}.duplicate(true)


func _mudds_return_approach_completion_is_current(receipt: Dictionary) -> bool:
	if not _mudds_return_approach_active \
			or not is_instance_valid(active_ship) \
			or not is_instance_valid(planetary_cruise_binding):
		return false
	if receipt.get("reason", &"") != &"return_approach_handoff_ready" \
			or receipt.get("home_target_id", &"") != MUDDS_RETURN_TARGET_ID \
			or int(receipt.get("target_generation", 0)) < 1 \
			or int(receipt.get("ship_instance_id", 0)) != active_ship.get_instance_id():
		return false
	var release := receipt.get("controller_release", {}) as Dictionary
	var ship_report := active_ship.get_planetary_cruise_attachment_report()
	if not bool(release.get("accepted", false)) \
			or int(receipt.get("released_ship_attachment_generation", 0)) \
				!= int(ship_report.get("ship_attachment_generation", -1)) \
			or int(ship_report.get("controller_instance_id", -1)) != 0:
		return false
	var controller_completion := receipt.get("controller_completion", {}) as Dictionary
	var target := controller_completion.get("target", {}) as Dictionary
	var measurement := controller_completion.get("measurement", {}) as Dictionary
	var current_target := _build_mudds_return_approach_target()
	var expected := current_target.get("target", {}) as Dictionary
	return bool(current_target.get("accepted", false)) \
		and target.get("home_target_id", &"") == MUDDS_RETURN_TARGET_ID \
		and target.get("home_target_world_transform", Transform3D.IDENTITY) \
			== expected.get("home_target_world_transform", Transform3D.IDENTITY) \
		and target.get("fleet_collision_bounds", {}) \
			== expected.get("fleet_collision_bounds", {}) \
		and bool(measurement.get("all_five_craft_corridor_proven", false))


## Consumes the cruise terminal receipt once, then selects the ordinary yard
## return phase. It deliberately does not move, reparent, reserve, occupy, or
## land the craft; `_request_landing_assist()` and `_on_landing_completed()`
## remain the only path into berth occupancy and shutdown.
func _consume_mudds_return_approach_completion(receipt: Dictionary) -> Dictionary:
	if _mudds_return_approach_completion_attempted:
		return {"accepted": false, "reason": &"return_approach_completion_replayed"}
	_mudds_return_approach_completion_attempted = true
	if not _mudds_return_approach_completion_is_current(receipt):
		if is_instance_valid(planetary_cruise_binding) \
				and int(receipt.get("target_generation", 0)) > 0:
			planetary_cruise_binding.discard_return_approach_completion(
				int(receipt.get("target_generation", 0)),
				planetary_cruise_binding.get_generation(),
				&"return_approach_completion_stale",
			)
		_mudds_return_approach_active = false
		_last_mudds_return_approach_result = {
			"accepted": false,
			"reason": &"return_approach_completion_stale",
		}.duplicate(true)
		return _last_mudds_return_approach_result.duplicate(true)
	var consumed := planetary_cruise_binding.consume_return_approach_completion(
		int(receipt.get("target_generation", 0)),
		planetary_cruise_binding.get_generation(),
	)
	if not bool(consumed.get("accepted", false)):
		_mudds_return_approach_active = false
		_last_mudds_return_approach_result = consumed.duplicate(true)
		return consumed
	_mudds_return_approach_completion_receipt = consumed.duplicate(true)
	_mudds_return_approach_active = false
	_ember_surface_journey_active = false
	_planetary_return_receipt_consumed = false
	_planetary_return_physical_arrival_required = true
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result.clear()
	_landing_request_active = false
	_active_landing_berth_id = &""
	_return_registered = false
	_sortie_departed_berth = true
	phase = Phase.RETURN_TO_YARD
	_last_mudds_return_approach_result = {
		"accepted": true,
		"reason": &"return_approach_handed_to_station_lifecycle",
		"phase": Phase.RETURN_TO_YARD,
		"receipt": consumed.duplicate(true),
	}.duplicate(true)
	if is_instance_valid(hud):
		hud.set_objective(
			"Approach Mudds Shipyards and engage landing assist at a compatible berth",
			"RETURN TO YARD",
		)
		hud.toast(
			"Mudds approach complete",
			"Manual flight and the registered berth lifecycle now own the return",
		)
	return _last_mudds_return_approach_result.duplicate(true)


func _current_planetary_return_frame_generation() -> int:
	if not is_instance_valid(ember_streaming_bootstrap):
		return 0
	var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
	return frame.get_generation() if is_instance_valid(frame) else 0


## Arms the evidence-only adapter only after HeroShip has synchronously accepted
## its ordinary landing request. No physics tick can complete the landing before
## this call returns, and the exact GameFlow token remains the sole lease.
func _arm_planetary_return_physical_arrival(berth: ShipBerth) -> Dictionary:
	if not _planetary_return_physical_arrival_required \
			or _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"physical_return_not_pending"}
	if _planetary_return_physical_arrival_armed:
		return {"accepted": false, "reason": &"physical_return_already_armed"}
	if not is_instance_valid(active_ship) or not is_instance_valid(player) \
			or not is_instance_valid(berth) \
			or not is_instance_valid(planetary_cruise_binding) \
			or not is_instance_valid(ember_surface_loop_production_binding) \
			or not ember_surface_loop_production_binding.has_method(
				&"adopt_physical_planetary_return_arrival"
			):
		return {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	var craft_instance_id := active_ship.get_instance_id()
	var home_berth_id := active_ship.get_home_berth_id()
	if berth.get_berth_id() != home_berth_id \
			or StringName(_reserved_berth_ids.get(craft_instance_id, &"")) \
				!= home_berth_id:
		return {"accepted": false, "reason": &"physical_return_wrong_home_berth"}
	var token := StringName(_berth_tokens.get(craft_instance_id, &""))
	var definition := active_ship.get_ship_definition()
	var frame_generation := _current_planetary_return_frame_generation()
	if token.is_empty() or definition == null or frame_generation < 1:
		return {"accepted": false, "reason": &"physical_return_identity_unavailable"}
	var adopted := ember_surface_loop_production_binding.call(
		&"adopt_physical_planetary_return_arrival",
		_mudds_return_approach_completion_receipt,
		planetary_cruise_binding.get_generation(),
		frame_generation,
		berth,
		active_ship,
		definition,
		token,
		player.get_instance_id(),
		craft_instance_id,
	) as Dictionary
	_last_planetary_return_physical_arrival_result = adopted.duplicate(true)
	_planetary_return_physical_arrival_armed = bool(adopted.get("accepted", false))
	return adopted


func _abort_planetary_return_physical_arrival(reason: StringName) -> Dictionary:
	if not _planetary_return_physical_arrival_armed:
		return {"accepted": false, "reason": &"physical_return_not_armed"}
	var aborted := {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	if is_instance_valid(ember_surface_loop_production_binding) \
			and ember_surface_loop_production_binding.has_method(
				&"abort_physical_planetary_return_arrival"
			):
		aborted = ember_surface_loop_production_binding.call(
			&"abort_physical_planetary_return_arrival", reason
		) as Dictionary
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result = aborted.duplicate(true)
	return aborted


func _complete_planetary_return_physical_arrival(
		berth: ShipBerth, landing_report: Dictionary
	) -> Dictionary:
	if not _planetary_return_physical_arrival_required \
			or not _planetary_return_physical_arrival_armed \
			or _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"physical_return_not_armed"}
	if not is_instance_valid(berth) \
			or not is_instance_valid(planetary_cruise_binding) \
			or not is_instance_valid(ember_surface_loop_production_binding):
		return {"accepted": false, "reason": &"physical_return_owner_unavailable"}
	var shell_generation := planetary_cruise_binding.get_generation()
	var frame_generation := _current_planetary_return_frame_generation()
	var confirmed := ember_surface_loop_production_binding.call(
		&"confirm_physical_planetary_return_arrival",
		landing_report,
		shell_generation,
		frame_generation,
	) as Dictionary
	if not bool(confirmed.get("accepted", false)):
		_last_planetary_return_physical_arrival_result = confirmed.duplicate(true)
		_abort_planetary_return_physical_arrival(&"physical_landing_confirmation_rejected")
		return confirmed
	var terminal := ember_surface_loop_production_binding.call(
		&"complete_physical_planetary_return_arrival",
		confirmed,
		shell_generation,
		frame_generation,
	) as Dictionary
	if not bool(terminal.get("accepted", false)):
		_last_planetary_return_physical_arrival_result = terminal.duplicate(true)
		_abort_planetary_return_physical_arrival(&"physical_landing_completion_rejected")
		return terminal
	var consumed := consume_planetary_return_receipt(
		terminal,
		ember_surface_loop_production_binding,
		berth,
		active_ship,
		player,
	) as Dictionary
	_last_planetary_return_physical_arrival_result = consumed.duplicate(true)
	_planetary_return_physical_arrival_armed = false
	if not bool(consumed.get("accepted", false)):
		return consumed
	_planetary_return_physical_arrival_required = false
	return consumed


func cancel_ember_surface_journey() -> Dictionary:
	if _pending_ember_surface_request.is_empty() \
			and not _ember_surface_journey_active:
		return {"accepted": false, "reason": &"ember_surface_request_not_pending"}
	if is_instance_valid(ember_surface_loop_host) \
			or is_instance_valid(ember_surface_loop_production_binding):
		var host_phase := ember_surface_loop_host.get_phase() \
			if is_instance_valid(ember_surface_loop_host) else -1
		if host_phase != EmberSurfaceLoopHost.Phase.IDLE:
			return {"accepted": false, "reason": &"ember_surface_journey_already_started"}
	if is_instance_valid(planetary_cruise_binding):
		var cruise_snapshot: Dictionary = planetary_cruise_binding.get_snapshot()
		if bool(cruise_snapshot.get("engagement_requested", false)):
			var disengaged: Dictionary = planetary_cruise_binding.request_disengage(
				planetary_cruise_binding.get_generation(), true
			)
			if not bool(disengaged.get("accepted", false)):
				return disengaged
		else:
			var final_snapshot := cruise_snapshot.get("final_approach", {}) as Dictionary
			var completion := final_snapshot.get("completion_receipt", {}) as Dictionary
			if not completion.is_empty():
				var discarded := planetary_cruise_binding.discard_final_approach_completion(
					int(completion.get("target_generation", 0)),
					planetary_cruise_binding.get_generation(),
					&"ember_surface_journey_cancelled",
				)
				if not bool(discarded.get("accepted", false)):
					return discarded
	_pending_ember_surface_request.clear()
	_pending_ember_surface_host = null
	_pending_ember_surface_director = null
	_pending_ember_surface_reward_sink = Callable()
	_pending_ember_surface_serial = 0
	_ember_final_approach_handoff_ready = false
	_ember_final_approach_completion_receipt.clear()
	_ember_surface_journey_active = false
	return {"accepted": true, "reason": &"ember_surface_request_cancelled"}


func _forward_pending_ember_surface_journey() -> Dictionary:
	if _pending_ember_surface_request.is_empty():
		return {"accepted": false, "reason": &"ember_surface_request_not_pending"}
	if not is_instance_valid(_pending_ember_surface_host) \
			or not is_instance_valid(_pending_ember_surface_director) \
			or not _pending_ember_surface_reward_sink.is_valid():
		cancel_ember_surface_journey()
		return {"accepted": false, "reason": &"ember_surface_request_stale"}
	var host := _pending_ember_surface_host
	var director := _pending_ember_surface_director
	var reward_sink := _pending_ember_surface_reward_sink
	var caller_serial := _pending_ember_surface_serial
	var retained_request := _pending_ember_surface_request.duplicate(true)
	# This is an internal handoff, not a caller cancellation. Clearing through
	# cancel_ember_surface_journey() disengages the cruise binding immediately
	# before begin_ember_surface_journey() tries to admit the ready surface
	# composition, losing the retained request if that admission rejects.
	_pending_ember_surface_request.clear()
	_pending_ember_surface_host = null
	_pending_ember_surface_director = null
	_pending_ember_surface_reward_sink = Callable()
	_pending_ember_surface_serial = 0
	var forwarded := begin_ember_surface_journey(
		host, director, reward_sink, caller_serial
	)
	if not bool(forwarded.get("accepted", false)):
		_pending_ember_surface_request = retained_request
		_pending_ember_surface_host = host
		_pending_ember_surface_director = director
		_pending_ember_surface_reward_sink = reward_sink
		_pending_ember_surface_serial = caller_serial
	return forwarded


## Consumes the detached Ember return receipt at the normal GameFlow boundary.
## The berth remains the sole occupancy authority: this method never reserves,
## occupies, moves, or teleports a craft.  The optional arguments are an
## explicit test/production handoff; normal Main callers may omit them and use
## the currently piloted craft, player, and registered world berth.
func consume_planetary_return_receipt(
		receipt: Variant, planetary_binding: Object = null,
		return_berth: ShipBerth = null, return_craft: Node = null,
		return_actor: Node = null, travel_session: Object = null,
		return_contract: Object = null
	) -> Dictionary:
	if _planetary_return_receipt_consumed:
		return {"accepted": false, "reason": &"planetary_return_receipt_replayed"}
	if phase != Phase.RETURN_TO_YARD:
		return {"accepted": false, "reason": &"planetary_return_phase_mismatch"}
	if not receipt is Dictionary:
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var returned := receipt as Dictionary
	if planetary_binding == null:
		planetary_binding = ember_surface_loop_production_binding
	if not bool(returned.get("accepted", false)) \
			or StringName(returned.get("reason", &"")) != &"returned_to_station":
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var berth_receipt := returned.get("berth_receipt", {}) as Dictionary
	var contract_receipt := returned.get("contract_receipt", {}) as Dictionary
	if not bool(berth_receipt.get("accepted", false)) \
			or StringName(berth_receipt.get("reason", &"")) != &"return_berth_occupied" \
			or not bool(contract_receipt.get("accepted", false)):
		return {"accepted": false, "reason": &"planetary_return_receipt_invalid"}
	var craft: Node = return_craft if return_craft != null else active_ship
	var actor: Node = return_actor if return_actor != null else player
	if craft == null or actor == null or not is_instance_valid(craft) \
			or not is_instance_valid(actor):
		return {"accepted": false, "reason": &"planetary_return_actor_unavailable"}
	var craft_id := int(berth_receipt.get("craft_instance_id", 0))
	var actor_id := int(berth_receipt.get("actor_instance_id", 0))
	if craft_id < 1 or actor_id < 1 \
			or craft.get_instance_id() != craft_id \
			or actor.get_instance_id() != actor_id:
		return {"accepted": false, "reason": &"planetary_return_actor_mismatch"}
	var session_generation := int(berth_receipt.get("session_generation", 0))
	var attachment_generation := int(berth_receipt.get("attachment_generation", 0))
	if session_generation < 1 or attachment_generation < 1:
		return {"accepted": false, "reason": &"planetary_return_generation_invalid"}
	if planetary_binding != null:
		if planetary_binding.has_method(&"get_generation") \
				and int(planetary_binding.call(&"get_generation")) != session_generation:
			return {"accepted": false, "reason": &"planetary_return_stale_generation"}
		if planetary_binding.has_method(&"get_planetary_surface_snapshot"):
			var surface_snapshot := planetary_binding.call(&"get_planetary_surface_snapshot") as Dictionary
			var current_attachment := int(surface_snapshot.get("attachment_generation", attachment_generation))
			if current_attachment != attachment_generation:
				return {"accepted": false, "reason": &"planetary_return_stale_attachment"}
	if craft.has_method(&"is_piloted") and not bool(craft.call(&"is_piloted")):
		return {"accepted": false, "reason": &"planetary_return_craft_not_piloted"}
	var berth := return_berth
	if berth == null and is_instance_valid(world) and world.has_method(&"get_berth_node"):
		berth = world.call(&"get_berth_node", StringName(berth_receipt.get("berth_id", &""))) as ShipBerth
	if berth == null or not is_instance_valid(berth) \
			or not berth.is_occupied() \
			or berth.get_occupant() != craft:
		return {"accepted": false, "reason": &"planetary_return_berth_not_occupied"}
	var ship_id := StringName(craft.call(&"get_ship_id")) if craft.has_method(&"get_ship_id") else &""
	var token := StringName(berth_receipt.get("token", &""))
	if ship_id.is_empty() or token.is_empty() \
			or not berth.has_valid_lease(craft, token, ship_id):
		return {"accepted": false, "reason": &"planetary_return_berth_lease_invalid"}
	if planetary_binding != null and planetary_binding.has_method(&"detach_planetary_surface"):
		if travel_session != null and return_contract != null \
				and planetary_binding.has_method(&"save_planetary_return_persistence") \
				and _runtime_settings_user_data_store != null:
			var commit_id := "planetary-return-%d-%d" % [actor_id, craft_id]
			var saved: Dictionary = planetary_binding.call(
				&"save_planetary_return_persistence", travel_session, return_contract,
				receipt, _runtime_settings_user_data_store.get_generation(), commit_id
			)
			if not bool(saved.get("accepted", false)):
				return {"accepted": false, "reason": &"planetary_return_persistence_commit_rejected", "store": saved}
		var detached := planetary_binding.call(&"detach_planetary_surface") as Dictionary
		if not bool(detached.get("accepted", false)):
			return {"accepted": false, "reason": &"planetary_return_attachment_detach_rejected"}
	_planetary_return_receipt_consumed = true
	_landing_request_active = false
	_active_landing_berth_id = &""
	_return_registered = true
	phase = Phase.SHUT_DOWN
	if is_instance_valid(hud):
		publish_first_sortie_tutorial_phase(&"exit", _first_sortie_tutorial_generation)
		hud.set_objective("Hold controls neutral, then exit %s" % craft.name)
		hud.toast("Return complete", "Authoritative Mudds Shipyards berth occupied — propulsion will idle offline")
	return {"accepted": true, "reason": &"planetary_return_consumed", "phase": Phase.SHUT_DOWN, "berth_id": berth.get_berth_id(), "craft_instance_id": craft_id, "actor_instance_id": actor_id}


func _on_landing_aborted(reason: StringName, source_ship: HeroShip = null) -> void:
	if _network_session_mode == &"client":
		return
	if source_ship != null and source_ship != active_ship:
		return
	var network_abort := _abort_network_landing_handoff(
		source_ship if source_ship != null else active_ship
	)
	_last_network_landing_handoff_result = network_abort.duplicate(true)
	if not bool(network_abort.get("accepted", false)):
		if is_instance_valid(hud):
			hud.set_interaction("", false)
			hud.set_objective(
				"Landing abort coordination interrupted — berth retained; retry pending"
			)
			hud.toast(
				"Landing abort retry pending",
				"The physical reservation remains held until the server publishes flying",
				3.5,
			)
		return
	if _planetary_return_physical_arrival_armed:
		_abort_planetary_return_physical_arrival(reason)
	if not _landing_request_active or _active_landing_berth_id.is_empty():
		return
	_landing_request_active = false
	_active_landing_berth_id = &""
	_release_ship_berth(active_ship)
	if phase == Phase.RETURN_TO_YARD:
		hud.set_objective("Re-align with the illuminated pad and retry the guided return")
	elif phase == Phase.FREE_FLIGHT:
		hud.set_objective("Free flight — re-align with a compatible registered berth to retry landing", "SANDBOX SORTIE")
	else:
		return
	var readable_reason := str(reason).replace("_", " ").capitalize()
	hud.set_interaction("", false)
	hud.toast("Landing assist aborted", "%s — berth reservation released" % readable_reason, 3.2)


func _restart_shift() -> void:
	get_tree().reload_current_scene()


func _begin_return_to_yard() -> void:
	# Opponent destruction can be reported more than once by overlapping combat
	# and presentation lifecycles. The first valid guided victory owns this state
	# transition; duplicates must not restart the phase or replace its toast.
	if (
		_guided_activity_complete
		or _guided_return_ready_for_completion
		or active_ship != ship
		or phase != Phase.INTERCEPTOR_ENGAGEMENT
	):
		return
	_guided_return_ready_for_completion = true
	phase = Phase.RETURN_TO_YARD
	publish_first_sortie_tutorial_phase(&"return_land", _first_sortie_tutorial_generation)
	hud.set_enemy_status("", 0.0, 1.0, false)
	hud.set_objective("Return to the regeneration deck and land on the illuminated pad")
	hud.toast("Interceptor destroyed", "Debris field clear — return vector and landing assist available")


func _begin_interceptor_engagement() -> void:
	if (
		_opponent_spawned
		or active_ship != ship
		or _guided_activity_complete
		or _guided_return_ready_for_completion
	):
		return
	# A reused defender generation cannot inherit any visual still crossing the
	# shared pool from its predecessor. Retire those records before advancing the
	# source fence; damage for each shot was already resolved at dispatch time.
	for shot_id_variant: Variant in _player_pulse_network_active_shots.keys():
		var live_record := _player_pulse_network_active_shots.get(shot_id_variant, {}) as Dictionary
		if StringName(live_record.get("source_entity_id", &"")) == RANGE_OPPONENT_NETWORK_ID:
			_terminalize_player_pulse_network_shot(int(shot_id_variant), &"abort")
	if _opponent_pulse_network_generation < NETWORK_MAX_SAFE_GENERATION:
		_opponent_pulse_network_generation += 1
	_opponent_spawned = true
	phase = Phase.INTERCEPTOR_ENGAGEMENT
	var spawn_direction := (active_ship.global_position - ENEMY_SPAWN).normalized()
	var spawn_up := Vector3.FORWARD if absf(spawn_direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var spawn_basis := Basis.looking_at(spawn_direction, spawn_up)
	opponent.activate(Transform3D(spawn_basis, ENEMY_SPAWN))
	opponent.set_target(active_ship)
	hud.set_enemy_status(
		"Mudds range defence interceptor",
		opponent.get_health(),
		float(opponent.get("maximum_health")),
		true
	)
	hud.set_objective("Dogfight the live range-defence interceptor")
	hud.toast("Live contact launched", "Break, pursue, and destroy the opposing spacecraft", 4.0)
	audio.play_combat_alert()


func _on_opponent_health_changed(current: float, maximum: float) -> void:
	hud.set_enemy_status("Mudds range defence interceptor", current, maximum, opponent.is_active())


func _on_opponent_destroyed(position: Vector3) -> void:
	if phase != Phase.INTERCEPTOR_ENGAGEMENT:
		return
	hud.set_enemy_status("", 0.0, 1.0, false)
	if opponent.get_pending_damage_presentation_count() == 0:
		combat_audio.play_explosion(position, opponent.get_instance_id())
	_begin_return_to_yard()


## Deliberately holds no coordinator gate. The defender's own fire latch is the
## gate, and it is stricter than any snapshot this handler could read: the signal
## is raised from `RangeOpponent._fire_at_target()`, which refuses unless
## `_active` is true, and `_active` is owned end to end by the encounter
## lifecycle. `opponent.activate()` is reached from exactly one place,
## `_begin_interceptor_engagement()`, immediately after it sets
## `Phase.INTERCEPTOR_ENGAGEMENT`; and the engagement has exactly two exits,
## both of which clear `_active` synchronously inside the same call that ends the
## phase — `_destroy_interceptor()` for the defender, `_recover_from_destroyed_ship()`
## for the pilot. Re-deriving `phase` here would be strictly weaker, because
## `phase` is idle-written and this handler runs in the defender's physics pass.
## `tests/combat_encounter_authority_gate_test.gd` locks that coupling.
func _on_opponent_projectile_fired(origin: Vector3, direction: Vector3) -> void:
	if _network_session_mode == &"client":
		_last_opponent_shot_result = {
			"accepted": false,
			"resolved": false,
			"reason": &"client_projectile_authority_forbidden",
		}
		return
	var ray_end := origin + direction.normalized() * ENEMY_WEAPON_RANGE
	var result: Dictionary = combat_authority.submit_hitscan_with_deferred_presentation(
		opponent,
		OPPONENT_WEAPON_ID,
		origin,
		direction
	)
	_last_opponent_shot_result = result.duplicate(true)
	var hit_position: Vector3 = result.get("position", ray_end) if bool(result.get("hit", false)) else ray_end
	if (
		bool(result.get("damaged", false))
		and result.get("target_entity") == active_ship
		and opponent.is_active()
	):
		var applied_damage := float(result.get("applied_damage", ENEMY_HIT_DAMAGE))
		var local_source := active_ship.global_basis.inverse() * (origin - active_ship.global_position)
		hud.flash_damage(applied_damage / 20.0, Vector2(local_source.x, local_source.z))


func _on_station_defense_network_snapshot_changed(snapshot: Dictionary) -> void:
	if (
		_network_session_mode != &"server"
		or not is_instance_valid(network_session)
		or not network_session.is_server()
	):
		return
	var host := snapshot.get("host", {}) as Dictionary
	var activity := host.get("activity", {}) as Dictionary
	if StringName(activity.get("state_id", &"idle")) == &"active":
		return
	# The encounter has withdrawn every hostile's dispatch authority. Any visual
	# still crossing the bounded pulse pool is now an abort tombstone; its damage
	# result, if any, was already final before this presentation transition.
	for shot_id_variant: Variant in _player_pulse_network_active_shots.keys():
		var record := _player_pulse_network_active_shots.get(shot_id_variant, {}) as Dictionary
		if String(record.get("source_entity_id", &"")).begins_with(
			STATION_DEFENSE_NETWORK_PREFIX
		):
			_terminalize_player_pulse_network_shot(int(shot_id_variant), &"abort")


func _publish_network_damage_state(
	ship_to_publish: HeroShip,
	health: float,
	destroyed: bool = false,
) -> Dictionary:
	if (
		not is_instance_valid(network_session)
		or not network_session.is_server()
		or not is_instance_valid(ship_to_publish)
	):
		return {"accepted": false, "status": &"network_publish_unavailable"}
	var entity_id := ship_to_publish.get_ship_id()
	var component := ship_to_publish.get_component_damage()
	var component_generation := component.get_ledger_generation() if component != null else 1
	var entity_generation := int(_network_damage_entities.get(entity_id, 0))
	if entity_generation <= 0:
		entity_generation = 1
		var registered := network_session.register_damage_entity(
			1, entity_id, entity_generation, component_generation
		)
		if not bool(registered.get("accepted", false)) and registered.get("status") != &"duplicate_entity":
			return registered
		_network_damage_entities[entity_id] = entity_generation
	var telemetry := ship_to_publish.get_telemetry()
	var state: StringName = &"destroyed" if destroyed or bool(telemetry.get("destroyed", false)) else &"active"
	_network_damage_server_tick += 1
	return network_session.publish_damage_respawn_snapshot(
		entity_id, entity_generation, maxf(0.0, health), state, destroyed,
		entity_generation if destroyed else 0, [], _network_damage_server_tick
	)


## Publishes only presentation state already emitted by Halyard's server-owned
## RepairAuthority. The ship receipt remains the mutation proof; this path
## merely attaches its bounded lifecycle to the existing canonical damage row.
func _on_engineer_repair_state_changed(
	repair_state: Dictionary,
	source_ship: HeroShip
) -> void:
	if _network_session_mode != &"server" \
			or not is_instance_valid(network_session) \
			or not network_session.is_server() \
			or not is_instance_valid(source_ship) \
			or not source_ship.has_signal(&"engineer_repair_state_changed"):
		return
	var local_state := StringName(repair_state.get("status", &""))
	var progress := clampf(float(repair_state.get("progress", 0.0)), 0.0, 1.0)
	var network_state: StringName = &""
	match local_state:
		&"repairing":
			network_state = &"started" if progress <= 0.0 else &"progress"
		&"completed":
			network_state = &"completed"
		&"interrupted":
			network_state = &"aborted"
		_:
			return
	var component_generation := int(repair_state.get("component_generation", 0))
	var component_id := StringName(repair_state.get("component_id", &""))
	if component_generation <= 0 or component_id.is_empty():
		return
	var entity_id := source_ship.get_ship_id()
	var entity_generation := int(_network_damage_entities.get(entity_id, 0))
	if entity_generation <= 0:
		var telemetry := source_ship.get_telemetry()
		var damage_published := _publish_network_damage_state(
			source_ship,
			float(telemetry.get("hull", 0.0)),
			bool(telemetry.get("destroyed", false))
		)
		if not bool(damage_published.get("accepted", false)):
			return
		entity_generation = int(_network_damage_entities.get(entity_id, 0))
	var owner := _network_engineer_repair_owner(source_ship, repair_state)
	if owner.is_empty():
		return
	_network_damage_server_tick += 1
	network_session.publish_repair_lifecycle_snapshot(
		entity_id,
		entity_generation,
		{
			"state": network_state,
			"component_id": component_id,
			"component_generation": component_generation,
			"progress": progress,
			"token": int(repair_state.get("token", -1)),
			"receipt": (repair_state.get("receipt", {}) as Dictionary).duplicate(true),
			"owner_peer_id": int(owner.get("occupant_peer_id", 0)),
			"avatar_id": StringName(owner.get("avatar_id", &"")),
			"seat_id": StringName(owner.get("seat_id", &"")),
			"seat_generation": int(owner.get("seat_generation", 0)),
		},
		_network_damage_server_tick
	)


func _network_engineer_repair_owner(
	source_ship: HeroShip,
	repair_state: Dictionary
) -> Dictionary:
	# Halyard, Jovian and Bulwark expose the same detached authority view. Match
	# it back to the synchronous signal payload so a stale or reordered callback
	# cannot borrow a newer engineer assignment.
	if source_ship.has_method(&"get_engineer_repair_network_snapshot"):
		var network_snapshot := source_ship.call(
			&"get_engineer_repair_network_snapshot"
		) as Dictionary
		var current := network_snapshot.get("repair", {}) as Dictionary
		if StringName(current.get("status", &"")) \
				!= StringName(repair_state.get("status", &"")) \
				or StringName(current.get("component_id", &"")) \
				!= StringName(repair_state.get("component_id", &"")) \
				or int(current.get("component_generation", 0)) \
				!= int(repair_state.get("component_generation", 0)) \
				or not is_equal_approx(
					float(current.get("progress", 0.0)),
					float(repair_state.get("progress", 0.0))
				):
			return {}
		return (network_snapshot.get("owner", {}) as Dictionary).duplicate(true)
	# Compatibility for the original focused Halyard harness. Production craft
	# use the shared snapshot above; this read-only fallback can be retired with
	# that older synthetic fixture.
	if not source_ship.has_method(&"get_crew_role_gameplay_snapshot"):
		return {}
	var crew := source_ship.call(&"get_crew_role_gameplay_snapshot") as Dictionary
	var selected := (
		(crew.get("selected_targets", {}) as Dictionary).get("engineer", {}) as Dictionary
	)
	var selected_peer_id := int(selected.get("occupant_peer_id", 0))
	var selected_avatar_id := StringName(selected.get("avatar_id", &""))
	if selected_peer_id <= 0 \
			or StringName(selected.get("component_id", &"")) \
			!= StringName(repair_state.get("component_id", &"")):
		return {}
	for occupant_variant in crew.get("occupants", []) as Array:
		var occupant := occupant_variant as Dictionary
		if StringName(occupant.get("role", &"")) == &"engineer" \
				and int(occupant.get("occupant_peer_id", 0)) == selected_peer_id \
				and StringName(occupant.get("avatar_id", &"")) == selected_avatar_id:
			return occupant.duplicate(true)
	return {}


func _on_ship_hull_changed(current: float, _maximum: float, source_ship: HeroShip = null) -> void:
	if source_ship != null and source_ship != active_ship:
		_publish_network_damage_state(source_ship, current)
		return
	_publish_network_damage_state(source_ship if source_ship != null else active_ship, current)
	if current <= 0.0:
		hud.set_enemy_status("", 0.0, 1.0, false)


func _on_ship_damage_stage_changed(stage: int, status: StringName, source_ship: HeroShip = null) -> void:
	if not _piloting or stage <= 0 or (source_ship != null and source_ship != active_ship):
		return
	if status == &"critical":
		hud.toast("Critical engine damage", "Thrust is unstable — disengage or finish the contact", 3.4)
		audio.play_combat_alert()
	elif status == &"damaged":
		hud.toast("Hull damage detected", "Warning systems and damage control are active", 2.4)


func _on_camera_view_changed(view: StringName, source_ship: HeroShip = null) -> void:
	if not _piloting or (source_ship != null and source_ship != active_ship):
		return
	if is_instance_valid(_ember_surface_loop_audio_composition) \
			and bool((_ember_surface_loop_audio_composition.call(
				&"get_snapshot"
			) as Dictionary).get("attached", false)):
		_ember_surface_loop_audio_composition.call(
			&"set_perspective", &"interior" if view == &"COCKPIT" else &"exterior"
		)
	if view == &"COCKPIT":
		hud.toast("Cockpit view", "Physical pilot-eye camera active", 1.4)
	else:
		hud.toast("Chase view", "Mouse wheel adjusts camera distance", 1.4)


func _register_flyable_ships() -> void:
	ships.clear()
	var seen_ship_ids: Dictionary = {}
	var seen_home_berths: Dictionary = {}
	var registration_candidates: Array[HeroShip] = []
	for child in get_children():
		if child is HeroShip:
			registration_candidates.append(child as HeroShip)
	# ShipyardWorld owns the production composition, so the three authored
	# expansion craft are deliberately discovered through its typed binding
	# query instead of making GameFlow depend on that binding's scene layout.
	var expansion_binding: Node = null
	if is_instance_valid(world) and world.has_method(&"get_fleet_expansion_production_binding"):
		expansion_binding = world.call(&"get_fleet_expansion_production_binding") as Node
	if is_instance_valid(expansion_binding) and expansion_binding.has_method(&"get_fleet_snapshot"):
		var pending_snapshot := expansion_binding.call(&"get_fleet_snapshot") as Dictionary
		if not bool(pending_snapshot.get("built", false)) and not _production_registry_refresh_queued:
			_production_registry_refresh_queued = true
			call_deferred(&"_refresh_production_flyable_registry")
	if is_instance_valid(expansion_binding) and expansion_binding.has_method(&"get_fleet_snapshot"):
		var fleet_snapshot := expansion_binding.call(&"get_fleet_snapshot") as Dictionary
		for row_variant: Variant in fleet_snapshot.get("craft", []) as Array:
			var row := row_variant as Dictionary
			var craft_id := StringName(row.get("craft_id", &""))
			if craft_id.is_empty() or not bool(row.get("attached", false)):
				continue
			var nested := expansion_binding.get_node_or_null(NodePath(String(craft_id))) as HeroShip
			if is_instance_valid(nested) and not registration_candidates.has(nested):
				registration_candidates.append(nested)
	for candidate in registration_candidates:
		var production_contract := _get_expansion_flyable_contract(candidate, expansion_binding)
		var is_production_candidate := bool(production_contract.get("accepted", false))
		var definition := candidate.get_ship_definition()
		var ship_audio_rig := candidate.get_ship_audio_rig()
		var candidate_id := candidate.get_ship_id()
		var berth_id := candidate.get_home_berth_id()
		if is_production_candidate:
			# Expansion pads are owned by FleetExpansionBerths, not ShipBerth.
			# Keep the GameFlow identity/uniqueness contract while retaining that
			# binding's attachment and reservation authority.
			berth_id = StringName(production_contract.get("pad_id", &""))
			candidate.home_berth_id = berth_id
		var invalid_reason := ""
		if not is_production_candidate and (definition == null or not definition.is_definition_valid()):
			invalid_reason = "missing or invalid ShipDefinition"
		elif ship_audio_rig == null \
				or not bool(ship_audio_rig.get_audit_report().get("valid", false)) \
				or (definition != null and ship_audio_rig.get_profile_id() != definition.audio_profile_id):
			invalid_reason = "missing, invalid, or mismatched ship-local audio profile"
		elif candidate_id.is_empty() or seen_ship_ids.has(candidate_id):
			invalid_reason = "empty or duplicate ship ID %s" % candidate_id
		elif berth_id.is_empty() or seen_home_berths.has(berth_id):
			invalid_reason = "empty or duplicate home berth ID %s" % berth_id
		elif not is_production_candidate and (not world.has_method("has_berth") or not bool(world.call("has_berth", berth_id))):
			invalid_reason = "unregistered home berth %s" % berth_id
		if not invalid_reason.is_empty():
			_disable_invalid_fleet_candidate(candidate)
			push_error("Flyable ship %s rejected: %s" % [candidate.name, invalid_reason])
			continue
		seen_ship_ids[candidate_id] = candidate
		seen_home_berths[berth_id] = candidate
		if not is_production_candidate and not _reserve_berth_for_ship(candidate, berth_id, true):
			_disable_invalid_fleet_candidate(candidate)
			push_error("Flyable ship %s could not occupy home berth %s" % [candidate.name, berth_id])
			continue
		var berth_transform := (
			Transform3D(candidate.global_basis, production_contract.get("landing_anchor", candidate.global_position))
			if is_production_candidate
			else world.call("get_berth_transform", berth_id) as Transform3D
		)
		candidate.global_transform = berth_transform
		candidate.set_piloted(false)
		ships.append(candidate)
		candidate.add_to_group("flyable_ships")
		_connect_flyable_ship_signals(candidate)
	ships.sort_custom(func(first: HeroShip, second: HeroShip) -> bool:
		return str(first.get_ship_id()) < str(second.get_ship_id())
	)
	if not ships.has(ship):
		push_error("The guided Torrent craft was rejected from the physical fleet registry")
	if _initialized:
		_sync_fleet_ship_semantic_audio()


func _refresh_production_flyable_registry() -> void:
	_production_registry_refresh_queued = false
	var expansion_binding: Node = (
		world.call(&"get_fleet_expansion_production_binding") as Node
		if is_instance_valid(world) and world.has_method(&"get_fleet_expansion_production_binding")
		else null
	)
	for _attempt in 120:
		if is_instance_valid(expansion_binding) and expansion_binding.has_method(&"get_fleet_snapshot"):
			var snapshot := expansion_binding.call(&"get_fleet_snapshot") as Dictionary
			if bool(snapshot.get("built", false)):
				_register_flyable_ships()
				_initialize_live_combat()
				return
		await get_tree().process_frame
	_register_flyable_ships()
	_initialize_live_combat()


func _sync_fleet_ship_semantic_audio() -> Dictionary:
	if not is_instance_valid(audio) \
			or not audio.has_method(&"bind_semantic_audio_source") \
			or not audio.has_method(&"unbind_semantic_audio_source"):
		return _fleet_ship_semantic_audio_report(&"audio_director_unavailable")
	var desired: Dictionary = {}
	for fleet_ship: HeroShip in ships:
		if not is_instance_valid(fleet_ship):
			continue
		var rig := fleet_ship.get_ship_audio_rig()
		if rig == null or not is_instance_valid(rig):
			continue
		desired[rig.get_instance_id()] = {
			"rig": rig,
			"ship_id": fleet_ship.get_ship_id(),
		}
	for source_id: int in _fleet_ship_semantic_audio_sources.keys():
		if desired.has(source_id):
			continue
		var prior := (_fleet_ship_semantic_audio_sources[source_id] as Dictionary).get("rig") as Node
		if is_instance_valid(prior):
			audio.call(&"unbind_semantic_audio_source", prior, &"ship")
		_fleet_ship_semantic_audio_sources.erase(source_id)
	for source_id: int in desired.keys():
		if _fleet_ship_semantic_audio_sources.has(source_id):
			continue
		var row := desired[source_id] as Dictionary
		var result := audio.call(
			&"bind_semantic_audio_source", row.rig as Node, &"ship"
		) as Dictionary
		if bool(result.get("accepted", false)):
			_fleet_ship_semantic_audio_sources[source_id] = row
	return _fleet_ship_semantic_audio_report(&"fleet_sources_synchronized")


func _detach_fleet_ship_semantic_audio() -> Dictionary:
	if is_instance_valid(audio) and audio.has_method(&"unbind_semantic_audio_source"):
		for row_variant: Variant in _fleet_ship_semantic_audio_sources.values():
			var rig := (row_variant as Dictionary).get("rig") as Node
			if is_instance_valid(rig):
				audio.call(&"unbind_semantic_audio_source", rig, &"ship")
	_fleet_ship_semantic_audio_sources.clear()
	return _fleet_ship_semantic_audio_report(&"fleet_sources_detached")


func get_fleet_ship_semantic_audio_report() -> Dictionary:
	return _fleet_ship_semantic_audio_report(&"snapshot")


func _fleet_ship_semantic_audio_report(reason: StringName) -> Dictionary:
	var bound_ship_ids: Array[StringName] = []
	var active_bound := false
	for row_variant: Variant in _fleet_ship_semantic_audio_sources.values():
		var row := row_variant as Dictionary
		bound_ship_ids.append(StringName(row.get("ship_id", &"")))
		var rig := row.get("rig") as Node
		active_bound = active_bound or (
			is_instance_valid(active_ship)
			and is_instance_valid(rig)
			and active_ship.get_ship_audio_rig() == rig
		)
	bound_ship_ids.sort()
	return {
		"reason": reason,
		"registered_ship_count": ships.size(),
		"bound_source_count": _fleet_ship_semantic_audio_sources.size(),
		"bound_ship_ids": bound_ship_ids,
		"all_registered_ships_bound": (
			ships.size() == _fleet_ship_semantic_audio_sources.size()
		),
		"active_ship_bound": active_bound,
		"source_kind": &"ship",
		"presentation_only": true,
		"gameplay_authority": false,
	}.duplicate(true)


func _get_expansion_flyable_contract(candidate: HeroShip, binding: Node) -> Dictionary:
	if not is_instance_valid(candidate) or not is_instance_valid(binding):
		return {}
	if not binding.has_method(&"get_fleet_snapshot") or not binding.has_method(&"get_craft_compatibility_contract"):
		return {}
	var snapshot := binding.call(&"get_fleet_snapshot") as Dictionary
	for row_variant: Variant in snapshot.get("craft", []) as Array:
		var row := row_variant as Dictionary
		var craft_id := StringName(row.get("craft_id", &""))
		if binding.get_node_or_null(NodePath(String(craft_id))) != candidate:
			continue
		var contract := binding.call(&"get_craft_compatibility_contract", craft_id) as Dictionary
		if bool(contract.get("accepted", false)) and bool(contract.get("valid", false)):
			contract["attached"] = bool(row.get("attached", false))
			return contract if bool(contract.get("attached", false)) else {}
	return {}


func _disable_invalid_fleet_candidate(candidate: HeroShip) -> void:
	if not is_instance_valid(candidate):
		return
	candidate.visible = false
	candidate.collision_layer = 0
	candidate.collision_mask = 0
	var ship_audio_rig := candidate.get_ship_audio_rig()
	if ship_audio_rig != null:
		ship_audio_rig.release_audio_resources()
	candidate.process_mode = Node.PROCESS_MODE_DISABLED


func _initialize_live_combat() -> void:
	if not is_instance_valid(combat_authority):
		push_error("Main scene is missing its live combat authority")
		return
	var source_owners: Dictionary = {}
	var expected_player_sources := 0
	for fleet_ship in ships:
		var source_id := int(PLAYER_SOURCE_IDS.get(fleet_ship.get_ship_id(), 0))
		if source_id <= 0:
			# Production expansion craft are flyable/boardable HeroShips, but
			# explicitly do not own combat authority until their combat contract is
			# authored. Keep them in switching while leaving live combat fail-closed.
			continue
		expected_player_sources += 1
		if source_owners.has(source_id):
			push_error(
				"Combat source ID %d is duplicated by %s and %s"
				% [source_id, (source_owners[source_id] as HeroShip).name, fleet_ship.name]
			)
			continue
		source_owners[source_id] = fleet_ship
		combat_authority.attach_lifecycle_damageable(
			fleet_ship,
			LifecycleDamageableAdapterType.LifecycleKind.HERO_SHIP,
			PLAYER_FACTION
		)
		var player_profiles := _get_player_weapon_profiles(fleet_ship)
		if (
			not _combat_registration_matches(
				fleet_ship, source_id, PLAYER_FACTION, player_profiles
			)
			and not combat_authority.register_source(
				fleet_ship,
				source_id,
				PLAYER_FACTION,
				player_profiles
			)
		):
			push_error("Failed to register combat source for %s" % fleet_ship.get_display_name())
	combat_authority.attach_lifecycle_damageable(
		opponent,
		LifecycleDamageableAdapterType.LifecycleKind.RANGE_OPPONENT,
		OPPONENT_FACTION
	)
	if (
		not _combat_registration_matches(
			opponent, OPPONENT_SOURCE_ID, OPPONENT_FACTION, OPPONENT_WEAPON_PROFILES
		)
		and not combat_authority.register_source(
			opponent,
			OPPONENT_SOURCE_ID,
			OPPONENT_FACTION,
			OPPONENT_WEAPON_PROFILES
		)
	):
		push_error("Failed to register the range-defence combat source")
	var adapted_target_count: int = combat_authority.attach_range_targets(world)
	var expected_target_count := int(world.call("get_target_count"))
	if adapted_target_count != expected_target_count and expected_target_count > 0:
		push_warning(
			"Combat authority adapted %d of %d range targets"
			% [adapted_target_count, expected_target_count]
		)
	var resolver := combat_authority.get_resolver()
	var roster_audit := get_live_combat_source_roster_audit()
	var expected_source_count := int(
		roster_audit.get("expected_source_count", expected_player_sources + 1)
	)
	if not bool(roster_audit.get("valid", false)):
		push_error(
			"Live combat source roster is invalid: %s"
			% "; ".join(roster_audit.get("errors", PackedStringArray()))
		)
	elif resolver == null or resolver.get_registered_source_count() != expected_source_count:
		push_error(
			"Live combat authority owns %d of %d exact source registrations"
			% [
				resolver.get_registered_source_count() if resolver != null else 0,
				expected_source_count,
			]
		)


## Detached exact census of every source this production composition is allowed
## to own. Fleet and range-opponent identities remain GameFlow-owned; the
## station-defense content proves its private three-source roster through its
## bounded contract. Exact total equality rejects arbitrary additional sources.
func get_live_combat_source_roster_audit() -> Dictionary:
	var errors := PackedStringArray()
	var player_rows: Array[Dictionary] = []
	var seen_source_ids: Dictionary = {}
	for fleet_ship in ships:
		var source_id := int(PLAYER_SOURCE_IDS.get(fleet_ship.get_ship_id(), 0))
		if source_id <= 0:
			continue
		var profiles := _get_player_weapon_profiles(fleet_ship)
		var exact := _combat_registration_matches(
			fleet_ship, source_id, PLAYER_FACTION, profiles
		)
		if seen_source_ids.has(source_id):
			errors.append("duplicate expected player source ID: %d" % source_id)
		seen_source_ids[source_id] = true
		if not exact:
			errors.append(
				"player combat source registration is not exact: %s"
				% fleet_ship.get_ship_id()
			)
		player_rows.append({
			"ship_id": fleet_ship.get_ship_id(),
			"entity_instance_id": fleet_ship.get_instance_id(),
			"source_id": source_id,
			"faction_id": PLAYER_FACTION,
			"weapon_ids": profiles.keys(),
			"exact": exact,
		})
	var opponent_exact := _combat_registration_matches(
		opponent, OPPONENT_SOURCE_ID, OPPONENT_FACTION, OPPONENT_WEAPON_PROFILES
	)
	if not opponent_exact:
		errors.append("range-opponent combat source registration is not exact")
	if seen_source_ids.has(OPPONENT_SOURCE_ID):
		errors.append("range-opponent source ID collides with a player source")
	seen_source_ids[OPPONENT_SOURCE_ID] = true

	var encounter_present := false
	var encounter_ready := false
	var encounter_contract: Dictionary = {}
	if is_instance_valid(world) and world.has_method(&"get_station_defense_content"):
		var encounter_content := world.call(&"get_station_defense_content") as Node
		encounter_present = is_instance_valid(encounter_content)
		encounter_ready = encounter_present \
			and bool(encounter_content.call(&"is_content_ready"))
		if encounter_ready:
			encounter_contract = encounter_content.call(
				&"get_live_source_registration_contract"
			) as Dictionary
			if int(encounter_contract.get("authority_instance_id", 0)) \
					!= combat_authority.get_instance_id():
				errors.append("station-defense sources use a different combat authority")
			if not bool(encounter_contract.get("valid", false)):
				for error in encounter_contract.get("errors", PackedStringArray()):
					errors.append("station defense: %s" % error)
	var authored_encounter_sources := int(
		encounter_contract.get("expected_source_count", 0)
	) if encounter_ready else 0
	var expected_encounter_sources := int(
		encounter_contract.get("expected_live_source_count", 0)
	) if encounter_ready else 0
	if encounter_ready and authored_encounter_sources != 4:
		errors.append("station-defense source roster must contain exactly four hostiles")
	if encounter_ready and expected_encounter_sources != 3:
		errors.append("station-defense startup roster must contain exactly three live sources")
	var resolver := combat_authority.get_resolver() if is_instance_valid(combat_authority) else null
	var actual_source_count := (
		resolver.get_registered_source_count() if is_instance_valid(resolver) else 0
	)
	var expected_source_count := player_rows.size() + 1 + expected_encounter_sources
	if actual_source_count != expected_source_count:
		errors.append(
			"live source count differs from exact composed roster: %d != %d"
			% [actual_source_count, expected_source_count]
		)
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"authority_instance_id": (
			combat_authority.get_instance_id()
			if is_instance_valid(combat_authority) else 0
		),
		"resolver_instance_id": (
			resolver.get_instance_id() if is_instance_valid(resolver) else 0
		),
		"expected_source_count": expected_source_count,
		"actual_source_count": actual_source_count,
		"expected_player_source_count": player_rows.size(),
		"expected_opponent_source_count": 1,
		"expected_station_defense_source_count": expected_encounter_sources,
		"authored_station_defense_source_count": authored_encounter_sources,
		"player_sources": player_rows,
		"opponent_source": {
			"entity_instance_id": opponent.get_instance_id() if is_instance_valid(opponent) else 0,
			"source_id": OPPONENT_SOURCE_ID,
			"faction_id": OPPONENT_FACTION,
			"weapon_ids": OPPONENT_WEAPON_PROFILES.keys(),
			"exact": opponent_exact,
		},
		"station_defense_present": encounter_present,
		"station_defense_ready": encounter_ready,
		"station_defense_sources": encounter_contract,
	}.duplicate(true)


func _combat_registration_matches(
	source_entity: Node3D,
	source_id: int,
	faction_id: StringName,
	weapon_profiles: Dictionary
	) -> bool:
	if (
		not is_instance_valid(combat_authority)
		or not is_instance_valid(source_entity)
		or combat_authority.get_source_id(source_entity) != source_id
		or combat_authority.get_source_faction(source_entity) != faction_id
	):
		return false
	for untyped_weapon_id: Variant in weapon_profiles:
		var weapon_id := StringName(untyped_weapon_id)
		var expected := weapon_profiles[untyped_weapon_id] as Dictionary
		var registered := combat_authority.get_weapon_profile(source_entity, weapon_id)
		if registered.size() != expected.size():
			return false
		for field: Variant in expected:
			if not registered.has(field):
				return false
			var expected_value: Variant = expected[field]
			var registered_value: Variant = registered[field]
			if expected_value is float or expected_value is int:
				if not is_equal_approx(float(registered_value), float(expected_value)):
					return false
			elif registered_value != expected_value:
				return false
	return true


func _get_player_weapon_profiles(candidate: HeroShip) -> Dictionary:
	var profiles := PLAYER_WEAPON_PROFILES.duplicate(true)
	if not is_instance_valid(candidate):
		return profiles
	if candidate.get_ship_id() == TORRENT_SHIP_ID:
		# There is no legacy base combat entry: malformed or unsupported authored
		# data cannot silently fall back to the value this Resource replaced.
		var migrated_profile := _get_torrent_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[TORRENT_COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == ARROW_SHIP_ID:
		# Arrow has no legacy override after migration. Reject invalid authored data
		# instead of borrowing Torrent's different combat envelope.
		var migrated_profile := _get_arrow_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[ARROW_COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == ZENITH_SHIP_ID:
		# Zenith has no legacy override after migration. Invalid modern weapon data
		# must not borrow another craft's combat envelope.
		var migrated_profile := _get_zenith_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[ZENITH_COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == JOVIAN_SHIP_ID:
		# Jovian has no legacy override after migration. Invalid modern weapon data
		# must not borrow another craft's combat envelope.
		var migrated_profile := _get_jovian_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[JOVIAN_COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == HALYARD_SHIP_ID:
		# Halyard has no legacy override after migration. Invalid modern weapon data
		# must not borrow another craft's combat envelope.
		var migrated_profile := _get_halyard_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[HALYARD_COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == CINDER_BOMBER_SHIP_ID:
		profiles[CINDER_BOMBER_WEAPON_ID] = CINDER_BOMBER_PAYLOAD_PROFILE.duplicate(true)
		return profiles
	return profiles


func _get_player_combat_weapon_id(candidate: HeroShip) -> StringName:
	if not is_instance_valid(candidate):
		return &""
	match candidate.get_ship_id():
		TORRENT_SHIP_ID:
			return TORRENT_COMBAT_WEAPON_ID
		ARROW_SHIP_ID:
			return ARROW_COMBAT_WEAPON_ID
		ZENITH_SHIP_ID:
			return ZENITH_COMBAT_WEAPON_ID
		JOVIAN_SHIP_ID:
			return JOVIAN_COMBAT_WEAPON_ID
		HALYARD_SHIP_ID:
			return HALYARD_COMBAT_WEAPON_ID
		_:
			return &""


func _get_torrent_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		TORRENT_COMBAT_WEAPON_DEFINITION,
		TORRENT_COMBAT_WEAPON_ID,
		TORRENT_COMBAT_ORIGIN_TOLERANCE_METERS,
		TORRENT_COMBAT_PRESENTATION_ID,
		TORRENT_COMBAT_FIRE_AUDIO_ID,
		TORRENT_COMBAT_IMPACT_AUDIO_ID,
		TORRENT_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_arrow_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		ARROW_COMBAT_WEAPON_DEFINITION,
		ARROW_COMBAT_WEAPON_ID,
		ARROW_COMBAT_ORIGIN_TOLERANCE_METERS,
		ARROW_COMBAT_PRESENTATION_ID,
		ARROW_COMBAT_FIRE_AUDIO_ID,
		ARROW_COMBAT_IMPACT_AUDIO_ID,
		ARROW_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_zenith_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		ZENITH_COMBAT_WEAPON_DEFINITION,
		ZENITH_COMBAT_WEAPON_ID,
		ZENITH_COMBAT_ORIGIN_TOLERANCE_METERS,
		ZENITH_COMBAT_PRESENTATION_ID,
		ZENITH_COMBAT_FIRE_AUDIO_ID,
		ZENITH_COMBAT_IMPACT_AUDIO_ID,
		ZENITH_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_jovian_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		JOVIAN_COMBAT_WEAPON_DEFINITION,
		JOVIAN_COMBAT_WEAPON_ID,
		JOVIAN_COMBAT_ORIGIN_TOLERANCE_METERS,
		JOVIAN_COMBAT_PRESENTATION_ID,
		JOVIAN_COMBAT_FIRE_AUDIO_ID,
		JOVIAN_COMBAT_IMPACT_AUDIO_ID,
		JOVIAN_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_halyard_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		HALYARD_COMBAT_WEAPON_DEFINITION,
		HALYARD_COMBAT_WEAPON_ID,
		HALYARD_COMBAT_ORIGIN_TOLERANCE_METERS,
		HALYARD_COMBAT_PRESENTATION_ID,
		HALYARD_COMBAT_FIRE_AUDIO_ID,
		HALYARD_COMBAT_IMPACT_AUDIO_ID,
		HALYARD_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_migrated_player_combat_weapon_profile(
	candidate: HeroShip,
	definition: WeaponDefinition,
	expected_weapon_id: StringName,
	origin_tolerance_meters: float,
	presentation_id: StringName,
	fire_audio_id: StringName,
	impact_audio_id: StringName,
	dry_fire_audio_id: StringName
	) -> Dictionary:
	if (
		not is_instance_valid(candidate)
		or definition == null
		or definition.weapon_id != expected_weapon_id
		or not is_finite(candidate.weapon_cooldown)
		or candidate.weapon_cooldown <= 0.0
		or not is_equal_approx(
			definition.cadence_shots_per_second,
			1.0 / candidate.weapon_cooldown
		)
		or definition.presentation_id != presentation_id
		or definition.fire_audio_id != fire_audio_id
		or definition.impact_audio_id != impact_audio_id
		or definition.dry_fire_audio_id != dry_fire_audio_id
	):
		return {}
	var converted := WeaponDefinitionResolverProfileType.to_resolver_profiles(
		definition,
		PLAYER_FACTION,
		origin_tolerance_meters
	)
	return (converted.get(expected_weapon_id, {}) as Dictionary).duplicate(true)


func _get_ship_entry_descriptor(candidate: HeroShip) -> Dictionary:
	if not is_instance_valid(candidate):
		return {
			"noun": "canopy",
			"open_verb": "open",
			"close_verb": "close",
			"boarding_verb": "board",
		}
	var definition := candidate.get_ship_definition()
	return definition.get_entry_descriptor() if definition != null else {
		"noun": "canopy",
		"open_verb": "open",
		"close_verb": "close",
		"boarding_verb": "board",
	}


func _find_boarding_candidate() -> HeroShip:
	var interaction_origin: Vector3 = player.get_interaction_origin()
	var nearest: HeroShip = null
	var nearest_distance_squared := INF

	# Physics discovery is deliberately treated as an unordered candidate set.
	# Choosing by the physical boarding-area centre prevents scene-tree or overlap
	# insertion order from changing which adjacent spacecraft receives the prompt.
	for interactable in player.get_nearby_interactables():
		if interactable is not ShipBoardingArea:
			continue
		var boarding_area := interactable as ShipBoardingArea
		var candidate := boarding_area.get_ship() as HeroShip
		if not (
			is_instance_valid(candidate)
			and candidate != _reboard_blocked_ship
			and boarding_area.is_available_for(player)
		):
			continue
		var distance_squared := interaction_origin.distance_squared_to(
			boarding_area.global_position
		)
		if _boarding_candidate_is_nearer(
			candidate,
			distance_squared,
			nearest,
			nearest_distance_squared
		):
			nearest = candidate
			nearest_distance_squared = distance_squared

	# The distance fallback keeps the interaction deterministic on the first
	# physics tick after a teleport and preserves compatibility with old saves or
	# test scenes that predate ShipBoardingArea. A craft that does own the modern
	# area must still pass that area's availability/reservation gate: the fallback
	# is a discovery bridge, never a way around a disabled or occupied seat.
	for candidate in ships:
		if not is_instance_valid(candidate) or candidate == _reboard_blocked_ship:
			continue
		var candidate_area := candidate.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
		if candidate_area != null:
			if not candidate_area.is_available_for(player):
				continue
		elif not candidate.is_boardable():
			continue
		var distance_squared := interaction_origin.distance_squared_to(
			candidate.get_boarding_position()
		)
		if distance_squared > BOARDING_FALLBACK_REACH * BOARDING_FALLBACK_REACH:
			continue
		if _boarding_candidate_is_nearer(
			candidate,
			distance_squared,
			nearest,
			nearest_distance_squared
		):
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest


func _boarding_candidate_is_nearer(
		candidate: HeroShip,
		distance_squared: float,
		current: HeroShip,
		current_distance_squared: float
	) -> bool:
	if not is_instance_valid(current):
		return true
	if distance_squared < current_distance_squared - 0.000001:
		return true
	if not is_equal_approx(distance_squared, current_distance_squared):
		return false
	# Equal-distance ties are rare but must still be stable across physics broad-
	# phase ordering. Scene paths are deterministic for the production fleet.
	return str(candidate.get_path()) < str(current.get_path())


func _find_station_interaction_candidate() -> Node3D:
	var origin: Vector3 = player.get_interaction_origin()
	var facing: Vector3 = player.get_interaction_direction()
	var best_candidate: Node3D
	var best_score := INF
	for candidate in player.get_nearby_interactables():
		if candidate is ShipBoardingArea:
			continue
		if not candidate.has_method("get_interaction_prompt") or not candidate.has_method("interact"):
			continue
		var offset: Vector3 = candidate.global_position - origin
		var distance: float = offset.length()
		if distance > 0.01:
			var facing_dot: float = facing.dot(offset / distance)
			if facing_dot < 0.05:
				continue
			# Favour what the player is looking at without making a slightly
			# off-centre nearby control impossible to use.
			distance -= facing_dot * 0.65
		if distance < best_score:
			best_score = distance
			best_candidate = candidate
	return best_candidate


func _get_active_berth_transform() -> Transform3D:
	if is_instance_valid(active_ship) and world.has_method("has_berth"):
		var berth_id := active_ship.get_home_berth_id()
		if world.call("has_berth", berth_id):
			return world.call("get_berth_transform", berth_id) as Transform3D
	return world.get_ship_spawn()


func _find_active_landing_berth() -> StringName:
	return StringName(
		_get_active_landing_assist_report().get("selected_berth_id", &"")
	)


func _get_active_landing_assist_report() -> Dictionary:
	if not is_instance_valid(active_ship):
		return {
			"valid": false,
			"assist_capture_accepted": false,
			"errors": PackedStringArray(["candidate_unavailable"]),
			"selected_berth_id": &"",
		}
	if world.has_method("get_landing_assist_report"):
		return world.call(
			"get_landing_assist_report",
			active_ship,
			active_ship.get_home_berth_id()
		) as Dictionary
	# Compatibility for marker-only custom worlds. Production always uses the
	# complete non-mutating ShipBerth capture report above.
	var berth_id := &""
	if world.has_method("find_landing_berth"):
		berth_id = world.call(
			"find_landing_berth",
			active_ship.global_position,
			active_ship.get_home_berth_id()
		) as StringName
	elif world.is_landing_position(active_ship.global_position):
		berth_id = active_ship.get_home_berth_id()
	var accepted := not berth_id.is_empty() and _can_ship_use_berth(active_ship, berth_id)
	return {
		"valid": accepted,
		"assist_capture_accepted": accepted,
		"errors": PackedStringArray(),
		"berth_id": berth_id,
		"selected_berth_id": berth_id,
	}


func _try_request_landing() -> void:
	if not is_instance_valid(active_ship):
		return
	if _network_session_mode == &"client":
		if is_instance_valid(hud):
			hud.toast(
				"Landing controlled by host",
				"Client landing replicas are presentation-only",
			)
		return
	if _landing_request_active:
		hud.toast("Landing assist active", "Maintain clearance while the docking sequence completes")
		return
	if phase not in [Phase.RETURN_TO_YARD, Phase.FREE_FLIGHT]:
		hud.toast("Landing unavailable", "Complete the active flight objective first")
		return
	if phase == Phase.FREE_FLIGHT and not _sortie_departed_berth:
		var telemetry: Dictionary = active_ship.get_telemetry()
		if not bool(telemetry.get("landed", false)):
			_mark_sortie_departed()
		if not _sortie_departed_berth:
			hud.toast("Already docked", "Clear the berth before requesting a return approach")
			return
	var landing_report := _get_active_landing_assist_report()
	var berth_id := StringName(landing_report.get("selected_berth_id", &""))
	if berth_id.is_empty():
		hud.toast("Landing unavailable", _landing_assist_failure_copy(landing_report))
		return
	if not bool(landing_report.get("assist_capture_accepted", false)):
		hud.toast("Landing unavailable", _landing_assist_failure_copy(landing_report))
		return
	if _planetary_return_physical_arrival_required \
			and berth_id != active_ship.get_home_berth_id():
		hud.toast(
			"Landing unavailable",
			"The Ember return must finish at this craft's registered home berth",
		)
		return
	if not _reserve_berth_for_ship(active_ship, berth_id, false):
		hud.toast("Berth occupied", "Choose another illuminated docking node")
		return
	var landing_berth := (
		world.call("get_berth_node", berth_id) as ShipBerth
		if world.has_method("get_berth_node")
		else null
	)
	if landing_berth == null:
		_release_ship_berth(active_ship)
		_active_landing_berth_id = &""
		hud.toast("Landing unavailable", "The selected berth has no physical landing contract")
		return
	if active_ship.request_berth_landing(landing_berth):
		_landing_request_active = true
		_active_landing_berth_id = berth_id
		if _planetary_return_physical_arrival_required:
			var physical_arrival := _arm_planetary_return_physical_arrival(
				landing_berth
			)
			if not bool(physical_arrival.get("accepted", false)):
				# Invalidating this one lease lets HeroShip's normal authority check
				# abort the assist on its next physics tick; the adapter never owns
				# a second release path.
				_release_ship_berth(active_ship)
				hud.toast(
					"Landing coordination interrupted",
					"The physical Ember return proof changed — retry the approach",
					3.5,
				)
				return
		var network_handoff := _begin_network_landing_handoff(
			active_ship, landing_berth
		)
		if not bool(network_handoff.get("accepted", false)):
			# The ship's next authority check observes this physical lease release
			# and emits the ordinary abort. No parallel landing rollback is owned
			# by networking.
			_release_ship_berth(active_ship)
			hud.toast(
				"Landing coordination interrupted",
				"The server landing handoff changed — retry the approach",
				3.5,
			)
			return
		if _convoy_is_running():
			_fail_active_activity(&"landing_requested")
	else:
		_release_ship_berth(active_ship)
		_active_landing_berth_id = &""
		hud.toast("Landing unavailable", "The approach changed before assist could engage — try again")


func _landing_assist_failure_copy(report: Dictionary) -> String:
	if _landing_report_has_error(report, "assist_capture_speed_exceeds_limit"):
		return (
			"Reduce speed to %.0f m/s or below"
			% float(report.get("effective_maximum_speed", 0.0))
		)
	if _landing_report_has_error(report, "assist_capture_attitude_exceeds_limit"):
		return (
			"Level the craft to within %.0f° of upright"
			% float(report.get("maximum_up_angle_degrees", 75.0))
		)
	if _landing_report_has_error(report, "docked_hull_does_not_fit"):
		return "This berth cannot safely fit the spacecraft"
	if _landing_report_has_error(report, "ship_collision_bounds_invalid"):
		return "The spacecraft landing envelope is unavailable"
	return "Enter an available compatible berth approach volume"


func _active_landing_assist_status() -> String:
	if not is_instance_valid(active_ship):
		return "LANDING ASSIST ACTIVE"
	var contract := active_ship.get_landing_contract_report()
	return _landing_assist_phase_status(StringName(contract.get("phase", &"")))


func _landing_assist_phase_status(landing_phase: StringName) -> String:
	match landing_phase:
		&"brake":
			return "LANDING ASSIST  //  BRAKING"
		&"move_to_staging":
			return "LANDING ASSIST  //  STAGING"
		&"align":
			return "LANDING ASSIST  //  ALIGNING"
		&"final_approach":
			return "LANDING ASSIST  //  FINAL APPROACH"
		_:
			return "LANDING ASSIST ACTIVE"


func _landing_report_has_error(report: Dictionary, error_id: String) -> bool:
	var errors := report.get("errors", PackedStringArray()) as PackedStringArray
	return errors.has(error_id)


func _on_ship_destroyed(
		world_position: Vector3,
		_inherited_velocity: Vector3,
		source_ship: HeroShip
	) -> void:
	if not is_instance_valid(source_ship) or not ships.has(source_ship):
		return
	_publish_network_damage_state(source_ship, 0.0, true)
	if source_ship.get_pending_terminal_damage_presentation_receipt_id() < 0:
		combat_audio.play_explosion(world_position, source_ship.get_instance_id())
	if source_ship == active_ship and _planetary_return_physical_arrival_armed:
		_abort_planetary_return_physical_arrival(&"return_ship_destroyed")
	_release_ship_berth(source_ship)
	var active_transition_loss := (
		source_ship == active_ship
		and phase in [Phase.BOARDING, Phase.DISEMBARKING, Phase.IN_FLIGHT_CABIN]
	)
	if source_ship == active_ship and (_piloting or active_transition_loss):
		_fail_active_activity(&"ship_destroyed")
		if not _recovering:
			_invalidate_transition_generation()
			_recover_from_destroyed_ship(source_ship)
		return
	# Parked fleet craft remain real damageable bodies in the shared world. Losing
	# one must not alter the active pilot/mission, but it still needs the same safe
	# berth regeneration lifecycle instead of remaining a dead untracked hull.
	hud.toast("Parked craft lost", "%s queued for berth regeneration" % source_ship.get_display_name(), 2.6)
	_replenish_destroyed_ship(source_ship)


func _recover_from_destroyed_ship(destroyed_ship: HeroShip) -> void:
	_recovering = true
	_advance_first_sortie_tutorial_source(&"active_ship_destroyed")
	# Losing the cabin is exactly the case the outer safety net exists for. Drop
	# containment and occupancy before the avatar is teleported back to the deck,
	# so nothing keeps trying to hold it against a hull that no longer exists.
	_release_cabin_occupancy()
	_landing_request_active = false
	_active_landing_berth_id = &""
	_planetary_return_physical_arrival_required = false
	_planetary_return_physical_arrival_armed = false
	_last_planetary_return_physical_arrival_result.clear()
	_transition_busy = true
	phase = Phase.RECOVERING
	opponent.deactivate()
	# A lost guided Torrent can be regenerated and retried in the same world.
	# Clearing this latch lets its opponent spawn again after the range contacts
	# are already complete instead of stranding the retry at the launch gate.
	if destroyed_ship == ship and not _guided_activity_complete:
		_guided_return_ready_for_completion = false
		_opponent_spawned = false
	hud.set_enemy_status("", 0.0, 1.0, false)
	hud.set_interaction("", false)
	hud.set_objective("Regeneration recall in progress", "SPACECRAFT LOST")
	hud.toast(
		"Hull integrity lost",
		(
			"Pilot recalled — berth regeneration ETA %.0f seconds; "
			+ "the other craft remains available"
		) % (float(DESTROYED_SHIP_REGENERATION_DELAY_MSEC) / 1000.0),
		3.0
	)
	destroyed_ship.set_piloted(false)
	if destroyed_ship.get_camera() != null:
		destroyed_ship.get_camera().current = false
	_recall_pilot_to_deck()
	_launch_registered = false
	_return_registered = false
	_sortie_departed_berth = false
	if _guided_activity_complete:
		phase = Phase.COMPLETE
		hud.set_objective("Walk to the other craft or wait for berth regeneration", "SHIPYARD SANDBOX")
	else:
		phase = Phase.APPROACH_SHIP
		_sandbox_sortie = false
		opponent.set_target(ship)
		hud.set_objective(
			"Board the Torrent interceptor to begin the pending guided flight test",
			"GUIDED TEST PENDING"
		)
		publish_first_sortie_tutorial_phase(
			&"walk_interact", _first_sortie_tutorial_generation
		)
	_transition_busy = false
	_recovering = false
	_replenish_destroyed_ship(destroyed_ship)


## Selects one production sortie before launch. Race and patrol remain distinct
## typed interpretations of the shared Cinder route; cargo and convoy retain
## their own authority-backed definitions. The first accepted start locks every
## interpretation so no generation-bearing sortie can be swapped under the player.
func select_activity_kind(activity_kind: StringName) -> Dictionary:
	if is_queued_for_deletion() or not is_inside_tree():
		return _activity_selection_result(false, &"detached")
	if activity_kind not in [
		ACTIVITY_KIND_TIMED_RACE,
		ACTIVITY_KIND_PATROL,
		ACTIVITY_KIND_CARGO_DELIVERY,
		ACTIVITY_KIND_CONVOY_ESCORT,
	]:
		return _activity_selection_result(false, &"unsupported_activity_kind")
	if _activity_selection_locked and activity_kind != _selected_activity_kind:
		return _activity_selection_result(false, &"selection_locked")
	if activity_kind == _selected_activity_kind:
		return _activity_selection_result(true, &"already_selected")
	if (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_transfer_authority == null
		or cargo_delivery_activity == null
	):
		return _activity_selection_result(false, &"director_unavailable")
	var current := _get_selected_activity_snapshot()
	if bool(current.get("running", false)):
		return _activity_selection_result(false, &"activity_in_progress")
	# Cargo binding is the one replacement preflight that can fail while the
	# current Cinder owner is still healthy. Reject before touching that owner.
	if (
		activity_kind == ACTIVITY_KIND_CARGO_DELIVERY
		and not _restore_cargo_delivery_bindings()
	):
		return _activity_selection_result(false, &"activity_attach_failed")
	var previous_kind := _selected_activity_kind
	var previous_active_id := _active_activity_id
	var previous_active_generation := _active_activity_generation
	_detach_cinder_race_session()
	_selected_activity_kind = activity_kind
	_restore_cinder_race_session(false)
	if not _selected_activity_composition_ready():
		# Selection is a transaction: a failed replacement cannot strand the
		# previous route without an owner or make a rejected HUD request visible.
		_detach_cinder_race_session()
		_selected_activity_kind = previous_kind
		_active_activity_id = previous_active_id
		_active_activity_generation = previous_active_generation
		_restore_cinder_race_session(false)
		_sync_activity_hud()
		return _activity_selection_result(false, &"activity_attach_failed")
	_active_activity_id = &""
	_active_activity_generation = 0
	_sync_activity_hud()
	return _activity_selection_result(true, &"selected")


## Public production start seam used by a flight/session owner. Starting is
## allowed only while the physical pilot is in general free flight; the
## ActivityDirector itself intentionally has no knowledge of that authority.
func request_activity_start(
	activity_id: StringName,
	sampled_world_position: Variant = null
	) -> Dictionary:
	if is_queued_for_deletion() or not is_inside_tree():
		return {"accepted": false, "reason": &"detached"}
	if (
		not is_instance_valid(activity_director)
		or cinder_race_session == null
		or patrol_activity == null
		or cargo_transfer_authority == null
		or cargo_delivery_activity == null
		or (
			_selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT
			and not is_instance_valid(cinder_convoy_host)
		)
	):
		return {"accepted": false, "reason": &"director_unavailable"}
	if activity_id != _get_selected_activity_id():
		return {"accepted": false, "reason": &"unsupported_activity"}
	if not _piloting or not is_instance_valid(active_ship) or phase != Phase.FREE_FLIGHT:
		return {"accepted": false, "reason": &"not_in_free_flight"}
	if (
		_selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY
		and active_ship != _cargo_delivery_source_ship
	):
		return {"accepted": false, "reason": &"delivery_craft_required"}
	var started: Dictionary
	match _selected_activity_kind:
		ACTIVITY_KIND_PATROL:
			# A terminal patrol remains visible and inert until the player makes a
			# fresh start request.  That one request crosses the existing reset
			# seam before starting, so callers cannot accidentally create a second
			# route owner or race a separate reset/start pair.
			var patrol_state := StringName(
				patrol_activity.get_presentation_snapshot().get("state_id", &"idle")
			)
			if patrol_state in [&"completed", &"failed", &"aborted"]:
				var repeat_reset := patrol_activity.reset(
					patrol_activity.get_generation()
				)
				if not bool(repeat_reset.get("accepted", false)):
					return _decorate_activity_snapshot(repeat_reset)
			started = patrol_activity.start(
				patrol_activity.get_generation(), active_ship
			)
		ACTIVITY_KIND_CARGO_DELIVERY:
			if not _restore_cargo_delivery_bindings():
				return {"accepted": false, "reason": &"cargo_authority_detached"}
			started = cargo_delivery_activity.start(
				cargo_delivery_activity.get_generation()
			)
		ACTIVITY_KIND_CONVOY_ESCORT:
			started = _start_cinder_convoy(sampled_world_position)
		_:
			started = cinder_race_session.start(
				cinder_race_session.get_session_generation()
			)
	if bool(started.get("accepted", false)):
		_active_activity_id = activity_id
		_activity_selection_locked = true
		_active_activity_generation = _get_selected_activity_generation()
		if _selected_activity_kind == ACTIVITY_KIND_TIMED_RACE:
			save_cinder_race_session()
		if _selected_activity_kind == ACTIVITY_KIND_PATROL:
			save_cinder_patrol_session()
		if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
			# FREE_FLIGHT is reached only after the physical ship has cleared its
			# berth, so this phase observes an existing lifecycle fact.
			var departed := cargo_delivery_activity.submit_phase(
				CARGO_DELIVERY_PHASES[0],
				_active_activity_generation
			)
			if not bool(departed.get("accepted", false)):
				cargo_delivery_activity.fail(
					&"delivery_departure_rejected",
					_active_activity_generation
				)
				started = cargo_delivery_activity.get_snapshot()
				started["accepted"] = false
				started["reason"] = &"delivery_departure_rejected"
			else:
				started = cargo_delivery_activity.get_snapshot()
				started["accepted"] = true
				started["reason"] = &"started"
		_sync_activity_hud()
	return _decorate_activity_snapshot(started)


func _start_cinder_convoy(sampled_world_position: Variant) -> Dictionary:
	if not _sortie_departed_berth:
		return {"accepted": false, "reason": &"sortie_not_departed"}
	if _landing_request_active:
		return {"accepted": false, "reason": &"landing_in_progress"}
	if not active_ship.is_piloted() or active_ship.is_destroyed():
		return {"accepted": false, "reason": &"ship_not_healthy_and_piloted"}
	var position: Vector3
	if sampled_world_position is Vector3:
		position = sampled_world_position as Vector3
	else:
		position = active_ship.global_position
	if not position.is_finite():
		return {"accepted": false, "reason": &"invalid_ship_position"}
	_convoy_last_player_position = position
	_convoy_has_player_sample = true
	if position.distance_to(_cinder_convoy_activation_center()) > CINDER_CONVOY_ACTIVATION_RADIUS:
		return {"accepted": false, "reason": &"outside_convoy_activation_sphere"}
	var stream := _get_cinder_stream_snapshot()
	var loaded_instance_id := int(stream.get("loaded_instance_id", 0))
	var loaded_generation := int(stream.get("loaded_generation", -1))
	if loaded_instance_id <= 0 or loaded_generation < 1:
		return {"accepted": false, "reason": &"cinder_generation_unavailable"}
	if _other_activity_is_running():
		return {"accepted": false, "reason": &"activity_in_progress"}
	var started := cinder_convoy_host.start(cinder_convoy_host.get_generation())
	if not bool(started.get("accepted", false)):
		return started
	_convoy_stream_instance_id = loaded_instance_id
	_convoy_stream_generation = loaded_generation
	_convoy_active_ship_instance_id = active_ship.get_instance_id()
	_convoy_terminal_reason = &""
	cinder_convoy_host.visible = true
	return started


## Explicit failure/recovery surface. A caller may end only the currently
## observed generation, so a delayed destruction/landing callback cannot fail a
## replacement route.
func fail_active_activity(reason: StringName) -> bool:
	if not _can_recover_live_activity():
		return false
	return _fail_active_activity(reason)


func reset_active_activity() -> bool:
	if not _can_recover_live_activity():
		return false
	if (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
		or _active_activity_id.is_empty()
		or (
			_selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT
			and not is_instance_valid(cinder_convoy_host)
		)
	):
		return false
	var reset: Dictionary
	match _selected_activity_kind:
		ACTIVITY_KIND_PATROL:
			reset = patrol_activity.reset(patrol_activity.get_generation())
		ACTIVITY_KIND_CARGO_DELIVERY:
			reset = cargo_delivery_activity.reset(
				cargo_delivery_activity.get_generation()
			)
		ACTIVITY_KIND_CONVOY_ESCORT:
			reset = cinder_convoy_host.reset(cinder_convoy_host.get_generation())
		_:
			reset = cinder_race_session.reset(
				cinder_race_session.get_session_generation()
			)
	if bool(reset.get("accepted", false)):
		_active_activity_generation = _get_selected_activity_generation()
		if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
			_convoy_stream_instance_id = 0
			_convoy_stream_generation = -1
			_convoy_active_ship_instance_id = 0
			_convoy_terminal_reason = &""
		_sync_activity_hud()
	return bool(reset.get("accepted", false))


func _can_recover_live_activity() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_activity_director() -> ActivityDirector:
	return activity_director


## Detached Ember production composition state. This is observability only;
## GameFlow never gains Ember streaming-generation or rebase authority.
func get_ember_streaming_report() -> Dictionary:
	return (
		ember_streaming_binding.audit()
		if is_instance_valid(ember_streaming_binding)
		else {}
	).duplicate(true)


func get_common_world_origin_report() -> Dictionary:
	return (
		common_world_origin_rebase_owner.audit()
		if is_instance_valid(common_world_origin_rebase_owner)
		else {}
	).duplicate(true)


func get_active_activity_snapshot() -> Dictionary:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return (
			_decorate_activity_snapshot(_get_convoy_activity_snapshot())
			if is_instance_valid(cinder_convoy_host)
			else {}
		)
	if (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
		or _active_activity_id.is_empty()
	):
		return {}
	return _decorate_activity_snapshot(_get_selected_activity_snapshot())


## Inspectable boundary proving this layer observes one physical ship and owns
## none of the authorities adjacent to it.
func get_activity_integration_report() -> Dictionary:
	var directors: Array[ActivityDirector] = []
	for child in get_children():
		if child is ActivityDirector:
			directors.append(child as ActivityDirector)
	var race_snapshot := (
		cinder_race_session.get_presentation_snapshot()
		if cinder_race_session != null
		else {}
	)
	var patrol_snapshot := (
		patrol_activity.get_presentation_snapshot()
		if patrol_activity != null
		else {}
	)
	var attached_route_owner_count := (
		int(bool(race_snapshot.get("attached", false)))
		+ int(bool(patrol_snapshot.get("attached", false)))
	)
	var selected_adapter: Object
	match _selected_activity_kind:
		ACTIVITY_KIND_PATROL:
			selected_adapter = patrol_activity
		ACTIVITY_KIND_CARGO_DELIVERY:
			selected_adapter = cargo_delivery_activity
		ACTIVITY_KIND_CONVOY_ESCORT:
			selected_adapter = cinder_convoy_host
		_:
			selected_adapter = cinder_race_session
	var cargo_authority_audit := (
		cargo_transfer_authority.audit()
		if cargo_transfer_authority != null
		else {}
	)
	return {
		"director": activity_director,
		"director_count": directors.size(),
		"route_activity_id": DEFAULT_FREE_FLIGHT_ACTIVITY_ID,
		"selected_activity_kind": _selected_activity_kind,
		"selection_locked": _activity_selection_locked,
		"attached_route_owner_count": attached_route_owner_count,
		"active_activity_id": _active_activity_id,
		"active_generation": _active_activity_generation,
		"snapshot": get_active_activity_snapshot(),
		"session": selected_adapter,
		"session_instance_id": selected_adapter.get_instance_id() if selected_adapter != null else 0,
		"race_session": cinder_race_session,
		"race_session_instance_id": cinder_race_session.get_instance_id() if cinder_race_session != null else 0,
		"patrol_activity": patrol_activity,
		"patrol_activity_instance_id": patrol_activity.get_instance_id() if patrol_activity != null else 0,
		"position_sample_count": _cinder_position_sample_count,
		"actor_position_sample_count": _cinder_actor_sample_count,
		"convoy_host": cinder_convoy_host,
		"convoy_host_count": find_children(
			"CinderConvoyEscortHost", "CinderConvoyEscortHost", true, false
		).size(),
		"convoy_host_instance_id": (
			cinder_convoy_host.get_instance_id()
			if is_instance_valid(cinder_convoy_host) else 0
		),
		"convoy_host_parent_is_main": (
			is_instance_valid(cinder_convoy_host)
			and cinder_convoy_host.get_parent() == self
		),
		"convoy_host_transform": (
			cinder_convoy_host.transform
			if is_instance_valid(cinder_convoy_host) else Transform3D.IDENTITY
		),
		"convoy_stream_instance_id": _convoy_stream_instance_id,
		"convoy_stream_generation": _convoy_stream_generation,
		"convoy_active_ship_instance_id": _convoy_active_ship_instance_id,
		"convoy_terminal_reason": _convoy_terminal_reason,
		"convoy_activation_center": _cinder_convoy_activation_center(),
		"convoy_activation_radius": CINDER_CONVOY_ACTIVATION_RADIUS,
		"convoy_escort_lane_offset": CINDER_CONVOY_ESCORT_LANE_OFFSET,
		"streaming": (
			cinder_streaming_binding.get_snapshot()
			if is_instance_valid(cinder_streaming_binding) else {}
		),
		"cargo_delivery_activity": cargo_delivery_activity,
		"cargo_delivery_activity_instance_id": cargo_delivery_activity.get_instance_id() if cargo_delivery_activity != null else 0,
		"cargo_transfer_authority": cargo_transfer_authority,
		"cargo_transfer_authority_instance_id": cargo_transfer_authority.get_instance_id() if cargo_transfer_authority != null else 0,
		"cargo_transfer_authority_count": find_children("CargoTransferAuthority", "CargoTransferAuthority", true, false).size(),
		"cargo_source_handle": _cargo_delivery_source_handle.duplicate(true),
		"cargo_destination_handle": _cargo_delivery_destination_handle.duplicate(true),
		"cargo_source_entity": _cargo_delivery_source_ship,
		"cargo_destination_entity": _cargo_delivery_destination,
		"cargo_source_manifest": (
			cargo_transfer_authority.get_manifest_snapshot(
				_cargo_delivery_source_handle
			)
			if cargo_transfer_authority != null
			else {}
		),
		"cargo_destination_manifest": (
			cargo_transfer_authority.get_manifest_snapshot(
				_cargo_delivery_destination_handle
			)
			if cargo_transfer_authority != null
			else {}
		),
		"cargo_contract": (
			(
				cargo_delivery_activity.get_snapshot().get("contract", {})
				as Dictionary
			).duplicate(true)
			if cargo_delivery_activity != null
			else {}
		),
		"cargo_authority_audit": cargo_authority_audit.duplicate(true),
		"cargo_physics_step_count": _cargo_delivery_physics_step_count,
		"cargo_evidence_status": CARGO_DELIVERY_EVIDENCE_STATUS,
		"cargo_source_bounded": false,
		"cargo_historical_authenticity_claim": false,
		"inventory_authority": cargo_transfer_authority,
		"owns_inventory": false,
		"uses_caller_physics_delta": true,
		"observed_ship": active_ship if _piloting and is_instance_valid(active_ship) else null,
		"gameplay_authority": false,
		"grants_rewards": false,
		"combat_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"network_authority": false,
	}


func _start_default_free_flight_activity() -> void:
	# Convoy activation belongs to the audited physics-space rendezvous sphere,
	# not the generic moment a craft first leaves its berth.
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return
	if not _active_activity_id.is_empty():
		var existing := get_active_activity_snapshot()
		if bool(existing.get("running", false)):
			return
	var result := request_activity_start(_get_selected_activity_id())
	if (
		_selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY
		and result.get("reason", &"") == &"delivery_craft_required"
		and is_instance_valid(hud)
	):
		hud.toast(
			"Delivery craft required",
			"Board the Jovian light freighter for this fabrication-kit run",
			3.2
		)


func _advance_selected_activity(delta: float, world_position: Vector3) -> void:
	if (
		not is_finite(delta)
		or delta < 0.0
		or not world_position.is_finite()
		or cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
	):
		return
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		_advance_cinder_convoy(delta, world_position)
		return
	if _active_activity_id.is_empty():
		return
	if _selected_activity_kind == ACTIVITY_KIND_PATROL:
		if phase != Phase.FREE_FLIGHT or not _piloting \
				or not is_instance_valid(active_ship):
			return
		_advance_patrol(delta, active_ship, world_position)
		return
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_advance_cargo_delivery(delta)
		return
	# A restored race may exist before the player has returned to ordinary free
	# flight. Boarding the guided-test craft during startup must not make that
	# retained Cinder clock consume physics from an unrelated phase.
	if phase != Phase.FREE_FLIGHT:
		return
	var generation := cinder_race_session.get_session_generation()
	var advanced := cinder_race_session.advance_physics(delta, generation)
	if not bool(advanced.get("accepted", false)):
		return
	if advanced.get("state_id", &"") != &"active":
		return
	_cinder_position_sample_count += 1
	cinder_race_session.submit_position(world_position, generation)


func _advance_cinder_convoy(delta: float, world_position: Vector3) -> void:
	if not is_instance_valid(cinder_convoy_host):
		return
	_convoy_last_player_position = world_position
	_convoy_has_player_sample = true
	if not _convoy_is_running():
		var activity := (
			cinder_convoy_host.get_snapshot().get("activity", {}) as Dictionary
		)
		if (
			activity.get("state_id", &"") == &"idle"
			and world_position.distance_to(_cinder_convoy_activation_center())
			<= CINDER_CONVOY_ACTIVATION_RADIUS
		):
			request_activity_start(CINDER_CONVOY_ACTIVITY_ID, world_position)
	if not _convoy_is_running():
		_sync_activity_hud()
		return
	_cinder_position_sample_count += 1
	var generation := cinder_convoy_host.get_generation()
	var advanced := cinder_convoy_host.advance_physics(
		delta,
		world_position,
		generation
	)
	if not bool(advanced.get("accepted", false)) and _convoy_is_running():
		_fail_active_activity(&"convoy_advance_rejected")


func _advance_patrol(
	delta: float,
	patrol_actor: Node3D,
	sampled_world_position: Vector3
) -> void:
	var generation := patrol_activity.get_generation()
	var before := patrol_activity.get_presentation_snapshot()
	if before.get("state_id", &"") != &"active":
		return
	# The live active ship is sampled once and fenced by PatrolActivity. Its exit
	# signal remains observable even when no later GameFlow physics tick exists.
	_cinder_position_sample_count += 1
	patrol_activity.advance_actor_physics(
		delta, patrol_actor, sampled_world_position, generation
	)


func _advance_cargo_delivery(delta: float) -> void:
	var generation := cargo_delivery_activity.get_generation()
	var snapshot := cargo_delivery_activity.get_snapshot()
	if int(snapshot.get("state", CargoDeliveryActivity.State.IDLE)) != CargoDeliveryActivity.State.ACTIVE:
		return
	var advanced := cargo_delivery_activity.advance_physics(delta, generation)
	if bool(advanced.get("accepted", false)) and not is_zero_approx(delta):
		_cargo_delivery_physics_step_count += 1


func _complete_cargo_delivery_on_return() -> bool:
	if (
		_selected_activity_kind != ACTIVITY_KIND_CARGO_DELIVERY
		or cargo_delivery_activity == null
		or _active_activity_id != CARGO_DELIVERY_ACTIVITY_ID
	):
		return false
	var snapshot := cargo_delivery_activity.get_snapshot()
	if int(snapshot.get("state", CargoDeliveryActivity.State.IDLE)) != CargoDeliveryActivity.State.ACTIVE:
		return false
	var generation := cargo_delivery_activity.get_generation()
	var returned := cargo_delivery_activity.submit_phase(
		CARGO_DELIVERY_PHASES[1],
		generation
	)
	if not bool(returned.get("accepted", false)):
		cargo_delivery_activity.fail(&"delivery_return_rejected", generation)
		return false
	var delivered := cargo_delivery_activity.submit_transfer(generation)
	if not bool(delivered.get("accepted", false)):
		if cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.ACTIVE:
			cargo_delivery_activity.fail(&"cargo_transfer_rejected", generation)
		return false
	return true


func _fail_active_activity(reason: StringName) -> bool:
	if (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
		or _active_activity_id.is_empty()
		or (
			_selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT
			and not is_instance_valid(cinder_convoy_host)
		)
	):
		return false
	var failed: Dictionary
	match _selected_activity_kind:
		ACTIVITY_KIND_PATROL:
			if reason == &"returned_to_shipyard":
				failed = patrol_activity.abort(reason, patrol_activity.get_generation())
			else:
				failed = patrol_activity.fail(reason, patrol_activity.get_generation())
		ACTIVITY_KIND_CARGO_DELIVERY:
			failed = cargo_delivery_activity.fail(
				reason,
				cargo_delivery_activity.get_generation()
			)
		ACTIVITY_KIND_CONVOY_ESCORT:
			_convoy_terminal_reason = reason
			failed = cinder_convoy_host.report_convoy_lost(
				cinder_convoy_host.get_generation()
			)
		_:
			failed = cinder_race_session.fail(
				reason,
				cinder_race_session.get_session_generation()
			)
	return bool(failed.get("accepted", false))


func _reset_terminal_activity_for_next_sortie() -> void:
	if (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
		or _active_activity_id.is_empty()
	):
		return
	var state_id := StringName(get_active_activity_snapshot().get("state_id", &"idle"))
	if state_id in [&"completed", &"failed", &"aborted", &"expired"]:
		reset_active_activity()


func _on_cinder_session_presentation_changed(snapshot: Dictionary) -> void:
	var fingerprint := _cinder_race_save_fingerprint(snapshot)
	if not fingerprint.is_empty() \
			and fingerprint != _cinder_race_session_saved_fingerprint:
		save_cinder_race_session()
	if _selected_activity_kind == ACTIVITY_KIND_TIMED_RACE:
		_sync_activity_hud()


func _cinder_race_save_fingerprint(snapshot: Dictionary) -> String:
	if int(snapshot.get("session_generation", 0)) < 1:
		return ""
	# Elapsed time deliberately is not part of this boundary fingerprint: it is
	# captured exactly on explicit/orderly save, while automatic writes occur only
	# for meaningful state, gate, lap, penalty, or result transitions.
	return "%d:%s:%d:%d:%.6f:%.6f:%.6f:%s" % [
		int(snapshot.get("session_generation", 0)),
		str(snapshot.get("state_id", &"idle")),
		int(snapshot.get("lap_number", 0)),
		int(snapshot.get("next_checkpoint_index", 0)),
		float(snapshot.get("penalty_seconds", 0.0)),
		float(snapshot.get("last_time_seconds", -1.0)),
		float(snapshot.get("best_time_seconds", -1.0)),
		str(snapshot.get("presentation_reason", &"")),
	]


func _on_cinder_session_completed(_snapshot: Dictionary) -> void:
	if is_instance_valid(hud):
		hud.toast("Cinder Reach race complete", "Time recorded — no reward granted", 3.2)


func _on_patrol_presentation_changed(snapshot: Dictionary) -> void:
	var fingerprint := _cinder_patrol_save_fingerprint(snapshot)
	if not fingerprint.is_empty() \
			and fingerprint != _cinder_patrol_session_saved_fingerprint:
		save_cinder_patrol_session()
	if _selected_activity_kind == ACTIVITY_KIND_PATROL:
		_sync_activity_hud()


func _cinder_patrol_save_fingerprint(snapshot: Dictionary) -> String:
	if int(snapshot.get("generation", 0)) < 1:
		return ""
	# Continuous elapsed/dwell time is captured exactly on explicit and detach
	# saves. Automatic writes track only meaningful lifecycle/ordered progress.
	return "%d:%s:%d:%d:%s:%s" % [
		int(snapshot.get("generation", 0)),
		str(snapshot.get("state_id", &"idle")),
		int(snapshot.get("completed_checkpoint_count", 0)),
		int(snapshot.get("dwell_checkpoint_index", PatrolActivity.ANY_CHECKPOINT)),
		str(bool(snapshot.get("checkpoint_occupied", false))),
		str(snapshot.get("terminal_reason", &"")),
	]


func _on_patrol_completed(_snapshot: Dictionary) -> void:
	if is_instance_valid(hud):
		hud.toast("Cinder Reach patrol complete", "Sweep recorded — no reward granted", 3.2)


func _on_cinder_convoy_presentation_changed(_snapshot: Dictionary) -> void:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		_sync_activity_hud()


func _on_cinder_convoy_safely_arrived(_snapshot: Dictionary) -> void:
	if is_instance_valid(hud):
		hud.toast(
			"Emberline tender arrived",
			"Escort recorded — no reward granted",
			3.2
		)


func _on_cinder_convoy_failed(snapshot: Dictionary) -> void:
	if _convoy_terminal_reason.is_empty():
		var activity := snapshot.get("activity", {}) as Dictionary
		_convoy_terminal_reason = StringName(activity.get("terminal_reason", &"convoy_lost"))
	if is_instance_valid(hud):
		hud.toast(
			"Emberline escort ended",
			str(_convoy_terminal_reason).replace("_", " ").capitalize(),
			3.2
		)


func _on_cinder_location_loaded(
	location_id: StringName,
	generation: int,
	instance: Node3D
	) -> void:
	if location_id != CinderStreamingBootstrap.LOCATION_ID:
		return
	if is_instance_valid(cinder_convoy_host):
		cinder_convoy_host.visible = is_instance_valid(instance)
	if _convoy_is_running() and (
		generation != _convoy_stream_generation
		or not is_instance_valid(instance)
		or instance.get_instance_id() != _convoy_stream_instance_id
	):
		_fail_active_activity(&"cinder_stream_replaced")


func _on_cinder_location_load_failed(
	location_id: StringName,
	_generation: int,
	_reason: StringName
	) -> void:
	if location_id == CinderStreamingBootstrap.LOCATION_ID and is_instance_valid(cinder_convoy_host):
		cinder_convoy_host.visible = false


func _on_cinder_location_unloaded(
	location_id: StringName,
	_generation: int
	) -> void:
	if location_id != CinderStreamingBootstrap.LOCATION_ID:
		return
	if _convoy_is_running():
		_fail_active_activity(&"cinder_stream_unloaded")
	if is_instance_valid(cinder_convoy_host):
		cinder_convoy_host.visible = false


func _sync_cinder_convoy_stream_presence() -> void:
	if not is_instance_valid(cinder_convoy_host):
		return
	var stream := _get_cinder_stream_snapshot()
	var loaded_instance_id := int(stream.get("loaded_instance_id", 0))
	var loaded_generation := int(stream.get("loaded_generation", -1))
	cinder_convoy_host.visible = loaded_instance_id > 0
	if not _convoy_is_running():
		return
	if loaded_instance_id <= 0:
		_fail_active_activity(&"cinder_stream_unloaded")
	elif (
		loaded_instance_id != _convoy_stream_instance_id
		or loaded_generation != _convoy_stream_generation
	):
		_fail_active_activity(&"cinder_stream_replaced")


func _get_cinder_stream_snapshot() -> Dictionary:
	return (
		cinder_streaming_bootstrap.get_snapshot()
		if is_instance_valid(cinder_streaming_bootstrap)
		else {}
	)


func _convoy_is_running() -> bool:
	if not is_instance_valid(cinder_convoy_host):
		return false
	var activity := cinder_convoy_host.get_snapshot().get("activity", {}) as Dictionary
	return activity.get("state_id", &"") == &"active"


func _selected_activity_is_running() -> bool:
	if _active_activity_id.is_empty():
		return false
	return bool(get_active_activity_snapshot().get("running", false))


func _other_activity_is_running() -> bool:
	return (
		(
			cinder_race_session != null
			and bool(cinder_race_session.get_presentation_snapshot().get("running", false))
		)
		or (
			patrol_activity != null
			and bool(patrol_activity.get_presentation_snapshot().get("running", false))
		)
		or (
			cargo_delivery_activity != null
			and cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.ACTIVE
		)
	)


func _on_cargo_delivery_snapshot_changed(_snapshot: Dictionary) -> void:
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_sync_activity_hud()


func _on_cargo_delivery_completed(
	_snapshot: Dictionary,
	receipt: Dictionary
	) -> void:
	if _selected_activity_kind != ACTIVITY_KIND_CARGO_DELIVERY:
		return
	_sync_activity_hud()
	if is_instance_valid(hud):
		hud.toast(
			"Fabrication kits delivered",
			"%d units received at the Jovian freight berth — no reward granted"
			% int(receipt.get("quantity", 0)),
			3.2
		)


func _sync_activity_hud() -> void:
	_sync_nearby_activity_hud()
	if not is_instance_valid(hud) or not hud.has_method(&"set_activity_objective"):
		return
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		var convoy_snapshot := get_active_activity_snapshot()
		hud.call(
			&"set_activity_objective",
			str(convoy_snapshot.get("display_name", "Emberline supply tender escort")),
			convoy_snapshot
		)
	elif (
		cinder_race_session == null
		or patrol_activity == null
		or cargo_delivery_activity == null
		or _active_activity_id.is_empty()
	):
		hud.call(&"clear_activity_objective")
	else:
		var snapshot := get_active_activity_snapshot()
		hud.call(
			&"set_activity_objective",
			str(snapshot.get("display_name", "Cinder Reach race")),
			snapshot
		)
	if hud.has_method(&"set_activity_selection_state"):
		var board_status_reason: StringName = &""
		if (
			_selected_activity_kind == ACTIVITY_KIND_PATROL
			and _activity_selection_locked
			and StringName(
				patrol_activity.get_presentation_snapshot().get("state_id", &"idle")
			) in [&"completed", &"failed", &"aborted"]
		):
			board_status_reason = &"repeat_ready"
		hud.call(
			&"set_activity_selection_state",
			_selected_activity_kind,
			_activity_selection_locked,
			board_status_reason
		)


func _get_nearby_activity_binding() -> Node:
	if not is_instance_valid(world) or not world.has_method(&"get_nearby_sector_cluster"):
		return null
	var cluster := world.call(&"get_nearby_sector_cluster") as Node
	if not is_instance_valid(cluster):
		return null
	return cluster.get_node_or_null(^"ActivityBinding") as Node


func _sync_nearby_activity_hud() -> void:
	if not is_instance_valid(hud):
		return
	var binding := _get_nearby_activity_binding()
	if not is_instance_valid(binding) or not binding.has_method(&"get_snapshot"):
		_detach_nearby_activity_audio()
		if hud.has_method(&"clear_nearby_activity_snapshot"):
			hud.call(&"clear_nearby_activity_snapshot")
		return
	if binding.has_method(&"bind_production_convoy_host"):
		var convoy_binding := binding.call(
			&"bind_production_convoy_host", cinder_convoy_host
		) as Dictionary
		if not bool(convoy_binding.get("accepted", false)):
			_detach_nearby_activity_audio()
			if hud.has_method(&"clear_nearby_activity_snapshot"):
				hud.call(&"clear_nearby_activity_snapshot")
			return
	bind_cinder_race_best_persistence(binding)
	bind_cinder_scan_discovery_persistence(binding)
	bind_cinder_cargo_delivery_persistence(binding)
	bind_cinder_mining_capacity_persistence(binding)
	bind_cinder_convoy_arrival_persistence(binding)
	var snapshot := binding.call(&"get_snapshot") as Dictionary
	_sync_nearby_activity_audio(snapshot)
	if hud.has_method(&"set_nearby_activity_snapshot"):
		hud.call(&"set_nearby_activity_snapshot", snapshot)


func _initialize_halyard_crew_semantic_audio() -> void:
	if not is_instance_valid(audio):
		return
	if not is_instance_valid(halyard_crew_semantic_audio_binding):
		halyard_crew_semantic_audio_binding = HalyardCrewSemanticAudioBindingType.new()
		halyard_crew_semantic_audio_binding.name = "HalyardCrewSemanticAudioBinding"
		add_child(halyard_crew_semantic_audio_binding)
	if not bool(halyard_crew_semantic_audio_binding.get_snapshot().get("attached", false)):
		halyard_crew_semantic_audio_binding.attach(
			int(halyard_crew_semantic_audio_binding.get_snapshot().get("generation", 0))
		)
	if not _halyard_crew_semantic_bound and audio.has_method(&"bind_semantic_audio_source"):
		var result := audio.call(
			&"bind_semantic_audio_source", halyard_crew_semantic_audio_binding, &"crew"
		) as Dictionary
		_halyard_crew_semantic_bound = bool(result.get("accepted", false))


func _initialize_optional_semantic_audio() -> void:
	if not is_instance_valid(audio):
		return
	if not is_instance_valid(optional_semantic_audio_composition):
		optional_semantic_audio_composition = OptionalSemanticAudioCompositionType.new()
		optional_semantic_audio_composition.name = "OptionalSemanticAudioComposition"
		add_child(optional_semantic_audio_composition)
	var cinder: Node = active_ship if active_ship is CinderCargoHaulerType else null
	var navigator_generation := _get_cinder_navigator_presentation_generation()
	if not bool(optional_semantic_audio_composition.get_snapshot().get("attached", false)):
		optional_semantic_audio_composition.attach(
			audio, cinder, planetary_cruise_binding, navigator_generation
		)
	else:
		optional_semantic_audio_composition.set_sources(cinder, planetary_cruise_binding)
		optional_semantic_audio_composition.set_navigator_generation(navigator_generation)
	_sync_cinder_navigator_hud_composition(navigator_generation)


func _sync_optional_semantic_audio() -> void:
	if not is_instance_valid(optional_semantic_audio_composition):
		_initialize_optional_semantic_audio()
		return
	if is_instance_valid(audio):
		var cinder: Node = active_ship if active_ship is CinderCargoHaulerType else null
		optional_semantic_audio_composition.set_sources(cinder, planetary_cruise_binding)
		optional_semantic_audio_composition.set_navigator_generation(
			_get_cinder_navigator_presentation_generation()
		)
	_sync_cinder_navigator_hud_composition(
		_get_cinder_navigator_presentation_generation()
	)


func _detach_optional_semantic_audio() -> void:
	if is_instance_valid(optional_semantic_audio_composition):
		optional_semantic_audio_composition.detach()


func _get_cinder_navigator_presentation_generation() -> int:
	if (
		_network_ship_authority_composition == null
		or not is_instance_valid(_network_composition_ship)
		or not _network_composition_ship is CinderCargoHaulerType
	):
		return 0
	return _network_ship_generation


func _sync_cinder_navigator_presentations() -> void:
	var navigator_generation := _get_cinder_navigator_presentation_generation()
	if is_instance_valid(optional_semantic_audio_composition) \
			and bool(optional_semantic_audio_composition.get_snapshot().get("attached", false)):
		optional_semantic_audio_composition.set_navigator_generation(navigator_generation)
	_sync_cinder_navigator_hud_composition(navigator_generation)


func _sync_cinder_navigator_hud_composition(navigator_generation: int) -> void:
	if navigator_generation <= 0 or not is_instance_valid(hud):
		if _cinder_navigator_ping_hud_composition != null:
			_cinder_navigator_ping_hud_composition.detach()
		_cinder_navigator_presentation_ship_generation = 0
		return
	if _cinder_navigator_ping_hud_composition == null:
		_cinder_navigator_ping_hud_composition = (
			CinderNavigatorPingHudCompositionType.new()
		)
	var snapshot: Dictionary = _cinder_navigator_ping_hud_composition.get_snapshot()
	if (
		_cinder_navigator_presentation_ship_generation != navigator_generation
		or not bool(snapshot.get("attached", false))
	):
		var attached: Dictionary = _cinder_navigator_ping_hud_composition.attach(hud)
		_cinder_navigator_presentation_ship_generation = (
			navigator_generation if bool(attached.get("accepted", false)) else 0
		)


func _unbind_cinder_navigator_presentations() -> void:
	if is_instance_valid(optional_semantic_audio_composition) \
			and bool(optional_semantic_audio_composition.get_snapshot().get("attached", false)):
		optional_semantic_audio_composition.set_navigator_generation(0)
	if _cinder_navigator_ping_hud_composition != null:
		_cinder_navigator_ping_hud_composition.detach()
	_cinder_navigator_presentation_ship_generation = 0


func _on_cinder_navigator_ping_result_forwarded(result: Dictionary) -> void:
	_forward_cinder_navigator_presentation(result, false)


func _on_cinder_navigator_ping_tombstones_forwarded(result: Dictionary) -> void:
	_forward_cinder_navigator_presentation(result, true)


func _forward_cinder_navigator_presentation(
	result: Dictionary, tombstone_envelope: bool
	) -> void:
	var navigator_generation := _get_cinder_navigator_presentation_generation()
	if navigator_generation <= 0 \
			or not _cinder_navigator_result_matches_generation(
				result, navigator_generation
			):
		return
	if is_instance_valid(optional_semantic_audio_composition):
		optional_semantic_audio_composition.present_cinder_navigator_bridge_result(result)
	if _cinder_navigator_ping_hud_composition == null \
			or _cinder_navigator_presentation_ship_generation != navigator_generation:
		return
	var identity_receipts: Array[Dictionary] = []
	var wire_receipt := result.get("wire_receipt", {}) as Dictionary
	if not wire_receipt.is_empty():
		identity_receipts.append(wire_receipt)
	if tombstone_envelope:
		for item_variant in result.get("tombstones", []) as Array:
			if item_variant is Dictionary:
				identity_receipts.append(
					((item_variant as Dictionary).get("receipt", {}) as Dictionary)
				)
	var crew_snapshot := _get_cinder_navigator_crew_snapshot(identity_receipts)
	# A ping receipt is never sufficient evidence of passenger occupancy. The
	# HUD receives only the exact retained physical assignment; without it, the
	# presentation fails closed instead of synthesizing a passenger row.
	if crew_snapshot.is_empty():
		return
	if tombstone_envelope:
		_cinder_navigator_ping_hud_composition.apply_tombstones(
			result.get("tombstones", []) as Array, crew_snapshot
		)
	else:
		_cinder_navigator_ping_hud_composition.apply_bridge_result(
			result, crew_snapshot
		)


func _cinder_navigator_result_matches_generation(
	result: Dictionary, navigator_generation: int
	) -> bool:
	var receipt := result.get("wire_receipt", {}) as Dictionary
	if not receipt.is_empty():
		return int(receipt.get("ship_generation", 0)) == navigator_generation
	for item_variant in result.get("tombstones", []) as Array:
		if not item_variant is Dictionary:
			return false
		var tombstone := (item_variant as Dictionary).get("receipt", {}) as Dictionary
		if int(tombstone.get("ship_generation", 0)) != navigator_generation:
			return false
	return true


func _get_cinder_navigator_crew_snapshot(
		expected_receipts: Array[Dictionary] = []
	) -> Dictionary:
	if not is_instance_valid(_network_composition_ship) \
			or not _network_composition_ship is CinderCargoHaulerType \
			or not _network_composition_ship.has_method(&"get_crew_role_authority"):
		return {}
	var authority: Object = _network_composition_ship.call(&"get_crew_role_authority")
	if authority == null or not is_instance_valid(authority) \
			or not authority.has_method(&"get_snapshot"):
		return {}
	for assignment_variant in (authority.call(&"get_snapshot") as Dictionary).get(
		"assignments", []
	) as Array:
		if not assignment_variant is Dictionary:
			continue
		var assignment := assignment_variant as Dictionary
		var avatar_id := StringName(assignment.get("avatar_id", &""))
		if (
			StringName(assignment.get("seat_id", &""))
				!= CinderCargoHaulerType.NAVIGATOR_STATION_SEAT_ID
			or StringName(assignment.get("role", &"")) != &"passenger"
			or StringName(assignment.get("vessel_id", &""))
				!= CinderCargoHaulerType.COMPONENT_ID
			or int(assignment.get("occupant_peer_id", 0)) <= 0
			or int(assignment.get("seat_generation", 0)) <= 0
			or avatar_id.is_empty()
		):
			continue
		# The base row and the overlay must describe the same physical occupant.
		# In particular, an old actor's delayed clear may not decorate a navigator
		# who took the seat after that ping was published.
		var assignment_matches_receipts := true
		for receipt in expected_receipts:
			if int(assignment.get("occupant_peer_id", 0)) \
					!= int(receipt.get("peer_id", 0)) \
					or avatar_id != StringName(receipt.get("avatar_id", &"")) \
					or int(assignment.get("seat_generation", 0)) \
						!= int(receipt.get("seat_generation", 0)):
				assignment_matches_receipts = false
				break
		if not assignment_matches_receipts:
			continue
		return {
			"actor_id": CinderCargoHaulerType.COMPONENT_ID,
			"roles": {
				&"passenger": {
					"occupant": str(avatar_id),
					"available": false,
					"seat_id": CinderCargoHaulerType.NAVIGATOR_STATION_SEAT_ID,
				},
			},
		}.duplicate(true)
	return {}



func _sync_halyard_crew_semantic_audio() -> void:
	if not is_instance_valid(halyard_crew_semantic_audio_binding):
		return
	if not is_instance_valid(active_ship) or active_ship.get_ship_id() != HALYARD_SHIP_ID \
			or not active_ship.has_method(&"get_crew_role_gameplay_snapshot"):
		if bool(halyard_crew_semantic_audio_binding.get_snapshot().get("attached", false)):
			halyard_crew_semantic_audio_binding.detach()
		_last_halyard_crew_event_sequence = -2
		return
	if not bool(halyard_crew_semantic_audio_binding.get_snapshot().get("attached", false)):
		halyard_crew_semantic_audio_binding.attach(
			int(halyard_crew_semantic_audio_binding.get_snapshot().get("generation", 0))
		)
	var snapshot := active_ship.call(&"get_crew_role_gameplay_snapshot") as Dictionary
	var event_sequence := int(snapshot.get("authority_event_sequence", -1))
	if event_sequence == _last_halyard_crew_event_sequence:
		return
	_last_halyard_crew_event_sequence = event_sequence
	halyard_crew_semantic_audio_binding.present_crew_snapshot(snapshot)


func _detach_halyard_crew_semantic_audio() -> void:
	if is_instance_valid(halyard_crew_semantic_audio_binding):
		halyard_crew_semantic_audio_binding.detach()
	if _halyard_crew_semantic_bound and is_instance_valid(audio) \
			and audio.has_method(&"detach_semantic_audio_sources"):
		audio.call(&"detach_semantic_audio_sources")
	_halyard_crew_semantic_bound = false
	_last_halyard_crew_event_sequence = -2


func _initialize_nearby_activity_audio() -> void:
	if not is_instance_valid(music_bed):
		return
	if not is_instance_valid(nearby_activity_audio_binding):
		nearby_activity_audio_binding = NearbySectorActivityAudioBindingType.new()
		nearby_activity_audio_binding.name = "NearbySectorActivityAudioBinding"
		add_child(nearby_activity_audio_binding)
	if not bool(nearby_activity_audio_binding.get_snapshot().get("attached", false)):
		nearby_activity_audio_binding.attach(
			int(nearby_activity_audio_binding.get_snapshot().get("generation", 0))
		)
	if not is_instance_valid(nearby_activity_music_adapter):
		nearby_activity_music_adapter = NearbySectorActivityMusicAdapterType.new()
		nearby_activity_music_adapter.name = "NearbySectorActivityMusicAdapter"
		add_child(nearby_activity_music_adapter)
		nearby_activity_music_adapter.configure(music_bed)
	if not bool(nearby_activity_music_adapter.get_snapshot().get("attached", false)):
		nearby_activity_music_adapter.attach(
			int(nearby_activity_music_adapter.get_snapshot().get("generation", 0))
		)


func _detach_nearby_activity_audio() -> void:
	if is_instance_valid(nearby_activity_audio_binding):
		nearby_activity_audio_binding.detach()
	if is_instance_valid(nearby_activity_music_adapter):
		nearby_activity_music_adapter.detach()


func _sync_nearby_activity_audio(snapshot: Dictionary) -> void:
	_initialize_nearby_activity_audio()
	var normalized := _normalize_nearby_activity_audio_snapshot(snapshot)
	if normalized.is_empty():
		return
	if is_instance_valid(nearby_activity_audio_binding):
		nearby_activity_audio_binding.present_activity_snapshot(normalized)
	if is_instance_valid(nearby_activity_music_adapter):
		nearby_activity_music_adapter.present_activity_snapshot(normalized)


func _normalize_nearby_activity_audio_snapshot(snapshot: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in [
		{"key": &"host", "kind": &"convoy"},
		{"key": &"race", "kind": &"race"},
		{"key": &"patrol", "kind": &"patrol"},
		{"key": &"cargo", "kind": &"cargo"},
		{"key": &"station_defense_state", "kind": &"defense"},
		{"key": &"mining", "kind": &"mining"},
		{"key": &"structure_scan", "kind": &"salvage"},
		{"key": &"beacon_traversal", "kind": &"beacon"},
	]:
		var value: Variant = snapshot.get(candidate.key, {})
		if value is Dictionary:
			if StringName(candidate.kind) == &"convoy":
				var activity: Variant = (value as Dictionary).get("activity", {})
				if activity is Dictionary:
					value = activity
			candidates.append({"value": value, "kind": candidate.kind})
	var fallback: Dictionary = {}
	for candidate: Dictionary in candidates:
		var value := candidate.value as Dictionary
		var raw_state: Variant = value.get("state_id", value.get("state", &"idle"))
		var state: StringName = &""
		if raw_state is StringName or raw_state is String:
			state = StringName(raw_state)
		elif raw_state is int:
			var kind := StringName(candidate.kind)
			if kind == &"cargo":
				state = {
					0: &"idle", 1: &"active", 2: &"completed",
					3: &"failed", 4: &"expired",
				}.get(int(raw_state), &"")
			elif kind == &"beacon":
				state = {
					0: &"idle", 1: &"active", 2: &"completed", 3: &"reset",
				}.get(int(raw_state), &"")
			elif kind == &"mining":
				state = {
					0: &"idle", 1: &"active", 2: &"completed", 3: &"reset",
				}.get(int(raw_state), &"")
		if state in [&"idle", &"selected", &"countdown", &"active", &"complete", &"completed", &"reset", &"failed", &"aborted", &"expired"]:
			if state in [&"idle", &"selected"]:
				if fallback.is_empty():
					fallback = {"candidate": candidate, "state": state}
				continue
			return _build_nearby_activity_audio_snapshot(candidate, value, state, snapshot)
	if fallback.is_empty():
		return {}
	var fallback_candidate := fallback.get("candidate", {}) as Dictionary
	return _build_nearby_activity_audio_snapshot(
		fallback_candidate,
		fallback_candidate.get("value", {}) as Dictionary,
		StringName(fallback.get("state", &"idle")),
		snapshot
	)


func _build_nearby_activity_audio_snapshot(
	candidate: Dictionary, value: Dictionary, state: StringName, source: Dictionary
) -> Dictionary:
	if candidate.is_empty():
		return {}
	if state in [&"idle", &"selected", &"countdown", &"active", &"complete", &"completed", &"reset", &"failed", &"aborted", &"expired"]:
		var activity_kind := StringName(candidate.get("kind", &"patrol"))
		var activity_id := StringName(value.get("activity_id", source.get("activity_id", &"nearby_activity")))
		var generation := int(value.get("generation", value.get("session_generation", 0)))
		var normalized_state: StringName = &"countdown" if state == &"countdown" else (&"active" if state == &"active" else (
			&"complete" if state in [&"complete", &"completed", &"failed", &"aborted", &"expired"] else (
				&"reset" if state == &"reset" else &"idle"
			)
		))
		var terminal_outcome: StringName = &""
		if state != &"reset":
			if activity_kind in [&"mining", &"salvage"]:
				var typed_terminal_outcome: Variant = value.get("terminal_outcome", &"")
				if typed_terminal_outcome is StringName:
					terminal_outcome = typed_terminal_outcome
			elif activity_kind == &"race":
				var failure_reason: Variant = value.get("failure_reason", &"")
				if state == &"aborted":
					terminal_outcome = &"aborted"
				elif state in [&"failed", &"expired"]:
					terminal_outcome = (
						&"timed_out"
						if state == &"expired" or (
							failure_reason is StringName and failure_reason == &"timeout"
						)
						else &"failed"
					)
			elif activity_kind == &"patrol":
				if state == &"failed":
					terminal_outcome = &"failed"
				elif state == &"aborted":
					terminal_outcome = &"aborted"
		var normalized := {
			"generation": maxi(generation, 0),
			"activity_kind": activity_kind,
			"activity_state": normalized_state,
			"activity_id": activity_id,
			"state": normalized_state,
			"progress_unitless": clampf(float(value.get("progress_unitless", 0.0)), 0.0, 1.0),
			"checkpoint_id": StringName(value.get("checkpoint_id", &"")),
			"reward_pending": bool(value.get("reward_pending", false)),
			"reset_serial": maxi(int(value.get("reset_serial", 0)), 0),
			"terminal_outcome": terminal_outcome,
		}.duplicate(true)
		if StringName(candidate.get("kind", &"")) == &"cargo":
			normalized["cargo_outcome"] = (
				&"delivered" if state in [&"complete", &"completed"] else (
					&"failed" if state in [&"failed", &"aborted", &"expired"] else &"active"
				)
			)
			var contract := value.get("contract", {}) as Dictionary
			normalized["activity_id"] = StringName(value.get(
				"contract_id", contract.get("contract_id", &"cinder_platform_supply_run")
			))
			var elapsed: Variant = value.get("elapsed_seconds", null)
			var deadline: Variant = value.get("deadline_seconds", null)
			var remaining: Variant = value.get("deadline_remaining_seconds", null)
			if (elapsed is float or elapsed is int) and is_finite(float(elapsed)) \
					and float(elapsed) >= 0.0 \
					and (deadline is float or deadline is int) and is_finite(float(deadline)) \
					and float(deadline) > 0.0 \
					and (remaining is float or remaining is int) and is_finite(float(remaining)) \
					and float(remaining) >= 0.0 and float(remaining) <= float(deadline):
				normalized["source_time_seconds"] = float(elapsed)
				normalized["deadline_seconds"] = float(deadline)
				normalized["deadline_remaining_seconds"] = float(remaining)
		elif StringName(candidate.get("kind", &"")) == &"beacon":
			var next_index: Variant = value.get("next_beacon_index", null)
			var beacon_count: Variant = value.get("beacon_count", null)
			var reason: Variant = value.get("presentation_reason", &"")
			if next_index is int and beacon_count is int \
					and int(beacon_count) > 0 and int(beacon_count) <= 1024 \
					and int(next_index) >= 0 and int(next_index) <= int(beacon_count) \
					and reason is StringName \
					and reason in [&"", &"out_of_order_beacon", &"outside_beacon"]:
				normalized["next_beacon_index"] = int(next_index)
				normalized["beacon_count"] = int(beacon_count)
				normalized["beacon_interruption_reason"] = reason
		elif StringName(candidate.get("kind", &"")) == &"convoy":
			var has_sample: Variant = value.get("has_entity_sample", null)
			var escort_distance: Variant = value.get("escort_distance", null)
			var proximity_radius: Variant = value.get("escort_proximity_radius", null)
			var within_proximity: Variant = value.get("escort_within_proximity", null)
			var maximum_separation: Variant = value.get("maximum_separation_seconds", null)
			var separation_remaining: Variant = value.get("separation_remaining_seconds", null)
			var elapsed: Variant = value.get("elapsed_seconds", null)
			var convoy_status: Variant = value.get("convoy_status_id", &"active")
			var terminal_reason: Variant = value.get("terminal_reason", &"")
			if has_sample is bool \
					and (escort_distance is float or escort_distance is int) \
					and is_finite(float(escort_distance)) and float(escort_distance) >= -1.0 \
					and (proximity_radius is float or proximity_radius is int) \
					and is_finite(float(proximity_radius)) and float(proximity_radius) > 0.0 \
					and within_proximity is bool \
					and (maximum_separation is float or maximum_separation is int) \
					and is_finite(float(maximum_separation)) and float(maximum_separation) > 0.0 \
					and (separation_remaining is float or separation_remaining is int) \
					and is_finite(float(separation_remaining)) \
					and float(separation_remaining) >= 0.0 \
					and float(separation_remaining) <= float(maximum_separation) \
					and (elapsed is float or elapsed is int) and is_finite(float(elapsed)) \
					and float(elapsed) >= 0.0 and convoy_status is StringName \
					and convoy_status in [&"active", &"destroyed", &"lost"] \
					and terminal_reason is StringName:
				normalized["source_time_seconds"] = float(elapsed)
				normalized["convoy_has_sample"] = has_sample
				normalized["convoy_escort_distance"] = float(escort_distance)
				normalized["convoy_proximity_radius"] = float(proximity_radius)
				normalized["convoy_within_proximity"] = within_proximity
				normalized["convoy_maximum_separation_seconds"] = float(maximum_separation)
				normalized["convoy_separation_remaining_seconds"] = float(separation_remaining)
				normalized["convoy_status"] = convoy_status
				normalized["convoy_terminal_reason"] = terminal_reason
				normalized["convoy_outcome"] = (
					&"arrived" if state in [&"complete", &"completed"] else (
						&"failed" if state in [&"failed", &"aborted", &"expired"] else &"active"
					)
				)
		elif StringName(candidate.get("kind", &"")) == &"mining":
			var elapsed: Variant = value.get("elapsed_seconds", null)
			var duration: Variant = value.get("extraction_seconds", null)
			var reward_requested: Variant = value.get("reward_requested", null)
			if (elapsed is float or elapsed is int) and is_finite(float(elapsed)) \
					and float(elapsed) >= 0.0 \
					and (duration is float or duration is int) and is_finite(float(duration)) \
					and float(duration) > 0.0 and float(duration) <= 86_400.0 \
					and float(elapsed) <= float(duration) and reward_requested is bool:
				normalized["source_time_seconds"] = float(elapsed)
				normalized["mining_elapsed_seconds"] = float(elapsed)
				normalized["mining_extraction_seconds"] = float(duration)
				normalized["reward_pending"] = reward_requested
		return normalized
	return {}


func _on_hud_nearby_activity_intent_requested(intent: Dictionary) -> void:
	var binding := _get_nearby_activity_binding()
	if not is_instance_valid(binding):
		return
	var activity_id := StringName(str(intent.get("activity_id", &"")))
	var action := StringName(str(intent.get("reason", &"")))
	if action in [&"save_progress", &"load_progress"]:
		var persistence_result := _handle_nearby_activity_persistence(binding, action, intent)
		if hud.has_method(&"apply_nearby_activity_persistence_result"):
			hud.call(&"apply_nearby_activity_persistence_result", persistence_result)
		return
	var result: Dictionary
	match action:
		&"selected":
			_sync_nearby_activity_hud()
			return
		&"start_requested":
			result = _start_nearby_activity(binding, activity_id)
		&"reset_requested":
			result = _reset_nearby_activity(binding, activity_id)
		_:
			return
	if bool(result.get("accepted", false)):
		_sync_nearby_activity_hud()


func configure_nearby_activity_persistence(store: RefCounted, slot_id: StringName = &"nearby_activity") -> bool:
	if store == null or slot_id.is_empty():
		return false
	nearby_activity_persistence_store = store
	nearby_activity_persistence_slot = slot_id
	var binding := _get_nearby_activity_binding()
	return is_instance_valid(binding) and bool(binding.call(&"configure_activity_persistence", store, slot_id))


func _handle_nearby_activity_persistence(binding: Node, action: StringName, intent: Dictionary) -> Dictionary:
	if nearby_activity_persistence_store == null:
		return {"accepted": false, "reason": &"persistence_unconfigured", "status": &"unconfigured"}
	if not bool(binding.call(&"configure_activity_persistence", nearby_activity_persistence_store, nearby_activity_persistence_slot)):
		return {"accepted": false, "reason": &"persistence_unconfigured", "status": &"unconfigured"}
	if action == &"load_progress":
		return binding.call(&"load_activity_session")
	var snapshot := binding.call(&"get_snapshot") as Dictionary
	var generation := maxi(int(intent.get("expected_generation", snapshot.get("generation", 0))), 0)
	_nearby_activity_persistence_commit_serial += 1
	var commit_id := "nearby-activity-%010d" % _nearby_activity_persistence_commit_serial
	return binding.call(&"save_activity_session", generation, commit_id)


func _start_nearby_activity(binding: Node, activity_id: StringName) -> Dictionary:
	if activity_id == CINDER_CONVOY_ACTIVITY_ID:
		if _selected_activity_kind != ACTIVITY_KIND_CONVOY_ESCORT:
			var selected := select_activity_kind(ACTIVITY_KIND_CONVOY_ESCORT)
			if not bool(selected.get("accepted", false)):
				return selected
		return request_activity_start(
			CINDER_CONVOY_ACTIVITY_ID,
			active_ship.global_position if is_instance_valid(active_ship) else null
		)
	match activity_id:
		&"cinder_reach_checkpoint_route": return binding.call(&"start_race")
		&"cinder_platform_mining_run": return binding.call(&"start_mining_activity", active_ship.global_position if is_instance_valid(active_ship) else Vector3.ZERO)
		&"cinder_derelict_structure_scan": return binding.call(&"start_structure_scan", active_ship.global_position if is_instance_valid(active_ship) else Vector3.ZERO)
		&"cinder_debris_beacon_traversal": return binding.call(&"start_beacon_traversal", active_ship.global_position if is_instance_valid(active_ship) else Vector3.ZERO)
		&"cinder_platform_supply_run": return binding.call(&"start_cargo_run")
		&"station_defense": return binding.call(&"start_station_defense")
	return {"accepted": false, "reason": &"unknown_activity"}


func _reset_nearby_activity(binding: Node, activity_id: StringName) -> Dictionary:
	if activity_id == CINDER_CONVOY_ACTIVITY_ID:
		var reset := reset_active_activity()
		return {
			"accepted": reset,
			"reason": &"reset" if reset else &"production_convoy_reset_rejected",
			"snapshot": get_active_activity_snapshot(),
		}.duplicate(true)
	match activity_id:
		&"cinder_reach_checkpoint_route": return binding.call(&"reset_race")
		&"cinder_platform_mining_run": return binding.call(&"reset_mining_activity")
		&"cinder_derelict_structure_scan": return binding.call(&"reset_structure_scan")
		&"cinder_debris_beacon_traversal": return binding.call(&"reset_beacon_traversal")
		&"cinder_platform_supply_run": return binding.call(&"reset_cargo_run")
		&"station_defense": return binding.call(&"reset_station_defense")
	return {"accepted": false, "reason": &"unknown_activity"}


func _get_selected_activity_snapshot() -> Dictionary:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return _get_convoy_activity_snapshot()
	if _selected_activity_kind == ACTIVITY_KIND_PATROL:
		return (
			patrol_activity.get_presentation_snapshot()
			if patrol_activity != null
			else {}
		)
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		return (
			cargo_delivery_activity.get_snapshot()
			if cargo_delivery_activity != null
			else {}
		)
	return (
		cinder_race_session.get_presentation_snapshot()
		if cinder_race_session != null
		else {}
	)


func _get_convoy_activity_snapshot() -> Dictionary:
	if not is_instance_valid(cinder_convoy_host):
		return {}
	var snapshot := cinder_convoy_host.get_snapshot()
	var activity := snapshot.get("activity", {}) as Dictionary
	for key: Variant in activity:
		snapshot[key] = activity[key]
	snapshot["running"] = activity.get("state_id", &"") == &"active"
	return snapshot.duplicate(true)


func _get_selected_activity_generation() -> int:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return cinder_convoy_host.get_generation() if is_instance_valid(cinder_convoy_host) else 0
	if _selected_activity_kind == ACTIVITY_KIND_PATROL:
		return patrol_activity.get_generation() if patrol_activity != null else 0
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		return (
			cargo_delivery_activity.get_generation()
			if cargo_delivery_activity != null
			else 0
		)
	return (
		cinder_race_session.get_session_generation()
		if cinder_race_session != null
		else 0
	)


func _decorate_activity_snapshot(source: Dictionary) -> Dictionary:
	var snapshot := source.duplicate(true)
	snapshot["activity_kind"] = _selected_activity_kind
	snapshot["selection_locked"] = _activity_selection_locked
	# Patrol calls its public generation simply `generation`; mirror it into the
	# established production field so consumers can remain kind-agnostic.
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		var state_id := StringName(snapshot.get("state_id", &"idle"))
		snapshot["activity_id"] = CINDER_CONVOY_ACTIVITY_ID
		snapshot["session_generation"] = int(snapshot.get("generation", 0))
		snapshot["activity_generation"] = int(snapshot.get("generation", 0))
		snapshot["race_generation"] = 0
		snapshot["running"] = state_id == &"active"
		snapshot["phase_id"] = (
			&"rendezvous" if state_id == &"idle" else &"escort"
		)
		snapshot["next_checkpoint_index"] = maxi(
			int(snapshot.get("next_leg_index", -1)), 0
		)
		snapshot["checkpoint_count"] = int(snapshot.get("leg_count", 0))
		snapshot["completed_checkpoint_count"] = int(
			snapshot.get("completed_leg_count", 0)
		)
		snapshot["current_time_seconds"] = float(snapshot.get("elapsed_seconds", 0.0))
		snapshot["failure_reason"] = (
			_convoy_terminal_reason
			if not _convoy_terminal_reason.is_empty()
			else StringName(snapshot.get("terminal_reason", &""))
		)
		snapshot["terminal_reason"] = snapshot["failure_reason"]
		snapshot["activation_center"] = _cinder_convoy_activation_center()
		snapshot["activation_radius"] = CINDER_CONVOY_ACTIVATION_RADIUS
		snapshot["escort_lane_offset"] = CINDER_CONVOY_ESCORT_LANE_OFFSET
		snapshot["activation_distance"] = (
			_convoy_last_player_position.distance_to(_cinder_convoy_activation_center())
			if _convoy_has_player_sample else -1.0
		)
		snapshot["stream_instance_id"] = _convoy_stream_instance_id
		snapshot["stream_generation"] = _convoy_stream_generation
	elif _selected_activity_kind == ACTIVITY_KIND_PATROL:
		snapshot["session_generation"] = int(snapshot.get("generation", 0))
		snapshot["race_generation"] = 0
	elif _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		var state := int(snapshot.get("state", CargoDeliveryActivity.State.IDLE))
		var phase_index := int(snapshot.get("next_phase_index", 0))
		snapshot["activity_id"] = CARGO_DELIVERY_ACTIVITY_ID
		snapshot["display_name"] = CARGO_DELIVERY_DISPLAY_NAME
		snapshot["state_id"] = _cargo_delivery_state_id(state)
		snapshot["running"] = state == CargoDeliveryActivity.State.ACTIVE
		snapshot["session_generation"] = int(snapshot.get("generation", 0))
		snapshot["activity_generation"] = int(snapshot.get("generation", 0))
		snapshot["race_generation"] = 0
		snapshot["phase_id"] = _cargo_delivery_phase_id(state, phase_index)
		snapshot["current_time_seconds"] = float(snapshot.get("elapsed_seconds", 0.0))
		snapshot["next_checkpoint_index"] = phase_index
		snapshot["checkpoint_count"] = int(snapshot.get("phase_count", 0))
		snapshot["completed_checkpoint_count"] = phase_index
		snapshot["quantity"] = CARGO_DELIVERY_QUANTITY
		snapshot["item_id"] = CARGO_DELIVERY_ITEM_ID
		snapshot["item_display_name"] = CARGO_DELIVERY_ITEM_DISPLAY_NAME
	return snapshot


func _cinder_convoy_activation_center() -> Vector3:
	if not is_instance_valid(cinder_streaming_bootstrap):
		return CINDER_CONVOY_ACTIVATION_CENTER
	if (
		cinder_streaming_bootstrap.is_queued_for_deletion()
		or not cinder_streaming_bootstrap.is_inside_tree()
	):
		# The authored activation coordinate is local to the streamed Ember root.
		# Detached/queued roots have no current world transform, so observability
		# must publish an explicit unavailable value rather than sampling Godot's
		# invalid identity fallback.
		return Vector3.INF
	return cinder_streaming_bootstrap.global_transform * CINDER_CONVOY_ACTIVATION_CENTER


func _activity_selection_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"activity_id": _get_selected_activity_id(),
		"activity_kind": _selected_activity_kind,
		"selection_locked": _activity_selection_locked,
		"attached": _selected_activity_composition_ready(),
	}.duplicate(true)


func _get_selected_activity_id() -> StringName:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return CINDER_CONVOY_ACTIVITY_ID
	return (
		CARGO_DELIVERY_ACTIVITY_ID
		if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY
		else DEFAULT_FREE_FLIGHT_ACTIVITY_ID
	)


func _selected_activity_composition_ready() -> bool:
	if _selected_activity_kind == ACTIVITY_KIND_CONVOY_ESCORT:
		return (
			is_instance_valid(cinder_convoy_host)
			and cinder_convoy_host.get_parent() == self
			and cinder_convoy_host.transform.is_equal_approx(Transform3D.IDENTITY)
			and bool(cinder_convoy_host.audit().get("valid", false))
		)
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		return _restore_cargo_delivery_bindings()
	return bool(_get_selected_activity_snapshot().get("attached", false))


func _cargo_delivery_state_id(state: int) -> StringName:
	match state:
		CargoDeliveryActivity.State.ACTIVE:
			return &"active"
		CargoDeliveryActivity.State.COMPLETED:
			return &"completed"
		CargoDeliveryActivity.State.FAILED:
			return &"failed"
		CargoDeliveryActivity.State.EXPIRED:
			return &"expired"
		_:
			return &"idle"


func _cargo_delivery_phase_id(state: int, next_phase_index: int) -> StringName:
	if state == CargoDeliveryActivity.State.COMPLETED:
		return &"complete"
	if state == CargoDeliveryActivity.State.FAILED:
		return &"failed"
	if state == CargoDeliveryActivity.State.EXPIRED:
		return &"expired"
	if state != CargoDeliveryActivity.State.ACTIVE:
		return &"idle"
	return &"outbound" if next_phase_index <= 0 else &"return"


func _on_hud_activity_selection_requested(activity_kind: StringName) -> void:
	var result: Dictionary
	var repeat_requested := false
	var selected_state := StringName(
		get_active_activity_snapshot().get("state_id", &"idle")
	)
	if (
		activity_kind == ACTIVITY_KIND_PATROL
		and activity_kind == _selected_activity_kind
		and _activity_selection_locked
		and selected_state in [&"completed", &"failed", &"aborted"]
	):
		repeat_requested = true
		result = request_activity_start(DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
	else:
		result = select_activity_kind(activity_kind)
	if is_instance_valid(hud) and hud.has_method(&"set_activity_selection_state"):
		# The accepted start already committed the active snapshot. Do not feed its
		# `started` lifecycle reason back through the selection-error presenter.
		var status_reason := StringName(
			result.get("reason", &"selection_rejected")
		)
		if repeat_requested and bool(result.get("accepted", false)):
			status_reason = &""
		hud.call(
			&"set_activity_selection_state",
			_selected_activity_kind,
			_activity_selection_locked,
			status_reason
		)


## The pause HUD supplies only a bounded monotonic request serial. This owner
## re-reads the live production gates synchronously and never treats the label or
## button state as authority. Duplicate/replayed signals are silent no-ops.
func _on_hud_planetary_cruise_toggle_requested(request_serial: int) -> void:
	if _planetary_cruise_hud_toggle_active:
		return
	if (
		request_serial < 1
		or request_serial > PLANETARY_CRUISE_MAX_HUD_TOGGLE_SERIAL
		or _last_hud_planetary_cruise_toggle_serial
			>= PLANETARY_CRUISE_MAX_HUD_TOGGLE_SERIAL
		or request_serial != _last_hud_planetary_cruise_toggle_serial + 1
	):
		_sync_planetary_cruise_hud()
		return
	_last_hud_planetary_cruise_toggle_serial = request_serial
	_planetary_cruise_hud_toggle_active = true
	var before := _planetary_cruise_presentation()
	var result: Dictionary
	if bool(before.get("engagement_requested", false)):
		result = disengage_planetary_cruise(true)
	elif (
		before.get("status_id", &"") == &"ready"
		and bool(before.get("toggle_enabled", false))
	):
		result = engage_planetary_cruise()
	else:
		_sync_planetary_cruise_hud()
		if is_instance_valid(hud):
			hud.toast(
				"EMBER CRUISE UNAVAILABLE",
				str(before.get("status_text", "UNAVAILABLE — NOT AVAILABLE")),
				2.4,
			)
		_planetary_cruise_hud_toggle_active = false
		return
	var after := _planetary_cruise_presentation()
	_sync_planetary_cruise_hud()
	if not is_instance_valid(hud):
		_planetary_cruise_hud_toggle_active = false
		return
	if bool(result.get("accepted", false)):
		hud.toast(
			"EMBER CRUISE",
			str(after.get("status_text", "QUEUED")),
			2.4,
		)
	else:
		hud.toast(
			"EMBER CRUISE UNAVAILABLE",
			str(after.get("status_text", before.get("status_text", "UNAVAILABLE — NOT AVAILABLE"))),
			2.4,
		)
	_planetary_cruise_hud_toggle_active = false


## Restores one coherent, controllable on-foot pilot at the deck spawn.
##
## Extracted from the destroyed-craft recovery so the tow tractor's own loss path
## reuses it verbatim instead of re-deriving a second embodiment reset. Every
## caller must have already advanced the transition generation, because
## `force_recovery_to_on_foot()` cancels an in-flight seat transition and emits
## its completion signal deferred; the awaiting coroutine returns on that token.
func _recall_pilot_to_deck() -> void:
	player.set_camera_active(true)
	# Loss can arrive at any await boundary: before boarding starts, while the
	# avatar is interpolating to the seat, while seated, or during exit. The
	# controller owns the embodiment reset so collision/pose/priority are restored
	# atomically instead of teleporting a still-BOARDING body.
	player.force_recovery_to_on_foot(world.get_player_spawn())
	if _boarding_area != null:
		_boarding_area.release_reservation(player)
	_boarding_area = null
	_piloting = false
	_driving = false
	player.set_control_enabled(true)
	hud.set_mode("on-foot")
	hud.set_interaction("", false)
	audio.set_on_foot(true)


func _replenish_destroyed_ship(destroyed_ship: HeroShip) -> void:
	if not is_instance_valid(destroyed_ship):
		return
	var instance_id := destroyed_ship.get_instance_id()
	if _regeneration_pending.has(instance_id):
		return
	# A monotonic deadline continues to age while Main is outside the tree, but
	# recovery is attempted only from `_process()` after Main is safely back
	# inside the tree. A
	# SceneTreeTimer coroutine could resume during the detached interval and call
	# `get_tree()` on null, permanently stranding the pending craft.
	_regeneration_pending[instance_id] = {
		"ship": weakref(destroyed_ship),
		"ready_at_msec": (
			Time.get_ticks_msec() + DESTROYED_SHIP_REGENERATION_DELAY_MSEC
		),
	}


func _update_pending_regeneration(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or _regeneration_pending.is_empty():
		return
	for instance_id_value in _regeneration_pending.keys():
		var instance_id := int(instance_id_value)
		var entry := _regeneration_pending.get(instance_id, {}) as Dictionary
		var ship_reference := entry.get("ship") as WeakRef
		var pending_ship := (
			ship_reference.get_ref() as HeroShip
			if ship_reference != null and is_instance_valid(ship_reference.get_ref())
			else null
		)
		if not is_instance_valid(pending_ship) or not pending_ship.is_destroyed():
			_regeneration_pending.erase(instance_id)
			continue
		var ready_at_msec := int(entry.get("ready_at_msec", 0))
		if Time.get_ticks_msec() < ready_at_msec:
			continue
		if _regeneration_attempts_active.has(instance_id):
			continue
		_regeneration_attempts_active[instance_id] = true
		_attempt_pending_regeneration(instance_id, entry, pending_ship)
		_regeneration_attempts_active.erase(instance_id)


func _attempt_pending_regeneration(
	instance_id: int,
	entry: Dictionary,
	pending_ship: HeroShip
) -> void:
	var berth_id := pending_ship.get_home_berth_id()
	var berth_transform: Transform3D = world.call("get_ship_spawn") as Transform3D
	var has_registered_berth: bool = (
		world.has_method("has_berth")
		and world.call("has_berth", berth_id)
	)
	if has_registered_berth:
		berth_transform = world.call("get_berth_transform", berth_id) as Transform3D

	# Reset rejection must precede every lease mutation and synchronous berth
	# signal. The ship privately retains the accepted transform/currentness proof.
	var preflight := pending_ship.preflight_reset_for_reuse(berth_transform)
	if not bool(preflight.get("accepted", false)):
		_hold_pending_regeneration(instance_id, entry, pending_ship)
		return

	# Acquire and occupy before restoring a visible/collidable hull. Calling the
	# same helper for the legacy unregistered fallback is harmless (it has no
	# physical berth) and removes the old reset-before-reservation split.
	if not _reserve_berth_for_ship(pending_ship, berth_id, true):
		pending_ship.cancel_reset_for_reuse(preflight)
		_hold_pending_regeneration(instance_id, entry, pending_ship)
		return
	if has_registered_berth and not _ship_owns_exact_occupied_berth(pending_ship, berth_id):
		_release_ship_berth(pending_ship)
		pending_ship.cancel_reset_for_reuse(preflight)
		_hold_pending_regeneration(instance_id, entry, pending_ship)
		return
	if not _pending_regeneration_is_current(instance_id, pending_ship):
		_release_ship_berth(pending_ship)
		pending_ship.cancel_reset_for_reuse(preflight)
		return

	_regeneration_lease_guarded_instance_ids[instance_id] = true
	var committed := pending_ship.commit_reset_for_reuse(preflight)
	_regeneration_lease_guarded_instance_ids.erase(instance_id)
	if not bool(committed.get("accepted", false)):
		# Commit revalidates before its first mutation. A red result therefore leaves
		# the destroyed craft intact; release only this attempt's lease and retry.
		_release_ship_berth(pending_ship)
		_hold_pending_regeneration(instance_id, entry, pending_ship)
		return
	# Synchronous reset listeners run before commit returns. Re-prove both the
	# process-owned pending identity and the exact physical lease before claiming
	# success; neither toast nor pending retirement is allowed on a stale result.
	if not _pending_regeneration_entry_matches(instance_id, pending_ship) \
			or (has_registered_berth \
			and not _ship_owns_exact_occupied_berth(pending_ship, berth_id)):
		_release_ship_berth(pending_ship)
		return
	hud.toast(
		"Berth regeneration complete",
		"%s is available again" % pending_ship.get_display_name(),
		2.2
	)
	_regeneration_pending.erase(instance_id)


func _hold_pending_regeneration(
	instance_id: int,
	entry: Dictionary,
	pending_ship: HeroShip
) -> void:
	if not _pending_regeneration_is_current(instance_id, pending_ship):
		return
	hud.toast(
		"Regeneration holding",
		"%s is waiting for its home berth" % pending_ship.get_display_name(),
		2.0
	)
	entry["ready_at_msec"] = Time.get_ticks_msec() + 2000
	_regeneration_pending[instance_id] = entry


func _pending_regeneration_is_current(instance_id: int, pending_ship: HeroShip) -> bool:
	if not is_instance_valid(pending_ship) or not pending_ship.is_destroyed():
		return false
	return _pending_regeneration_entry_matches(instance_id, pending_ship)


func _pending_regeneration_entry_matches(instance_id: int, pending_ship: HeroShip) -> bool:
	var current := _regeneration_pending.get(instance_id, {}) as Dictionary
	var ship_reference := current.get("ship") as WeakRef
	return ship_reference != null \
		and is_instance_valid(ship_reference.get_ref()) \
		and ship_reference.get_ref() == pending_ship


func _ship_owns_exact_occupied_berth(candidate: HeroShip, berth_id: StringName) -> bool:
	var instance_id := candidate.get_instance_id()
	if not _berth_tokens.has(instance_id) \
			or not _reserved_berth_ids.has(instance_id) \
			or StringName(_reserved_berth_ids.get(instance_id, &"")) != berth_id \
			or not world.has_method("get_berth_node"):
		return false
	var berth := world.call("get_berth_node", berth_id) as ShipBerth
	if berth == null:
		return false
	var token := StringName(_berth_tokens.get(instance_id, &""))
	return not token.is_empty() \
		and berth.has_valid_lease(candidate, token, candidate.get_ship_id()) \
		and berth.get_occupant() == candidate


func _can_ship_use_berth(candidate: HeroShip, berth_id: StringName) -> bool:
	if not world.has_method("get_berth_node"):
		return true
	var berth := world.call("get_berth_node", berth_id) as ShipBerth
	if berth == null:
		return true
	return berth.can_accept(candidate.get_ship_definition(), candidate)


func _ensure_landed_berth_occupancy(candidate: HeroShip) -> bool:
	if not is_instance_valid(candidate):
		return false
	# FleetExpansionBerths owns Dock04-06 attachment instead of ShipBerth's
	# lease/token table. A production craft that is still attached under that
	# binding already has the exact occupied landing contract required for a
	# physical pilot-seat exit; forcing it through the legacy berth registry
	# would reject every expansion craft despite its live pad occupancy.
	var expansion_binding: Node = (
		world.call(&"get_fleet_expansion_production_binding") as Node
		if is_instance_valid(world) and world.has_method(&"get_fleet_expansion_production_binding")
		else null
	)
	var expansion_contract := _get_expansion_flyable_contract(candidate, expansion_binding)
	if bool(expansion_contract.get("accepted", false)):
		return bool(expansion_contract.get("valid", false))
	if _occupy_reserved_berth(candidate):
		return true
	var berth_id := _find_active_landing_berth()
	if berth_id.is_empty():
		return false
	return _reserve_berth_for_ship(candidate, berth_id, true)


## Converts the ship's authoritative `landed -> false` transition into a
## one-shot sortie departure. Engine startup alone is intentionally insufficient:
## a physically parked craft continues to own its occupied berth until thrust
## actually clears the docking latch.
func _mark_sortie_departed() -> Dictionary:
	if _sortie_departed_berth or not is_instance_valid(active_ship):
		return {"accepted": false, "status": &"sortie_departure_unavailable"}
	var berth_id := StringName(
		_reserved_berth_ids.get(active_ship.get_instance_id(), &"")
	)
	var berth := (
		world.call(&"get_berth_node", berth_id) as ShipBerth
		if not berth_id.is_empty() and is_instance_valid(world) \
			and world.has_method(&"get_berth_node")
		else null
	)
	var network_release := _release_network_landing_handoff(active_ship, berth)
	_last_network_landing_handoff_result = network_release.duplicate(true)
	if not bool(network_release.get("accepted", false)):
		if is_instance_valid(hud):
			hud.set_objective(
				"Departure coordination interrupted — berth retained; retrying authoritative release"
			)
			hud.toast(
				"Departure coordination retry pending",
				"The physical berth remains occupied until network retirement publishes",
				3.5,
			)
		return network_release
	_release_ship_berth(active_ship)
	_sortie_departed_berth = true
	return {
		"accepted": true,
		"status": &"sortie_departed",
		"network_release": network_release.duplicate(true),
	}


func _reserve_berth_for_ship(candidate: HeroShip, berth_id: StringName, occupy_now: bool) -> bool:
	if not is_instance_valid(candidate):
		return false
	_release_ship_berth(candidate)
	if not world.has_method("get_berth_node"):
		return true
	var berth := world.call("get_berth_node", berth_id) as ShipBerth
	if berth == null:
		return true
	var definition := candidate.get_ship_definition()
	if definition == null:
		return false
	var token := berth.try_reserve(candidate, definition)
	if token.is_empty():
		return false
	_berth_tokens[candidate.get_instance_id()] = token
	_reserved_berth_ids[candidate.get_instance_id()] = berth_id
	if occupy_now and not berth.occupy(candidate, token):
		berth.release(candidate, token)
		_berth_tokens.erase(candidate.get_instance_id())
		_reserved_berth_ids.erase(candidate.get_instance_id())
		return false
	return true


func _occupy_reserved_berth(candidate: HeroShip) -> bool:
	var instance_id := candidate.get_instance_id()
	if not _berth_tokens.has(instance_id) or not _reserved_berth_ids.has(instance_id):
		return false
	var berth := world.call("get_berth_node", _reserved_berth_ids[instance_id]) as ShipBerth
	return berth != null and berth.occupy(candidate, _berth_tokens[instance_id])


func _release_ship_berth(candidate: HeroShip) -> void:
	if not is_instance_valid(candidate):
		return
	var instance_id := candidate.get_instance_id()
	if _regeneration_lease_guarded_instance_ids.has(instance_id):
		return
	if not _berth_tokens.has(instance_id) or not _reserved_berth_ids.has(instance_id):
		return
	if world.has_method("get_berth_node"):
		var berth := world.call("get_berth_node", _reserved_berth_ids[instance_id]) as ShipBerth
		if berth != null:
			var token := StringName(_berth_tokens[instance_id])
			# HeroShip's landing abort/destruction lifecycle may have already
			# released this exact lease before its synchronous signal reaches us.
			# Retire GameFlow bookkeeping without issuing a duplicate mutation.
			if berth.has_valid_lease(candidate, token, candidate.get_ship_id()):
				berth.release(candidate, token)
	_berth_tokens.erase(instance_id)
	_reserved_berth_ids.erase(instance_id)


func get_runtime_settings() -> RuntimeSettings:
	return runtime_settings


## Installs an injected atomic store before startup. Production never calls this
## and therefore uses RuntimeSettingsStoreAdapter.DEFAULT_STORE_PATH; focused
## tests use it to keep every byte in an in-memory filesystem. Once settings
## construction or loading has begun, changing persistence authority is refused.
func configure_runtime_settings_persistence(
	store: UserDataStore,
	legacy_path: String = ""
	) -> bool:
	if (
		store == null
		or runtime_settings != null
		or _runtime_settings_store_adapter != null
		or _runtime_settings_load_attempted
		or _initialized
	):
		return false
	_runtime_settings_persistence_injected = true
	_runtime_settings_user_data_store = store
	if not legacy_path.strip_edges().is_empty():
		_runtime_settings_legacy_path = legacy_path
	return true


## Detached persistence diagnostics. Nested adapter/store dictionaries are deep
## copies; callers receive no live settings, adapter, store or filesystem object.
func get_runtime_settings_persistence_report() -> Dictionary:
	return {
		"schema_version": 1,
		"store_count": 1 if _runtime_settings_user_data_store != null else 0,
		"adapter_count": 1 if _runtime_settings_store_adapter != null else 0,
		"store_instance_id": (
			_runtime_settings_user_data_store.get_instance_id()
			if _runtime_settings_user_data_store != null else 0
		),
		"adapter_instance_id": (
			_runtime_settings_store_adapter.get_instance_id()
			if _runtime_settings_store_adapter != null else 0
		),
		"identity_scope": (
			&"injected_main_lifetime"
			if _runtime_settings_persistence_injected
			else &"process_lifetime"
		),
		"injected_authority": _runtime_settings_persistence_injected,
		"load_attempted": _runtime_settings_load_attempted,
		"load_attempt_count": _runtime_settings_load_attempt_count,
		"load_status": _runtime_settings_load_status.duplicate(true),
		"save_attempt_count": _runtime_settings_save_attempt_count,
		"save_success_count": _runtime_settings_save_success_count,
		"last_save_status": _runtime_settings_last_save_status.duplicate(true),
		"accepted_transaction_count": _runtime_settings_transaction_count,
		"commit_serial": _runtime_settings_commit_serial,
		"last_commit_id": _runtime_settings_last_commit_id,
		"unsaved_changes": _runtime_settings_unsaved_changes,
		"transaction_active": _runtime_settings_transaction_active,
		"reentrant_rejection_count": _runtime_settings_reentrant_rejection_count,
		"apply_count": _runtime_settings_apply_count,
		"first_apply_followed_load": _runtime_settings_first_apply_followed_load,
		"load_before_first_apply": _runtime_settings_first_apply_followed_load,
		"commit_clock": &"bounded_monotonic_counter",
		"wall_clock_used": false,
		"automatic_repair_policy": false,
		"delete_policy": false,
		"os_crash_hook": false,
	}.duplicate(true)


## Explicit caller-owned repair seam. Inspection never mutates settings or
## bytes; callers must present the returned confirmation to prepare and commit.
## The optional argument remains for source compatibility, but is deliberately
## not an authority: only this GameFlow's retained startup receipt may make a
## repair eligible for the currently attached adapter/store generation.
func inspect_runtime_settings_repair(_load_status: Dictionary = {}) -> Dictionary:
	_ensure_runtime_settings_repair_binding()
	if _runtime_settings_repair_binding == null:
		return {"accepted": false, "reason": &"repair_unavailable"}
	if not _runtime_settings_load_attempted or _runtime_settings_load_status.is_empty():
		return {"accepted": false, "reason": &"startup_load_unavailable"}
	return _runtime_settings_repair_binding.inspect(
		_runtime_settings_load_status.duplicate(true)
	)


func prepare_runtime_settings_repair(confirmation: String, commit_id: String) -> Dictionary:
	_ensure_runtime_settings_repair_binding()
	if _runtime_settings_repair_binding == null:
		return {"accepted": false, "reason": &"repair_unavailable"}
	return _runtime_settings_repair_binding.prepare(confirmation, commit_id)


func commit_runtime_settings_repair(confirmation: String) -> Dictionary:
	_ensure_runtime_settings_repair_binding()
	if _runtime_settings_repair_binding == null:
		return {"accepted": false, "reason": &"repair_unavailable"}
	return _runtime_settings_repair_binding.commit(confirmation)


func get_runtime_settings_repair_report() -> Dictionary:
	return _runtime_settings_repair_binding.get_report() if _runtime_settings_repair_binding != null else {
		"attached": false,
		"reason": &"repair_unavailable",
	}.duplicate(true)


func _connect_runtime_settings_repair_hud() -> void:
	_connect_signal_once(
		hud,
		&"settings_repair_confirmation_requested",
		_on_settings_repair_confirmation_requested
	)


## Publishes only the result of this owner's authentic retained-startup
## inspection. Normal primary loads keep the conditional HUD surface clear;
## repairable and fail-closed recovery states remain explicit.
func _publish_runtime_settings_repair_to_hud() -> Dictionary:
	if not is_instance_valid(hud):
		return {"accepted": false, "reason": &"hud_unavailable"}
	if _runtime_settings_repair_resolved:
		if hud.has_method(&"clear_runtime_settings_repair_report"):
			hud.clear_runtime_settings_repair_report()
		return {"accepted": false, "reason": &"repair_resolved"}
	var inspected := inspect_runtime_settings_repair()
	var reason := StringName(inspected.get("reason", &""))
	if bool(inspected.get("accepted", false)) or reason in [
		&"unsupported_newer_schema", &"load_not_repairable",
		&"settings_payload_missing", &"stale_load_generation",
	]:
		if hud.has_method(&"present_runtime_settings_repair_report"):
			hud.present_runtime_settings_repair_report(
				get_runtime_settings_repair_report()
			)
		return inspected.duplicate(true)
	if hud.has_method(&"clear_runtime_settings_repair_report"):
		hud.clear_runtime_settings_repair_report()
	return inspected.duplicate(true)


## Sole mutation ingress for the HUD confirmation. GameFlow owns the bounded
## commit ID and calls the existing binding's prepare/commit fence; the HUD owns
## neither persistence nor an inference that the request succeeded.
func _on_settings_repair_confirmation_requested(confirmation: String) -> void:
	if _runtime_settings_repair_request_active:
		_present_runtime_settings_repair_result({
			"accepted": false,
			"reason": &"repair_request_active",
		})
		return
	if (
		confirmation.is_empty()
		or _runtime_settings_user_data_store == null
		or _runtime_settings_repair_binding == null
	):
		_present_runtime_settings_repair_result({
			"accepted": false,
			"reason": &"repair_unavailable",
		})
		return
	var next_generation := _runtime_settings_user_data_store.get_generation() + 1
	if next_generation <= 0 or next_generation > UserDataStoreType.MAX_GENERATION:
		if is_instance_valid(hud):
			if hud.has_method(&"clear_runtime_settings_repair_report"):
				hud.clear_runtime_settings_repair_report()
			if hud.has_method(&"set_settings_status"):
				hud.set_settings_status("BACKUP REPAIR FAILED  //  COMMIT ID EXHAUSTED", false)
		return
	var commit_id := "%s%010d" % [
		RUNTIME_SETTINGS_REPAIR_COMMIT_PREFIX,
		next_generation,
	]
	_runtime_settings_repair_request_active = true
	var prepared := prepare_runtime_settings_repair(confirmation, commit_id)
	if not bool(prepared.get("accepted", false)):
		_runtime_settings_repair_request_active = false
		_present_runtime_settings_repair_result(prepared)
		return
	var committed := commit_runtime_settings_repair(confirmation)
	_runtime_settings_repair_request_active = false
	if (
		bool(committed.get("accepted", false))
		and committed.get("reason", &"") == &"repair_committed"
	):
		_runtime_settings_repair_resolved = true
		_runtime_settings_commit_serial = maxi(
			_runtime_settings_commit_serial,
			_runtime_settings_user_data_store.get_generation()
		)
		_sync_production_runtime_settings_state()
	_present_runtime_settings_repair_result(committed)


func _present_runtime_settings_repair_result(result: Dictionary) -> void:
	if not is_instance_valid(hud):
		return
	var accepted: bool = bool(result.get("accepted", false)) \
		and result.get("reason", &"") == &"repair_committed"
	if accepted:
		if hud.has_method(&"clear_runtime_settings_repair_report"):
			hud.clear_runtime_settings_repair_report()
		if hud.has_method(&"set_settings_status"):
			hud.set_settings_status("SETTINGS BACKUP REPAIRED", true)
		return
	if hud.has_method(&"present_runtime_settings_repair_report"):
		hud.present_runtime_settings_repair_report(get_runtime_settings_repair_report())
	if hud.has_method(&"set_settings_status"):
		hud.set_settings_status(
			"BACKUP REPAIR FAILED  //  %s"
			% str(result.get("reason", &"unknown")).to_upper(),
			false
		)


## Detached diagnostics for the process startup marker and caller-owned
## stability window. No live policy, store, settings, or filesystem object is
## exposed. In particular, a scene-tree detach is not represented as shutdown.
func get_safe_start_recovery_report() -> Dictionary:
	return (
		_safe_start_production_recovery.get_report()
		if _safe_start_production_recovery != null else {}
	)


func get_safe_start_recovery_hud_status() -> Dictionary:
	return _safe_start_recovery_hud_status.duplicate(true)


func _handle_safe_start_recovery_intent(payload: Dictionary) -> Dictionary:
	var action_value: Variant = payload.get("action")
	var generation_value: Variant = payload.get("generation")
	var revision_value: Variant = payload.get("revision")
	if (
		not (action_value is String or action_value is StringName)
		or generation_value is not int
		or revision_value is not int
		or payload.get("presentation_only") != true
		or payload.get("settings_authority") != false
		or payload.get("filesystem_authority") != false
	):
		return _record_safe_start_recovery_hud_status(
			false, &"invalid_recovery_intent", &"invalid", -1, -1, {}
		)
	var action := StringName(str(action_value))
	var generation := generation_value as int
	var revision := revision_value as int
	if action not in [&"restore", &"keep_safe"]:
		return _record_safe_start_recovery_hud_status(
			false, &"action_unavailable", action, generation, revision, {}
		)
	if _safe_start_production_recovery == null:
		return _record_safe_start_recovery_hud_status(
			false, &"policy_unavailable", action, generation, revision, {}
		)
	var report := _safe_start_production_recovery.get_report() as Dictionary
	var cursor := _safe_start_recovery_report_cursor(report)
	if (
		not bool(cursor.get("accepted", false))
		or generation != int(cursor.get("generation", -1))
		or revision != int(cursor.get("revision", -1))
		or generation == _safe_start_recovery_dismissed_generation
	):
		return _record_safe_start_recovery_hud_status(
			false, &"stale_recovery_fence", action, generation, revision, {}
		)
	if action == &"keep_safe":
		_safe_start_recovery_dismissed_generation = generation
		if is_instance_valid(hud) and hud.has_method(&"clear_safe_start_recovery_status"):
			hud.call(&"clear_safe_start_recovery_status")
		return _record_safe_start_recovery_hud_status(
			true,
			&"keep_safe_dismissed",
			action,
			generation,
			revision,
			{
				"presentation_only": true,
				"settings_authority": false,
				"filesystem_authority": false,
			}
		)
	var domain_results := {}
	var attempted_domains: PackedStringArray = []
	var readiness := report.get("restore_readiness_snapshot", {}) as Dictionary
	var graphics := readiness.get("graphics", {}) as Dictionary
	if bool(graphics.get("restore_ready", false)):
		attempted_domains.append("graphics")
		domain_results["graphics"] = (
			_safe_start_production_recovery.restore_prior_graphics_profile(
				Callable(self, &"_persist_runtime_settings")
			) as Dictionary
		).duplicate(true)
	# The first persistence transaction advances report/store generations. Re-read
	# authoritative readiness before attempting the independent audio receipt.
	report = _safe_start_production_recovery.get_report()
	readiness = report.get("restore_readiness_snapshot", {}) as Dictionary
	var audio := readiness.get("audio", {}) as Dictionary
	if bool(audio.get("restore_ready", false)):
		attempted_domains.append("audio")
		domain_results["audio"] = (
			_safe_start_production_recovery.restore_prior_audio_profile(
				Callable(self, &"_persist_runtime_settings")
			) as Dictionary
		).duplicate(true)
	if attempted_domains.is_empty():
		_publish_safe_start_recovery_status_to_hud(true, true)
		return _record_safe_start_recovery_hud_status(
			false, &"restore_unavailable", action, generation, revision, {}
		)
	var all_accepted := true
	for domain: String in attempted_domains:
		all_accepted = all_accepted and bool(
			(domain_results.get(domain, {}) as Dictionary).get("accepted", false)
		)
	_sync_production_runtime_settings_state()
	var publication := _publish_safe_start_recovery_status_to_hud(true, true)
	return _record_safe_start_recovery_hud_status(
		all_accepted,
		&"restore_completed" if all_accepted else &"restore_partially_completed",
		action,
		generation,
		revision,
		{
			"attempted_domains": attempted_domains,
			"domain_results": domain_results,
			"publication": publication,
		}
	)


func _record_safe_start_recovery_hud_status(
		accepted: bool,
		reason: StringName,
		action: StringName,
		generation: int,
		revision: int,
		details: Dictionary
		) -> Dictionary:
	_safe_start_recovery_hud_status = {
		"accepted": accepted,
		"reason": reason,
		"action": action,
		"generation": generation,
		"revision": revision,
		"details": details.duplicate(true),
		"automatic_action": false,
		"presentation_only": action == &"keep_safe" or action == &"publish",
	}.duplicate(true)
	return _safe_start_recovery_hud_status.duplicate(true)


## Explicit application-owned orderly-shutdown seam. Both retained marker
## owners receive the same caller-confirmed close intent, and one failed write
## never suppresses the other attempt. `_exit_tree()`, free, and whole-Main
## streaming never call this method because none of them proves an OS process
## shutdown.
func mark_orderly_shutdown() -> Dictionary:
	var race_session_status := save_cinder_race_session()
	var patrol_session_status := save_cinder_patrol_session()
	var safe_start_status := (
		_safe_start_production_recovery.mark_orderly_shutdown()
		if _safe_start_production_recovery != null
		else {"accepted": false, "reason": &"policy_unavailable"}
	) as Dictionary
	var session_diagnostics_status := mark_orderly_session_shutdown()
	_sync_production_runtime_settings_state()
	var safe_start_accepted := bool(safe_start_status.get("accepted", false))
	var session_diagnostics_accepted := bool(
		session_diagnostics_status.get("accepted", false)
	)
	var reason := &"orderly_shutdown_failed"
	if safe_start_accepted and session_diagnostics_accepted:
		reason = &"orderly_shutdown"
	elif safe_start_accepted or session_diagnostics_accepted:
		reason = &"orderly_shutdown_partial_failure"
	return {
		"accepted": safe_start_accepted and session_diagnostics_accepted,
		"reason": reason,
		"safe_start": safe_start_status.duplicate(true),
		"session_diagnostics": session_diagnostics_status.duplicate(true),
		"cinder_race_session": race_session_status.duplicate(true),
		"cinder_patrol_session": patrol_session_status.duplicate(true),
	}.duplicate(true)


## The HUD has no persistence or process-lifecycle authority. Its explicit exit
## intent reaches this owner first, then the tree exits even if the best-effort
## clean marker cannot be written (for example, a failing filesystem).
func _on_orderly_shutdown_requested() -> void:
	mark_orderly_shutdown()
	if is_inside_tree():
		get_tree().quit()


## The only public caption payload: the service's detached, validated consumer
## snapshot. Neither the service nor typed event objects escape GameFlow.
func get_caption_presentation_snapshot() -> Dictionary:
	return (
		_caption_presentation_service.get_presentation_snapshot()
		if _caption_presentation_service != null
		else {}
	)


func get_caption_integration_report() -> Dictionary:
	var service_state := (
		_caption_presentation_service.get_state_snapshot()
		if _caption_presentation_service != null
		else {}
	)
	var hud_report := (
		hud.call(&"get_caption_presentation_report")
		if is_instance_valid(hud) and hud.has_method(&"get_caption_presentation_report")
		else {}
	) as Dictionary
	return {
		"schema_version": 1,
		"service_count": 1 if _caption_presentation_service != null else 0,
		"service_instance_id": _caption_presentation_service.get_instance_id() if _caption_presentation_service != null else 0,
		"service_generation": int(service_state.get("generation", 0)),
		"service_revision": int(service_state.get("revision", 0)),
		"stored_caption_count": int(service_state.get("stored_caption_count", 0)),
		"caption_request_count": _caption_request_count,
		"caption_accepted_count": _caption_accepted_count,
		"caption_rejected_count": _caption_rejected_count,
		"presenter_count": int(hud_report.get("component_id", &"") == CaptionPresenter.COMPONENT_ID),
		"presenter_instance_id": int(hud_report.get("presenter_instance_id", 0)),
		"hud_request_sink_bound": bool(hud_report.get("request_sink_bound", false)),
		"physics_time_owner": &"game_flow",
		"snapshot_boundary": &"validated_presentation_dictionary_only",
		"legacy_hud_history": false,
		"presentation_only": true,
		"gameplay_authority": false,
		"reward_authority": false,
		"audio_authority": false,
		"activity_authority": false,
		"ship_authority": false,
		"berth_authority": false,
	}.duplicate(true)


func get_flyable_ships() -> Array[HeroShip]:
	return ships.duplicate()


func get_active_ship() -> HeroShip:
	return active_ship


## Explicit production request seam for the canonical Ember navigation anchor.
## The pause HUD can request it, but this method rechecks all production gates;
## neither the HUD nor its displayed state is authoritative.
func engage_planetary_cruise() -> Dictionary:
	if not is_instance_valid(planetary_cruise_binding):
		_sync_planetary_cruise_hud()
		return {"accepted": false, "reason": &"binding_unavailable"}
	var frame_generation := 0
	if is_instance_valid(ember_streaming_bootstrap):
		var frame := ember_streaming_bootstrap.get_coordinate_frame_for_session()
		if frame != null:
			frame_generation = frame.get_generation()
	var result := planetary_cruise_binding.request_engage(
		active_ship,
		frame_generation,
		_planetary_cruise_gate_reason(),
		planetary_cruise_binding.get_generation(),
	)
	_sync_planetary_cruise_hud()
	return result


func disengage_planetary_cruise(brake_to_stop: bool = true) -> Dictionary:
	if not is_instance_valid(planetary_cruise_binding):
		_sync_planetary_cruise_hud()
		return {"accepted": false, "reason": &"binding_unavailable"}
	var result := planetary_cruise_binding.request_disengage(
		planetary_cruise_binding.get_generation(),
		brake_to_stop,
	)
	_sync_planetary_cruise_hud()
	return result


## Maps only the finite public gate vocabulary to bounded player copy. Internal
## generation, proof, controller, and transaction errors remain diagnostics.
func _planetary_cruise_public_gate_copy(reason: StringName) -> String:
	match reason:
		&"main_unavailable", &"binding_unavailable":
			return "SYSTEM OFFLINE"
		&"active_ship_unavailable":
			return "NO ACTIVE SHIP"
		&"ship_destroyed":
			return "SHIP DESTROYED"
		&"pilot_unseated":
			return "PILOT REQUIRED"
		&"landing_active":
			return "LANDING ACTIVE"
		&"combat_active":
			return "COMBAT ACTIVE"
		&"ship_recovery":
			return "SHIP RECOVERY"
		&"free_flight_unavailable":
			return "DEPART SHIPYARD"
		&"activity_running":
			return "ACTIVITY RUNNING"
		&"coordinate_frame_unavailable":
			return "NAVIGATION OFFLINE"
		&"origin_rebase_pending":
			return "ORIGIN SHIFT PENDING"
		_:
			return "NOT AVAILABLE"


func _planetary_cruise_presentation() -> Dictionary:
	var binding_snapshot: Dictionary = {}
	if is_instance_valid(planetary_cruise_binding):
		binding_snapshot = planetary_cruise_binding.get_snapshot().duplicate(true)
	var ship_report: Dictionary = {}
	if is_instance_valid(active_ship):
		ship_report = active_ship.get_planetary_cruise_attachment_report().duplicate(true)
	var engagement_requested := bool(
		binding_snapshot.get("engagement_requested", false)
	)
	var ship_state := StringName(
		ship_report.get("state", HeroShip.PLANETARY_CRUISE_STATE_INACTIVE)
	)
	var status_id: StringName
	var status_text: String
	var toggle_enabled := false
	var public_gate := &""
	match ship_state:
		HeroShip.PLANETARY_CRUISE_STATE_ACCELERATING:
			status_id = &"accelerating"
			status_text = "ACCELERATING"
			toggle_enabled = engagement_requested
		HeroShip.PLANETARY_CRUISE_STATE_CRUISING:
			status_id = &"cruising"
			status_text = "CRUISING"
			toggle_enabled = engagement_requested
		HeroShip.PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED:
			status_id = &"braking_to_speed"
			status_text = "BRAKING TO SPEED"
			toggle_enabled = engagement_requested
		HeroShip.PLANETARY_CRUISE_STATE_BRAKING:
			status_id = &"braking"
			status_text = "BRAKING"
		_:
			if engagement_requested:
				status_id = &"queued"
				status_text = "QUEUED"
				toggle_enabled = true
			else:
				var gate_reason := (
					_planetary_cruise_gate_reason()
					if is_instance_valid(planetary_cruise_binding)
					else &"binding_unavailable"
				)
				if gate_reason.is_empty():
					status_id = &"ready"
					status_text = "READY — EMBER MOON"
					toggle_enabled = true
				else:
					status_id = &"unavailable"
					public_gate = gate_reason
					status_text = "UNAVAILABLE — %s" % (
						_planetary_cruise_public_gate_copy(gate_reason)
					)
	return {
		"status_id": status_id,
		"status_text": status_text,
		"toggle_enabled": toggle_enabled,
		"engagement_requested": engagement_requested,
		"public_gate": public_gate,
	}.duplicate(true)


func _sync_planetary_cruise_hud() -> void:
	if (
		not is_instance_valid(hud)
		or not hud.has_method(&"set_planetary_cruise_state")
	):
		return
	var presentation := _planetary_cruise_presentation()
	if _final_approach_hud_composition != null:
		var final_controls := _final_approach_hud_composition.set_cruise_controls(
			bool(presentation.get("toggle_enabled", false)),
			bool(presentation.get("engagement_requested", false)),
		)
		var final_snapshot := _final_approach_hud_composition.get_snapshot()
		var final_adapter := final_snapshot.get("adapter", {}) as Dictionary
		var final_view := final_adapter.get("source_view", {}) as Dictionary
		var final_state := StringName(final_view.get("state", &""))
		if bool(final_controls.get("accepted", false)) and final_state in [
			&"armed", &"approaching", &"aligned", &"handoff", &"rejected"
		]:
			return
	hud.call(
		&"set_planetary_cruise_state",
		StringName(presentation.get("status_id", &"unavailable")),
		str(presentation.get("status_text", "UNAVAILABLE — SYSTEM OFFLINE")),
		bool(presentation.get("toggle_enabled", false)),
		bool(presentation.get("engagement_requested", false)),
	)


func _sync_cinder_loadmaster_hud_binding() -> void:
	var candidate := active_ship as CinderCargoHauler
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not is_instance_valid(hud)
	):
		_detach_cinder_loadmaster_hud_binding()
		return
	if (
		_cinder_loadmaster_hud_binding != null
		and _cinder_loadmaster_hud_craft == candidate
		and _cinder_loadmaster_hud_binding.is_attached()
	):
		return
	_detach_cinder_loadmaster_hud_binding()
	var binding := CinderLoadmasterHudBindingType.new()
	var result := binding.attach(candidate, hud, &"loadmaster")
	if bool(result.get("accepted", false)):
		_cinder_loadmaster_hud_binding = binding
		_cinder_loadmaster_hud_craft = candidate


func _detach_cinder_loadmaster_hud_binding() -> void:
	if _cinder_loadmaster_hud_binding != null:
		_cinder_loadmaster_hud_binding.detach()
	_cinder_loadmaster_hud_binding = null
	_cinder_loadmaster_hud_craft = null


func _ensure_final_approach_hud_composition() -> void:
	if (
		_final_approach_hud_composition != null
		and bool(_final_approach_hud_composition.get_snapshot().get("attached", false))
	):
		return
	if not is_instance_valid(planetary_cruise_binding) or not (hud is GameHUD):
		return
	if _final_approach_hud_composition != null:
		_final_approach_hud_composition.detach()
	var presentation := _planetary_cruise_presentation()
	var composition := FinalApproachHudCompositionType.new()
	var result := composition.attach(
		planetary_cruise_binding,
		hud as GameHUD,
		bool(presentation.get("toggle_enabled", false)),
		bool(presentation.get("engagement_requested", false)),
		bool(runtime_settings.reduced_motion) if runtime_settings != null else false,
	)
	if bool(result.get("accepted", false)):
		_final_approach_hud_composition = composition


func _detach_final_approach_hud_composition() -> void:
	if _final_approach_hud_composition != null:
		_final_approach_hud_composition.detach()
	_final_approach_hud_composition = null


## Attaches presentation only after the asynchronous production Host and its
## early/late binding are the live configured pair. Repeated physics calls are
## deliberately idempotent: one AudioDirector registration and one HUD signal
## path observe the retained owner, while ordinary surface-route presentation
## remains an external HUD producer.
func _ensure_ember_surface_presentations() -> Dictionary:
	if not is_instance_valid(ember_surface_loop_host) \
			or not is_instance_valid(ember_surface_loop_production_binding) \
			or not is_instance_valid(audio) \
			or not (hud is GameHUD):
		return {"accepted": false, "reason": &"ember_presentation_dependencies_missing"}
	var host_snapshot := ember_surface_loop_host.get_snapshot()
	var production_snapshot := ember_surface_loop_production_binding.get_snapshot()
	if not bool(host_snapshot.get("attached", false)) \
			or not bool(production_snapshot.get("configured", false)):
		return {"accepted": false, "reason": &"ember_production_not_bound"}

	if not is_instance_valid(_ember_surface_loop_audio_composition):
		_ember_surface_loop_audio_composition = EmberSurfaceLoopAudioCompositionType.new()
		_ember_surface_loop_audio_composition.name = "EmberSurfaceLoopAudioComposition"
		add_child(_ember_surface_loop_audio_composition)
	var audio_was_attached := bool(
		(_ember_surface_loop_audio_composition.call(&"get_snapshot") as Dictionary).get(
			"attached", false
		)
	)
	if not audio_was_attached:
		var entry_audio_perspective: StringName = &"interior" \
			if is_instance_valid(active_ship) \
				and active_ship.get_camera_view() == &"COCKPIT" else &"exterior"
		var audio_result := _ember_surface_loop_audio_composition.call(
			&"attach", audio, ember_surface_loop_production_binding,
			entry_audio_perspective
		) as Dictionary
		if not bool(audio_result.get("accepted", false)):
			return audio_result

	if _ember_surface_return_status_binding == null:
		_ember_surface_return_status_binding = EmberSurfaceReturnStatusBindingType.new()
	if _ember_surface_return_hud_adapter == null:
		_ember_surface_return_hud_adapter = EmberSurfaceReturnHudAdapterType.new()
	var status_attached := bool(
		(_ember_surface_return_status_binding.call(&"get_snapshot") as Dictionary).get(
			"attached", false
		)
	)
	var hud_attached := bool(
		(_ember_surface_return_hud_adapter.call(&"get_snapshot") as Dictionary).get(
			"attached", false
		)
	)
	if status_attached and hud_attached:
		return {
			"accepted": true,
			"reason": &"already_attached",
			"presentation_only": true,
		}.duplicate(true)
	if status_attached or hud_attached:
		_ember_surface_return_hud_adapter.call(&"detach")
		_ember_surface_return_status_binding.call(&"detach")
	var reduced_motion := bool(runtime_settings.reduced_motion) \
		if runtime_settings != null else false
	var status_result := _ember_surface_return_status_binding.call(
		&"attach", ember_surface_loop_production_binding,
		ember_surface_loop_host, null, reduced_motion
	) as Dictionary
	if not bool(status_result.get("accepted", false)):
		if not audio_was_attached:
			_ember_surface_loop_audio_composition.call(&"detach")
		return status_result
	var hud_result := _ember_surface_return_hud_adapter.call(
		&"attach", _ember_surface_return_status_binding, hud,
		ember_surface_loop_production_binding
	) as Dictionary
	if not bool(hud_result.get("accepted", false)):
		_ember_surface_return_status_binding.call(&"detach")
		if not audio_was_attached:
			_ember_surface_loop_audio_composition.call(&"detach")
		return hud_result
	return {
		"accepted": true,
		"reason": &"attached",
		"presentation_only": true,
		"host_authority": false,
		"session_authority": false,
		"movement_authority": false,
		"reward_authority": false,
		"audio_playback_authority": false,
	}.duplicate(true)


func _detach_ember_surface_presentations() -> void:
	if _ember_surface_return_hud_adapter != null:
		_ember_surface_return_hud_adapter.call(&"detach")
	if _ember_surface_return_status_binding != null:
		_ember_surface_return_status_binding.call(&"detach")
	if is_instance_valid(_ember_surface_loop_audio_composition):
		_ember_surface_loop_audio_composition.call(&"detach")


func get_planetary_cruise_report() -> Dictionary:
	if not is_instance_valid(planetary_cruise_binding):
		return {
			"available": false,
			"reason": &"binding_unavailable",
			"presentation": _planetary_cruise_presentation(),
		}.duplicate(true)
	var ship_report: Dictionary = {}
	if is_instance_valid(active_ship):
		ship_report = active_ship.get_planetary_cruise_attachment_report().duplicate(true)
	return {
		"available": true,
		"gate_reason": _planetary_cruise_gate_reason(),
		"combat_active": _planetary_cruise_combat_active(),
		"caller_tick": _planetary_cruise_caller_tick,
		"last_hud_toggle_serial": _last_hud_planetary_cruise_toggle_serial,
		"binding": planetary_cruise_binding.get_snapshot().duplicate(true),
		"ship": ship_report,
		"presentation": _planetary_cruise_presentation(),
	}.duplicate(true)


## The station's drivable ground vehicle. Deliberately not part of
## `get_flyable_ships()`: it holds no berth, lease, landing or combat authority.
func get_tow_tractor() -> TowTractor:
	return tow_tractor


func is_driving_tow_tractor() -> bool:
	return _driving


func get_last_tractor_recovery_reason() -> StringName:
	return _last_tractor_recovery_reason


func get_guided_ship() -> HeroShip:
	return ship


func is_guided_activity_complete() -> bool:
	return _guided_activity_complete


func get_combat_authority() -> LiveCombatAuthorityType:
	return combat_authority


func get_combat_resolver() -> CombatResolverType:
	return combat_authority.get_resolver() if is_instance_valid(combat_authority) else null


func get_combat_audio_presentation() -> CombatAudioPresentation:
	return combat_audio


func get_music_bed() -> StationMusicBed:
	return music_bed


## Reports the already decided phase to the bounded music bed.
##
## This is a one-way observation seam. The bed receives the phase the flow has
## already reached and can only change its own three voices; it never sets a
## phase, spawns or clears an opponent, or touches combat authority. An active
## encounter always resolves to `combat`, so an authored bed can never play over
## a live fight. Landing phases take priority over ordinary flight so the
## production landing crossfade is reached by the normal return path.
func _update_music_bed_state() -> void:
	if not is_instance_valid(music_bed):
		return
	var presentation_state: StringName = &"station"
	if (
		phase == Phase.INTERCEPTOR_ENGAGEMENT
		or (is_instance_valid(opponent) and opponent.is_active())
	):
		presentation_state = &"combat"
	elif (
		_landing_request_active
		or phase == Phase.RETURN_TO_YARD
		or phase == Phase.SHUT_DOWN
	):
		presentation_state = &"landing"
	elif _piloting:
		presentation_state = &"orbit"
	music_bed.notify_music_phase(presentation_state)


func get_last_player_shot_result() -> Dictionary:
	return _last_player_shot_result.duplicate(true)


func get_last_opponent_shot_result() -> Dictionary:
	return _last_opponent_shot_result.duplicate(true)


func _initialize_runtime_settings() -> void:
	if (
		not _runtime_settings_persistence_injected
		and not _production_runtime_settings_state.is_empty()
	):
		_adopt_production_runtime_settings_state()
		_ensure_runtime_settings_repair_binding()
		return
	if runtime_settings == null:
		runtime_settings = RuntimeSettings.new(_runtime_settings_legacy_path)
	if _runtime_settings_user_data_store == null:
		_runtime_settings_user_data_store = UserDataStoreType.new(
			RuntimeSettingsStoreAdapterType.DEFAULT_STORE_PATH
		)
	if _runtime_settings_store_adapter == null:
		_runtime_settings_store_adapter = RuntimeSettingsStoreAdapterType.new(
			runtime_settings,
			_runtime_settings_user_data_store,
			_runtime_settings_legacy_path
		)
	if _runtime_settings_load_attempted:
		_ensure_runtime_settings_repair_binding()
		return
	_runtime_settings_load_attempted = true
	_runtime_settings_load_attempt_count += 1
	_runtime_settings_load_status = _runtime_settings_store_adapter.load().duplicate(true)
	_runtime_settings_commit_serial = maxi(
		_runtime_settings_commit_serial,
		int(_runtime_settings_load_status.get("generation", 0))
	)
	var loaded_commit_id := str(
		(_runtime_settings_load_status.get("store_status", {}) as Dictionary)
			.get("commit", {})
			.get("id", "")
	)
	_runtime_settings_commit_serial = maxi(
		_runtime_settings_commit_serial,
		_parse_runtime_settings_commit_serial(loaded_commit_id)
	)
	if not bool(_runtime_settings_load_status.get("accepted", false)):
		push_warning(
			"Atomic runtime settings load retained authored defaults: %s / %s"
			% [
				str(_runtime_settings_load_status.get("reason", &"unknown")),
				str(_runtime_settings_load_status.get("store_reason", &"unknown")),
			]
		)
	_initialize_safe_start_recovery()
	_ensure_runtime_settings_repair_binding()
	_sync_production_runtime_settings_state()


func _ensure_runtime_settings_repair_binding() -> void:
	if _runtime_settings_repair_binding != null:
		return
	if _runtime_settings_store_adapter == null or _runtime_settings_user_data_store == null:
		return
	_runtime_settings_repair_binding = RuntimeSettingsRepairBindingType.new()
	var configured: Dictionary = _runtime_settings_repair_binding.configure(
		_runtime_settings_store_adapter,
		_runtime_settings_user_data_store
	)
	if not bool(configured.get("accepted", false)):
		_runtime_settings_repair_binding = null


## Restores and begins exactly one process startup after the settings adapter's
## store load, but before `_start_up()` exposes settings to any consumer. A
## corrupt/newer settings namespace remains untouched even though the generic
## store envelope itself loaded successfully.
func _initialize_safe_start_recovery() -> void:
	if _safe_start_production_recovery != null:
		return
	_safe_start_production_recovery = SafeStartProductionRecoveryType.new(
		runtime_settings,
		_runtime_settings_user_data_store,
		_runtime_settings_persistence_injected
	)
	_safe_start_production_recovery.initialize(
		_runtime_settings_load_status,
		Callable(self, &"_persist_safe_start_recommended_settings")
	)


func _persist_safe_start_recommended_settings() -> Dictionary:
	var prior_unsaved := _runtime_settings_unsaved_changes
	_runtime_settings_unsaved_changes = true
	var status := _persist_runtime_settings()
	if not bool(status.get("accepted", false)):
		_runtime_settings_unsaved_changes = prior_unsaved
	return status


func _validate_safe_start_recommendation(recommendation: Dictionary) -> Dictionary:
	if _safe_start_production_recovery == null:
		return {"accepted": false, "reason": &"policy_unavailable"}
	return _safe_start_production_recovery.validate_recommendation(recommendation)


func _advance_safe_start_recovery_physics(delta: float) -> void:
	if _safe_start_production_recovery != null:
		_safe_start_production_recovery.advance_physics(delta)
		_publish_safe_start_recovery_status_to_hud()


func _adopt_production_runtime_settings_state() -> void:
	runtime_settings = _production_runtime_settings_state.get("settings") as RuntimeSettings
	_runtime_settings_user_data_store = (
		_production_runtime_settings_state.get("store") as UserDataStore
	)
	_runtime_settings_store_adapter = (
		_production_runtime_settings_state.get("adapter") as RuntimeSettingsStoreAdapter
	)
	_runtime_settings_legacy_path = str(
		_production_runtime_settings_state.get(
			"legacy_path", RuntimeSettings.DEFAULT_CONFIG_PATH
		)
	)
	_runtime_settings_load_attempted = bool(
		_production_runtime_settings_state.get("load_attempted", false)
	)
	_runtime_settings_load_attempt_count = int(
		_production_runtime_settings_state.get("load_attempt_count", 0)
	)
	_runtime_settings_load_status = (
		_production_runtime_settings_state.get("load_status", {}) as Dictionary
	).duplicate(true)
	_runtime_settings_last_save_status = (
		_production_runtime_settings_state.get("last_save_status", {}) as Dictionary
	).duplicate(true)
	_runtime_settings_save_attempt_count = int(
		_production_runtime_settings_state.get("save_attempt_count", 0)
	)
	_runtime_settings_save_success_count = int(
		_production_runtime_settings_state.get("save_success_count", 0)
	)
	_runtime_settings_transaction_count = int(
		_production_runtime_settings_state.get("transaction_count", 0)
	)
	_runtime_settings_commit_serial = int(
		_production_runtime_settings_state.get("commit_serial", 0)
	)
	_runtime_settings_last_commit_id = str(
		_production_runtime_settings_state.get("last_commit_id", "")
	)
	_runtime_settings_unsaved_changes = bool(
		_production_runtime_settings_state.get("unsaved_changes", false)
	)
	_runtime_settings_reentrant_rejection_count = int(
		_production_runtime_settings_state.get("reentrant_rejection_count", 0)
	)
	_runtime_settings_apply_count = int(
		_production_runtime_settings_state.get("apply_count", 0)
	)
	_runtime_settings_first_apply_followed_load = bool(
		_production_runtime_settings_state.get("first_apply_followed_load", false)
	)
	_runtime_settings_repair_resolved = bool(
		_production_runtime_settings_state.get("repair_resolved", false)
	)
	_safe_start_production_recovery = (
		_production_runtime_settings_state.get("safe_start_recovery")
		as SafeStartProductionRecovery
	)


func _sync_production_runtime_settings_state() -> void:
	if _runtime_settings_persistence_injected:
		return
	_production_runtime_settings_state = {
		"settings": runtime_settings,
		"store": _runtime_settings_user_data_store,
		"adapter": _runtime_settings_store_adapter,
		"legacy_path": _runtime_settings_legacy_path,
		"load_attempted": _runtime_settings_load_attempted,
		"load_attempt_count": _runtime_settings_load_attempt_count,
		"load_status": _runtime_settings_load_status.duplicate(true),
		"last_save_status": _runtime_settings_last_save_status.duplicate(true),
		"save_attempt_count": _runtime_settings_save_attempt_count,
		"save_success_count": _runtime_settings_save_success_count,
		"transaction_count": _runtime_settings_transaction_count,
		"commit_serial": _runtime_settings_commit_serial,
		"last_commit_id": _runtime_settings_last_commit_id,
		"unsaved_changes": _runtime_settings_unsaved_changes,
		"reentrant_rejection_count": _runtime_settings_reentrant_rejection_count,
		"apply_count": _runtime_settings_apply_count,
		"first_apply_followed_load": _runtime_settings_first_apply_followed_load,
		"repair_resolved": _runtime_settings_repair_resolved,
		"safe_start_recovery": _safe_start_production_recovery,
	}


func _apply_all_runtime_settings() -> void:
	if runtime_settings == null:
		return
	_runtime_settings_apply_count += 1
	if _runtime_settings_apply_count == 1:
		_runtime_settings_first_apply_followed_load = (
			_runtime_settings_load_attempted
			and _runtime_settings_load_attempt_count == 1
			and not _runtime_settings_load_status.is_empty()
		)
		if _safe_start_production_recovery != null:
			_safe_start_production_recovery.note_first_settings_apply()
	_apply_runtime_input_bindings_and_options()
	for fleet_ship in ships:
		fleet_ship.mouse_sensitivity = runtime_settings.ship_mouse_sensitivity
		fleet_ship.invert_mouse_y = runtime_settings.invert_ship_y
		fleet_ship.set_camera_fov(runtime_settings.camera_fov)
	player.mouse_sensitivity = runtime_settings.on_foot_mouse_sensitivity
	player.invert_mouse_y = runtime_settings.invert_on_foot_y
	player.set_camera_fov(runtime_settings.camera_fov)
	_apply_on_foot_camera_preference()
	# The tractor's chase camera is an on-foot-scale third-person rig, so it takes
	# the on-foot look preference rather than the flight one.
	if is_instance_valid(tow_tractor):
		tow_tractor.mouse_sensitivity = runtime_settings.on_foot_mouse_sensitivity
		tow_tractor.set_camera_fov(runtime_settings.camera_fov)
	runtime_settings.apply_audio_settings()
	_apply_reduced_dynamic_range_setting()
	runtime_settings.apply_window_mode()
	runtime_settings.apply_display_settings()
	_bind_station_solar_runtime_settings()
	if world.has_method("apply_visual_quality"):
		world.apply_visual_quality(runtime_settings.graphics_profile)
	_apply_accessibility_settings()
	_sync_runtime_settings_hud()
	_sync_production_runtime_settings_state()


func _sync_runtime_settings_hud() -> void:
	if runtime_settings == null or not is_instance_valid(hud):
		return
	if hud.has_method("set_input_binding_defaults"):
		hud.set_input_binding_defaults(runtime_settings.get_project_input_binding_defaults())
	if hud.has_method("set_settings_snapshot"):
		hud.set_settings_snapshot(runtime_settings.to_dictionary())
	_sync_server_browser_defaults()


## Applies caller-owned multiplayer defaults to the retained browser controls.
## The browser presenter still validates and emits intents; GameFlow only keeps
## its display name and port fields aligned with the accepted settings snapshot.
func _sync_server_browser_defaults() -> void:
	if runtime_settings == null or not is_instance_valid(hud):
		return
	var port_control := hud.get("_server_browser_port") as LineEdit
	if port_control != null:
		port_control.text = str(runtime_settings.network_default_port)
	var name_control := hud.get("_server_browser_player_name") as LineEdit
	if name_control != null:
		name_control.text = runtime_settings.multiplayer_display_name


## Pushes the validated accessibility snapshot to the presentation owners.
##
## Nothing here touches flight handling, deadzones, or the sampled `ShipCommand`
## path. Reduced motion only removes presentation lag: the chase boom's softened
## orbit is an authored `HeroShip` presentation export whose zero value already
## snaps the boom to the physical hull, so damping it changes what the camera
## does, never what the craft does.
func _apply_accessibility_settings() -> void:
	if runtime_settings == null:
		return
	_bind_station_solar_runtime_settings()
	if hud.has_method("set_accessibility"):
		hud.set_accessibility(runtime_settings.get_accessibility_descriptor())
	if _caption_presentation_service != null:
		_caption_presentation_service.set_presentation_flags(
			runtime_settings.captions_enabled,
			runtime_settings.reduced_motion
		)
		_sync_caption_presentation()
	for fleet_ship in ships:
		if not is_instance_valid(fleet_ship):
			continue
		var instance_id := fleet_ship.get_instance_id()
		if not _authored_chase_camera_lag.has(instance_id):
			_authored_chase_camera_lag[instance_id] = (
				fleet_ship.maximum_chase_camera_rotation_lag_degrees
			)
		fleet_ship.maximum_chase_camera_rotation_lag_degrees = (
			0.0
			if runtime_settings.reduced_motion
			else float(_authored_chase_camera_lag[instance_id])
		)
	_apply_bomber_payload_presentation_profile()


## Gives the station's zero-budget Environment presenter the validated setting;
## RuntimeSettings remains the sole value/persistence authority.
func _bind_station_solar_runtime_settings() -> void:
	if runtime_settings != null and is_instance_valid(world) \
			and world.has_method(&"bind_station_solar_runtime_settings"):
		world.call(&"bind_station_solar_runtime_settings", runtime_settings)


func _apply_bomber_payload_presentation_profile(target: CinderLongRangeBomber = null) -> void:
	if runtime_settings == null:
		return
	var intensity_ids: Array[StringName] = [&"low", &"medium", &"high"]
	var intensity := intensity_ids[clampi(int(runtime_settings.payload_visual_intensity), 0, intensity_ids.size() - 1)]
	var candidates: Array = [target] if target != null else ships
	for candidate in candidates:
		var bomber := candidate as CinderLongRangeBomber
		if is_instance_valid(bomber):
			bomber.set_payload_presentation_profile(intensity, runtime_settings.reduced_flash)


func _on_audio_cue_started(cue_id: StringName) -> void:
	if hud.has_method("caption_cue"):
		hud.caption_cue(cue_id)


func _on_combat_audio_cue_started(
	cue_id: StringName,
	_voice_name: StringName,
	_world_position: Vector3,
	_source_instance_id: int
) -> void:
	if hud.has_method("caption_cue"):
		hud.caption_cue(cue_id)


func _on_semantic_audio_cue_emitted(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
) -> void:
	if is_instance_valid(hud) and hud.has_method(&"present_semantic_audio_cue"):
		hud.call(&"present_semantic_audio_cue", cue_id, source_id, intensity, world_position)


func _on_setting_change_requested(setting: StringName, value: Variant) -> void:
	if runtime_settings == null or not RUNTIME_SETTING_KEYS.has(setting):
		return
	if _runtime_settings_transaction_active:
		_runtime_settings_reentrant_rejection_count += 1
		_sync_production_runtime_settings_state()
		return
	_runtime_settings_transaction_active = true
	var before := runtime_settings.to_dictionary()
	runtime_settings.set(setting, value)
	var changed := runtime_settings.to_dictionary() != before
	if changed:
		if setting in [&"window_mode", &"display_resolution"]:
			var display_report := runtime_settings.apply_display_settings()
			if display_report.get("reason", &"") == &"headless":
				runtime_settings.window_mode = int(before.window_mode)
				runtime_settings.display_resolution = String(before.display_resolution)
				if is_instance_valid(hud):
					hud.set_settings_snapshot(before)
					hud.set_settings_status("DISPLAY PREVIEW UNAVAILABLE", false)
				_runtime_settings_transaction_active = false
				_sync_production_runtime_settings_state()
				return
			_display_confirmation_generation += 1
			_pending_display_confirmation = {
				"generation": _display_confirmation_generation,
				"remaining": 15.0,
				"prior": before.duplicate(true),
				"candidate": runtime_settings.to_dictionary(),
			}
			if is_instance_valid(hud):
				hud.show_display_settings_confirmation(_display_confirmation_generation, 15.0)
			_runtime_settings_transaction_active = false
			_sync_production_runtime_settings_state()
			return
		_runtime_settings_transaction_count += 1
		_runtime_settings_unsaved_changes = true
		var status := _persist_runtime_settings()
		_present_runtime_settings_save_status(status, &"change")
	_runtime_settings_transaction_active = false
	_sync_production_runtime_settings_state()


func _update_display_confirmation(delta: float) -> void:
	if _pending_display_confirmation.is_empty():
		return
	_pending_display_confirmation.remaining = maxf(
		float(_pending_display_confirmation.remaining) - maxf(delta, 0.0), 0.0
	)
	if is_instance_valid(hud):
		hud.show_display_settings_confirmation(
			int(_pending_display_confirmation.generation),
			float(_pending_display_confirmation.remaining)
		)
	if float(_pending_display_confirmation.remaining) <= 0.0:
		_revert_display_settings(int(_pending_display_confirmation.generation), &"timeout")


func _on_display_settings_keep_requested(generation: int) -> void:
	if _pending_display_confirmation.is_empty() or int(_pending_display_confirmation.generation) != generation:
		return
	var status := _persist_runtime_settings()
	if bool(status.get("accepted", false)):
		_runtime_settings_unsaved_changes = false
		_pending_display_confirmation = {}
		if is_instance_valid(hud):
			hud.clear_display_settings_confirmation()
			hud.set_settings_status("DISPLAY CHANGE KEPT", true)
	else:
		_revert_display_settings(generation, &"save_failed")
	_sync_production_runtime_settings_state()


func _on_display_settings_revert_requested(generation: int) -> void:
	_revert_display_settings(generation, &"caller_reverted")


func _revert_display_settings(generation: int, reason: StringName) -> void:
	if _pending_display_confirmation.is_empty() or int(_pending_display_confirmation.generation) != generation:
		return
	var prior := _pending_display_confirmation.prior as Dictionary
	_pending_display_confirmation = {}
	runtime_settings.window_mode = int(prior.get("window_mode", RuntimeSettings.DEFAULT_WINDOW_MODE))
	runtime_settings.display_resolution = String(prior.get("display_resolution", RuntimeSettings.DEFAULT_DISPLAY_RESOLUTION_ID))
	runtime_settings.apply_window_mode()
	runtime_settings.apply_display_settings()
	if is_instance_valid(hud):
		hud.clear_display_settings_confirmation()
		hud.set_settings_snapshot(prior)
		hud.set_settings_status("DISPLAY CHANGE REVERTED // %s" % String(reason).to_upper(), false)
	_sync_production_runtime_settings_state()


func _on_runtime_setting_changed(setting: StringName, _value: Variant) -> void:
	if setting == &"ship_mouse_sensitivity":
		for fleet_ship in ships:
			fleet_ship.mouse_sensitivity = runtime_settings.ship_mouse_sensitivity
	elif setting == &"on_foot_mouse_sensitivity":
		player.mouse_sensitivity = runtime_settings.on_foot_mouse_sensitivity
		if is_instance_valid(tow_tractor):
			tow_tractor.mouse_sensitivity = runtime_settings.on_foot_mouse_sensitivity
	elif setting == &"invert_ship_y":
		for fleet_ship in ships:
			fleet_ship.invert_mouse_y = runtime_settings.invert_ship_y
	elif setting == &"invert_on_foot_y":
		player.invert_mouse_y = runtime_settings.invert_on_foot_y
	elif setting == &"camera_fov":
		for fleet_ship in ships:
			fleet_ship.set_camera_fov(runtime_settings.camera_fov)
		player.set_camera_fov(runtime_settings.camera_fov)
		if is_instance_valid(tow_tractor):
			tow_tractor.set_camera_fov(runtime_settings.camera_fov)
	elif setting == &"on_foot_first_person":
		_apply_on_foot_camera_preference()
	elif setting in [
		&"master_volume", &"ambience_volume", &"engine_volume",
		&"weapons_volume", &"ui_volume", &"music_volume"
	]:
		# RuntimeSettings survives a streamed Main detach, but AudioServer belongs
		# to whichever scene is currently on screen. Preserve the validated value
		# and let the re-entry snapshot reclaim global buses at the correct boundary.
		if is_inside_tree():
			runtime_settings.apply_audio_settings()
	elif setting == &"graphics_profile" and world.has_method("apply_visual_quality"):
		world.apply_visual_quality(runtime_settings.graphics_profile)
	elif setting == &"window_mode":
		if is_inside_tree():
			runtime_settings.apply_window_mode()
	elif setting in [&"display_resolution", &"vsync_mode"]:
		if is_inside_tree():
			runtime_settings.apply_display_settings()
	elif setting == &"input_binding_profile":
		_apply_runtime_input_bindings_and_options()
		# Re-apply the canonical profile to the retained HUD after the settings
		# transaction. This keeps a caller-owned remap, InputMap, and glyph rows
		# on the same accepted snapshot even when the request came from a detached
		# settings owner rather than the currently visible HUD.
		_sync_runtime_settings_hud()
	elif setting in [&"multiplayer_display_name", &"network_default_port"]:
		_sync_server_browser_defaults()
	elif setting == &"reduced_dynamic_range":
		_apply_reduced_dynamic_range_setting()
	elif setting in [&"reduced_flash", &"payload_visual_intensity"]:
		_apply_bomber_payload_presentation_profile()
	elif setting in [
		&"ui_scale", &"colorblind_palette", &"reduced_motion", &"captions_enabled"
	]:
		_apply_accessibility_settings()


func _apply_on_foot_camera_preference() -> void:
	if runtime_settings == null or not is_instance_valid(player):
		return
	_applying_on_foot_camera_preference = true
	player.set_camera_view_mode(
		PlayerController.CameraViewMode.FIRST_PERSON
		if runtime_settings.on_foot_first_person
		else PlayerController.CameraViewMode.THIRD_PERSON
	)
	_applying_on_foot_camera_preference = false


func _on_player_camera_view_mode_changed(mode: PlayerController.CameraViewMode) -> void:
	if (
		_applying_on_foot_camera_preference
		or runtime_settings == null
		or not is_inside_tree()
		or is_queued_for_deletion()
	):
		return
	_on_setting_change_requested(
		&"on_foot_first_person",
		mode == PlayerController.CameraViewMode.FIRST_PERSON
	)


## Caller-facing convenience seam; RuntimeSettings remains the authority for
## validation and persistence before audio consumers receive the value.
func set_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if runtime_settings != null:
		runtime_settings.reduced_dynamic_range = enabled
		return _apply_reduced_dynamic_range_setting()
	_reduced_dynamic_range = enabled
	return _apply_reduced_dynamic_range_setting()


func _apply_reduced_dynamic_range_setting() -> Dictionary:
	if runtime_settings != null:
		_reduced_dynamic_range = runtime_settings.reduced_dynamic_range
	if is_instance_valid(_ember_surface_loop_audio_composition) \
			and bool((_ember_surface_loop_audio_composition.call(
				&"get_snapshot"
			) as Dictionary).get("attached", false)):
		_ember_surface_loop_audio_composition.call(
			&"set_reduced_dynamic_range", _reduced_dynamic_range
		)
	if is_instance_valid(audio) and audio.has_method(&"set_reduced_dynamic_range"):
		return audio.call(&"set_reduced_dynamic_range", _reduced_dynamic_range)
	return {"accepted": true, "reason": &"retained_until_audio_ready"}


## Applies one validated RuntimeSettings profile to InputMap and every retained
## ship-local transform bank as a single synchronous composition step. All banks
## preflight the exact candidate/generation before InputMap or any bank mutates;
## replacement then has no signal or await boundary at which the plan can stale.
## Exact matches are retained so whole-Main re-entry reclaims process-global
## InputMap state without resetting toggles or advancing ship-bank generations.
func _apply_runtime_input_bindings_and_options() -> Dictionary:
	if runtime_settings == null:
		return {
			"accepted": false,
			"reason": &"runtime_settings_unavailable",
			"source_count": 0,
			"replaced_count": 0,
			"unchanged_count": 0,
		}
	var profile := runtime_settings.get_input_binding_profile()
	var target := profile.to_dictionary() if profile != null else {}
	var pending: Array[Dictionary] = []
	var unchanged_count := 0
	var source_ids := {}
	for fleet_ship: HeroShip in ships:
		if not is_instance_valid(fleet_ship):
			push_error("Runtime input profile rejected: invalid fleet ship")
			return {
				"accepted": false,
				"reason": &"invalid_fleet_ship",
				"source_count": source_ids.size(),
				"replaced_count": 0,
				"unchanged_count": unchanged_count,
			}
		var source := fleet_ship.get_local_input_source()
		if source == null or not is_instance_valid(source):
			push_error("Runtime input profile rejected: missing local source for %s" % fleet_ship.name)
			return {
				"accepted": false,
				"reason": &"missing_local_input_source",
				"source_count": source_ids.size(),
				"replaced_count": 0,
				"unchanged_count": unchanged_count,
			}
		var source_id := source.get_instance_id()
		if source_ids.has(source_id):
			push_error("Runtime input profile rejected: duplicate local source")
			return {
				"accepted": false,
				"reason": &"duplicate_local_input_source",
				"source_count": source_ids.size(),
				"replaced_count": 0,
				"unchanged_count": unchanged_count,
			}
		source_ids[source_id] = true
		var current := source.get_input_binding_profile()
		if current != null and current.to_dictionary() == target:
			unchanged_count += 1
			continue
		var generation := source.get_input_profile_generation()
		var preflight := source.validate_input_binding_profile(profile, generation)
		if not bool(preflight.accepted):
			push_error(
				"Runtime input profile rejected by %s: %s"
				% [fleet_ship.name, str(preflight.reason)]
			)
			return {
				"accepted": false,
				"reason": StringName(preflight.reason),
				"source_count": source_ids.size(),
				"replaced_count": 0,
				"unchanged_count": unchanged_count,
			}
		pending.append({
			"ship_name": StringName(fleet_ship.name),
			"source": source,
			"generation": generation,
		})

	var input_map_result := runtime_settings.apply_input_bindings()
	if not bool(input_map_result.applied):
		push_error("Runtime input profile rejected by InputMap")
		return {
			"accepted": false,
			"reason": &"input_map_apply_failed",
			"source_count": source_ids.size(),
			"replaced_count": 0,
			"unchanged_count": unchanged_count,
		}
	var replaced_count := 0
	for entry: Dictionary in pending:
		var source := entry.source as LocalShipInputSource
		var replaced := source.replace_input_binding_profile(
			profile,
			int(entry.generation),
		)
		if not bool(replaced.accepted):
			# Preflight and commit are synchronous and signal-free. Reaching this
			# branch therefore indicates an internal invariant violation rather
			# than a recoverable profile rejection.
			push_error(
				"Runtime input profile commit invariant failed for %s: %s"
				% [str(entry.ship_name), str(replaced.reason)]
			)
			return {
				"accepted": false,
				"reason": &"source_commit_invariant_failed",
				"source_count": source_ids.size(),
				"replaced_count": replaced_count,
				"unchanged_count": unchanged_count,
			}
		replaced_count += 1
	return {
		"accepted": true,
		"reason": &"profile_applied" if replaced_count > 0 else &"profile_reclaimed",
		"source_count": source_ids.size(),
		"replaced_count": replaced_count,
		"unchanged_count": unchanged_count,
	}


func _on_settings_save_requested() -> void:
	if runtime_settings == null or _runtime_settings_store_adapter == null:
		return
	if _runtime_settings_transaction_active:
		_runtime_settings_reentrant_rejection_count += 1
		_sync_production_runtime_settings_state()
		return
	_runtime_settings_transaction_active = true
	_runtime_settings_transaction_count += 1
	var status := _persist_runtime_settings()
	_present_runtime_settings_save_status(status, &"explicit_save")
	_runtime_settings_transaction_active = false
	_sync_production_runtime_settings_state()


func _on_settings_reset_requested() -> void:
	if runtime_settings == null or _runtime_settings_store_adapter == null:
		return
	if _runtime_settings_transaction_active:
		_runtime_settings_reentrant_rejection_count += 1
		_sync_production_runtime_settings_state()
		return
	_runtime_settings_transaction_active = true
	runtime_settings.reset_to_defaults()
	_apply_all_runtime_settings()
	_runtime_settings_transaction_count += 1
	_runtime_settings_unsaved_changes = true
	var status := _persist_runtime_settings()
	_present_runtime_settings_save_status(status, &"reset")
	_runtime_settings_transaction_active = false
	_sync_production_runtime_settings_state()


func _persist_runtime_settings() -> Dictionary:
	if _runtime_settings_store_adapter == null:
		var unavailable := {
			"accepted": false,
			"reason": &"adapter_unavailable",
			"store_reason": &"not_attempted",
			"generation": 0,
			"commit_id": "",
		}
		_runtime_settings_last_save_status = unavailable.duplicate(true)
		_sync_production_runtime_settings_state()
		return unavailable
	var next_serial := maxi(
		_runtime_settings_commit_serial + 1,
		_runtime_settings_user_data_store.get_generation() + 1
	)
	if next_serial > UserDataStoreType.MAX_GENERATION:
		var exhausted := {
			"accepted": false,
			"reason": &"commit_id_exhausted",
			"store_reason": &"not_attempted",
			"generation": _runtime_settings_user_data_store.get_generation(),
			"commit_id": "",
		}
		_runtime_settings_last_save_status = exhausted.duplicate(true)
		_sync_production_runtime_settings_state()
		return exhausted
	var commit_id := "%s%010d" % [RUNTIME_SETTINGS_COMMIT_PREFIX, next_serial]
	_runtime_settings_save_attempt_count += 1
	var status := _runtime_settings_store_adapter.save(commit_id).duplicate(true)
	status["commit_id"] = commit_id
	_runtime_settings_last_save_status = status.duplicate(true)
	if bool(status.get("accepted", false)):
		_runtime_settings_commit_serial = next_serial
		_runtime_settings_last_commit_id = commit_id
		_runtime_settings_save_success_count += 1
		_runtime_settings_unsaved_changes = false
	_sync_production_runtime_settings_state()
	return status


func _present_runtime_settings_save_status(status: Dictionary, transaction: StringName) -> void:
	if not is_instance_valid(hud):
		return
	var accepted := bool(status.get("accepted", false))
	var reason := str(status.get("reason", &"unknown"))
	if accepted:
		if hud.has_method("set_settings_status"):
			hud.set_settings_status(
				"DEFAULTS RESTORED + SAVED" if transaction == &"reset" else "SETTINGS SAVED",
				true
			)
		if transaction == &"reset":
			hud.toast("Defaults restored", "Modern flight settings reapplied", 1.5)
		elif transaction == &"explicit_save":
			hud.toast("Settings saved", "Flight and presentation preferences stored", 1.5)
		return
	if hud.has_method("set_settings_status"):
		hud.set_settings_status(
			"DEFAULTS ACTIVE  //  SAVE FAILED"
			if transaction == &"reset"
			else "UNSAVED  //  %s" % reason.to_upper(),
			false
		)
	if transaction == &"reset":
		hud.toast("Defaults restored", "Changes apply now but could not be stored", 2.4)
	else:
		hud.toast("Settings not saved", reason.replace("_", " "), 2.4)


func _parse_runtime_settings_commit_serial(commit_id: String) -> int:
	if not commit_id.begins_with(RUNTIME_SETTINGS_COMMIT_PREFIX):
		return 0
	var suffix := commit_id.trim_prefix(RUNTIME_SETTINGS_COMMIT_PREFIX)
	if suffix.length() != RUNTIME_SETTINGS_COMMIT_DIGITS or not suffix.is_valid_int():
		return 0
	var serial := suffix.to_int()
	return serial if serial >= 0 and serial <= UserDataStoreType.MAX_GENERATION else 0


func _present_pulse_shot(
	origin: Vector3,
	end: Vector3,
	style_id: StringName,
	source_entity: Node,
		hit: bool,
		presentation_receipt_id: int = -1
	) -> bool:
	if not is_instance_valid(pulse_presentation):
		return false
	return pulse_presentation.present_shot(
		origin,
		end,
		style_id,
		source_entity,
		hit,
		presentation_receipt_id
	)
