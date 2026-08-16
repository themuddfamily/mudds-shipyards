extends SceneTree

## Human-review render of every HUD state the game can be in, driven through the
## real production scene. This is a looking tool, not a gate: it is deliberately
## not named `*_test.gd`, so it never joins the release matrix.
##
## A HUD defect is by definition visible and by definition invisible to an
## assertion — both of the stale readouts found on 2026-08-16 were found by
## looking at a frame. The states below are the complete set the player can
## reach: walking the station, driving the yard tractor, seated and shut down,
## seated and flying, and in combat. On foot *inside* a flying craft has its own
## tool, `tests/in_flight_cabin_render.gd`, because reaching it needs the whole
## seat-exit transition.
##
## Each capture also prints the chase boom's clearance at that moment, so the
## camera-comfort half of the same pass can be read off the same run rather than
## guessed at from the picture.
##
## Usage:
##   xvfb-run -a -s "-screen 0 2560x1440x24" godot --path <worktree> \
##     --display-driver x11 --rendering-driver vulkan \
##     --script tests/hud_state_render.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts"
const TICK_BUDGET := 400

var _game: GameFlow
var _player: PlayerController
var _hud: GameHUD
var _ship: HeroShip
var _tractor: TowTractor


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# `--script` still auto-loads the project's main scene and it owns the root
	# viewport. Drive that instance, or the shot is the auto-loaded copy's intro
	# overlay drawn over this script's world.
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
	_hud = _game.get_node("HUD") as GameHUD
	_ship = _game.get_node_or_null("TorrentInterceptor") as HeroShip
	_tractor = _find_tractor(_game)
	_game.canopy_motion_time = 0.02
	_game.boarding_motion_time = 0.25
	_game.disembarking_motion_time = 0.25

	await _capture("hud_00_intro.png")

	# The intro overlay is retired by the HUD's own input handler, not by
	# `start_shift()`. Parse a real action event so the panel actually clears.
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	Input.action_release(&"interact")
	for _tick in 20:
		await process_frame
		await physics_frame
	if _game.phase == GameFlow.Phase.INTRO:
		_game.start_shift()
		await process_frame
	for _tick in 12:
		await process_frame
		await physics_frame
	await _capture("hud_01_on_foot_station.png")

	await _render_tractor()
	await _render_piloting()

	print("HUD_STATE_RENDER_DONE")
	quit(0)


## Driving the yard tractor. The seat is taken through the real prompt-and-press
## path so the HUD state is whatever production actually publishes.
func _render_tractor() -> void:
	if not is_instance_valid(_tractor):
		print("RENDER_SKIP tractor unavailable")
		return
	await _stand_facing(_tractor.get_boarding_position(), _tractor.global_position)
	print("RENDER_STAGE at tractor step, prompt=", _interaction_text())
	await _capture("hud_02_tractor_prompt.png")
	await _press(&"interact", 2)
	var seated := await _wait(func() -> bool: return _tractor.is_driven(), 300)
	for _tick in 20:
		await physics_frame
		await process_frame
	print("RENDER_STAGE tractor driven=", _tractor.is_driven(), " reached=", seated)
	await _capture("hud_03_driving_tractor.png")

	# Under way, which is the state the controls card has to be right for.
	Input.action_press(&"move_forward")
	for _tick in 90:
		await physics_frame
		await process_frame
	await _capture("hud_04_driving_under_way.png")
	Input.action_release(&"move_forward")
	Input.action_press(&"jump")
	for _tick in 90:
		await physics_frame
		await process_frame
	Input.action_release(&"jump")
	for _tick in 30:
		await physics_frame
		await process_frame
	print("RENDER_STAGE tractor stopped, prompt=", _interaction_text())
	await _press(&"interact", 2)
	await _wait(func() -> bool: return not _tractor.is_driven(), 300)
	for _tick in 20:
		await physics_frame
		await process_frame
	await _capture("hud_05_back_on_foot.png")


## Places the walking body at `position` looking at `look_at_target`, so the
## interaction prompt and the chase framing are the ones a player who walked up
## would actually get.
func _stand_facing(position: Vector3, look_at_target: Vector3) -> void:
	var forward := (look_at_target - position)
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var basis := Basis.looking_at(forward, Vector3.UP)
	_player.teleport_to(Transform3D(basis, position + Vector3.UP * 0.15))
	_player.set_control_enabled(true)
	for _tick in 16:
		await physics_frame
		await process_frame


