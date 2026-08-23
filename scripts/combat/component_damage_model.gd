class_name ComponentDamageModel
extends RefCounted

## Strict, generation-scoped component-health contract.
##
## This model snapshots authored component definitions, owns only its detached
## component-health ledger, and exposes data-only stage consequences. It does
## not resolve combat, mutate a ship, enforce a consequence, authorize or time
## repairs, create debris, present effects, or participate in any scene-tree
## lifecycle.

signal component_damage_applied(result: Dictionary)
signal component_repair_applied(result: Dictionary)
signal component_stage_changed(result: Dictionary)
signal model_reset(result: Dictionary)

const SCHEMA_VERSION := 3
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_COMPONENTS := 64
const MAX_STAGES_PER_COMPONENT := 16
const MAXIMUM_HEALTH := 1_000_000_000.0
const MAX_PERFORMANCE_MULTIPLIER := 1.0

const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"new"
const EVIDENCE_SCOPE: StringName = &"component_damage_model"
const EVIDENCE_NOTES := (
	"New gameplay contract; component rosters, health, thresholds, and consequences "
	+ "are not recovered historical specifications."
)

const _COMPONENT_KEYS := ["component_id", "maximum_health", "damage_stages"]
const _STAGE_KEYS := [
	"stage_id",
	"health_ratio_at_or_below",
	"disabled",
	"performance_multiplier",
]
const _DAMAGE_CONTEXT_KEYS := ["component_id", "damage", "generation", "sequence"]
const _REPAIR_CONTEXT_KEYS := ["component_id", "repair", "generation", "sequence"]

var _definitions: Array[Dictionary] = []
var _configuration_errors := PackedStringArray()
var _components: Dictionary = {}
var _component_order: Array[StringName] = []
var _generation := 0
var _revision := 0
## Damage and repair share one total order inside a generation. The compatibility
## damage getter/snapshot key below deliberately expose this same cursor: before
## repair existed it was the damage sequence, and damage-only consumers retain
## exactly that behavior.
var _last_operation_sequence := -1
## Public mutations and their synchronous signal dispatch form one indivisible
## boundary. Signal callbacks may inspect detached state but cannot nest a
## reset, damage, or repair commit ahead of the outer operation's final signal.
var _mutation_dispatch_active := false


func _init(component_definitions: Array = []) -> void:
	_capture_definitions(component_definitions)
	_validate_configuration()
	_configuration_errors.sort()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_generation() -> int:
	return _generation


func get_revision() -> int:
	return _revision


func get_last_operation_sequence() -> int:
	return _last_operation_sequence


## Compatibility alias for the original damage-only contract. Once repair is
## used this is the shared damage-or-repair operation high-water mark.
func get_last_damage_sequence() -> int:
	return _last_operation_sequence


## Starts the first generation or restores every component for reuse.
##
## The caller supplies the generation it currently observes. An accepted reset
## advances exactly once. Duplicate, stale, and exhausted requests are rejected
## without changing health, sequence history, revision, or signals.
func reset_for_reuse(expected_generation: int) -> Dictionary:
	if _mutation_dispatch_active:
		return _result(false, &"reentrant_call")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if _generation >= MAX_SAFE_INTEGER:
		return _result(false, &"generation_exhausted")

	_mutation_dispatch_active = true
	_generation += 1
	_revision += 1
	_last_operation_sequence = -1
	_components.clear()
	_component_order.clear()
	for definition in _definitions:
		var component_id := StringName(definition.get("component_id", &""))
		var maximum_health := float(definition.get("maximum_health", 0.0))
		var stages := (definition.get("damage_stages", []) as Array).duplicate(true)
		var stage_index := _stage_index_for_health(maximum_health, maximum_health, stages)
		_components[component_id] = {
			"component_id": component_id,
			"maximum_health": maximum_health,
			"current_health": maximum_health,
			"damage_stages": stages,
			"stage_index": stage_index,
		}
		_component_order.append(component_id)
	var result := _result(true, &"reset")
	result["component_count"] = _component_order.size()
	model_reset.emit(result.duplicate(true))
	_mutation_dispatch_active = false
	return result


