class_name StartupLoader
extends Node3D

## Boot scene root: the packaged build's `run/main_scene`.
##
## The window used to open on `scenes/main.tscn`, which meant the engine had to
## load every resource the yard references and then run every `_ready()` in the
## Main subtree before a single frame could be presented. On the reference box
## that was ~1.5 s of resource loading followed by ~1.8 s of node construction,
## all of it inside one uninterrupted main-loop iteration, so Windows marked the
## window unresponsive and the cursor was already captured by the time the
## player could see anything at all.
##
## This scene is deliberately almost empty. It presents [LoadingScreen] on the
## first frames, then does the same work in two halves that both let the main
## loop breathe:
##
## 1. **Resources.** `scenes/main.tscn` is pulled in with
##    `ResourceLoader.load_threaded_request()`, so the import work happens on
##    loader threads while this scene keeps drawing and pumping input. The bar
##    is driven by `load_threaded_get_status()`'s own percentage.
## 2. **Construction.** Scene-tree mutation must stay on the main thread, so it
##    is chunked instead: [GameFlow] hands back its authored children before it
##    enters the tree and re-adds them a frame at a time, and [ShipyardWorld]
##    walks its procedural builders the same way. Both yield on a time budget
##    rather than blindly per item, so no chunk is the whole freeze and cheap
##    ones do not each cost a drawn frame.
##
## Staged construction is strictly opt-in and lives only on this path. Anything
## that instantiates `scenes/main.tscn` directly - every test suite, and every
## detach/re-add cycle - gets the original synchronous `_ready()`, unchanged.

const LoadingScreenType := preload("res://scripts/ui/loading_screen.gd")
const SessionDiagnosticFileSinkType := preload("res://scripts/diagnostics/session_diagnostic_file_sink.gd")

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const CLI_VERSION := &"--version"
const CLI_SUPPORT_INFO := &"--support-info"
const CLI_SUPPORT_EXPORT := &"--support-export"

## Frames to present before any expensive work starts. Two, because the first
## one is where the loading screen's Controls take their layout.
const PRESENT_FRAMES := 2

## Share of the progress bar each startup phase owns. These are the measured
## proportions on the reference box, not guesses: resource loading really is
## about 45% of a cold boot and construction the rest. Inside every phase the
## bar is driven by work that has actually completed.
const PHASE_RESOURCES := 0.45
const PHASE_CONSTRUCTION := 0.52
const PHASE_HANDOFF := 0.03

signal startup_completed(main: Node)

## Set false to drive the loader by hand from a test.
@export var auto_start := true

var _screen: LoadingScreen
var _main: Node
var _running := false
## Every awaitable boot continuation is tied to this loader lifetime. Leaving
## the tree retires it before any pending resource or staged-construction yield
## can attach a Main beneath an orphaned boot root.
var _startup_generation := 0
var _boot_usec := 0
var _first_frame_usec := 0
var _resources_ready_usec := 0
var _interactive_usec := 0
var _stage_log: Array[Dictionary] = []
var _last_stage_usec := 0
var _mouse_was_free := true
var _worst_frame_ms := 0.0
var _last_frame_usec := 0
var _display_settings_report: Dictionary = {}
var _early_cli_exit_code := 0


func _ready() -> void:
	var command_line := OS.get_cmdline_args()
	var early_cli_mode := cli_mode(command_line)
	if early_cli_mode == &"support_export":
		_run_early_support_export(cli_support_export_path(command_line))
		return
	if not early_cli_mode.is_empty():
		print(format_cli_output(early_cli_mode))
		call_deferred("_quit_after_cli_output")
		return
	_boot_usec = Time.get_ticks_usec()
	# Nothing is playable yet, so nothing may own the cursor. This is also the
	# backstop for a reloaded scene: `reload_current_scene()` returns here with
	# whatever mouse mode gameplay left behind.
	_release_mouse()
	_screen = LoadingScreenType.new()
	_screen.name = "LoadingScreen"
	_screen.configure(_read_accessibility_descriptor())
	add_child(_screen)
	_screen.set_stage(
		"Starting up", 0.0, "Preparing station manifest",
		"MUDDS SHIPYARDS", "Station data", 1, 3
	)
	if auto_start:
		run_startup()


