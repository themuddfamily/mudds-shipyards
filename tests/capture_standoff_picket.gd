extends SceneTree

## Rendered evidence for the standoff picket lance.
##
## The harness instantiates the production `Main` scene, stages the picket (and
## for one frame the existing range defender beside it) in an empty volume well
## clear of the yard, and photographs the states a player actually has to read:
## the hull silhouette, the long lance charge, the magenta lance in flight, the
## team read against the existing defender, and a critically damaged hull.
##
## It adds one evidence camera and advances the pooled presentation's public
## deterministic clock. Those are evidence controls, not a claim of an
## uninterrupted player-driven dogfight. This file is deliberately not named
## `*_test.gd`, so the frozen test matrix does not collect it.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/picket_visuals"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
## Open space outside the yard. The production WorldEnvironment and its key
## light are global, so the frames are lit exactly as they are in play without a
## harness light and without station structure crowding the silhouette.
const ARENA_ORIGIN := Vector3(360.0, 96.0, -430.0)
const CAMERA_FOV := 40.0

var _failures: Array[String] = []
var _game: GameFlow
var _picket: StandoffPicketOpponent
var _defender: RangeOpponent
var _pulse: PulseWeaponPresentation
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = MAIN_SCENE.instantiate() as GameFlow
	root.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame

	# Same HUD policy as the existing combat capture: every CanvasLayer is hidden
	# and disabled so the frames show only the rendered 3D craft.
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	_picket = _game.get_node("StandoffPicket") as StandoffPicketOpponent
	_defender = _game.get_node("RangeOpponent") as RangeOpponent
	_pulse = _game.get_node("PulseWeaponPresentation") as PulseWeaponPresentation
	_pulse.set_auto_advance_enabled(false)
	_picket.escort_enabled = false
	_picket.acceleration = 0.0

	_camera = Camera3D.new()
	_camera.name = "PicketEvidenceCamera"
	_camera.fov = CAMERA_FOV
	_camera.far = 4000.0
	root.add_child(_camera)
	_camera.current = true

	var picket_pose := Transform3D(
		Basis.looking_at(Vector3(-0.62, -0.10, -0.78).normalized(), Vector3.UP).orthonormalized(),
		ARENA_ORIGIN
	)
	_picket.activate(picket_pose)
	_picket.global_transform = picket_pose
	_picket.velocity = Vector3.ZERO
	await _settle(6)

	# Front three-quarter: the lance barrel and the identification stripe are the
	# two things a player has to recognise.
	_aim_camera(ARENA_ORIGIN + Vector3(0.0, 0.0, -2.0), Vector3(-0.86, 0.26, -0.62), 26.0)
	await _capture("01_picket_hull_profile.png")

	# Long lance charge: the dominant long-range read.
	_picket.set("_telegraph_remaining", _picket.telegraph_time * 0.16)
	await _settle(3)
	_aim_camera(ARENA_ORIGIN + Vector3(0.0, 0.0, -5.0), Vector3(-0.62, 0.20, -0.78), 22.0)
	await _capture("02_lance_charging.png")

	# Magenta lance in flight against the player's cyan and the defender's amber.
	var muzzle := (_picket.get_node("LanceMuzzle") as Marker3D).global_position
	var lance_end := muzzle + (-_picket.global_basis.z) * 120.0
	_pulse.present_shot(muzzle, lance_end, &"magenta", _picket, true, -1)
	_pulse.present_shot(
		muzzle + Vector3(0.0, 14.0, 0.0),
		lance_end + Vector3(0.0, 14.0, 0.0),
		&"cyan",
		null,
		true,
		-1
	)
	_pulse.present_shot(
		muzzle + Vector3(0.0, -14.0, 0.0),
		lance_end + Vector3(0.0, -14.0, 0.0),
		&"amber",
		null,
		true,
		-1
	)
	_pulse.advance_simulation(0.13)
	await _settle(2)
	_aim_camera(ARENA_ORIGIN + Vector3(0.0, 0.0, -34.0), Vector3(1.0, 0.14, 0.06), 52.0)
	await _capture("03_lance_in_flight_vs_cyan_amber.png")
	_pulse.clear_effects()

	# Team read: the two opponent archetypes side by side at combat distance.
	var defender_pose := Transform3D(
		Basis.looking_at(Vector3(-0.62, -0.10, -0.78).normalized(), Vector3.UP).orthonormalized(),
		ARENA_ORIGIN + Vector3(24.0, 0.0, 4.0)
	)
	_defender.activate(defender_pose)
	_defender.global_transform = defender_pose
	_defender.velocity = Vector3.ZERO
	await _settle(6)
	_aim_camera(ARENA_ORIGIN + Vector3(12.0, 0.0, 2.0), Vector3(-0.72, 0.30, -0.62), 46.0)
	await _capture("04_picket_and_defender.png")

	# Critically damaged hull.
	_picket.apply_damage(_picket.maximum_health * 0.72, _picket.global_position)
	await _settle(30)
	_aim_camera(ARENA_ORIGIN + Vector3(0.0, 0.0, 1.0), Vector3(-0.55, 0.30, 0.82), 24.0)
	await _capture("05_picket_critical_damage.png")

	_picket.deactivate()
	_defender.deactivate()
	print("CAPTURE_STANDOFF_PICKET_DONE: %s" % OUTPUT_DIR)
	if _failures.is_empty():
		quit(0)
	else:
		print("CAPTURE_STANDOFF_PICKET_FAILED: ", "; ".join(_failures))
		quit(1)


func _aim_camera(focus: Vector3, direction: Vector3, distance: float) -> void:
	var offset := direction.normalized() * distance
	var origin := focus + offset
	_camera.global_transform = Transform3D(
		Basis.looking_at((focus - origin).normalized(), Vector3.UP).orthonormalized(),
		origin
	)


func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame


func _capture(file_name: String) -> void:
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("%s produced an empty viewport image" % file_name)
		return
	image.convert(Image.FORMAT_RGB8)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_failures.append("%s could not be written: %s" % [file_name, error_string(error)])
		return
	print("CAPTURED: %s  size=%s" % [path, str(image.get_size())])
