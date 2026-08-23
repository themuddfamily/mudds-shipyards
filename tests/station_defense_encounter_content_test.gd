extends SceneTree

## Focused production-site integration for the checked-in station-defense
## content. It composes the production ShipyardWorld directly (never Main), an
## externally owned LiveCombatAuthority, the real host, real RangeOpponents,
## and the dedicated renewable Damageable-backed perimeter asset.

const CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")
const ASSET_SCENE := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")
const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const CONTENT_SCRIPT_PATH := "res://scripts/activities/station_defense_encounter_content.gd"
const CONTENT_SCENE_PATH := "res://scenes/activities/station_defense_encounter.tscn"
const ASSET_SCENE_PATH := "res://scenes/activities/station_defense_perimeter_asset.tscn"
const DEFINITION_PATH := "res://assets/activities/shipyard_perimeter_defense.tres"

const TEST_WEAPON: StringName = &"content_integration_cannon"
const TEST_SOURCE_ID := 9201
const TEST_WEAPON_DAMAGE := 100.0
const PHYSICS_STEP := 1.0 / 60.0
const FULL_ENCOUNTER_PHYSICS_STEPS := 720
const AUDITED_WORLD_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(90.0, 0.0, -10.0))

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_range_opponent_firing_patterns()
	await _test_perimeter_renewal_rejects_stale_live_ownership()
	await _test_checked_in_encounter_content()
	await _test_detached_configuration_initializes_once_on_reentry()
	await _test_queued_deferred_reentry_callbacks_are_inert()
	await _test_source_conflict_rolls_back_atomically()
	_check(
		root.get_child_count() == original_root_child_count,
		"content fixture removes the production world, encounter, and external authority"
	)
	_finish()


func _test_range_opponent_firing_patterns() -> void:
	var target := Node3D.new()
	target.name = "FiringPatternTarget"
	target.position = Vector3(0.0, 0.0, -48.0)
	root.add_child(target)
	var opponent := RangeOpponent.new()
	opponent.name = "FiringPatternOpponent"
	opponent.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(opponent)
	await process_frame
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	var shots: Array[Dictionary] = []
	opponent.projectile_fired.connect(
		func(origin: Vector3, direction: Vector3) -> void:
			shots.append({"origin": origin, "direction": direction})
	)

	var single_result := opponent.configure_firing_pattern(
		RangeOpponent.FIRE_PATTERN_SINGLE_SHOT
	)
	var single_pre_discharge := _start_and_capture_pattern_telegraph(opponent, target)
	_drive_firing_pattern_cycle(opponent, target, [])
	var single_snapshot := opponent.get_firing_pattern_snapshot()
	var single_count := shots.size()
	var single_cooldown := float(single_snapshot.cooldown_remaining_seconds)

	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	shots.clear()
	var burst_result := opponent.configure_firing_pattern(
		RangeOpponent.FIRE_PATTERN_SHORT_BURST
	)
	var burst_pre_discharge := _start_and_capture_pattern_telegraph(opponent, target)
	root.remove_child(opponent)
	await process_frame
	root.add_child(opponent)
	await process_frame
	opponent.call("_update_presentation", 0.0)
	var burst_pre_discharge_reentered := _capture_pattern_telegraph(opponent)
	_drive_firing_pattern_cycle(opponent, target, [
		RangeOpponent.SHORT_BURST_INTERVAL_SECONDS * 0.5,
	])
	var burst_mid_count := shots.size()
	var burst_mid := opponent.get_firing_pattern_snapshot()
	root.remove_child(opponent)
	await process_frame
	var detached_burst := opponent.get_firing_pattern_snapshot()
	root.add_child(opponent)
	await process_frame
	var reentered_burst := opponent.get_firing_pattern_snapshot()
	_drive_firing_pattern_cycle(opponent, target, [
		RangeOpponent.SHORT_BURST_INTERVAL_SECONDS * 0.5,
		RangeOpponent.SHORT_BURST_INTERVAL_SECONDS,
	], false)
	var burst_snapshot := opponent.get_firing_pattern_snapshot()
	var burst_count := shots.size()
	var burst_shots := shots.duplicate(true)
	opponent.call("_update_presentation", 0.0)
	var burst_cleared_telegraph := _capture_pattern_telegraph(opponent)

	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	shots.clear()
	var suppression_result := opponent.configure_firing_pattern(
		RangeOpponent.FIRE_PATTERN_SPACED_SUPPRESSION
	)
	opponent.call("_update_presentation", 0.0)
	var suppression_reuse_idle := _capture_pattern_telegraph(opponent)
	var suppression_pre_discharge := _start_and_capture_pattern_telegraph(opponent, target)
	opponent.call(
		"_update_weapon",
		target.global_position,
		Vector3.BACK,
		opponent.global_position.distance_to(target.global_position),
		0.0
	)
	opponent.call("_update_presentation", 0.0)
	var suppression_cancelled := _capture_pattern_telegraph(opponent)
	_drive_firing_pattern_cycle(opponent, target, [])
	var suppression_snapshot := opponent.get_firing_pattern_snapshot()
	var suppression_count := shots.size()

	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	opponent.apply_damage(34.0, opponent.global_position)
	var degraded_modifiers := opponent.get_operational_modifiers()
	var degraded_fire_multiplier := float(degraded_modifiers.fire_multiplier)
	shots.clear()
	opponent.configure_firing_pattern(RangeOpponent.FIRE_PATTERN_SHORT_BURST)
	_drive_firing_pattern_cycle(opponent, target, [])
	var degraded_pending := opponent.get_firing_pattern_snapshot()
	_drive_firing_pattern_cycle(
		opponent,
		target,
		[RangeOpponent.SHORT_BURST_INTERVAL_SECONDS],
		false
	)
	var degraded_nominal_interval_count := shots.size()
	var scaled_interval := (
		RangeOpponent.SHORT_BURST_INTERVAL_SECONDS / degraded_fire_multiplier
	)
	_drive_firing_pattern_cycle(opponent, target, [
		scaled_interval - RangeOpponent.SHORT_BURST_INTERVAL_SECONDS,
		scaled_interval,
	], false)
	var degraded_burst_snapshot := opponent.get_firing_pattern_snapshot()
	var degraded_burst_count := shots.size()

	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	opponent.set("_orbit_sign", -1.0)
	var maneuver_started := opponent.configure_evasive_maneuver(
		RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
	)
	var maneuver_start := opponent.get_evasive_maneuver_snapshot()
	var maneuver_modifiers := opponent.get_operational_modifiers()
	opponent.call("_update_evasive_maneuver_state", 0.3, maneuver_modifiers)
	var target_direction := (target.global_position - opponent.global_position).normalized()
	var maneuver_direction := opponent.call(
		"_choose_motion_direction", target_direction, opponent.global_position.distance_to(target.global_position)
	) as Vector3
	var lateral_direction := Vector3.UP.cross(target_direction).normalized() * -1.0
	var maneuver_mid := opponent.get_evasive_maneuver_snapshot()
	root.remove_child(opponent)
	await process_frame
	var detached_maneuver := opponent.get_evasive_maneuver_snapshot()
	root.add_child(opponent)
	await process_frame
	var reentered_maneuver := opponent.get_evasive_maneuver_snapshot()
	var repeated_maneuver := opponent.configure_evasive_maneuver(
		RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
	)
	var after_repeat := opponent.get_evasive_maneuver_snapshot()
	opponent.call("_update_evasive_maneuver_state", 0.55, maneuver_modifiers)
	var completed_maneuver := opponent.get_evasive_maneuver_snapshot()
	var completed_repeat := opponent.configure_evasive_maneuver(
		RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
	)

	opponent.deactivate()
	opponent.activate(Transform3D.IDENTITY)
	opponent.set_target(target)
	opponent.set("_orbit_sign", -1.0)
	opponent.apply_damage(34.0, opponent.global_position)
	var damaged_maneuver_modifiers := opponent.get_operational_modifiers()
	var damaged_maneuver_start := opponent.configure_evasive_maneuver(
		RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
	)
	opponent.call("_update_evasive_maneuver_state", 0.1, damaged_maneuver_modifiers)
	var damaged_maneuver := opponent.get_evasive_maneuver_snapshot()
	opponent.set_target(null)
	opponent.call("_update_evasive_maneuver_state", 0.1, damaged_maneuver_modifiers)
	var cancelled_maneuver := opponent.get_evasive_maneuver_snapshot()

	_check(
		single_result.accepted
		and single_count == 1
		and single_snapshot.pattern_id == RangeOpponent.FIRE_PATTERN_SINGLE_SHOT
		and int(single_snapshot.projectile_count_per_cycle) == 1
		and is_equal_approx(single_cooldown, opponent.weapon_cooldown),
		"baseline firing remains one telegraphed projectile per nominal cooldown"
	)
	_check(
		burst_result.accepted
		and burst_mid_count == 1
		and int(burst_mid.pending_projectile_count) == 2
		and detached_burst == reentered_burst
		and burst_count == RangeOpponent.SHORT_BURST_PROJECTILE_COUNT
		and not (burst_shots[0].origin as Vector3).is_equal_approx(
			burst_shots[1].origin as Vector3
		)
		and (burst_shots[0].origin as Vector3).is_equal_approx(
			burst_shots[2].origin as Vector3
		)
		and burst_snapshot.pattern_id == RangeOpponent.FIRE_PATTERN_SHORT_BURST
		and int(burst_snapshot.pending_projectile_count) == 0
		and int(burst_snapshot.maximum_projectiles_per_cycle) == 3
		and is_equal_approx(
			float(burst_snapshot.cooldown_remaining_seconds), opponent.weapon_cooldown
		),
		"short burst dispatches exactly three alternating projectiles at bounded spacing without detach/re-entry replay"
	)
	_check(
		suppression_result.accepted
		and suppression_count == 1
		and suppression_snapshot.pattern_id == RangeOpponent.FIRE_PATTERN_SPACED_SUPPRESSION
		and int(suppression_snapshot.projectile_count_per_cycle) == 1
		and is_equal_approx(
			float(suppression_snapshot.cooldown_remaining_seconds),
			opponent.weapon_cooldown * RangeOpponent.SUPPRESSION_COOLDOWN_MULTIPLIER
		),
		"spaced suppression dispatches one projectile then holds the bounded 1.65x cycle cooldown"
	)
	var single_scales := single_pre_discharge.scales as Array
	var burst_scales := burst_pre_discharge.scales as Array
	var suppression_scales := suppression_pre_discharge.scales as Array
	_check(
		single_snapshot.pre_discharge_telegraph_id == RangeOpponent.FIRE_TELEGRAPH_UNIFORM_PAIR
		and burst_snapshot.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_STEPPED_BURST
		and suppression_snapshot.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_SUPPRESSION_BRACE
		and single_scales.size() == 2
		and burst_scales.size() == 2
		and suppression_scales.size() == 2
		and is_equal_approx((single_scales[0] as Vector3).x, (single_scales[1] as Vector3).x)
		and (burst_scales[0] as Vector3).x < (single_scales[0] as Vector3).x
		and (burst_scales[1] as Vector3).x > (single_scales[1] as Vector3).x
		and is_equal_approx(
			(suppression_scales[0] as Vector3).x,
			(suppression_scales[1] as Vector3).x
		)
		and (suppression_scales[0] as Vector3).x > (burst_scales[1] as Vector3).x
		and burst_pre_discharge.positions == single_pre_discharge.positions
		and suppression_pre_discharge.positions == single_pre_discharge.positions
		and burst_pre_discharge.mesh_ids == single_pre_discharge.mesh_ids
		and suppression_pre_discharge.mesh_ids == single_pre_discharge.mesh_ids
		and burst_pre_discharge.material_ids == single_pre_discharge.material_ids
		and suppression_pre_discharge.material_ids == single_pre_discharge.material_ids
		and burst_pre_discharge_reentered.scales == burst_pre_discharge.scales
		and _telegraph_scales_are_uniform(burst_cleared_telegraph.scales as Array, 0.8)
		and _telegraph_scales_are_uniform(suppression_reuse_idle.scales as Array, 0.8)
		and _telegraph_scales_are_uniform(suppression_cancelled.scales as Array, 0.8)
		and is_zero_approx(float(suppression_cancelled.warning_light_energy))
		and bool(burst_snapshot.pre_discharge_uses_static_geometry)
		and not bool(burst_snapshot.pre_discharge_color_only)
		and not bool(burst_snapshot.pre_discharge_motion_added),
		"retained muzzle spheres show stepped burst and heavy suppression silhouettes before discharge without color or added motion"
	)
	_check(
		degraded_fire_multiplier > 0.0 and degraded_fire_multiplier < 1.0
		and degraded_burst_count == RangeOpponent.SHORT_BURST_PROJECTILE_COUNT
		and degraded_nominal_interval_count == 1
		and is_equal_approx(
			float(degraded_pending.pending_interval_seconds), scaled_interval
		)
		and is_equal_approx(
			float(degraded_burst_snapshot.cooldown_remaining_seconds),
			opponent.weapon_cooldown / degraded_fire_multiplier
		),
		"existing weapon degradation scales both burst spacing and post-cycle cooldown without changing its three-shot cap"
	)
	_check(
		maneuver_started.accepted and maneuver_started.reason == &"evasive_maneuver_started"
		and maneuver_start.state_id == &"active"
		and is_equal_approx(float(maneuver_start.direction_sign), -1.0)
		and maneuver_mid.state_id == &"active"
		and is_equal_approx(float(maneuver_mid.elapsed_seconds), 0.3)
		and maneuver_direction.dot(lateral_direction) > 0.9
		and detached_maneuver == reentered_maneuver
		and repeated_maneuver.reason == &"evasive_maneuver_already_consumed"
		and after_repeat == reentered_maneuver
		and completed_maneuver.state_id == &"completed"
		and completed_repeat.reason == &"evasive_maneuver_already_consumed",
		"one deterministic lateral-outward break completes once without detach/re-entry or repeated-role replay"
	)
	_check(
		damaged_maneuver_start.accepted
		and damaged_maneuver.state_id == &"active"
		and float(damaged_maneuver.last_mobility_multiplier) < 1.0
		and float(damaged_maneuver.last_mobility_multiplier) > 0.0
		and cancelled_maneuver.state_id == &"cancelled",
		"the existing engine mobility stage scales the break while loss of target awareness cancels it"
	)

	opponent.deactivate()
	root.remove_child(opponent)
	opponent.queue_free()
	root.remove_child(target)
	target.queue_free()
	await process_frame


