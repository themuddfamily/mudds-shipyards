class_name CommonWorldOriginRebaseOwner
extends Node

## Main-owned atomic floating-origin transaction for the production Ember frame.
## It owns coordinate-space translation only: never gameplay motion, landing,
## streaming generations, activity, combat, rewards, save, or networking.

signal rebase_committed(receipt: Dictionary)

const SCHEMA_VERSION := 1
const MAX_DERIVED_DESCENDANT_RESPONSE_METERS := 0.1
const DEFAULT_BOOTSTRAP_PATH := NodePath("../EmberMoonStreamingBootstrap")
const DEFAULT_BINDING_PATH := NodePath("../EmberMoonStreamingProductionBinding")

@export var bootstrap_path := DEFAULT_BOOTSTRAP_PATH
@export var binding_path := DEFAULT_BINDING_PATH

var _bootstrap: EmberMoonStreamingBootstrap
var _binding: EmberMoonStreamingProductionBinding
var _frame: PlanetaryCoordinateFrame
var _activated := false
var _configuration_error: StringName = &""
var _bootstrap_instance_id := 0
var _binding_instance_id := 0
var _frame_instance_id := 0
var _mutation_active := false
var _signal_dispatch_active := false
var _transaction_count := 0
var _rejection_count := 0
var _rollback_count := 0
var _reentrant_rejection_count := 0
var _last_source_generation := 0
var _last_target_generation := 0
var _last_translation_delta := Vector3.ZERO
var _last_root_roster: Array[Dictionary] = []
var _last_covered_node_count := 0
var _last_covered_instance_ids := PackedInt64Array()
var _last_receipt: Dictionary = {}
var _commit_adapter := Callable()


func _enter_tree() -> void:
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	call_deferred(&"_activate_scene_binding")


func _exit_tree() -> void:
	set_process(false)
	set_physics_process(false)


## Test-only pre-activation seam for proving commit rejection rollback. A
## production audit rejects any retained override.
func set_commit_adapter_for_test(adapter: Callable) -> bool:
	if _activated or _mutation_active or _signal_dispatch_active:
		return false
	if not adapter.is_valid():
		return false
	_commit_adapter = adapter
	return true


