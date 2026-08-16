extends SceneTree

## Focused suite for the drivable yard tow tractor.
##
## The station's own geometry is being actively corrected by a parallel pass, so
## every handling and safety assertion here runs against a synthetic deck this
## suite builds itself: a flat slab with one genuine void edge, one 0.25 m kerb,
## and one 22° ramp. That keeps the *rules* under test — climbs slope, is stopped
## by a kerb, refuses a void, recovers from a fall — independent of where the
## live station happens to put its edges this week.
##
## Every behaviour group carries a red witness: a paired case that the assertion
## would also pass if the guard under test were vacuously true (always block,
## always emit, always refuse). A guard that cannot be observed *not* firing is
## not evidence of anything.

const TRACTOR_SCENE := preload("res://scenes/world/tow_tractor.tscn")

## Synthetic deck plan. The obstacle course sits in its own lane so the open-deck
## handling and deck-edge cases are never accidentally measuring a kerb.
const DECK_HALF_LENGTH := 40.0
const DECK_HALF_WIDTH := 20.0
const OPEN_LANE_Z := -10.0
const OBSTACLE_LANE_Z := 12.0
const OBSTACLE_LANE_WIDTH := 12.0
const KERB_X := -8.0
const KERB_HEIGHT := 0.25
const RAMP_START_X := 12.0
const RAMP_ANGLE_DEGREES := 22.0
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _root: Node3D
var _tractor: TowTractor


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_synthetic_deck()
	await physics_frame
	await physics_frame

	_check_construction_contract()
	_check_authority_exclusions()
	await _check_handling()
	await _check_deck_edge_interlock()
	await _check_slope_and_kerb()
	await _check_seat_contract()
	await _check_recovery_net()

	_release_inputs()
	_root.queue_free()
	await process_frame
	_finish()


# ---------------------------------------------------------------- construction


func _check_construction_contract() -> void:
	_check(_tractor is CharacterBody3D, "the tractor is a physical CharacterBody3D, not a marker or a static prop")
	_check(
		_tractor.collision_layer == PhysicsLayers.WORLD
		and _tractor.collision_mask == PhysicsLayers.WORLD,
		"the tractor keeps the replaced prop's World layer and masks only world geometry"
	)
	var station := _tractor.get_driver_station()
	_check(station != null, "the tractor exposes a driver station")
	var station_node: Node = station
	_check(
		station_node is not ShipBoardingArea,
		"the driver station is not a ShipBoardingArea, so it cannot reach the craft boarding path"
	)
	_check(
		station.collision_layer == PhysicsLayers.INTERACTABLE_AREA_LAYER
		and station.collision_mask == PhysicsLayers.INTERACTABLE_AREA_MASK,
		"the driver station is an interaction query surface, never a solid body"
	)
	_check(
		station.has_method(&"get_interaction_prompt") and station.has_method(&"interact"),
		"the driver station advertises the same prompt/interact pair the station doors use"
	)
	_check(
		station.get_vehicle() == _tractor,
		"the driver station resolves back to its own vehicle"
	)

	# Surface treatment. The prop this replaces was raw boxes and cylinders.
	var visual := _tractor.get_node_or_null("Visual") as Node3D
	_check(visual != null, "the tractor builds a visual hierarchy")
	var box_count := 0
	var cylinder_count := 0
	var raw_primitives := 0
	for child in visual.get_children():
		var instance := child as MeshInstance3D
		if instance == null:
			continue
		if instance.mesh is BoxMesh or instance.mesh is CylinderMesh:
			raw_primitives += 1
		elif StationSurfaceKit.is_cylindrical_mesh(instance.mesh):
			cylinder_count += 1
		elif instance.mesh is ArrayMesh:
			box_count += 1
	_check(box_count >= 5, "the tractor's boxed stock is built by the shared chamfered-box builder")
	_check(cylinder_count >= 4, "the four wheels are built by the shared chamfered-cylinder builder")
	_check(raw_primitives == 0, "no unbevelled engine primitive survives in the tractor")

	var chassis_material := _tractor.get_node("Visual/Chassis").material_override as StandardMaterial3D
	_check(
		chassis_material != null
		and chassis_material.uv1_triplanar
		and chassis_material.uv1_world_triplanar,
		"the chassis binds the registered world-space triplanar panel family"
	)
	_check(
		chassis_material != null
		and chassis_material.normal_enabled
		and is_equal_approx(chassis_material.normal_scale, StationSurfaceKit.PANEL_NORMAL_SCALE)
		and is_equal_approx(StationSurfaceKit.PANEL_NORMAL_SCALE, 1.0),
		"the panel recipe is bound at the registered normal scale of 1.0"
	)
	# Red witness for the recipe check: an untextured material must fail the same
	# assertion, so a null-map fallback cannot be mistaken for a bound recipe.
	var bare := StandardMaterial3D.new()
	_check(
		not bare.uv1_triplanar and not bare.normal_enabled,
		"red witness: a plain material does not satisfy the panel-recipe assertion"
	)


