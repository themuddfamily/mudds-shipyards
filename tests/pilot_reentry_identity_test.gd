extends SceneTree

const PRESENTATION_SCENE := preload("res://scenes/player/pilot_skinned_presentation.tscn")
const REENTRY_CYCLE_COUNT := 3

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "PilotReentryHost"
	root.add_child(host)
	var presentation := PRESENTATION_SCENE.instantiate() as PilotSkinnedPresentation
	_check(presentation != null, "pilot presentation instantiates for lifecycle testing")
	if presentation == null:
		_finish()
		return
	host.add_child(presentation)
	await process_frame

	var fixed_nodes := _authored_node_identity_snapshot(presentation)
	var fixed_runtime_contract := _named_runtime_identity_snapshot(presentation)
	var initial_simulators := _compat_simulators(presentation)
	_check(not fixed_nodes.is_empty(), "pilot presentation publishes a non-empty runtime hierarchy")
	_check(
		_named_runtime_contract_is_exact(presentation),
		"pilot fixture resolves the exact wrapper/import/art/rig/skeleton/suit/animation hierarchy"
	)
	_check(
		initial_simulators.size() == 1
		and not initial_simulators[0].is_simulating_physics()
		and presentation.find_children("*", "PhysicalBoneSimulator3D", true, false).size() == 1
		and presentation.find_children("*", "PhysicalBone3D", true, false).is_empty(),
		"attached pilot owns exactly one inactive engine compatibility simulator and no physical bones"
	)
	var prior_simulator := initial_simulators[0] if initial_simulators.size() == 1 else null
	for cycle in REENTRY_CYCLE_COUNT:
		var prior_simulator_id := (
			prior_simulator.get_instance_id()
			if is_instance_valid(prior_simulator)
			else 0
		)
		var prior_simulator_ref: WeakRef = weakref(prior_simulator)
		host.remove_child(presentation)
		await process_frame
		host.add_child(presentation)
		await process_frame
		var restored_nodes := _authored_node_identity_snapshot(presentation)
		if restored_nodes != fixed_nodes:
			print("PILOT_REENTRY_IDENTITY_DIFF cycle=%d: %s" % [cycle + 1, _identity_diff(fixed_nodes, restored_nodes)])
		_check(
			restored_nodes == fixed_nodes,
			"re-entry cycle %d preserves every authored pilot node path, type, and ObjectID" % (cycle + 1)
		)
		_check(
			_named_runtime_identity_snapshot(presentation) == fixed_runtime_contract
			and _named_runtime_contract_is_exact(presentation),
			"re-entry cycle %d preserves exact wrapper/import/art/rig/skeleton/suit/animation identities" % (cycle + 1)
		)
		var restored_simulators := _compat_simulators(presentation)
		var restored_simulator := (
			restored_simulators[0]
			if restored_simulators.size() == 1
			else null
		)
		_check(
			restored_simulator != null
			and restored_simulator.get_instance_id() != prior_simulator_id
			and prior_simulator_ref.get_ref() == null
			and not restored_simulator.is_simulating_physics()
			and presentation.find_children("*", "PhysicalBoneSimulator3D", true, false).size() == 1
			and presentation.find_children("*", "PhysicalBone3D", true, false).is_empty(),
			"re-entry cycle %d replaces only the one inactive internal engine compatibility simulator" % (cycle + 1)
		)
		prior_simulator = restored_simulator
		_check(
			bool(presentation.get_asset_audit_report().get("valid", false)),
			"re-entry cycle %d keeps the pilot asset audit valid" % (cycle + 1)
		)

	host.queue_free()
	await process_frame
	await process_frame
	_finish()


func _authored_node_identity_snapshot(search_root: Node) -> Dictionary:
	var snapshot := {
		".": {
			"type": search_root.get_class(),
			"instance_id": search_root.get_instance_id(),
		},
	}
	for node in search_root.find_children("*", "", true, false):
		if _is_engine_pilot_compat_simulator(node):
			continue
		var relative_path := String(search_root.get_path_to(node))
		snapshot[relative_path] = {
			"type": node.get_class(),
			"instance_id": node.get_instance_id(),
		}
	return snapshot


