class_name LocalShipInputSource
extends ShipCommandSource

## Local InputMap adapter. An injected provider with `get_action_strength()` and
## `is_action_pressed()` methods can drive the exact same path deterministically.
## Keyboard/gamepad attitude axes are rates. Mouse motion is transported in the
## dedicated normalized per-tick look-delta fields so a consumer never has to
## guess whether a yaw value is a rate or an instantaneous attitude change.
## Camera-distance buttons and mouse-wheel events likewise become a bounded
## signed step stream: negative moves the chase camera nearer, positive farther.

const MAX_PENDING_CAMERA_DISTANCE_STEPS := 32.0

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
@export var engine_start_action: StringName = &"engine_start"
@export var engine_stop_action: StringName = &"engine_stop"
@export var landing_action: StringName = &"landing_assist"
@export var interact_action: StringName = &"interact"
@export var camera_toggle_action: StringName = &"toggle_ship_camera_view"
@export var camera_distance_in_action: StringName = &"camera_distance_in"
@export var camera_distance_out_action: StringName = &"camera_distance_out"

var _input_provider: Object
var _previous_edge_states: Dictionary = {}
var _pending_look_motion := Vector2.ZERO
var _pending_camera_distance_delta := 0.0
var _pending_explicit_edges: Dictionary = {}
var _edge_reprime_pending := false
var _application_focused := true
var _scene_tree_paused := false
var _has_entered_tree := false


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


## Passing null restores Godot's Input singleton.
func set_input_provider(provider: Object) -> void:
	var replacing_live_provider := get_next_sequence() > 0 or get_stream_id() > 0
	_input_provider = provider
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
			_prime_edge_states()
		else:
			_edge_reprime_pending = true


func get_input_provider() -> Object:
	return _input_provider


func _sample_controls() -> Dictionary:
	if not _is_input_sampling_active():
		return {}
	if _edge_reprime_pending:
		_prime_edge_states()
	var edges := _sample_edge_actions()
	var look := _consume_look_deltas()
	if bool(edges.get(camera_distance_in_action, false)):
		_pending_camera_distance_delta -= 1.0
	if bool(edges.get(camera_distance_out_action, false)):
		_pending_camera_distance_delta += 1.0
	return {
		"throttle": _axis(throttle_reverse_action, throttle_forward_action),
		"yaw": _axis(yaw_left_action, yaw_right_action),
		"pitch": _axis(pitch_down_action, pitch_up_action),
		"roll": _axis(roll_left_action, roll_right_action),
		"look_yaw_delta": look.x,
		"look_pitch_delta": look.y,
		"boost": _action_pressed(boost_action),
		"brake": _action_pressed(brake_action),
		"hover": _action_pressed(hover_action),
		"fire": _action_pressed(fire_action),
		"barrel_roll": bool(edges.get(barrel_roll_action, false)),
		"engine_start": bool(edges.get(engine_start_action, false)),
		"engine_stop": bool(edges.get(engine_stop_action, false)),
		"landing": bool(edges.get(landing_action, false)),
		"interact": bool(edges.get(interact_action, false)),
		"camera_toggle": bool(edges.get(camera_toggle_action, false)),
		"camera_distance_delta": _consume_camera_distance_delta(),
	}


func _on_consumption_state_changed(consuming: bool) -> void:
	invalidate_pending_commands()
	if not consuming:
		return
	# Ownership/enabled transitions are mode boundaries. Seed currently held
	# actions so they must be released before becoming a new edge for this owner.
	if _application_focused:
		_prime_edge_states()
	else:
		_edge_reprime_pending = true


func _prime_edge_states() -> void:
	_previous_edge_states.clear()
	for action in _edge_actions():
		_previous_edge_states[action] = _action_pressed(action)
	_edge_reprime_pending = false


func _on_stream_reset() -> void:
	_clear_transient_input(false)
	if is_enabled_owner():
		if _application_focused:
			_prime_edge_states()
		else:
			_edge_reprime_pending = true


func _on_delivery_invalidated() -> void:
	_clear_transient_input(true)


func _axis(negative_action: StringName, positive_action: StringName) -> float:
	return clampf(
		_action_strength(positive_action) - _action_strength(negative_action),
		-1.0,
		1.0
	)


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


func _sample_edge_actions() -> Dictionary:
	var edges := {}
	for action in _edge_actions():
		# Multiple logical commands may deliberately share one binding. Sample a
		# physical action once so every mapped command observes the same edge.
		if edges.has(action):
			continue
		var pressed := _action_pressed(action)
		var was_pressed := bool(_previous_edge_states.get(action, false))
		_previous_edge_states[action] = pressed
		edges[action] = (
			(pressed and not was_pressed)
			or bool(_pending_explicit_edges.get(action, false))
		)
	_pending_explicit_edges.clear()
	return edges


func _action_strength(action: StringName) -> float:
	if _input_provider != null:
		if not is_instance_valid(_input_provider):
			return 0.0
		if not _input_provider.has_method(&"get_action_strength"):
			return 0.0
		var injected: Variant = _input_provider.call(&"get_action_strength", action)
		if injected is float or injected is int:
			var value := float(injected)
			return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
		return 0.0
	if not InputMap.has_action(action):
		return 0.0
	var value := Input.get_action_strength(action)
	return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0


func _action_pressed(action: StringName) -> bool:
	if _input_provider != null:
		if not is_instance_valid(_input_provider):
			return false
		if not _input_provider.has_method(&"is_action_pressed"):
			return false
		var injected: Variant = _input_provider.call(&"is_action_pressed", action)
		return bool(injected) if injected is bool else false
	return InputMap.has_action(action) and Input.is_action_pressed(action)


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
	return not _has_entered_tree or (is_inside_tree() and can_process())


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
	_previous_edge_states.clear()
	_pending_look_motion = Vector2.ZERO
	_pending_camera_distance_delta = 0.0
	_pending_explicit_edges.clear()
	_edge_reprime_pending = reprime_edges


func _edge_actions() -> Array[StringName]:
	return [
		barrel_roll_action,
		engine_start_action,
		engine_stop_action,
		landing_action,
		interact_action,
		camera_toggle_action,
		camera_distance_in_action,
		camera_distance_out_action,
	]
