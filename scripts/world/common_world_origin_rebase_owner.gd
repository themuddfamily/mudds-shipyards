class_name CommonWorldOriginRebaseOwner
extends Node

## Main-owned atomic floating-origin transaction for every production planetary
## frame composed under this Main.
##
## It owns coordinate-space translation only: never gameplay motion, landing,
## streaming generations, activity, combat, rewards, save, or networking.
##
## The owner is deliberately world-plural. Each composed world brings its own
## [PlanetaryStreamingProductionBinding] and [PlanetaryStreamingBootstrap] pair
## and therefore its own [PlanetaryCoordinateFrame]; this component binds every
## such pair it finds beside it and routes each transaction to the one the
## incoming preview names. The common world is shared — a committed translation
## moves *every* root under Main once, whichever world asked for it — so there
## can still be only one owner, and only one transaction at a time.

signal rebase_committed(receipt: Dictionary)

const SCHEMA_VERSION := 1
const MAX_DERIVED_DESCENDANT_RESPONSE_METERS := 0.1


## A node that answers `false` declares that its transform does not express a
## position in the common world, so translating it would move something the
## owner does not own. Everything that does not declare the capability is an
## ordinary common-world root and is translated. `EmberSurfaceLoopHost` is the
## one production declarer: it is a logic node pinned to Main's own origin and
## used as the reference identity a surface visit measures against.
static func node_is_common_world_translation_root(node: Node3D) -> bool:
	if node.has_method(&"is_common_world_translation_root"):
		return bool(node.call(&"is_common_world_translation_root"))
	return true


var _worlds: Array[Dictionary] = []
var _activated := false
var _configuration_error: StringName = &""
var _mutation_active := false
var _signal_dispatch_active := false
var _transaction_count := 0
var _rejection_count := 0
var _rollback_count := 0
var _reentrant_rejection_count := 0
var _bind_count := 0
var _unbind_count := 0
var _last_world_id: StringName = &""
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


# --- world roster ------------------------------------------------------------


## Binds one composed world's observation binding and its bootstrap's frame.
##
## Fenced: a world can compose or retire between transactions, never inside one.
## The roster is keyed by world id, so a second composition of the same body is
## refused rather than silently shadowing the live one.
func bind_world(binding: PlanetaryStreamingProductionBinding) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _result(false, &"rebind_during_transaction")
	if not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"owner_unavailable")
	var record := _compose_record(binding)
	if record.is_empty():
		return _result(false, &"world_composition_invalid")
	var world_id := record.get("world_id", &"") as StringName
	if _find_world_index(world_id) >= 0:
		return _result(false, &"world_already_bound")
	_worlds.append(record)
	_worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("world_id", &"")) < String(b.get("world_id", &""))
	)
	_bind_count += 1
	_activated = true
	_configuration_error = &""
	return _result(true, &"world_bound", {
		"world_id": world_id,
		"world_count": _worlds.size(),
	})


## Retires one composed world. Fenced for the same reason as `bind_world`.
func unbind_world(world_id: StringName) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _result(false, &"rebind_during_transaction")
	var index := _find_world_index(world_id)
	if index < 0:
		return _result(false, &"world_not_bound")
	_worlds.remove_at(index)
	_unbind_count += 1
	if _worlds.is_empty():
		_activated = false
		_configuration_error = &"missing_world_composition"
	return _result(true, &"world_unbound", {
		"world_id": world_id,
		"world_count": _worlds.size(),
	})