func _quit_after_cli_output() -> void:
	get_tree().quit(_early_cli_exit_code)


## Returns the one supported early-start information mode, or an empty name.
## Unknown arguments remain the ordinary game startup path. If both supported
## flags are present, the more detailed support report wins deterministically.
static func cli_mode(args: PackedStringArray) -> StringName:
	if CLI_SUPPORT_EXPORT in args:
		return &"support_export"
	if CLI_SUPPORT_INFO in args:
		return &"support_info"
	if CLI_VERSION in args:
		return &"version"
	return &""


static func cli_support_export_path(args: PackedStringArray) -> String:
	var flag_index := args.find(CLI_SUPPORT_EXPORT)
	if flag_index < 0 or flag_index + 1 >= args.size():
		return ""
	return args[flag_index + 1]


func _run_early_support_export(export_root: String) -> void:
	var result: Dictionary
	if export_root.is_empty():
		result = {"accepted": false, "reason": &"support_export_path_missing"}
	else:
		var sink := SessionDiagnosticFileSinkType.new("user://diagnostics")
		result = sink.export_support_bundle_next_generation(export_root)
	_early_cli_exit_code = 0 if bool(result.get("accepted", false)) else 1
	print("Support export: %s" % ("completed" if _early_cli_exit_code == 0 else "rejected"))
	call_deferred("_quit_after_cli_output")


## Produces only stable build/runtime facts. This intentionally omits paths,
## usernames, hardware identifiers, settings, saves, and environment values.
static func format_cli_output(mode: StringName) -> String:
	var project_name := str(ProjectSettings.get_setting("application/config/name", "Mudds Shipyards"))
	var project_version := str(ProjectSettings.get_setting("application/config/version", "unknown"))
	if mode == &"version":
		return "%s %s" % [project_name, project_version]
	if mode != &"support_info":
		return ""
	var engine_info := Engine.get_version_info()
	var engine_version := str(engine_info.get("string", "unknown"))
	return "\n".join([
		"Project: %s" % project_name,
		"Version: %s" % project_version,
		"Godot: %s" % engine_version,
		"OS: %s" % OS.get_name(),
		"Architecture: %s" % Engine.get_architecture_name(),
		"Renderer: %s" % RenderingServer.get_current_rendering_method(),
		"Display: %s" % DisplayServer.get_name(),
	])


func _exit_tree() -> void:
	# ResourceLoader work cannot be cancelled, but its eventual continuation must
	# never perform scene-tree work for a boot root that has left the tree.
	if _running and is_instance_valid(_main):
		var incomplete_main := _main
		_main = null
		if incomplete_main.get_parent() == self:
			remove_child(incomplete_main)
		incomplete_main.queue_free()
	_startup_generation += 1
	_running = false


