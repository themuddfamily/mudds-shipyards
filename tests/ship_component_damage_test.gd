extends SceneTree

## Focused contract for the observational component damage/repair model and the
## localized presentation channel it drives.
##
## `modern_interpretation`: nothing in the roster, the integrity curve, the
## repair rate, or the localized rig grammar is authenticated by any source.
##
## The model is deliberately an observer. Every assertion below is written so it
## would fail if the model ever started owning hull, spending more integrity than
## a hit is worth, repairing without authorization, or leaving a rig behind on a
## recycled craft.
##
## Deterministic by construction: fixed AABBs, fixed damage amounts, fixed
## simulation deltas. No wall clock and no RNG are read anywhere in this suite,
## and every wait is a bounded step budget over an explicit condition.

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const HeroDamagePresentationType := preload("res://scripts/effects/hero_damage_presentation.gd")

## A plausible small-craft envelope: 8 m span, 3 m tall, 12 m long, centred a
## little above the root like the real collision variants.
const SHIP_BOUNDS := AABB(Vector3(-4.0, 0.0, -6.0), Vector3(8.0, 3.0, 12.0))
const MAXIMUM_HULL := 100.0
const SIMULATION_STEP := 1.0 / 60.0
## Two seconds of parked time at 60 Hz. The repair contract must finish well
## inside this, so recovery is never something a player waits on.
const REPAIR_STEP_BUDGET := 120

var _failures: Array[String] = []
var _state_events: Array[Dictionary] = []
var _restore_events := 0
var _owner_guard_model: ShipComponentDamage
var _owner_guard_foreign_capability: RefCounted
var _owner_guard_events := PackedStringArray()
var _owner_guard_attacks: Array[Dictionary] = []
var _failure_started: Array[Dictionary] = []
var _failure_cleared: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration()
	_test_invalid_configuration()
	_test_unconfigured_model_fails_closed()
	_test_duplicate_configuration()
	_test_owner_mutation_transaction()
	_test_attribution()
	_test_operational_modifiers_and_repair()
	_test_state_boundaries()
	_test_invalid_damage()
	_test_unlocated_damage()
	_test_repair_authorization()
	_test_repair_recovery_budget()
	_test_restore_and_determinism()
	_test_presentation_channel()
	_test_presentation_cleanup_and_reentry()
	await _test_queued_destruction_resume_is_inert()
	_finish()


# ---------------------------------------------------------------- layout --


func _test_configuration() -> void:
	var model := _make_model()
	_check(model.is_configured(), "a valid envelope configures the model")
	_check(
		model.get_component_count() == ShipComponentDamageType.COMPONENT_ORDER.size(),
		"the roster has exactly one entry per declared component id"
	)
	var states := model.get_component_states()
	var all_nominal := true
	for entry in states:
		if (
			int(entry.state) != ShipComponentDamageType.ComponentState.NOMINAL
			or not is_equal_approx(float(entry.integrity), 1.0)
		):
			all_nominal = false
	_check(all_nominal, "a freshly configured craft reports every component nominal at full integrity")
	var ledger := model.get_ledger_snapshot()
	_check(
		bool(ledger.get("active", false))
		and int(ledger.get("generation", 0)) == 1
		and ledger.get("component_order", []) == ShipComponentDamageType.COMPONENT_ORDER
		and (ledger.get("components", []) as Array).size()
			== ShipComponentDamageType.COMPONENT_ORDER.size(),
		"the legacy ship adapter owns one active generic five-section health ledger"
	)

	var layout: Dictionary = {}
	for entry in states:
		layout[StringName(entry.id)] = entry.local_position as Vector3
	var nose: Vector3 = layout[ShipComponentDamageType.COMPONENT_FORWARD_HULL]
	var tail: Vector3 = layout[ShipComponentDamageType.COMPONENT_ENGINE_BAY]
	var port: Vector3 = layout[ShipComponentDamageType.COMPONENT_PORT_WING]
	var starboard: Vector3 = layout[ShipComponentDamageType.COMPONENT_STARBOARD_WING]
	_check(
		nose.z < tail.z,
		"the forward hull sits ahead of the engine bay on the craft's -Z forward axis"
	)
	_check(
		port.x < starboard.x and port.x < 0.0 and starboard.x > 0.0,
		"the wings straddle the craft's centreline with port to -X"
	)
	var report := model.get_component_report()
	_check(
		report.get("interpretation") == ShipComponentDamageType.INTERPRETATION
		and int(report.get("schema_version", 0)) == ShipComponentDamageType.SCHEMA_VERSION,
		"the audit report is tagged modern_interpretation with an explicit schema version"
	)
	var report_components: Array = report.get("components", [])
	report_components.clear()
	_check(
		model.get_component_report().get("components", []).size()
			== ShipComponentDamageType.COMPONENT_ORDER.size(),
		"the audit report hands out copies a caller cannot mutate model state through"
	)
	model.free()


