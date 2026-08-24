extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 4
	var attachment_generation := 1
	var phase_id: StringName = &"on_foot"

	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": phase_id, "identities": {"world_id": &"ember_moon", "player_instance_id": 101}}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 4)
	_check(configured.accepted and configured.runtime.composition_generation == 1 and configured.runtime.navigation.state == &"idle" and configured.runtime.hazard.configured and configured.runtime.water.state == &"idle" and configured.runtime.landmarks.configured and configured.runtime.settlement.configured, "one generation-fenced Ember composition retains all planetary runtimes")
	var hazard_anchor := Vector3(92.0, 120001.0, -5.0)
	var staging_relay := Vector3(96.0, 120000.0, 0.0)
	var base_observation := {
		"actor_instance_id": 101,
		"delta_seconds": 1.0,
		"exposure_unitless": 1.0,
		"position_body_local_m": hazard_anchor,
		"surface_phase_id": &"on_foot",
	}.duplicate(true)
	var hazard_composed := binding.get_snapshot()
	_check(
		hazard_composed.hazard.hazard_ids.has(&"ember_relay_arc")
			and hazard_composed.hazard.hazard_ids.has(&"caldera_thermal_vent")
			and hazard_composed.hazard_content.identity.world_id == &"ember_moon"
			and hazard_composed.hazard_zone_presentation.visible
			and hazard_composed.hazard_zone_presentation.anchor_body_local_m == hazard_anchor,
		"the production binding composes the authored Relay Arc into one visible runtime zone"
	)
	_check(
		not binding.submit_authored_hazard_observation(base_observation, 3, 1).accepted
			and binding.get_authored_hazard_status().state == &"clear",
		"stale lifecycle evidence cannot enter the authored hazard"
	)
	var foreign := base_observation.duplicate(true)
	foreign.actor_instance_id = 102
	_check(
		binding.submit_authored_hazard_observation(foreign, 4, 1).reason
			== &"hazard_actor_identity_mismatch",
		"foreign actor evidence is rejected"
	)
	var wrong_phase := base_observation.duplicate(true)
	wrong_phase.surface_phase_id = &"reboarded"
	_check(
		binding.submit_authored_hazard_observation(wrong_phase, 4, 1).reason
			== &"hazard_lifecycle_mismatch",
		"non-surface lifecycle evidence is rejected"
	)
	var warned := binding.submit_authored_hazard_observation(base_observation, 4, 1)
	_check(
		warned.accepted and warned.reason == &"hazard_zone_exposed"
			and warned.status.visible and warned.status.state == &"warning"
			and warned.sample.damage_request.requested
			and not warned.sample.damage_request.health_mutation
			and not warned.status.authority.damage
			and not warned.status.authority.movement
			and not warned.status.authority.reward
			and not warned.presentation.authority.lifecycle
			and warned.presentation.state == &"warning"
			and not warned.presentation.recovery_cue.visible,
		"caller position enters the visible Relay Arc and emits detached warning requests"
	)
	var recovery_observation := base_observation.duplicate(true)
	recovery_observation.delta_seconds = 7.0
	var recovery := binding.submit_authored_hazard_observation(
		recovery_observation, 4, 1
	)
	_check(
		recovery.accepted and recovery.reason == &"hazard_recovery_requested"
			and recovery.status.state == &"recovery_required"
			and recovery.status.recovery_id == &"safe_recovery_at_staging_relay"
			and recovery.sample.recovery_request.requested
			and not recovery.sample.recovery_request.movement_mutation
			and recovery.presentation.recovery_cue.visible
			and recovery.presentation.recovery_cue.target_landmark_id == &"ember_staging_relay"
			and recovery.presentation.recovery_cue.target_body_local_m == staging_relay
			and recovery.presentation.recovery_cue.direction_unit.is_equal_approx(
				(staging_relay - recovery.presentation.recovery_cue.path_start_body_local_m).normalized()
			)
			and is_equal_approx(
				(recovery.presentation.recovery_cue.path_start_body_local_m - hazard_anchor).length(),
				12.0
			)
			and recovery.presentation.recovery_cue.color_independent_shape == &"progressive_width_dashes"
			and recovery.presentation.recovery_cue.dash_count == 4
			and recovery.presentation.recovery_cue.static
			and not recovery.presentation.recovery_cue.authority.navigation
			and not recovery.presentation.recovery_cue.authority.movement
			and not recovery.presentation.recovery_cue.authority.recovery
			and _reward_calls == 0,
		"sustained exposure reveals a static authored-relay path cue without applying recovery"
	)
	var cooled_observation := base_observation.duplicate(true)
	cooled_observation.exposure_unitless = 0.0
	var recovering := binding.submit_authored_hazard_observation(
		cooled_observation, 4, 1
	)
	_check(
		recovering.accepted and recovering.reason == &"hazard_recovery_requested"
			and recovering.status.state == &"recovery_required"
			and recovering.sample.recovery_request.generation == 1
			and not recovering.sample.recovery_request.newly_requested
			and recovering.presentation.recovery_cue.visible,
		"cooling cannot strand a failed actor by retracting the retained relay recovery cue"
	)
	var detached_status := binding.get_authored_hazard_status()
	detached_status.state = &"tampered"
	_check(
		binding.get_authored_hazard_status().state == &"recovery_required",
		"semantic hazard status is detached from the retained composition"
	)
	var exited := base_observation.duplicate(true)
	exited.position_body_local_m = hazard_anchor + Vector3(20.0, 0.0, 0.0)
	var clear := binding.submit_authored_hazard_observation(exited, 4, 1)
	_check(
		clear.accepted and clear.reason == &"hazard_zone_clear"
			and not clear.status.visible and clear.status.state == &"clear"
			and is_zero_approx(float(binding.get_snapshot().hazard.exposure[&"ember_relay_arc"]))
			and clear.presentation.visible
			and not clear.presentation.recovery_cue.visible,
		"exiting clears accumulated exposure and HUD status while retaining the visible perimeter"
	)
	var discovered := binding.discover_settlements(Vector3(92.0, 120000.5, -18.0), 20.0)
	var entered := binding.enter_settlement(&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0))
	_check(discovered.accepted and entered.accepted and entered.receipt.route_id == &"ember_pad_to_settlement_spine", "production composition forwards authored discovery and entry")
	_check(binding.detach().accepted and binding.get_snapshot().state == &"detached" and binding.get_snapshot().settlement.state == &"detached" and not binding.get_snapshot().hazard_zone_presentation.visible and not binding.get_snapshot().hazard_zone_presentation.recovery_cue.visible and binding.get_authored_hazard_status().state == &"clear", "detaching clears the hazard presentation/status and recovery cue with the surface composition")
	host.attachment_generation = 2
	_check(binding.reenter().accepted and binding.get_snapshot().state == &"bound" and binding.get_snapshot().settlement.state == &"inside" and binding.get_snapshot().hazard_zone_presentation.visible and not binding.get_snapshot().hazard_zone_presentation.recovery_cue.visible and binding.get_authored_hazard_status().state == &"clear" and binding.enter_settlement(&"ember_habitat_spine", Vector3(92.0, 120000.5, -18.0)).reason == &"settlement_entry_already_consumed", "re-entry restores the clear hazard perimeter without replaying the recovery cue")
	var reentered := binding.submit_authored_hazard_observation(base_observation, 4, 2)
	_check(
		reentered.accepted and reentered.status.state == &"warning"
			and float(reentered.status.exposure_unitless) < 0.8
			and not reentered.presentation.recovery_cue.visible,
		"fresh re-entry starts recoverably without replaying prior severe exposure"
	)
	binding.queue_free()
	director.queue_free()
	await process_frame
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("EMBER_PLANETARY_SURFACE_PRODUCTION_BINDING_TEST_OK: %d assertions" % _assertions)
	quit(0)

func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
