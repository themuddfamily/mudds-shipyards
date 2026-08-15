extends SceneTree

const MODULE_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. A frame count, never a wall-clock grace: the door advances in
## `_physics_process`, and only a frame budget measures the same amount of panel
## motion on a loaded box as on an idle one.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "AftJunctionStackTestRoot"
	root.add_child(_test_root)

	var module := MODULE_SCENE.instantiate() as AftJunctionStack
	_check(module != null, "aft junction scene instantiates as AftJunctionStack")
	if module == null:
		_finish()
		return
	module.position = Vector3(23.0, 1.5, -31.0)
	module.rotation_degrees.y = 27.0
	_test_root.add_child(module)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_evidence_and_audit(module)
	_test_route_and_space_contract(module)
	await _test_collision_backed_surfaces(module)
	await _test_stair_circulation(module)
	await _test_operations_door_and_room(module)
	_test_operations_contents(module)
	_test_vip_landmark(module)
	await _test_negative_space(module)
	_test_collision_matrix(module)
	await _test_cleanup(module)
	_finish()


func _test_identity_evidence_and_audit(module: AftJunctionStack) -> void:
	_check(module.get_module_id() == &"aft-junction-stack", "module exposes a stable kebab-case identity")
	_check(bool(module.get_meta("station_module", false)), "root metadata identifies a station module")
	_check(str(module.get_meta("evidence_status", "")) == "modern_interpretation", "root metadata rejects an authenticated-geometry claim")
	_check(bool(module.get_meta("source_bounded", false)), "root metadata marks the interpretation as source-bounded")
	_check(module.is_in_group("station_modules"), "module participates in station-module discovery")

	var evidence := module.get_evidence_metadata()
	_check(int(evidence.schema_version) == AftJunctionStack.SCHEMA_VERSION, "evidence report has a stable schema")
	_check(str(evidence.evidence_status) == "modern_interpretation", "evidence API labels exact layout as modern interpretation")
	_check((evidence.references as PackedStringArray).size() >= 4, "evidence API exposes source/timestamp references")
	_check("VIP" in str(evidence.content_note) and "no unsupported VIP interior" in str(evidence.content_note), "evidence note limits the VIP claim")
	var returned_references := evidence.references as PackedStringArray
	returned_references.append("mutation")
	_check(not (module.get_evidence_metadata().references as PackedStringArray).has("mutation"), "evidence arrays are detached from module state")

	var audit := module.get_audit_report()
	_check(bool(audit.valid), "fully constructed junction passes its public audit")
	_check((audit.errors as PackedStringArray).is_empty(), "valid audit reports no hidden structural errors")
	_check(int(audit.chair_count) == 4 and int(audit.console_bay_count) == 3, "audit exposes required operations furniture counts")
	_check(float(audit.open_to_space_ratio) >= 0.5, "audit proves a majority-open walkable-area estimate")
	(audit.operations_room as Dictionary)["half_extents"] = Vector3.ZERO
	_check((module.get_audit_report().operations_room as Dictionary).half_extents != Vector3.ZERO, "audit dictionaries are detached from module state")


func _test_route_and_space_contract(module: AftJunctionStack) -> void:
	var expected_routes := PackedStringArray([
		"approach",
		"lower-junction",
		"stair-base",
		"stair-top",
		"operations-room",
		"upper-floor",
		"vip-landmark",
	])
	for route_id in expected_routes:
		_check(module.has_route_marker(StringName(route_id)), "route marker is exposed: %s" % route_id)
		_check(module.get_route_marker(StringName(route_id)) != null, "route marker resolves to a physical Marker3D: %s" % route_id)
	_check(module.get_route_ids().size() == expected_routes.size(), "route registry has no implicit or missing route entries")
	_check(module.get_route_marker(&"missing-route") == null, "unknown route marker has no fallback")

	var floor_elevations := module.get_floor_elevations()
	_check(floor_elevations.size() == 2, "module declares exactly two principal floor elevations")
	_check(is_equal_approx(floor_elevations[0], 0.0), "lower floor uses the integration-anchor elevation")
	_check(is_equal_approx(floor_elevations[1], 4.2), "upper floor exposes a distinct 4.2 metre elevation")
	_check(floor_elevations[1] - floor_elevations[0] > 3.5, "two levels are spatially meaningful rather than decorative offsets")

	var footprint := module.get_integration_footprint()
	var footprint_min: Vector3 = footprint.local_min
	var footprint_max: Vector3 = footprint.local_max
	_check(footprint_min.x < -10.0 and footprint_max.x > 11.0, "integration footprint exposes the asymmetric east-west envelope")
	_check(footprint_min.z < -2.0 and footprint_max.z >= 21.0, "integration footprint includes approach and aft facade")
	_check((footprint.local_size as Vector3).is_finite(), "integration footprint size is finite")
	_check(module.get_module_anchor().global_transform.is_equal_approx(module.global_transform), "module anchor is the exact root connection transform")


