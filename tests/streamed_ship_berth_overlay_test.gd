extends SceneTree

const OverlayScript := preload("res://scripts/world/streamed_ship_berth_overlay.gd")

var _resident_ids := PackedStringArray([
	"central_berth",
	"arrow_recon_berth",
	"jovian_freight_berth",
	"zenith_fleet_dock_berth",
	"halyard_fleet_dock_berth",
])
const COMMON_AUTHORITY_KEYS := [
	"renderer",
	"gameplay",
	"streaming",
	"save",
	"network",
	"physics",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"origin_shift",
	"weather_clock",
	"audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"scene_tree_mutation",
	"berth_lease",
	"reservation",
	"occupancy",
	"ship_token",
	"landing",
	"ship_movement",
	"cargo",
	"route",
	"reward",
	"ui",
]

var _assertions := 0
var _failures: Array[String] = []
var _stage: Node3D
var _coordinator: WorldStreamingCoordinator
var _overlay: StreamedShipBerthOverlay
var _registered_events: Array[Dictionary] = []
var _retired_events: Array[Dictionary] = []
var _chronology := PackedStringArray()
var _registered_reentry: Array[Dictionary] = []
var _retired_reentry: Array[Dictionary] = []
var _registered_post_state_seen := false
var _retired_post_state_seen := false
var _queue_root_during_registration := false
var _queued_callback_fail_closed_seen := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_stage = Node3D.new()
	_stage.name = "StreamedShipBerthOverlayTestStage"
	root.add_child(_stage)

	await _test_configuration_and_schema_limits()
	await _configure_primary_overlay()
	await _test_atomic_invalid_rosters()
	await _test_atomic_registration_merged_reads_and_reentry()
	await _test_whole_coordinator_detach_reentry()
	await _test_exact_unload_retirement_and_reload()
	await _test_independent_removal_and_stale_observations()
	await _test_queued_nodes_fail_closed_and_retire_once()
	_test_snapshots_audit_authority_and_detachment()

	_stage.queue_free()
	await process_frame
	_finish()


func _test_configuration_and_schema_limits() -> void:
	var invalid_overlay := OverlayScript.new() as StreamedShipBerthOverlay
	_check_reason(
		invalid_overlay.configure(null, PackedStringArray()),
		&"invalid_coordinator",
		"configuration requires one live coordinator"
	)
	var capacity_coordinator := _new_coordinator("CapacityCoordinator")
	var over_capacity := PackedStringArray()
	for index in StreamedShipBerthOverlay.MAX_RESIDENT_BERTH_IDS + 1:
		over_capacity.append("resident_berth_%03d" % index)
	_check_reason(
		invalid_overlay.configure(capacity_coordinator, over_capacity),
		&"resident_capacity_exceeded",
		"resident roster is bounded before state allocation"
	)
	_check_reason(
		invalid_overlay.configure(
			capacity_coordinator, PackedStringArray(["Bad ID"])
		),
		&"invalid_resident_berth_id",
		"resident roster uses exact stable primitive IDs"
	)
	_check_reason(
		invalid_overlay.configure(
			capacity_coordinator,
			PackedStringArray(["central_berth", "central_berth"])
		),
		&"duplicate_resident_berth_id",
		"resident roster rejects duplicates atomically"
	)
	var valid_empty := invalid_overlay.configure(
		capacity_coordinator, PackedStringArray()
	)
	_check(
		bool(valid_empty.accepted)
		and int(valid_empty.coordinator_instance_id) == capacity_coordinator.get_instance_id(),
		"rejected configuration attempts leave the one-shot seam available"
	)
	_check_reason(
		invalid_overlay.configure(capacity_coordinator, PackedStringArray()),
		&"already_configured",
		"coordinator and resident roster identities configure exactly once"
	)

	var busy_coordinator := _new_coordinator("BusyCoordinator")
	_register_location(
		busy_coordinator,
		&"busy_reach",
		_make_scene([_berth_spec(&"busy_berth", "BusyBerth")])
	)
	busy_coordinator.request_load(&"busy_reach")
	var busy_overlay := OverlayScript.new() as StreamedShipBerthOverlay
	_check_reason(
		busy_overlay.configure(busy_coordinator, PackedStringArray()),
		&"coordinator_not_quiescent",
		"binding cannot miss an already pending coordinator generation"
	)
	await _wait_for_loaded(busy_coordinator, &"busy_reach")
	busy_coordinator.request_unload(&"busy_reach")
	await process_frame


