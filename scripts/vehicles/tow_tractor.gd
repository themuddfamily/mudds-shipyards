class_name TowTractor
extends CharacterBody3D

## The yard's little orange tow tractor, made drivable.
##
## `modern_interpretation`. No source authenticates a driveable ground vehicle at
## Mudds Shipyards; the prop this replaces was itself an invented dressing detail.
## Nothing here claims otherwise, and the tractor is deliberately *not* a fifth
## spacecraft: it owns no berth lease, no landing contract, no weapon, no hull,
## and no regeneration lifecycle. It is a deck toy with one job — be fun to get
## into and drive around the station.
##
## Three seams are reused rather than reinvented:
##
## - **Boarding.** The child [TowTractorDriverStation] is an ordinary layer-4
##   station interactable, exactly like the pressure doors, so `GameFlow` finds
##   it through the same `_refresh_interaction_targets()` /
##   `_find_station_interaction_candidate()` path that already exists. It is not a
##   [ShipBoardingArea], because that component's contract resolves to a craft the
##   fleet registry owns; a tractor must never appear there.
## - **Riding.** The driver seat is a live [Node3D] anchor handed to
##   `PlayerController.begin_boarding()`. That is the same mechanism the four
##   craft use to keep the visible pilot aboard while the hull moves, so no
##   reparenting and no second interior frame is needed.
## - **Recovery.** When this vehicle decides it has left the station, it says so
##   and `GameFlow` performs the *same* pilot recall the destroyed-craft path
##   performs. See [signal deck_recovery_required].
##
## ## Why the player cannot be stranded
##
## The station is full of deliberate voids, so a vehicle that can drive into one
## is a P0 soft-lock. Two independent guards close that, and the second does not
## depend on the first being correct:
##
## 1. **The deck-edge interlock refuses to leave the deck.** Every tick, before
##    the body moves, a ray is cast from a point one vehicle-length-plus-margin
##    ahead *along the current deck tangent* — so it follows a ramp instead of
##    shooting off into space above one. If nothing solid is within
##    [constant EDGE_PROBE_DROP] below that point, the drive component is dropped
##    to zero for the tick. The tractor stops short of the lip; it does not fall.
## 2. **The recovery net catches everything else.** Independently of the
##    interlock, of geometry, and of how the vehicle got there, falling below
##    [constant RECOVERY_FLOOR_Y] or staying off the floor for longer than
##    [constant MAXIMUM_AIRBORNE_SECONDS] raises [signal deck_recovery_required]
##    exactly once. `GameFlow` then recalls the driver to the on-foot spawn and
##    resets this vehicle to its authored parking spot. Both thresholds are
##    accumulated from the physics delta; no wall clock participates.
##
## The second guard is what makes the claim provable rather than probable: it
## fires from the vehicle's own pose, so a bug in the first guard degrades the
## experience (an unintended fall) without ever costing the player their body.
##
## ## Step-up rule
##
## `PlayerController` grants itself a 0.30 m step-up assist so a walking pilot is
## not stopped by a kerb. This vehicle deliberately does **not** inherit that and
## implements no step assist of its own: it is a small-wheeled tug, and the thing
## a walking pilot steps over is exactly the thing a tug should be stopped by.
## What it climbs instead is *slope* — [constant FLOOR_MAXIMUM_ANGLE_DEGREES] is
## wide enough for the junction access ramp and the authored approach-threshold
## aprons, which are the surfaces the station uses to join decks at different
## heights. Rendered evidence: the tractor drives up the ramp; it stops at a kerb.

## Emitted when a player-owned actor asks to take the driver seat. `GameFlow`
## owns the transition; this vehicle never touches player control or the camera
## authority by itself.
signal board_requested(actor: Node)

## Emitted when the seated driver presses interact. `GameFlow` decides whether
## the release is currently safe.
signal exit_requested()

## Emitted at most once per departure when this vehicle has left the station and
## can no longer return under its own power. Cleared by
## [method recover_to_home_transform].
signal deck_recovery_required(reason: StringName)

