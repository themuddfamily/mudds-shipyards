extends SceneTree

const ComponentDamageModelType := preload(
	"res://scripts/combat/component_damage_model.gd"
)

const ENGINE_ID: StringName = &"engine_core"
const WEAPON_ID: StringName = &"pulse_mount"
const MODEL_SCHEMA_VERSION := 3
const MAX_FINITE_REPAIR := 1.7976931348623157e308
const DEFINITION_SNAPSHOT_KEYS := [
	"schema_version",
	"components",
	"evidence",
	"authority",
]
const MODEL_SNAPSHOT_KEYS := [
	"schema_version",
	"generation",
	"revision",
	"last_operation_sequence",
	"last_damage_sequence",
	"active",
	"component_order",
	"components",
	"evidence",
	"authority",
]
const COMPONENT_STATE_KEYS := [
	"component_id",
	"maximum_health",
	"current_health",
	"health_ratio",
	"stage",
]
const BATCH_RESULT_KEYS := [
	"accepted",
	"reason",
	"generation",
	"sequence",
	"revision",
	"operation_kind",
	"operation_count",
	"first_sequence",
	"last_sequence",
	"operations",
]
const DAMAGE_RESULT_KEYS := [
	"accepted",
	"reason",
	"generation",
	"sequence",
	"revision",
	"component_id",
	"requested_damage",
	"applied_damage",
	"previous_health",
	"current_health",
	"maximum_health",
	"stage",
	"stage_changed",
]
const REPAIR_RESULT_KEYS := [
	"accepted",
	"reason",
	"generation",
	"sequence",
	"revision",
	"component_id",
	"requested_repair",
	"applied_repair",
	"previous_health",
	"current_health",
	"maximum_health",
	"stage",
	"stage_changed",
]
const REJECTION_RESULT_KEYS := [
	"accepted",
	"reason",
	"generation",
	"sequence",
	"revision",
]
const AUDIT_KEYS := [
	"schema_version",
	"valid",
	"configuration_errors",
	"definition",
	"state",
	"evidence",
	"authority",
]
const AUTHORITY_KEYS := [
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
const VALID_DEFINITIONS := [
	{
		"component_id": ENGINE_ID,
		"maximum_health": 100.0,
		"damage_stages": [
			{
				"stage_id": &"nominal",
				"health_ratio_at_or_below": 1.0,
				"disabled": false,
				"performance_multiplier": 1.0,
			},
			{
				"stage_id": &"damaged",
				"health_ratio_at_or_below": 0.75,
				"disabled": false,
				"performance_multiplier": 0.72,
			},
			{
				"stage_id": &"critical",
				"health_ratio_at_or_below": 0.35,
				"disabled": false,
				"performance_multiplier": 0.38,
			},
			{
				"stage_id": &"failed",
				"health_ratio_at_or_below": 0.0,
				"disabled": true,
				"performance_multiplier": 0.0,
			},
		],
	},
	{
		"component_id": WEAPON_ID,
		"maximum_health": 60.0,
		"damage_stages": [
			{
				"stage_id": &"nominal",
				"health_ratio_at_or_below": 1.0,
				"disabled": false,
				"performance_multiplier": 1.0,
			},
			{
				"stage_id": &"degraded",
				"health_ratio_at_or_below": 0.5,
				"disabled": false,
				"performance_multiplier": 0.55,
			},
			{
				"stage_id": &"failed",
				"health_ratio_at_or_below": 0.0,
				"disabled": true,
				"performance_multiplier": 0.0,
			},
		],
	},
]

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_typed_configuration_snapshot()
	_test_reset_and_ordered_stages()
	_test_ordered_repair_and_shared_sequence()
	_test_atomic_damage_batch_order_and_detachment()
	_test_atomic_repair_batch_order_and_detachment()
	_test_batch_structured_red_rejections()
	_test_atomic_rejections()
	_test_repair_atomic_rejections()
	_test_reentrant_mutation_guard()
	_test_generation_safe_reuse()
	_test_configuration_validation()
	_test_detached_snapshots_and_audit()
	_test_zero_authority_boundary()
	_finish()


func _test_typed_configuration_snapshot() -> void:
	var source := VALID_DEFINITIONS.duplicate(true)
	var model := ComponentDamageModelType.new(source) as ComponentDamageModel
	_check(model != null and model is RefCounted, "ComponentDamageModel is one typed RefCounted contract")
	_check(model.is_configuration_valid(), "the complete two-component definition validates")
	_check(
		model.get_configuration_errors().is_empty(),
		"a valid definition publishes no configuration errors"
	)
	_check(
		ComponentDamageModelType.is_stable_id(ENGINE_ID)
			and ComponentDamageModelType.is_stable_id(&"engine_core_2")
			and not ComponentDamageModelType.is_stable_id(&"1_engine")
			and not ComponentDamageModelType.is_stable_id(&"EngineCore")
			and not ComponentDamageModelType.is_stable_id(&"engine__core")
			and not ComponentDamageModelType.is_stable_id(&"engine-core"),
		"component and stage identities use one strict lowercase snake-case grammar"
	)
	source[0]["maximum_health"] = 999.0
	(source[0]["damage_stages"] as Array)[0]["performance_multiplier"] = 0.1
	var captured := model.get_definition_snapshot()
	_check(
		int(captured.get("schema_version", 0)) == MODEL_SCHEMA_VERSION
			and _has_exact_keys(captured, DEFINITION_SNAPSHOT_KEYS)
			and _has_exact_keys(model.get_snapshot(), MODEL_SNAPSHOT_KEYS),
		"schema version three freezes the exact definition and aggregate snapshot rosters"
	)
	var captured_components := captured.get("components", []) as Array
	_check(
		is_equal_approx(float(captured_components[0].maximum_health), 100.0)
			and is_equal_approx(
				float((captured_components[0].damage_stages as Array)[0].performance_multiplier),
				1.0
			),
		"construction detaches definitions from later caller mutation"
	)
	_check(
		model.get_generation() == 0
			and model.get_revision() == 0
			and model.get_component_states().is_empty(),
		"a valid definition remains inactive until its first generation reset"
	)
	var inactive := model.apply_component_damage(
		_damage_context(ENGINE_ID, 1.0, 0, 0)
	)
	_check(
		not bool(inactive.accepted) and inactive.reason == &"inactive",
		"an inactive definition cannot accept damage"
	)
	var inactive_repair := model.apply_component_repair(
		_repair_context(ENGINE_ID, 1.0, 0, 0)
	)
	_check(
		not bool(inactive_repair.accepted) and inactive_repair.reason == &"inactive",
		"an inactive definition cannot accept repair"
	)
	var inactive_damage_batch := model.apply_component_damage_batch([
		_damage_context(ENGINE_ID, 1.0, 0, 0),
		_damage_context(WEAPON_ID, 1.0, 0, 1),
	])
	var inactive_repair_batch := model.apply_component_repair_batch([
		_repair_context(ENGINE_ID, 1.0, 0, 0),
		_repair_context(WEAPON_ID, 1.0, 0, 1),
	])
	_check(
		not bool(inactive_damage_batch.accepted)
			and inactive_damage_batch.reason == &"inactive"
			and _has_exact_keys(inactive_damage_batch, REJECTION_RESULT_KEYS)
			and not bool(inactive_repair_batch.accepted)
			and inactive_repair_batch.reason == &"inactive"
			and _has_exact_keys(inactive_repair_batch, REJECTION_RESULT_KEYS),
		"inactive damage and repair batches retain the exact rejection roster"
	)


func _test_reset_and_ordered_stages() -> void:
	var model := _make_model()
	var resets: Array[Dictionary] = []
	var damage_events: Array[Dictionary] = []
	var stage_events: Array[Dictionary] = []
	model.model_reset.connect(
		func(result: Dictionary) -> void: resets.append(result)
	)
	model.component_damage_applied.connect(
		func(result: Dictionary) -> void: damage_events.append(result)
	)
	model.component_stage_changed.connect(
		func(result: Dictionary) -> void: stage_events.append(result)
	)

	var started := model.reset_for_reuse(0)
	_check(
		bool(started.accepted)
			and started.reason == &"reset"
			and int(started.generation) == 1
			and int(started.component_count) == 2,
		"the first exact reset starts generation one with the complete roster"
	)
	_check(resets.size() == 1, "an accepted reset emits exactly one detached reset signal")
	var engine := model.get_component_state(ENGINE_ID)
	_check(
		_has_exact_keys(engine, COMPONENT_STATE_KEYS)
			and is_equal_approx(float(engine.maximum_health), 100.0)
			and is_equal_approx(float(engine.current_health), 100.0)
			and is_equal_approx(float(engine.health_ratio), 1.0),
		"reset publishes exact maximum and current component health"
	)
	_check(
		StringName((engine.stage as Dictionary).stage_id) == &"nominal"
			and not bool((engine.stage as Dictionary).disabled)
			and is_equal_approx(
				float((engine.stage as Dictionary).performance_multiplier), 1.0
			),
		"the exact 1.0 threshold selects the explicit nominal consequences"
	)

	var damaged := model.apply_component_damage(
		_damage_context(ENGINE_ID, 25.0, 1, 0)
	)
	_check(
		bool(damaged.accepted)
			and is_equal_approx(float(damaged.applied_damage), 25.0)
			and is_equal_approx(float(damaged.current_health), 75.0)
			and StringName((damaged.stage as Dictionary).stage_id) == &"damaged",
		"damage landing exactly on 0.75 advances to the inclusive damaged stage"
	)
	var critical := model.apply_component_damage(
		_damage_context(ENGINE_ID, 40.0, 1, 1)
	)
	_check(
		bool(critical.accepted)
			and is_equal_approx(float(critical.current_health), 35.0)
			and StringName((critical.stage as Dictionary).stage_id) == &"critical"
			and is_equal_approx(
				float((critical.stage as Dictionary).performance_multiplier), 0.38
			),
		"ordered thresholds classify the exact critical boundary deterministically"
	)
	var failed := model.apply_component_damage(
		_damage_context(ENGINE_ID, 80.0, 1, 2)
	)
	_check(
		bool(failed.accepted)
			and is_equal_approx(float(failed.requested_damage), 80.0)
			and is_equal_approx(float(failed.applied_damage), 35.0)
			and is_equal_approx(float(failed.current_health), 0.0),
		"lethal component damage clamps at zero and reports the exact committed amount"
	)
	_check(
		StringName((failed.stage as Dictionary).stage_id) == &"failed"
			and bool((failed.stage as Dictionary).disabled)
			and is_equal_approx(
				float((failed.stage as Dictionary).performance_multiplier), 0.0
			),
		"failure remains an explicit data-only flag and scalar"
	)
	_check(
		damage_events.size() == 3 and stage_events.size() == 3,
		"each accepted state change emits one damage event and one stage event"
	)
	var signal_copy: Dictionary = damage_events.back()
	(signal_copy.stage as Dictionary)["performance_multiplier"] = 0.9
	_check(
		is_equal_approx(
			float((model.get_component_state(ENGINE_ID).stage as Dictionary).performance_multiplier),
			0.0
		),
		"signal payloads cannot mutate the model's stage consequences"
	)
	var no_effect_before := model.get_snapshot()
	var no_effect := model.apply_component_damage(
		_damage_context(ENGINE_ID, 1.0, 1, 3)
	)
	_check(
		not bool(no_effect.accepted)
			and no_effect.reason == &"no_component_effect"
			and model.get_snapshot() == no_effect_before,
		"damage against a failed component is rejected without consuming its sequence"
	)


func _test_ordered_repair_and_shared_sequence() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	var damage_events: Array[Dictionary] = []
	var repair_events: Array[Dictionary] = []
	var stage_events: Array[Dictionary] = []
	model.component_damage_applied.connect(
		func(result: Dictionary) -> void: damage_events.append(result)
	)
	model.component_repair_applied.connect(
		func(result: Dictionary) -> void: repair_events.append(result)
	)
	model.component_stage_changed.connect(
		func(result: Dictionary) -> void: stage_events.append(result)
	)

	var damaged := model.apply_component_damage(
		_damage_context(ENGINE_ID, 65.0, 1, 0)
	)
	var repaired := model.apply_component_repair(
		_repair_context(ENGINE_ID, 40.0, 1, 1)
	)
	_check(
		bool(damaged.accepted)
			and bool(repaired.accepted)
			and repaired.reason == &"repaired"
			and is_equal_approx(float(repaired.requested_repair), 40.0)
			and is_equal_approx(float(repaired.applied_repair), 40.0)
			and is_equal_approx(float(repaired.previous_health), 35.0)
			and is_equal_approx(float(repaired.current_health), 75.0)
			and StringName((repaired.stage as Dictionary).stage_id) == &"damaged",
		"repair applies an exact finite amount and deterministically improves the inclusive stage"
	)
	_check(
		model.get_last_operation_sequence() == 1
			and model.get_last_damage_sequence() == 1
			and int(model.get_snapshot().last_operation_sequence) == 1
			and int(model.get_snapshot().last_damage_sequence) == 1,
		"damage and repair publish one shared operation cursor through the compatibility alias"
	)

	_check_repair_rejection_atomic(
		model,
		_repair_context(ENGINE_ID, 2.0, 1, 1),
		&"duplicate_sequence",
		"a repair cannot replay the sequence consumed by the preceding repair"
	)
	_check_rejection_atomic(
		model,
		_damage_context(ENGINE_ID, 2.0, 1, 0),
		&"stale_sequence",
		"damage cannot move behind a later repair in the shared operation order"
	)

	var interleaved_damage := model.apply_component_damage(
		_damage_context(WEAPON_ID, 10.0, 1, 2)
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(ENGINE_ID, 1.0, 1, 2),
		&"duplicate_sequence",
		"repair cannot replay a sequence consumed by damage in the shared operation order"
	)
	var before_clamp_revision := model.get_revision()
	var clamped := model.apply_component_repair(
		_repair_context(ENGINE_ID, MAX_FINITE_REPAIR, 1, 3)
	)
	_check(
		bool(interleaved_damage.accepted)
			and bool(clamped.accepted)
			and is_finite(float(clamped.requested_repair))
			and is_equal_approx(float(clamped.applied_repair), 25.0)
			and float(clamped.current_health) == 100.0
			and is_finite(float(clamped.current_health))
			and model.get_revision() == before_clamp_revision + 1
			and model.get_last_operation_sequence() == 3
			and StringName((clamped.stage as Dictionary).stage_id) == &"nominal",
		"maximum finite repair clamps overflow-safely at exact maximum in one commit"
	)
	(clamped.stage as Dictionary)["performance_multiplier"] = 0.0
	clamped["current_health"] = -250.0
	_check(
		is_equal_approx(float(model.get_component_state(ENGINE_ID).current_health), 100.0)
			and is_equal_approx(
				float((model.get_component_state(ENGINE_ID).stage as Dictionary).performance_multiplier),
				1.0
			),
		"returned repair results are detached from component health and stage consequences"
	)
	var before_no_effect_events := repair_events.size()
	_check_repair_rejection_atomic(
		model,
		_repair_context(ENGINE_ID, 1.0, 1, 4),
		&"no_component_effect",
		"repair against a full component is rejected without consuming the operation"
	)
	var reused_after_no_effect := model.apply_component_damage(
		_damage_context(WEAPON_ID, 1.0, 1, 4)
	)
	_check(
		bool(reused_after_no_effect.accepted)
			and model.get_last_operation_sequence() == 4
			and repair_events.size() == before_no_effect_events,
		"a no-effect repair leaves its sequence available to the next valid operation"
	)
	_check(
		damage_events.size() == 3
			and repair_events.size() == 2
			and stage_events.size() == 3,
		"accepted interleaved operations emit one typed signal and only real stage transitions"
	)
	var repair_signal_copy: Dictionary = repair_events.back()
	(repair_signal_copy.stage as Dictionary)["performance_multiplier"] = 0.0
	repair_signal_copy["current_health"] = -500.0
	_check(
		is_equal_approx(float(model.get_component_state(ENGINE_ID).current_health), 100.0)
			and is_equal_approx(
				float((model.get_component_state(ENGINE_ID).stage as Dictionary).performance_multiplier),
				1.0
			),
		"repair signal payloads are detached from component health and stage consequences"
	)


func _test_atomic_damage_batch_order_and_detachment() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	var chronology: Array[Dictionary] = []
	var dispatch_snapshots: Array[Dictionary] = []
	var damage_events: Array[Dictionary] = []
	var stage_callback: Callable = func(result: Dictionary) -> void:
		chronology.append({"signal": &"stage", "component_id": result.component_id})
		dispatch_snapshots.append(model.get_snapshot())
	var damage_callback: Callable = func(result: Dictionary) -> void:
		chronology.append({"signal": &"damage", "component_id": result.component_id})
		damage_events.append(result)
		dispatch_snapshots.append(model.get_snapshot())
	model.component_stage_changed.connect(stage_callback)
	model.component_damage_applied.connect(damage_callback)

	var contexts := [
		_damage_context(ENGINE_ID, 65.0, 1, 4),
		_damage_context(WEAPON_ID, 30.0, 1, 5),
	]
	var before_revision := model.get_revision()
	var result := model.apply_component_damage_batch(contexts)
	var operations := result.get("operations", []) as Array
	_check(
		bool(result.accepted)
			and result.reason == &"applied_batch"
			and _has_exact_keys(result, BATCH_RESULT_KEYS)
			and result.operation_kind == &"damage"
			and int(result.operation_count) == 2
			and int(result.first_sequence) == 4
			and int(result.last_sequence) == 5
			and int(result.sequence) == 5
			and int(result.revision) == before_revision + 1
			and model.get_revision() == before_revision + 1
			and model.get_last_operation_sequence() == 5,
		"one accepted damage batch returns the exact aggregate receipt and advances revision once"
	)
	_check(
		operations.size() == 2
			and _has_exact_keys(operations[0] as Dictionary, DAMAGE_RESULT_KEYS)
			and _has_exact_keys(operations[1] as Dictionary, DAMAGE_RESULT_KEYS)
			and operations[0].component_id == ENGINE_ID
			and int(operations[0].sequence) == 4
			and is_equal_approx(float(operations[0].current_health), 35.0)
			and operations[1].component_id == WEAPON_ID
			and int(operations[1].sequence) == 5
			and is_equal_approx(float(operations[1].current_health), 30.0)
			and int(operations[0].revision) == int(result.revision)
			and int(operations[1].revision) == int(result.revision),
		"damage batch operations preserve captured input order, contiguous identities, and one aggregate revision"
	)
	var expected_chronology := [
		{"signal": &"stage", "component_id": ENGINE_ID},
		{"signal": &"damage", "component_id": ENGINE_ID},
		{"signal": &"stage", "component_id": WEAPON_ID},
		{"signal": &"damage", "component_id": WEAPON_ID},
	]
	_check(
		chronology == expected_chronology,
		"damage batch dispatch is stage-before-operation in captured roster order"
	)
	var all_committed_before_dispatch := dispatch_snapshots.size() == 4
	for snapshot in dispatch_snapshots:
		var states := snapshot.get("components", []) as Array
		all_committed_before_dispatch = (
			all_committed_before_dispatch
			and is_equal_approx(float(states[0].current_health), 35.0)
			and is_equal_approx(float(states[1].current_health), 30.0)
			and int(snapshot.revision) == int(result.revision)
			and int(snapshot.last_operation_sequence) == 5
		)
	_check(
		all_committed_before_dispatch,
		"every damage callback observes the complete atomic batch state rather than a partial ledger"
	)

	contexts[0]["damage"] = 999.0
	operations[0]["current_health"] = -10.0
	(operations[0].stage as Dictionary)["disabled"] = true
	damage_events[0]["current_health"] = -20.0
	(damage_events[0].stage as Dictionary)["performance_multiplier"] = 0.99
	_check(
		is_equal_approx(float(model.get_component_state(ENGINE_ID).current_health), 35.0)
			and is_equal_approx(float(model.get_component_state(WEAPON_ID).current_health), 30.0)
			and is_equal_approx(
				float((model.get_component_state(ENGINE_ID).stage as Dictionary).performance_multiplier),
				0.38
			),
		"damage batch input, aggregate operations, and signal payloads are deeply detached"
	)
	var scalar := model.apply_component_damage(_damage_context(ENGINE_ID, 1.0, 1, 6))
	_check(
		bool(scalar.accepted)
			and _has_exact_keys(scalar, DAMAGE_RESULT_KEYS)
			and int(scalar.sequence) == 6
			and int(scalar.revision) == before_revision + 2
			and not scalar.has("operations"),
		"scalar damage remains an outcome-compatible one-operation commit on the shared cursor"
	)
	model.component_stage_changed.disconnect(stage_callback)
	model.component_damage_applied.disconnect(damage_callback)


func _test_atomic_repair_batch_order_and_detachment() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	model.apply_component_damage_batch([
		_damage_context(ENGINE_ID, 70.0, 1, 0),
		_damage_context(WEAPON_ID, 40.0, 1, 1),
	])
	var chronology: Array[Dictionary] = []
	var repair_events: Array[Dictionary] = []
	var dispatch_snapshots: Array[Dictionary] = []
	var stage_callback: Callable = func(result: Dictionary) -> void:
		chronology.append({"signal": &"stage", "component_id": result.component_id})
		dispatch_snapshots.append(model.get_snapshot())
	var repair_callback: Callable = func(result: Dictionary) -> void:
		chronology.append({"signal": &"repair", "component_id": result.component_id})
		repair_events.append(result)
		dispatch_snapshots.append(model.get_snapshot())
	model.component_stage_changed.connect(stage_callback)
	model.component_repair_applied.connect(repair_callback)

	var before_revision := model.get_revision()
	var result := model.apply_component_repair_batch([
		_repair_context(ENGINE_ID, 45.0, 1, 2),
		_repair_context(WEAPON_ID, MAX_FINITE_REPAIR, 1, 3),
	])
	var operations := result.get("operations", []) as Array
	_check(
		bool(result.accepted)
			and result.reason == &"repaired_batch"
			and _has_exact_keys(result, BATCH_RESULT_KEYS)
			and result.operation_kind == &"repair"
			and int(result.operation_count) == 2
			and int(result.first_sequence) == 2
			and int(result.last_sequence) == 3
			and int(result.revision) == before_revision + 1
			and model.get_revision() == before_revision + 1
			and model.get_last_operation_sequence() == 3,
		"one accepted repair batch returns one exact aggregate receipt and revision"
	)
	_check(
		operations.size() == 2
			and _has_exact_keys(operations[0] as Dictionary, REPAIR_RESULT_KEYS)
			and _has_exact_keys(operations[1] as Dictionary, REPAIR_RESULT_KEYS)
			and is_equal_approx(float(operations[0].current_health), 75.0)
			and is_equal_approx(float(operations[0].applied_repair), 45.0)
			and float(operations[1].current_health) == 60.0
			and is_equal_approx(float(operations[1].applied_repair), 40.0)
			and is_finite(float(operations[1].current_health)),
		"repair batch precomputes exact per-component outcomes and clamps maximum finite input safely"
	)
	var expected_chronology := [
		{"signal": &"stage", "component_id": ENGINE_ID},
		{"signal": &"repair", "component_id": ENGINE_ID},
		{"signal": &"stage", "component_id": WEAPON_ID},
		{"signal": &"repair", "component_id": WEAPON_ID},
	]
	_check(
		chronology == expected_chronology,
		"repair batch emits detached stage-before-repair signals in captured roster order"
	)
	var all_committed_before_dispatch := dispatch_snapshots.size() == 4
	for snapshot in dispatch_snapshots:
		var states := snapshot.get("components", []) as Array
		all_committed_before_dispatch = (
			all_committed_before_dispatch
			and is_equal_approx(float(states[0].current_health), 75.0)
			and float(states[1].current_health) == 60.0
			and int(snapshot.revision) == int(result.revision)
			and int(snapshot.last_operation_sequence) == 3
		)
	_check(
		all_committed_before_dispatch,
		"every repair callback observes the complete atomic batch state"
	)
	operations[0]["current_health"] = -1.0
	(repair_events[0].stage as Dictionary)["performance_multiplier"] = 0.0
	_check(
		is_equal_approx(float(model.get_component_state(ENGINE_ID).current_health), 75.0)
			and float(model.get_component_state(WEAPON_ID).current_health) == 60.0
			and is_equal_approx(
				float((model.get_component_state(ENGINE_ID).stage as Dictionary).performance_multiplier),
				0.72
			),
		"repair aggregate and per-operation signal payloads cannot mutate committed state"
	)
	model.component_stage_changed.disconnect(stage_callback)
	model.component_repair_applied.disconnect(repair_callback)


func _test_batch_structured_red_rejections() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	var signal_counts := {"count": 0}
	model.component_stage_changed.connect(
		func(_result: Dictionary) -> void:
			signal_counts["count"] = int(signal_counts.get("count", 0)) + 1
	)
	model.component_damage_applied.connect(
		func(_result: Dictionary) -> void:
			signal_counts["count"] = int(signal_counts.get("count", 0)) + 1
	)
	model.component_repair_applied.connect(
		func(_result: Dictionary) -> void:
			signal_counts["count"] = int(signal_counts.get("count", 0)) + 1
	)

	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(WEAPON_ID, 1.0e-300, 1, 1),
		],
		&"no_component_effect",
		"a no-effect second damage operation rejects the whole batch without partial health"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(ENGINE_ID, 5.0, 1, 1),
		],
		&"duplicate_component",
		"one component cannot appear twice in an atomic damage batch"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(WEAPON_ID, 5.0, 1, 0),
		],
		&"duplicate_sequence",
		"duplicate identities inside a batch reject before commit"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(WEAPON_ID, 5.0, 1, 2),
		],
		&"invalid_sequence",
		"gapped identities inside a batch reject before commit"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(WEAPON_ID, 5.0, 2, 1),
		],
		&"stale_generation",
		"every batch entry must carry the exact active generation"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(WEAPON_ID, NAN, 1, 1),
		],
		&"invalid_damage",
		"a non-finite later amount rejects the complete damage batch"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, 0),
			_damage_context(&"unknown_thruster", 5.0, 1, 1),
		],
		&"unknown_component",
		"an unknown later component rejects the complete damage batch"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[],
		&"invalid_batch",
		"an empty batch cannot consume revision or sequence state"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[_damage_context(ENGINE_ID, 10.0, 1, 0), &"not_a_context"],
		&"invalid_batch",
		"a non-dictionary roster entry rejects the complete batch"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 10.0, 1, ComponentDamageModelType.MAX_SAFE_INTEGER),
			_damage_context(WEAPON_ID, 5.0, 1, ComponentDamageModelType.MAX_SAFE_INTEGER + 1),
		],
		&"sequence_exhausted",
		"a batch that cannot fit a complete contiguous signed-safe range fails closed"
	)
	var boundary_model := _make_model()
	boundary_model.reset_for_reuse(0)
	var final_safe_batch := boundary_model.apply_component_damage_batch([
		_damage_context(
			ENGINE_ID,
			1.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER - 1
		),
		_damage_context(
			WEAPON_ID,
			1.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER
		),
	])
	_check(
		bool(final_safe_batch.accepted)
			and int(final_safe_batch.first_sequence)
				== ComponentDamageModelType.MAX_SAFE_INTEGER - 1
			and int(final_safe_batch.last_sequence)
				== ComponentDamageModelType.MAX_SAFE_INTEGER
			and boundary_model.get_last_operation_sequence()
				== ComponentDamageModelType.MAX_SAFE_INTEGER,
		"the final complete contiguous signed-safe batch range is accepted exactly once"
	)
	_check_repair_batch_rejection_atomic(
		boundary_model,
		[
			_repair_context(
				ENGINE_ID,
				1.0,
				1,
				ComponentDamageModelType.MAX_SAFE_INTEGER + 1
			),
		],
		&"sequence_exhausted",
		"no scalar-sized repair batch can advance an exhausted shared cursor"
	)
	_check(
		int(signal_counts.get("count", 0)) == 0,
		"structured-red damage batches emit no stage, damage, or repair signals"
	)

	var accepted := model.apply_component_damage(_damage_context(ENGINE_ID, 20.0, 1, 4))
	_check(bool(accepted.accepted), "the stale and repair batch fixtures begin from one scalar commit")
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 1.0, 1, 4),
			_damage_context(WEAPON_ID, 1.0, 1, 5),
		],
		&"duplicate_sequence",
		"a batch cannot replay the current shared high-water identity"
	)
	_check_damage_batch_rejection_atomic(
		model,
		[
			_damage_context(ENGINE_ID, 1.0, 1, 3),
			_damage_context(WEAPON_ID, 1.0, 1, 4),
		],
		&"stale_sequence",
		"a batch cannot begin behind the shared high-water identity"
	)
	var signal_count_after_scalar := int(signal_counts.get("count", 0))
	_check_repair_batch_rejection_atomic(
		model,
		[
			_repair_context(ENGINE_ID, 5.0, 1, 5),
			_repair_context(WEAPON_ID, 5.0, 1, 6),
		],
		&"no_component_effect",
		"a full later component rejects the whole repair batch without partially repairing the first"
	)
	_check_repair_batch_rejection_atomic(
		model,
		[
			_repair_context(ENGINE_ID, 5.0, 1, 5),
			_repair_context(WEAPON_ID, NAN, 1, 6),
		],
		&"invalid_repair",
		"a non-finite later repair rejects the complete batch before the first plan commits"
	)
	_check(
		int(signal_counts.get("count", 0)) == signal_count_after_scalar,
		"structured-red repair batch emits no signal after a valid first plan"
	)


