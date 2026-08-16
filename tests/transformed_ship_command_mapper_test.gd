extends SceneTree

const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Bank := preload("res://scripts/settings/input_action_transform_bank.gd")
const Sampler := preload("res://scripts/settings/input_action_transform_sampler.gd")
const Mapper := preload("res://scripts/control/transformed_ship_command_mapper.gd")

const FULL_ACTION_ORDER: Array[StringName] = [
	&"barrel_roll", &"brake", &"camera_distance_in", &"camera_distance_out",
	&"fire", &"hover", &"interact", &"jump", &"landing_assist", &"move_back",
	&"move_forward", &"move_left", &"move_right", &"pause", &"pitch_down",
	&"pitch_up", &"roll_left", &"roll_right", &"sprint_boost",
	&"toggle_controls_overlay", &"toggle_first_person", &"toggle_ship_camera_view",
]

var _failures: Array[String] = []


class FakeProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return bool(pressed.get(action, false))

	func set_action(action: StringName, strength: float, is_pressed: bool = true) -> void:
		strengths[action] = strength
		pressed[action] = is_pressed


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_exact_flight_mapping()
	_test_edge_and_toggle_semantics()
	_test_fail_closed_validation()
	_test_audit_and_source_boundary()
	_finish()


func _test_exact_flight_mapping() -> void:
	var fixture := _fixture()
	var provider := fixture.provider as FakeProvider
	provider.set_action(&"move_forward", 0.8)
	provider.set_action(&"move_back", 0.1)
	provider.set_action(&"move_right", 0.7)
	provider.set_action(&"move_left", 0.2)
	provider.set_action(&"pitch_up", 0.6)
	provider.set_action(&"pitch_down", 0.1)
	provider.set_action(&"roll_left", 0.65)
	provider.set_action(&"roll_right", 0.15)
	for action: StringName in [
		&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
		&"landing_assist", &"interact", &"toggle_ship_camera_view",
		&"camera_distance_out", &"jump", &"pause", &"toggle_first_person",
	]:
		provider.set_action(action, 1.0)
	var frame := (fixture.sampler as InputActionTransformSampler).sample_physics_frame(0.25, 0)
	var original_frame := frame.duplicate(true)
	var mapped := (fixture.mapper as TransformedShipCommandMapper).map_frame(frame, 0, 7, 1234, 3)
	var command := mapped.command as ShipCommand
	_check(
		mapped.accepted and mapped.reason == &"mapped"
		and mapped.frame_generation == 0 and is_equal_approx(mapped.physics_delta, 0.25)
		and command.sequence == 7 and command.timestamp_usec == 1234 and command.stream_id == 3
		and command.is_valid(),
		"an accepted detached sampler frame maps into valid caller-owned ShipCommand metadata",
	)
	_check(
		is_equal_approx(command.throttle, 0.7)
		and is_equal_approx(command.yaw, 0.5)
		and is_equal_approx(command.pitch, 0.5)
		and is_equal_approx(command.roll, -0.5),
		"the exact opposing flight actions produce the established signed throttle/yaw/pitch/roll axes",
	)
	_check(
		command.boost and command.brake and command.hover and command.fire
		and command.barrel_roll and command.landing and command.interact
		and command.camera_toggle and command.camera_distance_delta == 1.0,
		"logical held and just-pressed outputs map to the established held, lifecycle, and camera fields",
	)
	_check(
		not command.engine_start and not command.engine_stop
		and is_zero_approx(command.look_yaw_delta)
		and is_zero_approx(command.look_pitch_delta),
		"automatic propulsion never emits retired engine actions and action frames cannot invent mouse motion",
	)
	_check(
		frame == original_frame,
		"mapping retains no aliases and never mutates its detached source frame",
	)

	var second_frame := (fixture.sampler as InputActionTransformSampler).sample_physics_frame(0.1, 0)
	var second := (fixture.mapper as TransformedShipCommandMapper).map_frame(second_frame, 0, 8, 1235, 3)
	var second_command := second.command as ShipCommand
	_check(
		second_command.boost and second_command.fire
		and not second_command.barrel_roll and not second_command.landing
		and not second_command.interact and not second_command.camera_toggle
		and is_zero_approx(second_command.camera_distance_delta),
		"held intent repeats while one-shot and camera-distance edges do not replay",
	)