## The whole point of keeping this a ground vehicle. If any of these start
## passing, the tractor has been handed craft authority and the berth suites will
## be the next thing to notice.
func _check_authority_exclusions() -> void:
	var vehicle_node: Node = _tractor
	_check(vehicle_node is not HeroShip, "the tractor is not a HeroShip")
	for forbidden in [
		&"get_home_berth_id",
		&"get_ship_definition",
		&"get_ship_id",
		&"request_berth_landing",
		&"get_landing_contract_report",
		&"apply_damage",
		&"get_telemetry",
		&"request_engine_start",
		&"reset_for_reuse",
	]:
		_check(
			not _tractor.has_method(forbidden),
			"the tractor exposes no %s authority" % forbidden
		)
	# Red witness: the same `has_method` probe must return true for the methods the
	# tractor genuinely owns, or the exclusions above prove nothing.
	for expected in [&"is_boardable", &"get_driver_seat_anchor", &"recover_to_home_transform"]:
		_check(
			_tractor.has_method(expected),
			"red witness: the exclusion probe still finds the tractor's own %s" % expected
		)


# -------------------------------------------------------------------- handling


func _check_handling() -> void:
	_place(Vector3(0.0, 0.2, OPEN_LANE_Z), 90.0)
	_tractor.set_driven(true)
	await _settle(6)

	var start := _tractor.global_position
	Input.action_press(&"move_forward")
	await _advance(70)
	_check(
		is_equal_approx(_tractor.get_drive_speed(), _tractor.maximum_forward_speed),
		"held throttle reaches exactly the authored forward speed of %.1f m/s"
			% _tractor.maximum_forward_speed
	)
	_check(
		_tractor.global_position.distance_to(start) > 8.0,
		"the tractor covers real deck under a real held key"
	)
	_check(
		(_tractor.global_position - start).normalized().dot(-_tractor.global_basis.z) > 0.99,
		"forward travel follows the tractor's own visible forward axis"
	)

	# Steering. A/D yaws about the deck normal; the heading must actually change
	# and the vehicle must stay tangent to the deck rather than rolling.
	var heading_before := -_tractor.global_basis.z
	await _hold(&"move_left", 40)
	Input.action_release(&"move_forward")
	var heading_after := -_tractor.global_basis.z
	_check(
		heading_before.angle_to(heading_after) > deg_to_rad(20.0),
		"real steering input yaws the tractor"
	)
	_check(
		heading_after.cross(heading_before).y < 0.0,
		"the left steering key turns the tractor to its own left"
	)
	_check(
		absf(_tractor.global_basis.y.dot(Vector3.UP) - 1.0) < 0.01,
		"steering keeps the tractor tangent to the flat deck instead of rolling it"
	)

	# Brake.
	await _hold(&"brake", 60)
	_check(is_zero_approx(_tractor.get_drive_speed()), "the brake brings the tractor to a complete stop")

	# Reverse is a slower gear, and steering mirrors like a real tug's.
	var reverse_heading := -_tractor.global_basis.z
	Input.action_press(&"move_back")
	await _advance(70)
	_check(
		is_equal_approx(_tractor.get_drive_speed(), -_tractor.maximum_reverse_speed)
		and _tractor.maximum_reverse_speed < _tractor.maximum_forward_speed,
		"reverse is capped at its own slower authored speed"
	)
	Input.action_press(&"move_left")
	await _advance(40)
	Input.action_release(&"move_left")
	Input.action_release(&"move_back")
	_check(
		reverse_heading.cross(-_tractor.global_basis.z).y < 0.0,
		"steering mirrors while reversing: the same key swings the nose the other way"
	)
	await _hold(&"brake", 60)

	# Red witness for the whole group: with no key held the tractor coasts to rest
	# and stays there, so none of the assertions above can be satisfied by a
	# vehicle that simply always moves.
	var idle_start := _tractor.global_position
	await _advance(60)
	_check(
		is_zero_approx(_tractor.get_drive_speed())
		and _tractor.global_position.distance_to(idle_start) < 0.05,
		"red witness: with no input held the tractor does not move at all"
	)
	_tractor.set_driven(false)