func _drive_firing_pattern_cycle(
	opponent: RangeOpponent,
	target: Node3D,
	followup_deltas: Array,
	start_cycle: bool = true
	) -> void:
	var target_direction := (target.global_position - opponent.global_position).normalized()
	var distance := opponent.global_position.distance_to(target.global_position)
	if start_cycle:
		opponent.set("_cooldown_remaining", 0.0)
		opponent.set("_telegraph_remaining", 0.0)
		opponent.call("_update_weapon", target.global_position, target_direction, distance, 0.0)
		opponent.call(
			"_update_weapon",
			target.global_position,
			target_direction,
			distance,
			opponent.telegraph_time
		)
	for delta_variant in followup_deltas:
		opponent.call(
			"_update_weapon",
			target.global_position,
			target_direction,
			distance,
			float(delta_variant)
		)


func _start_and_capture_pattern_telegraph(
	opponent: RangeOpponent,
	target: Node3D
	) -> Dictionary:
	var target_direction := (target.global_position - opponent.global_position).normalized()
	var distance := opponent.global_position.distance_to(target.global_position)
	opponent.set("_cooldown_remaining", 0.0)
	opponent.set("_telegraph_remaining", 0.0)
	opponent.call("_update_weapon", target.global_position, target_direction, distance, 0.0)
	opponent.call("_update_presentation", 0.0)
	return _capture_pattern_telegraph(opponent)


func _capture_pattern_telegraph(opponent: RangeOpponent) -> Dictionary:
	var scales: Array[Vector3] = []
	var positions: Array[Vector3] = []
	var mesh_ids: Array[int] = []
	var material_ids: Array[int] = []
	for node in _weapon_telegraph_nodes(opponent):
		scales.append(node.scale)
		positions.append(node.position)
		mesh_ids.append(node.mesh.get_instance_id())
		var sphere := node.mesh as SphereMesh
		material_ids.append(sphere.material.get_instance_id() if sphere.material != null else 0)
	var warning_light := opponent.get("_warning_light") as OmniLight3D
	return {
		"scales": scales,
		"positions": positions,
		"mesh_ids": mesh_ids,
		"material_ids": material_ids,
		"warning_light_energy": warning_light.light_energy if warning_light != null else 0.0,
	}.duplicate(true)


func _telegraph_scales_are_uniform(scales: Array, expected: float) -> bool:
	if scales.size() != RangeOpponent.WEAPON_TELEGRAPH_COPY_COUNT:
		return false
	for scale_variant in scales:
		var scale := scale_variant as Vector3
		if not scale.is_equal_approx(Vector3.ONE * expected):
			return false
	return true


func _test_perimeter_renewal_rejects_stale_live_ownership() -> void:
	var detached_asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	detached_asset.name = "DetachedRenewalPerimeterAsset"
	root.add_child(detached_asset)
	await process_frame
	var detached_generation := int(detached_asset.get_asset_handle().generation)
	var detached_before := detached_asset.get_snapshot()
	var detached_renewal_events: Array[Dictionary] = []
	detached_asset.asset_renewed.connect(
		func(asset_handle: Dictionary) -> void:
			detached_renewal_events.append(asset_handle.duplicate(true))
	)
	root.remove_child(detached_asset)
	var detached_result := detached_asset.renew(detached_generation)
	_check(
		not bool(detached_result.get("accepted", true))
		and detached_result.get("reason") == &"asset_detached"
		and detached_asset.get_snapshot() == detached_before
		and detached_renewal_events.is_empty(),
		"detached live perimeter renewal rejects before generation, health, collision, or publication mutation"
	)
	root.add_child(detached_asset)
	await process_frame
	var renewed_result := detached_asset.renew(detached_generation)
	_check(
		bool(renewed_result.get("accepted", false))
		and renewed_result.get("reason") == &"renewed"
		and int(detached_asset.get_asset_handle().generation) == detached_generation + 1
		and detached_renewal_events.size() == 1,
		"the same reattached perimeter asset performs one fresh live renewal"
	)
	root.remove_child(detached_asset)
	detached_asset.queue_free()

	var queued_asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	queued_asset.name = "QueuedRenewalPerimeterAsset"
	root.add_child(queued_asset)
	await process_frame
	var queued_generation := int(queued_asset.get_asset_handle().generation)
	var queued_before := queued_asset.get_snapshot()
	var queued_renewal_events: Array[Dictionary] = []
	queued_asset.asset_renewed.connect(
		func(asset_handle: Dictionary) -> void:
			queued_renewal_events.append(asset_handle.duplicate(true))
	)
	queued_asset.queue_free()
	var queued_result := queued_asset.renew(queued_generation)
	_check(
		queued_asset.is_queued_for_deletion()
		and not bool(queued_result.get("accepted", true))
		and queued_result.get("reason") == &"asset_detached"
		and queued_asset.get_snapshot() == queued_before
		and queued_renewal_events.is_empty(),
		"queued perimeter renewal rejects before generation, health, collision, or renewal signal mutation"
	)
	await process_frame
	_check(
		not is_instance_valid(detached_asset) and not is_instance_valid(queued_asset),
		"perimeter renewal currentness fixtures free both isolated production assets"
	)


