class_name TransformedShipCommandMapper
extends RefCounted

## Strict, production-neutral adapter from one detached
## InputActionTransformSampler frame to the existing ShipCommand transport.
##
## The caller owns sampling, physics cadence, command metadata, delivery, and
## authority. This mapper never polls input and retains no frame or command.

const ShipCommandType := preload("res://scripts/control/ship_command.gd")
const ProfileType := preload("res://scripts/settings/input_binding_profile.gd")

const FLIGHT_ACTION_ORDER: Array[StringName] = [
	&"barrel_roll",
	&"brake",
	&"camera_distance_in",
	&"camera_distance_out",
	&"fire",
	&"hover",
	&"interact",
	&"landing_assist",
	&"move_back",
	&"move_forward",
	&"move_left",
	&"move_right",
	&"pitch_down",
	&"pitch_up",
	&"roll_left",
	&"roll_right",
	&"sprint_boost",
	&"toggle_ship_camera_view",
]

const _FRAME_KEYS := [
	"accepted", "reason", "generation", "physics_delta", "action_count",
	"action_order", "actions",
]
const _ACTION_KEYS := [
	"action_id", "action_options", "generation", "attached", "sample_count",
	"elapsed_seconds", "raw_scalar", "raw_pressed", "raw_scalar_was_clamped",
	"transformed_scalar", "physical_pressed", "physical_just_pressed",
	"physical_just_released", "physical_hold_seconds", "pressed",
	"just_pressed", "just_released", "hold_seconds", "value", "toggle_latched",
]
const _OPTION_KEYS := ["deadzone", "curve", "hold_mode"]


## Maps one accepted sampler frame at the caller's exact bank generation.
## Rejections always include a fresh valid neutral command; no malformed or stale
## action can cross into ShipCommand transport.
func map_frame(
		frame: Variant,
		expected_frame_generation: Variant,
		sequence: Variant,
		timestamp_usec: Variant,
		stream_id: Variant,
	) -> Dictionary:
	var metadata := _validate_command_metadata(sequence, timestamp_usec, stream_id)
	if not bool(metadata.accepted):
		return _result(false, &"invalid_command_metadata", -1, 0.0, _neutral_command(0, 0, 0))
	var safe_sequence := int(sequence)
	var safe_timestamp := int(timestamp_usec)
	var safe_stream := int(stream_id)
	var neutral := _neutral_command(safe_sequence, safe_timestamp, safe_stream)
	if not expected_frame_generation is int or int(expected_frame_generation) < 0:
		return _result(false, &"invalid_expected_generation", -1, 0.0, neutral)

	var validated := _validate_frame(frame, int(expected_frame_generation))
	if not bool(validated.accepted):
		return _result(
			false,
			StringName(validated.reason),
			int(validated.get("generation", -1)),
			float(validated.get("physics_delta", 0.0)),
			neutral,
			validated.get("details", {}),
		)

	var actions := validated.actions as Dictionary
	var command := ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION,
		"sequence": safe_sequence,
		"timestamp_usec": safe_timestamp,
		"stream_id": safe_stream,
		"throttle": _axis(actions, &"move_back", &"move_forward"),
		"yaw": _axis(actions, &"move_left", &"move_right"),
		"pitch": _axis(actions, &"pitch_down", &"pitch_up"),
		"roll": _axis(actions, &"roll_left", &"roll_right"),
		"look_yaw_delta": 0.0,
		"look_pitch_delta": 0.0,
		"camera_distance_delta": (
			_edge(actions, &"camera_distance_out")
			- _edge(actions, &"camera_distance_in")
		),
		"boost": _held(actions, &"sprint_boost"),
		"brake": _held(actions, &"brake"),
		"hover": _held(actions, &"hover"),
		"fire": _held(actions, &"fire"),
		"fire_pressed": _edge(actions, &"fire") > 0.0,
		"barrel_roll": _edge(actions, &"barrel_roll") > 0.0,
		# Automatic propulsion deliberately has no player start/stop actions.
		"engine_start": false,
		"engine_stop": false,
		"landing": _edge(actions, &"landing_assist") > 0.0,
		"interact": _edge(actions, &"interact") > 0.0,
		"camera_toggle": _edge(actions, &"toggle_ship_camera_view") > 0.0,
	})
	if not command.is_valid():
		return _result(
			false,
			&"command_construction_failed",
			int(validated.generation),
			float(validated.physics_delta),
			neutral,
		)
	return _result(
		true,
		&"mapped",
		int(validated.generation),
		float(validated.physics_delta),
		command,
	)