func _configure_primary_overlay() -> void:
	_coordinator = _new_coordinator("PrimaryCoordinator")
	_overlay = OverlayScript.new() as StreamedShipBerthOverlay
	var configured := _overlay.configure(_coordinator, _resident_ids)
	_check(
		bool(configured.accepted)
		and configured.resident_berth_ids == [
			&"arrow_recon_berth",
			&"central_berth",
			&"halyard_fleet_dock_berth",
			&"jovian_freight_berth",
			&"zenith_fleet_dock_berth",
		],
		"primary overlay freezes the sorted five-berth resident roster"
	)
	_overlay.location_registered.connect(_on_location_registered)
	_overlay.location_retired.connect(_on_location_retired)


func _test_atomic_invalid_rosters() -> void:
	var cases := [
		{
			"location_id": &"empty_reach",
			"scene": _make_scene([]),
			"reason": &"no_ship_berths",
			"message": "a loaded root with no ShipBerth rejects as one empty batch",
		},
		{
			"location_id": &"duplicate_reach",
			"scene": _make_scene([
				_berth_spec(&"duplicate_berth", "DuplicateBerthA"),
				_berth_spec(&"duplicate_berth", "DuplicateBerthB"),
			]),
			"reason": &"duplicate_berth_id",
			"message": "duplicate IDs anywhere in one root reject the complete batch",
		},
		{
			"location_id": &"invalid_reach",
			"scene": _make_scene([
				_berth_spec(&"valid_neighbor", "ValidNeighbor"),
				_berth_spec(&"invalid_neighbor", "InvalidNeighbor", true),
			]),
			"reason": &"invalid_berth",
			"message": "one invalid physical berth prevents partial neighbor registration",
		},
		{
			"location_id": &"resident_collision_reach",
			"scene": _make_scene([
				_berth_spec(&"new_neighbor", "NewNeighbor"),
				_berth_spec(&"jovian_freight_berth", "ResidentCollision"),
			]),
			"reason": &"berth_id_collision",
			"message": "one collision with the resident five prevents partial registration",
		},
	]
	for case_value in cases:
		var case := case_value as Dictionary
		var before := _overlay.get_snapshot()
		var registered_signal_count := _registered_events.size()
		_register_location(_coordinator, case.location_id, case.scene)
		await _load_location(_coordinator, case.location_id)
		var after := _overlay.get_snapshot()
		_check(
			StringName(after.last_loaded_observation.reason) == case.reason
			and int(after.active_location_count) == int(before.active_location_count)
			and int(after.active_berth_count) == int(before.active_berth_count)
			and _registered_events.size() == registered_signal_count,
			str(case.message)
		)
		_coordinator.request_unload(case.location_id)
		await process_frame

	var too_many_specs: Array[Dictionary] = []
	for index in StreamedShipBerthOverlay.MAX_BERTHS_PER_LOCATION + 1:
		too_many_specs.append(_berth_spec(
			StringName("capacity_berth_%02d" % index), "CapacityBerth%02d" % index
		))
	_register_location(_coordinator, &"capacity_reach", _make_scene(too_many_specs))
	await _load_location(_coordinator, &"capacity_reach")
	_check(
		_overlay.get_snapshot().last_loaded_observation.reason
		== &"location_berth_capacity_exceeded"
		and int(_overlay.get_snapshot().active_berth_count) == 0,
		"per-location roster limit rejects before any berth index write"
	)
	_coordinator.request_unload(&"capacity_reach")
	await process_frame


