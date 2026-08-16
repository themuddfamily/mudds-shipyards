class_name WorldStreamingCoordinator
extends Node3D

## Generation-safe owner for explicitly requested world-location scene roots.
##
## This is a deliberately small streaming seam. A registered
## [WorldLocationDefinition] supplies stable identity and its station-relative
## anchor. Scene selection is either an optional [PackedScene] binding supplied
## at registration or an injected asynchronous loader. The coordinator does not
## decide *when* a location is near enough to load and owns no activity, reward,
## ship, berth, save, network, or gameplay authority.
##
## An injected loader is a Callable with this contract:
##
##     loader.call(definition, generation, completion) -> bool
##
## It returns whether it accepted the request. It may call the completion before
## returning (synchronous), or later (asynchronous):
##
##     completion.call(location_id, generation, packed_scene, error_reason)
##
## `error_reason` is empty on success. Every completion is checked against the
## current pending generation before a scene can be instantiated. A synchronous
## completion is returned directly by [method request_load]; `load_requested`
## means only that an asynchronous request was accepted and remains pending.

signal location_load_started(location_id: StringName, generation: int)
signal location_loaded(location_id: StringName, generation: int, instance: Node3D)
signal location_load_failed(location_id: StringName, generation: int, reason: StringName)
signal location_unloaded(location_id: StringName, generation: int)

const SCHEMA_VERSION := 1
const NO_ERROR: StringName = &""

var _definitions: Dictionary = {}
var _scene_bindings: Dictionary = {}
var _generation_by_id: Dictionary = {}
var _loading: Dictionary = {}
var _loaded: Dictionary = {}
var _scene_entry_in_progress: Dictionary = {}
var _loader := Callable()
var _dispatching_requests: Dictionary = {}
var _synchronous_results: Dictionary = {}
var _load_request_count := 0
var _load_failure_count := 0
var _unload_count := 0
var _tree_entry_epoch := 0


func _enter_tree() -> void:
	# A child `tree_exiting` event followed by a different coordinator entry epoch
	# is a whole-coordinator detach/re-entry, not independent child retirement.
	_tree_entry_epoch += 1


## Installs an asynchronous loader. Changing the loader while a request is in
## flight is rejected so that every callback has one unambiguous producer.
func set_loader(loader: Callable) -> bool:
	if not loader.is_valid() or not _loading.is_empty() or not _scene_entry_in_progress.is_empty():
		return false
	_loader = loader
	return true


## Registers a valid definition once. All fields are deep-copied into a detached
## snapshot; neither the caller nor an injected loader receives the internal
## snapshot, so later resource mutation cannot change identity or placement. The
## optional scene binding is used by the built-in deferred loader.
func register_location(definition: WorldLocationDefinition, scene: PackedScene = null) -> bool:
	if definition == null or not definition.is_definition_valid():
		return false
	var snapshot := definition.duplicate(true) as WorldLocationDefinition
	if snapshot == null or not snapshot.is_definition_valid():
		return false
	var location_id := snapshot.location_id
	if _definitions.has(location_id):
		return false
	_definitions[location_id] = snapshot
	if scene != null:
		_scene_bindings[location_id] = scene
	if not _generation_by_id.has(location_id):
		_generation_by_id[location_id] = 0
	return true


## Removes a definition and retires any pending or loaded generation. Loaded
## scene roots are queue-freed; callbacks that arrive after re-registration are
## stale because generation tombstones deliberately survive unregistration.
func unregister_location(location_id: StringName) -> bool:
	if not _definitions.has(location_id):
		return false
	_reconcile_loaded_location(location_id)
	var had_active_state := _loading.has(location_id) or _loaded.has(location_id)
	var retirement_generation := int(_generation_by_id.get(location_id, 0))
	if had_active_state:
		retirement_generation = _advance_generation(location_id)
	var instance := _get_loaded_instance_raw(location_id)
	_loading.erase(location_id)
	_loaded.erase(location_id)
	_scene_bindings.erase(location_id)
	_definitions.erase(location_id)
	if not _is_scene_entry_instance(location_id, instance):
		_detach_and_queue_free(instance)
	if had_active_state:
		_unload_count += 1
		location_unloaded.emit(location_id, retirement_generation)
	return true