func _test_detached_configuration_initializes_once_on_reentry() -> void:
	var authority := LiveCombatAuthority.new()
	authority.name = "DetachedConfigurationAuthority"
	root.add_child(authority)
	var replacement_authority := LiveCombatAuthority.new()
	replacement_authority.name = "RejectedDetachedReplacementAuthority"
	root.add_child(replacement_authority)
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	content.name = "DetachedConfigurationContent"
	root.add_child(content)
	await process_frame
	var host := content.get_host()
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	root.remove_child(content)
	await process_frame
	var configured := content.configure_external_combat_authority(authority)
	var replacement := content.configure_external_combat_authority(replacement_authority)
	_check(
		configured.accepted
		and not replacement.accepted and replacement.reason == &"already_configured"
		and not content.is_content_ready()
		and content.get_snapshot().configuration_state == &"configured_pending_tree"
		and content.get_combat_authority() == authority
		and authority.get_resolver().get_registered_source_count() == 0
		and replacement_authority.get_resolver().get_registered_source_count() == 0,
		"detached authority configuration binds one exact pending identity without acquiring live encounter sources"
	)
	root.add_child(content)
	await process_frame
	await process_frame
	var snapshot := content.get_snapshot()
	_check(
		content.is_content_ready()
		and snapshot.configuration_state == &"ready"
		and content.get_combat_authority() == authority
		and content.get_host() == host
		and host.get_combat_authority() == authority
		and (roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent) == alpha
		and authority.get_resolver().get_registered_source_count() == 3
		and replacement_authority.get_resolver().get_registered_source_count() == 0
		and content.audit().valid,
		"re-entry initializes exactly the retained content, authority, host, roster, and three source registrations once"
	)
	root.remove_child(content)
	content.queue_free()
	root.remove_child(authority)
	authority.queue_free()
	root.remove_child(replacement_authority)
	replacement_authority.queue_free()
	await process_frame
	_check(
		not is_instance_valid(content)
		and not is_instance_valid(authority)
		and not is_instance_valid(replacement_authority),
		"detached-configuration fixture releases retained content and both external authority candidates"
	)


func _test_queued_deferred_reentry_callbacks_are_inert() -> void:
	var pending_authority := LiveCombatAuthority.new()
	pending_authority.name = "QueuedPendingAuthority"
	root.add_child(pending_authority)
	var pending_content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	pending_content.name = "QueuedPendingContent"
	root.add_child(pending_content)
	await process_frame
	root.remove_child(pending_content)
	await process_frame
	var configured := pending_content.configure_external_combat_authority(pending_authority)
	root.add_child(pending_content)
	pending_content.queue_free()
	pending_content.call("_initialize_pending_configuration_after_reentry")
	var pending_snapshot := pending_content.get_snapshot()
	_check(
		configured.accepted
		and pending_content.is_queued_for_deletion()
		and not pending_content.is_content_ready()
		and pending_snapshot.get("configuration_state", &"") == &"configured_pending_tree"
		and int(pending_snapshot.get("registered_hostile_source_count", -1)) == 0
		and pending_authority.get_resolver().get_registered_source_count() == 0,
		"queued deferred configuration cannot initialize or acquire hostile sources"
	)
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(pending_content)
		and pending_authority.get_resolver().get_registered_source_count() == 0,
		"queued pending content frees without leaving external combat registrations"
	)
	root.remove_child(pending_authority)
	pending_authority.queue_free()
	await process_frame

	var restore_authority := LiveCombatAuthority.new()
	restore_authority.name = "QueuedRestoreAuthority"
	root.add_child(restore_authority)
	var restore_content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	restore_content.name = "QueuedRestoreContent"
	root.add_child(restore_content)
	await process_frame
	var restored_configuration := restore_content.configure_external_combat_authority(
		restore_authority
	)
	await process_frame
	root.remove_child(restore_content)
	await process_frame
	root.add_child(restore_content)
	restore_content.queue_free()
	restore_content.call("_restore_after_reentry")
	var restore_snapshot := restore_content.get_snapshot()
	_check(
		restored_configuration.accepted
		and restore_content.is_queued_for_deletion()
		and restore_content.is_content_ready()
		and int(restore_snapshot.get("registered_hostile_source_count", -1)) == 0
		and restore_authority.get_resolver().get_registered_source_count() == 0,
		"queued deferred restore cannot reconnect hostiles or reacquire their external source registrations"
	)
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(restore_content)
		and restore_authority.get_resolver().get_registered_source_count() == 0,
		"queued restored content frees without a late hostile-source reacquisition"
	)
	root.remove_child(restore_authority)
	restore_authority.queue_free()
	await process_frame


