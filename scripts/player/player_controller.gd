class_name PlayerController
extends CharacterBody3D

## Responsive third-person controller for exploring the shipyard on foot.
##
## The scene keeps locomotion, camera orbit, and proximity sensing together so
## callers only need to toggle control when the player boards a ship.

signal interact_requested
signal boarding_completed
signal disembarking_completed

enum EmbodimentState {
	ON_FOOT,
	BOARDING,
	SEATED,
	DISEMBARKING,
}

const BOARDING_ENTRY_FRACTION := 0.42
const BOARDING_STEP_HEIGHT := 0.16
const DISEMBARK_STEP_HEIGHT := 0.12

## Locomotion step-up assist.
##
## `CharacterBody3D` has no step solver: `move_and_slide()` treats any lip the
## capsule cannot roll over as a wall. Measured on this exact capsule the limit
## was 0.14 m — it mounted 0.14 m and failed at 0.15 m, walking or sprinting — so
## every authored lip at or above 0.15 m was a wall rather than a step and whole
## branches of the station became unreachable.
##
## `STEP_UP_MAX_HEIGHT` is chosen from the rig and the architecture, not rounded
## to taste:
##  - it equals the station's own authored stair riser (`AftJunctionStack`
##    raises 4.2 m over 14 risers = 0.300 m), so an authored stair can never be
##    a wall again;
##  - it is 58% of this avatar's measured knee-joint height (0.516 m above the
##    ground-contact plane on a 1.945 m standing suit), i.e. an unassisted step
##    rather than a climb;
##  - it is below the 0.38 m capsule radius, so the body is only ever placed
##    where the capsule's lower sphere could have rolled unaided;
##  - it is deliberately below the station's 0.40 m raised-pod slab, so a room a
##    whole slab above its approach still has to author a real threshold instead
##    of relying on the assist to paper over it.
const STEP_UP_MAX_HEIGHT := 0.30
## Minimum vertical headroom that must exist before a step is even attempted.
const STEP_UP_MIN_CLEARANCE := 0.02
## Minimum tangent progress a step must buy. Prevents lifting the body without
## actually getting it anywhere.
const STEP_UP_MIN_ADVANCE := 0.01

## Cabin containment tuning. The inset keeps the clamped body a hand's width
## inside the envelope so the very next tick does not immediately re-violate it,
## and the recall distance is the point past which a nudge is not credible any
## more and the occupant is returned bodily to the standing pose.
const CABIN_CONTAINMENT_INSET := 0.12
const CABIN_HARD_RECALL_DISTANCE := 1.5

const MOTION_RESET := &"RESET"
const MOTION_IDLE := &"idle"
const MOTION_WALK := &"walk"
const MOTION_RUN := &"run"
const MOTION_JUMP := &"jump"
const MOTION_AIRBORNE := &"airborne"
const MOTION_BOARDING := &"boarding"
const MOTION_SEATED_CONTROL := &"seated_control"
const MOTION_DISEMBARK_RECOVERY := &"disembark_recovery"
const MOTION_BLEND_TIME := 0.12
const TRANSITION_MOTION_BLEND_TIME := 0.16
const PILOT_INTEGRITY_PROBE_INTERVAL := 0.2
const BOARDING_CLIP_LENGTH := 1.1
const DISEMBARK_CLIP_LENGTH := 0.9
const PILOT_MOTION_VERSION := &"blender_skinned_motion_v2"
## The imported Blender suit's semantic face (visor, chest plate and status
## lights) is +Z after glTF import. Player traversal and every native seat frame
## use -Z as forward, so the visible imported presentation needs one mount-only
## half turn. This never changes input, CharacterBody velocity, or clip playback.
const IMPORTED_PILOT_FACING_YAW_OFFSET := PI
const PILOT_MOTION_CLIPS: Array[StringName] = [
	MOTION_RESET,
	MOTION_IDLE,
	MOTION_WALK,
	MOTION_RUN,
	MOTION_JUMP,
	MOTION_AIRBORNE,
	MOTION_BOARDING,
	MOTION_SEATED_CONTROL,
	MOTION_DISEMBARK_RECOVERY,
]
const LEGACY_MOTION_TRACK_PATHS: Array[NodePath] = [
	NodePath("VisualRoot:position:y"),
	NodePath("VisualRoot/BodyPivot:rotation:x"),
	NodePath("VisualRoot/BodyPivot:rotation:z"),
	NodePath("VisualRoot/BodyPivot/LeftArm:rotation"),
	NodePath("VisualRoot/BodyPivot/RightArm:rotation"),
	NodePath("VisualRoot/BodyPivot/LeftLeg:rotation"),
	NodePath("VisualRoot/BodyPivot/RightLeg:rotation"),
]
const LEGACY_MOTION_LIBRARY_SHA256 := "4af3e12abb02e2dca75ac441c782c2530d7090fe816d2f9d61e30596568e8642"

const PILOT_NAVY := Color("071922")
const PILOT_NAVY_LIGHT := Color("102d39")
const PILOT_CYAN_TEXTILE := Color("185665")
const PILOT_CYAN_ARMOR := Color("3f7882")
const PILOT_CERAMIC := Color("91a8a7")
const PILOT_RUBBER := Color("02090d")
const PILOT_VISOR := Color("011017")
const PILOT_KETH_CYAN := Color("42dce2")
const PILOT_AMBER := Color("e9aa3a")
const PILOT_PRESENTATION_VERSION := &"realistic_stylised_v2"

@export_category("Movement")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 5.8
@export_range(0.1, 30.0, 0.1) var sprint_speed: float = 9.2
@export_range(1.0, 80.0, 0.5) var ground_acceleration: float = 34.0
@export_range(1.0, 80.0, 0.5) var ground_deceleration: float = 42.0
@export_range(1.0, 40.0, 0.5) var air_acceleration: float = 9.0
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 7.4
@export_range(0.1, 4.0, 0.05) var gravity_multiplier: float = 1.0
@export_range(1.0, 100.0, 1.0) var terminal_velocity: float = 42.0
@export_range(1.0, 30.0, 0.5) var facing_speed: float = 14.0

