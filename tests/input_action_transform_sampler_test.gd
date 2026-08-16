extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Bank := preload("res://scripts/settings/input_action_transform_bank.gd")
const Sampler := preload("res://scripts/settings/input_action_transform_sampler.gd")

const ACTION_ORDER: Array[StringName] = [&"brake", &"fire", &"interact"]

var _failures: Array[String] = []


class CountingProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}
	var strength_calls: Dictionary = {}
	var pressed_calls: Dictionary = {}
	var call_order: Array[String] = []

	func get_action_strength(action: StringName) -> Variant:
		strength_calls[action] = int(strength_calls.get(action, 0)) + 1
		call_order.append("%s:strength" % action)
		return strengths.get(action, 0.0)

	func is_action_pressed(action: StringName) -> Variant:
		pressed_calls[action] = int(pressed_calls.get(action, 0)) + 1
		call_order.append("%s:pressed" % action)
		return pressed.get(action, false)

	func clear_calls() -> void:
		strength_calls.clear()
		pressed_calls.clear()
		call_order.clear()


class StrengthOnlyProvider:
	extends RefCounted

	var calls := 0

	func get_action_strength(_action: StringName) -> float:
		calls += 1
		return 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_and_audit()
	_test_exact_complete_sampling()
	_test_pre_provider_rejections()
	_test_provider_failures_are_atomic()
	_test_production_input_default()
	_finish()


func _test_configuration_and_audit() -> void:
	var bank := Bank.new(_profile(ACTION_ORDER))
	var provider := CountingProvider.new()
	var sampler := Sampler.new(bank, provider)
	var audit := sampler.audit()
	_check(
		sampler.is_configuration_valid()
		and audit.valid
		and audit.provider_mode == &"injected"
		and audit.strength_method == &"get_action_strength"
		and audit.pressed_method == &"is_action_pressed"
		and audit.strength_reads_per_action_per_tick == 1
		and audit.pressed_reads_per_action_per_tick == 1
		and audit.samples_complete_exact_roster
		and audit.uses_atomic_bank_frame,
		"the sampler declares one strength and pressed read per exact action through the atomic bank frame"
	)
	_check(
		audit.uses_caller_physics_delta
		and audit.reads_input_singleton_by_default
		and not audit.reads_input_map
		and not audit.mutates_input_map
		and not audit.infers_devices
		and not audit.gameplay_authority
		and not audit.player_authority
		and not audit.ship_authority
		and not audit.hud_authority
		and not audit.game_flow_authority,
		"the sampler owns caller timing and no InputMap, device, Player, ship, HUD, GameFlow, or gameplay authority"
	)
	var invalid_profile := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {},
		"action_options": {},
	})
	_check(
		not Sampler.new(null, provider).is_configuration_valid()
		and not Sampler.new(Bank.new(invalid_profile), provider).is_configuration_valid(),
		"missing and invalid banks fail sampler configuration closed"
	)


func _test_exact_complete_sampling() -> void:
	var bank := Bank.new(_profile([&"interact", &"fire", &"brake"]))
	bank.attach(0)
	var provider := CountingProvider.new()
	provider.strengths = {&"brake": -0.75, &"fire": 0.6, &"interact": 0.0}
	provider.pressed = {&"brake": true, &"fire": true, &"interact": false}
	var sampler := Sampler.new(bank, provider)
	var frame := sampler.sample_physics_frame(0.25, 0)
	_check(
		frame.accepted
		and frame.reason == &"sampled"
		and frame.generation == 0
		and frame.action_order == ACTION_ORDER
		and frame.actions.keys() == ACTION_ORDER
		and frame.action_count == 3
		and is_equal_approx(float(frame.physics_delta), 0.25),
		"one caller physics tick returns the complete detached transformed frame in canonical order"
	)
	_check(
		provider.call_order == [
			"brake:strength", "brake:pressed",
			"fire:strength", "fire:pressed",
			"interact:strength", "interact:pressed",
		]
		and _all_action_counts_equal(provider.strength_calls, 1)
		and _all_action_counts_equal(provider.pressed_calls, 1),
		"the provider is read in stable order exactly once per method for every bank action"
	)
	_check(
		is_equal_approx(float(frame.actions[&"fire"].value), 0.5)
		and frame.actions[&"fire"].just_pressed
		and is_equal_approx(float(frame.actions[&"brake"].transformed_scalar), -0.25)
		and frame.actions[&"brake"].toggle_latched
		and frame.actions[&"interact"].sample_count == 1,
		"the adapter forwards raw state and lets existing child transforms own all curve/hold semantics"
	)
	(frame.action_order as Array)[0] = &"mutated"
	(frame.actions[&"fire"] as Dictionary)["value"] = 99.0
	_check(
		bank.get_action_order() == ACTION_ORDER
		and not is_equal_approx(float(bank.get_snapshot().actions[&"fire"].value), 99.0),
		"returned action order and nested action snapshots are deeply detached"
	)

	provider.clear_calls()
	provider.strengths = {&"brake": 0.0, &"fire": 0.0, &"interact": 1.0}
	provider.pressed = {&"brake": false, &"fire": false, &"interact": true}
	var second := sampler.sample_physics_frame(0.1, 0)
	_check(
		second.accepted
		and _all_action_counts_equal(provider.strength_calls, 1)
		and _all_action_counts_equal(provider.pressed_calls, 1)
		and second.actions[&"fire"].just_released
		and second.actions[&"interact"].just_pressed,
		"each later caller tick resamples the full roster once and returns current release/press edges"
	)