func _test_checked_in_encounter_content() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	world.name = "AuditedShipyardWorld"
	root.add_child(world)
	var authority := LiveCombatAuthority.new()
	authority.name = "ExistingSessionCombatAuthority"
	root.add_child(authority)
	await process_frame
	await physics_frame
	# ShipyardWorld now production-composes this encounter at the same audited
	# transform. This component test intentionally injects and drives its own
	# isolated content instance below, so retire the world's copy first; otherwise
	# both protected assets overlap exactly and a resolver ray can hit the fixture
	# this test is not observing.
	var production_content := world.get_station_defense_content()
	if production_content != null:
		production_content.queue_free()
	await process_frame
	_check(
		not is_instance_valid(production_content)
		and authority.get_resolver().get_registered_source_count() == 0,
		"isolated content fixture retires the production-composed duplicate before exact-pose combat assertions"
	)

	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	root.add_child(content)
	await process_frame
	await physics_frame
	_check(
		content != null
		and content.scene_file_path == CONTENT_SCENE_PATH
		and content.get_meta("evidence_status") == &"modern_interpretation"
		and content.global_transform.is_equal_approx(AUDITED_WORLD_TRANSFORM)
		and not content.is_content_ready()
		and content.get_snapshot().configuration_state == &"awaiting_external_authority"
		and content.get_combat_authority() == null,
		"checked-in content instantiates at the audited site but waits for an external authority"
	)
	var configured := content.configure_external_combat_authority(authority)
	await process_frame
	_check(
		configured.accepted and content.is_content_ready()
		and content.get_combat_authority() == authority
		and content.get_host().get_combat_authority() == authority
		and authority.get_resolver() is CombatResolver
		and content.find_children("*", "LiveCombatAuthority", true, false).is_empty()
		and content.find_children("*", "CombatResolver", true, false).is_empty(),
		"the exact injected authority and its existing resolver are reused with no internal authority node"
	)
	_check(
		content.configure_external_combat_authority(authority).reason == &"already_configured",
		"initialized content cannot replace its exact external combat authority identity"
	)

	var host := content.get_host()
	var resolver := authority.get_resolver()
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var beta_nominal_preferred_range := beta.preferred_range
	var gamma_nominal_preferred_range := gamma.preferred_range
	var beta_nominal_cruise_speed := beta.cruise_speed
	var beta_nominal_chase_speed := beta.chase_speed
	var gamma_nominal_cruise_speed := gamma.cruise_speed
	var gamma_nominal_chase_speed := gamma.chase_speed
	var gamma_nominal_orbit_sign := float(gamma.get("_orbit_sign"))
	var beta_role_lamps := _weapon_telegraph_nodes(beta)
	var gamma_role_lamps := _weapon_telegraph_nodes(gamma)
	var beta_nominal_lamp_positions := _telegraph_positions(beta_role_lamps)
	var gamma_nominal_lamp_positions := _telegraph_positions(gamma_role_lamps)
	var beta_nominal_lamp_radius := _telegraph_radius(beta_role_lamps)
	var gamma_nominal_lamp_radius := _telegraph_radius(gamma_role_lamps)
	var beta_role_lamp_ids := _node_instance_ids(beta_role_lamps)
	var gamma_role_lamp_ids := _node_instance_ids(gamma_role_lamps)
	var opponents: Array[RangeOpponent] = [alpha, beta, gamma]
	var asset := content.get_protected_asset()
	var damageable := asset.get_damageable_component() if asset != null else null
	var signal_ring := asset.get_node(^"Presentation/SignalRing") as MeshInstance3D if asset != null else null
	var signal_core := asset.get_node(^"Presentation/Core") as MeshInstance3D if asset != null else null
	var signal_light := asset.get_node(^"Presentation/SignalLight") as OmniLight3D if asset != null else null
	var signal_ring_id := signal_ring.get_instance_id() if signal_ring != null else 0
	var signal_core_id := signal_core.get_instance_id() if signal_core != null else 0
	var signal_light_id := signal_light.get_instance_id() if signal_light != null else 0
	var signal_ring_mesh_id := signal_ring.mesh.get_instance_id() if signal_ring != null else 0
	var signal_core_mesh_id := signal_core.mesh.get_instance_id() if signal_core != null else 0
	_check(
		alpha != null and beta != null and gamma != null
		and _count_direct_opponents(roster) == 3
		and content.find_children("*", "RangeOpponent", true, false).size() == 3
		and alpha.scene_file_path == "res://scenes/ships/range_opponent.tscn"
		and beta.scene_file_path == "res://scenes/ships/range_opponent.tscn"
		and gamma.scene_file_path == "res://scenes/ships/range_opponent.tscn"
		and alpha.get_node(^"AuthoritativeDamageable") is LifecycleDamageableAdapter
		and beta.get_node(^"AuthoritativeDamageable") is LifecycleDamageableAdapter
		and gamma.get_node(^"AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"the bounded roster remains three pre-created production RangeOpponents with existing lifecycle adapters"
	)
	_check(
		asset != null and asset.scene_file_path == ASSET_SCENE_PATH
		and asset.global_position == Vector3(90.0, 8.0, -70.0)
		and asset.get_meta("source_label") == &"NEW"
		and asset.get_meta("evidence_status") == &"modern_interpretation"
		and damageable is Damageable
		and damageable.name == &"AuthoritativeDamageable"
		and damageable.get_target_entity() == asset
		and is_equal_approx(damageable.get_maximum_health(), 240.0)
		and int(asset.get_asset_handle().generation) == 1
		and asset.audit().valid,
		"the dedicated modern perimeter asset has one existing Damageable as its sole health store"
	)
	var safe_presentation := asset.get_protected_asset_presentation_snapshot()
	var presentation_budget := safe_presentation.budget as Dictionary
	_check(
		safe_presentation.state_id == &"safe"
		and safe_presentation.wave_state_id == &"idle"
		and safe_presentation.effective_state_id == &"idle"
		and bool(safe_presentation.ring_visible)
		and bool(safe_presentation.core_visible)
		and bool(safe_presentation.light_visible)
		and is_equal_approx(float(safe_presentation.ring_scale), 1.0)
		and is_equal_approx(float(safe_presentation.core_scale), 1.0)
		and (safe_presentation.light_color as Color).is_equal_approx(Color(0.282, 0.859, 0.886, 1.0))
		and is_equal_approx(float(safe_presentation.light_energy), 2.4),
		"caller-supplied healthy snapshot presents the perimeter asset as a steady cyan full-form beacon"
	)
	var approaching_activity := (
		content.get_snapshot().host.activity as Dictionary
	).duplicate(true)
	approaching_activity["state_id"] = &"active"
	approaching_activity["current_wave_index"] = 0
	approaching_activity["wave_active"] = false
	approaching_activity["wave_delay_remaining_seconds"] = 0.5
	var approaching_result := asset.apply_activity_presentation_snapshot(approaching_activity)
	var approaching_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		approaching_result.accepted
		and approaching_presentation.wave_state_id == &"approaching"
		and approaching_presentation.effective_state_id == &"approaching"
		and is_equal_approx(float(approaching_presentation.ring_scale), 0.86)
		and is_equal_approx(float(approaching_presentation.core_scale), 1.08)
		and (approaching_presentation.light_color as Color).is_equal_approx(Color("6ba9ff"))
		and is_equal_approx(float(approaching_presentation.light_energy), 1.8),
		"a detached pre-wave activity snapshot contracts the same beacon into a distinct approach cue"
	)
	asset.apply_activity_presentation_snapshot(content.get_snapshot().host.activity)
	_check(
		int(presentation_budget.presentation_nodes) == 4
		and int(presentation_budget.mesh_instances) == 2
		and int(presentation_budget.lights) == 1
		and not bool(presentation_budget.runtime_node_allocation)
		and not bool(presentation_budget.runtime_resource_allocation)
		and int(presentation_budget.process_callbacks) == 0
		and not bool(safe_presentation.authority.health)
		and not bool(safe_presentation.authority.damage)
		and not bool(safe_presentation.authority.targeting)
		and not bool(safe_presentation.authority.objective)
		and not bool(safe_presentation.authority.rewards),
		"asset danger presentation reuses the exact fixed 4-node/2-mesh/1-light authority-free budget"
	)
	var forged_presentation := asset.get_snapshot()
	(forged_presentation.asset_handle as Dictionary)["generation"] = 999
	var before_forged_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		asset.apply_authority_presentation_snapshot(forged_presentation).reason == &"stale_presentation_snapshot"
		and asset.get_protected_asset_presentation_snapshot() == before_forged_presentation,
		"stale caller snapshot rejects without changing visible protected-asset state"
	)
	var physical_before_preflight := asset.get_snapshot()
	_check(
		asset.preflight_renew(0).reason == &"stale_asset_generation"
		and asset.preflight_renew(1).accepted
		and asset.get_snapshot() == physical_before_preflight,
		"physical renewal preflight checks exact generation without mutating asset or health"
	)
	var unavailable_asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	_check(
		unavailable_asset.preflight_renew(1).reason == &"damageable_unavailable",
		"physical renewal preflight rejects a missing authoritative Damageable before tree entry"
	)
	unavailable_asset.free()

	var definition := content.contract_definition
	var definition_audit := definition.audit() if definition != null else {}
	var contract := definition.instantiate_contract() if definition != null else null
	var contract_snapshot := contract.get_snapshot() if contract != null else {}
	var waves := contract_snapshot.get("waves", []) as Array
	_check(
		definition != null and definition.resource_path == DEFINITION_PATH
		and bool(definition_audit.get("valid", false))
		and contract != null and contract.is_configuration_valid()
		and int(definition_audit.get("wave_count", 0)) == 2
		and int(definition_audit.get("hostile_count", 0)) == 3
		and int(definition_audit.get("protected_asset_count", 0)) == 1
		and is_equal_approx(definition.later_wave_opening_duration_seconds, 1.25)
		and is_equal_approx(
			float((definition_audit.limits as Dictionary).later_wave_opening_duration_seconds),
			1.25
		)
		and waves.size() == 2
		and waves[0].wave_id == &"yard_approach"
		and int(waves[0].mode) == StationDefenseContract.WaveMode.ORDERED
		and waves[1].wave_id == &"dockside_relief"
		and int(waves[1].mode) == StationDefenseContract.WaveMode.SIMULTANEOUS
		and is_equal_approx(float(waves[1].delay_seconds), 0.5)
		and is_equal_approx(float(contract_snapshot.timeout_seconds), 12.0),
		"the bounded contract freezes two waves plus the authored 1.25 s relief-wave opening"
	)

	var initial := content.get_snapshot()
	var staging := initial.staging as Array
	_check(
		initial.content_ready and initial.precreated_roster_wired
		and initial.external_combat_authority_injected
		and not initial.owns_combat_authority
		and int(initial.opponent_count) == 3
		and int(initial.authored_node_count) == 24
		and int(initial.registered_hostile_source_count) == 3
		and resolver.get_registered_source_count() == 3
		and staging.size() == 3
		and staging[0].local_position == Vector3(-24.0, 6.0, -52.0)
		and staging[1].local_position == Vector3(0.0, 6.0, -38.0)
		and staging[2].local_position == Vector3(26.0, 10.0, -84.0)
		and _staging_rows_valid(staging)
		and _minimum_keep_clear_gap(staging) > StationDefenseEncounterContent.MIN_KEEP_CLEAR_GAP,
		"checked-in content authors a distinct core breach lane and lateral feint lane within the bounded staging roster"
	)
	_check(
		content.global_transform.is_equal_approx(AUDITED_WORLD_TRANSFORM)
		and _staging_world_clear(content, staging)
		and _aabb_world_clear(content, StationDefenseEncounterContent.PLAYER_SHIP_ORIGIN_ENVELOPE)
		and _aabb_world_clear(content, StationDefenseEncounterContent.HOSTILE_ORIGIN_LEASH),
		"audited world pose keeps all staging, engagement, and hostile-leash volumes clear of production collision"
	)
	_check(
		alpha.get("_target") == asset
		and beta.get("_target") == asset
		and gamma.get("_target") == asset
		and authority.get_source_id(alpha) == 2121
		and authority.get_source_id(beta) == 2122
		and authority.get_source_id(gamma) == 2123,
		"all opponent target, projectile, and stable source seams use the injected authority and dedicated asset"
	)

	var attacker := Node3D.new()
	attacker.name = "ExistingStationDefenseSource"
	root.add_child(attacker)
	var weapons := {
		TEST_WEAPON: {
			"range": 180.0,
			"damage": TEST_WEAPON_DAMAGE,
			"origin_tolerance": 8.0,
		},
	}
	_check(
		authority.register_source(attacker, TEST_SOURCE_ID, &"station_allies", weapons)
		and resolver.get_registered_source_count() == 4,
		"an existing session source shares the same resolver with the three encounter sources"
	)

	var started := content.start(0)
	var generation := int(started.activity.generation)
	var active_presentation := asset.get_protected_asset_presentation_snapshot()
	var expected_alpha_bearing := asset.global_basis.inverse() * (
		alpha.global_position - asset.global_position
	)
	expected_alpha_bearing.y = 0.0
	expected_alpha_bearing = expected_alpha_bearing.normalized()
	_check(
		started.accepted and generation == 1
		and alpha.is_active() and not beta.is_active() and not gamma.is_active()
		and active_presentation.wave_state_id == &"active"
		and active_presentation.effective_state_id == &"active"
		and is_equal_approx(float(active_presentation.ring_scale), 1.18)
		and is_equal_approx(float(active_presentation.light_energy), 3.0)
		and bool(active_presentation.hostile_bearing_active)
		and (active_presentation.hostile_bearing_local as Vector3).is_equal_approx(
			expected_alpha_bearing
		)
		and (active_presentation.core_position as Vector3).is_equal_approx(
			Vector3(0.0, 2.65, 0.0) + expected_alpha_bearing * 0.85
		)
		and int(active_presentation.hostile_bearing_source.activity_generation) == generation,
		"start activates only the ordered production opponent"
	)
	var before_stale_bearing := asset.get_protected_asset_presentation_snapshot()
	var stale_bearing := (
		active_presentation.hostile_bearing_source as Dictionary
	).duplicate(true)
	(stale_bearing.asset_handle as Dictionary)["generation"] = generation + 1
	_check(
		asset.apply_hostile_bearing_presentation_snapshot(stale_bearing).reason \
			== &"stale_hostile_bearing_snapshot"
		and asset.get_protected_asset_presentation_snapshot() == before_stale_bearing,
		"a mismatched asset/activity generation cannot redirect the visible approach bearing"
	)
	var alpha_hostile_shot := await _emit_hostile_projectile(alpha, asset, content)
	var alpha_terminal := await _shoot(authority, attacker, alpha)
	var recovery_presentation := asset.get_protected_asset_presentation_snapshot()
	var forming_tactic := content.get_snapshot().later_wave_tactic as Dictionary
	_check(
		recovery_presentation.wave_state_id == &"recovery"
		and recovery_presentation.effective_state_id == &"recovery"
		and is_equal_approx(float(recovery_presentation.ring_scale), 0.94)
		and is_equal_approx(float(recovery_presentation.core_scale), 0.86)
		and (recovery_presentation.light_color as Color).is_equal_approx(Color("4fb9a7"))
		and is_equal_approx(float(recovery_presentation.light_energy), 1.4)
		and not bool(recovery_presentation.hostile_bearing_active)
		and (recovery_presentation.core_position as Vector3).is_equal_approx(
			Vector3(0.0, 2.65, 0.0)
		),
		"the caller-owned inter-wave delay softens the fixed beacon into a recovery cue"
	)
	_check(
		forming_tactic.tactic_id == StationDefenseEncounterContent.LATER_WAVE_TACTIC_ID
		and forming_tactic.state_id == &"forming"
		and not bool(forming_tactic.active)
		and content.get_snapshot().breaker_feint.state_id == &"inbound"
		and str(forming_tactic.objective).contains("BREAKER INBOUND")
		and str(content.get_snapshot().host.activity.next_step).begins_with(
			str(forming_tactic.objective)
		)
		and str(content.get_snapshot().host.activity.next_step).contains(
			"PERIMETER CORE UNDER FIRE 95% [|||!]"
		),
		"inter-wave feedback warns of the breaker and outer feint while retaining non-color-only core pressure"
	)
	var relief := content.advance_physics(0.5, generation)
	await physics_frame
	var breaker_snapshot := content.get_snapshot()
	var breaker_feedback := breaker_snapshot.breaker_feint as Dictionary
	var breaker_roles := breaker_feedback.roles as Array
	var beta_breaker_pattern := beta.get_firing_pattern_snapshot()
	var gamma_feint_pattern := gamma.get_firing_pattern_snapshot()
	var gamma_feint_maneuver := gamma.get_evasive_maneuver_snapshot()
	_check(
		alpha_terminal.destroyed and relief.accepted
		and beta.is_active() and gamma.is_active()
		and breaker_feedback.tactic_id == StationDefenseEncounterContent.BREAKER_FEINT_TACTIC_ID
		and breaker_feedback.state_id == &"active"
		and bool(breaker_feedback.active)
		and is_zero_approx(float(breaker_feedback.elapsed_seconds))
		and is_equal_approx(float(breaker_feedback.duration_seconds), 1.25)
		and (breaker_roles[0] as Dictionary).role == &"core_breaker"
		and (breaker_roles[0] as Dictionary).approach == &"direct_zero_orbit"
		and (breaker_roles[0] as Dictionary).firing_pattern_id \
			== RangeOpponent.FIRE_PATTERN_SHORT_BURST
		and (breaker_roles[0] as Dictionary).pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_STEPPED_BURST
		and (breaker_roles[0] as Dictionary).telegraph_identity_pattern == "o O"
		and (breaker_roles[1] as Dictionary).role == &"outer_feint"
		and (breaker_roles[1] as Dictionary).approach == &"slow_counter_orbit"
		and (breaker_roles[1] as Dictionary).firing_pattern_id \
			== RangeOpponent.FIRE_PATTERN_SPACED_SUPPRESSION
		and (breaker_roles[1] as Dictionary).pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_SUPPRESSION_BRACE
		and (breaker_roles[1] as Dictionary).telegraph_identity_pattern == "O O"
		and (breaker_roles[1] as Dictionary).evasive_maneuver_id \
			== RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
		and is_equal_approx(beta.preferred_range, StationDefenseEncounterContent.BREAKER_PREFERRED_RANGE)
		and is_equal_approx(beta.cruise_speed, StationDefenseEncounterContent.BREAKER_CRUISE_SPEED)
		and is_equal_approx(beta.chase_speed, StationDefenseEncounterContent.BREAKER_CHASE_SPEED)
		and is_zero_approx(float(beta.get("_orbit_sign")))
		and is_equal_approx(gamma.preferred_range, StationDefenseEncounterContent.FEINT_PREFERRED_RANGE)
		and is_equal_approx(gamma.cruise_speed, StationDefenseEncounterContent.FEINT_CRUISE_SPEED)
		and is_equal_approx(gamma.chase_speed, StationDefenseEncounterContent.FEINT_CHASE_SPEED)
		and float(gamma.get("_orbit_sign")) == StationDefenseEncounterContent.FEINT_ORBIT_SIGN
		and beta_breaker_pattern.pattern_id == RangeOpponent.FIRE_PATTERN_SHORT_BURST
		and beta_breaker_pattern.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_STEPPED_BURST
		and int(beta_breaker_pattern.projectile_count_per_cycle) == 3
		and gamma_feint_pattern.pattern_id == RangeOpponent.FIRE_PATTERN_SPACED_SUPPRESSION
		and gamma_feint_pattern.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_SUPPRESSION_BRACE
		and is_equal_approx(
			float(gamma_feint_pattern.cooldown_multiplier),
			RangeOpponent.SUPPRESSION_COOLDOWN_MULTIPLIER
		)
		and gamma_feint_maneuver.maneuver_id \
			== RangeOpponent.EVASIVE_MANEUVER_LATERAL_BREAK
		and gamma_feint_maneuver.state_id == &"active"
		and is_equal_approx(float(gamma_feint_maneuver.direction_sign), -1.0)
		and str(breaker_snapshot.host.activity.next_step).contains(
			"STOP BETA BREAKER // GAMMA IS THE FEINT"
		),
		"the relief wave opens with a direct fast core breaker and a slower lateral feint on authored lanes"
	)
	for _frame in 18:
		await physics_frame
	var beta_to_core := (asset.global_position - beta.global_position).normalized()
	var gamma_radius_during_feint := gamma.global_position - asset.global_position
	var beta_closing_motion := beta.velocity.dot(beta_to_core)
	var gamma_feint_motion := gamma.velocity.dot(
		Vector3.UP.cross(gamma_radius_during_feint).normalized()
	)
	var gamma_maneuver_after_motion := gamma.get_evasive_maneuver_snapshot()
	_check(
		beta_closing_motion > 4.0
		and gamma_feint_motion > 2.0
		and beta_closing_motion > absf(
			gamma.velocity.dot((asset.global_position - gamma.global_position).normalized())
		)
		and gamma_maneuver_after_motion.state_id == &"active"
		and float(gamma_maneuver_after_motion.elapsed_seconds) > 0.25,
		"live motion separates Beta's zero-orbit core rush from Gamma's slower tangential feint"
	)
	var stale_breaker := content.advance_physics(0.4, generation + 1)
	var after_stale_breaker := content.get_snapshot().breaker_feint as Dictionary
	_check(
		not stale_breaker.accepted and stale_breaker.reason == &"stale_generation"
		and after_stale_breaker.state_id == &"active"
		and is_zero_approx(float(after_stale_breaker.elapsed_seconds))
		and is_equal_approx(beta.chase_speed, StationDefenseEncounterContent.BREAKER_CHASE_SPEED)
		and is_equal_approx(gamma.chase_speed, StationDefenseEncounterContent.FEINT_CHASE_SPEED),
		"a stale generation cannot consume breaker time or disturb the authored live roles"
	)
	var partial_breaker := content.advance_physics(0.6, generation)
	var partial_feedback := content.get_snapshot().breaker_feint as Dictionary
	_check(
		partial_breaker.accepted
		and partial_feedback.state_id == &"active"
		and is_equal_approx(float(partial_feedback.elapsed_seconds), 0.6)
		and is_equal_approx(float(partial_feedback.remaining_seconds), 0.65)
		and is_equal_approx(beta.chase_speed, StationDefenseEncounterContent.BREAKER_CHASE_SPEED),
		"only accepted caller physics advances the bounded breaker window while its live roles remain applied"
	)
	var pincer_transition := content.advance_physics(0.65, generation)
	var active_tactic := content.get_snapshot().later_wave_tactic as Dictionary
	var active_activity := content.get_snapshot().host.activity as Dictionary
	var beta_pincer_pattern := beta.get_firing_pattern_snapshot()
	var gamma_pincer_pattern := gamma.get_firing_pattern_snapshot()
	var gamma_pincer_maneuver := gamma.get_evasive_maneuver_snapshot()
	var close_role := (active_tactic.formation as Array)[0] as Dictionary
	var outer_role := (active_tactic.formation as Array)[1] as Dictionary
	_check(
		pincer_transition.accepted and beta.is_active() and gamma.is_active()
		and content.get_snapshot().breaker_feint.state_id == &"transitioned"
		and active_tactic.state_id == &"active"
		and bool(active_tactic.applied)
		and (active_tactic.formation as Array).size() == 2
		and is_equal_approx(beta.preferred_range, StationDefenseEncounterContent.PINCER_CLOSE_PREFERRED_RANGE)
		and is_equal_approx(gamma.preferred_range, StationDefenseEncounterContent.PINCER_OUTER_PREFERRED_RANGE)
		and float(beta.get("_orbit_sign")) == StationDefenseEncounterContent.PINCER_CLOSE_ORBIT_SIGN
		and float(gamma.get("_orbit_sign")) == StationDefenseEncounterContent.PINCER_OUTER_ORBIT_SIGN
		and is_equal_approx(beta.cruise_speed, beta_nominal_cruise_speed)
		and is_equal_approx(beta.chase_speed, beta_nominal_chase_speed)
		and is_equal_approx(gamma.cruise_speed, gamma_nominal_cruise_speed)
		and is_equal_approx(gamma.chase_speed, gamma_nominal_chase_speed)
		and beta_pincer_pattern.pattern_id == RangeOpponent.FIRE_PATTERN_SINGLE_SHOT
		and gamma_pincer_pattern.pattern_id == RangeOpponent.FIRE_PATTERN_SINGLE_SHOT
		and beta_pincer_pattern.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_UNIFORM_PAIR
		and gamma_pincer_pattern.pre_discharge_telegraph_id \
			== RangeOpponent.FIRE_TELEGRAPH_UNIFORM_PAIR
		and gamma_pincer_maneuver.maneuver_id == RangeOpponent.EVASIVE_MANEUVER_NONE
		and gamma_pincer_maneuver.state_id == &"cancelled"
		and close_role.telegraph_identity == &"compact_pair"
		and close_role.identity_pattern == "><"
		and bool(close_role.presentation_active)
		and outer_role.telegraph_identity == &"wide_guard"
		and outer_role.identity_pattern == "|    |"
		and bool(outer_role.presentation_active)
		and _telegraph_positions_match(
			beta_role_lamps,
			StationDefenseEncounterContent.PINCER_CLOSE_TELEGRAPH_POSITIONS
		)
		and _telegraph_positions_match(
			gamma_role_lamps,
			StationDefenseEncounterContent.PINCER_OUTER_TELEGRAPH_POSITIONS
		)
		and is_equal_approx(
			_telegraph_radius(beta_role_lamps),
			StationDefenseEncounterContent.PINCER_CLOSE_TELEGRAPH_RADIUS
		)
		and is_equal_approx(
			_telegraph_radius(gamma_role_lamps),
			StationDefenseEncounterContent.PINCER_OUTER_TELEGRAPH_RADIUS
		)
		and str(active_activity.next_step).contains("BREAK CROSSFIRE PINCER"),
		"the bounded opening restores nominal speeds before handing the same opponents to the sustained pincer"
	)
	for _frame in 42:
		await physics_frame
	var beta_radius := beta.global_position - asset.global_position
	var gamma_radius := gamma.global_position - asset.global_position
	var beta_orbit_motion := beta.velocity.dot(Vector3.UP.cross(beta_radius).normalized())
	var gamma_orbit_motion := gamma.velocity.dot(Vector3.UP.cross(gamma_radius).normalized())
	_check(
		absf(beta_orbit_motion) > 0.5
		and absf(gamma_orbit_motion) > 0.5
		and signf(beta_orbit_motion) != signf(gamma_orbit_motion),
		"the two live registered opponents apply visible counter-orbit pressure instead of one repeated approach"
	)
	var health_before_relief_manual_shots := damageable.get_health()
	var accepted_events_before_relief_manual_shots := int(
		content.get_snapshot().host.activity.accepted_asset_event_count
	)
	var beta_hostile_shot := await _emit_hostile_projectile(beta, asset, content)
	var gamma_hostile_shot := await _emit_hostile_projectile(gamma, asset, content)
	_check(
		alpha_hostile_shot.damaged and int(alpha_hostile_shot.source_id) == 2121
		and beta_hostile_shot.damaged and int(beta_hostile_shot.source_id) == 2122
		and gamma_hostile_shot.damaged and int(gamma_hostile_shot.source_id) == 2123
		and is_equal_approx(
			damageable.get_health(), health_before_relief_manual_shots - 22.0
		)
		and int(content.get_snapshot().host.activity.accepted_asset_event_count) \
			== accepted_events_before_relief_manual_shots + 2,
		"all three production projectile signals resolve through their exact injected-authority source identities"
	)
	var beta_terminal := await _shoot(authority, attacker, beta)
	var broken_tactic := content.get_snapshot().later_wave_tactic as Dictionary
	var broken_formation := broken_tactic.formation as Array
	_check(
		beta_terminal.destroyed
		and broken_tactic.state_id == &"broken"
		and not bool(broken_tactic.applied)
		and not bool((broken_formation[0] as Dictionary).presentation_active)
		and not bool((broken_formation[1] as Dictionary).presentation_active)
		and str(broken_tactic.objective).contains("FINISH REMAINING RAIDER")
		and is_equal_approx(gamma.preferred_range, gamma_nominal_preferred_range)
		and float(gamma.get("_orbit_sign")) == gamma_nominal_orbit_sign
		and is_equal_approx(beta.cruise_speed, beta_nominal_cruise_speed)
		and is_equal_approx(beta.chase_speed, beta_nominal_chase_speed)
		and is_equal_approx(gamma.cruise_speed, gamma_nominal_cruise_speed)
		and is_equal_approx(gamma.chase_speed, gamma_nominal_chase_speed)
		and _telegraph_positions_match(beta_role_lamps, beta_nominal_lamp_positions)
		and _telegraph_positions_match(gamma_role_lamps, gamma_nominal_lamp_positions)
		and is_equal_approx(_telegraph_radius(beta_role_lamps), beta_nominal_lamp_radius)
		and is_equal_approx(_telegraph_radius(gamma_role_lamps), gamma_nominal_lamp_radius)
		and _node_instance_ids(beta_role_lamps) == beta_role_lamp_ids
		and _node_instance_ids(gamma_role_lamps) == gamma_role_lamp_ids
		and beta_nominal_preferred_range == gamma_nominal_preferred_range,
		"destroying either pincer wing clears both role silhouettes and restores the exact retained lamps and nominal pursuit"
	)
	var gamma_terminal := await _shoot(authority, attacker, gamma)
	var completed := content.get_snapshot()
	var completed_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		beta_terminal.destroyed and gamma_terminal.destroyed
		and completed.host.activity.state_id == &"completed"
		and completed_presentation.wave_state_id == &"completed"
		and completed_presentation.effective_state_id == &"completed"
		and is_equal_approx(float(completed_presentation.ring_scale), 1.32)
		and (completed_presentation.light_color as Color).is_equal_approx(Color("77e69a"))
		and is_equal_approx(float(completed_presentation.light_energy), 3.4)
		and not bool(completed_presentation.hostile_bearing_active)
		and int(completed.host.destroyed_entity_count) == 3
		and int(completed.host.active_entity_count) == 0
		and completed.later_wave_tactic.state_id == &"completed"
		and str(completed.host.activity.next_step).contains("RECOVER AT DEFENSE BOARD")
		and not bool(completed.later_wave_tactic.applied)
		and resolver.get_registered_source_count() == 1,
		"three real resolver terminal results complete exactly once and retire every hostile source"
	)

	var reset_after_completion := content.reset(generation)
	var idle_generation := int(reset_after_completion.activity.generation)
	_check(
		reset_after_completion.accepted and idle_generation == 2
		and content.get_snapshot().breaker_feint.state_id == &"idle"
		and is_zero_approx(float(content.get_snapshot().breaker_feint.elapsed_seconds))
		and int(asset.get_asset_handle().generation) == 2
		and int(reset_after_completion.activity.protected_assets[0].handle.generation) == 2
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and _telegraph_positions_match(beta_role_lamps, beta_nominal_lamp_positions)
		and _telegraph_positions_match(gamma_role_lamps, gamma_nominal_lamp_positions)
		and is_equal_approx(_telegraph_radius(beta_role_lamps), beta_nominal_lamp_radius)
		and is_equal_approx(_telegraph_radius(gamma_role_lamps), gamma_nominal_lamp_radius)
		and asset.collision_layer == PhysicsLayers.TARGET,
		"post-completion reset keeps both role-lamp pairs nominal while renewing health/collision generation plus one"
	)
	var timeout_start := content.start(idle_generation)
	var timeout_generation := int(timeout_start.activity.generation)
	var observed_hostile_fire := {"count": 0}
	alpha.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		observed_hostile_fire.count = int(observed_hostile_fire.count) + 1
	)
	var full_physics_clear := true
	var timed_result: Dictionary = {}
	for _step in FULL_ENCOUNTER_PHYSICS_STEPS:
		await physics_frame
		for opponent in opponents:
			if opponent.is_active() and not _sphere_world_clear(content, opponent.global_position, 5.0):
				full_physics_clear = false
		timed_result = content.advance_physics(PHYSICS_STEP, timeout_generation)
		if StringName((timed_result.get("activity", {}) as Dictionary).get("state_id", &"")) \
			in [&"failed", &"aborted", &"timed_out", &"completed"]:
			break
	var asset_after_physics := asset.get_snapshot()
	_check(
		full_physics_clear
		and timed_result.accepted and timed_result.reason == &"timed_out"
		and timed_result.activity.state_id == &"timed_out"
		and not alpha.is_active()
		and float(asset_after_physics.health) < float(asset_after_physics.maximum_health)
		and not bool(asset_after_physics.destroyed)
		and int(asset_after_physics.damage_event_count) > 0
		and int(observed_hostile_fire.count) > 0
		and resolver.get_registered_source_count() == 1,
		"a full 12 s of real physics stays collision-clear, resolves hostile fire, times out, and retires cleanly"
	)

	var reset_after_timeout := content.reset(timeout_generation)
	var reentry_start := content.start(int(reset_after_timeout.activity.generation))
	var reentry_generation := int(reentry_start.activity.generation)
	var retained_content_id := content.get_instance_id()
	var retained_asset_id := asset.get_instance_id()
	var retained_alpha_id := alpha.get_instance_id()
	var retained_asset_generation := int(asset.get_asset_handle().generation)
	var retained_health := damageable.get_health()
	root.remove_child(content)
	await process_frame
	_check(
		not bool(content.get_snapshot().host.activity.attached)
		and resolver.get_registered_source_count() == 1
		and int(asset.get_asset_handle().generation) == retained_asset_generation
		and is_equal_approx(damageable.get_health(), retained_health),
		"whole-content detach retires hostile sources without changing objective, asset, health, or generation"
	)
	root.add_child(content)
	await process_frame
	await physics_frame
	await process_frame
	var reentry_integrity := content.get_snapshot().protected_asset_integrity as Dictionary
	_check(
		content.get_instance_id() == retained_content_id
		and asset.get_instance_id() == retained_asset_id
		and alpha.get_instance_id() == retained_alpha_id
		and bool(content.get_snapshot().host.activity.attached)
		and resolver.get_registered_source_count() == 4
		and int(asset.get_asset_handle().generation) == retained_asset_generation
		and is_equal_approx(damageable.get_health(), retained_health)
		and _telegraph_positions_match(beta_role_lamps, beta_nominal_lamp_positions)
		and _telegraph_positions_match(gamma_role_lamps, gamma_nominal_lamp_positions)
		and is_equal_approx(_telegraph_radius(beta_role_lamps), beta_nominal_lamp_radius)
		and is_equal_approx(_telegraph_radius(gamma_role_lamps), gamma_nominal_lamp_radius)
		and content.get_snapshot().breaker_feint.state_id == &"standby"
		and is_zero_approx(float(content.get_snapshot().breaker_feint.elapsed_seconds))
		and reentry_integrity.state_id == &"stable"
		and int(reentry_integrity.health_percent) == 100
		and reentry_integrity.pattern == "[||||]",
		"same-instance re-entry restores exact wiring with nominal retained role lamps and stable integrity without rebuilding or healing"
	)

	var renewal_reentry := {}
	asset.asset_destroyed.connect(
		func(_asset_handle: Dictionary, _event_handle: Dictionary) -> void:
			var before_reset := content.get_snapshot()
			var reset_result := content.reset(content.get_generation())
			renewal_reentry["result"] = reset_result.duplicate(true)
			renewal_reentry["snapshot_unchanged"] = content.get_snapshot() == before_reset
	)
	var first_asset_hit := await _shoot(authority, attacker, asset)
	var danger_presentation := asset.get_protected_asset_presentation_snapshot()
	var danger_integrity := content.get_snapshot().protected_asset_integrity as Dictionary
	_check(
		first_asset_hit.damaged
		and danger_presentation.state_id == &"danger"
		and danger_presentation.wave_state_id == &"active"
		and danger_presentation.effective_state_id == &"danger"
		and bool(danger_presentation.ring_visible)
		and is_equal_approx(float(danger_presentation.ring_scale), 1.12)
		and is_equal_approx(float(danger_presentation.core_scale), 0.92)
		and (danger_presentation.light_color as Color).is_equal_approx(Color("ffb14e"))
		and is_equal_approx(float(danger_presentation.light_energy), 3.1)
		and danger_integrity.state_id == &"under_fire"
		and int(danger_integrity.health_percent) == 58
		and danger_integrity.pattern == "[|||!]"
		and danger_integrity.semantic_cue_id == &"station_defense_asset_danger"
		and str(content.get_snapshot().host.activity.next_step).contains(
			"PERIMETER CORE UNDER FIRE 58% [|||!]"
		),
		"real authoritative damage adds an explicit under-fire percent/pattern to the retained objective alongside the beacon silhouette"
	)
	var second_asset_hit := await _shoot(authority, attacker, asset)
	var critical_presentation := asset.get_protected_asset_presentation_snapshot()
	var critical_integrity := content.get_snapshot().protected_asset_integrity as Dictionary
	_check(
		second_asset_hit.damaged
		and critical_presentation.state_id == &"critical"
		and critical_presentation.effective_state_id == &"critical"
		and bool(critical_presentation.ring_visible)
		and is_equal_approx(float(critical_presentation.ring_scale), 1.28)
		and is_equal_approx(float(critical_presentation.core_scale), 0.78)
		and (critical_presentation.light_color as Color).is_equal_approx(Color("ff3b35"))
		and is_equal_approx(float(critical_presentation.light_energy), 4.2)
		and critical_integrity.state_id == &"critical"
		and int(critical_integrity.health_percent) == 17
		and critical_integrity.pattern == "[|!!!]"
		and critical_integrity.semantic_cue_id == &"station_defense_asset_critical"
		and content.get_snapshot().host.activity.protected_asset_integrity_state == &"critical",
		"second real hit exposes critical text, percentage, and pattern through the retained HUD-safe activity"
	)
	var terminal_asset_hit := await _shoot(authority, attacker, asset)
	var asset_failure := content.get_snapshot()
	var destroyed_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		first_asset_hit.damaged and second_asset_hit.damaged
		and terminal_asset_hit.destroyed and damageable.is_destroyed()
		and asset.collision_layer == PhysicsLayers.NONE
		and asset_failure.host.activity.state_id == &"failed"
		and asset_failure.host.activity.failure_reason == &"protected_asset_destroyed"
		and asset_failure.protected_asset_integrity.state_id == &"failed"
		and int(asset_failure.protected_asset_integrity.health_percent) == 0
		and asset_failure.protected_asset_integrity.pattern == "[XXXX]"
		and asset_failure.protected_asset_integrity.semantic_cue_id \
			== &"station_defense_asset_destroyed"
		and str(asset_failure.host.activity.next_step).contains(
			"PERIMETER CORE FAILED 0% [XXXX]"
		)
		and resolver.get_registered_source_count() == 1,
		"only AuthoritativeDamageable health terminalizes the activity and retains an explicit failed/recovery readout"
	)
	_check(
		destroyed_presentation.state_id == &"destroyed"
		and destroyed_presentation.wave_state_id == &"recovery"
		and destroyed_presentation.effective_state_id == &"destroyed"
		and not bool(destroyed_presentation.ring_visible)
		and not bool(destroyed_presentation.core_visible)
		and not bool(destroyed_presentation.light_visible)
		and is_zero_approx(float(destroyed_presentation.light_energy)),
		"authoritative destruction darkens the beacon without presentation mutating collision or objective state"
	)
	var renewal_reentry_result := renewal_reentry.get("result", {}) as Dictionary
	_check(
		renewal_reentry_result.get("reason") == &"protected_asset_renewal_preflight_failed"
		and renewal_reentry_result.get("preflight_reason") == &"reentrant_call"
		and bool(renewal_reentry.get("snapshot_unchanged", false))
		and content.get_snapshot() == asset_failure,
		"asset-observer reset preflight rejects before host commit and leaves host/activity/physical state exact"
	)

	var reset_after_asset_failure := content.reset(reentry_generation)
	var renewed_generation := int(asset.get_asset_handle().generation)
	var renewed_presentation := asset.get_protected_asset_presentation_snapshot()
	var renewed_integrity := content.get_snapshot().protected_asset_integrity as Dictionary
	var leash_start := content.start(int(reset_after_asset_failure.activity.generation))
	var leash_generation := int(leash_start.activity.generation)
	_check(
		reset_after_asset_failure.accepted
		and renewed_generation == retained_asset_generation + 1
		and int(reset_after_asset_failure.activity.protected_assets[0].handle.generation) == renewed_generation
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and content.protected_asset_damaged(
			{"asset_id": StationDefensePerimeterAsset.ASSET_ID, "generation": retained_asset_generation},
			{"event_id": &"stale_physical_hit", "generation": retained_asset_generation},
			leash_generation
		).reason == &"stale_protected_asset_generation",
		"reset renews exact generation plus one and stale physical callbacks cannot mutate the new activity"
	)
	_check(
		renewed_presentation.state_id == &"safe"
		and renewed_presentation.wave_state_id == &"idle"
		and renewed_presentation.effective_state_id == &"idle"
		and bool(renewed_presentation.ring_visible)
		and bool(renewed_presentation.core_visible)
		and is_equal_approx(float(renewed_presentation.ring_scale), 1.0)
		and is_equal_approx(float(renewed_presentation.light_energy), 2.4)
		and signal_ring.get_instance_id() == signal_ring_id
		and signal_core.get_instance_id() == signal_core_id
		and signal_light.get_instance_id() == signal_light_id
		and signal_ring.mesh.get_instance_id() == signal_ring_mesh_id
		and signal_core.mesh.get_instance_id() == signal_core_mesh_id
		and renewed_integrity.state_id == &"stable"
		and int(renewed_integrity.health_percent) == 100
		and renewed_integrity.pattern == "[||||]"
		and renewed_integrity.semantic_cue_id == &"station_defense_asset_safe"
		and not str(content.get_snapshot().host.activity.next_step).contains("UNDER FIRE")
		and not str(content.get_snapshot().host.activity.next_step).contains("CRITICAL")
		and not str(content.get_snapshot().host.activity.next_step).contains("FAILED"),
		"renewal clears pressure feedback and restores stable text/pattern on the same fixed beacon nodes and resources"
	)
	alpha.global_position = content.to_global(Vector3(40.0, 8.0, -60.0))
	var leash_result := content.advance_physics(0.0, leash_generation)
	var after_leash := content.get_snapshot()
	_check(
		not leash_result.accepted and leash_result.reason == &"engagement_leash_exited"
		and after_leash.host.activity.state_id == &"aborted"
		and after_leash.last_leash_exit.hostile_id == &"perimeter_raider_alpha"
		and after_leash.last_leash_exit.policy == &"abort_then_retire"
		and not alpha.is_active()
		and resolver.get_registered_source_count() == 1,
		"leash exit first aborts through public host authority, then retires the hostile and its source"
	)
	var audited_pose := content.global_transform
	content.global_position += Vector3(1.0, 0.0, 0.0)
	var pose_red := content.audit()
	_check(
		not bool(pose_red.valid)
		and "encounter live transform differs from the audited world site" in pose_red.errors
		and not bool(pose_red.snapshot.engagement.live_pose_matches_required)
		and content.start(leash_generation).reason == &"audited_world_pose_required",
		"live pose mutation is structured red and cannot start while reporting the required audited site"
	)
	content.global_transform = audited_pose

	var detached_snapshot := content.get_snapshot()
	(detached_snapshot.staging as Array).clear()
	(detached_snapshot.host.spawn_roster as Array).clear()
	(detached_snapshot.protected_asset.asset_handle as Dictionary)["generation"] = 999
	(detached_snapshot.authority_exclusions as Dictionary)["rewards"] = true
	var audit_first := content.audit()
	var audit_second := content.audit()
	_check(
		(content.get_snapshot().staging as Array).size() == 3
		and (content.get_snapshot().host.spawn_roster as Array).size() == 3
		and int(content.get_snapshot().protected_asset.asset_handle.generation) == renewed_generation
		and not bool(content.get_snapshot().authority_exclusions.rewards)
		and audit_first == audit_second and bool(audit_first.valid)
		and audit_first.evidence.evidence_status == &"modern_interpretation"
		and not bool(audit_first.evidence.historically_supported),
		"HUD-ready snapshots are deeply detached and the content audit is deterministic modern interpretation"
	)
	_check(
		_authority_is_exactly_excluded(audit_first.authority_exclusions)
		and _authority_is_exactly_excluded(definition_audit.authority_exclusions)
		and _authority_is_exactly_excluded(after_leash.authority_exclusions),
		"content, definition, and runtime snapshots freeze zero reward/save/network/ship/berth/world authority"
	)

	var content_source := FileAccess.get_file_as_string(CONTENT_SCRIPT_PATH)
	var scene_source := FileAccess.get_file_as_string(CONTENT_SCENE_PATH)
	var asset_source := FileAccess.get_file_as_string(
		"res://scripts/activities/station_defense_perimeter_asset.gd"
	)
	_check(
		not content_source.contains("func _process(")
		and not content_source.contains("func _physics_process(")
		and not content_source.contains("Time.")
		and not content_source.contains("apply_damage(")
		and not asset_source.contains("func _process(")
		and not asset_source.contains("func _physics_process(")
		and not scene_source.contains("LiveCombatAuthority")
		and not scene_source.contains("CombatResolver")
		and not scene_source.contains("name=\"Resolver\""),
		"content owns no hidden clock, damage path, internal authority, or resolver node"
	)

	root.remove_child(content)
	content.queue_free()
	root.remove_child(attacker)
	attacker.queue_free()
	root.remove_child(authority)
	authority.queue_free()
	var fleet_expansion := world.get_fleet_expansion_production_binding()
	if fleet_expansion != null:
		for craft_id: StringName in [
			&"cinder_cargo_hauler",
			&"cinder_long_range_bomber",
			&"cinder_light_interceptor",
		]:
			fleet_expansion.detach_craft(craft_id)
	root.remove_child(world)
	world.queue_free()
	for _frame in 10:
		await process_frame