## Applies one generation- and sequence-bound component damage event.
##
## The exact context is `{component_id, damage, generation, sequence}`. Damage
## sequences are global within one model generation, begin at zero, may skip,
## and must increase monotonically. Rejections are atomic and never consume a
## sequence or emit a signal.
func apply_component_damage(context: Dictionary) -> Dictionary:
	var batch_result := apply_component_damage_batch([context])
	if not bool(batch_result.get("accepted", false)):
		return batch_result
	return ((batch_result.get("operations", []) as Array)[0] as Dictionary).duplicate(true)


## Atomically applies an ordered, homogeneous component-damage batch.
##
## Every entry uses the scalar damage context. Component IDs must be distinct,
## and operation sequences must be a contiguous signed-safe range in captured
## input order. The complete batch is planned before any mutation. One accepted
## batch advances revision once and returns one detached aggregate receipt;
## existing stage and damage signals are still emitted once per operation.
func apply_component_damage_batch(contexts: Array) -> Dictionary:
	return _apply_component_batch(contexts, &"damage")


## Applies one caller-authorized component repair in the generation's shared
## operation order.
##
## The exact context is `{component_id, repair, generation, sequence}`. This
## object does not decide when repair is allowed or how much a caller should
## request. Rejections are atomic and never consume the shared operation
## sequence or emit a signal.
func apply_component_repair(context: Dictionary) -> Dictionary:
	var batch_result := apply_component_repair_batch([context])
	if not bool(batch_result.get("accepted", false)):
		return batch_result
	return ((batch_result.get("operations", []) as Array)[0] as Dictionary).duplicate(true)


## Atomically applies an ordered, homogeneous component-repair batch.
##
## This has the same roster, generation, contiguous-sequence, planning, receipt,
## revision, and dispatch guarantees as the damage batch. The model still does
## not authorize repair or choose an amount or rate.
func apply_component_repair_batch(contexts: Array) -> Dictionary:
	return _apply_component_batch(contexts, &"repair")


func _apply_component_batch(contexts: Array, operation_kind: StringName) -> Dictionary:
	if _mutation_dispatch_active:
		return _result(false, &"reentrant_call")
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if _generation <= 0:
		return _result(false, &"inactive")
	if contexts.is_empty() or contexts.size() > MAX_COMPONENTS:
		return _result(false, &"invalid_batch")

	var plans: Array[Dictionary] = []
	var seen_components: Dictionary = {}
	var seen_sequences: Dictionary = {}
	var first_sequence := -1
	for index in contexts.size():
		var raw_context: Variant = contexts[index]
		if not raw_context is Dictionary:
			return _result(false, &"invalid_batch")
		var context := raw_context as Dictionary
		var gate := (
			_damage_rejection(context)
			if operation_kind == &"damage"
			else _repair_rejection(context)
		)
		if not gate.is_empty():
			return _result(false, gate)

		var sequence := int(_field(context, "sequence", -1))
		if index == 0:
			first_sequence = sequence
			if first_sequence > MAX_SAFE_INTEGER - (contexts.size() - 1):
				return _result(false, &"sequence_exhausted")
		elif sequence != first_sequence + index:
			if seen_sequences.has(sequence):
				return _result(false, &"duplicate_sequence")
			if sequence < first_sequence + index:
				return _result(false, &"stale_sequence")
			return _result(false, &"invalid_sequence")
		seen_sequences[sequence] = true

		var component_id := StringName(_field(context, "component_id", &""))
		if seen_components.has(component_id):
			return _result(false, &"duplicate_component")
		seen_components[component_id] = true
		var plan := _plan_component_operation(context, operation_kind)
		if not bool(plan.get("accepted", false)):
			return _result(false, StringName(plan.get("reason", &"no_component_effect")))
		plans.append(plan)

	var last_sequence := first_sequence + plans.size() - 1
	var next_revision := _revision + 1
	var operation_results: Array[Dictionary] = []
	for plan in plans:
		operation_results.append(
			_operation_result(plan, operation_kind, _generation, next_revision)
		)
	var result := {
		"accepted": true,
		"reason": &"applied_batch" if operation_kind == &"damage" else &"repaired_batch",
		"generation": _generation,
		"sequence": last_sequence,
		"revision": next_revision,
		"operation_kind": operation_kind,
		"operation_count": operation_results.size(),
		"first_sequence": first_sequence,
		"last_sequence": last_sequence,
		"operations": operation_results.duplicate(true),
	}

	_mutation_dispatch_active = true
	for plan in plans:
		var component_id := StringName(plan.get("component_id", &""))
		var component := _components[component_id] as Dictionary
		component["current_health"] = float(plan.get("current_health", 0.0))
		component["stage_index"] = int(plan.get("next_stage_index", -1))
	_last_operation_sequence = last_sequence
	_revision = next_revision

	for operation_result in operation_results:
		if bool(operation_result.get("stage_changed", false)):
			component_stage_changed.emit(operation_result.duplicate(true))
		if operation_kind == &"damage":
			component_damage_applied.emit(operation_result.duplicate(true))
		else:
			component_repair_applied.emit(operation_result.duplicate(true))
	_mutation_dispatch_active = false
	return result.duplicate(true)


