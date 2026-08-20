extends SceneTree

## Focused detached regression for the server damage -> component receipt ->
## crash recovery -> landing-authority respawn handoff. It intentionally does
## not instantiate ships, physics, scene nodes, RPC peers, or a full matrix.

const ComponentDamageModel := preload("res://scripts/combat/component_damage_model.gd")
const ProjectileAuthority := preload("res://scripts/network/network_projectile_authority.gd")
const ProjectileIntent := preload("res://scripts/network/network_projectile_intent.gd")
const LandingAuthority := preload("res://scripts/network/network_landing_authority.gd")
const LandingIntent := preload("res://scripts/network/network_landing_intent.gd")
const Integration := preload("res://scripts/network/network_damage_respawn_integration.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_server_damage_and_recovery_handoff()
	_test_generation_and_replay_guards()
	if _failures.is_empty():
		print("OK: network damage/respawn integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_server_damage_and_recovery_handoff() -> void:
	var integration := Integration.new(99)
	_check(
		integration.register_entity(99, 7, &"fighter_a", 4, 1, 1.0, 0.25).accepted,
		"server registers one generation-scoped damage lifecycle"
	)
	var component := ComponentDamageModel.new([{
		"component_id": &"hull",
		"maximum_health": 100.0,
		"damage_stages": _stages(),
	}])
	var reset := component.reset_for_reuse(0)
	_check(reset.accepted and reset.generation == 1, "component model starts its authoritative generation")
	var projectile := ProjectileAuthority.new(99)
	_check(
		projectile.register_source(99, 7, &"fighter_a", 4, &"player", {
			&"pulse": {"speed": 100.0, "damage": 100.0, "lifetime": 1.0},
		}).accepted,
		"server projectile owner supplies the weapon profile"
	)
	_check(projectile.set_server_tick(99, 10).accepted, "server owns the projectile tick")
	var fire: ProjectileIntent = ProjectileIntent.create(
		7, &"fighter_a", 4, 1, 0, 10, &"pulse",
		Vector3.ZERO, Vector3.FORWARD
	)
	var spawned := projectile.accept_fire(7, fire.to_dictionary())
	_check(spawned.accepted, "owner intent becomes one server projectile")
	var projectile_id: StringName = spawned.projectile.projectile_id
	var impact := projectile.resolve_impact(
		99, projectile_id, &"fighter_a", 4,
		Vector3(1.0, 0.0, 0.0), Vector3.FORWARD
	)
	# The real projectile authority blocks self-hit, so the integration test uses
	# a second authoritative target identity while the registered lifecycle is
	# the damage recipient. This keeps the source/target boundary explicit.
	_check(not impact.accepted and impact.status == &"self_hit_blocked", "projectile authority blocks self-hit before integration")
	var target_component := ComponentDamageModel.new([{
		"component_id": &"hull",
		"maximum_health": 100.0,
		"damage_stages": _stages(),
	}])
	_check(target_component.reset_for_reuse(0).accepted, "target component model is reset by its owner")
	var target_receipt := target_component.apply_component_damage({
		"component_id": &"hull",
		"damage": 100.0,
		"generation": 1,
		"sequence": 0,
	})
	var damage_event := {
		"event_sequence": 1,
		"projectile_id": &"projectile_1",
		"target_entity_id": &"fighter_a",
		"target_generation": 4,
		"damage": 100.0,
	}
	_check(
		integration.record_damage(99, &"fighter_a", 4, damage_event, target_receipt, true).accepted,
		"server joins projectile damage event to the component receipt"
	)
	_check(
		integration.get_entity_snapshot(&"fighter_a").state == Integration.STATE_RECOVERING,
		"destroyed damage enters the bounded crash-recovery state"
	)
	var recovering := integration.tick_recovery(99, &"fighter_a", 4, 0.5)
	_check(recovering.accepted and recovering.status == &"recovery_advanced", "server advances recovery from physics")
	var ready := integration.tick_recovery(99, &"fighter_a", 4, 0.5)
	_check(ready.accepted and ready.status == &"recovery_ready", "recovery gate opens after its configured window")
	var landing := LandingAuthority.new(99)
	_check(landing.register_entity(99, 7, &"fighter_a", 4).accepted, "landing authority tracks the same destroyed generation")
	_check(landing.register_respawn_target(99, &"spawn_alpha", &"mudds_shipyards").accepted, "server registers an opaque respawn target")
	_check(landing.mark_destroyed(99, &"fighter_a", 4).accepted, "landing authority receives server destruction")
	_check(landing.set_server_tick(99, 10).accepted, "landing authority shares the server tick boundary")
	var intent: LandingIntent = LandingIntent.create(7, &"fighter_a", 4, 1, 0, 10, LandingIntent.ACTION_RESPAWN, &"mudds_shipyards", &"spawn_alpha")
	var reservation := landing.accept_intent(7, intent.to_dictionary())
	_check(reservation.accepted and reservation.status == &"respawn_reserved", "landing authority reserves one opaque respawn lease")
	_check(integration.reserve_respawn(99, &"fighter_a", 4, reservation).accepted, "integration accepts the server reservation only after recovery")
	var commit := landing.commit_respawn(99, &"fighter_a", 4, reservation.respawn_token)
	_check(commit.accepted and commit.status == &"respawn_committed", "landing authority advances its lifecycle generation")
	var component_reset := target_component.reset_for_reuse(1)
	_check(
		integration.commit_respawn(99, &"fighter_a", 4, commit, component_reset).accepted,
		"integration atomically joins landing and component generation commits"
	)
	var snapshot := integration.get_entity_snapshot(&"fighter_a")
	_check(snapshot.state == Integration.STATE_ACTIVE and snapshot.entity_generation == 5 and snapshot.component_generation == 2, "respawn returns the next active entity and component generations")


func _test_generation_and_replay_guards() -> void:
	var integration := Integration.new(99)
	_check(integration.register_entity(99, 7, &"fighter_a", 4, 1).accepted, "guard fixture registers the lifecycle")
	var receipt := {
		"accepted": true,
		"reason": &"applied",
		"generation": 1,
		"sequence": 0,
		"component_id": &"hull",
		"applied_damage": 2.0,
	}
	var event := {
		"event_sequence": 2,
		"projectile_id": &"projectile_2",
		"target_entity_id": &"fighter_a",
		"target_generation": 4,
		"damage": 2.0,
	}
	var spoof := integration.record_damage(8, &"fighter_a", 4, event, receipt, false)
	_check(not spoof.accepted and spoof.status == &"unauthorized_source", "clients cannot append damage to the server ledger")
	_check(integration.record_damage(99, &"fighter_a", 4, event, receipt, false).accepted, "server accepts the first component damage receipt")
	var replay := integration.record_damage(99, &"fighter_a", 4, event, receipt, false)
	_check(not replay.accepted and replay.status == &"stale_damage_event", "projectile event replay is rejected")
	var stale := integration.record_damage(99, &"fighter_a", 3, {
		"event_sequence": 3,
		"projectile_id": &"projectile_3",
		"target_entity_id": &"fighter_a",
		"target_generation": 3,
		"damage": 2.0,
	}, {"accepted": true, "reason": &"applied", "generation": 1, "sequence": 1, "component_id": &"hull", "applied_damage": 2.0}, false)
	_check(not stale.accepted and stale.status == &"stale_entity_generation", "late damage cannot target an older lifecycle generation")
	var audit := integration.audit()
	_check(
		bool(audit.server_owns_damage_event_order)
		and bool(audit.server_owns_component_generation)
		and bool(audit.server_owns_recovery_gate)
		and bool(audit.server_owns_respawn_generation)
		and not bool(audit.owns_health_store)
		and not bool(audit.client_can_mutate_respawn),
		"audit exposes server ownership without duplicating health or spawn authority"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)


func _stages() -> Array:
	return [
		{
			"stage_id": &"nominal",
			"health_ratio_at_or_below": 1.0,
			"disabled": false,
			"performance_multiplier": 1.0,
		},
		{
			"stage_id": &"failed",
			"health_ratio_at_or_below": 0.0,
			"disabled": true,
			"performance_multiplier": 0.0,
		},
	]
