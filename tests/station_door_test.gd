extends SceneTree

const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")
const WORLD_LAYER := 1
const INTERACTION_LAYER := 1 << 3

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "StationDoorTestRoot"
	root.add_child(_test_root)

	var door := DOOR_SCENE.instantiate() as StationDoor
	_check(door != null, "station door scene instantiates as StationDoor")
	if door == null:
		_finish()
		return
	door.motion_duration = 0.24
	door.interaction_label = "OPERATIONS ACCESS"
	_test_root.add_child(door)
	await process_frame
	await physics_frame

	_check(door.collision_layer == INTERACTION_LAYER, "interaction Area3D uses layer 8")
	_check(door.collision_mask == 0, "interaction Area3D has no collision mask")
	_check(not door.monitoring and door.monitorable, "interaction area is passive and externally detectable")
	_check(door.get_state() == StationDoor.DoorState.CLOSED, "door starts deterministically closed")
	_check(door.get_state_name() == &"CLOSED", "closed state has a stable public name")
	_check(door.can_interact(), "unlocked door accepts interaction")
	_check("OPEN OPERATIONS ACCESS" in door.get_interaction_prompt(), "closed prompt requests opening")
	_check(door.is_portal_blocked(), "closed state reports a blocked portal")
	var closed_hit := await _ray_through_portal(door)
	_check(not closed_hit.is_empty(), "real physics ray is blocked while closed")
	_check(
		closed_hit.get("collider") == door.get_node("PortalBlocker"),
		"closed ray is blocked by the dedicated physical portal collider"
	)

	var actor := Node3D.new()
	actor.name = "TestActor"
	_test_root.add_child(actor)
	var state_events: Array = []
	var completed_states: Array[int] = []
	var accepted_requests: Array[bool] = []
	var refusal_reasons: Array[StringName] = []
	door.state_changed.connect(func(previous: int, current: int) -> void:
		state_events.append([previous, current])
	)
	door.motion_completed.connect(func(state: int) -> void:
		completed_states.append(state)
	)
	door.interaction_accepted.connect(func(_actor: Node, requested_open: bool) -> void:
		accepted_requests.append(requested_open)
	)
	door.interaction_refused.connect(func(_actor: Node, reason: StringName) -> void:
		refusal_reasons.append(reason)
	)

	_check(door.interact(actor), "real interaction starts opening")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "interaction enters OPENING immediately")
	_check(accepted_requests == [true], "opening emits an accepted request with its destination")
	_check(door.is_portal_blocked(), "portal stays blocked for the entire opening state")
	var opening_hit := await _ray_through_portal(door)
	_check(not opening_hit.is_empty(), "real ray remains blocked while opening")

	await _wait_for_state(door, StationDoor.DoorState.OPEN, 1.0)
	_check(door.get_state() == StationDoor.DoorState.OPEN, "opening completes in OPEN")
	_check(door.get_state_name() == &"OPEN", "open state has a stable public name")
	_check(not door.is_portal_blocked(), "portal clears only in OPEN")
	var open_hit := await _ray_through_portal(door)
	_check(open_hit.is_empty(), "real physics ray clears the fully open portal")
	_check("CLOSE OPERATIONS ACCESS" in door.get_interaction_prompt(), "open prompt requests closing")
	_check(completed_states == [StationDoor.DoorState.OPEN], "opening emits one completion signal")

	# Begin closing, record the partial panel position, then reverse it. The panel
	# must not snap to an endpoint and the fixed blocker must remain active.
	_check(door.interact(actor), "open-door interaction starts closing")
	_check(door.get_state() == StationDoor.DoorState.CLOSING, "interaction enters CLOSING immediately")
	_check(door.is_portal_blocked(), "closing blocks the portal immediately")
	await physics_frame
	await physics_frame
	await physics_frame
	var partial_panel := door.get_node("SlidingPanel") as Node3D
	var before_reversal := partial_panel.position
	_check(before_reversal.x > 0.05 and before_reversal.x < door.open_offset.x - 0.05, "closing reaches an observable partial transform")
	_check(door.interact(actor), "interaction reverses a closing door")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "closing reverses directly to OPENING")
	_check(partial_panel.position.is_equal_approx(before_reversal), "reversal preserves the exact panel transform")
	_check(door.is_portal_blocked(), "reversed opening remains blocked until fully open")
	await physics_frame
	_check(partial_panel.position.x > before_reversal.x, "reversed panel continues toward open without restarting")
	await _wait_for_state(door, StationDoor.DoorState.OPEN, 1.0)
	_check(door.get_state() == StationDoor.DoorState.OPEN, "reversed motion completes open")
	_check(completed_states == [StationDoor.DoorState.OPEN, StationDoor.DoorState.OPEN], "each completed opening emits exactly once")

	# Close fully before access-policy tests.
	_check(door.interact(actor), "door can close after reversal")
	await _wait_for_state(door, StationDoor.DoorState.CLOSED, 1.0)
	_check(door.get_state() == StationDoor.DoorState.CLOSED, "closing completes in CLOSED")
	_check(door.is_portal_blocked(), "fully closed portal remains blocked")
	_check(completed_states.back() == StationDoor.DoorState.CLOSED, "closing emits its completion state")

	var lock_events: Array[bool] = []
	door.lock_changed.connect(func(value: bool) -> void:
		lock_events.append(value)
	)
	door.set_locked(true)
	_check(not door.can_interact(actor), "locked door refuses interaction eligibility")
	_check("LOCKED" in door.get_interaction_prompt(), "locked prompt is explicit")
	_check(not door.interact(actor), "locked interaction returns false")
	_check(door.get_state() == StationDoor.DoorState.CLOSED, "lock refusal does not change physical state")
	_check(refusal_reasons.back() == &"locked", "lock refusal emits a stable reason")
	_check(lock_events == [true], "lock transition emits exactly once")
	_check(bool(door.get_meta("locked")), "lock state is mirrored into component metadata")

	door.set_locked(false)
	door.interaction_label = "CREW SERVICES"
	door.deferred_label = "VIP ACCESS"
	door.set_deferred_access(true)
	_check(not door.can_interact(actor), "deferred VIP access refuses interaction eligibility")
	var deferred_text := door.get_interaction_prompt()
	_check("DEFERRED" in deferred_text and "VIP ACCESS" in deferred_text, "deferred VIP labeling is explicit")
	_check(not door.interact(actor), "deferred access interaction returns false")
	_check(refusal_reasons.back() == &"deferred", "deferred refusal emits a stable reason")
	_check(bool(door.get_meta("deferred_access")), "deferred status is mirrored into metadata")
	_check(str(door.get_meta("access_label")) == "VIP ACCESS", "metadata exposes the effective deferred label")
	_check(str(door.get_meta("evidence_status")) == "modern_interpretation", "component exposes evidence-status metadata")

	_check(
		state_events.has([StationDoor.DoorState.CLOSED, StationDoor.DoorState.OPENING])
		and state_events.has([StationDoor.DoorState.OPENING, StationDoor.DoorState.OPEN])
		and state_events.has([StationDoor.DoorState.OPEN, StationDoor.DoorState.CLOSING])
		and state_events.has([StationDoor.DoorState.CLOSING, StationDoor.DoorState.OPENING]),
		"state signal history includes open, close, completion, and interrupted reversal transitions"
	)

	var door_reference: WeakRef = weakref(door)
	door.queue_free()
	door = null
	actor.queue_free()
	await process_frame
	await process_frame
	_check(door_reference.get_ref() == null, "door and its physics children clean up without a retained instance")

	_test_root.queue_free()
	await process_frame
	_finish()


func _ray_through_portal(door: StationDoor) -> Dictionary:
	await physics_frame
	var from := door.to_global(Vector3(0.0, 1.7, -2.2))
	var to := door.to_global(Vector3(0.0, 1.7, 2.2))
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


func _wait_for_state(door: StationDoor, expected_state: int, timeout_seconds: float) -> void:
	var started_at := Time.get_ticks_msec()
	while is_instance_valid(door) and door.get_state() != expected_state:
		if float(Time.get_ticks_msec() - started_at) / 1000.0 > timeout_seconds:
			return
		await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DOOR_TEST_OK")
		quit(0)
	else:
		print("STATION_DOOR_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