## Palette shared with the station hub so the tractor still reads as yard plant.
const CHASSIS_COLOR := Color("ff9f43")
const CAB_COLOR := Color("dce8e4")
const TYRE_COLOR := Color("03080d")
const TRIM_COLOR := Color("0b1d2a")
const BEACON_COLOR := Color("48dbe2")
const PANEL_SURFACE_SCALE := 0.22

## Body plan. The origin sits on the wheel contact plane and local -Z is the
## direction of travel, so every offset below is readable as "metres forward /
## up / to port" without a mental transform.
##
## The layout is an *open* tug — bonnet forward, driver sitting behind it on an
## exposed seat with a wheel in front of them, flat tow deck aft. The first build
## carried the prop's enclosed ivory cab over literally, and the result was a
## pilot perched on top of a solid box with their hands in the air, because the
## seat anchor and the cab occupied the same volume. An open seat is both the
## correct read for a yard tug and the one that puts the authored seated pose to
## work: the steering wheel is placed where the clip's hands already are.
const CHASSIS_SIZE := Vector3(2.3, 1.1, 3.8)
const CHASSIS_CENTER_Y := 0.65
const BONNET_SIZE := Vector3(1.9, 0.66, 1.25)
const BONNET_CENTER := Vector3(0.0, 1.53, -1.2)
const SEAT_PAD_SIZE := Vector3(1.12, 0.18, 0.8)
const SEAT_PAD_CENTER := Vector3(0.0, 1.29, 0.12)
const SEAT_BACK_SIZE := Vector3(1.12, 0.78, 0.18)
const SEAT_BACK_CENTER := Vector3(0.0, 1.72, 0.61)
const STEERING_WHEEL_CENTER := Vector3(0.0, 1.74, -0.5)
const STEERING_WHEEL_RADIUS := 0.27
const WHEEL_RADIUS := 0.4
const WHEEL_WIDTH := 0.25
const WHEEL_HALF_TRACK := 1.15
const WHEEL_AXLE_Z := 1.05
const BODY_PROBE_RADIUS := 1.9

## Handling. Provisional modern values chosen for feel, not recovered data.
@export_range(1.0, 30.0, 0.5) var maximum_forward_speed := 11.5
@export_range(1.0, 20.0, 0.5) var maximum_reverse_speed := 5.0
@export_range(1.0, 60.0, 0.5) var drive_acceleration := 13.0
@export_range(1.0, 80.0, 0.5) var brake_deceleration := 22.0
@export_range(0.5, 40.0, 0.5) var coast_deceleration := 7.0
@export_range(10.0, 240.0, 1.0) var maximum_steer_rate_degrees := 104.0
@export_range(0.0005, 0.02, 0.0001) var mouse_sensitivity := 0.0025

## Speed at which steering authority is fully developed. Below it the rate falls
## off toward [constant STATIONARY_STEER_FRACTION] so the tug still pivots while
## crawling — a real tug would not, but refusing to turn at walking pace makes a
## deck vehicle feel broken rather than heavy.
const STEER_SPEED_REFERENCE := 6.0
const STATIONARY_STEER_FRACTION := 0.35

const FLOOR_MAXIMUM_ANGLE_DEGREES := 46.0
const FLOOR_SNAP_LENGTH := 0.6
const DECK_ALIGNMENT_RATE := 9.0

## Deck-edge interlock. `EDGE_PROBE_DROP` is the deepest step down that still
## counts as "there is deck there": generous enough to enter a down-ramp or a
## kerb-height change, far short of the station's actual voids, which have no
## floor beneath them at any depth.
const EDGE_PROBE_LOOKAHEAD := 1.15
const EDGE_PROBE_RISE := 0.9
const EDGE_PROBE_DROP := 2.2

## Recovery net. Mirrors the on-foot floor `GameFlow` already uses for a walking
## player who falls off the station.
const RECOVERY_FLOOR_Y := -24.0
const MAXIMUM_AIRBORNE_SECONDS := 2.0

## The driver may only step off a stationary tractor standing on real floor.
const EXIT_MAXIMUM_SPEED := 0.75