func _test_atomic_rejections() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	var accepted_events: Array[Dictionary] = []
	model.component_damage_applied.connect(
		func(result: Dictionary) -> void: accepted_events.append(result)
	)
	_check(
		bool(model.apply_component_damage(_damage_context(WEAPON_ID, 2.0, 1, 4)).accepted),
		"the rejection fixture begins with one accepted sequence"
	)
	var accepted_count := accepted_events.size()
	_check_rejection_atomic(
		model,
		_damage_context(WEAPON_ID, 2.0, 1, 4),
		&"duplicate_sequence",
		"a duplicate accepted sequence is rejected atomically"
	)
	_check_rejection_atomic(
		model,
		_damage_context(WEAPON_ID, 2.0, 1, 3),
		&"stale_sequence",
		"an older sequence is rejected atomically"
	)
	_check_rejection_atomic(
		model,
		_damage_context(&"unknown_thruster", 2.0, 1, 5),
		&"unknown_component",
		"a stable but unknown component ID is rejected atomically"
	)
	_check_rejection_atomic(
		model,
		_damage_context(&"UnknownComponent", 2.0, 1, 5),
		&"invalid_component_id",
		"a malformed component ID is rejected before lookup"
	)
	_check_rejection_atomic(
		model,
		_damage_context(WEAPON_ID, 1.0e-300, 1, 5),
		&"no_component_effect",
		"sub-ULP damage is rejected without consuming sequence, revision, health, or signals"
	)
	for invalid_damage in [NAN, INF, -INF, 0.0, -1.0]:
		_check_rejection_atomic(
			model,
			_damage_context(WEAPON_ID, invalid_damage, 1, 5),
			&"invalid_damage",
			"non-finite, zero, and negative damage are rejected atomically"
		)
	_check_rejection_atomic(
		model,
		_damage_context(WEAPON_ID, 2.0, 0, 5),
		&"stale_generation",
		"a callback from an older generation is rejected atomically"
	)
	_check_rejection_atomic(
		model,
		_damage_context(WEAPON_ID, 2.0, 2, 5),
		&"stale_generation",
		"an unissued future generation is rejected atomically"
	)
	var extra := _damage_context(WEAPON_ID, 2.0, 1, 5)
	extra["source_id"] = 44
	_check_rejection_atomic(
		model,
		extra,
		&"invalid_context",
		"unknown context fields are rejected instead of silently acquiring meaning"
	)
	var missing := _damage_context(WEAPON_ID, 2.0, 1, 5)
	missing.erase("damage")
	_check_rejection_atomic(
		model,
		missing,
		&"invalid_context",
		"missing context fields are rejected"
	)
	var invalid_sequence := _damage_context(WEAPON_ID, 2.0, 1, -1)
	_check_rejection_atomic(
		model,
		invalid_sequence,
		&"invalid_sequence",
		"negative sequences are rejected"
	)
	_check(
		accepted_events.size() == accepted_count,
		"no rejected damage request emits an accepted-damage signal"
	)
	var resumed := model.apply_component_damage(
		_damage_context(WEAPON_ID, 2.0, 1, 5)
	)
	_check(
		bool(resumed.accepted) and model.get_last_damage_sequence() == 5,
		"rejected sequence five remains available for one later valid commit"
	)