@export_category("Camera")
@export_range(0.0005, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025
@export var invert_mouse_y: bool = false
@export_range(1.0, 12.0, 0.1) var minimum_camera_distance: float = 2.4
@export_range(2.0, 18.0, 0.1) var maximum_camera_distance: float = 8.0
## Ceiling applied to the chase boom while the body is confined to a craft's
## cabin. The station is an exterior the 5.2 m default boom was authored for; a
## pressurised cabin is not. The forward flight deck is 3.25 m long and the
## through-lane 2.8 m wide, so the authored boom cannot fit behind the pilot at
## all and every frame of the walk resolves by retraction or by clipping. The
## SpringArm sweep handles the surfaces that carry collision; this keeps the boom
## short enough that the retraction is small and continuous rather than a snap
## from 5.2 m to nothing at every bulkhead, and keeps the camera out of the
## interior dressing that is drawn but not collided.
@export_range(1.0, 8.0, 0.1) var interior_camera_distance: float = 2.3
@export_range(0.1, 3.0, 0.05) var camera_zoom_step: float = 0.65
@export_range(1.0, 30.0, 0.5) var camera_zoom_speed: float = 12.0
@export_range(-85.0, 0.0, 1.0) var minimum_pitch_degrees: float = -52.0
@export_range(0.0, 85.0, 1.0) var maximum_pitch_degrees: float = 64.0

@onready var _visual_root: Node3D = %VisualRoot
@onready var _body_pivot: Node3D = %BodyPivot
@onready var _left_arm: Node3D = %LeftArm
@onready var _right_arm: Node3D = %RightArm
@onready var _left_leg: Node3D = %LeftLeg
@onready var _right_leg: Node3D = %RightLeg
@onready var _legacy_motion_animation_player: AnimationPlayer = %MotionAnimationPlayer
@onready var _pilot_presentation: PilotSkinnedPresentation = %PilotSkinnedPresentation
@onready var _player_collision: CollisionShape3D = $PlayerCollision
@onready var _camera_yaw: Node3D = %CameraYaw
@onready var _camera_pitch: Node3D = %CameraPitch
@onready var _spring_arm: SpringArm3D = %SpringArm3D
@onready var _camera: Camera3D = %PlayerCamera
@onready var _interaction_origin: Marker3D = %InteractionOrigin
@onready var _interaction_area: Area3D = %InteractionArea

var _control_enabled: bool = true
var _camera_active: bool = true
## The distance the boom eases toward. This is the *requested* distance already
## reduced by whatever ceiling the current space imposes; the request itself is
## kept separately so a player who zoomed out before stepping into a cabin gets
## their own framing back when they step out of it.
var _target_camera_distance: float = 5.2
var _requested_camera_distance: float = 5.2
var _camera_distance_ceiling: float = 8.0
var _pitch: float = deg_to_rad(-10.0)
## Travel-facing yaw in Player-local space, before the active presentation's
## visual-axis correction is applied.
var _target_body_yaw: float = 0.0
var _motion_state: StringName = &""

var _embodiment_state := EmbodimentState.ON_FOOT
var _seat_anchor: Node3D
var _transition_start := Transform3D.IDENTITY
var _transition_entry := Transform3D.IDENTITY
var _transition_target := Transform3D.IDENTITY
## Optional live frame the current seat transition is expressed in. World-space
## endpoints are correct only while the craft holds still; a transition begun or
## ended under way must be replayed against the craft that owns it, or the body
## interpolates towards a place the craft has already left.
var _transition_frame: Node3D
var _transition_start_local := Transform3D.IDENTITY
var _transition_entry_local := Transform3D.IDENTITY
var _transition_target_local := Transform3D.IDENTITY
var _transition_elapsed := 0.0
var _transition_duration := 0.0
## Live cabin containment. While set, this body may not leave `_cabin_bounds`
## expressed in `_cabin_frame` local space, which is what makes leaving the
## pilot seat in open space a recoverable act rather than a soft-lock.
var _cabin_frame: Node3D
var _cabin_bounds := AABB()
var _cabin_recall_local := Transform3D.IDENTITY
var _cabin_clamp_count := 0
var _cabin_recall_count := 0
var _standing_collision_layer := 0
var _standing_collision_mask := 0
var _standing_interaction_mask := 0
var _standing_physics_priority := 0
var _pilot_materials: Dictionary = {}
var _motion_animation_player: AnimationPlayer
var _using_imported_pilot_presentation := false
var _motion_playback_rate := 1.0
var _legacy_motion_library_backup: AnimationLibrary
var _legacy_motion_pristine_library: AnimationLibrary
var _legacy_motion_library_id := 0
var _legacy_motion_animation_ids: Dictionary = {}
var _legacy_motion_animation_contract: Dictionary = {}
var _legacy_motion_node_contract: Dictionary = {}
var _legacy_motion_player_contract: Dictionary = {}
var _imported_presentation_rejected := false
var _ensuring_motion_authority := false
var _motion_authority_contaminated := false
var _pilot_integrity_probe_elapsed := 0.0
## Horizontal reach of the step-up probe: far enough to place the capsule axis
## over the surface it is stepping onto. Derived from the live capsule so a
## future collision-shape change cannot silently stale it.
var _step_probe_reach := 0.40
var _imported_skeleton_pose_contract: Array[Dictionary] = []


func _ready() -> void:
	_initialize_legacy_motion_authority()
	_activate_skinned_pilot_presentation()
	_step_probe_reach = _resolve_step_probe_reach()
	_standing_collision_layer = collision_layer
	_standing_collision_mask = collision_mask
	_standing_interaction_mask = _interaction_area.collision_mask
	_standing_physics_priority = process_physics_priority
	_set_motion_state(MOTION_IDLE, 0.0, 1.0, true, true)
	_camera_distance_ceiling = maximum_camera_distance
	_requested_camera_distance = clampf(
		_spring_arm.spring_length,
		minimum_camera_distance,
		maximum_camera_distance
	)
	_apply_camera_distance_ceiling()
	_pitch = clampf(
		_camera_pitch.rotation.x,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	_camera_pitch.rotation.x = _pitch
	_camera.current = _camera_active
	if _control_enabled and _camera_active and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_ensure_motion_authority(_advance_pilot_integrity_probe(delta))
	if _embodiment_state != EmbodimentState.ON_FOOT:
		_update_embodiment(delta)
		_advance_motion_animation(delta)
		return

	var desired_direction := Vector3.ZERO
	var is_sprinting := false

	if _control_enabled:
		var input_vector := Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_back"
		)
		desired_direction = _camera_relative_direction(input_vector)
		is_sprinting = Input.is_action_pressed("sprint_boost") and not desired_direction.is_zero_approx()
		_update_horizontal_velocity(desired_direction, is_sprinting, delta)

		if Input.is_action_just_pressed("jump") and is_on_floor():
			var movement_up := _get_movement_up_direction()
			var existing_up_speed := velocity.dot(movement_up)
			if existing_up_speed < 0.0:
				velocity -= movement_up * existing_up_speed
			velocity += movement_up * jump_velocity
		if Input.is_action_just_pressed("interact"):
			interact_requested.emit()
	else:
		_decelerate_horizontal_velocity(delta)

	_apply_gravity(delta)
	var pre_move_transform := global_transform
	var pre_move_velocity := velocity
	move_and_slide()
	_resolve_step_up(pre_move_transform, pre_move_velocity, delta)
	_resolve_cabin_containment()
	_update_facing(desired_direction, delta)
	_update_authored_locomotion(is_sprinting)
	_advance_motion_animation(delta)


func _process(delta: float) -> void:
	_spring_arm.spring_length = lerpf(
		_spring_arm.spring_length,
		_target_camera_distance,
		1.0 - exp(-camera_zoom_speed * delta)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _camera_active or not _control_enabled:
		return

	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_target_camera_distance(_target_camera_distance - camera_zoom_step)
				get_viewport().set_input_as_handled()
				return
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_target_camera_distance(_target_camera_distance + camera_zoom_step)
				get_viewport().set_input_as_handled()
				return
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		_camera_yaw.rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
		_camera_yaw.rotation.y = wrapf(_camera_yaw.rotation.y, -PI, PI)
		var pitch_direction := 1.0 if invert_mouse_y else -1.0
		_pitch = clampf(
			_pitch + mouse_motion.relative.y * mouse_sensitivity * pitch_direction,
			deg_to_rad(minimum_pitch_degrees),
			deg_to_rad(maximum_pitch_degrees)
		)
		_camera_pitch.rotation.x = _pitch
		get_viewport().set_input_as_handled()


## Enables or suspends on-foot movement and interaction input.
func set_control_enabled(enabled: bool) -> void:
	if enabled and _embodiment_state != EmbodimentState.ON_FOOT:
		return
	_control_enabled = enabled
	if not enabled:
		# Stop only deck-tangent locomotion. Zeroing world X/Z corrupts the local
		# vertical component aboard a pitched or rolled moving interior.
		var movement_up := _get_movement_up_direction()
		velocity = movement_up * velocity.dot(movement_up)
	if enabled and _camera_active and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Makes this controller's camera current, or relinquishes it to another rig.
func set_camera_active(active: bool) -> void:
	_camera_active = active
	_camera.current = active
	if active and _control_enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Moves the player to an exact world-space transform and clears residual motion.
func teleport_to(target: Transform3D) -> void:
	global_transform = target
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_camera_yaw.rotation.y = 0.0
	_reset_body_facing()
	if _embodiment_state == EmbodimentState.ON_FOOT:
		_set_motion_state(MOTION_IDLE, 0.0, 1.0, true, true)


## Moves the visible character through a ship's entry point and into its pilot
## seat. The seat anchor is a live world-space Player-root frame (local forward
## is -Z), allowing the same character model to remain aboard a moving craft.
##
## `reference_frame` binds the whole transition to a live craft. Supply it
## whenever the craft can move during the transition — the endpoints are then
## rebased every tick, and the traversal arc is lifted along the craft's up
## rather than the world's.
func begin_boarding(
		entry_transform: Transform3D,
		seat_anchor: Node3D,
		duration: float = 1.1,
		reference_frame: Node3D = null
	) -> bool:
	if _embodiment_state != EmbodimentState.ON_FOOT or not is_instance_valid(seat_anchor):
		return false

	_control_enabled = false
	velocity = Vector3.ZERO
	# Locomotion turns the presentation pivot independently of the physical
	# CharacterBody. A boarding transition owns the root's world-space facing,
	# so carrying that last strafe yaw into its authored clips would leave the
	# pilot sitting sideways relative to the live seat anchor.
	_reset_body_facing()
	_set_embodied_collision_enabled(false)
	_seat_anchor = seat_anchor
	_process_after_seat_hierarchy(seat_anchor)
	_bind_transition_frame(reference_frame)
	_transition_start = _clean_transform(global_transform)
	_transition_entry = _clean_transform(entry_transform)
	_transition_start_local = _to_transition_local(_transition_start)
	_transition_entry_local = _to_transition_local(_transition_entry)
	_transition_elapsed = 0.0
	_transition_duration = maxf(0.0, duration)
	_embodiment_state = EmbodimentState.BOARDING
	if not is_zero_approx(_transition_duration):
		_set_motion_state(
			MOTION_BOARDING,
			TRANSITION_MOTION_BLEND_TIME,
			BOARDING_CLIP_LENGTH / _transition_duration,
			true,
			true
		)

	if is_zero_approx(_transition_duration):
		_complete_boarding()
	return true


## Moves the visible character from the pilot seat to a safe exit pose.
## Collision is restored before disembarking_completed is emitted; locomotion
## remains disabled so the gameplay coordinator can decide when controls resume.
##
## Pass `reference_frame` when the exit pose belongs to a craft that may be
## moving — the exit is then held on that craft for the whole transition instead
## of being a world point the craft flies away from.
func begin_disembark(
		exit_transform: Transform3D,
		duration: float = 0.9,
		reference_frame: Node3D = null
	) -> bool:
	if _embodiment_state != EmbodimentState.SEATED:
		return false

	_control_enabled = false
	velocity = Vector3.ZERO
	_reset_body_facing()
	_bind_transition_frame(reference_frame)
	_transition_start = _clean_transform(global_transform)
	_transition_target = _clean_transform(exit_transform)
	_transition_start_local = _to_transition_local(_transition_start)
	_transition_target_local = _to_transition_local(_transition_target)
	_transition_elapsed = 0.0
	_transition_duration = maxf(0.0, duration)
	_embodiment_state = EmbodimentState.DISEMBARKING
	if not is_zero_approx(_transition_duration):
		_set_motion_state(
			MOTION_DISEMBARK_RECOVERY,
			TRANSITION_MOTION_BLEND_TIME,
			DISEMBARK_CLIP_LENGTH / _transition_duration,
			true,
			true
		)

	if is_zero_approx(_transition_duration):
		_complete_disembark()
	return true


## Cancels any in-progress seat transition and restores one coherent physical
## on-foot body at `target`. This is reserved for destructive lifecycle recovery
## (for example a craft lost while its canopy or boarding animation is active).
## The completion signal for the interrupted transition is emitted deferred so
## an awaiting gameplay coroutine can observe its own invalidation token and
## return without continuing to mutate the recovered player.
func force_recovery_to_on_foot(target: Transform3D) -> void:
	var interrupted_state := _embodiment_state
	_control_enabled = false
	# Destructive recovery is world-space by definition: the craft that owned the
	# frame and the cabin envelope is the thing that was just lost.
	clear_cabin_containment()
	_transition_frame = null
	_transition_start = _clean_transform(target)
	_transition_entry = _transition_start
	_transition_target = _transition_start
	_transition_elapsed = 0.0
	_transition_duration = 0.0
	global_transform = _transition_start
	velocity = Vector3.ZERO
	_seat_anchor = null
	process_physics_priority = _standing_physics_priority
	_camera_yaw.rotation.y = 0.0
	_reset_body_facing()
	_embodiment_state = EmbodimentState.ON_FOOT
	_set_motion_state(MOTION_IDLE, 0.0, 1.0, true, true)
	_set_embodied_collision_enabled(true)
	reset_physics_interpolation()
	if interrupted_state == EmbodimentState.BOARDING:
		boarding_completed.emit.call_deferred()
	elif interrupted_state == EmbodimentState.DISEMBARKING:
		disembarking_completed.emit.call_deferred()


## True only after the boarding movement has reached the live pilot anchor.
func is_seated() -> bool:
	return _embodiment_state == EmbodimentState.SEATED


func get_camera() -> Camera3D:
	return _camera


func set_camera_fov(field_of_view: float) -> void:
	if _camera != null:
		_camera.fov = clampf(field_of_view, 55.0, 110.0)


func get_camera_fov() -> float:
	return _camera.fov if _camera != null else 72.0


## World-space point used by doors, seats, and other proximity interactions.
func get_interaction_origin() -> Vector3:
	return _interaction_origin.global_position


## Nearby layer-4 bodies and areas, ordered by distance from the player.
func get_nearby_interactables() -> Array[Node3D]:
	var nearby: Array[Node3D] = []
	if _embodiment_state != EmbodimentState.ON_FOOT:
		return nearby
	for body in _interaction_area.get_overlapping_bodies():
		if body is Node3D and body != self:
			nearby.append(body as Node3D)
	for area in _interaction_area.get_overlapping_areas():
		if area is Node3D and area != _interaction_area:
			nearby.append(area as Node3D)
	nearby.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return get_interaction_origin().distance_squared_to(a.global_position) \
			< get_interaction_origin().distance_squared_to(b.global_position)
	)
	return nearby


func get_interaction_direction() -> Vector3:
	return -_camera.global_basis.z.normalized()


func is_control_enabled() -> bool:
	return _control_enabled


## The scene-authored player that owns every visible locomotion and embodiment
## pose. It runs in manual/physics mode so pausing this controller also freezes
## the suit deterministically instead of letting a child tick independently.
func get_motion_animation_player() -> AnimationPlayer:
	return (
		_motion_animation_player
		if _motion_animation_player != null and is_instance_valid(_motion_animation_player)
		else null
	)


func get_authored_motion_state() -> StringName:
	return _motion_state


## Evidence-oriented motion metadata for the persistent Blender-authored,
## imported skeleton clips. CharacterBody traversal remains native authority.
func get_pilot_motion_audit() -> Dictionary:
	var live_presentation: PilotSkinnedPresentation = (
		_pilot_presentation
		if _pilot_presentation != null and is_instance_valid(_pilot_presentation)
		else null
	)
	var asset_audit := (
		live_presentation.get_asset_audit_report()
		if live_presentation != null else {}
	)
	# Reading an evidence audit is itself an explicit integrity boundary. Do not
	# leave a presentation selected after its full immutable contract has just
	# failed, even if its cheap per-tick structure still looks plausible.
	if not bool(asset_audit.get("valid", false)) and _using_imported_pilot_presentation:
		_imported_presentation_rejected = true
		_select_fallback_motion_authority()
	var expected_player := (
		live_presentation.get_animation_player()
		if live_presentation != null else null
	)
	var live_player: AnimationPlayer = (
		_motion_animation_player
		if _motion_animation_player != null and is_instance_valid(_motion_animation_player)
		else null
	)
	var driver_is_imported := live_player != null and live_player == expected_player
	var driver_active := driver_is_imported and live_player.active
	var driver_speed_matches := (
		driver_is_imported
		and is_finite(live_player.speed_scale)
		and live_player.speed_scale > 0.0
		and is_equal_approx(live_player.speed_scale, _motion_playback_rate)
	)
	var assigned_state_matches := driver_is_imported and (
		_motion_state.is_empty() or live_player.assigned_animation == _motion_state
	)
	var driver_completed_state := false
	if assigned_state_matches and not _motion_state.is_empty() and not live_player.is_playing():
		var assigned_clip := live_player.get_animation(_motion_state)
		driver_completed_state = (
			assigned_clip != null
			and assigned_clip.loop_mode == Animation.LOOP_NONE
			and live_player.current_animation_position >= assigned_clip.length - 0.002
		)
	var driver_matches_cached_state := (
		driver_active
		and driver_speed_matches
		and assigned_state_matches
		and (
			_motion_state.is_empty()
			or live_player.is_playing()
			or driver_completed_state
		)
	)
	var library := live_player.get_animation_library(&"") if driver_is_imported else null
	var animation_roster_exact := _motion_animation_player_roster_is_exact()
	var legacy_library_trusted := _legacy_motion_library_is_trusted()
	var legacy_inert := (
		_legacy_motion_animation_player != null
		and is_instance_valid(_legacy_motion_animation_player)
		and not _legacy_motion_animation_player.active
		and not _legacy_motion_animation_player.is_playing()
	)
	return {
		"version": PILOT_MOTION_VERSION,
		"authorship": &"original_script_assisted_blender",
		"motion_capture": false,
		"runtime_clip_generation": false,
		"manual_physics_sampling": driver_is_imported and live_player.callback_mode_process
			== AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"driver_is_imported": driver_is_imported,
		"driver_active": driver_active,
		"driver_speed_matches": driver_speed_matches,
		"expected_playback_rate": _motion_playback_rate,
		"driver_matches_cached_state": driver_matches_cached_state,
		"animation_player_roster_exact": animation_roster_exact,
		"legacy_library_trusted": legacy_library_trusted,
		"legacy_library_signature": _legacy_motion_library_signature(
			_legacy_motion_library_backup
		),
		"legacy_driver_inert": legacy_inert,
		"fallback_active": not _using_imported_pilot_presentation,
		"imported_presentation_rejected": _imported_presentation_rejected,
		"motion_authority_contaminated": _motion_authority_contaminated,
		"current_state": _motion_state,
		"clip_count": library.get_animation_list().size() if library != null else 0,
		"has_reset": library != null and library.has_animation(MOTION_RESET),
		"has_idle": library != null and library.has_animation(MOTION_IDLE),
		"has_walk": library != null and library.has_animation(MOTION_WALK),
		"has_run": library != null and library.has_animation(MOTION_RUN),
		"has_jump": library != null and library.has_animation(MOTION_JUMP),
		"has_airborne": library != null and library.has_animation(MOTION_AIRBORNE),
		"has_boarding": library != null and library.has_animation(MOTION_BOARDING),
		"has_seated_control": library != null
			and library.has_animation(MOTION_SEATED_CONTROL),
		"has_disembark_recovery": library != null
			and library.has_animation(MOTION_DISEMBARK_RECOVERY),
		"imported_track_count": int(asset_audit.get("imported_track_count", 0)),
		"bone_count": int(asset_audit.get("bone_count", 0)),
		"asset_valid": bool(asset_audit.get("valid", false)),
		"valid": (
			bool(asset_audit.get("valid", false))
			and _using_imported_pilot_presentation
			and driver_matches_cached_state
			and animation_roster_exact
			and legacy_library_trusted
			and legacy_inert
		),
	}


## Stable access to the imported Blender pressure-suit presentation.
func get_pilot_visual_root() -> Node3D:
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return null
	var result := _pilot_presentation.get_visual_root()
	return result if result != null and is_instance_valid(result) else null


## Semantic world-space direction in which the visible pilot is looking. The
## imported suit publishes its authored +Z face; the legacy fallback is -Z.
func get_pilot_visual_forward_direction() -> Vector3:
	if (
		_using_imported_pilot_presentation
		and _pilot_presentation != null
		and is_instance_valid(_pilot_presentation)
	):
		return _pilot_presentation.get_visual_forward_direction()
	if _body_pivot != null and is_instance_valid(_body_pivot):
		return -_body_pivot.global_basis.z.normalized()
	return Vector3.ZERO


## Current player-local bounds of the visible suit. Because these are sampled
## from the live rig they can be used to audit both the standing and seated
## silhouettes without assuming a particular ship or seat transform.
func get_pilot_visual_bounds() -> AABB:
	var pilot_root := get_pilot_visual_root()
	if pilot_root == null or not is_inside_tree():
		return AABB()
	var inverse_player := global_transform.affine_inverse()
	var bounds := AABB()
	var has_bounds := false
	for part in get_pilot_visual_parts():
		if not part.visible or part.mesh == null:
			continue
		var part_bounds := _transformed_aabb(
			part.get_aabb(),
			inverse_player * part.global_transform
		)
		bounds = bounds.merge(part_bounds) if has_bounds else part_bounds
		has_bounds = true
	return bounds


func get_pilot_visual_parts() -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	var pilot_root := get_pilot_visual_root()
	if pilot_root == null:
		return parts
	for candidate in pilot_root.find_children("*", "MeshInstance3D", true, false):
		var part := candidate as MeshInstance3D
		if part != null:
			parts.append(part)
	return parts


## Runtime presentation contract used by visual regression tests and capture
## tooling. Measurements come from the generated meshes rather than duplicated
## nominal constants, so future proportion changes cannot silently stale it.
func get_pilot_presentation_audit() -> Dictionary:
	var pilot_root := get_pilot_visual_root()
	var live_presentation: PilotSkinnedPresentation = (
		_pilot_presentation
		if _pilot_presentation != null and is_instance_valid(_pilot_presentation)
		else null
	)
	var asset_audit := (
		live_presentation.get_asset_audit_report()
		if live_presentation != null else {}
	)
	if not bool(asset_audit.get("valid", false)) and _using_imported_pilot_presentation:
		_imported_presentation_rejected = true
		_select_fallback_motion_authority()
	var errors := PackedStringArray(asset_audit.get("errors", PackedStringArray()))
	var live_visual_root: Node3D = (
		_visual_root if _visual_root != null and is_instance_valid(_visual_root) else null
	)
	var live_body_pivot: Node3D = (
		_body_pivot if _body_pivot != null and is_instance_valid(_body_pivot) else null
	)
	if (
		live_visual_root == null
		or live_visual_root.get_parent() != self
		or live_visual_root.top_level
		or not live_visual_root.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		errors.append("Player VisualRoot mounting authority drifted")
	if live_body_pivot == null or live_visual_root == null:
		errors.append("Player BodyPivot mounting authority is missing")
	else:
		var body_rotation := live_body_pivot.rotation
		if (
			live_body_pivot.get_parent() != live_visual_root
			or live_body_pivot.top_level
			or not live_body_pivot.position.is_zero_approx()
			or not live_body_pivot.scale.is_equal_approx(Vector3.ONE)
			or not body_rotation.is_finite()
			or not is_zero_approx(body_rotation.x)
			or not is_zero_approx(body_rotation.z)
		):
			errors.append("Player BodyPivot mounting authority drifted")
	if (
		live_presentation == null
		or live_body_pivot == null
		or live_presentation.get_parent() != live_body_pivot
		or live_presentation.top_level
		or not live_presentation.transform.is_equal_approx(Transform3D.IDENTITY)
		or not live_presentation.visible
	):
		errors.append("PilotSkinnedPresentation mounting authority drifted")
	var expected_player := (
		live_presentation.get_animation_player()
		if live_presentation != null else null
	)
	if (
		expected_player == null
		or not is_instance_valid(expected_player)
		or _motion_animation_player == null
		or not is_instance_valid(_motion_animation_player)
		or _motion_animation_player != expected_player
		or not _using_imported_pilot_presentation
	):
		errors.append("Player motion authority is not the imported pilot AnimationPlayer")
	if not _motion_animation_player_roster_is_exact():
		errors.append("Player AnimationPlayer authority roster drifted")
	if not _legacy_motion_library_is_trusted():
		errors.append("Player legacy recovery motion library drifted")
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
		or (
			is_instance_valid(_legacy_motion_animation_player)
			and (
				_legacy_motion_animation_player.active
				or _legacy_motion_animation_player.is_playing()
			)
		)
	):
		errors.append("Player legacy recovery motion driver is not inert")
	var visual_bounds: AABB = asset_audit.get("bind_bounds", AABB())
	var report := asset_audit.duplicate(true)
	report["errors"] = errors
	report["valid"] = bool(asset_audit.get("valid", false)) and pilot_root != null and errors.is_empty()
	report["version"] = &"blender_skinned_v2"
	report["style"] = &"realistic_stylised"
	report["visible_bounds"] = visual_bounds
	report["visible_height_m"] = visual_bounds.size.y
	report["ground_contact_y"] = visual_bounds.position.y
	report["visible_part_count"] = get_pilot_visual_parts().size()
	report["embodiment_state"] = _embodiment_state
	report["motion_version"] = PILOT_MOTION_VERSION
	report["motion_authorship"] = &"original_script_assisted_blender"
	report["motion_capture"] = false
	report["motion_state"] = _motion_state
	report["visual_facing_yaw_offset_rad"] = _get_visual_facing_yaw_offset()
	report["visual_forward_direction"] = get_pilot_visual_forward_direction()
	report["animation_player_roster_exact"] = _motion_animation_player_roster_is_exact()
	report["legacy_library_trusted"] = _legacy_motion_library_is_trusted()
	report["fallback_active"] = not _using_imported_pilot_presentation
	report["imported_presentation_rejected"] = _imported_presentation_rejected
	return report


func get_pilot_material(material_role: StringName) -> StandardMaterial3D:
	return _pilot_materials.get(String(material_role)) as StandardMaterial3D


func _update_embodiment(delta: float) -> void:
	velocity = Vector3.ZERO
	match _embodiment_state:
		EmbodimentState.BOARDING:
			_update_boarding(delta)
		EmbodimentState.SEATED:
			_follow_seat_anchor()
		EmbodimentState.DISEMBARKING:
			_update_disembarking(delta)


func _update_boarding(delta: float) -> void:
	if not is_instance_valid(_seat_anchor):
		# Retain a stable, collision-free pose if the ship disappears. The
		# gameplay owner can recover the player with begin_disembark once it has
		# selected a safe exit transform.
		_embodiment_state = EmbodimentState.SEATED
		_set_motion_state(MOTION_SEATED_CONTROL, 0.0, 1.0, true, true)
		boarding_completed.emit.call_deferred()
		return

	_transition_elapsed = minf(_transition_elapsed + delta, _transition_duration)
	var progress := clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)

	var traversal_up := _get_transition_up_direction()
	if progress <= BOARDING_ENTRY_FRACTION:
		var entry_progress := _smoothstep(progress / BOARDING_ENTRY_FRACTION)
		global_transform = _interpolate_transform(
			_resolve_transition_transform(_transition_start, _transition_start_local),
			_resolve_transition_transform(_transition_entry, _transition_entry_local),
			entry_progress
		)
		global_position += traversal_up * _transition_step_height(
			entry_progress,
			BOARDING_STEP_HEIGHT
		)
	else:
		var seat_progress := _smoothstep(
			(progress - BOARDING_ENTRY_FRACTION) / (1.0 - BOARDING_ENTRY_FRACTION)
		)
		global_transform = _interpolate_transform(
			_resolve_transition_transform(_transition_entry, _transition_entry_local),
			_get_live_seat_transform(),
			seat_progress
		)
		global_position += traversal_up * _transition_step_height(
			seat_progress,
			BOARDING_STEP_HEIGHT
		)

	if progress >= 1.0:
		_complete_boarding()


