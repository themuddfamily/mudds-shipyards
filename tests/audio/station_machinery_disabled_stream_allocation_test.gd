extends SceneTree

const AMBIENCE_SCENE := preload("res://scenes/audio/station_machinery_ambience.tscn")
const EXPECTED_SAMPLE_BYTES := 83840

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var ambience := AMBIENCE_SCENE.instantiate()
	ambience.synthesis_seed = 7759
	ambience.base_frequency_hz = 52.0
	ambience.set_room_mix(0.65, 0.35)
	ambience.set_ambience_enabled(false)
	host.add_child(ambience)
	await process_frame

	var disabled_report: Dictionary = ambience.get_synthesis_report()
	_check(
		not bool(disabled_report.resources_ready)
			and int(disabled_report.resident_sample_bytes) == 0
			and int(disabled_report.generation_count) == 0,
		"pre-tree disabled ambience allocates no idle procedural stream templates"
	)
	_check(
		ambience.find_children("*", "AudioStreamPlayer3D", true, false).size() == 2
			and _players_are_stopped_and_detached(ambience),
		"disabled optimization preserves the bounded positional voice hierarchy"
	)
	_check(
		ambience.get_room_mix_snapshot() == {
			"caller_distance": 0.65,
			"room_exposure": 0.35,
			"presentation_only": true,
		},
		"deferred synthesis preserves caller-owned listener perspective"
	)

	ambience.set_ambience_enabled(true)
	var enabled_report: Dictionary = ambience.get_synthesis_report()
	var fingerprints := enabled_report.fingerprints_sha256 as Dictionary
	_check(
		bool(enabled_report.resources_ready)
			and int(enabled_report.resident_sample_bytes) == EXPECTED_SAMPLE_BYTES
			and int(enabled_report.generation_count) == 1,
		"first enable performs exactly one bounded stream allocation"
	)
	_check(
		fingerprints.size() == 3
			and fingerprints.has(&"loop")
			and fingerprints.has(&"servo")
			and fingerprints.has(&"latch")
			and fingerprints[&"loop"] != fingerprints[&"servo"]
			and fingerprints[&"servo"] != fingerprints[&"latch"],
		"lazy allocation retains the distinct loop, servo, and latch waveforms"
	)
	_check(
		bool(ambience.get_audit_report().valid)
			and ambience.get_room_mix_snapshot() == {
				"caller_distance": 0.65,
				"room_exposure": 0.35,
				"presentation_only": true,
			},
		"enabled lazy-built ambience restores an auditable spatial presentation"
	)

	ambience.set_ambience_enabled(false)
	ambience.set_ambience_enabled(true)
	_check(
		int(ambience.get_synthesis_report().generation_count) == 1,
		"ordinary disable and re-enable reuse the generated templates"
	)

	host.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("STATION_MACHINERY_DISABLED_STREAM_ALLOCATION_TEST_OK")
		quit(0)
	else:
		quit(1)


func _players_are_stopped_and_detached(ambience: Node) -> bool:
	for candidate in ambience.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := candidate as AudioStreamPlayer3D
		if player.playing or player.stream != null:
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
