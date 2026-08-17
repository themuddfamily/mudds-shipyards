class_name InputActionTransformBank
extends RefCounted

## Production-neutral owner of one InputActionTransform for every exact action
## in a complete, validated InputBindingProfile.
##
## The bank coordinates profile and owner lifecycle only. Scalar transform math
## remains exclusively in InputActionTransform, and no method polls or mutates
## InputMap or dispatches input to gameplay.

const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")
const InputActionTransformType := preload("res://scripts/settings/input_action_transform.gd")

const MAX_GENERATION := 9223372036854775807

var _profile: InputBindingProfile
var _action_order: Array[StringName] = []
var _transforms: Dictionary = {}
var _configuration_errors := PackedStringArray()
var _generation := 0
var _attached := false


func _init(profile: InputBindingProfile) -> void:
	var expected_actions: Array[StringName] = []
	var prepared := _prepare_profile(profile, expected_actions, false, false)
	if not bool(prepared.accepted):
		_configuration_errors.append(String(prepared.reason))
		for detail: String in prepared.get("errors", PackedStringArray()):
			_configuration_errors.append(detail)
		return
	_commit_prepared(prepared)


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_generation() -> int:
	return _generation


func get_action_order() -> Array[StringName]:
	return _action_order.duplicate()


func get_profile() -> InputBindingProfile:
	return _profile.duplicate_profile() if _profile != null else null


## Attaches every retained child at its own exact generation. The preflight is
## complete before the mutation loop; child transforms have no signals or
## external references, so a successful preflight makes the commit deterministic.
func attach(expected_generation: int) -> Dictionary:
	var rejection := _validate_request(expected_generation, false)
	if not rejection.is_empty():
		return rejection
	if _attached:
		return _bank_result(false, &"already_attached")
	if not _children_match_lifecycle(false):
		return _bank_result(false, &"bank_corrupted")
	for action_id: StringName in _action_order:
		var transform := _transforms[action_id] as InputActionTransform
		var result := transform.attach(transform.get_generation())
		if not bool(result.accepted):
			return _bank_result(false, &"bank_corrupted")
	_attached = true
	return _bank_result(true, &"attached")


## Detach clears every child's transient edges through InputActionTransform but
## preserves persistent press/latch/value/time state for exact-generation re-entry.
func detach(expected_generation: int) -> Dictionary:
	var rejection := _validate_request(expected_generation, true)
	if not rejection.is_empty():
		return rejection
	if not _children_match_lifecycle(true):
		return _bank_result(false, &"bank_corrupted")
	for action_id: StringName in _action_order:
		var transform := _transforms[action_id] as InputActionTransform
		var result := transform.detach(transform.get_generation())
		if not bool(result.accepted):
			return _bank_result(false, &"bank_corrupted")
	_attached = false
	return _bank_result(true, &"detached")


## Replaces bindings/options only when the complete validated candidate has the
## exact initial action roster. A fresh, fully prepared child set is committed
## at once, so no prior edge, held value, elapsed time, or toggle can leak into
## the replacement generation.
func replace_profile(candidate: InputBindingProfile, expected_generation: int) -> Dictionary:
	var rejection := _validate_request(expected_generation, false)
	if not rejection.is_empty():
		return rejection
	if _generation == MAX_GENERATION:
		return _bank_result(false, &"generation_exhausted")
	var prepared := _prepare_profile(candidate, _action_order, true, _attached)
	if not bool(prepared.accepted):
		return _bank_result(false, StringName(prepared.reason), prepared)
	_commit_prepared(prepared)
	_generation += 1
	return _bank_result(true, &"profile_replaced")


## Resets sampled state for the entire current profile. Rebuilding all children
## before commit gives reset the same atomic/no-leak guarantee as replacement.
func reset(expected_generation: int) -> Dictionary:
	var rejection := _validate_request(expected_generation, false)
	if not rejection.is_empty():
		return rejection
	if _generation == MAX_GENERATION:
		return _bank_result(false, &"generation_exhausted")
	var prepared := _prepare_profile(_profile, _action_order, true, _attached)
	if not bool(prepared.accepted):
		return _bank_result(false, &"bank_corrupted")
	_commit_prepared(prepared)
	_generation += 1
	return _bank_result(true, &"reset")