func _test_operational_modifiers_and_repair() -> void:
	var model := _make_model()
	var nominal := model.get_operational_modifiers()
	_check(
		is_equal_approx(float(nominal.mobility_multiplier), 1.0)
		and is_equal_approx(float(nominal.fire_multiplier), 1.0)
		and is_equal_approx(float(nominal.targeting_multiplier), 1.0),
		"the single physical component ledger starts with nominal control modifiers"
	)
	_degrade_to_impaired(model, ShipComponentDamageType.COMPONENT_ENGINE_BAY)
	_degrade_to_impaired(model, ShipComponentDamageType.COMPONENT_PORT_WING)
	_degrade_to_impaired(model, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS)
	var degraded := model.get_operational_modifiers()
	_check(
		is_equal_approx(float(degraded.mobility_multiplier), 0.62)
		and is_equal_approx(float(degraded.fire_multiplier), 0.62)
		and is_equal_approx(float(degraded.targeting_multiplier), 0.62)
		and degraded.component_bindings.engine \
			== ShipComponentDamageType.COMPONENT_ENGINE_BAY
		and (degraded.component_bindings.weapons as Array).has(
			ShipComponentDamageType.COMPONENT_PORT_WING
		),
		"engine bay, weaker weapon wing, and core systems publish the bounded runtime channels"
	)
	for _step in REPAIR_STEP_BUDGET:
		model.tick_repair(SIMULATION_STEP, true)
		if model.get_worst_integrity() >= 1.0:
			break
	var repaired := model.get_operational_modifiers()
	_check(
		is_equal_approx(float(repaired.mobility_multiplier), 1.0)
		and is_equal_approx(float(repaired.fire_multiplier), 1.0)
		and is_equal_approx(float(repaired.targeting_multiplier), 1.0),
		"authorized repair restores all control modifiers through that same ledger"
	)
	model.free()


func _test_invalid_configuration() -> void:
	var model := ShipComponentDamageType.new()
	var rejected := [
		[AABB(Vector3.ZERO, Vector3.ZERO), MAXIMUM_HULL, "a zero-size envelope"],
		[AABB(Vector3.ZERO, Vector3(8.0, 0.0, 12.0)), MAXIMUM_HULL, "a flat envelope"],
		[AABB(Vector3.ZERO, Vector3(-8.0, 3.0, 12.0)), MAXIMUM_HULL, "a negative-span envelope"],
		[AABB(Vector3.ZERO, Vector3(NAN, 3.0, 12.0)), MAXIMUM_HULL, "a non-finite envelope"],
		[SHIP_BOUNDS, 0.0, "a zero maximum hull"],
		[SHIP_BOUNDS, -20.0, "a negative maximum hull"],
		[SHIP_BOUNDS, NAN, "a non-finite maximum hull"],
		[SHIP_BOUNDS, INF, "an infinite maximum hull"],
	]
	var all_rejected := true
	for case in rejected:
		if model.configure(case[0] as AABB, float(case[1])):
			all_rejected = false
			_fail("%s must be rejected by configure()" % case[2])
	_check(all_rejected, "every malformed envelope or hull value is rejected by configure()")
	_check(
		not model.is_configured() and model.get_component_count() == 0,
		"a model that never accepted a configuration holds no roster"
	)

	_check(model.configure(SHIP_BOUNDS, MAXIMUM_HULL), "a valid configuration is then accepted")
	model.record_damage(40.0, Vector3(0.0, 1.0, -5.0))
	var integrity_before := model.get_worst_integrity()
	_check(
		not model.configure(AABB(Vector3.ZERO, Vector3.ZERO), MAXIMUM_HULL),
		"a later malformed configuration is still rejected"
	)
	_check(
		model.is_configured()
		and is_equal_approx(model.get_worst_integrity(), integrity_before)
		and model.get_component_count() == ShipComponentDamageType.COMPONENT_ORDER.size(),
		"a rejected reconfiguration leaves the live roster and its integrity untouched"
	)
	model.free()


func _test_unconfigured_model_fails_closed() -> void:
	var model := ShipComponentDamageType.new()
	var damage_report := model.record_damage(25.0, Vector3.ZERO)
	_check(
		not bool(damage_report.accepted) and damage_report.reason == &"not_configured",
		"an unconfigured model refuses to record damage instead of inventing a roster"
	)
	var repair_report := model.tick_repair(SIMULATION_STEP, true)
	_check(
		not bool(repair_report.accepted) and repair_report.reason == &"not_configured",
		"an unconfigured model refuses to repair"
	)
	_check(
		model.get_component_states().is_empty()
		and model.get_component_integrity(ShipComponentDamageType.COMPONENT_ENGINE_BAY) < 0.0
		and model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) < 0,
		"an unconfigured model reports an empty roster and sentinel lookups"
	)
	model.reset_for_reuse()
	_check(
		not model.is_configured(),
		"restoring an unconfigured model is a no-op rather than a silent configuration"
	)
	model.free()