func _complete_boarding() -> void:
	if is_instance_valid(_seat_anchor):
		global_transform = _get_live_seat_transform()
	_transition_frame = null
	velocity = Vector3.ZERO
	_reset_body_facing()
	_embodiment_state = EmbodimentState.SEATED
	_set_motion_state(MOTION_SEATED_CONTROL, 0.0, 1.0, true, true)
	reset_physics_interpolation()
	# Deferred completion keeps the zero-duration path await-safe and gives the
	# final transform the same observable ordering as an animated transition.
	boarding_completed.emit.call_deferred()


func _follow_seat_anchor() -> void:
	if is_instance_valid(_seat_anchor):
		global_transform = _get_live_seat_transform()
	velocity = Vector3.ZERO


func _update_disembarking(delta: float) -> void:
	_transition_elapsed = minf(_transition_elapsed + delta, _transition_duration)
	var progress := clampf(_transition_elapsed / _transition_duration, 0.0, 1.0)
	var eased_progress := _smoothstep(progress)
	global_transform = _interpolate_transform(
		_resolve_transition_transform(_transition_start, _transition_start_local),
		_resolve_transition_transform(_transition_target, _transition_target_local),
		eased_progress
	)
	global_position += _get_transition_up_direction() * _transition_step_height(
		eased_progress,
		DISEMBARK_STEP_HEIGHT
	)

	if progress >= 1.0:
		_complete_disembark()


func _complete_disembark() -> void:
	global_transform = _resolve_transition_transform(
		_transition_target,
		_transition_target_local
	)
	_transition_frame = null
	velocity = Vector3.ZERO
	_seat_anchor = null
	process_physics_priority = _standing_physics_priority
	_reset_body_facing()
	_embodiment_state = EmbodimentState.ON_FOOT
	_set_motion_state(MOTION_IDLE, 0.0, 1.0, true, true)
	_set_embodied_collision_enabled(true)
	reset_physics_interpolation()
	# CollisionShape3D's deferred enable is queued first, so observers resume
	# locomotion only after the player is collision-ready at the exit point.
	disembarking_completed.emit.call_deferred()


func _set_embodied_collision_enabled(enabled: bool) -> void:
	if enabled:
		collision_layer = _standing_collision_layer
		collision_mask = _standing_collision_mask
		_interaction_area.collision_mask = _standing_interaction_mask
	else:
		collision_layer = 0
		collision_mask = 0
		_interaction_area.collision_mask = 0
	_player_collision.set_deferred(&"disabled", not enabled)


func _get_live_seat_transform() -> Transform3D:
	return _clean_transform(_seat_anchor.global_transform)


func _process_after_seat_hierarchy(seat_anchor: Node3D) -> void:
	var latest_priority := _standing_physics_priority
	var ancestor: Node = seat_anchor
	while ancestor != null:
		latest_priority = maxi(latest_priority, ancestor.process_physics_priority + 1)
		ancestor = ancestor.get_parent()
	process_physics_priority = latest_priority


func _reset_body_facing() -> void:
	_target_body_yaw = 0.0
	_apply_body_facing_rotation()


func _get_visual_facing_yaw_offset() -> float:
	return (
		IMPORTED_PILOT_FACING_YAW_OFFSET
		if _using_imported_pilot_presentation else 0.0
	)


func _get_body_pivot_target_yaw() -> float:
	return wrapf(_target_body_yaw + _get_visual_facing_yaw_offset(), -PI, PI)


func _apply_body_facing_rotation() -> void:
	if _body_pivot == null or not is_instance_valid(_body_pivot):
		return
	if not is_finite(_target_body_yaw):
		_target_body_yaw = 0.0
	_body_pivot.rotation = Vector3(0.0, _get_body_pivot_target_yaw(), 0.0)


func _bind_transition_frame(reference_frame: Node3D) -> void:
	_transition_frame = reference_frame if is_instance_valid(reference_frame) else null


func _to_transition_local(world_transform: Transform3D) -> Transform3D:
	if not is_instance_valid(_transition_frame):
		return world_transform
	return _clean_transform(_transition_frame.global_transform).affine_inverse() * world_transform


## Replays a captured endpoint against the live craft it was captured on. With
## no bound frame this is the historical world-space behaviour, unchanged.
func _resolve_transition_transform(
		world_transform: Transform3D,
		local_transform: Transform3D
	) -> Transform3D:
	if not is_instance_valid(_transition_frame):
		return world_transform
	return _clean_transform(
		_clean_transform(_transition_frame.global_transform) * local_transform
	)


func _get_transition_up_direction() -> Vector3:
	if not is_instance_valid(_transition_frame):
		return Vector3.UP
	var frame_up := _transition_frame.global_basis.y.normalized()
	return frame_up if frame_up.is_finite() and not frame_up.is_zero_approx() else Vector3.UP


## Confines this body to `local_bounds` expressed in `frame`'s local space.
##
## This is the whole anti-stranding mechanism for leaving a pilot seat away from
## a berth, and it is deliberately a hard physical constraint rather than a
## warning: an occupant who reaches the envelope is stopped at it, and one who
## somehow ends up well outside it — a fall through the deck, a teleport, an
## impulse — is returned bodily to `recall_transform`. The recall pose is stored
## in frame-local space so it stays valid however far the craft has travelled.
func set_cabin_containment(
		frame: Node3D,
		local_bounds: AABB,
		recall_transform: Transform3D
	) -> bool:
	if not is_instance_valid(frame):
		return false
	var canonical := local_bounds.abs()
	if canonical.size.x <= 0.0 or canonical.size.y <= 0.0 or canonical.size.z <= 0.0:
		return false
	_cabin_frame = frame
	_cabin_bounds = canonical
	_cabin_recall_local = _clean_transform(frame.global_transform).affine_inverse() \
		* _clean_transform(recall_transform)
	_cabin_clamp_count = 0
	_cabin_recall_count = 0
	# The envelope that confines the body also bounds what the camera can see out
	# of, so it is the right place to shorten the boom. Doing it here rather than
	# at the call site means every future craft that publishes a cabin inherits
	# the interior framing without its author having to know about the camera.
	_set_camera_distance_ceiling(interior_camera_distance)
	return true