# ------------------------------------------------------------ safety interlock


func _check_deck_edge_interlock() -> void:
	# Green: aimed at the deck's real void edge.
	_place(Vector3(-28.0, 0.2, OPEN_LANE_Z), 90.0)
	_tractor.set_driven(true)
	await _settle(6)
	await _hold(&"move_forward", 150)
	_check(
		_tractor.global_position.x > -DECK_HALF_LENGTH,
		"the tractor never crosses the deck's void edge"
	)
	_check(
		_tractor.is_on_floor(),
		"the tractor is still standing on the deck after driving at the edge"
	)
	_check(
		not _tractor.has_reported_recovery(),
		"stopping at the edge is not a fall and raises no recovery"
	)

	Input.action_press(&"move_forward")
	await _advance(10)
	_check(
		_tractor.is_edge_interlock_engaged(),
		"held throttle at the lip keeps the deck-edge interlock engaged rather than flickering"
	)
	_check(
		is_zero_approx(_tractor.get_drive_speed()),
		"the engaged interlock holds the drive speed at zero"
	)
	var pinned := _tractor.global_position
	await _advance(90)
	_check(
		_tractor.global_position.distance_to(pinned) < 0.05,
		"the interlock does not leak one tick of travel at a time under held throttle"
	)
	Input.action_release(&"move_forward")

	# The interlock must not be a wall: reverse away from the same lip works.
	await _hold(&"move_back", 60)
	_check(
		_tractor.global_position.x > pinned.x + 0.5,
		"reversing away from the edge is allowed while the forward lip is refused"
	)
	await _hold(&"brake", 60)

	# Red witness: the identical drive in open deck must engage nothing and cover
	# real ground, so "stops at the edge" is not "always stops".
	_place(Vector3(0.0, 0.2, OPEN_LANE_Z), 90.0)
	await _settle(6)
	var open_start := _tractor.global_position
	await _hold(&"move_forward", 60)
	_check(
		not _tractor.is_edge_interlock_engaged(),
		"red witness: the interlock stays clear in open deck"
	)
	_check(
		_tractor.global_position.distance_to(open_start) > 5.0,
		"red witness: the same held throttle covers real ground away from the edge"
	)
	await _hold(&"brake", 60)
	_tractor.set_driven(false)