## Reconciles the roster with what is actually composed beside this owner right
## now: binds every activated sibling world it does not already hold, and drops
## every record whose binding, bootstrap or frame identity has gone away. This
## is the seam a caller uses when a world composes or retires mid-session.
func rebind_composed_worlds() -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		return _result(false, &"rebind_during_transaction")
	if not is_inside_tree() or is_queued_for_deletion():
		return _result(false, &"owner_unavailable")
	var bound := PackedStringArray()
	var dropped := PackedStringArray()
	for index in range(_worlds.size() - 1, -1, -1):
		var record := _worlds[index]
		if not _record_identity_reason(record).is_empty():
			dropped.append(String(record.get("world_id", &"")))
			_worlds.remove_at(index)
			_unbind_count += 1
	for candidate in _composed_bindings():
		var binding := candidate as PlanetaryStreamingProductionBinding
		var world_id := binding.get_bound_world_id()
		if world_id.is_empty() or _find_world_index(world_id) >= 0:
			continue
		var record := _compose_record(binding)
		if record.is_empty():
			continue
		_worlds.append(record)
		_bind_count += 1
		bound.append(String(world_id))
	_worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("world_id", &"")) < String(b.get("world_id", &""))
	)
	_activated = not _worlds.is_empty()
	_configuration_error = &"" if _activated else &"missing_world_composition"
	return _result(_activated, &"worlds_rebound" if _activated else &"missing_world_composition", {
		"bound_world_ids": bound,
		"dropped_world_ids": dropped,
		"world_count": _worlds.size(),
	})


func get_bound_world_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for record in _worlds:
		ids.append(String(record.get("world_id", &"")))
	return ids


## Detached identity evidence for exactly one bound world, for a consumer that
## must prove the owner is paired with *its* composition and no other. Empty
## when that world is not bound.
func get_world_binding_snapshot(world_id: StringName) -> Dictionary:
	var index := _find_world_index(world_id)
	if index < 0:
		return {}
	var record := _worlds[index]
	var frame := record.get("frame") as PlanetaryCoordinateFrame
	return {
		"world_id": world_id,
		"bootstrap_instance_id": int(record.get("bootstrap_instance_id", 0)),
		"binding_instance_id": int(record.get("binding_instance_id", 0)),
		"coordinate_frame_instance_id": int(record.get("frame_instance_id", 0)),
		"coordinate_frame_generation": frame.get_generation() if frame != null else 0,
		"identity_error": _record_identity_reason(record),
	}.duplicate(true)


# --- transaction -------------------------------------------------------------


