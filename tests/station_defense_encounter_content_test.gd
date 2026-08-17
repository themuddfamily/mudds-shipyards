extends SceneTree

## Focused checked-in content integration. The scene supplies its own exact
## contract, physical staging, production RangeOpponent roster, host, and real
## resolver; the fixture supplies only an existing combat source and physics
## deltas that a future world integration would already own.

const CONTENT_SCENE := preload("res://scenes/activities/station_defense_encounter.tscn")
const CONTENT_SCRIPT_PATH := "res://scripts/activities/station_defense_encounter_content.gd"
const DEFINITION_PATH := "res://assets/activities/shipyard_perimeter_defense.tres"
const TEST_WEAPON: StringName = &"content_integration_cannon"
const TEST_SOURCE_ID := 9201

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_checked_in_encounter_content()
	_check(
		root.get_child_count() == original_root_child_count,
		"content fixture removes its scene instance and external combat source"
	)
	_finish()


func _test_checked_in_encounter_content() -> void:
	var content := CONTENT_SCENE.instantiate() as StationDefenseEncounterContent
	_check(
		content != null
		and content.scene_file_path == "res://scenes/activities/station_defense_encounter.tscn"
		and content.get_meta("evidence_status") == &"modern_interpretation",
		"the checked-in encounter scene instantiates as the production content type"
	)
	root.add_child(content)
	await process_frame
	await physics_frame

	var host := content.get_node_or_null(^"Host") as StationDefenseEncounterHost
	var authority := content.get_node_or_null(^"CombatAuthority") as LiveCombatAuthority
	var resolver := authority.get_resolver() if authority != null else null
	var roster := content.get_node_or_null(^"OpponentRoster") as Node3D
	var alpha := roster.get_node_or_null(^"PerimeterRaiderAlpha") as RangeOpponent
	var beta := roster.get_node_or_null(^"PerimeterRaiderBeta") as RangeOpponent
	var gamma := roster.get_node_or_null(^"PerimeterRaiderGamma") as RangeOpponent
	_check(
		content.is_content_ready()
		and host != null and authority != null and resolver is CombatResolver
		and content.get_host() == host
		and content.get_combat_authority() == authority
		and host.get_combat_authority() == authority,
		"scene readiness composes one existing host with one live production resolver"
	)
	_check(
		alpha != null and beta != null and gamma != null
		and alpha.scene_file_path == "res://scenes/ships/range_opponent.tscn"
		and beta.scene_file_path == "res://scenes/ships/range_opponent.tscn"
		and gamma.scene_file_path == "res://scenes/ships/range_opponent.tscn",
		"the exact roster is three pre-created instances of the production RangeOpponent scene"
	)
	_check(
		alpha.get_node_or_null(^"AuthoritativeDamageable") is LifecycleDamageableAdapter
		and beta.get_node_or_null(^"AuthoritativeDamageable") is LifecycleDamageableAdapter
		and gamma.get_node_or_null(^"AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"checked-in opponents are wired through the existing lifecycle adapter seam"
	)

	var definition := content.contract_definition
	var definition_audit := definition.audit() if definition != null else {}
	var contract := definition.instantiate_contract() if definition != null else null
	_check(
		definition != null and definition.resource_path == DEFINITION_PATH
		and bool(definition_audit.get("valid", false))
		and contract != null and contract.is_configuration_valid()
		and int(definition_audit.get("wave_count", 0)) == 2
		and int(definition_audit.get("hostile_count", 0)) == 3
		and int(definition_audit.get("protected_asset_count", 0)) == 1
		and int((definition_audit.limits as Dictionary).maximum_content_hostiles) == 8,
		"one checked-in bounded resource supplies the exact validated activity contract"
	)
	var contract_snapshot := contract.get_snapshot() if contract != null else {}
	var waves := contract_snapshot.get("waves", []) as Array
	_check(
		contract_snapshot.get("activity_id") == &"shipyard_perimeter_defense"
		and waves.size() == 2
		and waves[0].wave_id == &"yard_approach"
		and int(waves[0].mode) == StationDefenseContract.WaveMode.ORDERED
		and (waves[0].hostile_handles as Array).size() == 1
		and waves[1].wave_id == &"dockside_relief"
		and int(waves[1].mode) == StationDefenseContract.WaveMode.SIMULTANEOUS
		and is_equal_approx(float(waves[1].delay_seconds), 0.5)
		and (waves[1].hostile_handles as Array).size() == 2
		and is_equal_approx(float(contract_snapshot.timeout_seconds), 12.0),
		"resource freezes one ordered probe and one delayed simultaneous relief wave"
	)

	var initial := content.get_snapshot()
	var host_roster := initial.host.spawn_roster as Array
	_check(
		bool(initial.content_ready) and bool(initial.precreated_roster_wired)
		and int(initial.opponent_count) == 3
		and int(initial.authored_node_count) == 18
		and host_roster.size() == 3
		and host_roster[0].hostile_id == &"perimeter_raider_alpha"
		and host_roster[1].hostile_id == &"perimeter_raider_beta"
		and host_roster[2].hostile_id == &"perimeter_raider_gamma",
		"scene initialization closes manual caller staging in deterministic contract order"
	)
	_check(
		_count_direct_opponents(roster) == 3
		and content.find_children("*", "RangeOpponent", true, false).size() == 3
		and int(initial.authored_node_count) <= StationDefenseEncounterContent.MAX_AUTHORED_NODE_COUNT,
		"authored nodes and production opponents remain within exact component-local bounds"
	)

	var staging := initial.staging as Array
	_check(
		staging.size() == 3
		and staging[0].hostile_id == &"perimeter_raider_alpha"
		and staging[0].local_position == Vector3(-24.0, 6.0, -52.0)
		and staging[1].hostile_id == &"perimeter_raider_beta"
		and staging[1].local_position == Vector3(24.0, 6.0, -52.0)
		and staging[2].hostile_id == &"perimeter_raider_gamma"
		and staging[2].local_position == Vector3(0.0, 10.0, -86.0)
		and _staging_rows_valid(staging),
		"each stable handle has one deterministic marker and centered 9 m query-inert volume"
	)
	_check(
		_minimum_keep_clear_gap(staging) > StationDefenseEncounterContent.MIN_KEEP_CLEAR_GAP,
		"all authored keep-clear spheres have more than the required physical separation"
	)
	_check(
		_distinct_ship_colliders_in_volume(content, "AlphaSpawn").is_empty()
		and _distinct_ship_colliders_in_volume(content, "BetaSpawn").is_empty()
		and _distinct_ship_colliders_in_volume(content, "GammaSpawn").is_empty(),
		"dormant staging volumes begin clear of every ship collision body"
	)

	var attacker := Node3D.new()
	attacker.name = "ExistingStationDefenseSource"
	root.add_child(attacker)
	var weapons := {
		TEST_WEAPON: {"range": 120.0, "damage": 50.0, "origin_tolerance": 8.0},
	}
	_check(
		authority.register_source(attacker, TEST_SOURCE_ID, &"station_allies", weapons)
		and resolver.get_registered_source_count() == 1,
		"the content reuses a caller-owned source registration on its one resolver"
	)
	var started := content.start(0)
	var generation := int(started.activity.generation)
	var alpha_marker := content.get_node(^"SpawnStaging/AlphaSpawn") as Marker3D
	await physics_frame
	_check(
		started.accepted and generation == 1
		and alpha.is_active() and not beta.is_active() and not gamma.is_active()
		and alpha.global_transform.is_equal_approx(alpha_marker.global_transform),
		"start activates only the ordered wave hostile at its authored physical marker"
	)
	var alpha_space := _distinct_ship_colliders_in_volume(content, "AlphaSpawn")
	_check(
		alpha_space.size() == 1 and alpha_space.has(alpha.get_instance_id()),
		"the active ordered hostile occupies its own otherwise-clear staging volume"
	)

	var alpha_first := await _shoot(authority, attacker, alpha)
	var alpha_health_before_detach := alpha.get_health()
	var elapsed_before_detach := float(content.get_snapshot().host.activity.elapsed_seconds)
	_check(
		bool(alpha_first.get("damaged", false))
		and not bool(alpha_first.get("destroyed", false))
		and is_equal_approx(alpha_health_before_detach, 35.0),
		"real resolver damage changes only the existing opponent hull before streaming"
	)
	root.remove_child(content)
	await process_frame
	_check(
		not bool(content.get_snapshot().host.activity.attached)
		and alpha.is_active()
		and is_equal_approx(alpha.get_health(), alpha_health_before_detach)
		and is_equal_approx(
			float(content.get_snapshot().host.activity.elapsed_seconds), elapsed_before_detach
		),
		"whole-content detach preserves the same active opponent, hull, and caller-owned clock"
	)
	root.add_child(content)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		bool(content.get_snapshot().host.activity.attached)
		and alpha.is_active()
		and is_equal_approx(alpha.get_health(), alpha_health_before_detach)
		and resolver.get_registered_source_count() == 1,
		"same-instance re-entry restores host observation without rebuilding roster or resolver"
	)

	var alpha_terminal := await _shoot(authority, attacker, alpha)
	_check(
		bool(alpha_terminal.get("destroyed", false)) and not alpha.is_active()
		and not beta.is_active() and not gamma.is_active()
		and is_equal_approx(
			float(content.get_snapshot().host.activity.wave_delay_remaining_seconds), 0.5
		),
		"terminal resolver damage completes wave one and enters the caller-timed delay"
	)
	var relief := content.advance_physics(0.5, generation)
	await physics_frame
	await physics_frame
	_check(
		relief.accepted and int(relief.activity.current_wave_index) == 1
		and beta.is_active() and gamma.is_active()
		and beta.global_position == Vector3(24.0, 6.0, -52.0)
		and gamma.global_position == Vector3(0.0, 10.0, -86.0),
		"the exact caller delta simultaneously activates both relief-wave scene instances"
	)
	var beta_space := _distinct_ship_colliders_in_volume(content, "BetaSpawn")
	var gamma_space := _distinct_ship_colliders_in_volume(content, "GammaSpawn")
	print("OBSERVATION_STATION_DEFENSE_RELIEF_KEEP_CLEAR: beta=", beta_space, " gamma=", gamma_space)
	_check(
		beta_space.size() == 1 and beta_space.has(beta.get_instance_id())
		and gamma_space.size() == 1 and gamma_space.has(gamma.get_instance_id()),
		"simultaneous hostiles occupy separate keep-clear volumes without collision intrusion"
	)

	await _shoot(authority, attacker, beta)
	var beta_terminal := await _shoot(authority, attacker, beta)
	await _shoot(authority, attacker, gamma)
	var gamma_terminal := await _shoot(authority, attacker, gamma)
	var completed := content.get_snapshot()
	_check(
		bool(beta_terminal.get("destroyed", false))
		and bool(gamma_terminal.get("destroyed", false))
		and completed.host.activity.state_id == "completed"
		and int(completed.host.activity.remaining_hostile_count) == 0
		and int(completed.host.destroyed_entity_count) == 3
		and int(completed.host.active_entity_count) == 0,
		"real production resolver terminal results complete the checked-in contract exactly once"
	)

	var detached_snapshot := content.get_snapshot()
	(detached_snapshot.staging as Array).clear()
	(detached_snapshot.host.spawn_roster as Array).clear()
	(detached_snapshot.evidence as Dictionary)["evidence_status"] = &"historical"
	(detached_snapshot.authority_exclusions as Dictionary)["rewards"] = true
	_check(
		(content.get_snapshot().staging as Array).size() == 3
		and (content.get_snapshot().host.spawn_roster as Array).size() == 3
		and content.get_snapshot().evidence.evidence_status == &"modern_interpretation"
		and not bool(content.get_snapshot().authority_exclusions.rewards),
		"HUD-ready scene snapshot is deeply detached from content and authority data"
	)

	var audit_first := content.audit()
	var audit_second := content.audit()
	_check(
		audit_first == audit_second and bool(audit_first.valid)
		and audit_first.evidence.evidence_status == &"modern_interpretation"
		and not bool(audit_first.evidence.historically_supported)
		and not bool(definition_audit.evidence.authenticated_original_encounter),
		"content and resource audits are deterministic and explicitly modern interpretation"
	)
	_check(
		_authority_is_excluded(audit_first.authority_exclusions)
		and _authority_is_excluded(definition_audit.authority_exclusions)
		and _authority_is_excluded(completed.authority_exclusions),
		"content, resource, and runtime host publish zero reward/ship/berth/save/network authority"
	)

	var reset_after_completion := content.reset(generation)
	var restarted := content.start(int(reset_after_completion.activity.generation))
	var failure_generation := int(restarted.activity.generation)
	var failed := content.fail(&"station_asset_disabled", failure_generation)
	_check(
		reset_after_completion.accepted and restarted.accepted and failed.accepted
		and failed.activity.state_id == "failed"
		and failed.activity.failure_reason == &"station_asset_disabled"
		and int(failed.retired_entity_count) == 1 and not alpha.is_active(),
		"explicit production failure retires the active scene roster through the existing host"
	)
	var reset_after_failure := content.reset(failure_generation)
	var final_start := content.start(int(reset_after_failure.activity.generation))
	await physics_frame
	_check(
		reset_after_failure.accepted and final_start.accepted and alpha.is_active()
		and is_equal_approx(alpha.get_health(), alpha.maximum_health)
		and alpha.global_transform.is_equal_approx(alpha_marker.global_transform),
		"reset reuses and reactivates the same pre-created opponent at its deterministic marker"
	)
	content.abort(int(final_start.activity.generation))

	var content_source := FileAccess.get_file_as_string(CONTENT_SCRIPT_PATH)
	_check(
		not content_source.contains("func _process(")
		and not content_source.contains("func _physics_process(")
		and not content_source.contains("Time.")
		and not content_source.contains(".instantiate(")
		and not content_source.contains("apply_damage("),
		"content source contains no hidden clock, runtime spawning, or parallel damage path"
	)

	root.remove_child(content)
	content.queue_free()
	root.remove_child(attacker)
	attacker.queue_free()
	for _frame in 8:
		await process_frame


