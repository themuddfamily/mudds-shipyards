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

const SCHEMA_VERSION := 2
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
	if _mutation_dispatch_active:
		return _result(false, &"reentrant_call")
	var gate := _damage_rejection(context)
	if not gate.is_empty():
		return _result(false, gate)

	var component_id := StringName(_field(context, "component_id", &""))
	var requested_damage := float(_field(context, "damage", 0.0))
	var sequence := int(_field(context, "sequence", -1))
	var component := _components[component_id] as Dictionary
	var before_health := float(component.get("current_health", 0.0))
	if before_health <= 0.0:
		return _result(false, &"no_component_effect")

	var after_health := maxf(before_health - requested_damage, 0.0)
	if not after_health < before_health:
		return _result(false, &"no_component_effect")
	var applied_damage := before_health - after_health
	var prior_stage_index := int(component.get("stage_index", -1))
	var stages := component.get("damage_stages", []) as Array
	var next_stage_index := _stage_index_for_health(
		after_health,
		float(component.get("maximum_health", 0.0)),
		stages
	)
	_mutation_dispatch_active = true
	component["current_health"] = after_health
	component["stage_index"] = next_stage_index
	_last_operation_sequence = sequence
	_revision += 1

	var result := _result(true, &"applied")
	result["component_id"] = component_id
	result["requested_damage"] = requested_damage
	result["applied_damage"] = applied_damage
	result["previous_health"] = before_health
	result["current_health"] = after_health
	result["maximum_health"] = float(component.get("maximum_health", 0.0))
	result["stage"] = _stage_snapshot(stages, next_stage_index)
	result["stage_changed"] = next_stage_index != prior_stage_index
	if bool(result.get("stage_changed", false)):
		component_stage_changed.emit(result.duplicate(true))
	component_damage_applied.emit(result.duplicate(true))
	_mutation_dispatch_active = false
	return result


## Applies one caller-authorized component repair in the generation's shared
## operation order.
##
## The exact context is `{component_id, repair, generation, sequence}`. This
## object does not decide when repair is allowed or how much a caller should
## request. Rejections are atomic and never consume the shared operation
## sequence or emit a signal.
func apply_component_repair(context: Dictionary) -> Dictionary:
	if _mutation_dispatch_active:
		return _result(false, &"reentrant_call")
	var gate := _repair_rejection(context)
	if not gate.is_empty():
		return _result(false, gate)

	var component_id := StringName(_field(context, "component_id", &""))
	var requested_repair := float(_field(context, "repair", 0.0))
	var sequence := int(_field(context, "sequence", -1))
	var component := _components[component_id] as Dictionary
	var before_health := float(component.get("current_health", 0.0))
	var maximum_health := float(component.get("maximum_health", 0.0))
	if before_health >= maximum_health:
		return _result(false, &"no_component_effect")

	var remaining_health := maximum_health - before_health
	var applied_repair := minf(requested_repair, remaining_health)
	var after_health := before_health + applied_repair
	if applied_repair == remaining_health:
		after_health = maximum_health
	if not after_health > before_health:
		return _result(false, &"no_component_effect")
	var prior_stage_index := int(component.get("stage_index", -1))
	var stages := component.get("damage_stages", []) as Array
	var next_stage_index := _stage_index_for_health(after_health, maximum_health, stages)
	_mutation_dispatch_active = true
	component["current_health"] = after_health
	component["stage_index"] = next_stage_index
	_last_operation_sequence = sequence
	_revision += 1

	var result := _result(true, &"repaired")
	result["component_id"] = component_id
	result["requested_repair"] = requested_repair
	result["applied_repair"] = applied_repair
	result["previous_health"] = before_health
	result["current_health"] = after_health
	result["maximum_health"] = maximum_health
	result["stage"] = _stage_snapshot(stages, next_stage_index)
	result["stage_changed"] = next_stage_index != prior_stage_index
	if bool(result.get("stage_changed", false)):
		component_stage_changed.emit(result.duplicate(true))
	component_repair_applied.emit(result.duplicate(true))
	_mutation_dispatch_active = false
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
