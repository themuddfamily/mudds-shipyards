class_name CargoTransferTerminal
extends Area3D

## Reusable physical station endpoint for CargoTransferAuthority manifests.
##
## A world/session owner first registers this exact node with the cargo
## authority, then supplies the returned generation-bearing handle here. The
## terminal never creates, owns, edits, retires, or serializes inventory. It
## exposes a bounded prompt/state surface and delegates checked transfers to the
## existing authority. Temporary tree detach is restored only by presenting the
## same node and handle back to CargoTransferAuthority.reattach_entity().

signal binding_changed(snapshot: Dictionary)
signal interaction_requested(actor: Node, snapshot: Dictionary)

enum Role {
	SOURCE,
	DESTINATION,
}

const SCHEMA_VERSION := 1
const MAX_PROMPT_CHARACTERS := 96
const MAX_SNAPSHOT_ENTRIES := 8
const MIN_INTERACTION_RADIUS := 0.5
const MAX_INTERACTION_RADIUS := 4.0
const WORLD_LAYER := PhysicsLayers.WORLD_BODY_LAYER
const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const TERMINAL_DECK_SIZE := Vector3(3.0, 0.30, 3.0)
const TERMINAL_CONSOLE_SIZE := Vector3(1.40, 1.30, 0.70)
const PLACEMENT_SLOT_TRANSFORM := Transform3D.IDENTITY
const INTERACTION_ORIGIN := Vector3(0.0, 0.85, 0.25)
const APPROACH_ORIGIN := Vector3(0.0, 0.85, 1.10)

## Phase 9 component-local resource freeze. The checked-in source and
## destination fixtures use the same four immutable box recipes. Materials stay
## instance-owned because the role accent differs; collisions, nodes, semantic
## paths, visible copies, and renderer submissions are deliberately untouched.
const VISUAL_MESH_ROSTER := [
	{
		"role": &"access_deck",
		"cache_key": &"AccessDeck",
		"path": ^"AccessDeck/Mesh",
		"size": TERMINAL_DECK_SIZE,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, -0.15, 0.50)),
	},
	{
		"role": &"console_body",
		"cache_key": &"ConsoleBody",
		"path": ^"ConsoleBody/Mesh",
		"size": TERMINAL_CONSOLE_SIZE,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.65, -0.55)),
	},
	{
		"role": &"status_screen",
		"cache_key": &"StatusScreen",
		"path": ^"StatusScreen",
		"size": Vector3(0.92, 0.48, 0.035),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.82, -0.185)),
	},
	{
		"role": &"role_stripe",
		"cache_key": &"RoleStripe",
		"path": ^"RoleStripe",
		"size": Vector3(1.10, 0.10, 0.035),
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.20, -0.185)),
	},
]
const PRODUCTION_TERMINAL_COUNT := 2
const TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION := {
	"nodes": 8,
	"visible_copies": 8,
	"renderer_submissions": 8,
	"mesh_resource_allocations": 8,
	"material_resource_allocations": 6,
	"collision_nodes": 6,
}
const TERMINAL_PAIR_CURRENT_VISUAL_ALLOCATION := {
	"nodes": 8,
	"visible_copies": 8,
	"renderer_submissions": 8,
	"mesh_resource_allocations": 4,
	"material_resource_allocations": 6,
	"collision_nodes": 6,
}

## Process-wide because both production terminal scenes instantiate this same
## script. Values are created once, never exposed as a mutable catalog, and the
## live allocation audit rejects recipe or identity drift.
static var _shared_visual_meshes: Dictionary = {}

@export_category("Stable identity")
@export var terminal_id: StringName = &""
@export var manifest_id: StringName = &""
@export var placement_slot_id: StringName = &""
@export_enum("Source", "Destination") var terminal_role: int = Role.SOURCE

@export_category("Presentation")
@export var display_name := "Cargo transfer terminal"
@export var accent_color := Color("67d7de")
@export_range(MIN_INTERACTION_RADIUS, MAX_INTERACTION_RADIUS, 0.05)
var interaction_radius := 2.35

var _authority: CargoTransferAuthority
var _handle: Dictionary = {}
var _terminal_generation := 0
var _bound := false
var _closed := false
var _built := false
var _ready_complete := false
var _restore_pending := false
var _mutation_active := false
var _signal_dispatch_active := false
var _placement_slot: Marker3D
var _interaction_origin: Marker3D
var _approach_marker: Marker3D
var _interaction_shape: CollisionShape3D


func _enter_tree() -> void:
	if _ready_complete and _bound and not _closed and not _restore_pending:
		_restore_pending = true
		call_deferred("_restore_authority_binding")