func clear_cabin_containment() -> void:
	_cabin_frame = null
	_cabin_bounds = AABB()
	_cabin_recall_local = Transform3D.IDENTITY
	_set_camera_distance_ceiling(maximum_camera_distance)


func is_cabin_containment_active() -> bool:
	return is_instance_valid(_cabin_frame)


## Inspectable containment state. `contained` is the invariant a stranding test
## asserts: while containment is active the body is inside the envelope.
func get_cabin_containment_report() -> Dictionary:
	var active := is_instance_valid(_cabin_frame)
	var local_position := Vector3.INF
	if active:
		local_position = _clean_transform(
			_cabin_frame.global_transform
		).affine_inverse() * global_position
	return {
		"active": active,
		"frame": _cabin_frame,
		"local_bounds": _cabin_bounds,
		"local_position": local_position,
		"contained": active and _cabin_bounds.has_point(local_position),
		"clamp_count": _cabin_clamp_count,
		"recall_count": _cabin_recall_count,
	}


## Runs immediately after the slide, so the slide remains the only mover and
## this only ever corrects a result that already left the cabin.
func _resolve_cabin_containment() -> void:
	if not is_instance_valid(_cabin_frame):
		if _cabin_frame != null:
			clear_cabin_containment()
		return
	if _embodiment_state != EmbodimentState.ON_FOOT:
		return
	var frame_transform := _clean_transform(_cabin_frame.global_transform)
	var local_position := frame_transform.affine_inverse() * global_position
	if not local_position.is_finite():
		_recall_into_cabin(frame_transform)
		return
	if _cabin_bounds.has_point(local_position):
		return

	var minimum := _cabin_bounds.position + Vector3.ONE * CABIN_CONTAINMENT_INSET
	var maximum := _cabin_bounds.position + _cabin_bounds.size - Vector3.ONE * CABIN_CONTAINMENT_INSET
	var clamped := Vector3(
		clampf(local_position.x, minf(minimum.x, maximum.x), maxf(minimum.x, maximum.x)),
		clampf(local_position.y, minf(minimum.y, maximum.y), maxf(minimum.y, maximum.y)),
		clampf(local_position.z, minf(minimum.z, maximum.z), maxf(minimum.z, maximum.z))
	)
	var correction := clamped - local_position
	# Below the deck plane is a failure of the floor, not a nudge at a doorway:
	# clamping there would place the capsule inside the deck collider.
	var fell_through := local_position.y < _cabin_bounds.position.y
	if fell_through or correction.length() > CABIN_HARD_RECALL_DISTANCE:
		_recall_into_cabin(frame_transform)
		return

	global_position = frame_transform * clamped
	var world_correction := (frame_transform.basis * correction)
	if not world_correction.is_zero_approx():
		var inward := world_correction.normalized()
		var outward_speed := -velocity.dot(inward)
		if outward_speed > 0.0:
			velocity += inward * outward_speed
	_cabin_clamp_count += 1


func _recall_into_cabin(frame_transform: Transform3D) -> void:
	global_position = (frame_transform * _cabin_recall_local).origin
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_cabin_recall_count += 1


func _clean_transform(value: Transform3D) -> Transform3D:
	return Transform3D(value.basis.orthonormalized(), value.origin)


func _interpolate_transform(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	var amount := clampf(weight, 0.0, 1.0)
	var from_rotation := from.basis.orthonormalized().get_rotation_quaternion()
	var to_rotation := to.basis.orthonormalized().get_rotation_quaternion()
	return Transform3D(
		Basis(from_rotation.slerp(to_rotation, amount)).orthonormalized(),
		from.origin.lerp(to.origin, amount)
	)


func _smoothstep(value: float) -> float:
	var amount := clampf(value, 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)


func _transition_step_height(progress: float, height: float) -> float:
	var amount := clampf(progress, 0.0, 1.0)
	# Preserve the established collision-free world traversal arc. This moves the
	# CharacterBody root only; all visible rig articulation comes from authored
	# AnimationPlayer tracks.
	return sin(amount * PI) * height


## The scene-authored pivot animation is retained as a recovery authority when
## the imported skinned presentation fails its immutable contract at runtime.
## Keep a private, detached copy of that trusted library: mutating the inactive
## scene resource must never poison the recovery driver or silently animate the
## imported skeleton through a second AnimationPlayer.
func _initialize_legacy_motion_authority() -> void:
	_legacy_motion_library_backup = null
	_legacy_motion_pristine_library = null
	_legacy_motion_library_id = 0
	_legacy_motion_animation_ids.clear()
	_legacy_motion_animation_contract.clear()
	_legacy_motion_node_contract.clear()
	_legacy_motion_player_contract.clear()
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
	):
		return
	var source_library := _legacy_motion_animation_player.get_animation_library(&"")
	if source_library == null:
		return
	if not _legacy_source_library_has_safe_track_roster(source_library):
		_motion_authority_contaminated = true
		_legacy_motion_animation_player.stop()
		_legacy_motion_animation_player.active = false
		for library_name in _legacy_motion_animation_player.get_animation_library_list():
			_legacy_motion_animation_player.remove_animation_library(library_name)
		return
	_legacy_motion_library_backup = source_library.duplicate(true) as AnimationLibrary
	if _legacy_motion_library_backup == null:
		return
	_legacy_motion_pristine_library = _legacy_motion_library_backup.duplicate(true) as AnimationLibrary
	_legacy_motion_animation_player.remove_animation_library(&"")
	_legacy_motion_animation_player.add_animation_library(&"", _legacy_motion_library_backup)
	_legacy_motion_library_id = _legacy_motion_library_backup.get_instance_id()
	for clip_name in PILOT_MOTION_CLIPS:
		var animation := _legacy_motion_library_backup.get_animation(clip_name)
		if animation == null:
			continue
		_legacy_motion_animation_ids[clip_name] = animation.get_instance_id()
		_legacy_motion_animation_contract[clip_name] = _legacy_animation_contract(animation)
	for required_path in [
		NodePath("VisualRoot"),
		NodePath("VisualRoot/BodyPivot"),
		NodePath("VisualRoot/BodyPivot/LeftArm"),
		NodePath("VisualRoot/BodyPivot/RightArm"),
		NodePath("VisualRoot/BodyPivot/LeftLeg"),
		NodePath("VisualRoot/BodyPivot/RightLeg"),
	]:
		var node := get_node_or_null(required_path) as Node3D
		if node != null:
			_legacy_motion_node_contract[required_path] = node.get_instance_id()
	_legacy_motion_animation_player.stop()
	_legacy_motion_animation_player.active = false
	_legacy_motion_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	_legacy_motion_player_contract = {
		"root_node": _legacy_motion_animation_player.root_node,
		"root_motion_track": _legacy_motion_animation_player.root_motion_track,
		"root_motion_local": _legacy_motion_animation_player.root_motion_local,
		"deterministic": _legacy_motion_animation_player.deterministic,
		"callback_process": _legacy_motion_animation_player.callback_mode_process,
		"callback_method": _legacy_motion_animation_player.callback_mode_method,
		"callback_discrete": _legacy_motion_animation_player.callback_mode_discrete,
		"process_mode": _legacy_motion_animation_player.process_mode,
		"script_id": (
			_legacy_motion_animation_player.get_script().get_instance_id()
			if _legacy_motion_animation_player.get_script() != null else 0
		),
	}


func _legacy_source_library_has_safe_track_roster(library: AnimationLibrary) -> bool:
	if library == null or library.get_animation_list().size() != PILOT_MOTION_CLIPS.size():
		return false
	for clip_name in PILOT_MOTION_CLIPS:
		var animation := library.get_animation(clip_name)
		if animation == null or animation.get_track_count() != LEGACY_MOTION_TRACK_PATHS.size():
			return false
		var observed_paths: Array[NodePath] = []
		for track_index in animation.get_track_count():
			var track_type := animation.track_get_type(track_index)
			var track_path := animation.track_get_path(track_index)
			if (
				track_type != Animation.TYPE_VALUE
				or not LEGACY_MOTION_TRACK_PATHS.has(track_path)
				or observed_paths.has(track_path)
				or not animation.track_is_enabled(track_index)
			):
				return false
			observed_paths.append(track_path)
			for key_index in animation.track_get_key_count(track_index):
				var value: Variant = animation.track_get_key_value(track_index, key_index)
				if value is float and not is_finite(value):
					return false
				if value is Vector3 and not (value as Vector3).is_finite():
					return false
	return (
		LEGACY_MOTION_LIBRARY_SHA256.is_empty()
		or _legacy_motion_library_signature(library) == LEGACY_MOTION_LIBRARY_SHA256
	)


func _legacy_motion_library_signature(library: AnimationLibrary) -> String:
	if library == null:
		return ""
	var contract := []
	for clip_name in PILOT_MOTION_CLIPS:
		contract.append(clip_name)
		contract.append(_legacy_animation_contract(library.get_animation(clip_name)))
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing.update(var_to_bytes([&"legacy_pilot_motion_v1", contract]))
	return hashing.finish().hex_encode()


func _legacy_animation_contract(animation: Animation) -> Array:
	var contract := []
	if animation == null:
		return contract
	contract.append(animation.length)
	contract.append(animation.loop_mode)
	contract.append(animation.step)
	contract.append(animation.get_track_count())
	for track_index in animation.get_track_count():
		var track_type := animation.track_get_type(track_index)
		contract.append(track_type)
		contract.append(animation.track_get_path(track_index))
		contract.append(animation.track_is_imported(track_index))
		contract.append(animation.track_is_enabled(track_index))
		contract.append(animation.track_get_interpolation_type(track_index))
		contract.append(animation.track_get_interpolation_loop_wrap(track_index))
		contract.append(
			animation.value_track_get_update_mode(track_index)
			if track_type == Animation.TYPE_VALUE else -1
		)
		contract.append(animation.track_get_key_count(track_index))
		for key_index in animation.track_get_key_count(track_index):
			contract.append(animation.track_get_key_time(track_index, key_index))
			contract.append(animation.track_get_key_transition(track_index, key_index))
			contract.append(animation.track_get_key_value(track_index, key_index))
	return contract


func _legacy_motion_library_is_trusted() -> bool:
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
		or _legacy_motion_animation_player.get_parent() != self
		or _legacy_motion_library_backup == null
		or not is_instance_valid(_legacy_motion_library_backup)
		or _legacy_motion_animation_player.root_node
			!= _legacy_motion_player_contract.get("root_node", NodePath("__missing__"))
		or _legacy_motion_animation_player.root_motion_track
			!= _legacy_motion_player_contract.get(
				"root_motion_track", NodePath("__missing__")
			)
		or _legacy_motion_animation_player.root_motion_local
			!= bool(_legacy_motion_player_contract.get("root_motion_local", false))
		or _legacy_motion_animation_player.deterministic
			!= bool(_legacy_motion_player_contract.get("deterministic", false))
		or _legacy_motion_animation_player.callback_mode_method
			!= int(_legacy_motion_player_contract.get("callback_method", -1))
		or _legacy_motion_animation_player.callback_mode_discrete
			!= int(_legacy_motion_player_contract.get("callback_discrete", -1))
		or _legacy_motion_animation_player.callback_mode_process
			!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		or _legacy_motion_animation_player.process_mode
			!= int(_legacy_motion_player_contract.get("process_mode", -1))
		or (
			_legacy_motion_animation_player.get_script().get_instance_id()
			if _legacy_motion_animation_player.get_script() != null else 0
		) != int(_legacy_motion_player_contract.get("script_id", -1))
	):
		return false
	var library := _legacy_motion_animation_player.get_animation_library(&"")
	if (
		library == null
		or library != _legacy_motion_library_backup
		or library.get_instance_id() != _legacy_motion_library_id
		or library.get_animation_list().size() != PILOT_MOTION_CLIPS.size()
	):
		return false
	for clip_name in PILOT_MOTION_CLIPS:
		var animation := library.get_animation(clip_name)
		if (
			animation == null
			or animation.get_instance_id()
				!= int(_legacy_motion_animation_ids.get(clip_name, 0))
			or _legacy_animation_contract(animation)
				!= _legacy_motion_animation_contract.get(clip_name, [])
		):
			return false
	for required_path in _legacy_motion_node_contract:
		var node := get_node_or_null(required_path) as Node3D
		if (
			node == null
			or node.get_instance_id()
				!= int(_legacy_motion_node_contract.get(required_path, 0))
		):
			return false
	return true


func _restore_legacy_motion_library() -> bool:
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
		or _legacy_motion_animation_contract.size() != PILOT_MOTION_CLIPS.size()
	):
		return false
	var restored_library := AnimationLibrary.new()
	for clip_name in PILOT_MOTION_CLIPS:
		var source_animation := (
			_legacy_motion_pristine_library.get_animation(clip_name)
			if _legacy_motion_pristine_library != null
			and is_instance_valid(_legacy_motion_pristine_library)
			else null
		)
		if (
			source_animation == null
			or _legacy_animation_contract(source_animation)
				!= _legacy_motion_animation_contract.get(clip_name, [])
		):
			return false
		restored_library.add_animation(clip_name, source_animation.duplicate(true))
	_legacy_motion_animation_player.stop()
	_legacy_motion_animation_player.active = false
	if int(_legacy_motion_player_contract.get("script_id", 0)) == 0:
		_legacy_motion_animation_player.set_script(null)
	for library_name in _legacy_motion_animation_player.get_animation_library_list():
		_legacy_motion_animation_player.remove_animation_library(library_name)
	_legacy_motion_animation_player.add_animation_library(&"", restored_library)
	_legacy_motion_library_backup = restored_library
	_legacy_motion_library_id = restored_library.get_instance_id()
	_legacy_motion_animation_ids.clear()
	for clip_name in PILOT_MOTION_CLIPS:
		var restored_animation := restored_library.get_animation(clip_name)
		_legacy_motion_animation_ids[clip_name] = restored_animation.get_instance_id()
	return _legacy_motion_library_is_trusted()