func _check_slope_and_kerb() -> void:
	# Slope: the authored station joins decks with ramps and threshold aprons, so
	# this is the surface the tractor has to handle.
	_place(Vector3(8.0, 0.2, OBSTACLE_LANE_Z), -90.0)
	_tractor.set_driven(true)
	await _settle(6)
	var base_height := _tractor.global_position.y
	await _hold(&"move_forward", 110)
	_check(
		_tractor.global_position.y > base_height + 1.0,
		"the tractor climbs the %.0f° ramp under its own drive" % RAMP_ANGLE_DEGREES
	)
	_check(_tractor.is_on_floor(), "the tractor stays in contact while climbing")
	_check(
		_tractor.global_basis.y.dot(Vector3.UP) < 0.999,
		"the tractor pitches onto the ramp instead of driving up it flat"
	)
	await _hold(&"brake", 60)

	# Kerb: the deliberate divergence from the walking pilot's step-up assist.
	_place(Vector3(0.0, 0.2, OBSTACLE_LANE_Z), 90.0)
	await _settle(6)
	await _hold(&"move_forward", 150)
	_check(
		_tractor.global_position.x > KERB_X,
		"the tractor is stopped by the %.2f m kerb and does not climb it" % KERB_HEIGHT
	)
	_check(
		KERB_HEIGHT < PlayerController.STEP_UP_MAX_HEIGHT,
		"the kerb that stops the tractor is one a walking pilot's %.2f m step assist clears"
			% PlayerController.STEP_UP_MAX_HEIGHT
	)
	_check(
		_tractor.floor_max_angle > deg_to_rad(RAMP_ANGLE_DEGREES),
		"the tractor's climbing rule is slope, not an inherited step-up height"
	)
	await _hold(&"brake", 60)
	_tractor.set_driven(false)


# --------------------------------------------------------------- seat contract


func _check_seat_contract() -> void:
	_place(Vector3(0.0, 0.2, OPEN_LANE_Z), 90.0)
	await _settle(6)
	var actor := Node.new()
	actor.name = "PretendPilot"
	_root.add_child(actor)
	var requested: Array[Node] = []
	_tractor.board_requested.connect(func(requesting_actor: Node) -> void:
		requested.append(requesting_actor)
	)

	_check(_tractor.is_boardable(), "a parked tractor offers its seat")
	_check(
		_tractor.get_driver_station().interact(actor),
		"interacting with the driver step is accepted"
	)
	_check(
		requested.size() == 1 and requested[0] == actor,
		"the accepted request names the actor that made it"
	)

	_tractor.set_driven(true)
	await _settle(4)
	_check(not _tractor.is_boardable(), "an occupied tractor closes its seat")
	_check(
		not _tractor.get_driver_station().interact(actor),
		"red witness: a second interact on the occupied seat is refused, not silently accepted"
	)
	_check(
		requested.size() == 1,
		"the refused request raises no boarding signal"
	)
	_check(
		_tractor.get_interaction_prompt().is_empty(),
		"an occupied tractor draws no walk-up prompt"
	)
	_check(
		not _tractor.get_driver_station().is_available()
		and _tractor.get_driver_station().collision_layer == 0,
		"an occupied driver step leaves physics discovery instead of answering with an empty prompt"
	)

	# Release gating.
	await _hold(&"move_forward", 40)
	_check(
		not _tractor.can_release_driver(),
		"the driver cannot step off a moving tractor"
	)
	await _hold(&"brake", 60)
	_check(
		_tractor.can_release_driver(),
		"the driver may step off once the tractor is stopped on the deck"
	)

	# The dismount is validated against real deck, and its fallback is exact.
	var fallback := Transform3D(Basis.IDENTITY, Vector3(999.0, 999.0, 999.0))
	var on_deck_exit := _tractor.get_exit_transform(fallback)
	_check(
		not on_deck_exit.origin.is_equal_approx(fallback.origin),
		"a tractor parked on deck offers a real dismount point rather than the fallback"
	)
	_check(
		on_deck_exit.origin.distance_to(_tractor.global_position) < 4.0
		and absf(on_deck_exit.origin.y) < 0.4,
		"the dismount point stands on the deck beside the tractor"
	)
	var toward_tractor := _tractor.global_position - on_deck_exit.origin
	toward_tractor.y = 0.0
	_check(
		(-on_deck_exit.basis.z).dot(toward_tractor.normalized()) > 0.95,
		"the dismount turns the player back toward the tractor, keeping their camera boom off it"
	)
	_check(
		(-on_deck_exit.basis.z).dot(-_tractor.global_basis.z) < 0.95,
		"red witness: that facing is genuinely chosen, not the tractor's own heading inherited"
	)

	var parked := _tractor.global_transform
	_tractor.global_position = Vector3(0.0, 0.2, 400.0)
	await _settle(2)
	_check(
		_tractor.get_exit_transform(fallback).origin.is_equal_approx(fallback.origin),
		"a dismount with no deck under any candidate returns the caller's safe ground exactly"
	)
	_tractor.global_transform = parked
	_tractor.set_driven(false)
	actor.queue_free()
	await _settle(2)


