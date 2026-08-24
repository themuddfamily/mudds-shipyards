class_name CinderConvoyEscortHost
extends Node3D

## Production-neutral host for one original Cinder Reach convoy entity.
##
## The route resource owns the ordered positions, ConvoyEscortActivity owns the
## escort lifecycle/proximity clocks, and this host owns only deterministic
## entity motion plus publication of one caller-physics sample stream. All
## authored content is NEW/modern interpretation and is intentionally isolated
## from GameFlow, ships, combat, cargo, rewards, persistence, and networking.

signal convoy_started(snapshot: Dictionary)
signal convoy_advanced(snapshot: Dictionary)
signal convoy_safely_arrived(snapshot: Dictionary)
signal convoy_failed(snapshot: Dictionary)
signal convoy_reset(snapshot: Dictionary)
signal presentation_changed(snapshot: Dictionary)

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const SOURCE_CONFIDENCE: StringName = &"none"
const CONVOY_ID: StringName = &"emberline_supply_tender"
const ROUTE: ActivityDefinition = preload(
	"res://assets/activities/cinder_reach_emberline_convoy_route.tres"
)

const DEFAULT_MOVEMENT_SPEED := 24.0
const DEFAULT_ESCORT_PROXIMITY_RADIUS := 42.0
const DEFAULT_MAXIMUM_SEPARATION_SECONDS := 3.0
const DEFAULT_TIMEOUT_SECONDS := 90.0
const VISUAL_COMPONENT_NAMES := [
	"MainHull",
	"ForwardKeel",
	"PortCargoPod",
	"StarboardCargoPod",
	"DriveBlock",
	"DriveGlow",
	"NavigationBeacon",
]
const CARGO_POD_NAMES := [&"PortCargoPod", &"StarboardCargoPod"]
const CARGO_POD_POSITIONS := [
	Vector3(-3.35, 0.05, 0.4),
	Vector3(3.35, 0.05, 0.4),
]
const CARGO_POD_SIZE := Vector3(2.15, 2.5, 6.4)
const MAXIMUM_PRESENTATION_POD_SPREAD := 2.2
const COMPLETED_PRESENTATION_POD_TUCK := -0.75
const CRITICAL_SEPARATION_FRACTION := 0.75
const BASELINE_VISUAL_NODE_COUNT := 7
const RETAINED_VISUAL_RENDERER_NODE_COUNT := 6
const BASELINE_VISUAL_MESH_RESOURCE_COUNT := 7
const RETAINED_VISUAL_MESH_RESOURCE_COUNT := 6
const VISUAL_MATERIAL_RESOURCE_COUNT := 5
const BASELINE_STRUCTURAL_SURFACE_SUBMISSION_COUNT := 7
const CONTENT_NOTE := (
	"The Emberline supply tender, its appearance, route, movement values, and "
	+ "escort premise are NEW project-original modern interpretation. No source "
	+ "authenticates this convoy, and the host grants no reward, cargo, combat, "
	+ "player-ship, berth, HUD, GameFlow, save, or network authority."
)

var _movement_speed: float
var _escort_proximity_radius: float
var _maximum_separation_seconds: float
var _timeout_seconds: float

var _director: ActivityDirector
var _activity: ConvoyEscortActivity
var _convoy_entity: Node3D
var _cargo_pod_mesh: BoxMesh
var _cargo_pod_multimesh: MultiMesh
var _visual_feedback_snapshot: Dictionary = {}
var _built := false
var _attached := false
var _entity_generation := 0
var _entity_status := ConvoyEscortActivity.EntityStatus.ACTIVE
var _next_route_index := 0
var _movement_distance := 0.0
var _physics_tick_count := 0
var _sample_publication_count := 0
var _has_escort_sample := false
var _last_escort_position := Vector3.ZERO
var _last_entity_position := Vector3.ZERO
var _mutation_active := false
var _signal_dispatch_active := false
var _terminal_signal_generation := -1


func _init(
	configured_movement_speed: float = DEFAULT_MOVEMENT_SPEED,
	configured_escort_proximity_radius: float = DEFAULT_ESCORT_PROXIMITY_RADIUS,
	configured_maximum_separation_seconds: float = DEFAULT_MAXIMUM_SEPARATION_SECONDS,
	configured_timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
) -> void:
	_movement_speed = configured_movement_speed
	_escort_proximity_radius = configured_escort_proximity_radius
	_maximum_separation_seconds = configured_maximum_separation_seconds
	_timeout_seconds = configured_timeout_seconds
	set_process(false)
	set_physics_process(false)


func _enter_tree() -> void:
	_attached = true


func _exit_tree() -> void:
	_attached = false


func _ready() -> void:
	if not _built:
		_build_content()


