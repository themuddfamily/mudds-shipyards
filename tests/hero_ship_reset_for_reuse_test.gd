extends SceneTree

## Focused contract test for HeroShip's synchronous reset transaction. It uses
## the production Torrent and Jovian scenes, their real presentation/component
## children, and only public reset APIs except for explicit exhaustion/currentness
## fault injection.

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const ComponentDamageModelType := preload("res://scripts/combat/component_damage_model.gd")

const FIRST_TARGET := Transform3D(
	Basis(Vector3.UP, deg_to_rad(23.0)),
	Vector3(18.0, 4.0, -31.0)
)
const HOSTILE_TARGET := Transform3D(Basis.IDENTITY, Vector3(900.0, 800.0, 700.0))

var _failures := PackedStringArray()
var _assertions := 0
var _test_root: Node3D
var _signal_order := PackedStringArray()
var _reentrant_results: Array[Dictionary] = []
var _direct_component_attacks: Array[Dictionary] = []
var _hostile_callbacks_enabled := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "HeroResetForReuseTestRoot"
	root.add_child(_test_root)
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_check(torrent != null and jovian != null, "production reset fixtures instantiate")
	if torrent == null or jovian == null:
		_finish()
		return
	_test_root.add_child(torrent)
	_test_root.add_child(jovian)
	jovian.global_position = Vector3(120.0, 0.0, 0.0)
	await process_frame
	await physics_frame

	_test_schema_invalid_and_cancel(torrent)
	_test_dependency_currentness(torrent)
	_test_damage_callback_reset_rejected(torrent)
	await _test_detached_preflight_rejected(torrent)
	await _test_detach_currentness(torrent)
	await _test_guarded_commit_chronology(torrent)
	await _test_variant_hook_guard(jovian)
	_test_component_reset_availability(torrent)
	_test_receipt_exhaustion(torrent)

	_test_root.queue_free()
	await process_frame
	await physics_frame
	_finish()


func _test_schema_invalid_and_cancel(ship: HeroShip) -> void:
	var before := _ship_snapshot(ship)
	var invalid := ship.preflight_reset_for_reuse(
		Transform3D(Basis.IDENTITY, Vector3(INF, 0.0, 0.0))
	)
	_check(
		not bool(invalid.get("accepted", true))
		and invalid.get("reason") == &"invalid_spawn_transform"
		and int(invalid.get("receipt_id", 0)) == -1,
		"non-finite preflight rejects before allocating a receipt"
	)
	_check(_ship_snapshot(ship) == before, "invalid preflight is state-atomic")

	var receipt := ship.preflight_reset_for_reuse(FIRST_TARGET)
	_check(
		bool(receipt.get("accepted", false))
		and receipt.keys() == HeroShip.RESET_FOR_REUSE_RESULT_KEYS
		and int(receipt.get("schema_version", 0)) == HeroShip.RESET_FOR_REUSE_SCHEMA_VERSION
		and int(receipt.get("receipt_id", -1)) == 1
		and int(receipt.get("ship_instance_id", 0)) == ship.get_instance_id(),
		"preflight returns the exact schema-1 first ship-bound receipt"
	)
	var duplicate := ship.preflight_reset_for_reuse(FIRST_TARGET)
	_check(
		not bool(duplicate.get("accepted", true))
		and duplicate.get("reason") == &"reset_pending",
		"one pending receipt rejects a second preflight"
	)

	var held_snapshot := _ship_snapshot(ship)
	ship.apply_damage(12.0, ship.global_position, Vector3.UP)
	ship.set_piloted(true)
	ship.request_engine_start()
	ship.set_canopy_open(true, 0.0)
	_check(
		_ship_snapshot(ship) == held_snapshot and not ship.is_canopy_open(),
		"pending preflight blocks damage, pilot, engine, canopy, and physics mutation"
	)

	var foreign := receipt.duplicate(true)
	foreign["ship_instance_id"] = ship.get_instance_id() + 1
	var foreign_commit := ship.commit_reset_for_reuse(foreign)
	_check(
		not bool(foreign_commit.get("accepted", true))
		and foreign_commit.get("reason") == &"receipt_identity_mismatch",
		"foreign receipt rejects without consuming the live capability"
	)
	var cancelled := ship.cancel_reset_for_reuse(receipt)
	_check(
		bool(cancelled.get("accepted", false))
		and cancelled.get("reason") == &"reset_cancelled"
		and int(cancelled.get("receipt_id", -1)) == 1,
		"exact cancellation consumes the first receipt"
	)
	_check(_ship_snapshot(ship) == before, "cancellation leaves every ship dependency unchanged")
	_check(
		ship.cancel_reset_for_reuse(receipt).get("reason") == &"no_pending_reset",
		"cancelled receipt cannot be reused"
	)

	var second := ship.preflight_reset_for_reuse(FIRST_TARGET)
	var private_target := second.get("spawn_transform", Transform3D.IDENTITY) as Transform3D
	second["spawn_transform"] = HOSTILE_TARGET
	second["component_revision"] = -999
	var committed := ship.commit_reset_for_reuse(second)
	_check(
		bool(committed.get("accepted", false))
		and int(committed.get("receipt_id", -1)) == 2
		and (committed.get("spawn_transform", Transform3D.IDENTITY) as Transform3D)
			.is_equal_approx(private_target)
		and ship.global_transform.is_equal_approx(private_target)
		and not ship.global_transform.is_equal_approx(HOSTILE_TARGET),
		"caller mutation cannot alter the privately captured commit payload"
	)
	_check(
		ship.commit_reset_for_reuse(second).get("reason") == &"no_pending_reset",
		"committed receipt is single-use"
	)


