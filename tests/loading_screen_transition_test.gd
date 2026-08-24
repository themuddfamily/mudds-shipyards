extends SceneTree

const LoadingScreenType := preload("res://scripts/ui/loading_screen.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(5120, 1440)
	root.add_child(viewport)
	var screen := LoadingScreenType.new()
	viewport.add_child(screen)
	await process_frame
	screen.configure({"ui_scale": 1.6, "reduced_motion": true})
	var stack := screen.get_node_or_null("LoadingRoot/Stack") as VBoxContainer
	var destination := screen.get_node_or_null("LoadingRoot/Stack/Destination") as Label
	var phase := screen.get_node_or_null("LoadingRoot/Stack/Phase") as Label
	var phase_track := screen.get_node_or_null("LoadingRoot/Stack/PhaseTrack") as HBoxContainer
	var status := screen.get_node_or_null("LoadingRoot/Stack/StageRow/Status") as Label
	var progress := screen.get_node_or_null("LoadingRoot/Stack/StageRow/Progress") as Label
	var detail := screen.get_node_or_null("LoadingRoot/Stack/Detail") as Label
	_check(
		stack != null and destination != null and phase != null and phase_track != null
			and status != null and progress != null and detail != null,
		"the loading screen builds its destination, phase, status, detail, and completion composition"
	)
	if (
		stack == null
		or destination == null
		or phase == null
		or phase_track == null
		or status == null
		or progress == null
		or detail == null
	):
		screen.queue_free()
		await process_frame
		viewport.queue_free()
		await process_frame
		_finish()
		return

	screen.set_stage("Loading station data", 0.0, "Checking resident modules")
	_check(
		destination.text == "DESTINATION  /  MUDDS SHIPYARDS"
			and status.text == "LOADING STATION DATA"
			and progress.text == "0%"
			and detail.visible,
		"station startup has a separate steady destination, live status, detail, and numeric completion"
	)
	screen.set_stage(
		"Building the shipyard", 0.2, "Preparing Cinder Streaming Bootstrap"
	)
	_check(
		destination.text == "DESTINATION  /  MUDDS SHIPYARDS"
			and status.text == "BUILDING THE SHIPYARD"
			and detail.text == "Preparing Cinder Streaming Bootstrap",
		"an explicit station stage outranks incidental destination names in staged-child detail"
	)
	screen.set_stage("Loading Cinder Reach", 0.42, "Preparing nearby sector")
	screen.set_stage(
		"Preparing encounters", 0.58, "", "CINDER REACH", "Encounter handoff", 2, 3
	)
	_check(
		destination.text == "DESTINATION  /  CINDER REACH"
			and phase.text == "PHASE 2 OF 3  /  ENCOUNTER HANDOFF"
			and phase_track.visible
			and phase_track.get_child_count() == 3
			and status.text == "PREPARING ENCOUNTERS"
			and progress.text == "58%"
			and detail.visible
			and detail.text.is_empty(),
		"explicit Cinder identity and real phase stay readable while optional detail clears without shifting the track"
	)
	var retained_segment_ids: Array[int] = []
	for segment in phase_track.get_children():
		retained_segment_ids.append(segment.get_instance_id())
	screen.set_stage(
		"Preparing encounters", 0.61, "Placing patrols",
		"CINDER REACH", "Encounter handoff", 2, 3
	)
	var next_segment_ids: Array[int] = []
	for segment in phase_track.get_children():
		next_segment_ids.append(segment.get_instance_id())
	_check(
		next_segment_ids == retained_segment_ids and progress.text == "61%",
		"same-phase real progress repaints retained segments instead of allocating Controls every frame"
	)
	screen.set_stage(
		"Approaching Ember Moon", 0.73, "Streaming basalt terrain",
		"EMBER MOON", "Surface approach", 3, 3
	)
	_check(
		destination.text == "DESTINATION  /  EMBER MOON"
			and phase.text == "PHASE 3 OF 3  /  SURFACE APPROACH"
			and progress.text == "73%",
		"the next caller-owned phase replaces Cinder identity without inventing progress or transition authority"
	)
	var viewport_size := screen.get_viewport().get_visible_rect().size
	_check(
		viewport_size == Vector2(5120.0, 1440.0)
			and stack.position.x >= 0.0
			and stack.position.x + stack.size.x <= viewport_size.x
			and stack.size.x <= 760.0 * 1.6,
		(
			"the maximum-scale transition block stays inside a real 32:9 viewport and a bounded readable width "
			+ "(%s, position %s, size %s)" % [viewport_size, stack.position, stack.size]
		)
	)

	viewport.remove_child(screen)
	_check(
			destination.text.is_empty()
			and phase.text.is_empty()
			and not phase_track.visible
			and status.text.is_empty()
			and progress.text.is_empty()
			and detail.visible
			and detail.text.is_empty(),
		"detaching clears the painted transition composition before reuse"
	)
	viewport.add_child(screen)
	await process_frame
	screen.configure({"ui_scale": 1.25, "reduced_motion": true})
	screen.set_stage("Resolving approach", 0.1, "Fresh generation")
	var fresh_report := screen.get_report()
	_check(
		destination.text == "DESTINATION  /  DESTINATION PENDING"
			and not destination.text.contains("EMBER")
			and status.text == "RESOLVING APPROACH"
			and detail.text == "Fresh generation"
			and progress.text == "10%"
			and is_equal_approx(screen.get_progress(), 0.1)
			and screen.get_stage_text() == "Resolving approach"
			and is_equal_approx(float(fresh_report.progress), 0.1)
			and str(fresh_report.stage) == "Resolving approach"
			and str(fresh_report.detail) == "Fresh generation",
		"a reattached screen accepts lower fresh progress across getters, report, and paint"
	)
	screen.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("LOADING_SCREEN_TRANSITION_TEST_PASSED")
		quit(0)
		return
	print("LOADING_SCREEN_TRANSITION_TEST_FAILED: ", ", ".join(_failures))
	quit(1)
