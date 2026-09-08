class_name MainStartupStager
extends RefCounted

## Loading-frame coordinator for GameFlow's opt-in boot path.
##
## The boot loader still talks to GameFlow's public wrappers. This helper owns
## the detached-child transaction, ordered synchronous startup phases and their
## progress accounting. GameFlow retains gameplay startup, runtime bindings,
## lifecycle authority, and every authored node path.

## Longest a run of cheap children may hold the main loop before it yields. Six
## of the authored children cost a couple of milliseconds each, and a yield
## draws a whole frame, so they are batched; the heavy ones exceed the budget on
## their own and yield immediately after.
const STAGED_STARTUP_FRAME_BUDGET_USEC := 24_000

var _host: Node3D
var _resolve_scene_bindings: Callable
var _start_up: Callable
var _startup_stages: Array[Dictionary] = []
var _gameplay_startup_started := false
var _prepared := false
var _staged_children: Array[Node] = []
var _staged_child_owners: Dictionary = {}
var _staged_done := 0.0
var _staged_total := 1.0
var _staged_sink := Callable()
var _host_tree_generation := 0
var _run_generation := 0
var _active_run_generation := 0
var _active_host_tree_generation := 0


func _init(
		host: Node3D,
		resolve_scene_bindings: Callable,
		start_up: Callable,
		startup_stages: Array[Dictionary] = []
) -> void:
	_host = host
	_resolve_scene_bindings = resolve_scene_bindings
	_start_up = start_up
	_startup_stages = startup_stages.duplicate()
	_host.tree_exiting.connect(_on_host_tree_exiting)


## The host calls this only during final destruction. Tree exit alone keeps the
## transaction available for a later run on the same host.
func dispose() -> void:
	_run_generation += 1
	_cancel_stale_run()
	_prepared = false
	var owned_children := _staged_children.duplicate()
	_staged_children.clear()
	_staged_child_owners.clear()
	for child in owned_children:
		# Attached children belong to their current parent; queued nodes already
		# have a destruction owner. Only detached transaction nodes belong to us.
		if is_instance_valid(child) and child.get_parent() == null \
				and not child.is_queued_for_deletion():
			child.free()
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(_on_host_tree_exiting):
		_host.tree_exiting.disconnect(_on_host_tree_exiting)
	_host = null
	_resolve_scene_bindings = Callable()
	_start_up = Callable()
	_startup_stages.clear()


func is_prepared() -> bool:
	return _prepared


## Detaches the authored children so a boot loader can add them back one frame
## at a time instead of paying for all of them in a single main-loop iteration.
##
## Must be called while Main itself is outside the tree, which is where a loader
## has it: PackedScene.instantiate() does not enter the tree, so no `_ready()`
## has run and nothing is torn down here. Returns false - changing nothing - if
## the caller is too late, so the synchronous path stays the safe default.
func prepare(initialized: bool) -> bool:
	if not is_instance_valid(_host) or _host.is_inside_tree() or initialized or _prepared:
		return false
	_prepared = true
	for child in _host.get_children():
		_staged_child_owners[child] = child.owner
		# Cleared only for the detached interval. Godot warns about a node whose
		# owner is not one of its ancestors, and the owner is restored the moment
		# the child is back under Main.
		child.owner = null
		_host.remove_child(child)
		_staged_children.append(child)
		if child.has_method(&"prepare_staged_construction"):
			child.call(&"prepare_staged_construction")
	return true


