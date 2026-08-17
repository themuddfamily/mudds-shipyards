extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const LocalSource := preload("res://scripts/control/local_ship_input_source.gd")

var _failures: Array[String] = []


class MutableProvider:
	extends RefCounted

	var strengths := {}
	var pressed := {}
	var malformed := false
	var strength_reads := 0
	var pressed_reads := 0

	func get_action_strength(action: StringName) -> Variant:
		strength_reads += 1
		return "malformed" if malformed else strengths.get(action, 0.0)

	func is_action_pressed(action: StringName) -> Variant:
		pressed_reads += 1
		return "malformed" if malformed else pressed.get(action, false)

	func set_action(action: StringName, strength: float, is_pressed: bool = true) -> void:
		strengths[action] = strength
		pressed[action] = is_pressed


class ReentrantResetProvider:
	extends RefCounted

	var source: LocalShipInputSource
	var reset_once := true

	func get_action_strength(_action: StringName) -> float:
		if reset_once:
			reset_once = false
			source.reset_input_transform_state(source.get_input_profile_generation())
		return 0.0

	func is_action_pressed(_action: StringName) -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_compatibility_and_audit()
	_test_process_stable_authored_defaults()
	_test_profile_replacement_toggle_edges_and_reset()
	_test_toggle_boundary_priming_requires_repress()
	_test_stale_detached_and_malformed_fail_neutral()
	await process_frame
	_finish()


func _test_default_compatibility_and_audit() -> void:
	var source := LocalSource.new() as LocalShipInputSource
	var provider := MutableProvider.new()
	provider.strengths[&"move_forward"] = 0.85
	provider.strengths[&"move_back"] = 0.10
	provider.strengths[&"move_right"] = 0.55
	# Legacy injected providers often exposed button state only: the old source
	# read held buttons independently from analogue strengths.
	provider.pressed[&"fire"] = true
	provider.pressed[&"sprint_boost"] = true
	source.set_input_provider(provider)
	source.look_motion_for_full_axis = 100.0
	source.queue_look_motion(Vector2(25.0, -10.0))
	var command := source.next_command(1000)
	var profile := source.get_input_binding_profile()
	var audit := source.get_input_integration_audit()
	_check(
		source.is_input_configuration_valid()
		and profile != null
		and profile.bindings.size() == 22
		and float(profile.get_action_options(&"move_forward").deadzone) == 0.0
		and profile.get_action_options(&"move_forward").curve == Profile.CURVE_LINEAR
		and profile.get_action_options(&"move_forward").hold_mode == Profile.HOLD,
		"the default validated authored roster uses an identity transform over the established logical Input boundary",
	)
	_check(
		is_equal_approx(command.throttle, 0.75)
		and is_equal_approx(command.yaw, 0.55)
		and command.fire and command.boost
		and is_equal_approx(command.look_yaw_delta, 0.25)
		and is_equal_approx(command.look_pitch_delta, 0.10)
		and not command.engine_start and not command.engine_stop,
		"default injected axes, pressed-only held buttons, mouse backlog, and automatic-engine transport remain behavior-equivalent",
	)
	_check(
		provider.strength_reads == 22 and provider.pressed_reads == 22,
		"the legacy compatibility wrapper still reads each provider method exactly once per action",
	)
	_check(
		audit.valid and audit.uses_transform_bank and audit.uses_transform_sampler
		and audit.uses_ship_command_mapper and audit.preserves_mouse_motion_backlog
		and audit.owns_command_stream and audit.owns_command_sequence
		and audit.owns_command_timestamp and not audit.emits_engine_start
		and not audit.emits_engine_stop,
		"the source audit exposes the transformed composition while retaining command-stream ownership",
	)
	(profile.bindings as Dictionary).clear()
	(audit.profile as Dictionary).clear()
	_check(
		source.get_input_binding_profile().bindings.size() == 22
		and not (source.get_input_integration_audit().profile as Dictionary).is_empty(),
		"profile and audit accessors are detached from retained configuration",
	)
	source.free()


func _test_process_stable_authored_defaults() -> void:
	var first := LocalSource.new() as LocalShipInputSource
	var authored := first.get_authored_input_binding_profile().to_dictionary()
	var original_events := InputMap.action_get_events(&"fire")
	var original_deadzone := InputMap.action_get_deadzone(&"fire")
	InputMap.action_erase_events(&"fire")
	var custom_key := InputEventKey.new()
	custom_key.physical_keycode = KEY_F13
	InputMap.action_add_event(&"fire", custom_key)
	InputMap.action_set_deadzone(&"fire", 0.77)
	var reentered := LocalSource.new() as LocalShipInputSource
	_check(
		reentered.get_authored_input_binding_profile().to_dictionary() == authored,
		"a later source cannot redefine process-stable authored defaults from an already-remapped InputMap",
	)
	InputMap.action_erase_events(&"fire")
	for event: InputEvent in original_events:
		InputMap.action_add_event(&"fire", event)
	InputMap.action_set_deadzone(&"fire", original_deadzone)
	first.free()
	reentered.free()