func _test_duplicate_configuration() -> void:
	var model := _make_model()
	model.record_damage(50.0, Vector3(0.0, 1.0, -5.5))
	var integrity_before := model.get_component_integrity(
		ShipComponentDamageType.COMPONENT_FORWARD_HULL
	)
	var revision_before := model.get_revision()
	_check(
		model.configure(SHIP_BOUNDS, MAXIMUM_HULL),
		"re-configuring a live model with the same envelope is accepted"
	)
	_check(
		model.get_component_count() == ShipComponentDamageType.COMPONENT_ORDER.size(),
		"re-configuration never duplicates the roster"
	)
	_check(
		is_equal_approx(
			model.get_component_integrity(ShipComponentDamageType.COMPONENT_FORWARD_HULL),
			integrity_before
		),
		"re-configuration preserves the integrity the craft has already lost"
	)
	_check(
		model.get_revision() > revision_before,
		"re-configuration advances the revision so an owner republishes presentation once"
	)
	model.free()


func _test_owner_mutation_transaction() -> void:
	var model := _make_model()
	var foreign_model := _make_model()
	var abandoned_model := _make_model()
	var capability := model.claim_owner_mutation_capability()
	var foreign_capability := foreign_model.claim_owner_mutation_capability()
	var abandoned_capability := abandoned_model.claim_owner_mutation_capability()
	var abandoned_weak: WeakRef = weakref(abandoned_capability)
	abandoned_capability = null
	_check(
		capability != null
		and model.is_owner_mutation_capability_current(capability)
		and model.claim_owner_mutation_capability() == null,
		"one opaque owner capability is claimed once after configuration"
	)
	_check(
		foreign_capability != null
		and not model.is_owner_mutation_capability_current(foreign_capability)
		and not model.begin_owner_mutation_transaction(foreign_capability),
		"a capability issued by another component cannot start this model's transaction"
	)
	_check(
		abandoned_weak.get_ref() == null
		and abandoned_model.claim_owner_mutation_capability() == null
		and not abandoned_model.is_owner_mutation_capability_current(null),
		"an abandoned owner capability becomes stale and can never be reissued"
	)

	# An owner-bound model must be live when it receives its initial damage. The
	# detached fixture paths elsewhere in this suite remain data-only probes;
	# lifecycle-owned mutation is covered by the integration currentness test.
	root.add_child(model)
	model.record_damage(80.0, _component_position(
		model, ShipComponentDamageType.COMPONENT_FORWARD_HULL
	))
	var revision_before := model.get_revision()
	var ledger_generation_before := model.get_ledger_generation()
	var bounds_before := model.get_component_report().get("local_bounds", AABB()) as AABB
	_check(
		model.begin_owner_mutation_transaction(capability)
		and not model.begin_owner_mutation_transaction(capability),
		"the exact owner opens one non-nestable transaction"
	)

	root.remove_child(model)
	root.add_child(model)
	_check(
		model.is_owner_mutation_capability_current(capability),
		"detach and re-entry preserve the exact owner capability identity"
	)

	var blocked_damage := model.record_damage(4.0, Vector3.INF)
	var blocked_repair := model.tick_repair(SIMULATION_STEP, true)
	model.reset_for_reuse()
	_check(
		not model.configure(SHIP_BOUNDS, MAXIMUM_HULL)
		and not bool(blocked_damage.accepted)
		and blocked_damage.reason == &"owner_transaction_active"
		and not bool(blocked_repair.accepted)
		and blocked_repair.reason == &"owner_transaction_active"
		and model.get_revision() == revision_before,
		"every legacy component mutator is atomic while the owner transaction is active"
	)

	_owner_guard_model = model
	_owner_guard_foreign_capability = foreign_capability
	_owner_guard_events.clear()
	_owner_guard_attacks.clear()
	model.component_state_changed.connect(_attack_owner_guard_from_state_signal)
	model.components_restored.connect(_attack_owner_guard_from_restore_signal)
	_check(
		model.reset_for_reuse_as_owner(capability),
		"the exact owner capability can perform the sole guarded roster reset"
	)
	_check(
		model.get_revision() == revision_before + 1
		and model.get_ledger_generation() == ledger_generation_before + 1
		and is_equal_approx(model.get_worst_integrity(), 1.0)
		and (model.get_component_report().get("local_bounds", AABB()) as AABB) == bounds_before,
		"owner reset preserves geometry and advances one generic generation and legacy revision"
	)
	var attacks_rejected := not _owner_guard_attacks.is_empty()
	for attack in _owner_guard_attacks:
		attacks_rejected = attacks_rejected \
			and not bool(attack.configure_accepted) \
			and attack.damage_reason == &"owner_transaction_active" \
			and attack.repair_reason == &"owner_transaction_active" \
			and not bool(attack.duplicate_claimed) \
			and not bool(attack.foreign_end_accepted) \
			and not bool(attack.foreign_reset_accepted) \
			and int(attack.revision_after) == int(attack.revision_before)
	_check(
		attacks_rejected,
		"state and restore callbacks cannot mutate the roster or end the owner's guard"
	)
	_check(
		not _owner_guard_events.is_empty()
		and _owner_guard_events[-1] == &"restored"
		and _owner_guard_events.find(&"state") >= 0,
		"guarded reset preserves component-state-before-restored signal chronology"
	)
	_check(
		not model.end_owner_mutation_transaction(foreign_capability)
		and model.record_damage(2.0, Vector3.INF).reason == &"owner_transaction_active"
		and model.end_owner_mutation_transaction(capability)
		and not model.end_owner_mutation_transaction(capability),
		"only the current owner closes the guard, exactly once"
	)
	_check(
		bool(model.record_damage(2.0, Vector3.INF).accepted),
		"legacy public mutations resume with their original outcome after owner commit"
	)
	model.component_state_changed.disconnect(_attack_owner_guard_from_state_signal)
	model.components_restored.disconnect(_attack_owner_guard_from_restore_signal)
	_owner_guard_model = null
	_owner_guard_foreign_capability = null
	root.remove_child(model)
	model.free()
	foreign_model.free()
	abandoned_model.free()


