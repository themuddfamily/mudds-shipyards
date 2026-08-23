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
		and waves.size() == 2
		and waves[0].wave_id == &"yard_approach"
		and int(waves[0].mode) == StationDefenseContract.WaveMode.ORDERED
		and waves[1].wave_id == &"dockside_relief"
		and int(waves[1].mode) == StationDefenseContract.WaveMode.SIMULTANEOUS
		and is_equal_approx(float(waves[1].delay_seconds), 0.5)
		and is_equal_approx(float(contract_snapshot.timeout_seconds), 12.0),
		"the original bounded contract still freezes one ordered and one simultaneous wave"
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
		and staging[1].local_position == Vector3(24.0, 6.0, -52.0)
		and staging[2].local_position == Vector3(0.0, 10.0, -86.0)
		and _staging_rows_valid(staging)
		and _minimum_keep_clear_gap(staging) > StationDefenseEncounterContent.MIN_KEEP_CLEAR_GAP,
		"checked-in content keeps exact bounded nodes, sources, staging identities, and 9 m volumes"
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
	_check(
		started.accepted and generation == 1
		and alpha.is_active() and not beta.is_active() and not gamma.is_active()
		and active_presentation.wave_state_id == &"active"
		and active_presentation.effective_state_id == &"active"
		and is_equal_approx(float(active_presentation.ring_scale), 1.18)
		and is_equal_approx(float(active_presentation.light_energy), 3.0),
		"start activates only the ordered production opponent"
	)
	var alpha_hostile_shot := await _emit_hostile_projectile(alpha, asset, content)
	var alpha_terminal := await _shoot(authority, attacker, alpha)
	var recovery_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		recovery_presentation.wave_state_id == &"recovery"
		and recovery_presentation.effective_state_id == &"recovery"
		and is_equal_approx(float(recovery_presentation.ring_scale), 0.94)
		and is_equal_approx(float(recovery_presentation.core_scale), 0.86)
		and (recovery_presentation.light_color as Color).is_equal_approx(Color("4fb9a7"))
		and is_equal_approx(float(recovery_presentation.light_energy), 1.4),
		"the caller-owned inter-wave delay softens the fixed beacon into a recovery cue"
	)
	var relief := content.advance_physics(0.5, generation)
	await physics_frame
	_check(
		alpha_terminal.destroyed and relief.accepted
		and beta.is_active() and gamma.is_active(),
		"resolver terminal authority and exact caller delta activate the simultaneous relief wave"
	)
	var beta_hostile_shot := await _emit_hostile_projectile(beta, asset, content)
	var gamma_hostile_shot := await _emit_hostile_projectile(gamma, asset, content)
	_check(
		alpha_hostile_shot.damaged and int(alpha_hostile_shot.source_id) == 2121
		and beta_hostile_shot.damaged and int(beta_hostile_shot.source_id) == 2122
		and gamma_hostile_shot.damaged and int(gamma_hostile_shot.source_id) == 2123
		and is_equal_approx(damageable.get_health(), 207.0)
		and int(content.get_snapshot().host.activity.accepted_asset_event_count) == 3,
		"all three production projectile signals resolve through their exact injected-authority source identities"
	)
	var beta_terminal := await _shoot(authority, attacker, beta)
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
		and int(completed.host.destroyed_entity_count) == 3
		and int(completed.host.active_entity_count) == 0
		and resolver.get_registered_source_count() == 1,
		"three real resolver terminal results complete exactly once and retire every hostile source"
	)

	var reset_after_completion := content.reset(generation)
	var idle_generation := int(reset_after_completion.activity.generation)
	_check(
		reset_after_completion.accepted and idle_generation == 2
		and int(asset.get_asset_handle().generation) == 2
		and int(reset_after_completion.activity.protected_assets[0].handle.generation) == 2
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and asset.collision_layer == PhysicsLayers.TARGET,
		"post-completion reset commits host renewal before physical health/collision generation plus one"
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
	_check(
		content.get_instance_id() == retained_content_id
		and asset.get_instance_id() == retained_asset_id
		and alpha.get_instance_id() == retained_alpha_id
		and bool(content.get_snapshot().host.activity.attached)
		and resolver.get_registered_source_count() == 4
		and int(asset.get_asset_handle().generation) == retained_asset_generation
		and is_equal_approx(damageable.get_health(), retained_health),
		"same-instance re-entry restores exact authority/source wiring without rebuilding or healing"
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
	_check(
		first_asset_hit.damaged
		and danger_presentation.state_id == &"danger"
		and danger_presentation.wave_state_id == &"active"
		and danger_presentation.effective_state_id == &"danger"
		and bool(danger_presentation.ring_visible)
		and is_equal_approx(float(danger_presentation.ring_scale), 1.12)
		and is_equal_approx(float(danger_presentation.core_scale), 0.92)
		and (danger_presentation.light_color as Color).is_equal_approx(Color("ffb14e"))
		and is_equal_approx(float(danger_presentation.light_energy), 3.1),
		"real authoritative damage expands the ring and warms the practical into a readable danger state"
	)
	var second_asset_hit := await _shoot(authority, attacker, asset)
	var critical_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		second_asset_hit.damaged
		and critical_presentation.state_id == &"critical"
		and critical_presentation.effective_state_id == &"critical"
		and bool(critical_presentation.ring_visible)
		and is_equal_approx(float(critical_presentation.ring_scale), 1.28)
		and is_equal_approx(float(critical_presentation.core_scale), 0.78)
		and (critical_presentation.light_color as Color).is_equal_approx(Color("ff3b35"))
		and is_equal_approx(float(critical_presentation.light_energy), 4.2),
		"second real hit widens the silhouette and turns its bounded practical critical red"
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
		and resolver.get_registered_source_count() == 1,
		"only AuthoritativeDamageable health emits protected destruction, which the host observes and terminalizes"
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
		and signal_core.mesh.get_instance_id() == signal_core_mesh_id,
		"renewal restores the cyan full-form beacon on the same fixed nodes and resources"
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