## Processes exactly one known action from caller-supplied physics input. Bank
## generation is the public freshness token; child generations remain private
## implementation state and are invoked at their exact current value.
func process_action_sample(
		action_id: StringName,
		raw_scalar: float,
		raw_pressed: bool,
		physics_delta: float,
		expected_generation: int,
		echo: bool = false,
	) -> Dictionary:
	var rejection := _validate_request(expected_generation, false)
	if not rejection.is_empty():
		return _action_result(false, StringName(rejection.reason), action_id, {})
	if not _transforms.has(action_id):
		return _action_result(false, &"unknown_action", action_id, {})
	if not _attached:
		return _action_result(false, &"detached", action_id, {})
	var transform := _transforms[action_id] as InputActionTransform
	var transformed := transform.process_sample(
		raw_scalar,
		raw_pressed,
		physics_delta,
		transform.get_generation(),
		echo,
	)
	var action_snapshot := transformed.duplicate(true)
	action_snapshot.erase("accepted")
	action_snapshot.erase("reason")
	return _action_result(
		bool(transformed.accepted),
		StringName(transformed.reason),
		action_id,
		action_snapshot,
	)


## Atomically processes one complete caller-physics frame. The exact roster,
## sample shapes, numeric inputs, and every possible child time accumulation are
## preflighted before the first InputActionTransform is invoked. Children are
## private, signal-free, and lifecycle-matched, so the post-preflight commit loop
## cannot reject without an internal bank invariant violation. A priming frame
## seeds physical state across the same exact roster without emitting edges or
## changing toggle latches.
func process_complete_frame(
		samples: Variant,
		physics_delta: Variant,
		expected_generation: int,
		prime_physical_state: bool = false,
	) -> Dictionary:
	var rejection := _validate_request(expected_generation, true)
	if not rejection.is_empty():
		return _frame_result(false, StringName(rejection.reason), 0.0, {})
	if not physics_delta is float and not physics_delta is int:
		return _frame_result(false, &"invalid_physics_delta", 0.0, {})
	var delta := float(physics_delta)
	if not _is_finite(delta) or delta < 0.0:
		return _frame_result(false, &"invalid_physics_delta", 0.0, {})
	if not samples is Dictionary:
		return _frame_result(false, &"malformed_frame", delta, {})
	var raw_samples := samples as Dictionary
	var action_parse := _parse_frame_action_order(raw_samples)
	if not bool(action_parse.accepted):
		return _frame_result(false, &"malformed_frame", delta, {})
	var frame_order: Array[StringName] = action_parse.action_order
	var canonical_samples := action_parse.samples as Dictionary
	if frame_order != _action_order:
		return _frame_result(
			false,
			&"action_roster_mismatch",
			delta,
			{},
			{
				"missing_actions": _difference(_action_order, frame_order),
				"unknown_actions": _difference(frame_order, _action_order),
			},
		)
	if not _children_match_lifecycle(true):
		return _frame_result(false, &"bank_corrupted", delta, {})

	var normalized_samples := {}
	for action_id: StringName in _action_order:
		var candidate: Variant = canonical_samples[action_id]
		if not candidate is Dictionary:
			return _frame_result(false, &"malformed_frame", delta, {}, {"failed_action": action_id})
		var raw := candidate as Dictionary
		if raw.size() != 2 or not raw.has("raw_scalar") or not raw.has("raw_pressed"):
			return _frame_result(false, &"malformed_frame", delta, {}, {"failed_action": action_id})
		if not raw.raw_scalar is float and not raw.raw_scalar is int:
			return _frame_result(false, &"malformed_frame", delta, {}, {"failed_action": action_id})
		if not raw.raw_pressed is bool:
			return _frame_result(false, &"malformed_frame", delta, {}, {"failed_action": action_id})
		var scalar := float(raw.raw_scalar)
		if not _is_finite(scalar):
			return _frame_result(false, &"non_finite_sample", delta, {}, {"failed_action": action_id})
		var transform := _transforms[action_id] as InputActionTransform
		var snapshot := transform.get_snapshot()
		if int(snapshot.sample_count) == MAX_GENERATION:
			return _frame_result(false, &"sample_count_exhausted", delta, {}, {"failed_action": action_id})
		if (
			not _finite_sum(float(snapshot.elapsed_seconds), delta)
			or not _finite_sum(float(snapshot.physical_hold_seconds), delta)
			or not _finite_sum(float(snapshot.hold_seconds), delta)
		):
			return _frame_result(false, &"non_finite_accumulation", delta, {}, {"failed_action": action_id})
		normalized_samples[action_id] = {
			"raw_scalar": scalar,
			"raw_pressed": bool(raw.raw_pressed),
		}

	var action_snapshots := {}
	for action_id: StringName in _action_order:
		var transform := _transforms[action_id] as InputActionTransform
		var sample := normalized_samples[action_id] as Dictionary
		var transformed := transform.process_sample(
			float(sample.raw_scalar),
			bool(sample.raw_pressed),
			delta,
			transform.get_generation(),
			false,
			prime_physical_state,
		)
		if not bool(transformed.accepted):
			push_error("InputActionTransformBank complete-frame invariant failed for %s" % action_id)
			return _frame_result(false, &"bank_corrupted", delta, {})
		var action_snapshot := transformed.duplicate(true)
		action_snapshot.erase("accepted")
		action_snapshot.erase("reason")
		action_snapshots[action_id] = action_snapshot
	return _frame_result(true, &"sampled", delta, action_snapshots)


