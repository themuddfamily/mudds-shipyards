extends SceneTree

const ComponentDamageModelType := preload(
	"res://scripts/combat/component_damage_model.gd"
)

const ENGINE_ID: StringName = &"engine_core"
const WEAPON_ID: StringName = &"pulse_mount"
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
	_test_atomic_rejections()
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
		is_equal_approx(float(engine.maximum_health), 100.0)
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
	var reused_sequence := model.apply_component_damage(
		_damage_context(ENGINE_ID, 10.0, 2, 0)
	)
	_check(
		bool(reused_sequence.accepted)
			and is_equal_approx(float(reused_sequence.current_health), 90.0),
		"the same numeric sequence is valid once in the new physical generation"
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
		is_equal_approx(float(fresh_components[0].current_health), 70.0)
			and not bool((fresh_components[0].stage as Dictionary).disabled),
		"nested component and stage snapshots are detached"
	)
	_check(
		(fresh.get("component_order", []) as Array).size() == 2
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
		bool(audit.valid)
			and (audit.get("configuration_errors", PackedStringArray()) as PackedStringArray).is_empty()
			and (audit.get("state", {}) as Dictionary) == fresh,
		"the audit deterministically combines definition validation and current state"
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
			and not model.has_method("repair")
			and not model.has_method("apply_shield_damage")
			and not model.has_method("spawn_debris"),
		"the standalone contract has no scene, repair, shield, or debris lifecycle"
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