func _live_imported_animation_player() -> AnimationPlayer:
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return null
	var candidate: Variant = _pilot_presentation.get_animation_player()
	return (
		candidate as AnimationPlayer
		if candidate is AnimationPlayer and is_instance_valid(candidate)
		else null
	)


func _set_imported_presentation_visible(visible_value: bool) -> void:
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return
	_pilot_presentation.visible = visible_value
	var imported_root: Variant = _pilot_presentation.get_visual_root()
	if imported_root is Node3D and is_instance_valid(imported_root):
		(imported_root as Node3D).visible = visible_value
		for candidate in (imported_root as Node3D).find_children(
			"*", "MeshInstance3D", true, false
		):
			(candidate as MeshInstance3D).visible = visible_value


func _quarantine_rejected_presentation_authority() -> void:
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return
	_pilot_presentation.process_mode = Node.PROCESS_MODE_DISABLED
	for candidate in _pilot_presentation.find_children("*", "", true, false):
		candidate.process_mode = Node.PROCESS_MODE_DISABLED
		if candidate is Camera3D:
			var camera := candidate as Camera3D
			camera.current = false
			camera.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is Area3D:
			var area := candidate as Area3D
			area.monitoring = false
			area.monitorable = false
			area.collision_layer = 0
			area.collision_mask = 0
			area.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is CollisionObject3D:
			var collision_object := candidate as CollisionObject3D
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
			collision_object.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is CollisionShape3D:
			(candidate as CollisionShape3D).disabled = true
		elif candidate is AudioStreamPlayer3D:
			var audio := candidate as AudioStreamPlayer3D
			audio.stop()
			audio.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is NavigationRegion3D:
			(candidate as NavigationRegion3D).enabled = false
			candidate.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is NavigationAgent3D:
			candidate.process_mode = Node.PROCESS_MODE_DISABLED
		elif candidate is AudioListener3D:
			(candidate as AudioListener3D).clear_current()
		elif candidate is RayCast3D:
			(candidate as RayCast3D).enabled = false
		elif candidate is ShapeCast3D:
			(candidate as ShapeCast3D).enabled = false
		elif candidate is AudioStreamPlayer:
			(candidate as AudioStreamPlayer).stop()
	# Hiding a visual root is not an authority boundary: future engine node types
	# could still listen, cast, play, or process. A rejected imported subtree is
	# therefore retired as a queued-free detached graph. Re-entry is not attempted
	# after immutable-contract rejection; the trusted fallback owns all subsequent
	# presentation until this Player instance is replaced.
	var parent := _pilot_presentation.get_parent()
	if parent != null:
		parent.remove_child(_pilot_presentation)
	_pilot_presentation.queue_free()
	_pilot_presentation = null


func _set_fallback_presentation_visible(visible_value: bool) -> void:
	if _body_pivot == null or not is_instance_valid(_body_pivot):
		return
	var refined_core := _body_pivot.get_node_or_null("RefinedPilotCore") as Node3D
	if refined_core != null:
		refined_core.visible = visible_value
	# The scene-authored blockout meshes remain stable rig parents. Every generated
	# recovery mesh (including arms and legs parented to those pivots) is visible in
	# fallback mode, and every non-generated blockout mesh remains hidden.
	for candidate in _body_pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if (
			_pilot_presentation != null
			and is_instance_valid(_pilot_presentation)
			and _pilot_presentation.is_ancestor_of(mesh)
		):
			continue
		mesh.visible = visible_value and bool(mesh.get_meta(&"pilot_generated", false))


func _fallback_render_hierarchy_is_inert() -> bool:
	if _body_pivot == null or not is_instance_valid(_body_pivot):
		return false
	for candidate in _body_pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if (
			_pilot_presentation != null
			and is_instance_valid(_pilot_presentation)
			and _pilot_presentation.is_ancestor_of(mesh)
		):
			continue
		if mesh.visible:
			return false
	var refined_core := _body_pivot.get_node_or_null("RefinedPilotCore") as Node3D
	return refined_core == null or not refined_core.visible


func _fallback_render_hierarchy_is_exclusive() -> bool:
	if _body_pivot == null or not is_instance_valid(_body_pivot):
		return false
	var refined_core := _body_pivot.get_node_or_null("RefinedPilotCore") as Node3D
	if refined_core == null or not refined_core.visible:
		return false
	var generated_count := 0
	for candidate in _body_pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if (
			_pilot_presentation != null
			and is_instance_valid(_pilot_presentation)
			and _pilot_presentation.is_ancestor_of(mesh)
		):
			if mesh.visible:
				return false
			continue
		var generated := bool(mesh.get_meta(&"pilot_generated", false))
		if generated:
			generated_count += 1
		if mesh.visible != generated:
			return false
	return generated_count > 0


func _motion_animation_player_roster_is_exact() -> bool:
	var expected_imported := _live_imported_animation_player()
	var expected_legacy: AnimationPlayer = (
		_legacy_motion_animation_player
		if _legacy_motion_animation_player != null
		and is_instance_valid(_legacy_motion_animation_player)
		else null
	)
	var live_mixers: Array[AnimationMixer] = []
	for candidate in find_children("*", "AnimationMixer", true, false):
		var mixer := candidate as AnimationMixer
		if mixer != null:
			live_mixers.append(mixer)
	if expected_imported == null:
		return (
			expected_legacy != null
			and live_mixers.size() == 1
			and live_mixers[0] == expected_legacy
		)
	return (
		expected_legacy != null
		and live_mixers.size() == 2
		and live_mixers.has(expected_legacy)
		and live_mixers.has(expected_imported)
	)


func _quarantine_unexpected_animation_players() -> void:
	var expected_imported := _live_imported_animation_player()
	for candidate in find_children("*", "AnimationMixer", true, false):
		var mixer := candidate as AnimationMixer
		if mixer == _legacy_motion_animation_player or mixer == expected_imported:
			continue
		_motion_authority_contaminated = true
		mixer.active = false
		if mixer is AnimationPlayer:
			(mixer as AnimationPlayer).stop()
		var parent := mixer.get_parent()
		if parent != null:
			parent.remove_child(mixer)
		mixer.queue_free()


func _restore_contaminated_legacy_driver() -> bool:
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
	):
		return false
	if _legacy_motion_library_is_trusted():
		return true
	_motion_authority_contaminated = true
	_legacy_motion_animation_player.stop()
	_legacy_motion_animation_player.active = false
	_legacy_motion_animation_player.root_node = _legacy_motion_player_contract.get(
		"root_node", NodePath("..")
	)
	_legacy_motion_animation_player.root_motion_track = _legacy_motion_player_contract.get(
		"root_motion_track", NodePath()
	)
	_legacy_motion_animation_player.root_motion_local = bool(
		_legacy_motion_player_contract.get("root_motion_local", false)
	)
	_legacy_motion_animation_player.deterministic = bool(
		_legacy_motion_player_contract.get("deterministic", true)
	)
	_legacy_motion_animation_player.callback_mode_method = int(
		_legacy_motion_player_contract.get("callback_method", 0)
	)
	_legacy_motion_animation_player.callback_mode_discrete = int(
		_legacy_motion_player_contract.get("callback_discrete", 2)
	)
	_legacy_motion_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	_legacy_motion_animation_player.process_mode = int(
		_legacy_motion_player_contract.get("process_mode", Node.PROCESS_MODE_INHERIT)
	)
	return _restore_legacy_motion_library()


func _repair_pilot_mount_contract() -> bool:
	if (
		_visual_root == null
		or not is_instance_valid(_visual_root)
		or _body_pivot == null
		or not is_instance_valid(_body_pivot)
	):
		return false
	if _visual_root.get_parent() != self:
		_visual_root.reparent(self, false)
	_visual_root.top_level = false
	_visual_root.transform = Transform3D.IDENTITY
	if _body_pivot.get_parent() != _visual_root:
		_body_pivot.reparent(_visual_root, false)
	_body_pivot.top_level = false
	_body_pivot.position = Vector3.ZERO
	_body_pivot.scale = Vector3.ONE
	if not is_finite(_target_body_yaw):
		_target_body_yaw = 0.0
	_apply_body_facing_rotation()
	if _pilot_presentation != null and is_instance_valid(_pilot_presentation):
		if (
			_pilot_presentation.get_parent() != null
			and _pilot_presentation.get_parent() != _body_pivot
		):
			_pilot_presentation.reparent(_body_pivot, false)
		elif _pilot_presentation.get_parent() == null:
			return false
		_pilot_presentation.top_level = false
		_pilot_presentation.transform = Transform3D.IDENTITY
	return _imported_mount_contract_is_live()


func _imported_mount_contract_is_live() -> bool:
	if (
		_visual_root == null
		or not is_instance_valid(_visual_root)
		or _visual_root.get_parent() != self
		or _visual_root.top_level
		or not _visual_root.transform.is_equal_approx(Transform3D.IDENTITY)
		or _body_pivot == null
		or not is_instance_valid(_body_pivot)
		or _body_pivot.get_parent() != _visual_root
		or _body_pivot.top_level
		or not _body_pivot.position.is_zero_approx()
		or not _body_pivot.scale.is_equal_approx(Vector3.ONE)
		or not _body_pivot.rotation.is_finite()
		or not is_zero_approx(_body_pivot.rotation.x)
		or not is_zero_approx(_body_pivot.rotation.z)
		or _pilot_presentation == null
		or not is_instance_valid(_pilot_presentation)
		or _pilot_presentation.get_parent() != _body_pivot
		or _pilot_presentation.top_level
		or not _pilot_presentation.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		return false
	return true


func _imported_motion_authority_is_healthy() -> bool:
	if _imported_presentation_rejected or not _imported_mount_contract_is_live():
		return false
	var expected_player := _live_imported_animation_player()
	var imported_root: Variant = _pilot_presentation.get_visual_root()
	var imported_parts := get_pilot_visual_parts()
	if (
		expected_player == null
		or _motion_animation_player != expected_player
		or expected_player.get_parent() == null
		or not _pilot_presentation.is_ancestor_of(expected_player)
		or not _pilot_presentation.visible
		or not (imported_root is Node3D)
		or not is_instance_valid(imported_root)
		or not (imported_root as Node3D).visible
		or (imported_root as Node3D).top_level
		or not (imported_root as Node3D).transform.is_equal_approx(Transform3D.IDENTITY)
		or imported_parts.size() != 1
		or not imported_parts[0].visible
		or not _fallback_render_hierarchy_is_inert()
		or not expected_player.active
		or expected_player.callback_mode_process
			!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		or not _motion_animation_player_roster_is_exact()
		or not _legacy_motion_library_is_trusted()
		or _legacy_motion_animation_player.active
		or _legacy_motion_animation_player.is_playing()
	):
		return false
	return true


func _select_imported_motion_authority(run_full_audit: bool = false) -> bool:
	if _imported_presentation_rejected or not _imported_mount_contract_is_live():
		return false
	_set_imported_presentation_visible(true)
	var expected_player := _live_imported_animation_player()
	if expected_player == null:
		return false
	if run_full_audit:
		var audit := _pilot_presentation.get_asset_audit_report()
		if not bool(audit.get("valid", false)):
			_imported_presentation_rejected = true
			return false
	_set_fallback_presentation_visible(false)
	_set_imported_presentation_visible(true)
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
	):
		return false
	_legacy_motion_animation_player.stop()
	_legacy_motion_animation_player.active = false
	expected_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	expected_player.active = true
	_motion_animation_player = expected_player
	_using_imported_pilot_presentation = true
	_apply_body_facing_rotation()
	_capture_imported_skeleton_pose_contract()
	return _repair_cached_motion_state(true)


func _select_fallback_motion_authority() -> bool:
	_using_imported_pilot_presentation = false
	_apply_body_facing_rotation()
	_imported_presentation_rejected = true
	var imported_player := _live_imported_animation_player()
	if imported_player != null:
		imported_player.stop()
		imported_player.active = false
	_set_imported_presentation_visible(false)
	_quarantine_rejected_presentation_authority()
	_refine_pilot_presentation()
	_set_fallback_presentation_visible(true)
	_quarantine_unexpected_animation_players()
	if (
		_legacy_motion_animation_player == null
		or not is_instance_valid(_legacy_motion_animation_player)
	):
		_motion_animation_player = null
		_motion_authority_contaminated = true
		return false
	if not _restore_contaminated_legacy_driver():
		_motion_animation_player = null
		_motion_authority_contaminated = true
		return false
	_legacy_motion_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)
	_legacy_motion_animation_player.callback_mode_discrete = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_DISCRETE_FORCE_CONTINUOUS
	)
	_legacy_motion_animation_player.active = true
	_motion_animation_player = _legacy_motion_animation_player
	return _repair_cached_motion_state(true)