func start(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _common_mutation_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not get_configuration_errors().is_empty():
		return _finish(false, &"invalid_configuration")
	if _activity.get_state() != ConvoyEscortActivity.State.IDLE:
		return _finish(false, &"reset_required")
	_restore_missing_convoy_entity()

	var candidate_entity_generation := _entity_generation + 1
	var started := _activity.start(
		CONVOY_ID,
		candidate_entity_generation,
		expected_generation
	)
	if not bool(started.get("accepted", false)):
		return _finish(
			false,
			StringName(started.get("reason", &"activity_rejected"))
		)
	_entity_generation = candidate_entity_generation
	_entity_status = ConvoyEscortActivity.EntityStatus.ACTIVE
	_next_route_index = 0
	_movement_distance = 0.0
	_physics_tick_count = 0
	_sample_publication_count = 0
	_has_escort_sample = false
	_last_escort_position = Vector3.ZERO
	_terminal_signal_generation = -1
	_convoy_entity.visible = true
	_set_entity_position(ROUTE.get_checkpoint_position(0))
	_orient_toward_route_index(1)
	var result := _finish(true, &"started")
	_emit_snapshot(convoy_started)
	_emit_snapshot(presentation_changed)
	return result


## Moves and samples the tender from one exact caller physics delta. The escort
## position is route-local observation data only; it is never polled or moved.
func advance_physics(
	delta: float,
	escort_position: Vector3,
	expected_generation: int
) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not _has_live_convoy_entity():
		return _finish_actor_loss(expected_generation)
	if not is_finite(delta) or delta < 0.0:
		return _finish(false, &"invalid_delta")
	if not WorldLocationDefinition._is_finite_vector(escort_position):
		return _finish(false, &"invalid_escort_position")
	if is_zero_approx(delta):
		return _finish(true, &"no_delta")
	var candidate_travel := _movement_speed * delta
	var candidate_total_distance := _movement_distance + candidate_travel
	if not is_finite(candidate_travel) or not is_finite(candidate_total_distance):
		return _finish(false, &"movement_overflow")

	_has_escort_sample = true
	_last_escort_position = escort_position
	var result_reason: StringName = &"advanced"
	var opening_sample := _publish_sample(
		escort_position,
		ConvoyEscortActivity.EntityStatus.ACTIVE
	)
	if not bool(opening_sample.get("accepted", false)):
		return _finish(false, &"sample_publication_rejected")
	result_reason = _prefer_progress_reason(
		result_reason,
		StringName(opening_sample.get("reason", &"sample_recorded"))
	)
	if _activity.get_state() != ConvoyEscortActivity.State.ACTIVE:
		var opening_result := _finish(true, result_reason)
		_emit_terminal_once()
		_emit_snapshot(presentation_changed)
		return opening_result

	var clock := _activity.advance_physics(delta, expected_generation)
	if not bool(clock.get("accepted", false)):
		return _finish(
			false,
			StringName(clock.get("reason", &"activity_clock_rejected"))
		)
	if _activity.get_state() == ConvoyEscortActivity.State.FAILED:
		if int(clock.get("terminal_result", ConvoyEscortActivity.TerminalResult.NONE)) \
				== ConvoyEscortActivity.TerminalResult.CONVOY_LOST:
			_entity_status = ConvoyEscortActivity.EntityStatus.LOST
			_convoy_entity.visible = false
		var clock_result := _finish(
			true,
			StringName(clock.get("reason", &"failed"))
		)
		_emit_terminal_once()
		_emit_snapshot(presentation_changed)
		return clock_result

	_physics_tick_count += 1
	var remaining := candidate_travel
	var moved_this_tick := false
	while remaining > 0.0 and _next_route_index < ROUTE.get_checkpoint_count():
		var target := ROUTE.get_checkpoint_position(_next_route_index)
		var distance_to_target := _convoy_entity.position.distance_to(target)
		if distance_to_target <= 0.00001:
			var at_target := _publish_sample(
				escort_position,
				ConvoyEscortActivity.EntityStatus.ACTIVE
			)
			if not bool(at_target.get("accepted", false)):
				return _finish(false, &"sample_publication_rejected")
			result_reason = _prefer_progress_reason(
				result_reason,
				StringName(at_target.get("reason", &"sample_recorded"))
			)
			_sync_next_route_index()
			if _activity.get_state() != ConvoyEscortActivity.State.ACTIVE:
				break
			continue
		var step := minf(remaining, distance_to_target)
		var direction := (target - _convoy_entity.position) / distance_to_target
		_set_entity_position(_convoy_entity.position + direction * step)
		_movement_distance += step
		remaining -= step
		moved_this_tick = true
		_orient_toward_route_index(_next_route_index)
		if step >= distance_to_target - 0.00001:
			_set_entity_position(target)
			var reached := _publish_sample(
				escort_position,
				ConvoyEscortActivity.EntityStatus.ACTIVE
			)
			if not bool(reached.get("accepted", false)):
				return _finish(false, &"sample_publication_rejected")
			result_reason = _prefer_progress_reason(
				result_reason,
				StringName(reached.get("reason", &"sample_recorded"))
			)
			_sync_next_route_index()
			if _activity.get_state() != ConvoyEscortActivity.State.ACTIVE:
				break

	if moved_this_tick and _activity.get_state() == ConvoyEscortActivity.State.ACTIVE:
		var final_sample := _publish_sample(
			escort_position,
			ConvoyEscortActivity.EntityStatus.ACTIVE
		)
		if not bool(final_sample.get("accepted", false)):
			return _finish(false, &"sample_publication_rejected")
		result_reason = _prefer_progress_reason(
			result_reason,
			StringName(final_sample.get("reason", &"sample_recorded"))
		)
		_sync_next_route_index()

	var result := _finish(true, result_reason)
	_emit_snapshot(convoy_advanced)
	_emit_terminal_once()
	_emit_snapshot(presentation_changed)
	return result


## A production caller may report telemetry loss. This is not damage authority:
## no health, projectile, combat, or destruction state exists in this host.
func report_convoy_lost(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _running_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	if not _has_live_convoy_entity():
		return _finish_actor_loss(expected_generation)
	var escort_position := (
		_last_escort_position if _has_escort_sample else _convoy_entity.position
	)
	var lost := _activity.submit_entity_sample(
		CONVOY_ID,
		_entity_generation,
		_convoy_entity.position,
		escort_position,
		ConvoyEscortActivity.EntityStatus.LOST,
		expected_generation
	)
	if not bool(lost.get("accepted", false)):
		return _finish(false, &"sample_publication_rejected")
	_sample_publication_count += 1
	_entity_status = ConvoyEscortActivity.EntityStatus.LOST
	_convoy_entity.visible = false
	var result := _finish(true, &"convoy_lost")
	_emit_terminal_once()
	_emit_snapshot(presentation_changed)
	return result


func reset(expected_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	var rejection := _common_mutation_rejection(expected_generation)
	if not rejection.is_empty():
		return _finish(false, rejection)
	_restore_missing_convoy_entity()
	var reset_result := _activity.reset(expected_generation)
	if not bool(reset_result.get("accepted", false)):
		return _finish(
			false,
			StringName(reset_result.get("reason", &"activity_reset_rejected"))
		)
	_entity_status = ConvoyEscortActivity.EntityStatus.ACTIVE
	_next_route_index = 0
	_movement_distance = 0.0
	_physics_tick_count = 0
	_sample_publication_count = 0
	_has_escort_sample = false
	_last_escort_position = Vector3.ZERO
	_terminal_signal_generation = -1
	_convoy_entity.visible = true
	_set_entity_position(ROUTE.get_checkpoint_position(0))
	_orient_toward_route_index(1)
	var result := _finish(true, &"reset")
	_emit_snapshot(convoy_reset)
	_emit_snapshot(presentation_changed)
	return result


func get_generation() -> int:
	return _activity.get_generation() if is_instance_valid(_activity) else 0


## Applies only the terminal static formation recipe restored by persistence.
## The live activity must still be the pristine generation-zero IDLE authority;
## no entity position, movement ledger, sample, status, clock, or generation is
## adopted from the receipt. Starting or resetting the host reapplies its live
## authority snapshot through the ordinary mutation path.
func apply_restored_safe_arrival_presentation(arrival: Dictionary) -> Dictionary:
	if not _built or not is_instance_valid(_activity) or not is_instance_valid(_convoy_entity):
		return {"accepted": false, "reason": &"not_ready"}
	var live := _activity.get_snapshot()
	if int(live.get("state", -1)) != ConvoyEscortActivity.State.IDLE \
			or int(live.get("generation", -1)) != 0:
		return {"accepted": false, "reason": &"pristine_idle_presentation_required"}
	if StringName(arrival.get("activity_id", &"")) != ROUTE.activity_id \
			or StringName(arrival.get("convoy_id", &"")) != CONVOY_ID \
			or StringName(arrival.get("terminal_result", &"")) != &"safely_arrived" \
			or int(arrival.get("leg_count", 0)) != ROUTE.get_checkpoint_count():
		return {"accepted": false, "reason": &"invalid_safe_arrival_presentation"}
	_apply_visual_feedback({"state_id": &"completed", "generation": 0})
	return {
		"accepted": true,
		"reason": &"safe_arrival_presentation_restored",
		"visual_feedback": _visual_feedback_snapshot.duplicate(true),
		"activity_authority_restored": false,
		"movement_authority_restored": false,
		"combat_authority_restored": false,
		"reward_authority_restored": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	var activity_snapshot := (
		_activity.get_snapshot() if is_instance_valid(_activity) else {}
	)
	var entity_position := (
		_convoy_entity.position if is_instance_valid(_convoy_entity) else Vector3.ZERO
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"source_confidence": SOURCE_CONFIDENCE,
		"content_note": CONTENT_NOTE,
		"route_resource_path": ROUTE.resource_path,
		"activity_id": ROUTE.activity_id,
		"display_name": ROUTE.display_name,
		"route_positions": ROUTE.checkpoint_positions.duplicate(),
		"route_leg_count": ROUTE.get_checkpoint_count(),
		"route_arrival_radius": ROUTE.checkpoint_radius,
		"host_instance_id": get_instance_id(),
		"director_instance_id": _director.get_instance_id() if is_instance_valid(_director) else 0,
		"activity_instance_id": _activity.get_instance_id() if is_instance_valid(_activity) else 0,
		"entity_instance_id": _convoy_entity.get_instance_id() if is_instance_valid(_convoy_entity) else 0,
		"convoy_id": CONVOY_ID,
		"entity_generation": _entity_generation,
		"entity_status": _entity_status,
		"entity_status_id": ConvoyEscortActivity._entity_status_id(_entity_status),
		"entity_position": entity_position,
		"entity_visible": _convoy_entity.visible if is_instance_valid(_convoy_entity) else false,
		"entity_available": _has_live_convoy_entity(),
		"last_entity_position": _last_entity_position,
		"next_route_index": _next_route_index,
		"movement_speed": _movement_speed,
		"movement_distance": _movement_distance,
		"physics_tick_count": _physics_tick_count,
		"sample_publication_count": _sample_publication_count,
		"has_escort_sample": _has_escort_sample,
		"last_escort_position": _last_escort_position,
		"attached": _attached and is_inside_tree(),
		"activity": activity_snapshot.duplicate(true),
		"visual_feedback": _visual_feedback_snapshot.duplicate(true),
		"uses_caller_physics_delta": true,
		"auto_processes": false,
		"owns_route_definition": true,
		"owns_checkpoint_geometry": false,
		"entity_movement_authority": true,
		"sample_publication_authority": true,
		"activity_lifecycle_authority": true,
		"gameplay_authority": false,
		"combat_authority": false,
		"damage_authority": false,
		"grants_rewards": false,
		"cargo_authority": false,
		"player_ship_authority": false,
		"berth_authority": false,
		"hud_authority": false,
		"game_flow_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func get_evidence_metadata() -> Dictionary:
	return {
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"source_confidence": SOURCE_CONFIDENCE,
		"authenticated_original_geometry": false,
		"historically_supported": false,
		"content_note": CONTENT_NOTE,
		"modern_interpretations": PackedStringArray([
			"the Emberline tender identity and visual design",
			"the four-position Cinder Reach approach route",
			"the movement, escort-radius, grace, and timeout values",
		]),
	}.duplicate(true)


## Renderer-independent allocation evidence for the exact paired cargo-pod
## visual family. One MultiMesh renderer retains both named semantic anchors,
## exact authored transforms, material, bounds, layers, and shadow recipe. The
## host's movement and activity lifecycle authority remains outside the family.
func get_cargo_pod_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var all_mesh_ids: Dictionary = {}
	var all_material_ids: Dictionary = {}
	var visual_renderer_node_count := 0
	var drawn_copy_count := 0
	var structural_surface_submissions := 0
	var cargo_pod_child_count := 0
	var cargo_pod_script_count := 0
	var cargo_pod_metadata_entry_count := 0
	var cargo_pod_group_count := 0
	var cargo_pod_processing_count := 0
	var behavior_rows: Array[Dictionary] = []
	var collision_object_count := 0
	var collision_shape_count := 0
	var navigation_region_count := 0

	if not is_instance_valid(_convoy_entity):
		errors.append("convoy_visual_root_unavailable")
	else:
		collision_object_count = _convoy_entity.find_children(
			"*", "CollisionObject3D", true, false
		).size()
		collision_shape_count = _convoy_entity.find_children(
			"*", "CollisionShape3D", true, false
		).size()
		navigation_region_count = _convoy_entity.find_children(
			"*", "NavigationRegion3D", true, false
		).size()
		for raw_child in _convoy_entity.get_children():
			var mesh_instance := raw_child as MeshInstance3D
			if mesh_instance != null:
				visual_renderer_node_count += 1
				drawn_copy_count += 1
				var mesh := mesh_instance.mesh
				if mesh == null:
					errors.append("convoy_visual_mesh_missing:%s" % String(mesh_instance.name))
					continue
				all_mesh_ids[mesh.get_instance_id()] = true
				structural_surface_submissions += mesh.get_surface_count()
				if mesh_instance.material_override != null:
					all_material_ids[mesh_instance.material_override.get_instance_id()] = true
				continue
			var batch := raw_child as MultiMeshInstance3D
			if batch == null:
				continue
			visual_renderer_node_count += 1
			if batch.multimesh == null or batch.multimesh.mesh == null:
				errors.append("convoy_visual_mesh_missing:%s" % String(batch.name))
				continue
			drawn_copy_count += batch.multimesh.instance_count
			all_mesh_ids[batch.multimesh.mesh.get_instance_id()] = true
			structural_surface_submissions += (
				batch.multimesh.mesh.get_surface_count() * batch.multimesh.instance_count
			)
			if batch.material_override != null:
				all_material_ids[batch.material_override.get_instance_id()] = true

		var batch := _convoy_entity.get_node_or_null(^"PortCargoPod") as MultiMeshInstance3D
		var starboard_anchor := _convoy_entity.get_node_or_null(^"StarboardCargoPod") as Node3D
		var pod_spread := float(_visual_feedback_snapshot.get("pod_spread", 0.0))
		if batch == null:
			errors.append("cargo_pod_batch_missing")
		elif batch.multimesh == null:
			errors.append("cargo_pod_multimesh_missing")
		else:
			var pod_mesh := batch.multimesh.mesh as BoxMesh
			var pod_material := batch.material_override as StandardMaterial3D
			if batch.multimesh != _cargo_pod_multimesh:
				errors.append("cargo_pod_multimesh_identity_drift")
			if batch.multimesh.transform_format != MultiMesh.TRANSFORM_3D \
					or batch.multimesh.instance_count != CARGO_POD_NAMES.size() \
					or batch.multimesh.visible_instance_count != -1:
				errors.append("cargo_pod_multimesh_recipe_drift")
			var expected_batch_aabb := _cargo_pod_presentation_aabb()
			if not batch.multimesh.custom_aabb.is_equal_approx(expected_batch_aabb):
				errors.append("cargo_pod_culling_bounds_drift")
			var expected_transforms := _cargo_pod_presentation_transforms(pod_spread)
			if batch.multimesh.buffer != _encode_multimesh_transforms(expected_transforms):
				errors.append("cargo_pod_instance_transform_buffer_drift")
			if (
				not batch.position.is_equal_approx(CARGO_POD_POSITIONS[0])
				or not batch.rotation.is_equal_approx(Vector3.ZERO)
				or not batch.scale.is_equal_approx(Vector3.ONE)
				or not batch.visible
				or batch.layers != 1
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				or batch.material_overlay != null
				or not is_zero_approx(batch.transparency)
				or not is_zero_approx(batch.extra_cull_margin)
				or batch.custom_aabb != AABB()
			):
				errors.append("cargo_pod_renderer_recipe_drift:PortCargoPod")
			cargo_pod_child_count += batch.get_child_count()
			cargo_pod_metadata_entry_count += batch.get_meta_list().size()
			cargo_pod_group_count += batch.get_groups().size()
			if batch.get_script() != null:
				cargo_pod_script_count += 1
			if batch.is_processing() or batch.is_physics_processing():
				cargo_pod_processing_count += 1
			if pod_mesh == null:
				errors.append("cargo_pod_mesh_type_drift")
			else:
				if pod_mesh != _cargo_pod_mesh:
					errors.append("cargo_pod_mesh_identity_drift")
				if (
					not pod_mesh.size.is_equal_approx(CARGO_POD_SIZE)
					or pod_mesh.material != null
					or pod_mesh.get_surface_count() != 1
					or not pod_mesh.get_aabb().is_equal_approx(
						AABB(-CARGO_POD_SIZE * 0.5, CARGO_POD_SIZE)
					)
				):
					errors.append("cargo_pod_mesh_recipe_drift")
			if pod_material == null:
				errors.append("cargo_pod_material_missing")
			else:
				if (
					pod_material.resource_name != "EmberlineCargo"
					or pod_material.albedo_color != Color("8b6d3f")
					or not is_equal_approx(pod_material.metallic, 0.42)
					or not is_equal_approx(pod_material.roughness, 0.52)
					or pod_material.emission_enabled
				):
					errors.append("cargo_pod_material_recipe_drift")
		if starboard_anchor == null or starboard_anchor is GeometryInstance3D:
			errors.append("cargo_pod_semantic_anchor_drift:StarboardCargoPod")
		else:
			cargo_pod_child_count += starboard_anchor.get_child_count()
			cargo_pod_metadata_entry_count += starboard_anchor.get_meta_list().size()
			cargo_pod_group_count += starboard_anchor.get_groups().size()
			if starboard_anchor.get_script() != null:
				cargo_pod_script_count += 1
			if starboard_anchor.is_processing() or starboard_anchor.is_physics_processing():
				cargo_pod_processing_count += 1
			if (
				not starboard_anchor.position.is_equal_approx(
					CARGO_POD_POSITIONS[1] + Vector3(pod_spread, 0.0, 0.0)
				)
				or not starboard_anchor.rotation.is_equal_approx(Vector3.ZERO)
				or not starboard_anchor.scale.is_equal_approx(Vector3.ONE)
				or not starboard_anchor.visible
			):
				errors.append("cargo_pod_semantic_anchor_drift:StarboardCargoPod")

		for pod_index in CARGO_POD_NAMES.size():
			var pod_name: StringName = CARGO_POD_NAMES[pod_index]
			behavior_rows.append({
				"name": String(pod_name),
				"position": [
					CARGO_POD_POSITIONS[pod_index].x,
					CARGO_POD_POSITIONS[pod_index].y,
					CARGO_POD_POSITIONS[pod_index].z,
				],
				"rotation": [0.0, 0.0, 0.0],
				"scale": [1.0, 1.0, 1.0],
				"size": [CARGO_POD_SIZE.x, CARGO_POD_SIZE.y, CARGO_POD_SIZE.z],
				"material": "EmberlineCargo",
			})

	if visual_renderer_node_count != RETAINED_VISUAL_RENDERER_NODE_COUNT:
		errors.append("convoy_visual_node_count_drift")
	if drawn_copy_count != BASELINE_VISUAL_NODE_COUNT:
		errors.append("convoy_visual_drawn_copy_count_drift")
	if all_mesh_ids.size() != RETAINED_VISUAL_MESH_RESOURCE_COUNT:
		errors.append("convoy_visual_mesh_resource_count_drift")
	if all_material_ids.size() != VISUAL_MATERIAL_RESOURCE_COUNT:
		errors.append("convoy_visual_material_resource_count_drift")
	if structural_surface_submissions != BASELINE_STRUCTURAL_SURFACE_SUBMISSION_COUNT:
		errors.append("convoy_visual_structural_submission_count_drift")
	if collision_object_count != 0 or collision_shape_count != 0 or navigation_region_count != 0:
		errors.append("convoy_visuals_gained_collision_or_navigation_authority")
	if (
		cargo_pod_child_count != 0
		or cargo_pod_script_count != 0
		or cargo_pod_metadata_entry_count != 0
		or cargo_pod_group_count != 0
		or cargo_pod_processing_count != 0
	):
		errors.append("cargo_pod_visuals_gained_semantic_or_lifecycle_authority")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"cinder_convoy_escort_host_cargo_pod_visuals",
		"visual_node_count": visual_renderer_node_count,
		"baseline_visual_node_count": BASELINE_VISUAL_NODE_COUNT,
		"visual_node_delta": visual_renderer_node_count - BASELINE_VISUAL_NODE_COUNT,
		"drawn_copy_count": drawn_copy_count,
		"baseline_drawn_copy_count": BASELINE_VISUAL_NODE_COUNT,
		"drawn_copy_delta": drawn_copy_count - BASELINE_VISUAL_NODE_COUNT,
		"mesh_resource_identity_count": all_mesh_ids.size(),
		"baseline_mesh_resource_identity_count": BASELINE_VISUAL_MESH_RESOURCE_COUNT,
		"mesh_resource_identity_delta": (
			all_mesh_ids.size() - BASELINE_VISUAL_MESH_RESOURCE_COUNT
		),
		"cargo_pod_copy_count": CARGO_POD_NAMES.size(),
		"cargo_pod_mesh_resource_identity_count": 1 if is_instance_valid(_cargo_pod_mesh) else 0,
		"baseline_cargo_pod_mesh_resource_identity_count": CARGO_POD_NAMES.size(),
		"cargo_pod_mesh_resource_identity_delta": (
			(1 if is_instance_valid(_cargo_pod_mesh) else 0) - CARGO_POD_NAMES.size()
		),
		"material_resource_identity_count": all_material_ids.size(),
		"baseline_material_resource_identity_count": VISUAL_MATERIAL_RESOURCE_COUNT,
		"material_resource_identity_delta": (
			all_material_ids.size() - VISUAL_MATERIAL_RESOURCE_COUNT
		),
		"structural_surface_submission_count": structural_surface_submissions,
		"baseline_structural_surface_submission_count": (
			BASELINE_STRUCTURAL_SURFACE_SUBMISSION_COUNT
		),
		"structural_surface_submission_delta": (
			structural_surface_submissions - BASELINE_STRUCTURAL_SURFACE_SUBMISSION_COUNT
		),
		"collision_object_count": collision_object_count,
		"collision_shape_count": collision_shape_count,
		"navigation_region_count": navigation_region_count,
		"cargo_pod_child_count": cargo_pod_child_count,
		"cargo_pod_script_count": cargo_pod_script_count,
		"cargo_pod_metadata_entry_count": cargo_pod_metadata_entry_count,
		"cargo_pod_group_count": cargo_pod_group_count,
		"cargo_pod_processing_count": cargo_pod_processing_count,
		"batched": true,
		"driver_draw_call_claimed": false,
		"frame_time_claimed": false,
		"vram_claimed": false,
		"behavior_rows": behavior_rows,
	}.duplicate(true)


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built or not is_instance_valid(_director) or not is_instance_valid(_activity):
		errors.append("host content is not built")
	elif not _activity.is_configuration_valid():
		errors.append("composed convoy activity is invalid")
	if not ROUTE.is_definition_valid() or ROUTE.get_checkpoint_count() != 4:
		errors.append("the exact four-leg route definition is invalid")
	if not is_finite(_movement_speed) or _movement_speed <= 0.0:
		errors.append("movement_speed must be finite and greater than zero")
	return errors


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	var cargo_pod_allocation := get_cargo_pod_visual_allocation_audit()
	if not bool(cargo_pod_allocation.get("valid", false)):
		for allocation_error in cargo_pod_allocation.get("errors", PackedStringArray()):
			errors.append("cargo pod allocation: %s" % String(allocation_error))
	if not WorldLocationDefinition._is_finite_vector(
		_convoy_entity.position if is_instance_valid(_convoy_entity) else Vector3.INF
	):
		errors.append("convoy entity position is non-finite")
	if not is_finite(_movement_distance) or _movement_distance < 0.0:
		errors.append("movement distance is invalid")
	if _physics_tick_count < 0 or _sample_publication_count < 0:
		errors.append("host counters cannot be negative")
	if is_instance_valid(_activity) and not bool(_activity.audit().get("valid", false)):
		errors.append("composed convoy activity audit failed")
	if is_instance_valid(_activity) and _activity.get_generation() != get_generation():
		errors.append("host and activity generations diverged")
	if not is_instance_valid(_convoy_entity):
		errors.append("the one convoy entity is missing")
	else:
		var child_names := PackedStringArray()
		for child in _convoy_entity.get_children():
			child_names.append(str(child.name))
		if Array(child_names) != VISUAL_COMPONENT_NAMES:
			errors.append("convoy visual component roster drifted")
		if not _convoy_entity.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("visual-only convoy content gained collision authority")
		if (
			_convoy_entity.find_children("*", "MeshInstance3D", true, false).size() != 5
			or _convoy_entity.find_children(
				"*", "MultiMeshInstance3D", true, false
			).size() != 1
		):
			errors.append("convoy visual mesh count drifted")
	var report := get_snapshot()
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	report["visual_component_names"] = PackedStringArray(VISUAL_COMPONENT_NAMES)
	report["visual_mesh_count"] = (
		_convoy_entity.find_children("*", "MeshInstance3D", true, false).size()
		+ _convoy_entity.find_children("*", "MultiMeshInstance3D", true, false).size()
		if is_instance_valid(_convoy_entity) else 0
	)
	report["entity_count"] = 1 if is_instance_valid(_convoy_entity) else 0
	report["cargo_pod_visual_allocation"] = cargo_pod_allocation
	report["definition_snapshot_policy"] = &"deep_copy_registered_with_private_director"
	return report.duplicate(true)


func _build_content() -> void:
	name = "CinderConvoyEscortHost"
	set_meta(&"content_class", CONTENT_CLASS)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"source_confidence", SOURCE_CONFIDENCE)
	_director = ActivityDirector.new()
	_director.name = "ConvoyActivityDirector"
	add_child(_director)
	var route_snapshot := ROUTE.duplicate(true) as ActivityDefinition
	_director.register_definition(route_snapshot)
	_activity = ConvoyEscortActivity.new(
		_director,
		ROUTE.activity_id,
		_escort_proximity_radius,
		_maximum_separation_seconds,
		_timeout_seconds
	)
	_activity.name = "ConvoyEscortActivity"
	add_child(_activity)
	_restore_missing_convoy_entity()
	_set_entity_position(ROUTE.get_checkpoint_position(0))
	_orient_toward_route_index(1)
	_built = true
	_apply_visual_feedback()


func _build_entity_visuals() -> void:
	var hull_material := _material("EmberlineHull", Color("6b7e86"), 0.72, 0.34)
	var cargo_material := _material("EmberlineCargo", Color("8b6d3f"), 0.42, 0.52)
	var dark_material := _material("EmberlineMachinery", Color("1c2930"), 0.82, 0.28)
	var glow_material := _material(
		"EmberlineDriveGlow", Color("4edfe6"), 0.15, 0.25, Color("4edfe6")
	)
	var beacon_material := _material(
		"EmberlineBeacon", Color("f4a641"), 0.1, 0.3, Color("f4a641")
	)
	_box("MainHull", Vector3(4.8, 2.0, 9.8), Vector3.ZERO, hull_material)
	_box("ForwardKeel", Vector3(3.4, 1.25, 2.2), Vector3(0.0, -0.18, -5.45), hull_material)
	_cargo_pod_mesh = BoxMesh.new()
	_cargo_pod_mesh.size = CARGO_POD_SIZE
	_cargo_pod_multimesh = MultiMesh.new()
	_cargo_pod_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_cargo_pod_multimesh.mesh = _cargo_pod_mesh
	_cargo_pod_multimesh.instance_count = CARGO_POD_NAMES.size()
	_cargo_pod_multimesh.visible_instance_count = -1
	var cargo_pod_transforms := _cargo_pod_presentation_transforms(0.0)
	_cargo_pod_multimesh.buffer = _encode_multimesh_transforms(cargo_pod_transforms)
	_cargo_pod_multimesh.custom_aabb = _cargo_pod_presentation_aabb()
	var cargo_pod_batch := MultiMeshInstance3D.new()
	cargo_pod_batch.name = "PortCargoPod"
	cargo_pod_batch.multimesh = _cargo_pod_multimesh
	cargo_pod_batch.material_override = cargo_material
	cargo_pod_batch.position = CARGO_POD_POSITIONS[0]
	cargo_pod_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_convoy_entity.add_child(cargo_pod_batch)
	var starboard_cargo_pod := Node3D.new()
	starboard_cargo_pod.name = "StarboardCargoPod"
	starboard_cargo_pod.position = CARGO_POD_POSITIONS[1]
	_convoy_entity.add_child(starboard_cargo_pod)
	_box("DriveBlock", Vector3(3.8, 1.5, 1.2), Vector3(0.0, -0.05, 5.25), dark_material)
	_box("DriveGlow", Vector3(3.0, 0.72, 0.16), Vector3(0.0, -0.05, 5.92), glow_material)
	_box("NavigationBeacon", Vector3(0.42, 0.34, 0.42), Vector3(0.0, 1.2, -1.2), beacon_material)


func _apply_visual_feedback(activity_override: Dictionary = {}) -> void:
	if not _built or not is_instance_valid(_activity) or not is_instance_valid(_convoy_entity):
		return
	var activity_snapshot := (
		activity_override.duplicate(true)
		if not activity_override.is_empty()
		else _activity.get_snapshot()
	)
	var activity_state := StringName(activity_snapshot.get("state_id", &"idle"))
	var geometry_state: StringName = &"idle"
	var separation_fraction := 0.0
	var pod_spread := 0.0
	var drive_scale := Vector3.ONE
	var beacon_scale := Vector3.ONE
	var engine_state: StringName = &"standby"
	var formation_state: StringName = &"open"
	if activity_state == &"active":
		geometry_state = &"formation_stable"
		engine_state = &"underway"
		formation_state = &"escorting"
		var maximum_separation := float(
			activity_snapshot.get("maximum_separation_seconds", 0.0)
		)
		if maximum_separation > 0.0:
			separation_fraction = clampf(
				float(activity_snapshot.get("separation_elapsed_seconds", 0.0))
				/ maximum_separation,
				0.0,
				1.0
			)
		if bool(activity_snapshot.get("has_entity_sample", false)) \
				and not bool(activity_snapshot.get("escort_within_proximity", true)):
			if separation_fraction >= CRITICAL_SEPARATION_FRACTION:
				geometry_state = &"separation_critical"
				pod_spread = MAXIMUM_PRESENTATION_POD_SPREAD
				drive_scale = Vector3(1.75, 0.42, 1.0)
				beacon_scale = Vector3(1.8, 2.5, 1.8)
			else:
				geometry_state = &"separation_warning"
				pod_spread = lerpf(0.65, 1.5, separation_fraction / CRITICAL_SEPARATION_FRACTION)
				drive_scale = Vector3(1.25, 0.72, 1.0)
				beacon_scale = Vector3(1.0, 1.8, 1.0)
	elif activity_state == &"completed":
		geometry_state = &"convoy_complete"
		engine_state = &"safe"
		formation_state = &"secured"
		pod_spread = COMPLETED_PRESENTATION_POD_TUCK
		drive_scale = Vector3(0.72, 1.65, 1.0)
		beacon_scale = Vector3(2.2, 0.55, 2.2)
	elif activity_state in [&"failed", &"aborted"]:
		geometry_state = &"convoy_failed"
		engine_state = &"unavailable"
		formation_state = &"broken"
		pod_spread = MAXIMUM_PRESENTATION_POD_SPREAD
		drive_scale = Vector3(1.75, 0.42, 1.0)
		beacon_scale = Vector3(1.8, 2.5, 1.8)

	_cargo_pod_multimesh.buffer = _encode_multimesh_transforms(
		_cargo_pod_presentation_transforms(pod_spread)
	)
	var starboard_anchor := _convoy_entity.get_node_or_null(^"StarboardCargoPod") as Node3D
	var drive_glow := _convoy_entity.get_node_or_null(^"DriveGlow") as MeshInstance3D
	var navigation_beacon := (
		_convoy_entity.get_node_or_null(^"NavigationBeacon") as MeshInstance3D
	)
	if starboard_anchor != null:
		starboard_anchor.position = CARGO_POD_POSITIONS[1] + Vector3(pod_spread, 0.0, 0.0)
	if drive_glow != null:
		drive_glow.scale = drive_scale
	if navigation_beacon != null:
		navigation_beacon.scale = beacon_scale
	var previous_response_active := bool(
		_visual_feedback_snapshot.get("arrival_response_active", false)
	)
	var response_active := activity_state == &"completed"
	var response_serial := int(_visual_feedback_snapshot.get("arrival_response_serial", 0))
	if response_active and not previous_response_active:
		response_serial += 1
	_visual_feedback_snapshot = {
		"geometry_state": geometry_state,
		"engine_state": engine_state,
		"formation_state": formation_state,
		"arrival_response_id": (
			&"engines_safe_formation_secured" if response_active else &""
		),
		"arrival_response_active": response_active,
		"arrival_response_serial": response_serial,
		"activity_generation": int(activity_snapshot.get("generation", 0)),
		"separation_fraction": separation_fraction,
		"pod_spread": pod_spread,
		"drive_scale": drive_scale,
		"beacon_scale": beacon_scale,
		"uses_authoritative_activity_snapshot": true,
		"static_geometry_only": true,
		"movement_authority": false,
		"combat_authority": false,
		"reward_authority": false,
		"restored_terminal_presentation": not activity_override.is_empty(),
	}.duplicate(true)


func _cargo_pod_presentation_transforms(pod_spread: float) -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-pod_spread, 0.0, 0.0)),
		Transform3D(Basis.IDENTITY, Vector3(6.7 + pod_spread, 0.0, 0.0)),
	]