func _test_atomic_registration_merged_reads_and_reentry() -> void:
	var cinder_scene := _make_scene([
		_berth_spec(
			&"cinder_service_berth", "CinderServiceBerth",
			false, PackedStringArray(["service", "light_freighter"])
		),
		_berth_spec(
			&"cinder_cargo_jovian_berth", "CinderCargoJovianBerth",
			false, PackedStringArray(["light_freighter"])
		),
	])
	_register_location(_coordinator, &"cinder_reach", cinder_scene)
	var loaded_root := await _load_location(_coordinator, &"cinder_reach")
	var snapshot := _overlay.get_snapshot()
	var location := _overlay.lookup_location(&"cinder_reach")
	_check(
		loaded_root != null
		and int(snapshot.active_location_count) == 1
		and int(snapshot.active_berth_count) == 2
		and _registered_events.size() == 1
		and _registered_post_state_seen,
		"one coordinator load commits the complete two-berth roster before one signal"
	)
	_check(
		_registered_reentry.size() == 3
		and _all_reasons(_registered_reentry, &"reentrant_call"),
		"registration callback cannot configure, register, or retire reentrantly"
	)
	var cargo_record := _overlay.lookup_record(&"cinder_cargo_jovian_berth")
	var service_record := _overlay.lookup_record(&"cinder_service_berth")
	_check(
		bool(location.found) and bool(location.identity_current) and bool(location.available)
		and int(location.load_generation) == 1
		and int(location.root_instance_id) == loaded_root.get_instance_id()
		and int(location.berth_count) == 2,
		"location lookup freezes exact root instance and coordinator load generation"
	)
	_check(
		int(cargo_record.berth_schema_version) == ShipBerth.SCHEMA_VERSION
		and cargo_record.compatibility_tags == PackedStringArray(["light_freighter"])
		and service_record.compatibility_tags
		== PackedStringArray(["light_freighter", "service"]),
		"berth provenance includes exact schema and sorted detached compatibility tags"
	)
	var cargo_node := _resolve_record(cargo_record)
	_check(
		cargo_node != null
		and cargo_node.get_instance_id() == int(cargo_record.berth_instance_id)
		and cargo_node.get_berth_id() == &"cinder_cargo_jovian_berth",
		"the clearly named live resolver returns only the exact available ShipBerth"
	)
	cargo_node.compatibility_tags = PackedStringArray(["drifted_contract"])
	_check(
		_resolve_record(cargo_record) == null
		and not bool(_overlay.lookup_record(&"cinder_cargo_jovian_berth").identity_current)
		and _has_error_fragment(_overlay.audit().errors, "berth_contract_drift"),
		"live resolution rejects compatibility-contract drift from frozen provenance"
	)
	cargo_node.compatibility_tags = PackedStringArray(["light_freighter"])
	_check(
		_resolve_record(cargo_record) == cargo_node
		and bool(_overlay.audit().valid),
		"restoring the exact sorted compatibility contract restores live resolution"
	)
	_check(
		_overlay.get_merged_berth_ids() == [
			&"arrow_recon_berth",
			&"central_berth",
			&"cinder_cargo_jovian_berth",
			&"cinder_service_berth",
			&"halyard_fleet_dock_berth",
			&"jovian_freight_berth",
			&"zenith_fleet_dock_berth",
		],
		"merged resident and streamed read IDs are unique and deterministically sorted"
	)
	var merged := _overlay.get_merged_read_snapshot()
	_check(
		(merged.entries as Array).size() == 7
		and not _contains_live_capability(merged),
		"merged read snapshot contains no Node, WeakRef, Resource, Callable, or Signal"
	)
	(merged.entries as Array).clear()
	(cargo_record.compatibility_tags as PackedStringArray).append("mutated")
	(_registered_events[0].berths as Array).clear()
	_check(
		(_overlay.get_merged_read_snapshot().entries as Array).size() == 7
		and _overlay.lookup_record(&"cinder_cargo_jovian_berth").compatibility_tags
		== PackedStringArray(["light_freighter"])
		and int(_overlay.lookup_location(&"cinder_reach").berth_count) == 2,
		"read and signal payload mutation cannot reach committed roster state"
	)
	_check_reason(
		_overlay.register_loaded_root(
			&"cinder_reach", 1, loaded_root.get_instance_id(), loaded_root
		),
		&"duplicate_location",
		"exact loaded-root replay is signal-free duplicate rejection"
	)
	_check_reason(
		_overlay.retire_location(
			&"cinder_reach", 1, loaded_root.get_instance_id(), 2
		),
		&"coordinator_location_still_loaded",
		"overlay cannot invent unload while the coordinator still owns the root"
	)
	_check_reason(
		_overlay.retire_location(
			&"cinder_reach", 1, loaded_root.get_instance_id(), 3
		),
		&"retirement_generation_mismatch",
		"retirement must be the coordinator's exact immediate N+1 tombstone"
	)

	var collision_scene := _make_scene([
		_berth_spec(&"unique_before_collision", "UniqueBeforeCollision"),
		_berth_spec(&"cinder_service_berth", "GlobalCollision"),
	])
	_register_location(_coordinator, &"other_reach", collision_scene)
	var before_count := int(_overlay.get_snapshot().active_berth_count)
	var before_signals := _registered_events.size()
	await _load_location(_coordinator, &"other_reach")
	_check(
		_overlay.get_snapshot().last_loaded_observation.reason == &"berth_id_collision"
		and int(_overlay.get_snapshot().active_berth_count) == before_count
		and not _overlay.has_streamed_berth(&"unique_before_collision")
		and _registered_events.size() == before_signals,
		"global streamed collision rejects another root's entire roster atomically"
	)
	_coordinator.request_unload(&"other_reach")
	await process_frame