func _test_source_conflict_rolls_back_atomically() -> void:
	var authority := LiveCombatAuthority.new()
	authority.name = "ConflictSessionCombatAuthority"
	root.add_child(authority)
	var conflicting_source := Node3D.new()
	conflicting_source.name = "ExistingSourceOwning2122"
	root.add_child(conflicting_source)
	await process_frame
	var conflict_profiles := {
		&"existing_weapon": {"range": 50.0, "damage": 1.0, "origin_tolerance": 2.0},
	}
	_check(
		authority.register_source(
			conflicting_source, 2122, &"existing_session_faction", conflict_profiles
		),
		"conflict fixture owns the fixed beta source ID before encounter injection"
	)
	var resolver := authority.get_resolver()
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	root.add_child(content)
	await process_frame
	var configured := content.configure_external_combat_authority(authority)
	await process_frame
	var roster := content.get_node(^"OpponentRoster") as Node3D
	var alpha := roster.get_node(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node(^"PerimeterRaiderGamma") as RangeOpponent
	var failed_snapshot := content.get_snapshot()
	_check(
		not configured.accepted
		and configured.reason == &"configuration_failed_terminal"
		and not content.is_content_ready()
		and failed_snapshot.configuration_state == &"configuration_failed_terminal"
		and not failed_snapshot.initialization_errors.is_empty()
		and not bool(failed_snapshot.host.configured)
		and int(failed_snapshot.registered_hostile_source_count) == 0,
		"fixed-ID conflict terminalizes configuration before the Host is bound"
	)
	_check(
		resolver.get_registered_source_count() == 1
		and authority.get_source_id(conflicting_source) == 2122
		and authority.get_source_id(alpha) == 0
		and authority.get_source_id(beta) == 0
		and authority.get_source_id(gamma) == 0
		and content.find_children("*", "LiveCombatAuthority", true, false).is_empty()
		and content.find_children("*", "CombatResolver", true, false).is_empty()
		and authority.find_children("*", "CombatResolver", true, false).size() == 1,
		"failed acquisition rolls back every new source and creates no authority or resolver duplicate"
	)
	var replacement_source := Node3D.new()
	replacement_source.name = "ReplacementSourceForRolledBack2121"
	root.add_child(replacement_source)
	_check(
		authority.register_source(
			replacement_source, 2121, &"replacement_faction", conflict_profiles
		)
		and resolver.get_registered_source_count() == 2,
		"rollback forgets the transient stable-ID owner so a later session source can acquire 2121"
	)
	authority.forget_source(replacement_source, 2121)
	root.remove_child(replacement_source)
	replacement_source.queue_free()
	_check(
		content.configure_external_combat_authority(authority).reason \
			== &"configuration_failed_terminal",
		"terminal configuration failure is explicit and cannot partially retry the bound content"
	)
	root.remove_child(content)
	content.queue_free()
	await process_frame
	_check(
		resolver.get_registered_source_count() == 1
		and authority.get_source_id(conflicting_source) == 2122,
		"failed content exit preserves only the caller's prior source registration"
	)
	root.remove_child(conflicting_source)
	conflicting_source.queue_free()
	await process_frame
	root.remove_child(authority)
	authority.queue_free()
	for _frame in 4:
		await process_frame


func _emit_hostile_projectile(
	opponent: RangeOpponent,
	asset: StationDefensePerimeterAsset,
	content: StationDefenseEncounterContent
	) -> Dictionary:
	await physics_frame
	await process_frame
	var origin := opponent.global_position
	var direction := (asset.global_position - origin).normalized()
	opponent.projectile_fired.emit(origin, direction)
	await process_frame
	return (content.get_snapshot().last_hostile_shot as Dictionary).duplicate(true)


func _shoot(
	authority: LiveCombatAuthority,
	attacker: Node3D,
	target: Node3D
	) -> Dictionary:
	await physics_frame
	await process_frame
	var aim_position := target.global_position
	if target is RangeOpponent:
		var keel := target.get_node_or_null(^"KeelCollision") as CollisionShape3D
		if keel != null:
			aim_position = keel.global_position
	attacker.global_position = aim_position + Vector3(0.0, 0.0, 18.0)
	var result := authority.submit_hitscan(
		attacker,
		TEST_WEAPON,
		attacker.global_position,
		(aim_position - attacker.global_position).normalized()
	)
	await process_frame
	return result


func _staging_world_clear(
	content: StationDefenseEncounterContent,
	staging: Array
	) -> bool:
	for row_value in staging:
		var row := row_value as Dictionary
		if not _sphere_world_clear(
			content,
			row.world_position as Vector3,
			float(row.keep_clear_radius)
		):
			return false
	return true


func _sphere_world_clear(
	content: StationDefenseEncounterContent,
	world_position: Vector3,
	radius: float
	) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, world_position)
	query.collision_mask = PhysicsLayers.WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = true
	return content.get_world_3d().direct_space_state.intersect_shape(query, 64).is_empty()