func _ensure_motion_authority(run_integrity_probe: bool = false) -> bool:
	if _ensuring_motion_authority:
		return _motion_animation_player != null and is_instance_valid(_motion_animation_player)
	_ensuring_motion_authority = true
	_repair_pilot_mount_contract()
	_quarantine_unexpected_animation_players()
	var healthy := false
	if _using_imported_pilot_presentation:
		var expected_imported := _live_imported_animation_player()
		_set_fallback_presentation_visible(false)
		_restore_contaminated_legacy_driver()
		if (
			_legacy_motion_animation_player != null
			and is_instance_valid(_legacy_motion_animation_player)
		):
			_legacy_motion_animation_player.stop()
			_legacy_motion_animation_player.active = false
		# AnimationPlayer.stop() can synchronously sample the stopped clip at zero.
		# Reassert Player-owned mount/facing state after the legacy driver is inert.
		_repair_pilot_mount_contract()
		if expected_imported != null:
			_motion_animation_player = expected_imported
		if (
			expected_imported != null
			and _motion_animation_player != expected_imported
			and not _imported_presentation_rejected
		):
			if (
				_legacy_motion_animation_player != null
				and is_instance_valid(_legacy_motion_animation_player)
			):
				_legacy_motion_animation_player.stop()
				_legacy_motion_animation_player.active = false
			_motion_animation_player = expected_imported
		if (
			expected_imported != null
			and (
				not expected_imported.active
				or expected_imported.callback_mode_process
					!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			)
		):
			expected_imported.stop()
			expected_imported.callback_mode_process = (
				AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			)
			expected_imported.active = true
		healthy = _imported_motion_authority_is_healthy()
		if healthy and run_integrity_probe:
			var asset_audit := _pilot_presentation.get_asset_audit_report()
			healthy = bool(asset_audit.get("valid", false))
			if not healthy:
				_imported_presentation_rejected = true
		if not healthy:
			healthy = _select_fallback_motion_authority()
	else:
		var imported_player := _live_imported_animation_player()
		_set_imported_presentation_visible(false)
		_quarantine_rejected_presentation_authority()
		_set_fallback_presentation_visible(true)
		var fallback_is_exclusive := (
			_motion_animation_player == _legacy_motion_animation_player
			and _legacy_motion_library_is_trusted()
			and _motion_animation_player_roster_is_exact()
			and _fallback_render_hierarchy_is_exclusive()
			and (
				imported_player == null
				or (not imported_player.active and not imported_player.is_playing())
			)
		)
		if not fallback_is_exclusive:
			healthy = _select_fallback_motion_authority()
		else:
			healthy = true
	_ensuring_motion_authority = false
	return healthy


func _advance_pilot_integrity_probe(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	_pilot_integrity_probe_elapsed += delta
	if _pilot_integrity_probe_elapsed < PILOT_INTEGRITY_PROBE_INTERVAL:
		return false
	_pilot_integrity_probe_elapsed = fmod(
		_pilot_integrity_probe_elapsed,
		PILOT_INTEGRITY_PROBE_INTERVAL
	)
	return true


func _motion_driver_matches_cached_state() -> bool:
	var player := _motion_animation_player
	if player == null or not is_instance_valid(player) or not player.active:
		return false
	if (
		player.callback_mode_process
		!= AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		or not is_finite(_motion_playback_rate)
		or _motion_playback_rate <= 0.0
		or not is_finite(player.speed_scale)
		or not is_equal_approx(player.speed_scale, _motion_playback_rate)
	):
		return false
	if _motion_state.is_empty():
		return true
	if not player.has_animation(_motion_state) or player.assigned_animation != _motion_state:
		return false
	if player.is_playing():
		return true
	var clip := player.get_animation(_motion_state)
	return (
		clip != null
		and clip.loop_mode == Animation.LOOP_NONE
		and player.current_animation_position >= clip.length - 0.002
	)


func _repair_cached_motion_state(sample_immediately: bool) -> bool:
	var player := _motion_animation_player
	if player == null or not is_instance_valid(player):
		return false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.active = true
	if not is_finite(_motion_playback_rate) or _motion_playback_rate <= 0.0:
		return false
	player.speed_scale = _motion_playback_rate
	if _motion_state.is_empty():
		return true
	if not player.has_animation(_motion_state):
		return false
	var clip := player.get_animation(_motion_state)
	var completed_one_shot := (
		player.assigned_animation == _motion_state
		and not player.is_playing()
		and clip != null
		and clip.loop_mode == Animation.LOOP_NONE
		and player.current_animation_position >= clip.length - 0.002
	)
	if player.assigned_animation != _motion_state or (
		not player.is_playing() and not completed_one_shot
	):
		player.play(_motion_state, 0.0)
	if sample_immediately:
		if _using_imported_pilot_presentation:
			_restore_imported_skeleton_pose_contract()
		# Godot can optimize away a sample at the already-cached position. Sample a
		# distinct bounded point first, then the exact cached point, so the accepted
		# driver overwrites every last visible write from quarantined authorities.
		var cached_position := player.current_animation_position
		var alternate_position := (
			minf(clip.length, cached_position + 0.001)
			if cached_position < clip.length else maxf(0.0, cached_position - 0.001)
		)
		player.seek(alternate_position, true, true)
		player.seek(cached_position, true, true)
	return _motion_driver_matches_cached_state()


func _capture_imported_skeleton_pose_contract() -> void:
	if not _imported_skeleton_pose_contract.is_empty():
		return
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return
	var skeleton: Variant = _pilot_presentation.get_skeleton()
	if not (skeleton is Skeleton3D) or not is_instance_valid(skeleton):
		return
	for bone_index in (skeleton as Skeleton3D).get_bone_count():
		_imported_skeleton_pose_contract.append({
			"position": (skeleton as Skeleton3D).get_bone_pose_position(bone_index),
			"rotation": (skeleton as Skeleton3D).get_bone_pose_rotation(bone_index),
			"scale": (skeleton as Skeleton3D).get_bone_pose_scale(bone_index),
		})


func _restore_imported_skeleton_pose_contract() -> bool:
	if _pilot_presentation == null or not is_instance_valid(_pilot_presentation):
		return false
	var skeleton: Variant = _pilot_presentation.get_skeleton()
	if (
		not (skeleton is Skeleton3D)
		or not is_instance_valid(skeleton)
		or (skeleton as Skeleton3D).get_bone_count()
			!= _imported_skeleton_pose_contract.size()
	):
		return false
	for bone_index in _imported_skeleton_pose_contract.size():
		var pose := _imported_skeleton_pose_contract[bone_index]
		(skeleton as Skeleton3D).set_bone_pose_position(bone_index, pose.position)
		(skeleton as Skeleton3D).set_bone_pose_rotation(bone_index, pose.rotation)
		(skeleton as Skeleton3D).set_bone_pose_scale(bone_index, pose.scale)
	return true


func _fallback_motion_authority_is_healthy() -> bool:
	return (
		_imported_presentation_rejected
		and not _using_imported_pilot_presentation
		and _pilot_presentation == null
		and _legacy_motion_animation_player != null
		and is_instance_valid(_legacy_motion_animation_player)
		and _motion_animation_player == _legacy_motion_animation_player
		and _legacy_motion_library_is_trusted()
		and _motion_animation_player_roster_is_exact()
		and _fallback_render_hierarchy_is_exclusive()
		and _motion_driver_matches_cached_state()
	)


## Explicit integrity fence for lifecycle code, test tooling, and unusual hosts
## that manually sample this controller instead of letting physics advance the
## bounded 0.2-second automatic integrity probe.
func validate_pilot_motion_authority() -> bool:
	_pilot_integrity_probe_elapsed = 0.0
	if not _ensure_motion_authority(true):
		return false
	if not _repair_cached_motion_state(true):
		return false
	if not _using_imported_pilot_presentation:
		return _fallback_motion_authority_is_healthy()
	if not _imported_motion_authority_is_healthy():
		return false
	var asset_audit := _pilot_presentation.get_asset_audit_report()
	return bool(asset_audit.get("valid", false)) and _motion_driver_matches_cached_state()


## Replaces the deliberately simple scene blockout with a smoother articulated
## shipyard pressure-suit silhouette. The original animation pivots remain the
## rig, so locomotion and the live cockpit pose continue to share one body.
func _refine_pilot_presentation() -> void:
	if _body_pivot == null or not is_instance_valid(_body_pivot):
		return
	if _body_pivot.has_node("RefinedPilotCore"):
		return
	for child in _body_pivot.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).visible = false

	_create_pilot_materials()
	_build_pilot_core()
	_build_pilot_arm(_left_arm, -1.0)
	_build_pilot_arm(_right_arm, 1.0)
	_build_pilot_leg(_left_leg, -1.0)
	_build_pilot_leg(_right_leg, 1.0)


func _activate_skinned_pilot_presentation() -> void:
	_motion_animation_player = null
	_using_imported_pilot_presentation = false
	# Rejection is terminal for this Player instance. A replacement subtree cannot
	# regain presentation or animation authority after an immutable-contract fault.
	if _imported_presentation_rejected:
		_select_fallback_motion_authority()
		return
	if _select_imported_motion_authority(true):
		return
	push_warning("Player rejected the Blender-skinned pilot presentation; using safe fallback")
	_select_fallback_motion_authority()


func _create_pilot_materials() -> void:
	_pilot_materials = {
		# The pressure layers read as woven and light-absorbing; armour remains
		# subtly harder without turning the whole suit into polished metal.
		"undersuit": _pilot_material(PILOT_NAVY, 0.0, 0.9),
		"textile": _pilot_material(PILOT_CYAN_TEXTILE, 0.01, 0.82),
		"webbing": _pilot_material(Color("0b2028"), 0.01, 0.76),
		"soft_armor": _pilot_material(PILOT_NAVY_LIGHT, 0.05, 0.66),
		"hard_armor": _pilot_material(PILOT_CYAN_ARMOR, 0.17, 0.45),
		"ceramic": _pilot_material(PILOT_CERAMIC, 0.07, 0.58),
		"rubber": _pilot_material(PILOT_RUBBER, 0.0, 0.94),
		"visor": _pilot_material(PILOT_VISOR, 0.34, 0.15),
		"piping": _pilot_material(Color("23828a"), 0.06, 0.55),
		"cyan_light": _pilot_material(
			PILOT_KETH_CYAN,
			0.08,
			0.38,
			PILOT_KETH_CYAN,
			0.62
		),
		"amber": _pilot_material(PILOT_AMBER, 0.2, 0.4),
		"amber_light": _pilot_material(
			PILOT_AMBER,
			0.08,
			0.4,
			PILOT_AMBER,
			0.48
		),
	}


func _build_pilot_core() -> void:
	var core := Node3D.new()
	core.name = "RefinedPilotCore"
	core.set_meta(&"presentation_style", &"realistic_stylised")
	core.set_meta(&"presentation_version", PILOT_PRESENTATION_VERSION)
	core.set_meta(&"target_heads_tall", Vector2(5.5, 6.0))
	_body_pivot.add_child(core)

	# Flexible pressure layer and tapered armoured torso establish human rather
	# than toy-like proportions without making the suit implausibly skin-tight.
	_pilot_cylinder(
		core, "PressureTorso", Vector3(0.0, 1.205, 0.0),
		0.305, 0.235, 0.62, _pilot_materials.textile,
		Vector3(1.0, 1.0, 0.64)
	)
	_pilot_sphere(
		core, "ChestShell", Vector3(0.0, 1.315, -0.045),
		0.3, _pilot_materials.hard_armor,
		Vector3(1.04, 0.78, 0.52)
	)
	_pilot_sphere(
		core, "SternumPanel", Vector3(0.0, 1.3, -0.225),
		0.16, _pilot_materials.ceramic,
		Vector3(0.82, 1.14, 0.12)
	)
	_pilot_capsule(
		core, "ClavicleArmor", Vector3(0.0, 1.5, -0.092),
		0.045, 0.44, _pilot_materials.soft_armor,
		Vector3(1.0, 1.0, 0.58),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	_pilot_cylinder(
		core, "Abdomen", Vector3(0.0, 0.92, 0.0),
		0.235, 0.215, 0.28, _pilot_materials.undersuit,
		Vector3(1.0, 1.0, 0.66)
	)
	for rib_index in range(3):
		_pilot_torus(
			core,
			"AbdomenSeal%02d" % rib_index,
			Vector3(0.0, 0.845 + float(rib_index) * 0.078, -0.006),
			0.192,
			0.207,
			_pilot_materials.soft_armor,
			Vector3(1.0, 1.0, 0.68)
		)

	_pilot_sphere(
		core, "PelvicArmor", Vector3(0.0, 0.735, -0.004),
		0.275, _pilot_materials.soft_armor,
		Vector3(1.0, 0.5, 0.68)
	)
	_pilot_cylinder(
		core, "UtilityBelt", Vector3(0.0, 0.825, -0.004),
		0.245, 0.245, 0.082, _pilot_materials.webbing,
		Vector3(1.0, 1.0, 0.68)
	)
	_pilot_torus(
		core, "BeltCyanPiping", Vector3(0.0, 0.842, -0.006),
		0.225, 0.239, _pilot_materials.piping,
		Vector3(1.0, 1.0, 0.68)
	)

	# A shallow life-support pack and service spine keep the back readable while
	# remaining compact enough for the Torrent seat and canopy.
	_pilot_capsule(
		core, "LifeSupportPack", Vector3(0.0, 1.205, 0.205),
		0.17, 0.5, _pilot_materials.soft_armor,
		Vector3(1.45, 1.0, 0.43)
	)
	_pilot_capsule(
		core, "ServiceSpine", Vector3(0.0, 1.205, 0.285),
		0.062, 0.4, _pilot_materials.ceramic,
		Vector3(0.78, 1.0, 0.5)
	)
	_pilot_sphere(
		core, "PackStatusLight", Vector3(0.0, 1.38, 0.323),
		0.026, _pilot_materials.cyan_light,
		Vector3(1.3, 0.55, 0.34)
	)

	# Harness webbing follows the chest instead of floating as a rectangular
	# plate. The amber quick-release remains a strong Keth colour cue.
	for side in [-1.0, 1.0]:
		_pilot_capsule(
			core,
			"HarnessStrap%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 0.132, 1.235, -0.252),
			0.022, 0.54, _pilot_materials.webbing,
			Vector3(1.0, 1.0, 0.44),
			Vector3(0.0, 0.0, side * deg_to_rad(-14.0))
		)
	_pilot_sphere(
		core, "HarnessRelease", Vector3(0.0, 1.075, -0.276),
		0.046, _pilot_materials.amber,
		Vector3(1.0, 0.62, 0.26)
	)
	_pilot_capsule(
		core, "ChestTelemetry", Vector3(-0.102, 1.355, -0.265),
		0.042, 0.125, _pilot_materials.soft_armor,
		Vector3(1.4, 1.0, 0.25),
		Vector3(0.0, 0.0, deg_to_rad(-8.0))
	)
	_pilot_sphere(
		core, "TelemetryLight", Vector3(-0.102, 1.382, -0.282),
		0.013, _pilot_materials.amber_light,
		Vector3(1.0, 0.55, 0.36)
	)

	# Low-profile service hoses terminate at visible couplings instead of
	# disappearing into the torso. Their dark rubber stays subordinate to the
	# harness and helmet while adding credible pressure-suit function.
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		_pilot_capsule(
			core, "ServiceHoseUpper%s" % suffix,
			Vector3(side * 0.245, 1.245, -0.195),
			0.015, 0.31, _pilot_materials.rubber,
			Vector3(1.0, 1.0, 0.88),
			Vector3(deg_to_rad(-4.0), 0.0, side * deg_to_rad(9.0))
		)
		_pilot_capsule(
			core, "ServiceHoseLower%s" % suffix,
			Vector3(side * 0.218, 1.015, -0.16),
			0.015, 0.2, _pilot_materials.rubber,
			Vector3(1.0, 1.0, 0.88),
			Vector3(deg_to_rad(-9.0), 0.0, side * deg_to_rad(-7.0))
		)
		_pilot_cylinder(
			core, "HoseCoupling%s" % suffix,
			Vector3(side * 0.25, 1.39, -0.215),
			0.025, 0.025, 0.026, _pilot_materials.amber,
			Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0)
		)
	for side in [-1.0, 1.0]:
		for height in [1.2, 1.4]:
			_pilot_cylinder(
				core,
				"ChestFastener%s%s" % ["L" if side < 0.0 else "R", "Low" if height < 1.3 else "High"],
				Vector3(side * 0.105, height, -0.251),
				0.011, 0.011, 0.016, _pilot_materials.rubber,
				Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0)
			)

	_build_pilot_helmet(core)


