class_name GameFlow
extends Node3D

const LiveCombatAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const LifecycleDamageableAdapterType := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const CombatResolverType := preload("res://scripts/combat/combat_resolver.gd")
const WeaponDefinitionResolverProfileType := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const MainStartupStagerType := preload("res://scripts/game/main_startup_stager.gd")
const CaptionPresentationEventType := preload("res://scripts/ui/caption_presentation_event.gd")
const CaptionPresentationServiceType := preload("res://scripts/ui/caption_presentation_service.gd")
const RuntimeSettingsStoreAdapterType := preload(
	"res://scripts/settings/runtime_settings_store_adapter.gd"
)
const UserDataStoreType := preload("res://scripts/persistence/user_data_store.gd")
const SafeStartProductionRecoveryType := preload(
	"res://scripts/recovery/safe_start_production_recovery.gd"
)

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
const CINDER_PATROL_DWELL_SECONDS := 2.0
const CAPTION_CATEGORY_BY_ID := {
	&"dialogue": CaptionPresentationEvent.Category.DIALOGUE,
	&"radio": CaptionPresentationEvent.Category.RADIO,
	&"system": CaptionPresentationEvent.Category.SYSTEM,
	&"ambient": CaptionPresentationEvent.Category.AMBIENT,
}
const RUNTIME_SETTINGS_COMMIT_PREFIX := "runtime-settings-"
const RUNTIME_SETTINGS_COMMIT_DIGITS := 10
## Five seconds of successful physics callbacks is long enough to cross the
## staged Main construction and first embodied simulation ticks without making
## wall-clock, idle-frame, or scene-tree attachment time authoritative.
const SAFE_START_STABILITY_PHYSICS_SECONDS := (
	SafeStartProductionRecoveryType.STABILITY_PHYSICS_SECONDS
)
const SAFE_START_RECOMMENDATION_PRESERVED_KEYS := (
	SafeStartProductionRecoveryType.RECOMMENDATION_PRESERVED_KEYS
)

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
}
const FLIGHT_PATH_MINIMUM_SPEED := 1.5
const FLIGHT_PATH_PROJECTION_DISTANCE := 100.0
const FLIGHT_PATH_NEAR_SIDE_EPSILON := 0.001
const FLIGHT_PATH_SAFE_HORIZONTAL_VIEWPORT_RATIO := 0.27
const FLIGHT_PATH_SAFE_HORIZONTAL_ASPECT_LIMIT := 0.52
const FLIGHT_PATH_SAFE_VERTICAL_VIEWPORT_RATIO := 0.18
const BOARDING_FALLBACK_REACH := 7.0
const SAFED_PULSE_DISTANCE := 0.20
const OPPONENT_SOURCE_ID := 2101
const PLAYER_FACTION: StringName = &"shipyard_flight_test"
const OPPONENT_FACTION: StringName = &"range_defence"
const RANGE_WEAPON_ID: StringName = &"range_pulse_cannon"
const COMBAT_WEAPON_ID: StringName = &"combat_pulse_cannon"
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
const PLAYER_WEAPON_PROFILES := {
	RANGE_WEAPON_ID: {
		"range": 360.0,
		"damage": RANGE_TARGET_HIT_DAMAGE,
		"origin_tolerance": 24.0,
	},
}
## ShipDefinition currently owns cadence while the live authority owns range and
## damage. Keep those authority values per physical craft so fleet expansion does
## not silently give a light recon ship and a durable freighter identical guns.
## These are modern provisional balance values, not recovered historical data.
const PLAYER_COMBAT_WEAPON_OVERRIDES := {
	&"jovian_provisional": {
		"range": 315.0,
		"damage": 23.0,
		"origin_tolerance": 32.0,
	},
	# The crew transport's cadence is already the slowest in the fleet; its
	# mounts are self-defence hardware, so range and damage are the lowest too.
	&"halyard_new_design": {
		"range": 280.0,
		"damage": 18.0,
		"origin_tolerance": 30.0,
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
	&"master_volume",
	&"ambience_volume",
	&"engine_volume",
	&"weapons_volume",
	&"ui_volume",
	&"music_volume",
	&"graphics_profile",
	&"window_mode",
	&"control_preset",
	&"ui_scale",
	&"colorblind_palette",
	&"reduced_motion",
	&"captions_enabled",
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
## Legacy primary alias retained for the guided vertical-slice tests. Runtime
## gameplay uses `active_ship` and the physical `ships` registry below.
var ship: HeroShip
var opponent: CharacterBody3D
var combat_authority: LiveCombatAuthorityType
var pulse_presentation: PulseWeaponPresentation
var combat_audio: CombatAudioPresentation
var hud: CanvasLayer
var audio: Node
var music_bed: StationMusicBed
var activity_director: ActivityDirector
var cinder_race_session: CinderTimedRaceSession
var patrol_activity: PatrolActivity
var cinder_convoy_host: CinderConvoyEscortHost
var cinder_streaming_bootstrap: CinderStreamingBootstrap
var cinder_streaming_binding: CinderStreamingProductionBinding
var cinder_streaming_coordinator: WorldStreamingCoordinator
var ember_streaming_bootstrap: EmberMoonStreamingBootstrap
var ember_streaming_binding: EmberMoonStreamingProductionBinding
var common_world_origin_rebase_owner: CommonWorldOriginRebaseOwner
var cargo_transfer_authority: CargoTransferAuthority
var cargo_delivery_activity: CargoDeliveryActivity
## One presentation-only caption authority for this Main lifetime. It is a
## RefCounted service rather than a scene node and survives whole-Main detach.
var _caption_presentation_service: CaptionPresentationService
var _caption_event_serial := 0
var _caption_request_count := 0
var _caption_accepted_count := 0
var _caption_rejected_count := 0

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
## Which of the tow tractor's two independent safety guards last recalled the
## driver. Diagnostic only; nothing gameplay-facing reads it.
var _last_tractor_recovery_reason: StringName = &""
var _last_engine_state := "OFFLINE"
var _launch_registered := false
var _return_registered := false
var _transition_busy := false
## Every awaited boarding/disembarking coroutine captures this generation. A
## destructive recovery advances it before restoring the player, so stale
## continuations can never reacquire cameras, seats, phases, or berth state.
var _transition_generation := 0
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
var _runtime_settings_last_save_status: Dictionary = {}
var _runtime_settings_load_attempt_count := 0
var _runtime_settings_save_attempt_count := 0
var _runtime_settings_save_success_count := 0
var _runtime_settings_transaction_count := 0
var _runtime_settings_commit_serial := 0
var _runtime_settings_last_commit_id := ""
var _runtime_settings_unsaved_changes := false
var _runtime_settings_transaction_active := false
var _runtime_settings_reentrant_rejection_count := 0
var _runtime_settings_apply_count := 0
var _runtime_settings_first_apply_followed_load := false
var _runtime_settings_persistence_injected := false
## Retained safe-start composition over the exact same process-lifetime store.
var _safe_start_production_recovery: SafeStartProductionRecovery
## Authored chase-boom lag per ship, captured before reduced motion ever damps
## it, so turning the preset back off restores the exact authored feel.
var _authored_chase_camera_lag: Dictionary = {}
var ships: Array[HeroShip] = []
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


func _enter_tree() -> void:
	# A whole Main subtree can be streamed out and re-added without being freed.
	# Source `tree_exiting` hooks intentionally clear combat authority state, but
	# Godot does not call `_ready()` again. Restore only runtime bindings after all
	# descendants have re-entered; gameplay startup and world construction remain
	# one-time operations.
	if _initialized:
		call_deferred("_restore_runtime_bindings_after_reentry")


func _exit_tree() -> void:
	_detach_cinder_race_session()
	_detach_caption_presentation()
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


## Returns the cursor to the desktop. Safe to call from any state, and a no-op
## under `--headless`, where `Input.mouse_mode` has nothing to address.
func release_mouse_capture() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
	common_world_origin_rebase_owner = (
		get_node_or_null(^"CommonWorldOriginRebaseOwner")
		as CommonWorldOriginRebaseOwner
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
	_restore_cinder_race_session()


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
	player.teleport_to(world.get_player_spawn())
	player.set_control_enabled(false)
	player.set_camera_active(false)
	_register_flyable_ships()
	_resolve_ground_vehicle()
	active_ship = ship
	_initialize_cargo_delivery_composition()
	_initialize_cinder_race_session()
	_initialize_cinder_convoy_host()
	_initialize_caption_presentation()
	_initialize_live_combat()
	# The atomic load above is complete before the first global, player, ship or
	# HUD settings consumer sees a snapshot. In particular, the complete binding
	# profile reaches InputMap and all retained local ship banks before gameplay
	# signals can sample it.
	_apply_all_runtime_settings()
	_connect_runtime_signals()
	opponent.set_target(active_ship)
	opponent.deactivate()
	total_targets = world.get_target_count()
	hud.set_target_count(0, total_targets)
	hud.set_mode("on-foot")
	hud.set_interaction("", false)
	hud.set_enemy_status("", 0.0, 1.0, false)
	_update_music_bed_state()
	_apply_torus_geometry_budget()
	_sync_activity_hud()
	_initialized = true


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
	_update_pending_regeneration(delta)
	_update_music_bed_state()
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


func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	_advance_safe_start_recovery_physics(delta)
	if _caption_presentation_service != null:
		_caption_presentation_service.advance_physics(delta)
	var actor_sample := _capture_cinder_actor_sample()
	if is_instance_valid(ember_streaming_binding):
		var ember_tick := ember_streaming_binding.physics_tick_from_caller_sample(
			delta, actor_sample
		)
		if (
			is_instance_valid(common_world_origin_rebase_owner)
			and (ember_tick.has("coordinate_frame_generation"))
		):
			var preview := ember_streaming_binding.preview_origin_rebase(
				int(ember_tick.get("coordinate_frame_generation", 0))
			)
			if bool(preview.get("accepted", false)):
				var rebase := common_world_origin_rebase_owner.consume_rebase_preview(
					preview, actor_sample
				)
				if bool(rebase.get("accepted", false)) and rebase.has("actor_sample"):
					actor_sample = (rebase.get("actor_sample", {}) as Dictionary).duplicate(true)
	if is_instance_valid(cinder_streaming_binding):
		cinder_streaming_binding.physics_tick_from_caller_sample(delta, actor_sample)
	_sync_cinder_convoy_stream_presence()
	if _convoy_is_running() and not _convoy_lifecycle_accepts_sample(actor_sample):
		_fail_active_activity(_convoy_lifecycle_failure_reason(actor_sample))
	if not _piloting:
		return
	if not is_instance_valid(active_ship):
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


func _capture_cinder_actor_sample() -> Dictionary:
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
	if not _initialized or not is_inside_tree():
		return
	# The world subtree is not rebuilt by a detach, so this re-binds the same
	# single vehicle rather than producing a second one. Re-resolving is what keeps
	# the binding honest if the instance was released while detached.
	_resolve_ground_vehicle()
	_restore_cargo_delivery_bindings()
	_restore_cinder_race_session()
	_sync_cinder_convoy_stream_presence()
	_restore_caption_presentation()
	_connect_runtime_signals()
	_initialize_live_combat()
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
	_sync_activity_hud()


func _connect_runtime_signals() -> void:
	_connect_signal_once(
		combat_authority,
		&"authoritative_shot_submitted",
		_on_authoritative_shot_submitted
	)
	_connect_signal_once(pulse_presentation, &"impact_started", _on_pulse_impact_started)
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
	_connect_signal_once(hud, &"setting_change_requested", _on_setting_change_requested)
	_connect_signal_once(hud, &"settings_save_requested", _on_settings_save_requested)
	_connect_signal_once(hud, &"settings_reset_requested", _on_settings_reset_requested)
	_connect_signal_once(
		hud,
		&"orderly_shutdown_requested",
		_on_orderly_shutdown_requested
	)
	_connect_signal_once(player, &"interact_requested", _on_interact_requested)
	_connect_signal_once(opponent, &"projectile_fired", _on_opponent_projectile_fired)
	_connect_signal_once(opponent, &"health_changed", _on_opponent_health_changed)
	_connect_signal_once(opponent, &"destroyed", _on_opponent_destroyed)
	_connect_signal_once(world, &"target_destroyed", _on_target_destroyed)
	_connect_signal_once(audio, &"cue_started", _on_audio_cue_started)
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
	if phase != Phase.INTRO:
		return
	phase = Phase.APPROACH_SHIP
	player.set_camera_active(true)
	player.set_control_enabled(true)
	hud.set_mode("on-foot")
	hud.set_objective(
		"Board the Torrent interceptor for the guided test — other berthed craft are available for free sorties"
	)
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
	if tow_tractor.is_edge_interlock_engaged():
		hud.set_interaction("DECK EDGE  //  SAFETY INTERLOCK")
	elif tow_tractor.can_release_driver():
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


## The tow tractor's half of the crash-recovery contract.
##
## The vehicle raises this at most once per departure, from its own pose, so it
## fires whatever the reason — an interlock that missed an edge, a launch off a
## ramp, geometry that changed underneath it. The pilot recall is the *same*
## `_recall_pilot_to_deck()` a destroyed craft performs; only the vehicle-side
## reset differs, because a tractor owns no berth to regenerate into.
func _recover_from_lost_tractor(reason: StringName) -> void:
	if _recovering:
		return
	var had_driver := _driving
	_recovering = true
	_invalidate_transition_generation()
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
	if _drain_pending_lifecycle_commands(source):
		return
	# Compatibility for custom command sources that have not adopted lossless
	# lifecycle delivery yet. The sequence cursor still prevents repeat polling.
	_consume_active_ship_command(active_ship.get_last_ship_command())


## Returns true when the source implements lossless delivery, including when its
## current FIFO is empty. Capture and validation occur synchronously so a focus,
## pause, pilot, source, or tree boundary cannot let a stale caller drain a newer
## generation. Every queued edge is dispatched in its original command order.
func _drain_pending_lifecycle_commands(source: ShipCommandSource) -> bool:
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
		# lifecycle FIFO so an older pending edge is always dispatched before this
		# newly sampled one. A later idle drain is empty rather than a replay.
		var command := source.next_command() as ShipCommand
		active_ship.consume_sampled_camera_edges(command)
		if not _drain_pending_lifecycle_commands(source):
			_consume_active_ship_command(command)


func _on_interact_requested() -> void:
	if _piloting or _transition_busy:
		return
	# Physics-emitted signal, idle-refreshed selection: recompute before deciding.
	# See `_refresh_interaction_targets()`.
	_refresh_interaction_targets()
	if is_instance_valid(station_interaction_candidate):
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
	active_ship = candidate
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
			return
		if _boarding_area != null:
			_boarding_area.release_reservation(player)
		phase = Phase.COMPLETE if _guided_activity_complete else Phase.APPROACH_SHIP
		player.set_control_enabled(true)
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
	player.set_camera_active(false)
	active_ship.set_piloted(true)
	active_ship.get_camera().current = true
	phase = Phase.START_ENGINES
	hud.set_mode("piloting")
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
	_landing_request_active = false
	player.set_control_enabled(true)
	_reboard_blocked_ship = active_ship
	if _boarding_area != null:
		_boarding_area.release_reservation(player)
	_boarding_area = null
	hud.set_mode("on-foot")
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
	# Range drones belong to the pending guided Torrent sortie. Before that guide
	# completes, non-Torrent craft remain presentation-only and Torrent weapons are
	# safed outside its launch/range/live-contact phases. Demand can power a weapon
	# while still berthed, but allowing damage before physical departure could
	# permanently remove an uncredited range target.
	var guided_weapon_authorized := (
		firing_ship == ship
		and phase in [
			Phase.LAUNCH,
			Phase.TARGET_PRACTICE,
			Phase.INTERCEPTOR_ENGAGEMENT,
			Phase.RETURN_TO_YARD,
		]
	)
	if not _guided_activity_complete and not guided_weapon_authorized:
		var safe_direction := direction.normalized() if direction.is_finite() else Vector3.ZERO
		_last_player_shot_result = {
			"accepted": false,
			"resolved": false,
			"hit": false,
			"damaged": false,
			"destroyed": false,
			"status": &"guided_range_reserved" if firing_ship != ship else &"weapons_safed",
			"reason": (
				"guided range contacts are reserved for the Torrent activity"
				if firing_ship != ship
				else "Torrent weapons are safed until guided flight authority is active"
			),
			"source_entity": firing_ship,
			"source_id": combat_authority.get_source_id(firing_ship),
			"position": Vector3.INF,
			"distance": 0.0,
		}
		# This is a local safing acknowledgement, not an authority result. Keep the
		# visual inside the muzzle envelope so it cannot resemble an unoccluded
		# max-range miss or imply that world geometry/damage resolution occurred.
		if safe_direction.length_squared() > 0.000001 and origin.is_finite():
			combat_audio.play_dry_fire(origin, firing_ship.get_instance_id())
			_present_pulse_shot(
				origin,
				origin + safe_direction * SAFED_PULSE_DISTANCE,
				&"cyan",
				firing_ship,
				false
			)
		return
	var weapon_id := (
		RANGE_WEAPON_ID
		if phase in [Phase.LAUNCH, Phase.TARGET_PRACTICE]
		else COMBAT_WEAPON_ID
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
	if bool(result.get("damaged", false)) and request.presentation_receipt_id < 0:
		# submit_hitscan() is the explicit authority/component-presentation API used
		# by deterministic probes and non-travelling integrations. The target has
		# already reacted synchronously; do not append a late fire/pulse/impact cue.
		return
	if request.source_entity == opponent:
		combat_audio.play_defender_fire(request.origin, source_instance_id)
	else:
		combat_audio.play_player_fire(request.origin, source_instance_id)
	var endpoint := request.origin + direction * request.range
	if bool(result.get("hit", false)):
		var resolved_position: Variant = result.get("position", endpoint)
		if resolved_position is Vector3 and (resolved_position as Vector3).is_finite():
			endpoint = resolved_position as Vector3
	var style_id: StringName = &"amber" if request.source_entity == opponent else &"cyan"
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
	var presented := _present_pulse_shot(
		request.origin,
		endpoint,
		style_id,
		request.source_entity if is_instance_valid(request.source_entity) else null,
		bool(result.get("hit", false)),
		receipt_id
	)
	if bool(result.get("damaged", false)) and receipt_id >= 0 and not presented:
		var impact_weight := 0.45 if style_id == &"amber" else 0.9
		combat_audio.play_impact(endpoint, impact_weight, maxi(source_instance_id, 0))
		_commit_damage_presentation_receipt(receipt_id, result.get("target_entity"), endpoint)


func _on_pulse_impact_started(
	_shot_id: int,
	style_id: StringName,
	source_instance_id: int,
	position: Vector3
	) -> void:
	# The pulse owns travel timing; its endpoint event is the first frame on which
	# the positional impact cue is allowed to start. A separate fixed pool lets a
	# close impact overlap the already travelling fire transient.
	var impact_weight := 0.45 if style_id == &"amber" else 0.9
	combat_audio.play_impact(position, impact_weight, maxi(source_instance_id, 0))


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
	if not is_inside_tree() or not _receipt_target_is_inside_tree(record):
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


## A drop here would be permanent: `authorize_target_destruction()` is one-shot
## and nothing re-reads the world's destroyed count. That is safe only because
## the phases this gate rejects are exactly the phases in which no live drone can
## be damaged. Player fire is safed outside the guided weapon window, guided range
## contacts are reserved against non-Torrent craft, and the two live-fire phases
## the gate does reject — `INTERCEPTOR_ENGAGEMENT` and `RETURN_TO_YARD` — cannot
## be entered until `destroyed_targets >= total_targets`, which is reached only by
## accepting one authorization per drone. Both defenders are likewise dormant
## until then. Widening the weapon window, or admitting a second producer of drone
## damage, would strand the guided sortie at an uncountable range contact;
## `tests/combat_encounter_authority_gate_test.gd` guards both halves.
func _on_target_destroyed(_target_id: StringName, _position: Vector3) -> void:
	if active_ship != ship or (phase != Phase.LAUNCH and phase != Phase.TARGET_PRACTICE):
		return
	destroyed_targets = mini(total_targets, destroyed_targets + 1)
	hud.set_target_count(destroyed_targets, total_targets)
	if destroyed_targets >= total_targets and phase == Phase.TARGET_PRACTICE:
		_begin_interceptor_engagement()
	elif destroyed_targets >= total_targets:
		hud.toast("Range contacts cleared", "Clear the launch aperture to receive your return vector")
	else:
		hud.toast("Target destroyed", "%d range contacts remain" % (total_targets - destroyed_targets))


func _on_landing_completed(source_ship: HeroShip = null) -> void:
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
	_landing_request_active = false
	_active_landing_berth_id = &""
	if not _ensure_landed_berth_occupancy(active_ship):
		_release_ship_berth(active_ship)
		hud.set_interaction("", false)
		hud.set_objective("Docking claim interrupted — keep the pad clear and retry the approach")
		hud.toast("Docking coordination fault", "The berth lease could not be secured; do not exit", 3.5)
		return
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_complete_cargo_delivery_on_return()
	else:
		_fail_active_activity(&"returned_to_shipyard")
	_return_registered = true
	phase = Phase.SHUT_DOWN
	hud.set_objective("Hold controls neutral, then exit %s" % active_ship.get_display_name())
	hud.toast("Landing complete", "Docking clamps engaged — propulsion will idle offline")


func _on_landing_aborted(reason: StringName, source_ship: HeroShip = null) -> void:
	if source_ship != null and source_ship != active_ship:
		return
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


func _on_ship_hull_changed(current: float, _maximum: float, source_ship: HeroShip = null) -> void:
	if source_ship != null and source_ship != active_ship:
		return
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
	if view == &"COCKPIT":
		hud.toast("Cockpit view", "Physical pilot-eye camera active", 1.4)
	else:
		hud.toast("Chase view", "Mouse wheel adjusts camera distance", 1.4)


func _register_flyable_ships() -> void:
	ships.clear()
	var seen_ship_ids: Dictionary = {}
	var seen_home_berths: Dictionary = {}
	for child in get_children():
		if child is not HeroShip:
			continue
		var candidate := child as HeroShip
		var definition := candidate.get_ship_definition()
		var ship_audio_rig := candidate.get_ship_audio_rig()
		var candidate_id := candidate.get_ship_id()
		var berth_id := candidate.get_home_berth_id()
		var invalid_reason := ""
		if definition == null or not definition.is_definition_valid():
			invalid_reason = "missing or invalid ShipDefinition"
		elif ship_audio_rig == null \
				or not bool(ship_audio_rig.get_audit_report().get("valid", false)) \
				or ship_audio_rig.get_profile_id() != definition.audio_profile_id:
			invalid_reason = "missing, invalid, or mismatched ship-local audio profile"
		elif candidate_id.is_empty() or seen_ship_ids.has(candidate_id):
			invalid_reason = "empty or duplicate ship ID %s" % candidate_id
		elif berth_id.is_empty() or seen_home_berths.has(berth_id):
			invalid_reason = "empty or duplicate home berth ID %s" % berth_id
		elif not world.has_method("has_berth") or not bool(world.call("has_berth", berth_id)):
			invalid_reason = "unregistered home berth %s" % berth_id
		if not invalid_reason.is_empty():
			_disable_invalid_fleet_candidate(candidate)
			push_error("Flyable ship %s rejected: %s" % [candidate.name, invalid_reason])
			continue
		seen_ship_ids[candidate_id] = candidate
		seen_home_berths[berth_id] = candidate
		if not _reserve_berth_for_ship(candidate, berth_id, true):
			_disable_invalid_fleet_candidate(candidate)
			push_error("Flyable ship %s could not occupy home berth %s" % [candidate.name, berth_id])
			continue
		var berth_transform := world.call("get_berth_transform", berth_id) as Transform3D
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
	for fleet_ship in ships:
		var source_id := int(PLAYER_SOURCE_IDS.get(fleet_ship.get_ship_id(), 0))
		if source_id <= 0:
			push_error(
				"No stable combat source ID is registered for ship ID %s"
				% fleet_ship.get_ship_id()
			)
			continue
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
	var expected_source_count := ships.size() + 1
	if resolver == null or resolver.get_registered_source_count() != expected_source_count:
		push_error(
			"Live combat authority owns %d of %d expected source registrations"
			% [
				resolver.get_registered_source_count() if resolver != null else 0,
				expected_source_count,
			]
		)


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
		profiles[COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == ARROW_SHIP_ID:
		# Arrow has no legacy override after migration. Reject invalid authored data
		# instead of borrowing Torrent's different combat envelope.
		var migrated_profile := _get_arrow_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	if candidate.get_ship_id() == ZENITH_SHIP_ID:
		# Zenith has no legacy override after migration. Invalid modern weapon data
		# must not borrow another craft's combat envelope.
		var migrated_profile := _get_zenith_combat_weapon_profile(candidate)
		if migrated_profile.is_empty():
			return {}
		profiles[COMBAT_WEAPON_ID] = migrated_profile
		return profiles
	var override: Dictionary = PLAYER_COMBAT_WEAPON_OVERRIDES.get(candidate.get_ship_id(), {})
	if not override.is_empty():
		profiles[COMBAT_WEAPON_ID] = override.duplicate(true)
	return profiles


func _get_torrent_combat_weapon_profile(candidate: HeroShip) -> Dictionary:
	return _get_migrated_player_combat_weapon_profile(
		candidate,
		TORRENT_COMBAT_WEAPON_DEFINITION,
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
		ZENITH_COMBAT_ORIGIN_TOLERANCE_METERS,
		ZENITH_COMBAT_PRESENTATION_ID,
		ZENITH_COMBAT_FIRE_AUDIO_ID,
		ZENITH_COMBAT_IMPACT_AUDIO_ID,
		ZENITH_COMBAT_DRY_FIRE_AUDIO_ID
	)


func _get_migrated_player_combat_weapon_profile(
	candidate: HeroShip,
	definition: WeaponDefinition,
	origin_tolerance_meters: float,
	presentation_id: StringName,
	fire_audio_id: StringName,
	impact_audio_id: StringName,
	dry_fire_audio_id: StringName
	) -> Dictionary:
	if (
		not is_instance_valid(candidate)
		or definition == null
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
	return (converted.get(COMBAT_WEAPON_ID, {}) as Dictionary).duplicate(true)


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
	if source_ship.get_pending_terminal_damage_presentation_receipt_id() < 0:
		combat_audio.play_explosion(world_position, source_ship.get_instance_id())
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
	# Losing the cabin is exactly the case the outer safety net exists for. Drop
	# containment and occupancy before the avatar is teleported back to the deck,
	# so nothing keeps trying to hold it against a hull that no longer exists.
	_release_cabin_occupancy()
	_landing_request_active = false
	_active_landing_berth_id = &""
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
	hud.toast("Hull integrity lost", "Pilot recall engaged — the other craft remains available", 3.0)
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
	_transition_busy = false
	_recovering = false
	_replenish_destroyed_ship(destroyed_ship)


## Selects one production sortie before launch. Race and patrol remain distinct
## typed interpretations of the shared Cinder route; cargo and convoy retain
## their own authority-backed definitions. The first accepted start locks every
## interpretation so no generation-bearing sortie can be swapped under the player.
func select_activity_kind(activity_kind: StringName) -> Dictionary:
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
			started = patrol_activity.start(patrol_activity.get_generation())
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
	return _fail_active_activity(reason)


func reset_active_activity() -> bool:
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
		_advance_patrol(delta, world_position)
		return
	if _selected_activity_kind == ACTIVITY_KIND_CARGO_DELIVERY:
		_advance_cargo_delivery(delta)
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


func _advance_patrol(delta: float, world_position: Vector3) -> void:
	var generation := patrol_activity.get_generation()
	var before := patrol_activity.get_presentation_snapshot()
	if before.get("state_id", &"") != &"active":
		return
	# One captured active-ship position is shared by arrival and continuous dwell
	# for this physics tick. GameFlow samples; PatrolActivity and the director own
	# every decision made from that value.
	_cinder_position_sample_count += 1
	if before.get("phase_id", &"") == &"travel":
		patrol_activity.submit_position(world_position, generation)
	var after_arrival := patrol_activity.get_presentation_snapshot()
	if after_arrival.get("state_id", &"") == &"active":
		patrol_activity.advance_physics(delta, world_position, generation)


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


func _on_cinder_session_presentation_changed(_snapshot: Dictionary) -> void:
	if _selected_activity_kind == ACTIVITY_KIND_TIMED_RACE:
		_sync_activity_hud()


func _on_cinder_session_completed(_snapshot: Dictionary) -> void:
	if is_instance_valid(hud):
		hud.toast("Cinder Reach race complete", "Time recorded — no reward granted", 3.2)


func _on_patrol_presentation_changed(_snapshot: Dictionary) -> void:
	if _selected_activity_kind == ACTIVITY_KIND_PATROL:
		_sync_activity_hud()


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
		hud.call(
			&"set_activity_selection_state",
			_selected_activity_kind,
			_activity_selection_locked,
			&""
		)


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
	return (
		cinder_streaming_bootstrap.global_transform * CINDER_CONVOY_ACTIVATION_CENTER
		if is_instance_valid(cinder_streaming_bootstrap)
		else CINDER_CONVOY_ACTIVATION_CENTER
	)


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
	var result := select_activity_kind(activity_kind)
	if is_instance_valid(hud) and hud.has_method(&"set_activity_selection_state"):
		hud.call(
			&"set_activity_selection_state",
			_selected_activity_kind,
			_activity_selection_locked,
			StringName(result.get("reason", &"selection_rejected"))
		)


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
		"ready_at_msec": Time.get_ticks_msec() + 4000,
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
		var berth_id := pending_ship.get_home_berth_id()
		var berth_transform: Transform3D = world.call("get_ship_spawn") as Transform3D
		var has_registered_berth: bool = (
			world.has_method("has_berth")
			and world.call("has_berth", berth_id)
		)
		if has_registered_berth:
			berth_transform = world.call("get_berth_transform", berth_id) as Transform3D
			# Acquire and occupy the physical pad before making the hull visible or
			# collidable. An occupied home pad keeps the hull safely despawned and
			# schedules one bounded retry without allocating a timer/coroutine.
			if not _reserve_berth_for_ship(pending_ship, berth_id, true):
				hud.toast(
					"Regeneration holding",
					"%s is waiting for its home berth" % pending_ship.get_display_name(),
					2.0
				)
				entry["ready_at_msec"] = Time.get_ticks_msec() + 2000
				_regeneration_pending[instance_id] = entry
				continue
		pending_ship.reset_for_reuse(berth_transform)
		if not has_registered_berth:
			_reserve_berth_for_ship(pending_ship, berth_id, true)
		hud.toast(
			"Berth regeneration complete",
			"%s is available again" % pending_ship.get_display_name(),
			2.2
		)
		_regeneration_pending.erase(instance_id)


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
func _mark_sortie_departed() -> void:
	if _sortie_departed_berth or not is_instance_valid(active_ship):
		return
	_sortie_departed_berth = true
	_release_ship_berth(active_ship)


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
	if not _berth_tokens.has(instance_id) or not _reserved_berth_ids.has(instance_id):
		return
	if world.has_method("get_berth_node"):
		var berth := world.call("get_berth_node", _reserved_berth_ids[instance_id]) as ShipBerth
		if berth != null:
			berth.release(candidate, _berth_tokens[instance_id])
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


## Detached diagnostics for the process startup marker and caller-owned
## stability window. No live policy, store, settings, or filesystem object is
## exposed. In particular, a scene-tree detach is not represented as shutdown.
func get_safe_start_recovery_report() -> Dictionary:
	return (
		_safe_start_production_recovery.get_report()
		if _safe_start_production_recovery != null else {}
	)


## Explicit application-owned orderly-shutdown seam. `_exit_tree()`, free, and
## whole-Main streaming never call this method because none of them proves an OS
## process shutdown. The caller may invoke it after deciding shutdown is clean.
func mark_orderly_shutdown() -> Dictionary:
	if _safe_start_production_recovery == null:
		return {"accepted": false, "reason": &"policy_unavailable"}
	var result := _safe_start_production_recovery.mark_orderly_shutdown()
	_sync_production_runtime_settings_state()
	return result


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


## Reports the already decided session state to the bounded music bed.
##
## This is a one-way observation seam. The bed receives the state the flow has
## already reached and can only change its own three voices; it never sets a
## phase, spawns or clears an opponent, or touches combat authority. An active
## encounter always resolves to `combat`, so an authored bed can never play over
## a live fight.
func _update_music_bed_state() -> void:
	if not is_instance_valid(music_bed):
		return
	var state := StationMusicBed.STATE_REST
	if (
		phase == Phase.INTERCEPTOR_ENGAGEMENT
		or (is_instance_valid(opponent) and opponent.is_active())
	):
		state = StationMusicBed.STATE_COMBAT
	elif _piloting:
		state = StationMusicBed.STATE_FLIGHT
	music_bed.notify_session_state(state)


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
	_sync_production_runtime_settings_state()


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
	# The tractor's chase camera is an on-foot-scale third-person rig, so it takes
	# the on-foot look preference rather than the flight one.
	if is_instance_valid(tow_tractor):
		tow_tractor.mouse_sensitivity = runtime_settings.on_foot_mouse_sensitivity
		tow_tractor.set_camera_fov(runtime_settings.camera_fov)
	runtime_settings.apply_audio_settings()
	runtime_settings.apply_window_mode()
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
		_runtime_settings_transaction_count += 1
		_runtime_settings_unsaved_changes = true
		var status := _persist_runtime_settings()
		_present_runtime_settings_save_status(status, &"change")
	_runtime_settings_transaction_active = false
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
	elif setting in [
		&"master_volume", &"ambience_volume", &"engine_volume",
		&"weapons_volume", &"ui_volume", &"music_volume"
	]:
		runtime_settings.apply_audio_settings()
	elif setting == &"graphics_profile" and world.has_method("apply_visual_quality"):
		world.apply_visual_quality(runtime_settings.graphics_profile)
	elif setting == &"window_mode":
		runtime_settings.apply_window_mode()
	elif setting == &"input_binding_profile":
		_apply_runtime_input_bindings_and_options()
	elif setting in [
		&"ui_scale", &"colorblind_palette", &"reduced_motion", &"captions_enabled"
	]:
		_apply_accessibility_settings()


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
