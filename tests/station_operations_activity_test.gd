extends SceneTree

const ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")

## Frozen directly from the production player scene: 1.42 m pivot, the default
## 5.2 m boom at 10 degrees, 0.16 m SpringArm sphere, 0.28 m margin and 0.08 m
## camera near plane. This is the walking-camera lane the old FULL orbit entered.
const WALKING_CAMERA_SWEEP_TOP_Y := 1.42 + sin(deg_to_rad(10.0)) * 5.2 + 0.16 + 0.28 + 0.08
const DRONE_LOWEST_VISUAL_OFFSET_Y := -0.61
const LEGACY_FULL_DRONE_BASE_ELEVATION := 1.48

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
	_check(
		integration.collision_policy == &"world_owned_declared_solids_presentation_nonblocking"
		and int(integration.declared_solid_volume_count) == 6
		and not bool(integration.owns_collision),
		"FULL declares six exact world-realised solids without giving its presentation subtree collision authority"
	)
	_check(
		(integration.intentionally_nonblocking_static_families as PackedStringArray)
		== PackedStringArray(["safety_beacon_sacrificial_route_marker"]),
		"every profile publishes the safety beacon's intentional sacrificial nonphysical policy"
	)
	_check((integration.local_size as Vector3).is_equal_approx(Vector3(11.3, 7.25, 9.0)), "integration footprint is complete and finite")
	_check(_meshes_stay_inside_declared_envelope(activity), "FULL profile render and motion remain inside its published envelope")
	await _test_full_drone_camera_clearance(activity)

	var performance := activity.get_performance_audit()
	var counts := performance.counts as Dictionary
	print("STATION_OPERATIONS_PERFORMANCE: ", performance)
	_check(bool(performance.within_budget), "runtime node and material counts remain within the published budget")
	_check(int(counts.collision_nodes) == 0, "component contains no body, area, shape, or collision polygon")
	_check(int(counts.lights) == 0 and int(counts.particle_emitters) == 0, "beacons use bounded emissive meshes without dynamic lights or particles")
	_check(not bool(performance.uses_external_assets), "component requires no external art assets")
	_check(
		int((activity.get_performance_audit(6).aggregate_counts as Dictionary).unique_materials) == 17,
		"aggregate performance audit counts the shared catalog once across six placements"
	)

	var profile_instances: Array[Node] = [activity]
	var expected_equipment := {
		StationOperationsActivity.ActivityProfile.FULL: [1, 1, 2, 4, 5],
		StationOperationsActivity.ActivityProfile.GANTRY: [1, 0, 0, 4, 1],
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: [0, 1, 0, 4, 2],
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: [0, 0, 2, 4, 2],
		StationOperationsActivity.ActivityProfile.CARGO_LINE: [0, 0, 0, 4, 2],
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: [0, 0, 0, 4, 1],
		StationOperationsActivity.ActivityProfile.OBSERVATORY: [0, 0, 0, 4, 2],
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: [0, 0, 0, 4, 2],
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG: [0, 0, 0, 4, 2],
	}
	## Movers and material-swapped lenses each station-life profile must build.
	var expected_station_life := {
		StationOperationsActivity.ActivityProfile.GANTRY: [0, 0],
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: [0, 0],
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: [0, 0],
		StationOperationsActivity.ActivityProfile.CARGO_LINE: [2, 2],
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: [1, 5],
		StationOperationsActivity.ActivityProfile.OBSERVATORY: [2, 1],
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: [2, 1],
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG: [2, 2],
	}
	var expected_mounts := {
		StationOperationsActivity.ActivityProfile.GANTRY: &"level_deck",
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: &"deck_edge",
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: &"deck_or_inverted_ceiling_anchor",
		StationOperationsActivity.ActivityProfile.CARGO_LINE: &"level_deck",
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: &"level_deck",
		StationOperationsActivity.ActivityProfile.OBSERVATORY: &"level_deck",
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: &"deck_edge",
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG: &"level_deck",
	}
	var expected_solid_volume_counts := {
		StationOperationsActivity.ActivityProfile.GANTRY: 4,
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: 2,
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: 0,
		StationOperationsActivity.ActivityProfile.CARGO_LINE: 11,
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: 0,
		StationOperationsActivity.ActivityProfile.OBSERVATORY: 0,
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: 12,
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG: 14,
	}
	## The exact published mount envelope of each specialised profile, in metres.
	var expected_envelopes := {
		StationOperationsActivity.ActivityProfile.GANTRY: Vector3(10.8, 7.25, 7.2),
		StationOperationsActivity.ActivityProfile.SERVICE_ARM: Vector3(4.8, 5.45, 3.5),
		StationOperationsActivity.ActivityProfile.DRONE_PATROL: Vector3(9.1, 2.4, 7.1),
		StationOperationsActivity.ActivityProfile.CARGO_LINE: Vector3(9.7, 2.98, 5.3),
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: Vector3(3.6, 4.5, 3.0),
		StationOperationsActivity.ActivityProfile.OBSERVATORY: Vector3(4.7, 3.75, 4.7),
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: Vector3(5.7, 2.6, 3.9),
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG: Vector3(22.8, 3.0, 3.6),
	}
	for profile: int in [
		StationOperationsActivity.ActivityProfile.GANTRY,
		StationOperationsActivity.ActivityProfile.SERVICE_ARM,
		StationOperationsActivity.ActivityProfile.DRONE_PATROL,
		StationOperationsActivity.ActivityProfile.CARGO_LINE,
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON,
		StationOperationsActivity.ActivityProfile.OBSERVATORY,
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST,
		# Twice, because the recommended roster carries two long runs and
		# `audit_production_roster` holds each profile to an exact count.
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG,
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG,
	]:
		var profiled := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		profiled.activity_profile = profile
		profiled.variation_seed = 40000 + profile + profile_instances.size()
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
		var expected_life: Array = expected_station_life[profile]
		_check(
			int(equipment.station_life_mover_count) == int(expected_life[0])
			and int(equipment.station_life_lens_count) == int(expected_life[1]),
			"%s profile builds exactly its declared station-life movers and lenses" % profiled.get_activity_profile_id()
		)
		# Re-frozen from "smaller than FULL" to an exact size per profile. The old
		# rule was a proxy for "a specialised profile omits the assemblies it does
		# not use", and it stopped being that the moment a profile was deliberately
		# longer than the gantry: a 21.6 m transfer run is not a bloated cargo line,
		# it is the thing that was asked for. An exact envelope per profile is
		# stricter than the bound it replaces — it fails on growth *and* shrinkage,
		# in any single axis, rather than only on a longer diagonal.
		_check(
			profile_integration.mount_type == expected_mounts[profile]
			and (profile_integration.local_size as Vector3).is_equal_approx(
				expected_envelopes[profile] as Vector3
			),
			"%s profile publishes its exact role-specific mount envelope" % profiled.get_activity_profile_id()
		)
		_check(
			bool((profile_integration.drone_motion_envelope as Dictionary).present) == (profile == StationOperationsActivity.ActivityProfile.DRONE_PATROL),
			"%s profile publishes the correct drone motion-envelope presence" % profiled.get_activity_profile_id()
		)
		_check(int(profile_integration.visible_mount_footprint_count) > 0, "%s profile retains a visible supported mount" % profiled.get_activity_profile_id())
		var expected_solid_count := int(expected_solid_volume_counts[profile])
		_check(
			int(profile_integration.declared_solid_volume_count) == expected_solid_count
			and not bool(profile_integration.owns_collision)
			and profile_integration.collision_policy == (
				&"world_owned_declared_solids_presentation_nonblocking"
				if expected_solid_count > 0
				else &"presentation_only_nonblocking"
			),
			"%s publishes its exact owning-world solid declaration without local authority" % profiled.get_activity_profile_id()
		)
		_check(
			(profile_integration.intentionally_nonblocking_static_families as PackedStringArray)
			== PackedStringArray(["safety_beacon_sacrificial_route_marker"]),
			"%s preserves the universal nonphysical safety-beacon policy" % profiled.get_activity_profile_id()
		)
		_check(_meshes_stay_inside_declared_envelope(profiled), "%s profile render and motion remain inside its published envelope" % profiled.get_activity_profile_id())
		_check(
			int(profile_counts.collision_nodes) == 0
			and int(profile_counts.lights) == 0
			and int(profile_counts.particle_emitters) == 0,
			"%s presentation subtree stays collision-free and headless-safe" % profiled.get_activity_profile_id()
		)
		if profile == StationOperationsActivity.ActivityProfile.CREW_WORKPOST:
			_check_crew_workpost_hung_tool_batch(profiled)
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
	_check(bool(roster_audit.valid), "the audited profile multiset satisfies the recommended production roster audit")
	var roster_catalog := roster_audit.material_catalog as Dictionary
	var full_catalog := activity.get_material_catalog_audit()
	var visible_parameters := full_catalog.visible_parameters_by_key as Dictionary
	_check(
		bool(roster_catalog.valid)
		and bool(roster_catalog.catalog_shared)
		and int(roster_catalog.catalog_entries) == 17
		and int(roster_catalog.retained_unique_materials) == 17,
		"ten placements retain one shared 17-entry material catalog instead of 170 duplicate resources"
	)
	_check(
		(full_catalog.catalog_keys as PackedStringArray) == PackedStringArray([
			"amber_dim", "amber_lit", "ceramic", "crate", "crate_alt", "cyan_dim",
			"cyan_lit", "frame", "frame_edge", "graphite", "green_dim", "green_lit",
			"orange", "red_dim", "red_lit", "rubber", "sign_lit",
		]),
		"shared catalog preserves the exact visible material-key roster"
	)
	_check(
		int(roster_catalog.bound_material_references) == 412
		and int(roster_catalog.dynamic_lens_count) == 57
		and bool(roster_catalog.dynamic_lens_bindings_valid),
		"sharing leaves all 412 renderer bindings and 57 per-instance dynamic lens bindings intact"
	)
	var frame_parameters := visible_parameters.frame as Dictionary
	var amber_parameters := visible_parameters.amber_lit as Dictionary
	var sign_parameters := visible_parameters.sign_lit as Dictionary
	_check(
		(frame_parameters.albedo_color as Color).is_equal_approx(Color("253943"))
		and is_equal_approx(float(frame_parameters.metallic), 0.72)
		and is_equal_approx(float(frame_parameters.roughness), 0.32)
		and (amber_parameters.albedo_color as Color).is_equal_approx(Color("ffc069"))
		and is_equal_approx(float(amber_parameters.emission_energy), 1.8)
		and (sign_parameters.albedo_color as Color).is_equal_approx(Color("e8f2ef"))
		and is_equal_approx(float(sign_parameters.emission_energy), 1.15),
		"shared resources preserve representative structural, warning, and sign visible parameters"
	)
	# Re-frozen from 4 roles / 180 meshes by the station-life pass, 180 -> 339
	# (79 + 48 + 19 + 32 + 47 + 33 + 33 + 48).
	#
	# Re-frozen again, 339 -> 404, by the long-cargo pass: the roster went eight
	# placements to ten, both additions `cargo_line_long`, and `cargo_line` itself
	# went 47 -> 34 drawn meshes when its thirteen repeated ties, wheels, ribs and
	# post bands became four instanced batches drawing the same thirteen copies of
	# the same meshes at the same sizes and positions.
	# 79 + 48 + 19 + 32 + 34 + 33 + 33 + 48 + 39 + 39 = 404.
	#
	# The instanced copies are audited separately and exactly, so the reduction
	# cannot hide geometry. The crew workpost then moved 404 -> 399 drawn meshes,
	# 12 -> 13 batches and 57 -> 62 visible batched copies when its five identical
	# hung tools became one renderer submission at their exact authored transforms.
	_check(int((roster_audit.counts as Dictionary).node_count) == 527, "ten production placements have the exact 527-node aggregate")
	_check(int((roster_audit.counts as Dictionary).mesh_instances) == 399, "ten production placements have the exact 399 drawn-mesh aggregate")
	_check(
		int((roster_audit.counts as Dictionary).multimesh_batches) == 13
		and int((roster_audit.counts as Dictionary).multimesh_instances) == 62,
		"instanced structure is reported exactly rather than vanishing from the mesh count"
	)
	_check(int((roster_audit.counts as Dictionary).instance_count) == 10, "the recommended production roster is exactly ten placements")
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
	_check(
		not bool(activity.get_audit_report().valid)
		and not bool(peer.get_material_catalog_audit().valid),
		"all placements reject in-place drift of their deliberately shared immutable material"
	)
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

	await _test_station_life_behaviour()

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

