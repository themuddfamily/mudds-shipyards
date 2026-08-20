extends SceneTree

const MovingFrame := preload("res://scripts/physics/moving_interior_frame.gd")

var _failures: Array[String] = []
var _step_token := 1000


class PhysicsOccupant:
	extends CharacterBody3D

	var local_gravity := 18.0
	var floor_ticks := 0


	func _physics_process(delta: float) -> void:
		if is_on_floor():
			floor_ticks += 1
			var vertical_speed := velocity.dot(up_direction)
			if vertical_speed < 0.0:
				velocity -= up_direction * vertical_speed
		else:
			velocity -= up_direction * local_gravity * delta
		move_and_slide()


class AcceleratingFrame:
	extends Node3D

	var motion_enabled := false
	var linear_speed := 1.0
	var linear_acceleration := 2.5
	var roll_rate := 0.18


	func _physics_process(delta: float) -> void:
		if not motion_enabled:
			return
		linear_speed += linear_acceleration * delta
		global_position += Vector3(linear_speed * delta, 0.35 * delta, -0.2 * delta)
		global_basis = (Basis(Vector3.FORWARD, roll_rate * delta) * global_basis).orthonormalized()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_registration()
	_test_translation_rotation_and_acceleration()
	_test_step_token_and_kinematic_edges()
	_test_exit_velocity_inheritance()
	_test_gravity_compensation_contract()
	_test_multiplayer_authority_lifecycle()
	await _test_ownership_reparent_free_and_reuse()
	await _test_component_detach_readd()
	await _test_direct_step_currentness()
	await _test_stale_frame_registration_is_atomic()
	await _test_volume_provenance_and_handoff()
	await _test_physical_standing_and_auto_volume()
	_finish()


func _test_configuration_and_registration() -> void:
	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant

	_check(coordinator.get_moving_frame() == frame, "component accepts an explicit moving Node3D frame")
	_check(coordinator.get_interior_bounds() == AABB(Vector3(-5, -2, -6), Vector3(10, 7, 12)), "component exposes canonical ship-local bounds")
	_check(coordinator.contains_world_position(occupant.global_position), "world positions resolve through ship-local bounds")
	_check(not coordinator.contains_world_position(Vector3(30, 0, 0)), "bounds reject remote world positions")

	var original_priority := occupant.process_physics_priority
	var original_up := occupant.up_direction
	var original_floor_layers := occupant.platform_floor_layers
	var original_wall_layers := occupant.platform_wall_layers
	var original_leave := occupant.platform_on_leave
	var registration: Dictionary = coordinator.register_occupant(occupant)
	_check(bool(registration.registered) and registration.status == &"registered", "manual entry registers a CharacterBody3D")
	_check(coordinator.get_occupant_count() == 1 and coordinator.is_occupant_registered(occupant), "registered occupancy is queryable")
	_check(coordinator.process_physics_priority > frame.process_physics_priority, "frame coordinator runs after ship motion")
	_check(occupant.process_physics_priority > coordinator.process_physics_priority, "occupant physics runs after frame compensation")
	_check(occupant.platform_floor_layers == 0 and occupant.platform_wall_layers == 0, "registration disables built-in platform propagation to prevent double motion")
	_check(occupant.platform_on_leave == CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING, "registration disables built-in exit inheritance")
	_check(occupant.up_direction.is_equal_approx(frame.global_basis.y), "registration aligns floor classification to ship-local up")

	var repeated: Dictionary = coordinator.register_occupant(occupant)
	_check(bool(repeated.registered) and repeated.status == &"already_registered" and coordinator.get_occupant_count() == 1, "duplicate registration is idempotent")
	var release: Dictionary = coordinator.unregister_occupant(occupant, false)
	_check(bool(release.released), "manual exit releases an occupant")
	_check(occupant.process_physics_priority == original_priority, "exit restores the original physics priority")
	_check(occupant.up_direction.is_equal_approx(original_up), "exit restores the original up direction")
	_check(occupant.platform_floor_layers == original_floor_layers and occupant.platform_wall_layers == original_wall_layers, "exit restores built-in platform masks")
	_check(occupant.platform_on_leave == original_leave, "exit restores the original platform leave policy")
	_check(not occupant.has_meta(MovingFrame.OWNER_META), "exit clears exclusive moving-frame ownership")

	var plain_occupant := Node3D.new()
	plain_occupant.name = "PlainNodeOccupant"
	fixture.root.add_child(plain_occupant)
	plain_occupant.global_position = Vector3(-1, 1, 2)
	var plain_start := plain_occupant.global_position
	_check(bool(coordinator.register_occupant(plain_occupant).registered), "non-CharacterBody Node3D occupants use the same lifecycle")
	coordinator.reset_frame_tracking(true)
	frame.global_position = Vector3(1, 0.5, -0.25)
	coordinator.step_frame(0.5, _next_token())
	_check(plain_occupant.global_position.is_equal_approx(plain_start + frame.global_position), "plain Node3D occupants receive full frame compensation")
	var plain_release: Dictionary = coordinator.unregister_occupant(plain_occupant, true)
	_check(bool(plain_release.released) and not bool(plain_release.velocity_applied), "plain Node3D exit reports motion without inventing a velocity property")

	occupant.global_position = Vector3(40, 0, 0)
	var outside: Dictionary = coordinator.register_occupant(occupant)
	_check(not bool(outside.registered) and outside.status == &"outside_bounds", "entry outside declared bounds fails closed")
	var override: Dictionary = coordinator.register_occupant(occupant, {"require_inside_bounds": false})
	_check(bool(override.registered), "callers can explicitly override bounds for recovery flows")
	coordinator.unregister_occupant(occupant, false)
	fixture.root.free()