func _aabb_world_clear(
	content: StationDefenseEncounterContent,
	local_bounds: AABB
	) -> bool:
	var shape := BoxShape3D.new()
	shape.size = local_bounds.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		content.global_basis,
		content.to_global(local_bounds.position + local_bounds.size * 0.5)
	)
	query.collision_mask = PhysicsLayers.WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = true
	return content.get_world_3d().direct_space_state.intersect_shape(query, 64).is_empty()


func _minimum_keep_clear_gap(staging: Array) -> float:
	var minimum := INF
	for left_index in staging.size():
		var left := staging[left_index] as Dictionary
		for right_index in range(left_index + 1, staging.size()):
			var right := staging[right_index] as Dictionary
			minimum = minf(
				minimum,
				(left.local_position as Vector3).distance_to(right.local_position as Vector3)
					- float(left.keep_clear_radius)
					- float(right.keep_clear_radius)
			)
	return minimum


func _staging_rows_valid(staging: Array) -> bool:
	for row_value in staging:
		var row := row_value as Dictionary
		if not is_equal_approx(float(row.keep_clear_radius), 9.0) \
			or not bool(row.query_inert):
			return false
	return true


func _count_direct_opponents(roster: Node3D) -> int:
	var count := 0
	for child in roster.get_children():
		if child is RangeOpponent:
			count += 1
	return count


