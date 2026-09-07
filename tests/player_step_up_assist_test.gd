extends SceneTree

## Focused regression for the production PlayerController's locomotion step-up
## assist, added to close MAP-001…MAP-003.
##
## The defect class was: `CharacterBody3D` has no step solver, so `move_and_slide()`
## treated every authored lip at or above 0.15 m as a wall. The fix adds a bounded
## up-forward-down capsule probe. This suite pins both halves of that contract —
## the lips it must now mount, and the things it must still refuse to climb —
## against the real `scenes/player/player.tscn` capsule with real input actions.
##
## Step cases drive `move_forward` through the InputMap without jumping. The
## Ember contact regression also checks a real jump and unsupported edge.
## Nothing is teleported during a walk.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MovingFrame := preload("res://scripts/physics/moving_interior_frame.gd")
const WORLD_LAYER := PhysicsLayers.WORLD

const WALK_FRAMES := 150

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_assist_contract()
	await _test_step_height_boundary()
	await _test_refuses_to_step_into_a_void()
	await _test_refuses_a_lip_without_headroom()
	await _test_refuses_an_unwalkable_landing()
	await _test_does_not_displace_on_open_ground()
	await _test_steps_along_ship_local_up()
	await _test_ember_pad_floor_contact()
	_finish()


## The contract is reported from the live capsule, so a future collision-shape
## change cannot leave the documented bounds stale.
func _test_assist_contract() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	var audit := player.get_step_up_assist_audit()
	print("STEP_UP_ASSIST_AUDIT: ", audit)
	_check(
		is_equal_approx(float(audit["max_step_height"]), 0.30),
		"the step-up assist limit is the station's authored 0.30 m stair riser"
	)
	_check(
		bool(audit["within_capsule_radius"])
		and float(audit["max_step_height"]) <= float(audit["capsule_radius"]),
		"the step-up limit stays inside the capsule radius, so the body is only placed where the capsule could have rolled"
	)
	_check(
		is_equal_approx(
			float(audit["probe_reach"]),
			float(audit["capsule_radius"]) + float(audit["min_clearance"])
		),
		"the step probe reaches exactly one capsule radius plus clearance, derived from the live shape"
	)
	_check(
		bool(audit["requires_floor_contact"])
		and bool(audit["requires_wall_contact"])
		and bool(audit["requires_walkable_landing"])
		and not bool(audit["steps_into_void"]),
		"the assist declares its floor, wall, walkable-landing and no-void bounds"
	)
	rig.queue_free()
	await process_frame


## Boundary case, both directions. 0.15 m is the exact height the pre-fix
## controller failed at; 0.31 m is one millimetre past the declared limit and
## must stay a wall, so a widened limit cannot pass this suite unnoticed.
func _test_step_height_boundary() -> void:
	var mounted := PackedStringArray()
	var refused := PackedStringArray()
	for height in [0.14, 0.15, 0.25, 0.30, 0.31, 0.35, 0.45]:
		if await _walks_up_lip(float(height)):
			mounted.append("%.2f" % height)
		else:
			refused.append("%.2f" % height)
	print("STEP_UP_MOUNTED: ", mounted, " REFUSED: ", refused)
	_check(
		mounted == PackedStringArray(["0.14", "0.15", "0.25", "0.30"]),
		"continuous move_forward mounts every lip up to and including the 0.30 m limit, with no jump"
	)
	_check(
		refused == PackedStringArray(["0.31", "0.35", "0.45"]),
		"a lip one millimetre past the limit, and anything taller, remains a wall"
	)