## Consumes the exact preview produced from the shared physics actor sample.
## On success the returned actor sample is the same observation translated into
## the newly committed local frame; GameFlow must use it for later consumers.
func consume_rebase_preview(preview: Variant, actor_sample: Variant) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		_reentrant_rejection_count += 1
		return _reject(&"reentrant_call")
	if not _activated or not is_inside_tree() or is_queued_for_deletion():
		return _reject(&"owner_unavailable")
	var identity_reason := _identity_preflight()
	if not identity_reason.is_empty():
		return _reject(identity_reason)
	var validation := _validate_preview_and_actor(preview, actor_sample)
	if not bool(validation.get("accepted", false)):
		return _reject(validation.get("reason", &"invalid_rebase_preview") as StringName)
	var preview_value := preview as Dictionary
	var sample_value := actor_sample as Dictionary
	if not bool(preview_value.get("rebase_required", false)):
		return _result(true, &"no_rebase_required", {
			"actor_sample": sample_value.duplicate(true),
			"coordinate_frame_generation": _frame.get_generation(),
		})
	var quiescence_reason := _world_quiescence_preflight()
	if not quiescence_reason.is_empty():
		return _reject(quiescence_reason)

	var roster_result := _capture_live_roster()
	if not bool(roster_result.get("accepted", false)):
		return _reject(roster_result.get("reason", &"roster_preflight_failed") as StringName)
	var roots := roster_result.get("roots", []) as Array
	var covered := roster_result.get("covered", []) as Array
	var source_generation := int(preview_value.get("coordinate_frame_generation", 0))
	var focus := preview_value.get("focus_world_streaming_position", Vector3.INF) as Vector3
	var delta := preview_value.get("world_translation_delta", Vector3.INF) as Vector3

	_mutation_active = true
	var request_result := _frame.request_rebase(focus, source_generation)
	if not bool(request_result.get("accepted", false)):
		_mutation_active = false
		return _reject(request_result.get("reason", &"rebase_request_rejected") as StringName)
	var request := (request_result.get("request", {}) as Dictionary).duplicate(true)
	var binding_preflight := _binding.preflight_external_origin_rebase(
		preview_value, request
	)
	if not bool(binding_preflight.get("accepted", false)):
		_frame.cancel_rebase(int(request.get("request_id", 0)), source_generation)
		_mutation_active = false
		return _reject(binding_preflight.get("reason", &"binding_preflight_rejected") as StringName)
	if not _apply_root_translation(roots, delta):
		var apply_rollback_synchronized := _rollback_world(roots, covered)
		_frame.cancel_rebase(int(request.get("request_id", 0)), source_generation)
		_rollback_count += 1
		_mutation_active = false
		if not apply_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(&"translation_apply_failed")
	if not _verify_covered_translation(covered, roots, delta):
		var verification_rollback_synchronized := _rollback_world(roots, covered)
		_frame.cancel_rebase(int(request.get("request_id", 0)), source_generation)
		_rollback_count += 1
		_mutation_active = false
		if not verification_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(&"translation_verification_failed")
	# Node3D transforms commit immediately, but broadphase state for inherited
	# CollisionObject3D transforms can otherwise remain at the pre-translation
	# coordinates until the next physics flush. Downstream same-tick consumers
	# (notably HeroShip's full-hull cruise proof) must observe neither a false
	# obstacle nor a false clear, so synchronize the exact covered collision
	# roster before the coordinate-frame commit is exposed.
	if not _synchronize_collision_transforms(covered):
		var synchronization_rollback_synchronized := _rollback_world(roots, covered)
		_frame.cancel_rebase(int(request.get("request_id", 0)), source_generation)
		_rollback_count += 1
		_mutation_active = false
		if not synchronization_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(&"collision_transform_synchronization_failed")
	var commit := _commit_frame_rebase(
		int(request.get("request_id", 0)), source_generation
	)
	if not bool(commit.get("accepted", false)):
		var commit_rollback_synchronized := _rollback_world(roots, covered)
		var pending := _frame.get_snapshot().get("pending_rebase", {}) as Dictionary
		if int(pending.get("request_id", 0)) == int(request.get("request_id", 0)):
			_frame.cancel_rebase(int(request.get("request_id", 0)), source_generation)
		_rollback_count += 1
		_mutation_active = false
		if not commit_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(commit.get("reason", &"rebase_commit_rejected") as StringName)
	var target_generation := int(request.get("target_generation", 0))
	var adjusted_sample := sample_value.duplicate(true)
	adjusted_sample["position"] = focus + delta
	var binding_commit := _binding.accept_committed_origin_rebase(
		preview_value, request, adjusted_sample, target_generation
	)
	if not bool(binding_commit.get("accepted", false)):
		# Every mutable dependency was synchronously preflighted under this guard;
		# reaching this branch means an invariant breach after an irreversible frame
		# commit. Report fail-closed rather than pretending rollback is possible.
		_mutation_active = false
		return _reject(&"binding_commit_desynchronized")

	_transaction_count += 1
	_last_source_generation = source_generation
	_last_target_generation = target_generation
	_last_translation_delta = delta
	_last_root_roster = _public_root_roster(roots)
	_last_covered_node_count = covered.size()
	_last_covered_instance_ids = _covered_ids(covered)
	_last_receipt = {
		"schema_version": SCHEMA_VERSION,
		"reason": &"rebase_committed",
		"transaction_index": _transaction_count,
		"source_generation": source_generation,
		"target_generation": target_generation,
		"request_id": int(request.get("request_id", 0)),
		"actor_kind": preview_value.get("actor_kind", &"") as StringName,
		"actor_instance_id": int(preview_value.get("actor_instance_id", 0)),
		"absolute_coordinate": (
			preview_value.get("absolute_coordinate", {}) as Dictionary
		).duplicate(true),
		"world_translation_delta": delta,
		"adjusted_actor_sample": adjusted_sample.duplicate(true),
		"root_roster": _last_root_roster.duplicate(true),
		"covered_node_count": _last_covered_node_count,
		"covered_instance_ids": _last_covered_instance_ids.duplicate(),
		"ember_streaming": binding_commit.get("streaming", {}).duplicate(true),
	}.duplicate(true)
	_mutation_active = false
	_signal_dispatch_active = true
	rebase_committed.emit(_last_receipt.duplicate(true))
	_signal_dispatch_active = false
	return _result(true, &"rebase_committed", {
		"actor_sample": adjusted_sample.duplicate(true),
		"receipt": _last_receipt.duplicate(true),
		"coordinate_frame_generation": target_generation,
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activated": _activated,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"automatic_process": is_processing(),
		"automatic_physics_process": is_physics_processing(),
		"bootstrap_instance_id": _bootstrap_instance_id,
		"binding_instance_id": _binding_instance_id,
		"coordinate_frame_instance_id": _frame_instance_id,
		"coordinate_frame_generation": _frame.get_generation() if _frame != null else 0,
		"transaction_count": _transaction_count,
		"rejection_count": _rejection_count,
		"rollback_count": _rollback_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"last_source_generation": _last_source_generation,
		"last_target_generation": _last_target_generation,
		"last_translation_delta": _last_translation_delta,
		"last_root_roster": _last_root_roster.duplicate(true),
		"last_covered_node_count": _last_covered_node_count,
		"last_covered_instance_ids": _last_covered_instance_ids.duplicate(),
		"last_receipt": _last_receipt.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var identity_reason := _identity_preflight()
	if not _activated:
		errors.append("common-world origin owner is not activated: %s" % _configuration_error)
	elif not identity_reason.is_empty():
		errors.append("bound identity invalid: %s" % identity_reason)
	if _commit_adapter.is_valid():
		errors.append("production owner cannot retain a test commit adapter")
	if is_processing() or is_physics_processing():
		errors.append("origin owner must be caller-driven only")
	var count := 0
	var host := get_parent()
	if host != null:
		for candidate in host.find_children("*", "CommonWorldOriginRebaseOwner", true, false):
			if candidate is CommonWorldOriginRebaseOwner:
				count += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty() and count == 1,
		"errors": errors,
		"owner_count": count,
		"snapshot": get_snapshot(),
		"roster_policy": &"all_live_direct_node3d_roots_plus_every_nested_top_level_node3d",
		"covered_policy": &"exact_roots_exact_descendant_local_transforms_camera_rig_bounded_response",
		"maximum_derived_descendant_response_meters": MAX_DERIVED_DESCENDANT_RESPONSE_METERS,
		"owned_capabilities": {
			"coordinate_frame_rebase_request": true,
			"coordinate_frame_rebase_commit": true,
			"common_world_translation": true,
			"collision_transform_synchronization": true,
		},
		"collision_transform_synchronization_policy": &"exact_covered_collision_object_roster_before_commit_and_after_rollback",
		"adjacent_authority": {
			"activity": false,
			"combat": false,
			"gameplay": false,
			"landing": false,
			"network": false,
			"reward": false,
			"save": false,
			"ship_movement": false,
			"streaming_generation": false,
			"streaming_load_unload": false,
		},
	}.duplicate(true)


func _activate_scene_binding() -> void:
	if _activated or not is_inside_tree() or is_queued_for_deletion():
		return
	_bootstrap = get_node_or_null(bootstrap_path) as EmberMoonStreamingBootstrap
	_binding = get_node_or_null(binding_path) as EmberMoonStreamingProductionBinding
	if not is_instance_valid(_bootstrap) or not is_instance_valid(_binding):
		_configuration_error = &"missing_ember_composition"
		return
	_frame = _bootstrap.get_coordinate_frame_for_session()
	if _frame == null:
		_configuration_error = &"missing_coordinate_frame"
		return
	_bootstrap_instance_id = _bootstrap.get_instance_id()
	_binding_instance_id = _binding.get_instance_id()
	_frame_instance_id = _frame.get_instance_id()
	_activated = true
	_configuration_error = &""


func _identity_preflight() -> StringName:
	var host := get_parent()
	if is_queued_for_deletion() or host == null or host.is_queued_for_deletion():
		return &"owner_or_host_unavailable"
	if not is_instance_valid(_bootstrap) or _bootstrap.is_queued_for_deletion() \
			or not _bootstrap.is_inside_tree() \
			or _bootstrap.get_instance_id() != _bootstrap_instance_id \
			or _bootstrap.get_parent() != host:
		return &"bootstrap_identity_drift"
	if not is_instance_valid(_binding) or _binding.is_queued_for_deletion() \
			or not _binding.is_inside_tree() \
			or _binding.get_instance_id() != _binding_instance_id \
			or _binding.get_parent() != host:
		return &"binding_identity_drift"
	if _frame == null or _frame.get_instance_id() != _frame_instance_id \
			or _bootstrap.get_coordinate_frame_for_session() != _frame:
		return &"coordinate_frame_identity_drift"
	return &""


func _validate_preview_and_actor(preview: Variant, actor_sample: Variant) -> Dictionary:
	if not preview is Dictionary or not actor_sample is Dictionary:
		return _result(false, &"invalid_rebase_input")
	var p := preview as Dictionary
	var s := actor_sample as Dictionary
	if not bool(p.get("accepted", false)) or p.get("reason") != &"origin_rebase_preview":
		return _result(false, &"invalid_rebase_preview")
	var generation := int(p.get("coordinate_frame_generation", 0))
	if generation != _frame.get_generation():
		return _result(false, &"stale_coordinate_frame_generation")
	var focus: Variant = p.get("focus_world_streaming_position", Vector3.INF)
	var delta: Variant = p.get("world_translation_delta", Vector3.INF)
	if focus is not Vector3 or delta is not Vector3 \
			or not (focus as Vector3).is_finite() or not (delta as Vector3).is_finite() \
			or not (delta as Vector3).is_equal_approx(-(focus as Vector3)):
		return _result(false, &"invalid_translation_delta")
	if not bool(s.get("available", false)) \
			or s.get("position") != focus \
			or s.get("actor_kind") != p.get("actor_kind") \
			or int(s.get("actor_instance_id", 0)) != int(p.get("actor_instance_id", -1)):
		return _result(false, &"actor_sample_mismatch")
	var actor := instance_from_id(int(p.get("actor_instance_id", 0))) as Node3D
	var host := get_parent()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() \
			or not actor.is_inside_tree() or not host.is_ancestor_of(actor) \
			or not actor.global_position.is_equal_approx(focus as Vector3):
		return _result(false, &"actor_identity_mismatch")
	return _result(true, &"rebase_input_valid")


func _capture_live_roster() -> Dictionary:
	var host := get_parent()
	var roots: Array[Dictionary] = []
	var covered: Array[Dictionary] = []
	for candidate in host.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion() \
				or not node.is_inside_tree():
			return _result(false, &"queued_or_detached_world_node")
		covered.append({
			"node": node,
			"instance_id": node.get_instance_id(),
			"path": str(host.get_path_to(node)),
			"global_transform": node.global_transform,
			"transform": node.transform,
		})
		if node.get_parent() == host or node.top_level:
			roots.append({
				"node": node,
				"instance_id": node.get_instance_id(),
				"path": str(host.get_path_to(node)),
				"mode": &"top_level" if node.top_level else &"direct",
				"transform": node.transform,
				"global_transform": node.global_transform,
			})
	roots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.path) < str(b.path))
	covered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.path) < str(b.path))
	return {"accepted": true, "reason": &"roster_captured", "roots": roots, "covered": covered}