func _plan_component_operation(context: Dictionary, operation_kind: StringName) -> Dictionary:
	var component_id := StringName(_field(context, "component_id", &""))
	var component := _components[component_id] as Dictionary
	var before_health := float(component.get("current_health", 0.0))
	var maximum_health := float(component.get("maximum_health", 0.0))
	var requested_amount := float(
		_field(context, "damage" if operation_kind == &"damage" else "repair", 0.0)
	)
	var after_health := before_health
	var applied_amount := 0.0
	if operation_kind == &"damage":
		if before_health <= 0.0:
			return {"accepted": false, "reason": &"no_component_effect"}
		after_health = maxf(before_health - requested_amount, 0.0)
		if not after_health < before_health:
			return {"accepted": false, "reason": &"no_component_effect"}
		applied_amount = before_health - after_health
	else:
		if before_health >= maximum_health:
			return {"accepted": false, "reason": &"no_component_effect"}
		var remaining_health := maximum_health - before_health
		applied_amount = minf(requested_amount, remaining_health)
		after_health = before_health + applied_amount
		if applied_amount == remaining_health:
			after_health = maximum_health
		if not after_health > before_health:
			return {"accepted": false, "reason": &"no_component_effect"}

	var stages := component.get("damage_stages", []) as Array
	return {
		"accepted": true,
		"component_id": component_id,
		"sequence": int(_field(context, "sequence", -1)),
		"requested_amount": requested_amount,
		"applied_amount": applied_amount,
		"previous_health": before_health,
		"current_health": after_health,
		"maximum_health": maximum_health,
		"stages": stages,
		"prior_stage_index": int(component.get("stage_index", -1)),
		"next_stage_index": _stage_index_for_health(after_health, maximum_health, stages),
	}


func _operation_result(
	plan: Dictionary,
	operation_kind: StringName,
	generation: int,
	revision: int
	) -> Dictionary:
	var result := {
		"accepted": true,
		"reason": &"applied" if operation_kind == &"damage" else &"repaired",
		"generation": generation,
		"sequence": int(plan.get("sequence", -1)),
		"revision": revision,
		"component_id": StringName(plan.get("component_id", &"")),
	}
	if operation_kind == &"damage":
		result["requested_damage"] = float(plan.get("requested_amount", 0.0))
		result["applied_damage"] = float(plan.get("applied_amount", 0.0))
	else:
		result["requested_repair"] = float(plan.get("requested_amount", 0.0))
		result["applied_repair"] = float(plan.get("applied_amount", 0.0))
	result["previous_health"] = float(plan.get("previous_health", 0.0))
	result["current_health"] = float(plan.get("current_health", 0.0))
	result["maximum_health"] = float(plan.get("maximum_health", 0.0))
	result["stage"] = _stage_snapshot(
		plan.get("stages", []) as Array,
		int(plan.get("next_stage_index", -1))
	)
	result["stage_changed"] = (
		int(plan.get("next_stage_index", -1)) != int(plan.get("prior_stage_index", -1))
	)
	return result


func get_component_state(component_id: StringName) -> Dictionary:
	var component: Dictionary = _components.get(component_id, {})
	if component.is_empty():
		return {}
	var maximum_health := float(component.get("maximum_health", 0.0))
	var current_health := float(component.get("current_health", 0.0))
	var stages := component.get("damage_stages", []) as Array
	return {
		"component_id": component_id,
		"maximum_health": maximum_health,
		"current_health": current_health,
		"health_ratio": current_health / maximum_health,
		"stage": _stage_snapshot(stages, int(component.get("stage_index", -1))),
	}.duplicate(true)


