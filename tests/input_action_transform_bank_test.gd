extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Bank := preload("res://scripts/settings/input_action_transform_bank.gd")

const ACTION_ORDER: Array[StringName] = [&"brake", &"fire", &"interact"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_complete_profile_and_deterministic_audit()
	_test_per_action_sampling_and_rejections()
	_test_atomic_complete_frame()
	_test_atomic_profile_replacement()
	await _test_reset_detach_and_reentry()
	_test_input_map_neutrality()
	_finish()


func _test_complete_profile_and_deterministic_audit() -> void:
	var profile := _profile(
		[&"interact", &"fire", &"brake"],
		{
			&"brake": _options(0.5, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"fire": _options(0.2, Profile.CURVE_LINEAR, Profile.HOLD),
			&"interact": _options(0.18, Profile.CURVE_LINEAR, Profile.HOLD),
		},
	)
	var bank := Bank.new(profile)
	var audit := bank.audit()
	_check(
		bank.is_configuration_valid()
		and bank.get_generation() == 0
		and not bool(bank.get_snapshot().attached)
		and bank.get_action_order() == ACTION_ORDER
		and audit.action_order == ACTION_ORDER
		and audit.action_count == 3,
		"a complete validated profile creates one initially detached child per deterministic sorted action"
	)
	_check(
		audit.exact_action_roster_enforced
		and audit.atomic_profile_replacement
		and audit.atomic_whole_profile_reset
		and audit.uses_input_action_transform
		and audit.uses_caller_physics_delta,
		"the audit freezes exact roster, atomic lifecycle, child-transform reuse, and caller-physics ownership"
	)
	_check(
		not audit.reads_input_map
		and not audit.mutates_input_map
		and not audit.infers_devices
		and not audit.gameplay_authority
		and not audit.player_authority
		and not audit.ship_authority
		and not audit.hud_authority
		and not audit.game_flow_authority,
		"the bank owns no InputMap, device inference, Player, ship, HUD, GameFlow, or gameplay authority"
	)
	var child_audits := audit.child_audits as Dictionary
	_check(
		child_audits.keys() == ACTION_ORDER
		and child_audits[&"brake"].action_options == profile.get_action_options(&"brake")
		and child_audits[&"fire"].action_options == profile.get_action_options(&"fire"),
		"child audits preserve sorted insertion and the exact per-action normalized options"
	)

	var snapshot := bank.get_snapshot()
	(snapshot.action_order as Array)[0] = &"mutated"
	((snapshot.actions as Dictionary)[&"brake"] as Dictionary)["toggle_latched"] = true
	(((snapshot.profile as Dictionary).action_options as Dictionary)[&"fire"] as Dictionary)["deadzone"] = 0.9
	((audit.child_audits as Dictionary)[&"interact"] as Dictionary)["action_id"] = &"mutated"
	profile.set_action_options(&"fire", _options(0.8, Profile.CURVE_SQUARED, Profile.TOGGLE))
	_check(
		bank.get_action_order() == ACTION_ORDER
		and not bool(bank.get_snapshot().actions[&"brake"].toggle_latched)
		and is_equal_approx(float(bank.get_profile().get_action_options(&"fire").deadzone), 0.2)
		and bank.audit().child_audits[&"interact"].action_id == &"interact",
		"profile, bank snapshot, embedded profile, and child audit trees are deeply detached"
	)

	var incomplete := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {&"fire": []},
		"action_options": {
			&"fire": Profile.default_action_options(),
			&"orphan": Profile.default_action_options(),
		},
	})
	var empty := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {},
		"action_options": {},
	})
	_check(
		incomplete != null
		and not Bank.new(incomplete).is_configuration_valid()
		and not Bank.new(empty).is_configuration_valid()
		and not Bank.new(null).is_configuration_valid(),
		"option-only, empty, and missing profiles fail closed before any partial child bank exists"
	)