func _test_translation_rotation_and_acceleration() -> void:
	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant
	coordinator.register_occupant(occupant)

	var start_transform := Transform3D(Basis(Vector3.UP, 0.31), Vector3(2.0, 1.0, -3.0))
	occupant.global_transform = start_transform
	coordinator.reset_frame_tracking(true)
	frame.global_position = Vector3(4.0, 1.0, -2.0)
	var translated: Dictionary = coordinator.step_frame(0.5, _next_token())
	_check(bool(translated.applied), "translation frame step applies")
	_check(occupant.global_position.is_equal_approx(start_transform.origin + Vector3(4.0, 1.0, -2.0)), "translation carries the occupant exactly once")
	_check(coordinator.get_frame_linear_velocity().is_equal_approx(Vector3(8.0, 2.0, -4.0)), "translation derives frame linear velocity")
	var after_translation := occupant.global_transform
	var duplicate: Dictionary = coordinator.step_frame(0.5, int(translated.step_token))
	_check(duplicate.status == &"duplicate_step" and occupant.global_transform.is_equal_approx(after_translation), "one physics token cannot double-apply frame motion")

	coordinator.reset_frame_tracking(true)
	var pre_rotation := occupant.global_transform
	occupant.velocity = Vector3(1.0, 0.0, -2.0)
	var pre_velocity := occupant.velocity
	var rotation_delta := Basis(Vector3.UP, PI * 0.5)
	frame.global_basis = rotation_delta * frame.global_basis
	coordinator.step_frame(0.25, _next_token())
	var pivot := frame.global_position
	var expected_position := pivot + rotation_delta * (pre_rotation.origin - pivot)
	_check(occupant.global_position.is_equal_approx(expected_position), "rotation carries an offset occupant around the live frame origin")
	_check(occupant.global_basis.is_equal_approx(rotation_delta * pre_rotation.basis), "rotation carries occupant attitude with the deck")
	_check(occupant.velocity.is_equal_approx(rotation_delta * pre_velocity), "rotation preserves occupant-relative velocity in the rotated frame")
	_check(is_equal_approx(coordinator.get_frame_angular_velocity().length(), TAU), "rotation derives angular velocity from the shortest quaternion delta")

	# A rolling frame updates floor-up independently of the global Y axis.
	coordinator.reset_frame_tracking(true)
	var roll_delta := Basis(Vector3.FORWARD, PI * 0.25)
	frame.global_basis = roll_delta * frame.global_basis
	coordinator.step_frame(0.5, _next_token())
	_check(occupant.up_direction.is_equal_approx(frame.global_basis.y.normalized()), "rolling frame updates CharacterBody ship-local up")

	# Velocity changes across two known steps produce deterministic acceleration.
	frame.global_transform = Transform3D.IDENTITY
	coordinator.reset_frame_tracking(true)
	frame.global_position.x = 1.0
	coordinator.step_frame(0.5, _next_token())
	_check(coordinator.get_frame_linear_velocity().is_equal_approx(Vector3(2, 0, 0)), "first acceleration sample has the expected velocity")
	_check(coordinator.get_frame_linear_acceleration().is_zero_approx(), "first velocity sample does not manufacture acceleration from zero")
	frame.global_position.x = 4.0
	coordinator.step_frame(0.5, _next_token())
	_check(coordinator.get_frame_linear_velocity().is_equal_approx(Vector3(6, 0, 0)), "accelerating translation updates velocity")
	_check(coordinator.get_frame_linear_acceleration().is_equal_approx(Vector3(8, 0, 0)), "accelerating translation derives frame acceleration")

	# Discontinuous corrections still carry physical occupants but never create a
	# catastrophic inherited velocity.
	coordinator.teleport_distance_threshold = 20.0
	var local_before_teleport := frame.to_local(occupant.global_position)
	frame.global_position += Vector3(100, 30, -50)
	var discontinuity: Dictionary = coordinator.step_frame(0.1, _next_token())
	_check(bool(discontinuity.discontinuity), "large network/respawn corrections are detected")
	_check(frame.to_local(occupant.global_position).is_equal_approx(local_before_teleport), "discontinuous frame corrections keep the same physical interior offset")
	_check(coordinator.get_frame_linear_velocity().is_zero_approx() and coordinator.get_frame_angular_velocity().is_zero_approx(), "discontinuous corrections do not become exit-launch velocity")

	# A caller that has already teleported the frame can explicitly carry the
	# occupants while rebasing, still without manufacturing exit velocity.
	coordinator.reset_frame_tracking(true)
	var local_before_rebase := frame.to_local(occupant.global_position)
	frame.global_position += Vector3(12, -3, 7)
	coordinator.reset_frame_tracking(true, true)
	_check(frame.to_local(occupant.global_position).is_equal_approx(local_before_rebase), "reset can carry occupants through an externally applied frame correction")
	_check(coordinator.get_frame_linear_velocity().is_zero_approx(), "carrying reset clears correction velocity history")

	# Equivalent 350-degree basis changes are interpreted as the shortest
	# negative ten-degree step, not an impossible near-full revolution.
	frame.global_transform = Transform3D.IDENTITY
	coordinator.teleport_angle_threshold_degrees = 120.0
	coordinator.reset_frame_tracking(true)
	frame.global_basis = Basis(Vector3.UP, deg_to_rad(350.0))
	var short_turn: Dictionary = coordinator.step_frame(0.5, _next_token())
	_check(not bool(short_turn.discontinuity), "shortest-angle tracking avoids a false rotational discontinuity")
	_check(is_equal_approx(coordinator.get_frame_angular_velocity().length(), deg_to_rad(20.0)), "shortest-angle tracking derives the ten-degree turn rate")
	_check(coordinator.get_frame_angular_velocity().is_equal_approx(Vector3.UP * deg_to_rad(-20.0)), "shortest-angle tracking preserves the signed rotation axis")
	fixture.root.free()


