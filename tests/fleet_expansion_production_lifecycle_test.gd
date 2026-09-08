extends SceneTree

const BINDING := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	await _test_staged_assembly_reentry()
	await _test_staged_queued_cleanup()
	var binding := BINDING.new()
	root.add_child(binding)
	await process_frame
	await process_frame
	for row in binding.get_fleet_snapshot().get("craft", []) as Array:
		var craft_id: StringName = (row as Dictionary).get("craft_id", &"")
		var contract: Dictionary = binding.get_craft_compatibility_contract(craft_id)
		_check(bool(contract.get("accepted", false)) and bool(contract.get("valid", false)), "%s has an exact berth/access compatibility contract" % craft_id)
		_check((contract.get("seat_anchor", Vector3.INF) as Vector3).is_finite() and (contract.get("boarding_anchor", Vector3.INF) as Vector3).is_finite(), "%s publishes finite seat and boarding anchors" % craft_id)
		var reset: Dictionary = binding.reset_craft_for_reuse(craft_id)
		_check(bool(reset.get("accepted", false)) and int(reset.get("receipt_id", 0)) > 0, "%s accepts one HeroShip reuse reset generation" % craft_id)
		_check(bool(reset.get("attachment_preserved", false)), "%s remains attached after reuse reset" % craft_id)
	var craft_instance_ids: Dictionary = {}
	for row in binding.get_fleet_snapshot().get("craft", []) as Array:
		craft_instance_ids[(row as Dictionary).craft_id] = (row as Dictionary).instance_id
	root.remove_child(binding)
	var exited_audio_bindings := binding.get("_audio_bindings") as Dictionary
	for craft_id: StringName in exited_audio_bindings:
		var audio := (exited_audio_bindings[craft_id] as RefCounted).get_snapshot() as Dictionary
		_check(
			not bool(audio.get("attached", true))
				and (audio.get("payload_audio", {}) as Dictionary).is_empty(),
			"%s releases caller-owned audio on tree exit" % craft_id
		)
	root.add_child(binding)
	await process_frame
	for row in binding.get_fleet_snapshot().get("craft", []) as Array:
		var craft_id: StringName = (row as Dictionary).craft_id
		_check(
			bool(((row as Dictionary).audio as Dictionary).get("attached", false))
				and int((row as Dictionary).instance_id) == int(craft_instance_ids.get(craft_id, 0)),
			"%s restores audio without replacing gameplay state on tree re-entry" % craft_id
		)
	binding.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_production_lifecycle_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_staged_assembly_reentry() -> void:
	var binding := BINDING.new()
	binding.prepare_staged_construction()
	root.add_child(binding)
	await process_frame
	await process_frame
	_check(binding.get_child_count() == 0,
		"opt-in staged fleet waits for its startup owner instead of deferred assembly")
	var stages: Array[String] = []
	var frames: Array[int] = []
	var identities: Dictionary = {}
	var sink := func(label: String) -> void:
		stages.append(label)
		frames.append(Engine.get_process_frames())
		for spec in BINDING.CRAFT_SPECS:
			var craft := binding.get_node_or_null(NodePath(spec.craft_id)) as HeroShip
			if craft != null:
				if identities.has(spec.craft_id):
					_check(identities[spec.craft_id] == craft.get_instance_id(),
						"partial fleet construction retains existing craft identities")
				identities[spec.craft_id] = craft.get_instance_id()
		# A competing call from the progress sink cannot build a second unit.
		BINDING.run_staged_construction(weakref(binding))
		if stages.size() in [2, 4]:
			root.remove_child(binding)
			root.add_child(binding)
	var first_run: bool = await BINDING.run_staged_construction(weakref(binding), sink)
	var partial_children := binding.get_children()
	await process_frame
	await process_frame
	_check(not first_run and stages.size() == 2 and not binding.is_composition_ready()
		and binding.get_children() == partial_children,
		"partial detach/reentry cancels the old fleet run without deferred duplicates")
	var second_run: bool = await BINDING.run_staged_construction(weakref(binding), sink)
	_check(not second_run and stages.size() == 4 and not binding.is_composition_ready(),
		"detachment in the final craft callback cancels completion before the settle frame")
	BINDING.run_staged_construction(weakref(binding), sink)
	_check(not binding.is_composition_ready(),
		"resuming the final craft still waits a process frame before attachment")
	await process_frame
	await process_frame
	_check(binding.is_composition_ready() and bool(binding.get_audit_report().valid),
		"resumed staged fleet completes its live production audit and attachments")
	var separated := frames.size() == BINDING.get_staged_construction_stage_count()
	for index in range(1, frames.size()):
		separated = separated and frames[index] > frames[index - 1]
	_check(separated, "berths and each Cinder craft construct on separate process frames")
	_check(stages == ["Preparing Cinder fleet berths", "Preparing Cinder Cargo Hauler",
		"Preparing Cinder Long Range Bomber", "Preparing Cinder Light Interceptor"],
		"staged fleet progress reports each real construction unit once in authored order")
	for index in BINDING.CRAFT_SPECS.size():
		var spec := BINDING.CRAFT_SPECS[index]
		var craft := binding.get_child(index + 1) as HeroShip
		var contract := binding.get_craft_compatibility_contract(spec.craft_id)
		_check(craft != null and craft.name == spec.craft_id
			and craft.get_instance_id() == identities[spec.craft_id]
			and craft.global_transform.is_equal_approx(contract.landing_transform)
			and float(craft.get_telemetry().get("hull", 0.0)) == craft.maximum_hull and craft.velocity == Vector3.ZERO
			and craft.process_mode == Node.PROCESS_MODE_INHERIT,
			"%s preserves identity, order, full hull and exact physical berth without process overrides" % spec.craft_id)
	binding.queue_free()
	await process_frame


func _test_staged_queued_cleanup() -> void:
	var binding := BINDING.new()
	binding.prepare_staged_construction()
	root.add_child(binding)
	var owned: Array[WeakRef] = [weakref(binding)]
	var stages: Array[String] = []
	var accepted: bool = await BINDING.run_staged_construction(weakref(binding),
		func(label: String) -> void:
			stages.append(label)
			if stages.size() == 2:
				for child in binding.get_children():
					owned.append(weakref(child))
				binding.queue_free()
	)
	_check(not accepted and stages.size() == 2,
		"queued partial fleet cannot report completion or build another craft")
	await process_frame
	await process_frame
	var freed := true
	for reference in owned:
		freed = freed and reference.get_ref() == null
	_check(freed, "queued partial fleet frees its constructed berths and craft")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