## Local candidate footfalls for the dismount, tried in order. Each is validated
## against real deck before it is offered, so an exit can never place the player
## over a void even if the tractor is parked on a lip.
const EXIT_CANDIDATE_OFFSETS: Array[Vector3] = [
	Vector3(-1.95, 0.0, 0.4),
	Vector3(1.95, 0.0, 0.4),
	Vector3(0.0, 0.0, 2.9),
	Vector3(0.0, 0.0, -2.9),
]
const EXIT_PROBE_RISE := 1.2
const EXIT_PROBE_DROP := 1.2

const BOARDING_ENTRY_OFFSET := Vector3(-1.95, 0.0, 0.4)
## Where a walking pilot naturally ends up when they come to use the tractor:
## clear of the hull, level with the driver step. Mirrors
## `HeroShip.get_boarding_position()` so tests and tooling can walk to a vehicle
## the same way they walk to a craft.
const BOARDING_APPROACH_OFFSET := Vector3(-3.0, 0.0, 0.4)

var _driven := false
var _forward_speed := 0.0
var _airborne_seconds := 0.0
var _vertical_speed := 0.0
var _recovery_reported := false
var _edge_interlock_engaged := false
## Sign of the drive input the driver is currently holding, used so the deck-edge
## interlock probes an intent the interlock itself has already zeroed.
var _throttle_direction := 0.0
var _deck_normal := Vector3.UP
var _home_transform := Transform3D.IDENTITY
var _camera_yaw_offset := 0.0
var _camera_pitch := deg_to_rad(-14.0)
var _mesh_cache: Dictionary = {}
var _materials: Dictionary = {}

@onready var _driver_seat: Node3D = $DriverSeat
@onready var _driver_station: TowTractorDriverStation = $DriverStation
@onready var _camera_yaw: Node3D = $CameraRig
@onready var _camera_pitch_pivot: Node3D = $CameraRig/CameraPitch
@onready var _camera: Camera3D = $CameraRig/CameraPitch/CameraArm/Camera3D


func _ready() -> void:
	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(FLOOR_MAXIMUM_ANGLE_DEGREES)
	floor_snap_length = FLOOR_SNAP_LENGTH
	floor_stop_on_slope = true
	floor_block_on_wall = true
	slide_on_ceiling = false
	# The prop this replaces was a `WORLD`-layer static body, so keeping that
	# layer preserves exactly what already collided with it: the walking player,
	# the four craft, and hitscan treating it as scenery. It masks `WORLD` alone —
	# a vehicle that pushed a CharacterBody player around would be two solvers
	# fighting over the same metre.
	collision_layer = PhysicsLayers.WORLD
	collision_mask = PhysicsLayers.WORLD
	_home_transform = global_transform
	_camera_pitch_pivot.rotation.x = _camera_pitch
	_camera.current = false
	_build_materials()
	_build_visual()
	_refresh_driver_station_availability()


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_update_deck_normal(delta)
	if _driven:
		_read_drive_input(delta)
	else:
		_forward_speed = move_toward(_forward_speed, 0.0, brake_deceleration * delta)
		_throttle_direction = 0.0

	var plane_forward := _deck_tangent_forward()
	# Vertical motion is held as its own state rather than read back out of
	# `velocity.y`. On a ramp the deck tangent carries a vertical component of its
	# own, so re-integrating gravity from the composed velocity would fold the
	# climb rate into the fall speed and make a tractor that drove up a slope
	# behave as if it had been thrown.
	if is_on_floor():
		_airborne_seconds = 0.0
		_vertical_speed = 0.0
	else:
		_airborne_seconds += delta
		_vertical_speed -= _get_gravity_magnitude() * delta
	if is_on_ceiling() and _vertical_speed > 0.0:
		_vertical_speed = 0.0

	# Probe the direction the driver is *asking* for, not only the one already
	# being travelled. Once the interlock has zeroed the drive speed there is no
	# travel left to probe, so a speed-only test would report the edge clear on
	# the next tick and let the throttle push the tractor over it one tick at a
	# time. Held throttle therefore keeps the interlock engaged and the prompt
	# steady, while releasing it — or selecting reverse — clears it immediately.
	var probe_speed := _forward_speed
	if is_zero_approx(probe_speed):
		probe_speed = _throttle_direction
	_edge_interlock_engaged = _blocked_by_deck_edge(plane_forward * probe_speed)
	if _edge_interlock_engaged:
		_forward_speed = 0.0

	velocity = plane_forward * _forward_speed + Vector3.UP * _vertical_speed
	move_and_slide()
	# A wall or a refused edge takes the drive speed with it; without this the
	# stored speed keeps the tractor pinned against geometry at full throttle.
	if is_on_wall() and absf(_forward_speed) > 0.0:
		_forward_speed = move_toward(_forward_speed, 0.0, brake_deceleration * delta)
	_check_recovery_conditions()


