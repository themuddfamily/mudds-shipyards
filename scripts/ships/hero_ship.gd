class_name HeroShip
extends CharacterBody3D

## Flyable Torrent-class interceptor.
##
## The B5-observed Torrent macroform is a checked-in authored/imported asset.
## Cockpit and modern-system presentation remains separately assembled so its
## speculative detail cannot be mistaken for recovered historical geometry.
## Local forward is negative Z and the parked root height is 1.15 metres.

signal engine_state_changed(state: StringName)
signal projectile_fired(origin: Vector3, direction: Vector3)
signal landing_completed
signal landing_aborted(reason: StringName)
signal boarded
signal hull_changed(current: float, maximum: float)
signal critical_damage
signal canopy_motion_finished(open: bool)
signal camera_view_changed(view: StringName)
signal damage_stage_changed(stage: int, status: StringName)
signal component_damage_changed(component_id: StringName, state: int, integrity: float)
signal component_repair_progressed(progress: Dictionary)
signal component_repair_interrupted(receipt: Dictionary)
signal destroyed(world_position: Vector3, inherited_velocity: Vector3)
signal planetary_cruise_state_changed(snapshot: Dictionary)


## SpringArm3D resolves its sweep after the ship's own physics callback. Keeping
## the boundary correction on its direct child makes the ordering explicit: the
## arm owns obstruction distance first, then this mount moves only the one chase
## camera far enough above the owning collision envelope to keep its near plane
## out of the hull. It adds no camera or input authority.
class ChaseCameraBoundaryMount:
	extends Node3D

	var controller: Node


	func _physics_process(_delta: float) -> void:
		if controller != null and controller.is_inside_tree():
			controller.call(&"_enforce_chase_camera_self_hull_boundary")


const ENGINE_OFFLINE: StringName = &"OFFLINE"
const ENGINE_STARTING: StringName = &"STARTING"
const ENGINE_ONLINE: StringName = &"ONLINE"
## Player propulsion stays available briefly after the last real flight intent.
## This is physics time, so pausing or a slow render frame never consumes it.
const AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS := 1.5
const AUTOMATIC_ENGINE_INTENT_EPSILON := 0.001
const SHIP_LAYER := PhysicsLayers.SHIP
const WORLD_LAYER := PhysicsLayers.WORLD
const TARGET_LAYER := PhysicsLayers.TARGET
const WEAPON_AIM_MASK := PhysicsLayers.HITSCAN_QUERY_MASK
const WEAPON_AIM_DISTANCE := 1000.0
const FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR := 0.30
## The pulse cannons reward short bursts without turning ordinary taps into
## resource management. Heat is presentation/gameplay state on this existing
## fire gate; projectile damage remains owned by the existing resolver path.
const WEAPON_HEAT_PER_SHOT := 0.28
const WEAPON_HEAT_COOLING_PER_SECOND := 0.50
const WEAPON_OVERHEAT_DURATION := 1.0
const WEAPON_RECOVERY_HEAT := 0.35
## Damaged propulsion reduces pilot-commanded braking, but retained attitude
## jets preserve a bounded emergency floor even after the main engine fails.
## Automatic landing/cruise safety braking remains independently authoritative.
const FAILED_ENGINE_MANUAL_BRAKE_FACTOR := 0.35
const DEPARTURE_SPEED_THRESHOLD := 0.25
const DEPARTURE_MOTION_EPSILON_SQUARED := 0.000001
const PLANETARY_CRUISE_PHYSICAL_SCHEMA_VERSION := 1
const PLANETARY_CRUISE_ENVELOPE_SCHEMA_VERSION := 1
const PLANETARY_CRUISE_MAX_SAFE_INTEGER := 9_007_199_254_740_991
const PLANETARY_CRUISE_MAX_SPEED_METERS_PER_SECOND := 100_000.0
const PLANETARY_CRUISE_MAX_ACCELERATION_METERS_PER_SECOND_SQUARED := 10_000.0
const PLANETARY_CRUISE_DIRECTION_EPSILON := 0.00001
const RESET_FOR_REUSE_SCHEMA_VERSION := 1
const RESET_FOR_REUSE_MAX_SAFE_RECEIPT_ID := 9_007_199_254_740_991
const RESET_FOR_REUSE_RESULT_KEYS := [
	"schema_version",
	"accepted",
	"reason",
	"phase",
	"receipt_id",
	"ship_instance_id",
	"spawn_transform",
	"destruction_serial",
	"component_instance_id",
	"component_revision",
	"planetary_cruise_attachment_generation",
]
const PLANETARY_CRUISE_STATE_INACTIVE: StringName = &"inactive"
const PLANETARY_CRUISE_STATE_ACCELERATING: StringName = &"accelerating"
const PLANETARY_CRUISE_STATE_CRUISING: StringName = &"cruising"
const PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED: StringName = &"braking_to_speed"
const PLANETARY_CRUISE_STATE_BRAKING: StringName = &"braking"
const PLANETARY_CRUISE_CLEARANCE_PROOF_KEYS := [
	"accepted",
	"reason",
	"schema_version",
	"ship_instance_id",
	"ship_attachment_generation",
	"coordinate_frame_generation",
	"proof_sequence",
	"controller_instance_id",
	"direction_world",
	"sweep_distance_meters",
	"verified_clearance_meters",
	"clearance_full_hull",
	"clearance_verified",
	"obstacle_detected",
	"enabled_shape_count",
	"queried_shape_count",
	"shape_names",
	"shape_transforms",
	"collision_mask",
	"fixed_orientation_basis",
	"ship_position_world",
	"velocity_world",
	"ship_speed_meters_per_second",
	"alignment_basis",
	"alignment_dot",
	"closing_speed_meters_per_second",
	"currently_participating",
]
const PLANETARY_CRUISE_ENVELOPE_KEYS := [
	"schema_version",
	"ship_instance_id",
	"ship_attachment_generation",
	"controller_instance_id",
	"controller_generation",
	"sequence",
	"coordinate_frame_generation",
	"destination_direction_world",
	"desired_participation",
	"desired_speed_meters_per_second",
	"acceleration_hint_meters_per_second_squared",
	"braking_requested",
	"braking_acceleration_hint_meters_per_second_squared",
	"policy_reason",
	"observation",
	"clearance_proof_sequence",
	"clearance_proof_generation",
	"clearance_full_hull",
	"clearance_verified",
	"obstacle_detected",
]
const LANDING_CONTRACT_SCHEMA_VERSION := 3
const LANDING_TIMEOUT_SECONDS := 24.0
const LANDING_STALL_TIMEOUT_SECONDS := 4.0
const LANDING_PROGRESS_EPSILON := 0.0001
const LANDING_COMPLETION_DISTANCE := 0.16
const LANDING_COMPLETION_SPEED := 0.5
const LANDING_COMPLETION_ANGLE_DEGREES := 1.5
const LANDING_BRAKE_COMPLETE_SPEED := 1.5
const LANDING_STAGING_COMPLETION_DISTANCE := 0.45
const LANDING_STAGING_COMPLETION_SPEED := 0.75
const LANDING_ALIGNMENT_COMPLETION_DISTANCE := 0.35
const LANDING_ALIGNMENT_COMPLETION_ANGLE_DEGREES := 2.0
const LANDING_TRANSFORM_EPSILON := 0.0001
const LANDING_ROTATION_GUARD_ANGLE_DEGREES := 0.1
const LANDING_PHASE_NONE: StringName = &"none"
const LANDING_PHASE_BRAKE: StringName = &"brake"
const LANDING_PHASE_MOVE_TO_STAGING: StringName = &"move_to_staging"
const LANDING_PHASE_ALIGN: StringName = &"align"
const LANDING_PHASE_FINAL_APPROACH: StringName = &"final_approach"
const LANDING_PHASE_DOCKED: StringName = &"docked"
const LANDING_PHASE_ABORTED: StringName = &"aborted"
const CHASE_CAMERA_OFFSET := Vector3(0.0, 5.0, 14.5)
const CHASE_CAMERA_PITCH := 0.0
const CHASE_CAMERA_SELF_HULL_CLEARANCE := 0.02
const CHASE_CAMERA_BOUNDARY_EPSILON := 0.0001
const CANOPY_OPEN_ANGLE := deg_to_rad(63.0)
const CAMERA_VIEW_ACTION: StringName = &"toggle_ship_camera_view"
const CAMERA_VIEW_CHASE: StringName = &"CHASE"
const CAMERA_VIEW_COCKPIT: StringName = &"COCKPIT"
const ShipCommandType := preload("res://scripts/control/ship_command.gd")
const LocalShipInputSourceType := preload("res://scripts/control/local_ship_input_source.gd")
const PlanetaryCruisePolicyType := preload(
	"res://scripts/world/planetary_cruise_policy.gd"
)
const TORRENT_AUTHORED_MACROFORM_SCENE := preload(
	"res://scenes/ships/presentation/torrent_authored_macroform.tscn"
)
const TORRENT_HERO_PRESENTATION_SCENE := preload(
	"res://scenes/ships/presentation/torrent_hero_presentation.tscn"
)

const HULL_IVORY := Color("e8ece5")
const HULL_LIGHT := Color("f8f6e9")
const HULL_MID := Color("aeb8b6")
const STRUCTURE := Color("263b45")
const STRUCTURE_DARK := Color("07141c")
const COCKPIT_BLUE := Color(0.10, 0.62, 0.72, 0.38)
const KETH_CYAN := Color("48dbe2")
const WARM_GOLD := Color("f0b94d")
const ENGINE_BLUE := Color("64efff")
const NAV_RED := Color("ff5c55")
const NAV_GREEN := Color("78ee9b")
const TORRENT_ART_SCHEMA_VERSION := 3
const TORRENT_GEOMETRY_STATUS: StringName = &"source_aligned_partial"
const TORRENT_IDENTITY_LOCK: StringName = &"b5_observed_name_to_model"
const TORRENT_RECONSTRUCTION_STATUS: StringName = &"partial"
const TORRENT_2009_CONTINUITY: StringName = &"unproved"
const TORRENT_VENT_LOUVERS_PER_BANK := 6
const TORRENT_VENT_LOUVER_COPY_COUNT := 12
const TORRENT_CAPTURE_JAW_COPY_COUNT := 4
const TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER := 2
const TORRENT_RCS_THRUSTER_PORT_COPY_COUNT := 8
# Component-local render census retains all close art and semantic/system roots.
# Two louvre and four RCS-port batches retain every source-local copy while
# reducing fallback submissions; shared capture jaws retain their named paths.
const TORRENT_RENDER_DESCENDANT_COUNT := 295
const TORRENT_RENDER_MESH_INSTANCE_COUNT := 233
const TORRENT_RENDER_MULTIMESH_BATCH_COUNT := 6
const TORRENT_RENDER_DRAWN_COPY_COUNT := 253
const TORRENT_RENDER_GEOMETRY_SUBMISSION_COUNT := 239
const TORRENT_RENDER_UNIQUE_MESH_RESOURCE_COUNT := 209
const TORRENT_RENDER_UNIQUE_MATERIAL_RESOURCE_COUNT := 37
const TORRENT_MODERN_DESCENDANT_COUNT := 109
const TORRENT_MODERN_MESH_INSTANCE_COUNT := 87
const TORRENT_MODERN_DRAWN_COPY_COUNT := 107
const TORRENT_MODERN_GEOMETRY_SUBMISSION_COUNT := 93
const TORRENT_MODERN_UNIQUE_MESH_RESOURCE_COUNT := 74
const TORRENT_MODERN_UNIQUE_MATERIAL_RESOURCE_COUNT := 11

@export_category("Identity")
@export var ship_id: StringName = &"torrent_test_article_01"
@export var display_name := "Torrent-class Interceptor"
@export var role_name := "Interceptor"
@export var home_berth_id: StringName = &"central_berth"
@export var identification_accent := WARM_GOLD
@export var ship_definition: ShipDefinition

@export_category("Flight")
@export_range(10.0, 180.0, 1.0) var maximum_speed := 82.0
@export_range(1.0, 80.0, 1.0) var thrust_acceleration := 34.0
@export_range(1.0, 80.0, 1.0) var brake_acceleration := 48.0
@export_range(0.1, 20.0, 0.1) var passive_drag := 2.8
@export_range(1.0, 30.0, 0.5) var throttle_response := 10.0
@export_range(10.0, 180.0, 1.0) var boost_speed := 118.0
@export_range(0.1, 4.0, 0.05) var boost_multiplier := 1.55
@export_range(10.0, 180.0, 1.0) var yaw_speed_degrees := 72.0
@export_range(10.0, 240.0, 1.0) var roll_speed_degrees := 108.0
@export_range(0.0002, 0.02, 0.0001) var mouse_sensitivity := 0.0022
@export var invert_mouse_y := false
@export_range(0.1, 12.0, 0.1) var flight_assist_strength := 5.8
@export_range(0.0, 30.0, 0.5) var visual_bank_degrees := 13.0
@export_range(1.0, 45.0, 1.0) var maximum_mouse_turn_degrees := 18.0

@export_category("Camera")
@export_range(6.0, 20.0, 0.25) var minimum_chase_camera_distance := 9.0
@export_range(12.0, 36.0, 0.25) var maximum_chase_camera_distance := 24.0
@export_range(0.25, 4.0, 0.05) var chase_camera_zoom_step := 1.5
@export_range(1.0, 30.0, 0.5) var chase_camera_zoom_response := 9.0
@export_range(1.0, 30.0, 0.5) var chase_camera_rotation_response := 7.0
@export_range(0.0, 12.0, 0.25) var maximum_chase_camera_rotation_lag_degrees := 8.0
@export_range(0.1, 1.2, 0.05) var chase_camera_collision_radius := 0.55
@export_range(0.05, 1.0, 0.05) var chase_camera_collision_margin := 0.45
# The seated pilot's visor front is around local Z -0.28. Keeping the camera
# forward of that shell preserves the embodied exterior pilot without putting
# first-person vision inside the helmet mesh.
@export var cockpit_camera_position := Vector3(0.0, 3.32, -0.52)

@export_category("Systems")
@export_range(0.1, 8.0, 0.1) var engine_start_time := 2.0
@export_range(0.05, 2.0, 0.05) var weapon_cooldown := 0.22
@export_range(1.0, 1000.0, 1.0) var maximum_hull := 100.0
@export_range(5.0, 40.0, 0.5) var landing_range := 24.0
@export_range(1.0, 40.0, 0.5) var landing_maximum_speed := 20.0
@export_range(1.0, 80.0, 0.5) var impact_damage_threshold := 45.0
@export_range(0.1, 12.0, 0.1) var impact_damage_scale := 1.5
@export_range(0.05, 2.0, 0.05) var impact_damage_cooldown := 0.35

var _engine_state: StringName = ENGINE_OFFLINE
var _piloted := false
var _landed := true
var _landing_active := false
var _docked_latch := false
var _landing_target := Transform3D.IDENTITY
var _landing_berth: WeakRef
var _landing_contract := {}
var _landing_berth_instance_id := 0
var _landing_berth_parent_instance_id := 0
var _landing_berth_id: StringName = &""
var _landing_reservation_token: StringName = &""
var _landing_reserved_ship_id: StringName = &""
var _landing_half_extents_snapshot := Vector3.ZERO
var _landing_capture_center_snapshot := Vector3.ZERO
var _landing_capture_half_extents_snapshot := Vector3.ZERO
var _landing_capture_maximum_speed_snapshot := 0.0
var _landing_capture_maximum_tilt_snapshot := 0.0
var _landing_staging_target := Transform3D.IDENTITY
var _landing_phase: StringName = LANDING_PHASE_NONE
var _landing_after_brake_phase: StringName = LANDING_PHASE_FINAL_APPROACH
var _landing_elapsed := 0.0
var _landing_stall_elapsed := 0.0
var _landing_previous_distance := INF
var _landing_last_abort_reason: StringName = &""
var _engine_timer := 0.0
var _automatic_engine_idle_elapsed := 0.0
var _weapon_timer := 0.0
var _weapon_heat := 0.0
var _weapon_overheated := false
var _weapon_overheat_remaining := 0.0
var _throttle := 0.0
var _hull := 100.0
var _critical_damage_emitted := false
var _deferred_terminal_presentation_receipt_id := -1
var _destroyed_hull_hide_pending := false
var _travel_sign := 1.0
var _roll_animation := 0.0
var _visual_bank := 0.0
var _elapsed := 0.0
var _impact_cooldown_remaining := 0.0
## Synchronous scope flag used only while a resolved CharacterBody collision is
## passing through the ordinary virtual apply_damage chain. Derived craft keep
## their destruction hooks without needing a second damage entry point.
var _collision_component_routing_active := false
var _destroyed := false
var _destruction_serial := 0
var _built := false
var _canopy_open := false
var _canopy_motion_serial := 0
var _cockpit_view := false
var _target_chase_camera_distance := CHASE_CAMERA_OFFSET.length()
var _chase_follow_rotation := Quaternion.IDENTITY
var _chase_camera_bank := 0.0
var _chase_camera_rotation_lag_degrees := 0.0

## Instance-owned, so the meshes are freed with the craft and never outlive it.
var _chamfered_cylinder_cache: Dictionary = {}

var _visual_root: Node3D
var _cockpit_root: Node3D
var _canopy_pivot: Node3D
var _canopy_tween: Tween
var _pilot_seat_anchor: Marker3D
var _boarding_entry_marker: Marker3D
var _camera_pivot: Node3D
var _camera_spring_arm: SpringArm3D
var _camera_boundary_mount: Node3D
var _camera: Camera3D
var _cockpit_camera: Camera3D
var _boarding_marker: Marker3D
var _exit_marker: Marker3D
var _muzzle_left: Marker3D
var _muzzle_right: Marker3D
var _engine_glows: Array[MeshInstance3D] = []
var _engine_core_glows: Array[MeshInstance3D] = []
var _engine_lights: Array[OmniLight3D] = []
var _engine_exhaust_damage_overlay: StandardMaterial3D
var _engine_exhaust_original_overlays: Dictionary = {}
var _engine_exhaust_original_light_colors: Dictionary = {}
var _weapon_component_emitters: Array[MeshInstance3D] = []
var _weapon_component_original_scales: Dictionary = {}
var _weapon_component_original_overlays: Dictionary = {}
var _weapon_component_original_transparency: Dictionary = {}
var _weapon_component_original_visibility: Dictionary = {}
var _weapon_component_damage_overlay: StandardMaterial3D
var _weapon_component_fallback_mesh: Mesh
var _weapon_component_fallback_node_count := 0
var _weapon_component_fallback_mesh_count := 0
var _weapon_component_presentation_initialized := false
var _materials: Dictionary = {}
var _fire_from_left := true
var _damage_presentation: HeroDamagePresentation
## Observational component model. It never owns hull; see
## `scripts/combat/ship_component_damage.gd` for the authority boundary.
var _component_damage: ShipComponentDamage
## Opaque one-time identity claimed after initial component configuration. It is
## never returned by Hero, so synchronous reset callbacks cannot forge the sole
## component mutation permitted while the whole-ship transaction is guarded.
var _component_damage_owner_capability: RefCounted
var _last_component_damage_revision := -1
## Optional interruption observer only. RepairAuthority retains the reservation
## and interruption decision; this binding neither admits repairs nor mutates
## hull/component health. Multi-crew variants are also discovered through their
## existing `_engineer_repair_authority` property so the shared Hero damage path
## applies identically without duplicating hooks in every craft subclass.
var _repair_damage_interrupt_authority: RefCounted
## Fleet variants replace the temporary common root collision only after the
## base `_ready()` returns. This one-shot gate lets that same initial ready pass
## bind the existing component model to the final live envelope without opening
## a detach/re-entry or reuse reconfiguration path.
var _component_damage_final_collision_capture_open := false
var _component_damage_final_collision_capture_attempted := false
var _component_damage_final_collision_capture_accepted := false
## One accepted preflight privately owns its dependency snapshot until exact
## commit or cancellation. Receipt IDs are process-session monotonic and never
## rewound by reuse or tree detach/re-entry.
var _next_reset_for_reuse_receipt_id := 1
var _pending_reset_for_reuse: Dictionary = {}
var _reset_for_reuse_dispatch_active := false
var _command_source: ShipCommandSource
var _default_local_command_source: LocalShipInputSource
var _last_ship_command: ShipCommand = ShipCommandType.neutral()
## Every direct physics effect shares one replay cursor. A command rejected here
## becomes neutral before flight, look, fire, barrel roll, audio, camera, or visual
## presentation can observe it. Fresh held controls still arrive every physics
## tick with a strictly increasing sequence from the built-in source.
var _last_direct_command_stream_id := -1
var _last_direct_command_sequence := -1
## Camera controls are one-shot command effects, unlike held flight axes. Keep a
## ship-local epoch/sequence high-water mark so a replay source, packet retry, or
## repeated deterministic sample cannot toggle the view or zoom more than once.
## The cursor intentionally survives command-source replacement: a replacement
## must continue with a newer stream epoch rather than making an older snapshot
## current again.
var _last_camera_command_stream_id := -1
var _last_camera_command_sequence := -1
var _cockpit_readout: Label3D
var _cockpit_practical_light: SpotLight3D
var _ship_audio_rig: ShipAudioRig
var _torrent_hero_presentation: TorrentHeroPresentation
var _legacy_torrent_presentation: Node3D
var _legacy_torrent_cockpit_art: Node3D
var _legacy_torrent_canopy_art: Node3D
var _torrent_unknown_function_panel: MeshInstance3D
var _torrent_vent_louver_mesh: ArrayMesh
var _torrent_vent_louver_batches: Array[MultiMeshInstance3D] = []
## Torrent-local and immutable: all four articulated-visual-only capture jaws
## retain their paths and transforms while sharing this exact gold box mesh.
var _torrent_capture_jaw_mesh: ArrayMesh
## The eight RCS ports are immutable, presentation-only copies. Four local
## batches retain the named cluster roots and their parent-space transforms.
var _torrent_rcs_thruster_port_mesh: ArrayMesh
var _torrent_rcs_thruster_port_batches: Array[MultiMeshInstance3D] = []
var _audio_throttle_state := -1.0
var _audio_boost_state := false
## Planetary cruise is an optional, caller-issued envelope inside this body's
## existing physics authority. No external component writes velocity or calls a
## movement method. The attachment generation fences every lifecycle boundary.
var _planetary_cruise_attachment_generation := 1
var _planetary_cruise_state: StringName = PLANETARY_CRUISE_STATE_INACTIVE
var _planetary_cruise_reason: StringName = &"never_engaged"
var _planetary_cruise_pending_envelope: Dictionary = {}
var _planetary_cruise_last_envelope: Dictionary = {}
var _planetary_cruise_pending_clearance_proof: Dictionary = {}
var _planetary_cruise_clearance_proof_sequence := 0
var _planetary_cruise_controller_instance_id := 0
var _planetary_cruise_last_controller_generation := 0
var _planetary_cruise_last_sequence := 0
var _planetary_cruise_coordinate_frame_generation := 0
var _planetary_cruise_direction_world := Vector3.ZERO
var _planetary_cruise_desired_speed := 0.0
var _planetary_cruise_acceleration := 0.0
var _planetary_cruise_braking_acceleration := 0.0
var _planetary_cruise_mutation_active := false
var _planetary_cruise_signal_dispatch_active := false
var _planetary_cruise_policy := PlanetaryCruisePolicyType.new()


func _enter_tree() -> void:
	# Child `_ready()` runs before this ship's `_ready()`. Bind the authored rig to
	# the definition here so it snapshots the exact profile ID for every variant.
	var rig := get_node_or_null("ShipAudioRig") as ShipAudioRig
	if rig != null and ship_definition != null:
		rig.profile_id = ship_definition.audio_profile_id
	if _destroyed and _destroyed_hull_hide_pending:
		call_deferred("_resume_destroyed_hull_hide_after_reentry")


func _exit_tree() -> void:
	# A detached body performs no physics. Fence every envelope captured against
	# the old World3D so re-entry requires a new physical proof and submission.
	_retire_planetary_cruise(&"ship_detached", true)