func _test_step_token_and_kinematic_edges() -> void:
	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant
	coordinator.register_occupant(occupant)
	coordinator.reset_frame_tracking(true)

	frame.global_position.x = 1.0
	coordinator.step_frame(0.25, 2_000_000)
	frame.global_position.x = 2.0
	coordinator.step_frame(0.25, 2_000_001)
	var before_old_token := occupant.global_transform
	frame.global_position.x = 3.0
	var old_token: Dictionary = coordinator.step_frame(0.25, 2_000_000)
	_check(old_token.status == &"out_of_order_step" and occupant.global_transform.is_equal_approx(before_old_token), "A-B-A token reuse is rejected without replaying motion")
	var invalid_delta: Dictionary = coordinator.step_frame(0.0, 2_000_002)
	var corrected: Dictionary = coordinator.step_frame(0.25, 2_000_002)
	_check(invalid_delta.status == &"invalid_delta" and corrected.status == &"applied", "invalid input does not consume a valid rollback token")
	_check(frame.to_local(occupant.global_position).is_equal_approx(Vector3(1, 1, 0)), "corrected step carries the occupant exactly once")

	frame.global_transform = Transform3D.IDENTITY
	coordinator.reset_frame_tracking(true)
	frame.global_basis = Basis(Vector3.UP, PI * 0.5)
	coordinator.step_frame(0.25, _next_token())
	_check(coordinator.get_frame_angular_velocity().is_equal_approx(Vector3.UP * TAU), "positive quarter-turn produces signed +Y angular velocity")
	frame.global_basis = Basis(Vector3.UP, PI)
	coordinator.step_frame(0.25, _next_token())
	_check(coordinator.get_frame_angular_acceleration().is_zero_approx(), "constant signed turn rate produces zero angular acceleration")
	fixture.root.free()


func _test_exit_velocity_inheritance() -> void:
	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant
	occupant.global_position = Vector3(3, 1, 0)
	coordinator.register_occupant(occupant)
	coordinator.reset_frame_tracking(true)

	var delta := 0.5
	frame.global_transform = Transform3D(
		Basis(Vector3.UP, 0.5),
		Vector3(2.0, 0.5, -1.0)
	)
	coordinator.step_frame(delta, _next_token())
	occupant.velocity = Vector3(0.75, 0.25, -0.5)
	var relative_velocity := occupant.velocity
	var expected_linear_velocity := Vector3(4.0, 1.0, -2.0)
	var expected_angular_velocity := Vector3.UP
	var radius := occupant.global_position - frame.global_position
	var point_frame_velocity := expected_linear_velocity + expected_angular_velocity.cross(radius)
	var expected_exit := relative_velocity + point_frame_velocity
	_check(coordinator.get_frame_linear_velocity().is_equal_approx(expected_linear_velocity), "exit fixture independently verifies frame linear velocity")
	_check(coordinator.get_frame_angular_velocity().is_equal_approx(expected_angular_velocity), "exit fixture independently verifies signed angular velocity")
	_check(not point_frame_velocity.is_equal_approx(coordinator.get_frame_linear_velocity()), "off-axis exit includes angular point velocity")
	_check(coordinator.get_exit_velocity(occupant).is_equal_approx(expected_exit), "exit preview combines relative, linear, and angular motion")
	var release: Dictionary = coordinator.unregister_occupant(occupant, true, &"airlock_exit")
	_check(bool(release.velocity_applied) and release.reason == &"airlock_exit", "exit inheritance is applied and audited")
	_check(occupant.velocity.is_equal_approx(expected_exit), "CharacterBody receives frame velocity exactly once on exit")
	var post_release_velocity := occupant.velocity
	var repeated: Dictionary = coordinator.unregister_occupant(occupant, true)
	_check(not bool(repeated.released) and occupant.velocity.is_equal_approx(post_release_velocity), "repeated exit cannot add frame velocity twice")
	fixture.root.free()


