class_name LocalShipInputSource
extends ShipCommandSource

## Local InputMap adapter. Logical action sampling passes through the validated
## InputActionTransformBank/Sampler/ShipCommand mapper path. An injected provider
## with `get_action_strength()` and `is_action_pressed()` drives that exact path
## deterministically.
## Keyboard/gamepad attitude axes are rates. Mouse motion is transported in the
## dedicated normalized per-tick look-delta fields so a consumer never has to
## guess whether a yaw value is a rate or an instantaneous attitude change.
## Camera-distance buttons and mouse-wheel events likewise become a bounded
## signed step stream: negative moves the chase camera nearer, positive farther.

const MAX_PENDING_CAMERA_DISTANCE_STEPS := 32.0
const INPUT_PROVIDER_RAW: StringName = &"raw"
const INPUT_PROVIDER_INPUT_MAP_RESOLVED: StringName = &"input_map_resolved"
const InputBindingProfileType := preload("res://scripts/settings/input_binding_profile.gd")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")
const InputActionTransformBankType := preload("res://scripts/settings/input_action_transform_bank.gd")
const InputActionTransformSamplerType := preload("res://scripts/settings/input_action_transform_sampler.gd")
const TransformedShipCommandMapperType := preload("res://scripts/control/transformed_ship_command_mapper.gd")


## Legacy injected providers commonly supplied analogue strengths without also
## marking those rate axes pressed, and button presses without duplicating them
## into action strength, because the old source read each family independently.
## Preserve that public seam while still giving InputActionTransform coherent
## physical state. Each underlying method is still invoked exactly once/action.
class AxisCompatibleInputProvider:
	extends RefCounted

	var provider: Object
	var axis_actions: Array[StringName]
	var last_strengths := {}
	var prefetched_pressed := {}

	func _init(p_provider: Object, p_axis_actions: Array[StringName]) -> void:
		provider = p_provider
		axis_actions = p_axis_actions.duplicate()

	func get_action_strength(action: StringName) -> Variant:
		if (
			provider == null
			or not is_instance_valid(provider)
			or not provider.has_method(&"get_action_strength")
		):
			return null
		var value: Variant = provider.call(&"get_action_strength", action)
		var normalized: Variant = value
		if (value is float or value is int) and is_finite(float(value)):
			normalized = clampf(float(value), 0.0, 1.0)
			# The sampler asks for strength before pressed. Pre-fetch only a
			# zero-strength button so a pressed-only legacy provider becomes the
			# same scalar=1/pressed=true sample Input would expose. Cache the
			# answer for is_action_pressed() to retain one underlying read.
			if (
				is_zero_approx(float(normalized))
				and not action in axis_actions
				and provider.has_method(&"is_action_pressed")
			):
				var candidate: Variant = provider.call(&"is_action_pressed", action)
				prefetched_pressed[action] = candidate
				if candidate is bool and bool(candidate):
					normalized = 1.0
		last_strengths[action] = normalized
		return normalized

	func is_action_pressed(action: StringName) -> Variant:
		if (
			provider == null
			or not is_instance_valid(provider)
			or not provider.has_method(&"is_action_pressed")
		):
			return null
		var candidate: Variant
		if prefetched_pressed.has(action):
			candidate = prefetched_pressed[action]
			prefetched_pressed.erase(action)
		else:
			candidate = provider.call(&"is_action_pressed", action)
		if not candidate is bool:
			return candidate
		if bool(candidate) or not action in axis_actions:
			return bool(candidate)
		var strength: Variant = last_strengths.get(action)
		return (
			absf(float(strength)) > 0.0
			if (strength is float or strength is int) and is_finite(float(strength))
			else false
		)