func _world_quiescence_preflight() -> StringName:
	var host := get_parent()
	var pulse := host.get_node_or_null(^"PulseWeaponPresentation")
	if pulse != null and pulse.has_method(&"get_active_effect_count") \
			and int(pulse.call(&"get_active_effect_count")) != 0:
		return &"active_world_presentation"
	for candidate in host.find_children("*", "", true, false):
		if candidate.has_method(&"get_pending_damage_presentation_count") \
				and int(candidate.call(&"get_pending_damage_presentation_count")) != 0:
			return &"pending_world_damage_presentation"
		if candidate.has_method(&"get_pending_target_damage_presentation_count") \
				and int(candidate.call(&"get_pending_target_damage_presentation_count")) != 0:
			return &"pending_world_damage_presentation"
		if candidate.has_method(&"get_pending_terminal_damage_presentation_receipt_id") \
				and int(candidate.call(&"get_pending_terminal_damage_presentation_receipt_id")) >= 0:
			return &"pending_terminal_damage_presentation"
	return &""


func _apply_root_translation(roots: Array, delta: Vector3) -> bool:
	for record_value in roots:
		var record := record_value as Dictionary
		var node := record.get("node") as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
			return false
		if record.get("mode") == &"top_level":
			node.global_position += delta
		else:
			node.position += delta
		var expected := (record.get("global_transform") as Transform3D).origin + delta
		if not node.global_position.is_equal_approx(expected):
			return false
	return true


