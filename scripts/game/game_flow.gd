class_name GameFlow
extends Node3D

const LiveCombatAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")
const LifecycleDamageableAdapterType := preload("res://scripts/combat/lifecycle_damageable_adapter.gd")
const CombatResolverType := preload("res://scripts/combat/combat_resolver.gd")
const MainStartupStagerType := preload("res://scripts/game/main_startup_stager.gd")
const CaptionPresentationEventType := preload("res://scripts/ui/caption_presentation_event.gd")
const CaptionPresentationServiceType := preload("res://scripts/ui/caption_presentation_service.gd")

## First production nearby activity. It is a modern interpretation and remains
## a progress-only route: the director and this integration own no rewards,
## combat, ship, landing, or berth state.
const DEFAULT_FREE_FLIGHT_ACTIVITY_ID: StringName = &"cinder_reach_checkpoint_route"
const CINDER_RACE_LAPS := 1
const CINDER_RACE_COUNTDOWN_SECONDS := 2.0
const CINDER_RACE_TIMEOUT_SECONDS := 120.0
const CAPTION_CATEGORY_BY_ID := {
	&"dialogue": CaptionPresentationEvent.Category.DIALOGUE,
	&"radio": CaptionPresentationEvent.Category.RADIO,
	&"system": CaptionPresentationEvent.Category.SYSTEM,
	&"ambient": CaptionPresentationEvent.Category.AMBIENT,
}

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
const PLAYER_HIT_DAMAGE := 34.0
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
const PLAYER_WEAPON_PROFILES := {
	RANGE_WEAPON_ID: {
		"range": 360.0,
		"damage": RANGE_TARGET_HIT_DAMAGE,
		"origin_tolerance": 24.0,
	},
	COMBAT_WEAPON_ID: {
		"range": 360.0,
		"damage": PLAYER_HIT_DAMAGE,
		"origin_tolerance": 24.0,
	},
}
## ShipDefinition currently owns cadence while the live authority owns range and
## damage. Keep those authority values per physical craft so fleet expansion does
## not silently give a light recon ship and a durable freighter identical guns.
## These are modern provisional balance values, not recovered historical data.
const PLAYER_COMBAT_WEAPON_OVERRIDES := {
	&"arrow_provisional": {
		"range": 410.0,
		"damage": 25.0,
		"origin_tolerance": 24.0,
	},
	&"jovian_provisional": {
		"range": 315.0,
		"damage": 23.0,
		"origin_tolerance": 32.0,
	},
	&"zenith_b7_observed": {
		"range": 390.0,
		"damage": 27.0,
		"origin_tolerance": 24.0,
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
## Diagnostic only: exactly one increment accompanies each production physics
## position submission, proving the retired director sampler is not still live.
var _cinder_position_sample_count := 0


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


## Owns exactly one adapter for this Main lifetime. It is detached rather than
## discarded when Main leaves the tree, so re-entry preserves the current lap,
## checkpoint, clock, and best result alongside the authored director.
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
	_restore_cinder_race_session()


func _restore_cinder_race_session() -> void:
	if cinder_race_session == null:
		_initialize_cinder_race_session()
		return
	var snapshot := cinder_race_session.get_presentation_snapshot()
	if not bool(snapshot.get("attached", false)):
		cinder_race_session.attach(
			activity_director,
			cinder_race_session.get_session_generation()
		)
	_sync_activity_hud()


func _detach_cinder_race_session() -> void:
	if cinder_race_session == null:
		return
	var snapshot := cinder_race_session.get_presentation_snapshot()
	if bool(snapshot.get("attached", false)):
		cinder_race_session.detach(cinder_race_session.get_session_generation())


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
	if what != NOTIFICATION_PREDELETE:
		return
	_detach_caption_presentation()
	_caption_presentation_service = null
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
	_initialize_cinder_race_session()
	_initialize_caption_presentation()
	_initialize_live_combat()
	_connect_runtime_signals()
	opponent.set_target(active_ship)
	opponent.deactivate()
	total_targets = world.get_target_count()
	hud.set_target_count(0, total_targets)
	hud.set_mode("on-foot")
	hud.set_interaction("", false)
	hud.set_enemy_status("", 0.0, 1.0, false)
	_apply_all_runtime_settings()
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
	if _caption_presentation_service != null:
		_caption_presentation_service.advance_physics(delta)
	if not _piloting:
		return
	if not is_instance_valid(active_ship):
		return
	_advance_cinder_race(delta, active_ship.global_position)
	var telemetry: Dictionary = active_ship.get_telemetry()
	_decorate_flight_path_telemetry(telemetry)
	hud.update_ship_telemetry(telemetry)
	var engine_state := str(telemetry.get("engine_state", "OFFLINE")).to_upper()
	if engine_state == "OFFLINE":
		return
	# The ship-local positional rig consumes the already sampled ShipCommand and
	# smoothed throttle. The coordinator performs no raw Input read or global hum.


func _restore_runtime_bindings_after_reentry() -> void:
	if not _initialized or not is_inside_tree():
		return
	# The world subtree is not rebuilt by a detach, so this re-binds the same
	# single vehicle rather than producing a second one. Re-resolving is what keeps
	# the binding honest if the instance was released while detached.
	_resolve_ground_vehicle()
	_restore_cinder_race_session()
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
	_connect_signal_once(hud, &"setting_change_requested", _on_setting_change_requested)
	_connect_signal_once(hud, &"settings_save_requested", _on_settings_save_requested)
	_connect_signal_once(hud, &"settings_reset_requested", _on_settings_reset_requested)
	_connect_signal_once(player, &"interact_requested", _on_interact_requested)
	_connect_signal_once(opponent, &"projectile_fired", _on_opponent_projectile_fired)
	_connect_signal_once(opponent, &"health_changed", _on_opponent_health_changed)
	_connect_signal_once(opponent, &"destroyed", _on_opponent_destroyed)
	_connect_signal_once(world, &"target_destroyed", _on_target_destroyed)
	_connect_signal_once(audio, &"cue_started", _on_audio_cue_started)
	_connect_signal_once(combat_audio, &"cue_started", _on_combat_audio_cue_started)
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
	var override: Dictionary = PLAYER_COMBAT_WEAPON_OVERRIDES.get(candidate.get_ship_id(), {})
	if not override.is_empty():
		profiles[COMBAT_WEAPON_ID] = override.duplicate(true)
	return profiles


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


## Public production seam used by a flight/session owner. Starting is allowed
## only while the physical pilot is in the general free-flight lifecycle; the
## ActivityDirector itself intentionally has no knowledge of that authority.
func request_activity_start(activity_id: StringName) -> Dictionary:
	if not is_instance_valid(activity_director) or cinder_race_session == null:
		return {"accepted": false, "reason": &"director_unavailable"}
	if activity_id != DEFAULT_FREE_FLIGHT_ACTIVITY_ID:
		return {"accepted": false, "reason": &"unsupported_activity"}
	if not _piloting or not is_instance_valid(active_ship) or phase != Phase.FREE_FLIGHT:
		return {"accepted": false, "reason": &"not_in_free_flight"}
	var started := cinder_race_session.start(
		cinder_race_session.get_session_generation()
	)
	if bool(started.get("accepted", false)):
		_active_activity_id = activity_id
		_active_activity_generation = int(started.get("session_generation", 0))
		_sync_activity_hud()
	return started


## Explicit failure/recovery surface. A caller may end only the currently
## observed generation, so a delayed destruction/landing callback cannot fail a
## replacement route.
func fail_active_activity(reason: StringName) -> bool:
	return _fail_active_activity(reason)


func reset_active_activity() -> bool:
	if cinder_race_session == null or _active_activity_id.is_empty():
		return false
	var reset := cinder_race_session.reset(
		cinder_race_session.get_session_generation()
	)
	if bool(reset.get("accepted", false)):
		_active_activity_generation = int(reset.get("session_generation", 0))
		_sync_activity_hud()
	return bool(reset.get("accepted", false))


func get_activity_director() -> ActivityDirector:
	return activity_director


func get_active_activity_snapshot() -> Dictionary:
	if cinder_race_session == null or _active_activity_id.is_empty():
		return {}
	return cinder_race_session.get_presentation_snapshot()


## Inspectable boundary proving this layer observes one physical ship and owns
## none of the authorities adjacent to it.
func get_activity_integration_report() -> Dictionary:
	var directors := find_children("ActivityDirector", "ActivityDirector", true, false)
	return {
		"director": activity_director,
		"director_count": directors.size(),
		"active_activity_id": _active_activity_id,
		"active_generation": _active_activity_generation,
		"snapshot": get_active_activity_snapshot(),
		"session": cinder_race_session,
		"session_instance_id": cinder_race_session.get_instance_id() if cinder_race_session != null else 0,
		"position_sample_count": _cinder_position_sample_count,
		"observed_ship": active_ship if _piloting and is_instance_valid(active_ship) else null,
		"gameplay_authority": false,
		"grants_rewards": false,
		"combat_authority": false,
		"ship_authority": false,
		"berth_authority": false,
	}


func _start_default_free_flight_activity() -> void:
	if not _active_activity_id.is_empty():
		var existing := get_active_activity_snapshot()
		if bool(existing.get("running", false)):
			return
	request_activity_start(DEFAULT_FREE_FLIGHT_ACTIVITY_ID)


func _advance_cinder_race(delta: float, world_position: Vector3) -> void:
	if (
		not is_finite(delta)
		or delta < 0.0
		or not world_position.is_finite()
		or cinder_race_session == null
		or _active_activity_id.is_empty()
	):
		return
	var generation := cinder_race_session.get_session_generation()
	var advanced := cinder_race_session.advance_physics(delta, generation)
	if not bool(advanced.get("accepted", false)):
		return
	if advanced.get("state_id", &"") != &"active":
		return
	_cinder_position_sample_count += 1
	cinder_race_session.submit_position(world_position, generation)


func _fail_active_activity(reason: StringName) -> bool:
	if cinder_race_session == null or _active_activity_id.is_empty():
		return false
	var failed := cinder_race_session.fail(
		reason,
		cinder_race_session.get_session_generation()
	)
	return bool(failed.get("accepted", false))


func _reset_terminal_activity_for_next_sortie() -> void:
	if cinder_race_session == null or _active_activity_id.is_empty():
		return
	var state_id := StringName(get_active_activity_snapshot().get("state_id", &"idle"))
	if state_id in [&"completed", &"failed"]:
		reset_active_activity()


func _on_cinder_session_presentation_changed(_snapshot: Dictionary) -> void:
	_sync_activity_hud()


func _on_cinder_session_completed(_snapshot: Dictionary) -> void:
	if is_instance_valid(hud):
		hud.toast("Cinder Reach race complete", "Time recorded — no reward granted", 3.2)


func _sync_activity_hud() -> void:
	if not is_instance_valid(hud) or not hud.has_method(&"set_activity_objective"):
		return
	if cinder_race_session == null or _active_activity_id.is_empty():
		hud.call(&"clear_activity_objective")
		return
	var snapshot := cinder_race_session.get_presentation_snapshot()
	hud.call(
		&"set_activity_objective",
		str(snapshot.get("display_name", "Cinder Reach race")),
		snapshot
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
	runtime_settings = RuntimeSettings.new()
	var load_error := runtime_settings.load_from_file()
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Runtime settings could not be loaded: %s" % error_string(load_error))
	_connect_signal_once(runtime_settings, &"setting_changed", _on_runtime_setting_changed)


func _apply_all_runtime_settings() -> void:
	if runtime_settings == null:
		return
	runtime_settings.apply_input_bindings()
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
	runtime_settings.set(setting, value)


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
		runtime_settings.apply_input_bindings()
	elif setting in [
		&"ui_scale", &"colorblind_palette", &"reduced_motion", &"captions_enabled"
	]:
		_apply_accessibility_settings()


func _on_settings_save_requested() -> void:
	if runtime_settings == null:
		return
	var save_error := runtime_settings.save_to_file()
	if save_error == OK:
		if hud.has_method("set_settings_status"):
			hud.set_settings_status("SETTINGS SAVED", true)
		hud.toast("Settings saved", "Flight and presentation preferences stored", 1.5)
	else:
		if hud.has_method("set_settings_status"):
			hud.set_settings_status("SAVE FAILED  //  %s" % error_string(save_error), false)
		hud.toast("Settings not saved", error_string(save_error), 2.4)


func _on_settings_reset_requested() -> void:
	if runtime_settings == null:
		return
	runtime_settings.reset_to_defaults()
	_apply_all_runtime_settings()
	var save_error := runtime_settings.save_to_file()
	if save_error == OK:
		if hud.has_method("set_settings_status"):
			hud.set_settings_status("DEFAULTS RESTORED + SAVED", true)
		hud.toast("Defaults restored", "Modern flight settings reapplied", 1.5)
	else:
		if hud.has_method("set_settings_status"):
			hud.set_settings_status("DEFAULTS ACTIVE  //  SAVE FAILED", false)
		hud.toast("Defaults restored", "Changes apply now but could not be stored", 2.4)


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