func _test_per_action_sampling_and_rejections() -> void:
	var bank := Bank.new(_default_profile())
	_check(bank.attach(0).accepted, "the complete bank attaches at its exact initial generation")
	var fire := bank.process_action_sample(&"fire", 0.6, true, 0.25, 0)
	var brake := bank.process_action_sample(&"brake", -0.75, true, 0.1, 0)
	_check(
		fire.accepted
		and fire.action_id == &"fire"
		and is_equal_approx(float(fire.action_snapshot.value), 0.5)
		and fire.action_snapshot.just_pressed
		and brake.accepted
		and is_equal_approx(float(brake.action_snapshot.transformed_scalar), -0.25)
		and brake.action_snapshot.toggle_latched
		and is_equal_approx(float(brake.action_snapshot.value), 1.0),
		"explicit action samples delegate exact linear-hold and squared-toggle math to independent children"
	)
	var whole := bank.get_snapshot()
	_check(
		whole.actions[&"fire"].sample_count == 1
		and whole.actions[&"brake"].sample_count == 1
		and whole.actions[&"interact"].sample_count == 0
		and is_equal_approx(float(whole.actions[&"fire"].elapsed_seconds), 0.25)
		and is_equal_approx(float(whole.actions[&"brake"].elapsed_seconds), 0.1),
		"per-action sampling cannot advance or manufacture state for unsampled siblings"
	)
	var before_rejections := bank.get_snapshot()
	var stale := bank.process_action_sample(&"fire", 0.0, false, 0.5, 9)
	var unknown := bank.process_action_sample(&"unknown", 1.0, true, 0.5, 0)
	var stale_snapshot := bank.get_action_snapshot(&"fire", 9)
	var unknown_snapshot := bank.get_action_snapshot(&"unknown", 0)
	_check(
		not stale.accepted and stale.reason == &"stale_generation"
		and not unknown.accepted and unknown.reason == &"unknown_action"
		and not stale_snapshot.accepted and stale_snapshot.reason == &"stale_generation"
		and not unknown_snapshot.accepted and unknown_snapshot.reason == &"unknown_action"
		and stale.action_snapshot.is_empty()
		and unknown.action_snapshot.is_empty()
		and bank.get_snapshot() == before_rejections,
		"stale and unknown sampling/inspection reject without exposing or mutating an action"
	)
	var echo := bank.process_action_sample(&"fire", 1.0, true, 4.0, 0, true)
	_check(
		echo.accepted
		and echo.reason == &"echo_ignored"
		and not echo.action_snapshot.just_pressed
		and echo.action_snapshot.sample_count == 1
		and is_equal_approx(float(echo.action_snapshot.elapsed_seconds), 0.25),
		"bank sampling preserves the child transform's edge-safe echo contract"
	)


