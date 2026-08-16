extends SceneTree

## Human-review render of the on-foot first/third person choice, driven through
## the real production scene with real input. A looking tool, not a gate: it is
## deliberately not named `*_test.gd`, so it never joins the release matrix.
##
## A camera feature is judged by eye. These frames exist to answer three
## questions an assertion cannot: is the eye at the right height, is the body
## actually gone rather than clipped through, and does the view survive the
## transitions in and out of a vehicle.
##
## Usage:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json \
##     xvfb-run -a -s "-screen 0 1280x720x24" godot --path <worktree> \
##     --display-driver x11 --rendering-driver vulkan \
##     --script tests/first_person_view_render.gd
##
## Set `KETH_FIRST_PERSON_RENDER_STAGES` to a subset of `station,tractor,cabin`
## to re-look at one part without re-flying the rest.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/first_person_view"
const LOCOMOTION_TICK_BUDGET := 400
## Comma-separated subset of `station,tractor,cabin`. Empty runs all three.
const STAGES_ENVIRONMENT_VARIABLE := "KETH_FIRST_PERSON_RENDER_STAGES"

var _game: GameFlow
var _player: PlayerController
var _tractor: TowTractor
var _jovian: JovianLightFreighter
var _captures := 0
var _misses := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Refuse rather than hang. A build with no rendering device never fires
	# `frame_post_draw`, so every await below would sit at 1% CPU looking exactly
	# like a slow render instead of like the misconfiguration it is.
	var adapter := RenderingServer.get_video_adapter_name()
	if adapter.strip_edges().is_empty() or DisplayServer.get_name() == "headless":
		printerr(
			"FIRST_PERSON_RENDER_NO_DEVICE: adapter=%r display=%s -- this harness needs a real "
			% [adapter, DisplayServer.get_name()]
			+ "rendering device. Run it under xvfb with --rendering-driver vulkan."
		)
		quit(2)
		return
	print("FIRST_PERSON_RENDER_DEVICE: adapter=%s display=%s method=%s" % [
		adapter, DisplayServer.get_name(), RenderingServer.get_current_rendering_method()
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var guard := 0
	while _find_game_flow() == null and guard < 600:
		await process_frame
		guard += 1
	_game = _find_game_flow()
	if _game == null:
		# `--script` usually auto-loads the project's main scene and it owns the
		# root viewport, so the auto-loaded instance is the one to drive. When it
		# has not appeared, this script owns the world instead.
		_game = MAIN_SCENE.instantiate() as GameFlow
		root.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame

	_player = _game.get_node("Player") as PlayerController
	_tractor = _game.get_tow_tractor()
	_jovian = _game.get_node_or_null("JovianLightFreighter") as JovianLightFreighter
	_game.canopy_motion_time = 0.02
	_game.boarding_motion_time = 0.3
	_game.disembarking_motion_time = 0.5
	await _clear_intro()

	# Each stage costs minutes under llvmpipe and each writes its own files, so
	# re-looking at one of them does not mean re-flying the other two.
	var stages := OS.get_environment(STAGES_ENVIRONMENT_VARIABLE).strip_edges()
	if stages.is_empty():
		stages = "station,tractor,cabin"
	if stages.contains("station"):
		await _station_frames()
	if stages.contains("tractor"):
		await _tractor_frames()
	if stages.contains("cabin"):
		await _cabin_frames()

	print("FIRST_PERSON_RENDER_DONE captures=%d misses=%d" % [_captures, _misses])
	quit(0 if _misses == 0 else 1)


## Walking the station: the authored chase framing, the same stance in first
## person, and what looking down at your own feet actually shows.
func _station_frames() -> void:
	_player.set_camera_view_mode(PlayerController.CameraViewMode.THIRD_PERSON)
	await _settle(30)
	await _capture("01_station_third_person.png")

	_player.toggle_camera_view_mode()
	await _settle(60)
	await _capture("02_station_first_person.png")
	print("STAGE station first_person=", _player.get_camera_view_report())

	await _walk(&"move_forward", 45)
	await _capture("03_station_first_person_walking.png")

	# Looking down is the frame that proves the body is culled rather than
	# clipped: a body that is merely inside the near plane still shows its
	# shoulders and backpack from here.
	await _look(Vector2(0.0, 900.0))
	await _settle(20)
	await _capture("04_station_first_person_looking_down.png")
	await _look(Vector2(0.0, -900.0))
	await _settle(20)
	await _capture("05_station_first_person_looking_up.png")
	await _look(Vector2(0.0, 300.0))
	await _settle(20)


## In and out of the tow tractor while first person is the chosen view. The
## driving frames must show the tractor's own chase camera, and the frame after
## hopping out must be back on the pilot's eye without a manual re-press.
func _tractor_frames() -> void:
	if not is_instance_valid(_tractor):
		print("STAGE tractor unavailable")
		return
	# Each stage states the view it is about rather than inheriting it, so any
	# one of them can be re-looked at on its own and still be the thing its file
	# names claim it is.
	_player.set_camera_view_mode(PlayerController.CameraViewMode.FIRST_PERSON)
	await _settle(30)
	var approach := _tractor.get_boarding_position()
	_player.teleport_to(Transform3D(
		Basis.looking_at(_tractor.global_position - approach, Vector3.UP),
		approach
	))
	await _settle(20)
	await _capture("06_first_person_at_the_tractor.png")

	await _press(&"interact", 2)
	await _wait(func() -> bool: return _game.is_driving_tow_tractor(), 300)
	await _settle(30)
	print("STAGE driving=", _game.is_driving_tow_tractor(), " view=", _player.get_camera_view_report())
	await _capture("07_driving_the_tractor_view_suspended.png")

	await _walk(&"move_forward", 40)
	await _capture("08_driving_the_tractor_under_way.png")
	await _settle(60)

	await _press(&"interact", 2)
	await _wait(func() -> bool: return not _game.is_driving_tow_tractor(), 300)
	await _settle(90)
	print("STAGE hopped out view=", _player.get_camera_view_report())
	await _capture("09_hopped_out_first_person_resumed.png")


## Walking a drifting Jovian's cabin in first person. This is the state the
## cabin ceiling was written for: the boom cannot fit here at all, so it is also
## the state in which first person has to prove it is not fighting the ceiling.
func _cabin_frames() -> void:
	if not is_instance_valid(_jovian):
		print("STAGE jovian unavailable")
		return
	_player.set_camera_view_mode(PlayerController.CameraViewMode.FIRST_PERSON)
	await _settle(30)
	_player.teleport_to(Transform3D(
		_jovian.global_basis.orthonormalized(),
		_jovian.get_boarding_position() + _jovian.global_basis.y.normalized() * 0.05
	))
	_player.set_control_enabled(true)
	await _settle(20)
	await _press(&"interact", 2)
	# Wait for the phase, not just the seat: `is_seated()` goes true a frame
	# before GameFlow has finished the boarding transition, and an `engine_start`
	# delivered in that gap is discarded.
	if not await _wait(
		func() -> bool: return _game.phase == GameFlow.Phase.START_ENGINES,
		600
	):
		print("STAGE jovian boarding did not reach START_ENGINES phase=", _game.phase)
		return
	print("STAGE jovian seated phase=", _game.phase)

	_jovian.engine_start_time = 0.03
	_action(&"engine_start")
	await _wait(
		func() -> bool: return str(_jovian.get_telemetry().get("engine_state")).to_upper() == "ONLINE",
		300
	)
	var origin := _jovian.global_position
	Input.action_press(&"move_forward")
	var ticks := 0
	while bool(_jovian.get_telemetry().get("landed", true)) and ticks < 240:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(&"move_forward")
	await _settle(20)
	_jovian.global_transform = Transform3D(
		_jovian.global_basis.orthonormalized(),
		origin + Vector3(0.0, 260.0, -540.0)
	)
	_jovian.velocity = -_jovian.global_basis.z * 26.0
	await _settle(10)

	_action(&"engine_stop")
	await _wait(
		func() -> bool: return str(_jovian.get_telemetry().get("engine_state")).to_upper() == "OFFLINE",
		300
	)
	await _settle(10)
	await _press(&"interact", 2)
	if not await _wait(
		func() -> bool: return bool(_game.get_in_flight_cabin_status().get("carried", false)),
		400
	):
		print("STAGE leaving the seat did not complete")
		return
	await _settle(90)
	print("STAGE in cabin view=", _player.get_camera_view_report())
	await _capture("10_cabin_first_person_out_of_the_seat.png")

	_jovian.velocity = -_jovian.global_basis.z * 9.0
	await _walk_until(
		&"move_forward",
		func() -> bool: return _jovian.to_local(_player.global_position).z > 1.5
	)
	await _capture("11_cabin_first_person_walking_the_hold.png")

	# The same place in third person, so the cabin ceiling and the first-person
	# view can be compared against each other rather than described.
	_player.toggle_camera_view_mode()
	await _settle(90)
	print("STAGE cabin third person view=", _player.get_camera_view_report())
	await _capture("12_cabin_third_person_at_the_cabin_ceiling.png")
	_player.toggle_camera_view_mode()
	await _settle(90)
	await _capture("13_cabin_first_person_restored.png")

	await _walk_until(
		&"move_back",
		func() -> bool: return _jovian.to_local(_player.global_position).z < -6.0
	)
	await _capture("14_cabin_first_person_back_at_the_seat.png")


func _clear_intro() -> void:
	var intro_press := InputEventAction.new()
	intro_press.action = &"interact"
	intro_press.pressed = true
	Input.parse_input_event(intro_press)
	var intro_release := InputEventAction.new()
	intro_release.action = &"interact"
	intro_release.pressed = false
	Input.parse_input_event(intro_release)
	Input.action_release(&"interact")
	await _settle(20)
	if _game.phase == GameFlow.Phase.INTRO:
		_game.start_shift()
		await process_frame
	await _settle(10)


func _find_game_flow() -> GameFlow:
	for child in root.get_children():
		if child is GameFlow:
			return child as GameFlow
	return null


func _look(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = relative
	_player._unhandled_input(motion)
	await process_frame


func _walk(action: StringName, ticks: int) -> void:
	Input.action_press(action)
	for _tick in ticks:
		await physics_frame
		await process_frame
	Input.action_release(action)
	await _settle(10)


func _walk_until(action: StringName, predicate: Callable) -> void:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < LOCOMOTION_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	await _settle(10)


func _press(action: StringName, ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_game._unhandled_input(event)


func _settle(frames: int) -> void:
	for _tick in maxi(1, frames):
		await physics_frame
		await process_frame


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
		_misses += 1
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(path) != OK:
		print("RENDER_SAVE_FAILED: ", file_name)
		_misses += 1
		return
	var absolute := ProjectSettings.globalize_path(path)
	_captures += 1
	print("CAPTURED: ", absolute, " (", FileAccess.get_file_as_bytes(absolute).size(), " bytes)")