func _test_profile_replacement_toggle_edges_and_reset() -> void:
	var source := LocalSource.new() as LocalShipInputSource
	var provider := MutableProvider.new()
	source.set_input_provider(provider)
	source.set_input_transform_physics_delta(0.125)
	var custom := source.get_input_binding_profile()
	custom.set_action_options(&"move_forward", {
		"deadzone": 0.2,
		"curve": Profile.CURVE_SQUARED,
		"hold_mode": Profile.HOLD,
	})
	custom.set_action_options(&"sprint_boost", {
		"deadzone": 0.0,
		"curve": Profile.CURVE_LINEAR,
		"hold_mode": Profile.TOGGLE,
	})
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		custom.set_action_options(action, {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": Profile.TOGGLE,
		})
	var initial_generation := source.get_input_profile_generation()
	var initial_stream := source.get_stream_id()
	var replaced := source.replace_input_binding_profile(custom, initial_generation)
	_check(
		replaced.accepted and replaced.reason == &"profile_replaced"
		and source.get_input_profile_generation() == initial_generation + 1
		and source.get_stream_id() > initial_stream
		and is_equal_approx(float(source.get_input_integration_audit().physics_delta), 0.125),
		"a complete exact RuntimeSettings-style profile replacement advances generation and command epoch atomically",
	)

	provider.set_action(&"move_forward", 0.6)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		provider.set_action(action, 1.0)
	# The replacement boundary reprimes already-held one-shots. Release once, then
	# prove both later physical presses survive a toggle-configured logical latch.
	var primed := source.next_command(2000)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		provider.set_action(action, 0.0, false)
	provider.set_action(&"sprint_boost", 0.0, false)
	source.next_command(2001)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		provider.set_action(action, 1.0)
	provider.set_action(&"sprint_boost", 1.0)
	var first_press := source.next_command(2002)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		provider.set_action(action, 0.0, false)
	provider.set_action(&"sprint_boost", 0.0, false)
	var toggle_held := source.next_command(2003)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_out",
	]:
		provider.set_action(action, 1.0)
	provider.set_action(&"sprint_boost", 1.0)
	var second_press := source.next_command(2004)
	_check(
		is_equal_approx(primed.throttle, 0.25)
		and not primed.barrel_roll and not primed.landing
		and first_press.barrel_roll and first_press.landing and first_press.interact
		and first_press.camera_toggle and first_press.camera_distance_delta == 1.0
		and second_press.barrel_roll and second_press.landing and second_press.interact
		and second_press.camera_toggle and second_press.camera_distance_delta == 1.0,
		"configured curve/deadzone execute while every toggle-configured one-shot still follows each physical press",
	)
	_check(
		first_press.boost and toggle_held.boost and not second_press.boost,
		"held boost alone follows configured logical toggle state across press/release/press",
	)

	var before_stale := source.get_input_transform_snapshot()
	var stream_before_stale := source.get_stream_id()
	var stale := source.replace_input_binding_profile(custom, initial_generation)
	var incomplete := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": {&"fire": []},
		"action_options": {&"fire": Profile.default_action_options()},
	})
	var incomplete_result := source.configure_input_binding_profile(incomplete)
	_check(
		not stale.accepted and stale.reason == &"stale_generation"
		and not incomplete_result.accepted and incomplete_result.reason == &"action_roster_mismatch"
		and source.get_input_transform_snapshot() == before_stale
		and source.get_stream_id() == stream_before_stale,
		"stale and incomplete profile replacement change neither bank state nor command authority",
	)
	var reset := source.reset_input_binding_profile(source.get_input_profile_generation())
	provider.set_action(&"sprint_boost", 0.0, false)
	var restored := source.next_command(2005)
	_check(
		reset.accepted and reset.reason == &"profile_reset"
		and is_equal_approx(restored.throttle, 0.6)
		and not restored.boost
		and source.get_input_binding_profile().get_action_options(&"sprint_boost").hold_mode == Profile.HOLD,
		"authored reset restores identity axes and HOLD semantics without a GameFlow or RuntimeSettings mutation",
	)
	source.free()


