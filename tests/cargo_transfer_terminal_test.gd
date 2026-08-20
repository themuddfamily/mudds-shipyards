extends SceneTree

## Focused physical-adapter contract. The two checked-in fixtures bind real
## CargoTransferAuthority handles, delegate one atomic transfer, detach/re-enter,
## and prove embodied access without any GameFlow, HUD, ship, berth, combat,
## reward, network, or production-world integration.

const SOURCE_SCENE := preload("res://scenes/world/modules/cargo_source_terminal.tscn")
const DESTINATION_SCENE := preload(
	"res://scenes/world/modules/cargo_destination_terminal.tscn"
)
const AuthorityScript := preload("res://scripts/cargo/cargo_transfer_authority.gd")
const ItemScript := preload("res://scripts/cargo/cargo_item_definition.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		call_deferred("_capture_fixture_frame")
	else:
		call_deferred("_run")


func _run() -> void:
	await _test_unbound_bind_currentness()
	var stage := Node3D.new()
	stage.name = "CargoTerminalTestStage"
	root.add_child(stage)
	var source := SOURCE_SCENE.instantiate() as CargoTransferTerminal
	var destination := DESTINATION_SCENE.instantiate() as CargoTransferTerminal
	_check(source != null and destination != null, "both checked-in cargo terminal fixtures instantiate")
	if source == null or destination == null:
		_finish()
		return
	source.position = Vector3(-3.0, 0.0, 0.0)
	destination.position = Vector3(3.0, 0.0, 0.0)
	stage.add_child(source)
	stage.add_child(destination)
	await process_frame
	await physics_frame

	_test_fixture_identity_slots_and_physics(source, destination)
	_test_visual_resource_sharing(source, destination)
	var authority := AuthorityScript.new() as CargoTransferAuthority
	authority.name = "CargoTransferAuthority"
	root.add_child(authority)
	await process_frame
	var handles := _register_fixture_manifests(authority, source, destination)
	if handles.is_empty():
		await _cleanup(stage, authority)
		_finish()
		return
	var source_handle := handles.source as Dictionary
	var destination_handle := handles.destination as Dictionary
	_test_binding_and_bounded_snapshots(
		authority, source, destination, source_handle, destination_handle
	)
	await _test_embodied_access(source, destination)
	_test_delegated_transfer(
		authority, source, destination, source_handle, destination_handle
	)
	await _test_detach_reentry_and_stale_authority(
		stage, authority, source, destination, source_handle, destination_handle
	)
	await _test_queued_terminal_admission_and_restore_currentness()
	await _cleanup(stage, authority)
	_finish()


func _test_unbound_bind_currentness() -> void:
	var detached_fixture := await _make_unbound_bind_fixture("DetachedBind")
	_check(not detached_fixture.is_empty(), "detached bind fixture registers one unbound live terminal")
	if not detached_fixture.is_empty():
		var detached_stage := detached_fixture.stage as Node3D
		var detached_authority := detached_fixture.authority as CargoTransferAuthority
		var detached_terminal := detached_fixture.terminal as CargoTransferTerminal
		var detached_handle := detached_fixture.handle as Dictionary
		var detached_events: Array[bool] = []
		detached_terminal.binding_changed.connect(func(_snapshot: Dictionary) -> void:
			detached_events.append(true)
		)
		detached_stage.remove_child(detached_terminal)
		var detached_terminal_before := detached_terminal.get_state_snapshot()
		var detached_authority_before := detached_authority.to_dictionary()
		var detached_bind := detached_terminal.bind_authority(
			detached_authority, detached_handle, 0
		)
		_check(
			not bool(detached_bind.accepted)
				and detached_bind.reason == &"terminal_unavailable"
				and detached_terminal.get_state_snapshot() == detached_terminal_before
				and detached_authority.to_dictionary() == detached_authority_before
				and detached_events.is_empty(),
			"a detached unbound terminal rejects stale authority binding atomically"
		)
		detached_stage.add_child(detached_terminal)
		await process_frame
		var reattached := detached_authority.reattach_entity(detached_terminal, detached_handle)
		var live_bind := detached_terminal.bind_authority(
			detached_authority, reattached.get("handle", {}) as Dictionary, 0
		)
		_check(
			bool(reattached.accepted)
				and bool(live_bind.accepted)
				and bool(detached_terminal.get_state_snapshot().ready),
			"a reattached terminal accepts one fresh current authority binding"
		)
		await _cleanup(detached_stage, detached_authority)

	var queued_fixture := await _make_unbound_bind_fixture("QueuedBind")
	_check(not queued_fixture.is_empty(), "queued bind fixture registers one unbound live terminal")
	if not queued_fixture.is_empty():
		var queued_stage := queued_fixture.stage as Node3D
		var queued_authority := queued_fixture.authority as CargoTransferAuthority
		var queued_terminal := queued_fixture.terminal as CargoTransferTerminal
		var queued_handle := queued_fixture.handle as Dictionary
		var queued_events: Array[bool] = []
		queued_terminal.binding_changed.connect(func(_snapshot: Dictionary) -> void:
			queued_events.append(true)
		)
		var queued_terminal_before := queued_terminal.get_state_snapshot()
		var queued_authority_before := queued_authority.to_dictionary()
		queued_terminal.queue_free()
		var queued_bind := queued_terminal.bind_authority(
			queued_authority, queued_handle, 0
		)
		_check(
			not bool(queued_bind.accepted)
				and queued_bind.reason == &"terminal_unavailable"
				and queued_terminal.get_state_snapshot() == queued_terminal_before
				and queued_authority.to_dictionary() == queued_authority_before
				and queued_events.is_empty(),
			"a queued unbound terminal rejects stale authority binding atomically"
		)
		await process_frame
		await _cleanup(queued_stage, queued_authority)


func _make_unbound_bind_fixture(label: String) -> Dictionary:
	var stage := Node3D.new()
	stage.name = "%sCargoTerminalStage" % label
	root.add_child(stage)
	var terminal := SOURCE_SCENE.instantiate() as CargoTransferTerminal
	if terminal == null:
		stage.queue_free()
		await process_frame
		return {}
	stage.add_child(terminal)
	var authority := AuthorityScript.new() as CargoTransferAuthority
	authority.name = "%sCargoAuthority" % label
	root.add_child(authority)
	await process_frame
	var registration := authority.register_entity(
		terminal, terminal.terminal_id, terminal.manifest_id, 2
	)
	if not bool(registration.accepted):
		await _cleanup(stage, authority)
		return {}
	return {
		"stage": stage,
		"authority": authority,
		"terminal": terminal,
		"handle": (registration.handle as Dictionary).duplicate(true),
	}.duplicate(true)


func _test_fixture_identity_slots_and_physics(
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal
	) -> void:
	_check(
		source.is_configuration_valid()
		and destination.is_configuration_valid()
		and source.terminal_role == CargoTransferTerminal.Role.SOURCE
		and destination.terminal_role == CargoTransferTerminal.Role.DESTINATION,
		"source and destination fixtures publish valid distinct roles"
	)
	var source_slot := source.get_placement_slot_snapshot()
	var destination_slot := destination.get_placement_slot_snapshot()
	_check(
		StringName(source_slot.slot_id) == &"station_cargo_source_terminal_slot"
		and StringName(destination_slot.slot_id)
		== &"station_cargo_destination_terminal_slot"
		and (source_slot.local_transform as Transform3D).is_equal_approx(
			CargoTransferTerminal.PLACEMENT_SLOT_TRANSFORM
		)
		and (destination_slot.local_transform as Transform3D).is_equal_approx(
			CargoTransferTerminal.PLACEMENT_SLOT_TRANSFORM
		)
		and (source_slot.world_transform as Transform3D).is_equal_approx(
			source.global_transform
		)
		and (destination_slot.world_transform as Transform3D).is_equal_approx(
			destination.global_transform
		),
		"fixtures expose exact local/world placement slots for a later world owner"
	)
	(source_slot as Dictionary)["production_route_claim"] = true
	_check(
		not bool(source.get_placement_slot_snapshot().production_route_claim)
		and not bool(destination.get_placement_slot_snapshot().station_registry_claim)
		and not source.has_meta("station_route_marker")
		and not destination.has_meta("station_route_marker"),
		"placement reports are detached and make no production route or station-registry claim"
	)
	for terminal in [source, destination]:
		var physical: Dictionary = terminal.get_physical_contract()
		_check(
			int(physical.static_body_count) == 2
			and int(physical.world_body_count) == 2
			and int(physical.solid_shape_count) == 2
			and int(physical.interaction_shape_count) == 1
			and bool(physical.all_body_masks_zero)
			and int(physical.process_loops) == 0
			and int(physical.physics_process_loops) == 0,
			"%s has a physical deck/console, one bounded interaction volume and no frame loop"
			% terminal.name
		)
		_check(
			bool(terminal.audit().valid)
			and terminal.collision_layer == 0
			and (terminal.get_node(^"TerminalLabel") as Label3D).rotation_degrees.is_zero_approx()
			and terminal.get_interaction_prompt().is_empty(),
			"%s is physically valid, front-readable and undiscoverable before authority binding"
			% terminal.name
		)


func _test_visual_resource_sharing(
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal
	) -> void:
	var source_state_before := source.get_state_snapshot()
	var destination_state_before := destination.get_state_snapshot()
	var source_physical_before := source.get_physical_contract()
	var destination_physical_before := destination.get_physical_contract()
	var allocation := CargoTransferTerminal.audit_production_visual_resource_roster(
		[source, destination]
	)
	_check(
		bool(allocation.valid)
		and (allocation.legacy as Dictionary) == {
			"nodes": 8,
			"visible_copies": 8,
			"renderer_submissions": 8,
			"mesh_resource_allocations": 8,
			"material_resource_allocations": 6,
			"collision_nodes": 6,
		}
		and (allocation.current as Dictionary) == {
			"nodes": 8,
			"visible_copies": 8,
			"renderer_submissions": 8,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 6,
			"collision_nodes": 6,
		}
		and int(allocation.mesh_resource_allocation_delta) == -4
		and int(allocation.renderer_submission_delta) == 0
		and int(allocation.node_delta) == 0
		and int(allocation.collision_node_delta) == 0,
		"source/destination visual stock freezes exact 8->4 meshes with eight nodes, copies, submissions and six collision nodes unchanged"
	)
	var source_visual := source.get_visual_resource_allocation_audit()
	var destination_visual := destination.get_visual_resource_allocation_audit()
	_check(
		bool(source_visual.valid)
		and bool(destination_visual.valid)
		and bool(source_visual.visual_only)
		and bool(destination_visual.childless)
		and not bool(source_visual.batched)
		and int(source_visual.mesh_resource_allocations) == 4
		and int(destination_visual.material_resource_allocations) == 3
		and source_visual.node_paths == PackedStringArray([
			"AccessDeck/Mesh",
			"ConsoleBody/Mesh",
			"StatusScreen",
			"RoleStripe",
		]),
		"each terminal retains four named childless visual nodes, exact transforms, renderer recipes and instance-owned materials"
	)
	var source_deck := source.get_node(^"AccessDeck/Mesh") as MeshInstance3D
	var destination_deck := destination.get_node(^"AccessDeck/Mesh") as MeshInstance3D
	var source_console := source.get_node(^"ConsoleBody/Mesh") as MeshInstance3D
	var destination_console := destination.get_node(^"ConsoleBody/Mesh") as MeshInstance3D
	_check(
		source_deck.mesh == destination_deck.mesh
		and source_console.mesh == destination_console.mesh
		and source_deck.material_override != destination_deck.material_override
		and source_console.material_override != destination_console.material_override,
		"identical geometry shares exact mesh identity while both terminal material catalogs remain separately owned"
	)
	var destination_screen := destination.get_node(^"StatusScreen") as MeshInstance3D
	var shared_screen_mesh := destination_screen.mesh
	if shared_screen_mesh != null:
		destination_screen.mesh = shared_screen_mesh.duplicate() as Mesh
	var split_red := destination.get_visual_resource_allocation_audit()
	var roster_red := CargoTransferTerminal.audit_production_visual_resource_roster(
		[source, destination]
	)
	if shared_screen_mesh != null:
		destination_screen.mesh = shared_screen_mesh
	_check(
		not bool(split_red.valid)
		and (split_red.errors as PackedStringArray).has(
			"visual_mesh_recipe_or_identity_drift_status_screen"
		)
		and not bool(roster_red.valid)
		and (roster_red.errors as PackedStringArray).has(
			"production_terminal_visual_allocation_drift"
		)
		and bool(destination.get_visual_resource_allocation_audit().valid),
		"structured-red: splitting one byte-identical terminal mesh fails shared identity and restores cleanly"
	)
	var authority_exclusions := allocation.authority_exclusions as Dictionary
	_check(
		source.get_state_snapshot() == source_state_before
		and destination.get_state_snapshot() == destination_state_before
		and source.get_physical_contract() == source_physical_before
		and destination.get_physical_contract() == destination_physical_before
		and authority_exclusions == {
			"inventory": false,
			"ship": false,
			"berth": false,
			"combat": false,
			"reward": false,
			"network": false,
			"activity": false,
			"ui": false,
		},
		"allocation audit and mutation preserve collision, terminal state and every excluded authority exactly"
	)


func _register_fixture_manifests(
		authority: CargoTransferAuthority,
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal
	) -> Dictionary:
	var initial := {}
	for item_index in 10:
		var item_id := StringName("fixture_item_%02d" % item_index)
		var item := ItemScript.new() as CargoItemDefinition
		item.item_id = item_id
		item.display_name = "Fixture item %02d" % item_index
		item.unit_capacity = 1
		_check(
			bool(authority.register_item(item).accepted),
			"bounded fixture cargo item %02d registers" % item_index
		)
		initial[item_id] = 1
	var source_registration := authority.register_entity(
		source,
		source.terminal_id,
		source.manifest_id,
		20,
		initial
	)
	var destination_registration := authority.register_entity(
		destination,
		destination.terminal_id,
		destination.manifest_id,
		20
	)
	_check(
		bool(source_registration.accepted)
		and bool(destination_registration.accepted),
		"world-owner fixture setup registers both terminal manifests externally"
	)
	if not bool(source_registration.accepted) or not bool(destination_registration.accepted):
		return {}
	return {
		"source": (source_registration.handle as Dictionary).duplicate(true),
		"destination": (destination_registration.handle as Dictionary).duplicate(true),
	}


func _test_binding_and_bounded_snapshots(
		authority: CargoTransferAuthority,
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal,
		source_handle: Dictionary,
		destination_handle: Dictionary
	) -> void:
	var future_handle := source_handle.duplicate(true)
	future_handle["manifest_generation"] = 2
	_check(
		source.bind_authority(authority, future_handle, 0).reason
		== &"stale_authority_handle",
		"binding fails closed when the manifest generation is not current"
	)
	var wrong_identity := source_handle.duplicate(true)
	wrong_identity["entity_id"] = destination.terminal_id
	_check(
		source.bind_authority(authority, wrong_identity, 0).reason
		== &"wrong_terminal_identity",
		"binding rejects a current authority handle for the wrong terminal identity"
	)
	var source_bound := source.bind_authority(authority, source_handle, 0)
	var destination_bound := destination.bind_authority(
		authority, destination_handle, 0
	)
	_check(
		bool(source_bound.accepted)
		and bool(destination_bound.accepted)
		and source.get_terminal_generation() == 1
		and destination.get_terminal_generation() == 1,
		"exact handles bind both physical terminals at generation one"
	)
	_check(
		source.bind_authority(authority, source_handle, 0).reason
		== &"stale_terminal_generation"
		and source.bind_authority(authority, source_handle, 1).reason
		== &"already_bound",
		"stale and duplicate bind calls cannot replace terminal identity"
	)
	var source_state := source.get_state_snapshot()
	_check(
		bool(source_state.ready)
		and source_state.state_id == &"ready"
		and int(source_state.manifest_entry_count) == 10
		and (source_state.manifest_entries as Array).size()
		== CargoTransferTerminal.MAX_SNAPSHOT_ENTRIES
		and bool(source_state.manifest_entries_truncated)
		and int(source_state.maximum_snapshot_entries)
		== CargoTransferTerminal.MAX_SNAPSHOT_ENTRIES,
		"terminal state exposes a detached manifest summary capped at eight entries"
	)
	(source_state.manifest_entries as Array).clear()
	source_state["used_capacity"] = 999
	_check(
		(source.get_state_snapshot().manifest_entries as Array).size()
		== CargoTransferTerminal.MAX_SNAPSHOT_ENTRIES
		and int(source.get_state_snapshot().used_capacity) == 10,
		"caller mutation cannot alter terminal or authority state"
	)
	_check(
		source.collision_layer == PhysicsLayers.INTERACTABLE_AREA_LAYER
		and destination.collision_layer == PhysicsLayers.INTERACTABLE_AREA_LAYER
		and source.get_interaction_prompt().length()
		<= CargoTransferTerminal.MAX_PROMPT_CHARACTERS
		and "SOURCE" in source.get_interaction_prompt()
		and "DESTINATION" in destination.get_interaction_prompt(),
		"ready fixtures publish bounded role-specific prompts on the canonical interaction layer"
	)
	var authority_boundary := source.audit()
	_check(
		not bool(authority_boundary.owns_inventory)
		and bool(authority_boundary.uses_cargo_transfer_authority)
		and not bool(authority_boundary.ship_authority)
		and not bool(authority_boundary.berth_authority)
		and not bool(authority_boundary.combat_authority)
		and not bool(authority_boundary.reward_authority)
		and not bool(authority_boundary.network_authority)
		and not bool(authority_boundary.activity_authority)
		and not bool(authority_boundary.ui_authority),
		"terminal claims zero inventory, ship, berth, combat, reward, network, activity, or UI authority"
	)


func _test_embodied_access(
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal
	) -> void:
	for terminal in [source, destination]:
		var actor := CharacterBody3D.new()
		actor.name = "%sAccessActor" % terminal.name
		actor.collision_layer = PhysicsLayers.PLAYER_BODY_LAYER
		actor.collision_mask = PhysicsLayers.PLAYER_BODY_MASK
		actor.floor_snap_length = 0.35
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.70
		collision.shape = capsule
		actor.add_child(collision)
		root.add_child(actor)
		actor.global_position = terminal.to_global(Vector3(0.0, 0.86, 1.75))
		await physics_frame
		var reached := await _walk_actor_to(
			actor,
			terminal.to_global(CargoTransferTerminal.APPROACH_ORIGIN),
			90
		)
		var interaction: Dictionary = terminal.get_interaction_snapshot(
			actor.global_position,
			terminal.get_terminal_generation()
		)
		_check(
			reached
			and actor.is_on_floor()
			and bool(interaction.accepted)
			and bool(interaction.available)
			and interaction.reason == &"ready"
			and terminal.can_interact(actor),
			"an embodied player walks onto %s's real deck and reaches its bounded prompt"
			% terminal.name
		)
		var far: Dictionary = terminal.get_interaction_snapshot(
			terminal.to_global(Vector3(0.0, 0.85, 8.0)),
			terminal.get_terminal_generation()
		)
		_check(
			bool(far.accepted)
			and not bool(far.available)
			and far.reason == &"out_of_range",
			"%s refuses a finite actor outside the published interaction radius"
			% terminal.name
		)
		actor.queue_free()
		await process_frame


func _test_delegated_transfer(
		authority: CargoTransferAuthority,
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal,
		source_handle: Dictionary,
		destination_handle: Dictionary
	) -> void:
	var before_source := authority.get_quantity(source_handle, &"fixture_item_00")
	var before_destination := authority.get_quantity(
		destination_handle, &"fixture_item_00"
	)
	var stale := source.transfer_to(
		destination,
		&"stale_terminal_transfer",
		&"fixture_item_00",
		1,
		0,
		destination.get_terminal_generation()
	)
	_check(
		stale.reason == &"stale_terminal_generation"
		and authority.get_quantity(source_handle, &"fixture_item_00")
		== before_source
		and authority.get_quantity(destination_handle, &"fixture_item_00")
		== before_destination,
		"stale terminal generation rejects before either authority manifest mutates"
	)
	_check(
		destination.transfer_to(
			source,
			&"wrong_role_transfer",
			&"fixture_item_00",
			1,
			destination.get_terminal_generation(),
			source.get_terminal_generation()
		).reason == &"source_role_required",
		"destination fixture cannot impersonate the transfer source"
	)
	var reentry_probe := {}
	authority.transfer_committed.connect(func(_receipt: Dictionary) -> void:
		reentry_probe["result"] = source.transfer_to(
			destination,
			&"reentrant_terminal_transfer",
			&"fixture_item_00",
			1,
			source.get_terminal_generation(),
			destination.get_terminal_generation()
		)
	)
	var committed := source.transfer_to(
		destination,
		&"terminal_transfer_001",
		&"fixture_item_00",
		1,
		source.get_terminal_generation(),
		destination.get_terminal_generation()
	)
	_check(
		bool(committed.accepted)
		and committed.reason == &"committed"
		and authority.get_quantity(source_handle, &"fixture_item_00") == 0
		and authority.get_quantity(destination_handle, &"fixture_item_00") == 1,
		"terminal delegates one exact atomic source-to-destination authority transfer"
	)
	_check(
		(reentry_probe.result as Dictionary).reason == &"reentrant_call",
		"authority commit observers cannot re-enter the originating terminal transfer"
	)
	var interaction_probe := {}
	source.interaction_requested.connect(func(_actor: Node, snapshot: Dictionary) -> void:
		interaction_probe["close"] = source.close(source.get_terminal_generation())
		snapshot["used_capacity"] = 999
	)
	_check(
		source.interact()
		and (interaction_probe.close as Dictionary).reason == &"reentrant_call"
		and int(source.get_state_snapshot().used_capacity) == 9,
		"interaction observers receive detached state and cannot re-enter terminal mutation"
	)


func _test_detach_reentry_and_stale_authority(
		stage: Node3D,
		authority: CargoTransferAuthority,
		source: CargoTransferTerminal,
		destination: CargoTransferTerminal,
		source_handle: Dictionary,
		destination_handle: Dictionary
	) -> void:
	var source_instance_id := source.get_instance_id()
	var source_generation := source.get_terminal_generation()
	var snapshot_before := source.get_state_snapshot()
	var detached_binding_events: Array[bool] = []
	source.binding_changed.connect(func(_snapshot: Dictionary) -> void:
		detached_binding_events.append(true)
	)
	stage.remove_child(source)
	await process_frame
	var detached := source.get_state_snapshot()
	var detached_physical := _interaction_physical_snapshot(source)
	detached_binding_events.clear()
	_check(
		detached.state_id == &"detached"
		and not bool(detached.ready)
		and detached.instance_id == source_instance_id
		and detached.terminal_generation == source_generation
		and detached.entity_generation == snapshot_before.entity_generation
		and detached.manifest_generation == snapshot_before.manifest_generation
		and authority.get_quantity(source_handle, &"fixture_item_01") == 1,
		"tree detach preserves exact terminal/handle identity and authority quantity while disabling interaction"
	)
	_check(
		source.transfer_to(
			destination,
			&"detached_terminal_transfer",
			&"fixture_item_01",
			1,
			source_generation,
			destination.get_terminal_generation()
		).reason == &"source_detached",
		"detached physical source fails closed before authority mutation"
	)
	var detached_close := source.close(source_generation)
	_check(
		not bool(detached_close.accepted)
			and detached_close.reason == &"terminal_unavailable"
			and source.get_state_snapshot() == detached
			and _interaction_physical_snapshot(source) == detached_physical
			and detached_binding_events.is_empty(),
		"detached close rejects before terminal state, collision, or binding publication mutate"
	)
	stage.add_child(source)
	await process_frame
	await physics_frame
	var restored := source.get_state_snapshot()
	_check(
		bool(restored.ready)
		and restored.instance_id == source_instance_id
		and restored.terminal_generation == source_generation
		and source.get_handle() == source_handle
		and authority.get_manifest_snapshot(source_handle).attached,
		"re-entry reattaches the same node and generations without replacing its manifest"
	)
	_check(
		bool(source.transfer_to(
			destination,
			&"post_reentry_terminal_transfer",
			&"fixture_item_01",
			1,
			source_generation,
			destination.get_terminal_generation()
		).accepted),
		"same-generation terminal delegates again after exact re-entry"
	)

	_check(
		bool(authority.retire_entity(destination_handle).accepted),
		"external world owner can retire the destination manifest"
	)
	await physics_frame
	_check(
		destination.get_state_snapshot().state_id == &"stale"
		and destination.collision_layer == 0
		and destination.get_interaction_prompt().is_empty(),
		"retired authority generation immediately withdraws the stale terminal from interaction"
	)
	var source_quantity := authority.get_quantity(source_handle, &"fixture_item_02")
	var stale_destination := source.transfer_to(
		destination,
		&"retired_destination_transfer",
		&"fixture_item_02",
		1,
		source_generation,
		destination.get_terminal_generation()
	)
	_check(
		stale_destination.reason == &"destination_stale_authority"
		and authority.get_quantity(source_handle, &"fixture_item_02")
		== source_quantity,
		"stale destination authority generation fails closed without consuming source cargo"
	)
	var replacement := authority.register_entity(
		destination,
		destination.terminal_id,
		destination.manifest_id,
		20
	)
	_check(
		bool(replacement.accepted)
		and int(replacement.handle.entity_generation) == 2
		and int(replacement.handle.manifest_generation) == 2
		and destination.bind_authority(
			authority,
			replacement.handle as Dictionary,
			destination.get_terminal_generation()
		).reason == &"already_bound"
		and destination.get_state_snapshot().state_id == &"stale",
		"a replacement manifest cannot silently remap a terminal frozen to retired generations"
	)
	var placement := source.get_node(^"PlacementSlot") as Marker3D
	placement.position = Vector3(0.25, 0.0, 0.0)
	_check(
		not bool(source.audit().valid),
		"red mutation: moving the later-owner placement slot turns terminal audit red"
	)
	placement.transform = CargoTransferTerminal.PLACEMENT_SLOT_TRANSFORM
	_check(bool(source.audit().valid), "restoring exact placement returns terminal audit green")
	var closed := source.close(source_generation)
	await physics_frame
	_check(
		bool(closed.accepted)
		and source.get_state_snapshot().state_id == &"closed"
		and source.collision_layer == 0
		and authority.get_quantity(source_handle, &"fixture_item_02")
		== source_quantity,
		"closing the adapter withdraws interaction without retiring or owning inventory"
	)


func _test_queued_terminal_admission_and_restore_currentness() -> void:
	for queue_source in [true, false]:
		var fixture := await _make_queued_currentness_fixture(
			"QueuedSource" if queue_source else "QueuedDestination"
		)
		_check(not fixture.is_empty(), "queued terminal fixture binds both current authority handles")
		if fixture.is_empty():
			continue
		var authority := fixture.authority as CargoTransferAuthority
		var source := fixture.source as CargoTransferTerminal
		var destination := fixture.destination as CargoTransferTerminal
		var source_handle := fixture.source_handle as Dictionary
		var destination_handle := fixture.destination_handle as Dictionary
		var candidate := source if queue_source else destination
		var interaction_events: Array[bool] = []
		var binding_events: Array[bool] = []
		candidate.interaction_requested.connect(func(_actor: Node, _snapshot: Dictionary) -> void:
			interaction_events.append(true)
		)
		candidate.binding_changed.connect(func(_snapshot: Dictionary) -> void:
			binding_events.append(true)
		)
		var source_before := authority.get_quantity(source_handle, &"queued_fixture_item")
		var destination_before := authority.get_quantity(
			destination_handle, &"queued_fixture_item"
		)
		candidate.queue_free()
		var queued_terminal_snapshot := candidate.get_state_snapshot()
		var queued_physical_snapshot := _interaction_physical_snapshot(candidate)
		var queued_close := candidate.close(candidate.get_terminal_generation())
		var transfer := source.transfer_to(
			destination,
			&"queued_terminal_transfer",
			&"queued_fixture_item",
			1,
			source.get_terminal_generation(),
			destination.get_terminal_generation()
		)
		var expected_reason: StringName = &"source_detached" if queue_source else &"destination_detached"
		_check(
			candidate.is_inside_tree()
			and candidate.is_queued_for_deletion()
			and not bool(candidate.get_state_snapshot().ready)
			and candidate.get_state_snapshot().state_id == &"detached"
			and not candidate.can_interact()
			and not candidate.interact()
			and not bool(queued_close.accepted)
			and queued_close.reason == &"terminal_unavailable"
			and candidate.get_state_snapshot() == queued_terminal_snapshot
			and _interaction_physical_snapshot(candidate) == queued_physical_snapshot
			and transfer.reason == expected_reason
			and authority.get_quantity(source_handle, &"queued_fixture_item") == source_before
			and authority.get_quantity(destination_handle, &"queued_fixture_item") == destination_before
			and interaction_events.is_empty(),
			"queued %s terminal rejects interaction, transfer, and close without authority or signal mutation"
			% ("source" if queue_source else "destination")
		)
		_check(
			binding_events.is_empty(),
			"queued %s close publishes no binding change" % ("source" if queue_source else "destination")
		)
		await process_frame
		await _cleanup(fixture.stage as Node3D, authority)

	var restore_fixture := await _make_queued_currentness_fixture("QueuedRestore")
	_check(not restore_fixture.is_empty(), "queued restore fixture binds one current source terminal")
	if restore_fixture.is_empty():
		return
	var restore_authority := restore_fixture.authority as CargoTransferAuthority
	var restore_stage := restore_fixture.stage as Node3D
	var restore_source := restore_fixture.source as CargoTransferTerminal
	var restore_handle := restore_fixture.source_handle as Dictionary
	var restore_events: Array[bool] = []
	restore_source.binding_changed.connect(func(_snapshot: Dictionary) -> void:
		restore_events.append(true)
	)
	restore_stage.remove_child(restore_source)
	await process_frame
	var detached_before := restore_authority.get_manifest_snapshot(restore_handle)
	var detached_event_count := restore_events.size()
	restore_source.call("_restore_authority_binding")
	_check(
		not bool(detached_before.attached)
		and restore_authority.get_manifest_snapshot(restore_handle) == detached_before
		and restore_events.size() == detached_event_count,
		"a detached terminal cannot restore authority ownership or publish binding state"
	)
	restore_stage.add_child(restore_source)
	restore_source.queue_free()
	var queued_before := restore_authority.get_manifest_snapshot(restore_handle)
	restore_source.call("_restore_authority_binding")
	_check(
		restore_source.is_queued_for_deletion()
		and restore_authority.get_manifest_snapshot(restore_handle) == queued_before
		and not bool(queued_before.attached)
		and restore_events.size() == detached_event_count,
		"a queued reentry terminal cannot restore authority ownership or publish binding state"
	)
	await process_frame
	_check(
		not is_instance_valid(restore_source)
		and restore_authority.get_manifest_snapshot(restore_handle).is_empty()
		and restore_events.size() == detached_event_count,
		"the queued deferred restore stays inert while authority retires its freed owner"
	)
	await _cleanup(restore_stage, restore_authority)


func _make_queued_currentness_fixture(label: String) -> Dictionary:
	var stage := Node3D.new()
	stage.name = "%sCargoTerminalStage" % label
	root.add_child(stage)
	var source := SOURCE_SCENE.instantiate() as CargoTransferTerminal
	var destination := DESTINATION_SCENE.instantiate() as CargoTransferTerminal
	if source == null or destination == null:
		stage.queue_free()
		await process_frame
		return {}
	stage.add_child(source)
	stage.add_child(destination)
	var authority := AuthorityScript.new() as CargoTransferAuthority
	authority.name = "%sCargoAuthority" % label
	root.add_child(authority)
	await process_frame
	await physics_frame
	var item := ItemScript.new() as CargoItemDefinition
	item.item_id = &"queued_fixture_item"
	item.display_name = "Queued fixture item"
	item.unit_capacity = 1
	var item_registered := authority.register_item(item)
	var source_registration := authority.register_entity(
		source, source.terminal_id, source.manifest_id, 2, {&"queued_fixture_item": 1}
	)
	var destination_registration := authority.register_entity(
		destination, destination.terminal_id, destination.manifest_id, 2
	)
	if (
		not bool(item_registered.accepted)
		or not bool(source_registration.accepted)
		or not bool(destination_registration.accepted)
	):
		await _cleanup(stage, authority)
		return {}
	var source_handle := source_registration.handle as Dictionary
	var destination_handle := destination_registration.handle as Dictionary
	var source_bound := source.bind_authority(authority, source_handle, 0)
	var destination_bound := destination.bind_authority(authority, destination_handle, 0)
	if not bool(source_bound.accepted) or not bool(destination_bound.accepted):
		await _cleanup(stage, authority)
		return {}
	return {
		"stage": stage,
		"authority": authority,
		"source": source,
		"destination": destination,
		"source_handle": source_handle.duplicate(true),
		"destination_handle": destination_handle.duplicate(true),
	}.duplicate(true)


func _walk_actor_to(
		actor: CharacterBody3D,
		target: Vector3,
		frame_budget: int
	) -> bool:
	for _frame in frame_budget:
		var offset := target - actor.global_position
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		if horizontal.length() <= 0.16:
			actor.velocity = Vector3.ZERO
			return true
		var desired := horizontal.normalized() * minf(2.5, horizontal.length() * 3.0)
		actor.velocity = Vector3(desired.x, -1.5, desired.z)
		actor.move_and_slide()
		await physics_frame
	return Vector2(
		actor.global_position.x - target.x,
		actor.global_position.z - target.z
	).length() <= 0.20


func _capture_fixture_frame() -> void:
	root.size = Vector2i(1200, 800)
	var stage := Node3D.new()
	root.add_child(stage)
	var source := SOURCE_SCENE.instantiate() as CargoTransferTerminal
	var destination := DESTINATION_SCENE.instantiate() as CargoTransferTerminal
	source.position = Vector3(-2.0, 0.0, 0.0)
	destination.position = Vector3(2.0, 0.0, 0.0)
	stage.add_child(source)
	stage.add_child(destination)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fb2b8")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("d8e8eb")
	key.light_energy = 0.82
	key.shadow_enabled = true
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 58.0
	camera.position = Vector3(7.5, 5.2, 8.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.55, 0.0), Vector3.UP)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/cargo-transfer-terminals.png")
	print("CARGO_TRANSFER_TERMINAL_CAPTURE_OK" if error == OK else "CARGO_TRANSFER_TERMINAL_CAPTURE_FAILED")
	quit(0 if error == OK else 1)


func _cleanup(stage: Node3D, authority: CargoTransferAuthority) -> void:
	stage.queue_free()
	authority.queue_free()
	await process_frame
	await process_frame


func _interaction_physical_snapshot(terminal: CargoTransferTerminal) -> Dictionary:
	var shape := terminal.get_node_or_null(^"InteractionShape") as CollisionShape3D
	return {
		"collision_layer": terminal.collision_layer,
		"collision_mask": terminal.collision_mask,
		"monitoring": terminal.monitoring,
		"monitorable": terminal.monitorable,
		"shape_disabled": shape.disabled if shape != null else true,
	}.duplicate(true)


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CARGO_TRANSFER_TERMINAL_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_TRANSFER_TERMINAL_TEST_OK")
		quit(0)
	else:
		print("CARGO_TRANSFER_TERMINAL_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