func _test_repair_atomic_rejections() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	model.apply_component_damage(_damage_context(WEAPON_ID, 10.0, 1, 4))
	var repair_events: Array[Dictionary] = []
	var stage_events: Array[Dictionary] = []
	model.component_repair_applied.connect(
		func(result: Dictionary) -> void: repair_events.append(result)
	)
	model.component_stage_changed.connect(
		func(result: Dictionary) -> void: stage_events.append(result)
	)

	_check_repair_rejection_atomic(
		model,
		_repair_context(&"unknown_thruster", 2.0, 1, 5),
		&"unknown_component",
		"repair rejects an unknown stable component without partial mutation"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(&"UnknownComponent", 2.0, 1, 5),
		&"invalid_component_id",
		"repair rejects a malformed component identity before lookup"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(WEAPON_ID, 1.0e-300, 1, 5),
		&"no_component_effect",
		"sub-ULP repair is rejected without consuming sequence, revision, health, or signals"
	)
	for invalid_repair in [NAN, INF, -INF, 0.0, -1.0]:
		_check_repair_rejection_atomic(
			model,
			_repair_context(WEAPON_ID, invalid_repair, 1, 5),
			&"invalid_repair",
			"non-finite, zero, and negative repair is rejected atomically"
		)
	_check_repair_rejection_atomic(
		model,
		_repair_context(WEAPON_ID, 2.0, 0, 5),
		&"stale_generation",
		"repair from an older generation is rejected atomically"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(WEAPON_ID, 2.0, 2, 5),
		&"stale_generation",
		"repair from an unissued future generation is rejected atomically"
	)
	var extra := _repair_context(WEAPON_ID, 2.0, 1, 5)
	extra["repair_rate"] = 0.62
	_check_repair_rejection_atomic(
		model,
		extra,
		&"invalid_context",
		"repair rejects unknown policy fields rather than acquiring timing authority"
	)
	var missing := _repair_context(WEAPON_ID, 2.0, 1, 5)
	missing.erase("repair")
	_check_repair_rejection_atomic(
		model,
		missing,
		&"invalid_context",
		"repair rejects a context missing its amount"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(WEAPON_ID, 2.0, 1, -1),
		&"invalid_sequence",
		"repair rejects a negative operation sequence"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(
			WEAPON_ID,
			2.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER + 1
		),
		&"invalid_sequence",
		"repair rejects an out-of-range sequence before the ledger is exhausted"
	)
	_check(
		repair_events.is_empty() and stage_events.is_empty(),
		"no rejected repair request emits a repair or stage signal"
	)
	var resumed := model.apply_component_repair(
		_repair_context(WEAPON_ID, 2.0, 1, 5)
	)
	_check(
		bool(resumed.accepted)
			and model.get_last_operation_sequence() == 5
			and repair_events.size() == 1,
		"the rejected shared sequence remains available for one later valid repair"
	)

	var exhausted := _make_model()
	exhausted.reset_for_reuse(0)
	var final_safe := exhausted.apply_component_damage(
		_damage_context(
			ENGINE_ID,
			10.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER
		)
	)
	_check(
		bool(final_safe.accepted)
			and exhausted.get_last_operation_sequence()
				== ComponentDamageModelType.MAX_SAFE_INTEGER,
		"the maximum signed-safe sequence is the final accepted operation identity"
	)
	_check_repair_rejection_atomic(
		exhausted,
		_repair_context(
			ENGINE_ID,
			1.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER + 1
		),
		&"sequence_exhausted",
		"repair fails closed once no newer signed-safe operation identity remains"
	)
	_check_rejection_atomic(
		exhausted,
		_damage_context(
			ENGINE_ID,
			1.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER + 1
		),
		&"sequence_exhausted",
		"damage observes the same exhausted shared operation ledger"
	)
	_check_repair_rejection_atomic(
		exhausted,
		_repair_context(
			ENGINE_ID,
			1.0,
			1,
			ComponentDamageModelType.MAX_SAFE_INTEGER
		),
		&"duplicate_sequence",
		"retrying the final accepted identity remains a duplicate after exhaustion"
	)