## Re-adds the authored children a frame at a time, lets staged builders run,
## resolves GameFlow's ordinary bindings, then performs ordinary startup.
##
## `on_stage` is called as `on_stage.call(label: String, ratio: float)` where
## `ratio` is the fraction of real stages that have finished.
func run(initialized: bool, on_stage: Callable = Callable()) -> bool:
	# Leaving the tree detaches services initialized by a gameplay phase. Those
	# side effects cannot be resumed or replayed as a construction transaction;
	# an interrupted tail needs a fresh Main, which the loader already enforces.
	if not _prepared or initialized or _gameplay_startup_started \
			or _active_run_generation != 0:
		return false
	_run_generation += 1
	var run_generation := _run_generation
	var host_tree_generation := _host_tree_generation
	if not _is_run_current(run_generation, host_tree_generation):
		return false
	_active_run_generation = run_generation
	_active_host_tree_generation = host_tree_generation
	var tree := _host.get_tree()
	var pending := _staged_children.duplicate()
	# One unit per child, plus one for each staged builder stage a child declares,
	# plus one per gameplay startup phase. Legacy callers retain one synchronous
	# tail callback; progress completes only after all of its work has returned.
	var startup_stages := _startup_stages.duplicate()
	if startup_stages.is_empty():
		startup_stages.append({"label": "Bringing systems online", "run": _start_up})
	_staged_total = float(pending.size() + startup_stages.size())
	for child in pending:
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		if child.has_method(&"get_staged_construction_stage_count"):
			_staged_total += float(child.call(&"get_staged_construction_stage_count"))
	_staged_done = 0.0
	_staged_sink = on_stage
	var budget_started := Time.get_ticks_usec()
	for child in pending:
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			_cancel_stale_run()
			return false
		if child.get_parent() == null:
			_host.add_child(child)
		elif child.get_parent() != _host:
			_cancel_stale_run()
			return false
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		if _staged_child_owners.has(child):
			child.owner = _staged_child_owners[child] as Node
		_advance_stage(_stage_label(child))
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		if Time.get_ticks_usec() - budget_started >= STAGED_STARTUP_FRAME_BUDGET_USEC:
			await tree.process_frame
			if not _is_run_current(run_generation, host_tree_generation):
				_cancel_stale_run()
				return false
			budget_started = Time.get_ticks_usec()
		if child.has_method(&"run_staged_construction"):
			# A bound method, not a lambda: GDScript lambdas capture locals by
			# value, so a counter incremented inside one never advances.
			var completed: Variant = await child.call(&"run_staged_construction", _advance_stage)
			# Legacy builders have no return value. A builder that reports a
			# failed/incomplete transaction must not admit gameplay startup.
			if completed is bool and not completed:
				_cancel_stale_run()
				return false
			if not _is_run_current(run_generation, host_tree_generation):
				_cancel_stale_run()
				return false
			budget_started = Time.get_ticks_usec()
	if not _is_run_current(run_generation, host_tree_generation):
		_cancel_stale_run()
		return false
	_staged_children.clear()
	_staged_child_owners.clear()
	_resolve_scene_bindings.call()
	if not _is_run_current(run_generation, host_tree_generation):
		_cancel_stale_run()
		return false
	for stage: Dictionary in startup_stages:
		# Present the finished construction/previous phase before another costly
		# phase. Direct Main startup executes the same callbacks without yielding.
		await tree.process_frame
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		_gameplay_startup_started = true
		(stage.run as Callable).call()
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
		_advance_stage(String(stage.label))
		if not _is_run_current(run_generation, host_tree_generation):
			_cancel_stale_run()
			return false
	_prepared = false
	_staged_sink = Callable()
	_active_run_generation = 0
	_active_host_tree_generation = 0
	return true


func _on_host_tree_exiting() -> void:
	# A host can leave and re-enter during one awaited staged-builder callback.
	# The generation makes that stale continuation fail closed even if it resumes
	# after the host has already been reattached.
	_host_tree_generation += 1


func _is_run_current(run_generation: int, host_tree_generation: int) -> bool:
	return (
		run_generation == _run_generation
		and host_tree_generation == _host_tree_generation
		and is_instance_valid(_host)
		and _host.is_inside_tree()
		and not _host.is_queued_for_deletion()
	)


func _cancel_stale_run() -> void:
	# Retain the detached-child transaction for the owning host's teardown, but
	# drop the loader callback so a stale generation cannot publish more progress.
	_staged_sink = Callable()
	_active_run_generation = 0
	_active_host_tree_generation = 0


## Counts one finished stage and reports the new fraction to the loader.
func _advance_stage(label: String) -> void:
	if (
		_active_run_generation != 0
		and not _is_run_current(_active_run_generation, _active_host_tree_generation)
	):
		return
	_staged_done = minf(_staged_done + 1.0, _staged_total)
	if _staged_sink.is_valid():
		_staged_sink.call(
			label,
			clampf(_staged_done / maxf(_staged_total, 1.0), 0.0, 1.0)
		)


func _stage_label(child: Node) -> String:
	if child is HeroShip or child is RangeOpponent:
		return "Preparing %s" % String(child.name).capitalize()
	if child.name == &"ShipyardWorld":
		return "Raising the shipyard"
	if child.name == &"Player":
		return "Waking the pilot"
	return "Preparing %s" % String(child.name).capitalize()