func _exit_tree() -> void:
	_restore_pending = false
	_apply_interaction_availability(false)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	monitoring = false
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	if not _built:
		_built = true
		_build_physical_terminal()
	_ready_complete = true
	_apply_metadata()
	_apply_interaction_availability(false)


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not CargoItemDefinition.is_stable_id(terminal_id):
		errors.append("terminal_id must be a stable identifier")
	if not CargoItemDefinition.is_stable_id(manifest_id):
		errors.append("manifest_id must be a stable identifier")
	if not CargoItemDefinition.is_stable_id(placement_slot_id):
		errors.append("placement_slot_id must be a stable identifier")
	if terminal_role not in [Role.SOURCE, Role.DESTINATION]:
		errors.append("terminal_role must be source or destination")
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > CargoItemDefinition.MAX_DISPLAY_NAME_LENGTH:
		errors.append("display_name must contain 1..%d characters" % CargoItemDefinition.MAX_DISPLAY_NAME_LENGTH)
	if (
		not is_finite(interaction_radius)
		or interaction_radius < MIN_INTERACTION_RADIUS
		or interaction_radius > MAX_INTERACTION_RADIUS
	):
		errors.append("interaction_radius is outside its finite bound")
	return errors


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


## Binds one already-registered authority handle. Successful binding advances
## the terminal generation once; detach/re-entry does not.
func bind_authority(
		authority: CargoTransferAuthority,
		handle: Dictionary,
		expected_terminal_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_terminal_generation != _terminal_generation:
		return _finish(false, &"stale_terminal_generation")
	if _closed:
		return _finish(false, &"closed")
	if _bound:
		return _finish(false, &"already_bound")
	if not is_configuration_valid():
		return _finish(false, &"invalid_configuration")
	if not is_instance_valid(authority) or not authority.is_inside_tree():
		return _finish(false, &"authority_unavailable")
	var canonical := _canonical_handle(handle)
	var handle_error := _handle_error(canonical)
	if not handle_error.is_empty():
		return _finish(false, handle_error)
	if StringName(canonical.entity_id) != terminal_id:
		return _finish(false, &"wrong_terminal_identity")
	if StringName(canonical.manifest_id) != manifest_id:
		return _finish(false, &"wrong_manifest_identity")
	var manifest := authority.get_manifest_snapshot(canonical)
	if manifest.is_empty() or not _manifest_matches_handle(manifest, canonical):
		return _finish(false, &"stale_authority_handle")
	if not bool(manifest.get("attached", false)):
		return _finish(false, &"authority_entity_detached")

	_authority = authority
	_handle = canonical
	_bound = true
	_terminal_generation += 1
	_connect_authority_signals()
	_apply_interaction_availability(true)
	var result := _finish(true, &"bound")
	_emit_binding_changed()
	return result


## Permanently disables this physical adapter without retiring the manifest.
## Inventory lifecycle remains exclusively with CargoTransferAuthority.
func close(expected_terminal_generation: int) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_terminal_generation != _terminal_generation:
		return _finish(false, &"stale_terminal_generation")
	if _closed:
		return _finish(false, &"already_closed")
	_disconnect_authority_signals()
	_closed = true
	_apply_interaction_availability(false)
	var result := _finish(true, &"closed")
	_emit_binding_changed()
	return result


func get_terminal_generation() -> int:
	return _terminal_generation


func get_handle() -> Dictionary:
	return _handle.duplicate(true)


func get_placement_slot_snapshot() -> Dictionary:
	var local_transform := (
		_placement_slot.transform
		if is_instance_valid(_placement_slot)
		else PLACEMENT_SLOT_TRANSFORM
	)
	return {
		"slot_id": placement_slot_id,
		"terminal_id": terminal_id,
		"terminal_role": _role_id(),
		"local_transform": local_transform,
		"world_transform": global_transform * local_transform,
		"approach_local_position": APPROACH_ORIGIN,
		"interaction_local_position": INTERACTION_ORIGIN,
		"requires_world_owner": true,
		"production_route_claim": false,
		"station_registry_claim": false,
	}.duplicate(true)


## Detached and bounded: at most MAX_SNAPSHOT_ENTRIES manifest rows are exposed,
## regardless of how many cargo kinds the authority owns.
func get_state_snapshot() -> Dictionary:
	var manifest := _current_manifest_snapshot()
	var handle_current := not manifest.is_empty()
	var authority_attached := handle_current and bool(manifest.get("attached", false))
	var authority_available := is_instance_valid(_authority) and _authority.is_inside_tree()
	var ready := (
		_bound
		and not _closed
		and is_inside_tree()
		and authority_available
		and handle_current
		and authority_attached
	)
	var state_id: StringName = &"unbound"
	if _closed:
		state_id = &"closed"
	elif _bound and not handle_current:
		state_id = &"stale"
	elif _bound and not ready:
		state_id = &"detached"
	elif ready:
		state_id = &"ready"

	var all_entries := manifest.get("entries", []) as Array
	var bounded_entries: Array[Dictionary] = []
	for entry_index in mini(all_entries.size(), MAX_SNAPSHOT_ENTRIES):
		bounded_entries.append((all_entries[entry_index] as Dictionary).duplicate(true))
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"terminal_id": terminal_id,
		"manifest_id": manifest_id,
		"display_name": display_name.strip_edges(),
		"terminal_role": _role_id(),
		"terminal_generation": _terminal_generation,
		"instance_id": get_instance_id(),
		"bound": _bound,
		"closed": _closed,
		"inside_tree": is_inside_tree(),
		"authority_available": authority_available,
		"authority_handle_current": handle_current,
		"authority_entity_attached": authority_attached,
		"ready": ready,
		"state_id": state_id,
		"entity_generation": int(_handle.get("entity_generation", 0)),
		"manifest_generation": int(_handle.get("manifest_generation", 0)),
		"capacity": int(manifest.get("capacity", 0)),
		"used_capacity": int(manifest.get("used_capacity", 0)),
		"remaining_capacity": int(manifest.get("remaining_capacity", 0)),
		"manifest_entry_count": all_entries.size(),
		"manifest_entries": bounded_entries,
		"manifest_entries_truncated": all_entries.size() > MAX_SNAPSHOT_ENTRIES,
		"maximum_snapshot_entries": MAX_SNAPSHOT_ENTRIES,
		"interaction_radius": interaction_radius,
		"prompt": "",
		"owns_inventory": false,
		"uses_cargo_transfer_authority": true,
		"ship_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"reward_authority": false,
		"network_authority": false,
		"ui_authority": false,
	}
	if ready:
		snapshot["prompt"] = _build_prompt(snapshot)
	return snapshot.duplicate(true)