func _test_reentrant_mutation_guard() -> void:
	var model := _make_model()
	var chronology: Array[StringName] = []
	var reentrant_attempts: Array[Dictionary] = []
	var attempt_reentrant_mutations: Callable = func(source: StringName) -> void:
		var next_sequence := model.get_last_operation_sequence() + 1
		var before_reset := model.get_snapshot()
		var reset_result := model.reset_for_reuse(model.get_generation())
		reentrant_attempts.append({
			"source": source,
			"mutation": &"reset",
			"result": reset_result,
			"unchanged": model.get_snapshot() == before_reset,
		})
		var before_damage := model.get_snapshot()
		var damage_result := model.apply_component_damage(
			_damage_context(ENGINE_ID, 1.0, model.get_generation(), next_sequence)
		)
		reentrant_attempts.append({
			"source": source,
			"mutation": &"damage",
			"result": damage_result,
			"unchanged": model.get_snapshot() == before_damage,
		})
		var before_repair := model.get_snapshot()
		var repair_result := model.apply_component_repair(
			_repair_context(ENGINE_ID, 1.0, model.get_generation(), next_sequence)
		)
		reentrant_attempts.append({
			"source": source,
			"mutation": &"repair",
			"result": repair_result,
			"unchanged": model.get_snapshot() == before_repair,
		})
		var before_damage_batch := model.get_snapshot()
		var damage_batch_result := model.apply_component_damage_batch([
			_damage_context(ENGINE_ID, 1.0, model.get_generation(), next_sequence),
			_damage_context(WEAPON_ID, 1.0, model.get_generation(), next_sequence + 1),
		])
		reentrant_attempts.append({
			"source": source,
			"mutation": &"damage_batch",
			"result": damage_batch_result,
			"unchanged": model.get_snapshot() == before_damage_batch,
		})
		var before_repair_batch := model.get_snapshot()
		var repair_batch_result := model.apply_component_repair_batch([
			_repair_context(ENGINE_ID, 1.0, model.get_generation(), next_sequence),
			_repair_context(WEAPON_ID, 1.0, model.get_generation(), next_sequence + 1),
		])
		reentrant_attempts.append({
			"source": source,
			"mutation": &"repair_batch",
			"result": repair_batch_result,
			"unchanged": model.get_snapshot() == before_repair_batch,
		})

	var reset_callback: Callable = func(_result: Dictionary) -> void:
		chronology.append(&"reset")
		attempt_reentrant_mutations.call(&"reset")
	var stage_callback: Callable = func(_result: Dictionary) -> void:
		chronology.append(&"stage")
		attempt_reentrant_mutations.call(&"stage")
	var damage_callback: Callable = func(_result: Dictionary) -> void:
		chronology.append(&"damage")
		attempt_reentrant_mutations.call(&"damage")
	var repair_callback: Callable = func(_result: Dictionary) -> void:
		chronology.append(&"repair")
		attempt_reentrant_mutations.call(&"repair")
	model.model_reset.connect(reset_callback)
	model.component_stage_changed.connect(stage_callback)
	model.component_damage_applied.connect(damage_callback)
	model.component_repair_applied.connect(repair_callback)

	var outer_reset := model.reset_for_reuse(0)
	var outer_damage := model.apply_component_damage(
		_damage_context(ENGINE_ID, 70.0, 1, 0)
	)
	var outer_repair := model.apply_component_repair(
		_repair_context(ENGINE_ID, 50.0, 1, 1)
	)
	var all_reentrant := reentrant_attempts.size() == 25
	for attempt in reentrant_attempts:
		var result := attempt.get("result", {}) as Dictionary
		all_reentrant = (
			all_reentrant
			and not bool(result.get("accepted", true))
			and result.get("reason", &"") == &"reentrant_call"
			and bool(attempt.get("unchanged", false))
		)
	_check(
		all_reentrant,
		"reset, stage, damage, and repair callbacks cannot nest scalar or batch mutations"
	)
	var expected_chronology: Array[StringName] = [
		&"reset",
		&"stage",
		&"damage",
		&"stage",
		&"repair",
	]
	_check(
		chronology == expected_chronology,
		"outer commits publish the exact reset then stage-before-operation signal chronology"
	)
	_check(
		bool(outer_reset.accepted)
			and int(outer_reset.revision) == 1
			and bool(outer_damage.accepted)
			and is_equal_approx(float(outer_damage.current_health), 30.0)
			and int(outer_damage.revision) == 2
			and bool(outer_repair.accepted)
			and is_equal_approx(float(outer_repair.current_health), 80.0)
			and int(outer_repair.revision) == 3
			and model.get_revision() == 3
			and model.get_last_operation_sequence() == 1,
		"hostile callbacks leave each outer result current and consume only its own commit"
	)
	model.model_reset.disconnect(reset_callback)
	model.component_stage_changed.disconnect(stage_callback)
	model.component_damage_applied.disconnect(damage_callback)
	model.component_repair_applied.disconnect(repair_callback)