func _test_pre_provider_rejections() -> void:
	var bank := Bank.new(_profile(ACTION_ORDER))
	var provider := CountingProvider.new()
	var sampler := Sampler.new(bank, provider)
	var detached := sampler.sample_physics_frame(0.1, 0)
	_check(
		not detached.accepted
		and detached.reason == &"detached"
		and provider.call_order.is_empty()
		and detached.actions.is_empty(),
		"detached banks reject before any provider read"
	)
	bank.attach(0)
	var stale := sampler.sample_physics_frame(0.1, 7)
	var malformed_delta := sampler.sample_physics_frame("0.1", 0)
	var nonfinite_delta := sampler.sample_physics_frame(INF, 0)
	_check(
		not stale.accepted and stale.reason == &"stale_generation"
		and not malformed_delta.accepted and malformed_delta.reason == &"invalid_physics_delta"
		and not nonfinite_delta.accepted and nonfinite_delta.reason == &"invalid_physics_delta"
		and provider.call_order.is_empty()
		and bank.get_snapshot().actions[&"fire"].sample_count == 0,
		"stale, malformed, and nonfinite ticks fail before provider access or bank mutation"
	)
	bank.reset(0)
	var retired := sampler.sample_physics_frame(0.1, 0)
	_check(
		not retired.accepted
		and retired.reason == &"stale_generation"
		and provider.call_order.is_empty(),
		"whole-bank generation replacement retires sampler calls carrying the old generation"
	)


func _test_provider_failures_are_atomic() -> void:
	var bank := Bank.new(_profile(ACTION_ORDER))
	bank.attach(0)
	var malformed := CountingProvider.new()
	malformed.strengths = {&"brake": "bad", &"fire": NAN, &"interact": 1.0}
	malformed.pressed = {&"brake": true, &"fire": true, &"interact": "pressed"}
	var sampler := Sampler.new(bank, malformed)
	var initial := bank.get_snapshot()
	var rejected := sampler.sample_physics_frame(0.25, 0)
	_check(
		not rejected.accepted
		and rejected.reason == &"malformed_provider_sample"
		and rejected.failed_action == &"brake"
		and rejected.failed_method == &"get_action_strength"
		and _all_action_counts_equal(malformed.strength_calls, 1)
		and _all_action_counts_equal(malformed.pressed_calls, 1)
		and bank.get_snapshot() == initial,
		"malformed provider output still completes one read per roster member but commits no partial frame"
	)

	var nonfinite := CountingProvider.new()
	nonfinite.strengths = {&"brake": 0.0, &"fire": INF, &"interact": 0.0}
	var nonfinite_result := Sampler.new(bank, nonfinite).sample_physics_frame(0.25, 0)
	_check(
		not nonfinite_result.accepted
		and nonfinite_result.reason == &"non_finite_provider_sample"
		and nonfinite_result.failed_action == &"fire"
		and bank.get_snapshot() == initial,
		"nonfinite provider strength fails the complete frame without clamping or mutation"
	)

	var missing_method := StrengthOnlyProvider.new()
	var missing_result := Sampler.new(bank, missing_method).sample_physics_frame(0.25, 0)
	_check(
		not missing_result.accepted
		and missing_result.reason == &"provider_missing_method"
		and missing_result.failed_method == &"is_action_pressed"
		and missing_method.calls == 0
		and bank.get_snapshot() == initial,
		"an incomplete provider is rejected before its available method can be called"
	)


func _test_production_input_default() -> void:
	var bank := Bank.new(_profile([&"fire"]))
	bank.attach(0)
	var sampler := Sampler.new(bank)
	var audit := sampler.audit()
	var frame := sampler.sample_physics_frame(0.0, 0)
	_check(
		audit.provider_mode == &"production_input"
		and audit.provider_valid
		and frame.accepted
		and frame.action_order == [&"fire"]
		and frame.actions[&"fire"].sample_count == 1,
		"without injection the same seam samples Godot's production Input singleton"
	)


func _profile(insertion_order: Array[StringName]) -> InputBindingProfile:
	var bindings := {}
	var options := {}
	for action_id: StringName in insertion_order:
		bindings[action_id] = []
		match action_id:
			&"brake": options[action_id] = _options(0.5, Profile.CURVE_SQUARED, Profile.TOGGLE)
			&"fire": options[action_id] = _options(0.2, Profile.CURVE_LINEAR, Profile.HOLD)
			_: options[action_id] = Profile.default_action_options()
	return Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": bindings,
		"action_options": options,
	})


func _options(deadzone: float, curve: StringName, hold_mode: StringName) -> Dictionary:
	return {"deadzone": deadzone, "curve": curve, "hold_mode": hold_mode}


func _all_action_counts_equal(counts: Dictionary, expected: int) -> bool:
	if counts.size() != ACTION_ORDER.size():
		return false
	for action_id: StringName in ACTION_ORDER:
		if int(counts.get(action_id, 0)) != expected:
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("INPUT_ACTION_TRANSFORM_SAMPLER_TEST_OK")
		quit(0)
	else:
		print("INPUT_ACTION_TRANSFORM_SAMPLER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
