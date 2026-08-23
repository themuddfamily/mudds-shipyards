extends SceneTree

const TorrentScene := preload("res://scenes/ships/torrent_interceptor.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var torrent := TorrentScene.instantiate() as Node
	root.add_child(torrent)
	await process_frame
	await process_frame
	var rig := torrent.get_node("ShipAudioRig") as ShipAudioRig
	var adapter := torrent.get_node("ShipPerspectiveAudioAdapter")
	var production: Dictionary = adapter.get_snapshot()
	_check(bool(production.attached), "Torrent scene composes the perspective audio adapter")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Torrent starts in exterior perspective")
	torrent.set_cockpit_view(true)
	var cockpit := rig.get_perspective_mix_snapshot()
	_check(
		cockpit.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT
			and float(cockpit.gain_db) < 0.0
			and float(cockpit.filter_cutoff_hz) < ShipAudioRig.ATTENUATION_FILTER_CUTOFF_HZ,
		"Torrent cockpit view reaches the resident rig mix/filter"
	)
	torrent.set_cockpit_view(false)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Torrent chase view restores exterior mix")
	root.remove_child(torrent)
	await process_frame
	root.add_child(torrent)
	await process_frame
	await process_frame
	var reentry: Dictionary = torrent.get_node("ShipPerspectiveAudioAdapter").get_snapshot()
	_check(bool(reentry.attached), "Torrent perspective adapter re-enters")
	_check(int(reentry.generation) == 1, "Torrent detach/re-entry advances perspective generation")
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Torrent re-entry resets to exterior")
	_check(int(rig.get_performance_report().maximum_simultaneous_voices) == 6, "Torrent perspective preserves the six-voice ceiling")
	_check(rig.get_audit_report().valid, "Torrent perspective mix remains auditable")
	torrent.queue_free()
	for failure in _failures:
		push_error(failure)
	print("torrent_perspective_audio_scene_adapter_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