func _test_edge_and_toggle_semantics() -> void:
	var fixture := _fixture({&"sprint_boost": Profile.TOGGLE})
	var provider := fixture.provider as FakeProvider
	provider.set_action(&"sprint_boost", 1.0)
	provider.set_action(&"camera_distance_in", 1.0)
	provider.set_action(&"camera_distance_out", 1.0)
	var first := _sample_and_map(fixture, 0, 1)
	_check(
		(first.command as ShipCommand).boost
		and is_zero_approx((first.command as ShipCommand).camera_distance_delta),
		"logical toggle state drives held intent and simultaneous distance edges cancel",
	)
	provider.set_action(&"sprint_boost", 0.0, false)
	provider.set_action(&"camera_distance_in", 0.0, false)
	provider.set_action(&"camera_distance_out", 0.0, false)
	var released := _sample_and_map(fixture, 0, 2)
	_check((released.command as ShipCommand).boost, "a released toggle remains active through transformed logical state")
	provider.set_action(&"sprint_boost", 1.0)
	var toggled_off := _sample_and_map(fixture, 0, 3)
	_check(not (toggled_off.command as ShipCommand).boost, "the next physical press switches transformed toggle intent off")

	var edge_modes := {}
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_in", &"camera_distance_out",
	]:
		edge_modes[action] = Profile.TOGGLE
	var edge_fixture := _fixture(edge_modes)
	var edge_provider := edge_fixture.provider as FakeProvider
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_in",
	]:
		edge_provider.set_action(action, 1.0)
	var first_edges := _sample_and_map(edge_fixture, 0, 4).command as ShipCommand
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_in",
	]:
		edge_provider.set_action(action, 0.0, false)
	_sample_and_map(edge_fixture, 0, 5)
	for action: StringName in [
		&"barrel_roll", &"landing_assist", &"interact",
		&"toggle_ship_camera_view", &"camera_distance_in",
	]:
		edge_provider.set_action(action, 1.0)
	var second_edges := _sample_and_map(edge_fixture, 0, 6).command as ShipCommand
	_check(
		first_edges.barrel_roll and second_edges.barrel_roll
		and first_edges.landing and second_edges.landing
		and first_edges.interact and second_edges.interact
		and first_edges.camera_toggle and second_edges.camera_toggle
		and first_edges.camera_distance_delta == -1.0
		and second_edges.camera_distance_delta == -1.0,
		"toggle options cannot suppress every other physical barrel, lifecycle, camera-toggle, or distance-in edge",
	)

	var out_fixture := _fixture(edge_modes)
	var out_provider := out_fixture.provider as FakeProvider
	out_provider.set_action(&"camera_distance_out", 1.0)
	var first_out := _sample_and_map(out_fixture, 0, 7).command as ShipCommand
	out_provider.set_action(&"camera_distance_out", 0.0, false)
	_sample_and_map(out_fixture, 0, 8)
	out_provider.set_action(&"camera_distance_out", 1.0)
	var second_out := _sample_and_map(out_fixture, 0, 9).command as ShipCommand
	_check(
		first_out.camera_distance_delta == 1.0 and second_out.camera_distance_delta == 1.0,
		"toggle options cannot suppress every other physical distance-out edge",
	)