func _test_collision_backed_surfaces(module: AftJunctionStack) -> void:
	var lower_hit := await _ray_down(module, Vector3(0, 2.0, 7.2), Vector3(0, -1.0, 7.2))
	_check(not lower_hit.is_empty(), "lower open junction floor is backed by real physics")
	if not lower_hit.is_empty():
		var lower_local := module.to_local(lower_hit.position)
		_check(is_equal_approx(lower_local.y, 0.0), "lower collision surface matches its declared elevation")

	var room_hit := await _ray_down(module, Vector3(5.6, 2.0, 10.7), Vector3(5.6, -1.0, 10.7))
	_check(not room_hit.is_empty(), "operations-room floor is backed by real physics")
	if not room_hit.is_empty():
		_check(absf(module.to_local(room_hit.position).y) < 0.02, "operations floor joins the lower circulation without a hidden step")

	var upper_hit := await _ray_down(module, Vector3(-5.2, 6.0, 16.2), Vector3(-5.2, 3.0, 16.2))
	_check(not upper_hit.is_empty(), "upper open floor is backed by real physics")
	if not upper_hit.is_empty():
		_check(absf(module.to_local(upper_hit.position).y - 4.2) < 0.02, "upper collision surface matches its declared elevation")


func _test_stair_circulation(module: AftJunctionStack) -> void:
	var profile := module.get_stair_profile()
	_check(int(profile.step_count) == 15, "stair exposes fifteen readable treads")
	_check(float(profile.riser_height) <= 0.31, "stair riser interval remains avatar-friendly")
	_check(float(profile.tread_run) >= 0.69, "stair tread run is generous enough for circulation")
	_check(float(profile.clear_width) >= 2.8, "stair preserves a broad player-clear route")
	_check(float(profile.minimum_head_clearance) >= 2.6, "stair publishes more than player-height head clearance")
	_check(str(profile.collision_solution) == "continuous_ramp_beneath_visible_treads", "stair explicitly exposes its snag-resistant physical solution")

	var samples := module.get_stair_surface_samples()
	_check(samples.size() == int(profile.step_count), "stair provides one physical test sample per visible tread")
	var every_step_supported := true
	var every_step_clear := true
	for sample in samples:
		var support_hit := await _ray_local(module, sample + Vector3.UP * 0.55, sample - Vector3.UP * 0.5)
		if support_hit.is_empty():
			every_step_supported = false
		var clearance_hit := await _ray_local(
			module,
			sample + Vector3.UP * 0.24,
			sample + Vector3.UP * float(profile.minimum_head_clearance)
		)
		if not clearance_hit.is_empty():
			every_step_clear = false
	_check(every_step_supported, "every visible stair interval has continuous collision support")
	_check(every_step_clear, "stair centreline preserves the published head clearance at every interval")
	_check(absf(samples[0].y - 0.11) < 0.02, "stair begins at the lower floor without a high first step")
	_check(absf(samples[samples.size() - 1].y - 4.31) < 0.02, "stair terminates flush with the upper landing surface")