func get_interaction_snapshot(
		actor_world_position: Vector3,
		expected_terminal_generation: int
	) -> Dictionary:
	var state := get_state_snapshot()
	var result := {
		"accepted": false,
		"available": false,
		"reason": &"unavailable",
		"terminal_id": terminal_id,
		"terminal_generation": _terminal_generation,
		"state_id": state.state_id,
		"prompt": "",
		"distance": -1.0,
		"maximum_distance": interaction_radius,
	}
	if expected_terminal_generation != _terminal_generation:
		result["reason"] = &"stale_terminal_generation"
		return result.duplicate(true)
	if not actor_world_position.is_finite():
		result["reason"] = &"invalid_actor_position"
		return result.duplicate(true)
	if not bool(state.ready):
		result["reason"] = _state_rejection(StringName(state.state_id))
		return result.duplicate(true)
	var origin := (
		_interaction_origin.global_position
		if is_instance_valid(_interaction_origin)
		else to_global(INTERACTION_ORIGIN)
	)
	var distance := actor_world_position.distance_to(origin)
	result["accepted"] = true
	result["distance"] = distance
	result["prompt"] = str(state.prompt)
	if distance > interaction_radius:
		result["reason"] = &"out_of_range"
		return result.duplicate(true)
	result["available"] = true
	result["reason"] = &"ready"
	return result.duplicate(true)


func get_interaction_prompt() -> String:
	return str(get_state_snapshot().prompt)


func can_interact(actor: Node = null) -> bool:
	if actor == null:
		return bool(get_state_snapshot().ready)
	if actor is not Node3D:
		return false
	return bool(get_interaction_snapshot(
		(actor as Node3D).global_position,
		_terminal_generation
	).available)


## This is a request boundary only. A later world/session owner can observe the
## detached snapshot and choose item/quantity/destination without the terminal
## acquiring HUD, activity, or inventory authority.
func interact(actor: Node = null) -> bool:
	if _is_reentrant() or not can_interact(actor):
		return false
	_mutation_active = true
	var snapshot := get_state_snapshot()
	_mutation_active = false
	_signal_dispatch_active = true
	interaction_requested.emit(actor, snapshot)
	_signal_dispatch_active = false
	return true