func _cargo_pod_presentation_aabb() -> AABB:
	return AABB(
		Vector3(-MAXIMUM_PRESENTATION_POD_SPREAD, 0.0, 0.0) - CARGO_POD_SIZE * 0.5,
		CARGO_POD_SIZE
	).merge(
		AABB(
			Vector3(6.7 + MAXIMUM_PRESENTATION_POD_SPREAD, 0.0, 0.0)
			- CARGO_POD_SIZE * 0.5,
			CARGO_POD_SIZE
		)
	)


func _encode_multimesh_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _box(
	node_name: String,
	size: Vector3,
	position: Vector3,
	material: Material,
	shared_mesh: BoxMesh = null
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := shared_mesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_convoy_entity.add_child(instance)
	return instance


func _material(
	resource_name: String,
	color: Color,
	metallic: float,
	roughness: float,
	emission: Color = Color(0.0, 0.0, 0.0, 1.0)
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = resource_name
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.2
	return material


func _publish_sample(escort_position: Vector3, status: int) -> Dictionary:
	var result := _activity.submit_entity_sample(
		CONVOY_ID,
		_entity_generation,
		_convoy_entity.position,
		escort_position,
		status,
		_activity.get_generation()
	)
	if bool(result.get("accepted", false)):
		_sample_publication_count += 1
		_sync_next_route_index()
	return result


func _sync_next_route_index() -> void:
	var snapshot := _activity.get_snapshot()
	var next_index := int(snapshot.get("next_leg_index", -1))
	_next_route_index = next_index if next_index >= 0 else ROUTE.get_checkpoint_count()
	if _next_route_index < ROUTE.get_checkpoint_count():
		_orient_toward_route_index(_next_route_index)


func _set_entity_position(value: Vector3) -> void:
	_last_entity_position = value
	if not _has_live_convoy_entity():
		return
	var transform := _convoy_entity.transform
	transform.origin = value
	_convoy_entity.transform = transform


func _has_live_convoy_entity() -> bool:
	return (
		is_instance_valid(_convoy_entity)
		and not _convoy_entity.is_queued_for_deletion()
		and _convoy_entity.get_parent() == self
	)


## Actor removal is terminal rather than an implicit respawn. The activity keeps
## its own generation-safe lifecycle authority, so the normal reset/start path
## is the sole bounded recovery route for a fresh tender incarnation.
func _finish_actor_loss(expected_generation: int) -> Dictionary:
	var escort_position := (
		_last_escort_position if _has_escort_sample else _last_entity_position
	)
	var lost := _activity.submit_entity_sample(
		CONVOY_ID,
		_entity_generation,
		_last_entity_position,
		escort_position,
		ConvoyEscortActivity.EntityStatus.LOST,
		expected_generation
	)
	if not bool(lost.get("accepted", false)):
		return _finish(false, &"actor_loss_publication_rejected")
	_sample_publication_count += 1
	_entity_status = ConvoyEscortActivity.EntityStatus.LOST
	var result := _finish(true, &"convoy_actor_lost")
	_emit_terminal_once()
	_emit_snapshot(presentation_changed)
	return result


func _restore_missing_convoy_entity() -> void:
	if _has_live_convoy_entity():
		return
	if is_instance_valid(_convoy_entity) and _convoy_entity.get_parent() == self:
		remove_child(_convoy_entity)
	_convoy_entity = Node3D.new()
	_convoy_entity.name = "EmberlineSupplyTender"
	_convoy_entity.set_meta(&"convoy_entity", true)
	_convoy_entity.set_meta(&"content_class", CONTENT_CLASS)
	_convoy_entity.set_meta(&"evidence_status", EVIDENCE_STATUS)
	add_child(_convoy_entity)
	_build_entity_visuals()


func _orient_toward_route_index(index: int) -> void:
	if not is_instance_valid(_convoy_entity) or index < 0 or index >= ROUTE.get_checkpoint_count():
		return
	var direction := ROUTE.get_checkpoint_position(index) - _convoy_entity.position
	if direction.length_squared() <= 0.000001:
		return
	var transform := _convoy_entity.transform
	transform.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	_convoy_entity.transform = transform


func _common_mutation_rejection(expected_generation: int) -> StringName:
	if not _built:
		return &"not_ready"
	if is_queued_for_deletion():
		return &"queued_for_deletion"
	if not _attached or not is_inside_tree():
		return &"detached"
	if expected_generation != get_generation():
		return &"stale_generation"
	return &""


func _running_rejection(expected_generation: int) -> StringName:
	var common := _common_mutation_rejection(expected_generation)
	if not common.is_empty():
		return common
	if _activity.get_state() != ConvoyEscortActivity.State.ACTIVE:
		return &"not_active"
	return &""


func _prefer_progress_reason(current: StringName, candidate: StringName) -> StringName:
	if candidate in [&"safely_arrived", &"convoy_lost", &"convoy_destroyed"]:
		return candidate
	if candidate in [&"leg_reached", &"final_leg_waiting_for_escort"]:
		return candidate
	return current


func _emit_terminal_once() -> void:
	if not is_instance_valid(_activity):
		return
	var state := _activity.get_state()
	if state not in [
		ConvoyEscortActivity.State.COMPLETED,
		ConvoyEscortActivity.State.FAILED,
	]:
		return
	var generation := _activity.get_generation()
	if generation == _terminal_signal_generation:
		return
	_terminal_signal_generation = generation
	if state == ConvoyEscortActivity.State.COMPLETED:
		_emit_snapshot(convoy_safely_arrived)
	else:
		_emit_snapshot(convoy_failed)


func _emit_snapshot(target_signal: Signal) -> void:
	_signal_dispatch_active = true
	target_signal.emit(get_snapshot())
	_signal_dispatch_active = false


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	_apply_visual_feedback()
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)