func get_component_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for component_id in _component_order:
		states.append(get_component_state(component_id))
	return states


## Returns bounded, data-only runtime consequences for caller-designated engine,
## weapon, and sensor components. The caller retains movement, fire, targeting,
## and component-role authority; this model only translates its resolved stages
## into detached multipliers that those authorities may consume.
##
## An inactive model or an unknown binding returns an empty dictionary rather
## than inventing operational state. Valid multipliers are always finite 0..1,
## with the matching disabled flag copied from the resolved component stage.
func get_operational_modifiers(
		engine_component_id: StringName,
		weapon_component_id: StringName,
		sensor_component_id: StringName
	) -> Dictionary:
	if _generation <= 0:
		return {}
	for component_id in [engine_component_id, weapon_component_id, sensor_component_id]:
		if not _components.has(component_id):
			return {}
	var engine_stage := _resolved_stage(engine_component_id)
	var weapon_stage := _resolved_stage(weapon_component_id)
	var sensor_stage := _resolved_stage(sensor_component_id)
	return {
		"generation": _generation,
		"revision": _revision,
		"mobility_multiplier": _stage_multiplier(engine_stage),
		"fire_multiplier": _stage_multiplier(weapon_stage),
		"targeting_multiplier": _stage_multiplier(sensor_stage),
		"mobility_disabled": bool(engine_stage.get("disabled", false)),
		"fire_disabled": bool(weapon_stage.get("disabled", false)),
		"targeting_disabled": bool(sensor_stage.get("disabled", false)),
		"component_bindings": {
			"engine": engine_component_id,
			"weapon": weapon_component_id,
			"sensor": sensor_component_id,
		},
	}.duplicate(true)


