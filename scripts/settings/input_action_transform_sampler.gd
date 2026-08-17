class_name InputActionTransformSampler
extends RefCounted

## Production-neutral sampling adapter for InputActionTransformBank.
##
## Each explicit caller-physics tick reads `get_action_strength()` and
## `is_action_pressed()` exactly once for every bank action, then submits the
## complete roster through the bank's atomic frame API. A null injected provider
## selects Godot's production Input singleton.

const InputActionTransformBankType := preload("res://scripts/settings/input_action_transform_bank.gd")

const STRENGTH_METHOD := &"get_action_strength"
const PRESSED_METHOD := &"is_action_pressed"

var _bank: InputActionTransformBank
var _input_provider: Object
var _configuration_errors := PackedStringArray()


func _init(bank: InputActionTransformBank, input_provider: Object = null) -> void:
	_bank = bank
	_input_provider = input_provider
	if _bank == null or not is_instance_valid(_bank):
		_configuration_errors.append("missing_bank")
	elif not _bank.is_configuration_valid():
		_configuration_errors.append("invalid_bank")


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


## Samples a complete profile frame. Configuration, bank generation/lifecycle,
## and caller delta are checked before touching the provider. Provider outputs
## for the whole roster are collected before the bank is invoked, so a malformed
## value cannot partially mutate transform state. `prime_physical_state` retains
## the exact same one-read-per-action sampling but seeds boundary state without
## manufacturing logical toggle presses.
func sample_physics_frame(
		physics_delta: Variant,
		expected_generation: int,
		prime_physical_state: bool = false,
	) -> Dictionary:
	if not is_configuration_valid():
		return _frame_result(false, &"invalid_configuration", 0.0, {})
	if expected_generation != _bank.get_generation():
		return _frame_result(false, &"stale_generation", 0.0, {})
	var bank_snapshot := _bank.get_snapshot()
	if not bool(bank_snapshot.attached):
		return _frame_result(false, &"detached", 0.0, {})
	if not physics_delta is float and not physics_delta is int:
		return _frame_result(false, &"invalid_physics_delta", 0.0, {})
	var delta := float(physics_delta)
	if not _is_finite(delta) or delta < 0.0:
		return _frame_result(false, &"invalid_physics_delta", 0.0, {})

	var provider := _resolve_provider()
	if provider == null or not is_instance_valid(provider):
		return _frame_result(false, &"invalid_provider", delta, {})
	if not provider.has_method(STRENGTH_METHOD):
		return _frame_result(
			false,
			&"provider_missing_method",
			delta,
			{},
			{"failed_method": STRENGTH_METHOD},
		)
	if not provider.has_method(PRESSED_METHOD):
		return _frame_result(
			false,
			&"provider_missing_method",
			delta,
			{},
			{"failed_method": PRESSED_METHOD},
		)

	var raw_frame := {}
	var first_failure := {}
	for action_id: StringName in _bank.get_action_order():
		if not is_instance_valid(provider):
			return _frame_result(
				false,
				&"provider_failed",
				delta,
				{},
				{"failed_action": action_id},
			)
		var scalar_candidate: Variant = provider.call(STRENGTH_METHOD, action_id)
		if not is_instance_valid(provider):
			return _frame_result(
				false,
				&"provider_failed",
				delta,
				{},
				{"failed_action": action_id, "failed_method": STRENGTH_METHOD},
			)
		var pressed_candidate: Variant = provider.call(PRESSED_METHOD, action_id)
		if first_failure.is_empty():
			if not scalar_candidate is float and not scalar_candidate is int:
				first_failure = {
					"reason": &"malformed_provider_sample",
					"failed_action": action_id,
					"failed_method": STRENGTH_METHOD,
				}
			elif not _is_finite(float(scalar_candidate)):
				first_failure = {
					"reason": &"non_finite_provider_sample",
					"failed_action": action_id,
					"failed_method": STRENGTH_METHOD,
				}
			elif not pressed_candidate is bool:
				first_failure = {
					"reason": &"malformed_provider_sample",
					"failed_action": action_id,
					"failed_method": PRESSED_METHOD,
				}
		raw_frame[action_id] = {
			"raw_scalar": float(scalar_candidate) if scalar_candidate is float or scalar_candidate is int else 0.0,
			"raw_pressed": bool(pressed_candidate) if pressed_candidate is bool else false,
		}
	if not first_failure.is_empty():
		return _frame_result(
			false,
			StringName(first_failure.reason),
			delta,
			{},
			first_failure,
		)

	# Re-checking occurs inside the bank after all provider calls. A provider that
	# changes bank generation/lifecycle cannot commit the collected stale frame.
	var transformed := _bank.process_complete_frame(
		raw_frame,
		delta,
		expected_generation,
		prime_physical_state,
	)
	return transformed.duplicate(true)


## The audit describes call cardinality and boundaries without exposing the
## injected provider object or invoking it.
func audit() -> Dictionary:
	var provider := _resolve_provider()
	return {
		"valid": is_configuration_valid(),
		"errors": _configuration_errors.duplicate(),
		"provider_mode": &"injected" if _input_provider != null else &"production_input",
		"provider_valid": provider != null and is_instance_valid(provider),
		"provider_methods_valid": (
			provider != null
			and is_instance_valid(provider)
			and provider.has_method(STRENGTH_METHOD)
			and provider.has_method(PRESSED_METHOD)
		),
		"strength_method": STRENGTH_METHOD,
		"pressed_method": PRESSED_METHOD,
		"strength_reads_per_action_per_tick": 1,
		"pressed_reads_per_action_per_tick": 1,
		"samples_complete_exact_roster": true,
		"uses_atomic_bank_frame": true,
		"uses_caller_physics_delta": true,
		"reads_input_singleton_by_default": true,
		"reads_input_map": false,
		"mutates_input_map": false,
		"infers_devices": false,
		"gameplay_authority": false,
		"player_authority": false,
		"ship_authority": false,
		"hud_authority": false,
		"game_flow_authority": false,
		"action_order": _bank.get_action_order() if is_configuration_valid() else [],
		"bank_generation": _bank.get_generation() if is_configuration_valid() else -1,
	}


func _resolve_provider() -> Object:
	return _input_provider if _input_provider != null else Input


func _frame_result(
		accepted: bool,
		reason: StringName,
		physics_delta: float,
		actions: Dictionary,
		details: Dictionary = {},
	) -> Dictionary:
	var action_order: Array[StringName] = []
	var generation := -1
	if _bank != null and is_instance_valid(_bank):
		action_order = _bank.get_action_order()
		generation = _bank.get_generation()
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": generation,
		"physics_delta": physics_delta,
		"action_count": action_order.size(),
		"action_order": action_order,
		"actions": actions.duplicate(true),
	}
	for key: Variant in details:
		if key == &"reason":
			continue
		var value: Variant = details[key]
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
