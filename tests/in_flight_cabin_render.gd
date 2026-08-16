extends SceneTree

## Human-review render of the in-flight cabin loop, driven through the real
## production scene with real input. This is a looking tool, not a gate: it is
## deliberately not named `*_test.gd`, so it never joins the release matrix.
##
## Usage:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path <worktree> \
##     --display-driver x11 --rendering-driver vulkan \
##     --script tests/in_flight_cabin_render.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts"
const LOCOMOTION_TICK_BUDGET := 400
const FLIGHT_CONTROL_ACTIONS := [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]

var _game: GameFlow
var _player: PlayerController
var _jovian: JovianLightFreighter


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# `--script` still auto-loads the project's main scene, and it owns the root
	# viewport. Drive that instance rather than adding a second one, or the shot
	# is the auto-loaded copy's intro overlay drawn over this script's world.
	var guard := 0
	while _find_game_flow() == null and guard < 600:
		await process_frame
		guard += 1
	_game = _find_game_flow()
	if _game == null:
		_game = MAIN_SCENE.instantiate() as GameFlow
		root.add_child(_game)
	await process_frame
	await physics_frame
	await physics_frame

	_player = _game.get_node("Player") as PlayerController
	_jovian = _game.get_node("JovianLightFreighter") as JovianLightFreighter

	_game.canopy_motion_time = 0.02
	_game.boarding_motion_time = 0.3
	_game.disembarking_motion_time = 0.5
	# The intro overlay is retired by the HUD's own input handler, not by
	# `start_shift()`. Parse a real action event so the panel actually clears and
	# the capture shows the game rather than the title card.
	var intro_press := InputEventAction.new()
	intro_press.action = &"interact"
	intro_press.pressed = true
	Input.parse_input_event(intro_press)
	# A parsed action event also latches the action, and a latched action produces
	# no later `just_pressed` edge — which would silently swallow the boarding
	# press. Release it explicitly.
	var intro_release := InputEventAction.new()
	intro_release.action = &"interact"
	intro_release.pressed = false
	Input.parse_input_event(intro_release)
	Input.action_release(&"interact")
	for _intro_tick in 20:
		await process_frame
		await physics_frame
	if _game.phase == GameFlow.Phase.INTRO:
		_game.start_shift()
		await process_frame

	_player.teleport_to(Transform3D(
		_jovian.global_basis.orthonormalized(),
		_jovian.get_boarding_position() + _jovian.global_basis.y.normalized() * 0.05
	))
	_player.set_control_enabled(true)
	for _approach in 6:
		await physics_frame
		await process_frame
	await _press(&"interact", 1)
	await _wait(func() -> bool: return _game.phase == GameFlow.Phase.START_ENGINES, 240)
	print("RENDER_STAGE boarded phase=", _game.phase, " seated=", _player.is_seated())

	if not await _wake_engine_with_flight_demand():
		printerr("RENDER_STAGE automatic flight demand did not wake Jovian in one physics tick")
		quit(1)
		return
	print("RENDER_STAGE engines online phase=", _game.phase)

	# Clear the berth with real thrust, then place the hull in open space instead
	# of flying the whole way there. This is a looking tool; the integration suite
	# is what proves the flown route.
	var origin := _jovian.global_position
	Input.action_press(&"move_forward")
	var ticks := 0
	while bool(_jovian.get_telemetry().get("landed", true)) and ticks < 240:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(&"move_forward")
	for _clear_tick in 20:
		await physics_frame
		await process_frame
	print(
		"RENDER_STAGE departed landed=", _jovian.get_telemetry().get("landed"),
		" distance=", _jovian.global_position.distance_to(origin)
	)
	_jovian.global_transform = Transform3D(
		_jovian.global_basis.orthonormalized(),
		origin + Vector3(0.0, 260.0, -540.0)
	)
	_jovian.velocity = -_jovian.global_basis.z * 26.0
	for _place_tick in 10:
		await physics_frame
		await process_frame
	await _capture("cabin_01_in_flight_before_shutdown.png")

	if not await _idle_engine_offline():
		printerr("RENDER_STAGE Jovian did not idle OFFLINE in the finite physics budget")
		quit(1)
		return
	for _prompt in 8:
		await physics_frame
		await process_frame
	await _capture("cabin_02_shut_down_prompt.png")

	_action(&"interact")
	await _wait(
		func() -> bool: return bool(_game.get_in_flight_cabin_status().get("carried", false)),
		240
	)
	for _settle in 10:
		await physics_frame
		await process_frame
	await _capture("cabin_03_out_of_the_seat.png")

	_jovian.velocity = -_jovian.global_basis.z * 9.0
	await _walk_until(
		&"move_forward",
		func() -> bool: return _jovian.to_local(_player.global_position).z > 1.0
	)
	await _capture("cabin_04_walking_the_hold.png")

	await _walk_until(
		&"move_forward",
		func() -> bool: return _jovian.to_local(_player.global_position).z > 7.5
	)
	await _capture("cabin_05_aft_of_the_hold.png")

	await _walk_until(
		&"move_back",
		func() -> bool: return _jovian.to_local(_player.global_position).z < 3.0
	)
	await _walk_until(
		&"move_right",
		func() -> bool: return _jovian.to_local(_player.global_position).x < -5.4
	)
	await _capture("cabin_06_held_at_the_open_aperture.png")

	await _walk_until(
		&"move_back",
		func() -> bool: return _jovian.to_local(_player.global_position).z < -6.5
	)
	await _capture("cabin_07_back_at_the_pilot_seat.png")

	await _press(&"interact", 1)
	await _wait(func() -> bool: return _game.phase == GameFlow.Phase.START_ENGINES, 240)
	for _seated in 10:
		await physics_frame
		await process_frame
	await _capture("cabin_08_seat_retaken.png")

	print("IN_FLIGHT_CABIN_RENDER_DONE")
	quit(0)


func _find_game_flow() -> GameFlow:
	for child in root.get_children():
		if child is GameFlow:
			return child as GameFlow
	return null


func _walk_until(action: StringName, predicate: Callable) -> void:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < LOCOMOTION_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	for _settle in 8:
		await physics_frame
		await process_frame


func _press(action: StringName, ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _wake_engine_with_flight_demand() -> bool:
	_release_all_flight_controls()
	Input.action_press(&"hover")
	await physics_frame
	await process_frame
	var woke_same_tick := (
		StringName(_jovian.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE
		and _jovian.get_last_ship_command().hover
	)
	Input.action_release(&"hover")
	return woke_same_tick


func _idle_engine_offline() -> bool:
	_release_all_flight_controls()
	var physics_tick := 1.0 / float(Engine.physics_ticks_per_second)
	var idle_budget := HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS + physics_tick * 2.0
	var frame_count := int(ceil(idle_budget * float(Engine.physics_ticks_per_second)))
	for _frame in frame_count:
		await physics_frame
		await process_frame
	return StringName(_jovian.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_OFFLINE


func _release_all_flight_controls() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	var source := _jovian.get_command_source() as LocalShipInputSource
	if source != null:
		source.clear_pending_look_motion()


func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_game._unhandled_input(event)


func _wait(predicate: Callable, budget: int) -> bool:
	var frames := 0
	while not bool(predicate.call()):
		if frames >= budget:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		print("RENDER_MISS: ", file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(path) != OK:
		print("RENDER_SAVE_FAILED: ", file_name)
		return
	var absolute := ProjectSettings.globalize_path(path)
	print("CAPTURED: ", absolute, " (", FileAccess.get_file_as_bytes(absolute).size(), " bytes)")