func _test_dependency_currentness(ship: HeroShip) -> void:
	var target := Transform3D(Basis.IDENTITY, Vector3(-12.0, 3.0, 20.0))
	var component := ship.get_component_damage()
	var receipt := ship.preflight_reset_for_reuse(target)
	var hull_before := float(ship.get_telemetry().get("hull", -1.0))
	var transform_before := ship.global_transform
	var serial_before := int(ship.get("_destruction_serial"))
	component.record_damage(3.0, Vector3.INF)
	var externally_advanced_revision := component.get_revision()
	var rejected := ship.commit_reset_for_reuse(receipt)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason") == &"dependency_changed",
		"component revision drift rejects commit before the first reset mutation"
	)
	_check(
		is_equal_approx(float(ship.get_telemetry().get("hull", -2.0)), hull_before)
		and ship.global_transform == transform_before
		and int(ship.get("_destruction_serial")) == serial_before
		and component.get_revision() == externally_advanced_revision,
		"dependency rejection does not partially reset hull, pose, fence, or component"
	)
	_check(
		ship.cancel_reset_for_reuse(receipt).get("reason") == &"no_pending_reset",
		"dependency rejection retires its stale receipt"
	)
	component.reset_for_reuse()


func _test_damage_callback_reset_rejected(ship: HeroShip) -> void:
	var hostile_results: Array[Dictionary] = []
	var transform_before := ship.global_transform
	var hull_before := float(ship.get_telemetry().get("hull", 0.0))
	var component := ship.get_component_damage()
	var components := component.get_component_report().get("components", []) as Array
	var first_component := components[0] as Dictionary
	var local_hit: Vector3 = first_component.get("local_position", Vector3.ZERO) as Vector3
	var hostile_callback := func(_id: StringName, _state: int, _integrity: float) -> void:
		hostile_results.append(ship.reset_for_reuse(HOSTILE_TARGET))
	ship.component_damage_changed.connect(hostile_callback)
	ship.apply_damage(30.0, ship.to_global(local_hit), Vector3.UP)
	ship.component_damage_changed.disconnect(hostile_callback)
	var all_rejected := not hostile_results.is_empty()
	for result in hostile_results:
		all_rejected = all_rejected \
			and not bool(result.get("accepted", true)) \
			and result.get("reason") == &"component_reset_unavailable"
	_check(
		all_rejected
		and ship.global_transform == transform_before
		and is_equal_approx(float(ship.get_telemetry().get("hull", -1.0)), hull_before - 30.0)
		and not ship.is_destroyed(),
		"normal generic stage callbacks cannot enter a partial Hero reset"
	)