func _test_generation_safe_reuse() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	var old_context := _damage_context(ENGINE_ID, 40.0, 1, 0)
	_check(
		bool(model.apply_component_damage(old_context).accepted),
		"generation one accepts its first component event"
	)
	var reset := model.reset_for_reuse(1)
	_check(
		bool(reset.accepted)
			and model.get_generation() == 2
			and model.get_last_operation_sequence() == -1
			and model.get_last_damage_sequence() == -1
			and is_equal_approx(
				float(model.get_component_state(ENGINE_ID).current_health), 100.0
			),
		"reuse advances generation once, restores health, and clears only the new sequence ledger"
	)
	_check_rejection_atomic(
		model,
		old_context,
		&"stale_generation",
		"a delayed generation-one damage event cannot touch the reused component"
	)
	_check_repair_rejection_atomic(
		model,
		_repair_context(ENGINE_ID, 5.0, 1, 1),
		&"stale_generation",
		"a delayed generation-one repair event cannot touch the reused component"
	)
	var reused_sequence := model.apply_component_damage(
		_damage_context(ENGINE_ID, 10.0, 2, 0)
	)
	_check(
		bool(reused_sequence.accepted)
			and is_equal_approx(float(reused_sequence.current_health), 90.0),
		"the same numeric sequence is valid once in the new physical generation"
	)
	var reused_repair := model.apply_component_repair(
		_repair_context(ENGINE_ID, 5.0, 2, 1)
	)
	_check(
		bool(reused_repair.accepted)
			and is_equal_approx(float(reused_repair.current_health), 95.0)
			and model.get_last_operation_sequence() == 1,
		"the new generation composes damage then repair in one fresh operation order"
	)
	var before_duplicate_reset := model.get_snapshot()
	var duplicate_reset := model.reset_for_reuse(1)
	_check(
		not bool(duplicate_reset.accepted)
			and duplicate_reset.reason == &"stale_generation"
			and model.get_snapshot() == before_duplicate_reset,
		"a duplicate reset from the prior generation is rejected without restoring twice"
	)

	var exhausted := _make_model()
	exhausted.set("_generation", ComponentDamageModelType.MAX_SAFE_INTEGER)
	var before_exhaustion := exhausted.get_snapshot()
	var exhaustion := exhausted.reset_for_reuse(ComponentDamageModelType.MAX_SAFE_INTEGER)
	_check(
		not bool(exhaustion.accepted)
			and exhaustion.reason == &"generation_exhausted"
			and exhausted.get_snapshot() == before_exhaustion,
		"generation exhaustion fails closed without wrap or partial reset"
	)


