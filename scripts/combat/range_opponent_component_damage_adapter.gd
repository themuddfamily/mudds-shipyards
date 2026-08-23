class_name RangeOpponentComponentDamageAdapter
extends RefCounted

## Production hull-ledger adapter for RangeOpponent.
##
## This object owns exactly one ComponentDamageModel and translates the
## opponent's synchronous activate/apply calls into its generation-scoped API.
## It does not own collision, activity, source registration, destruction,
## presentation, audio, score, or any scene-tree lifecycle.

const ComponentDamageModelType := preload(
	"res://scripts/combat/component_damage_model.gd"
)

const HULL_COMPONENT_ID: StringName = &"hull"
const ENGINE_COMPONENT_ID: StringName = &"engine"
const WEAPON_COMPONENT_ID: StringName = &"weapon"
const SENSOR_COMPONENT_ID: StringName = &"sensor"
const STAGE_NOMINAL: StringName = &"nominal"
const STAGE_DAMAGED: StringName = &"damaged"
const STAGE_CRITICAL: StringName = &"critical"
const STAGE_DESTROYED: StringName = &"destroyed"

const DAMAGE_STAGES := [
	{
		"stage_id": STAGE_NOMINAL,
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_DAMAGED,
		"health_ratio_at_or_below": 0.67,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_CRITICAL,
		"health_ratio_at_or_below": 0.34,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_DESTROYED,
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]
const ENGINE_DAMAGE_STAGES := [
	{
		"stage_id": STAGE_NOMINAL,
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_DAMAGED,
		"health_ratio_at_or_below": 0.67,
		"disabled": false,
		"performance_multiplier": 0.72,
	},
	{
		"stage_id": STAGE_CRITICAL,
		"health_ratio_at_or_below": 0.34,
		"disabled": false,
		"performance_multiplier": 0.42,
	},
	{
		"stage_id": STAGE_DESTROYED,
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]
const WEAPON_DAMAGE_STAGES := [
	{
		"stage_id": STAGE_NOMINAL,
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_DAMAGED,
		"health_ratio_at_or_below": 0.67,
		"disabled": false,
		"performance_multiplier": 0.78,
	},
	{
		"stage_id": STAGE_CRITICAL,
		"health_ratio_at_or_below": 0.34,
		"disabled": false,
		"performance_multiplier": 0.50,
	},
	{
		"stage_id": STAGE_DESTROYED,
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]
const SENSOR_DAMAGE_STAGES := [
	{
		"stage_id": STAGE_NOMINAL,
		"health_ratio_at_or_below": 1.0,
		"disabled": false,
		"performance_multiplier": 1.0,
	},
	{
		"stage_id": STAGE_DAMAGED,
		"health_ratio_at_or_below": 0.67,
		"disabled": false,
		"performance_multiplier": 0.82,
	},
	{
		"stage_id": STAGE_CRITICAL,
		"health_ratio_at_or_below": 0.34,
		"disabled": false,
		"performance_multiplier": 0.58,
	},
	{
		"stage_id": STAGE_DESTROYED,
		"health_ratio_at_or_below": 0.0,
		"disabled": true,
		"performance_multiplier": 0.0,
	},
]

var _captured_maximum_health := NAN
var _model: ComponentDamageModel
var _next_damage_sequence := 0


func _init(maximum_health: float) -> void:
	_captured_maximum_health = maximum_health
	_model = ComponentDamageModelType.new([
		_component_definition(HULL_COMPONENT_ID, maximum_health, DAMAGE_STAGES),
		_component_definition(ENGINE_COMPONENT_ID, maximum_health, ENGINE_DAMAGE_STAGES),
		_component_definition(WEAPON_COMPONENT_ID, maximum_health, WEAPON_DAMAGE_STAGES),
		_component_definition(SENSOR_COMPONENT_ID, maximum_health, SENSOR_DAMAGE_STAGES),
	]) as ComponentDamageModel


func is_configuration_valid() -> bool:
	return _model != null and _model.is_configuration_valid()


func get_configuration_errors() -> PackedStringArray:
	return (
		_model.get_configuration_errors()
		if _model != null
		else PackedStringArray(["component damage model is unavailable"])
	)


## The authored maximum is captured once. A later public-property mutation must
## never silently split the model health from RangeOpponent presentation or its
## LifecycleDamageableAdapter maximum-health report.
func configuration_matches(maximum_health: float) -> bool:
	return is_finite(maximum_health) and maximum_health == _captured_maximum_health


func reset_for_reuse(maximum_health: float) -> Dictionary:
	if not configuration_matches(maximum_health):
		return _adapter_result(false, &"maximum_health_drift")
	if not is_configuration_valid():
		return _adapter_result(false, &"invalid_configuration")
	var result := _model.reset_for_reuse(_model.get_generation())
	if bool(result.get("accepted", false)):
		_next_damage_sequence = 0
	return result.duplicate(true)


func apply_hull_damage(amount: float, maximum_health: float) -> Dictionary:
	if not configuration_matches(maximum_health):
		return _adapter_result(false, &"maximum_health_drift")
	if not is_configuration_valid():
		return _adapter_result(false, &"invalid_configuration")
	var contexts: Array[Dictionary] = []
	for component_id in [
		HULL_COMPONENT_ID,
		ENGINE_COMPONENT_ID,
		WEAPON_COMPONENT_ID,
		SENSOR_COMPONENT_ID,
	]:
		contexts.append({
			"component_id": component_id,
			"damage": amount,
			"generation": _model.get_generation(),
			"sequence": _next_damage_sequence + contexts.size(),
		})
	var batch := _model.apply_component_damage_batch(contexts)
	if not bool(batch.get("accepted", false)):
		return batch.duplicate(true)
	_next_damage_sequence += contexts.size()
	var operations := batch.get("operations", []) as Array
	return (operations[0] as Dictionary).duplicate(true)


func get_health() -> float:
	if _model == null:
		return 0.0
	return float(_model.get_component_state(HULL_COMPONENT_ID).get("current_health", 0.0))


func get_maximum_health() -> float:
	return _captured_maximum_health


func get_component_state() -> Dictionary:
	return (
		_model.get_component_state(HULL_COMPONENT_ID)
		if _model != null
		else {}
	)


func get_operational_modifiers() -> Dictionary:
	return (
		_model.get_operational_modifiers(
			ENGINE_COMPONENT_ID,
			WEAPON_COMPONENT_ID,
			SENSOR_COMPONENT_ID
		)
		if _model != null
		else {}
	)


func get_snapshot() -> Dictionary:
	return {
		"configuration_valid": is_configuration_valid(),
		"configuration_errors": get_configuration_errors(),
		"captured_maximum_health": _captured_maximum_health,
		"configuration_current": configuration_matches(_captured_maximum_health),
		"next_damage_sequence": _next_damage_sequence,
		"operational_modifiers": get_operational_modifiers(),
		"definition": _model.get_definition_snapshot() if _model != null else {},
		"model": _model.get_snapshot() if _model != null else {},
	}.duplicate(true)


static func _component_definition(
		component_id: StringName,
		maximum_health: float,
		stages: Array
	) -> Dictionary:
	return {
		"component_id": component_id,
		"maximum_health": maximum_health,
		"damage_stages": stages.duplicate(true),
	}


func _adapter_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _model.get_generation() if _model != null else 0,
		"sequence": _model.get_last_damage_sequence() if _model != null else -1,
		"revision": _model.get_revision() if _model != null else 0,
	}.duplicate(true)
