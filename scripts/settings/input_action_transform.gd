class_name InputActionTransform
extends RefCounted

## Deterministic, side-effect-free execution of one InputBindingProfile action's
## deadzone, response-curve, and hold/toggle options.
##
## A caller owns sampling and supplies physics delta explicitly. This transform
## never reads or mutates InputMap and owns no gameplay or presentation state.

const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")

const RAW_SCALAR_MIN := -1.0
const RAW_SCALAR_MAX := 1.0
const MAX_GENERATION := 9223372036854775807

var _action_id: StringName = &""
var _options: Dictionary = {}
var _configuration_errors := PackedStringArray()

var _generation := 0
var _attached := false
var _sample_count := 0
var _elapsed_seconds := 0.0

var _raw_scalar := 0.0
var _raw_pressed := false
var _last_sample_was_clamped := false
var _transformed_scalar := 0.0
var _physical_pressed := false
var _physical_just_pressed := false
var _physical_just_released := false
var _physical_hold_seconds := 0.0
var _pressed := false
var _just_pressed := false
var _just_released := false
var _hold_seconds := 0.0
var _value := 0.0
var _toggle_latched := false


func _init(action_id: StringName, action_options: Variant) -> void:
	_action_id = action_id
	_options = InputBindingProfileType.normalize_action_options(action_options)
	if _action_id.is_empty():
		_configuration_errors.append("action_id must not be empty")
	if _options.is_empty():
		_configuration_errors.append(
			"action_options must match InputBindingProfile schema version %d"
			% InputBindingProfileType.SCHEMA_VERSION
		)


## Builds the transform from one already-validated profile action. A missing
## profile/action produces an invalid, auditable transform rather than silently
## substituting defaults.
static func from_profile(profile: InputBindingProfile, action_id: StringName) -> InputActionTransform:
	if profile == null:
		return InputActionTransform.new(action_id, {})
	return InputActionTransform.new(action_id, profile.get_action_options(action_id))


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_generation() -> int:
	return _generation


func get_action_id() -> StringName:
	return _action_id


func get_action_options() -> Dictionary:
	return _options.duplicate(true)


## Attachment is an explicit owner-lifecycle gate. Detaching preserves the
## exact transform state; sampling can resume after reattachment with the same
## generation and no hidden elapsed time.
func attach(expected_generation: int) -> Dictionary:
	var rejection := _validate_mutation(expected_generation, false)
	if not rejection.is_empty():
		return rejection
	if _attached:
		return _result(false, &"already_attached")
	_attached = true
	return _result(true, &"attached")


func detach(expected_generation: int) -> Dictionary:
	var rejection := _validate_mutation(expected_generation, true)
	if not rejection.is_empty():
		return rejection
	# One-sample edges must never be replayed by a later owner after re-entry.
	_clear_edges()
	_attached = false
	return _result(true, &"detached")


## Reset clears sampled state and advances generation atomically. It is valid
## while attached or detached, and deliberately preserves that lifecycle state.
func reset(expected_generation: int) -> Dictionary:
	var rejection := _validate_mutation(expected_generation, false)
	if not rejection.is_empty():
		return rejection
	if _generation == MAX_GENERATION:
		return _result(false, &"generation_exhausted")
	_generation += 1
	_clear_sampled_state()
	return _result(true, &"reset")


## Processes one caller-owned physics sample. `raw_scalar` is clamped to the
## normalized action-strength range [-1, 1] before its signed deadzone remap.
## Echo samples clear one-sample edge flags but cannot advance time, change the
## latch, or create a second press. A priming sample seeds current physical state
## without emitting edges or changing a toggle latch; HOLD output still follows
## the seeded state. A pressed sample inside the deadzone is treated as inactive
## noise; crossing back inside creates one physical release.
func process_sample(
		raw_scalar: float,
		raw_pressed: bool,
		physics_delta: float,
		expected_generation: int,
		echo: bool = false,
		prime_physical_state: bool = false,
	) -> Dictionary:
	var rejection := _validate_mutation(expected_generation, true)
	if not rejection.is_empty():
		return rejection
	if not _is_finite(raw_scalar):
		return _result(false, &"invalid_raw_scalar")
	if not _is_finite(physics_delta) or physics_delta < 0.0:
		return _result(false, &"invalid_physics_delta")

	if echo:
		_clear_edges()
		return _result(true, &"echo_ignored")

	var normalized_raw := clampf(raw_scalar, RAW_SCALAR_MIN, RAW_SCALAR_MAX)
	var transformed := _transform_scalar(normalized_raw)
	var next_physical_pressed := raw_pressed and transformed != 0.0
	var physical_rising := next_physical_pressed and not _physical_pressed

	var next_toggle_latched := _toggle_latched
	var next_pressed := next_physical_pressed
	var next_value := transformed if next_physical_pressed else 0.0
	if _options.hold_mode == InputBindingProfileType.TOGGLE:
		if physical_rising and not prime_physical_state:
			next_toggle_latched = not next_toggle_latched
		next_pressed = next_toggle_latched
		next_value = 1.0 if next_toggle_latched else 0.0

	var next_elapsed := _elapsed_seconds + physics_delta
	var next_physical_hold := (
		_physical_hold_seconds + physics_delta
		if next_physical_pressed and _physical_pressed
		else physics_delta if next_physical_pressed else 0.0
	)
	var next_hold := (
		_hold_seconds + physics_delta
		if next_pressed and _pressed
		else physics_delta if next_pressed else 0.0
	)
	if not _is_finite(next_elapsed) or not _is_finite(next_physical_hold) or not _is_finite(next_hold):
		return _result(false, &"non_finite_accumulation")

	_physical_just_pressed = physical_rising and not prime_physical_state
	_physical_just_released = (
		not next_physical_pressed and _physical_pressed and not prime_physical_state
	)
	_just_pressed = next_pressed and not _pressed and not prime_physical_state
	_just_released = not next_pressed and _pressed and not prime_physical_state
	_raw_scalar = normalized_raw
	_raw_pressed = raw_pressed
	_last_sample_was_clamped = not is_equal_approx(normalized_raw, raw_scalar)
	_transformed_scalar = transformed
	_physical_pressed = next_physical_pressed
	_physical_hold_seconds = next_physical_hold
	_toggle_latched = next_toggle_latched
	_pressed = next_pressed
	_hold_seconds = next_hold
	_value = next_value
	_elapsed_seconds = next_elapsed
	_sample_count += 1
	return _result(true, &"sampled")