func _test_configuration_validation() -> void:
	_expect_invalid([], "component count", "an empty component roster is invalid")

	var bad_id := VALID_DEFINITIONS.duplicate(true)
	bad_id[0]["component_id"] = &"Engine-Core"
	_expect_invalid(bad_id, "component_id", "malformed component IDs are rejected")

	var duplicate_id := VALID_DEFINITIONS.duplicate(true)
	duplicate_id.append((duplicate_id[0] as Dictionary).duplicate(true))
	_expect_invalid(duplicate_id, "unique", "duplicate component IDs are rejected")

	for invalid_health in [0.0, -1.0, NAN, INF, ComponentDamageModelType.MAXIMUM_HEALTH + 1.0]:
		var bad_health := VALID_DEFINITIONS.duplicate(true)
		bad_health[0]["maximum_health"] = invalid_health
		_expect_invalid(
			bad_health,
			"maximum_health",
			"maximum health rejects zero, negative, non-finite, and over-bound values"
		)

	var unknown_component_field := VALID_DEFINITIONS.duplicate(true)
	unknown_component_field[0]["repair_rate"] = 1.0
	_expect_invalid(
		unknown_component_field,
		"contain exactly",
		"component definitions reject unknown repair-like fields"
	)

	var no_stages := VALID_DEFINITIONS.duplicate(true)
	no_stages[0]["damage_stages"] = []
	_expect_invalid(no_stages, "stage count", "every component requires bounded stages")

	var bad_first := VALID_DEFINITIONS.duplicate(true)
	((bad_first[0].damage_stages as Array)[0] as Dictionary)["health_ratio_at_or_below"] = 0.9
	_expect_invalid(bad_first, "first stage threshold", "stage coverage must begin at exact health ratio 1.0")

	var bad_last := VALID_DEFINITIONS.duplicate(true)
	((bad_last[0].damage_stages as Array)[3] as Dictionary)["health_ratio_at_or_below"] = 0.1
	_expect_invalid(bad_last, "final stage threshold", "stage coverage must end at exact health ratio 0.0")

	var unordered := VALID_DEFINITIONS.duplicate(true)
	((unordered[0].damage_stages as Array)[2] as Dictionary)["health_ratio_at_or_below"] = 0.8
	_expect_invalid(unordered, "strictly descending", "damage thresholds must remain strictly ordered")

	var duplicate_stage := VALID_DEFINITIONS.duplicate(true)
	((duplicate_stage[0].damage_stages as Array)[1] as Dictionary)["stage_id"] = &"nominal"
	_expect_invalid(duplicate_stage, "stage IDs", "stage IDs are unique within each component")

	var leading_digit_stage := VALID_DEFINITIONS.duplicate(true)
	((leading_digit_stage[0].damage_stages as Array)[1] as Dictionary)["stage_id"] = &"1_damaged"
	_expect_invalid(
		leading_digit_stage,
		"stage_id",
		"stage IDs cannot begin with a digit"
	)

	var disabled_output := VALID_DEFINITIONS.duplicate(true)
	((disabled_output[0].damage_stages as Array)[3] as Dictionary)["performance_multiplier"] = 0.1
	_expect_invalid(disabled_output, "disabled stages", "disabled stages require zero performance")

	var enabled_zero := VALID_DEFINITIONS.duplicate(true)
	((enabled_zero[0].damage_stages as Array)[2] as Dictionary)["performance_multiplier"] = 0.0
	_expect_invalid(enabled_zero, "enabled stages", "enabled stages require positive performance")

	var improved_damage := VALID_DEFINITIONS.duplicate(true)
	((improved_damage[0].damage_stages as Array)[2] as Dictionary)["performance_multiplier"] = 0.9
	_expect_invalid(
		improved_damage,
		"non-increasing",
		"a later damage stage cannot improve performance"
	)

	var reenabled := VALID_DEFINITIONS.duplicate(true)
	((reenabled[0].damage_stages as Array)[2] as Dictionary)["disabled"] = true
	((reenabled[0].damage_stages as Array)[2] as Dictionary)["performance_multiplier"] = 0.0
	((reenabled[0].damage_stages as Array)[3] as Dictionary)["disabled"] = false
	((reenabled[0].damage_stages as Array)[3] as Dictionary)["performance_multiplier"] = 0.1
	_expect_invalid(reenabled, "re-enable", "a later stage cannot re-enable a failed component")

	var unknown_stage_field := VALID_DEFINITIONS.duplicate(true)
	((unknown_stage_field[0].damage_stages as Array)[1] as Dictionary)["smoke"] = true
	_expect_invalid(
		unknown_stage_field,
		"contain exactly",
		"stages reject invented presentation consequence fields"
	)