func audit() -> Dictionary:
	return {
		"valid": true,
		"flight_action_count": FLIGHT_ACTION_ORDER.size(),
		"flight_action_order": FLIGHT_ACTION_ORDER.duplicate(),
		"axis_mappings": {
			"throttle": [&"move_back", &"move_forward"],
			"yaw": [&"move_left", &"move_right"],
			"pitch": [&"pitch_down", &"pitch_up"],
			"roll": [&"roll_left", &"roll_right"],
		},
		"held_mappings": {
			"boost": &"sprint_boost",
			"brake": &"brake",
			"hover": &"hover",
			"fire": &"fire",
		},
		"edge_mappings": {
			"fire_pressed": &"fire",
			"barrel_roll": &"barrel_roll",
			"landing": &"landing_assist",
			"interact": &"interact",
			"camera_toggle": &"toggle_ship_camera_view",
			"camera_distance_in": &"camera_distance_in",
			"camera_distance_out": &"camera_distance_out",
		},
		"automatic_engine_start_emitted": false,
		"automatic_engine_stop_emitted": false,
		"mouse_look_motion_authority": false,
		"reads_input": false,
		"reads_input_map": false,
		"owns_physics_timing": false,
		"owns_command_sequence": false,
		"owns_command_delivery": false,
		"owns_device_selection": false,
		"owns_game_flow": false,
		"owns_ship": false,
	}.duplicate(true)


func _validate_frame(frame: Variant, expected_generation: int) -> Dictionary:
	if not frame is Dictionary:
		return _validation(false, &"malformed_frame")
	var raw := frame as Dictionary
	if not _has_exact_string_keys(raw, _FRAME_KEYS):
		return _validation(false, &"malformed_frame")
	if not raw.accepted is bool or not bool(raw.accepted):
		return _validation(false, &"upstream_rejected")
	if not raw.reason is StringName or raw.reason != &"sampled":
		return _validation(false, &"malformed_frame")
	if not raw.generation is int or int(raw.generation) < 0:
		return _validation(false, &"malformed_frame")
	var generation := int(raw.generation)
	if generation != expected_generation:
		return _validation(false, &"stale_frame_generation", generation)
	if not raw.physics_delta is float and not raw.physics_delta is int:
		return _validation(false, &"malformed_frame", generation)
	var physics_delta := float(raw.physics_delta)
	if not _is_finite(physics_delta) or physics_delta < 0.0:
		return _validation(false, &"malformed_frame", generation)
	if not raw.action_count is int or int(raw.action_count) < 0:
		return _validation(false, &"malformed_frame", generation, physics_delta)
	if not raw.action_order is Array or not raw.actions is Dictionary:
		return _validation(false, &"malformed_frame", generation, physics_delta)

	var action_order: Array[StringName] = []
	for raw_action: Variant in raw.action_order as Array:
		if not raw_action is StringName or StringName(raw_action).is_empty():
			return _validation(false, &"malformed_frame", generation, physics_delta)
		action_order.append(StringName(raw_action))
	var sorted_order := action_order.duplicate()
	sorted_order.sort()
	if (
		action_order != sorted_order
		or _contains_duplicate(action_order)
		or action_order.size() != int(raw.action_count)
		or (raw.actions as Dictionary).size() != action_order.size()
	):
		return _validation(false, &"malformed_frame", generation, physics_delta)
	for raw_key: Variant in (raw.actions as Dictionary):
		if not raw_key is StringName or not StringName(raw_key) in action_order:
			return _validation(false, &"malformed_frame", generation, physics_delta)
	for action_id: StringName in FLIGHT_ACTION_ORDER:
		if not action_id in action_order:
			return _validation(
				false, &"missing_flight_action", generation, physics_delta,
				{"failed_action": action_id},
			)

	var actions := raw.actions as Dictionary
	for action_id: StringName in action_order:
		var action_validation := _validate_action_snapshot(actions[action_id], action_id)
		if not bool(action_validation.accepted):
			return _validation(
				false,
				StringName(action_validation.reason),
				generation,
				physics_delta,
				{"failed_action": action_id},
			)
	return {
		"accepted": true,
		"reason": &"valid",
		"generation": generation,
		"physics_delta": physics_delta,
		"actions": actions.duplicate(true),
	}