func _unhandled_input(event: InputEvent) -> void:
	if not _driven or event is not InputEventMouseMotion:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	_camera_yaw_offset = wrapf(
		_camera_yaw_offset - motion.relative.x * mouse_sensitivity,
		-PI,
		PI
	)
	_camera_pitch = clampf(
		_camera_pitch - motion.relative.y * mouse_sensitivity,
		deg_to_rad(-46.0),
		deg_to_rad(38.0)
	)
	_camera_pitch_pivot.rotation.x = _camera_pitch
	get_viewport().set_input_as_handled()


## Hands the chase camera and the drive inputs to, or back from, the seated
## driver. Releasing always parks the drive speed so a re-board cannot inherit
## the throttle the previous session left behind.
func set_driven(value: bool) -> void:
	if _driven == value:
		return
	_driven = value
	_camera.current = value
	if not value:
		_forward_speed = 0.0
		_throttle_direction = 0.0
		_edge_interlock_engaged = false
	else:
		_camera_yaw_offset = 0.0
		_camera_yaw.rotation.y = 0.0
	_refresh_driver_station_availability()


func is_driven() -> bool:
	return _driven


## True when a walking player may take the seat. A vehicle that has already
## reported itself lost stays closed until it has been recovered.
func is_boardable() -> bool:
	return not _driven and not _recovery_reported


## True when the seat may be released: standing on real floor, at rest.
func can_release_driver() -> bool:
	return is_on_floor() and absf(_forward_speed) <= EXIT_MAXIMUM_SPEED


func is_edge_interlock_engaged() -> bool:
	return _edge_interlock_engaged


func get_drive_speed() -> float:
	return _forward_speed


func get_airborne_seconds() -> float:
	return _airborne_seconds


func has_reported_recovery() -> bool:
	return _recovery_reported


func get_home_transform() -> Transform3D:
	return _home_transform


func get_camera() -> Camera3D:
	return _camera


func get_driver_station() -> TowTractorDriverStation:
	return _driver_station


func set_camera_fov(field_of_view: float) -> void:
	_camera.fov = clampf(field_of_view, 55.0, 110.0)


## World-space footfall the boarding animation walks through on its way to the
## seat, matching `HeroShip.get_boarding_entry_transform()`'s contract.
func get_boarding_entry_transform() -> Transform3D:
	return Transform3D(global_basis.orthonormalized(), to_global(BOARDING_ENTRY_OFFSET))


## Where a walking pilot stands to use the driver step.
func get_boarding_position() -> Vector3:
	return to_global(BOARDING_APPROACH_OFFSET)


## Live seat frame. Returned as the node rather than a transform so the visible
## driver stays aboard while the tractor moves, exactly as the craft seats do.
func get_driver_seat_anchor() -> Node3D:
	return _driver_seat


## A dismount that is guaranteed to stand on deck.
##
## Each candidate offset is only offered once a downward ray has found solid
## world geometry under it, so the player cannot be placed over one of the
## station's voids. `fallback` is the coordinator's own safe ground — in
## production the on-foot spawn — and is used when the tractor is parked
## somewhere none of the candidates are backed by floor.
func get_exit_transform(fallback: Transform3D = Transform3D.IDENTITY) -> Transform3D:
	for offset in EXIT_CANDIDATE_OFFSETS:
		var candidate := to_global(offset)
		var ground := _probe_ground(candidate, EXIT_PROBE_RISE, EXIT_PROBE_DROP)
		if ground.is_finite():
			return Transform3D(_facing_the_tractor_from(ground), ground)
	return fallback