func _test_fail_closed_validation() -> void:
	var fixture := _fixture()
	var provider := fixture.provider as FakeProvider
	provider.set_action(&"fire", 1.0)
	var frame := (fixture.sampler as InputActionTransformSampler).sample_physics_frame(0.1, 0)
	var mapper := fixture.mapper as TransformedShipCommandMapper

	var stale := mapper.map_frame(frame, 1, 10, 20, 2)
	var malformed_metadata := mapper.map_frame(frame, 0, -1, 20, 2)
	var rejected_frame := frame.duplicate(true)
	rejected_frame.accepted = false
	rejected_frame.reason = &"provider_failed"
	var upstream := mapper.map_frame(rejected_frame, 0, 10, 20, 2)
	_check(
		not stale.accepted and stale.reason == &"stale_frame_generation" and (stale.command as ShipCommand).is_neutral()
		and not malformed_metadata.accepted and malformed_metadata.reason == &"invalid_command_metadata"
		and (malformed_metadata.command as ShipCommand).is_neutral()
		and not upstream.accepted and upstream.reason == &"upstream_rejected"
		and (upstream.command as ShipCommand).is_neutral(),
		"stale generations, invalid transport metadata, and rejected upstream samples fail to neutral commands",
	)

	var missing := frame.duplicate(true)
	(missing.action_order as Array).erase(&"fire")
	(missing.actions as Dictionary).erase(&"fire")
	missing.action_count = int(missing.action_count) - 1
	var missing_result := mapper.map_frame(missing, 0, 10, 20, 2)
	var nonfinite := frame.duplicate(true)
	(nonfinite.actions[&"fire"] as Dictionary).value = INF
	var nonfinite_result := mapper.map_frame(nonfinite, 0, 10, 20, 2)
	var inconsistent := frame.duplicate(true)
	(inconsistent.actions[&"fire"] as Dictionary).pressed = false
	var inconsistent_result := mapper.map_frame(inconsistent, 0, 10, 20, 2)
	_check(
		not missing_result.accepted and missing_result.reason == &"missing_flight_action"
		and missing_result.failed_action == &"fire"
		and not nonfinite_result.accepted and nonfinite_result.reason == &"malformed_action_snapshot"
		and nonfinite_result.failed_action == &"fire"
		and not inconsistent_result.accepted and inconsistent_result.reason == &"invalid_action_snapshot"
		and (inconsistent_result.command as ShipCommand).is_neutral(),
		"missing, nonfinite, and semantically inconsistent action snapshots cannot synthesize a command",
	)

	var reordered := frame.duplicate(true)
	(reordered.action_order as Array).reverse()
	var reordered_result := mapper.map_frame(reordered, 0, 10, 20, 2)
	var injected := frame.duplicate(true)
	injected["engine_start"] = true
	var injected_result := mapper.map_frame(injected, 0, 10, 20, 2)
	_check(
		not reordered_result.accepted and reordered_result.reason == &"malformed_frame"
		and not injected_result.accepted and injected_result.reason == &"malformed_frame"
		and (injected_result.command as ShipCommand).is_neutral(),
		"noncanonical frame order and injected top-level authority fail the exact sampler-frame schema",
	)


func _test_audit_and_source_boundary() -> void:
	var mapper := Mapper.new()
	var audit := mapper.audit()
	_check(
		audit.valid and audit.flight_action_count == 18
		and audit.flight_action_order == Mapper.FLIGHT_ACTION_ORDER
		and not audit.automatic_engine_start_emitted and not audit.automatic_engine_stop_emitted,
		"the audit freezes the exact 18-action ship-facing roster and automatic-engine boundary",
	)
	_check(
		not audit.mouse_look_motion_authority and not audit.reads_input and not audit.reads_input_map
		and not audit.owns_physics_timing and not audit.owns_command_sequence
		and not audit.owns_command_delivery and not audit.owns_device_selection
		and not audit.owns_game_flow and not audit.owns_ship,
		"the mapper owns no input polling, timing, transport delivery, device, GameFlow, or ship authority",
	)
	var source := FileAccess.get_file_as_string("res://scripts/control/transformed_ship_command_mapper.gd")
	_check(
		not "Input." in source and not "InputMap" in source
		and not "_process(" in source and not "_physics_process(" in source
		and not "engine_start_action" in source and not "engine_stop_action" in source,
		"the implementation contains no hidden polling, process loop, or retired engine action mapping",
	)


func _fixture(hold_modes: Dictionary = {}) -> Dictionary:
	var bindings := {}
	var options := {}
	for action_id: StringName in FULL_ACTION_ORDER:
		bindings[action_id] = []
		options[action_id] = {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": hold_modes.get(action_id, Profile.HOLD),
		}
	var profile := Profile.from_dictionary({
		"schema_version": Profile.SCHEMA_VERSION,
		"bindings": bindings,
		"action_options": options,
	})
	var bank := Bank.new(profile)
	bank.attach(bank.get_generation())
	var provider := FakeProvider.new()
	return {
		"bank": bank,
		"provider": provider,
		"sampler": Sampler.new(bank, provider),
		"mapper": Mapper.new(),
	}


func _sample_and_map(fixture: Dictionary, generation: int, sequence: int) -> Dictionary:
	var frame := (fixture.sampler as InputActionTransformSampler).sample_physics_frame(0.1, generation)
	return (fixture.mapper as TransformedShipCommandMapper).map_frame(frame, generation, sequence, sequence, 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TRANSFORMED_SHIP_COMMAND_MAPPER_TEST_OK")
		quit(0)
	else:
		print("TRANSFORMED_SHIP_COMMAND_MAPPER_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