func _test_operations_door_and_room(module: AftJunctionStack) -> void:
	var door := module.get_operations_entrance()
	_check(door != null, "cyan operations entrance is exposed as StationDoor")
	if door == null:
		return
	_check(door.can_interact(), "operations entrance begins operable")
	_check("OPERATIONS ACCESS" in door.get_interaction_prompt(), "operations door publishes a diegetic access prompt")
	_check(str(door.get_meta("evidence_status")) == "modern_interpretation", "operations door preserves its own evidence metadata")
	_check(door.is_portal_blocked(), "closed operations entrance is physically blocked")
	var closed_hit := await _ray_through_door(door)
	_check(not closed_hit.is_empty(), "closed operations portal blocks a real physics ray")
	if not closed_hit.is_empty():
		_check(closed_hit.collider == door.get_node("PortalBlocker"), "dedicated StationDoor portal collider owns the closed obstruction")

	_check(door.interact(module), "operations entrance accepts direct component interaction")
	_check(door.get_state() == StationDoor.DoorState.OPENING, "operations entrance uses StationDoor's deterministic opening state")
	var opening_hit := await _ray_through_door(door)
	_check(not opening_hit.is_empty(), "portal remains physically blocked during opening")
	var entrance_opened := await _wait_for_door_state(door, StationDoor.DoorState.OPEN, 1.5)
	_check(entrance_opened, "operations entrance completes its motion inside its physics-frame budget")
	_check(door.is_open(), "operations entrance reaches fully open")
	_check(not door.is_portal_blocked(), "fully open operations entrance clears its blocker")
	var open_hit := await _ray_through_door(door)
	_check(open_hit.is_empty(), "fully open entrance exposes an unobstructed room threshold")

	var room_anchor := module.get_operations_room_marker()
	_check(room_anchor != null and module.contains_operations_room(room_anchor.global_position), "operations anchor lies inside the occupancy volume")
	_check(module.contains_operations_room(module.to_global(Vector3(1.0, 1.0, 10.0))), "entry-side aisle is inside the operations occupancy volume")
	_check(not module.contains_operations_room(module.to_global(Vector3(-2.0, 1.0, 13.2))), "open junction does not masquerade as room occupancy")
	_check(not module.contains_operations_room(module.to_global(Vector3(5.6, 6.0, 13.2))), "space above the operations roof is outside room occupancy")

	var room_volume := module.get_operations_room_volume()
	_check((room_volume.half_extents as Vector3).x >= 5.0, "room volume exposes its broad interior width")
	_check((room_volume.world_transform as Transform3D).origin.is_equal_approx(module.to_global(room_volume.local_center)), "room volume composes through the module transform")


func _test_operations_contents(module: AftJunctionStack) -> void:
	_check(module.get_chair_count() == 4, "operations room contains four physical chairs")
	_check(module.get_console_bay_count() == 3, "operations room contains three physical console bays")
	var chairs := module.find_children("OperationsChair*", "Node3D", true, false)
	var consoles := module.find_children("ConsoleBay*", "Node3D", true, false)
	_check(chairs.size() == 4, "four independently addressable chair roots exist in the scene tree")
	_check(consoles.size() == 3, "three independently addressable console roots exist in the scene tree")
	var furniture_tagged := true
	for chair in chairs:
		furniture_tagged = furniture_tagged and bool(chair.get_meta("station_chair", false))
	for console in consoles:
		furniture_tagged = furniture_tagged and bool(console.get_meta("station_console_bay", false))
	_check(furniture_tagged, "operations furniture exposes stable semantic metadata")
	var service_wall := module.get_service_wall()
	_check(service_wall != null and bool(service_wall.get_meta("station_service_wall", false)), "service wall is present and semantically tagged")


func _test_vip_landmark(module: AftJunctionStack) -> void:
	var vip := module.get_vip_access()
	_check(vip != null, "VIP landmark exposes a StationDoor component")
	if vip == null:
		return
	_check(vip.locked and vip.deferred_access, "VIP landmark is both locked and deferred")
	_check(not vip.can_interact(module), "deferred VIP landmark cannot imply a playable unsupported room")
	_check(not vip.interact(module), "VIP interaction is explicitly refused")
	var prompt := vip.get_interaction_prompt()
	_check("DEFERRED" in prompt and "VIP ACCESS" in prompt, "VIP prompt names the red landmark and its deferred state")
	_check(str(vip.get_meta("access_label")) == "VIP ACCESS", "VIP component metadata exposes its stable label")
	_check(bool(vip.get_meta("deferred_access")), "VIP component metadata preserves deferred status")
	_check("No unsupported VIP room" in str(vip.get_meta("content_note")), "VIP component carries the no-interior evidence boundary")
	_check(module.get_vip_access_marker().global_position.distance_to(vip.global_position + Vector3.UP * 0.15) < 1.3, "VIP route marker terminates at the deferred landmark")

	var panel := vip.get_node_or_null("SlidingPanel/PanelMesh") as MeshInstance3D
	var panel_material := panel.material_override as StandardMaterial3D if panel != null else null
	_check(panel_material != null and panel_material.albedo_color.r > panel_material.albedo_color.g * 1.7, "VIP panel is visibly red rather than reusing cyan access styling")