## Starts exactly one load generation. State is committed before either the
## signal or loader is invoked, so synchronous fake loaders are safe too.
func request_load(location_id: StringName) -> Dictionary:
	if not _definitions.has(location_id):
		return _result(false, &"unknown_location", location_id, -1)
	_reconcile_loaded_location(location_id)
	# Removing a node from inside its own `_enter_tree()` is unsafe in Godot. A
	# reentrant retirement is logically committed immediately, but physical
	# detach waits until the surrounding `add_child()` returns. Do not permit a
	# nested replacement load during that tiny protected interval.
	if _scene_entry_in_progress.has(location_id):
		return _result(
			false,
			&"scene_entry_retirement_in_progress",
			location_id,
			int(_generation_by_id.get(location_id, 0))
		)
	if _loading.has(location_id):
		return _result(
			false,
			&"already_loading",
			location_id,
			int((_loading[location_id] as Dictionary).get("generation", -1))
		)
	if _loaded.has(location_id):
		return _result(
			false,
			&"already_loaded",
			location_id,
			int((_loaded[location_id] as Dictionary).get("generation", -1))
		)

	var generation := _advance_generation(location_id)
	_loading[location_id] = {"generation": generation}
	_load_request_count += 1
	location_load_started.emit(location_id, generation)
	# A signal observer is allowed to cancel or unregister immediately. Do not
	# dispatch work after that committed transition has already been retired.
	if not _definitions.has(location_id) or not _is_loading_generation(location_id, generation):
		return _result(false, &"cancelled_during_start_signal", location_id, generation)

	# Loaders receive a disposable copy, not the placement authority retained by
	# the coordinator. A loader may annotate or even corrupt its copy without
	# changing the registered ID or anchor.
	var definition := (_definitions[location_id] as WorldLocationDefinition).duplicate(true) \
		as WorldLocationDefinition
	var completion := Callable(self, "complete_load")
	var loader := _loader if _loader.is_valid() else Callable(self, "_request_bound_scene")
	var request_key := _request_key(location_id, generation)
	_dispatching_requests[request_key] = true
	var loader_accepted := bool(loader.call(definition, generation, completion))
	_dispatching_requests.erase(request_key)
	if _synchronous_results.has(request_key):
		var synchronous_result := (_synchronous_results[request_key] as Dictionary).duplicate(true)
		_synchronous_results.erase(request_key)
		return synchronous_result
	if not _is_loading_generation(location_id, generation):
		# A loader is not expected to mutate coordinator lifecycle directly, but a
		# reentrant retirement is still a committed result, never an async ack.
		return _result(false, &"retired_during_loader_dispatch", location_id, generation)
	if not loader_accepted and _is_loading_generation(location_id, generation):
		_commit_load_failure(location_id, generation, &"loader_rejected")
		return _result(false, &"loader_rejected", location_id, generation)
	# This is strictly an asynchronous-request acknowledgement: the generation
	# remains pending and no load outcome has been claimed yet.
	return _result(true, &"load_requested", location_id, generation)