func _test_atomic_complete_frame() -> void:
	var bank := Bank.new(_default_profile())
	bank.attach(0)
	_check(bank.audit().atomic_complete_frame, "the bank audit publishes its complete-frame transaction boundary")
	var missing := _complete_samples()
	missing.erase(&"interact")
	var initial := bank.get_snapshot()
	var missing_result := bank.process_complete_frame(missing, 0.25, 0)
	_check(
		not missing_result.accepted
		and missing_result.reason == &"action_roster_mismatch"
		and missing_result.missing_actions == [&"interact"]
		and (missing_result.unknown_actions as Array).is_empty()
		and bank.get_snapshot() == initial,
		"a complete frame missing one action rejects before any sibling transform changes"
	)
	var injected := _complete_samples()
	injected.erase(&"interact")
	injected[&"ghost"] = {"raw_scalar": 1.0, "raw_pressed": true}
	var injected_result := bank.process_complete_frame(injected, 0.25, 0)
	_check(
		not injected_result.accepted
		and injected_result.missing_actions == [&"interact"]
		and injected_result.unknown_actions == [&"ghost"]
		and bank.get_snapshot() == initial,
		"an injected action cannot substitute for an exact complete-frame roster member"
	)
	var malformed := _complete_samples()
	malformed[&"fire"] = {"raw_scalar": "strong", "raw_pressed": true}
	var nonfinite := _complete_samples()
	nonfinite[&"fire"] = {"raw_scalar": NAN, "raw_pressed": true}
	_check(
		not bool(bank.process_complete_frame(malformed, 0.25, 0).accepted)
		and bank.get_snapshot() == initial
		and not bool(bank.process_complete_frame(nonfinite, 0.25, 0).accepted)
		and bank.get_snapshot() == initial
		and not bool(bank.process_complete_frame(_complete_samples(), INF, 0).accepted)
		and bank.get_snapshot() == initial,
		"malformed/nonfinite samples and delta reject the whole frame without partial mutation"
	)
	var sampled := bank.process_complete_frame(_complete_samples(), 0.25, 0)
	_check(
		sampled.accepted
		and sampled.action_order == ACTION_ORDER
		and sampled.actions.keys() == ACTION_ORDER
		and sampled.action_count == 3
		and is_equal_approx(float(sampled.actions[&"fire"].value), 0.5)
		and sampled.actions[&"brake"].toggle_latched
		and sampled.actions[&"interact"].sample_count == 1,
		"a valid complete frame commits every action once and returns detached snapshots in stable order"
	)
	(sampled.action_order as Array)[0] = &"mutated"
	(sampled.actions[&"fire"] as Dictionary)["value"] = 99.0
	_check(
		bank.get_action_order() == ACTION_ORDER
		and not is_equal_approx(float(bank.get_snapshot().actions[&"fire"].value), 99.0),
		"the complete transformed frame is deeply detached from the bank"
	)

	var overflow_bank := Bank.new(_default_profile())
	overflow_bank.attach(0)
	overflow_bank.process_action_sample(&"interact", 1.0, true, 1.0e308, 0)
	var before_overflow := overflow_bank.get_snapshot()
	var overflow := overflow_bank.process_complete_frame(_complete_samples(), 1.0e308, 0)
	_check(
		not overflow.accepted
		and overflow.reason == &"non_finite_accumulation"
		and overflow.failed_action == &"interact"
		and overflow_bank.get_snapshot() == before_overflow,
		"a late-roster child overflow is preflighted before earlier actions can commit"
	)