# --------------------------------------------------------------- recovery net


func _check_recovery_net() -> void:
	# Red witness first: a tractor sitting on the deck for the same span of frames
	# emits nothing, so the two green cases below cannot be an always-on signal.
	_tractor.recover_to_home_transform()
	await _settle(4)
	var reasons: Array[StringName] = []
	_tractor.deck_recovery_required.connect(func(reason: StringName) -> void:
		reasons.append(reason)
	)
	await _advance(200)
	_check(
		reasons.is_empty() and not _tractor.has_reported_recovery(),
		"red witness: a tractor parked on the deck never reports a recovery"
	)

	# Falling off the station, driver aboard. This is the stranding case, and the
	# vehicle reports it from its own pose without help from the interlock.
	_tractor.set_driven(true)
	_tractor.global_position = Vector3(0.0, 0.0, 400.0)
	_tractor.velocity = Vector3.ZERO
	var fell := await _wait_until(
		func() -> bool: return not reasons.is_empty(),
		2.0
	)
	_check(fell, "a driven tractor that falls off the station reports a recovery inside its frame budget")
	_check(reasons.size() == 1, "the fall reports exactly one recovery")
	_check(
		not reasons.is_empty() and reasons[0] == &"fell_below_station",
		"the reported reason names the recovery floor"
	)
	_check(not _tractor.is_boardable(), "a lost tractor refuses boarding until it is recovered")
	_check(
		not _tractor.get_driver_station().is_available(),
		"a lost tractor withdraws its driver step from discovery"
	)
	_check(
		_tractor.get_interaction_prompt().contains("RECOVERING"),
		"a lost tractor says so at its driver step"
	)
	await _advance(120)
	_check(
		reasons.size() == 1,
		"a continuing fall does not report a second recovery"
	)

	_tractor.recover_to_home_transform()
	_check(
		_tractor.global_transform.is_equal_approx(_tractor.get_home_transform()),
		"recovery restores the authored parking transform exactly"
	)
	_check(
		not _tractor.is_driven() and is_zero_approx(_tractor.get_drive_speed()),
		"recovery releases the seat and parks the drive speed"
	)
	_check(_tractor.is_boardable(), "a recovered tractor is available again")
	_check(
		_tractor.get_driver_station().is_available(),
		"recovery restores the driver step to discovery"
	)
	_check(not _tractor.has_reported_recovery(), "recovery re-arms the report for the next departure")
	await _settle(20)
	_check(
		_tractor.is_on_floor() and not _tractor.has_reported_recovery(),
		"the recovered tractor settles back onto the deck and stays reported-clear"
	)

	# The second, independent trigger: airborne beyond the limit, high above the
	# deck, with the recovery floor never reached.
	reasons.clear()
	_tractor.global_position = Vector3(0.0, 44.0, OPEN_LANE_Z)
	_tractor.velocity = Vector3.ZERO
	var airborne := await _wait_until(
		func() -> bool: return not reasons.is_empty(),
		TowTractor.MAXIMUM_AIRBORNE_SECONDS + 0.2
	)
	_check(airborne, "a tractor airborne beyond the limit reports inside its frame budget")
	_check(
		not reasons.is_empty() and reasons[0] == &"airborne_beyond_limit",
		"the second trigger names the airborne limit rather than the floor"
	)
	_check(
		_tractor.global_position.y > TowTractor.RECOVERY_FLOOR_Y,
		"the airborne trigger fires on its own, not as a disguised floor trigger"
	)
	_tractor.recover_to_home_transform()
	await _settle(20)