func _test_negative_space(module: AftJunctionStack) -> void:
	var west_void := await _ray_local(module, Vector3(-9.0, 8.0, 6.0), Vector3(-9.0, -4.0, 6.0))
	var east_void := await _ray_local(module, Vector3(8.5, 8.0, 5.8), Vector3(8.5, -4.0, 5.8))
	_check(west_void.is_empty(), "west footprint sample remains true station negative space")
	_check(east_void.is_empty(), "east footprint sample remains true station negative space")

	var lower_sky := await _ray_local(module, Vector3(0, 0.3, 7.2), Vector3(0, 12.0, 7.2))
	var upper_sky := await _ray_local(module, Vector3(-7.8, 4.5, 16.0), Vector3(-7.8, 13.0, 16.0))
	_check(lower_sky.is_empty(), "lower junction remains uncovered and open to space")
	_check(upper_sky.is_empty(), "upper overlook remains uncovered and open to space")

	var room_roof := await _ray_local(module, Vector3(5.6, 1.0, 13.2), Vector3(5.6, 8.0, 13.2))
	_check(not room_roof.is_empty(), "compact operations insertion has a physical roof distinct from open decks")
	_check(module.get_open_to_space_ratio() > 0.67, "declared walkable-area estimate keeps more than two thirds open to space")


func _test_collision_matrix(module: AftJunctionStack) -> void:
	var bodies := module.find_children("*", "StaticBody3D", true, false)
	_check(bodies.size() >= 30, "module contains substantial collision-backed architecture and furniture")
	var every_body_canonical := true
	var every_body_shaped := true
	for candidate in bodies:
		var body := candidate as StaticBody3D
		var layer_is_valid := body.collision_layer == WORLD_LAYER
		if body.name == "PortalBlocker":
			# The reusable StationDoor deliberately clears only its portal blocker's
			# layer while fully open; all other static structure stays on World.
			layer_is_valid = body.collision_layer == WORLD_LAYER or body.collision_layer == 0
		every_body_canonical = every_body_canonical and layer_is_valid and body.collision_mask == 0
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			every_body_shaped = false
	_check(every_body_canonical, "every static collider follows the canonical World layer/mask contract")
	_check(every_body_shaped, "every static body owns at least one real collision shape")


func _test_cleanup(module: AftJunctionStack) -> void:
	var module_reference: WeakRef = weakref(module)
	var operations_reference: WeakRef = weakref(module.get_operations_entrance())
	var vip_reference: WeakRef = weakref(module.get_vip_access())
	module.queue_free()
	module = null
	await process_frame
	await physics_frame
	await process_frame
	_check(module_reference.get_ref() == null, "module root cleans up without a retained instance")
	_check(operations_reference.get_ref() == null and vip_reference.get_ref() == null, "both StationDoor children clean up with the module")
	_test_root.queue_free()
	await process_frame


func _ray_down(module: AftJunctionStack, local_from: Vector3, local_to: Vector3) -> Dictionary:
	return await _ray_local(module, local_from, local_to)


func _ray_local(module: AftJunctionStack, local_from: Vector3, local_to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(module.to_global(local_from), module.to_global(local_to), WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _ray_through_door(door: StationDoor) -> Dictionary:
	await physics_frame
	var from := door.to_global(Vector3(0, 1.7, -1.7))
	var to := door.to_global(Vector3(0, 1.7, 1.7))
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return door.get_world_3d().direct_space_state.intersect_ray(query)


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus a fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for a door to reach `expected_state` on the physics clock, which is the
## clock `StationDoor` actually advances its panel on.
##
## The budget deliberately counts physics steps rather than wall-clock seconds. A
## `Time.get_ticks_msec()` deadline measures the monotonic clock, and under load
## Godot drops physics steps rather than letting the simulation spiral, so the
## wall clock reaches the deadline while the panel has been stepped only part of
## the way. The wait then returned silently and the caller asserted on a door
## caught mid-travel — a false failure, not a defect. Counting frames gives the
## door the same amount of simulation however busy the box is, and still fails a
## genuinely stuck door because the budget remains finite.
##
## Returns whether the state was actually reached so callers can assert on it
## rather than assume it.
func _wait_for_door_state(door: StationDoor, expected_state: int, travel_seconds: float) -> bool:
	var frame_budget := _frame_budget(travel_seconds)
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
		print("AFT_JUNCTION_STACK_TEST_OK")
		quit(0)
	else:
		print("AFT_JUNCTION_STACK_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