func _test_gravity_compensation_contract() -> void:
	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant
	coordinator.register_occupant(occupant, {"compensate_world_gravity": true})
	coordinator.reset_frame_tracking(true)
	var delta := 0.1
	frame.global_basis = Basis(Vector3.FORWARD, PI * 0.5)
	coordinator.step_frame(delta, _next_token())
	var world_gravity := occupant.get_gravity()
	occupant.velocity += world_gravity * delta
	var expected_local_gravity := coordinator.get_frame_gravity(occupant) * delta
	_check(occupant.velocity.is_equal_approx(expected_local_gravity), "opt-in compensation converts a controller's later world gravity into ship-local gravity")
	_check(occupant.up_direction.is_equal_approx(frame.global_basis.y), "gravity contract and floor-up share the same moving frame")
	fixture.root.free()


func _test_multiplayer_authority_lifecycle() -> void:
	var api := root.get_multiplayer()
	var previous_peer := api.multiplayer_peer
	var peer := ENetMultiplayerPeer.new()
	var peer_error := peer.create_server(0, 1)
	_check(peer_error == OK, "authority test creates an isolated local multiplayer peer")
	if peer_error != OK:
		return
	api.multiplayer_peer = peer

	var fixture := _manual_fixture()
	var frame: Node3D = fixture.frame
	var coordinator: MovingInteriorFrame = fixture.coordinator
	var occupant: CharacterBody3D = fixture.occupant
	var original_priority := occupant.process_physics_priority
	var original_floor_layers := occupant.platform_floor_layers
	coordinator.authority_mode = MovingFrame.AuthorityMode.FRAME_AUTHORITY
	coordinator.set_multiplayer_authority(2)
	var registration: Dictionary = coordinator.register_occupant(occupant)
	_check(bool(registration.registered) and not bool(registration.simulation_authority), "remote peers track occupancy without taking simulation authority")
	_check(not occupant.has_meta(MovingFrame.OWNER_META) and occupant.platform_floor_layers == original_floor_layers, "remote registration does not mutate the live character controller")
	coordinator.reset_frame_tracking(true)
	var remote_position := occupant.global_position
	frame.global_position.x = 2.0
	var remote_step: Dictionary = coordinator.step_frame(0.5, _next_token())
	_check(int(remote_step.occupants_applied) == 0 and occupant.global_position.is_equal_approx(remote_position), "remote authority never applies moving-frame compensation")

	coordinator.set_multiplayer_authority(1)
	frame.global_position.x = 3.0
	coordinator.step_frame(0.5, _next_token())
	_check(occupant.has_meta(MovingFrame.OWNER_META) and occupant.platform_floor_layers == 0, "authority transfer prepares the controller and rebases without replay")
	var authoritative_position := occupant.global_position
	frame.global_position.x = 4.0
	coordinator.step_frame(0.5, _next_token())
	_check(occupant.global_position.is_equal_approx(authoritative_position + Vector3.RIGHT), "new authority begins compensation on the following frame")

	coordinator.set_multiplayer_authority(2)
	frame.global_position.x = 5.0
	coordinator.step_frame(0.5, _next_token())
	_check(not occupant.has_meta(MovingFrame.OWNER_META) and occupant.process_physics_priority == original_priority and occupant.platform_floor_layers == original_floor_layers, "authority loss restores local controller state without dropping replicated occupancy")
	coordinator.unregister_occupant(occupant, false)
	fixture.root.free()
	api.multiplayer_peer = previous_peer
	peer.close()