func _validate_action_snapshot(candidate: Variant, expected_action: StringName) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	var snapshot := candidate as Dictionary
	if not _has_exact_string_keys(snapshot, _ACTION_KEYS):
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if not snapshot.action_id is StringName or snapshot.action_id != expected_action:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if not snapshot.action_options is Dictionary:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	var options := snapshot.action_options as Dictionary
	if not _has_exact_string_keys(options, _OPTION_KEYS):
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if not options.deadzone is float and not options.deadzone is int:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	var deadzone := float(options.deadzone)
	if not _is_finite(deadzone) or deadzone < 0.0 or deadzone > 1.0:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if (
		not options.curve is StringName
		or not options.hold_mode is StringName
		or not options.curve in [ProfileType.CURVE_LINEAR, ProfileType.CURVE_SQUARED]
		or not options.hold_mode in [ProfileType.HOLD, ProfileType.TOGGLE]
	):
		return {"accepted": false, "reason": &"malformed_action_snapshot"}

	for key: String in ["generation", "sample_count"]:
		if not snapshot[key] is int or int(snapshot[key]) < 0:
			return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if int(snapshot.sample_count) < 1:
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	if not snapshot.attached is bool or not bool(snapshot.attached):
		return {"accepted": false, "reason": &"malformed_action_snapshot"}
	for key: String in [
		"elapsed_seconds", "raw_scalar", "transformed_scalar",
		"physical_hold_seconds", "hold_seconds", "value",
	]:
		if not snapshot[key] is float and not snapshot[key] is int:
			return {"accepted": false, "reason": &"malformed_action_snapshot"}
		if not _is_finite(float(snapshot[key])):
			return {"accepted": false, "reason": &"malformed_action_snapshot"}
	for key: String in [
		"raw_pressed", "raw_scalar_was_clamped", "physical_pressed",
		"physical_just_pressed", "physical_just_released", "pressed",
		"just_pressed", "just_released", "toggle_latched",
	]:
		if not snapshot[key] is bool:
			return {"accepted": false, "reason": &"malformed_action_snapshot"}

	var raw_scalar := float(snapshot.raw_scalar)
	var transformed := float(snapshot.transformed_scalar)
	var value := float(snapshot.value)
	var elapsed := float(snapshot.elapsed_seconds)
	var physical_hold := float(snapshot.physical_hold_seconds)
	var logical_hold := float(snapshot.hold_seconds)
	if (
		raw_scalar < -1.0 or raw_scalar > 1.0
		or transformed < -1.0 or transformed > 1.0
		or value < -1.0 or value > 1.0
		or elapsed < 0.0
		or physical_hold < 0.0 or physical_hold > elapsed
		or logical_hold < 0.0 or logical_hold > elapsed
	):
		return {"accepted": false, "reason": &"invalid_action_snapshot"}
	var expected_transform := _transform_scalar(raw_scalar, deadzone, StringName(options.curve))
	var physical_pressed := bool(snapshot.raw_pressed) and not is_zero_approx(expected_transform)
	if (
		not is_equal_approx(transformed, expected_transform)
		or bool(snapshot.physical_pressed) != physical_pressed
		or (bool(snapshot.physical_just_pressed) and not physical_pressed)
		or (bool(snapshot.physical_just_released) and physical_pressed)
		or (bool(snapshot.physical_just_pressed) and bool(snapshot.physical_just_released))
		or (not physical_pressed and not is_zero_approx(physical_hold))
		or (bool(snapshot.just_pressed) and not bool(snapshot.pressed))
		or (bool(snapshot.just_released) and bool(snapshot.pressed))
		or (bool(snapshot.just_pressed) and bool(snapshot.just_released))
		or (not bool(snapshot.pressed) and not is_zero_approx(logical_hold))
	):
		return {"accepted": false, "reason": &"invalid_action_snapshot"}
	if options.hold_mode == ProfileType.HOLD:
		var expected_value := transformed if physical_pressed else 0.0
		if (
			bool(snapshot.pressed) != physical_pressed
			or bool(snapshot.just_pressed) != bool(snapshot.physical_just_pressed)
			or bool(snapshot.just_released) != bool(snapshot.physical_just_released)
			or bool(snapshot.toggle_latched)
			or not is_equal_approx(value, expected_value)
		):
			return {"accepted": false, "reason": &"invalid_action_snapshot"}
	else:
		var latched := bool(snapshot.toggle_latched)
		if (
			bool(snapshot.pressed) != latched
			or not is_equal_approx(value, 1.0 if latched else 0.0)
		):
			return {"accepted": false, "reason": &"invalid_action_snapshot"}
	return {"accepted": true, "reason": &"valid"}


