extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Transform := preload("res://scripts/settings/input_action_transform.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_profile_contract_and_deep_audit()
	_test_linear_hold_and_input_edges()
	_test_squared_toggle_semantics()
	await _test_generation_and_detach_reentry()
	_test_fail_closed_numeric_boundary_and_input_map_neutrality()
	_finish()


func _test_profile_contract_and_deep_audit() -> void:
	var profile := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {&"fire": []},
		"action_options": {
			&"fire": {"deadzone": 0.2, "curve": Profile.CURVE_LINEAR, "hold_mode": Profile.HOLD},
		},
	})
	var transform := Transform.from_profile(profile, &"fire")
	var audit := transform.audit()
	_check(
		transform.is_configuration_valid()
		and audit.valid
		and audit.profile_schema_version == Profile.SCHEMA_VERSION
		and audit.action_options == profile.get_action_options(&"fire"),
		"a normalized profile action configures the executable transform without translating option IDs"
	)
	_check(
		audit.supported_curves == [Profile.CURVE_LINEAR, Profile.CURVE_SQUARED]
		and audit.supported_hold_modes == [Profile.HOLD, Profile.TOGGLE],
		"the executable roster is exactly the profile's linear/squared and hold/toggle vocabulary"
	)
	_check(
		audit.uses_caller_physics_delta
		and not audit.reads_input_map
		and not audit.mutates_input_map
		and not audit.gameplay_authority
		and not audit.player_authority
		and not audit.ship_authority
		and not audit.hud_authority
		and not audit.game_flow_authority,
		"the audit freezes caller timing and zero InputMap, Player, ship, HUD, GameFlow, or gameplay authority"
	)

	(audit.action_options as Dictionary)["deadzone"] = 0.9
	((audit.snapshot as Dictionary).action_options as Dictionary)["curve"] = &"mutated"
	var snapshot := transform.get_snapshot()
	(snapshot.action_options as Dictionary)["hold_mode"] = &"mutated"
	_check(
		is_equal_approx(float(transform.get_action_options().deadzone), 0.2)
		and transform.get_action_options().curve == Profile.CURVE_LINEAR
		and transform.get_action_options().hold_mode == Profile.HOLD,
		"audit, embedded snapshot, and public snapshot trees are deeply detached from transform authority"
	)

	var missing_action := Transform.from_profile(profile, &"brake")
	var invalid_options := Transform.new(&"fire", {"deadzone": 0.2, "curve": &"cubic", "hold_mode": Profile.HOLD})
	var empty_action := Transform.new(&"", Profile.default_action_options())
	_check(
		not missing_action.is_configuration_valid()
		and not invalid_options.is_configuration_valid()
		and not empty_action.is_configuration_valid()
		and not bool(missing_action.attach(0).accepted),
		"missing actions, unsupported profile IDs, and empty action IDs fail closed without default substitution"
	)


