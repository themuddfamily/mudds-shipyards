extends SceneTree

## Focused production-presentation proof for authoritative Cinder cargo state.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var binding := cluster.get_node(^"ActivityBinding") as NearbySectorActivityBinding
	var access := cluster.get_cinder_cargo_access()
	var terminal := cluster.get_cinder_cargo_destination_terminal()
	var fixture := _build_authoritative_activity()
	var activity := fixture.activity as CargoDeliveryActivity
	binding.set("_cargo_activity", activity)
	binding.set("_cargo_source_entity", fixture.source as Node)
	binding.call("_publish_cargo_presentation")

	var cues := access.get_node(^"VisualRouteCues") as Node3D
	var retained_ids := _child_ids(cues)
	var retained_count := cues.get_child_count()
	_assert_geometry(access, &"pickup_ready", Vector3(2.5, 6.0, 2.5), &"normal")

	var started := binding.start_cargo_run()
	var first_generation := activity.get_generation()
	_check(
		bool(started.get("accepted", false)) and first_generation == 1,
		"the real cargo activity starts one authoritative delivery generation"
	)
	_assert_geometry(access, &"pickup", Vector3(2.5, 6.0, 2.5), &"normal")

	var loaded := binding.submit_cargo_phase(&"load_crate")
	_check(bool(loaded.get("accepted", false)), "the authoritative pickup phase advances")
	_assert_geometry(access, &"carrying", Vector3(4.0, 1.0, 1.0), &"normal")

	binding.advance_cargo_run(90.0)
	_assert_geometry(access, &"carrying_warning", Vector3(1.5, 5.0, 1.5), &"warning")
	binding.advance_cargo_run(18.0)
	_assert_geometry(access, &"carrying_critical", Vector3(5.0, 0.5, 5.0), &"critical")

	var cleared := binding.submit_cargo_phase(&"clear_gate")
	var docked := binding.submit_cargo_phase(&"dock_platform")
	_check(
		bool(cleared.get("accepted", false)) and bool(docked.get("accepted", false)),
		"the real ordered carry and dock phases reach the terminal"
	)
	_assert_geometry(access, &"delivery_ready", Vector3(4.0, 4.0, 4.0), &"normal")

	var delivered := activity.submit_transfer(first_generation)
	binding.call("_publish_cargo_presentation", delivered)
	_check(
		bool(delivered.get("accepted", false))
		and activity.get_snapshot().get("state") == CargoDeliveryActivity.State.COMPLETED,
		"only the real cargo authority receipt completes delivery"
	)
	_assert_geometry(access, &"delivered", Vector3(7.0, 0.35, 7.0), &"normal")

	var platform := access.get_parent()
	var delivered_state := access.get_cargo_presentation_state()
	platform.remove_child(access)
	await process_frame
	_check(
		_child_ids(cues) == retained_ids
		and access.get_cargo_presentation_state() == delivered_state,
		"detachment preserves the exact delivered silhouette without replay or growth"
	)
	platform.add_child(access)
	await process_frame
	var rebound := binding.bind_cargo_access(
		access, terminal, access.get_attachment_generation()
	)
	_check(
		bool(rebound.get("accepted", false))
		and _child_ids(cues) == retained_ids
		and access.get_cargo_presentation_state().get("geometry_state") == &"delivered",
		"re-entry accepts only the new attachment generation and republishes retained state"
	)

	var reset := binding.reset_cargo_run()
	var reset_generation := activity.get_generation()
	_check(
		bool(reset.get("accepted", false))
		and reset_generation > first_generation
		and cues.get_child_count() == retained_count,
		"reset advances authority generation without changing presentation node count"
	)
	_assert_geometry(access, &"reset", Vector3.ONE, &"normal")
	binding.start_cargo_run()
	_assert_geometry(access, &"pickup", Vector3(2.5, 6.0, 2.5), &"normal")
	var failed := binding.abort_cargo_run(activity.get_generation())
	_check(bool(failed.get("accepted", false)), "the authoritative abort remains cargo-owned")
	_assert_geometry(access, &"failed", Vector3(1.0, 7.0, 1.0), &"normal")
	_check(
		_child_ids(cues) == retained_ids
		and cues.get_child_count() == retained_count
		and int(access.audit().get("actual_budget", {}).get("collision_shapes", -1)) == 21
		and bool(access.audit().get("budget_exact", false)),
		"all states retain the exact cue nodes and original physical collision roster"
	)
	var presentation := access.get_cargo_presentation_state()
	_check(
		bool(presentation.get("static_geometry_only", false))
		and not bool(presentation.get("inventory_authority", true))
		and not bool(presentation.get("reward_authority", true))
		and not bool(presentation.get("interaction_authority", true)),
		"world geometry owns no inventory, reward, or interaction authority"
	)

	cluster.queue_free()
	(fixture.authority as Node).queue_free()
	await process_frame
	_finish()


func _build_authoritative_activity() -> Dictionary:
	var authority := CargoTransferAuthority.new()
	root.add_child(authority)
	var item := CargoItemDefinition.new()
	item.item_id = &"cinder_supply_crates"
	item.display_name = "Cinder supply crates"
	item.unit_capacity = 1
	authority.register_item(item)
	var source := Node.new()
	var destination := Node.new()
	authority.add_child(source)
	authority.add_child(destination)
	var source_handle := authority.register_entity(
		source, &"cargo_geometry_source", &"cargo_geometry_source_manifest", 8,
		{&"cinder_supply_crates": 2}
	).handle as Dictionary
	var destination_handle := authority.register_entity(
		destination, &"cargo_geometry_destination", &"cargo_geometry_destination_manifest", 8
	).handle as Dictionary
	var contract := CargoDeliveryContract.new(
		&"cinder_platform_supply_run", source_handle, destination_handle,
		&"cinder_supply_crates", 1,
		[&"load_crate", &"clear_gate", &"dock_platform"], 120.0
	)
	return {
		"authority": authority,
		"source": source,
		"activity": CargoDeliveryActivity.new(authority, contract),
	}


func _assert_geometry(
		access: CinderCargoAccess,
		expected_state: StringName,
		expected_scale: Vector3,
		expected_urgency: StringName
	) -> void:
	var state := access.get_cargo_presentation_state()
	var audit := access.get_route_cue_visual_allocation_audit()
	var live := audit.get("live_transforms", []) as Array
	var determinant := absf((live[0] as Transform3D).basis.determinant()) if not live.is_empty() else -1.0
	_check(
		state.get("geometry_state") == expected_state
		and (state.get("geometry_scale", Vector3.ZERO) as Vector3).is_equal_approx(expected_scale)
		and state.get("urgency_id") == expected_urgency
		and is_equal_approx(determinant, expected_scale.x * expected_scale.y * expected_scale.z)
		and bool(audit.get("valid", false)),
		"%s is readable in the five retained route-cue transforms" % String(expected_state)
	)


func _child_ids(parent: Node) -> Array[int]:
	var ids: Array[int] = []
	for child in parent.get_children():
		ids.append((child as Node).get_instance_id())
	return ids


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_CARGO_WORLD_GEOMETRY_STATE_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_CARGO_WORLD_GEOMETRY_STATE_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_CARGO_WORLD_GEOMETRY_STATE_TEST_FAILURE: ", failure)
	quit(1)