## Generation-checked completion entry point handed to loaders. A callback may
## commit either one scene or one failure; duplicates, unknown IDs and callbacks
## retired by unload/re-registration cannot change state.
func complete_load(
	location_id: StringName,
	generation: int,
	packed_scene: PackedScene,
	error_reason: StringName = NO_ERROR
) -> Dictionary:
	if not _definitions.has(location_id):
		return _completion_result(false, &"unknown_location", location_id, generation)
	_reconcile_loaded_location(location_id)
	if not _loading.has(location_id):
		var loaded_record := _loaded.get(location_id, {}) as Dictionary
		if int(loaded_record.get("generation", -1)) == generation:
			return _completion_result(false, &"duplicate_completion", location_id, generation)
		if generation != int(_generation_by_id.get(location_id, 0)):
			return _completion_result(false, &"stale_generation", location_id, generation)
		return _completion_result(false, &"no_pending_load", location_id, generation)
	var expected_generation := int((_loading[location_id] as Dictionary).get("generation", -1))
	if generation != expected_generation:
		return _completion_result(false, &"stale_generation", location_id, generation)
	if not error_reason.is_empty() or packed_scene == null:
		var failure_reason := error_reason if not error_reason.is_empty() else &"missing_packed_scene"
		_commit_load_failure(location_id, generation, failure_reason)
		return _completion_result(true, failure_reason, location_id, generation)

	var candidate := packed_scene.instantiate()
	if not candidate is Node3D:
		if candidate != null:
			candidate.queue_free()
		_commit_load_failure(location_id, generation, &"scene_root_not_node_3d")
		return _completion_result(true, &"scene_root_not_node_3d", location_id, generation)

	var definition := _definitions[location_id] as WorldLocationDefinition
	var instance := candidate as Node3D
	instance.name = _instance_name(location_id)
	instance.top_level = false
	instance.transform = Transform3D(Basis.IDENTITY, definition.get_anchor_position())
	instance.set_meta(&"world_location_id", location_id)
	instance.set_meta(&"world_location_generation", generation)
	# Provisional ownership must exist before `_enter_tree()`/`_ready()` run. A
	# scene callback can now unload or unregister this exact generation instead of
	# observing `_loading` and being overwritten after `add_child()` returns.
	_loading.erase(location_id)
	var tree_exiting_callable := Callable(self, "_on_loaded_root_tree_exiting").bind(
		location_id, generation, instance.get_instance_id()
	)
	instance.tree_exiting.connect(tree_exiting_callable)
	_loaded[location_id] = {
		"generation": generation,
		"instance": instance,
		"tree_exiting_callable": tree_exiting_callable,
	}
	_scene_entry_in_progress[location_id] = {
		"generation": generation,
		"instance": instance,
	}
	add_child(instance)
	var entry_record := _scene_entry_in_progress.get(location_id, {}) as Dictionary
	if int(entry_record.get("generation", -1)) == generation \
		and entry_record.get("instance") == instance:
		_scene_entry_in_progress.erase(location_id)
	var committed_record := _loaded.get(location_id, {}) as Dictionary
	var still_committed: bool = (
		int(committed_record.get("generation", -1)) == generation
		and committed_record.get("instance") == instance
	)
	if still_committed and instance.is_queued_for_deletion():
		_retire_unexpected_loaded_root(location_id, generation, instance.get_instance_id())
		still_committed = false
	if not still_committed:
		_detach_and_queue_free(instance)
		return _completion_result(false, &"retired_during_scene_entry", location_id, generation)
	if instance.get_parent() != self:
		_loaded.erase(location_id)
		_detach_and_queue_free(instance)
		_load_failure_count += 1
		location_load_failed.emit(location_id, generation, &"scene_parenting_failed")
		return _completion_result(true, &"scene_parenting_failed", location_id, generation)
	location_loaded.emit(location_id, generation, instance)
	return _completion_result(true, &"loaded", location_id, generation)


## Retires a pending request or loaded instance. The generation advances before
## queue-free and before the signal, making any racing completion stale and all
## signal observers see the final unloaded state.
func request_unload(location_id: StringName) -> Dictionary:
	if not _definitions.has(location_id):
		return _result(false, &"unknown_location", location_id, -1)
	_reconcile_loaded_location(location_id)
	if not _loading.has(location_id) and not _loaded.has(location_id):
		return _result(
			false,
			&"already_unloaded",
			location_id,
			int(_generation_by_id.get(location_id, 0))
		)
	var retirement_generation := _advance_generation(location_id)
	var instance := _get_loaded_instance_raw(location_id)
	_loading.erase(location_id)
	_loaded.erase(location_id)
	if not _is_scene_entry_instance(location_id, instance):
		_detach_and_queue_free(instance)
	_unload_count += 1
	location_unloaded.emit(location_id, retirement_generation)
	return _result(true, &"unloaded", location_id, retirement_generation)


func get_definition(location_id: StringName) -> WorldLocationDefinition:
	var definition := _definitions.get(location_id) as WorldLocationDefinition
	return definition.duplicate(true) as WorldLocationDefinition if definition != null else null


