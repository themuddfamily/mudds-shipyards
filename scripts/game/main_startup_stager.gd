class_name MainStartupStager
extends RefCounted

## Construction-only coordinator for GameFlow's opt-in boot path.
##
## The boot loader still talks to GameFlow's public wrappers. This helper owns
## only the detached-child transaction and its progress accounting, leaving
## gameplay startup, runtime bindings, lifecycle authority, and every authored
## node path with GameFlow.

## Longest a run of cheap children may hold the main loop before it yields. Six
## of the authored children cost a couple of milliseconds each, and a yield
## draws a whole frame, so they are batched; the heavy ones exceed the budget on
## their own and yield immediately after.
const STAGED_STARTUP_FRAME_BUDGET_USEC := 24_000

var _host: Node3D
var _resolve_scene_bindings: Callable
var _start_up: Callable
var _prepared := false
var _staged_children: Array[Node] = []
var _staged_child_owners: Dictionary = {}
var _staged_done := 0.0
var _staged_total := 1.0
var _staged_sink := Callable()


func _init(
		host: Node3D,
		resolve_scene_bindings: Callable,
		start_up: Callable
) -> void:
	_host = host
	_resolve_scene_bindings = resolve_scene_bindings
	_start_up = start_up


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
	if _host.is_inside_tree() or initialized or _prepared:
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
func run(initialized: bool, on_stage: Callable = Callable()) -> void:
	if not _prepared or initialized:
		return
	var tree := _host.get_tree()
	var pending := _staged_children.duplicate()
	# One unit per child, plus one for each staged builder stage a child declares,
	# plus one for the gameplay startup tail. Counting real work is what keeps the
	# bar from completing in a single jump.
	_staged_total = float(pending.size() + 1)
	for child in pending:
		if child.has_method(&"get_staged_construction_stage_count"):
			_staged_total += float(child.call(&"get_staged_construction_stage_count"))
	_staged_done = 0.0
	_staged_sink = on_stage
	var budget_started := Time.get_ticks_usec()
	for child in pending:
		_host.add_child(child)
		if _staged_child_owners.has(child):
			child.owner = _staged_child_owners[child] as Node
		_advance_stage(_stage_label(child))
		if Time.get_ticks_usec() - budget_started >= STAGED_STARTUP_FRAME_BUDGET_USEC:
			await tree.process_frame
			budget_started = Time.get_ticks_usec()
		if child.has_method(&"run_staged_construction"):
			# A bound method, not a lambda: GDScript lambdas capture locals by
			# value, so a counter incremented inside one never advances.
			await child.call(&"run_staged_construction", _advance_stage)
			budget_started = Time.get_ticks_usec()
	_staged_children.clear()
	_staged_child_owners.clear()
	_prepared = false
	_resolve_scene_bindings.call()
	_staged_done = _staged_total
	_advance_stage("Bringing systems online")
	_staged_sink = Callable()
	_start_up.call()


## Counts one finished stage and reports the new fraction to the loader.
func _advance_stage(label: String) -> void:
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