## Regression witness for the Central FULL placement. Before the fix this exact
## check fails: the first drone bottoms at 0.69 m, well inside the production
## player's default walking-camera sweep. The roof patrol is a separate mounting
## contract, so it must remain byte-for-formula identical while FULL moves up.
func _test_full_drone_camera_clearance(full: StationOperationsActivity) -> void:
	var was_paused := full.is_activity_paused()
	full.set_activity_paused(true)
	var roof_patrol := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
	roof_patrol.activity_profile = StationOperationsActivity.ActivityProfile.DRONE_PATROL
	roof_patrol.variation_seed = full.variation_seed
	roof_patrol.starts_paused = true
	root.add_child(roof_patrol)
	await process_frame

	var full_clear := true
	var roof_route_unchanged := true
	var seed_phase := fmod(float(full.variation_seed), 997.0) / 997.0 * TAU
	for step in 1201:
		var seconds := float(step) * 0.0125
		full.set_activity_time(seconds)
		roof_patrol.set_activity_time(seconds)
		var full_drones := full.get_activity_state().drones as Array
		var roof_drones := roof_patrol.get_activity_state().drones as Array
		for index in roof_drones.size():
			var full_position := (full_drones[index] as Dictionary).position as Vector3
			full_clear = (
				full_clear
				and full_position.y + DRONE_LOWEST_VISUAL_OFFSET_Y
				> WALKING_CAMERA_SWEEP_TOP_Y
			)
			var phase := seconds * (0.24 + index * 0.035) + seed_phase + float(index) * PI
			var expected_roof_position := Vector3(
				cos(phase) * (3.55 - index * 0.28),
				LEGACY_FULL_DRONE_BASE_ELEVATION + float(index) * 0.44 + sin(phase * 2.0) * 0.18,
				sin(phase) * (2.85 - index * 0.22)
			)
			roof_route_unchanged = (
				roof_route_unchanged
				and ((roof_drones[index] as Dictionary).position as Vector3).is_equal_approx(
					expected_roof_position
				)
			)

	_check(
		LEGACY_FULL_DRONE_BASE_ELEVATION - 0.18 + DRONE_LOWEST_VISUAL_OFFSET_Y
		<= WALKING_CAMERA_SWEEP_TOP_Y,
		"legacy FULL orbit is a deterministic witness inside the real walking-camera sweep"
	)
	_check(full_clear, "FULL drones and their cargo pods remain above the real walking-camera sweep")
	_check(roof_route_unchanged, "roof-patrol placement and timing retain the original mount-relative route")

	var full_envelope := full.get_integration_contract().drone_motion_envelope as Dictionary
	var roof_envelope := roof_patrol.get_integration_contract().drone_motion_envelope as Dictionary
	_check(
		(full_envelope.local_center as Vector3).is_equal_approx(Vector3(0.0, 3.97, 0.0))
		and (roof_envelope.local_center as Vector3).is_equal_approx(Vector3(0.0, 1.7, 0.0))
		and (full_envelope.half_extents as Vector3).is_equal_approx(
			roof_envelope.half_extents as Vector3
		),
		"published FULL drone envelope moves 1.70 -> 3.97 m without resizing the roof route"
	)

	var pulse_materials_unchanged := true
	var full_lens := full.get_node(
		^"PresentationRoot/AnimatedServiceDrone01/NavigationLens"
	) as MeshInstance3D
	var roof_lens := roof_patrol.get_node(
		^"PresentationRoot/AnimatedServiceDrone01/NavigationLens"
	) as MeshInstance3D
	for step in 55:
		var seconds := float(step) * 0.025
		full.set_activity_time(seconds)
		roof_patrol.set_activity_time(seconds)
		pulse_materials_unchanged = (
			pulse_materials_unchanged
			and full_lens.material_override == roof_lens.material_override
		)
	_check(
		pulse_materials_unchanged,
		"FULL reroute preserves the roof patrol's exact 1.35 s pulse timing and shared material identity"
	)

	roof_patrol.queue_free()
	await process_frame
	full.set_activity_time(0.0)
	full.set_activity_paused(was_paused)


