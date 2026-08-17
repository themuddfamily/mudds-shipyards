extends SceneTree

## Concrete-content regression for the production-neutral Cinder convoy host.

const HostScript := preload(
	"res://scripts/activities/cinder_convoy_escort_host.gd"
)
const ROUTE := preload(
	"res://assets/activities/cinder_reach_emberline_convoy_route.tres"
)
const EXPECTED_VISUAL_COMPONENT_NAMES := [
	"MainHull",
	"ForwardKeel",
	"PortCargoPod",
	"StarboardCargoPod",
	"DriveBlock",
	"DriveGlow",
	"NavigationBeacon",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := HostScript.new() as CinderConvoyEscortHost
	root.add_child(host)
	await process_frame
	_test_content_and_authority_contract(host)
	_test_cargo_pod_visual_allocation(host)
	await _test_movement_proximity_and_safe_arrival(host)
	await _test_loss_reset_and_reentry(host)
	host.queue_free()
	await process_frame
	_finish()


func _test_content_and_authority_contract(host: CinderConvoyEscortHost) -> void:
	var audit := host.audit()
	for error in audit.get("errors", PackedStringArray()) as PackedStringArray:
		print("CINDER_CONVOY_HOST_AUDIT: ", error)
	_check(
		bool(audit.get("valid", false))
		and ROUTE.is_definition_valid()
		and ROUTE.activity_id == &"cinder_reach_emberline_convoy"
		and ROUTE.get_checkpoint_count() == 4
		and is_equal_approx(ROUTE.checkpoint_radius, 4.0)
		and audit.get("route_resource_path") == ROUTE.resource_path,
		"the host composes the exact valid four-position Emberline route resource"
	)
	_test_remaining_content_and_authority_contract(host, audit)


func _test_cargo_pod_visual_allocation(host: CinderConvoyEscortHost) -> void:
	var audit := host.get_cargo_pod_visual_allocation_audit()
	_check(
		bool(audit.get("valid", false)),
		"cargo-pod visual allocation audit is green: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("visual_node_count", 0)) == 7
		and int(audit.get("baseline_visual_node_count", 0)) == 7
		and int(audit.get("visual_node_delta", 99)) == 0
		and int(audit.get("drawn_copy_count", 0)) == 7
		and int(audit.get("drawn_copy_delta", 99)) == 0
		and int(audit.get("mesh_resource_identity_count", 0)) == 6
		and int(audit.get("baseline_mesh_resource_identity_count", 0)) == 7
		and int(audit.get("mesh_resource_identity_delta", 0)) == -1,
		"seven visible nodes and copies retain six meshes instead of seven"
	)
	_check(
		int(audit.get("cargo_pod_copy_count", 0)) == 2
		and int(audit.get("cargo_pod_mesh_resource_identity_count", 0)) == 1
		and int(audit.get("baseline_cargo_pod_mesh_resource_identity_count", 0)) == 2
		and int(audit.get("cargo_pod_mesh_resource_identity_delta", 0)) == -1
		and int(audit.get("material_resource_identity_count", 0)) == 5
		and int(audit.get("material_resource_identity_delta", 99)) == 0,
		"the exact paired cargo-pod family shares one mesh and preserves five materials"
	)
	_check(
		int(audit.get("structural_surface_submission_count", 0)) == 7
		and int(audit.get("structural_surface_submission_delta", 99)) == 0
		and int(audit.get("collision_object_count", -1)) == 0
		and int(audit.get("collision_shape_count", -1)) == 0
		and int(audit.get("navigation_region_count", -1)) == 0
		and int(audit.get("cargo_pod_child_count", -1)) == 0
		and int(audit.get("cargo_pod_script_count", -1)) == 0
		and int(audit.get("cargo_pod_metadata_entry_count", -1)) == 0
		and int(audit.get("cargo_pod_group_count", -1)) == 0
		and int(audit.get("cargo_pod_processing_count", -1)) == 0
		and not bool(audit.get("batched", true))
		and not bool(audit.get("driver_draw_call_claimed", true))
		and not bool(audit.get("frame_time_claimed", true))
		and not bool(audit.get("vram_claimed", true)),
		"renderer surfaces remain exact and cargo-pod stock owns no collision, navigation, or lifecycle authority"
	)

	var rows := audit.get("behavior_rows", []) as Array
	rows.clear()
	(audit.get("errors", PackedStringArray()) as PackedStringArray).append("mutation")
	var detached_allocation := host.get_cargo_pod_visual_allocation_audit()
	_check(
		bool(detached_allocation.get("valid", false))
		and (detached_allocation.get("behavior_rows", []) as Array).size() == 2
		and not (detached_allocation.get("errors", PackedStringArray()) as PackedStringArray).has("mutation"),
		"cargo-pod allocation evidence is deeply detached"
	)

	var allocation_port_pod := host.get_node(
		^"EmberlineSupplyTender/PortCargoPod"
	) as MeshInstance3D
	var allocation_starboard_pod := host.get_node(
		^"EmberlineSupplyTender/StarboardCargoPod"
	) as MeshInstance3D
	var shared_mesh := allocation_port_pod.mesh
	_check(allocation_starboard_pod.mesh == shared_mesh, "both named cargo pods reference the same exact mesh")
	allocation_starboard_pod.mesh = shared_mesh.duplicate() as Mesh
	var identity_red := host.get_cargo_pod_visual_allocation_audit()
	_check(
		not bool(identity_red.get("valid", true))
		and int(identity_red.get("mesh_resource_identity_count", 0)) == 7
		and int(identity_red.get("cargo_pod_mesh_resource_identity_count", 0)) == 2
		and _audit_has_error(identity_red, "cargo_pod_mesh_identity_drift:StarboardCargoPod")
		and _audit_has_error(identity_red, "cargo_pod_mesh_identity_count_drift"),
		"structured red: duplicating one identical pod mesh invalidates retained allocation identity"
	)
	allocation_starboard_pod.mesh = shared_mesh

	allocation_starboard_pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var renderer_red := host.get_cargo_pod_visual_allocation_audit()
	_check(
		not bool(renderer_red.get("valid", true))
		and _audit_has_error(renderer_red, "cargo_pod_renderer_recipe_drift:StarboardCargoPod"),
		"structured red: renderer shadow drift invalidates the exact pod recipe"
	)
	allocation_starboard_pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var rogue_area := Area3D.new()
	rogue_area.name = "RoguePodInteraction"
	var rogue_shape := CollisionShape3D.new()
	rogue_shape.shape = BoxShape3D.new()
	rogue_area.add_child(rogue_shape)
	allocation_starboard_pod.add_child(rogue_area)
	var authority_red := host.get_cargo_pod_visual_allocation_audit()
	_check(
		not bool(authority_red.get("valid", true))
		and int(authority_red.get("collision_object_count", 0)) == 1
		and int(authority_red.get("collision_shape_count", 0)) == 1
		and _audit_has_error(authority_red, "convoy_visuals_gained_collision_or_navigation_authority")
		and _audit_has_error(authority_red, "cargo_pod_visuals_gained_semantic_or_lifecycle_authority"),
		"structured red: a pod interaction collider cannot hide inside visual stock"
	)
	allocation_starboard_pod.remove_child(rogue_area)
	rogue_area.free()
	allocation_starboard_pod.set_meta(&"interaction_owner", true)
	var semantic_red := host.get_cargo_pod_visual_allocation_audit()
	_check(
		not bool(semantic_red.get("valid", true))
		and _audit_has_error(semantic_red, "cargo_pod_visuals_gained_semantic_or_lifecycle_authority"),
		"structured red: semantic metadata cannot turn a shared pod visual into authority"
	)
	allocation_starboard_pod.remove_meta(&"interaction_owner")
	_check(
		bool(host.get_cargo_pod_visual_allocation_audit().get("valid", false))
		and bool(host.audit().get("valid", false)),
		"all renderer, collision, and authority mutations restore to a green host audit"
	)


func _test_remaining_content_and_authority_contract(
		host: CinderConvoyEscortHost,
		audit: Dictionary
	) -> void:
	_check(
		StringName(audit.get("content_class", &"")) == &"NEW"
		and StringName(audit.get("evidence_status", &"")) == &"modern_interpretation"
		and StringName(audit.get("source_confidence", &"")) == &"none"
		and "No source authenticates this convoy" in str(audit.get("content_note", "")),
		"the complete convoy entity, route, timing, and premise are disclosed as NEW modern interpretation"
	)
	var evidence := host.get_evidence_metadata()
	_check(
		not bool(evidence.get("authenticated_original_geometry", true))
		and not bool(evidence.get("historically_supported", true))
		and (evidence.get("modern_interpretations") as PackedStringArray).size() == 3,
		"the host claims no authenticated or historically supported content"
	)

	var entity := host.get_node_or_null(^"EmberlineSupplyTender") as Node3D
	var actual_names := PackedStringArray()
	if entity != null:
		for child in entity.get_children():
			actual_names.append(str(child.name))
	_check(
		entity != null
		and Array(actual_names) == EXPECTED_VISUAL_COMPONENT_NAMES
		and entity.find_children("*", "MeshInstance3D", true, false).size() == 7
		and entity.find_children("*", "CollisionObject3D", true, false).is_empty()
		and entity.find_children("*", "Light3D", true, false).is_empty(),
		"one deterministic seven-part visual-only tender exists without collision or lighting authority"
	)
	if entity != null:
		var hull := entity.get_node_or_null(^"MainHull") as MeshInstance3D
		var port_pod := entity.get_node_or_null(^"PortCargoPod") as MeshInstance3D
		var starboard_pod := entity.get_node_or_null(^"StarboardCargoPod") as MeshInstance3D
		var drive_glow := entity.get_node_or_null(^"DriveGlow") as MeshInstance3D
		_check(
			hull != null and hull.mesh is BoxMesh
			and (hull.mesh as BoxMesh).size.is_equal_approx(Vector3(4.8, 2.0, 9.8))
			and port_pod != null and starboard_pod != null
			and port_pod.position.is_equal_approx(Vector3(-3.35, 0.05, 0.4))
			and starboard_pod.position.is_equal_approx(Vector3(3.35, 0.05, 0.4))
			and drive_glow != null
			and (drive_glow.material_override as StandardMaterial3D).emission_enabled,
			"the original tender's hull, paired cargo pods, and bounded drive emission retain exact authored recipes"
		)

	_check(
		bool(audit.get("entity_movement_authority", false))
		and bool(audit.get("sample_publication_authority", false))
		and bool(audit.get("activity_lifecycle_authority", false))
		and bool(audit.get("uses_caller_physics_delta", false))
		and not bool(audit.get("auto_processes", true))
		and not host.is_processing()
		and not host.is_physics_processing(),
		"the host owns only explicit entity motion, sample publication, and activity lifecycle on caller physics time"
	)
	_check(
		not bool(audit.get("gameplay_authority", true))
		and not bool(audit.get("combat_authority", true))
		and not bool(audit.get("damage_authority", true))
		and not bool(audit.get("grants_rewards", true))
		and not bool(audit.get("cargo_authority", true))
		and not bool(audit.get("player_ship_authority", true))
		and not bool(audit.get("berth_authority", true))
		and not bool(audit.get("hud_authority", true))
		and not bool(audit.get("game_flow_authority", true))
		and not bool(audit.get("save_authority", true))
		and not bool(audit.get("network_authority", true)),
		"combat, damage, rewards, cargo, player ship, berth, HUD, GameFlow, save, and network stay outside the host"
	)

	var detached := host.get_snapshot()
	var detached_route := detached.get("route_positions") as PackedVector3Array
	detached_route[0] = Vector3.ZERO
	(detached.get("activity") as Dictionary)["state_id"] = &"forged"
	(evidence.get("modern_interpretations") as PackedStringArray)[0] = "forged"
	_check(
		(host.get_snapshot().get("route_positions") as PackedVector3Array)[0]
		== ROUTE.get_checkpoint_position(0)
		and host.get_snapshot().get("activity", {}).get("state_id") == &"idle"
		and (host.get_evidence_metadata().get("modern_interpretations") as PackedStringArray)[0]
		!= "forged",
		"presentation, nested activity, route, and evidence collections are detached"
	)


func _test_movement_proximity_and_safe_arrival(
	host: CinderConvoyEscortHost
) -> void:
	var signal_kinds: Array[StringName] = []
	var nested_results: Array[Dictionary] = []
	host.convoy_started.connect(
		func(snapshot: Dictionary) -> void:
			signal_kinds.append(&"started")
			nested_results.append(
				host.advance_physics(
					0.25,
					snapshot.get("entity_position", Vector3.ZERO),
					int(snapshot.get("activity", {}).get("generation", -1))
				)
			)
	)
	host.convoy_safely_arrived.connect(
		func(snapshot: Dictionary) -> void:
			signal_kinds.append(&"arrived")
			nested_results.append(
				host.reset(int(snapshot.get("activity", {}).get("generation", -1)))
			)
	)
	var started := host.start(0)
	var generation := int(started.get("activity", {}).get("generation", -1))
	_check(
		bool(started.get("accepted", false))
		and started.get("reason") == &"started"
		and generation == 1
		and int(started.get("entity_generation", -1)) == 1
		and started.get("entity_position") == ROUTE.get_checkpoint_position(0)
		and started.get("activity", {}).get("state_id") == &"active",
		"start binds the first exact tender incarnation to one fresh escort generation"
	)
	_check(
		nested_results.size() == 1
		and nested_results[0].get("reason") == &"reentrant_call",
		"a started subscriber cannot reenter host movement"
	)

	var start_position := ROUTE.get_checkpoint_position(0)
	var first_leg_direction := (
		ROUTE.get_checkpoint_position(1) - start_position
	).normalized()
	var first_tick := host.advance_physics(0.5, start_position, generation)
	var expected_position := start_position + first_leg_direction * 12.0
	_check(
		bool(first_tick.get("accepted", false))
		and first_tick.get("reason") == &"leg_reached"
		and (first_tick.get("entity_position") as Vector3).is_equal_approx(expected_position)
		and is_equal_approx(float(first_tick.get("movement_distance", -1.0)), 12.0)
		and int(first_tick.get("physics_tick_count", -1)) == 1
		and int(first_tick.get("sample_publication_count", -1)) == 2
		and int(first_tick.get("activity", {}).get("completed_leg_count", -1)) == 1
		and is_equal_approx(float(first_tick.get("activity", {}).get("elapsed_seconds", -1.0)), 0.5),
		"one finite physics tick publishes the start leg and moves the real entity exactly speed times delta"
	)
	var before_process_frames := host.get_snapshot()
	for _frame in 3:
		await process_frame
	_check(
		host.get_snapshot() == before_process_frames,
		"process frames alone cannot move, sample, or time the convoy"
	)
	var before_pause := host.get_snapshot()
	var paused := host.advance_physics(0.0, expected_position, generation)
	_check(
		bool(paused.get("accepted", false))
		and paused.get("reason") == &"no_delta"
		and host.get_snapshot() == before_pause,
		"zero caller delta is an exact state-preserving pause"
	)

	var route_distance := 0.0
	for index in range(1, ROUTE.get_checkpoint_count()):
		route_distance += ROUTE.get_checkpoint_position(index - 1).distance_to(
			ROUTE.get_checkpoint_position(index)
		)
	var step_budget := 80
	while host.get_snapshot().get("activity", {}).get("state_id") == &"active" \
			and step_budget > 0:
		var entity_position := host.get_snapshot().get("entity_position") as Vector3
		host.advance_physics(0.25, entity_position, generation)
		step_budget -= 1
	var completed := host.get_snapshot()
	_check(
		step_budget > 0
		and completed.get("activity", {}).get("state_id") == &"completed"
		and completed.get("activity", {}).get("terminal_result_id") == &"safely_arrived"
		and int(completed.get("activity", {}).get("completed_leg_count", -1)) == 4
		and (completed.get("entity_position") as Vector3).distance_to(
			ROUTE.get_checkpoint_position(3)
		) <= ROUTE.checkpoint_radius
		and bool(completed.get("entity_visible", false)),
		"ordered real movement reaches all four checkpoint volumes and safely arrives with the escort nearby"
	)
	var completed_distance := float(completed.get("movement_distance", -1.0))
	var completed_elapsed := float(completed.get("activity", {}).get("elapsed_seconds", -1.0))
	_check(
		completed_distance > 0.0
		and completed_distance <= route_distance
		and is_equal_approx(
			completed_distance,
			float(completed.get("movement_speed", 0.0)) * completed_elapsed
		),
		"safe arrival spends exactly speed times caller-physics time without exceeding the authored polyline"
	)
	_check(
		signal_kinds == [&"started", &"arrived"]
		and nested_results.size() == 2
		and nested_results[1].get("reason") == &"reentrant_call",
		"post-state arrival emits once and rejects reset reentry"
	)


func _test_loss_reset_and_reentry(host: CinderConvoyEscortHost) -> void:
	var reset_after_arrival := host.reset(host.get_generation())
	var reset_generation := host.get_generation()
	_check(
		bool(reset_after_arrival.get("accepted", false))
		and reset_generation == 2
		and reset_after_arrival.get("activity", {}).get("state_id") == &"idle"
		and reset_after_arrival.get("entity_position") == ROUTE.get_checkpoint_position(0)
		and int(reset_after_arrival.get("physics_tick_count", -1)) == 0
		and int(reset_after_arrival.get("sample_publication_count", -1)) == 0,
		"reset returns the entity and activity to one clean reusable route origin"
	)
	var restarted := host.start(reset_generation)
	var loss_generation := host.get_generation()
	host.advance_physics(
		0.25,
		restarted.get("entity_position") as Vector3,
		loss_generation
	)
	var position_before_loss := host.get_snapshot().get("entity_position") as Vector3
	var lost := host.report_convoy_lost(loss_generation)
	_check(
		bool(lost.get("accepted", false))
		and lost.get("reason") == &"convoy_lost"
		and lost.get("activity", {}).get("state_id") == &"failed"
		and lost.get("activity", {}).get("terminal_result_id") == &"convoy_lost"
		and lost.get("activity", {}).get("terminal_reason") == &"convoy_reported_lost"
		and lost.get("entity_status_id") == &"lost"
		and not bool(lost.get("entity_visible", true))
		and lost.get("entity_position") == position_before_loss,
		"an explicit telemetry loss terminalizes the escort without damage or extra movement"
	)

	var reset_for_grace := host.reset(loss_generation)
	var grace_start := host.start(host.get_generation())
	var grace_generation := host.get_generation()
	var far_offset := Vector3(800.0, 0.0, 0.0)
	var first_far := host.advance_physics(
		1.0,
		(grace_start.get("entity_position") as Vector3) + far_offset,
		grace_generation
	)
	var second_far := host.advance_physics(
		1.0,
		(host.get_snapshot().get("entity_position") as Vector3) + far_offset,
		grace_generation
	)
	var before_grace_failure := host.get_snapshot()
	var grace_failure := host.advance_physics(
		1.0,
		(host.get_snapshot().get("entity_position") as Vector3) + far_offset,
		grace_generation
	)
	_check(
		bool(reset_for_grace.get("accepted", false))
		and bool(first_far.get("accepted", false))
		and bool(second_far.get("accepted", false))
		and is_equal_approx(
			float(second_far.get("activity", {}).get("separation_elapsed_seconds", -1.0)),
			2.0
		)
		and grace_failure.get("reason") == &"convoy_lost"
		and grace_failure.get("activity", {}).get("terminal_reason") == &"escort_separation_exceeded"
		and grace_failure.get("entity_position") == before_grace_failure.get("entity_position")
		and int(grace_failure.get("physics_tick_count", -1))
		== int(before_grace_failure.get("physics_tick_count", -1)),
		"the exact three-second separation grace fails before any movement on its crossing tick"
	)

	host.reset(grace_generation)
	host.start(host.get_generation())
	var reentry_generation := host.get_generation()
	host.advance_physics(
		0.5,
		host.get_snapshot().get("entity_position") as Vector3,
		reentry_generation
	)
	var before_detach := host.get_snapshot()
	var identities := [
		int(before_detach.get("host_instance_id", 0)),
		int(before_detach.get("director_instance_id", 0)),
		int(before_detach.get("activity_instance_id", 0)),
		int(before_detach.get("entity_instance_id", 0)),
	]
	var arrival_counter := {"value": 0}
	host.convoy_safely_arrived.connect(
		func(_snapshot: Dictionary) -> void:
			arrival_counter["value"] = int(arrival_counter.get("value", 0)) + 1
	)
	root.remove_child(host)
	await process_frame
	await process_frame
	var detached_before_call := host.get_snapshot()
	var detached_call := host.advance_physics(
		1.0,
		detached_before_call.get("entity_position") as Vector3,
		reentry_generation
	)
	_check(
		not bool(detached_before_call.get("attached", true))
		and detached_call.get("reason") == &"detached"
		and detached_call.get("entity_position") == before_detach.get("entity_position")
		and detached_call.get("activity", {}).get("elapsed_seconds")
		== before_detach.get("activity", {}).get("elapsed_seconds")
		and int(detached_call.get("sample_publication_count", -1))
		== int(before_detach.get("sample_publication_count", -2)),
		"whole-host detachment rejects physics mutation and preserves exact live state"
	)
	root.add_child(host)
	await process_frame
	await process_frame
	var reentered := host.get_snapshot()
	var identities_after := [
		int(reentered.get("host_instance_id", 0)),
		int(reentered.get("director_instance_id", 0)),
		int(reentered.get("activity_instance_id", 0)),
		int(reentered.get("entity_instance_id", 0)),
	]
	var resumed := host.advance_physics(
		0.5,
		reentered.get("entity_position") as Vector3,
		reentry_generation
	)
	_check(
		bool(reentered.get("attached", false))
		and identities_after == identities
		and host.get_generation() == reentry_generation
		and int(reentered.get("entity_generation", -1))
		== int(before_detach.get("entity_generation", -2))
		and bool(resumed.get("accepted", false))
		and float(resumed.get("movement_distance", 0.0))
		> float(before_detach.get("movement_distance", 0.0))
		and int(arrival_counter.get("value", -1)) == 0,
		"tree re-entry preserves host, director, activity, entity, and generation identity without replay, then resumes motion"
	)

	var before_invalid := host.get_snapshot()
	var invalid_delta := host.advance_physics(
		NAN,
		before_invalid.get("entity_position") as Vector3,
		reentry_generation
	)
	var invalid_position := host.advance_physics(
		0.25,
		Vector3.INF,
		reentry_generation
	)
	var overflow := host.advance_physics(
		1.0e308,
		before_invalid.get("entity_position") as Vector3,
		reentry_generation
	)
	var stale := host.advance_physics(
		0.25,
		before_invalid.get("entity_position") as Vector3,
		reentry_generation - 1
	)
	_check(
		invalid_delta.get("reason") == &"invalid_delta"
		and invalid_position.get("reason") == &"invalid_escort_position"
		and overflow.get("reason") == &"movement_overflow"
		and stale.get("reason") == &"stale_generation"
		and host.get_snapshot() == before_invalid,
		"malformed, non-finite, overflowing, and stale caller physics inputs fail closed"
	)
	_check(bool(host.audit().get("valid", false)), "the reused host retains a clean deep audit")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _audit_has_error(audit: Dictionary, expected: String) -> bool:
	return (audit.get("errors", PackedStringArray()) as PackedStringArray).has(expected)


func _finish() -> void:
	print("CINDER_CONVOY_ESCORT_HOST_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_CONVOY_ESCORT_HOST_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_CONVOY_ESCORT_HOST_TEST_FAILURE: ", failure)
	quit(1)
