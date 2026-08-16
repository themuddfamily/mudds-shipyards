extends SceneTree

const ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	root.add_child(activity)
	await process_frame

	_check(activity != null, "typed station operations scene instantiates")
	if activity == null:
		_finish()
		return
	_check(
		activity.is_in_group(&"station_operations_activity")
		and get_nodes_in_group(&"station_operations_activity").has(activity),
		"component owns its stable station-operations discovery group membership"
	)
	var audit := activity.get_audit_report()
	_check(bool(audit.valid), "component passes its structural, lifecycle, and budget audit")
	_check(audit.evidence_status == &"modern_interpretation", "unsupported operations design is explicitly modern interpretation")
	_check(not bool((audit.evidence as Dictionary).authenticated_original_geometry), "audit makes no recovered-original geometry claim")
	_check((audit.equipment as Dictionary).service_drone_count == 2, "two visible service drones provide ambient activity")
	_check((audit.equipment as Dictionary).safety_beacon_count == 4, "four warning beacons define the service envelope")

	var integration := activity.get_integration_contract()
	_check(integration.mount_type == &"level_deck", "integration contract declares a reusable deck mount")
	_check(integration.service_facing_axis_local == Vector3.FORWARD, "local negative Z is the stable service-facing convention")
	_check(integration.collision_policy == &"presentation_only_nonblocking", "component explicitly promises nonblocking presentation")
	_check((integration.local_size as Vector3).is_equal_approx(Vector3(11.3, 7.25, 9.0)), "integration footprint is complete and finite")
	_check(_meshes_stay_inside_declared_envelope(activity), "FULL profile render and motion remain inside its published envelope")

	var performance := activity.get_performance_audit()
	var counts := performance.counts as Dictionary
	print("STATION_OPERATIONS_PERFORMANCE: ", performance)
	_check(bool(performance.within_budget), "runtime node and material counts remain within the published budget")
	_check(int(counts.collision_nodes) == 0, "component contains no body, area, shape, or collision polygon")
	_check(int(counts.lights) == 0 and int(counts.particle_emitters) == 0, "beacons use bounded emissive meshes without dynamic lights or particles")
	_check(not bool(performance.uses_external_assets), "component requires no external art assets")

	var profile_instances: Array[Node] = [activity]
	var expected_equipment := {
		StationOperationsActivity.ActivityProfile.FULL: [1, 1, 2, 4, 5],
		StationOperationsActivity.ActivityProfile.GANTRY: [1, 0, 0, 4, 1],
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: [0, 1, 0, 4, 2],
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: [0, 0, 2, 4, 2],
	}
	var expected_mounts := {
		StationOperationsActivity.ActivityProfile.GANTRY: &"level_deck",
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: &"deck_edge",
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: &"deck_or_inverted_ceiling_anchor",
	}
	for profile: int in [
		StationOperationsActivity.ActivityProfile.GANTRY,
		StationOperationsActivity.ActivityProfile.SERVICE_ARM,
		StationOperationsActivity.ActivityProfile.DRONE_PATROL,
	]:
		var profiled := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		profiled.activity_profile = profile
		profiled.variation_seed = 40000 + profile
		root.add_child(profiled)
		await process_frame
		profile_instances.append(profiled)
		var profile_audit := profiled.get_audit_report()
		var profile_performance := profile_audit.performance as Dictionary
		var profile_counts := profile_performance.counts as Dictionary
		var equipment := profile_audit.equipment as Dictionary
		var profile_integration := profile_audit.integration as Dictionary
		var expected: Array = expected_equipment[profile]
		print("STATION_OPERATIONS_PROFILE_%s: %s" % [profiled.get_activity_profile_id(), profile_counts])
		_check(bool(profile_audit.valid), "%s profile passes its dynamic validation" % profiled.get_activity_profile_id())
		_check(
			int(equipment.gantry_count) == int(expected[0])
			and int(equipment.service_arm_count) == int(expected[1])
			and int(equipment.service_drone_count) == int(expected[2])
			and int(equipment.safety_beacon_count) == int(expected[3])
			and int(equipment.animated_assembly_count) == int(expected[4]),
			"%s profile builds only its declared equipment" % profiled.get_activity_profile_id()
		)
		_check(
			profile_integration.mount_type == expected_mounts[profile]
			and (profile_integration.local_size as Vector3).length() < (integration.local_size as Vector3).length(),
			"%s profile publishes its compact, role-specific mount envelope" % profiled.get_activity_profile_id()
		)
		_check(
			bool((profile_integration.drone_motion_envelope as Dictionary).present) == (profile == StationOperationsActivity.ActivityProfile.DRONE_PATROL),
			"%s profile publishes the correct drone motion-envelope presence" % profiled.get_activity_profile_id()
		)
		_check(int(profile_integration.visible_mount_footprint_count) > 0, "%s profile retains a visible supported mount" % profiled.get_activity_profile_id())
		_check(_meshes_stay_inside_declared_envelope(profiled), "%s profile render and motion remain inside its published envelope" % profiled.get_activity_profile_id())
		_check(
			int(profile_counts.collision_nodes) == 0
			and int(profile_counts.lights) == 0
			and int(profile_counts.particle_emitters) == 0,
			"%s profile stays nonblocking and headless-safe" % profiled.get_activity_profile_id()
		)
		var first_seek := profiled.set_activity_time(6.75)
		var seek_state := profiled.get_activity_state()
		profiled.set_activity_time(14.0)
		profiled.set_activity_time(6.75)
		_check(first_seek and _states_match(seek_state, profiled.get_activity_state()), "%s profile seek is deterministic" % profiled.get_activity_profile_id())
		profiled.set_activity_paused(true)
		_check(not profiled.is_processing() and not profiled.advance_activity_simulation(1.0), "%s profile pause prevents all process advancement" % profiled.get_activity_profile_id())
		profiled.set_activity_paused(false)
		profiled.set_activity_enabled(false)
		_check(not profiled.is_processing() and not profiled.advance_activity_simulation(1.0), "%s profile disable prevents all process advancement" % profiled.get_activity_profile_id())
		profiled.set_activity_enabled(true)

	var roster_audit := StationOperationsActivity.audit_production_roster(profile_instances)
	print("STATION_OPERATIONS_PRODUCTION_ROSTER: ", roster_audit)
	_check(bool(roster_audit.valid), "one of each profile satisfies the recommended production roster audit")
	_check(int((roster_audit.counts as Dictionary).mesh_instances) <= 180, "four distinct production roles stay within the 180-mesh aggregate budget")
	var mutated_profile := profile_instances[1] as StationOperationsActivity
	mutated_profile.activity_profile = StationOperationsActivity.ActivityProfile.FULL
	_check(not bool(mutated_profile.get_audit_report().valid), "changing the exported profile after build is detected instead of misreporting geometry")
	_check(
		not bool(StationOperationsActivity.audit_production_roster(profile_instances).valid),
		"production roster rejects a component whose built profile configuration was mutated"
	)
	mutated_profile.activity_profile = StationOperationsActivity.ActivityProfile.GANTRY

	var built_fingerprint := mutated_profile.get_determinism_fingerprint()
	mutated_profile.set_activity_time(9.25)
	var built_seed_state := mutated_profile.get_activity_state()
	mutated_profile.variation_seed += 1
	mutated_profile.set_activity_time(9.25)
	var seed_mutation_roster := StationOperationsActivity.audit_production_roster(profile_instances)
	_check(
		not bool(mutated_profile.get_audit_report().valid)
		and mutated_profile.get_determinism_fingerprint() == built_fingerprint
		and _states_match(built_seed_state, mutated_profile.get_activity_state()),
		"post-build seed mutation fails red while deterministic motion keeps its immutable built seed"
	)
	_check(
		not bool(seed_mutation_roster.valid)
		and _errors_include(seed_mutation_roster.errors as PackedStringArray, "fails its own audit"),
		"production roster rejects a seed-mutated component through its complete component audit"
	)
	mutated_profile.variation_seed -= 1

	var before_manual_process := mutated_profile.get_activity_time()
	mutated_profile.playback_speed = 2.0
	mutated_profile._process(1.0)
	_check(
		not bool(mutated_profile.get_audit_report().valid)
		and is_equal_approx(mutated_profile.get_activity_time() - before_manual_process, 1.0),
		"post-build playback mutation fails red and cannot alter the immutable built playback rate"
	)
	_check(
		not bool(StationOperationsActivity.audit_production_roster(profile_instances).valid),
		"production roster rejects a component whose exported playback configuration was mutated"
	)
	mutated_profile.playback_speed = 1.0
	mutated_profile.starts_enabled = false
	_check(not bool(mutated_profile.get_audit_report().valid), "post-build starts-enabled mutation fails component audit")
	mutated_profile.starts_enabled = true
	mutated_profile.starts_paused = true
	_check(not bool(mutated_profile.get_audit_report().valid), "post-build starts-paused mutation fails component audit")
	mutated_profile.starts_paused = false
	_check(bool(StationOperationsActivity.audit_production_roster(profile_instances).valid), "restoring exported build configuration restores roster validity")

	var invalid_profile := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	invalid_profile.activity_profile = 99
	root.add_child(invalid_profile)
	await process_frame
	_check(not bool(invalid_profile.get_audit_report().valid), "invalid exported profile fails validation without crashing")

	# Equal seed and absolute time must produce identical reusable instances.
	var peer := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	peer.variation_seed = activity.variation_seed
	peer.position = Vector3(30.0, 4.0, -18.0)
	root.add_child(peer)
	await process_frame
	activity.set_activity_time(12.75)
	peer.set_activity_time(12.75)
	_check(activity.get_determinism_fingerprint() == peer.get_determinism_fingerprint(), "equivalent instances expose identical deterministic fingerprints")
	_check(_states_match(activity.get_activity_state(), peer.get_activity_state()), "absolute seek is independent of world placement")

	# Total-time transforms are independent of frame subdivision.
	activity.reset_activity_time()
	peer.reset_activity_time()
	activity.advance_activity_simulation(5.25)
	for _step in 21:
		peer.advance_activity_simulation(0.25)
	_check(_states_match(activity.get_activity_state(), peer.get_activity_state()), "motion state is frame-subdivision independent")

	var paused_state := activity.get_activity_state()
	activity.set_activity_paused(true)
	_check(not activity.is_processing(), "pause disables per-frame process work")
	_check(not activity.advance_activity_simulation(2.0), "manual advancement respects pause")
	_check(_states_match(paused_state, activity.get_activity_state(), false), "pause preserves equipment transforms and elapsed time")
	activity.set_activity_paused(true)
	_check(not activity.is_processing(), "repeated pause is idempotent")

	activity.set_activity_enabled(false)
	_check(not activity.is_processing() and not bool(activity.get_activity_state().visible), "disable hides presentation and performs no process work")
	_check(not activity.advance_activity_simulation(2.0), "disabled activity cannot advance")
	activity.set_activity_enabled(false)
	_check(not activity.is_processing(), "repeated disable is idempotent")
	activity.set_activity_paused(false)
	_check(not activity.is_processing(), "unpausing while disabled does not restart work")
	activity.set_activity_enabled(true)
	_check(activity.is_processing() and bool(activity.get_activity_state().visible), "reenable restores presentation and deterministic processing")

	activity.set_process(false)
	var stopped_process_audit := activity.get_audit_report()
	_check(
		not bool(stopped_process_audit.valid)
		and _errors_include(stopped_process_audit.errors as PackedStringArray, "process state"),
		"component audit fails red when advancing lifecycle state has no actual process work"
	)
	activity.set_activity_enabled(true)
	activity.set_activity_paused(true)
	activity.set_process(true)
	var paused_process_audit := activity.get_audit_report()
	_check(
		not bool(paused_process_audit.valid)
		and _errors_include(paused_process_audit.errors as PackedStringArray, "process state"),
		"component audit fails red when paused lifecycle state still has actual process work"
	)
	activity.set_activity_paused(false)
	_check(bool(activity.get_audit_report().valid), "lifecycle setters repair externally corrupted process state")

	# The public audit must describe the live authored presentation, not only its
	# node count and broad envelope. Every mutation below is reversible and must
	# fail red without rebuilding the component.
	var foot_pad := activity.get_node("PresentationRoot/MaintenanceGantry/FootPad") as MeshInstance3D
	var original_transparency := foot_pad.transparency
	foot_pad.transparency = 1.0
	_check(not bool(activity.get_audit_report().valid), "audit rejects a fully transparent generated mesh")
	foot_pad.transparency = original_transparency
	# The generated boxes are chamfered `ArrayMesh` resources rather than
	# `BoxMesh`, so the reversible in-place drift witness now shrinks the live
	# mesh's declared bounds instead of resizing a primitive. It is the same class
	# of mutation as the `BoxMesh.size` witness it replaces: one stored geometry
	# property of the component's own generated resource, changed in place and
	# restored exactly. Rebuilding the surface arrays instead is not usable here,
	# because a `surface_get_arrays` round trip is not bit-exact and so cannot be
	# undone without leaving the component permanently red.
	var foot_mesh := foot_pad.mesh as ArrayMesh
	var original_custom_aabb := foot_mesh.custom_aabb
	foot_mesh.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.001)
	_check(not bool(activity.get_audit_report().valid), "audit rejects in-place generated mesh geometry drift")
	foot_mesh.custom_aabb = original_custom_aabb
	var original_material := foot_pad.material_override as StandardMaterial3D
	var original_cull_mode := original_material.cull_mode
	original_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_check(not bool(activity.get_audit_report().valid), "audit rejects in-place shared material presentation drift")
	original_material.cull_mode = original_cull_mode
	var gantry := activity.get_node("PresentationRoot/MaintenanceGantry") as Node3D
	var original_gantry_scale := gantry.scale
	gantry.scale = Vector3.ONE * 0.001
	_check(not bool(activity.get_audit_report().valid), "audit rejects static assembly transform drift")
	gantry.scale = original_gantry_scale
	var original_carriage_position := (activity.get_node("PresentationRoot/MaintenanceGantry/AnimatedGantryCarriage") as Node3D).position
	(activity.get_node("PresentationRoot/MaintenanceGantry/AnimatedGantryCarriage") as Node3D).position.x += 0.2
	_check(not bool(activity.get_audit_report().valid), "audit rejects moving assembly pose drift from the deterministic clock")
	(activity.get_node("PresentationRoot/MaintenanceGantry/AnimatedGantryCarriage") as Node3D).position = original_carriage_position
	_check(bool(activity.get_audit_report().valid), "restoring presentation resources and poses restores the complete audit")

	var elapsed_before_reentry := activity.get_activity_time()
	root.remove_child(activity)
	root.add_child(activity)
	await process_frame
	await process_frame
	_check(
		activity.is_activity_advancing()
		and activity.is_processing()
		and activity.get_activity_time() > elapsed_before_reentry
		and bool(activity.get_audit_report().valid),
		"child remove and re-add under the same world restores enabled advancing process work"
	)
	activity.set_activity_paused(true)
	var paused_reentry_time := activity.get_activity_time()
	root.remove_child(activity)
	root.add_child(activity)
	await process_frame
	_check(
		activity.is_activity_enabled()
		and activity.is_activity_paused()
		and not activity.is_activity_advancing()
		and not activity.is_processing()
		and is_equal_approx(activity.get_activity_time(), paused_reentry_time)
		and bool(activity.get_activity_state().visible)
		and bool(activity.get_audit_report().valid),
		"child remove and re-add preserves paused visible lifecycle without process work"
	)
	activity.set_activity_paused(false)
	activity.set_activity_enabled(false)
	var disabled_reentry_time := activity.get_activity_time()
	root.remove_child(activity)
	root.add_child(activity)
	await process_frame
	_check(
		not activity.is_activity_enabled()
		and not activity.is_activity_advancing()
		and not activity.is_processing()
		and is_equal_approx(activity.get_activity_time(), disabled_reentry_time)
		and not bool(activity.get_activity_state().visible)
		and bool(activity.get_audit_report().valid),
		"child remove and re-add preserves disabled hidden lifecycle without process work"
	)
	activity.set_activity_enabled(true)

	var preconfigured := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	preconfigured.set_activity_enabled(false)
	preconfigured.set_activity_paused(true)
	root.add_child(preconfigured)
	await process_frame
	_check(
		not preconfigured.is_activity_enabled()
		and preconfigured.is_activity_paused()
		and not preconfigured.is_processing(),
		"lifecycle configuration made before tree entry is preserved by ready"
	)

	var detached_audit := activity.get_audit_report()
	(detached_audit.performance as Dictionary).clear()
	_check(not activity.get_performance_audit().is_empty(), "audit dictionaries are detached from component state")

	peer.queue_free()
	preconfigured.queue_free()
	invalid_profile.queue_free()
	for profile_instance in profile_instances:
		if profile_instance != activity:
			profile_instance.queue_free()
	activity.queue_free()
	await process_frame
	await process_frame
	_finish()


