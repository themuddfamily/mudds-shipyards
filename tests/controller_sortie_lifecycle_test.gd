extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

const AXIS_LEFT_Y := 1
const BUTTON_X := 2
const BUTTON_DPAD_LEFT := 13

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this suite is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

var _failures := PackedStringArray()
var _assertions := 0


class ControllerOnlyProvider:
	extends RefCounted

	var buttons: Dictionary = {}
	var axes: Dictionary = {}

	func set_button(button_index: int, pressed: bool) -> void:
		buttons[button_index] = pressed

	func set_axis(axis_index: int, value: float) -> void:
		axes[axis_index] = clampf(value, -1.0, 1.0)

	func get_action_strength(action: StringName) -> float:
		if not InputMap.has_action(action):
			return 0.0
		var strength := 0.0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				var button := event as InputEventJoypadButton
				if bool(buttons.get(button.button_index, false)):
					strength = 1.0
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				var actual := float(axes.get(motion.axis, 0.0))
				if signf(actual) == signf(motion.axis_value):
					strength = maxf(strength, absf(actual))
		return strength

	func is_action_pressed(action: StringName) -> bool:
		return (
			InputMap.has_action(action)
			and get_action_strength(action) > InputMap.action_get_deadzone(action)
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the controller sortie")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.0
	game.disembarking_motion_time = 0.0
	game.start_shift()
	await process_frame

	var arrow := game.get_node_or_null("ArrowReconShip") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(arrow != null and world != null, "controller fixture resolves Arrow and its live shipyard")
	if arrow == null or world == null:
		await _clean_up(game)
		_finish()
		return
	game.call("_board_ship", arrow)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			0.8
		),
		"physical controller fixture reaches Arrow's pilot seat"
	)
	_check(
		game.get_active_ship() == arrow and arrow.is_piloted(),
		"GameFlow and HeroShip share the same piloted controller authority"
	)

	var source := arrow.get_command_source() as LocalShipInputSource
	var provider := ControllerOnlyProvider.new()
	_check(source != null, "piloted Arrow exposes the production local command source")
	if source == null:
		await _clean_up(game)
		_finish()
		return
	source.set_input_provider(provider)

	var engine_events: Array[StringName] = []
	arrow.engine_state_changed.connect(func(state: StringName) -> void:
		engine_events.append(state)
	)
	var berth_id := arrow.get_home_berth_id()
	var berth := world.get_berth_node(berth_id) as ShipBerth
	provider.set_axis(AXIS_LEFT_Y, -1.0)
	_check(
		await _wait_until(
			func() -> bool:
				return str(arrow.get_telemetry().get("engine_state", "")) == "ONLINE",
			0.5
		),
		"left-stick flight demand automatically wakes the physical ship"
	)
	_check(
		await _wait_until(
			func() -> bool: return not bool(arrow.get_telemetry().get("landed", true)),
			1.0
		),
		"left-stick thrust physically releases Arrow from its occupied berth"
	)
	provider.set_axis(AXIS_LEFT_Y, 0.0)
	await physics_frame
	await process_frame
	_check(
		game.phase == GameFlow.Phase.FREE_FLIGHT,
		"physical controller departure advances the production free-sortie phase"
	)
	_check(
		engine_events == [&"ONLINE"],
		"automatic controller demand yields one immediate ONLINE transition without replay"
	)
	_check(
		berth != null and berth.get_occupant() == null and berth.get_reservation_owner() == null,
		"controller departure releases the exact authoritative berth lease"
	)

	var berth_transform := world.get_berth_transform(berth_id)
	arrow.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.velocity = Vector3.ZERO
	await physics_frame
	provider.set_button(BUTTON_DPAD_LEFT, true)
	_check(
		await _wait_until(
			func() -> bool: return arrow.is_landing_active(),
			0.5
		),
		"D-pad Left requests the live strict landing contract through GameFlow"
	)
	provider.set_button(BUTTON_DPAD_LEFT, false)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN,
			3.5
		),
		"controller-requested landing reaches the authoritative shutdown phase"
	)
	_check(
		berth.get_occupant() == arrow and berth.get_reservation_owner() == arrow,
		"controller landing restores the complete occupied berth lease"
	)

	_check(
		await _wait_until(
			func() -> bool:
				return str(arrow.get_telemetry().get("engine_state", "")) == "OFFLINE",
			2.0
		),
		"landed neutral Arrow automatically idles offline after the frozen delay"
	)
	_check(
		engine_events == [&"ONLINE", &"OFFLINE"],
		"automatic controller sortie publishes one wake and one idle transition"
	)
	await physics_frame
	provider.set_button(BUTTON_X, true)
	_check(
		await _wait_until(func() -> bool: return not arrow.is_piloted(), 1.0),
		"controller X completes the physical exit lifecycle from the secured berth"
	)
	provider.set_button(BUTTON_X, false)
	_check(
		game.phase == GameFlow.Phase.APPROACH_SHIP
		and game.get_active_ship() == arrow
		and not game.player.is_seated()
		and game.player.is_control_enabled(),
		"controller-only sortie returns the same player to on-foot authority"
	)

	await _clean_up(game)
	_finish()


## Waits for `predicate` on a finite simulation-frame budget.
##
## Every result this suite waits on — craft selection, boarding, seating, engine
## spin-up, flight and the on-foot handoff — is integrated in a frame callback,
## most of them in `_physics_process`. Under load Godot drops physics steps
## rather than letting the simulation spiral while the wall clock keeps running,
## so a wall-clock deadline ends the wait after far fewer simulated steps than
## the manoeuvre needs and scores a perfectly healthy sortie as a failure.
## `timeout_seconds` is kept as the nominal simulated duration and becomes a
## finite frame budget, so a genuinely stuck sortie still fails the suite.
func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("CONTROLLER_SORTIE_LIFECYCLE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("CONTROLLER_SORTIE_LIFECYCLE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