func transfer_to(
		destination: CargoTransferTerminal,
		transfer_id: StringName,
		item_id: StringName,
		quantity: int,
		expected_terminal_generation: int,
		expected_destination_generation: int
	) -> Dictionary:
	if _is_reentrant():
		return _result(false, &"reentrant_call")
	_mutation_active = true
	if expected_terminal_generation != _terminal_generation:
		return _finish(false, &"stale_terminal_generation")
	if destination == null or not is_instance_valid(destination):
		return _finish(false, &"invalid_destination")
	if expected_destination_generation != destination.get_terminal_generation():
		return _finish(false, &"stale_destination_generation")
	if terminal_role != Role.SOURCE:
		return _finish(false, &"source_role_required")
	if destination.terminal_role != Role.DESTINATION:
		return _finish(false, &"destination_role_required")
	var source_state := get_state_snapshot()
	if not bool(source_state.ready):
		return _finish(false, _prefixed_state_rejection(&"source", source_state))
	var destination_state := destination.get_state_snapshot()
	if not bool(destination_state.ready):
		return _finish(false, _prefixed_state_rejection(&"destination", destination_state))
	if _authority != destination._authority:
		return _finish(false, &"authority_mismatch")
	var delegated := _authority.transfer(
		transfer_id,
		_handle,
		destination._handle,
		item_id,
		quantity
	)
	_mutation_active = false
	return delegated.duplicate(true)


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	if _built:
		if not _physical_contract_exact():
			errors.append("physical terminal geometry or collision drifted")
		if not _placement_contract_exact():
			errors.append("placement slot or approach markers drifted")
		for allocation_error in get_visual_resource_allocation_audit().get(
			"errors", PackedStringArray()
		):
			errors.append(String(allocation_error))
	var state := get_state_snapshot()
	if _bound and StringName(state.state_id) == &"stale":
		errors.append("bound authority handle is stale")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"state": state,
		"placement_slot": get_placement_slot_snapshot(),
		"physical": get_physical_contract(),
		"visual_resource_allocation": get_visual_resource_allocation_audit(),
		"owns_inventory": false,
		"uses_cargo_transfer_authority": true,
		"ship_authority": false,
		"berth_authority": false,
		"combat_authority": false,
		"reward_authority": false,
		"network_authority": false,
		"activity_authority": false,
		"ui_authority": false,
	}.duplicate(true)


## Headless-safe live proof that this terminal retains all four semantic mesh
## nodes and their exact renderer recipes while binding the shared immutable
## meshes. Resource identity is observed from Objects; submission count is the
## sum of mesh surfaces and does not require a rendered frame.
func get_visual_resource_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var visible_copies := 0
	var renderer_submissions := 0
	var childless_nodes := 0
	var live_paths := PackedStringArray()
	var live_transforms: Array[Transform3D] = []
	var accent_material: Material
	for recipe in VISUAL_MESH_ROSTER:
		var path := recipe.path as NodePath
		var role := recipe.role as StringName
		var mesh_instance := get_node_or_null(path) as MeshInstance3D
		if mesh_instance == null:
			errors.append("visual_mesh_node_missing_%s" % role)
			continue
		live_paths.append(String(path))
		var local_transform := global_transform.affine_inverse() * mesh_instance.global_transform
		live_transforms.append(local_transform)
		if not local_transform.is_equal_approx(recipe.local_transform as Transform3D):
			errors.append("visual_mesh_transform_drift_%s" % role)
		if mesh_instance.get_child_count() == 0:
			childless_nodes += 1
		else:
			errors.append("visual_mesh_node_not_childless_%s" % role)
		if mesh_instance.visible:
			visible_copies += 1
		else:
			errors.append("visual_mesh_visibility_drift_%s" % role)
		if (
			mesh_instance.cast_shadow
			!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			or mesh_instance.layers != 1
			or mesh_instance.material_overlay != null
			or not is_zero_approx(mesh_instance.extra_cull_margin)
			or not is_zero_approx(mesh_instance.visibility_range_begin)
			or not is_zero_approx(mesh_instance.visibility_range_end)
		):
			errors.append("visual_mesh_renderer_state_drift_%s" % role)
		var mesh := mesh_instance.mesh as BoxMesh
		var expected_mesh := _shared_visual_meshes.get(recipe.cache_key) as BoxMesh
		if mesh == null:
			errors.append("visual_box_mesh_missing_%s" % role)
		else:
			mesh_resource_ids[mesh.get_instance_id()] = true
			renderer_submissions += mesh.get_surface_count()
			if (
				mesh != expected_mesh
				or not mesh.size.is_equal_approx(recipe.size as Vector3)
				or mesh.material != null
				or mesh.get_surface_count() != 1
			):
				errors.append("visual_mesh_recipe_or_identity_drift_%s" % role)
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			errors.append("visual_material_missing_%s" % role)
		else:
			material_resource_ids[material.get_instance_id()] = true
			if not _matches_visual_material_recipe(role, material):
				errors.append("visual_material_recipe_drift_%s" % role)
			if role == &"status_screen":
				accent_material = material
			elif role == &"role_stripe" and material != accent_material:
				errors.append("terminal_accent_material_identity_drift")
	if mesh_resource_ids.size() != VISUAL_MESH_ROSTER.size():
		errors.append("terminal_visual_mesh_resource_count_drift")
	if material_resource_ids.size() != 3:
		errors.append("terminal_visual_material_resource_count_drift")
	if visible_copies != VISUAL_MESH_ROSTER.size():
		errors.append("terminal_visual_copy_count_drift")
	if renderer_submissions != VISUAL_MESH_ROSTER.size():
		errors.append("terminal_renderer_submission_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"family_id": &"cargo_terminal_box_recipes",
		"visual_only": childless_nodes == VISUAL_MESH_ROSTER.size(),
		"childless": childless_nodes == VISUAL_MESH_ROSTER.size(),
		"batched": false,
		"immutable_shared_meshes": mesh_resource_ids.size() == VISUAL_MESH_ROSTER.size(),
		"node_paths": live_paths.duplicate(),
		"live_transforms": live_transforms.duplicate(true),
		"visible_copies": visible_copies,
		"renderer_submissions": renderer_submissions,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"material_resource_allocations": material_resource_ids.size(),
		"collision_nodes": find_children("*", "CollisionShape3D", true, false).size(),
	}.duplicate(true)