## The four station-life profiles as a behaviour group: the movers must be pure
## functions of the clock, the material-swapped lenses must actually change state
## over one cycle rather than sitting on one material, and both must fail the
## audit red when nudged off the pose or the material the clock implies.
func _test_station_life_behaviour() -> void:
	var cases := {
		StationOperationsActivity.ActivityProfile.CARGO_LINE: "PresentationRoot/CargoTransferLine/AnimatedCargoSled",
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON: "PresentationRoot/WayfindingPylon/AnimatedIdentifierDrum",
		StationOperationsActivity.ActivityProfile.OBSERVATORY: "PresentationRoot/SkywatchPost/AnimatedSkywatchYoke",
		StationOperationsActivity.ActivityProfile.CREW_WORKPOST: "PresentationRoot/CrewWorkPost/AnimatedToolCarousel",
	}
	for profile: int in cases:
		var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		activity.activity_profile = profile
		activity.variation_seed = 60000 + profile
		root.add_child(activity)
		await process_frame
		var profile_id := activity.get_activity_profile_id()

		# A mover must actually move, and both movers must be distinguishable.
		activity.set_activity_time(0.0)
		var first_state := activity.get_activity_state()
		activity.set_activity_time(4.4)
		var later_state := activity.get_activity_state()
		var moved := false
		var movers_first := first_state.station_life_movers as Array
		var movers_later := later_state.station_life_movers as Array
		for index in movers_first.size():
			var before := movers_first[index] as Dictionary
			var after := movers_later[index] as Dictionary
			moved = moved or not (
				(before.position as Vector3).is_equal_approx(after.position as Vector3)
				and (before.rotation as Vector3).is_equal_approx(after.rotation as Vector3)
			)
		_check(moved, "%s station-life movers advance with the deterministic clock" % profile_id)

		# Every lens must be observed both lit and unlit inside one 8 s sweep, so
		# a lens frozen on one material cannot pass as a working cue.
		var lens_count := int((activity.get_equipment_counts() as Dictionary).station_life_lens_count)
		var seen_lit: Array[bool] = []
		var seen_dark: Array[bool] = []
		for _index in lens_count:
			seen_lit.append(false)
			seen_dark.append(false)
		for step in 320:
			activity.set_activity_time(float(step) * 0.025)
			var lit := activity.get_activity_state().station_life_lit as Array
			for index in lit.size():
				if bool(lit[index]):
					seen_lit[index] = true
				else:
					seen_dark[index] = true
		var all_cycle := lens_count > 0
		for index in lens_count:
			all_cycle = all_cycle and seen_lit[index] and seen_dark[index]
		_check(all_cycle, "%s lights and clears every station-life lens within one cycle" % profile_id)

		# Frame subdivision independence for the new movers specifically.
		var peer := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		peer.activity_profile = profile
		peer.variation_seed = activity.variation_seed
		peer.position = Vector3(-24.0, 3.0, 41.0)
		root.add_child(peer)
		await process_frame
		activity.reset_activity_time()
		peer.reset_activity_time()
		activity.advance_activity_simulation(6.0)
		for _step in 24:
			peer.advance_activity_simulation(0.25)
		_check(
			_states_match(activity.get_activity_state(), peer.get_activity_state()),
			"%s station-life motion is frame-subdivision and placement independent" % profile_id
		)

		_check(bool(activity.get_audit_report().valid), "%s station-life build passes its own audit" % profile_id)
		var mover := activity.get_node(cases[profile] as String) as Node3D
		var original_position := mover.position
		mover.position.x += 0.25
		_check(
			not bool(activity.get_audit_report().valid),
			"%s audit rejects a station-life mover nudged off its clock pose" % profile_id
		)
		mover.position = original_position
		var lens_path := _first_station_life_lens_path(activity)
		var lens := activity.get_node(lens_path) as MeshInstance3D
		var original_lens_material := lens.material_override
		lens.material_override = (
			activity.get_node("PresentationRoot/SafetyBeacon01/Base") as MeshInstance3D
		).material_override
		_check(
			not bool(activity.get_audit_report().valid),
			"%s audit rejects a station-life lens forced off its clock material" % profile_id
		)
		lens.material_override = original_lens_material
		_check(bool(activity.get_audit_report().valid), "%s station-life mutations are fully reversible" % profile_id)

		peer.queue_free()
		activity.queue_free()
		await process_frame