# ----------------------------------------------------------------- scaffolding


func _build_synthetic_deck() -> void:
	_root = Node3D.new()
	_root.name = "SyntheticDeck"
	root.add_child(_root)

	_static_box(
		"Deck",
		Vector3(0.0, -0.5, 0.0),
		Vector3(DECK_HALF_LENGTH * 2.0, 1.0, DECK_HALF_WIDTH * 2.0),
		Vector3.ZERO
	)
	# A 0.25 m kerb: below the walking pilot's step assist, above what a small
	# wheeled tug should be able to mount.
	_static_box(
		"Kerb",
		Vector3(KERB_X, 0.0, OBSTACLE_LANE_Z),
		Vector3(0.6, KERB_HEIGHT * 2.0, OBSTACLE_LANE_WIDTH),
		Vector3.ZERO
	)
	# A ramp whose top surface is flush with the deck at `RAMP_START_X`.
	var angle := deg_to_rad(RAMP_ANGLE_DEGREES)
	var ramp_basis := Basis(Vector3.BACK, angle)
	var along := ramp_basis.x
	var ramp_up := ramp_basis.y
	var ramp_center := Vector3(RAMP_START_X, 0.0, OBSTACLE_LANE_Z) + along * 7.0 - ramp_up * 0.4
	_static_box(
		"Ramp",
		ramp_center,
		Vector3(14.0, 0.8, OBSTACLE_LANE_WIDTH),
		Vector3(0.0, 0.0, RAMP_ANGLE_DEGREES)
	)

	_tractor = TRACTOR_SCENE.instantiate() as TowTractor
	_tractor.position = Vector3(0.0, 0.2, OPEN_LANE_Z)
	_tractor.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_root.add_child(_tractor)


func _static_box(
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		rotation_degrees_value: Vector3
	) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = box_position
	body.rotation_degrees = rotation_degrees_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_root.add_child(body)


func _place(target_position: Vector3, yaw_degrees: float) -> void:
	_release_inputs()
	_tractor.global_transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(yaw_degrees)),
		target_position
	)
	_tractor.velocity = Vector3.ZERO
	_tractor.reset_physics_interpolation()


func _settle(frames: int) -> void:
	await _advance(frames)


func _advance(frames: int) -> void:
	for _frame in maxi(1, frames):
		await physics_frame


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _advance(frames)
	Input.action_release(action)
	await physics_frame


func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"brake", &"interact", &"jump"]:
		Input.action_release(action)


## Physics frames a nominal duration is worth at the configured tick rate, plus a
## fixed frame grace. A frame budget, never a wall-clock sleep: the recovery net
## accumulates the physics delta, so it must be measured on the same clock.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for `predicate` on the simulation clock. The recovery net accumulates
## the physics delta, so a loaded machine that drops physics steps must be given
## the same amount of *simulation*, not the same amount of wall time.
func _wait_until(predicate: Callable, nominal_seconds: float) -> bool:
	var budget := _frame_budget(nominal_seconds)
	var frames := 0
	while not bool(predicate.call()):
		if frames >= budget:
			return false
		await physics_frame
		frames += 1
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TOW_TRACTOR_TEST_OK")
		quit(0)
	else:
		print("TOW_TRACTOR_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
