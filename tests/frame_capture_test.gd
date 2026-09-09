extends SceneTree

const Capture := preload("res://scripts/diagnostics/frame_capture.gd")
var failures: Array[String] = []

class MainFixture extends Node:
	var phase := 1

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func read_events(path: String) -> Array:
	var result: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		result.append(JSON.parse_string(line))
	return result

func _run() -> void:
	var capture := Capture.new()
	root.add_child(capture)
	check(not capture.is_processing() and capture._file == null, "Capture remains inactive until explicitly started")
	var path := "user://capture-test-%d.jsonl" % Time.get_ticks_usec()
	check(capture.start_capture(path), "Capture opens a new private recording")
	capture.set_process(false)
	capture._process(0.0)
	var main := MainFixture.new()
	root.add_child(main)
	capture.on_startup_completed(main)
	capture._process(0.0)
	main.phase = 4
	capture._process(0.0)
	main.free()
	capture._process(0.0)
	root.remove_child(capture)
	capture.free()
	var events := read_events(path)
	check(events[0].event == "start" and events[0].has("renderer"), "Recording identifies its renderer and executable")
	check(events[-1].event == "stop" and int(events[-1].frames) == 4, "Detach flushes the final partial batch")
	var samples: Array = []
	for event in events:
		if event.event == "frames":
			samples.append_array(event.samples)
	check(samples.size() == 4, "Every sampled frame survives batched recording")
	check(samples.map(func(row: Array): return int(row[4])) == [-1, 1, 4, -1], "Phase follows the live game and tolerates game destruction")
	for sample in samples:
		check(sample.size() == 6 and sample[1] >= 0.0, "Frame interval and column contract are valid")
		if DisplayServer.get_name() == "headless":
			check(sample[2] == null and sample[3] == null, "Headless timings are unavailable rather than zero")
		else:
			check(sample[2] != null and sample[2] >= 0.0, "Rendered capture queries viewport CPU timing")
			check(sample[3] == null or sample[3] > 0.0, "Unavailable GPU timing remains null")
	var prior := FileAccess.get_file_as_bytes(path)
	capture = Capture.new()
	root.add_child(capture)
	check(not capture.start_capture(path), "An existing capture is never overwritten")
	check(FileAccess.get_file_as_bytes(path) == prior, "Rejected recording preserves the existing file")
	var limit_path := path + ".limit"
	check(capture.start_capture(limit_path), "Bounded capture starts")
	capture.set_process(false)
	capture._started_usec -= int((Capture.MAX_SECONDS + 1.0) * 1000000.0)
	capture._process(0.0)
	check(capture._file == null and not capture.is_processing(), "Time limit closes the capture without stopping gameplay")
	check(read_events(limit_path)[-1].reason == "limit", "Time limit is recorded in the completed file")
	capture.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(limit_path)
	if failures.is_empty():
		print("FRAME_CAPTURE_TEST_OK")
	quit(0 if failures.is_empty() else 1)