func _test_whole_coordinator_detach_reentry() -> void:
	var location_before := _overlay.lookup_location(&"cinder_reach")
	var berth_before := _overlay.lookup_record(&"cinder_cargo_jovian_berth")
	var register_count := _registered_events.size()
	var retire_count := _retired_events.size()
	var coordinator_index := _coordinator.get_index()
	_stage.remove_child(_coordinator)
	await process_frame
	var detached_location := _overlay.lookup_location(&"cinder_reach")
	_check(
		bool(detached_location.identity_current)
		and not bool(detached_location.available)
		and _resolve_record(berth_before) == null
		and int(detached_location.root_instance_id) == int(location_before.root_instance_id)
		and int((_overlay.lookup_record(&"cinder_cargo_jovian_berth")).berth_instance_id)
		== int(berth_before.berth_instance_id)
		and bool(_overlay.audit().valid),
		"whole-coordinator detach preserves identity but withholds live capability"
	)
	_stage.add_child(_coordinator)
	_stage.move_child(_coordinator, mini(coordinator_index, _stage.get_child_count() - 1))
	await process_frame
	await process_frame
	var reentered := _overlay.lookup_location(&"cinder_reach")
	_check(
		bool(reentered.identity_current) and bool(reentered.available)
		and _resolve_record(berth_before) != null
		and _registered_events.size() == register_count
		and _retired_events.size() == retire_count,
		"whole-coordinator re-entry restores availability without register/retire replay"
	)


func _test_exact_unload_retirement_and_reload() -> void:
	var old_location := _overlay.lookup_location(&"cinder_reach")
	var old_cargo := _overlay.lookup_record(&"cinder_cargo_jovian_berth")
	var unload := _coordinator.request_unload(&"cinder_reach")
	_check(
		bool(unload.accepted) and int(unload.generation) == 2
		and _retired_events.size() == 1 and _retired_post_state_seen
		and int(_overlay.get_snapshot().active_location_count) == 0
		and int(_overlay.get_snapshot().active_berth_count) == 0,
		"coordinator N+1 unload atomically removes every berth before one batch signal"
	)
	_check(
		_retired_reentry.size() == 3
		and _all_reasons(_retired_reentry, &"reentrant_call"),
		"retirement callback cannot configure, register, or retire reentrantly"
	)
	var tombstone := (_overlay.get_snapshot().location_tombstones as Array)[0] as Dictionary
	_check(
		int(tombstone.load_generation) == 1
		and int(tombstone.retirement_generation) == 2
		and int(tombstone.root_instance_id) == int(old_location.root_instance_id)
		and int(tombstone.berth_count) == 2
		and (tombstone.berths as Array)[0].berth_id == &"cinder_cargo_jovian_berth",
		"one tombstone separates exact load N from retirement N+1 with sorted berth provenance"
	)
	_check_reason(
		_overlay.retire_location(
			&"cinder_reach", 1, old_location.root_instance_id, 2
		),
		&"already_retired",
		"duplicate retirement is typed and emits no second signal"
	)

	var reloaded_root := await _load_location(_coordinator, &"cinder_reach")
	var reloaded := _overlay.lookup_location(&"cinder_reach")
	var reloaded_cargo := _overlay.lookup_record(&"cinder_cargo_jovian_berth")
	_check(
		int(reloaded.load_generation) == 3
		and int(reloaded.root_instance_id) == reloaded_root.get_instance_id()
		and int(reloaded.root_instance_id) != int(old_location.root_instance_id)
		and int(reloaded_cargo.berth_instance_id) != int(old_cargo.berth_instance_id)
		and _registered_events.size() == 2,
		"reload generation 3 reuses stable IDs only with new root and berth instances"
	)
	_check(
		_resolve_record(old_cargo) == null and _resolve_record(reloaded_cargo) != null,
		"old exact provenance cannot resolve the replacement stable berth ID"
	)
	(reloaded_root as Node3D).set_meta(&"world_location_generation", 1)
	_check_reason(
		_overlay.register_loaded_root(
			&"cinder_reach", 1, reloaded_root.get_instance_id(), reloaded_root
		),
		&"stale_generation",
		"stale load observation cannot replay over active replacement generation"
	)
	(reloaded_root as Node3D).set_meta(&"world_location_generation", 3)
	_check(bool(_overlay.audit().valid), "restoring exact replacement provenance restores audit")