## Consumes the exact preview produced from the shared physics actor sample.
## On success the returned actor sample is the same observation translated into
## the newly committed local frame; GameFlow must use it for later consumers.
func consume_rebase_preview(preview: Variant, actor_sample: Variant) -> Dictionary:
	if _mutation_active or _signal_dispatch_active:
		_reentrant_rejection_count += 1
		return _reject(&"reentrant_call")
	if not _activated or not is_inside_tree() or is_queued_for_deletion():
		return _reject(&"owner_unavailable")
	if not preview is Dictionary or not actor_sample is Dictionary:
		return _reject(&"invalid_rebase_input")
	var world_index := _find_world_index(
		(preview as Dictionary).get("world_id", &"") as StringName
	)
	if world_index < 0:
		return _reject(&"unbound_rebase_world")
	var record := _worlds[world_index]
	var identity_reason := _record_identity_reason(record)
	if not identity_reason.is_empty():
		return _reject(identity_reason)
	var binding := record.get("binding") as PlanetaryStreamingProductionBinding
	var frame := record.get("frame") as PlanetaryCoordinateFrame
	var validation := _validate_preview_and_actor(frame, preview, actor_sample)
	if not bool(validation.get("accepted", false)):
		return _reject(validation.get("reason", &"invalid_rebase_preview") as StringName)
	var preview_value := preview as Dictionary
	var sample_value := actor_sample as Dictionary
	if not bool(preview_value.get("rebase_required", false)):
		return _result(true, &"no_rebase_required", {
			"world_id": record.get("world_id", &""),
			"actor_sample": sample_value.duplicate(true),
			"coordinate_frame_generation": frame.get_generation(),
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
	# The common world is shared, so a committed translation moves every world's
	# local space at once. Open the pending request on *every* bound frame, not
	# just the one that asked: a frame left behind would have its bootstrap root
	# translated out from under it and would refuse every later focus update.
	var opened := _open_pending_rebases(focus)
	if not bool(opened.get("accepted", false)):
		_mutation_active = false
		return _reject(opened.get("reason", &"rebase_request_rejected") as StringName)
	var requests := opened.get("requests", []) as Array
	var request := _request_for_world(
		requests, record.get("world_id", &"") as StringName
	)
	if int(request.get("source_generation", -1)) != source_generation:
		_cancel_pending_rebases(requests)
		_mutation_active = false
		return _reject(&"rebase_request_rejected")
	var binding_preflight := binding.preflight_external_origin_rebase(
		preview_value, request
	)
	if not bool(binding_preflight.get("accepted", false)):
		_cancel_pending_rebases(requests)
		_mutation_active = false
		return _reject(binding_preflight.get("reason", &"binding_preflight_rejected") as StringName)
	if not _apply_root_translation(roots, delta):
		var apply_rollback_synchronized := _rollback_world(roots, covered)
		_cancel_pending_rebases(requests)
		_rollback_count += 1
		_mutation_active = false
		if not apply_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(&"translation_apply_failed")
	if not _verify_covered_translation(covered, roots, delta):
		var verification_rollback_synchronized := _rollback_world(roots, covered)
		_cancel_pending_rebases(requests)
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
		_cancel_pending_rebases(requests)
		_rollback_count += 1
		_mutation_active = false
		if not synchronization_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(&"collision_transform_synchronization_failed")
	# The requesting world commits first, while every other frame is still only
	# pending and the whole transaction is still reversible.
	var commit := _commit_frame_rebase(
		frame, int(request.get("request_id", 0)), source_generation
	)
	if not bool(commit.get("accepted", false)):
		var commit_rollback_synchronized := _rollback_world(roots, covered)
		_cancel_pending_rebases(requests)
		_rollback_count += 1
		_mutation_active = false
		if not commit_rollback_synchronized:
			return _reject(&"collision_transform_rollback_desynchronized")
		return _reject(commit.get("reason", &"rebase_commit_rejected") as StringName)
	var target_generation := int(request.get("target_generation", 0))
	# From here the transaction is irreversible. Every remaining frame was
	# synchronously validated and left pending under this same guard, so a
	# refusal now is an invariant breach, reported fail-closed.
	if not _commit_remaining_frames(requests, record.get("world_id", &"") as StringName):
		_mutation_active = false
		return _reject(&"common_world_frame_commit_desynchronized")
	var adjusted_sample := sample_value.duplicate(true)
	adjusted_sample["position"] = focus + delta
	var binding_commit := binding.accept_committed_origin_rebase(
		preview_value, request, adjusted_sample, target_generation
	)
	if not bool(binding_commit.get("accepted", false)):
		# Every mutable dependency was synchronously preflighted under this guard;
		# reaching this branch means an invariant breach after an irreversible frame
		# commit. Report fail-closed rather than pretending rollback is possible.
		_mutation_active = false
		return _reject(&"binding_commit_desynchronized")

	# The commit is irreversible from here. Actors that froze a world-space target
	# before it are now holding pre-translation coordinates; tell exactly those
	# that ask to be told. This is notification, not authority: the owner writes
	# no actor state beyond the translation it already applied.
	_notify_committed_translation(roots, covered, delta, requests)

	# Every other composed world's observation adapter now holds a pre-translation
	# local position for an absolute coordinate that did not move. Reconcile them
	# against their own committed generation.
	var unreconciled := _reconcile_other_worlds(
		requests, record.get("world_id", &"") as StringName, delta
	)
	if not unreconciled.is_empty():
		_mutation_active = false
		return _reject(&"common_world_binding_reconciliation_desynchronized")

	_transaction_count += 1
	_last_world_id = record.get("world_id", &"") as StringName
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
		"world_id": _last_world_id,
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
		"world_generations": _public_world_generations(requests),
		"world_streaming": binding_commit.get("streaming", {}).duplicate(true),
	}.duplicate(true)
	_mutation_active = false
	_signal_dispatch_active = true
	rebase_committed.emit(_last_receipt.duplicate(true))
	_signal_dispatch_active = false
	return _result(true, &"rebase_committed", {
		"world_id": _last_world_id,
		"actor_sample": adjusted_sample.duplicate(true),
		"receipt": _last_receipt.duplicate(true),
		"coordinate_frame_generation": target_generation,
	})


func get_snapshot() -> Dictionary:
	var worlds: Array[Dictionary] = []
	for record in _worlds:
		var frame := record.get("frame") as PlanetaryCoordinateFrame
		worlds.append({
			"world_id": record.get("world_id", &""),
			"bootstrap_instance_id": int(record.get("bootstrap_instance_id", 0)),
			"binding_instance_id": int(record.get("binding_instance_id", 0)),
			"coordinate_frame_instance_id": int(record.get("frame_instance_id", 0)),
			"coordinate_frame_generation": frame.get_generation() if frame != null else 0,
			"identity_error": _record_identity_reason(record),
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"activated": _activated,
		"configuration_error": _configuration_error,
		"inside_tree": is_inside_tree(),
		"automatic_process": is_processing(),
		"automatic_physics_process": is_physics_processing(),
		"world_count": _worlds.size(),
		"world_ids": get_bound_world_ids(),
		"worlds": worlds.duplicate(true),
		"bind_count": _bind_count,
		"unbind_count": _unbind_count,
		"transaction_count": _transaction_count,
		"rejection_count": _rejection_count,
		"rollback_count": _rollback_count,
		"reentrant_rejection_count": _reentrant_rejection_count,
		"last_world_id": _last_world_id,
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
	if not _activated or _worlds.is_empty():
		errors.append("common-world origin owner is not activated: %s" % _configuration_error)
	else:
		for record in _worlds:
			var reason := _record_identity_reason(record)
			if not reason.is_empty():
				errors.append("bound %s identity invalid: %s" % [
					String(record.get("world_id", &"")), reason,
				])
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
		"world_count": _worlds.size(),
		"world_ids": get_bound_world_ids(),
		"snapshot": get_snapshot(),
		"world_binding_policy": &"every_composed_planetary_streaming_binding_pair_routed_by_preview_world_id",
		"roster_policy": &"all_live_direct_node3d_roots_plus_every_nested_top_level_node3d",
		"covered_policy": &"exact_roots_exact_descendant_local_transforms_camera_rig_bounded_response",
		"maximum_derived_descendant_response_meters": MAX_DERIVED_DESCENDANT_RESPONSE_METERS,
		"owned_capabilities": {
			"coordinate_frame_rebase_request": true,
			"coordinate_frame_rebase_commit": true,
			"common_world_translation": true,
			"collision_transform_synchronization": true,
			"multi_world_binding": true,
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


# --- internals ---------------------------------------------------------------


func _activate_scene_binding() -> void:
	if _activated or not is_inside_tree() or is_queued_for_deletion():
		return
	var rebound := rebind_composed_worlds()
	if not bool(rebound.get("accepted", false)):
		_configuration_error = &"missing_world_composition"


func _composed_bindings() -> Array[PlanetaryStreamingProductionBinding]:
	var bindings: Array[PlanetaryStreamingProductionBinding] = []
	var host := get_parent()
	if host == null:
		return bindings
	for candidate in host.find_children("*", "", true, false):
		if candidate is PlanetaryStreamingProductionBinding:
			bindings.append(candidate as PlanetaryStreamingProductionBinding)
	return bindings


func _compose_record(binding: PlanetaryStreamingProductionBinding) -> Dictionary:
	if not is_instance_valid(binding) or binding.is_queued_for_deletion() \
			or not binding.is_inside_tree() or binding.get_parent() != get_parent():
		return {}
	var bootstrap := binding.get_bound_bootstrap()
	if not is_instance_valid(bootstrap) or bootstrap.is_queued_for_deletion() \
			or not bootstrap.is_inside_tree() \
			or bootstrap.get_parent() != get_parent():
		return {}
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		return {}
	var world_id := binding.get_bound_world_id()
	if world_id.is_empty():
		return {}
	return {
		"world_id": world_id,
		"binding": binding,
		"bootstrap": bootstrap,
		"frame": frame,
		"binding_instance_id": binding.get_instance_id(),
		"bootstrap_instance_id": bootstrap.get_instance_id(),
		"frame_instance_id": frame.get_instance_id(),
	}


func _find_world_index(world_id: StringName) -> int:
	if world_id.is_empty():
		return -1
	for index in _worlds.size():
		if _worlds[index].get("world_id", &"") == world_id:
			return index
	return -1


func _record_identity_reason(record: Dictionary) -> StringName:
	var host := get_parent()
	if is_queued_for_deletion() or host == null or host.is_queued_for_deletion():
		return &"owner_or_host_unavailable"
	var bootstrap := record.get("bootstrap") as PlanetaryStreamingBootstrap
	var binding := record.get("binding") as PlanetaryStreamingProductionBinding
	var frame := record.get("frame") as PlanetaryCoordinateFrame
	if not is_instance_valid(bootstrap) or bootstrap.is_queued_for_deletion() \
			or not bootstrap.is_inside_tree() \
			or bootstrap.get_instance_id() != int(record.get("bootstrap_instance_id", 0)) \
			or bootstrap.get_parent() != host:
		return &"bootstrap_identity_drift"
	if not is_instance_valid(binding) or binding.is_queued_for_deletion() \
			or not binding.is_inside_tree() \
			or binding.get_instance_id() != int(record.get("binding_instance_id", 0)) \
			or binding.get_parent() != host \
			or binding.get_bound_world_id() != record.get("world_id", &""):
		return &"binding_identity_drift"
	if frame == null \
			or frame.get_instance_id() != int(record.get("frame_instance_id", 0)) \
			or bootstrap.get_coordinate_frame_for_session() != frame:
		return &"coordinate_frame_identity_drift"
	return &""


func _validate_preview_and_actor(
		frame: PlanetaryCoordinateFrame,
		preview: Variant,
		actor_sample: Variant,
	) -> Dictionary:
	if not preview is Dictionary or not actor_sample is Dictionary:
		return _result(false, &"invalid_rebase_input")
	var p := preview as Dictionary
	var s := actor_sample as Dictionary
	if not bool(p.get("accepted", false)) or p.get("reason") != &"origin_rebase_preview":
		return _result(false, &"invalid_rebase_preview")
	var generation := int(p.get("coordinate_frame_generation", 0))
	if generation != frame.get_generation():
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
		if (node.get_parent() == host or node.top_level) \
				and node_is_common_world_translation_root(node):
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


## Tells every translated node that implements the optional notification seam
## that the common world just moved under it by `delta`. Each node decides what
## that means for its own frozen world-space state; nothing here inspects or
## overrides the result.
func _notify_committed_translation(
		roots: Array,
		covered: Array,
		delta: Vector3,
		requests: Array,
	) -> void:
	# A streamed world root re-expresses itself against its *own* frame, so each
	# one is told the generation its own frame just reached. Everything else in
	# the common world shares one translation and is told the requesting world's.
	var generation_by_bootstrap := {}
	var default_generation := 0
	for entry_value in requests:
		var entry := entry_value as Dictionary
		var entry_bootstrap := entry.get("bootstrap") as PlanetaryStreamingBootstrap
		var entry_target := int((entry.get("request", {}) as Dictionary).get(
			"target_generation", 0
		))
		if is_instance_valid(entry_bootstrap):
			generation_by_bootstrap[entry_bootstrap.get_instance_id()] = entry_target
		if default_generation == 0:
			default_generation = entry_target
	var notified := {}
	for group: Array in [roots, covered]:
		for record_value in group:
			var node := (record_value as Dictionary).get("node") as Node3D
			if not is_instance_valid(node) or notified.has(node.get_instance_id()):
				continue
			notified[node.get_instance_id()] = true
			if node.has_method(&"notify_common_world_translation"):
				node.call(
					&"notify_common_world_translation",
					delta,
					int(generation_by_bootstrap.get(
						node.get_instance_id(), default_generation
					)),
				)


## Opens one pending rebase on every bound frame for the same shared focus.
## Either all of them are pending on return, or none is.
func _open_pending_rebases(focus: Vector3) -> Dictionary:
	var requests: Array = []
	for world_record in _worlds:
		var world_frame := world_record.get("frame") as PlanetaryCoordinateFrame
		var source := world_frame.get_generation()
		var world_opened := world_frame.request_rebase(focus, source)
		if not bool(world_opened.get("accepted", false)):
			_cancel_pending_rebases(requests)
			return _result(
				false,
				world_opened.get("reason", &"rebase_request_rejected") as StringName,
			)
		requests.append({
			"world_id": world_record.get("world_id", &""),
			"frame": world_frame,
			"binding": world_record.get("binding"),
			"bootstrap": world_record.get("bootstrap"),
			"source_generation": source,
			"request": (world_opened.get("request", {}) as Dictionary).duplicate(true),
		})
	if requests.is_empty():
		return _result(false, &"missing_world_composition")
	return {"accepted": true, "reason": &"pending_rebases_opened", "requests": requests}


func _cancel_pending_rebases(requests: Array) -> void:
	for index in range(requests.size() - 1, -1, -1):
		var entry := requests[index] as Dictionary
		var world_frame := entry.get("frame") as PlanetaryCoordinateFrame
		var entry_request := entry.get("request", {}) as Dictionary
		var still_pending := world_frame.get_snapshot().get(
			"pending_rebase", {}
		) as Dictionary
		if int(still_pending.get("request_id", 0)) \
				== int(entry_request.get("request_id", 0)):
			world_frame.cancel_rebase(
				int(entry_request.get("request_id", 0)),
				int(entry.get("source_generation", 0)),
			)


func _request_for_world(requests: Array, world_id: StringName) -> Dictionary:
	for entry_value in requests:
		var entry := entry_value as Dictionary
		if entry.get("world_id", &"") == world_id:
			return (entry.get("request", {}) as Dictionary).duplicate(true)
	return {}


func _commit_remaining_frames(requests: Array, committed_world_id: StringName) -> bool:
	for entry_value in requests:
		var entry := entry_value as Dictionary
		if entry.get("world_id", &"") == committed_world_id:
			continue
		var world_frame := entry.get("frame") as PlanetaryCoordinateFrame
		var entry_request := entry.get("request", {}) as Dictionary
		var committed := world_frame.commit_rebase(
			int(entry_request.get("request_id", 0)),
			int(entry.get("source_generation", 0)),
		)
		if not bool(committed.get("accepted", false)):
			return false
	return true


## Hands every non-requesting world's adapter its own committed generation and
## the shared translation. Returns the first world id that refused, or `&""`.
func _reconcile_other_worlds(
		requests: Array,
		committed_world_id: StringName,
		delta: Vector3,
	) -> StringName:
	for entry_value in requests:
		var entry := entry_value as Dictionary
		var entry_world_id := entry.get("world_id", &"") as StringName
		if entry_world_id == committed_world_id:
			continue
		var other := entry.get("binding") as PlanetaryStreamingProductionBinding
		var entry_request := entry.get("request", {}) as Dictionary
		var accepted := other.accept_common_world_translation(
			delta, int(entry_request.get("target_generation", 0))
		)
		if not bool(accepted.get("accepted", false)):
			return entry_world_id
	return &""


func _public_world_generations(requests: Array) -> Dictionary:
	var generations := {}
	for entry_value in requests:
		var entry := entry_value as Dictionary
		generations[String(entry.get("world_id", &""))] = int(
			(entry.get("request", {}) as Dictionary).get("target_generation", 0)
		)
	return generations.duplicate(true)


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


func _commit_frame_rebase(
		frame: PlanetaryCoordinateFrame,
		request_id: int,
		source_generation: int,
	) -> Dictionary:
	if _commit_adapter.is_valid():
		return _commit_adapter.call(request_id, source_generation) as Dictionary
	return frame.commit_rebase(request_id, source_generation)


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