# ------------------------------------------------------------ attribution --


func _test_attribution() -> void:
	var model := _make_model()
	var nose_position := _component_position(model, ShipComponentDamageType.COMPONENT_FORWARD_HULL)
	var ledger_before := model.get_ledger_snapshot()
	var report := model.record_damage(30.0, nose_position)
	_check(bool(report.accepted) and bool(report.located), "a located hit is accepted and marked located")
	var ledger_after := model.get_ledger_snapshot()
	_check(
		int(ledger_after.get("revision", -1)) == int(ledger_before.get("revision", -2)) + 1
		and int(ledger_after.get("last_operation_sequence", -1))
			== (report.get("components", {}) as Dictionary).size() - 1,
		"one attributed hit commits its affected sections through one generic ledger batch"
	)

	var nose_loss := 1.0 - model.get_component_integrity(
		ShipComponentDamageType.COMPONENT_FORWARD_HULL
	)
	var tail_loss := 1.0 - model.get_component_integrity(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	_check(
		nose_loss > 0.0 and nose_loss > tail_loss,
		"a nose hit costs the forward hull more integrity than the far engine bay"
	)
	# Attribution shares are normalized to exactly one, so a hit small enough that
	# no section clamps at zero spends its whole budget and never a unit more,
	# wherever it lands.
	var budget_amount := 12.0
	var budget := (budget_amount / MAXIMUM_HULL) * ShipComponentDamageType.ATTRIBUTION_GAIN
	var budget_positions := [
		nose_position,
		_component_position(model, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS),
		Vector3(0.0, 0.0, -4000.0),
		Vector3.INF,
	]
	var budget_respected := true
	for position: Vector3 in budget_positions:
		var budget_model := _make_model()
		budget_model.record_damage(budget_amount, position)
		var total_loss := 0.0
		for entry in budget_model.get_component_states():
			total_loss += 1.0 - float(entry.integrity)
		if absf(total_loss - budget) > 0.0001:
			budget_respected = false
		budget_model.free()
	_check(
		budget_respected,
		"attribution spends exactly the integrity the resolved hit is worth, never more"
	)

	var tail_model := _make_model()
	tail_model.record_damage(
		30.0,
		_component_position(tail_model, ShipComponentDamageType.COMPONENT_ENGINE_BAY)
	)
	_check(
		tail_model.get_component_integrity(ShipComponentDamageType.COMPONENT_ENGINE_BAY)
			< tail_model.get_component_integrity(
				ShipComponentDamageType.COMPONENT_FORWARD_HULL
			),
		"the struck section is always the worst-off one, whichever end is hit"
	)
	tail_model.free()

	var distant_model := _make_model()
	var distant := distant_model.record_damage(30.0, Vector3(0.0, 0.0, -4000.0))
	_check(
		bool(distant.accepted)
		and distant_model.get_component_integrity(
			ShipComponentDamageType.COMPONENT_FORWARD_HULL
		) < 1.0,
		"a hit outside every splash radius is still credited to the nearest section"
	)
	distant_model.free()
	model.free()


func _test_state_boundaries() -> void:
	_check(
		ShipComponentDamageType.state_for_integrity(1.0)
			== ShipComponentDamageType.ComponentState.NOMINAL,
		"full integrity classifies as nominal"
	)
	_check(
		ShipComponentDamageType.state_for_integrity(
			ShipComponentDamageType.IMPAIRED_THRESHOLD
		) == ShipComponentDamageType.ComponentState.IMPAIRED,
		"the impaired threshold itself classifies as impaired"
	)
	_check(
		ShipComponentDamageType.state_for_integrity(
			ShipComponentDamageType.IMPAIRED_THRESHOLD + 0.0001
		) == ShipComponentDamageType.ComponentState.NOMINAL,
		"just above the impaired threshold is still nominal"
	)
	_check(
		ShipComponentDamageType.state_for_integrity(
			ShipComponentDamageType.FAILED_THRESHOLD
		) == ShipComponentDamageType.ComponentState.FAILED,
		"the failed threshold itself classifies as failed"
	)
	_check(
		ShipComponentDamageType.state_for_integrity(
			ShipComponentDamageType.FAILED_THRESHOLD + 0.0001
		) == ShipComponentDamageType.ComponentState.IMPAIRED,
		"just above the failed threshold is impaired, not failed"
	)
	_check(
		ShipComponentDamageType.state_for_integrity(0.0)
			== ShipComponentDamageType.ComponentState.FAILED
		and ShipComponentDamageType.state_for_integrity(NAN)
			== ShipComponentDamageType.ComponentState.FAILED,
		"zero and non-finite integrity both fail closed"
	)

	var model := _make_model()
	model.component_state_changed.connect(_record_state_event)
	_state_events.clear()
	var nose_position := _component_position(model, ShipComponentDamageType.COMPONENT_FORWARD_HULL)
	var guard := 0
	while (
		model.get_component_state(ShipComponentDamageType.COMPONENT_FORWARD_HULL)
			!= ShipComponentDamageType.ComponentState.FAILED
		and guard < 40
	):
		model.record_damage(11.0, nose_position)
		guard += 1
	_check(
		guard > 1 and guard < 40,
		"repeated defence-cannon hits drive one section through to failure in a bounded count"
	)
	var forward_events: Array[int] = []
	for event in _state_events:
		if StringName(event.id) == ShipComponentDamageType.COMPONENT_FORWARD_HULL:
			forward_events.append(int(event.state))
	_check(
		forward_events == [
			ShipComponentDamageType.ComponentState.IMPAIRED,
			ShipComponentDamageType.ComponentState.FAILED,
		],
		"a section announces each grade exactly once, in order, and never repeats a grade"
	)
	model.component_state_changed.disconnect(_record_state_event)
	model.free()


func _test_invalid_damage() -> void:
	var model := _make_model()
	var nose_position := _component_position(model, ShipComponentDamageType.COMPONENT_FORWARD_HULL)
	var revision_before := model.get_revision()
	var rejected := [0.0, -1.0, -250.0, NAN, INF, -INF]
	var all_rejected := true
	for amount: float in rejected:
		var report := model.record_damage(amount, nose_position)
		if bool(report.accepted) or report.reason != &"invalid_damage":
			all_rejected = false
	_check(all_rejected, "zero, negative and non-finite damage is rejected as invalid")
	_check(
		is_equal_approx(model.get_worst_integrity(), 1.0)
		and model.get_revision() == revision_before,
		"a rejected damage record changes no integrity and publishes no revision"
	)

	var clamp_model := _make_model()
	var overkill := clamp_model.record_damage(MAXIMUM_HULL * 40.0, nose_position)
	_check(
		is_equal_approx(float(overkill.normalized_damage), 1.0),
		"damage beyond the whole hull is clamped to a single hull's worth of attribution"
	)
	_check(
		clamp_model.get_component_integrity(ShipComponentDamageType.COMPONENT_FORWARD_HULL) <= 0.0,
		"an overkill hit drives the struck section to zero integrity, not below it"
	)
	_exhaust_roster(clamp_model)
	var spent := clamp_model.record_damage(MAXIMUM_HULL, Vector3.INF)
	_check(
		not bool(spent.accepted) and spent.reason == &"no_component_effect",
		"a fully failed roster reports that further damage changed nothing"
	)
	clamp_model.free()
	model.free()


func _test_unlocated_damage() -> void:
	var model := _make_model()
	var report := model.record_damage(20.0, Vector3.INF)
	_check(
		bool(report.accepted) and not bool(report.located),
		"an unlocated hit is recorded as a diffuse hit rather than rejected"
	)
	var first := -1.0
	var uniform := true
	for entry in model.get_component_states():
		if first < 0.0:
			first = float(entry.integrity)
		elif not is_equal_approx(float(entry.integrity), first):
			uniform = false
	_check(uniform and first < 1.0, "a diffuse hit costs every section the same integrity")

	var nan_model := _make_model()
	var nan_report := nan_model.record_damage(20.0, Vector3(NAN, 0.0, 0.0))
	_check(
		bool(nan_report.accepted) and not bool(nan_report.located),
		"a non-finite hit position degrades to a diffuse hit instead of corrupting the layout"
	)
	nan_model.free()
	model.free()


# ---------------------------------------------------------------- repair --


func _test_repair_authorization() -> void:
	var model := _make_model()
	model.record_damage(45.0, _component_position(
		model, ShipComponentDamageType.COMPONENT_PORT_WING
	))
	var damaged := model.get_worst_integrity()
	_check(damaged < 1.0, "the craft is measurably damaged before the repair contract is exercised")

	var unauthorized := model.tick_repair(SIMULATION_STEP, false)
	_check(
		not bool(unauthorized.accepted)
		and unauthorized.reason == &"repair_not_authorized"
		and is_equal_approx(model.get_worst_integrity(), damaged),
		"repair does nothing while the owner has not authorized it, so damage reads for the whole sortie"
	)
	var invalid_deltas := [0.0, -SIMULATION_STEP, NAN, INF]
	var all_rejected := true
	for delta: float in invalid_deltas:
		var report := model.tick_repair(delta, true)
		if bool(report.accepted) or report.reason != &"invalid_delta":
			all_rejected = false
	_check(
		all_rejected and is_equal_approx(model.get_worst_integrity(), damaged),
		"a zero, negative or non-finite simulation step cannot advance repair"
	)

	var authorized := model.tick_repair(SIMULATION_STEP, true)
	_check(
		bool(authorized.accepted)
		and int(authorized.repaired_components) > 0
		and model.get_worst_integrity() > damaged,
		"an authorized step raises integrity on exactly the sections that lost it"
	)
	model.reset_for_reuse()
	var nominal := model.tick_repair(SIMULATION_STEP, true)
	_check(
		not bool(nominal.accepted) and nominal.reason == &"already_nominal",
		"an intact craft reports that there was nothing to repair"
	)
	model.free()


func _test_repair_recovery_budget() -> void:
	var model := _make_model()
	_exhaust_roster(model)
	_check(
		model.get_failed_component_count() == ShipComponentDamageType.COMPONENT_ORDER.size(),
		"the recovery budget is measured from a completely failed craft"
	)
	var steps := 0
	while model.get_worst_integrity() < 1.0 and steps < REPAIR_STEP_BUDGET:
		model.tick_repair(SIMULATION_STEP, true)
		steps += 1
	_check(
		model.get_worst_integrity() >= 1.0 and steps <= REPAIR_STEP_BUDGET,
		"a completely failed craft repairs fully inside two seconds of berthed time"
	)
	_check(
		model.get_failed_component_count() == 0 and model.get_impaired_component_count() == 0,
		"berth repair returns every section to nominal, not merely above the failure line"
	)
	var overshoot := model.get_worst_integrity()
	model.tick_repair(SIMULATION_STEP, true)
	_check(
		is_equal_approx(model.get_worst_integrity(), overshoot)
		and is_equal_approx(overshoot, 1.0),
		"repair clamps at full integrity and cannot overshoot it"
	)
	model.free()


func _test_restore_and_determinism() -> void:
	var model := _make_model()
	model.components_restored.connect(_record_restore)
	_restore_events = 0
	model.record_damage(80.0, _component_position(
		model, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	))
	_check(model.get_worst_integrity() < 1.0, "the craft is damaged before respawn restoration")
	model.reset_for_reuse()
	_check(
		is_equal_approx(model.get_worst_integrity(), 1.0)
		and model.get_failed_component_count() == 0
		and _restore_events == 1,
		"respawn restoration is instant, complete, and announced exactly once"
	)
	model.components_restored.disconnect(_record_restore)

	# Two independently constructed models fed an identical script must agree
	# exactly. Any wall-clock read, RNG draw, or retained cross-call state in the
	# model would show up here as a divergence.
	var first := _make_model()
	var second := _make_model()
	var script_positions := [
		_component_position(first, ShipComponentDamageType.COMPONENT_FORWARD_HULL),
		_component_position(first, ShipComponentDamageType.COMPONENT_PORT_WING),
		Vector3.INF,
		_component_position(first, ShipComponentDamageType.COMPONENT_ENGINE_BAY),
	]
	for position: Vector3 in script_positions:
		first.record_damage(17.0, position)
		second.record_damage(17.0, position)
	for _step in 5:
		first.tick_repair(SIMULATION_STEP, true)
		second.tick_repair(SIMULATION_STEP, true)
	var identical := true
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		if not is_equal_approx(
			first.get_component_integrity(component_id),
			second.get_component_integrity(component_id)
		):
			identical = false
	_check(identical, "two models replaying one damage and repair script agree exactly")
	first.free()
	second.free()
	model.free()


# ---------------------------------------------------------- presentation --


func _test_presentation_channel() -> void:
	var presentation := HeroDamagePresentationType.new() as HeroDamagePresentation
	root.add_child(presentation)
	_failure_started.clear()
	_failure_cleared.clear()
	presentation.component_failure_started.connect(_record_failure_started)
	presentation.component_failure_cleared.connect(_record_failure_cleared)
	presentation.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)

	var live := presentation.set_component_damage_states([
		_state_entry(&"port_wing", 1, Vector3(-3.0, 0.5, 0.0)),
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
		_state_entry(&"core_systems", 0, Vector3(0.0, 0.8, 0.0)),
	])
	_check(
		live == 2 and presentation.get_active_component_effect_count() == 2,
		"only impaired and failed sections take a localized rig"
	)
	var expected_ids: Array[StringName] = [&"engine_bay", &"port_wing"]
	_check(
		presentation.get_component_effect_ids() == expected_ids,
		"the live rig roster names exactly the damaged sections"
	)
	var impaired_rig := presentation.get_node_or_null("ComponentDamage_port_wing") as Node3D
	var failed_rig := presentation.get_node_or_null("ComponentDamage_engine_bay") as Node3D
	_check(
		impaired_rig != null and failed_rig != null,
		"each damaged section owns one ship-local rig node"
	)
	_check(
		impaired_rig.position.is_equal_approx(Vector3(-3.0, 0.5, 0.0)),
		"a rig sits at the section's own ship-local position, not a shared anchor"
	)
	var impaired_sparks := impaired_rig.get_node("ComponentSparks") as CPUParticles3D
	var impaired_smoke := impaired_rig.get_node("ComponentSmoke") as CPUParticles3D
	var failed_smoke := failed_rig.get_node("ComponentSmoke") as CPUParticles3D
	_check(
		impaired_sparks.emitting
		and impaired_sparks.visible
		and not impaired_smoke.emitting
		and not impaired_smoke.visible,
		"an impaired section shows sparks while renderer-hiding dormant smoke"
	)
	_check(
		failed_smoke.emitting and failed_smoke.visible,
		"a failed section vents visible smoke as well as sparking"
	)
	_check(
		_failure_started.size() == 1
		and _failure_started[0].get("id") == &"engine_bay"
		and presentation.get_failed_component_effect_ids() == [&"engine_bay"],
		"a failed section emits one deterministic failure-start event and appears in the failed snapshot"
	)

	var repeated := presentation.set_component_damage_states([
		_state_entry(&"port_wing", 1, Vector3(-3.0, 0.5, 0.0)),
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
	])
	_check(
		repeated == 2
		and presentation.get_node_or_null("ComponentDamage_port_wing") == impaired_rig,
		"republishing the same roster reuses the existing rigs instead of duplicating them"
	)

	presentation.set_component_damage_states([
		_state_entry(&"port_wing", 2, Vector3(-3.0, 0.5, 0.0)),
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
	])
	_check(
		impaired_smoke.emitting
		and presentation.get_component_effect_state(&"port_wing")
			== HeroDamagePresentation.COMPONENT_STATE_FAILED,
		"a section that degrades from impaired to failed re-grades its existing rig"
	)

	presentation.set_component_damage_states([
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
	])
	_check(
		presentation.get_active_component_effect_count() == 1
		and presentation.get_node_or_null("ComponentDamage_port_wing") == null,
		"a repaired section retires its rig synchronously"
	)
	_check(
		_failure_cleared == [&"port_wing"],
		"a repaired failed section emits one deterministic failure-clear event"
	)

	var malformed := presentation.set_component_damage_states([
		"not a dictionary",
		{"state": 2, "local_position": Vector3.ZERO},
		_state_entry(&"nan_section", 2, Vector3(NAN, 0.0, 0.0)),
		{"id": &"typeless_section", "state": 2, "local_position": "over there"},
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
	])
	var surviving_ids: Array[StringName] = [&"engine_bay"]
	_check(
		malformed == 1 and presentation.get_component_effect_ids() == surviving_ids,
		"malformed, unnamed and non-finite entries create no rig"
	)

	var flood: Array = []
	for index in 24:
		flood.append(_state_entry(
			StringName("flood_%02d" % index),
			2,
			Vector3(float(index), 0.0, 0.0)
		))
	var bounded := presentation.set_component_damage_states(flood)
	_check(
		bounded == HeroDamagePresentation.MAX_COMPONENT_EFFECTS,
		"the localized channel is bounded so a pathological roster cannot flood the craft"
	)

	presentation.clear_component_damage_effects()
	_check(
		presentation.get_active_component_effect_count() == 0
		and presentation.get_node_or_null("ComponentDamage_engine_bay") == null,
		"clearing the channel detaches every rig synchronously"
	)
	presentation.free()