func _test_detached_snapshots_and_audit() -> void:
	var model := _make_model()
	model.reset_for_reuse(0)
	model.apply_component_damage(_damage_context(ENGINE_ID, 30.0, 1, 0))
	model.apply_component_repair(_repair_context(ENGINE_ID, 5.0, 1, 1))
	var first := model.get_snapshot()
	var second := model.get_snapshot()
	_check(first == second, "unchanged model state produces deterministic equal snapshots")

	var components := first.get("components", []) as Array
	components[0]["current_health"] = -500.0
	(components[0].stage as Dictionary)["disabled"] = true
	(first.get("component_order", []) as Array).clear()
	(first.get("authority", {}) as Dictionary)["gameplay"] = true
	(first.get("evidence", {}) as Dictionary)["status"] = &"authenticated"
	var fresh := model.get_snapshot()
	var fresh_components := fresh.get("components", []) as Array
	_check(
		is_equal_approx(float(fresh_components[0].current_health), 75.0)
			and not bool((fresh_components[0].stage as Dictionary).disabled),
		"nested component and stage snapshots are detached"
	)
	_check(
		(fresh.get("component_order", []) as Array).size() == 2
			and int(fresh.get("last_operation_sequence", -1)) == 1
			and int(fresh.get("last_damage_sequence", -1)) == 1
			and not bool((fresh.get("authority", {}) as Dictionary).gameplay)
			and (fresh.get("evidence", {}) as Dictionary).status == &"new",
		"order, authority, and evidence snapshots are detached"
	)
	_check(
		model.get_component_state(&"unknown_component").is_empty(),
		"unknown component state lookup returns no invented state"
	)

	var audit := model.get_audit_report()
	_check(
		_has_exact_keys(audit, AUDIT_KEYS)
			and int(audit.schema_version) == MODEL_SCHEMA_VERSION
			and bool(audit.valid)
			and (audit.get("configuration_errors", PackedStringArray()) as PackedStringArray).is_empty()
			and (audit.get("state", {}) as Dictionary) == fresh,
		"the exact versioned audit roster deterministically combines definition and state"
	)
	(audit.get("definition", {}) as Dictionary).clear()
	(audit.get("state", {}) as Dictionary).clear()
	_check(
		not (model.get_audit_report().get("definition", {}) as Dictionary).is_empty()
			and not (model.get_audit_report().get("state", {}) as Dictionary).is_empty(),
		"audit definition and state dictionaries are deeply detached"
	)