## Facing for a dismount: turned back toward the vehicle.
##
## Inheriting the tractor's own heading looks harmless and is not. The player's
## third-person boom sits behind whatever they face, so stepping off still facing
## down the deck puts the boom straight through the hull it just left, and the
## first frame on foot is a spring arm crushed against the driver's own back.
## Turning to face the tractor puts the boom over the open deck the dismount was
## validated against, and puts the thing they were just driving — and its prompt —
## in front of them.
func _facing_the_tractor_from(exit_position: Vector3) -> Basis:
	var toward := global_position - exit_position
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return global_basis.orthonormalized()
	return Basis.looking_at(toward.normalized(), Vector3.UP)


## Restores the authored parking spot and re-arms the recovery report.
func recover_to_home_transform() -> void:
	set_driven(false)
	global_transform = _home_transform
	velocity = Vector3.ZERO
	_forward_speed = 0.0
	_vertical_speed = 0.0
	_airborne_seconds = 0.0
	_recovery_reported = false
	_throttle_direction = 0.0
	_edge_interlock_engaged = false
	_deck_normal = Vector3.UP
	_camera_yaw_offset = 0.0
	_camera_yaw.rotation.y = 0.0
	_refresh_driver_station_availability()
	reset_physics_interpolation()


## Called by the driver station when a walking player interacts with it.
func request_boarding(actor: Node) -> bool:
	if not is_boardable():
		return false
	board_requested.emit(actor)
	return true


func get_interaction_prompt() -> String:
	# Recovery is reported before the coordinator has finished releasing the seat,
	# so it outranks the occupied state: a lost tractor must never read as one a
	# passer-by could climb into.
	if _recovery_reported:
		return "[ ---- ]  TOW TRACTOR RECOVERING"
	if _driven:
		return ""
	return "[ E ]  DRIVE THE TOW TRACTOR"


## Keeps the walk-up interaction surface in step with whether the seat can
## actually be taken.
func _refresh_driver_station_availability() -> void:
	if is_instance_valid(_driver_station):
		_driver_station.set_available(is_boardable())


func _read_drive_input(delta: float) -> void:
	var throttle := Input.get_axis(&"move_back", &"move_forward")
	_throttle_direction = signf(throttle)
	var braking := Input.is_action_pressed(&"brake") or Input.is_action_pressed(&"jump")
	if Input.is_action_just_pressed(&"interact"):
		exit_requested.emit()

	if braking:
		_forward_speed = move_toward(_forward_speed, 0.0, brake_deceleration * delta)
	elif throttle > 0.0:
		_forward_speed = move_toward(
			_forward_speed,
			maximum_forward_speed * throttle,
			drive_acceleration * delta
		)
	elif throttle < 0.0:
		_forward_speed = move_toward(
			_forward_speed,
			maximum_reverse_speed * throttle,
			drive_acceleration * delta
		)
	else:
		_forward_speed = move_toward(_forward_speed, 0.0, coast_deceleration * delta)

	var steer_input := Input.get_axis(&"move_right", &"move_left")
	if not is_zero_approx(steer_input):
		var speed_fraction := clampf(
			absf(_forward_speed) / STEER_SPEED_REFERENCE,
			0.0,
			1.0
		)
		var authority := lerpf(STATIONARY_STEER_FRACTION, 1.0, speed_fraction)
		# Steering follows the wheels, so reversing mirrors it exactly as a real
		# tug does. The threshold rather than `signf` keeps a crawling tractor
		# steering forward instead of flipping about zero.
		var travel_sign := -1.0 if _forward_speed < -0.05 else 1.0
		var yaw := steer_input * travel_sign * authority \
			* deg_to_rad(maximum_steer_rate_degrees) * delta
		_apply_deck_yaw(yaw)

	# Ease the mouse orbit back behind the tractor while it is actually driving,
	# so a player who looked sideways is not left steering blind.
	if absf(_forward_speed) > 0.5:
		_camera_yaw_offset = move_toward(
			_camera_yaw_offset,
			0.0,
			deg_to_rad(48.0) * delta
		)
	_camera_yaw.rotation.y = _camera_yaw_offset