func _test_presentation_cleanup_and_reentry() -> void:
	var presentation := HeroDamagePresentationType.new() as HeroDamagePresentation
	root.add_child(presentation)
	presentation.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	presentation.set_component_damage_states([
		_state_entry(&"port_wing", 2, Vector3(-3.0, 0.5, 0.0)),
	])
	_check(
		presentation.get_active_component_effect_count() == 1,
		"a rig is live before the reuse and re-entry contract is exercised"
	)

	presentation.reset_for_reuse(1.0, HeroDamagePresentation.STATE_POWERED_DOWN)
	_check(
		presentation.get_active_component_effect_count() == 0,
		"recycling a craft for reuse clears its component rigs"
	)

	presentation.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	presentation.set_component_damage_states([
		_state_entry(&"engine_bay", 2, Vector3(0.0, 0.6, 4.4)),
	])
	var rig := presentation.get_node("ComponentDamage_engine_bay") as Node3D
	var smoke := rig.get_node("ComponentSmoke") as CPUParticles3D
	root.remove_child(presentation)
	_check(
		presentation.get_active_component_effect_count() == 1
		and is_instance_valid(rig)
		and rig.get_parent() == presentation,
		"a detached craft keeps its ship-local rigs rather than stranding them in world space"
	)
	root.add_child(presentation)
	_check(
		presentation.get_active_component_effect_count() == 1
		and smoke.emitting
		and smoke.visible,
		"re-entry resumes exactly the roster the craft left with"
	)
	_check(
		presentation.get_node_or_null("ComponentDamage_engine_bay") == rig,
		"re-entry does not duplicate a rig the craft already owns"
	)

	presentation.present_destruction(Vector3.ZERO)
	_check(
		not smoke.emitting and not smoke.visible,
		"a destroyed craft silences and renderer-hides its component rigs with the staged hull channel"
	)
	presentation.reset_for_reuse(1.0, HeroDamagePresentation.STATE_POWERED_DOWN)
	_check(
		presentation.get_active_component_effect_count() == 0,
		"a respawned craft starts with no component rig from its previous life"
	)
	presentation.dispose_effects()
	_check(
		presentation.get_active_component_effect_count() == 0,
		"disposal of an already-clean channel is idempotent"
	)
	presentation.free()


