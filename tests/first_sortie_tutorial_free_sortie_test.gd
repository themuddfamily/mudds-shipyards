extends SceneTree

## Before the guided test is done, a fresh profile may board any berthed craft
## for a free sortie. The first-sortie card follows it to the seat and launch,
## but it must not keep "Throttle and steer ... clear of the bay" alive for the
## rest of free flight, resurfacing whenever the nearby-activity briefing that
## foregrounds over it is acknowledged.
##
## Production Main, fresh XDG profile, a real controller X press to board and
## the real `move_forward` action held to fly out.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CRAFT_ID := &"cinder_light_interceptor"
const BUTTON_X := 2
const HOLD_TICKS := 600

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var flow := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(flow)
	for i in 60:
		await physics_frame
	flow.start_shift()
	var craft: HeroShip = null
	for candidate: HeroShip in flow.get_flyable_ships():
		if candidate.get_ship_id() == CRAFT_ID:
			craft = candidate
	_check(craft != null and craft != flow.ship, "%s is a flyable free-sortie craft" % CRAFT_ID)
	if craft == null:
		await _finish(flow)
		return
	flow.player.teleport_to(Transform3D(Basis.IDENTITY, craft.get_boarding_position() + Vector3.UP * 0.05))
	for i in 6:
		await physics_frame
		await process_frame
	_check(
		flow.boarding_candidate == craft and _card(flow) == &"board",
		"standing at the free-sortie craft shows the board step (%s)" % _card(flow)
	)
	await _tap_joy_button(BUTTON_X)
	for i in 600:
		if flow.phase == GameFlow.Phase.START_ENGINES and not bool(flow.get(&"_transition_busy")):
			break
		await physics_frame
	_check(
		flow.phase == GameFlow.Phase.START_ENGINES and _card(flow) == &"launch",
		"the seated free-sortie pilot is shown the launch step (%s)" % _card(flow)
	)
	var start := craft.global_position
	Input.action_press(&"move_forward")
	for tick in HOLD_TICKS:
		await physics_frame
		if craft.global_position.distance_to(start) > 150.0:
			break
	Input.action_release(&"move_forward")
	await process_frame
	_check(
		flow.phase == GameFlow.Phase.FREE_FLIGHT
			and craft.global_position.distance_to(start) > 100.0,
		"held thrust flies the craft well clear of its berth into free flight"
	)
	# Acknowledge whatever briefing currently foregrounds the runtime card.
	if flow.hud.get("_runtime_status_kind") == &"activity_tutorial":
		flow.hud.call(&"request_activity_tutorial_action", &"next")
	await process_frame
	var status_title := flow.hud.get("_runtime_status_title") as Label
	var status_panel := flow.hud.get("_runtime_status_panel") as Control
	_check(
		_card(flow) == &""
			and not (status_panel.visible and status_title.text == "Throttle and steer"),
		"clear of the bay, free flight no longer holds the launch card (%s, shown=%s)"
			% [_card(flow), status_panel.visible and status_title.text == "Throttle and steer"]
	)
	await _finish(flow)


func _card(game: GameFlow) -> StringName:
	var presenter: RefCounted = game.hud.get("_first_sortie_tutorial_presenter")
	var snapshot := presenter.call(&"get_snapshot") as Dictionary
	if snapshot.is_empty() or not bool(snapshot.get("attached", false)):
		return &""
	return StringName(snapshot.get("step_id", &""))


func _tap_joy_button(button_index: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button_index
		event.pressed = pressed
		Input.parse_input_event(event)
		await physics_frame
		await process_frame


func _finish(flow: GameFlow) -> void:
	Input.action_release(&"move_forward")
	root.remove_child(flow)
	flow.free()
	for i in 4:
		await process_frame
	if _failures.is_empty():
		print("FIRST_SORTIE_TUTORIAL_FREE_SORTIE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		print("FIRST_SORTIE_TUTORIAL_FREE_SORTIE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