func get_loaded_instance(location_id: StringName) -> Node3D:
	_reconcile_loaded_location(location_id)
	return _get_loaded_instance_raw(location_id)


func _get_loaded_instance_raw(location_id: StringName) -> Node3D:
	var record := _loaded.get(location_id, {}) as Dictionary
	var candidate: Variant = record.get("instance")
	if not is_instance_valid(candidate):
		return null
	return candidate as Node3D


func get_loaded_ids() -> PackedStringArray:
	_reconcile_all_loaded_locations()
	return _sorted_ids(_loaded)


func get_loading_ids() -> PackedStringArray:
	return _sorted_ids(_loading)


## A deep-copy operational report. It intentionally carries identifiers and
## immutable snapshots rather than Resource or Node references, so an audit
## consumer cannot acquire mutation authority over the coordinator.
func audit() -> Dictionary:
	var loading_records: Array[Dictionary] = []
	for location_id_string in get_loading_ids():
		var location_id := StringName(location_id_string)
		var record := _loading[location_id] as Dictionary
		loading_records.append({
			"location_id": location_id,
			"generation": int(record.get("generation", -1)),
		})
	var loaded_records: Array[Dictionary] = []
	for location_id_string in get_loaded_ids():
		var location_id := StringName(location_id_string)
		var record := _loaded[location_id] as Dictionary
		var instance := _get_loaded_instance_raw(location_id)
		loaded_records.append({
			"location_id": location_id,
			"generation": int(record.get("generation", -1)),
			"instance_id": instance.get_instance_id() if is_instance_valid(instance) else 0,
			"parent_is_coordinator": is_instance_valid(instance) and instance.get_parent() == self,
			"local_transform": instance.transform if is_instance_valid(instance) else Transform3D.IDENTITY,
		})
	var report := {
		"schema_version": SCHEMA_VERSION,
		"registered_ids": _sorted_ids(_definitions),
		"loading_ids": get_loading_ids(),
		"loaded_ids": get_loaded_ids(),
		"loading_records": loading_records,
		"loaded_records": loaded_records,
		"generation_by_id": _generation_by_id.duplicate(true),
		"load_request_count": _load_request_count,
		"load_failure_count": _load_failure_count,
		"unload_count": _unload_count,
		"owned_instance_count": _loaded.size(),
		"definition_snapshot_policy": &"deep_copy_on_registration_loader_dispatch_and_read",
		"parenting_policy": &"coordinator_child",
		"transform_policy": &"identity_basis_at_definition_anchor",
		"automatic_distance_policy": false,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}
	return report.duplicate(true)


func _request_bound_scene(
	definition: WorldLocationDefinition,
	generation: int,
	completion: Callable
) -> bool:
	var scene := _scene_bindings.get(definition.location_id) as PackedScene
	var error_reason: StringName = NO_ERROR if scene != null else &"missing_scene_binding"
	completion.call_deferred(definition.location_id, generation, scene, error_reason)
	return true


func _commit_load_failure(location_id: StringName, generation: int, reason: StringName) -> void:
	if not _is_loading_generation(location_id, generation):
		return
	_loading.erase(location_id)
	_load_failure_count += 1
	location_load_failed.emit(location_id, generation, reason)


func _on_loaded_root_tree_exiting(
	location_id: StringName,
	generation: int,
	instance_id: int
) -> void:
	# Tree propagation has not finished while this signal runs. Reconcile after
	# it does so a child exit can be distinguished from its coordinator leaving
	# the tree with the owned subtree intact.
	call_deferred(
		"_reconcile_exited_loaded_root",
		location_id,
		generation,
		instance_id,
		_tree_entry_epoch
	)


