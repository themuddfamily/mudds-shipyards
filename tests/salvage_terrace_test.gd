extends SceneTree

## Focused contract, mutation, and embodied traversal proof for Salvage Terrace.

const MODULE_SCENE := preload("res://scenes/world/modules/salvage_terrace.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WORLD_LAYER := 1

var _failures: Array[String] = []
var _assertions := 0
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "SalvageTerraceTestRoot"
	root.add_child(_test_root)
	var module := MODULE_SCENE.instantiate() as SalvageTerrace
	_test_root.add_child(module)
	await process_frame
	await physics_frame

	_check(module != null, "standalone Salvage Terrace scene instantiates")
	if module == null:
		_finish()
		return

	_test_evidence_and_shared_contract(module)
	_test_origin_slot_and_routes(module)
	await _test_exact_surface_union(module)
	_test_rails_dressing_and_authority(module)
	_test_performance_and_lifecycle(module)
	await _test_real_player_ramp_traversal(module)
	await _test_mutations_turn_audit_red(module)
	await _test_cleanup(module)
	_finish()


func _test_evidence_and_shared_contract(module: SalvageTerrace) -> void:
	var audit := module.get_audit_report()
	var evidence := module.get_evidence_metadata()
	_check(bool(audit.valid), "fresh standalone module passes its complete audit")
	_check(module.get_module_id() == &"salvage-terrace", "module publishes its stable integration id")
	_check(
		evidence.element_status == &"new"
		and evidence.evidence_status == &"modern_interpretation"
		and evidence.source_confidence == &"none",
		"entire module is explicitly NEW modern interpretation at confidence none"
	)
	_check(
		not bool(evidence.authenticated_original_geometry)
		and not bool(evidence.authenticated_original_function)
		and (evidence.references as PackedStringArray).is_empty()
		and (evidence.claim_ids as PackedStringArray).is_empty(),
		"module makes no recovered geometry, function, reference, or claim-id assertion"
	)
	var shared := StationModuleContract.new().validate_contract(module)
	_check(bool(shared.valid), "module satisfies the reusable StationModuleContract surface")
	_check(
		bool(module.get_meta("station_module", false))
		and module.get_meta("element_status") == &"new"
		and module.get_meta("evidence_status") == &"modern_interpretation",
		"discovery metadata preserves the NEW evidence boundary"
	)


func _test_origin_slot_and_routes(module: SalvageTerrace) -> void:
	var expected_routes: Array[StringName] = [
		&"connector", &"entry", &"lower-pad", &"main-ramp-base", &"upper-pad",
		&"inspection-ramp-base", &"inspection-pad",
	]
	_check(module.get_route_ids() == expected_routes, "route API publishes the exact ordered seven-node local path")
	for route_id in expected_routes:
		_check(
			module.has_route_marker(route_id)
			and module.get_route_marker(route_id) != null
			and module.get_route_transform(route_id).is_equal_approx(
				module.get_route_marker(route_id).global_transform
			),
			"route marker resolves exactly: %s" % route_id
		)
	_check(not module.has_route_marker(&"invented"), "unknown route has no invented fallback")
	var slot := StationModuleContract.new().capture_connection_slot(module, &"connector")
	var slots: Array = module.get_connection_slot_contract()
	_check(
		slots.size() == 1
		and slot.slot_id == &"hub-salvage-terrace"
		and slot.route_id == &"connector"
		and module.get_module_anchor().transform.is_equal_approx(Transform3D.IDENTITY)
		and module.get_route_marker(&"connector").position.is_equal_approx(Vector3(0, 0.15, 0)),
		"one named connection slot sits exactly on the clear local-origin plane"
	)
	var footprint := module.get_integration_footprint()
	_check(
		bool(footprint.connection_at_local_origin)
		and footprint.connection_plane_local == Transform3D.IDENTITY
		and footprint.approach_axis_local == Vector3.FORWARD
		and (footprint.local_size as Vector3).is_equal_approx(Vector3(45.4, 8.9, 18.2)),
		"integration footprint and local-origin approach convention are finite and exact"
	)


func _test_exact_surface_union(module: SalvageTerrace) -> void:
	var surfaces := module.get_standable_surface_contract()
	var expected_ids := PackedStringArray([
		"connection-apron", "lower-salvage-pad", "main-service-ramp",
		"upper-inspection-pad", "inspection-ramp", "top-inspection-pad",
	])
	var live_ids := PackedStringArray()
	var projected_sum := 0.0
	var true_sum := 0.0
	var unique_bodies := {}
	var all_supported := true
	for surface in surfaces:
		var surface_id := StringName(surface.surface_id)
		live_ids.append(str(surface_id))
		projected_sum += float(surface.horizontal_area_m2)
		true_sum += float(surface.true_area_m2)
		var body := module.get_node(surface.body_path as NodePath) as StaticBody3D
		if body != null:
			unique_bodies[body.get_instance_id()] = true
		all_supported = all_supported and body != null
		all_supported = all_supported and bool(body.get_meta("walkable_surface", false))
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_id", &"")) == surface_id
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_kind", &"")) == surface.kind
		all_supported = all_supported and StringName(body.get_meta("walkable_surface_owner", &"")) == &"salvage-terrace"
		if body != null:
			var center := body.global_position
			var hit := await _ray(module, center + Vector3.UP * 4.0, center + Vector3.DOWN * 4.0)
			all_supported = all_supported and hit.get("collider") == body
	live_ids.sort()
	expected_ids.sort()
	_check(
		surfaces.size() == 6 and unique_bodies.size() == 6 and live_ids == expected_ids,
		"every standable surface has one unique stable id and collision body"
	)
	_check(all_supported, "all six authoritative usable bodies carry exact census tags and real World support")
	var area := module.get_walkable_area_contract()
	print("SALVAGE_TERRACE_AREA: ", area)
	_check(
		area.surface_union == &"non_overlapping_shared_boundaries_only"
		and is_equal_approx(float(area.level_area_m2), 384.0)
		and is_equal_approx(float(area.ramp_projected_area_m2), 72.0)
		and is_equal_approx(float(area.horizontal_walkable_area_m2), 456.0)
		and is_equal_approx(projected_sum, 456.0),
		"non-overlapping horizontal union is exactly 456.0 square metres"
	)
	_check(
		is_equal_approx(float(area.main_ramp_true_area_m2), 52.636109)
		and is_equal_approx(float(area.inspection_ramp_true_area_m2), 26.318054)
		and is_equal_approx(float(area.ramp_true_area_m2), 78.954163)
		and is_equal_approx(true_sum, 462.954163)
		and not bool(area.baseline_share_claimed),
		"true ramp areas are explicit and no unsupported station-baseline percentage is claimed"
	)
	var roster := module.get_component_roster()
	_check(
		int(roster.usable_pad_count) == 3
		and (roster.usable_pad_ids as PackedStringArray) == PackedStringArray([
			"lower-salvage-pad", "upper-inspection-pad", "top-inspection-pad",
		])
		and int(roster.ramp_count) == 2,
		"three spatially distinct usable pads are joined by two declared broad ramps"
	)
	var by_surface := area.by_surface as Dictionary
	_check(
		float((by_surface[&"main-service-ramp"] as Dictionary).horizontal_area_m2) == 48.0
		and float((by_surface[&"inspection-ramp"] as Dictionary).horizontal_area_m2) == 24.0,
		"both broad ramps publish exact projected contribution rather than hidden stair area"
	)


func _test_rails_dressing_and_authority(module: SalvageTerrace) -> void:
	var roster := module.get_component_roster()
	var collision := module.get_collision_contract()
	_check(
		int(roster.safety_rail_count) == 20
		and int(collision.safety_rail_count) == 20
		and bool(collision.all_layers_match_lifecycle)
		and bool(collision.all_masks_zero),
		"twenty continuous physical rail segments guard exposed terrace and ramp edges"
	)
	var rail_shapes_valid := true
	for raw_rail in module.find_children("*", "StaticBody3D", true, false):
		var rail := raw_rail as StaticBody3D
		if bool(rail.get_meta("safety_rail", false)):
			rail_shapes_valid = rail_shapes_valid and rail.find_children("*", "CollisionShape3D", true, false).size() == 1
	_check(rail_shapes_valid, "every safety rail is a real one-shape World barrier, not presentation trim")
	_check(
		int(roster.multimesh_batch_count) == 3
		and module.find_children("*", "MultiMeshInstance3D", true, false).size() == 3,
		"repeated supports, salvage cages, and emissive markers use three bounded batches"
	)
	var reasons_complete := true
	for visual in module.find_children("*", "MeshInstance3D", true, false):
		var mesh := visual as MeshInstance3D
		if mesh.get_parent() == module.get_node(^"GeneratedRoot"):
			reasons_complete = reasons_complete and not str(mesh.get_meta("non_walkable_reason", "")).is_empty()
	_check(reasons_complete, "every collision-free dressing mesh states why it is non-walkable")
	var authority := module.get_authority_contract()
	_check(
		int(authority.ship_berth_count) == 0
		and int(authority.landing_or_interaction_area_count) == 0
		and int(authority.audio_node_count) == 0
		and int(authority.activity_node_count) == 0
		and int(authority.ship_authority_count) == 0
		and int(authority.berth_authority_count) == 0
		and int(authority.combat_authority_count) == 0
		and int(authority.interaction_authority_count) == 0
		and int(authority.station_activity_authority_count) == 0,
		"module owns zero ship, berth, combat, interaction, audio, and station-activity authority"
	)


func _test_performance_and_lifecycle(module: SalvageTerrace) -> void:
	var performance := module.get_performance_contract()
	print("SALVAGE_TERRACE_PERFORMANCE: ", performance)
	_check(bool(performance.within_budget), "module remains inside every published performance ceiling")
	_check(
		int(performance.lights) == 0
		and int(performance.labels) == 1
		and int(performance.multimesh_batches) == 3
		and int(performance.multimesh_instances) == 20
		and int(performance.process_loops) == 0
		and int(performance.physics_process_loops) == 0,
		"module uses zero lights/loops, one bounded identity label, and twenty batched copies"
	)
	var before := module.get_lifecycle_contract()
	module.set_module_enabled(false)
	var disabled := module.get_lifecycle_contract()
	_check(
		not module.is_module_enabled()
		and bool(disabled.reversible)
		and bool(disabled.visible_matches_enabled)
		and bool(disabled.collision_matches_enabled)
		and not module.get_node(^"GeneratedRoot").visible,
		"disable hides presentation and clears collision without rebuilding"
	)
	module.set_module_enabled(true)
	var restored := module.get_lifecycle_contract()
	_check(
		module.is_module_enabled()
		and restored.surface_instance_ids == before.surface_instance_ids
		and int(restored.build_generation) == 1
		and bool(module.get_audit_report().valid),
		"re-enable restores identical nodes, World collision, and a green audit"
	)


func _test_real_player_ramp_traversal(module: SalvageTerrace) -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	await process_frame
	player.set_camera_active(false)
	player.set_control_enabled(true)
	_release_actions()
	var start_basis := Basis.looking_at(module.global_basis * Vector3.RIGHT, Vector3.UP)
	player.teleport_to(Transform3D(start_basis, module.to_global(Vector3(5.0, 0.08, 5.0))))
	for _settle in 8:
		await physics_frame
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var main_reached := await _wait_until(
		func() -> bool:
			var local := module.to_local(player.global_position)
			return local.x >= 15.0 and local.y >= 3.45,
		150
	)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	var after_main := module.to_local(player.global_position)
	_check(
		main_reached and after_main.x >= 15.0 and after_main.y >= 3.45 and player.is_on_floor(),
		"real production player climbs the 6 m-wide main ramp without jump input"
	)

	# Re-orient in place on the upper pad, then cross and climb the second ramp.
	# No position teleport occurs between ramps: the same body completes the route.
	player.global_basis = Basis.looking_at(module.global_basis * Vector3.RIGHT, Vector3.UP)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var crossed_upper := await _wait_until(
		func() -> bool: return module.to_local(player.global_position).x >= 22.8,
		120
	)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	await physics_frame
	player.global_basis = Basis.looking_at(module.global_basis * Vector3.BACK, Vector3.UP)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	var inspection_reached := await _wait_until(
		func() -> bool:
			var local := module.to_local(player.global_position)
			return local.z >= 14.5 and local.y >= 5.2,
		140
	)
	_release_actions()
	await physics_frame
	var final_local := module.to_local(player.global_position)
	print("SALVAGE_TERRACE_PLAYER_TRAVERSAL: ", {
		"main_reached": main_reached,
		"crossed_upper": crossed_upper,
		"inspection_reached": inspection_reached,
		"final_local": final_local,
	})
	_check(
		crossed_upper and inspection_reached
		and final_local.z >= 14.5 and final_local.y >= 5.2 and player.is_on_floor(),
		"same player crosses the upper pad and climbs the second broad ramp without jumping"
	)
	player.queue_free()
	await process_frame
	await physics_frame


func _test_mutations_turn_audit_red(module: SalvageTerrace) -> void:
	var connector := module.get_route_marker(&"connector")
	var original_slot: Variant = connector.get_meta(StationModuleContract.CONNECTION_SLOT_META)
	connector.remove_meta(StationModuleContract.CONNECTION_SLOT_META)
	_check(_errors_include(module.get_validation_errors(), "connector slot"), "MUTATION: removing the origin slot turns the audit red")
	connector.set_meta(StationModuleContract.CONNECTION_SLOT_META, original_slot)
	_check(bool(module.get_audit_report().valid), "restoring the exact slot returns the audit to green")

	var surface_contract := module.get_standable_surface_contract()[0]
	var surface := module.get_node(surface_contract.body_path as NodePath) as StaticBody3D
	var surface_mesh := (surface.get_node(^"Mesh") as MeshInstance3D).mesh as BoxMesh
	var original_size := surface_mesh.size
	surface_mesh.size.x += 0.5
	_check(_errors_include(module.get_validation_errors(), "surface geometry diverged"), "MUTATION: widening visible walkable geometry turns the audit red")
	surface_mesh.size = original_size
	_check(bool(module.get_audit_report().valid), "restoring surface geometry returns the audit to green")

	var collision := surface.get_node(^"Collision") as CollisionShape3D
	collision.disabled = true
	await physics_frame
	_check(_errors_include(module.get_validation_errors(), "static collision"), "MUTATION: disabling one walkable collider turns the audit red")
	collision.disabled = false
	await physics_frame
	_check(bool(module.get_audit_report().valid), "restoring walkable collision returns the audit to green")

	var rail: StaticBody3D = null
	for raw_body in module.find_children("*", "StaticBody3D", true, false):
		if bool(raw_body.get_meta("safety_rail", false)):
			rail = raw_body as StaticBody3D
			break
	if rail != null:
		rail.collision_layer = 0
		_check(_errors_include(module.get_validation_errors(), "safety rails"), "MUTATION: making one exposed edge rail nonphysical turns the audit red")
		rail.collision_layer = WORLD_LAYER
		_check(bool(module.get_audit_report().valid), "restoring rail collision returns the audit to green")

	var intruder := Area3D.new()
	intruder.name = "InventedAuthority"
	module.get_node(^"GeneratedRoot").add_child(intruder)
	await process_frame
	_check(_errors_include(module.get_validation_errors(), "zero ship, berth, combat"), "MUTATION: adding interaction authority turns the audit red")
	intruder.queue_free()
	await process_frame
	_check(bool(module.get_audit_report().valid), "removing foreign authority returns the audit to green")

	var detached := module.get_audit_report()
	(detached.walkable_area as Dictionary).clear()
	_check(not module.get_walkable_area_contract().is_empty(), "public audit dictionaries are detached from live module state")


func _test_cleanup(module: SalvageTerrace) -> void:
	var module_ref: WeakRef = weakref(module)
	module.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_check(module_ref.get_ref() == null, "standalone module releases without retained runtime state")
	_test_root.queue_free()
	await process_frame


func _ray(module: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return module.get_world_3d().direct_space_state.intersect_ray(query)


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame in maximum_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _release_actions() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump"]:
		Input.action_release(action)


func _errors_include(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	_release_actions()
	if _failures.is_empty():
		print("SALVAGE_TERRACE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SALVAGE_TERRACE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