func _ready() -> void:
	_apply_ship_definition()
	_hull = maximum_hull
	_ensure_camera_view_input_action()
	_ensure_command_source()
	_build_ship()
	_damage_presentation = get_node_or_null("HeroDamagePresentation") as HeroDamagePresentation
	_ship_audio_rig = get_node_or_null("ShipAudioRig") as ShipAudioRig
	if _ship_audio_rig != null:
		_ship_audio_rig.set_engine_running(_engine_state == ENGINE_ONLINE, false)
		_ship_audio_rig.set_thrust_state(0.0, false)
		_ship_audio_rig.set_damage_alarm_active(false)
		_audio_throttle_state = 0.0
		_audio_boost_state = false
	if _damage_presentation != null:
		_damage_presentation.stage_changed.connect(_on_damage_stage_changed)
		_damage_presentation.deferred_component_impact_committed.connect(
			_on_deferred_component_impact_committed
		)
		_sync_damage_presentation()
	_ensure_component_damage()
	if _damage_presentation != null and _component_damage != null \
			and _component_damage.is_configured():
		_damage_presentation.bind_component_generation(
			_component_damage.get_ledger_generation()
		)
	_component_damage_final_collision_capture_open = true
	call_deferred("_close_component_damage_final_collision_capture")
	# Fleet subclasses finish replacing the base visual after super._ready().
	# Discover their retained muzzle lenses only after that replacement settles.
	call_deferred("_initialize_weapon_component_presentation")
	_set_camera_current(_piloted)
	if _piloted and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Production holds a preflight for one synchronous GameFlow call. Freezing the
	# body also makes a deliberately delayed external transaction deterministic.
	if _reset_for_reuse_mutation_blocked():
		return
	_elapsed += delta
	_weapon_timer = maxf(0.0, _weapon_timer - delta)
	_update_weapon_heat(maxf(delta, 0.0))
	_impact_cooldown_remaining = maxf(0.0, _impact_cooldown_remaining - delta)
	# One immutable command is sampled for this entire simulation tick. Flight,
	# weapon, camera, and presentation consumers all observe the same snapshot.
	var sampled_command := _sample_ship_command()
	var direct_command_accepted := _claim_direct_command(sampled_command)
	var command := (
		sampled_command
		if direct_command_accepted
		else _neutralized_command_snapshot(sampled_command)
	)
	_last_ship_command = command
	var camera_changed := (
		consume_sampled_camera_edges(command)
		if _piloted and direct_command_accepted
		else false
	)
	if _command_interrupts_planetary_cruise(command):
		_retire_planetary_cruise(&"manual_flight_command", true)
	_update_automatic_engine_control(delta, command)
	_update_engine(delta)
	if _landing_active:
		_update_landing(delta)
	elif _piloted and _engine_state == ENGINE_ONLINE and not _docked_latch:
		if not _update_planetary_cruise_physics(delta):
			_update_flight(delta, command, camera_changed)
	else:
		# Looking around during boarding, startup, landing, or shutdown must not
		# become a queued steering command on the first active flight frame.
		_clear_pending_look_motion()
		velocity = velocity.move_toward(Vector3.ZERO, passive_drag * delta)
		if not _landed:
			move_and_slide()
	# Publish the state produced by this immutable command, including same-tick
	# throttle, boost, landing, shutdown, and destruction transitions.
	_sync_ship_audio(command)
	_update_presentation(delta, command)
	_sync_damage_presentation()
	_sync_component_damage(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if not _piloted:
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed:
			if not _cockpit_view and button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_queue_camera_distance_delta(-1.0)
				get_viewport().set_input_as_handled()
				return
			if not _cockpit_view and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_queue_camera_distance_delta(1.0)
				get_viewport().set_input_as_handled()
				return
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
				return
	if (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not _landing_active
	):
		var motion := event as InputEventMouseMotion
		_queue_look_motion(motion.relative)


## Enables or suspends flight controls and whichever ship camera was selected.
func set_piloted(piloted: bool) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	_ensure_command_source()
	_invalidate_command_delivery(_command_source)
	if _piloted != piloted:
		_retire_planetary_cruise(
			&"pilot_attached" if piloted else &"pilot_unseated",
			true
		)
	_piloted = piloted
	# No producer may carry undelivered lifecycle edges across a pilot-authority
	# boundary. The local adapter additionally starts a new stream epoch and clears
	# device-specific edge/mouse accumulation; remote/replay producers otherwise
	# retain their explicitly managed stream identity.
	if _command_source is LocalShipInputSource:
		(_command_source as LocalShipInputSource).reset_stream()
	_set_camera_current(piloted)
	if piloted:
		_snap_chase_camera_response()
		boarded.emit()
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_clear_pending_look_motion()


## Backwards-compatible deterministic mouse hook. Both test-injected motion and
## real `_unhandled_input()` events are forwarded to the current source, so the
## ship never maintains a second accumulator or consumes one event twice.
func apply_look_motion(relative: Vector2) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _piloted and not _landing_active:
		_queue_look_motion(relative)


## Replaces the local InputMap adapter with an AI, replay, or network producer.
## Passing null restores the ship-owned local source. The producer remains the
## authority boundary: disabled or non-owner sources yield neutral commands.
## Stream epochs are ship-global replay authority: a replacement producer must
## begin above the newest epoch this ship has consumed. Merely swapping Node
## instances never makes an older captured command current again.
func set_command_source(source: ShipCommandSource) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	var outgoing_source := _command_source
	_invalidate_command_delivery(outgoing_source)
	if source == null:
		_ensure_default_local_command_source()
		_command_source = _default_local_command_source
	else:
		_command_source = source
	if _command_source != outgoing_source:
		_invalidate_command_delivery(_command_source)
	_configure_command_source()
	_rebase_command_source_above_ship_cursor(_command_source)


func get_command_source() -> ShipCommandSource:
	_ensure_command_source()
	return _command_source


## The ship-retained production InputMap source, even while an injected replay,
## AI, or network source temporarily owns the active command stream. Runtime
## settings configure this identity so restoring local control cannot resurrect
## an obsolete profile.
func get_local_input_source() -> LocalShipInputSource:
	_ensure_default_local_command_source()
	return _default_local_command_source


## Returns the exact snapshot consumed by the most recent physics tick.
func get_last_ship_command() -> ShipCommand:
	return _last_ship_command


## Applies camera one-shots from an already sampled command exactly once and in
## stream order. The public seam is also used by GameFlow's deterministic
## InputEventAction compatibility path, which samples immediately instead of
## waiting for the next physics callback. Held flight state is never applied here.
func consume_sampled_camera_edges(command: ShipCommand) -> bool:
	if _reset_for_reuse_mutation_blocked():
		return false
	if not _piloted or not _claim_camera_command(command):
		return false
	var camera_changed := false
	if command.camera_toggle:
		toggle_camera_view()
		camera_changed = true
	if not _cockpit_view and not is_zero_approx(command.camera_distance_delta):
		adjust_chase_camera_distance(
			chase_camera_zoom_step * command.camera_distance_delta
		)
	return camera_changed


func _claim_camera_command(command: ShipCommand) -> bool:
	if command == null or not command.is_valid():
		return false
	# Boundary invalidation advances the live source epoch immediately. This fence
	# revokes a snapshot already returned to another synchronous caller even when
	# no post-boundary sample has yet advanced the ship's own replay cursor.
	if is_instance_valid(_command_source):
		if _command_source.is_stream_exhausted():
			return false
		# A producer's live epoch is also its revocation fence. Accepting a packet
		# from a numerically future epoch would let a later focus/pause invalidation
		# advance only the source ledger and fail to revoke the captured packet.
		if command.stream_id != _command_source.get_stream_id():
			return false
	if command.stream_id < _last_camera_command_stream_id:
		return false
	if (
		command.stream_id == _last_camera_command_stream_id
		and command.sequence <= _last_camera_command_sequence
	):
		return false
	_last_camera_command_stream_id = command.stream_id
	_last_camera_command_sequence = command.sequence
	return true


## Claims the single immutable snapshot that every ship-local physics consumer
## will observe this tick. Stream IDs form one ship-global replay authority across
## source replacement; a duplicate packet, rolled-back replay, or captured command
## revoked by a source boundary cannot steer, fire, roll, or affect presentation.
func _claim_direct_command(command: ShipCommand) -> bool:
	if not _piloted or command == null or not command.is_valid():
		return false
	if is_instance_valid(_command_source):
		if _command_source.is_stream_exhausted():
			return false
		if command.stream_id != _command_source.get_stream_id():
			return false
	if not command.is_strictly_newer_than(
		_last_direct_command_stream_id,
		_last_direct_command_sequence
	):
		return false
	_last_direct_command_stream_id = command.stream_id
	_last_direct_command_sequence = command.sequence
	return true


func _neutralized_command_snapshot(command: ShipCommand) -> ShipCommand:
	if command == null:
		return ShipCommandType.neutral()
	return ShipCommandType.neutral(
		command.sequence,
		command.timestamp_usec,
		command.stream_id
	)


func _ensure_command_source() -> void:
	if is_instance_valid(_command_source):
		_configure_command_source()
		return
	_ensure_default_local_command_source()
	_command_source = _default_local_command_source
	_configure_command_source()


func _ensure_default_local_command_source() -> void:
	if is_instance_valid(_default_local_command_source):
		return
	var existing := get_node_or_null("LocalShipInputSource") as LocalShipInputSource
	if existing != null:
		_default_local_command_source = existing
		return
	_default_local_command_source = LocalShipInputSourceType.new() as LocalShipInputSource
	_default_local_command_source.name = "LocalShipInputSource"
	add_child(_default_local_command_source)


func _configure_command_source() -> void:
	if not (_command_source is LocalShipInputSource):
		return
	var local_source := _command_source as LocalShipInputSource
	# HeroShip is the sole event receiver. Disabling the source Node's own input
	# callback prevents one mouse event being accumulated by both parent and child.
	local_source.capture_mouse_motion = false


func _sample_ship_command() -> ShipCommand:
	_ensure_command_source()
	if not _piloted or not is_instance_valid(_command_source):
		return ShipCommandType.neutral()
	if _command_source is LocalShipInputSource:
		var local_source := _command_source as LocalShipInputSource
		var maximum_turn := deg_to_rad(maximum_mouse_turn_degrees)
		var safe_sensitivity := maxf(absf(mouse_sensitivity), 0.000001)
		# Normalizing at the source and restoring the configured maximum angle in
		# flight preserves the exact legacy pixels*sensitivity response, including
		# its per-frame clamp, while keeping the command transport range bounded.
		local_source.look_motion_for_full_axis = maximum_turn / safe_sensitivity
		local_source.invert_look_y = invert_mouse_y
	var sampled := _command_source.next_command()
	if sampled == null or not sampled.is_valid():
		return ShipCommandType.neutral()
	return sampled


func _queue_look_motion(relative: Vector2) -> void:
	_ensure_command_source()
	if not relative.is_finite() or not is_instance_valid(_command_source):
		return
	if _command_source.has_method(&"queue_look_motion"):
		_command_source.call(&"queue_look_motion", relative)


## Mouse-wheel and controller chase-distance changes use the same immutable
## command stream as flight. This prevents render/input callbacks from mutating
## the camera outside the simulation tick or replaying a queued device edge.
func _queue_camera_distance_delta(delta_steps: float) -> void:
	_ensure_command_source()
	if (
		not is_finite(delta_steps)
		or is_zero_approx(delta_steps)
		or not is_instance_valid(_command_source)
	):
		return
	if _command_source.has_method(&"queue_camera_distance_delta"):
		_command_source.call(&"queue_camera_distance_delta", delta_steps)


func _clear_pending_look_motion() -> void:
	if not is_instance_valid(_command_source):
		return
	if _command_source.has_method(&"clear_pending_look_motion"):
		_command_source.call(&"clear_pending_look_motion")


func _invalidate_command_delivery(source: ShipCommandSource) -> void:
	if is_instance_valid(source) and source.has_method(&"invalidate_pending_commands"):
		source.call(&"invalidate_pending_commands")


## Built-in producers own their sequence ledger, while the ship owns replay
## authority across producer replacement. Bring an attached ledger strictly above
## the newest command already accepted by either direct physics or the immediate
## camera compatibility seam. Replay sources that override next_command() remain
## responsible for supplying matching/newer packet metadata and are fenced if not.
func _rebase_command_source_above_ship_cursor(source: ShipCommandSource) -> void:
	if not is_instance_valid(source) or source.is_stream_exhausted():
		return
	var high_stream := _last_direct_command_stream_id
	var high_sequence := _last_direct_command_sequence
	if (
		_last_camera_command_stream_id > high_stream
		or (
			_last_camera_command_stream_id == high_stream
			and _last_camera_command_sequence > high_sequence
		)
	):
		high_stream = _last_camera_command_stream_id
		high_sequence = _last_camera_command_sequence
	if high_stream < 0:
		return
	if source.get_stream_id() > high_stream:
		return
	if (
		source.get_stream_id() == high_stream
		and source.get_next_sequence() > high_sequence
	):
		return
	if high_stream < ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER:
		source.reset_stream(0, -1, high_stream + 1)
	elif (
		high_sequence < ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		and source.get_stream_id() < ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
	):
		source.reset_stream(high_sequence + 1, -1, high_stream)
	else:
		# No lexicographically newer pair exists. Move to the terminal ledger; its
		# first non-newer return is rejected and the following request exhausts it.
		source.reset_stream(
			ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
			-1,
			ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		)


## Selects the physical first-person cockpit or the collision-safe chase rig.
## The preference persists across disembarking so the next boarding restores it.
func set_cockpit_view(enabled: bool) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _cockpit_view == enabled:
		return
	_cockpit_view = enabled
	# A view change is an explicit mode boundary. Discarding motion gathered in
	# the prior view prevents a same-frame mouse event becoming an attitude snap.
	_clear_pending_look_motion()
	_snap_chase_camera_response()
	_set_camera_current(_piloted)
	camera_view_changed.emit(get_camera_view())


## Toggles between chase and first-person cockpit views, returning the new state.
func toggle_camera_view() -> bool:
	set_cockpit_view(not _cockpit_view)
	return _cockpit_view


func is_cockpit_view() -> bool:
	return _cockpit_view


## Stable action name for future settings and HUD integrations.
func get_camera_view_action() -> StringName:
	return CAMERA_VIEW_ACTION


func get_camera_view() -> StringName:
	return CAMERA_VIEW_COCKPIT if _cockpit_view else CAMERA_VIEW_CHASE


## Sets the desired unobstructed chase distance; the visible rig eases toward it.
func set_chase_camera_distance(distance: float) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	_target_chase_camera_distance = _clamp_chase_camera_distance(distance)


func adjust_chase_camera_distance(delta_distance: float) -> void:
	set_chase_camera_distance(_target_chase_camera_distance + delta_distance)


## Returns the requested distance rather than a temporary collision retraction.
func get_chase_camera_distance() -> float:
	return _target_chase_camera_distance


## Returns the smoothed, unobstructed arm length. SpringArm3D may safely place
## its camera closer than this value when level geometry blocks the sweep.
func get_current_chase_camera_distance() -> float:
	return _camera_spring_arm.spring_length if _camera_spring_arm != null else 0.0


## Structured witness for the collision-safe chase rig. The SpringArm owns
## external obstruction distance; this report proves that its resolved endpoint
## and all four near-plane corners also remain outside this craft's enabled root
## collision envelope after the self-hull correction is applied.
func get_chase_camera_self_hull_boundary_report() -> Dictionary:
	var collision := get_landing_collision_report()
	var bounds := collision.get("local_bounds", AABB()) as AABB
	if _camera == null or _camera_boundary_mount == null \
			or not bool(collision.get("valid", false)) or not bounds.has_volume():
		return {
			"valid": false,
			"reason": &"camera_or_collision_boundary_unavailable",
			"sample_count": 0,
			"required_clearance_m": CHASE_CAMERA_SELF_HULL_CLEARANCE,
			"base_signed_clearance_m": -INF,
			"signed_clearance_m": -INF,
			"correction_m": 0.0,
			"collision_bounds": bounds,
			"samples_local": {},
		}
	var base_samples := _chase_camera_boundary_samples(_camera_boundary_mount.global_position)
	var live_samples := _chase_camera_boundary_samples(_camera.global_position)
	var base_clearance := _minimum_signed_aabb_clearance(base_samples, bounds)
	var live_clearance := _minimum_signed_aabb_clearance(live_samples, bounds)
	var correction := (
		_camera.global_position - _camera_boundary_mount.global_position
	).dot(global_basis.y.normalized())
	var samples_local := {}
	for sample_name: StringName in live_samples:
		samples_local[sample_name] = to_local(live_samples[sample_name] as Vector3)
	return {
		"valid": live_clearance \
			>= CHASE_CAMERA_SELF_HULL_CLEARANCE - CHASE_CAMERA_BOUNDARY_EPSILON,
		"reason": &"clear" if live_clearance \
			>= CHASE_CAMERA_SELF_HULL_CLEARANCE - CHASE_CAMERA_BOUNDARY_EPSILON \
			else &"near_plane_intersects_own_hull",
		"sample_count": live_samples.size(),
		"required_clearance_m": CHASE_CAMERA_SELF_HULL_CLEARANCE,
		"base_signed_clearance_m": base_clearance,
		"signed_clearance_m": live_clearance,
		"correction_m": correction,
		"collision_bounds": bounds,
		"samples_local": samples_local,
	}


## Angular separation between the chase boom's softened orbit and the physical
## ship attitude. The optical camera itself remains nose-aligned at all times.
func get_current_chase_camera_rotation_lag_degrees() -> float:
	return _chase_camera_rotation_lag_degrees


## Internal lifecycle/AI compatibility seam; local player input never calls it.
## Begins the deliberate legacy start sequence and releases a docked latch.
func request_engine_start() -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _engine_state != ENGINE_OFFLINE or _hull <= 0.0 or _destroyed:
		return
	_docked_latch = false
	_automatic_engine_idle_elapsed = 0.0
	_engine_state = ENGINE_STARTING
	_engine_timer = engine_start_time
	_sync_engine_visuals_immediately()
	if _ship_audio_rig != null:
		_ship_audio_rig.play_cue(ShipAudioRig.CUE_STARTUP)
	engine_state_changed.emit(_engine_state)


## Internal lifecycle/AI/test compatibility seam; it is not a player control.
## Stops thrust immediately. Shutdown is accepted at any time for safety.
func request_engine_stop(play_transition_cue: bool = true) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _engine_state == ENGINE_OFFLINE:
		return
	_engine_state = ENGINE_OFFLINE
	_engine_timer = 0.0
	_automatic_engine_idle_elapsed = 0.0
	_throttle = 0.0
	_sync_engine_visuals_immediately()
	if _ship_audio_rig != null:
		_ship_audio_rig.set_engine_running(false, play_transition_cue)
		_ship_audio_rig.set_thrust_state(0.0, false)
	engine_state_changed.emit(_engine_state)


## Engages automatic landing when the craft is close and slow enough. A full
## Transform3D preserves side-berth orientation; Vector3 remains accepted for
## compatibility with the original central-pad API and older tests.
func request_landing(target: Variant) -> bool:
	if _reset_for_reuse_mutation_blocked():
		return false
	if _engine_state != ENGINE_ONLINE or _landing_active or _destroyed:
		return false
	var target_transform := Transform3D.IDENTITY
	if target is Transform3D:
		target_transform = target as Transform3D
	elif target is Vector3:
		target_transform = Transform3D(Basis.IDENTITY, target as Vector3)
	else:
		return false
	target_transform.basis = target_transform.basis.orthonormalized()
	var target_position := target_transform.origin
	var horizontal_offset := Vector2(global_position.x - target_position.x, global_position.z - target_position.z)
	if horizontal_offset.length() > landing_range:
		return false
	if absf(global_position.y - target_position.y) > 14.0 or velocity.length() > landing_maximum_speed:
		return false
	_begin_landing_assist(
		target_transform,
		target_transform,
		LANDING_PHASE_FINAL_APPROACH,
		{}
	)
	return true


## Production landing entry point. A separate broad capture contract permits
## any yaw and a generous non-inverted attitude, then stages the craft before
## alignment and final descent. The narrow target-only API above stays unchanged
## for legacy callers; it is deliberately not allowed to veto a berth-approved
## accessibility capture.
func request_berth_landing(berth: ShipBerth) -> bool:
	if _reset_for_reuse_mutation_blocked():
		return false
	if _landing_active or _destroyed:
		return false
	if berth == null or not is_instance_valid(berth) or not berth.is_inside_tree():
		_landing_last_abort_reason = &"berth_unavailable"
		return false
	var definition := get_ship_definition()
	var reservation_token := berth.get_reservation_token(self)
	var reserved_ship_id := definition.ship_id if definition != null else &""
	if definition == null \
			or not definition.is_definition_valid() \
			or reservation_token.is_empty() \
			or not berth.can_accept(definition, self) \
			or not berth.has_valid_lease(self, reservation_token, reserved_ship_id):
		_landing_last_abort_reason = &"reservation_lost"
		return false
	var collision_report := get_landing_collision_report()
	if not (collision_report.get("valid", false) as bool):
		_landing_last_abort_reason = &"collision_envelope_invalid"
		return false
	var collision_bounds: AABB = collision_report.get("local_bounds", AABB()) as AABB
	var dock_snapshot := berth.get_dock_transform()
	var acceptance := berth.evaluate_assist_capture_candidate(
		global_transform,
		collision_bounds,
		velocity,
		landing_maximum_speed
	)
	if not (acceptance.get("valid", false) as bool):
		_landing_last_abort_reason = &"berth_acceptance_rejected"
		return false
	var staging_snapshot := berth.get_assist_staging_transform()
	var next_phase := _select_initial_berth_landing_phase(berth, dock_snapshot)
	var phase_after_braking := next_phase
	if velocity.length() > LANDING_BRAKE_COMPLETE_SPEED:
		next_phase = LANDING_PHASE_BRAKE
	_begin_landing_assist(
		dock_snapshot,
		staging_snapshot,
		next_phase,
		acceptance
	)
	_landing_after_brake_phase = phase_after_braking
	_landing_berth = weakref(berth)
	_landing_berth_instance_id = berth.get_instance_id()
	var berth_parent := berth.get_parent()
	_landing_berth_parent_instance_id = (
		berth_parent.get_instance_id() if is_instance_valid(berth_parent) else 0
	)
	_landing_berth_id = berth.get_berth_id()
	_landing_reservation_token = reservation_token
	_landing_reserved_ship_id = reserved_ship_id
	_landing_half_extents_snapshot = berth.get_landing_half_extents()
	_landing_capture_center_snapshot = berth.get_assist_capture_center()
	_landing_capture_half_extents_snapshot = berth.get_assist_capture_half_extents()
	_landing_capture_maximum_speed_snapshot = berth.get_assist_capture_maximum_speed()
	_landing_capture_maximum_tilt_snapshot = berth.get_assist_maximum_tilt_degrees()
	_landing_contract["contract_accepted"] = true
	_landing_contract["strict_dock_acceptance"] = bool(
		acceptance.get("strict_dock_acceptance", false)
	)
	_landing_contract["berth_instance_id"] = _landing_berth_instance_id
	_landing_contract["berth_parent_instance_id"] = _landing_berth_parent_instance_id
	_landing_contract["reserved_ship_id"] = _landing_reserved_ship_id
	_landing_contract["reservation_owner_instance_id"] = get_instance_id()
	_landing_contract["reservation_token_bound"] = true
	_landing_contract["collision_report"] = collision_report.duplicate(true)
	_landing_contract["phase"] = _landing_phase
	_landing_contract["staging_transform_snapshot"] = _landing_staging_target
	_landing_contract["landing_half_extents_snapshot"] = _landing_half_extents_snapshot
	_landing_contract["capture_center_snapshot"] = _landing_capture_center_snapshot
	_landing_contract["capture_half_extents_snapshot"] = _landing_capture_half_extents_snapshot
	_landing_contract["capture_maximum_speed_snapshot"] = _landing_capture_maximum_speed_snapshot
	_landing_contract["capture_maximum_tilt_snapshot"] = _landing_capture_maximum_tilt_snapshot
	if _ship_audio_rig != null:
		_ship_audio_rig.play_landing()
	return true


func _begin_landing_assist(
	dock_target: Transform3D,
	staging_target: Transform3D,
	initial_phase: StringName,
	acceptance: Dictionary
	) -> void:
	_retire_planetary_cruise(&"landing_started", true)
	_landing_target = dock_target
	_landing_staging_target = staging_target
	_landing_active = true
	# A production landing owns propulsion until touchdown. Internal callers can
	# enter this seam without a preceding player command, so guarantee power here.
	_wake_engine_for_automatic_demand()
	_docked_latch = false
	_landed = false
	_throttle = 0.0
	_clear_landing_authority_snapshot()
	_landing_contract = acceptance.duplicate(true)
	_landing_elapsed = 0.0
	_landing_stall_elapsed = 0.0
	_landing_last_abort_reason = &""
	_landing_after_brake_phase = LANDING_PHASE_FINAL_APPROACH
	_set_landing_phase(initial_phase)


func _select_initial_berth_landing_phase(
	berth: ShipBerth,
	dock_target: Transform3D
	) -> StringName:
	# A craft already inside the exact berth should never fly out to the broad
	# staging point. Align in place if needed, then finish the short approach.
	if berth.contains(global_position):
		var angular_error := rad_to_deg(
			Quaternion(global_basis).angle_to(Quaternion(dock_target.basis))
		)
		return (
			LANDING_PHASE_FINAL_APPROACH
			if angular_error <= LANDING_ALIGNMENT_COMPLETION_ANGLE_DEGREES
			else LANDING_PHASE_ALIGN
		)
	return LANDING_PHASE_MOVE_TO_STAGING


func _set_landing_phase(next_phase: StringName) -> void:
	_landing_phase = next_phase
	_landing_stall_elapsed = 0.0
	match next_phase:
		LANDING_PHASE_BRAKE:
			_landing_previous_distance = velocity.length()
		LANDING_PHASE_ALIGN:
			_landing_previous_distance = rad_to_deg(
				Quaternion(global_basis).angle_to(Quaternion(_landing_target.basis))
			)
		LANDING_PHASE_FINAL_APPROACH, LANDING_PHASE_DOCKED:
			_landing_previous_distance = global_position.distance_to(_landing_target.origin)
		_:
			_landing_previous_distance = global_position.distance_to(
				_landing_staging_target.origin
			)
	if not _landing_contract.is_empty():
		_landing_contract["phase"] = _landing_phase


func is_landing_active() -> bool:
	return _landing_active


## Derives a ship-local envelope from every enabled root collision shape. This
## automatically follows the Torrent, Arrow and Jovian collision variants and
## avoids maintaining a second hand-authored hull-size table.
func get_landing_collision_report() -> Dictionary:
	var combined := AABB()
	var has_bounds := false
	var shape_count := 0
	var unsupported := PackedStringArray()
	for child in get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or collision.shape == null:
			continue
		var shape_bounds := _shape_local_bounds(collision.shape)
		if shape_bounds.size == Vector3.ZERO:
			unsupported.append(str(collision.name))
			continue
		var transformed := _transformed_local_aabb(collision.transform, shape_bounds)
		combined = transformed if not has_bounds else combined.merge(transformed)
		has_bounds = true
		shape_count += 1
	var errors := PackedStringArray()
	if not has_bounds:
		errors.append("no_supported_root_collision_shapes")
	if not unsupported.is_empty():
		errors.append("unsupported_root_collision_shapes")
	return {
		"schema_version": LANDING_CONTRACT_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"local_bounds": combined,
		"shape_count": shape_count,
		"unsupported_shapes": unsupported,
	}


## Binds exactly one caller-owned cruise controller to this lifecycle epoch.
## The controller receives no movement capability: it can only submit validated,
## detached envelopes that this body may consume during its own physics step.
func attach_planetary_cruise_controller(
	controller_instance_id: int,
	expected_attachment_generation: int
) -> Dictionary:
	if _reset_for_reuse_mutation_blocked() \
			or _planetary_cruise_mutation_active or _planetary_cruise_signal_dispatch_active:
		return _planetary_cruise_receipt(false, &"reentrant_call")
	if not _planetary_cruise_body_is_live():
		return _planetary_cruise_receipt(false, &"ship_unavailable")
	if expected_attachment_generation != _planetary_cruise_attachment_generation:
		return _planetary_cruise_receipt(false, &"attachment_generation_mismatch")
	if _planetary_cruise_state == PLANETARY_CRUISE_STATE_BRAKING:
		return _planetary_cruise_receipt(false, &"braking_in_progress")
	if controller_instance_id <= 0:
		return _planetary_cruise_receipt(false, &"invalid_controller_instance_id")
	var controller_candidate := instance_from_id(controller_instance_id)
	if not controller_candidate is Node \
		or not is_instance_valid(controller_candidate) \
		or (controller_candidate as Node).is_queued_for_deletion() \
		or not (controller_candidate as Node).is_inside_tree():
		return _planetary_cruise_receipt(false, &"controller_unavailable")
	if _planetary_cruise_controller_instance_id != 0 \
		and _planetary_cruise_controller_instance_id != controller_instance_id:
		return _planetary_cruise_receipt(false, &"controller_collision")
	if _planetary_cruise_controller_instance_id == controller_instance_id:
		return _planetary_cruise_receipt(true, &"already_attached")
	_planetary_cruise_mutation_active = true
	_planetary_cruise_controller_instance_id = controller_instance_id
	_planetary_cruise_pending_clearance_proof.clear()
	_planetary_cruise_reason = &"controller_attached"
	_planetary_cruise_mutation_active = false
	_emit_planetary_cruise_state_changed()
	return _planetary_cruise_receipt(true, &"attached")


## Performs the current-generation, fixed-orientation sweep proof used by the
## pure PlanetaryCruisePolicy. Every enabled direct collision shape on this body
## is queried with this body's mask; the body itself is the only exclusion.
func build_planetary_cruise_clearance_proof(
	direction_world: Vector3,
	sweep_distance_meters: float,
	coordinate_frame_generation: int,
	expected_attachment_generation: int,
	controller_instance_id: int
) -> Dictionary:
	if _reset_for_reuse_mutation_blocked() \
			or _planetary_cruise_mutation_active or _planetary_cruise_signal_dispatch_active:
		return _planetary_cruise_clearance_receipt(
			false,
			&"reentrant_call",
			direction_world,
			sweep_distance_meters,
			coordinate_frame_generation
		)
	# A newest proof request supersedes any unconsumed capability. A malformed or
	# stale request therefore cannot leave an older clear route or already queued
	# envelope reusable before the body's next physics tick.
	_planetary_cruise_pending_clearance_proof.clear()
	_planetary_cruise_pending_envelope.clear()
	var rejection := _validate_planetary_cruise_query_context(
		direction_world,
		sweep_distance_meters,
		coordinate_frame_generation,
		expected_attachment_generation,
		controller_instance_id
	)
	if not rejection.is_empty():
		return _planetary_cruise_clearance_receipt(
			false,
			rejection,
			direction_world,
			sweep_distance_meters,
			coordinate_frame_generation
		)
	var enabled_shapes: Array[CollisionShape3D] = []
	for child in get_children():
		if child is CollisionShape3D:
			var collision := child as CollisionShape3D
			if not collision.disabled and collision.shape != null:
				enabled_shapes.append(collision)
	enabled_shapes.sort_custom(func(left: CollisionShape3D, right: CollisionShape3D) -> bool:
		return String(left.name) < String(right.name)
	)
	if enabled_shapes.is_empty():
		return _planetary_cruise_clearance_receipt(
			false,
			&"no_enabled_root_collision_shapes",
			direction_world,
			sweep_distance_meters,
			coordinate_frame_generation
		)
	if collision_mask == 0:
		return _planetary_cruise_clearance_receipt(
			false,
			&"collision_mask_empty",
			direction_world,
			sweep_distance_meters,
			coordinate_frame_generation,
			enabled_shapes.size()
		)
	if _planetary_cruise_clearance_proof_sequence \
		>= PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return _planetary_cruise_clearance_receipt(
			false,
			&"clearance_proof_sequence_exhausted",
			direction_world,
			sweep_distance_meters,
			coordinate_frame_generation,
			enabled_shapes.size()
		)
	var space := get_world_3d().direct_space_state
	var normalized_direction := direction_world.normalized()
	var motion := normalized_direction * sweep_distance_meters
	var minimum_safe_fraction := 1.0
	var obstacle_detected := false
	var queried_shape_count := 0
	var shape_names := PackedStringArray()
	var shape_transforms: Array[Transform3D] = []
	for collision in enabled_shapes:
		shape_names.append(str(collision.name))
		shape_transforms.append(collision.global_transform)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		query.margin = 0.0
		if not space.intersect_shape(query, 1).is_empty():
			minimum_safe_fraction = 0.0
			obstacle_detected = true
			queried_shape_count += 1
			continue
		query.motion = motion
		var cast_result := space.cast_motion(query)
		if cast_result.size() != 2 \
			or not is_finite(float(cast_result[0])) \
			or not is_finite(float(cast_result[1])):
			return _planetary_cruise_clearance_receipt(
				false,
				&"shape_cast_failed",
				direction_world,
				sweep_distance_meters,
				coordinate_frame_generation,
				enabled_shapes.size(),
				queried_shape_count
			)
		var safe_fraction := clampf(float(cast_result[0]), 0.0, 1.0)
		minimum_safe_fraction = minf(minimum_safe_fraction, safe_fraction)
		if safe_fraction < 1.0:
			obstacle_detected = true
		else:
			# `cast_motion()` returns [1, 1] for both a clear sweep and some exact
			# endpoint contacts. Test the closed endpoint explicitly so the proof
			# matches the policy's at-or-before boundary.
			query.motion = Vector3.ZERO
			query.transform = Transform3D(
				collision.global_basis,
				collision.global_position + motion
			)
			if not space.intersect_shape(query, 1).is_empty():
				obstacle_detected = true
		queried_shape_count += 1
	var verified_clearance := sweep_distance_meters * minimum_safe_fraction
	var ship_speed := velocity.length()
	var alignment_basis: StringName
	var alignment_dot: float
	var closing_speed: float
	if ship_speed == 0.0:
		alignment_basis = PlanetaryCruisePolicyType.ALIGNMENT_BASIS_ZERO_SPEED
		alignment_dot = clampf(
			(-global_basis.z.normalized()).dot(normalized_direction),
			-1.0,
			1.0
		)
		closing_speed = 0.0
	else:
		alignment_basis = PlanetaryCruisePolicyType.ALIGNMENT_BASIS_VELOCITY
		alignment_dot = clampf(
			velocity.normalized().dot(normalized_direction),
			-1.0,
			1.0
		)
		closing_speed = ship_speed * alignment_dot
	var proof_sequence := _planetary_cruise_clearance_proof_sequence + 1
	var proof := {
		"accepted": true,
		"reason": &"clearance_proved",
		"schema_version": PLANETARY_CRUISE_PHYSICAL_SCHEMA_VERSION,
		"ship_instance_id": get_instance_id(),
		"ship_attachment_generation": _planetary_cruise_attachment_generation,
		"coordinate_frame_generation": coordinate_frame_generation,
		"proof_sequence": proof_sequence,
		"controller_instance_id": controller_instance_id,
		"direction_world": normalized_direction,
		"sweep_distance_meters": sweep_distance_meters,
		"verified_clearance_meters": verified_clearance,
		"clearance_full_hull": queried_shape_count == enabled_shapes.size(),
		"clearance_verified": queried_shape_count == enabled_shapes.size(),
		"obstacle_detected": obstacle_detected,
		"enabled_shape_count": enabled_shapes.size(),
		"queried_shape_count": queried_shape_count,
		"shape_names": shape_names,
		"shape_transforms": shape_transforms.duplicate(),
		"collision_mask": collision_mask,
		"fixed_orientation_basis": global_basis,
		"ship_position_world": global_position,
		"velocity_world": velocity,
		"ship_speed_meters_per_second": ship_speed,
		"alignment_basis": alignment_basis,
		"alignment_dot": alignment_dot,
		"closing_speed_meters_per_second": closing_speed,
		"currently_participating": _planetary_cruise_state in [
			PLANETARY_CRUISE_STATE_ACCELERATING,
			PLANETARY_CRUISE_STATE_CRUISING,
			PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED,
		],
	}.duplicate(true)
	_planetary_cruise_mutation_active = true
	_planetary_cruise_clearance_proof_sequence = proof_sequence
	_planetary_cruise_pending_clearance_proof = proof.duplicate(true)
	_planetary_cruise_mutation_active = false
	return proof.duplicate(true)


## Queues one exact envelope for the next HeroShip physics step. Acceptance does
## not move the body or alter velocity; it only transfers detached intent into
## the body that already owns physics integration.
func submit_planetary_cruise_envelope(envelope: Dictionary) -> Dictionary:
	if _reset_for_reuse_mutation_blocked() \
			or _planetary_cruise_mutation_active or _planetary_cruise_signal_dispatch_active:
		return _planetary_cruise_receipt(false, &"reentrant_call")
	var validation_reason := _validate_planetary_cruise_envelope(envelope)
	if not validation_reason.is_empty():
		return _planetary_cruise_receipt(false, validation_reason)
	_planetary_cruise_mutation_active = true
	_planetary_cruise_pending_envelope = envelope.duplicate(true)
	_planetary_cruise_pending_clearance_proof.clear()
	_planetary_cruise_last_controller_generation = int(envelope.controller_generation)
	_planetary_cruise_last_sequence = int(envelope.sequence)
	_planetary_cruise_mutation_active = false
	return _planetary_cruise_receipt(true, &"envelope_queued")


## Explicitly retires the bound controller and any pending/active envelope. The
## body begins a bounded HeroShip-owned brake when that is physically allowed.
func disengage_planetary_cruise(
	controller_instance_id: int,
	expected_attachment_generation: int,
	brake_to_stop: bool = true
) -> Dictionary:
	if _reset_for_reuse_mutation_blocked() \
			or _planetary_cruise_mutation_active or _planetary_cruise_signal_dispatch_active:
		return _planetary_cruise_receipt(false, &"reentrant_call")
	if controller_instance_id != _planetary_cruise_controller_instance_id:
		return _planetary_cruise_receipt(false, &"controller_identity_mismatch")
	if expected_attachment_generation != _planetary_cruise_attachment_generation:
		return _planetary_cruise_receipt(false, &"attachment_generation_mismatch")
	_planetary_cruise_pending_envelope.clear()
	_planetary_cruise_pending_clearance_proof.clear()
	_planetary_cruise_controller_instance_id = 0
	if brake_to_stop and _planetary_cruise_can_brake() and velocity.length() > 0.0:
		_planetary_cruise_state = PLANETARY_CRUISE_STATE_BRAKING
		_planetary_cruise_reason = &"explicit_disengage"
		_planetary_cruise_braking_acceleration = (
			PlanetaryCruisePolicyType.BRAKING_HINT_METERS_PER_SECOND_SQUARED
		)
		_planetary_cruise_attachment_generation = _next_planetary_cruise_generation()
		_emit_planetary_cruise_state_changed()
		return _planetary_cruise_receipt(true, &"braking")
	_retire_planetary_cruise(&"explicit_disengage", true)
	return _planetary_cruise_receipt(true, &"disengaged")


func get_planetary_cruise_attachment_report() -> Dictionary:
	return {
		"schema_version": PLANETARY_CRUISE_PHYSICAL_SCHEMA_VERSION,
		"ship_instance_id": get_instance_id(),
		"ship_attachment_generation": _planetary_cruise_attachment_generation,
		"controller_instance_id": _planetary_cruise_controller_instance_id,
		"attached": _planetary_cruise_controller_instance_id > 0,
		"inside_tree": is_inside_tree(),
		"queued_for_deletion": is_queued_for_deletion(),
		"piloted": _piloted,
		"destroyed": _destroyed,
		"landing_active": _landing_active,
		"state": _planetary_cruise_state,
		"reason": _planetary_cruise_reason,
		"coordinate_frame_generation": _planetary_cruise_coordinate_frame_generation,
		"last_controller_generation": _planetary_cruise_last_controller_generation,
		"last_sequence": _planetary_cruise_last_sequence,
		"pending_envelope": _planetary_cruise_pending_envelope.duplicate(true),
		"pending_clearance_proof": (
			_planetary_cruise_pending_clearance_proof.duplicate(true)
		),
		"last_consumed_envelope": _planetary_cruise_last_envelope.duplicate(true),
		"direction_world": _planetary_cruise_direction_world,
		"desired_speed_meters_per_second": _planetary_cruise_desired_speed,
		"acceleration_meters_per_second_squared": _planetary_cruise_acceleration,
		"braking_acceleration_meters_per_second_squared": (
			_planetary_cruise_braking_acceleration
		),
		"body_owns_velocity": true,
		"body_owns_move_and_slide": true,
	}.duplicate(true)


func get_landing_contract_report() -> Dictionary:
	var berth := _get_landing_berth()
	var lease_still_valid := berth != null \
		and not _landing_reservation_token.is_empty() \
		and berth.has_valid_lease(
			self,
			_landing_reservation_token,
			_landing_reserved_ship_id
		)
	return {
		"schema_version": LANDING_CONTRACT_SCHEMA_VERSION,
		"active": _landing_active,
		"phase": _landing_phase,
		"contract_accepted": bool(_landing_contract.get("contract_accepted", false)),
		"strict_dock_acceptance": bool(_landing_contract.get("strict_dock_acceptance", false)),
		"berth_id": _landing_berth_id,
		"berth_instance_id": _landing_berth_instance_id,
		"berth_parent_instance_id": _landing_berth_parent_instance_id,
		"reserved_ship_id": _landing_reserved_ship_id,
		"reservation_identity_snapshotted": not _landing_reservation_token.is_empty(),
		"reservation_token_bound": lease_still_valid,
		"elapsed": _landing_elapsed,
		"stall_elapsed": _landing_stall_elapsed,
		"timeout_seconds": LANDING_TIMEOUT_SECONDS,
		"stall_timeout_seconds": LANDING_STALL_TIMEOUT_SECONDS,
		"last_abort_reason": _landing_last_abort_reason,
		"target": _landing_target,
		"dock_transform_snapshot": _landing_target,
		"staging_transform_snapshot": _landing_staging_target,
		"landing_half_extents_snapshot": _landing_half_extents_snapshot,
		"capture_center_snapshot": _landing_capture_center_snapshot,
		"capture_half_extents_snapshot": _landing_capture_half_extents_snapshot,
		"capture_maximum_speed_snapshot": _landing_capture_maximum_speed_snapshot,
		"capture_maximum_tilt_snapshot": _landing_capture_maximum_tilt_snapshot,
		"acceptance": _landing_contract.duplicate(true),
		"collision": get_landing_collision_report(),
	}


## World-space boarding point beside the port cockpit step.
func get_boarding_position() -> Vector3:
	if _boarding_marker == null:
		return global_transform * Vector3(-3.0, 0.35, 0.8)
	return _boarding_marker.global_position


## Stable ship-local pilot pose. The marker moves and rotates with the craft.
func get_pilot_seat_anchor() -> Node3D:
	if _pilot_seat_anchor == null:
		_build_ship()
	return _pilot_seat_anchor


## World-space threshold at the port cockpit sill, just above the boarding steps.
func get_boarding_entry_transform() -> Transform3D:
	if _boarding_entry_marker == null:
		_build_ship()
	return _boarding_entry_marker.global_transform


## Opens or closes the complete framed canopy around its physical aft hinge.
func set_canopy_open(open: bool, duration: float = 0.65) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	_set_canopy_open_unchecked(open, duration)


## Reset owns a private path because its dispatch guard must reject a hostile
## callback without blocking the transaction's own authored canopy restoration.
func _set_canopy_open_unchecked(open: bool, duration: float) -> void:
	_canopy_open = open
	_canopy_motion_serial += 1
	var motion_serial := _canopy_motion_serial
	if _canopy_tween != null and _canopy_tween.is_valid():
		_canopy_tween.kill()
	_canopy_tween = null
	if _canopy_pivot == null:
		_build_ship()
	if _canopy_pivot == null:
		return
	var target_rotation := Vector3(CANOPY_OPEN_ANGLE if open else 0.0, 0.0, 0.0)
	if duration <= 0.0 or not is_inside_tree() or _canopy_pivot.rotation.is_equal_approx(target_rotation):
		_set_canopy_open_fraction(1.0 if open else 0.0)
		call_deferred("_emit_canopy_motion_finished", open, motion_serial)
		return
	_canopy_tween = create_tween()
	_canopy_tween.set_trans(Tween.TRANS_CUBIC)
	_canopy_tween.set_ease(Tween.EASE_IN_OUT)
	var start_fraction := _canopy_pivot.rotation.x / maxf(CANOPY_OPEN_ANGLE, 0.001)
	_canopy_tween.tween_method(
		_set_canopy_open_fraction,
		start_fraction,
		1.0 if open else 0.0,
		maxf(0.01, duration)
	)
	_canopy_tween.tween_callback(_finish_canopy_motion.bind(open, motion_serial))


func is_canopy_open() -> bool:
	return _canopy_open


## Safe world-space transform used when the pilot leaves the landed craft.
func get_exit_transform() -> Transform3D:
	if _exit_marker == null:
		return Transform3D(global_basis.orthonormalized(), get_boarding_position())
	return _exit_marker.global_transform


func get_camera() -> Camera3D:
	if _cockpit_view and _cockpit_camera != null:
		return _cockpit_camera
	return _camera


## Applies one FOV to both aiming rigs so the reticle and current view remain
## consistent when the player changes the camera setting mid-flight.
func set_camera_fov(field_of_view: float) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	var safe_fov := clampf(field_of_view, 55.0, 110.0)
	if _camera != null:
		_camera.fov = safe_fov
	if _cockpit_camera != null:
		_cockpit_camera.fov = safe_fov


func get_camera_fov() -> float:
	return _camera.fov if _camera != null else 72.0


func get_damage_presentation() -> HeroDamagePresentation:
	return _damage_presentation


func get_ship_id() -> StringName:
	return ship_id


func get_display_name() -> String:
	return display_name


func get_role() -> String:
	return role_name


func get_home_berth_id() -> StringName:
	return home_berth_id


func get_ship_definition() -> ShipDefinition:
	return ship_definition


func get_ship_audio_rig() -> ShipAudioRig:
	return _ship_audio_rig


func is_boardable() -> bool:
	return not _destroyed and not _piloted and _engine_state == ENGINE_OFFLINE


## Typed contract for leaving the pilot seat while the craft is away from a
## berth, and for walking its pressurised cabin under way.
##
## This is `modern_interpretation` design, not a recovered original behaviour and
## not a claim about any historical craft. The default is deliberately closed:
## a craft with no physically walkable, bounded cabin has nowhere to stand once
## the seat is vacated, so it refuses rather than putting a pilot in open space.
## Overriders return:
##
## - `supported`: the pilot may leave the seat while the craft is in space.
## - `frame`: the [MovingInteriorFrame] that will carry the occupant.
## - `stand_transform`: world-space standing pose the pilot arrives at, and the
##   pose the containment guard recalls them to.
## - `local_bounds`: ship-local volume the occupant is confined to. This is the
##   anti-stranding envelope, so it must enclose every place the pilot is
##   allowed to be, and nothing outside the hull.
func get_in_flight_cabin_report() -> Dictionary:
	return {
		"supported": false,
		"status": &"no_walkable_cabin",
		"frame": null,
		"stand_transform": Transform3D.IDENTITY,
		"local_bounds": AABB(),
	}


## Convenience gate over [method get_in_flight_cabin_report].
func supports_in_flight_cabin_access() -> bool:
	return bool(get_in_flight_cabin_report().get("supported", false))


func is_destroyed() -> bool:
	return _destroyed


func is_piloted() -> bool:
	return _piloted


## Validates and reserves one exact reuse operation without changing gameplay,
## presentation, component, landing, cruise, or variant state. The returned
## dictionary is a detached capability report; commit uses the private snapshot,
## never caller-owned fields such as `spawn_transform`.
func preflight_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	if _reset_for_reuse_dispatch_active:
		return _reset_for_reuse_result(false, &"reentrant_call", &"preflight", {}, spawn_transform)
	if not _pending_reset_for_reuse.is_empty():
		return _reset_for_reuse_result(false, &"reset_pending", &"preflight", {}, spawn_transform)
	if _next_reset_for_reuse_receipt_id > RESET_FOR_REUSE_MAX_SAFE_RECEIPT_ID:
		return _reset_for_reuse_result(false, &"receipt_exhausted", &"preflight", {}, spawn_transform)
	if not _reset_for_reuse_transform_is_finite(spawn_transform):
		return _reset_for_reuse_result(false, &"invalid_spawn_transform", &"preflight", {}, spawn_transform)
	# Reset captures world-space state and synchronizes the chase camera. A
	# detached craft has no valid global transform, so it must never reserve a
	# receipt that could later report an accepted partial reset.
	if not is_inside_tree():
		return _reset_for_reuse_result(false, &"ship_detached", &"preflight", {}, spawn_transform)
	if not is_finite(maximum_hull) or maximum_hull <= 0.0:
		return _reset_for_reuse_result(false, &"invalid_maximum_hull", &"preflight", {}, spawn_transform)
	if _component_damage == null \
			or not is_instance_valid(_component_damage) \
			or not _component_damage.is_configured():
		return _reset_for_reuse_result(false, &"component_unavailable", &"preflight", {}, spawn_transform)
	if not _component_damage.is_owner_mutation_capability_current(
		_component_damage_owner_capability
	):
		return _reset_for_reuse_result(
			false,
			&"component_owner_unavailable",
			&"preflight",
			{},
			spawn_transform
		)
	if not _component_damage.is_reset_for_reuse_available():
		return _reset_for_reuse_result(
			false,
			&"component_reset_unavailable",
			&"preflight",
			{},
			spawn_transform
		)

	_reset_for_reuse_dispatch_active = true
	var variant_preflight := _preflight_variant_reset_for_reuse(spawn_transform)
	if not bool(variant_preflight.get("accepted", false)):
		var variant_reason := StringName(variant_preflight.get("reason", &"variant_rejected"))
		if variant_reason.is_empty():
			variant_reason = &"variant_rejected"
		var rejected := _reset_for_reuse_result(
			false,
			variant_reason,
			&"preflight",
			{},
			spawn_transform
		)
		_reset_for_reuse_dispatch_active = false
		return rejected

	var component_report := _component_damage.get_component_report()
	var receipt_id := _next_reset_for_reuse_receipt_id
	_next_reset_for_reuse_receipt_id += 1
	_pending_reset_for_reuse = {
		"receipt_id": receipt_id,
		"ship_instance_id": get_instance_id(),
		"spawn_transform": spawn_transform,
		"destruction_serial": _destruction_serial,
		"component_instance_id": _component_damage.get_instance_id(),
		"component_revision": _component_damage.get_revision(),
		"component_ledger_generation": _component_damage.get_ledger_generation(),
		"component_owner_capability_instance_id": (
			_component_damage_owner_capability.get_instance_id()
			if is_instance_valid(_component_damage_owner_capability)
			else 0
		),
		"component_configured": _component_damage.is_configured(),
		"component_maximum_hull": float(component_report.get("maximum_hull", 0.0)),
		"component_local_bounds": component_report.get("local_bounds", AABB()) as AABB,
		"maximum_hull": maximum_hull,
		"hull": _hull,
		"destroyed": _destroyed,
		"piloted": _piloted,
		"engine_state": _engine_state,
		"landing_active": _landing_active,
		"global_transform": global_transform,
		"inside_tree": is_inside_tree(),
		"damage_presentation_instance_id": (
			_damage_presentation.get_instance_id()
			if is_instance_valid(_damage_presentation)
			else 0
		),
		"damage_presentation_generation": (
			_damage_presentation.get_presented_component_generation()
			if is_instance_valid(_damage_presentation)
			else 0
		),
		"planetary_cruise_attachment_generation": _planetary_cruise_attachment_generation,
	}.duplicate(true)
	var accepted := _reset_for_reuse_result(
		true,
		&"preflight_ready",
		&"preflight",
		_pending_reset_for_reuse
	)
	_reset_for_reuse_dispatch_active = false
	return accepted


## Commits the exact pending receipt. Every possible rejection is decided before
## the first mutation; once currentness passes, the existing accepted reset and
## signal chronology runs under one guard and the deterministic variant hook is
## the final step before the receipt is retired.
func commit_reset_for_reuse(receipt: Dictionary) -> Dictionary:
	if _reset_for_reuse_dispatch_active:
		return _reset_for_reuse_result(false, &"reentrant_call", &"commit")
	if _pending_reset_for_reuse.is_empty():
		return _reset_for_reuse_result(false, &"no_pending_reset", &"commit")
	if not _reset_for_reuse_receipt_matches(receipt, _pending_reset_for_reuse):
		return _reset_for_reuse_result(false, &"receipt_identity_mismatch", &"commit")

	_reset_for_reuse_dispatch_active = true
	var context := _pending_reset_for_reuse.duplicate(true)
	if not _reset_for_reuse_dependencies_are_current(context):
		_pending_reset_for_reuse.clear()
		var stale := _reset_for_reuse_result(false, &"dependency_changed", &"commit", context)
		_reset_for_reuse_dispatch_active = false
		return stale
	var variant_preflight := _preflight_variant_reset_for_reuse(
		context.get("spawn_transform", Transform3D.IDENTITY) as Transform3D
	)
	if not bool(variant_preflight.get("accepted", false)):
		_pending_reset_for_reuse.clear()
		var variant_reason := StringName(variant_preflight.get("reason", &"variant_rejected"))
		if variant_reason.is_empty():
			variant_reason = &"variant_rejected"
		var rejected := _reset_for_reuse_result(false, variant_reason, &"commit", context)
		_reset_for_reuse_dispatch_active = false
		return rejected
	if not _component_damage.begin_owner_mutation_transaction(
		_component_damage_owner_capability
	):
		_pending_reset_for_reuse.clear()
		var unavailable := _reset_for_reuse_result(
			false,
			&"component_transaction_unavailable",
			&"commit",
			context
		)
		_reset_for_reuse_dispatch_active = false
		return unavailable

	var spawn_transform := context.get("spawn_transform", Transform3D.IDENTITY) as Transform3D
	_destruction_serial += 1
	_retire_planetary_cruise(&"reset_for_reuse", true)
	_end_landing_for_lifecycle(&"reset_for_reuse")
	_destroyed = false
	global_transform = spawn_transform
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_engine_state = ENGINE_OFFLINE
	_engine_timer = 0.0
	_automatic_engine_idle_elapsed = 0.0
	_weapon_timer = 0.0
	_weapon_heat = 0.0
	_weapon_overheated = false
	_weapon_overheat_remaining = 0.0
	_throttle = 0.0
	_hull = maximum_hull
	_critical_damage_emitted = false
	_deferred_terminal_presentation_receipt_id = -1
	_destroyed_hull_hide_pending = false
	_clear_pending_look_motion()
	_roll_animation = 0.0
	_visual_bank = 0.0
	_landing_active = false
	_landing_target = spawn_transform
	_landing_staging_target = spawn_transform
	_clear_landing_authority_snapshot()
	_landing_contract = {}
	_landing_phase = LANDING_PHASE_NONE
	_landing_after_brake_phase = LANDING_PHASE_FINAL_APPROACH
	_landing_elapsed = 0.0
	_landing_stall_elapsed = 0.0
	_landing_previous_distance = INF
	_landing_last_abort_reason = &""
	_landed = true
	_docked_latch = true
	_piloted = false
	_impact_cooldown_remaining = 0.0
	_collision_component_routing_active = false
	if _ship_audio_rig != null:
		_ship_audio_rig.set_engine_running(false, false)
		_ship_audio_rig.set_thrust_state(0.0, false)
		_ship_audio_rig.set_damage_alarm_active(false)
		_audio_throttle_state = 0.0
		_audio_boost_state = false
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false
	if _visual_root != null:
		_visual_root.visible = true
		_visual_root.rotation = Vector3.ZERO
	_sync_engine_visuals_immediately()
	_snap_chase_camera_response()
	_set_canopy_open_unchecked(false, 0.0)
	# Respawn restores the whole roster in one call, so recovery never waits on the
	# gradual berth repair. Reset authority first: its nominal callbacks may touch
	# retained presentation consumers, so the presentation clear must be the last
	# damage-lifecycle mutation and bind the exact new model generation.
	if _component_damage != null:
		if not _component_damage.reset_for_reuse_as_owner(
			_component_damage_owner_capability
		):
			push_error("HeroShip component owner reset invariant failed after accepted preflight")
		_last_component_damage_revision = _component_damage.get_revision()
	if _damage_presentation != null:
		_damage_presentation.reset_for_reuse(
			1.0,
			HeroDamagePresentation.STATE_POWERED_DOWN,
			_component_damage.get_ledger_generation()
		)
	# Component reset is the point where every retained engine and weapon grade
	# becomes nominal. Restore those consumers after the generic rig is clean.
	_sync_engine_visuals_immediately()
	_sync_weapon_component_presentation()
	_set_camera_current(false)
	engine_state_changed.emit(_engine_state)
	hull_changed.emit(_hull, maximum_hull)
	_commit_variant_reset_for_reuse(context.duplicate(true))
	if not _component_damage.end_owner_mutation_transaction(
		_component_damage_owner_capability
	):
		push_error("HeroShip component owner transaction could not close")
	var committed := _reset_for_reuse_result(true, &"reset_committed", &"commit", context)
	_pending_reset_for_reuse.clear()
	_reset_for_reuse_dispatch_active = false
	return committed


## Releases an accepted preflight after an external prerequisite such as berth
## occupancy fails. Cancellation consumes the receipt but changes no ship state
## and emits no lifecycle or presentation signal.
func cancel_reset_for_reuse(receipt: Dictionary) -> Dictionary:
	if _reset_for_reuse_dispatch_active:
		return _reset_for_reuse_result(false, &"reentrant_call", &"cancel")
	if _pending_reset_for_reuse.is_empty():
		return _reset_for_reuse_result(false, &"no_pending_reset", &"cancel")
	if not _reset_for_reuse_receipt_matches(receipt, _pending_reset_for_reuse):
		return _reset_for_reuse_result(false, &"receipt_identity_mismatch", &"cancel")
	_reset_for_reuse_dispatch_active = true
	var context := _pending_reset_for_reuse.duplicate(true)
	_pending_reset_for_reuse.clear()
	var cancelled := _reset_for_reuse_result(true, &"reset_cancelled", &"cancel", context)
	_reset_for_reuse_dispatch_active = false
	return cancelled


## Synchronous compatibility seam used by tests and non-transactional callers.
## Existing callers may continue to ignore the detached Dictionary result.
func reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	var preflight := preflight_reset_for_reuse(spawn_transform)
	if not bool(preflight.get("accepted", false)):
		return preflight
	return commit_reset_for_reuse(preflight)


## Current variants have no fallible reset prerequisite. The explicit hook is
## the future home for a pure identity/configuration check and may never mutate.
func _preflight_variant_reset_for_reuse(_spawn_transform: Transform3D) -> Dictionary:
	return {"accepted": true, "reason": &"variant_ready"}


## Runs under the reset dispatch guard, after the base engine/hull signals, at
## the exact point where today's subclass code returns from `super`.
func _commit_variant_reset_for_reuse(_context: Dictionary) -> void:
	pass


func _reset_for_reuse_mutation_blocked() -> bool:
	return _reset_for_reuse_dispatch_active or not _pending_reset_for_reuse.is_empty()


func _reset_for_reuse_transform_is_finite(value: Transform3D) -> bool:
	return value.origin.is_finite() \
		and value.basis.x.is_finite() \
		and value.basis.y.is_finite() \
		and value.basis.z.is_finite()


func _reset_for_reuse_receipt_matches(receipt: Dictionary, context: Dictionary) -> bool:
	return typeof(receipt.get("schema_version")) == TYPE_INT \
		and int(receipt.get("schema_version", 0)) == RESET_FOR_REUSE_SCHEMA_VERSION \
		and typeof(receipt.get("receipt_id")) == TYPE_INT \
		and int(receipt.get("receipt_id", -1)) == int(context.get("receipt_id", -2)) \
		and typeof(receipt.get("ship_instance_id")) == TYPE_INT \
		and int(receipt.get("ship_instance_id", 0)) == get_instance_id() \
		and int(context.get("ship_instance_id", 0)) == get_instance_id()


func _reset_for_reuse_dependencies_are_current(context: Dictionary) -> bool:
	if int(context.get("ship_instance_id", 0)) != get_instance_id() \
			or not _reset_for_reuse_transform_is_finite(
				context.get("spawn_transform", Transform3D.IDENTITY) as Transform3D
			) \
			or bool(context.get("inside_tree", false)) != is_inside_tree() \
			or int(context.get("destruction_serial", -1)) != _destruction_serial \
			or float(context.get("maximum_hull", NAN)) != maximum_hull \
			or float(context.get("hull", NAN)) != _hull \
			or bool(context.get("destroyed", not _destroyed)) != _destroyed \
			or bool(context.get("piloted", not _piloted)) != _piloted \
			or StringName(context.get("engine_state", &"")) != _engine_state \
			or bool(context.get("landing_active", not _landing_active)) != _landing_active \
			or (context.get("global_transform", Transform3D.IDENTITY) as Transform3D) != global_transform \
			or int(context.get("planetary_cruise_attachment_generation", -1)) \
				!= _planetary_cruise_attachment_generation:
		return false
	if _component_damage == null or not is_instance_valid(_component_damage):
		return false
	if int(context.get("component_instance_id", 0)) != _component_damage.get_instance_id() \
			or bool(context.get("component_configured", false)) != _component_damage.is_configured() \
			or int(context.get("component_revision", -1)) != _component_damage.get_revision() \
			or int(context.get("component_ledger_generation", -1)) \
				!= _component_damage.get_ledger_generation() \
			or not _component_damage.is_reset_for_reuse_available():
		return false
	if not _component_damage.is_owner_mutation_capability_current(
			_component_damage_owner_capability
		) \
			or int(context.get("component_owner_capability_instance_id", 0)) \
				!= _component_damage_owner_capability.get_instance_id():
		return false
	var component_report := _component_damage.get_component_report()
	if float(context.get("component_maximum_hull", NAN)) \
			!= float(component_report.get("maximum_hull", NAN)) \
			or (context.get("component_local_bounds", AABB()) as AABB) \
				!= (component_report.get("local_bounds", AABB()) as AABB):
		return false
	var presentation_id := (
		_damage_presentation.get_instance_id()
		if is_instance_valid(_damage_presentation)
		else 0
	)
	if int(context.get("damage_presentation_instance_id", -1)) != presentation_id:
		return false
	var presentation_generation := (
		_damage_presentation.get_presented_component_generation()
		if is_instance_valid(_damage_presentation)
		else 0
	)
	return int(context.get("damage_presentation_generation", -1)) \
		== presentation_generation


func _reset_for_reuse_result(
	accepted: bool,
	reason: StringName,
	phase: StringName,
	context: Dictionary = {},
	requested_transform: Transform3D = Transform3D.IDENTITY
) -> Dictionary:
	var component_instance_id := (
		_component_damage.get_instance_id()
		if is_instance_valid(_component_damage)
		else 0
	)
	var component_revision := (
		_component_damage.get_revision()
		if is_instance_valid(_component_damage)
		else -1
	)
	return {
		"schema_version": RESET_FOR_REUSE_SCHEMA_VERSION,
		"accepted": accepted,
		"reason": reason,
		"phase": phase,
		"receipt_id": int(context.get("receipt_id", -1)),
		"ship_instance_id": get_instance_id(),
		"spawn_transform": context.get("spawn_transform", requested_transform) as Transform3D,
		"destruction_serial": int(context.get("destruction_serial", _destruction_serial)),
		"component_instance_id": int(context.get("component_instance_id", component_instance_id)),
		"component_revision": int(context.get("component_revision", component_revision)),
		"planetary_cruise_attachment_generation": int(context.get(
			"planetary_cruise_attachment_generation",
			_planetary_cruise_attachment_generation
		)),
	}.duplicate(true)


## Stable snapshot consumed by the HUD and gameplay coordinator.
func get_telemetry() -> Dictionary:
	var flight_forward_world := Vector3.FORWARD
	var altitude := 0.0
	if is_inside_tree():
		flight_forward_world = -global_basis.z.normalized()
		altitude = maxf(0.0, global_position.y - 1.15)
	var weapon_status := get_weapon_fire_status()
	return {
		"speed": velocity.length(),
		"velocity_world": velocity,
		"flight_forward_world": flight_forward_world,
		"camera_view": get_camera_view(),
		"throttle": _throttle,
		"altitude": altitude,
		"hull": _hull,
		"maximum_hull": maximum_hull,
		"damage_status": _damage_presentation.get_status() if _damage_presentation != null else &"healthy",
		# Scalar component readings only. The full roster stays behind
		# `get_component_damage_report()` so this per-frame snapshot allocates nothing
		# proportional to the roster.
		"components_failed": (
			_component_damage.get_failed_component_count() if _component_damage != null else 0
		),
		"components_impaired": (
			_component_damage.get_impaired_component_count() if _component_damage != null else 0
		),
		"component_integrity": (
			_component_damage.get_worst_integrity() if _component_damage != null else 1.0
		),
		"engine_power": _get_damage_engine_multiplier(),
		"weapon_power": _get_damage_weapon_multiplier(),
		"weapon_heat": _weapon_heat,
		"weapon_heat_percent": roundi(_weapon_heat * 100.0),
		"weapon_overheated": _weapon_overheated,
		"weapon_ready": bool(weapon_status.get("ready", false)),
		"weapon_status": StringName(weapon_status.get("status", &"unavailable")),
		"weapon_unavailable_reason": StringName(weapon_status.get("reason", &"weapon_unavailable")),
		"weapon_cooldown_remaining": _weapon_timer,
		"weapon_recovery_remaining": _weapon_overheat_remaining,
		"targeting_power": _get_damage_targeting_multiplier(),
		"engine_state": _engine_state,
		"automatic_engine_idle_remaining": (
			maxf(
				AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS - _automatic_engine_idle_elapsed,
				0.0
			)
			if _engine_state == ENGINE_ONLINE and _piloted and not _landing_active
			else 0.0
		),
		"landed": _landed,
		"landing_active": _landing_active,
		"landing_phase": _landing_phase,
		"landing_dock_accepted": bool(_landing_contract.get("strict_dock_acceptance", false)),
		"landing_abort_reason": _landing_last_abort_reason,
		"destroyed": _destroyed,
		"ship_id": ship_id,
		"display_name": display_name,
		"role": role_name,
	}


## Auditable quality contract for the physical pilot-eye view. Opaque geometry
## is deliberately kept outside a conservative five-ray forward sight cone;
## the historical warm panel is translucent and sits below that cone.
func get_cockpit_quality_report() -> Dictionary:
	var errors := PackedStringArray()
	var forward_panel := _torrent_unknown_function_panel
	var panel_size := Vector2.ZERO
	if forward_panel != null and forward_panel.has_meta("physical_size"):
		var size_value: Variant = forward_panel.get_meta("physical_size")
		if size_value is Vector2:
			panel_size = size_value as Vector2
	if _cockpit_camera == null:
		errors.append("cockpit_camera_missing")
	if forward_panel == null or panel_size.x <= 0.0 or panel_size.y <= 0.0:
		errors.append("forward_panel_missing")
	if _cockpit_readout == null:
		errors.append("instrument_readout_missing")
	var camera_alignment := 0.0
	var sight_sample_count := 5
	var opaque_obstruction_count := 0
	if _cockpit_camera != null:
		camera_alignment = (-_cockpit_camera.global_basis.z.normalized()).dot(-global_basis.z.normalized())
		if camera_alignment <= 0.999:
			errors.append("camera_not_nose_aligned")
		opaque_obstruction_count = _count_cockpit_sight_obstructions(10.0)
		if opaque_obstruction_count > 0:
			errors.append("opaque_forward_sight_obstruction")
	var anti_glare_texture := _materials.get("cockpit_anti_glare", null) as StandardMaterial3D
	var texture_loaded := anti_glare_texture != null and anti_glare_texture.albedo_texture != null
	if not texture_loaded:
		errors.append("anti_glare_texture_missing")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"forward_sight_clear": opaque_obstruction_count == 0,
		"opaque_obstruction_count": opaque_obstruction_count,
		"sight_sample_count": sight_sample_count,
		"sight_distance": 10.0,
		"camera_near": _cockpit_camera.near if _cockpit_camera != null else INF,
		"camera_forward_alignment": camera_alignment,
		"forward_panel_size": panel_size,
		"forward_panel_area": panel_size.x * panel_size.y,
		"anti_glare_texture_loaded": texture_loaded,
		"instrument_readout_present": _cockpit_readout != null,
		"practical_light_present": _cockpit_practical_light != null,
		"modern_interpretation": &"modern",
	}