## RuntimeSettings applies an action's deadzone to InputMap before this source
## samples it. The returned action strength is therefore already in the logical
## post-InputMap domain used by the pre-transform production path. Lift that
## resolved value into InputActionTransform's deadzone-remap domain so the bank
## can retain the exact profile and apply its curve/hold semantics without
## attenuating the authored default response a second time.
class ResolvedInputProfileProvider:
	extends RefCounted

	var provider: Object
	var deadzones := {}

	func _init(p_provider: Object, profile: InputBindingProfile) -> void:
		provider = p_provider
		if profile == null:
			return
		for action: StringName in profile.bindings:
			deadzones[action] = float(profile.get_action_options(action).deadzone)

	func get_action_strength(action: StringName) -> Variant:
		if provider == null or not is_instance_valid(provider):
			return null
		var candidate: Variant = provider.call(&"get_action_strength", action)
		if not candidate is float and not candidate is int:
			return candidate
		var resolved := clampf(float(candidate), 0.0, 1.0)
		if is_zero_approx(resolved):
			return 0.0
		var deadzone := clampf(float(deadzones.get(action, 0.0)), 0.0, 1.0)
		return deadzone + resolved * (1.0 - deadzone)

	func is_action_pressed(action: StringName) -> Variant:
		if provider == null or not is_instance_valid(provider):
			return null
		return provider.call(&"is_action_pressed", action)

@export_category("Analogue / held actions")
@export var throttle_forward_action: StringName = &"move_forward"
@export var throttle_reverse_action: StringName = &"move_back"
@export var yaw_left_action: StringName = &"move_left"
@export var yaw_right_action: StringName = &"move_right"
@export var pitch_up_action: StringName = &"pitch_up"
@export var pitch_down_action: StringName = &"pitch_down"
@export var roll_left_action: StringName = &"roll_left"
@export var roll_right_action: StringName = &"roll_right"
@export var boost_action: StringName = &"sprint_boost"
@export var brake_action: StringName = &"brake"
@export var hover_action: StringName = &"hover"
@export var fire_action: StringName = &"fire"

@export_category("Mouse steering")
@export_range(1.0, 1000.0, 1.0) var look_motion_for_full_axis := 140.0
@export var invert_look_y := false
@export var capture_mouse_motion := true

@export_category("Edge actions")
@export var barrel_roll_action: StringName = &"barrel_roll"
@export var landing_action: StringName = &"landing_assist"
@export var interact_action: StringName = &"interact"
@export var camera_toggle_action: StringName = &"toggle_ship_camera_view"
@export var camera_distance_in_action: StringName = &"camera_distance_in"
@export var camera_distance_out_action: StringName = &"camera_distance_out"

var _input_provider: Object
var _input_provider_strength_domain := INPUT_PROVIDER_RAW
var _sampler_input_provider: Object
var _pending_look_motion := Vector2.ZERO
var _pending_camera_distance_delta := 0.0
var _pending_explicit_edges: Dictionary = {}
var _edge_reprime_pending := false
var _application_focused := true
var _scene_tree_paused := false
var _has_entered_tree := false
var _authored_input_profile: InputBindingProfile
var _input_transform_bank: InputActionTransformBank
var _input_transform_sampler: InputActionTransformSampler
var _ship_command_mapper: TransformedShipCommandMapper
var _input_transform_physics_delta := 1.0 / 60.0
var _input_configuration_errors := PackedStringArray()
var _transform_boundary_committed := false
var _production_input_profile_active := false


func _init() -> void:
	_input_transform_physics_delta = 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	_ship_command_mapper = TransformedShipCommandMapperType.new()
	# RuntimeSettings owns the process-stable project snapshot. Reusing it here
	# prevents whole-Main re-entry after a live remap from redefining that custom
	# InputMap as the source's authored reset target.
	var captured := RuntimeSettingsType.new().get_project_input_binding_defaults()
	_authored_input_profile = _make_authored_compatibility_profile(captured)
	if _authored_input_profile == null:
		_input_configuration_errors.append("authored_input_profile_invalid")
		return
	for action_id: StringName in TransformedShipCommandMapperType.FLIGHT_ACTION_ORDER:
		if not _authored_input_profile.bindings.has(action_id):
			_input_configuration_errors.append("missing_flight_action:%s" % action_id)
	if not _input_configuration_errors.is_empty():
		return
	_input_transform_bank = InputActionTransformBankType.new(_authored_input_profile)
	if not _input_transform_bank.is_configuration_valid():
		_input_configuration_errors.append("input_transform_bank_invalid")
		return
	var attached := _input_transform_bank.attach(_input_transform_bank.get_generation())
	if not bool(attached.accepted):
		_input_configuration_errors.append("input_transform_bank_attach_failed")
		return
	_rebuild_input_transform_sampler()