func _test_linear_hold_and_input_edges() -> void:
	var transform := Transform.new(
		&"fire",
		{"deadzone": 0.2, "curve": Profile.CURVE_LINEAR, "hold_mode": Profile.HOLD},
	)
	_check(transform.attach(0).accepted, "a valid transform attaches at its exact initial generation")
	var noise := transform.process_sample(0.19, true, 0.25, 0)
	var boundary := transform.process_sample(0.2, true, 0.25, 0)
	_check(
		noise.accepted
		and not noise.physical_pressed
		and is_zero_approx(float(noise.value))
		and not boundary.physical_pressed
		and not boundary.just_pressed,
		"pressed scalar noise at or below the stored deadzone is inactive and creates no edge"
	)
	var pressed := transform.process_sample(0.6, true, 0.25, 0)
	_check(
		pressed.physical_just_pressed
		and pressed.just_pressed
		and pressed.pressed
		and is_equal_approx(float(pressed.transformed_scalar), 0.5)
		and is_equal_approx(float(pressed.value), 0.5)
		and is_equal_approx(float(pressed.physical_hold_seconds), 0.25)
		and is_equal_approx(float(pressed.hold_seconds), 0.25),
		"linear hold remaps signed magnitude outside the deadzone and starts caller-physics hold time"
	)
	var reversed := transform.process_sample(-0.6, true, 0.25, 0)
	_check(
		not reversed.physical_just_pressed
		and reversed.pressed
		and is_equal_approx(float(reversed.value), -0.5)
		and is_equal_approx(float(reversed.hold_seconds), 0.5),
		"a held signed input can change direction without manufacturing another press"
	)
	var before_echo := transform.get_snapshot()
	var echo := transform.process_sample(1.0, true, 9.0, 0, true)
	_check(
		echo.accepted
		and echo.reason == &"echo_ignored"
		and not echo.just_pressed
		and not echo.physical_just_pressed
		and echo.sample_count == before_echo.sample_count
		and is_equal_approx(float(echo.elapsed_seconds), float(before_echo.elapsed_seconds))
		and is_equal_approx(float(echo.value), float(before_echo.value)),
		"echo clears edge visibility but cannot double-toggle, resample, or advance caller physics time"
	)
	var clamped := transform.process_sample(4.0, true, 0.25, 0)
	_check(
		clamped.raw_scalar_was_clamped
		and is_equal_approx(float(clamped.raw_scalar), 1.0)
		and is_equal_approx(float(clamped.value), 1.0),
		"finite raw strength is deterministically clamped before transform execution"
	)
	var released := transform.process_sample(0.0, false, 0.25, 0)
	var repeated_release := transform.process_sample(0.0, false, 0.25, 0)
	_check(
		released.physical_just_released
		and released.just_released
		and not released.pressed
		and is_zero_approx(float(released.hold_seconds))
		and not repeated_release.physical_just_released
		and not repeated_release.just_released,
		"release produces one physical and logical edge and repeated release is idempotent"
	)


func _test_squared_toggle_semantics() -> void:
	var transform := Transform.new(
		&"brake",
		{"deadzone": 0.5, "curve": Profile.CURVE_SQUARED, "hold_mode": Profile.TOGGLE},
	)
	transform.attach(0)
	var toggled_on := transform.process_sample(-0.75, true, 0.1, 0)
	_check(
		is_equal_approx(float(toggled_on.transformed_scalar), -0.25)
		and toggled_on.physical_just_pressed
		and toggled_on.just_pressed
		and toggled_on.toggle_latched
		and toggled_on.pressed
		and is_equal_approx(float(toggled_on.value), 1.0),
		"squared response is sign-preserving while the first physical edge latches boolean output on"
	)
	var held := transform.process_sample(-1.0, true, 0.2, 0)
	_check(
		held.toggle_latched
		and not held.just_pressed
		and is_equal_approx(float(held.physical_hold_seconds), 0.3)
		and is_equal_approx(float(held.hold_seconds), 0.3),
		"held and repeated pressed samples cannot retrigger a toggle"
	)
	var released := transform.process_sample(0.0, false, 0.2, 0)
	_check(
		released.physical_just_released
		and not released.just_released
		and released.pressed
		and released.toggle_latched
		and is_zero_approx(float(released.physical_hold_seconds))
		and is_equal_approx(float(released.hold_seconds), 0.5),
		"physical release rearms toggle input while latched logical hold continues on caller delta"
	)
	var at_deadzone := transform.process_sample(0.5, true, 0.1, 0)
	_check(
		not at_deadzone.physical_pressed and at_deadzone.toggle_latched,
		"deadzone noise cannot become the rearmed press that changes a toggle"
	)
	var toggled_off := transform.process_sample(0.75, true, 0.1, 0)
	_check(
		toggled_off.physical_just_pressed
		and not toggled_off.just_pressed
		and toggled_off.just_released
		and not toggled_off.pressed
		and not toggled_off.toggle_latched
		and is_zero_approx(float(toggled_off.value))
		and is_zero_approx(float(toggled_off.hold_seconds)),
		"the next post-release physical edge latches output off and reports one logical release"
	)