func _weapon_telegraph_nodes(opponent: RangeOpponent) -> Array[MeshInstance3D]:
	var nodes: Array[MeshInstance3D] = []
	var visual := opponent.get_node(^"RangeInterceptorVisual") as Node3D
	var audit := opponent.get_weapon_telegraph_mesh_allocation_audit()
	for path_text in audit.get("node_paths", PackedStringArray()) as PackedStringArray:
		var node := visual.get_node(NodePath(path_text)) as MeshInstance3D
		nodes.append(node)
	return nodes


func _telegraph_positions(nodes: Array[MeshInstance3D]) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for node in nodes:
		positions.append(node.position)
	return positions


func _telegraph_positions_match(nodes: Array[MeshInstance3D], expected: Array) -> bool:
	if nodes.size() != expected.size():
		return false
	for index in nodes.size():
		if not nodes[index].position.is_equal_approx(expected[index] as Vector3):
			return false
	return true


func _telegraph_radius(nodes: Array[MeshInstance3D]) -> float:
	if nodes.is_empty():
		return 0.0
	var sphere := nodes[0].mesh as SphereMesh
	return sphere.radius if sphere != null else 0.0


func _node_instance_ids(nodes: Array[MeshInstance3D]) -> Array[int]:
	var ids: Array[int] = []
	for node in nodes:
		ids.append(node.get_instance_id())
	return ids


func _authority_is_exactly_excluded(authority: Dictionary) -> bool:
	for key in [
		&"rewards", &"ships", &"berths", &"world_geometry", &"hud",
		&"game_flow", &"main", &"save", &"network",
	]:
		if bool(authority.get(key, true)):
			return false
	return true


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
		return true
	_failures.append(description)
	push_error("FAIL: " + description)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("Station defense encounter content tests passed: ", _assertions, " assertions")
		quit(0)
		return
	print(
		"Station defense encounter content tests failed: ",
		_failures.size(),
		" of ",
		_assertions,
		" assertions"
	)
	for failure in _failures:
		print(" - ", failure)
	quit(1)