## Exact-generation single-action inspection is available while attached or
## detached. Unknown/stale requests return an empty action snapshot.
func get_action_snapshot(action_id: StringName, expected_generation: int) -> Dictionary:
	var rejection := _validate_request(expected_generation, false)
	if not rejection.is_empty():
		return _action_result(false, StringName(rejection.reason), action_id, {})
	if not _transforms.has(action_id):
		return _action_result(false, &"unknown_action", action_id, {})
	var transform := _transforms[action_id] as InputActionTransform
	return _action_result(true, &"snapshot", action_id, transform.get_snapshot())


## Whole-bank snapshots are deeply detached and inserted in stable sorted action
## order. They are presentation-ready data only, never transform references.
func get_snapshot() -> Dictionary:
	var action_snapshots := {}
	for action_id: StringName in _action_order:
		var transform := _transforms[action_id] as InputActionTransform
		action_snapshots[action_id] = transform.get_snapshot()
	return {
		"generation": _generation,
		"attached": _attached,
		"action_count": _action_order.size(),
		"action_order": _action_order.duplicate(),
		"profile": _profile.to_dictionary() if _profile != null else {},
		"actions": action_snapshots,
	}


## Declares the complete action roster, child audits, atomicity/lifecycle rules,
## and absence of every adjacent production authority. Nested data is detached.
func audit() -> Dictionary:
	var child_audits := {}
	for action_id: StringName in _action_order:
		var transform := _transforms[action_id] as InputActionTransform
		child_audits[action_id] = transform.audit()
	return {
		"valid": is_configuration_valid(),
		"errors": _configuration_errors.duplicate(),
		"profile_schema_version": InputBindingProfileType.SCHEMA_VERSION,
		"action_count": _action_order.size(),
		"action_order": _action_order.duplicate(),
		"exact_action_roster_enforced": true,
		"atomic_profile_replacement": true,
		"atomic_whole_profile_reset": true,
		"atomic_complete_frame": true,
		"uses_input_action_transform": true,
		"uses_caller_physics_delta": true,
		"reads_input_map": false,
		"mutates_input_map": false,
		"infers_devices": false,
		"gameplay_authority": false,
		"player_authority": false,
		"ship_authority": false,
		"hud_authority": false,
		"game_flow_authority": false,
		"child_audits": child_audits,
		"snapshot": get_snapshot(),
	}