func _reconcile_exited_loaded_root(
	location_id: StringName,
	generation: int,
	instance_id: int,
	observed_tree_epoch: int
) -> void:
	var record := _loaded.get(location_id, {}) as Dictionary
	if int(record.get("generation", -1)) != generation:
		return
	var instance := _get_loaded_instance_raw(location_id)
	if is_instance_valid(instance) and instance.get_instance_id() != instance_id:
		return
	if is_instance_valid(instance) and instance.get_parent() == self \
		and not instance.is_queued_for_deletion():
		# Still parented while the coordinator is out of tree, or parented after a
		# new entry epoch, means the whole owned subtree detached/re-entered.
		if not is_inside_tree() or _tree_entry_epoch != observed_tree_epoch:
			return
	_retire_unexpected_loaded_root(location_id, generation, instance_id)


func _reconcile_all_loaded_locations() -> void:
	var location_ids := _loaded.keys()
	for location_id_value in location_ids:
		_reconcile_loaded_location(StringName(location_id_value))


func _reconcile_loaded_location(location_id: StringName) -> void:
	var record := _loaded.get(location_id, {}) as Dictionary
	if record.is_empty():
		return
	var generation := int(record.get("generation", -1))
	var instance := _get_loaded_instance_raw(location_id)
	if is_instance_valid(instance) and instance.get_parent() == self \
		and not instance.is_queued_for_deletion():
		return
	var instance_id := instance.get_instance_id() if is_instance_valid(instance) else 0
	_retire_unexpected_loaded_root(location_id, generation, instance_id)


func _retire_unexpected_loaded_root(
	location_id: StringName,
	expected_generation: int,
	expected_instance_id: int
) -> bool:
	var record := _loaded.get(location_id, {}) as Dictionary
	if int(record.get("generation", -1)) != expected_generation:
		return false
	var instance := _get_loaded_instance_raw(location_id)
	if is_instance_valid(instance) and expected_instance_id > 0 \
		and instance.get_instance_id() != expected_instance_id:
		return false
	# Erase before physical teardown. Its tree-exiting callback therefore sees no
	# matching record and intentional or reconciliation teardown cannot double
	# signal or advance the generation twice.
	_loaded.erase(location_id)
	var retirement_generation := _advance_generation(location_id)
	_detach_and_queue_free(instance)
	_unload_count += 1
	location_unloaded.emit(location_id, retirement_generation)
	return true


func _detach_and_queue_free(instance: Node3D) -> void:
	if not is_instance_valid(instance):
		return
	# Detach first. `queue_free()` deliberately defers deletion, whereas the
	# stable child name must become reusable in this same call stack.
	if instance.get_parent() == self:
		remove_child(instance)
	if not instance.is_queued_for_deletion():
		instance.queue_free()


func _is_scene_entry_instance(location_id: StringName, instance: Node3D) -> bool:
	if not is_instance_valid(instance):
		return false
	var entry_record := _scene_entry_in_progress.get(location_id, {}) as Dictionary
	return entry_record.get("instance") == instance


func _is_loading_generation(location_id: StringName, generation: int) -> bool:
	if not _loading.has(location_id):
		return false
	return int((_loading[location_id] as Dictionary).get("generation", -1)) == generation


func _advance_generation(location_id: StringName) -> int:
	var generation := int(_generation_by_id.get(location_id, 0)) + 1
	_generation_by_id[location_id] = generation
	return generation


func _sorted_ids(source: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for location_id: StringName in source:
		ids.append(str(location_id))
	ids.sort()
	return ids


func _instance_name(location_id: StringName) -> String:
	return "WorldLocation_%s" % str(location_id).to_pascal_case()


func _request_key(location_id: StringName, generation: int) -> String:
	return "%s:%d" % [str(location_id), generation]


func _completion_result(
	accepted: bool,
	reason: StringName,
	location_id: StringName,
	generation: int
) -> Dictionary:
	var result := _result(accepted, reason, location_id, generation)
	var request_key := _request_key(location_id, generation)
	# Only retain a result while its loader call is on the stack. Async outcomes
	# never accumulate bookkeeping, and the first synchronous completion wins if
	# a broken loader invokes the callback more than once.
	if _dispatching_requests.has(request_key) and not _synchronous_results.has(request_key):
		_synchronous_results[request_key] = result.duplicate(true)
	return result


func _result(
	accepted: bool,
	reason: StringName,
	location_id: StringName,
	generation: int
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"location_id": location_id,
		"generation": generation,
	}