## Exact two-fixture component census. This is intentionally not a whole-world
## count: it proves only the checked-in source/destination production family.
static func audit_production_visual_resource_roster(terminals: Array) -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var visible_copies := 0
	var renderer_submissions := 0
	var collision_nodes := 0
	var node_count := 0
	if terminals.size() != PRODUCTION_TERMINAL_COUNT:
		errors.append("production_terminal_count_drift")
	for terminal_index in terminals.size():
		var terminal := terminals[terminal_index] as CargoTransferTerminal
		if terminal == null:
			errors.append("production_terminal_invalid_%d" % terminal_index)
			continue
		var terminal_audit := terminal.get_visual_resource_allocation_audit()
		for allocation_error in terminal_audit.get("errors", PackedStringArray()):
			errors.append("terminal_%d_%s" % [terminal_index, allocation_error])
		visible_copies += int(terminal_audit.visible_copies)
		renderer_submissions += int(terminal_audit.renderer_submissions)
		collision_nodes += int(terminal_audit.collision_nodes)
		for recipe in VISUAL_MESH_ROSTER:
			var mesh_instance := terminal.get_node_or_null(
				recipe.path as NodePath
			) as MeshInstance3D
			if mesh_instance == null:
				continue
			node_count += 1
			if mesh_instance.mesh != null:
				mesh_resource_ids[mesh_instance.mesh.get_instance_id()] = true
			if mesh_instance.material_override != null:
				material_resource_ids[
					mesh_instance.material_override.get_instance_id()
				] = true
	var current := {
		"nodes": node_count,
		"visible_copies": visible_copies,
		"renderer_submissions": renderer_submissions,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"material_resource_allocations": material_resource_ids.size(),
		"collision_nodes": collision_nodes,
	}
	if current != TERMINAL_PAIR_CURRENT_VISUAL_ALLOCATION:
		errors.append("production_terminal_visual_allocation_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"family_id": &"cargo_terminal_box_recipes",
		"scope": &"checked_in_source_destination_pair",
		"terminal_instances": terminals.size(),
		"legacy": TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION.duplicate(true),
		"current": current.duplicate(true),
		"mesh_resource_allocation_delta": (
			int(current.mesh_resource_allocations)
			- int(TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION.mesh_resource_allocations)
		),
		"renderer_submission_delta": (
			int(current.renderer_submissions)
			- int(TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION.renderer_submissions)
		),
		"node_delta": int(current.nodes) - int(TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION.nodes),
		"collision_node_delta": (
			int(current.collision_nodes)
			- int(TERMINAL_PAIR_LEGACY_VISUAL_ALLOCATION.collision_nodes)
		),
		"authority_exclusions": {
			"inventory": false,
			"ship": false,
			"berth": false,
			"combat": false,
			"reward": false,
			"network": false,
			"activity": false,
			"ui": false,
		},
	}.duplicate(true)