func _prepare_profile(
		candidate: InputBindingProfile,
		expected_actions: Array[StringName],
		enforce_roster: bool,
		attach_children: bool,
	) -> Dictionary:
	if candidate == null:
		return {"accepted": false, "reason": &"missing_profile"}
	var validated := InputBindingProfileType.from_dictionary(candidate.to_dictionary())
	if validated == null:
		return {"accepted": false, "reason": &"invalid_profile"}
	var binding_actions := _sorted_actions(validated.bindings)
	var option_actions := _sorted_actions(validated.action_options)
	if binding_actions.is_empty():
		return {"accepted": false, "reason": &"empty_profile"}
	if binding_actions != option_actions:
		return {
			"accepted": false,
			"reason": &"incomplete_profile",
			"missing_action_options": _difference(binding_actions, option_actions),
			"orphan_action_options": _difference(option_actions, binding_actions),
		}
	if enforce_roster and binding_actions != expected_actions:
		return {
			"accepted": false,
			"reason": &"action_roster_mismatch",
			"missing_actions": _difference(expected_actions, binding_actions),
			"unknown_actions": _difference(binding_actions, expected_actions),
		}

	var canonical_bindings := {}
	var canonical_options := {}
	for action_id: StringName in binding_actions:
		canonical_bindings[action_id] = validated.get_bindings(action_id)
		canonical_options[action_id] = validated.get_action_options(action_id)
	var canonical := InputBindingProfileType.from_dictionary({
		"schema_version": InputBindingProfileType.SCHEMA_VERSION,
		"bindings": canonical_bindings,
		"action_options": canonical_options,
	})
	if canonical == null:
		return {"accepted": false, "reason": &"invalid_profile"}

	var prepared_transforms := {}
	for action_id: StringName in binding_actions:
		var transform := InputActionTransformType.from_profile(canonical, action_id)
		if not transform.is_configuration_valid():
			return {"accepted": false, "reason": &"invalid_action_options"}
		if attach_children and not bool(transform.attach(transform.get_generation()).accepted):
			return {"accepted": false, "reason": &"transform_attach_failed"}
		prepared_transforms[action_id] = transform
	return {
		"accepted": true,
		"reason": &"prepared",
		"profile": canonical,
		"action_order": binding_actions,
		"transforms": prepared_transforms,
	}


func _commit_prepared(prepared: Dictionary) -> void:
	_profile = prepared.profile as InputBindingProfile
	_action_order = (prepared.action_order as Array).duplicate()
	_transforms = prepared.transforms as Dictionary


func _validate_request(expected_generation: int, require_attached: bool) -> Dictionary:
	if not is_configuration_valid():
		return _bank_result(false, &"invalid_configuration")
	if expected_generation != _generation:
		return _bank_result(false, &"stale_generation")
	if require_attached and not _attached:
		return _bank_result(false, &"detached")
	return {}


func _children_match_lifecycle(expected_attached: bool) -> bool:
	if _transforms.size() != _action_order.size():
		return false
	for action_id: StringName in _action_order:
		if not _transforms.has(action_id):
			return false
		var transform := _transforms[action_id] as InputActionTransform
		if transform == null or not transform.is_configuration_valid():
			return false
		if bool(transform.get_snapshot().attached) != expected_attached:
			return false
	return true


func _bank_result(accepted: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	for key: Variant in details:
		if key in [&"accepted", &"reason", &"profile", &"transforms"]:
			continue
		var value: Variant = details[key]
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _action_result(
		accepted: bool,
		reason: StringName,
		action_id: StringName,
		action_snapshot: Dictionary,
	) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"action_id": action_id,
		"action_snapshot": action_snapshot.duplicate(true),
	}


static func _sorted_actions(source: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_action: Variant in source:
		result.append(StringName(raw_action))
	result.sort()
	return result


static func _difference(left: Array[StringName], right: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for action_id: StringName in left:
		if not action_id in right:
			result.append(action_id)
	return result


func _frame_result(
		accepted: bool,
		reason: StringName,
		physics_delta: float,
		action_snapshots: Dictionary,
		details: Dictionary = {},
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"physics_delta": physics_delta,
		"action_count": _action_order.size(),
		"action_order": _action_order.duplicate(),
		"actions": action_snapshots.duplicate(true),
	}
	for key: Variant in details:
		var value: Variant = details[key]
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


static func _parse_frame_action_order(samples: Dictionary) -> Dictionary:
	var action_order: Array[StringName] = []
	var canonical_samples := {}
	for raw_action: Variant in samples:
		if not raw_action is StringName and not raw_action is String:
			return {"accepted": false, "action_order": action_order, "samples": {}}
		var action_id := StringName(raw_action)
		if action_id.is_empty():
			return {"accepted": false, "action_order": action_order, "samples": {}}
		action_order.append(action_id)
		canonical_samples[action_id] = samples[raw_action]
	action_order.sort()
	return {"accepted": true, "action_order": action_order, "samples": canonical_samples}


static func _finite_sum(current: float, delta: float) -> bool:
	if not _is_finite(current):
		return false
	return _is_finite(current + delta)


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