func _test_independent_removal_and_stale_observations() -> void:
	var replacement := _coordinator.get_loaded_instance(&"cinder_reach")
	var replacement_id := replacement.get_instance_id()
	var before_retire := _retired_events.size()
	_coordinator.location_unloaded.emit(&"cinder_reach", 2)
	_check(
		_overlay.has_streamed_berth(&"cinder_cargo_jovian_berth")
		and _overlay.lookup_location(&"cinder_reach").load_generation == 3
		and _retired_events.size() == before_retire
		and _overlay.get_snapshot().last_unloaded_observation.reason
		== &"retirement_generation_mismatch",
		"delayed old unload observation cannot retire the generation-3 replacement"
	)
	_coordinator.remove_child(replacement)
	await process_frame
	await process_frame
	_check(
		int(_overlay.get_snapshot().active_location_count) == 0
		and _retired_events.size() == before_retire + 1
		and (_retired_events[-1] as Dictionary).retirement_generation == 4
		and (_retired_events[-1] as Dictionary).root_instance_id == replacement_id,
		"independent root removal is reconciled by coordinator and retires exactly once"
	)
	await process_frame
	_check(
		_retired_events.size() == before_retire + 1,
		"deferred root-exit reconciliation cannot double-retire the batch"
	)


func _test_queued_nodes_fail_closed_and_retire_once() -> void:
	var queued_root := await _load_location(_coordinator, &"cinder_reach")
	var queued_generation := int(queued_root.get_meta(&"world_location_generation"))
	var before_retire := _retired_events.size()
	_queue_root_during_registration = false
	var queued_record := _overlay.lookup_record(&"cinder_cargo_jovian_berth")
	var cargo := _resolve_record(queued_record)
	cargo.queue_free()
	_check(
		_resolve_record(queued_record) == null
		and not bool(_overlay.lookup_record(&"cinder_cargo_jovian_berth").available)
		and not bool(_overlay.audit().valid)
		and _has_error_fragment(_overlay.audit().errors, "berth_queued"),
		"queued berth fails live lookup, snapshot availability, and audit immediately"
	)
	var explicit_unload := _coordinator.request_unload(&"cinder_reach")
	_check(
		bool(explicit_unload.accepted)
		and int(explicit_unload.generation) == queued_generation + 1
		and _retired_events.size() == before_retire + 1,
		"queued child still retires once through the coordinator's location tombstone"
	)
	await process_frame

	# A subscriber is allowed to invalidate the external root after observing the
	# committed batch. The resolver fails immediately; coordinator reconciliation
	# then supplies the sole exact retirement observation.
	_queue_root_during_registration = true
	var before_register := _registered_events.size()
	before_retire = _retired_events.size()
	var callback_request := _coordinator.request_load(&"cinder_reach")
	_check(
		bool(callback_request.accepted),
		"fixture callback-queued load request is accepted"
	)
	for _frame in 12:
		if _registered_events.size() == before_register + 1:
			break
		await process_frame
	_check(
		_registered_events.size() == before_register + 1
		and _queued_callback_fail_closed_seen,
		"registration callback sees committed state then queued root is fail-closed immediately"
	)
	await process_frame
	await process_frame
	_check(
		_retired_events.size() == before_retire + 1
		and int(_overlay.get_snapshot().active_location_count) == 0,
		"queued loaded root produces one later coordinator retirement with no index leak"
	)
	_queue_root_during_registration = false