func _test_detached_preflight_rejected(ship: HeroShip) -> void:
	var receipt_id_before := int(ship.get("_next_reset_for_reuse_receipt_id"))
	var hull_before := float(ship.get_telemetry().get("hull", -1.0))
	var component_revision_before := ship.get_component_damage().get_revision()
	var canopy_open_before := ship.is_canopy_open()
	_test_root.remove_child(ship)
	await process_frame
	var rejected := ship.preflight_reset_for_reuse(FIRST_TARGET)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason") == &"ship_detached"
		and int(rejected.get("receipt_id", 0)) == -1
		and int(ship.get("_next_reset_for_reuse_receipt_id")) == receipt_id_before
		and is_equal_approx(float(ship.get_telemetry().get("hull", -2.0)), hull_before)
		and ship.get_component_damage().get_revision() == component_revision_before
		and ship.is_canopy_open() == canopy_open_before,
		"detached preflight rejects atomically before world-space capture or receipt allocation"
	)
	_test_root.add_child(ship)
	await process_frame
	var next := ship.preflight_reset_for_reuse(FIRST_TARGET)
	_check(
		bool(next.get("accepted", false))
		and int(next.get("receipt_id", -1)) == receipt_id_before,
		"re-entered ship accepts the untouched next reset receipt"
	)
	ship.cancel_reset_for_reuse(next)


func _test_detach_currentness(ship: HeroShip) -> void:
	var receipt := ship.preflight_reset_for_reuse(
		Transform3D(Basis.IDENTITY, Vector3(7.0, 2.0, 9.0))
	)
	var receipt_id := int(receipt.get("receipt_id", -1))
	_test_root.remove_child(ship)
	await process_frame
	_test_root.add_child(ship)
	await process_frame
	var rejected := ship.commit_reset_for_reuse(receipt)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason") == &"dependency_changed",
		"detach/re-entry cruise generation makes a captured receipt stale"
	)
	var next := ship.preflight_reset_for_reuse(ship.global_transform)
	_check(
		bool(next.get("accepted", false))
		and int(next.get("receipt_id", -1)) > receipt_id,
		"detach/re-entry never rewinds the monotonic receipt allocator"
	)
	ship.cancel_reset_for_reuse(next)


