extends SceneTree

## Focused production-seam integration for StationDefenseEncounterHost.
## Real RangeOpponent instances take damage only through LiveCombatAuthority's
## real CombatResolver and existing LifecycleDamageableAdapter.

const HostScript := preload("res://scripts/activities/station_defense_encounter_host.gd")
const ContractScript := preload("res://scripts/activities/station_defense_contract.gd")
const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")

const TEST_WEAPON: StringName = &"station_defense_test_cannon"
const TEST_SOURCE_ID := 9101
const HOSTILE_FACTION: StringName = &"station_defense_hostiles"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	await _test_real_resolver_waves_and_lifecycle()
	_check(
		root.get_child_count() == original_root_child_count,
		"encounter-host fixture cleans up every staged production node"
	)
	_finish()


func _test_real_resolver_waves_and_lifecycle() -> void:
	var contract := _contract()
	var host := HostScript.new() as StationDefenseEncounterHost
	host.name = "StationDefenseEncounterHost"
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var attacker := Node3D.new()
	attacker.name = "RegisteredDefenseSource"
	host.add_child(attacker)

	var alpha := _opponent("RaiderAlpha")
	var beta := _opponent("RaiderBeta")
	var gamma := _opponent("RaiderGamma")
	host.add_child(alpha)
	host.add_child(beta)
	host.add_child(gamma)

	var configured := host.configure(contract, authority)
	_check(
		configured.accepted
		and host.get_combat_authority() == authority
		and host.get_snapshot().destruction_source == &"combat_resolver_terminal_result",
		"host composes the supplied activity contract and live combat authority"
	)

	# Register in deliberately scrambled call order. The public roster must still
	# be contract wave/order, never dictionary or registration order.
	var gamma_registration := host.register_hostile(
		_hostile(&"raider_gamma", 3),
		gamma,
		Transform3D(Basis.IDENTITY, Vector3(20.0, 0.0, -40.0)),
		HOSTILE_FACTION
	)
	var alpha_registration := host.register_hostile(
		_hostile(&"raider_alpha", 1),
		alpha,
		Transform3D(Basis.IDENTITY, Vector3(-20.0, 0.0, -30.0)),
		HOSTILE_FACTION
	)
	_check(
		gamma_registration.accepted and alpha_registration.accepted,
		"pre-staged production opponents register by exact generation-bearing handle"
	)
	_check(
		host.start(0).reason == &"host_not_in_tree",
		"a configured host cannot activate combat outside a physics tree"
	)
	root.add_child(host)
	await process_frame
	await physics_frame

	_check(
		host.start(0).reason == &"incomplete_spawn_roster",
		"activity start fails closed until the exact bounded contract roster is staged"
	)
	var beta_registration := host.register_hostile(
		_hostile(&"raider_beta", 2),
		beta,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -35.0)),
		HOSTILE_FACTION
	)
	_check(beta_registration.accepted, "the final exact contract hostile closes the spawn roster")
	_check(
		host.register_hostile(
			_hostile(&"raider_alpha", 1), alpha, Transform3D.IDENTITY, HOSTILE_FACTION
		).reason == &"duplicate_hostile_registration"
		and host.register_hostile(
			_hostile(&"unknown_raider", 1), beta, Transform3D.IDENTITY, HOSTILE_FACTION
		).reason == &"unknown_hostile"
		and host.register_hostile(
			_hostile(&"raider_beta", 2), gamma, Transform3D.IDENTITY, HOSTILE_FACTION
		).reason == &"duplicate_hostile_registration",
		"unknown and duplicate stable registrations fail without changing the roster"
	)

	var roster := host.get_snapshot().spawn_roster as Array
	_check(
		roster.size() == 3
		and roster[0].hostile_id == &"raider_alpha"
		and roster[1].hostile_id == &"raider_beta"
		and roster[2].hostile_id == &"raider_gamma"
		and int(roster[0].wave_index) == 0 and int(roster[0].wave_order) == 0
		and int(roster[1].wave_index) == 0 and int(roster[1].wave_order) == 1
		and int(roster[2].wave_index) == 1 and int(roster[2].wave_order) == 0,
		"HUD roster order is deterministic contract order despite scrambled registration"
	)
	_check(
		alpha.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter
		and beta.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter
		and gamma.get_node_or_null("AuthoritativeDamageable") is LifecycleDamageableAdapter,
		"each hostile reuses the production lifecycle adapter instead of gaining health or damage state"
	)

	var weapon_profiles := {
		TEST_WEAPON: {"range": 120.0, "damage": 50.0, "origin_tolerance": 8.0},
	}
	_check(
		authority.register_source(attacker, TEST_SOURCE_ID, &"station_allies", weapon_profiles),
		"test attacker registers on the one production resolver"
	)
	var resolver := authority.get_resolver()
	_check(
		resolver != null and resolver.get_registered_source_count() == 1,
		"host creates no parallel resolver or combat-source registry"
	)

	var reentry_probe := {"armed": true, "result": {}}
	host.snapshot_changed.connect(func(_snapshot: Dictionary) -> void:
		if not bool(reentry_probe.armed):
			return
		reentry_probe.armed = false
		reentry_probe.result = host.advance_physics(0.25, host.get_generation())
	)
	var started := host.start(0)
	var generation := int(started.activity.generation)
	_check(
		started.accepted and generation == 1
		and alpha.is_active() and not beta.is_active() and not gamma.is_active()
		and int(started.active_entity_count) == 1,
		"wave one activates only its first ordered production opponent"
	)
	_check(
		(reentry_probe.result as Dictionary).reason == &"reentrant_call"
		and is_zero_approx(float(host.get_snapshot().activity.elapsed_seconds)),
		"synchronous snapshot observers cannot re-enter host mutation or advance time"
	)

	var alpha_first := await _shoot(authority, attacker, alpha)
	_check(
		alpha_first.damaged and not alpha_first.destroyed
		and is_equal_approx(alpha.get_health(), 35.0)
		and int(host.get_snapshot().activity.remaining_hostile_count) == 3,
		"nonterminal resolver damage changes only the opponent's existing health"
	)
	var alpha_terminal := await _shoot(authority, attacker, alpha)
	_check(
		alpha_terminal.destroyed and not alpha.is_active()
		and beta.is_active() and not gamma.is_active()
		and int(host.get_snapshot().activity.remaining_hostile_count) == 2
		and host.get_snapshot().last_observation_result.hostile_id == &"raider_alpha",
		"terminal resolver authority advances the exact handle and activates the next ordered hostile"
	)

	# Preserve a live partial hull through whole-host streaming. No host clock is
	# advanced while detached and no opponent is reconstructed or healed.
	var beta_first := await _shoot(authority, attacker, beta)
	var beta_health_before_detach := beta.get_health()
	var detached_elapsed := float(host.get_snapshot().activity.elapsed_seconds)
	_check(beta_first.damaged and not beta_first.destroyed, "second ordered hostile takes real nonterminal resolver damage")
	root.remove_child(host)
	await process_frame
	_check(
		not bool(host.get_snapshot().activity.attached)
		and is_equal_approx(beta.get_health(), beta_health_before_detach)
		and is_equal_approx(float(host.get_snapshot().activity.elapsed_seconds), detached_elapsed),
		"whole-host detach preserves objective time and the opponent's authoritative partial hull"
	)
	root.add_child(host)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		bool(host.get_snapshot().activity.attached)
		and beta.is_active()
		and is_equal_approx(beta.get_health(), beta_health_before_detach)
		and bool(host.get_snapshot().resolver_connected),
		"same-instance re-entry restores observation without rebuilding or healing the active hostile"
	)
	_check(
		authority.register_source(attacker, TEST_SOURCE_ID, &"station_allies", weapon_profiles),
		"external combat source re-registers on the same retained resolver after streaming"
	)
	var beta_terminal := await _shoot(authority, attacker, beta)
	_check(
		beta_terminal.destroyed and not beta.is_active()
		and not gamma.is_active()
		and is_equal_approx(float(host.get_snapshot().activity.wave_delay_remaining_seconds), 0.5),
		"finishing wave one enters the exact caller-timed second-wave delay"
	)

	var before_frames := host.get_snapshot()
	await process_frame
	await physics_frame
	_check(host.get_snapshot() == before_frames, "engine frames cannot progress the host's wave or timeout clocks")
	_check(
		host.advance_physics(NAN, generation).reason == &"invalid_delta"
		and host.advance_physics(0.25, generation).accepted
		and is_equal_approx(float(host.get_snapshot().activity.wave_delay_remaining_seconds), 0.25)
		and not gamma.is_active(),
		"malformed delta is rejected and only accepted caller physics advances delay"
	)
	var wave_two := host.advance_physics(0.25, generation)
	_check(
		wave_two.accepted and gamma.is_active()
		and int(wave_two.activity.current_wave_index) == 1
		and int(wave_two.active_entity_count) == 1,
		"the exact remaining caller delta activates wave two"
	)
	await _shoot(authority, attacker, gamma)
	var completed_shot := await _shoot(authority, attacker, gamma)
	var completed := host.get_snapshot()
	_check(
		completed_shot.destroyed
		and completed.activity.state_id == "completed"
		and int(completed.activity.remaining_hostile_count) == 0
		and int(completed.destroyed_entity_count) == 3
		and int(completed.active_entity_count) == 0,
		"final resolver-confirmed destruction completes exactly the existing activity contract"
	)
	var completed_observation: Dictionary = completed.last_observation_result.duplicate(true)
	alpha.destroyed.emit(alpha.global_position)
	_check(
		host.get_snapshot().last_observation_result == completed_observation
		and host.get_snapshot().activity.state_id == "completed",
		"an opponent lifecycle signal outside the resolver seam cannot replay completion"
	)

	var detached_snapshot := host.get_snapshot()
	(detached_snapshot.spawn_roster as Array).clear()
	(detached_snapshot.activity as Dictionary)["generation"] = 999
	(detached_snapshot.authority_exclusions as Dictionary)["damage"] = true
	_check(
		(host.get_snapshot().spawn_roster as Array).size() == 3
		and int(host.get_snapshot().activity.generation) == generation
		and not bool(host.get_snapshot().authority_exclusions.damage),
		"HUD-ready host snapshots are deeply detached primitive data"
	)
	var audit_first := host.audit()
	var audit_second := host.audit()
	_check(
		audit_first == audit_second and audit_first.valid
		and int(audit_first.limits.maximum_spawn_roster) == ContractScript.MAX_TOTAL_HOSTILES
		and not bool(audit_first.authority_exclusions.combat_resolution)
		and not bool(audit_first.authority_exclusions.health)
		and not bool(audit_first.authority_exclusions.damage)
		and not bool(audit_first.authority_exclusions.rewards)
		and not bool(audit_first.authority_exclusions.scene_instantiation)
		and not bool(audit_first.authority_exclusions.protected_asset_lifecycle)
		and not bool(audit_first.authority_exclusions.ships)
		and not bool(audit_first.authority_exclusions.berths)
		and not bool(audit_first.authority_exclusions.world_geometry)
		and not bool(audit_first.authority_exclusions.hud)
		and not bool(audit_first.authority_exclusions.game_flow)
		and not bool(audit_first.authority_exclusions.main)
		and not bool(audit_first.authority_exclusions.save)
		and not bool(audit_first.authority_exclusions.network),
		"audit is deterministic, bounded, and freezes every excluded authority"
	)

	var reset := host.reset(generation)
	var host_idle_generation := int(reset.activity.generation)
	var host_before_bad_renewal := host.get_snapshot()
	var renewed_asset := host.renew_protected_asset_handle(
		_asset(&"station_core", 5), _asset(&"station_core", 6), host_idle_generation
	)
	_check(
		reset.accepted and renewed_asset.accepted
		and renewed_asset.reason == &"protected_asset_renewed"
		and int(renewed_asset.activity.protected_assets[0].handle.generation) == 6
		and int(renewed_asset.activity.generation) == host_idle_generation
		and host.renew_protected_asset_handle(
			_asset(&"station_core", 5), _asset(&"station_core", 6), host_idle_generation
		).reason == &"stale_protected_asset_generation",
		"host proxies only the exact idle old-to-next protected handle without changing activity generation"
	)
	_check(
		host.renew_protected_asset_handle(
			_asset(&"station_core", 6), _asset(&"station_core", 8), host_idle_generation
		).reason == &"invalid_protected_asset_renewal"
		and int(host_before_bad_renewal.activity.protected_assets[0].handle.generation) == 5
		and int(host.get_snapshot().activity.protected_assets[0].handle.generation) == 6,
		"malformed host renewal is rejected while the prior detached snapshot stays immutable"
	)
	var restarted := host.start(int(reset.activity.generation))
	var failure_generation := int(restarted.activity.generation)
	var health_before_asset_event := alpha.get_health()
	var damage_event := host.protected_asset_damaged(
		_asset(&"station_core", 6), _event(&"asset_hit_001", 1), failure_generation
	)
	var asset_failure := host.protected_asset_destroyed(
		_asset(&"station_core", 6), _event(&"asset_destroyed_001", 1), failure_generation
	)
	_check(
		reset.accepted and restarted.accepted and alpha.is_active() == false
		and damage_event.accepted and asset_failure.accepted
		and asset_failure.activity.state_id == "failed"
		and asset_failure.activity.failure_reason == &"protected_asset_destroyed"
		and is_equal_approx(alpha.get_health(), health_before_asset_event)
		and int(asset_failure.retired_entity_count) == 1,
		"protected-asset observations fail and retire the encounter without applying object or hostile damage"
	)

	var reset_after_failure := host.reset(failure_generation)
	var timeout_start := host.start(int(reset_after_failure.activity.generation))
	var timeout_generation := int(timeout_start.activity.generation)
	var timed_out := host.advance_physics(5.0, timeout_generation)
	_check(
		timed_out.accepted and timed_out.reason == &"timed_out"
		and timed_out.activity.state_id == "timed_out"
		and int(timed_out.retired_entity_count) == 1
		and not alpha.is_active(),
		"caller-physics timeout fails and retires the active production opponent"
	)
	var reset_after_timeout := host.reset(timeout_generation)
	var abort_start := host.start(int(reset_after_timeout.activity.generation))
	var aborted := host.abort(int(abort_start.activity.generation))
	_check(
		aborted.accepted and aborted.activity.state_id == "aborted"
		and int(aborted.retired_entity_count) == 1 and not alpha.is_active(),
		"abort uses the existing activity terminal and leaves no active hostile"
	)

	var host_source := FileAccess.get_file_as_string(
		"res://scripts/activities/station_defense_encounter_host.gd"
	)
	_check(
		not host_source.contains("func _process(")
		and not host_source.contains("func _physics_process(")
		and not host_source.contains("Time.")
		and not host_source.contains("maximum_health =")
		and not host_source.contains("apply_damage("),
		"host contains no hidden clock, health store, damage application, or frame progression"
	)

	root.remove_child(host)
	host.queue_free()
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