func get_physical_contract() -> Dictionary:
	var bodies := find_children("*", "StaticBody3D", true, false)
	var shapes := find_children("*", "CollisionShape3D", true, false)
	var world_bodies := 0
	var all_masks_zero := true
	for raw_body in bodies:
		var body := raw_body as StaticBody3D
		world_bodies += int(body.collision_layer == WORLD_LAYER)
		all_masks_zero = all_masks_zero and body.collision_mask == 0
	return {
		"static_body_count": bodies.size(),
		"world_body_count": world_bodies,
		"collision_shape_count": shapes.size(),
		"solid_shape_count": maxi(shapes.size() - 1, 0),
		"interaction_shape_count": 1 if is_instance_valid(_interaction_shape) else 0,
		"all_body_masks_zero": all_masks_zero,
		"player_access_local_position": APPROACH_ORIGIN,
		"walkable_deck_size": TERMINAL_DECK_SIZE,
		"console_size": TERMINAL_CONSOLE_SIZE,
		"process_loops": int(is_processing()),
		"physics_process_loops": int(is_physics_processing()),
	}.duplicate(true)


func _restore_authority_binding() -> void:
	_restore_pending = false
	if not is_inside_tree() or not _bound or _closed:
		return
	if not is_instance_valid(_authority) or not _authority.is_inside_tree():
		_apply_interaction_availability(false)
		return
	var snapshot := _authority.get_manifest_snapshot(_handle)
	if snapshot.is_empty() or not _manifest_matches_handle(snapshot, _handle):
		_apply_interaction_availability(false)
		_emit_binding_changed()
		return
	if not bool(snapshot.get("attached", false)):
		var reattached := _authority.reattach_entity(self, _handle)
		if not bool(reattached.get("accepted", false)):
			_apply_interaction_availability(false)
			_emit_binding_changed()
			return
	_apply_interaction_availability(bool(get_state_snapshot().ready))
	_emit_binding_changed()


func _connect_authority_signals() -> void:
	if not _authority.manifest_detached.is_connected(_on_authority_manifest_changed):
		_authority.manifest_detached.connect(_on_authority_manifest_changed)
	if not _authority.manifest_reattached.is_connected(_on_authority_manifest_changed):
		_authority.manifest_reattached.connect(_on_authority_manifest_changed)
	if not _authority.manifest_retired.is_connected(_on_authority_manifest_changed):
		_authority.manifest_retired.connect(_on_authority_manifest_changed)
	if not _authority.tree_exiting.is_connected(_on_authority_tree_exiting):
		_authority.tree_exiting.connect(_on_authority_tree_exiting)


func _disconnect_authority_signals() -> void:
	if not is_instance_valid(_authority):
		return
	for authority_signal: Signal in [
		_authority.manifest_detached,
		_authority.manifest_reattached,
		_authority.manifest_retired,
	]:
		if authority_signal.is_connected(_on_authority_manifest_changed):
			authority_signal.disconnect(_on_authority_manifest_changed)
	if _authority.tree_exiting.is_connected(_on_authority_tree_exiting):
		_authority.tree_exiting.disconnect(_on_authority_tree_exiting)


func _on_authority_manifest_changed(changed_handle: Dictionary) -> void:
	if not _handles_equal(changed_handle, _handle):
		return
	_apply_interaction_availability(bool(get_state_snapshot().ready))
	_emit_binding_changed()


func _on_authority_tree_exiting() -> void:
	_apply_interaction_availability(false)
	_emit_binding_changed()


func _apply_interaction_availability(available: bool) -> void:
	var enabled := available and is_inside_tree() and not _closed
	collision_layer = INTERACTABLE_LAYER if enabled else 0
	monitorable = enabled
	if is_instance_valid(_interaction_shape):
		_interaction_shape.set_deferred("disabled", not enabled)


func _emit_binding_changed() -> void:
	if _signal_dispatch_active:
		return
	_signal_dispatch_active = true
	binding_changed.emit(get_state_snapshot())
	_signal_dispatch_active = false


func _current_manifest_snapshot() -> Dictionary:
	if not _bound or not is_instance_valid(_authority):
		return {}
	var snapshot := _authority.get_manifest_snapshot(_handle)
	if snapshot.is_empty() or not _manifest_matches_handle(snapshot, _handle):
		return {}
	return snapshot


func _build_prompt(state: Dictionary) -> String:
	var role_text := "SOURCE" if terminal_role == Role.SOURCE else "DESTINATION"
	var prompt := "[ E ]  %s  //  %s  %d/%d" % [
		display_name.strip_edges().to_upper(),
		role_text,
		int(state.used_capacity),
		int(state.capacity),
	]
	return prompt.substr(0, MAX_PROMPT_CHARACTERS)


func _role_id() -> StringName:
	return &"source" if terminal_role == Role.SOURCE else &"destination"


func _state_rejection(state_id: StringName) -> StringName:
	match state_id:
		&"closed":
			return &"closed"
		&"stale":
			return &"stale_authority_handle"
		&"detached":
			return &"binding_detached"
		_:
			return &"not_bound"