func _test_queued_destruction_resume_is_inert() -> void:
	var presentation := HeroDamagePresentationType.new() as HeroDamagePresentation
	root.add_child(presentation)
	var destruction_events := [0]
	presentation.destruction_started.connect(
		func(_position: Vector3, _velocity: Vector3) -> void:
			destruction_events[0] += 1
	)
	root.remove_child(presentation)
	presentation.present_destruction(Vector3.ZERO, Transform3D.IDENTITY)
	_check(
		bool(presentation.get("_pending_destruction"))
		and presentation.get_live_world_effect_count() == 0,
		"detached destruction remains pending without spawning a world effect"
	)
	root.add_child(presentation)
	# Re-entry queued the deferred destruction handoff. Terminal disposal in the
	# same idle turn must not leak debris/particles into the live world root.
	presentation.queue_free()
	presentation.call("_resume_pending_destruction_after_reentry")
	_check(
		presentation.is_queued_for_deletion()
		and bool(presentation.get("_pending_destruction"))
		and presentation.get_live_world_effect_count() == 0
		and destruction_events[0] == 0,
		"a queued post-reentry presentation cannot resume destruction into world space"
	)
	await process_frame
	_check(
		not is_instance_valid(presentation),
		"the queued pending-destruction presentation frees normally"
	)