func _test_atomic_profile_replacement() -> void:
	var bank := Bank.new(_default_profile())
	bank.attach(0)
	bank.process_action_sample(&"brake", 1.0, true, 0.2, 0)
	bank.process_action_sample(&"fire", 1.0, true, 0.2, 0)

	var malformed := _default_profile()
	malformed.bindings[&"fire"] = [{"device": &"keyboard", "type": &"key", "physical_keycode": 0}]
	var before_malformed := bank.get_snapshot()
	var malformed_result := bank.replace_profile(malformed, 0)
	_check(
		not malformed_result.accepted
		and malformed_result.reason == &"invalid_profile"
		and bank.get_snapshot() == before_malformed,
		"a malformed replacement is validated completely before it can disturb live actions"
	)

	var missing := _profile(
		[&"brake", &"fire"],
		{
			&"brake": _options(0.5, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"fire": _options(0.2, Profile.CURVE_LINEAR, Profile.HOLD),
		},
	)
	var missing_result := bank.replace_profile(missing, 0)
	_check(
		not missing_result.accepted
		and missing_result.reason == &"action_roster_mismatch"
		and missing_result.missing_actions == [&"interact"]
		and (missing_result.unknown_actions as Array).is_empty()
		and bank.get_snapshot() == before_malformed,
		"a replacement missing an exact action reports the sorted gap and rejects atomically"
	)

	var foreign := _profile(
		[&"brake", &"fire", &"ghost"],
		{
			&"brake": _options(0.5, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"fire": _options(0.2, Profile.CURVE_LINEAR, Profile.HOLD),
			&"ghost": Profile.default_action_options(),
		},
	)
	var foreign_result := bank.replace_profile(foreign, 0)
	_check(
		not foreign_result.accepted
		and foreign_result.reason == &"action_roster_mismatch"
		and foreign_result.missing_actions == [&"interact"]
		and foreign_result.unknown_actions == [&"ghost"]
		and bank.get_snapshot() == before_malformed,
		"injected actions cannot replace omitted roster members or partially enter the bank"
	)

	var replacement := _profile(
		[&"fire", &"interact", &"brake"],
		{
			&"brake": _options(0.1, Profile.CURVE_LINEAR, Profile.HOLD),
			&"fire": _options(0.4, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"interact": _options(0.3, Profile.CURVE_SQUARED, Profile.HOLD),
		},
	)
	var before_preflight := bank.get_snapshot()
	var preflight := bank.validate_profile_replacement(replacement, 0)
	var stale_preflight := bank.validate_profile_replacement(replacement, 1)
	var rejected_preflight := bank.validate_profile_replacement(missing, 0)
	_check(
		preflight.accepted and preflight.reason == &"profile_accepted"
		and not stale_preflight.accepted and stale_preflight.reason == &"stale_generation"
		and not rejected_preflight.accepted
		and rejected_preflight.reason == &"action_roster_mismatch"
		and bank.get_snapshot() == before_preflight,
		"replacement preflight validates exact roster and generation without mutating the live bank",
	)
	var replaced := bank.replace_profile(replacement, 0)
	_check(
		replaced.accepted
		and replaced.reason == &"profile_replaced"
		and replaced.generation == 1
		and replaced.attached
		and replaced.action_order == ACTION_ORDER,
		"a complete same-roster profile replaces all actions together and advances one bank generation"
	)
	var after := bank.get_snapshot()
	var all_clean := true
	for action_id: StringName in ACTION_ORDER:
		var action := after.actions[action_id] as Dictionary
		all_clean = all_clean and action.attached and action.sample_count == 0
		all_clean = all_clean and not action.pressed and not action.toggle_latched
		all_clean = all_clean and not action.just_pressed and not action.just_released
	_check(
		all_clean
		and after.actions[&"fire"].action_options == replacement.get_action_options(&"fire")
		and after.actions[&"brake"].action_options == replacement.get_action_options(&"brake"),
		"replacement creates clean attached children so old held edges and toggles cannot leak across profiles"
	)
	var after_replacement := bank.get_snapshot()
	_check(
		not bool(bank.process_action_sample(&"fire", 1.0, true, 0.1, 0).accepted)
		and bank.get_snapshot() == after_replacement,
		"the retired profile generation cannot sample any replacement action"
	)
	replacement.set_action_options(&"fire", Profile.default_action_options())
	_check(
		is_equal_approx(float(bank.get_profile().get_action_options(&"fire").deadzone), 0.4),
		"accepted replacement data is detached from later caller mutation"
	)


func _test_reset_detach_and_reentry() -> void:
	var bank := Bank.new(_default_profile())
	bank.attach(0)
	bank.process_action_sample(&"brake", 1.0, true, 0.2, 0)
	bank.process_action_sample(&"fire", 1.0, true, 0.2, 0)
	var detached := bank.detach(0)
	_check(
		detached.accepted
		and not detached.attached
		and detached.actions[&"brake"].toggle_latched
		and detached.actions[&"brake"].pressed
		and not detached.actions[&"brake"].just_pressed
		and detached.actions[&"fire"].pressed
		and not detached.actions[&"fire"].just_pressed,
		"whole-bank detach retains persistent state while clearing every child's transient edge"
	)
	var detached_snapshot := bank.get_snapshot()
	await process_frame
	await process_frame
	var detached_sample := bank.process_action_sample(&"fire", 0.0, false, 0.5, 0)
	_check(
		bank.get_snapshot() == detached_snapshot
		and not detached_sample.accepted
		and detached_sample.reason == &"detached",
		"process frames and detached samples cannot advance or release retained action state"
	)
	_check(
		not bool(bank.attach(4).accepted)
		and bank.attach(0).accepted
		and bank.get_snapshot().actions[&"brake"].toggle_latched
		and not bool(bank.get_snapshot().actions[&"brake"].just_pressed),
		"exact-generation re-entry resumes persistent toggles without replaying their activation edge"
	)

	var reset := bank.reset(0)
	var reset_clean := true
	for action_id: StringName in ACTION_ORDER:
		var action := reset.actions[action_id] as Dictionary
		reset_clean = reset_clean and action.attached and action.sample_count == 0
		reset_clean = reset_clean and not action.pressed and not action.toggle_latched
	_check(
		reset.accepted and reset.generation == 1 and reset_clean,
		"attached whole-profile reset advances generation and clears every held value and toggle atomically"
	)
	var after_reset := bank.get_snapshot()
	_check(
		not bool(bank.reset(0).accepted) and bank.get_snapshot() == after_reset,
		"a stale whole-profile reset leaves the new generation unchanged"
	)
	bank.process_action_sample(&"brake", 1.0, true, 0.1, 1)
	bank.detach(1)
	var detached_reset := bank.reset(1)
	_check(
		detached_reset.accepted
		and detached_reset.generation == 2
		and not detached_reset.attached
		and not detached_reset.actions[&"brake"].toggle_latched
		and not detached_reset.actions[&"brake"].pressed
		and bank.attach(2).accepted,
		"detached reset retires retained toggles without implicitly attaching the new generation"
	)


func _test_input_map_neutrality() -> void:
	var action := &"fire"
	var had_action := InputMap.has_action(action)
	var deadzone := InputMap.action_get_deadzone(action) if had_action else 0.0
	var events := InputMap.action_get_events(action) if had_action else []
	var bank := Bank.new(_default_profile())
	bank.attach(0)
	bank.process_action_sample(action, 1.0, true, 0.1, 0)
	bank.reset(0)
	bank.replace_profile(_replacement_profile(), 1)
	bank.detach(2)
	_check(
		InputMap.has_action(action) == had_action
		and (not had_action or is_equal_approx(InputMap.action_get_deadzone(action), deadzone))
		and (not had_action or InputMap.action_get_events(action) == events),
		"profile, sample, reset, replacement, and lifecycle operations leave live InputMap untouched"
	)


func _default_profile() -> InputBindingProfile:
	return _profile(
		[&"interact", &"fire", &"brake"],
		{
			&"brake": _options(0.5, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"fire": _options(0.2, Profile.CURVE_LINEAR, Profile.HOLD),
			&"interact": _options(0.18, Profile.CURVE_LINEAR, Profile.HOLD),
		},
	)


func _replacement_profile() -> InputBindingProfile:
	return _profile(
		[&"fire", &"brake", &"interact"],
		{
			&"brake": _options(0.1, Profile.CURVE_LINEAR, Profile.HOLD),
			&"fire": _options(0.4, Profile.CURVE_SQUARED, Profile.TOGGLE),
			&"interact": _options(0.3, Profile.CURVE_SQUARED, Profile.HOLD),
		},
	)


func _profile(insertion_order: Array[StringName], options: Dictionary) -> InputBindingProfile:
	var bindings := {}
	var ordered_options := {}
	for action_id: StringName in insertion_order:
		bindings[action_id] = []
		ordered_options[action_id] = (options[action_id] as Dictionary).duplicate(true)
	return Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": bindings,
		"action_options": ordered_options,
	})


func _options(deadzone: float, curve: StringName, hold_mode: StringName) -> Dictionary:
	return {"deadzone": deadzone, "curve": curve, "hold_mode": hold_mode}


func _complete_samples() -> Dictionary:
	# Reverse insertion proves the result uses the bank's canonical order.
	return {
		&"interact": {"raw_scalar": 0.0, "raw_pressed": false},
		&"fire": {"raw_scalar": 0.6, "raw_pressed": true},
		&"brake": {"raw_scalar": -0.75, "raw_pressed": true},
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("INPUT_ACTION_TRANSFORM_BANK_TEST_OK")
		quit(0)
	else:
		print("INPUT_ACTION_TRANSFORM_BANK_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