func _count_cockpit_sight_obstructions(distance: float) -> int:
	if _cockpit_camera == null:
		return 5
	var mesh_roots: Array[Node] = [_cockpit_root, _canopy_pivot]
	var directions := PackedVector2Array([
		Vector2.ZERO,
		Vector2(-6.0, 0.0), Vector2(6.0, 0.0),
		Vector2(0.0, -5.0), Vector2(0.0, 5.0),
	])
	var blocked_samples := 0
	for angles in directions:
		var camera_direction := Vector3(
			tan(deg_to_rad(angles.x)),
			tan(deg_to_rad(angles.y)),
			-1.0
		).normalized()
		var world_start := _cockpit_camera.to_global(camera_direction * 0.10)
		var world_end := _cockpit_camera.to_global(camera_direction * distance)
		var blocked := false
		for root_node in mesh_roots:
			if root_node == null:
				continue
			var meshes: Array[Node] = root_node.find_children("*", "MeshInstance3D", true, false)
			for node in meshes:
				var mesh_instance := node as MeshInstance3D
				if not mesh_instance.visible or _mesh_is_translucent(mesh_instance):
					continue
				var local_start := mesh_instance.to_local(world_start)
				var local_end := mesh_instance.to_local(world_end)
				if mesh_instance.get_aabb().intersects_segment(local_start, local_end) != null:
					blocked = true
					break
			if blocked:
				break
		if blocked:
			blocked_samples += 1
	return blocked_samples