func _prefixed_state_rejection(side: StringName, state: Dictionary) -> StringName:
	var state_id := StringName(state.get("state_id", &"unbound"))
	if state_id == &"stale":
		return &"source_stale_authority" if side == &"source" else &"destination_stale_authority"
	if state_id == &"closed":
		return &"source_closed" if side == &"source" else &"destination_closed"
	return &"source_detached" if side == &"source" else &"destination_detached"


func _build_physical_terminal() -> void:
	_placement_slot = Marker3D.new()
	_placement_slot.name = "PlacementSlot"
	_placement_slot.transform = PLACEMENT_SLOT_TRANSFORM
	add_child(_placement_slot)
	_interaction_origin = Marker3D.new()
	_interaction_origin.name = "InteractionOrigin"
	_interaction_origin.position = INTERACTION_ORIGIN
	add_child(_interaction_origin)
	_approach_marker = Marker3D.new()
	_approach_marker.name = "PlayerApproach"
	_approach_marker.position = APPROACH_ORIGIN
	add_child(_approach_marker)

	_interaction_shape = CollisionShape3D.new()
	_interaction_shape.name = "InteractionShape"
	var interaction_sphere := SphereShape3D.new()
	interaction_sphere.radius = interaction_radius
	_interaction_shape.shape = interaction_sphere
	_interaction_shape.position = INTERACTION_ORIGIN
	add_child(_interaction_shape)

	var shell_material := _material(Color("26333a"), 0.62, 0.32)
	var deck_material := _material(Color("56666b"), 0.48, 0.26)
	var accent_material := _material(accent_color.darkened(0.38), 0.28, 0.18)
	accent_material.emission_enabled = true
	accent_material.emission = accent_color
	accent_material.emission_energy_multiplier = 1.15
	_static_box(
		"AccessDeck",
		Vector3(0.0, -0.15, 0.50),
		TERMINAL_DECK_SIZE,
		deck_material,
		true
	)
	_static_box(
		"ConsoleBody",
		Vector3(0.0, 0.65, -0.55),
		TERMINAL_CONSOLE_SIZE,
		shell_material,
		false
	)
	_visual_box(
		"StatusScreen",
		Vector3(0.0, 0.82, -0.185),
		Vector3(0.92, 0.48, 0.035),
		accent_material
	)
	_visual_box(
		"RoleStripe",
		Vector3(0.0, 0.20, -0.185),
		Vector3(1.10, 0.10, 0.035),
		accent_material
	)
	var label := Label3D.new()
	label.name = "TerminalLabel"
	label.text = "CARGO SOURCE" if terminal_role == Role.SOURCE else "CARGO DESTINATION"
	label.position = Vector3(0.0, 1.48, -0.18)
	label.rotation_degrees = Vector3.ZERO
	label.font_size = 40
	label.modulate = accent_color
	label.outline_size = 8
	add_child(label)


func _static_box(
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		walkable: bool
	) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.set_meta("cargo_terminal_physical", true)
	body.set_meta("walkable_surface", walkable)
	body.set_meta("non_walkable_reason", "solid cargo terminal console" if not walkable else "")
	add_child(body)
	var visible := MeshInstance3D.new()
	visible.name = "Mesh"
	visible.mesh = _shared_visual_box_mesh(StringName(node_name), size)
	visible.material_override = material
	body.add_child(visible)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _visual_box(
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material
	) -> void:
	var visible := MeshInstance3D.new()
	visible.name = node_name
	visible.position = position_value
	visible.mesh = _shared_visual_box_mesh(StringName(node_name), size)
	visible.material_override = material
	visible.set_meta("visual_detail_only", true)
	add_child(visible)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func _shared_visual_box_mesh(cache_key: StringName, size: Vector3) -> BoxMesh:
	var cached := _shared_visual_meshes.get(cache_key) as BoxMesh
	if cached != null:
		return cached
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_visual_meshes[cache_key] = mesh
	return mesh


func _matches_visual_material_recipe(
		role: StringName,
		material: StandardMaterial3D
	) -> bool:
	if role == &"access_deck":
		return (
			material.albedo_color.is_equal_approx(Color("56666b"))
			and is_equal_approx(material.roughness, 0.48)
			and is_equal_approx(material.metallic, 0.26)
			and not material.emission_enabled
		)
	if role == &"console_body":
		return (
			material.albedo_color.is_equal_approx(Color("26333a"))
			and is_equal_approx(material.roughness, 0.62)
			and is_equal_approx(material.metallic, 0.32)
			and not material.emission_enabled
		)
	return (
		material.albedo_color.is_equal_approx(accent_color.darkened(0.38))
		and is_equal_approx(material.roughness, 0.28)
		and is_equal_approx(material.metallic, 0.18)
		and material.emission_enabled
		and material.emission.is_equal_approx(accent_color)
		and is_equal_approx(material.emission_energy_multiplier, 1.15)
	)