func _first_station_life_lens_path(activity: StationOperationsActivity) -> String:
	match activity.get_activity_profile():
		StationOperationsActivity.ActivityProfile.CARGO_LINE:
			return "PresentationRoot/CargoTransferLine/AnimatedCargoSled/SledStrobe"
		StationOperationsActivity.ActivityProfile.SIGNAGE_PYLON:
			return "PresentationRoot/WayfindingPylon/Chevron"
		StationOperationsActivity.ActivityProfile.OBSERVATORY:
			return "PresentationRoot/SkywatchPost/AnimatedSkywatchYoke/AnimatedOpticTube/OpticLens"
		_:
			return "PresentationRoot/CrewWorkPost/AnimatedWeldJig/WeldArc"


func _check_crew_workpost_hung_tool_batch(activity: StationOperationsActivity) -> void:
	var batch := activity.get_node_or_null(
		^"PresentationRoot/CrewWorkPost/HungTools"
	) as MultiMeshInstance3D
	var graphite_peer := activity.get_node_or_null(
		^"PresentationRoot/CrewWorkPost/BenchShelf"
	) as MeshInstance3D
	var expected: Array[Transform3D] = []
	for index in 5:
		expected.append(
			Transform3D(Basis.IDENTITY, Vector3(-1.85 + float(index) * 0.48, 1.72, 0.935))
		)
	var authored := (
		batch.get_meta("authored_instance_transforms", []) as Array
		if batch != null else []
	)
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (
			authored[index] as Transform3D
		).is_equal_approx(expected[index])
	_check(
		batch != null
		and batch.multimesh != null
		and batch.multimesh.mesh != null
		and batch.multimesh.instance_count == 5
		and batch.multimesh.mesh.get_aabb().size.is_equal_approx(Vector3(0.09, 0.55, 0.05))
		and graphite_peer != null
		and batch.material_override == graphite_peer.material_override
		and authored_exact,
		"crew workpost batches the exact five graphite hung-tool copies without changing their authored geometry"
	)
	if batch == null or batch.multimesh == null:
		return
	if not RenderingServer.get_video_adapter_name().is_empty():
		var live_exact := true
		for index in expected.size():
			live_exact = live_exact and batch.multimesh.get_instance_transform(index).is_equal_approx(
				expected[index]
			)
		_check(live_exact, "Forward+ MultiMesh buffer exactly matches the five-copy authored hung-tool roster")
		var original := batch.multimesh.get_instance_transform(0)
		batch.multimesh.set_instance_transform(0, original.translated(Vector3(0.25, 0.0, 0.0)))
		_check(not bool(activity.get_audit_report().valid), "rendering-buffer drift from the authored hung-tool roster fails the component audit")
		batch.multimesh.set_instance_transform(0, original)
		_check(bool(activity.get_audit_report().valid), "restoring the hung-tool rendering buffer restores the complete component audit")


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
	var first_movers := first.station_life_movers as Array
	var second_movers := second.station_life_movers as Array
	if first_movers.size() != second_movers.size():
		return false
	for index in first_movers.size():
		if not ((first_movers[index] as Dictionary).position as Vector3).is_equal_approx((second_movers[index] as Dictionary).position as Vector3):
			return false
		if not ((first_movers[index] as Dictionary).rotation as Vector3).is_equal_approx((second_movers[index] as Dictionary).rotation as Vector3):
			return false
	if first.station_life_lit != second.station_life_lit:
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