## Returns a detached tree suitable for a later consumer or deterministic test.
## `pressed`/`just_*` describe logical output; `physical_*` separately exposes
## the post-deadzone edge that drives hold/toggle state.
func get_snapshot() -> Dictionary:
	return {
		"action_id": _action_id,
		"action_options": _options.duplicate(true),
		"generation": _generation,
		"attached": _attached,
		"sample_count": _sample_count,
		"elapsed_seconds": _elapsed_seconds,
		"raw_scalar": _raw_scalar,
		"raw_pressed": _raw_pressed,
		"raw_scalar_was_clamped": _last_sample_was_clamped,
		"transformed_scalar": _transformed_scalar,
		"physical_pressed": _physical_pressed,
		"physical_just_pressed": _physical_just_pressed,
		"physical_just_released": _physical_just_released,
		"physical_hold_seconds": _physical_hold_seconds,
		"pressed": _pressed,
		"just_pressed": _just_pressed,
		"just_released": _just_released,
		"hold_seconds": _hold_seconds,
		"value": _value,
		"toggle_latched": _toggle_latched,
	}


## Deep audit declares configuration, executable option IDs, time/lifecycle
## boundaries, and absence of adjacent authorities. All nested values are
## detached, including the embedded live snapshot.
func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": _configuration_errors.duplicate(),
		"profile_schema_version": InputBindingProfileType.SCHEMA_VERSION,
		"action_id": _action_id,
		"action_options": _options.duplicate(true),
		"supported_curves": [
			InputBindingProfileType.CURVE_LINEAR,
			InputBindingProfileType.CURVE_SQUARED,
		],
		"supported_hold_modes": [
			InputBindingProfileType.HOLD,
			InputBindingProfileType.TOGGLE,
		],
		"raw_scalar_bounds": {"minimum": RAW_SCALAR_MIN, "maximum": RAW_SCALAR_MAX},
		"uses_caller_physics_delta": true,
		"reads_input_map": false,
		"mutates_input_map": false,
		"gameplay_authority": false,
		"player_authority": false,
		"ship_authority": false,
		"hud_authority": false,
		"game_flow_authority": false,
		"snapshot": get_snapshot(),
	}


func _validate_mutation(expected_generation: int, require_attached: bool) -> Dictionary:
	if not is_configuration_valid():
		return _result(false, &"invalid_configuration")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if require_attached and not _attached:
		return _result(false, &"detached")
	return {}


func _transform_scalar(normalized_raw: float) -> float:
	var magnitude := absf(normalized_raw)
	var deadzone := float(_options.deadzone)
	if magnitude <= deadzone:
		return 0.0
	var remapped := 1.0
	if deadzone < 1.0:
		remapped = clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	if _options.curve == InputBindingProfileType.CURVE_SQUARED:
		remapped *= remapped
	return remapped * signf(normalized_raw)


func _clear_edges() -> void:
	_physical_just_pressed = false
	_physical_just_released = false
	_just_pressed = false
	_just_released = false


func _clear_sampled_state() -> void:
	_sample_count = 0
	_elapsed_seconds = 0.0
	_raw_scalar = 0.0
	_raw_pressed = false
	_last_sample_was_clamped = false
	_transformed_scalar = 0.0
	_physical_pressed = false
	_physical_just_pressed = false
	_physical_just_released = false
	_physical_hold_seconds = 0.0
	_pressed = false
	_just_pressed = false
	_just_released = false
	_hold_seconds = 0.0
	_value = 0.0
	_toggle_latched = false


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result


func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