## Loads and constructs Main behind the loading screen. Awaitable; also safe to
## call and forget, which is what `_ready()` does.
func run_startup() -> Node:
	if _running or is_instance_valid(_main) or not is_inside_tree():
		return _main
	_startup_generation += 1
	var startup_generation := _startup_generation
	_running = true
	var tree := get_tree()

	# Present before working. Until these frames have gone out there is nothing
	# on screen but the engine boot splash, and any long call made here would be
	# indistinguishable from the freeze this whole scene exists to remove.
	for _index in PRESENT_FRAMES:
		await tree.process_frame
		if not _is_startup_current(startup_generation):
			return null
	_first_frame_usec = Time.get_ticks_usec()
	_last_stage_usec = _first_frame_usec
	_screen.attach_backdrop()

	var packed := await _load_main_scene(startup_generation)
	if not _is_startup_current(startup_generation):
		return null
	_resources_ready_usec = Time.get_ticks_usec()
	if packed == null:
		_screen.set_stage(
			"Startup failed", 1.0, "scenes/main.tscn could not be loaded",
			"MUDDS SHIPYARDS", "Startup interrupted", 1, 1
		)
		_finish_startup(startup_generation)
		return null

	_main = packed.instantiate()
	if not _is_startup_current(startup_generation):
		_main.queue_free()
		_main = null
		return null
	var flow := _main as GameFlow
	var staged := flow != null and flow.prepare_staged_startup()
	add_child(_main)
	if staged:
		await flow.run_staged_startup(
			func(label: String, ratio: float) -> void:
				_on_construction_stage(startup_generation, label, ratio)
		)
		if not _is_startup_current(startup_generation):
			return null
		_note_stage("construction", "Shipyard ready")

	# Suppressing 3D behind the opaque loading screen was measured and rejected:
	# it does not remove the renderer's one-time warm-up, it collects all of it -
	# including every deferred reflection-probe bake - into the single frame that
	# turns 3D back on, which is exactly the monolithic stall this scene exists to
	# break up. Letting each staged chunk draw spreads that warm-up over frames
	# the loading screen is already repainting between.
	_screen.set_stage(
		"Entering the yard", PHASE_RESOURCES + PHASE_CONSTRUCTION, "Preparing player control",
		"MUDDS SHIPYARDS", "Handoff", 3, 3
	)
	await tree.process_frame
	if not _is_startup_current(startup_generation):
		return null
	_screen.set_stage(
		"Entering the yard", PHASE_RESOURCES + PHASE_CONSTRUCTION + PHASE_HANDOFF, "Yard ready",
		"MUDDS SHIPYARDS", "Handoff", 3, 3
	)
	_interactive_usec = Time.get_ticks_usec()
	_screen.dismiss()
	_finish_startup(startup_generation)
	startup_completed.emit(_main)
	return _main


func get_main() -> Node:
	return _main


func get_loading_screen() -> LoadingScreen:
	return _screen


## Honest startup timings, in milliseconds from the boot scene's `_ready()`.
##
## `time_to_first_frame_ms` is when the loading screen was on screen and the
## window was already pumping input. `time_to_interactive_ms` is when the title
## screen's "BEGIN SHIFT" became pressable. `worst_frame_ms` is the longest
## single main-loop iteration between those two, which is the number that decides
## whether the OS thinks the window has stopped responding - a phase that takes a
## second spread over sixty drawn frames costs the player nothing, and a single
## uninterrupted second costs them the window.
func get_startup_report() -> Dictionary:
	return {
		"time_to_first_frame_ms": _ms_since_boot(_first_frame_usec),
		"time_to_resources_ms": _ms_since_boot(_resources_ready_usec),
		"time_to_interactive_ms": _ms_since_boot(_interactive_usec),
		"worst_frame_ms": _worst_frame_ms,
		"stages": _stage_log.duplicate(true),
		"mouse_free_during_load": _mouse_was_free,
	}


func _ms_since_boot(usec: int) -> float:
	if usec <= 0 or _boot_usec <= 0:
		return 0.0
	return (usec - _boot_usec) / 1000.0


func _load_main_scene(startup_generation: int) -> PackedScene:
	if not _is_startup_current(startup_generation):
		return null
	var tree := get_tree()
	var request := ResourceLoader.load_threaded_request(MAIN_SCENE_PATH, "PackedScene", false)
	if request != OK:
		# A loader thread was refused. Fall back to the blocking load rather than
		# failing to boot; the loading screen is still up, it just stops moving.
		_screen.set_stage(
			"Loading station data", PHASE_RESOURCES, "Fallback resource load",
			"MUDDS SHIPYARDS", "Station data", 1, 3
		)
		var fallback := load(MAIN_SCENE_PATH) as PackedScene
		_note_stage("resources", "Loading station data")
		return fallback
	var progress: Array = []
	while true:
		if not _is_startup_current(startup_generation):
			return null
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, progress)
		var ratio := 0.0
		if not progress.is_empty():
			ratio = clampf(float(progress[0]), 0.0, 1.0)
		_screen.set_stage(
			"Loading station data",
			PHASE_RESOURCES * ratio,
			"Resource load %d%%" % roundi(ratio * 100.0),
			"MUDDS SHIPYARDS",
			"Station data",
			1,
			3
		)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_note_stage("resources", "Loading station data")
			return null
		# Yielding here is the point: the window repaints and pumps input while
		# the loader threads work.
		await tree.process_frame
		if not _is_startup_current(startup_generation):
			return null
	_screen.set_stage(
		"Loading station data", PHASE_RESOURCES, "Resource load 100%",
		"MUDDS SHIPYARDS", "Station data", 1, 3
	)
	_note_stage("resources", "Loading station data")
	return ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene


## Progress sink handed to [method GameFlow.run_staged_startup]. `ratio` is the
## fraction of construction stages finished, weighted by nothing - it is a plain
## count of real stages that have run.
func _on_construction_stage(startup_generation: int, label: String, ratio: float) -> void:
	if not _is_startup_current(startup_generation) or not is_instance_valid(_screen):
		return
	_screen.set_stage(
		"Building the shipyard",
		PHASE_RESOURCES + PHASE_CONSTRUCTION * clampf(ratio, 0.0, 1.0),
		label,
		"MUDDS SHIPYARDS",
		"Yard construction",
		2,
		3
	)
	_note_stage("construction", label)


func _is_startup_current(startup_generation: int) -> bool:
	return (
		_running
		and startup_generation == _startup_generation
		and is_inside_tree()
		and not is_queued_for_deletion()
	)


func _finish_startup(startup_generation: int) -> void:
	if startup_generation == _startup_generation:
		_running = false


func _note_stage(phase: String, label: String) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := 0.0
	if _last_stage_usec > 0:
		elapsed = (now - _last_stage_usec) / 1000.0
	_last_stage_usec = now
	_stage_log.append({
		"phase": phase,
		"label": label,
		"elapsed_ms": elapsed,
		"at_ms": _ms_since_boot(now),
	})


func _release_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if not _running:
		return
	# Wall clock between two `_process` calls, which is the length of the
	# main-loop iteration that just finished - the stall the player would have
	# felt. `delta` cannot be used for this: the engine clamps it, so a two-second
	# freeze and a 150 ms one arrive here looking identical.
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		_worst_frame_ms = maxf(_worst_frame_ms, (now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now
	if DisplayServer.get_name() == "headless":
		return
	# A regression here is invisible in a screenshot and obvious to a player, so
	# it is recorded rather than assumed: nothing may capture the cursor while
	# the loading screen owns the window.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_mouse_was_free = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Reads the stored accessibility preferences without constructing any gameplay.
## `RuntimeSettings` is documented as side-effect free to load, so this cannot
## disturb the presets `GameFlow` applies for real a moment later; the one global
## it does apply is the window mode, so the player who chose fullscreen sees the
## loading screen in fullscreen instead of a window that jumps afterwards.
func _read_accessibility_descriptor() -> Dictionary:
	var settings := RuntimeSettings.new()
	var error := settings.load_from_file()
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Startup could not read stored settings: %s" % error_string(error))
		_display_settings_report = {"applied": false, "reason": &"settings_load_failed"}
		return {}
	var window_report := settings.apply_window_mode()
	var display_report := settings.apply_display_settings()
	_display_settings_report = {
		"applied": bool(window_report.get("applied", false)) or bool(display_report.get("applied", false)),
		"window": window_report,
		"display": display_report,
		"headless": display_report.get("reason", &"") == &"headless",
	}
	return settings.get_accessibility_descriptor()


func get_display_settings_report() -> Dictionary:
	return _display_settings_report.duplicate(true)


## Applies a validated snapshot at the startup boundary and retains only a
## detached report. Tests and alternate boot owners can provide their already
## loaded settings without coupling this loader to persistence.
func apply_runtime_settings(settings: RuntimeSettings) -> Dictionary:
	var window_report := settings.apply_window_mode()
	var display_report := settings.apply_display_settings()
	_display_settings_report = {
		"applied": bool(window_report.get("applied", false)) or bool(display_report.get("applied", false)),
		"window": window_report,
		"display": display_report,
		"headless": display_report.get("reason", &"") == &"headless",
	}
	return get_display_settings_report()