func _mesh_is_translucent(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null:
		return false
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	return material != null and (
		material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or material.albedo_color.a < 0.95
	)


func apply_damage(
		amount: float,
		world_hit_position: Vector3 = Vector3.INF,
		world_hit_normal: Vector3 = Vector3.ZERO,
		presentation_receipt_id: int = -1,
		defer_presentation: bool = false
	) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _reset_for_reuse_mutation_blocked():
		return
	if amount <= 0.0 or _hull <= 0.0 or _destroyed:
		return
	var repair_interrupt_authority := _resolve_repair_damage_interrupt_authority()
	var component_revision_before := (
		_component_damage.get_revision()
		if _component_damage != null and _component_damage.is_configured()
		else -1
	)
	var damage_revision_observed := false
	if repair_interrupt_authority != null and component_revision_before >= 0:
		var observed := repair_interrupt_authority.call(
			&"observe_component_damage_revision",
			{
				"target_id": get_ship_id(),
				"generation": _component_damage.get_ledger_generation(),
				"revision": component_revision_before,
			}
		) as Dictionary
		damage_revision_observed = bool(observed.get("accepted", false))
	var has_hit_position := world_hit_position.is_finite()
	var safe_normal := Vector3.ZERO
	if world_hit_normal.is_finite() and world_hit_normal != Vector3.ZERO:
		safe_normal = world_hit_normal.normalized()
	if safe_normal.length_squared() <= 0.001 and has_hit_position:
		var radial_normal := world_hit_position - global_position
		if radial_normal != Vector3.ZERO:
			safe_normal = radial_normal.normalized()
	_hull = maxf(0.0, _hull - amount)
	# The component roster observes the hull loss that has just been decided. It
	# cannot veto, refund, or re-apply it; hull authority is settled above.
	var component_damage_result := _record_component_damage(
		amount,
		world_hit_position,
		_collision_component_routing_active
	)
	if damage_revision_observed:
		_interrupt_repair_from_component_damage(
			repair_interrupt_authority,
			component_revision_before,
			component_damage_result,
			RepairAuthority.DAMAGE_KIND_COLLISION
			if _collision_component_routing_active
			else RepairAuthority.DAMAGE_KIND_COMBAT
		)
	var component_fence := _get_component_presentation_fence()
	var impact_world_position := _component_impact_world_position(
		component_damage_result,
		world_hit_position
	)
	var impact_component_id := _component_impact_id(component_damage_result)
	var semantic_intensity := clampf(amount / 18.0, 0.35, 1.0)
	if not defer_presentation and _ship_audio_rig != null:
		_ship_audio_rig.present_component_impact(impact_component_id, semantic_intensity)
	if (
		_damage_presentation != null
		and has_hit_position
		and not defer_presentation
	):
		_damage_presentation.present_impact(
			impact_world_position,
			safe_normal,
			clampf(amount / 18.0, 0.35, 2.0)
		)
	# Apply stage/alarm/engine-power state immediately. Terminal explosion is the
	# only part withheld when a travelling-pulse receipt owns presentation.
	if _damage_presentation != null and _hull > 0.0:
		_sync_damage_presentation()
	hull_changed.emit(_hull, maximum_hull)
	if _hull <= maximum_hull * 0.3 and not _critical_damage_emitted:
		_critical_damage_emitted = true
		critical_damage.emit()
	if _hull <= 0.0:
		_destroyed = true
		_retire_planetary_cruise(&"ship_destroyed", true)
		_destruction_serial += 1
		var destruction_serial := _destruction_serial
		var destruction_position := global_position
		var inherited_velocity := velocity
		if (
			defer_presentation
			and presentation_receipt_id >= 0
			and _damage_presentation != null
		):
			_deferred_terminal_presentation_receipt_id = presentation_receipt_id
			_damage_presentation.defer_damage_presentation(
				presentation_receipt_id,
				impact_world_position if impact_world_position.is_finite() else destruction_position,
				safe_normal,
				clampf(amount / 18.0, 0.35, 2.0),
				true,
				inherited_velocity,
				global_transform,
				impact_component_id,
				semantic_intensity,
				int(component_fence.get("generation", 0)),
				int(component_fence.get("sequence", -1)),
				int(component_fence.get("revision", 0))
			)
		elif _damage_presentation != null:
			_sync_damage_presentation()
		# Silence continuous engine state without playing the legacy ship-local
		# destruction cue. GameFlow owns the single authored positional explosion at
		# the captured receipt pose (or immediately for non-receipt damage).
		request_engine_stop(false)
		_end_landing_for_lifecycle(&"ship_destroyed")
		_clear_landing_authority_snapshot()
		_landing_contract = {}
		_landing_phase = LANDING_PHASE_ABORTED
		_landing_after_brake_phase = LANDING_PHASE_FINAL_APPROACH
		_landing_elapsed = 0.0
		_landing_stall_elapsed = 0.0
		_landing_previous_distance = INF
		_docked_latch = false
		_throttle = 0.0
		_clear_pending_look_motion()
		collision_layer = 0
		collision_mask = 0
		for child in get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", true)
		if is_inside_tree() and not defer_presentation:
			get_tree().create_timer(0.18).timeout.connect(
				_hide_destroyed_hull.bind(destruction_serial),
				CONNECT_ONE_SHOT
			)
		destroyed.emit(destruction_position, inherited_velocity)
	elif (
		defer_presentation
		and presentation_receipt_id >= 0
		and _damage_presentation != null
		and world_hit_position.is_finite()
	):
		_damage_presentation.defer_damage_presentation(
			presentation_receipt_id,
			impact_world_position,
			safe_normal,
			clampf(amount / 18.0, 0.35, 2.0),
			false,
			velocity,
			global_transform,
			impact_component_id,
			semantic_intensity,
			int(component_fence.get("generation", 0)),
			int(component_fence.get("sequence", -1)),
			int(component_fence.get("revision", 0))
		)


func commit_deferred_damage_presentation(receipt_id: int) -> bool:
	if _reset_for_reuse_mutation_blocked():
		return false
	if _damage_presentation == null:
		return false
	var component_fence := _get_component_presentation_fence()
	var committed := _damage_presentation.commit_deferred_damage_presentation(
		receipt_id,
		int(component_fence.get("generation", 0)),
		int(component_fence.get("sequence", -1)),
		int(component_fence.get("revision", 0))
	)
	if not committed and receipt_id == _deferred_terminal_presentation_receipt_id:
		# A consumed stale/corrupt terminal record may never retain a live-looking
		# terminal capability after its generation/sequence fence rejects it.
		_deferred_terminal_presentation_receipt_id = -1
	if committed and receipt_id == _deferred_terminal_presentation_receipt_id:
		_deferred_terminal_presentation_receipt_id = -1
		_destroyed_hull_hide_pending = true
		if is_inside_tree():
			get_tree().create_timer(0.18).timeout.connect(
				_hide_destroyed_hull.bind(_destruction_serial),
				CONNECT_ONE_SHOT
			)
	return committed


## For re-entry and teardown, discard pending deferred presentation records so
## stale receipt IDs can never commit on a recycled ship instance.
func discard_deferred_damage_presentations() -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _damage_presentation != null:
		_damage_presentation.discard_deferred_damage_presentations()
	_deferred_terminal_presentation_receipt_id = -1


func get_pending_damage_presentation_count() -> int:
	if _damage_presentation == null:
		return 0
	return _damage_presentation.get_pending_damage_presentation_count()


func get_pending_terminal_damage_presentation_receipt_id() -> int:
	return _deferred_terminal_presentation_receipt_id


func _get_component_presentation_fence() -> Dictionary:
	if _component_damage == null or not _component_damage.is_configured():
		return {"generation": 0, "sequence": -1, "revision": 0}
	var snapshot := _component_damage.get_ledger_snapshot()
	return {
		"generation": int(snapshot.get("generation", 0)),
		"sequence": int(snapshot.get("last_operation_sequence", -1)),
		"revision": int(snapshot.get("revision", 0)),
	}


func _update_engine(delta: float) -> void:
	if _engine_state != ENGINE_STARTING:
		return
	_engine_timer -= delta
	if _engine_timer <= 0.0:
		_engine_timer = 0.0
		_engine_state = ENGINE_ONLINE
		if _ship_audio_rig != null:
			_ship_audio_rig.set_engine_running(true, false)
		_sync_engine_visuals_immediately()
		engine_state_changed.emit(_engine_state)


## Automatic propulsion is intentionally downstream of direct-command authority:
## a stale replay, disabled source, or non-owner sample is neutralized before it
## can wake the craft. Presentation-only camera/UI edges are deliberately absent.
func _update_automatic_engine_control(delta: float, command: ShipCommand) -> void:
	if not _piloted or _destroyed or _hull <= 0.0:
		_automatic_engine_idle_elapsed = 0.0
		return
	var propulsion_demand := _landing_active \
		or _command_requires_engine(command) \
		or _planetary_cruise_has_propulsion_demand()
	if propulsion_demand:
		_automatic_engine_idle_elapsed = 0.0
		_wake_engine_for_automatic_demand()
		return
	if _engine_state != ENGINE_ONLINE:
		_automatic_engine_idle_elapsed = 0.0
		return
	_automatic_engine_idle_elapsed += maxf(delta, 0.0)
	if _automatic_engine_idle_elapsed >= AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS:
		request_engine_stop()


func _command_requires_engine(command: ShipCommand) -> bool:
	if command == null:
		return false
	return (
		absf(command.throttle) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or absf(command.yaw) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or absf(command.pitch) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or absf(command.roll) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or absf(command.look_yaw_delta) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or absf(command.look_pitch_delta) > AUTOMATIC_ENGINE_INTENT_EPSILON
		or command.boost
		or command.brake
		or command.hover
		or command.fire
		or command.barrel_roll
		or command.landing
	)


func _command_interrupts_planetary_cruise(command: ShipCommand) -> bool:
	return (
		_planetary_cruise_state != PLANETARY_CRUISE_STATE_INACTIVE
		or not _planetary_cruise_pending_envelope.is_empty()
	) \
		and _command_requires_engine(command)


func _planetary_cruise_has_propulsion_demand() -> bool:
	return not _planetary_cruise_pending_envelope.is_empty() \
		or _planetary_cruise_state != PLANETARY_CRUISE_STATE_INACTIVE


## Returns true only when this physics tick was fully integrated by the cruise
## branch. The branch owns no second movement path: it mutates this body's
## velocity, then calls the same CharacterBody3D move and collision accounting
## that ordinary flight uses, exactly once.
func _update_planetary_cruise_physics(delta: float) -> bool:
	if _destroyed or not _piloted or _landing_active or not is_inside_tree():
		_retire_planetary_cruise(&"lifecycle_gate", true)
		return false
	var had_pending := not _planetary_cruise_pending_envelope.is_empty()
	if had_pending:
		var envelope := _planetary_cruise_pending_envelope.duplicate(true)
		_planetary_cruise_pending_envelope.clear()
		var validation_reason := _validate_planetary_cruise_envelope(
			envelope,
			true
		)
		if not validation_reason.is_empty():
			_retire_planetary_cruise(validation_reason, true)
			return false
		_planetary_cruise_last_envelope = envelope.duplicate(true)
		_planetary_cruise_coordinate_frame_generation = int(
			envelope.coordinate_frame_generation
		)
		_planetary_cruise_direction_world = (
			envelope.destination_direction_world as Vector3
		).normalized()
		_planetary_cruise_desired_speed = float(
			envelope.desired_speed_meters_per_second
		)
		var signed_acceleration := float(
			envelope.acceleration_hint_meters_per_second_squared
		)
		_planetary_cruise_acceleration = absf(signed_acceleration)
		_planetary_cruise_braking_acceleration = absf(float(
			envelope.braking_acceleration_hint_meters_per_second_squared
		))
		if bool(envelope.desired_participation):
			if bool(envelope.braking_requested) or signed_acceleration < 0.0:
				_planetary_cruise_state = PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED
			elif _planetary_cruise_acceleration > 0.0:
				_planetary_cruise_state = PLANETARY_CRUISE_STATE_ACCELERATING
			else:
				_planetary_cruise_state = PLANETARY_CRUISE_STATE_CRUISING
			_planetary_cruise_reason = StringName(envelope.policy_reason)
		elif bool(envelope.braking_requested) and _planetary_cruise_can_brake():
			_planetary_cruise_state = PLANETARY_CRUISE_STATE_BRAKING
			_planetary_cruise_reason = StringName(envelope.policy_reason)
		else:
			_retire_planetary_cruise(StringName(envelope.policy_reason), true)
			return false
		_emit_planetary_cruise_state_changed()
	elif _planetary_cruise_state in [
		PLANETARY_CRUISE_STATE_ACCELERATING,
		PLANETARY_CRUISE_STATE_CRUISING,
		PLANETARY_CRUISE_STATE_BRAKING_TO_SPEED,
	]:
		# Participation needs one proof-bearing envelope per physics tick. Missing
		# cadence cannot coast indefinitely on an old obstacle observation.
		_planetary_cruise_controller_instance_id = 0
		_planetary_cruise_attachment_generation = _next_planetary_cruise_generation()
		_planetary_cruise_last_controller_generation = 0
		_planetary_cruise_last_sequence = 0
		_planetary_cruise_state = PLANETARY_CRUISE_STATE_BRAKING
		_planetary_cruise_reason = &"fresh_envelope_missing"
		_planetary_cruise_braking_acceleration = (
			PlanetaryCruisePolicyType.BRAKING_HINT_METERS_PER_SECOND_SQUARED
		)
		_emit_planetary_cruise_state_changed()
	if _planetary_cruise_state == PLANETARY_CRUISE_STATE_INACTIVE:
		return false

	var safe_delta := maxf(delta, 0.0)
	if _planetary_cruise_state == PLANETARY_CRUISE_STATE_BRAKING:
		var braking_step := _planetary_cruise_braking_acceleration * safe_delta
		velocity = velocity.move_toward(Vector3.ZERO, braking_step)
		_throttle = 0.0
	else:
		var target_velocity := _planetary_cruise_direction_world \
			* _planetary_cruise_desired_speed \
			* _get_damage_engine_multiplier()
		velocity = velocity.move_toward(
			target_velocity,
			_planetary_cruise_acceleration * _get_damage_engine_multiplier() * safe_delta
		)
		_throttle = (
			1.0
			if _planetary_cruise_acceleration > 0.0 \
				and velocity.dot(_planetary_cruise_direction_world) \
				< _planetary_cruise_desired_speed
			else 0.0
		)
	var pre_collision_velocity := velocity
	var pre_move_position := global_position
	if velocity.length_squared() > 0.0:
		move_and_slide()
	if (
		_landed
		and velocity.length() > DEPARTURE_SPEED_THRESHOLD
		and global_position.distance_squared_to(pre_move_position) \
			> DEPARTURE_MOTION_EPSILON_SQUARED
	):
		_landed = false
	_apply_collision_damage(pre_collision_velocity)
	if get_slide_collision_count() > 0:
		_retire_planetary_cruise(&"physical_collision", true)
		return true
	if _planetary_cruise_state == PLANETARY_CRUISE_STATE_BRAKING \
		and velocity.length() <= PlanetaryCruisePolicyType.SPEED_DEADBAND_METERS_PER_SECOND:
		velocity = Vector3.ZERO
		_retire_planetary_cruise(&"braking_complete", true)
	return true


func _validate_planetary_cruise_query_context(
	direction_world: Vector3,
	sweep_distance_meters: float,
	coordinate_frame_generation: int,
	expected_attachment_generation: int,
	controller_instance_id: int
) -> StringName:
	if not _planetary_cruise_body_is_live():
		return &"ship_unavailable"
	if _destroyed:
		return &"destroyed"
	if not _piloted:
		return &"not_piloted"
	if _landing_active:
		return &"landing_active"
	if expected_attachment_generation != _planetary_cruise_attachment_generation:
		return &"attachment_generation_mismatch"
	if controller_instance_id != _planetary_cruise_controller_instance_id:
		return &"controller_identity_mismatch"
	if coordinate_frame_generation < 1 \
		or coordinate_frame_generation > PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return &"coordinate_frame_generation_out_of_bounds"
	if not direction_world.is_finite() \
		or absf(direction_world.length() - 1.0) > PLANETARY_CRUISE_DIRECTION_EPSILON:
		return &"direction_not_normalized"
	if not is_finite(sweep_distance_meters) \
		or sweep_distance_meters <= 0.0 \
		or sweep_distance_meters > PlanetaryCruisePolicyType.MAX_CLEARANCE_METERS:
		return &"sweep_distance_out_of_bounds"
	return &""


func _validate_planetary_cruise_envelope(
	envelope: Dictionary,
	allow_pending_identity: bool = false
) -> StringName:
	if not _has_exact_planetary_cruise_keys(
		envelope,
		PLANETARY_CRUISE_ENVELOPE_KEYS
	):
		return &"envelope_schema_mismatch"
	for key in [
		"schema_version",
		"ship_instance_id",
		"ship_attachment_generation",
		"controller_instance_id",
		"controller_generation",
		"sequence",
		"coordinate_frame_generation",
		"clearance_proof_sequence",
		"clearance_proof_generation",
	]:
		if not envelope[key] is int:
			return StringName("%s_not_int" % key)
	for key in [
		"desired_speed_meters_per_second",
		"acceleration_hint_meters_per_second_squared",
		"braking_acceleration_hint_meters_per_second_squared",
	]:
		if not envelope[key] is float or not is_finite(float(envelope[key])):
			return StringName("%s_invalid" % key)
	for key in [
		"desired_participation",
		"braking_requested",
		"clearance_full_hull",
		"clearance_verified",
		"obstacle_detected",
	]:
		if not envelope[key] is bool:
			return StringName("%s_not_bool" % key)
	if not envelope.policy_reason is StringName:
		return &"policy_reason_not_string_name"
	if not envelope.observation is Dictionary:
		return &"observation_not_dictionary"
	if not envelope.destination_direction_world is Vector3:
		return &"direction_not_vector3"
	var direction := envelope.destination_direction_world as Vector3
	if not direction.is_finite() \
		or absf(direction.length() - 1.0) > PLANETARY_CRUISE_DIRECTION_EPSILON:
		return &"direction_not_normalized"
	if int(envelope.schema_version) != PLANETARY_CRUISE_ENVELOPE_SCHEMA_VERSION:
		return &"envelope_schema_version_mismatch"
	if int(envelope.ship_instance_id) != get_instance_id():
		return &"ship_instance_mismatch"
	if int(envelope.ship_attachment_generation) \
		!= _planetary_cruise_attachment_generation:
		return &"attachment_generation_mismatch"
	if int(envelope.controller_instance_id) \
		!= _planetary_cruise_controller_instance_id:
		return &"controller_identity_mismatch"
	if not allow_pending_identity and not _planetary_cruise_body_is_live():
		return &"ship_unavailable"
	if _destroyed:
		return &"destroyed"
	if not _piloted:
		return &"not_piloted"
	if _landing_active:
		return &"landing_active"
	var controller_generation := int(envelope.controller_generation)
	var sequence := int(envelope.sequence)
	if controller_generation < 1 \
		or controller_generation > PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return &"controller_generation_out_of_bounds"
	if sequence < 1 or sequence > PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return &"sequence_out_of_bounds"
	if (
		controller_generation < _planetary_cruise_last_controller_generation
		or (
			controller_generation == _planetary_cruise_last_controller_generation
			and sequence < _planetary_cruise_last_sequence
		)
	):
		return &"stale_envelope"
	if not allow_pending_identity \
		and controller_generation == _planetary_cruise_last_controller_generation \
		and sequence == _planetary_cruise_last_sequence:
		return &"duplicate_envelope"
	var frame_generation := int(envelope.coordinate_frame_generation)
	if frame_generation < 1 \
		or frame_generation > PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return &"coordinate_frame_generation_out_of_bounds"
	if int(envelope.clearance_proof_generation) != frame_generation:
		return &"clearance_proof_generation_mismatch"
	if int(envelope.clearance_proof_sequence) < 1 \
		or int(envelope.clearance_proof_sequence) \
		> PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return &"clearance_proof_sequence_out_of_bounds"
	var pending_frame_generation := int(
		_planetary_cruise_pending_envelope.get(
			"coordinate_frame_generation",
			_planetary_cruise_coordinate_frame_generation
		)
	)
	if frame_generation < max(
		_planetary_cruise_coordinate_frame_generation,
		pending_frame_generation
	):
		return &"stale_coordinate_frame_generation"
	var desired_speed := float(envelope.desired_speed_meters_per_second)
	var acceleration := float(envelope.acceleration_hint_meters_per_second_squared)
	var braking := float(
		envelope.braking_acceleration_hint_meters_per_second_squared
	)
	if desired_speed < 0.0 \
		or desired_speed > PLANETARY_CRUISE_MAX_SPEED_METERS_PER_SECOND:
		return &"desired_speed_out_of_bounds"
	if absf(acceleration) \
		> PLANETARY_CRUISE_MAX_ACCELERATION_METERS_PER_SECOND_SQUARED:
		return &"acceleration_out_of_bounds"
	if braking < 0.0 \
		or braking > PLANETARY_CRUISE_MAX_ACCELERATION_METERS_PER_SECOND_SQUARED:
		return &"braking_acceleration_out_of_bounds"
	var observation := (envelope.observation as Dictionary).duplicate(true)
	var policy_result := _planetary_cruise_policy.evaluate(
		observation,
		frame_generation
	)
	if not bool(policy_result.get("accepted", false)):
		return StringName(
			"policy_%s" % String(policy_result.get("reason", &"rejected"))
		)
	if bool(envelope.desired_participation) \
		!= bool(policy_result.get("desired_cruise_participation", false)) \
		or desired_speed \
		!= float(policy_result.get("desired_speed_meters_per_second", 0.0)) \
		or acceleration \
		!= float(policy_result.get(
			"acceleration_hint_meters_per_second_squared", 0.0
		)) \
		or bool(envelope.braking_requested) \
		!= bool(policy_result.get("braking_requested", false)) \
		or braking \
		!= float(policy_result.get(
			"braking_acceleration_hint_meters_per_second_squared", 0.0
		)) \
		or StringName(envelope.policy_reason) \
		!= StringName(policy_result.get("reason", &"")):
		return &"policy_result_mismatch"
	if not allow_pending_identity:
		var proof_reason := _validate_planetary_cruise_proof_capability(
			envelope,
			observation
		)
		if not proof_reason.is_empty():
			return proof_reason
	return &""


func _validate_planetary_cruise_proof_capability(
	envelope: Dictionary,
	observation: Dictionary
) -> StringName:
	if _planetary_cruise_pending_clearance_proof.is_empty():
		return &"clearance_proof_unavailable"
	var proof := _planetary_cruise_pending_clearance_proof
	if not _has_exact_planetary_cruise_keys(
		proof,
		PLANETARY_CRUISE_CLEARANCE_PROOF_KEYS
	):
		return &"clearance_proof_schema_mismatch"
	if int(envelope.clearance_proof_sequence) \
		!= int(proof.get("proof_sequence", 0)):
		return &"clearance_proof_sequence_mismatch"
	if int(proof.get("controller_instance_id", 0)) \
		!= _planetary_cruise_controller_instance_id \
		or int(proof.get("ship_instance_id", 0)) != get_instance_id() \
		or int(proof.get("ship_attachment_generation", 0)) \
		!= _planetary_cruise_attachment_generation:
		return &"clearance_proof_identity_mismatch"
	if int(proof.get("coordinate_frame_generation", 0)) \
		!= int(envelope.coordinate_frame_generation) \
		or not (proof.get("direction_world", Vector3.ZERO) as Vector3).is_equal_approx(
			envelope.destination_direction_world as Vector3
		):
		return &"clearance_proof_geometry_mismatch"
	if bool(envelope.clearance_full_hull) \
		!= bool(proof.get("clearance_full_hull", false)) \
		or bool(envelope.clearance_verified) \
		!= bool(proof.get("clearance_verified", false)) \
		or bool(envelope.obstacle_detected) \
		!= bool(proof.get("obstacle_detected", false)):
		return &"clearance_proof_flags_mismatch"
	if not bool(proof.get("clearance_full_hull", false)) \
		or not bool(proof.get("clearance_verified", false)):
		return &"clearance_proof_unverified"
	if float(observation.get("distance_to_destination_meters", -1.0)) \
		< float(proof.get("sweep_distance_meters", INF)) \
		or float(observation.get("ship_speed_meters_per_second", -1.0)) \
		!= float(proof.get("ship_speed_meters_per_second", -2.0)) \
		or float(observation.get("closing_speed_meters_per_second", INF)) \
		!= float(proof.get("closing_speed_meters_per_second", -INF)) \
		or StringName(observation.get("alignment_basis", &"")) \
		!= StringName(proof.get("alignment_basis", &"invalid")) \
		or float(observation.get("alignment_dot", INF)) \
		!= float(proof.get("alignment_dot", -INF)) \
		or int(observation.get("coordinate_frame_generation", 0)) \
		!= int(proof.get("coordinate_frame_generation", -1)) \
		or float(observation.get("verified_clearance_meters", -1.0)) \
		!= float(proof.get("verified_clearance_meters", -2.0)) \
		or float(observation.get("clearance_sweep_distance_meters", -1.0)) \
		!= float(proof.get("sweep_distance_meters", -2.0)) \
		or int(observation.get("clearance_proof_generation", 0)) \
		!= int(proof.get("coordinate_frame_generation", -1)) \
		or bool(observation.get("clearance_full_hull", false)) \
		!= bool(proof.get("clearance_full_hull", false)) \
		or bool(observation.get("clearance_verified", false)) \
		!= bool(proof.get("clearance_verified", false)) \
		or bool(observation.get("obstacle_detected", false)) \
		!= bool(proof.get("obstacle_detected", false)) \
		or bool(observation.get("currently_participating", false)) \
		!= bool(proof.get("currently_participating", false)):
		return &"clearance_observation_mismatch"
	if bool(observation.get("piloted", false)) != _piloted \
		or bool(observation.get("destroyed", false)) != _destroyed \
		or bool(observation.get("landing_active", false)) != _landing_active:
		return &"lifecycle_observation_mismatch"
	if not (proof.get("fixed_orientation_basis", Basis()) as Basis).is_equal_approx(
		global_basis
	) \
		or not (proof.get("ship_position_world", Vector3.INF) as Vector3) \
			.is_equal_approx(global_position) \
		or not (proof.get("velocity_world", Vector3.INF) as Vector3) \
			.is_equal_approx(velocity) \
		or float(proof.get("ship_speed_meters_per_second", -1.0)) \
		!= velocity.length() \
		or int(proof.get("collision_mask", -1)) != collision_mask:
		return &"clearance_proof_no_longer_current"
	var current_shape_names := PackedStringArray()
	var current_shape_transforms: Array[Transform3D] = []
	var current_shapes: Array[CollisionShape3D] = []
	for child in get_children():
		if child is CollisionShape3D:
			var collision := child as CollisionShape3D
			if not collision.disabled and collision.shape != null:
				current_shapes.append(collision)
	current_shapes.sort_custom(func(left: CollisionShape3D, right: CollisionShape3D) -> bool:
		return String(left.name) < String(right.name)
	)
	for collision in current_shapes:
		current_shape_names.append(str(collision.name))
		current_shape_transforms.append(collision.global_transform)
	if current_shape_names != proof.get("shape_names", PackedStringArray()) \
		or current_shape_transforms != proof.get("shape_transforms", []):
		return &"clearance_hull_roster_changed"
	return &""


func _planetary_cruise_body_is_live() -> bool:
	return is_inside_tree() \
		and not is_queued_for_deletion() \
		and get_world_3d() != null


func _planetary_cruise_can_brake() -> bool:
	return _piloted and not _destroyed and not _landing_active


func _retire_planetary_cruise(reason: StringName, advance_generation: bool) -> void:
	var changed := _planetary_cruise_state != PLANETARY_CRUISE_STATE_INACTIVE \
		or not _planetary_cruise_pending_envelope.is_empty() \
		or _planetary_cruise_controller_instance_id != 0 \
		or _planetary_cruise_reason != reason
	_planetary_cruise_pending_envelope.clear()
	_planetary_cruise_pending_clearance_proof.clear()
	_planetary_cruise_controller_instance_id = 0
	_planetary_cruise_state = PLANETARY_CRUISE_STATE_INACTIVE
	_planetary_cruise_reason = reason
	_planetary_cruise_direction_world = Vector3.ZERO
	_planetary_cruise_desired_speed = 0.0
	_planetary_cruise_acceleration = 0.0
	_planetary_cruise_braking_acceleration = 0.0
	_planetary_cruise_coordinate_frame_generation = 0
	_planetary_cruise_last_controller_generation = 0
	_planetary_cruise_last_sequence = 0
	if advance_generation:
		_planetary_cruise_attachment_generation = _next_planetary_cruise_generation()
	if changed:
		_emit_planetary_cruise_state_changed()


func _next_planetary_cruise_generation() -> int:
	if _planetary_cruise_attachment_generation \
		>= PLANETARY_CRUISE_MAX_SAFE_INTEGER:
		return 1
	return _planetary_cruise_attachment_generation + 1


func _emit_planetary_cruise_state_changed() -> void:
	if _planetary_cruise_signal_dispatch_active:
		return
	_planetary_cruise_signal_dispatch_active = true
	planetary_cruise_state_changed.emit(
		get_planetary_cruise_attachment_report().duplicate(true)
	)
	_planetary_cruise_signal_dispatch_active = false


func _planetary_cruise_receipt(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"schema_version": PLANETARY_CRUISE_PHYSICAL_SCHEMA_VERSION,
		"ship_instance_id": get_instance_id(),
		"ship_attachment_generation": _planetary_cruise_attachment_generation,
		"state": _planetary_cruise_state,
	}.duplicate(true)


func _planetary_cruise_clearance_receipt(
	accepted: bool,
	reason: StringName,
	direction_world: Vector3,
	sweep_distance_meters: float,
	coordinate_frame_generation: int,
	enabled_shape_count: int = 0,
	queried_shape_count: int = 0
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"schema_version": PLANETARY_CRUISE_PHYSICAL_SCHEMA_VERSION,
		"ship_instance_id": get_instance_id(),
		"ship_attachment_generation": _planetary_cruise_attachment_generation,
		"coordinate_frame_generation": coordinate_frame_generation,
		"proof_sequence": 0,
		"controller_instance_id": 0,
		"direction_world": direction_world,
		"sweep_distance_meters": sweep_distance_meters,
		"verified_clearance_meters": 0.0,
		"clearance_full_hull": false,
		"clearance_verified": false,
		"obstacle_detected": false,
		"enabled_shape_count": enabled_shape_count,
		"queried_shape_count": queried_shape_count,
		"shape_names": PackedStringArray(),
		"shape_transforms": [],
		"collision_mask": collision_mask,
		"fixed_orientation_basis": global_basis,
		"ship_position_world": global_position,
		"velocity_world": velocity,
		"ship_speed_meters_per_second": 0.0,
		"alignment_basis": &"",
		"alignment_dot": 0.0,
		"closing_speed_meters_per_second": 0.0,
		"currently_participating": false,
	}.duplicate(true)


static func _has_exact_planetary_cruise_keys(
	value: Dictionary,
	keys: Array
) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


## Player demand bypasses the legacy timed-start seam so the command that wakes
## the craft is also the command integrated by flight, weapons, and presentation.
func _wake_engine_for_automatic_demand() -> void:
	if _engine_state == ENGINE_ONLINE or _destroyed or _hull <= 0.0:
		return
	var startup_cue_needed := _engine_state == ENGINE_OFFLINE
	_docked_latch = false
	_engine_timer = 0.0
	_engine_state = ENGINE_ONLINE
	if _ship_audio_rig != null:
		# Match legacy timed-start ordering: observers of ONLINE see continuous
		# audio authority and visual power already committed atomically.
		_ship_audio_rig.set_engine_running(true, false)
		if startup_cue_needed:
			_ship_audio_rig.play_cue(ShipAudioRig.CUE_STARTUP)
	_sync_engine_visuals_immediately()
	engine_state_changed.emit(_engine_state)


func _sync_ship_audio(command: ShipCommand) -> void:
	if _ship_audio_rig == null:
		return
	var engine_running := _engine_state == ENGINE_ONLINE and not _destroyed
	if _ship_audio_rig.is_engine_running() != engine_running:
		_ship_audio_rig.set_engine_running(engine_running, false)
	var normalized_thrust := absf(_throttle) if engine_running else 0.0
	var boosting := engine_running and command.boost and _throttle > 0.05
	if not is_equal_approx(normalized_thrust, _audio_throttle_state) or boosting != _audio_boost_state:
		_ship_audio_rig.set_thrust_state(normalized_thrust, boosting)
		_audio_throttle_state = normalized_thrust
		_audio_boost_state = boosting
	_ship_audio_rig.set_damage_alarm_active(
		not _destroyed and _hull > 0.0 and _hull <= maximum_hull * 0.3
	)


func _update_flight(delta: float, command: ShipCommand, suppress_look: bool = false) -> void:
	var throttle_input := command.throttle
	# Keys express the player's current thrust intent. A short response curve keeps
	# takeoff smooth without leaving almost a second of unwanted thrust after a
	# release or making a W/S reversal feel ignored.
	_throttle = move_toward(_throttle, throttle_input, throttle_response * delta)
	if absf(throttle_input) > 0.04:
		_travel_sign = signf(throttle_input)
	# Completing a landing must remain a stable state while the engines idle;
	# otherwise the gameplay coordinator cannot safely unlock disembarking.
	if (
		_landed
		and absf(_throttle) < 0.04
		and velocity.length() <= DEPARTURE_SPEED_THRESHOLD
	):
		_clear_pending_look_motion()
		velocity = Vector3.ZERO
		if command.fire:
			_fire_weapon()
		return
	var boosting := command.boost and _throttle > 0.05
	var damage_power := _get_damage_engine_multiplier()
	var manual_brake_power := lerpf(
		FAILED_ENGINE_MANUAL_BRAKE_FACTOR,
		1.0,
		damage_power
	)
	var speed_limit := (boost_speed if boosting else maximum_speed) * lerpf(0.55, 1.0, damage_power)
	var acceleration := thrust_acceleration * (boost_multiplier if boosting else 1.0) * damage_power
	var flight_forward := -global_basis.z.normalized()
	velocity += flight_forward * _throttle * acceleration * delta

	if command.brake:
		velocity = velocity.move_toward(
			Vector3.ZERO,
			brake_acceleration * manual_brake_power * delta
		)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, passive_drag * delta)
	if velocity.length() > speed_limit:
		velocity = velocity.normalized() * speed_limit

	var key_yaw := command.yaw
	var maximum_mouse_turn := deg_to_rad(maximum_mouse_turn_degrees)
	var mouse_yaw := 0.0 if suppress_look else -command.look_yaw_delta * maximum_mouse_turn
	var mouse_pitch := 0.0 if suppress_look else command.look_pitch_delta * maximum_mouse_turn
	# Mouse motion maps directly to craft attitude. A/D performs yaw only; the
	# accompanying bank is presentation-only so it cannot corrupt the movement axes.
	rotate_object_local(
		Vector3.UP,
		-key_yaw * deg_to_rad(yaw_speed_degrees) * damage_power * delta
	)
	# Compose simultaneous mouse yaw and pitch as one local rotation-vector
	# exponential. Repeating proportional diagonal samples now follows the same
	# attitude path regardless of how the OS partitions the physical mouse sweep.
	var mouse_rotation_vector := Vector3(mouse_pitch, mouse_yaw, 0.0) * damage_power
	var mouse_rotation_angle := mouse_rotation_vector.length()
	if mouse_rotation_vector.is_finite() and is_finite(mouse_rotation_angle) and mouse_rotation_angle > 0.000001:
		var mouse_rotation := Quaternion(
			mouse_rotation_vector / mouse_rotation_angle,
			mouse_rotation_angle
		)
		global_basis = global_basis * Basis(mouse_rotation)
	rotate_object_local(
		Vector3.RIGHT,
		command.pitch * deg_to_rad(yaw_speed_degrees) * damage_power * delta
	)
	rotate_object_local(
		Vector3.FORWARD,
		command.roll * deg_to_rad(roll_speed_degrees) * damage_power * delta
	)
	global_basis = global_basis.orthonormalized()

	# Preserve arcade momentum while pulling the travel vector toward the visible
	# nose. This keeps W/mouse steering aligned with the chase view instead of
	# allowing a long sideways slide along the pre-turn velocity vector.
	flight_forward = -global_basis.z.normalized()
	if velocity.length_squared() > 0.01:
		var assisted_velocity := flight_forward * velocity.length() * _travel_sign
		var assist_weight := 1.0 - exp(
			-flight_assist_strength * damage_power * maxf(absf(_throttle), 0.35) * delta
		)
		velocity = velocity.lerp(assisted_velocity, assist_weight)

	if command.barrel_roll and damage_power > 0.0 and absf(_roll_animation) < 0.01:
		_roll_animation = TAU
	if _roll_animation > 0.0:
		var roll_step := minf(
			_roll_animation,
			deg_to_rad(roll_speed_degrees) * 2.2 * damage_power * delta
		)
		rotate_object_local(Vector3.FORWARD, roll_step)
		_roll_animation -= roll_step

	if command.hover:
		velocity.y = move_toward(
			velocity.y,
			0.0,
			brake_acceleration * manual_brake_power * delta
		)
		var upright := Quaternion(global_basis).slerp(
			Quaternion(Basis(Vector3.UP, rotation.y)),
			1.0 - exp(-2.0 * delta)
		)
		global_basis = Basis(upright).orthonormalized()
	if command.fire:
		_fire_weapon()
	var pre_collision_velocity := velocity
	var pre_move_position := global_position
	move_and_slide()
	# A throttle tap is not an authoritative departure. Keep the berth latch until
	# post-collision motion proves that the craft has actually begun moving; this
	# also prevents a blocked craft from releasing its occupied berth in GameFlow.
	if (
		_landed
		and velocity.length() > DEPARTURE_SPEED_THRESHOLD
		and global_position.distance_squared_to(pre_move_position) > DEPARTURE_MOTION_EPSILON_SQUARED
	):
		_landed = false
	_apply_collision_damage(pre_collision_velocity)