func _axis(actions: Dictionary, negative: StringName, positive: StringName) -> float:
	return clampf(
		float((actions[positive] as Dictionary).value)
		- float((actions[negative] as Dictionary).value),
		-1.0,
		1.0,
	)


func _held(actions: Dictionary, action_id: StringName) -> bool:
	return bool((actions[action_id] as Dictionary).pressed)


func _edge(actions: Dictionary, action_id: StringName) -> float:
	# Edge commands preserve LocalShipInputSource's physical rising-edge contract.
	# A valid toggle option may change a held action's logical latch, but must not
	# make landing/camera/etc. fire only on every other physical press.
	return 1.0 if bool((actions[action_id] as Dictionary).physical_just_pressed) else 0.0


func _transform_scalar(raw_scalar: float, deadzone: float, curve: StringName) -> float:
	var magnitude := absf(raw_scalar)
	if magnitude <= deadzone:
		return 0.0
	var remapped := 1.0
	if deadzone < 1.0:
		remapped = clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	if curve == ProfileType.CURVE_SQUARED:
		remapped *= remapped
	return remapped * signf(raw_scalar)


func _validate_command_metadata(sequence: Variant, timestamp_usec: Variant, stream_id: Variant) -> Dictionary:
	for value: Variant in [sequence, timestamp_usec, stream_id]:
		if (
			not value is int
			or int(value) < 0
			or int(value) > ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		):
			return {"accepted": false}
	return {"accepted": true}


func _neutral_command(sequence: int, timestamp_usec: int, stream_id: int) -> ShipCommand:
	return ShipCommandType.neutral(sequence, timestamp_usec, stream_id)


func _result(
		accepted: bool,
		reason: StringName,
		frame_generation: int,
		physics_delta: float,
		command: ShipCommand,
		details: Dictionary = {},
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"frame_generation": frame_generation,
		"physics_delta": physics_delta,
		"command": command,
	}
	for key: Variant in details:
		result[key] = details[key]
	return result


func _validation(
		accepted: bool,
		reason: StringName,
		generation: int = -1,
		physics_delta: float = 0.0,
		details: Dictionary = {},
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": generation,
		"physics_delta": physics_delta,
		"details": details.duplicate(true),
	}


func _has_exact_string_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key: Variant in dictionary:
		if not key is String or not key in expected:
			return false
	for key: String in expected:
		if not dictionary.has(key):
			return false
	return true


func _contains_duplicate(values: Array[StringName]) -> bool:
	var seen := {}
	for value: StringName in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false


func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