func _named_runtime_identity_snapshot(presentation: PilotSkinnedPresentation) -> Dictionary:
	var visual_root := presentation.get_visual_root()
	var rig := visual_root.get_node_or_null("PilotRig") if visual_root != null else null
	var skeleton := presentation.get_skeleton()
	var suit := (
		visual_root.find_child("PilotSuit", true, false)
		if visual_root != null
		else null
	)
	var animation_player := presentation.get_animation_player()
	var import_root := visual_root.get_parent() if visual_root != null else null
	return {
		"wrapper": presentation.get_instance_id(),
		"import": import_root.get_instance_id() if import_root != null else 0,
		"art": visual_root.get_instance_id() if visual_root != null else 0,
		"rig": rig.get_instance_id() if rig != null else 0,
		"skeleton": skeleton.get_instance_id() if skeleton != null else 0,
		"suit": suit.get_instance_id() if suit != null else 0,
		"animation_player": animation_player.get_instance_id() if animation_player != null else 0,
	}


func _named_runtime_contract_is_exact(presentation: PilotSkinnedPresentation) -> bool:
	var visual_root := presentation.get_visual_root()
	if visual_root == null or visual_root.name != &"PilotArt":
		return false
	var import_root := visual_root.get_parent()
	var rig := visual_root.get_node_or_null("PilotRig")
	var skeleton := presentation.get_skeleton()
	var suit := visual_root.find_child("PilotSuit", true, false)
	var animation_player := presentation.get_animation_player()
	return (
		presentation.name == &"PilotSkinnedPresentation"
		and import_root != null
		and import_root.name == &"PilotMotionImport"
		and import_root.get_parent() == presentation
		and rig != null
		and rig.get_parent() == visual_root
		and skeleton != null
		and skeleton.name == &"PilotSkeleton"
		and skeleton.get_parent() == rig
		and suit is MeshInstance3D
		and skeleton.is_ancestor_of(suit)
		and animation_player != null
		and animation_player.name == &"PilotAnimationPlayer"
		and import_root.is_ancestor_of(animation_player)
	)


func _compat_simulators(search_root: Node) -> Array[PhysicalBoneSimulator3D]:
	var result: Array[PhysicalBoneSimulator3D] = []
	for candidate in search_root.find_children("*", "PhysicalBoneSimulator3D", true, false):
		if _is_engine_pilot_compat_simulator(candidate):
			result.append(candidate as PhysicalBoneSimulator3D)
	return result


func _is_engine_pilot_compat_simulator(node: Node) -> bool:
	if not node is PhysicalBoneSimulator3D:
		return false
	var skeleton := node.get_parent() as Skeleton3D
	if skeleton == null or skeleton.name != &"PilotSkeleton":
		return false
	var runtime_name := String(node.name)
	const GENERATED_PREFIX := "@PhysicalBoneSimulator3D@"
	if not runtime_name.begins_with(GENERATED_PREFIX):
		return false
	if not runtime_name.trim_prefix(GENERATED_PREFIX).is_valid_int():
		return false
	if not skeleton.get_children(true).has(node) or skeleton.get_children(false).has(node):
		return false
	var rig := skeleton.get_parent()
	var art := rig.get_parent() if rig != null else null
	var import_root := art.get_parent() if art != null else null
	var presentation := import_root.get_parent() if import_root != null else null
	return (
		rig != null
		and rig.name == &"PilotRig"
		and art != null
		and art.name == &"PilotArt"
		and import_root != null
		and import_root.name == &"PilotMotionImport"
		and presentation is PilotSkinnedPresentation
	)


func _identity_diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var removed := {}
	var added := {}
	var changed := {}
	for path in before:
		if not after.has(path):
			removed[path] = before[path]
		elif after[path] != before[path]:
			changed[path] = {"before": before[path], "after": after[path]}
	for path in after:
		if not before.has(path):
			added[path] = after[path]
	return {"removed": removed, "added": added, "changed": changed}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("PILOT_REENTRY_IDENTITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("PILOT_REENTRY_IDENTITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