func _physical_contract_exact() -> bool:
	var deck := get_node_or_null(^"AccessDeck") as StaticBody3D
	var console := get_node_or_null(^"ConsoleBody") as StaticBody3D
	return (
		deck != null
		and console != null
		and deck.collision_layer == WORLD_LAYER
		and console.collision_layer == WORLD_LAYER
		and deck.collision_mask == 0
		and console.collision_mask == 0
		and _box_shape_size(deck) == TERMINAL_DECK_SIZE
		and _box_shape_size(console) == TERMINAL_CONSOLE_SIZE
		and is_instance_valid(_interaction_shape)
		and _interaction_shape.shape is SphereShape3D
		and is_equal_approx(
			(_interaction_shape.shape as SphereShape3D).radius,
			interaction_radius
		)
	)


func _placement_contract_exact() -> bool:
	return (
		is_instance_valid(_placement_slot)
		and _placement_slot.transform.is_equal_approx(PLACEMENT_SLOT_TRANSFORM)
		and is_instance_valid(_interaction_origin)
		and _interaction_origin.position.is_equal_approx(INTERACTION_ORIGIN)
		and is_instance_valid(_approach_marker)
		and _approach_marker.position.is_equal_approx(APPROACH_ORIGIN)
	)


func _box_shape_size(body: StaticBody3D) -> Vector3:
	if body == null:
		return Vector3.ZERO
	var collision := body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if collision == null or collision.shape is not BoxShape3D:
		return Vector3.ZERO
	return (collision.shape as BoxShape3D).size


func _apply_metadata() -> void:
	add_to_group("cargo_transfer_terminals")
	set_meta("cargo_transfer_terminal", true)
	set_meta("terminal_id", terminal_id)
	set_meta("terminal_role", _role_id())
	set_meta("placement_slot_id", placement_slot_id)
	set_meta("production_route_claim", false)
	set_meta("owns_inventory", false)


func _handle_error(handle: Dictionary) -> StringName:
	if handle.size() != 4:
		return &"invalid_handle"
	for field: StringName in [
		&"entity_id",
		&"entity_generation",
		&"manifest_id",
		&"manifest_generation",
	]:
		if not handle.has(field):
			return &"invalid_handle"
	if (
		(not handle.entity_id is String and not handle.entity_id is StringName)
		or (not handle.manifest_id is String and not handle.manifest_id is StringName)
		or not handle.entity_generation is int
		or not handle.manifest_generation is int
	):
		return &"invalid_handle"
	if (
		not CargoItemDefinition.is_stable_id(StringName(handle.entity_id))
		or not CargoItemDefinition.is_stable_id(StringName(handle.manifest_id))
	):
		return &"invalid_handle"
	if int(handle.entity_generation) <= 0 or int(handle.manifest_generation) <= 0:
		return &"invalid_handle"
	return &""


func _canonical_handle(handle: Dictionary) -> Dictionary:
	var result := {}
	for field: StringName in [
		&"entity_id",
		&"entity_generation",
		&"manifest_id",
		&"manifest_generation",
	]:
		if handle.has(field):
			result[field] = handle[field]
	return result


func _manifest_matches_handle(manifest: Dictionary, handle: Dictionary) -> bool:
	return (
		StringName(manifest.get("owner_entity_id", &""))
		== StringName(handle.get("entity_id", &""))
		and int(manifest.get("owner_generation", 0))
		== int(handle.get("entity_generation", -1))
		and StringName(manifest.get("manifest_id", &""))
		== StringName(handle.get("manifest_id", &""))
		and int(manifest.get("generation", 0))
		== int(handle.get("manifest_generation", -1))
	)


func _handles_equal(left: Dictionary, right: Dictionary) -> bool:
	return (
		StringName(left.get("entity_id", &"")) == StringName(right.get("entity_id", &""))
		and int(left.get("entity_generation", 0)) == int(right.get("entity_generation", -1))
		and StringName(left.get("manifest_id", &"")) == StringName(right.get("manifest_id", &""))
		and int(left.get("manifest_generation", 0)) == int(right.get("manifest_generation", -1))
	)


func _is_reentrant() -> bool:
	return _mutation_active or _signal_dispatch_active


func _finish(accepted: bool, reason: StringName) -> Dictionary:
	_mutation_active = false
	return _result(accepted, reason)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_state_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result