func _update_landing(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_landing_elapsed += safe_delta
	var berth := _get_landing_berth()
	var authority_failure := _get_landing_authority_failure(berth)
	if not authority_failure.is_empty():
		_abort_landing(authority_failure)
		return
	if _landing_elapsed > LANDING_TIMEOUT_SECONDS:
		_abort_landing(&"assist_timeout")
		return
	if berth != null:
		var collision_report := get_landing_collision_report()
		if not (collision_report.get("valid", false) as bool) \
				or not berth.contains_oriented_bounds(
					_landing_target,
					collision_report.get("local_bounds", AABB()) as AABB,
					0.05
				):
			_abort_landing(&"berth_clearance_lost")
			return
	match _landing_phase:
		LANDING_PHASE_BRAKE:
			_update_landing_brake(safe_delta)
		LANDING_PHASE_MOVE_TO_STAGING:
			_update_landing_staging(safe_delta)
		LANDING_PHASE_ALIGN:
			_update_landing_alignment(safe_delta)
		LANDING_PHASE_FINAL_APPROACH:
			_update_landing_final(safe_delta, berth)
		_:
			_abort_landing(&"landing_phase_invalid")


func _update_landing_brake(delta: float) -> void:
	# Capture speed is intentionally generous. First neutralise momentum without
	# asking the pilot to manually settle inside the old narrow speed envelope.
	velocity = velocity.move_toward(
		Vector3.ZERO,
		maxf(brake_acceleration, 48.0) * delta
	)
	if velocity.length() > 0.001:
		move_and_slide()
	var remaining_speed := velocity.length()
	if remaining_speed <= LANDING_BRAKE_COMPLETE_SPEED:
		velocity = Vector3.ZERO
		_set_landing_phase(_landing_after_brake_phase)
		return
	_track_landing_progress(remaining_speed, delta)


func _update_landing_staging(delta: float) -> void:
	var offset := _landing_staging_target.origin - global_position
	var desired_velocity := offset * 1.35
	if desired_velocity.length() > 12.0:
		desired_velocity = desired_velocity.normalized() * 12.0
	velocity = velocity.lerp(desired_velocity, 1.0 - exp(-4.5 * delta))
	move_and_slide()
	var remaining_distance := global_position.distance_to(_landing_staging_target.origin)
	if remaining_distance <= LANDING_STAGING_COMPLETION_DISTANCE \
			and velocity.length() <= LANDING_STAGING_COMPLETION_SPEED:
		velocity = Vector3.ZERO
		_set_landing_phase(LANDING_PHASE_ALIGN)
		return
	_track_landing_progress(remaining_distance, delta)


func _update_landing_alignment(delta: float) -> void:
	var target_basis := _landing_target.basis.orthonormalized()
	var proposed_basis := Basis(Quaternion(global_basis).slerp(
		Quaternion(target_basis),
		1.0 - exp(-3.2 * delta)
	)).orthonormalized()
	var proposed_angular_change := rad_to_deg(
		Quaternion(global_basis).angle_to(Quaternion(proposed_basis))
	)
	var proposed_transform := Transform3D(proposed_basis, global_position)
	var pose_obstructed := proposed_angular_change > LANDING_ROTATION_GUARD_ANGLE_DEGREES \
		and (
			_is_landing_pose_obstructed(global_transform)
			or _is_landing_pose_obstructed(proposed_transform)
		)
	if pose_obstructed:
		velocity = Vector3.ZERO
		_track_landing_progress(
			rad_to_deg(Quaternion(global_basis).angle_to(Quaternion(target_basis))),
			delta,
			false
		)
		return
	velocity = velocity.move_toward(Vector3.ZERO, maxf(brake_acceleration, 48.0) * delta)
	global_basis = proposed_basis
	if velocity.length() > 0.001:
		move_and_slide()
	var angular_error := rad_to_deg(
		Quaternion(global_basis).angle_to(Quaternion(target_basis))
	)
	if angular_error <= LANDING_ALIGNMENT_COMPLETION_ANGLE_DEGREES \
			and velocity.length() <= LANDING_STAGING_COMPLETION_SPEED:
		var exact_alignment := Transform3D(target_basis, global_position)
		var final_alignment_change := rad_to_deg(
			Quaternion(global_basis).angle_to(Quaternion(target_basis))
		)
		if final_alignment_change > LANDING_ROTATION_GUARD_ANGLE_DEGREES \
				and _is_landing_pose_obstructed(exact_alignment):
			_track_landing_progress(angular_error, delta, false)
			return
		global_basis = target_basis
		velocity = Vector3.ZERO
		_set_landing_phase(LANDING_PHASE_FINAL_APPROACH)
		return
	_track_landing_progress(angular_error, delta)


func _update_landing_final(delta: float, berth: ShipBerth) -> void:
	var offset := _landing_target.origin - global_position
	var desired_velocity := offset * 1.6
	desired_velocity.x = clampf(desired_velocity.x, -8.0, 8.0)
	desired_velocity.y = clampf(desired_velocity.y, -5.0, 5.0)
	desired_velocity.z = clampf(desired_velocity.z, -8.0, 8.0)
	var proposed_velocity := velocity.lerp(desired_velocity, 1.0 - exp(-4.0 * delta))
	var target_basis := _landing_target.basis.orthonormalized()
	var proposed_basis := Basis(Quaternion(global_basis).slerp(
		Quaternion(target_basis),
		1.0 - exp(-3.5 * delta)
	)).orthonormalized()
	var proposed_transform := Transform3D(
		proposed_basis,
		global_position + proposed_velocity * delta
	)
	var proposed_angular_change := rad_to_deg(
		Quaternion(global_basis).angle_to(Quaternion(proposed_basis))
	)
	var pose_obstructed := proposed_angular_change > LANDING_ROTATION_GUARD_ANGLE_DEGREES \
		and (
			_is_landing_pose_obstructed(global_transform)
			or _is_landing_pose_obstructed(proposed_transform)
		)
	if pose_obstructed:
		velocity = Vector3.ZERO
	else:
		velocity = proposed_velocity
		global_basis = proposed_basis
		move_and_slide()
	var remaining_distance := global_position.distance_to(_landing_target.origin)
	var angular_error := rad_to_deg(
		Quaternion(global_basis).angle_to(Quaternion(target_basis))
	)
	if remaining_distance <= LANDING_COMPLETION_DISTANCE \
			and velocity.length() <= LANDING_COMPLETION_SPEED \
			and angular_error <= LANDING_COMPLETION_ANGLE_DEGREES:
		_complete_landing(berth, target_basis)
		return
	_track_landing_progress(remaining_distance, delta, not pose_obstructed)


func _track_landing_progress(error_value: float, delta: float, allow_reset: bool = true) -> void:
	if not _landing_active:
		return
	if allow_reset and _landing_previous_distance - error_value > LANDING_PROGRESS_EPSILON:
		_landing_stall_elapsed = 0.0
	else:
		_landing_stall_elapsed += delta
	_landing_previous_distance = error_value
	if _landing_stall_elapsed > LANDING_STALL_TIMEOUT_SECONDS:
		_abort_landing(&"approach_obstructed")


func _complete_landing(berth: ShipBerth, target_basis: Basis) -> void:
	var authority_failure := _get_landing_authority_failure(berth)
	if not authority_failure.is_empty():
		_abort_landing(authority_failure)
		return
	var final_angular_change := rad_to_deg(
		Quaternion(global_basis).angle_to(Quaternion(target_basis))
	)
	if final_angular_change > LANDING_ROTATION_GUARD_ANGLE_DEGREES \
			and _is_landing_pose_obstructed(_landing_target):
		_abort_landing(&"approach_obstructed")
		return
	if berth != null:
		var collision_report := get_landing_collision_report()
		if not (collision_report.get("valid", false) as bool) \
				or not berth.contains_oriented_bounds(
					_landing_target,
					collision_report.get("local_bounds", AABB()) as AABB,
					0.05
				):
			_abort_landing(&"berth_clearance_lost")
			return
		if not berth.occupy(self, _landing_reservation_token):
			_abort_landing(&"reservation_lost")
			return
		authority_failure = _get_landing_authority_failure(berth)
		if not authority_failure.is_empty():
			_abort_landing(authority_failure)
			return
	global_transform = Transform3D(target_basis, _landing_target.origin)
	_retire_planetary_cruise(&"landing_completed", true)
	velocity = Vector3.ZERO
	_landing_active = false
	_landed = true
	_docked_latch = true
	_set_landing_phase(LANDING_PHASE_DOCKED)
	if _ship_audio_rig != null:
		_ship_audio_rig.play_docking()
	_landing_elapsed = 0.0
	_landing_stall_elapsed = 0.0
	_landing_previous_distance = 0.0
	landing_completed.emit()


func _abort_landing(reason: StringName) -> void:
	if not _landing_active:
		return
	_retire_planetary_cruise(&"landing_aborted", true)
	var released_lease := _release_landing_lease()
	if not _landing_contract.is_empty():
		_landing_contract["reservation_released_on_abort"] = released_lease
	_landing_active = false
	_landed = false
	_docked_latch = false
	_throttle = 0.0
	velocity = Vector3.ZERO
	_landing_elapsed = 0.0
	_landing_stall_elapsed = 0.0
	_landing_previous_distance = INF
	_landing_phase = LANDING_PHASE_ABORTED
	_landing_last_abort_reason = reason
	landing_aborted.emit(reason)


## Destruction and explicit reuse are terminal boundaries for an in-flight
## landing contract. Release the exact snapshotted lease before its opaque token
## is cleared. A completed landing can still retain an occupied lease snapshot;
## release that ownership silently because it is no longer an active abort.
func _end_landing_for_lifecycle(reason: StringName) -> void:
	if _landing_active:
		_abort_landing(reason)
	else:
		_release_landing_lease()


func _release_landing_lease() -> bool:
	var berth := _get_landing_berth()
	if berth == null or _landing_reservation_token.is_empty():
		return false
	return berth.release(self, _landing_reservation_token)


func _get_landing_berth() -> ShipBerth:
	if _landing_berth == null:
		return null
	var candidate: Variant = _landing_berth.get_ref()
	return candidate as ShipBerth if is_instance_valid(candidate) and candidate is ShipBerth else null


func _get_landing_authority_failure(berth: ShipBerth) -> StringName:
	if _landing_contract.is_empty():
		return &""
	if berth == null \
			or not is_instance_valid(berth) \
			or not berth.is_inside_tree() \
			or berth.get_instance_id() != _landing_berth_instance_id \
			or berth.get_berth_id() != _landing_berth_id:
		return &"berth_changed"
	var berth_parent := berth.get_parent()
	var parent_instance_id := (
		berth_parent.get_instance_id() if is_instance_valid(berth_parent) else 0
	)
	if parent_instance_id != _landing_berth_parent_instance_id \
			or not _landing_transforms_match(berth.get_dock_transform(), _landing_target) \
			or not berth.get_landing_half_extents().is_equal_approx(_landing_half_extents_snapshot) \
			or not berth.get_assist_capture_center().is_equal_approx(_landing_capture_center_snapshot) \
			or not berth.get_assist_capture_half_extents().is_equal_approx(
				_landing_capture_half_extents_snapshot
			) \
			or not is_equal_approx(
				berth.get_assist_capture_maximum_speed(),
				_landing_capture_maximum_speed_snapshot
			) \
			or not is_equal_approx(
				berth.get_assist_maximum_tilt_degrees(),
				_landing_capture_maximum_tilt_snapshot
			):
		return &"berth_changed"
	if _landing_reservation_token.is_empty() \
			or _landing_reserved_ship_id.is_empty() \
			or not berth.has_valid_lease(
				self,
				_landing_reservation_token,
				_landing_reserved_ship_id
			):
		return &"reservation_lost"
	return &""


func _is_landing_pose_obstructed(candidate_transform: Transform3D) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return true
	var space := get_world_3d().direct_space_state
	for child in get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or collision.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = candidate_transform * collision.transform
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		if not space.intersect_shape(query, 1).is_empty():
			return true
	return false


static func _landing_transforms_match(first: Transform3D, second: Transform3D) -> bool:
	return first.origin.distance_squared_to(second.origin) \
			<= LANDING_TRANSFORM_EPSILON * LANDING_TRANSFORM_EPSILON \
		and first.basis.x.distance_squared_to(second.basis.x) \
			<= LANDING_TRANSFORM_EPSILON * LANDING_TRANSFORM_EPSILON \
		and first.basis.y.distance_squared_to(second.basis.y) \
			<= LANDING_TRANSFORM_EPSILON * LANDING_TRANSFORM_EPSILON \
		and first.basis.z.distance_squared_to(second.basis.z) \
			<= LANDING_TRANSFORM_EPSILON * LANDING_TRANSFORM_EPSILON


func _clear_landing_authority_snapshot() -> void:
	_landing_berth = null
	_landing_berth_instance_id = 0
	_landing_berth_parent_instance_id = 0
	_landing_berth_id = &""
	_landing_reservation_token = &""
	_landing_reserved_ship_id = &""
	_landing_half_extents_snapshot = Vector3.ZERO
	_landing_capture_center_snapshot = Vector3.ZERO
	_landing_capture_half_extents_snapshot = Vector3.ZERO
	_landing_capture_maximum_speed_snapshot = 0.0
	_landing_capture_maximum_tilt_snapshot = 0.0


## Detached availability snapshot for the existing weapon consumer and HUD
## telemetry. It does not reserve a shot or resolve damage.
func get_weapon_fire_status() -> Dictionary:
	var reason := _get_weapon_unavailable_reason()
	var status: StringName = &"ready"
	if reason == &"weapon_overheated":
		status = &"overheated"
	elif reason == &"weapon_cooldown":
		status = &"cooldown"
	elif reason == &"engine_not_online":
		status = &"offline"
	elif not reason.is_empty():
		status = &"unavailable"
	return {
		"ready": reason.is_empty(),
		"status": status,
		"reason": reason,
		"heat": _weapon_heat,
		"cooldown_remaining": _weapon_timer,
		"recovery_remaining": _weapon_overheat_remaining,
	}.duplicate(true)


func _get_weapon_unavailable_reason() -> StringName:
	if _reset_for_reuse_mutation_blocked():
		return &"reset_for_reuse_pending"
	if _destroyed or _hull <= 0.0:
		return &"ship_destroyed"
	if _engine_state != ENGINE_ONLINE:
		return &"engine_not_online"
	var modifiers := get_operational_modifiers()
	if _get_damage_weapon_multiplier() <= 0.0 or bool(modifiers.get("fire_disabled", false)):
		return &"weapon_component_failed"
	if _weapon_overheated:
		return &"weapon_overheated"
	if _weapon_timer > 0.0:
		return &"weapon_cooldown"
	return &""


func _update_weapon_heat(delta: float) -> void:
	_weapon_heat = move_toward(
		_weapon_heat,
		0.0,
		WEAPON_HEAT_COOLING_PER_SECOND * delta
	)
	if not _weapon_overheated:
		_weapon_overheat_remaining = 0.0
		return
	_weapon_overheat_remaining = maxf(0.0, _weapon_overheat_remaining - delta)
	if _weapon_overheat_remaining <= 0.0:
		_weapon_overheated = false
		_weapon_heat = minf(_weapon_heat, WEAPON_RECOVERY_HEAT)


func _fire_weapon() -> void:
	var modifiers := get_operational_modifiers()
	var fire_power := _get_damage_weapon_multiplier()
	if not bool(get_weapon_fire_status().get("ready", false)):
		return
	_weapon_timer = weapon_cooldown / fire_power
	_weapon_heat = clampf(_weapon_heat + WEAPON_HEAT_PER_SHOT, 0.0, 1.0)
	if _weapon_heat >= 1.0:
		_weapon_overheated = true
		_weapon_overheat_remaining = WEAPON_OVERHEAT_DURATION
	var muzzle := _muzzle_left if _fire_from_left else _muzzle_right
	_fire_from_left = not _fire_from_left
	var aiming_camera := get_camera()
	var screen_center := aiming_camera.get_viewport().get_visible_rect().size * 0.5
	var camera_direction := aiming_camera.project_ray_normal(screen_center).normalized()
	var targeting_distance := _get_weapon_targeting_distance()
	var ray_end := aiming_camera.global_position + camera_direction * targeting_distance
	var convergence_point := ray_end
	# Resolve the reticle ray first so both offset cannons converge exactly on
	# nearby geometry and range drones. Damage remains owned by game_flow.gd;
	# this query only corrects the emitted direction.
	if is_inside_tree() and not bool(modifiers.get("targeting_disabled", false)):
		var query := PhysicsRayQueryParameters3D.create(
			aiming_camera.global_position,
			ray_end,
			WEAPON_AIM_MASK,
			[get_rid()]
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			convergence_point = hit.get("position", ray_end)
	var aimed_direction := (convergence_point - muzzle.global_position).normalized()
	projectile_fired.emit(muzzle.global_position, aimed_direction)


func _update_presentation(delta: float, command: ShipCommand) -> void:
	if _visual_root != null:
		var bank_input := command.yaw if _piloted and _engine_state == ENGINE_ONLINE else 0.0
		var bank_target := -bank_input * deg_to_rad(visual_bank_degrees)
		_visual_bank = lerpf(_visual_bank, bank_target, 1.0 - exp(-7.0 * delta))
		_visual_root.rotation.z = _visual_bank
	if _camera_pivot != null:
		_target_chase_camera_distance = _clamp_chase_camera_distance(
			_target_chase_camera_distance
		)
		_camera_spring_arm.spring_length = lerpf(
			_camera_spring_arm.spring_length,
			_target_chase_camera_distance,
			1.0 - exp(-chase_camera_zoom_response * delta)
		)
		var ship_basis := global_basis.orthonormalized()
		var target_rotation := Quaternion(ship_basis).normalized()
		if not _chase_follow_rotation.is_finite():
			_chase_follow_rotation = target_rotation
		var follow_weight := 1.0 - exp(-chase_camera_rotation_response * delta)
		var candidate := _chase_follow_rotation.slerp(target_rotation, follow_weight).normalized()
		var lag_radians := candidate.angle_to(target_rotation)
		var lag_limit := deg_to_rad(maximum_chase_camera_rotation_lag_degrees)
		if lag_limit <= 0.0:
			candidate = target_rotation
			lag_radians = 0.0
		elif lag_radians > lag_limit:
			candidate = target_rotation.slerp(candidate, lag_limit / lag_radians).normalized()
			lag_radians = lag_limit
		_chase_follow_rotation = candidate
		_chase_camera_rotation_lag_degrees = rad_to_deg(lag_radians)
		var local_velocity := ship_basis.inverse() * velocity
		var target_tilt := clampf(-local_velocity.x / maximum_speed, -0.08, 0.08)
		_chase_camera_bank = lerpf(
			_chase_camera_bank,
			target_tilt,
			1.0 - exp(-4.0 * delta)
		)
		var bank_basis := Basis(Vector3.FORWARD, _chase_camera_bank)
		# Only the boom orbit is softened. The optical basis is forced back to the
		# physical hull so the reticle, muzzle convergence, and visible nose never
		# disagree about where the craft is pointing.
		_camera_pivot.global_basis = Basis(_chase_follow_rotation) * bank_basis
		if _camera != null:
			_camera.global_basis = ship_basis * bank_basis
	var engine_level := 0.0
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	if _engine_state == ENGINE_STARTING:
		engine_level = 0.25 + 0.15 * sin(_elapsed * 18.0)
	elif _engine_state == ENGINE_ONLINE:
		engine_level = 0.42 + absf(_throttle) * 0.58
		if _damage_presentation != null:
			engine_level *= clampf(
				_damage_presentation.get_engine_power_multiplier(), 0.0, 1.0
			)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var exhaust_geometry := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for glow in _engine_glows:
		if not is_instance_valid(glow):
			continue
		glow.scale.z = lerpf(
			glow.scale.z,
			0.45 + engine_level * 1.4 * exhaust_geometry,
			1.0 - exp(-9.0 * delta)
		)
		glow.visible = engine_level > 0.01
	for core in _engine_core_glows:
		if is_instance_valid(core):
			core.visible = engine_level > 0.01
	var torrent_presentation := _get_live_torrent_hero_presentation()
	if torrent_presentation != null and _canopy_pivot != null:
		torrent_presentation.set_canopy_fraction(
			_canopy_pivot.rotation.x / maxf(CANOPY_OPEN_ANGLE, 0.001)
		)
		_sync_torrent_close_overlay_visibility()
	for light in _engine_lights:
		if not is_instance_valid(light):
			continue
		light.light_energy = engine_level * 2.6
	_apply_engine_exhaust_damage_presentation(
		_engine_glows,
		_engine_lights,
		_engine_state in [ENGINE_STARTING, ENGINE_ONLINE] and not _destroyed,
		exhaust_profile
	)
	if _cockpit_readout != null:
		var weapon_status := get_weapon_fire_status()
		var weapon_line := "WPN READY  //  HEAT %03d%%" % roundi(_weapon_heat * 100.0)
		match StringName(weapon_status.get("status", &"unavailable")):
			&"overheated":
				weapon_line = "! WPN OVERHEAT  //  %.1fs" % _weapon_overheat_remaining
			&"cooldown":
				weapon_line = "WPN CYCLING  //  HEAT %03d%%" % roundi(_weapon_heat * 100.0)
			&"offline":
				weapon_line = "WPN SAFE  //  ENGINE OFFLINE"
			&"unavailable":
				weapon_line = "! WPN UNAVAILABLE"
		_cockpit_readout.text = "SPD %03d   THR %+03d\n%s  //  %s\n%s" % [
			roundi(velocity.length()),
			roundi(_throttle * 100.0),
			str(_engine_state),
			"PATH" if velocity.length() >= 1.5 else "HOLD",
			weapon_line,
		]
		_cockpit_readout.modulate = (
			Color("ff6b5f") if _weapon_overheated
			else (Color("ffb85c") if _weapon_heat >= 0.70 else Color("8de8e4"))
		)
	if _cockpit_practical_light != null:
		var practical_energy := 0.04
		if _engine_state == ENGINE_STARTING:
			practical_energy = 0.18 + sin(_elapsed * 8.0) * 0.04
		elif _engine_state == ENGINE_ONLINE:
			practical_energy = 0.30
		if _hull <= maximum_hull * 0.3:
			practical_energy = 0.25 + sin(_elapsed * 9.0) * 0.07
		_cockpit_practical_light.light_energy = clampf(practical_energy, 0.04, 0.35)
		_cockpit_practical_light.light_color = Color("ff746a") if _hull <= maximum_hull * 0.3 else Color("d8c7a5")


## Creates or adopts the ship-local component model and derives its roster from
## this craft's initial common collision envelope. Called once from `_ready()`
## after `_build_ship()`; a scene-authored `ShipComponentDamage` child wins if
## present, so no variant is forced to take the programmatic one. Fleet variants
## use the one-shot protected seam below after installing final root collision.
func _ensure_component_damage() -> void:
	if _component_damage == null:
		_component_damage = get_node_or_null("ShipComponentDamage") as ShipComponentDamage
	if _component_damage == null:
		_component_damage = ShipComponentDamage.new()
		_component_damage.name = "ShipComponentDamage"
		add_child(_component_damage)
	if not _component_damage.component_state_changed.is_connected(_on_component_state_changed):
		_component_damage.component_state_changed.connect(_on_component_state_changed)
	if not _component_damage.component_repair_committed.is_connected(_on_component_repair_committed):
		_component_damage.component_repair_committed.connect(_on_component_repair_committed)
	var collision_report := get_landing_collision_report()
	var local_bounds: AABB = collision_report.get("local_bounds", AABB())
	if not bool(collision_report.get("valid", false)):
		# A craft with no usable root collision keeps an unconfigured model. Every
		# entry point below fails closed rather than inventing an envelope.
		return
	var configured := _component_damage.configure(local_bounds, maxf(maximum_hull, 0.001))
	if configured and _component_damage_owner_capability == null:
		_component_damage_owner_capability = (
			_component_damage.claim_owner_mutation_capability()
		)
	if configured and not _component_damage.is_owner_mutation_capability_current(
		_component_damage_owner_capability
	):
		push_error("HeroShip could not claim the component mutation owner capability")
	_last_component_damage_revision = -1


## One-shot protected seam for fleet subclasses during their initial `_ready()`.
##
## The existing model identity and signal connection are retained. A successful
## call changes only its captured bounds/derived anchors, preserves any integrity,
## and closes the gate before returning. Repeated calls return the cached result
## without another configure/revision; late calls on Torrent fail closed. The
## gate is never reopened by detach/re-entry or `reset_for_reuse()`.
func _reconfigure_component_damage_from_final_root_collision() -> bool:
	if _component_damage_final_collision_capture_attempted:
		return _component_damage_final_collision_capture_accepted
	_component_damage_final_collision_capture_attempted = true
	if not _component_damage_final_collision_capture_open:
		return false
	_component_damage_final_collision_capture_open = false
	if _component_damage == null or not _component_damage.is_configured():
		return false
	var collision_report := get_landing_collision_report()
	if not bool(collision_report.get("valid", false)):
		return false
	var local_bounds: AABB = collision_report.get("local_bounds", AABB())
	_component_damage_final_collision_capture_accepted = _component_damage.configure(
		local_bounds,
		maximum_hull
	)
	if _component_damage_final_collision_capture_accepted:
		_last_component_damage_revision = -1
	return _component_damage_final_collision_capture_accepted


func _close_component_damage_final_collision_capture() -> void:
	_component_damage_final_collision_capture_open = false


## Advances repair and republishes the localized presentation channel. Repair is
## authorized only while this craft is physically at rest and intact, so a hit
## taken in a dogfight stays readable for the whole engagement and clears once the
## craft is berthed. Nothing in the game waits on it: destruction recovery goes
## through `reset_for_reuse()`, which restores the whole roster in one call.
func _sync_component_damage(delta: float) -> void:
	if _reset_for_reuse_mutation_blocked():
		return
	if _component_damage == null or not _component_damage.is_configured():
		return
	_component_damage.tick_repair(delta, _landed and not _destroyed and not _landing_active)
	var revision := _component_damage.get_revision()
	if revision == _last_component_damage_revision:
		return
	_last_component_damage_revision = revision
	if _damage_presentation != null:
		_damage_presentation.set_component_damage_states(
			_component_damage.get_component_states()
		)


## Records an already-applied hull loss against the component roster. This is an
## observation: the hull value is decided before this runs and is not read back.
func _record_component_damage(
	amount: float,
	world_hit_position: Vector3,
	collision_contact: bool = false
	) -> Dictionary:
	if _component_damage == null or not _component_damage.is_configured():
		return {}
	var local_hit_position := Vector3.INF
	if is_inside_tree() and world_hit_position.is_finite():
		local_hit_position = to_local(world_hit_position)
	if collision_contact:
		return _component_damage.record_collision_damage(amount, local_hit_position)
	elif local_hit_position.is_finite():
		return _component_damage.record_projectile_damage(amount, local_hit_position)
	return _component_damage.record_damage(amount, local_hit_position)


## Presentation consumes the component operation that was already accepted; it
## never performs a parallel region query. A rejected/multi-section operation
## keeps the caller's exact point, preserving the generic fallback contract.
func _component_impact_world_position(
	component_damage_result: Dictionary,
	fallback_world_position: Vector3
	) -> Vector3:
	if not bool(component_damage_result.get("accepted", false)) or _component_damage == null:
		return fallback_world_position
	var components := component_damage_result.get("components", {}) as Dictionary
	if components.size() != 1:
		return fallback_world_position
	var component_id := StringName(components.keys()[0])
	for state: Dictionary in _component_damage.get_component_states():
		if StringName(state.get("id", &"")) != component_id:
			continue
		var local_position := state.get("local_position", Vector3.INF) as Vector3
		if local_position.is_finite() and is_inside_tree():
			return to_global(local_position)
		break
	return fallback_world_position


func _component_impact_id(component_damage_result: Dictionary) -> StringName:
	if not bool(component_damage_result.get("accepted", false)):
		return &""
	var components := component_damage_result.get("components", {}) as Dictionary
	return StringName(components.keys()[0]) if components.size() == 1 else &""


func _on_deferred_component_impact_committed(
	component_id: StringName,
	intensity: float
	) -> void:
	if _ship_audio_rig != null:
		_ship_audio_rig.present_component_impact(component_id, intensity)


func get_component_damage() -> ShipComponentDamage:
	return _component_damage


## Explicit binding seam for repair-capable Hero compositions. It grants no
## repair admission or component mutation; it only lets this craft present the
## interruption receipt produced by the existing RepairAuthority. Current crew
## craft remain compatible through the automatic property discovery below.
func bind_repair_damage_interrupt_authority(authority: RefCounted) -> Dictionary:
	if authority == null or not is_instance_valid(authority) \
			or not authority.has_method(&"has_active_repair") \
			or not authority.has_method(&"get_snapshot") \
			or not authority.has_method(&"observe_component_damage_revision") \
			or not authority.has_method(&"interrupt_for_authoritative_component_damage"):
		return {"accepted": false, "reason": &"invalid_repair_authority"}
	var snapshot := authority.call(&"get_snapshot") as Dictionary
	if StringName(snapshot.get("target_id", &"")) != get_ship_id():
		return {"accepted": false, "reason": &"target_mismatch"}
	if _component_damage == null or not _component_damage.is_configured() \
			or int(snapshot.get("generation", 0)) != _component_damage.get_ledger_generation():
		return {"accepted": false, "reason": &"stale_generation"}
	_repair_damage_interrupt_authority = authority
	return {"accepted": true, "reason": &"repair_damage_interrupt_bound"}


func _resolve_repair_damage_interrupt_authority() -> RefCounted:
	if _repair_damage_interrupt_authority != null \
			and is_instance_valid(_repair_damage_interrupt_authority) \
			and bool(_repair_damage_interrupt_authority.call(&"has_active_repair")):
		return _repair_damage_interrupt_authority
	# Jovian, Halyard, and Bulwark already own this exact field and authority.
	# Discovering it here keeps the accepted-damage hook on HeroShip, including
	# future repair-capable variants, without changing role admission code.
	var has_engineer_authority_property := false
	for property: Dictionary in get_property_list():
		if StringName(property.get("name", &"")) == &"_engineer_repair_authority":
			has_engineer_authority_property = true
			break
	if not has_engineer_authority_property:
		return null
	var candidate: Variant = get(&"_engineer_repair_authority")
	if not candidate is RefCounted or candidate == null \
			or not is_instance_valid(candidate) \
			or not candidate.has_method(&"has_active_repair") \
			or not bool(candidate.call(&"has_active_repair")):
		return null
	var bound := bind_repair_damage_interrupt_authority(candidate as RefCounted)
	return candidate as RefCounted if bool(bound.get("accepted", false)) else null


func _interrupt_repair_from_component_damage(
	authority: RefCounted,
	previous_revision: int,
	damage_result: Dictionary,
	damage_kind: StringName
	) -> void:
	if authority == null or not is_instance_valid(authority):
		return
	var component_ids: Array = []
	for component_id: Variant in (damage_result.get("components", {}) as Dictionary).keys():
		component_ids.append(StringName(component_id))
	component_ids.sort()
	var receipt := authority.call(
		&"interrupt_for_authoritative_component_damage",
		{
			"target_id": get_ship_id(),
			"generation": _component_damage.get_ledger_generation(),
			"previous_revision": previous_revision,
			"revision": int(damage_result.get("revision", previous_revision)),
			"accepted": bool(damage_result.get("accepted", false)),
			"damage_kind": damage_kind,
			"component_ids": component_ids,
		}
	) as Dictionary
	if not bool(receipt.get("accepted", false)):
		return
	component_repair_interrupted.emit(receipt.duplicate(true))
	_publish_engineer_repair_damage_interruption(receipt)


## Existing crew craft already publish this state through their canonical
## network snapshot. Updating it through their shared setter makes damage
## interruption immediately visible without giving HeroShip repair authority.
func _publish_engineer_repair_damage_interruption(receipt: Dictionary) -> void:
	if not has_method(&"get_engineer_repair_state") \
			or not has_method(&"_set_engineer_repair_state"):
		return
	var state := call(&"get_engineer_repair_state") as Dictionary
	if StringName(state.get("status", &"")) != &"repairing" \
			or int(state.get("token", -1)) != int(receipt.get("token", -2)):
		return
	state["status"] = &"interrupted"
	state["reason"] = StringName(receipt.get("reason", &"authoritative_component_damage"))
	state["active"] = false
	state["receipt"] = receipt.duplicate(true)
	call(&"_set_engineer_repair_state", state)


## Deep-copied audit of the craft's component integrity.
func get_component_damage_report() -> Dictionary:
	if _component_damage == null:
		return {
			"schema_version": ShipComponentDamage.SCHEMA_VERSION,
			"interpretation": ShipComponentDamage.INTERPRETATION,
			"configured": false,
			"component_count": 0,
			"failed_count": 0,
			"impaired_count": 0,
			"worst_integrity": 1.0,
			"components": [] as Array[Dictionary],
		}
	return _component_damage.get_component_report()


## Detached post-reuse evidence for all production HeroShip variants. Authority
## remains in the component ledger and reset transaction; this audit can neither
## repair state nor clear presentation residue.
func get_component_recovery_report() -> Dictionary:
	var errors := PackedStringArray()
	if _component_damage == null or not _component_damage.is_configured():
		errors.append("component_model_unavailable")
	var model := (
		_component_damage.get_ledger_snapshot()
		if _component_damage != null and _component_damage.is_configured()
		else {}
	) as Dictionary
	var model_generation := int(model.get("generation", 0))
	if _destroyed or not is_equal_approx(_hull, maximum_hull):
		errors.append("hull_not_restored")
	if int(model.get("last_operation_sequence", -2)) != -1:
		errors.append("component_sequence_not_reset")
	for component_variant in model.get("components", []) as Array:
		if not component_variant is Dictionary:
			errors.append("invalid_component_state")
			continue
		var component := component_variant as Dictionary
		var stage := component.get("stage", {}) as Dictionary
		if (
			not is_equal_approx(
				float(component.get("current_health", -1.0)),
				float(component.get("maximum_health", 0.0))
			)
			or StringName(stage.get("stage_id", &"")) != &"nominal"
			or bool(stage.get("disabled", true))
			or not is_equal_approx(float(stage.get("performance_multiplier", -1.0)), 1.0)
		):
			errors.append("component_not_nominal:%s" % component.get("component_id", &""))
	var modifiers := get_operational_modifiers()
	if (
		modifiers.is_empty()
		or bool(modifiers.get("mobility_disabled", true))
		or bool(modifiers.get("fire_disabled", true))
		or bool(modifiers.get("targeting_disabled", true))
		or not is_equal_approx(float(modifiers.get("mobility_multiplier", -1.0)), 1.0)
		or not is_equal_approx(float(modifiers.get("fire_multiplier", -1.0)), 1.0)
		or not is_equal_approx(float(modifiers.get("targeting_multiplier", -1.0)), 1.0)
	):
		errors.append("engine_weapon_sensor_not_restored")
	if get_engine_exhaust_damage_presentation_profile().get("stage", &"") != &"nominal":
		errors.append("engine_presentation_residue")
	if get_weapon_component_presentation_profile().get("stage", &"") != &"nominal":
		errors.append("weapon_presentation_residue")
	if _deferred_terminal_presentation_receipt_id >= 0:
		errors.append("pending_terminal_presentation")
	if _visual_root == null or not is_instance_valid(_visual_root) or not _visual_root.visible:
		errors.append("component_visual_root_not_restored")
	var presentation_report := (
		_damage_presentation.get_component_recovery_report(model_generation)
		if is_instance_valid(_damage_presentation)
		else {"valid": false, "errors": PackedStringArray(["presentation_unavailable"])}
	) as Dictionary
	for presentation_error in presentation_report.get("errors", PackedStringArray()) as PackedStringArray:
		errors.append(String(presentation_error))
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"hero_ship_component_recovery",
		"ship_id": ship_id,
		"model_generation": model_generation,
		"presentation_generation": int(presentation_report.get(
			"presentation_generation", 0
		)),
		"component_sequence": int(model.get("last_operation_sequence", -2)),
		"pending_presentations": get_pending_damage_presentation_count(),
		"presentation": presentation_report.duplicate(true),
	}.duplicate(true)


## Detached operational consequences consumed by this ship's existing control
## authorities. ComponentDamageModel remains data-only and owns no movement,
## projectile dispatch, aim query, or repair decision.
func get_operational_modifiers() -> Dictionary:
	return _component_damage.get_operational_modifiers() if _component_damage != null else {}


func _on_component_state_changed(
		component_id: StringName,
		state: int,
		integrity: float
	) -> void:
	_sync_weapon_component_presentation()
	component_damage_changed.emit(component_id, state, integrity)


func _on_component_repair_committed(progress: Dictionary) -> void:
	_sync_weapon_component_presentation()
	component_repair_progressed.emit(progress.duplicate(true))


func _sync_damage_presentation() -> void:
	if _damage_presentation == null:
		return
	if _destroyed and _deferred_terminal_presentation_receipt_id >= 0:
		return
	var state := HeroDamagePresentation.STATE_POWERED_DOWN
	if _hull <= 0.0:
		state = HeroDamagePresentation.STATE_DESTROYED
	elif _engine_state in [ENGINE_STARTING, ENGINE_ONLINE]:
		state = HeroDamagePresentation.STATE_ACTIVE
	_damage_presentation.update_state(
		_hull / maxf(maximum_hull, 0.001),
		state,
		velocity
	)
	_sync_weapon_component_presentation()


func _apply_collision_damage(pre_collision_velocity: Vector3) -> void:
	if _impact_cooldown_remaining > 0.0 or _landing_active or _destroyed:
		return
	var strongest_closing_speed := 0.0
	var strongest_position := global_position
	var strongest_normal := Vector3.UP
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collision_position := collision.get_position()
		var collision_normal := collision.get_normal()
		if (
			not collision_position.is_finite()
			or not collision_normal.is_finite()
			or collision_normal.is_zero_approx()
		):
			continue
		collision_normal = collision_normal.normalized()
		var closing_speed := maxf(0.0, -pre_collision_velocity.dot(collision_normal))
		if closing_speed > strongest_closing_speed:
			strongest_closing_speed = closing_speed
			strongest_position = collision_position
			strongest_normal = collision_normal
	if strongest_closing_speed <= impact_damage_threshold:
		return
	_impact_cooldown_remaining = impact_damage_cooldown
	var impact_damage := (strongest_closing_speed - impact_damage_threshold) * impact_damage_scale
	_apply_resolved_collision_damage(impact_damage, strongest_position, strongest_normal)
	# Collision damage has no travelling pulse endpoint. Keep the bounded local
	# operational thud for surviving hulls; combat hits are exclusively routed by
	# GameFlow into the authored positional impact bank.
	if not _destroyed and _ship_audio_rig != null:
		_ship_audio_rig.play_hull_hit(clampf(impact_damage / 18.0, 0.35, 1.5))


## Keeps collision routing inside the existing virtual damage chain so every
## retained craft preserves its destruction cleanup. The scope is synchronous;
## component generation and replay fencing remain in ShipComponentDamage.
func _apply_resolved_collision_damage(
	amount: float,
	world_hit_position: Vector3,
	world_hit_normal: Vector3
	) -> bool:
	if (
		not world_hit_position.is_finite()
		or not world_hit_normal.is_finite()
		or world_hit_normal.is_zero_approx()
	):
		return false
	_collision_component_routing_active = true
	apply_damage(amount, world_hit_position, world_hit_normal.normalized())
	_collision_component_routing_active = false
	return true


func _hide_destroyed_hull(destruction_serial: int) -> void:
	if destruction_serial != _destruction_serial or not _destroyed:
		return
	if _visual_root != null:
		_visual_root.visible = false
	_destroyed_hull_hide_pending = false


func _resume_destroyed_hull_hide_after_reentry() -> void:
	if not is_inside_tree() or not _destroyed or not _destroyed_hull_hide_pending:
		return
	get_tree().create_timer(0.18).timeout.connect(
		_hide_destroyed_hull.bind(_destruction_serial),
		CONNECT_ONE_SHOT
	)


func _get_damage_engine_multiplier() -> float:
	var presentation_power := (
		clampf(_damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
		if _damage_presentation != null
		else 1.0
	)
	var modifiers := get_operational_modifiers()
	var component_power := clampf(
		float(modifiers.get("mobility_multiplier", 1.0)),
		0.0,
		1.0
	)
	return minf(presentation_power, component_power)


func _get_damage_weapon_multiplier() -> float:
	return clampf(
		float(get_operational_modifiers().get("fire_multiplier", 1.0)),
		0.0,
		1.0
	)


func _get_damage_targeting_multiplier() -> float:
	return clampf(
		float(get_operational_modifiers().get("targeting_multiplier", 1.0)),
		0.0,
		1.0
	)


func _get_weapon_targeting_distance() -> float:
	return WEAPON_AIM_DISTANCE * lerpf(
		FAILED_SENSOR_MANUAL_AIM_DISTANCE_FACTOR,
		1.0,
		_get_damage_targeting_multiplier()
	)


func _apply_ship_definition() -> void:
	if ship_definition == null:
		return
	if not ship_definition.is_definition_valid():
		push_warning("Ship definition rejected for %s: %s" % [name, "; ".join(ship_definition.get_validation_errors())])
		return
	ship_id = ship_definition.get_ship_id()
	display_name = ship_definition.get_display_name()
	role_name = ship_definition.get_role()
	var profile := ship_definition.get_flight_profile()
	for property_name: String in profile:
		set(property_name, profile[property_name])
	var systems := ship_definition.get_systems_profile()
	for property_name: String in systems:
		set(property_name, systems[property_name])


func _on_damage_stage_changed(stage: int, _health_ratio: float) -> void:
	damage_stage_changed.emit(stage, _damage_presentation.get_status())


func _build_ship() -> void:
	if _built:
		return
	_built = true
	collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	collision_mask = PhysicsLayers.SHIP_BODY_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	_create_materials()
	_visual_root = Node3D.new()
	_visual_root.name = "TorrentVisual"
	add_child(_visual_root)

	# Every HeroShip-derived craft needs this exact functional cockpit hierarchy.
	# Arrow and Jovian reparent it into their own presentation after base ready.
	_build_cockpit()
	if _uses_torrent_reconstruction_presentation():
		_apply_torrent_reconstruction_metadata()
		_build_dated_2011_torrent_form()
		_apply_torrent_2011_cockpit_presentation()
		_build_torrent_modern_systems()

	_build_markers_and_camera()
	_build_collision()
	if _uses_torrent_reconstruction_presentation():
		_install_torrent_hero_presentation()


## Variants override this before HeroShip._ready() builds the temporary common
## rig. This keeps Torrent-only evidence claims and colour cues off Arrow/Jovian.
func _uses_torrent_reconstruction_presentation() -> bool:
	return true


func _apply_torrent_reconstruction_metadata() -> void:
	set_meta("identity_lock", TORRENT_IDENTITY_LOCK)
	set_meta("reconstruction_status", TORRENT_RECONSTRUCTION_STATUS)
	set_meta("authenticated_2009_continuity", false)
	_visual_root.set_meta("geometry_status", TORRENT_GEOMETRY_STATUS)
	_visual_root.set_meta("identity_lock", TORRENT_IDENTITY_LOCK)
	_visual_root.set_meta("reconstruction_status", TORRENT_RECONSTRUCTION_STATUS)
	_visual_root.set_meta("authenticated_historical_silhouette", false)
	_visual_root.set_meta("authenticated_exact_geometry", false)
	_visual_root.set_meta("construction_revision", &"torrent_b5_observed_authored_macroform_v1")
	_visual_root.set_meta(
		"content_note",
		"B5 source-locks the observed craft identity and broad form. Its upload "
		+ "date does not establish the recording date or live build revision; exact "
		+ "geometry, systems, finish, handling, and 2009 continuity remain unproved."
	)


func _build_dated_2011_torrent_form() -> void:
	var authored_macroform := TORRENT_AUTHORED_MACROFORM_SCENE.instantiate() as Node3D
	if authored_macroform == null:
		push_error("Unable to instantiate the checked-in Torrent authored macroform")
		return
	authored_macroform.name = "TorrentAuthoredMacroform"
	_visual_root.add_child(authored_macroform)


func _install_torrent_hero_presentation() -> void:
	if _torrent_hero_presentation != null:
		return
	var presentation := TORRENT_HERO_PRESENTATION_SCENE.instantiate() as TorrentHeroPresentation
	if presentation == null:
		push_error("Unable to instantiate the Torrent hero presentation adapter")
		return
	presentation.name = "TorrentHeroPresentation"
	_visual_root.add_child(presentation)
	presentation._build_once()
	# `_ready()` has executed synchronously after adding the child in-tree. Treat
	# the imported contract transactionally: a broken asset never hides or moves
	# the trusted fallback craft.
	var report := presentation.get_asset_audit_report()
	if not bool(report.get("valid", false)):
		push_error(
			"Torrent hero presentation rejected: %s"
			% "; ".join(report.get("errors", PackedStringArray()))
		)
		presentation.queue_free()
		return
	_torrent_hero_presentation = presentation
	if not presentation.lod_changed.is_connected(_on_torrent_lod_changed):
		presentation.lod_changed.connect(_on_torrent_lod_changed)
	var hero_root := presentation.get_asset_root()
	if hero_root != null:
		_tag_modern_interpretation(hero_root)
	# Keep the established gameplay roots as authority, but make the Blender
	# meshes the only near-field cockpit and canopy presentation. The legacy art
	# is retained under explicit hidden fallback gates rather than double-rendered.
	var imported_cockpit := presentation.get_cockpit_art_root()
	var imported_canopy := presentation.get_canopy_pivot()
	if imported_cockpit == null or imported_canopy == null:
		push_error("Torrent hero presentation lacks cockpit/canopy art roots")
		presentation.queue_free()
		return
	_legacy_torrent_cockpit_art = Node3D.new()
	_legacy_torrent_cockpit_art.name = "LegacyCockpitArt"
	_cockpit_root.add_child(_legacy_torrent_cockpit_art)
	for cockpit_child in _cockpit_root.get_children():
		if (
			cockpit_child == _legacy_torrent_cockpit_art
			or cockpit_child == _pilot_seat_anchor
			or cockpit_child == _boarding_entry_marker
			or cockpit_child == _cockpit_camera
			or cockpit_child == _cockpit_practical_light
		):
			continue
		cockpit_child.reparent(_legacy_torrent_cockpit_art, true)
	_legacy_torrent_cockpit_art.visible = false
	# Keep imported cockpit ownership inside the audited asset hierarchy. Moving
	# it under the functional marker root made the adapter invalidate its own
	# immutable graph after a successful preflight audit.
	if _cockpit_readout != null:
		_cockpit_readout.reparent(_cockpit_root, true)
	var imported_seat := imported_cockpit.get_node_or_null("CrimsonSeatPan") as MeshInstance3D
	if imported_seat != null:
		imported_seat.set_meta("historically_observed_colour", true)
		imported_seat.set_meta("source_reference", &"B5")
	_torrent_unknown_function_panel = (
		presentation.get_lod0_root().get_node_or_null("AmberUnknownFunctionPanel")
		as MeshInstance3D
	)
	if _torrent_unknown_function_panel != null:
		_torrent_unknown_function_panel.set_meta("physical_size", Vector2(0.72, 0.26))
		_torrent_unknown_function_panel.set_meta("historical_function", &"unknown")
		_torrent_unknown_function_panel.set_meta("historical_function_unresolved", true)
		_torrent_unknown_function_panel.set_meta("historically_supported", true)
		_torrent_unknown_function_panel.set_meta("source_reference", &"B5")
		_torrent_unknown_function_panel.set_meta("silhouette_role", &"warm_forward_panel")

	_legacy_torrent_canopy_art = Node3D.new()
	_legacy_torrent_canopy_art.name = "LegacyCanopyArt"
	_canopy_pivot.add_child(_legacy_torrent_canopy_art)
	for canopy_child in _canopy_pivot.get_children():
		if (
			canopy_child == _legacy_torrent_canopy_art
		):
			continue
		canopy_child.reparent(_legacy_torrent_canopy_art, true)
	_legacy_torrent_canopy_art.visible = false
	# The imported pivot stays in the adapter's immutable hierarchy. The live
	# functional pivot remains canopy-motion authority; `_update_presentation`
	# mirrors only its bounded open fraction onto the imported visual pivot.
	presentation.set_imported_canopy_visible(true)
	presentation.set_canopy_fraction(1.0 if _canopy_open else 0.0)
	_sync_torrent_close_overlay_visibility()
	_legacy_torrent_presentation = Node3D.new()
	_legacy_torrent_presentation.name = "LegacyFarPresentation"
	_visual_root.add_child(_legacy_torrent_presentation)
	for child_name in [&"TorrentAuthoredMacroform", &"ModernSystems"]:
		var legacy_child := _visual_root.get_node_or_null(NodePath(String(child_name))) as Node3D
		if legacy_child != null:
			legacy_child.reparent(_legacy_torrent_presentation, true)
	_legacy_torrent_presentation.visible = false
	# The Blender craft owns near-field engine exhaust geometry. Keep the legacy
	# plumes out of the update roster while their whole fallback parent is hidden.
	_engine_glows.clear()
	_engine_core_glows.clear()
	for plume in presentation.get_engine_plumes():
		plume.visible = false
		_engine_glows.append(plume)
	for core in presentation.get_engine_cores():
		core.visible = false
		_engine_core_glows.append(core)
	_visual_root.set_meta("construction_revision", &"torrent_blender_hero_v1")


func _apply_torrent_2011_cockpit_presentation() -> void:
	# B5 supports a central physical pilot area and a red seat, but not this
	# cockpit's exact shell, controls, restraints, or camera construction. Keep
	# the broad observation in dedicated metadata while the hierarchy itself is
	# explicitly modern so descendants cannot inherit an accidental source claim.
	_tag_modern_interpretation(_cockpit_root)
	_cockpit_root.set_meta("pilot_capacity", 1)
	_cockpit_root.set_meta("historical_access", &"physical_central")
	_cockpit_root.set_meta("historical_access_source_reference", &"B5")
	for seat_name in ["SeatPan", "SeatBack", "Headrest", "SeatBolster"]:
		for candidate in _cockpit_root.find_children(seat_name, "MeshInstance3D", true, false):
			(candidate as MeshInstance3D).material_override = _materials.seat_red if seat_name != "Headrest" else _materials.seat_red_light
	var seat_pan := _cockpit_root.get_node_or_null("SeatPan") as MeshInstance3D
	if seat_pan != null:
		seat_pan.set_meta("historically_observed_colour", true)
		seat_pan.set_meta("source_reference", &"B5")
	_canopy_pivot.set_meta("evidence_status", &"modern_interpretation")
	_canopy_pivot.set_meta("design_origin", &"modern")
	_canopy_pivot.set_meta("historically_supported", false)
	var canopy_glass := _canopy_pivot.get_node_or_null("CanopyGlass") as MeshInstance3D
	if canopy_glass != null:
		canopy_glass.material_override = _materials.neutral_glass
	# B5's warm element is kept small and restrained instead of becoming the
	# former shield-sized cyan/amber slab. Its tapered outline and low placement
	# preserve a clear pilot sight channel while remaining visible from outside.
	var forward_panel := _trapezoid_panel(
		_canopy_pivot,
		"ForwardPanel",
		Vector3(0.0, 0.55, -2.90),
		0.90,
		1.10,
		0.28,
		0.035,
		_materials.amber_panel
	)
	forward_panel.set_meta("physical_size", Vector2(1.10, 0.28))
	forward_panel.set_meta("historical_function", &"unknown")
	forward_panel.set_meta("historical_function_unresolved", true)
	forward_panel.set_meta("silhouette_role", &"warm_forward_panel")
	forward_panel.set_meta("source_reference", &"B5")

	# The exact hood, texture and display are explicitly modern. Re-meshing in
	# place preserves the inherited functional cockpit objects that Arrow and
	# Jovian adopt, while giving Torrent a less slab-like, low-glare pilot view.
	var cluster := _cockpit_root.get_node_or_null("InstrumentCluster") as Node3D
	if cluster != null:
		cluster.position = Vector3(0.0, 2.84, -1.56)
		cluster.rotation.x = deg_to_rad(-10.0)
		var hood := cluster.get_node_or_null("InstrumentHood") as MeshInstance3D
		if hood != null:
			hood.mesh = _trapezoid_prism_mesh(1.42, 1.18, 0.42, 0.24, _materials.cockpit_anti_glare)
			hood.material_override = _materials.cockpit_anti_glare
			hood.position = Vector3(0.0, -0.01, 0.0)
			hood.set_meta("presentation_only", true)
		var primary_display := cluster.get_node_or_null("PrimaryFlightDisplay") as MeshInstance3D
		if primary_display != null:
			primary_display.mesh = _rounded_box_mesh(Vector3(0.78, 0.27, 0.025), _materials.display_substrate)
			primary_display.material_override = _materials.display_substrate
			primary_display.position = Vector3(0.0, 0.015, 0.145)
		for repeater in cluster.find_children("StatusRepeater*", "MeshInstance3D", true, false):
			(repeater as MeshInstance3D).material_override = _materials.display_cyan_low
			(repeater as MeshInstance3D).scale = Vector3.ONE * 0.58
		for ladder in cluster.find_children("AttitudeLadder*", "MeshInstance3D", true, false):
			(ladder as MeshInstance3D).material_override = _materials.display_cyan_low
		var warning_strip := cluster.get_node_or_null("WarningStrip") as MeshInstance3D
		if warning_strip != null:
			warning_strip.material_override = _materials.display_gold_low
		for console in _cockpit_root.find_children("SideConsole*", "MeshInstance3D", true, false):
			(console as MeshInstance3D).material_override = _materials.cockpit_anti_glare
		_cockpit_readout = Label3D.new()
		_cockpit_readout.name = "FlightDataReadout"
		_cockpit_readout.position = Vector3(0.0, 0.015, 0.164)
		_cockpit_readout.font_size = 42
		_cockpit_readout.pixel_size = 0.00082
		_cockpit_readout.modulate = Color("8de8e4")
		_cockpit_readout.outline_modulate = Color("07111d")
		_cockpit_readout.outline_size = 10
		_cockpit_readout.no_depth_test = true
		_cockpit_readout.text = "SPD 000   THR +00\nOFFLINE  //  HOLD"
		_cockpit_readout.set_meta("presentation_only", true)
		_tag_modern_interpretation(_cockpit_readout)
		cluster.add_child(_cockpit_readout)
	_cockpit_practical_light = SpotLight3D.new()
	_cockpit_practical_light.name = "CockpitPracticalLight"
	_cockpit_practical_light.position = Vector3(0.0, 3.24, 0.30)
	_cockpit_practical_light.rotation.x = deg_to_rad(-20.0)
	_cockpit_practical_light.light_color = Color("d8c7a5")
	_cockpit_practical_light.light_energy = 0.04
	_cockpit_practical_light.spot_range = 3.0
	_cockpit_practical_light.spot_angle = 55.0
	_cockpit_practical_light.spot_attenuation = 1.8
	_cockpit_practical_light.shadow_enabled = false
	_tag_modern_interpretation(_cockpit_practical_light)
	_cockpit_root.add_child(_cockpit_practical_light)


func _build_torrent_modern_systems() -> void:
	var modern := Node3D.new()
	modern.name = "ModernSystems"
	modern.set_meta("evidence_status", &"modern_interpretation")
	modern.set_meta("design_origin", &"modern")
	modern.set_meta("interpretation_status", &"modern")
	modern.set_meta("historically_supported", false)
	_visual_root.add_child(modern)

	var weapons := Node3D.new()
	weapons.name = "Weapons"
	weapons.set_meta("presentation_only", true)
	weapons.set_meta("weapon_class", &"compact_twin_pulse_cannon")
	weapons.set_meta("mount_scale", &"interceptor_light")
	weapons.set_meta("historically_supported", false)
	_tag_modern_interpretation(weapons)
	modern.add_child(weapons)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		var rail := _box(weapons, side_name + "GunRail", Vector3(side * 2.82, 0.42, -2.18), Vector3(0.22, 0.22, 1.45), _materials.dark)
		var cannon := _cylinder(weapons, side_name + "PulseCannon", Vector3(side * 2.82, 0.42, -3.02), 0.13, 0.72, _materials.structure, Vector3(90.0, 0.0, 0.0))
		var shroud := _box(weapons, side_name + "CannonShroud", Vector3(side * 2.82, 0.42, -2.68), Vector3(0.38, 0.32, 0.40), _materials.dark)
		var collar := _cylinder(weapons, side_name + "MuzzleCollar", Vector3(side * 2.82, 0.42, -3.34), 0.18, 0.12, _materials.dark, Vector3(90.0, 0.0, 0.0))
		var lens := _cylinder(weapons, side_name + "MuzzleLens", Vector3(side * 2.82, 0.42, -3.405), 0.105, 0.025, _materials.cyan, Vector3(90.0, 0.0, 0.0))
		for weapon_part in [rail, cannon, shroud, collar, lens]:
			weapon_part.set_meta("presentation_only", true)
			weapon_part.set_meta("weapon_class", &"compact_pulse_cannon")
			weapon_part.set_meta("mount_scale", &"interceptor_light")
			_tag_modern_interpretation(weapon_part)

	var engines := Node3D.new()
	engines.name = "EngineInterpretations"
	engines.set_meta("presentation_only", true)
	modern.add_child(engines)
	for side in [-1.0, 1.0]:
		var engine_assembly := _build_torrent_engine(engines, side)
		var plume := engine_assembly.get_node("EnginePlume") as MeshInstance3D
		_engine_glows.append(plume)
		var engine_light := OmniLight3D.new()
		engine_light.name = "EngineLight"
		engine_light.position = Vector3(0.0, 0.0, 1.68)
		engine_light.light_color = ENGINE_BLUE
		engine_light.light_energy = 0.0
		engine_light.omni_range = 6.0
		engine_light.shadow_enabled = false
		engine_assembly.add_child(engine_light)
		_engine_lights.append(engine_light)
		_sphere(modern, "NavigationLight", Vector3(side * 3.48, 1.08, 2.20), 0.10, _materials.nav_red if side < 0.0 else _materials.nav_green)

	_build_torrent_service_detail(modern)
	_build_torrent_landing_hardware(modern)
	for step_index in 3:
		var step_position := Vector3(-2.15 - step_index * 0.38, -0.08 + step_index * 0.28, 0.4)
		_box(modern, "BoardingStep", step_position, Vector3(0.72, 0.12, 0.75), _materials.gold)
		_cylinder_between(modern, "BoardingStepBrace%02d" % step_index, step_position + Vector3(0.25, 0.0, 0.24), step_position + Vector3(0.25, 0.3, 0.47), 0.035, _materials.dark)


## Protected construction seam for evidence-bounded fleet variants. A subclass
## may call this once to establish the inherited runtime/camera/damage state,
## then replace only the visual hierarchy and collision shapes while retaining
## the public boarding, flight, landing, and reuse contracts.
func rebuild_variant_presentation(builder: Callable) -> bool:
	_build_ship()
	if not builder.is_valid():
		return false
	var result: Variant = builder.call(self)
	if result is Node3D:
		return replace_variant_visual_root(result as Node3D)
	return bool(result)


## Makes a variant's replacement hierarchy authoritative for common banking,
## destruction visibility, and reuse. The cockpit/canopy references remain valid
## when a builder reparents those inherited functional nodes into `new_root`.
func replace_variant_visual_root(new_root: Node3D) -> bool:
	if new_root == null or not is_instance_valid(new_root):
		return false
	if new_root.get_parent() == null:
		add_child(new_root)
	elif not is_ancestor_of(new_root):
		return false
	_visual_root = new_root
	# Inherited Torrent plume references may belong to a queued replacement root.
	# A variant animates its own engines; the base must never dereference freed nodes.
	_engine_glows.clear()
	_engine_core_glows.clear()
	_engine_lights.clear()
	# Torrent-only quality presentation is intentionally not part of a fleet
	# variant. The preserved common cockpit remains functional, but the base must
	# not keep updating freed/reparented source-specific readout or light objects.
	if not _uses_torrent_reconstruction_presentation():
		_cockpit_readout = null
		_cockpit_practical_light = null
		_torrent_unknown_function_panel = null
	_visual_bank = new_root.rotation.z
	return true


## Protected accessors avoid forcing fleet variants to depend on private member
## names while the common flight controller remains one tested implementation.
func get_variant_visual_root() -> Node3D:
	return _visual_root if _visual_root != null and is_instance_valid(_visual_root) else null


func get_variant_materials() -> Dictionary:
	return _materials


## Component-local render census and a deterministic audit of the one bounded
## batching seam. It deliberately counts both imported close art and retained
## fallback art because both remain allocated by a live Torrent.
func get_torrent_render_allocation_report() -> Dictionary:
	var visual := get_variant_visual_root()
	var modern := (
		visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D
		if visual != null else null
	)
	var visual_census := _collect_torrent_render_census(visual)
	var modern_census := _collect_torrent_render_census(modern)
	var exact_counts := (
		int(visual_census.get("descendant_nodes", -1)) == TORRENT_RENDER_DESCENDANT_COUNT
		and int(visual_census.get("mesh_instances", -1)) == TORRENT_RENDER_MESH_INSTANCE_COUNT
		and int(visual_census.get("multimesh_batches", -1)) == TORRENT_RENDER_MULTIMESH_BATCH_COUNT
		and int(visual_census.get("drawn_copies", -1)) == TORRENT_RENDER_DRAWN_COPY_COUNT
		and int(visual_census.get("geometry_submissions", -1)) == TORRENT_RENDER_GEOMETRY_SUBMISSION_COUNT
		and int(visual_census.get("unique_mesh_resources", -1)) == TORRENT_RENDER_UNIQUE_MESH_RESOURCE_COUNT
		and int(visual_census.get("unique_material_resources", -1)) == TORRENT_RENDER_UNIQUE_MATERIAL_RESOURCE_COUNT
		and int(visual_census.get("multimesh_resources", -1)) == TORRENT_RENDER_MULTIMESH_BATCH_COUNT
		and int(modern_census.get("descendant_nodes", -1)) == TORRENT_MODERN_DESCENDANT_COUNT
		and int(modern_census.get("mesh_instances", -1)) == TORRENT_MODERN_MESH_INSTANCE_COUNT
		and int(modern_census.get("multimesh_batches", -1)) == TORRENT_RENDER_MULTIMESH_BATCH_COUNT
		and int(modern_census.get("drawn_copies", -1)) == TORRENT_MODERN_DRAWN_COPY_COUNT
		and int(modern_census.get("geometry_submissions", -1)) == TORRENT_MODERN_GEOMETRY_SUBMISSION_COUNT
		and int(modern_census.get("unique_mesh_resources", -1)) == TORRENT_MODERN_UNIQUE_MESH_RESOURCE_COUNT
		and int(modern_census.get("unique_material_resources", -1)) == TORRENT_MODERN_UNIQUE_MATERIAL_RESOURCE_COUNT
	)

	var expected_transforms := _torrent_vent_louver_transforms()
	var expected_buffer := _torrent_encode_multimesh_transforms(expected_transforms)
	var expected_names := PackedStringArray([
		"VentLouver00", "VentLouver01", "VentLouver02",
		"VentLouver03", "VentLouver04", "VentLouver05",
	])
	var batch_contract_matches := _torrent_vent_louver_batches.size() == 2
	var buffer_matches := batch_contract_matches
	var bounds_match := batch_contract_matches
	var mesh_material_matches := batch_contract_matches
	var renderer_buffer_floats := 0
	for side_name: String in ["Port", "Starboard"]:
		var batch := (
			modern.get_node_or_null(side_name + "DorsalVentBank/VentLouvers")
			as MultiMeshInstance3D if modern != null else null
		)
		if batch == null or batch.multimesh == null:
			batch_contract_matches = false
			buffer_matches = false
			bounds_match = false
			mesh_material_matches = false
			continue
		var multi := batch.multimesh
		renderer_buffer_floats += multi.buffer.size()
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		batch_contract_matches = batch_contract_matches and (
			multi.transform_format == MultiMesh.TRANSFORM_3D
			and not multi.use_colors
			and not multi.use_custom_data
			and multi.instance_count == TORRENT_VENT_LOUVERS_PER_BANK
			and multi.visible_instance_count == TORRENT_VENT_LOUVERS_PER_BANK
			and batch.transform.is_equal_approx(Transform3D.IDENTITY)
			and batch.visible
			and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and batch.layers == 1
			and batch.get_child_count() == 0
			and batch.get_script() == null
			and batch.get_groups().is_empty()
			and bool(batch.get_meta("visual_detail_only", false))
			and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_names
			and _torrent_transform_arrays_match(authored_transforms, expected_transforms)
		)
		buffer_matches = buffer_matches and multi.buffer == expected_buffer
		bounds_match = bounds_match and (
			_torrent_vent_louver_mesh != null
			and multi.custom_aabb.is_equal_approx(_torrent_transformed_mesh_bounds(
				_torrent_vent_louver_mesh.get_aabb(), expected_transforms
			))
		)
		mesh_material_matches = mesh_material_matches and (
			_torrent_vent_louver_mesh != null
			and multi.mesh == _torrent_vent_louver_mesh
			and batch.material_override == null
			and _torrent_vent_louver_mesh.get_surface_count() == 1
			and _torrent_vent_louver_mesh.surface_get_material(0) == _materials.get("dark")
		)

	var retired_louver_nodes := 0
	if modern != null:
		for raw_node in modern.find_children("VentLouver*", "MeshInstance3D", true, false):
			retired_louver_nodes += 1
	batch_contract_matches = batch_contract_matches and retired_louver_nodes == 0
	var capture_jaw_contract_matches := _torrent_capture_jaw_mesh != null
	var docking_receiver := (
		modern.get_node_or_null("VentralDockingReceiver") as Node3D
		if modern != null else null
	)
	var capture_jaws := (
		docking_receiver.find_children("CaptureJaw*", "MeshInstance3D", false, false)
		if docking_receiver != null else []
	)
	capture_jaw_contract_matches = capture_jaw_contract_matches and (
		capture_jaws.size() == TORRENT_CAPTURE_JAW_COPY_COUNT
		and _torrent_capture_jaw_mesh.get_surface_count() == 1
		and _torrent_capture_jaw_mesh.get_aabb().size.is_equal_approx(Vector3(0.18, 0.12, 0.3))
		and _torrent_capture_jaw_mesh.surface_get_material(0) == _materials.get("gold")
	)
	for raw_jaw in capture_jaws:
		var jaw := raw_jaw as MeshInstance3D
		capture_jaw_contract_matches = capture_jaw_contract_matches and (
			jaw != null
			and jaw.mesh == _torrent_capture_jaw_mesh
			and jaw.material_override == null
			and jaw.get_parent() == docking_receiver
		)
	var rcs_port_contract_matches := _torrent_rcs_thruster_port_mesh != null
	var expected_rcs_names := PackedStringArray(["ThrusterPort00", "ThrusterPort01"])
	for side_name: String in ["Port", "Starboard"]:
		var side := -1.0 if side_name == "Port" else 1.0
		var expected_rcs_transforms := _torrent_rcs_thruster_port_transforms(side)
		var expected_rcs_buffer := _torrent_encode_multimesh_transforms(expected_rcs_transforms)
		for station_name: String in ["Forward", "Aft"]:
			var cluster := modern.get_node_or_null(
				side_name + station_name + "RCSCluster"
			) as Node3D if modern != null else null
			var batch := (
				cluster.get_node_or_null("ThrusterPorts") as MultiMeshInstance3D
				if cluster != null else null
			)
			if batch == null or batch.multimesh == null:
				rcs_port_contract_matches = false
				continue
			var multi := batch.multimesh
			var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
			rcs_port_contract_matches = rcs_port_contract_matches and (
				multi.transform_format == MultiMesh.TRANSFORM_3D
				and not multi.use_colors
				and not multi.use_custom_data
				and multi.instance_count == TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER
				and multi.visible_instance_count == TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER
				and multi.buffer == expected_rcs_buffer
				and multi.custom_aabb.is_equal_approx(_torrent_transformed_mesh_bounds(
					_torrent_rcs_thruster_port_mesh.get_aabb(), expected_rcs_transforms
				))
				and multi.mesh == _torrent_rcs_thruster_port_mesh
				and _torrent_rcs_thruster_port_mesh.get_surface_count() == 1
				and _torrent_rcs_thruster_port_mesh.surface_get_material(0) == _materials.get("thermal")
				and batch.transform.is_equal_approx(Transform3D.IDENTITY)
				and batch.material_override == null
				and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				and batch.layers == 1
				and batch.get_child_count() == 0
				and batch.get_script() == null
				and batch.get_groups().is_empty()
				and bool(batch.get_meta("visual_detail_only", false))
				and batch.get_meta("authored_visual_names", PackedStringArray()) == expected_rcs_names
				and _torrent_transform_arrays_match(authored_transforms, expected_rcs_transforms)
			)
	var retired_rcs_port_nodes := (
		modern.find_children("ThrusterPort*", "MeshInstance3D", true, false).size()
		if modern != null else -1
	)
	rcs_port_contract_matches = rcs_port_contract_matches and (
		_torrent_rcs_thruster_port_batches.size() == 4 and retired_rcs_port_nodes == 0
	)
	var errors := PackedStringArray()
	if not exact_counts:
		errors.append("Torrent render allocations drifted from the frozen component-local roster")
	if not batch_contract_matches:
		errors.append("Torrent dorsal vent-louver batch contract drifted")
	if not buffer_matches:
		errors.append("Torrent dorsal vent-louver renderer buffer drifted from its authored transforms")
	if not bounds_match:
		errors.append("Torrent dorsal vent-louver culling bounds drifted from its authored copies")
	if not mesh_material_matches:
		errors.append("Torrent dorsal vent-louver mesh or material identity drifted")
	if not capture_jaw_contract_matches:
		errors.append("Torrent capture-jaw mesh-sharing contract drifted")
	if not rcs_port_contract_matches:
		errors.append("Torrent RCS thruster-port batch contract drifted")
	return {
		"schema_version": 1,
		"valid": errors.is_empty(),
		"errors": errors,
		"component": visual_census.duplicate(true),
		"modern_fallback": modern_census.duplicate(true),
		"vent_louver_batches": _torrent_vent_louver_batches.size(),
		"vent_louver_copies": TORRENT_VENT_LOUVER_COPY_COUNT,
		"vent_louver_shared_mesh_resources": 1 if _torrent_vent_louver_mesh != null else 0,
		"capture_jaw_copies": TORRENT_CAPTURE_JAW_COPY_COUNT,
		"capture_jaw_shared_mesh_resources": 1 if _torrent_capture_jaw_mesh != null else 0,
		"rcs_thruster_port_batches": _torrent_rcs_thruster_port_batches.size(),
		"rcs_thruster_port_copies": TORRENT_RCS_THRUSTER_PORT_COPY_COUNT,
		"rcs_thruster_port_shared_mesh_resources": 1 if _torrent_rcs_thruster_port_mesh != null else 0,
		"renderer_buffer_floats": renderer_buffer_floats,
		"renderer_buffer_matches_authored": buffer_matches,
		"bounds_match_authored": bounds_match,
		"mesh_material_matches_authored": mesh_material_matches,
		"batch_contract_matches": batch_contract_matches,
		"capture_jaw_contract_matches": capture_jaw_contract_matches,
		"rcs_thruster_port_contract_matches": rcs_port_contract_matches,
		"exact_counts": exact_counts,
		"authored_bank_transforms": expected_transforms.duplicate(),
		"old_family": {
			"nodes": 12, "mesh_instances": 12, "multimesh_batches": 0,
			"drawn_copies": 12, "geometry_submissions": 12,
			"unique_mesh_resources": 12,
		},
		"new_family": {
			"nodes": 2, "mesh_instances": 0, "multimesh_batches": 2,
			"drawn_copies": 12, "geometry_submissions": 2,
			"unique_mesh_resources": 1,
		},
	}


func _collect_torrent_render_census(search_root: Node) -> Dictionary:
	if search_root == null:
		return {}
	var mesh_nodes := search_root.find_children("*", "MeshInstance3D", true, false)
	var batch_nodes := search_root.find_children("*", "MultiMeshInstance3D", true, false)
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var multimesh_resource_ids := {}
	var drawn_copies := 0
	var submissions := 0
	for raw_node in mesh_nodes:
		var instance := raw_node as MeshInstance3D
		if instance.mesh == null:
			continue
		drawn_copies += 1
		submissions += instance.mesh.get_surface_count()
		mesh_resource_ids[instance.mesh.get_instance_id()] = true
		_collect_torrent_active_material_ids(
			instance.mesh, instance.material_override, material_resource_ids
		)
	for raw_node in batch_nodes:
		var batch := raw_node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var visible_copies := batch.multimesh.visible_instance_count
		if visible_copies < 0:
			visible_copies = batch.multimesh.instance_count
		drawn_copies += visible_copies
		submissions += batch.multimesh.mesh.get_surface_count()
		mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
		multimesh_resource_ids[batch.multimesh.get_instance_id()] = true
		_collect_torrent_active_material_ids(
			batch.multimesh.mesh, batch.material_override, material_resource_ids
		)
	return {
		"descendant_nodes": search_root.find_children("*", "Node", true, false).size(),
		"mesh_instances": mesh_nodes.size(),
		"multimesh_batches": batch_nodes.size(),
		"multimesh_resources": multimesh_resource_ids.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
		"unique_mesh_resources": mesh_resource_ids.size(),
		"unique_material_resources": material_resource_ids.size(),
	}


func _collect_torrent_active_material_ids(
		mesh: Mesh,
		override: Material,
		material_ids: Dictionary
	) -> void:
	if override != null:
		material_ids[override.get_instance_id()] = true
		return
	for surface_index in mesh.get_surface_count():
		var surface_material := mesh.surface_get_material(surface_index)
		if surface_material != null:
			material_ids[surface_material.get_instance_id()] = true


func _torrent_transform_arrays_match(left: Array, right: Array[Transform3D]) -> bool:
	if left.size() != right.size():
		return false
	for index in right.size():
		if not (left[index] as Transform3D).is_equal_approx(right[index]):
			return false
	return true


## Evidence-bounded audit for the B5-observed reconstruction. The identity lock
## is high confidence; exact dimensions, function, finish, and 2009 continuity
## are intentionally kept outside the authenticated claim.
func get_torrent_reconstruction_audit_report() -> Dictionary:
	var visual: Node3D = (
		_visual_root
		if _visual_root != null and is_instance_valid(_visual_root)
		else null
	)
	var authored_macroform := (
		visual.get_node_or_null("LegacyFarPresentation/TorrentAuthoredMacroform") as Node3D
		if visual != null else null
	)
	var authored_audit: Dictionary = {}
	if (
		authored_macroform != null
		and authored_macroform.has_method("get_torrent_authored_asset_audit_report")
	):
		authored_audit = (
			authored_macroform.call("get_torrent_authored_asset_audit_report") as Dictionary
		)
	var authored_lod0_path := (
		"TorrentVisual/LegacyFarPresentation/TorrentAuthoredMacroform/"
		+ "Dated2011Form/MacroformLOD0"
	)
	var node_contract := {
		"visual_root": NodePath("TorrentVisual"),
		"authored_macroform": NodePath("TorrentVisual/LegacyFarPresentation/TorrentAuthoredMacroform"),
		"dated_form": NodePath("TorrentVisual/LegacyFarPresentation/TorrentAuthoredMacroform/Dated2011Form"),
		"pointed_nose": NodePath(authored_lod0_path + "/PointedNose"),
		"raised_spine": NodePath(authored_lod0_path + "/RaisedSpine"),
		"blocky_aft": NodePath(authored_lod0_path + "/BlockyAftBody"),
		"port_lower_side_plane": NodePath(authored_lod0_path + "/PortLowerSidePlane"),
		"port_upper_side_plane": NodePath(authored_lod0_path + "/PortUpperSidePlane"),
		"starboard_lower_side_plane": NodePath(authored_lod0_path + "/StarboardLowerSidePlane"),
		"starboard_upper_side_plane": NodePath(authored_lod0_path + "/StarboardUpperSidePlane"),
		"port_aft_housing": NodePath(authored_lod0_path + "/PortAftCircularHousing"),
		"starboard_aft_housing": NodePath(authored_lod0_path + "/StarboardAftCircularHousing"),
		"port_aft_rail": NodePath(authored_lod0_path + "/PortAftRail"),
		"starboard_aft_rail": NodePath(authored_lod0_path + "/StarboardAftRail"),
		"aft_crossbar": NodePath(authored_lod0_path + "/AftCrossbar"),
		"pilot_area": NodePath("TorrentVisual/CockpitInterior"),
		"pilot_seat": NodePath("TorrentVisual/TorrentHeroPresentation/TorrentHeroImport/TorrentHeroArt/CockpitArt/CrimsonSeatPan"),
		"forward_panel": NodePath("TorrentVisual/TorrentHeroPresentation/TorrentHeroImport/TorrentHeroArt/LOD0/AmberUnknownFunctionPanel"),
	}
	var errors := PackedStringArray()
	if visual == null or visual.name != &"TorrentVisual":
		errors.append("dedicated Torrent visual root is missing")
	if authored_macroform == null:
		errors.append("checked-in authored Torrent macroform is missing")
	elif authored_audit.is_empty():
		errors.append("authored Torrent macroform audit is unavailable")
	elif not bool(authored_audit.get("valid", false)):
		errors.append("authored Torrent macroform fails its own audit")
	for key: String in node_contract:
		if get_node_or_null(node_contract[key]) == null:
			errors.append("reconstruction node contract is missing %s" % key)
	var modern_systems := (
		visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D
		if visual != null else null
	)
	var engine_count := modern_systems.find_children("*EngineAssembly", "Node3D", true, false).size() if modern_systems != null else 0
	var gear_count := modern_systems.find_children("*GearAssembly", "Node3D", true, false).size() if modern_systems != null else 0
	var rcs_count := modern_systems.find_children("*RCSCluster", "Node3D", true, false).size() if modern_systems != null else 0
	var service_panel_count := modern_systems.find_children("*ServicePanel", "MeshInstance3D", true, false).size() if modern_systems != null else 0
	if engine_count != 2:
		errors.append("two modern engine interpretations are required")
	if gear_count != 3:
		errors.append("tricycle modern landing hardware is incomplete")
	if rcs_count != 4:
		errors.append("four modern RCS presentation clusters are required")
	var render_allocations := get_torrent_render_allocation_report()
	for render_error in render_allocations.get("errors", PackedStringArray()):
		errors.append(str(render_error))
	var canopy_seal_count := (
		_canopy_pivot.find_children("*PressureSeal", "MeshInstance3D", true, false).size()
		if _canopy_pivot != null and is_instance_valid(_canopy_pivot)
		else 0
	)
	var restraint_count := (
		_cockpit_root.find_children("*Belt*", "MeshInstance3D", true, false).size()
		if _cockpit_root != null and is_instance_valid(_cockpit_root)
		else 0
	)
	if canopy_seal_count < 4 or restraint_count < 4:
		errors.append("modern cockpit safety detail is incomplete")
	var mapped_hull_materials := 0
	for material in [_materials.get("ivory") as StandardMaterial3D, _materials.get("light") as StandardMaterial3D]:
		if material != null and material.normal_enabled and material.normal_texture != null and material.roughness_texture != null:
			mapped_hull_materials += 1
	if mapped_hull_materials != 2:
		errors.append("mapped pale hull material families are incomplete")
	if get_node_or_null("HullCollision") == null or get_node_or_null("WingCollision") == null:
		errors.append("canonical collision envelope is missing")
	return {
		"schema_version": TORRENT_ART_SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"geometry_status": TORRENT_GEOMETRY_STATUS,
		"identity_lock": TORRENT_IDENTITY_LOCK,
		"historical_revision": "unverified",
		"source_upload_date": "2011-06-29",
		"recording_date_status": "unknown",
		"game_build_revision_status": "unknown",
		"reconstruction_status": TORRENT_RECONSTRUCTION_STATUS,
		"2009_continuity": TORRENT_2009_CONTINUITY,
		"authenticated_geometry": false,
		"source_references": PackedStringArray([
			"B5@00:10.200-00:41.000 decisive uncut Torrent chain in footage uploaded 2011-06-29",
			"B6@05:31.167-05:33.333 independent upload-era corroboration",
		]),
		"safe_historical_features": PackedStringArray([
			"pointed faceted nose", "raised central spine", "blocky aft body",
			"paired stepped side planes", "paired circular aft housings of unknown function",
			"paired upright aft rails", "central single pilot area",
			"visible red pilot seat", "pale yellow translucent forward panel",
		]),
		"modern_interpretations": PackedStringArray([
			"engine machinery inside source-observed housings", "blue exhaust and engine light",
			"recessed pulse weapon hardware", "tricycle landing gear and docking receiver",
			"neutral pressure canopy and hinge", "detailed cockpit controls and restraints",
			"inferred aft crossbar for the U-like rear read",
			"arcade flight handling and damage systems", "RCS, vents, service panels and PBR finish",
		]),
		"authored_bounds_m": {
			"length": 8.40,
			"width": 7.20,
			"body_height": 2.86,
			"total_height": 4.54,
		},
		"full_visual_bounds_m": {
			"position": Vector3(-3.60, -0.755, -4.80),
			"size": Vector3(7.20, 4.905, 8.535),
		},
		"width_to_length_ratio": 7.20 / 8.40,
		"pilot_area_count": 1,
		"node_contract": node_contract,
		"visual_root": visual,
		"engine_assembly_count": engine_count,
		"landing_gear_assembly_count": gear_count,
		"rcs_cluster_count": rcs_count,
		"service_panel_count": service_panel_count,
		"canopy_seal_count": canopy_seal_count,
		"restraint_detail_count": restraint_count,
		"mapped_hull_material_count": mapped_hull_materials,
		"render_allocations": render_allocations.duplicate(true),
		"collision_shapes": PackedStringArray([
			"HullCollision", "WingCollision", "UpperSilhouetteCollision",
			"PortAftPropulsionCollision", "StarboardAftPropulsionCollision",
			"LowerGearCollision", "NoseGearCollision",
		]),
		"authored_mesh": authored_audit.duplicate(true),
		"content_note": "Dated-2011 identity lock and partial source-aligned reconstruction; exact geometry and 2009 continuity remain unproved.",
	}


## Compatibility alias retained for existing art and capture tooling.
func get_torrent_art_audit_report() -> Dictionary:
	var reconstruction := get_torrent_reconstruction_audit_report()
	var live_presentation: TorrentHeroPresentation = (
		_torrent_hero_presentation
		if (
			_torrent_hero_presentation != null
			and is_instance_valid(_torrent_hero_presentation)
		)
		else null
	)
	var hero: Dictionary = (
		live_presentation.get_asset_audit_report()
		if live_presentation != null else {}
	)
	var errors := PackedStringArray()
	if not bool(reconstruction.get("valid", false)):
		errors.append("B5-observed far/fallback macroform fails its audit")
	if hero.is_empty():
		errors.append("Blender-authored close presentation is missing")
	elif not bool(hero.get("valid", false)):
		errors.append("Blender-authored close presentation fails its audit")
	if (
		_legacy_torrent_presentation == null
		or not is_instance_valid(_legacy_torrent_presentation)
	):
		errors.append("legacy far/fallback presentation gate is missing")
	var collision_errors := _get_torrent_collision_authority_errors()
	for collision_error in collision_errors:
		errors.append(collision_error)
	var functional_errors := _get_torrent_functional_authority_errors()
	for functional_error in functional_errors:
		errors.append(functional_error)
	var lifecycle_errors := _get_torrent_lifecycle_visual_errors()
	for lifecycle_error in lifecycle_errors:
		errors.append(lifecycle_error)
	return {
		"schema_version": 4,
		"valid": errors.is_empty(),
		"errors": errors,
		"identity_lock": TORRENT_IDENTITY_LOCK,
		"historical_revision": "unverified",
		"source_upload_date": "2011-06-29",
		"recording_date_status": "unknown",
		"game_build_revision_status": "unknown",
		"geometry_status": TORRENT_GEOMETRY_STATUS,
		"reconstruction_status": TORRENT_RECONSTRUCTION_STATUS,
		"2009_continuity": TORRENT_2009_CONTINUITY,
		"authenticated_geometry": false,
		"close_presentation": hero.duplicate(true),
		"far_fallback_reconstruction": reconstruction.duplicate(true),
		"close_art_active": live_presentation != null,
		"legacy_far_visible": (
			_legacy_torrent_presentation.visible
			if (
				_legacy_torrent_presentation != null
				and is_instance_valid(_legacy_torrent_presentation)
			)
			else false
		),
		"gameplay_authority_unchanged": collision_errors.is_empty() and functional_errors.is_empty(),
		"collision_authority_unchanged": collision_errors.is_empty(),
		"functional_authority_unchanged": functional_errors.is_empty(),
		"presentation_lifecycle_valid": lifecycle_errors.is_empty(),
		"content_note": "Original Blender close art over an independently audited B5-observed far/fallback macroform; neither is authenticated exact historical geometry, and B5's recording/build dates remain unknown.",
	}


func _build_torrent_service_detail(parent: Node3D) -> void:
	# Four compact attitude-control clusters are readable hardware, not active
	# gameplay thrusters. Metadata keeps that presentation boundary explicit.
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for longitudinal_index in 2:
			var station_name := "Forward" if longitudinal_index == 0 else "Aft"
			var cluster := Node3D.new()
			cluster.name = side_name + station_name + "RCSCluster"
			cluster.position = Vector3(side * (2.32 if longitudinal_index == 0 else 2.68), 1.34, -3.48 if longitudinal_index == 0 else 3.08)
			cluster.set_meta("presentation_only", true)
			cluster.set_meta("system", &"attitude_control")
			parent.add_child(cluster)
			_box(cluster, "RCSServicePanel", Vector3.ZERO, Vector3(0.54, 0.28, 0.46), _materials.panel, Vector3(0.0, 0.0, side * deg_to_rad(-9.0)))
			_build_torrent_rcs_thruster_port_batch(cluster, side)

	# Recessed access covers, fasteners, and louvred heat-exchanger banks break
	# large surfaces without presenting them as unsupported historical features.
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(parent, side_name + "FuselageServicePanel", Vector3(side * 1.62, 1.79, -2.55), Vector3(0.72, 0.055, 1.08), _materials.panel, Vector3(0.0, 0.0, side * deg_to_rad(-5.0)))
		var vent_bank := Node3D.new()
		vent_bank.name = side_name + "DorsalVentBank"
		vent_bank.position = Vector3(side * 1.17, 1.84, 2.72)
		parent.add_child(vent_bank)
		_box(vent_bank, "VentRecess", Vector3.ZERO, Vector3(0.68, 0.055, 1.12), _materials.thermal)
		_build_torrent_vent_louver_batch(vent_bank)

	var docking_receiver := Node3D.new()
	docking_receiver.name = "VentralDockingReceiver"
	docking_receiver.position = Vector3(0.0, 0.04, 0.35)
	docking_receiver.set_meta("articulated_visual_only", true)
	parent.add_child(docking_receiver)
	_torus(docking_receiver, "DockingCaptureRing", Vector3.ZERO, 0.38, 0.56, _materials.mid)
	_cylinder(docking_receiver, "DockingHardpoint", Vector3(0.0, -0.035, 0.0), 0.28, 0.08, _materials.dark)
	if _torrent_capture_jaw_mesh == null:
		_torrent_capture_jaw_mesh = _rounded_box_mesh(
			Vector3(0.18, 0.12, 0.3), _materials.gold
		)
	for jaw_index in 4:
		var jaw_angle := TAU * float(jaw_index) / 4.0
		var jaw := MeshInstance3D.new()
		jaw.name = "CaptureJaw%02d" % jaw_index
		jaw.position = Vector3(cos(jaw_angle) * 0.46, -0.08, sin(jaw_angle) * 0.46)
		jaw.rotation = Vector3(0.0, -jaw_angle, 0.0)
		jaw.mesh = _torrent_capture_jaw_mesh
		docking_receiver.add_child(jaw)


## The twelve louvres are repeated childless surface dressing. Their two bank
## roots remain named semantic nodes; only the identical visual leaves share a
## mesh and renderer allocation. Keeping one batch per bank preserves the old
## parent-space transforms and bank-local culling while retaining every copy.
func _build_torrent_vent_louver_batch(vent_bank: Node3D) -> void:
	if _torrent_vent_louver_mesh == null:
		_torrent_vent_louver_mesh = _rounded_box_mesh(
			Vector3(0.54, 0.045, 0.065), _materials.dark
		)
	var transforms := _torrent_vent_louver_transforms()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _torrent_vent_louver_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _torrent_encode_multimesh_transforms(transforms)
	multi.custom_aabb = _torrent_transformed_mesh_bounds(
		_torrent_vent_louver_mesh.get_aabb(), transforms
	)
	var batch := MultiMeshInstance3D.new()
	batch.name = "VentLouvers"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_visual_names", PackedStringArray([
		"VentLouver00", "VentLouver01", "VentLouver02",
		"VentLouver03", "VentLouver04", "VentLouver05",
	]))
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	vent_bank.add_child(batch)
	_torrent_vent_louver_batches.append(batch)