func _test_ownership_reparent_free_and_reuse() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var frame_a := Node3D.new()
	frame_a.name = "FrameA"
	root_node.add_child(frame_a)
	var frame_b := Node3D.new()
	frame_b.name = "FrameB"
	root_node.add_child(frame_b)
	var coordinator_a := MovingFrame.new()
	frame_a.add_child(coordinator_a)
	coordinator_a.configure(frame_a, AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20)))
	coordinator_a.set_physics_process(false)
	var coordinator_b := MovingFrame.new()
	frame_b.add_child(coordinator_b)
	coordinator_b.configure(frame_b, AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20)))
	coordinator_b.set_physics_process(false)
	var occupant := _make_occupant("ReusableOccupant")
	root_node.add_child(occupant)

	_check(bool(coordinator_a.register_occupant(occupant).registered), "first moving frame claims an occupant")
	var competing: Dictionary = coordinator_b.register_occupant(occupant)
	_check(not bool(competing.registered) and competing.status == &"owned_by_other_frame", "overlapping frames cannot double-own one occupant")
	coordinator_a.unregister_occupant(occupant, false)
	_check(bool(coordinator_b.register_occupant(occupant).registered), "released occupants can be reused by another ship")
	coordinator_b.unregister_occupant(occupant, false)

	coordinator_a.register_occupant(occupant)
	var world_before_reparent := occupant.global_transform
	occupant.reparent(frame_a, true)
	frame_a.global_position = Vector3(4, 0, 0)
	coordinator_a.step_frame(0.5, _next_token())
	_check(not coordinator_a.is_occupant_registered(occupant), "reparenting under the moving hierarchy automatically releases compensation")
	_check(occupant.global_transform.is_equal_approx(Transform3D(world_before_reparent.basis, world_before_reparent.origin + Vector3(4, 0, 0))), "parented occupant receives only hierarchy motion, never double compensation")
	occupant.reparent(root_node, true)
	_check(bool(coordinator_a.register_occupant(occupant).registered), "reparented occupants can register again after returning to world hierarchy")

	var restored_priority := 13
	coordinator_a.unregister_occupant(occupant, false)
	occupant.process_physics_priority = restored_priority
	coordinator_a.register_occupant(occupant)
	coordinator_a.queue_free()
	await process_frame
	_check(occupant.process_physics_priority == restored_priority and not occupant.has_meta(MovingFrame.OWNER_META), "component teardown restores occupant state and ownership")

	# A freed occupant removes itself through the authority-safe tree lifecycle.
	var replacement_coordinator := MovingFrame.new()
	frame_a.add_child(replacement_coordinator)
	replacement_coordinator.configure(frame_a, AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20)))
	replacement_coordinator.set_physics_process(false)
	replacement_coordinator.register_occupant(occupant)
	occupant.queue_free()
	await process_frame
	_check(replacement_coordinator.get_occupant_count() == 0, "freeing an occupant cannot leave a stale registration")

	var frame_exit_occupant := _make_occupant("FrameExitOccupant")
	root_node.add_child(frame_exit_occupant)
	frame_exit_occupant.global_position = frame_b.global_position + Vector3(0, 1, 0)
	var original_frame_exit_priority := frame_exit_occupant.process_physics_priority
	coordinator_b.register_occupant(frame_exit_occupant)
	frame_b.queue_free()
	await process_frame
	_check(
		frame_exit_occupant.process_physics_priority == original_frame_exit_priority
		and not frame_exit_occupant.has_meta(MovingFrame.OWNER_META),
		"freeing the moving frame safely releases and restores surviving occupants"
	)
	root_node.queue_free()
	await process_frame


func _test_component_detach_readd() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var frame := Node3D.new()
	world.add_child(frame)
	var coordinator := MovingFrame.new()
	frame.add_child(coordinator)
	coordinator.configure(frame, AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10)))
	coordinator.set_physics_process(false)
	var occupant := _make_occupant("DetachReaddOccupant")
	world.add_child(occupant)
	occupant.global_position = Vector3(0, 1, 0)
	var original_priority := occupant.process_physics_priority
	coordinator.register_occupant(occupant)

	frame.remove_child(coordinator)
	_check(not occupant.has_meta(MovingFrame.OWNER_META) and occupant.process_physics_priority == original_priority, "detaching a reusable component restores every occupant immediately")
	frame.add_child(coordinator)
	await process_frame
	coordinator.set_physics_process(false)
	_check(coordinator.get_moving_frame() == frame and bool(coordinator.register_occupant(occupant).registered), "the same component reconnects and registers after remove/re-add")
	occupant.queue_free()
	await process_frame
	_check(coordinator.get_occupant_count() == 0, "re-added component reconnects occupant tree-exit cleanup")
	world.queue_free()
	await process_frame


func _test_direct_step_currentness() -> void:
	var detached_fixture := _manual_fixture()
	var detached_root := detached_fixture.root as Node3D
	var detached_frame := detached_fixture.frame as Node3D
	var detached_coordinator := detached_fixture.coordinator as MovingInteriorFrame
	var detached_occupant := detached_fixture.occupant as CharacterBody3D
	detached_coordinator.register_occupant(detached_occupant)
	detached_coordinator.step_frame(0.25, _next_token())
	detached_frame.remove_child(detached_coordinator)
	await process_frame
	var detached_snapshot := _frame_step_snapshot(detached_coordinator, detached_occupant)
	var detached_token := _next_token()
	detached_frame.global_position += Vector3(3.0, 0.5, -1.0)
	var detached_step := detached_coordinator.step_frame(0.25, detached_token)
	_check(
		not detached_coordinator.is_inside_tree()
			and not bool(detached_step.get("applied", true))
			and detached_step.get("status") == &"frame_unavailable"
			and _frame_step_snapshot(detached_coordinator, detached_occupant) == detached_snapshot,
		"detached direct frame stepping is inert before token, kinematic, or occupant mutation"
	)

	detached_frame.add_child(detached_coordinator)
	await process_frame
	detached_coordinator.set_physics_process(false)
	var reentry_registration := detached_coordinator.register_occupant(detached_occupant)
	var reentry_baseline := detached_coordinator.step_frame(0.25, detached_token)
	var reentry_origin := detached_occupant.global_position
	detached_frame.global_position += Vector3(-2.0, 0.25, 1.5)
	var reentry_step := detached_coordinator.step_frame(0.25, _next_token())
	_check(
		bool(reentry_registration.get("registered", false))
			and reentry_baseline.get("status") == &"baseline_captured"
			and bool(reentry_step.get("applied", false))
			and detached_occupant.global_position.distance_to(reentry_origin) > 0.1,
		"reentered live frame accepts the preserved next token and resumes one current occupant step"
	)
	detached_root.queue_free()
	await process_frame

	var queued_fixture := _manual_fixture()
	var queued_root := queued_fixture.root as Node3D
	var queued_frame := queued_fixture.frame as Node3D
	var queued_coordinator := queued_fixture.coordinator as MovingInteriorFrame
	var queued_occupant := queued_fixture.occupant as CharacterBody3D
	queued_coordinator.register_occupant(queued_occupant)
	queued_coordinator.step_frame(0.25, _next_token())
	var queued_snapshot := _frame_step_snapshot(queued_coordinator, queued_occupant)
	queued_frame.global_position += Vector3(4.0, -0.25, 2.0)
	queued_coordinator.queue_free()
	var queued_step := queued_coordinator.step_frame(0.25, _next_token())
	_check(
		queued_coordinator.is_inside_tree()
			and queued_coordinator.is_queued_for_deletion()
			and not bool(queued_step.get("applied", true))
			and queued_step.get("status") == &"frame_unavailable"
			and _frame_step_snapshot(queued_coordinator, queued_occupant) == queued_snapshot,
		"queued direct frame stepping preserves occupant ownership and physics state without applying the pending frame motion"
	)
	await process_frame
	queued_root.queue_free()
	await process_frame


func _test_stale_frame_registration_is_atomic() -> void:
	var queued_fixture := _manual_fixture()
	var queued_root := queued_fixture.root as Node3D
	var queued_frame := queued_fixture.frame as Node3D
	var queued_coordinator := queued_fixture.coordinator as MovingInteriorFrame
	var queued_occupant := queued_fixture.occupant as CharacterBody3D
	var queued_priority := queued_occupant.process_physics_priority
	var queued_up := queued_occupant.up_direction
	var queued_floor_layers := queued_occupant.platform_floor_layers
	var queued_wall_layers := queued_occupant.platform_wall_layers
	var queued_leave := queued_occupant.platform_on_leave
	var queued_rejections: Array[StringName] = []
	queued_coordinator.occupant_registration_rejected.connect(
		func(_occupant: Node3D, status: StringName) -> void: queued_rejections.append(status)
	)
	queued_coordinator.queue_free()
	var queued_result := queued_coordinator.register_occupant(queued_occupant)
	_check(
		not bool(queued_result.registered)
		and queued_result.status == &"frame_teardown"
		and queued_coordinator.is_queued_for_deletion()
		and queued_coordinator.get_occupant_count() == 0
		and queued_rejections.is_empty()
		and queued_occupant.process_physics_priority == queued_priority
		and queued_occupant.up_direction.is_equal_approx(queued_up)
		and queued_occupant.platform_floor_layers == queued_floor_layers
		and queued_occupant.platform_wall_layers == queued_wall_layers
		and queued_occupant.platform_on_leave == queued_leave
		and not queued_occupant.has_meta(MovingFrame.OWNER_META)
		and not queued_occupant.has_meta(MovingFrame.REGISTRATION_META),
		"queued moving frame rejects registration before signal, ownership, or occupant physics mutation"
	)
	await process_frame
	queued_root.queue_free()
	await process_frame

	var detached_fixture := _manual_fixture()
	var detached_root := detached_fixture.root as Node3D
	var detached_frame := detached_fixture.frame as Node3D
	var detached_coordinator := detached_fixture.coordinator as MovingInteriorFrame
	var detached_occupant := detached_fixture.occupant as CharacterBody3D
	var detached_priority := detached_occupant.process_physics_priority
	detached_frame.remove_child(detached_coordinator)
	var detached_result := detached_coordinator.register_occupant(detached_occupant)
	_check(
		not bool(detached_result.registered)
		and detached_result.status == &"frame_teardown"
		and not detached_coordinator.is_inside_tree()
		and detached_coordinator.get_occupant_count() == 0
		and detached_occupant.process_physics_priority == detached_priority
		and not detached_occupant.has_meta(MovingFrame.OWNER_META)
		and not detached_occupant.has_meta(MovingFrame.REGISTRATION_META),
		"detached moving frame rejects registration without retaining stale occupant authority"
	)
	detached_frame.add_child(detached_coordinator)
	_check(
		bool(detached_coordinator.register_occupant(detached_occupant).registered),
		"re-entered moving frame restores live registration authority"
	)
	detached_root.queue_free()
	await process_frame


func _test_volume_provenance_and_handoff() -> void:
	var world := Node3D.new()
	world.name = "VolumeLifecycleWorld"
	root.add_child(world)
	var frame := Node3D.new()
	world.add_child(frame)
	var volume_a := _make_volume(frame, "VolumeA", Vector3.ZERO)
	var coordinator := MovingFrame.new()
	frame.add_child(coordinator)
	coordinator.configure(frame, AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8)), volume_a)

	var occupant := _make_colliding_occupant("ManualInsideVolume")
	world.add_child(occupant)
	occupant.global_position = Vector3.ZERO
	coordinator.register_occupant(occupant)
	for _tick in range(3):
		await physics_frame
	occupant.global_position = Vector3(12, 0, 0)
	for _tick in range(3):
		await physics_frame
	_check(coordinator.is_occupant_registered(occupant), "Area exit never unregisters an occupant whose provenance is manual")
	coordinator.unregister_occupant(occupant, false)

	occupant.global_position = Vector3.ZERO
	for _tick in range(3):
		await physics_frame
	_check(coordinator.is_occupant_registered(occupant), "returning through the Area registers a volume-owned occupant")
	var volume_far := _make_volume(frame, "ReplacementVolume", Vector3(30, 0, 0))
	coordinator.set_occupant_volume(volume_far)
	_check(not coordinator.is_occupant_registered(occupant), "replacing an Area releases registrations sourced by the old Area")
	coordinator.set_occupant_volume(volume_a)
	for _tick in range(3):
		await physics_frame
	_check(coordinator.is_occupant_registered(occupant), "reconnecting an Area discovers bodies that already overlap it")
	coordinator.unregister_occupant(occupant, false)
	coordinator.set_interior_bounds(AABB(Vector3(-4, 0.5, -4), Vector3(8, 3.5, 8)))
	occupant.global_position = Vector3(12, 0.2, 0)
	for _tick in range(2):
		await physics_frame
	occupant.global_position = Vector3(0, 0.2, 0)
	# A threshold body_entered fires while the CharacterBody origin is still just
	# outside the stricter published AABB, even though its capsule overlaps Area.
	for _tick in range(3):
		await physics_frame
	_check(not coordinator.is_occupant_registered(occupant), "threshold overlap remains rejected until the body origin enters bounds")
	occupant.global_position.y = 0.8
	for _tick in range(3):
		await physics_frame
	_check(coordinator.is_occupant_registered(occupant), "outside-bounds Area candidate retries after crossing fully into the interior")
	coordinator.set_interior_bounds(AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8)))
	volume_a.queue_free()
	await process_frame
	_check(not coordinator.is_occupant_registered(occupant) and coordinator.get_occupant_volume() == null, "freeing the configured Area releases its occupants and clears the reference")

	# Two ship volumes may overlap at a dock threshold. The rejected component
	# retains only a weak candidate and claims it after the first owner releases.
	var handoff_volume_a := _make_volume(frame, "HandoffVolumeA", Vector3.ZERO)
	var handoff_volume_b := _make_volume(frame, "HandoffVolumeB", Vector3.ZERO)
	var coordinator_a := MovingFrame.new()
	var coordinator_b := MovingFrame.new()
	frame.add_child(coordinator_a)
	frame.add_child(coordinator_b)
	var bounds := AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	coordinator_a.configure(frame, bounds, handoff_volume_a)
	coordinator_b.configure(frame, bounds, handoff_volume_b)
	for _tick in range(4):
		await physics_frame
	var a_owned := coordinator_a.is_occupant_registered(occupant)
	var b_owned := coordinator_b.is_occupant_registered(occupant)
	_check(a_owned != b_owned, "overlapping automatic volumes establish exactly one owner")
	var first_owner: MovingInteriorFrame = coordinator_a if a_owned else coordinator_b
	var waiting_owner: MovingInteriorFrame = coordinator_b if a_owned else coordinator_a
	first_owner.unregister_occupant(occupant, false, &"dock_handoff")
	for _tick in range(3):
		await physics_frame
	_check(waiting_owner.is_occupant_registered(occupant), "overlapping volume retries and completes ownership handoff without another body_entered signal")

	world.queue_free()
	await process_frame
	await process_frame


