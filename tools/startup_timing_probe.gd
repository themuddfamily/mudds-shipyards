extends SceneTree

## Temporary before/after startup measurement. Run under a real rendering device:
##
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot \
##     --path . --rendering-driver vulkan --script res://tools/startup_timing_probe.gd -- <mode>
##
## `mode` is `legacy` (what the packaged build used to do: open straight onto
## scenes/main.tscn) or `staged` (the boot scene). Both report the wall-clock
## time to the first *presented* frame and to the point the title screen is
## pressable, plus the longest single main-thread stall in between.

const OUTPUT_DIR := "res://artifacts/startup"

var _mode := "staged"
var _frames: Array[float] = []
var _last_frame_usec := 0
var _watching := false
## Set from a signal handler. A bound method, not a lambda: GDScript lambdas
## capture locals by value, so a flag set inside one never reaches the caller.
var _startup_finished := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		_mode = str(argument)
	call_deferred("_run")


## True only when a real rendering device exists. Under `--headless` there is
## none: `RenderingServer.frame_post_draw` never fires and `get_image()` returns
## null, so both are skipped. A headless run still measures the CPU-side cost of
## construction, which is the half of startup that transfers to other machines.
func _has_render_device() -> bool:
	return not RenderingServer.get_video_adapter_name().is_empty()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("RENDER DEVICE: '%s'" % RenderingServer.get_video_adapter_name())
	if _mode == "legacy":
		await _run_legacy()
	else:
		await _run_staged()
	_report_frames()
	quit()


func _begin_frame_watch() -> void:
	_watching = true
	_last_frame_usec = Time.get_ticks_usec()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if not _watching:
		return
	var now := Time.get_ticks_usec()
	_frames.append((now - _last_frame_usec) / 1000.0)
	_last_frame_usec = now


func _report_frames() -> void:
	_watching = false
	var worst := 0.0
	var over_250 := 0
	for interval in _frames:
		worst = maxf(worst, interval)
		if interval > 250.0:
			over_250 += 1
	print("FRAMES presented during startup: %d" % _frames.size())
	print("WORST main-loop iteration: %.1f ms" % worst)
	print("ITERATIONS over 250 ms: %d" % over_250)
	var cumulative := 0.0
	var timeline := PackedStringArray()
	for index in mini(_frames.size(), 10):
		cumulative += _frames[index]
		timeline.append("%.0f" % cumulative)
	print("FIRST FRAMES presented at (ms): %s" % ", ".join(timeline))


## What the shipped build did before this change: the engine opens directly onto
## scenes/main.tscn, so nothing can be presented until every resource has loaded
## and every `_ready()` in the Main subtree has run.
func _run_legacy() -> void:
	var t0 := Time.get_ticks_usec()
	_begin_frame_watch()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	if _has_render_device():
		await RenderingServer.frame_post_draw
	else:
		await process_frame
	var first_frame := (Time.get_ticks_usec() - t0) / 1000.0
	print("LEGACY time_to_first_frame_ms: %.1f" % first_frame)
	print("LEGACY time_to_interactive_ms: %.1f" % first_frame)
	await _await_settled("LEGACY", t0)
	await _snapshot("legacy_first_frame")


func _on_startup_completed(_main: Node) -> void:
	_startup_finished = true


## Runs until the renderer stops hitching: five consecutive main-loop iterations
## under 200 ms. Both modes are reported at this same point, because "something
## appeared" and "the game is actually running" are different moments and the
## legacy path only ever looked good on the first of them.
func _await_settled(label: String, t0: int) -> void:
	var calm := 0
	var guard := 0
	while calm < 5 and guard < 24:
		var before := Time.get_ticks_usec()
		await process_frame
		var elapsed := (Time.get_ticks_usec() - before) / 1000.0
		calm = calm + 1 if elapsed < 200.0 else 0
		guard += 1
	print("%s time_to_settled_ms: %.1f" % [label, (Time.get_ticks_usec() - t0) / 1000.0])


func _run_staged() -> void:
	var t0 := Time.get_ticks_usec()
	_begin_frame_watch()
	var packed := load("res://scenes/boot.tscn") as PackedScene
	var boot := packed.instantiate() as StartupLoader
	root.add_child(boot)
	if _has_render_device():
		await RenderingServer.frame_post_draw
	else:
		await process_frame
	print("STAGED time_to_first_presented_frame_ms: %.1f" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var captured := false
	boot.startup_completed.connect(_on_startup_completed)
	var last_stage := ""
	while not _startup_finished:
		var screen := boot.get_loading_screen()
		if is_instance_valid(screen) and str(screen.get_report()["detail"]) != last_stage:
			last_stage = str(screen.get_report()["detail"])
			print("  ...%6.0f ms  %.0f%%  %s" % [
				(Time.get_ticks_usec() - t0) / 1000.0,
				screen.get_progress() * 100.0,
				last_stage,
			])
		if not captured and is_instance_valid(screen) and screen.get_progress() > 0.55:
			captured = true
			await _snapshot("loading_screen_mid")
		await process_frame
	await _await_settled("STAGED", t0)
	var report := boot.get_startup_report()
	print("STAGED time_to_first_frame_ms: %.1f" % float(report["time_to_first_frame_ms"]))
	print("STAGED time_to_resources_ms: %.1f" % float(report["time_to_resources_ms"]))
	print("STAGED time_to_interactive_ms: %.1f" % float(report["time_to_interactive_ms"]))
	print("STAGED worst_frame_ms: %.1f" % float(report["worst_frame_ms"]))
	print("STAGED mouse_free_during_load: %s" % str(report["mouse_free_during_load"]))
	for entry: Dictionary in report["stages"]:
		print("  STAGE %-40s %8.1f ms  (@ %.0f ms)" % [
			entry["label"], float(entry["elapsed_ms"]), float(entry["at_ms"])
		])
	await _snapshot("staged_title_screen")


func _snapshot(label: String) -> void:
	await process_frame
	if not _has_render_device():
		print("NO RENDER DEVICE, skipping snapshot %s" % label)
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		print("NO IMAGE for %s" % label)
		return
	var path := "%s/%s.png" % [OUTPUT_DIR, label]
	image.save_png(path)
	print("CAPTURED: %s" % path)