func _get_gravity_magnitude() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))


func _update_deck_normal(delta: float) -> void:
	var target := get_floor_normal() if is_on_floor() else Vector3.UP
	if not target.is_finite() or target.length_squared() < 0.000001:
		target = Vector3.UP
	_deck_normal = _deck_normal.lerp(target, clampf(DECK_ALIGNMENT_RATE * delta, 0.0, 1.0))
	if _deck_normal.length_squared() < 0.000001:
		_deck_normal = Vector3.UP
	_deck_normal = _deck_normal.normalized()
	_align_to_deck(_deck_tangent_forward())


## Projects the vehicle's own forward onto the plane of the deck under it, which
## is what keeps drive input tangent to a ramp instead of into or above it.
func _deck_tangent_forward() -> Vector3:
	var forward := -global_basis.z
	var tangent := forward - _deck_normal * forward.dot(_deck_normal)
	if tangent.length_squared() < 0.000001:
		return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD
	return tangent.normalized()


func _apply_deck_yaw(yaw: float) -> void:
	if is_zero_approx(yaw):
		return
	_align_to_deck(_deck_tangent_forward().rotated(_deck_normal, yaw))


func _align_to_deck(forward: Vector3) -> void:
	if forward.length_squared() < 0.000001:
		return
	if absf(forward.normalized().dot(_deck_normal)) > 0.999:
		return
	global_basis = Basis.looking_at(forward, _deck_normal)


## The deck-edge interlock. See the class documentation for why this is the
## first of two independent guards rather than the only one.
func _blocked_by_deck_edge(travel: Vector3) -> bool:
	if not is_on_floor() or travel.length_squared() < 0.000001:
		return false
	var direction := travel.normalized()
	var probe_point := global_position + direction * (BODY_PROBE_RADIUS + EDGE_PROBE_LOOKAHEAD)
	return not _probe_ground(probe_point, EDGE_PROBE_RISE, EDGE_PROBE_DROP).is_finite()