## Each RCS cluster remains a named semantic root. Its two repeated visual-only
## ports are rendered together in the same local space, retaining their exact
## authored transforms, material and visibility without a gameplay authority.
func _build_torrent_rcs_thruster_port_batch(cluster: Node3D, side: float) -> void:
	if _torrent_rcs_thruster_port_mesh == null:
		_torrent_rcs_thruster_port_mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
			0.065, 0.065, 0.09, 32, _chamfered_cylinder_cache,
			ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.thermal
		)
	var transforms := _torrent_rcs_thruster_port_transforms(side)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _torrent_rcs_thruster_port_mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = transforms.size()
	multi.buffer = _torrent_encode_multimesh_transforms(transforms)
	multi.custom_aabb = _torrent_transformed_mesh_bounds(
		_torrent_rcs_thruster_port_mesh.get_aabb(), transforms
	)
	var batch := MultiMeshInstance3D.new()
	batch.name = "ThrusterPorts"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_visual_names", PackedStringArray(["ThrusterPort00", "ThrusterPort01"]))
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	cluster.add_child(batch)
	_torrent_rcs_thruster_port_batches.append(batch)


func _torrent_vent_louver_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var louver_basis := Basis.from_euler(Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	for louver_index in TORRENT_VENT_LOUVERS_PER_BANK:
		transforms.append(Transform3D(
			louver_basis,
			Vector3(0.0, 0.055, -0.43 + float(louver_index) * 0.17)
		))
	return transforms


func _torrent_rcs_thruster_port_transforms(side: float) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var port_basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(90.0)))
	for port_index in TORRENT_RCS_THRUSTER_PORTS_PER_CLUSTER:
		transforms.append(Transform3D(
			port_basis,
			Vector3(side * 0.28, 0.07 - float(port_index) * 0.15, -0.1 + float(port_index) * 0.2)
		))
	return transforms