func _opponent(node_name: String) -> RangeOpponent:
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	opponent.name = node_name
	opponent.cruise_speed = 10.0
	opponent.chase_speed = 10.0
	opponent.acceleration = 1.0
	return opponent


func _contract() -> StationDefenseContract:
	return ContractScript.new(
		&"production_station_defense",
		[
			_wave(
				&"ordered_intercept",
				ContractScript.WaveMode.ORDERED,
				0.0,
				[_hostile(&"raider_alpha", 1), _hostile(&"raider_beta", 2)]
			),
			_wave(
				&"relief_push",
				ContractScript.WaveMode.SIMULTANEOUS,
				0.5,
				[_hostile(&"raider_gamma", 3)]
			),
		],
		[_asset(&"station_core", 5)],
		5.0
	) as StationDefenseContract


func _wave(
	wave_id: StringName,
	mode: int,
	delay_seconds: float,
	hostile_handles: Array[Dictionary]
	) -> Dictionary:
	return {
		"wave_id": wave_id,
		"mode": mode,
		"delay_seconds": delay_seconds,
		"hostile_handles": hostile_handles,
	}


func _hostile(hostile_id: StringName, generation: int) -> Dictionary:
	return {"hostile_id": hostile_id, "generation": generation}


func _asset(asset_id: StringName, generation: int) -> Dictionary:
	return {"asset_id": asset_id, "generation": generation}


func _event(event_id: StringName, generation: int) -> Dictionary:
	return {"event_id": event_id, "generation": generation}


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("STATION_DEFENSE_ENCOUNTER_HOST_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("STATION_DEFENSE_ENCOUNTER_HOST_TEST_OK")
		quit(0)
	else:
		print("STATION_DEFENSE_ENCOUNTER_HOST_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