func _verify_covered_translation(covered: Array, roots: Array, delta: Vector3) -> bool:
	var root_ids := {}
	for root_value in roots:
		root_ids[int((root_value as Dictionary).get("instance_id", 0))] = true
	for record_value in covered:
		var record := record_value as Dictionary
		var node := record.get("node") as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree() \
				or node.get_instance_id() != int(record.get("instance_id", 0)):
			return false
		var before := record.get("global_transform") as Transform3D
		if root_ids.has(node.get_instance_id()):
			if not node.global_position.is_equal_approx(before.origin + delta) \
					or not node.global_basis.is_equal_approx(before.basis):
				return false
			continue
		var before_local := record.get("transform") as Transform3D
		if node.transform.is_equal_approx(before_local):
			continue
		var path := str(record.get("path", ""))
		var derived_camera := path.begins_with("Player/CameraRig/") \
				and (node is Camera3D or node is SpringArm3D)
		if not derived_camera \
				or node.position.distance_to(before_local.origin) \
					> MAX_DERIVED_DESCENDANT_RESPONSE_METERS \
				or not node.basis.is_equal_approx(before_local.basis):
			return false
	return true


func _rollback_roots(roots: Array) -> bool:
	var restored := true
	for index in range(roots.size() - 1, -1, -1):
		var record := roots[index] as Dictionary
		var node := record.get("node") as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			restored = false
			continue
		if record.get("mode") == &"top_level":
			node.global_transform = record.get("global_transform") as Transform3D
		else:
			node.transform = record.get("transform") as Transform3D
	return restored