# ---------------------------------------------------------------- helpers --


func _make_model() -> ShipComponentDamage:
	var model := ShipComponentDamageType.new() as ShipComponentDamage
	model.configure(SHIP_BOUNDS, MAXIMUM_HULL)
	return model


## Drives every section of a configured roster to zero integrity with a bounded,
## deterministic number of whole-hull diffuse hits.
func _exhaust_roster(model: ShipComponentDamage) -> void:
	for _hit in 8:
		model.record_damage(MAXIMUM_HULL, Vector3.INF)


func _component_position(model: ShipComponentDamage, component_id: StringName) -> Vector3:
	for entry in model.get_component_states():
		if StringName(entry.id) == component_id:
			return entry.local_position as Vector3
	return Vector3.ZERO


func _degrade_to_impaired(model: ShipComponentDamage, component_id: StringName) -> void:
	for _hit in 8:
		if model.get_component_state(component_id) != ShipComponentDamageType.ComponentState.NOMINAL:
			return
		model.record_damage(3.0, _component_position(model, component_id))


func _state_entry(component_id: StringName, state: int, local_position: Vector3) -> Dictionary:
	return {
		"id": component_id,
		"state": state,
		"local_position": local_position,
	}


func _record_state_event(component_id: StringName, state: int, integrity: float) -> void:
	_state_events.append({"id": component_id, "state": state, "integrity": integrity})