func _torrent_encode_multimesh_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _torrent_transformed_mesh_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var transformed := (value * mesh_bounds).abs()
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result


func _build_torrent_engine(parent: Node3D, side: float) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = ("Port" if side < 0.0 else "Starboard") + "EngineAssembly"
	assembly.position = Vector3(side * 2.52, 1.02, 1.925)
	assembly.set_meta("recessed_engine_interior", true)
	assembly.set_meta("exposed_emissive_disc", false)
	assembly.set_meta("interpretation_status", &"modern")
	assembly.set_meta("historically_supported", false)
	parent.add_child(assembly)
	# Modern machinery is recessed inside the B5-observed 0.80 m shell. The
	# source-safe outer housing remains a sibling in Dated2011Form.
	_torus(assembly, "ForwardMountCollar", Vector3(0.0, 0.0, -1.36), 0.25, 0.36, _materials.mid, Vector3(90.0, 0.0, 0.0))
	_torus(assembly, "EngineCollar", Vector3(0.0, 0.0, 1.54), 0.29, 0.38, _materials.mid, Vector3(90.0, 0.0, 0.0))
	_frustum(assembly, "EngineNozzle", Vector3(0.0, 0.0, 1.64), 0.20, 0.29, 0.28, _materials.thermal, Vector3(90.0, 0.0, 0.0), false, false)
	_torus(assembly, "NozzleThermalLip", Vector3(0.0, 0.0, 1.76), 0.21, 0.31, _materials.thermal, Vector3(90.0, 0.0, 0.0))
	_torus(assembly, "NozzleInnerCollar", Vector3(0.0, 0.0, 1.49), 0.15, 0.23, _materials.dark, Vector3(90.0, 0.0, 0.0))
	_cylinder(assembly, "EngineCore", Vector3(0.0, 0.0, 1.55), 0.17, 0.07, _materials.thermal, Vector3(90.0, 0.0, 0.0))
	for vane_index in 8:
		var vane_angle := TAU * float(vane_index) / 8.0
		_box(
			assembly,
			"TurbineStatorVane%02d" % vane_index,
			Vector3(cos(vane_angle) * 0.11, sin(vane_angle) * 0.11, 1.59),
			Vector3(0.22, 0.025, 0.045),
			_materials.mid,
			Vector3(0.0, 0.0, vane_angle)
		)
	_sphere(assembly, "RecessedIgniter", Vector3(0.0, 0.0, 1.59), 0.055, _materials.engine)
	var plume := _frustum(assembly, "EnginePlume", Vector3(0.0, 0.0, 2.13), 0.10, 0.22, 0.88, _materials.engine, Vector3(90.0, 0.0, 0.0))
	plume.visible = false
	return assembly


func _build_torrent_landing_hardware(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var gear := Node3D.new()
		gear.name = ("Port" if side < 0.0 else "Starboard") + "MainGearAssembly"
		gear.set_meta("articulated_visual_only", true)
		gear.set_meta("parked_configuration", true)
		parent.add_child(gear)
		var upper := Vector3(side * 1.55, 0.27, 1.06)
		var knee := Vector3(side * 1.76, -0.22, 1.2)
		var axle := Vector3(side * 1.92, -0.6, 1.25)
		_sphere(gear, "GearTrunnion", upper, 0.18, _materials.mid)
		_cylinder_between(gear, "LandingStrut", upper, axle, 0.095, _materials.dark)
		_cylinder_between(gear, "ShockPiston", knee, axle, 0.062, _materials.hydraulic)
		_cylinder_between(gear, "DragBrace", Vector3(side * 2.38, 0.18, 1.78), knee, 0.055, _materials.mid)
		_sphere(gear, "KneeJoint", knee, 0.115, _materials.gold)
		_box(gear, "LandingFoot", Vector3(side * 1.92, -0.68, 1.25), Vector3(1.05, 0.15, 1.65), _materials.structure)
		_box(gear, "DockingClampJawForward", Vector3(side * 1.92, -0.59, 0.66), Vector3(0.54, 0.17, 0.16), _materials.gold)
		_box(gear, "DockingClampJawAft", Vector3(side * 1.92, -0.59, 1.84), Vector3(0.54, 0.17, 0.16), _materials.gold)

	var nose_gear := Node3D.new()
	nose_gear.name = "NoseGearAssembly"
	nose_gear.set_meta("articulated_visual_only", true)
	nose_gear.set_meta("parked_configuration", true)
	parent.add_child(nose_gear)
	var nose_upper := Vector3(0.0, 0.25, -2.88)
	var nose_axle := Vector3(0.0, -0.51, -3.04)
	_sphere(nose_gear, "NoseGearTrunnion", nose_upper, 0.15, _materials.mid)
	_cylinder_between(nose_gear, "NoseStrut", nose_upper, nose_axle, 0.085, _materials.dark)
	_cylinder_between(nose_gear, "NoseShockPiston", Vector3(0.0, -0.05, -2.98), nose_axle, 0.052, _materials.hydraulic)
	_cylinder_between(nose_gear, "PortNoseBrace", Vector3(-0.44, 0.12, -2.55), nose_axle, 0.045, _materials.mid)
	_cylinder_between(nose_gear, "StarboardNoseBrace", Vector3(0.44, 0.12, -2.55), nose_axle, 0.045, _materials.mid)
	_box(nose_gear, "NoseFoot", Vector3(0.0, -0.58, -3.05), Vector3(0.8, 0.15, 1.15), _materials.structure)
	_box(nose_gear, "NoseDockingClamp", Vector3(0.0, -0.49, -3.05), Vector3(0.38, 0.16, 0.45), _materials.gold)


func _build_cockpit() -> void:
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "CockpitInterior"
	_visual_root.add_child(_cockpit_root)

	# Recessed floor and sidewalls make the space read as an actual cabin even
	# while viewed through the closed transparent canopy.
	_box(_cockpit_root, "CockpitFloor", Vector3(0.0, 1.93, -0.55), Vector3(1.95, 0.12, 3.25), _materials.dark)
	_box(_cockpit_root, "PortSidewall", Vector3(-1.08, 2.17, -0.55), Vector3(0.18, 0.48, 3.2), _materials.structure)
	_box(_cockpit_root, "StarboardSidewall", Vector3(1.08, 2.17, -0.55), Vector3(0.18, 0.48, 3.2), _materials.structure)
	_box(_cockpit_root, "PortSill", Vector3(-1.18, 2.43, -0.55), Vector3(0.16, 0.16, 3.35), _materials.gold)
	_box(_cockpit_root, "StarboardSill", Vector3(1.18, 2.43, -0.55), Vector3(0.16, 0.16, 3.35), _materials.gold)
	_box(_cockpit_root, "ForwardPressureWall", Vector3(0.0, 2.25, -2.05), Vector3(2.05, 0.55, 0.16), _materials.structure)
	_box(_cockpit_root, "RearPressureWall", Vector3(0.0, 2.28, 0.94), Vector3(2.1, 0.65, 0.2), _materials.structure)

	# A fully modelled pilot seat: shell, cushion, back, bolsters, headrest, and
	# visible floor rails. The anchor is at the seated pelvis and remains a child
	# of the moving ship rather than a detached world-space boarding shortcut.
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_cockpit_root, side_name + "SeatRail", Vector3(side * 0.31, 2.04, 0.08), Vector3(0.1, 0.1, 1.2), _materials.mid)
		_box(_cockpit_root, side_name + "SeatBolster", Vector3(side * 0.43, 2.24, -0.02), Vector3(0.16, 0.34, 0.82), _materials.upholstery)
	_box(_cockpit_root, "SeatPan", Vector3(0.0, 2.17, -0.02), Vector3(0.76, 0.22, 0.82), _materials.upholstery)
	_box(
		_cockpit_root,
		"SeatBack",
		Vector3(0.0, 2.55, 0.35),
		Vector3(0.82, 0.92, 0.18),
		_materials.upholstery,
		Vector3(deg_to_rad(12.0), 0.0, 0.0)
	)
	_box(_cockpit_root, "Headrest", Vector3(0.0, 3.02, 0.48), Vector3(0.58, 0.32, 0.22), _materials.upholstery_light)
	_box(_cockpit_root, "HarnessLeft", Vector3(-0.2, 2.62, 0.23), Vector3(0.09, 0.65, 0.06), _materials.gold, Vector3(0.0, 0.0, deg_to_rad(-14.0)))
	_box(_cockpit_root, "HarnessRight", Vector3(0.2, 2.62, 0.23), Vector3(0.09, 0.65, 0.06), _materials.gold, Vector3(0.0, 0.0, deg_to_rad(14.0)))
	# Layered webbing, lap restraint, and a central rotary buckle make the seat's
	# occupant-retention system legible from both cockpit and exterior views.
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0.0 else "Right"
		_box(_cockpit_root, "ShoulderBelt" + side_name, Vector3(side * 0.19, 2.62, 0.19), Vector3(0.075, 0.68, 0.035), _materials.restraint, Vector3(0.0, 0.0, side * deg_to_rad(14.0)))
		_box(_cockpit_root, "LapBelt" + side_name, Vector3(side * 0.22, 2.31, -0.03), Vector3(0.38, 0.075, 0.045), _materials.restraint, Vector3(0.0, side * deg_to_rad(5.0), side * deg_to_rad(-11.0)))
		_cylinder(_cockpit_root, "HarnessAnchor" + side_name, Vector3(side * 0.3, 2.91, 0.33), 0.055, 0.08, _materials.mid, Vector3(90.0, 0.0, 0.0))
	_box(_cockpit_root, "BeltAntiSub", Vector3(0.0, 2.26, -0.16), Vector3(0.09, 0.34, 0.045), _materials.restraint, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_cylinder(_cockpit_root, "HarnessBuckle", Vector3(0.0, 2.37, -0.08), 0.12, 0.055, _materials.gold, Vector3(90.0, 0.0, 0.0))
	_pilot_seat_anchor = Marker3D.new()
	_pilot_seat_anchor.name = "PilotSeatAnchor"
	# PlayerController treats its root as a feet-frame; its hips are 0.72 m
	# above that origin. This places those hips on the 2.28 m seat cushion.
	_pilot_seat_anchor.position = Vector3(0.0, 1.56, -0.02)
	_cockpit_root.add_child(_pilot_seat_anchor)

	# Angled instrument hood with a central flight display, circular status
	# repeaters, side consoles, throttle, and a visibly articulated control stick.
	var instrument_cluster := Node3D.new()
	instrument_cluster.name = "InstrumentCluster"
	instrument_cluster.position = Vector3(0.0, 2.5, -1.52)
	instrument_cluster.rotation.x = deg_to_rad(-13.0)
	_cockpit_root.add_child(instrument_cluster)
	_box(instrument_cluster, "InstrumentHood", Vector3.ZERO, Vector3(1.62, 0.62, 0.18), _materials.dark)
	_box(instrument_cluster, "PrimaryFlightDisplay", Vector3(0.0, 0.06, 0.105), Vector3(0.72, 0.32, 0.035), _materials.display_cyan)
	_box(instrument_cluster, "DisplayBezelTop", Vector3(0.0, 0.245, 0.125), Vector3(0.82, 0.055, 0.055), _materials.mid)
	_box(instrument_cluster, "DisplayBezelBottom", Vector3(0.0, -0.125, 0.125), Vector3(0.82, 0.055, 0.055), _materials.mid)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(instrument_cluster, side_name + "DisplayBezelSide", Vector3(side * 0.385, 0.06, 0.125), Vector3(0.055, 0.32, 0.055), _materials.mid)
	for ladder_index in 5:
		var ladder_width := 0.34 - absf(float(ladder_index) - 2.0) * 0.035
		_box(
			instrument_cluster,
			"AttitudeLadder%02d" % ladder_index,
			Vector3(0.0, -0.015 + float(ladder_index) * 0.04, 0.136),
			Vector3(ladder_width, 0.012, 0.012),
			_materials.display_gold if ladder_index == 2 else _materials.display_cyan
		)
	_box(instrument_cluster, "WarningStrip", Vector3(0.0, -0.2, 0.11), Vector3(1.22, 0.055, 0.035), _materials.display_gold)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_cylinder(instrument_cluster, side_name + "StatusRepeater", Vector3(side * 0.57, 0.08, 0.11), 0.13, 0.035, _materials.display_cyan, Vector3(90.0, 0.0, 0.0))
		_box(_cockpit_root, side_name + "SideConsole", Vector3(side * 0.79, 2.24, -0.52), Vector3(0.42, 0.28, 1.38), _materials.structure, Vector3(0.0, 0.0, side * deg_to_rad(-8.0)))
		for light_index in 3:
			_box(
				_cockpit_root,
				side_name + "ConsoleKey%02d" % light_index,
				Vector3(side * (0.76 + light_index * side * 0.045), 2.41, -0.88 + light_index * 0.32),
				Vector3(0.12, 0.035, 0.12),
				_materials.display_gold if light_index == 1 else _materials.display_cyan
			)
		for switch_index in 4:
			_cylinder(
				_cockpit_root,
				("Port" if side < 0.0 else "Starboard") + "ConsoleToggle%02d" % switch_index,
				Vector3(side * 0.82, 2.45, -0.72 + float(switch_index) * 0.2),
				0.025,
				0.09,
				_materials.hydraulic,
				Vector3(0.0, 0.0, side * 12.0)
			)
		_cylinder(_cockpit_root, side_name + "ConsoleRotary", Vector3(side * 0.81, 2.44, 0.0), 0.07, 0.045, _materials.gold, Vector3(90.0, 0.0, 0.0))
	_torus(_cockpit_root, "ControlStickGimbal", Vector3(0.0, 2.11, -0.66), 0.1, 0.17, _materials.mid)
	_cylinder(_cockpit_root, "ControlStickShaft", Vector3(0.0, 2.38, -0.73), 0.055, 0.64, _materials.mid, Vector3(-14.0, 0.0, 0.0))
	_cylinder(_cockpit_root, "ControlStickGrip", Vector3(0.0, 2.68, -0.8), 0.075, 0.32, _materials.upholstery, Vector3(90.0, 0.0, 0.0))
	_box(_cockpit_root, "ControlStickTrigger", Vector3(0.0, 2.74, -0.97), Vector3(0.06, 0.12, 0.035), _materials.gold, Vector3(deg_to_rad(-12.0), 0.0, 0.0))
	_box(_cockpit_root, "ThrottleGate", Vector3(-0.75, 2.4, -0.25), Vector3(0.22, 0.055, 0.62), _materials.dark)
	_cylinder(_cockpit_root, "Throttle", Vector3(-0.75, 2.52, -0.25), 0.055, 0.4, _materials.gold, Vector3(0.0, 0.0, -18.0))
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_cockpit_root, side_name + "RudderPedal", Vector3(side * 0.28, 2.1, -1.48), Vector3(0.28, 0.08, 0.36), _materials.mid, Vector3(deg_to_rad(-18.0), 0.0, 0.0))

	_boarding_entry_marker = Marker3D.new()
	_boarding_entry_marker.name = "BoardingEntry"
	_boarding_entry_marker.position = Vector3(-1.42, 2.32, 0.18)
	_boarding_entry_marker.rotation.y = -PI * 0.5
	_cockpit_root.add_child(_boarding_entry_marker)

	# A rear-hinged one-piece canopy keeps glass and all reinforcing members
	# together during motion. Only this pivot rotates; neither the interior nor
	# the ship's exterior visual root is hidden during boarding.
	_canopy_pivot = Node3D.new()
	_canopy_pivot.name = "CanopyHinge"
	_canopy_pivot.position = Vector3(0.0, 2.42, 1.02)
	_canopy_pivot.rotation.x = CANOPY_OPEN_ANGLE if _canopy_open else 0.0
	_visual_root.add_child(_canopy_pivot)
	var canopy_glass := _wedge(_canopy_pivot, "CanopyGlass", Vector3(0.0, 0.46, -1.82), Vector3(2.48, 1.55, 3.58), _materials.glass)
	canopy_glass.set_meta("laminated_visual_edge", true)
	canopy_glass.set_meta("closed_volume", true)
	_box(_canopy_pivot, "CanopyRearFrame", Vector3(0.0, 0.32, -0.08), Vector3(2.58, 0.18, 0.18), _materials.dark)
	# Split the former centre rail into two slim longitudinal members. The broad
	# frame remains readable from outside while the pilot's reticle gets an
	# unobstructed central sight channel instead of pointing through a solid bar.
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(
			_canopy_pivot,
			side_name + "CanopyTopRail",
			Vector3(side * 0.72, 1.22, -1.58),
			Vector3(0.065, 0.075, 2.9),
			_materials.gold
		)
		_box(
			_canopy_pivot,
			side_name + "CanopyNoseFrame",
			Vector3(side * 0.62, 0.49, -3.56),
			Vector3(0.075, 1.08, 0.13),
			_materials.dark
		)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_canopy_pivot, side_name + "CanopyLowerRail", Vector3(side * 1.21, -0.02, -1.72), Vector3(0.13, 0.14, 3.45), _materials.dark)
		_box(_canopy_pivot, side_name + "CanopyRearUpright", Vector3(side * 1.2, 0.6, -0.12), Vector3(0.14, 1.25, 0.14), _materials.gold)
		_box(_canopy_pivot, side_name + "CanopyLowerPressureSeal", Vector3(side * 1.115, -0.105, -1.72), Vector3(0.085, 0.08, 3.32), _materials.seal)
		_box(_canopy_pivot, side_name + "CanopyLaminateEdge", Vector3(side * 1.13, 0.02, -1.72), Vector3(0.04, 0.055, 3.28), _materials.mid)
		_box(_canopy_pivot, side_name + "CanopyLatchHook", Vector3(side * 0.92, -0.14, -0.78), Vector3(0.16, 0.18, 0.24), _materials.hydraulic)
		_box(_cockpit_root, side_name + "CanopyLatchStriker", Vector3(side * 0.92, 2.37, 0.24), Vector3(0.2, 0.13, 0.24), _materials.mid)
	_box(_canopy_pivot, "CanopyNosePressureSeal", Vector3(0.0, 0.28, -3.55), Vector3(1.26, 0.075, 0.09), _materials.seal)
	_box(_canopy_pivot, "CanopyRearPressureSeal", Vector3(0.0, 0.18, -0.16), Vector3(2.28, 0.075, 0.09), _materials.seal)
	_cylinder(_visual_root, "CanopyHingeBar", Vector3(0.0, 2.42, 1.04), 0.12, 2.78, _materials.dark, Vector3(0.0, 0.0, 90.0))
	_tag_modern_interpretation(_visual_root.get_node("CanopyHingeBar"))
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		var hinge_mount := _cylinder(_visual_root, side_name + "CanopyHingeMount", Vector3(side * 1.31, 2.42, 1.04), 0.21, 0.22, _materials.gold, Vector3(0.0, 0.0, 90.0))
		_tag_modern_interpretation(hinge_mount)


func _tag_modern_interpretation(node: Node) -> void:
	if node == null:
		return
	node.set_meta("evidence_status", &"modern_interpretation")
	node.set_meta("design_origin", &"modern")
	node.set_meta("interpretation_status", &"modern")
	node.set_meta("historically_supported", false)


func _build_markers_and_camera() -> void:
	_boarding_marker = Marker3D.new()
	_boarding_marker.name = "BoardingPoint"
	_boarding_marker.position = Vector3(-3.2, 0.05, 0.65)
	add_child(_boarding_marker)
	_exit_marker = Marker3D.new()
	_exit_marker.name = "ExitPoint"
	# Place the pilot beyond the broad wing collision so re-enabling the player
	# capsule cannot wedge it inside the landed craft.
	_exit_marker.position = Vector3(-7.6, -1.0, 0.75)
	_exit_marker.rotation.y = -PI * 0.5
	add_child(_exit_marker)
	_muzzle_left = Marker3D.new()
	_muzzle_left.name = "LeftMuzzle"
	_muzzle_left.position = Vector3(-2.82, 0.42, -3.42)
	add_child(_muzzle_left)
	_muzzle_right = Marker3D.new()
	_muzzle_right.name = "RightMuzzle"
	_muzzle_right.position = Vector3(2.82, 0.42, -3.42)
	add_child(_muzzle_right)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraRig"
	_camera_pivot.position = Vector3(0.0, 2.2, 2.5)
	add_child(_camera_pivot)
	_camera_spring_arm = SpringArm3D.new()
	_camera_spring_arm.name = "CameraCollisionArm"
	_camera_spring_arm.collision_mask = PhysicsLayers.CAMERA_OBSTRUCTION_QUERY_MASK
	# The arm begins inside the owning hull, so including the shared Ship layer
	# requires an explicit self exclusion while still retracting for other craft.
	_camera_spring_arm.add_excluded_object(get_rid())
	_target_chase_camera_distance = _clamp_chase_camera_distance(
		_target_chase_camera_distance
	)
	_camera_spring_arm.spring_length = _target_chase_camera_distance
	_camera_spring_arm.margin = chase_camera_collision_margin
	# A swept volume keeps the near plane away from wall corners while the arm
	# retracts. The explicit RID exclusion above keeps this shape out of its hull.
	var camera_collision_shape := SphereShape3D.new()
	camera_collision_shape.radius = chase_camera_collision_radius
	_camera_spring_arm.shape = camera_collision_shape
	# SpringArm3D extends along local +Z; incline it to preserve the original
	# high chase-camera offset while letting the physics query control distance.
	_camera_spring_arm.rotation.x = -atan2(CHASE_CAMERA_OFFSET.y, CHASE_CAMERA_OFFSET.z)
	_camera_pivot.add_child(_camera_spring_arm)
	_camera = Camera3D.new()
	_camera.name = "ShipCamera"
	# Compensate for the arm incline so the reticle follows the physical nose.
	_camera.rotation.x = CHASE_CAMERA_PITCH - _camera_spring_arm.rotation.x
	_camera.fov = 72.0
	_camera.near = 0.15
	_camera.far = 1800.0
	_camera_boundary_mount = ChaseCameraBoundaryMount.new()
	_camera_boundary_mount.name = "CameraBoundaryMount"
	_camera_boundary_mount.controller = self
	# SpringArm moves this direct child after its sweep. The mount's later physics
	# priority then offsets only the camera, leaving arm distance and collision
	# ownership unchanged.
	_camera_boundary_mount.process_physics_priority = 100
	_camera_spring_arm.add_child(_camera_boundary_mount)
	_camera_boundary_mount.add_child(_camera)

	# The first-person camera shares the cockpit's presentation-only bank, but
	# keeps local -Z as its exact aiming axis. A short near plane lets the modelled
	# instrument hood and canopy frame remain visible at true cockpit scale.
	_cockpit_camera = Camera3D.new()
	_cockpit_camera.name = "CockpitCamera"
	_cockpit_camera.position = cockpit_camera_position
	_cockpit_camera.fov = 78.0
	_cockpit_camera.near = 0.04
	_cockpit_camera.far = 1800.0
	_cockpit_root.add_child(_cockpit_camera)
	_snap_chase_camera_response()
	_set_camera_current(_piloted)


func _enforce_chase_camera_self_hull_boundary() -> void:
	if _camera == null or _camera_boundary_mount == null:
		return
	var collision := get_landing_collision_report()
	var bounds := collision.get("local_bounds", AABB()) as AABB
	var mount_position := _camera_boundary_mount.global_position
	if not bool(collision.get("valid", false)) or not bounds.has_volume():
		_camera.global_position = mount_position
		return
	var base_samples := _chase_camera_boundary_samples(mount_position)
	var lowest_local_y := INF
	for sample_name: StringName in base_samples:
		var local_sample := to_local(base_samples[sample_name] as Vector3)
		lowest_local_y = minf(lowest_local_y, local_sample.y)
	var correction := 0.0
	if _minimum_signed_aabb_clearance(base_samples, bounds) \
			< CHASE_CAMERA_SELF_HULL_CLEARANCE:
		correction = maxf(
			bounds.end.y + CHASE_CAMERA_SELF_HULL_CLEARANCE - lowest_local_y,
			0.0
		)
	_camera.global_position = mount_position + global_basis.y.normalized() * correction


func _chase_camera_boundary_samples(camera_position: Vector3) -> Dictionary:
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var aspect := (
		viewport_size.x / viewport_size.y
		if viewport_size.x > 0.0 and viewport_size.y > 0.0 else 16.0 / 9.0
	)
	var tangent := tan(deg_to_rad(_camera.fov * 0.5))
	var half_width := _camera.near * tangent
	var half_height := half_width / aspect
	if _camera.keep_aspect == Camera3D.KEEP_HEIGHT:
		half_height = _camera.near * tangent
		half_width = half_height * aspect
	var forward := -_camera.global_basis.z.normalized()
	var right := _camera.global_basis.x.normalized()
	var up := _camera.global_basis.y.normalized()
	var near_centre := camera_position + forward * _camera.near
	return {
		&"camera_point": camera_position,
		&"near_top_left": near_centre - right * half_width + up * half_height,
		&"near_top_right": near_centre + right * half_width + up * half_height,
		&"near_bottom_left": near_centre - right * half_width - up * half_height,
		&"near_bottom_right": near_centre + right * half_width - up * half_height,
	}


func _minimum_signed_aabb_clearance(samples: Dictionary, bounds: AABB) -> float:
	var result := INF
	for sample_name: StringName in samples:
		result = minf(
			result,
			_signed_point_aabb_clearance(to_local(samples[sample_name] as Vector3), bounds)
		)
	return result


func _signed_point_aabb_clearance(point: Vector3, bounds: AABB) -> float:
	var outside := Vector3(
		maxf(maxf(bounds.position.x - point.x, point.x - bounds.end.x), 0.0),
		maxf(maxf(bounds.position.y - point.y, point.y - bounds.end.y), 0.0),
		maxf(maxf(bounds.position.z - point.z, point.z - bounds.end.z), 0.0)
	)
	if not outside.is_zero_approx():
		return outside.length()
	return -minf(
		minf(
			minf(point.x - bounds.position.x, bounds.end.x - point.x),
			minf(point.y - bounds.position.y, bounds.end.y - point.y)
		),
		minf(point.z - bounds.position.z, bounds.end.z - point.z)
	)
func _snap_chase_camera_response() -> void:
	var ship_basis := global_basis.orthonormalized()
	_chase_follow_rotation = Quaternion(ship_basis).normalized()
	_chase_camera_rotation_lag_degrees = 0.0
	_chase_camera_bank = 0.0
	if _camera_pivot != null:
		_camera_pivot.global_basis = ship_basis
		_camera_pivot.reset_physics_interpolation()
	if _camera != null:
		_camera.global_basis = ship_basis
		_camera.reset_physics_interpolation()


func _ensure_camera_view_input_action() -> void:
	if InputMap.has_action(CAMERA_VIEW_ACTION):
		return
	InputMap.add_action(CAMERA_VIEW_ACTION)
	var default_key := InputEventKey.new()
	default_key.physical_keycode = KEY_V
	InputMap.action_add_event(CAMERA_VIEW_ACTION, default_key)


func _set_camera_current(active: bool) -> void:
	if _camera != null:
		_camera.current = active and not _cockpit_view
	if _cockpit_camera != null:
		_cockpit_camera.current = active and _cockpit_view


func _clamp_chase_camera_distance(distance: float) -> float:
	var lower_bound := minf(minimum_chase_camera_distance, maximum_chase_camera_distance)
	var upper_bound := maxf(minimum_chase_camera_distance, maximum_chase_camera_distance)
	return clampf(distance, lower_bound, upper_bound)


func _build_collision() -> void:
	# Seven simple boxes cover the evaluated primary hull, propulsion hardware,
	# and parked gear within two centimetres while retaining the arcade collision
	# profile and central-berth clearance. These are gameplay authority; the GLB
	# remains presentation-only.
	_add_box_collision_shape("HullCollision", Vector3(0.0, 1.05, -0.3), Vector3(4.6, 2.35, 9.0))
	_add_box_collision_shape("WingCollision", Vector3(0.0, 0.62, 0.05), Vector3(7.2, 1.5, 6.3))
	_add_box_collision_shape("UpperSilhouetteCollision", Vector3(0.0, 2.85, 0.85), Vector3(4.75, 1.75, 6.0))
	_add_box_collision_shape("PortAftPropulsionCollision", Vector3(-2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7))
	_add_box_collision_shape("StarboardAftPropulsionCollision", Vector3(2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7))
	_add_box_collision_shape("LowerGearCollision", Vector3(0.0, -0.4, -0.15), Vector3(5.0, 0.75, 4.95))
	_add_box_collision_shape("NoseGearCollision", Vector3(0.0, -0.4, -3.05), Vector3(0.85, 0.55, 1.35))