func _interaction_text() -> String:
	var label := _hud.get("_interaction_label") as Label
	var panel := _hud.get("_interaction_panel") as Control
	if label == null or panel == null:
		return "<none>"
	return "%s (visible=%s)" % [label.text, str(panel.visible)]


## Seated in a craft: shut down on the pad, then flying, then in combat.
func _render_piloting() -> void:
	if not is_instance_valid(_ship):
		print("RENDER_SKIP hero ship unavailable")
		return
	await _stand_facing(_ship.get_boarding_position(), _ship.global_position)
	print("RENDER_STAGE at craft, prompt=", _interaction_text())
	await _press(&"interact", 2)
	var boarded := await _wait(
		func() -> bool: return _game.phase == GameFlow.Phase.START_ENGINES,
		400
	)
	for _tick in 16:
		await physics_frame
		await process_frame
	print("RENDER_STAGE boarded=", boarded, " phase=", _game.phase)
	await _capture("hud_06_seated_engines_off.png")

	_ship.engine_start_time = 0.05
	_action(&"engine_start")
	await _wait(
		func() -> bool: return str(_ship.get_telemetry().get("engine_state")).to_upper() == "ONLINE",
		300
	)
	Input.action_press(&"move_forward")
	var ticks := 0
	while bool(_ship.get_telemetry().get("landed", true)) and ticks < 300:
		await physics_frame
		await process_frame
		ticks += 1
	for _tick in 120:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _tick in 20:
		await physics_frame
		await process_frame
	await _capture("hud_07_piloting_in_flight.png")

	# Combat overlay on a live flight frame. The enemy readout, the caption
	# channel and the directional damage cue are published straight to the HUD
	# rather than flown into a real engagement: this tool exists to look at the
	# panels, and the encounter itself is covered by the combat suites.
	_hud.set_captions_enabled(true)
	_hud.set_enemy_status("Range Defence Interceptor", 26.0, 100.0, true)
	_hud.caption_cue(&"combat_alert")
	_hud.caption_cue(&"hull_impact_heavy")
	_hud.update_ship_telemetry({
		"speed": _ship.velocity.length(),
		"altitude": maxf(0.0, _ship.global_position.y),
		"throttle": -0.8,
		"hull": 31.0,
		"maximum_hull": 100.0,
		"damage_status": "critical",
		"engine_power": 0.58,
		"engine_state": "ONLINE",
	})
	_hud.flash_damage(1.0, Vector2(-0.7, -0.7))
	_hud.toast("Hostile contact", "Range defence interceptor is engaging")
	for _tick in 8:
		await process_frame
	await _capture("hud_08_combat.png")

	print("RENDER_STAGE combat overlay captured")
	_hud.set_paused(true)
	for _tick in 8:
		await process_frame
	await _capture("hud_09_paused.png")
	_hud.set_paused(false)
	for _tick in 4:
		await process_frame
	print("RENDER_STAGE piloting sequence complete")


func _find_game_flow() -> GameFlow:
	for child in root.get_children():
		if child is GameFlow:
			return child as GameFlow
	return null


func _find_tractor(from: Node) -> TowTractor:
	for candidate in from.find_children("*", "TowTractor", true, false):
		return candidate as TowTractor
	return null


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


func _wait(predicate: Callable, budget: int) -> bool:
	var frames := 0
	while not bool(predicate.call()):
		if frames >= budget:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


## Reports the live chase boom alongside the shot, so camera clearance is a
## measured number in the log rather than an impression from the picture.
func _report_camera(file_name: String) -> void:
	var arm := _player.get_node_or_null(
		"CameraRig/CameraYaw/CameraPitch/SpringArm3D"
	) as SpringArm3D
	if arm == null:
		return
	var camera := arm.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		return
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	# The camera's own near-plane corner, so an overlap here means the near plane
	# can reach a surface and the shot will show the inside of it.
	sphere.radius = camera.near * sqrt(
		1.0 + pow(tan(deg_to_rad(camera.fov) * 0.5), 2.0) * 2.0
	)
	probe.shape = sphere
	probe.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	probe.collision_mask = arm.collision_mask
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(probe, 6)
	var names := PackedStringArray()
	for hit: Dictionary in hits:
		var collider: Variant = hit.get("collider")
		names.append(str((collider as Node).name) if collider is Node else "?")
	print("   CAMERA %s boom=%.2f/%.2f near_plane_intrusions=%d %s" % [
		file_name, arm.get_hit_length(), arm.spring_length, hits.size(), str(names)
	])


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(_player):
		_report_camera(file_name)
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