func _record_restore() -> void:
	_restore_events += 1


func _attack_owner_guard_from_state_signal(
	_component_id: StringName,
	_state: int,
	_integrity: float
) -> void:
	_owner_guard_events.append(&"state")
	_attack_owner_guard()


func _attack_owner_guard_from_restore_signal() -> void:
	_owner_guard_events.append(&"restored")
	_attack_owner_guard()


func _attack_owner_guard() -> void:
	var revision_before := _owner_guard_model.get_revision()
	var configure_accepted := _owner_guard_model.configure(SHIP_BOUNDS, MAXIMUM_HULL)
	var damage := _owner_guard_model.record_damage(3.0, Vector3.INF)
	var repair := _owner_guard_model.tick_repair(SIMULATION_STEP, true)
	_owner_guard_model.reset_for_reuse()
	_owner_guard_attacks.append({
		"configure_accepted": configure_accepted,
		"damage_reason": damage.reason,
		"repair_reason": repair.reason,
		"duplicate_claimed": _owner_guard_model.claim_owner_mutation_capability() != null,
		"foreign_end_accepted": _owner_guard_model.end_owner_mutation_transaction(
			_owner_guard_foreign_capability
		),
		"foreign_reset_accepted": _owner_guard_model.reset_for_reuse_as_owner(
			_owner_guard_foreign_capability
		),
		"revision_before": revision_before,
		"revision_after": _owner_guard_model.get_revision(),
	})


func _record_failure_started(component_id: StringName, local_position: Vector3) -> void:
	_failure_started.append({"id": component_id, "position": local_position})


func _record_failure_cleared(component_id: StringName) -> void:
	_failure_cleared.append(component_id)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_COMPONENT_DAMAGE_TEST_OK")
		quit(0)
	else:
		print("SHIP_COMPONENT_DAMAGE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
