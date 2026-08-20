extends SceneTree

const DOOR_SCENE := preload("res://scenes/world/components/station_door.tscn")
const WORLD_LAYER := 1
const INTERACTION_LAYER := 1 << 3

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_for_state].
const FRAME_BUDGET_GRACE := 30

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
	await _test_deferred_panel_binding_currentness()

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
	_test_root.remove_child(door)
	await process_frame
	_check(not door.is_inside_tree(), "door detaches before direct interaction admission is sampled")
	_check(
		door.get_interaction_prompt().is_empty()
		and not door.can_interact(actor)
		and not door.interact(actor)
		and door.get_state() == StationDoor.DoorState.CLOSED
		and state_events.is_empty()
		and accepted_requests.is_empty(),
		"detached door rejects direct interaction without mutating state or publishing acceptance"
	)
	_test_root.add_child(door)
	await process_frame
	await physics_frame
	_check(
		door.is_inside_tree()
		and door.can_interact(actor)
		and "OPEN OPERATIONS ACCESS" in door.get_interaction_prompt(),
		"re-added door restores its live direct-interaction contract"
	)

	_check(door.interact(actor), "real interaction starts opening")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "interaction enters OPENING immediately")
	_check(accepted_requests == [true], "opening emits an accepted request with its destination")
	_check(door.is_portal_blocked(), "portal stays blocked for the entire opening state")
	var opening_hit := await _ray_through_portal(door)
	_check(not opening_hit.is_empty(), "real ray remains blocked while opening")

	var opened := await _wait_for_state(door, StationDoor.DoorState.OPEN, 1.0)
	_check(opened, "opening completes inside its bounded simulated-frame budget")
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
	var reversal_opened := await _wait_for_state(door, StationDoor.DoorState.OPEN, 1.0)
	_check(reversal_opened, "reversed motion completes inside its bounded simulated-frame budget")
	_check(door.get_state() == StationDoor.DoorState.OPEN, "reversed motion completes open")
	_check(completed_states == [StationDoor.DoorState.OPEN, StationDoor.DoorState.OPEN], "each completed opening emits exactly once")

	# Close fully before access-policy tests.
	_check(door.interact(actor), "door can close after reversal")
	var closed := await _wait_for_state(door, StationDoor.DoorState.CLOSED, 1.0)
	_check(closed, "closing completes inside its bounded simulated-frame budget")
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


func _test_deferred_panel_binding_currentness() -> void:
	var deferred_door := DOOR_SCENE.instantiate() as StationDoor
	_test_root.add_child(deferred_door)
	var panel := deferred_door.get_node(^"SlidingPanel/PanelMesh") as MeshInstance3D
	var original_material := panel.material_override
	var original_transform := (deferred_door.get_node(^"SlidingPanel") as Node3D).transform
	_test_root.remove_child(deferred_door)
	await process_frame
	_check(
		not deferred_door.is_inside_tree()
		and panel.material_override == original_material
		and (deferred_door.get_node(^"SlidingPanel") as Node3D).transform.is_equal_approx(original_transform),
		"detached deferred panel binding leaves the retained door material and grain transform unchanged"
	)
	_test_root.add_child(deferred_door)
	await process_frame
	var rebound_material := panel.material_override
	await process_frame
	_check(
		deferred_door.is_inside_tree()
		and rebound_material != null
		and rebound_material != original_material
		and panel.material_override == rebound_material,
		"re-entry applies one current panel-family binding without duplicate deferred material mutation"
	)
	deferred_door.queue_free()
	await process_frame
	var queued_door := DOOR_SCENE.instantiate() as StationDoor
	_test_root.add_child(queued_door)
	var queued_panel := queued_door.get_node(^"SlidingPanel/PanelMesh") as MeshInstance3D
	var queued_material := queued_panel.material_override
	queued_door.queue_free()
	queued_door.call("_bind_panel_surface_family")
	_check(
		queued_door.is_inside_tree()
		and queued_door.is_queued_for_deletion()
		and queued_panel.material_override == queued_material,
		"queued-but-live door rejects deferred panel binding before material mutation"
	)
	await process_frame


func _ray_through_portal(door: StationDoor) -> Dictionary:
	await physics_frame
	var from := door.to_global(Vector3(0.0, 1.7, -2.2))
	var to := door.to_global(Vector3(0.0, 1.7, 2.2))
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on.
##
## `travel_seconds` is a nominal amount of *simulated* travel and is budgeted in
## physics frames, not wall-clock seconds. A `Time.get_ticks_msec()` deadline
## measures the monotonic clock, and under load Godot drops physics steps rather
## than letting the simulation spiral, so the wall clock reached the deadline
## while the panel had been stepped only part of the way. The wait then returned
## silently and the assertion on the next line probed a door that was still
## mid-travel — a false failure, not a defect. Counting frames gives the panel
## the same amount of simulation however busy the box is, and still fails a
## genuinely stuck door because the budget remains finite.
##
## Returns whether the state was actually reached so callers can assert on it
## rather than assume it.
func _wait_for_state(door: StationDoor, expected_state: int, travel_seconds: float) -> bool:
	var required := int(ceil(maxf(travel_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	var frame_budget := maxi(required, 1) + FRAME_BUDGET_GRACE
	var frames := 0
	while is_instance_valid(door) and door.get_state() != expected_state:
		if frames >= frame_budget:
			break
		await physics_frame
		frames += 1
	await process_frame
	return is_instance_valid(door) and door.get_state() == expected_state


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