func _test_zero_authority_boundary() -> void:
	var model := _make_model()
	var authority := model.get_authority_report()
	var exact_keys := true
	var all_false := authority.size() == AUTHORITY_KEYS.size()
	for key in AUTHORITY_KEYS:
		exact_keys = exact_keys and authority.has(key)
		all_false = all_false and not bool(authority.get(key, true))
	_check(
		exact_keys and all_false,
		"ComponentDamageModel owns exactly zero common renderer, gameplay, streaming, save, network, physics, generation, origin, clock, or audio authority"
	)
	var evidence := model.get_evidence_report()
	_check(
		evidence.content_class == &"NEW"
			and evidence.status == &"new"
			and evidence.scope == &"component_damage_model"
			and (evidence.references as PackedStringArray).is_empty()
			and str(evidence.notes).contains("not recovered historical"),
		"the foundation is explicit NEW evidence without invented source references"
	)
	var object_variant: Variant = model
	_check(
			not object_variant is Node
				and model.has_method("apply_component_repair")
				and model.has_method("apply_component_damage_batch")
				and model.has_method("apply_component_repair_batch")
			and not model.has_method("authorize_repair")
			and not model.has_method("tick_repair")
			and not model.has_method("apply_shield_damage")
			and not model.has_method("spawn_debris"),
		"the standalone repair mutation grants no scene, authorization, ticking, shield, or debris lifecycle"
	)


func _make_model() -> ComponentDamageModel:
	return ComponentDamageModelType.new(VALID_DEFINITIONS.duplicate(true)) as ComponentDamageModel


func _damage_context(
	component_id: StringName,
	damage: float,
	generation: int,
	sequence: int
	) -> Dictionary:
	return {
		"component_id": component_id,
		"damage": damage,
		"generation": generation,
		"sequence": sequence,
	}


func _repair_context(
	component_id: StringName,
	repair: float,
	generation: int,
	sequence: int
	) -> Dictionary:
	return {
		"component_id": component_id,
		"repair": repair,
		"generation": generation,
		"sequence": sequence,
	}


func _check_rejection_atomic(
	model: ComponentDamageModel,
	context: Dictionary,
	expected_reason: StringName,
	description: String
	) -> void:
	var before := model.get_snapshot()
	var result := model.apply_component_damage(context)
	_check(
		not bool(result.accepted)
			and result.reason == expected_reason
			and model.get_snapshot() == before,
		description
	)


func _check_repair_rejection_atomic(
	model: ComponentDamageModel,
	context: Dictionary,
	expected_reason: StringName,
	description: String
	) -> void:
	var before := model.get_snapshot()
	var result := model.apply_component_repair(context)
	_check(
		not bool(result.accepted)
			and result.reason == expected_reason
			and model.get_snapshot() == before,
		description
	)


func _check_damage_batch_rejection_atomic(
	model: ComponentDamageModel,
	contexts: Array,
	expected_reason: StringName,
	description: String
	) -> void:
	var before := model.get_snapshot()
	var result := model.apply_component_damage_batch(contexts)
	_check(
		not bool(result.accepted)
			and result.reason == expected_reason
			and _has_exact_keys(result, REJECTION_RESULT_KEYS)
			and model.get_snapshot() == before,
		description
	)


func _check_repair_batch_rejection_atomic(
	model: ComponentDamageModel,
	contexts: Array,
	expected_reason: StringName,
	description: String
	) -> void:
	var before := model.get_snapshot()
	var result := model.apply_component_repair_batch(contexts)
	_check(
		not bool(result.accepted)
			and result.reason == expected_reason
			and _has_exact_keys(result, REJECTION_RESULT_KEYS)
			and model.get_snapshot() == before,
		description
	)


func _expect_invalid(definitions: Array, fragment: String, description: String) -> void:
	var model := ComponentDamageModelType.new(definitions) as ComponentDamageModel
	var errors := model.get_configuration_errors()
	_check(
		not model.is_configuration_valid() and _has_error(errors, fragment),
		description
	)
	var before := model.get_snapshot()
	var rejected := model.reset_for_reuse(0)
	_check(
		not bool(rejected.accepted)
			and rejected.reason == &"invalid_configuration"
			and model.get_snapshot() == before,
		"invalid configuration cannot enter a live generation"
	)


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _has_exact_keys(dictionary: Dictionary, expected_keys: Array) -> bool:
	if dictionary.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not dictionary.has(key) and not dictionary.has(StringName(key)):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPONENT_DAMAGE_MODEL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("COMPONENT_DAMAGE_MODEL_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