func _shoot(
	authority: LiveCombatAuthority,
	attacker: Node3D,
	target: RangeOpponent
	) -> Dictionary:
	attacker.global_position = target.global_position + Vector3(0.0, 0.0, 18.0)
	await physics_frame
	var result := authority.submit_hitscan(
		attacker,
		TEST_WEAPON,
		attacker.global_position,
		(target.global_position - attacker.global_position).normalized()
	)
	await process_frame
	return result


func _distinct_ship_colliders_in_volume(
	content: StationDefenseEncounterContent,
	marker_name: String
	) -> Dictionary:
	var collision := content.get_node(
		NodePath("SpawnStaging/%s/KeepClearVolume/CollisionShape3D" % marker_name)
	) as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = PhysicsLayers.SHIP
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var distinct: Dictionary = {}
	for hit in content.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider := (hit as Dictionary).get("collider") as CollisionObject3D
		if is_instance_valid(collider):
			distinct[collider.get_instance_id()] = String(collider.name)
	return distinct


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
	for value in staging:
		var row := value as Dictionary
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


func _authority_is_excluded(authority: Dictionary) -> bool:
	return not bool(authority.get("rewards", true)) \
		and not bool(authority.get("ships", true)) \
		and not bool(authority.get("berths", true)) \
		and not bool(authority.get("save", true)) \
		and not bool(authority.get("network", true)) \
		and not bool(authority.get("health", true)) \
		and not bool(authority.get("damage", true)) \
		and not bool(authority.get("combat_resolution", true))


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("STATION_DEFENSE_ENCOUNTER_CONTENT_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("STATION_DEFENSE_ENCOUNTER_CONTENT_TEST_OK")
		quit(0)
	else:
		print("STATION_DEFENSE_ENCOUNTER_CONTENT_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