func _test_generation_and_detach_reentry() -> void:
	var transform := Transform.new(&"fire", Profile.default_action_options())
	var initial := transform.get_snapshot()
	_check(
		not bool(transform.process_sample(1.0, true, 1.0, 0).accepted)
		and transform.get_snapshot() == initial,
		"sampling while detached is rejected with no state change"
	)
	transform.attach(0)
	transform.process_sample(1.0, true, 0.125, 0)
	var attached_state := transform.get_snapshot()
	transform.detach(0)
	var detached_state := transform.get_snapshot()
	await process_frame
	await process_frame
	_check(
		transform.get_snapshot() == detached_state
		and detached_state.sample_count == attached_state.sample_count
		and is_equal_approx(float(detached_state.elapsed_seconds), float(attached_state.elapsed_seconds))
		and detached_state.pressed
		and not detached_state.just_pressed,
		"detach retains persistent state, clears transient edges, and process frames cannot advance caller physics time"
	)
	var before_detached_rejection := transform.get_snapshot()
	_check(
		not bool(transform.process_sample(0.0, false, 0.5, 0).accepted)
		and transform.get_snapshot() == before_detached_rejection,
		"a release cannot mutate a detached transform"
	)
	_check(
		not bool(transform.attach(1).accepted)
		and transform.attach(0).accepted
		and transform.get_snapshot().pressed,
		"stale re-entry is rejected and exact-generation re-entry retains live transform state"
	)
	var before_stale_reset := transform.get_snapshot()
	_check(
		not bool(transform.reset(4).accepted)
		and transform.get_snapshot() == before_stale_reset,
		"a stale reset cannot mutate generation or sampled state"
	)
	var reset := transform.reset(0)
	_check(
		reset.accepted
		and reset.generation == 1
		and reset.attached
		and reset.sample_count == 0
		and not reset.pressed
		and is_zero_approx(float(reset.elapsed_seconds)),
		"an exact reset advances generation and atomically clears every sampled field"
	)
	var after_reset := transform.get_snapshot()
	_check(
		not bool(transform.process_sample(1.0, true, 0.25, 0).accepted)
		and transform.get_snapshot() == after_reset,
		"callbacks carrying a retired generation cannot enter the reset transform"
	)
	transform.detach(1)
	var detached_reset := transform.reset(1)
	_check(
		detached_reset.accepted and detached_reset.generation == 2 and not detached_reset.attached,
		"a detached owner may invalidate retained state without implicitly reattaching it"
	)


func _test_fail_closed_numeric_boundary_and_input_map_neutrality() -> void:
	var action := &"fire"
	var input_map_had_action := InputMap.has_action(action)
	var input_map_deadzone := InputMap.action_get_deadzone(action) if input_map_had_action else 0.0
	var input_map_events := InputMap.action_get_events(action) if input_map_had_action else []
	var transform := Transform.new(action, Profile.default_action_options())
	transform.attach(0)
	var initial := transform.get_snapshot()
	_check(
		not bool(transform.process_sample(NAN, true, 0.1, 0).accepted)
		and transform.get_snapshot() == initial
		and not bool(transform.process_sample(INF, true, 0.1, 0).accepted)
		and transform.get_snapshot() == initial
		and not bool(transform.process_sample(1.0, true, -0.1, 0).accepted)
		and transform.get_snapshot() == initial
		and not bool(transform.process_sample(1.0, true, INF, 0).accepted)
		and transform.get_snapshot() == initial,
		"NaN, infinity, and negative caller delta reject atomically"
	)
	var huge := transform.process_sample(1.0, true, 1.0e308, 0)
	var before_overflow := transform.get_snapshot()
	_check(
		huge.accepted
		and not bool(transform.process_sample(1.0, true, 1.0e308, 0).accepted)
		and transform.get_snapshot() == before_overflow,
		"finite samples whose accumulated physics time would overflow reject before mutation"
	)

	var closed_deadzone := Transform.new(
		action,
		{"deadzone": 1.0, "curve": Profile.CURVE_LINEAR, "hold_mode": Profile.HOLD},
	)
	closed_deadzone.attach(0)
	var below := closed_deadzone.process_sample(0.999, true, 0.0, 0)
	var full := closed_deadzone.process_sample(1.0, true, 0.0, 0)
	_check(
		not below.pressed
		and not full.pressed
		and is_zero_approx(float(full.transformed_scalar))
		and is_zero_approx(float(full.value)),
		"the profile's inclusive deadzone-one bound deterministically closes the normalized range"
	)
	_check(
		InputMap.has_action(action) == input_map_had_action
		and (not input_map_had_action or is_equal_approx(InputMap.action_get_deadzone(action), input_map_deadzone))
		and (not input_map_had_action or InputMap.action_get_events(action) == input_map_events),
		"processing and lifecycle operations leave the live InputMap byte-for-byte untouched"
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("INPUT_ACTION_TRANSFORM_TEST_OK")
		quit(0)
	else:
		print("INPUT_ACTION_TRANSFORM_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