func _test_toggle_boundary_priming_requires_repress() -> void:
	var source := LocalSource.new() as LocalShipInputSource
	var provider := MutableProvider.new()
	source.set_input_provider(provider)
	root.add_child(source)
	var custom := source.get_input_binding_profile()
	custom.set_action_options(&"sprint_boost", {
		"deadzone": 0.0,
		"curve": Profile.CURVE_LINEAR,
		"hold_mode": Profile.TOGGLE,
	})
	var configured := source.configure_input_binding_profile(custom)
	_check(configured.accepted, "toggle boundary fixture configures")
	source.next_command(2500)
	source.notification(Node.NOTIFICATION_PAUSED)
	provider.set_action(&"sprint_boost", 1.0)
	source.notification(Node.NOTIFICATION_UNPAUSED)
	var resumed := source.next_command(2501)
	provider.set_action(&"sprint_boost", 0.0, false)
	source.next_command(2502)
	provider.set_action(&"sprint_boost", 1.0)
	var repressed := source.next_command(2503)
	_check(
		not resumed.boost and repressed.boost,
		"a toggle pressed while paused is primed without changing its latch and requires one physical repress",
	)

	provider.set_action(&"sprint_boost", 0.0, false)
	source.next_command(2504)
	provider.set_action(&"sprint_boost", 1.0)
	configured = source.configure_input_binding_profile(custom)
	var replaced_while_held := source.next_command(2505)
	provider.set_action(&"sprint_boost", 0.0, false)
	source.next_command(2506)
	provider.set_action(&"sprint_boost", 1.0)
	var replacement_repress := source.next_command(2507)
	_check(
		configured.accepted and not replaced_while_held.boost and replacement_repress.boost,
		"a profile replacement primes an already-held toggle without treating the boundary as a physical press",
	)

	provider.set_action(&"sprint_boost", 0.0, false)
	configured = source.configure_input_binding_profile(custom)
	source.next_command(2508)
	root.remove_child(source)
	provider.set_action(&"sprint_boost", 1.0)
	root.add_child(source)
	var reentered := source.next_command(2509)
	provider.set_action(&"sprint_boost", 0.0, false)
	source.next_command(2510)
	provider.set_action(&"sprint_boost", 1.0)
	var reentry_repress := source.next_command(2511)
	_check(
		configured.accepted and not reentered.boost and reentry_repress.boost,
		"whole-tree detach and re-entry seed a toggle held during detachment without changing its latch",
	)
	source.queue_free()


func _test_stale_detached_and_malformed_fail_neutral() -> void:
	var source := LocalSource.new() as LocalShipInputSource
	var provider := MutableProvider.new()
	provider.set_action(&"fire", 1.0)
	source.set_input_provider(provider)
	source.look_motion_for_full_axis = 100.0
	source.queue_look_motion(Vector2(40.0, -20.0))
	provider.malformed = true
	var snapshot_before := source.get_input_transform_snapshot()
	var malformed := source.next_command(3000)
	_check(
		malformed.is_neutral()
		and source.get_input_transform_snapshot() == snapshot_before
		and provider.strength_reads == 22 and provider.pressed_reads == 22,
		"a malformed provider frame is read atomically and fails to a neutral command without partial transform state",
	)
	provider.malformed = false
	var recovered := source.next_command(3001)
	_check(
		recovered.fire
		and is_equal_approx(recovered.look_yaw_delta, 0.4)
		and is_equal_approx(recovered.look_pitch_delta, 0.2),
		"the valid retry consumes the mouse backlog that the malformed frame could not discard",
	)

	var generation := source.get_input_profile_generation()
	var detached := source.detach_input_transform(generation)
	var detached_command := source.next_command(3002)
	var stale_attach := source.attach_input_transform(generation + 1)
	var attached := source.attach_input_transform(generation)
	_check(
		detached.accepted and detached.reason == &"detached"
		and detached_command.is_neutral()
		and not stale_attach.accepted and stale_attach.reason == &"stale_generation"
		and attached.accepted and attached.reason == &"attached",
		"detached sampling and stale lifecycle generations fail neutral until exact-generation reattachment",
	)
	provider.set_action(&"fire", 0.0, false)
	var reattached := source.next_command(3003)
	_check(
		reattached.is_valid() and not reattached.engine_start and not reattached.engine_stop,
		"exact reattachment resumes valid commands without resurrecting retired engine transport",
	)
	source.free()

	var reentrant_source := LocalSource.new() as LocalShipInputSource
	var reentrant_provider := ReentrantResetProvider.new()
	reentrant_provider.source = reentrant_source
	reentrant_source.set_input_provider(reentrant_provider)
	var generation_before := reentrant_source.get_input_profile_generation()
	var reentrant := reentrant_source.next_command(4000)
	_check(
		reentrant.is_neutral()
		and reentrant_source.get_input_profile_generation() == generation_before + 1
		and reentrant_source.get_stream_id() > 0,
		"a provider-driven generation change makes the collected sampler frame stale and neutralizes the same command",
	)
	reentrant_source.free()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("LOCAL_SHIP_TRANSFORMED_INPUT_TEST_OK")
		quit(0)
	else:
		print("LOCAL_SHIP_TRANSFORMED_INPUT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