## Solid world geometry beneath `point`, or `Vector3.INF` when there is none.
## The ray runs along the deck normal rather than world down so it follows a
## ramp the tractor is already standing on.
func _probe_ground(point: Vector3, rise: float, drop: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(
		point + _deck_normal * rise,
		point - _deck_normal * drop,
		PhysicsLayers.WORLD
	)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return hit.get("position", Vector3.INF) as Vector3


## The recovery net. Independent of the interlock, of geometry, and of how the
## vehicle reached this pose.
func _check_recovery_conditions() -> void:
	if _recovery_reported:
		return
	var reason := &""
	if global_position.y < RECOVERY_FLOOR_Y or not global_position.is_finite():
		reason = &"fell_below_station"
	elif _airborne_seconds > MAXIMUM_AIRBORNE_SECONDS:
		reason = &"airborne_beyond_limit"
	if reason.is_empty():
		return
	_recovery_reported = true
	_refresh_driver_station_availability()
	deck_recovery_required.emit(reason)


func _build_materials() -> void:
	_materials["chassis"] = _panel_material(CHASSIS_COLOR, 0.16, 0.52)
	_materials["cab"] = _panel_material(CAB_COLOR, 0.06, 0.6)
	_materials["trim"] = _panel_material(TRIM_COLOR, 0.32, 0.5)
	_materials["tyre"] = _plain_material(TYRE_COLOR, 0.05, 0.88)
	_materials["beacon"] = _plain_material(BEACON_COLOR, 0.05, 0.34, BEACON_COLOR, 1.7)


func _panel_material(
		color: Color,
		metallic: float,
		roughness: float
	) -> StandardMaterial3D:
	var material := _plain_material(color, metallic, roughness)
	StationSurfaceKit.apply_panel_triplanar(material, PANEL_SURFACE_SCALE)
	return material


func _plain_material(
		color: Color,
		metallic: float,
		roughness: float,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


## Rebuilds the tractor out of the shared station surface kit. The prop this
## replaces used raw boxes and cylinders, so every edge on it was a zero-width
## 90° line with no pixels to hold a highlight; the kit's chamfer and the
## registered triplanar panel recipe are the whole reason it now reads as
## manufactured yard plant rather than shaded primitives. Winding comes from the
## kit's emission order, which `tests/station_surface_winding_test.gd` guards.
func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	_mesh_box(visual, "Chassis", Vector3(0.0, CHASSIS_CENTER_Y, 0.0), CHASSIS_SIZE, "chassis")
	_mesh_box(visual, "Bonnet", BONNET_CENTER, BONNET_SIZE, "cab")
	_mesh_box(
		visual,
		"BonnetVent",
		BONNET_CENTER + Vector3(0.0, BONNET_SIZE.y * 0.5, -0.1),
		Vector3(1.3, 0.05, 0.5),
		"trim"
	)
	_mesh_box(visual, "SeatPad", SEAT_PAD_CENTER, SEAT_PAD_SIZE, "trim")
	_mesh_box(visual, "SeatBack", SEAT_BACK_CENTER, SEAT_BACK_SIZE, "trim")
	# The steering column and wheel sit exactly where the authored seated-control
	# pose already puts the driver's hands, so the borrowed clip reads as steering
	# rather than as someone holding nothing.
	_mesh_box(
		visual,
		"SteeringColumn",
		Vector3(0.0, 1.5, -0.42),
		Vector3(0.13, 0.5, 0.13),
		"trim"
	)
	var steering_wheel := _mesh_cylinder(
		visual,
		"SteeringWheel",
		STEERING_WHEEL_CENTER,
		STEERING_WHEEL_RADIUS,
		0.06,
		"trim"
	)
	steering_wheel.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	_mesh_box(
		visual,
		"TowDeck",
		Vector3(0.0, 1.24, 1.36),
		Vector3(1.85, 0.12, 1.0),
		"trim"
	)
	_mesh_box(
		visual,
		"HitchBar",
		Vector3(0.0, 0.5, 2.02),
		Vector3(0.9, 0.18, 0.36),
		"trim"
	)
	for side in [-1.0, 1.0]:
		_mesh_box(
			visual,
			"SideStep",
			Vector3(side * 1.28, 0.32, 0.4),
			Vector3(0.34, 0.1, 1.2),
			"trim"
		)
		_mesh_box(
			visual,
			"SeatRail",
			Vector3(side * 0.62, 1.5, 0.61),
			Vector3(0.1, 0.42, 0.1),
			"chassis"
		)
		for axle_side in [-1.0, 1.0]:
			var wheel := _mesh_cylinder(
				visual,
				"Wheel",
				Vector3(side * WHEEL_HALF_TRACK, WHEEL_RADIUS, axle_side * WHEEL_AXLE_Z),
				WHEEL_RADIUS,
				WHEEL_WIDTH,
				"tyre"
			)
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_mesh_box(
		visual,
		"BeaconMast",
		Vector3(0.72, 1.98, -1.2),
		Vector3(0.09, 0.24, 0.09),
		"trim"
	)
	_mesh_cylinder(
		visual,
		"Beacon",
		Vector3(0.72, 2.2, -1.2),
		0.11,
		0.22,
		"beacon"
	)


func _mesh_box(
		parent: Node3D,
		node_name: String,
		mesh_position: Vector3,
		size: Vector3,
		material_key: String
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = mesh_position
	instance.mesh = StationSurfaceKit.rounded_box_mesh_cached(size, _mesh_cache)
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _mesh_cylinder(
		parent: Node3D,
		node_name: String,
		mesh_position: Vector3,
		radius: float,
		height: float,
		material_key: String
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = mesh_position
	instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius,
		radius,
		height,
		24,
		_mesh_cache
	)
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance
