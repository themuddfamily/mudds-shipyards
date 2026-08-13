class_name MovingInteriorFrame
extends Node

## Keeps physical occupants in one world while a spacecraft translates, rotates,
## and accelerates around them.
##
## This node is a pre-occupant physics coordinator, not a second interior level.
## It samples a live [Node3D] frame after the ship has moved, applies that frame's
## complete rigid transform delta once to every registered occupant, and leaves
## each CharacterBody3D's `velocity` as occupant-relative world velocity while it
## is aboard. On exit, the frame's linear velocity and `angular_velocity × radius`
## are added exactly once.
##
## Character controllers remain responsible for calling `move_and_slide()`. If a
## controller adds global gravity itself, opt into `compensate_world_gravity` at
## registration or, preferably, consume [method get_frame_gravity] directly.

signal occupant_registered(occupant: Node3D)
signal occupant_unregistered(occupant: Node3D, exit_velocity: Vector3, reason: StringName)
signal occupant_registration_rejected(occupant: Node3D, status: StringName)
signal frame_reset

enum AuthorityMode {
	## The node owning this component is the simulation authority. Recommended for
	## a server-authoritative ship and all occupants physically aboard it.
	FRAME_AUTHORITY,
	## Each occupant's multiplayer authority applies its compensation.
	OCCUPANT_AUTHORITY,
	## Both frame and occupant authority must agree on this peer.
	FRAME_AND_OCCUPANT_AUTHORITY,
	## Useful for deterministic tests and explicitly non-networked scenes.
	UNRESTRICTED,
}

const OWNER_META: StringName = &"_moving_interior_frame_owner"
const REGISTRATION_META: StringName = &"_moving_interior_frame_registration"
const DEFAULT_FRAME_PRIORITY_OFFSET := 1
const DEFAULT_OCCUPANT_PRIORITY_OFFSET := 1
const MINIMUM_STEP_DELTA := 0.000001
const DEFAULT_TELEPORT_DISTANCE := 250.0
const DEFAULT_TELEPORT_ANGLE_DEGREES := 120.0

@export_category("Frame")
@export_node_path("Node3D") var moving_frame_path: NodePath
@export var interior_bounds := AABB()
@export_range(0.0, 10000.0, 0.5) var teleport_distance_threshold := DEFAULT_TELEPORT_DISTANCE
@export_range(0.0, 180.0, 1.0) var teleport_angle_threshold_degrees := DEFAULT_TELEPORT_ANGLE_DEGREES

@export_category("Automatic occupancy")
@export_node_path("Area3D") var occupant_volume_path: NodePath
@export var auto_register_from_volume := true
@export var require_inside_bounds_on_register := true

@export_category("Execution")
@export var authority_mode := AuthorityMode.FRAME_AUTHORITY
@export_range(1, 64, 1) var frame_priority_offset := DEFAULT_FRAME_PRIORITY_OFFSET
@export_range(1, 64, 1) var occupant_priority_offset := DEFAULT_OCCUPANT_PRIORITY_OFFSET

var _moving_frame: Node3D
var _occupant_volume: Area3D
var _occupants: Dictionary = {}
var _previous_frame_transform := Transform3D.IDENTITY
var _has_frame_sample := false
var _frame_linear_velocity := Vector3.ZERO
var _frame_angular_velocity := Vector3.ZERO
var _frame_linear_acceleration := Vector3.ZERO
var _frame_angular_acceleration := Vector3.ZERO
var _sampled_frame_origin := Vector3.ZERO
var _has_velocity_sample := false
var _last_step_token := -1
var _base_physics_priority := 0
var _tearing_down := false
var _volume_registered_ids: Dictionary = {}
var _pending_volume_occupants: Dictionary = {}


func _enter_tree() -> void:
	_tearing_down = false
	request_ready()


func _ready() -> void:
	_base_physics_priority = process_physics_priority
	interior_bounds = _canonical_aabb(interior_bounds)
	var resolved_frame := _moving_frame
	if not is_instance_valid(resolved_frame):
		resolved_frame = get_node_or_null(moving_frame_path) as Node3D \
			if not moving_frame_path.is_empty() else get_parent() as Node3D
	set_moving_frame(resolved_frame)
	var resolved_volume := _occupant_volume
	if not is_instance_valid(resolved_volume):
		resolved_volume = get_node_or_null(occupant_volume_path) as Area3D \
			if not occupant_volume_path.is_empty() else null
	set_occupant_volume(resolved_volume)
	if auto_register_from_volume and _occupant_volume != null:
		call_deferred("_register_existing_overlaps")


func _exit_tree() -> void:
	_tearing_down = true
	_disconnect_frame()
	# Preserve directly configured references while this reusable component is
	# merely detached. _ready() reconnects them if it is added to the tree again.
	_disconnect_volume(false, false)
	clear_occupants(false, &"frame_teardown")
	_pending_volume_occupants.clear()
	_has_frame_sample = false


func _physics_process(delta: float) -> void:
	_retry_pending_volume_occupants()
	step_frame(delta, int(Engine.get_physics_frames()))


## Configures the complete integration seam used by a large ship scene. Bounds
## are expressed in `moving_frame` local coordinates. A zero-sized AABB disables
## bounds filtering; an Area3D is optional because callers may register manually.
func configure(frame: Node3D, bounds: AABB = AABB(), volume: Area3D = null) -> void:
	interior_bounds = _canonical_aabb(bounds)
	set_moving_frame(frame)
	set_occupant_volume(volume)


func set_moving_frame(frame: Node3D) -> void:
	if frame == _moving_frame:
		_connect_frame()
		return
	var was_tearing_down := _tearing_down
	_tearing_down = true
	clear_occupants(false, &"moving_frame_changed")
	_disconnect_frame()
	_moving_frame = frame
	_connect_frame()
	reset_frame_tracking(true)
	_refresh_execution_order()
	_tearing_down = was_tearing_down


func get_moving_frame() -> Node3D:
	return _moving_frame


func set_interior_bounds(bounds: AABB) -> void:
	interior_bounds = _canonical_aabb(bounds)


func get_interior_bounds() -> AABB:
	return interior_bounds


func has_interior_bounds() -> bool:
	return interior_bounds.size.x > 0.0 and interior_bounds.size.y > 0.0 and interior_bounds.size.z > 0.0


func contains_world_position(world_position: Vector3) -> bool:
	if not has_interior_bounds():
		return true
	if not is_instance_valid(_moving_frame):
		return false
	return interior_bounds.has_point(_sample_frame_transform().affine_inverse() * world_position)


func set_occupant_volume(volume: Area3D) -> void:
	if volume == _occupant_volume:
		_connect_volume()
		return
	_disconnect_volume(true, true)
	_occupant_volume = volume
	if not is_instance_valid(_occupant_volume):
		return
	_connect_volume()
	if is_inside_tree() and auto_register_from_volume:
		call_deferred("_register_existing_overlaps")


func get_occupant_volume() -> Area3D:
	return _occupant_volume


## Registers a world-space occupant without reparenting it. Options are copied
## and allow per-controller integration:
##
## - `rotate_basis` (true): rotate the whole occupant with the deck.
## - `rotate_velocity` (true): rotate CharacterBody relative velocity.
## - `align_up_direction` (true): use ship-local +Y for floor classification.
## - `disable_builtin_platform_follow` (true): prevents double platform motion.
## - `manage_physics_priority` (true): ship → frame → occupant ordering.
## - `inherit_velocity_on_exit` (true): impart linear + angular frame velocity.
## - `compensate_world_gravity` (false): pre-correct a controller known to add
##   world gravity later in the same tick so its net gravity points deck-down.
## - `require_inside_bounds`: overrides the component default.
func register_occupant(occupant: Node3D, options: Dictionary = {}) -> Dictionary:
	var result := _registration_result(occupant)
	if _tearing_down:
		result["status"] = &"frame_teardown"
		if is_instance_valid(occupant):
			occupant_registration_rejected.emit(occupant, result["status"])
		return result
	if not is_instance_valid(occupant):
		result["status"] = &"invalid_occupant"
		return result
	if not is_instance_valid(_moving_frame):
		result["status"] = &"missing_frame"
		return result
	if occupant == _moving_frame or occupant.is_ancestor_of(_moving_frame):
		result["status"] = &"invalid_hierarchy"
		return result
	if _moving_frame.is_ancestor_of(occupant):
		result["status"] = &"already_in_frame_hierarchy"
		return result

	var occupant_id := occupant.get_instance_id()
	if _occupants.has(occupant_id):
		result["status"] = &"already_registered"
		result["registered"] = true
		result["simulation_authority"] = _can_simulate_occupant(occupant)
		return result

	var prior_owner_ref: Variant = occupant.get_meta(REGISTRATION_META) \
		if occupant.has_meta(REGISTRATION_META) else null
	# OWNER_META predates the separate tracking marker. Respect it so an older or
	# independently loaded coordinator cannot double-apply the same body.
	if prior_owner_ref == null and occupant.has_meta(OWNER_META):
		prior_owner_ref = occupant.get_meta(OWNER_META)
	if prior_owner_ref is WeakRef:
		var prior_owner: Variant = (prior_owner_ref as WeakRef).get_ref()
		if is_instance_valid(prior_owner) and prior_owner != self:
			result["status"] = &"owned_by_other_frame"
			occupant_registration_rejected.emit(occupant, result["status"])
			return result
	occupant.set_meta(REGISTRATION_META, weakref(self))

	var resolved_options := _resolved_options(options)
	if bool(resolved_options["require_inside_bounds"]) \
		and not contains_world_position(_node_world_transform(occupant).origin):
		_clear_registration_meta(occupant)
		result["status"] = &"outside_bounds"
		occupant_registration_rejected.emit(occupant, result["status"])
		return result

	var state := {
		"occupant": weakref(occupant),
		"options": resolved_options,
		"previous_frame_transform": _sample_frame_transform(),
		"original_priority": occupant.process_physics_priority,
		"assigned_priority": occupant.process_physics_priority,
		"tree_exiting_callable": Callable(self, "_on_occupant_tree_exiting").bind(occupant_id),
		"registration_source": StringName(options.get("registration_source", &"manual")),
		"simulation_prepared": false,
	}
	if occupant is CharacterBody3D:
		var body := occupant as CharacterBody3D
		state["original_up_direction"] = body.up_direction
		state["original_platform_floor_layers"] = body.platform_floor_layers
		state["original_platform_wall_layers"] = body.platform_wall_layers
		state["original_platform_on_leave"] = body.platform_on_leave

	_occupants[occupant_id] = state
	occupant.tree_exiting.connect(state["tree_exiting_callable"] as Callable)
	_sync_occupant_authority(occupant, state, _sample_frame_transform())
	_occupants[occupant_id] = state
	result["registered"] = true
	result["status"] = &"registered"
	result["simulation_authority"] = _can_simulate_occupant(occupant)
	result["registration_id"] = occupant_id
	occupant_registered.emit(occupant)
	return result


## Releases one occupant and optionally applies physically correct world exit
## velocity. The result always reports the calculated velocity, even for Node3D
## occupants that have no writable `velocity` property.
func unregister_occupant(
		occupant: Node3D,
		inherit_velocity: bool = true,
		reason: StringName = &"manual"
	) -> Dictionary:
	var result := {
		"released": false,
		"status": &"not_registered",
		"reason": reason,
		"occupant": occupant,
		"relative_velocity": Vector3.ZERO,
		"frame_velocity": Vector3.ZERO,
		"exit_velocity": Vector3.ZERO,
		"velocity_applied": false,
	}
	if not is_instance_valid(occupant):
		result["status"] = &"invalid_occupant"
		return result
	var occupant_id := occupant.get_instance_id()
	if not _occupants.has(occupant_id):
		return result

	var state: Dictionary = _occupants[occupant_id]
	var relative_velocity := _get_relative_velocity(occupant)
	var frame_velocity := get_frame_velocity_at_position(_node_world_transform(occupant).origin)
	var exit_velocity := relative_velocity + frame_velocity
	var should_inherit := inherit_velocity and bool((state["options"] as Dictionary)["inherit_velocity_on_exit"])

	_restore_occupant_state(occupant, state)
	_occupants.erase(occupant_id)
	_volume_registered_ids.erase(occupant_id)
	_pending_volume_occupants.erase(occupant_id)
	_clear_owner_meta(occupant)
	_clear_registration_meta(occupant)
	if should_inherit and occupant is CharacterBody3D and _can_simulate_occupant(occupant):
		(occupant as CharacterBody3D).velocity = exit_velocity
		result["velocity_applied"] = true

	result["released"] = true
	result["status"] = &"released"
	result["relative_velocity"] = relative_velocity
	result["frame_velocity"] = frame_velocity
	result["exit_velocity"] = exit_velocity
	occupant_unregistered.emit(occupant, exit_velocity, reason)
	return result


func is_occupant_registered(occupant: Node3D) -> bool:
	return is_instance_valid(occupant) and _occupants.has(occupant.get_instance_id())


func get_registered_occupants() -> Array[Node3D]:
	_prune_invalid_occupants()
	var result: Array[Node3D] = []
	for state: Dictionary in _occupants.values():
		var occupant: Variant = (state["occupant"] as WeakRef).get_ref()
		if is_instance_valid(occupant):
			result.append(occupant as Node3D)
	return result


func get_occupant_count() -> int:
	_prune_invalid_occupants()
	return _occupants.size()


func clear_occupants(inherit_velocity: bool = false, reason: StringName = &"cleared") -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for occupant in get_registered_occupants():
		reports.append(unregister_occupant(occupant, inherit_velocity, reason))
	return reports


## Samples and applies one frame update. Production code uses `_physics_process`;
## deterministic tests and rollback/replay code may supply a monotonically
## increasing token. Reusing a token is a guaranteed no-op.
func step_frame(delta: float, step_token: int = -1) -> Dictionary:
	var resolved_token := step_token
	if resolved_token < 0:
		resolved_token = int(Engine.get_physics_frames())
	var report := {
		"applied": false,
		"status": &"",
		"step_token": resolved_token,
		"occupants_considered": 0,
		"occupants_applied": 0,
		"discontinuity": false,
		"linear_velocity": _frame_linear_velocity,
		"angular_velocity": _frame_angular_velocity,
	}
	if not is_instance_valid(_moving_frame):
		report["status"] = &"missing_frame"
		clear_occupants(false, &"missing_frame")
		return report
	if delta <= MINIMUM_STEP_DELTA or is_nan(delta) or is_inf(delta):
		report["status"] = &"invalid_delta"
		return report
	if resolved_token <= _last_step_token:
		report["status"] = &"duplicate_step" if resolved_token == _last_step_token else &"out_of_order_step"
		return report
	_last_step_token = resolved_token

	_refresh_execution_order()
	_prune_invalid_occupants()
	var current_frame := _sample_frame_transform()
	if not _has_frame_sample:
		_previous_frame_transform = current_frame
		_sampled_frame_origin = current_frame.origin
		_has_frame_sample = true
		_sync_occupant_frame_samples(current_frame)
		report["status"] = &"baseline_captured"
		return report

	var global_delta := current_frame * _previous_frame_transform.affine_inverse()
	var discontinuity := _is_frame_discontinuity(_previous_frame_transform, current_frame)
	_update_frame_kinematics(_previous_frame_transform, current_frame, delta, discontinuity)
	_previous_frame_transform = current_frame

	report["occupants_considered"] = _occupants.size()
	report["discontinuity"] = discontinuity
	report["linear_velocity"] = _frame_linear_velocity
	report["angular_velocity"] = _frame_angular_velocity
	var applied_count := 0
	var release_queue: Array[Node3D] = []
	for occupant_id: int in _occupants.keys():
		var state: Dictionary = _occupants[occupant_id]
		var occupant_variant: Variant = (state["occupant"] as WeakRef).get_ref()
		if not is_instance_valid(occupant_variant):
			continue
		var occupant := occupant_variant as Node3D
		if _moving_frame.is_ancestor_of(occupant) or occupant.is_ancestor_of(_moving_frame):
			release_queue.append(occupant)
			continue
		var authority_changed := _sync_occupant_authority(occupant, state, current_frame)
		var occupant_previous_frame: Transform3D = state["previous_frame_transform"]
		var occupant_delta := current_frame * occupant_previous_frame.affine_inverse()
		state["previous_frame_transform"] = current_frame
		if bool(state["simulation_prepared"]) and not authority_changed:
			_apply_frame_delta(occupant, state, occupant_delta, delta)
			applied_count += 1
		_occupants[occupant_id] = state

	for occupant in release_queue:
		unregister_occupant(occupant, false, &"parented_to_frame")
	report["occupants_applied"] = applied_count
	report["applied"] = true
	report["status"] = &"applied"
	# Expose the aggregate delta for diagnostics without making callers apply it.
	report["frame_delta"] = global_delta
	return report


## Clears velocity history after a dock snap, respawn, network correction, or
## scene reuse. When `carry_occupants_with_frame` is true, an already-applied
## external frame teleport first carries occupants by the same rigid delta but
## deliberately contributes no exit velocity. The default only rebases samples,
## which is appropriate while configuring a new frame or resetting an empty ship.
func reset_frame_tracking(
		preserve_occupants: bool = true,
		carry_occupants_with_frame: bool = false
	) -> void:
	_frame_linear_velocity = Vector3.ZERO
	_frame_angular_velocity = Vector3.ZERO
	_frame_linear_acceleration = Vector3.ZERO
	_frame_angular_acceleration = Vector3.ZERO
	_has_velocity_sample = false
	_last_step_token = -1
	if is_instance_valid(_moving_frame):
		var current_frame := _sample_frame_transform()
		if preserve_occupants and carry_occupants_with_frame and _has_frame_sample:
			for occupant_id: int in _occupants.keys():
				var state: Dictionary = _occupants[occupant_id]
				var occupant_variant: Variant = (state["occupant"] as WeakRef).get_ref()
				if not is_instance_valid(occupant_variant):
					continue
				var occupant := occupant_variant as Node3D
				if _moving_frame.is_ancestor_of(occupant) or not _can_simulate_occupant(occupant):
					continue
				var prior_frame: Transform3D = state["previous_frame_transform"]
				_apply_frame_delta(
					occupant,
					state,
					current_frame * prior_frame.affine_inverse(),
					0.0
				)
		_previous_frame_transform = current_frame
		_sampled_frame_origin = current_frame.origin
		_has_frame_sample = true
		if preserve_occupants:
			_sync_occupant_frame_samples(_previous_frame_transform)
	else:
		_previous_frame_transform = Transform3D.IDENTITY
		_sampled_frame_origin = Vector3.ZERO
		_has_frame_sample = false
	if not preserve_occupants:
		clear_occupants(false, &"frame_reset")
	frame_reset.emit()


func get_frame_linear_velocity() -> Vector3:
	return _frame_linear_velocity


func get_frame_angular_velocity() -> Vector3:
	return _frame_angular_velocity


func get_frame_linear_acceleration() -> Vector3:
	return _frame_linear_acceleration


func get_frame_angular_acceleration() -> Vector3:
	return _frame_angular_acceleration


func get_frame_up_direction() -> Vector3:
	if not is_instance_valid(_moving_frame):
		return Vector3.UP
	var up := _sample_frame_transform().basis.y.normalized()
	return up if not up.is_zero_approx() else Vector3.UP


## Ship-local artificial gravity with the magnitude of the occupant's current
## physics-space gravity (or the project default when no body is supplied).
func get_frame_gravity(occupant: CharacterBody3D = null) -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if is_instance_valid(occupant) and occupant.is_inside_tree():
		var world_gravity := occupant.get_gravity()
		if world_gravity.is_finite():
			magnitude = world_gravity.length()
	return -get_frame_up_direction() * magnitude


func get_frame_velocity_at_position(world_position: Vector3) -> Vector3:
	if not is_instance_valid(_moving_frame):
		return Vector3.ZERO
	var radius := world_position - _sampled_frame_origin
	return _frame_linear_velocity + _frame_angular_velocity.cross(radius)


func get_exit_velocity(occupant: Node3D) -> Vector3:
	if not is_instance_valid(occupant):
		return Vector3.ZERO
	return _get_relative_velocity(occupant) \
		+ get_frame_velocity_at_position(_node_world_transform(occupant).origin)


func is_simulation_authority_for(occupant: Node3D) -> bool:
	return _can_simulate_occupant(occupant)


func get_status_report() -> Dictionary:
	return {
		"configured": is_instance_valid(_moving_frame),
		"moving_frame": _moving_frame,
		"occupant_volume": _occupant_volume,
		"interior_bounds": interior_bounds,
		"has_bounds": has_interior_bounds(),
		"occupant_count": get_occupant_count(),
		"linear_velocity": _frame_linear_velocity,
		"angular_velocity": _frame_angular_velocity,
		"linear_acceleration": _frame_linear_acceleration,
		"angular_acceleration": _frame_angular_acceleration,
		"up_direction": get_frame_up_direction(),
		"authority_mode": authority_mode,
	}


func _apply_frame_delta(
		occupant: Node3D,
		state: Dictionary,
		frame_delta: Transform3D,
		delta: float
	) -> void:
	var options: Dictionary = state["options"]
	var original_transform := _node_world_transform(occupant)
	var transformed_origin := frame_delta * original_transform.origin
	var transformed_basis := original_transform.basis
	if bool(options["rotate_basis"]):
		transformed_basis = frame_delta.basis * transformed_basis
	_set_node_world_transform(occupant, Transform3D(transformed_basis, transformed_origin))

	if occupant is not CharacterBody3D:
		return
	var body := occupant as CharacterBody3D
	if bool(options["rotate_velocity"]):
		body.velocity = frame_delta.basis * body.velocity
	if bool(options["align_up_direction"]):
		body.up_direction = get_frame_up_direction()
	if bool(options["compensate_world_gravity"]) and not body.is_on_floor():
		var world_gravity := body.get_gravity() if body.is_inside_tree() else Vector3(0.0, -9.8, 0.0)
		body.velocity += (get_frame_gravity(body) - world_gravity) * delta


func _prepare_character_body(body: CharacterBody3D, state: Dictionary) -> void:
	var options: Dictionary = state["options"]
	if bool(options["align_up_direction"]):
		body.up_direction = get_frame_up_direction()
	if bool(options["disable_builtin_platform_follow"]):
		body.platform_floor_layers = 0
		body.platform_wall_layers = 0
		body.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING


func _restore_occupant_state(occupant: Node3D, state: Dictionary) -> void:
	var exit_callable: Callable = state.get("tree_exiting_callable", Callable())
	if exit_callable.is_valid() and occupant.tree_exiting.is_connected(exit_callable):
		occupant.tree_exiting.disconnect(exit_callable)
	_restore_simulation_state(occupant, state)


func _restore_simulation_state(occupant: Node3D, state: Dictionary) -> void:
	if not bool(state.get("simulation_prepared", false)):
		return
	var options: Dictionary = state["options"]
	if bool(options["manage_physics_priority"]):
		occupant.process_physics_priority = int(state["original_priority"])
	if occupant is CharacterBody3D:
		var body := occupant as CharacterBody3D
		body.up_direction = state.get("original_up_direction", Vector3.UP)
		body.platform_floor_layers = int(state.get("original_platform_floor_layers", body.platform_floor_layers))
		body.platform_wall_layers = int(state.get("original_platform_wall_layers", body.platform_wall_layers))
		body.platform_on_leave = int(state.get("original_platform_on_leave", body.platform_on_leave))
	state["simulation_prepared"] = false


## Activates local-only controller integration when multiplayer authority arrives,
## and restores it when authority leaves without dropping replicated occupancy.
## A newly authoritative peer rebases at the current frame instead of replaying a
## transform delta that another authority already simulated.
func _sync_occupant_authority(
		occupant: Node3D,
		state: Dictionary,
		current_frame: Transform3D
	) -> bool:
	var should_prepare := _can_simulate_occupant(occupant)
	var is_prepared := bool(state.get("simulation_prepared", false))
	if should_prepare == is_prepared:
		return false
	if should_prepare:
		occupant.set_meta(OWNER_META, weakref(self))
		state["simulation_prepared"] = true
		if occupant is CharacterBody3D:
			_prepare_character_body(occupant as CharacterBody3D, state)
		_assign_occupant_priority(occupant, state)
	else:
		_restore_simulation_state(occupant, state)
		_clear_owner_meta(occupant)
	state["previous_frame_transform"] = current_frame
	return true


func _resolved_options(overrides: Dictionary) -> Dictionary:
	var options := {
		"rotate_basis": true,
		"rotate_velocity": true,
		"align_up_direction": true,
		"disable_builtin_platform_follow": true,
		"manage_physics_priority": true,
		"inherit_velocity_on_exit": true,
		"compensate_world_gravity": false,
		"require_inside_bounds": require_inside_bounds_on_register,
	}
	for key: Variant in overrides:
		if options.has(key) and typeof(overrides[key]) == TYPE_BOOL:
			options[key] = overrides[key]
	return options


func _registration_result(occupant: Node3D) -> Dictionary:
	return {
		"registered": false,
		"status": &"",
		"occupant": occupant,
		"registration_id": 0,
		"simulation_authority": false,
	}


func _refresh_execution_order() -> void:
	if not is_instance_valid(_moving_frame):
		return
	process_physics_priority = maxi(
		_base_physics_priority,
		_moving_frame.process_physics_priority + frame_priority_offset
	)
	for occupant_id: int in _occupants.keys():
		var state: Dictionary = _occupants[occupant_id]
		var occupant_variant: Variant = (state["occupant"] as WeakRef).get_ref()
		if is_instance_valid(occupant_variant) and bool(state.get("simulation_prepared", false)):
			_assign_occupant_priority(occupant_variant as Node3D, state)
			_occupants[occupant_id] = state


func _assign_occupant_priority(occupant: Node3D, state: Dictionary) -> void:
	if not bool((state["options"] as Dictionary)["manage_physics_priority"]):
		return
	var assigned := maxi(int(state["original_priority"]), process_physics_priority + occupant_priority_offset)
	occupant.process_physics_priority = assigned
	state["assigned_priority"] = assigned


func _can_simulate_occupant(occupant: Node3D) -> bool:
	if not is_instance_valid(occupant):
		return false
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return true
	match authority_mode:
		AuthorityMode.FRAME_AUTHORITY:
			return is_multiplayer_authority()
		AuthorityMode.OCCUPANT_AUTHORITY:
			return occupant.is_multiplayer_authority()
		AuthorityMode.FRAME_AND_OCCUPANT_AUTHORITY:
			return is_multiplayer_authority() and occupant.is_multiplayer_authority()
		AuthorityMode.UNRESTRICTED:
			return true
	return false


func _sample_frame_transform() -> Transform3D:
	if not is_instance_valid(_moving_frame):
		return Transform3D.IDENTITY
	var world_transform := _node_world_transform(_moving_frame)
	return Transform3D(world_transform.basis.orthonormalized(), world_transform.origin)


func _update_frame_kinematics(
		previous: Transform3D,
		current: Transform3D,
		delta: float,
		discontinuity: bool
	) -> void:
	var prior_linear_velocity := _frame_linear_velocity
	var prior_angular_velocity := _frame_angular_velocity
	if discontinuity:
		_frame_linear_velocity = Vector3.ZERO
		_frame_angular_velocity = Vector3.ZERO
		_frame_linear_acceleration = Vector3.ZERO
		_frame_angular_acceleration = Vector3.ZERO
		_sampled_frame_origin = current.origin
		_has_velocity_sample = false
		return
	_frame_linear_velocity = (current.origin - previous.origin) / delta
	var rotation_delta := (current.basis * previous.basis.inverse()).orthonormalized()
	var rotation_quaternion := rotation_delta.get_rotation_quaternion().normalized()
	var angle := _shortest_rotation_angle(rotation_quaternion.get_angle())
	var axis := rotation_quaternion.get_axis()
	_frame_angular_velocity = axis * (angle / delta) \
		if absf(angle) > 0.000001 and axis.is_finite() else Vector3.ZERO
	if _has_velocity_sample:
		_frame_linear_acceleration = (_frame_linear_velocity - prior_linear_velocity) / delta
		_frame_angular_acceleration = (_frame_angular_velocity - prior_angular_velocity) / delta
	else:
		_frame_linear_acceleration = Vector3.ZERO
		_frame_angular_acceleration = Vector3.ZERO
	_has_velocity_sample = true
	_sampled_frame_origin = current.origin


func _is_frame_discontinuity(previous: Transform3D, current: Transform3D) -> bool:
	if teleport_distance_threshold > 0.0 \
		and previous.origin.distance_to(current.origin) > teleport_distance_threshold:
		return true
	if teleport_angle_threshold_degrees <= 0.0:
		return false
	var rotation_delta := (current.basis * previous.basis.inverse()).orthonormalized()
	var angle := absf(_shortest_rotation_angle(rotation_delta.get_rotation_quaternion().get_angle()))
	return rad_to_deg(angle) > teleport_angle_threshold_degrees


func _sync_occupant_frame_samples(frame_transform: Transform3D) -> void:
	for occupant_id: int in _occupants.keys():
		var state: Dictionary = _occupants[occupant_id]
		state["previous_frame_transform"] = frame_transform
		_occupants[occupant_id] = state


func _get_relative_velocity(occupant: Node3D) -> Vector3:
	if occupant is CharacterBody3D:
		var velocity := (occupant as CharacterBody3D).velocity
		return velocity if velocity.is_finite() else Vector3.ZERO
	return Vector3.ZERO


func _prune_invalid_occupants() -> void:
	for occupant_id: int in _occupants.keys():
		var state: Dictionary = _occupants[occupant_id]
		var occupant: Variant = (state["occupant"] as WeakRef).get_ref()
		if not is_instance_valid(occupant):
			_volume_registered_ids.erase(occupant_id)
			_occupants.erase(occupant_id)


func _clear_owner_meta(occupant: Node3D) -> void:
	if not is_instance_valid(occupant) or not occupant.has_meta(OWNER_META):
		return
	var owner_ref: Variant = occupant.get_meta(OWNER_META) if occupant.has_meta(OWNER_META) else null
	if owner_ref is WeakRef and (owner_ref as WeakRef).get_ref() == self:
		occupant.remove_meta(OWNER_META)


func _clear_registration_meta(occupant: Node3D) -> void:
	if not is_instance_valid(occupant) or not occupant.has_meta(REGISTRATION_META):
		return
	var owner_ref: Variant = occupant.get_meta(REGISTRATION_META)
	if owner_ref is WeakRef and (owner_ref as WeakRef).get_ref() == self:
		occupant.remove_meta(REGISTRATION_META)


func _disconnect_frame() -> void:
	if is_instance_valid(_moving_frame) \
		and _moving_frame.tree_exiting.is_connected(_on_moving_frame_tree_exiting):
		_moving_frame.tree_exiting.disconnect(_on_moving_frame_tree_exiting)


func _connect_frame() -> void:
	if is_instance_valid(_moving_frame) \
		and not _moving_frame.tree_exiting.is_connected(_on_moving_frame_tree_exiting):
		_moving_frame.tree_exiting.connect(_on_moving_frame_tree_exiting)


func _connect_volume() -> void:
	if not is_instance_valid(_occupant_volume):
		return
	if not _occupant_volume.body_entered.is_connected(_on_volume_body_entered):
		_occupant_volume.body_entered.connect(_on_volume_body_entered)
	if not _occupant_volume.body_exited.is_connected(_on_volume_body_exited):
		_occupant_volume.body_exited.connect(_on_volume_body_exited)
	if not _occupant_volume.tree_exiting.is_connected(_on_occupant_volume_tree_exiting):
		_occupant_volume.tree_exiting.connect(_on_occupant_volume_tree_exiting)


func _disconnect_volume(
		release_volume_occupants: bool,
		clear_reference: bool = true
	) -> void:
	if not is_instance_valid(_occupant_volume):
		if clear_reference:
			_occupant_volume = null
		return
	if _occupant_volume.body_entered.is_connected(_on_volume_body_entered):
		_occupant_volume.body_entered.disconnect(_on_volume_body_entered)
	if _occupant_volume.body_exited.is_connected(_on_volume_body_exited):
		_occupant_volume.body_exited.disconnect(_on_volume_body_exited)
	if _occupant_volume.tree_exiting.is_connected(_on_occupant_volume_tree_exiting):
		_occupant_volume.tree_exiting.disconnect(_on_occupant_volume_tree_exiting)
	if release_volume_occupants:
		_release_volume_occupants(&"volume_replaced")
	_pending_volume_occupants.clear()
	if clear_reference:
		_occupant_volume = null


func _register_existing_overlaps() -> void:
	if not auto_register_from_volume or not is_instance_valid(_occupant_volume):
		return
	for body: Node3D in _occupant_volume.get_overlapping_bodies():
		_register_volume_occupant(body)


func _on_volume_body_entered(body: Node3D) -> void:
	if auto_register_from_volume:
		_register_volume_occupant(body)


func _on_volume_body_exited(body: Node3D) -> void:
	if is_instance_valid(body):
		_pending_volume_occupants.erase(body.get_instance_id())
	if auto_register_from_volume \
		and is_occupant_registered(body) \
		and _volume_registered_ids.has(body.get_instance_id()):
		unregister_occupant(body, true, &"volume_exited")