func _states_match(first: Dictionary, second: Dictionary, compare_lifecycle: bool = true) -> bool:
	if not is_equal_approx(float(first.elapsed), float(second.elapsed)):
		return false
	if compare_lifecycle and (
		bool(first.enabled) != bool(second.enabled)
		or bool(first.paused) != bool(second.paused)
		or bool(first.advancing) != bool(second.advancing)
	):
		return false
	if not (first.gantry_carriage_position as Vector3).is_equal_approx(second.gantry_carriage_position as Vector3):
		return false
	if not (first.gantry_tool_position as Vector3).is_equal_approx(second.gantry_tool_position as Vector3):
		return false
	if not (first.service_arm_shoulder_rotation as Vector3).is_equal_approx(second.service_arm_shoulder_rotation as Vector3):
		return false
	if not (first.service_arm_elbow_rotation as Vector3).is_equal_approx(second.service_arm_elbow_rotation as Vector3):
		return false
	var first_drones := first.drones as Array
	var second_drones := second.drones as Array
	if first_drones.size() != second_drones.size():
		return false
	for index in first_drones.size():
		if not ((first_drones[index] as Dictionary).position as Vector3).is_equal_approx((second_drones[index] as Dictionary).position as Vector3):
			return false
		if not ((first_drones[index] as Dictionary).rotation as Vector3).is_equal_approx((second_drones[index] as Dictionary).rotation as Vector3):
			return false
	return first.beacon_pattern == second.beacon_pattern