func get_definition_snapshot() -> Dictionary:
	var components: Array[Dictionary] = []
	for definition in _definitions:
		components.append(definition.duplicate(true))
	return {
		"schema_version": SCHEMA_VERSION,
		"components": components,
		"evidence": get_evidence_report(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generation": _generation,
		"revision": _revision,
		"last_operation_sequence": _last_operation_sequence,
		"last_damage_sequence": _last_operation_sequence,
		"active": _generation > 0,
		"component_order": _component_order.duplicate(),
		"components": get_component_states(),
		"evidence": get_evidence_report(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_evidence_report() -> Dictionary:
	return {
		"content_class": CONTENT_CLASS,
		"status": EVIDENCE_STATUS,
		"scope": EVIDENCE_SCOPE,
		"references": PackedStringArray(),
		"notes": EVIDENCE_NOTES,
	}.duplicate(true)


## The exact common authority core. All authority remains with future adapters
## and their existing runtime owners; this detached model enforces no outcome.
func get_authority_report() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": is_configuration_valid(),
		"configuration_errors": get_configuration_errors(),
		"definition": get_definition_snapshot(),
		"state": get_snapshot(),
		"evidence": get_evidence_report(),
		"authority": get_authority_report(),
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit()


func _capture_definitions(component_definitions: Array) -> void:
	if component_definitions.is_empty() or component_definitions.size() > MAX_COMPONENTS:
		_configuration_errors.append(
			"component count must be within 1..%d" % MAX_COMPONENTS
		)
	for raw_definition in component_definitions:
		if not raw_definition is Dictionary:
			_configuration_errors.append("component definitions must be dictionaries")
			continue
		var definition := raw_definition as Dictionary
		if not _has_exact_keys(definition, _COMPONENT_KEYS):
			_configuration_errors.append(
				"component definitions must contain exactly component_id, maximum_health, and damage_stages"
			)
		var component_id := _canonical_id(_field(definition, "component_id", null))
		var raw_maximum_health: Variant = _field(definition, "maximum_health", NAN)
		var maximum_health := (
			float(raw_maximum_health)
			if raw_maximum_health is int or raw_maximum_health is float
			else NAN
		)
		var stages: Array[Dictionary] = []
		var raw_stages: Variant = _field(definition, "damage_stages", [])
		if raw_stages is Array:
			for raw_stage in raw_stages as Array:
				if not raw_stage is Dictionary:
					_configuration_errors.append("damage stages must be dictionaries")
					continue
				stages.append(_capture_stage(raw_stage as Dictionary))
		else:
			_configuration_errors.append("damage_stages must be an Array")
		_definitions.append({
			"component_id": component_id,
			"maximum_health": maximum_health,
			"damage_stages": stages,
		})


func _capture_stage(stage: Dictionary) -> Dictionary:
	if not _has_exact_keys(stage, _STAGE_KEYS):
		_configuration_errors.append(
			"damage stages must contain exactly stage_id, health_ratio_at_or_below, disabled, and performance_multiplier"
		)
	var raw_threshold: Variant = _field(stage, "health_ratio_at_or_below", NAN)
	var raw_multiplier: Variant = _field(stage, "performance_multiplier", NAN)
	var raw_disabled: Variant = _field(stage, "disabled", null)
	if not raw_disabled is bool:
		_configuration_errors.append("stage disabled consequence must be boolean")
	return {
		"stage_id": _canonical_id(_field(stage, "stage_id", null)),
		"health_ratio_at_or_below": (
			float(raw_threshold) if raw_threshold is int or raw_threshold is float else NAN
		),
		"disabled": bool(raw_disabled) if raw_disabled is bool else false,
		"performance_multiplier": (
			float(raw_multiplier) if raw_multiplier is int or raw_multiplier is float else NAN
		),
	}


func _validate_configuration() -> void:
	var component_ids: Dictionary = {}
	for definition in _definitions:
		var component_id := StringName(definition.get("component_id", &""))
		if not is_stable_id(component_id):
			_configuration_errors.append("component_id must be a stable lowercase identifier")
		elif component_ids.has(component_id):
			_configuration_errors.append("component IDs must be unique")
		else:
			component_ids[component_id] = true
		var maximum_health := float(definition.get("maximum_health", NAN))
		if (
			not is_finite(maximum_health)
			or maximum_health <= 0.0
			or maximum_health > MAXIMUM_HEALTH
		):
			_configuration_errors.append("maximum_health is outside its finite positive bound")
		_validate_stages(definition.get("damage_stages", []) as Array)


func _validate_stages(stages: Array) -> void:
	if stages.is_empty() or stages.size() > MAX_STAGES_PER_COMPONENT:
		_configuration_errors.append(
			"damage stage count must be within 1..%d" % MAX_STAGES_PER_COMPONENT
		)
		return
	var stage_ids: Dictionary = {}
	var previous_threshold := INF
	var previous_multiplier := INF
	var disabled_seen := false
	for index in stages.size():
		var stage := stages[index] as Dictionary
		var stage_id := StringName(stage.get("stage_id", &""))
		if not is_stable_id(stage_id):
			_configuration_errors.append("stage_id must be a stable lowercase identifier")
		elif stage_ids.has(stage_id):
			_configuration_errors.append("stage IDs must be unique within a component")
		else:
			stage_ids[stage_id] = true
		var threshold := float(stage.get("health_ratio_at_or_below", NAN))
		if not is_finite(threshold) or threshold < 0.0 or threshold > 1.0:
			_configuration_errors.append("stage thresholds must be finite within 0..1")
		elif index > 0 and threshold >= previous_threshold:
			_configuration_errors.append("stage thresholds must be strictly descending")
		previous_threshold = threshold
		var disabled := bool(stage.get("disabled", false))
		var multiplier := float(stage.get("performance_multiplier", NAN))
		if (
			not is_finite(multiplier)
			or multiplier < 0.0
			or multiplier > MAX_PERFORMANCE_MULTIPLIER
		):
			_configuration_errors.append(
				"performance_multiplier must be finite within 0..1"
			)
		elif index > 0 and multiplier > previous_multiplier:
			_configuration_errors.append(
				"stage performance multipliers must be non-increasing"
			)
		previous_multiplier = multiplier
		if disabled and multiplier != 0.0:
			_configuration_errors.append("disabled stages require a zero performance multiplier")
		if not disabled and multiplier <= 0.0:
			_configuration_errors.append("enabled stages require a positive performance multiplier")
		if disabled_seen and not disabled:
			_configuration_errors.append("a later stage cannot re-enable a disabled component")
		disabled_seen = disabled_seen or disabled
	var first := stages.front() as Dictionary
	var last := stages.back() as Dictionary
	if float(first.get("health_ratio_at_or_below", NAN)) != 1.0:
		_configuration_errors.append("the first stage threshold must be exactly 1.0")
	if bool(first.get("disabled", true)) \
			or float(first.get("performance_multiplier", NAN)) != 1.0:
		_configuration_errors.append("the first stage must be enabled at exact performance 1.0")
	if float(last.get("health_ratio_at_or_below", NAN)) != 0.0:
		_configuration_errors.append("the final stage threshold must be exactly 0.0")


func _damage_rejection(context: Dictionary) -> StringName:
	var common := _operation_rejection(context, _DAMAGE_CONTEXT_KEYS)
	if not common.is_empty():
		return common
	var raw_damage: Variant = _field(context, "damage", null)
	if not raw_damage is int and not raw_damage is float:
		return &"invalid_damage"
	var damage := float(raw_damage)
	if not is_finite(damage) or damage <= 0.0:
		return &"invalid_damage"
	return &""


func _repair_rejection(context: Dictionary) -> StringName:
	var common := _operation_rejection(context, _REPAIR_CONTEXT_KEYS)
	if not common.is_empty():
		return common
	var raw_repair: Variant = _field(context, "repair", null)
	if not raw_repair is int and not raw_repair is float:
		return &"invalid_repair"
	var repair := float(raw_repair)
	if not is_finite(repair) or repair <= 0.0:
		return &"invalid_repair"
	return &""


func _operation_rejection(context: Dictionary, exact_keys: Array) -> StringName:
	if not is_configuration_valid():
		return &"invalid_configuration"
	if _generation <= 0:
		return &"inactive"
	if not _has_exact_keys(context, exact_keys):
		return &"invalid_context"
	var raw_generation: Variant = _field(context, "generation", null)
	if not raw_generation is int or int(raw_generation) != _generation:
		return &"stale_generation"
	var raw_sequence: Variant = _field(context, "sequence", null)
	if not raw_sequence is int or int(raw_sequence) < 0:
		return &"invalid_sequence"
	var sequence := int(raw_sequence)
	if sequence == _last_operation_sequence:
		return &"duplicate_sequence"
	if sequence < _last_operation_sequence:
		return &"stale_sequence"
	if _last_operation_sequence >= MAX_SAFE_INTEGER:
		return &"sequence_exhausted"
	if sequence > MAX_SAFE_INTEGER:
		return &"invalid_sequence"
	var raw_component_id: Variant = _field(context, "component_id", null)
	if not raw_component_id is String and not raw_component_id is StringName:
		return &"invalid_component_id"
	var component_id := StringName(raw_component_id)
	if not is_stable_id(component_id):
		return &"invalid_component_id"
	if not _components.has(component_id):
		return &"unknown_component"
	return &""


func _stage_index_for_health(current_health: float, maximum_health: float, stages: Array) -> int:
	var ratio := clampf(current_health / maximum_health, 0.0, 1.0)
	var selected := 0
	for index in stages.size():
		var threshold := float((stages[index] as Dictionary).get("health_ratio_at_or_below", 0.0))
		if ratio <= threshold:
			selected = index
		else:
			break
	return selected


func _stage_snapshot(stages: Array, stage_index: int) -> Dictionary:
	if stage_index < 0 or stage_index >= stages.size():
		return {}
	return (stages[stage_index] as Dictionary).duplicate(true)


func _resolved_stage(component_id: StringName) -> Dictionary:
	var component := _components[component_id] as Dictionary
	return _stage_snapshot(
		component.get("damage_stages", []) as Array,
		int(component.get("stage_index", -1))
	)


func _stage_multiplier(stage: Dictionary) -> float:
	return clampf(
		float(stage.get("performance_multiplier", 0.0)),
		0.0,
		MAX_PERFORMANCE_MULTIPLIER
	)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"sequence": _last_operation_sequence,
		"revision": _revision,
	}


static func is_stable_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	var first_code := text.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var lowercase := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lowercase and not digit and code != 95:
			return false
	if text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		return false
	return true


static func _canonical_id(value: Variant) -> StringName:
	return StringName(value) if value is String or value is StringName else &""


static func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	var normalized := PackedStringArray()
	for key in dictionary:
		if not key is String and not key is StringName:
			return false
		normalized.append(str(key))
	for expected_key in expected:
		if not normalized.has(str(expected_key)):
			return false
	return true


static func _field(dictionary: Dictionary, key: String, default_value: Variant) -> Variant:
	if dictionary.has(key):
		return dictionary[key]
	var named := StringName(key)
	return dictionary[named] if dictionary.has(named) else default_value