func _test_guarded_commit_chronology(ship: HeroShip) -> void:
	ship.apply_damage(ship.maximum_hull + 1.0, ship.global_position, Vector3.UP)
	_check(ship.is_destroyed(), "chronology fixture reaches the real destroyed lifecycle")
	var component := ship.get_component_damage()
	var presentation := ship.get_damage_presentation()
	var model_identity := component.get_instance_id()
	var bounds_before := component.get_component_report().get("local_bounds", AABB()) as AABB
	var revision_before := component.get_revision()
	var ledger_generation_before := component.get_ledger_generation()
	ship.set_cockpit_view(false)
	ship.set_chase_camera_distance(11.0)
	ship.set_camera_fov(77.0)
	_signal_order.clear()
	_reentrant_results.clear()
	_direct_component_attacks.clear()

	ship.planetary_cruise_state_changed.connect(
		func(_snapshot: Dictionary) -> void: _hostile_signal(ship, &"cruise")
	)
	presentation.stage_changed.connect(
		func(_stage: int, _ratio: float) -> void: _hostile_signal(ship, &"presentation_stage")
	)
	presentation.status_changed.connect(
		func(_status: StringName, _ratio: float) -> void: _hostile_signal(ship, &"presentation_status")
	)
	presentation.effects_cleared.connect(
		func() -> void: _hostile_signal(ship, &"presentation_cleared")
	)
	ship.component_damage_changed.connect(
		func(_id: StringName, _state: int, _integrity: float) -> void:
			_hostile_signal(ship, &"component")
	)
	component.components_restored.connect(
		func() -> void: _hostile_signal(ship, &"components_restored")
	)
	ship.engine_state_changed.connect(
		func(_state: StringName) -> void: _hostile_signal(ship, &"engine")
	)
	ship.hull_changed.connect(
		func(_current: float, _maximum: float) -> void: _hostile_signal(ship, &"hull")
	)

	var target := Transform3D(Basis(Vector3.UP, deg_to_rad(-31.0)), Vector3(4.0, 5.0, 6.0))
	_hostile_callbacks_enabled = true
	var result := ship.reset_for_reuse(target)
	_hostile_callbacks_enabled = false
	_check(
		bool(result.get("accepted", false))
		and result.get("reason") == &"reset_committed"
		and ship.global_transform.is_equal_approx(target)
		and not ship.is_destroyed()
		and not ship.is_piloted()
		and not ship.is_canopy_open()
		and not ship.is_cockpit_view()
		and is_equal_approx(ship.get_chase_camera_distance(), 11.0)
		and is_equal_approx(ship.get_camera_fov(), 77.0)
		and is_equal_approx(float(ship.get_telemetry().get("hull", 0.0)), ship.maximum_hull),
		"guarded reset commits canonical state without callback camera mutation"
	)
	var all_reentrant := not _reentrant_results.is_empty()
	for rejected in _reentrant_results:
		all_reentrant = all_reentrant \
			and not bool(rejected.get("accepted", true)) \
			and rejected.get("reason") == &"reentrant_call"
	_check(all_reentrant, "every synchronous reset-signal callback rejects nested reset")
	var direct_attacks_rejected := not _direct_component_attacks.is_empty()
	for attack in _direct_component_attacks:
		direct_attacks_rejected = direct_attacks_rejected \
			and not bool(attack.configure_accepted) \
			and attack.damage_reason == &"owner_transaction_active" \
			and attack.repair_reason == &"owner_transaction_active" \
			and not bool(attack.duplicate_claimed) \
			and not bool(attack.foreign_end_accepted) \
			and int(attack.revision_after) == int(attack.revision_before)
	_check(
		direct_attacks_rejected,
		"every synchronous reset callback is fenced from direct component mutation"
	)
	_check(
		_ordered(&"cruise", &"presentation_stage")
		and _ordered(&"presentation_stage", &"presentation_status")
		and _ordered(&"presentation_status", &"presentation_cleared")
		and _ordered(&"presentation_cleared", &"components_restored")
		and _ordered(&"components_restored", &"engine")
		and _ordered(&"engine", &"hull"),
		"accepted reset preserves cruise, presentation, component, engine, hull chronology"
	)
	_check(
		component.get_instance_id() == model_identity
		and component.get_revision() == revision_before + 1
		and component.get_ledger_generation() == ledger_generation_before + 1
		and (component.get_component_report().get("local_bounds", AABB()) as AABB) == bounds_before
		and component.component_state_changed.get_connections().size() == 1,
		"accepted reset preserves one component identity, geometry, generic generation, revision, and connection"
	)


func _test_variant_hook_guard(jovian: JovianLightFreighter) -> void:
	var frame := jovian.get_moving_interior_component()
	var volume := jovian.get_node_or_null("WalkableInterior/InteriorOccupantVolume") as Area3D
	var frame_events := {"count": 0}
	var nested: Array[Dictionary] = []
	frame.frame_reset.connect(func() -> void:
		frame_events["count"] = int(frame_events.get("count", 0)) + 1
		nested.append(jovian.reset_for_reuse(HOSTILE_TARGET))
		jovian.apply_damage(10.0, jovian.global_position, Vector3.UP)
	)
	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	await process_frame
	var target := Transform3D(Basis.IDENTITY, Vector3(60.0, 3.0, -14.0))
	var result := jovian.reset_for_reuse(target)
	await process_frame
	await physics_frame
	_check(
		bool(result.get("accepted", false))
		and int(frame_events.get("count", 0)) == 1
		and nested.size() == 1
		and nested[0].get("reason") == &"reentrant_call",
		"Jovian post-base frame hook runs once under the whole-dispatch guard"
	)
	_check(
		not jovian.is_destroyed()
		and jovian.global_transform.is_equal_approx(target)
		and jovian.get_interior_root().visible
		and volume != null and volume.monitoring
		and frame.get_moving_frame() == jovian,
		"accepted variant hook restores the existing interior without hostile mutation"
	)