## The assist may only mount a lip it is standing against. It must not bridge an
## open gap in the deck, and it must not climb the far face once the body is in
## the pit — even though the far platform's top is only 0.30 m above the deck the
## body started on.
func _test_refuses_to_step_into_a_void() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	# Near deck, top y = 0, ending at z = -4.
	rig.add_child(_slab(Vector3(8.0, 1.0, 8.0), Vector3(0.0, -0.5, 0.0)))
	# Pit floor 3 m down, spanning the gap and beyond.
	rig.add_child(_slab(Vector3(8.0, 1.0, 10.0), Vector3(0.0, -3.5, -9.0)))
	# Far platform, top y = 0.30 — one exact step above the near deck, but 1.0 m
	# of open air away from it and 3.30 m above the pit floor.
	rig.add_child(_slab(Vector3(8.0, 3.3, 7.0), Vector3(0.0, -1.35, -8.5)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	var result := await _walk(player, Vector3(0.0, 0.05, 2.0), WALK_FRAMES)
	print("GAP_AND_FACE_WALK: ", result)
	var final_position := result["final"] as Vector3
	_check(
		final_position.y < -2.5,
		"the assist does not bridge an open gap: the body falls into the pit instead of stepping across"
	)
	_check(
		final_position.z > -5.4,
		"the assist does not climb the 3.30 m pit face to reach a platform only one step above where it started"
	)
	rig.queue_free()
	await process_frame


## Headroom bound: the same climbable lip becomes a wall when the capsule cannot
## be lifted over it.
func _test_refuses_a_lip_without_headroom() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	rig.add_child(_slab(Vector3(8.0, 1.0, 8.0), Vector3(0.0, -0.5, 0.0)))
	rig.add_child(_slab(Vector3(8.0, 1.25, 8.0), Vector3(0.0, -0.375, -8.0)))
	# Ceiling 2.10 m over the near deck: the 1.94 m standing capsule fits and
	# walks normally, but it cannot be lifted the 0.32 m the probe needs.
	rig.add_child(_slab(Vector3(8.0, 0.4, 14.0), Vector3(0.0, 2.30, -5.0)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	var result := await _walk(player, Vector3(0.0, 0.05, 2.0), WALK_FRAMES)
	print("NO_HEADROOM_WALK: ", result)
	var final_position := result["final"] as Vector3
	_check(
		final_position.y < 0.20 and final_position.z > -4.2,
		"a 0.25 m lip under a low ceiling is not mounted, because the capsule cannot be lifted clear"
	)
	rig.queue_free()
	await process_frame


## The mutation that matters most: without the walkable-landing bound the assist
## would step 0.30 m up an unwalkable slope every physics tick and turn it into a
## staircase. A 65 degree face — well past the body's 50 degree floor_max_angle —
## must stay a wall no matter how long the player leans on it.
func _test_refuses_an_unwalkable_landing() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	# A deck the body cannot walk off, so nothing below can be mistaken for a pass.
	rig.add_child(_slab(Vector3(16.0, 1.0, 20.0), Vector3(0.0, -0.5, -6.0)))
	# A 65 degree face whose foot meets the deck plane exactly at z = -4.
	var face := _slab(Vector3(12.0, 2.0, 12.0), Vector3(0.0, 5.015, -7.442))
	face.rotation_degrees = Vector3(65.0, 0.0, 0.0)
	rig.add_child(face)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	var result := await _walk(player, Vector3(0.0, 0.05, 2.0), WALK_FRAMES)
	print("UNWALKABLE_LANDING_WALK: ", result)
	var final_position := result["final"] as Vector3
	_check(
		final_position.y < 0.05,
		"a face steeper than floor_max_angle is never mounted, however many ticks the body pushes into it"
	)
	_check(
		final_position.z > -4.6,
		"the body stays at the foot of the steep face instead of stepping up it"
	)
	rig.queue_free()
	await process_frame


## The assist must never fire on open ground: no per-frame displacement may
## exceed what ordinary locomotion could produce.
func _test_does_not_displace_on_open_ground() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	rig.add_child(_slab(Vector3(40.0, 1.0, 40.0), Vector3(0.0, -0.5, 0.0)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 10.0)))
	for _settle in 10:
		await physics_frame
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var budget := player.sprint_speed * tick * 1.5
	var previous := player.global_position
	var largest := 0.0
	var largest_rise := 0.0
	Input.action_press(&"move_forward")
	for _frame in 90:
		await physics_frame
		var moved := player.global_position - previous
		largest = maxf(largest, moved.length())
		largest_rise = maxf(largest_rise, moved.y)
		previous = player.global_position
	Input.action_release(&"move_forward")
	await physics_frame
	print("OPEN_GROUND_MAX_STEP: ", largest, " budget=", budget, " max_rise=", largest_rise)
	_check(
		largest <= budget,
		"walking across open ground never produces a step-sized displacement"
	)
	_check(
		largest_rise <= 0.01,
		"walking across open ground never lifts the body"
	)
	rig.queue_free()
	await process_frame


## The assist resolves in the body's current up direction, not world up, so it
## works aboard a rotated moving interior exactly as it does on the station.
func _test_steps_along_ship_local_up() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var frame := Node3D.new()
	frame.name = "TiltedInterior"
	frame.rotation_degrees = Vector3(0.0, 0.0, 22.0)
	rig.add_child(frame)
	frame.add_child(_slab(Vector3(8.0, 1.0, 8.0), Vector3(0.0, -0.5, 0.0)))
	frame.add_child(_slab(Vector3(8.0, 1.25, 8.0), Vector3(0.0, -0.375, -8.0)))
	var coordinator := MovingFrame.new()
	coordinator.name = "InteriorFrame"
	coordinator.authority_mode = MovingFrame.AuthorityMode.UNRESTRICTED
	frame.add_child(coordinator)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	await physics_frame

	var frame_basis := frame.global_basis.orthonormalized()
	var frame_up := frame_basis.y
	player.teleport_to(Transform3D(frame_basis, frame.global_transform * Vector3(0.0, 0.05, 2.0)))
	var registration := coordinator.register_occupant(player)
	_check(
		bool(registration["registered"]),
		"the production capsule registers with a rotated MovingInteriorFrame"
	)
	for _settle in 20:
		await physics_frame
	var start := player.global_position
	Input.action_press(&"move_forward")
	var climbed := false
	for _frame in WALK_FRAMES:
		await physics_frame
		var offset := player.global_position - start
		if offset.dot(frame_basis.z) < -4.5 and offset.dot(frame_up) >= 0.22:
			climbed = true
			break
	Input.action_release(&"move_forward")
	await physics_frame
	var offset_final := player.global_position - start
	print(
		"SHIP_LOCAL_STEP: local_up_rise=", offset_final.dot(frame_up),
		" world_y_rise=", offset_final.y,
		" local_forward=", -offset_final.dot(frame_basis.z)
	)
	_check(
		climbed,
		"the assist mounts a 0.25 m ship-local lip aboard a 22 degree rolled moving interior"
	)
	_check(
		offset_final.dot(frame_up) > absf(offset_final.y) - 0.01,
		"the rise is resolved along ship-local up rather than world up"
	)
	coordinator.unregister_occupant(player, false, &"test_teardown")
	rig.queue_free()
	await process_frame


## A naturally reached Ember pad pose exposed native capsule contact loss at the
## default 1 mm recovery margin. Stage that recorded pose, then use continuous
## collision motion; no position correction occurs during the walk.
func _test_ember_pad_floor_contact() -> void:
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 5.0
	var rig := Node3D.new()
	root.add_child(rig)
	rig.add_child(_slab(Vector3(96.0, 0.5, 96.0), Vector3(0.0, -60.21875, -290.2366)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.position = Vector3(30.0, -59.96, -290.4699)
	rig.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	for _settle in 11:
		await physics_frame
		player._apply_gravity(1.0 / 12.0)
		player._move_in_interior_collision_frame(1.0 / 12.0)
	player.position = Vector3(41.986328125, -59.967742919921875, -290.46990966796875)
	var lost_floor := 0
	var penetrated_floor := false
	var direction := 1.0
	for _frame in 80:
		await physics_frame
		player.velocity.x = player.walk_speed * direction
		player._apply_gravity(1.0 / 12.0)
		player._move_in_interior_collision_frame(1.0 / 12.0)
		if not player.is_on_floor():
			lost_floor += 1
		penetrated_floor = penetrated_floor or player.position.y < -60.06875
		if player.position.x > 46.0:
			direction = -1.0
		elif player.position.x < 30.0:
			direction = 1.0
	_check(lost_floor == 0 and not penetrated_floor,
		"the recorded Ember pad contact stays grounded above the floor through repeated physical crossings")

	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	var jump_start := player.position
	Input.action_press(&"jump")
	await physics_frame
	await physics_frame
	Input.action_release(&"jump")
	_check(not player.is_on_floor() and player.position.y > jump_start.y + 0.1,
		"the contact recovery margin preserves a real input-driven jump off the pad")
	for _land in 90:
		await physics_frame
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "the jumping capsule lands on the same physical pad")
	player.set_physics_process(false)
	for _edge in 80:
		await physics_frame
		player.velocity.x = player.walk_speed
		player._apply_gravity(1.0 / 12.0)
		player._move_in_interior_collision_frame(1.0 / 12.0)
		if player.position.x > 50.0 and player.position.y < -60.5:
			break
	_check(not player.is_on_floor() and player.position.x > 48.0
		and player.position.y < -60.5,
		"walking beyond the real pad edge loses support and falls instead of retaining false floor contact")
	rig.queue_free()
	await process_frame
	Engine.time_scale = original_time_scale


func _walks_up_lip(height: float) -> bool:
	var rig := Node3D.new()
	root.add_child(rig)
	rig.add_child(_slab(Vector3(8.0, 1.0, 8.0), Vector3(0.0, -0.5, 0.0)))
	rig.add_child(_slab(Vector3(8.0, 1.0 + height, 8.0), Vector3(0.0, -0.5 + height * 0.5, -8.0)))
	var player := PLAYER_SCENE.instantiate() as PlayerController
	rig.add_child(player)
	await process_frame
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 2.0)))
	for _settle in 10:
		await physics_frame
	Input.action_press(&"move_forward")
	var climbed := false
	for _frame in WALK_FRAMES:
		await physics_frame
		if player.global_position.z < -4.5 and player.global_position.y >= height - 0.02:
			climbed = true
			break
	Input.action_release(&"move_forward")
	await physics_frame
	rig.queue_free()
	await process_frame
	return climbed


func _walk(player: PlayerController, start: Vector3, frames: int) -> Dictionary:
	player.teleport_to(Transform3D(Basis.IDENTITY, start))
	for _settle in 10:
		await physics_frame
	var initial := player.global_position
	Input.action_press(&"move_forward")
	for _frame in frames:
		await physics_frame
	Input.action_release(&"move_forward")
	await physics_frame
	return {
		"initial": initial,
		"final": player.global_position,
		"travelled": initial.distance_to(player.global_position),
	}


func _slab(size: Vector3, slab_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = slab_position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)
	if _failures.is_empty():
		print("PLAYER_STEP_UP_ASSIST_TEST_OK")
		quit(0)
	else:
		print("PLAYER_STEP_UP_ASSIST_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
