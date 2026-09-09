extends Node

## Opt-in native performance capture. No input, quality, frame cap or gameplay
## changes. Renderer timestamps are delayed and must not be subtracted from
## same-row wall times; zero GPU samples mean timing is unavailable.
const MAX_SECONDS := 600.0
const MAX_FRAMES := 120000
const FLUSH_FRAMES := 120

var _file: FileAccess
var _rows: Array = []
var _started_usec := 0
var _previous_usec := 0
var _last_flush_usec := 0
var _frame_count := 0
var _pending_write_ms := 0.0
var _main: WeakRef
var _viewport: Viewport
var _measuring := false
var _capture_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func start_capture(path: String = "") -> bool:
	if _file != null or not is_inside_tree():
		return false
	_capture_path = path
	if _capture_path.is_empty():
		_capture_path = "user://frame-capture-%d-%d-%d.jsonl" % [
			int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()
		]
	# Capture must never replace a previous recording.
	if FileAccess.file_exists(_capture_path):
		return false
	_file = FileAccess.open(_capture_path, FileAccess.WRITE)
	if _file == null:
		push_warning("Frame capture could not open its output file.")
		return false
	_viewport = get_viewport()
	_measuring = DisplayServer.get_name() != "headless"
	if _measuring:
		RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	_write_event({
		"event": "start", "executable": OS.get_executable_path().get_file(),
		"project_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"engine": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(), "cpu": OS.get_processor_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_driver": DisplayServer.get_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"max_seconds": MAX_SECONDS, "max_frames": MAX_FRAMES,
		"columns": ["elapsed_ms", "wall_ms", "viewport_cpu_ms", "viewport_gpu_ms", "phase", "previous_write_ms"],
		"timing_note": "Viewport samples are delayed. Null GPU time is unavailable, not zero GPU work. Wall intervals include capture overhead. Phase -1 is startup; other IDs match GameFlow.Phase.",
		"view": _view_context(),
	})
	_file.flush()
	if _file.get_error() != OK:
		_close_capture()
		return false
	_frame_count = 0
	_pending_write_ms = 0.0
	_started_usec = Time.get_ticks_usec()
	_previous_usec = _started_usec
	_last_flush_usec = _started_usec
	set_process(true)
	print("FRAME_CAPTURE_STARTED: ", ProjectSettings.globalize_path(_capture_path))
	return true


func on_startup_completed(main: Node) -> void:
	_main = weakref(main)
	if _file != null:
		_flush_rows()
		if _file == null:
			return
		_write_event({"event": "menu_handoff", "view": _view_context()})
		_file.flush()


func _view_context() -> Dictionary:
	return {
		"viewport_size": str(_viewport.get_visible_rect().size),
		"scale_3d": _viewport.scaling_3d_scale, "msaa_3d": _viewport.msaa_3d,
		"frame_cap": Engine.max_fps,
	}


func _process(_delta: float) -> void:
	if _file == null:
		return
	var now := Time.get_ticks_usec()
	var elapsed := float(now - _started_usec) / 1000.0
	var main: Node = _main.get_ref() as Node if _main != null else null
	var cpu_ms: Variant = null
	var gpu_ms: Variant = null
	if _measuring:
		cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(_viewport.get_viewport_rid())
		var measured_gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport.get_viewport_rid())
		if measured_gpu > 0.0:
			gpu_ms = measured_gpu
	_rows.append([
		elapsed, float(now - _previous_usec) / 1000.0, cpu_ms, gpu_ms,
		int(main.get("phase")) if main != null else -1, _pending_write_ms,
	])
	_pending_write_ms = 0.0
	_previous_usec = now
	_frame_count += 1
	if elapsed >= MAX_SECONDS * 1000.0 or _frame_count >= MAX_FRAMES:
		stop_capture("limit")
	elif _rows.size() >= FLUSH_FRAMES or now - _last_flush_usec >= 1000000:
		_flush_rows()


func _write_event(event: Dictionary) -> void:
	_file.store_line(JSON.stringify(event))


func _flush_rows() -> void:
	if _file == null or _rows.is_empty():
		return
	var began := Time.get_ticks_usec()
	_write_event({"event": "frames", "view": _view_context(), "samples": _rows})
	_file.flush()
	_rows.clear()
	_last_flush_usec = Time.get_ticks_usec()
	_pending_write_ms += float(_last_flush_usec - began) / 1000.0
	if _file.get_error() != OK:
		push_warning("Frame capture stopped after a file write error.")
		_close_capture()


func stop_capture(reason: String = "exit") -> void:
	if _file == null:
		return
	_flush_rows()
	if _file != null:
		_write_event({"event": "stop", "reason": reason, "frames": _frame_count})
		_file.flush()
	_close_capture()


func _close_capture() -> void:
	_file = null
	set_process(false)
	if _measuring and is_instance_valid(_viewport):
		RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), false)
	_measuring = false


func _exit_tree() -> void:
	stop_capture()