func _test_snapshots_audit_authority_and_detachment() -> void:
	var snapshot := _overlay.get_snapshot()
	var audit := _overlay.audit()
	_check(
		bool(audit.valid)
		and _exact_false_keys(audit.authority, COMMON_AUTHORITY_KEYS)
		and _exact_false_keys(audit.adjacent_authority, ADJACENT_AUTHORITY_KEYS),
		"audit publishes exact nested common and adjacent zero-authority rosters"
	)
	_check(
		(snapshot.limits as Dictionary) == {
			"resident_berth_ids": 128,
			"active_streamed_berths": 64,
			"active_locations": 32,
			"berths_per_location": 16,
			"tracked_berth_ids": 128,
			"tracked_location_ids": 64,
			"maximum_safe_integer": 9_007_199_254_740_991,
		},
		"snapshot freezes every roster and integer limit exactly"
	)
	_check(
		JSON.stringify(snapshot) == JSON.stringify(_overlay.get_snapshot()),
		"sorted primitive snapshot serialization is deterministic"
	)
	var tombstone_count := (snapshot.location_tombstones as Array).size()
	(snapshot.location_tombstones as Array).clear()
	(snapshot.authority as Dictionary)["gameplay"] = true
	(snapshot.last_loaded_observation as Dictionary)["reason"] = &"mutated"
	_check(
		(_overlay.get_snapshot().location_tombstones as Array).size() == tombstone_count
		and not bool(_overlay.get_snapshot().authority.gameplay)
		and _overlay.get_snapshot().last_loaded_observation.reason != &"mutated",
		"nested snapshot mutation cannot reach tombstone, diagnostics, or authority state"
	)
	_check(
		not _contains_live_capability(_overlay.get_snapshot())
		and not _contains_live_capability(_overlay.audit()),
		"all dictionary APIs and signal records are deeply detached from live capabilities"
	)
	_check(
		_chronology == PackedStringArray([
			"registered:cinder_reach:1",
			"retired:cinder_reach:2",
			"registered:cinder_reach:3",
			"retired:cinder_reach:4",
			"registered:cinder_reach:5",
			"retired:cinder_reach:6",
			"registered:cinder_reach:7",
			"retired:cinder_reach:8",
		]),
		"batch signal chronology is exact across unload, removal, queued child, and queued root"
	)


func _on_location_registered(snapshot: Dictionary) -> void:
	var location_id := StringName(snapshot.location_id)
	var generation := int(snapshot.load_generation)
	_registered_post_state_seen = _overlay.lookup_location(location_id).found \
		and int(_overlay.get_snapshot().active_berth_count) == int(snapshot.berth_count)
	_registered_events.append(snapshot.duplicate(true))
	_chronology.append("registered:%s:%d" % [location_id, generation])
	var coordinator := _coordinator
	var root_node := coordinator.get_loaded_instance(location_id)
	_registered_reentry = [
		_overlay.configure(coordinator, _resident_ids),
		_overlay.register_loaded_root(
			location_id, generation, snapshot.root_instance_id, root_node
		),
		_overlay.retire_location(
			location_id, generation, snapshot.root_instance_id, generation + 1
		),
	]
	(snapshot.berths as Array).clear()
	if _queue_root_during_registration and is_instance_valid(root_node):
		root_node.queue_free()
		_queued_callback_fail_closed_seen = (
			_resolve_record(
				_overlay.lookup_record(&"cinder_cargo_jovian_berth")
			) == null
			and not bool(
				_overlay.lookup_record(&"cinder_cargo_jovian_berth").available
			)
		)


func _on_location_retired(tombstone: Dictionary) -> void:
	var location_id := StringName(tombstone.location_id)
	var load_generation := int(tombstone.load_generation)
	var retirement_generation := int(tombstone.retirement_generation)
	_retired_post_state_seen = not _overlay.lookup_location(location_id).found \
		and int(_overlay.get_snapshot().active_berth_count) == 0
	_retired_events.append(tombstone.duplicate(true))
	_chronology.append("retired:%s:%d" % [location_id, retirement_generation])
	_retired_reentry = [
		_overlay.configure(_coordinator, _resident_ids),
		_overlay.register_loaded_root(location_id, load_generation, 1, null),
		_overlay.retire_location(
			location_id, load_generation, tombstone.root_instance_id,
			retirement_generation
		),
	]
	(tombstone.berths as Array).clear()