func _test_physical_standing_and_auto_volume() -> void:
	var world := Node3D.new()
	world.name = "MovingInteriorPhysicsWorld"
	root.add_child(world)

	var frame := AcceleratingFrame.new()
	frame.name = "AcceleratingFreighter"
	frame.process_physics_priority = -30
	world.add_child(frame)

	var floor := AnimatableBody3D.new()
	floor.name = "InteriorDeck"
	floor.collision_layer = 1
	floor.collision_mask = 1
	frame.add_child(floor)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12, 0.2, 12)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)

	var volume := Area3D.new()
	volume.name = "InteriorOccupantVolume"
	volume.collision_layer = 0
	volume.collision_mask = 1
	volume.monitoring = true
	frame.add_child(volume)
	var volume_shape := CollisionShape3D.new()
	var volume_box := BoxShape3D.new()
	volume_box.size = Vector3(10, 4, 10)
	volume_shape.shape = volume_box
	volume_shape.position.y = 2.0
	volume.add_child(volume_shape)

	var coordinator := MovingFrame.new()
	coordinator.name = "MovingInteriorFrame"
	frame.add_child(coordinator)
	coordinator.configure(frame, AABB(Vector3(-5, -0.5, -5), Vector3(10, 5, 10)), volume)

	var occupant := PhysicsOccupant.new()
	occupant.name = "WalkingOccupant"
	occupant.collision_layer = 1
	occupant.collision_mask = 1
	occupant.floor_snap_length = 0.35
	occupant.platform_floor_layers = 1
	var occupant_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	occupant_shape.shape = capsule
	occupant.add_child(occupant_shape)
	world.add_child(occupant)
	occupant.global_position = Vector3(1.75, 0.81, -1.2)

	for _settle_tick in range(10):
		await physics_frame
	_check(coordinator.is_occupant_registered(occupant), "Area3D volume auto-registers a physical interior occupant")
	_check(occupant.is_on_floor(), "occupant settles on the real ship-local collision deck")
	var stable_local_position := frame.to_local(occupant.global_position)
	frame.motion_enabled = true
	for _motion_tick in range(90):
		await physics_frame
	var moved_local_position := frame.to_local(occupant.global_position)
	var planar_drift := Vector2(
		moved_local_position.x - stable_local_position.x,
		moved_local_position.z - stable_local_position.z
	).length()
	_check(frame.global_position.length() > 1.0 and absf(frame.rotation.z) > 0.05, "standing test exercises accelerating translation and frame rotation")
	_check(planar_drift < 0.08, "standing occupant retains a stable ship-local deck position")
	_check(absf(moved_local_position.y - stable_local_position.y) < 0.08, "standing occupant does not jitter or fall through the moving deck")
	_check(occupant.floor_ticks > 70 and occupant.is_on_floor(), "ship-local up and real collisions preserve floor contact")
	_check(coordinator.get_frame_linear_acceleration().length() > 0.1, "live component observes the ship's acceleration")

	# Use a passive probe for exact-once evidence: the physical CharacterBody can
	# legitimately drift by collision recovery within a tick, while a Node3D has no
	# independent motion at all. One frame delta preserves its local transform;
	# applying none or two changes it deterministically.
	var exact_once_probe := Node3D.new()
	exact_once_probe.name = "ExactOnceProbe"
	world.add_child(exact_once_probe)
	exact_once_probe.global_position = frame.to_global(Vector3(-2.0, 1.5, 1.0))
	coordinator.register_occupant(exact_once_probe)
	# SceneTree.physics_frame fires before node callbacks. Finish the current tick,
	# then bracket exactly one complete subsequent tick process-to-process.
	await process_frame
	var local_before_single_tick := frame.to_local(exact_once_probe.global_position)
	await physics_frame
	await process_frame
	_check(frame.to_local(exact_once_probe.global_position).distance_to(local_before_single_tick) < 0.0001, "automatic physics ordering applies the frame exactly once per tick")

	# Crossing the actual volume boundary invokes the same exit inheritance API.
	occupant.global_position = frame.to_global(Vector3(8, 1, 0))
	for _exit_tick in range(3):
		await physics_frame
	_check(not coordinator.is_occupant_registered(occupant), "leaving the interior Area3D automatically releases the occupant")
	_check(occupant.velocity.length() > 0.1, "automatic volume exit inherits live frame motion")

	world.queue_free()
	await process_frame
	await process_frame


func _manual_fixture() -> Dictionary:
	var root_node := Node3D.new()
	root_node.name = "ManualMovingInteriorFixture"
	root.add_child(root_node)
	var frame := Node3D.new()
	frame.name = "MovingFrame"
	frame.process_physics_priority = -20
	root_node.add_child(frame)
	var coordinator := MovingFrame.new()
	coordinator.name = "Coordinator"
	frame.add_child(coordinator)
	coordinator.configure(frame, AABB(Vector3(-5, -2, -6), Vector3(10, 7, 12)))
	coordinator.set_physics_process(false)
	var occupant := _make_occupant("Occupant")
	root_node.add_child(occupant)
	occupant.global_position = Vector3(1, 1, 0)
	return {
		"root": root_node,
		"frame": frame,
		"coordinator": coordinator,
		"occupant": occupant,
	}


func _frame_step_snapshot(
		coordinator: MovingInteriorFrame,
		occupant: CharacterBody3D
	) -> Dictionary:
	return {
		"registered": coordinator.is_occupant_registered(occupant),
		"occupant_count": coordinator.get_occupant_count(),
		"occupant_transform": occupant.global_transform,
		"occupant_velocity": occupant.velocity,
		"occupant_up_direction": occupant.up_direction,
		"linear_velocity": coordinator.get_frame_linear_velocity(),
		"angular_velocity": coordinator.get_frame_angular_velocity(),
		"linear_acceleration": coordinator.get_frame_linear_acceleration(),
		"angular_acceleration": coordinator.get_frame_angular_acceleration(),
	}.duplicate(true)


func _make_occupant(node_name: String) -> CharacterBody3D:
	var occupant := CharacterBody3D.new()
	occupant.name = node_name
	occupant.process_physics_priority = 4
	occupant.platform_floor_layers = 0xA5
	occupant.platform_wall_layers = 0x5A
	occupant.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	return occupant


func _make_colliding_occupant(node_name: String) -> CharacterBody3D:
	var occupant := _make_occupant(node_name)
	occupant.collision_layer = 1
	occupant.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.0
	collision.shape = shape
	occupant.add_child(collision)
	return occupant


func _make_volume(parent: Node3D, node_name: String, position: Vector3) -> Area3D:
	var volume := Area3D.new()
	volume.name = node_name
	volume.position = position
	volume.collision_layer = 0
	volume.collision_mask = 1
	volume.monitoring = true
	parent.add_child(volume)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8, 8, 8)
	collision.shape = shape
	volume.add_child(collision)
	return volume


func _next_token() -> int:
	_step_token += 1
	return _step_token


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("MOVING_INTERIOR_FRAME_TEST_OK")
		quit(0)
	else:
		print("MOVING_INTERIOR_FRAME_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