func _rollback_world(roots: Array, covered: Array) -> bool:
	var restored := _rollback_roots(roots)
	var root_ids := {}
	for root_value in roots:
		root_ids[int((root_value as Dictionary).get("instance_id", 0))] = true
	# Restore every non-root local transform as well. This reverses synchronous
	# derived-rig responses (notably SpringArm camera settling), so a rejected
	# transaction is byte-for-byte spatially neutral rather than merely restoring
	# authoritative parents.
	for record_value in covered:
		var record := record_value as Dictionary
		var node := record.get("node") as Node3D
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			restored = false
			continue
		if root_ids.has(node.get_instance_id()):
			continue
		node.transform = record.get("transform") as Transform3D
	# A failed transaction must also restore physics-server transforms that were
	# synchronously advanced before a later commit rejection.
	return _synchronize_collision_transforms(covered) and restored


func _synchronize_collision_transforms(covered: Array) -> bool:
	for record_value in covered:
		var record := record_value as Dictionary
		var node := record.get("node") as Node3D
		if not node is CollisionObject3D:
			continue
		var collision := node as CollisionObject3D
		if (
			not is_instance_valid(collision)
			or collision.is_queued_for_deletion()
			or not collision.is_inside_tree()
			or collision.get_instance_id() != int(record.get("instance_id", 0))
		):
			return false
		collision.force_update_transform()
		var rid := collision.get_rid()
		if not rid.is_valid():
			return false
		if collision is PhysicsBody3D:
			PhysicsServer3D.body_set_state(
				rid,
				PhysicsServer3D.BODY_STATE_TRANSFORM,
				collision.global_transform,
			)
		elif collision is Area3D:
			PhysicsServer3D.area_set_transform(rid, collision.global_transform)
		else:
			return false
	return true


func _commit_frame_rebase(request_id: int, source_generation: int) -> Dictionary:
	if _commit_adapter.is_valid():
		return _commit_adapter.call(request_id, source_generation) as Dictionary
	return _frame.commit_rebase(request_id, source_generation)


func _public_root_roster(roots: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record_value in roots:
		var record := record_value as Dictionary
		result.append({
			"path": str(record.get("path", "")),
			"instance_id": int(record.get("instance_id", 0)),
			"mode": record.get("mode", &"") as StringName,
		})
	return result


func _covered_ids(covered: Array) -> PackedInt64Array:
	var result := PackedInt64Array()
	for record_value in covered:
		result.append(int((record_value as Dictionary).get("instance_id", 0)))
	return result


func _reject(reason: StringName) -> Dictionary:
	_rejection_count += 1
	return _result(false, reason)


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