func _new_coordinator(node_name: String) -> WorldStreamingCoordinator:
	var coordinator := WorldStreamingCoordinator.new()
	coordinator.name = node_name
	_stage.add_child(coordinator)
	return coordinator


func _register_location(
	coordinator: WorldStreamingCoordinator,
	location_id: StringName,
	scene: PackedScene
	) -> void:
	var definition := WorldLocationDefinition.new()
	definition.location_id = location_id
	definition.display_name = str(location_id).replace("_", " ").capitalize()
	definition.sector_id = &"test_sector"
	definition.content_note = "Focused streamed berth overlay fixture."
	definition.anchor_source_id = &"test_anchor"
	definition.anchor_position = Vector3(0.0, 0.0, -100.0)
	definition.scene_origin_position = Vector3.ZERO
	_check(
		coordinator.register_location(definition, scene),
		"fixture location %s registers with the real coordinator" % location_id
	)


func _make_scene(berth_specs: Array) -> PackedScene:
	var scene_root := Node3D.new()
	scene_root.name = "FixtureLocationRoot"
	for spec_value in berth_specs:
		var spec := spec_value as Dictionary
		var berth := ShipBerth.new()
		berth.name = str(spec.node_name)
		berth.berth_id = StringName(spec.berth_id)
		berth.compatibility_tags = PackedStringArray(spec.compatibility_tags)
		if bool(spec.invalid):
			berth.landing_half_extents = Vector3.ZERO
		scene_root.add_child(berth)
		berth.owner = scene_root
	var packed := PackedScene.new()
	var error := packed.pack(scene_root)
	_check(error == OK, "temporary fixture scene packs successfully")
	scene_root.free()
	return packed


func _berth_spec(
	berth_id: StringName,
	node_name: String,
	invalid: bool = false,
	compatibility_tags: PackedStringArray = PackedStringArray(["light_freighter"])
	) -> Dictionary:
	return {
		"berth_id": berth_id,
		"node_name": node_name,
		"invalid": invalid,
		"compatibility_tags": compatibility_tags.duplicate(),
	}


func _load_location(
	coordinator: WorldStreamingCoordinator,
	location_id: StringName
	) -> Node3D:
	var request := coordinator.request_load(location_id)
	_check(bool(request.accepted), "fixture load request %s is accepted" % location_id)
	return await _wait_for_loaded(coordinator, location_id)


func _wait_for_loaded(
	coordinator: WorldStreamingCoordinator,
	location_id: StringName
	) -> Node3D:
	for _frame in 12:
		var loaded := coordinator.get_loaded_instance(location_id)
		if loaded != null:
			return loaded
		await process_frame
	_check(false, "fixture location %s loads within twelve frames" % location_id)
	return null


func _exact_false_keys(value: Variant, expected_keys: Array) -> bool:
	if value is not Dictionary:
		return false
	var dictionary := value as Dictionary
	if dictionary.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not dictionary.has(key) or dictionary[key] is not bool or bool(dictionary[key]):
			return false
	return true


func _resolve_record(record: Dictionary) -> ShipBerth:
	if not bool(record.get("found", false)):
		return null
	return _overlay.resolve_berth_node(
		StringName(record.location_id),
		int(record.load_generation),
		int(record.root_instance_id),
		StringName(record.berth_id),
		int(record.berth_instance_id)
	)


func _contains_live_capability(value: Variant) -> bool:
	if value is Node or value is Resource or value is WeakRef \
			or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if _contains_live_capability(key) \
					or _contains_live_capability((value as Dictionary)[key]):
				return true
	elif value is Array:
		for entry in value as Array:
			if _contains_live_capability(entry):
				return true
	return false


func _all_reasons(results: Array[Dictionary], reason: StringName) -> bool:
	for result in results:
		if bool(result.get("accepted", true)) or result.get("reason", &"") != reason:
			return false
	return true


func _has_error_fragment(errors: Variant, fragment: String) -> bool:
	for error in errors:
		if str(error).contains(fragment):
			return true
	return false


func _check_reason(result: Dictionary, reason: StringName, message: String) -> void:
	_check(
		not bool(result.get("accepted", true)) and result.get("reason", &"") == reason,
		message
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("STREAMED_SHIP_BERTH_OVERLAY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"STREAMED_SHIP_BERTH_OVERLAY_TEST_FAILED: %d failures / %d assertions"
			% [_failures.size(), _assertions]
		)
		quit(1)