func _enter_tree() -> void:
	# Application notifications are delivered only to nodes currently in the tree.
	# Snapshot the live Window state on every entry so a focus transition missed
	# while this subtree was detached cannot leave the adapter permanently stale.
	_application_focused = _query_application_focus()
	_scene_tree_paused = get_tree().paused
	if _has_entered_tree:
		invalidate_pending_commands()
	_has_entered_tree = true


func _exit_tree() -> void:
	invalidate_pending_commands()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_scene_tree_paused = true
		invalidate_pending_commands()
	elif what == NOTIFICATION_UNPAUSED:
		_scene_tree_paused = false
		# A controller button used to navigate the pause UI must be seeded as held,
		# not manufactured as a fresh flight edge on the first resumed tick.
		invalidate_pending_commands()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_application_focused = false
		invalidate_pending_commands()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_application_focused = true
		invalidate_pending_commands()


func _unhandled_input(event: InputEvent) -> void:
	if not capture_mouse_motion:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		queue_look_motion((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			queue_camera_distance_delta(-1.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			queue_camera_distance_delta(1.0)


## Deterministic mouse-look hook. Pixel motion is retained as a backlog until
## authoritative commands consume it. A physics tick can emit at most one full
## look-axis impulse per component; excess motion is carried forward instead of
## being lost to a clamp when the OS coalesces several events into one sample.
func queue_look_motion(relative: Vector2) -> void:
	if not _can_accept_transient_input() or not relative.is_finite():
		return
	_pending_look_motion += relative


## Queues signed chase-distance steps without bypassing the command snapshot.
## A bounded backlog preserves multiple high-resolution wheel events while
## preventing a stalled consumer from accumulating an unbounded impulse.
func queue_camera_distance_delta(delta_steps: float) -> void:
	if (
		not _can_accept_transient_input()
		or not is_finite(delta_steps)
		or is_zero_approx(delta_steps)
	):
		return
	_pending_camera_distance_delta = clampf(
		_pending_camera_distance_delta + delta_steps,
		-MAX_PENDING_CAMERA_DISTANCE_STEPS,
		MAX_PENDING_CAMERA_DISTANCE_STEPS
	)


## Drops motion at camera, pilot, and flight-state boundaries without resetting
## the command stream or disturbing held-action edge bookkeeping.
func clear_pending_look_motion() -> void:
	_pending_look_motion = Vector2.ZERO


## Drops only queued chase-distance steps. Lifecycle/focus boundaries call the
## stronger internal reset, which also re-primes every held edge action.
func clear_pending_camera_distance_delta() -> void:
	_pending_camera_distance_delta = 0.0


## Deterministic compatibility hook for automation/replay adapters that already
## receive an action edge. Physical keyboard and joypad input still uses the
## regular held-state sampler; this queue exists so a synthetic InputEventAction
## can enter the same immutable command stream instead of bypassing authority.
func queue_action_edge(action: StringName) -> void:
	if not _can_accept_transient_input() or not _edge_actions().has(action):
		return
	_pending_explicit_edges[action] = true


## Passing null restores Godot's Input singleton. Deterministic providers supply
## raw physical strengths by default; an InputMap-aware adapter may explicitly
## declare already-resolved strengths so the retained profile deadzone is not
## applied to that logical magnitude twice.
func set_input_provider(
		provider: Object,
		strength_domain: StringName = INPUT_PROVIDER_RAW,
	) -> void:
	var replacing_live_provider := get_next_sequence() > 0 or get_stream_id() > 0
	_input_provider = provider
	_input_provider_strength_domain = (
		INPUT_PROVIDER_INPUT_MAP_RESOLVED
		if provider != null and strength_domain == INPUT_PROVIDER_INPUT_MAP_RESOLVED
		else INPUT_PROVIDER_RAW
	)
	_rebuild_input_transform_sampler()
	# Initial injection has no produced or queued history to revoke and preserves
	# the established contract that an initially-held edge is observable once.
	# A live provider swap is a true boundary and invalidates sampled delivery.
	if replacing_live_provider:
		invalidate_pending_commands()
	else:
		_clear_transient_input(false)
	# Swapping devices during an active stream is another mode boundary. A key
	# already held on the replacement device must be released before it edges.
	if replacing_live_provider and is_enabled_owner():
		if _is_input_sampling_active():
			_prime_transform_states()
		else:
			_edge_reprime_pending = true


func get_input_provider() -> Object:
	return _input_provider


## Side-effect-free half of a multi-source profile transaction. The retained
## bank checks the caller's exact generation and fully prepares the candidate,
## including attached child transforms, without changing live command state.
func validate_input_binding_profile(
		profile: InputBindingProfile,
		expected_generation: int,
	) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var validated := _input_transform_bank.validate_profile_replacement(
		profile,
		expected_generation,
	)
	return _input_configuration_result(
		bool(validated.accepted),
		StringName(validated.reason),
	)


## Atomically installs a complete RuntimeSettings-compatible binding profile.
## The bank enforces the exact authored action roster. A successful replacement
## advances both bank generation and command stream; stale/invalid candidates do
## neither. Bindings remain provider-owned while action options become executable.
func replace_input_binding_profile(
		profile: InputBindingProfile,
		expected_generation: int,
	) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var replaced := _input_transform_bank.replace_profile(profile, expected_generation)
	if not bool(replaced.accepted):
		return _input_configuration_result(false, StringName(replaced.reason))
	_production_input_profile_active = true
	_commit_transform_boundary()
	return _input_configuration_result(true, &"profile_replaced")


## Convenience seam for RuntimeSettings owners that hold the current detached
## profile but do not retain the bank generation separately.
func configure_input_binding_profile(profile: InputBindingProfile) -> Dictionary:
	return replace_input_binding_profile(profile, get_input_profile_generation())


## Restores the process-captured authored binding roster with compatibility
## options that preserve LocalShipInputSource's pre-transform raw behavior.
func reset_input_binding_profile(expected_generation: int) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var replaced := _input_transform_bank.replace_profile(
		_authored_input_profile,
		expected_generation,
	)
	if not bool(replaced.accepted):
		return _input_configuration_result(false, StringName(replaced.reason))
	_production_input_profile_active = false
	_commit_transform_boundary()
	return _input_configuration_result(true, &"profile_reset")


func reset_input_binding_profile_to_authored() -> Dictionary:
	return reset_input_binding_profile(get_input_profile_generation())


## Clears transformed held/toggle/edge state without changing the current
## profile. This is an explicit authority boundary and begins a new command epoch.
func reset_input_transform_state(expected_generation: int) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var reset := _input_transform_bank.reset(expected_generation)
	if not bool(reset.accepted):
		return _input_configuration_result(false, StringName(reset.reason))
	_commit_transform_boundary()
	return _input_configuration_result(true, &"transform_state_reset")


## Explicit lifecycle gates make detached/stale behavior testable without
## exposing the retained bank or letting a caller partially mutate its children.
func detach_input_transform(expected_generation: int) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var detached := _input_transform_bank.detach(expected_generation)
	if not bool(detached.accepted):
		return _input_configuration_result(false, StringName(detached.reason))
	_commit_transform_boundary()
	return _input_configuration_result(true, &"detached")


func attach_input_transform(expected_generation: int) -> Dictionary:
	if not is_input_configuration_valid():
		return _input_configuration_result(false, &"invalid_configuration")
	var attached := _input_transform_bank.attach(expected_generation)
	if not bool(attached.accepted):
		return _input_configuration_result(false, StringName(attached.reason))
	_commit_transform_boundary()
	return _input_configuration_result(true, &"attached")


## LocalShipInputSource remains the caller-physics owner. The default matches the
## configured physics tick rate; deterministic callers may supply their exact
## non-negative finite tick delta explicitly.
func set_input_transform_physics_delta(physics_delta: Variant) -> Dictionary:
	if (
		(not physics_delta is float and not physics_delta is int)
		or not is_finite(float(physics_delta))
		or float(physics_delta) < 0.0
	):
		return _input_configuration_result(false, &"invalid_physics_delta")
	_input_transform_physics_delta = float(physics_delta)
	return _input_configuration_result(true, &"physics_delta_configured")


func is_input_configuration_valid() -> bool:
	return (
		_input_configuration_errors.is_empty()
		and _input_transform_bank != null
		and _input_transform_bank.is_configuration_valid()
		and _input_transform_sampler != null
		and _input_transform_sampler.is_configuration_valid()
		and _ship_command_mapper != null
	)


func get_input_profile_generation() -> int:
	return _input_transform_bank.get_generation() if _input_transform_bank != null else -1


func get_input_binding_profile() -> InputBindingProfile:
	return _input_transform_bank.get_profile() if _input_transform_bank != null else null


func get_authored_input_binding_profile() -> InputBindingProfile:
	return _authored_input_profile.duplicate_profile() if _authored_input_profile != null else null


func get_input_transform_snapshot() -> Dictionary:
	return (
		_input_transform_bank.get_snapshot().duplicate(true)
		if _input_transform_bank != null
		else {}
	)


func get_input_integration_audit() -> Dictionary:
	return {
		"valid": is_input_configuration_valid() and _action_contract_matches_mapper(),
		"errors": _input_configuration_errors.duplicate(),
		"profile_generation": get_input_profile_generation(),
		"profile": (
			get_input_binding_profile().to_dictionary()
			if get_input_binding_profile() != null
			else {}
		),
		"authored_profile": (
			get_authored_input_binding_profile().to_dictionary()
			if get_authored_input_binding_profile() != null
			else {}
		),
		"physics_delta": _input_transform_physics_delta,
		"uses_transform_bank": true,
		"uses_transform_sampler": true,
		"uses_ship_command_mapper": true,
		"preserves_mouse_motion_backlog": true,
		"preserves_camera_distance_backlog": true,
		"owns_command_stream": true,
		"owns_command_sequence": true,
		"owns_command_timestamp": true,
		"emits_engine_start": false,
		"emits_engine_stop": false,
		"production_input_profile_active": _production_input_profile_active,
		"input_provider_strength_domain": _input_provider_strength_domain,
		"production_input_strength_domain": (
			_input_provider_strength_domain
			if _input_provider != null
			else &"input_map_resolved" if _production_input_profile_active
			else &"compatibility_resolved"
		),
		"bank": _input_transform_bank.audit() if _input_transform_bank != null else {},
		"sampler": _input_transform_sampler.audit() if _input_transform_sampler != null else {},
		"mapper": _ship_command_mapper.audit() if _ship_command_mapper != null else {},
	}.duplicate(true)


func _sample_controls() -> Dictionary:
	if (
		not _is_input_sampling_active()
		or not is_input_configuration_valid()
		or not _action_contract_matches_mapper()
	):
		return {}
	var generation := _input_transform_bank.get_generation()
	var prime_physical_state := _edge_reprime_pending
	var frame := _input_transform_sampler.sample_physics_frame(
		_input_transform_physics_delta,
		generation,
		prime_physical_state,
	)
	if not bool(frame.accepted):
		return {}
	if prime_physical_state:
		_edge_reprime_pending = false
	var mapped := _ship_command_mapper.map_frame(frame, generation, 0, 0, 0)
	if not bool(mapped.accepted):
		return {}
	var command := mapped.command as ShipCommand
	if command == null or not command.is_valid():
		return {}

	# Motion events remain source-owned and are consumed only after the complete
	# action frame has validated. A malformed/stale/detached frame is fully neutral
	# and cannot discard a queued look or wheel event.
	var look := _consume_look_deltas()
	_pending_camera_distance_delta = clampf(
		_pending_camera_distance_delta + command.camera_distance_delta,
		-MAX_PENDING_CAMERA_DISTANCE_STEPS,
		MAX_PENDING_CAMERA_DISTANCE_STEPS,
	)
	var values := command.to_dictionary()
	values["look_yaw_delta"] = look.x
	values["look_pitch_delta"] = look.y
	values["camera_distance_delta"] = _consume_camera_distance_delta()
	_apply_explicit_edges(values)
	_pending_explicit_edges.clear()
	# Deprecated fields stay false even if a malformed provider exposes retired
	# action names or an automation caller tries to queue them explicitly.
	values["engine_start"] = false
	values["engine_stop"] = false
	return values


func _on_consumption_state_changed(consuming: bool) -> void:
	invalidate_pending_commands()
	if not consuming:
		return
	# Ownership/enabled transitions are mode boundaries. Seed currently held
	# actions so they must be released before becoming a new edge for this owner.
	if _application_focused:
		_prime_transform_states()
	else:
		_edge_reprime_pending = true


func _prime_transform_states() -> void:
	if not is_input_configuration_valid() or not _is_input_sampling_active():
		_edge_reprime_pending = true
		return
	var frame := _input_transform_sampler.sample_physics_frame(
		0.0,
		_input_transform_bank.get_generation(),
		true,
	)
	_edge_reprime_pending = not bool(frame.accepted)


func _on_stream_reset() -> void:
	_clear_transient_input(false)
	_reset_transform_bank_for_boundary()
	if is_enabled_owner():
		if _application_focused:
			_prime_transform_states()
		else:
			_edge_reprime_pending = true


func _on_delivery_invalidated() -> void:
	_clear_transient_input(true)
	if not _transform_boundary_committed:
		_reset_transform_bank_for_boundary()


func _consume_look_deltas() -> Vector2:
	if not _pending_look_motion.is_finite():
		_pending_look_motion = Vector2.ZERO
		return Vector2.ZERO
	var divisor := (
		maxf(look_motion_for_full_axis, 1.0)
		if is_finite(look_motion_for_full_axis)
		else 140.0
	)
	# Keep command semantics unchanged: each normalized field is still the
	# angular impulse for this physics tick. Chunking in pixel space makes the
	# integrated impulse independent of mouse-event coalescing and polling rate.
	var consumed_motion := Vector2(
		clampf(_pending_look_motion.x, -divisor, divisor),
		clampf(_pending_look_motion.y, -divisor, divisor)
	)
	_pending_look_motion -= consumed_motion
	if _pending_look_motion.is_zero_approx():
		_pending_look_motion = Vector2.ZERO
	var pitch_sign := 1.0 if invert_look_y else -1.0
	return Vector2(
		consumed_motion.x / divisor,
		consumed_motion.y / divisor * pitch_sign
	)


func _consume_camera_distance_delta() -> float:
	if not is_finite(_pending_camera_distance_delta):
		_pending_camera_distance_delta = 0.0
		return 0.0
	var consumed := clampf(_pending_camera_distance_delta, -1.0, 1.0)
	_pending_camera_distance_delta -= consumed
	if is_zero_approx(_pending_camera_distance_delta):
		_pending_camera_distance_delta = 0.0
	return consumed


func _can_accept_transient_input() -> bool:
	return (
		_is_input_sampling_active()
		and is_enabled_owner()
		and (not _has_entered_tree or is_inside_tree())
	)


func _is_input_sampling_active() -> bool:
	if not _application_focused or _scene_tree_paused:
		return false
	# Before first attachment, injected providers remain usable by deterministic
	# unit/replay tools. Once attached, Godot's process policy is authoritative.
	return not _has_entered_tree or (
		is_inside_tree()
		and not is_queued_for_deletion()
		and can_process()
	)


## Overridable only so headless regressions can supply deterministic focus. A
## focused Godot-owned secondary Window still counts as application focus, which
## is why this queries Window rather than only DisplayServer's main-window ID.
## Godot exposes current state, not missed transition history: presses/releases
## that both occur while detached are intentionally unrecoverable. Likewise,
## APPLICATION_PAUSED/RESUMED are mobile notifications with no corresponding
## authoritative query, so a complete mobile suspend cycle while this node is
## detached cannot be reconstructed without an always-present platform tracker.
## Held axes/fire/boost resume from current state; one-shot edge actions are
## deliberately primed and require release/repress after the boundary.
func _query_application_focus() -> bool:
	return Window.get_focused_window() != null


func _clear_transient_input(reprime_edges: bool) -> void:
	_pending_look_motion = Vector2.ZERO
	_pending_camera_distance_delta = 0.0
	_pending_explicit_edges.clear()
	_edge_reprime_pending = reprime_edges


func _edge_actions() -> Array[StringName]:
	return [
		fire_action,
		barrel_roll_action,
		landing_action,
		interact_action,
		camera_toggle_action,
		camera_distance_in_action,
		camera_distance_out_action,
	]


func _axis_actions() -> Array[StringName]:
	return [
		throttle_forward_action,
		throttle_reverse_action,
		yaw_left_action,
		yaw_right_action,
		pitch_up_action,
		pitch_down_action,
		roll_left_action,
		roll_right_action,
	]


func _make_authored_compatibility_profile(captured: InputBindingProfile) -> InputBindingProfile:
	if captured == null:
		return null
	var serialized := captured.to_dictionary()
	# Input.get_action_strength()/injected providers were the old source boundary.
	# A zero-deadzone linear HOLD transform is the identity over those already
	# resolved logical values, preserving default flight response byte-for-value.
	var compatibility_options := {}
	for raw_action: Variant in serialized.action_options as Dictionary:
		compatibility_options[StringName(raw_action)] = {
			"deadzone": 0.0,
			"curve": InputBindingProfileType.CURVE_LINEAR,
			"hold_mode": InputBindingProfileType.HOLD,
		}
	serialized["action_options"] = compatibility_options
	return InputBindingProfileType.from_dictionary(serialized)


func _rebuild_input_transform_sampler() -> void:
	if _input_transform_bank == null:
		_input_transform_sampler = null
		return
	if _input_provider != null:
		var compatible := AxisCompatibleInputProvider.new(
			_input_provider,
			_axis_actions(),
		)
		_sampler_input_provider = (
			ResolvedInputProfileProvider.new(
				compatible,
				_input_transform_bank.get_profile(),
			)
			if (
				_production_input_profile_active
				and _input_provider_strength_domain == INPUT_PROVIDER_INPUT_MAP_RESOLVED
			)
			else compatible
		)
	elif _production_input_profile_active:
		_sampler_input_provider = ResolvedInputProfileProvider.new(
			Input,
			_input_transform_bank.get_profile(),
		)
	else:
		_sampler_input_provider = null
	_input_transform_sampler = InputActionTransformSamplerType.new(
		_input_transform_bank,
		_sampler_input_provider,
	)


func _reset_transform_bank_for_boundary() -> void:
	if _input_transform_bank == null or not _input_transform_bank.is_configuration_valid():
		return
	var snapshot := _input_transform_bank.get_snapshot()
	if not bool(snapshot.attached):
		return
	_input_transform_bank.reset(_input_transform_bank.get_generation())


func _commit_transform_boundary() -> void:
	_rebuild_input_transform_sampler()
	_transform_boundary_committed = true
	invalidate_pending_commands()
	_transform_boundary_committed = false
	_edge_reprime_pending = true


func _apply_explicit_edges(values: Dictionary) -> void:
	if bool(_pending_explicit_edges.get(fire_action, false)):
		values["fire_pressed"] = true
	if bool(_pending_explicit_edges.get(barrel_roll_action, false)):
		values["barrel_roll"] = true
	if bool(_pending_explicit_edges.get(landing_action, false)):
		values["landing"] = true
	if bool(_pending_explicit_edges.get(interact_action, false)):
		values["interact"] = true
	if bool(_pending_explicit_edges.get(camera_toggle_action, false)):
		values["camera_toggle"] = true
	if bool(_pending_explicit_edges.get(camera_distance_in_action, false)):
		values["camera_distance_delta"] = clampf(
			float(values.get("camera_distance_delta", 0.0)) - 1.0,
			-1.0,
			1.0,
		)
	if bool(_pending_explicit_edges.get(camera_distance_out_action, false)):
		values["camera_distance_delta"] = clampf(
			float(values.get("camera_distance_delta", 0.0)) + 1.0,
			-1.0,
			1.0,
		)


func _action_contract_matches_mapper() -> bool:
	return (
		throttle_forward_action == &"move_forward"
		and throttle_reverse_action == &"move_back"
		and yaw_left_action == &"move_left"
		and yaw_right_action == &"move_right"
		and pitch_up_action == &"pitch_up"
		and pitch_down_action == &"pitch_down"
		and roll_left_action == &"roll_left"
		and roll_right_action == &"roll_right"
		and boost_action == &"sprint_boost"
		and brake_action == &"brake"
		and hover_action == &"hover"
		and fire_action == &"fire"
		and barrel_roll_action == &"barrel_roll"
		and landing_action == &"landing_assist"
		and interact_action == &"interact"
		and camera_toggle_action == &"toggle_ship_camera_view"
		and camera_distance_in_action == &"camera_distance_in"
		and camera_distance_out_action == &"camera_distance_out"
	)


func _input_configuration_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": get_input_profile_generation(),
		"stream_id": get_stream_id(),
		"delivery_generation": get_delivery_generation(),
		"snapshot": get_input_transform_snapshot(),
	}.duplicate(true)