func _test_receipt_exhaustion(ship: HeroShip) -> void:
	var before := _ship_snapshot(ship)
	ship.set("_next_reset_for_reuse_receipt_id", HeroShip.RESET_FOR_REUSE_MAX_SAFE_RECEIPT_ID)
	var final_receipt := ship.preflight_reset_for_reuse(ship.global_transform)
	_check(
		bool(final_receipt.get("accepted", false))
		and int(final_receipt.get("receipt_id", -1))
			== HeroShip.RESET_FOR_REUSE_MAX_SAFE_RECEIPT_ID,
		"last safe monotonic receipt remains usable"
	)
	ship.cancel_reset_for_reuse(final_receipt)
	var exhausted := ship.preflight_reset_for_reuse(ship.global_transform)
	_check(
		not bool(exhausted.get("accepted", true))
		and exhausted.get("reason") == &"receipt_exhausted"
		and int(exhausted.get("receipt_id", 0)) == -1,
		"allocator fails closed before issuing an unsafe receipt"
	)
	_check(_ship_snapshot(ship) == before, "receipt saturation and cancellation are state-atomic")


func _test_component_reset_availability(ship: HeroShip) -> void:
	var component := ship.get_component_damage()
	var ledger: ComponentDamageModel = component.get("_ledger") as ComponentDamageModel
	_check(ledger != null, "Hero component adapter retains one inspectable generic-ledger fixture")
	if ledger == null:
		return
	var generation_before := ledger.get_generation()
	ledger.set("_generation", ComponentDamageModelType.MAX_SAFE_INTEGER)
	var before := _ship_snapshot(ship)
	var next_receipt_before := int(ship.get("_next_reset_for_reuse_receipt_id"))
	var rejected := ship.preflight_reset_for_reuse(ship.global_transform)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason") == &"component_reset_unavailable"
		and int(ship.get("_next_reset_for_reuse_receipt_id")) == next_receipt_before
		and _ship_snapshot(ship) == before,
		"generic generation exhaustion rejects Hero reset before allocating a receipt or mutating state"
	)
	ledger.set("_generation", generation_before)


func _hostile_signal(ship: HeroShip, label: StringName) -> void:
	if not _hostile_callbacks_enabled:
		return
	_signal_order.append(label)
	_reentrant_results.append(ship.reset_for_reuse(HOSTILE_TARGET))
	ship.apply_damage(99.0, ship.global_position, Vector3.UP)
	ship.set_piloted(true)
	ship.request_engine_start()
	ship.set_canopy_open(true, 0.0)
	ship.set_cockpit_view(true)
	ship.set_chase_camera_distance(26.0)
	ship.set_camera_fov(105.0)
	var component := ship.get_component_damage()
	var revision_before := component.get_revision()
	var component_report := component.get_component_report()
	var blocked_damage := component.record_damage(7.0, Vector3.INF)
	var blocked_repair := component.tick_repair(1.0 / 60.0, true)
	component.reset_for_reuse()
	_direct_component_attacks.append({
		"configure_accepted": component.configure(
			component_report.get("local_bounds", AABB()) as AABB,
			float(component_report.get("maximum_hull", 0.0))
		),
		"damage_reason": blocked_damage.reason,
		"repair_reason": blocked_repair.reason,
		"duplicate_claimed": component.claim_owner_mutation_capability() != null,
		"foreign_end_accepted": component.end_owner_mutation_transaction(RefCounted.new()),
		"revision_before": revision_before,
		"revision_after": component.get_revision(),
	})


func _ordered(first: StringName, second: StringName) -> bool:
	var first_index := _signal_order.find(first)
	var second_index := _signal_order.find(second)
	return first_index >= 0 and second_index > first_index


func _ship_snapshot(ship: HeroShip) -> Dictionary:
	return {
		"transform": ship.global_transform,
		"telemetry": ship.get_telemetry().duplicate(true),
		"component": ship.get_component_damage_report().duplicate(true),
		"component_id": ship.get_component_damage().get_instance_id(),
		"collision_layer": ship.collision_layer,
		"collision_mask": ship.collision_mask,
		"canopy_open": ship.is_canopy_open(),
		"cruise": ship.get_planetary_cruise_attachment_report().duplicate(true),
	}.duplicate(true)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_SHIP_RESET_FOR_REUSE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("HERO_SHIP_RESET_FOR_REUSE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