func _build_pilot_helmet(parent: Node3D) -> void:
	_pilot_torus(
		parent, "NeckPressureSeal", Vector3(0.0, 1.575, 0.0),
		0.145, 0.18, _pilot_materials.rubber,
		Vector3(1.0, 1.0, 0.9)
	)
	_pilot_sphere(
		parent, "HelmetShell", Vector3(0.0, 1.765, 0.0),
		0.18, _pilot_materials.ceramic,
		Vector3(1.0, 0.95, 0.92)
	)
	_pilot_sphere(
		parent, "HelmetRearArmor", Vector3(0.0, 1.765, 0.105),
		0.166, _pilot_materials.hard_armor,
		Vector3(1.02, 0.9, 0.56)
	)
	_pilot_sphere(
		parent, "Visor", Vector3(0.0, 1.765, -0.173),
		0.148, _pilot_materials.visor,
		Vector3(0.91, 0.7, 0.15)
	)
	_pilot_torus(
		parent, "VisorSeal", Vector3(0.0, 1.765, -0.191),
		0.108, 0.126, _pilot_materials.soft_armor,
		Vector3(1.05, 0.78, 1.0),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_capsule(
		parent, "HelmetBrow", Vector3(0.0, 1.88, -0.142),
		0.027, 0.225, _pilot_materials.hard_armor,
		Vector3(1.0, 1.0, 0.68),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	_pilot_capsule(
		parent, "HelmetChin", Vector3(0.0, 1.64, -0.138),
		0.03, 0.205, _pilot_materials.soft_armor,
		Vector3(1.0, 1.0, 0.68),
		Vector3(0.0, 0.0, PI * 0.5)
	)
	for side in [-1.0, 1.0]:
		_pilot_cylinder(
			parent,
			"HelmetComms%s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 0.183, 1.765, 0.0),
			0.038, 0.038, 0.028, _pilot_materials.amber,
			Vector3.ONE,
			Vector3(0.0, 0.0, PI * 0.5)
		)
	_pilot_capsule(
		parent, "HelmetCyanRail", Vector3(0.0, 1.925, 0.005),
		0.01, 0.17, _pilot_materials.piping,
		Vector3(1.0, 1.0, 0.64),
		Vector3(0.0, 0.0, PI * 0.5)
	)


func _build_pilot_arm(parent: Node3D, side: float) -> void:
	var suffix := "L" if side < 0.0 else "R"
	_pilot_sphere(
		parent, "PressureShoulder%s" % suffix, Vector3(-side * 0.04, -0.02, 0.0),
		0.09, _pilot_materials.textile,
		Vector3(1.04, 1.0, 0.96)
	)
	_pilot_sphere(
		parent, "Shoulder%s" % suffix, Vector3(-side * 0.04, 0.005, -0.018),
		0.095, _pilot_materials.hard_armor,
		Vector3(1.18, 0.56, 0.94)
	)
	_pilot_cylinder(
		parent, "UpperArm%s" % suffix, Vector3(-side * 0.032, -0.21, 0.0),
		0.082, 0.068, 0.36, _pilot_materials.textile,
		Vector3(1.0, 1.0, 0.92),
		Vector3(0.0, 0.0, side * deg_to_rad(3.0))
	)
	_pilot_torus(
		parent, "UpperArmBand%s" % suffix, Vector3(-side * 0.039, -0.292, 0.0),
		0.073, 0.087, _pilot_materials.piping,
		Vector3(1.0, 1.0, 0.92)
	)
	_pilot_sphere(
		parent, "Elbow%s" % suffix, Vector3(-side * 0.045, -0.425, 0.0),
		0.077, _pilot_materials.soft_armor,
		Vector3(1.0, 0.9, 0.96)
	)
	_pilot_cylinder(
		parent, "Forearm%s" % suffix, Vector3(-side * 0.055, -0.56, -0.012),
		0.072, 0.058, 0.275, _pilot_materials.hard_armor,
		Vector3(1.0, 1.0, 0.9),
		Vector3(0.0, 0.0, side * deg_to_rad(4.0))
	)
	_pilot_torus(
		parent, "WristSeal%s" % suffix, Vector3(-side * 0.065, -0.7, -0.015),
		0.058, 0.072, _pilot_materials.rubber,
		Vector3(1.0, 1.0, 0.93)
	)
	_pilot_capsule(
		parent, "Glove%s" % suffix, Vector3(-side * 0.068, -0.765, -0.045),
		0.071, 0.18, _pilot_materials.rubber,
		Vector3(0.9, 1.0, 0.88),
		Vector3(deg_to_rad(8.0), 0.0, side * deg_to_rad(4.0))
	)
	_pilot_sphere(
		parent, "GloveKnuckle%s" % suffix, Vector3(-side * 0.068, -0.82, -0.092),
		0.054, _pilot_materials.ceramic,
		Vector3(1.04, 0.52, 0.4)
	)


func _build_pilot_leg(parent: Node3D, side: float) -> void:
	var suffix := "L" if side < 0.0 else "R"
	_pilot_sphere(
		parent, "HipSeal%s" % suffix, Vector3.ZERO,
		0.116, _pilot_materials.undersuit,
		Vector3(0.88, 0.94, 0.96)
	)
	_pilot_cylinder(
		parent, "Thigh%s" % suffix, Vector3(side * 0.008, -0.205, 0.0),
		0.115, 0.088, 0.38, _pilot_materials.textile,
		Vector3(0.94, 1.0, 0.92),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.0))
	)
	_pilot_capsule(
		parent, "ThighArmor%s" % suffix, Vector3(side * 0.008, -0.215, -0.088),
		0.072, 0.33, _pilot_materials.hard_armor,
		Vector3(1.0, 1.0, 0.32),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.0))
	)
	_pilot_sphere(
		parent, "Knee%s" % suffix, Vector3(side * 0.018, -0.39, -0.035),
		0.106, _pilot_materials.soft_armor,
		Vector3(0.91, 0.84, 0.96)
	)
	_pilot_sphere(
		parent, "KneePlate%s" % suffix, Vector3(side * 0.018, -0.4, -0.108),
		0.077, _pilot_materials.ceramic,
		Vector3(0.91, 0.82, 0.29)
	)
	_pilot_cylinder(
		parent, "Shin%s" % suffix, Vector3(side * 0.025, -0.53, 0.0),
		0.09, 0.068, 0.28, _pilot_materials.textile,
		Vector3(0.93, 1.0, 0.91),
		Vector3(0.0, 0.0, side * deg_to_rad(-2.5))
	)
	_pilot_capsule(
		parent, "ShinGuard%s" % suffix, Vector3(side * 0.025, -0.535, -0.078),
		0.061, 0.285, _pilot_materials.hard_armor,
		Vector3(0.94, 1.0, 0.3)
	)
	_pilot_torus(
		parent, "AnkleSeal%s" % suffix, Vector3(side * 0.03, -0.615, 0.0),
		0.071, 0.087, _pilot_materials.rubber,
		Vector3(0.95, 1.0, 0.92)
	)
	_pilot_capsule(
		parent, "Boot%s" % suffix, Vector3(side * 0.03, -0.625, -0.1),
		0.09, 0.39, _pilot_materials.rubber,
		Vector3(0.92, 1.0, 0.94),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_capsule(
		parent, "BootArmor%s" % suffix, Vector3(side * 0.03, -0.595, -0.17),
		0.06, 0.27, _pilot_materials.ceramic,
		Vector3(0.92, 1.0, 0.42),
		Vector3(PI * 0.5, 0.0, 0.0)
	)
	_pilot_box(
		parent, "BootSole%s" % suffix, Vector3(side * 0.03, -0.7125, -0.1),
		Vector3(0.17, 0.035, 0.35), _pilot_materials.rubber
	)


func _pilot_material(
		albedo: Color,
		metallic: float,
		roughness: float,
		emission: Color = Color(0.0, 0.0, 0.0, 1.0),
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _pilot_mesh_instance(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		mesh: PrimitiveMesh,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.position = position
	instance.rotation = rotation_value
	instance.scale = scale_value
	instance.mesh = mesh
	var material_role := _get_pilot_material_role(material)
	instance.set_meta(&"pilot_generated", true)
	instance.set_meta(&"material_role", material_role)
	instance.set_meta(&"construction_role", _get_pilot_construction_role(material_role))
	parent.add_child(instance)
	return instance


func _get_pilot_material_role(material: Material) -> StringName:
	for key in _pilot_materials:
		if _pilot_materials[key] == material:
			return StringName(key)
	return &"unknown"


func _get_pilot_construction_role(material_role: StringName) -> StringName:
	match material_role:
		&"undersuit", &"textile", &"webbing":
			return &"fabric"
		&"soft_armor", &"rubber":
			return &"flexible"
		&"hard_armor", &"ceramic", &"amber":
			return &"hard"
		&"visor":
			return &"glazing"
		&"cyan_light", &"amber_light":
			return &"light"
		&"piping":
			return &"trim"
	return &"unknown"


func _pilot_capsule(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		radius: float,
		height: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 8
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_sphere(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		radius: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_cylinder(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		top_radius: float,
		bottom_radius: float,
		height: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 4
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_torus(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 10
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _pilot_box(
		parent: Node3D,
		part_name: String,
		position: Vector3,
		size: Vector3,
		material: Material,
		scale_value: Vector3 = Vector3.ONE,
		rotation_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _pilot_mesh_instance(
		parent, part_name, position, mesh, material, scale_value, rotation_value
	)


func _transformed_aabb(source: AABB, transform_value: Transform3D) -> AABB:
	var first_corner := transform_value * source.position
	var result := AABB(first_corner, Vector3.ZERO)
	for corner_index in range(1, 8):
		var corner := source.position + Vector3(
			source.size.x if (corner_index & 1) != 0 else 0.0,
			source.size.y if (corner_index & 2) != 0 else 0.0,
			source.size.z if (corner_index & 4) != 0 else 0.0
		)
		result = result.expand(transform_value * corner)
	return result


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO
	var movement_up := _get_movement_up_direction()
	var camera_forward := (-_camera_yaw.global_basis.z).slide(movement_up).normalized()
	if camera_forward.is_zero_approx():
		camera_forward = (-global_basis.z).slide(movement_up).normalized()
	var camera_right := camera_forward.cross(movement_up).normalized()
	return (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()


func _update_horizontal_velocity(direction: Vector3, sprinting: bool, delta: float) -> void:
	var speed := sprint_speed if sprinting else walk_speed
	var movement_up := _get_movement_up_direction()
	var tangent_direction := direction.slide(movement_up).normalized()
	var target_velocity := tangent_direction * speed
	var up_speed := velocity.dot(movement_up)
	var horizontal_velocity := velocity - movement_up * up_speed
	var accelerating := not direction.is_zero_approx()
	var acceleration := air_acceleration
	if is_on_floor():
		acceleration = ground_acceleration if accelerating else ground_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	velocity = horizontal_velocity + movement_up * up_speed


## Mounts a low lip that `move_and_slide()` has just refused, and does nothing
## else. Called immediately after the slide with the pre-slide state, so the
## slide itself remains the only mover; this either accepts the slide's result or
## replaces it with a position the capsule could have reached by stepping.
##
## Every bound here exists to keep the assist from becoming a climbing tool:
## it only runs while walking on a floor with control enabled and no upward
## speed, only when the slide was actually stopped by a wall, only when the
## destination is a floor by this body's own `floor_max_angle` measured against
## its current up direction (ship-local while aboard a `MovingInteriorFrame`),
## only when the whole capsule fits there, and only for a net rise inside
## [constant STEP_UP_MAX_HEIGHT] that also buys real forward progress. A lip with
## nothing walkable on top of it — a rail, a hull, the edge of a void — fails
## every one of those and is left exactly as solid as it was.
func _resolve_step_up(
		pre_move_transform: Transform3D,
		pre_move_velocity: Vector3,
		delta: float
	) -> bool:
	if not _control_enabled or _embodiment_state != EmbodimentState.ON_FOOT:
		return false
	if not is_on_wall() or not is_on_floor():
		return false
	var movement_up := _get_movement_up_direction()
	if pre_move_velocity.dot(movement_up) > 0.01:
		return false
	var intended := pre_move_velocity.slide(movement_up) * delta
	var intended_distance := intended.length()
	if intended_distance < STEP_UP_MIN_ADVANCE:
		return false
	var achieved := (global_position - pre_move_transform.origin).slide(movement_up)
	if achieved.length() >= intended_distance - STEP_UP_MIN_ADVANCE:
		return false

	var landing := _probe_step_up_landing(pre_move_transform, intended, movement_up)
	if landing.is_empty():
		return false

	global_position = (landing["transform"] as Transform3D).origin
	# Keep the tangent speed the wall just consumed; the body is grounded again,
	# so the vertical component is re-established by gravity on the next tick.
	velocity = pre_move_velocity.slide(movement_up)
	return true


## Up-forward-down capsule probe. Returns the accepted landing transform, or an
## empty dictionary when any bound fails. Uses `test_move` throughout so nothing
## is committed until every bound has passed.
func _probe_step_up_landing(
		pre_move_transform: Transform3D,
		intended: Vector3,
		movement_up: Vector3
	) -> Dictionary:
	var collision := KinematicCollision3D.new()

	# Lift one clearance past the limit so a lip of exactly STEP_UP_MAX_HEIGHT is
	# probed with the capsule above it rather than tangent to it. The accepted
	# rise is still clamped to STEP_UP_MAX_HEIGHT below, so this widens nothing.
	var lifted := pre_move_transform
	var lift := movement_up * (STEP_UP_MAX_HEIGHT + STEP_UP_MIN_CLEARANCE)
	if test_move(pre_move_transform, lift, collision):
		var lift_travel := collision.get_travel()
		if lift_travel.length() <= STEP_UP_MIN_CLEARANCE:
			return {}
		lifted = pre_move_transform.translated(lift_travel)
	else:
		lifted = pre_move_transform.translated(lift)

	# One physics tick of walking is a fraction of the capsule radius, so probing
	# only that far would still leave the body hanging off the lip and the drop
	# would find the floor it started on. Reach at least far enough to put the
	# capsule axis over the new surface.
	var forward := intended.normalized() * maxf(intended.length(), _step_probe_reach)
	var advanced := lifted
	if test_move(lifted, forward, collision):
		var forward_travel := collision.get_travel()
		if forward_travel.length() <= STEP_UP_MIN_ADVANCE:
			return {}
		advanced = lifted.translated(forward_travel)
	else:
		advanced = lifted.translated(forward)

	# Never step out over a void: the probe has to find something to stand on.
	var drop := -movement_up * (STEP_UP_MAX_HEIGHT + STEP_UP_MIN_CLEARANCE * 2.0)
	if not test_move(advanced, drop, collision):
		return {}
	if collision.get_normal().dot(movement_up) < cos(floor_max_angle):
		return {}

	var landed := advanced.translated(collision.get_travel())
	var offset := landed.origin - pre_move_transform.origin
	var rise := offset.dot(movement_up)
	if rise <= 0.001 or rise > STEP_UP_MAX_HEIGHT + 0.001:
		return {}
	var advance := offset.slide(movement_up)
	if advance.length() < STEP_UP_MIN_ADVANCE or advance.dot(intended) <= 0.0:
		return {}
	if advance.length() > _step_probe_reach + STEP_UP_MIN_ADVANCE:
		return {}
	return {"transform": landed, "rise": rise, "advance": advance.length()}


func _resolve_step_probe_reach() -> float:
	if _player_collision == null or not is_instance_valid(_player_collision):
		return 0.40
	var capsule := _player_collision.shape as CapsuleShape3D
	if capsule == null:
		return 0.40
	return capsule.radius + STEP_UP_MIN_CLEARANCE


## Frozen, inspectable contract for the locomotion step-up assist. Reported from
## the live body rather than from duplicated nominal constants so a future
## capsule or floor-angle change cannot silently stale it.
func get_step_up_assist_audit() -> Dictionary:
	var capsule_radius := 0.0
	var capsule_height := 0.0
	if _player_collision != null and is_instance_valid(_player_collision):
		var capsule := _player_collision.shape as CapsuleShape3D
		if capsule != null:
			capsule_radius = capsule.radius
			capsule_height = capsule.height
	return {
		"max_step_height": STEP_UP_MAX_HEIGHT,
		"min_clearance": STEP_UP_MIN_CLEARANCE,
		"min_advance": STEP_UP_MIN_ADVANCE,
		"probe_reach": _step_probe_reach,
		"capsule_radius": capsule_radius,
		"capsule_height": capsule_height,
		"floor_max_angle_rad": floor_max_angle,
		"movement_up": _get_movement_up_direction(),
		"requires_floor_contact": true,
		"requires_wall_contact": true,
		"requires_walkable_landing": true,
		"steps_into_void": false,
		# The capsule can only be placed where its lower sphere could have rolled.
		"within_capsule_radius": STEP_UP_MAX_HEIGHT <= capsule_radius,
	}


func _decelerate_horizontal_velocity(delta: float) -> void:
	var movement_up := _get_movement_up_direction()
	var up_speed := velocity.dot(movement_up)
	var horizontal_velocity := velocity - movement_up * up_speed
	var deceleration := ground_deceleration if is_on_floor() else air_acceleration
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	velocity = horizontal_velocity + movement_up * up_speed


func _apply_gravity(delta: float) -> void:
	var movement_up := _get_movement_up_direction()
	var up_speed := velocity.dot(movement_up)
	if is_on_floor():
		if up_speed < 0.0:
			velocity -= movement_up * up_speed
		return
	velocity += _get_effective_gravity() * gravity_multiplier * delta
	var downward_speed := -velocity.dot(movement_up)
	if downward_speed > terminal_velocity:
		velocity += movement_up * (downward_speed - terminal_velocity)


## MovingInteriorFrame sets CharacterBody3D.up_direction before this controller
## runs. All locomotion is resolved in that tangent plane, so a real occupant can
## walk and jump on a translating or rotated ship deck without a separate level.
func _get_movement_up_direction() -> Vector3:
	var result := up_direction.normalized()
	return result if result.is_finite() and not result.is_zero_approx() else Vector3.UP


func _get_effective_gravity() -> Vector3:
	if not has_meta(&"_moving_interior_frame_owner"):
		return get_gravity()
	var owner_ref: Variant = get_meta(&"_moving_interior_frame_owner")
	if owner_ref is WeakRef:
		var frame_owner: Variant = (owner_ref as WeakRef).get_ref()
		if is_instance_valid(frame_owner) and frame_owner.has_method("get_frame_gravity"):
			var frame_gravity: Variant = frame_owner.call("get_frame_gravity", self)
			if frame_gravity is Vector3 and (frame_gravity as Vector3).is_finite():
				return frame_gravity as Vector3
	return get_gravity()


func _update_facing(desired_direction: Vector3, delta: float) -> void:
	if not desired_direction.is_zero_approx():
		var local_direction := _visual_root.global_basis.inverse() * desired_direction
		_target_body_yaw = atan2(-local_direction.x, -local_direction.z)
	_body_pivot.rotation.y = lerp_angle(
		_body_pivot.rotation.y,
		_get_body_pivot_target_yaw(),
		1.0 - exp(-facing_speed * delta)
	)


func _update_authored_locomotion(sprinting: bool) -> void:
	var movement_up := _get_movement_up_direction()
	var horizontal_speed := (velocity - movement_up * velocity.dot(movement_up)).length()
	if not is_on_floor():
		var upward_speed := velocity.dot(movement_up)
		_set_motion_state(
			MOTION_JUMP if upward_speed > 0.25 else MOTION_AIRBORNE,
			MOTION_BLEND_TIME
		)
		return

	if horizontal_speed <= 0.15:
		_set_motion_state(MOTION_IDLE, MOTION_BLEND_TIME)
		return

	if sprinting or horizontal_speed > walk_speed * 1.08:
		_set_motion_state(
			MOTION_RUN,
			MOTION_BLEND_TIME,
			clampf(horizontal_speed / maxf(sprint_speed, 0.1), 0.72, 1.3)
		)
		return

	_set_motion_state(
		MOTION_WALK,
		MOTION_BLEND_TIME,
		clampf(horizontal_speed / maxf(walk_speed, 0.1), 0.62, 1.28)
	)


func _set_motion_state(
		state: StringName,
		blend_time: float,
		playback_rate: float = 1.0,
		restart: bool = false,
		sample_immediately: bool = false
		) -> void:
	if not is_finite(playback_rate) or playback_rate <= 0.0:
		push_error("Player motion playback rate must be finite and positive")
		return
	var prior_player := _motion_animation_player
	if not _ensure_motion_authority():
		return
	if prior_player != _motion_animation_player:
		restart = true
	if _motion_animation_player == null or not is_instance_valid(_motion_animation_player):
		return
	var assigned_state_matches := _motion_animation_player.assigned_animation == state
	var stopped_early := false
	if assigned_state_matches and not _motion_animation_player.is_playing():
		var assigned_clip := _motion_animation_player.get_animation(state)
		stopped_early = (
			assigned_clip != null
			and (
				assigned_clip.loop_mode != Animation.LOOP_NONE
				or _motion_animation_player.current_animation_position
					< assigned_clip.length - 0.002
			)
		)
	if (
		not restart
		and _motion_state == state
		and assigned_state_matches
		and not stopped_early
	):
		_motion_playback_rate = playback_rate
		_motion_animation_player.speed_scale = playback_rate
		return
	if not _motion_animation_player.has_animation(state):
		push_error("Player motion library is missing authored clip: %s" % state)
		return
	_motion_state = state
	_motion_playback_rate = playback_rate
	_motion_animation_player.speed_scale = playback_rate
	_motion_animation_player.play(state, maxf(0.0, blend_time))
	if restart:
		_motion_animation_player.seek(0.0, sample_immediately, true)
	elif sample_immediately:
		_motion_animation_player.advance(0.0)


func _get_accepted_imported_motion_player() -> AnimationPlayer:
	if (
		not _using_imported_pilot_presentation
		or _imported_presentation_rejected
		or _pilot_presentation == null
		or not is_instance_valid(_pilot_presentation)
	):
		return null
	return _live_imported_animation_player()


func _advance_motion_animation(delta: float) -> void:
	if not _ensure_motion_authority():
		return
	var expected_player := _motion_animation_player
	if expected_player == null or not is_instance_valid(expected_player):
		return
	if (
		not is_finite(expected_player.speed_scale)
		or expected_player.speed_scale <= 0.0
		or not is_equal_approx(expected_player.speed_scale, _motion_playback_rate)
	):
		expected_player.speed_scale = _motion_playback_rate
	if not _motion_state.is_empty() and expected_player.has_animation(_motion_state):
		var assigned_state_matches := expected_player.assigned_animation == _motion_state
		var stopped_early := false
		if assigned_state_matches and not expected_player.is_playing():
			var clip := expected_player.get_animation(_motion_state)
			stopped_early = (
				clip != null
				and (
					clip.loop_mode != Animation.LOOP_NONE
					or expected_player.current_animation_position < clip.length - 0.002
				)
			)
		if not assigned_state_matches or stopped_early:
			expected_player.play(_motion_state, 0.0)
	expected_player.advance(delta)


func _set_target_camera_distance(distance: float) -> void:
	_requested_camera_distance = clampf(
		distance,
		minimum_camera_distance,
		maximum_camera_distance
	)
	_apply_camera_distance_ceiling()


## Applies the current space's ceiling to the player's requested distance. Never
## raises the request, so zooming out inside a cabin does nothing surprising and
## the request is still there on the way out.
func _apply_camera_distance_ceiling() -> void:
	_target_camera_distance = minf(_requested_camera_distance, _camera_distance_ceiling)


## The boom distance the player asked for, before any interior ceiling.
func get_requested_camera_distance() -> float:
	return _requested_camera_distance


## The boom distance actually being eased toward right now.
func get_target_camera_distance() -> float:
	return _target_camera_distance


func _set_camera_distance_ceiling(ceiling: float) -> void:
	var validated := ceiling
	if is_nan(validated) or is_inf(validated):
		validated = maximum_camera_distance
	_camera_distance_ceiling = clampf(validated, 0.5, maximum_camera_distance)
	_apply_camera_distance_ceiling()
	# Shorten immediately rather than easing outward-to-inward across a doorway:
	# the transition into a cabin already teleports the body, so the boom being
	# long for a fifth of a second is exactly the frame that ends up inside a
	# bulkhead. Growing back on the way out stays eased.
	if _spring_arm != null and _spring_arm.spring_length > _target_camera_distance:
		_spring_arm.spring_length = _target_camera_distance