func _errors_include(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false


func _meshes_stay_inside_declared_envelope(activity: StationOperationsActivity) -> bool:
	var contract := activity.get_integration_contract()
	var local_min := contract.local_min as Vector3
	var local_max := contract.local_max as Vector3
	for sample_time in [0.0, 2.75, 8.5, 17.25, 31.0]:
		activity.set_activity_time(sample_time)
		for candidate in activity.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance == null:
				continue
			var bounds := mesh_instance.get_aabb()
			for corner_index in 8:
				var corner := bounds.position + Vector3(
					bounds.size.x if corner_index & 1 else 0.0,
					bounds.size.y if corner_index & 2 else 0.0,
					bounds.size.z if corner_index & 4 else 0.0
				)
				var local_point := activity.to_local(mesh_instance.to_global(corner))
				if local_point.x < local_min.x - 0.02 or local_point.x > local_max.x + 0.02 \
					or local_point.y < local_min.y - 0.02 or local_point.y > local_max.y + 0.02 \
					or local_point.z < local_min.z - 0.02 or local_point.z > local_max.z + 0.02:
					print("ENVELOPE_ESCAPE: ", activity.get_activity_profile_id(), " ", mesh_instance.get_path(), " @ ", sample_time, " -> ", local_point)
					return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_OPERATIONS_ACTIVITY_TEST_OK")
		quit(0)
	else:
		print("STATION_OPERATIONS_ACTIVITY_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