func _register_volume_occupant(body: Node3D) -> void:
	var result := register_occupant(body, {"registration_source": &"volume"})
	if not is_instance_valid(body):
		return
	var occupant_id := body.get_instance_id()
	var status: StringName = result["status"]
	if status == &"registered":
		_volume_registered_ids[occupant_id] = true
		_pending_volume_occupants.erase(occupant_id)
	elif status == &"already_registered" and _occupants.has(occupant_id):
		var state: Dictionary = _occupants[occupant_id]
		if StringName(state.get("registration_source", &"manual")) == &"volume":
			_volume_registered_ids[occupant_id] = true
		_pending_volume_occupants.erase(occupant_id)
	elif status == &"owned_by_other_frame" or status == &"outside_bounds":
		# Overlapping volumes only emit body_entered once. Keep a weak retry when a
		# docking threshold is shared by two ships, or when a tall CharacterBody's
		# root has not crossed the stricter local AABB yet. This needs no GameFlow
		# polling and never retains the body.
		_pending_volume_occupants[occupant_id] = weakref(body)
	else:
		_pending_volume_occupants.erase(occupant_id)


func _retry_pending_volume_occupants() -> void:
	if not auto_register_from_volume or not is_instance_valid(_occupant_volume):
		_pending_volume_occupants.clear()
		return
	for occupant_id: int in _pending_volume_occupants.keys():
		var body: Variant = (_pending_volume_occupants[occupant_id] as WeakRef).get_ref()
		if not is_instance_valid(body):
			_pending_volume_occupants.erase(occupant_id)
			continue
		if not _occupant_volume.overlaps_body(body as Node3D):
			_pending_volume_occupants.erase(occupant_id)
			continue
		var owner_ref: Variant = body.get_meta(REGISTRATION_META) \
			if body.has_meta(REGISTRATION_META) else null
		if owner_ref == null and body.has_meta(OWNER_META):
			owner_ref = body.get_meta(OWNER_META)
		if owner_ref is WeakRef:
			var current_owner: Variant = (owner_ref as WeakRef).get_ref()
			if is_instance_valid(current_owner) and current_owner != self:
				continue
		_register_volume_occupant(body as Node3D)


func _release_volume_occupants(reason: StringName) -> void:
	for occupant_id: int in _volume_registered_ids.keys():
		if not _occupants.has(occupant_id):
			_volume_registered_ids.erase(occupant_id)
			continue
		var state: Dictionary = _occupants[occupant_id]
		var occupant: Variant = (state["occupant"] as WeakRef).get_ref()
		if is_instance_valid(occupant):
			unregister_occupant(occupant as Node3D, false, reason)
		else:
			_volume_registered_ids.erase(occupant_id)


func _on_occupant_volume_tree_exiting() -> void:
	_release_volume_occupants(&"volume_tree_exiting")
	_pending_volume_occupants.clear()
	_occupant_volume = null


func _on_occupant_tree_exiting(occupant_id: int) -> void:
	if _tearing_down or not _occupants.has(occupant_id):
		return
	var state: Dictionary = _occupants[occupant_id]
	var occupant: Variant = (state["occupant"] as WeakRef).get_ref()
	if is_instance_valid(occupant):
		unregister_occupant(occupant as Node3D, false, &"occupant_tree_exiting")
	else:
		_volume_registered_ids.erase(occupant_id)
		_pending_volume_occupants.erase(occupant_id)
		_occupants.erase(occupant_id)


func _on_moving_frame_tree_exiting() -> void:
	var was_tearing_down := _tearing_down
	_tearing_down = true
	clear_occupants(false, &"moving_frame_tree_exiting")
	_moving_frame = null
	_has_frame_sample = false
	_tearing_down = was_tearing_down


static func _node_world_transform(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var result := node.transform
	var ancestor := node.get_parent() as Node3D
	while ancestor != null:
		result = ancestor.transform * result
		ancestor = ancestor.get_parent() as Node3D
	return result


static func _set_node_world_transform(node: Node3D, world_transform: Transform3D) -> void:
	if node.is_inside_tree():
		node.global_transform = world_transform
		return
	var parent_3d := node.get_parent() as Node3D
	node.transform = _node_world_transform(parent_3d).affine_inverse() * world_transform \
		if parent_3d != null else world_transform


static func _shortest_rotation_angle(angle: float) -> float:
	return angle - TAU if angle > PI else angle


static func _canonical_aabb(value: AABB) -> AABB:
	var end := value.position + value.size
	var minimum := Vector3(
		minf(value.position.x, end.x),
		minf(value.position.y, end.y),
		minf(value.position.z, end.z)
	)
	var maximum := Vector3(
		maxf(value.position.x, end.x),
		maxf(value.position.y, end.y),
		maxf(value.position.z, end.z)
	)
	return AABB(minimum, maximum - minimum)