func _add_box_collision_shape(shape_name: String, position_value: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = shape_name
	collision.position = position_value
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	add_child(collision)


func _sync_engine_visuals_immediately() -> void:
	var engine_active := not _destroyed and _engine_state in [ENGINE_STARTING, ENGINE_ONLINE]
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	var engine_level := 0.0
	if _engine_state == ENGINE_STARTING:
		engine_level = 0.25
	elif _engine_state == ENGINE_ONLINE:
		engine_level = 0.42 + absf(_throttle) * 0.58
		if _damage_presentation != null:
			engine_level *= clampf(
				_damage_presentation.get_engine_power_multiplier(), 0.0, 1.0
			)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var geometry_multiplier := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for glow in _engine_glows:
		if is_instance_valid(glow):
			glow.visible = engine_active
			glow.scale.z = 0.45 + engine_level * 1.4 * geometry_multiplier
	for core in _engine_core_glows:
		if is_instance_valid(core):
			core.visible = engine_active
	for light in _engine_lights:
		if is_instance_valid(light):
			light.light_energy = engine_level * 2.6
	_apply_engine_exhaust_damage_presentation(
		_engine_glows, _engine_lights, engine_active, exhaust_profile
	)
	_sync_variant_engine_presentation_immediately()


## One virtual same-tick seam for fleet-specific plume/core/light rosters. Base
## lifecycle and automatic-demand transitions call this before publishing their
## engine-state signal, so no derived craft waits for its next presentation tick.
func _sync_variant_engine_presentation_immediately() -> void:
	pass


## Presentation-only grading of the existing propulsion output. Component
## integrity remains owned by ShipComponentDamage and actual thrust continues to
## use `_get_damage_engine_multiplier()` in the flight integrator.
func get_engine_exhaust_damage_presentation_profile() -> Dictionary:
	var integrity := 1.0
	var authoritative_state := ShipComponentDamage.ComponentState.NOMINAL
	if _component_damage != null and _component_damage.is_configured():
		integrity = clampf(_component_damage.get_component_integrity(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		), 0.0, 1.0)
		authoritative_state = _component_damage.get_component_state(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		)
	var stage: StringName = &"nominal"
	var geometry_multiplier := 1.0
	var intensity_multiplier := 1.0
	var visible_fraction := 1.0
	var overlay_color := Color.TRANSPARENT
	if authoritative_state >= ShipComponentDamage.ComponentState.FAILED:
		stage = &"failed"
		geometry_multiplier = 0.0
		intensity_multiplier = 0.0
		visible_fraction = 0.0
		overlay_color = Color("ff3b35")
	elif integrity <= 0.40:
		stage = &"critical"
		geometry_multiplier = 0.48
		intensity_multiplier = 0.42
		visible_fraction = 0.5
		overlay_color = Color("ff653a")
	elif authoritative_state >= ShipComponentDamage.ComponentState.IMPAIRED:
		stage = &"degraded"
		geometry_multiplier = 0.78
		intensity_multiplier = 0.72
		overlay_color = Color("ffd166")
	return {
		"stage": stage,
		"engine_integrity": integrity,
		"authoritative_state": authoritative_state,
		"geometry_multiplier": geometry_multiplier,
		"intensity_multiplier": intensity_multiplier,
		"visible_fraction": visible_fraction,
		"overlay_color": overlay_color,
		"overlay_material_resources_allocated": (
			1 if _engine_exhaust_damage_overlay != null else 0
		),
		"maximum_overlay_material_resources_per_ship": 1,
		"active_overlay_passes_per_visible_plume": (
			1 if stage in [&"degraded", &"critical"] else 0
		),
		"added_nodes": 0,
		"added_meshes": 0,
		"collision_shapes": 0,
		"transition_policy": &"static",
		"flashing": false,
		"motion_animation_added": false,
		"gameplay_authority": false,
	}.duplicate(true)


func _apply_engine_exhaust_damage_presentation(
		plumes: Array,
		lights: Array,
		engine_active: bool,
		profile: Dictionary
	) -> void:
	var stage := StringName(profile.get("stage", &"nominal"))
	var overlay: Material = null
	if stage in [&"degraded", &"critical"]:
		_ensure_engine_exhaust_damage_overlay()
		var color := profile.get("overlay_color", Color.WHITE) as Color
		_engine_exhaust_damage_overlay.albedo_color = Color(color, 0.58)
		_engine_exhaust_damage_overlay.emission = color
		_engine_exhaust_damage_overlay.emission_energy_multiplier = (
			1.8 if stage == &"critical" else 1.2
		)
		overlay = _engine_exhaust_damage_overlay
	for index in plumes.size():
		var plume := plumes[index] as MeshInstance3D
		if not is_instance_valid(plume):
			continue
		var instance_id := plume.get_instance_id()
		if not _engine_exhaust_original_overlays.has(instance_id):
			_engine_exhaust_original_overlays[instance_id] = plume.material_overlay
		plume.material_overlay = (
			overlay
			if overlay != null
			else _engine_exhaust_original_overlays.get(instance_id) as Material
		)
		var stage_visible := stage not in [&"failed"]
		if stage == &"critical":
			stage_visible = index % 2 == 0
		plume.visible = engine_active and stage_visible
	for light_value in lights:
		var light := light_value as OmniLight3D
		if not is_instance_valid(light):
			continue
		var light_id := light.get_instance_id()
		if not _engine_exhaust_original_light_colors.has(light_id):
			_engine_exhaust_original_light_colors[light_id] = light.light_color
		light.light_color = (
			profile.get("overlay_color", light.light_color) as Color
			if stage in [&"degraded", &"critical"]
			else _engine_exhaust_original_light_colors.get(light_id, light.light_color) as Color
		)


func _ensure_engine_exhaust_damage_overlay() -> void:
	if _engine_exhaust_damage_overlay != null:
		return
	_engine_exhaust_damage_overlay = StandardMaterial3D.new()
	_engine_exhaust_damage_overlay.resource_name = "EngineExhaustDamageOverlay"
	_engine_exhaust_damage_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_engine_exhaust_damage_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_engine_exhaust_damage_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_engine_exhaust_damage_overlay.emission_enabled = true


## Static, authority-free grade for the weaker of the two wing-mounted weapon
## sections. HeroShip's existing fire-status and dispatch methods remain the
## only firing authority; this snapshot only drives retained emitter geometry.
func get_weapon_component_presentation_profile() -> Dictionary:
	var integrity := 1.0
	var authoritative_state := ShipComponentDamage.ComponentState.NOMINAL
	if _component_damage != null and _component_damage.is_configured():
		var port_integrity := _component_damage.get_component_integrity(
			ShipComponentDamage.COMPONENT_PORT_WING
		)
		var starboard_integrity := _component_damage.get_component_integrity(
			ShipComponentDamage.COMPONENT_STARBOARD_WING
		)
		integrity = clampf(minf(port_integrity, starboard_integrity), 0.0, 1.0)
		authoritative_state = maxi(
			_component_damage.get_component_state(ShipComponentDamage.COMPONENT_PORT_WING),
			_component_damage.get_component_state(ShipComponentDamage.COMPONENT_STARBOARD_WING)
		)
	var stage: StringName = &"nominal"
	var geometry_multiplier := 1.0
	var intensity_multiplier := 1.0
	var visible_fraction := 1.0
	var overlay_color := Color.TRANSPARENT
	if authoritative_state >= ShipComponentDamage.ComponentState.FAILED:
		stage = &"failed"
		geometry_multiplier = 0.0
		intensity_multiplier = 0.0
		visible_fraction = 0.0
		overlay_color = Color("ff3b35")
	elif integrity <= 0.40:
		stage = &"critical"
		geometry_multiplier = 0.48
		intensity_multiplier = 0.36
		visible_fraction = 0.5
		overlay_color = Color("ff5944")
	elif authoritative_state >= ShipComponentDamage.ComponentState.IMPAIRED:
		stage = &"degraded"
		geometry_multiplier = 0.76
		intensity_multiplier = 0.70
		overlay_color = Color("ffd166")
	return {
		"stage": stage,
		"weapon_integrity": integrity,
		"authoritative_state": authoritative_state,
		"geometry_multiplier": geometry_multiplier,
		"intensity_multiplier": intensity_multiplier,
		"visible_fraction": visible_fraction,
		"overlay_color": overlay_color,
		"emitter_count": _weapon_component_emitters.size(),
		"fallback_node_count": _weapon_component_fallback_node_count,
		"fallback_mesh_count": _weapon_component_fallback_mesh_count,
		"maximum_damage_overlay_materials_per_ship": 1,
		"transition_policy": &"static",
		"flashing": false,
		"motion_animation_added": false,
		"collision_shapes": 0,
		"fire_authority": false,
	}.duplicate(true)


func get_weapon_component_emitter_snapshot() -> Dictionary:
	_ensure_weapon_component_emitters()
	var emitters: Array[Dictionary] = []
	for emitter in _weapon_component_emitters:
		if not is_instance_valid(emitter):
			continue
		var overlay := emitter.material_overlay as StandardMaterial3D
		emitters.append({
			"name": String(emitter.name),
			"instance_id": emitter.get_instance_id(),
			"global_position": emitter.global_position,
			"scale": emitter.scale,
			"visible": emitter.visible and emitter.is_visible_in_tree(),
			"transparency": emitter.transparency,
			"overlay_color": overlay.emission if overlay != null else Color.TRANSPARENT,
		})
	var snapshot := get_weapon_component_presentation_profile()
	snapshot["emitters"] = emitters
	snapshot["visible_emitter_count"] = emitters.filter(
		func(record: Dictionary) -> bool: return bool(record.get("visible", false))
	).size()
	return snapshot.duplicate(true)


func _sync_weapon_component_presentation() -> void:
	if not _weapon_component_presentation_initialized:
		return
	_ensure_weapon_component_emitters()
	if _weapon_component_emitters.is_empty():
		return
	var profile := get_weapon_component_presentation_profile()
	var stage := StringName(profile.get("stage", &"nominal"))
	var geometry_multiplier := float(profile.get("geometry_multiplier", 1.0))
	var intensity_multiplier := float(profile.get("intensity_multiplier", 1.0))
	var overlay: Material = null
	if stage in [&"degraded", &"critical"]:
		_ensure_weapon_component_damage_overlay()
		var color := profile.get("overlay_color", Color.WHITE) as Color
		_weapon_component_damage_overlay.albedo_color = Color(color, 0.56)
		_weapon_component_damage_overlay.emission = color
		_weapon_component_damage_overlay.emission_energy_multiplier = intensity_multiplier
		overlay = _weapon_component_damage_overlay
	for index in _weapon_component_emitters.size():
		var emitter := _weapon_component_emitters[index]
		if not is_instance_valid(emitter):
			continue
		var instance_id := emitter.get_instance_id()
		var base_scale := _weapon_component_original_scales.get(
			instance_id, Vector3.ONE
		) as Vector3
		emitter.scale = base_scale * geometry_multiplier
		emitter.material_overlay = (
			overlay
			if overlay != null
			else _weapon_component_original_overlays.get(instance_id) as Material
		)
		var base_transparency := float(
			_weapon_component_original_transparency.get(instance_id, 0.0)
		)
		emitter.transparency = clampf(
			base_transparency + (1.0 - intensity_multiplier) * 0.75,
			0.0,
			1.0
		)
		var visible := bool(_weapon_component_original_visibility.get(instance_id, true))
		if stage == &"critical":
			visible = visible and index % 2 == 0
		elif stage == &"failed":
			visible = false
		emitter.visible = visible and not _destroyed


func _initialize_weapon_component_presentation() -> void:
	_weapon_component_presentation_initialized = true
	_sync_weapon_component_presentation()


func _ensure_weapon_component_emitters() -> void:
	# Component configuration can emit during HeroShip._ready(), before variant
	# visuals have finished registering their authored lenses. Defer discovery
	# until the complete craft is ready so that fallback geometry is only used
	# when a retained variant genuinely has no independent live emitter mesh.
	if not is_node_ready():
		return
	var retained: Array[MeshInstance3D] = []
	for emitter in _weapon_component_emitters:
		if is_instance_valid(emitter):
			retained.append(emitter)
	if retained.size() >= 2:
		_weapon_component_emitters = retained
		return
	_weapon_component_emitters.clear()
	var visual := get_variant_visual_root()
	var all_lenses: Array[MeshInstance3D] = []
	if visual != null:
		for candidate in visual.find_children("*", "MeshInstance3D", true, false):
			if String(candidate.name).ends_with("MuzzleLens"):
				all_lenses.append(candidate as MeshInstance3D)
	for lens in all_lenses:
		if _weapon_emitter_is_authored_visible(lens, visual):
			_weapon_component_emitters.append(lens)
	if _weapon_component_emitters.size() < 2:
		_weapon_component_emitters.clear()
		var reusable_mesh := all_lenses[0].mesh if not all_lenses.is_empty() else null
		if reusable_mesh == null:
			var fallback_mesh := SphereMesh.new()
			fallback_mesh.radius = 0.11
			fallback_mesh.height = 0.22
			fallback_mesh.radial_segments = 12
			fallback_mesh.rings = 6
			fallback_mesh.material = _materials.get("cyan") as Material
			reusable_mesh = fallback_mesh
			_weapon_component_fallback_mesh_count = 1
		_weapon_component_fallback_mesh = reusable_mesh
		for marker in [_muzzle_left, _muzzle_right]:
			if marker == null or not is_instance_valid(marker):
				continue
			var emitter := marker.get_node_or_null("WeaponChargeEmitter") as MeshInstance3D
			if emitter == null:
				emitter = MeshInstance3D.new()
				emitter.name = "WeaponChargeEmitter"
				emitter.mesh = _weapon_component_fallback_mesh
				emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				emitter.set_meta("presentation_only", true)
				emitter.set_meta("gameplay_authority", false)
				marker.add_child(emitter)
				_weapon_component_fallback_node_count += 1
			_weapon_component_emitters.append(emitter)
	_weapon_component_emitters.sort_custom(
		func(left: MeshInstance3D, right: MeshInstance3D) -> bool:
			return left.global_position.x < right.global_position.x
	)
	for emitter in _weapon_component_emitters:
		var instance_id := emitter.get_instance_id()
		_weapon_component_original_scales[instance_id] = emitter.scale
		_weapon_component_original_overlays[instance_id] = emitter.material_overlay
		_weapon_component_original_transparency[instance_id] = emitter.transparency
		_weapon_component_original_visibility[instance_id] = emitter.visible


func _weapon_emitter_is_authored_visible(emitter: MeshInstance3D, visual: Node3D) -> bool:
	var current: Node = emitter
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		if current == visual:
			break
		current = current.get_parent()
	return current == visual


func _ensure_weapon_component_damage_overlay() -> void:
	if _weapon_component_damage_overlay != null:
		return
	_weapon_component_damage_overlay = StandardMaterial3D.new()
	_weapon_component_damage_overlay.resource_name = "WeaponComponentDamageOverlay"
	_weapon_component_damage_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_weapon_component_damage_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_weapon_component_damage_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_weapon_component_damage_overlay.emission_enabled = true


func _sync_imported_canopy_immediately() -> void:
	var presentation := _get_live_torrent_hero_presentation()
	if presentation == null or _canopy_pivot == null:
		return
	presentation.set_canopy_fraction(
		_canopy_pivot.rotation.x / maxf(CANOPY_OPEN_ANGLE, 0.001)
	)


func _set_canopy_open_fraction(open_fraction: float) -> void:
	var fraction := clampf(open_fraction, 0.0, 1.0)
	if _canopy_pivot != null:
		_canopy_pivot.rotation = Vector3(CANOPY_OPEN_ANGLE * fraction, 0.0, 0.0)
	var presentation := _get_live_torrent_hero_presentation()
	if presentation != null:
		presentation.set_canopy_fraction(fraction)


func _on_torrent_lod_changed(_lod_index: int) -> void:
	_sync_torrent_close_overlay_visibility()


func _sync_torrent_close_overlay_visibility() -> void:
	var presentation := _get_live_torrent_hero_presentation()
	if presentation == null:
		return
	var close_visible := presentation.get_active_lod() == 0
	if _cockpit_readout != null:
		_cockpit_readout.visible = close_visible
	if _cockpit_practical_light != null:
		_cockpit_practical_light.visible = close_visible


func _get_live_torrent_hero_presentation() -> TorrentHeroPresentation:
	if (
		_torrent_hero_presentation != null
		and is_instance_valid(_torrent_hero_presentation)
		and not _torrent_hero_presentation.is_queued_for_deletion()
		and _torrent_hero_presentation.get_parent() == _visual_root
	):
		# A whole HeroShip detach temporarily takes this retained direct child out of
		# the tree. It is still the installed adapter, so presentation calls simply
		# defer until re-entry rather than treating that ordinary lifecycle boundary
		# as a stale-cache failure.
		if _torrent_hero_presentation.is_inside_tree():
			return _torrent_hero_presentation
		return null
	_torrent_hero_presentation = null
	if _legacy_torrent_cockpit_art != null \
			and is_instance_valid(_legacy_torrent_cockpit_art):
		_legacy_torrent_cockpit_art.visible = true
	if _legacy_torrent_canopy_art != null \
			and is_instance_valid(_legacy_torrent_canopy_art):
		_legacy_torrent_canopy_art.visible = true
	if _legacy_torrent_presentation != null \
			and is_instance_valid(_legacy_torrent_presentation):
		_legacy_torrent_presentation.visible = true
	if _cockpit_readout != null and is_instance_valid(_cockpit_readout):
		_cockpit_readout.visible = true
	if _cockpit_practical_light != null and is_instance_valid(_cockpit_practical_light):
		_cockpit_practical_light.visible = true
	return null


func _get_torrent_collision_authority_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _uses_torrent_reconstruction_presentation():
		return errors
	if collision_layer != PhysicsLayers.SHIP_BODY_LAYER or collision_mask != PhysicsLayers.SHIP_BODY_MASK:
		errors.append("Torrent collision layer or mask drifted from ship authority")
	var expected := {
		"HullCollision": [Vector3(0.0, 1.05, -0.3), Vector3(4.6, 2.35, 9.0)],
		"WingCollision": [Vector3(0.0, 0.62, 0.05), Vector3(7.2, 1.5, 6.3)],
		"UpperSilhouetteCollision": [Vector3(0.0, 2.85, 0.85), Vector3(4.75, 1.75, 6.0)],
		"PortAftPropulsionCollision": [Vector3(-2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7)],
		"StarboardAftPropulsionCollision": [Vector3(2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7)],
		"LowerGearCollision": [Vector3(0.0, -0.4, -0.15), Vector3(5.0, 0.75, 4.95)],
		"NoseGearCollision": [Vector3(0.0, -0.4, -3.05), Vector3(0.85, 0.55, 1.35)],
	}
	var live_collision_names := PackedStringArray()
	for child in get_children():
		if child is CollisionShape3D:
			live_collision_names.append(str(child.name))
	live_collision_names.sort()
	var expected_collision_names := PackedStringArray(expected.keys())
	expected_collision_names.sort()
	if live_collision_names != expected_collision_names:
		errors.append("Torrent direct collision roster drifted from exact authority")
	for shape_name: String in expected:
		var collision := get_node_or_null(NodePath(shape_name)) as CollisionShape3D
		if collision == null or collision.disabled or not collision.shape is BoxShape3D:
			errors.append("Torrent collision authority is missing or disabled: %s" % shape_name)
			continue
		var contract: Array = expected[shape_name]
		var expected_transform := Transform3D(Basis.IDENTITY, contract[0] as Vector3)
		if collision.top_level or not collision.transform.is_equal_approx(expected_transform):
			errors.append("Torrent collision transform drifted: %s" % shape_name)
		if not (collision.shape as BoxShape3D).size.is_equal_approx(contract[1] as Vector3):
			errors.append("Torrent collision size drifted: %s" % shape_name)
	return errors


func _get_torrent_functional_authority_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _uses_torrent_reconstruction_presentation():
		return errors
	var exact_nodes: Array[Dictionary] = [
		{
			"name": "BoardingPoint", "node": _boarding_marker, "parent": self,
			"transform": Transform3D(Basis.IDENTITY, Vector3(-3.2, 0.05, 0.65)),
		},
		{
			"name": "ExitPoint", "node": _exit_marker, "parent": self,
			"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-7.6, -1.0, 0.75)),
		},
		{
			"name": "LeftMuzzle", "node": _muzzle_left, "parent": self,
			"transform": Transform3D(Basis.IDENTITY, Vector3(-2.82, 0.42, -3.42)),
		},
		{
			"name": "RightMuzzle", "node": _muzzle_right, "parent": self,
			"transform": Transform3D(Basis.IDENTITY, Vector3(2.82, 0.42, -3.42)),
		},
		{
			"name": "PilotSeatAnchor", "node": _pilot_seat_anchor, "parent": _cockpit_root,
			"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 1.56, -0.02)),
		},
		{
			"name": "BoardingEntry", "node": _boarding_entry_marker, "parent": _cockpit_root,
			"transform": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-1.42, 2.32, 0.18)),
		},
		{
			"name": "CockpitCamera", "node": _cockpit_camera, "parent": _cockpit_root,
			"transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 3.32, -0.52)),
		},
	]
	for contract in exact_nodes:
		var expected_name := str(contract.get("name", ""))
		var node_value: Variant = contract.get("node")
		var parent_value: Variant = contract.get("parent")
		if not is_instance_valid(node_value) or not is_instance_valid(parent_value):
			errors.append("Torrent functional authority drifted: %s" % expected_name)
			continue
		var node := node_value as Node3D
		var expected_parent := parent_value as Node
		var expected_transform: Transform3D = contract.get(
			"transform", Transform3D.IDENTITY
		)
		if (
			node == null
			or expected_parent == null
			or node.name != StringName(expected_name)
			or node.get_parent() != expected_parent
			or node.top_level
			or not node.transform.is_equal_approx(expected_transform)
		):
			errors.append("Torrent functional authority drifted: %s" % expected_name)
	var boarding_area := get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if (
		boarding_area == null
		or boarding_area.get_parent() != self
		or boarding_area.top_level
		or not boarding_area.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(-3.2, 0.55, 0.65))
		)
		or boarding_area.get_ship() != self
	):
		errors.append("Torrent boarding interaction authority drifted")
	return errors


func _get_torrent_lifecycle_visual_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _uses_torrent_reconstruction_presentation():
		return errors
	var live_presentation: TorrentHeroPresentation = (
		_torrent_hero_presentation
		if (
			_torrent_hero_presentation != null
			and is_instance_valid(_torrent_hero_presentation)
		)
		else null
	)
	if live_presentation == null:
		errors.append("Torrent live presentation adapter is missing")
		return errors
	var live_visual: Node3D = (
		_visual_root
		if _visual_root != null and is_instance_valid(_visual_root)
		else null
	)
	if (
		live_visual == null
		or not live_visual.visible
		or not live_presentation.visible
		or not live_presentation.is_visible_in_tree()
	):
		errors.append("Torrent live presentation ancestry is hidden")
	if live_visual != null:
		var visual_rotation := live_visual.rotation
		if (
			live_visual.top_level
			or not live_visual.position.is_zero_approx()
			or not live_visual.scale.is_equal_approx(Vector3.ONE)
			or not visual_rotation.is_finite()
			or not is_zero_approx(visual_rotation.x)
			or not is_zero_approx(visual_rotation.y)
			or absf(visual_rotation.z) > deg_to_rad(visual_bank_degrees) + 0.01
		):
			errors.append("Torrent visual root transform drifted outside presentation banking authority")
	var expected_engine_visible := not _destroyed and _engine_state in [ENGINE_STARTING, ENGINE_ONLINE]
	var expected_plume_names := PackedStringArray([
		"LOD1PortEnginePlume", "LOD1StarboardEnginePlume",
		"PortEnginePlume", "StarboardEnginePlume",
	])
	var live_plume_names := PackedStringArray()
	for plume in _engine_glows:
		if is_instance_valid(plume):
			live_plume_names.append(str(plume.name))
	live_plume_names.sort()
	expected_plume_names.sort()
	var expected_core_names := PackedStringArray(["PortEngineCore", "StarboardEngineCore"])
	var live_core_names := PackedStringArray()
	for core in _engine_core_glows:
		if is_instance_valid(core):
			live_core_names.append(str(core.name))
	live_core_names.sort()
	expected_core_names.sort()
	if (
		_engine_glows.size() != 4
		or _engine_core_glows.size() != 2
		or live_plume_names != expected_plume_names
		or live_core_names != expected_core_names
	):
		errors.append("Torrent imported engine visual roster drifted")
	for engine_part in _engine_glows + _engine_core_glows:
		if not is_instance_valid(engine_part) or engine_part.visible != expected_engine_visible:
			errors.append("Torrent imported engine visibility disagrees with lifecycle state")
			break
	if _engine_lights.size() != 2:
		errors.append("Torrent engine light roster drifted")
	else:
		for light in _engine_lights:
			if not is_instance_valid(light):
				errors.append("Torrent engine light roster drifted")
				break
			if not expected_engine_visible and not is_zero_approx(light.light_energy):
				errors.append("Torrent engine light remains energized while offline")
				break
	if _canopy_pivot != null and is_instance_valid(_canopy_pivot):
		var imported_canopy := live_presentation.get_canopy_pivot()
		if (
			imported_canopy == null
			or not is_equal_approx(imported_canopy.rotation.x, _canopy_pivot.rotation.x)
		):
			errors.append("Torrent imported canopy disagrees with functional hinge")
	else:
		errors.append("Torrent functional canopy hinge is missing")
	var close_visible := live_presentation.get_active_lod() == 0
	if (
		_cockpit_readout == null
		or not is_instance_valid(_cockpit_readout)
		or _cockpit_readout.visible != close_visible
	):
		errors.append("Torrent cockpit readout disagrees with close LOD ownership")
	if (
		_cockpit_practical_light == null
		or not is_instance_valid(_cockpit_practical_light)
		or _cockpit_practical_light.visible != close_visible
	):
		errors.append("Torrent practical light disagrees with close LOD ownership")
	if (
		_torrent_unknown_function_panel == null
		or not is_instance_valid(_torrent_unknown_function_panel)
		or _torrent_unknown_function_panel.get_parent() != live_presentation.get_lod0_root()
	):
		errors.append("Torrent unknown-function panel identity drifted")
	if (
		_legacy_torrent_cockpit_art == null
		or not is_instance_valid(_legacy_torrent_cockpit_art)
		or _legacy_torrent_cockpit_art.visible
		or _cockpit_root == null
		or not is_instance_valid(_cockpit_root)
		or _legacy_torrent_cockpit_art.get_parent() != _cockpit_root
	):
		errors.append("Torrent legacy cockpit fallback gate drifted or became visible")
	if (
		_legacy_torrent_canopy_art == null
		or not is_instance_valid(_legacy_torrent_canopy_art)
		or _legacy_torrent_canopy_art.visible
		or _canopy_pivot == null
		or not is_instance_valid(_canopy_pivot)
		or _legacy_torrent_canopy_art.get_parent() != _canopy_pivot
	):
		errors.append("Torrent legacy canopy fallback gate drifted or became visible")
	if (
		_legacy_torrent_presentation == null
		or not is_instance_valid(_legacy_torrent_presentation)
		or _legacy_torrent_presentation.visible
		or live_visual == null
		or _legacy_torrent_presentation.get_parent() != live_visual
	):
		errors.append("Torrent legacy far fallback gate drifted or became visible")
	return errors


static func _shape_local_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return AABB(-size * 0.5, size)
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return AABB(
			Vector3(-capsule.radius, -capsule.height * 0.5, -capsule.radius),
			Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
		)
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return AABB(
			Vector3(-cylinder.radius, -cylinder.height * 0.5, -cylinder.radius),
			Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		)
	var points := PackedVector3Array()
	if shape is ConvexPolygonShape3D:
		points = (shape as ConvexPolygonShape3D).points
	elif shape is ConcavePolygonShape3D:
		points = (shape as ConcavePolygonShape3D).get_faces()
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


static func _transformed_local_aabb(transform_value: Transform3D, source: AABB) -> AABB:
	var minimum := source.position
	var maximum := source.end
	var corners := PackedVector3Array([
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
	])
	var transformed := AABB(transform_value * corners[0], Vector3.ZERO)
	for corner in corners:
		transformed = transformed.expand(transform_value * corner)
	return transformed


func _create_materials() -> void:
	_materials.ivory = _material(HULL_IVORY, 0.08, 0.34)
	_materials.light = _material(HULL_LIGHT, 0.06, 0.3)
	_materials.mid = _material(HULL_MID, 0.42, 0.48)
	_materials.structure = _material(STRUCTURE, 0.55, 0.43)
	_materials.dark = _material(STRUCTURE_DARK, 0.62, 0.35)
	_materials.gold = _material(identification_accent, 0.34, 0.38)
	_materials.cyan = _material(KETH_CYAN, 0.24, 0.3, KETH_CYAN, 1.2)
	_materials.engine = _material(ENGINE_BLUE, 0.08, 0.2, ENGINE_BLUE, 2.6)
	_materials.nav_red = _material(NAV_RED, 0.12, 0.24, NAV_RED, 2.0)
	_materials.nav_green = _material(NAV_GREEN, 0.12, 0.24, NAV_GREEN, 2.0)
	_materials.upholstery = _material(Color("102c35"), 0.12, 0.78)
	_materials.upholstery_light = _material(Color("31515a"), 0.18, 0.68)
	_materials.seat_red = _material(Color("a83227"), 0.08, 0.68)
	_materials.seat_red_light = _material(Color("b54432"), 0.10, 0.58)
	_materials.display_cyan = _material(Color("16383e"), 0.16, 0.25, KETH_CYAN, 2.8)
	_materials.display_substrate = _material(Color("07161c"), 0.08, 0.46, Color("0d2a30"), 0.08)
	_materials.display_cyan_low = _material(Color("0b242a"), 0.10, 0.40, KETH_CYAN.darkened(0.25), 0.38)
	_materials.display_gold_low = _material(
		identification_accent.darkened(0.78),
		0.10,
		0.42,
		identification_accent.darkened(0.18),
		0.42
	)
	_materials.display_gold = _material(
		identification_accent.darkened(0.68),
		0.16,
		0.28,
		identification_accent,
		2.4
	)
	_materials.panel = _material(Color("66777a"), 0.5, 0.48)
	_materials.thermal = _material(Color("3b3431"), 0.72, 0.56)
	_materials.hydraulic = _material(Color("b9c4c1"), 0.76, 0.2)
	_materials.seal = _material(Color("081015"), 0.06, 0.88)
	_materials.restraint = _material(Color("c7a647"), 0.08, 0.72)
	var anti_glare := _material(Color(0.18, 0.20, 0.22), 0.04, 0.82)
	anti_glare.albedo_texture = load("res://assets/materials/cockpit-anti-glare-composite-v1.png") as Texture2D
	anti_glare.uv1_triplanar = true
	anti_glare.uv1_triplanar_sharpness = 5.0
	anti_glare.uv1_scale = Vector3.ONE * 1.4
	_materials.cockpit_anti_glare = anti_glare
	var amber_panel := StandardMaterial3D.new()
	amber_panel.albedo_color = Color(0.80, 0.72, 0.38, 0.22)
	amber_panel.metallic = 0.02
	amber_panel.roughness = 0.32
	amber_panel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber_panel.cull_mode = BaseMaterial3D.CULL_BACK
	_materials.amber_panel = amber_panel
	# Only the Torrent fallback uses the dated hull texture set. Fleet variants
	# inherit the common functional cockpit but immediately replace the exterior;
	# loading Torrent maps for them permanently contaminated the resource cache.
	if _uses_torrent_reconstruction_presentation():
		var hull_albedo := load("res://assets/materials/torrent-hull-albedo-v1.png") as Texture2D
		var hull_normal := load("res://assets/materials/torrent-hull-normal-v1.png") as Texture2D
		var hull_roughness := load("res://assets/materials/torrent-hull-roughness-v1.png") as Texture2D
		for hull_material: StandardMaterial3D in [_materials.ivory, _materials.light]:
			hull_material.albedo_texture = hull_albedo
			hull_material.normal_enabled = hull_normal != null
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.32
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			hull_material.uv1_triplanar = true
			hull_material.uv1_triplanar_sharpness = 4.0
			hull_material.uv1_scale = Vector3.ONE * 0.17
			hull_material.clearcoat_enabled = true
			hull_material.clearcoat = 0.58
			hull_material.clearcoat_roughness = 0.24
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.46, 0.55, 0.22)
	glass.metallic = 0.08
	glass.roughness = 0.09
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Render the outward canopy shell only. With back-face culling, a pilot
	# physically inside the closed mesh does not look through two alpha layers,
	# avoiding the opaque cyan wash that previously buried space and targets.
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	glass.emission_enabled = true
	glass.emission = Color("123e48")
	glass.emission_energy_multiplier = 0.16
	_materials.glass = glass
	var neutral_glass := glass.duplicate(true) as StandardMaterial3D
	neutral_glass.albedo_color = Color(0.62, 0.72, 0.70, 0.13)
	neutral_glass.emission_enabled = false
	_materials.neutral_glass = neutral_glass


func _finish_canopy_motion(open: bool, motion_serial: int) -> void:
	if motion_serial != _canopy_motion_serial or open != _canopy_open:
		return
	_canopy_tween = null
	_sync_imported_canopy_immediately()
	call_deferred("_emit_canopy_motion_finished", open, motion_serial)


func _emit_canopy_motion_finished(open: bool, motion_serial: int) -> void:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or motion_serial != _canopy_motion_serial
		or open != _canopy_open
	):
		return
	canopy_motion_finished.emit(open)


func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.04, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	mesh_instance.mesh = _rounded_box_mesh(size, material)
	parent.add_child(mesh_instance)
	return mesh_instance


func _trapezoid_panel(
		parent: Node3D,
		node_name: String,
		position: Vector3,
		top_width: float,
		bottom_width: float,
		height: float,
		depth: float,
		material: Material
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = _trapezoid_prism_mesh(top_width, bottom_width, height, depth, material)
	instance.set_meta("closed_volume", true)
	parent.add_child(instance)
	return instance


func _trapezoid_prism_mesh(
		top_width: float,
		bottom_width: float,
		height: float,
		depth: float,
		material: Material
	) -> ArrayMesh:
	var half_top := top_width * 0.5
	var half_bottom := bottom_width * 0.5
	var half_height := height * 0.5
	var half_depth := depth * 0.5
	var front := PackedVector3Array([
		Vector3(-half_bottom, -half_height, -half_depth),
		Vector3(half_bottom, -half_height, -half_depth),
		Vector3(half_top, half_height, -half_depth),
		Vector3(-half_top, half_height, -half_depth),
	])
	var back := PackedVector3Array([
		Vector3(-half_bottom, -half_height, half_depth),
		Vector3(half_bottom, -half_height, half_depth),
		Vector3(half_top, half_height, half_depth),
		Vector3(-half_top, half_height, half_depth),
	])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var triangles := PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4,
		1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6,
		3, 0, 4, 3, 4, 7,
	])
	var vertices := PackedVector3Array()
	vertices.append_array(front)
	vertices.append_array(back)
	for index in triangles:
		var vertex := vertices[index]
		tool.set_uv(Vector2(vertex.x / maxf(bottom_width, 0.001) + 0.5, vertex.y / maxf(height, 0.001) + 0.5))
		tool.add_vertex(vertex)
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()


func _rounded_box_mesh(size: Vector3, material: Material) -> ArrayMesh:
	var half := size * 0.5
	var bevel := minf(0.16, minf(size.x, minf(size.y, size.z)) * 0.24)
	bevel = maxf(bevel, 0.004)
	var inner_half := Vector3(
		maxf(0.0, half.x - bevel),
		maxf(0.0, half.y - bevel),
		maxf(0.0, half.z - bevel)
	)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(material)
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var normal_axis: Vector3 = face[0]
		var u_axis: Vector3 = face[1]
		var v_axis: Vector3 = face[2]
		var face_center := Vector3(
			normal_axis.x * half.x,
			normal_axis.y * half.y,
			normal_axis.z * half.z
		)
		var u_extent := absf(u_axis.x) * half.x + absf(u_axis.y) * half.y + absf(u_axis.z) * half.z
		var v_extent := absf(v_axis.x) * half.x + absf(v_axis.y) * half.y + absf(v_axis.z) * half.z
		var u_inner := maxf(0.0, u_extent - bevel)
		var v_inner := maxf(0.0, v_extent - bevel)
		var u_values := PackedFloat32Array([-u_extent, -u_inner, u_inner, u_extent])
		var v_values := PackedFloat32Array([-v_extent, -v_inner, v_inner, v_extent])
		for u_index in u_values.size() - 1:
			for v_index in v_values.size() - 1:
				var points := [
					face_center + u_axis * u_values[u_index] + v_axis * v_values[v_index],
					face_center + u_axis * u_values[u_index + 1] + v_axis * v_values[v_index],
					face_center + u_axis * u_values[u_index + 1] + v_axis * v_values[v_index + 1],
					face_center + u_axis * u_values[u_index] + v_axis * v_values[v_index + 1],
				]
				var u0 := float(u_index) / 3.0
				var u1 := float(u_index + 1) / 3.0
				var v0 := float(v_index) / 3.0
				var v1 := float(v_index + 1) / 3.0
				# Emission order *is* the front-face winding, and it has to agree
				# with the outward normal `_add_rounded_box_vertex` already sets
				# on every vertex. Godot's front face is the one whose vertices
				# run clockwise seen from outside, so on a correct surface
				# `(b - a) x (c - a)` points *opposite* the shading normal —
				# BoxMesh, CylinderMesh and SphereMesh all measure that way.
				#
				# This builder is a copy of the pre-fix `StationSurfaceKit`
				# chamfered box and carried the same defect: emitting 0-1-2 /
				# 0-2-3 against these face axes puts the geometric normal *along*
				# the outward normal on all six faces. Measured against the
				# engine's own primitives, every size scored 108/108 triangles
				# backwards where the fixed kit box scores 0/108. Every box on
				# the Torrent, the Arrow, the Zenith and the Jovian is built here
				# via `_box`, so all of them had their outward faces culled and
				# drew the unlit inside of their own back faces instead — which
				# is what "the materials look inside out" means.
				#
				# `StationSurfaceKit.rounded_box_mesh_with_bevel` and
				# `JovianFreightBerth._add_quad` were fixed the same way in
				# 806d2ff; this copy was missed because that fix never reached
				# `HeroShip`. Vertices, normals, UVs and tangents are untouched;
				# only the order they are emitted in is reversed.
				_add_rounded_box_vertex(surface_tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_box_vertex(surface_tool, points[2], inner_half, bevel, Vector2(u1, v1))
				_add_rounded_box_vertex(surface_tool, points[1], inner_half, bevel, Vector2(u1, v0))
				_add_rounded_box_vertex(surface_tool, points[0], inner_half, bevel, Vector2(u0, v0))
				_add_rounded_box_vertex(surface_tool, points[3], inner_half, bevel, Vector2(u0, v1))
				_add_rounded_box_vertex(surface_tool, points[2], inner_half, bevel, Vector2(u1, v1))
	return surface_tool.commit()


func _add_rounded_box_vertex(
		surface_tool: SurfaceTool,
		point: Vector3,
		inner_half: Vector3,
		bevel: float,
		uv: Vector2
	) -> void:
	var closest := Vector3(
		clampf(point.x, -inner_half.x, inner_half.x),
		clampf(point.y, -inner_half.y, inner_half.y),
		clampf(point.z, -inner_half.z, inner_half.z)
	)
	var offset := point - closest
	var normal := offset.normalized() if offset.length_squared() > 0.000001 else Vector3.UP
	surface_tool.set_normal(normal)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(closest + normal * bevel)


func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	# Chamfered rims at the frozen 32 radial segments. Inherited by every
	# HeroShip subclass, so this is also what puts a highlight on the Jovian's
	# four engine housings, collars and cores. Outer radius and overall height
	# are unchanged; no collision shape reads this mesh.
	#
	# The wall carries no lateral subdivision: see
	# `ShipSurfaceDetail.CYLINDER_WALL_RINGS` for why the four rings Godot's
	# primitive defaults to resolve nothing on a planar wall quad.
	mesh_instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 32, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, material
	)
	parent.add_child(mesh_instance)
	return mesh_instance


func _frustum(
		parent: Node3D,
		node_name: String,
		position: Vector3,
		top_radius: float,
		bottom_radius: float,
		height: float,
		material: Material,
		rotation_degrees_value := Vector3.ZERO,
		cap_top := true,
		cap_bottom := true
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	# Tapered: the kit chamfers only the narrow rim, because the wide rim is the
	# sole carrier of the radial extent and moving it would move the silhouette.
	mesh_instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		top_radius, bottom_radius, height, 32, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, cap_top, cap_bottom, material
	)
	parent.add_child(mesh_instance)
	return mesh_instance


func _torus(
		parent: Node3D,
		node_name: String,
		position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value := Vector3.ZERO,
		scale_value := Vector3.ONE
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	mesh_instance.scale = scale_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 16
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance


func _sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance


func _cylinder_between(
		parent: Node3D,
		node_name: String,
		start: Vector3,
		finish: Vector3,
		radius: float,
		material: Material
	) -> MeshInstance3D:
	var direction := finish - start
	var mesh_instance := _cylinder(parent, node_name, (start + finish) * 0.5, radius, maxf(direction.length(), 0.001), material)
	if direction.length_squared() > 0.000001:
		mesh_instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return mesh_instance


## A smooth multi-section arrowhead loft with a rounded nose toward negative Z.
func _wedge(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, skew := 0.0) -> MeshInstance3D:
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	var half_length := size.z * 0.5
	var nose_x := skew * size.z
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(material)
	const SECTION_COUNT := 24
	const RING_COUNT := 16
	for section_index in SECTION_COUNT:
		var progress := float(section_index) / float(SECTION_COUNT - 1)
		var width_factor := 0.045 + 0.955 * pow(progress, 0.72)
		var height_factor := minf(
			1.0,
			lerpf(0.16, 0.86, progress) + pow(sin(progress * PI), 1.1) * 0.42
		)
		if section_index == SECTION_COUNT - 1:
			height_factor = 0.82
		var ring_width := half_width * width_factor
		var ring_height := half_height * height_factor
		var ring_center_x := lerpf(nose_x, 0.0, progress)
		var ring_z := lerpf(-half_length, half_length, progress)
		# A rounded superellipse keeps the broad readable arrowhead while avoiding
		# the eight-sided faceting of the earlier blockout loft.
		var ring_points := PackedVector2Array()
		for ring_index in RING_COUNT:
			var angle := PI * 0.5 - TAU * float(ring_index) / float(RING_COUNT)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.58)
			var rounded_y := signf(sine) * pow(absf(sine), 0.58)
			ring_points.append(Vector2(ring_width * rounded_x, ring_height * rounded_y))
		for ring_index in RING_COUNT:
			var ring_point := ring_points[ring_index]
			surface_tool.set_uv(Vector2(float(ring_index) / float(RING_COUNT), progress))
			surface_tool.add_vertex(Vector3(ring_center_x + ring_point.x, ring_point.y, ring_z))

	for section_index in SECTION_COUNT - 1:
		for ring_index in RING_COUNT:
			var next_ring := (ring_index + 1) % RING_COUNT
			var front_a := section_index * RING_COUNT + ring_index
			var front_b := section_index * RING_COUNT + next_ring
			var rear_a := (section_index + 1) * RING_COUNT + ring_index
			var rear_b := (section_index + 1) * RING_COUNT + next_ring
			surface_tool.add_index(front_a)
			surface_tool.add_index(rear_a)
			surface_tool.add_index(rear_b)
			surface_tool.add_index(front_a)
			surface_tool.add_index(rear_b)
			surface_tool.add_index(front_b)

	var nose_center_index := SECTION_COUNT * RING_COUNT
	surface_tool.set_uv(Vector2(0.5, 0.0))
	surface_tool.add_vertex(Vector3(nose_x, 0.0, -half_length))
	var rear_center_index := nose_center_index + 1
	surface_tool.set_uv(Vector2(0.5, 1.0))
	surface_tool.add_vertex(Vector3(0.0, 0.0, half_length))
	for ring_index in RING_COUNT:
		var next_ring := (ring_index + 1) % RING_COUNT
		surface_tool.add_index(nose_center_index)
		surface_tool.add_index(ring_index)
		surface_tool.add_index(next_ring)
		var rear_ring := (SECTION_COUNT - 1) * RING_COUNT
		surface_tool.add_index(rear_center_index)
		surface_tool.add_index(rear_ring + next_ring)
		surface_tool.add_index(rear_ring + ring_index)
	surface_tool.generate_normals()
	var array_mesh := surface_tool.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.mesh = array_mesh
	mesh_instance.set_meta("closed_volume", true)
	mesh_instance.set_meta("section_count", SECTION_COUNT)
	mesh_instance.set_meta("ring_count", RING_COUNT)
	parent.add_child(mesh_instance)
	return mesh_instance
